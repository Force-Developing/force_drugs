-- Runs once force_drugs knows the framework is "qbx" (Config.Framework, or detected by the server).
-- Keep your code inside this function. Items go through ox_inventory (server/custom/inventory.lua).
RegisterFramework("qbx", function()
  local function getPlayer(source)
    if GetResourceState("qbx_core") ~= "started" then return nil end
    local ok, player = pcall(function() return exports.qbx_core:GetPlayer(source) end)
    return ok and player or nil
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
    if GetResourceState("qbx_core") ~= "started" then return 0 end
    local ok, players = pcall(function() return exports.qbx_core:GetQBPlayers() end)
    if not ok or type(players) ~= "table" then return 0 end
    local count = 0
    for _, player in pairs(players) do
      local job = player.PlayerData and player.PlayerData.job
      if type(job) == "table" and jobs[job.name] and (not onlyOnDuty or job.onduty) then count = count + 1 end
    end
    return count
  end
end)
