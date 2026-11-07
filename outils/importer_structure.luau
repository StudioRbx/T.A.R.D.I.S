-- Importe la structure du TARDIS (dossier structure/ du dépôt public StudioRbx/T.A.R.D.I.S) dans la map ouverte.
-- À coller dans la barre de commande de Studio (View › Command Bar), en mode Édition, puis Entrée.
-- Chaque fichier .rbxm est téléchargé, vérifié (taille et empreinte) puis chargé dans ServerStorage › TARDIS_Structure_V<version>.
-- PLACER = true : chaque objet est aussi mis à sa place (parent de structure/index.json). Ce qui s'y trouve déjà sous le même nom
-- est déplacé dans ServerStorage › TARDIS_Sauvegarde_<date>, jamais supprimé. Les destinations (TARDIS_DESTINATIONS) sont propres
-- à chaque map : elles ne sont mises à leur place que si PLACER_DESTINATIONS = true.
-- Les scripts du système (src/) ne sont pas dans structure/ : les mettre à jour avec outils/synchro_github.luau.
local BRANCHE = "main"
local PLACER = false
local PLACER_DESTINATIONS = false
local DEPOT = "StudioRbx/T.A.R.D.I.S"

local HttpService, SerializationService = game:GetService("HttpService"), game:GetService("SerializationService")
local ServerStorage = game:GetService("ServerStorage")
local httpAvant = HttpService.HttpEnabled
pcall(function() HttpService.HttpEnabled = true end) -- le temps de l'import (remis comme avant à la fin)
local function lire(url) return HttpService:GetAsync(url .. (string.find(url, "?", 1, true) and "&" or "?") .. "t=" .. os.clock(), true) end
local function empreinte(s)
	local h = 0
	for i = 1, #s do
		h = (h * 31 + s:byte(i)) % 2147483647
		if i % 500000 == 0 then task.wait() end
	end
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
local function dossier(parent, nom)
	local d = parent:FindFirstChild(nom)
	if not d then d = Instance.new("Folder") d.Name = nom d.Parent = parent end
	return d
end

local rapport, erreurs = {}, 0
local ok, err = pcall(function()
	local okRef, commit = pcall(function()
		return HttpService:JSONDecode(lire("https://api.github.com/repos/" .. DEPOT .. "/commits/" .. BRANCHE))
	end)
	local ref = okRef and commit and commit.sha or BRANCHE
	local base = "https://raw.githubusercontent.com/" .. DEPOT .. "/" .. ref .. "/"
	local index = HttpService:JSONDecode(lire(base .. "structure/index.json"))
	table.insert(rapport, string.format("Dépôt %s, branche %s, commit %s, structure V%s", DEPOT, BRANCHE, string.sub(ref, 1, 7), index.version))
	local cible = dossier(ServerStorage, "TARDIS_Structure_V" .. index.version)
	local sauvegarde
	for _, f in index.fichiers do
		local okData, data = pcall(lire, base .. f.fichier)
		if not okData or #data ~= f.octets or empreinte(data) ~= f.empreinte then
			erreurs += 1 table.insert(rapport, "ERREUR téléchargement : " .. f.fichier) continue
		end
		local okObj, objets = pcall(function() return SerializationService:DeserializeInstancesAsync(buffer.fromstring(data)) end)
		local racine = okObj and objets[1]
		if not racine or #racine:GetDescendants() ~= f.descendants then
			erreurs += 1 table.insert(rapport, "ERREUR lecture : " .. f.fichier) continue
		end
		local copie = cible:FindFirstChild(f.parent .. "/" .. f.nom)
		if copie then copie:Destroy() end -- ancienne copie de cet import (dans le dossier de l'import seulement)
		racine.Name = f.parent .. "/" .. f.nom
		racine.Parent = cible
		table.insert(rapport, string.format("chargé : %s (%d descendants)", f.fichier, f.descendants))
		if PLACER and (f.nom ~= "TARDIS_DESTINATIONS" or PLACER_DESTINATIONS) then
			local parent = trouver(f.parent)
			if not parent then
				local p = game
				for nom in string.gmatch(f.parent, "[^/]+") do p = (p == game) and game:GetService(nom) or dossier(p, nom) end
				parent = p
			end
			local ancien = parent:FindFirstChild(f.nom)
			if ancien then
				sauvegarde = sauvegarde or dossier(ServerStorage, "TARDIS_Sauvegarde_" .. os.date("%Y%m%d_%H%M%S"))
				ancien.Name = f.parent .. "/" .. f.nom
				ancien.Parent = sauvegarde
				table.insert(rapport, "ancien mis de côté : " .. sauvegarde:GetFullName() .. " › " .. ancien.Name)
			end
			local place = racine:Clone()
			place.Name = f.nom
			-- Map en Streaming (V6.9.17) : les pièces de l'intérieur sont rangées dans un Model Persistent « <TARDIS>_INTERIEURE »,
			-- sinon le client ne reçoit que les pièces proches de lui et le menu (T) et la tablette (Y) ne s'ouvrent pas
			if workspace.StreamingEnabled and f.nom == "INTERIEURE" and (place:FindFirstChild("Portail") or place:FindFirstChild("Rotor")) then
				local modele = Instance.new("Model")
				modele.Name = parent.Name .. "_INTERIEURE"
				modele.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
				for _, enfant in place:GetChildren() do enfant.Parent = modele end
				modele.Parent = place
				modele.WorldPivot = CFrame.new((modele:GetBoundingBox()).Position)
				table.insert(rapport, "streaming : intérieur rangé dans le Model Persistent " .. modele.Name)
			end
			place.Parent = parent
			table.insert(rapport, "placé : " .. place:GetFullName())
		end
	end
	table.insert(rapport, string.format("Structure V%s : %d fichier(s), %d erreur(s)%s", index.version, #index.fichiers, erreurs,
		erreurs == 0 and " — pense à enregistrer (Ctrl+S)" or ""))
end)
pcall(function() HttpService.HttpEnabled = httpAvant end)
if not ok then table.insert(rapport, "ERREUR : " .. tostring(err)) end
print("[TARDIS] import de la structure\n  " .. table.concat(rapport, "\n  "))
