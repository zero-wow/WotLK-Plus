local root = (... and ... ~= "" and ...) or "."

local openedQuery
local printed = {}
_G.SlashCmdList = {}
_G.Levo = {
  initialized = true,
  Print = function(_, message) printed[#printed + 1] = message end,
  OpenConfig = function(_, _, query)
    openedQuery = query
    return true
  end,
}
_G.WotLKPlus = _G.Levo
_G.AscensionPlus = _G.Levo

dofile(root .. "/modules/slash/Commands.lua")

assert(_G.SLASH_LEVO1 == "/lv" and _G.SLASH_LEVO2 == "/lev",
  "short commands must retain the help handler")
assert(_G.SLASH_LEVOCONFIG1 == "/levo" and _G.SLASH_LEVOCONFIG2 == "/lvc",
  "full-name and compact config commands must share the config handler")

SlashCmdList.LEVOCONFIG("")
assert(openedQuery == nil, "an empty /levo must open the default config page")

SlashCmdList.LEVO("")
assert(#printed > 0, "an empty /lv must show help")

print("SlashCommandsSpec: OK")
