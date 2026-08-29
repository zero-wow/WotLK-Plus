local root = (... and ... ~= "" and ...) or "."

_G.AscensionPlus = {}
dofile(root .. "/core/Utils.lua")
dofile(root .. "/core/ConfigRegistry.lua")

local AP = _G.AscensionPlus
local Registry = AP.ConfigRegistry

local function resetRegistry()
  Registry.pages = {}
  Registry.roots = {}
  Registry.searchCache = {}
end

local function findNode(nodes, pageID)
  for index = 1, #nodes do
    if nodes[index].id == pageID then
      return nodes[index], index
    end
  end
end

local function assertSingleResult(query, expectedPageID)
  local results = Registry:Search(query)
  assert(#results == 1, "expected one result for " .. tostring(query))
  assert(results[1].pageId == expectedPageID, "unexpected result for " .. tostring(query))
end

resetRegistry()
Registry:RegisterPage({ id = "root", title = "Root", order = 10 })
Registry:RegisterPage({ id = "root.child", parent = "root", title = "Child", order = 10 })
Registry:RegisterPage({
  id = "root.child.leaf",
  parent = "root.child",
  title = "Leaf",
  order = 10,
  searchText = "ancestral needle",
})
Registry:Finalize()

local collapsed = Registry:BuildTree("", {})
assert(#collapsed == 1, "collapsed roots must hide all descendants")
assert(collapsed[1].id == "root" and collapsed[1].expanded == false, "root should remain collapsed")
assert(collapsed[1].isRoot == true and collapsed[1].depth == 0, "root metadata must identify root rows")
assert(collapsed[1].rootId == "root" and collapsed[1].parentId == nil, "root metadata must preserve ancestry")

local rootExpanded = Registry:BuildTree("", { root = true })
assert(#rootExpanded == 2, "expanding a root should reveal only its immediate collapsed branch")
assert(rootExpanded[2].id == "root.child" and rootExpanded[2].depth == 1, "child depth must be stable")
assert(rootExpanded[2].isRoot == false and rootExpanded[2].rootId == "root", "children must identify their root")

local searched = Registry:BuildTree("needle", {})
assert(#searched == 3, "search must reveal every ancestor on a matching path")
assert(findNode(searched, "root").expanded == true, "search must auto-expand the matching root")
assert(findNode(searched, "root.child").expanded == true, "search must auto-expand matching ancestors")
assert(findNode(searched, "root.child.leaf").matched == true, "matching leaf must be marked")

resetRegistry()
local dynamicStatus = "first pulse"
Registry:RegisterPage({
  id = "feature.magic-id",
  title = "Feature",
  options = function()
    return {
      { type = "toggle", path = "settings.deep.flag", label = "Flag" },
      { type = "button", buttonText = "Rebuild Cache" },
      {
        type = "segmented",
        choices = {
          { value = "never", label = "Never" },
          { value = "auto", label = function() return "Automatic Choice" end },
        },
      },
      { type = "text", text = function() return dynamicStatus end },
    }
  end,
})
Registry:Finalize()

assertSingleResult("magic id", "feature.magic-id")
assertSingleResult("settings deep flag", "feature.magic-id")
assertSingleResult("rebuild cache", "feature.magic-id")
assertSingleResult("automatic choice", "feature.magic-id")
assertSingleResult("first pulse", "feature.magic-id")
dynamicStatus = "second pulse"
assert(#Registry:Search("first pulse") == 0, "dynamic search text must not remain cached")
assertSingleResult("second pulse", "feature.magic-id")

resetRegistry()
Registry:RegisterPage({ id = "parent.z", title = "Zebra Parent", order = 10 })
Registry:RegisterPage({ id = "parent.a", title = "Alpha Parent", order = 20 })
Registry:RegisterPage({ id = "parent.a.beta", parent = "parent.a", title = "Beta", searchText = "shared term" })
Registry:RegisterPage({ id = "parent.z.alpha", parent = "parent.z", title = "Alpha", searchText = "shared term" })
Registry:RegisterPage({ id = "parent.a.alpha", parent = "parent.a", title = "Alpha", searchText = "shared term" })
Registry:Finalize()

local ordered = Registry:Search("shared term")
assert(#ordered == 3, "deterministic ordering fixture should return three children")
assert(ordered[1].pageId == "parent.a.alpha", "results should sort by path, then title")
assert(ordered[2].pageId == "parent.a.beta", "same-path results should sort by title")
assert(ordered[3].pageId == "parent.z.alpha", "later paths should follow earlier paths")

resetRegistry()
AP.data = {}
local registeredClassesModule
AP.Modules = {
  Register = function(_, moduleID, module)
    assert(moduleID == "classes", "Classes module must retain its module ID")
    registeredClassesModule = module
  end,
}

dofile(root .. "/data/Classes.lua")
dofile(root .. "/modules/classes/ClassesModule.lua")
assert(registeredClassesModule and registeredClassesModule.OnInitialize, "Classes module must register")
registeredClassesModule.OnInitialize()
Registry:RegisterPage({ id = "afterthought", title = "Earlier Feature", order = 20 })
Registry:Finalize()

local expectedPageCount = #AP.data.classes + 2
local actualPageCount = 0
for pageID in pairs(Registry.pages) do
  actualPageCount = actualPageCount + 1
  assert(not tostring(pageID):find(".spec.", 1, true), "empty specialization leaf pages must not be registered")
end
assert(actualPageCount == expectedPageCount, "Class Library should register one page per class and no spec leaves")
assert(Registry:GetPage("classes").title == "Class Library", "Classes root should use the consolidated display title")
assert(Registry:GetRoots()[#Registry:GetRoots()].id == "classes", "Class Library should be the final root")

for index = 1, #AP.data.classes do
  local classData = AP.data.classes[index]
  local classPage = Registry:GetPage("classes." .. classData.id)
  assert(classPage, "missing class page " .. tostring(classData.id))
  assert(#classPage.children == 0, "class pages should no longer contain empty spec leaves")
end

local mechanicsResults = Registry:Search("mechanics")
local foundTinker = false
for index = 1, #mechanicsResults do
  if mechanicsResults[index].pageId == "classes.tinker" then
    foundTinker = true
  end
end
assert(foundTinker, "specialization terms must find their consolidated class page")

io.write("PASS config registry navigation, search, ordering, and class consolidation\n")
