local root = (... and ... ~= "" and ...) or "."

local clock = 0
local values = {}
local rank = 0
local delayedRank = 0
local delayedPointReady = false
local commits = 0
local playerLevel = 10
local unspentPoints = 0

_G.GetTime = function() return clock end
_G.InCombatLockdown = function() return false end
_G.UnitLevel = function() return playerLevel end
_G.GetActiveTalentGroup = function() return 1 end
_G.GetUnspentTalentPoints = function() return unspentPoints end
_G.Levo = {
  TalentImport = {},
  Database = {
    Get = function(_, path, fallback)
      return values[path] == nil and fallback or values[path]
    end,
    Set = function(_, path, value)
      values[path] = value
    end,
  },
  Print = function() end,
}

dofile(root .. "/modules/talents/BuildParser.lua")
dofile(root .. "/modules/talents/BuildPlanner.lua")
dofile(root .. "/modules/talents/ProgressionPlan.lua")

_G.Levo.TalentImport.ImportWindow = {
  SetReport = function() end,
}
_G.Levo.TalentImport.AscensionAdapter = {
  IsAvailable = function() return true end,
  GetCatalog = function()
    return {
      [1] = {
        id = 1,
        name = "Test Talent",
        rank = rank,
        maxRank = 2,
        canSpend = function() return rank < 2 end,
      },
      [2] = {
        id = 2,
        name = "Delayed Talent",
        rank = delayedRank,
        maxRank = 1,
        canSpend = function() return delayedPointReady and delayedRank < 1 end,
      },
    }
  end,
  Spend = function(_, entry)
    if entry.id == 2 then
      delayedRank = delayedRank + 1
    else
      rank = rank + 1
    end
    return true
  end,
  CommitPreview = function()
    commits = commits + 1
    return true
  end,
}

dofile(root .. "/modules/talents/TalentRuntime.lua")

local Runtime = _G.Levo.TalentImport.Runtime
Runtime.enabled = true
assert(Runtime:ApplyNow(":1t2:"), "manual application must start with the first affordable rank")
clock = 0.2
Runtime:Process()
clock = 0.4
Runtime:Process()
clock = 0.6
Runtime:Process()
clock = 0.8
Runtime:Process()
clock = 1.0
Runtime:Process()
assert(rank == 2, "the runtime must re-evaluate and apply every currently affordable requested rank")
assert(commits == 1, "a completed manual application must invoke native commit once")

assert(Runtime:SaveAndApply(":1t2:"), "a completed build can still be saved for later progression")
assert(_G.Levo.TalentImport.ProgressionPlan:IsEnabled(), "SAVE & AUTO must arm persisted progression")

assert(_G.Levo.TalentImport.ProgressionPlan:Save(":2t1:"), "a future-level build must remain saved")
Runtime:WakeProgression("PLAYER_LEVEL_UP", 0)
Runtime:TryProgression()
assert(Runtime.progressionDue, "an early level-up pass must retry while Ascension's new point is still settling")

delayedPointReady = true
unspentPoints = 1
clock = clock + 0.9
Runtime:TryProgression()
assert(Runtime.session, "the saved build must start automatically once the delayed point becomes affordable")
clock = clock + 0.2
Runtime:Process()
clock = clock + 0.2
Runtime:Process()
assert(delayedRank == 1, "automatic progression must spend the newly affordable saved rank")
assert(commits == 2, "automatic progression must invoke Ascension's native Apply/Save action")

Runtime:PollProgressionSignals()
playerLevel = 11
unspentPoints = 2
Runtime:PollProgressionSignals()
assert(Runtime.progressionDue, "the watchdog must recover when Ascension's normal point event is missed")

print("TalentRuntimeSpec: OK")
