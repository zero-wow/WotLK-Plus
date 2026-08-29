local _, AP = ...
AP = AP or _G.AscensionPlus

local Categories = AP.Banking.Categories

local function appendToggleOptions(options, entries, pathPrefix, description)
  for index = 1, #entries do
    local entry = entries[index]
    options[#options + 1] = {
      type = "toggle",
      path = pathPrefix .. entry.key,
      label = entry.title,
      description = type(description) == "function" and description(entry) or description,
      onChange = Categories.configChanged,
    }
  end
end

local function appendQualityOptions(options, categoryID)
  for index = 1, #Categories.qualityOptions do
    local quality = Categories.qualityOptions[index]
    options[#options + 1] = {
      type = "toggle",
      path = "banking.categories." .. categoryID .. ".qualities." .. quality.key,
      label = "Allow " .. quality.title,
      description = "Only " .. quality.title .. " items that also match this category's type rules can be transferred.",
      onChange = Categories.configChanged,
    }
  end
end

local function enabledToggle(categoryID, label)
  return {
    type = "toggle",
    path = "banking.categories." .. categoryID .. ".enabled",
    label = label,
    description = "Disable this entire transfer category without changing its detailed rules.",
    onChange = Categories.configChanged,
  }
end

function Categories:RegisterConfigPages(registry, onChanged)
  self.configChanged = function()
    if type(onChanged) == "function" then
      onChanged()
    end
  end

  registry:RegisterPage({
    id = "banking.categories",
    parent = "banking",
    title = "Categories",
    order = 20,
    description = "Edit what the six filtered transfer buttons recognize and which hard exclusions also remain protected from All.",
    searchText = "bank categories classification all everything boe bind on equip unbound materials reagents gear recipe other food grey poor quality blacklist personal realm bank item",
    options = function()
      return {
        {
          type = "section",
          label = "Exclusive classification",
          description = "Materials, Reagents, Gear, Recipe, and Other remain exclusive. BoE is an independent live binding filter and may overlap Gear. Disabled types and qualities are left untouched.",
        },
        {
          type = "text",
          label = "Safe defaults",
          text = "Poor (grey) quality is disabled for every category. Food & Drink and every other Consumable subclass are disabled under Other until you explicitly enable them. Server-specific bank access items are protected when that extension is available.",
        },
        {
          type = "text",
          label = "How All differs",
          text = "All intentionally bypasses category, type, subclass, and quality choices. It still respects the hard item blacklist below and protected server-specific bank access items.",
        },
      }
    end,
  })

  registry:RegisterPage({
    id = "banking.categories.boe",
    parent = "banking.categories",
    title = "BoE",
    order = 15,
    description = "Transfer only currently unbound Bind-on-Equip items detected from their live source-slot tooltip.",
    searchText = "boe bind on equip unbound soulbound binding quality inventory bank guild personal realm",
    options = function()
      local options = {
        enabledToggle("boe", "Enable BoE transfers"),
        {
          type = "section",
          label = "Live binding safety",
          description = "An item must explicitly say 'Binds when equipped' in its current bag or bank slot. Soulbound, account-bound, realm-bound, quest-bound, and unreadable items fail closed.",
        },
        { type = "section", label = "Allowed qualities", description = "Poor (grey) BoE items are off by default." },
      }
      appendQualityOptions(options, "boe")
      return options
    end,
  })

  registry:RegisterPage({
    id = "banking.categories.materials",
    parent = "banking.categories",
    title = "Materials",
    order = 10,
    description = "Choose raw Trade Goods subclasses, Gems, and qualities recognized by Materials.",
    searchText = "materials raw gems parts jewelcrafting cloth leather metal stone meat herb elemental enchanting explosive device quality",
    options = function()
      local options = {
        enabledToggle("materials", "Enable Materials transfers"),
        {
          type = "toggle",
          path = "banking.categories.materials.includeGems",
          label = "Include Gems",
          description = "Treat Gem-class items as Materials when their quality is also enabled.",
          onChange = Categories.configChanged,
        },
        {
          type = "section",
          label = "Trade Goods subclasses",
          description = "Enchanting rods remain protected from Materials even when Enchanting inputs are enabled.",
        },
      }
      appendToggleOptions(options, Categories.materialOptions, "banking.categories.materials.", function(entry)
        return entry.default and "Recognize this Trade Goods subclass as Materials." or "Off by default because this subclass commonly contains finished or ambiguous items."
      end)
      options[#options + 1] = { type = "section", label = "Allowed qualities", description = "Poor (grey) is off by default." }
      appendQualityOptions(options, "materials")
      options[#options + 1] = {
        type = "text",
        label = "Current Materials rules",
        text = function()
          return Categories:GetMaterialsSummary()
        end,
      }
      return options
    end,
  })

  registry:RegisterPage({
    id = "banking.categories.reagents",
    parent = "banking.categories",
    title = "Reagents",
    order = 20,
    description = "Control Reagent-class transfers and their allowed qualities.",
    searchText = "reagents reagent class poor grey common green blue epic legendary heirloom quality",
    options = function()
      local options = {
        enabledToggle("reagents", "Enable Reagents transfers"),
        {
          type = "section",
          label = "Client classification",
          description = "Reagents accepts only items whose client item class is Reagent; no Consumables or Trade Goods are inferred as Reagents.",
        },
        { type = "section", label = "Allowed qualities", description = "Poor (grey) is off by default." },
      }
      appendQualityOptions(options, "reagents")
      return options
    end,
  })

  registry:RegisterPage({
    id = "banking.categories.gear",
    parent = "banking.categories",
    title = "Gear",
    order = 30,
    description = "Choose which equippable client classes and qualities are recognized as Gear.",
    searchText = "gear weapon armor equippable bags containers quiver grey poor quality",
    options = function()
      local options = {
        enabledToggle("gear", "Enable Gear transfers"),
        {
          type = "section",
          label = "Equippable types",
          description = "Weapons and Armor are enabled. Equippable bags, quivers, and custom equippable classes remain off until selected.",
        },
      }
      appendToggleOptions(options, Categories.gearOptions, "banking.categories.gear.", "Recognize this equippable type as Gear.")
      options[#options + 1] = { type = "section", label = "Allowed qualities", description = "Poor (grey) gear is off by default." }
      appendQualityOptions(options, "gear")
      return options
    end,
  })

  registry:RegisterPage({
    id = "banking.categories.recipe",
    parent = "banking.categories",
    title = "Recipe",
    order = 40,
    description = "Choose Recipe subclasses and qualities recognized by Recipe.",
    searchText = "recipe plans patterns schematics book alchemy blacksmith cooking enchanting engineering tailoring quality",
    options = function()
      local options = {
        enabledToggle("recipe", "Enable Recipe transfers"),
        {
          type = "section",
          label = "Recipe subclasses",
          description = "Known professions are enabled; unknown or custom subclasses are off until explicitly allowed.",
        },
      }
      appendToggleOptions(options, Categories.recipeOptions, "banking.categories.recipe.", "Recognize this Recipe subclass.")
      options[#options + 1] = { type = "section", label = "Allowed qualities", description = "Poor (grey) is off by default." }
      appendQualityOptions(options, "recipe")
      return options
    end,
  })

  registry:RegisterPage({
    id = "banking.categories.other",
    parent = "banking.categories",
    title = "Other",
    order = 50,
    description = "Choose non-gear classes, individual Consumable subclasses, and qualities recognized by Other.",
    searchText = "other food drink consumable potion elixir flask bandage scroll container projectile generic money quest key miscellaneous glyph quality",
    options = function()
      local options = {
        enabledToggle("other", "Enable Other transfers"),
        {
          type = "section",
          label = "Non-consumable classes",
          description = "Items already claimed by Gear, Recipe, Reagents, or enabled Materials rules cannot duplicate into Other.",
        },
      }
      appendToggleOptions(options, Categories.otherOptions, "banking.categories.other.", "Recognize this otherwise-unclaimed client item class under Other.")
      options[#options + 1] = {
        type = "section",
        label = "Consumable subclasses",
        description = "All Consumables, including Food & Drink, default OFF. Enable only the exact subclasses you want Other to transfer.",
      }
      appendToggleOptions(options, Categories.consumableOptions, "banking.categories.other.consumables.", "Recognize this Consumable subclass under Other.")
      options[#options + 1] = { type = "section", label = "Allowed qualities", description = "Poor (grey) is off by default." }
      appendQualityOptions(options, "other")
      options[#options + 1] = {
        type = "text",
        label = "Current Other rules",
        text = function()
          return Categories:GetOtherSummary()
        end,
      }
      return options
    end,
  })

  registry:RegisterPage({
    id = "banking.categories.exclusions",
    parent = "banking.categories",
    title = "Exclusions",
    order = 60,
    description = "Protect bank-access items and blacklist exact item IDs from every transfer category.",
    searchText = "category exclusions blacklist ignored drag item personal bank realm bank protect never deposit withdraw",
    options = function()
      return {
        {
          type = "toggle",
          path = "banking.categories.exclusions.protectBankAccessItems",
          label = "Protect server-specific bank items",
          description = "On supported servers, never transfer items whose name or client class identifies them as special bank access items.",
          onChange = Categories.configChanged,
        },
        {
          type = "blacklist",
          label = "Never transfer these items",
          description = "Drag an item here to exclude that item ID from All and every filtered button in both directions.",
          get = function()
            return Categories:GetIgnoredItemEntries()
          end,
          onAdd = function(itemID, itemLink)
            local added, reason = Categories:AddIgnoredItem(itemID, itemLink)
            if not added and reason then
              AP:Print(reason)
            end
            Categories.configChanged()
          end,
          onRemove = function(itemID)
            Categories:RemoveIgnoredItem(itemID)
            Categories.configChanged()
          end,
          onClear = function()
            Categories:ClearIgnoredItems()
            Categories.configChanged()
          end,
        },
      }
    end,
  })
end
