local root = (... and ... ~= "" and ...) or "."

local runtimeEnabled = true
local reviewAlertsEnabled = true
local qualityModes = {
  [0] = "never",
  [1] = "ask",
  [2] = "auto",
}
local blacklist = {}
local collected = {}
local queuedRequests = {}
local slots = {}
local promptOpens = {}
local promptCloses = 0
local inCombat = false

local Collector = {
  queuedAppearanceIDs = {},
  activeRequest = nil,
}

function Collector:IsRuntimeEnabled()
  return runtimeEnabled
end

function Collector:IsReviewAlertsEnabled()
  return reviewAlertsEnabled
end

function Collector:IsLootInspectionEnabled()
  return runtimeEnabled or reviewAlertsEnabled
end

function Collector:GetQualityMode(quality)
  return qualityModes[quality] or "never"
end

function Collector:GetQualityKey(quality)
  return ({ [0] = "poor", [1] = "common", [2] = "uncommon" })[quality]
end

function Collector:SetQualityMode(qualityKey, mode)
  local qualities = { poor = 0, common = 1, uncommon = 2 }
  qualityModes[qualities[qualityKey]] = mode
  return true
end

function Collector:SetEnabled(enabled)
  runtimeEnabled = enabled and true or false
end

function Collector:GetPendingRequestCount()
  return #queuedRequests + (self.activeRequest and 1 or 0)
end

function Collector:QueueAppearance(entry, source)
  if self.queuedAppearanceIDs[entry.appearanceID] then
    return false
  end
  entry.source = source
  queuedRequests[#queuedRequests + 1] = entry
  self.queuedAppearanceIDs[entry.appearanceID] = true
  return true
end

function Collector:StartNextRequest()
  self.activeRequest = table.remove(queuedRequests, 1)
end

function Collector:IsBlacklisted(itemID)
  return blacklist[itemID] == true
end

function Collector:AddBlacklistItem(itemID)
  blacklist[itemID] = true
end

function Collector:IsTypeAllowed(_, equipSlot)
  return equipSlot and equipSlot ~= ""
end

function Collector:IsAppearanceCollected(appearanceID)
  return true, collected[appearanceID] == true
end

function Collector:ShouldPrint()
  return false
end

function Collector:NotifyAppearanceInbox()
end

_G.AscensionPlus = {
  TransmogAutoCollect = Collector,
  Print = function() end,
  Database = {
    Get = function(_, _, fallback)
      if fallback == true then
        return true
      end
      return fallback
    end,
  },
  TransmogAppearanceCatalog = {
    InspectSlot = function(_, bag, slot)
      return slots[tostring(bag) .. ":" .. tostring(slot)]
    end,
  },
  TransmogAppearancePrompt = {
    Open = function(_, entry)
      promptOpens[#promptOpens + 1] = entry
      return true
    end,
    CloseSilently = function()
      promptCloses = promptCloses + 1
    end,
    Refresh = function() end,
  },
}

function InCombatLockdown()
  return inCombat
end

local function entry(itemID, appearanceID, quality, slot)
  local value = {
    bag = 0,
    slot = slot,
    itemID = itemID,
    appearanceID = appearanceID,
    quality = quality,
    itemClass = "Armor",
    equipSlot = "INVTYPE_HEAD",
    guid = "GUID-" .. tostring(itemID),
    link = "item:" .. tostring(itemID),
    name = "Item " .. tostring(itemID),
  }
  slots["0:" .. tostring(slot)] = value
  return value
end

dofile(root .. "/modules/transmog/services/AppearanceRules.lua")

local Rules = AscensionPlus.TransmogAppearanceRules
local neverItem = entry(100, 1000, 0, 1)
local askItem = entry(101, 1001, 1, 2)
local secondAsk = entry(102, 1002, 1, 3)

assert(not Rules:Route(neverItem, "loot"), "NEVER must ignore the item without prompting or queueing")
assert(#promptOpens == 0 and #queuedRequests == 0, "NEVER must have no side effects")

assert(Rules:Route(askItem, "loot"), "ASK must accept a decision candidate")
assert(Rules.activeEntry.itemID == askItem.itemID and #promptOpens == 1, "ASK must open exactly one prompt")
assert(not Rules:Route(askItem, "loot"), "the same appearance must not prompt twice")
assert(Rules:Route(secondAsk, "loot"), "a second ASK item should wait behind the active prompt")
assert(#promptOpens == 1 and Rules:GetPendingAskCount() == 2, "ASK decisions must be serialized")

assert(Rules:ResolveActive("defer"), "closing an ASK prompt should resolve it as deferred")
assert(not blacklist[askItem.itemID], "deferring or closing must never persist a blacklist entry")
assert(Rules.deferredAppearanceIDs[askItem.appearanceID], "defer must suppress the appearance for this session")
assert(Rules.activeEntry.itemID == secondAsk.itemID and #promptOpens == 2, "the next prompt may open only after the first resolves")
assert(not Rules:Route(askItem, "loot"), "a deferred appearance must stay quiet for the session")

assert(Rules:ResolveActive("reject"), "NO + NEVER should resolve the active prompt")
assert(blacklist[secondAsk.itemID], "NO + NEVER must persist the exact item ID")
assert(Rules:GetPendingAskCount() == 0, "rejected decisions must leave no stale prompt state")

local approvedAsk = entry(103, 1003, 1, 4)
assert(Rules:Route(approvedAsk, "loot"), "ASK should prompt for another uncollected appearance")
inCombat = true
assert(Rules:ResolveActive("approve"), "YES should submit the approved item")
assert(not Collector.activeRequest and queuedRequests[1].itemID == approvedAsk.itemID, "approved ASK must wait when combat deferral is enabled")
inCombat = false
Collector:StartNextRequest()
assert(Collector.activeRequest and Collector.activeRequest.itemID == approvedAsk.itemID, "YES must dispatch the exact approved item")
assert(Collector.activeRequest.ruleApproved and Collector.activeRequest.automaticRequest, "approved requests need explicit-consent markers")

Collector.queuedAppearanceIDs[approvedAsk.appearanceID] = nil
Collector.activeRequest = nil
Rules:OnCollectionQueueAdvanced()
local autoItem = entry(104, 1004, 2, 5)
assert(Rules:Route(autoItem, "loot"), "AUTO should queue an eligible item")
assert(#queuedRequests == 1 and queuedRequests[1].automaticRequest, "AUTO must bypass the ASK prompt and enter the collection queue")
assert(#promptOpens == 3, "AUTO must not open a confirmation prompt")

runtimeEnabled = false
queuedRequests = {}
Collector.queuedAppearanceIDs[autoItem.appearanceID] = nil
Rules:OnCollectionQueueAdvanced()

local pausedAuto = entry(105, 1005, 2, 6)
assert(Rules:Route(pausedAuto, "loot"), "AUTO loot must remain visible when automation is paused")
assert(Rules.activeEntry and Rules.activeEntry.reviewReason == "automatic-paused", "paused AUTO must open the read-only review window")
assert(#promptOpens == 4, "paused AUTO must add one review alert instead of binding")
assert(#queuedRequests == 0, "paused AUTO review must not queue a collection mutation")
assert(Rules:ResolveActive("defer"), "a paused AUTO review can be deferred safely")

local firstRarityItem = entry(106, 1006, 1, 7)
local secondRarityItem = entry(107, 1007, 1, 8)
assert(Rules:Route(firstRarityItem, "loot"), "ASK item should enter the review queue while automation is off")
assert(Rules:Route(secondRarityItem, "loot"), "additional ASK items should appear in the same review queue")
assert(#Rules:GetReviewEntries() == 2, "the review window must expose current and upcoming appearances")
assert(Rules:ResolveActive("auto-quality"), "AUTO RARITY should approve the item and update its rule")
assert(runtimeEnabled and qualityModes[1] == "auto", "AUTO RARITY must enable automation and persist AUTO for that rarity")
assert(Collector.activeRequest and Collector.activeRequest.itemID == firstRarityItem.itemID, "AUTO RARITY must submit only the approved current item first")

Collector.queuedAppearanceIDs[firstRarityItem.appearanceID] = nil
Collector.activeRequest = nil
Rules:OnCollectionQueueAdvanced()
assert(#queuedRequests == 1 and queuedRequests[1].itemID == secondRarityItem.itemID, "remaining reviewed items of that rarity should move into the serialized AUTO queue")

reviewAlertsEnabled = false
runtimeEnabled = false
local fullyDisabledItem = entry(108, 1008, 2, 9)
assert(not Rules:Route(fullyDisabledItem, "loot"), "disabling both automation and review must stop loot processing")

assert(promptCloses >= 3, "every resolved ASK prompt should close through the safe silent path")
io.write("PASS appearance rules serialize review, preserve read-only alerts, and promote AUTO rarity safely\n")
