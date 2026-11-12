-- Compile chaque script avec le vrai compilateur Luau (sans l'exécuter) :  lune run tools/lune/syntax.luau
local fs = require("@lune/fs")

local failures, count = 0, 0
local function scan(dir)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			scan(path)
		elseif name:match("%.luau$") then
			count += 1
			local fn, err = loadstring(fs.readFile(path), "=" .. path)
			if not fn then
				failures += 1
				print("ERREUR " .. tostring(err))
			end
		end
	end
end

scan("src")
print(("Compilation Luau : %d fichiers, %d erreurs"):format(count, failures))
if failures > 0 then
	error("erreurs de syntaxe")
end
