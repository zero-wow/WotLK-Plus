local _, AP = ...
AP = AP or _G.AscensionPlus

local Theme = AP.UI.Theme
local SEARCH_PAGE_ID = "__search__"
local SEARCH_DEBOUNCE_SECONDS = 0.08
local LAYOUT = {
  minWidth = 900,
  minHeight = 560,
  maxWidth = 1440,
  maxHeight = 900,
  defaultWidth = 1040,
  defaultHeight = 660,
  topBarHeight = 52,
  outerInset = 12,
  navigationWidth = 238,
  contentGutter = 18,
  footerHeight = 24,
  contentBottom = 34,
}

local ConfigWindow = {
  frame = nil,
  searchQuery = "",
  selectedPageId = "general",
  lastExplicitPageId = "general",
  expanded = {},
  pendingSearchQuery = nil,
  pendingSearchElapsed = 0,
  suppressSearchChanged = false,
  treeRendered = false,
  treeDirty = true,
  lastTreeQuery = nil,
  lastTreeSelectedId = nil,
}

AP.ConfigWindow = ConfigWindow
ConfigWindow.Layout = LAYOUT

local function profileNow()
  if type(debugprofilestop) == "function" then
    return debugprofilestop()
  end
  return nil
end

local function profileElapsed(started)
  if started then
    return debugprofilestop() - started
  end
  return nil
end

local function saveWindowState(frame)
  if not frame then
    return
  end

  local point, _, relPoint, x, y = frame:GetPoint(1)
  AP.Database:Set("interface.window", {
    point = point or "CENTER",
    relPoint = relPoint or point or "CENTER",
    x = x or 0,
    y = y or 0,
    width = math.floor(frame:GetWidth() or LAYOUT.defaultWidth),
    height = math.floor(frame:GetHeight() or LAYOUT.defaultHeight),
  })
end

local function applyWindowState(frame)
  local state = AP.Database:Get("interface.window", {})
  local width = AP.Utils.Clamp(tonumber(state.width) or LAYOUT.defaultWidth, LAYOUT.minWidth, LAYOUT.maxWidth)
  local height = AP.Utils.Clamp(tonumber(state.height) or LAYOUT.defaultHeight, LAYOUT.minHeight, LAYOUT.maxHeight)

  frame:SetWidth(width)
  frame:SetHeight(height)
  frame:ClearAllPoints()
  frame:SetPoint(state.point or "CENTER", UIParent, state.relPoint or state.point or "CENTER", state.x or 0, state.y or 0)
end

local function updateSearchHint(self)
  if not self.SearchHint then
    return
  end

  local showHint = AP.Database:Get("interface.searchHints", true)
  if showHint and self.SearchBox:GetText() == "" and not self.SearchBox:HasFocus() then
    self.SearchHint:Show()
  else
    self.SearchHint:Hide()
  end

  if self.SearchClear then
    if self.SearchBox:GetText() ~= "" then
      self.SearchClear:Show()
    else
      self.SearchClear:Hide()
    end
  end
end

function ConfigWindow:RefreshTree()
  if not self.frame then
    return
  end

  local started = profileNow()
  local selectedId = self.selectedPageId
  if selectedId == SEARCH_PAGE_ID then
    selectedId = self.lastExplicitPageId
  end

  if self.treeRendered
    and not self.treeDirty
    and self.lastTreeQuery == self.searchQuery
    and self.lastTreeSelectedId == selectedId then
    self.lastTreeMs = 0
    return
  end

  local nodes = AP.ConfigRegistry:BuildTree(self.searchQuery, self.expanded)
  self.frame.Tree:SetTreeData(nodes, selectedId, self.treeCallbacks)
  self.treeRendered = true
  self.treeDirty = false
  self.lastTreeQuery = self.searchQuery
  self.lastTreeSelectedId = selectedId
  self.lastTreeNodeCount = #nodes
  self.lastTreeMs = profileElapsed(started)
  if self.frame.Tree.ScrollToNode then
    self.frame.Tree:ScrollToNode(selectedId)
  end
end

function ConfigWindow:RefreshContent()
  if not self.frame then
    return
  end

  local started = profileNow()
  if self.selectedPageId == SEARCH_PAGE_ID then
    self.frame.Pages:RenderSearch(self.searchQuery, AP.ConfigRegistry:Search(self.searchQuery))
    self.lastContentMs = profileElapsed(started)
    return
  end

  local page = AP.ConfigRegistry:GetPage(self.selectedPageId)
  if page then
    self.frame.Pages:RenderPage(page)
  end
  self.lastContentMs = profileElapsed(started)
end

function ConfigWindow:Refresh()
  local started = profileNow()
  if self.frame then
    updateSearchHint(self.frame)
  end
  self:RefreshTree()
  self:RefreshContent()
  self.lastRefreshMs = profileElapsed(started)
end

function ConfigWindow:RefreshSearchHint()
  if self.frame then
    updateSearchHint(self.frame)
  end
end

function ConfigWindow:EnsurePageVisible(pageId)
  local page = AP.ConfigRegistry:GetPage(pageId)
  while page and page.parent do
    self.expanded[page.parent] = true
    page = AP.ConfigRegistry:GetPage(page.parent)
  end
end

function ConfigWindow:SelectPage(pageId, suppressRefresh)
  if not pageId or not AP.ConfigRegistry:GetPage(pageId) then
    return
  end

  local hadUncommittedSearch = self.pendingSearchQuery ~= nil
    or (self.frame and self.frame.SearchBox:GetText() ~= "")
  self:CancelPendingSearch()
  if self.searchQuery ~= "" or hadUncommittedSearch then
    self.searchQuery = ""
    if self.frame and self.frame.SearchBox:GetText() ~= "" then
      self.suppressSearchChanged = true
      self.frame.SearchBox:SetText("")
      self.suppressSearchChanged = false
    end
    self.treeDirty = true
  end

  self.selectedPageId = pageId
  self.lastExplicitPageId = pageId
  self:EnsurePageVisible(pageId)
  self.treeDirty = true

  if AP.Database:Get("interface.restoreLastPage", true) then
    AP.Database:Set("state.lastPage", pageId)
  end

  if not suppressRefresh then
    self:Refresh()
  end
end

function ConfigWindow:IsPageDescendantOf(pageId, ancestorId)
  local page = AP.ConfigRegistry:GetPage(pageId)
  while page and page.parent do
    if page.parent == ancestorId then
      return true
    end
    page = AP.ConfigRegistry:GetPage(page.parent)
  end
  return false
end

function ConfigWindow:TogglePage(pageId)
  local willExpand = not self.expanded[pageId]
  self.expanded[pageId] = willExpand
  local selectedId = self.selectedPageId == SEARCH_PAGE_ID
    and self.lastExplicitPageId
    or self.selectedPageId
  if not willExpand and self:IsPageDescendantOf(selectedId, pageId) then
    self:SelectPage(pageId)
    return
  end
  self.treeDirty = true
  self:RefreshTree()
end

function ConfigWindow:SetSearch(query, suppressRefresh, skipBoxSync)
  query = AP.Utils.Trim(query)
  local previousQuery = self.searchQuery
  local previousPageId = self.selectedPageId
  self.searchQuery = query

  if self.frame and not skipBoxSync and self.frame.SearchBox:GetText() ~= query then
    self.suppressSearchChanged = true
    self.frame.SearchBox:SetText(query)
    self.suppressSearchChanged = false
  end

  if query ~= "" then
    self.selectedPageId = SEARCH_PAGE_ID
  else
    self.selectedPageId = self.lastExplicitPageId or AP.Database:Get("state.lastPage", "general")
  end

  self:RefreshSearchHint()

  if not suppressRefresh and (previousQuery ~= query or previousPageId ~= self.selectedPageId) then
    self:Refresh()
  end
end

function ConfigWindow:CancelPendingSearch()
  self.pendingSearchQuery = nil
  self.pendingSearchElapsed = 0
  if self.frame then
    self.frame:SetScript("OnUpdate", nil)
  end
end

function ConfigWindow:FlushPendingSearch()
  if self.pendingSearchQuery == nil then
    return
  end

  local query = self.pendingSearchQuery
  self:CancelPendingSearch()
  self:SetSearch(query, false, true)
end

function ConfigWindow:ResetWindowState()
  AP.Database:Set("interface.window", AP.Utils.DeepCopy(AP.defaults.interface.window))
  if self.frame then
    applyWindowState(self.frame)
    self:Refresh()
  end
end

function ConfigWindow:Initialize()
  if self.frame then
    return
  end

  local frame = CreateFrame("Frame", "WotLKPlusConfigFrame", UIParent)
  frame:SetFrameStrata("HIGH")
  frame:SetToplevel(true)
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:SetResizable(true)
  frame:SetClampedToScreen(true)
  frame:SetMinResize(LAYOUT.minWidth, LAYOUT.minHeight)
  if frame.SetMaxResize then
    frame:SetMaxResize(LAYOUT.maxWidth, LAYOUT.maxHeight)
  end
  Theme:ApplyBackdrop(frame, Theme.colors.background, Theme.colors.border)

  self.treeCallbacks = {
    onSelect = function(pageId)
      ConfigWindow:SelectPage(pageId)
    end,
    onToggle = function(pageId)
      ConfigWindow:TogglePage(pageId)
    end,
  }

  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(self)
    self:StartMoving()
  end)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    saveWindowState(self)
  end)

  if UISpecialFrames then
    table.insert(UISpecialFrames, "WotLKPlusConfigFrame")
  end

  frame.TitleBar = frame:CreateTexture(nil, "ARTWORK")
  frame.TitleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
  frame.TitleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
  frame.TitleBar:SetHeight(LAYOUT.topBarHeight)
  Theme:Paint(frame.TitleBar, Theme.colors.titlebar)

  frame.TitleLine = frame:CreateTexture(nil, "ARTWORK")
  frame.TitleLine:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -(LAYOUT.topBarHeight + 1))
  frame.TitleLine:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -(LAYOUT.topBarHeight + 1))
  frame.TitleLine:SetHeight(1)
  Theme:Paint(frame.TitleLine, Theme.colors.line)

  frame.BrandMark = CreateFrame("Frame", nil, frame)
  frame.BrandMark:SetWidth(32)
  frame.BrandMark:SetHeight(32)
  frame.BrandMark:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -10)
  Theme:ApplyBackdrop(frame.BrandMark, Theme.colors.inset, Theme.colors.border)

  frame.BrandMarkText = frame.BrandMark:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  frame.BrandMarkText:SetPoint("CENTER", frame.BrandMark, "CENTER", 0, 0)
  frame.BrandMarkText:SetText("AP")
  frame.BrandMarkText:SetTextColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3], 1)

  frame.Title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  frame.Title:SetPoint("TOPLEFT", frame.BrandMark, "TOPRIGHT", 10, -1)
  frame.Title:SetText(AP.prettyName or "WotLK Plus")
  frame.Title:SetTextColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], Theme.colors.text[4])
  Theme:TrySetTitleFont(frame.Title, 19)

  frame.Subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  frame.Subtitle:SetPoint("TOPLEFT", frame.Title, "BOTTOMLEFT", 1, -1)
  frame.Subtitle:SetText("CONTROL CENTER  |  v" .. tostring(AP.version or ""))
  frame.Subtitle:SetTextColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3], Theme.colors.muted[4])

  frame.CloseButton = CreateFrame("Button", nil, frame)
  frame.CloseButton:SetWidth(24)
  frame.CloseButton:SetHeight(24)
  frame.CloseButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -14)
  Theme:SkinCloseButton(frame.CloseButton, "x")
  frame.CloseButton:SetScript("OnClick", function()
    frame:Hide()
  end)

  frame.SearchShell = CreateFrame("Frame", nil, frame)
  Theme:ApplyBackdrop(frame.SearchShell, Theme.colors.inset, Theme.colors.border)
  frame.SearchShell:SetPoint("TOPRIGHT", frame.CloseButton, "TOPLEFT", -10, 2)
  frame.SearchShell:SetWidth(292)
  frame.SearchShell:SetHeight(28)

  frame.SearchLabel = frame.SearchShell:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  frame.SearchLabel:SetPoint("LEFT", frame.SearchShell, "LEFT", 8, 0)
  frame.SearchLabel:SetText("FIND")
  frame.SearchLabel:SetTextColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3], 0.85)

  frame.SearchBox = CreateFrame("EditBox", nil, frame.SearchShell)
  frame.SearchBox:SetAutoFocus(false)
  frame.SearchBox:SetFontObject(ChatFontNormal)
  frame.SearchBox:SetTextColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], Theme.colors.text[4])
  frame.SearchBox:SetPoint("TOPLEFT", frame.SearchShell, "TOPLEFT", 44, -2)
  frame.SearchBox:SetPoint("BOTTOMRIGHT", frame.SearchShell, "BOTTOMRIGHT", -28, 2)
  if frame.SearchBox.SetTextInsets then
    frame.SearchBox:SetTextInsets(0, 0, 0, 0)
  end
  local function processPendingSearch(_, elapsed)
    ConfigWindow.pendingSearchElapsed = ConfigWindow.pendingSearchElapsed + elapsed
    if ConfigWindow.pendingSearchElapsed >= SEARCH_DEBOUNCE_SECONDS then
      ConfigWindow:FlushPendingSearch()
    end
  end

  frame.SearchBox:SetScript("OnTextChanged", function(self)
    updateSearchHint(frame)
    if ConfigWindow.suppressSearchChanged then
      return
    end

    ConfigWindow.pendingSearchQuery = AP.Utils.Trim(self:GetText())
    ConfigWindow.pendingSearchElapsed = 0
    frame:SetScript("OnUpdate", processPendingSearch)
  end)
  frame.SearchBox:SetScript("OnEscapePressed", function(self)
    if self:GetText() ~= "" then
      self:SetText("")
      ConfigWindow:FlushPendingSearch()
    else
      self:ClearFocus()
    end
  end)
  frame.SearchBox:SetScript("OnEnterPressed", function(self)
    ConfigWindow:FlushPendingSearch()
    self:ClearFocus()
  end)
  frame.SearchBox:SetScript("OnEditFocusGained", function()
    updateSearchHint(frame)
  end)
  frame.SearchBox:SetScript("OnEditFocusLost", function()
    updateSearchHint(frame)
  end)
  Theme:SkinEditBox(frame.SearchBox, frame.SearchShell)

  frame.SearchClear = CreateFrame("Button", nil, frame.SearchShell)
  frame.SearchClear:SetWidth(20)
  frame.SearchClear:SetHeight(20)
  frame.SearchClear:SetPoint("RIGHT", frame.SearchShell, "RIGHT", -4, 0)
  Theme:SkinCloseButton(frame.SearchClear, "x")
  frame.SearchClear:SetScript("OnClick", function()
    frame.SearchBox:SetText("")
    ConfigWindow:FlushPendingSearch()
    frame.SearchBox:SetFocus()
  end)
  frame.SearchClear:Hide()

  frame.SearchHint = frame.SearchShell:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  frame.SearchHint:SetPoint("LEFT", frame.SearchBox, "LEFT", 4, 0)
  frame.SearchHint:SetText("Search settings and features")
  frame.SearchHint:SetTextColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3], 0.9)

  frame.Tree = AP.UI.Tree:Create(frame)
  frame.Tree:SetPoint("TOPLEFT", frame, "TOPLEFT", LAYOUT.outerInset, -(LAYOUT.topBarHeight + LAYOUT.outerInset))
  frame.Tree:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", LAYOUT.outerInset, LAYOUT.footerHeight + 10)
  frame.Tree:SetWidth(LAYOUT.navigationWidth)

  frame.NavFooter = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  frame.NavFooter:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", LAYOUT.outerInset + 4, 13)
  frame.NavFooter:SetText("/wp help  |  settings apply instantly")
  frame.NavFooter:SetTextColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3], 0.72)

  frame.ContentDivider = frame:CreateTexture(nil, "ARTWORK")
  frame.ContentDivider:SetPoint("TOPLEFT", frame.Tree, "TOPRIGHT", math.floor(LAYOUT.contentGutter / 2), 0)
  frame.ContentDivider:SetPoint("BOTTOMLEFT", frame.Tree, "BOTTOMRIGHT", math.floor(LAYOUT.contentGutter / 2), 0)
  frame.ContentDivider:SetWidth(1)
  Theme:Paint(frame.ContentDivider, Theme.colors.neutralLine or Theme.colors.line)

  frame.Pages = AP.UI.Pages:Create(frame)
  frame.Pages:SetPoint("TOPLEFT", frame.Tree, "TOPRIGHT", LAYOUT.contentGutter, 0)
  frame.Pages:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -LAYOUT.outerInset, LAYOUT.contentBottom)
  frame.Pages.onSelectPage = function(pageId)
    ConfigWindow:SelectPage(pageId)
  end
  frame.Pages.onChanged = function()
    ConfigWindow:RefreshContent()
  end

  frame.ResizeGrip = CreateFrame("Button", nil, frame)
  frame.ResizeGrip:SetWidth(16)
  frame.ResizeGrip:SetHeight(16)
  frame.ResizeGrip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
  Theme:SkinResizeGrip(frame.ResizeGrip)
  frame.ResizeGrip:SetScript("OnMouseDown", function()
    frame.ResizeGrip.APGripPressed = true
    Theme:RefreshResizeGrip(frame.ResizeGrip)
    frame:StartSizing("BOTTOMRIGHT")
  end)
  frame.ResizeGrip:SetScript("OnMouseUp", function()
    frame.ResizeGrip.APGripPressed = false
    Theme:RefreshResizeGrip(frame.ResizeGrip)
    frame:StopMovingOrSizing()
    saveWindowState(frame)
    ConfigWindow:RefreshContent()
  end)

  frame:SetScript("OnShow", function()
    updateSearchHint(frame)
    Theme:FadeIn(frame, 0.12)
  end)
  frame:SetScript("OnHide", function()
    ConfigWindow:CancelPendingSearch()
    if frame.Pages.CaptureOverlay:IsShown() then
      frame.Pages:CancelKeyCapture()
    end
  end)

  self.frame = frame
  self.searchQuery = ""

  if AP.Database:Get("interface.restoreLastPage", true) then
    local restoredPageId = AP.Database:Get("state.lastPage", "general")
    if not AP.ConfigRegistry:GetPage(restoredPageId) then
      local classId = tostring(restoredPageId):match("^classes%.([^%.]+)%.spec%.")
      local classPageId = classId and ("classes." .. classId) or nil
      if classPageId and AP.ConfigRegistry:GetPage(classPageId) then
        restoredPageId = classPageId
      else
        restoredPageId = "general"
      end
      AP.Database:Set("state.lastPage", restoredPageId)
    end
    self.lastExplicitPageId = restoredPageId
    self.selectedPageId = self.lastExplicitPageId
  end
  self:EnsurePageVisible(self.selectedPageId)

  applyWindowState(frame)
  updateSearchHint(frame)
  frame:Hide()
end

function ConfigWindow:Open(pageId, query)
  local started = profileNow()
  if not self.frame then
    self:Initialize()
  end

  self:CancelPendingSearch()

  applyWindowState(self.frame)

  if query and query ~= "" then
    self:SetSearch(query, true)
  elseif pageId then
    self:SetSearch("", true)
    self:SelectPage(pageId, true)
  else
    self:SetSearch("", true)
  end

  self.frame:Show()
  self:Refresh()
  self.lastOpenMs = profileElapsed(started)
end

function ConfigWindow:Toggle(pageId, query)
  if not self.frame then
    self:Initialize()
  end

  if self.frame:IsShown() then
    self.frame:Hide()
    return
  end

  self:Open(pageId, query)
end
