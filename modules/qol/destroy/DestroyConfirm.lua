local _, AP = ...
AP = AP or _G.AscensionPlus

local Helper = {
  moduleEnabled = false,
  eventFrame = nil,
}

AP.DestroyConfirmHelper = Helper

local DELETE_POPUPS = {
  DELETE_ITEM = true,
  DELETE_GOOD_ITEM = true,
  DELETE_QUEST_ITEM = true,
  DELETE_GOOD_QUEST_ITEM = true,
}

local function getDeleteText()
  if type(DELETE_ITEM_CONFIRM_STRING) == "string" and DELETE_ITEM_CONFIRM_STRING ~= "" then
    return DELETE_ITEM_CONFIRM_STRING
  end

  return "DELETE"
end

function Helper:IsEnabled()
  return self.moduleEnabled and AP.Database:Get("qol.destroyConfirm.autoFillDelete", true)
end

function Helper:GetSummaryText()
  local moduleLabel = AP.Database:Get("modules.destroyConfirm", true) and "Enabled" or "Disabled"
  local autofillLabel = AP.Database:Get("qol.destroyConfirm.autoFillDelete", true) and "On" or "Off"

  return string.format(
    "Module: %s. Auto-fill: %s. This helper only fills the confirmation word when the client asks for it; it never confirms item deletion for you.",
    moduleLabel,
    autofillLabel
  )
end

function Helper:FindPopup()
  local total = STATICPOPUP_NUMDIALOGS or 4
  for index = 1, total do
    local popup = _G["StaticPopup" .. index]
    if popup and popup:IsShown() and DELETE_POPUPS[popup.which] then
      return popup
    end
  end
end

function Helper:ApplyDeleteText()
  if not self:IsEnabled() then
    return
  end

  local popup = self:FindPopup()
  if not popup then
    return
  end

  local editBox = _G[popup:GetName() .. "EditBox"]
  if not editBox or not editBox:IsShown() then
    return
  end

  local deleteText = getDeleteText()
  if editBox:GetText() ~= deleteText then
    editBox:SetText(deleteText)
  end

  editBox:HighlightText(0, 0)
end

function Helper:EnsureEventFrame()
  if self.eventFrame then
    return
  end

  local frame = CreateFrame("Frame")
  frame:SetScript("OnEvent", function()
    Helper:ApplyDeleteText()
  end)

  self.eventFrame = frame
end

function Helper:Enable()
  self.moduleEnabled = true
  self:EnsureEventFrame()
  self.eventFrame:RegisterEvent("DELETE_ITEM_CONFIRM")
end

function Helper:Disable()
  self.moduleEnabled = false

  if self.eventFrame then
    self.eventFrame:UnregisterAllEvents()
  end
end
