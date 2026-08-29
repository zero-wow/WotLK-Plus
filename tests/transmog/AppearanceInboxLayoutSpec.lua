local root = (... and ... ~= "" and ...) or "."

_G.AscensionPlus = {
  UI = {
    Theme = {
      colors = {},
    },
  },
  TransmogAutoCollect = {},
  TransmogAppearanceCatalog = {},
}

dofile(root .. "/modules/transmog/AppearanceInbox.lua")

local layout = AscensionPlus.TransmogAppearanceInbox.LAYOUT
local usableWidth = layout.width - (layout.horizontalInset * 2)
local tabWidth = (78 * 3) + (6 * 2)
local toolbarWidth = 76 + 6 + 78
local listHeight = layout.height - layout.listTop - layout.listBottom

assert(layout.width <= 720 and layout.height <= 540, "window must fit comfortably inside a 1024x768 UI")
assert(tabWidth + toolbarWidth <= usableWidth, "tabs and toolbar must not overlap at minimum width")
assert(layout.summaryTop + layout.summaryHeight + layout.gutter <= layout.listTop, "summary needs a visible gutter above the list border")
assert(listHeight >= ((layout.rowHeight * 6) + (layout.rowGap * 5)), "list must expose six complete rows and their gutters")
assert(layout.listBottom >= layout.footerBottom + 20 + layout.gutter, "list needs a visible gutter above the footer")
assert(150 >= 72 + layout.gutter + 54 + layout.gutter, "row text needs a visible gutter before both action buttons")
assert(layout.horizontalInset >= layout.gutter, "outer controls need a visible gutter from the frame border")

io.write("PASS appearance inbox fixed bounds do not overlap or clip controls\n")
