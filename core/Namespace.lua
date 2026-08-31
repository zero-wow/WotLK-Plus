local ADDON_NAME, AP = ...
AP = AP or _G.Levo or _G.WotLKPlus or _G.AscensionPlus or {}
_G.Levo = AP
_G.WotLKPlus = AP
_G.AscensionPlus = AP

AP.name = ADDON_NAME
AP.prettyName = "Levo"
AP.version = (GetAddOnMetadata and GetAddOnMetadata(ADDON_NAME, "Version")) or "0.1.0"
AP.modules = AP.modules or {}
AP.UI = AP.UI or AP.ui or {}
AP.ui = AP.UI
AP.data = AP.data or {}
AP.state = AP.state or {}
AP.constants = AP.constants or {}

function AP:Print(message)
  local formatted = "|cffe7c56d[LV]|r " .. tostring(message or "")
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage(formatted)
  elseif print then
    print(formatted)
  end
end
