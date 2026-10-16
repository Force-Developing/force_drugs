local RESOURCE = GetCurrentResourceName()
local CALLBACK_TIMEOUT = 15000
local BOSS_SPAWN_DISTANCE = 50.0
-- Crates and guards appear when the player is this far outside the job area
local AREA_SPAWN_EXTRA = 60.0
local PICKUP_DICT, PICKUP_CLIP = "mini@repair", "fixing_a_ped"
local GUARD_GROUP = "FORCE_DRUGS_GUARDS"
local BLIP_COLOUR = 46

local bossPed = nil
local bossBlip = nil
local bossPoint = nil
local requesting = false -- menu / dialog / server request in progress
local job = nil          -- the running job, see beginJob()

local function notify(message, notifyType)
  lib.notify({ description = message, type = notifyType or "inform" })
end

local function playerLoaded()
  local ok, loaded = pcall(IsPlayerLoaded)
  return ok and loaded == true
end

--- lib.callback with its own timeout (ox_lib waits 5 minutes and throws). Returns nil when the server didn't answer.
local function awaitServer(name, ...)
  local p = promise.new()
  local settled = false
  local function settle(value)
    if settled then return end
    settled = true
    p:resolve(value)
  end
  lib.callback(name, false, function(...)
    settle({ n = select("#", ...), ... })
  end, ...)
  SetTimeout(CALLBACK_TIMEOUT, function() settle(false) end)
  local result = Citizen.Await(p)
  if not result then return nil end
  return table.unpack(result, 1, result.n)
end

--- Notification for a reason the server returned
local function notifyReason(reason, extra)
  if reason == "cooldown" then
    return notify(locale("cooldown", math.max(1, math.ceil((tonumber(extra) or 60) / 60))), "error")
  end
  if reason == "inventory_full" then return notify(locale("inventory_full", Config.Boss.name), "error") end
  local key = type(reason) == "string" and reason or "failed"
  local text = locale(key)
  notify(text == key and locale("failed") or text, "error")
end

local function bossCoords()
  return Config.Boss.position
end

local function drawText2D(text, y)
  SetTextFont(4)
  SetTextScale(0.5, 0.5)
  SetTextColour(255, 255, 255, 255)
  SetTextEdge(2, 0, 0, 0, 150)
  SetTextOutline()
  SetTextCentre(true)
  BeginTextCommandDisplayText("STRING")
  AddTextComponentSubstringPlayerName(text)
  EndTextCommandDisplayText(0.5, y)
end

local function setBlipName(blip, text)
  BeginTextCommandSetBlipName("STRING")
  AddTextComponentSubstringPlayerName(text)
  EndTextCommandSetBlipName(blip)
end

local function routeBlip(coords, text)
  local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
  SetBlipColour(blip, BLIP_COLOUR)
  SetBlipRoute(blip, true)
  SetBlipRouteColour(blip, BLIP_COLOUR)
  setBlipName(blip, text)
  return blip
end

local function removeBlip(blip)
  if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
end

local function deleteEntity(entity)
  if entity and DoesEntityExist(entity) then DeleteEntity(entity) end
end

--- Loads a model (pcall: lib.requestModel throws on a bad model or timeout). Returns the hash or nil.
local function loadModel(model)
  local hash = type(model) == "number" and model or joaat(model)
  local ok, err = pcall(lib.requestModel, hash, 10000)
  if not ok then
    Debug("error", "Model '%s' could not be loaded: %s", tostring(model), tostring(err))
    return nil
  end
  return hash
end

-------------------------------------------------------------------------------------------------------------------
-- Job
-------------------------------------------------------------------------------------------------------------------

local function crateId(index) return "crate:" .. index end

--- Removes everything a job put in the world. Safe to call more than once.
local function endJob()
  local current = job
  if not current then return end
  job = nil
  if current.busy then pcall(lib.cancelProgress) end
  removeBlip(current.areaBlip)
  removeBlip(current.routeBlip)
  removeBlip(current.returnBlip)
  if current.areaPoint then current.areaPoint:remove() end
  for index, crate in pairs(current.crates) do
    deleteEntity(crate)
    Interact.remove(crateId(index))
  end
  for _, guard in ipairs(current.guards) do deleteEntity(guard) end
end

--- Tells the server the job is over (nothing is given) and cleans up
local function cancelJob(reason)
  if not job then return end
  TriggerServerEvent(RESOURCE .. ":server:cancel", reason)
  endJob()
end

local function startReturn(current)
  current.returning = true
  removeBlip(current.areaBlip)
  removeBlip(current.routeBlip)
  current.areaBlip, current.routeBlip = nil, nil
  for index in pairs(current.crates) do Interact.remove(crateId(index)) end
  current.returnBlip = routeBlip(bossCoords(), Config.Boss.name)
  notify(locale("all_collected"), "success")
end

local function pickupCrate(index)
  local current = job
  if not current or current.busy or current.returning or current.picked[index] then return end
  current.busy = true
  local ok, finished = pcall(lib.progressBar, {
    duration = GetPickupDuration(),
    label = locale("picking_up"),
    useWhileDead = false,
    canCancel = true,
    disable = { move = true, car = true, combat = true },
    anim = { dict = PICKUP_DICT, clip = PICKUP_CLIP, flag = 1 },
  })
  ClearPedTasks(PlayerPedId())
  if job ~= current then return end
  current.busy = false
  if not ok then Debug("error", "Pickup progress failed: %s", tostring(finished)) return end
  if not finished then return end

  local picked, count, needed = awaitServer(RESOURCE .. ":server:pickup", index)
  if job ~= current then return end
  if picked == nil then return notify(locale("server_no_response"), "error") end
  if not picked then
    notifyReason(count)
    if count == "expired" or count == "no_job" then endJob() end
    return
  end
  current.picked[index] = true
  current.count = tonumber(count) or current.count + 1
  deleteEntity(current.crates[index])
  current.crates[index] = nil
  Interact.remove(crateId(index))
  notify(locale("crate_count", current.count, tonumber(needed) or current.mission.cratesNeeded))
  if current.count >= current.mission.cratesNeeded then startReturn(current) end
end

local function spawnCrate(current, index, crate)
  local hash = loadModel(crate.model)
  if not hash or job ~= current or current.picked[index] then return end
  local c = crate.coords
  local object = CreateObject(hash, c.x, c.y, c.z, false, false, false)
  SetModelAsNoLongerNeeded(hash)
  FreezeEntityPosition(object, true)
  current.crates[index] = object
  Interact.add(crateId(index), {
    coords = vector3(c.x, c.y, c.z + 0.4),
    distance = GetInteractDistance(),
    size = 0.8,
    label = locale("crate_label"),
    icon = "fa-solid fa-box",
    text = locale("crate_textui"),
    canInteract = function()
      return job == current and not current.busy and not current.returning and not current.picked[index]
    end,
    onSelect = function() CreateThread(function() pickupCrate(index) end) end,
  })
end

local function spawnGuard(current, guard, group)
  local hash = loadModel(guard.model)
  if not hash or job ~= current then return end
  local c = guard.coords
  local ped = CreatePed(4, hash, c.x, c.y, c.z, guard.heading, false, false)
  SetModelAsNoLongerNeeded(hash)
  current.guards[#current.guards + 1] = ped
  SetPedRelationshipGroupHash(ped, group)
  SetPedCombatAttributes(ped, 46, true)
  SetPedSeeingRange(ped, 100.0)
  SetPedHearingRange(ped, 100.0)
  SetPedDropsWeaponsWhenDead(ped, false)
  if guard.weapon then
    GiveWeaponToPed(ped, joaat(guard.weapon), 1, false, true)
    SetCurrentPedWeapon(ped, joaat(guard.weapon), true)
  end
end

--- Crates and guards, once per job, when the player gets close to the area
local function spawnArea(current)
  if current.areaSpawned then return end
  current.areaSpawned = true
  for index, crate in ipairs(current.mission.crates) do
    if not current.picked[index] then spawnCrate(current, index, crate) end
  end
  AddRelationshipGroup(GUARD_GROUP)
  local group = joaat(GUARD_GROUP)
  SetRelationshipBetweenGroups(0, group, group)
  SetRelationshipBetweenGroups(5, group, `PLAYER`)
  SetRelationshipBetweenGroups(5, `PLAYER`, group)
  for _, guard in ipairs(current.mission.guards) do spawnGuard(current, guard, group) end
end

--- Death, time limit and the route blip (every 500 ms)
local function watchJob(current)
  while job == current do
    if IsEntityDead(PlayerPedId()) then
      notify(locale("died"), "error")
      cancelJob("death")
      return
    end
    if GetGameTimer() >= current.endsAt then
      notify(locale("expired"), "error")
      cancelJob("expired")
      return
    end
    if not current.returning then
      local area = current.mission.area
      local outside = #(GetEntityCoords(PlayerPedId()) - area.coords) > area.radius
      if outside and not current.routeBlip then
        current.routeBlip = routeBlip(area.coords, locale("blip_area"))
      elseif not outside and current.routeBlip then
        removeBlip(current.routeBlip)
        current.routeBlip = nil
      end
    end
    Wait(500)
  end
end

local function formatTime(seconds)
  return ("%d:%02d"):format(seconds // 60, seconds % 60)
end

--- Time left, crate count and the hint line (only while a job runs)
local function drawJob(current)
  while job == current do
    local left = math.max(0, math.ceil((current.endsAt - GetGameTimer()) / 1000))
    drawText2D(locale("timer", formatTime(left), current.count, current.mission.cratesNeeded), 0.01)
    drawText2D(current.returning and locale("hint_return", Config.Boss.name) or locale("hint_collect"), 0.93)
    Wait(0)
  end
end

local function beginJob(mission)
  local current = {
    mission = mission,
    endsAt = GetGameTimer() + mission.timeLimit * 1000,
    count = 0,
    picked = {},
    crates = {},
    guards = {},
  }
  job = current

  local area = mission.area
  current.areaBlip = AddBlipForRadius(area.coords.x, area.coords.y, area.coords.z, area.radius)
  SetBlipColour(current.areaBlip, BLIP_COLOUR)
  SetBlipAlpha(current.areaBlip, 100)
  current.areaPoint = lib.points.new({
    coords = area.coords,
    distance = area.radius + AREA_SPAWN_EXTRA,
    onEnter = function()
      -- loading models yields; don't block the points loop
      CreateThread(function() if job == current then spawnArea(current) end end)
    end,
  })

  CreateThread(function() watchJob(current) end)
  if Config.ShowTimer ~= false then CreateThread(function() drawJob(current) end) end
  CreateThread(function()
    for i = 1, 4 do
      if job ~= current then return end
      notify(locale("dialog_" .. i))
      Wait(2000)
    end
  end)
end

-------------------------------------------------------------------------------------------------------------------
-- Boss
-------------------------------------------------------------------------------------------------------------------

local function confirmStart(mission)
  local answer = lib.alertDialog({
    header = locale("confirm_header", Config.Boss.name),
    content = locale("confirm_content", mission.cratesNeeded, #mission.crates, math.ceil(mission.timeLimit / 60)),
    centered = true,
    cancel = true,
  })
  if answer ~= "confirm" then return notify(locale("declined"), "error") end
  if job then return notify(locale("busy"), "error") end
  local ok, result, extra = awaitServer(RESOURCE .. ":server:start", mission.id)
  if ok == nil then return notify(locale("server_no_response"), "error") end
  if not ok then return notifyReason(result, extra) end
  beginJob(mission)
end

local function openMenu()
  local options = {}
  for _, id in ipairs(GetMissionIds()) do
    local mission = GetMission(id)
    options[#options + 1] = {
      title = locale("menu_item", mission.label),
      description = locale("menu_item_desc", mission.cratesNeeded, #mission.crates, math.ceil(mission.timeLimit / 60),
        mission.amount.min, mission.amount.max),
      icon = "fa-solid fa-box",
      onSelect = function()
        CreateThread(function()
          requesting = true
          local ok, err = pcall(confirmStart, mission)
          requesting = false
          if not ok then
            Debug("error", "Starting a job failed: %s", tostring(err))
            notify(locale("server_no_response"), "error")
          end
        end)
      end,
    }
  end
  local id = RESOURCE .. ":menu"
  lib.registerContext({
    id = id,
    title = locale("menu_title", Config.Boss.name),
    options = options,
    onExit = function() notify(locale("declined"), "error") end,
  })
  lib.showContext(id)
end

local function deliver(current)
  local ok, result = awaitServer(RESOURCE .. ":server:finish")
  if job ~= current then return end
  if ok == nil then return notify(locale("server_no_response"), "error") end
  if not ok then
    notifyReason(result)
    if result == "expired" or result == "no_job" then endJob() end
    return
  end
  notify(locale("rewarded", tonumber(result) or 0, current.mission.label), "success")
  endJob()
end

local function askCancel(current)
  local answer = lib.alertDialog({
    header = locale("not_finished_header", Config.Boss.name),
    content = locale("not_finished_content", current.mission.cratesNeeded - current.count),
    centered = true,
    cancel = true,
  })
  if answer == "confirm" and job == current then
    cancelJob("cancelled")
    notify(locale("cancelled"))
  end
end

local function talkToBoss()
  if requesting then return end
  if not IsFrameworkReady() or not playerLoaded() then return notify(locale("not_ready"), "error") end
  local current = job
  if not current then return openMenu() end
  if current.busy then return end
  requesting = true
  local ok, err = pcall(current.returning and deliver or askCancel, current)
  requesting = false
  if not ok then
    Debug("error", "Talking to the boss failed: %s", tostring(err))
    notify(locale("server_no_response"), "error")
  end
end

local function deleteBoss()
  deleteEntity(bossPed)
  bossPed = nil
end

local function spawnBoss()
  if bossPed and DoesEntityExist(bossPed) then return end
  local boss = Config.Boss
  local hash = loadModel(boss.model)
  if not hash then return end
  -- the player may have walked away while the model loaded
  if not bossPoint or not bossPoint.inside or (bossPed and DoesEntityExist(bossPed)) then
    SetModelAsNoLongerNeeded(hash)
    return
  end
  local c = boss.position
  local ped = CreatePed(4, hash, c.x, c.y, c.z, boss.heading, false, false)
  SetModelAsNoLongerNeeded(hash)
  FreezeEntityPosition(ped, true)
  SetEntityInvincible(ped, true)
  SetBlockingOfNonTemporaryEvents(ped, true)
  SetPedCanRagdoll(ped, false)
  bossPed = ped
  if boss.anim then
    local ok, err = pcall(lib.requestAnimDict, boss.anim.dict, 5000)
    if not ok then return Debug("error", "Boss animation could not be loaded: %s", tostring(err)) end
    if not DoesEntityExist(ped) then return end
    TaskPlayAnim(ped, boss.anim.dict, boss.anim.clip, 8.0, -8.0, -1, 1, 0, false, false, false)
    RemoveAnimDict(boss.anim.dict)
  end
end

local function setupBoss()
  local boss = Config.Boss
  if not boss then return end
  local c = boss.position
  bossPoint = lib.points.new({
    coords = c,
    distance = BOSS_SPAWN_DISTANCE,
    onEnter = function(self)
      self.inside = true
      CreateThread(spawnBoss)
    end,
    onExit = function(self)
      self.inside = false
      deleteBoss()
    end,
  })
  Interact.add("boss", {
    coords = vector3(c.x, c.y, c.z + 1.0),
    distance = GetInteractDistance(),
    size = 1.0,
    label = locale("talk_label", boss.name),
    icon = "fa-solid fa-comments",
    text = locale("talk_textui", boss.name),
    canInteract = function() return not requesting and not (job and job.busy) and playerLoaded() end,
    onSelect = function() CreateThread(talkToBoss) end,
  })
  if type(boss.blip) == "table" then
    bossBlip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(bossBlip, tonumber(boss.blip.sprite) or 51)
    SetBlipColour(bossBlip, tonumber(boss.blip.colour) or 1)
    SetBlipScale(bossBlip, (tonumber(boss.blip.scale) or 0.7) + 0.0)
    SetBlipAsShortRange(bossBlip, true)
    setBlipName(bossBlip, type(boss.blip.label) == "string" and boss.blip.label or boss.name)
  end
end

-- The server ended the job (time limit)
RegisterNetEvent(RESOURCE .. ":client:ended", function(reason)
  if not job then return end
  endJob()
  if reason == "expired" then notify(locale("expired"), "error") end
end)

OnEnvironmentReady(function()
  local ok, err = pcall(setupBoss)
  if not ok then Log("error", ("The boss could not be set up: %s"):format(tostring(err))) end
end)

AddEventHandler("onResourceStop", function(resource)
  if resource ~= RESOURCE then return end
  if requesting then
    pcall(lib.closeAlertDialog)
    pcall(lib.hideContext)
  end
  endJob()
  deleteBoss()
  removeBlip(bossBlip)
  if bossPoint then bossPoint:remove() end
  Interact.removeAll()
end)
