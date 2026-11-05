-- ServerScriptService > TardisServeur (Script)
-- Gère l'état du TARDIS, la console, le menu à distance, le camouflage, les sons et les déplacements.
-- Les effets visuels (fondus, lampe, rotor, secousses) sont faits côté client.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("TardisConfig"))
local E = Config.Etats

local def = Config.demarrerPourChaqueTardis(script) -- cet exemplaire ne s'occupe que d'un TARDIS (voir Config.Tardis)
local exterieur, interieur = Config.modeles(def)
local dossierDestinations = Config.dossierDestinations(true) -- à la racine ou dans le dossier TARDIS
local dossierSons = ReplicatedStorage:WaitForChild("TardisAssets"):WaitForChild("Sons")

local portailInt = interieur:WaitForChild(Config.NomPortailInt)
local rotor = interieur:WaitForChild(Config.NomRotor)
-- Le Rotor peut être une Part ou un Model : les sons ont besoin d'une Part pour être positionnés
local partRotor = rotor:IsA("BasePart") and rotor or rotor:FindFirstChildWhichIsA("BasePart", true)
-- Un ProximityPrompt doit être dans une Part : si la commande est un Model, on prend sa première Part
-- (V6.9.10.1 : exclu = une commande rangée dedans qui a son propre prompt, comme Colors dans le Selecteur)
local function enPart(objet, exclu)
	if objet:IsA("BasePart") then return objet end
	local function libre(part) return part and not (exclu and (part == exclu or part:IsDescendantOf(exclu))) end
	if objet:IsA("Model") and libre(objet.PrimaryPart) then return objet.PrimaryPart end
	for _, part in objet:GetDescendants() do
		if part:IsA("BasePart") and libre(part) then return part end
	end
	return (objet:IsA("Model") and objet.PrimaryPart) or objet:FindFirstChildWhichIsA("BasePart", true)
end

-- Le Selecteur garde son prompt sur une autre pièce que le bouton Vol libre (Console › Selecteur › Colors, V6.9.10.1)
local selecteur = enPart(Config.Trouver(interieur, "Selecteur"), Config.trouverCommande(interieur, "VolLibre"))
local levier = enPart(Config.Trouver(interieur, "Levier"))

assert(exterieur.PrimaryPart, "[TARDIS] Le Model extérieur doit avoir un PrimaryPart (la base).")

-- Canal du menu à distance (client -> serveur pour les commandes, serveur -> client pour les réponses)
local remote = Instance.new("RemoteEvent")
remote.Name = Config.canal(def, "TardisCommande")
remote.Parent = ReplicatedStorage

--------------------------------------------------------------------
-- Sons (positionnés : autour de l'extérieur ET dans l'intérieur)
--------------------------------------------------------------------
-- Portée (V6.9.7) : « Dehors » pour les sons de la cabine, « Dedans » pour ceux de la salle de contrôle
local function appliquerPortee(son, cote)
	local reglage = (Config.PorteeSons or {})[cote]
	if not reglage then return end
	son.RollOffMode = Enum.RollOffMode.InverseTapered
	son.RollOffMinDistance = reglage.Min or 10
	son.RollOffMaxDistance = reglage.Max or 200
end

local function preparerSon(nom, parent, optionnel)
	local modele = dossierSons:FindFirstChild(nom)
	if not modele then
		if not optionnel then
			warn("[TARDIS] Son manquant : ReplicatedStorage.TardisAssets.Sons." .. nom)
		end
		return nil
	end
	local son = modele:Clone()
	appliquerPortee(son, parent == exterieur.PrimaryPart and "Dehors" or "Dedans")
	son.Parent = parent
	return son
end

-- Sons de Config.Sons (V6.7.3) : créés dans TardisAssets › Sons s'ils n'y sont pas déjà (un Sound placé à la main
-- dans Studio reste prioritaire). Le premier exemplaire du script les crée, les autres les trouvent.
for nom, reglage in Config.Sons or {} do
	local id = type(reglage) == "table" and reglage.Id or reglage
	local valide = (type(id) == "number" and id > 0) or (type(id) == "string" and id ~= "")
	if valide and not dossierSons:FindFirstChild(nom) then
		local son = Instance.new("Sound")
		son.Name = nom
		son.SoundId = type(id) == "number" and ("rbxassetid://" .. id) or id
		son.Volume = type(reglage) == "table" and reglage.Volume or 0.8
		son.PlaybackSpeed = type(reglage) == "table" and reglage.Vitesse or 1
		son.RollOffMaxDistance = 140
		son.Parent = dossierSons
	end
end

-- [nom] = { son extérieur, son intérieur }
-- Sons des voyages, tirés de Config.Modes (ceux du mode Express sont optionnels), et sons de la salle joués par les
-- autres scripts (V6.7.3 : Cloitre et Reparation n'étaient pas préparés, donc jamais joués)
local LISTE_SONS = { { "Camouflage", true }, { "Decamouflage", true }, { "Cloitre", true }, { "Reparation", true } }
for nomMode, reglages in Config.Modes do
	for _, nomSon in reglages.Sons do
		table.insert(LISTE_SONS, { nomSon, nomMode == "Express" })
	end
end
local sons = {}
for _, info in LISTE_SONS do
	local nom, optionnel = info[1], info[2]
	sons[nom] = {
		ext = preparerSon(nom, exterieur.PrimaryPart, optionnel),
		int = preparerSon(nom, partRotor, optionnel),
	}
end

-- Son express absent : le son normal, sans son silence de départ, coupé en fondu à la fin de l'animation express
local function jouerExpress(son, etat)
	local _, decalage = Config.Timing(etat, "Normal")
	local duree = Config.Timing(etat, "Express")
	local volume = son.Volume
	son:Play()
	son.TimePosition = decalage
	task.delay(math.max(duree - 0.4, 0), function()
		for i = 1, 8 do
			son.Volume = volume * (1 - i / 8)
			task.wait(0.05)
		end
		son:Stop()
		son.Volume = volume
	end)
end

local function jouer(nom, dehorsAussi)
	local groupe = sons[nom]
	-- Son d'urgence absent : on se rabat sur le son normal
	if not (groupe and (groupe.int or groupe.ext)) and string.find(nom, "_Urg") then
		groupe = sons[(string.gsub(nom, "_Urg", ""))]
	end
	if not groupe then return end
	if groupe.int then groupe.int:Play() end
	if dehorsAussi and groupe.ext then groupe.ext:Play() end
end

-- Son d'un voyage (démat ou remat) dans un mode. Son du mode absent : celui du mode Normal,
-- raccourci en express (voir jouerExpress)
local function jouerVoyage(etat, mode, dehorsAussi)
	mode = Config.normaliserMode(mode)
	if Config.Modes[mode].Discret then return end -- Silencieux (V6.9) : aucun son
	local groupe = sons[Config.Son(etat, mode)]
	if groupe and (groupe.int or groupe.ext) then
		return jouer(Config.Son(etat, mode), dehorsAussi)
	end
	local normal = sons[Config.Son(etat, "Normal")]
	if not normal then return end
	if mode ~= "Express" then return jouer(Config.Son(etat, "Normal"), dehorsAussi) end
	if normal.int then jouerExpress(normal.int, etat) end
	if dehorsAussi and normal.ext then jouerExpress(normal.ext, etat) end
end

local function etatActuel()
	return exterieur:GetAttribute("Etat") or E.Pose
end

--------------------------------------------------------------------
-- Destinations
--------------------------------------------------------------------
local indexDestination = 1
-- État partagé entre le script et ses modules (vol libre) : une table, pour que tous voient la même valeur
local partage = {
	occupe = false,           -- vrai pendant une animation (portes, demat, remat)
	positionActuelle = nil,   -- Part de destination où le TARDIS se trouve
	sauvegardeModifiee = false,
	expressPret = 0,          -- os.clock() à partir duquel un nouvel Express est possible (recharge, V6.6.4)
}
local precedent = nil        -- { cf, nom } : là d'où le TARDIS est parti (bouton "Dernière destination")

local historique = {} -- { { nom, x, y, z }, ... } : les 10 derniers atterrissages
local function publierHistorique()
	local lignes = {}
	for _, h in historique do
		table.insert(lignes, string.format("%s\t%.1f\t%.1f\t%.1f\t%s", h[1], h[2], h[3], h[4], h[5] or "Normal"))
	end
	exterieur:SetAttribute("Historique", table.concat(lignes, "\n"))
end
local function ajouterHistorique(nom, cf, mode)
	local p = cf.Position
	table.insert(historique, 1, { tostring(nom), p.X, p.Y, p.Z, Config.normaliserMode(mode) }) -- V6.6.4 : avec le mode
	while #historique > 10 do table.remove(historique) end
	publierHistorique()
	partage.sauvegardeModifiee = true
end

local function memoriserDepart()
	precedent = { cf = exterieur:GetPivot(), nom = tostring(exterieur:GetAttribute("Position") or "Départ") }
	exterieur:SetAttribute("PrecedentNom", precedent.nom)
	partage.sauvegardeModifiee = true
end

local function listeDestinations()
	local liste = {}
	for _, part in dossierDestinations:GetDescendants() do -- sous-dossiers compris (Zone accessible, Zone restreinte...)
		if part:IsA("BasePart") then
			table.insert(liste, part)
		end
	end
	table.sort(liste, function(a, b) return a.Name < b.Name end)
	return liste
end

local function destinationChoisie()
	local liste = listeDestinations()
	if #liste == 0 then return nil, 0 end
	indexDestination = math.clamp(indexDestination, 1, #liste)
	return liste[indexDestination], #liste
end

-- La liste est publiée en attribut pour le menu (les clients ne voient pas forcément le dossier avec le Streaming)
local function publierDestinations()
	local noms = {}
	for _, part in listeDestinations() do
		table.insert(noms, part.Name)
	end
	exterieur:SetAttribute("ListeDestinations", table.concat(noms, "\n"))
	-- Positions pour la mini-carte de la tablette : "nom<TAB>x<TAB>z" par ligne
	local carte = {}
	for _, part in listeDestinations() do
		table.insert(carte, string.format("%s\t%.1f\t%.1f", part.Name, part.Position.X, part.Position.Z))
	end
	exterieur:SetAttribute("CarteDestinations", table.concat(carte, "\n"))
end

-- Écrans de la console (V6.9.10.1) : faits en script par le module Ecrans, sur chaque pièce « Ecran » de la Console
-- (une, deux ou plus) et sur l'écran ingénieur. majEcran(message) : message court ; majEcran() : affichage normal.
local Ecrans = require(script:WaitForChild("Ecrans"))({ Config = Config, E = E, Players = Players, def = def, destinationChoisie = destinationChoisie, etatActuel = etatActuel, exterieur = exterieur, interieur = interieur, remote = remote })
local majEcran = Ecrans.majEcran

-- Journal du TARDIS (V6.8) : TardisSupervision l'envoie au journal du jeu (Config.Journal)
local function journal(categorie, message)
	local evenements = game:GetService("ServerStorage"):FindFirstChild("TardisEvenements")
	if evenements then evenements:Fire("Journal", { categorie = categorie, message = message, tardis = def.Nom }) end
end

local function alerter(message)
	majEcran(message)
	task.delay(2, majEcran)
end

--------------------------------------------------------------------
-- Collisions de l'extérieur et de la porte intérieure
--------------------------------------------------------------------
local collisionsOrigine = {}
for _, part in exterieur:GetDescendants() do
	if part:IsA("BasePart") then
		collisionsOrigine[part] = part.CanCollide
	end
end

local function setCollisionsExterieur(actives)
	for part, origine in collisionsOrigine do
		if part.Parent then
			part.CanCollide = actives and origine
		end
	end
end

-- Le Portail intérieur est un mur invisible tant que la porte est fermée ou que le TARDIS n'est pas posé
local function majPortailInterieur()
	local passable = exterieur:GetAttribute("PorteOuverte") == true and etatActuel() == E.Pose
	portailInt.CanCollide = not passable
end

local function setEtat(etat)
	exterieur:SetAttribute("DebutEtat", workspace:GetServerTimeNow())
	exterieur:SetAttribute("Etat", etat)
	if etat ~= E.Pose and exterieur:GetAttribute("Siege") then exterieur:SetAttribute("Siege", false) end -- V6.9 : le siège prend fin au départ
	majPortailInterieur()
	majEcran()
end

-- instantane = true : pas de fondu (utilisé pour l'atterrissage invisible)
local DUREE_CAMOUFLAGE = Config.DureeCamouflage or 2
local function setCamouflage(actif, instantane)
	-- +1 seconde de marge : le fondu est bien terminé chez tous les clients
	local decalage = instantane and (DUREE_CAMOUFLAGE + 1) or 0
	exterieur:SetAttribute("DebutCamouflage", workspace:GetServerTimeNow() - decalage)
	exterieur:SetAttribute("Camouflage", actif)
	majEcran()
end

--------------------------------------------------------------------
-- Initialisation (faite tôt : même si une fonction secondaire plante plus bas,
-- le TARDIS est posé, la vue/le passage marchent et le menu s'affiche)
--------------------------------------------------------------------
if exterieur:GetAttribute("PorteOuverte") == nil then
	exterieur:SetAttribute("PorteOuverte", false)
end
exterieur:SetAttribute("Verrouille", false)
exterieur:SetAttribute("Position", "Départ")
exterieur:SetAttribute("Retreci", false)
exterieur:SetAttribute("Echelle", 1)
exterieur:SetAttribute("Alimentation", true)
exterieur:SetAttribute("Alerte", false)
exterieur:SetAttribute("DemarrageBloque", false)
exterieur:SetAttribute("Mode", "Normal") -- mode du voyage en cours : Normal, Urgence ou Express
exterieur:SetAttribute("Porteur", nil)
exterieur:GetAttributeChangedSignal("PorteOuverte"):Connect(majPortailInterieur)
setCamouflage(false, true)
setEtat(E.Pose)

publierDestinations()
dossierDestinations.ChildAdded:Connect(publierDestinations)
dossierDestinations.ChildRemoved:Connect(publierDestinations)

--------------------------------------------------------------------
-- Pilotes autorisés à utiliser le menu
--------------------------------------------------------------------
local function estPilote(joueur)
	local pilotes = Config.Pilotes or {}
	if Config.estPiloteDe(def, joueur.UserId) then return true end -- liste globale ou liste de ce TARDIS
	-- Accès réservé à la liste : ni le propriétaire du jeu, ni les membres du groupe
	if pilotes.UniquementUserIds then return false end

	if game.CreatorType == Enum.CreatorType.User and joueur.UserId == game.CreatorId then
		return true
	end

	local groupe = pilotes.GroupeId or 0
	if groupe == 0 and game.CreatorType == Enum.CreatorType.Group then
		groupe = game.CreatorId
	end
	if groupe ~= 0 then
		local ok, rang = pcall(joueur.GetRankInGroup, joueur, groupe)
		if ok and rang >= (pilotes.RangMin or 255) then return true end
	end
	return false
end

local pilotes = {}
local function marquerActivite()
	exterieur:SetAttribute("ActivitePilote", workspace:GetServerTimeNow())
end
-- Les rôles temporaires (pilote promu, bannissement) viennent de TardisExtras, sous forme d'attributs du joueur
local function verifierJoueur(joueur)
	-- Pilote : config, rôle temporaire, ou accès donné par le jeu (Adonis, WL : TardisSupervision, V6.8)
	local autorise = estPilote(joueur) or joueur:GetAttribute("TardisPiloteTemp_" .. def.Nom) == true or joueur:GetAttribute("TardisAccesPilote") == true
	-- Un bannissement ne touche jamais un pilote de la config (pour ne pas s'enfermer dehors)
	if joueur:GetAttribute("TardisBanni_" .. def.Nom) == true and not Config.estPiloteDe(def, joueur.UserId) then
		autorise = false
	end
	pilotes[joueur] = autorise
	joueur:SetAttribute("TardisPilote_" .. def.Nom, autorise) -- pilote de CE TARDIS (sert aux menus côté client)
	local pilote_quelque_part = false
	for _, autre in Config.Tardis do
		if joueur:GetAttribute("TardisPilote_" .. autre.Nom) == true then pilote_quelque_part = true end
	end
	joueur:SetAttribute("TardisPilote", pilote_quelque_part)
end
local function suivreRoles(joueur)
	verifierJoueur(joueur)
	joueur:GetAttributeChangedSignal("TardisPiloteTemp_" .. def.Nom):Connect(function() verifierJoueur(joueur) end)
	joueur:GetAttributeChangedSignal("TardisBanni_" .. def.Nom):Connect(function() verifierJoueur(joueur) end)
	joueur:GetAttributeChangedSignal("TardisAccesPilote"):Connect(function() verifierJoueur(joueur) end)
end
Players.PlayerAdded:Connect(suivreRoles)
for _, joueur in Players:GetPlayers() do
	task.spawn(suivreRoles, joueur)
end
Players.PlayerRemoving:Connect(function(joueur)
	pilotes[joueur] = nil
end)

--------------------------------------------------------------------
-- Séquences : portes, décollage, atterrissage, camouflage
--------------------------------------------------------------------
-- (« occupe » est dans la table partage, en tête de la section Destinations)

-- Demande aux scripts Shut de fermer les portes et attend qu'elles le soient
local function fermerPortes()
	if not exterieur:GetAttribute("PorteOuverte") then return true end
	majEcran("FERMETURE DES PORTES")
	exterieur:SetAttribute("FermerPortes", true)
	local limite = os.clock() + 5
	while exterieur:GetAttribute("PorteOuverte") and os.clock() < limite do
		task.wait(0.1)
	end
	exterieur:SetAttribute("FermerPortes", false)
	return not exterieur:GetAttribute("PorteOuverte")
end

-- Posé -> En vol (le TARDIS reste en vol jusqu'à un atterrissage)
-- mode : "Normal", "Urgence" (sons Demat_Urg, animation saccadée) ou "Express" (2 s) ; voir Config.Modes
--------------------------------------------------------------------
-- Vortex temporel (voyage classique) : pendant le vol, le TARDIS est visible très haut dans le ciel et tourne sur
-- lui-même, entouré du vortex (dessiné par les clients). Les passagers clandestins collés à la cabine au départ
-- sont emportés avec elle, puis déposés dehors à l'arrivée.
--------------------------------------------------------------------
local dansInterieur -- définie plus bas (section des joueurs)
local dansZoneRefusee -- définie plus bas (atterrissage)
local dansZoneSansExpress -- définie plus bas (atterrissage)
local ouvrirPortesSimple -- définie plus bas (portes) ; utilisée par l'atterrissage de sauvetage
local clandestins = {} -- [joueur] = décalage par rapport au TARDIS
local rotationCiel = nil
local function reperer_clandestins()
	table.clear(clandestins)
	local boiteCF, boiteTaille = exterieur:GetBoundingBox()
	for _, autre in Players:GetPlayers() do
		local racine = autre.Character and autre.Character:FindFirstChild("HumanoidRootPart")
		if racine and not dansInterieur(racine.Position) then
			local local_ = boiteCF:PointToObjectSpace(racine.Position)
			local demi = boiteTaille / 2 + Vector3.new(2.5, 3, 2.5)
			if math.abs(local_.X) <= demi.X and math.abs(local_.Y) <= demi.Y and math.abs(local_.Z) <= demi.Z then
				clandestins[autre] = exterieur:GetPivot():ToObjectSpace(racine.CFrame)
				racine.Anchored = true
				remote:FireClient(autre, "Tu es resté collé au TARDIS : accroche-toi !", false)
			end
		end
	end
end
local function partir_dans_le_ciel()
	local ciel = Config.PositionCiel or Vector3.new(2000, 2000, 2000)
	exterieur:SetAttribute("Ciel", true)
	rotationCiel = { angle = 0, ciel = ciel }
	task.spawn(function()
		while rotationCiel and etatActuel() == E.Vol do
			local dt = task.wait()
			-- L'atterrissage a pu commencer pendant l'attente (quasi certain en mode express) : on s'arrête net,
			-- sinon rotationCiel vaut nil (erreur) ou le TARDIS serait replacé dans le ciel
			if not rotationCiel or etatActuel() ~= E.Vol then break end
			rotationCiel.angle += dt * 0.5
			local cf = CFrame.new(rotationCiel.ciel) * CFrame.Angles(0, rotationCiel.angle, 0) * CFrame.Angles(0.08 * math.sin(rotationCiel.angle * 0.7), 0, 0)
			exterieur:PivotTo(cf)
			for autre, decalage in clandestins do
				local racine = autre.Character and autre.Character:FindFirstChild("HumanoidRootPart")
				if racine then racine.CFrame = cf * decalage else clandestins[autre] = nil end
			end
		end
	end)
end
local function revenir_du_ciel()
	rotationCiel = nil
	exterieur:SetAttribute("Ciel", false)
end
local function deposer_clandestins()
	local pivot = exterieur:GetPivot()
	for autre, decalage in clandestins do
		local racine = autre.Character and autre.Character:FindFirstChild("HumanoidRootPart")
		if racine then
			racine.CFrame = pivot * decalage + Vector3.new(0, 0.5, 0)
			racine.Anchored = false
			remote:FireClient(autre, "Le TARDIS s'est posé : tu peux lâcher.", true)
		end
	end
	table.clear(clandestins)
end
Players.PlayerRemoving:Connect(function(joueur) clandestins[joueur] = nil end)

-- Express (V6.6.4) : recharge entre deux voyages express, et zones où il est interdit (sous-dossier SANS_EXPRESS).
-- Renvoie le mode à utiliser : un Express impossible devient un voyage normal, avec un message sur l'écran.
local function modeAutorise(mode, position)
	if mode ~= "Express" then return mode end
	local reste = partage.expressPret - os.clock()
	if reste > 0 then
		alerter(string.format("EXPRESS EN RECHARGE (%d s) : VOYAGE NORMAL", math.ceil(reste)))
		return "Normal"
	end
	if dansZoneSansExpress and dansZoneSansExpress(position) then
		alerter("ZONE SANS EXPRESS : VOYAGE NORMAL")
		return "Normal"
	end
	return mode
end

local function decoller(mode)
	mode = Config.normaliserMode(mode)
	if partage.occupe then return false, "TARDIS OCCUPÉ" end
	if etatActuel() ~= E.Pose then return false, "DÉJÀ EN VOL" end
	if exterieur:GetAttribute("Porteur") then return false, "TARDIS PORTÉ" end
	if exterieur:GetAttribute("Alimentation") == false then return false, "HORS TENSION" end
	if exterieur:GetAttribute("DemarrageBloque") then return false, "DÉMARRAGE BLOQUÉ" end
	-- Alerte générale : toujours en urgence
	if exterieur:GetAttribute("Alerte") then mode = "Urgence" end
	-- Zone refusée au départ (V6.7.1) : le décollage se fait en urgence
	if not Config.modeSaccade(mode) and dansZoneRefusee and dansZoneRefusee(exterieur:GetPivot().Position) then
		alerter("ZONE REFUSÉE : DÉCOLLAGE D'URGENCE")
		mode = "Urgence"
	end
	mode = modeAutorise(mode, exterieur:GetPivot().Position)
	if mode == "Catastrophe" then mode = "Urgence" end -- la catastrophe n'existe qu'à l'atterrissage

	partage.occupe = true
	exterieur:SetAttribute("Verrouille", true)

	if not fermerPortes() then
		exterieur:SetAttribute("Verrouille", false)
		partage.occupe = false
		return false, "PORTES BLOQUÉES"
	end
	memoriserDepart()
	exterieur:SetAttribute("SurEau", false)

	local camoufle = exterieur:GetAttribute("Camouflage") == true
	exterieur:SetAttribute("Mode", mode) -- posé AVANT l'état : les clients choisissent la bonne animation
	setEtat(E.Demat)
	jouerVoyage(E.Demat, mode, not camoufle) -- camouflé : on ne l'entend que de l'intérieur
	local duree, decalage = Config.Timing(E.Demat, mode)
	task.wait(decalage + duree) -- son d'abord, puis l'animation complète

	setCollisionsExterieur(false)
	setCamouflage(false, true) -- remis à zéro pendant le vol (invisible de toute façon)
	-- Passagers clandestins : ceux qui se collent à la cabine au moment du départ partent avec elle
	reperer_clandestins()
	setEtat(E.Vol) -- vol silencieux
	-- Vortex temporel : le TARDIS visible, très haut dans le ciel, tournant dans son vortex jusqu'à la matérialisation
	partir_dans_le_ciel()

	partage.occupe = false
	return true
end

-- Calcule où poser le TARDIS sur un joueur : au sol, exactement à sa position, porte dans la direction de son regard
local boiteInterieurCF, boiteInterieurTaille = interieur:GetBoundingBox()

dansInterieur = function(position)
	local p = boiteInterieurCF:PointToObjectSpace(position)
	return math.abs(p.X) <= boiteInterieurTaille.X / 2
		and math.abs(p.Y) <= boiteInterieurTaille.Y / 2
		and math.abs(p.Z) <= boiteInterieurTaille.Z / 2
end

-- Hauteur où poser la Racine sur le sol sous un point (en ignorant le TARDIS et les personnages)
local function chercherSol(origine, distance)
	local exclus = { exterieur, interieur }
	for _, autre in Players:GetPlayers() do
		if autre.Character then table.insert(exclus, autre.Character) end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclus
	params.RespectCanCollide = true

	local resultat = workspace:Raycast(origine, Vector3.new(0, -(distance or 60), 0), params)
	if not resultat then return nil end
	return resultat.Position + Vector3.new(0, exterieur.PrimaryPart.Size.Y / 2, 0)
end

-- Le TARDIS est-il posé sur de l'eau ? (il flotte alors et tangue chez les clients)
local function verifierEau()
	local pivot = exterieur:GetPivot()
	local exclus = { exterieur, interieur }
	for _, autre in Players:GetPlayers() do
		if autre.Character then table.insert(exclus, autre.Character) end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclus
	params.IgnoreWater = false
	local resultat = workspace:Raycast(pivot.Position + Vector3.new(0, 2, 0), Vector3.new(0, -6, 0), params)
	exterieur:SetAttribute("BaseEau", pivot) -- en premier : les clients en ont besoin pour tanguer
	exterieur:SetAttribute("SurEau", resultat ~= nil and resultat.Material == Enum.Material.Water)
end

-- autoriserInterieur : vrai seulement pour la commande Remat des menus (paradoxe confirmé par le pilote) ;
-- les autres appels (balise, rappel, téléportation de poche, saisie) refusent un joueur à bord
local function cibleJoueur(joueurCible, autoriserInterieur)
	local personnage = joueurCible.Character
	local racine = personnage and personnage:FindFirstChild("HumanoidRootPart")
	if not racine then return nil, "JOUEUR SANS PERSONNAGE" end
	local devant = racine.CFrame.LookVector * Vector3.new(1, 0, 1)
	devant = devant.Magnitude > 0.01 and devant.Unit or Vector3.new(0, 0, -1)
	if dansInterieur(racine.Position) then
		if not autoriserInterieur then return nil, "JOUEUR DANS LE TARDIS" end
		-- Joueur à bord (V6.7.1) : la destination est le TARDIS lui-même (paradoxe, voir la commande Remat).
		-- Le sol de la salle fait partie de l'intérieur (ignoré par chercherSol) : on pose la cabine aux pieds du joueur.
		local humanoid = personnage:FindFirstChildOfClass("Humanoid")
		local pieds = racine.Position - Vector3.new(0, (humanoid and humanoid.HipHeight or 2) + racine.Size.Y / 2, 0)
		local sol = pieds + Vector3.new(0, exterieur.PrimaryPart.Size.Y / 2, 0)
		return CFrame.lookAt(sol, sol + devant)
	end

	local sol = chercherSol(racine.Position)
	if not sol then return nil, "PAS DE SOL SOUS LE JOUEUR" end
	return CFrame.lookAt(sol, sol + devant)
end

-- Tous les joueurs qui se trouvent à l'emplacement du TARDIS quand il se pose sont emmenés à l'intérieur
-- (le joueur ciblé, mais aussi n'importe qui d'autre : sinon il resterait coincé dans la cabine)
local function emmenerALInterieur()
	local boiteCF, boiteTaille = exterieur:GetBoundingBox()
	local marge = 1

	-- Point d'arrivée : la Part "Arrivee" de l'intérieur si elle existe, sinon juste derrière la porte intérieure
	local arrivee = interieur:FindFirstChild(Config.NomArrivee or "Arrivee")
	local base
	if arrivee and arrivee:IsA("BasePart") then
		base = arrivee.CFrame * CFrame.new(0, arrivee.Size.Y / 2 + 3, 0)
	else
		base = portailInt.CFrame * CFrame.new(0, -portailInt.Size.Y / 2 + 3, 5) * CFrame.Angles(0, math.pi, 0)
	end

	local nombre = 0
	for _, joueur in Players:GetPlayers() do
		local personnage = joueur.Character
		local racine = personnage and personnage:FindFirstChild("HumanoidRootPart")
		if racine then
			local p = boiteCF:PointToObjectSpace(racine.Position)
			if math.abs(p.X) <= boiteTaille.X / 2 + marge
				and math.abs(p.Y) <= boiteTaille.Y / 2 + marge
				and math.abs(p.Z) <= boiteTaille.Z / 2 + marge then
				-- Plusieurs joueurs : on les place côte à côte
				local decalageX = ((nombre % 3) - 1) * 2.5
				local decalageZ = math.floor(nombre / 3) * 2.5
				racine.AssemblyLinearVelocity = Vector3.zero
				personnage:PivotTo(base * CFrame.new(decalageX, 0, decalageZ))
				nombre += 1
			end
		end
	end
end

-- Portes bloquées si le TARDIS est trop petit (sous Config.TailleOuverturePortes)
local function tropPetitPourLesPortes(facteur)
	facteur = facteur or exterieur:GetAttribute("Echelle") or 1
	return facteur < (Config.TailleOuverturePortes or 1) - 0.001
end

-- Le TARDIS posé à "cible" rentrerait-il dans un mur ? (boîte englobante légèrement réduite,
-- pour ne pas compter le simple contact avec le sol)
local function enCollision(cible)
	local taille = exterieur:GetExtentsSize()
	local hauteurRacine = exterieur.PrimaryPart.Size.Y / 2
	local marge = 0.4
	local centre = cible * CFrame.new(0, taille.Y / 2 - hauteurRacine + marge / 2, 0)

	local exclus = { exterieur, interieur }
	for _, autre in Players:GetPlayers() do
		if autre.Character then table.insert(exclus, autre.Character) end
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclus
	params.RespectCanCollide = true

	local taillesReduite = Vector3.new(
		math.max(taille.X - marge, 0.1), math.max(taille.Y - marge, 0.1), math.max(taille.Z - marge, 0.1))
	return #workspace:GetPartBoundsInBox(centre, taillesReduite, params) > 0
end

-- En vol -> Posé (visible ou invisible)
-- cible : CFrame où poser la Racine · nom : affiché dans le menu · partDestination : la Part si c'est une destination
-- Retourne ok, erreur, urgenceForcee (vrai si une collision a imposé l'urgence)
local function atterrir(cible, nom, invisible, partDestination, mode)
	mode = Config.normaliserMode(mode)
	if partage.occupe then return false, "TARDIS OCCUPÉ" end
	if etatActuel() ~= E.Vol then return false, "PAS EN VOL" end
	if exterieur:GetAttribute("Alimentation") == false then return false, "HORS TENSION" end
	-- Alerte générale : toujours en urgence
	if exterieur:GetAttribute("Alerte") then mode = "Urgence" end

	-- Une partie du TARDIS dans un mur : atterrissage d'urgence obligatoire (même en rapide)
	local urgenceForcee = false
	local okCollision, collision = pcall(enCollision, cible)
	if okCollision and collision and not Config.modeSaccade(mode) then
		mode, urgenceForcee = "Urgence", true
	end
	-- Zone refusée (sous-dossier REFUSE des destinations) : atterrissage d'urgence, directement (V6.7.1 ; avant,
	-- la première tentative était repoussée dans le vortex)
	if not Config.modeSaccade(mode) and dansZoneRefusee(cible.Position) then
		alerter("ZONE REFUSÉE : ATTERRISSAGE D'URGENCE")
		mode, urgenceForcee = "Urgence", true
	end
	mode = modeAutorise(mode, cible.Position)
	local reglages = Config.Modes[mode]

	partage.occupe = true

	revenir_du_ciel()
	-- Sauvetage : la cabine apparaît en hauteur et descend en tournant pendant toute la matérialisation
	local hauteurSauvetage = (mode == "Sauvetage" and reglages.Hauteur) or 0
	exterieur:PivotTo(hauteurSauvetage > 0 and (cible + Vector3.new(0, hauteurSauvetage, 0)) or cible)
	partage.positionActuelle = partDestination
	exterieur:SetAttribute("Position", nom)
	deposer_clandestins()

	-- Le camouflage est posé AVANT l'état, pour qu'aucune image ne montre le TARDIS
	setCamouflage(invisible, true)
	exterieur:SetAttribute("Mode", mode) -- posé AVANT l'état : les clients choisissent la bonne animation
	setEtat(E.Remat)
	jouerVoyage(E.Remat, mode, not invisible) -- invisible : on ne l'entend que de l'intérieur
	local duree, decalage = Config.Timing(E.Remat, mode)
	if hauteurSauvetage > 0 then
		-- Descente : du sommet au sol pendant l'animation, en tournant sur elle-même (les clients lissent le mouvement)
		local debut = os.clock()
		local tours = reglages.Tours or 1
		while os.clock() - debut < decalage + duree do
			task.wait()
			if etatActuel() ~= E.Remat then break end
			local p = math.clamp((os.clock() - debut - decalage) / duree, 0, 1)
			local douceur = 1 - (1 - p) * (1 - p) -- vite au début, lente à la fin
			local hauteur = hauteurSauvetage * (1 - douceur)
			exterieur:PivotTo(cible * CFrame.Angles(0, (1 - douceur) * tours * math.pi * 2, 0) + Vector3.new(0, hauteur, 0))
		end
		exterieur:PivotTo(cible)
	else
		task.wait(decalage + duree) -- son d'abord, puis l'animation complète
	end

	emmenerALInterieur() -- avant les collisions, sinon les joueurs seraient coincés dans la cabine
	setCollisionsExterieur(true)
	setEtat(E.Pose)
	exterieur:SetAttribute("Mode", "Normal")
	-- Trop petit : les portes restent bloquées
	exterieur:SetAttribute("Verrouille", tropPetitPourLesPortes())
	partage.occupe = false
	verifierEau()
	ajouterHistorique(nom, cible, mode)
	if mode == "Express" then partage.expressPret = os.clock() + (Config.Modes.Express.Recharge or 0) end
	if mode == "Catastrophe" then
		-- Atterrissage forcé dans le TARDIS lui-même : la cabine encaisse (TardisSystemes lit cet attribut), alerte générale
		exterieur:SetAttribute("Catastrophe", workspace:GetServerTimeNow())
		if not exterieur:GetAttribute("Alerte") then exterieur:SetAttribute("Alerte", true) end
		alerter("PARADOXE : TARDIS DANS LE TARDIS")
	end
	-- Sauvetage : les portes s'ouvrent toutes seules ; sinon elles restent fermées (ouvertes quand un joueur veut sortir)
	if reglages.OuvrirPortes and not invisible then
		task.spawn(function()
			task.wait(0.6)
			ouvrirPortesSimple()
		end)
	end
	return true, nil, urgenceForcee
end

-- Atterrissage avorté (V6.7.1) : la destination est dans le TARDIS lui-même. La matérialisation commence en mode
-- Catastrophe, puis la cabine est repoussée dans le vortex. Le pilote doit confirmer pour forcer (mode Catastrophe).
local function atterrissageAvorte(cible, nom, invisible)
	if partage.occupe then return false, "TARDIS OCCUPÉ" end
	if etatActuel() ~= E.Vol then return false, "PAS EN VOL" end
	if exterieur:GetAttribute("Alimentation") == false then return false, "HORS TENSION" end
	partage.occupe = true
	revenir_du_ciel()
	exterieur:PivotTo(cible)
	setCamouflage(invisible, true)
	alerter("PARADOXE : DESTINATION DANS LE TARDIS")
	exterieur:SetAttribute("Mode", "Catastrophe")
	setEtat(E.Remat)
	jouerVoyage(E.Remat, "Catastrophe", not invisible)
	local duree, decalage = Config.Timing(E.Remat, "Catastrophe")
	task.wait(decalage + duree * 0.45)
	if etatActuel() == E.Remat then
		alerter("MATÉRIALISATION REPOUSSÉE : CONFIRMER POUR FORCER")
		exterieur:SetAttribute("Mode", "Urgence")
		setEtat(E.Demat) -- il redisparaît (démat d'urgence, courte)
		jouerVoyage(E.Demat, "Urgence", not invisible)
		local dureeDemat, decalageDemat = Config.Timing(E.Demat, "Urgence")
		task.wait(decalageDemat + dureeDemat)
		setCollisionsExterieur(false)
		setEtat(E.Vol)
		exterieur:SetAttribute("Mode", "Normal")
		partir_dans_le_ciel()
	end
	partage.occupe = false
	return true
end

-- La position est-elle dans une zone d'un sous-dossier de TARDIS_DESTINATIONS (REFUSE, SANS_EXPRESS…) ?
local function dansZone(position, nomDossier)
	local dossier = Config.dossierDestinations(false)
	local zone = dossier and dossier:FindFirstChild(nomDossier)
	if not zone then return false end
	for _, part in zone:GetDescendants() do
		if part:IsA("BasePart") then
			local local_ = part.CFrame:PointToObjectSpace(position)
			local demi = part.Size / 2 + Vector3.new(6, 6, 6)
			if math.abs(local_.X) <= demi.X and math.abs(local_.Y) <= demi.Y and math.abs(local_.Z) <= demi.Z then return true end
		end
	end
	return false
end
dansZoneRefusee = function(position) return dansZone(position, Config.ZoneRestreinte or "REFUSE") end
-- Zone sans express (V6.6.4) : un voyage Express qui part de là ou y arrive devient un voyage normal
dansZoneSansExpress = function(position) return dansZone(position, Config.ZoneSansExpress or "SANS_EXPRESS") end

-- Rétréci : il ne peut atterrir que là où il a décollé
local function cibleSurPlace()
	local pivot = exterieur:GetPivot()
	local devant = pivot.LookVector * Vector3.new(1, 0, 1)
	devant = devant.Magnitude > 0.01 and devant.Unit or Vector3.new(0, 0, -1)
	-- Il a pu décoller en plein vol : on le pose au sol, à la verticale
	local sol = chercherSol(pivot.Position + Vector3.new(0, 2, 0), 3000)
	if sol then
		return CFrame.lookAt(sol, sol + devant), exterieur:GetAttribute("Position") or "Sur place"
	end
	return pivot, exterieur:GetAttribute("Position") or "Sur place"
end

-- Fermeture simple des portes (sans verrouiller)
local function fermerPortesSimple()
	if not exterieur:GetAttribute("PorteOuverte") then return false, "PORTES DÉJÀ FERMÉES" end
	if partage.occupe then return false, "TARDIS OCCUPÉ" end
	partage.occupe = true
	local fermees = fermerPortes()
	partage.occupe = false
	majEcran()
	if not fermees then return false, "PORTES BLOQUÉES" end
	return true
end

-- Ouverture des portes à la demande (menu) : les scripts Shut ouvrent les deux battants
ouvrirPortesSimple = function()
	if exterieur:GetAttribute("PorteOuverte") then return false, "PORTES DÉJÀ OUVERTES" end
	if partage.occupe then return false, "TARDIS OCCUPÉ" end
	if etatActuel() ~= E.Pose then return false, "PAS POSÉ" end
	if exterieur:GetAttribute("PortesVerrouillees") then return false, "PORTES VERROUILLÉES" end
	if exterieur:GetAttribute("Verrouille") or tropPetitPourLesPortes() then return false, "PORTES BLOQUÉES (TAILLE)" end

	-- On repasse par "faux" pour être sûr que le changement soit bien vu par les scripts Shut
	exterieur:SetAttribute("OuvrirPorte", false)
	task.wait()
	exterieur:SetAttribute("OuvrirPorte", true)
	local limite = os.clock() + 3
	while not exterieur:GetAttribute("PorteOuverte") and os.clock() < limite do
		task.wait(0.1)
	end
	exterieur:SetAttribute("OuvrirPorte", false)
	if not exterieur:GetAttribute("PorteOuverte") then return false, "PORTES BLOQUÉES" end
	return true
end

-- Immobilise un joueur (pendant qu'on se matérialise sur lui)
local function figerJoueur(joueurCible, fige)
	local personnage = joueurCible.Character
	local racine = personnage and personnage:FindFirstChild("HumanoidRootPart")
	if racine then
		racine.Anchored = fige
	end
end

-- Verrouillage des portes depuis le menu (appliqué à Locked par TardisLiaisonPortes)
local function basculerVerrou()
	local verrouiller = not exterieur:GetAttribute("PortesVerrouillees")
	if verrouiller and exterieur:GetAttribute("PorteOuverte") then
		if partage.occupe then return false, "TARDIS OCCUPÉ" end
		partage.occupe = true
		local fermees = fermerPortes()
		partage.occupe = false
		majEcran()
		if not fermees then return false, "PORTES BLOQUÉES" end
	end
	exterieur:SetAttribute("PortesVerrouillees", verrouiller)
	return true
end

-- Mode des voyages lancés par le levier de la console (Config.LevierEnExpress, V6.6.4)
local function modeLevier()
	return Config.LevierEnExpress == true and "Express" or nil
end

-- Voyage complet (levier de la console quand le TARDIS est posé)
local function voyager(dest)
	local ok, erreur = decoller(modeLevier())
	if not ok then
		alerter(erreur)
		return
	end
	task.wait(Config.DureeVol)
	if exterieur:GetAttribute("Retreci") then
		local cible, nom = cibleSurPlace()
		ok, erreur = atterrir(cible, nom, false, partage.positionActuelle, modeLevier())
	else
		ok, erreur = atterrir(dest.CFrame, dest.Name, false, dest, modeLevier())
	end
	if not ok and erreur ~= "PAS EN VOL" then -- "PAS EN VOL" : quelqu'un a déjà fait atterrir le TARDIS via le menu
		alerter(erreur)
	end
end

local function basculerCamouflage()
	if partage.occupe then return false, "TARDIS OCCUPÉ" end
	if etatActuel() ~= E.Pose then return false, "PAS POSÉ" end
	if exterieur:GetAttribute("Alimentation") == false then return false, "HORS TENSION" end

	local actif = not exterieur:GetAttribute("Camouflage")
	setCamouflage(actif, false)
	jouer(actif and "Camouflage" or "Decamouflage", true)
	return true
end

--------------------------------------------------------------------
-- Alimentation, alerte et démarrage
--------------------------------------------------------------------
local function estAlimente()
	return exterieur:GetAttribute("Alimentation") ~= false
end

-- Tout ce qui éclaire l'intérieur, avec ses réglages d'origine
local eclairages = {}
local function memoriserEclairage(objet)
	if eclairages[objet] then return end
	if objet:IsA("Light") then
		eclairages[objet] = { Enabled = objet.Enabled, Color = objet.Color }
	elseif objet:IsA("BasePart") and objet.Material == Enum.Material.Neon then
		eclairages[objet] = { Material = objet.Material, Color = objet.Color }
	elseif objet:IsA("LayerCollector") or objet:IsA("ParticleEmitter") or objet:IsA("Beam") then
		eclairages[objet] = { Enabled = objet.Enabled }
	end
end
for _, objet in interieur:GetDescendants() do
	memoriserEclairage(objet)
end

local dossierLeds = interieur:FindFirstChild(Config.NomLedsAlerte or "LedsAlerte")
local function estLedAlerte(objet)
	return dossierLeds == nil or objet:IsDescendantOf(dossierLeds)
end

local sonAlerte = preparerSon("Cloitre", partRotor, true)
if sonAlerte then sonAlerte.Looped = true end

local function appliquerEclairage()
	local alimente = estAlimente()
	local alerte = alimente and exterieur:GetAttribute("Alerte") == true
	local rouge = Config.CouleurAlerte or Color3.fromRGB(255, 30, 30)

	for objet, origine in eclairages do
		if objet.Parent then
			if objet:IsA("Light") then
				objet.Enabled = alimente and origine.Enabled
				objet.Color = (alerte and estLedAlerte(objet)) and rouge or origine.Color
			elseif objet:IsA("BasePart") then
				objet.Material = alimente and origine.Material or Enum.Material.SmoothPlastic
				objet.Color = (alerte and estLedAlerte(objet)) and rouge or origine.Color
			else
				objet.Enabled = alimente and origine.Enabled
			end
		end
	end

	if sonAlerte then
		if alerte and not sonAlerte.IsPlaying then sonAlerte:Play() end
		if not alerte and sonAlerte.IsPlaying then sonAlerte:Stop() end
	end
end

local function reglerAlimentation(allumer)
	exterieur:SetAttribute("Alimentation", allumer)
	if not allumer then exterieur:SetAttribute("Alerte", false) end
	appliquerEclairage()
	majEcran()
end
local function basculerAlimentation()
	if partage.occupe then return false, "TARDIS OCCUPÉ" end
	if etatActuel() ~= E.Pose then return false, "PAS POSÉ" end
	if exterieur:GetAttribute("Avarie") then return false, "AVARIE : RÉPARER LE ROTOR" end
	if exterieur:GetAttribute("RedemarrageRequis") then return false, "REDÉMARRAGE REQUIS (10 S SUR L'ALIMENTATION)" end
	local allumer = not estAlimente()
	exterieur:SetAttribute("Alimentation", allumer)
	if not allumer then
		exterieur:SetAttribute("Alerte", false) -- sans courant, plus d'alerte
	end
	appliquerEclairage()
	majEcran()
	return true
end

local function basculerAlerte()
	if not estAlimente() then return false, "HORS TENSION" end
	exterieur:SetAttribute("Alerte", not exterieur:GetAttribute("Alerte"))
	appliquerEclairage()
	majEcran()
	return true
end

local function basculerDemarrage()
	exterieur:SetAttribute("DemarrageBloque", not exterieur:GetAttribute("DemarrageBloque"))
	majEcran()
	return true
end

--------------------------------------------------------------------
-- Ouverture automatique quand un joueur s'approche de la porte pour sortir
--------------------------------------------------------------------
local PROFONDEUR_SORTIE = 4  -- distance devant la porte intérieure qui déclenche l'ouverture (studs)
local derniereOuverture = 0

local function demanderOuverture()
	if exterieur:GetAttribute("PorteOuverte") then return end
	if partage.occupe or etatActuel() ~= E.Pose or exterieur:GetAttribute("Verrouille") then return end
	if exterieur:GetAttribute("PortesVerrouillees") or tropPetitPourLesPortes() then return end
	local maintenant = os.clock()
	if maintenant - derniereOuverture < 3 then return end
	derniereOuverture = maintenant

	-- Écouté par les scripts Shut des deux battants (qui refusent si la porte est verrouillée avec Locked)
	exterieur:SetAttribute("OuvrirPorte", true)
	task.delay(1, function()
		exterieur:SetAttribute("OuvrirPorte", false)
	end)
end

-- Vérifié par le serveur à partir de la position des personnages : rien à envoyer depuis le client
task.spawn(function()
	while true do
		task.wait(0.2)
		if etatActuel() == E.Pose and not exterieur:GetAttribute("PorteOuverte") then
			local demiLargeur = portailInt.Size.X / 2 + 0.5
			local demiHauteur = portailInt.Size.Y / 2 + 1
			for _, joueur in Players:GetPlayers() do
				local personnage = joueur.Character
				local racine = personnage and personnage:FindFirstChild("HumanoidRootPart")
				if racine and pilotes[joueur] then -- seuls les joueurs autorisés ouvrent les portes
					-- Côté salle, le joueur est derrière le Portail intérieur (Z positif)
					local p = portailInt.CFrame:PointToObjectSpace(racine.Position)
					if p.Z > 0 and p.Z < PROFONDEUR_SORTIE
						and math.abs(p.X) <= demiLargeur and math.abs(p.Y) <= demiHauteur then
						demanderOuverture()
						break
					end
				end
			end
		end
	end
end)

--------------------------------------------------------------------
-- Commandes de la console (ProximityPrompt : validées par le serveur)
--------------------------------------------------------------------
local function creerPrompt(part, action)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = "Console"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	return prompt
end

local dernierUsage = 0
local function disponible()
	local maintenant = os.clock()
	if maintenant - dernierUsage < Config.Cooldown then return false end
	dernierUsage = maintenant
	return true
end

local promptSelecteur = creerPrompt(selecteur, "Changer de destination")
local promptLevier = creerPrompt(levier, "Décoller")

promptSelecteur.Triggered:Connect(function(joueur)
	if not pilotes[joueur] then return end -- réservé aux joueurs autorisés (Config.Pilotes)
	marquerActivite()
	if not disponible() then return end
	if not estAlimente() then return end -- écran éteint, rien ne répond
	local _, total = destinationChoisie()
	if total == 0 then alerter("AUCUNE DESTINATION") return end
	indexDestination = indexDestination % total + 1
	majEcran()
end)

promptLevier.Triggered:Connect(function(joueur)
	if not pilotes[joueur] then return end
	if Config.bloqueParMaintenance(exterieur, "Demat") then alerter("EN MAINTENANCE") return end
	marquerActivite()
	if not disponible() then return end
	local dest = destinationChoisie()
	if not dest then alerter("AUCUNE DESTINATION") return end

	local etat = etatActuel()
	local retreci = exterieur:GetAttribute("Retreci") == true
	if etat == E.Pose then
		if dest == partage.positionActuelle and not retreci then alerter("DÉJÀ SUR PLACE") return end
		task.spawn(voyager, dest)
	elseif etat == E.Vol then
		task.spawn(function()
			local ok, erreur
			if retreci then
				local cible, nom = cibleSurPlace()
				ok, erreur = atterrir(cible, nom, false, partage.positionActuelle, modeLevier())
			else
				ok, erreur = atterrir(dest.CFrame, dest.Name, false, dest, modeLevier())
			end
			if not ok then alerter(erreur) end
		end)
	else
		alerter("PATIENTEZ")
	end
end)

-- Le texte du levier suit l'état : "Décoller" posé, "Atterrir" en vol
exterieur:GetAttributeChangedSignal("Etat"):Connect(function()
	promptLevier.ActionText = etatActuel() == E.Vol and "Atterrir" or "Décoller"
end)

-- Commande à bascule générique : prompt sur la Part au bout du chemin, texte selon l'état
local function brancherCommande(cle, texteActif, texteInactif, attribut, valeurActive, action, messageActif, messageInactif)
	if not Config.Chemins[cle] then return end
	task.spawn(function()
		local part = enPart(Config.Trouver(interieur, cle))
		if not part then
			warn("[TARDIS] Commande '" .. cle .. "' introuvable (aucune Part)")
			return
		end
		local prompt = creerPrompt(part, texteInactif)
		local function majTexte()
			prompt.ActionText = (exterieur:GetAttribute(attribut) == valeurActive) and texteActif or texteInactif
		end
		exterieur:GetAttributeChangedSignal(attribut):Connect(majTexte)
		majTexte()
		prompt.Triggered:Connect(function(joueur)
			if not pilotes[joueur] then return end
			marquerActivite()
			if not disponible() then return end
			local ok, erreur = action()
			if ok then
				alerter((exterieur:GetAttribute(attribut) == valeurActive) and messageActif or messageInactif)
			else
				alerter(erreur)
			end
		end)
	end)
end

-- Alimentation : Controls > LockLever > Main > Lever > Main
brancherCommande("Alimentation", "Rétablir l'alimentation", "Couper l'alimentation", "Alimentation", false,
	basculerAlimentation, "HORS TENSION", "ALIMENTATION RÉTABLIE")
-- Alerte : Console > Datapanel > Redbutton > Button (V6.9.10.1 ; avant : Console > Circuit > Cloister > Switch)
brancherCommande("Alerte", "Lever l'alerte", "Déclencher l'alerte", "Alerte", true,
	basculerAlerte, "ALERTE GÉNÉRALE", "FIN DE L'ALERTE")
-- Démarrage : Controls > Power > On
brancherCommande("Demarrage", "Débloquer le démarrage", "Bloquer le démarrage", "DemarrageBloque", true,
	basculerDemarrage, "DÉMARRAGE BLOQUÉ", "DÉMARRAGE DÉBLOQUÉ")

-- Levier de verrouillage des portes (Console > LeverLeft > Main > Lever > Main)
if Config.Chemins.Verrou then
	task.spawn(function()
		local partVerrou = enPart(Config.Trouver(interieur, "Verrou"))
		if not partVerrou then
			warn("[TARDIS] Commande de verrouillage introuvable (aucune Part)")
			return
		end
		local promptVerrou = creerPrompt(partVerrou, "Verrouiller les portes")

		local function majTexteVerrou()
			promptVerrou.ActionText = exterieur:GetAttribute("PortesVerrouillees")
				and "Déverrouiller les portes" or "Verrouiller les portes"
		end
		exterieur:GetAttributeChangedSignal("PortesVerrouillees"):Connect(majTexteVerrou)
		majTexteVerrou()

		promptVerrou.Triggered:Connect(function(joueur)
			if not pilotes[joueur] then return end
			marquerActivite()
			if not disponible() then return end
			task.spawn(function()
				local ok, erreur = basculerVerrou()
				if ok then
					alerter(exterieur:GetAttribute("PortesVerrouillees") and "PORTES VERROUILLÉES" or "PORTES DÉVERROUILLÉES")
				else
					alerter(erreur)
				end
			end)
		end)
	end)
end

--------------------------------------------------------------------
-- Rapetissement et ramassage
--------------------------------------------------------------------
local reglages = Config.Ramassage or {}
local echelleNormale, hauteurNormale = 1, nil
local okMesure, erreurMesure = pcall(function()
	echelleNormale = exterieur:GetScale()
	hauteurNormale = exterieur:GetExtentsSize().Y
end)
if not okMesure then
	warn("[TARDIS] Rapetissement désactivé : " .. tostring(erreurMesure))
end

-- Le "Ramasser" est accroché au milieu du TARDIS (pas au ras du sol), via un Attachment
-- qui suit automatiquement la mise à l'échelle
local pointRamasser = Instance.new("Attachment")
pointRamasser.Name = "PointRamasser"
pointRamasser.Position = Vector3.new(0, (hauteurNormale or 8) / 2, 0)
pointRamasser.Parent = exterieur.PrimaryPart

local DISTANCE_RAMASSER = 8
--------------------------------------------------------------------
-- Portes réservées aux joueurs autorisés
-- Le script d'ouverture au clic ne sait pas qui clique : ses ClickDetectors sont désactivés,
-- et les portes s'ouvrent avec "Ouvrir les portes" (E), devant la porte dehors comme dedans.
-- Les scripts Shut animent toujours les battants.
--------------------------------------------------------------------
do
	local dossierPortes = exterieur:WaitForChild(Config.NomDossierPortes or "TARDISDoors", 10)
	local portailExterieur = exterieur:WaitForChild(Config.NomPortailExt, 10)

	local function couperClic(objet)
		if objet:IsA("ClickDetector") then
			objet.MaxActivationDistance = 0
		elseif objet:IsA("ProximityPrompt") then
			objet.Enabled = false
		end
	end
	if dossierPortes then
		for _, objet in dossierPortes:GetDescendants() do couperClic(objet) end
		dossierPortes.DescendantAdded:Connect(couperClic)
	else
		warn("[TARDIS] TARDISDoors introuvable : les clics sur les portes n'ont pas pu être désactivés.")
	end

	local function promptPortes(portail, nom)
		local point = Instance.new("Attachment")
		point.Name = "TardisPromptPortes"
		point.Parent = portail
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = nom
		prompt.ObjectText = "TARDIS"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = false
		prompt.Parent = point
		local function majTexte()
			prompt.ActionText = exterieur:GetAttribute("PorteOuverte") and "Fermer les portes" or "Ouvrir les portes"
			-- Pas de porte à ouvrir en vol libre (le pilote les gère depuis le vol) ni pendant un voyage
			prompt.Enabled = etatActuel() == E.Pose and not exterieur:GetAttribute("VolLibre")
		end
		for _, attribut in { "PorteOuverte", "Etat", "VolLibre" } do
			exterieur:GetAttributeChangedSignal(attribut):Connect(majTexte)
		end
		majTexte()
		prompt.Triggered:Connect(function(joueur)
			if not pilotes[joueur] then return end
			task.spawn(function()
				local ok, erreur
				if exterieur:GetAttribute("PorteOuverte") then
					ok, erreur = fermerPortesSimple()
				else
					ok, erreur = ouvrirPortesSimple()
				end
				if not ok and erreur then remote:FireClient(joueur, "Impossible : " .. string.lower(erreur), false) end
			end)
		end)
	end
	if portailExterieur then promptPortes(portailExterieur, "PortesExterieur") end
	promptPortes(portailInt, "PortesInterieur")
end

local promptRamasser = Instance.new("ProximityPrompt")
promptRamasser.ActionText = "Ramasser"
promptRamasser.ObjectText = "TARDIS"
promptRamasser.HoldDuration = 0                                  -- un simple appui sur E suffit
promptRamasser.MaxActivationDistance = DISTANCE_RAMASSER
promptRamasser.RequiresLineOfSight = false
promptRamasser.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow -- jamais masqué par un autre prompt
promptRamasser.Enabled = false
promptRamasser.Parent = pointRamasser

local HAUTEUR_MAX_RAMASSAGE = reglages.HauteurMax or 3 -- au-delà, il est trop grand pour être porté

local function majRamassage()
	promptRamasser.MaxActivationDistance = DISTANCE_RAMASSER -- au cas où la mise à l'échelle l'aurait modifiée
	local facteur = exterieur:GetAttribute("Echelle") or 1
	local assezPetit = hauteurNormale ~= nil and hauteurNormale * facteur <= HAUTEUR_MAX_RAMASSAGE + 0.01
	promptRamasser.Enabled = exterieur:GetAttribute("Retreci") == true
		and assezPetit
		and exterieur:GetAttribute("Porteur") == nil
		and etatActuel() == E.Pose
		and not partage.occupe
end
exterieur:GetAttributeChangedSignal("Etat"):Connect(majRamassage)

-- Animation de taille (le modèle est mis à l'échelle autour de sa Racine, donc il reste au sol)
local function animerEchelle(arrivee)
	local depart = exterieur:GetScale()
	local duree = reglages.DureeAnimation or 1.5
	local debut = os.clock()
	while true do
		local p = math.min((os.clock() - debut) / duree, 1)
		local lisse = 1 - (1 - p) ^ 3
		exterieur:ScaleTo(depart + (arrivee - depart) * lisse)
		if p >= 1 then break end
		task.wait()
	end
end

-- Règle la taille du TARDIS : facteur entre Config.TailleMin (ex. 0.25) et 1 (taille normale)
local function reglerTaille(facteur)
	if not hauteurNormale then return false, "RAPETISSEMENT INDISPONIBLE" end
	if partage.occupe then return false, "TARDIS OCCUPÉ" end
	if etatActuel() ~= E.Pose then return false, "PAS POSÉ" end
	if exterieur:GetAttribute("Porteur") then return false, "TARDIS PORTÉ" end
	if exterieur:GetAttribute("Alimentation") == false then return false, "HORS TENSION" end

	local minimum = Config.TailleMin or 0.25
	facteur = math.clamp(facteur, minimum, 1)
	if facteur > 0.99 then facteur = 1 end
	local actuel = exterieur:GetAttribute("Echelle") or 1
	if math.abs(facteur - actuel) < 0.01 then return true end

	partage.occupe = true
	majRamassage()

	-- Il passe sous le seuil des portes : on les ferme et on les bloque AVANT de rétrécir
	if tropPetitPourLesPortes(facteur) and not tropPetitPourLesPortes(actuel) then
		exterieur:SetAttribute("Verrouille", true)
		if not fermerPortes() then
			exterieur:SetAttribute("Verrouille", false)
			partage.occupe = false
			majRamassage()
			return false, "PORTES BLOQUÉES"
		end
	end
	exterieur:SetAttribute("Retreci", facteur < 1)

	local ok, erreur = pcall(animerEchelle, echelleNormale * facteur)
	if not ok then warn("[TARDIS] Changement de taille : " .. tostring(erreur)) end
	exterieur:SetAttribute("Echelle", facteur)

	-- Assez grand : les portes peuvent de nouveau s'ouvrir
	exterieur:SetAttribute("Verrouille", tropPetitPourLesPortes(facteur))

	partage.occupe = false
	majRamassage()
	majEcran()
	return true
end

local function ramasser(joueur)
	if not exterieur:GetAttribute("Retreci") or exterieur:GetAttribute("Porteur") or partage.occupe then return end
	setCollisionsExterieur(false) -- sinon il pousserait son porteur
	exterieur:SetAttribute("SurEau", false)
	exterieur:SetAttribute("ModePort", "Main")
	exterieur:SetAttribute("Porteur", joueur.UserId)
	exterieur:SetAttribute("Position", "Porté par " .. joueur.DisplayName)
	partage.positionActuelle = nil
	majRamassage()
end

-- Repose le TARDIS au sol devant le porteur, porte tournée vers lui
local function poserTardis(joueur, personnage)
	if exterieur:GetAttribute("Porteur") ~= joueur.UserId then return end
	personnage = personnage or joueur.Character
	local racine = personnage and personnage:FindFirstChild("HumanoidRootPart")

	local cible = exterieur:GetPivot()
	if racine then
		local devant = racine.CFrame.LookVector * Vector3.new(1, 0, 1)
		devant = devant.Magnitude > 0.01 and devant.Unit or Vector3.new(0, 0, -1)
		local sol = chercherSol(racine.Position + devant * 3)
		if sol then
			local regard = Vector3.new(racine.Position.X, sol.Y, racine.Position.Z)
			cible = CFrame.lookAt(sol, regard)
		end
	end

	-- DepotCF : les clients s'y recalent en arrêtant de suivre le porteur (évite tout décalage)
	exterieur:SetAttribute("DepotCF", cible)
	exterieur:PivotTo(cible)
	exterieur:SetAttribute("Porteur", nil)
	setCollisionsExterieur(true)
	exterieur:SetAttribute("Position", "Posé par " .. joueur.DisplayName)
	majRamassage()
	verifierEau()
	partage.sauvegardeModifiee = true
end

--------------------------------------------------------------------
-- Vol libre (piloté depuis la tablette) : module VolLibre
--------------------------------------------------------------------
local VolLibre = require(script:WaitForChild("VolLibre"))({ Config = Config, jouerVoyage = jouerVoyage, modeAutorise = modeAutorise, E = E, Players = Players, chercherSol = chercherSol, dansInterieur = dansInterieur, echelleNormale = echelleNormale, emmenerALInterieur = emmenerALInterieur, etatActuel = etatActuel, exterieur = exterieur, fermerPortes = fermerPortes, hauteurNormale = hauteurNormale, interieur = interieur, jouer = jouer, majEcran = majEcran, majRamassage = majRamassage, memoriserDepart = memoriserDepart, partage = partage, setCollisionsExterieur = setCollisionsExterieur, tropPetitPourLesPortes = tropPetitPourLesPortes, verifierEau = verifierEau })
local basculerPortesEnVol, changerPhaseVol, demarrerVolLibre, lancerDescente, lancerGlisse, recevoirPositionVol = VolLibre.basculerPortesEnVol, VolLibre.changerPhaseVol, VolLibre.demarrerVolLibre, VolLibre.lancerDescente, VolLibre.lancerGlisse, VolLibre.recevoirPositionVol
local reglagesVol, teleAtterrir, volLibre = VolLibre.reglagesVol, VolLibre.teleAtterrir, VolLibre.volLibre
local freinerVol = VolLibre.freinerVol -- V6.9.10 : freinage d'urgence ressenti à bord

--------------------------------------------------------------------
-- Boucliers
--   "Joueurs" (bleu ciel) : bulle visuelle + enceinte invisible (murs et toit) que les joueurs ne traversent pas
--   "Balles"  (cyan)      : bulle solide pour les tirs (les balles ACS s'y arrêtent), que les joueurs traversent
-- Ils demandent du courant et ne marchent que TARDIS posé ; ils se coupent tout seuls sinon.
--------------------------------------------------------------------
local basculerBouclier
do
	local PhysicsService = game:GetService("PhysicsService")
	local GROUPE_BALLES = "TardisBouclierBalles"
	local GROUPE_PERSONNAGES = "TardisPersonnages"
	pcall(function() PhysicsService:RegisterCollisionGroup(GROUPE_BALLES) end)
	pcall(function() PhysicsService:RegisterCollisionGroup(GROUPE_PERSONNAGES) end)
	-- Le bouclier anti-balles reste solide pour tout (donc pour les tirs), sauf pour les personnages
	pcall(function() PhysicsService:CollisionGroupSetCollidable(GROUPE_BALLES, GROUPE_PERSONNAGES, false) end)

	local groupesExclus = { [GROUPE_PERSONNAGES] = true }
	local function preparerPiece(objet)
		if not objet:IsA("BasePart") then return end
		local groupe = objet.CollisionGroup
		if groupe == "Default" then
			objet.CollisionGroup = GROUPE_PERSONNAGES
		elseif not groupesExclus[groupe] then
			-- Le personnage utilise déjà un autre groupe (ACS ou autre) : on le rend traversable lui aussi
			groupesExclus[groupe] = true
			pcall(function() PhysicsService:CollisionGroupSetCollidable(GROUPE_BALLES, groupe, false) end)
		end
	end
	local function preparerPersonnage(personnage)
		for _, objet in personnage:GetDescendants() do preparerPiece(objet) end
		personnage.DescendantAdded:Connect(preparerPiece)
	end
	local function suivreJoueur(autre)
		if autre.Character then preparerPersonnage(autre.Character) end
		autre.CharacterAdded:Connect(preparerPersonnage)
	end
	Players.PlayerAdded:Connect(suivreJoueur)
	for _, autre in Players:GetPlayers() do suivreJoueur(autre) end

	local dossier = exterieur:FindFirstChild("Boucliers") or Instance.new("Folder")
	dossier.Name = "Boucliers"
	dossier.Parent = exterieur
	local boucliers = {} -- [type] = Model

	local COULEURS = { Joueurs = Color3.fromRGB(135, 206, 250), Balles = Color3.fromRGB(0, 230, 255), Complet = Color3.fromRGB(135, 206, 250) }

	local function piece(proprietes)
		local p = Instance.new("Part")
		p.Anchored, p.CastShadow, p.CanTouch = true, false, false
		for cle, valeur in proprietes do p[cle] = valeur end
		return p
	end

	-- Taille du TARDIS sans les boucliers déjà actifs (sinon la bulle grossirait à chaque bouclier)
	local function tailleSansBoucliers()
		local pivot = exterieur:GetPivot()
		local mini = Vector3.new(math.huge, math.huge, math.huge)
		local maxi = -mini
		for _, objet in exterieur:GetDescendants() do
			if objet:IsA("BasePart") and not objet:IsDescendantOf(dossier) then
				local repere, demi = pivot:ToObjectSpace(objet.CFrame), objet.Size / 2
				for _, sx in { -1, 1 } do
					for _, sy in { -1, 1 } do
						for _, sz in { -1, 1 } do
							local coin = repere * Vector3.new(sx * demi.X, sy * demi.Y, sz * demi.Z)
							mini, maxi = mini:Min(coin), maxi:Max(coin)
						end
					end
				end
			end
		end
		return maxi - mini
	end

	local function creer(type)
		local taille = tailleSansBoucliers()
		local pivot = exterieur:GetPivot()
		local hauteurRacine = exterieur.PrimaryPart.Size.Y / 2
		local centre = pivot * CFrame.new(0, taille.Y / 2 - hauteurRacine, 0)
		local rayon = math.max(taille.X, taille.Y, taille.Z) * 0.5 * 1.35 + 2
		if type == "Balles" then rayon += 1.5 end -- un peu plus grand : les deux bulles ne se confondent pas

		local modele = Instance.new("Model")
		modele.Name = "Bouclier" .. type
		-- Invisible par défaut : il n'apparaît (en partie) que quand un joueur le touche ou lui tire dessus
		local bulle = piece({ Name = "Bulle", Shape = Enum.PartType.Ball, Size = Vector3.new(rayon * 2, rayon * 2, rayon * 2),
			CFrame = centre, Material = Enum.Material.ForceField, Color = COULEURS[type], Transparency = 1 })
		bulle:SetAttribute("TailleCible", bulle.Size) -- utilisé par les clients pour l'animation d'apparition

		if type == "Balles" then
			-- Solide (les tirs s'y arrêtent), mais traversable par les personnages grâce au groupe de collision
			bulle.CanCollide, bulle.CanQuery = true, true
			bulle.CollisionGroup = GROUPE_BALLES
		elseif type == "Complet" then
			-- Bouclier complet : solide pour tout le monde, joueurs et tirs
			bulle.CanCollide, bulle.CanQuery = true, true
		else
			bulle.CanCollide, bulle.CanQuery = false, false
			-- Enceinte invisible : 16 murs en cercle + un toit, un peu à l'intérieur de la bulle
			local r = rayon * 0.9
			local bas, haut = -(taille.Y / 2) - 2, rayon * 0.45
			local largeur = 2 * math.pi * r / 16 * 1.08
			for i = 1, 16 do
				local mur = piece({ Name = "Mur", Size = Vector3.new(largeur, haut - bas, 0.6), Transparency = 1,
					CanCollide = true, CanQuery = false,
					CFrame = centre * CFrame.Angles(0, i / 16 * math.pi * 2, 0) * CFrame.new(0, (haut + bas) / 2, -r) })
				mur.Parent = modele
			end
			local toit = piece({ Name = "Toit", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, r * 2, r * 2),
				Transparency = 1, CanCollide = true, CanQuery = false,
				CFrame = centre * CFrame.new(0, haut, 0) * CFrame.Angles(0, 0, math.pi / 2) })
			toit.Parent = modele
		end
		bulle.Parent = modele
		modele.Parent = dossier
		boucliers[type] = modele
	end

	local function retirer(type)
		local modele = boucliers[type]
		boucliers[type] = nil
		if not modele then return end
		-- Les murs disparaissent tout de suite ; la bulle laisse aux clients le temps de se rétracter
		for _, objet in modele:GetChildren() do
			if objet.Name ~= "Bulle" then objet:Destroy() end
		end
		modele:SetAttribute("Disparition", true)
		task.delay(0.4, function() modele:Destroy() end)
	end

	local function majBouclier(type)
		local actif = exterieur:GetAttribute("Bouclier" .. type) == true
		if actif and not boucliers[type] then
			creer(type)
		elseif not actif and boucliers[type] then
			retirer(type)
		end
	end

	basculerBouclier = function(type)
		if type ~= "Joueurs" and type ~= "Balles" and type ~= "Complet" then return false, "BOUCLIER INCONNU" end
		local attribut = "Bouclier" .. type
		if not exterieur:GetAttribute(attribut) then
			if etatActuel() ~= E.Pose or exterieur:GetAttribute("VolLibre") then return false, "PAS POSÉ" end
			if exterieur:GetAttribute("Porteur") then return false, "TARDIS PORTÉ" end
			if not estAlimente() then return false, "HORS TENSION" end
		end
		local actif = not exterieur:GetAttribute(attribut)
		if actif then exterieur:SetAttribute("BouclierEnergie", 100) end -- un bouclier relancé repart à pleine énergie
		exterieur:SetAttribute(attribut, actif)
		return true
	end

	exterieur:SetAttribute("BouclierJoueurs", false)
	exterieur:SetAttribute("BouclierBalles", false)
	exterieur:SetAttribute("BouclierComplet", false)
	exterieur:SetAttribute("BouclierEnergie", 100)
	exterieur:GetAttributeChangedSignal("BouclierJoueurs"):Connect(function() majBouclier("Joueurs") end)
	exterieur:GetAttributeChangedSignal("BouclierBalles"):Connect(function() majBouclier("Balles") end)
	exterieur:GetAttributeChangedSignal("BouclierComplet"):Connect(function() majBouclier("Complet") end)

	-- Coupure automatique : décollage, vol libre, ramassage, changement de taille, coupure de courant
	local function toutCouper()
		exterieur:SetAttribute("BouclierJoueurs", false)
		exterieur:SetAttribute("BouclierBalles", false)
		exterieur:SetAttribute("BouclierComplet", false)
	end
	exterieur:GetAttributeChangedSignal("Etat"):Connect(function()
		if etatActuel() ~= E.Pose then toutCouper() end
	end)
	for _, nom in { "VolLibre", "Porteur" } do
		exterieur:GetAttributeChangedSignal(nom):Connect(function()
			if exterieur:GetAttribute(nom) then toutCouper() end
		end)
	end
	exterieur:GetAttributeChangedSignal("Echelle"):Connect(toutCouper)
	exterieur:GetAttributeChangedSignal("Alimentation"):Connect(function()
		if not estAlimente() then toutCouper() end
	end)
end

--------------------------------------------------------------------
-- Menu à distance : permissions et commandes
--------------------------------------------------------------------
local dernierOrdre = {}
-- Destination demandée par un menu (lieu, joueur, dernière destination ou coordonnées)
-- Renvoie : cible, nom, partDestination, joueurAFiger, erreur
-- autoriserInterieur (V6.7.1) : la commande Remat des menus accepte une destination dans le TARDIS (paradoxe) ;
-- partout ailleurs, elle est refusée
-- Noms des joueurs partis pendant la session (V6.9.7), pour dire clairement qui a quitté
local nomsPartis = {}
Players.PlayerRemoving:Connect(function(joueur) nomsPartis[joueur.UserId] = joueur.DisplayName end)

-- repliSiParti (V6.9.7) : si le joueur visé a quitté le jeu ou n'a plus de personnage, retour au lieu de départ
-- (6e valeur renvoyée : le message à afficher) au lieu de laisser le TARDIS dans le vortex
local function resoudreDestination(donnees, autoriserInterieur, repliSiParti)
	local cible, nom, partDestination
	local joueurAFiger = nil
	if typeof(donnees.destination) == "string" and #donnees.destination <= 100 then
		-- Atterrissage sur une destination
		local dest = dossierDestinations:FindFirstChild(donnees.destination, true) -- sous-dossiers compris
		if not (dest and dest:IsA("BasePart")) then
			return nil, nil, nil, nil, "destination introuvable"
		end
		if not autoriserInterieur and dansInterieur(dest.Position) then
			return nil, nil, nil, nil, "destination dans le TARDIS"
		end
		cible, nom, partDestination = dest.CFrame, dest.Name, dest

	elseif typeof(donnees.joueur) == "number" then
		-- Atterrissage près d'un joueur
		local joueurCible = Players:GetPlayerByUserId(donnees.joueur)
		local erreur
		if joueurCible then cible, erreur = cibleJoueur(joueurCible, autoriserInterieur) end
		if not cible then
			local absent = not joueurCible or erreur == "JOUEUR SANS PERSONNAGE"
			local qui = (joueurCible and joueurCible.DisplayName) or nomsPartis[donnees.joueur] or "Le joueur visé"
			if absent and repliSiParti and precedent then
				return precedent.cf, precedent.nom, nil, nil, nil,
					qui .. (joueurCible and " n'a plus de personnage" or " a quitté le jeu") .. " : retour à " .. tostring(precedent.nom) .. "."
			end
			if not joueurCible then
				return nil, nil, nil, nil, nomsPartis[donnees.joueur] and (qui .. " a quitté le jeu") or "joueur introuvable"
			end
			return nil, nil, nil, nil, erreur
		end
		if donnees.figer == true then
			-- "Sur lui" : le joueur est immobilisé jusqu'à la fin de la matérialisation
			joueurAFiger = joueurCible
			nom = "Sur " .. joueurCible.DisplayName
		else
			nom = "Dernière position de " .. joueurCible.DisplayName
		end

	elseif donnees.precedent == true then
		-- Retour là d'où le TARDIS est parti
		if not precedent then
			return nil, nil, nil, nil, "aucune destination précédente"
		end
		cible, nom = precedent.cf, precedent.nom

	elseif typeof(donnees.position) == "CFrame" then
		-- Nouvelle localisation choisie dans le monde (avec rotations)
		local position = donnees.position.Position
		local valide = position.X == position.X and position.Y == position.Y and position.Z == position.Z -- pas de NaN
			and math.abs(position.X) < 100000 and math.abs(position.Y) < 100000 and math.abs(position.Z) < 100000
		if not valide or dansInterieur(position) then
			return nil, nil, nil, nil, "localisation invalide"
		end
		cible = donnees.position:Orthonormalize()
		nom = string.format("Coordonnées (%d, %d, %d)", position.X, position.Y, position.Z)
	else
		return nil, nil, nil, nil, "aucune destination choisie"
	end
	return cible, nom, partDestination, joueurAFiger, nil
end

-- Joue un son sur le personnage d'un joueur (le TARDIS porté suit son porteur, pas sa position serveur)
local function jouerSurPersonnage(joueurCible, nom)
	-- Mode sans son (Silencieux, V6.9.7) : Config.Son renvoie nil ; avant, le script plantait ici et laissait le TARDIS occupé
	if type(nom) ~= "string" then return end
	local groupe = sons[nom] or sons[(string.gsub(string.gsub(nom, "_Urg", ""), "_Express", ""))]
	local modele = groupe and (groupe.ext or groupe.int)
	local racine = joueurCible.Character and joueurCible.Character:FindFirstChild("HumanoidRootPart")
	if not (modele and racine) then return end
	local son = modele:Clone()
	appliquerPortee(son, "Dehors")
	son.Parent = racine
	son:Play()
	son.Ended:Connect(function() son:Destroy() end)
end

-- Téléportation de poche : le TARDIS porté se dématérialise dans les mains (ou sur l'épaule) de son porteur,
-- puis se rematérialise tout seul, toujours petit, à la destination choisie
local function teleporterEnPoche(porteur, cible, nom, partDestination, joueurAFiger, modeDemande)
	if exterieur:GetAttribute("Porteur") ~= porteur.UserId then return false, "TARDIS PAS PORTÉ" end
	if partage.occupe then return false, "TARDIS OCCUPÉ" end
	if not estAlimente() then return false, "HORS TENSION" end
	if exterieur:GetAttribute("DemarrageBloque") then return false, "DÉMARRAGE BLOQUÉ" end
	-- Mode : celui des protocoles (Urgence ou Express, V6.6.4), ou l'urgence imposée par l'alerte
	local mode = Config.normaliserMode(modeDemande)
	if exterieur:GetAttribute("Alerte") == true then mode = "Urgence" end
	mode = modeAutorise(mode, exterieur:GetPivot().Position)

	partage.occupe = true
	majRamassage()

	-- 1) Dématérialisation dans les mains du porteur (les clients continuent de le faire suivre)
	exterieur:SetAttribute("Mode", mode)
	setEtat(E.Demat)
	local son = Config.Son(E.Demat, mode)
	jouerVoyage(E.Demat, mode, false) -- dans la salle de contrôle
	jouerSurPersonnage(porteur, son) -- dehors : sur le porteur
	local duree, decalage = Config.Timing(E.Demat, mode)
	task.wait(decalage + duree)

	-- 2) Invisible : il quitte le porteur et rejoint la destination
	exterieur:SetAttribute("DepotCF", cible) -- les clients s'y recalent en arrêtant de suivre le porteur
	exterieur:SetAttribute("Porteur", nil)
	exterieur:PivotTo(cible)
	setCamouflage(false, true)
	setEtat(E.Vol)
	partage.occupe = false

	-- 3) Rematérialisation, toujours petit
	if joueurAFiger then figerJoueur(joueurAFiger, true) end
	local ok, erreur = atterrir(cible, nom, false, partDestination, mode)
	if joueurAFiger then figerJoueur(joueurAFiger, false) end
	partage.sauvegardeModifiee = true
	return ok, erreur
end

--------------------------------------------------------------------
-- Copilote (V6.9.1, ajout C2) : un pilote nomme un joueur à bord qui gère la navigation (destination, protocoles,
-- démat / remat, camouflage, atterrissage du vol libre) pendant qu'il pilote. Le copilote n'a aucun autre droit,
-- et il perd son poste dès qu'il quitte le TARDIS.
--------------------------------------------------------------------
local ACTIONS_COPILOTE = { Demat = true, Remat = true, Camouflage = true, NavAtterrir = true }
local function relacherCopilote(raison)
	local id = exterieur:GetAttribute("Copilote")
	if not id then return end
	exterieur:SetAttribute("Copilote", nil)
	exterieur:SetAttribute("CopiloteNom", nil)
	local ancien = Players:GetPlayerByUserId(id)
	if ancien then
		ancien:SetAttribute("TardisCopilote_" .. def.Nom, nil)
		if raison then remote:FireClient(ancien, "Tu n'es plus copilote du " .. def.Nom .. " : " .. raison .. ".", false) end
	end
end
local function designerCopilote(par, id)
	if (Config.Copilote or {}).Actif == false then return false, "COPILOTE DÉSACTIVÉ" end
	if id == nil or id == exterieur:GetAttribute("Copilote") then
		relacherCopilote("relevé par " .. par.DisplayName)
		return true, nil, "Copilote relevé."
	end
	local cible = typeof(id) == "number" and Players:GetPlayerByUserId(id)
	if not cible then return false, "JOUEUR INTROUVABLE" end
	if cible == par then return false, "TU PILOTES DÉJÀ" end
	if pilotes[cible] then return false, "DÉJÀ PILOTE" end
	local racine = cible.Character and cible.Character:FindFirstChild("HumanoidRootPart")
	if not racine or not dansInterieur(racine.Position) then return false, "PAS À BORD" end
	relacherCopilote("remplacé par " .. cible.DisplayName)
	exterieur:SetAttribute("Copilote", cible.UserId)
	exterieur:SetAttribute("CopiloteNom", cible.DisplayName)
	cible:SetAttribute("TardisCopilote_" .. def.Nom, true)
	remote:FireClient(cible, par.DisplayName .. " te nomme copilote du " .. def.Nom .. " : à toi la navigation et les protocoles.", true)
	journal("Équipage", string.format("%s : %s nomme %s copilote.", def.Nom, par.Name, cible.Name))
	return true, nil, cible.DisplayName .. " est copilote."
end
-- Le copilote doit rester à bord (et dans le jeu)
task.spawn(function()
	while true do
		task.wait(2)
		local id = exterieur:GetAttribute("Copilote")
		if id then
			local cible = Players:GetPlayerByUserId(id)
			local racine = cible and cible.Character and cible.Character:FindFirstChild("HumanoidRootPart")
			if not cible then
				relacherCopilote(nil)
			elseif not racine or not dansInterieur(racine.Position) then
				relacherCopilote("tu as quitté le TARDIS")
			elseif cible:GetAttribute("TardisBanni_" .. def.Nom) == true then
				relacherCopilote("accès retiré")
			end
		end
	end
end)

-- Les ordres des pilotes (menu, tablette) ; V6.9.10.1 : aussi les commandes de la console qui reprennent une action du
-- menu (bouton Vol libre), avec exactement les mêmes vérifications. rappel(ok, message) : seulement pour un appel du
-- serveur lui-même (un client ne peut pas envoyer de fonction par un RemoteEvent).
local function traiterOrdre(joueur, action, donnees, rappel)
	-- Le serveur ne fait jamais confiance au client : permission, type et fréquence vérifiés ici
	if typeof(action) ~= "string" then return end
	if typeof(rappel) ~= "function" then rappel = nil end
	-- Préférences du joueur : traitées par TardisExtras seul (V6.9.9). Ici, elles consommeraient le délai entre deux ordres
	-- d'un pilote (DÉMAT ignoré juste après un changement de réglage) et remettraient son inactivité à zéro.
	if action == "Prefs" then return end

	-- Actions du porteur (n'importe quel joueur qui tient le TARDIS, pas forcément un pilote)
	if action == "ModePort" or action == "Poser" then
		if exterieur:GetAttribute("Porteur") ~= joueur.UserId then return end
		if action == "Poser" then
			poserTardis(joueur)
		else
			-- Main -> Ceinture -> Épaule -> Main
			local suivant = { Main = "Ceinture", Ceinture = "Epaule", Epaule = "Main" }
			exterieur:SetAttribute("ModePort", suivant[exterieur:GetAttribute("ModePort")] or "Main")
		end
		return
	end

	-- Vol libre : positions (~15 par seconde), chute et atterrissage, réservés au pilote en cours
	if action == "VolLibre" then
		recevoirPositionVol(joueur, donnees)
		return
	end
	if action == "VolLibreVortex" or action == "VolLibreUrgence" then
		if exterieur:GetAttribute("VolLibre") == joueur.UserId and not volLibre.enDescente then
			local attribut = action == "VolLibreVortex" and "VolVortex" or "VolUrgence"
			exterieur:SetAttribute(attribut, not exterieur:GetAttribute(attribut))
		end
		return
	end
	if action == "VolLibreDemat" or action == "VolLibreRemat" then
		if exterieur:GetAttribute("VolLibre") == joueur.UserId then
			if action == "VolLibreDemat" then
				changerPhaseVol("Visible", "Demat", "Invisible", E.Demat, typeof(donnees) == "table" and donnees.mode)
			else
				changerPhaseVol("Invisible", "Remat", "Visible", E.Remat, typeof(donnees) == "table" and donnees.mode)
			end
		end
		return
	end
	if action == "VolLibreSaut" then
		if exterieur:GetAttribute("VolLibre") == joueur.UserId and not volLibre.enDescente then
			local recharge = (reglagesVol.SautRecharge or 4) * 0.8
			if os.clock() - (volLibre.dernierSaut or 0) >= recharge then
				volLibre.dernierSaut = os.clock()
				volLibre.bonusDistance = (reglagesVol.SautDistance or 45) + 10
				exterieur:SetAttribute("VolSaut", workspace:GetServerTimeNow()) -- effets chez tous les clients
			end
		end
		return
	end
	if action == "VolLibrePortes" then
		if exterieur:GetAttribute("VolLibre") == joueur.UserId and not volLibre.enDescente then
			task.spawn(basculerPortesEnVol)
		end
		return
	end
	if action == "VolLibreFrein" then
		-- V6.9.10 : pilote du vol libre seul, sans données, au plus un frein par seconde (vérifié dans freinerVol)
		freinerVol(joueur, donnees)
		return
	end
	if action == "VolLibreGlisse" then
		if exterieur:GetAttribute("VolLibre") == joueur.UserId then lancerGlisse(donnees) end
		return
	end
	if action == "VolLibreTeleAtterrir" then
		if exterieur:GetAttribute("VolLibre") == joueur.UserId then task.spawn(teleAtterrir, donnees) end
		return
	end
	if action == "VolLibrePrecision" then
		if exterieur:GetAttribute("VolLibre") == joueur.UserId and not volLibre.enDescente then
			-- Le rétrécissement est fait par chaque client sur sa copie (le TARDIS est déjà déplacé localement en vol)
			exterieur:SetAttribute("VolPrecision", not exterieur:GetAttribute("VolPrecision"))
		end
		return
	end
	if action == "VolLibreChute" or action == "VolLibrePoser" then
		if exterieur:GetAttribute("VolLibre") == joueur.UserId then
			lancerDescente(action == "VolLibreChute" and "Chute" or "Douce", false, donnees)
		end
		return
	end
	if action == "VolLibreCamouflage" then
		-- Camouflage pendant le vol libre (seulement matérialisé)
		if exterieur:GetAttribute("VolLibre") == joueur.UserId and not volLibre.enDescente
			and exterieur:GetAttribute("VolPhase") == "Visible" then
			setCamouflage(not exterieur:GetAttribute("Camouflage"), false)
		end
		return
	end

	-- Copilote (V6.9.1) : seulement la navigation
	local copilote = not pilotes[joueur] and exterieur:GetAttribute("Copilote") == joueur.UserId
	if not pilotes[joueur] and not (copilote and ACTIONS_COPILOTE[action]) then return end
	-- Maintenance (V6.9.4) : plus de voyage ni de vol (un vol libre déjà commencé peut se terminer). Ce script prévient
	-- le joueur pour toutes les actions refusées, celles de TardisExtras comprises (qui les ignore sans rien dire).
	local maintenance = Config.bloqueParMaintenance(exterieur, action)
	if maintenance then
		remote:FireClient(joueur, "Impossible : TARDIS en maintenance (" .. maintenance .. ").", false)
		if rappel then rappel(false, "EN MAINTENANCE") end
		return
	end
	marquerActivite()
	-- Détruit (auto-destruction) ou compte à rebours en cours : plus aucune commande
	if exterieur:GetAttribute("Detruit") or exterieur:GetAttribute("AutoDestructionDebut") then
		remote:FireClient(joueur, exterieur:GetAttribute("Detruit") and "Impossible : TARDIS détruit, il se reconstitue bientôt." or "Impossible : auto-destruction en cours.", false)
		if rappel then rappel(false, exterieur:GetAttribute("Detruit") and "TARDIS DÉTRUIT" or "AUTO-DESTRUCTION EN COURS") end
		return
	end
	local maintenant = os.clock()
	if dernierOrdre[joueur] and maintenant - dernierOrdre[joueur] < Config.Cooldown then return end
	dernierOrdre[joueur] = maintenant

	local function repondre(ok, erreur, messageOk)
		remote:FireClient(joueur, ok and messageOk or ("Impossible : " .. string.lower(erreur or "erreur")), ok)
		if rappel then rappel(ok, ok and messageOk or (erreur or "ERREUR")) end
	end

	-- Mode demandé : "Normal", "Urgence", "Express", "Sauvetage" (les anciens champs urgence / express restent acceptés) ;
	-- "Catastrophe" n'est jamais demandé : il est imposé par une destination dans le TARDIS (confirmée)
	local mode = "Normal"
	if typeof(donnees) == "table" then
		mode = Config.normaliserMode(donnees.mode or (donnees.urgence == true and "Urgence") or (donnees.express == true and "Express"))
		if mode == "Catastrophe" then mode = "Normal" end
	end

	if action == "Demat" then
		task.spawn(function()
			local ok, erreur = decoller(mode)
			if ok then journal("Voyage", string.format("%s : décollage demandé par %s.", def.Nom, joueur.Name)) end
			local modeReel = Config.modeDe(exterieur)
			repondre(ok, erreur, (modeReel == "Urgence" and "Décollage d'urgence réussi : le TARDIS est en vol.")
				or (modeReel == "Express" and "Décollage rapide : le TARDIS est en vol.") or "Le TARDIS est en vol.")
		end)

	elseif action == "Remat" then
		if typeof(donnees) ~= "table" then return end
		local invisible = donnees.invisible == true
		local cible, nom, partDestination
		local joueurAFiger, avisRepli = nil, nil

		if exterieur:GetAttribute("Retreci") then
			-- Rétréci : atterrissage sur place uniquement, la destination demandée est ignorée
			cible, nom = cibleSurPlace()
			partDestination = partage.positionActuelle
		else
			local erreur
			cible, nom, partDestination, joueurAFiger, erreur, avisRepli = resoudreDestination(donnees, true, etatActuel() == E.Vol)
			if not cible then
				if erreur then repondre(false, erreur) end
				return
			end
		end

		-- Paradoxe (V6.7.1) : la destination est dans le TARDIS lui-même. Première demande : atterrissage avorté et
		-- demande de confirmation au menu ("__paradoxe", message caché) ; demande confirmée (forcer) : mode Catastrophe.
		if dansInterieur(cible.Position) then
			if donnees.forcer == true then
				mode = "Catastrophe"
			else
				remote:FireClient(joueur, "__paradoxe", false)
				task.spawn(function()
					local ok, erreur = atterrissageAvorte(cible, nom, invisible)
					repondre(ok, erreur, "Paradoxe : la destination est dans le TARDIS. Matérialisation repoussée. Clique encore sur REMAT pour forcer.")
				end)
				return
			end
		end

		task.spawn(function()
			if joueurAFiger then figerJoueur(joueurAFiger, true) end
			local ok, erreur, urgenceForcee = atterrir(cible, nom, invisible, partDestination, mode)
			if ok then journal("Voyage", string.format("%s : atterrissage à %s demandé par %s%s.", def.Nom, nom, joueur.Name, invisible and " (invisible)" or "")) end
			if joueurAFiger then figerJoueur(joueurAFiger, false) end

			local texte = (invisible and "Atterri en secret : " or "Atterri : ") .. nom .. "."
			if mode == "Catastrophe" then
				texte = "PARADOXE : le TARDIS s'est matérialisé dans lui-même. Intégrité abîmée, alerte générale. " .. texte
			elseif urgenceForcee then
				texte = "Atterrissage d'urgence imposé (collision ou zone refusée). " .. texte
			elseif mode == "Urgence" then
				texte = "Atterrissage d'urgence réussi. " .. texte
			elseif mode == "Express" then
				texte = "Atterrissage rapide. " .. texte
			elseif mode == "Sauvetage" then
				texte = "Sauvetage : descente terminée, portes ouvertes. " .. texte
			end
			if avisRepli then texte = avisRepli .. " " .. texte end
			repondre(ok, erreur, texte)
		end)

	elseif action == "Taille" then
		local facteur = typeof(donnees) == "table" and donnees.facteur
		if typeof(facteur) ~= "number" or facteur ~= facteur then return end
		task.spawn(function()
			local ok, erreur = reglerTaille(facteur)
			local pourcentage = math.floor((exterieur:GetAttribute("Echelle") or 1) * 100 + 0.5)
			repondre(ok, erreur, "Taille réglée à " .. pourcentage .. " %.")
		end)

	elseif action == "FermerPortes" then
		task.spawn(function()
			local ok, erreur = fermerPortesSimple()
			repondre(ok, erreur, "Portes fermées.")
		end)

	elseif action == "Portes" then
		-- Bascule : ouvre si elles sont fermées, ferme si elles sont ouvertes
		task.spawn(function()
			if exterieur:GetAttribute("PorteOuverte") then
				local ok, erreur = fermerPortesSimple()
				repondre(ok, erreur, "Portes fermées.")
			else
				local ok, erreur = ouvrirPortesSimple()
				repondre(ok, erreur, "Portes ouvertes.")
			end
		end)

	elseif action == "Verrou" then
		task.spawn(function()
			local ok, erreur = basculerVerrou()
			repondre(ok, erreur, exterieur:GetAttribute("PortesVerrouillees") and "Portes verrouillées." or "Portes déverrouillées.")
		end)

	elseif action == "Repositionner" then
		-- Menu "Rotation" : démat, quelques secondes de vortex, puis remat à la position et à la rotation choisies
		if typeof(donnees) ~= "table" or typeof(donnees.position) ~= "CFrame" then return end
		local cible, nom, _, _, erreur = resoudreDestination({ position = donnees.position })
		if not cible then
			repondre(false, erreur)
			return
		end
		task.spawn(function()
			local ok, erreurDemat = decoller(false)
			if not ok then
				repondre(false, erreurDemat)
				return
			end
			task.wait(Config.DureeVortexRepositionnement or 10)
			-- atterrir passe tout seul en urgence si le TARDIS est trop enfoncé dans un décor
			local okRemat, erreurRemat, urgenceForcee = atterrir(cible, nom, false, nil, false)
			repondre(okRemat, erreurRemat,
				(urgenceForcee and "Collision : rematérialisation d'urgence. " or "") .. "TARDIS repositionné.")
		end)

	elseif action == "DematPorte" then
		-- Téléportation de poche : réservée à celui qui porte le TARDIS
		if exterieur:GetAttribute("Porteur") ~= joueur.UserId then
			repondre(false, "tu ne portes pas le TARDIS")
			return
		end
		if typeof(donnees) ~= "table" then return end
		local cible, nom, partDestination, joueurAFiger, erreur = resoudreDestination(donnees)
		if not cible then
			repondre(false, erreur or "aucune destination choisie")
			return
		end
		task.spawn(function()
			local ok, erreurPoche = teleporterEnPoche(joueur, cible, nom, partDestination, joueurAFiger, donnees.mode)
			repondre(ok, erreurPoche, "Rematérialisé (petit) : " .. nom .. ".")
		end)

	elseif action == "Bouclier" then
		local type = typeof(donnees) == "table" and donnees.type
		if typeof(type) ~= "string" then return end
		local ok, erreur = basculerBouclier(type)
		local actif = exterieur:GetAttribute("Bouclier" .. type) == true
		local nom = (type == "Balles" and "Bouclier anti-balles") or (type == "Complet" and "Bouclier complet") or "Bouclier anti-joueurs"
		repondre(ok, erreur, nom .. (actif and " activé." or " désactivé."))

	elseif action == "Siege" then
		-- Mode Siège (V6.9) : bouclier, verrou et alerte d'un seul geste ; un second appui les relâche
		task.spawn(function()
			local reglages = Config.Siege or {}
			local lever = not exterieur:GetAttribute("Siege")
			local typeBouclier = reglages.Bouclier or "Complet"
			local refus = {}
			if lever and etatActuel() ~= E.Pose then repondre(false, "PAS POSÉ") return end
			if reglages.Verrou ~= false and (exterieur:GetAttribute("PortesVerrouillees") == true) ~= lever then
				local ok, erreur = basculerVerrou()
				if not ok then table.insert(refus, "verrou : " .. string.lower(erreur or "?")) end
			end
			if typeBouclier and (exterieur:GetAttribute("Bouclier" .. typeBouclier) == true) ~= lever then
				local ok, erreur = basculerBouclier(typeBouclier)
				if not ok then table.insert(refus, "bouclier : " .. string.lower(erreur or "?")) end
			end
			if reglages.Alerte ~= false and (exterieur:GetAttribute("Alerte") == true) ~= lever then
				local ok, erreur = basculerAlerte()
				if not ok then table.insert(refus, "alerte : " .. string.lower(erreur or "?")) end
			end
			exterieur:SetAttribute("Siege", lever)
			if lever then alerter("MODE SIÈGE") end
			journal("Sécurité", string.format("%s : mode Siège %s par %s.", def.Nom, lever and "levé" or "relâché", joueur.Name))
			remote:FireClient(joueur, (lever and "Mode Siège : bouclier levé, portes verrouillées, alerte générale." or "Siège levé : bouclier, verrou et alerte relâchés.")
				.. (#refus > 0 and ("  (Non appliqué : " .. table.concat(refus, ", ") .. ")") or ""), #refus == 0)
		end)

	elseif action == "Copilote" then
		-- Nommer (joueur = UserId) ou relever (joueur absent, ou le copilote actuel) le copilote
		local id = typeof(donnees) == "table" and tonumber(donnees.joueur) or nil
		local ok, erreur, message = designerCopilote(joueur, id)
		repondre(ok, erreur, message)

	elseif action == "NavAtterrir" then
		-- Vol libre : atterrir à la destination choisie par la navigation (pilote ou copilote), une fois dans le vortex
		if not exterieur:GetAttribute("VolLibre") then repondre(false, "PAS EN VOL LIBRE") return end
		if exterieur:GetAttribute("VolPhase") ~= "Invisible" or volLibre.enDescente then repondre(false, "LE PILOTE DOIT D'ABORD PASSER DANS LE VORTEX") return end
		if typeof(donnees) ~= "table" then return end
		local cible, nom, _, _, erreur = resoudreDestination(donnees, false)
		if not cible then repondre(false, erreur or "DESTINATION INVALIDE") return end
		task.spawn(function()
			local ok = teleAtterrir(cible.Position)
			if ok then
				journal("Voyage", string.format("%s : atterrissage du vol libre à %s demandé par %s%s.", def.Nom, nom, joueur.Name, copilote and " (copilote)" or ""))
				local pilote = Players:GetPlayerByUserId(exterieur:GetAttribute("VolLibre") or 0)
				if pilote and pilote ~= joueur then remote:FireClient(pilote, joueur.DisplayName .. " pose le TARDIS : " .. nom .. ".", true) end
			end
			repondre(ok, "ATTERRISSAGE IMPOSSIBLE ICI", "Atterrissage vers " .. tostring(nom) .. ".")
		end)

	elseif action == "VolLibreDebut" then
		task.spawn(function()
			local ok, erreur = demarrerVolLibre(joueur)
			repondre(ok, erreur, "Vol libre activé : à toi de piloter !")
		end)

	elseif action == "Camouflage" then
		local ok, erreur = basculerCamouflage()
		repondre(ok, erreur, exterieur:GetAttribute("Camouflage") and "Camouflage activé." or "Camouflage désactivé.")
	end
end
remote.OnServerEvent:Connect(traiterOrdre)

--------------------------------------------------------------------
-- Bouton Vol libre de la console (V6.9.10.1) : Console › Selecteur › Colors. Un clic ou l'invite (touche F) lance le vol
-- libre pour le pilote qui l'actionne, par le même chemin que l'action « VolLibreDebut » de la tablette (traiterOrdre :
-- pilote, maintenance, détruit, délai entre deux ordres, puis demarrerVolLibre : posé, porté, courant, démarrage…).
-- Rien pour un non-pilote. Un refus s'affiche sur les écrans de destination, comme pour les autres commandes.
--------------------------------------------------------------------
if Config.Chemins.VolLibre then
	task.spawn(function()
		local partVol = Config.partDe(Config.trouverCommande(interieur, "VolLibre", 10))
		if not partVol then
			warn("[TARDIS] Bouton Vol libre (" .. table.concat(Config.Chemins.VolLibre, " › ") .. ") introuvable : le vol libre reste dans la tablette.")
			return
		end
		local reglagesBouton = Config.BoutonVolLibre or {}
		local promptVol = creerPrompt(partVol, "Vol libre")
		promptVol.Name = "TardisVolLibre"
		promptVol.MaxActivationDistance = reglagesBouton.Distance or 10
		local okTouche, touche = pcall(function() return Enum.KeyCode[reglagesBouton.Touche or "F"] end)
		promptVol.KeyboardKeyCode = okTouche and touche or Enum.KeyCode.F -- pas E : l'invite du Selecteur reste visible
		promptVol.GamepadKeyCode = Enum.KeyCode.ButtonY
		local clicVol = Instance.new("ClickDetector")
		clicVol.Name = "TardisVolLibre"
		clicVol.MaxActivationDistance = reglagesBouton.Distance or 10
		clicVol.Parent = partVol
		local function lancerDepuisConsole(joueur)
			if not pilotes[joueur] then return end
			traiterOrdre(joueur, "VolLibreDebut", nil, function(ok, message)
				if not ok then alerter(string.upper(message or "IMPOSSIBLE")) end
			end)
		end
		promptVol.Triggered:Connect(lancerDepuisConsole)
		clicVol.MouseClick:Connect(lancerDepuisConsole)
		-- L'invite n'apparaît que TARDIS posé, hors vol libre
		local function majBoutonVol()
			promptVol.Enabled = etatActuel() == E.Pose and not exterieur:GetAttribute("VolLibre")
		end
		exterieur:GetAttributeChangedSignal("Etat"):Connect(majBoutonVol)
		exterieur:GetAttributeChangedSignal("VolLibre"):Connect(majBoutonVol)
		majBoutonVol()
	end)
end

Players.PlayerRemoving:Connect(function(joueur)
	dernierOrdre[joueur] = nil
end)

promptRamasser.Triggered:Connect(function(joueur)
	if not pilotes[joueur] then return end -- réservé aux joueurs autorisés (Config.Pilotes)
	if Config.bloqueParMaintenance(exterieur, "Ramasser") then alerter("EN MAINTENANCE") return end
	ramasser(joueur)
end)

-- Si le porteur meurt, réapparaît ou quitte le jeu, le TARDIS est reposé là où il était
local function surveillerPorteur(joueur)
	joueur.CharacterRemoving:Connect(function(personnage)
		poserTardis(joueur, personnage)
		if exterieur:GetAttribute("VolLibre") == joueur.UserId then
			task.spawn(lancerDescente, "Douce", true) -- V6.9.7 : invisible, il se rematérialise d'abord
		end
	end)
end
Players.PlayerAdded:Connect(surveillerPorteur)
for _, joueur in Players:GetPlayers() do
	surveillerPorteur(joueur)
end


--------------------------------------------------------------------
-- Sauvegarde (DataStore) : l'état du TARDIS survit aux redémarrages du serveur
--------------------------------------------------------------------
do
	local reglagesSave = Config.Sauvegarde or {}
	-- Sauvegarde versionnée (V6.8.1) : nouveau magasin, l'ancien n'est que lu (migration sans perte)
	local store = nil
	if reglagesSave.Actif ~= false then
		local Sauvegarde = require(script.Parent:WaitForChild("TardisSauvegarde"))
		store = Sauvegarde.ouvrir((reglagesSave.NomStore or "TardisSauvegarde_v2") .. "_" .. def.Nom,
			(reglagesSave.AncienStore or "TardisSauvegarde_v1") .. "_" .. def.Nom)
		if not store:disponible() then store = nil end
	end
	local CLE = "place_" .. tostring(game.PlaceId)
	local chargementReussi = false -- tant que la lecture a échoué, on n'écrase pas la sauvegarde

	local function versTable(cf) return { cf:GetComponents() } end
	local function versCFrame(t) return CFrame.new(table.unpack(t)) end

	local function sauvegarder()
		if not store or not chargementReussi then return end
		-- On ne sauvegarde qu'un état stable (posé, pas en vol libre, pas porté)
		if etatActuel() ~= E.Pose or partage.occupe or exterieur:GetAttribute("VolLibre") or exterieur:GetAttribute("Porteur") then return end
		local donnees = {
			cf = versTable(exterieur:GetPivot()),
			position = exterieur:GetAttribute("Position"),
			echelle = exterieur:GetAttribute("Echelle") or 1,
			camouflage = exterieur:GetAttribute("Camouflage") == true,
			verrou = exterieur:GetAttribute("PortesVerrouillees") == true,
			alimentation = exterieur:GetAttribute("Alimentation") ~= false,
			demarrageBloque = exterieur:GetAttribute("DemarrageBloque") == true,
			precedent = precedent and { cf = versTable(precedent.cf), nom = precedent.nom } or nil,
			historique = historique,
		}
		if store:ecrire(CLE, donnees) then partage.sauvegardeModifiee = false end
	end

	local function charger()
		if not store then return end
		local donnees, lu = store:lire(CLE)
		if not lu then
			warn("[TARDIS] Sauvegarde illisible pour l'instant : elle ne sera pas écrasée pendant cette session.")
			return
		end
		chargementReussi = true
		if type(donnees) ~= "table" or type(donnees.cf) ~= "table" then return end

		-- Au lancement, le TARDIS reste là où il est placé dans Studio.
		-- Sa dernière position sauvegardée devient la "dernière destination" du menu (entrée "Retour : ...").
		local dernierePosition = versCFrame(donnees.cf)
		if (dernierePosition.Position - exterieur:GetPivot().Position).Magnitude > 5 then
			precedent = { cf = dernierePosition, nom = tostring(donnees.position or "Dernière position") }
		elseif type(donnees.precedent) == "table" and type(donnees.precedent.cf) == "table" then
			-- Il n'avait pas bougé depuis Studio : on garde la dernière destination déjà connue
			precedent = { cf = versCFrame(donnees.precedent.cf), nom = donnees.precedent.nom or "?" }
		end
		if precedent then
			exterieur:SetAttribute("PrecedentNom", precedent.nom)
		end
		if type(donnees.historique) == "table" then
			historique = {}
			for _, h in donnees.historique do
				if type(h) == "table" and #h >= 4 then table.insert(historique, h) end -- 5e champ (mode) depuis la V6.6.4
			end
			publierHistorique()
		end
		local facteur = math.clamp(tonumber(donnees.echelle) or 1, Config.TailleMin or 0.25, 1)
		if facteur < 0.999 and hauteurNormale then
			exterieur:ScaleTo(echelleNormale * facteur)
			exterieur:SetAttribute("Echelle", facteur)
			exterieur:SetAttribute("Retreci", true)
			exterieur:SetAttribute("Verrouille", tropPetitPourLesPortes(facteur))
		end
		if donnees.camouflage then setCamouflage(true, true) end
		if donnees.verrou then exterieur:SetAttribute("PortesVerrouillees", true) end
		if donnees.alimentation == false then
			exterieur:SetAttribute("Alimentation", false)
			appliquerEclairage()
		end
		if donnees.demarrageBloque then exterieur:SetAttribute("DemarrageBloque", true) end
		verifierEau()
		majRamassage()
		majEcran()
		print("[TARDIS] Sauvegarde chargée. Dernière position disponible dans le menu : " .. tostring(precedent and precedent.nom))
	end

	charger()
	for _, nom in { "Camouflage", "PortesVerrouillees", "Alimentation", "DemarrageBloque", "Echelle", "Position" } do
		exterieur:GetAttributeChangedSignal(nom):Connect(function() partage.sauvegardeModifiee = true end)
	end
	task.spawn(function()
		while true do
			task.wait(reglagesSave.Intervalle or 60)
			if partage.sauvegardeModifiee then sauvegarder() end
		end
	end)
	game:BindToClose(sauvegarder)
end

if (Config.Maintenance or {}).AuDemarrage then
	exterieur:SetAttribute("Maintenance", ((Config.Maintenance or {}).Raisons or {})[1] or "Réparations en cours")
end

--------------------------------------------------------------------
-- Pont interne : TardisExtras (balise, rappel, minuterie, leurre, zones interdites...) utilise ces fonctions
--------------------------------------------------------------------
do
	local pont = Instance.new("BindableFunction")
	pont.Name = Config.canal(def, "TardisInterne")
	pont.Parent = game:GetService("ServerStorage")
	pont.OnInvoke = function(action, ...)
		if action == "decoller" then return decoller(...)
		elseif action == "atterrir" then return atterrir(...)
		elseif action == "resoudreDestination" then return resoudreDestination(...)
		elseif action == "cibleJoueur" then return cibleJoueur(...)
		elseif action == "dansInterieur" then return dansInterieur(...)
		elseif action == "estPilote" then local j = ... return pilotes[j] == true
		elseif action == "etat" then return etatActuel(), partage.occupe
		elseif action == "alerter" then alerter(...) return true
		elseif action == "jouer" then jouer(...) return true
		elseif action == "sauvegarder" then partage.sauvegardeModifiee = true return true
		elseif action == "setEtat" then setEtat(...) return true
		elseif action == "collisions" then setCollisionsExterieur(...) return true
		elseif action == "listeDestinations" then return listeDestinations()
		elseif action == "destinationChoisie" then return destinationChoisie()
		elseif action == "reglerAlimentation" then reglerAlimentation(...) return true
		elseif action == "basculerAlimentation" then return basculerAlimentation()
		elseif action == "basculerVerrou" then return basculerVerrou()
		elseif action == "ouvrirPortes" then return ouvrirPortesSimple()
		elseif action == "emmener" then emmenerALInterieur() return true
		end
		return nil
	end
end

print("[TARDIS] " .. def.Nom .. " : serveur prêt (V" .. tostring(Config.Version or "?") .. ").")
-- Diagnostic : une ligne qui résume les pièces, sons et destinations en place
task.spawn(function()
	local ok, resultat = pcall(function()
		return require(script.Parent:WaitForChild("TardisDiagnostic", 10))(def, exterieur, interieur)
	end)
	if ok then print(resultat) else warn("[TARDIS] Diagnostic impossible : " .. tostring(resultat)) end
end)