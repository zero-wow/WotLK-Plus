local root = (... and ... ~= "" and ...) or "."

local settings = {
  ["modules.skillCards"] = true,
  ["skillCards.protectStandard"] = true,
  ["skillCards.protectGolden"] = true,
}

_G.AscensionPlus = {
  Database = {
    Get = function(_, path, fallback)
      local value = settings[path]
      if value == nil then
        return fallback
      end
      return value
    end,
  },
}

BACKPACK_CONTAINER = 0
NUM_BAG_SLOTS = 1

local itemData = {
  [1001] = { name = "Skill Card: Arcane Intellect", quality = 2, kind = "normal", owned = false },
  [1002] = { name = "Lucky Skill Card: Blink", quality = 3, kind = "lucky", owned = true },
  [1003] = { name = "Golden Skill Card: Fireball", quality = 4, kind = "golden", owned = false },
  [1004] = { name = "Lucky Golden Skill Card: Frostbolt", quality = 4, kind = "goldenLucky", owned = true },
  [1005] = { name = "Golden Lucky Skill Card: Polymorph", quality = 3, kind = "fallback", owned = true },
  [2000] = { name = "Ordinary Stone", quality = 1, kind = "other", owned = false },
}

local bags = {
  [0] = {
    { id = 1001, count = 3 },
    { id = 1002, count = 4 },
    { id = 1003, count = 5 },
    { id = 2000, count = 99 },
  },
  [1] = {
    { id = 1001, count = 2 },
    { id = 1004, count = 6 },
    { id = 1005, count = 1 },
  },
}

local nilOwnershipID
local ownershipCalls = {}
local currentTime = 100
local combat = false
local invalidSlotCountBag
local malformedCountLocation
local unresolvedLocation

local function locationKey(bag, slot)
  return tostring(bag) .. ":" .. tostring(slot)
end

function GetTime()
  return currentTime
end

function InCombatLockdown()
  return combat
end

function GetContainerNumSlots(bag)
  if bag == invalidSlotCountBag then
    return nil
  end
  return #(bags[bag] or {})
end

function GetContainerItemID(bag, slot)
  if locationKey(bag, slot) == unresolvedLocation then
    return nil
  end
  local record = bags[bag] and bags[bag][slot]
  return record and record.id or nil
end

function GetContainerItemInfo(bag, slot)
  local record = bags[bag] and bags[bag][slot]
  if not record then
    return nil
  end
  local item = itemData[record.id]
  local count = record.count
  if locationKey(bag, slot) == malformedCountLocation then
    count = nil
  end
  local link = "|cff00ff00|Hitem:" .. tostring(record.id) .. "|h[" .. item.name .. "]|h|r"
  if locationKey(bag, slot) == unresolvedLocation then
    link = nil
  end
  return "texture:" .. tostring(record.id), count, false, item.quality, false, false, link
end

function GetContainerItemLink(bag, slot)
  if locationKey(bag, slot) == unresolvedLocation then
    return nil
  end
  local record = bags[bag] and bags[bag][slot]
  return record and ("item:" .. tostring(record.id)) or nil
end

function GetItemInfo(value)
  local itemID = type(value) == "number" and value or tonumber(tostring(value):match("item:(%d+)"))
  local item = itemID and itemData[itemID]
  if not item then
    return nil
  end
  return item.name, "item:" .. tostring(itemID), item.quality, 1, 1, "Miscellaneous", "Other", 20, "",
    "texture:" .. tostring(itemID)
end

function GetItemCount()
  error("SkillCardCatalog must use the stack count returned for each bag slot")
end

function GetSkillCard(itemID)
  local kind = itemData[itemID] and itemData[itemID].kind
  if kind == "normal" then
    return { isGolden = false }
  end
  if kind == "golden" then
    return { isGolden = true }
  end
end

function GetLuckyCard(itemID)
  local kind = itemData[itemID] and itemData[itemID].kind
  if kind == "lucky" then
    return { isGolden = false }
  end
  if kind == "goldenLucky" then
    return { isGolden = true }
  end
end

C_VanityCollection = {
  IsCollectionItemOwned = function(itemID)
    ownershipCalls[itemID] = (ownershipCalls[itemID] or 0) + 1
    if itemID == nilOwnershipID then
      return nil
    end
    local item = itemData[itemID]
    return item and item.owned or false
  end,
}

local clicks = {
  normal = 0,
  lucky = 0,
  golden = 0,
  goldenLucky = 0,
}

local function newButton(kind)
  return {
    enabled = true,
    IsEnabled = function(self)
      return self.enabled
    end,
    Click = function()
      clicks[kind] = clicks[kind] + 1
    end,
  }
end

local vendorOpen = true
local buttons = {
  normal = newButton("normal"),
  lucky = newButton("lucky"),
  golden = newButton("golden"),
  goldenLucky = newButton("goldenLucky"),
}

local vendor = {
  IsShown = function()
    return vendorOpen
  end,
  content = {
    exchange = {
      buttonNormal = buttons.normal,
      buttonNormalLucky = buttons.lucky,
      buttonGold = buttons.golden,
      buttonGoldLucky = buttons.goldenLucky,
    },
  },
}

StaticPopup1Button1 = {
  Click = function()
    error("the catalog must never click a global confirmation popup")
  end,
}

dofile(root .. "/modules/skillcards/SkillCardCatalog.lua")

local Catalog = AscensionPlus.SkillCards.Catalog
Catalog:SetExchangeFrame(vendor)

local snapshot = Catalog:Scan("unit test")
assert(snapshot.scanReady, snapshot.scanError or "bag APIs should be available")
assert(snapshot.ownershipReady, snapshot.ownershipError or "ownership should be authoritative")
assert(#snapshot.cards == 6, "all six card slots must remain distinct")
assert(snapshot.totalCount == 21, "only per-slot skill-card stack counts should contribute to the total")
assert(Catalog:GetCount("normal") == 5, "duplicate normal stacks should sum to five copies")
assert(Catalog:GetCount("lucky") == 4, "lucky count should use the slot stack count")
assert(Catalog:GetCount("golden") == 5, "golden count should use the slot stack count")
assert(Catalog:GetCount("goldenLucky") == 7, "API and English fallback golden-lucky cards should share a kind")
assert(Catalog:GetCount("invalid") == 0, "invalid kinds should fail closed")
assert(
  snapshot.cards[1].itemID == 1001 and snapshot.cards[1].bag == 0
    and snapshot.cards[2].itemID == 1001 and snapshot.cards[2].bag == 1
    and snapshot.cards[3].itemID == 1003
    and snapshot.cards[4].itemID == 1002
    and snapshot.cards[5].itemID == 1004
    and snapshot.cards[6].itemID == 1005,
  "slot records should have a deterministic unknown-first, kind, quality, name, and location order"
)

local duplicateSlots = 0
local duplicateCopies = 0
for index = 1, #snapshot.cards do
  local record = snapshot.cards[index]
  if record.itemID == 1001 then
    duplicateSlots = duplicateSlots + 1
    duplicateCopies = duplicateCopies + record.count
  end
end
assert(duplicateSlots == 2 and duplicateCopies == 5, "duplicate item IDs must retain both bag-slot records")
assert(snapshot.unknown.groups.standard.copies == 5, "unknown standard copies should aggregate both stacks")
assert(snapshot.unknown.groups.standard.uniqueIDs == 1, "duplicate unknown stacks should count one unique item ID")
assert(snapshot.unknown.groups.standard.slots == 2, "unknown aggregates should expose their source-slot count")
assert(snapshot.unknown.groups.golden.copies == 5, "unknown golden copies should remain separate from standard")
assert(Catalog:GetUnknownGroupCount("standard") == 5, "unknown group helper should return copy count")
local goldenCopies, goldenIDs = Catalog:GetUnknownGroupCount("golden")
assert(goldenCopies == 5 and goldenIDs == 1, "unknown helper should also expose unique-ID count")
assert(ownershipCalls[1001] == 1, "ownership should be queried once per unique item ID during a scan")

local state = Catalog:GetExchangeState("normal")
assert(not state.ready and state.code == "protected-unknown", "standard protection must block known unlearned cards")
assert(not Catalog:Exchange("normal"), "protected normal cards must not reach the vendor button")
assert(clicks.normal == 0, "blocked exchanges must not click Ascension's vendor")

settings["skillCards.protectStandard"] = false
local exchanged, exchangeError = Catalog:Exchange("normal")
assert(exchanged, exchangeError or "explicitly disabling standard protection should permit the ready exchange")
assert(clicks.normal == 1, "a ready exchange should click only the matching vendor button once")

state = Catalog:GetExchangeState("lucky")
assert(not state.ready and state.code == "not-enough", "four lucky cards must not satisfy a five-card exchange")
assert(not Catalog:Exchange("lucky") and clicks.lucky == 0, "insufficient cards must never click the vendor")

settings["skillCards.protectGolden"] = true
state = Catalog:GetExchangeState("golden")
assert(not state.ready and state.code == "protected-unknown", "golden protection must use the golden unknown group")
settings["skillCards.protectGolden"] = false
assert(Catalog:Exchange("golden"), "disabling golden protection should allow an otherwise ready exchange")
assert(clicks.golden == 1, "golden exchange should click only the golden vendor button")

combat = true
state = Catalog:GetExchangeState("golden")
assert(not state.ready and state.code == "combat", "combat must disable an otherwise-ready exchange")
assert(not Catalog:Exchange("golden") and clicks.golden == 1, "combat must never click Ascension's vendor button")
combat = false

vendorOpen = false
state = Catalog:GetExchangeState("goldenLucky")
assert(not state.ready and state.code == "vendor-closed", "a hidden exchange vendor must block programmatic clicks")
assert(not Catalog:Exchange("goldenLucky") and clicks.goldenLucky == 0, "closed vendor must remain untouched")
vendorOpen = true

vendor.content.exchange.buttonGoldLucky = nil
state = Catalog:GetExchangeState("goldenLucky")
assert(not state.ready and state.code == "button-unavailable", "changed Ascension frame internals must fail safely")
vendor.content.exchange.buttonGoldLucky = buttons.goldenLucky

buttons.goldenLucky.enabled = false
state = Catalog:GetExchangeState("goldenLucky")
assert(not state.ready and state.code == "button-disabled", "a disabled native exchange button must remain untouched")
buttons.goldenLucky.enabled = true

local savedIsEnabled = buttons.goldenLucky.IsEnabled
buttons.goldenLucky.IsEnabled = nil
state = Catalog:GetExchangeState("goldenLucky")
assert(not state.ready and state.code == "button-unavailable", "a vendor button missing its enabled capability must fail closed")
assert(not Catalog:Exchange("goldenLucky") and clicks.goldenLucky == 0, "an incomplete vendor button must never be clicked")
buttons.goldenLucky.IsEnabled = savedIsEnabled

Catalog:SetExchangeFrame(42)
assert(not Catalog:IsExchangeOpen(), "a malformed exchange-frame global must fail closed")
state = Catalog:GetExchangeState("goldenLucky")
assert(not state.ready and state.code == "vendor-closed", "malformed vendor state must not throw or click")
Catalog:SetExchangeFrame(vendor)

malformedCountLocation = "0:1"
snapshot = Catalog:Scan("invalid stack count")
assert(not snapshot.scanReady, "an occupied card slot with no authoritative stack count must invalidate the scan")
assert(Catalog:GetExchangeState("normal").code == "scan-unavailable", "invalid stack counts must block exchange")
assert(not Catalog:Exchange("normal") and clicks.normal == 1, "a malformed count must never fabricate the fifth card")
malformedCountLocation = nil

invalidSlotCountBag = 0
snapshot = Catalog:Scan("invalid bag size")
assert(not snapshot.scanReady, "a successful bag API call with no numeric size must invalidate the scan")
assert(not Catalog:Exchange("normal") and clicks.normal == 1, "invalid bag enumeration must fail closed")
invalidSlotCountBag = nil

unresolvedLocation = "0:1"
snapshot = Catalog:Scan("unresolved occupied slot")
assert(not snapshot.scanReady, "an occupied slot without an item ID or parseable link must invalidate the scan")
assert(not Catalog:Exchange("normal") and clicks.normal == 1, "unresolved occupied slots must fail closed")
unresolvedLocation = nil

nilOwnershipID = 1001
snapshot = Catalog:Scan("ownership unavailable")
local ownershipReady = Catalog:IsOwnershipReady()
assert(not ownershipReady, "nil ownership results must mark the entire snapshot unready")
assert(snapshot.uncertain.groups.standard.copies == 5, "uncertain copies should remain visible for diagnostics")
settings["skillCards.protectStandard"] = false
state = Catalog:GetExchangeState("normal")
assert(not state.ready and state.code == "ownership-unavailable", "ownership uncertainty must fail closed even when protection is off")
assert(not Catalog:Exchange("normal") and clicks.normal == 1, "nil ownership must never submit another exchange")
assert(Catalog:GetStatusText():find("exchanges are locked", 1, true), "status should explain the fail-closed lock")

nilOwnershipID = nil
C_VanityCollection = nil
snapshot = Catalog:Scan("ownership API missing")
assert(not snapshot.ownershipReady, "a missing ownership namespace must fail closed")
assert(Catalog:GetExchangeState("normal").code == "ownership-unavailable", "missing ownership API must block exchange")

io.write("PASS skill-card catalog preserves slots, counts stacks, fails closed, and safely gates vendor clicks\n")
