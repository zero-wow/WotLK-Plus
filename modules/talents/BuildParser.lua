local _, AP = ...
AP = AP or _G.Levo or _G.WotLKPlus or _G.AscensionPlus

AP.TalentImport = AP.TalentImport or {}
local Parser = {}
AP.TalentImport.BuildParser = Parser

local function trim(value)
  return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

function Parser:Parse(text)
  local source = trim(text)
  if source == "" then
    return nil, "Paste an Ascension build string first."
  end

  local targets = {}
  local byID = {}
  for entryID, rank in source:lower():gmatch(":(%d+)t(%d+)") do
    entryID = tonumber(entryID)
    rank = tonumber(rank)
    if entryID and entryID > 0 and rank and rank > 0 then
      local existing = byID[entryID]
      if existing then
        existing.rank = math.max(existing.rank, rank)
      else
        local target = {
          id = entryID,
          rank = rank,
          order = #targets + 1,
        }
        targets[#targets + 1] = target
        byID[entryID] = target
      end
    end
  end

  if #targets == 0 then
    return nil, "No ':EntryIDtRank' targets were found in that build string."
  end

  return {
    source = source,
    targets = targets,
    byID = byID,
  }
end
