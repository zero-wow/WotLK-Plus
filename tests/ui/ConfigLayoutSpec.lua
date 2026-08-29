local root = (... and ... ~= "" and ...) or "."

_G.AscensionPlus = {
  UI = {
    Theme = {},
  },
}

dofile(root .. "/ui/ConfigWindow.lua")

local layout = AscensionPlus.ConfigWindow.Layout
assert(layout.minWidth == 900 and layout.minHeight == 560, "config minimum bounds must remain explicit")
assert(layout.outerInset >= 12 and layout.contentGutter >= 12, "panels need visible gutters away from borders and dividers")
assert(layout.navigationWidth >= 220, "task navigation needs room for deep labels and 24px targets")

local contentWidth = layout.minWidth
  - (layout.outerInset * 2)
  - layout.navigationWidth
  - layout.contentGutter
assert(contentWidth >= 620, "minimum config width must leave a useful settings canvas")
assert(layout.topBarHeight >= 44, "brand, search, and close targets must fit inside the command bar")
assert(layout.footerHeight >= 22, "navigation footer text must stay clear of the panel border")
assert(layout.contentBottom >= layout.footerHeight + 10, "settings canvas must clear the resize grip and scrollbar button")

io.write("PASS config shell minimum bounds preserve navigation, gutters, and settings canvas\n")
