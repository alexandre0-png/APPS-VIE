--!nocheck
-- Lanceur Lune du lot 13 : `PATH=...:$PATH lune run roblox/tests/run_lot13.luau` depuis la racine du dépôt (ou de la copie patchée).
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local passed, failed = 0, 0
local function suite(name)
	print("  > " .. name)
end
local function check(name, cond)
	if cond then
		passed += 1
	else
		failed += 1
		print("  ECHEC : " .. name)
	end
end
local lot13 = luau.load(fs.readFile("roblox/tests/lot13.luau"), { debugName = "lot13" })()
lot13({ check = check, suite = suite, luau = luau, fs = fs })
print(string.format("%d assertions réussies, %d échecs", passed, failed))
process.exit(failed == 0 and 0 or 1)
