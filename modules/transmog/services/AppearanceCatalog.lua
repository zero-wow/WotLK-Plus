local _, AP = ...
AP = AP or _G.AscensionPlus

local Collector = AP.TransmogAutoCollect
if not Collector then
  return
end

local Catalog = {
  snapshot = nil,
  revision = 0,
}

AP.TransmogAppearanceCatalog = Catalog
Collector.AppearanceCatalog = Catalog

local QUALITY_NAMES = {
  [0] = "Poor",
  [1] = "Common",
  [2] = "Uncommon",
  [3] = "Rare",
  [4] = "Epic",
  [5] = "Legendary",
  [6] = "Artifact",
  [7] = "Heirloom",
}

local STATUS = {
  ready = { title = "AUTO ON LOOT", color = "green", priority = 10 },
  ["auto-paused"] = { title = "REVIEW: AUTO PAUSED", color = "orange", priority = 12 },
  ["rule-ask"] = { title = "ASK ON LOOT", color = "orange", priority = 15 },
  queued = { title = "QUEUED", color = "gold", priority = 20 },
  blacklisted = { title = "BLACKLISTED", color = "red", priority = 30 },
  ["rule-never"] = { title = "RULE: NEVER", color = "red", priority = 40 },
  ["type-disabled"] = { title = "TYPE BLOCKED", color = "orange", priority = 50 },
  ["waiting-guid"] = { title = "WAITING FOR ITEM", color = "orange", priority = 60 },
  ["api-error"] = { title = "API ERROR", color = "red", priority = 70 },
  uncached = { title = "ITEM DATA PENDING", color = "orange", priority = 80 },
  collected = { title = "COLLECTED", color = "muted", priority = 90 },
  ["no-appearance"] = { title = "NO APPEARANCE", color = "muted", priority = 100 },
}

local function safeCall(fn, ...)
  if type(fn) ~= "function" then
    return false, "function unavailable"
  end
  return pcall(fn, ...)
end

local function now()
  return type(GetTime) == "function" and GetTime() or 0
end

local function getContainerLink(bag, slot, infoLink)
  if infoLink and infoLink ~= "" then
    return infoLink
  end
  if type(GetContainerItemLink) == "function" then
    return GetContainerItemLink(bag, slot)
  end
end

local function isQueued(appearanceID)
  if Collector.queuedAppearanceIDs and Collector.queuedAppearanceIDs[appearanceID] then
    return true
  end
  return Collector.activeRequest and Collector.activeRequest.appearanceID == appearanceID or false
end

function Catalog:GetStatus(code)
  return STATUS[code] or STATUS["api-error"]
end

function Catalog:GetQualityName(quality)
  return QUALITY_NAMES[tonumber(quality)] or "Unknown"
end

function Catalog:GetApiDiagnostics()
  local diagnostics = {
    {
      name = "C_Appearance.GetItemAppearanceID",
      ready = type(C_Appearance) == "table" and type(C_Appearance.GetItemAppearanceID) == "function",
      detail = "Maps an item ID to Ascension's wardrobe appearance ID.",
    },
    {
      name = "C_AppearanceCollection.IsAppearanceCollected",
      ready = type(C_AppearanceCollection) == "table" and type(C_AppearanceCollection.IsAppearanceCollected) == "function",
      detail = "Authoritatively reports whether the wardrobe appearance is owned.",
    },
    {
      name = "C_AppearanceCollection.CollectItemAppearance",
      ready = type(C_AppearanceCollection) == "table" and type(C_AppearanceCollection.CollectItemAppearance) == "function",
      detail = "Performs Ascension's CTRL+ALT collection action using the item GUID.",
    },
    {
      name = "GetContainerItemID",
      ready = type(GetContainerItemID) == "function",
      detail = "Reads the current item ID from an inventory slot.",
    },
    {
      name = "GetContainerItemGUID",
      ready = type(GetContainerItemGUID) == "function",
      detail = "Supplies the unique item instance required by the collection call.",
    },
    {
      name = "GetContainerItemInfo / GetContainerNumSlots",
      ready = type(GetContainerItemInfo) == "function" and type(GetContainerNumSlots) == "function",
      detail = "Builds a bounded snapshot of carried bags without continuous polling.",
    },
    {
      name = "APPEARANCE_COLLECTED listener",
      ready = Collector.moduleEnabled and Collector.eventFrame ~= nil,
      detail = Collector.appearanceEventSeen
        and "Listening; this session has confirmed at least one collection event."
        or "Listening when the Transmog module is enabled; no event has been observed this session yet.",
      informational = true,
    },
  }

  local ready = true
  for index = 1, #diagnostics do
    local diagnostic = diagnostics[index]
    if not diagnostic.informational and not diagnostic.ready then
      ready = false
    end
  end
  return diagnostics, ready
end

function Catalog:GetApiSummary()
  local diagnostics, ready = self:GetApiDiagnostics()
  local available = 0
  for index = 1, #diagnostics do
    if diagnostics[index].ready then
      available = available + 1
    end
  end
  if ready then
    return string.format("Appearance API ready: %d/%d runtime capabilities available.", available, #diagnostics)
  end
  return string.format("Appearance API incomplete: %d/%d runtime capabilities available. Open the API tab for exact details.", available, #diagnostics)
end

function Catalog:InspectSlot(bag, slot)
  local itemID = type(GetContainerItemID) == "function" and GetContainerItemID(bag, slot) or nil
  if not itemID or itemID == 0 then
    return nil, "empty"
  end

  local texture, count, locked, containerQuality, readable, lootable, infoLink
  if type(GetContainerItemInfo) == "function" then
    texture, count, locked, containerQuality, readable, lootable, infoLink = GetContainerItemInfo(bag, slot)
  end
  local itemLink = getContainerLink(bag, slot, infoLink)
  local itemName, resolvedLink, quality, itemLevel, requiredLevel, itemClass, itemSubClass, maxStack, equipSlot, itemTexture
  if type(GetItemInfo) == "function" then
    itemName, resolvedLink, quality, itemLevel, requiredLevel, itemClass, itemSubClass, maxStack, equipSlot, itemTexture = GetItemInfo(itemLink or itemID)
  end

  local entry = {
    bag = bag,
    slot = slot,
    itemID = itemID,
    guid = type(GetContainerItemGUID) == "function" and GetContainerItemGUID(bag, slot) or nil,
    link = resolvedLink or itemLink,
    name = itemName or ("Item #" .. tostring(itemID)),
    texture = itemTexture or texture,
    count = tonumber(count) or 1,
    quality = quality ~= nil and quality or containerQuality,
    itemLevel = itemLevel,
    requiredLevel = requiredLevel,
    itemClass = itemClass,
    itemSubClass = itemSubClass,
    maxStack = maxStack,
    equipSlot = equipSlot,
    locked = locked and true or false,
    readable = readable,
    lootable = lootable,
    copies = 1,
  }

  if not itemName or entry.quality == nil or not itemClass then
    entry.statusCode = "uncached"
    entry.statusReason = "The client has not cached enough item information to evaluate this slot."
    return entry, entry.statusCode
  end

  local appearanceOk, appearanceID = safeCall(C_Appearance and C_Appearance.GetItemAppearanceID, itemID)
  if not appearanceOk then
    entry.statusCode = "api-error"
    entry.statusReason = "GetItemAppearanceID failed: " .. tostring(appearanceID)
    return entry, entry.statusCode
  end
  if type(appearanceID) ~= "number" or appearanceID <= 0 then
    entry.statusCode = "no-appearance"
    entry.statusReason = "Ascension reports no wardrobe appearance for this item."
    return entry, entry.statusCode
  end
  entry.appearanceID = appearanceID

  local collectedOk, collected = safeCall(
    C_AppearanceCollection and C_AppearanceCollection.IsAppearanceCollected,
    appearanceID
  )
  if not collectedOk then
    entry.statusCode = "api-error"
    entry.statusReason = "IsAppearanceCollected failed: " .. tostring(collected)
  elseif collected then
    entry.statusCode = "collected"
    entry.statusReason = "Ascension reports this appearance is already collected."
  elseif isQueued(appearanceID) then
    entry.statusCode = "queued"
    entry.statusReason = "This appearance is already waiting in the verified collection queue."
  elseif Collector:IsBlacklisted(itemID) then
    entry.statusCode = "blacklisted"
    entry.statusReason = "This item ID is blocked by the Transmog blacklist."
  elseif not Collector:IsTypeAllowed(itemClass, equipSlot) then
    entry.statusCode = "type-disabled"
    entry.statusReason = "This equippable item type is disabled under Transmog > Auto Collect."
  elseif not entry.guid or entry.guid == "" then
    entry.statusCode = "waiting-guid"
    entry.statusReason = "The item instance GUID is not available yet; wait for the bag update and refresh."
  else
    entry.ruleMode = Collector:GetQualityMode(entry.quality)
    if entry.ruleMode == "never" then
      entry.statusCode = "rule-never"
      entry.statusReason = self:GetQualityName(entry.quality) .. " quality is set to NEVER under Transmog > Auto Collect."
    elseif entry.ruleMode == "ask" then
      entry.statusCode = "rule-ask"
      if Collector:IsReviewAlertsEnabled() then
        entry.statusReason = "Loot review will ask before binding this " .. self:GetQualityName(entry.quality) .. " item."
      else
        entry.statusReason = "This quality is set to ASK, but loot review alerts are currently off."
      end
    elseif not Collector:IsRuntimeEnabled() then
      entry.statusCode = "auto-paused"
      if Collector:IsReviewAlertsEnabled() then
        entry.statusReason = "This quality is set to AUTO, but automatic learning is off. Loot review will ask before binding it."
      else
        entry.statusReason = "This quality is set to AUTO, but automatic learning and review alerts are both off."
      end
    else
      entry.statusCode = "ready"
      entry.statusReason = "Loot processing may collect this appearance automatically under its AUTO quality rule."
    end
  end

  return entry, entry.statusCode
end

local function shouldReplaceDuplicate(existing, candidate)
  local existingPriority = (STATUS[existing.statusCode] or STATUS["api-error"]).priority
  local candidatePriority = (STATUS[candidate.statusCode] or STATUS["api-error"]).priority
  return candidatePriority < existingPriority
end

function Catalog:BuildSnapshot(source)
  local diagnostics, apiReady = self:GetApiDiagnostics()
  local snapshot = {
    source = source or "manual",
    createdAt = now(),
    apiReady = apiReady,
    diagnostics = diagnostics,
    entries = {},
    stats = {
      slots = 0,
      appearanceItems = 0,
      needsCollection = 0,
      eligible = 0,
      ask = 0,
      queued = 0,
      blocked = 0,
      collected = 0,
      uncached = 0,
      noAppearance = 0,
      duplicates = 0,
    },
  }

  if apiReady then
    local byAppearance = {}
    local firstBag = BACKPACK_CONTAINER or 0
    local lastBag = NUM_BAG_SLOTS or 4
    for bag = firstBag, lastBag do
      local slotCount = GetContainerNumSlots(bag) or 0
      for slot = 1, slotCount do
        local entry = self:InspectSlot(bag, slot)
        if entry then
          snapshot.stats.slots = snapshot.stats.slots + 1
          if entry.statusCode == "no-appearance" then
            snapshot.stats.noAppearance = snapshot.stats.noAppearance + 1
          elseif not entry.appearanceID then
            snapshot.stats.uncached = snapshot.stats.uncached + 1
          else
            snapshot.stats.appearanceItems = snapshot.stats.appearanceItems + 1
            local existing = byAppearance[entry.appearanceID]
            if existing then
              snapshot.stats.duplicates = snapshot.stats.duplicates + 1
              local copies = (existing.copies or 1) + 1
              if shouldReplaceDuplicate(existing, entry) then
                entry.copies = copies
                byAppearance[entry.appearanceID] = entry
                for index = 1, #snapshot.entries do
                  if snapshot.entries[index] == existing then
                    snapshot.entries[index] = entry
                    break
                  end
                end
              else
                existing.copies = copies
              end
            else
              byAppearance[entry.appearanceID] = entry
              snapshot.entries[#snapshot.entries + 1] = entry
            end
          end
        end
      end
    end

    for index = 1, #snapshot.entries do
      local code = snapshot.entries[index].statusCode
      if code == "collected" then
        snapshot.stats.collected = snapshot.stats.collected + 1
      else
        snapshot.stats.needsCollection = snapshot.stats.needsCollection + 1
        if code == "ready" then
          snapshot.stats.eligible = snapshot.stats.eligible + 1
        elseif code == "rule-ask" or code == "auto-paused" then
          snapshot.stats.ask = snapshot.stats.ask + 1
        elseif code == "queued" then
          snapshot.stats.queued = snapshot.stats.queued + 1
        else
          snapshot.stats.blocked = snapshot.stats.blocked + 1
        end
      end
    end

    table.sort(snapshot.entries, function(left, right)
      local leftPriority = (STATUS[left.statusCode] or STATUS["api-error"]).priority
      local rightPriority = (STATUS[right.statusCode] or STATUS["api-error"]).priority
      if leftPriority ~= rightPriority then
        return leftPriority < rightPriority
      end
      if left.quality ~= right.quality then
        return (tonumber(left.quality) or -1) > (tonumber(right.quality) or -1)
      end
      return tostring(left.name) < tostring(right.name)
    end)
  end

  self.revision = self.revision + 1
  snapshot.revision = self.revision
  self.snapshot = snapshot
  return snapshot
end

function Catalog:GetSnapshot()
  return self.snapshot
end

function Catalog:GetSnapshotSummary(snapshot)
  snapshot = snapshot or self.snapshot
  if not snapshot then
    return "Inventory has not been inspected yet."
  end
  if not snapshot.apiReady then
    return "The runtime appearance API is incomplete. Open the API tab for the missing capability."
  end
  local stats = snapshot.stats
  return string.format(
    "%d need collection: %d AUTO, %d ASK, %d queued, %d blocked. %d already collected.",
    stats.needsCollection,
    stats.eligible,
    stats.ask or 0,
    stats.queued,
    stats.blocked,
    stats.collected
  )
end

function Catalog:GetNeedsEntries(snapshot)
  snapshot = snapshot or self.snapshot
  local entries = {}
  if not snapshot then
    return entries
  end
  for index = 1, #snapshot.entries do
    local entry = snapshot.entries[index]
    if entry.statusCode ~= "collected" then
      entries[#entries + 1] = entry
    end
  end
  return entries
end

function Catalog:QueueEntry(entry, source)
  if not Collector:IsAutomationAuthorized() then
    return false, "The Transmog rules migration has not completed. Reload the interface and try again."
  end
  if not Collector.moduleEnabled then
    return false, "The Transmog module is disabled."
  end
  if not entry or not entry.bag or not entry.slot then
    return false, "The inventory location is unavailable."
  end

  local current = self:InspectSlot(entry.bag, entry.slot)
  if not current or current.itemID ~= entry.itemID or current.appearanceID ~= entry.appearanceID then
    return false, "The item moved or changed; refresh the inbox."
  end
  if current.statusCode ~= "ready" then
    return false, current.statusReason or "The appearance is not currently eligible."
  end

  current.automaticRequest = true
  local queued = Collector:QueueAppearance(current, source or "Appearance Inbox")
  if not queued then
    return false, "This appearance is already queued."
  end
  return true
end

function Catalog:MemorizeEntry(entry)
  if not Collector.moduleEnabled then
    return false, "The Transmog module is disabled. Enable it before testing MEMORIZE."
  end
  if Collector:GetPendingRequestCount() > 0 then
    return false, "Wait for the current appearance request to finish before memorizing another item."
  end
  if not entry or not entry.bag or not entry.slot then
    return false, "The inventory location is unavailable."
  end

  local current = self:InspectSlot(entry.bag, entry.slot)
  if not current or current.itemID ~= entry.itemID or current.appearanceID ~= entry.appearanceID then
    return false, "The item moved or changed; refresh the inbox."
  end

  local allowed = current.statusCode == "ready"
    or current.statusCode == "auto-paused"
    or current.statusCode == "rule-ask"
    or current.statusCode == "rule-never"
    or current.statusCode == "type-disabled"
  if not allowed then
    return false, current.statusReason or "This appearance cannot be memorized right now."
  end

  current.manualRequest = true
  current.manualConfirmation = true
  Collector.lastManualDispatch = nil
  local queued = Collector:QueueAppearance(current, "manual MEMORIZE")
  if not queued then
    return false, "This appearance is already pending."
  end

  Collector:StartNextRequest()
  local dispatch = Collector.lastManualDispatch
  if not dispatch or dispatch.appearanceID ~= current.appearanceID or not dispatch.submitted then
    return false, dispatch and dispatch.error or "Ascension did not accept the manual collection request."
  end
  return true
end

function Catalog:QueueEligible(snapshot, source)
  if not Collector:IsAutomationAuthorized() then
    return 0, 0, "The Transmog rules migration has not completed. Reload the interface and try again."
  end
  snapshot = snapshot or self.snapshot or self:BuildSnapshot(source or "Appearance Inbox")
  local queued = 0
  local failed = 0
  for index = 1, #snapshot.entries do
    local entry = snapshot.entries[index]
    if entry.statusCode == "ready" then
      local ok = self:QueueEntry(entry, source or "Appearance Inbox")
      if ok then
        queued = queued + 1
      else
        failed = failed + 1
      end
    end
  end
  return queued, failed
end

function Collector:NotifyAppearanceInbox(reason, delay)
  local inbox = AP.TransmogAppearanceInbox
  if inbox and type(inbox.ScheduleRefresh) == "function" then
    inbox:ScheduleRefresh(reason, delay)
  end
end

function Collector:OnFilterSettingsChanged()
  local rules = AP.TransmogAppearanceRules
  if rules and type(rules.OnSettingsChanged) == "function" then
    rules:OnSettingsChanged()
  end
  self:NotifyAppearanceInbox("filter change", 0)
end
