local root = (... and ... ~= "" and ...) or "."

_G.AscensionPlus = {}
_G.WotLKPlus = _G.AscensionPlus
_G.GetSkillCard = nil
_G.GetLuckyCard = nil
_G.C_VanityCollection = nil
_G.C_Appearance = nil
_G.C_AppearanceCollection = nil
_G.CUSTOM_CLASS_COLORS = nil
_G.GuildBankFrame = nil

dofile(root .. "/core/Compatibility.lua")

local Compatibility = _G.WotLKPlus.Compatibility

assert(not Compatibility:HasSkillCards(), "standard clients must not enable the skill-card extension")
assert(not Compatibility:HasAppearanceCollection(), "standard clients must not enable the appearance extension")
assert(not Compatibility:HasCustomClasses(), "standard clients must not enable custom class pages")
assert(not Compatibility:IsAscensionClient(), "standard clients must remain generic")
assert(not Compatibility:HasKeeperBanks(), "Keeper support must remain unavailable without a host frame")

_G.GetSkillCard = function() end
_G.GetLuckyCard = function() end
_G.C_VanityCollection = { IsCollectionItemOwned = function() return false end }
assert(Compatibility:HasSkillCards(), "all required skill-card APIs must enable the extension")

_G.C_Appearance = { GetItemAppearanceID = function() return 1 end }
_G.C_AppearanceCollection = {
  IsAppearanceCollected = function() return false end,
  CollectItemAppearance = function() return true end,
}
assert(Compatibility:HasAppearanceCollection(), "all required appearance APIs must enable the extension")

_G.CUSTOM_CLASS_COLORS = { NECROMANCER = { r = 1, g = 1, b = 1 } }
assert(Compatibility:HasCustomClasses(), "custom class colors must enable the class extension")
assert(Compatibility:IsAscensionClient(), "an extension capability must identify the Ascension client")

_G.GuildBankFrame = { IsPersonalBank = true }
assert(Compatibility:HasKeeperBanks(), "boolean Keeper flags must be detected")
_G.GuildBankFrame = { IsRealmBank = function() return true end }
assert(Compatibility:HasKeeperBanks(), "function Keeper flags must be detected")

print("CompatibilitySpec: OK")
