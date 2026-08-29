local root = (... and ... ~= "" and ...) or "."

local values = {
  ["transmog.autoCollect.enabled"] = true,
  ["transmog.autoCollect.automationAuthorized"] = false,
  ["transmog.autoCollect.rulesVersion"] = 0,
  ["transmog.autoCollect.showChatMessages"] = false,
  ["transmog.autoCollect.autoConfirmBinding"] = true,
  ["transmog.autoCollect.deferUntilOutOfCombat"] = true,
  ["transmog.autoCollect.includeArmor"] = true,
  ["transmog.autoCollect.includeWeapons"] = true,
  ["transmog.autoCollect.includeOtherEquippable"] = false,
  ["transmog.autoCollect.qualities.poor"] = false,
  ["transmog.autoCollect.qualities.common"] = true,
  ["transmog.autoCollect.qualities.uncommon"] = true,
  ["transmog.autoCollect.qualities.rare"] = true,
  ["transmog.autoCollect.qualities.epic"] = true,
  ["transmog.autoCollect.qualities.legendary"] = true,
  ["transmog.autoCollect.qualities.artifact"] = true,
  ["transmog.autoCollect.qualities.heirloom"] = true,
  ["transmog.autoCollect.blacklist"] = {
    [104] = { name = "Blocked Blade", link = "item:104" },
  },
}

_G.AscensionPlus = {
  Database = {
    Get = function(_, path, fallback)
      local value = values[path]
      if value == nil then
        return fallback
      end
      return value
    end,
    Set = function(_, path, value)
      values[path] = value
    end,
  },
  Print = function() end,
}

BACKPACK_CONTAINER = 0
NUM_BAG_SLOTS = 1
ARMOR = "Armor"
WEAPON = "Weapon"
STATICPOPUP_NUMDIALOGS = 4

local itemData = {
  [100] = { name = "Ready Helm", quality = 1, class = "Armor", equip = "INVTYPE_HEAD", appearance = 1000 },
  [101] = { name = "Known Sword", quality = 2, class = "Weapon", equip = "INVTYPE_WEAPON", appearance = 1001 },
  [102] = { name = "Plain Stone", quality = 1, class = "Miscellaneous", equip = "", appearance = nil },
  [103] = { name = "Grey Shoulders", quality = 0, class = "Armor", equip = "INVTYPE_SHOULDER", appearance = 1003 },
  [104] = { name = "Blocked Blade", quality = 1, class = "Weapon", equip = "INVTYPE_WEAPON", appearance = 1004 },
  [105] = { name = "Ready Helm Copy", quality = 1, class = "Armor", equip = "INVTYPE_HEAD", appearance = 1000 },
}

local bags = {
  [0] = { 100, 101, 102, 103, 104, 105 },
  [1] = {},
}
local collected = { [1001] = true }
local currentTime = 0
local collectCalls = 0

function GetTime()
  return currentTime
end

function InCombatLockdown()
  return false
end

function GetContainerNumSlots(bag)
  return #(bags[bag] or {})
end

function GetContainerItemID(bag, slot)
  return bags[bag] and bags[bag][slot] or nil
end

function GetContainerItemGUID(bag, slot)
  local itemID = GetContainerItemID(bag, slot)
  return itemID and ("GUID-" .. tostring(bag) .. "-" .. tostring(slot) .. "-" .. tostring(itemID)) or nil
end

function GetContainerItemLink(bag, slot)
  local itemID = GetContainerItemID(bag, slot)
  return itemID and ("item:" .. tostring(itemID)) or nil
end

function GetContainerItemInfo(bag, slot)
  local itemID = GetContainerItemID(bag, slot)
  local item = itemID and itemData[itemID]
  if not item then
    return nil
  end
  return "texture:" .. tostring(itemID), 1, false, item.quality, false, false, "item:" .. tostring(itemID)
end

local function itemIDFrom(value)
  if type(value) == "number" then
    return value
  end
  return tonumber(tostring(value or ""):match("item:(%d+)"))
end

function GetItemInfo(value)
  local itemID = itemIDFrom(value)
  local item = itemID and itemData[itemID]
  if not item then
    return nil
  end
  return item.name, "item:" .. tostring(itemID), item.quality, 10, 1, item.class, "Test", 1, item.equip, "texture:" .. tostring(itemID)
end

C_Appearance = {
  GetItemAppearanceID = function(itemID)
    return itemData[itemID] and itemData[itemID].appearance or nil
  end,
}

C_AppearanceCollection = {
  IsAppearanceCollected = function(appearanceID)
    return collected[appearanceID] and true or false
  end,
  CollectItemAppearance = function(guid)
    assert(type(guid) == "string" and guid:match("^GUID%-"), "manual collection must submit the item GUID")
    collectCalls = collectCalls + 1
    return true
  end,
}

dofile(root .. "/modules/transmog/AutoCollect.lua")
dofile(root .. "/modules/transmog/services/AppearanceQueue.lua")
dofile(root .. "/modules/transmog/services/AppearanceCatalog.lua")

local Collector = AscensionPlus.TransmogAutoCollect
local Catalog = AscensionPlus.TransmogAppearanceCatalog
Collector.moduleEnabled = true
Collector.eventFrame = {}

assert(not Collector:IsRuntimeEnabled(), "legacy enabled state must not authorize automation before migration")
assert(Collector:MigrateAutomationRules(), "legacy transmog settings should migrate exactly once")
assert(values["transmog.autoCollect.rulesVersion"] == Collector.RULES_VERSION, "migration must persist its schema version")
assert(values["transmog.autoCollect.automationAuthorized"] == true, "validated runtime should be authorized by migration")
assert(values["transmog.autoCollect.enabled"] == false, "migration must leave runtime processing opt-in")
assert(values["transmog.autoCollect.showReviewAlerts"] == true, "migration must enable read-only loot review alerts")
assert(values["transmog.autoCollect.qualityModes.common"] == "ask", "legacy enabled qualities must migrate to ASK")
assert(values["transmog.autoCollect.qualityModes.poor"] == "never", "legacy disabled qualities must migrate to NEVER")

values["transmog.autoCollect.rulesVersion"] = 1
values["transmog.autoCollect.qualityModes.common"] = "auto"
values["transmog.autoCollect.enabled"] = true
values["transmog.autoCollect.showReviewAlerts"] = nil
assert(Collector:MigrateAutomationRules(), "version-one settings should add review alerts")
assert(values["transmog.autoCollect.qualityModes.common"] == "auto", "review migration must preserve an existing quality mode")
assert(values["transmog.autoCollect.enabled"] == true, "review migration must preserve an existing runtime choice")
assert(values["transmog.autoCollect.showReviewAlerts"] == true, "review migration must enable the new read-only alert path")
values["transmog.autoCollect.qualityModes.common"] = "ask"
values["transmog.autoCollect.enabled"] = false
assert(not Collector:MigrateAutomationRules(), "current settings must not migrate twice")

Collector:SetEnabled(true, true, "test")
assert(values["transmog.autoCollect.enabled"] == true and Collector:IsRuntimeEnabled(), "explicit opt-in must enable the migrated runtime")
assert(Collector:ShouldAutoConfirmBinding(), "AUTO requests should honor automatic popup confirmation")
assert(not Collector:ShouldAutoConfirmBinding({ manualConfirmation = true }), "manual requests must never auto-confirm")
assert(Collector:ShouldAutoConfirmBinding({ ruleApproved = true }), "ASK approval should consent to the redundant bind dialog")
Collector:SetEnabled(false, true, "test")
assert(not Collector:IsRuntimeEnabled(), "automatic processing should be disabled")
assert(Collector:IsReviewAlertsEnabled(), "read-only review alerts should remain enabled")
assert(Collector:IsLootInspectionEnabled(), "loot discovery should remain active for review alerts")

local diagnostics, apiReady = Catalog:GetApiDiagnostics()
assert(apiReady, "all required mocked appearance APIs should be ready")
assert(#diagnostics == 7, "the API menu should expose the complete runtime contract")

local snapshot = Catalog:BuildSnapshot("test")
assert(snapshot.apiReady, "snapshot should use the available API")
assert(snapshot.stats.slots == 6, "all occupied carried slots should be inspected once")
assert(snapshot.stats.appearanceItems == 5, "five inventory items should expose appearances")
assert(snapshot.stats.duplicates == 1, "duplicate appearance IDs should collapse to one menu row")
assert(snapshot.stats.needsCollection == 3, "ASK, NEVER, and blacklisted appearances all still need collection")
assert(snapshot.stats.eligible == 0, "migration must not silently convert any legacy quality directly to AUTO")
assert(snapshot.stats.ask == 1, "the common appearance should be visible under its ASK rule")
assert(snapshot.stats.blocked == 2, "NEVER and blacklist rules should remain visible as blocked")
assert(snapshot.stats.collected == 1, "collected appearances should remain visible in All")
assert(#Catalog:GetNeedsEntries(snapshot) == 3, "Needs must include blocked uncollected appearances")

Collector:SetQualityMode("common", "auto")
local pausedSnapshot = Catalog:BuildSnapshot("paused AUTO test")
local pausedEntry
for index = 1, #pausedSnapshot.entries do
  if pausedSnapshot.entries[index].appearanceID == 1000 then
    pausedEntry = pausedSnapshot.entries[index]
    break
  end
end
assert(pausedEntry and pausedEntry.statusCode == "auto-paused", "AUTO rules must remain reviewable while automatic processing is off")
assert(pausedSnapshot.stats.ask == 1 and pausedSnapshot.stats.eligible == 0, "paused AUTO must count as review, not executable automation")
Collector:SetQualityMode("common", "ask")
snapshot = Catalog:BuildSnapshot("test restore")

local byID = {}
for index = 1, #snapshot.entries do
  byID[snapshot.entries[index].itemID] = snapshot.entries[index]
end
assert(byID[100] and byID[100].statusCode == "rule-ask", "common appearance should show its ASK behavior")
assert(byID[103] and byID[103].statusCode == "rule-never", "grey appearance should be visible with its NEVER reason")
assert(byID[104] and byID[104].statusCode == "blacklisted", "blacklisted appearance should be visible with its blocked reason")

local queued, failed, lockedReason = Catalog:QueueEligible(snapshot, "test")
assert(queued == 0 and failed == 0 and not lockedReason, "ASK and NEVER entries must not enter the AUTO queue")
assert(Collector:ScanBags(nil, "loot") == 0, "a missing rules service must fail closed without mutating items")
assert(#Collector.collectionQueue == 0 and collectCalls == 0, "read-only review discovery must never reach the collection API")

local manualOk, manualError = Catalog:MemorizeEntry(byID[103])
assert(manualOk, manualError or "explicit MEMORIZE should bypass future quality automation rules")
assert(collectCalls == 1, "manual MEMORIZE must call CollectItemAppearance exactly once")
assert(Collector.activeRequest, "request should wait for the user or appearance event")
assert(Collector.activeRequest.manualRequest, "manual request marker must survive dispatch")
assert(Collector.activeRequest.manualConfirmation, "manual confirmation marker must survive dispatch")
assert(not Collector:ShouldAutoConfirmBinding(Collector.activeRequest), "active manual request must not auto-confirm")
Collector:OnStaticPopupShown("CONFIRM_BINDER")
assert(not Collector.pendingPopup, "manual request must leave Ascension's confirmation popup untouched")

collected[1003] = true
Collector:HandleAppearanceCollected()
assert(not Collector.activeRequest, "appearance event should verify and complete the request")
assert(collectCalls == 1, "successful manual request must not retry")

local blockedOk = Catalog:MemorizeEntry(byID[104])
assert(not blockedOk, "the hard item blacklist must still block manual MEMORIZE")

collected[1000] = false
snapshot = Catalog:BuildSnapshot("timeout test")
local readyEntry
for index = 1, #snapshot.entries do
  if snapshot.entries[index].appearanceID == 1000 then
    readyEntry = snapshot.entries[index]
  end
end
assert(Catalog:MemorizeEntry(readyEntry), "second manual request should queue after the first completes")
assert(collectCalls == 2, "second manual request should submit once")
currentTime = 31
Collector:HandleActiveRequest(currentTime)
assert(not Collector.activeRequest, "timed-out manual request should stop")
assert(collectCalls == 2, "timed-out manual request must not retry automatically")

local eventScripts = {}
function CreateFrame()
  return {
    SetScript = function(_, scriptName, handler)
      eventScripts[scriptName] = handler
    end,
  }
end

Collector.eventFrame = nil
Collector:EnsureEventFrame()
eventScripts.OnEvent(nil, "LOOT_OPENED")
assert(Collector.lootWindowOpen and Collector.pendingLootWindow, "loot discovery must remain active until the loot session closes")
assert(Collector.pendingScanAt == nil, "LOOT_OPENED must not scan before an item reaches the bags")
eventScripts.OnEvent(nil, "BAG_UPDATE", 0)
assert(Collector.pendingBags[0] and Collector.pendingScanAt, "bag changes during loot must schedule the affected bag")
eventScripts.OnEvent(nil, "LOOT_CLOSED")
assert(not Collector.lootWindowOpen and Collector.pendingScanAt, "LOOT_CLOSED must preserve a final post-loot scan")

io.write("PASS appearance catalog migrates safe rules, preserves one-call MEMORIZE, and tracks complete loot sessions\n")
