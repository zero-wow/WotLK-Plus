local root = (... and ... ~= "" and ...) or "."

local values = {}
local pages = {
  general = { id = "general", title = "Overview" },
  banking = { id = "banking", title = "Banking" },
  ["banking.sorter"] = { id = "banking.sorter", parent = "banking", title = "Sorter" },
}

_G.AscensionPlus = {
  UI = { Theme = {} },
  ConfigRegistry = {
    GetPage = function(_, pageId) return pages[pageId] end,
  },
  Database = {
    Get = function(_, path, fallback)
      local value = values[path]
      return value == nil and fallback or value
    end,
    Set = function(_, path, value) values[path] = value end,
  },
  Utils = {
    Trim = function(value) return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "") end,
  },
}

dofile(root .. "/ui/ConfigWindow.lua")
local Window = AscensionPlus.ConfigWindow

local searchBox = { text = "banking" }
function searchBox:GetText() return self.text end
function searchBox:SetText(value) self.text = value end

Window.frame = {
  SearchBox = searchBox,
  SetScript = function() end,
}
Window.pendingSearchQuery = "banking"
Window.searchQuery = ""
Window:SelectPage("general", true)
assert(searchBox.text == "" and Window.pendingSearchQuery == nil,
  "page selection must clear visible text from an uncommitted debounced search")

Window.frame = nil
Window.selectedPageId = "banking.sorter"
Window.lastExplicitPageId = "banking.sorter"
Window.expanded.banking = true
Window:TogglePage("banking")
assert(Window.expanded.banking == false and Window.selectedPageId == "banking",
  "collapsing the selected page's ancestor must leave a visible selected row")

io.write("PASS config search debounce and collapsed-selection state remain coherent\n")
