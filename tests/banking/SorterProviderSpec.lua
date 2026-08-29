local slots = {}
local cursor
local pickupCalls = 0
local splitCalls = 0
local maxStacks = {
  [65] = 10,
  [66] = 1,
  [999] = 1,
}
local blockedItems = {}

local function clone(item)
  if not item then
    return nil
  end
  return {
    itemID = item.itemID,
    itemLink = item.itemLink,
    count = item.count,
    maxStack = item.maxStack,
  }
end

GuildBankFrame = {
  mode = "bank",
  IsShown = function()
    return true
  end,
  IsPersonalBank = true,
}

MAX_GUILDBANK_SLOTS_PER_TAB = 4

function GetCurrentGuildBankTab()
  return 1
end

function GetGuildBankTabInfo()
  return "Test", nil, true
end

function GetGuildBankItemLink(_, slotID)
  return slots[slotID] and slots[slotID].itemLink or nil
end

function GetGuildBankItemInfo(_, slotID)
  local item = slots[slotID]
  return item and "texture" or nil, item and item.count or 0, false
end

function GetItemInfo(itemLink)
  local itemID = tonumber(itemLink:match("item:(%d+)"))
  local name = itemID < 256 and string.char(itemID) or tostring(itemID)
  return name, itemLink, 1, 1, 0, "Test", "Test", maxStacks[itemID], ""
end

function GetCursorInfo()
  if not cursor then
    return nil
  end
  return "item", cursor.itemID, cursor.itemLink
end

function PickupGuildBankItem(_, slotID)
  pickupCalls = pickupCalls + 1
  local destination = slots[slotID]
  if not cursor then
    cursor = destination
    slots[slotID] = nil
    return
  end

  if destination
    and destination.itemLink == cursor.itemLink
    and destination.count < destination.maxStack then
    local moved = math.min(cursor.count, destination.maxStack - destination.count)
    destination.count = destination.count + moved
    cursor.count = cursor.count - moved
    if cursor.count == 0 then
      cursor = nil
    end
    return
  end

  slots[slotID], cursor = cursor, destination
end

function SplitGuildBankItem(_, slotID, amount)
  splitCalls = splitCalls + 1
  local source = slots[slotID]
  cursor = clone(source)
  cursor.count = amount
  source.count = source.count - amount
end

function QueryGuildBankTab()
end

_G.AscensionPlus = {
  Database = {
    Get = function(_, path, fallback)
      if path == "banking.sorter.exclusions.items" then
        return blockedItems
      elseif path == "banking.sorter.exclusions.bags.keeper" then
        return {}
      end
      return fallback
    end,
    Set = function()
    end,
  },
  Banking = {
    ContainerStore = {
      GetItemID = function(_, itemLink)
        return tonumber(itemLink:match("item:(%d+)"))
      end,
    },
  },
}

dofile("modules/banking/sorter/Planner.lua")
dofile("modules/banking/sorter/Exclusions.lua")
dofile("modules/banking/sorter/KeeperProvider.lua")

local Banking = _G.AscensionPlus.Banking
local Planner = Banking.SorterPlanner
local Provider = Banking.KeeperSorterProvider
local passed = 0

local function makeItem(itemID, count)
  return {
    itemID = itemID,
    itemLink = "item:" .. itemID,
    count = count,
    maxStack = maxStacks[itemID],
  }
end

local function reset(nextSlots)
  slots = nextSlots
  cursor = nil
  pickupCalls = 0
  splitCalls = 0
end

local function buildPlan()
  local snapshot = assert(Provider:TakeSnapshot())
  return assert(Planner:Build(snapshot))
end

local function test(name, callback)
  local ok, message = pcall(callback)
  if not ok then
    io.stderr:write("FAIL " .. name .. ": " .. tostring(message) .. "\n")
    os.exit(1)
  end
  passed = passed + 1
  io.write("PASS " .. name .. "\n")
end

test("non-empty swap restores the displaced item and clears cursor", function()
  reset({
    [1] = makeItem(66, 1),
    [2] = makeItem(65, 10),
  })
  local plan = buildPlan()
  assert(#plan.operations == 1 and plan.operations[1].kind == "swap")
  assert(Provider:Execute(1, plan.operations[1]))
  assert(pickupCalls == 3, "a non-empty swap should complete all three cursor placements")
  assert(cursor == nil, "cursor must be empty after swap")
  assert(Provider:OperationMatches(1, plan.operations[1], "after"))
end)

test("move into an empty target confirms an empty source", function()
  reset({
    [2] = makeItem(66, 1),
  })
  local plan = buildPlan()
  local operation = plan.operations[1]
  assert(operation.kind == "swap" and operation.afterSource == nil)
  assert(Provider:Execute(1, operation))
  assert(pickupCalls == 2, "an empty-target move should pick up then place")
  assert(cursor == nil, "cursor must be empty after placement")
  assert(Provider:OperationMatches(1, operation, "after"))
end)

test("partial merge splits only the required amount", function()
  reset({
    [1] = makeItem(65, 8),
    [2] = makeItem(65, 8),
  })
  local plan = buildPlan()
  local operation = plan.operations[1]
  assert(operation.kind == "stack" and operation.amount == 2)
  assert(Provider:Execute(1, operation))
  assert(splitCalls == 1 and pickupCalls == 1, "partial merge should split then place once")
  assert(cursor == nil, "cursor must be empty after partial merge")
  assert(Provider:OperationMatches(1, operation, "after"), string.format(
    "final state mismatch: source=%s target=%s expectedSource=%s expectedTarget=%s",
    slots[operation.sourceSlot] and slots[operation.sourceSlot].count or "empty",
    slots[operation.targetSlot] and slots[operation.targetSlot].count or "empty",
    operation.afterSource and operation.afterSource.count or "empty",
    operation.afterTarget and operation.afterTarget.count or "empty"
  ))
end)

test("complete source merge uses pickup without a split", function()
  reset({
    [1] = makeItem(65, 6),
    [2] = makeItem(65, 4),
  })
  local plan = buildPlan()
  local operation = plan.operations[1]
  assert(operation.kind == "stack" and operation.amount == 4, string.format("expected stack amount 4, got %s amount %s", tostring(operation.kind), tostring(operation.amount)))
  assert(Provider:Execute(1, operation))
  assert(splitCalls == 0 and pickupCalls == 2, "complete merge should pick up and place the source")
  assert(cursor == nil, "cursor must be empty after complete merge")
  local actualSource, actualTarget, actualLocked = Provider:ReadOperationSlots(1, operation)
  local sourceMatches = Planner:ItemsMatch(actualSource, operation.afterSource)
  local targetMatches = Planner:ItemsMatch(actualTarget, operation.afterTarget)
  local operationMatches, operationLocked = Provider:OperationMatches(1, operation, "after")
  assert(operationMatches, string.format(
    "final state mismatch: source=%s target=%s expectedSource=%s expectedTarget=%s targetKey=%s expectedKey=%s sourceMatches=%s targetMatches=%s locked=%s operationLocked=%s",
    slots[operation.sourceSlot] and slots[operation.sourceSlot].count or "empty",
    slots[operation.targetSlot] and slots[operation.targetSlot].count or "empty",
    operation.afterSource and operation.afterSource.count or "empty",
    operation.afterTarget and operation.afterTarget.count or "empty",
    actualTarget and actualTarget.stackKey or "empty",
    operation.afterTarget and operation.afterTarget.stackKey or "empty",
    tostring(sourceMatches),
    tostring(targetMatches),
    tostring(actualLocked),
    tostring(operationLocked)
  ))
end)

test("protected Keeper item slots are absent from logical planning", function()
  blockedItems["999"] = true
  reset({
    [1] = makeItem(66, 1),
    [2] = makeItem(999, 1),
    [3] = makeItem(65, 10),
  })

  local snapshot = assert(Provider:TakeSnapshot())
  assert(snapshot.slotCount == 3, "one protected slot should be removed from four physical slots")
  assert(snapshot.excludedItems == 1, "protected slot should be reported")
  assert(snapshot.locations[1] == 1 and snapshot.locations[2] == 3, "logical locations must jump over the protected slot")
  local plan = assert(Planner:Build(snapshot))
  local operation = assert(plan.operations[1])
  operation.sourceLocation = snapshot.locations[operation.sourceSlot]
  operation.targetLocation = snapshot.locations[operation.targetSlot]
  assert(operation.sourceLocation ~= 2 and operation.targetLocation ~= 2, "protected Keeper slot cannot participate")
  assert(Provider:Execute(1, operation))
  assert(Provider:OperationMatches(1, operation, "after"), "physical Keeper move should confirm through the logical mapping")
  assert(slots[2] and slots[2].itemID == 999, "protected Keeper item must remain untouched")
  blockedItems["999"] = nil
end)

io.write(string.format("%d sorter provider tests passed\n", passed))
