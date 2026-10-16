-- Runs once force_drugs knows the framework is "esx" (decided by the server). Keep your code inside this function.
RegisterFramework("esx", function()
  local ESX
  local resource = GetFrameworkResource() or "es_extended"
  -- Loaded again when es_extended restarts: the old shared object points at the stopped resource
  LoadFrameworkObject(resource, function()
    return exports[resource]:getSharedObject()
  end, function(obj)
    ESX = obj
  end)

  --- Hides the prompts until a character is loaded; the server checks the player again.
  function IsPlayerLoaded()
    return ESX ~= nil and ESX.IsPlayerLoaded() == true
  end
end)
