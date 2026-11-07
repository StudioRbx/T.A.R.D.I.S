-- ServerScriptService > TardisDiagnostic (ModuleScript)
-- Diagnostic au démarrage : une seule ligne dans l'Output qui dit ce qui est en place pour un TARDIS
-- (pièces obligatoires, pièces optionnelles, sons, destinations), au lieu de commandes à coller.
-- Appelé par TardisServeur : print(Diagnostic(def, exterieur, interieur))

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("TardisConfig"))

-- Pièces optionnelles : chacune active une fonctionnalité
local OPTIONNELLES = {
	{ "Arrivee", "point d'arrivée des joueurs" },
	{ "LedsAlerte", "LED d'alerte ciblées" },
	{ "Diagnostic1", "écrans de diagnostic" },
	{ "Casier", "casiers à tenues" },
	{ "ConsoleSecours", "console de secours" },
	{ "Vanne", "vanne de l'incendie" },
	{ "Murs", "peinture des murs" },
	{ "Sol", "styles de sol" },
	{ "SiegeEquipage", "sièges d'équipage" },
	{ "Grille", "vapeur des grilles" },
	{ "Zones", "zones des pannes" }, -- (V6.9.12) dossier facultatif : situe les pannes (diagnostic, tablette technicien)
	{ "Structure", "brèches de la structure", "Breches" }, -- (V6.9.13) dossier « Structure » (ou « Breches ») : où s'ouvrent les brèches
	{ "FuiteAir", "fuites d'air", "Conduits" },           -- (V6.9.13) Parts « FuiteAir » (ou dossier « Conduits ») : où fuit l'air
}

-- Sons optionnels (ceux des voyages viennent de Config.Modes)
local SONS_OPTIONNELS = { "Camouflage", "Decamouflage", "Alarme", "Cloitre", "Reparation", "Chute", "Impact",
	"Moteur_Pose", "Moteur_Vol", "Moteur_Urgence", "Regeneration", "Intercom",
	"Vortex", "Frein", -- V6.9.10 : vent du vortex à bord, crissement du frein d'urgence (facultatif)
	"Panne_Vapeur", "Panne_Feu", "Panne_Grincement", "Panne_Etincelles", -- (V6.9.12) sons des pannes (facultatifs)
	"Panne_FuiteAir", "RotorBloque", "Soudure" } -- (V6.9.13) fuite d'air, rotor bloqué, soudeur (facultatifs)

local function chercherDans(racine, nom)
	return racine:FindFirstChild(nom, true) ~= nil
end

return function(def, exterieur, interieur)
	local manquantes, optionnellesAbsentes = {}, {}

	-- Obligatoires
	local obligatoires = 0
	local function exiger(ok, nom)
		obligatoires += 1
		if not ok then table.insert(manquantes, nom) end
	end
	exiger(exterieur.PrimaryPart ~= nil, "PrimaryPart (Racine) de l'extérieur")
	exiger(exterieur:FindFirstChild(Config.NomPortailExt) ~= nil, "Portail extérieur")
	exiger(exterieur:FindFirstChild(Config.NomDossierPortes) ~= nil, Config.NomDossierPortes)
	exiger(chercherDans(exterieur, Config.NomLampe), "Lampe")
	exiger(interieur:FindFirstChild(Config.NomPortailInt) ~= nil, "Portail intérieur")
	exiger(interieur:FindFirstChild(Config.NomRotor) ~= nil, "Rotor")
	-- Commandes de la console (V6.9.10.1 : les commandes de Config.CheminsFacultatifs comptent parmi les optionnelles ;
	-- les chemins sont parcourus dans l'ordre alphabétique, pour une ligne toujours identique)
	local facultatives = Config.CheminsFacultatifs or {}
	local cles, optionnelles = {}, #OPTIONNELLES
	for cle in Config.Chemins do table.insert(cles, cle) end
	table.sort(cles)
	for _, cle in cles do
		local chemin = Config.Chemins[cle]
		local objet = interieur
		for _, nom in chemin do objet = objet and objet:FindFirstChild(nom) end
		local secours = (Config.CheminsSecours or {})[cle]
		if not objet and secours then -- ancien emplacement encore en place : la commande marche
			objet = interieur
			for _, nom in secours do objet = objet and objet:FindFirstChild(nom) end
		end
		local libelle = "commande " .. cle .. " (" .. table.concat(chemin, " > ") .. ")"
		if facultatives[cle] then
			optionnelles += 1
			if objet == nil then table.insert(optionnellesAbsentes, libelle) end
		else
			exiger(objet ~= nil, libelle)
		end
	end

	-- Optionnelles
	for _, info in OPTIONNELLES do
		-- (V6.9.13) info[3] : autre nom accepté (Breches pour Structure, Conduits pour FuiteAir)
		if not chercherDans(interieur, info[1]) and not (info[3] and chercherDans(interieur, info[3])) then table.insert(optionnellesAbsentes, info[1]) end
	end

	-- Sons
	local dossierSons = ReplicatedStorage:FindFirstChild("TardisAssets") and ReplicatedStorage.TardisAssets:FindFirstChild("Sons")
	-- (sans doublons : plusieurs modes partagent les mêmes sons)
	local noms, vus, presents, sonsAbsents = {}, {}, 0, {}
	local function ajouter(nom) if not vus[nom] then vus[nom] = true table.insert(noms, nom) end end
	for _, reglages in Config.Modes do
		for _, nom in reglages.Sons do ajouter(nom) end
	end
	for _, nom in SONS_OPTIONNELS do ajouter(nom) end
	for _, nom in noms do
		if dossierSons and dossierSons:FindFirstChild(nom) then presents += 1 else table.insert(sonsAbsents, nom) end
	end

	-- Destinations
	local destinations, zdc = 0, 0
	local dossier = Config.dossierDestinations(false)
	if dossier then
		for _, part in dossier:GetDescendants() do
			if part:IsA("BasePart") then
				destinations += 1
				if string.sub(part.Name, 1, 4) == "ZDC-" then zdc += 1 end
			end
		end
	end

	local ligne = string.format("[TARDIS] %s : diagnostic · obligatoires %d/%d · optionnelles %d/%d · sons %d/%d · destinations %d (ZDC : %d)",
		def.Nom, obligatoires - #manquantes, obligatoires, optionnelles - #optionnellesAbsentes, optionnelles,
		presents, #noms, destinations, zdc)
	if #manquantes > 0 then
		warn("[TARDIS] " .. def.Nom .. " : pièces OBLIGATOIRES manquantes : " .. table.concat(manquantes, ", "))
	end
	-- Streaming (V6.9.17) : l'intérieur et l'extérieur doivent arriver en entier chez le client (Model Persistent)
	if workspace.StreamingEnabled then
		local nonPersistants = {}
		for _, objet in { interieur, exterieur } do
			if not objet:IsA("Model") or objet.ModelStreamingMode ~= Enum.ModelStreamingMode.Persistent then
				table.insert(nonPersistants, objet:GetFullName())
			end
		end
		if #nonPersistants > 0 then
			warn("[TARDIS] " .. def.Nom .. " : map en Streaming, à mettre en Model avec ModelStreamingMode = Persistent : "
				.. table.concat(nonPersistants, ", ") .. " (sinon le client peut ne pas recevoir les pièces loin de lui)")
		end
		ligne ..= " · streaming : " .. (#nonPersistants == 0 and "ok" or "à régler")
	end
	if #optionnellesAbsentes > 0 then
		ligne ..= " · absentes : " .. table.concat(optionnellesAbsentes, ", ")
	end
	if #sonsAbsents > 0 then
		ligne ..= " · sons absents (Config.Sons) : " .. table.concat(sonsAbsents, ", ")
	end
	return ligne
end
