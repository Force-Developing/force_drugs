-- Runs once force_drugs knows the framework is "custom": Config.Framework = "custom", or "auto" when none
-- of qbx_core, es_extended and qb-core is installed. Keep your code inside this function.
RegisterFramework("custom", function()
  --- TODO: a stable id of the player's character (cooldowns are stored per id). nil while no character is loaded:
  --- nobody can take a job until this returns something.
  --- @param source number
  --- @return string|nil
  function GetIdentifier(source)
    return nil
  end

  --- TODO: number of players with one of the police jobs. Only used when Config.Police.minimum > 0.
  --- @param jobs table<string, true> e.g. { police = true }
  --- @param onlyOnDuty boolean
  --- @return number
  function CountPolice(jobs, onlyOnDuty)
    return 0
  end

  -- With ox_inventory running nothing else is needed. For another inventory, fill these in:
  -- FrameworkInventory = {
  --   count = function(source, item) return 0 end,               -- number, nil when unknown
  --   canCarry = function(source, item, count) return true end,
  --   add = function(source, item, count) return false end,     -- true only when the items were added
  --   remove = function(source, item, count) return false end,  -- true only when the items were removed
  -- }
end)
