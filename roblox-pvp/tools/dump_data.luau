--!nonstrict
-- Exporte Config, Weapons, Lore, QuestLogic (JSON sur la sortie standard) pour générer docs/maquette.html.
-- Usage : luau tools/dump_data.luau   (depuis un dossier contenant .emit, voir tools/build_maquette.py)
local function enc(v, indent)
	local t = type(v)
	if t == "string" then
		return '"' .. v:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n") .. '"'
	elseif t == "number" or t == "boolean" then
		return tostring(v)
	elseif t == "table" then
		local isArray = #v > 0 or next(v) == nil
		local parts = {}
		if isArray then
			for _, x in ipairs(v) do table.insert(parts, enc(x)) end
			return "[" .. table.concat(parts, ",") .. "]"
		end
		local keys = {}
		for k in pairs(v) do table.insert(keys, tostring(k)) end
		table.sort(keys)
		for _, k in ipairs(keys) do
			local val = v[k]
			if val == nil then val = v[tonumber(k)] end
			table.insert(parts, '"' .. k .. '":' .. enc(val))
		end
		return "{" .. table.concat(parts, ",") .. "}"
	end
	return "null"
end
local base = "../.emit/ReplicatedStorage/Shared/"
local out = {
	Config = require(base .. "Config"),
	Weapons = require(base .. "Weapons").List,
	Lore = { Intro = require(base .. "Lore").Intro, Heroes = require(base .. "Lore").Heroes, Chapters = require(base .. "Lore").Chapters, Runes = require(base .. "Lore").Runes },
	Quests = require(base .. "QuestLogic").Pool,
	Cin = require(base .. "CinematicLogic").Sequences,
}
print(enc(out))
