local clock = 0

function GetTime()
  return clock
end

function InCombatLockdown()
  return false
end

function CreateFrame()
  return {
    Hide = function() end,
    Show = function() end,
    SetScript = function() end,
    RegisterEvent = function() end,
    UnregisterAllEvents = function() end,
  }
end

local settings = {
  ["banking.sorter.enabled"] = true,
  ["banking.sorter.showChatMessages"] = false,
  ["banking.sorter.conservativePacing"] = false,
}

_G.AscensionPlus = {
  Banking = {
    Controller = {
      processing = false,
    },
  },
  Database = {
    Get = function(_, path, fallback)
      local value = settings[path]
      if value == nil then
        return fallback
      end
      return value
    end,
  },
  Print = function() end,
}

dofile("modules/banking/sorter/Planner.lua")
dofile("modules/banking/sorter/AdaptivePacing.lua")

local Banking = _G.AscensionPlus.Banking
local Planner = Banking.SorterPlanner
local provider = {
  token = "personal:1:bank",
  tab = 1,
  mutations = 0,
  queries = 0,
  autoApply = true,
}

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

local function cloneSnapshot(source)
  local copy = {
    tab = source.tab,
    token = source.token,
    slotCount = source.slotCount,
    lockedSlots = source.lockedSlots or 0,
    slots = {},
  }
  for slotID = 1, source.slotCount do
    copy.slots[slotID] = cloneItem(source.slots[slotID])
  end
  return copy
end

function provider:CanUse()
  return true
end

function provider:GetBankName()
  return "Personal Bank"
end

function provider:GetTab()
  return self.tab
end

function provider:GetToken()
  return self.token
end

function provider:HasCursorItem()
  return false
end

function provider:TakeSnapshot()
  return cloneSnapshot(self.snapshot)
end

function provider:OperationMatches(_, operation, phase)
  local expectedSource
  local expectedTarget
  if phase == "after" then
    expectedSource = operation.afterSource
    expectedTarget = operation.afterTarget
  else
    expectedSource = operation.beforeSource
    expectedTarget = operation.beforeTarget
  end
  return Planner:ItemsMatch(self.snapshot.slots[operation.sourceSlot], expectedSource)
    and Planner:ItemsMatch(self.snapshot.slots[operation.targetSlot], expectedTarget), false
end

function provider:Execute(_, operation)
  local matches = self:OperationMatches(self.tab, operation, "before")
  if not matches then
    return false, "stale"
  end

  self.mutations = self.mutations + 1
  self.lastOperation = operation
  if self.autoApply then
    Planner:ApplyExpected(self.snapshot.slots, operation)
  end
  return true
end

function provider:CompleteCursor()
  return true
end

function provider:Query()
  self.queries = self.queries + 1
  return true
end

Banking.KeeperSorterProvider = provider
dofile("modules/banking/sorter/SorterController.lua")

local Sorter = Banking.Sorter
Sorter:Enable()

local passed = 0

local function fail(message)
  error(message, 2)
end

local function assertEqual(actual, expected, message)
  if actual ~= expected then
    fail(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)))
  end
end

local function item(key, name)
  return {
    itemID = string.byte(key),
    itemLink = "item:" .. key,
    stackKey = "item:" .. key,
    count = 1,
    maxStack = 1,
    name = name or key,
    itemType = "Test",
    itemSubType = "",
    quality = 1,
    itemLevel = 1,
    originalSlot = 1,
  }
end

local function setSnapshot(slots, slotCount)
  provider.snapshot = {
    tab = 1,
    token = provider.token,
    slotCount = slotCount,
    lockedSlots = 0,
    slots = slots,
  }
  provider.mutations = 0
  provider.queries = 0
  provider.lastOperation = nil
  provider.autoApply = true
  clock = 0
  Sorter:ResetRunState()
  Sorter.enabled = true
  Sorter.lastError = nil
end

local function advance(seconds)
  clock = clock + seconds
  Sorter:OnUpdate(seconds)
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

test("submits one move and waits for confirmation", function()
  setSnapshot({
    [1] = item("B", "Beta"),
    [2] = item("A", "Alpha"),
  }, 2)

  assertEqual(Sorter:Start(), true, "start result")
  assertEqual(provider.mutations, 0, "mutations before update")
  advance(0.001)
  assertEqual(provider.mutations, 1, "first mutation")
  assertEqual(Sorter.phase, "confirming", "phase after mutation")
  advance(0.05)
  assertEqual(provider.mutations, 1, "no dependent mutation before confirmation")
  assertEqual(Sorter.phase, "finalizing", "phase after confirmation")
  advance(0.05)
  assertEqual(Sorter:IsRunning(), false, "finished state")
end)

test("discards remaining plan when a future slot becomes stale", function()
  setSnapshot({
    [1] = item("C", "Charlie"),
    [2] = item("A", "Alpha"),
    [3] = item("B", "Beta"),
  }, 3)

  Sorter:Start()
  advance(0.001)
  advance(0.05)
  assertEqual(provider.mutations, 1, "confirmed first mutation")

  local nextOperation = Sorter.plan.operations[Sorter.currentIndex]
  provider.snapshot.slots[nextOperation.sourceSlot] = item("Z", "Zulu")
  advance(0.08)
  assertEqual(provider.mutations, 1, "no stale dependent mutation")
  assertEqual(Sorter:IsRunning(), false, "stale plan stopped")
end)

test("cancel waits for active confirmation and submits nothing else", function()
  setSnapshot({
    [1] = item("B", "Beta"),
    [2] = item("A", "Alpha"),
  }, 2)
  provider.autoApply = false

  Sorter:Start()
  advance(0.001)
  assertEqual(provider.mutations, 1, "active mutation")
  Sorter:Cancel("Test cancellation.")
  assertEqual(Sorter:IsRunning(), true, "still running until confirmation")

  Planner:ApplyExpected(provider.snapshot.slots, provider.lastOperation)
  advance(0.05)
  assertEqual(provider.mutations, 1, "no mutation after cancellation")
  assertEqual(Sorter:IsRunning(), false, "cancelled after confirmation")
end)

io.write(string.format("%d sorter controller tests passed\n", passed))
