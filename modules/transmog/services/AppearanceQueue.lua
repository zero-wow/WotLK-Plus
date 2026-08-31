local _, AP = ...
AP = AP or _G.Levo or _G.WotLKPlus or _G.AscensionPlus

local Collector = AP.TransmogAutoCollect

local MAX_REQUEST_ATTEMPTS = 2
local REQUEST_TIMEOUT = 1.75
local MANUAL_CONFIRM_TIMEOUT = 30
local POPUP_CONFIRM_DELAY = 0.05
local POPUP_DETECTION_WINDOW = 1.25
local REQUEST_SPACING = 0.10

local function safeCall(fn, ...)
  if type(fn) ~= "function" then
    return false, "function unavailable"
  end
  return pcall(fn, ...)
end

local function getPopupButton(popup, index)
  if not popup then
    return nil
  end

  local popupName = popup.GetName and popup:GetName()
  if popupName then
    return _G[popupName .. "Button" .. tostring(index)]
  end
  return popup["button" .. tostring(index)]
end

local function getPopupText(popup)
  if not popup then
    return ""
  end

  local popupName = popup.GetName and popup:GetName()
  local textRegion = popupName and _G[popupName .. "Text"]
  if textRegion and textRegion.GetText then
    return textRegion:GetText() or ""
  end
  return ""
end

function Collector:BeginCollectionBatch(source)
  if not self.collectionBatch then
    self.collectionBatch = {
      source = source or "bags",
      queued = 0,
      collected = 0,
      failed = 0,
    }
  elseif self.collectionBatch.source ~= source then
    self.collectionBatch.source = "bag scans"
  end
  return self.collectionBatch
end

function Collector:QueueAppearance(entry, source)
  if not entry or not entry.appearanceID or self.queuedAppearanceIDs[entry.appearanceID] then
    return false
  end
  if not entry.manualRequest and not self:IsAutomationAuthorized() then
    return false
  end
  if not entry.manualRequest and not entry.ruleApproved and not entry.automaticRequest then
    return false
  end
  if not entry.manualRequest and not entry.ruleApproved and not self:IsRuntimeEnabled() then
    return false
  end

  entry.source = source or "bags"
  if entry.ruleApproved then
    table.insert(self.collectionQueue, 1, entry)
  else
    self.collectionQueue[#self.collectionQueue + 1] = entry
  end
  self.queuedAppearanceIDs[entry.appearanceID] = true

  local batch = self:BeginCollectionBatch(entry.source)
  batch.queued = batch.queued + 1
  if self.NotifyAppearanceInbox then
    self:NotifyAppearanceInbox("appearance queued", 0)
  end
  return true
end

function Collector:FinishCollectionBatch()
  if self.activeRequest or #self.collectionQueue > 0 then
    return
  end

  local batch = self.collectionBatch
  self.collectionBatch = nil
  if not batch or batch.queued == 0 or not self:ShouldPrint() then
    return
  end

  if batch.failed > 0 then
    AP:Print(string.format(
      "Collected %d of %d appearance%s from %s; %d request%s could not be confirmed.",
      batch.collected,
      batch.queued,
      batch.queued == 1 and "" or "s",
      batch.source,
      batch.failed,
      batch.failed == 1 and "" or "s"
    ))
  else
    AP:Print(string.format(
      "Collected %d appearance%s from %s.",
      batch.collected,
      batch.collected == 1 and "" or "s",
      batch.source
    ))
  end
end

function Collector:ClearCollectionQueue()
  self.collectionQueue = {}
  self.queuedAppearanceIDs = {}
  self.activeRequest = nil
  self.nextRequestAt = nil
  self.collectionBatch = nil
  self.collectCallInProgress = false
  self.pendingPopup = nil
  self.popupConfirmAt = nil
  if self.NotifyAppearanceInbox then
    self:NotifyAppearanceInbox("queue cleared", 0)
  end
end

function Collector:CompleteActiveRequest(success)
  local request = self.activeRequest
  if not request then
    return
  end

  self.queuedAppearanceIDs[request.appearanceID] = nil
  self.activeRequest = nil
  self.pendingPopup = nil
  self.popupConfirmAt = nil

  if self.collectionBatch then
    if success then
      self.collectionBatch.collected = self.collectionBatch.collected + 1
    else
      self.collectionBatch.failed = self.collectionBatch.failed + 1
    end
  end

  self.nextRequestAt = GetTime() + REQUEST_SPACING
  if self.NotifyAppearanceInbox then
    self:NotifyAppearanceInbox(success and "collection confirmed" or "collection failed", 0.15)
  end
  self:FinishCollectionBatch()
  local rules = AP.TransmogAppearanceRules
  if rules and rules.OnCollectionQueueAdvanced then
    rules:OnCollectionQueueAdvanced()
  end
end

function Collector:FindItemByGUID(request)
  if not request or not request.guid or request.guid == "" then
    return false
  end

  if GetContainerItemGUID(request.bag, request.slot) == request.guid then
    return GetContainerItemID(request.bag, request.slot) == request.itemID
  end

  local firstBag = BACKPACK_CONTAINER or 0
  local lastBag = NUM_BAG_SLOTS or 4
  for bag = firstBag, lastBag do
    local slotCount = GetContainerNumSlots(bag) or 0
    for slot = 1, slotCount do
      if GetContainerItemGUID(bag, slot) == request.guid then
        if GetContainerItemID(bag, slot) ~= request.itemID then
          return false
        end
        request.bag = bag
        request.slot = slot
        request.link = (GetContainerItemLink and GetContainerItemLink(bag, slot)) or request.link
        return true
      end
    end
  end

  return false
end

function Collector:GetRequestState(request)
  if not self:FindItemByGUID(request) then
    return "invalid"
  end
  if self:IsBlacklisted(request.itemID) then
    return "invalid"
  end
  if not request.manualRequest and not self:IsTypeAllowed(request.itemClass, request.equipSlot) then
    return "invalid"
  end
  if request.automaticRequest and not request.ruleApproved
      and self:GetQualityMode(request.quality) ~= "auto" then
    return "invalid"
  end

  local currentAppearanceID = self:GetAppearanceID(request.itemID)
  if currentAppearanceID ~= request.appearanceID then
    return "invalid"
  end

  local ok, isCollected = self:IsAppearanceCollected(request.appearanceID)
  if not ok then
    return "unavailable"
  end
  return isCollected and "collected" or "ready"
end

function Collector:CanRetryRequest(request)
  return request
    and not request.manualRequest
    and not request.manualConfirmation
    and self:ShouldAutoConfirmBinding(request)
end

function Collector:CaptureVisiblePopups()
  local visible = {}
  for index = 1, (STATICPOPUP_NUMDIALOGS or 4) do
    local popup = _G["StaticPopup" .. tostring(index)]
    if popup and popup.IsShown and popup:IsShown() then
      visible[popup] = true
    end
  end
  return visible
end

function Collector:FindShownPopup(which)
  for index = 1, (STATICPOPUP_NUMDIALOGS or 4) do
    local popup = _G["StaticPopup" .. tostring(index)]
    if popup and popup.IsShown and popup:IsShown() and (not which or popup.which == which) then
      return popup
    end
  end
  return nil
end

function Collector:IsLikelyAppearancePopup(which, popup, request)
  local popupKey = string.upper(tostring(which or ""))
  if string.find(popupKey, "DELETE", 1, true)
      or string.find(popupKey, "DESTROY", 1, true)
      or string.find(popupKey, "LOOT", 1, true)
      or string.find(popupKey, "QUEST", 1, true)
      or string.find(popupKey, "TRADE", 1, true)
      or string.find(popupKey, "RELOAD", 1, true)
      or string.find(popupKey, "ADDON", 1, true) then
    return false
  end

  if popupKey == "CONFIRM_BINDER"
      or string.find(popupKey, "APPEAR", 1, true)
      or string.find(popupKey, "TRANSMOG", 1, true)
      or string.find(popupKey, "WARDROBE", 1, true)
      or string.find(popupKey, "COLLECT", 1, true) then
    return true
  end

  local popupText = string.lower(getPopupText(popup))
  if string.find(popupText, "appearance", 1, true)
      or string.find(popupText, "transmog", 1, true)
      or string.find(popupText, "wardrobe", 1, true)
      or string.find(popupText, "collect", 1, true) then
    return true
  end

  local itemName = request and request.name and string.lower(request.name)
  return itemName and itemName ~= "" and string.find(popupText, itemName, 1, true) ~= nil
end

function Collector:QueuePopupConfirmation(which, synchronous)
  local request = self.activeRequest
  if not request or not self:ShouldAutoConfirmBinding(request) then
    return
  end

  self.pendingPopup = {
    which = which,
    token = request.token,
    synchronous = synchronous and true or false,
  }
  self.popupConfirmAt = GetTime() + POPUP_CONFIRM_DELAY
end

function Collector:OnStaticPopupShown(which)
  local request = self.activeRequest
  if not request or not self:ShouldAutoConfirmBinding(request) then
    return
  end

  local now = GetTime()
  local synchronous = self.collectCallInProgress and true or false
  if synchronous or (request.confirmUntil and now <= request.confirmUntil) then
    self:QueuePopupConfirmation(which, synchronous)
  end
end

function Collector:EnsurePopupHook()
  if self.popupHooked or type(hooksecurefunc) ~= "function" or type(StaticPopup_Show) ~= "function" then
    return
  end

  self.popupHooked = true
  hooksecurefunc("StaticPopup_Show", function(which)
    Collector:OnStaticPopupShown(which)
  end)
end

function Collector:DetectNewAppearancePopup(now)
  local request = self.activeRequest
  if not request or not request.confirmUntil or now > request.confirmUntil
      or self.pendingPopup or not self:ShouldAutoConfirmBinding(request) then
    return
  end

  for index = 1, (STATICPOPUP_NUMDIALOGS or 4) do
    local popup = _G["StaticPopup" .. tostring(index)]
    if popup and popup.IsShown and popup:IsShown() and not request.visiblePopups[popup] then
      if self:IsLikelyAppearancePopup(popup.which, popup, request) then
        self:QueuePopupConfirmation(popup.which, false)
        return
      end
    end
  end
end

function Collector:ConfirmPendingPopup(now)
  local pending = self.pendingPopup
  local request = self.activeRequest
  if not pending or not request or pending.token ~= request.token then
    self.pendingPopup = nil
    self.popupConfirmAt = nil
    return
  end
  if self.popupConfirmAt and now < self.popupConfirmAt then
    return
  end
  if not self:ShouldAutoConfirmBinding(request) then
    self.pendingPopup = nil
    self.popupConfirmAt = nil
    return
  end
  if not request.confirmUntil or now > request.confirmUntil then
    self.pendingPopup = nil
    self.popupConfirmAt = nil
    return
  end

  local requestState = self:GetRequestState(request)
  if requestState ~= "ready" then
    self.pendingPopup = nil
    self.popupConfirmAt = nil
    self:CompleteActiveRequest(requestState == "collected")
    return
  end

  local popup = self:FindShownPopup(pending.which)
  if not popup then
    self.popupConfirmAt = now + POPUP_CONFIRM_DELAY
    return
  end
  if request.visiblePopups[popup] then
    self.pendingPopup = nil
    self.popupConfirmAt = nil
    return
  end

  local popupName = popup.GetName and popup:GetName()
  local editBox = popupName and _G[popupName .. "EditBox"]
  if editBox and editBox.IsShown and editBox:IsShown() then
    self.pendingPopup = nil
    self.popupConfirmAt = nil
    return
  end

  if not pending.synchronous and not self:IsLikelyAppearancePopup(pending.which, popup, request) then
    self.pendingPopup = nil
    self.popupConfirmAt = nil
    return
  end

  local button = getPopupButton(popup, 1)
  if not button or not button.IsShown or not button:IsShown()
      or (button.IsEnabled and not button:IsEnabled()) then
    self.popupConfirmAt = now + POPUP_CONFIRM_DELAY
    return
  end

  local ok = pcall(button.Click, button)
  if ok then
    request.popupConfirmed = true
  end
  self.pendingPopup = nil
  self.popupConfirmAt = nil
end

function Collector:DispatchActiveRequest()
  local request = self.activeRequest
  if not request then
    return
  end

  local state = self:GetRequestState(request)
  if state == "collected" then
    self:CompleteActiveRequest(true)
    return
  elseif state ~= "ready" then
    self:CompleteActiveRequest(false)
    return
  end

  local now = GetTime()
  request.attempts = (request.attempts or 0) + 1
  request.requestedAt = now
  request.verifyAt = now + 0.15
  request.deadline = now + (self:ShouldAutoConfirmBinding(request) and REQUEST_TIMEOUT or MANUAL_CONFIRM_TIMEOUT)
  request.confirmUntil = now + POPUP_DETECTION_WINDOW
  request.retryAt = nil
  request.popupConfirmed = false
  request.visiblePopups = self:CaptureVisiblePopups()

  self.collectCallInProgress = true
  local ok, result = safeCall(C_AppearanceCollection.CollectItemAppearance, request.guid)
  self.collectCallInProgress = false

  if request.manualRequest then
    self.lastManualDispatch = {
      appearanceID = request.appearanceID,
      guid = request.guid,
      submitted = ok and true or false,
      error = ok and nil or tostring(result),
      at = now,
    }
  end

  if not ok then
    request.lastError = tostring(result)
    if self:CanRetryRequest(request) and request.attempts < MAX_REQUEST_ATTEMPTS then
      request.retryAt = now + 0.35
      request.deadline = nil
    else
      self:CompleteActiveRequest(false)
    end
    return
  end

  local currentState = self:GetRequestState(request)
  if currentState == "collected" then
    self:CompleteActiveRequest(true)
  end
end

function Collector:StartNextRequest()
  if self.activeRequest or #self.collectionQueue == 0 then
    self:FinishCollectionBatch()
    return
  end

  local request = table.remove(self.collectionQueue, 1)
  self.requestSequence = self.requestSequence + 1
  request.token = self.requestSequence
  self.activeRequest = request
  self:DispatchActiveRequest()
end

function Collector:HandleActiveRequest(now)
  local request = self.activeRequest
  if not request then
    return
  end

  self:DetectNewAppearancePopup(now)
  if self.pendingPopup then
    self:ConfirmPendingPopup(now)
  end

  request = self.activeRequest
  if not request then
    return
  end

  if request.retryAt then
    if now >= request.retryAt then
      self:DispatchActiveRequest()
    end
    return
  end

  if request.verifyAt and now >= request.verifyAt then
    local state = self:GetRequestState(request)
    if state == "collected" then
      self:CompleteActiveRequest(true)
      return
    elseif state == "invalid" or state == "unavailable" then
      self:CompleteActiveRequest(false)
      return
    end

    if request.deadline and now >= request.deadline then
      if self:CanRetryRequest(request) and request.attempts < MAX_REQUEST_ATTEMPTS then
        request.retryAt = now + 0.20
        request.deadline = nil
        self.pendingPopup = nil
        self.popupConfirmAt = nil
      else
        self:CompleteActiveRequest(false)
      end
    else
      request.verifyAt = now + 0.20
    end
  end
end

function Collector:ProcessCollectionQueue(now)
  if not self.moduleEnabled then
    return
  end

  if self.activeRequest then
    self:HandleActiveRequest(now)
    return
  end

  local rules = AP.TransmogAppearanceRules
  if rules and rules.activeEntry then
    return
  end

  if #self.collectionQueue > 0
      and AP.Database:Get("transmog.autoCollect.deferUntilOutOfCombat", true)
      and InCombatLockdown and InCombatLockdown() then
    return
  end

  if #self.collectionQueue > 0 and (not self.nextRequestAt or now >= self.nextRequestAt) then
    self:StartNextRequest()
    return
  end

  self:FinishCollectionBatch()
end
