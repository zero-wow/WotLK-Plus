local root = (... and ... ~= "" and ...) or "."

_G.AscensionPlus = {}
_G.Levo = _G.AscensionPlus
_G.LevoDB = {
  interface = {
    window = {
      point = "CENTER",
      relPoint = "CENTER",
      x = 36,
      y = -18,
      width = 1180,
      height = 720,
    },
  },
}

dofile(root .. "/core/Utils.lua")
dofile(root .. "/core/Database.lua")

local Database = _G.Levo.Database
Database:Initialize()

assert(Database:Get("interface.window.width") == 1180 and Database:Get("interface.window.height") == 720,
  "a manually resized config panel must not be replaced by the compact default")
assert(Database:Get("interface.window.x") == 36 and Database:Get("interface.window.y") == -18,
  "a manually positioned config panel must retain its anchor")

print("DatabaseCustomWindowSpec: OK")
