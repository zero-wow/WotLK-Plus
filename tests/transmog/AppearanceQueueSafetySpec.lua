local root = (... and ... ~= "" and ...) or "."

local values = {
  ["transmog.autoCollect.deferUntilOutOfCombat"] = true,
}

local Collector = {
  collectionQueue = {},
  queuedAppearanceIDs = {},
  activeRequest = nil,
  moduleEnabled = true,
  ShouldPrint = function() return false end,
  ShouldAutoConfirmBinding = function() return true end,
  IsAutomationAuthorized = function() return true end,
  IsRuntimeEnabled = function() return true end,
}

_G.AscensionPlus = {
  TransmogAutoCollect = Collector,
  Database = {
    Get = function(_, path, fallback)
      local value = values[path]
      if value == nil then
        return fallback
      end
      return value
    end,
  },
  Print = function() end,
  TransmogAppearanceRules = {
    activeEntry = nil,
  },
}

function GetTime()
  return 0
end

function InCombatLockdown()
  return false
end

dofile(root .. "/modules/transmog/services/AppearanceQueue.lua")

assert(not Collector:QueueAppearance({ appearanceID = 99 }, "unknown"), "unmarked non-manual requests must never enter the mutation queue")
assert(Collector:QueueAppearance({ appearanceID = 100, automaticRequest = true }, "loot"), "AUTO request should queue")
assert(Collector:QueueAppearance({ appearanceID = 101, ruleApproved = true }, "approved appearance"), "approved ASK request should queue")
assert(Collector.collectionQueue[1].appearanceID == 101, "an explicitly approved ASK item must take priority over pending AUTO items")
assert(Collector.collectionQueue[2].appearanceID == 100, "priority insertion must preserve the existing AUTO request")

local starts = 0
Collector.StartNextRequest = function()
  starts = starts + 1
end

AscensionPlus.TransmogAppearanceRules.activeEntry = { appearanceID = 102 }
Collector:ProcessCollectionQueue(0)
assert(starts == 0, "AUTO queue must pause while an ASK decision is visible")

AscensionPlus.TransmogAppearanceRules.activeEntry = nil
Collector:ProcessCollectionQueue(0)
assert(starts == 1, "collection queue may resume after the ASK prompt resolves")

local completed
Collector.activeRequest = {
  token = 7,
  confirmUntil = 1,
}
Collector.pendingPopup = {
  token = 7,
  which = "CONFIRM_BINDER",
}
Collector.popupConfirmAt = 0
Collector.GetRequestState = function()
  return "invalid"
end
Collector.CompleteActiveRequest = function(_, success)
  completed = success
end
Collector:ConfirmPendingPopup(0)
assert(completed == false, "a changed rule or blacklist must cancel the request before the native bind dialog is accepted")
assert(not Collector.pendingPopup, "invalidated native popup work must be discarded")

local popupClicked = 0
local popupShown = true
local popup = {
  which = "EQUIP_BIND_CONFIRM",
  IsShown = function() return popupShown end,
  GetName = function() return "StaticPopup1" end,
}
_G.StaticPopup1 = popup
_G.StaticPopup1Text = {
  GetText = function()
    return "Collecting this appearance will bind Test Item to you."
  end,
}
_G.StaticPopup1Button1 = {
  IsShown = function() return true end,
  IsEnabled = function() return true end,
  Click = function() popupClicked = popupClicked + 1 end,
}
_G.StaticPopup1EditBox = {
  IsShown = function() return false end,
}
STATICPOPUP_NUMDIALOGS = 1

Collector.activeRequest = {
  token = 8,
  confirmUntil = 1,
  visiblePopups = {},
  name = "Test Item",
}
Collector.GetRequestState = function()
  return "ready"
end
Collector.pendingPopup = {
  token = 8,
  which = popup.which,
  popup = popup,
}
Collector.popupConfirmAt = 0
Collector:ConfirmPendingPopup(0)
assert(popupClicked == 1, "an AUTO request must accept Ascension's new appearance-binding popup")
assert(not Collector.pendingPopup, "a confirmed appearance popup must leave no pending work")

popup.which = "CONFIRM_BINDER"
assert(not Collector:IsLikelyAppearancePopup(popup.which, popup, Collector.activeRequest), "the innkeeper hearth-binding dialog is not an appearance popup")
assert(not Collector:IsSafeRequestPopup(popup.which, popup, Collector.activeRequest), "the innkeeper dialog must never pass the request-owned fallback")

popup.which = "ASCENSION_CONFIRM"
_G.StaticPopup1Text.GetText = function()
  return "Proceed with this operation?"
end
Collector.pendingPopup = {
  token = 8,
  which = popup.which,
  popup = popup,
}
Collector.popupConfirmAt = 0
Collector:ConfirmPendingPopup(0)
assert(popupClicked == 2, "one new safe popup inside the collection window should use the request-owned fallback")

popup.which = "DELETE_ITEM"
Collector.pendingPopup = {
  token = 8,
  which = popup.which,
  popup = popup,
}
Collector.popupConfirmAt = 0
Collector:ConfirmPendingPopup(0)
assert(popupClicked == 2, "a delete popup must never be accepted by automatic appearance collection")

io.write("PASS appearance queue prioritizes consent and safely owns Ascension bind popups\n")
