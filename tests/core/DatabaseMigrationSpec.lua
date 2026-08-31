local root = (... and ... ~= "" and ...) or "."

_G.AscensionPlus = {}
_G.Levo = _G.AscensionPlus
_G.LevoDB = {
  interface = {
    searchHints = false,
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
assert(Database:Get("banking.sorter.enabled") == false, "legacy banking settings must migrate")
assert(_G.LevoDB == Database.db, "the new SavedVariables table must own the resolved database")
assert(_G.WotLKPlusDB == nil and _G.AscensionPlusDB == nil, "legacy SavedVariables globals must be released after migration")

print("DatabaseMigrationSpec: OK")
