local _, AP = ...
AP = AP or _G.Levo or _G.WotLKPlus or _G.AscensionPlus

local Theme = AP.UI.Theme
local Window = {}
AP.TalentImport.ImportWindow = Window

local function setTextColor(fontString, color)
  fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

function Window:Create()
  if self.frame then
    return self.frame
  end

  local frame = CreateFrame("Frame", "LevoTalentImportWindow", UIParent)
  frame:SetWidth(640)
  frame:SetHeight(470)
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
  frame.Title:SetText("IMPORT MAX LEVEL BUILD")
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
  frame.Help:SetText("Paste a full Ascension build string. Levo follows its order, selecting only requested ranks that the native tree says are currently affordable. It updates Ascension's preview; use the native Apply/Save control to commit.")
  setTextColor(frame.Help, Theme.colors.text)

  frame.InputLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  frame.InputLabel:SetPoint("TOPLEFT", frame.Help, "BOTTOMLEFT", 0, -11)
  frame.InputLabel:SetText("BUILD STRING")
  setTextColor(frame.InputLabel, Theme.colors.gold)

  frame.InputShell = CreateFrame("Frame", nil, frame)
  frame.InputShell:SetPoint("TOPLEFT", frame.InputLabel, "BOTTOMLEFT", 0, -5)
  frame.InputShell:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -5)
  frame.InputShell:SetHeight(82)
  Theme:ApplyBackdrop(frame.InputShell, Theme.colors.inset, { Theme.colors.border[1], Theme.colors.border[2], Theme.colors.border[3], 0.45 })

  frame.Input = CreateFrame("EditBox", nil, frame.InputShell)
  frame.Input:SetMultiLine(true)
  frame.Input:SetAutoFocus(false)
  frame.Input:SetFontObject(GameFontHighlightSmall)
  frame.Input:SetTextInsets(7, 7, 6, 6)
  frame.Input:SetMaxLetters(8192)
  frame.Input:SetPoint("TOPLEFT", frame.InputShell, "TOPLEFT", 1, -1)
  frame.Input:SetPoint("BOTTOMRIGHT", frame.InputShell, "BOTTOMRIGHT", -1, 1)
  frame.Input:SetScript("OnEscapePressed", function(input)
    input:ClearFocus()
  end)
  frame.Input:SetScript("OnTextChanged", function(input, userInput)
    if userInput then
      AP.Database:Set("talentImport.lastBuild", input:GetText())
    end
  end)

  frame.ReportLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  frame.ReportLabel:SetPoint("TOPLEFT", frame.InputShell, "BOTTOMLEFT", 0, -11)
  frame.ReportLabel:SetText("AFFORDABILITY REPORT")
  setTextColor(frame.ReportLabel, Theme.colors.gold)

  frame.ReportScroll = CreateFrame("ScrollFrame", "LevoTalentImportReportScroll", frame, "UIPanelScrollFrameTemplate")
  frame.ReportScroll:SetPoint("TOPLEFT", frame.ReportLabel, "BOTTOMLEFT", 0, -5)
  frame.ReportScroll:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -30, -5)
  frame.ReportScroll:SetHeight(180)
  Theme:SkinScrollFrame(frame.ReportScroll)

  frame.ReportContent = CreateFrame("Frame", nil, frame.ReportScroll)
  frame.ReportContent:SetWidth(570)
  frame.ReportContent:SetHeight(1)
  frame.ReportScroll:SetScrollChild(frame.ReportContent)

  frame.Report = frame.ReportContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.Report:SetPoint("TOPLEFT", frame.ReportContent, "TOPLEFT", 2, -2)
  frame.Report:SetPoint("TOPRIGHT", frame.ReportContent, "TOPRIGHT", -4, -2)
  frame.Report:SetJustifyH("LEFT")
  frame.Report:SetJustifyV("TOP")
  setTextColor(frame.Report, Theme.colors.muted)

  frame.Analyze = CreateFrame("Button", nil, frame)
  frame.Analyze:SetWidth(124)
  frame.Analyze:SetHeight(24)
  frame.Analyze:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 15)
  frame.Analyze:SetText("ANALYZE")
  Theme:SkinButton(frame.Analyze)

  frame.Apply = CreateFrame("Button", nil, frame)
  frame.Apply:SetWidth(182)
  frame.Apply:SetHeight(24)
  frame.Apply:SetPoint("LEFT", frame.Analyze, "RIGHT", 8, 0)
  frame.Apply:SetText("APPLY AFFORDABLE")
  Theme:SkinButton(frame.Apply)

  frame.Clear = CreateFrame("Button", nil, frame)
  frame.Clear:SetWidth(90)
  frame.Clear:SetHeight(24)
  frame.Clear:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 15)
  frame.Clear:SetText("CLEAR")
  Theme:SkinButton(frame.Clear)

  frame.Analyze:SetScript("OnClick", function()
    local runtime = AP.TalentImport.Runtime
    if runtime then
      runtime:Analyze(frame.Input:GetText())
    end
  end)
  frame.Apply:SetScript("OnClick", function()
    local runtime = AP.TalentImport.Runtime
    if runtime then
      runtime:Start(frame.Input:GetText())
    end
  end)
  frame.Clear:SetScript("OnClick", function()
    frame.Input:SetText("")
    AP.Database:Set("talentImport.lastBuild", "")
    Window:SetReport("Paste a build string, then choose ANALYZE or APPLY AFFORDABLE.", "muted")
  end)

  if UISpecialFrames then
    UISpecialFrames[#UISpecialFrames + 1] = "LevoTalentImportWindow"
  end
  frame:Hide()
  self.frame = frame
  local initialReport = self.pendingReport or {
    text = "Paste a build string, then choose ANALYZE or APPLY AFFORDABLE.",
    colorName = "muted",
  }
  self:SetReport(initialReport.text, initialReport.colorName)
  return frame
end

function Window:SetReport(text, colorName)
  self.pendingReport = {
    text = tostring(text or ""),
    colorName = colorName or "muted",
  }
  local frame = self.frame
  if not frame then
    return
  end
  frame.Report:SetText(self.pendingReport.text)
  setTextColor(frame.Report, Theme.colors[self.pendingReport.colorName] or Theme.colors.muted)
  frame.ReportContent:SetHeight(math.max(1, frame.Report:GetStringHeight() + 8))
  frame.ReportScroll:SetVerticalScroll(0)
end

function Window:Open()
  local frame = self:Create()
  if frame.Input:GetText() == "" then
    frame.Input:SetText(AP.Database:Get("talentImport.lastBuild", ""))
  end
  frame:Show()
  frame.Input:SetFocus()
end
