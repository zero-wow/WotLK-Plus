local root = (... and ... ~= "" and ...) or "."

local values = {
  ["skillCards.migrationVersion"] = 0,
}
local pages = {}
local moduleDefinition

_G.AscendedSkillCardsDB = {
  EnableTooltips = false,
  EnableColorSkillCardButtonBorderByRarity = true,
  ForceExchangeCards = true,
  ForceExchangeGoldenCards = false,
  ShowOnOpeningSealedDeck = false,
  ShowOnOpeningExchangeWindow = true,
  HideOnClosingExchangeWindow = false,
}

_G.AscensionPlus = {
  Database = {
    Get = function(_, path, fallback)
      local value = values[path]
      if value == nil then
        return fallback
      end
      return value
    end,
    Set = function(_, path, value)
      values[path] = value
    end,
  },
  ConfigRegistry = {
    RegisterPage = function(_, page)
      pages[page.id] = page
    end,
  },
  Modules = {
    Register = function(_, id, definition)
      assert(id == "skillCards", "module id should remain stable")
      moduleDefinition = definition
    end,
    RefreshStates = function() end,
  },
  SkillCards = {
    Catalog = {
      GetSnapshot = function() return nil end,
      GetStatusText = function() return "Not scanned." end,
      IsOwnershipReady = function() return false, "Cache needed." end,
    },
    Window = {
      Open = function() end,
      Refresh = function() end,
      ResetPosition = function() end,
    },
  },
}

dofile(root .. "/modules/skillcards/SkillCardsModule.lua")
assert(moduleDefinition and moduleDefinition.enabledPath == "modules.skillCards", "Skill Cards must use the module lifecycle")
moduleDefinition.OnInitialize()

assert(pages.skillcards, "Skill Cards needs a first-class root page")
assert(pages["skillcards.behavior"] and pages["skillcards.behavior"].parent == "skillcards", "behavior page should remain under Skill Cards")
assert(pages["skillcards.safety"] and pages["skillcards.safety"].parent == "skillcards", "safety page should remain under Skill Cards")
assert(pages["skillcards.display"] and pages["skillcards.display"].parent == "skillcards", "display page should remain under Skill Cards")

local rootOptions = pages.skillcards.options()
assert(rootOptions[1].type == "status", "Skill Cards root should lead with live status")

local behavior = pages["skillcards.behavior"].options()
assert(behavior[1].type == "segmented" and #behavior[1].choices == 3, "loot behavior should offer off, toast, and open")
assert(behavior[2].type == "segmented" and #behavior[2].choices == 3, "vendor opening should offer off, compact, and open")
assert(behavior[3].type == "segmented" and #behavior[3].choices == 3, "vendor closing should offer keep, compact, and hide")

assert(values["skillCards.migrationVersion"] == 1, "legacy settings migration must be versioned")
assert(values["skillCards.showTooltips"] == false, "legacy tooltip choice should migrate")
assert(values["skillCards.rarityBorders"] == true, "legacy rarity border choice should migrate")
assert(values["skillCards.protectStandard"] == false, "legacy force-standard should invert into protection")
assert(values["skillCards.protectGolden"] == true, "legacy golden default should invert into protection")
assert(values["skillCards.lootBehavior"] == "off", "legacy loot auto-open should map to tri-state behavior")
assert(values["skillCards.vendorOpenBehavior"] == "open", "legacy vendor auto-open should migrate")
assert(values["skillCards.vendorCloseBehavior"] == "keep", "legacy vendor-close behavior should migrate")

io.write("PASS Skill Cards config registers the Ledger and migrates legacy safety behavior\n")

