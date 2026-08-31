local _, AP = ...
AP = AP or _G.Levo or _G.WotLKPlus or _G.AscensionPlus

local Collector = {
  moduleEnabled = false,
  eventFrame = nil,
  bindingButton = nil,
  pendingLootWindow = false,
  lootWindowOpen = false,
  pendingBags = nil,
  pendingScanAt = nil,
  pendingBindingRefresh = false,
  collectionQueue = {},
  queuedAppearanceIDs = {},
  activeRequest = nil,
  requestSequence = 0,
  nextRequestAt = nil,
  collectionBatch = nil,
  popupHooked = false,
  collectCallInProgress = false,
  pendingPopup = nil,
  popupConfirmAt = nil,
}

AP.TransmogAutoCollect = Collector

Collector.qualityOptions = {
  { id = "poor", quality = 0, title = "Poor (Grey)" },
  { id = "common", quality = 1, title = "Common (White)" },
  { id = "uncommon", quality = 2, title = "Uncommon (Green)" },
  { id = "rare", quality = 3, title = "Rare (Blue)" },
  { id = "epic", quality = 4, title = "Epic (Purple)" },
  { id = "legendary", quality = 5, title = "Legendary (Orange)" },
  { id = "artifact", quality = 6, title = "Artifact" },
  { id = "heirloom", quality = 7, title = "Heirloom" },
}

Collector.RULES_VERSION = 2
Collector.qualityKeys = {
  [0] = "poor",
  [1] = "common",
  [2] = "uncommon",
  [3] = "rare",
  [4] = "epic",
  [5] = "legendary",
  [6] = "artifact",
  [7] = "heirloom",
}

local VALID_QUALITY_MODES = {
  never = true,
  ask = true,
  auto = true,
}

local function safeCall(fn, ...)
  if type(fn) ~= "function" then
    return false, "function unavailable"
  end
  return pcall(fn, ...)
end

local function hasEntries(value)
  return type(value) == "table" and next(value) ~= nil
end

function Collector:HasAppearanceApi()
  return type(C_Appearance) == "table"
    and type(C_Appearance.GetItemAppearanceID) == "function"
    and type(C_AppearanceCollection) == "table"
    and type(C_AppearanceCollection.IsAppearanceCollected) == "function"
    and type(C_AppearanceCollection.CollectItemAppearance) == "function"
    and type(GetContainerItemID) == "function"
    and type(GetContainerItemGUID) == "function"
end

function Collector:IsRuntimeEnabled()
  return self.moduleEnabled
    and AP.Database:Get("transmog.autoCollect.automationAuthorized", false)
    and AP.Database:Get("transmog.autoCollect.enabled", false)
end

function Collector:IsAutomationAuthorized()
  return AP.Database:Get("transmog.autoCollect.automationAuthorized", false) and true or false
end

function Collector:IsReviewAlertsEnabled()
  return self.moduleEnabled
    and self:IsAutomationAuthorized()
    and AP.Database:Get("transmog.autoCollect.showReviewAlerts", true)
end

function Collector:IsLootInspectionEnabled()
  return self:IsRuntimeEnabled() or self:IsReviewAlertsEnabled()
end

function Collector:ShouldPrint()
  return AP.Database:Get("transmog.autoCollect.showChatMessages", true)
end

function Collector:ShouldAutoConfirmBinding(request)
  if request and request.manualConfirmation then
    return false
  end
  if request and request.ruleApproved then
    return true
  end
  return self:IsAutomationAuthorized()
    and AP.Database:Get("transmog.autoCollect.autoConfirmBinding", true)
end

function Collector:GetToggleKey()
  return AP.Database:Get("transmog.autoCollect.toggleKey", "")
end

function Collector:SetToggleKey(binding)
  AP.Database:Set("transmog.autoCollect.toggleKey", binding or "")
  self:RefreshBinding()
end

function Collector:GetRuntimeStatusLabel()
  if not self.moduleEnabled then
    return "Module Disabled"
  end
  if not self:IsAutomationAuthorized() then
    return "Rules Unavailable"
  end
  if AP.Database:Get("transmog.autoCollect.enabled", false) then
    return "Enabled"
  end
  return "Disabled"
end

function Collector:GetPendingRequestCount()
  return #self.collectionQueue + (self.activeRequest and 1 or 0)
end

function Collector:GetRootSummaryText()
  local blacklistEntries = self:GetBlacklistEntries()
  local key = self:GetToggleKey()
  local keyLabel = (key ~= "" and key) or "Not Bound"
  local autoCount, askCount, neverCount = self:GetQualityModeCounts()
  local rules = AP.TransmogAppearanceRules
  local waiting = rules and rules.GetPendingAskCount and rules:GetPendingAskCount() or 0
  local alertState = self:IsReviewAlertsEnabled() and "On" or "Off"
  return string.format(
    "Automatic learning: %s. Review alerts: %s. Hotkey: %s. Quality rules: %d AUTO, %d ASK, %d NEVER. Blacklist: %d. Collection queue: %d. Waiting for review: %d.",
    self:GetRuntimeStatusLabel(),
    alertState,
    keyLabel,
    autoCount,
    askCount,
    neverCount,
    #blacklistEntries,
    self:GetPendingRequestCount(),
    waiting
  )
end

function Collector:GetQualityEnabled(qualityKey)
  return self:GetQualityModeByKey(qualityKey) ~= "never"
end

function Collector:MigrateAutomationRules()
  local version = tonumber(AP.Database:Get("transmog.autoCollect.rulesVersion", 0)) or 0
  if version >= self.RULES_VERSION then
    return false
  end

  if version < 1 then
    for index = 1, #self.qualityOptions do
      local quality = self.qualityOptions[index]
      local legacyAllowed = AP.Database:Get("transmog.autoCollect.qualities." .. quality.id, false)
      AP.Database:Set(
        "transmog.autoCollect.qualityModes." .. quality.id,
        legacyAllowed and "ask" or "never"
      )
    end

    -- The manual path has now been validated in game. Runtime processing remains opt-in.
    AP.Database:Set("transmog.autoCollect.automationAuthorized", true)
    AP.Database:Set("transmog.autoCollect.enabled", false)
  end

  if version < 2 then
    -- Review alerts are read-only until the user chooses an explicit action.
    AP.Database:Set("transmog.autoCollect.showReviewAlerts", true)
  end

  AP.Database:Set("transmog.autoCollect.rulesVersion", self.RULES_VERSION)
  return true
end

function Collector:GetQualityModeByKey(qualityKey)
  local mode = string.lower(tostring(AP.Database:Get(
    "transmog.autoCollect.qualityModes." .. tostring(qualityKey or ""),
    "never"
  ) or "never"))
  if not VALID_QUALITY_MODES[mode] then
    return "never"
  end
  return mode
end

function Collector:GetQualityMode(quality)
  local qualityKey = self:GetQualityKey(quality)
  if not qualityKey then
    return "never"
  end
  return self:GetQualityModeByKey(qualityKey)
end

function Collector:GetQualityKey(quality)
  return self.qualityKeys[tonumber(quality)]
end

function Collector:SetQualityMode(qualityKey, mode, preservePending)
  mode = string.lower(tostring(mode or ""))
  if not VALID_QUALITY_MODES[mode] then
    return false
  end

  local knownQuality = false
  for index = 1, #self.qualityOptions do
    if self.qualityOptions[index].id == qualityKey then
      knownQuality = true
      break
    end
  end
  if not knownQuality then
    return false
  end

  AP.Database:Set("transmog.autoCollect.qualityModes." .. qualityKey, mode)
  AP.Database:Set("transmog.autoCollect.qualities." .. qualityKey, mode ~= "never")
  if not preservePending and self.OnFilterSettingsChanged then
    self:OnFilterSettingsChanged()
  elseif self.NotifyAppearanceInbox then
    self:NotifyAppearanceInbox("quality rule change", 0)
  end
  return true
end

function Collector:GetQualityModeCounts()
  local autoCount, askCount, neverCount = 0, 0, 0
  for index = 1, #self.qualityOptions do
    local mode = self:GetQualityModeByKey(self.qualityOptions[index].id)
    if mode == "auto" then
      autoCount = autoCount + 1
    elseif mode == "ask" then
      askCount = askCount + 1
    else
      neverCount = neverCount + 1
    end
  end
  return autoCount, askCount, neverCount
end

function Collector:SetEnabled(enabled, silent, source)
  if enabled and not self:IsAutomationAuthorized() then
    enabled = false
    if not silent then
      AP:Print("Automatic appearance processing is unavailable because its rules migration did not complete.")
    end
  end
  AP.Database:Set("transmog.autoCollect.enabled", enabled and true or false)

  if not enabled then
    self:ClearCollectionQueue()
    local rules = AP.TransmogAppearanceRules
    if not self:IsReviewAlertsEnabled() then
      self.lootWindowOpen = false
      self:ClearPendingScan()
      if rules and rules.OnInspectionDisabled then
        rules:OnInspectionDisabled()
      end
    elseif rules and rules.OnRuntimeStateChanged then
      rules:OnRuntimeStateChanged()
    end
  else
    local rules = AP.TransmogAppearanceRules
    if rules and rules.OnRuntimeStateChanged then
      rules:OnRuntimeStateChanged()
    end
  end

  if not silent and self:ShouldPrint() then
    local stateText = enabled and "enabled" or "disabled"
    AP:Print(string.format("Transmog auto-collect %s%s.", stateText, source and (" via " .. source) or ""))
  end

  if self.NotifyAppearanceInbox then
    self:NotifyAppearanceInbox("runtime state change", 0)
  end
end

function Collector:SetReviewAlertsEnabled(enabled)
  AP.Database:Set("transmog.autoCollect.showReviewAlerts", enabled and true or false)

  local rules = AP.TransmogAppearanceRules
  if not enabled and not self:IsRuntimeEnabled() then
    self.lootWindowOpen = false
    self:ClearPendingScan()
    if rules and rules.OnInspectionDisabled then
      rules:OnInspectionDisabled()
    end
  elseif rules and rules.OnRuntimeStateChanged then
    rules:OnRuntimeStateChanged()
  end

  if self.NotifyAppearanceInbox then
    self:NotifyAppearanceInbox("review alert state change", 0)
  end
end

function Collector:ToggleEnabled(source)
  self:SetEnabled(not AP.Database:Get("transmog.autoCollect.enabled", false), false, source)
end

function Collector:EnsureBindingButton()
  if self.bindingButton then
    return
  end

  local button = CreateFrame("Button", "LevoTransmogBindingButton", UIParent)
  button:SetWidth(1)
  button:SetHeight(1)
  button:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -200, -200)
  button:SetScript("OnClick", function()
    Collector:ToggleEnabled("hotkey")
  end)
  self.bindingButton = button
end

function Collector:RefreshBinding()
  self:EnsureBindingButton()

  if not self.bindingButton or not ClearOverrideBindings then
    return
  end

  if InCombatLockdown and InCombatLockdown() then
    self.pendingBindingRefresh = true
    return
  end

  ClearOverrideBindings(self.bindingButton)
  self.pendingBindingRefresh = false

  if not self.moduleEnabled or not self:IsAutomationAuthorized() then
    return
  end

  local key = self:GetToggleKey()
  if not key or key == "" then
    return
  end

  if SetOverrideBindingClick then
    SetOverrideBindingClick(self.bindingButton, false, key, self.bindingButton:GetName())
  end
end

function Collector:GetBlacklistStore()
  local blacklist = AP.Database:Get("transmog.autoCollect.blacklist", {})
  if type(blacklist) ~= "table" then
    blacklist = {}
    AP.Database:Set("transmog.autoCollect.blacklist", blacklist)
  end
  return blacklist
end

function Collector:GetBlacklistEntries()
  local blacklist = self:GetBlacklistStore()
  local entries = {}

  for itemID, entry in pairs(blacklist) do
    local numericId = tonumber(itemID) or itemID
    local name = type(entry) == "table" and entry.name or nil
    local link = type(entry) == "table" and entry.link or nil

    if not link and type(numericId) == "number" and GetItemInfo then
      link = select(2, GetItemInfo(numericId))
    end
    if not name and type(numericId) == "number" and GetItemInfo then
      name = GetItemInfo(numericId)
    end

    entries[#entries + 1] = {
      id = numericId,
      name = name or ("Item #" .. tostring(numericId)),
      link = link,
    }
  end

  table.sort(entries, function(left, right)
    return tostring(left.name) < tostring(right.name)
  end)

  return entries
end

function Collector:IsBlacklisted(itemID)
  local blacklist = self:GetBlacklistStore()
  return blacklist[itemID] ~= nil or blacklist[tostring(itemID)] ~= nil
end

function Collector:AddBlacklistItem(itemID, itemLink)
  itemID = tonumber(itemID) or (GetItemInfoFromHyperlink and GetItemInfoFromHyperlink(itemLink or ""))
  if not itemID then
    return
  end

  local name = nil
  local link = itemLink
  if GetItemInfo then
    name, link = GetItemInfo(itemID)
  end

  local blacklist = self:GetBlacklistStore()
  blacklist[itemID] = {
    name = name or ("Item #" .. tostring(itemID)),
    link = link or itemLink,
  }
  AP.Database:Set("transmog.autoCollect.blacklist", blacklist)
  local rules = AP.TransmogAppearanceRules
  if rules and rules.OnBlacklistChanged then
    rules:OnBlacklistChanged(itemID)
  end
  if self.NotifyAppearanceInbox then
    self:NotifyAppearanceInbox("blacklist change", 0)
  end
end

function Collector:RemoveBlacklistItem(itemID)
  local blacklist = self:GetBlacklistStore()
  blacklist[itemID] = nil
  blacklist[tostring(itemID)] = nil
  AP.Database:Set("transmog.autoCollect.blacklist", blacklist)
  if self.NotifyAppearanceInbox then
    self:NotifyAppearanceInbox("blacklist change", 0)
  end
end

function Collector:ClearBlacklist()
  AP.Database:Set("transmog.autoCollect.blacklist", {})
  if self.NotifyAppearanceInbox then
    self:NotifyAppearanceInbox("blacklist change", 0)
  end
end

function Collector:GetSelectedBags()
  local bags = {}
  local firstBag = BACKPACK_CONTAINER or 0
  local lastBag = NUM_BAG_SLOTS or 4
  for bag = firstBag, lastBag do
    bags[#bags + 1] = bag
  end
  return bags
end

function Collector:IsQualityAllowed(quality)
  return self:GetQualityMode(quality) ~= "never"
end

function Collector:IsTypeAllowed(itemClass, equipSlot)
  if not equipSlot or equipSlot == "" then
    return false
  end

  if itemClass == (ARMOR or "Armor") then
    return AP.Database:Get("transmog.autoCollect.includeArmor", true)
  end
  if itemClass == (WEAPON or "Weapon") then
    return AP.Database:Get("transmog.autoCollect.includeWeapons", true)
  end

  return AP.Database:Get("transmog.autoCollect.includeOtherEquippable", true)
end

function Collector:GetAppearanceID(itemID)
  local ok, appearanceID = safeCall(C_Appearance and C_Appearance.GetItemAppearanceID, itemID)
  if not ok or type(appearanceID) ~= "number" or appearanceID <= 0 then
    return nil
  end
  return appearanceID
end

function Collector:IsAppearanceCollected(appearanceID)
  local ok, isCollected = safeCall(
    C_AppearanceCollection and C_AppearanceCollection.IsAppearanceCollected,
    appearanceID
  )
  return ok, ok and isCollected and true or false
end

function Collector:ShouldCollectItem(itemID, quality, itemClass, equipSlot, appearanceID, seenAppearanceIDs)
  if not appearanceID or seenAppearanceIDs[appearanceID] or self.queuedAppearanceIDs[appearanceID] then
    return false
  end
  if not self:IsQualityAllowed(quality) then
    return false
  end
  if not self:IsTypeAllowed(itemClass, equipSlot) then
    return false
  end
  if self:IsBlacklisted(itemID) then
    return false
  end
  local rules = AP.TransmogAppearanceRules
  if rules and rules.IsPendingOrDeferred and rules:IsPendingOrDeferred(appearanceID) then
    return false
  end

  local ok, isCollected = self:IsAppearanceCollected(appearanceID)
  return ok and not isCollected
end

function Collector:ScanBags(bagLookup, source)
  if not self:IsLootInspectionEnabled() then
    return 0
  end
  if not self:HasAppearanceApi() then
    if self:ShouldPrint() and not self.apiWarningPrinted then
      self.apiWarningPrinted = true
      AP:Print("Transmog appearance API is not available on this client build.")
    end
    return 0
  end

  local rules = AP.TransmogAppearanceRules
  if not rules or type(rules.Route) ~= "function" then
    if self:ShouldPrint() and not self.rulesWarningPrinted then
      self.rulesWarningPrinted = true
      AP:Print("Transmog rules service is unavailable; no items were processed.")
    end
    return 0
  end

  local queued = 0
  local seenAppearanceIDs = {}
  local firstBag = BACKPACK_CONTAINER or 0
  local lastBag = NUM_BAG_SLOTS or 4

  for bag = firstBag, lastBag do
    if not bagLookup or bagLookup[bag] then
      local slotCount = GetContainerNumSlots(bag) or 0
      for slot = 1, slotCount do
        local itemID = GetContainerItemID(bag, slot)
        local guid = GetContainerItemGUID(bag, slot)
        local _, _, _, containerQuality, _, _, link = GetContainerItemInfo(bag, slot)

        if itemID and guid and guid ~= "" and link then
          local name, _, itemQuality, _, _, itemClass, _, _, equipSlot = GetItemInfo(link)
          itemQuality = itemQuality or containerQuality

          if name and itemQuality ~= nil then
            local appearanceID = self:GetAppearanceID(itemID)
            if self:ShouldCollectItem(
                itemID,
                itemQuality,
                itemClass,
                equipSlot,
                appearanceID,
                seenAppearanceIDs
              ) then
              seenAppearanceIDs[appearanceID] = true
              if rules:Route({
                  bag = bag,
                  slot = slot,
                  itemID = itemID,
                  guid = guid,
                  link = link,
                  name = name,
                  quality = itemQuality,
                  itemClass = itemClass,
                  equipSlot = equipSlot,
                  appearanceID = appearanceID,
                }, source) then
                queued = queued + 1
              end
            end
          end
        end
      end
    end
  end

  if self.NotifyAppearanceInbox then
    self:NotifyAppearanceInbox(source or "bag scan", 0.15)
  end

  return queued
end

function Collector:ClearPendingScan()
  self.pendingLootWindow = false
  self.pendingBags = nil
  self.pendingScanAt = nil
end

function Collector:RunPendingScan(source)
  if not self:IsLootInspectionEnabled() then
    self:ClearPendingScan()
    return
  end

  if AP.Database:Get("transmog.autoCollect.deferUntilOutOfCombat", true)
      and InCombatLockdown and InCombatLockdown() then
    self.pendingScanAt = GetTime() + 1.0
    return
  end

  local bagLookup = hasEntries(self.pendingBags) and self.pendingBags or nil
  self:ClearPendingScan()
  self:ScanBags(bagLookup, source or "loot")
end

function Collector:ScheduleLootScan(bag)
  if not self:IsLootInspectionEnabled() then
    return
  end

  if not self.pendingLootWindow then
    self.pendingBags = {}
  end
  self.pendingLootWindow = true

  if type(bag) == "number" and bag >= (BACKPACK_CONTAINER or 0) and bag <= (NUM_BAG_SLOTS or 4) then
    self.pendingBags[bag] = true
  end
  self.pendingScanAt = GetTime() + 0.35
end

function Collector:HandleAppearanceCollected()
  self.appearanceEventSeen = true
  if self.NotifyAppearanceInbox then
    self:NotifyAppearanceInbox("appearance collected", 0.15)
  end
  local rules = AP.TransmogAppearanceRules
  if rules and rules.OnAppearanceCollected then
    rules:OnAppearanceCollected()
  end

  local request = self.activeRequest
  if not request then
    return
  end

  local ok, isCollected = self:IsAppearanceCollected(request.appearanceID)
  if ok and isCollected then
    self:CompleteActiveRequest(true)
  else
    request.verifyAt = GetTime() + 0.05
  end
end

function Collector:EnsureEventFrame()
  if self.eventFrame then
    return
  end

  local frame = CreateFrame("Frame")
  frame:SetScript("OnEvent", function(_, event, ...)
    if event == "LOOT_OPENED" then
      if self.NotifyAppearanceInbox then
        self:NotifyAppearanceInbox("loot opened", 0.45)
      end
      if self:IsLootInspectionEnabled() then
        self.lootWindowOpen = true
        self.pendingLootWindow = true
        self.pendingBags = {}
        self.pendingScanAt = nil
      else
        self.lootWindowOpen = false
        self:ClearPendingScan()
      end
    elseif event == "ITEM_PUSH" then
      if self.NotifyAppearanceInbox then
        self:NotifyAppearanceInbox("new item", 0.35)
      end
      self:ScheduleLootScan(...)
    elseif event == "LOOT_CLOSED" then
      if self.NotifyAppearanceInbox then
        self:NotifyAppearanceInbox("loot closed", 0.20)
      end
      self.lootWindowOpen = false
      self:ScheduleLootScan()
    elseif event == "BAG_UPDATE" then
      if self.pendingLootWindow or self.lootWindowOpen then
        local bag = ...
        if type(self.pendingBags) ~= "table" then
          self.pendingBags = {}
        end
        if type(bag) == "number" then
          self.pendingBags[bag] = true
        end
        self.pendingScanAt = GetTime() + 0.20
      end
    elseif event == "APPEARANCE_COLLECTED" then
      self:HandleAppearanceCollected()
    elseif event == "PLAYER_REGEN_ENABLED" then
      if self.pendingBindingRefresh then
        self:RefreshBinding()
      end
      if self.pendingScanAt then
        self:RunPendingScan("post-combat loot")
      end
      if not self.moduleEnabled then
        frame:UnregisterEvent("PLAYER_REGEN_ENABLED")
      end
    end
  end)

  frame:SetScript("OnUpdate", function()
    local now = GetTime()
    if self.pendingScanAt and now >= self.pendingScanAt then
      self:RunPendingScan("loot")
    end
    self:ProcessCollectionQueue(now)
  end)

  self.eventFrame = frame
end

function Collector:Enable()
  self:MigrateAutomationRules()
  self.moduleEnabled = true
  self:EnsureBindingButton()
  self:EnsureEventFrame()
  self:EnsurePopupHook()

  self.eventFrame:RegisterEvent("LOOT_OPENED")
  self.eventFrame:RegisterEvent("LOOT_CLOSED")
  self.eventFrame:RegisterEvent("ITEM_PUSH")
  self.eventFrame:RegisterEvent("BAG_UPDATE")
  self.eventFrame:RegisterEvent("APPEARANCE_COLLECTED")
  self.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

  self:RefreshBinding()
  if self.NotifyAppearanceInbox then
    self:NotifyAppearanceInbox("module enabled", 0)
  end
end

function Collector:Disable()
  self.moduleEnabled = false
  self.lootWindowOpen = false
  self:ClearPendingScan()
  self:ClearCollectionQueue()
  local rules = AP.TransmogAppearanceRules
  if rules and rules.OnInspectionDisabled then
    rules:OnInspectionDisabled()
  end

  if self.eventFrame then
    self.eventFrame:UnregisterAllEvents()
  end

  if self.bindingButton and ClearOverrideBindings then
    if InCombatLockdown and InCombatLockdown() then
      self.pendingBindingRefresh = true
      if self.eventFrame then
        self.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
      end
    else
      ClearOverrideBindings(self.bindingButton)
      self.pendingBindingRefresh = false
    end
  end

  if self.NotifyAppearanceInbox then
    self:NotifyAppearanceInbox("module disabled", 0)
  end
end
