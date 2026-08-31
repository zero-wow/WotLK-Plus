local root = (... and ... ~= "" and ...) or "."

_G.AscensionPlus = {
  UI = {
    Theme = {},
  },
}

dofile(root .. "/ui/ConfigWindow.lua")

local layout = AscensionPlus.ConfigWindow.Layout
assert(layout.minWidth == 840 and layout.minHeight == 500, "compact config minimum bounds must remain explicit")
assert(layout.defaultWidth == 960 and layout.defaultHeight == 590, "reset must use the compact shell dimensions")
assert(layout.outerInset >= 8 and layout.contentGutter >= 10, "panels need visible gutters away from borders and dividers")
assert(layout.navigationWidth >= 210, "task navigation needs room for deep labels and compact tree targets")

local contentWidth = layout.minWidth
  - (layout.outerInset * 2)
  - layout.navigationWidth
  - layout.contentGutter
assert(contentWidth >= 580, "minimum config width must leave a useful settings canvas")
assert(layout.topBarHeight >= 48, "brand, search, and close targets must fit inside the command bar")
assert(layout.footerHeight >= 18, "navigation footer text must stay clear of the panel border")
assert(layout.contentBottom >= layout.footerHeight + 8, "settings canvas must clear the resize grip and scrollbar button")

io.write("PASS config shell minimum bounds preserve navigation, gutters, and settings canvas\n")
