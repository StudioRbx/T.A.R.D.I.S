-- ServerScriptService > TardisSystemes (Script)
-- Systèmes du TARDIS : points de vie et avarie, énergie et fissures des boucliers, pannes (surcharge de vapeur,
-- incendie, coupure après N voyages), régénération des pilotes, outils des techniciens (chiffon, visseuse,
-- clé à molette, extincteur), saleté de la cabine, électricité statique, stabilisateur.
-- (V6.9.12) Socle commun des pannes : annonce unique (effet sur le vol, qui répare), historique des 20 dernières pannes
-- (attribut HistoriquePannes), zone de la panne (dossier Zones facultatif), fréquence réglable (FrequencePannes).
-- S'appuie sur TardisServeur à travers le pont "TardisInterne" (ServerStorage).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage:WaitForChild("TardisConfig"))
local def = Config.demarrerPourChaqueTardis(script) -- cet exemplaire ne s'occupe que d'un TARDIS (voir Config.Tardis)
local exterieur, interieur = Config.modeles(def)
local remote = ReplicatedStorage:WaitForChild(Config.canal(def, "TardisCommande"))
local pont = ServerStorage:WaitForChild(Config.canal(def, "TardisInterne"), 60)
if not pont then
	error("[TARDIS] TardisSystemes : le pont TardisInterne n'existe pas. TardisServeur a-t-il une erreur (voir l'Output) ?")
end
local E = Config.Etats
local S = Config.Systemes or {}

local function interne(action, ...) return pont:Invoke(action, ...) end
local function estPilote(joueur) return interne("estPilote", joueur) == true end
local function estTechnicien(joueur) return joueur:GetAttribute("TardisTechnicien_" .. def.Nom) == true or Config.estTechnicienDe(def, joueur.UserId) end
local function dire(joueur, message, ok) remote:FireClient(joueur, message, ok ~= false) end
local function direAuxPilotes(message, ok)
	for _, autre in Players:GetPlayers() do
		if estPilote(autre) or estTechnicien(autre) then dire(autre, message, ok) end
	end
end
local function racineDe(joueur) return joueur.Character and joueur.Character:FindFirstChild("HumanoidRootPart") end
local function partDe(objet)
	if not objet then return nil end
	if objet:IsA("BasePart") then return objet end
	if objet:IsA("Model") then return objet.PrimaryPart or objet:FindFirstChildWhichIsA("BasePart", true) end
	return objet:FindFirstChildWhichIsA("BasePart", true)
end
local function trouverChemin(cle)
	local chemin = Config.Chemins and Config.Chemins[cle]
	if not chemin then return nil end
	local objet = interieur
	for _, nom in chemin do objet = objet and objet:FindFirstChild(nom) end
	return partDe(objet)
end
local rotorPart = partDe(interieur:FindFirstChild(Config.NomRotor or "Rotor"))

--------------------------------------------------------------------
-- (V6.9.12) Socle commun des pannes : fiche de chaque panne, annonce, historique
--------------------------------------------------------------------
-- (V6.9.12) Ce que chaque panne fait au vol et qui peut la réparer : la même annonce pour toutes les pannes
local FICHES_PANNES = {
	Avarie = { titre = "Avarie (intégrité à 0 %)", court = "AVARIE : RÉPARER LE ROTOR",
		effet = "décollage impossible, portes ouvertes, tension coupée", repare = "pilote ou technicien : maintenir E 5 s sur le rotor" },
	Vapeur = { titre = "Surcharge de vapeur", court = "SURCHARGE DE VAPEUR",
		effet = "aucun effet sur le vol", repare = "technicien : visseuse sur la grille (3 fois)" },
	Incendie = { titre = "Incendie de console", court = "INCENDIE DE CONSOLE",
		effet = "aucun effet sur le vol", repare = "extincteur sur la console, puis clé à molette sur la vanne (maintenir E 4 s)" },
	Coupure = { titre = "Système coupé", court = "SYSTÈME COUPÉ : REDÉMARRAGE REQUIS",
		effet = "décollage impossible, tension coupée", repare = "maintenir E sur le levier d'alimentation, ou redémarrage à distance (tablette technicien)" },
	Bouclier = { titre = "Bouclier tombé", court = "BOUCLIER TOMBÉ",
		effet = "bouclier coupé, la cabine prend les tirs", repare = "pilote : relancer le bouclier depuis le menu" },
	AirVicie = { titre = "Air vicié", court = "AIR VICIÉ",
		effet = "aucun effet sur le vol", repare = "technicien : purge ou régulation de l'air (tablette technicien)" },
}
-- (V6.9.12) Historique des pannes de ce TARDIS : 20 au plus, la plus récente d'abord, publié en JSON dans l'attribut
-- HistoriquePannes (lu par la tablette technicien). « Réparé par » reste une simple mention : aucun compteur par joueur.
local HttpService = game:GetService("HttpService")
local HISTORIQUE_PANNES_MAX = 20
local historiquePannes = {}
local function publierHistorique()
	local ok, json = pcall(function() return HttpService:JSONEncode(historiquePannes) end)
	if ok and type(json) == "string" then exterieur:SetAttribute("HistoriquePannes", json) end
end
-- (V6.9.12) Ouvre une ligne d'historique (une seule ligne ouverte par type de panne à la fois)
local function ouvrirPanne(cle, details)
	local fiche = FICHES_PANNES[cle]
	if not fiche then return false end
	for _, entree in historiquePannes do
		if entree.type == cle and not entree.fin then return false end
	end
	table.insert(historiquePannes, 1, { type = cle, titre = fiche.titre, detail = details, debut = os.time() })
	while #historiquePannes > HISTORIQUE_PANNES_MAX do table.remove(historiquePannes) end
	publierHistorique()
	return true
end
-- (V6.9.12) Ferme la ligne ouverte de cette panne : heure de fin et, si on le sait, qui l'a réglée (joueur ou nom)
local function fermerPanne(cle, par)
	local fiche = FICHES_PANNES[cle]
	if not fiche then return false end
	local nom = nil
	if typeof(par) == "Instance" and par:IsA("Player") then nom = par.DisplayName elseif type(par) == "string" and par ~= "" then nom = par end
	for _, entree in historiquePannes do
		if entree.type == cle and not entree.fin then
			entree.fin = os.time()
			entree.par = nom
			publierHistorique()
			local bus = ServerStorage:FindFirstChild("TardisEvenements")
			if bus then
				bus:Fire("Journal", { categorie = "Panne", tardis = def.Nom,
					message = string.format("%s : %s, panne réglée%s.", def.Nom, fiche.titre, nom and (" par " .. nom) or "") })
			end
			return true
		end
	end
	return false
end
-- (V6.9.12) Annonce commune : alerte sur l'écran de la console, message aux pilotes et techniciens (effet sur le vol,
-- qui répare), ligne d'historique
local function signalerPanne(cle, details)
	local fiche = FICHES_PANNES[cle]
	if not fiche then return end
	interne("alerter", fiche.court)
	direAuxPilotes(string.format("PANNE : %s%s · EFFET SUR LE VOL : %s · QUI RÉPARE : %s.", fiche.titre,
		details and (" (" .. details .. ")") or "", fiche.effet, fiche.repare), false)
	ouvrirPanne(cle, details)
end
-- (V6.9.12) Chemin d'une pièce depuis l'intérieur (« Grilles/Grille »), publié pour que le client trouve la même pièce
local function cheminDepuisInterieur(objet)
	local noms = {}
	while objet and objet ~= interieur do
		table.insert(noms, 1, objet.Name)
		objet = objet.Parent
	end
	return objet == interieur and table.concat(noms, "/") or nil
end

--------------------------------------------------------------------
-- Points de vie et avarie
--------------------------------------------------------------------
local pvMax = S.PointsDeVie or 10000
local pv = pvMax
local function publierPV()
	exterieur:SetAttribute("PointsDeVie", math.floor(pv / pvMax * 100 + 0.5))
	exterieur:SetAttribute("PV", math.floor(pv))
	exterieur:SetAttribute("PVMax", pvMax)
end
local dernierReparateurRotor = nil -- (V6.9.12) le dernier joueur qui a réparé au rotor (mention dans l'historique)
local function avarie(actif)
	if (exterieur:GetAttribute("Avarie") == true) == actif then return end
	exterieur:SetAttribute("Avarie", actif)
	if actif then
		signalerPanne("Avarie") -- (V6.9.12) annonce commune (alerte, effet sur le vol, qui répare) + historique
		interne("reglerAlimentation", false)
		exterieur:SetAttribute("Verrouille", false)
		interne("ouvrirPortes")
	else
		direAuxPilotes("Réparation suffisante : les systèmes repartent.", true)
		interne("reglerAlimentation", true)
		fermerPanne("Avarie", dernierReparateurRotor) -- (V6.9.12)
	end
end
local function degats(montant, raison)
	if exterieur:GetAttribute("Detruit") then return end
	pv = math.clamp(pv - montant, 0, pvMax)
	publierPV()
	if pv <= 0 then avarie(true) end
	exterieur:SetAttribute("DernierDegat", string.format("%s\t%d\t%.2f", raison, montant, workspace:GetServerTimeNow()))
end
local function reparer(montant)
	pv = math.clamp(pv + montant, 0, pvMax)
	publierPV()
	if pv > 0 and exterieur:GetAttribute("Avarie") then avarie(false) end
end
publierPV()
-- Pendant une avarie, les portes restent ouvertes
task.spawn(function()
	while true do
		task.wait(4)
		if exterieur:GetAttribute("Avarie") and not exterieur:GetAttribute("PorteOuverte") and (exterieur:GetAttribute("Etat") or E.Pose) == E.Pose then
			exterieur:SetAttribute("Verrouille", false)
			interne("ouvrirPortes")
		end
	end
end)

-- Sources de dégâts : chocs en vol, chutes, balles sans bouclier, explosions
exterieur:GetAttributeChangedSignal("ChocTemps"):Connect(function() degats(S.DegatsChoc or 25, "Choc en vol") end)
local derniereDescente = nil
exterieur:GetAttributeChangedSignal("DescenteDebut"):Connect(function()
	local debut = exterieur:GetAttribute("DescenteDebut")
	if debut then
		derniereDescente = exterieur:GetAttribute("DescenteMode")
	elseif derniereDescente == "Chute" then
		derniereDescente = nil
		degats(S.DegatsChute or 80, "Chute")
	end
end)
local function bouclierActif()
	return exterieur:GetAttribute("BouclierBalles") == true or exterieur:GetAttribute("BouclierComplet") == true
end
local function surveillerImpacts(part)
	part.DescendantAdded:Connect(function(objet)
		-- Les systèmes d'armes attachent leurs impacts (Attachment, Decal...) aux pièces touchées ; les nôtres commencent par "Tardis"
		if (objet:IsA("Attachment") or objet:IsA("Decal")) and string.sub(objet.Name, 1, 6) ~= "Tardis" and not bouclierActif() then
			degats(S.DegatsBalle or 4, "Tir")
		end
	end)
end
for _, objet in exterieur:GetDescendants() do
	if objet:IsA("BasePart") and not objet:IsDescendantOf(exterieur:FindFirstChild("Boucliers") or exterieur.PrimaryPart) then surveillerImpacts(objet) end
end
workspace.DescendantAdded:Connect(function(objet)
	if objet:IsA("Explosion") and not exterieur:GetAttribute("AutoDestructionDebut") and not exterieur:GetAttribute("Detruit") then
		task.defer(function()
			if (objet.Position - exterieur:GetPivot().Position).Magnitude <= 60 then degats(S.DegatsExplosion or 300, "Explosion") end
		end)
	end
end)

-- Réparation : maintenir E 5 s sur le rotor (pilotes et techniciens)
if rotorPart then
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TardisReparation"
	prompt.ActionText = "Réparer"
	prompt.ObjectText = "Rotor"
	prompt.HoldDuration = 5
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = rotorPart
	prompt.Triggered:Connect(function(joueur)
		if not (estPilote(joueur) or estTechnicien(joueur)) then return end
		if pv >= pvMax then dire(joueur, "Le TARDIS est déjà intact.", true) return end
		dernierReparateurRotor = joueur -- (V6.9.12)
		reparer(S.ReparationParMaintien or 1500)
		exterieur:SetAttribute("ReparationTemps", workspace:GetServerTimeNow())
		interne("jouer", "Reparation", false)
		dire(joueur, string.format("Réparation : %d %% d'intégrité.", exterieur:GetAttribute("PointsDeVie") or 0), true)
	end)
end

--------------------------------------------------------------------
-- Boucliers : énergie, impacts, chute du bouclier
--------------------------------------------------------------------
local function surveillerBouclier(modele)
	local bulle = modele:WaitForChild("Bulle", 5)
	if not bulle then return end
	local dernierCoup = 0
	local function coup(position)
		if os.clock() - dernierCoup < 0.03 then return end
		dernierCoup = os.clock()
		local energie = (exterieur:GetAttribute("BouclierEnergie") or 100) - 100 / (S.BouclierCoups or 250)
		exterieur:SetAttribute("BouclierImpact", position)
		exterieur:SetAttribute("BouclierImpactTemps", workspace:GetServerTimeNow())
		if energie <= 0 then
			exterieur:SetAttribute("BouclierEnergie", 0)
			exterieur:SetAttribute("BouclierBrise", workspace:GetServerTimeNow())
			exterieur:SetAttribute("BouclierJoueurs", false)
			exterieur:SetAttribute("BouclierBalles", false)
			exterieur:SetAttribute("BouclierComplet", false)
			signalerPanne("Bouclier") -- (V6.9.12) annonce commune + historique
		else
			exterieur:SetAttribute("BouclierEnergie", energie)
		end
	end
	bulle.DescendantAdded:Connect(function(objet)
		local position = (objet:IsA("Attachment") and objet.WorldPosition) or (objet:IsA("BasePart") and objet.Position)
		if position then coup(position) end
	end)
	bulle.Touched:Connect(function(autre)
		if autre:IsDescendantOf(exterieur) or (autre.Parent and autre.Parent:FindFirstChildOfClass("Humanoid")) then return end
		if not autre.Anchored then coup(autre.Position) end -- projectile physique
	end)
end
task.spawn(function()
	local dossier = exterieur:WaitForChild("Boucliers", 30)
	if not dossier then return end
	dossier.ChildAdded:Connect(function(modele) task.spawn(surveillerBouclier, modele) end)
	for _, modele in dossier:GetChildren() do task.spawn(surveillerBouclier, modele) end
end)
-- (V6.9.12) Bouclier relancé (il repart à pleine énergie) : la panne se ferme dans l'historique
exterieur:GetAttributeChangedSignal("BouclierEnergie"):Connect(function()
	if (tonumber(exterieur:GetAttribute("BouclierEnergie")) or 0) > 0 then fermerPanne("Bouclier") end
end)

--------------------------------------------------------------------
-- Pannes : surcharge de vapeur (visseuse), incendie (extincteur + clé à molette), coupure après N voyages
--------------------------------------------------------------------
-- (V6.9.12) Les grilles sont numérotées (attribut TardisGrille) : le client retrouve la même grille que le serveur
local grilles = Config.grillesDe(interieur)
for numero, grille in grilles do grille:SetAttribute("TardisGrille", numero) end
local function panneVapeur()
	if #grilles == 0 or exterieur:GetAttribute("VapeurSurcharge") then return false end
	local index = math.random(#grilles)
	local grille = grilles[index]
	exterieur:SetAttribute("VapeurGrille", cheminDepuisInterieur(grille)) -- (V6.9.12) chemin de la grille, pour le client
	exterieur:SetAttribute("VapeurSurcharge", index)
	exterieur:SetAttribute("VapeurSurchargeAvancement", 0)
	local zone = Config.zoneDe(interieur, grille) -- (V6.9.12) zone de la panne (dossier Zones, sinon autour de la console)
	signalerPanne("Vapeur", string.format("grille n°%d%s", index, zone and (", zone " .. zone) or ""))
	return true
end
local function panneIncendie()
	if exterieur:GetAttribute("Incendie") then return false end
	exterieur:SetAttribute("Incendie", true)
	exterieur:SetAttribute("IncendieEteint", nil)
	signalerPanne("Incendie") -- (V6.9.12) annonce commune + historique
	return true
end
-- Les flammes repartent 20 s après l'extincteur tant que la vanne n'est pas fermée
task.spawn(function()
	while true do
		task.wait(1)
		local eteint = exterieur:GetAttribute("IncendieEteint")
		if exterieur:GetAttribute("Incendie") and eteint and workspace:GetServerTimeNow() - eteint > 20 then
			exterieur:SetAttribute("IncendieEteint", nil)
			direAuxPilotes("Les flammes repartent : fermez la vanne avec la clé à molette.", false)
		end
	end
end)
-- Vanne : pièce "Vanne" de l'intérieur (sinon le rotor), à fermer avec la clé à molette (maintenir E 4 s)
do
	local vanne = partDe(interieur:FindFirstChild("Vanne", true)) or rotorPart
	if vanne then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "TardisVanne"
		prompt.ActionText = "Fermer la vanne (clé à molette)"
		prompt.ObjectText = "Vanne"
		prompt.HoldDuration = 4
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = false
		prompt.UIOffset = Vector2.new(0, 50)
		prompt.Enabled = false
		prompt.Parent = vanne
		exterieur:GetAttributeChangedSignal("Incendie"):Connect(function() prompt.Enabled = exterieur:GetAttribute("Incendie") == true end)
		prompt.Triggered:Connect(function(joueur)
			local outil = joueur.Character and joueur.Character:FindFirstChild("CleMolette")
			if not outil then dire(joueur, "Il faut la clé à molette en main.", false) return end
			exterieur:SetAttribute("Incendie", false)
			exterieur:SetAttribute("IncendieEteint", nil)
			interne("jouer", "Reparation", false)
			direAuxPilotes("Vanne fermée par " .. joueur.DisplayName .. " : incendie terminé.", true)
			fermerPanne("Incendie", joueur) -- (V6.9.12)
		end)
	end
end
-- Coupure après N voyages consécutifs : 10 s sur le levier d'alimentation pour redémarrer
local voyagesConsecutifs = 0
local etatPrecedent = exterieur:GetAttribute("Etat")
exterieur:GetAttributeChangedSignal("Etat"):Connect(function()
	local etat = exterieur:GetAttribute("Etat")
	if etat == E.Pose and etatPrecedent == E.Remat then
		voyagesConsecutifs += 1
		exterieur:SetAttribute("VoyagesConsecutifs", voyagesConsecutifs) -- lu par la tablette technicien
		-- Saleté : la cabine se salit à chaque atterrissage
		exterieur:SetAttribute("Salete", math.clamp((exterieur:GetAttribute("Salete") or 0) + (S.SaleteParVoyage or 8), 0, 100))
		if voyagesConsecutifs >= (S.VoyagesAvantCoupure or 5) and not exterieur:GetAttribute("RedemarrageRequis") then
			task.delay(2, function()
				exterieur:SetAttribute("RedemarrageRequis", true)
				interne("reglerAlimentation", false)
				-- (V6.9.12) annonce commune + historique (la durée du maintien est rappelée dans le détail)
				signalerPanne("Coupure", string.format("après %d voyages consécutifs, maintenir E %d s", voyagesConsecutifs, S.RedemarrageDuree or 10))
			end)
		end
	end
	etatPrecedent = etat
end)
do
	local levier = trouverChemin("Alimentation")
	if levier then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "TardisRedemarrage"
		prompt.ActionText = "Redémarrer le système"
		prompt.ObjectText = "Alimentation"
		prompt.HoldDuration = S.RedemarrageDuree or 10
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = false
		prompt.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
		prompt.Enabled = false
		prompt.Parent = levier
		-- Pendant le redémarrage requis, l'invite habituelle du levier (On/Off) est cachée : seule la nôtre (E maintenu) reste
		local function majInvites()
			local requis = exterieur:GetAttribute("RedemarrageRequis") == true
			prompt.Enabled = requis
			for _, autre in levier:GetDescendants() do
				if autre:IsA("ProximityPrompt") and autre ~= prompt then autre.Enabled = not requis end
			end
		end
		exterieur:GetAttributeChangedSignal("RedemarrageRequis"):Connect(majInvites)
		prompt.Triggered:Connect(function(joueur)
			if not (estPilote(joueur) or estTechnicien(joueur)) then return end
			voyagesConsecutifs = 0
			exterieur:SetAttribute("VoyagesConsecutifs", 0)
			exterieur:SetAttribute("RedemarrageRequis", false)
			interne("reglerAlimentation", true)
			interne("jouer", "Reparation", false)
			direAuxPilotes("Système redémarré par " .. joueur.DisplayName .. ".", true)
			fermerPanne("Coupure", joueur) -- (V6.9.12)
		end)
	end
end
-- (V6.9.12) Pannes aléatoires : liste pondérée (une future panne s'y ajoute d'une ligne) ; si la panne tirée est
-- impossible (pas de grille, déjà en cours), on tente les autres
local PANNES_ALEATOIRES = {
	{ nom = "Vapeur", declencher = panneVapeur, poids = 1 },
	{ nom = "Incendie", declencher = panneIncendie, poids = 1 },
}
local function tirerPanneAleatoire()
	local restantes = table.clone(PANNES_ALEATOIRES)
	while #restantes > 0 do
		local total = 0
		for _, panne in restantes do total += math.max(tonumber(panne.poids) or 0, 0) end
		if total <= 0 then return nil end
		local tirage, choisie = math.random() * total, #restantes
		for i, panne in restantes do
			local poids = math.max(tonumber(panne.poids) or 0, 0)
			if poids > 0 and tirage <= poids then choisie = i break end
			tirage -= poids
		end
		local panne = table.remove(restantes, choisie)
		if panne.declencher() then return panne.nom end
	end
	return nil
end
-- (V6.9.12) Fréquence réglable (Config.Systemes.FrequencePannes : Aucune, Rare, Normale, Frequente) ; Aucune = la boucle s'arrête
task.spawn(function()
	while true do
		local mini, maxi = Config.intervallePannes(S)
		if not mini then return end
		task.wait(mini + math.random() * math.max(maxi - mini, 0))
		local etat, occupe = interne("etat")
		if etat == E.Pose and not occupe and exterieur:GetAttribute("Alimentation") ~= false and not exterieur:GetAttribute("Detruit") then
			tirerPanneAleatoire()
		end
	end
end)

--------------------------------------------------------------------
-- Régénération (Config.Regeneration) : les joueurs de l'équipe C.A.T. (Config.Equipe) ne meurent pas, ils se régénèrent.
-- Pendant la régénération, rien ne peut les tuer. Ils prennent l'apparence d'un des avatars sauvegardés sur leur compte
-- (sinon une tenue de Config.Tenues), sont soignés et gagnent des PV en plus pendant quelques minutes.
-- (Un seul exemplaire du script s'en occupe : celui du premier TARDIS.)
--------------------------------------------------------------------
local REGEN = Config.Regeneration or {}
local regenerations = {}   -- [UserId] = nombre de régénérations depuis la dernière vraie mort
local tenuesCompte = {}    -- [UserId] = { identifiants des avatars sauvegardés } (envoyés par le joueur, avec sa permission)
local derniereTenue = {}   -- [UserId] = dernier avatar porté, pour ne pas reprendre le même
local descriptionsChargees = {} -- [clé] = HumanoidDescription (gardée pour la session) : "tenue:123" ou "joueur:456"
local function estRegenerateur(joueur)
	return joueur.Team ~= nil and joueur.Team.Name == Config.nomEquipe()
end
-- Le joueur a-t-il partagé ses avatars ?
local function aPartageSesAvatars(joueur)
	local liste = tenuesCompte[joueur.UserId]
	return REGEN.TenuesDuCompte ~= false and liste ~= nil and #liste > 0
end
-- Charge un avatar : 3 essais, car le service des avatars de Roblox échoue parfois.
-- source = "tenue" (avatar sauvegardé du joueur) ou "joueur" (avatar actuel d'un compte, pour Config.Regeneration.AvatarsDuJeu)
local function chargerDescription(source, identifiant)
	local cle = source .. ":" .. identifiant
	if descriptionsChargees[cle] then return descriptionsChargees[cle] end
	for essai = 1, 3 do
		local ok, description = pcall(function()
			if source == "joueur" then return Players:GetHumanoidDescriptionFromUserId(identifiant) end
			return Players:GetHumanoidDescriptionFromOutfitId(identifiant)
		end)
		if ok and description then
			descriptionsChargees[cle] = description
			return description
		end
		task.wait(0.5 * essai)
	end
	return nil
end
-- Vêtements 3D : un corps R6 ne peut pas les porter
local T = Enum.AccessoryType
local VETEMENTS_3D = { [T.Shirt] = true, [T.TShirt] = true, [T.Jacket] = true, [T.Sweater] = true, [T.Pants] = true,
	[T.Shorts] = true, [T.DressSkirt] = true, [T.LeftShoe] = true, [T.RightShoe] = true }
-- Adapte un avatar à un corps R6, au lieu de l'écarter : les vêtements 3D sont retirés ; les autres accessoires
-- enregistrés « superposés » (souvent les cheveux) sont gardés et posés comme des accessoires classiques ;
-- une tête dynamique (sans visage) redevient une tête classique avec le visage actuel du joueur
local function adapterR6(description, humanoid)
	local ok, accessoires = pcall(function() return description:GetAccessories(true) end)
	if ok then
		local gardes, change = {}, false
		for _, accessoire in accessoires do
			if not accessoire.IsLayered then
				table.insert(gardes, accessoire)
			else
				change = true
				if not VETEMENTS_3D[accessoire.AccessoryType] then
					table.insert(gardes, { AccessoryType = accessoire.AccessoryType, AssetId = accessoire.AssetId, IsLayered = false })
				end
			end
		end
		if change then pcall(function() description:SetAccessories(gardes, true) end) end
	end
	if description.Head ~= 0 and description.Face == 0 then
		description.Head = 0
		local okActuelle, actuelle = pcall(function() return humanoid:GetAppliedDescription() end)
		if okActuelle and actuelle then description.Face = actuelle.Face end
	end
	return description
end
-- Choisit un avatar (nil si aucun n'est utilisable) : d'abord ceux du joueur (s'il les a partagés),
-- sinon ceux de Config.Regeneration.AvatarsDuJeu. Jusqu'à 4 essais, sans reprendre le dernier porté s'il y a le choix.
-- Renvoie aussi d'où vient l'avatar (pour le journal).
local function choisirDescription(joueur, humanoid)
	local source, liste = "tenue", tenuesCompte[joueur.UserId]
	if not aPartageSesAvatars(joueur) then
		source, liste = "joueur", REGEN.AvatarsDuJeu
		if type(liste) ~= "table" or #liste == 0 then return nil, "aucun avatar disponible" end
	end
	local derniere = derniereTenue[joueur.UserId]
	local candidats, repli = {}, nil
	for _, identifiant in liste do
		if identifiant == derniere then repli = identifiant else table.insert(candidats, identifiant) end
	end
	if #candidats == 0 and repli then candidats = { repli } end
	for _ = 1, math.min(#candidats, 4) do
		local choix = table.remove(candidats, math.random(#candidats))
		local description = chargerDescription(source, choix)
		if description then
			derniereTenue[joueur.UserId] = choix
			description = description:Clone()
			if humanoid.RigType == Enum.HumanoidRigType.R6 then adapterR6(description, humanoid) end
			return description, (source == "tenue" and "avatar du compte n°" or "avatar du jeu n°") .. tostring(choix)
		end
	end
	return nil, "avatars introuvables"
end
-- Une tenue de Config.Tenues (quand aucun avatar n'est disponible, ou quand l'avatar n'a pas de vêtements classiques).
-- (V6.9.10.5) Par TardisTenues : les identifiants du catalogue sont changés en vraies images (avant, mis tels quels :
-- le joueur ressortait sans vêtements). Une tenue introuvable : on en essaie une autre, sinon il garde les siens.
local Tenues = require(script.Parent:WaitForChild("TardisTenues"))
local function habillerTenueJeu(personnage)
	local tenues = {}
	for _, tenue in Config.Tenues or {} do table.insert(tenues, tenue) end
	for _ = 1, math.min(#tenues, 3) do
		local tenue = table.remove(tenues, math.random(#tenues))
		if Tenues.appliquer(personnage, tenue) then return true end
	end
	return false
end
-- Applique l'avatar puis vérifie que tous ses accessoires sont arrivés (ApplyDescription en perd parfois) : jusqu'à 3 essais
local function appliquerDescription(personnage, humanoid, description)
	local attendus = 0
	pcall(function() attendus = #description:GetAccessories(true) end)
	local applique = false
	for essai = 1, 3 do
		if not humanoid.Parent then return applique end
		if pcall(function() humanoid:ApplyDescription(description) end) then
			applique = true
			local portes = 0
			for _, objet in personnage:GetChildren() do
				if objet:IsA("Accessory") then portes += 1 end
			end
			if portes >= attendus then return true end
		end
		task.wait(0.3 * essai)
	end
	return applique -- un accessoire manque encore (supprimé du catalogue ?) : l'avatar reste quand même
end
-- Nouvelle apparence (la description a été préparée au début de la régénération). L'apparence change toujours :
-- avatar choisi, sinon une tenue du jeu. Une ligne dans l'Output dit ce qui a été appliqué.
local function changerApparence(joueur, personnage, humanoid, description, origine)
	if description and appliquerDescription(personnage, humanoid, description) then
		-- Un avatar sans vêtements classiques (que des vêtements 3D, retirés en R6) reçoit une tenue du jeu
		local habille = personnage:FindFirstChildOfClass("Shirt") or personnage:FindFirstChildOfClass("Pants")
		local tenueMise = (not habille) and habillerTenueJeu(personnage)
		print(string.format("[TARDIS] Régénération de %s : %s%s", joueur.Name, origine or "avatar",
			habille and "" or (tenueMise and " + tenue du jeu" or " (tenue du jeu introuvable)")))
		return
	end
	local tenueMise = habillerTenueJeu(personnage)
	print(string.format("[TARDIS] Régénération de %s : %s (%s)", joueur.Name, tenueMise and "tenue du jeu" or "vêtements gardés, tenue du jeu introuvable",
		description and "avatar non appliqué" or origine or "aucun avatar"))
end
-- Le corps tient-il encore ? (une commande :kill ou une explosion casse toutes les articulations)
local function corpsIntact(personnage)
	local torse = personnage:FindFirstChild("Torso")
	if torse then -- R6
		for _, nom in { "Neck", "Right Shoulder", "Left Shoulder", "Right Hip", "Left Hip" } do
			if not torse:FindFirstChild(nom) then return false end
		end
		local racine = personnage:FindFirstChild("HumanoidRootPart")
		return racine ~= nil and racine:FindFirstChild("RootJoint") ~= nil
	end
	local tete, haut, bas = personnage:FindFirstChild("Head"), personnage:FindFirstChild("UpperTorso"), personnage:FindFirstChild("LowerTorso")
	return tete ~= nil and tete:FindFirstChild("Neck") ~= nil and haut ~= nil and haut:FindFirstChild("Waist") ~= nil
		and bas ~= nil and bas:FindFirstChild("Root") ~= nil
end
local enAttente = {} -- [UserId] = { position, regard, habille } : régénération à finir sur un corps neuf
local choixEnAttente = {} -- [UserId] = fonction appelée si le joueur refuse sa régénération

-- Journal des régénérations (qui, quand, où), visible dans la tablette (outil Régénérations)
local journalRegen = {}
local function noterRegeneration(joueur, nature, lieu, numero)
	table.insert(journalRegen, 1, { heure = os.date("%d/%m %H:%M:%S"), nom = joueur.DisplayName, pseudo = joueur.Name,
		nature = nature, lieu = lieu or "Hors du TARDIS", numero = numero })
	while #journalRegen > 40 do table.remove(journalRegen) end
	ReplicatedStorage:SetAttribute("TardisRegenerations", game:GetService("HttpService"):JSONEncode(journalRegen))
end
-- Dans quel TARDIS se trouve cette position ? (tous les TARDIS du jeu, par leurs ponts)
local function tardisABord(position)
	for _, d in Config.Tardis do
		local autrePont = ServerStorage:FindFirstChild(Config.canal(d, "TardisInterne"))
		if autrePont then
			local ok, dedans = pcall(function() return autrePont:Invoke("dansInterieur", position) end)
			if ok and dedans then return d.Nom end
		end
	end
	return nil
end
-- Régénération à bord : le TARDIS concerné encaisse le choc (étincelles, alarme, intégrité)
local evenementABord = ServerStorage:FindFirstChild("TardisRegenerationABord")
if not evenementABord then
	evenementABord = Instance.new("BindableEvent")
	evenementABord.Name = "TardisRegenerationABord"
	evenementABord.Parent = ServerStorage
end
evenementABord.Event:Connect(function(nomTardis)
	if nomTardis ~= def.Nom then return end
	degats(REGEN.DegatsTardis or 400, "Régénération à bord")
	exterieur:SetAttribute("RegenerationABord", workspace:GetServerTimeNow()) -- étincelles sur la console (clients)
	interne("alerter", "RÉGÉNÉRATION À BORD")
	interne("jouer", "Cloitre", false)
end)
-- Catastrophe (V6.7.1) : le TARDIS s'est matérialisé dans lui-même (TardisServeur pose l'attribut) : la cabine encaisse
exterieur:GetAttributeChangedSignal("Catastrophe"):Connect(function()
	if not exterieur:GetAttribute("Catastrophe") then return end
	degats((Config.Modes.Catastrophe or {}).Degats or 1500, "Paradoxe : TARDIS dans le TARDIS")
	exterieur:SetAttribute("RegenerationABord", workspace:GetServerTimeNow()) -- la console crache des étincelles
	interne("jouer", "Cloitre", false)
	direAuxPilotes("Paradoxe : la cabine a encaissé le choc (intégrité " .. tostring(exterieur:GetAttribute("PointsDeVie") or "?") .. " %).", false)
end)

local spawnsEquipes = {} -- nom d'équipe → SpawnLocation utilisé (V6.9.10.2)
-- Spawns dans le TARDIS (V6.7.1, Config.Equipe.SpawnDansLeTardis ; V6.9.5 : aussi la C.T.A.T.) : un SpawnLocation
-- réservé à chaque équipe, sur la Part "Arrivee" de l'intérieur si elle existe, sinon juste derrière la porte intérieure.
-- La C.T.A.T. (Config.EquipeTechnique) est créée dans Teams si elle n'existe pas ; elle ne se régénère pas.
if def.Nom == Config.Tardis[1].Nom then
	local Teams = game:GetService("Teams")
	-- V6.9.10.2 : un SpawnLocation déjà posé dans l'intérieur pour l'équipe (« Spawn C.A.T », « Spawn C.T.A.T »…) est réutilisé :
	-- son nom, sans points ni espaces, se termine par celui de l'équipe. Sinon, le spawn est créé comme avant.
	local function compacter(texte) return (string.gsub(string.upper(texte), "[%.%s_%-]", "")) end
	local function spawnDeStudio(nom)
		local cle = compacter(nom)
		for _, objet in interieur:GetChildren() do
			if objet:IsA("SpawnLocation") and objet.Name ~= "TardisSpawn_" .. def.Nom .. "_" .. nom then
				local n = compacter(objet.Name)
				if n == cle or string.sub(n, -#cle) == cle then return objet end
			end
		end
		return nil
	end
	local function placerSpawn(nom, decalage)
		local equipe = Teams:FindFirstChild(nom) or Teams:WaitForChild(nom, 30)
		if not equipe then
			warn("[TARDIS] Spawn dans le TARDIS : l'équipe « " .. nom .. " » n'existe pas dans Teams.")
			return
		end
		local existant = spawnDeStudio(nom)
		if existant then
			existant.Neutral = false
			existant.TeamColor = equipe.TeamColor
			existant.AllowTeamChangeOnTouch = false
			existant:SetAttribute("TardisEquipe", nom)
			spawnsEquipes[nom] = existant
			print("[TARDIS] " .. def.Nom .. " : spawn « " .. existant.Name .. " » utilisé pour l'équipe « " .. nom .. " ».")
			return
		end
		local arrivee = interieur:FindFirstChild(Config.NomArrivee or "Arrivee")
		local portail = interieur:FindFirstChild(Config.NomPortailInt or "Portail")
		local cf
		if arrivee and arrivee:IsA("BasePart") then
			cf = arrivee.CFrame * CFrame.new(0, arrivee.Size.Y / 2 + 0.5, 0)
		elseif portail and portail:IsA("BasePart") then
			cf = portail.CFrame * CFrame.new(0, -portail.Size.Y / 2 + 0.5, 5) * CFrame.Angles(0, math.pi, 0)
		else
			cf = Config.pivot(interieur)
		end
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "TardisSpawn_" .. def.Nom .. "_" .. nom
		spawn.Size = Vector3.new(6, 1, 6)
		spawn.CFrame = cf * CFrame.new(decalage, 0, 0)
		spawn.Anchored, spawn.CanCollide, spawn.CanQuery, spawn.CanTouch = true, false, false, false
		spawn.Transparency = 1
		spawn.Neutral = false
		spawn.TeamColor = equipe.TeamColor
		spawn.AllowTeamChangeOnTouch = false
		spawn.Duration = 0
		spawn.Parent = interieur
		spawnsEquipes[nom] = spawn
		print("[TARDIS] " .. def.Nom .. " : spawn de l'équipe « " .. nom .. " » placé dans l'intérieur.")
	end
	if (Config.Equipe or {}).SpawnDansLeTardis ~= false then
		task.spawn(placerSpawn, Config.nomEquipe(), 0)
	end
	local technique = Config.EquipeTechnique
	if technique then
		local nom = technique.Nom or "C.T.A.T."
		if technique.Creer ~= false and not Teams:FindFirstChild(nom) then
			local equipe = Instance.new("Team")
			equipe.Name = nom
			equipe.TeamColor = technique.Couleur or BrickColor.new("Deep orange")
			equipe.AutoAssignable = false
			equipe.Parent = Teams
			print("[TARDIS] Équipe « " .. nom .. " » (Cellule Technique d'Autorité Temporelle) créée.")
		end
		if technique.SpawnDansLeTardis ~= false then
			task.spawn(placerSpawn, nom, 7) -- 7 studs à côté de celui de la C.A.T.
		end
	end
end
-- Main qui repousse : après une régénération, un membre perdu repousse pendant quelques minutes (R6)
local MEMBRES = { ["Right Arm"] = "Right Shoulder", ["Left Arm"] = "Left Shoulder", ["Right Leg"] = "Right Hip", ["Left Leg"] = "Left Hip" }
local function surveillerMembres(joueur, personnage, duree)
	local torse = personnage:FindFirstChild("Torso")
	if not torse or duree <= 0 then return end
	local modeles = {}
	for membre, nomMoteur in MEMBRES do
		local part, moteur = personnage:FindFirstChild(membre), torse:FindFirstChild(nomMoteur)
		if part and moteur and moteur:IsA("Motor6D") then
			modeles[membre] = { part = part:Clone(), C0 = moteur.C0, C1 = moteur.C1, moteur = nomMoteur }
		end
	end
	local fin = os.clock() + duree
	task.spawn(function()
		local enRepousse = {}
		while os.clock() < fin and personnage.Parent and torse.Parent do
			task.wait(1)
			for membre, modele in modeles do
				local part, moteur = personnage:FindFirstChild(membre), torse:FindFirstChild(modele.moteur)
				local attache = part and moteur and moteur:IsA("Motor6D") and moteur.Part1 == part
				if not attache and not enRepousse[membre] then
					enRepousse[membre] = true
					dire(joueur, (string.find(membre, "Arm") and "Ton bras" or "Ta jambe") .. " repousse…", true)
					task.delay(2.5, function()
						if not personnage.Parent or not torse.Parent then return end
						local ancien = personnage:FindFirstChild(membre)
						if ancien then ancien:Destroy() end
						local ancienMoteur = torse:FindFirstChild(modele.moteur)
						if ancienMoteur then ancienMoteur:SetAttribute("TardisVolontaire", true) ancienMoteur:Destroy() end
						local neuf = modele.part:Clone()
						neuf.CFrame = torse.CFrame * modele.C0 * modele.C1:Inverse()
						neuf.Parent = personnage
						local m = Instance.new("Motor6D")
						m.Name = modele.moteur
						m.Part0, m.Part1, m.C0, m.C1 = torse, neuf, modele.C0, modele.C1
						m.Parent = torse
						-- Un peu d'énergie dorée sur le membre neuf
						local eclat = Instance.new("ParticleEmitter")
						eclat.Color = ColorSequence.new(Color3.fromRGB(255, 235, 150), Color3.fromRGB(255, 150, 40))
						eclat.LightEmission = 1
						eclat.Size = NumberSequence.new(0.4, 0)
						eclat.Speed = NumberRange.new(2, 5)
						eclat.Lifetime = NumberRange.new(0.4, 0.8)
						eclat.Rate = 60
						eclat.Parent = neuf
						task.delay(2, function() eclat:Destroy() end)
						enRepousse[membre] = nil
					end)
				end
			end
		end
	end)
end

-- PV en plus pendant quelques minutes (une nouvelle régénération relance la durée, sans cumuler)
local function bonusPV(humanoid)
	local bonus, dureeBonus = REGEN.BonusPV or 100, REGEN.BonusDuree or 300
	local jeton = (humanoid:GetAttribute("TardisBonusJeton") or 0) + 1
	humanoid:SetAttribute("TardisBonusJeton", jeton)
	if not humanoid:GetAttribute("TardisBonusActif") then
		humanoid:SetAttribute("TardisBonusActif", true)
		humanoid.MaxHealth += bonus
	end
	humanoid.Health = humanoid.MaxHealth
	task.delay(dureeBonus, function()
		if humanoid.Parent and humanoid:GetAttribute("TardisBonusJeton") == jeton and humanoid:GetAttribute("TardisBonusActif") then
			humanoid:SetAttribute("TardisBonusActif", nil)
			humanoid.MaxHealth = math.max(humanoid.MaxHealth - bonus, 1)
			humanoid.Health = math.min(humanoid.Health, humanoid.MaxHealth)
		end
	end)
end
-- Pose de la série (R6) : bras écartés sur les côtés, paumes vers le ciel, tête renversée en arrière.
-- Le mouvement est fluide (interpolation des articulations), et tout le monde le voit.
local TweenService = game:GetService("TweenService")
local POSE = {
	["Right Shoulder"] = CFrame.Angles(-math.rad(72), 0, 0) * CFrame.Angles(0, 0, math.rad(8)),  -- bras droit levé sur le côté
	["Left Shoulder"] = CFrame.Angles(-math.rad(72), 0, 0) * CFrame.Angles(0, 0, -math.rad(8)),  -- bras gauche levé sur le côté
	["Neck"] = CFrame.Angles(-math.rad(28), 0, 0),                                                  -- tête renversée en arrière
	["Right Hip"] = CFrame.Angles(-math.rad(6), 0, 0),                                              -- jambes légèrement écartées
	["Left Hip"] = CFrame.Angles(-math.rad(6), 0, 0),
}
local function poseRegeneration(personnage, active, duree)
	local torse = personnage:FindFirstChild("Torso")
	if not torse then return end
	for nom, rotation in POSE do
		local moteur = torse:FindFirstChild(nom)
		if moteur and moteur:IsA("Motor6D") then
			if active then
				moteur:SetAttribute("TardisC0", moteur:GetAttribute("TardisC0") or moteur.C0)
				TweenService:Create(moteur, TweenInfo.new(duree or 0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
					{ C0 = moteur:GetAttribute("TardisC0") * rotation }):Play()
			elseif moteur:GetAttribute("TardisC0") then
				local origine = moteur:GetAttribute("TardisC0")
				moteur:SetAttribute("TardisC0", nil)
				TweenService:Create(moteur, TweenInfo.new(duree or 0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { C0 = origine }):Play()
			end
		end
	end
end

-- Chute dans le vide (V6.9.7) : dernière position où le joueur se tenait sur un sol, loin sous la limite de destruction
-- de Roblox (workspace.FallenPartsDestroyHeight). Sert à rattraper un membre de la C.A.T. qui tombe hors de la carte,
-- au lieu de le laisser se régénérer dans le vide en boucle.
local positionsSures = {} -- [UserId] = CFrame
local derniersRattrapages = {} -- [UserId] = os.clock() du dernier rattrapage
local function seuilDuVide() return workspace.FallenPartsDestroyHeight end
-- Un sol existe-t-il encore sous cette position ? (le support a pu bouger ou disparaître : plateforme, véhicule, pièce détruite)
local function solSous(cf, personnage)
	local parametres = RaycastParams.new()
	parametres.FilterType = Enum.RaycastFilterType.Exclude
	parametres.FilterDescendantsInstances = { personnage }
	return workspace:Raycast(cf.Position, Vector3.new(0, -15, 0), parametres) ~= nil
end
local function pointDeSecours(joueur, personnage)
	local sure = positionsSures[joueur.UserId]
	-- Dernière position sûre, seulement s'il y a encore un sol dessous et si le joueur n'a pas déjà été rattrapé
	-- il y a moins de 15 s (sinon il retomberait au même endroit, et se régénérerait en boucle)
	local recent = derniersRattrapages[joueur.UserId] ~= nil and os.clock() - derniersRattrapages[joueur.UserId] < 15
	if sure and not recent and solSous(sure, personnage) then return sure end
	positionsSures[joueur.UserId] = nil
	-- Sinon : le spawn de l'équipe dans le TARDIS, ou la Part Arrivee de l'intérieur
	local spawn = spawnsEquipes[Config.nomEquipe()] or interieur:FindFirstChild("TardisSpawn_" .. def.Nom .. "_" .. Config.nomEquipe())
	local arrivee = interieur:FindFirstChild(Config.NomArrivee or "Arrivee")
	local part = (spawn and spawn:IsA("BasePart") and spawn) or (arrivee and arrivee:IsA("BasePart") and arrivee) or nil
	return part and (part.CFrame + Vector3.new(0, 3, 0)) or nil
end

local function surveillerPersonnage(joueur, personnage)
	if def.Nom ~= Config.Tardis[1].Nom then return end -- un seul exemplaire gère la régénération
	local humanoid = personnage:WaitForChild("Humanoid", 10)
	if not humanoid then return end
	-- Dans l'équipe : pas de mort normale (le client fait de même, voir TardisExtrasClient)
	local function majEligible()
		if not humanoid.Parent then return end
		local ok = estRegenerateur(joueur)
		humanoid.BreakJointsOnDeath = not ok
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, not ok)
		personnage:SetAttribute("TardisRegenerateur", ok)
	end
	majEligible()
	local connexionEquipe = joueur:GetPropertyChangedSignal("Team"):Connect(majEligible)
	personnage.AncestryChanged:Connect(function() if not personnage:IsDescendantOf(game) then connexionEquipe:Disconnect() end end)

	-- Articulations gardées (V6.7.1) : une commande :kill (BreakJoints) ou une explosion casse toutes les articulations.
	-- Pour un membre de la C.A.T., chacune est ressoudée à l'instant même : le corps ne tombe plus en miettes avant de se
	-- régénérer. Les suppressions voulues (membre qui repousse) portent l'attribut TardisVolontaire.
	personnage.DescendantRemoving:Connect(function(moteur)
		if not moteur:IsA("Motor6D") or moteur:GetAttribute("TardisVolontaire") then return end
		if not estRegenerateur(joueur) or personnage:GetAttribute("TardisMortReelle") == true then return end
		if not personnage:IsDescendantOf(workspace) then return end
		local fiche = { nom = moteur.Name, parent = moteur.Parent, part0 = moteur.Part0, part1 = moteur.Part1, c0 = moteur.C0, c1 = moteur.C1 }
		if not (fiche.parent and fiche.part0 and fiche.part1) then return end
		task.defer(function()
			if not personnage.Parent or not fiche.parent.Parent or not fiche.part0.Parent or not fiche.part1.Parent then return end
			if fiche.parent:FindFirstChild(fiche.nom) then return end
			-- La pièce n'a bougé que d'une image au plus : on la remet exactement en place avant de la ressouder
			fiche.part1.AssemblyLinearVelocity = Vector3.zero
			fiche.part1.AssemblyAngularVelocity = Vector3.zero
			fiche.part1.CFrame = fiche.part0.CFrame * fiche.c0 * fiche.c1:Inverse()
			local neuf = Instance.new("Motor6D")
			neuf.Name = fiche.nom
			neuf.Part0, neuf.Part1, neuf.C0, neuf.C1 = fiche.part0, fiche.part1, fiche.c0, fiche.c1
			neuf.Parent = fiche.parent
		end)
	end)

	local enCours = false
	local function derouler(changerTenue)
		enCours = true
		local nombre = regenerations[joueur.UserId] or 0
		local maximum = REGEN.Nombre or 0
		regenerations[joueur.UserId] = nombre + 1
		local duree = REGEN.Duree or 5
		-- Où ? Dans un TARDIS, il encaisse le choc
		local racinePos = (personnage:FindFirstChild("HumanoidRootPart") or personnage:FindFirstChild("Head"))
		local lieu = racinePos and tardisABord(racinePos.Position) or nil
		noterRegeneration(joueur, "Régénération", lieu, nombre + 1)
		if lieu then evenementABord:Fire(lieu) end
		-- Style de l'animation (Config.Regeneration.Style : 0 = au hasard, 1 à 5 = imposé)
		local style = REGEN.Style or 0
		if style < 1 or style > 7 then style = math.random(7) end
		personnage:SetAttribute("TardisRegenerationStyle", style)
		-- Invulnérable pendant toute la régénération : bouclier invisible, et la santé est maintenue au maximum
		local protection = Instance.new("ForceField")
		protection.Name = "TardisRegenerationProtection"
		protection.Visible = false
		protection.Parent = personnage
		humanoid.Health = humanoid.MaxHealth
		local garde = game:GetService("RunService").Heartbeat:Connect(function()
			if humanoid.Parent and humanoid.Health < humanoid.MaxHealth then humanoid.Health = humanoid.MaxHealth end
		end)
		-- Figé, bras écartés
		local vitesse, saut, hauteurSaut = humanoid.WalkSpeed, humanoid.JumpPower, humanoid.JumpHeight
		humanoid.WalkSpeed, humanoid.JumpPower, humanoid.JumpHeight = 0, 0, 0
		poseRegeneration(personnage, true, math.max((REGEN.Duree or 7) * 0.15, 0.5))
		personnage:SetAttribute("TardisRegenerationDuree", duree)
		personnage:SetAttribute("TardisRegeneration", workspace:GetServerTimeNow()) -- les clients jouent les effets
		dire(joueur, maximum > 0 and string.format("Régénération %d/%d…", nombre + 1, maximum) or string.format("Régénération n°%d…", nombre + 1), true)
		-- Au cœur de l'énergie : nouvelle apparence
		if changerTenue then
			-- L'avatar est chargé dès maintenant (le service peut être lent), puis appliqué au cœur de l'énergie
			local description, origine, prete = nil, nil, false
			task.spawn(function()
				description, origine = choisirDescription(joueur, humanoid)
				prete = true
			end)
			task.delay(duree * 0.55, function()
				local limite = os.clock() + duree * 0.35
				while not prete and os.clock() < limite do task.wait(0.1) end
				if personnage.Parent then changerApparence(joueur, personnage, humanoid, description, origine) end
			end)
		end
		task.delay(duree, function()
			garde:Disconnect()
			if not personnage.Parent then return end
			poseRegeneration(personnage, false)
			humanoid.WalkSpeed, humanoid.JumpPower, humanoid.JumpHeight = vitesse, saut, hauteurSaut
			bonusPV(humanoid) -- soigné, avec des PV en plus pendant quelques minutes
			personnage:SetAttribute("TardisRegeneration", nil)
			protection:Destroy()
			enCours = false
			surveillerMembres(joueur, personnage, REGEN.RepousseDuree or 300)
		end)
	end

	-- Chute dans le vide (V6.9.7) : on retient la dernière position sûre ; si le corps passe sous la limite, il est
	-- rattrapé (remonté à cette position, ou dans le TARDIS) puis la régénération se déroule là, une seule fois
	do
		local racineSuivi = personnage:WaitForChild("HumanoidRootPart", 5)
		local prochaineMemoire = 0
		local suivi
		if racineSuivi then suivi = game:GetService("RunService").Heartbeat:Connect(function()
			if not personnage.Parent or not racineSuivi.Parent then suivi:Disconnect() return end
			local y = racineSuivi.Position.Y
			local maintenant = os.clock()
			if maintenant >= prochaineMemoire then
				prochaineMemoire = maintenant + 0.5
				if humanoid.FloorMaterial ~= Enum.Material.Air and y > seuilDuVide() + 50 then positionsSures[joueur.UserId] = racineSuivi.CFrame end
			end
			if y < seuilDuVide() + 30 and estRegenerateur(joueur) and personnage:GetAttribute("TardisMortReelle") ~= true then
				local secours = pointDeSecours(joueur, personnage)
				if not secours then return end
				derniersRattrapages[joueur.UserId] = os.clock()
				racineSuivi.AssemblyLinearVelocity = Vector3.zero
				racineSuivi.AssemblyAngularVelocity = Vector3.zero
				personnage:PivotTo(secours)
				-- Tenu une seconde sur place : la physique du client (qui possède le personnage) ne le refait pas tomber aussitôt
				racineSuivi.Anchored = true
				task.delay(1, function() if racineSuivi.Parent then racineSuivi.Anchored = false end end)
				dire(joueur, "Chute dans le vide : le TARDIS t'a rattrapé.", false)
				if not enCours then humanoid.Health = 0 end -- la régénération se déroule à l'endroit sûr
			end
		end) end
	end

	-- Corps neuf après un corps disloqué : on le replace où était l'ancien, et la régénération se poursuit
	local attente = enAttente[joueur.UserId]
	if attente then
		enAttente[joueur.UserId] = nil
		local racine = personnage:WaitForChild("HumanoidRootPart", 5)
		-- V6.9.7 : jamais dans le vide (sinon il retombe et se régénère en boucle)
		if attente.position and attente.position.Y < seuilDuVide() + 30 then
			local secours = pointDeSecours(joueur, personnage)
			attente.position = secours and secours.Position or nil
		end
		if racine and attente.position then
			task.wait(0.1)
			local regard = attente.regard and Vector3.new(attente.regard.X, 0, attente.regard.Z) or Vector3.new(0, 0, -1)
			if regard.Magnitude < 0.1 then regard = Vector3.new(0, 0, -1) end
			personnage:PivotTo(CFrame.lookAt(attente.position, attente.position + regard.Unit))
		end
		if not attente.habille then habillerTenueJeu(personnage) end
		derouler(false)
	end

	local function mortReelle(nature)
		regenerations[joueur.UserId] = 0 -- le compteur repart de zéro
		local reference = personnage:FindFirstChild("HumanoidRootPart") or personnage:FindFirstChild("Head")
		noterRegeneration(joueur, nature, reference and tardisABord(reference.Position) or nil, nil)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
		humanoid.BreakJointsOnDeath = true
		personnage:SetAttribute("TardisMortReelle", true)
		humanoid.Health = 0
		humanoid:ChangeState(Enum.HumanoidStateType.Dead)
	end

	humanoid.HealthChanged:Connect(function(sante)
		if sante > 0 or enCours or not estRegenerateur(joueur) then return end
		enCours = true
		local maximum = REGEN.Nombre or 0 -- 0 = infini
		if maximum > 0 and (regenerations[joueur.UserId] or 0) >= maximum then
			mortReelle("Mort (plus de régénération)")
			return
		end
		-- Régénération refusée : quelques secondes pour choisir, sans pouvoir être tué pendant ce temps
		if REGEN.ChoixRefus ~= false then
			local delai = REGEN.DelaiChoix or 3
			local refuse = false
			local protection = Instance.new("ForceField")
			protection.Visible = false
			protection.Parent = personnage
			humanoid.Health = humanoid.MaxHealth
			local garde = game:GetService("RunService").Heartbeat:Connect(function()
				if humanoid.Parent and humanoid.Health < humanoid.MaxHealth then humanoid.Health = humanoid.MaxHealth end
			end)
			choixEnAttente[joueur.UserId] = function() refuse = true end
			personnage:SetAttribute("TardisRegenChoix", workspace:GetServerTimeNow() + delai)
			local fin = os.clock() + delai
			while os.clock() < fin and not refuse and personnage.Parent do task.wait(0.1) end
			choixEnAttente[joueur.UserId] = nil
			personnage:SetAttribute("TardisRegenChoix", nil)
			garde:Disconnect()
			protection:Destroy()
			if not personnage.Parent then return end
			if refuse then
				mortReelle("Régénération refusée")
				return
			end
		end
		if not corpsIntact(personnage) then
			-- Corps disloqué (commande :kill, explosion…) : impossible de le remettre d'aplomb, on en reconstruit un neuf
			-- au même endroit, déjà avec la nouvelle apparence, et la régénération s'y déroule
			enCours = true
			local reference = personnage:FindFirstChild("Head") or personnage:FindFirstChild("HumanoidRootPart")
			local description = choisirDescription(joueur, humanoid)
			enAttente[joueur.UserId] = {
				position = reference and (reference.Position + Vector3.new(0, 3, 0)) or nil,
				regard = reference and reference.CFrame.LookVector or nil,
				habille = description ~= nil,
			}
			local ok = pcall(function()
				if description then joueur:LoadCharacterWithHumanoidDescription(description) else joueur:LoadCharacter() end
			end)
			if not ok then enAttente[joueur.UserId] = nil end
			return
		end
		derouler(true)
	end)
end
local function suivreJoueur(joueur)
	joueur.CharacterAdded:Connect(function(personnage) task.spawn(surveillerPersonnage, joueur, personnage) end)
	if joueur.Character then task.spawn(surveillerPersonnage, joueur, joueur.Character) end
end
Players.PlayerAdded:Connect(suivreJoueur)
for _, joueur in Players:GetPlayers() do suivreJoueur(joueur) end
Players.PlayerRemoving:Connect(function(joueur) tenuesCompte[joueur.UserId] = nil derniereTenue[joueur.UserId] = nil enAttente[joueur.UserId] = nil positionsSures[joueur.UserId] = nil derniersRattrapages[joueur.UserId] = nil end)

--------------------------------------------------------------------
-- Outils des techniciens : chiffon (saleté), visseuse (surcharge de vapeur), clé à molette (vanne), extincteur
--------------------------------------------------------------------
local OUTILS = {
	Chiffon = { nom = "Chiffon", couleur = Color3.fromRGB(230, 225, 210), taille = Vector3.new(1, 0.3, 1) },
	Visseuse = { nom = "Visseuse / Dévisseuse", couleur = Color3.fromRGB(240, 170, 40), taille = Vector3.new(0.5, 0.5, 1.6) },
	CleMolette = { nom = "Clé à molette", couleur = Color3.fromRGB(160, 165, 175), taille = Vector3.new(0.4, 1.8, 0.3) },
	Extincteur = { nom = "Extincteur", couleur = Color3.fromRGB(200, 30, 30), taille = Vector3.new(0.7, 1.6, 0.7) },
}
local function donnerOutil(joueur, cle)
	local infos = OUTILS[cle]
	local sac = joueur:FindFirstChildOfClass("Backpack")
	if not infos or not sac then return end
	if sac:FindFirstChild(cle) or (joueur.Character and joueur.Character:FindFirstChild(cle)) then return end
	local outil = Instance.new("Tool")
	outil.Name = cle
	outil.ToolTip = infos.nom
	outil.RequiresHandle = true
	outil.CanBeDropped = false
	local manche = Instance.new("Part")
	manche.Name = "Handle"
	manche.Size = infos.taille
	manche.Color = infos.couleur
	manche.Material = cle == "Chiffon" and Enum.Material.Fabric or Enum.Material.Metal
	manche.CanCollide = false
	manche.Parent = outil
	outil.Parent = sac
	outil.Activated:Connect(function()
		local racine = racineDe(joueur)
		if not racine then return end
		if cle == "Chiffon" then
			if (racine.Position - exterieur:GetPivot().Position).Magnitude > 10 then dire(joueur, "Approche-toi de la cabine pour la nettoyer.", false) return end
			local salete = math.max((exterieur:GetAttribute("Salete") or 0) - 15, 0)
			exterieur:SetAttribute("Salete", salete)
			exterieur:SetAttribute("Nettoyage", workspace:GetServerTimeNow())
			dire(joueur, salete > 0 and string.format("Nettoyage : encore %d %% de saleté.", salete) or "La cabine est propre.", true)
		elseif cle == "Visseuse" then
			local grille = Config.grilleEnPanne(exterieur, interieur, grilles) -- (V6.9.12) même grille que celle du client
			if not grille then dire(joueur, "Aucune surcharge de vapeur à régler.", false) return end
			if (racine.Position - grille.Position).Magnitude > 8 then dire(joueur, "Approche-toi de la grille en surcharge.", false) return end
			local avancement = (exterieur:GetAttribute("VapeurSurchargeAvancement") or 0) + 1
			exterieur:SetAttribute("VapeurSurchargeAvancement", avancement)
			if avancement >= 3 then
				exterieur:SetAttribute("VapeurSurcharge", nil)
				exterieur:SetAttribute("VapeurGrille", nil) -- (V6.9.12)
				interne("jouer", "Reparation", false)
				direAuxPilotes("Surcharge de vapeur réglée par " .. joueur.DisplayName .. ".", true)
				fermerPanne("Vapeur", joueur) -- (V6.9.12)
			else
				dire(joueur, string.format("Réglage %d/3…", avancement), true)
			end
		elseif cle == "Extincteur" then
			exterieur:SetAttribute("ExtincteurJet", string.format("%s\t%.2f", joueur.Name, workspace:GetServerTimeNow()))
			local console = interieur:FindFirstChild("Console")
			local centre = console and (console:IsA("Model") and console:GetPivot().Position or partDe(console).Position) or Config.pivot(interieur).Position
			if exterieur:GetAttribute("Incendie") and not exterieur:GetAttribute("IncendieEteint") and (racine.Position - centre).Magnitude < 12 then
				exterieur:SetAttribute("IncendieEteint", workspace:GetServerTimeNow())
				dire(joueur, "Flammes éteintes… pour l'instant. Fermez la vanne avec la clé à molette.", true)
			end
		elseif cle == "CleMolette" then
			dire(joueur, "Maintiens E sur la vanne avec la clé en main pour la fermer.", true)
		end
	end)
end
local function retirerOutils(joueur, garderCle)
	for _, conteneur in { joueur:FindFirstChildOfClass("Backpack"), joueur.Character } do
		if conteneur then
			for cle, infos in OUTILS do
				local outil = conteneur:FindFirstChild(cle)
				if outil and not (garderCle and infos.garder) then outil:Destroy() end
			end
		end
	end
end

--------------------------------------------------------------------
-- Électricité statique : toucher la cabine pendant une démat (voyage ou en vol) donne un arc et de très légers dégâts
--------------------------------------------------------------------
do
	local derniersArcs = {}
	local function surveiller(part)
		part.Touched:Connect(function(autre)
			local personnage = autre.Parent
			local humanoid = personnage and personnage:FindFirstChildOfClass("Humanoid")
			local joueur = humanoid and Players:GetPlayerFromCharacter(personnage)
			if not joueur then return end
			local enDemat = exterieur:GetAttribute("Etat") == E.Demat or exterieur:GetAttribute("VolPhase") == E.Demat
			if not enDemat or os.clock() - (derniersArcs[joueur] or 0) < 0.8 then return end
			derniersArcs[joueur] = os.clock()
			humanoid:TakeDamage(S.DegatsStatique or 0.5)
			exterieur:SetAttribute("ArcStatique", string.format("%.1f\t%.1f\t%.1f\t%.2f", autre.Position.X, autre.Position.Y, autre.Position.Z, workspace:GetServerTimeNow()))
		end)
	end
	for _, objet in exterieur:GetDescendants() do
		if objet:IsA("BasePart") and objet.CanTouch and not objet:IsDescendantOf(exterieur:FindFirstChild("Boucliers") or exterieur.PrimaryPart) then surveiller(objet) end
	end
end

--------------------------------------------------------------------
-- Atterrissages : terrain réactif, bousculade des objets, atterrissage sur un véhicule, tempêtes
--------------------------------------------------------------------
local function solSousLeTardis()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclus = { exterieur, interieur }
	for _, autre in Players:GetPlayers() do
		if autre.Character then table.insert(exclus, autre.Character) end
	end
	params.FilterDescendantsInstances = exclus
	params.IgnoreWater = false
	return workspace:Raycast(exterieur:GetPivot().Position + Vector3.new(0, 2, 0), Vector3.new(0, -6, 0), params)
end
local vehiculeSuivi = nil -- { part, decalage }
local function surAtterrissage()
	local sol = solSousLeTardis()
	-- Terrain réactif : les clients jouent l'effet du matériau (sable, neige, métal, eau, herbe...)
	exterieur:SetAttribute("TerrainAtterrissage", sol and sol.Material.Name or "Inconnu")
	exterieur:SetAttribute("TerrainTemps", workspace:GetServerTimeNow())
	-- Bousculade : les objets non ancrés autour sont repoussés
	local centre = exterieur:GetPivot().Position
	local taille = exterieur:GetExtentsSize()
	local rayon = math.max(taille.X, taille.Z) * 1.2 + 2
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclus = { exterieur, interieur }
	for _, autre in Players:GetPlayers() do
		if autre.Character then table.insert(exclus, autre.Character) end
	end
	params.FilterDescendantsInstances = exclus
	local vus = {}
	for _, part in workspace:GetPartBoundsInRadius(centre, rayon, params) do
		local racine = part.AssemblyRootPart
		if racine and not racine.Anchored and not vus[racine] and racine.AssemblyMass < 3000 then
			vus[racine] = true
			local direction = (racine.Position - centre) * Vector3.new(1, 0, 1)
			direction = direction.Magnitude > 0.1 and direction.Unit or Vector3.new(1, 0, 0)
			racine.AssemblyLinearVelocity = direction * 22 + Vector3.new(0, 12, 0)
		end
	end
	-- Atterrissage sur un véhicule : posé sur un objet non ancré et lourd, le TARDIS le suit
	vehiculeSuivi = nil
	if sol and sol.Instance and sol.Instance:IsA("BasePart") then
		local racine = sol.Instance.AssemblyRootPart
		if racine and not racine.Anchored and racine.AssemblyMass >= 50 then
			vehiculeSuivi = { part = racine, decalage = racine.CFrame:ToObjectSpace(exterieur:GetPivot()) }
			direAuxPilotes("Posé sur un véhicule : le TARDIS le suit.", true)
		end
	end
end
game:GetService("RunService").Heartbeat:Connect(function()
	if not vehiculeSuivi then return end
	local etat = exterieur:GetAttribute("Etat") or E.Pose
	if etat ~= E.Pose or exterieur:GetAttribute("VolLibre") or exterieur:GetAttribute("Porteur") or not vehiculeSuivi.part.Parent then
		vehiculeSuivi = nil
		return
	end
	local cible = vehiculeSuivi.part.CFrame * vehiculeSuivi.decalage
	if (cible.Position - exterieur:GetPivot().Position).Magnitude > 0.05 then
		exterieur:PivotTo(cible)
		exterieur:SetAttribute("DepotCF", cible)
	end
end)
local etatAvant = exterieur:GetAttribute("Etat")
exterieur:GetAttributeChangedSignal("Etat"):Connect(function()
	local etat = exterieur:GetAttribute("Etat")
	if etat == E.Pose and etatAvant == E.Remat then task.delay(0.1, surAtterrissage) end
	etatAvant = etat
end)
local volLibreAvant = nil
exterieur:GetAttributeChangedSignal("VolLibre"):Connect(function()
	local id = exterieur:GetAttribute("VolLibre")
	if volLibreAvant and not id and not exterieur:GetAttribute("Detruit") then task.delay(0.1, surAtterrissage) end
	volLibreAvant = id
end)

-- Tempête temporelle en vol libre : de temps en temps, une rafale dévie le TARDIS (8 s)
task.spawn(function()
	while true do
		task.wait(180 + math.random() * 180)
		if exterieur:GetAttribute("VolLibre") and not exterieur:GetAttribute("DescenteDebut") and math.random() < 0.6 then
			local direction = Vector3.new(math.random() - 0.5, (math.random() - 0.5) * 0.4, math.random() - 0.5).Unit
			exterieur:SetAttribute("Tempete", string.format("%.2f\t%.2f\t%.2f\t%.2f\t%d", direction.X, direction.Y, direction.Z, workspace:GetServerTimeNow(), 8))
			direAuxPilotes("TEMPÊTE TEMPORELLE : le TARDIS est dévié pendant quelques secondes !", false)
		end
	end
end)
-- Tempête de vortex : trop longtemps dans le vortex (10 min), il se matérialise près de la destination du sélecteur
task.spawn(function()
	local debutVol = nil
	while true do
		task.wait(5)
		local etat = exterieur:GetAttribute("Etat") or E.Pose
		if etat == E.Vol then
			debutVol = debutVol or os.clock()
			if os.clock() - debutVol > 10 * 60 then
				debutVol = nil
				local dest = interne("destinationChoisie")
				local liste = interne("listeDestinations") or {}
				local proches = {}
				for _, part in liste do
					if not dest or (part.Position - dest.Position).Magnitude < 200 then table.insert(proches, part) end
				end
				local cible = #proches > 0 and proches[math.random(#proches)] or (#liste > 0 and liste[math.random(#liste)])
				if cible then
					interne("alerter", "TEMPÊTE DE VORTEX")
					direAuxPilotes("TEMPÊTE DE VORTEX : trop longtemps dans le vortex, le TARDIS se matérialise en urgence vers " .. cible.Name .. ".", false)
					interne("atterrir", cible.CFrame, cible.Name, false, cible, true)
				end
			end
		else
			debutVol = nil
		end
	end
end)

--------------------------------------------------------------------
-- Commandes
--------------------------------------------------------------------
exterieur:SetAttribute("Stabilisateur", true)

-- Siège extérieur (vol stationnaire) : poses R6 procédurales, appliquées par le serveur pour que tout le monde les voie
local posesOrigine = {} -- [personnage] = { [Motor6D] = C0 d'origine }
local function appliquerPose(personnage, pose)
	local torse = personnage:FindFirstChild("Torso")
	if not torse then return end
	local motors = {}
	for _, nom in { "Right Hip", "Left Hip", "Right Shoulder", "Left Shoulder" } do
		local m = torse:FindFirstChild(nom)
		if m and m:IsA("Motor6D") then motors[nom] = m end
	end
	posesOrigine[personnage] = posesOrigine[personnage] or {}
	for _, m in motors do posesOrigine[personnage][m] = posesOrigine[personnage][m] or m.C0 end
	local angles = ({
		[0] = { 0, 0, 0, 0 },                                -- pose normale
		[1] = { math.pi / 2, -math.pi / 2, 0, 0 },           -- assis, deux jambes dans le vide
		[2] = { math.pi / 2, -2.2, 0, 0 },                    -- une jambe dans le vide, l'autre remontée
		[3] = { 0.15, -0.15, math.pi, -math.pi },             -- accroché au bas du TARDIS, deux mains
		[4] = { 0.3, -0.1, math.pi, 0.35 },                   -- accroché d'une main
	})[pose] or { 0, 0, 0, 0 }
	local ordre = { "Right Hip", "Left Hip", "Right Shoulder", "Left Shoulder" }
	for i, nom in ordre do
		local m = motors[nom]
		if m then m.C0 = posesOrigine[personnage][m] * CFrame.Angles(0, 0, angles[i]) end
	end
end

--------------------------------------------------------------------
-- Tablette technicien (V6.7.2) : régulation de l'énergie, de l'air et de la vapeur, marche / arrêt de l'énergie,
-- redémarrage à distance, purge de l'air, diagnostic. Aucune commande de voyage, de vol, de portes ni de boucliers.
-- Tout est publié en attributs de l'extérieur : Regul<Systeme>, TechRedemarrageFin, TechPurgeFin, TechDiagnostic, TechDernier.
--------------------------------------------------------------------
local TECH = Config.Technicien or {}
local SYSTEMES_REGULES = { Energie = true, Air = true, Vapeur = true }
local function intensiteVapeur(valeur)
	return valeur / 50 * ((Config.Vapeur or {}).Intensite or 1)
end
for systeme in SYSTEMES_REGULES do
	if exterieur:GetAttribute("Regul" .. systeme) == nil then
		exterieur:SetAttribute("Regul" .. systeme, (TECH.Regulation or {})[systeme] or (systeme == "Vapeur" and 50 or 100))
	end
end
exterieur:SetAttribute("VapeurIntensite", intensiteVapeur(exterieur:GetAttribute("RegulVapeur") or 50))

local dernierTech = {}
local function commandeTechnique(joueur, donnees)
	if typeof(donnees) ~= "table" then return end
	local maintenant = os.clock()
	if dernierTech[joueur] and maintenant - dernierTech[joueur] < 0.25 then return end
	dernierTech[joueur] = maintenant
	local commande = donnees.commande

	if commande == "Reguler" then
		local systeme, valeur = donnees.systeme, donnees.valeur
		-- (V6.9.10.1 : un nombre seulement, entre 0 et 100 ; hors bornes, refusé au lieu d'être ramené dans 0..100)
		if type(systeme) ~= "string" or not SYSTEMES_REGULES[systeme] or type(valeur) ~= "number" or valeur ~= valeur then return end
		if valeur < 0 or valeur > 100 then return end
		valeur = math.floor(valeur + 0.5)
		-- (V6.9.12) l'auteur est noté avant la nouvelle valeur (l'historique des pannes le lit quand l'air remonte)
		exterieur:SetAttribute("TechDernier", string.format("%s\tRégulation %s : %d %%\t%.2f", joueur.DisplayName, string.lower(systeme), valeur, workspace:GetServerTimeNow()))
		exterieur:SetAttribute("Regul" .. systeme, valeur)
		if systeme == "Vapeur" then exterieur:SetAttribute("VapeurIntensite", intensiteVapeur(valeur)) end

	elseif commande == "Energie" then
		local ok, erreur = interne("basculerAlimentation")
		if ok then
			local allume = exterieur:GetAttribute("Alimentation") ~= false
			direAuxPilotes((allume and "Énergie rétablie par " or "Énergie coupée par ") .. joueur.DisplayName .. ".", allume)
			exterieur:SetAttribute("TechDernier", string.format("%s\t%s\t%.2f", joueur.DisplayName, allume and "Énergie rétablie" or "Énergie coupée", workspace:GetServerTimeNow()))
		else
			dire(joueur, "Impossible : " .. string.lower(erreur or "erreur"), false)
		end

	elseif commande == "Redemarrer" then
		if not exterieur:GetAttribute("RedemarrageRequis") then dire(joueur, "Aucun redémarrage requis.", false) return end
		if exterieur:GetAttribute("TechRedemarrageFin") then return end
		local duree = S.RedemarrageDuree or 10
		exterieur:SetAttribute("TechRedemarrageFin", workspace:GetServerTimeNow() + duree)
		interne("alerter", "REDÉMARRAGE À DISTANCE")
		direAuxPilotes(joueur.DisplayName .. " lance le redémarrage à distance (" .. duree .. " s).", true)
		task.delay(duree, function()
			exterieur:SetAttribute("TechRedemarrageFin", nil)
			if not exterieur:GetAttribute("RedemarrageRequis") then return end
			voyagesConsecutifs = 0
			exterieur:SetAttribute("VoyagesConsecutifs", 0)
			exterieur:SetAttribute("RedemarrageRequis", false)
			interne("reglerAlimentation", true)
			interne("jouer", "Reparation", false)
			direAuxPilotes("Système redémarré à distance par " .. joueur.DisplayName .. ".", true)
			fermerPanne("Coupure", joueur) -- (V6.9.12)
		end)

	elseif commande == "Purger" then
		if exterieur:GetAttribute("TechPurgeFin") then return end
		if exterieur:GetAttribute("Alimentation") == false then dire(joueur, "Impossible : hors tension.", false) return end
		local duree = TECH.DureePurge or 6
		exterieur:SetAttribute("TechPurgeFin", workspace:GetServerTimeNow() + duree)
		interne("alerter", "PURGE DE L'AIR")
		interne("jouer", "Reparation", false)
		task.delay(duree, function()
			exterieur:SetAttribute("TechPurgeFin", nil)
			-- (V6.9.12) l'auteur de la purge est noté avant que l'air remonte (l'historique des pannes le lit)
			exterieur:SetAttribute("TechDernier", string.format("%s\t%s\t%.2f", joueur.DisplayName, "Purge de l'air", workspace:GetServerTimeNow()))
			exterieur:SetAttribute("RegulAir", 100)
			dire(joueur, "Purge terminée : air à 100 %.", true)
		end)

	elseif commande == "Diagnostic" then
		exterieur:SetAttribute("TechDiagnostic", workspace:GetServerTimeNow())
		local defauts = {}
		-- (V6.9.12) chaque panne située dans sa zone (dossier Zones de l'intérieur, sinon par rapport à la console)
		local function situer(texte, objet)
			local zone = objet and Config.zoneDe(interieur, objet)
			return zone and (texte .. " (zone " .. zone .. ")") or texte
		end
		if exterieur:GetAttribute("Avarie") then table.insert(defauts, situer("avarie (intégrité à 0 %) au rotor", rotorPart)) end
		if exterieur:GetAttribute("RedemarrageRequis") then table.insert(defauts, situer("redémarrage requis au levier d'alimentation", trouverChemin("Alimentation"))) end
		if exterieur:GetAttribute("VapeurSurcharge") then
			local grille, numero = Config.grilleEnPanne(exterieur, interieur, grilles)
			table.insert(defauts, situer(numero and string.format("fuite de vapeur : grille n°%d", numero) or "fuite de vapeur", grille))
		end
		if exterieur:GetAttribute("Incendie") then table.insert(defauts, situer("incendie de console", interieur:FindFirstChild("Console"))) end
		if exterieur:GetAttribute("Alimentation") == false then table.insert(defauts, "hors tension") end
		if (exterieur:GetAttribute("RegulAir") or 100) < (TECH.SeuilAirVicie or 25) then table.insert(defauts, "air vicié") end
		if (exterieur:GetAttribute("RegulEnergie") or 0) > (TECH.SurtensionAuDessus or 90) then table.insert(defauts, "surtension") end
		if (exterieur:GetAttribute("PointsDeVie") or 100) < 60 then table.insert(defauts, string.format("intégrité %d %%", exterieur:GetAttribute("PointsDeVie") or 0)) end
		task.delay(2.5, function()
			dire(joueur, #defauts == 0 and "Diagnostic : tous les systèmes sont nominaux." or ("Diagnostic : " .. table.concat(defauts, ", ") .. "."), #defauts == 0)
		end)
	end
end
Players.PlayerRemoving:Connect(function(joueur) dernierTech[joueur] = nil end)

-- Usure de l'air (quand quelqu'un est à bord) et surtension (risque de fuite de vapeur)
task.spawn(function()
	while true do
		task.wait(30)
		local usure = TECH.UsureAir or 1
		if usure > 0 and not exterieur:GetAttribute("TechPurgeFin") then
			local occupants = 0
			for _, autre in Players:GetPlayers() do
				local racine = racineDe(autre)
				if racine and interne("dansInterieur", racine.Position) then occupants += 1 end
			end
			if occupants > 0 then
				local avant = exterieur:GetAttribute("RegulAir") or 100
				local air = math.max(avant - usure, 0)
				exterieur:SetAttribute("RegulAir", air)
				local seuil = TECH.SeuilAirVicie or 25
				if avant >= seuil and air < seuil then
					signalerPanne("AirVicie", string.format("air à %d %%", air)) -- (V6.9.12) annonce commune + historique
				end
			end
		end
		if (exterieur:GetAttribute("RegulEnergie") or 0) > (TECH.SurtensionAuDessus or 90) and exterieur:GetAttribute("Alimentation") ~= false
			and math.random() < 0.25 then
			if panneVapeur() then direAuxPilotes("Surtension : une grille de vapeur a lâché. Baisse la régulation de l'énergie.", false) end
		end
	end
end)
-- (V6.9.12) Air revenu au-dessus du seuil (purge ou régulation) : la panne « air vicié » se ferme dans l'historique, avec
-- le technicien de la dernière action (TechDernier) si elle date de moins de 10 s
exterieur:GetAttributeChangedSignal("RegulAir"):Connect(function()
	if (tonumber(exterieur:GetAttribute("RegulAir")) or 100) < (TECH.SeuilAirVicie or 25) then return end
	local par = nil
	local dernier = exterieur:GetAttribute("TechDernier")
	if type(dernier) == "string" then
		local nom, quand = string.match(dernier, "^(.-)\t.-\t([%d%.]+)$")
		if nom and tonumber(quand) and workspace:GetServerTimeNow() - tonumber(quand) < 10 then par = nom end
	end
	fermerPanne("AirVicie", par)
end)

local derniereMaintenance = {}
Players.PlayerRemoving:Connect(function(joueur) derniereMaintenance[joueur] = nil end)
remote.OnServerEvent:Connect(function(joueur, action, donnees)
	if action == "Maintenance" then
		-- Mode maintenance (V6.9.4) : un pilote ou un technicien de ce TARDIS l'active ou le lève
		if not (estTechnicien(joueur) or estPilote(joueur)) or typeof(donnees) ~= "table" then return end
		local maintenant = os.clock()
		if derniereMaintenance[joueur] and maintenant - derniereMaintenance[joueur] < 2 then return end
		derniereMaintenance[joueur] = maintenant
		local activer = donnees.actif == true
		if activer == (exterieur:GetAttribute("Maintenance") ~= nil) then return end
		if activer then
			if (exterieur:GetAttribute("Etat") or E.Pose) ~= E.Pose or exterieur:GetAttribute("VolLibre") or exterieur:GetAttribute("Porteur") then
				dire(joueur, "Impossible : le TARDIS doit être posé pour passer en maintenance.", false)
				return
			end
			local raisons = (Config.Maintenance or {}).Raisons or { "Réparations en cours" }
			local raison = raisons[tonumber(donnees.raison) or 1] or raisons[1]
			exterieur:SetAttribute("Maintenance", raison)
			exterieur:SetAttribute("MaintenancePar", joueur.DisplayName)
			dire(joueur, "TARDIS en maintenance (" .. raison .. ") : plus de voyage ni de vol jusqu'à la levée.", true)
		else
			exterieur:SetAttribute("Maintenance", nil)
			exterieur:SetAttribute("MaintenancePar", nil)
			dire(joueur, "Maintenance levée : le TARDIS peut de nouveau voyager.", true)
		end
		local bus = ServerStorage:FindFirstChild("TardisEvenements")
		if bus then
			bus:Fire("Journal", { categorie = "Maintenance", tardis = def.Nom, message = string.format("%s : maintenance %s par %s%s.", def.Nom,
				activer and "commencée" or "levée", joueur.Name, activer and (" (" .. tostring(exterieur:GetAttribute("Maintenance")) .. ")") or "") })
		end
		return
	end
	if action == "Tech" then
		-- Techniciens et pilotes (les pilotes l'ouvrent depuis l'outil Ingénierie de leur tablette)
		if not (estTechnicien(joueur) or estPilote(joueur)) then return end
		commandeTechnique(joueur, donnees)
		return
	end
	if action == "RefuserRegeneration" then
		local refuser = choixEnAttente[joueur.UserId]
		if refuser then refuser() end
		return
	end
	if action == "TenuesCompte" then
		local ids = typeof(donnees) == "table" and donnees.ids
		if type(ids) ~= "table" then return end
		local propres = {}
		for _, id in ids do
			if type(id) == "number" and id > 0 and id == math.floor(id) and #propres < 50 then table.insert(propres, id) end
		end
		tenuesCompte[joueur.UserId] = propres
		return
	end
	if action == "SiegePose" then
		local pose = typeof(donnees) == "table" and tonumber(donnees.pose) or 0
		if joueur.Character and exterieur:GetAttribute("VolLibre") == joueur.UserId then appliquerPose(joueur.Character, math.clamp(math.floor(pose), 0, 4)) end
		return
	end
	if action == "Outil" then
		if not estTechnicien(joueur) then return end
		local mon = Config.tardisDuJoueur(joueur)
		if mon and mon.Nom ~= def.Nom then return end -- les outils viennent de l'exemplaire de son TARDIS principal
		local cle = typeof(donnees) == "table" and donnees.outil
		if cle == "Retirer" then retirerOutils(joueur) elseif OUTILS[cle] then donnerOutil(joueur, cle) end
		return
	end
	if not estPilote(joueur) then return end
	if action == "LienTimeLord" then
		local actif = not ReplicatedStorage:GetAttribute("TardisLienTimeLord")
		ReplicatedStorage:SetAttribute("TardisLienTimeLord", actif)
		dire(joueur, actif and "Lien Time Lord activé : les membres de la C.A.T. ressentent les régénérations." or "Lien Time Lord désactivé.", true)
		return
	end
	if action == "Stabilisateur" then
		exterieur:SetAttribute("Stabilisateur", not exterieur:GetAttribute("Stabilisateur"))
		dire(joueur, exterieur:GetAttribute("Stabilisateur") and "Stabilisateur activé." or "Stabilisateur désactivé : la cabine vibrera pendant les voyages.", true)
	end
end)
-- Les outils disparaissent quand un technicien sort du TARDIS... sauf le chiffon, qui sert dehors
task.spawn(function()
	while true do
		task.wait(2)
		for _, joueur in Players:GetPlayers() do
			if estTechnicien(joueur) then
				local racine = racineDe(joueur)
				if racine and not interne("dansInterieur", racine.Position) and (racine.Position - exterieur:GetPivot().Position).Magnitude > 20 then
					retirerOutils(joueur)
				end
			end
		end
	end
end)

print("[TARDIS] " .. def.Nom .. " : systèmes prêts.")