local _, AP = ...
AP = AP or _G.WotLKPlus or _G.AscensionPlus

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
  WotLKPlusMinimapPaletteButton = true,
  LibDBIcon10_WotLKPlus = true,
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
  local normal = call(frame, "GetNormalTexture") or frame.icon or frame.Icon
  local texture
  local coords
  if type(normal) == "string" then
    texture = normal
  elseif normal then
    texture = call(normal, "GetTexture")
    local left, right, top, bottom = call(normal, "GetTexCoord")
    if left and right and top and bottom then
      coords = { left, right, top, bottom }
    end
  end

  if not texture and type(frame.icon) == "string" then
    texture = frame.icon
  end
  return texture or "Interface\\Icons\\INV_Misc_QuestionMark", coords
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
