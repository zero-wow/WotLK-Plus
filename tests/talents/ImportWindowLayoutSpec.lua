local root = (... and ... ~= "" and ...) or "."

_G.Levo = {
  TalentImport = {},
  UI = {
    Theme = {
      colors = {},
    },
  },
}

dofile(root .. "/modules/talents/ImportWindow.lua")

local layout = _G.Levo.TalentImport.ImportWindow.Layout
local usableWidth = layout.width - (layout.inset * 2)
local actionWidth = layout.analyzeWidth
  + layout.applyWidth
  + layout.saveWidth
  + layout.clearWidth
  + (layout.actionGap * 2)

assert(layout.collapsedHeight < layout.expandedHeight, "the importer must expand only when a report is visible")
assert(layout.collapsedHeight <= 280, "the initial importer must remain compact")
assert(layout.expandedHeight <= 460, "the expanded importer must fit comfortably on a 768px UI")
assert(actionWidth <= usableWidth, "the compact action row must retain visible gutters without overlap")
assert(layout.actionBottom >= 12, "action buttons must remain clear of the window border")

print("ImportWindowLayoutSpec: OK")
