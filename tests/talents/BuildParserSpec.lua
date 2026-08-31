local root = (... and ... ~= "" and ...) or "."

_G.Levo = { TalentImport = {} }
dofile(root .. "/modules/talents/BuildParser.lua")

local Parser = _G.Levo.TalentImport.BuildParser
local build = assert(Parser:Parse(":5008t1:6261t2:6298t2:31230t1:"))

assert(#build.targets == 4, "every build target must be parsed")
assert(build.targets[1].id == 5008 and build.targets[1].rank == 1, "target ordering must be preserved")
assert(build.byID[6261].rank == 2, "requested rank must be retained")
assert(build.byID[31230].order == 4, "target order must remain stable")

local merged = assert(Parser:Parse(":11t1:12t2:11t3:"))
assert(#merged.targets == 2, "duplicate entries must not create duplicate work")
assert(merged.targets[1].rank == 3, "duplicate entries must retain the highest requested rank")
assert(not Parser:Parse("this is not an Ascension build"), "invalid input must be rejected")

print("BuildParserSpec: OK")
