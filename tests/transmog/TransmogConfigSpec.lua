local root = (... and ... ~= "" and ...) or "."

local pages = {}
local registeredModule
local selectedModes = {}
local runtimeValue = false
local reviewAlertsValue = true

local qualityOptions = {
  { id = "poor", title = "Poor (Grey)" },
  { id = "common", title = "Common (White)" },
  { id = "uncommon", title = "Uncommon (Green)" },
  { id = "rare", title = "Rare (Blue)" },
  { id = "epic", title = "Epic (Purple)" },
  { id = "legendary", title = "Legendary (Orange)" },
  { id = "artifact", title = "Artifact" },
  { id = "heirloom", title = "Heirloom" },
}

local Collector = {
  qualityOptions = qualityOptions,
  MigrateAutomationRules = function() end,
  GetQualityModeByKey = function(_, key)
    return selectedModes[key] or "ask"
  end,
  SetQualityMode = function(_, key, mode)
    selectedModes[key] = mode
  end,
  GetRootSummaryText = function()
    return "status"
  end,
  GetToggleKey = function()
    return ""
  end,
  SetToggleKey = function() end,
  SetEnabled = function(_, enabled)
    runtimeValue = enabled
  end,
  SetReviewAlertsEnabled = function(_, enabled)
    reviewAlertsValue = enabled
  end,
  GetBlacklistEntries = function()
    return {}
  end,
  AddBlacklistItem = function() end,
  RemoveBlacklistItem = function() end,
  ClearBlacklist = function() end,
}

_G.AscensionPlus = {
  ConfigRegistry = {
    RegisterPage = function(_, page)
      pages[page.id] = page
    end,
  },
  TransmogAutoCollect = Collector,
  TransmogAppearanceCatalog = {
    GetApiSummary = function() return "ready" end,
    GetSnapshotSummary = function() return "empty" end,
  },
  TransmogAppearanceInbox = {
    Open = function() end,
  },
  Database = {
    Get = function(_, path, fallback)
      if path == "transmog.autoCollect.enabled" then
        return runtimeValue
      elseif path == "transmog.autoCollect.showReviewAlerts" then
        return reviewAlertsValue
      end
      return fallback
    end,
  },
  Modules = {
    Register = function(_, _, module)
      registeredModule = module
    end,
    RefreshStates = function() end,
  },
}

dofile(root .. "/modules/transmog/TransmogModule.lua")
registeredModule.OnInitialize()

local autoPage = pages["transmog.auto-collect"]
assert(autoPage and type(autoPage.options) == "function", "Auto Collect config page must be registered")

local options = autoPage.options()
local segmented = {}
local runtimeToggle
local reviewAlertsToggle
for index = 1, #options do
  local option = options[index]
  if option.type == "segmented" then
    segmented[#segmented + 1] = option
  elseif option.label == "Enable automatic appearance processing" then
    runtimeToggle = option
  elseif option.label == "Show appearance review alerts after loot" then
    reviewAlertsToggle = option
  end
end

assert(#segmented == 8, "every supported item quality needs its own visible rule selector")
for index = 1, #segmented do
  local choices = segmented[index].choices
  assert(#choices == 3, "each quality selector must expose three separate buttons")
  assert(choices[1].value == "never" and choices[2].value == "ask" and choices[3].value == "auto", "quality buttons must be NEVER, ASK, and AUTO in a stable order")
end

segmented[4].set("auto")
assert(selectedModes.rare == "auto", "clicking a quality button must persist that exact mode")
assert(runtimeToggle and runtimeToggle.get() == false, "runtime must remain visibly disabled until opted in")
runtimeToggle.set(true)
assert(runtimeValue == true, "runtime config control must use the collector lifecycle setter")
assert(reviewAlertsToggle and reviewAlertsToggle.get() == true, "loot review alerts must be visible and enabled by default")
reviewAlertsToggle.set(false)
assert(reviewAlertsValue == false, "review alert control must use the collector lifecycle setter")

io.write("PASS transmog config exposes quality rules and independent loot review alerts\n")
