_G.AscensionPlus = {
  Banking = {},
}

dofile("modules/banking/sorter/AdaptivePacing.lua")

local Pacing = _G.AscensionPlus.Banking.SorterPacing
local state = Pacing:Create(false)

assert(math.abs(Pacing:GetRate(state) - (1 / 0.12)) < 0.001, "default pacing must start near 8.3 operations/sec")
for _ = 1, 3 do
  Pacing:Confirm(state, 0.10, false)
end
assert(math.abs(Pacing:GetDelay(state) - 0.12) < 0.001, "pacing must not accelerate before four fast confirmations")
Pacing:Confirm(state, 0.10, false)
assert(Pacing:GetDelay(state) < 0.12, "four fast confirmations should permit one acceleration step")

for _ = 1, 100 do
  Pacing:Confirm(state, 0.05, false)
end
assert(Pacing:GetDelay(state) >= 0.075, "default pacing must respect the measured safe cap")

local beforeBackoff = Pacing:GetDelay(state)
Pacing:BackOff(state)
assert(Pacing:GetDelay(state) > beforeBackoff, "a delayed response must immediately reduce the rate")

local conservative = Pacing:Create(true)
for _ = 1, 100 do
  Pacing:Confirm(conservative, 0.05, false)
end
assert(Pacing:GetDelay(conservative) >= 0.10, "conservative pacing must cap at 10 operations/sec")

io.write("PASS adaptive pacing requires sustained confirmations and respects both safety caps\n")
