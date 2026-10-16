-- Runs once force_drugs knows the framework is "qbx" (decided by the server). Keep your code inside this function.
RegisterFramework("qbx", function()
  --- Hides the prompts until a character is loaded; the server checks the player again.
  function IsPlayerLoaded()
    return LocalPlayer.state.isLoggedIn == true
  end
end)
