local root = (... and ... ~= "" and ...) or "."

local values = {}
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
}

dofile(root .. "/modules/talents/ProgressionPlan.lua")

local Plan = _G.Levo.TalentImport.ProgressionPlan
assert(not Plan:IsEnabled(), "progression must start disabled")
assert(Plan:Save(":5008t1:"), "a valid build must save")
assert(Plan:IsEnabled(), "saving a build must explicitly arm progression")
assert(Plan:GetBuild() == ":5008t1:", "saved build text must remain stable")
Plan:SetEnabled(false)
assert(not Plan:IsEnabled() and Plan:HasBuild(), "pausing must preserve the saved build")
Plan:Clear()
assert(not Plan:HasBuild() and not Plan:IsEnabled(), "clearing must remove both build and automatic behavior")

print("ProgressionPlanSpec: OK")
