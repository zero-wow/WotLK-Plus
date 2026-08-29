_G.AscensionPlus = {
  Banking = {},
  Utils = {
    NormalizeSearch = function(text)
      return string.lower(tostring(text or ""))
    end,
  },
  Database = {
    Get = function(_, _, fallback)
      return fallback
    end,
    Set = function()
    end,
  },
  Print = function()
  end,
}

dofile("modules/banking/BankingCategories.lua")
dofile("modules/banking/CategoryConfig.lua")

local pages = {}
local registry = {
  RegisterPage = function(_, page)
    pages[page.id] = page
  end,
}

local Categories = _G.AscensionPlus.Banking.Categories
Categories:RegisterConfigPages(registry)

for _, pageID in ipairs({
  "banking.categories",
  "banking.categories.boe",
  "banking.categories.materials",
  "banking.categories.reagents",
  "banking.categories.gear",
  "banking.categories.recipe",
  "banking.categories.other",
  "banking.categories.exclusions",
}) do
  assert(pages[pageID], "missing category config page " .. pageID)
end

local function hasOptionPath(pageID, path)
  local options = pages[pageID].options()
  for index = 1, #options do
    if options[index].path == path then
      return true
    end
  end
  return false
end

assert(hasOptionPath("banking.categories.materials", "banking.categories.materials.qualities.poor"), "Materials needs a poor-quality toggle")
assert(hasOptionPath("banking.categories.boe", "banking.categories.boe.qualities.poor"), "BoE needs a poor-quality toggle")
assert(hasOptionPath("banking.categories.reagents", "banking.categories.reagents.qualities.poor"), "Reagents needs a poor-quality toggle")
assert(hasOptionPath("banking.categories.gear", "banking.categories.gear.weapons"), "Gear needs type toggles")
assert(hasOptionPath("banking.categories.recipe", "banking.categories.recipe.engineering"), "Recipe needs subclass toggles")
assert(hasOptionPath("banking.categories.other", "banking.categories.other.consumables.foodDrink"), "Other needs a Food & Drink toggle")
assert(hasOptionPath("banking.categories.exclusions", "banking.categories.exclusions.protectBankAccessItems"), "category exclusions need bank-access protection")

io.write("PASS all six transfer categories expose nested type and quality configuration\n")
