local _, AP = ...
AP = AP or _G.AscensionPlus

local Utils = {}
AP.Utils = Utils

function Utils.DeepCopy(value)
  if type(value) ~= "table" then
    return value
  end

  local copy = {}
  for key, nestedValue in pairs(value) do
    copy[Utils.DeepCopy(key)] = Utils.DeepCopy(nestedValue)
  end

  return copy
end

function Utils.MergeDefaults(target, defaults)
  if type(defaults) ~= "table" then
    return target
  end

  if type(target) ~= "table" then
    target = {}
  end

  for key, value in pairs(defaults) do
    if type(value) == "table" then
      target[key] = Utils.MergeDefaults(target[key], value)
    elseif target[key] == nil then
      target[key] = value
    end
  end

  return target
end

function Utils.Trim(text)
  return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

function Utils.NormalizeSearch(text)
  local normalized = Utils.Trim(text):lower()
  normalized = normalized:gsub("[%c%p]+", " ")
  normalized = normalized:gsub("%s+", " ")
  return Utils.Trim(normalized)
end

function Utils.SplitSearch(text)
  local terms = {}
  local normalized = Utils.NormalizeSearch(text)

  for term in normalized:gmatch("%S+") do
    terms[#terms + 1] = term
  end

  return terms
end

function Utils.PathSegments(path)
  local segments = {}
  for segment in tostring(path or ""):gmatch("[^%.]+") do
    segments[#segments + 1] = segment
  end
  return segments
end

function Utils.Clamp(value, low, high)
  if value < low then
    return low
  end
  if value > high then
    return high
  end
  return value
end

function Utils.Colorize(hex, text)
  return string.format("|cff%s%s|r", tostring(hex or "ffffff"), tostring(text or ""))
end
