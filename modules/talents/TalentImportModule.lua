local _, AP = ...
AP = AP or _G.Levo or _G.WotLKPlus or _G.AscensionPlus

local Registry = AP.ConfigRegistry
local Runtime = AP.TalentImport.Runtime
local Plan = AP.TalentImport.ProgressionPlan
local Window = AP.TalentImport.ImportWindow

AP.Modules:Register("talentImport", {
  order = 36,
  enabledPath = "modules.talentImport",

  OnInitialize = function()
    Registry:RegisterPage({
      id = "talents",
      title = "Talents",
      order = 38,
      description = "Build application tools. Ascension controls activate only while its Character Advancement tree is available.",
      searchText = "talents talent tree build import max level affordable permanent auto progression point level combat preview apply save character advancement",
      options = function()
        return {
          {
            type = "toggle",
            path = "modules.talentImport",
            label = "Enable talent import",
            description = "Attach Levo's max-level build tool when a supported talent tree opens.",
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
      description = "Apply only the requested ranks that Ascension currently permits, then optionally keep the build armed for future levels and talent points.",
      searchText = "import max level build ascension talent tree entry id rank affordable level prerequisite preview permanent auto apply save point out of combat",
      options = function()
        return {
          {
            type = "section",
            label = "Smart application",
            description = "APPLY NOW always spends only currently learnable requested ranks. After every rank, Levo waits for Ascension's pending preview rank before choosing the next one. When Ascension exposes its native Apply/Save control, Levo invokes it to commit the finished preview.",
          },
          {
            type = "toggle",
            path = "talentImport.showButton",
            label = "Show talent-tree import button",
            description = "Show Levo's compact Import Max-Level Build button beside Ascension's native Import Build control.",
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
            type = "toggle",
            path = "talentImport.progression.enabled",
            label = "Auto-apply saved progression build",
            description = "When a saved build exists, retry its next requested rank after login, level-up, new talent points, or leaving combat.",
            onChange = function()
              Runtime:OnProgressionSettingChanged()
            end,
          },
          {
            type = "status",
            label = "Importer status",
            value = function()
              return Runtime.session and "APPLYING" or "READY"
            end,
            description = function()
              return Runtime:GetStatusText()
            end,
            color = function()
              return Runtime.session and "gold" or "muted"
            end,
          },
          {
            type = "text",
            label = "Saved progression",
            text = function()
              return Plan:Summary()
            end,
          },
          {
            type = "button",
            label = "Open build importer",
            buttonText = "Open Importer",
            description = "Paste, analyze, apply now, or save a max-level build for automatic future progression.",
            action = function()
              Window:Open()
            end,
          },
          {
            type = "button",
            label = "Clear saved progression",
            buttonText = "Clear Plan",
            description = "Forget the saved automatic build. Existing native talents and previews are never removed.",
            action = function()
              Runtime:ClearProgression()
            end,
          },
          {
            type = "button",
            label = "Cancel active application",
            buttonText = "Cancel Apply",
            description = "Stop immediately. The current native preview remains available for review.",
            action = function()
              Runtime:Cancel("Talent application cancelled from configuration.", true)
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
