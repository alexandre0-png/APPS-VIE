-- ModuleScript : ServerScriptService/Diag
-- Classement pur des erreurs de services Roblox (testé hors Roblox). Aucune dépendance.
local Diag = {}

-- Studio sans « Enable Studio Access to API Services » : DataStore refusé, inutile de réessayer.
function Diag.isStudioApiError(err)
	local s = tostring(err)
	return s:find("StudioAccessToApisNotAllowed", 1, true) ~= nil
		or s:find("API access is not enabled", 1, true) ~= nil
		or s:find("Studio access to APIs is not allowed", 1, true) ~= nil
end

return Diag
