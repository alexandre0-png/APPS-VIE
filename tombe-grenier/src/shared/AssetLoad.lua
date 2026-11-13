--[[
  AssetLoad : installation sûre de modèles chargés (sans objet Roblox direct : testable).
  - Un modèle invalide (conteneur vide, sans Model, sans pièce) est refusé : rien n'est installé.
  - Les scripts, RemoteEvent et BindableEvent présents dans un modèle sont retirés.
  - Un chargement qui échoue ne fait jamais planter : l'entrée est simplement notée comme échec.
  La progression ne dépend jamais d'un modèle : ces objets sont décoratifs.
]]
local AssetLoad = {}

local UNSAFE = {
	Script = true,
	LocalScript = true,
	ModuleScript = true,
	RemoteEvent = true,
	BindableEvent = true,
}

-- Retire les objets dangereux du modèle. Retourne le nombre retiré.
function AssetLoad.sanitize(model)
	local removed = 0
	for _, d in ipairs(model:GetDescendants()) do
		if UNSAFE[d.ClassName] then
			d:Destroy()
			removed = removed + 1
		end
	end
	return removed
end

-- entries : liste de { name = "...", id = number }. loadFn(id) retourne un conteneur (ou nil).
-- folder : dossier où ranger les modèles, sous leur nom. Retourne { ok = {names}, failed = {names} }.
function AssetLoad.install(entries, loadFn, folder)
	local report = { ok = {}, failed = {} }
	for _, e in ipairs(entries) do
		local okLoad, container = pcall(loadFn, e.id)
		local model = nil
		if okLoad and container then
			model = container:FindFirstChildWhichIsA("Model", true)
		end
		local valid = model ~= nil and #model:GetDescendants() > 0
		if valid then
			AssetLoad.sanitize(model)
			model.Name = e.name
			model.Parent = folder
			table.insert(report.ok, e.name)
		else
			table.insert(report.failed, e.name)
		end
		if okLoad and container then
			container:Destroy()
		end
	end
	return report
end

return AssetLoad
