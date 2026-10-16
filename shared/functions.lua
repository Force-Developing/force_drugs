local RESOURCE = GetCurrentResourceName()
local IS_SERVER = IsDuplicityVersion()

--- Prints to the console regardless of Config.Debug (setup problems must always be visible).
--- @param level "error"|"warn"|"info"
function Log(level, message)
  local color = level == "error" and "^1" or level == "warn" and "^3" or "^2"
  print(("%s[%s] %s^7"):format(color, RESOURCE, tostring(message)))
end

--- Debug output. Errors are always printed, everything else only with Config.Debug.
function Debug(level, message, ...)
  message = tostring(message)
  if select("#", ...) > 0 then
    local ok, formatted = pcall(string.format, message, ...)
    if ok then message = formatted end
  end
  if level == "error" then
    lib.print.error(message)
    return
  end
  if not Config.Debug then return end
  local fn = ({ warn = lib.print.warn, info = lib.print.info, debug = lib.print.debug })[level] or lib.print.info
  fn(message)
end

--- Loads the configured locale. "auto" follows the replicated ox:locale convar; anything without a file -> "en".
local function InitLocale()
  local key = Config.Locale
  if type(key) ~= "string" or key == "auto" then key = GetConvar("ox:locale", "en") end
  local function hasLocale(name)
    return name and LoadResourceFile(RESOURCE, ("locales/%s.json"):format(name)) ~= nil
  end
  if not hasLocale(key) then
    local language = key:match("^(%a+)")
    key = hasLocale(language) and language or "en"
  end
  lib.locale(key)
end

-------------------------------------------------------------------------------------------------------------------
-- Boss and jobs (validated once per side; the server repeats every check, the client only uses them for the UI)
-------------------------------------------------------------------------------------------------------------------

local function isVector(value)
  local t = type(value)
  return (t == "vector3" or t == "vector4" or t == "table") and tonumber(value.x) and tonumber(value.y)
      and tonumber(value.z) and true or false
end

--- Heading of a vec4 (nil for a vec3: reading .w from a vector3 errors in cfx)
local function headingOf(value)
  local t = type(value)
  if t == "vector4" then return value.w + 0.0 end
  if t == "table" and tonumber(value.w) then return tonumber(value.w) + 0.0 end
  return nil
end

local function toVector3(v)
  return vector3(v.x + 0.0, v.y + 0.0, v.z + 0.0)
end

--- Whole number >= minimum, or the fallback
local function wholeNumber(value, fallback, minimum)
  local n = math.tointeger(math.floor(tonumber(value) or fallback))
  if not n or n < minimum then return fallback end
  return n
end

local function PrepareBoss()
  local boss = Config.Boss
  if type(boss) ~= "table" or not isVector(boss.coords) then
    Log("error", "Config.Boss needs coords: nobody hands out jobs")
    Config.Boss = nil
    return
  end
  boss.name = type(boss.name) == "string" and boss.name or "Kalle"
  boss.model = type(boss.model) == "string" and boss.model or "g_m_m_armgoon_01"
  boss.heading = headingOf(boss.coords) or 0.0
  boss.position = toVector3(boss.coords)
  if boss.anim ~= false and (type(boss.anim) ~= "table" or type(boss.anim.dict) ~= "string" or type(boss.anim.clip) ~= "string") then
    boss.anim = false
  end
  if boss.blip ~= nil and boss.blip ~= false and type(boss.blip) ~= "table" then
    Log("error", "Config.Boss.blip must be a table or false, it is disabled")
    boss.blip = false
  end
end

local function PrepareMission(id, mission)
  if type(id) ~= "string" then return nil, "the job id must be a string" end
  if type(mission) ~= "table" then return nil, "it must be a table" end
  if type(mission.item) ~= "string" or mission.item == "" then return nil, "it needs an item" end
  if type(mission.area) ~= "table" or not isVector(mission.area.coords) then return nil, "it needs area.coords" end
  if type(mission.crates) ~= "table" then return nil, "it needs crates" end

  local crates = {}
  for i, crate in ipairs(mission.crates) do
    if type(crate) == "table" and isVector(crate.coords) then
      crates[#crates + 1] = {
        model = type(crate.model) == "string" and crate.model or "prop_cs_cardbox_01",
        coords = toVector3(crate.coords),
      }
    else
      Log("error", ("Job '%s': crate %d is skipped, it needs coords"):format(id, i))
    end
  end
  if #crates == 0 then return nil, "it needs at least one crate with coords" end

  local guards = {}
  for i, guard in ipairs(type(mission.guards) == "table" and mission.guards or {}) do
    if type(guard) == "table" and type(guard.model) == "string" and isVector(guard.coords) then
      guards[#guards + 1] = {
        model = guard.model,
        weapon = type(guard.weapon) == "string" and guard.weapon or nil,
        coords = toVector3(guard.coords),
        heading = headingOf(guard.coords) or 0.0,
      }
    else
      Log("error", ("Job '%s': guard %d is skipped, it needs a model and coords"):format(id, i))
    end
  end

  local amount = type(mission.amount) == "table" and mission.amount or {}
  local min = wholeNumber(amount.min, 1, 1)
  local max = wholeNumber(amount.max, min, min)

  mission.id = id
  mission.label = type(mission.label) == "string" and mission.label or id
  mission.crates = crates
  mission.guards = guards
  mission.amount = { min = min, max = max }
  mission.timeLimit = wholeNumber(mission.timeLimit, 900, 30)
  mission.cooldown = wholeNumber(mission.cooldown, 0, 0)
  mission.cratesNeeded = math.min(wholeNumber(mission.cratesNeeded, #crates, 1), #crates)
  mission.area = { coords = toVector3(mission.area.coords), radius = (tonumber(mission.area.radius) or 50.0) + 0.0 }
  return mission
end

local function PrepareMissions()
  if type(Config.Missions) ~= "table" then
    Log("error", "Config.Missions is missing or not a table")
    Config.Missions = {}
    return
  end
  for id, mission in pairs(Config.Missions) do
    local prepared, why = PrepareMission(id, mission)
    if not prepared then
      Log("error", ("Job '%s' is skipped: %s"):format(tostring(id), why))
      Config.Missions[id] = nil
    end
  end
end

--- @param id any
--- @return table|nil
function GetMission(id)
  if type(id) ~= "string" then return nil end
  return Config.Missions[id]
end

--- Job ids sorted by key (menu order)
--- @return string[]
function GetMissionIds()
  local ids = {}
  for id in pairs(Config.Missions) do ids[#ids + 1] = id end
  table.sort(ids)
  return ids
end

--- Milliseconds it takes to pick up one crate
function GetPickupDuration()
  return math.max(1000, math.floor((tonumber(Config.PickupDuration) or 10) * 1000))
end

--- Meters the player has to be within of the boss or a crate
function GetInteractDistance()
  return math.max(1.0, (tonumber(Config.InteractDistance) or 2.0) + 0.0)
end

-------------------------------------------------------------------------------------------------------------------
-- Environment: framework and target
--
-- The server decides, because only the server sees every resource: a client only knows the resources it has
-- mounted already, so a framework ensured after this resource reads "missing" there. A candidate that is
-- installed but not started yet is waited for without a time limit, with a red warning every 10 seconds.
-- The decisions are replicated through GlobalState; clients wait for them and never detect on their own.
-------------------------------------------------------------------------------------------------------------------

local FRAMEWORK_KEY = RESOURCE .. ":framework"
local TARGET_KEY = RESOURCE .. ":target"

-- qbx_core before qb-core: qbx_core `provide`s qb-core, so GetResourceState('qb-core') is "started" on QBox too
local FRAMEWORKS = {
  { name = "qbx", resource = "qbx_core" },
  { name = "esx", resource = "es_extended" },
  { name = "qb",  resource = "qb-core" },
}
local FRAMEWORK_RESOURCES = { qbx = "qbx_core", esx = "es_extended", qb = "qb-core" }

local TARGETS = {
  { name = "ox_target", resource = "ox_target" },
  { name = "qb-target", resource = "qb-target" },
}

local environment = {}    -- framework = { name, resource }, target = "ox_target" | "qb-target" | "none"
local frameworkInits = {} -- [name] = init functions registered by the framework files
local frameworkActive = false
local readyCallbacks = {}

local function IsStartedOrStarting(resource)
  local state = GetResourceState(resource)
  return state == "started" or state == "starting"
end

local function IsInstalled(resource)
  local state = GetResourceState(resource)
  return state ~= "missing" and state ~= "unknown"
end

--- First running candidate, otherwise nil and the candidates that are installed but not started yet
local function FindRunning(list)
  for _, entry in ipairs(list) do
    if IsStartedOrStarting(entry.resource) then return entry end
  end
  local waiting = {}
  for _, entry in ipairs(list) do
    if IsInstalled(entry.resource) then waiting[#waiting + 1] = entry.resource end
  end
  return nil, waiting
end

--- Server only: calls onResolved(entry) once a candidate runs, or onResolved(false) when none is installed.
local function ResolveOnServer(what, list, onResolved)
  local entry, waiting = FindRunning(list)
  if entry or #waiting == 0 then return onResolved(entry or false) end

  CreateThread(function()
    local nextWarning = GetGameTimer() + 10000
    while true do
      Wait(250)
      entry, waiting = FindRunning(list)
      if entry or #waiting == 0 then return onResolved(entry or false) end
      if GetGameTimer() >= nextWarning then
        Log("error", ("Waiting for the %s (%s) to start. Ensure it before %s in server.cfg, or remove it if you " ..
          "don't use it."):format(what, table.concat(waiting, ", "), RESOURCE))
        nextWarning = GetGameTimer() + 10000
      end
    end
  end)
end

local function NormalizeFramework(name)
  if name == "qbcore" then return "qb" end
  if name == "qbox" then return "qbx" end
  return name
end

local function RunSafe(label, fn)
  local ok, err = pcall(fn)
  if not ok then Log("error", ("%s failed: %s"):format(label, tostring(err))) end
end

--- Framework files (server/custom/frameworks, client/custom/frameworks) register their body here. It runs once
--- the framework is known: right away when it already is, otherwise as soon as the server has decided.
--- @param name string "esx" | "qb" | "qbx" | "custom"
--- @param init function
function RegisterFramework(name, init)
  name = NormalizeFramework(name)
  if frameworkActive then
    if Config.Framework == name then RunSafe("Framework file '" .. name .. "'", init) end
    return
  end
  frameworkInits[name] = frameworkInits[name] or {}
  table.insert(frameworkInits[name], init)
end

--- True once the framework is known on this side
function IsFrameworkReady()
  return frameworkActive
end

--- Resource name of the active framework (nil for custom)
function GetFrameworkResource()
  return environment.framework and environment.framework.resource
end

--- "ox_target" | "qb-target" | "none", nil until known
function GetTargetSystem()
  return environment.target
end

local function IsReady()
  return frameworkActive and environment.target ~= nil
end

--- Runs fn once framework and target are known on this side (immediately when they already are)
function OnEnvironmentReady(fn)
  if IsReady() then return RunSafe("Environment callback", fn) end
  readyCallbacks[#readyCallbacks + 1] = fn
end

local function NotifyReady()
  if not IsReady() then return end
  local callbacks = readyCallbacks
  readyCallbacks = {}
  for _, fn in ipairs(callbacks) do RunSafe("Environment callback", fn) end
end

local function ActivateFramework(framework)
  if frameworkActive then return end
  environment.framework = framework
  Config.Framework = framework.name
  frameworkActive = true
  local inits = frameworkInits[framework.name]
  frameworkInits = {}
  for _, init in ipairs(inits or {}) do RunSafe("Framework file '" .. framework.name .. "'", init) end
  Debug("info", "Framework: " .. framework.name)
end

local function SetTarget(target)
  if environment.target ~= nil then return end
  environment.target = target
  Config.Target = target
  Debug("info", "Target: " .. target)
end

local function InitServer()
  local configured = NormalizeFramework(Config.Framework)
  -- Replaces a decision a previous run of this resource left in GlobalState
  GlobalState[FRAMEWORK_KEY] = nil
  GlobalState[TARGET_KEY] = nil

  local function publish()
    GlobalState[FRAMEWORK_KEY] = environment.framework
    GlobalState[TARGET_KEY] = environment.target
    NotifyReady()
  end

  if configured ~= "auto" then
    if configured ~= "custom" and not FRAMEWORK_RESOURCES[configured] then
      Log("error", ("Unknown Config.Framework '%s', using \"auto\""):format(tostring(Config.Framework)))
      configured = "auto"
    end
  end

  if configured == "auto" then
    ResolveOnServer("framework", FRAMEWORKS, function(entry)
      if entry then
        ActivateFramework({ name = entry.name, resource = entry.resource })
      else
        Log("warn", "No supported framework found (qbx_core, es_extended, qb-core), using the custom framework files " ..
          "(server/custom/frameworks/custom.lua, client/custom/frameworks/custom.lua).")
        ActivateFramework({ name = "custom" })
      end
      publish()
    end)
  else
    ActivateFramework({ name = configured, resource = FRAMEWORK_RESOURCES[configured] })
    publish()
  end

  local target = Config.Target
  if target == "auto" then
    ResolveOnServer("target resource", TARGETS, function(entry)
      SetTarget(entry and entry.name or "none")
      publish()
    end)
  else
    if target ~= "ox_target" and target ~= "qb-target" then target = "none" end
    SetTarget(target)
    publish()
  end
end

local function InitClient()
  local function Apply()
    local framework, target = GlobalState[FRAMEWORK_KEY], GlobalState[TARGET_KEY]
    if type(target) == "string" then SetTarget(target) end
    if type(framework) == "table" and type(framework.name) == "string" then ActivateFramework(framework) end
    NotifyReady()
  end

  -- Usually the server decided long before the client joined
  Apply()
  if IsReady() then return end

  AddStateBagChangeHandler(FRAMEWORK_KEY, "global", function() SetTimeout(0, Apply) end)
  AddStateBagChangeHandler(TARGET_KEY, "global", function() SetTimeout(0, Apply) end)

  CreateThread(function()
    local nextWarning = GetGameTimer() + 15000
    while not IsReady() do
      Wait(500)
      Apply()
      if not IsReady() and GetGameTimer() >= nextWarning then
        Log("warn", "Still waiting for the server to detect the framework / target resource (see the server console).")
        nextWarning = GetGameTimer() + 15000
      end
    end
  end)
end

--- Calls getter() until it returns a value. If the framework isn't running on this side yet, waits for it without
--- a time limit and warns every 10 seconds. Runs again when the framework restarts (cached objects go stale).
--- @param resource string
--- @param getter fun(): any
--- @param onLoaded fun(obj: any)
function LoadFrameworkObject(resource, getter, onLoaded)
  local loading = false
  local function load()
    if loading then return end
    loading = true
    CreateThread(function()
      local nextWarning = GetGameTimer() + 10000
      while true do
        if GetResourceState(resource) == "started" then
          local ok, obj = pcall(getter)
          if ok and obj then
            onLoaded(obj)
            loading = false
            return
          end
        end
        if GetGameTimer() >= nextWarning then
          Log("warn", ("Still waiting for %s to start. Ensure it before %s in server.cfg."):format(resource, RESOURCE))
          nextWarning = GetGameTimer() + 10000
        end
        Wait(250)
      end
    end)
  end

  load()
  AddEventHandler(IS_SERVER and "onServerResourceStart" or "onClientResourceStart", function(started)
    if started == resource then load() end
  end)
end

-- Safe defaults until a framework file is active: requests that arrive earlier are refused cleanly
if IS_SERVER then
  function GetIdentifier(source) return nil end
  function CountPolice(jobs, onlyOnDuty) return 0 end
else
  function IsPlayerLoaded() return false end
end

InitLocale()
PrepareBoss()
PrepareMissions()
RunSafe("Environment initialization", IS_SERVER and InitServer or InitClient)
