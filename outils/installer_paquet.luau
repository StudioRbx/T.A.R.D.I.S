-- Installe le paquet TARDIS_MiseAJour (outils/paquet_studio.py) : à coller dans la barre de commande de Studio, en mode Édition,
-- après avoir inséré le fichier .rbxmx dans Workspace. Seuls les scripts qui diffèrent sont réécrits ; chacun est vérifié par son empreinte.
local paquet = workspace:FindFirstChild("TARDIS_MiseAJour")
assert(paquet, "Insère d'abord le fichier TARDIS_MiseAJour_V….rbxmx dans Workspace (clic droit › Insert from File…)")
local HttpService, SES = game:GetService("HttpService"), game:GetService("ScriptEditorService")
local infos = HttpService:JSONDecode(string.match(paquet._manifeste.Source, "%[==%[(.*)%]==%]"))
local function empreinte(s) local h = 0 for i = 1, #s do h = (h * 31 + s:byte(i)) % 2147483647 end return h end
local function trouver(chemin)
	local objet = game
	for nom in string.gmatch(chemin, "[^/]+") do
		if objet == game then objet = game:GetService(nom) else objet = objet and objet:FindFirstChild(nom) end
		if not objet then return nil end
	end
	return objet
end
local function parentsDe(e)
	if not e.parTardis then return { trouver(e.parent) } end
	local liste = {}
	for _, dossier in (workspace:FindFirstChild("TARDIS") and workspace.TARDIS:GetChildren() or {}) do
		local ext = dossier:IsA("Folder") and dossier:FindFirstChild("EXTERIEURE")
		local p = ext and ext:FindFirstChildWhichIsA("Model")
		for nom in string.gmatch(string.match(e.parent, "EXTERIEURE/(.*)$") or "", "[^/]+") do p = p and p:FindFirstChild(nom) end
		if ext then table.insert(liste, p or false) end
	end
	return liste
end
local rapport, erreurs, changes, connus = {}, 0, 0, {}
for _, e in infos.entrees do
	local source = paquet[e.cle].Source
	connus[e.parent .. "/" .. e.nom] = true
	if #source ~= e.taille or empreinte(source) ~= e.empreinte then
		erreurs += 1 table.insert(rapport, "ERREUR paquet abîmé : " .. e.fichier) continue
	end
	for _, parent in parentsDe(e) do
		if not parent then erreurs += 1 table.insert(rapport, "ERREUR parent introuvable : " .. e.parent) continue end
		local s = parent:FindFirstChild(e.nom)
		if s and s.ClassName ~= e.classe then
			erreurs += 1 table.insert(rapport, "ERREUR type : " .. s:GetFullName() .. " est un " .. s.ClassName .. ", attendu " .. e.classe) continue
		end
		local nouveau = s == nil
		if nouveau then s = Instance.new(e.classe) s.Name = e.nom s.Parent = parent end
		if s.Source ~= source then
			SES:UpdateSourceAsync(s, function() return source end)
			changes += 1
			table.insert(rapport, (nouveau and "créé : " or "mis à jour : ") .. s:GetFullName())
		end
		if empreinte(s.Source) ~= e.empreinte then erreurs += 1 table.insert(rapport, "ERREUR vérification : " .. s:GetFullName()) end
	end
end
for _, chemin in infos.supprimer do
	local objet = trouver(chemin)
	if objet then objet:Destroy() table.insert(rapport, "supprimé : " .. chemin) end
end
-- Scripts « Tardis… » présents dans Studio mais absents du dépôt : signalés, jamais supprimés
for _, racine in { "ServerScriptService", "ReplicatedStorage", "StarterPlayer/StarterPlayerScripts" } do
	local r = trouver(racine)
	for _, enfant in (r and r:GetChildren() or {}) do
		if enfant:IsA("LuaSourceContainer") and string.sub(enfant.Name, 1, 6) == "Tardis" and not connus[racine .. "/" .. enfant.Name] then
			table.insert(rapport, "à vérifier (absent du dépôt) : " .. enfant:GetFullName())
		end
	end
end
if erreurs == 0 then paquet:Destroy() end
table.insert(rapport, string.format("TARDIS V%s : %d scripts dans le paquet, %d réécrit(s), %d erreur(s)%s", infos.version, #infos.entrees,
	changes, erreurs, erreurs == 0 and " — paquet retiré, pense à enregistrer (Ctrl+S)" or " — paquet gardé dans Workspace"))
print(table.concat(rapport, "\n"))
