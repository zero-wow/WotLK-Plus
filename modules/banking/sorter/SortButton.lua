local _, AP = ...
AP = AP or _G.AscensionPlus

local Banking = AP.Banking
local Theme = AP.UI.Theme
local Sorter = Banking.Sorter
local ICON = "Interface\\AddOns\\WotLK-Plus\\media\\banking\\sort"

local SortButton = {
  frames = {},
}

Banking.SorterButton = SortButton

local function setBorder(frame, color)
  if frame and frame.SetBackdropBorderColor then
    frame:SetBackdropBorderColor(color[1], color[2], color[3], color[4] or 1)
  end
end

local function contextTitle(contextID)
  local provider = Sorter:GetProvider(contextID)
  return provider and provider:GetBankName() or tostring(contextID or "Sorter")
end

function SortButton:Create(contextID)
  local frame = self.frames[contextID]
  if frame then
    return frame
  end

  local safeID = tostring(contextID):gsub("[^%w]", "")
  frame = CreateFrame("Button", "WotLKPlusSortButton" .. safeID, UIParent)
  frame:SetWidth(22)
  frame:SetHeight(22)
  frame:SetClampedToScreen(true)
  frame.contextID = contextID
  Theme:ApplyBackdrop(frame, Theme.colors.inset, Theme.colors.border)

  local icon = frame:CreateTexture(nil, "ARTWORK")
  icon:SetPoint("TOPLEFT", 3, -3)
  icon:SetPoint("BOTTOMRIGHT", -3, 3)
  icon:SetTexture(ICON)
  frame.Icon = icon

  local hover = frame:CreateTexture(nil, "HIGHLIGHT")
  hover:SetAllPoints(frame)
  Theme:Paint(hover, { Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3], 0.16 })
  frame:SetHighlightTexture(hover)

  local pulse = frame:CreateTexture(nil, "OVERLAY")
  pulse:SetAllPoints(frame)
  Theme:Paint(pulse, { Theme.colors.orange[1], Theme.colors.orange[2], Theme.colors.orange[3], 0.18 })
  pulse:Hide()
  frame.Pulse = pulse

  local progressBackground = frame:CreateTexture(nil, "OVERLAY")
  progressBackground:SetPoint("BOTTOMLEFT", 3, 3)
  progressBackground:SetPoint("BOTTOMRIGHT", -3, 3)
  progressBackground:SetHeight(2)
  Theme:Paint(progressBackground, { 0.02, 0.02, 0.02, 0.90 })
  progressBackground:Hide()
  frame.ProgressBackground = progressBackground

  local progress = frame:CreateTexture(nil, "OVERLAY")
  progress:SetPoint("BOTTOMLEFT", 3, 3)
  progress:SetHeight(2)
  Theme:Paint(progress, Theme.colors.gold)
  progress:Hide()
  frame.Progress = progress

  frame:SetScript("OnEnter", function(button)
    local activeHere = Sorter:IsRunning() and Sorter.provider and Sorter.provider.id == button.contextID
    setBorder(button, activeHere and Theme.colors.orange or Theme.colors.gold)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:AddLine("WOTLK PLUS SORT", Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3])
    GameTooltip:AddLine(contextTitle(button.contextID), Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3])
    GameTooltip:AddLine(Sorter:GetStatusText(), Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3], true)
    GameTooltip:AddLine(" ")
    if activeHere then
      GameTooltip:AddLine("Click to cancel after the active move confirms.", Theme.colors.orange[1], Theme.colors.orange[2], Theme.colors.orange[3], true)
    elseif Sorter:IsRunning() then
      GameTooltip:AddLine("Another WotLK Plus sort is already running.", Theme.colors.red[1], Theme.colors.red[2], Theme.colors.red[3], true)
    else
      local available, reason = Sorter:GetAvailability(button.contextID)
      if available then
        GameTooltip:AddLine("Click to consolidate and sort this visible context.", Theme.colors.green[1], Theme.colors.green[2], Theme.colors.green[3], true)
      else
        GameTooltip:AddLine(reason, Theme.colors.red[1], Theme.colors.red[2], Theme.colors.red[3], true)
      end
    end
    GameTooltip:AddLine("Blocked item slots, blocked bags, and specialty bags are omitted before planning. Each move waits for server confirmation.", Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3], true)
    GameTooltip:Show()
  end)
  frame:SetScript("OnLeave", function(button)
    local activeHere = Sorter:IsRunning() and Sorter.provider and Sorter.provider.id == button.contextID
    setBorder(button, activeHere and Theme.colors.orange or Theme.colors.border)
    GameTooltip:Hide()
  end)
  frame:SetScript("OnMouseDown", function(button)
    if button:IsEnabled() then
      button.Icon:ClearAllPoints()
      button.Icon:SetPoint("TOPLEFT", 4, -4)
      button.Icon:SetPoint("BOTTOMRIGHT", -2, 2)
    end
  end)
  frame:SetScript("OnMouseUp", function(button)
    button.Icon:ClearAllPoints()
    button.Icon:SetPoint("TOPLEFT", 3, -3)
    button.Icon:SetPoint("BOTTOMRIGHT", -3, 3)
  end)
  frame:SetScript("OnClick", function(button)
    if Sorter:IsRunning() then
      Sorter:Cancel("Sorting cancelled from the bank or inventory button.")
    else
      Sorter:Start(button.contextID)
    end
  end)
  frame:SetScript("OnUpdate", function(button)
    if button.busy then
      local currentTime = type(GetTime) == "function" and GetTime() or 0
      button.Pulse:SetAlpha(0.10 + (math.sin(currentTime * 5) + 1) * 0.08)
    end
  end)

  frame:Hide()
  self.frames[contextID] = frame
  return frame
end

function SortButton:SetPlacement(contextID, placement)
  local frame = self:Create(contextID)
  local host = placement and placement.host
  if not host then
    frame:Hide()
    return
  end

  local size = math.max(18, math.min(tonumber(placement.size) or 22, 28))
  frame:SetWidth(size)
  frame:SetHeight(size)
  frame:SetParent(host)
  frame:SetFrameStrata(host:GetFrameStrata() or "MEDIUM")
  frame:SetFrameLevel(placement.frameLevel or ((placement.anchor and placement.anchor.GetFrameLevel and placement.anchor:GetFrameLevel()) or host:GetFrameLevel() or 0) + 8)
  frame:ClearAllPoints()
  frame:SetPoint(
    placement.point or "RIGHT",
    placement.anchor or host,
    placement.relativePoint or placement.point or "LEFT",
    placement.x or -4,
    placement.y or 0
  )
end

function SortButton:Refresh(contextID, placement)
  local frame = self:Create(contextID)
  if not placement
    or not Sorter.enabled
    or not AP.Database:Get("banking.sorter.showButton", true) then
    frame:Hide()
    return
  end

  self:SetPlacement(contextID, placement)
  local running = Sorter:IsRunning()
  local activeHere = running and Sorter.provider and Sorter.provider.id == contextID
  local available = not running and Sorter:GetAvailability(contextID)
  frame.busy = activeHere

  if activeHere then
    frame:Enable()
    frame.Icon:SetDesaturated(false)
    frame.Icon:SetVertexColor(1, 0.88, 0.48, 1)
    frame.Pulse:Show()
    frame.ProgressBackground:Show()
    local completed, total = Sorter:GetProgress()
    local width = total > 0 and (frame:GetWidth() - 6) * (completed / total) or 1
    frame.Progress:SetWidth(math.max(width, 1))
    frame.Progress:Show()
    setBorder(frame, Theme.colors.orange)
  else
    frame.Pulse:Hide()
    frame.ProgressBackground:Hide()
    frame.Progress:Hide()
    if available then
      frame:Enable()
      frame.Icon:SetDesaturated(false)
      frame.Icon:SetVertexColor(1, 1, 1, 1)
      setBorder(frame, Theme.colors.border)
    else
      frame:Disable()
      frame.Icon:SetDesaturated(true)
      frame.Icon:SetVertexColor(0.55, 0.55, 0.55, 0.85)
      setBorder(frame, { 0.35, 0.35, 0.35, 0.65 })
    end
  end
  frame:Show()
end
