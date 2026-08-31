local _, AP = ...
AP = AP or _G.Levo or _G.WotLKPlus or _G.AscensionPlus

local Registry = AP.ConfigRegistry
local Helper = AP.DestroyConfirmHelper

local function refreshModuleState()
  AP.Modules:RefreshStates()
end

AP.Modules:Register("destroyConfirm", {
  order = 23,
  enabledPath = "modules.destroyConfirm",

  OnInitialize = function()
    Registry:RegisterPage({
      id = "qol.destroy-items",
      parent = "qol",
      title = "Destroy Items",
      order = 10,
      description = "Auto-fill the DELETE confirmation text when destroying protected items.",
      searchText = "destroy items delete confirm popup trash discard protected item delete text",
      options = function()
        return {
          {
            type = "text",
            label = "Safety",
            text = "This only fills the required text. It never clicks the confirmation button or bypasses the popup.",
          },
          {
            type = "toggle",
            path = "modules.destroyConfirm",
            label = "Enable destroy helper module",
            description = "Loads the destroy-confirm watcher and its config page behavior.",
            onChange = refreshModuleState,
          },
          {
            type = "toggle",
            path = "qol.destroyConfirm.autoFillDelete",
            label = "Auto-fill DELETE text",
            description = "Automatically fill the confirmation box when the destroy popup asks for DELETE.",
          },
        }
      end,
    })
  end,

  OnEnable = function()
    Helper:Enable()
  end,

  OnDisable = function()
    Helper:Disable()
  end,
})
