local _, AP = ...
AP = AP or _G.Levo or _G.WotLKPlus or _G.AscensionPlus

local Banking = AP.Banking
local Planner = {}

Banking.SorterPlanner = Planner

local function cloneItem(item)
  if not item then
    return nil
  end

  local copy = {}
  for key, value in pairs(item) do
    copy[key] = value
  end
  return copy
end

local function copySlots(slots, slotCount)
  local copy = {}
  for slotID = 1, slotCount do
    copy[slotID] = cloneItem(slots[slotID])
  end
  return copy
end

local function normalizedText(value)
  return string.lower(tostring(value or ""))
end

local function compareNumberDescending(left, right)
  left = tonumber(left) or 0
  right = tonumber(right) or 0
  if left ~= right then
    return left > right
  end
end

local function compareTextAscending(left, right)
  left = normalizedText(left)
  right = normalizedText(right)
  if left ~= right then
    return left < right
  end
end

function Planner:ItemsMatch(left, right, includeCount)
  if left == nil or right == nil then
    return left == right
  end

  local leftKey = left.stackKey or left.itemLink or left.itemID
  local rightKey = right.stackKey or right.itemLink or right.itemID
  if leftKey ~= rightKey then
    return false
  end

  if includeCount ~= false and (tonumber(left.count) or 0) ~= (tonumber(right.count) or 0) then
    return false
  end
  return true
end

function Planner:DefaultLess(left, right)
  local result = compareTextAscending(left.itemType, right.itemType)
  if result ~= nil then
    return result
  end

  result = compareTextAscending(left.itemSubType, right.itemSubType)
  if result ~= nil then
    return result
  end

  result = compareTextAscending(left.equipLoc, right.equipLoc)
  if result ~= nil then
    return result
  end

  result = compareNumberDescending(left.quality, right.quality)
  if result ~= nil then
    return result
  end

  result = compareNumberDescending(left.itemLevel, right.itemLevel)
  if result ~= nil then
    return result
  end

  result = compareTextAscending(left.name, right.name)
  if result ~= nil then
    return result
  end

  local leftID = tonumber(left.itemID) or 0
  local rightID = tonumber(right.itemID) or 0
  if leftID ~= rightID then
    return leftID < rightID
  end

  local leftCount = tonumber(left.count) or 0
  local rightCount = tonumber(right.count) or 0
  if leftCount ~= rightCount then
    return leftCount > rightCount
  end
  return (tonumber(left.originalSlot) or 0) < (tonumber(right.originalSlot) or 0)
end

local function makeOperation(kind, sourceSlot, targetSlot, amount, beforeSource, beforeTarget, afterSource, afterTarget)
  return {
    kind = kind,
    sourceSlot = sourceSlot,
    targetSlot = targetSlot,
    amount = amount,
    beforeSource = cloneItem(beforeSource),
    beforeTarget = cloneItem(beforeTarget),
    afterSource = cloneItem(afterSource),
    afterTarget = cloneItem(afterTarget),
  }
end

local function findMergeSource(slots, slotCount, targetSlot, target)
  local needed = target.maxStack - target.count
  local bestSlot
  local bestCount

  for slotID = targetSlot + 1, slotCount do
    local source = slots[slotID]
    if source
      and source.count > 0
      and source.count < source.maxStack
      and source.stackKey == target.stackKey then
      local drainsSource = source.count <= needed
      local bestDrains = bestCount and bestCount <= needed
      if not bestSlot
        or (drainsSource and not bestDrains)
        or (drainsSource == bestDrains and source.count > bestCount) then
        bestSlot = slotID
        bestCount = source.count
      end
    end
  end

  return bestSlot
end

local function consolidateStacks(slots, slotCount, operations)
  local moveCount = 0

  for targetSlot = 1, slotCount do
    local target = slots[targetSlot]
    if target and target.maxStack > 1 and target.count < target.maxStack then
      local sourceSlot = findMergeSource(slots, slotCount, targetSlot, target)
      while sourceSlot do
        local source = slots[sourceSlot]
        local amount = math.min(target.maxStack - target.count, source.count)
        local beforeSource = cloneItem(source)
        local beforeTarget = cloneItem(target)

        target.count = target.count + amount
        source.count = source.count - amount
        if source.count <= 0 then
          slots[sourceSlot] = nil
        end

        operations[#operations + 1] = makeOperation(
          "stack",
          sourceSlot,
          targetSlot,
          amount,
          beforeSource,
          beforeTarget,
          slots[sourceSlot],
          target
        )
        moveCount = moveCount + 1

        if target.count >= target.maxStack then
          break
        end
        sourceSlot = findMergeSource(slots, slotCount, targetSlot, target)
      end
    end
  end

  return moveCount
end

local function collectItems(slots, slotCount)
  local items = {}
  for slotID = 1, slotCount do
    if slots[slotID] then
      items[#items + 1] = cloneItem(slots[slotID])
    end
  end
  return items
end

local function buildCompactTarget(items, slotCount, less)
  table.sort(items, less)
  local target = {}
  for slotID = 1, #items do
    target[slotID] = items[slotID]
  end
  return target, #items
end

local function getQualityRule(policy, item)
  local rules = policy and policy.qualityRules
  if type(rules) ~= "table" or not item then
    return nil
  end
  return rules[tonumber(item.quality) or -1]
end

local function buildPolicyTarget(items, slotCount, less, policy)
  local slotGroups = policy and policy.slotGroups
  if type(slotGroups) ~= "table" or type(policy.qualityRules) ~= "table" then
    return buildCompactTarget(items, slotCount, less)
  end

  local groups = {}
  local groupOrder = {}
  for slotID = 1, slotCount do
    local group = slotGroups[slotID] or "default"
    if not groups[group] then
      groups[group] = {}
      groupOrder[#groupOrder + 1] = group
    end
    groups[group][#groups[group] + 1] = slotID
  end

  local routed = {}
  local remaining = {}
  for index = 1, #items do
    local item = items[index]
    local rule = getQualityRule(policy, item)
    local destination = rule and rule.destination or "any"
    if destination and destination ~= "" and destination ~= "any" then
      if not groups[destination] then
        return nil, nil, string.format("The selected destination '%s' is unavailable in this sorting context.", tostring(destination))
      end
      routed[destination] = routed[destination] or {}
      routed[destination][#routed[destination] + 1] = item
    else
      remaining[#remaining + 1] = item
    end
  end

  local target = {}
  local reserved = {}
  local routedItems = 0
  for group, bucket in pairs(routed) do
    local slots = groups[group]
    if #bucket > #slots then
      return nil, nil, string.format(
        "The selected destination '%s' has room for %d stack%s but %d matching stack%s need it.",
        tostring(group),
        #slots,
        #slots == 1 and "" or "s",
        #bucket,
        #bucket == 1 and "" or "s"
      )
    end
    reserved[group] = true
    routedItems = routedItems + #bucket
    table.sort(bucket, less)
    for index = 1, #bucket do
      target[slots[index]] = bucket[index]
    end
  end

  local availableSlots = {}
  for groupIndex = 1, #groupOrder do
    local group = groupOrder[groupIndex]
    if not reserved[group] then
      local slots = groups[group]
      for index = 1, #slots do
        availableSlots[#availableSlots + 1] = slots[index]
      end
    end
  end
  if #remaining > #availableSlots then
    return nil, nil, string.format(
      "%d stack%s cannot fit outside the bags reserved for quality destinations.",
      #remaining,
      #remaining == 1 and "" or "s"
    )
  end

  table.sort(remaining, function(left, right)
    local leftRule = getQualityRule(policy, left)
    local rightRule = getQualityRule(policy, right)
    local leftBottom = leftRule and leftRule.mode == "bottom"
    local rightBottom = rightRule and rightRule.mode == "bottom"
    if leftBottom ~= rightBottom then
      return not leftBottom
    end
    return less(left, right)
  end)
  for index = 1, #remaining do
    target[availableSlots[index]] = remaining[index]
  end

  return target, #items, nil, routedItems
end

local function buildTarget(slots, slotCount, less, policy)
  local items = collectItems(slots, slotCount)
  if not policy then
    return buildCompactTarget(items, slotCount, less)
  end
  return buildPolicyTarget(items, slotCount, less, policy)
end

local function findDesiredSource(planner, slots, target, desiredSlot, slotCount)
  local desired = target[desiredSlot]
  local displaced = slots[desiredSlot]
  local firstMatch

  for sourceSlot = desiredSlot + 1, slotCount do
    if planner:ItemsMatch(slots[sourceSlot], desired) then
      firstMatch = firstMatch or sourceSlot
      if planner:ItemsMatch(displaced, target[sourceSlot]) then
        return sourceSlot
      end
    end
  end
  return firstMatch
end

local function planSortMoves(planner, slots, slotCount, target, operations)
  local moveCount = 0

  for targetSlot = 1, slotCount do
    if not planner:ItemsMatch(slots[targetSlot], target[targetSlot]) then
      local sourceSlot = findDesiredSource(planner, slots, target, targetSlot, slotCount)
      if not sourceSlot then
        return nil, string.format("Could not resolve target slot %d", targetSlot)
      end

      local beforeSource = cloneItem(slots[sourceSlot])
      local beforeTarget = cloneItem(slots[targetSlot])
      slots[targetSlot], slots[sourceSlot] = slots[sourceSlot], slots[targetSlot]
      operations[#operations + 1] = makeOperation(
        "swap",
        sourceSlot,
        targetSlot,
        nil,
        beforeSource,
        beforeTarget,
        slots[sourceSlot],
        slots[targetSlot]
      )
      moveCount = moveCount + 1
    end
  end

  return moveCount
end

function Planner:Build(snapshot, less)
  if type(snapshot) ~= "table" or type(snapshot.slots) ~= "table" then
    return nil, "A bank snapshot is required"
  end

  local slotCount = tonumber(snapshot.slotCount) or 0
  if slotCount < 1 then
    return nil, "The snapshot has no bank slots"
  end

  local initial = copySlots(snapshot.slots, slotCount)
  local simulated = copySlots(snapshot.slots, slotCount)
  local operations = {}
  local stackMoves = consolidateStacks(simulated, slotCount, operations)
  local target, occupiedSlots, targetError, routedItems = buildTarget(simulated, slotCount, less or function(left, right)
    return self:DefaultLess(left, right)
  end, snapshot)
  if not target then
    return nil, targetError
  end
  local sortMoves, sortError = planSortMoves(self, simulated, slotCount, target, operations)
  if not sortMoves then
    return nil, sortError
  end

  return {
    tab = snapshot.tab,
    token = snapshot.token,
    slotCount = slotCount,
    occupiedSlots = occupiedSlots,
    initial = initial,
    target = target,
    operations = operations,
    stats = {
      stackMoves = stackMoves,
      sortMoves = sortMoves,
      routedItems = routedItems or 0,
      totalMoves = #operations,
    },
  }
end

function Planner:ApplyExpected(slots, operation)
  slots[operation.sourceSlot] = cloneItem(operation.afterSource)
  slots[operation.targetSlot] = cloneItem(operation.afterTarget)
end
