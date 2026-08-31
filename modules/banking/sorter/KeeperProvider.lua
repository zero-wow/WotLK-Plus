local _, AP = ...
AP = AP or _G.Levo or _G.WotLKPlus or _G.AscensionPlus

local Banking = AP.Banking
local Store = Banking.ContainerStore
local Planner = Banking.SorterPlanner
local Exclusions = Banking.SorterExclusions or {
  GetSignature = function()
    return ""
  end,
  IsItemBlocked = function()
    return false
  end,
  IsQualityIgnored = function()
    return false
  end,
  GetPlanningRules = function()
    return {}
  end,
}
local Provider = {
  id = "keeper",
}

Banking.KeeperSorterProvider = Provider
Banking.SorterProviders = Banking.SorterProviders or {}
Banking.SorterProviders.keeper = Provider

local function readFrameFlag(frame, key)
  if not frame then
    return false
  end

  local value = frame[key]
  if type(value) == "function" then
    local ok, result = pcall(value, frame)
    return ok and result and true or false
  end
  return value and true or false
end

local function cursorItem()
  if type(GetCursorInfo) == "function" then
    local cursorType, itemID, itemLink = GetCursorInfo()
    if cursorType == "item" then
      return true, tonumber(itemID), itemLink
    end
    return false
  end
  return type(CursorHasItem) == "function" and CursorHasItem() and true or false
end

local function itemString(itemLink)
  if not itemLink then
    return nil
  end
  return itemLink:match("|H(item:[^|]+)|h") or itemLink:match("(item:[^|]+)") or itemLink
end

local function itemIDFromLink(itemLink)
  if Store and Store.GetItemID then
    return Store:GetItemID(itemLink)
  end
  return itemLink and tonumber(itemLink:match("item:(%-?%d+)")) or nil
end

function Provider:GetMode()
  local frame = _G.GuildBankFrame
  if readFrameFlag(frame, "IsPersonalBank") then
    return "personal"
  elseif readFrameFlag(frame, "IsRealmBank") then
    return "realm"
  end
  return "guild"
end

function Provider:IsKeeperMode()
  local mode = self:GetMode()
  return mode == "personal" or mode == "realm"
end

function Provider:GetBankName()
  return self:GetMode() == "realm" and "Realm Bank" or "Personal Bank"
end

function Provider:GetScopeLabel()
  return string.format("%s tab %d", self:GetBankName(), self:GetTab() or 0)
end

function Provider:GetContext()
  return self:GetTab()
end

function Provider:GetTab()
  return type(GetCurrentGuildBankTab) == "function" and GetCurrentGuildBankTab() or nil
end

function Provider:GetToken()
  local frameMode = _G.GuildBankFrame and _G.GuildBankFrame.mode or "bank"
  return string.format(
    "%s:%s:%s:%s",
    self:GetMode(),
    tostring(self:GetTab() or 0),
    tostring(frameMode),
    Exclusions:GetSignature("keeper")
  )
end

function Provider:IsOpen()
  local frame = _G.GuildBankFrame
  return frame and frame:IsShown() and self:IsKeeperMode() and (not frame.mode or frame.mode == "bank")
end

function Provider:CanUse()
  if type(GetGuildBankItemInfo) ~= "function"
    or type(GetGuildBankItemLink) ~= "function"
    or type(PickupGuildBankItem) ~= "function" then
    return false, "The Keeper bank API is unavailable on this client."
  end

  local frame = _G.GuildBankFrame
  if not frame or not frame:IsShown() then
    return false, "Open a Personal or Realm Keeper Bank first."
  elseif not self:IsKeeperMode() then
    return false, "This server-specific sorter is limited to Personal and Realm Keeper Banks."
  elseif frame.mode and frame.mode ~= "bank" then
    return false, "Select the Keeper bank's item view first."
  end

  local tab = self:GetTab()
  if not tab or tab < 1 then
    return false, "Select a Keeper bank tab first."
  end

  local _, _, isViewable = GetGuildBankTabInfo(tab)
  if not isViewable then
    return false, "The selected Keeper bank tab is not viewable."
  end
  return true
end

function Provider:ReadSlot(tab, slotID)
  local itemLink = GetGuildBankItemLink(tab, slotID)
  local _, count, locked = GetGuildBankItemInfo(tab, slotID)
  locked = locked and true or false
  if not itemLink then
    return nil, locked
  end

  local itemID = itemIDFromLink(itemLink)
  local name, _, quality, itemLevel, _, itemType, itemSubType, maxStack, equipLoc = GetItemInfo(itemLink)
  return {
    slot = slotID,
    originalSlot = slotID,
    itemID = itemID,
    itemLink = itemLink,
    stackKey = itemString(itemLink),
    count = tonumber(count) or 1,
    maxStack = math.max(tonumber(maxStack) or 1, 1),
    name = name or itemLink:match("%[(.-)%]") or tostring(itemID or "Unknown"),
    quality = tonumber(quality) or 0,
    itemLevel = tonumber(itemLevel) or 0,
    itemType = itemType or "",
    itemSubType = itemSubType or "",
    equipLoc = equipLoc or "",
    locked = locked,
  }, locked
end

function Provider:TakeSnapshot()
  local canUse, reason = self:CanUse()
  if not canUse then
    return nil, reason
  end

  local tab = self:GetTab()
  local rawSlotCount = _G.MAX_GUILDBANK_SLOTS_PER_TAB or 98
  local snapshot = {
    tab = tab,
    context = tab,
    token = self:GetToken(),
    locations = {},
    slots = {},
    lockedSlots = 0,
    excludedItems = 0,
    excludedQualities = 0,
    excludedBags = 0,
    specialtyBags = 0,
    slotGroups = {},
    qualityRules = Exclusions:GetPlanningRules("keeper"),
  }

  for slotID = 1, rawSlotCount do
    local item, locked = self:ReadSlot(tab, slotID)
    if item and Exclusions:IsItemBlocked(item.itemID) then
      snapshot.excludedItems = snapshot.excludedItems + 1
    elseif item and Exclusions:IsQualityIgnored(item.quality) then
      snapshot.excludedQualities = snapshot.excludedQualities + 1
    else
      local logicalSlot = #snapshot.locations + 1
      snapshot.locations[logicalSlot] = slotID
      snapshot.slotGroups[logicalSlot] = "keeper"
      snapshot.slots[logicalSlot] = item
      if item then
        item.originalSlot = logicalSlot
      end
      if locked then
        snapshot.lockedSlots = snapshot.lockedSlots + 1
      end
    end
  end
  snapshot.slotCount = #snapshot.locations
  return snapshot
end

function Provider:ReadOperationSlots(tab, operation)
  local sourceSlot = operation.sourceLocation or operation.sourceSlot
  local targetSlot = operation.targetLocation or operation.targetSlot
  local source, sourceLocked = self:ReadSlot(tab, sourceSlot)
  local target, targetLocked = self:ReadSlot(tab, targetSlot)
  return source, target, sourceLocked or targetLocked
end

function Provider:OperationMatches(tab, operation, phase, ignoreLocks)
  local source, target, locked = self:ReadOperationSlots(tab, operation)
  if locked and not ignoreLocks then
    return false, true
  end

  local expectedSource
  local expectedTarget
  if phase == "after" then
    expectedSource = operation.afterSource
    expectedTarget = operation.afterTarget
  else
    expectedSource = operation.beforeSource
    expectedTarget = operation.beforeTarget
  end
  return Planner:ItemsMatch(source, expectedSource) and Planner:ItemsMatch(target, expectedTarget), locked
end

function Provider:HasCursorItem()
  return cursorItem()
end

function Provider:CompleteCursor(tab, operation)
  local occupied, cursorID, cursorLink = cursorItem()
  if not occupied then
    return true
  end

  local source, target, locked = self:ReadOperationSlots(tab, operation)
  if locked then
    return true, "locked"
  end

  local cursorKey = itemString(cursorLink)
  local function cursorMatches(item)
    if not item then
      return false
    end
    if cursorKey and item.stackKey then
      return cursorKey == item.stackKey
    end
    return cursorID and cursorID == item.itemID
  end

  local destination
  if cursorMatches(operation.afterTarget) and not Planner:ItemsMatch(target, operation.afterTarget) then
    destination = operation.targetLocation or operation.targetSlot
  elseif cursorMatches(operation.afterSource) and not Planner:ItemsMatch(source, operation.afterSource) then
    destination = operation.sourceLocation or operation.sourceSlot
  elseif cursorMatches(operation.beforeSource) then
    destination = operation.targetLocation or operation.targetSlot
  elseif cursorMatches(operation.beforeTarget) then
    destination = operation.sourceLocation or operation.sourceSlot
  end

  if not destination then
    return false, "The cursor item does not match the active sort move."
  end

  local ok, moveError = pcall(PickupGuildBankItem, tab, destination)
  if not ok then
    return false, tostring(moveError)
  end
  return true
end

function Provider:Execute(tab, operation)
  if cursorItem() then
    return false, "Clear the cursor before sorting."
  end

  local matches, locked = self:OperationMatches(tab, operation, "before")
  if locked then
    return false, "locked"
  elseif not matches then
    return false, "stale"
  end

  local ok, moveError
  local sourceSlot = operation.sourceLocation or operation.sourceSlot
  local targetSlot = operation.targetLocation or operation.targetSlot
  if operation.kind == "stack" and operation.amount < operation.beforeSource.count then
    if type(SplitGuildBankItem) ~= "function" then
      return false, "The Keeper split-stack API is unavailable."
    end
    ok, moveError = pcall(SplitGuildBankItem, tab, sourceSlot, operation.amount)
  else
    ok, moveError = pcall(PickupGuildBankItem, tab, sourceSlot)
  end
  if not ok then
    return false, tostring(moveError)
  end

  if cursorItem() then
    ok, moveError = pcall(PickupGuildBankItem, tab, targetSlot)
    if not ok then
      return false, tostring(moveError)
    end
  end

  if cursorItem() then
    local completed, completionError = self:CompleteCursor(tab, operation)
    if not completed then
      return false, completionError
    end
  end
  return true
end

function Provider:Query(tab)
  if type(QueryGuildBankTab) ~= "function" then
    return false
  end
  return pcall(QueryGuildBankTab, tab)
end

function Provider:GetResponseTimeout()
  return 1.25
end

function Provider:GetRefreshInterval()
  return 0.75
end
