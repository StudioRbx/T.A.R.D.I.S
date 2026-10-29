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
}

-- Sons optionnels (ceux des voyages viennent de Config.Modes)
local SONS_OPTIONNELS = { "Camouflage", "Decamouflage", "Alarme", "Cloitre", "Chute", "Impact", "Moteur",
	"Moteur_Pose", "Moteur_Vol", "Moteur_Urgence", "Regeneration" }

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
	for cle, chemin in Config.Chemins do
		local objet = interieur
		for _, nom in chemin do objet = objet and objet:FindFirstChild(nom) end
		exiger(objet ~= nil, "commande " .. cle .. " (" .. table.concat(chemin, " > ") .. ")")
	end

	-- Optionnelles
	for _, info in OPTIONNELLES do
		if not chercherDans(interieur, info[1]) then table.insert(optionnellesAbsentes, info[1]) end
	end

	-- Sons
	local dossierSons = ReplicatedStorage:FindFirstChild("TardisAssets") and ReplicatedStorage.TardisAssets:FindFirstChild("Sons")
	local noms, presents = {}, 0
	for _, reglages in Config.Modes do
		for _, nom in reglages.Sons do table.insert(noms, nom) end
	end
	for _, nom in SONS_OPTIONNELS do table.insert(noms, nom) end
	for _, nom in noms do
		if dossierSons and dossierSons:FindFirstChild(nom) then presents += 1 end
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
		def.Nom, obligatoires - #manquantes, obligatoires, #OPTIONNELLES - #optionnellesAbsentes, #OPTIONNELLES,
		presents, #noms, destinations, zdc)
	if #manquantes > 0 then
		warn("[TARDIS] " .. def.Nom .. " : pièces OBLIGATOIRES manquantes : " .. table.concat(manquantes, ", "))
	end
	if #optionnellesAbsentes > 0 then
		ligne ..= " · absentes : " .. table.concat(optionnellesAbsentes, ", ")
	end
	return ligne
end
