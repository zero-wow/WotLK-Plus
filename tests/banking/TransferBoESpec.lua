local unpack = unpack or table.unpack

ITEM_BIND_ON_EQUIP = "Binds when equipped"
ITEM_SOULBOUND = "Soulbound"
ITEM_ACCOUNTBOUND = "Account Bound"
ITEM_BNETACCOUNTBOUND = "Battle.net Account Bound"
ITEM_BIND_QUEST = "Quest Item"
ITEM_CONJURED = "Conjured Item"

local records = {
  ["item:3001"] = { "Unbound Sword", "item:3001", 2, 60, 50, "Weapon", "Sword", 1, "INVTYPE_WEAPON" },
  ["item:3002"] = { "Bound Sword", "item:3002", 3, 70, 60, "Weapon", "Sword", 1, "INVTYPE_WEAPON" },
  ["item:3003"] = { "Unbound Potion", "item:3003", 1, 1, 0, "Consumable", "Potion", 5, "" },
}

function GetItemInfo(itemLink)
  local record = records[itemLink]
  if record then
    return unpack(record)
  end
end

function IsEquippableItem(itemLink)
  return itemLink == "item:3001" or itemLink == "item:3002"
end

_G.AscensionPlus = {
  Banking = {
    providers = {},
  },
  Utils = {
    NormalizeSearch = function(text)
      return string.lower(tostring(text or "")):gsub("[^%w]+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    end,
  },
  Database = {
    Get = function(_, _, fallback)
      return fallback
    end,
    Set = function() end,
  },
  Print = function() end,
}

dofile("modules/banking/BankingCategories.lua")
dofile("modules/banking/DepositController.lua")

local Banking = _G.AscensionPlus.Banking
local Controller = Banking.Controller
local activeLines = {}
local lineMap = {
  ["container:1"] = { ITEM_BIND_ON_EQUIP },
  ["container:2"] = { ITEM_SOULBOUND },
  ["container:3"] = {},
  ["guild-bank:1"] = { ITEM_BIND_ON_EQUIP },
  ["guild-bank:2"] = { ITEM_SOULBOUND },
  ["guild-bank:3"] = {},
}

Controller.scanner = {
  GetName = function()
    return "AscensionPlusBoETestScanner"
  end,
  ClearLines = function()
    activeLines = {}
  end,
  SetBagItem = function(_, _, slotID)
    activeLines = lineMap["container:" .. tostring(slotID)] or {}
  end,
  SetGuildBankItem = function(_, _, slotID)
    activeLines = lineMap["guild-bank:" .. tostring(slotID)] or {}
  end,
  NumLines = function()
    return #activeLines
  end,
  Hide = function() end,
}

for index = 1, 3 do
  local lineIndex = index
  _G["AscensionPlusBoETestScannerTextLeft" .. tostring(lineIndex)] = {
    GetText = function()
      return activeLines[lineIndex]
    end,
  }
end

local snapshots = {
  [1] = { itemID = 3001, itemLink = "item:3001", count = 1, locked = false },
  [2] = { itemID = 3002, itemLink = "item:3002", count = 1, locked = false },
  [3] = { itemID = 3003, itemLink = "item:3003", count = 5, locked = false },
}

local provider = {
  GetSourceLocations = function(_, operation)
    local kind = operation == "withdraw" and "guild-bank" or "container"
    local locations = {}
    for index = 1, 3 do
      locations[index] = kind == "guild-bank"
        and { kind = kind, tab = 1, slotID = index }
        or { kind = kind, containerID = 0, slotID = index }
    end
    return locations
  end,
  GetSourceSnapshot = function(_, _, location)
    return snapshots[location.slotID]
  end,
  GetSourceLabel = function(_, operation, location)
    return operation .. " slot " .. tostring(location.slotID)
  end,
  CanAcceptItemFlags = function()
    return true
  end,
  CanUse = function()
    return true
  end,
  HasDestinationCapacity = function()
    return true
  end,
}

local bagFlags = Controller:ScanItemFlags({ kind = "container", containerID = 0, slotID = 1 })
assert(bagFlags.scanned, "container BoE binding scan must complete")
assert(bagFlags.bindOnEquip, "container BoE binding scan must find ITEM_BIND_ON_EQUIP")
local bankFlags = Controller:ScanItemFlags({ kind = "guild-bank", tab = 1, slotID = 1 })
assert(bankFlags.scanned, "guild-style BoE binding scan must complete")
assert(bankFlags.bindOnEquip, "guild-style BoE binding scan must find ITEM_BIND_ON_EQUIP")
local matches, allowed, evidence = Banking.Categories:EvaluateButton("item:3001", "boe", { flags = bagFlags })
assert(matches and allowed, "category evaluation must accept the scanned unbound BoE slot: " .. tostring(evidence and evidence.code) .. " / " .. tostring(evidence and evidence.reason))

local depositQueue, depositStats = Controller:BuildQueue("boe", provider, "deposit")
assert(#depositQueue == 1 and depositQueue[1].itemID == 3001, "Deposit BOE must include only the unbound bag-slot instance")
assert(depositStats.matchedStacks == 1, "Deposit BOE must count only live unbound BoE stacks")

local withdrawQueue, withdrawStats = Controller:BuildQueue("boe", provider, "withdraw")
assert(#withdrawQueue == 1 and withdrawQueue[1].itemID == 3001, "Withdraw BOE must scan the active guild-style bank slot")
assert(withdrawStats.matchedStacks == 1, "Withdraw BOE must count only live unbound BoE stacks")

local depositAudit = Controller:BuildAudit("boe", provider, "deposit")
local withdrawAudit = Controller:BuildAudit("boe", provider, "withdraw")
assert(depositAudit.eligibleStacks == 1 and withdrawAudit.eligibleStacks == 1, "PRETEND BOE must audit the same safe item in both directions")
assert(withdrawAudit.entries[1].flagsChecked, "PRETEND BOE withdrawal must report its live bank-slot binding scan")

io.write("PASS BOE transfers include only live unbound Bind-on-Equip source slots in every mode\n")
