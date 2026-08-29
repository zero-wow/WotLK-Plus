local _, AP = ...
AP = AP or _G.AscensionPlus

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

local function buildTarget(slots, slotCount, less)
  local items = {}
  for slotID = 1, slotCount do
    if slots[slotID] then
      items[#items + 1] = cloneItem(slots[slotID])
    end
  end

  table.sort(items, less)
  local target = {}
  for slotID = 1, #items do
    target[slotID] = items[slotID]
  end
  return target, #items
end

local function findDesiredSource(planner, slots, target, desiredSlot, occupiedSlots, slotCount)
  local desired = target[desiredSlot]
  local displaced = slots[desiredSlot]
  local firstMatch

  for sourceSlot = desiredSlot + 1, slotCount do
    if planner:ItemsMatch(slots[sourceSlot], desired) then
      firstMatch = firstMatch or sourceSlot
      if sourceSlot <= occupiedSlots and planner:ItemsMatch(displaced, target[sourceSlot]) then
        return sourceSlot
      end
    end
  end
  return firstMatch
end

local function planSortMoves(planner, slots, slotCount, target, occupiedSlots, operations)
  local moveCount = 0

  for targetSlot = 1, occupiedSlots do
    if not planner:ItemsMatch(slots[targetSlot], target[targetSlot]) then
      local sourceSlot = findDesiredSource(planner, slots, target, targetSlot, occupiedSlots, slotCount)
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
  local target, occupiedSlots = buildTarget(simulated, slotCount, less or function(left, right)
    return self:DefaultLess(left, right)
  end)
  local sortMoves, sortError = planSortMoves(self, simulated, slotCount, target, occupiedSlots, operations)
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
      totalMoves = #operations,
    },
  }
end

function Planner:ApplyExpected(slots, operation)
  slots[operation.sourceSlot] = cloneItem(operation.afterSource)
  slots[operation.targetSlot] = cloneItem(operation.afterTarget)
end

