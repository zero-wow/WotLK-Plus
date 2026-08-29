local clock = 0
local messages = {}
local settings = {
  ["banking.deposit.conservativePacing"] = false,
  ["banking.deposit.showChatMessages"] = true,
}

function GetTime()
  return clock
end

function GetCursorInfo()
  return nil
end

function InCombatLockdown()
  return false
end

_G.AscensionPlus = {
  Banking = {
    Categories = {
      definitions = {
        all = { title = "All" },
      },
      EvaluateButton = function()
        return true, true, {}
      end,
    },
    providers = {},
  },
  Database = {
    Get = function(_, path, fallback)
      local value = settings[path]
      return value == nil and fallback or value
    end,
  },
  Print = function(_, message)
    messages[#messages + 1] = message
  end,
}

dofile("modules/banking/sorter/AdaptivePacing.lua")
dofile("modules/banking/DepositController.lua")

local Banking = _G.AscensionPlus.Banking
local Controller = Banking.Controller
local locations = {}
local snapshots = {}
local submissions = {}
local failedTransferID
local responseTimeout = 0.80
local pacingProfile = {}
local destinationToken = "test:1"

local provider = {
  IsOpen = function(_, controller)
    return controller.normalBankOpen
  end,
  CanUse = function()
    return true
  end,
  GetSourceLocations = function()
    return locations
  end,
  GetSourceSnapshot = function(_, _, location)
    return snapshots[location.id]
  end,
  HasDestinationCapacity = function()
    return true
  end,
  Transfer = function(_, _, location)
    submissions[#submissions + 1] = location.id
    if failedTransferID == location.id then
      failedTransferID = nil
      error("simulated transfer failure")
    end
  end,
  GetBankName = function()
    return "Test Bank"
  end,
  GetDestinationToken = function()
    return destinationToken
  end,
  GetMoveDelay = function()
    return 0.10
  end,
  GetResponseTimeout = function()
    return responseTimeout
  end,
  GetTransferPacingProfile = function()
    return pacingProfile
  end,
}

Banking.providers.character = provider
Controller.normalBankOpen = true
Controller.eventFrame = {
  Show = function() end,
  Hide = function() end,
}

local function advance(seconds)
  clock = clock + seconds
  Controller:OnUpdate(seconds)
end

local function fireBankUpdate()
  Controller:OnEvent("BAG_UPDATE")
  Controller:OnUpdate(0)
end

local function confirm(...)
  for index = 1, select("#", ...) do
    snapshots[select(index, ...)] = nil
  end
  fireBankUpdate()
end

local function advanceToNextSubmission()
  local delay = math.max(0, (Controller.nextSubmitAt or clock) - clock)
  advance(delay + 0.002)
end

local function setScenario(itemCount, overrides, timeout)
  Controller:Cancel(nil, true)
  locations = {}
  snapshots = {}
  submissions = {}
  failedTransferID = nil
  responseTimeout = timeout or 0.80
  destinationToken = "test:1"
  pacingProfile = {
    startDelay = 0.10,
    minDelay = 0.025,
    maxDelay = 0.50,
    fastConfirmation = 0.12,
    fastConfirmationsRequired = 3,
    accelerationFactor = 0.82,
    initialInFlight = 10,
    maxInFlight = 12,
    delayedConfirmation = 0.60,
    backoffCooldown = 0.50,
    pipelineRecoveryConfirmations = 3,
  }
  for key, value in pairs(overrides or {}) do
    pacingProfile[key] = value
  end

  for index = 1, itemCount do
    locations[index] = { kind = "test", id = index }
    snapshots[index] = {
      itemID = 2000 + index,
      itemLink = "item:" .. tostring(2000 + index),
      count = 1,
      locked = false,
    }
  end
  Controller.normalBankOpen = true
end

setScenario(6, {
  initialInFlight = 4,
  maxInFlight = 6,
  pipelineRecoveryConfirmations = 2,
})
Controller:StartTransfer("all", "deposit")
Controller:OnUpdate(0)
assert(#submissions == 1, "the first stack must submit immediately")
advance(0.101)
advance(0.101)
advance(0.101)
assert(#submissions == 4 and Controller:GetPendingCount() == 4, "distinct stacks must pipeline at the 10/sec cadence without waiting for confirmations")
advance(0.101)
assert(#submissions == 4, "the bounded in-flight window must stop additional submissions")
confirm(1, 2)
assert(Controller:GetPipelineLimit() == 5, "confirmed pipeline work must cautiously reopen one in-flight slot")
assert(#submissions == 5, "a newly available pipeline slot must resume submissions without a confirmation-serialized pause")
assert(Controller:GetObservedRate(clock) and Controller:GetObservedRate(clock) > 0, "progress must expose measured throughput")

setScenario(4)
Controller:StartTransfer("all", "deposit")
Controller:OnUpdate(0)
for itemID = 1, 3 do
  advance(0.02)
  confirm(itemID)
  if itemID < 3 then
    advanceToNextSubmission()
  end
end
assert(Controller:GetPacingDelay() < 0.10, "three fast confirmations must accelerate the submission cadence")

setScenario(2, {
  initialInFlight = 1,
  maxInFlight = 1,
  delayedConfirmation = 0.20,
  backoffCooldown = 0.20,
}, 0.50)
Controller:StartTransfer("all", "deposit")
Controller:OnUpdate(0)
local beforeBackoff = Controller:GetPacingDelay()
advance(0.21)
assert(Controller.awaiting and Controller.awaiting.delayed, "a delayed source confirmation must be retained for its bounded timeout")
assert(Controller:GetPacingDelay() > beforeBackoff, "a delayed confirmation must immediately reduce submission speed")
assert(Controller.stats.backoffs == 1, "one delayed batch must produce only one adaptive backoff")
advance(0.30)
assert(Controller.processing and Controller.awaiting and Controller.awaiting.entry.location.id == 2, "an unchanged unlocked stack must be skipped while the next stack continues")
assert(Controller.stats.rejected == 1, "the timed-out stack must be counted as skipped")
confirm(2)
assert(not Controller.processing and Controller.stats.movedStacks == 1, "the queue must finish after a later stack succeeds")

setScenario(2)
failedTransferID = 1
Controller:StartTransfer("all", "deposit")
Controller:OnUpdate(0)
assert(Controller.processing and Controller:GetPendingCount() == 0, "a failed API call must leave no phantom in-flight request")
assert(Controller.stats.rejected == 1, "a failed API call must skip only that stack")
advanceToNextSubmission()
confirm(2)
assert(not Controller.processing and Controller.stats.movedStacks == 1, "the queue must continue and finish after an API failure")

setScenario(2)
Controller:StartTransfer("all", "deposit")
Controller:OnUpdate(0)
destinationToken = "test:2"
fireBankUpdate()
assert(not Controller.processing and Controller.lastStatus:find("tab or view changed", 1, true), "changing the active bank view must stop a pipelined transfer")

local sawBackoffMessage = false
for index = 1, #messages do
  if messages[index]:find("backed off", 1, true) then
    sawBackoffMessage = true
    break
  end
end
assert(sawBackoffMessage, "adaptive backoff must remain visible in chat")

io.write("PASS transfers use bounded adaptive pipelining, measured throughput, and per-stack failure recovery\n")
