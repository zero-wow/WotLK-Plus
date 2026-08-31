local function assertEqual(actual, expected, label)
  if actual ~= expected then
    error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)), 2)
  end
end

local values = {
  banking = {
    sorter = {
      exclusions = {
        items = {
          ["999"] = true,
        },
        bags = {
          inventory = {
            bag1 = true,
          },
        },
      },
    },
  },
}

local function readPath(path)
  local current = values
  for segment in tostring(path):gmatch("[^%.]+") do
    if type(current) ~= "table" then
      return nil
    end
    current = current[segment]
  end
  return current
end

_G.AscensionPlus = {
  Banking = {},
  Database = {
    Get = function(_, path, fallback)
      local value = readPath(path)
      return value == nil and fallback or value
    end,
    Set = function()
    end,
  },
}

_G.NUM_BAG_SLOTS = 2
_G.BANK_CONTAINER = -1

local items = {
  [100] = { name = "Alpha", quality = 1 },
  [200] = { name = "Zeta", quality = 1 },
  [300] = { name = "Specialty", quality = 1 },
  [400] = { name = "Blocked Bag", quality = 1 },
  [999] = { name = "Protected", quality = 4 },
}

local bags = {
  [0] = {
    { id = 200, count = 1 },
    { id = 999, count = 1 },
    { id = 100, count = 1 },
  },
  [1] = {
    { id = 400, count = 1 },
    false,
  },
  [2] = {
    { id = 300, count = 1 },
    false,
  },
}

local function linkFor(itemID)
  local item = items[itemID]
  return item and string.format("|cff00ff00|Hitem:%d:0:0:0|h[%s]|h|r", itemID, item.name) or nil
end

function GetContainerNumSlots(containerID)
  return bags[containerID] and #bags[containerID] or 0
end

function GetContainerNumFreeSlots(containerID)
  return 0, containerID == 2 and 32 or 0
end

function GetContainerItemLink(containerID, slotID)
  local slot = bags[containerID] and bags[containerID][slotID]
  return slot and linkFor(slot.id) or nil
end

function GetContainerItemInfo(containerID, slotID)
  local slot = bags[containerID] and bags[containerID][slotID]
  return nil, slot and slot.count or 0, false, slot and items[slot.id].quality or nil
end

function GetItemInfo(item)
  local itemID = tonumber(item) or tonumber(tostring(item):match("item:(%d+)"))
  local data = items[itemID]
  if not data then
    return nil
  end
  return data.name, linkFor(itemID), data.quality, 1, 1, "Trade Goods", "Parts", 20, ""
end

local cursor

function GetCursorInfo()
  if cursor then
    return "item", cursor.id, linkFor(cursor.id)
  end
  return nil
end

function PickupContainerItem(containerID, slotID)
  local slot = bags[containerID][slotID]
  if not cursor then
    cursor = slot
    bags[containerID][slotID] = false
  elseif not slot then
    bags[containerID][slotID] = cursor
    cursor = nil
  else
    bags[containerID][slotID], cursor = cursor, slot
  end
end

function SplitContainerItem()
end

function GetNumBankSlots()
  return 0
end

dofile("modules/banking/sorter/Planner.lua")
dofile("modules/banking/sorter/Exclusions.lua")
dofile("modules/banking/sorter/ContainerProvider.lua")

local Banking = _G.AscensionPlus.Banking
local provider = Banking.SorterProviders.inventory
local snapshot = assert(provider:TakeSnapshot())

assertEqual(snapshot.slotCount, 2, "only two physical slots remain movable")
assertEqual(snapshot.excludedItems, 1, "protected item slot count")
assertEqual(snapshot.excludedBags, 2, "blocked and specialty bag count")
assertEqual(snapshot.specialtyBags, 1, "specialty bag count")
assertEqual(snapshot.locations[1].containerID, 0, "first location bag")
assertEqual(snapshot.locations[1].slotID, 1, "first location physical slot")
assertEqual(snapshot.locations[2].containerID, 0, "second location bag")
assertEqual(snapshot.locations[2].slotID, 3, "protected physical slot is absent")

local plan = assert(Banking.SorterPlanner:Build(snapshot))
assertEqual(#plan.operations, 1, "two movable items require one swap")
local operation = plan.operations[1]
operation.sourceLocation = snapshot.locations[operation.sourceSlot]
operation.targetLocation = snapshot.locations[operation.targetSlot]

assert(operation.sourceLocation.slotID ~= 2, "protected item slot cannot be a source")
assert(operation.targetLocation.slotID ~= 2, "protected item slot cannot be a destination")
assert(operation.sourceLocation.containerID ~= 1, "blocked bag cannot be a source")
assert(operation.targetLocation.containerID ~= 1, "blocked bag cannot be a destination")
assert(operation.sourceLocation.containerID ~= 2, "specialty bag cannot be a source")
assert(operation.targetLocation.containerID ~= 2, "specialty bag cannot be a destination")

local beforeMatches = provider:OperationMatches("inventory", operation, "before")
assertEqual(beforeMatches, true, "bound physical locations match before state")
local executed, executeError = provider:Execute("inventory", operation)
assertEqual(executed, true, "physical container swap executes: " .. tostring(executeError))
assertEqual(cursor, nil, "physical container swap restores displaced cursor item")
local afterMatches = provider:OperationMatches("inventory", operation, "after")
assertEqual(afterMatches, true, "bound physical locations match after state")

values.banking.sorter.qualityRules = {
  legendary = { mode = "ignore" },
}
items[200].quality = 5
snapshot = assert(provider:TakeSnapshot())
assertEqual(snapshot.slotCount, 1, "ignored quality slots should be absent from the planner snapshot")
assertEqual(snapshot.excludedQualities, 1, "ignored quality slot count")
assertEqual(snapshot.locations[1].slotID, 1, "remaining movable slot should preserve its physical location")

io.write("PASS exclusions stay outside the plan and bound physical container swaps confirm\n")
