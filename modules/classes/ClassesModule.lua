local _, AP = ...
AP = AP or _G.Levo or _G.WotLKPlus or _G.AscensionPlus

if AP.Compatibility
  and type(AP.Compatibility.HasCustomClasses) == "function"
  and not AP.Compatibility:HasCustomClasses() then
  return
end

local Registry = AP.ConfigRegistry

local function joinSpecNames(specs)
  local names = {}
  for index = 1, #specs do
    names[#names + 1] = specs[index].title
  end
  return table.concat(names, ", ")
end

local function buildLibrarySearchText(classes)
  local parts = { "class library classes subclasses specializations specs conquest of azeroth" }
  for index = 1, #classes do
    local classData = classes[index]
    parts[#parts + 1] = classData.title
    parts[#parts + 1] = joinSpecNames(classData.specs)
  end
  return table.concat(parts, " ")
end

AP.Modules:Register("classes", {
  order = 20,

  OnInitialize = function()
    local classes = AP.data.classes or {}

    Registry:RegisterPage({
      id = "classes",
      title = "Class Library",
      order = 1000,
      description = "Browse the current Conquest of Azeroth classes and their specializations.",
      options = function()
        return {
          {
            type = "text",
            text = "Select a class to review its specializations and available Levo features.",
          },
        }
      end,
      searchText = buildLibrarySearchText(classes),
    })

    for classIndex = 1, #classes do
      local classData = classes[classIndex]
      local classPageId = "classes." .. classData.id

      Registry:RegisterPage({
        id = classPageId,
        parent = "classes",
        title = classData.title,
        treeTitle = string.upper(classData.title),
        classToken = classData.classToken,
        treeShadow = true,
        order = classIndex,
        description = classData.description,
        searchText = "class library " .. classData.title .. " " .. joinSpecNames(classData.specs),
        options = function()
          local options = {
            {
              type = "text",
              label = "Specializations",
              text = joinSpecNames(classData.specs),
            },
          }

          return options
        end,
      })
    end
  end,
})
