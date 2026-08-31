local root = (... and ... ~= "" and ...) or "."

local pages = {}
local registered

_G.Levo = {
  TalentImport = {
    BuildParser = {},
    BuildPlanner = {},
    AscensionAdapter = {},
    ProgressionPlan = {},
    ImportWindow = {},
    Runtime = {},
  },
  ConfigRegistry = {
    RegisterPage = function(_, page)
      pages[page.id] = page
    end,
  },
  Modules = {
    Register = function(_, _, definition)
      registered = definition
    end,
  },
}

dofile(root .. "/modules/talents/TalentImportModule.lua")
registered.OnInitialize()

assert(pages.talents, "talent tools need a top-level configuration page")
local page = assert(pages["talents.import"], "max-level import needs its own nested configuration page")
local options = page.options()
local found = {}
for index = 1, #options do
  local option = options[index]
  if option.path then
    found[option.path] = true
  end
end

assert(found["talentImport.showButton"], "button visibility must be configurable")
assert(found["talentImport.showTooltips"], "tooltip visibility must be configurable")
assert(found["talentImport.progression.enabled"], "automatic saved progression must be configurable")

print("TalentImportConfigSpec: OK")
