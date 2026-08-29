local _, AP = ...
AP = AP or _G.AscensionPlus

function AP.RegisterCorePages()
  if AP._corePagesRegistered then
    return
  end
  AP._corePagesRegistered = true

  AP.ConfigRegistry:RegisterPage({
    id = "general",
    title = "Overview",
    order = 10,
      description = "Live feature status and the fastest routes into WotLK Plus.",
      searchText = "overview general status modules slash commands help wp wpc ap apc config",
      options = function()
        local options = {
          {
            type = "status",
            label = "WotLK Plus",
            value = "READY",
          color = "green",
          description = "Version " .. tostring(AP.version or "") .. " is initialized. Settings apply immediately.",
        },
          {
          type = "status",
          label = "Banking",
          value = function()
            return AP.Database:Get("modules.banking", true) and "ENABLED" or "DISABLED"
          end,
          color = function()
            return AP.Database:Get("modules.banking", true) and "green" or "muted"
          end,
          description = "Confirmed transfers, category rules, and safe inventory sorting.",
        },
          {
            type = "toggle",
            path = "general.showStartupMessage",
            label = "Show startup message on login",
            description = "Print a small chat confirmation when WotLK Plus finishes loading.",
          },
        }

        if AP.Modules:Get("skillCards") then
          options[#options + 1] = {
            type = "status",
            label = "Skill Cards",
            value = function()
              return AP.Database:Get("modules.skillCards", true) and "ENABLED" or "DISABLED"
            end,
            color = function()
              return AP.Database:Get("modules.skillCards", true) and "green" or "muted"
            end,
            description = function()
              local catalog = AP.SkillCards and AP.SkillCards.Catalog
              return catalog and catalog:GetStatusText() or "The Skill Card Ledger is waiting for runtime initialization."
            end,
          }
          options[#options + 1] = {
            type = "button",
            label = "Skill Card Ledger",
            buttonText = "Open Ledger",
            description = "Inspect carried cards, learn uncollected designs, and exchange safely at the vendor.",
            disabled = function()
              return not AP.Database:Get("modules.skillCards", true)
            end,
            action = function()
              local window = AP.SkillCards and AP.SkillCards.Window
              if window and window.Open then
                window:Open("expanded")
              end
            end,
          }
        end

        if AP.Modules:Get("transmog") then
          options[#options + 1] = {
            type = "status",
            label = "Appearances",
            value = function()
              return AP.Database:Get("modules.transmog", true) and "ENABLED" or "DISABLED"
            end,
            color = function()
              return AP.Database:Get("modules.transmog", true) and "green" or "muted"
            end,
            description = "Loot review, collection rules, and the Appearance Inbox.",
          }
        end

        return options
      end,
  })

  AP.ConfigRegistry:RegisterPage({
    id = "interface",
    title = "Interface",
    order = 90,
    description = "Window behavior, navigation memory, and presentation.",
    searchText = "interface search tree config window appearance",
    options = function()
      return {
        {
          type = "toggle",
          path = "interface.restoreLastPage",
          label = "Restore last selected page",
          description = "Re-open the config panel on the last page you visited.",
        },
        {
          type = "toggle",
          path = "interface.searchHints",
          label = "Show search placeholder hint",
          description = "Display a search hint while the search bar is empty.",
          onChange = function()
            if AP.ConfigWindow and AP.ConfigWindow.frame then
              AP.ConfigWindow:RefreshSearchHint()
            end
          end,
        },
        {
          type = "button",
          label = "Reset window layout",
          buttonText = "Reset Window",
          description = "Reset the config panel size and position back to the default anchor.",
          action = function()
            AP.ConfigWindow:ResetWindowState()
          end,
        },
      }
    end,
  })
end

local function requireService(name, value)
  if value == nil then
    error("Required service did not load: " .. tostring(name))
  end
  return value
end

function AP:Initialize()
  if self.initialized then
    return true
  end
  if self.initializing then
    return false, "initialization is already in progress"
  end

  self.initializing = true

  local ok, err = pcall(function()
    requireService("Utils", self.Utils)
    requireService("Database", self.Database)
    requireService("Modules", self.Modules)
    requireService("ConfigRegistry", self.ConfigRegistry)
    requireService("ConfigWindow", self.ConfigWindow)

    self.Database:Initialize()
    self.RegisterCorePages()
    self.Modules:InitializeDefinitions()
    self.ConfigRegistry:Finalize()
    self.Modules:RefreshStates()
  end)

  self.initializing = false
  if not ok then
    self.initializationError = tostring(err)
    return false, self.initializationError
  end

  self.initialized = true
  self.initializationError = nil
  if self.loadState then
    self.loadState.initialized = true
    self.loadState.initializationError = nil
  end
  return true
end

function AP:OpenConfig(pageId, query)
  if not self.initialized then
    local initialized, initializeError = self:TryInitialize("config open")
    if not initialized then
      return false, initializeError
    end
  end

  if not self.ConfigWindow or type(self.ConfigWindow.Open) ~= "function" then
    return false, "ConfigWindow.Open is unavailable"
  end

  local ok, err = pcall(self.ConfigWindow.Open, self.ConfigWindow, pageId, query)
  if not ok then
    return false, err
  end

  return true
end

if AP.loadState then
  AP.loadState.bootstrapLoaded = true
end
