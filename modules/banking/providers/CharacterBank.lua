local _, AP = ...
AP = AP or _G.AscensionPlus

local Banking = AP.Banking
local Store = Banking.ContainerStore
Banking.providers = Banking.providers or {}

local Provider = {
  id = "character",
}

Banking.providers.character = Provider

function Provider:IsOpen(controller)
  return controller and controller.normalBankOpen and true or false
end

function Provider:GetHostFrame()
  if _G.ElvUI_BankContainerFrame and _G.ElvUI_BankContainerFrame:IsShown() then
    return _G.ElvUI_BankContainerFrame
  end
  if _G.BankFrame and _G.BankFrame:IsShown() then
    return _G.BankFrame
  end
  return _G.ElvUI_BankContainerFrame or _G.BankFrame
end

function Provider:GetBankName()
  return "Character Bank"
end

function Provider:GetDestinationName(operation)
  return operation == "withdraw" and "Inventory" or self:GetBankName()
end

function Provider:GetDestinationToken()
  return self.id
end

function Provider:GetMoveDelay()
  return 0.10
end

function Provider:GetResponseTimeout()
  return 1.50
end

function Provider:GetTransferPacingProfile(conservative)
  if conservative then
    return {
      startDelay = 0.14,
      minDelay = 0.075,
      maxDelay = 0.60,
      fastConfirmation = 0.18,
      fastConfirmationsRequired = 4,
      initialInFlight = 3,
      maxInFlight = 4,
      delayedConfirmation = 1.15,
      backoffCooldown = 1.00,
      pipelineRecoveryConfirmations = 4,
    }
  end
  return {
    startDelay = 0.10,
    minDelay = 0.025,
    maxDelay = 0.50,
    fastConfirmation = 0.12,
    fastConfirmationsRequired = 3,
    accelerationFactor = 0.82,
    initialInFlight = 10,
    maxInFlight = 12,
    delayedConfirmation = 1.15,
    backoffCooldown = 1.00,
    pipelineRecoveryConfirmations = 3,
  }
end

function Provider:CanAcceptItemFlags()
  return true
end

function Provider:CanUse(controller)
  if not self:IsOpen(controller) then
    return false, "Open your Character Bank first."
  end

  local host = self:GetHostFrame()
  if not host or not host:IsShown() then
    return false, "The Character Bank frame is not visible."
  end
  return true
end

function Provider:GetSourceLocations(operation)
  if operation == "withdraw" then
    return Store:GetCharacterBankLocations()
  end
  return Store:GetInventoryLocations()
end

function Provider:GetSourceSnapshot(_, location)
  return Store:GetSnapshot(location)
end

function Provider:GetSourceLabel(_, location)
  return Store:GetLocationLabel(location)
end

function Provider:HasDestinationCapacity(operation, itemLink)
  if operation == "withdraw" then
    return Store:HasInventoryCapacity(itemLink)
  end
  return Store:HasCharacterBankCapacity(itemLink)
end

function Provider:Transfer(_, location)
  UseContainerItem(location.containerID, location.slotID)
end

-- Compatibility wrappers for callers from older Ascension Plus builds.
function Provider:HasCapacity(itemLink)
  return self:HasDestinationCapacity("deposit", itemLink)
end

function Provider:Deposit(bagID, slotID)
  UseContainerItem(bagID, slotID)
end
