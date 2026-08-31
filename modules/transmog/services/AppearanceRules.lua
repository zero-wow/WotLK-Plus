local _, AP = ...
AP = AP or _G.Levo or _G.WotLKPlus or _G.AscensionPlus

local Collector = AP.TransmogAutoCollect
if not Collector then
  return
end

local Rules = {
  askQueue = {},
  pendingAppearanceIDs = {},
  deferredAppearanceIDs = {},
  activeEntry = nil,
  resolvingDecision = false,
}

AP.TransmogAppearanceRules = Rules
Collector.AppearanceRules = Rules

local function copyEntry(entry)
  local copy = {}
  for key, value in pairs(entry or {}) do
    copy[key] = value
  end
  return copy
end

local function printIfEnabled(message)
  if message and Collector:ShouldPrint() then
    AP:Print(message)
  end
end

function Rules:GetPendingAskCount()
  return #self.askQueue + (self.activeEntry and 1 or 0)
end

function Rules:GetReviewEntries()
  local entries = {}
  if self.activeEntry then
    entries[#entries + 1] = self.activeEntry
  end
  for index = 1, #self.askQueue do
    entries[#entries + 1] = self.askQueue[index]
  end
  return entries
end

function Rules:RefreshPrompt()
  local prompt = AP.TransmogAppearancePrompt
  if prompt and type(prompt.Refresh) == "function" then
    prompt:Refresh()
  end
end

function Rules:IsPendingOrDeferred(appearanceID)
  if not appearanceID then
    return false
  end
  return self.pendingAppearanceIDs[appearanceID] == true
    or self.deferredAppearanceIDs[appearanceID] == true
end

function Rules:QueueAsk(entry, source, reviewReason)
  local appearanceID = entry and entry.appearanceID
  if not appearanceID or self:IsPendingOrDeferred(appearanceID)
      or Collector.queuedAppearanceIDs[appearanceID] then
    return false
  end

  local request = copyEntry(entry)
  request.source = source or "loot"
  request.ruleMode = "ask"
  request.reviewReason = reviewReason or "quality-ask"
  self.askQueue[#self.askQueue + 1] = request
  self.pendingAppearanceIDs[appearanceID] = true
  self:ShowNext()
  self:RefreshPrompt()
  return true
end

function Rules:Route(entry, source)
  if not Collector:IsLootInspectionEnabled() or not entry or not entry.appearanceID then
    return false
  end

  local mode = Collector:GetQualityMode(entry.quality)
  if mode == "never" then
    return false
  elseif mode == "ask" then
    if not Collector:IsReviewAlertsEnabled() then
      return false
    end
    return self:QueueAsk(entry, source, "quality-ask")
  elseif not Collector:IsRuntimeEnabled() then
    if not Collector:IsReviewAlertsEnabled() then
      return false
    end
    return self:QueueAsk(entry, source, "automatic-paused")
  end

  local request = copyEntry(entry)
  request.source = source or "loot"
  request.ruleMode = "auto"
  request.automaticRequest = true
  return Collector:QueueAppearance(request, request.source)
end

function Rules:Revalidate(entry)
  if not Collector:IsLootInspectionEnabled() then
    return nil, nil, "Appearance review and automatic learning are both disabled."
  end
  if not entry or not entry.itemID or not entry.appearanceID then
    return nil, nil, "The appearance request is incomplete."
  end

  local catalog = AP.TransmogAppearanceCatalog
  local location = copyEntry(entry)
  if type(Collector.FindItemByGUID) == "function" and not Collector:FindItemByGUID(location) then
    return nil, nil, "The exact item instance is no longer in your carried bags."
  end

  local current
  if catalog and type(catalog.InspectSlot) == "function" then
    current = catalog:InspectSlot(location.bag, location.slot)
    if not current or current.itemID ~= entry.itemID or current.appearanceID ~= entry.appearanceID then
      return nil, nil, "The item moved or changed before a decision was made."
    end
  else
    current = location
  end

  if Collector:IsBlacklisted(current.itemID) then
    return nil, nil, "This item is now blacklisted."
  end
  if not Collector:IsTypeAllowed(current.itemClass, current.equipSlot) then
    return nil, nil, "This item type is disabled under Transmog rules."
  end

  local ok, collected = Collector:IsAppearanceCollected(current.appearanceID)
  if not ok then
    return nil, nil, "Ascension's appearance state is temporarily unavailable."
  elseif collected then
    return nil, nil, "This appearance is already collected."
  end

  if not current.guid or current.guid == "" then
    return nil, nil, "The item instance is not ready yet."
  end

  local mode = Collector:GetQualityMode(current.quality)
  if mode == "never" then
    return nil, mode, "This quality is now set to NEVER."
  end
  current.ruleMode = mode
  return current, mode
end

function Rules:ShowNext()
  if self.resolvingDecision or self.activeEntry or not Collector:IsReviewAlertsEnabled() then
    return
  end
  if Collector:GetPendingRequestCount() > 0 then
    return
  end

  while #self.askQueue > 0 do
    local candidate = table.remove(self.askQueue, 1)
    local current, mode = self:Revalidate(candidate)
    if not current then
      self.pendingAppearanceIDs[candidate.appearanceID] = nil
    elseif mode == "auto" and Collector:IsRuntimeEnabled() then
      self.pendingAppearanceIDs[candidate.appearanceID] = nil
      current.automaticRequest = true
      if Collector:QueueAppearance(current, candidate.source or "loot") then
        return
      end
    else
      local prompt = AP.TransmogAppearancePrompt
      if not prompt or type(prompt.Open) ~= "function" then
        table.insert(self.askQueue, 1, candidate)
        return
      end

      self.activeEntry = current
      current.source = candidate.source
      current.reviewReason = candidate.reviewReason
      local opened = prompt:Open(current)
      if opened then
        return
      end

      self.activeEntry = nil
      self.pendingAppearanceIDs[candidate.appearanceID] = nil
      self.deferredAppearanceIDs[candidate.appearanceID] = true
      printIfEnabled("The appearance decision window could not be opened; the item was skipped for this session.")
    end
  end
end

function Rules:ResolveActive(action)
  local entry = self.activeEntry
  if not entry then
    return false
  end

  self.resolvingDecision = true
  self.activeEntry = nil
  self.pendingAppearanceIDs[entry.appearanceID] = nil

  if action == "defer-all" then
    for index = 1, #self.askQueue do
      local queuedEntry = self.askQueue[index]
      self.deferredAppearanceIDs[queuedEntry.appearanceID] = true
      self.pendingAppearanceIDs[queuedEntry.appearanceID] = nil
    end
    self.askQueue = {}
  end

  local prompt = AP.TransmogAppearancePrompt
  if prompt and type(prompt.CloseSilently) == "function" then
    prompt:CloseSilently()
  end

  if action == "reject" then
    Collector:AddBlacklistItem(entry.itemID, entry.link)
    printIfEnabled(string.format(
      "%s was permanently added to the Transmog blacklist.",
      entry.link or entry.name or ("Item #" .. tostring(entry.itemID))
    ))
  elseif action == "approve" or action == "auto-quality" then
    if action == "auto-quality" then
      local qualityKey = Collector:GetQualityKey(entry.quality)
      if qualityKey then
        Collector:SetQualityMode(qualityKey, "auto", true)
        Collector:SetEnabled(true, false, "appearance review")
      end
    end

    local current, _, reason = self:Revalidate(entry)
    if current then
      current.ruleApproved = true
      current.automaticRequest = true
      current.manualConfirmation = false
      local queued = Collector:QueueAppearance(current, "approved appearance")
      local deferForCombat = AP.Database and AP.Database.Get
        and AP.Database:Get("transmog.autoCollect.deferUntilOutOfCombat", true)
        and type(InCombatLockdown) == "function"
        and InCombatLockdown()
      if queued and not Collector.activeRequest and not deferForCombat then
        Collector:StartNextRequest()
      elseif not queued then
        printIfEnabled("That appearance is already pending or can no longer be processed.")
      end
    else
      printIfEnabled(reason)
    end
  else
    self.deferredAppearanceIDs[entry.appearanceID] = true
  end

  self.resolvingDecision = false
  self:ShowNext()
  self:RefreshPrompt()
  if Collector.NotifyAppearanceInbox then
    Collector:NotifyAppearanceInbox("appearance decision", 0.10)
  end
  return true
end

function Rules:ClearPendingDecisions(resetDeferred)
  self.askQueue = {}
  self.pendingAppearanceIDs = {}
  self.activeEntry = nil
  self.resolvingDecision = false
  if resetDeferred then
    self.deferredAppearanceIDs = {}
  end

  local prompt = AP.TransmogAppearancePrompt
  if prompt and type(prompt.CloseSilently) == "function" then
    prompt:CloseSilently()
  end
end

function Rules:OnInspectionDisabled()
  self:ClearPendingDecisions(false)
end

function Rules:OnRuntimeStateChanged()
  if not Collector:IsReviewAlertsEnabled() then
    self:ClearPendingDecisions(false)
    return
  end
  self:ShowNext()
  self:RefreshPrompt()
end

function Rules:OnSettingsChanged()
  self:ClearPendingDecisions(false)
end

function Rules:OnBlacklistChanged(itemID)
  itemID = tonumber(itemID) or itemID
  for index = #self.askQueue, 1, -1 do
    local entry = self.askQueue[index]
    if entry.itemID == itemID then
      self.pendingAppearanceIDs[entry.appearanceID] = nil
      table.remove(self.askQueue, index)
    end
  end

  if self.activeEntry and self.activeEntry.itemID == itemID then
    self.pendingAppearanceIDs[self.activeEntry.appearanceID] = nil
    self.activeEntry = nil
    local prompt = AP.TransmogAppearancePrompt
    if prompt and type(prompt.CloseSilently) == "function" then
      prompt:CloseSilently()
    end
  end
  self:ShowNext()
  self:RefreshPrompt()
end

function Rules:OnAppearanceCollected()
  for index = #self.askQueue, 1, -1 do
    local entry = self.askQueue[index]
    local ok, collected = Collector:IsAppearanceCollected(entry.appearanceID)
    if ok and collected then
      self.pendingAppearanceIDs[entry.appearanceID] = nil
      table.remove(self.askQueue, index)
    end
  end

  if self.activeEntry then
    local ok, collected = Collector:IsAppearanceCollected(self.activeEntry.appearanceID)
    if ok and collected then
      self.pendingAppearanceIDs[self.activeEntry.appearanceID] = nil
      self.activeEntry = nil
      local prompt = AP.TransmogAppearancePrompt
      if prompt and type(prompt.CloseSilently) == "function" then
        prompt:CloseSilently()
      end
    end
  end
  self:ShowNext()
  self:RefreshPrompt()
end

function Rules:OnCollectionQueueAdvanced()
  self:ShowNext()
end
