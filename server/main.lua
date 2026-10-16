local RESOURCE = GetCurrentResourceName()
-- Extra meters on top of Config.InteractDistance (the player's position on the server lags a little behind)
local DISTANCE_MARGIN = 3.0
-- A crate may be reported this much before the pickup time is up (network and frame timing)
local PICKUP_EARLY_MS = 1500
-- Extra time on top of a job's time limit before the server ends it (the client's timer ends it first)
local DEADLINE_GRACE_MS = 3000

local missions = {}  -- [source] = { id, identifier, startedAt, deadline, picked = { [index] = true }, count, lastPickup }
local cooldowns = {} -- [identifier] = { [job id] = GetGameTimer() when the cooldown ends }
local policeJobs = {}

local function prepareConfig()
  local police = type(Config.Police) == "table" and Config.Police or {}
  Config.Police = police
  -- Accepts { "police" } and { police = true }
  for key, value in pairs(type(police.jobs) == "table" and police.jobs or {}) do
    if type(value) == "string" then policeJobs[value] = true
    elseif type(key) == "string" and value then policeJobs[key] = true end
  end
  police.minimum = math.max(0, math.floor(tonumber(police.minimum) or 0))
  if police.minimum > 0 and next(policeJobs) == nil then
    Log("error", "Config.Police.minimum is set but Config.Police.jobs is empty: nobody can take a job")
  end
end

local function playerCoords(source)
  local ped = GetPlayerPed(source)
  if not ped or ped == 0 then return nil end
  return GetEntityCoords(ped)
end

local function isNear(source, coords, distance)
  local pos = playerCoords(source)
  return pos ~= nil and #(pos - coords) <= distance + DISTANCE_MARGIN
end

local function identifierOf(source)
  local ok, identifier = pcall(GetIdentifier, source)
  if not ok then
    Log("error", ("Reading the player's identifier failed: %s"):format(tostring(identifier)))
    return nil
  end
  return type(identifier) == "string" and identifier ~= "" and identifier or nil
end

--- Seconds left on the player's cooldown for a job (0 when none)
local function cooldownLeft(identifier, id)
  local ends = cooldowns[identifier] and cooldowns[identifier][id]
  if not ends then return 0 end
  local left = ends - GetGameTimer()
  if left <= 0 then
    cooldowns[identifier][id] = nil
    return 0
  end
  return math.ceil(left / 1000)
end

local function startCooldown(identifier, mission)
  if not identifier or not mission or mission.cooldown <= 0 then return end
  cooldowns[identifier] = cooldowns[identifier] or {}
  cooldowns[identifier][mission.id] = GetGameTimer() + mission.cooldown * 1000
end

--- Ends the player's job (if any) and starts its cooldown. Every way a job ends goes through here.
--- @return table|nil the job that ended
local function endMission(source, why)
  local running = missions[source]
  if not running then return nil end
  missions[source] = nil
  startCooldown(running.identifier, GetMission(running.id))
  Debug("info", "Job '%s' of %s ended: %s", running.id, tostring(GetPlayerName(source)), why)
  return running
end

local function isExpired(running)
  return GetGameTimer() > running.deadline
end

--- Ends an expired job and tells the client. Returns true when the job was expired.
local function expire(source)
  local running = missions[source]
  if not running or not isExpired(running) then return false end
  endMission(source, "time limit")
  TriggerClientEvent(RESOURCE .. ":client:ended", source, "expired")
  return true
end

--- Police on duty, or nil when the framework bridge failed
local function policeOnline()
  local ok, count = pcall(CountPolice, policeJobs, Config.Police.onlyOnDuty ~= false)
  if not ok or type(count) ~= "number" then
    Log("error", ("Counting the police failed: %s"):format(tostring(count)))
    return nil
  end
  return count
end

lib.callback.register(RESOURCE .. ":server:start", function(source, id)
  if not IsFrameworkReady() then return false, "not_ready" end
  local mission = GetMission(id)
  if not mission then return false, "unknown_job" end
  local identifier = identifierOf(source)
  if not identifier then return false, "not_ready" end
  expire(source)
  if missions[source] then return false, "busy" end
  if not Config.Boss or not isNear(source, Config.Boss.position, GetInteractDistance()) then return false, "too_far" end
  local left = cooldownLeft(identifier, mission.id)
  if left > 0 then return false, "cooldown", left end
  if Config.Police.minimum > 0 then
    local police = policeOnline()
    if not police then return false, "not_ready" end
    if police < Config.Police.minimum then return false, "not_enough_police" end
  end

  local startedAt = GetGameTimer()
  missions[source] = {
    id = mission.id,
    identifier = identifier,
    startedAt = startedAt,
    deadline = startedAt + mission.timeLimit * 1000 + DEADLINE_GRACE_MS,
    picked = {},
    count = 0,
    lastPickup = startedAt,
  }
  Debug("info", "%s started job '%s'", tostring(GetPlayerName(source)), mission.id)
  return true, mission.id
end)

lib.callback.register(RESOURCE .. ":server:pickup", function(source, index)
  local running = missions[source]
  if not running then return false, "no_job" end
  if expire(source) then return false, "expired" end
  local mission = GetMission(running.id)
  index = math.tointeger(tonumber(index))
  local crate = mission and index and mission.crates[index]
  if not crate or running.picked[index] then return false, "failed" end
  if running.count >= mission.cratesNeeded then return false, "failed" end
  if not isNear(source, crate.coords, GetInteractDistance()) then return false, "too_far" end
  if GetGameTimer() - running.lastPickup < GetPickupDuration() - PICKUP_EARLY_MS then return false, "too_fast" end

  running.picked[index] = true
  running.count = running.count + 1
  running.lastPickup = GetGameTimer()
  return true, running.count, mission.cratesNeeded
end)

lib.callback.register(RESOURCE .. ":server:finish", function(source)
  local running = missions[source]
  if not running then return false, "no_job" end
  if expire(source) then return false, "expired" end
  local mission = GetMission(running.id)
  if not mission then
    endMission(source, "job no longer configured")
    return false, "failed"
  end
  if running.count < mission.cratesNeeded then return false, "not_done" end
  if not Config.Boss or not isNear(source, Config.Boss.position, GetInteractDistance()) then return false, "too_far" end

  local amount = math.random(mission.amount.min, mission.amount.max)
  -- The job stays open on a full inventory: the player makes room and talks to the boss again
  if not CanCarryItem(source, mission.item, amount) then return false, "inventory_full" end
  if not AddItem(source, mission.item, amount) then return false, "inventory_full" end

  endMission(source, "delivered")
  Debug("info", "%s got %sx %s from job '%s'", tostring(GetPlayerName(source)), amount, mission.item, mission.id)
  TriggerEvent(RESOURCE .. ":jobFinished", source, mission.id, mission.item, amount)
  return true, amount
end)

-- The player cancelled the job or died. Nothing is given; the cooldown starts.
RegisterNetEvent(RESOURCE .. ":server:cancel", function(reason)
  local src = source
  endMission(src, reason == "death" and "death" or "cancelled")
end)

AddEventHandler("playerDropped", function()
  local src = source
  endMission(src, "player left")
end)

-- Ends jobs whose time is up (the client normally reports it first)
CreateThread(function()
  while true do
    Wait(1000)
    for src in pairs(missions) do expire(src) end
  end
end)

--- The job id the player is running, or nil
exports("GetActiveJob", function(source)
  local running = missions[tonumber(source) or -1]
  return running and running.id or nil
end)

prepareConfig()
