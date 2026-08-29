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

io.write("PASS appearance queue prioritizes consent and pauses AUTO behind ASK\n")
