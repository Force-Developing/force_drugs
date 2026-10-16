-- Item access for the reward. ox_inventory is used whenever it runs (any framework); otherwise the framework
-- file's FrameworkInventory (ESX inventory, qb-inventory). Every function is safe to call at any time.

local warned = {}

local function warnOnce(key, message)
  if warned[key] then return end
  warned[key] = true
  Log("error", message)
end

local function useOx()
  return GetResourceState("ox_inventory") == "started"
end

local function framework()
  if type(FrameworkInventory) == "table" then return FrameworkInventory end
  warnOnce("no_inventory", "No inventory found: run ox_inventory, or fill in FrameworkInventory in " ..
    "server/custom/frameworks/custom.lua")
  return nil
end

--- @return number|nil count, nil when the inventory can't tell
function GetItemCount(source, item)
  if useOx() then
    local ok, count = pcall(function() return exports.ox_inventory:GetItemCount(source, item) end)
    if ok then return tonumber(count) or 0 end
    Log("error", ("ox_inventory GetItemCount failed: %s"):format(tostring(count)))
    return nil
  end
  local inv = framework()
  if not inv then return nil end
  local ok, count = pcall(inv.count, source, item)
  if not ok then Log("error", ("Reading item '%s' failed: %s"):format(item, tostring(count))) return nil end
  if count == nil then
    warnOnce("missing:" .. item, ("Item '%s' doesn't exist in your inventory. Add it (see the items folder)."):format(item))
  end
  return count
end

--- @return boolean
function CanCarryItem(source, item, count)
  if useOx() then
    local ok, result = pcall(function() return exports.ox_inventory:CanCarryItem(source, item, count) end)
    if not ok then Log("error", ("ox_inventory CanCarryItem failed: %s"):format(tostring(result))) return false end
    return result == true
  end
  local inv = framework()
  if not inv then return false end
  local ok, result = pcall(inv.canCarry, source, item, count)
  if not ok then Log("error", ("Checking item '%s' failed: %s"):format(item, tostring(result))) return false end
  return result == true
end

--- @return boolean added
function AddItem(source, item, count)
  if useOx() then
    local ok, success, response = pcall(function() return exports.ox_inventory:AddItem(source, item, count) end)
    if not ok then Log("error", ("ox_inventory AddItem failed: %s"):format(tostring(success))) return false end
    if not success and response == "invalid_item" then
      warnOnce("missing:" .. item, ("Item '%s' doesn't exist in ox_inventory. Add it (see the items folder)."):format(item))
    end
    return success == true
  end
  local inv = framework()
  if not inv then return false end
  local ok, added = pcall(inv.add, source, item, count)
  if not ok then Log("error", ("Adding item '%s' failed: %s"):format(item, tostring(added))) return false end
  if not added then
    Debug("warn", "Item '%s' x%s could not be added to %s (full inventory or unknown item)", item, count, source)
  end
  return added == true
end

--- @return boolean removed
function RemoveItem(source, item, count)
  if useOx() then
    local ok, success = pcall(function() return exports.ox_inventory:RemoveItem(source, item, count) end)
    if not ok then Log("error", ("ox_inventory RemoveItem failed: %s"):format(tostring(success))) return false end
    return success == true
  end
  local inv = framework()
  if not inv then return false end
  local ok, removed = pcall(inv.remove, source, item, count)
  if not ok then Log("error", ("Removing item '%s' failed: %s"):format(item, tostring(removed))) return false end
  return removed == true
end
