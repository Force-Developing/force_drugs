-- Runs once force_drugs knows the framework is "qb" (Config.Framework, or detected by the server).
-- Keep your code inside this function.
RegisterFramework("qb", function()
  local QBCore
  local resource = GetFrameworkResource() or "qb-core"
  -- Loaded again when qb-core restarts: the old core object points at the stopped resource
  LoadFrameworkObject(resource, function()
    return exports[resource]:GetCoreObject()
  end, function(obj)
    QBCore = obj
  end)

  local function getPlayer(source)
    return QBCore and QBCore.Functions.GetPlayer(source)
  end

  --- Citizen id (cooldowns survive a reconnect), nil while the player has no character loaded
  --- @param source number
  --- @return string|nil
  function GetIdentifier(source)
    local player = getPlayer(source)
    return player and player.PlayerData and player.PlayerData.citizenid or nil
  end

  --- Players with one of the police jobs (on duty when onlyOnDuty)
  --- @param jobs table<string, true>
  --- @param onlyOnDuty boolean
  --- @return number
  function CountPolice(jobs, onlyOnDuty)
    if not QBCore then return 0 end
    local count = 0
    for _, player in pairs(QBCore.Functions.GetQBPlayers() or {}) do
      local job = player.PlayerData and player.PlayerData.job
      if type(job) == "table" and jobs[job.name] and (not onlyOnDuty or job.onduty) then count = count + 1 end
    end
    return count
  end

  local function itemBox(source, item, action, count)
    local shared = QBCore and QBCore.Shared and QBCore.Shared.Items
    if type(shared) == "table" and shared[item] then
      TriggerClientEvent("qb-inventory:client:ItemBox", source, shared[item], action, count)
    end
  end

  -- qb-inventory through the core player functions (only used when ox_inventory isn't running).
  -- The items must exist in qb-core/shared/items.lua.
  FrameworkInventory = {
    count = function(source, item)
      local player = getPlayer(source)
      if not player then return nil end
      local total = 0
      local slots = player.Functions.GetItemsByName and player.Functions.GetItemsByName(item)
      if type(slots) ~= "table" then
        local slot = player.Functions.GetItemByName(item)
        slots = slot and { slot } or {}
      end
      for _, slot in pairs(slots) do total = total + (tonumber(slot.amount or slot.count) or 0) end
      return total
    end,
    canCarry = function(source, item, count)
      if GetResourceState("qb-inventory") ~= "started" then return true end
      local ok, result = pcall(function() return exports["qb-inventory"]:CanAddItem(source, item, count) end)
      -- qb-inventory 1.x has no CanAddItem: AddItem below still refuses a full inventory
      if not ok then return true end
      return result ~= false
    end,
    add = function(source, item, count)
      local player = getPlayer(source)
      if not player then return false end
      local added = player.Functions.AddItem(item, count) ~= false
      if added then itemBox(source, item, "add", count) end
      return added
    end,
    remove = function(source, item, count)
      local player = getPlayer(source)
      if not player then return false end
      local removed = player.Functions.RemoveItem(item, count) ~= false
      if removed then itemBox(source, item, "remove", count) end
      return removed
    end,
  }
end)
