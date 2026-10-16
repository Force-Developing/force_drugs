-- One place for every interaction: an ox_target / qb-target zone, or [E] with the ox_lib text UI when no target
-- resource runs. Entries can be added and removed at any time; target zones are (re)added once the target
-- resource runs on this client.
local RESOURCE = GetCurrentResourceName()
local KEY_E = 38

Interact = {}

local entries = {}      -- [id] = { opts, oxZone, qbZone, point }
local targetReady = false
local shownText = nil   -- id of the entry whose text UI is shown
local lastPress = 0

local function hideText(id)
  if not shownText or (id and shownText ~= id) then return end
  lib.hideTextUI()
  shownText = nil
end

local function showText(id, text)
  if shownText == id then return end
  lib.showTextUI(text)
  shownText = id
end

local function usable(entry)
  local check = entry.opts.canInteract
  if not check then return true end
  local ok, result = pcall(check)
  if not ok then Debug("error", "canInteract of '%s' failed: %s", entry.id, tostring(result)) end
  return ok and result == true
end

local function select(entry)
  local ok, err = pcall(entry.opts.onSelect)
  if not ok then Log("error", ("Interaction '%s' failed: %s"):format(entry.id, tostring(err))) end
end

local function removeTarget(entry)
  if entry.oxZone then
    local zone = entry.oxZone
    entry.oxZone = nil
    pcall(function() exports.ox_target:removeZone(zone) end)
  end
  if entry.qbZone then
    local name = entry.qbZone
    entry.qbZone = nil
    pcall(function() exports["qb-target"]:RemoveZone(name) end)
  end
end

local function addTarget(entry)
  removeTarget(entry)
  local o = entry.opts
  local name = ("%s:%s"):format(RESOURCE, entry.id)
  local function canInteract() return usable(entry) end
  local function onSelect() select(entry) end
  local target = GetTargetSystem()
  if target == "ox_target" then
    entry.oxZone = exports.ox_target:addSphereZone({
      coords = o.coords,
      radius = o.size or 1.0,
      options = { {
        name = name, icon = o.icon, label = o.label, distance = o.distance,
        canInteract = canInteract, onSelect = onSelect,
      } },
    })
  elseif target == "qb-target" then
    exports["qb-target"]:AddCircleZone(name, o.coords, o.size or 1.0, { name = name, debugPoly = false, useZ = true }, {
      options = { { icon = o.icon, label = o.label, canInteract = canInteract, action = onSelect } },
      distance = o.distance,
    })
    entry.qbZone = name
  end
end

local function addPoint(entry)
  local o = entry.opts
  entry.point = lib.points.new({
    coords = o.coords,
    distance = o.distance,
    nearby = function()
      if not usable(entry) then return hideText(entry.id) end
      showText(entry.id, o.text)
      if IsControlJustReleased(0, KEY_E) and GetGameTimer() - lastPress > 500 then
        lastPress = GetGameTimer()
        hideText(entry.id)
        select(entry)
      end
    end,
    onExit = function() hideText(entry.id) end,
  })
end

local function attach(entry)
  if GetTargetSystem() == "none" then
    addPoint(entry)
  elseif targetReady then
    local ok, err = pcall(addTarget, entry)
    if not ok then Log("error", ("Adding the target zone '%s' failed: %s"):format(entry.id, tostring(err))) end
  end
end

--- Adds (or replaces) an interaction. Call after OnEnvironmentReady.
--- opts = { coords = vector3, distance = meters, size = zone radius, label, icon, text ([E] text UI),
---          canInteract = fun(): boolean, onSelect = fun() (runs in the target's / points' thread; don't block) }
function Interact.add(id, opts)
  Interact.remove(id)
  local entry = { id = id, opts = opts }
  entries[id] = entry
  attach(entry)
end

function Interact.remove(id)
  local entry = entries[id]
  if not entry then return end
  entries[id] = nil
  removeTarget(entry)
  if entry.point then entry.point:remove() end
  hideText(id)
end

function Interact.removeAll()
  for id in pairs(entries) do Interact.remove(id) end
  hideText()
end

function Interact.hideText()
  hideText()
end

OnEnvironmentReady(function()
  local target = GetTargetSystem()
  if target == "none" then return end
  -- The client starts resources in server.cfg order: a target ensured after this resource isn't running here yet
  CreateThread(function()
    local nextWarning = GetGameTimer() + 10000
    while GetResourceState(target) ~= "started" do
      Wait(250)
      if GetGameTimer() >= nextWarning then
        Log("warn", ("Still waiting for %s to start on this client."):format(target))
        nextWarning = GetGameTimer() + 10000
      end
    end
    targetReady = true
    for _, entry in pairs(entries) do attach(entry) end
  end)
end)

-- A restarted target resource has forgotten our zones
AddEventHandler("onClientResourceStart", function(resource)
  if not targetReady or resource ~= GetTargetSystem() then return end
  for _, entry in pairs(entries) do
    -- the old zone ids died with the target resource; removing them could hit a new zone with the same id
    entry.oxZone, entry.qbZone = nil, nil
    attach(entry)
  end
end)
