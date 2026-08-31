local root = (... and ... ~= "" and ...) or "."

local clock = 0
local values = {}
local rank = 0
local commits = 0

_G.GetTime = function() return clock end
_G.InCombatLockdown = function() return false end
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
    }
  end,
  Spend = function()
    rank = rank + 1
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

print("TalentRuntimeSpec: OK")
