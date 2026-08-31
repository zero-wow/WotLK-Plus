local root = (... and ... ~= "" and ...) or "."

local function texture(path)
  return {
    GetTexture = function()
      return path
    end,
    GetTexCoord = function()
      return 0.1, 0.9, 0.2, 0.8
    end,
  }
end

local function button(name, label, shown)
  local liveIcon = texture("Interface\\Icons\\INV_Misc_QuestionMark")
  local frame = {
    tooltipText = label,
    IsObjectType = function(_, kind)
      return kind == "Button"
    end,
    IsShown = function()
      return shown
    end,
    IsProtected = function()
      return false
    end,
    GetName = function()
      return name
    end,
    GetNormalTexture = function()
      return texture("Interface\\Icons\\INV_Misc_Bag_07")
    end,
  }
  frame.icon = liveIcon
  return frame
end

local hidden = button("LibDBIcon10_AtlasLoot", "AtlasLoot", false)
local valid = button("LibDBIcon10_Questie", "Questie", true)
local fallbackName = button("MinimapButtonAuctionator", nil, true)
local protected = button("LibDBIcon10_Protected", "Protected", true)
protected.IsProtected = function()
  return true
end
local standard = button("MinimapZoomIn", "Zoom", true)

_G.AscensionPlus = {}
_G.Levo = _G.AscensionPlus
_G.Minimap = {
  GetChildren = function()
    return fallbackName, standard, valid, protected, hidden
  end,
}

dofile(root .. "/modules/minimap/MinimapDiscovery.lua")

local Discovery = _G.Levo.MinimapPaletteDiscovery
local entries = Discovery:GetEntries()
assert(#entries == 2, "only shown, unprotected, non-standard launcher buttons should be included")
assert(entries[1].label == "Auctionator" and entries[2].label == "Questie", "entries must use stable alphabetical labels")
assert(entries[2].texture == "Interface\\Icons\\INV_Misc_QuestionMark", "the live icon region must win over decorative normal textures")
assert(math.abs(entries[2].coords[1] - 0.132) < 0.0001 and math.abs(entries[2].coords[4] - 0.776) < 0.0001, "live icon coordinates must be slightly inset")

entries = Discovery:GetEntries({ [hidden] = true })
assert(#entries == 3 and entries[1].label == "AtlasLoot", "buttons hidden by the palette must stay discoverable")

print("MinimapDiscoverySpec: OK")
