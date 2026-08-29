local AP = _G.WotLKPlus or _G.AscensionPlus
if type(AP) ~= "table" then
  return
end

local function trim(text)
  return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function showHelp()
  AP:Print("|cffe7c56d" .. tostring(AP.prettyName or "WotLK Plus") .. " commands|r")
  AP:Print("|cff93c2ff/wp|r or |cff93c2ff/wp help|r - show this help")
  AP:Print("|cff93c2ff/wp config|r or |cff93c2ff/wpc|r - open configuration")
  AP:Print("|cff93c2ff/wp search <text>|r - open configuration search")
  AP:Print("|cff93c2ff/wp sort [inventory|bank|keeper|status|cancel|config]|r - control safe sorting")
  if AP.Modules and AP.Modules:Get("transmog") then
    AP:Print("|cff93c2ff/wp transmog [needs|all|api|collect|config]|r - open the Appearance Inbox")
  end
  if AP.Modules and AP.Modules:Get("skillCards") then
    AP:Print("|cff93c2ff/wp cards [refresh|config]|r - open the Skill Card Ledger")
  end
  AP:Print("|cff93c2ff/wp minimap|r - show or hide the minimap button")
  AP:Print("|cff93c2ff/wp status|r - show loader diagnostics")
  AP:Print("|cff93c2ff/ap|r and |cff93c2ff/apc|r remain legacy aliases.")
end

function AP:ShowHelp()
  showHelp()
end

local function showStatus()
  local state = AP.loadState or {}
  local function yesNo(value)
    return value and "|cff66dd88yes|r" or "|cffff6666no|r"
  end

  AP:Print("Loader status:")
  AP:Print("Main loaded: " .. yesNo(state.mainLoaded))
  AP:Print("ADDON_LOADED received: " .. yesNo(state.addonLoaded))
  AP:Print("PLAYER_LOGIN received: " .. yesNo(state.playerLogin))
  AP:Print("Slash commands registered: " .. yesNo(AP.slashRegistered))
  AP:Print("Initialized: " .. yesNo(AP.initialized or state.initialized))
  AP:Print("LDB launcher ready: " .. yesNo(AP.Launcher and AP.Launcher:IsReady()))
  local configWindow = AP.ConfigWindow
  if configWindow and configWindow.lastOpenMs then
    AP:Print(string.format(
      "Last config open: %.1f ms (tree %.1f ms, content %.1f ms, %d rows)",
      configWindow.lastOpenMs,
      configWindow.lastTreeMs or 0,
      configWindow.lastContentMs or 0,
      configWindow.lastTreeNodeCount or 0
    ))
  end
  if state.initializationError then
    AP:Print("|cffff6666Last initialization error:|r " .. tostring(state.initializationError))
  end
end

local function toggleMinimap()
  if not AP.initialized and AP.TryInitialize then
    local ok = AP:TryInitialize("minimap command")
    if not ok then
      return
    end
  end

  if not AP.Launcher or type(AP.Launcher.ToggleMinimap) ~= "function" then
    AP:Print("|cffff6666The minimap launcher is unavailable.|r Type /wp status for diagnostics.")
    return
  end

  local visible = AP.Launcher:ToggleMinimap()
  AP:Print("Minimap button " .. (visible and "shown." or "hidden."))
end

local function openConfig(query)
  if not AP.initialized and AP.TryInitialize then
    local ok = AP:TryInitialize("slash command")
    if not ok then
      return
    end
  end

  if type(AP.OpenConfig) ~= "function" then
    AP:Print("|cffff6666The config loader is unavailable.|r Type /wp status for diagnostics.")
    return
  end

  local ok, opened, openError = pcall(AP.OpenConfig, AP, nil, query)
  if not ok then
    openError = opened
    opened = false
  end
  if not opened then
    AP:Print("|cffff6666Could not open configuration:|r " .. tostring(openError or "unknown error"))
  end
end

local function controlSorter(arguments)
  if not AP.initialized and AP.TryInitialize then
    local ok = AP:TryInitialize("sort command")
    if not ok then
      return
    end
  end

  local sorter = AP.Banking and AP.Banking.Sorter
  if not sorter or type(sorter.HandleSlash) ~= "function" then
    AP:Print("|cffff6666The WotLK Plus sorter is unavailable.|r Fully relog if this build added new addon files.")
    return
  end
  sorter:HandleSlash(arguments)
end

local function controlTransmog(arguments)
  if not AP.initialized and AP.TryInitialize then
    local ok = AP:TryInitialize("transmog command")
    if not ok then
      return
    end
  end

  local inbox = AP.TransmogAppearanceInbox
  if not inbox or type(inbox.HandleSlash) ~= "function" then
    AP:Print("|cffff6666The Appearance Inbox is unavailable.|r Fully relog if this build added new addon files.")
    return
  end
  inbox:HandleSlash(arguments)
end

local function controlSkillCards(arguments)
  if not AP.initialized and AP.TryInitialize then
    local ok = AP:TryInitialize("skill cards command")
    if not ok then
      return
    end
  end

  local window = AP.SkillCards and AP.SkillCards.Window
  if not window or type(window.HandleSlash) ~= "function" then
    AP:Print("|cffff6666The Skill Card Ledger is unavailable.|r Fully relog if this build added new addon files.")
    return
  end
  window:HandleSlash(arguments)
end

local function handlePrimarySlash(message)
  local input = trim(message)
  if input == "" then
    showHelp()
    return
  end

  local command, remainder = input:match("^(%S+)%s*(.-)$")
  command = string.lower(command or "")

  if command == "help" or command == "?" then
    showHelp()
  elseif command == "config" or command == "c" or command == "options" then
    openConfig(remainder ~= "" and remainder or nil)
  elseif command == "search" or command == "find" then
    openConfig(remainder)
  elseif command == "sort" or command == "sortbank" then
    controlSorter(remainder)
  elseif command == "transmog" or command == "appearance" or command == "wardrobe" then
    controlTransmog(remainder)
  elseif command == "cards" or command == "card" or command == "skillcards" or command == "ledger" then
    controlSkillCards(remainder)
  elseif command == "minimap" or command == "icon" then
    toggleMinimap()
  elseif command == "status" or command == "debug" then
    showStatus()
  else
    AP:Print("Unknown command |cffffaa55" .. command .. "|r. Type |cff93c2ff/wp help|r.")
  end
end

local function handleConfigSlash(message)
  local query = trim(message)
  openConfig(query ~= "" and query or nil)
end

function AP:RegisterSlashCommands()
  if type(SlashCmdList) ~= "table" then
    return false, "SlashCmdList is unavailable"
  end

  _G.SLASH_WOTLKPLUS1 = "/wp"
  _G.SLASH_WOTLKPLUS2 = "/wotlkplus"
  SlashCmdList.WOTLKPLUS = handlePrimarySlash

  _G.SLASH_WOTLKPLUSCONFIG1 = "/wpc"
  _G.SLASH_WOTLKPLUSCONFIG2 = "/wotlkplusconfig"
  SlashCmdList.WOTLKPLUSCONFIG = handleConfigSlash

  -- Existing Ascension Plus users keep their muscle-memory commands after migration.
  _G.SLASH_ASCENSIONPLUS1 = "/ap"
  _G.SLASH_ASCENSIONPLUS2 = "/ascensionplus"
  SlashCmdList.ASCENSIONPLUS = handlePrimarySlash
  _G.SLASH_ASCENSIONPLUSCONFIG1 = "/apc"
  _G.SLASH_ASCENSIONPLUSCONFIG2 = "/apconfig"
  SlashCmdList.ASCENSIONPLUSCONFIG = handleConfigSlash

  self.slashRegistered = true
  return true
end

AP:RegisterSlashCommands()
