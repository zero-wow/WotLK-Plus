local _, AP = ...
AP = AP or _G.AscensionPlus

local Banking = AP.Banking
local Store = Banking.ContainerStore
Banking.providers = Banking.providers or {}

local Provider = {
  id = "guild-style",
}

Banking.providers.guildStyle = Provider

local function readFrameFlag(frame, key)
  if not frame then
    return false
  end

  local value = frame[key]
  if type(value) == "function" then
    local ok, result = pcall(value, frame)
    return ok and result and true or false
  end
  return value and true or false
end

function Provider:GetMode()
  local frame = _G.GuildBankFrame
  if readFrameFlag(frame, "IsPersonalBank") then
    return "personal"
  elseif readFrameFlag(frame, "IsRealmBank") then
    return "realm"
  end
  return "guild"
end

function Provider:IsOpen(controller)
  return controller and controller.guildBankOpen and true or false
end

function Provider:GetHostFrame()
  return _G.GuildBankFrame
end

function Provider:GetPanelRightClearance()
  return 68
end

function Provider:GetBankName()
  local mode = self:GetMode()
  if mode == "personal" then
    return "Personal Bank"
  elseif mode == "realm" then
    return "Realm Bank"
  end
  return "Guild Bank"
end

function Provider:GetDestinationName(operation)
  return operation == "withdraw" and "Inventory" or self:GetBankName()
end

function Provider:GetDestinationToken()
  local tab = type(GetCurrentGuildBankTab) == "function" and GetCurrentGuildBankTab() or 0
  local frameMode = _G.GuildBankFrame and _G.GuildBankFrame.mode or "bank"
  return string.format("%s:%s:%s", self:GetMode(), tostring(tab), tostring(frameMode))
end

function Provider:GetMoveDelay()
  return self:GetMode() == "guild" and 0.40 or 0.12
end

function Provider:GetResponseTimeout()
  return self:GetMode() == "guild" and 2.50 or 1.50
end

function Provider:GetTransferPacingProfile(conservative)
  if self:GetMode() == "guild" then
    if conservative then
      return {
        startDelay = 0.20,
        minDelay = 0.10,
        maxDelay = 1.25,
        fastConfirmation = 0.40,
        fastConfirmationsRequired = 4,
        initialInFlight = 3,
        maxInFlight = 4,
        delayedConfirmation = 1.90,
        backoffCooldown = 1.50,
        pipelineRecoveryConfirmations = 4,
      }
    end
    return {
      startDelay = 0.12,
      minDelay = 0.05,
      maxDelay = 1.00,
      fastConfirmation = 0.30,
      fastConfirmationsRequired = 3,
      accelerationFactor = 0.85,
      initialInFlight = 10,
      maxInFlight = 12,
      delayedConfirmation = 1.90,
      backoffCooldown = 1.50,
      pipelineRecoveryConfirmations = 3,
    }
  end

  if conservative then
    return {
      startDelay = 0.14,
      minDelay = 0.075,
      maxDelay = 0.75,
      fastConfirmation = 0.20,
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
    maxDelay = 0.65,
    fastConfirmation = 0.15,
    fastConfirmationsRequired = 3,
    accelerationFactor = 0.82,
    initialInFlight = 10,
    maxInFlight = 12,
    delayedConfirmation = 1.15,
    backoffCooldown = 1.00,
    pipelineRecoveryConfirmations = 3,
  }
end

function Provider:CanAcceptItemFlags(flags, operation)
  if operation == "withdraw" then
    return true
  end

  local mode = self:GetMode()
  if mode == "personal" then
    return true
  elseif mode == "realm" then
    if flags.soulbound then
      return false, "soulbound items cannot be deposited into the Realm Bank"
    end
    return true
  end

  if flags.soulbound then
    return false, "soulbound items cannot be deposited into the Guild Bank"
  elseif flags.accountBound then
    return false, "account-bound items cannot be deposited into the Guild Bank"
  elseif flags.realmBound then
    return false, "realm-bound items cannot be deposited into the Guild Bank"
  elseif flags.questBound then
    return false, "quest-bound items cannot be deposited into the Guild Bank"
  end
  return true
end

function Provider:CanUse(controller, operation)
  if not self:IsOpen(controller) or not _G.GuildBankFrame or not _G.GuildBankFrame:IsShown() then
    return false, "Open a Guild, Personal, or Realm Bank first."
  end

  if _G.GuildBankFrame.mode and _G.GuildBankFrame.mode ~= "bank" then
    return false, "Select the bank's item view first."
  end

  local tab = GetCurrentGuildBankTab()
  if not tab or tab < 1 then
    return false, "Select a bank tab first."
  end

  local _, _, isViewable, canDeposit, numWithdrawals, remainingWithdrawals = GetGuildBankTabInfo(tab)
  if not isViewable then
    return false, "The selected bank tab is not viewable."
  end

  if self:GetMode() == "guild" then
    if operation == "deposit" and not canDeposit then
      return false, "You do not have deposit permission for the selected Guild Bank tab."
    elseif operation == "withdraw" and numWithdrawals == 0 and remainingWithdrawals == 0 then
      return false, "You do not have withdrawal permission for the selected Guild Bank tab."
    end
  end

  return true
end

function Provider:GetSourceLocations(operation)
  if operation ~= "withdraw" then
    return Store:GetInventoryLocations()
  end

  local locations = {}
  local tab = GetCurrentGuildBankTab()
  local slotCount = _G.MAX_GUILDBANK_SLOTS_PER_TAB or 98
  for slotID = 1, slotCount do
    if GetGuildBankItemLink(tab, slotID) then
      locations[#locations + 1] = {
        kind = "guild-bank",
        tab = tab,
        slotID = slotID,
      }
    end
  end
  return locations
end

function Provider:GetSourceSnapshot(operation, location)
  if operation ~= "withdraw" then
    return Store:GetSnapshot(location)
  end
  if not location or location.kind ~= "guild-bank" then
    return nil
  end

  local itemLink = GetGuildBankItemLink(location.tab, location.slotID)
  if not itemLink then
    return nil
  end

  local _, count, locked = GetGuildBankItemInfo(location.tab, location.slotID)
  return {
    itemLink = itemLink,
    itemID = Store:GetItemID(itemLink),
    count = count or 0,
    locked = locked and true or false,
  }
end

function Provider:GetSourceLabel(operation, location)
  if operation ~= "withdraw" then
    return Store:GetLocationLabel(location)
  end

  local tabName = location and select(1, GetGuildBankTabInfo(location.tab)) or nil
  return string.format("%s tab %d%s, slot %d", self:GetBankName(), location.tab, tabName and " (" .. tabName .. ")" or "", location.slotID)
end

function Provider:HasDestinationCapacity(operation, itemLink)
  if operation == "withdraw" then
    return Store:HasInventoryCapacity(itemLink)
  end

  local itemID = Store:GetItemID(itemLink)
  local maxStack = select(8, GetItemInfo(itemLink))
  local tab = GetCurrentGuildBankTab()
  if not itemID or not maxStack or not tab then
    return false, "item or tab data is unavailable"
  end

  local slotCount = _G.MAX_GUILDBANK_SLOTS_PER_TAB or 98
  for slotID = 1, slotCount do
    local destinationLink = GetGuildBankItemLink(tab, slotID)
    local destinationID = Store:GetItemID(destinationLink)
    local _, count, locked = GetGuildBankItemInfo(tab, slotID)
    if destinationID == itemID and not locked and (count or 0) < maxStack then
      return true
    elseif not destinationLink and not locked then
      return true
    end
  end

  return false, "no room on the selected tab"
end

function Provider:Transfer(operation, location)
  if operation == "withdraw" then
    AutoStoreGuildBankItem(location.tab, location.slotID)
  else
    UseContainerItem(location.containerID, location.slotID)
  end
end

-- Compatibility wrappers for callers from older Ascension Plus builds.
function Provider:HasCapacity(itemLink)
  return self:HasDestinationCapacity("deposit", itemLink)
end

function Provider:Deposit(bagID, slotID)
  UseContainerItem(bagID, slotID)
end
