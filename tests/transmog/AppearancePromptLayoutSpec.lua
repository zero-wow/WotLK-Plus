local root = (... and ... ~= "" and ...) or "."

_G.AscensionPlus = {
  UI = {
    Theme = {
      colors = {},
    },
  },
  TransmogAppearanceRules = {},
}

dofile(root .. "/modules/transmog/AppearancePrompt.lua")

local layout = AscensionPlus.TransmogAppearancePrompt.LAYOUT
local usableWidth = layout.width - (layout.inset * 2)
local buttonWidth = layout.learnWidth
  + layout.autoWidth
  + layout.neverWidth
  + layout.laterWidth
  + (layout.buttonGap * 3)
local buttonTop = layout.height - layout.buttonBottom - layout.buttonHeight

assert(layout.width <= 600 and layout.height <= 380, "review queue must fit comfortably inside a 1024x768 UI")
assert(layout.summaryTop >= layout.titleBarHeight + layout.gutter, "summary needs a visible gutter below the title divider")
assert(layout.itemTop >= layout.summaryTop + 16, "item shell needs a visible gutter below the summary")
assert(layout.queueLabelTop >= layout.itemTop + layout.itemHeight + layout.gutter, "queue heading needs a visible gutter below the item shell")
assert(layout.queueTop >= layout.queueLabelTop + 16, "queue shell needs a visible gutter below its heading")
assert(layout.warningTop >= layout.queueTop + layout.queueHeight + layout.gutter, "warning text needs a visible gutter below the queue shell")
assert(buttonWidth <= usableWidth, "all four review buttons must fit without overlap")
assert(buttonTop >= layout.warningTop + 56, "warning and explanation text need reserved space above the buttons")
assert(layout.buttonBottom >= layout.gutter, "buttons need a visible gutter from the frame border")

io.write("PASS appearance review queue bounds preserve all gutters\n")
