local _, AP = ...
AP = AP or _G.AscensionPlus

local Registry = AP.ConfigRegistry

AP.Modules:Register("launcher", {
  order = 10,

  OnInitialize = function()
    Registry:RegisterPage({
      id = "interface.launcher",
      parent = "interface",
      title = "Launcher",
      order = 10,
      description = "Data Broker and minimap access to WotLK Plus.",
      searchText = "launcher ldb libdatabroker minimap icon broker chocolatebar config",
      options = function()
        return {
          {
            type = "text",
            label = "Status",
            text = function()
              return AP.Launcher:GetStatusText()
            end,
          },
          {
            type = "toggle",
            label = "Show minimap button",
            description = "Show the draggable WotLK Plus icon around the minimap.",
            get = function()
              return AP.Launcher:IsMinimapVisible()
            end,
            set = function(checked)
              AP.Launcher:SetMinimapVisible(checked)
            end,
          },
          {
            type = "toggle",
            path = "interface.launcher.showTooltip",
            label = "Show launcher tooltip",
            description = "Show click instructions and launcher status when hovering over the icon or an LDB display.",
            onChange = function()
              AP.Launcher:Refresh()
            end,
          },
          {
            type = "button",
            label = "Reset minimap position",
            buttonText = "Reset Position",
            description = "Move the minimap icon back to its default position.",
            action = function()
              AP.Launcher:ResetMinimapPosition()
            end,
          },
          {
            type = "text",
            label = "Mouse controls",
            text = "Left-click toggles configuration. Shift + Left-click toggles the optional extension window. Right-click prints the /wp command list in chat.",
          },
        }
      end,
    })
  end,

  OnEnable = function()
    AP.Launcher:Enable()
  end,

  OnDisable = function()
    AP.Launcher:Disable()
  end,
})
