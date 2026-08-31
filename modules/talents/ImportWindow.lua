local _, AP = ...
AP = AP or _G.Levo or _G.WotLKPlus or _G.AscensionPlus

local Theme = AP.UI.Theme
local Window = {}
AP.TalentImport.ImportWindow = Window

Window.Layout = {
  width = 580,
  collapsedHeight = 252,
  expandedHeight = 432,
  inset = 16,
  actionBottom = 15,
  actionHeight = 24,
  actionGap = 8,
  analyzeWidth = 88,
  applyWidth = 124,
  saveWidth = 148,
  clearWidth = 72,
}

local function setTextColor(fontString, color)
  fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

function Window:UpdateLayout()
  local frame = self.frame
  if not frame then
    return
  end
  local expanded = self.hasReport and true or false
  frame:SetHeight(expanded and self.Layout.expandedHeight or self.Layout.collapsedHeight)
  if expanded then
    frame.ReportLabel:Show()
    frame.ReportScroll:Show()
    frame.ActionRule:Show()
  else
    frame.ReportLabel:Hide()
    frame.ReportScroll:Hide()
    frame.ActionRule:Hide()
  end
end

function Window:Create()
  if self.frame then
    return self.frame
  end

  local frame = CreateFrame("Frame", "LevoTalentImportWindow", UIParent)
  frame:SetWidth(self.Layout.width)
  frame:SetHeight(self.Layout.collapsedHeight)
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 35)
  frame:SetFrameStrata("DIALOG")
  frame:SetToplevel(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  Theme:ApplyBackdrop(frame, Theme.colors.background, Theme.colors.border)

  frame.TitleBar = frame:CreateTexture(nil, "BACKGROUND")
  frame.TitleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
  frame.TitleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
  frame.TitleBar:SetHeight(38)
  Theme:Paint(frame.TitleBar, Theme.colors.titlebar)

  frame.Title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  frame.Title:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -12)
  frame.Title:SetText("IMPORT MAX-LEVEL BUILD")
  setTextColor(frame.Title, Theme.colors.gold)
  Theme:TrySetTitleFont(frame.Title, 19)

  frame.Close = CreateFrame("Button", nil, frame)
  frame.Close:SetWidth(22)
  frame.Close:SetHeight(22)
  frame.Close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -7)
  Theme:SkinCloseButton(frame.Close, "x")
  frame.Close:SetScript("OnClick", function()
    frame:Hide()
  end)

  frame.Rule = frame:CreateTexture(nil, "ARTWORK")
  frame.Rule:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -40)
  frame.Rule:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, -40)
  frame.Rule:SetHeight(1)
  Theme:Paint(frame.Rule, Theme.colors.line)

  frame.Help = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.Help:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -51)
  frame.Help:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -51)
  frame.Help:SetJustifyH("LEFT")
  frame.Help:SetJustifyV("TOP")
  frame.Help:SetText("APPLY NOW spends only requested ranks Ascension currently permits. SAVE & AUTO keeps the build armed for future points outside combat.")
  setTextColor(frame.Help, Theme.colors.text)

  frame.InputLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  frame.InputLabel:SetPoint("TOPLEFT", frame.Help, "BOTTOMLEFT", 0, -10)
  frame.InputLabel:SetText("BUILD STRING")
  setTextColor(frame.InputLabel, Theme.colors.gold)

  frame.InputShell = CreateFrame("Frame", nil, frame)
  frame.InputShell:SetPoint("TOPLEFT", frame.InputLabel, "BOTTOMLEFT", 0, -5)
  frame.InputShell:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -5)
  frame.InputShell:SetHeight(64)
  Theme:ApplyBackdrop(frame.InputShell, Theme.colors.inset, { Theme.colors.border[1], Theme.colors.border[2], Theme.colors.border[3], 0.45 })

  frame.Input = CreateFrame("EditBox", nil, frame.InputShell)
  frame.Input:SetMultiLine(true)
  frame.Input:SetAutoFocus(false)
  frame.Input:SetFontObject(GameFontHighlightSmall)
  frame.Input:SetTextInsets(7, 7, 5, 5)
  frame.Input:SetMaxLetters(8192)
  frame.Input:SetPoint("TOPLEFT", frame.InputShell, "TOPLEFT", 1, -1)
  frame.Input:SetPoint("BOTTOMRIGHT", frame.InputShell, "BOTTOMRIGHT", -1, 1)
  frame.Input:SetScript("OnEscapePressed", function(input)
    input:ClearFocus()
  end)
  frame.Input:SetScript("OnTextChanged", function(input, userInput)
    if userInput then
      AP.Database:Set("talentImport.lastBuild", input:GetText())
      Window:ClearReport()
    end
  end)

  frame.Actions = CreateFrame("Frame", nil, frame)
  frame.Actions:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", self.Layout.inset, self.Layout.actionBottom)
  frame.Actions:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -self.Layout.inset, self.Layout.actionBottom)
  frame.Actions:SetHeight(self.Layout.actionHeight)

  frame.ActionRule = frame:CreateTexture(nil, "ARTWORK")
  frame.ActionRule:SetPoint("BOTTOMLEFT", frame.Actions, "TOPLEFT", 0, 9)
  frame.ActionRule:SetPoint("BOTTOMRIGHT", frame.Actions, "TOPRIGHT", 0, 9)
  frame.ActionRule:SetHeight(1)
  Theme:Paint(frame.ActionRule, Theme.colors.line)

  frame.Analyze = CreateFrame("Button", nil, frame.Actions)
  frame.Analyze:SetWidth(self.Layout.analyzeWidth)
  frame.Analyze:SetHeight(self.Layout.actionHeight)
  frame.Analyze:SetPoint("LEFT", frame.Actions, "LEFT", 0, 0)
  frame.Analyze:SetText("ANALYZE")
  Theme:SkinButton(frame.Analyze)

  frame.Apply = CreateFrame("Button", nil, frame.Actions)
  frame.Apply:SetWidth(self.Layout.applyWidth)
  frame.Apply:SetHeight(self.Layout.actionHeight)
  frame.Apply:SetPoint("LEFT", frame.Analyze, "RIGHT", self.Layout.actionGap, 0)
  frame.Apply:SetText("APPLY NOW")
  Theme:SkinButton(frame.Apply)

  frame.Save = CreateFrame("Button", nil, frame.Actions)
  frame.Save:SetWidth(self.Layout.saveWidth)
  frame.Save:SetHeight(self.Layout.actionHeight)
  frame.Save:SetPoint("LEFT", frame.Apply, "RIGHT", self.Layout.actionGap, 0)
  frame.Save:SetText("SAVE & AUTO")
  Theme:SkinButton(frame.Save)

  frame.Clear = CreateFrame("Button", nil, frame.Actions)
  frame.Clear:SetWidth(self.Layout.clearWidth)
  frame.Clear:SetHeight(self.Layout.actionHeight)
  frame.Clear:SetPoint("RIGHT", frame.Actions, "RIGHT", 0, 0)
  frame.Clear:SetText("CLEAR")
  Theme:SkinButton(frame.Clear)

  frame.ReportLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  frame.ReportLabel:SetPoint("TOPLEFT", frame.InputShell, "BOTTOMLEFT", 0, -11)
  frame.ReportLabel:SetText("AFFORDABILITY REPORT")
  setTextColor(frame.ReportLabel, Theme.colors.gold)

  frame.ReportScroll = CreateFrame("ScrollFrame", "LevoTalentImportReportScroll", frame, "UIPanelScrollFrameTemplate")
  frame.ReportScroll:SetPoint("TOPLEFT", frame.ReportLabel, "BOTTOMLEFT", 0, -5)
  frame.ReportScroll:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -30, -5)
  frame.ReportScroll:SetPoint("BOTTOMLEFT", frame.Actions, "TOPLEFT", 0, 18)
  frame.ReportScroll:SetPoint("BOTTOMRIGHT", frame.Actions, "TOPRIGHT", -14, 18)
  Theme:SkinScrollFrame(frame.ReportScroll)

  frame.ReportContent = CreateFrame("Frame", nil, frame.ReportScroll)
  frame.ReportContent:SetWidth(516)
  frame.ReportContent:SetHeight(1)
  frame.ReportScroll:SetScrollChild(frame.ReportContent)

  frame.Report = frame.ReportContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.Report:SetPoint("TOPLEFT", frame.ReportContent, "TOPLEFT", 2, -2)
  frame.Report:SetPoint("TOPRIGHT", frame.ReportContent, "TOPRIGHT", -4, -2)
  frame.Report:SetJustifyH("LEFT")
  frame.Report:SetJustifyV("TOP")
  setTextColor(frame.Report, Theme.colors.muted)

  frame.Analyze:SetScript("OnClick", function()
    local runtime = AP.TalentImport.Runtime
    if runtime then
      runtime:Analyze(frame.Input:GetText())
    end
  end)
  frame.Apply:SetScript("OnClick", function()
    local runtime = AP.TalentImport.Runtime
    if runtime then
      runtime:ApplyNow(frame.Input:GetText())
    end
  end)
  frame.Save:SetScript("OnClick", function()
    local runtime = AP.TalentImport.Runtime
    if runtime then
      runtime:SaveAndApply(frame.Input:GetText())
    end
  end)
  frame.Clear:SetScript("OnClick", function()
    frame.Input:SetText("")
    AP.Database:Set("talentImport.lastBuild", "")
    Window:ClearReport()
  end)

  if UISpecialFrames then
    UISpecialFrames[#UISpecialFrames + 1] = "LevoTalentImportWindow"
  end
  frame:Hide()
  self.frame = frame
  if self.pendingReport then
    self:SetReport(self.pendingReport.text, self.pendingReport.colorName)
  else
    self:UpdateLayout()
  end
  return frame
end

function Window:ClearReport()
  self.hasReport = false
  self.pendingReport = nil
  if self.frame then
    self:UpdateLayout()
  end
end

function Window:SetReport(text, colorName)
  text = tostring(text or "")
  if text == "" then
    self:ClearReport()
    return
  end
  self.pendingReport = {
    text = text,
    colorName = colorName or "muted",
  }
  self.hasReport = true
  local frame = self.frame
  if not frame then
    return
  end
  self:UpdateLayout()
  frame.Report:SetText(self.pendingReport.text)
  setTextColor(frame.Report, Theme.colors[self.pendingReport.colorName] or Theme.colors.muted)
  frame.ReportContent:SetHeight(math.max(1, frame.Report:GetStringHeight() + 8))
  frame.ReportScroll:SetVerticalScroll(0)
end

function Window:GetInput()
  if self.frame then
    return self.frame.Input:GetText()
  end
  return AP.Database:Get("talentImport.lastBuild", "")
end

function Window:Open()
  local frame = self:Create()
  if frame.Input:GetText() == "" then
    frame.Input:SetText(AP.Database:Get("talentImport.lastBuild", ""))
  end
  frame:Show()
  frame.Input:SetFocus()
end
