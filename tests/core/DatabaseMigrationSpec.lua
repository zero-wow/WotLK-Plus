local root = (... and ... ~= "" and ...) or "."

_G.AscensionPlus = {}
_G.WotLKPlus = _G.AscensionPlus
_G.WotLKPlusDB = {
  interface = {
    searchHints = false,
  },
}
_G.AscensionPlusDB = {
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

local Database = _G.WotLKPlus.Database
Database:Initialize()

assert(Database:Get("general.showStartupMessage") == false, "legacy general settings must migrate")
assert(Database:Get("interface.restoreLastPage") == false, "missing nested settings must migrate")
assert(Database:Get("interface.searchHints") == false, "existing WotLK Plus settings must win")
assert(Database:Get("banking.sorter.enabled") == false, "legacy banking settings must migrate")
assert(_G.WotLKPlusDB == Database.db, "the new SavedVariables table must own the resolved database")

print("DatabaseMigrationSpec: OK")
