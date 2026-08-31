local _, AP = ...
AP = AP or _G.Levo or _G.WotLKPlus or _G.AscensionPlus

local Registry = AP.ConfigRegistry
local Banking = AP.Banking
local Categories = Banking.Categories
local Controller = Banking.Controller
local Sorter = Banking.Sorter
local Exclusions = Banking.SorterExclusions

local QUALITY_RULES = {
  { key = "poor", label = "Poor (Grey)", color = "muted" },
  { key = "common", label = "Common (White)", color = "text" },
  { key = "uncommon", label = "Uncommon (Green)", color = "green" },
  { key = "rare", label = "Rare (Blue)", color = "blue" },
  { key = "epic", label = "Epic (Purple)", color = "epic" },
  { key = "legendary", label = "Legendary (Orange)", color = "orange" },
  { key = "artifact", label = "Artifact", color = "gold" },
  { key = "heirloom", label = "Heirloom", color = "gold" },
}

local QUALITY_MODE_CHOICES = {
  { value = "normal", label = "Normal sort", color = "gold" },
  { value = "ignore", label = "Ignore completely", color = "red" },
  { value = "bottom", label = "Bottom-right", color = "blue" },
}

local INVENTORY_DESTINATIONS = {
  { value = "any", label = "Any eligible bag", color = "gold" },
  { value = "backpack", label = "Backpack", color = "gold" },
  { value = "bag1", label = "Bag 1", color = "gold" },
  { value = "bag2", label = "Bag 2", color = "gold" },
  { value = "bag3", label = "Bag 3", color = "gold" },
  { value = "bag4", label = "Bag 4", color = "gold" },
}

local CHARACTER_DESTINATIONS = {
  { value = "any", label = "Any eligible bank bag", color = "gold" },
  { value = "main", label = "Main Bank", color = "gold" },
  { value = "bag1", label = "Bank Bag 1", color = "gold" },
  { value = "bag2", label = "Bank Bag 2", color = "gold" },
  { value = "bag3", label = "Bank Bag 3", color = "gold" },
  { value = "bag4", label = "Bank Bag 4", color = "gold" },
  { value = "bag5", label = "Bank Bag 5", color = "gold" },
  { value = "bag6", label = "Bank Bag 6", color = "gold" },
  { value = "bag7", label = "Bank Bag 7", color = "gold" },
}

local function refreshModuleState()
  AP.Modules:RefreshStates()
end

local function refreshPanel()
  Controller:OnSettingsChanged()
end

local function refreshTransferPacing()
  Controller:OnPacingSettingsChanged()
end

local function refreshSorter()
  Sorter:OnSettingsChanged()
end

local function refreshSorterExclusions()
  Sorter:OnSettingsChanged(true)
end

local function addBagExclusionOptions(options, scope, count)
  local labels
  if scope == "inventory" then
    labels = { "Backpack", "Bag 1", "Bag 2", "Bag 3", "Bag 4" }
  else
    labels = { "Main Bank", "Bank Bag 1", "Bank Bag 2", "Bank Bag 3", "Bank Bag 4", "Bank Bag 5", "Bank Bag 6", "Bank Bag 7" }
  end

  for index = 1, count do
    local key = index == 1 and (scope == "inventory" and "backpack" or "main") or "bag" .. tostring(index - 1)
    options[#options + 1] = {
      type = "toggle",
      path = "banking.sorter.exclusions.bags." .. scope .. "." .. key,
      label = "Exclude " .. labels[index],
      description = "Keep every slot in " .. labels[index] .. " completely outside sort snapshots, sources, destinations, stacking, and final verification.",
      onChange = refreshSorterExclusions,
    }
  end
end

AP.Modules:Register("banking", {
  order = 27,
  enabledPath = "modules.banking",

  OnInitialize = function()
    Registry:RegisterPage({
      id = "banking",
      title = "Banking",
      order = 40,
      description = "Safe complete/category transfers, reports, and confirmed sorting for Inventory, Character, and Guild-style Banks.",
      searchText = "bank banking deposit all withdraw everything pretend report boe bind on equip unbound materials reagents gear recipe other guild character special server tab sort sorter elvui bagnon adibags",
      options = function()
        return {
          {
            type = "section",
            label = "Active bank",
            description = "The transfer panel follows the bank currently open. Guild-style banks use only the selected visible tab.",
          },
          {
            type = "text",
            label = "Transfer status",
            text = function()
              return Controller:GetStatusText()
            end,
          },
          {
            type = "text",
            label = "Sorter status",
            text = function()
              return Sorter:GetStatusText()
            end,
          },
        }
      end,
    })

    Registry:RegisterPage({
      id = "banking.deposit",
      parent = "banking",
      title = "Transfers",
      order = 10,
      description = "Configure Deposit, Withdraw, and PRETEND behavior on the attached transfer panel.",
      searchText = "deposit all everything withdraw pretend dry run report panel buttons boe bind on equip materials reagents gear recipe other chat tooltip cancel safety tab adaptive pacing pipeline speed stacks per second conservative backoff",
      options = function()
        return {
          {
            type = "section",
            label = "Transfer safety",
            description = "Transfers send distinct source stacks through a bounded adaptive pipeline and confirm every source independently from bank events. The default window sustains the target cadence even when the server reports changes late; delays or failures slow and shrink it immediately. Failed unchanged stacks are skipped, while cursor or persistent server-lock hazards stop safely. Transfers never spill into another guild-style tab.",
          },
          {
            type = "text",
            label = "All button",
            text = "All transfers every otherwise-transferable source stack and bypasses the six category/type/quality filters. Explicit Banking blacklist entries, protected server-specific access items, locked stacks, binding restrictions, and destination capacity are still enforced.",
          },
          {
            type = "toggle",
            path = "modules.banking",
            label = "Enable banking module",
            description = "Loads the transfer controller and attaches the panel when a supported bank opens.",
            onChange = refreshModuleState,
          },
          {
            type = "toggle",
            path = "banking.deposit.showPanel",
            label = "Show transfer panel at banks",
            description = "Attach the category button rail beside the currently open bank frame.",
            onChange = refreshPanel,
          },
          {
            type = "toggle",
            path = "banking.deposit.showTooltips",
            label = "Show button tooltips",
            description = "Explain the selected mode, each category, and the exact enabled contents of Materials and Other.",
          },
          {
            type = "toggle",
            path = "banking.deposit.showChatMessages",
            label = "Show transfer results in chat",
            description = "Report completion, skipped stacks, cancellation, and safety errors in chat.",
          },
          {
            type = "toggle",
            path = "banking.deposit.conservativePacing",
            label = "Use conservative adaptive pacing",
            description = "Default submits at 10 stacks/sec for Character and supported server-specific banks (8.3/sec for Guild Banks), pipelines up to 10 distinct stacks initially, and accelerates after repeated fast confirmations. Conservative mode starts with only three in flight and caps the ramp sooner. Either mode slows and shrinks the pipeline when the server delays or rejects a transfer.",
            onChange = refreshTransferPacing,
          },
          {
            type = "section",
            label = "PRETEND reports",
            description = "PRETEND never moves items. Clicking All or a filtered category audits both Inventory -> Bank and Bank -> Inventory, then opens a themed copyable report with every match and decision reason.",
          },
          {
            type = "button",
            label = "Cancel active transfer",
            buttonText = "Cancel Transfer",
            description = "Stops new submissions immediately. Cursorless requests already sent to the server may still complete; the status reports how many were in flight. Clicking the active category button also cancels.",
            action = function()
              Controller:Cancel("Transfer cancelled from configuration.")
            end,
          },
        }
      end,
    })

    Registry:RegisterPage({
      id = "banking.sorter",
      parent = "banking",
      title = "Sorter",
      order = 15,
      description = "Consolidate and sort Inventory, Character Bank, or a supported server-specific bank tab with event-confirmed adaptive pacing.",
      searchText = "inventory bags character bank sort sorter active tab consolidate stack adaptive pacing speed progress cancel button placement blizzard elvui bagnon adibags slash exclusions blacklist",
      options = function()
        return {
          {
            type = "section",
            label = "Confirmed-operation safety",
            description = "Inventory and Character Bank use only eligible general-purpose bags. Server-specific sorting remains limited to the visible tab. One move is submitted and confirmed before the next begins.",
          },
          {
            type = "toggle",
            path = "banking.sorter.enabled",
            label = "Enable Levo sorter",
            description = "Allow Levo to sort Inventory, Character Bank, and supported visible server-specific bank tabs.",
            onChange = refreshSorter,
          },
          {
            type = "toggle",
            path = "banking.sorter.showButton",
            label = "Show Levo sort buttons",
            description = "Attach Levo controls to supported visible inventory and bank UIs. Configuration and /lv sort remain available when hidden.",
            onChange = refreshSorter,
          },
          {
            type = "toggle",
            path = "banking.sorter.preferNativeAnchor",
            label = "Place beside the host sort button",
            description = "Prefer a detected ElvUI, Bagnon, AdiBags, or Blizzard sort control. Levo is placed immediately left of the host control and never replaces it.",
            onChange = refreshSorter,
          },
          {
            type = "toggle",
            path = "banking.sorter.conservativePacing",
            label = "Use conservative adaptive pacing",
            description = "Start slightly slower and cap around 10 confirmed operations per second. Default pacing starts near 8.3/sec and may cautiously rise to 13.3/sec after repeated fast confirmations.",
            onChange = refreshSorter,
          },
          {
            type = "toggle",
            path = "banking.sorter.showChatMessages",
            label = "Show sorter results in chat",
            description = "Report plans, completion, cancellation, stale data, locks, and safety stops in chat.",
          },
          {
            type = "section",
            label = "Control and progress",
            description = "Contextual start prefers an open supported server-specific tab, then an open Character Bank, then Inventory. Cancel waits for an already-submitted move and never destroys a cursor item.",
          },
          {
            type = "text",
            label = "Current status",
            text = function()
              return Sorter:GetStatusText()
            end,
          },
          {
            type = "text",
            label = "Last safety stop",
            text = function()
              return Sorter:GetLastErrorText()
            end,
          },
          {
            type = "button",
            label = "Sort current context",
            buttonText = "Sort Current",
            description = "Sort the open supported server-specific tab, otherwise the open Character Bank, otherwise Inventory.",
            action = function()
              Sorter:Start()
            end,
          },
          {
            type = "button",
            label = "Sort Inventory directly",
            buttonText = "Sort Inventory",
            description = "Build a fresh snapshot containing only movable slots from enabled general-purpose carried bags.",
            action = function()
              Sorter:Start("inventory")
            end,
          },
          {
            type = "button",
            label = "Sort Character Bank directly",
            buttonText = "Sort Bank",
            description = "Sort the open Character Bank while respecting item, bank-bag, and specialty-bag exclusions.",
            action = function()
              Sorter:Start("character")
            end,
          },
          {
            type = "button",
            label = "Cancel active sort",
            buttonText = "Cancel Sort",
            description = "Stop after the currently submitted server move confirms. No additional move will be queued.",
            action = function()
              Sorter:Cancel("Sorting cancelled from configuration.")
            end,
          },
          {
            type = "text",
            label = "Universal command",
            text = "Use /lv sort for the current context; /lv sort inventory, /lv sort bank, or /lv sort keeper for an explicit target; /lv sort cancel stops safely.",
          },
        }
      end,
    })

    Registry:RegisterPage({
      id = "banking.sorter.qualityRules",
      parent = "banking.sorter",
      title = "Quality Rules",
      order = 5,
      description = "Control exactly how each item quality participates in sorting. Rules are applied to the snapshot before any move is planned.",
      searchText = "sort quality rarity poor grey common white uncommon green rare blue epic purple legendary orange artifact heirloom ignore exclude bottom right destination specific bag inventory bank reserve",
      options = function()
        local options = {
          {
            type = "section",
            label = "Quality handling",
            description = "IGNORE completely removes that quality from snapshots, stacking, destinations, and verification. BOTTOM-RIGHT places it after normal items. A selected destination reserves that entire eligible bag for that quality; it wins over Bottom-right and stops before moving anything when capacity is insufficient.",
          },
          {
            type = "text",
            label = "Server-specific Keeper Banks",
            text = "Keeper Banks use the active tab as one slot area. Quality mode applies there, but Inventory and Character Bank destinations are intentionally ignored because those banks have no bag containers.",
          },
        }

        for index = 1, #QUALITY_RULES do
          local quality = QUALITY_RULES[index]
          local root = "banking.sorter.qualityRules." .. quality.key
          options[#options + 1] = {
            type = "select",
            path = root .. ".mode",
            label = quality.label .. " placement",
            description = "Choose whether " .. quality.label .. " items sort normally, remain completely untouched, or collect at the bottom-right of the available area.",
            choices = QUALITY_MODE_CHOICES,
            onChange = refreshSorterExclusions,
          }
          options[#options + 1] = {
            type = "select",
            path = root .. ".inventoryDestination",
            label = quality.label .. " Inventory destination",
            description = "Reserve one eligible carried bag exclusively for this quality. Leave this at Any eligible bag for normal cross-bag sorting.",
            choices = INVENTORY_DESTINATIONS,
            onChange = refreshSorterExclusions,
          }
          options[#options + 1] = {
            type = "select",
            path = root .. ".characterDestination",
            label = quality.label .. " Character Bank destination",
            description = "Reserve one eligible Character Bank area exclusively for this quality. This has no effect on Keeper Bank tabs.",
            choices = CHARACTER_DESTINATIONS,
            onChange = refreshSorterExclusions,
          }
        end
        return options
      end,
    })

    Registry:RegisterPage({
      id = "banking.sorter.exclusions",
      parent = "banking.sorter",
      title = "Exclusions",
      order = 10,
      description = "Protect individual items and complete bags from every sorter calculation and move.",
      searchText = "sort exclusions blacklist blocked ignored items drag bag backpack bank specialty immutable source destination",
      options = function()
        local options = {
          {
            type = "section",
            label = "Hard exclusion behavior",
            description = "Excluded item slots and excluded bags are removed before planning. AP cannot stack into them, move out of them, use them as empty destinations, or count them during final verification. Specialty bags are always excluded for compatibility safety.",
          },
          {
            type = "blacklist",
            label = "Protected items",
            description = "Drag an item here to freeze every matching item slot in Inventory, Character Bank, and supported server-specific bank sorts.",
            get = function()
              return Exclusions:GetItemEntries()
            end,
            onAdd = function(itemID, itemLink)
              local added, reason = Exclusions:AddItem(itemID, itemLink)
              if not added and reason then
                AP:Print(reason)
              end
              refreshSorterExclusions()
            end,
            onRemove = function(itemID)
              Exclusions:RemoveItem(itemID)
              refreshSorterExclusions()
            end,
            onClear = function()
              Exclusions:ClearItems()
              refreshSorterExclusions()
            end,
          },
          {
            type = "section",
            label = "Inventory bags",
            description = "Exclude a whole carried bag when its contents must retain exact slot positions.",
          },
        }

        addBagExclusionOptions(options, "inventory", 5)
        options[#options + 1] = {
          type = "section",
          label = "Character Bank bags",
          description = "Exclude the main bank area or any purchased bank bag from Character Bank sorting.",
        }
        addBagExclusionOptions(options, "character", 8)
        return options
      end,
    })

    Categories:RegisterConfigPages(Registry, function()
      if Controller.processing then
        Controller:Cancel("Transfer cancelled because category rules changed.")
      end
      Controller:OnSettingsChanged()
    end)
  end,

  OnEnable = function()
    Controller:Enable()
    Sorter:Enable()
  end,

  OnDisable = function()
    Sorter:Disable()
    Controller:Disable()
  end,
})
