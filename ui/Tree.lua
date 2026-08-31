local _, AP = ...
AP = AP or _G.Levo or _G.WotLKPlus or _G.AscensionPlus

local Theme = AP.UI.Theme

local Tree = {}
AP.UI.Tree = Tree

local ROOT_ROW_HEIGHT = 23
local CHILD_ROW_HEIGHT = 20
local ROOT_GAP = 1
local INDENT_WIDTH = 10
local NAV_GUTTER = 6

local function updateScrollChildWidth(scrollFrame, child)
  local width = scrollFrame:GetWidth() or 0
  if width > 4 then
    child:SetWidth(width - 2)
  end
end

local function getClassColor(classToken)
  if not classToken then
    return nil
  end

  local color = CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[classToken]
  if not color then
    color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
  end
  return color
end

function Tree:Create(parent)
  local frame = CreateFrame("Frame", nil, parent)
  Theme:ApplyBackdrop(frame, Theme.colors.sidebar or Theme.colors.inset, Theme.colors.border)

  frame.Title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  frame.Title:SetPoint("TOPLEFT", frame, "TOPLEFT", NAV_GUTTER, -5)
  frame.Title:SetText("WORKSPACE")
  frame.Title:SetTextColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3], Theme.colors.gold[4])

  frame.Divider = frame:CreateTexture(nil, "ARTWORK")
  frame.Divider:SetPoint("TOPLEFT", frame, "TOPLEFT", NAV_GUTTER, -22)
  frame.Divider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -NAV_GUTTER, -22)
  frame.Divider:SetHeight(1)
  Theme:Paint(frame.Divider, Theme.colors.line)

  frame.Scroll = CreateFrame("ScrollFrame", "LevoTreeScroll", frame, "UIPanelScrollFrameTemplate")
  frame.Scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", NAV_GUTTER, -27)
  frame.Scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -19, NAV_GUTTER)
  Theme:SkinScrollFrame(frame.Scroll)
  frame.Scroll:EnableMouseWheel(true)
  frame.Scroll:SetScript("OnMouseWheel", function(self, delta)
    local range = self:GetVerticalScrollRange() or 0
    local nextValue = (self:GetVerticalScroll() or 0) - (delta * 18)
    nextValue = AP.Utils.Clamp(nextValue, 0, range)
    self:SetVerticalScroll(nextValue)
  end)

  frame.Child = CreateFrame("Frame", nil, frame.Scroll)
  frame.Child:SetWidth(162)
  frame.Child:SetHeight(1)
  frame.Scroll:SetScrollChild(frame.Child)

  function frame:SetScrollBarVisible(visible)
    visible = visible and true or false
    if self.scrollBarVisible == visible then
      return false
    end

    self.scrollBarVisible = visible
    local scrollBar = self.Scroll.APScrollBar
    local upButton = self.Scroll.APScrollUpButton
    local downButton = self.Scroll.APScrollDownButton
    if visible then
      if scrollBar then scrollBar:Show() end
      if upButton then upButton:Show() end
      if downButton then downButton:Show() end
    else
      if scrollBar then scrollBar:Hide() end
      if upButton then upButton:Hide() end
      if downButton then downButton:Hide() end
      self.Scroll:SetVerticalScroll(0)
    end

    self.Scroll:ClearAllPoints()
    self.Scroll:SetPoint("TOPLEFT", self, "TOPLEFT", NAV_GUTTER, -27)
    self.Scroll:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", visible and -19 or -NAV_GUTTER, NAV_GUTTER)
    updateScrollChildWidth(self.Scroll, self.Child)
    return true
  end

  function frame:RefreshScrollChrome()
    if self.refreshingScrollChrome then
      return false
    end
    self.refreshingScrollChrome = true
    local changed = self:SetScrollBarVisible((self.Scroll:GetVerticalScrollRange() or 0) > 0)
    self.refreshingScrollChrome = false
    return changed
  end

  frame.rows = {}
  frame.nodes = {}
  frame.rowsById = {}

  frame.Scroll:SetScript("OnSizeChanged", function(self)
    updateScrollChildWidth(self, frame.Child)
    if not frame.refreshingScrollChrome then
      frame:RefreshScrollChrome()
    end
  end)
  frame:SetScrollBarVisible(false)

  function frame:AcquireRow(index)
    local row = self.rows[index]
    if row then
      return row
    end

    row = CreateFrame("Button", nil, self.Child)
    row:SetHeight(CHILD_ROW_HEIGHT)

    row.Bg = row:CreateTexture(nil, "BACKGROUND")
    row.Bg:SetAllPoints(row)
    Theme:SkinListRow(row)
    row.APRowAccent:SetWidth(3)

    row.Toggle = CreateFrame("Button", nil, row)
    row.Toggle:SetWidth(18)
    row.Toggle:SetHeight(18)

    row.Toggle.Hover = row.Toggle:CreateTexture(nil, "HIGHLIGHT")
    row.Toggle.Hover:SetPoint("TOPLEFT", row.Toggle, "TOPLEFT", 2, -2)
    row.Toggle.Hover:SetPoint("BOTTOMRIGHT", row.Toggle, "BOTTOMRIGHT", -2, 2)
    Theme:Paint(row.Toggle.Hover, { Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3], 0.10 })

    row.Toggle.Glyph = row.Toggle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.Toggle.Glyph:SetPoint("CENTER", row.Toggle, "CENTER", 0, 0)
    row.Toggle.Glyph:SetTextColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3], 1)

    row.Label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.Label:SetJustifyH("LEFT")
    row.Label:SetPoint("RIGHT", row, "RIGHT", -4, 0)

    row.RootRule = row:CreateTexture(nil, "ARTWORK")
    row.RootRule:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 4, 0)
    row.RootRule:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -4, 0)
    row.RootRule:SetHeight(1)
    Theme:Paint(row.RootRule, { Theme.colors.border[1], Theme.colors.border[2], Theme.colors.border[3], 0.14 })
    row.RootRule:Hide()

    row.Toggle:SetScript("OnClick", function()
      if row.node and row.node.hasChildren and frame.onToggle then
        frame.onToggle(row.node.id)
      end
    end)
    row.Toggle:SetScript("OnEnter", function(self)
      self.Glyph:SetTextColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3], 1)
    end)
    row.Toggle:SetScript("OnLeave", function(self)
      self.Glyph:SetTextColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3], 1)
    end)

    row:SetScript("OnClick", function()
      if row.node and frame.onSelect then
        frame.onSelect(row.node.id)
      end
    end)

    self.rows[index] = row
    return row
  end

  function frame:SetTreeData(nodes, selectedId, callbacks)
    self.nodes = nodes or {}
    self.onSelect = callbacks and callbacks.onSelect or nil
    self.onToggle = callbacks and callbacks.onToggle or nil
    self.rowsById = {}

    updateScrollChildWidth(self.Scroll, self.Child)

    local y = -1
    for index = 1, #self.nodes do
      local node = self.nodes[index]
      local row = self:AcquireRow(index)
      local rowHeight = node.isRoot and ROOT_ROW_HEIGHT or CHILD_ROW_HEIGHT

      if node.isRoot and index > 1 then
        y = y - ROOT_GAP
      end

      row.node = node
      row.layoutTop = math.abs(y)
      row.layoutHeight = rowHeight
      self.rowsById[node.id] = row
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", self.Child, "TOPLEFT", 0, y)
      row:SetPoint("TOPRIGHT", self.Child, "TOPRIGHT", 0, y)
      row:SetHeight(rowHeight)
      row:Show()

      row.Toggle:ClearAllPoints()
      row.Toggle:SetPoint("LEFT", row, "LEFT", node.depth * INDENT_WIDTH, 0)

      if node.hasChildren then
        row.Toggle:Show()
        row.Toggle.Glyph:SetText(node.expanded and "v" or ">")
        row.Toggle.Glyph:SetTextColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3], 1)
      else
        row.Toggle:Hide()
      end

      row.Label:ClearAllPoints()
      if node.isRoot then
        row.Label:SetPoint("LEFT", row, "LEFT", 22, 0)
      elseif node.hasChildren then
        row.Label:SetPoint("LEFT", row.Toggle, "RIGHT", 1, 0)
      else
        row.Label:SetPoint("LEFT", row, "LEFT", 21 + (node.depth * INDENT_WIDTH), 0)
      end
      row.Label:SetPoint("RIGHT", row, "RIGHT", -4, 0)
      if row.Label.SetFontObject then
        row.Label:SetFontObject(node.isRoot and GameFontNormal or GameFontHighlightSmall)
      end
      row.Label:SetText(node.title or node.id)

      if row.Label.SetShadowColor and row.Label.SetShadowOffset then
        if node.treeShadow then
          row.Label:SetShadowColor(0, 0, 0, 1)
          row.Label:SetShadowOffset(1, -1)
        else
          row.Label:SetShadowColor(0, 0, 0, 0)
          row.Label:SetShadowOffset(0, 0)
        end
      end

      local classColor = getClassColor(node.classToken)
      local selected = node.id == selectedId

      Theme:SetListRowState(row, selected, node.matched)
      if node.isRoot then
        row.RootRule:Show()
        if not selected and not node.matched then
          Theme:Paint(row.APRowBackground, {
            Theme.colors.panel[1],
            Theme.colors.panel[2],
            Theme.colors.panel[3],
            0.46
          })
        end
      else
        row.RootRule:Hide()
      end

      if node.isRoot then
        row.Label:SetTextColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3], selected and 1 or 0.88)
      elseif classColor then
        row.Label:SetTextColor(
          classColor.r or classColor[1] or Theme.colors.text[1],
          classColor.g or classColor[2] or Theme.colors.text[2],
          classColor.b or classColor[3] or Theme.colors.text[3],
          1
        )
      elseif selected then
        row.Label:SetTextColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3], 1)
      else
        row.Label:SetTextColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], 1)
      end

      y = y - rowHeight
    end

    for index = #self.nodes + 1, #self.rows do
      self.rows[index]:Hide()
    end

    self.Child:SetHeight(math.max(1, math.abs(y) + 1))
    self:RefreshScrollChrome()
    self:ScrollToNode(selectedId)
  end

  function frame:ScrollToNode(pageId)
    local row = pageId and self.rowsById[pageId]
    if not row or not row:IsShown() then
      return false
    end

    local viewportHeight = self.Scroll:GetHeight() or 0
    if viewportHeight <= 0 then
      return false
    end

    local rowTop = row.layoutTop or 0
    local rowBottom = rowTop + (row.layoutHeight or CHILD_ROW_HEIGHT)
    local current = self.Scroll:GetVerticalScroll() or 0
    local nextValue = current

    if rowTop < current then
      nextValue = rowTop
    elseif rowBottom > current + viewportHeight then
      nextValue = rowBottom - viewportHeight
    end

    if nextValue ~= current then
      local range = math.max(0, (self.Child:GetHeight() or 0) - viewportHeight)
      self.Scroll:SetVerticalScroll(AP.Utils.Clamp(nextValue, 0, range))
    end
    return true
  end

  return frame
end
