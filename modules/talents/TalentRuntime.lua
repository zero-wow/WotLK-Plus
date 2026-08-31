local _, AP = ...
AP = AP or _G.Levo or _G.WotLKPlus or _G.AscensionPlus

local Parser = AP.TalentImport.BuildParser
local Planner = AP.TalentImport.BuildPlanner
local Adapter = AP.TalentImport.AscensionAdapter
local Plan = AP.TalentImport.ProgressionPlan
local Window = AP.TalentImport.ImportWindow

local Runtime = {
  enabled = false,
  confirmationDelay = 0.12,
  confirmationTimeout = 1.20,
  lastStatus = "Open the Ascension talent tree to apply a max-level build.",
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

function Runtime:SetStatus(message, color, showReport)
  self.lastStatus = tostring(message or "")
  if showReport then
    Window:SetReport(self.lastStatus, color or "muted")
  end
end

function Runtime:GetStatusText()
  if self.session then
    return string.format("Applying requested talent ranks: %d confirmed this run.", self.session.applied or 0)
  end
  return self.lastStatus
end

function Runtime:GetProgressionSummary()
  return Plan:Summary()
end

function Runtime:Describe(build, analysis, prefix)
  local lines = {
    prefix or "MAX-LEVEL BUILD ANALYSIS",
    string.format("Requested: %d | Visible: %d | Already learned or previewed: %d", #build.targets, analysis.matched, analysis.satisfied),
  }
  if analysis.ready then
    local entry = analysis.ready.entry
    lines[#lines + 1] = string.format(
      "Next requested rank: %s (%d/%d -> target %d)",
      entry.name,
      analysis.ready.currentRank,
      entry.maxRank,
      analysis.ready.targetRank
    )
  elseif analysis.satisfied == #build.targets then
    lines[#lines + 1] = "Every requested rank is already learned or present in Ascension's preview."
  else
    lines[#lines + 1] = "No requested rank is currently learnable. The saved plan will wait for points or prerequisites."
  end
  if #analysis.available > 0 then
    lines[#lines + 1] = string.format("Additional requested ranks currently available: %d", #analysis.available)
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
    self:SetStatus(reason, "red", true)
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
  local catalog, catalogReason = Adapter:GetCatalog()
  if not catalog or not next(catalog) then
    return nil, catalogReason or "No Ascension talent entries are available yet."
  end
  return catalog
end

function Runtime:Analyze(text)
  local build, reason = self:ParseBuild(text)
  if not build then
    return false, reason
  end
  local catalog, catalogError = self:GetCatalog()
  if not catalog then
    self:SetStatus(catalogError, "red", true)
    return false, catalogError
  end
  local analysis = Planner:Analyze(build, catalog)
  self:SetStatus(self:Describe(build, analysis), analysis.ready and "gold" or "muted", true)
  return true, analysis
end

function Runtime:Cancel(reason, showReport)
  if not self.session then
    self:SetStatus(reason or "No talent application is running.", "muted", showReport)
    return false
  end
  self.session = nil
  self.pending = nil
  self:SetStatus(reason or "Talent application cancelled. The native preview was left unchanged.", "muted", showReport)
  return true
end

function Runtime:Finish(build, analysis, color)
  local session = self.session
  local applied = session and session.applied or 0
  self.session = nil
  self.pending = nil

  local prefix = string.format("APPLY COMPLETE: %d rank%s added to Ascension's preview", applied, applied == 1 and "" or "s")
  local report = self:Describe(build, analysis, prefix)
  if applied > 0 and session and session.commit then
    local committed, commitError = Adapter:CommitPreview()
    if committed then
      report = report .. "\nNative Apply/Save was invoked to commit the preview permanently."
    else
      report = report .. "\nPreview is ready, but native commit was not invoked: " .. tostring(commitError)
    end
  elseif applied > 0 then
    report = report .. "\nReview the native preview and use Ascension's Apply/Save control to commit it."
  end

  self:SetStatus(report, color or "gold", not (session and session.quiet))
  if session and not session.quiet then
    self:Print(string.format("Applied %d requested talent rank%s.", applied, applied == 1 and "" or "s"))
  end
end

function Runtime:Process()
  local session = self.session
  if not session then
    return
  end
  if inCombat() then
    self:Cancel("Talent application paused because combat started. It will retry after combat if the saved plan is armed.", not session.quiet)
    if session.progression then
      self:WakeProgression("combat ended")
    end
    return
  end

  local currentTime = now()
  if self.pending then
    if currentTime < self.pending.checkAt then
      return
    end
    local catalog, catalogError = self:GetCatalog()
    if not catalog then
      self:Cancel(catalogError, not session.quiet)
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
      self:Cancel("Ascension did not report a preview-rank change after the requested click. No further ranks were attempted.", not session.quiet)
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
    self:Cancel(catalogError, not session.quiet)
    return
  end
  local action, analysis = Planner:Next(session.build, catalog)
  if not action then
    self:Finish(session.build, analysis, analysis.satisfied == #session.build.targets and "green" or "muted")
    return
  end

  local spent, spendError = Adapter:Spend(action.entry)
  if not spent then
    self:Cancel("Could not add the next requested rank: " .. tostring(spendError), not session.quiet)
    return
  end
  self.pending = {
    id = action.id,
    beforeRank = action.currentRank,
    checkAt = currentTime + self.confirmationDelay,
    deadline = currentTime + self.confirmationTimeout,
  }
end

function Runtime:StartBuild(build, options)
  options = options or {}
  if not self.enabled then
    return false, "Talent import is disabled in Levo's configuration."
  end
  if self.session then
    return false, "A talent application is already waiting for Ascension confirmation."
  end
  if inCombat() then
    return false, "Leave combat before applying talent ranks."
  end

  local catalog, catalogError = self:GetCatalog()
  if not catalog then
    self:SetStatus(catalogError, "red", options.presentReport)
    return false, "talent-tree-unavailable"
  end
  local action, analysis = Planner:Next(build, catalog)
  if not action then
    self:SetStatus(self:Describe(build, analysis), "muted", options.presentReport)
    return false, "no-affordable-ranks"
  end

  self.session = {
    build = build,
    applied = 0,
    commit = options.commit and true or false,
    progression = options.progression and true or false,
    quiet = options.quiet and true or false,
    nextActionAt = now(),
  }
  self:SetStatus(self:Describe(build, analysis, "APPLYING AFFORDABLE REQUESTED RANKS"), "gold", options.presentReport)
  self:Process()
  return true
end

function Runtime:ApplyNow(text)
  local build, reason = self:ParseBuild(text)
  if not build then
    return false, reason
  end
  return self:StartBuild(build, {
    commit = true,
    presentReport = true,
  })
end

function Runtime:SaveAndApply(text)
  local build, reason = self:ParseBuild(text)
  if not build then
    return false, reason
  end
  Plan:Save(build.source)
  self:WakeProgression("saved progression build")
  local started, startReason = self:StartBuild(build, {
    commit = true,
    progression = true,
    presentReport = true,
  })
  if not started and startReason == "no-affordable-ranks" then
    self:SetStatus("SAVED PROGRESSION BUILD\n" .. self:GetProgressionSummary() .. " It will apply the next requested rank automatically after you gain points and are out of combat.", "gold", true)
    return true
  end
  return started, startReason
end

function Runtime:ClearProgression()
  Plan:Clear()
  self.progressionDue = false
  self:SetStatus("Saved progression build cleared.", "muted", true)
end

function Runtime:WakeProgression(reason)
  if not Plan:IsEnabled() then
    return
  end
  self.progressionDue = true
  self.progressionReason = reason or "new talent points"
  self.nextProgressionAt = 0
end

function Runtime:TryProgression()
  if self.session or not self.progressionDue or not Plan:IsEnabled() then
    return
  end
  if inCombat() then
    return
  end
  local currentTime = now()
  if currentTime < (self.nextProgressionAt or 0) then
    return
  end
  self.progressionDue = false

  local build, reason = Parser:Parse(Plan:GetBuild())
  if not build then
    Plan:Clear()
    self:SetStatus("Saved progression build was invalid and has been cleared: " .. tostring(reason), "red")
    return
  end
  local started, startReason = self:StartBuild(build, {
    commit = true,
    progression = true,
    quiet = true,
  })
  if not started and startReason == "talent-tree-unavailable" then
    self.progressionDue = true
    self.nextProgressionAt = currentTime + 3
  end
end

function Runtime:OnProgressionSettingChanged()
  if Plan:IsEnabled() then
    self:WakeProgression("progression setting enabled")
  else
    self.progressionDue = false
  end
end

function Runtime:CreateButton()
  if self.button then
    return self.button
  end
  local button = CreateFrame("Button", "LevoTalentImportMaxLevelButton", UIParent)
  button:SetWidth(26)
  button:SetHeight(24)
  button:RegisterForClicks("LeftButtonUp")
  local theme = AP.UI.Theme
  theme:SkinButton(button)
  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
  icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
  icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
  self.buttonIcon = icon
  button:SetScript("OnClick", function()
    Window:Open()
  end)
  button:SetScript("OnEnter", function(control)
    if not AP.Database:Get("talentImport.showTooltips", true) or not GameTooltip then
      return
    end
    GameTooltip:SetOwner(control, "ANCHOR_TOP")
    GameTooltip:AddLine("IMPORT MAX LEVEL BUILD", theme.colors.gold[1], theme.colors.gold[2], theme.colors.gold[3])
    GameTooltip:AddLine("Apply only requested ranks Ascension currently allows. SAVE & AUTO keeps the build armed for future talent points outside combat.", theme.colors.text[1], theme.colors.text[2], theme.colors.text[3], true)
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
    button:SetPoint("LEFT", native, "RIGHT", 4, 0)
    button:SetWidth(math.max(native:GetHeight() or 0, 22))
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
      self.attachElapsed = 0.75
      self:WakeProgression(event)
    elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_LEVEL_UP" or event == "CHARACTER_POINTS_CHANGED" or event == "PLAYER_TALENT_UPDATE" then
      self:WakeProgression(event)
    elseif event == "CHARACTER_ADVANCEMENT_PENDING_BUILD_UPDATED"
      or event == "CHARACTER_ADVANCEMENT_UPDATE_ENTRIES_RESULT"
      or event == "CHARACTER_ADVANCEMENT_KNOWN_ENTRIES_CHANGED"
      or event == "CHARACTER_ADVANCEMENT_LEARN_RESULT" then
      if not self.session then
        self:WakeProgression(event)
      end
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
    self:TryProgression()
  end)
  driver:RegisterEvent("PLAYER_LOGIN")
  driver:RegisterEvent("ADDON_LOADED")
  driver:RegisterEvent("PLAYER_REGEN_DISABLED")
  driver:RegisterEvent("PLAYER_REGEN_ENABLED")
  driver:RegisterEvent("PLAYER_LEVEL_UP")
  pcall(driver.RegisterEvent, driver, "CHARACTER_POINTS_CHANGED")
  pcall(driver.RegisterEvent, driver, "PLAYER_TALENT_UPDATE")
  pcall(driver.RegisterEvent, driver, "CHARACTER_ADVANCEMENT_PENDING_BUILD_UPDATED")
  pcall(driver.RegisterEvent, driver, "CHARACTER_ADVANCEMENT_UPDATE_ENTRIES_RESULT")
  pcall(driver.RegisterEvent, driver, "CHARACTER_ADVANCEMENT_KNOWN_ENTRIES_CHANGED")
  pcall(driver.RegisterEvent, driver, "CHARACTER_ADVANCEMENT_LEARN_RESULT")
  self.driver = driver
end

function Runtime:Enable()
  if self.enabled then
    return
  end
  self.enabled = true
  self:CreateDriver()
  self:AttachButton()
  self:WakeProgression("talent import enabled")
end

function Runtime:Disable()
  self:Cancel("Talent import disabled.")
  self.enabled = false
  self.progressionDue = false
  if self.button then
    self.button:Hide()
  end
  if Window.frame then
    Window.frame:Hide()
  end
end
