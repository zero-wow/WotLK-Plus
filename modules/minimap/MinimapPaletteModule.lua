local _, AP = ...
AP = AP or _G.Levo or _G.WotLKPlus or _G.AscensionPlus

local Palette = AP.MinimapPalette
local Registry = AP.ConfigRegistry

AP.Modules:Register("minimapPalette", {
  order = 11,
  enabledPath = "modules.minimapPalette",

  OnInitialize = function()
    Registry:RegisterPage({
      id = "interface.minimapPalette",
      parent = "interface",
      title = "Minimap Palette",
      order = 15,
      description = "Collect eligible third-party minimap launcher buttons into a compact Levo palette without changing their original frames.",
      searchText = "minimap palette launcher buttons icons collect hide restore hub square names right click lock shift drag move visibility",
      options = function()
        return {
          {
            type = "text",
            label = "Status",
            text = function()
              return Palette:GetStatusText()
            end,
          },
          {
            type = "toggle",
            path = "modules.minimapPalette",
            label = "Enable minimap palette",
            description = "Show the Levo hub button and its expandable launcher list.",
            onChange = function()
              AP.Modules:RefreshStates()
            end,
          },
          {
            type = "toggle",
            label = "Collect launcher buttons",
            description = "Hide eligible third-party minimap launcher buttons and replace them with non-invasive square proxy rows in the palette. Turn this off to restore them immediately.",
            get = function()
              return Palette:IsCollectionEnabled()
            end,
            set = function(checked)
              Palette:SetCollectionEnabled(checked)
            end,
          },
          {
            type = "toggle",
            label = "Lock hub position",
            description = "Prevent Shift + drag from moving the central palette hub.",
            get = function()
              return Palette:IsLocked()
            end,
            set = function(checked)
              Palette:SetLocked(checked)
            end,
          },
          {
            type = "toggle",
            path = "interface.minimapPalette.showTooltips",
            label = "Show palette tooltips",
            description = "Show action descriptions when hovering over the hub and launcher rows.",
          },
          {
            type = "button",
            label = "Refresh launcher list",
            buttonText = "Refresh",
            description = "Rescan the minimap immediately for eligible unprotected launcher buttons.",
            action = function()
              Palette:Refresh()
            end,
          },
          {
            type = "button",
            label = "Reset hub position",
            buttonText = "Reset Position",
            description = "Move the palette hub back to the upper-right edge of the minimap and restore its default behavior settings.",
            action = function()
              Palette:ResetPosition()
            end,
          },
          {
            type = "text",
            label = "Controls",
            text = "Left-click the hub to open or close the launcher palette. Shift + drag moves it while unlocked. Right-click opens quick controls for locking, restoring original icons, refreshing, and settings.",
          },
        }
      end,
    })
  end,

  OnEnable = function()
    Palette:Enable()
  end,

  OnDisable = function()
    Palette:Disable()
  end,
})
