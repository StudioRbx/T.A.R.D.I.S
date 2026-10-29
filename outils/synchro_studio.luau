-- Synchronise Studio avec le dépôt (à coller dans la barre de commande de Studio, en mode Édition).
-- Prérequis : depuis la racine du dépôt,
--   python outils/manifeste.py
--   python -m http.server 35001 --bind 127.0.0.1
-- Chaque script est comparé à son empreinte ; seuls ceux qui diffèrent sont réécrits.
local BASE = "http://127.0.0.1:35001/"
local HttpService = game:GetService("HttpService")
local SES = game:GetService("ScriptEditorService")

local function empreinte(s)
	local h = 0
	for i = 1, #s do h = (h * 31 + s:byte(i)) % 2147483647 end
	return h
end

local function trouver(chemin)
	local objet = game
	for nom in string.gmatch(chemin, "[^/]+") do
		if objet == game then objet = game:GetService(nom) else objet = objet and objet:FindFirstChild(nom) end
		if not objet then return nil end
	end
	return objet
end

local manifeste = HttpService:JSONDecode(HttpService:GetAsync(BASE .. "outils/manifeste.json?" .. os.clock()))
local rapport, erreurs = {}, 0

-- Parents à mettre à jour : les scripts « par TARDIS » vont dans chaque TARDIS_n
local function parentsDe(entree)
	if not entree.parTardis then return { trouver(entree.parent) } end
	local liste = {}
	for _, dossier in workspace.TARDIS:GetChildren() do
		if dossier:IsA("Folder") and dossier:FindFirstChild("EXTERIEURE") then
			local exterieur = dossier.EXTERIEURE:FindFirstChildWhichIsA("Model")
			local reste = string.match(entree.parent, "EXTERIEURE/(.*)$")
			local p = exterieur
			for nom in string.gmatch(reste or "", "[^/]+") do p = p and p:FindFirstChild(nom) end
			table.insert(liste, p)
		end
	end
	return liste
end

for _, entree in manifeste.entrees do
	local source = HttpService:GetAsync(BASE .. entree.fichier .. "?" .. os.clock())
	if #source ~= entree.taille or empreinte(source) ~= entree.empreinte then
		erreurs += 1
		table.insert(rapport, "ERREUR téléchargement : " .. entree.fichier)
		continue
	end
	for _, parent in parentsDe(entree) do
		if not parent then
			erreurs += 1
			table.insert(rapport, "ERREUR parent introuvable : " .. entree.parent)
			continue
		end
		local script = parent:FindFirstChild(entree.nom)
		if script and script.ClassName ~= entree.classe then
			erreurs += 1
			table.insert(rapport, "ERREUR type : " .. script:GetFullName() .. " est un " .. script.ClassName)
			continue
		end
		local nouveau = script == nil
		if nouveau then
			script = Instance.new(entree.classe)
			script.Name = entree.nom
			script.Parent = parent
		end
		if script.Source ~= source then
			SES:UpdateSourceAsync(script, function() return source end)
			table.insert(rapport, (nouveau and "créé : " or "mis à jour : ") .. script:GetFullName())
		end
		if empreinte(script.Source) ~= entree.empreinte then
			erreurs += 1
			table.insert(rapport, "ERREUR vérification : " .. script:GetFullName())
		end
	end
end

for _, chemin in manifeste.supprimer do
	local objet = trouver(chemin)
	if objet then
		objet:Destroy()
		table.insert(rapport, "supprimé : " .. chemin)
	end
end

table.insert(rapport, string.format("%d scripts vérifiés, %d erreur(s)", #manifeste.entrees, erreurs))
return table.concat(rapport, "\n")
