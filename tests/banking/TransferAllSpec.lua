local unpack = unpack or table.unpack

local records = {
  ["item:1001"] = { "Conjured Bread", "item:1001", 1, 1, 0, "Consumable", "Food & Drink", 20, "" },
  ["item:1002"] = { "Rusty Sword", "item:1002", 0, 1, 0, "Weapon", "Sword", 1, "INVTYPE_WEAPON" },
  ["item:1003"] = { "Runed Adamantite Rod", "item:1003", 2, 70, 60, "Trade Goods", "Enchanting", 1, "" },
  ["item:1004"] = { "Protected Cloth", "item:1004", 2, 1, 0, "Trade Goods", "Cloth", 20, "" },
  ["item:1005"] = { "Realm Bank Item", "item:1005", 1, 1, 0, "Miscellaneous", "Other", 1, "" },
  ["item:1006"] = { "Arcane Dust", "item:1006", 2, 60, 0, "Trade Goods", "Enchanting", 20, "" },
  ["item:1007"] = { "Restricted Relic", "item:1007", 3, 70, 60, "Armor", "Miscellaneous", 1, "INVTYPE_TRINKET" },
}

local settings = {
  ["banking.categories.exclusions.items"] = {
    ["1004"] = "item:1004",
  },
  ["banking.categories.exclusions.protectBankAccessItems"] = true,
}

function GetItemInfo(itemLink)
  local record = records[itemLink]
  if record then
    return unpack(record)
  end
end

function IsEquippableItem(itemLink)
  return itemLink == "item:1002" or itemLink == "item:1007"
end

_G.AscensionPlus = {
  Banking = {},
  UI = {
    Theme = {
      colors = {},
    },
  },
  Utils = {
    NormalizeSearch = function(text)
      return string.lower(tostring(text or "")):gsub("[^%w]+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    end,
  },
  Database = {
    Get = function(_, path, fallback)
      local value = settings[path]
      return value == nil and fallback or value
    end,
    Set = function(_, path, value)
      settings[path] = value
    end,
  },
  Print = function() end,
}

dofile("modules/banking/BankingCategories.lua")
dofile("modules/banking/DepositController.lua")
dofile("modules/banking/PretendReport.lua")
dofile("modules/banking/DepositPanel.lua")

local Banking = _G.AscensionPlus.Banking
local Categories = Banking.Categories
local Controller = Banking.Controller
local locations = {}
local snapshots = {}

for itemID = 1001, 1007 do
  local location = { id = itemID }
  locations[#locations + 1] = location
  snapshots[itemID] = {
    itemID = itemID,
    itemLink = "item:" .. tostring(itemID),
    count = itemID == 1001 and 5 or (itemID == 1004 and 2 or (itemID == 1006 and 20 or 1)),
    locked = itemID == 1006,
  }
end

local provider = {
  GetSourceLocations = function()
    return locations
  end,
  GetSourceSnapshot = function(_, _, location)
    return snapshots[location.id]
  end,
  GetSourceLabel = function(_, operation, location)
    return operation .. " source " .. tostring(location.id)
  end,
  CanUse = function()
    return true
  end,
  HasDestinationCapacity = function()
    return true
  end,
  GetBankName = function()
    return "Test Bank"
  end,
  GetDestinationToken = function()
    return "test:1"
  end,
}

Controller.GetRestriction = function(_, _, operation, location)
  if operation == "deposit" and location.id == 1007 then
    return false, "the open bank rejects this item", { soulbound = true }
  end
  return true, nil, {}
end

assert(Categories.order[1] == "all" and Categories.definitions.all, "All must be the first transfer button")

local foodMatches, foodAllowed, foodEvidence = Categories:EvaluateButton("item:1001", "all")
assert(foodMatches and foodAllowed and foodEvidence.code == "all-transfer", "All must include food even when its category filter is disabled")
local greyMatches, greyAllowed = Categories:EvaluateButton("item:1002", "all")
assert(greyMatches and greyAllowed, "All must include poor-quality gear despite Gear quality filters")
local ignoredMatches, ignoredAllowed, ignoredEvidence = Categories:EvaluateButton("item:1004", "all")
assert(ignoredMatches and not ignoredAllowed and ignoredEvidence.code == "item-blacklisted", "All must preserve exact item blacklists")
local bankMatches, bankAllowed, bankEvidence = Categories:EvaluateButton("item:1005", "all")
assert(bankMatches and not bankAllowed and bankEvidence.code == "bank-access-protected", "All must preserve protected bank-access items")

local queue, stats = Controller:BuildQueue("all", provider, "deposit")
assert(stats.matchedStacks == 7 and stats.matchedItems == 31, "All must inspect every source stack")
assert(#queue == 4, "classification-safe unlocked stacks should queue without a blocking tooltip preflight")
assert(stats.restricted == 2, "hard blacklist and bank-access exclusions must be counted during queue construction")
assert(stats.locked == 1, "locked stacks must remain excluded")

local depositAudit = Controller:BuildAudit("all", provider, "deposit")
local withdrawAudit = Controller:BuildAudit("all", provider, "withdraw")
assert(depositAudit.matchedStacks == 7 and #depositAudit.entries == 7, "PRETEND All must report every deposit-side stack")
assert(depositAudit.eligibleStacks == 3, "PRETEND deposit eligibility must match the executable queue")
assert(withdrawAudit.matchedStacks == 7 and withdrawAudit.eligibleStacks == 4, "withdraw audit must omit deposit-only binding restrictions")

local plainReport = Banking.PretendReport:BuildText("all", provider, depositAudit, withdrawAudit)
assert(plainReport:find("Button clicked: ALL", 1, true), "PRETEND report must identify the All button")
assert(plainReport:find("Conjured Bread", 1, true) and plainReport:find("Realm Bank Item", 1, true), "PRETEND All must list included and safety-excluded items")
assert(plainReport:find("Category, type, subclass, and quality filters are bypassed", 1, true), "PRETEND All must explain its classification policy")

local Panel = Banking.Panel
local layout = Panel.LAYOUT
local panelHeight = Panel:GetRequiredHeight()
local buttonBottom = layout.categoryTop
  + (#Categories.order * layout.categoryButtonHeight)
  + ((#Categories.order - 1) * layout.categoryGap)
local statusTop = panelHeight - layout.statusBottom - layout.statusHeight
assert(#Categories.order == 7, "the transfer panel must expose All plus six filtered buttons")
assert(statusTop - buttonBottom >= layout.statusGutter, "the sixth button must not overlap the status block")

io.write("PASS All transfers every filtered-out stack while preserving hard exclusions and panel gutters\n")
