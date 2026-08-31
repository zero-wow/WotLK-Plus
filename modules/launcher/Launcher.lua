local _, AP = ...
AP = AP or _G.Levo or _G.WotLKPlus or _G.AscensionPlus

local OBJECT_NAME = "Levo"
local DEFAULT_MINIMAP_POSITION = 220

local Launcher = {
  dataObject = nil,
  iconLibrary = nil,
  enabled = false,
  registrationError = nil,
}

AP.Launcher = Launcher

local function showTooltip(tooltip)
  Launcher:BuildTooltip(tooltip)
end

local function addTooltipLine(tooltip, left, right)
  if right and tooltip.AddDoubleLine then
    tooltip:AddDoubleLine(left, right, 1, 1, 1, 0.45, 0.85, 1)
  elseif tooltip.AddLine then
    tooltip:AddLine(left, 1, 1, 1)
  end
end

local function getLibrary(name)
  if not LibStub then
    return nil
  end
  return LibStub(name, true)
end

function Launcher:GetMinimapSettings()
  local settings = AP.Database:Get("interface.launcher.minimap", nil)
  if type(settings) ~= "table" then
    settings = {
      hide = false,
      minimapPos = DEFAULT_MINIMAP_POSITION,
    }
    AP.Database:Set("interface.launcher.minimap", settings)
  end
  return settings
end

function Launcher:IsTooltipEnabled()
  return AP.Database:Get("interface.launcher.showTooltip", true) and true or false
end

function Launcher:IsMinimapVisible()
  return not self:GetMinimapSettings().hide
end

function Launcher:IsReady()
  return self.enabled and self.dataObject ~= nil and self.registrationError == nil
end

function Launcher:GetStatusText()
  if self.registrationError then
    return "Launcher error: " .. tostring(self.registrationError)
  end
  if not self:IsReady() then
    return "The LDB launcher has not initialized yet."
  end
  return "LDB object is active. The minimap button is " .. (self:IsMinimapVisible() and "shown." or "hidden.")
end

function Launcher:BuildTooltip(tooltip)
  if not tooltip or not self:IsTooltipEnabled() then
    return
  end

  addTooltipLine(tooltip, AP.prettyName, "v" .. tostring(AP.version or ""))
  addTooltipLine(tooltip, "Left-click", "Toggle configuration")
  addTooltipLine(tooltip, "Shift + Left-click", "Toggle Skill Card Ledger")
  addTooltipLine(tooltip, "Right-click", "Show command help")
  addTooltipLine(tooltip, "Minimap", self:IsMinimapVisible() and "Shown" or "Hidden")
end

function Launcher:ToggleConfig()
  if not AP.initialized and AP.TryInitialize then
    local initialized = AP:TryInitialize("launcher click")
    if not initialized then
      return
    end
  end

  local config = AP.ConfigWindow
  if config and config.frame and config.frame:IsShown() then
    config.frame:Hide()
  elseif AP.OpenConfig then
    AP:OpenConfig()
  end
end

function Launcher:OnClick(button)
  if button == "RightButton" then
    if AP.ShowHelp then
      AP:ShowHelp()
    else
      AP:Print("Type /lv for Levo commands.")
    end
    return
  end


  if button == "LeftButton" and IsShiftKeyDown and IsShiftKeyDown() then
    local window = AP.SkillCards and AP.SkillCards.Window
    if window and window.Toggle then
      window:Toggle("expanded")
    else
      AP:Print("The Skill Card Ledger is unavailable.")
    end
    return
  end

  self:ToggleConfig()
end

function Launcher:EnsureDataObject()
  if self.dataObject then
    return self.dataObject
  end

  local dataBroker = getLibrary("LibDataBroker-1.1")
  if not dataBroker then
    return nil, "LibDataBroker-1.1 is unavailable"
  end

  local dataObject = dataBroker:GetDataObjectByName(OBJECT_NAME)
  if not dataObject then
    dataObject = dataBroker:NewDataObject(OBJECT_NAME, {
      type = "launcher",
      text = AP.prettyName,
      label = AP.prettyName,
      icon = "Interface\\Icons\\INV_Misc_Gear_01",
      iconCoords = { 0.08, 0.92, 0.08, 0.92 },
      OnClick = function(_, button)
        Launcher:OnClick(button)
      end,
      OnTooltipShow = showTooltip,
    })
  end

  self.dataObject = dataObject
  return dataObject
end

function Launcher:Refresh()
  if not self.enabled then
    return false
  end

  local dataObject, objectError = self:EnsureDataObject()
  if not dataObject then
    self.registrationError = objectError
    return false, objectError
  end

  dataObject.text = AP.prettyName
  dataObject.label = AP.prettyName
  dataObject.icon = "Interface\\Icons\\INV_Misc_Gear_01"
  dataObject.iconCoords = { 0.08, 0.92, 0.08, 0.92 }
  dataObject.OnTooltipShow = self:IsTooltipEnabled() and showTooltip or nil

  self.iconLibrary = self.iconLibrary or getLibrary("LibDBIcon-1.0")
  if not self.iconLibrary then
    self.registrationError = "LibDBIcon-1.0 is unavailable"
    return false, self.registrationError
  end

  local settings = self:GetMinimapSettings()
  local ok, err = pcall(function()
    if not self.iconLibrary:IsRegistered(OBJECT_NAME) then
      self.iconLibrary:Register(OBJECT_NAME, dataObject, settings)
    else
      self.iconLibrary:Refresh(OBJECT_NAME, settings)
    end

    if settings.hide then
      self.iconLibrary:Hide(OBJECT_NAME)
    else
      self.iconLibrary:Show(OBJECT_NAME)
    end
  end)

  if not ok then
    self.registrationError = tostring(err)
    return false, self.registrationError
  end

  self.registrationError = nil
  return true
end

function Launcher:Enable()
  self.enabled = true
  local ok, err = self:Refresh()
  if not ok and err then
    AP:Print("|cffff6666Launcher initialization failed:|r " .. tostring(err))
  end
end

function Launcher:Disable()
  self.enabled = false
  if self.iconLibrary and self.iconLibrary:IsRegistered(OBJECT_NAME) then
    self.iconLibrary:Hide(OBJECT_NAME)
  end
end

function Launcher:SetMinimapVisible(visible)
  local settings = self:GetMinimapSettings()
  settings.hide = not visible
  self:Refresh()
  return not settings.hide
end

function Launcher:ToggleMinimap()
  return self:SetMinimapVisible(not self:IsMinimapVisible())
end

function Launcher:ResetMinimapPosition()
  local settings = self:GetMinimapSettings()
  settings.minimapPos = DEFAULT_MINIMAP_POSITION
  self:Refresh()
end
