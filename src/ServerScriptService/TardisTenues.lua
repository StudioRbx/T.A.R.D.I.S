-- ServerScriptService > TardisTenues (ModuleScript, V6.9.10.5)
-- Tenues de Config.Tenues (casiers, régénération) : les nombres « shirt » et « pant » sont les identifiants des vêtements
-- du CATALOGUE (ceux de la page de l'objet), pas ceux de leur image. Un ShirtTemplate « rbxassetid://<id du catalogue> »
-- ne s'affiche pas (il faut l'image du vêtement) : le joueur se retrouvait sans haut ni bas, la peau seule.
-- Ce module retrouve l'image de chaque vêtement, sur le serveur seulement :
--   1. InsertService:LoadAsset(id) rend un Model qui contient le Shirt (ou les Pants) du catalogue : on garde son
--      ShirtTemplate (PantsTemplate). Une fois par identifiant pour la session, 3 essais (le service échoue parfois) ;
--   2. l'objet chargé ne contient ni Shirt ni Pants (ce n'est pas un vêtement) : l'identifiant est essayé tel quel comme
--      image (une image déjà mise en ligne, ou l'image d'un Decal) ;
--   3. sinon, en dernier recours, le vêtement est mis par une HumanoidDescription (qui prend, elle, les identifiants du
--      catalogue), et l'image obtenue est retenue.
-- Les images trouvées sont publiées pour l'aperçu des joueurs (attributs Config.cleVetement du dossier ReplicatedStorage ›
-- TardisAssets › Tenues). Le client ne fait que l'aperçu : la tenue gardée est toujours mise par le serveur. Accessoires,
-- corps et visage du joueur ne changent pas. Une tenue introuvable : le joueur garde ses vêtements.
-- Au démarrage, une seule ligne dans l'Output, et seulement si des identifiants n'ont pas pu être résolus.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("TardisConfig"))

local Tenues = {}
local GENRES = { Shirt = "ShirtTemplate", Pants = "PantsTemplate" }
local ESSAIS = 3 -- un essai, puis deux de plus
local cache = {} -- [« Shirt_123 »] = image (texte rbxassetid) ou false (introuvable)
local enCours = {} -- [« Shirt_123 »] = true pendant la recherche (les autres demandes l'attendent)
local demarre = false

-- Le service qui charge les objets du catalogue (remplaçable pour les simulations)
local function service()
	return game:GetService("InsertService")
end

local function dossierApercu()
	local assets = ReplicatedStorage:FindFirstChild("TardisAssets")
	if not assets then
		assets = Instance.new("Folder")
		assets.Name = "TardisAssets"
		assets.Parent = ReplicatedStorage
	end
	local dossier = assets:FindFirstChild("Tenues")
	if not dossier then
		dossier = Instance.new("Folder")
		dossier.Name = "Tenues"
		dossier.Parent = assets
	end
	return dossier
end

-- Publie l'image d'un vêtement pour l'aperçu des joueurs ("" = introuvable)
local function publier(cle, image)
	dossierApercu():SetAttribute(cle, image or "")
end

-- Charge un objet du catalogue et y cherche l'image du vêtement : image, ou nil et la raison
local function chargerImage(genre, id)
	local derniereErreur = nil
	for essai = 1, ESSAIS do
		local ok, modele = pcall(function() return service():LoadAsset(id) end)
		if ok and typeof(modele) == "Instance" then
			local vetement = modele:IsA(genre) and modele or modele:FindFirstChildWhichIsA(genre, true)
			local image = vetement and vetement[GENRES[genre]] or nil
			local decal = (not vetement) and modele:FindFirstChildWhichIsA("Decal", true) or nil
			local texture = decal and decal.Texture or nil
			modele:Destroy()
			if type(image) == "string" and image ~= "" then return image end
			if vetement then return nil, "vêtement sans image" end
			-- Pas un vêtement : l'identifiant est essayé tel quel comme image (ou l'image du Decal)
			if type(texture) == "string" and texture ~= "" then return texture end
			return "rbxassetid://" .. string.format("%d", id)
		end
		derniereErreur = modele
		if essai < ESSAIS then task.wait(0.5 * essai) end
	end
	return nil, tostring(derniereErreur or "chargement impossible")
end

-- Image d'un vêtement (genre = "Shirt" ou "Pants") : le texte rbxassetid de l'image, ou nil (introuvable). Gardée pour la
-- session ; deux demandes en même temps ne chargent qu'une fois.
function Tenues.image(genre, valeur)
	local cle = Config.cleVetement(genre, valeur)
	if not cle or not GENRES[genre] then return nil end
	while enCours[cle] do task.wait(0.1) end
	if cache[cle] ~= nil then return cache[cle] or nil end
	enCours[cle] = true
	local image = chargerImage(genre, Config.idVetement(valeur))
	cache[cle] = image or false
	enCours[cle] = nil
	publier(cle, image)
	return image
end

-- Retient une image trouvée autrement (HumanoidDescription) : l'aperçu des joueurs en profite
local function retenir(genre, valeur, image)
	local cle = Config.cleVetement(genre, valeur)
	if cle and type(image) == "string" and image ~= "" then
		cache[cle] = image
		publier(cle, image)
	end
end

local function habits(personnage)
	return personnage:FindFirstChildOfClass("Shirt"), personnage:FindFirstChildOfClass("Pants")
end
local function poser(personnage, classe, propriete, image)
	local objet = personnage:FindFirstChildOfClass(classe)
	if not objet then
		objet = Instance.new(classe)
		objet.Name = classe
		objet.Parent = personnage
	end
	objet[propriete] = image
end

-- Met une tenue de Config.Tenues sur un personnage (serveur). Renvoie vrai si le haut et le bas sont mis ; sinon faux et
-- la raison, et le personnage garde exactement ses vêtements.
function Tenues.appliquer(personnage, tenue)
	if typeof(personnage) ~= "Instance" or type(tenue) ~= "table" then return false, "tenue inconnue" end
	local humanoid = personnage:FindFirstChildOfClass("Humanoid")
	if not humanoid then return false, "pas de personnage" end
	local haut, bas = Tenues.image("Shirt", tenue.shirt), Tenues.image("Pants", tenue.pant)
	if not personnage.Parent then return false, "personnage disparu" end
	if haut and bas then
		poser(personnage, "Shirt", "ShirtTemplate", haut)
		poser(personnage, "Pants", "PantsTemplate", bas)
		return true
	end
	-- Dernier recours : HumanoidDescription (identifiants du catalogue), en gardant tout le reste de l'avatar
	local idHaut, idBas = Config.idVetement(tenue.shirt), Config.idVetement(tenue.pant)
	if not idHaut or not idBas then return false, "identifiants invalides" end
	local shirt, pants = habits(personnage)
	local avant = { shirt = shirt and shirt.ShirtTemplate, pants = pants and pants.PantsTemplate }
	local ok = pcall(function()
		local description = humanoid:GetAppliedDescription()
		description.Shirt = idHaut
		description.Pants = idBas
		humanoid:ApplyDescription(description)
	end)
	shirt, pants = habits(personnage)
	local imageHaut, imageBas = shirt and shirt.ShirtTemplate or "", pants and pants.PantsTemplate or ""
	if ok and imageHaut ~= "" and imageBas ~= "" then
		retenir("Shirt", tenue.shirt, imageHaut)
		retenir("Pants", tenue.pant, imageBas)
		return true
	end
	-- Échec : les vêtements d'avant sont remis tels quels
	if avant.shirt then poser(personnage, "Shirt", "ShirtTemplate", avant.shirt) elseif shirt then shirt:Destroy() end
	if avant.pants then poser(personnage, "Pants", "PantsTemplate", avant.pants) elseif pants then pants:Destroy() end
	return false, "vêtements introuvables"
end

-- Une seule fois par serveur : toutes les tenues sont résolues au démarrage (l'aperçu est prêt quand un joueur ouvre un
-- casier), puis une ligne dans l'Output si des identifiants n'ont rien donné.
function Tenues.demarrer()
	if demarre then return end
	demarre = true
	dossierApercu()
	task.spawn(function()
		local echecs = {}
		-- (V6.9.14) Les tenues en attente (identifiants à 0) sont ignorées sans rien dire ; les uniformes des équipes
		-- (Config.uniformeDe) sont résolus avec les tenues
		local aResoudre = {}
		for _, tenue in Config.Tenues or {} do table.insert(aResoudre, tenue) end
		for _, nomEquipe in { Config.nomEquipe(), (Config.EquipeTechnique or {}).Nom } do
			local uniforme = Config.uniformeDe(nomEquipe)
			if uniforme then table.insert(aResoudre, uniforme) end
		end
		for _, tenue in aResoudre do
			if Config.tenueDisponible(tenue) then
				for _, info in { { "Shirt", tenue.shirt, "haut" }, { "Pants", tenue.pant, "bas" } } do
					if not Tenues.image(info[1], info[2]) then
						local id = Config.idVetement(info[2])
						table.insert(echecs, string.format("%s (%s %s)", tostring(tenue.nom), info[3], id and string.format("%d", id) or tostring(info[2])))
					end
				end
			end
		end
		if #echecs > 0 then
			warn("[TARDIS] Tenues : vêtements introuvables dans le catalogue : " .. table.concat(echecs, ", ")
				.. ". Vérifie leurs identifiants dans Config.Tenues (si rien ne marche, le joueur garde ses vêtements).")
		end
	end)
end

return Tenues
