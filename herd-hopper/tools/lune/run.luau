-- Lance tests/pure.spec.luau avec Lune :  lune run tools/lune/run.luau
-- (nécessite Lune ; Vector3/Color3 viennent de @lune/roblox)
local roblox = require("@lune/roblox")
local fs = require("@lune/fs")

_G.Vector3 = roblox.Vector3
_G.Color3 = roblox.Color3
Vector3 = roblox.Vector3
Color3 = roblox.Color3

local function load(path)
	local fn = assert(loadstring(fs.readFile(path), "=" .. path))
	return fn()
end

local Config = load("src/shared/Config.luau")
local Species = load("src/shared/Species.luau")
local Util = load("src/shared/Util.luau")
local spec = load("tests/pure.spec.luau")
local failures, passed = spec(Config, Species, Util)
print(("Lune : %d réussis, %d échecs"):format(passed, failures))
if failures > 0 then
	error("tests en échec")
end
