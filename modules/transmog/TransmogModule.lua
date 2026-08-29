local _, AP = ...
AP = AP or _G.AscensionPlus

if AP.Compatibility
  and type(AP.Compatibility.HasAppearanceCollection) == "function"
  and not AP.Compatibility:HasAppearanceCollection() then
  return
end

local Registry = AP.ConfigRegistry
local Collector = AP.TransmogAutoCollect
local Catalog = AP.TransmogAppearanceCatalog
local Inbox = AP.TransmogAppearanceInbox

local QUALITY_RULE_CHOICES = {
  { value = "never", label = "NEVER", color = "red" },
  { value = "ask", label = "ASK", color = "orange" },
  { value = "auto", label = "AUTO", color = "green" },
}

local function refreshModuleState()
  AP.Modules:RefreshStates()
end

local function refreshCollectorView()
  if Collector.OnFilterSettingsChanged then
    Collector:OnFilterSettingsChanged()
  end
end

local function buildQualityOptions()
  local options = {}
  for index = 1, #Collector.qualityOptions do
    local quality = Collector.qualityOptions[index]
    local qualityKey = quality.id
    options[#options + 1] = {
      type = "segmented",
      label = quality.title,
      description = "",
      choices = QUALITY_RULE_CHOICES,
      get = function()
        return Collector:GetQualityModeByKey(qualityKey)
      end,
      set = function(mode)
        Collector:SetQualityMode(qualityKey, mode)
      end,
    }
  end
  return options
end

AP.Modules:Register("transmog", {
  order = 30,
  enabledPath = "modules.transmog",

  OnInitialize = function()
    Collector:MigrateAutomationRules()

    Registry:RegisterPage({
      id = "transmog",
      title = "Appearances",
      order = 30,
      description = "Loot-gated wardrobe review and automatic collection tools for Ascension appearance items.",
      searchText = "transmog appearance wardrobe auto collect review alert popup blacklist keybind loot bag inventory",
      options = function()
        return {
          {
            type = "section",
            label = "Automatic appearance collection",
            description = "WotLK Plus uses this server's runtime wardrobe API, scans only after loot/new-item signals, and routes each uncollected appearance through your NEVER, ASK, or AUTO rarity rule. Review alerts can stay active without allowing automatic binding.",
          },
          {
            type = "text",
            text = function()
              return Collector:GetRootSummaryText()
            end,
          },
          {
            type = "button",
            label = "Appearance Inbox",
            buttonText = "Open Inbox",
            description = "Show carried appearances, their live Ascension state, and the exact rule that will apply on loot.",
            action = function()
              Inbox:Open("needs")
            end,
          },
        }
      end,
    })

    Registry:RegisterPage({
      id = "transmog.appearance-inbox",
      parent = "transmog",
      title = "Appearance Inbox",
      order = 5,
      description = "Inspect authoritative Ascension wardrobe state and manually process a specific carried appearance.",
      searchText = "appearance inbox api needs collection collected tooltip ctrl alt runtime diagnostics queue inventory",
      options = function()
        return {
          {
            type = "section",
            label = "Authoritative wardrobe state",
            description = "The Needs view is driven by C_Appearance and C_AppearanceCollection, not tooltip text. Filtered and blacklisted appearances remain visible with the exact reason they are blocked.",
          },
          {
            type = "text",
            label = "Runtime API",
            text = function()
              return Catalog:GetApiSummary()
            end,
          },
          {
            type = "text",
            label = "Last inventory inspection",
            text = function()
              return Catalog:GetSnapshotSummary()
            end,
          },
          {
            type = "button",
            label = "Open the skinned menu",
            buttonText = "Open Appearance Inbox",
            description = "Open Needs, All, and API views. Opening the menu performs one explicit inventory inspection.",
            action = function()
              Inbox:Open("needs")
            end,
          },
          {
            type = "section",
            label = "Scan discipline",
            description = "There is no continuous bag polling. Runtime decisions are discovered only from loot/new-item events; opening or refreshing this menu performs a read-only inventory inspection.",
          },
        }
      end,
    })

    Registry:RegisterPage({
      id = "transmog.auto-collect",
      parent = "transmog",
      title = "Auto Collect",
      order = 10,
      description = "Control when WotLK Plus ignores, asks about, or automatically learns carried appearances.",
      searchText = "auto collect review alert popup hotkey keybind loot scan quality armor weapon runtime on off",
      options = function()
        local options = {
          {
            type = "toggle",
            path = "modules.transmog",
            label = "Enable transmog module",
            description = "Loads the Appearance Inbox, rules service, hotkey, and loot-gated appearance processing.",
            onChange = refreshModuleState,
          },
          {
            type = "section",
            label = "Runtime control",
            description = "Discovery and binding are separate. Review alerts perform a read-only loot scan; automatic processing permits AUTO rules and explicit review choices to bind an item.",
          },
          {
            type = "toggle",
            label = "Enable automatic appearance processing",
            description = "Permit AUTO rarity rules to learn appearances after loot. Disable this instantly with the checkbox or configured hotkey; review alerts can remain active without binding anything.",
            disabled = function()
              return not AP.Database:Get("modules.transmog", true)
            end,
            get = function()
              return AP.Database:Get("transmog.autoCollect.enabled", false)
            end,
            set = function(enabled)
              Collector:SetEnabled(enabled, false, "config")
            end,
          },
          {
            type = "toggle",
            label = "Show appearance review alerts after loot",
            description = "Inspect only loot-affected bags and open the compact review queue for ASK items or AUTO items while automatic processing is off. Discovery alone never binds an item.",
            disabled = function()
              return not AP.Database:Get("modules.transmog", true)
            end,
            get = function()
              return AP.Database:Get("transmog.autoCollect.showReviewAlerts", true)
            end,
            set = function(enabled)
              Collector:SetReviewAlertsEnabled(enabled)
            end,
          },
          {
            type = "text",
            label = "Current state",
            text = function()
              return Collector:GetRootSummaryText()
            end,
          },
          {
            type = "keybind",
            label = "Runtime toggle hotkey",
            description = "Set a keyboard, mouse, or modifier combination that toggles automatic appearance processing on or off.",
            get = function()
              return Collector:GetToggleKey()
            end,
            set = function(binding)
              Collector:SetToggleKey(binding)
            end,
          },
          {
            type = "toggle",
            path = "transmog.autoCollect.autoConfirmBinding",
            label = "Automatically confirm AUTO binding prompts",
            description = "Accept Ascension's bind dialog for AUTO rules. Choosing LEARN ONCE or AUTO RARITY in the review window is already explicit consent for the selected item.",
          },
          {
            type = "toggle",
            path = "transmog.autoCollect.deferUntilOutOfCombat",
            label = "Wait until out of combat",
            description = "Defer scans and collection requests while combat lockdown is active.",
          },
          {
            type = "toggle",
            path = "transmog.autoCollect.showChatMessages",
            label = "Show transmog status in chat",
            description = "Report runtime changes, permanent blacklist decisions, and collection batch results.",
          },
          {
            type = "section",
            label = "Allowed item types",
            description = "A quality rule can process an item only when its item type is also allowed.",
          },
          {
            type = "toggle",
            path = "transmog.autoCollect.includeArmor",
            label = "Collect armor appearances",
            description = "Allow items classified as armor to be processed.",
            onChange = refreshCollectorView,
          },
          {
            type = "toggle",
            path = "transmog.autoCollect.includeWeapons",
            label = "Collect weapon appearances",
            description = "Allow items classified as weapons to be processed.",
            onChange = refreshCollectorView,
          },
          {
            type = "toggle",
            path = "transmog.autoCollect.includeOtherEquippable",
            label = "Collect other equippable items",
            description = "Allow other equippable items with valid appearance IDs to be processed.",
            onChange = refreshCollectorView,
          },
          {
            type = "divider",
          },
          {
            type = "section",
            label = "Rules by item quality",
            description = "Choose one behavior per rarity. ASK adds matching loot to the compact review queue. In that window, LEARN ONCE binds only the current item, AUTO RARITY changes that entire rarity to AUTO, NEVER ITEM blacklists the exact item ID, and LATER ALL or x defers the queue for this login.",
          },
        }

        local qualityOptions = buildQualityOptions()
        for index = 1, #qualityOptions do
          options[#options + 1] = qualityOptions[index]
        end

        return options
      end,
    })

    Registry:RegisterPage({
      id = "transmog.blacklist",
      parent = "transmog",
      title = "Blacklist",
      order = 20,
      description = "Blacklist specific item IDs so they never auto-bind for wardrobe collection.",
      searchText = "transmog blacklist drag item remove clear ignore",
      options = function()
        return {
          {
            type = "blacklist",
            label = "Ignored items",
            description = "Drag an item here or choose NEVER ITEM in the appearance review window. Use Remove to allow one item ID again or Clear All to wipe the blacklist.",
            get = function()
              return Collector:GetBlacklistEntries()
            end,
            onAdd = function(itemID, itemLink)
              Collector:AddBlacklistItem(itemID, itemLink)
            end,
            onRemove = function(itemID)
              Collector:RemoveBlacklistItem(itemID)
            end,
            onClear = function()
              Collector:ClearBlacklist()
            end,
          },
        }
      end,
    })
  end,

  OnEnable = function()
    Collector:Enable()
  end,

  OnDisable = function()
    Collector:Disable()
  end,
})
