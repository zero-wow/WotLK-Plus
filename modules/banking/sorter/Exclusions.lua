local _, AP = ...
AP = AP or _G.AscensionPlus

local Banking = AP.Banking
local Exclusions = {}

Banking.SorterExclusions = Exclusions

local function normalizeItemID(itemID)
  itemID = tonumber(itemID)
  if not itemID or itemID <= 0 then
    return nil
  end
  return math.floor(itemID)
end

local function itemKey(itemID)
  itemID = normalizeItemID(itemID)
  return itemID and tostring(itemID) or nil
end

local function getItems()
  local items = AP.Database:Get("banking.sorter.exclusions.items", {})
  return type(items) == "table" and items or {}
end

function Exclusions:IsItemBlocked(itemID)
  local key = itemKey(itemID)
  return key and getItems()[key] ~= nil or false
end

function Exclusions:AddItem(itemID, itemLink)
  local key = itemKey(itemID)
  if not key then
    return false, "That cursor item has no usable item ID."
  end

  local items = getItems()
  items[key] = itemLink or true
  AP.Database:Set("banking.sorter.exclusions.items", items)
  return true
end

function Exclusions:RemoveItem(itemID)
  local key = itemKey(itemID)
  if not key then
    return false
  end

  local items = getItems()
  items[key] = nil
  AP.Database:Set("banking.sorter.exclusions.items", items)
  return true
end

function Exclusions:ClearItems()
  AP.Database:Set("banking.sorter.exclusions.items", {})
end

function Exclusions:GetItemEntries()
  local entries = {}
  for key, savedLink in pairs(getItems()) do
    local itemID = normalizeItemID(key)
    if itemID then
      local link = type(savedLink) == "string" and savedLink or nil
      local name, resolvedLink = GetItemInfo(link or itemID)
      entries[#entries + 1] = {
        id = itemID,
        link = resolvedLink or link,
        name = name or ("Item #" .. tostring(itemID)),
      }
    end
  end

  table.sort(entries, function(left, right)
    return tostring(left.name) < tostring(right.name)
  end)
  return entries
end

function Exclusions:GetBagKey(scope, containerID)
  local lastBag = _G.NUM_BAG_SLOTS or 4
  if scope == "inventory" then
    if containerID == 0 then
      return "backpack"
    elseif containerID and containerID >= 1 and containerID <= lastBag then
      return "bag" .. tostring(containerID)
    end
  elseif scope == "character" then
    if containerID == (_G.BANK_CONTAINER or -1) then
      return "main"
    elseif containerID and containerID > lastBag then
      return "bag" .. tostring(containerID - lastBag)
    end
  end
end

function Exclusions:IsBagBlocked(scope, containerID)
  local key = self:GetBagKey(scope, containerID)
  if not key then
    return true
  end
  return AP.Database:Get("banking.sorter.exclusions.bags." .. scope .. "." .. key, false) and true or false
end

function Exclusions:GetSignature(scope)
  local parts = {}
  for key in pairs(getItems()) do
    parts[#parts + 1] = "i" .. tostring(key)
  end

  local bagSettings = AP.Database:Get("banking.sorter.exclusions.bags." .. tostring(scope or ""), {})
  if type(bagSettings) == "table" then
    for key, blocked in pairs(bagSettings) do
      if blocked then
        parts[#parts + 1] = "b" .. tostring(key)
      end
    end
  end
  table.sort(parts)
  return table.concat(parts, ",")
end

