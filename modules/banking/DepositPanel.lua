local _, AP = ...
AP = AP or _G.AscensionPlus

local Banking = AP.Banking
local Categories = Banking.Categories
local Theme = AP.UI.Theme

local Panel = {
  buttons = {},
  modeButtons = {},
  mode = "deposit",
}

Panel.LAYOUT = {
  width = 220,
  categoryTop = 60,
  categoryButtonHeight = 24,
  categoryGap = 4,
  statusHeight = 34,
  statusBottom = 7,
  statusGutter = 9,
  popupGutter = 12,
}

Banking.Panel = Panel

local MEDIA = "Interface\\AddOns\\WotLK-Plus\\media\\banking\\"
local BUTTON_NORMAL = MEDIA .. "deposit-normal"
local BUTTON_HOVER = MEDIA .. "deposit-hover"
local BUTTON_PRESSED = MEDIA .. "deposit-pressed"
local BUTTON_RELEASE = MEDIA .. "deposit-release"

local MODES = {
  { id = "deposit", label = "DEPOSIT", width = 60 },
  { id = "withdraw", label = "WITHDRAW", width = 72 },
  { id = "pretend", label = "PRETEND", width = 62 },
}

function Panel:GetRequiredHeight()
  local layout = self.LAYOUT
  local buttonCount = #Categories.order
  local buttonArea = buttonCount * layout.categoryButtonHeight
    + math.max(0, buttonCount - 1) * layout.categoryGap
  return layout.categoryTop
    + buttonArea
    + layout.statusGutter
    + layout.statusHeight
    + layout.statusBottom
end

local function setTextColor(fontString, color)
  fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

local function setTextureToButton(texture, button, inset)
  if not texture then
    return
  end
  inset = inset or 0
  texture:ClearAllPoints()
  texture:SetPoint("TOPLEFT", button, "TOPLEFT", inset, -inset)
  texture:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -inset, inset)
end

local function releaseUpdate(button, elapsed)
  button.releaseTime = (button.releaseTime or 0) - elapsed
  if button.releaseTime <= 0 then
    button.ReleaseTexture:Hide()
    button:SetScript("OnUpdate", nil)
    return
  end

  button.ReleaseTexture:SetAlpha(button.releaseTime / 0.12)
end

function Panel:UpdateModeButtons()
  for index = 1, #self.modeButtons do
    local button = self.modeButtons[index]
    if button.modeID == self.mode then
      setTextColor(button.Label, Theme.colors.gold)
      button.Underline:Show()
    else
      setTextColor(button.Label, Theme.colors.muted)
      button.Underline:Hide()
    end
  end
end

function Panel:UpdateDestination()
  if not self.frame then
    return
  end

  local bankName = self.provider and self.provider:GetBankName() or "Bank"
  if self.mode == "withdraw" then
    self.frame.Destination:SetText("from " .. bankName)
  elseif self.mode == "pretend" then
    self.frame.Destination:SetText("audit Inventory + " .. bankName)
  else
    self.frame.Destination:SetText("to " .. bankName)
  end
end

function Panel:SetMode(mode)
  if mode ~= "deposit" and mode ~= "withdraw" and mode ~= "pretend" then
    return
  elseif Banking.Controller.processing then
    return
  end

  self.mode = mode
  self:UpdateModeButtons()
  self:UpdateDestination()
  if self.frame and self.frame:IsShown() then
    if mode == "pretend" then
      self:SetStatus("Choose what to inspect")
    elseif mode == "withdraw" then
      self:SetStatus("Choose what to withdraw")
    else
      self:SetStatus("Choose what to deposit")
    end
  end
end

function Panel:GetMode()
  return self.mode
end

function Panel:CreateModeButton(parent, mode, previous)
  local button = CreateFrame("Button", nil, parent)
  button:SetWidth(mode.width)
  button:SetHeight(21)
  button:RegisterForClicks("LeftButtonUp")
  button.modeID = mode.id

  if previous then
    button:SetPoint("LEFT", previous, "RIGHT", 1, 0)
  else
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -7)
  end

  button.Label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  button.Label:SetAllPoints(button)
  button.Label:SetJustifyH("CENTER")
  button.Label:SetText(mode.label)
  button.Label:SetShadowColor(0, 0, 0, 1)
  button.Label:SetShadowOffset(1, -1)

  button.Underline = button:CreateTexture(nil, "ARTWORK")
  button.Underline:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 5, 1)
  button.Underline:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -5, 1)
  button.Underline:SetHeight(1)
  Theme:Paint(button.Underline, Theme.colors.gold)

  button:SetScript("OnClick", function(self)
    Panel:SetMode(self.modeID)
  end)
  button:SetScript("OnEnter", function(self)
    if self:IsEnabled() then
      setTextColor(self.Label, Theme.colors.gold)
    end
  end)
  button:SetScript("OnLeave", function()
    button.Label:ClearAllPoints()
    button.Label:SetAllPoints(button)
    Panel:UpdateModeButtons()
  end)
  button:SetScript("OnMouseDown", function(self)
    if self:IsEnabled() then
      setTextColor(self.Label, Theme.colors.orange)
      self.Label:ClearAllPoints()
      self.Label:SetPoint("CENTER", self, "CENTER", 1, -1)
    end
  end)
  button:SetScript("OnMouseUp", function(self)
    self.Label:ClearAllPoints()
    self.Label:SetAllPoints(self)
    Panel:UpdateModeButtons()
  end)

  self.modeButtons[#self.modeButtons + 1] = button
  return button
end

function Panel:CreateButton(parent, categoryID, previous)
  local layout = self.LAYOUT
  local definition = Categories.definitions[categoryID]
  local button = CreateFrame("Button", nil, parent)
  button:SetWidth(196)
  button:SetHeight(layout.categoryButtonHeight)
  button:RegisterForClicks("LeftButtonUp")
  button.categoryID = categoryID
  Theme:ApplyBackdrop(button, Theme.colors.inset, Theme.colors.border)

  if previous then
    button:SetPoint("TOP", previous, "BOTTOM", 0, -layout.categoryGap)
  else
    button:SetPoint("TOP", parent, "TOP", 0, -layout.categoryTop)
  end

  button:SetNormalTexture(BUTTON_NORMAL)
  button:SetHighlightTexture(BUTTON_HOVER, "BLEND")
  button:SetPushedTexture(BUTTON_PRESSED)
  button:SetDisabledTexture(BUTTON_NORMAL)
  setTextureToButton(button:GetNormalTexture(), button, 2)
  setTextureToButton(button:GetHighlightTexture(), button, 2)
  setTextureToButton(button:GetPushedTexture(), button, 2)
  setTextureToButton(button:GetDisabledTexture(), button, 2)
  if button:GetDisabledTexture() then
    button:GetDisabledTexture():SetVertexColor(0.45, 0.45, 0.45, 0.75)
  end

  button.ReleaseTexture = button:CreateTexture(nil, "ARTWORK")
  button.ReleaseTexture:SetTexture(BUTTON_RELEASE)
  setTextureToButton(button.ReleaseTexture, button, 2)
  button.ReleaseTexture:Hide()

  button:SetText(string.upper(definition.title))
  local fontString = button:GetFontString()
  if fontString then
    fontString:SetFontObject(_G.GameFontNormalSmall)
    fontString:SetTextColor(0.96, 0.88, 0.63, 1)
    fontString:SetShadowColor(0, 0, 0, 1)
    fontString:SetShadowOffset(1, -1)
  end

  button:SetScript("OnClick", function(self)
    Banking.Controller:RunCategory(self.categoryID, Panel:GetMode())
  end)
  button:SetScript("OnMouseUp", function(self)
    if self:IsEnabled() then
      self:SetBackdropBorderColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3], 0.72)
      self.releaseTime = 0.12
      self.ReleaseTexture:SetAlpha(1)
      self.ReleaseTexture:Show()
      self:SetScript("OnUpdate", releaseUpdate)
    end
  end)
  button:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3], 0.82)
    if not AP.Database:Get("banking.deposit.showTooltips", true) then
      return
    end

    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(definition.title, Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3])
    local lines = Categories:GetTooltipLines(self.categoryID)
    for index = 1, #lines do
      GameTooltip:AddLine(lines[index], 0.88, 0.90, 0.95, true)
    end

    local allButton = self.categoryID == "all"
    if Banking.Controller.processing and Banking.Controller.category == self.categoryID then
      GameTooltip:AddLine("Click again to cancel the active " .. tostring(Banking.Controller.operation or "transfer") .. ".", 1, 0.55, 0.35, true)
    elseif Panel.mode == "withdraw" then
      GameTooltip:AddLine(allButton
        and "Click to withdraw every transferable stack from the open bank or visible tab."
        or "Click to withdraw matching stacks from the open bank or visible tab.", 0.46, 0.82, 0.55, true)
    elseif Panel.mode == "pretend" then
      GameTooltip:AddLine(allButton
        and "Click to audit every stack in both directions and open a copyable report. Nothing moves."
        or "Click to audit both directions and open a copyable report. Nothing moves.", 0.46, 0.82, 0.55, true)
    else
      GameTooltip:AddLine(allButton
        and "Click to deposit every transferable inventory stack."
        or "Click to deposit matching inventory stacks.", 0.46, 0.82, 0.55, true)
    end
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(Theme.colors.border[1], Theme.colors.border[2], Theme.colors.border[3], Theme.colors.border[4] or 1)
    if not GameTooltip.GetOwner or GameTooltip:GetOwner() == self then
      GameTooltip:Hide()
    end
  end)

  self.buttons[#self.buttons + 1] = button
  self.buttonByCategory[categoryID] = button
  return button
end

function Panel:Create()
  if self.frame then
    return self.frame
  end

  local frame = CreateFrame("Frame", "WotLKPlusBankDepositPanel", UIParent)
  Theme:ApplyBackdrop(frame, Theme.colors.panel, Theme.colors.border)
  frame:SetWidth(self.LAYOUT.width)
  frame:SetHeight(self:GetRequiredHeight())
  frame:SetFrameStrata("DIALOG")
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:Hide()

  local previousMode
  for index = 1, #MODES do
    previousMode = self:CreateModeButton(frame, MODES[index], previousMode)
  end

  frame.Destination = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  frame.Destination:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -31)
  frame.Destination:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
  frame.Destination:SetJustifyH("LEFT")
  frame.Destination:SetText("to Bank")

  frame.Divider = frame:CreateTexture(nil, "ARTWORK")
  frame.Divider:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -51)
  frame.Divider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -51)
  frame.Divider:SetHeight(1)
  Theme:Paint(frame.Divider, Theme.colors.line)

  self.frame = frame
  self.buttonByCategory = {}
  local previous
  for index = 1, #Categories.order do
    previous = self:CreateButton(frame, Categories.order[index], previous)
  end

  frame.Status = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  frame.Status:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, self.LAYOUT.statusBottom)
  frame.Status:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, self.LAYOUT.statusBottom)
  frame.Status:SetHeight(self.LAYOUT.statusHeight)
  frame.Status:SetJustifyH("CENTER")
  frame.Status:SetJustifyV("MIDDLE")
  frame.Status:SetText("Ready")

  self:UpdateModeButtons()
  if AP.BankingElvUI then
    AP.BankingElvUI:Apply(frame)
  end
  return frame
end

local function getFrameEdge(frame, method, fallback)
  if frame and type(frame[method]) == "function" then
    local value = frame[method](frame)
    if value then
      return value
    end
  end
  return fallback
end

function Panel:GetPopupPlacement(popup)
  local screenLeft = getFrameEdge(UIParent, "GetLeft", 0)
  local screenRight = getFrameEdge(UIParent, "GetRight", getFrameEdge(UIParent, "GetWidth", 0))
  local screenBottom = getFrameEdge(UIParent, "GetBottom", 0)
  local screenTop = getFrameEdge(UIParent, "GetTop", getFrameEdge(UIParent, "GetHeight", 0))
  local popupLeft = getFrameEdge(popup, "GetLeft", screenLeft)
  local popupRight = getFrameEdge(popup, "GetRight", popupLeft)
  local popupBottom = getFrameEdge(popup, "GetBottom", screenBottom)
  local popupTop = getFrameEdge(popup, "GetTop", screenTop)
  local gutter = self.LAYOUT.popupGutter
  local neededWidth = self.LAYOUT.width + gutter
  local neededHeight = self:GetRequiredHeight() + gutter

  if screenRight - popupRight >= neededWidth then
    return "right"
  elseif popupLeft - screenLeft >= neededWidth then
    return "left"
  elseif popupBottom - screenBottom >= neededHeight then
    return "below"
  elseif screenTop - popupTop >= neededHeight then
    return "above"
  end

  local horizontalSpace = math.max(screenRight - popupRight, popupLeft - screenLeft)
  local verticalSpace = math.max(popupBottom - screenBottom, screenTop - popupTop)
  if horizontalSpace >= verticalSpace then
    return (screenRight - popupRight) >= (popupLeft - screenLeft) and "right" or "left"
  end
  return (popupBottom - screenBottom) >= (screenTop - popupTop) and "below" or "above"
end

function Panel:AnchorToPopup(frame, popup)
  local placement = self:GetPopupPlacement(popup)
  local gutter = self.LAYOUT.popupGutter

  if placement == "left" then
    frame:SetPoint("TOPRIGHT", popup, "TOPLEFT", -gutter, 0)
  elseif placement == "below" then
    frame:SetPoint("TOP", popup, "BOTTOM", 0, -gutter)
  elseif placement == "above" then
    frame:SetPoint("BOTTOM", popup, "TOP", 0, gutter)
  else
    frame:SetPoint("TOPLEFT", popup, "TOPRIGHT", gutter, 0)
  end
end

function Panel:RefreshAnchor()
  if not self.frame or not self.frame:IsShown() or not self.provider then
    return
  end
  self:AnchorToHost(self.provider:GetHostFrame(), self.provider)
end

function Panel:WatchGuildBankPopup()
  local popup = _G.GuildBankPopupFrame
  if not popup or self.popupHooked == popup or type(popup.HookScript) ~= "function" then
    return
  end

  self.popupHooked = popup
  popup:HookScript("OnShow", function()
    Panel:RefreshAnchor()
  end)
  popup:HookScript("OnHide", function()
    Panel:RefreshAnchor()
  end)
end

function Panel:AnchorToHost(host, provider)
  local frame = self:Create()
  frame:ClearAllPoints()

  if not host then
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    return
  end

  local popup = _G.GuildBankPopupFrame
  if provider == Banking.providers.guildStyle and popup and popup:IsShown() then
    self:AnchorToPopup(frame, popup)
    return
  end

  local hostCenter = host:GetCenter()
  local screenCenter = UIParent:GetCenter()
  if hostCenter and screenCenter and hostCenter > screenCenter then
    frame:SetPoint("TOPRIGHT", host, "TOPLEFT", -5, -12)
  else
    local clearance = 5
    if provider and type(provider.GetPanelRightClearance) == "function" then
      clearance = provider:GetPanelRightClearance() or clearance
    end
    frame:SetPoint("TOPLEFT", host, "TOPRIGHT", clearance, -12)
  end
end

function Panel:ShowForProvider(provider)
  local frame = self:Create()
  self.provider = provider
  self:WatchGuildBankPopup()
  self:UpdateDestination()
  self:AnchorToHost(provider and provider:GetHostFrame(), provider)
  if AP.BankingElvUI then
    AP.BankingElvUI:Apply(frame)
  end
  frame:Show()
end

function Panel:Hide()
  if self.frame then
    self.frame:Hide()
  end
  local owner = GameTooltip.GetOwner and GameTooltip:GetOwner()
  if owner and owner.categoryID and self.buttonByCategory and self.buttonByCategory[owner.categoryID] == owner then
    GameTooltip:Hide()
  end
end

function Panel:SetStatus(text)
  local frame = self:Create()
  frame.Status:SetText(text or "Ready")
end

function Panel:SetBusy(categoryID, operation)
  self:Create()
  if categoryID and operation and self.mode ~= operation then
    self.mode = operation
    self:UpdateModeButtons()
    self:UpdateDestination()
  end

  for index = 1, #self.modeButtons do
    if categoryID then
      self.modeButtons[index]:Disable()
    else
      self.modeButtons[index]:Enable()
    end
  end

  for index = 1, #self.buttons do
    local button = self.buttons[index]
    if categoryID and button.categoryID ~= categoryID then
      button:Disable()
    else
      button:Enable()
    end

    local fontString = button:GetFontString()
    if fontString then
      if categoryID == button.categoryID then
        fontString:SetTextColor(1, 0.65, 0.35, 1)
      elseif categoryID then
        fontString:SetTextColor(0.48, 0.48, 0.48, 1)
      else
        fontString:SetTextColor(0.96, 0.88, 0.63, 1)
      end
    end
  end
end
