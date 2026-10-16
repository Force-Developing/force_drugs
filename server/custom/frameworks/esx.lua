-- Runs once force_drugs knows the framework is "esx" (Config.Framework, or detected by the server).
-- Keep your code inside this function.
RegisterFramework("esx", function()
  local ESX
  local resource = GetFrameworkResource() or "es_extended"
  -- Loaded again when es_extended restarts: the old shared object points at the stopped resource
  LoadFrameworkObject(resource, function()
    return exports[resource]:getSharedObject()
  end, function(obj)
    ESX = obj
  end)

  local function getPlayer(source)
    return ESX and ESX.GetPlayerFromId(source)
  end

  --- Character identifier (cooldowns survive a reconnect), nil while the player has no character loaded
  --- @param source number
  --- @return string|nil
  function GetIdentifier(source)
    local xPlayer = getPlayer(source)
    return xPlayer and xPlayer.identifier or nil
  end

  --- Players with one of the police jobs (on duty when onlyOnDuty and the ESX version has job.onDuty)
  --- @param jobs table<string, true>
  --- @param onlyOnDuty boolean
  --- @return number
  function CountPolice(jobs, onlyOnDuty)
    if not ESX then return 0 end
    local players = {}
    if ESX.GetExtendedPlayers then
      players = ESX.GetExtendedPlayers()
    else
      for _, id in ipairs(ESX.GetPlayers()) do players[#players + 1] = ESX.GetPlayerFromId(id) end
    end
    local count = 0
    for _, xPlayer in pairs(players) do
      local job = type(xPlayer) == "table" and xPlayer.job
      if type(job) == "table" and jobs[job.name] and (not onlyOnDuty or job.onDuty ~= false) then
        count = count + 1
      end
    end
    return count
  end

  -- ESX inventory (only used when ox_inventory isn't running). The items must exist in the `items` table.
  local function itemCount(xPlayer, item)
    local data = xPlayer.getInventoryItem(item)
    return type(data) == "table" and tonumber(data.count) or nil
  end

  FrameworkInventory = {
    count = function(source, item)
      local xPlayer = getPlayer(source)
      if not xPlayer then return nil end
      return itemCount(xPlayer, item)
    end,
    canCarry = function(source, item, count)
      local xPlayer = getPlayer(source)
      if not xPlayer then return false end
      if not xPlayer.canCarryItem then return true end
      return xPlayer.canCarryItem(item, count) == true
    end,
    add = function(source, item, count)
      local xPlayer = getPlayer(source)
      if not xPlayer then return false end
      local before = itemCount(xPlayer, item)
      if not before then return false end
      xPlayer.addInventoryItem(item, count)
      return (itemCount(xPlayer, item) or 0) >= before + count
    end,
    remove = function(source, item, count)
      local xPlayer = getPlayer(source)
      if not xPlayer then return false end
      local before = itemCount(xPlayer, item)
      if not before or before < count then return false end
      xPlayer.removeInventoryItem(item, count)
      return (itemCount(xPlayer, item) or before) <= before - count
    end,
  }
end)
