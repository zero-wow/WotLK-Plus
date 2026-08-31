local root = (... and ... ~= "" and ...) or "."

local clicked = 0
local entryNode = {
  entry = { ID = 5008, Name = "Test Talent", Spells = { 1, 2 } },
  rank = 0,
}
entryNode.button = {
  IsEnabled = function() return true end,
  Click = function()
    clicked = clicked + 1
    entryNode.rank = entryNode.rank + 1
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
assert(Adapter:Spend(entry), "the adapter must invoke the native entry control")
assert(clicked == 1 and entryNode.rank == 1, "the adapter must not invent a separate talent mutation path")

print("AscensionAdapterSpec: OK")
