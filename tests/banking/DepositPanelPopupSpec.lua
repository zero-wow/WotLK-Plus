local function makeFrame(left, right, bottom, top)
  return {
    GetLeft = function() return left end,
    GetRight = function() return right end,
    GetBottom = function() return bottom end,
    GetTop = function() return top end,
  }
end

UIParent = makeFrame(0, 1920, 0, 1080)
_G.AscensionPlus = {
  Banking = {
    Categories = {
      order = { "all", "boe", "materials", "reagents", "gear", "recipe", "other" },
      definitions = {},
    },
    providers = {},
  },
  UI = {
    Theme = {},
  },
}

dofile("modules/banking/DepositPanel.lua")

local Panel = _G.AscensionPlus.Banking.Panel
assert(Panel:GetPopupPlacement(makeFrame(1000, 1400, 300, 900)) == "right", "the panel should prefer clear space to the popup's right")
assert(Panel:GetPopupPlacement(makeFrame(1700, 1900, 300, 900)) == "left", "the panel should move left when the popup is near the right screen edge")
assert(Panel:GetPopupPlacement(makeFrame(100, 1800, 400, 900)) == "below", "the panel should move below when neither horizontal side has room")

local anchored = {}
local frame = {
  SetPoint = function(_, ...)
    anchored = { ... }
  end,
}
local popup = makeFrame(1000, 1400, 300, 900)
Panel:AnchorToPopup(frame, popup)
assert(anchored[1] == "TOPLEFT" and anchored[2] == popup and anchored[3] == "TOPRIGHT", "popup anchoring must use the selected clear side")
assert(anchored[4] == Panel.LAYOUT.popupGutter, "popup anchoring must preserve the explicit visible gutter")

io.write("PASS transfer panel avoids GuildBankPopupFrame with a visible gutter\n")
