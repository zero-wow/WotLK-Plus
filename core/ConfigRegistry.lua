local _, AP = ...
AP = AP or _G.AscensionPlus

local Registry = {
  pages = {},
  roots = {},
  searchCache = {},
}

AP.ConfigRegistry = Registry

local function sortPages(pages)
  table.sort(pages, function(left, right)
    local leftOrder = left.order or 100
    local rightOrder = right.order or 100

    if leftOrder == rightOrder then
      local leftTitle = tostring(left.title or left.id)
      local rightTitle = tostring(right.title or right.id)
      if leftTitle ~= rightTitle then
        return leftTitle < rightTitle
      end
      return tostring(left.id) < tostring(right.id)
    end

    return leftOrder < rightOrder
  end)
end

local function resolveText(value, page, option)
  if type(value) == "function" then
    return value(page, option)
  end
  return value
end

local function appendSearchText(parts, value)
  local valueType = type(value)
  if valueType == "string" or valueType == "number" or valueType == "boolean" then
    parts[#parts + 1] = tostring(value)
  end
end

local function matchesTerms(haystack, terms)
  if #terms == 0 then
    return true
  end

  for index = 1, #terms do
    if not haystack:find(terms[index], 1, true) then
      return false
    end
  end

  return true
end

function Registry:RegisterPage(page)
  page.children = page.children or {}
  self.pages[page.id] = page
  self.searchCache[page.id] = nil
end

function Registry:GetPage(id)
  return self.pages[id]
end

function Registry:GetChildren(id)
  local page = self.pages[id]
  return page and page.children or {}
end

function Registry:GetRoots()
  return self.roots
end

function Registry:GetResolvedOptions(page)
  if not page then
    return {}
  end

  local options = page.options
  if type(options) == "function" then
    options = options(page)
  end

  if type(options) ~= "table" then
    return {}
  end

  return options
end

function Registry:GetPagePath(id)
  local segments = {}
  local current = self.pages[id]

  while current do
    table.insert(segments, 1, current.title or current.id)
    if not current.parent then
      break
    end
    current = self.pages[current.parent]
  end

  return table.concat(segments, " / ")
end

function Registry:Finalize()
  self.roots = {}
  self.searchCache = {}

  for _, page in pairs(self.pages) do
    page.children = {}
  end

  for _, page in pairs(self.pages) do
    if page.parent then
      local parent = self.pages[page.parent]
      if parent then
        parent.children[#parent.children + 1] = page
      end
    else
      self.roots[#self.roots + 1] = page
    end
  end

  sortPages(self.roots)
  for _, page in pairs(self.pages) do
    sortPages(page.children)
  end
end

function Registry:GetSearchText(page)
  local textParts = {}
  appendSearchText(textParts, page.id)
  appendSearchText(textParts, resolveText(page.title, page))
  appendSearchText(textParts, resolveText(page.description, page))
  appendSearchText(textParts, resolveText(page.searchText, page))
  appendSearchText(textParts, resolveText(page.treeTitle, page))

  local options = self:GetResolvedOptions(page)
  for index = 1, #options do
    local option = options[index]
    appendSearchText(textParts, resolveText(option.label, page, option))
    appendSearchText(textParts, resolveText(option.description, page, option))
    appendSearchText(textParts, resolveText(option.text, page, option))
    appendSearchText(textParts, resolveText(option.path, page, option))
    appendSearchText(textParts, resolveText(option.buttonText, page, option))

    local choices = resolveText(option.choices, page, option)
    if type(choices) == "table" then
      for choiceIndex = 1, #choices do
        local choice = choices[choiceIndex]
        appendSearchText(textParts, resolveText(choice.label, page, option))
        appendSearchText(textParts, choice.value)
      end
    end
  end

  -- Options may expose live status text. Rebuild the index on demand so a
  -- previous search cannot leave those function-derived values stale.
  return AP.Utils.NormalizeSearch(table.concat(textParts, " "))
end

function Registry:PageMatchesTerms(page, terms)
  if #terms == 0 then
    return true
  end

  return matchesTerms(self:GetSearchText(page), terms)
end

function Registry:PageMatchesQuery(page, query)
  return self:PageMatchesTerms(page, AP.Utils.SplitSearch(query))
end

function Registry:Search(query)
  local terms = AP.Utils.SplitSearch(query)
  local results = {}

  if #terms == 0 then
    return results
  end

  for _, page in pairs(self.pages) do
    if self:PageMatchesTerms(page, terms) then
      local title = resolveText(page.title, page) or page.id
      results[#results + 1] = {
        pageId = page.id,
        title = title,
        description = resolveText(page.description, page) or "",
        path = page.parent and self:GetPagePath(page.parent) or "Top Level",
      }
    end
  end

  table.sort(results, function(left, right)
    local leftPath = AP.Utils.NormalizeSearch(left.path)
    local rightPath = AP.Utils.NormalizeSearch(right.path)
    if leftPath ~= rightPath then
      return leftPath < rightPath
    end

    local leftTitle = AP.Utils.NormalizeSearch(left.title)
    local rightTitle = AP.Utils.NormalizeSearch(right.title)
    if leftTitle ~= rightTitle then
      return leftTitle < rightTitle
    end

    return tostring(left.pageId) < tostring(right.pageId)
  end)

  return results
end

function Registry:BuildTree(query, expandedState)
  local nodes = {}
  local include = {}
  local matched = {}
  local terms = AP.Utils.SplitSearch(query)

  if #terms > 0 then
    for _, page in pairs(self.pages) do
      if self:PageMatchesTerms(page, terms) then
        matched[page.id] = true
        local current = page
        while current do
          include[current.id] = true
          if not current.parent then
            break
          end
          current = self.pages[current.parent]
        end
      end
    end
  end

  local function visit(page, depth, rootId)
    if #terms > 0 and not include[page.id] then
      return
    end

    local hasChildren = #page.children > 0
    local isExpanded = expandedState and expandedState[page.id] and true or false
    local searchExpanded = #terms > 0 and include[page.id] and true or false
    local resolvedRootId = rootId or page.id

    nodes[#nodes + 1] = {
      id = page.id,
      title = page.treeTitle or page.title,
      depth = depth,
      isRoot = depth == 0,
      rootId = resolvedRootId,
      parentId = page.parent,
      hasChildren = hasChildren,
      expanded = hasChildren and (isExpanded or searchExpanded) or false,
      matched = matched[page.id] or false,
      classToken = page.classToken,
      treeShadow = page.treeShadow,
    }

    if hasChildren and (isExpanded or searchExpanded) then
      for index = 1, #page.children do
        visit(page.children[index], depth + 1, resolvedRootId)
      end
    end
  end

  for index = 1, #self.roots do
    visit(self.roots[index], 0, self.roots[index].id)
  end

  return nodes
end
