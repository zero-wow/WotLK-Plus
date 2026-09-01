local root = (... and ... ~= "" and ...) or "."

local clicked = 0
local directAdds = 0
local pendingRanks = { [5008] = 0 }
local entryNode = {
  entry = { ID = 5008, Name = "Test Talent", Spells = { 1, 2 } },
  rank = 0,
}
entryNode.button = {
  IsEnabled = function() return true end,
  Click = function()
    clicked = clicked + 1
    pendingRanks[5008] = pendingRanks[5008] + 1
  end,
}

local function enumerate(nodes)
  local index = 0
  return function()
    index = index + 1
    return nodes[index]
  end
end

_G.Levo = { TalentImport = {} }
_G.C_CharacterAdvancement = {
  GetPendingRankByEntryID = function(entryID)
    return pendingRanks[entryID]
  end,
  CanAddByEntryID = function(entryID, ranks)
    return entryID == 5008 and ranks == 1 and pendingRanks[entryID] < 2
  end,
  AddByEntryID = function(entryID, ranks)
    assert(entryID == 5008 and ranks == 1, "the direct add API must receive one requested rank")
    directAdds = directAdds + 1
    pendingRanks[entryID] = pendingRanks[entryID] + ranks
  end,
}
_G.CoATalentFrame = {
  TreeView = {
    ClassTree = { EnumerateNodes = function() return enumerate({ entryNode }) end },
    SpecTree = { EnumerateNodes = function() return enumerate({}) end },
  },
}

dofile(root .. "/modules/talents/AscensionAdapter.lua")

local Adapter = _G.Levo.TalentImport.AscensionAdapter
assert(Adapter:IsAvailable(), "the native Ascension tree must be detected")
local catalog = assert(Adapter:GetCatalog())
local entry = assert(catalog[5008], "visible entry IDs must be catalogued")
assert(entry.name == "Test Talent" and entry.maxRank == 2, "node metadata must be retained")
assert(entry.canSpend(), "enabled native nodes must be affordable")
assert(Adapter:Spend(entry), "the adapter must invoke Ascension's direct pending-build add API")
assert(directAdds == 1 and clicked == 0 and pendingRanks[5008] == 1,
  "direct API application must not click a presentational tree child")
catalog = assert(Adapter:GetCatalog())
assert(catalog[5008].rank == 1, "the pending Ascension preview rank must be used after a native click")

local nestedClicks = 0
local nestedControl = {
  IsEnabled = function() return true end,
  GetScript = function(_, script)
    if script == "OnClick" then
      return function()
        nestedClicks = nestedClicks + 1
      end
    end
  end,
}
local nestedNode = {
  entry = { ID = 6000, Name = "Nested Talent", Spells = { 1 } },
  rank = 0,
  GetScript = function() return nil end,
  GetChildren = function() return nestedControl end,
}
_G.CoATalentFrame.TreeView.ClassTree = {
  EnumerateNodes = function() return enumerate({ nestedNode }) end,
}
_G.C_CharacterAdvancement.CanAddByEntryID = nil
_G.C_CharacterAdvancement.AddByEntryID = nil
catalog = assert(Adapter:GetCatalog())
assert(Adapter:Spend(catalog[6000]), "a native child control must be discovered when the node itself is not clickable")
assert(nestedClicks == 1, "the child click handler must receive the requested spend")

local committed = 0
local applyButton = {
  IsEnabled = function() return true end,
  GetText = function() return "Apply Build" end,
  GetScript = function(_, script)
    if script == "OnClick" then
      return function()
        committed = committed + 1
      end
    end
  end,
}
local importButton = {
  GetText = function() return "Import Build" end,
  GetScript = function() return nil end,
}
local bottomBar = {
  GetChildren = function() return importButton, applyButton end,
}
importButton.GetParent = function() return bottomBar end
_G.CoATalentFrameTreeViewBottomBarImportBuildButton = importButton
local directCommits = 0
_G.CanApplyPendingBuild = function() return true end
_G.ApplyPendingBuild = function()
  directCommits = directCommits + 1
end
assert(Adapter:CommitPreview(), "Ascension's direct ApplyPendingBuild action must be invoked")
assert(directCommits == 1 and committed == 0, "the direct pending-build commit must win over visual-button guessing")

_G.ApplyPendingBuild = nil
_G.CanApplyPendingBuild = nil
assert(Adapter:CommitPreview(), "the native Apply/Save sibling must remain a compatibility fallback")
assert(committed == 1, "the native Apply/Save fallback must be invoked when the direct action is unavailable")

print("AscensionAdapterSpec: OK")
