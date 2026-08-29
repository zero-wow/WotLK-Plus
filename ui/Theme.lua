local _, AP = ...
AP = AP or _G.AscensionPlus

local Theme = {
  texture = "Interface\\Buttons\\WHITE8x8",
  spacing = {
    xsmall = 4,
    small = 8,
    medium = 12,
    large = 16,
  },
  colors = {
    background = { 0.035, 0.047, 0.065, 0.985 },
    panel = { 0.055, 0.075, 0.102, 0.98 },
    surface = { 0.070, 0.094, 0.125, 0.96 },
    sidebar = { 0.027, 0.038, 0.054, 0.99 },
    inset = { 0.020, 0.029, 0.043, 0.98 },
    titlebar = { 0.043, 0.059, 0.082, 0.99 },
    border = { 0.82, 0.71, 0.41, 0.38 },
    line = { 0.82, 0.71, 0.41, 0.17 },
    neutralLine = { 0.24, 0.29, 0.36, 0.42 },
    selection = { 0.21, 0.18, 0.10, 0.82 },
    hover = { 0.16, 0.14, 0.09, 0.48 },
    pressed = { 0.27, 0.20, 0.08, 0.95 },
    disabled = { 0.055, 0.064, 0.078, 0.80 },
    text = { 0.91, 0.90, 0.86, 1.00 },
    muted = { 0.57, 0.61, 0.67, 1.00 },
    gold = { 0.87, 0.73, 0.39, 1.00 },
    green = { 0.46, 0.82, 0.55, 1.00 },
    orange = { 1.00, 0.77, 0.38, 1.00 },
    red = { 0.93, 0.40, 0.40, 1.00 },
  },
}

AP.UI.Theme = Theme

function Theme:ApplyBackdrop(frame, bgColor, borderColor)
  if not frame or not frame.SetBackdrop then
    return
  end

  frame:SetBackdrop({
    bgFile = self.texture,
    edgeFile = self.texture,
    tile = false,
    edgeSize = 1,
    insets = {
      left = 1,
      right = 1,
      top = 1,
      bottom = 1,
    },
  })

  local bg = bgColor or self.colors.panel
  local border = borderColor or self.colors.border
  frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
  frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
end

function Theme:Paint(texture, color)
  if not texture then
    return
  end

  local shade = color or self.colors.line
  texture:SetTexture(self.texture)
  texture:SetVertexColor(shade[1], shade[2], shade[3], shade[4] or 1)
end

function Theme:TrySetTitleFont(fontString, size)
  if not fontString or not fontString.SetFont then
    return
  end

  pcall(fontString.SetFont, fontString, "Fonts\\MORPHEUS.TTF", size or 20, "")
end

function Theme:FadeIn(frame, duration)
  if not frame then
    return
  end

  if type(UIFrameFadeIn) == "function" then
    UIFrameFadeIn(frame, duration or 0.12, 0, 1)
  elseif frame.SetAlpha then
    frame:SetAlpha(1)
  end
end

function Theme:GetQualityColor(quality)
  local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[tonumber(quality) or -1]
  if color then
    return color.r or color[1] or 1, color.g or color[2] or 1, color.b or color[3] or 1
  end
  return self.colors.muted[1], self.colors.muted[2], self.colors.muted[3]
end

local function setBackdropColors(frame, background, border)
  if not frame or not frame.SetBackdropColor then
    return
  end

  frame:SetBackdropColor(background[1], background[2], background[3], background[4] or 1)
  frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
end

local function isControlEnabled(control)
  if not control or not control.IsEnabled then
    return true
  end

  local enabled = control:IsEnabled()
  return enabled == true or enabled == 1
end

function Theme:StripTextures(frame)
  if not frame then
    return
  end

  local textureSetters = {
    "SetNormalTexture",
    "SetPushedTexture",
    "SetHighlightTexture",
    "SetDisabledTexture",
    "SetCheckedTexture",
    "SetDisabledCheckedTexture",
  }
  for index = 1, #textureSetters do
    local setter = frame[textureSetters[index]]
    if setter then
      setter(frame, nil)
    end
  end

  if frame.GetNumRegions and frame.GetRegions then
    for index = 1, frame:GetNumRegions() do
      local region = select(index, frame:GetRegions())
      if region and region.IsObjectType and region:IsObjectType("Texture") then
        region:SetTexture(nil)
        region:SetAlpha(0)
      end
    end
  end

  local pieces = { "Left", "Middle", "Right", "Center" }
  local frameName = frame.GetName and frame:GetName()
  for index = 1, #pieces do
    local piece = frame[pieces[index]]
    if not piece and frameName then
      piece = _G[frameName .. pieces[index]]
    end
    if piece and piece.SetAlpha then
      piece:SetAlpha(0)
    end
  end
end

function Theme:RefreshButton(button)
  local style = button and button.APButtonStyle
  if not style then
    return
  end

  local background = style.background or self.colors.panel
  local border = style.border or self.colors.border
  local textColor = style.text or self.colors.text

  if not isControlEnabled(button) then
    background = style.disabledBackground or self.colors.disabled
    border = style.disabledBorder or { self.colors.border[1], self.colors.border[2], self.colors.border[3], 0.16 }
    textColor = style.disabledText or { self.colors.muted[1], self.colors.muted[2], self.colors.muted[3], 0.45 }
  elseif button.APButtonPressed then
    background = style.pressedBackground or self.colors.pressed
    border = style.pressedBorder or self.colors.gold
    textColor = style.pressedText or self.colors.gold
  elseif button.APButtonHovered then
    background = style.hoverBackground or self.colors.selection
    border = style.hoverBorder or self.colors.gold
    textColor = style.hoverText or self.colors.gold
  elseif button.APButtonSelected then
    background = style.selectedBackground or self.colors.selection
    border = style.selectedBorder or self.colors.gold
    textColor = style.selectedText or self.colors.gold
  end

  setBackdropColors(button, background, border)
  local fontString = button.GetFontString and button:GetFontString()
  if fontString then
    fontString:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4] or 1)
  end
end

function Theme:SkinButton(button, style)
  if not button or button.APThemedButton then
    return
  end

  self:StripTextures(button)
  self:ApplyBackdrop(button, self.colors.panel, self.colors.border)
  button.APThemedButton = true
  button.APButtonStyle = style or {}

  if button.SetNormalFontObject then
    button:SetNormalFontObject(GameFontHighlightSmall)
  end
  if button.SetHighlightFontObject then
    button:SetHighlightFontObject(GameFontHighlightSmall)
  end
  if button.SetDisabledFontObject then
    button:SetDisabledFontObject(GameFontDisableSmall)
  end
  if button.SetText and button.GetText then
    button:SetText(button:GetText() or "")
  end

  button:HookScript("OnEnter", function(self)
    self.APButtonHovered = true
    Theme:RefreshButton(self)
  end)
  button:HookScript("OnLeave", function(self)
    self.APButtonHovered = false
    self.APButtonPressed = false
    Theme:RefreshButton(self)
  end)
  button:HookScript("OnMouseDown", function(self)
    if isControlEnabled(self) then
      self.APButtonPressed = true
      Theme:RefreshButton(self)
    end
  end)
  button:HookScript("OnMouseUp", function(self)
    self.APButtonPressed = false
    Theme:RefreshButton(self)
  end)
  button:HookScript("OnEnable", function(self)
    Theme:RefreshButton(self)
  end)
  button:HookScript("OnDisable", function(self)
    Theme:RefreshButton(self)
  end)
  button:HookScript("OnShow", function(self)
    Theme:RefreshButton(self)
  end)

  self:RefreshButton(button)
end

function Theme:RefreshCloseButton(button)
  if not button or not button.Text then
    return
  end

  local color = self.colors.muted
  if not isControlEnabled(button) then
    color = { self.colors.muted[1], self.colors.muted[2], self.colors.muted[3], 0.35 }
  elseif button.APClosePressed then
    color = self.colors.red
  elseif button.APCloseHovered then
    color = self.colors.gold
  end
  button.Text:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

function Theme:SkinCloseButton(button, label)
  if not button or button.APThemedClose then
    return
  end

  self:StripTextures(button)
  button.APThemedClose = true
  button.Text = button.Text or button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  button.Text:ClearAllPoints()
  button.Text:SetPoint("CENTER", button, "CENTER", 0, 0)
  button.Text:SetText(label or "x")
  button.Text:SetShadowColor(0, 0, 0, 1)
  button.Text:SetShadowOffset(1, -1)

  button:HookScript("OnEnter", function(self)
    self.APCloseHovered = true
    Theme:RefreshCloseButton(self)
  end)
  button:HookScript("OnLeave", function(self)
    self.APCloseHovered = false
    self.APClosePressed = false
    Theme:RefreshCloseButton(self)
  end)
  button:HookScript("OnMouseDown", function(self)
    self.APClosePressed = true
    Theme:RefreshCloseButton(self)
  end)
  button:HookScript("OnMouseUp", function(self)
    self.APClosePressed = false
    Theme:RefreshCloseButton(self)
  end)
  button:HookScript("OnEnable", function(self)
    Theme:RefreshCloseButton(self)
  end)
  button:HookScript("OnDisable", function(self)
    Theme:RefreshCloseButton(self)
  end)

  self:RefreshCloseButton(button)
end

function Theme:RefreshCheckButton(checkButton)
  if not checkButton or not checkButton.APCheckFill then
    return
  end

  local enabled = isControlEnabled(checkButton)
  local checked = checkButton:GetChecked() and true or false
  checkButton.APCheckFill:ClearAllPoints()
  if checked then
    checkButton.APCheckFill:SetPoint("RIGHT", checkButton, "RIGHT", -3, 0)
    self:Paint(checkButton.APCheckFill, self.colors.gold)
  else
    checkButton.APCheckFill:SetPoint("LEFT", checkButton, "LEFT", 3, 0)
    self:Paint(checkButton.APCheckFill, self.colors.muted)
  end
  checkButton.APCheckFill:Show()

  if not enabled then
    checkButton.APCheckFill:SetAlpha(0.35)
    setBackdropColors(checkButton, self.colors.disabled, { self.colors.border[1], self.colors.border[2], self.colors.border[3], 0.16 })
  elseif checkButton.APCheckHovered then
    checkButton.APCheckFill:SetAlpha(1)
    setBackdropColors(checkButton, checked and self.colors.selection or self.colors.surface, self.colors.gold)
  else
    checkButton.APCheckFill:SetAlpha(1)
    setBackdropColors(checkButton, checked and self.colors.selection or self.colors.inset, checked and self.colors.gold or self.colors.border)
  end
end

function Theme:SkinCheckButton(checkButton)
  if not checkButton or checkButton.APThemedCheck then
    return
  end

  self:StripTextures(checkButton)
  self:ApplyBackdrop(checkButton, self.colors.inset, self.colors.border)
  checkButton.APThemedCheck = true

  checkButton.APCheckFill = checkButton:CreateTexture(nil, "ARTWORK")
  checkButton.APCheckFill:SetWidth(14)
  checkButton.APCheckFill:SetHeight(14)
  self:Paint(checkButton.APCheckFill, self.colors.gold)

  checkButton.APCheckHover = checkButton:CreateTexture(nil, "HIGHLIGHT")
  checkButton.APCheckHover:SetPoint("TOPLEFT", checkButton, "TOPLEFT", 1, -1)
  checkButton.APCheckHover:SetPoint("BOTTOMRIGHT", checkButton, "BOTTOMRIGHT", -1, 1)
  self:Paint(checkButton.APCheckHover, { self.colors.gold[1], self.colors.gold[2], self.colors.gold[3], 0.12 })

  checkButton:HookScript("OnClick", function(self)
    Theme:RefreshCheckButton(self)
  end)
  checkButton:HookScript("OnEnter", function(self)
    self.APCheckHovered = true
    Theme:RefreshCheckButton(self)
  end)
  checkButton:HookScript("OnLeave", function(self)
    self.APCheckHovered = false
    Theme:RefreshCheckButton(self)
  end)
  checkButton:HookScript("OnEnable", function(self)
    Theme:RefreshCheckButton(self)
  end)
  checkButton:HookScript("OnDisable", function(self)
    Theme:RefreshCheckButton(self)
  end)

  self:RefreshCheckButton(checkButton)
end

function Theme:SetCheckButtonChecked(checkButton, checked)
  if not checkButton then
    return
  end

  checkButton:SetChecked(checked and true or false)
  self:RefreshCheckButton(checkButton)
end

function Theme:SkinScrollFrame(scrollFrame)
  if not scrollFrame or scrollFrame.APThemedScroll then
    return
  end

  local frameName = scrollFrame.GetName and scrollFrame:GetName()
  local scrollBar = scrollFrame.ScrollBar
  if not scrollBar and frameName then
    scrollBar = _G[frameName .. "ScrollBar"]
  end
  if not scrollBar then
    return
  end

  local scrollBarName = scrollBar.GetName and scrollBar:GetName()
  local upButton = scrollFrame.ScrollUpButton
  local downButton = scrollFrame.ScrollDownButton
  if scrollBarName then
    upButton = upButton or _G[scrollBarName .. "ScrollUpButton"] or _G[scrollBarName .. "UpButton"]
    downButton = downButton or _G[scrollBarName .. "ScrollDownButton"] or _G[scrollBarName .. "DownButton"]
  end

  self:StripTextures(scrollBar)
  self:ApplyBackdrop(scrollBar, self.colors.inset, { self.colors.border[1], self.colors.border[2], self.colors.border[3], 0.28 })
  scrollBar:SetWidth(12)
  scrollBar:ClearAllPoints()
  scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 5, -15)
  scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 5, 15)

  if scrollBar.SetThumbTexture then
    scrollBar:SetThumbTexture(self.texture)
  end
  local thumb = scrollBar.GetThumbTexture and scrollBar:GetThumbTexture()
  if not thumb and scrollBarName then
    thumb = _G[scrollBarName .. "ThumbTexture"]
  end
  if thumb then
    thumb:SetTexture(self.texture)
    thumb:SetVertexColor(self.colors.gold[1], self.colors.gold[2], self.colors.gold[3], 0.82)
    thumb:SetWidth(8)
    thumb:SetHeight(24)
    thumb:SetAlpha(1)
  end

  local arrowStyle = {
    background = self.colors.panel,
    hoverBackground = self.colors.selection,
    pressedBackground = self.colors.pressed,
    border = { self.colors.border[1], self.colors.border[2], self.colors.border[3], 0.32 },
    text = self.colors.muted,
  }
  if upButton then
    self:SkinButton(upButton, arrowStyle)
    upButton:SetText("^")
    upButton:SetWidth(12)
    upButton:SetHeight(12)
    upButton:ClearAllPoints()
    upButton:SetPoint("BOTTOM", scrollBar, "TOP", 0, 2)
    self:RefreshButton(upButton)
  end
  if downButton then
    self:SkinButton(downButton, arrowStyle)
    downButton:SetText("v")
    downButton:SetWidth(12)
    downButton:SetHeight(12)
    downButton:ClearAllPoints()
    downButton:SetPoint("TOP", scrollBar, "BOTTOM", 0, -2)
    self:RefreshButton(downButton)
  end

  scrollBar:HookScript("OnEnter", function(self)
    self:SetBackdropBorderColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3], 0.72)
  end)
  scrollBar:HookScript("OnLeave", function(self)
    self:SetBackdropBorderColor(Theme.colors.border[1], Theme.colors.border[2], Theme.colors.border[3], 0.28)
  end)

  scrollFrame.APThemedScroll = true
  scrollFrame.APScrollBar = scrollBar
end

function Theme:SkinEditBox(editBox, shell)
  if not editBox or editBox.APThemedEditBox then
    return
  end

  editBox.APThemedEditBox = true
  editBox.APEditShell = shell
  if editBox.SetTextInsets then
    editBox:SetTextInsets(4, 4, 0, 0)
  end

  local function refresh(self)
    local target = self.APEditShell
    if not target or not target.SetBackdropBorderColor then
      return
    end
    if self:HasFocus() then
      target:SetBackdropBorderColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3], 0.95)
      target:SetBackdropColor(Theme.colors.inset[1], Theme.colors.inset[2], Theme.colors.inset[3], 1)
    elseif self.APEditHovered then
      target:SetBackdropBorderColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3], 0.68)
      target:SetBackdropColor(Theme.colors.panel[1], Theme.colors.panel[2], Theme.colors.panel[3], Theme.colors.panel[4])
    else
      target:SetBackdropBorderColor(Theme.colors.border[1], Theme.colors.border[2], Theme.colors.border[3], Theme.colors.border[4])
      target:SetBackdropColor(Theme.colors.inset[1], Theme.colors.inset[2], Theme.colors.inset[3], Theme.colors.inset[4])
    end
  end

  editBox:HookScript("OnEnter", function(self)
    self.APEditHovered = true
    refresh(self)
  end)
  editBox:HookScript("OnLeave", function(self)
    self.APEditHovered = false
    refresh(self)
  end)
  editBox:HookScript("OnEditFocusGained", refresh)
  editBox:HookScript("OnEditFocusLost", refresh)
  editBox:HookScript("OnShow", refresh)
  refresh(editBox)
end

function Theme:SkinDropTarget(control)
  if not control or control.APThemedDropTarget then
    return
  end

  self:StripTextures(control)
  self:ApplyBackdrop(control, self.colors.panel, self.colors.border)
  control.APThemedDropTarget = true
  control.APDropHover = control:CreateTexture(nil, "HIGHLIGHT")
  control.APDropHover:SetPoint("TOPLEFT", control, "TOPLEFT", 1, -1)
  control.APDropHover:SetPoint("BOTTOMRIGHT", control, "BOTTOMRIGHT", -1, 1)
  self:Paint(control.APDropHover, { self.colors.gold[1], self.colors.gold[2], self.colors.gold[3], 0.10 })
  control:HookScript("OnEnter", function(self)
    self:SetBackdropBorderColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3], 0.9)
  end)
  control:HookScript("OnLeave", function(self)
    self:SetBackdropBorderColor(Theme.colors.border[1], Theme.colors.border[2], Theme.colors.border[3], Theme.colors.border[4])
  end)
end

function Theme:SkinListRow(row)
  if not row or row.APThemedListRow then
    return
  end

  self:StripTextures(row)
  row.APThemedListRow = true
  row.APRowBackground = row.Bg or row:CreateTexture(nil, "BACKGROUND")
  row.APRowBackground:SetAllPoints(row)
  row.APRowBackground:SetAlpha(1)
  self:Paint(row.APRowBackground, { 0, 0, 0, 0 })

  row.APRowHover = row:CreateTexture(nil, "HIGHLIGHT")
  row.APRowHover:SetAllPoints(row)
  self:Paint(row.APRowHover, { self.colors.gold[1], self.colors.gold[2], self.colors.gold[3], 0.10 })

  row.APRowAccent = row:CreateTexture(nil, "ARTWORK")
  row.APRowAccent:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
  row.APRowAccent:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
  row.APRowAccent:SetWidth(2)
  self:Paint(row.APRowAccent, self.colors.gold)
  row.APRowAccent:Hide()
end

function Theme:SetListRowState(row, selected, matched)
  if not row then
    return
  end
  self:SkinListRow(row)

  if selected then
    self:Paint(row.APRowBackground, self.colors.selection)
    row.APRowAccent:Show()
  elseif matched then
    self:Paint(row.APRowBackground, { self.colors.hover[1], self.colors.hover[2], self.colors.hover[3], 0.35 })
    row.APRowAccent:Hide()
  else
    self:Paint(row.APRowBackground, { 0, 0, 0, 0 })
    row.APRowAccent:Hide()
  end
end

function Theme:SkinResultRow(row)
  if not row or row.APThemedResultRow then
    return
  end

  self:StripTextures(row)
  self:ApplyBackdrop(row, { 0.06, 0.07, 0.09, 0.82 }, { self.colors.border[1], self.colors.border[2], self.colors.border[3], 0.24 })
  row.APThemedResultRow = true
  row.APResultHover = row:CreateTexture(nil, "HIGHLIGHT")
  row.APResultHover:SetPoint("TOPLEFT", row, "TOPLEFT", 1, -1)
  row.APResultHover:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -1, 1)
  self:Paint(row.APResultHover, { self.colors.gold[1], self.colors.gold[2], self.colors.gold[3], 0.10 })
  row.APResultAccent = row:CreateTexture(nil, "ARTWORK")
  row.APResultAccent:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
  row.APResultAccent:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
  row.APResultAccent:SetWidth(2)
  self:Paint(row.APResultAccent, { self.colors.gold[1], self.colors.gold[2], self.colors.gold[3], 0.72 })
  row:HookScript("OnEnter", function(self)
    self:SetBackdropBorderColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3], 0.64)
  end)
  row:HookScript("OnLeave", function(self)
    self:SetBackdropBorderColor(Theme.colors.border[1], Theme.colors.border[2], Theme.colors.border[3], 0.24)
  end)
end

function Theme:RefreshResizeGrip(grip)
  if not grip or not grip.APGripTextures then
    return
  end

  local color = self.colors.muted
  if grip.APGripPressed then
    color = self.colors.red
  elseif grip.APGripHovered then
    color = self.colors.gold
  end
  for index = 1, #grip.APGripTextures do
    self:Paint(grip.APGripTextures[index], color)
  end
end

function Theme:SkinResizeGrip(grip)
  if not grip or grip.APThemedResizeGrip then
    return
  end

  self:StripTextures(grip)
  grip.APThemedResizeGrip = true
  grip.APGripTextures = {}
  for index = 1, 3 do
    local mark = grip:CreateTexture(nil, "ARTWORK")
    mark:SetWidth(2)
    mark:SetHeight(2)
    mark:SetPoint("BOTTOMRIGHT", grip, "BOTTOMRIGHT", -1 - ((index - 1) * 4), 1 + ((index - 1) * 4))
    grip.APGripTextures[index] = mark
  end
  grip:HookScript("OnEnter", function(self)
    self.APGripHovered = true
    Theme:RefreshResizeGrip(self)
  end)
  grip:HookScript("OnLeave", function(self)
    self.APGripHovered = false
    self.APGripPressed = false
    Theme:RefreshResizeGrip(self)
  end)
  grip:HookScript("OnMouseDown", function(self)
    self.APGripPressed = true
    Theme:RefreshResizeGrip(self)
  end)
  grip:HookScript("OnMouseUp", function(self)
    self.APGripPressed = false
    Theme:RefreshResizeGrip(self)
  end)
  self:RefreshResizeGrip(grip)
end
