local _, AP = ...
AP = AP or _G.Levo or _G.WotLKPlus or _G.AscensionPlus

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
    minimapPalette = {
      collectButtons = true,
      locked = false,
      showTooltips = true,
      point = "TOPRIGHT",
      relPoint = "TOPRIGHT",
      x = -8,
      y = -8,
    },
    window = {
      point = "CENTER",
      relPoint = "CENTER",
      x = 0,
      y = 0,
      width = 760,
      height = 470,
    },
  },
  modules = {
    classes = true,
    skillCards = true,
    banking = true,
    transmog = true,
    destroyConfirm = true,
    minimapPalette = true,
    talentImport = true,
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
      qualityRules = {
        poor = { mode = "normal", inventoryDestination = "any", characterDestination = "any" },
        common = { mode = "normal", inventoryDestination = "any", characterDestination = "any" },
        uncommon = { mode = "normal", inventoryDestination = "any", characterDestination = "any" },
        rare = { mode = "normal", inventoryDestination = "any", characterDestination = "any" },
        epic = { mode = "normal", inventoryDestination = "any", characterDestination = "any" },
        legendary = { mode = "normal", inventoryDestination = "any", characterDestination = "any" },
        artifact = { mode = "normal", inventoryDestination = "any", characterDestination = "any" },
        heirloom = { mode = "normal", inventoryDestination = "any", characterDestination = "any" },
      },
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
  talentImport = {
    showButton = true,
    showTooltips = true,
    lastBuild = "",
    progression = {
      enabled = false,
      build = "",
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

  if type(LevoDB) ~= "table" then
    LevoDB = {}
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

  -- Levo adopts prior settings once, then keeps only its own SavedVariables root.
  if type(WotLKPlusDB) == "table" then
    copyMissing(LevoDB, WotLKPlusDB)
  end
  if type(AscensionPlusDB) == "table" then
    copyMissing(LevoDB, AscensionPlusDB)
  end

  -- Only replace former stock sizes; a manually resized panel is intentional.
  local interface = type(LevoDB.interface) == "table" and LevoDB.interface or nil
  local window = interface and type(interface.window) == "table" and interface.window or nil
  if interface and interface.windowLayoutVersion ~= 2 then
    if window
      and ((tonumber(window.width) == 1040 and tonumber(window.height) == 660)
        or (tonumber(window.width) == 960 and tonumber(window.height) == 590))
      and (window.point == nil or window.point == "CENTER")
      and (window.relPoint == nil or window.relPoint == "CENTER")
      and (window.x == nil or tonumber(window.x) == 0)
      and (window.y == nil or tonumber(window.y) == 0) then
      window.width = 760
      window.height = 470
    end
    interface.windowLayoutVersion = 2
  end

  self.db = AP.Utils.MergeDefaults(LevoDB, AP.defaults)
  LevoDB = self.db
  WotLKPlusDB = nil
  AscensionPlusDB = nil
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
