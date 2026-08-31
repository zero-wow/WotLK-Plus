local _, AP = ...
AP = AP or _G.Levo or _G.WotLKPlus or _G.AscensionPlus

local Theme = AP.UI.Theme
local CONTENT_INSET = 12
local ITEM_GAP = 1
local SECTION_GAP = 8

local Pages = {}
AP.UI.Pages = Pages

local KEY_CAPTURE_HELP = "Hold any modifiers, then press a keyboard key, mouse button, or scroll direction. Nothing changes until you choose Save."
local MODIFIER_KEYS = {
  ALT = true,
  CTRL = true,
  SHIFT = true,
  LALT = true,
  RALT = true,
  LCTRL = true,
  RCTRL = true,
  LSHIFT = true,
  RSHIFT = true,
}
local MOUSE_BINDINGS = {
  LeftButton = "BUTTON1",
  RightButton = "BUTTON2",
  MiddleButton = "BUTTON3",
  Button4 = "BUTTON4",
  Button5 = "BUTTON5",
}

local function updateScrollChildWidth(scrollFrame, child)
  local width = scrollFrame:GetWidth() or 0
  if width > 4 then
    child:SetWidth(width - 2)
  end
end

local function resolve(value, page, option)
  if type(value) == "function" then
    return value(page, option)
  end
  return value
end

local function formatBindingToken(token)
  token = tostring(token or "")
  if token == "CTRL" then
    return "Ctrl"
  elseif token == "ALT" then
    return "Alt"
  elseif token == "SHIFT" then
    return "Shift"
  elseif token == "BUTTON1" then
    return "Left Mouse"
  elseif token == "BUTTON2" then
    return "Right Mouse"
  elseif token == "BUTTON3" then
    return "Middle Mouse"
  elseif token == "MOUSEWHEELUP" then
    return "Mouse Wheel Up"
  elseif token == "MOUSEWHEELDOWN" then
    return "Mouse Wheel Down"
  end

  local mouseButton = token:match("^BUTTON(%d+)$")
  if mouseButton then
    return "Mouse " .. mouseButton
  end

  if GetBindingText then
    local localized = GetBindingText(token, "KEY_")
    if localized and localized ~= "" then
      return localized
    end
  end

  token = token:gsub("NUMPAD", "Numpad ")
  token = token:gsub("PAGEUP", "Page Up")
  token = token:gsub("PAGEDOWN", "Page Down")
  token = token:gsub("SPACE", "Space")
  return token
end

local function formatBindingLabel(binding)
  if not binding or binding == "" then
    return "Not Bound"
  end

  local parts = {}
  for part in tostring(binding):gmatch("[^-]+") do
    parts[#parts + 1] = formatBindingToken(part)
  end

  return table.concat(parts, " + ")
end

local function normalizeInputToken(key)
  local token = MOUSE_BINDINGS[key]
  if token then
    return token
  end

  key = tostring(key or "")
  local mouseButton = key:match("^Button(%d+)$") or key:match("^MouseButton(%d+)$")
  if mouseButton then
    return "BUTTON" .. mouseButton
  end

  return string.upper(key)
end

local function getHeldModifiers()
  local tokens = {}
  local labels = {}
  if IsAltKeyDown and IsAltKeyDown() then
    tokens[#tokens + 1] = "ALT"
    labels[#labels + 1] = "Alt"
  end
  if IsControlKeyDown and IsControlKeyDown() then
    tokens[#tokens + 1] = "CTRL"
    labels[#labels + 1] = "Ctrl"
  end
  if IsShiftKeyDown and IsShiftKeyDown() then
    tokens[#tokens + 1] = "SHIFT"
    labels[#labels + 1] = "Shift"
  end
  return tokens, table.concat(labels, " + ")
end

local function buildBindingString(key)
  local token = normalizeInputToken(key)
  if token == "" or token == "UNKNOWN" then
    return nil, "unknown"
  end

  if MODIFIER_KEYS[token] then
    return nil, "modifier"
  end

  local parts = getHeldModifiers()
  parts[#parts + 1] = token
  return table.concat(parts, "-")
end

function Pages:Create(parent)
  local frame = CreateFrame("Frame", nil, parent)
  Theme:ApplyBackdrop(frame, Theme.colors.background, Theme.colors.neutralLine or Theme.colors.border)

  frame.Scroll = CreateFrame("ScrollFrame", "LevoPagesScroll", frame, "UIPanelScrollFrameTemplate")
  frame.Scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
  frame.Scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 1)
  Theme:SkinScrollFrame(frame.Scroll)
  frame.Scroll:EnableMouseWheel(true)
  frame.Scroll:SetScript("OnMouseWheel", function(self, delta)
    local range = self:GetVerticalScrollRange() or 0
    local nextValue = (self:GetVerticalScroll() or 0) - (delta * 28)
    nextValue = AP.Utils.Clamp(nextValue, 0, range)
    self:SetVerticalScroll(nextValue)
  end)

  frame.Child = CreateFrame("Frame", nil, frame.Scroll)
  frame.Child:SetWidth(720)
  frame.Child:SetHeight(1)
  frame.Scroll:SetScrollChild(frame.Child)
  frame.Scroll:SetScript("OnSizeChanged", function(self)
    updateScrollChildWidth(self, frame.Child)
  end)

  frame.Breadcrumb = frame.Child:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  frame.Breadcrumb:SetJustifyH("LEFT")
  frame.Breadcrumb:SetPoint("TOPLEFT", frame.Child, "TOPLEFT", CONTENT_INSET, -CONTENT_INSET)

  frame.Title = frame.Child:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  frame.Title:SetJustifyH("LEFT")
  frame.Title:SetPoint("TOPLEFT", frame.Breadcrumb, "BOTTOMLEFT", 0, -3)
  Theme:TrySetTitleFont(frame.Title, 22)

  frame.Description = frame.Child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.Description:SetJustifyH("LEFT")
  frame.Description:SetJustifyV("TOP")
  frame.Description:SetPoint("TOPLEFT", frame.Title, "BOTTOMLEFT", 0, -4)

  frame.HeaderRule = frame.Child:CreateTexture(nil, "ARTWORK")
  frame.HeaderRule:SetHeight(1)
  Theme:Paint(frame.HeaderRule, Theme.colors.neutralLine or Theme.colors.line)

  frame.HeaderAccent = frame.Child:CreateTexture(nil, "ARTWORK")
  frame.HeaderAccent:SetHeight(2)
  frame.HeaderAccent:SetWidth(38)
  Theme:Paint(frame.HeaderAccent, Theme.colors.gold)

  frame.items = {
    text = {},
    toggle = {},
    button = {},
    result = {},
    divider = {},
    keybind = {},
    segmented = {},
    select = {},
    blacklist = {},
    status = {},
  }
  frame.pageScroll = {}
  frame.currentPageId = nil

  frame.CaptureOverlay = CreateFrame("Frame", nil, UIParent)
  frame.CaptureOverlay:SetAllPoints(UIParent)
  frame.CaptureOverlay:SetFrameStrata("DIALOG")
  frame.CaptureOverlay:EnableMouse(true)
  frame.CaptureOverlay:Hide()

  frame.CaptureOverlay.Bg = frame.CaptureOverlay:CreateTexture(nil, "BACKGROUND")
  frame.CaptureOverlay.Bg:SetAllPoints(frame.CaptureOverlay)
  Theme:Paint(frame.CaptureOverlay.Bg, { 0.01, 0.01, 0.02, 0.75 })

  frame.CaptureOverlay.Input = CreateFrame("Button", nil, frame.CaptureOverlay)
  frame.CaptureOverlay.Input:SetAllPoints(frame.CaptureOverlay)
  frame.CaptureOverlay.Input:SetFrameLevel(frame.CaptureOverlay:GetFrameLevel() + 1)
  frame.CaptureOverlay.Input:RegisterForClicks("AnyDown")
  frame.CaptureOverlay.Input:EnableKeyboard(false)
  frame.CaptureOverlay.Input:EnableMouseWheel(true)

  frame.CaptureOverlay.Panel = CreateFrame("Frame", nil, frame.CaptureOverlay)
  Theme:ApplyBackdrop(frame.CaptureOverlay.Panel, Theme.colors.panel, Theme.colors.border)
  frame.CaptureOverlay.Panel:SetFrameLevel(frame.CaptureOverlay.Input:GetFrameLevel() + 1)
  frame.CaptureOverlay.Panel:SetWidth(460)
  frame.CaptureOverlay.Panel:SetHeight(208)
  frame.CaptureOverlay.Panel:SetPoint("CENTER", frame.CaptureOverlay, "CENTER", 0, 0)
  frame.CaptureOverlay.Panel:EnableMouse(true)
  frame.CaptureOverlay.Panel:EnableMouseWheel(true)

  frame.CaptureOverlay.TitleBar = frame.CaptureOverlay.Panel:CreateTexture(nil, "BACKGROUND")
  frame.CaptureOverlay.TitleBar:SetPoint("TOPLEFT", frame.CaptureOverlay.Panel, "TOPLEFT", 1, -1)
  frame.CaptureOverlay.TitleBar:SetPoint("TOPRIGHT", frame.CaptureOverlay.Panel, "TOPRIGHT", -1, -1)
  frame.CaptureOverlay.TitleBar:SetHeight(32)
  Theme:Paint(frame.CaptureOverlay.TitleBar, Theme.colors.titlebar)

  frame.CaptureOverlay.Title = frame.CaptureOverlay.Panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  frame.CaptureOverlay.Title:SetPoint("TOPLEFT", frame.CaptureOverlay.Panel, "TOPLEFT", 12, -10)
  frame.CaptureOverlay.Title:SetPoint("TOPRIGHT", frame.CaptureOverlay.Panel, "TOPRIGHT", -34, -10)
  frame.CaptureOverlay.Title:SetText("Capture Keybind")
  frame.CaptureOverlay.Title:SetTextColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3], 1)
  Theme:TrySetTitleFont(frame.CaptureOverlay.Title, 18)

  frame.CaptureOverlay.CloseButton = CreateFrame("Button", nil, frame.CaptureOverlay.Panel)
  frame.CaptureOverlay.CloseButton:SetWidth(20)
  frame.CaptureOverlay.CloseButton:SetHeight(20)
  frame.CaptureOverlay.CloseButton:SetPoint("TOPRIGHT", frame.CaptureOverlay.Panel, "TOPRIGHT", -7, -6)
  Theme:SkinCloseButton(frame.CaptureOverlay.CloseButton, "x")

  frame.CaptureOverlay.Divider = frame.CaptureOverlay.Panel:CreateTexture(nil, "ARTWORK")
  frame.CaptureOverlay.Divider:SetPoint("TOPLEFT", frame.CaptureOverlay.Panel, "TOPLEFT", 12, -33)
  frame.CaptureOverlay.Divider:SetPoint("TOPRIGHT", frame.CaptureOverlay.Panel, "TOPRIGHT", -12, -33)
  frame.CaptureOverlay.Divider:SetHeight(1)
  Theme:Paint(frame.CaptureOverlay.Divider, Theme.colors.line)

  frame.CaptureOverlay.Help = frame.CaptureOverlay.Panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.CaptureOverlay.Help:SetJustifyH("LEFT")
  frame.CaptureOverlay.Help:SetJustifyV("TOP")
  frame.CaptureOverlay.Help:SetPoint("TOPLEFT", frame.CaptureOverlay.Panel, "TOPLEFT", 12, -42)
  frame.CaptureOverlay.Help:SetPoint("TOPRIGHT", frame.CaptureOverlay.Panel, "TOPRIGHT", -12, -42)
  frame.CaptureOverlay.Help:SetText(KEY_CAPTURE_HELP)

  frame.CaptureOverlay.CaptureArea = CreateFrame("Button", nil, frame.CaptureOverlay.Panel)
  Theme:SkinDropTarget(frame.CaptureOverlay.CaptureArea)
  frame.CaptureOverlay.CaptureArea:SetPoint("TOPLEFT", frame.CaptureOverlay.Panel, "TOPLEFT", 12, -72)
  frame.CaptureOverlay.CaptureArea:SetPoint("TOPRIGHT", frame.CaptureOverlay.Panel, "TOPRIGHT", -12, -72)
  frame.CaptureOverlay.CaptureArea:SetHeight(76)
  frame.CaptureOverlay.CaptureArea:RegisterForClicks("AnyDown")
  frame.CaptureOverlay.CaptureArea:EnableMouseWheel(true)

  frame.CaptureOverlay.CaptureLabel = frame.CaptureOverlay.CaptureArea:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  frame.CaptureOverlay.CaptureLabel:SetPoint("TOPLEFT", frame.CaptureOverlay.CaptureArea, "TOPLEFT", 7, -6)
  frame.CaptureOverlay.CaptureLabel:SetText("LIVE INPUT")
  frame.CaptureOverlay.CaptureLabel:SetTextColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3], 1)

  frame.CaptureOverlay.Candidate = frame.CaptureOverlay.CaptureArea:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  frame.CaptureOverlay.Candidate:SetPoint("TOPLEFT", frame.CaptureOverlay.CaptureArea, "TOPLEFT", 7, -24)
  frame.CaptureOverlay.Candidate:SetPoint("TOPRIGHT", frame.CaptureOverlay.CaptureArea, "TOPRIGHT", -7, -24)
  frame.CaptureOverlay.Candidate:SetJustifyH("CENTER")
  frame.CaptureOverlay.Candidate:SetTextColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3], 1)

  frame.CaptureOverlay.Status = frame.CaptureOverlay.CaptureArea:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.CaptureOverlay.Status:SetPoint("BOTTOMLEFT", frame.CaptureOverlay.CaptureArea, "BOTTOMLEFT", 7, 6)
  frame.CaptureOverlay.Status:SetPoint("BOTTOMRIGHT", frame.CaptureOverlay.CaptureArea, "BOTTOMRIGHT", -7, 6)
  frame.CaptureOverlay.Status:SetJustifyH("CENTER")
  frame.CaptureOverlay.Status:SetTextColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3], 1)

  frame.CaptureOverlay.SaveButton = CreateFrame("Button", nil, frame.CaptureOverlay.Panel)
  frame.CaptureOverlay.SaveButton:SetWidth(90)
  frame.CaptureOverlay.SaveButton:SetHeight(20)
  frame.CaptureOverlay.SaveButton:SetPoint("BOTTOMRIGHT", frame.CaptureOverlay.Panel, "BOTTOMRIGHT", -12, 12)
  frame.CaptureOverlay.SaveButton:SetText("SAVE")
  Theme:SkinButton(frame.CaptureOverlay.SaveButton)

  frame.CaptureOverlay.CancelButton = CreateFrame("Button", nil, frame.CaptureOverlay.Panel)
  frame.CaptureOverlay.CancelButton:SetWidth(90)
  frame.CaptureOverlay.CancelButton:SetHeight(20)
  frame.CaptureOverlay.CancelButton:SetPoint("RIGHT", frame.CaptureOverlay.SaveButton, "LEFT", -6, 0)
  frame.CaptureOverlay.CancelButton:SetText("CANCEL")
  Theme:SkinButton(frame.CaptureOverlay.CancelButton)

  function frame:StopKeyCapture()
    self.captureCallback = nil
    self.captureCandidateBinding = nil
    self.captureModifierLabel = nil
    self.captureModifierElapsed = 0
    self.CaptureOverlay.Input:EnableKeyboard(false)
    self.CaptureOverlay:Hide()
  end

  function frame:CancelKeyCapture()
    self:StopKeyCapture()
  end

  function frame:SaveKeyCapture()
    local binding = self.captureCandidateBinding
    if not binding or binding == "" then
      self.CaptureOverlay.Status:SetText("Press an input before saving, or choose Cancel.")
      self.CaptureOverlay.Status:SetTextColor(Theme.colors.red[1], Theme.colors.red[2], Theme.colors.red[3], 1)
      return
    end

    local callback = self.captureCallback
    self:StopKeyCapture()
    if callback then
      callback(binding)
    end
  end

  function frame:UpdateCaptureCandidate(binding, message)
    self.captureCandidateBinding = binding or ""
    if self.captureCandidateBinding ~= "" then
      self.CaptureOverlay.Candidate:SetText(formatBindingLabel(self.captureCandidateBinding))
      self.CaptureOverlay.SaveButton:Enable()
    else
      self.CaptureOverlay.Candidate:SetText("PRESS ANY INPUT")
      self.CaptureOverlay.SaveButton:Disable()
    end

    self.CaptureOverlay.Status:SetText(message or "Press another input to replace this candidate.")
    self.CaptureOverlay.Status:SetTextColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3], 1)
  end

  function frame:RefreshCaptureModifierStatus()
    local _, label = getHeldModifiers()
    if label == self.captureModifierLabel then
      return
    end

    self.captureModifierLabel = label
    if label ~= "" then
      self.CaptureOverlay.Candidate:SetText(label .. " + ...")
      self.CaptureOverlay.Status:SetText("Held: " .. label .. " + ...")
    elseif self.captureCandidateBinding and self.captureCandidateBinding ~= "" then
      self.CaptureOverlay.Candidate:SetText(formatBindingLabel(self.captureCandidateBinding))
      self.CaptureOverlay.Status:SetText("Captured. Press another input to replace it, or choose Save.")
    else
      self.CaptureOverlay.Candidate:SetText("PRESS ANY INPUT")
      self.CaptureOverlay.Status:SetText("Waiting for a keyboard or mouse input.")
    end
    self.CaptureOverlay.Status:SetTextColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3], 1)
  end

  function frame:CaptureKeyInput(key)
    local binding, reason = buildBindingString(key)
    if reason == "modifier" then
      self.captureModifierLabel = nil
      self:RefreshCaptureModifierStatus()
      return
    end
    if not binding then
      self.CaptureOverlay.Status:SetText("That input was not recognized. Try another key or mouse input.")
      self.CaptureOverlay.Status:SetTextColor(Theme.colors.red[1], Theme.colors.red[2], Theme.colors.red[3], 1)
      return
    end

    self:UpdateCaptureCandidate(binding, "Captured. Press another input to replace it, or choose Save.")
  end

  function frame:StartKeyCapture(callback, currentBinding)
    self.captureCallback = callback
    self.captureModifierLabel = nil
    self.captureModifierElapsed = 0
    self.CaptureOverlay.Help:SetText(KEY_CAPTURE_HELP)
    Theme:RefreshCloseButton(self.CaptureOverlay.CloseButton)
    self:UpdateCaptureCandidate(
      currentBinding or "",
      currentBinding and currentBinding ~= ""
        and "Current binding loaded. Press any input to replace it."
        or "Waiting for a keyboard or mouse input."
    )
    self.CaptureOverlay:Show()
    self.CaptureOverlay.Input:EnableKeyboard(true)
  end

  local function captureMouseInput(_, button)
    frame:CaptureKeyInput(button)
  end

  local function captureMouseWheel(_, delta)
    frame:CaptureKeyInput(delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN")
  end

  frame.CaptureOverlay.Input:SetScript("OnKeyDown", function(_, key)
    frame:CaptureKeyInput(key)
  end)
  frame.CaptureOverlay.Input:SetScript("OnKeyUp", function()
    frame.captureModifierLabel = nil
    frame:RefreshCaptureModifierStatus()
  end)
  frame.CaptureOverlay.Input:SetScript("OnClick", captureMouseInput)
  frame.CaptureOverlay.Input:SetScript("OnMouseWheel", captureMouseWheel)
  frame.CaptureOverlay.Input:SetScript("OnUpdate", function(_, elapsed)
    frame.captureModifierElapsed = (frame.captureModifierElapsed or 0) + elapsed
    if frame.captureModifierElapsed >= 0.04 then
      frame.captureModifierElapsed = 0
      frame:RefreshCaptureModifierStatus()
    end
  end)

  frame.CaptureOverlay.CaptureArea:SetScript("OnClick", captureMouseInput)
  frame.CaptureOverlay.CaptureArea:SetScript("OnMouseWheel", captureMouseWheel)
  frame.CaptureOverlay.Panel:SetScript("OnMouseDown", captureMouseInput)
  frame.CaptureOverlay.Panel:SetScript("OnMouseWheel", captureMouseWheel)

  frame.CaptureOverlay.SaveButton:SetScript("OnClick", function()
    frame:SaveKeyCapture()
  end)
  frame.CaptureOverlay.CancelButton:SetScript("OnClick", function()
    frame:CancelKeyCapture()
  end)

  frame.CaptureOverlay.CloseButton:SetScript("OnClick", function()
    frame:CancelKeyCapture()
  end)

  frame.CaptureOverlay:SetScript("OnHide", function()
    frame.CaptureOverlay.Input:EnableKeyboard(false)
    frame.captureCallback = nil
    frame.captureCandidateBinding = nil
    frame.captureModifierLabel = nil
    frame.captureModifierElapsed = 0
  end)

  frame.SelectMenu = CreateFrame("Frame", "LevoConfigSelectMenu", UIParent)
  frame.SelectMenu:SetFrameStrata("DIALOG")
  frame.SelectMenu:SetToplevel(true)
  frame.SelectMenu:SetClampedToScreen(true)
  Theme:ApplyBackdrop(frame.SelectMenu, Theme.colors.panel, Theme.colors.border)
  frame.SelectMenu.rows = {}
  frame.SelectMenu:Hide()
  if UISpecialFrames then
    UISpecialFrames[#UISpecialFrames + 1] = "LevoConfigSelectMenu"
  end

  function frame:ShowSelectMenu(owner, choices, currentValue, onSelect)
    local menu = self.SelectMenu
    if not owner or type(choices) ~= "table" or #choices == 0 then
      menu:Hide()
      return
    end

    local width = math.max(180, owner:GetWidth() or 180)
    menu:SetWidth(width)
    menu:SetHeight((#choices * 24) + 8)
    menu:ClearAllPoints()
    menu:SetPoint("TOPRIGHT", owner, "BOTTOMRIGHT", 0, -4)

    for index = 1, #choices do
      local choice = choices[index]
      local selectedValue = choice.value
      local row = menu.rows[index]
      if not row then
        row = CreateFrame("Button", nil, menu)
        row:SetHeight(22)
        Theme:SkinButton(row)
        menu.rows[index] = row
      end
      local color = Theme.colors[choice.color or "gold"] or Theme.colors.gold
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", menu, "TOPLEFT", 4, -4 - ((index - 1) * 24))
      row:SetWidth(width - 8)
      row:SetText(resolve(choice.label, nil, nil) or tostring(choice.value or ""))
      row.APButtonStyle = {
        background = Theme.colors.panel,
        border = { Theme.colors.border[1], Theme.colors.border[2], Theme.colors.border[3], 0.28 },
        text = Theme.colors.muted,
        hoverBackground = Theme.colors.hover,
        hoverBorder = color,
        hoverText = color,
        pressedBackground = Theme.colors.pressed,
        pressedBorder = color,
        pressedText = color,
        selectedBackground = Theme.colors.selection,
        selectedBorder = color,
        selectedText = color,
      }
      row.APButtonSelected = currentValue == selectedValue
      row:SetScript("OnClick", function()
        menu:Hide()
        if onSelect then
          onSelect(selectedValue)
        end
      end)
      Theme:RefreshButton(row)
      row:Show()
    end
    for index = #choices + 1, #menu.rows do
      menu.rows[index]:Hide()
    end
    menu:Show()
  end

  function frame:HideAllItems()
    for _, pool in pairs(self.items) do
      for index = 1, #pool do
        pool[index]:Hide()
      end
    end
    if self.SelectMenu then
      self.SelectMenu:Hide()
    end
  end

  function frame:LayoutHeader(title, description, breadcrumb)
    local width = (self.Child:GetWidth() or 720) - (CONTENT_INSET * 2)
    local y = -12

    self.Breadcrumb:ClearAllPoints()
    self.Breadcrumb:SetWidth(width)
    if breadcrumb and breadcrumb ~= "" then
      self.Breadcrumb:SetPoint("TOPLEFT", self.Child, "TOPLEFT", CONTENT_INSET, y)
      self.Breadcrumb:SetText(breadcrumb)
      self.Breadcrumb:SetTextColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3], Theme.colors.muted[4])
      self.Breadcrumb:Show()
      y = y - self.Breadcrumb:GetStringHeight() - 3
    else
      self.Breadcrumb:SetText("")
      self.Breadcrumb:Hide()
    end

    self.Title:ClearAllPoints()
    self.Title:SetPoint("TOPLEFT", self.Child, "TOPLEFT", CONTENT_INSET, y)
    self.Title:SetWidth(width)
    self.Title:SetText(title or "")
    self.Title:SetTextColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], Theme.colors.text[4])
    self.Title:Show()
    y = y - self.Title:GetStringHeight() - 6

    description = description or ""
    self.Description:ClearAllPoints()
    self.Description:SetPoint("TOPLEFT", self.Child, "TOPLEFT", CONTENT_INSET, y)
    self.Description:SetWidth(width)
    self.Description:SetText(description)
    self.Description:SetTextColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3], Theme.colors.muted[4])
    if description ~= "" then
      self.Description:Show()
      y = y - self.Description:GetStringHeight() - 8
    else
      self.Description:Hide()
      y = y - 2
    end

    self.HeaderRule:ClearAllPoints()
    self.HeaderRule:SetPoint("TOPLEFT", self.Child, "TOPLEFT", CONTENT_INSET, y)
    self.HeaderRule:SetWidth(width)
    self.HeaderRule:Show()

    self.HeaderAccent:ClearAllPoints()
    self.HeaderAccent:SetPoint("TOPLEFT", self.Child, "TOPLEFT", CONTENT_INSET, y + 1)
    self.HeaderAccent:Show()
    y = y - 8

    return width, y
  end

  function frame:AcquireText(index)
    local item = self.items.text[index]
    if item then
      return item
    end

    item = CreateFrame("Frame", nil, self.Child)

    item.SectionAccent = item:CreateTexture(nil, "ARTWORK")
    item.SectionAccent:SetPoint("TOPLEFT", item, "TOPLEFT", 0, 0)
    item.SectionAccent:SetPoint("BOTTOMLEFT", item, "BOTTOMLEFT", 0, 0)
    item.SectionAccent:SetWidth(2)
    Theme:Paint(item.SectionAccent, Theme.colors.gold)
    item.SectionAccent:Hide()

    item.SectionRule = item:CreateTexture(nil, "ARTWORK")
    item.SectionRule:SetPoint("BOTTOMLEFT", item, "BOTTOMLEFT", 0, 0)
    item.SectionRule:SetPoint("BOTTOMRIGHT", item, "BOTTOMRIGHT", 0, 0)
    item.SectionRule:SetHeight(1)
    Theme:Paint(item.SectionRule, Theme.colors.line)
    item.SectionRule:Hide()

    item.Title = item:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    item.Title:SetJustifyH("LEFT")
    item.Title:SetPoint("TOPLEFT", item, "TOPLEFT", 0, 0)

    item.Body = item:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    item.Body:SetJustifyH("LEFT")
    item.Body:SetJustifyV("TOP")
    item.Body:SetPoint("TOPLEFT", item.Title, "BOTTOMLEFT", 0, -2)

    self.items.text[index] = item
    return item
  end

  function frame:AcquireToggle(index)
    local item = self.items.toggle[index]
    if item then
      return item
    end

    item = CreateFrame("Frame", nil, self.Child)
    item:EnableMouse(true)

    item.Hover = item:CreateTexture(nil, "HIGHLIGHT")
    item.Hover:SetPoint("TOPLEFT", item, "TOPLEFT", 0, 0)
    item.Hover:SetPoint("BOTTOMRIGHT", item, "BOTTOMRIGHT", 0, 1)
    Theme:Paint(item.Hover, { Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3], 0.055 })

    item.Rule = item:CreateTexture(nil, "ARTWORK")
    item.Rule:SetPoint("BOTTOMLEFT", item, "BOTTOMLEFT", 0, 0)
    item.Rule:SetPoint("BOTTOMRIGHT", item, "BOTTOMRIGHT", 0, 0)
    item.Rule:SetHeight(1)
    Theme:Paint(item.Rule, Theme.colors.neutralLine or Theme.colors.line)

    item.Check = CreateFrame("CheckButton", nil, item)
    item.Check:SetWidth(34)
    item.Check:SetHeight(18)
    item.Check:SetPoint("TOPRIGHT", item, "TOPRIGHT", 0, -7)
    Theme:SkinCheckButton(item.Check)

    item.Label = item:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    item.Label:SetJustifyH("LEFT")
    item.Label:SetPoint("TOPLEFT", item, "TOPLEFT", 0, -6)
    item.Label:SetPoint("TOPRIGHT", item, "TOPRIGHT", -46, -6)

    item.Description = item:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    item.Description:SetJustifyH("LEFT")
    item.Description:SetJustifyV("TOP")
    item.Description:SetPoint("TOPLEFT", item.Label, "BOTTOMLEFT", 0, -2)
    item.Description:SetPoint("TOPRIGHT", item, "TOPRIGHT", -46, -20)

    self.items.toggle[index] = item
    return item
  end

  function frame:AcquireButton(index)
    local item = self.items.button[index]
    if item then
      return item
    end

    item = CreateFrame("Frame", nil, self.Child)
    item.Rule = item:CreateTexture(nil, "ARTWORK")
    item.Rule:SetPoint("BOTTOMLEFT", item, "BOTTOMLEFT", 0, 0)
    item.Rule:SetPoint("BOTTOMRIGHT", item, "BOTTOMRIGHT", 0, 0)
    item.Rule:SetHeight(1)
    Theme:Paint(item.Rule, Theme.colors.neutralLine or Theme.colors.line)

    item.Label = item:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    item.Label:SetJustifyH("LEFT")
    item.Label:SetPoint("TOPLEFT", item, "TOPLEFT", 0, -6)

    item.Button = CreateFrame("Button", nil, item)
    item.Button:SetWidth(150)
    item.Button:SetHeight(22)
    item.Button:SetPoint("TOPRIGHT", item, "TOPRIGHT", 0, -6)
    Theme:SkinButton(item.Button)

    item.Description = item:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    item.Description:SetJustifyH("LEFT")
    item.Description:SetJustifyV("TOP")
    item.Description:SetPoint("TOPLEFT", item.Label, "BOTTOMLEFT", 0, -2)

    self.items.button[index] = item
    return item
  end

  function frame:AcquireStatus(index)
    local item = self.items.status[index]
    if item then
      return item
    end

    item = CreateFrame("Frame", nil, self.Child)
    item.Accent = item:CreateTexture(nil, "ARTWORK")
    item.Accent:SetPoint("TOPLEFT", item, "TOPLEFT", 0, -5)
    item.Accent:SetPoint("BOTTOMLEFT", item, "BOTTOMLEFT", 0, 6)
    item.Accent:SetWidth(2)
    Theme:Paint(item.Accent, Theme.colors.gold)

    item.Label = item:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    item.Label:SetJustifyH("LEFT")
    item.Label:SetPoint("TOPLEFT", item, "TOPLEFT", 8, -5)

    item.Value = item:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    item.Value:SetJustifyH("RIGHT")
    item.Value:SetPoint("TOPRIGHT", item, "TOPRIGHT", 0, -5)

    item.Description = item:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    item.Description:SetJustifyH("LEFT")
    item.Description:SetJustifyV("TOP")
    item.Description:SetPoint("TOPLEFT", item.Label, "BOTTOMLEFT", 0, -2)

    item.Rule = item:CreateTexture(nil, "ARTWORK")
    item.Rule:SetPoint("BOTTOMLEFT", item, "BOTTOMLEFT", 0, 0)
    item.Rule:SetPoint("BOTTOMRIGHT", item, "BOTTOMRIGHT", 0, 0)
    item.Rule:SetHeight(1)
    Theme:Paint(item.Rule, Theme.colors.neutralLine or Theme.colors.line)

    self.items.status[index] = item
    return item
  end

  function frame:AcquireResult(index)
    local item = self.items.result[index]
    if item then
      return item
    end

    item = CreateFrame("Button", nil, self.Child)
    Theme:SkinResultRow(item)

    item.Title = item:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    item.Title:SetJustifyH("LEFT")
    item.Title:SetPoint("TOPLEFT", item, "TOPLEFT", 6, -4)
    item.Title:SetPoint("TOPRIGHT", item, "TOPRIGHT", -6, -4)

    item.Path = item:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    item.Path:SetJustifyH("LEFT")
    item.Path:SetPoint("TOPLEFT", item.Title, "BOTTOMLEFT", 0, -2)
    item.Path:SetPoint("TOPRIGHT", item, "TOPRIGHT", -6, -19)

    item.Summary = item:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    item.Summary:SetJustifyH("LEFT")
    item.Summary:SetJustifyV("TOP")
    item.Summary:SetPoint("TOPLEFT", item.Path, "BOTTOMLEFT", 0, -2)
    item.Summary:SetPoint("TOPRIGHT", item, "TOPRIGHT", -6, -31)

    self.items.result[index] = item
    return item
  end

  function frame:AcquireDivider(index)
    local item = self.items.divider[index]
    if item then
      return item
    end

    item = CreateFrame("Frame", nil, self.Child)
    item.Line = item:CreateTexture(nil, "ARTWORK")
    item.Line:SetAllPoints(item)
    Theme:Paint(item.Line, Theme.colors.line)

    self.items.divider[index] = item
    return item
  end

  function frame:AcquireKeybind(index)
    local item = self.items.keybind[index]
    if item then
      return item
    end

    item = CreateFrame("Frame", nil, self.Child)

    item.Label = item:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    item.Label:SetJustifyH("LEFT")
    item.Label:SetPoint("TOPLEFT", item, "TOPLEFT", 0, 0)
    item.Label:SetPoint("TOPRIGHT", item, "TOPRIGHT", 0, 0)

    item.Description = item:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    item.Description:SetJustifyH("LEFT")
    item.Description:SetJustifyV("TOP")
    item.Description:SetPoint("TOPLEFT", item.Label, "BOTTOMLEFT", 0, -2)
    item.Description:SetPoint("TOPRIGHT", item, "TOPRIGHT", 0, -18)

    item.ValueShell = CreateFrame("Frame", nil, item)
    Theme:ApplyBackdrop(item.ValueShell, Theme.colors.inset, { Theme.colors.border[1], Theme.colors.border[2], Theme.colors.border[3], 0.30 })
    item.ValueShell:SetHeight(20)

    item.Value = item.ValueShell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    item.Value:SetJustifyH("LEFT")
    item.Value:SetPoint("LEFT", item.ValueShell, "LEFT", 6, 0)
    item.Value:SetPoint("RIGHT", item.ValueShell, "RIGHT", -6, 0)

    item.SetButton = CreateFrame("Button", nil, item)
    item.SetButton:SetWidth(88)
    item.SetButton:SetHeight(18)
    item.SetButton:SetText("Set Hotkey")
    item.SetButton:SetPoint("TOPLEFT", item.ValueShell, "BOTTOMLEFT", 0, -3)
    Theme:SkinButton(item.SetButton)

    item.ClearButton = CreateFrame("Button", nil, item)
    item.ClearButton:SetWidth(64)
    item.ClearButton:SetHeight(18)
    item.ClearButton:SetText("Clear")
    item.ClearButton:SetPoint("LEFT", item.SetButton, "RIGHT", 6, 0)
    Theme:SkinButton(item.ClearButton)

    self.items.keybind[index] = item
    return item
  end

  function frame:AcquireSegmented(index)
    local item = self.items.segmented[index]
    if item then
      return item
    end

    item = CreateFrame("Frame", nil, self.Child)

    item.Label = item:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    item.Label:SetJustifyH("LEFT")
    item.Label:SetPoint("TOPLEFT", item, "TOPLEFT", 0, 0)
    item.Label:SetPoint("TOPRIGHT", item, "TOPRIGHT", 0, 0)

    item.Description = item:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    item.Description:SetJustifyH("LEFT")
    item.Description:SetJustifyV("TOP")
    item.Description:SetPoint("TOPLEFT", item.Label, "BOTTOMLEFT", 0, -2)
    item.Description:SetPoint("TOPRIGHT", item, "TOPRIGHT", 0, -18)

    item.Buttons = {}
    function item:AcquireChoice(choiceIndex)
      local button = self.Buttons[choiceIndex]
      if button then
        return button
      end

      button = CreateFrame("Button", nil, self)
      button:SetHeight(20)
      Theme:SkinButton(button)
      self.Buttons[choiceIndex] = button
      return button
    end

    self.items.segmented[index] = item
    return item
  end

  function frame:AcquireSelect(index)
    local item = self.items.select[index]
    if item then
      return item
    end

    item = CreateFrame("Frame", nil, self.Child)
    item.Rule = item:CreateTexture(nil, "ARTWORK")
    item.Rule:SetPoint("BOTTOMLEFT", item, "BOTTOMLEFT", 0, 0)
    item.Rule:SetPoint("BOTTOMRIGHT", item, "BOTTOMRIGHT", 0, 0)
    item.Rule:SetHeight(1)
    Theme:Paint(item.Rule, Theme.colors.neutralLine or Theme.colors.line)

    item.Label = item:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    item.Label:SetJustifyH("LEFT")
    item.Label:SetPoint("TOPLEFT", item, "TOPLEFT", 0, -6)

    item.Description = item:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    item.Description:SetJustifyH("LEFT")
    item.Description:SetJustifyV("TOP")
    item.Description:SetPoint("TOPLEFT", item.Label, "BOTTOMLEFT", 0, -2)

    item.SelectButton = CreateFrame("Button", nil, item)
    item.SelectButton:SetWidth(200)
    item.SelectButton:SetHeight(22)
    Theme:SkinButton(item.SelectButton)

    self.items.select[index] = item
    return item
  end

  function frame:AcquireBlacklist(index)
    local item = self.items.blacklist[index]
    if item then
      return item
    end

    item = CreateFrame("Frame", nil, self.Child)

    item.Label = item:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    item.Label:SetJustifyH("LEFT")
    item.Label:SetPoint("TOPLEFT", item, "TOPLEFT", 0, 0)
    item.Label:SetPoint("TOPRIGHT", item, "TOPRIGHT", 0, 0)

    item.Description = item:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    item.Description:SetJustifyH("LEFT")
    item.Description:SetJustifyV("TOP")
    item.Description:SetPoint("TOPLEFT", item.Label, "BOTTOMLEFT", 0, -2)
    item.Description:SetPoint("TOPRIGHT", item, "TOPRIGHT", 0, -20)

    item.DropBox = CreateFrame("Button", nil, item)
    Theme:SkinDropTarget(item.DropBox)
    item.DropBox:SetHeight(24)

    item.DropText = item.DropBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    item.DropText:SetPoint("LEFT", item.DropBox, "LEFT", 6, 0)
    item.DropText:SetPoint("RIGHT", item.DropBox, "RIGHT", -6, 0)
    item.DropText:SetJustifyH("LEFT")
    item.DropText:SetText("Drag an item here to blacklist it")

    item.ClearButton = CreateFrame("Button", nil, item)
    item.ClearButton:SetWidth(90)
    item.ClearButton:SetHeight(18)
    item.ClearButton:SetText("Clear All")
    Theme:SkinButton(item.ClearButton)

    item.Empty = item:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    item.Empty:SetJustifyH("LEFT")
    item.Empty:SetPoint("TOPLEFT", item.DropBox, "BOTTOMLEFT", 0, -6)
    item.Empty:SetText("No blacklisted items.")

    item.rows = {}

    function item:AcquireRow(rowIndex)
      local row = self.rows[rowIndex]
      if row then
        return row
      end

      row = CreateFrame("Frame", nil, self)
      Theme:ApplyBackdrop(row, { 0.06, 0.07, 0.09, 0.8 }, Theme.colors.line)
      row:SetHeight(22)

      row.Text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      row.Text:SetJustifyH("LEFT")
      row.Text:SetPoint("LEFT", row, "LEFT", 6, 0)
      row.Text:SetPoint("RIGHT", row, "RIGHT", -68, 0)

      row.Remove = CreateFrame("Button", nil, row)
      row.Remove:SetWidth(58)
      row.Remove:SetHeight(18)
      row.Remove:SetText("Remove")
      row.Remove:SetPoint("RIGHT", row, "RIGHT", -3, 0)
      Theme:SkinButton(row.Remove)

      self.rows[rowIndex] = row
      return row
    end

    self.items.blacklist[index] = item
    return item
  end

  function frame:RenderPage(page)
    local pageId = page and page.id or "__unknown__"
    local currentScroll = self.Scroll:GetVerticalScroll() or 0
    if self.currentPageId then
      self.pageScroll[self.currentPageId] = currentScroll
    end
    local targetScroll = self.currentPageId == pageId and currentScroll or (self.pageScroll[pageId] or 0)
    self.currentPageId = pageId

    self:HideAllItems()
    updateScrollChildWidth(self.Scroll, self.Child)

    local breadcrumb = page.parent and AP.ConfigRegistry:GetPagePath(page.parent) or nil
    local width, y = self:LayoutHeader(page.title or page.id, page.description or "", breadcrumb)
    local options = AP.ConfigRegistry:GetResolvedOptions(page)

    local textIndex = 0
    local toggleIndex = 0
    local buttonIndex = 0
    local dividerIndex = 0
    local keybindIndex = 0
    local segmentedIndex = 0
    local selectIndex = 0
    local blacklistIndex = 0
    local statusIndex = 0

    for index = 1, #options do
      local option = options[index]
      local optionType = option.type or "text"

      if optionType == "section" or optionType == "text" then
        textIndex = textIndex + 1
        local item = self:AcquireText(textIndex)
        item:ClearAllPoints()
        item:SetPoint("TOPLEFT", self.Child, "TOPLEFT", CONTENT_INSET, y)
        item:SetWidth(width)

        local title = resolve(option.label, page, option) or ""
        local body = resolve(option.description, page, option) or resolve(option.text, page, option) or ""
        local isSection = optionType == "section"
        local textInset = isSection and 8 or 0

        if isSection then
          item.SectionAccent:Show()
          item.SectionRule:Show()
        else
          item.SectionAccent:Hide()
          item.SectionRule:Hide()
        end

        item.Title:ClearAllPoints()
        item.Title:SetWidth(width - textInset)
        item.Title:SetText(title)
        item.Title:SetTextColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3], isSection and 1 or 0.85)

        item.Body:ClearAllPoints()
        item.Body:SetWidth(width - textInset)
        item.Body:SetText(body)
        item.Body:SetTextColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], Theme.colors.text[4])

        local height = 0
        if title ~= "" then
          item.Title:SetPoint("TOPLEFT", item, "TOPLEFT", textInset, 0)
          item.Title:Show()
          height = item.Title:GetStringHeight()
        else
          item.Title:Hide()
        end

        if body ~= "" then
          if title ~= "" then
            item.Body:SetPoint("TOPLEFT", item.Title, "BOTTOMLEFT", 0, -2)
            height = height + 2
          else
            item.Body:SetPoint("TOPLEFT", item, "TOPLEFT", textInset, 0)
          end
          item.Body:Show()
          height = height + item.Body:GetStringHeight()
        else
          item.Body:Hide()
        end

        height = math.max(1, height) + (isSection and 2 or 0)
        item:SetHeight(height)
        item:Show()
        y = y - height - (isSection and SECTION_GAP or 4)
      elseif optionType == "status" then
        statusIndex = statusIndex + 1
        local item = self:AcquireStatus(statusIndex)
        item:ClearAllPoints()
        item:SetPoint("TOPLEFT", self.Child, "TOPLEFT", CONTENT_INSET, y)
        item:SetWidth(width)
        item:Show()

        local label = resolve(option.label, page, option) or "Status"
        local value = resolve(option.value, page, option) or ""
        local description = resolve(option.description, page, option) or resolve(option.text, page, option) or ""
        local color = resolve(option.color, page, option)
        if type(color) == "string" then
          color = Theme.colors[color]
        end
        color = type(color) == "table" and color or Theme.colors.gold

        item.Label:SetWidth(math.max(120, math.floor(width * 0.55)))
        item.Label:SetText(label)
        item.Label:SetTextColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], 1)
        item.Value:SetWidth(math.max(100, math.floor(width * 0.35)))
        item.Value:SetText(value)
        item.Value:SetTextColor(color[1], color[2], color[3], color[4] or 1)
        item.Description:SetWidth(width - 20)
        item.Description:SetText(description)
        item.Description:SetTextColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3], 1)
        if description ~= "" then
          item.Description:Show()
        else
          item.Description:Hide()
        end
        Theme:Paint(item.Accent, color)

        local height = 26
        if description ~= "" then
          height = math.max(38, 16 + item.Description:GetStringHeight() + 9)
        end
        item:SetHeight(height)
        y = y - height - ITEM_GAP
      elseif optionType == "toggle" then
        toggleIndex = toggleIndex + 1
        local item = self:AcquireToggle(toggleIndex)
        item:ClearAllPoints()
        item:SetPoint("TOPLEFT", self.Child, "TOPLEFT", CONTENT_INSET, y)
        item:SetWidth(width)
        item:Show()

        local label = resolve(option.label, page, option) or ""
        local description = resolve(option.description, page, option) or ""
        local disabled = resolve(option.disabled, page, option) and true or false

        item.Label:SetWidth(width - 46)
        item.Label:SetText(label)
        item.Label:SetTextColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], disabled and 0.45 or 1)

        item.Description:SetWidth(width - 46)
        item.Description:SetText(description)
        item.Description:SetTextColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3], disabled and 0.45 or 1)
        if description ~= "" then
          item.Description:Show()
        else
          item.Description:Hide()
        end

        local currentValue
        if type(option.get) == "function" then
          currentValue = option.get(page, option)
        else
          currentValue = AP.Database:Get(option.path, false)
        end

        Theme:SetCheckButtonChecked(item.Check, currentValue and true or false)
        if disabled then
          if item.Check.Disable then
            item.Check:Disable()
          end
        else
          if item.Check.Enable then
            item.Check:Enable()
          end
        end
        item.Check:SetScript("OnClick", function(checkButton)
          local checked = checkButton:GetChecked() and true or false
          Theme:RefreshCheckButton(checkButton)
          if type(option.set) == "function" then
            option.set(checked, page, option)
          elseif option.path then
            AP.Database:Set(option.path, checked)
          end
          if type(option.onChange) == "function" then
            option.onChange(checked, page, option)
          end
          if self.onChanged then
            self.onChanged()
          end
        end)
        item:SetScript("OnMouseUp", function(_, button)
          if button ~= "LeftButton" or disabled then
            return
          end
          local checked = not (item.Check:GetChecked() and true or false)
          Theme:SetCheckButtonChecked(item.Check, checked)
          if type(option.set) == "function" then
            option.set(checked, page, option)
          elseif option.path then
            AP.Database:Set(option.path, checked)
          end
          if type(option.onChange) == "function" then
            option.onChange(checked, page, option)
          end
          if self.onChanged then
            self.onChanged()
          end
        end)

        local height = item.Label:GetStringHeight()
        if description ~= "" then
          height = height + item.Description:GetStringHeight() + 2
        end
        height = math.max(36, height + 12)
        item.Check:ClearAllPoints()
        item.Check:SetPoint("TOPRIGHT", item, "TOPRIGHT", 0, -math.floor((height - item.Check:GetHeight()) / 2))
        item:SetHeight(height)
        y = y - height - ITEM_GAP
      elseif optionType == "button" then
        buttonIndex = buttonIndex + 1
        local item = self:AcquireButton(buttonIndex)
        item:ClearAllPoints()
        item:SetPoint("TOPLEFT", self.Child, "TOPLEFT", CONTENT_INSET, y)
        item:SetWidth(width)
        item:Show()

        local label = resolve(option.label, page, option) or "Action"
        local buttonWidth = tonumber(resolve(option.buttonWidth, page, option)) or 150
        local disabled = resolve(option.disabled, page, option) and true or false
        item.Button:SetWidth(buttonWidth)
        item.Label:SetWidth(math.max(80, width - buttonWidth - 16))
        item.Label:SetText(label)
        item.Label:SetTextColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], disabled and 0.45 or 1)
        item.Button:SetText(resolve(option.buttonText, page, option) or label or "Run")
        if disabled then
          item.Button:Disable()
        else
          item.Button:Enable()
        end
        Theme:RefreshButton(item.Button)
        item.Button:SetScript("OnClick", function()
          if type(option.action) == "function" then
            option.action(page, option)
          end
          if self.onChanged then
            self.onChanged()
          end
        end)

        item.Description:ClearAllPoints()
        item.Description:SetPoint("TOPLEFT", item.Label, "BOTTOMLEFT", 0, -2)
        item.Description:SetWidth(math.max(80, width - buttonWidth - 16))
        local description = resolve(option.description, page, option) or ""
        item.Description:SetText(description)
        item.Description:SetTextColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3], disabled and 0.45 or Theme.colors.muted[4])
        if description ~= "" then
          item.Description:Show()
        else
          item.Description:Hide()
        end

        local height = item.Label:GetStringHeight()
        if description ~= "" then
          height = height + item.Description:GetStringHeight() + 2
        end
        height = math.max(38, height + 12)
        item.Button:ClearAllPoints()
        item.Button:SetPoint("RIGHT", item, "RIGHT", 0, 0)
        item:SetHeight(height)
        y = y - height - ITEM_GAP
      elseif optionType == "select" then
        selectIndex = selectIndex + 1
        local item = self:AcquireSelect(selectIndex)
        item:ClearAllPoints()
        item:SetPoint("TOPLEFT", self.Child, "TOPLEFT", CONTENT_INSET, y)
        item:SetWidth(width)
        item:Show()

        local label = resolve(option.label, page, option) or "Selection"
        local description = resolve(option.description, page, option) or ""
        local choices = resolve(option.choices, page, option) or {}
        local buttonWidth = tonumber(resolve(option.buttonWidth, page, option)) or 200
        local disabled = resolve(option.disabled, page, option) and true or false
        local currentValue
        if type(option.get) == "function" then
          currentValue = option.get(page, option)
        elseif option.path then
          currentValue = AP.Database:Get(option.path, option.default)
        end

        local currentLabel = tostring(currentValue or "Select...")
        for choiceIndex = 1, #choices do
          local choice = choices[choiceIndex]
          if choice.value == currentValue then
            currentLabel = resolve(choice.label, page, option) or currentLabel
            break
          end
        end

        item.Label:SetWidth(math.max(80, width - buttonWidth - 16))
        item.Label:SetText(label)
        item.Label:SetTextColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], disabled and 0.45 or 1)
        item.Description:SetWidth(math.max(80, width - buttonWidth - 16))
        item.Description:SetText(description)
        item.Description:SetTextColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3], disabled and 0.45 or 1)
        if description ~= "" then
          item.Description:Show()
        else
          item.Description:Hide()
        end

        item.SelectButton:SetWidth(buttonWidth)
        item.SelectButton:SetText(currentLabel)
        if disabled then
          item.SelectButton:Disable()
        else
          item.SelectButton:Enable()
        end
        Theme:RefreshButton(item.SelectButton)
        item.SelectButton:SetScript("OnClick", function()
          if disabled then
            return
          end
          self:ShowSelectMenu(item.SelectButton, choices, currentValue, function(value)
            if type(option.set) == "function" then
              option.set(value, page, option)
            elseif option.path then
              AP.Database:Set(option.path, value)
            end
            if type(option.onChange) == "function" then
              option.onChange(value, page, option)
            end
            if self.onChanged then
              self.onChanged()
            end
          end)
        end)

        local height = item.Label:GetStringHeight()
        if description ~= "" then
          height = height + item.Description:GetStringHeight() + 2
        end
        height = math.max(38, height + 12)
        item.SelectButton:ClearAllPoints()
        item.SelectButton:SetPoint("RIGHT", item, "RIGHT", 0, 0)
        item:SetHeight(height)
        y = y - height - ITEM_GAP
      elseif optionType == "keybind" then
        keybindIndex = keybindIndex + 1
        local item = self:AcquireKeybind(keybindIndex)
        item:ClearAllPoints()
        item:SetPoint("TOPLEFT", self.Child, "TOPLEFT", CONTENT_INSET, y)
        item:SetWidth(width)
        item:Show()

        item.Label:SetWidth(width)
        item.Label:SetText(resolve(option.label, page, option) or "Hotkey")
        item.Label:SetTextColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], Theme.colors.text[4])

        item.Description:SetWidth(width)
        local description = resolve(option.description, page, option) or ""
        item.Description:SetText(description)
        item.Description:SetTextColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3], Theme.colors.muted[4])
        if description ~= "" then
          item.Description:Show()
        else
          item.Description:Hide()
        end

        local currentBinding = ""
        if type(option.get) == "function" then
          currentBinding = option.get(page, option) or ""
        elseif option.path then
          currentBinding = AP.Database:Get(option.path, "")
        end

        local contentY = -item.Label:GetStringHeight()
        item.Description:ClearAllPoints()
        if description ~= "" then
          item.Description:SetPoint("TOPLEFT", item, "TOPLEFT", 0, contentY - 2)
          item.Description:SetPoint("TOPRIGHT", item, "TOPRIGHT", 0, contentY - 2)
          contentY = contentY - item.Description:GetStringHeight() - 2
        end

        item.ValueShell:ClearAllPoints()
        item.ValueShell:SetPoint("TOPLEFT", item, "TOPLEFT", 0, contentY - 3)
        item.ValueShell:SetPoint("TOPRIGHT", item, "TOPRIGHT", 0, contentY - 3)
        item.Value:SetText("Current Binding: " .. formatBindingLabel(currentBinding))
        item.Value:SetTextColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3], 0.95)

        item.SetButton:SetScript("OnClick", function()
          self:StartKeyCapture(function(binding)
            if type(option.set) == "function" then
              option.set(binding, page, option)
            elseif option.path then
              AP.Database:Set(option.path, binding)
            end
            if type(option.onChange) == "function" then
              option.onChange(binding, page, option)
            end
            if self.onChanged then
              self.onChanged()
            end
          end, currentBinding)
        end)

        item.ClearButton:SetScript("OnClick", function()
          if type(option.set) == "function" then
            option.set("", page, option)
          elseif option.path then
            AP.Database:Set(option.path, "")
          end
          if type(option.onChange) == "function" then
            option.onChange("", page, option)
          end
          if self.onChanged then
            self.onChanged()
          end
        end)

        local valueTop = contentY - 3
        local height = math.abs(valueTop) + item.ValueShell:GetHeight() + 3 + item.SetButton:GetHeight()
        item:SetHeight(height)
        y = y - height - ITEM_GAP
      elseif optionType == "segmented" then
        segmentedIndex = segmentedIndex + 1
        local item = self:AcquireSegmented(segmentedIndex)
        item:ClearAllPoints()
        item:SetPoint("TOPLEFT", self.Child, "TOPLEFT", CONTENT_INSET, y)
        item:SetWidth(width)
        item:Show()

        local label = resolve(option.label, page, option) or "Rule"
        local description = resolve(option.description, page, option) or ""
        local choices = resolve(option.choices, page, option) or {}
        local currentValue
        if type(option.get) == "function" then
          currentValue = option.get(page, option)
        elseif option.path then
          currentValue = AP.Database:Get(option.path, option.default)
        end

        item.Label:SetWidth(width)
        item.Label:SetText(label)
        item.Label:SetTextColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], Theme.colors.text[4])

        item.Description:SetWidth(width)
        item.Description:SetText(description)
        item.Description:SetTextColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3], Theme.colors.muted[4])
        if description ~= "" then
          item.Description:Show()
        else
          item.Description:Hide()
        end

        local contentY = -item.Label:GetStringHeight()
        item.Description:ClearAllPoints()
        if description ~= "" then
          item.Description:SetPoint("TOPLEFT", item, "TOPLEFT", 0, contentY - 2)
          item.Description:SetPoint("TOPRIGHT", item, "TOPRIGHT", 0, contentY - 2)
          contentY = contentY - item.Description:GetStringHeight() - 2
        end

        local buttonGap = 4
        local buttonTop = contentY - 4
        local choiceCount = #choices
        local buttonWidth = choiceCount > 0 and math.floor((width - (buttonGap * (choiceCount - 1))) / choiceCount) or width
        for choiceIndex = 1, choiceCount do
          local choice = choices[choiceIndex]
          local button = item:AcquireChoice(choiceIndex)
          local color = Theme.colors[choice.color or "gold"] or Theme.colors.gold
          button.APButtonStyle = {
            background = Theme.colors.panel,
            border = { Theme.colors.border[1], Theme.colors.border[2], Theme.colors.border[3], 0.28 },
            text = Theme.colors.muted,
            hoverBackground = Theme.colors.hover,
            hoverBorder = color,
            hoverText = color,
            pressedBackground = Theme.colors.pressed,
            pressedBorder = color,
            pressedText = color,
            selectedBackground = Theme.colors.selection,
            selectedBorder = color,
            selectedText = color,
          }
          button:ClearAllPoints()
          button:SetPoint("TOPLEFT", item, "TOPLEFT", (choiceIndex - 1) * (buttonWidth + buttonGap), buttonTop)
          button:SetWidth(buttonWidth)
          button:SetText(resolve(choice.label, page, option) or tostring(choice.value or ""))
          button.APButtonSelected = currentValue == choice.value
          button:SetScript("OnClick", function()
            if type(option.set) == "function" then
              option.set(choice.value, page, option)
            elseif option.path then
              AP.Database:Set(option.path, choice.value)
            end
            if type(option.onChange) == "function" then
              option.onChange(choice.value, page, option)
            end
            if self.onChanged then
              self.onChanged()
            end
          end)
          Theme:RefreshButton(button)
          button:Show()
        end
        for choiceIndex = choiceCount + 1, #item.Buttons do
          item.Buttons[choiceIndex]:Hide()
        end

        local height = math.abs(buttonTop) + 20
        item:SetHeight(height)
        y = y - height - ITEM_GAP
      elseif optionType == "blacklist" then
        blacklistIndex = blacklistIndex + 1
        local item = self:AcquireBlacklist(blacklistIndex)
        item:ClearAllPoints()
        item:SetPoint("TOPLEFT", self.Child, "TOPLEFT", CONTENT_INSET, y)
        item:SetWidth(width)
        item:Show()

        local entries = {}
        if type(option.get) == "function" then
          entries = option.get(page, option) or {}
        end

        item.Label:SetWidth(width)
        item.Label:SetText(resolve(option.label, page, option) or "Blacklist")
        item.Label:SetTextColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], Theme.colors.text[4])

        item.Description:SetWidth(width)
        local description = resolve(option.description, page, option) or ""
        item.Description:SetText(description)
        item.Description:SetTextColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3], Theme.colors.muted[4])
        if description ~= "" then
          item.Description:Show()
        else
          item.Description:Hide()
        end

        local contentY = -item.Label:GetStringHeight()
        if description ~= "" then
          contentY = contentY - item.Description:GetStringHeight() - 2
        end
        item.DropBox:ClearAllPoints()
        item.DropBox:SetPoint("TOPLEFT", item, "TOPLEFT", 0, contentY - 3)
        item.DropBox:SetPoint("TOPRIGHT", item, "TOPRIGHT", 0, contentY - 3)
        item.DropText:SetText("Drag an item here to blacklist it")
        item.DropText:SetTextColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], Theme.colors.text[4])
        item.DropBox:SetScript("OnReceiveDrag", function()
          local cursorType, itemID, itemLink = GetCursorInfo()
          if cursorType ~= "item" then
            return
          end
          if type(option.onAdd) == "function" then
            option.onAdd(itemID, itemLink, page, option)
          end
          if ClearCursor then
            ClearCursor()
          end
          if self.onChanged then
            self.onChanged()
          end
        end)

        item.DropBox:SetScript("OnMouseUp", function()
          local cursorType, itemID, itemLink = GetCursorInfo()
          if cursorType ~= "item" then
            return
          end
          if type(option.onAdd) == "function" then
            option.onAdd(itemID, itemLink, page, option)
          end
          if ClearCursor then
            ClearCursor()
          end
          if self.onChanged then
            self.onChanged()
          end
        end)

        item.ClearButton:ClearAllPoints()
        item.ClearButton:SetPoint("TOPRIGHT", item.DropBox, "BOTTOMRIGHT", 0, -4)
        if #entries > 0 then
          item.ClearButton:Enable()
        else
          item.ClearButton:Disable()
        end
        Theme:RefreshButton(item.ClearButton)
        item.ClearButton:SetScript("OnClick", function()
          if type(option.onClear) == "function" then
            option.onClear(page, option)
          end
          if self.onChanged then
            self.onChanged()
          end
        end)

        local clearTop = contentY - 31
        local listY = clearTop - 23
        if #entries == 0 then
          item.Empty:Show()
          item.Empty:SetText("No blacklisted items.")
          item.Empty:ClearAllPoints()
          item.Empty:SetPoint("TOPLEFT", item, "TOPLEFT", 0, clearTop - 3)
          for rowIndex = 1, #item.rows do
            item.rows[rowIndex]:Hide()
          end
        else
          item.Empty:Hide()
          for entryIndex = 1, #entries do
            local entry = entries[entryIndex]
            local row = item:AcquireRow(entryIndex)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", item, "TOPLEFT", 0, listY)
            row:SetPoint("TOPRIGHT", item, "TOPRIGHT", 0, listY)
            row:Show()
            row.Text:SetText(entry.link or entry.name or ("Item #" .. tostring(entry.id)))
            row.Text:SetTextColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], Theme.colors.text[4])
            row.Remove:SetScript("OnClick", function()
              if type(option.onRemove) == "function" then
                option.onRemove(entry.id, page, option)
              end
              if self.onChanged then
                self.onChanged()
              end
            end)
            listY = listY - 22
          end
          for rowIndex = #entries + 1, #item.rows do
            item.rows[rowIndex]:Hide()
          end
        end

        local height
        if #entries > 0 then
          height = math.abs(listY) + 2
        else
          height = math.abs(clearTop) + 18
        end
        item:SetHeight(height)
        y = y - height - ITEM_GAP
      elseif optionType == "divider" then
        dividerIndex = dividerIndex + 1
        local item = self:AcquireDivider(dividerIndex)
        item:ClearAllPoints()
        item:SetPoint("TOPLEFT", self.Child, "TOPLEFT", CONTENT_INSET, y)
        item:SetWidth(width)
        item:SetHeight(1)
        item:Show()
        y = y - 6
      end
    end

    self.Child:SetHeight(math.abs(y) + 12)
    self.Scroll:SetVerticalScroll(math.max(0, targetScroll))
  end

  function frame:RenderSearch(query, results)
    if self.currentPageId then
      self.pageScroll[self.currentPageId] = self.Scroll:GetVerticalScroll() or 0
    end
    self.currentPageId = "__search__"
    self:HideAllItems()
    updateScrollChildWidth(self.Scroll, self.Child)
    self.Scroll:SetVerticalScroll(0)

    local width, y = self:LayoutHeader(
      "Search Results",
      string.format('Matches for "%s"', tostring(query or "")),
      nil
    )

    if #results == 0 then
      local item = self:AcquireText(1)
      item:ClearAllPoints()
      item:SetPoint("TOPLEFT", self.Child, "TOPLEFT", CONTENT_INSET, y)
      item:SetWidth(width)
      item:Show()
      item.Title:ClearAllPoints()
      item.Title:SetPoint("TOPLEFT", item, "TOPLEFT", 0, 0)
      item.Title:SetWidth(width)
      item.Title:SetText("No matching sections")
      item.Title:Show()
      item.Title:SetTextColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3], 1)
      item.SectionAccent:Hide()
      item.SectionRule:Hide()
      item.Body:ClearAllPoints()
      item.Body:SetPoint("TOPLEFT", item.Title, "BOTTOMLEFT", 0, -2)
      item.Body:SetWidth(width)
      item.Body:SetText("Try a class name, spec name, feature label, or option text.")
      item.Body:Show()
      item.Body:SetTextColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], Theme.colors.text[4])
      local height = item.Title:GetStringHeight() + item.Body:GetStringHeight() + 2
      item:SetHeight(height)
      self.Child:SetHeight(math.abs(y) + height + 12)
      return
    end

    for index = 1, #results do
      local result = results[index]
      local item = self:AcquireResult(index)
      item:ClearAllPoints()
      item:SetPoint("TOPLEFT", self.Child, "TOPLEFT", CONTENT_INSET, y)
      item:SetWidth(width)
      item:Show()

      item.Title:SetText(result.title or result.pageId)
      item.Title:SetTextColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3], 1)
      item.Path:SetText(result.path or "")
      item.Path:SetTextColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3], Theme.colors.muted[4])
      item.Summary:SetText(result.description or "Open this section.")
      item.Summary:SetTextColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], Theme.colors.text[4])

      item:SetScript("OnClick", function()
        if self.onSelectPage then
          self.onSelectPage(result.pageId)
        end
      end)

      local height = item.Title:GetStringHeight() + item.Path:GetStringHeight() + item.Summary:GetStringHeight() + 14
      item:SetHeight(height)
      y = y - height - ITEM_GAP
    end

    self.Child:SetHeight(math.abs(y) + 12)
  end

  return frame
end
