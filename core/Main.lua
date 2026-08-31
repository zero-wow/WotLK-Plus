local ADDON_NAME, AP = ...
ADDON_NAME = type(ADDON_NAME) == "string" and ADDON_NAME or "Levo"

if type(AP) ~= "table" then
  AP = type(_G.Levo) == "table" and _G.Levo
    or (type(_G.WotLKPlus) == "table" and _G.WotLKPlus
      or (type(_G.AscensionPlus) == "table" and _G.AscensionPlus or {}))
end
_G.Levo = AP
_G.WotLKPlus = AP
-- Keep the former namespace alive for existing internal modules and saved UI callbacks.
_G.AscensionPlus = AP

AP.name = ADDON_NAME
AP.prettyName = "Levo"
AP.version = (GetAddOnMetadata and GetAddOnMetadata(ADDON_NAME, "Version")) or "0.8.0"
AP.modules = AP.modules or {}
AP.UI = AP.UI or AP.ui or {}
AP.ui = AP.UI
AP.data = AP.data or {}
AP.state = AP.state or {}
AP.constants = AP.constants or {}
AP.loadState = AP.loadState or {}
AP.loadState.mainLoaded = true
AP.loadState.addonLoaded = false
AP.loadState.playerLogin = false
AP.loadState.initialized = false
AP.loadState.initializationError = nil

function AP:Print(message)
  local formatted = "|cffe7c56d[LV]|r " .. tostring(message or "")
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage(formatted)
  elseif print then
    print(formatted)
  end
end

function AP:TryInitialize(reason)
  if self.initialized then
    self.loadState.initialized = true
    return true
  end

  if type(self.Initialize) ~= "function" then
    local message = "Initialization function was not loaded"
    if reason then
      message = message .. " (trigger: " .. tostring(reason) .. ")"
    end
    self.loadState.initializationError = message
    self:Print("|cffff6666" .. message .. ".|r Use /lv status for diagnostics.")
    return false, message
  end

  local callOk, initialized, initializeError = pcall(self.Initialize, self)
  if not callOk then
    initializeError = initialized
    initialized = false
  end

  if not initialized then
    local message = tostring(initializeError or "unknown initialization error")
    self.loadState.initializationError = message
    self:Print("|cffff6666Initialization failed:|r " .. message)
    return false, message
  end

  self.loadState.initialized = true
  self.loadState.initializationError = nil
  return true
end

local eventFrame = CreateFrame("Frame")
AP.eventFrame = eventFrame
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self, event, ...)
  if event == "ADDON_LOADED" then
    local loadedAddonName = ...
    if loadedAddonName ~= ADDON_NAME then
      return
    end

    AP.loadState.addonLoaded = true
    if AP.RegisterSlashCommands then
      AP:RegisterSlashCommands()
    end
    AP:TryInitialize("ADDON_LOADED")
    self:UnregisterEvent("ADDON_LOADED")
    return
  end

  if event == "PLAYER_LOGIN" then
    AP.loadState.playerLogin = true
    if AP.RegisterSlashCommands then
      AP:RegisterSlashCommands()
    end

    local initialized = AP:TryInitialize("PLAYER_LOGIN")
    if initialized then
      local showMessage = true
      if AP.Database and AP.Database.Get then
        showMessage = AP.Database:Get("general.showStartupMessage", true)
      end
      if showMessage then
        AP:Print(string.format("%s v%s loaded. Type |cff93c2ff/lv|r for help or |cff93c2ff/levo|r for configuration.", AP.prettyName, AP.version))
      end
    else
      AP:Print("|cffff6666Core loaded, but startup did not complete.|r Type /lv status for the captured error.")
    end

    self:UnregisterEvent("PLAYER_LOGIN")
  end
end)
