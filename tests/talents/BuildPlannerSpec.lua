local root = (... and ... ~= "" and ...) or "."

_G.Levo = { TalentImport = {} }
dofile(root .. "/modules/talents/BuildParser.lua")
dofile(root .. "/modules/talents/BuildPlanner.lua")

local Parser = _G.Levo.TalentImport.BuildParser
local Planner = _G.Levo.TalentImport.BuildPlanner
local build = assert(Parser:Parse(":1t2:2t1:3t1:4t1:"))

local catalog = {
  [1] = { rank = 1, maxRank = 2, canSpend = function() return false end },
  [2] = { rank = 0, maxRank = 1, canSpend = function() return false end },
  [3] = { rank = 0, maxRank = 1, canSpend = function() return true end },
  [4] = { rank = 0, maxRank = 1, canSpend = function() return true end },
}

local action, analysis = Planner:Next(build, catalog)
assert(action and action.id == 3, "the first currently affordable requested talent must be selected")
assert(analysis.satisfied == 0 and #analysis.blocked == 3, "non-selected targets must be reported as waiting")

catalog[1].canSpend = function() return true end
action = Planner:Next(build, catalog)
assert(action and action.id == 1 and action.targetRank == 2, "declared target order must win when multiple ranks are affordable")

catalog[1].rank = 2
catalog[2].rank = 1
catalog[3].rank = 1
catalog[4].rank = 1
action, analysis = Planner:Next(build, catalog)
assert(not action and analysis.satisfied == 4, "completed builds must not produce an extra click")

print("BuildPlannerSpec: OK")
