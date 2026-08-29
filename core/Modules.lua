local _, AP = ...
AP = AP or _G.AscensionPlus

local Modules = {
  registry = {},
  order = {},
  initialized = false,
}

AP.Modules = Modules

local function sortModuleIds(order, registry)
  table.sort(order, function(leftId, rightId)
    local left = registry[leftId]
    local right = registry[rightId]
    local leftOrder = left and left.order or 100
    local rightOrder = right and right.order or 100

    if leftOrder == rightOrder then
      return leftId < rightId
    end

    return leftOrder < rightOrder
  end)
end

local function callModuleMethod(module, methodName)
  local method = module and module[methodName]
  if type(method) ~= "function" then
    return
  end

  local ok, err = pcall(method, module)
  if not ok then
    AP:Print(string.format("Module error in %s.%s: %s", tostring(module.id), tostring(methodName), tostring(err)))
  end
end

function Modules:Register(id, module)
  module = module or {}
  module.id = id

  if not self.registry[id] then
    self.order[#self.order + 1] = id
  end

  self.registry[id] = module
end

function Modules:Get(id)
  return self.registry[id]
end

function Modules:IsEnabled(moduleOrId)
  local module = moduleOrId
  if type(moduleOrId) == "string" then
    module = self.registry[moduleOrId]
  end

  if not module then
    return false
  end

  if not module.enabledPath then
    return true
  end

  return AP.Database:Get(module.enabledPath, true) and true or false
end

function Modules:InitializeDefinitions()
  if self.initialized then
    return
  end

  sortModuleIds(self.order, self.registry)
  for index = 1, #self.order do
    local module = self.registry[self.order[index]]
    callModuleMethod(module, "OnInitialize")
  end

  self.initialized = true
end

function Modules:RefreshStates()
  sortModuleIds(self.order, self.registry)

  for index = 1, #self.order do
    local module = self.registry[self.order[index]]
    local shouldBeEnabled = self:IsEnabled(module)

    if shouldBeEnabled and not module._enabled then
      callModuleMethod(module, "OnEnable")
      module._enabled = true
    elseif not shouldBeEnabled and module._enabled then
      callModuleMethod(module, "OnDisable")
      module._enabled = false
    end
  end
end
