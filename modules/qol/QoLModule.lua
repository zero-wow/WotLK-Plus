local _, AP = ...
AP = AP or _G.Levo or _G.WotLKPlus or _G.AscensionPlus

local Registry = AP.ConfigRegistry

AP.Modules:Register("qol", {
  order = 22,

  OnInitialize = function()
    Registry:RegisterPage({
      id = "qol",
      title = "Utilities",
      order = 50,
      description = "Focused helpers for small, repetitive game interactions.",
      searchText = "qol quality of life destroy delete helper convenience",
      options = function()
        return {
          {
            type = "text",
            text = "Select a helper below to configure its runtime behavior.",
          },
        }
      end,
    })
  end,
})
