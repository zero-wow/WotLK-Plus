local root = (... and ... ~= "" and ...) or "."

_G.AscensionPlus = {}
_G.Levo = _G.AscensionPlus
_G.LevoDB = {
  interface = {
    windowLayoutVersion = 1,
    window = {
      point = "CENTER",
      relPoint = "CENTER",
      x = 0,
      y = 0,
      width = 960,
      height = 590,
    },
  },
}

dofile(root .. "/core/Utils.lua")
dofile(root .. "/core/Database.lua")

local Database = _G.Levo.Database
Database:Initialize()

assert(Database:Get("interface.window.width") == 760 and Database:Get("interface.window.height") == 470,
  "the former compact default must migrate to the smaller configuration panel")
assert(Database:Get("interface.windowLayoutVersion") == 2, "the window-density migration must advance once")

print("DatabaseCompactWindowSpec: OK")
