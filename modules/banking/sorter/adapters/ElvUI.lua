local _, AP = ...
AP = AP or _G.Levo or _G.WotLKPlus or _G.AscensionPlus

local Presentation = AP.Banking.SorterPresentation

local function shown(frame)
  return frame and frame.IsShown and frame:IsShown()
end

local function getFrames(contextID)
  if contextID == "keeper" then
    return _G.GuildBankFrame, _G.GuildBankFrameSortButton
  elseif contextID == "character" then
    local host = _G.ElvUI_BankContainerFrame
    return host, host and (host.sortButton or _G.ElvUI_BankContainerFrameSortButton)
  elseif contextID == "inventory" then
    local host = _G.ElvUI_ContainerFrame
    return host, host and (host.sortButton or _G.ElvUI_ContainerFrameSortButton)
  end
end

Presentation:RegisterAdapter({
  id = "elvui",
  order = 10,
  Resolve = function(_, contextID)
    if type(IsAddOnLoaded) ~= "function" or not IsAddOnLoaded("ElvUI") then
      return nil
    end

    local host, nativeSort = getFrames(contextID)
    if not shown(host) or not shown(nativeSort) then
      return nil
    end
    return {
      id = "elvui-" .. contextID,
      host = host,
      anchor = nativeSort,
      point = "RIGHT",
      relativePoint = "LEFT",
      x = -4,
      y = 0,
      size = nativeSort:GetWidth() or 20,
      frameLevel = (nativeSort:GetFrameLevel() or host:GetFrameLevel() or 0) + 8,
    }
  end,
})
