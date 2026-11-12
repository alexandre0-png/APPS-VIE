-- Lance tests/pure.spec.luau avec Lune :  lune run tools/lune/run.luau
-- (nécessite Lune ; Vector3/Color3 viennent de @lune/roblox)
local roblox = require("@lune/roblox")
local fs = require("@lune/fs")

_G.Vector3 = roblox.Vector3
_G.Color3 = roblox.Color3
Vector3 = roblox.Vector3
Color3 = roblox.Color3

local function load(path, env)
	local fn = assert(loadstring(fs.readFile(path), "=" .. path))
	if env then
		setfenv(fn, setmetatable(env, { __index = getfenv(0) }))
	end
	return fn()
end

local Config = load("src/shared/Config.luau")
local Species = load("src/shared/Species.luau")
local Util = load("src/shared/Util.luau")
-- Zoo.luau fait require(script.Parent.Config) : on fournit un `script` et un `require` factices.
local Zoo = load("src/shared/Zoo.luau", {
	script = { Parent = { Config = Config, Species = Species } },
	require = function(module)
		return module
	end,
})
local spec = load("tests/pure.spec.luau")
local failures, passed = spec(Config, Species, Util, Zoo)
print(("Lune : %d réussis, %d échecs"):format(passed, failures))
if failures > 0 then
	error("tests en échec")
end
