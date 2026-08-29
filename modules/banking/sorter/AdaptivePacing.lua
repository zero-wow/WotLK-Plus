local _, AP = ...
AP = AP or _G.AscensionPlus

local Banking = AP.Banking
local AdaptivePacing = {}

Banking.SorterPacing = AdaptivePacing

local DEFAULT_PROFILE = {
  startDelay = 0.12,
  minDelay = 0.075,
  maxDelay = 0.40,
  fastConfirmation = 0.18,
  fastConfirmationsRequired = 4,
}

local CONSERVATIVE_PROFILE = {
  startDelay = 0.14,
  minDelay = 0.10,
  maxDelay = 0.50,
  fastConfirmation = 0.20,
  fastConfirmationsRequired = 5,
}

local function copyProfile(profile)
  local copy = {}
  for key, value in pairs(profile) do
    copy[key] = value
  end
  return copy
end

function AdaptivePacing:Create(conservative, overrides)
  local profile = copyProfile(conservative and CONSERVATIVE_PROFILE or DEFAULT_PROFILE)
  for key, value in pairs(overrides or {}) do
    profile[key] = value
  end
  return {
    profile = profile,
    delay = profile.startDelay,
    fastConfirmations = 0,
    backoffs = 0,
  }
end

function AdaptivePacing:GetDelay(state)
  return state and state.delay or DEFAULT_PROFILE.startDelay
end

function AdaptivePacing:GetRate(state)
  local delay = self:GetDelay(state)
  if delay <= 0 then
    return 0
  end
  return 1 / delay
end

function AdaptivePacing:Confirm(state, latency, retried)
  if not state then
    return
  end

  local profile = state.profile
  if retried or latency > profile.fastConfirmation then
    state.fastConfirmations = 0
    return
  end

  state.fastConfirmations = state.fastConfirmations + 1
  if state.fastConfirmations >= profile.fastConfirmationsRequired then
    state.delay = math.max(profile.minDelay, state.delay * (profile.accelerationFactor or 0.90))
    state.fastConfirmations = 0
  end
end

function AdaptivePacing:BackOff(state)
  if not state then
    return
  end

  local profile = state.profile
  state.delay = math.min(profile.maxDelay, state.delay * 1.35 + 0.01)
  state.fastConfirmations = 0
  state.backoffs = state.backoffs + 1
end

function AdaptivePacing:IsDelayed(state, latency)
  if not state then
    return false
  end
  local threshold = state.profile.delayedConfirmation or math.max(0.22, state.delay * 2)
  return latency >= threshold
end
