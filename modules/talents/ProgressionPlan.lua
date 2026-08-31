local _, AP = ...
AP = AP or _G.Levo or _G.WotLKPlus or _G.AscensionPlus

local Plan = {}
AP.TalentImport.ProgressionPlan = Plan

local function cleanBuild(value)
  value = tostring(value or "")
  return value:gsub("^%s+", ""):gsub("%s+$", "")
end

function Plan:GetBuild()
  return cleanBuild(AP.Database:Get("talentImport.progression.build", ""))
end

function Plan:HasBuild()
  return self:GetBuild() ~= ""
end

function Plan:IsEnabled()
  return AP.Database:Get("talentImport.progression.enabled", false) and self:HasBuild()
end

function Plan:Save(build)
  build = cleanBuild(build)
  if build == "" then
    return false, "Paste a build string before saving a progression plan."
  end
  AP.Database:Set("talentImport.progression.build", build)
  AP.Database:Set("talentImport.progression.enabled", true)
  return true
end

function Plan:SetEnabled(enabled)
  AP.Database:Set("talentImport.progression.enabled", enabled and self:HasBuild() or false)
end

function Plan:Clear()
  AP.Database:Set("talentImport.progression.build", "")
  AP.Database:Set("talentImport.progression.enabled", false)
end

function Plan:Summary()
  if not self:HasBuild() then
    return "No saved progression build."
  end
  if self:IsEnabled() then
    return "Saved progression build is armed for out-of-combat talent points."
  end
  return "Saved progression build is paused."
end
