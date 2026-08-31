local _, AP = ...
AP = AP or _G.Levo or _G.WotLKPlus or _G.AscensionPlus

local Theme = AP.UI.Theme
local Rules = AP.TransmogAppearanceRules

local Prompt = {
  frame = nil,
}

Prompt.LAYOUT = {
  width = 560,
  height = 358,
  inset = 16,
  gutter = 8,
  titleBarHeight = 38,
  summaryTop = 52,
  itemTop = 76,
  itemHeight = 72,
  queueLabelTop = 163,
  queueTop = 181,
  queueHeight = 58,
  queueRows = 3,
  queueRowHeight = 16,
  warningTop = 251,
  buttonBottom = 16,
  buttonHeight = 24,
  buttonGap = 8,
  learnWidth = 112,
  autoWidth = 148,
  neverWidth = 112,
  laterWidth = 92,
}

AP.TransmogAppearancePrompt = Prompt

local QUALITY_NAMES = {
  [0] = "Poor",
  [1] = "Common",
  [2] = "Uncommon",
  [3] = "Rare",
  [4] = "Epic",
  [5] = "Legendary",
  [6] = "Artifact",
  [7] = "Heirloom",
}

local function setColor(fontString, color)
  fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

local function keepSingleLine(fontString, height)
  fontString:SetHeight(height)
  if fontString.SetWordWrap then
    fontString:SetWordWrap(false)
  end
  if fontString.SetNonSpaceWrap then
    fontString:SetNonSpaceWrap(false)
  end
end

local function getQualityColor(quality)
  local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[tonumber(quality)]
  if color then
    return { color.r, color.g, color.b, 1 }
  end
  return Theme.colors.text
end

local function getQualityName(quality)
  local catalog = AP.TransmogAppearanceCatalog
  if catalog and type(catalog.GetQualityName) == "function" then
    return catalog:GetQualityName(quality)
  end
  return QUALITY_NAMES[tonumber(quality)] or "Unknown"
end

local function applyItemTooltip(frame)
  local entry = frame.Entry
  if not entry or not GameTooltip then
    return
  end

  GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
  local currentID = type(GetContainerItemID) == "function"
    and GetContainerItemID(entry.bag, entry.slot)
    or nil
  if currentID == entry.itemID and type(GameTooltip.SetBagItem) == "function" then
    GameTooltip:SetBagItem(entry.bag, entry.slot)
  elseif entry.link and type(GameTooltip.SetHyperlink) == "function" then
    GameTooltip:SetHyperlink(entry.link)
  end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("Levo Appearance Review", Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3])
  GameTooltip:AddLine("No binding occurs until you choose an action.", 1, 1, 1, true)
  GameTooltip:Show()
end

function Prompt:EnsureFrame()
  if self.frame then
    return self.frame
  end

  local layout = self.LAYOUT
  local frame = CreateFrame("Frame", "LevoAppearancePrompt", UIParent)
  frame:SetWidth(layout.width)
  frame:SetHeight(layout.height)
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 28)
  frame:SetFrameStrata("DIALOG")
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:Hide()
  Theme:ApplyBackdrop(frame, Theme.colors.background, Theme.colors.border)

  frame.TitleBar = frame:CreateTexture(nil, "BACKGROUND")
  frame.TitleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
  frame.TitleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
  frame.TitleBar:SetHeight(layout.titleBarHeight)
  Theme:Paint(frame.TitleBar, Theme.colors.titlebar)

  frame.Title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  frame.Title:SetPoint("TOPLEFT", frame, "TOPLEFT", layout.inset, -13)
  frame.Title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -46, -13)
  frame.Title:SetText("APPEARANCE REVIEW")
  setColor(frame.Title, Theme.colors.gold)
  Theme:TrySetTitleFont(frame.Title, 18)

  frame.CloseButton = CreateFrame("Button", nil, frame)
  frame.CloseButton:SetWidth(24)
  frame.CloseButton:SetHeight(24)
  frame.CloseButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -7)
  Theme:SkinCloseButton(frame.CloseButton, "x")

  frame.TitleRule = frame:CreateTexture(nil, "ARTWORK")
  frame.TitleRule:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -39)
  frame.TitleRule:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, -39)
  frame.TitleRule:SetHeight(1)
  Theme:Paint(frame.TitleRule, Theme.colors.line)

  frame.Summary = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.Summary:SetJustifyH("LEFT")
  frame.Summary:SetPoint("TOPLEFT", frame, "TOPLEFT", layout.inset, -layout.summaryTop)
  frame.Summary:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -layout.inset, -layout.summaryTop)
  keepSingleLine(frame.Summary, 16)
  setColor(frame.Summary, Theme.colors.text)

  frame.ItemShell = CreateFrame("Frame", nil, frame)
  frame.ItemShell:SetPoint("TOPLEFT", frame, "TOPLEFT", layout.inset, -layout.itemTop)
  frame.ItemShell:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -layout.inset, -layout.itemTop)
  frame.ItemShell:SetHeight(layout.itemHeight)
  frame.ItemShell:EnableMouse(true)
  Theme:ApplyBackdrop(frame.ItemShell, Theme.colors.inset, Theme.colors.gold)

  frame.IconShell = CreateFrame("Frame", nil, frame.ItemShell)
  frame.IconShell:SetWidth(52)
  frame.IconShell:SetHeight(52)
  frame.IconShell:SetPoint("LEFT", frame.ItemShell, "LEFT", 10, 0)
  Theme:ApplyBackdrop(frame.IconShell, Theme.colors.panel, Theme.colors.border)

  frame.Icon = frame.IconShell:CreateTexture(nil, "ARTWORK")
  frame.Icon:SetPoint("TOPLEFT", frame.IconShell, "TOPLEFT", 3, -3)
  frame.Icon:SetPoint("BOTTOMRIGHT", frame.IconShell, "BOTTOMRIGHT", -3, 3)
  frame.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

  frame.ItemName = frame.ItemShell:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  frame.ItemName:SetJustifyH("LEFT")
  frame.ItemName:SetPoint("TOPLEFT", frame.ItemShell, "TOPLEFT", 72, -12)
  frame.ItemName:SetPoint("TOPRIGHT", frame.ItemShell, "TOPRIGHT", -10, -12)
  keepSingleLine(frame.ItemName, 20)

  frame.ItemDetail = frame.ItemShell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.ItemDetail:SetJustifyH("LEFT")
  frame.ItemDetail:SetPoint("TOPLEFT", frame.ItemName, "BOTTOMLEFT", 0, -5)
  frame.ItemDetail:SetPoint("TOPRIGHT", frame.ItemShell, "TOPRIGHT", -10, -36)
  keepSingleLine(frame.ItemDetail, 16)
  setColor(frame.ItemDetail, Theme.colors.muted)

  frame.ItemShell:SetScript("OnEnter", function(self)
    applyItemTooltip(self)
  end)
  frame.ItemShell:SetScript("OnLeave", function()
    if GameTooltip then
      GameTooltip:Hide()
    end
  end)

  frame.QueueLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  frame.QueueLabel:SetJustifyH("LEFT")
  frame.QueueLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", layout.inset, -layout.queueLabelTop)
  keepSingleLine(frame.QueueLabel, 16)
  frame.QueueLabel:SetText("AVAILABLE AFTER THIS ITEM")
  setColor(frame.QueueLabel, Theme.colors.gold)

  frame.QueueShell = CreateFrame("Frame", nil, frame)
  frame.QueueShell:SetPoint("TOPLEFT", frame, "TOPLEFT", layout.inset, -layout.queueTop)
  frame.QueueShell:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -layout.inset, -layout.queueTop)
  frame.QueueShell:SetHeight(layout.queueHeight)
  Theme:ApplyBackdrop(frame.QueueShell, Theme.colors.inset, { Theme.colors.border[1], Theme.colors.border[2], Theme.colors.border[3], 0.30 })

  frame.QueueRows = {}
  for index = 1, layout.queueRows do
    local row = frame.QueueShell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row:SetJustifyH("LEFT")
    row:SetPoint("TOPLEFT", frame.QueueShell, "TOPLEFT", 8, -5 - ((index - 1) * layout.queueRowHeight))
    row:SetPoint("TOPRIGHT", frame.QueueShell, "TOPRIGHT", -8, -5 - ((index - 1) * layout.queueRowHeight))
    keepSingleLine(row, layout.queueRowHeight)
    frame.QueueRows[index] = row
  end

  frame.Warning = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  frame.Warning:SetJustifyH("LEFT")
  frame.Warning:SetPoint("TOPLEFT", frame, "TOPLEFT", layout.inset, -layout.warningTop)
  frame.Warning:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -layout.inset, -layout.warningTop)
  keepSingleLine(frame.Warning, 16)
  setColor(frame.Warning, Theme.colors.orange)

  frame.Explanation = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.Explanation:SetJustifyH("LEFT")
  frame.Explanation:SetJustifyV("TOP")
  frame.Explanation:SetPoint("TOPLEFT", frame.Warning, "BOTTOMLEFT", 0, -5)
  frame.Explanation:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -layout.inset, -layout.warningTop - 19)
  frame.Explanation:SetHeight(34)
  setColor(frame.Explanation, Theme.colors.text)

  local learnStyle = {
    border = { Theme.colors.green[1], Theme.colors.green[2], Theme.colors.green[3], 0.65 },
    text = Theme.colors.green,
    hoverBorder = Theme.colors.green,
    hoverText = Theme.colors.green,
  }
  frame.LearnButton = CreateFrame("Button", nil, frame)
  frame.LearnButton:SetWidth(layout.learnWidth)
  frame.LearnButton:SetHeight(layout.buttonHeight)
  frame.LearnButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", layout.inset, layout.buttonBottom)
  frame.LearnButton:SetText("LEARN ONCE")
  Theme:SkinButton(frame.LearnButton, learnStyle)

  local autoStyle = {
    border = { Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3], 0.75 },
    text = Theme.colors.gold,
    hoverBorder = Theme.colors.gold,
    hoverText = Theme.colors.gold,
  }
  frame.AutoButton = CreateFrame("Button", nil, frame)
  frame.AutoButton:SetWidth(layout.autoWidth)
  frame.AutoButton:SetHeight(layout.buttonHeight)
  frame.AutoButton:SetPoint("LEFT", frame.LearnButton, "RIGHT", layout.buttonGap, 0)
  frame.AutoButton:SetText("AUTO RARITY")
  Theme:SkinButton(frame.AutoButton, autoStyle)

  local neverStyle = {
    border = { Theme.colors.red[1], Theme.colors.red[2], Theme.colors.red[3], 0.65 },
    text = Theme.colors.red,
    hoverBorder = Theme.colors.red,
    hoverText = Theme.colors.red,
  }
  frame.NeverButton = CreateFrame("Button", nil, frame)
  frame.NeverButton:SetWidth(layout.neverWidth)
  frame.NeverButton:SetHeight(layout.buttonHeight)
  frame.NeverButton:SetPoint("LEFT", frame.AutoButton, "RIGHT", layout.buttonGap, 0)
  frame.NeverButton:SetText("NEVER ITEM")
  Theme:SkinButton(frame.NeverButton, neverStyle)

  frame.LaterButton = CreateFrame("Button", nil, frame)
  frame.LaterButton:SetWidth(layout.laterWidth)
  frame.LaterButton:SetHeight(layout.buttonHeight)
  frame.LaterButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -layout.inset, layout.buttonBottom)
  frame.LaterButton:SetText("LATER ALL")
  Theme:SkinButton(frame.LaterButton)

  frame.LearnButton:SetScript("OnClick", function()
    Rules:ResolveActive("approve")
  end)
  frame.AutoButton:SetScript("OnClick", function()
    Rules:ResolveActive("auto-quality")
  end)
  frame.NeverButton:SetScript("OnClick", function()
    Rules:ResolveActive("reject")
  end)
  frame.LaterButton:SetScript("OnClick", function()
    Rules:ResolveActive("defer-all")
  end)
  frame.CloseButton:SetScript("OnClick", function()
    Rules:ResolveActive("defer-all")
  end)

  frame:SetScript("OnHide", function(self)
    if self.APSilentHide then
      return
    end
    if self.Entry then
      Rules:ResolveActive("defer-all")
    end
  end)

  UISpecialFrames = UISpecialFrames or {}
  local registered = false
  for index = 1, #UISpecialFrames do
    if UISpecialFrames[index] == frame:GetName() then
      registered = true
      break
    end
  end
  if not registered then
    UISpecialFrames[#UISpecialFrames + 1] = frame:GetName()
  end

  self.frame = frame
  return frame
end

function Prompt:Refresh()
  local frame = self.frame
  if not frame or not frame:IsShown() then
    return
  end

  local entries = Rules:GetReviewEntries()
  local entry = entries[1]
  if not entry then
    self:CloseSilently()
    return
  end

  frame.Entry = entry
  frame.ItemShell.Entry = entry
  frame.Summary:SetText(string.format(
    "%d learnable appearance%s waiting. Review is read-only until you choose an action.",
    #entries,
    #entries == 1 and " is" or "s are"
  ))

  frame.Icon:SetTexture(entry.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
  frame.ItemName:SetText(entry.name or ("Item #" .. tostring(entry.itemID or "?")))
  setColor(frame.ItemName, getQualityColor(entry.quality))

  local qualityName = getQualityName(entry.quality)
  local reasonLabel = entry.reviewReason == "automatic-paused" and "AUTO paused" or "ASK rule"
  frame.ItemDetail:SetText(string.format(
    "%s | %s | Appearance #%s | Item #%s",
    qualityName,
    reasonLabel,
    tostring(entry.appearanceID or "?"),
    tostring(entry.itemID or "?")
  ))

  local upcoming = #entries - 1
  frame.QueueLabel:SetText(string.format("AVAILABLE AFTER THIS ITEM (%d)", upcoming))
  for rowIndex = 1, self.LAYOUT.queueRows do
    local queuedEntry = entries[rowIndex + 1]
    local row = frame.QueueRows[rowIndex]
    if queuedEntry then
      local extra = rowIndex == self.LAYOUT.queueRows and upcoming > self.LAYOUT.queueRows
        and (" | +" .. tostring(upcoming - self.LAYOUT.queueRows) .. " more")
        or ""
      row:SetText(string.format(
        "NEXT %d | %s | %s%s",
        rowIndex,
        queuedEntry.name or ("Item #" .. tostring(queuedEntry.itemID or "?")),
        getQualityName(queuedEntry.quality),
        extra
      ))
      setColor(row, getQualityColor(queuedEntry.quality))
    elseif rowIndex == 1 then
      row:SetText("No other appearances are waiting.")
      setColor(row, Theme.colors.muted)
    else
      row:SetText("")
    end
  end

  if entry.reviewReason == "automatic-paused" then
    frame.Warning:SetText("This item is set to AUTO, but automatic learning is currently off.")
  else
    frame.Warning:SetText("This quality is set to ASK. Nothing is bound until you choose.")
  end

  local upperQuality = string.upper(qualityName)
  frame.AutoButton:SetText("AUTO " .. upperQuality)
  frame.Explanation:SetText(string.format(
    "LEARN ONCE affects only this item. AUTO %s sets every %s item to AUTO and enables automatic learning. NEVER ITEM blacklists this item ID. LATER ALL or x defers this review queue for this login.",
    upperQuality,
    qualityName
  ))
end

function Prompt:Open(entry)
  if not entry then
    return false
  end

  local frame = self:EnsureFrame()
  frame.Entry = entry
  frame:Show()
  self:Refresh()
  if frame.Raise then
    frame:Raise()
  end
  return true
end

function Prompt:CloseSilently()
  local frame = self.frame
  if not frame then
    return
  end

  frame.Entry = nil
  frame.ItemShell.Entry = nil
  frame.APSilentHide = true
  frame:Hide()
  frame.APSilentHide = false
end
