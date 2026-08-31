local root = (... and ... ~= "" and ...) or "."

local pages = {}

_G.Levo = {
  Banking = {
    Categories = {
      RegisterConfigPages = function()
      end,
    },
    Controller = {},
    Sorter = {
      OnSettingsChanged = function()
      end,
    },
    SorterExclusions = {},
  },
  ConfigRegistry = {
    RegisterPage = function(_, page)
      pages[page.id] = page
    end,
  },
  Modules = {
    Register = function(_, _, definition)
      definition.OnInitialize()
    end,
  },
}

dofile(root .. "/modules/banking/BankingModule.lua")

local page = pages["banking.sorter.qualityRules"]
assert(page, "quality rules must have their own nested sorter configuration page")
local options = page.options()

local expected = {
  ["banking.sorter.qualityRules.poor.mode"] = true,
  ["banking.sorter.qualityRules.legendary.mode"] = true,
  ["banking.sorter.qualityRules.heirloom.mode"] = true,
  ["banking.sorter.qualityRules.legendary.inventoryDestination"] = true,
  ["banking.sorter.qualityRules.legendary.characterDestination"] = true,
}

for index = 1, #options do
  local option = options[index]
  if option.type == "select" then
    assert(type(option.choices) == "table" and #option.choices >= 3, "quality rules require real dropdown choices")
    expected[option.path] = nil
  end
end

for path in pairs(expected) do
  assert(false, "missing quality rule selector: " .. path)
end

print("SorterQualityRulesConfigSpec: OK")
