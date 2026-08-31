local _, AP = ...
AP = AP or _G.Levo or _G.WotLKPlus or _G.AscensionPlus

local Adapter = {}
AP.TalentImport.AscensionAdapter = Adapter

local function call(object, method, ...)
  if not object or type(object[method]) ~= "function" then
    return nil
  end
  local ok, first, second = pcall(object[method], object, ...)
  if ok then
    return first, second
  end
end

local function nodeEntryID(node)
  local entry = node and node.entry
  return tonumber(entry and (entry.ID or entry.id) or node and (node.entryID or node.entryId))
end

local function nodeRank(node)
  local entry = node and node.entry
  return math.max(tonumber(node and (node.rank or node.currentRank)) or tonumber(entry and (entry.Rank or entry.rank)) or 0, 0)
end

local function nodeMaxRank(node)
  local entry = node and node.entry
  local ranks = entry and entry.Spells
  return math.max(tonumber(node and (node.maxRank or node.MaxRank)) or tonumber(entry and (entry.MaxRank or entry.maxRank)) or (type(ranks) == "table" and #ranks or 1), 1)
end

local function nodeName(node)
  local entry = node and node.entry
  return entry and (entry.Name or entry.name) or nil
end

local function findClickable(node)
  local candidates = {}
  local function add(candidate)
    if candidate then
      candidates[#candidates + 1] = candidate
    end
  end
  add(node)
  add(node and node.Button)
  add(node and node.button)
  add(node and node.SelectButton)
  add(node and node.selectButton)

  for index = 1, #candidates do
    local candidate = candidates[index]
    if type(candidate.Click) == "function" or type(candidate.GetScript) == "function" then
      return candidate
    end
  end
end

local function controlCanSpend(control)
  if not control then
    return false
  end
  if type(control.IsEnabled) == "function" then
    local enabled = call(control, "IsEnabled")
    return enabled and true or false
  end
  if type(control.IsDisabled) == "function" then
    local disabled = call(control, "IsDisabled")
    return not disabled
  end
  if control.disabled ~= nil then
    return not control.disabled
  end
  if control.enabled ~= nil then
    return control.enabled and true or false
  end
  -- The native node may expose availability only through its click handler. A
  -- queued click still has to confirm a rank change before another pick runs.
  return true
end

function Adapter:GetTalentFrame()
  return _G.CoATalentFrame
end

function Adapter:GetTreeView()
  local frame = self:GetTalentFrame()
  return frame and frame.TreeView or _G.CoATalentFrameTreeView
end

function Adapter:IsAvailable()
  local treeView = self:GetTreeView()
  if not treeView then
    return false, "Ascension's Character Advancement talent tree is not loaded yet."
  end
  return true
end

function Adapter:GetCatalog()
  local treeView = self:GetTreeView()
  if not treeView then
    return {}, "Ascension's Character Advancement talent tree is not loaded yet."
  end

  local catalog = {}
  local seenNodes = setmetatable({}, { __mode = "k" })
  local function visit(node)
    if not node or seenNodes[node] then
      return
    end
    seenNodes[node] = true

    local entryID = nodeEntryID(node)
    if entryID then
      local control = findClickable(node)
      local existing = catalog[entryID]
      local candidate = {
        id = entryID,
        name = nodeName(node) or ("Entry #" .. tostring(entryID)),
        rank = nodeRank(node),
        maxRank = nodeMaxRank(node),
        node = node,
        control = control,
      }
      candidate.canSpend = function()
        return candidate.rank < candidate.maxRank and controlCanSpend(candidate.control)
      end
      if not existing or candidate.rank > existing.rank then
        catalog[entryID] = candidate
      end
    end

    if type(node.nodes) == "table" then
      for index = 1, #node.nodes do
        visit(node.nodes[index])
      end
    end
  end

  local function scanTree(tree)
    if not tree then
      return
    end
    if type(tree.EnumerateNodes) == "function" then
      for node in tree:EnumerateNodes() do
        visit(node)
      end
    elseif type(tree.nodes) == "table" then
      for index = 1, #tree.nodes do
        visit(tree.nodes[index])
      end
    end
  end

  scanTree(treeView.ClassTree)
  scanTree(treeView.SpecTree)
  if not next(catalog) then
    return catalog, "No Ascension talent entries are currently visible in the tree."
  end
  return catalog
end

function Adapter:Spend(entry)
  if not entry or not entry.control then
    return false, "That requested talent is not clickable in the current tree."
  end
  if not entry.canSpend or not entry.canSpend() then
    return false, "That requested talent is not currently affordable or its prerequisites are not met."
  end

  local control = entry.control
  if type(control.Click) == "function" then
    local ok, message = pcall(control.Click, control, "LeftButton")
    return ok, ok and nil or tostring(message)
  end
  local onClick = call(control, "GetScript", "OnClick")
  if type(onClick) == "function" then
    local ok, message = pcall(onClick, control, "LeftButton")
    return ok, ok and nil or tostring(message)
  end
  return false, "The native talent entry has no usable click handler."
end
