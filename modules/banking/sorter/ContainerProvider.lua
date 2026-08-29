local _, AP = ...
AP = AP or _G.AscensionPlus

local Banking = AP.Banking
local Planner = Banking.SorterPlanner
local Exclusions = Banking.SorterExclusions

Banking.SorterProviders = Banking.SorterProviders or {}

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
  return itemLink and tonumber(itemLink:match("item:(%-?%d+)")) or nil
end

local function isFrameShown(frame)
  return frame and frame.IsShown and frame:IsShown() and true or false
end

local function inventoryFrameShown()
  if isFrameShown(_G.ElvUI_ContainerFrame)
    or isFrameShown(_G.BagnonFrameinventory)
    or isFrameShown(_G.BagnonInventoryFrame)
    or isFrameShown(_G.AdiBagsContainer1) then
    return true
  end

  for index = 1, (_G.NUM_CONTAINER_FRAMES or 13) do
    if isFrameShown(_G["ContainerFrame" .. tostring(index)]) then
      return true
    end
  end
  return false
end

local function characterBankFrameShown()
  return isFrameShown(_G.ElvUI_BankContainerFrame)
    or isFrameShown(_G.BankFrame)
    or isFrameShown(_G.BagnonFramebank)
    or isFrameShown(_G.BagnonBankFrame)
end

local function specialtyBag(containerID)
  if containerID == 0 or containerID == (_G.BANK_CONTAINER or -1) then
    return false
  end

  if type(GetContainerNumFreeSlots) == "function" then
    local ok, _, family = pcall(GetContainerNumFreeSlots, containerID)
    if ok and tonumber(family) and tonumber(family) ~= 0 then
      return true
    end
  end

  if type(ContainerIDToInventoryID) == "function"
    and type(GetInventoryItemLink) == "function"
    and type(GetItemFamily) == "function" then
    local inventoryID = ContainerIDToInventoryID(containerID)
    local bagLink = inventoryID and GetInventoryItemLink("player", inventoryID)
    local family = bagLink and GetItemFamily(bagLink)
    return tonumber(family) and tonumber(family) ~= 0 or false
  end
  return false
end

local function createProvider(id, title)
  local Provider = {
    id = id,
    title = title,
  }

  function Provider:IsOpen()
    if self.id == "character" then
      return characterBankFrameShown()
        or (Banking.Controller and Banking.Controller.normalBankOpen and true or false)
    end
    return inventoryFrameShown()
  end

  function Provider:GetScopeLabel()
    return self.title
  end

  function Provider:GetBankName()
    return self.title
  end

  function Provider:GetContext()
    return self.id
  end

  function Provider:GetToken()
    local parts = { self.id, Exclusions:GetSignature(self.id) }
    local containers = self:GetContainers()
    for index = 1, #containers do
      local containerID = containers[index]
      parts[#parts + 1] = string.format(
        "%s:%s:%s",
        tostring(containerID),
        tostring(GetContainerNumSlots(containerID) or 0),
        specialtyBag(containerID) and "specialty" or "general"
      )
    end
    return table.concat(parts, "|")
  end

  function Provider:GetContainers()
    local containers = {}
    local lastBag = _G.NUM_BAG_SLOTS or 4
    if self.id == "inventory" then
      for containerID = 0, lastBag do
        containers[#containers + 1] = containerID
      end
    else
      containers[1] = _G.BANK_CONTAINER or -1
      local purchased = type(GetNumBankSlots) == "function" and GetNumBankSlots() or 0
      for index = 1, purchased do
        containers[#containers + 1] = lastBag + index
      end
    end
    return containers
  end

  function Provider:CanUse()
    if type(GetContainerNumSlots) ~= "function"
      or type(GetContainerItemInfo) ~= "function"
      or type(GetContainerItemLink) ~= "function"
      or type(PickupContainerItem) ~= "function" then
      return false, "The container sorting API is unavailable on this client."
    elseif self.id == "character" and not self:IsOpen() then
      return false, "Open your Character Bank first."
    end
    return true
  end

  function Provider:ReadLocation(location)
    if not location then
      return nil, false
    end

    local itemLink = GetContainerItemLink(location.containerID, location.slotID)
    local _, count, locked, quality = GetContainerItemInfo(location.containerID, location.slotID)
    locked = locked and true or false
    if not itemLink then
      return nil, locked
    end

    local itemID = itemIDFromLink(itemLink)
    local name, _, resolvedQuality, itemLevel, _, itemType, itemSubType, maxStack, equipLoc = GetItemInfo(itemLink)
    return {
      originalSlot = location.logicalSlot,
      itemID = itemID,
      itemLink = itemLink,
      stackKey = itemString(itemLink),
      count = tonumber(count) or 1,
      maxStack = math.max(tonumber(maxStack) or 1, 1),
      name = name or itemLink:match("%[(.-)%]") or tostring(itemID or "Unknown"),
      quality = tonumber(resolvedQuality) or tonumber(quality) or 0,
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

    local snapshot = {
      context = self.id,
      token = self:GetToken(),
      locations = {},
      slots = {},
      lockedSlots = 0,
      excludedItems = 0,
      excludedBags = 0,
      specialtyBags = 0,
    }

    local containers = self:GetContainers()
    for index = 1, #containers do
      local containerID = containers[index]
      local blocked = Exclusions:IsBagBlocked(self.id, containerID)
      local specialty = not blocked and specialtyBag(containerID)
      if blocked or specialty then
        snapshot.excludedBags = snapshot.excludedBags + 1
        if specialty then
          snapshot.specialtyBags = snapshot.specialtyBags + 1
        end
      else
        local slotCount = GetContainerNumSlots(containerID) or 0
        for slotID = 1, slotCount do
          local itemLink = GetContainerItemLink(containerID, slotID)
          local itemID = itemIDFromLink(itemLink)
          if itemID and Exclusions:IsItemBlocked(itemID) then
            snapshot.excludedItems = snapshot.excludedItems + 1
          else
            local logicalSlot = #snapshot.locations + 1
            local location = {
              kind = "container",
              containerID = containerID,
              slotID = slotID,
              logicalSlot = logicalSlot,
            }
            snapshot.locations[logicalSlot] = location
            local item, locked = self:ReadLocation(location)
            snapshot.slots[logicalSlot] = item
            if locked then
              snapshot.lockedSlots = snapshot.lockedSlots + 1
            end
          end
        end
      end
    end

    snapshot.slotCount = #snapshot.locations
    if snapshot.slotCount == 0 then
      return nil, "No movable slots remain after bag and item exclusions."
    end
    return snapshot
  end

  function Provider:ResolveLocation(operation, key)
    return operation and operation[key .. "Location"]
  end

  function Provider:ReadOperationSlots(_, operation)
    local source, sourceLocked = self:ReadLocation(self:ResolveLocation(operation, "source"))
    local target, targetLocked = self:ReadLocation(self:ResolveLocation(operation, "target"))
    return source, target, sourceLocked or targetLocked
  end

  function Provider:OperationMatches(context, operation, phase, ignoreLocks)
    local source, target, locked = self:ReadOperationSlots(context, operation)
    if locked and not ignoreLocks then
      return false, true
    end

    local expectedSource = phase == "after" and operation.afterSource or operation.beforeSource
    local expectedTarget = phase == "after" and operation.afterTarget or operation.beforeTarget
    return Planner:ItemsMatch(source, expectedSource) and Planner:ItemsMatch(target, expectedTarget), locked
  end

  function Provider:HasCursorItem()
    return cursorItem()
  end

  function Provider:CompleteCursor(_, operation)
    local occupied, cursorID, cursorLink = cursorItem()
    if not occupied then
      return true
    end

    local source, target, locked = self:ReadOperationSlots(nil, operation)
    if locked then
      return true, "locked"
    end

    local cursorKey = itemString(cursorLink)
    local function cursorMatches(item)
      if not item then
        return false
      elseif cursorKey and item.stackKey then
        return cursorKey == item.stackKey
      end
      return cursorID and cursorID == item.itemID
    end

    local destination
    if cursorMatches(operation.afterTarget) and not Planner:ItemsMatch(target, operation.afterTarget) then
      destination = self:ResolveLocation(operation, "target")
    elseif cursorMatches(operation.afterSource) and not Planner:ItemsMatch(source, operation.afterSource) then
      destination = self:ResolveLocation(operation, "source")
    elseif cursorMatches(operation.beforeSource) then
      destination = self:ResolveLocation(operation, "target")
    elseif cursorMatches(operation.beforeTarget) then
      destination = self:ResolveLocation(operation, "source")
    end

    if not destination then
      return false, "The cursor item does not match the active sort move."
    end

    local ok, moveError = pcall(PickupContainerItem, destination.containerID, destination.slotID)
    return ok, ok and nil or tostring(moveError)
  end

  function Provider:Execute(context, operation)
    if cursorItem() then
      return false, "Clear the cursor before sorting."
    end

    local matches, locked = self:OperationMatches(context, operation, "before")
    if locked then
      return false, "locked"
    elseif not matches then
      return false, "stale"
    end

    local source = self:ResolveLocation(operation, "source")
    local target = self:ResolveLocation(operation, "target")
    local ok, moveError
    if operation.kind == "stack" and operation.amount < operation.beforeSource.count then
      if type(SplitContainerItem) ~= "function" then
        return false, "The split-stack API is unavailable."
      end
      ok, moveError = pcall(SplitContainerItem, source.containerID, source.slotID, operation.amount)
    else
      ok, moveError = pcall(PickupContainerItem, source.containerID, source.slotID)
    end
    if not ok then
      return false, tostring(moveError)
    end

    if cursorItem() then
      ok, moveError = pcall(PickupContainerItem, target.containerID, target.slotID)
      if not ok then
        return false, tostring(moveError)
      end
    end

    if cursorItem() then
      return self:CompleteCursor(context, operation)
    end
    return true
  end

  function Provider:Query()
    return false
  end

  function Provider:GetResponseTimeout()
    return self.id == "character" and 1.15 or 0.85
  end

  function Provider:GetRefreshInterval()
    return 0.50
  end

  return Provider
end

Banking.SorterProviders.inventory = createProvider("inventory", "Inventory")
Banking.SorterProviders.character = createProvider("character", "Character Bank")
Banking.InventorySorterProvider = Banking.SorterProviders.inventory
Banking.CharacterSorterProvider = Banking.SorterProviders.character
