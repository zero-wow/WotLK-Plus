local _, AP = ...
AP = AP or _G.AscensionPlus

local Database = {
  ready = false,
  db = nil,
}

AP.Database = Database

AP.defaults = AP.defaults or {
  general = {
    showStartupMessage = true,
  },
  interface = {
    restoreLastPage = true,
    searchHints = true,
    launcher = {
      showTooltip = true,
      minimap = {
        hide = false,
        minimapPos = 220,
      },
    },
    window = {
      point = "CENTER",
      relPoint = "CENTER",
      x = 0,
      y = 0,
      width = 1040,
      height = 660,
    },
  },
  modules = {
    classes = true,
    skillCards = true,
    banking = true,
    transmog = true,
    destroyConfirm = true,
  },
  skillCards = {
    migrationVersion = 0,
    showTooltips = true,
    rarityBorders = true,
    protectStandard = true,
    protectGolden = true,
    lootBehavior = "toast",
    vendorOpenBehavior = "open",
    vendorCloseBehavior = "hide",
    window = {
      point = "CENTER",
      relPoint = "CENTER",
      x = 0,
      y = 20,
      width = 520,
      height = 470,
    },
  },
  banking = {
    sorter = {
      enabled = true,
      showButton = true,
      preferNativeAnchor = true,
      conservativePacing = false,
      showChatMessages = true,
      exclusions = {
        items = {},
        bags = {
          inventory = {
            backpack = false,
            bag1 = false,
            bag2 = false,
            bag3 = false,
            bag4 = false,
          },
          character = {
            main = false,
            bag1 = false,
            bag2 = false,
            bag3 = false,
            bag4 = false,
            bag5 = false,
            bag6 = false,
            bag7 = false,
          },
        },
      },
    },
    deposit = {
      showPanel = true,
      showTooltips = true,
      showChatMessages = true,
      conservativePacing = false,
    },
    categories = {
      boe = {
        enabled = true,
        qualities = {
          poor = false,
          common = true,
          uncommon = true,
          rare = true,
          epic = true,
          legendary = true,
          artifact = true,
          heirloom = true,
        },
      },
      materials = {
        enabled = true,
        includeGems = true,
        parts = true,
        jewelcrafting = true,
        cloth = true,
        leather = true,
        metalStone = true,
        meat = true,
        herb = true,
        elemental = true,
        enchanting = true,
        materials = true,
        tradeGoods = false,
        explosives = false,
        devices = false,
        other = false,
        armorEnchantment = false,
        weaponEnchantment = false,
        unknown = false,
        qualities = {
          poor = false,
          common = true,
          uncommon = true,
          rare = true,
          epic = true,
          legendary = true,
          artifact = true,
          heirloom = true,
        },
      },
      reagents = {
        enabled = true,
        qualities = {
          poor = false,
          common = true,
          uncommon = true,
          rare = true,
          epic = true,
          legendary = true,
          artifact = true,
          heirloom = true,
        },
      },
      gear = {
        enabled = true,
        weapons = true,
        armor = true,
        containers = false,
        quivers = false,
        otherEquippable = false,
        qualities = {
          poor = false,
          common = true,
          uncommon = true,
          rare = true,
          epic = true,
          legendary = true,
          artifact = true,
          heirloom = true,
        },
      },
      recipe = {
        enabled = true,
        book = true,
        leatherworking = true,
        tailoring = true,
        engineering = true,
        blacksmithing = true,
        cooking = true,
        alchemy = true,
        firstAid = true,
        enchanting = true,
        fishing = true,
        jewelcrafting = true,
        inscription = true,
        generic = true,
        unknown = false,
        qualities = {
          poor = false,
          common = true,
          uncommon = true,
          rare = true,
          epic = true,
          legendary = true,
          artifact = true,
          heirloom = true,
        },
      },
      other = {
        enabled = true,
        consumable = false,
        container = true,
        projectile = true,
        tradeGoods = true,
        generic = true,
        money = true,
        quiver = true,
        quest = false,
        key = false,
        permanent = true,
        miscellaneous = true,
        glyph = true,
        unknown = false,
        consumables = {
          foodDrink = false,
          potion = false,
          elixir = false,
          flask = false,
          bandage = false,
          itemEnhancement = false,
          scroll = false,
          other = false,
          unknown = false,
        },
        qualities = {
          poor = false,
          common = true,
          uncommon = true,
          rare = true,
          epic = true,
          legendary = true,
          artifact = true,
          heirloom = true,
        },
      },
      exclusions = {
        protectBankAccessItems = true,
        items = {},
      },
    },
  },
  qol = {
    destroyConfirm = {
      autoFillDelete = true,
    },
  },
  transmog = {
    autoCollect = {
      enabled = false,
      automationAuthorized = false,
      rulesVersion = 0,
      toggleKey = "",
      showChatMessages = true,
      showReviewAlerts = true,
      autoConfirmBinding = true,
      deferUntilOutOfCombat = true,
      includeArmor = true,
      includeWeapons = true,
      includeOtherEquippable = true,
      qualities = {
        poor = false,
        common = false,
        uncommon = true,
        rare = true,
        epic = false,
        legendary = false,
        artifact = false,
        heirloom = false,
      },
      qualityModes = {
        poor = "never",
        common = "never",
        uncommon = "ask",
        rare = "ask",
        epic = "never",
        legendary = "never",
        artifact = "never",
        heirloom = "never",
      },
      blacklist = {},
    },
  },
  state = {
    lastPage = "general",
  },
}

local function traverse(root, path, createMissing)
  local current = root
  local segments = AP.Utils.PathSegments(path)

  if #segments == 0 then
    return root, nil
  end

  for index = 1, #segments - 1 do
    local segment = segments[index]
    if type(current[segment]) ~= "table" then
      if not createMissing then
        return nil, nil
      end
      current[segment] = {}
    end
    current = current[segment]
  end

  return current, segments[#segments]
end

function Database:Initialize()
  if self.ready then
    return
  end

  if type(WotLKPlusDB) ~= "table" then
    WotLKPlusDB = {}
  end

  local function copyMissing(target, source)
    for key, value in pairs(source or {}) do
      if target[key] == nil then
        target[key] = value
      elseif type(target[key]) == "table" and type(value) == "table" then
        copyMissing(target[key], value)
      end
    end
  end

  -- The renamed addon adopts existing Ascension Plus settings without sharing
  -- a SavedVariables name with a legacy installation.
  if type(AscensionPlusDB) == "table" then
    copyMissing(WotLKPlusDB, AscensionPlusDB)
  end

  self.db = AP.Utils.MergeDefaults(WotLKPlusDB, AP.defaults)
  WotLKPlusDB = self.db
  self.ready = true
end

function Database:Get(path, fallback)
  if not self.ready then
    self:Initialize()
  end

  if not path or path == "" then
    return self.db
  end

  local current = self.db
  local segments = AP.Utils.PathSegments(path)
  for index = 1, #segments do
    if type(current) ~= "table" then
      return fallback
    end

    current = current[segments[index]]
    if current == nil then
      return fallback
    end
  end

  return current
end

function Database:Set(path, value)
  if not self.ready then
    self:Initialize()
  end

  local parent, key = traverse(self.db, path, true)
  if not parent or not key then
    return
  end

  parent[key] = value
end

function Database:Toggle(path)
  local nextValue = not self:Get(path, false)
  self:Set(path, nextValue)
  return nextValue
end
