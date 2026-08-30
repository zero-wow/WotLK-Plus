local _, AP = ...
AP = AP or _G.WotLKPlus or _G.AscensionPlus

local Theme = AP.UI.Theme
local Discovery = AP.MinimapPaletteDiscovery

local Palette = {
  enabled = false,
  entries = {},
  rows = {},
  hiddenButtons = setmetatable({}, { __mode = "k" }),
}
AP.MinimapPalette = Palette

local ICON_PATH = "Interface\\AddOns\\WotLK-Plus\\media\\minimap\\palette-hub"
local PANEL_WIDTH = 272
local ROW_HEIGHT = 27
local ROW_GAP = 3
local MAX_VISIBLE_ROWS = 9
local PANEL_GUTTER = 10
local HEADER_HEIGHT = 30
local FOOTER_HEIGHT = 24

local function isInCombat()
  return type(InCombatLockdown) == "function" and InCombatLockdown() and true or false
end

local function isFrameShown(frame)
  return frame and type(frame.IsShown) == "function" and frame:IsShown() and true or false
end

local function frameIsProtected(frame)
  return frame and type(frame.IsProtected) == "function" and frame:IsProtected() and true or false
end

local function setBorder(frame, color)
  if frame and frame.SetBackdropBorderColor then
    frame:SetBackdropBorderColor(color[1], color[2], color[3], color[4] or 1)
  end
end

function Palette:GetSettings()
  return AP.Database:Get("interface.minimapPalette", AP.defaults.interface.minimapPalette)
end

function Palette:IsCollectionEnabled()
  return AP.Database:Get("interface.minimapPalette.collectButtons", true) and true or false
end

function Palette:IsLocked()
  return AP.Database:Get("interface.minimapPalette.locked", false) and true or false
end

function Palette:IsTooltipEnabled()
  return AP.Database:Get("interface.minimapPalette.showTooltips", true) and true or false
end

function Palette:GetStatusText()
  if not self.enabled then
    return "The minimap palette is disabled."
  end
  local mode = self:IsCollectionEnabled() and "collecting eligible launcher buttons" or "leaving original launcher buttons visible"
  return string.format("%d launcher%s discovered; %s.", #self.entries, #self.entries == 1 and "" or "s", mode)
end

function Palette:ApplyControlPosition()
  local control = self.control
  local minimap = _G.Minimap
  if not control or not minimap then
    return
  end
  local settings = self:GetSettings()
  control:ClearAllPoints()
  control:SetPoint(settings.point or "TOPRIGHT", minimap, settings.relPoint or "TOPRIGHT", settings.x or -8, settings.y or -8)
end

function Palette:SaveControlPosition()
  if not self.control then
    return
  end
  local point, _, relPoint, x, y = self.control:GetPoint()
  local settings = self:GetSettings()
  settings.point = point or "TOPRIGHT"
  settings.relPoint = relPoint or "TOPRIGHT"
  settings.x = math.floor((x or 0) + 0.5)
  settings.y = math.floor((y or 0) + 0.5)
end

function Palette:CreateControl()
  if self.control or not _G.Minimap then
    return self.control
  end

  local control = CreateFrame("Button", "WotLKPlusMinimapPaletteButton", _G.Minimap)
  control:SetWidth(32)
  control:SetHeight(32)
  control:SetFrameStrata("HIGH")
  control:SetToplevel(true)
  control:SetMovable(true)
  control:SetClampedToScreen(true)
  control:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  control:RegisterForDrag("LeftButton")
  Theme:ApplyBackdrop(control, Theme.colors.inset, Theme.colors.border)

  control.Icon = control:CreateTexture(nil, "ARTWORK")
  control.Icon:SetPoint("TOPLEFT", control, "TOPLEFT", 7, -7)
  control.Icon:SetPoint("BOTTOMRIGHT", control, "BOTTOMRIGHT", -7, 7)
  control.Icon:SetTexture(ICON_PATH)

  control.Highlight = control:CreateTexture(nil, "HIGHLIGHT")
  control.Highlight:SetPoint("TOPLEFT", control, "TOPLEFT", 2, -2)
  control.Highlight:SetPoint("BOTTOMRIGHT", control, "BOTTOMRIGHT", -2, 2)
  Theme:Paint(control.Highlight, { Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3], 0.16 })

  control:SetScript("OnEnter", function(button)
    setBorder(button, Theme.colors.gold)
    if not Palette:IsTooltipEnabled() then
      return
    end
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    GameTooltip:AddLine("MINIMAP PALETTE", Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3])
    GameTooltip:AddLine("Left-click to reveal captured launcher buttons.", Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], true)
    GameTooltip:AddLine("Shift + drag to move. Right-click for controls.", Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3], true)
    GameTooltip:Show()
  end)
  control:SetScript("OnLeave", function(button)
    setBorder(button, Theme.colors.border)
    GameTooltip:Hide()
  end)
  control:SetScript("OnDragStart", function(button)
    if Palette:IsLocked() or not (IsShiftKeyDown and IsShiftKeyDown()) then
      return
    end
    button.APWasDragged = true
    button:StartMoving()
  end)
  control:SetScript("OnDragStop", function(button)
    button:StopMovingOrSizing()
    if button.APWasDragged then
      Palette:SaveControlPosition()
    end
  end)
  control:SetScript("OnClick", function(button, mouseButton)
    if mouseButton == "RightButton" then
      button.APWasDragged = nil
      Palette:ShowMenu()
      return
    end
    if button.APWasDragged then
      button.APWasDragged = nil
      return
    end
    Palette:TogglePanel()
  end)

  self.control = control
  self:ApplyControlPosition()
  return control
end

function Palette:CreatePanel()
  if self.panel then
    return self.panel
  end

  local panel = CreateFrame("Frame", "WotLKPlusMinimapPalettePanel", UIParent)
  panel:SetWidth(PANEL_WIDTH)
  panel:SetFrameStrata("DIALOG")
  panel:SetToplevel(true)
  panel:EnableMouse(true)
  panel:SetClampedToScreen(true)
  Theme:ApplyBackdrop(panel, Theme.colors.background, Theme.colors.border)

  panel.Header = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  panel.Header:SetPoint("TOPLEFT", panel, "TOPLEFT", PANEL_GUTTER, -9)
  panel.Header:SetTextColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3])
  panel.Header:SetShadowColor(0, 0, 0, 1)
  panel.Header:SetShadowOffset(1, -1)
  panel.Header:SetText("MINIMAP LAUNCHERS")

  panel.Count = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  panel.Count:SetPoint("RIGHT", panel, "TOPRIGHT", -34, -11)
  panel.Count:SetTextColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3])

  panel.Close = CreateFrame("Button", nil, panel)
  panel.Close:SetWidth(20)
  panel.Close:SetHeight(20)
  panel.Close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, -5)
  Theme:SkinCloseButton(panel.Close, "x")
  panel.Close:SetScript("OnClick", function()
    Palette:HidePanel()
  end)

  panel.Line = panel:CreateTexture(nil, "ARTWORK")
  panel.Line:SetPoint("TOPLEFT", panel, "TOPLEFT", PANEL_GUTTER, -HEADER_HEIGHT)
  panel.Line:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PANEL_GUTTER, -HEADER_HEIGHT)
  panel.Line:SetHeight(1)
  Theme:Paint(panel.Line, Theme.colors.line)

  panel.Scroll = CreateFrame("ScrollFrame", "WotLKPlusMinimapPaletteScroll", panel, "UIPanelScrollFrameTemplate")
  panel.Scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", PANEL_GUTTER, -(HEADER_HEIGHT + 7))
  panel.Scroll:SetWidth(PANEL_WIDTH - (PANEL_GUTTER * 2) - 15)
  panel.Content = CreateFrame("Frame", nil, panel.Scroll)
  panel.Content:SetWidth(panel.Scroll:GetWidth())
  panel.Scroll:SetScrollChild(panel.Content)
  Theme:SkinScrollFrame(panel.Scroll)

  panel.Empty = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  panel.Empty:SetPoint("TOPLEFT", panel, "TOPLEFT", PANEL_GUTTER, -(HEADER_HEIGHT + 14))
  panel.Empty:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PANEL_GUTTER, -(HEADER_HEIGHT + 14))
  panel.Empty:SetJustifyH("LEFT")
  panel.Empty:SetTextColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3])
  panel.Empty:SetText("No eligible third-party minimap launchers are currently visible.")

  panel.Footer = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  panel.Footer:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", PANEL_GUTTER, 7)
  panel.Footer:SetTextColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3])
  panel.Footer:SetText("Right-click the hub to lock, restore, or configure.")

  if UISpecialFrames then
    UISpecialFrames[#UISpecialFrames + 1] = "WotLKPlusMinimapPalettePanel"
  end

  self.panel = panel
  panel:Hide()
  return panel
end

function Palette:CreateRow(index)
  local panel = self:CreatePanel()
  local row = CreateFrame("Button", nil, panel.Content)
  row:SetWidth(panel.Content:GetWidth())
  row:SetHeight(ROW_HEIGHT)
  row:RegisterForClicks("LeftButtonUp")
  row.Fill = row:CreateTexture(nil, "BACKGROUND")
  row.Fill:SetAllPoints(row)
  Theme:Paint(row.Fill, { Theme.colors.surface[1], Theme.colors.surface[2], Theme.colors.surface[3], 0.58 })
  row.Hover = row:CreateTexture(nil, "HIGHLIGHT")
  row.Hover:SetAllPoints(row)
  Theme:Paint(row.Hover, { Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3], 0.13 })

  row.Icon = row:CreateTexture(nil, "ARTWORK")
  row.Icon:SetPoint("LEFT", row, "LEFT", 6, 0)
  row.Icon:SetWidth(21)
  row.Icon:SetHeight(21)

  row.Label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.Label:SetPoint("LEFT", row.Icon, "RIGHT", 8, 0)
  row.Label:SetPoint("RIGHT", row, "RIGHT", -8, 0)
  row.Label:SetJustifyH("LEFT")
  row.Label:SetShadowColor(0, 0, 0, 1)
  row.Label:SetShadowOffset(1, -1)

  row:SetScript("OnEnter", function(button)
    button.Label:SetTextColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3])
    if not Palette:IsTooltipEnabled() then
      return
    end
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:AddLine(button.entry.label, Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3])
    GameTooltip:AddLine("Click to invoke this launcher's original minimap action.", Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], true)
    GameTooltip:Show()
  end)
  row:SetScript("OnLeave", function(button)
    button.Label:SetTextColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3])
    GameTooltip:Hide()
  end)
  row:SetScript("OnClick", function(button)
    Palette:ActivateEntry(button.entry)
  end)

  self.rows[index] = row
  return row
end

function Palette:UpdateRows()
  local panel = self:CreatePanel()
  local count = #self.entries
  local visibleRows = math.min(math.max(count, 1), MAX_VISIBLE_ROWS)
  local listHeight = (visibleRows * ROW_HEIGHT) + math.max(visibleRows - 1, 0) * ROW_GAP
  panel:SetHeight(HEADER_HEIGHT + listHeight + FOOTER_HEIGHT + 13)
  panel.Scroll:SetHeight(listHeight)
  panel.Content:SetHeight(math.max(listHeight, (count * ROW_HEIGHT) + math.max(count - 1, 0) * ROW_GAP))
  panel.Count:SetText(string.format("%d ITEM%s", count, count == 1 and "" or "S"))
  if count == 0 then
    panel.Empty:Show()
  else
    panel.Empty:Hide()
  end

  for index = 1, count do
    local entry = self.entries[index]
    local row = self.rows[index] or self:CreateRow(index)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", panel.Content, "TOPLEFT", 0, -((index - 1) * (ROW_HEIGHT + ROW_GAP)))
    row.entry = entry
    row.Icon:SetTexture(entry.texture)
    if entry.coords then
      row.Icon:SetTexCoord(entry.coords[1], entry.coords[2], entry.coords[3], entry.coords[4])
    else
      row.Icon:SetTexCoord(0, 1, 0, 1)
    end
    row.Label:SetText(entry.label)
    row:Show()
  end
  for index = count + 1, #self.rows do
    self.rows[index]:Hide()
  end
end

function Palette:PositionPanel()
  if not self.panel or not self.control then
    return
  end
  local _, controlY = self.control:GetCenter()
  local _, screenY = UIParent:GetCenter()
  self.panel:ClearAllPoints()
  if controlY and screenY and controlY < screenY then
    self.panel:SetPoint("BOTTOMRIGHT", self.control, "TOPRIGHT", 0, 7)
  else
    self.panel:SetPoint("TOPRIGHT", self.control, "BOTTOMRIGHT", 0, -7)
  end
end

function Palette:AnimateOpen()
  local panel = self.panel
  panel.openElapsed = 0
  panel:SetScale(0.84)
  panel:SetAlpha(0)
  panel:SetScript("OnUpdate", function(frame, elapsed)
    frame.openElapsed = frame.openElapsed + elapsed
    local progress = math.min(frame.openElapsed / 0.14, 1)
    frame:SetScale(0.84 + (0.16 * progress))
    frame:SetAlpha(progress)
    if progress >= 1 then
      frame:SetScale(1)
      frame:SetAlpha(1)
      frame:SetScript("OnUpdate", nil)
    end
  end)
end

function Palette:ShowPanel()
  self:Refresh()
  local panel = self:CreatePanel()
  self:UpdateRows()
  self:PositionPanel()
  panel:Show()
  self:AnimateOpen()
end

function Palette:HidePanel()
  if self.panel then
    self.panel:SetScript("OnUpdate", nil)
    self.panel:SetScale(1)
    self.panel:SetAlpha(1)
    self.panel:Hide()
  end
end

function Palette:TogglePanel()
  if isFrameShown(self.panel) then
    self:HidePanel()
  else
    self:ShowPanel()
  end
end

function Palette:HideCapturedButtons()
  for index = 1, #self.entries do
    local button = self.entries[index].button
    if button and not frameIsProtected(button) and isFrameShown(button) then
      button:Hide()
      self.hiddenButtons[button] = true
    end
  end
end

function Palette:RestoreCapturedButtons()
  for button in pairs(self.hiddenButtons) do
    if button and not frameIsProtected(button) and type(button.Show) == "function" then
      button:Show()
    end
    self.hiddenButtons[button] = nil
  end
end

function Palette:Refresh()
  if not self.enabled or not self.control then
    return
  end
  self.entries = Discovery:GetEntries(self.hiddenButtons)
  if self:IsCollectionEnabled() then
    self:HideCapturedButtons()
  else
    self:RestoreCapturedButtons()
    self.entries = Discovery:GetEntries(nil)
  end
  if isFrameShown(self.panel) then
    self:UpdateRows()
    self:PositionPanel()
  end
end

function Palette:ActivateEntry(entry)
  self:HidePanel()
  local button = entry and entry.button
  if not button then
    return
  end
  if frameIsProtected(button) and isInCombat() then
    AP:Print("|cffff6666That minimap action cannot be invoked during combat.|r")
    return
  end

  local clicked = false
  if type(button.Click) == "function" then
    clicked = pcall(button.Click, button, "LeftButton")
  end
  if not clicked and type(button.GetScript) == "function" then
    local onClick = button:GetScript("OnClick")
    if type(onClick) == "function" then
      clicked = pcall(onClick, button, "LeftButton")
    end
  end
  if not clicked then
    AP:Print("|cffff6666Unable to invoke|r " .. tostring(entry.label) .. ".")
  end
end

function Palette:SetCollectionEnabled(enabled)
  AP.Database:Set("interface.minimapPalette.collectButtons", enabled and true or false)
  self:Refresh()
end

function Palette:SetLocked(locked)
  AP.Database:Set("interface.minimapPalette.locked", locked and true or false)
end

function Palette:ResetPosition()
  local settings = self:GetSettings()
  local defaults = AP.defaults.interface.minimapPalette
  settings.point = defaults.point
  settings.relPoint = defaults.relPoint
  settings.x = defaults.x
  settings.y = defaults.y
  self:ApplyControlPosition()
end

function Palette:ShowMenu()
  if type(EasyMenu) ~= "function" then
    AP:OpenConfig("interface.minimapPalette")
    return
  end
  self.menuFrame = self.menuFrame or CreateFrame("Frame", "WotLKPlusMinimapPaletteMenu", UIParent, "UIDropDownMenuTemplate")
  local menu = {
    { text = "Minimap Palette", isTitle = true, notCheckable = true },
    {
      text = "Lock position",
      checked = self:IsLocked(),
      keepShownOnClick = true,
      func = function()
        Palette:SetLocked(not Palette:IsLocked())
      end,
    },
    {
      text = "Collect launcher buttons",
      checked = self:IsCollectionEnabled(),
      keepShownOnClick = true,
      func = function()
        Palette:SetCollectionEnabled(not Palette:IsCollectionEnabled())
      end,
    },
    {
      text = "Refresh list",
      notCheckable = true,
      func = function()
        Palette:Refresh()
      end,
    },
    {
      text = "Open settings",
      notCheckable = true,
      func = function()
        AP:OpenConfig("interface.minimapPalette")
      end,
    },
  }
  EasyMenu(menu, self.menuFrame, "cursor", 0, 0, "MENU")
end

function Palette:EnsureDriver()
  if self.driver then
    return
  end
  local driver = CreateFrame("Frame")
  driver.elapsed = 0
  driver:RegisterEvent("PLAYER_LOGIN")
  driver:SetScript("OnEvent", function()
    Palette:CreateControl()
    Palette:Refresh()
  end)
  driver:SetScript("OnUpdate", function(frame, elapsed)
    if not Palette.enabled then
      return
    end
    frame.elapsed = frame.elapsed + elapsed
    if frame.elapsed >= 0.75 then
      frame.elapsed = 0
      Palette:CreateControl()
      Palette:Refresh()
    end
  end)
  self.driver = driver
end

function Palette:Enable()
  self.enabled = true
  self:EnsureDriver()
  self:CreateControl()
  if self.control then
    self.control:Show()
  end
  self:Refresh()
end

function Palette:Disable()
  self.enabled = false
  self:HidePanel()
  self:RestoreCapturedButtons()
  if self.control then
    self.control:Hide()
  end
end
