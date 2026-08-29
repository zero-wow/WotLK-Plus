local unpack = unpack or table.unpack

local records = {
  rod = { "Runed Adamantite Rod", "item:900", 2, 70, 60, "Trade Goods", "Enchanting", 1, "" },
  dust = { "Arcane Dust", "item:901", 2, 60, 0, "Trade Goods", "Enchanting", 20, "" },
  food = { "Conjured Bread", "item:1001", 1, 1, 0, "Consumable", "Food & Drink", 20, "" },
  greyGear = { "Rusty Sword", "item:1002", 0, 1, 0, "Weapon", "Sword", 1, "INVTYPE_WEAPON" },
  whiteGear = { "Training Sword", "item:1003", 1, 1, 0, "Weapon", "Sword", 1, "INVTYPE_WEAPON" },
  realmItem = { "Realm Bank Item", "item:1004", 1, 1, 0, "Miscellaneous", "Other", 1, "" },
  ignored = { "Protected Cloth", "item:1005", 2, 1, 0, "Trade Goods", "Cloth", 20, "" },
  boeGear = { "Unbound Epic Sword", "item:1006", 4, 80, 70, "Weapon", "Sword", 1, "INVTYPE_WEAPON" },
}

local settings = {
  ["banking.categories.other.tradeGoods"] = true,
}

function GetItemInfo(itemLink)
  local record = records[itemLink]
  if record then
    return unpack(record)
  end
end

function IsEquippableItem(itemLink)
  return itemLink == "greyGear" or itemLink == "whiteGear"
end

_G.AscensionPlus = {
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
}

dofile("modules/banking/BankingCategories.lua")

local Categories = _G.AscensionPlus.Banking.Categories

local rodCategory, rodEvidence = Categories:Classify("rod")
assert(rodCategory == "other", "enchanting rods must not classify as Materials")
assert(rodEvidence.code == "enchanting-rod-tool", "rod exclusion should explain the profession-tool rule")
assert(Categories:Classify("dust") == "materials", "ordinary enchanting inputs must remain Materials")

local foodCategory, foodEvidence = Categories:Classify("food")
assert(foodCategory == nil, "Food & Drink must default to no transfer category")
assert(foodEvidence.code == "consumable-subclass-disabled", "food exclusion should identify its disabled subclass")
settings["banking.categories.other.consumables.foodDrink"] = true
assert(Categories:Classify("food") == "other", "Food & Drink must become Other only when explicitly enabled")

local greyCategory, greyEvidence = Categories:Classify("greyGear")
assert(greyCategory == nil, "poor-quality Gear must default to excluded")
assert(greyEvidence.code == "quality-disabled", "grey Gear should explain the quality threshold")
settings["banking.categories.gear.qualities.poor"] = true
assert(Categories:Classify("greyGear") == "gear", "poor-quality Gear must become eligible only when enabled for Gear")
assert(Categories:Classify("whiteGear") == "gear", "common Gear remains eligible by default")

local boeMatches, boeAllowed, boeEvidence = Categories:EvaluateButton("boeGear", "boe", {
  flags = { scanned = true, bindOnEquip = true },
})
assert(boeMatches and boeAllowed, "an explicitly unbound Bind-on-Equip source slot must match BoE")
assert(boeEvidence.code == "unbound-bind-on-equip", "BoE should explain its live binding decision")
local boundMatches = Categories:EvaluateButton("boeGear", "boe", {
  flags = { scanned = true, bindOnEquip = true, soulbound = true },
})
assert(not boundMatches, "a soulbound instance of a BoE template must not match BoE")
local unreadableMatches = Categories:EvaluateButton("boeGear", "boe", { flags = {} })
assert(not unreadableMatches, "BoE must fail closed when the live binding tooltip cannot be read")

local bankCategory, bankEvidence = Categories:Classify("realmItem")
assert(bankCategory == nil, "Realm Bank access items must default to protected")
assert(bankEvidence.code == "bank-access-protected", "bank-item exclusion should explain its protection rule")
settings["banking.categories.exclusions.protectBankAccessItems"] = false
assert(Categories:Classify("realmItem") == "other", "bank access protection must be user-configurable")

settings["banking.categories.exclusions.items"] = { ["1005"] = true }
local ignoredCategory, ignoredEvidence = Categories:Classify("ignored")
assert(ignoredCategory == nil, "category-blacklisted items must never transfer")
assert(ignoredEvidence.code == "item-blacklisted", "blacklisted item should explain its exact exclusion")

io.write("PASS category rules protect binding state, food, grey gear, bank-access items, rods, and exact blacklists\n")
