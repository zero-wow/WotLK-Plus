local _, AP = ...
AP = AP or _G.Levo or _G.WotLKPlus or _G.AscensionPlus

local Presentation = AP.Banking.SorterPresentation

local CANDIDATES = {
  keeper = { "AdiBagsGuildBankFrame", "AdiBags_GuildBankFrame" },
  character = { "AdiBagsBankFrame", "AdiBags_BankFrame" },
  inventory = { "AdiBagsContainer1", "AdiBags_ContainerFrame" },
}

local function nativeSortButton(frame)
  return frame and (frame.sortButton or frame.SortButton or frame.sort)
end

Presentation:RegisterAdapter({
  id = "adibags",
  order = 30,
  Resolve = function(_, contextID)
    if type(IsAddOnLoaded) ~= "function" or not IsAddOnLoaded("AdiBags") then
      return nil
    end

    local candidates = CANDIDATES[contextID] or {}
    for index = 1, #candidates do
      local host = _G[candidates[index]]
      local nativeSort = nativeSortButton(host)
      if host and host:IsShown() and nativeSort and nativeSort:IsShown() then
        return {
          id = "adibags-" .. contextID,
          host = host,
          anchor = nativeSort,
          point = "RIGHT",
          relativePoint = "LEFT",
          x = -4,
          y = 0,
          size = nativeSort:GetWidth() or 22,
        }
      end
    end
  end,
})
