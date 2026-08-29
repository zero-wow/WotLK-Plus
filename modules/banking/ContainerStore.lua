local _, AP = ...
AP = AP or _G.AscensionPlus

local Banking = AP.Banking

local Store = {}
Banking.ContainerStore = Store

local function getBagFamily(containerID)
  if containerID == 0 or containerID == -1 then
    return 0
  end

  if type(GetContainerNumFreeSlots) == "function" then
    local ok, _, bagFamily = pcall(GetContainerNumFreeSlots, containerID)
    if ok and bagFamily ~= nil then
      return bagFamily
    end
  end

  local bagName = type(GetBagName) == "function" and GetBagName(containerID)
  return bagName and GetItemFamily(bagName) or nil
end

local function containerAcceptsItem(containerID, itemLink)
  local bagFamily = getBagFamily(containerID)
  if bagFamily == 0 then
    return true
  elseif not bagFamily then
    return false
  end

  local itemFamily = GetItemFamily(itemLink) or 0
  return itemFamily > 0 and bit and bit.band and bit.band(itemFamily, bagFamily) > 0
end

function Store:GetItemID(itemLink)
  return tonumber(tostring(itemLink or ""):match("item:(%-?%d+)"))
end

function Store:GetInventoryContainers()
  local containers = {}
  local lastBag = _G.NUM_BAG_SLOTS or 4
  for containerID = 0, lastBag do
    containers[#containers + 1] = containerID
  end
  return containers
end

function Store:GetCharacterBankContainers()
  local containers = { -1 }
  local purchased = type(GetNumBankSlots) == "function" and GetNumBankSlots() or 0
  for index = 1, purchased do
    containers[#containers + 1] = (_G.NUM_BAG_SLOTS or 4) + index
  end
  return containers
end

function Store:GetLocations(containers)
  local locations = {}
  for index = 1, #containers do
    local containerID = containers[index]
    local slotCount = GetContainerNumSlots(containerID) or 0
    for slotID = 1, slotCount do
      if GetContainerItemLink(containerID, slotID) then
        locations[#locations + 1] = {
          kind = "container",
          containerID = containerID,
          slotID = slotID,
        }
      end
    end
  end
  return locations
end

function Store:GetInventoryLocations()
  return self:GetLocations(self:GetInventoryContainers())
end

function Store:GetCharacterBankLocations()
  return self:GetLocations(self:GetCharacterBankContainers())
end

function Store:GetSnapshot(location)
  if not location or location.kind ~= "container" then
    return nil
  end

  local itemLink = GetContainerItemLink(location.containerID, location.slotID)
  if not itemLink then
    return nil
  end

  local _, count, locked, quality = GetContainerItemInfo(location.containerID, location.slotID)
  return {
    itemLink = itemLink,
    itemID = self:GetItemID(itemLink),
    count = count or 0,
    locked = locked and true or false,
    quality = quality,
  }
end

function Store:GetLocationLabel(location)
  local containerID = location and location.containerID
  local slotID = location and location.slotID or 0
  local lastBag = _G.NUM_BAG_SLOTS or 4

  if containerID == 0 then
    return string.format("Backpack, slot %d", slotID)
  elseif containerID and containerID > 0 and containerID <= lastBag then
    return string.format("Bag %d, slot %d", containerID, slotID)
  elseif containerID == -1 then
    return string.format("Character Bank, slot %d", slotID)
  elseif containerID and containerID > lastBag then
    return string.format("Character Bank bag %d, slot %d", containerID - lastBag, slotID)
  end
  return string.format("Container %s, slot %d", tostring(containerID), slotID)
end

function Store:HasCapacity(itemLink, containers)
  local itemID = self:GetItemID(itemLink)
  local maxStack = select(8, GetItemInfo(itemLink))
  if not itemID or not maxStack then
    return false, "item data is unavailable"
  end

  for index = 1, #containers do
    local containerID = containers[index]
    local slotCount = GetContainerNumSlots(containerID) or 0
    local acceptsEmptySlot = containerAcceptsItem(containerID, itemLink)

    for slotID = 1, slotCount do
      local destinationID = GetContainerItemID(containerID, slotID)
      local _, count, locked = GetContainerItemInfo(containerID, slotID)
      if destinationID == itemID and not locked and (count or 0) < maxStack then
        return true
      elseif not destinationID and not locked and acceptsEmptySlot then
        return true
      end
    end
  end

  return false, "no compatible room"
end

function Store:HasInventoryCapacity(itemLink)
  return self:HasCapacity(itemLink, self:GetInventoryContainers())
end

function Store:HasCharacterBankCapacity(itemLink)
  return self:HasCapacity(itemLink, self:GetCharacterBankContainers())
end
