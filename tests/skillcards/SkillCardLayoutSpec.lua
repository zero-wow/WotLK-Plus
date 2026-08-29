local root = (... and ... ~= "" and ...) or "."

_G.AscensionPlus = {
  UI = {
    Theme = {},
  },
  SkillCards = {
    Catalog = {},
  },
}

dofile(root .. "/modules/skillcards/SkillCardWindow.lua")

local Window = AscensionPlus.SkillCards.Window
local layout = Window.Layout

assert(layout.minWidth == 480 and layout.minHeight == 420, "the supported expanded minimum must remain explicit")
assert(layout.cardSize >= 40, "card actions need a readable item-art and click target")

local normal = Window:GetLayoutMetrics(layout.minWidth, layout.minHeight, false, "expanded")
assert(normal.innerWidth == 456, "minimum width must preserve twelve-pixel gutters")
assert(normal.gridHeight >= 200, "the ordinary ledger must reserve a useful card field")
assert(not normal.exchangeVisible, "exchange controls must not exist away from the vendor")

local vendor = Window:GetLayoutMetrics(layout.minWidth, layout.minHeight, true, "expanded")
assert(vendor.exchangeVisible, "the exchange desk should reveal only at the vendor")
assert(vendor.gridHeight >= 120, "revealing the exchange desk must leave at least two readable card rows")
assert(vendor.gridBottom >= vendor.exchangeBottom + layout.exchangeHeight, "grid and exchange desk bounds must not overlap")

local compact = Window:GetLayoutMetrics(layout.compactWidth, layout.compactHeight, true, "compact")
assert(compact.gridHeight == 0 and not compact.exchangeVisible, "compact mode must remain a passive inventory strip")
assert(compact.summaryTop + compact.summaryHeight < layout.compactHeight, "compact summary must remain inside the frame")

io.write("PASS Skill Card Ledger bounds preserve card, exchange, footer, and compact states\n")

