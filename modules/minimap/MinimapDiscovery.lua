local _, AP = ...
AP = AP or _G.Levo or _G.WotLKPlus or _G.AscensionPlus

local Discovery = {}
AP.MinimapPaletteDiscovery = Discovery

local EXCLUDED_BUTTONS = {
  MinimapZoomIn = true,
  MinimapZoomOut = true,
  MiniMapTracking = true,
  MiniMapWorldMapButton = true,
  MiniMapBattlefieldFrame = true,
  MiniMapMailFrame = true,
  MiniMapVoiceChatFrame = true,
  MiniMapInstanceDifficulty = true,
  GuildInstanceDifficulty = true,
  GameTimeFrame = true,
  QueueStatusMinimapButton = true,
  MiniMapLFGFrame = true,
  MiniMapMeetingStoneFrame = true,
  LevoMinimapPaletteButton = true,
  LibDBIcon10_Levo = true,
}

local function call(frame, method, ...)
  if not frame or type(frame[method]) ~= "function" then
    return nil
  end
  local ok, result, second, third, fourth = pcall(frame[method], frame, ...)
  if ok then
    return result, second, third, fourth
  end
end

local function isButton(frame)
  if not frame then
    return false
  end
  local objectType = call(frame, "GetObjectType")
  if objectType then
    return objectType == "Button"
  end
  return call(frame, "IsObjectType", "Button") and true or false
end

local function getName(frame)
  return call(frame, "GetName")
end

local function cleanLabel(name)
  if not name or name == "" then
    return nil
  end
  name = name:gsub("^LibDBIcon10_", "")
  name = name:gsub("^MinimapButton", "")
  name = name:gsub("([a-z])([A-Z])", "%1 %2")
  name = name:gsub("[_%-]+", " ")
  name = name:gsub("%s+", " ")
  name = name:gsub("^%s+", ""):gsub("%s+$", "")
  return name ~= "" and name or nil
end

local function getLabel(frame, name)
  local label = frame.tooltipText
  if type(label) ~= "string" or label == "" then
    local object = frame.dataObject or frame.object or frame.data
    if type(object) == "table" then
      label = object.label or object.text or object.name
    end
  end
  if type(label) ~= "string" or label == "" then
    label = cleanLabel(name)
  end
  return label
end

local function getIcon(frame)
  -- Prefer the addon's data-object or live icon region. Normal textures are often
  -- decorative minimap rings, so use them only as a final compatibility fallback.
  local data = frame.dataObject or frame.object or frame.data
  local candidates = {}
  local function addCandidate(candidate)
    if candidate ~= nil then
      candidates[#candidates + 1] = candidate
    end
  end
  addCandidate(type(data) == "table" and (data.icon or data.Icon) or nil)
  addCandidate(frame.icon)
  addCandidate(frame.Icon)
  addCandidate(frame.texture)
  addCandidate(frame.Texture)
  addCandidate(call(frame, "GetNormalTexture"))

  for index = 1, #candidates do
    local candidate = candidates[index]
    local texture
    local coords
    if type(candidate) == "string" or type(candidate) == "number" then
      texture = candidate
      coords = { 0.04, 0.96, 0.04, 0.96 }
    elseif candidate then
      texture = call(candidate, "GetTexture")
      local left, right, top, bottom = call(candidate, "GetTexCoord")
      if left and right and top and bottom then
        local horizontalInset = (right - left) * 0.04
        local verticalInset = (bottom - top) * 0.04
        coords = {
          left + horizontalInset,
          right - horizontalInset,
          top + verticalInset,
          bottom - verticalInset,
        }
      end
    end
    if texture then
      return texture, coords
    end
  end
  return "Interface\\Icons\\INV_Misc_QuestionMark", nil
end

local function isProtected(frame)
  return call(frame, "IsProtected") and true or false
end

local function isShown(frame)
  return call(frame, "IsShown") and true or false
end

function Discovery:IsEligible(frame, hiddenButtons)
  if not isButton(frame) or isProtected(frame) then
    return false
  end

  local name = getName(frame)
  if name and EXCLUDED_BUTTONS[name] then
    return false
  end

  if not isShown(frame) and not (hiddenButtons and hiddenButtons[frame]) then
    return false
  end

  return true
end

function Discovery:GetEntries(hiddenButtons)
  local minimap = _G.Minimap
  if not minimap or type(minimap.GetChildren) ~= "function" then
    return {}
  end

  local entries = {}
  local children = { minimap:GetChildren() }
  for index = 1, #children do
    local button = children[index]
    if self:IsEligible(button, hiddenButtons) then
      local name = getName(button)
      local label = getLabel(button, name)
      if label then
        local texture, coords = getIcon(button)
        entries[#entries + 1] = {
          button = button,
          label = label,
          texture = texture,
          coords = coords,
        }
      end
    end
  end

  table.sort(entries, function(left, right)
    return left.label:lower() < right.label:lower()
  end)
  return entries
end
