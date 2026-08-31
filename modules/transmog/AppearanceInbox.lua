local _, AP = ...
AP = AP or _G.Levo or _G.WotLKPlus or _G.AscensionPlus

local Theme = AP.UI.Theme
local Collector = AP.TransmogAutoCollect
local Catalog = AP.TransmogAppearanceCatalog

if not Theme or not Collector or not Catalog then
  return
end

local Inbox = {
  mode = "needs",
  rows = {},
  refreshAt = nil,
  refreshReason = nil,
  LAYOUT = {
    width = 720,
    height = 540,
    gutter = 6,
    horizontalInset = 16,
    tabsTop = 64,
    summaryTop = 102,
    summaryHeight = 38,
    listTop = 148,
    listBottom = 56,
    footerBottom = 14,
    rowHeight = 52,
    rowGap = 3,
  },
}

AP.TransmogAppearanceInbox = Inbox

local function setTextColor(fontString, color)
  if fontString and color then
    fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
  end
end

local function getStatusColor(status)
  return Theme.colors[status.color] or Theme.colors.text
end

local function getQualityColor(quality)
  local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[tonumber(quality)]
  if color then
    return { color.r, color.g, color.b, 1 }
  end
  return Theme.colors.text
end

local function createButton(parent, text, width)
  local button = CreateFrame("Button", nil, parent)
  button:SetWidth(width)
  button:SetHeight(24)
  button:SetText(text)
  Theme:SkinButton(button)
  return button
end

local function appendSpecialFrame(frameName)
  UISpecialFrames = UISpecialFrames or {}
  for index = 1, #UISpecialFrames do
    if UISpecialFrames[index] == frameName then
      return
    end
  end
  UISpecialFrames[#UISpecialFrames + 1] = frameName
end

function Inbox:CreateTab(parent, label, mode, previous)
  local tab = createButton(parent, label, 78)
  if previous then
    tab:SetPoint("LEFT", previous, "RIGHT", 6, 0)
  else
    tab:SetPoint("TOPLEFT", parent, "TOPLEFT", self.LAYOUT.horizontalInset, -self.LAYOUT.tabsTop)
  end
  tab:SetScript("OnClick", function()
    Inbox:SetMode(mode)
  end)
  tab.Mode = mode
  return tab
end

function Inbox:CreateRow(parent, index)
  local row = CreateFrame("Button", nil, parent)
  row:SetHeight(self.LAYOUT.rowHeight)
  row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -((index - 1) * (self.LAYOUT.rowHeight + self.LAYOUT.rowGap)))
  row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -((index - 1) * (self.LAYOUT.rowHeight + self.LAYOUT.rowGap)))
  Theme:SkinResultRow(row)

  row.IconShell = CreateFrame("Frame", nil, row)
  row.IconShell:SetWidth(36)
  row.IconShell:SetHeight(36)
  row.IconShell:SetPoint("LEFT", row, "LEFT", 7, 0)
  Theme:ApplyBackdrop(row.IconShell, Theme.colors.inset, { Theme.colors.border[1], Theme.colors.border[2], Theme.colors.border[3], 0.34 })

  row.Icon = row.IconShell:CreateTexture(nil, "ARTWORK")
  row.Icon:SetPoint("TOPLEFT", row.IconShell, "TOPLEFT", 2, -2)
  row.Icon:SetPoint("BOTTOMRIGHT", row.IconShell, "BOTTOMRIGHT", -2, 2)
  row.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  row.Name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.Name:SetPoint("TOPLEFT", row, "TOPLEFT", 52, -7)
  row.Name:SetPoint("TOPRIGHT", row, "TOPRIGHT", -150, -7)
  row.Name:SetJustifyH("LEFT")
  row.Name:SetHeight(15)
  row.Name:SetShadowColor(0, 0, 0, 1)
  row.Name:SetShadowOffset(1, -1)

  row.Detail = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.Detail:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 52, 7)
  row.Detail:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -150, 7)
  row.Detail:SetJustifyH("LEFT")
  row.Detail:SetHeight(14)
  setTextColor(row.Detail, Theme.colors.muted)

  row.Status = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  row.Status:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, -7)
  row.Status:SetWidth(134)
  row.Status:SetHeight(14)
  row.Status:SetJustifyH("RIGHT")
  row.Status:SetShadowColor(0, 0, 0, 1)
  row.Status:SetShadowOffset(1, -1)

  row.Secondary = createButton(row, "BLOCK", 54)
  row.Secondary:SetHeight(20)
  row.Secondary:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -7, 6)
  row.Secondary:SetScript("OnClick", function(self)
    Inbox:HandleSecondary(self:GetParent().Entry)
  end)

  row.Primary = createButton(row, "QUEUE", 72)
  row.Primary:SetHeight(20)
  row.Primary:SetPoint("RIGHT", row.Secondary, "LEFT", -6, 0)
  row.Primary:SetScript("OnClick", function(self)
    Inbox:HandlePrimary(self:GetParent().Entry)
  end)

  row:SetScript("OnEnter", function(self)
    Inbox:ShowEntryTooltip(self.Entry)
  end)
  row:SetScript("OnLeave", function()
    if GameTooltip then
      GameTooltip:Hide()
    end
  end)

  self.rows[index] = row
  return row
end

function Inbox:EnsureFrame()
  if self.frame then
    return self.frame
  end

  local layout = self.LAYOUT
  local frame = CreateFrame("Frame", "LevoAppearanceInbox", UIParent)
  frame:SetWidth(layout.width)
  frame:SetHeight(layout.height)
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  frame:SetFrameStrata("DIALOG")
  frame:SetToplevel(true)
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  Theme:ApplyBackdrop(frame, Theme.colors.background, Theme.colors.border)
  frame:Hide()

  frame.Header = CreateFrame("Frame", nil, frame)
  frame.Header:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
  frame.Header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
  frame.Header:SetHeight(49)
  Theme:ApplyBackdrop(frame.Header, Theme.colors.titlebar, { Theme.colors.border[1], Theme.colors.border[2], Theme.colors.border[3], 0.25 })
  frame.Header:EnableMouse(true)
  frame.Header:RegisterForDrag("LeftButton")
  frame.Header:SetScript("OnDragStart", function()
    frame:StartMoving()
  end)
  frame.Header:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
  end)

  frame.Title = frame.Header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  frame.Title:SetPoint("TOPLEFT", frame.Header, "TOPLEFT", 16, -9)
  frame.Title:SetText("APPEARANCE INBOX")
  Theme:TrySetTitleFont(frame.Title, 19)
  setTextColor(frame.Title, Theme.colors.gold)
  frame.Title:SetShadowColor(0, 0, 0, 1)
  frame.Title:SetShadowOffset(1, -1)

  frame.Subtitle = frame.Header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.Subtitle:SetPoint("TOPLEFT", frame.Title, "BOTTOMLEFT", 1, -2)
  frame.Subtitle:SetText("Ascension wardrobe state from the live collection API")
  setTextColor(frame.Subtitle, Theme.colors.muted)

  frame.CloseButton = CreateFrame("Button", nil, frame.Header)
  frame.CloseButton:SetWidth(28)
  frame.CloseButton:SetHeight(28)
  frame.CloseButton:SetPoint("TOPRIGHT", frame.Header, "TOPRIGHT", -9, -7)
  Theme:SkinCloseButton(frame.CloseButton, "x")
  frame.CloseButton:SetScript("OnClick", function()
    frame:Hide()
  end)

  frame.NeedsTab = self:CreateTab(frame, "NEEDS", "needs")
  frame.AllTab = self:CreateTab(frame, "ALL", "all", frame.NeedsTab)
  frame.ApiTab = self:CreateTab(frame, "API", "api", frame.AllTab)

  frame.ConfigButton = createButton(frame, "CONFIG", 76)
  frame.ConfigButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -layout.horizontalInset, -layout.tabsTop)
  frame.ConfigButton:SetScript("OnClick", function()
    AP:OpenConfig("transmog.appearance-inbox")
  end)

  frame.RefreshButton = createButton(frame, "REFRESH", 78)
  frame.RefreshButton:SetPoint("RIGHT", frame.ConfigButton, "LEFT", -6, 0)
  frame.RefreshButton:SetScript("OnClick", function()
    Inbox:Refresh("manual refresh")
  end)

  frame.SummaryShell = CreateFrame("Frame", nil, frame)
  frame.SummaryShell:SetPoint("TOPLEFT", frame, "TOPLEFT", layout.horizontalInset, -layout.summaryTop)
  frame.SummaryShell:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -layout.horizontalInset, -layout.summaryTop)
  frame.SummaryShell:SetHeight(layout.summaryHeight)
  Theme:ApplyBackdrop(frame.SummaryShell, Theme.colors.inset, { Theme.colors.border[1], Theme.colors.border[2], Theme.colors.border[3], 0.28 })

  frame.Summary = frame.SummaryShell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.Summary:SetPoint("LEFT", frame.SummaryShell, "LEFT", 10, 0)
  frame.Summary:SetPoint("RIGHT", frame.SummaryShell, "RIGHT", -10, 0)
  frame.Summary:SetJustifyH("LEFT")
  frame.Summary:SetHeight(30)
  setTextColor(frame.Summary, Theme.colors.text)

  frame.ListShell = CreateFrame("Frame", nil, frame)
  frame.ListShell:SetPoint("TOPLEFT", frame, "TOPLEFT", layout.horizontalInset, -layout.listTop)
  frame.ListShell:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -layout.horizontalInset, layout.listBottom)
  Theme:ApplyBackdrop(frame.ListShell, Theme.colors.inset, { Theme.colors.border[1], Theme.colors.border[2], Theme.colors.border[3], 0.35 })

  frame.Scroll = CreateFrame("ScrollFrame", "LevoAppearanceInboxScroll", frame.ListShell, "UIPanelScrollFrameTemplate")
  frame.Scroll:SetPoint("TOPLEFT", frame.ListShell, "TOPLEFT", 6, -6)
  frame.Scroll:SetPoint("BOTTOMRIGHT", frame.ListShell, "BOTTOMRIGHT", -24, 6)
  Theme:SkinScrollFrame(frame.Scroll)

  frame.Child = CreateFrame("Frame", nil, frame.Scroll)
  frame.Child:SetWidth(640)
  frame.Child:SetHeight(1)
  frame.Scroll:SetScrollChild(frame.Child)

  frame.Empty = frame.ListShell:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  frame.Empty:SetPoint("CENTER", frame.ListShell, "CENTER", 0, 0)
  frame.Empty:SetWidth(520)
  frame.Empty:SetJustifyH("CENTER")
  setTextColor(frame.Empty, Theme.colors.muted)
  frame.Empty:Hide()

  frame.Footer = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.Footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", layout.horizontalInset, layout.footerBottom)
  frame.Footer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -layout.horizontalInset, layout.footerBottom)
  frame.Footer:SetJustifyH("LEFT")
  frame.Footer:SetText("Manual validation only: MEMORIZE submits one item once and never confirms the binding popup for you.")
  setTextColor(frame.Footer, Theme.colors.muted)

  frame:SetScript("OnShow", function()
    Inbox:Refresh("menu opened")
  end)
  frame:SetScript("OnUpdate", function()
    if Inbox.refreshAt and GetTime() >= Inbox.refreshAt then
      local reason = Inbox.refreshReason or "event refresh"
      Inbox.refreshAt = nil
      Inbox.refreshReason = nil
      Inbox:Refresh(reason)
    end
  end)
  frame:SetScript("OnSizeChanged", function()
    local width = frame.Scroll:GetWidth() or 0
    frame.Child:SetWidth(math.max(1, width))
  end)

  self.frame = frame
  appendSpecialFrame(frame:GetName())
  return frame
end

function Inbox:UpdateTabs()
  if not self.frame then
    return
  end
  local tabs = { self.frame.NeedsTab, self.frame.AllTab, self.frame.ApiTab }
  for index = 1, #tabs do
    local tab = tabs[index]
    tab.APButtonPressed = tab.Mode == self.mode
    Theme:RefreshButton(tab)
  end
end

function Inbox:SetMode(mode)
  if mode ~= "needs" and mode ~= "all" and mode ~= "api" then
    mode = "needs"
  end
  self.mode = mode
  self:UpdateTabs()
  if not Catalog:GetSnapshot() and mode ~= "api" then
    self:Refresh("view changed")
  else
    self:Render()
  end
end

function Inbox:GetDisplayEntries(snapshot)
  if self.mode == "api" then
    local diagnostics = Catalog:GetApiDiagnostics()
    return diagnostics
  elseif self.mode == "all" then
    return snapshot and snapshot.entries or {}
  end
  return Catalog:GetNeedsEntries(snapshot)
end

function Inbox:AcquireRow(index)
  return self.rows[index] or self:CreateRow(self.frame.Child, index)
end

function Inbox:ConfigureApiRow(row, diagnostic)
  row.Entry = diagnostic
  row.EntryKind = "api"
  row.IconShell:Hide()
  row.Name:ClearAllPoints()
  row.Name:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -7)
  row.Name:SetPoint("TOPRIGHT", row, "TOPRIGHT", -150, -7)
  row.Name:SetText(diagnostic.name)
  setTextColor(row.Name, Theme.colors.text)
  row.Detail:ClearAllPoints()
  row.Detail:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 10, 7)
  row.Detail:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -150, 7)
  row.Detail:SetText(diagnostic.detail or "")
  row.Status:SetText(diagnostic.ready and (diagnostic.informational and "LISTENING" or "READY") or "MISSING")
  setTextColor(row.Status, diagnostic.ready and Theme.colors.green or Theme.colors.red)
  row.Primary:Hide()
  row.Secondary:Hide()
  row:Show()
end

function Inbox:ConfigureItemRow(row, entry)
  local status = Catalog:GetStatus(entry.statusCode)
  row.Entry = entry
  row.EntryKind = "item"
  row.IconShell:Show()
  row.Icon:SetTexture(entry.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
  row.Name:ClearAllPoints()
  row.Name:SetPoint("TOPLEFT", row, "TOPLEFT", 52, -7)
  row.Name:SetPoint("TOPRIGHT", row, "TOPRIGHT", -150, -7)
  row.Name:SetText(entry.name or ("Item #" .. tostring(entry.itemID or "?")))
  setTextColor(row.Name, getQualityColor(entry.quality))
  row.Detail:ClearAllPoints()
  row.Detail:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 52, 7)
  row.Detail:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -150, 7)
  row.Detail:SetText(string.format(
    "Appearance #%s | %s | Bag %s, Slot %s%s",
    tostring(entry.appearanceID or "?"),
    Catalog:GetQualityName(entry.quality),
    tostring(entry.bag),
    tostring(entry.slot),
    (entry.copies or 1) > 1 and (" | " .. tostring(entry.copies) .. " copies") or ""
  ))
  row.Status:SetText(status.title)
  setTextColor(row.Status, getStatusColor(status))

  row.Primary:Enable()
  row.Primary:Show()
  row.Secondary:Show()
  row.Secondary:SetText("BLOCK")

  if entry.statusCode == "ready"
      or entry.statusCode == "auto-paused"
      or entry.statusCode == "rule-ask"
      or entry.statusCode == "rule-never"
      or entry.statusCode == "type-disabled" then
    row.Primary:SetText("MEMORIZE")
  elseif entry.statusCode == "queued" then
    row.Primary:SetText("WAITING")
    row.Primary:Disable()
  elseif entry.statusCode == "blacklisted" then
    row.Primary:SetText("UNBLOCK")
    row.Secondary:Hide()
  elseif entry.statusCode == "collected" then
    row.Primary:Hide()
    row.Secondary:Hide()
  else
    row.Primary:SetText("REFRESH")
  end
  Theme:RefreshButton(row.Primary)
  Theme:RefreshButton(row.Secondary)
  row:Show()
end

function Inbox:Render()
  local frame = self:EnsureFrame()
  local snapshot = Catalog:GetSnapshot()
  local entries = self:GetDisplayEntries(snapshot)

  self:UpdateTabs()
  if self.mode == "api" then
    frame.Summary:SetText(Catalog:GetApiSummary() .. " The bundled API Documentation does not index this collection namespace, so runtime capability is authoritative.")
  else
    frame.Summary:SetText(Catalog:GetSnapshotSummary(snapshot) .. " Click MEMORIZE on one item, then approve Ascension's binding prompt yourself.")
  end

  for index = 1, #entries do
    local row = self:AcquireRow(index)
    if self.mode == "api" then
      self:ConfigureApiRow(row, entries[index])
    else
      self:ConfigureItemRow(row, entries[index])
    end
  end
  for index = #entries + 1, #self.rows do
    self.rows[index]:Hide()
  end

  local contentHeight = math.max(1, (#entries * (self.LAYOUT.rowHeight + self.LAYOUT.rowGap)) - self.LAYOUT.rowGap)
  frame.Child:SetHeight(contentHeight)
  frame.Scroll:SetVerticalScroll(0)

  if #entries == 0 then
    if self.mode == "api" then
      frame.Empty:SetText("No API diagnostics are available.")
    elseif snapshot and not snapshot.apiReady then
      frame.Empty:SetText("The appearance API is incomplete. Open the API tab for details.")
    elseif self.mode == "needs" then
      frame.Empty:SetText("No carried appearances currently need collection.")
    else
      frame.Empty:SetText("No wardrobe-capable items were found in carried bags.")
    end
    frame.Empty:Show()
  else
    frame.Empty:Hide()
  end

end

function Inbox:Refresh(source)
  self.refreshAt = nil
  self.refreshReason = nil
  if self.mode ~= "api" or not Catalog:GetSnapshot() then
    Catalog:BuildSnapshot(source or "Appearance Inbox")
  end
  self:Render()
end

function Inbox:ScheduleRefresh(reason, delay)
  if not self.frame or not self.frame:IsShown() then
    return
  end
  self.refreshReason = reason or "event refresh"
  self.refreshAt = GetTime() + (tonumber(delay) or 0.15)
end

function Inbox:Open(mode)
  local frame = self:EnsureFrame()
  if mode then
    self.mode = mode
  end
  frame:Show()
  if frame.Raise then
    frame:Raise()
  end
end

function Inbox:Toggle(mode)
  local frame = self:EnsureFrame()
  if frame:IsShown() then
    frame:Hide()
  else
    self:Open(mode)
  end
end

function Inbox:HandlePrimary(entry)
  if not entry or self.mode == "api" then
    return
  end
  if entry.statusCode == "ready"
      or entry.statusCode == "auto-paused"
      or entry.statusCode == "rule-ask"
      or entry.statusCode == "rule-never"
      or entry.statusCode == "type-disabled" then
    local queued, reason = Catalog:MemorizeEntry(entry)
    if queued then
      AP:Print("MEMORIZE submitted one item. Confirm Ascension's binding prompt to collect the appearance.")
    elseif reason then
      AP:Print(reason)
    end
  elseif entry.statusCode == "blacklisted" then
    Collector:RemoveBlacklistItem(entry.itemID)
  elseif entry.statusCode ~= "queued" and entry.statusCode ~= "collected" then
    self:Refresh("row refresh")
    return
  end
  Catalog:BuildSnapshot("row action")
  self:Render()
end

function Inbox:HandleSecondary(entry)
  if not entry or not entry.itemID then
    return
  end
  Collector:AddBlacklistItem(entry.itemID, entry.link)
  Catalog:BuildSnapshot("blacklist change")
  self:Render()
end

function Inbox:ShowEntryTooltip(entry)
  if not entry or self.mode == "api" or not GameTooltip then
    return
  end
  GameTooltip:SetOwner(self.frame, "ANCHOR_CURSOR")
  local currentID = type(GetContainerItemID) == "function" and GetContainerItemID(entry.bag, entry.slot) or nil
  if currentID == entry.itemID and type(GameTooltip.SetBagItem) == "function" then
    GameTooltip:SetBagItem(entry.bag, entry.slot)
  elseif entry.link and type(GameTooltip.SetHyperlink) == "function" then
    GameTooltip:SetHyperlink(entry.link)
  end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("Levo", Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3])
  GameTooltip:AddLine(entry.statusReason or "No status detail is available.", 1, 1, 1, true)
  GameTooltip:Show()
end

function Inbox:HandleSlash(arguments)
  local command = tostring(arguments or ""):match("^%s*(%S*)")
  command = string.lower(command or "")
  if command == "api" then
    self:Open("api")
  elseif command == "all" then
    self:Open("all")
  elseif command == "collect" or command == "memorize" then
    self:Open("needs")
  elseif command == "config" or command == "options" then
    AP:OpenConfig("transmog.appearance-inbox")
  else
    self:Open("needs")
  end
end
