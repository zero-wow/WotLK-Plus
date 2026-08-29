local function assertEqual(actual, expected, label)
  if actual ~= expected then
    error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)), 2)
  end
end

local function frame(width)
  return {
    IsShown = function()
      return true
    end,
    GetWidth = function()
      return width or 20
    end,
    GetFrameLevel = function()
      return 5
    end,
  }
end

local inventoryHost = frame(400)
inventoryHost.sortButton = frame(18)
local bankHost = frame(500)
bankHost.sortButton = frame(18)
local keeperHost = frame(600)
local keeperSort = frame(21)

_G.ElvUI_ContainerFrame = inventoryHost
_G.ElvUI_BankContainerFrame = bankHost
_G.GuildBankFrame = keeperHost
_G.GuildBankFrameSortButton = keeperSort

function IsAddOnLoaded(addonName)
  return addonName == "ElvUI"
end

_G.AscensionPlus = {
  Database = {
    Get = function(_, _, fallback)
      return fallback
    end,
  },
  Banking = {
    SorterProviders = {
      keeper = { IsOpen = function() return true end },
      character = { IsOpen = function() return true end },
      inventory = { IsOpen = function() return true end },
    },
  },
}

dofile("modules/banking/sorter/Presentation.lua")
dofile("modules/banking/sorter/adapters/ElvUI.lua")

local presentation = _G.AscensionPlus.Banking.SorterPresentation
for _, contextID in ipairs({ "keeper", "character", "inventory" }) do
  local placement = assert(presentation:GetPlacement(contextID), contextID .. " placement")
  assertEqual(placement.point, "RIGHT", contextID .. " AP edge")
  assertEqual(placement.relativePoint, "LEFT", contextID .. " host edge")
  assertEqual(placement.x, -4, contextID .. " spacing")
end

assertEqual(presentation:GetPlacement("inventory").host, inventoryHost, "inventory host")
assertEqual(presentation:GetPlacement("character").host, bankHost, "character bank host")
assertEqual(presentation:GetPlacement("keeper").host, keeperHost, "keeper host")

io.write("PASS ElvUI sorter controls anchor immediately left in every supported context\n")

