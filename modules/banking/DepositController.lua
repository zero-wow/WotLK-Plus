local _, AP = ...
AP = AP or _G.Levo or _G.WotLKPlus or _G.AscensionPlus

local Banking = AP.Banking
local Categories = Banking.Categories
local Pacing = Banking.SorterPacing

local TRANSFER_CONFIRM_EVENTS = {
  BAG_UPDATE = true,
  GUILDBANKBAGSLOTS_CHANGED = true,
  GUILDBANK_ITEM_LOCK_CHANGED = true,
  ITEM_LOCK_CHANGED = true,
  PLAYERBANKBAGSLOTS_CHANGED = true,
  PLAYERBANKSLOTS_CHANGED = true,
}

local OPERATIONS = {
  deposit = {
    title = "Deposit",
    gerund = "Depositing",
    past = "Deposited",
    source = "inventory",
  },
  withdraw = {
    title = "Withdraw",
    gerund = "Withdrawing",
    past = "Withdrew",
    source = "bank",
  },
}

local Controller = {
  enabled = false,
  normalBankOpen = false,
  guildBankOpen = false,
  queue = {},
  pendingTransfers = {},
  processing = false,
  lastStatus = "Ready",
}

Banking.Controller = Controller

local function cursorIsOccupied()
  if type(GetCursorInfo) == "function" then
    return GetCursorInfo() ~= nil
  end
  return type(CursorHasItem) == "function" and CursorHasItem() and true or false
end

local function now()
  if type(GetTime) == "function" then
    return GetTime()
  end
  return 0
end

local function newStats()
  return {
    matchedStacks = 0,
    matchedItems = 0,
    movedStacks = 0,
    movedItems = 0,
    restricted = 0,
    locked = 0,
    noRoom = 0,
    rejected = 0,
    changed = 0,
    backoffs = 0,
  }
end

local function joinSkipped(stats)
  return (stats.restricted or 0)
    + (stats.locked or 0)
    + (stats.noRoom or 0)
    + (stats.rejected or 0)
    + (stats.changed or 0)
end

local function getOperation(operation)
  return OPERATIONS[operation] or OPERATIONS.deposit
end

function Controller:CreateEventFrame()
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

function Controller:Wake()
  if self.eventFrame then
    self.eventFrame:Show()
  end
end

function Controller:SleepIfIdle()
  if self.eventFrame and not self.processing and not self.panelRefreshDelay then
    self.eventFrame:Hide()
  end
end

function Controller:Print(message)
  if AP.Database:Get("banking.deposit.showChatMessages", true) then
    AP:Print(message)
  end
end

function Controller:GetActiveProvider()
  if self.guildBankOpen then
    return Banking.providers.guildStyle
  elseif self.normalBankOpen then
    return Banking.providers.character
  end
end

function Controller:SchedulePanelRefresh(delay)
  self.panelRefreshDelay = delay or 0.10
  self:Wake()
end

function Controller:RefreshPanel()
  local panel = Banking.Panel
  if not panel then
    return
  end

  local provider = self:GetActiveProvider()
  local showPanel = AP.Database:Get("banking.deposit.showPanel", true)
  if self.enabled and showPanel and provider and provider:IsOpen(self) then
    panel:ShowForProvider(provider)
    panel:SetStatus(self.lastStatus)
    panel:SetBusy(self.processing and self.category or nil, self.operation)
  else
    panel:Hide()
  end
end

function Controller:OnSettingsChanged()
  self:SchedulePanelRefresh(0)
end

function Controller:OnPacingSettingsChanged()
  if self.processing then
    self:Cancel("Transfer cancelled because adaptive pacing settings changed.")
    return
  end
  self:SchedulePanelRefresh(0)
end

function Controller:Enable()
  if self.enabled then
    self:SchedulePanelRefresh(0)
    return
  end

  self:CreateEventFrame()
  local frame = self.eventFrame
  frame:RegisterEvent("ADDON_LOADED")
  frame:RegisterEvent("BANKFRAME_OPENED")
  frame:RegisterEvent("BANKFRAME_CLOSED")
  frame:RegisterEvent("GUILDBANKFRAME_OPENED")
  frame:RegisterEvent("GUILDBANKFRAME_CLOSED")
  frame:RegisterEvent("GUILDBANKBAGSLOTS_CHANGED")
  frame:RegisterEvent("GUILDBANK_ITEM_LOCK_CHANGED")
  frame:RegisterEvent("BAG_UPDATE")
  frame:RegisterEvent("ITEM_LOCK_CHANGED")
  frame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
  frame:RegisterEvent("PLAYERBANKBAGSLOTS_CHANGED")
  frame:RegisterEvent("PLAYER_REGEN_DISABLED")

  self.normalBankOpen = (_G.BankFrame and _G.BankFrame:IsShown())
    or (_G.ElvUI_BankContainerFrame and _G.ElvUI_BankContainerFrame:IsShown())
    or false
  self.guildBankOpen = _G.GuildBankFrame and _G.GuildBankFrame:IsShown() or false
  self.enabled = true
  self:SchedulePanelRefresh(0)
end

function Controller:Disable()
  if not self.enabled then
    return
  end

  self:Cancel("Banking module disabled.", true)
  self.enabled = false
  self.normalBankOpen = false
  self.guildBankOpen = false
  self.panelRefreshDelay = nil

  if self.eventFrame then
    self.eventFrame:UnregisterAllEvents()
    self.eventFrame:Hide()
  end
  if Banking.Panel then
    Banking.Panel:Hide()
  end
  if Banking.PretendReport then
    Banking.PretendReport:Hide()
  end
end

function Controller:GetActiveOperationTitle()
  return getOperation(self.operation).title
end

function Controller:OnEvent(event, addonName)
  if TRANSFER_CONFIRM_EVENTS[event] and self.processing and self:GetPendingCount() > 0 then
    self.serverEventPending = true
    self.nextVerifyAt = now()
    self:Wake()
  end

  if event == "BANKFRAME_OPENED" then
    self.normalBankOpen = true
    self.guildBankOpen = false
    self.lastStatus = "Ready"
    self:SchedulePanelRefresh(0.12)
  elseif event == "BANKFRAME_CLOSED" then
    self.normalBankOpen = false
    if self.processing and self.activeProvider == Banking.providers.character then
      self:Cancel(self:GetActiveOperationTitle() .. " cancelled because the bank closed.")
    end
    self:SchedulePanelRefresh(0)
  elseif event == "GUILDBANKFRAME_OPENED" then
    self.guildBankOpen = true
    self.normalBankOpen = false
    self.lastStatus = "Ready"
    self:SchedulePanelRefresh(0.12)
  elseif event == "GUILDBANKFRAME_CLOSED" then
    self.guildBankOpen = false
    if self.processing and self.activeProvider == Banking.providers.guildStyle then
      self:Cancel(self:GetActiveOperationTitle() .. " cancelled because the bank closed.")
    end
    self:SchedulePanelRefresh(0)
  elseif event == "PLAYER_REGEN_DISABLED" then
    if self.processing then
      self:Cancel(self:GetActiveOperationTitle() .. " cancelled when combat started.")
    end
  elseif event == "ADDON_LOADED" and (addonName == "Blizzard_GuildBankUI" or addonName == "ElvUI") then
    self:SchedulePanelRefresh(0.12)
  end
end

function Controller:GetPacingDelay()
  if Pacing and self.pacing then
    return Pacing:GetDelay(self.pacing)
  end
  return self.activeProvider and self.activeProvider:GetMoveDelay() or 0.10
end

function Controller:GetPacingRate()
  if Pacing and self.pacing then
    return Pacing:GetRate(self.pacing)
  end
  local delay = self:GetPacingDelay()
  return delay > 0 and (1 / delay) or 0
end

function Controller:GetPendingCount()
  return self.pendingTransfers and #self.pendingTransfers or 0
end

function Controller:SyncAwaitingAlias()
  self.awaiting = self.pendingTransfers and self.pendingTransfers[1] or nil
end

function Controller:GetPipelineLimit()
  return self.pipelineLimit or 1
end

function Controller:GetObservedRate(checkedAt)
  local stats = self.stats
  if not stats or (stats.movedStacks or 0) < 1 or not self.firstSubmittedAt then
    return nil
  end

  local endpoint = checkedAt or self.lastConfirmedAt or now()
  local elapsed = endpoint - self.firstSubmittedAt
  if elapsed <= 0 then
    return nil
  end
  return stats.movedStacks / elapsed
end

function Controller:RecoverPipeline(pending)
  if not pending or pending.delayed or not self.pacing then
    self.pipelineSuccesses = 0
    return
  end

  local profile = self.pacing.profile or {}
  self.pipelineSuccesses = (self.pipelineSuccesses or 0) + 1
  if self.pipelineSuccesses >= (profile.pipelineRecoveryConfirmations or 3) then
    self.pipelineLimit = math.min(self.pipelineMaximum or 1, self:GetPipelineLimit() + 1)
    self.pipelineSuccesses = 0
  end
  if self.lastSubmittedAt and self.nextSubmitAt then
    self.nextSubmitAt = math.min(self.nextSubmitAt, self.lastSubmittedAt + self:GetPacingDelay())
  end
end

function Controller:BackOffPacing(reason, checkedAt)
  checkedAt = checkedAt or now()
  local profile = self.pacing and self.pacing.profile or {}
  local cooldown = profile.backoffCooldown or 0.75
  if self.lastBackoffAt and checkedAt - self.lastBackoffAt < cooldown then
    return false
  end

  if Pacing and self.pacing then
    Pacing:BackOff(self.pacing)
  end
  self.lastBackoffAt = checkedAt
  self.pipelineSuccesses = 0
  self.pipelineLimit = math.max(1, math.floor(self:GetPipelineLimit() / 2))
  if self.lastSubmittedAt then
    self.nextSubmitAt = math.max(self.nextSubmitAt or checkedAt, self.lastSubmittedAt + self:GetPacingDelay())
  end
  if self.stats then
    self.stats.backoffs = (self.stats.backoffs or 0) + 1
  end

  self:Print(string.format(
    "%s Adaptive transfer pacing backed off to %.1f stacks/sec.",
    reason,
    self:GetPacingRate()
  ))
  return true
end

function Controller:CreateScanner()
  if self.scanner then
    return self.scanner
  end

  local scanner = CreateFrame("GameTooltip", "LevoBankingScanner", UIParent, "GameTooltipTemplate")
  scanner:SetOwner(UIParent, "ANCHOR_NONE")
  self.scanner = scanner
  return scanner
end

function Controller:ScanItemFlags(location)
  local flags = {}
  if not location or (location.kind ~= "container" and location.kind ~= "guild-bank") then
    return flags
  end

  local scanner = self:CreateScanner()
  scanner:ClearLines()
  local scanned = false
  if location.kind == "container" and type(scanner.SetBagItem) == "function" then
    scanned = pcall(scanner.SetBagItem, scanner, location.containerID, location.slotID)
  elseif location.kind == "guild-bank" and type(scanner.SetGuildBankItem) == "function" then
    scanned = pcall(scanner.SetGuildBankItem, scanner, location.tab, location.slotID)
  end

  if not scanned then
    scanner:Hide()
    return flags
  end
  flags.scanned = true

  for lineIndex = 1, scanner:NumLines() do
    local region = _G[scanner:GetName() .. "TextLeft" .. lineIndex]
    local text = region and region:GetText()
    if text then
      if text == _G.ITEM_SOULBOUND then
        flags.soulbound = true
      elseif text == (_G.ITEM_BIND_ON_EQUIP or "Binds when equipped") then
        flags.bindOnEquip = true
      elseif text == _G.ITEM_ACCOUNTBOUND or text == _G.ITEM_BNETACCOUNTBOUND then
        flags.accountBound = true
      elseif text == "Realm Bound" then
        flags.realmBound = true
      elseif text == _G.ITEM_BIND_QUEST then
        flags.questBound = true
      elseif text == _G.ITEM_CONJURED then
        flags.conjured = true
      end
    end
  end

  scanner:Hide()
  return flags
end

function Controller:GetItemFlags(categoryID, operation, location)
  if categoryID == "boe" then
    return self:ScanItemFlags(location)
  end
  return {}
end

function Controller:GetRestriction(provider, operation, location, flags)
  flags = flags or {}
  if operation ~= "deposit" then
    return true, nil, flags
  end

  if not flags.scanned then
    flags = self:ScanItemFlags(location)
  end
  if flags.conjured then
    return false, "conjured items cannot be stored in a bank", flags
  end

  if type(provider.CanAcceptItemFlags) == "function" then
    local accepted, reason = provider:CanAcceptItemFlags(flags, operation)
    if not accepted then
      return false, reason or "the open bank rejects this item's binding flags", flags
    end
  end
  return true, nil, flags
end

function Controller:BuildQueue(categoryID, provider, operation)
  local queue = {}
  local stats = newStats()
  local locations = provider:GetSourceLocations(operation)

  for index = 1, #locations do
    local location = locations[index]
    local snapshot = provider:GetSourceSnapshot(operation, location)
    if snapshot and snapshot.itemLink and snapshot.itemID then
      local flags = self:GetItemFlags(categoryID, operation, location)
      local matches, classificationAllowed = Categories:EvaluateButton(snapshot.itemLink, categoryID, { flags = flags })
      if matches then
        stats.matchedStacks = stats.matchedStacks + 1
        stats.matchedItems = stats.matchedItems + snapshot.count

        if not classificationAllowed then
          stats.restricted = stats.restricted + 1
        elseif snapshot.locked then
          stats.locked = stats.locked + 1
        else
          queue[#queue + 1] = {
            location = location,
            itemID = snapshot.itemID,
            itemLink = snapshot.itemLink,
            flags = flags,
          }
        end
      end
    end
  end

  return queue, stats
end

function Controller:StartTransfer(categoryID, operation)
  local definition = Categories.definitions[categoryID]
  local operationInfo = OPERATIONS[operation]
  if not definition or not operationInfo then
    return
  end

  if self.processing then
    if self.category == categoryID and self.operation == operation then
      self:Cancel(string.format("%s %s cancelled.", definition.title, operationInfo.title:lower()))
    else
      local activeDefinition = Categories.definitions[self.category]
      self:Print(string.format("A %s %s is already running. Click its category again to cancel it.", activeDefinition.title, getOperation(self.operation).title:lower()))
    end
    return
  end

  if Banking.Sorter and Banking.Sorter:IsRunning() then
    self:Print("Cancel the active bank sort before starting a transfer.")
    return
  end

  local provider = self:GetActiveProvider()
  if not provider then
    self:Print("Open a bank before using " .. operationInfo.title .. ".")
    return
  end

  local canUse, reason = provider:CanUse(self, operation)
  if not canUse then
    self.lastStatus = reason
    self:RefreshPanel()
    self:Print(reason)
    return
  end

  if type(InCombatLockdown) == "function" and InCombatLockdown() then
    self:Print(operationInfo.title .. " is unavailable during combat.")
    return
  elseif cursorIsOccupied() then
    self:Print("Clear the cursor before starting a " .. operationInfo.title:lower() .. ".")
    return
  end

  local queue, stats = self:BuildQueue(categoryID, provider, operation)
  if #queue == 0 then
    local skipped = joinSkipped(stats)
    if stats.matchedStacks == 0 then
      if categoryID == "all" then
        self.lastStatus = "No items found in the " .. operationInfo.source
      else
        self.lastStatus = string.format("No %s found in the %s", definition.title:lower(), operationInfo.source)
      end
    else
      self.lastStatus = string.format("No eligible stacks (%d skipped)", skipped)
    end
    self:RefreshPanel()
    self:Print(self.lastStatus .. ".")
    return
  end

  self.queue = queue
  self.stats = stats
  self.nextIndex = 1
  self.category = categoryID
  self.operation = operation
  self.activeProvider = provider
  self.bankName = provider:GetBankName()
  self.destinationToken = provider:GetDestinationToken()
  self.pendingTransfers = {}
  self.awaiting = nil
  self.serverEventPending = nil
  local conservative = AP.Database:Get("banking.deposit.conservativePacing", false)
  local profile = type(provider.GetTransferPacingProfile) == "function"
    and provider:GetTransferPacingProfile(conservative)
    or nil
  self.pacing = Pacing and Pacing:Create(conservative, profile) or nil
  local pacingProfile = self.pacing and self.pacing.profile or profile or {}
  self.pipelineLimit = math.max(1, pacingProfile.initialInFlight or 1)
  self.pipelineMaximum = math.max(self.pipelineLimit, pacingProfile.maxInFlight or self.pipelineLimit)
  self.pipelineSuccesses = 0
  self.lastBackoffAt = nil
  self.firstSubmittedAt = nil
  self.lastSubmittedAt = nil
  self.lastConfirmedAt = nil
  stats.startedAt = now()
  self.nextSubmitAt = stats.startedAt
  self.nextVerifyAt = nil
  self.timer = 0
  self.processing = true
  self.lastStatus = string.format(
    "%s %s: 0/%d, 0 pending, %.1f/s target",
    operationInfo.gerund,
    definition.title,
    stats.matchedStacks,
    self:GetPacingRate()
  )
  self:RefreshPanel()
  self:Wake()
end

function Controller:StartDeposit(categoryID)
  self:StartTransfer(categoryID, "deposit")
end

function Controller:StartWithdraw(categoryID)
  self:StartTransfer(categoryID, "withdraw")
end

function Controller:IsTransferStillValid()
  local provider = self.activeProvider
  if not provider or not provider:IsOpen(self) then
    return false, "the bank closed"
  end

  local canUse, reason = provider:CanUse(self, self.operation)
  if not canUse then
    return false, reason
  elseif provider:GetDestinationToken() ~= self.destinationToken then
    return false, "the bank tab or view changed"
  end
  return true
end

function Controller:UpdateProgressStatus()
  if not self.processing then
    return
  end

  local definition = Categories.definitions[self.category]
  local completed = self.stats.movedStacks + joinSkipped(self.stats)
  local observedRate = self:GetObservedRate(now())
  local speedText = observedRate
    and string.format("%.1f/s live, %.1f/s target", observedRate, self:GetPacingRate())
    or string.format("%.1f/s target", self:GetPacingRate())
  local pendingCount = self:GetPendingCount()
  self.lastStatus = string.format(
    "%s %s: %d/%d, %d pending, %s",
    getOperation(self.operation).gerund,
    definition.title,
    completed,
    self.stats.matchedStacks,
    pendingCount,
    speedText
  )
  if Banking.Panel then
    Banking.Panel:SetStatus(self.lastStatus)
    Banking.Panel:SetBusy(self.category, self.operation)
  end
end

function Controller:RecordRejected(reason)
  self.stats.rejected = self.stats.rejected + 1
  self.lastRejectedReason = reason
end

function Controller:ProcessNext()
  local valid, reason = self:IsTransferStillValid()
  if not valid then
    self:Cancel(self:GetActiveOperationTitle() .. " cancelled because " .. reason .. ".")
    return
  elseif cursorIsOccupied() then
    self:Cancel(self:GetActiveOperationTitle() .. " cancelled because the cursor is occupied.")
    return
  elseif type(InCombatLockdown) == "function" and InCombatLockdown() then
    self:Cancel(self:GetActiveOperationTitle() .. " cancelled when combat started.")
    return
  end

  while self.nextIndex <= #self.queue do
    local entry = self.queue[self.nextIndex]
    self.nextIndex = self.nextIndex + 1

    local snapshot = self.activeProvider:GetSourceSnapshot(self.operation, entry.location)
    if not snapshot or snapshot.itemID ~= entry.itemID then
      self.stats.changed = self.stats.changed + 1
    elseif snapshot.locked then
      self.stats.locked = self.stats.locked + 1
    else
      local flags = self.category == "boe"
        and self:GetItemFlags(self.category, self.operation, entry.location)
        or (entry.flags or {})
      local matches, classificationAllowed = Categories:EvaluateButton(snapshot.itemLink, self.category, { flags = flags })
      if not matches or not classificationAllowed then
        self.stats.changed = self.stats.changed + 1
      else
        local accepted, _, checkedFlags = self:GetRestriction(self.activeProvider, self.operation, entry.location, flags)
        entry.flags = checkedFlags or flags
        if not accepted then
          self.stats.restricted = self.stats.restricted + 1
        else
          local hasCapacity = self.activeProvider:HasDestinationCapacity(self.operation, snapshot.itemLink)
          if not hasCapacity then
            self.stats.noRoom = self.stats.noRoom + 1
          else
            local submittedAt = now()
            self.serverEventPending = nil
            local pending = {
              entry = entry,
              beforeCount = snapshot.count,
              submittedAt = submittedAt,
              backedOff = false,
              delayed = false,
            }
            self.pendingTransfers[#self.pendingTransfers + 1] = pending
            self:SyncAwaitingAlias()
            self.firstSubmittedAt = self.firstSubmittedAt or submittedAt
            self.lastSubmittedAt = submittedAt
            local ok, transferResult = pcall(self.activeProvider.Transfer, self.activeProvider, self.operation, entry.location)
            if ok and transferResult ~= false then
              self.nextSubmitAt = submittedAt + self:GetPacingDelay()
              local verifyAt = self.serverEventPending and submittedAt or submittedAt + 0.04
              if not self.nextVerifyAt or verifyAt < self.nextVerifyAt then
                self.nextVerifyAt = verifyAt
              end
              self.timer = math.max(0, self.nextSubmitAt - submittedAt)
              self:UpdateProgressStatus()
              return
            end

            table.remove(self.pendingTransfers, #self.pendingTransfers)
            self:SyncAwaitingAlias()
            pending.backedOff = true
            pending.delayed = true
            local failureReason = ok and "The server rejected the transfer call." or "The transfer call failed."
            self:BackOffPacing(failureReason, now())
            self:RecordRejected(failureReason)
            self.nextSubmitAt = now() + self:GetPacingDelay()
            self.timer = self:GetPacingDelay()
            self:UpdateProgressStatus()
            return
          end
        end
      end
    end
  end

  if self:GetPendingCount() == 0 then
    self:Finish()
  else
    self:UpdateProgressStatus()
  end
end

function Controller:VerifyPending(checkedAt)
  local pendingTransfers = self.pendingTransfers or {}
  if #pendingTransfers == 0 then
    return
  end

  local valid, reason = self:IsTransferStillValid()
  if not valid then
    self:Cancel(self:GetActiveOperationTitle() .. " cancelled because " .. reason .. ".")
    return
  end

  checkedAt = checkedAt or now()
  local timeout = self.activeProvider and self.activeProvider:GetResponseTimeout() or 0.80
  local remaining = {}

  for index = 1, #pendingTransfers do
    local pending = pendingTransfers[index]
    local entry = pending.entry
    local snapshot = self.activeProvider:GetSourceSnapshot(self.operation, entry.location)
    local itemID = snapshot and snapshot.itemID
    local count = snapshot and snapshot.count or 0
    local latency = math.max(0, checkedAt - (pending.submittedAt or checkedAt))

    local movedCount
    if itemID ~= entry.itemID then
      movedCount = pending.beforeCount
    elseif count < pending.beforeCount then
      movedCount = pending.beforeCount - count
    end

    if movedCount and movedCount > 0 then
      if Pacing and self.pacing then
        Pacing:Confirm(self.pacing, latency, pending.delayed)
      end
      self.stats.movedStacks = self.stats.movedStacks + 1
      self.stats.movedItems = self.stats.movedItems + movedCount
      self.lastConfirmedAt = checkedAt
      self:RecoverPipeline(pending)

      if snapshot and itemID == entry.itemID and count > 0 then
        entry.itemLink = snapshot.itemLink or entry.itemLink
        self.queue[#self.queue + 1] = entry
        self.stats.matchedStacks = self.stats.matchedStacks + 1
      end
    elseif latency + 0.001 < timeout then
      if Pacing and self.pacing and Pacing:IsDelayed(self.pacing, latency) and not pending.delayed then
        pending.delayed = true
        pending.backedOff = self:BackOffPacing("The server response is delayed.", checkedAt) and true or false
      end
      remaining[#remaining + 1] = pending
    else
      if not pending.delayed then
        pending.delayed = true
        pending.backedOff = self:BackOffPacing("The server did not confirm a transfer.", checkedAt) and true or false
      end

      if cursorIsOccupied() then
        self:Cancel("Transfer stopped because a failed stack left an item on the cursor.")
        return
      elseif snapshot and snapshot.locked then
        self:Cancel("Transfer stopped because a failed stack remained server-locked.")
        return
      end

      self:RecordRejected("The server did not confirm this stack, so it was skipped.")
    end
  end

  self.pendingTransfers = remaining
  self:SyncAwaitingAlias()
  self.serverEventPending = nil
  self.nextVerifyAt = #remaining > 0 and checkedAt + 0.04 or nil
  self:UpdateProgressStatus()

  if self.nextIndex > #self.queue and #remaining == 0 then
    self:Finish()
  end
end

-- Kept as a compatibility entry point for older callers and focused tests.
function Controller:VerifyAwaiting()
  self:VerifyPending(now())
end

function Controller:Finish()
  local stats = self.stats or {}
  local skipped = joinSkipped(stats)
  local bankName = self.bankName or "the bank"
  local operation = self.operation
  local operationInfo = getOperation(operation)
  local destinationText = operation == "withdraw" and "to Inventory from " .. bankName or "to " .. bankName
  local summary = string.format("%s %d item%s in %d stack%s %s", operationInfo.past, stats.movedItems or 0, (stats.movedItems or 0) == 1 and "" or "s", stats.movedStacks or 0, (stats.movedStacks or 0) == 1 and "" or "s", destinationText)
  if skipped > 0 then
    summary = summary .. string.format("; %d stack%s skipped", skipped, skipped == 1 and "" or "s")
  end
  if (stats.backoffs or 0) > 0 then
    summary = summary .. string.format("; adaptive pacing backed off %d time%s", stats.backoffs, stats.backoffs == 1 and "" or "s")
  end
  local observedRate = self:GetObservedRate(now())
  if observedRate then
    summary = summary .. string.format("; %.1f stacks/sec measured", observedRate)
  end

  self.processing = false
  self.pendingTransfers = {}
  self.awaiting = nil
  self.serverEventPending = nil
  self.queue = {}
  self.nextIndex = nil
  self.activeProvider = nil
  self.destinationToken = nil
  self.bankName = nil
  self.pacing = nil
  self.pipelineLimit = nil
  self.pipelineMaximum = nil
  self.pipelineSuccesses = nil
  self.lastBackoffAt = nil
  self.nextSubmitAt = nil
  self.nextVerifyAt = nil
  self.firstSubmittedAt = nil
  self.lastSubmittedAt = nil
  self.lastConfirmedAt = nil
  self.timer = nil
  self.lastStatus = summary
  self.category = nil
  self.operation = nil
  self:RefreshPanel()
  self:Print(summary .. ".")
  self:SleepIfIdle()
end

function Controller:Cancel(reason, quiet)
  local wasProcessing = self.processing
  local pendingCount = self:GetPendingCount()
  if reason and pendingCount > 0 then
    reason = reason .. string.format(" New submissions stopped; %d already-submitted stack%s may still complete.", pendingCount, pendingCount == 1 and "" or "s")
  end
  self.processing = false
  self.pendingTransfers = {}
  self.awaiting = nil
  self.serverEventPending = nil
  self.queue = {}
  self.nextIndex = nil
  self.activeProvider = nil
  self.destinationToken = nil
  self.bankName = nil
  self.pacing = nil
  self.pipelineLimit = nil
  self.pipelineMaximum = nil
  self.pipelineSuccesses = nil
  self.lastBackoffAt = nil
  self.nextSubmitAt = nil
  self.nextVerifyAt = nil
  self.firstSubmittedAt = nil
  self.lastSubmittedAt = nil
  self.lastConfirmedAt = nil
  self.category = nil
  self.operation = nil
  self.timer = nil

  if reason then
    self.lastStatus = reason
  end
  self:RefreshPanel()
  if wasProcessing and reason and not quiet then
    self:Print(reason)
  end
  self:SleepIfIdle()
end

function Controller:BuildAudit(categoryID, provider, operation)
  local audit = {
    operation = operation,
    entries = {},
    matchedStacks = 0,
    matchedItems = 0,
    eligibleStacks = 0,
    eligibleItems = 0,
  }

  local canUse, unavailableReason = provider:CanUse(self, operation)
  audit.available = canUse and true or false
  audit.unavailableReason = unavailableReason

  local locations = provider:GetSourceLocations(operation)
  for index = 1, #locations do
    local location = locations[index]
    local snapshot = provider:GetSourceSnapshot(operation, location)
    if snapshot and snapshot.itemLink and snapshot.itemID then
      local flags = self:GetItemFlags(categoryID, operation, location)
      local matches, classificationAllowed, evidence = Categories:EvaluateButton(snapshot.itemLink, categoryID, { flags = flags })
      if matches then
        audit.matchedStacks = audit.matchedStacks + 1
        audit.matchedItems = audit.matchedItems + snapshot.count

        local accepted = classificationAllowed
        local restrictionReason = not classificationAllowed and evidence.reason or nil
        local flagsChecked = flags.scanned and true or false
        if classificationAllowed then
          accepted, restrictionReason, flags = self:GetRestriction(provider, operation, location, flags)
          flagsChecked = flags.scanned and true or false
        end
        local eligible = true
        local statusReason
        if not audit.available then
          eligible = false
          statusReason = unavailableReason
        elseif not classificationAllowed then
          eligible = false
          statusReason = restrictionReason
        elseif snapshot.locked then
          eligible = false
          statusReason = "the source stack is locked"
        elseif not accepted then
          eligible = false
          statusReason = restrictionReason
        end

        if eligible then
          local hasCapacity, capacityReason = provider:HasDestinationCapacity(operation, snapshot.itemLink)
          if not hasCapacity then
            eligible = false
            statusReason = capacityReason
          end
        end

        if eligible then
          audit.eligibleStacks = audit.eligibleStacks + 1
          audit.eligibleItems = audit.eligibleItems + snapshot.count
        end

        audit.entries[#audit.entries + 1] = {
          itemID = snapshot.itemID,
          itemLink = snapshot.itemLink,
          count = snapshot.count,
          source = provider:GetSourceLabel(operation, location),
          evidence = evidence,
          flags = flags,
          flagsChecked = flagsChecked,
          eligible = eligible,
          statusReason = statusReason,
        }
      end
    end
  end

  table.sort(audit.entries, function(left, right)
    local leftName = left.evidence.itemName or left.itemLink or ""
    local rightName = right.evidence.itemName or right.itemLink or ""
    if leftName == rightName then
      return left.source < right.source
    end
    return leftName < rightName
  end)
  return audit
end

function Controller:RunPretend(categoryID)
  local definition = Categories.definitions[categoryID]
  if not definition then
    return
  elseif self.processing then
    self:Print("Cancel the active transfer before building a PRETEND report.")
    return
  elseif Banking.Sorter and Banking.Sorter:IsRunning() then
    self:Print("Cancel the active bank sort before building a PRETEND report.")
    return
  end

  local provider = self:GetActiveProvider()
  if not provider then
    self:Print("Open a bank before using PRETEND.")
    return
  end

  local canUse, reason = provider:CanUse(self, "pretend")
  if not canUse then
    self.lastStatus = reason
    self:RefreshPanel()
    self:Print(reason)
    return
  end

  local depositAudit = self:BuildAudit(categoryID, provider, "deposit")
  local withdrawAudit = self:BuildAudit(categoryID, provider, "withdraw")
  local report = Banking.PretendReport
  if not report then
    self:Print("The PRETEND report UI did not load. Fully relog to load new addon files.")
    return
  end

  report:Open(categoryID, provider, depositAudit, withdrawAudit)
  self.lastStatus = string.format("PRETEND: %d deposit + %d withdraw stacks", depositAudit.matchedStacks, withdrawAudit.matchedStacks)
  self:RefreshPanel()
end

function Controller:RunCategory(categoryID, mode)
  if mode == "pretend" then
    self:RunPretend(categoryID)
  elseif mode == "withdraw" then
    self:StartWithdraw(categoryID)
  else
    self:StartDeposit(categoryID)
  end
end

function Controller:OnUpdate(elapsed)
  if self.panelRefreshDelay then
    self.panelRefreshDelay = self.panelRefreshDelay - elapsed
    if self.panelRefreshDelay <= 0 then
      self.panelRefreshDelay = nil
      self:RefreshPanel()
    end
  end

  if self.processing then
    local checkedAt = now()
    if self:GetPendingCount() > 0
      and (self.serverEventPending or not self.nextVerifyAt or checkedAt + 0.001 >= self.nextVerifyAt) then
      self:VerifyPending(checkedAt)
    end

    if self.processing
      and self.nextIndex <= #self.queue
      and self:GetPendingCount() < self:GetPipelineLimit()
      and checkedAt + 0.001 >= (self.nextSubmitAt or checkedAt) then
      self:ProcessNext()
    elseif self.processing and self.nextIndex > #self.queue and self:GetPendingCount() == 0 then
      self:Finish()
    end

    if self.processing then
      local nextActivityAt
      if self:GetPendingCount() > 0 then
        nextActivityAt = self.nextVerifyAt
      end
      if self.nextIndex <= #self.queue and self:GetPendingCount() < self:GetPipelineLimit() then
        local submitAt = self.nextSubmitAt or checkedAt
        nextActivityAt = not nextActivityAt and submitAt or math.min(nextActivityAt, submitAt)
      end
      self.timer = nextActivityAt and math.max(0, nextActivityAt - checkedAt) or 0.04
    end
  end

  self:SleepIfIdle()
end

function Controller:GetStatusText()
  if self.processing then
    return self.lastStatus .. "."
  end

  local provider = self:GetActiveProvider()
  if provider then
    return "Ready at " .. provider:GetBankName() .. ". Withdraw and PRETEND use only the visible guild-style tab."
  end
  return "Idle. Open a Character Bank or Guild-style Bank to show the transfer panel."
end
