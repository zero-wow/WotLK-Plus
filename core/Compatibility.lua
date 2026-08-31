local _, AP = ...
AP = AP or _G.Levo or _G.WotLKPlus or _G.AscensionPlus

local Compatibility = {}
AP.Compatibility = Compatibility

function Compatibility:HasSkillCards()
  return type(GetSkillCard) == "function"
    and type(GetLuckyCard) == "function"
    and type(C_VanityCollection) == "table"
    and type(C_VanityCollection.IsCollectionItemOwned) == "function"
end

function Compatibility:HasAppearanceCollection()
  return type(C_Appearance) == "table"
    and type(C_Appearance.GetItemAppearanceID) == "function"
    and type(C_AppearanceCollection) == "table"
    and type(C_AppearanceCollection.IsAppearanceCollected) == "function"
    and type(C_AppearanceCollection.CollectItemAppearance) == "function"
end

function Compatibility:HasCustomClasses()
  return type(CUSTOM_CLASS_COLORS) == "table" and CUSTOM_CLASS_COLORS.NECROMANCER ~= nil
end

function Compatibility:IsAscensionClient()
  return self:HasSkillCards() or self:HasAppearanceCollection() or self:HasCustomClasses()
end

function Compatibility:HasKeeperBanks()
  local frame = _G.GuildBankFrame
  if not frame then
    return false
  end
  return type(frame.IsPersonalBank) == "function"
    or type(frame.IsRealmBank) == "function"
    or frame.IsPersonalBank == true
    or frame.IsRealmBank == true
end
