local _, AP = ...
AP = AP or _G.AscensionPlus

local Integration = {}
AP.BankingElvUI = Integration

function Integration:IsAvailable()
  return type(_G.ElvUI) == "table" and type(_G.ElvUI[1]) == "table"
end

function Integration:Apply(panel)
  if not self:IsAvailable() or panel._ascensionPlusElvUIStyled then
    return false
  end

  if type(panel.SetTemplate) == "function" then
    panel:SetTemplate("Transparent")
  end

  panel._ascensionPlusElvUIStyled = true
  return true
end
