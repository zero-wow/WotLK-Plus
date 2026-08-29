local _, AP = ...
AP = AP or _G.AscensionPlus

local Banking = AP.Banking
local Presentation = {
  adapters = {},
  contexts = { "keeper", "character", "inventory" },
}

Banking.SorterPresentation = Presentation

function Presentation:RegisterAdapter(adapter)
  if not adapter or not adapter.id or type(adapter.Resolve) ~= "function" then
    return
  end
  self.adapters[#self.adapters + 1] = adapter
  table.sort(self.adapters, function(left, right)
    return (left.order or 100) < (right.order or 100)
  end)
end

function Presentation:HookFrame(frame)
  if not frame or frame.__WotLKPlusSorterHooked or type(frame.HookScript) ~= "function" then
    return
  end
  frame.__WotLKPlusSorterHooked = true
  local function refresh()
    local sorter = Banking.Sorter
    if sorter then
      sorter:BeginUISettle(0.8)
      sorter:ScheduleUIRefresh(0.03)
    end
  end
  frame:HookScript("OnShow", refresh)
  frame:HookScript("OnHide", refresh)
end

function Presentation:InstallHooks()
  local frameNames = {
    "GuildBankFrame",
    "BankFrame",
    "ElvUI_ContainerFrame",
    "ElvUI_BankContainerFrame",
    "BagnonFrameinventory",
    "BagnonFramebank",
    "BagnonFrameguildbank",
    "AdiBagsContainer1",
    "AdiBagsBankFrame",
    "AdiBagsGuildBankFrame",
  }
  for index = 1, #frameNames do
    self:HookFrame(_G[frameNames[index]])
  end
  for index = 1, (_G.NUM_CONTAINER_FRAMES or 13) do
    self:HookFrame(_G["ContainerFrame" .. tostring(index)])
  end
end

function Presentation:GetPlacement(contextID)
  local provider = Banking.SorterProviders and Banking.SorterProviders[contextID]
  if not provider or not provider.IsOpen or not provider:IsOpen() then
    return nil
  end

  local preferNative = AP.Database:Get("banking.sorter.preferNativeAnchor", true)
  if not preferNative then
    for index = 1, #self.adapters do
      local adapter = self.adapters[index]
      if adapter.id == "blizzard" then
        local placement = adapter:Resolve(contextID, true)
        if placement then
          return placement
        end
      end
    end
  end

  for index = 1, #self.adapters do
    local placement = self.adapters[index]:Resolve(contextID, false)
    if placement then
      return placement
    end
  end
end

function Presentation:Refresh()
  self:InstallHooks()
  if not Banking.SorterButton then
    return
  end
  for index = 1, #self.contexts do
    local contextID = self.contexts[index]
    Banking.SorterButton:Refresh(contextID, self:GetPlacement(contextID))
  end
end
