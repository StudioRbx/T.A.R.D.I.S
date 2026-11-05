-- Met Studio à jour directement depuis GitHub (dépôt public StudioRbx/T.A.R.D.I.S). À coller dans la barre de commande de
-- Studio (View › Command Bar), en mode Édition, puis Entrée. Rien à installer ni à télécharger à la main.
-- BRANCHE : "main" = version publiée ; une autre branche = version en cours de test.
-- Seuls les scripts qui diffèrent sont réécrits ; chacun est vérifié par son empreinte. Les scripts « Tardis… » de Studio
-- absents du dépôt sont signalés, jamais supprimés.
local BRANCHE = "main"
local DEPOT = "StudioRbx/T.A.R.D.I.S"

local HttpService, SES = game:GetService("HttpService"), game:GetService("ScriptEditorService")
local httpAvant = HttpService.HttpEnabled
pcall(function() HttpService.HttpEnabled = true end) -- le temps de la synchro (remis comme avant à la fin)
local function lire(url) return HttpService:GetAsync(url .. (string.find(url, "?", 1, true) and "&" or "?") .. "t=" .. os.clock(), true) end
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
local ok, err = pcall(function()
	-- Le commit exact de la branche : évite le cache de quelques minutes des fichiers bruts de GitHub
	local okRef, commit = pcall(function()
		return HttpService:JSONDecode(lire("https://api.github.com/repos/" .. DEPOT .. "/commits/" .. BRANCHE))
	end)
	local ref = okRef and commit and commit.sha or BRANCHE
	local base = "https://raw.githubusercontent.com/" .. DEPOT .. "/" .. ref .. "/"
	local manifeste = HttpService:JSONDecode(lire(base .. "outils/manifeste.json"))
	table.insert(rapport, string.format("Dépôt %s, branche %s, commit %s", DEPOT, BRANCHE, string.sub(ref, 1, 7)))
	for _, e in manifeste.entrees do
		connus[e.parent .. "/" .. e.nom] = true
		local okSource, source = pcall(lire, base .. e.fichier)
		if not okSource or #source ~= e.taille or empreinte(source) ~= e.empreinte then
			erreurs += 1 table.insert(rapport, "ERREUR téléchargement : " .. e.fichier) continue
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
	for _, chemin in manifeste.supprimer do
		local objet = trouver(chemin)
		if objet then objet:Destroy() table.insert(rapport, "supprimé : " .. chemin) end
	end
	for _, racine in { "ServerScriptService", "ReplicatedStorage", "StarterPlayer/StarterPlayerScripts" } do
		local r = trouver(racine)
		for _, enfant in (r and r:GetChildren() or {}) do
			if enfant:IsA("LuaSourceContainer") and string.sub(enfant.Name, 1, 6) == "Tardis" and not connus[racine .. "/" .. enfant.Name] then
				table.insert(rapport, "à vérifier (absent du dépôt) : " .. enfant:GetFullName())
			end
		end
	end
	table.insert(rapport, string.format("TARDIS V%s : %d scripts, %d réécrit(s), %d erreur(s)%s", manifeste.version or "?", #manifeste.entrees,
		changes, erreurs, erreurs == 0 and " — pense à enregistrer (Ctrl+S)" or ""))
end)
pcall(function() HttpService.HttpEnabled = httpAvant end)
if not ok then
	table.insert(rapport, "ÉCHEC : " .. tostring(err))
	table.insert(rapport, "Vérifie l'accès à Internet de Studio, ou utilise le paquet .rbxmx (outils/paquet_studio.py).")
end
print(table.concat(rapport, "\n"))
