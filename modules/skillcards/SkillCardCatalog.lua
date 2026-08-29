local _, AP = ...
AP = AP or _G.AscensionPlus

if not AP then
  return
end

AP.SkillCards = AP.SkillCards or {}

local Catalog = {
  snapshot = nil,
  revision = 0,
  exchangeFrame = nil,
}

AP.SkillCards.Catalog = Catalog

local REQUIRED_EXCHANGE_COUNT = 5
local KIND_ORDER = {
  normal = 1,
  lucky = 2,
  golden = 3,
  goldenLucky = 4,
}

local KIND_CONFIG = {
  normal = {
    label = "Normal",
    group = "standard",
    button = "buttonNormal",
  },
  lucky = {
    label = "Lucky",
    group = "standard",
    button = "buttonNormalLucky",
  },
  golden = {
    label = "Golden",
    group = "golden",
    button = "buttonGold",
  },
  goldenLucky = {
    label = "Golden Lucky",
    group = "golden",
    button = "buttonGoldLucky",
  },
}

Catalog.KIND_ORDER = KIND_ORDER
Catalog.REQUIRED_EXCHANGE_COUNT = REQUIRED_EXCHANGE_COUNT

local function safeCall(fn, ...)
  if type(fn) ~= "function" then
    return false, "function unavailable"
  end
  return pcall(fn, ...)
end

local function now()
  if type(GetTime) == "function" then
    local ok, value = pcall(GetTime)
    if ok then
      return value
    end
  end
  return 0
end

local function inCombat()
  return type(InCombatLockdown) == "function" and InCombatLockdown() and true or false
end

local function emptyCounts()
  return {
    normal = 0,
    lucky = 0,
    golden = 0,
    goldenLucky = 0,
  }
end

local function newAggregate()
  return {
    copies = 0,
    uniqueIDs = 0,
    slots = 0,
    ids = {},
  }
end

local function newAggregateSet()
  return {
    total = newAggregate(),
    byKind = {
      normal = newAggregate(),
      lucky = newAggregate(),
      golden = newAggregate(),
      goldenLucky = newAggregate(),
    },
    groups = {
      standard = newAggregate(),
      golden = newAggregate(),
    },
  }
end

local function addToAggregate(aggregate, itemID, copies)
  copies = tonumber(copies) or 1
  aggregate.copies = aggregate.copies + copies
  aggregate.slots = aggregate.slots + 1

  if aggregate.ids[itemID] == nil then
    aggregate.ids[itemID] = copies
    aggregate.uniqueIDs = aggregate.uniqueIDs + 1
  else
    aggregate.ids[itemID] = aggregate.ids[itemID] + copies
  end
end

local function addToAggregateSet(aggregateSet, record)
  local config = KIND_CONFIG[record.kind]
  addToAggregate(aggregateSet.total, record.itemID, record.count)
  addToAggregate(aggregateSet.byKind[record.kind], record.itemID, record.count)
  addToAggregate(aggregateSet.groups[config.group], record.itemID, record.count)
end

local function parseItemID(link)
  if type(link) ~= "string" then
    return nil
  end
  return tonumber(link:match("item:(%d+)"))
end

local function parseLinkName(link)
  if type(link) ~= "string" then
    return nil
  end
  return link:match("%[(.-)%]")
end

local function getContainerLink(bag, slot, infoLink)
  if type(infoLink) == "string" and infoLink ~= "" then
    return infoLink
  end
  if type(GetContainerItemLink) == "function" then
    local ok, link = pcall(GetContainerItemLink, bag, slot)
    if ok then
      return link
    end
  end
end

local function getItemDetails(itemID, itemLink, containerTexture, containerQuality)
  local name
  local resolvedLink
  local quality
  local texture

  if type(GetItemInfo) == "function" then
    local ok
    local itemLevel
    local requiredLevel
    local itemClass
    local itemSubClass
    local maxStack
    local equipSlot
    ok, name, resolvedLink, quality, itemLevel, requiredLevel, itemClass, itemSubClass, maxStack, equipSlot, texture =
      pcall(GetItemInfo, itemLink or itemID)
    if not ok then
      name = nil
      resolvedLink = nil
      quality = nil
      texture = nil
    end
  end

  return {
    name = name or parseLinkName(itemLink) or ("Item #" .. tostring(itemID)),
    link = resolvedLink or itemLink,
    quality = quality ~= nil and quality or containerQuality,
    texture = texture or containerTexture,
  }
end

local function normalizeCount(value)
  local count = tonumber(value)
  if not count or count < 1 or count ~= math.floor(count) then
    return nil, "occupied slot has an invalid stack count"
  end
  return count
end

local function classifierMatched(value)
  return value ~= nil and value ~= false
end

local function classifierGolden(value, nameSaysGolden)
  if type(value) == "table" and value.isGolden ~= nil then
    return value.isGolden and true or false
  end
  return nameSaysGolden
end

local function classifyCard(itemID, itemName)
  local lowerName = string.lower(tostring(itemName or ""))
  local nameSaysCard = lowerName:find("skill card", 1, true) ~= nil
  local nameSaysLucky = lowerName:find("lucky", 1, true) ~= nil
  local nameSaysGolden = lowerName:find("golden", 1, true) ~= nil

  local normalOk, normalCard = safeCall(GetSkillCard, itemID)
  local luckyOk, luckyCard = safeCall(GetLuckyCard, itemID)

  if luckyOk and classifierMatched(luckyCard) then
    if classifierGolden(luckyCard, nameSaysGolden) then
      return "goldenLucky", "api"
    end
    return "lucky", "api"
  end

  if normalOk and classifierMatched(normalCard) then
    if classifierGolden(normalCard, nameSaysGolden) then
      return "golden", "api"
    end
    return "normal", "api"
  end

  if not nameSaysCard then
    return nil
  end
  if nameSaysGolden and nameSaysLucky then
    return "goldenLucky", "name"
  end
  if nameSaysGolden then
    return "golden", "name"
  end
  if nameSaysLucky then
    return "lucky", "name"
  end
  return "normal", "name"
end

local function inspectSlot(bag, slot)
  local texture
  local count
  local locked
  local containerQuality
  local readable
  local lootable
  local infoLink

  local infoOk
  infoOk, texture, count, locked, containerQuality, readable, lootable, infoLink =
    safeCall(GetContainerItemInfo, bag, slot)
  if not infoOk then
    return nil, tostring(texture)
  end

  local itemID
  if type(GetContainerItemID) == "function" then
    local idOk, resolvedID = pcall(GetContainerItemID, bag, slot)
    if idOk then
      itemID = tonumber(resolvedID)
    end
  end

  local itemLink = getContainerLink(bag, slot, infoLink)
  itemID = itemID or parseItemID(itemLink)
  local occupied = itemID ~= nil
    or texture ~= nil
    or count ~= nil
    or locked ~= nil
    or containerQuality ~= nil
    or itemLink ~= nil
  if not itemID or itemID <= 0 then
    if occupied then
      return nil, "occupied slot has no resolvable item ID"
    end
    return nil
  end

  local stackCount, countError = normalizeCount(count)
  if not stackCount then
    return nil, countError
  end

  local details = getItemDetails(itemID, itemLink, texture, containerQuality)
  local kind, classificationSource = classifyCard(itemID, details.name)
  if not kind then
    return nil
  end

  return {
    bag = bag,
    slot = slot,
    itemID = itemID,
    name = details.name,
    link = details.link,
    texture = details.texture,
    quality = details.quality,
    count = stackCount,
    locked = locked and true or false,
    readable = readable,
    lootable = lootable,
    kind = kind,
    group = KIND_CONFIG[kind].group,
    classificationSource = classificationSource,
  }
end

local function getOwnership(itemID, cache, ownershipFunction)
  local cached = cache[itemID]
  if cached then
    return cached.known, cached.owned, cached.error
  end

  local result = {
    known = false,
    owned = nil,
    error = nil,
  }

  if type(ownershipFunction) ~= "function" then
    result.error = "C_VanityCollection.IsCollectionItemOwned is unavailable"
  else
    local ok, owned = pcall(ownershipFunction, itemID)
    if not ok then
      result.error = tostring(owned)
    elseif owned == nil then
      result.error = "Ascension ownership data is not initialized"
    else
      result.known = true
      result.owned = owned and true or false
    end
  end

  cache[itemID] = result
  return result.known, result.owned, result.error
end

local function ownershipSortRank(record)
  if record.ownershipKnown and record.owned == false then
    return 1
  end
  if not record.ownershipKnown then
    return 2
  end
  return 3
end

local function sortRecords(left, right)
  local leftRank = ownershipSortRank(left)
  local rightRank = ownershipSortRank(right)
  if leftRank ~= rightRank then
    return leftRank < rightRank
  end

  local leftKind = KIND_ORDER[left.kind] or 99
  local rightKind = KIND_ORDER[right.kind] or 99
  if leftKind ~= rightKind then
    return leftKind < rightKind
  end

  local leftQuality = tonumber(left.quality) or -1
  local rightQuality = tonumber(right.quality) or -1
  if leftQuality ~= rightQuality then
    return leftQuality > rightQuality
  end

  local leftName = string.lower(tostring(left.name or ""))
  local rightName = string.lower(tostring(right.name or ""))
  if leftName ~= rightName then
    return leftName < rightName
  end
  if left.itemID ~= right.itemID then
    return left.itemID < right.itemID
  end
  if left.bag ~= right.bag then
    return left.bag < right.bag
  end
  return left.slot < right.slot
end

function Catalog:Scan(source)
  local snapshot = {
    source = source or "manual",
    createdAt = now(),
    scanReady = type(GetContainerNumSlots) == "function" and type(GetContainerItemInfo) == "function",
    scanError = nil,
    ownershipReady = type(C_VanityCollection) == "table"
      and type(C_VanityCollection.IsCollectionItemOwned) == "function",
    ownershipError = nil,
    cards = {},
    counts = emptyCounts(),
    totalCount = 0,
    scannedSlots = 0,
    occupiedCardSlots = 0,
    unknown = newAggregateSet(),
    uncertain = newAggregateSet(),
  }
  snapshot.entries = snapshot.cards
  snapshot.unknownByKind = snapshot.unknown.byKind
  snapshot.unknownGroups = snapshot.unknown.groups

  if not snapshot.ownershipReady then
    snapshot.ownershipError = "C_VanityCollection.IsCollectionItemOwned is unavailable"
  end

  if snapshot.scanReady then
    local ownershipFunction = type(C_VanityCollection) == "table"
      and C_VanityCollection.IsCollectionItemOwned
      or nil
    local ownershipCache = {}
    local firstBag = tonumber(BACKPACK_CONTAINER) or 0
    local lastBag = tonumber(NUM_BAG_SLOTS) or 4

    for bag = firstBag, lastBag do
      local slotsOk, slotCount = pcall(GetContainerNumSlots, bag)
      if not slotsOk then
        snapshot.scanReady = false
        snapshot.scanError = "GetContainerNumSlots failed for bag " .. tostring(bag) .. ": " .. tostring(slotCount)
        break
      end

      slotCount = tonumber(slotCount)
      if not slotCount or slotCount < 0 or slotCount ~= math.floor(slotCount) then
        snapshot.scanReady = false
        snapshot.scanError = "GetContainerNumSlots returned an invalid size for bag " .. tostring(bag)
        break
      end

      for slot = 1, slotCount do
        snapshot.scannedSlots = snapshot.scannedSlots + 1
        local record, inspectError = inspectSlot(bag, slot)
        if inspectError then
          snapshot.scanReady = false
          snapshot.scanError = "Inventory scan failed for bag " .. tostring(bag)
            .. ", slot " .. tostring(slot) .. ": " .. tostring(inspectError)
          break
        end

        if record then
          local ownershipKnown, owned, ownershipError = getOwnership(
            record.itemID,
            ownershipCache,
            ownershipFunction
          )
          record.ownershipKnown = ownershipKnown
          record.owned = owned
          record.unknown = ownershipKnown and owned == false or false
          record.ownershipError = ownershipError

          if not ownershipKnown then
            snapshot.ownershipReady = false
            snapshot.ownershipError = snapshot.ownershipError or ownershipError
            addToAggregateSet(snapshot.uncertain, record)
          elseif not owned then
            addToAggregateSet(snapshot.unknown, record)
          end

          snapshot.cards[#snapshot.cards + 1] = record
          snapshot.occupiedCardSlots = snapshot.occupiedCardSlots + 1
          snapshot.counts[record.kind] = snapshot.counts[record.kind] + record.count
          snapshot.totalCount = snapshot.totalCount + record.count
        end
      end

      if not snapshot.scanReady then
        break
      end
    end
  else
    snapshot.scanError = "The container scan API is unavailable"
  end

  table.sort(snapshot.cards, sortRecords)

  self.revision = self.revision + 1
  snapshot.revision = self.revision
  self.snapshot = snapshot
  return snapshot
end

function Catalog:GetSnapshot()
  return self.snapshot
end

function Catalog:GetCount(kind)
  if not KIND_CONFIG[kind] then
    return 0
  end
  local snapshot = self.snapshot
  return snapshot and snapshot.counts[kind] or 0
end

local function normalizeGroup(group)
  if group == "normal" or group == "lucky" then
    return "standard"
  end
  if group == "goldenLucky" then
    return "golden"
  end
  return group
end

function Catalog:GetUnknownGroupCount(group)
  group = normalizeGroup(group)
  local snapshot = self.snapshot
  local aggregate = snapshot and snapshot.unknown.groups[group]
  if not aggregate then
    return 0, 0
  end
  return aggregate.copies, aggregate.uniqueIDs
end

function Catalog:IsOwnershipReady()
  if not self.snapshot then
    return false, "Inventory has not been scanned"
  end
  return self.snapshot.ownershipReady and true or false, self.snapshot.ownershipError
end

function Catalog:SetExchangeFrame(frame)
  self.exchangeFrame = frame
end

function Catalog:GetExchangeFrame()
  return self.exchangeFrame or _G.SkillCardExchangeUI
end

function Catalog:IsExchangeOpen()
  local frame = self:GetExchangeFrame()
  local frameType = type(frame)
  if frameType ~= "table" and frameType ~= "userdata" then
    return false
  end

  local shownMethod = frame.IsShown
  if type(shownMethod) == "function" then
    local ok, shown = pcall(shownMethod, frame)
    return ok and shown and true or false
  end

  local visibleMethod = frame.IsVisible
  if type(visibleMethod) == "function" then
    local ok, visible = pcall(visibleMethod, frame)
    return ok and visible and true or false
  end

  return false
end

local function resolveExchangeButton(frame, kind)
  local config = KIND_CONFIG[kind]
  if not frame or not config then
    return nil
  end

  local ok, button = pcall(function()
    return frame.content and frame.content.exchange and frame.content.exchange[config.button]
  end)
  if not ok or not button then
    return nil
  end
  local buttonType = type(button)
  if (buttonType ~= "table" and buttonType ~= "userdata")
    or type(button.Click) ~= "function"
    or type(button.IsEnabled) ~= "function"
  then
    return nil
  end
  return button
end

local function databaseGet(path, fallback)
  local database = AP.Database
  if not database or type(database.Get) ~= "function" then
    return fallback
  end
  local ok, value = pcall(database.Get, database, path, fallback)
  if not ok or value == nil then
    return fallback
  end
  return value
end

local function protectionEnabled(group)
  local key = group == "golden" and "protectGolden" or "protectStandard"
  local value = databaseGet("skillCards." .. key, nil)
  if value == nil then
    value = databaseGet("skillCards.exchange." .. key, true)
  end
  return value ~= false
end

local function buttonIsEnabled(button)
  local buttonType = type(button)
  if buttonType ~= "table" and buttonType ~= "userdata" then
    return false
  end
  if type(button.IsEnabled) ~= "function" then
    return false
  end
  local ok, enabled = pcall(button.IsEnabled, button)
  -- Wrath-era widget APIs commonly return 1/nil instead of true/false.
  return ok and enabled and true or false
end

function Catalog:GetExchangeState(kind, snapshot)
  local config = KIND_CONFIG[kind]
  if not config then
    return {
      kind = kind,
      ready = false,
      code = "invalid-kind",
      reason = "Unknown skill-card exchange type.",
      required = REQUIRED_EXCHANGE_COUNT,
      count = 0,
    }
  end

  snapshot = snapshot or self.snapshot or self:Scan("exchange state")
  local unknownCopies, unknownUniqueIDs = 0, 0
  if snapshot and snapshot.unknown and snapshot.unknown.groups[config.group] then
    local aggregate = snapshot.unknown.groups[config.group]
    unknownCopies = aggregate.copies
    unknownUniqueIDs = aggregate.uniqueIDs
  end

  local frame = self:GetExchangeFrame()
  local button = resolveExchangeButton(frame, kind)
  local state = {
    kind = kind,
    label = config.label,
    group = config.group,
    count = snapshot and snapshot.counts[kind] or 0,
    required = REQUIRED_EXCHANGE_COUNT,
    unknownCopies = unknownCopies,
    unknownUniqueIDs = unknownUniqueIDs,
    protectionEnabled = protectionEnabled(config.group),
    ownershipReady = snapshot and snapshot.ownershipReady or false,
    vendorOpen = self:IsExchangeOpen(),
    buttonAvailable = button ~= nil,
    button = button,
    moduleEnabled = databaseGet("modules.skillCards", true) ~= false,
    combatLocked = inCombat(),
    ready = false,
  }

  if not state.moduleEnabled then
    state.code = "module-disabled"
    state.reason = "The Skill Card Ledger is disabled."
  elseif not snapshot or not snapshot.scanReady then
    state.code = "scan-unavailable"
    state.reason = snapshot and snapshot.scanError or "Inventory has not been scanned."
  elseif not snapshot.ownershipReady then
    state.code = "ownership-unavailable"
    state.reason = snapshot.ownershipError
      or "Ascension ownership data is unavailable; exchange is locked to protect unlearned cards."
  elseif state.combatLocked then
    state.code = "combat"
    state.reason = "Skill-card exchanges are unavailable during combat."
  elseif state.protectionEnabled and unknownCopies > 0 then
    state.code = "protected-unknown"
    state.reason = string.format(
      "%d unlearned %s card%s are protected from exchange.",
      unknownCopies,
      config.group,
      unknownCopies == 1 and "" or "s"
    )
  elseif state.count < REQUIRED_EXCHANGE_COUNT then
    state.code = "not-enough"
    state.reason = string.format(
      "You need %d %s cards; %d are carried.",
      REQUIRED_EXCHANGE_COUNT,
      string.lower(config.label),
      state.count
    )
  elseif not state.vendorOpen then
    state.code = "vendor-closed"
    state.reason = "Open Ascension's skill-card exchange window first."
  elseif not button then
    state.code = "button-unavailable"
    state.reason = "Ascension's exchange button is unavailable for this card type."
  elseif not buttonIsEnabled(button) then
    state.code = "button-disabled"
    state.reason = "Ascension's exchange button is currently disabled."
  else
    state.ready = true
    state.code = "ready"
    state.reason = string.format("Exchange 5 %s cards.", string.lower(config.label))
  end

  return state
end

function Catalog:Exchange(kind)
  if databaseGet("modules.skillCards", true) == false then
    return false, "The Skill Card Ledger is disabled."
  end
  if inCombat() then
    return false, "Skill-card exchanges are unavailable during combat."
  end

  local snapshot = self:Scan("exchange")
  local state = self:GetExchangeState(kind, snapshot)
  if not state.ready then
    return false, state.reason, state
  end

  if not self:IsExchangeOpen() then
    state.ready = false
    state.code = "vendor-closed"
    state.reason = "The skill-card exchange window closed before the request was submitted."
    return false, state.reason, state
  end

  local button = resolveExchangeButton(self:GetExchangeFrame(), kind)
  if not button or not buttonIsEnabled(button) then
    state.ready = false
    state.code = button and "button-disabled" or "button-unavailable"
    state.reason = button
      and "Ascension's exchange button became disabled."
      or "Ascension's exchange button is no longer available."
    return false, state.reason, state
  end

  local ok, err = pcall(button.Click, button)
  if not ok then
    state.ready = false
    state.code = "click-failed"
    state.reason = "Ascension rejected the exchange request: " .. tostring(err)
    return false, state.reason, state
  end

  return true, nil, state
end

function Catalog:GetStatusText()
  local snapshot = self.snapshot
  if not snapshot then
    return "Skill-card inventory has not been scanned yet."
  end
  if not snapshot.scanReady then
    return "Skill-card inventory scan unavailable: " .. tostring(snapshot.scanError or "unknown error")
  end

  local counts = snapshot.counts
  local summary = string.format(
    "%d cards carried: %d normal, %d lucky, %d golden, %d golden lucky.",
    snapshot.totalCount,
    counts.normal,
    counts.lucky,
    counts.golden,
    counts.goldenLucky
  )

  if not snapshot.ownershipReady then
    return summary .. " Ownership data is unavailable; exchanges are locked."
  end

  local unknown = snapshot.unknown.total
  if unknown.copies == 0 then
    return summary .. " Every carried card is learned."
  end

  return summary .. string.format(
    " %d unlearned copies across %d unique card IDs.",
    unknown.copies,
    unknown.uniqueIDs
  )
end
