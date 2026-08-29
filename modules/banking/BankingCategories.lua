local _, AP = ...
AP = AP or _G.AscensionPlus

AP.Banking = AP.Banking or {}
local Banking = AP.Banking

local Categories = {
  order = { "all", "boe", "materials", "reagents", "gear", "recipe", "other" },
  definitions = {
    all = {
      title = "All",
      summary = "Every transferable stack in the source. Category, type, subclass, and quality filters are bypassed; explicit Banking exclusions and bank restrictions remain enforced.",
    },
    boe = {
      title = "BoE",
      summary = "Currently unbound items whose live source-slot tooltip explicitly says Binds when equipped.",
    },
    materials = {
      title = "Materials",
      summary = "Enabled raw-material Trade Goods subclasses and, optionally, Gems.",
    },
    reagents = {
      title = "Reagents",
      summary = "Enabled Reagent-class items that pass the Reagents quality rules.",
    },
    gear = {
      title = "Gear",
      summary = "Enabled equippable item classes that pass the Gear quality rules.",
    },
    recipe = {
      title = "Recipe",
      summary = "Enabled Recipe subclasses that pass the Recipe quality rules.",
    },
    other = {
      title = "Other",
      summary = "Enabled non-gear classes and consumable subclasses not claimed by another button.",
    },
  },
  qualityOptions = {
    { key = "poor", id = 0, title = "Poor (Grey)", default = false },
    { key = "common", id = 1, title = "Common (White)", default = true },
    { key = "uncommon", id = 2, title = "Uncommon (Green)", default = true },
    { key = "rare", id = 3, title = "Rare (Blue)", default = true },
    { key = "epic", id = 4, title = "Epic (Purple)", default = true },
    { key = "legendary", id = 5, title = "Legendary (Orange)", default = true },
    { key = "artifact", id = 6, title = "Artifact", default = true },
    { key = "heirloom", id = 7, title = "Heirloom", default = true },
  },
  materialOptions = {
    { key = "parts", title = "Parts", default = true },
    { key = "jewelcrafting", title = "Jewelcrafting", default = true },
    { key = "cloth", title = "Cloth", default = true },
    { key = "leather", title = "Leather", default = true },
    { key = "metalStone", title = "Metal & Stone", default = true },
    { key = "meat", title = "Raw Meat", default = true },
    { key = "herb", title = "Herbs", default = true },
    { key = "elemental", title = "Elemental", default = true },
    { key = "enchanting", title = "Enchanting", default = true },
    { key = "materials", title = "Materials", default = true },
    { key = "tradeGoods", title = "Generic Trade Goods", default = false },
    { key = "explosives", title = "Explosives", default = false },
    { key = "devices", title = "Devices", default = false },
    { key = "other", title = "Trade Goods: Other", default = false },
    { key = "armorEnchantment", title = "Armor Enchantments", default = false },
    { key = "weaponEnchantment", title = "Weapon Enchantments", default = false },
    { key = "unknown", title = "Unknown Trade Goods subclasses", default = false },
  },
  gearOptions = {
    { key = "weapons", classKey = "weapon", title = "Weapons", default = true },
    { key = "armor", classKey = "armor", title = "Armor", default = true },
    { key = "containers", classKey = "container", title = "Equippable Containers", default = false },
    { key = "quivers", classKey = "quiver", title = "Equippable Quivers", default = false },
    { key = "otherEquippable", classKey = "other", title = "Other Equippable Items", default = false },
  },
  recipeOptions = {
    { key = "book", title = "Books", default = true },
    { key = "leatherworking", title = "Leatherworking", default = true },
    { key = "tailoring", title = "Tailoring", default = true },
    { key = "engineering", title = "Engineering", default = true },
    { key = "blacksmithing", title = "Blacksmithing", default = true },
    { key = "cooking", title = "Cooking", default = true },
    { key = "alchemy", title = "Alchemy", default = true },
    { key = "firstAid", title = "First Aid", default = true },
    { key = "enchanting", title = "Enchanting", default = true },
    { key = "fishing", title = "Fishing", default = true },
    { key = "jewelcrafting", title = "Jewelcrafting", default = true },
    { key = "inscription", title = "Inscription", default = true },
    { key = "generic", title = "Generic Recipes", default = true },
    { key = "unknown", title = "Unknown or custom Recipe subclasses", default = false },
  },
  consumableOptions = {
    { key = "foodDrink", title = "Food & Drink", default = false },
    { key = "potion", title = "Potions", default = false },
    { key = "elixir", title = "Elixirs", default = false },
    { key = "flask", title = "Flasks", default = false },
    { key = "bandage", title = "Bandages", default = false },
    { key = "itemEnhancement", title = "Item Enhancements", default = false },
    { key = "scroll", title = "Scrolls", default = false },
    { key = "other", title = "Consumable: Other", default = false },
    { key = "unknown", title = "Unknown or custom Consumables", default = false },
  },
  otherOptions = {
    { key = "container", classKey = "container", title = "Non-equippable Containers", default = true },
    { key = "projectile", classKey = "projectile", title = "Projectiles", default = true },
    { key = "tradeGoods", classKey = "tradeGoods", title = "Trade Goods excluded from Materials", default = true },
    { key = "generic", classKey = "generic", title = "Generic Items", default = true },
    { key = "money", classKey = "money", title = "Money Items", default = true },
    { key = "quiver", classKey = "quiver", title = "Non-equippable Quivers", default = true },
    { key = "quest", classKey = "quest", title = "Quest Items", default = false },
    { key = "key", classKey = "key", title = "Keys", default = false },
    { key = "permanent", classKey = "permanent", title = "Permanent Items", default = true },
    { key = "miscellaneous", classKey = "miscellaneous", title = "Miscellaneous Items", default = true },
    { key = "glyph", classKey = "glyph", title = "Glyphs", default = true },
    { key = "unknown", classKey = "unknown", title = "Unknown or custom Classes", default = false },
  },
}

Banking.Categories = Categories

local CLASS_KEYS = {
  ["consumable"] = "consumable",
  ["container"] = "container",
  ["weapon"] = "weapon",
  ["gem"] = "gem",
  ["gems"] = "gem",
  ["armor"] = "armor",
  ["reagent"] = "reagent",
  ["reagents"] = "reagent",
  ["projectile"] = "projectile",
  ["projectiles"] = "projectile",
  ["trade good"] = "tradeGoods",
  ["trade goods"] = "tradeGoods",
  ["tradegoods"] = "tradeGoods",
  ["tradeskill"] = "tradeGoods",
  ["generic"] = "generic",
  ["recipe"] = "recipe",
  ["recipes"] = "recipe",
  ["money"] = "money",
  ["quiver"] = "quiver",
  ["quest"] = "quest",
  ["quest item"] = "quest",
  ["quest items"] = "quest",
  ["key"] = "key",
  ["keys"] = "key",
  ["permanent"] = "permanent",
  ["miscellaneous"] = "miscellaneous",
  ["glyph"] = "glyph",
  ["glyphs"] = "glyph",
}

local TRADE_SUBCLASS_KEYS = {
  ["trade good"] = "tradeGoods",
  ["trade goods"] = "tradeGoods",
  ["parts"] = "parts",
  ["explosive"] = "explosives",
  ["explosives"] = "explosives",
  ["device"] = "devices",
  ["devices"] = "devices",
  ["jewelcrafting"] = "jewelcrafting",
  ["cloth"] = "cloth",
  ["leather"] = "leather",
  ["metal stone"] = "metalStone",
  ["meat"] = "meat",
  ["herb"] = "herb",
  ["herbs"] = "herb",
  ["elemental"] = "elemental",
  ["other"] = "other",
  ["enchanting"] = "enchanting",
  ["material"] = "materials",
  ["materials"] = "materials",
  ["raw material"] = "materials",
  ["raw materials"] = "materials",
  ["armor enchantment"] = "armorEnchantment",
  ["armor enchantments"] = "armorEnchantment",
  ["weapon enchantment"] = "weaponEnchantment",
  ["weapon enchantments"] = "weaponEnchantment",
}

local RECIPE_SUBCLASS_KEYS = {
  ["book"] = "book",
  ["leatherworking"] = "leatherworking",
  ["tailoring"] = "tailoring",
  ["engineering"] = "engineering",
  ["blacksmithing"] = "blacksmithing",
  ["cooking"] = "cooking",
  ["alchemy"] = "alchemy",
  ["first aid"] = "firstAid",
  ["enchanting"] = "enchanting",
  ["fishing"] = "fishing",
  ["jewelcrafting"] = "jewelcrafting",
  ["inscription"] = "inscription",
  ["recipe"] = "generic",
  ["recipes"] = "generic",
}

local CONSUMABLE_SUBCLASS_KEYS = {
  ["food drink"] = "foodDrink",
  ["food and drink"] = "foodDrink",
  ["potion"] = "potion",
  ["potions"] = "potion",
  ["elixir"] = "elixir",
  ["elixirs"] = "elixir",
  ["flask"] = "flask",
  ["flasks"] = "flask",
  ["bandage"] = "bandage",
  ["bandages"] = "bandage",
  ["item enhancement"] = "itemEnhancement",
  ["item enhancements"] = "itemEnhancement",
  ["scroll"] = "scroll",
  ["scrolls"] = "scroll",
  ["other"] = "other",
}

local function normalize(text)
  return AP.Utils.NormalizeSearch(text or "")
end

local function itemIDFromLink(itemLink)
  return tonumber(tostring(itemLink or ""):match("item:(%-?%d+)"))
end

local function isEnchantingRod(itemName, subClassKey)
  if subClassKey ~= "enchanting" then
    return false
  end
  return normalize(itemName):find("%f[%a]rod%f[%A]") ~= nil
end

local function joinOptionTitles(options, pathPrefix)
  local included = {}
  local excluded = {}
  for index = 1, #options do
    local option = options[index]
    local target = AP.Database:Get(pathPrefix .. option.key, option.default) and included or excluded
    target[#target + 1] = option.title
  end
  return included, excluded
end

local function decide(evidence, categoryID, code, reason)
  evidence.category = categoryID
  evidence.code = code
  evidence.reason = reason
  return categoryID, evidence
end

function Categories:GetClassKey(className)
  return CLASS_KEYS[normalize(className)] or "unknown"
end

function Categories:GetTradeSubclassKey(subClassName)
  return TRADE_SUBCLASS_KEYS[normalize(subClassName)] or "unknown"
end

function Categories:GetRecipeSubclassKey(subClassName)
  return RECIPE_SUBCLASS_KEYS[normalize(subClassName)] or "unknown"
end

function Categories:GetConsumableSubclassKey(subClassName)
  return CONSUMABLE_SUBCLASS_KEYS[normalize(subClassName)] or "unknown"
end

function Categories:GetOption(options, key)
  for index = 1, #options do
    if options[index].key == key or options[index].classKey == key then
      return options[index]
    end
  end
  return options[#options]
end

function Categories:IsCategoryEnabled(categoryID)
  return AP.Database:Get("banking.categories." .. categoryID .. ".enabled", true) and true or false
end

function Categories:GetQualityOption(quality)
  quality = tonumber(quality)
  for index = 1, #self.qualityOptions do
    if self.qualityOptions[index].id == quality then
      return self.qualityOptions[index]
    end
  end
end

function Categories:IsQualityEnabled(categoryID, quality)
  local option = self:GetQualityOption(quality)
  if not option then
    return false
  end
  return AP.Database:Get(
    "banking.categories." .. categoryID .. ".qualities." .. option.key,
    option.default
  ) and true or false
end

function Categories:DecideCategory(evidence, categoryID, code, reason)
  evidence.intendedCategory = categoryID
  if not self:IsCategoryEnabled(categoryID) then
    return decide(evidence, nil, "category-disabled", self.definitions[categoryID].title .. " is disabled in configuration.")
  elseif not self:IsQualityEnabled(categoryID, evidence.quality) then
    local quality = self:GetQualityOption(evidence.quality)
    local qualityName = quality and quality.title or ("quality " .. tostring(evidence.quality))
    return decide(evidence, nil, "quality-disabled", qualityName .. " is disabled for " .. self.definitions[categoryID].title .. ".")
  end
  return decide(evidence, categoryID, code, reason)
end

function Categories:IsMaterialSubclassEnabled(subClassKey)
  local option = self:GetOption(self.materialOptions, subClassKey)
  return AP.Database:Get("banking.categories.materials." .. option.key, option.default)
end

function Categories:IsGearClassEnabled(classKey)
  local option
  for index = 1, #self.gearOptions do
    local candidate = self.gearOptions[index]
    if candidate.classKey == classKey then
      option = candidate
      break
    end
  end
  option = option or self.gearOptions[#self.gearOptions]
  return AP.Database:Get("banking.categories.gear." .. option.key, option.default), option
end

function Categories:IsRecipeSubclassEnabled(subClassKey)
  local option = self:GetOption(self.recipeOptions, subClassKey)
  return AP.Database:Get("banking.categories.recipe." .. option.key, option.default), option
end

function Categories:IsConsumableSubclassEnabled(subClassKey)
  local option = self:GetOption(self.consumableOptions, subClassKey)
  return AP.Database:Get("banking.categories.other.consumables." .. option.key, option.default), option
end

function Categories:IsOtherClassEnabled(classKey, subClassName)
  if classKey == "consumable" then
    return self:IsConsumableSubclassEnabled(self:GetConsumableSubclassKey(subClassName))
  end
  local option = self:GetOption(self.otherOptions, classKey)
  return AP.Database:Get("banking.categories.other." .. option.key, option.default), option
end

function Categories:GetIgnoredItems()
  local items = AP.Database:Get("banking.categories.exclusions.items", {})
  return type(items) == "table" and items or {}
end

function Categories:IsItemIgnored(itemID)
  itemID = tonumber(itemID)
  return itemID and self:GetIgnoredItems()[tostring(itemID)] ~= nil or false
end

function Categories:AddIgnoredItem(itemID, itemLink)
  itemID = tonumber(itemID)
  if not itemID or itemID <= 0 then
    return false, "That cursor item has no usable item ID."
  end
  local items = self:GetIgnoredItems()
  items[tostring(math.floor(itemID))] = itemLink or true
  AP.Database:Set("banking.categories.exclusions.items", items)
  return true
end

function Categories:RemoveIgnoredItem(itemID)
  local items = self:GetIgnoredItems()
  items[tostring(tonumber(itemID) or itemID)] = nil
  AP.Database:Set("banking.categories.exclusions.items", items)
end

function Categories:ClearIgnoredItems()
  AP.Database:Set("banking.categories.exclusions.items", {})
end

function Categories:GetIgnoredItemEntries()
  local entries = {}
  for key, savedLink in pairs(self:GetIgnoredItems()) do
    local itemID = tonumber(key)
    if itemID then
      local link = type(savedLink) == "string" and savedLink or nil
      local name, resolvedLink = GetItemInfo(link or itemID)
      entries[#entries + 1] = {
        id = itemID,
        link = resolvedLink or link,
        name = name or ("Item #" .. tostring(itemID)),
      }
    end
  end
  table.sort(entries, function(left, right)
    return tostring(left.name) < tostring(right.name)
  end)
  return entries
end

function Categories:IsProtectedBankAccessItem(itemName, className, subClassName)
  local compatibility = AP.Compatibility
  if compatibility
    and type(compatibility.IsAscensionClient) == "function"
    and not compatibility:IsAscensionClient() then
    return false
  end
  if not AP.Database:Get("banking.categories.exclusions.protectBankAccessItems", true) then
    return false
  end
  local text = normalize(table.concat({ itemName or "", className or "", subClassName or "" }, " "))
  return text:find("personal bank", 1, true) ~= nil or text:find("realm bank", 1, true) ~= nil
end

function Categories:GetItemEvidence(itemLink)
  local itemName, resolvedLink, quality, itemLevel, requiredLevel, className, subClassName, maxStack, equipSlot = GetItemInfo(itemLink)
  return {
    itemName = itemName,
    itemLink = resolvedLink or itemLink,
    itemID = itemIDFromLink(resolvedLink or itemLink),
    quality = quality,
    itemLevel = itemLevel,
    requiredLevel = requiredLevel,
    className = className,
    subClassName = subClassName,
    maxStack = maxStack,
    equipSlot = equipSlot,
  }
end

function Categories:GetHardExclusion(evidence)
  if not evidence.itemName or not evidence.className then
    return "uncached", "The client has not cached this item's class data yet."
  elseif self:IsItemIgnored(evidence.itemID) then
    return "item-blacklisted", "This item is on the Banking transfer blacklist."
  elseif self:IsProtectedBankAccessItem(evidence.itemName, evidence.className, evidence.subClassName) then
    return "bank-access-protected", "Server-specific bank access items are protected by configuration."
  end
end

function Categories:IsUnboundBindOnEquip(flags)
  return flags
    and flags.scanned
    and flags.bindOnEquip
    and not flags.soulbound
    and not flags.accountBound
    and not flags.realmBound
    and not flags.questBound
    or false
end

function Categories:Classify(itemLink)
  local evidence = self:GetItemEvidence(itemLink)
  local exclusionCode, exclusionReason = self:GetHardExclusion(evidence)
  if exclusionCode then
    return decide(evidence, nil, exclusionCode, exclusionReason)
  end

  local itemName = evidence.itemName
  local className = evidence.className
  local subClassName = evidence.subClassName
  local equipSlot = evidence.equipSlot

  evidence.classKey = self:GetClassKey(className)
  evidence.subClassKey = evidence.classKey == "tradeGoods" and self:GetTradeSubclassKey(subClassName) or nil

  local equippable = false
  if type(IsEquippableItem) == "function" then
    equippable = IsEquippableItem(itemLink) and true or false
  end
  if not equippable and equipSlot and equipSlot ~= "" and equipSlot ~= "INVTYPE_NON_EQUIP" then
    equippable = true
  end
  evidence.equippable = equippable

  if equippable then
    local enabled, option = self:IsGearClassEnabled(evidence.classKey)
    if not enabled then
      return decide(evidence, nil, "gear-type-disabled", option.title .. " is disabled under Gear.")
    end
    return self:DecideCategory(evidence, "gear", "equippable", "The client identifies this as enabled equippable " .. option.title .. ".")
  elseif evidence.classKey == "recipe" then
    evidence.recipeSubClassKey = self:GetRecipeSubclassKey(subClassName)
    local enabled, option = self:IsRecipeSubclassEnabled(evidence.recipeSubClassKey)
    if not enabled then
      return decide(evidence, nil, "recipe-subclass-disabled", option.title .. " is disabled under Recipe.")
    end
    return self:DecideCategory(evidence, "recipe", "recipe-subclass-enabled", option.title .. " is enabled under Recipe.")
  elseif evidence.classKey == "reagent" then
    return self:DecideCategory(evidence, "reagents", "reagent-class", "Its client item class is Reagent.")
  elseif evidence.classKey == "tradeGoods" then
    local option = self:GetOption(self.materialOptions, evidence.subClassKey)
    if isEnchantingRod(itemName, evidence.subClassKey) then
      if self:IsOtherClassEnabled("tradeGoods") then
        return self:DecideCategory(evidence, "other", "enchanting-rod-tool", "Enchanting rods are profession tools, not raw Materials.")
      end
      return decide(evidence, nil, "enchanting-rod-tool", "Enchanting rods are profession tools, not raw Materials.")
    elseif self:IsMaterialSubclassEnabled(evidence.subClassKey) then
      return self:DecideCategory(evidence, "materials", "material-subclass-enabled", string.format("Trade Goods subclass '%s' is enabled as a Material.", subClassName or option.title))
    elseif self:IsOtherClassEnabled("tradeGoods") then
      return self:DecideCategory(evidence, "other", "material-subclass-disabled", string.format("Trade Goods subclass '%s' is disabled under Materials and enabled under Other.", subClassName or option.title))
    end
    return decide(evidence, nil, "trade-goods-disabled", string.format("Trade Goods subclass '%s' is disabled under both Materials and Other.", subClassName or option.title))
  elseif evidence.classKey == "gem" then
    if AP.Database:Get("banking.categories.materials.includeGems", true) then
      return self:DecideCategory(evidence, "materials", "gems-enabled", "Its client item class is Gem and Include Gems is enabled.")
    end
    return decide(evidence, nil, "gems-disabled", "Its client item class is Gem, but Include Gems is disabled.")
  else
    local enabled, option = self:IsOtherClassEnabled(evidence.classKey, subClassName)
    if enabled then
      local code = evidence.classKey == "consumable" and "consumable-subclass-enabled" or "other-class-enabled"
      return self:DecideCategory(evidence, "other", code, option.title .. " is enabled under Other.")
    end
    local code = evidence.classKey == "consumable" and "consumable-subclass-disabled" or "other-class-disabled"
    return decide(evidence, nil, code, option.title .. " is disabled under Other.")
  end
end

function Categories:EvaluateButton(itemLink, categoryID, context)
  if categoryID == "all" then
    local evidence = self:GetItemEvidence(itemLink)
    local exclusionCode, exclusionReason = self:GetHardExclusion(evidence)
    if exclusionCode then
      local _, excludedEvidence = decide(evidence, nil, exclusionCode, exclusionReason)
      return true, false, excludedEvidence
    end

    local _, includedEvidence = decide(
      evidence,
      "all",
      "all-transfer",
      "The All button includes this stack without applying category, type, subclass, or quality filters."
    )
    return true, true, includedEvidence
  elseif categoryID == "boe" then
    local evidence = self:GetItemEvidence(itemLink)
    local exclusionCode, exclusionReason = self:GetHardExclusion(evidence)
    if exclusionCode then
      local _, excludedEvidence = decide(evidence, nil, exclusionCode, exclusionReason)
      return false, false, excludedEvidence
    end

    local flags = context and context.flags or nil
    evidence.bindingFlags = flags
    if not flags or not flags.scanned then
      local _, unscannedEvidence = decide(evidence, nil, "binding-unreadable", "The live source-slot binding tooltip could not be read, so BoE detection failed closed.")
      return false, false, unscannedEvidence
    elseif not self:IsUnboundBindOnEquip(flags) then
      local _, boundEvidence = decide(evidence, nil, "not-unbound-boe", "The live source slot is not an unbound Bind-on-Equip item.")
      return false, false, boundEvidence
    end

    local category, boeEvidence = self:DecideCategory(
      evidence,
      "boe",
      "unbound-bind-on-equip",
      "The live source slot is unbound and explicitly says Binds when equipped."
    )
    local matches = category == "boe"
    return matches, matches, boeEvidence
  end

  local itemCategory, evidence = self:Classify(itemLink)
  local matches = itemCategory == categoryID
  return matches, matches, evidence
end

function Categories:GetCategory(itemLink)
  local categoryID, evidence = self:Classify(itemLink)
  return categoryID, evidence and evidence.code
end

function Categories:GetQualitySummary(categoryID)
  local included, excluded = joinOptionTitles(self.qualityOptions, "banking.categories." .. categoryID .. ".qualities.")
  return "Qualities included: " .. (#included > 0 and table.concat(included, ", ") or "Nothing")
    .. ".\nQualities excluded: " .. (#excluded > 0 and table.concat(excluded, ", ") or "Nothing") .. "."
end

function Categories:GetMaterialsSummary()
  local included, excluded = joinOptionTitles(self.materialOptions, "banking.categories.materials.")
  local gemText = AP.Database:Get("banking.categories.materials.includeGems", true) and "included" or "excluded"
  return "Trade Goods included: " .. (#included > 0 and table.concat(included, ", ") or "Nothing")
    .. ".\nTrade Goods excluded: " .. (#excluded > 0 and table.concat(excluded, ", ") or "Nothing")
    .. ".\nEnchanting rods: always excluded from Materials. Gems: " .. gemText .. ".\n"
    .. self:GetQualitySummary("materials")
end

function Categories:GetOtherSummary()
  local included, excluded = joinOptionTitles(self.otherOptions, "banking.categories.other.")
  local consumables, excludedConsumables = joinOptionTitles(self.consumableOptions, "banking.categories.other.consumables.")
  return "Classes included: " .. (#included > 0 and table.concat(included, ", ") or "Nothing")
    .. ".\nClasses excluded: " .. (#excluded > 0 and table.concat(excluded, ", ") or "Nothing")
    .. ".\nConsumables included: " .. (#consumables > 0 and table.concat(consumables, ", ") or "Nothing")
    .. ".\nConsumables excluded: " .. (#excludedConsumables > 0 and table.concat(excludedConsumables, ", ") or "Nothing")
    .. ".\n" .. self:GetQualitySummary("other")
end

function Categories:GetTooltipLines(categoryID)
  local definition = self.definitions[categoryID]
  if not definition then
    return { "Unknown transfer category." }
  end

  local lines = {}
  if categoryID == "all" then
    lines[1] = definition.summary
  elseif categoryID == "boe" then
    lines[1] = definition.summary .. "\n" .. self:GetQualitySummary("boe")
  elseif categoryID == "materials" then
    lines[1] = self:GetMaterialsSummary()
  elseif categoryID == "other" then
    lines[1] = self:GetOtherSummary()
  else
    lines[1] = definition.summary .. "\n" .. self:GetQualitySummary(categoryID)
  end
  lines[#lines + 1] = "Withdraw uses only the open Character Bank or visible guild-style tab."
  return lines
end
