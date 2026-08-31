local root = (... and ... ~= "" and ...) or "."

_G.AscensionPlus = {}
_G.Levo = _G.AscensionPlus
_G.LevoDB = {
  interface = {
    searchHints = false,
    window = {
      point = "CENTER",
      relPoint = "CENTER",
      x = 0,
      y = 0,
      width = 1040,
      height = 660,
    },
  },
}
_G.WotLKPlusDB = {
  general = {
    showStartupMessage = false,
  },
  interface = {
    searchHints = true,
    restoreLastPage = false,
  },
  banking = {
    sorter = {
      enabled = false,
    },
  },
}

dofile(root .. "/core/Utils.lua")
dofile(root .. "/core/Database.lua")

local Database = _G.Levo.Database
Database:Initialize()

assert(Database:Get("general.showStartupMessage") == false, "legacy general settings must migrate")
assert(Database:Get("interface.restoreLastPage") == false, "missing nested settings must migrate")
assert(Database:Get("interface.searchHints") == false, "existing Levo settings must win")
assert(Database:Get("interface.window.width") == 960 and Database:Get("interface.window.height") == 590,
  "the former stock window dimensions must adopt the compact layout")
assert(Database:Get("interface.windowLayoutVersion") == 1, "the compact-window migration must only run once")
assert(Database:Get("banking.sorter.enabled") == false, "legacy banking settings must migrate")
assert(_G.LevoDB == Database.db, "the new SavedVariables table must own the resolved database")
assert(_G.WotLKPlusDB == nil and _G.AscensionPlusDB == nil, "legacy SavedVariables globals must be released after migration")

print("DatabaseMigrationSpec: OK")
