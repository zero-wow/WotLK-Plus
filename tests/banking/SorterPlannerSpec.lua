_G.AscensionPlus = {
  Banking = {},
}

dofile("modules/banking/sorter/Planner.lua")

local Planner = _G.AscensionPlus.Banking.SorterPlanner
local passed = 0

local function fail(message)
  error(message, 2)
end

local function assertEqual(actual, expected, message)
  if actual ~= expected then
    fail(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)))
  end
end

local function item(key, count, maxStack, name, itemType)
  return {
    itemID = string.byte(key),
    itemLink = "item:" .. key,
    stackKey = "item:" .. key,
    count = count or 1,
    maxStack = maxStack or 1,
    name = name or key,
    itemType = itemType or "Test",
    itemSubType = "",
    quality = 1,
    itemLevel = 1,
    originalSlot = 0,
  }
end

local function snapshot(slotCount, slots)
  for slotID = 1, slotCount do
    if slots[slotID] then
      slots[slotID].originalSlot = slotID
    end
  end
  return {
    tab = 1,
    token = "personal:1:bank",
    slotCount = slotCount,
    slots = slots,
  }
end

local function replay(plan)
  local slots = {}
  for slotID = 1, plan.slotCount do
    slots[slotID] = plan.initial[slotID]
  end

  for index = 1, #plan.operations do
    local operation = plan.operations[index]
    if not Planner:ItemsMatch(slots[operation.sourceSlot], operation.beforeSource) then
      fail("operation " .. index .. " source precondition does not match")
    end
    if not Planner:ItemsMatch(slots[operation.targetSlot], operation.beforeTarget) then
      fail("operation " .. index .. " target precondition does not match")
    end
    Planner:ApplyExpected(slots, operation)
  end

  for slotID = 1, plan.slotCount do
    if not Planner:ItemsMatch(slots[slotID], plan.target[slotID]) then
      fail("final slot " .. slotID .. " does not match the target")
    end
  end
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

test("already sorted produces no moves", function()
  local plan = assert(Planner:Build(snapshot(4, {
    [1] = item("A", 1, 1, "Alpha"),
    [2] = item("B", 1, 1, "Beta"),
  })))
  assertEqual(#plan.operations, 0, "operation count")
  replay(plan)
end)

test("compatible partial stacks consolidate before sorting", function()
  local plan = assert(Planner:Build(snapshot(4, {
    [1] = item("A", 6, 10, "Alpha"),
    [2] = item("B", 1, 1, "Beta"),
    [3] = item("A", 4, 10, "Alpha"),
  })))
  assertEqual(plan.stats.stackMoves, 1, "stack move count")
  assertEqual(plan.operations[1].kind, "stack", "first operation kind")
  assertEqual(plan.operations[1].amount, 4, "merged amount")
  replay(plan)
end)

test("three-way permutation uses two swaps", function()
  local plan = assert(Planner:Build(snapshot(3, {
    [1] = item("C", 1, 1, "Charlie"),
    [2] = item("A", 1, 1, "Alpha"),
    [3] = item("B", 1, 1, "Beta"),
  })))
  assertEqual(plan.stats.sortMoves, 2, "sort move count")
  replay(plan)
end)

test("reciprocal mismatch uses one swap", function()
  local plan = assert(Planner:Build(snapshot(2, {
    [1] = item("B", 1, 1, "Beta"),
    [2] = item("A", 1, 1, "Alpha"),
  })))
  assertEqual(plan.stats.sortMoves, 1, "sort move count")
  replay(plan)
end)

test("multiple partial stacks conserve counts", function()
  local plan = assert(Planner:Build(snapshot(5, {
    [1] = item("A", 8, 10, "Alpha"),
    [2] = item("A", 8, 10, "Alpha"),
    [3] = item("A", 8, 10, "Alpha"),
  })))
  assertEqual(plan.stats.stackMoves, 2, "stack move count")
  assertEqual(plan.target[1].count + plan.target[2].count + plan.target[3].count, 24, "item total")
  assertEqual(plan.target[1].count, 10, "first stack")
  assertEqual(plan.target[2].count, 10, "second stack")
  assertEqual(plan.target[3].count, 4, "remainder stack")
  replay(plan)
end)

io.write(string.format("%d sorter planner tests passed\n", passed))
