local root = (... and ... ~= "" and ...) or "."

local Methods = {}
local function newWidget(kind, name)
  local widget = {
    kind = kind,
    name = name,
    width = kind == "Frame" and 400 or 100,
    height = kind == "Frame" and 200 or 20,
    shown = true,
    enabled = true,
    scripts = {},
    attributes = {},
    point = { "CENTER", nil, "CENTER", 0, 0 },
    text = "",
  }
  return setmetatable(widget, { __index = Methods })
end

function Methods:CreateTexture() return newWidget("Texture") end
function Methods:CreateFontString() return newWidget("FontString") end
function Methods:SetWidth(value) self.width = value end
function Methods:SetHeight(value) self.height = value end
function Methods:SetSize(width, height) self.width, self.height = width, height end
function Methods:GetWidth() return self.width end
function Methods:GetHeight() return self.height end
function Methods:SetPoint(...) self.point = { ... } end
function Methods:GetPoint() return unpack(self.point) end
function Methods:ClearAllPoints() self.point = { "CENTER", nil, "CENTER", 0, 0 } end
function Methods:SetAllPoints() end
function Methods:SetScript(name, callback) self.scripts[name] = callback end
function Methods:HookScript(name, callback) self.scripts["hook:" .. name] = callback end
function Methods:Show()
  self.shown = true
  if self.scripts.OnShow then self.scripts.OnShow(self) end
end
function Methods:Hide()
  self.shown = false
  if self.scripts.OnHide then self.scripts.OnHide(self) end
end
function Methods:IsShown() return self.shown end
function Methods:IsVisible() return self.shown end
function Methods:Enable() self.enabled = true end
function Methods:Disable() self.enabled = false end
function Methods:IsEnabled() return self.enabled end
function Methods:SetText(value) self.text = tostring(value or "") end
function Methods:GetText() return self.text end
function Methods:GetStringHeight()
  local _, lines = self.text:gsub("\n", "\n")
  return (lines + 1) * 12
end
function Methods:SetAttribute(key, value) self.attributes[key] = value end
function Methods:GetAttribute(key) return self.attributes[key] end
function Methods:GetFrameLevel() return 1 end
function Methods:GetName() return self.name end
function Methods:SetVerticalScroll(value) self.scroll = value end
function Methods:GetVerticalScroll() return self.scroll or 0 end
function Methods:GetVerticalScrollRange() return 500 end
function Methods:SetScrollChild(child) self.scrollChild = child end
function Methods:SetResizable(value) self.resizable = value end
function Methods:StopMovingOrSizing() end
function Methods:StartMoving() end
function Methods:StartSizing() end
function Methods:RegisterForDrag() end
function Methods:RegisterForClicks() end
function Methods:EnableMouse() end
function Methods:EnableMouseWheel() end
function Methods:SetMovable() end
function Methods:SetClampedToScreen() end
function Methods:SetMinResize() end
function Methods:SetMaxResize() end
function Methods:SetFrameStrata() end
function Methods:SetFrameLevel() end
function Methods:SetToplevel() end
function Methods:SetJustifyH() end
function Methods:SetJustifyV() end
function Methods:SetTextColor() end
function Methods:SetShadowColor() end
function Methods:SetShadowOffset() end
function Methods:SetTexture(value) self.texture = value end
function Methods:SetVertexColor() end
function Methods:SetBackdrop() end
function Methods:SetBackdropColor() end
function Methods:SetBackdropBorderColor() end
function Methods:SetAlpha() end

function CreateFrame(_, name)
  return newWidget("Frame", name)
end

UIParent = newWidget("Frame", "UIParent")
UIParent.width, UIParent.height = 1920, 1080
MerchantFrame = newWidget("Frame", "MerchantFrame")
MerchantFrame:Hide()
UISpecialFrames = {}
GameTooltip = newWidget("GameTooltip")
function GameTooltip:SetOwner() end
function GameTooltip:SetHyperlink() end
function GameTooltip:SetBagItem() end
function GameTooltip:AddLine() end
UIErrorsFrame = { AddMessage = function() end }
StaticPopupDialogs = {}
YES = "Yes"
CANCEL = "Cancel"
local shownPopup
function StaticPopup_Show(which, _, _, data)
  shownPopup = { which = which, data = data }
  return shownPopup
end
function StaticPopup_Hide(which)
  if shownPopup and shownPopup.which == which then
    shownPopup = nil
  end
end

local combat = false
function InCombatLockdown() return combat end
function GetTime() return 100 end

local values = {
  ["modules.skillCards"] = true,
  ["skillCards.rarityBorders"] = true,
  ["skillCards.showTooltips"] = true,
  ["skillCards.window"] = {
    point = "CENTER",
    relPoint = "CENTER",
    x = 0,
    y = 20,
    width = 520,
    height = 470,
  },
}

local snapshot = {
  scanReady = true,
  ownershipReady = true,
  counts = { normal = 5, lucky = 2, golden = 1, goldenLucky = 0 },
  totalCount = 8,
  unknown = {
    total = { copies = 3, uniqueIDs = 2 },
  },
  cards = {
    { bag = 0, slot = 1, itemID = 1001, name = "Skill Card A", texture = "a", quality = 2, count = 2, kind = "normal", group = "standard", ownershipKnown = true, unknown = true },
    { bag = 0, slot = 2, itemID = 1002, name = "Golden Skill Card B", texture = "b", quality = 4, count = 1, kind = "golden", group = "golden", ownershipKnown = true, unknown = true },
    { bag = 1, slot = 1, itemID = 1003, name = "Known Skill Card", texture = "c", quality = 3, count = 5, kind = "normal", group = "standard", ownershipKnown = true, owned = true, unknown = false },
  },
}

local vendorOpen = false
local scanCalls = 0
local exchangeCalls = 0
local mockUnknownCopies = 0
local mockProtectionEnabled = true
local usedBag
local usedSlot
function UseContainerItem(bag, slot)
  usedBag, usedSlot = bag, slot
end
local Catalog = {
  GetSnapshot = function() return snapshot end,
  Scan = function()
    scanCalls = scanCalls + 1
    return snapshot
  end,
  IsExchangeOpen = function() return vendorOpen end,
  GetExchangeState = function(_, kind)
    return {
      kind = kind,
      label = kind,
      group = kind == "golden" and "golden" or "standard",
      count = snapshot.counts[kind] or 0,
      required = 5,
      unknownCopies = mockUnknownCopies,
      protectionEnabled = mockProtectionEnabled,
      ready = vendorOpen and (snapshot.counts[kind] or 0) >= 5,
      code = vendorOpen and "not-enough" or "vendor-closed",
      reason = "Mock exchange state",
    }
  end,
  Exchange = function()
    exchangeCalls = exchangeCalls + 1
    return true
  end,
}

local colors = {
  background = { 0, 0, 0, 1 }, panel = { 0, 0, 0, 1 }, surface = { 0, 0, 0, 1 },
  sidebar = { 0, 0, 0, 1 }, inset = { 0, 0, 0, 1 }, titlebar = { 0, 0, 0, 1 },
  border = { 1, 1, 1, 1 }, neutralLine = { 1, 1, 1, 1 }, line = { 1, 1, 1, 1 },
  text = { 1, 1, 1, 1 }, muted = { 0.5, 0.5, 0.5, 1 }, gold = { 1, 0.8, 0.2, 1 },
  green = { 0.2, 1, 0.2, 1 }, orange = { 1, 0.5, 0.1, 1 }, red = { 1, 0.2, 0.2, 1 },
}

local Theme = {
  colors = colors,
  ApplyBackdrop = function() end,
  Paint = function() end,
  TrySetTitleFont = function() end,
  SkinButton = function() end,
  RefreshButton = function() end,
  SkinCloseButton = function() end,
  SkinResizeGrip = function() end,
  RefreshResizeGrip = function() end,
  SkinScrollFrame = function() end,
  FadeIn = function() end,
  GetQualityColor = function() return 0.2, 1, 0.2 end,
}

_G.AscensionPlus = {
  UI = { Theme = Theme },
  SkillCards = { Catalog = Catalog },
  Database = {
    Get = function(_, path, fallback)
      local value = values[path]
      return value == nil and fallback or value
    end,
    Set = function(_, path, value) values[path] = value end,
  },
  Utils = {
    Clamp = function(value, minimum, maximum) return math.max(minimum, math.min(maximum, value)) end,
    DeepCopy = function(value) return value end,
  },
  defaults = { skillCards = { window = values["skillCards.window"] } },
  Print = function() end,
}

dofile(root .. "/modules/skillcards/SkillCardWindow.lua")
local Window = AscensionPlus.SkillCards.Window

assert(Window:Open("expanded"), "enabled Ledger should open")
assert(Window.frame:IsShown() and Window.mode == "expanded", "expanded mode should be visible")
assert(#Window.cardButtons >= 2, "unlearned view should build card action buttons")
Window.cardButtons[1].scripts.OnClick(Window.cardButtons[1])
assert(usedBag == 0 and usedSlot == 1, "card clicks should fresh-scan and use the current matching unlearned slot")
assert(Window.cardButtons[1]:GetAttribute("type") == nil, "card actions must not retain stale secure bag-slot attributes")
usedBag, usedSlot = nil, nil
MerchantFrame:Show()
Window.cardButtons[1].scripts.OnClick(Window.cardButtons[1])
assert(usedBag == nil and usedSlot == nil, "an open merchant must never turn a learn action into an item sale")
MerchantFrame:Hide()

Window:Open("compact")
assert(Window.mode == "compact" and not Window.frame.CardShell:IsShown(), "compact mode should hide the interactive grid")

vendorOpen = true
Window:Open("expanded")
assert(Window.frame.ExchangeDesk:IsShown(), "vendor state should reveal the Exchange Desk")

combat = true
Window:OnCombatStarted()
assert(Window.frame.CombatOverlay:IsShown(), "combat start should cover stale card actions")
Window:Refresh(false)
assert(Window.pendingInventoryRefresh, "combat refresh should defer inventory-button mutation")
Window:SetMode("compact")
Window:SetMode("expanded")
assert(Window.pendingMode == nil, "the latest mode request should cancel an older opposite combat request")
Window:RequestHide(true)
Window:Open("expanded")
assert(Window.pendingVisibility == nil, "reopening a visible Ledger should cancel a queued combat hide")
Window:Open("compact")
assert(Window.mode == "expanded" and Window.pendingMode == "compact", "combat should defer a protected mode change")
Window:Toggle()
assert(Window.frame:IsShown() and Window.pendingVisibility == "hide", "combat should defer hiding the Ledger")
combat = false
Window:OnCombatEnded()
assert(not Window.pendingInventoryRefresh and not Window.frame:IsShown(), "combat exit should apply deferred inventory work and hiding")
assert(not Window.frame.CombatOverlay:IsShown(), "combat overlay should clear after deferred work completes")

combat = true
Window:Open("expanded")
assert(not Window.frame:IsShown() and Window.pendingVisibility == "show", "combat should defer showing the Ledger")
Window:RequestHide(true)
assert(Window.pendingVisibility == nil, "hiding a still-hidden Ledger should cancel its queued combat open")
Window:Open("expanded")
combat = false
Window:OnCombatEnded()
assert(Window.frame:IsShown() and Window.mode == "expanded", "combat exit should apply a deferred open and mode")

Window.view = "all"
Window:Refresh(false)
usedBag, usedSlot = nil, nil
Window.cardButtons[3].scripts.OnClick(Window.cardButtons[3])
assert(usedBag == nil and usedSlot == nil, "owned cards in All Carried must never become use actions")

snapshot.scanReady = false
snapshot.scanError = "mock partial scan"
Window:Refresh(false)
assert(Window.frame.StatusBadge:GetText() == "SCAN BLOCKED", "failed scans must never present a healthy Ledger state")
assert(not Window.cardButtons[1]:IsShown(), "failed scans must clear every stale card action")
snapshot.scanReady = true
snapshot.scanError = nil

Window.view = "unknown"
Window:Refresh(false)
vendorOpen = true
mockUnknownCopies = 2
mockProtectionEnabled = false
local scansBeforeExchange = scanCalls
assert(Window:RequestExchange("normal"), "an at-risk ready exchange should open AP's scoped confirmation")
assert(scanCalls == scansBeforeExchange + 1, "exchange risk must be decided from a fresh inventory scan")
assert(shownPopup and shownPopup.which == "ASCENSIONPLUS_SKILLCARD_RISK" and exchangeCalls == 0,
  "at-risk exchange must wait for the scoped AP confirmation")
local stalePopupData = shownPopup.data
mockUnknownCopies = 3
StaticPopupDialogs.ASCENSIONPLUS_SKILLCARD_RISK.OnAccept({ data = stalePopupData })
assert(exchangeCalls == 0, "a changed risk count must invalidate the earlier confirmation")
mockUnknownCopies = 2
Window:RequestExchange("normal")
StaticPopupDialogs.ASCENSIONPLUS_SKILLCARD_RISK.OnAccept({ data = shownPopup.data })
assert(exchangeCalls == 1, "accepting AP's risk warning should request only the native vendor action")

combat = true
assert(not Window:RequestExchange("normal") and exchangeCalls == 1,
  "combat must block direct exchange requests even after a session confirmation")
combat = false

io.write("PASS Skill Card Ledger initializes, switches modes, reveals vendor actions, and defers combat mutations\n")
