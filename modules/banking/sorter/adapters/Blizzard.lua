local _, AP = ...
AP = AP or _G.AscensionPlus

local Presentation = AP.Banking.SorterPresentation

local function shown(frame)
  return frame and frame.IsShown and frame:IsShown()
end

Presentation:RegisterAdapter({
  id = "blizzard",
  order = 100,
  Resolve = function(_, contextID, forcedFallback)
    local host
    local nativeSort
    if contextID == "keeper" then
      host = _G.GuildBankFrame
      nativeSort = _G.GuildBankFrameSortButton or (host and (host.sortButton or host.SortButton))
    elseif contextID == "character" then
      host = _G.BankFrame
      nativeSort = host and (host.sortButton or host.SortButton)
    elseif contextID == "inventory" then
      host = _G.ContainerFrame1
      nativeSort = host and (host.sortButton or host.SortButton)
    end

    if not shown(host) then
      return nil
    end
    if not forcedFallback and shown(nativeSort) then
      return {
        id = "blizzard-native-" .. contextID,
        host = host,
        anchor = nativeSort,
        point = "RIGHT",
        relativePoint = "LEFT",
        x = -4,
        y = 0,
        size = nativeSort:GetWidth() or 22,
      }
    end

    if contextID == "keeper" then
      return {
        id = "blizzard-fallback-keeper",
        host = host,
        anchor = host,
        point = "BOTTOMRIGHT",
        relativePoint = "BOTTOMRIGHT",
        x = -40,
        y = 38,
      }
    end
    return {
      id = "blizzard-fallback-" .. contextID,
      host = host,
      anchor = host,
      point = "TOPRIGHT",
      relativePoint = "TOPRIGHT",
      x = -34,
      y = -14,
      size = 20,
    }
  end,
})

