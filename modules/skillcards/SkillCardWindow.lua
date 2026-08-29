local _, AP = ...
AP = AP or _G.AscensionPlus

if not AP then
  return
end

AP.SkillCards = AP.SkillCards or {}

local Theme = AP.UI.Theme
local Catalog = AP.SkillCards.Catalog

local Window = {
  frame = nil,
  toast = nil,
  mode = "expanded",
  view = "unknown",
  cardButtons = {},
  exchangeButtons = {},
  pendingInventoryRefresh = false,
  pendingVisibility = nil,
  pendingMode = nil,
  pendingResetPosition = false,
  sessionConfirmedGroups = {},
}

AP.SkillCards.Window = Window

local LAYOUT = {
  minWidth = 480,
  minHeight = 420,
  maxWidth = 620,
  maxHeight = 560,
  defaultWidth = 520,
  defaultHeight = 470,
  compactWidth = 420,
  compactHeight = 122,
  inset = 12,
  headerHeight = 46,
  summaryHeight = 58,
  filterHeight = 28,
  footerHeight = 26,
  exchangeHeight = 80,
  cardSize = 40,
  cardGap = 8,
}

Window.Layout = LAYOUT

local KINDS = {
  { id = "normal", label = "NORMAL" },
  { id = "lucky", label = "LUCKY" },
  { id = "golden", label = "GOLDEN" },
  { id = "goldenLucky", label = "LUCKY GOLD" },
}

local function trim(text)
  return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function inCombat()
  return type(InCombatLockdown) == "function" and InCombatLockdown() and true or false
end

local function isFrameShown(frame)
  local frameType = type(frame)
  if frameType ~= "table" and frameType ~= "userdata" then
    return false
  end
  if type(frame.IsShown) == "function" then
    local ok, shown = pcall(frame.IsShown, frame)
    if ok then
      return shown and true or false
    end
  end
  if type(frame.IsVisible) == "function" then
    local ok, visible = pcall(frame.IsVisible, frame)
    return ok and visible and true or false
  end
  return false
end

local function showError(message)
  if UIErrorsFrame and UIErrorsFrame.AddMessage then
    UIErrorsFrame:AddMessage(tostring(message or "Skill Card action unavailable."), 1, 0.25, 0.20, 1, 1)
  else
    AP:Print(message or "Skill Card action unavailable.")
  end
end

local function paint(texture, color)
  Theme:Paint(texture, color)
end

local function saveWindowState(frame)
  if not frame then
    return
  end

  local point, _, relPoint, x, y = frame:GetPoint(1)
  local current = AP.Database:Get("skillCards.window", {})
  local width = Window.mode == "expanded" and frame:GetWidth() or current.width
  local height = Window.mode == "expanded" and frame:GetHeight() or current.height
  AP.Database:Set("skillCards.window", {
    point = point or "CENTER",
    relPoint = relPoint or point or "CENTER",
    x = x or 0,
    y = y or 20,
    width = math.floor(width or LAYOUT.defaultWidth),
    height = math.floor(height or LAYOUT.defaultHeight),
  })
end

local function applyWindowAnchor(frame)
  local state = AP.Database:Get("skillCards.window", {})
  frame:ClearAllPoints()
  frame:SetPoint(
    state.point or "CENTER",
    UIParent,
    state.relPoint or state.point or "CENTER",
    tonumber(state.x) or 0,
    tonumber(state.y) or 20
  )
end

function Window:GetLayoutMetrics(width, height, vendorOpen, mode)
  width = tonumber(width) or LAYOUT.defaultWidth
  height = tonumber(height) or LAYOUT.defaultHeight
  mode = mode or self.mode

  local innerWidth = width - (LAYOUT.inset * 2)
  if mode == "compact" then
    return {
      innerWidth = innerWidth,
      summaryTop = LAYOUT.headerHeight + 4,
      summaryHeight = 46,
      footerBottom = 7,
      gridHeight = 0,
      exchangeVisible = false,
    }
  end

  local summaryTop = LAYOUT.headerHeight + LAYOUT.inset
  local filterTop = summaryTop + LAYOUT.summaryHeight + 8
  local gridTop = filterTop + LAYOUT.filterHeight + 8
  local footerBottom = 8
  local exchangeVisible = vendorOpen and true or false
  local gridBottom = footerBottom + LAYOUT.footerHeight + 8
  if exchangeVisible then
    gridBottom = gridBottom + LAYOUT.exchangeHeight + 8
  end

  return {
    innerWidth = innerWidth,
    summaryTop = summaryTop,
    summaryHeight = LAYOUT.summaryHeight,
    filterTop = filterTop,
    gridTop = gridTop,
    gridBottom = gridBottom,
    gridHeight = math.max(54, height - gridTop - gridBottom),
    footerBottom = footerBottom,
    exchangeBottom = footerBottom + LAYOUT.footerHeight + 8,
    exchangeVisible = exchangeVisible,
  }
end

local function setStatusText(frame, text, color)
  color = color or Theme.colors.muted
  frame.StatusBadge:SetText(text)
  frame.StatusBadge:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

local function getSnapshot()
  return Catalog:GetSnapshot() or Catalog:Scan("ledger open")
end

local function getVisibleRecords(snapshot, view)
  local records = {}
  local cards = snapshot and (snapshot.cards or snapshot.entries) or {}
  for index = 1, #cards do
    local record = cards[index]
    if view == "all" or record.unknown then
      records[#records + 1] = record
    end
  end
  return records
end

function Window:AcquireCardButton(index)
  local button = self.cardButtons[index]
  if button then
    return button
  end
  if inCombat() then
    return nil
  end

  button = CreateFrame("Button", nil, self.frame.CardChild)
  button:SetWidth(LAYOUT.cardSize)
  button:SetHeight(LAYOUT.cardSize)
  button:RegisterForClicks("LeftButtonUp")
  Theme:ApplyBackdrop(button, Theme.colors.inset, Theme.colors.neutralLine or Theme.colors.border)

  button.Icon = button:CreateTexture(nil, "ARTWORK")
  button.Icon:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
  button.Icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)

  button.Hover = button:CreateTexture(nil, "HIGHLIGHT")
  button.Hover:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
  button.Hover:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
  paint(button.Hover, { 1, 1, 1, 0.12 })

  button.Count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  button.Count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
  button.Count:SetTextColor(1, 1, 1, 1)
  if button.Count.SetShadowColor then
    button.Count:SetShadowColor(0, 0, 0, 1)
    button.Count:SetShadowOffset(1, -1)
  end

  button.TypeBadge = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  button.TypeBadge:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
  if button.TypeBadge.SetShadowColor then
    button.TypeBadge:SetShadowColor(0, 0, 0, 1)
    button.TypeBadge:SetShadowOffset(1, -1)
  end

  button.Ownership = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  button.Ownership:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 3, 3)
  button.Ownership:SetTextColor(Theme.colors.orange[1], Theme.colors.orange[2], Theme.colors.orange[3], 1)
  if button.Ownership.SetShadowColor then
    button.Ownership:SetShadowColor(0, 0, 0, 1)
    button.Ownership:SetShadowOffset(1, -1)
  end

  button:SetScript("OnEnter", function(self)
    local record = self.record
    if not AP.Database:Get("skillCards.showTooltips", true) or not record or not GameTooltip then
      return
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if record.link and GameTooltip.SetHyperlink then
      GameTooltip:SetHyperlink(record.link)
    elseif GameTooltip.SetBagItem then
      GameTooltip:SetBagItem(record.bag, record.slot)
    end
    if GameTooltip.AddLine then
      if record.unknown then
        GameTooltip:AddLine("Unlearned design", Theme.colors.orange[1], Theme.colors.orange[2], Theme.colors.orange[3])
      elseif record.ownershipKnown then
        GameTooltip:AddLine("Already learned", Theme.colors.green[1], Theme.colors.green[2], Theme.colors.green[3])
      else
        GameTooltip:AddLine("Ownership not initialized", Theme.colors.orange[1], Theme.colors.orange[2], Theme.colors.orange[3])
      end
      if self.actionable then
        GameTooltip:AddLine("Click to learn this card.", Theme.colors.green[1], Theme.colors.green[2], Theme.colors.green[3])
      end
    end
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function()
    if GameTooltip then
      GameTooltip:Hide()
    end
  end)
  button:SetScript("OnClick", function(self)
    if not self.actionable then
      showError("Only verified unlearned cards can be used through the Ledger.")
      return
    end
    Window:UseCard(self.record)
  end)

  self.cardButtons[index] = button
  return button
end

function Window:UpdateCardButton(button, record, actionAllowed)
  button.record = record
  button.actionable = actionAllowed and true or false
  button.Icon:SetTexture(record.texture or "Interface\\Icons\\INV_Misc_Note_01")
  button.Count:SetText(record.count and record.count > 1 and tostring(record.count) or "")

  local badge = ""
  if record.kind == "lucky" then
    badge = "L"
  elseif record.kind == "golden" then
    badge = "G"
  elseif record.kind == "goldenLucky" then
    badge = "GL"
  end
  button.TypeBadge:SetText(badge)
  if record.group == "golden" then
    button.TypeBadge:SetTextColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3], 1)
  else
    button.TypeBadge:SetTextColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], 1)
  end
  button.Ownership:SetText(record.unknown and "NEW" or (record.ownershipKnown and "" or "?"))

  local r, g, b
  if AP.Database:Get("skillCards.rarityBorders", true) then
    r, g, b = Theme:GetQualityColor(record.quality)
  else
    r, g, b = Theme.colors.border[1], Theme.colors.border[2], Theme.colors.border[3]
  end
  button:SetBackdropBorderColor(r, g, b, 0.95)
end

function Window:UseCard(record)
  if not AP.Database:Get("modules.skillCards", true) then
    showError("The Skill Card Ledger is disabled.")
    return false
  end
  if inCombat() then
    showError("Skill cards cannot be used through the Ledger during combat.")
    return false
  end
  if isFrameShown(_G.MerchantFrame) then
    showError("Close the merchant before learning a skill card; using a bag item there can sell it.")
    return false
  end
  if type(record) ~= "table" or not record.itemID then
    showError("That card is no longer available.")
    return false
  end
  if type(UseContainerItem) ~= "function" then
    showError("The container-use API is unavailable.")
    return false
  end

  local snapshot = Catalog:Scan("card click")
  if not snapshot.scanReady then
    showError(snapshot.scanError or "Inventory could not be verified.")
    self:Refresh(false)
    return false
  end
  if not snapshot.ownershipReady then
    showError(snapshot.ownershipError or "Ownership data is unavailable.")
    self:Refresh(false)
    return false
  end

  local target
  for index = 1, #snapshot.cards do
    local candidate = snapshot.cards[index]
    if candidate.itemID == record.itemID
      and candidate.ownershipKnown
      and candidate.unknown
      and not candidate.locked
    then
      target = candidate
      break
    end
  end
  if not target then
    showError("That unlearned card is no longer in your bags.")
    self:Refresh(false)
    return false
  end

  local used, useError = pcall(UseContainerItem, target.bag, target.slot)
  if not used then
    showError("Ascension rejected the card action: " .. tostring(useError))
    return false
  end

  self.frame.FooterStatus:SetText("Card use requested; inventory will refresh after Ascension processes it.")
  self.frame.FooterStatus:SetTextColor(Theme.colors.green[1], Theme.colors.green[2], Theme.colors.green[3], 1)
  return true
end

function Window:RefreshCardGrid(snapshot)
  local frame = self.frame
  if not frame or self.mode == "compact" then
    return
  end

  if inCombat() then
    self.pendingInventoryRefresh = true
    frame.EmptyState:SetText("IN COMBAT\nCard actions will refresh when combat ends.")
    frame.EmptyState:SetTextColor(Theme.colors.orange[1], Theme.colors.orange[2], Theme.colors.orange[3], 1)
    frame.EmptyState:Show()
    return
  end

  self.pendingInventoryRefresh = false
  local records = snapshot.scanReady and getVisibleRecords(snapshot, self.view) or {}
  local width = math.max(1, (frame.CardScroll:GetWidth() or 1) - 4)
  local usableWidth = math.max(LAYOUT.cardSize, width - 16)
  local columns = math.max(1, math.floor((usableWidth + LAYOUT.cardGap) / (LAYOUT.cardSize + LAYOUT.cardGap)))
  local rowCount = math.ceil(#records / columns)

  for index = 1, #records do
    local button = self:AcquireCardButton(index)
    if button then
      local column = (index - 1) % columns
      local row = math.floor((index - 1) / columns)
      button:ClearAllPoints()
      button:SetPoint(
        "TOPLEFT",
        frame.CardChild,
        "TOPLEFT",
        8 + (column * (LAYOUT.cardSize + LAYOUT.cardGap)),
        -8 - (row * (LAYOUT.cardSize + LAYOUT.cardGap))
      )
      local record = records[index]
      self:UpdateCardButton(
        button,
        record,
        snapshot.ownershipReady and record.ownershipKnown and record.unknown and not record.locked
      )
      button:Show()
    end
  end

  for index = #records + 1, #self.cardButtons do
    self.cardButtons[index]:Hide()
    self.cardButtons[index].record = nil
    self.cardButtons[index].actionable = false
  end

  frame.CardChild:SetWidth(width)
  frame.CardChild:SetHeight(math.max(frame.CardScroll:GetHeight() or 1, 16 + (rowCount * (LAYOUT.cardSize + LAYOUT.cardGap))))

  if not snapshot.scanReady then
    frame.EmptyState:SetText("INVENTORY SCAN FAILED\nCard actions and exchanges remain locked until a full scan succeeds.")
    frame.EmptyState:SetTextColor(Theme.colors.red[1], Theme.colors.red[2], Theme.colors.red[3], 1)
    frame.EmptyState:Show()
  elseif self.view == "unknown" and not snapshot.ownershipReady then
    frame.EmptyState:SetText("OPEN VANITY COLLECTIONS ONCE\nOwnership data is unavailable, so exchange remains safely locked.")
    frame.EmptyState:SetTextColor(Theme.colors.orange[1], Theme.colors.orange[2], Theme.colors.orange[3], 1)
    frame.EmptyState:Show()
  elseif #records == 0 then
    if self.view == "unknown" then
      frame.EmptyState:SetText("COLLECTION CLEAR\nEvery carried card is already learned.")
      frame.EmptyState:SetTextColor(Theme.colors.green[1], Theme.colors.green[2], Theme.colors.green[3], 1)
    else
      frame.EmptyState:SetText("NO CARDS CARRIED\nSkill cards in your bags will appear here.")
      frame.EmptyState:SetTextColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3], 1)
    end
    frame.EmptyState:Show()
  else
    frame.EmptyState:Hide()
  end
end

local function formatExchangeText(state)
  if state.ready then
    return string.format("%s\n%d / 5", string.upper(state.label), state.count)
  end
  if state.code == "not-enough" then
    return string.format("%s\nNEED %d", string.upper(state.label), math.max(0, state.required - state.count))
  end
  if state.code == "protected-unknown" then
    return string.format("%s\nPROTECTED", string.upper(state.label))
  end
  if state.code == "ownership-unavailable" then
    return string.format("%s\nCACHE NEEDED", string.upper(state.label))
  end
  return string.format("%s\nUNAVAILABLE", string.upper(state.label))
end

function Window:ExecuteExchange(kind)
  if not AP.Database:Get("modules.skillCards", true) then
    showError("The Skill Card Ledger is disabled.")
    return false
  end
  if inCombat() then
    showError("Skill-card exchanges are unavailable during combat.")
    return false
  end

  local exchanged, reason = Catalog:Exchange(kind)
  if not exchanged then
    showError(reason)
    self:Refresh(false)
    return false
  end

  self.frame.FooterStatus:SetText("Exchange requested. Review Ascension's native confirmation before committing.")
  self.frame.FooterStatus:SetTextColor(Theme.colors.green[1], Theme.colors.green[2], Theme.colors.green[3], 1)
  return true
end

function Window:RequestExchange(kind)
  if not AP.Database:Get("modules.skillCards", true) then
    showError("The Skill Card Ledger is disabled.")
    return false
  end
  if inCombat() then
    showError("Skill-card exchanges are unavailable during combat.")
    return false
  end

  local snapshot = Catalog:Scan("exchange preview")
  local state = Catalog:GetExchangeState(kind, snapshot)
  if not state.ready then
    showError(state.reason)
    self:Refresh(false)
    return false
  end

  if state.unknownCopies > 0 and not state.protectionEnabled and not self.sessionConfirmedGroups[state.group] then
    if not StaticPopupDialogs or type(StaticPopup_Show) ~= "function" then
      showError("Cannot confirm an at-risk exchange safely; re-enable unlearned-card protection.")
      return false
    end

    StaticPopupDialogs.ASCENSIONPLUS_SKILLCARD_RISK = StaticPopupDialogs.ASCENSIONPLUS_SKILLCARD_RISK or {
      text = "This exchange may consume %d unlearned %s card copies. Continue for this session?",
      button1 = YES or "Yes",
      button2 = CANCEL or "Cancel",
      timeout = 0,
      whileDead = 1,
      hideOnEscape = 1,
      preferredIndex = 3,
      OnAccept = function(dialog)
        local data = dialog and dialog.data
        if not data then
          return
        end
        if not AP.Database:Get("modules.skillCards", true) or inCombat() then
          showError("The exchange was cancelled because the Ledger is disabled or combat began.")
          return
        end
        local latestSnapshot = Catalog:Scan("exchange risk confirmation")
        local latestState = Catalog:GetExchangeState(data.kind, latestSnapshot)
        if not latestState.ready then
          showError(latestState.reason)
          Window:Refresh(false)
          return
        end
        if latestState.unknownCopies ~= data.unknownCopies then
          showError("Your unlearned-card count changed. Review the updated risk and try the exchange again.")
          Window:Refresh(false)
          return
        end
        if Window:ExecuteExchange(data.kind) then
          Window.sessionConfirmedGroups[data.group] = true
        end
      end,
    }
    StaticPopup_Show(
      "ASCENSIONPLUS_SKILLCARD_RISK",
      state.unknownCopies,
      state.group,
      { group = state.group, kind = kind, unknownCopies = state.unknownCopies }
    )
    return true
  end

  return self:ExecuteExchange(kind)
end

function Window:RefreshExchangeDesk(snapshot)
  local frame = self.frame
  if not frame then
    return
  end

  local vendorOpen = Catalog:IsExchangeOpen()
  if self.mode ~= "expanded" or not vendorOpen then
    frame.ExchangeDesk:Hide()
    return
  end

  frame.ExchangeDesk:Show()
  local readyCount = 0
  for index = 1, #KINDS do
    local kind = KINDS[index].id
    local state = Catalog:GetExchangeState(kind, snapshot)
    local button = self.exchangeButtons[index]
    button.state = state
    button:SetText(formatExchangeText(state))
    button:SetScript("OnClick", function()
      self:RequestExchange(kind)
    end)
    button:SetScript("OnEnter", function(control)
      if not AP.Database:Get("skillCards.showTooltips", true) or not GameTooltip then
        return
      end
      GameTooltip:SetOwner(control, "ANCHOR_TOP")
      GameTooltip:AddLine(state.label .. " exchange", 1, 1, 1)
      GameTooltip:AddLine(state.reason or "", Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3], true)
      if state.ready then
        GameTooltip:AddLine("Ascension's native confirmation remains manual.", Theme.colors.green[1], Theme.colors.green[2], Theme.colors.green[3], true)
      end
      GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
      if GameTooltip then
        GameTooltip:Hide()
      end
    end)
    if state.ready then
      button:Enable()
      readyCount = readyCount + 1
    else
      button:Disable()
    end
    Theme:RefreshButton(button)
  end

  if readyCount > 0 then
    frame.ExchangeHint:SetText("Ready exchanges: " .. tostring(readyCount) .. ". Native confirmation stays in control.")
    frame.ExchangeHint:SetTextColor(Theme.colors.green[1], Theme.colors.green[2], Theme.colors.green[3], 1)
  else
    frame.ExchangeHint:SetText("Hover an exchange to see its exact blocking reason.")
    frame.ExchangeHint:SetTextColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3], 1)
  end
end

function Window:LayoutFrame()
  local frame = self.frame
  if not frame then
    return
  end

  local vendorOpen = Catalog:IsExchangeOpen()
  local metrics = self:GetLayoutMetrics(frame:GetWidth(), frame:GetHeight(), vendorOpen, self.mode)
  local cellWidth = math.floor(metrics.innerWidth / 4)

  frame.Summary:ClearAllPoints()
  frame.Summary:SetPoint("TOPLEFT", frame, "TOPLEFT", LAYOUT.inset, -metrics.summaryTop)
  frame.Summary:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -LAYOUT.inset, -metrics.summaryTop)
  frame.Summary:SetHeight(metrics.summaryHeight)

  for index = 1, #frame.SummaryCells do
    local cell = frame.SummaryCells[index]
    cell:ClearAllPoints()
    cell:SetPoint("TOPLEFT", frame.Summary, "TOPLEFT", (index - 1) * cellWidth, 0)
    cell:SetWidth(index == #frame.SummaryCells and metrics.innerWidth - ((index - 1) * cellWidth) or cellWidth)
    cell:SetHeight(metrics.summaryHeight)
  end

  if self.mode == "compact" then
    frame.Filters:Hide()
    frame.CardShell:Hide()
    frame.ExchangeDesk:Hide()
    frame.FooterStatus:ClearAllPoints()
    frame.FooterStatus:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", LAYOUT.inset, metrics.footerBottom)
    frame.FooterStatus:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -LAYOUT.inset, metrics.footerBottom)
    return
  end

  frame.Filters:Show()
  frame.CardShell:Show()
  frame.Filters:ClearAllPoints()
  frame.Filters:SetPoint("TOPLEFT", frame, "TOPLEFT", LAYOUT.inset, -metrics.filterTop)
  frame.Filters:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -LAYOUT.inset, -metrics.filterTop)
  frame.Filters:SetHeight(LAYOUT.filterHeight)

  frame.CardShell:ClearAllPoints()
  frame.CardShell:SetPoint("TOPLEFT", frame, "TOPLEFT", LAYOUT.inset, -metrics.gridTop)
  frame.CardShell:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -LAYOUT.inset, metrics.gridBottom)

  frame.FooterStatus:ClearAllPoints()
  frame.FooterStatus:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", LAYOUT.inset, metrics.footerBottom)
  frame.FooterStatus:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28, metrics.footerBottom)

  frame.ExchangeDesk:ClearAllPoints()
  frame.ExchangeDesk:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", LAYOUT.inset, metrics.exchangeBottom)
  frame.ExchangeDesk:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -LAYOUT.inset, metrics.exchangeBottom)
  frame.ExchangeDesk:SetHeight(LAYOUT.exchangeHeight)

  if metrics.exchangeVisible then
    frame.ExchangeDesk:Show()
  else
    frame.ExchangeDesk:Hide()
  end
  self:LayoutExchangeButtons()
end

function Window:Refresh(rescan)
  if not self.frame then
    return
  end

  local snapshot
  if rescan then
    snapshot = Catalog:Scan("ledger refresh")
  else
    snapshot = getSnapshot()
  end

  for index = 1, #KINDS do
    local kind = KINDS[index]
    local cell = self.frame.SummaryCells[index]
    local count = snapshot.counts[kind.id] or 0
    cell.Count:SetText(snapshot.scanReady and tostring(count) or "--")
    cell.Progress:SetText(snapshot.scanReady and (tostring(count) .. " / 5 TO EXCHANGE") or "SCAN BLOCKED")
    if snapshot.scanReady and count >= 5 then
      cell.Progress:SetTextColor(Theme.colors.green[1], Theme.colors.green[2], Theme.colors.green[3], 1)
    else
      cell.Progress:SetTextColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3], 1)
    end
  end

  local unknownCopies = snapshot.unknown and snapshot.unknown.total.copies or 0
  local unknownUnique = snapshot.unknown and snapshot.unknown.total.uniqueIDs or 0
  local compact = self.mode == "compact"
  self.frame.UnknownButton:SetText(snapshot.scanReady and ("UNLEARNED  " .. tostring(unknownUnique)) or "UNLEARNED  --")
  self.frame.AllButton:SetText(snapshot.scanReady and ("ALL CARRIED  " .. tostring(snapshot.totalCount or 0)) or "ALL CARRIED  --")
  self.frame.UnknownButton.APButtonSelected = self.view == "unknown"
  self.frame.AllButton.APButtonSelected = self.view == "all"

  local combatLocked = inCombat()
  if not combatLocked then
    Theme:RefreshButton(self.frame.UnknownButton)
    Theme:RefreshButton(self.frame.AllButton)
  end

  if combatLocked then
    self.pendingInventoryRefresh = true
    self:SetCombatOverlay(true)
    setStatusText(self.frame, "IN COMBAT", Theme.colors.orange)
    self.frame.FooterStatus:SetText(compact and "Refresh deferred until combat ends." or "Card actions are locked until combat ends.")
    self.frame.FooterStatus:SetTextColor(Theme.colors.orange[1], Theme.colors.orange[2], Theme.colors.orange[3], 1)
  elseif not snapshot.scanReady then
    setStatusText(self.frame, "SCAN BLOCKED", Theme.colors.red)
    self.frame.FooterStatus:SetText(compact and "Inventory scan failed; actions locked." or tostring(snapshot.scanError or "Inventory scan failed; actions are locked."))
    self.frame.FooterStatus:SetTextColor(Theme.colors.red[1], Theme.colors.red[2], Theme.colors.red[3], 1)
  elseif not snapshot.ownershipReady then
    setStatusText(self.frame, "CACHE NEEDED", Theme.colors.orange)
    self.frame.FooterStatus:SetText(compact and "Open Vanity Collections once; exchanges locked." or "Open Vanity Collections once; exchange safety is locked until ownership is known.")
    self.frame.FooterStatus:SetTextColor(Theme.colors.orange[1], Theme.colors.orange[2], Theme.colors.orange[3], 1)
  elseif unknownCopies > 0 then
    setStatusText(self.frame, tostring(unknownUnique) .. " UNLEARNED", Theme.colors.orange)
    if compact then
      self.frame.FooterStatus:SetText(string.format("%d copies | %d unlearned designs", unknownCopies, unknownUnique))
    else
      self.frame.FooterStatus:SetText(string.format("%d unlearned copies across %d unique designs.", unknownCopies, unknownUnique))
    end
    self.frame.FooterStatus:SetTextColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], 1)
  else
    setStatusText(self.frame, "READY", Theme.colors.green)
    self.frame.FooterStatus:SetText(compact and "All carried card designs are learned." or "Every carried card is learned.")
    self.frame.FooterStatus:SetTextColor(Theme.colors.green[1], Theme.colors.green[2], Theme.colors.green[3], 1)
  end

  if combatLocked then
    return
  end

  self:RefreshExchangeDesk(snapshot)
  self:LayoutFrame()
  self:RefreshCardGrid(snapshot)
end

function Window:SetMode(mode)
  mode = mode == "compact" and "compact" or "expanded"
  if inCombat() and self.frame then
    if self.mode ~= mode then
      self.pendingMode = mode
      self.pendingInventoryRefresh = true
      return false
    end
    self.pendingMode = nil
    return true
  end

  self.pendingMode = nil
  self.mode = mode
  local frame = self.frame
  if not frame then
    return true
  end

  if mode == "compact" then
    self:SetCombatOverlay(false)
    frame:SetResizable(false)
    frame.ResizeGrip:Hide()
    frame:SetWidth(LAYOUT.compactWidth)
    frame:SetHeight(LAYOUT.compactHeight)
    frame.Subtitle:Hide()
    for index = 1, #frame.SummaryCells do
      frame.SummaryCells[index].Progress:Hide()
    end
  else
    local state = AP.Database:Get("skillCards.window", {})
    frame:SetResizable(true)
    frame.ResizeGrip:Show()
    frame:SetWidth(AP.Utils.Clamp(tonumber(state.width) or LAYOUT.defaultWidth, LAYOUT.minWidth, LAYOUT.maxWidth))
    frame:SetHeight(AP.Utils.Clamp(tonumber(state.height) or LAYOUT.defaultHeight, LAYOUT.minHeight, LAYOUT.maxHeight))
    frame.Subtitle:Show()
    for index = 1, #frame.SummaryCells do
      frame.SummaryCells[index].Progress:Show()
    end
  end
  self:LayoutFrame()
  return true
end

function Window:Initialize()
  if self.frame then
    return
  end

  local frame = CreateFrame("Frame", "AscensionPlusSkillCardLedger", UIParent)
  frame:SetFrameStrata("DIALOG")
  frame:SetToplevel(true)
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:SetResizable(true)
  frame:SetClampedToScreen(true)
  frame:SetMinResize(LAYOUT.minWidth, LAYOUT.minHeight)
  if frame.SetMaxResize then
    frame:SetMaxResize(LAYOUT.maxWidth, LAYOUT.maxHeight)
  end
  Theme:ApplyBackdrop(frame, Theme.colors.background, Theme.colors.border)

  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(self)
    if inCombat() then
      showError("The Skill Card Ledger cannot move during combat.")
      return
    end
    self.APMoving = true
    self:StartMoving()
  end)
  frame:SetScript("OnDragStop", function(self)
    if not self.APMoving then
      return
    end
    self.APMoving = nil
    self:StopMovingOrSizing()
    saveWindowState(self)
  end)

  local escapeProxy = CreateFrame("Frame", "AscensionPlusSkillCardEscapeProxy", UIParent)
  escapeProxy:SetWidth(1)
  escapeProxy:SetHeight(1)
  escapeProxy:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -2, 2)
  escapeProxy:SetScript("OnHide", function(self)
    if not self.APSuppressed and Window.frame and Window.frame:IsShown() then
      Window:RequestHide(true)
    end
  end)
  escapeProxy:Hide()
  self.escapeProxy = escapeProxy
  if UISpecialFrames then
    table.insert(UISpecialFrames, "AscensionPlusSkillCardEscapeProxy")
  end

  frame.Header = frame:CreateTexture(nil, "BACKGROUND")
  frame.Header:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
  frame.Header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
  frame.Header:SetHeight(LAYOUT.headerHeight)
  paint(frame.Header, Theme.colors.titlebar)

  frame.HeaderAccent = frame:CreateTexture(nil, "ARTWORK")
  frame.HeaderAccent:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
  frame.HeaderAccent:SetPoint("BOTTOMLEFT", frame.Header, "BOTTOMLEFT", 1, 0)
  frame.HeaderAccent:SetWidth(3)
  paint(frame.HeaderAccent, Theme.colors.gold)

  frame.Title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  frame.Title:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -10)
  frame.Title:SetText("Skill Cards")
  frame.Title:SetTextColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], 1)
  Theme:TrySetTitleFont(frame.Title, 19)

  frame.Subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  frame.Subtitle:SetPoint("LEFT", frame.Title, "RIGHT", 9, -1)
  frame.Subtitle:SetText("LEDGER")
  frame.Subtitle:SetTextColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3], 1)

  frame.CloseButton = CreateFrame("Button", nil, frame)
  frame.CloseButton:SetWidth(24)
  frame.CloseButton:SetHeight(24)
  frame.CloseButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -11)
  Theme:SkinCloseButton(frame.CloseButton, "x")
  frame.CloseButton:SetScript("OnClick", function()
    Window:RequestHide(false)
  end)

  frame.SettingsButton = CreateFrame("Button", nil, frame)
  frame.SettingsButton:SetWidth(66)
  frame.SettingsButton:SetHeight(22)
  frame.SettingsButton:SetPoint("RIGHT", frame.CloseButton, "LEFT", -8, 0)
  frame.SettingsButton:SetText("SETTINGS")
  Theme:SkinButton(frame.SettingsButton)
  frame.SettingsButton:SetScript("OnClick", function()
    if AP.OpenConfig then
      AP:OpenConfig("skillcards.behavior")
    end
  end)

  frame.StatusBadge = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  frame.StatusBadge:SetPoint("RIGHT", frame.SettingsButton, "LEFT", -12, 0)
  frame.StatusBadge:SetText("READY")

  frame.Summary = CreateFrame("Frame", nil, frame)
  Theme:ApplyBackdrop(frame.Summary, Theme.colors.sidebar or Theme.colors.inset, Theme.colors.neutralLine or Theme.colors.line)
  frame.SummaryCells = {}
  for index = 1, #KINDS do
    local cell = CreateFrame("Frame", nil, frame.Summary)
    cell.Label = cell:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    cell.Label:SetPoint("TOP", cell, "TOP", 0, -8)
    cell.Label:SetText(KINDS[index].label)
    cell.Label:SetTextColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3], 1)
    cell.Count = cell:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    cell.Count:SetPoint("TOP", cell.Label, "BOTTOM", 0, -1)
    cell.Count:SetText("0")
    cell.Count:SetTextColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], 1)
    cell.Progress = cell:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    cell.Progress:SetPoint("BOTTOM", cell, "BOTTOM", 0, 5)
    cell.Progress:SetText("0 / 5 TO EXCHANGE")
    if index > 1 then
      cell.Divider = cell:CreateTexture(nil, "ARTWORK")
      cell.Divider:SetPoint("TOPLEFT", cell, "TOPLEFT", 0, -7)
      cell.Divider:SetPoint("BOTTOMLEFT", cell, "BOTTOMLEFT", 0, 7)
      cell.Divider:SetWidth(1)
      paint(cell.Divider, Theme.colors.neutralLine or Theme.colors.line)
    end
    frame.SummaryCells[index] = cell
  end

  frame.Filters = CreateFrame("Frame", nil, frame)
  frame.UnknownButton = CreateFrame("Button", nil, frame.Filters)
  frame.UnknownButton:SetWidth(142)
  frame.UnknownButton:SetHeight(LAYOUT.filterHeight)
  frame.UnknownButton:SetPoint("LEFT", frame.Filters, "LEFT", 0, 0)
  frame.UnknownButton:SetText("UNLEARNED  0")
  Theme:SkinButton(frame.UnknownButton)
  frame.UnknownButton:SetScript("OnClick", function()
    self.view = "unknown"
    self:Refresh(false)
  end)

  frame.AllButton = CreateFrame("Button", nil, frame.Filters)
  frame.AllButton:SetWidth(142)
  frame.AllButton:SetHeight(LAYOUT.filterHeight)
  frame.AllButton:SetPoint("LEFT", frame.UnknownButton, "RIGHT", 6, 0)
  frame.AllButton:SetText("ALL CARRIED  0")
  Theme:SkinButton(frame.AllButton)
  frame.AllButton:SetScript("OnClick", function()
    self.view = "all"
    self:Refresh(false)
  end)

  frame.RefreshButton = CreateFrame("Button", nil, frame.Filters)
  frame.RefreshButton:SetWidth(82)
  frame.RefreshButton:SetHeight(LAYOUT.filterHeight)
  frame.RefreshButton:SetPoint("RIGHT", frame.Filters, "RIGHT", 0, 0)
  frame.RefreshButton:SetText("REFRESH")
  Theme:SkinButton(frame.RefreshButton)
  frame.RefreshButton:SetScript("OnClick", function()
    self:Refresh(true)
  end)

  frame.CardShell = CreateFrame("Frame", nil, frame)
  Theme:ApplyBackdrop(frame.CardShell, Theme.colors.inset, Theme.colors.neutralLine or Theme.colors.line)
  frame.CardScroll = CreateFrame("ScrollFrame", "AscensionPlusSkillCardScroll", frame.CardShell, "UIPanelScrollFrameTemplate")
  frame.CardScroll:SetPoint("TOPLEFT", frame.CardShell, "TOPLEFT", 2, -2)
  frame.CardScroll:SetPoint("BOTTOMRIGHT", frame.CardShell, "BOTTOMRIGHT", -20, 2)
  Theme:SkinScrollFrame(frame.CardScroll)
  frame.CardScroll:EnableMouseWheel(true)
  frame.CardScroll:SetScript("OnMouseWheel", function(scroll, delta)
    local range = scroll:GetVerticalScrollRange() or 0
    scroll:SetVerticalScroll(AP.Utils.Clamp((scroll:GetVerticalScroll() or 0) - (delta * 48), 0, range))
  end)
  frame.CardChild = CreateFrame("Frame", nil, frame.CardScroll)
  frame.CardChild:SetWidth(1)
  frame.CardChild:SetHeight(1)
  frame.CardScroll:SetScrollChild(frame.CardChild)

  frame.CombatOverlay = CreateFrame("Frame", "AscensionPlusSkillCardCombatOverlay", UIParent)
  frame.CombatOverlay:SetPoint("TOPLEFT", frame.CardShell, "TOPLEFT", 0, 0)
  frame.CombatOverlay:SetPoint("BOTTOMRIGHT", frame.CardShell, "BOTTOMRIGHT", 0, 0)
  frame.CombatOverlay:SetFrameStrata("DIALOG")
  if frame.CombatOverlay.SetFrameLevel then
    frame.CombatOverlay:SetFrameLevel(frame:GetFrameLevel() + 50)
  end
  frame.CombatOverlay:EnableMouse(true)
  Theme:ApplyBackdrop(frame.CombatOverlay, { 0.03, 0.04, 0.06, 0.96 }, Theme.colors.orange)
  frame.CombatOverlay.Text = frame.CombatOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  frame.CombatOverlay.Text:SetPoint("CENTER", frame.CombatOverlay, "CENTER", 0, 0)
  frame.CombatOverlay.Text:SetWidth(340)
  frame.CombatOverlay.Text:SetJustifyH("CENTER")
  frame.CombatOverlay.Text:SetText("IN COMBAT\nCard actions are locked until the inventory refresh completes.")
  frame.CombatOverlay.Text:SetTextColor(Theme.colors.orange[1], Theme.colors.orange[2], Theme.colors.orange[3], 1)
  frame.CombatOverlay:Hide()

  frame.EmptyState = frame.CardShell:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  frame.EmptyState:SetPoint("CENTER", frame.CardShell, "CENTER", 0, 0)
  frame.EmptyState:SetWidth(360)
  frame.EmptyState:SetJustifyH("CENTER")
  frame.EmptyState:SetText("NO CARDS CARRIED")

  frame.ExchangeDesk = CreateFrame("Frame", nil, frame)
  Theme:ApplyBackdrop(frame.ExchangeDesk, Theme.colors.sidebar or Theme.colors.inset, Theme.colors.neutralLine or Theme.colors.line)
  frame.ExchangeTitle = frame.ExchangeDesk:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  frame.ExchangeTitle:SetPoint("TOPLEFT", frame.ExchangeDesk, "TOPLEFT", 8, -6)
  frame.ExchangeTitle:SetText("EXCHANGE DESK")
  frame.ExchangeTitle:SetTextColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3], 1)
  frame.ExchangeHint = frame.ExchangeDesk:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  frame.ExchangeHint:SetPoint("TOPRIGHT", frame.ExchangeDesk, "TOPRIGHT", -8, -7)
  frame.ExchangeHint:SetPoint("LEFT", frame.ExchangeTitle, "RIGHT", 12, 0)
  frame.ExchangeHint:SetJustifyH("RIGHT")

  for index = 1, #KINDS do
    local button = CreateFrame("Button", nil, frame.ExchangeDesk)
    button:SetHeight(44)
    button:SetText(KINDS[index].label)
    Theme:SkinButton(button)
    self.exchangeButtons[index] = button
  end

  frame.FooterStatus = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  frame.FooterStatus:SetJustifyH("LEFT")
  frame.FooterStatus:SetText("Waiting for inventory scan.")

  frame.ResizeGrip = CreateFrame("Button", nil, frame)
  frame.ResizeGrip:SetWidth(16)
  frame.ResizeGrip:SetHeight(16)
  frame.ResizeGrip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
  Theme:SkinResizeGrip(frame.ResizeGrip)
  frame.ResizeGrip:SetScript("OnMouseDown", function()
    if inCombat() then
      showError("The Skill Card Ledger cannot resize during combat.")
      return
    end
    frame.ResizeGrip.APGripPressed = true
    frame.ResizeGrip.APResizing = true
    Theme:RefreshResizeGrip(frame.ResizeGrip)
    frame:StartSizing("BOTTOMRIGHT")
  end)
  frame.ResizeGrip:SetScript("OnMouseUp", function()
    if not frame.ResizeGrip.APResizing then
      return
    end
    frame.ResizeGrip.APResizing = nil
    frame.ResizeGrip.APGripPressed = false
    Theme:RefreshResizeGrip(frame.ResizeGrip)
    frame:StopMovingOrSizing()
    saveWindowState(frame)
    self:Refresh(false)
  end)

  frame:SetScript("OnSizeChanged", function()
    if not inCombat() then
      self:LayoutFrame()
    end
  end)
  frame:SetScript("OnShow", function()
    if Window.escapeProxy and not Window.escapeProxy:IsShown() then
      Window.escapeProxy:Show()
    end
    Theme:FadeIn(frame, 0.12)
  end)
  frame:SetScript("OnHide", function()
    Window:SetCombatOverlay(false)
    if Window.escapeProxy and Window.escapeProxy:IsShown() then
      Window.escapeProxy.APSuppressed = true
      Window.escapeProxy:Hide()
      Window.escapeProxy.APSuppressed = nil
    end
    if GameTooltip then
      GameTooltip:Hide()
    end
  end)

  self.frame = frame
  applyWindowAnchor(frame)
  self:SetMode("expanded")
  frame:Hide()
end

function Window:LayoutExchangeButtons()
  local desk = self.frame and self.frame.ExchangeDesk
  if not desk then
    return
  end
  local width = tonumber(desk:GetWidth()) or 0
  if width < 120 then
    width = math.max(120, (self.frame:GetWidth() or LAYOUT.defaultWidth) - (LAYOUT.inset * 2))
  end
  local gap = 6
  local buttonWidth = math.max(22, math.floor((width - 16 - (gap * 3)) / 4))
  for index = 1, #self.exchangeButtons do
    local button = self.exchangeButtons[index]
    button:ClearAllPoints()
    button:SetPoint("BOTTOMLEFT", desk, "BOTTOMLEFT", 8 + ((index - 1) * (buttonWidth + gap)), 7)
    button:SetWidth(buttonWidth)
  end
end

function Window:Open(mode)
  if not AP.Database:Get("modules.skillCards", true) then
    AP:Print("The Skill Card Ledger is disabled. Enable it under Skill Cards in configuration.")
    if AP.OpenConfig then
      AP:OpenConfig("skillcards")
    end
    return false
  end
  self:Initialize()
  mode = mode == "compact" and "compact" or "expanded"
  if inCombat() then
    if not self.frame:IsShown() then
      self.pendingVisibility = "show"
      self.pendingMode = mode
      self.pendingInventoryRefresh = true
      showError("The Skill Card Ledger will open when combat ends.")
      return false
    end
    self.pendingVisibility = nil
    self:SetMode(mode)
    self:Refresh(false)
    return self.mode == mode
  end

  self.pendingVisibility = nil
  applyWindowAnchor(self.frame)
  self:SetMode(mode)
  self.frame:Show()
  self:Refresh(true)
  self:LayoutExchangeButtons()
  return true
end

function Window:RequestHide(silent)
  if not self.frame then
    self.pendingVisibility = nil
    self.pendingMode = nil
    return true
  end

  if not self.frame:IsShown() then
    self.pendingVisibility = nil
    self.pendingMode = nil
    return true
  end

  if inCombat() then
    self.pendingVisibility = "hide"
    if not silent then
      showError("The Skill Card Ledger will close when combat ends.")
    end
    return false
  end

  self.pendingVisibility = nil
  self.frame:Hide()
  return true
end

function Window:SetCombatOverlay(shown)
  local frame = self.frame
  local overlay = frame and frame.CombatOverlay
  if not overlay then
    return
  end

  if shown and frame:IsShown() and self.mode == "expanded" then
    overlay:Show()
  else
    overlay:Hide()
  end
end

function Window:Toggle(mode)
  if not AP.Database:Get("modules.skillCards", true) then
    return self:Open(mode)
  end
  self:Initialize()
  if self.frame:IsShown() then
    self:RequestHide(false)
  else
    self:Open(mode)
  end
end

function Window:ShowToast(message)
  if not self.toast then
    local toast = CreateFrame("Button", "AscensionPlusSkillCardToast", UIParent)
    toast:SetFrameStrata("DIALOG")
    toast:SetWidth(320)
    toast:SetHeight(54)
    toast:SetPoint("TOP", UIParent, "TOP", 0, -150)
    Theme:ApplyBackdrop(toast, Theme.colors.panel, Theme.colors.border)
    toast.Icon = toast:CreateTexture(nil, "ARTWORK")
    toast.Icon:SetWidth(34)
    toast.Icon:SetHeight(34)
    toast.Icon:SetPoint("LEFT", toast, "LEFT", 10, 0)
    toast.Icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
    toast.Title = toast:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    toast.Title:SetPoint("TOPLEFT", toast.Icon, "TOPRIGHT", 10, -1)
    toast.Title:SetText("SKILL CARD LEDGER")
    toast.Title:SetTextColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3], 1)
    toast.Message = toast:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    toast.Message:SetPoint("TOPLEFT", toast.Title, "BOTTOMLEFT", 0, -4)
    toast.Message:SetPoint("RIGHT", toast, "RIGHT", -10, 0)
    toast.Message:SetJustifyH("LEFT")
    toast:SetScript("OnClick", function()
      toast:Hide()
      Window:Open("expanded")
    end)
    toast:SetScript("OnEnter", function(self)
      self.expiresAt = nil
    end)
    toast:SetScript("OnLeave", function(self)
      self.expiresAt = (GetTime and GetTime() or 0) + 4
    end)
    toast:SetScript("OnUpdate", function(self)
      if self.expiresAt and GetTime and GetTime() >= self.expiresAt then
        self:Hide()
      end
    end)
    toast:Hide()
    self.toast = toast
  end

  self.toast.Message:SetText(message or "New skill cards found. Click to open.")
  self.toast.expiresAt = (GetTime and GetTime() or 0) + 5
  self.toast:Show()
  Theme:FadeIn(self.toast, 0.12)
end

function Window:OnCombatStarted()
  self.pendingInventoryRefresh = true
  if type(StaticPopup_Hide) == "function" then
    StaticPopup_Hide("ASCENSIONPLUS_SKILLCARD_RISK")
  end
  if not self.frame or not self.frame:IsShown() then
    return
  end

  self:SetCombatOverlay(true)
  setStatusText(self.frame, "IN COMBAT", Theme.colors.orange)
  self.frame.FooterStatus:SetText(self.mode == "compact"
    and "Refresh deferred until combat ends."
    or "Card actions and exchanges are locked until combat ends.")
  self.frame.FooterStatus:SetTextColor(Theme.colors.orange[1], Theme.colors.orange[2], Theme.colors.orange[3], 1)
  for index = 1, #self.exchangeButtons do
    local button = self.exchangeButtons[index]
    button:Disable()
    button:SetText(KINDS[index].label .. "\nIN COMBAT")
    Theme:RefreshButton(button)
  end
  if GameTooltip then
    GameTooltip:Hide()
  end
end

function Window:OnCombatEnded()
  local pendingVisibility = self.pendingVisibility
  local pendingMode = self.pendingMode
  local pendingResetPosition = self.pendingResetPosition
  local pendingRefresh = self.pendingInventoryRefresh

  self.pendingVisibility = nil
  self.pendingMode = nil
  self.pendingResetPosition = false
  self.pendingInventoryRefresh = false

  if not self.frame then
    return
  end

  if pendingResetPosition then
    applyWindowAnchor(self.frame)
  end
  if pendingMode then
    self:SetMode(pendingMode)
  end

  local moduleEnabled = AP.Database:Get("modules.skillCards", true)
  if pendingVisibility == "hide" or not moduleEnabled then
    self:SetCombatOverlay(false)
    self.frame:Hide()
    return
  elseif pendingVisibility == "show" then
    applyWindowAnchor(self.frame)
    self.frame:Show()
  end

  if moduleEnabled and (pendingRefresh or pendingVisibility == "show" or pendingMode) then
    self:Refresh(true)
  end
  self:SetCombatOverlay(false)
end

function Window:ResetPosition()
  AP.Database:Set("skillCards.window", AP.Utils.DeepCopy(AP.defaults.skillCards.window))
  if self.frame then
    if inCombat() then
      self.pendingResetPosition = true
      self.pendingMode = "expanded"
      self.pendingInventoryRefresh = true
      showError("The Skill Card Ledger will reset when combat ends.")
      return false
    end
    applyWindowAnchor(self.frame)
    self:SetMode("expanded")
  end
  return true
end

function Window:HandleSlash(arguments)
  local command = string.lower(trim(arguments))
  if command == "config" or command == "settings" or command == "options" then
    if AP.OpenConfig then
      AP:OpenConfig("skillcards.behavior")
    end
  elseif not AP.Database:Get("modules.skillCards", true) then
    self:Open("expanded")
  elseif command == "refresh" or command == "scan" then
    self:Initialize()
    self:Refresh(true)
    if not self.frame:IsShown() then
      self:Open("expanded")
    end
  elseif command == "compact" then
    self:Open("compact")
  else
    self:Toggle("expanded")
  end
end
