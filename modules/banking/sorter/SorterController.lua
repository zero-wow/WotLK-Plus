local _, AP = ...
AP = AP or _G.Levo or _G.WotLKPlus or _G.AscensionPlus

local Banking = AP.Banking
local Planner = Banking.SorterPlanner
local Pacing = Banking.SorterPacing
local Providers = Banking.SorterProviders or {}
if not Providers.keeper and Banking.KeeperSorterProvider then
  Providers.keeper = Banking.KeeperSorterProvider
end

local Sorter = {
  enabled = false,
  running = false,
  lastStatus = "Idle. Sort Inventory, Character Bank, or a supported server-specific bank tab.",
  lastError = nil,
  responseTimeout = 1.25,
  refreshInterval = 0.75,
  maxCursorAttempts = 3,
  maxMoveRetries = 1,
}

Banking.Sorter = Sorter

local function now()
  return type(GetTime) == "function" and GetTime() or 0
end

local function inCombat()
  return type(InCombatLockdown) == "function" and InCombatLockdown() and true or false
end

local function trim(text)
  return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

function Sorter:CreateEventFrame()
  if self.eventFrame then
    return
  end

  local frame = CreateFrame("Frame")
  frame:Hide()
  frame:SetScript("OnEvent", function(_, event, ...)
    self:OnEvent(event, ...)
  end)
  frame:SetScript("OnUpdate", function(_, elapsed)
    self:OnUpdate(elapsed)
  end)
  self.eventFrame = frame
end

function Sorter:Wake()
  if self.eventFrame then
    self.eventFrame:Show()
  end
end

function Sorter:SleepIfIdle()
  local settling = self.uiSettleUntil and now() < self.uiSettleUntil
  if self.eventFrame and not self.running and self.uiRefreshTimer == nil and not settling then
    self.eventFrame:Hide()
  end
end

function Sorter:GetProvider(contextID)
  if self.running and self.provider and (not contextID or contextID == self.provider.id) then
    return self.provider
  end
  if contextID and Providers[contextID] then
    return Providers[contextID]
  end

  local keeper = Providers.keeper
  if keeper and keeper.IsOpen and keeper:IsOpen() then
    return keeper
  end
  local character = Providers.character
  if character and character.IsOpen and character:IsOpen() then
    return character
  end
  return Providers.inventory or keeper or character
end

function Sorter:BeginUISettle(duration)
  local untilTime = now() + (tonumber(duration) or 1.5)
  if not self.uiSettleUntil or untilTime > self.uiSettleUntil then
    self.uiSettleUntil = untilTime
  end
  self.nextUISettleAt = 0
  self:Wake()
end

function Sorter:Print(message)
  if AP.Database:Get("banking.sorter.showChatMessages", true) then
    AP:Print(message)
  end
end

function Sorter:ScheduleUIRefresh(delay, forceConfig)
  delay = tonumber(delay) or 0.05
  if self.uiRefreshTimer == nil or delay < self.uiRefreshTimer then
    self.uiRefreshTimer = delay
  end
  self.forceConfigRefresh = self.forceConfigRefresh or forceConfig
  self:Wake()
end

function Sorter:RefreshUI()
  if Banking.SorterPresentation and Banking.SorterPresentation.Refresh then
    Banking.SorterPresentation:Refresh()
  end

  local config = AP.ConfigWindow
  local frame = config and config.frame
  local currentTime = now()
  local mayRefreshConfig = self.forceConfigRefresh
    or not self.lastConfigRefresh
    or currentTime - self.lastConfigRefresh >= 0.35
  if mayRefreshConfig
    and frame
    and frame:IsShown()
    and config.selectedPageId == "banking.sorter" then
    config:RefreshContent()
    self.lastConfigRefresh = currentTime
  end
  self.forceConfigRefresh = nil
end

function Sorter:SetStatus(message, isError, forceConfig)
  self.lastStatus = tostring(message or "")
  if isError then
    self.lastError = self.lastStatus
  end
  self:ScheduleUIRefresh(0.03, forceConfig)
end

function Sorter:ClearError()
  self.lastError = nil
end

function Sorter:Enable()
  if self.enabled then
    self:ScheduleUIRefresh(0)
    return
  end

  self:CreateEventFrame()
  local frame = self.eventFrame
  frame:RegisterEvent("ADDON_LOADED")
  frame:RegisterEvent("GUILDBANKFRAME_OPENED")
  frame:RegisterEvent("GUILDBANKFRAME_CLOSED")
  frame:RegisterEvent("GUILDBANKBAGSLOTS_CHANGED")
  frame:RegisterEvent("GUILDBANK_ITEM_LOCK_CHANGED")
  frame:RegisterEvent("GUILDBANK_UPDATE_TABS")
  frame:RegisterEvent("BANKFRAME_OPENED")
  frame:RegisterEvent("BANKFRAME_CLOSED")
  frame:RegisterEvent("BAG_UPDATE")
  frame:RegisterEvent("ITEM_LOCK_CHANGED")
  frame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
  frame:RegisterEvent("PLAYERBANKBAGSLOTS_CHANGED")
  frame:RegisterEvent("PLAYER_REGEN_DISABLED")
  self.enabled = true
  self:BeginUISettle(1.5)
  self:ScheduleUIRefresh(0, true)
end

function Sorter:Disable()
  if not self.enabled then
    return
  end

  if self.running then
    self:Abort("Sorting stopped because the banking module was disabled.", true)
  end
  self.enabled = false
  if self.eventFrame then
    self.eventFrame:UnregisterAllEvents()
  end
  self:ScheduleUIRefresh(0, true)
end

function Sorter:OnSettingsChanged(cancelRunning)
  if self.running and (cancelRunning or not AP.Database:Get("banking.sorter.enabled", true)) then
    if cancelRunning and self.provider then
      -- A submitted move must settle before the new exclusion map is applied.
      self.token = self.provider:GetToken()
    end
    self:Cancel(cancelRunning
      and "Sorting cancelled because exclusions changed."
      or "Sorting cancelled because the sorter was disabled.")
  end
  self:ScheduleUIRefresh(0, true)
end

function Sorter:IsRunning()
  return self.running and true or false
end

function Sorter:GetProgress()
  return self.completed or 0, self.plan and #self.plan.operations or 0
end

function Sorter:GetStatusText()
  if self.running then
    local completed, total = self:GetProgress()
    local rate = Pacing:GetRate(self.pacing)
    local detail = self.phase == "confirming" and "confirming server state" or "ready for next move"
    if self.cancelRequested then
      detail = "cancelling after confirmation"
    elseif self.phase == "finalizing" then
      detail = "verifying final layout"
    end
    return string.format(
      "%s: %d/%d operations, %s (adaptive cap %.1f operations/sec).",
      self.scopeLabel or "Sorter",
      completed,
      total,
      detail,
      rate
    )
  end
  return self.lastStatus
end

function Sorter:GetLastErrorText()
  return self.lastError or "No sorter safety stop has been recorded this session."
end

function Sorter:GetAvailability(contextID)
  local provider = self:GetProvider(contextID)
  if not self.enabled then
    return false, "The banking module is disabled."
  elseif not AP.Database:Get("banking.sorter.enabled", true) then
    return false, "Sorting is disabled in Levo configuration."
  elseif inCombat() then
    return false, "Sorting is unavailable during combat."
  elseif Banking.Controller and Banking.Controller.processing then
    return false, "Wait for the active Levo bank transfer to finish."
  elseif not provider then
    return false, "No supported sorting context is available."
  elseif provider:HasCursorItem() then
    return false, "Clear the cursor before sorting."
  end
  local available, reason = provider:CanUse()
  return available, reason, provider
end

function Sorter:IsContextValid()
  local provider = self.provider
  if not provider then
    return false, "The active sorter provider is unavailable."
  end
  local canUse, reason = provider:CanUse()
  if not canUse then
    return false, reason
  elseif provider:GetToken() ~= self.token then
    return false, "The selected bags, bank view, tab, or exclusions changed."
  elseif inCombat() then
    return false, "Combat started."
  end
  return true
end

function Sorter:ResetRunState()
  self.running = false
  self.plan = nil
  self.pending = nil
  self.phase = nil
  self.currentIndex = nil
  self.completed = nil
  self.token = nil
  self.context = nil
  self.provider = nil
  self.tab = nil
  self.bankName = nil
  self.scopeLabel = nil
  self.nextActionAt = nil
  self.startedAt = nil
  self.cancelRequested = nil
  self.blockedSince = nil
  self.blockedBackedOff = nil
  self.finalizeStartedAt = nil
end

function Sorter:Abort(reason, quiet)
  local wasRunning = self.running
  local cursorWarning
  local provider = self.provider
  if wasRunning and provider and self.pending and provider:HasCursorItem() then
    pcall(provider.CompleteCursor, provider, self.context, self.pending.operation)
    if provider:HasCursorItem() then
      cursorWarning = " An item remains on the cursor; place it back before continuing."
    end
  end

  self:ResetRunState()
  local message = tostring(reason or "Sorting stopped.") .. (cursorWarning or "")
  self:SetStatus(message, true, true)
  if wasRunning and not quiet then
    self:Print(message)
  end
  self:SleepIfIdle()
end

function Sorter:Cancel(reason)
  if not self.running then
    self:SetStatus(reason or "No sort is running.", false, true)
    return false
  end

  if self.pending then
    self.cancelRequested = reason or "Sorting cancelled."
    self:SetStatus("Cancelling after the current server move is confirmed.", false, true)
  else
    self:Abort(reason or "Sorting cancelled.")
  end
  return true
end

function Sorter:BindPlanLocations(plan, snapshot)
  if not plan or not snapshot or type(snapshot.locations) ~= "table" then
    return
  end
  for index = 1, #plan.operations do
    local operation = plan.operations[index]
    operation.sourceLocation = snapshot.locations[operation.sourceSlot]
    operation.targetLocation = snapshot.locations[operation.targetSlot]
  end
end

function Sorter:Start(contextID)
  if self.running then
    self:Print(self:GetStatusText())
    return false, "already-running"
  end

  local available, reason, provider = self:GetAvailability(contextID)
  if not available then
    self:SetStatus(reason, true, true)
    self:Print(reason)
    return false, reason
  end

  local snapshot, snapshotError = provider:TakeSnapshot()
  if not snapshot then
    self:SetStatus(snapshotError, true, true)
    self:Print(snapshotError)
    return false, snapshotError
  elseif snapshot.lockedSlots > 0 then
    reason = string.format("Wait for the sorting context to unlock (%d locked slot%s).", snapshot.lockedSlots, snapshot.lockedSlots == 1 and "" or "s")
    self:SetStatus(reason, true, true)
    self:Print(reason)
    return false, reason
  end

  local plan, planError = Planner:Build(snapshot)
  if not plan then
    reason = "Could not build a safe sort plan: " .. tostring(planError)
    self:SetStatus(reason, true, true)
    self:Print(reason)
    return false, reason
  elseif #plan.operations == 0 then
    local label = provider.GetScopeLabel and provider:GetScopeLabel(snapshot) or provider:GetBankName()
    reason = string.format("%s is already consolidated and sorted.", label)
    self:ClearError()
    self:SetStatus(reason, false, true)
    self:Print(reason)
    return true, "already-sorted"
  end

  self:ClearError()
  self:BindPlanLocations(plan, snapshot)
  self.plan = plan
  self.provider = provider
  self.context = snapshot.context or snapshot.tab or (provider.GetContext and provider:GetContext())
  self.tab = snapshot.tab
  self.token = snapshot.token
  self.bankName = provider:GetBankName()
  self.scopeLabel = provider.GetScopeLabel and provider:GetScopeLabel(snapshot) or self.bankName
  self.responseTimeout = provider.GetResponseTimeout and provider:GetResponseTimeout() or 1.25
  self.refreshInterval = provider.GetRefreshInterval and provider:GetRefreshInterval() or 0.75
  self.currentIndex = 1
  self.completed = 0
  self.pending = nil
  self.phase = "ready"
  self.startedAt = now()
  self.nextActionAt = self.startedAt
  self.pacing = Pacing:Create(AP.Database:Get("banking.sorter.conservativePacing", false))
  local excludedItemSlots = (snapshot.excludedItems or 0) + (snapshot.excludedQualities or 0)
  local exclusionSummary = ""
  if excludedItemSlots + (snapshot.excludedBags or 0) > 0 then
    exclusionSummary = string.format(
      "; %d protected/quality item slot%s and %d bag%s excluded",
      excludedItemSlots,
      excludedItemSlots == 1 and "" or "s",
      snapshot.excludedBags or 0,
      snapshot.excludedBags == 1 and "" or "s"
    )
  end
  self.running = true
  self:SetStatus(string.format(
    "Sorting %s: %d consolidation + %d placement operations planned%s%s.",
    self.scopeLabel,
    plan.stats.stackMoves,
    plan.stats.sortMoves,
    plan.stats.routedItems and plan.stats.routedItems > 0
      and string.format("; dedicated quality routing applies to %d stack%s", plan.stats.routedItems, plan.stats.routedItems == 1 and "" or "s")
      or "",
    exclusionSummary
  ), false, true)
  self:Print(self.lastStatus)
  self:Wake()
  return true
end

function Sorter:BackOff(reason)
  Pacing:BackOff(self.pacing)
  self:SetStatus(string.format(
    "%s Backing off to %.1f operations/sec.",
    reason,
    Pacing:GetRate(self.pacing)
  ))
end

function Sorter:HandleBlocked(nowValue, reason)
  self.blockedSince = self.blockedSince or nowValue
  if not self.blockedBackedOff then
    self.blockedBackedOff = true
    self:BackOff(reason)
  end

  if nowValue - self.blockedSince >= self.responseTimeout then
    self:Abort(reason .. " Sorting stopped without submitting another move.")
  else
    self.nextActionAt = nowValue + math.max(Pacing:GetDelay(self.pacing), 0.10)
  end
end

function Sorter:ProcessReady(nowValue)
  local provider = self.provider
  if self.cancelRequested then
    self:Abort(self.cancelRequested)
    return
  elseif self.currentIndex > #self.plan.operations then
    self.phase = "finalizing"
    self.finalizeStartedAt = self.finalizeStartedAt or nowValue
    return
  elseif nowValue < (self.nextActionAt or 0) then
    return
  end

  local valid, reason = self:IsContextValid()
  if not valid then
    self:Abort("Sorting stopped: " .. reason)
    return
  elseif provider:HasCursorItem() then
    self:Abort("Sorting stopped because the cursor became occupied.")
    return
  end

  local operation = self.plan.operations[self.currentIndex]
  local matches, locked = provider:OperationMatches(self.context, operation, "before")
  if locked then
    self:HandleBlocked(nowValue, "The source or target slot is locked.")
    return
  elseif not matches then
    self:Abort("Contents changed before the next move; the stale plan was discarded.")
    return
  end

  self.blockedSince = nil
  self.blockedBackedOff = nil
  local executed, executeError = provider:Execute(self.context, operation)
  if not executed then
    if executeError == "locked" then
      self:HandleBlocked(nowValue, "The source or target slot locked before submission.")
    elseif executeError == "stale" then
      self:Abort("Contents changed before submission; the stale plan was discarded.")
    else
      self:Abort("The sort move was rejected: " .. tostring(executeError))
    end
    return
  end

  self.pending = {
    operation = operation,
    mutationStartedAt = nowValue,
    confirmationStartedAt = nowValue,
    retryCount = 0,
    queryCount = 0,
    cursorAttempts = 0,
    lastCursorAttempt = 0,
    backedOff = false,
    lockExtension = false,
    nextCheckAt = nowValue + 0.04,
  }
  self.phase = "confirming"
  self:SetStatus(string.format(
    "Sorting %s: confirming operation %d/%d.",
    self.scopeLabel,
    self.currentIndex,
    #self.plan.operations
  ))
end

function Sorter:ConfirmPending(nowValue)
  local pending = self.pending
  local latency = nowValue - pending.mutationStartedAt
  Pacing:Confirm(self.pacing, latency, pending.retryCount > 0)

  self.completed = self.completed + 1
  self.currentIndex = self.currentIndex + 1
  self.pending = nil
  self.phase = "ready"
  self.nextActionAt = math.max(nowValue, pending.mutationStartedAt + Pacing:GetDelay(self.pacing))

  if self.cancelRequested then
    self:Abort(self.cancelRequested)
    return
  elseif self.currentIndex > #self.plan.operations then
    self.phase = "finalizing"
    self.finalizeStartedAt = nowValue
  end
  self:ScheduleUIRefresh(0.05)
end

function Sorter:RetryPending(nowValue, pending)
  local provider = self.provider
  self:BackOff("The server did not confirm the move in time.")
  local executed, executeError = provider:Execute(self.context, pending.operation)
  if not executed then
    self:Abort("The sort retry was rejected: " .. tostring(executeError))
    return
  end

  pending.retryCount = pending.retryCount + 1
  pending.mutationStartedAt = nowValue
  pending.confirmationStartedAt = nowValue
  pending.backedOff = false
  pending.cursorAttempts = 0
  pending.lastCursorAttempt = 0
  pending.nextCheckAt = nowValue + 0.04
  self:SetStatus(string.format(
    "Retrying operation %d/%d once at %.1f operations/sec.",
    self.currentIndex,
    #self.plan.operations,
    Pacing:GetRate(self.pacing)
  ))
end

function Sorter:ProcessPending(nowValue)
  local pending = self.pending
  local provider = self.provider
  if not pending then
    return
  end

  local valid, reason = self:IsContextValid()
  if not valid then
    self:Abort("Sorting stopped: " .. reason)
    return
  end


  if not self.serverEventPending and nowValue < (pending.nextCheckAt or 0) then
    return
  end
  self.serverEventPending = nil
  pending.nextCheckAt = nowValue + 0.04

  if provider:HasCursorItem() then
    local cursorWait = math.max(Pacing:GetDelay(self.pacing), 0.12)
    if nowValue - pending.lastCursorAttempt >= cursorWait then
      local completed, completionError = provider:CompleteCursor(self.context, pending.operation)
      pending.cursorAttempts = pending.cursorAttempts + 1
      pending.lastCursorAttempt = nowValue
      if not completed then
        self:Abort("Cursor recovery stopped: " .. tostring(completionError))
        return
      elseif completionError == "locked" and not pending.backedOff then
        pending.backedOff = true
        self:BackOff("The cursor destination is locked.")
      end
    end

    if pending.cursorAttempts >= self.maxCursorAttempts
      and nowValue - pending.confirmationStartedAt >= self.responseTimeout then
      self:Abort("Cursor recovery timed out.")
    end
    return
  end

  local afterMatches, locked = provider:OperationMatches(self.context, pending.operation, "after")
  if afterMatches and not locked then
    self:ConfirmPending(nowValue)
    return
  end

  local elapsed = nowValue - pending.confirmationStartedAt
  if (locked or Pacing:IsDelayed(self.pacing, elapsed)) and not pending.backedOff then
    pending.backedOff = true
    self:BackOff(locked and "The server is still locking the moved slots." or "The server response is delayed.")
  end
  if elapsed < self.responseTimeout then
    return
  end

  local afterIgnoringLocks = provider:OperationMatches(self.context, pending.operation, "after", true)
  if afterIgnoringLocks and locked and not pending.lockExtension then
    pending.lockExtension = true
    pending.confirmationStartedAt = nowValue
    return
  elseif afterIgnoringLocks then
    self:ConfirmPending(nowValue)
    return
  end

  local beforeMatches = provider:OperationMatches(self.context, pending.operation, "before", true)
  if pending.queryCount <= pending.retryCount then
    if not self.lastQueryAt or nowValue - self.lastQueryAt >= self.refreshInterval then
      provider:Query(self.context)
      self.lastQueryAt = nowValue
      pending.queryCount = pending.queryCount + 1
      pending.confirmationStartedAt = nowValue
      self:BackOff("Refreshing the active sorting context after a delayed confirmation.")
      return
    end
    return
  elseif beforeMatches and pending.retryCount < self.maxMoveRetries then
    self:RetryPending(nowValue, pending)
    return
  end

  if beforeMatches then
    self:Abort("The server did not confirm the move after refresh and retry; sorting stopped safely.")
  else
    self:Abort("Contents no longer match either side of the active move; sorting stopped safely.")
  end
end

function Sorter:VerifyFinal(nowValue)
  local provider = self.provider
  local valid, reason = self:IsContextValid()
  if not valid then
    self:Abort("Final verification failed: " .. reason)
    return
  end

  local snapshot, snapshotError = provider:TakeSnapshot()
  if not snapshot then
    self:Abort("Final verification failed: " .. tostring(snapshotError))
    return
  elseif snapshot.lockedSlots > 0 then
    if nowValue - (self.finalizeStartedAt or nowValue) >= self.responseTimeout then
      self:Abort("Final verification timed out while slots remained locked.")
    end
    return
  end

  for slotID = 1, self.plan.slotCount do
    if not Planner:ItemsMatch(snapshot.slots[slotID], self.plan.target[slotID]) then
      self:Abort(string.format("Final verification found an unexpected item in logical slot %d.", slotID))
      return
    end
  end

  local elapsed = math.max(nowValue - self.startedAt, 0.001)
  local completed = self.completed or 0
  local message = string.format(
    "Sorted %s: %d operation%s confirmed in %.1f seconds (%.1f/sec).",
    self.scopeLabel,
    completed,
    completed == 1 and "" or "s",
    elapsed,
    completed / elapsed
  )
  self:ResetRunState()
  self:ClearError()
  self:SetStatus(message, false, true)
  self:Print(message)
end

function Sorter:OnUpdate(elapsed)
  if self.uiRefreshTimer ~= nil then
    self.uiRefreshTimer = self.uiRefreshTimer - elapsed
    if self.uiRefreshTimer <= 0 then
      self.uiRefreshTimer = nil
      self:RefreshUI()
    end
  end

  local currentTime = now()
  if self.uiSettleUntil then
    if currentTime >= self.uiSettleUntil then
      self.uiSettleUntil = nil
      self.nextUISettleAt = nil
    elseif currentTime >= (self.nextUISettleAt or 0) then
      self.nextUISettleAt = currentTime + 0.20
      self:RefreshUI()
    end
  end

  if self.running then
    if self.phase == "confirming" then
      self:ProcessPending(currentTime)
    elseif self.phase == "finalizing" then
      self:VerifyFinal(currentTime)
    else
      self:ProcessReady(currentTime)
    end
  end
  self:SleepIfIdle()
end

function Sorter:OnEvent(event, addonName)
  if event == "GUILDBANKFRAME_CLOSED" then
    if self.running and self.provider and self.provider.id == "keeper" then
      self:Abort("Sorting stopped because the Keeper Bank closed.")
    end
    self:ScheduleUIRefresh(0.05, true)
  elseif event == "BANKFRAME_CLOSED" then
    if self.running and self.provider and self.provider.id == "character" then
      self:Abort("Sorting stopped because the Character Bank closed.")
    end
    self:ScheduleUIRefresh(0.05, true)
  elseif event == "PLAYER_REGEN_DISABLED" then
    if self.running then
      self:Abort("Sorting stopped when combat started.")
    end
  elseif event == "ADDON_LOADED" then
    if addonName == "Blizzard_GuildBankUI"
      or addonName == "ElvUI"
      or addonName == "Bagnon"
      or addonName == "AdiBags" then
      self:BeginUISettle(2.0)
      self:ScheduleUIRefresh(0.15, true)
    end
  else
    if self.running and (event == "GUILDBANKBAGSLOTS_CHANGED"
      or event == "GUILDBANK_ITEM_LOCK_CHANGED"
      or event == "BAG_UPDATE"
      or event == "ITEM_LOCK_CHANGED"
      or event == "PLAYERBANKSLOTS_CHANGED"
      or event == "PLAYERBANKBAGSLOTS_CHANGED") then
      self.serverEventPending = true
    end
    if event == "GUILDBANKFRAME_OPENED" or event == "BANKFRAME_OPENED" then
      self:BeginUISettle(2.0)
      self:ScheduleUIRefresh(0.15, true)
    elseif event == "GUILDBANK_UPDATE_TABS" then
      self:ScheduleUIRefresh(0.05)
    end
  end
end

function Sorter:HandleSlash(arguments)
  local command = string.lower(trim(arguments))
  if command == "" or command == "start" or command == "now" then
    return self:Start()
  elseif command == "inventory" or command == "bags" then
    return self:Start("inventory")
  elseif command == "bank" or command == "character" then
    return self:Start("character")
  elseif command == "keeper" or command == "realm" or command == "personal" then
    return self:Start("keeper")
  elseif command == "cancel" or command == "stop" then
    return self:Cancel("Sorting cancelled from /lv sort.")
  elseif command == "status" then
    self:Print(self:GetStatusText())
    return true
  elseif command == "config" or command == "options" then
    if type(AP.OpenConfig) == "function" then
      AP:OpenConfig("banking.sorter")
      return true
    end
  end

  self:Print("Usage: |cff93c2ff/lv sort|r [inventory|bank|keeper], |cff93c2ff/lv sort status|r, |cff93c2ff/lv sort cancel|r, or |cff93c2ff/lv sort config|r.")
  return false, "usage"
end
