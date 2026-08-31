local _, AP = ...
AP = AP or _G.Levo or _G.WotLKPlus or _G.AscensionPlus

if not AP then
  return
end

if AP.Compatibility
  and type(AP.Compatibility.HasSkillCards) == "function"
  and not AP.Compatibility:HasSkillCards() then
  return
end

local Registry = AP.ConfigRegistry
local Catalog = AP.SkillCards.Catalog
local Window = AP.SkillCards.Window

local Runtime = {
  enabled = false,
  frame = nil,
  hookedFrame = nil,
  pendingScan = nil,
  pendingElapsed = 0,
  pendingLootBehavior = nil,
  pendingDisableCleanup = false,
  ownershipPollElapsed = 0,
  legacyWarningShown = false,
}

AP.SkillCards.Runtime = Runtime

local BEHAVIOR_CHOICES = {
  loot = {
    { value = "off", label = "OFF", color = "muted" },
    { value = "toast", label = "TOAST", color = "gold" },
    { value = "open", label = "OPEN LEDGER", color = "green" },
  },
  vendorOpen = {
    { value = "off", label = "OFF", color = "muted" },
    { value = "compact", label = "COMPACT", color = "gold" },
    { value = "open", label = "OPEN LEDGER", color = "green" },
  },
  vendorClose = {
    { value = "keep", label = "KEEP OPEN", color = "muted" },
    { value = "compact", label = "COMPACT", color = "gold" },
    { value = "hide", label = "HIDE", color = "green" },
  },
}

local function isLegacyLoaded()
  if type(IsAddOnLoaded) ~= "function" then
    return false
  end
  local ok, loaded = pcall(IsAddOnLoaded, "AscendedSkillCards")
  return ok and loaded and true or false
end

local function isInCombat()
  return type(InCombatLockdown) == "function" and InCombatLockdown() and true or false
end

local function migrateLegacySettings()
  local version = tonumber(AP.Database:Get("skillCards.migrationVersion", 0)) or 0
  if version >= 1 then
    return
  end

  local old = _G.AscendedSkillCardsDB
  if type(old) == "table" then
    if old.EnableTooltips ~= nil then
      AP.Database:Set("skillCards.showTooltips", old.EnableTooltips and true or false)
    end
    if old.EnableColorSkillCardButtonBorderByRarity ~= nil then
      AP.Database:Set("skillCards.rarityBorders", old.EnableColorSkillCardButtonBorderByRarity and true or false)
    end
    if old.ForceExchangeCards ~= nil then
      AP.Database:Set("skillCards.protectStandard", not old.ForceExchangeCards)
    end
    if old.ForceExchangeGoldenCards ~= nil then
      AP.Database:Set("skillCards.protectGolden", not old.ForceExchangeGoldenCards)
    end
    if old.ShowOnOpeningSealedDeck ~= nil then
      AP.Database:Set("skillCards.lootBehavior", old.ShowOnOpeningSealedDeck and "open" or "off")
    end
    if old.ShowOnOpeningExchangeWindow ~= nil then
      AP.Database:Set("skillCards.vendorOpenBehavior", old.ShowOnOpeningExchangeWindow and "open" or "off")
    end
    if old.HideOnClosingExchangeWindow ~= nil then
      AP.Database:Set("skillCards.vendorCloseBehavior", old.HideOnClosingExchangeWindow and "hide" or "keep")
    end
  end

  AP.Database:Set("skillCards.migrationVersion", 1)
end

local function refreshConfigAndLedger()
  if Window.frame then
    Window:Refresh(false)
  end
  if AP.ConfigWindow and AP.ConfigWindow.frame and AP.ConfigWindow.frame:IsShown() then
    AP.ConfigWindow:RefreshContent()
  end
end

local function getCollectionValue()
  local snapshot = Catalog:GetSnapshot()
  if not snapshot then
    return "NOT SCANNED"
  end
  if not snapshot.scanReady then
    return "UNAVAILABLE"
  end
  if not snapshot.ownershipReady then
    return "CACHE NEEDED"
  end
  local unknown = snapshot.unknown.total
  if unknown.uniqueIDs > 0 then
    return tostring(unknown.uniqueIDs) .. " UNLEARNED"
  end
  return "READY"
end

local function getCollectionColor()
  local snapshot = Catalog:GetSnapshot()
  if not snapshot or not snapshot.scanReady or not snapshot.ownershipReady then
    return "orange"
  end
  return snapshot.unknown.total.uniqueIDs > 0 and "orange" or "green"
end

local function refreshModuleState()
  AP.Modules:RefreshStates()
end

local function registerConfigPages()
  Registry:RegisterPage({
    id = "skillcards",
    title = "Skill Cards",
    order = 20,
    description = "Inventory intelligence, unlearned-card protection, and vendor exchange controls.",
    searchText = "skill cards skillcard ledger collection unlearned known vanity sealed deck vendor exchange lucky golden",
    options = function()
      local options = {
        {
          type = "status",
          label = "Collection state",
          value = getCollectionValue,
          color = getCollectionColor,
          description = function()
            return Catalog:GetStatusText()
          end,
        },
      }

      if isLegacyLoaded() then
        options[#options + 1] = {
          type = "status",
          label = "Legacy addon conflict",
          value = "DETECTED",
          color = "orange",
          description = "AscendedSkillCards is also enabled. Disable it at character select to avoid duplicate bag scans, windows, and vendor hooks.",
        }
      end

      options[#options + 1] = {
        type = "button",
        label = "Skill Card Ledger",
        buttonText = "Open Ledger",
        description = "Inspect carried cards and use the contextual Exchange Desk while Ascension's vendor is open.",
        disabled = function()
          return not AP.Database:Get("modules.skillCards", true)
        end,
        action = function()
          Window:Open("expanded")
        end,
      }
      options[#options + 1] = {
        type = "toggle",
        path = "modules.skillCards",
        label = "Enable Skill Card Ledger",
        description = "Enable inventory scans, contextual vendor behavior, loot notifications, and /lv cards.",
        onChange = refreshModuleState,
      }
      options[#options + 1] = {
        type = "section",
        label = "Safety model",
        description = "Ownership uncertainty always fails closed. Levo never clicks a global confirmation button; the native vendor confirmation remains your final commit.",
      }
      return options
    end,
  })

  Registry:RegisterPage({
    id = "skillcards.behavior",
    parent = "skillcards",
    title = "Behavior",
    order = 10,
    description = "Choose when the Ledger appears without turning routine loot into a distraction.",
    searchText = "skill cards behavior auto show loot sealed deck toast vendor open close compact hide",
    options = function()
      return {
        {
          type = "segmented",
          path = "skillCards.lootBehavior",
          label = "After a sealed-deck result",
          description = "Stay quiet, show a small click-through notification, or open the full Ledger after skill-card loot.",
          choices = BEHAVIOR_CHOICES.loot,
          default = "toast",
        },
        {
          type = "segmented",
          path = "skillCards.vendorOpenBehavior",
          label = "When the exchange vendor opens",
          description = "Do nothing, show the passive inventory strip, or open the full Ledger and contextual Exchange Desk.",
          choices = BEHAVIOR_CHOICES.vendorOpen,
          default = "open",
        },
        {
          type = "segmented",
          path = "skillCards.vendorCloseBehavior",
          label = "When the exchange vendor closes",
          description = "Keep the Ledger as-is, return it to the compact strip, or hide it.",
          choices = BEHAVIOR_CHOICES.vendorClose,
          default = "hide",
        },
        {
          type = "toggle",
          path = "skillCards.showTooltips",
          label = "Show card and exchange tooltips",
          description = "Show native item details and exact exchange blocking reasons on hover.",
        },
      }
    end,
  })

  Registry:RegisterPage({
    id = "skillcards.safety",
    parent = "skillcards",
    title = "Exchange & Safety",
    order = 20,
    description = "Protect unlearned designs and keep every exchange explicit.",
    searchText = "skill cards exchange safety protect force unknown unlearned standard golden confirmation fail closed",
    options = function()
      return {
        {
          type = "status",
          label = "Ownership authority",
          value = function()
            local ready = Catalog:IsOwnershipReady()
            return ready and "READY" or "LOCKED"
          end,
          color = function()
            local ready = Catalog:IsOwnershipReady()
            return ready and "green" or "orange"
          end,
          description = function()
            local ready, reason = Catalog:IsOwnershipReady()
            if ready then
              return "Ascension ownership data is initialized; learned and unlearned cards can be distinguished safely."
            end
            return tostring(reason or "Open Vanity Collections once this session to initialize ownership data.")
          end,
        },
        {
          type = "toggle",
          path = "skillCards.protectStandard",
          label = "Protect unlearned standard and lucky cards",
          description = "Block Normal and Lucky exchanges while any unlearned standard-group card is carried.",
          onChange = refreshConfigAndLedger,
        },
        {
          type = "toggle",
          path = "skillCards.protectGolden",
          label = "Protect unlearned golden cards",
          description = "Block Golden and Golden Lucky exchanges while any unlearned golden-group card is carried.",
          onChange = refreshConfigAndLedger,
        },
        {
          type = "section",
          label = "Two confirmations, two jobs",
          description = "When protection is intentionally disabled, Levo asks once per card group for the current session. The native exchange confirmation then remains visible and must still be accepted manually.",
        },
      }
    end,
  })

  Registry:RegisterPage({
    id = "skillcards.display",
    parent = "skillcards",
    title = "Display",
    order = 30,
    description = "Control item emphasis and restore the Ledger workspace.",
    searchText = "skill cards display appearance rarity border window layout position reset compact",
    options = function()
      return {
        {
          type = "toggle",
          path = "skillCards.rarityBorders",
          label = "Color card borders by item rarity",
          description = "Use canonical item-quality colors around card art. Golden and Lucky types remain text-labeled, so meaning never depends on color alone.",
          onChange = refreshConfigAndLedger,
        },
        {
          type = "button",
          label = "Compact inventory strip",
          buttonText = "Show Compact",
          description = "Open a passive four-count strip without the card grid or exchange controls.",
          disabled = function()
            return not AP.Database:Get("modules.skillCards", true)
          end,
          action = function()
            Window:Open("compact")
          end,
        },
        {
          type = "button",
          label = "Reset Ledger position and size",
          buttonText = "Reset Ledger",
          description = "Restore the default centered position and expanded dimensions.",
          action = function()
            Window:ResetPosition()
          end,
        },
      }
    end,
  })
end

function Runtime:HandleVendorOpened()
  self:ScheduleScan("exchange vendor opened")
  local behavior = AP.Database:Get("skillCards.vendorOpenBehavior", "open")
  if behavior == "compact" then
    Window:Open("compact")
  elseif behavior == "open" then
    Window:Open("expanded")
  elseif Window.frame and Window.frame:IsShown() then
    Window:Refresh(false)
  end
end

function Runtime:TryHookExchangeFrame()
  local exchangeFrame = _G.SkillCardExchangeUI
  if not exchangeFrame then
    return false
  end

  Catalog:SetExchangeFrame(exchangeFrame)
  if self.hookedFrame == exchangeFrame then
    if self.frame then
      self.frame:UnregisterEvent("ADDON_LOADED")
    end
    if self.enabled and Catalog:IsExchangeOpen() then
      self:HandleVendorOpened()
    end
    return true
  end
  if type(exchangeFrame.HookScript) ~= "function" then
    return false
  end

  exchangeFrame:HookScript("OnShow", function()
    if not Runtime.enabled then
      return
    end
    Runtime:HandleVendorOpened()
  end)

  exchangeFrame:HookScript("OnHide", function()
    if not Runtime.enabled or not Window.frame then
      return
    end
    if not Window.frame:IsShown() and Window.pendingVisibility ~= "show" then
      return
    end
    local behavior = AP.Database:Get("skillCards.vendorCloseBehavior", "hide")
    if behavior == "hide" then
      Window:RequestHide(true)
    elseif behavior == "compact" then
      Window:SetMode("compact")
      Window:Refresh(false)
    else
      Window:Refresh(false)
    end
  end)

  self.hookedFrame = exchangeFrame
  if self.frame then
    self.frame:UnregisterEvent("ADDON_LOADED")
  end
  if Catalog:IsExchangeOpen() then
    self:HandleVendorOpened()
  end
  return true
end

function Runtime:ScheduleScan(source, lootBehavior)
  self.pendingScan = source or "event"
  self.pendingElapsed = 0
  if lootBehavior then
    self.pendingLootBehavior = lootBehavior
  end
end

function Runtime:FlushScan()
  if not self.pendingScan then
    return
  end

  local source = self.pendingScan
  local lootBehavior = self.pendingLootBehavior
  self.pendingScan = nil
  self.pendingLootBehavior = nil
  self.pendingElapsed = 0

  local before = Catalog:GetSnapshot()
  local beforeUnknown = before and before.unknown and before.unknown.total.uniqueIDs or 0
  local snapshot = Catalog:Scan(source)
  local afterUnknown = snapshot.unknown and snapshot.unknown.total.uniqueIDs or 0

  if Window.frame and Window.frame:IsShown() then
    Window:Refresh(false)
  end
  if AP.ConfigWindow and AP.ConfigWindow.frame and AP.ConfigWindow.frame:IsShown() then
    local selectedPageId = tostring(AP.ConfigWindow.selectedPageId or "")
    if selectedPageId == "general" or selectedPageId:find("^skillcards") then
      AP.ConfigWindow:RefreshContent()
    end
  end

  if lootBehavior == "open" then
    if isInCombat() then
      Window:ShowToast("Skill cards changed while in combat. Click to inspect them after combat.")
    else
      Window:Open("expanded")
    end
  elseif lootBehavior == "toast" then
    local gained = math.max(0, afterUnknown - beforeUnknown)
    if gained > 0 then
      Window:ShowToast(string.format("%d new unlearned design%s found. Click to inspect.", gained, gained == 1 and "" or "s"))
    else
      Window:ShowToast("Skill cards added to your bags. Click to inspect the Ledger.")
    end
  end
end

function Runtime:OnUpdate(elapsed)
  elapsed = tonumber(elapsed) or 0
  if self.pendingScan then
    self.pendingElapsed = self.pendingElapsed + elapsed
    if self.pendingElapsed >= 0.12 then
      self:FlushScan()
    end
  end

  local snapshot = Catalog:GetSnapshot()
  local ledgerVisible = Window.frame and Window.frame:IsShown()
  if ledgerVisible and snapshot and not snapshot.ownershipReady and not isInCombat() then
    self.ownershipPollElapsed = self.ownershipPollElapsed + elapsed
    if self.ownershipPollElapsed >= 2 then
      self.ownershipPollElapsed = 0
      Catalog:Scan("ownership cache retry")
      Window:Refresh(false)
    end
  else
    self.ownershipPollElapsed = 0
  end
end

function Runtime:OnEvent(event, ...)
  if not self.enabled and event ~= "PLAYER_REGEN_ENABLED" then
    return
  end

  if event == "PLAYER_REGEN_DISABLED" then
    Window:OnCombatStarted()
  elseif event == "BAG_UPDATE" then
    self:ScheduleScan("bag update")
  elseif event == "CHAT_MSG_LOOT" then
    local message = string.lower(tostring((...) or ""))
    if message:find("skill card", 1, true) then
      local behavior = AP.Database:Get("skillCards.lootBehavior", "toast")
      if behavior ~= "off" then
        self:ScheduleScan("skill-card loot", behavior)
      end
    end
  elseif event == "PLAYER_REGEN_ENABLED" then
    Window:OnCombatEnded()
    if self.pendingDisableCleanup and self.frame then
      self.pendingDisableCleanup = false
      self.frame:UnregisterAllEvents()
      self.frame:SetScript("OnUpdate", nil)
    end
  elseif event == "PLAYER_ENTERING_WORLD" then
    self:TryHookExchangeFrame()
    self:ScheduleScan(string.lower(event))
  elseif event == "ADDON_LOADED" then
    self:TryHookExchangeFrame()
    local snapshot = Catalog:GetSnapshot()
    if not snapshot or not snapshot.ownershipReady then
      self:ScheduleScan("addon loaded cache check")
    end
  end
end

function Runtime:Enable()
  if self.enabled then
    return
  end
  self.enabled = true
  self.pendingDisableCleanup = false
  self.ownershipPollElapsed = 0
  if Window.pendingVisibility == "hide" then
    Window.pendingVisibility = nil
  end

  Window:Initialize()
  self.frame = self.frame or CreateFrame("Frame")
  self.frame:SetScript("OnEvent", function(_, event, ...)
    Runtime:OnEvent(event, ...)
  end)
  self.frame:SetScript("OnUpdate", function(_, elapsed)
    Runtime:OnUpdate(elapsed)
  end)
  self.frame:RegisterEvent("BAG_UPDATE")
  self.frame:RegisterEvent("CHAT_MSG_LOOT")
  self.frame:RegisterEvent("PLAYER_REGEN_ENABLED")
  self.frame:RegisterEvent("PLAYER_REGEN_DISABLED")
  self.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
  self.frame:RegisterEvent("ADDON_LOADED")

  self:TryHookExchangeFrame()
  Catalog:Scan("module enabled")
  Window:Refresh(false)

  if isLegacyLoaded() and not self.legacyWarningShown then
    self.legacyWarningShown = true
    AP:Print("|cffffc45cAscendedSkillCards is also enabled.|r Disable the legacy addon to avoid duplicate windows and bag scans.")
  end
end

function Runtime:Disable()
  self.enabled = false
  self.pendingScan = nil
  self.pendingLootBehavior = nil
  self.ownershipPollElapsed = 0
  if type(StaticPopup_Hide) == "function" then
    StaticPopup_Hide("ASCENSIONPLUS_SKILLCARD_RISK")
  end
  local hideDeferred = Window.frame and not Window:RequestHide(true)
  if self.frame then
    self.frame:UnregisterAllEvents()
    self.frame:SetScript("OnUpdate", nil)
    if hideDeferred then
      self.pendingDisableCleanup = true
      self.frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    else
      self.pendingDisableCleanup = false
    end
  end
  if Window.toast then
    Window.toast:Hide()
  end
end

AP.Modules:Register("skillCards", {
  order = 21,
  enabledPath = "modules.skillCards",

  OnInitialize = function()
    migrateLegacySettings()
    registerConfigPages()
  end,

  OnEnable = function()
    Runtime:Enable()
  end,

  OnDisable = function()
    Runtime:Disable()
  end,
})
