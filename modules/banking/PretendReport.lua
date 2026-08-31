local _, AP = ...
AP = AP or _G.Levo or _G.WotLKPlus or _G.AscensionPlus

local Banking = AP.Banking
local Categories = Banking.Categories
local Theme = AP.UI.Theme

local Report = {
  maxTextLength = 60000,
  maxDisplayLength = 56000,
}

Banking.PretendReport = Report

local QUALITY_NAMES = {
  [0] = _G.ITEM_QUALITY0_DESC or "Poor",
  [1] = _G.ITEM_QUALITY1_DESC or "Common",
  [2] = _G.ITEM_QUALITY2_DESC or "Uncommon",
  [3] = _G.ITEM_QUALITY3_DESC or "Rare",
  [4] = _G.ITEM_QUALITY4_DESC or "Epic",
  [5] = _G.ITEM_QUALITY5_DESC or "Legendary",
  [6] = _G.ITEM_QUALITY6_DESC or "Artifact",
  [7] = _G.ITEM_QUALITY7_DESC or "Heirloom",
}

local QUALITY_HEX = {
  [0] = "ff9d9d9d",
  [1] = "ffffffff",
  [2] = "ff1eff00",
  [3] = "ff0070dd",
  [4] = "ffa335ee",
  [5] = "ffff8000",
  [6] = "ffe6cc80",
  [7] = "ffe6cc80",
}

local COLOR = {
  text = "ffe1e6f2",
  muted = "ff9ea8bd",
  dim = "ff665f4b",
  gold = "ffe7c56d",
  blue = "ff93c2ff",
  green = "ff75d18c",
  orange = "ffffc462",
  red = "ffed6666",
  purple = "ffc69cff",
}

local CATEGORY_HEX = {
  all = COLOR.green,
  materials = COLOR.gold,
  reagents = COLOR.blue,
  gear = COLOR.orange,
  recipe = COLOR.purple,
  other = COLOR.muted,
}

local DEFAULT_FOOTER = "Display is read-only. COPY sends the clean uncolored report to your clipboard."

local function escapeMarkup(value)
  return tostring(value or ""):gsub("|", "||")
end

local function paint(value, hex)
  return "|c" .. (hex or COLOR.text) .. escapeMarkup(value) .. "|r"
end

local function colorLabel(label, color)
  label:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

local function createTextButton(parent, text, width, height)
  local button = CreateFrame("Button", nil, parent)
  button:SetWidth(width)
  button:SetHeight(height)
  button:RegisterForClicks("LeftButtonUp")

  button.Label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  button.Label:SetAllPoints(button)
  button.Label:SetJustifyH("CENTER")
  button.Label:SetText(text)
  button.Label:SetShadowColor(0, 0, 0, 1)
  button.Label:SetShadowOffset(1, -1)
  colorLabel(button.Label, Theme.colors.muted)

  button:SetScript("OnEnter", function(self)
    colorLabel(self.Label, Theme.colors.gold)
  end)
  button:SetScript("OnLeave", function(self)
    self.Label:ClearAllPoints()
    self.Label:SetAllPoints(self)
    colorLabel(self.Label, Theme.colors.muted)
  end)
  button:SetScript("OnMouseDown", function(self)
    colorLabel(self.Label, Theme.colors.orange)
    self.Label:ClearAllPoints()
    self.Label:SetPoint("CENTER", self, "CENTER", 1, -1)
  end)
  button:SetScript("OnMouseUp", function(self)
    self.Label:ClearAllPoints()
    self.Label:SetAllPoints(self)
    colorLabel(self.Label, Theme.colors.gold)
  end)
  return button
end

local function addLine(document, plain, colored)
  document.plain[#document.plain + 1] = plain or ""
  document.colored[#document.colored + 1] = colored or paint(plain or "", COLOR.text)
end

local function addMultiline(document, value)
  for line in (tostring(value or "") .. "\n"):gmatch("(.-)\n") do
    local label, detail = line:match("^([^:]+):%s*(.*)$")
    if label then
      addLine(document, line, paint(label .. ": ", COLOR.muted) .. paint(detail, COLOR.text))
    else
      addLine(document, line, paint(line, COLOR.text))
    end
  end
end

local function getFlagText(flags)
  local names = {}
  if flags.bindOnEquip then
    names[#names + 1] = "Bind on Equip (unbound)"
  end
  if flags.soulbound then
    names[#names + 1] = "Soulbound"
  end
  if flags.accountBound then
    names[#names + 1] = "Account Bound"
  end
  if flags.realmBound then
    names[#names + 1] = "Realm Bound"
  end
  if flags.questBound then
    names[#names + 1] = "Quest Bound"
  end
  if flags.conjured then
    names[#names + 1] = "Conjured"
  end
  return #names > 0 and table.concat(names, ", ") or "None detected", #names > 0
end

local function appendAudit(document, title, directionText, audit)
  local divider = string.rep("=", 72)
  local accessText = audit.available and "AVAILABLE" or "UNAVAILABLE - " .. tostring(audit.unavailableReason or "unknown reason")
  local accessHex = audit.available and COLOR.green or COLOR.red

  addLine(document, "", "")
  addLine(document, divider, paint(divider, COLOR.dim))
  addLine(document, title, paint(title, COLOR.gold))
  addLine(document, directionText, paint(directionText, COLOR.blue))
  addLine(document, divider, paint(divider, COLOR.dim))
  addLine(document, "Access: " .. accessText, paint("Access: ", COLOR.muted) .. paint(accessText, accessHex))
  addLine(document,
    string.format("Matched: %d item(s) in %d stack(s)", audit.matchedItems, audit.matchedStacks),
    paint("Matched: ", COLOR.muted) .. paint(audit.matchedItems, COLOR.gold) .. paint(" item(s) in ", COLOR.text) .. paint(audit.matchedStacks, COLOR.gold) .. paint(" stack(s)", COLOR.text))
  addLine(document,
    string.format("Currently eligible: %d item(s) in %d stack(s)", audit.eligibleItems, audit.eligibleStacks),
    paint("Currently eligible: ", COLOR.muted) .. paint(audit.eligibleItems, COLOR.green) .. paint(" item(s) in ", COLOR.text) .. paint(audit.eligibleStacks, COLOR.green) .. paint(" stack(s)", COLOR.text))
  addLine(document,
    "Capacity is checked per stack against the current layout; PRETEND does not reserve cumulative empty slots.",
    paint("Capacity is checked per stack against the current layout; PRETEND does not reserve cumulative empty slots.", COLOR.muted))

  if #audit.entries == 0 then
    addLine(document, "", "")
    addLine(document, "No items matched this button in this source.", paint("No items matched this button in this source.", COLOR.muted))
    return
  end

  for index = 1, #audit.entries do
    local entry = audit.entries[index]
    local evidence = entry.evidence or {}
    local itemName = evidence.itemName or "Unknown item"
    local quality = QUALITY_NAMES[evidence.quality] or tostring(evidence.quality or "Unknown")
    local qualityHex = QUALITY_HEX[evidence.quality] or COLOR.text
    local equipSlot = evidence.equipSlot and evidence.equipSlot ~= "" and evidence.equipSlot or "None"
    local category = tostring(evidence.category or "EXCLUDED"):upper()
    local categoryHex = CATEGORY_HEX[evidence.category] or COLOR.red
    local itemLine = string.format("[%d] %s (item:%s) x%d", index, itemName, tostring(entry.itemID or "?"), entry.count or 0)

    addLine(document, "", "")
    addLine(document, itemLine,
      paint("[" .. index .. "]", COLOR.gold)
        .. " " .. paint(itemName, qualityHex)
        .. " " .. paint("(item:" .. tostring(entry.itemID or "?") .. ")", COLOR.muted)
        .. " " .. paint("x" .. tostring(entry.count or 0), COLOR.orange))
    addLine(document, "    Source: " .. tostring(entry.source or "Unknown"),
      paint("    Source: ", COLOR.muted) .. paint(entry.source or "Unknown", COLOR.blue))
    addLine(document,
      string.format("    Client data: %s > %s | Quality: %s | Equip slot: %s", tostring(evidence.className or "Unknown"), tostring(evidence.subClassName or "Unknown"), quality, equipSlot),
      paint("    Client data: ", COLOR.muted)
        .. paint(evidence.className or "Unknown", COLOR.blue)
        .. paint(" > ", COLOR.dim)
        .. paint(evidence.subClassName or "Unknown", COLOR.blue)
        .. paint(" | Quality: ", COLOR.muted)
        .. paint(quality, qualityHex)
        .. paint(" | Equip slot: ", COLOR.muted)
        .. paint(equipSlot, COLOR.text))
    addLine(document,
      string.format("    Decision: %s (%s)", category, tostring(evidence.code or "no-code")),
      paint("    Decision: ", COLOR.muted)
        .. paint(category, categoryHex)
        .. " " .. paint("(" .. tostring(evidence.code or "no-code") .. ")", COLOR.muted))
    addLine(document, "    Why: " .. tostring(evidence.reason or "No classification reason was returned."),
      paint("    Why: ", COLOR.gold) .. paint(evidence.reason or "No classification reason was returned.", COLOR.text))

    if entry.flagsChecked then
      local flagText, hasFlags = getFlagText(entry.flags or {})
      addLine(document, "    Binding flags: " .. flagText,
        paint("    Binding flags: ", COLOR.muted) .. paint(flagText, hasFlags and COLOR.orange or COLOR.green))
    elseif audit.operation == "deposit" then
      local flagText, hasFlags
      flagText = "Not checked; a hard transfer exclusion already applies."
      hasFlags = false
      addLine(document, "    Binding flags: " .. flagText,
        paint("    Binding flags: ", COLOR.muted) .. paint(flagText, COLOR.muted))
    else
      local flagText = "Not checked; bindings do not block withdrawal."
      addLine(document, "    Binding flags: " .. flagText,
        paint("    Binding flags: ", COLOR.muted) .. paint(flagText, COLOR.muted))
    end

    if entry.eligible then
      addLine(document, "    Transfer result: ELIGIBLE",
        paint("    Transfer result: ", COLOR.muted) .. paint("ELIGIBLE", COLOR.green))
    else
      local reason = tostring(entry.statusReason or "unknown reason")
      addLine(document, "    Transfer result: SKIPPED - " .. reason,
        paint("    Transfer result: ", COLOR.muted) .. paint("SKIPPED", COLOR.red) .. paint(" - " .. reason, COLOR.red))
    end
  end
end

local function joinLimited(lines, maxLength, colored)
  local output = {}
  local length = 0
  for index = 1, #lines do
    local line = lines[index]
    local addedLength = #line + (index > 1 and 1 or 0)
    if length + addedLength > maxLength then
      local warning = "[REPORT TRUNCATED AT " .. tostring(maxLength) .. " CHARACTERS]"
      output[#output + 1] = colored and paint(warning, COLOR.red) or warning
      break
    end
    output[#output + 1] = line
    length = length + addedLength
  end
  return table.concat(output, "\n")
end

function Report:BuildReport(categoryID, provider, depositAudit, withdrawAudit)
  local definition = Categories.definitions[categoryID]
  local categoryTitle = string.upper(definition and definition.title or tostring(categoryID))
  local categoryHex = CATEGORY_HEX[categoryID] or COLOR.gold
  local bankName = provider:GetBankName()
  local generated = type(date) == "function" and date("%Y-%m-%d %H:%M:%S") or "Unknown"
  local document = {
    plain = {},
    colored = {},
  }

  addLine(document, "LEVO - PRETEND BANK TRANSFER REPORT", paint("LEVO - PRETEND BANK TRANSFER REPORT", COLOR.gold))
  addLine(document, "No items were moved. This report is a read-only simulation of both directions.", paint("No items were moved. This report is a read-only simulation of both directions.", COLOR.green))
  addLine(document, "", "")
  addLine(document, "Button clicked: " .. categoryTitle, paint("Button clicked: ", COLOR.muted) .. paint(categoryTitle, categoryHex))
  addLine(document, "Open bank: " .. tostring(bankName), paint("Open bank: ", COLOR.muted) .. paint(bankName, COLOR.blue))
  addLine(document, "Bank view token: " .. tostring(provider:GetDestinationToken()), paint("Bank view token: ", COLOR.muted) .. paint(provider:GetDestinationToken(), COLOR.text))
  addLine(document, "Generated: " .. generated, paint("Generated: ", COLOR.muted) .. paint(generated, COLOR.text))
  addLine(document, "", "")
  addLine(document, "CLASSIFICATION POLICY", paint("CLASSIFICATION POLICY", COLOR.gold))

  if categoryID == "all" then
    addMultiline(document, definition and definition.summary or "All transferable stacks.")
  elseif categoryID == "materials" then
    addMultiline(document, Categories:GetMaterialsSummary())
  elseif categoryID == "other" then
    addMultiline(document, Categories:GetOtherSummary())
  else
    addMultiline(document, definition and definition.summary or "Unknown category.")
  end

  appendAudit(document, "DEPOSIT AUDIT", "Inventory -> " .. bankName, depositAudit)
  appendAudit(document, "WITHDRAW AUDIT", bankName .. " -> Inventory", withdrawAudit)

  local divider = string.rep("=", 72)
  addLine(document, "", "")
  addLine(document, divider, paint(divider, COLOR.dim))
  addLine(document, "END OF REPORT - NO ITEMS WERE MOVED", paint("END OF REPORT - NO ITEMS WERE MOVED", COLOR.green))

  return joinLimited(document.plain, self.maxTextLength, false), joinLimited(document.colored, self.maxDisplayLength, true)
end

function Report:BuildText(categoryID, provider, depositAudit, withdrawAudit)
  local plainText = self:BuildReport(categoryID, provider, depositAudit, withdrawAudit)
  return plainText
end

function Report:BuildColoredText(categoryID, provider, depositAudit, withdrawAudit)
  local _, coloredText = self:BuildReport(categoryID, provider, depositAudit, withdrawAudit)
  return coloredText
end

function Report:EstimateTextHeight(text)
  local visualLines = 0
  for line in (tostring(text) .. "\n"):gmatch("(.-)\n") do
    visualLines = visualLines + math.max(1, math.ceil(#line / 96))
  end
  return math.max(410, visualLines * 15 + 24)
end

function Report:SetFooter(text, color, duration)
  if not self.frame then
    return
  end

  local shade = color or Theme.colors.muted
  self.frame.Help:SetText(text or DEFAULT_FOOTER)
  self.frame.Help:SetTextColor(shade[1], shade[2], shade[3], shade[4] or 1)
  self.frame.Help:SetAlpha(1)
  self.footerTimer = duration
end

function Report:ResetFooter()
  self:SetFooter(DEFAULT_FOOTER, Theme.colors.muted)
end

function Report:CopyPlainText()
  if not self.text or self.text == "" then
    self:SetFooter("NOTHING TO COPY", Theme.colors.red, 2.5)
    return false
  end

  if type(_G.Internal_CopyToClipboard) ~= "function" then
    self:SetFooter("ASCENSION CLIPBOARD API IS UNAVAILABLE", Theme.colors.red, 3.5)
    return false
  end

  local ok, result = pcall(_G.Internal_CopyToClipboard, self.text)
  if not ok or result == false then
    self:SetFooter("COPY FAILED", Theme.colors.red, 3.5)
    return false
  end

  self:SetFooter("COPIED UNCOLORED REPORT TO CLIPBOARD", Theme.colors.green, 2.5)
  return true
end

function Report:RefreshScrollRange()
  if not self.frame then
    return
  end

  local viewportHeight = self.frame.Scroll:GetHeight() or 410
  local textHeight = self.frame.ReportText:GetStringHeight() or self:EstimateTextHeight(self.text or "")
  self.frame.ScrollChild:SetHeight(math.max(viewportHeight, textHeight + 16))

  local range = self.frame.Scroll:GetVerticalScrollRange() or 0
  self.frame.ScrollBar:SetMinMaxValues(0, range)
  if self.frame.ScrollBar:GetValue() > range then
    self.frame.ScrollBar:SetValue(range)
  end
  if range > 0 then
    self.frame.ScrollBar:Show()
  else
    self.frame.ScrollBar:Hide()
  end
end

function Report:Create()
  if self.frame then
    return self.frame
  end

  local frame = CreateFrame("Frame", "LevoPretendReport", UIParent)
  Theme:ApplyBackdrop(frame, Theme.colors.background, Theme.colors.border)
  frame:SetWidth(760)
  frame:SetHeight(540)
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
  frame:SetFrameStrata("FULLSCREEN_DIALOG")
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(self)
    self:StartMoving()
  end)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
  end)
  frame:Hide()

  frame.Title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  frame.Title:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -13)
  frame.Title:SetText("PRETEND REPORT")
  frame.Title:SetTextColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3], 1)
  frame.Title:SetShadowColor(0, 0, 0, 1)
  frame.Title:SetShadowOffset(1, -1)
  Theme:TrySetTitleFont(frame.Title, 20)

  frame.Subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  frame.Subtitle:SetPoint("LEFT", frame.Title, "RIGHT", 12, -1)
  frame.Subtitle:SetText("DRY RUN - NOTHING MOVED")
  frame.Subtitle:SetTextColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3], 1)

  frame.Close = createTextButton(frame, "x", 24, 24)
  frame.Close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -7)
  frame.Close.Label:SetFontObject(_G.GameFontNormalLarge)
  frame.Close:SetScript("OnClick", function()
    self:Hide()
  end)

  frame.Divider = frame:CreateTexture(nil, "ARTWORK")
  frame.Divider:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -43)
  frame.Divider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -43)
  frame.Divider:SetHeight(1)
  Theme:Paint(frame.Divider, Theme.colors.line)

  frame.Body = CreateFrame("Frame", nil, frame)
  frame.Body:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -54)
  frame.Body:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -34, 48)
  Theme:ApplyBackdrop(frame.Body, Theme.colors.inset, Theme.colors.line)

  frame.Scroll = CreateFrame("ScrollFrame", nil, frame.Body)
  frame.Scroll:SetPoint("TOPLEFT", frame.Body, "TOPLEFT", 8, -8)
  frame.Scroll:SetPoint("BOTTOMRIGHT", frame.Body, "BOTTOMRIGHT", -8, 8)
  frame.Scroll:EnableMouseWheel(true)

  frame.ScrollChild = CreateFrame("Frame", nil, frame.Scroll)
  frame.ScrollChild:SetWidth(678)
  frame.ScrollChild:SetHeight(410)

  frame.ReportText = frame.ScrollChild:CreateFontString(nil, "ARTWORK")
  frame.ReportText:SetPoint("TOPLEFT", frame.ScrollChild, "TOPLEFT", 4, -4)
  frame.ReportText:SetPoint("TOPRIGHT", frame.ScrollChild, "TOPRIGHT", -4, -4)
  frame.ReportText:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
  frame.ReportText:SetJustifyH("LEFT")
  frame.ReportText:SetJustifyV("TOP")
  frame.ReportText:SetTextColor(1, 1, 1, 1)
  frame.ReportText:SetShadowColor(0, 0, 0, 0.9)
  frame.ReportText:SetShadowOffset(1, -1)
  if frame.ReportText.SetSpacing then
    frame.ReportText:SetSpacing(2)
  end
  frame.Scroll:SetScrollChild(frame.ScrollChild)

  frame.ScrollBar = CreateFrame("Slider", nil, frame)
  frame.ScrollBar:SetPoint("TOPRIGHT", frame.Body, "TOPRIGHT", 17, -8)
  frame.ScrollBar:SetPoint("BOTTOMRIGHT", frame.Body, "BOTTOMRIGHT", 17, 8)
  frame.ScrollBar:SetWidth(10)
  frame.ScrollBar:SetOrientation("VERTICAL")
  frame.ScrollBar:SetValueStep(24)
  frame.ScrollBar:SetMinMaxValues(0, 0)
  Theme:ApplyBackdrop(frame.ScrollBar, Theme.colors.inset, Theme.colors.line)

  frame.ScrollBar.Thumb = frame.ScrollBar:CreateTexture(nil, "OVERLAY")
  frame.ScrollBar.Thumb:SetTexture(Theme.texture)
  frame.ScrollBar.Thumb:SetVertexColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3], 0.75)
  frame.ScrollBar.Thumb:SetWidth(8)
  frame.ScrollBar.Thumb:SetHeight(36)
  frame.ScrollBar:SetThumbTexture(frame.ScrollBar.Thumb)
  frame.ScrollBar:SetScript("OnValueChanged", function(_, value)
    frame.Scroll:SetVerticalScroll(value)
  end)

  local function scrollBy(delta)
    local range = frame.Scroll:GetVerticalScrollRange() or 0
    local nextValue = math.max(0, math.min(range, frame.ScrollBar:GetValue() - delta * 48))
    frame.ScrollBar:SetValue(nextValue)
  end
  frame.Scroll:SetScript("OnMouseWheel", function(_, delta)
    scrollBy(delta)
  end)

  frame.Help = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  frame.Help:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 16)
  frame.Help:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -132, 16)
  frame.Help:SetJustifyH("LEFT")

  frame.CloseText = createTextButton(frame, "CLOSE", 48, 22)
  frame.CloseText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)
  frame.CloseText:SetScript("OnClick", function()
    self:Hide()
  end)

  frame.Copy = createTextButton(frame, "COPY", 48, 22)
  frame.Copy:SetPoint("RIGHT", frame.CloseText, "LEFT", -8, 0)
  frame.Copy:SetScript("OnClick", function()
    self:CopyPlainText()
  end)

  frame:SetScript("OnUpdate", function(_, elapsed)
    if self.refreshScrollDelay then
      self.refreshScrollDelay = self.refreshScrollDelay - elapsed
      if self.refreshScrollDelay <= 0 then
        self.refreshScrollDelay = nil
        self:RefreshScrollRange()
      end
    end

    if self.footerTimer then
      self.footerTimer = self.footerTimer - elapsed
      if self.footerTimer <= 0 then
        self.footerTimer = nil
        self:ResetFooter()
      end
    end
  end)

  self.frame = frame
  self:ResetFooter()
  if _G.UISpecialFrames then
    table.insert(_G.UISpecialFrames, frame:GetName())
  end
  return frame
end

function Report:Open(categoryID, provider, depositAudit, withdrawAudit)
  local frame = self:Create()
  self.text, self.coloredText = self:BuildReport(categoryID, provider, depositAudit, withdrawAudit)
  frame.ReportText:SetText(self.coloredText)
  frame.ScrollChild:SetHeight(self:EstimateTextHeight(self.text))
  frame.ScrollBar:SetValue(0)
  frame.Scroll:SetVerticalScroll(0)
  self:ResetFooter()
  frame:Show()
  frame:Raise()
  self.refreshScrollDelay = 0.02
end

function Report:Hide()
  if self.frame then
    self.footerTimer = nil
    self.frame:Hide()
  end
end
