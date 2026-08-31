local _, AP = ...
AP = AP or _G.Levo or _G.WotLKPlus or _G.AscensionPlus

local Registry = AP.ConfigRegistry
local Parser = AP.TalentImport.BuildParser
local Planner = AP.TalentImport.BuildPlanner
local Adapter = AP.TalentImport.AscensionAdapter
local Window = AP.TalentImport.ImportWindow

local Runtime = {
  enabled = false,
  lastStatus = "Open the Ascension talent tree to import a max-level build.",
  confirmationDelay = 0.12,
  confirmationTimeout = 1.20,
}
AP.TalentImport.Runtime = Runtime

local function now()
  return type(GetTime) == "function" and GetTime() or 0
end

local function inCombat()
  return type(InCombatLockdown) == "function" and InCombatLockdown() and true or false
end

local function shortList(entries, formatter)
  local parts = {}
  local limit = math.min(#entries, 5)
  for index = 1, limit do
    parts[#parts + 1] = formatter(entries[index])
  end
  if #entries > limit then
    parts[#parts + 1] = string.format("and %d more", #entries - limit)
  end
  return table.concat(parts, ", ")
end

function Runtime:Print(message)
  AP:Print(message)
end

function Runtime:SetStatus(message, color)
  self.lastStatus = tostring(message or "")
  Window:SetReport(self.lastStatus, color or "muted")
end

function Runtime:GetStatusText()
  if self.session then
    return string.format("Importing requested talent ranks: %d confirmed this run.", self.session.applied or 0)
  end
  return self.lastStatus
end

function Runtime:Describe(build, analysis, prefix)
  local lines = {
    prefix or "MAX-LEVEL BUILD ANALYSIS",
    string.format("Requested targets: %d | Visible matches: %d | Already satisfied: %d", #build.targets, analysis.matched, analysis.satisfied),
  }
  if analysis.ready then
    local entry = analysis.ready.entry
    lines[#lines + 1] = string.format(
      "Next affordable: %s (%d/%d -> target %d)",
      entry.name,
      analysis.ready.currentRank,
      entry.maxRank,
      analysis.ready.targetRank
    )
  elseif analysis.satisfied == #build.targets then
    lines[#lines + 1] = "Every requested rank already appears in the native preview."
  else
    lines[#lines + 1] = "No further requested rank is currently enabled by the native talent tree."
  end
  if #analysis.missing > 0 then
    lines[#lines + 1] = "Not visible in this tree: " .. shortList(analysis.missing, function(target)
      return "#" .. tostring(target.id)
    end)
  end
  if #analysis.blocked > 0 then
    lines[#lines + 1] = "Waiting on points or prerequisites: " .. shortList(analysis.blocked, function(target)
      return "#" .. tostring(target.id) .. " (" .. tostring(target.currentRank) .. "/" .. tostring(target.targetRank) .. ")"
    end)
  end
  return table.concat(lines, "\n")
end

function Runtime:ParseBuild(text)
  local build, reason = Parser:Parse(text)
  if not build then
    self:SetStatus(reason, "red")
    return nil, reason
  end
  AP.Database:Set("talentImport.lastBuild", build.source)
  return build
end

function Runtime:GetCatalog()
  local available, reason = Adapter:IsAvailable()
  if not available then
    return nil, reason
  end
  return Adapter:GetCatalog()
end

function Runtime:Analyze(text)
  local build, reason = self:ParseBuild(text)
  if not build then
    return false, reason
  end
  local catalog, catalogError = self:GetCatalog()
  if not catalog then
    self:SetStatus(catalogError, "red")
    return false, catalogError
  end
  local analysis = Planner:Analyze(build, catalog)
  self:SetStatus(self:Describe(build, analysis), analysis.ready and "gold" or "muted")
  return true, analysis
end

function Runtime:Cancel(reason)
  if not self.session then
    self:SetStatus(reason or "No max-level build import is running.", "muted")
    return false
  end
  self.session = nil
  self.pending = nil
  self:SetStatus(reason or "Max-level build import cancelled.", "muted")
  return true
end

function Runtime:Finish(build, analysis, color)
  local applied = self.session and self.session.applied or 0
  self.session = nil
  self.pending = nil
  local report = self:Describe(build, analysis, string.format("IMPORT COMPLETE: %d rank%s added to Ascension's preview", applied, applied == 1 and "" or "s"))
  self:SetStatus(report, color or "gold")
  self:Print(string.format("Max-level build import stopped after %d confirmed rank%s. Review Ascension's preview, then use its native Apply/Save action.", applied, applied == 1 and "" or "s"))
end

function Runtime:Process()
  local session = self.session
  if not session then
    return
  end
  if inCombat() then
    self:Cancel("Max-level build import stopped because combat started.")
    return
  end

  local currentTime = now()
  if self.pending then
    if currentTime < self.pending.checkAt then
      return
    end
    local catalog, catalogError = self:GetCatalog()
    if not catalog then
      self:Cancel(catalogError)
      return
    end
    local updated = catalog[self.pending.id]
    if updated and updated.rank > self.pending.beforeRank then
      session.applied = session.applied + 1
      self.pending = nil
      session.nextActionAt = currentTime + self.confirmationDelay
      return
    end
    if currentTime >= self.pending.deadline then
      self:Cancel("The native talent tree did not confirm the last requested rank. No further talent was clicked.")
      return
    end
    self.pending.checkAt = currentTime + 0.08
    return
  end

  if currentTime < (session.nextActionAt or 0) then
    return
  end

  local catalog, catalogError = self:GetCatalog()
  if not catalog then
    self:Cancel(catalogError)
    return
  end
  local action, analysis = Planner:Next(session.build, catalog)
  if not action then
    self:Finish(session.build, analysis, analysis.satisfied == #session.build.targets and "green" or "muted")
    return
  end

  local spent, spendError = Adapter:Spend(action.entry)
  if not spent then
    self:Cancel("Could not add the next requested rank: " .. tostring(spendError))
    return
  end
  self.pending = {
    id = action.id,
    beforeRank = action.currentRank,
    checkAt = currentTime + self.confirmationDelay,
    deadline = currentTime + self.confirmationTimeout,
  }
end

function Runtime:Start(text)
  if self.session then
    self:SetStatus("A max-level build import is already waiting for native confirmation.", "muted")
    return false
  elseif inCombat() then
    self:SetStatus("Leave combat before importing a talent build.", "red")
    return false
  end

  local build, reason = self:ParseBuild(text)
  if not build then
    return false, reason
  end
  local catalog, catalogError = self:GetCatalog()
  if not catalog then
    self:SetStatus(catalogError, "red")
    return false, catalogError
  end
  local action, analysis = Planner:Next(build, catalog)
  if not action then
    self:SetStatus(self:Describe(build, analysis), "muted")
    return false, "no-affordable-ranks"
  end

  self.session = {
    build = build,
    applied = 0,
    nextActionAt = now(),
  }
  self:SetStatus(self:Describe(build, analysis, "IMPORTING AFFORDABLE RANKS"), "gold")
  self:Process()
  return true
end

function Runtime:CreateButton()
  if self.button then
    return self.button
  end
  local button = CreateFrame("Button", "LevoTalentImportMaxLevelButton", UIParent)
  button:SetWidth(176)
  button:SetHeight(24)
  button:SetText("IMPORT MAX LEVEL BUILD")
  button:RegisterForClicks("LeftButtonUp")
  local theme = AP.UI.Theme
  theme:SkinButton(button)
  button:SetScript("OnClick", function()
    Window:Open()
  end)
  button:SetScript("OnEnter", function(control)
    if not AP.Database:Get("talentImport.showTooltips", true) then
      return
    end
    if not GameTooltip then
      return
    end
    GameTooltip:SetOwner(control, "ANCHOR_TOP")
    GameTooltip:AddLine("IMPORT MAX LEVEL BUILD", theme.colors.gold[1], theme.colors.gold[2], theme.colors.gold[3])
    GameTooltip:AddLine("Paste a full Ascension build. Levo follows its declared order and adds only ranks currently enabled by the native talent tree.", theme.colors.text[1], theme.colors.text[2], theme.colors.text[3], true)
    GameTooltip:AddLine("The native Ascension preview remains in control. Review it and use its Apply/Save action to commit.", theme.colors.muted[1], theme.colors.muted[2], theme.colors.muted[3], true)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function()
    if GameTooltip then
      GameTooltip:Hide()
    end
  end)
  self.button = button
  return button
end

function Runtime:AttachButton()
  local button = self:CreateButton()
  if not self.enabled or not AP.Database:Get("talentImport.showButton", true) then
    button:Hide()
    return false
  end

  local native = _G.CoATalentFrameTreeViewBottomBarImportBuildButton
  local treeView = Adapter:GetTreeView()
  if native and native.GetParent then
    button:SetParent(native:GetParent())
    button:ClearAllPoints()
    button:SetPoint("RIGHT", native, "LEFT", -6, 0)
    button:SetHeight(math.max(native:GetHeight() or 0, 22))
    button:SetFrameLevel((native:GetFrameLevel() or 1) + 2)
    if not native.IsShown or native:IsShown() then
      button:Show()
    else
      button:Hide()
    end
    return true
  elseif treeView then
    button:SetParent(treeView)
    button:ClearAllPoints()
    button:SetPoint("BOTTOMRIGHT", treeView, "BOTTOMRIGHT", -20, 12)
    button:SetFrameLevel((treeView:GetFrameLevel() or 1) + 10)
    if not treeView.IsShown or treeView:IsShown() then
      button:Show()
    else
      button:Hide()
    end
    return true
  end

  button:Hide()
  return false
end

function Runtime:CreateDriver()
  if self.driver then
    return
  end
  local driver = CreateFrame("Frame")
  driver:SetScript("OnEvent", function(_, event)
    if event == "ADDON_LOADED" or event == "PLAYER_LOGIN" then
      self.nextAttachAt = 0
    elseif self.session then
      self.nextProcessAt = 0
    end
  end)
  driver:SetScript("OnUpdate", function(_, elapsed)
    if not self.enabled then
      return
    end
    self.attachElapsed = (self.attachElapsed or 0) + elapsed
    if self.attachElapsed >= 0.75 then
      self.attachElapsed = 0
      self:AttachButton()
    end
    self:Process()
  end)
  driver:RegisterEvent("PLAYER_LOGIN")
  driver:RegisterEvent("ADDON_LOADED")
  driver:RegisterEvent("PLAYER_REGEN_DISABLED")
  pcall(driver.RegisterEvent, driver, "CHARACTER_ADVANCEMENT_PENDING_BUILD_UPDATED")
  pcall(driver.RegisterEvent, driver, "CHARACTER_ADVANCEMENT_UPDATE_ENTRIES_RESULT")
  self.driver = driver
end

function Runtime:Enable()
  if self.enabled then
    return
  end
  self.enabled = true
  self:CreateDriver()
  self:AttachButton()
end

function Runtime:Disable()
  self:Cancel("Max-level build import disabled.")
  self.enabled = false
  if self.button then
    self.button:Hide()
  end
  if Window.frame then
    Window.frame:Hide()
  end
end

AP.Modules:Register("talentImport", {
  order = 36,
  enabledPath = "modules.talentImport",

  OnInitialize = function()
    Registry:RegisterPage({
      id = "talents",
      title = "Talents",
      order = 38,
      description = "Build import tools. Ascension-specific controls activate only when its Character Advancement tree is available.",
      searchText = "talents talent tree build import ascension max level affordable prerequisite preview rank character advancement",
      options = function()
        return {
          {
            type = "toggle",
            path = "modules.talentImport",
            label = "Enable talent import",
            description = "Attach Levo's max-level build importer when a supported talent tree opens.",
            onChange = function()
              AP.Modules:RefreshStates()
            end,
          },
          {
            type = "text",
            label = "Current state",
            text = function()
              return Runtime:GetStatusText()
            end,
          },
        }
      end,
    })

    Registry:RegisterPage({
      id = "talents.import",
      parent = "talents",
      title = "Import Max Level Build",
      order = 10,
      description = "Import a full build while spending only ranks the currently open talent tree permits at your present level and point budget.",
      searchText = "import max level build ascension talent tree entry id rank affordable level prerequisite preview apply save button",
      options = function()
        return {
          {
            type = "section",
            label = "Import safety",
            description = "Levo parses Ascension ':EntryIDtRank' strings, keeps their declared priority, and asks the native tree which requested rank is currently enabled. It waits for native confirmation after every click and never spends a rank that was not present in the pasted build.",
          },
          {
            type = "toggle",
            path = "talentImport.showButton",
            label = "Show IMPORT MAX LEVEL BUILD button",
            description = "Place Levo's import button immediately beside Ascension's native Import Build control whenever that control is available.",
            onChange = function()
              Runtime:AttachButton()
            end,
          },
          {
            type = "toggle",
            path = "talentImport.showTooltips",
            label = "Show talent import tooltips",
            description = "Show an explanation when hovering the talent-tree import button.",
          },
          {
            type = "status",
            label = "Importer status",
            value = function()
              return Runtime.session and "RUNNING" or "READY"
            end,
            description = function()
              return Runtime:GetStatusText()
            end,
            color = function()
              return Runtime.session and "gold" or "muted"
            end,
          },
          {
            type = "button",
            label = "Open build importer",
            buttonText = "Open Importer",
            description = "Paste or review an Ascension max-level build string and preview the ranks that are currently affordable.",
            action = function()
              Window:Open()
            end,
          },
          {
            type = "button",
            label = "Cancel active import",
            buttonText = "Cancel Import",
            description = "Stop immediately. The existing native preview is left intact so you can review or reset it yourself.",
            action = function()
              Runtime:Cancel("Max-level build import cancelled from configuration.")
            end,
          },
        }
      end,
    })
  end,

  OnEnable = function()
    Runtime:Enable()
  end,

  OnDisable = function()
    Runtime:Disable()
  end,
})
