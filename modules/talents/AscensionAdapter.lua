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

local function childrenOf(frame)
  if not frame or type(frame.GetChildren) ~= "function" then
    return {}
  end
  local ok, children = pcall(function()
    return { frame:GetChildren() }
  end)
  return ok and children or {}
end

local function nodeEntryID(node)
  local entry = node and node.entry
  return tonumber(entry and (entry.ID or entry.id) or node and (node.entryID or node.entryId))
end

local function pendingRank(entryID)
  local api = _G.C_CharacterAdvancement
  if not entryID or type(api) ~= "table" or type(api.GetPendingRankByEntryID) ~= "function" then
    return nil
  end
  local ok, rank = pcall(api.GetPendingRankByEntryID, entryID)
  if ok and rank ~= nil then
    return math.max(tonumber(rank) or 0, 0)
  end
  return nil
end

local function nodeRank(node, entryID)
  -- Ascension's nodes retain committed rank during a pending build. Its pending
  -- rank is the source of truth until the native Apply/Save action runs.
  local pending = pendingRank(entryID)
  if pending ~= nil then
    return pending
  end
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

local function clickHandler(control)
  return call(control, "GetScript", "OnClick")
end

local function findClickable(root)
  local seen = setmetatable({}, { __mode = "k" })
  local fallback
  local function visit(control, depth)
    if not control or seen[control] or depth > 3 then
      return nil
    end
    seen[control] = true

    if type(clickHandler(control)) == "function" then
      return control
    end
    if type(control.Click) == "function" then
      fallback = fallback or control
    end

    local namedChildren = {
      control.Button,
      control.button,
      control.SelectButton,
      control.selectButton,
      control.NodeButton,
      control.nodeButton,
      control.EntryButton,
      control.entryButton,
      control.HitBox,
      control.hitBox,
    }
    for index = 1, #namedChildren do
      local clickable = visit(namedChildren[index], depth + 1)
      if clickable then
        return clickable
      end
    end
    local children = childrenOf(control)
    for index = 1, #children do
      local clickable = visit(children[index], depth + 1)
      if clickable then
        return clickable
      end
    end
  end
  return visit(root, 0) or fallback
end

local function controlCanSpend(control)
  if not control then
    return false
  end
  if type(control.IsEnabled) == "function" then
    local enabled = call(control, "IsEnabled")
    if enabled ~= nil then
      return enabled and true or false
    end
  end
  if type(control.IsDisabled) == "function" then
    local disabled = call(control, "IsDisabled")
    if disabled ~= nil then
      return not disabled
    end
  end
  if control.disabled ~= nil then
    return not control.disabled
  end
  if control.enabled ~= nil then
    return control.enabled and true or false
  end
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
  if not self:GetTreeView() then
    return false, "Ascension's Character Advancement talent tree is not loaded yet."
  end
  return true
end

function Adapter:ClickControl(control)
  if not control then
    return false, "No native control was found."
  end
  if type(control.Click) == "function" then
    local ok, message = pcall(control.Click, control, "LeftButton")
    return ok, ok and nil or tostring(message)
  end
  local onClick = clickHandler(control)
  if type(onClick) == "function" then
    local ok, message = pcall(onClick, control, "LeftButton")
    return ok, ok and nil or tostring(message)
  end
  return false, "The native control has no usable click handler."
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
        rank = nodeRank(node, entryID),
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
  return self:ClickControl(entry.control)
end

local COMMIT_CONTROL_NAMES = {
  "CoATalentFrameTreeViewBottomBarApplyBuildButton",
  "CoATalentFrameTreeViewBottomBarApplyButton",
  "CoATalentFrameTreeViewBottomBarSaveBuildButton",
  "CoATalentFrameTreeViewBottomBarSaveButton",
}

local function looksLikeCommit(control)
  local text = tostring(call(control, "GetText") or ""):lower()
  local name = tostring(call(control, "GetName") or ""):lower()
  local label = text .. " " .. name
  if label:find("import", 1, true) or label:find("export", 1, true) or label:find("cancel", 1, true) then
    return false
  end
  return label:find("apply", 1, true) ~= nil
    or label:find("commit", 1, true) ~= nil
    or label:find("save", 1, true) ~= nil
end

function Adapter:GetCommitControl()
  for index = 1, #COMMIT_CONTROL_NAMES do
    local control = _G[COMMIT_CONTROL_NAMES[index]]
    if control and findClickable(control) then
      return findClickable(control)
    end
  end

  local import = _G.CoATalentFrameTreeViewBottomBarImportBuildButton
  local parent = import and call(import, "GetParent")
  local seen = setmetatable({}, { __mode = "k" })
  local function search(control, depth)
    if not control or seen[control] or depth > 3 then
      return nil
    end
    seen[control] = true
    local clickable = findClickable(control)
    if clickable and looksLikeCommit(control) then
      return clickable
    end
    local children = childrenOf(control)
    for index = 1, #children do
      local result = search(children[index], depth + 1)
      if result then
        return result
      end
    end
  end
  return search(parent, 0)
end

function Adapter:CommitPreview()
  local control = self:GetCommitControl()
  if not control then
    return false, "Ascension's native Apply/Save control was not found."
  end
  if not controlCanSpend(control) then
    return false, "Ascension's native Apply/Save control is not currently enabled."
  end
  return self:ClickControl(control)
end
