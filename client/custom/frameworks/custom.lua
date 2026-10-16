-- Runs once force_drugs knows the framework is "custom": Config.Framework = "custom", or "auto" when none
-- of qbx_core, es_extended and qb-core is installed. Keep your code inside this function.
RegisterFramework("custom", function()
  --- Optional: return false while the player has no character loaded (hides the prompts).
  function IsPlayerLoaded()
    return true
  end
end)
