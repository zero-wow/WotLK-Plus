local _, AP = ...
AP = AP or _G.Levo or _G.WotLKPlus or _G.AscensionPlus

local Planner = {}
AP.TalentImport.BuildPlanner = Planner

local function rankOf(entry)
  return math.max(tonumber(entry and entry.rank) or 0, 0)
end

local function canSpend(entry)
  if type(entry and entry.canSpend) == "function" then
    local ok, available = pcall(entry.canSpend, entry)
    return ok and available and true or false
  end
  return entry and entry.canSpend and true or false
end

function Planner:Analyze(build, catalog)
  local result = {
    matched = 0,
    satisfied = 0,
    missing = {},
    blocked = {},
    ready = nil,
  }
  catalog = type(catalog) == "table" and catalog or {}

  for index = 1, #(build and build.targets or {}) do
    local target = build.targets[index]
    local entry = catalog[target.id]
    if not entry then
      result.missing[#result.missing + 1] = target
    else
      result.matched = result.matched + 1
      if rankOf(entry) >= target.rank then
        result.satisfied = result.satisfied + 1
      elseif not result.ready and canSpend(entry) then
        result.ready = {
          id = target.id,
          targetRank = target.rank,
          currentRank = rankOf(entry),
          entry = entry,
        }
      else
        result.blocked[#result.blocked + 1] = {
          id = target.id,
          targetRank = target.rank,
          currentRank = rankOf(entry),
        }
      end
    end
  end

  return result
end

function Planner:Next(build, catalog)
  local analysis = self:Analyze(build, catalog)
  if analysis.ready then
    return analysis.ready, analysis
  end
  return nil, analysis
end
