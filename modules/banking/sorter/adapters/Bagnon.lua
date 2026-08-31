local _, AP = ...
AP = AP or _G.Levo or _G.WotLKPlus or _G.AscensionPlus

local Presentation = AP.Banking.SorterPresentation

local CANDIDATES = {
  keeper = { "BagnonGuildBankFrame", "BagnonFrameguildbank" },
  character = { "BagnonBankFrame", "BagnonFramebank" },
  inventory = { "BagnonInventoryFrame", "BagnonFrameinventory" },
}

local function nativeSortButton(frame)
  return frame and (frame.sortButton or frame.SortButton or frame.sort)
end

Presentation:RegisterAdapter({
  id = "bagnon",
  order = 20,
  Resolve = function(_, contextID)
    if type(IsAddOnLoaded) ~= "function" or not IsAddOnLoaded("Bagnon") then
      return nil
    end

    local candidates = CANDIDATES[contextID] or {}
    for index = 1, #candidates do
      local host = _G[candidates[index]]
      local nativeSort = nativeSortButton(host)
      if host and host:IsShown() and nativeSort and nativeSort:IsShown() then
        return {
          id = "bagnon-" .. contextID,
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
