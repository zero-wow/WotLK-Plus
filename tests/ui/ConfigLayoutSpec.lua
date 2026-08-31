local root = (... and ... ~= "" and ...) or "."

_G.AscensionPlus = {
  UI = {
    Theme = {},
  },
}

dofile(root .. "/ui/ConfigWindow.lua")

local layout = AscensionPlus.ConfigWindow.Layout
assert(layout.minWidth == 680 and layout.minHeight == 400, "compact config minimum bounds must remain explicit")
assert(layout.defaultWidth == 760 and layout.defaultHeight == 470, "reset must use the compact shell dimensions")
assert(layout.outerInset >= 6 and layout.contentGutter >= 8, "panels need visible gutters away from borders and dividers")
assert(layout.navigationWidth >= 170, "task navigation needs room for deep labels and compact tree targets")

local contentWidth = layout.minWidth
  - (layout.outerInset * 2)
  - layout.navigationWidth
  - layout.contentGutter
assert(contentWidth >= 480, "minimum config width must leave a useful settings canvas")
assert(layout.topBarHeight >= 40, "brand, search, and close targets must fit inside the command bar")
assert(layout.footerHeight >= 18, "navigation footer text must stay clear of the panel border")
assert(layout.contentBottom >= layout.footerHeight + 6, "settings canvas must clear the resize grip and scrollbar button")

io.write("PASS config shell minimum bounds preserve navigation, gutters, and settings canvas\n")
