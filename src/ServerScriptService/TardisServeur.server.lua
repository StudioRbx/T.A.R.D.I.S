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
local function enPart(objet)
	if objet:IsA("BasePart") then return objet end
	return (objet:IsA("Model") and objet.PrimaryPart) or objet:FindFirstChildWhichIsA("BasePart", true)
end

local selecteur = enPart(Config.Trouver(interieur, "Selecteur"))
local levier = enPart(Config.Trouver(interieur, "Levier"))
local ecran = Config.Trouver(interieur, "Ecran")

assert(exterieur.PrimaryPart, "[TARDIS] Le Model extérieur doit avoir un PrimaryPart (la base).")

-- Canal du menu à distance (client -> serveur pour les commandes, serveur -> client pour les réponses)
local remote = Instance.new("RemoteEvent")
remote.Name = Config.canal(def, "TardisCommande")
remote.Parent = ReplicatedStorage

--------------------------------------------------------------------
-- Sons (positionnés : autour de l'extérieur ET dans l'intérieur)
--------------------------------------------------------------------
local function preparerSon(nom, parent, optionnel)
	local modele = dossierSons:FindFirstChild(nom)
	if not modele then
		if not optionnel then
			warn("[TARDIS] Son manquant : ReplicatedStorage.TardisAssets.Sons." .. nom)
		end
		return nil
	end
	local son = modele:Clone()
	son.Parent = parent
	return son
end

-- [nom] = { son extérieur, son intérieur }
local LISTE_SONS = {
	{ "Demat", false }, { "Remat", false },
	{ "Demat_Urg", false }, { "Remat_Urg", false },
	{ "Demat_Express", true }, { "Remat_Express", true },
	{ "Camouflage", true }, { "Decamouflage", true },
}
local sons = {}
for _, info in LISTE_SONS do
	local nom, optionnel = info[1], info[2]
	sons[nom] = {
		ext = preparerSon(nom, exterieur.PrimaryPart, optionnel),
		int = preparerSon(nom, partRotor, optionnel),
	}
end

-- Son express absent : le son normal, sans son silence de départ, coupé en fondu à la fin de l'animation express
local function jouerExpress(son, nom)
	local etat = string.find(nom, "Demat") and E.Demat or E.Remat
	local _, decalage = Config.Timing(etat, false)
	local duree = Config.Timing(etat, false, true)
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
	if not (groupe and (groupe.int or groupe.ext)) and string.find(nom, "_Express") then
		local normal = sons[(string.gsub(nom, "_Express", ""))]
		if not normal then return end
		if normal.int then jouerExpress(normal.int, nom) end
		if dehorsAussi and normal.ext then jouerExpress(normal.ext, nom) end
		return
	end
	-- Son d'urgence absent : on se rabat sur le son normal
	if not (groupe and (groupe.int or groupe.ext)) and string.find(nom, "_Urg") then
		groupe = sons[(string.gsub(nom, "_Urg", ""))]
	end
	if not groupe then return end
	if groupe.int then groupe.int:Play() end
	if dehorsAussi and groupe.ext then groupe.ext:Play() end
end

--------------------------------------------------------------------
-- Écran de la console
--------------------------------------------------------------------
local guiEcran = Instance.new("SurfaceGui")
guiEcran.Face = Enum.NormalId.Front
guiEcran.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
guiEcran.PixelsPerStud = 50
guiEcran.Parent = ecran

local texte = Instance.new("TextLabel")
texte.Size = UDim2.fromScale(1, 1)
texte.BackgroundColor3 = Color3.fromRGB(10, 20, 30)
texte.Font = Enum.Font.Code
texte.TextScaled = true
texte.Parent = guiEcran

local libelles = {
	[E.Pose] = "POSÉ",
	[E.Demat] = "DÉMATÉRIALISATION",
	[E.Vol] = "EN VOL",
	[E.Remat] = "MATÉRIALISATION",
}

local function etatActuel()
	return exterieur:GetAttribute("Etat") or E.Pose
end

--------------------------------------------------------------------
-- Destinations
--------------------------------------------------------------------
local indexDestination = 1
local positionActuelle = nil -- Part de destination où le TARDIS se trouve
local precedent = nil        -- { cf, nom } : là d'où le TARDIS est parti (bouton "Dernière destination")
local sauvegardeModifiee = false

local historique = {} -- { { nom, x, y, z }, ... } : les 10 derniers atterrissages
local function publierHistorique()
	local lignes = {}
	for _, h in historique do
		table.insert(lignes, string.format("%s\t%.1f\t%.1f\t%.1f", h[1], h[2], h[3], h[4]))
	end
	exterieur:SetAttribute("Historique", table.concat(lignes, "\n"))
end
local function ajouterHistorique(nom, cf)
	local p = cf.Position
	table.insert(historique, 1, { tostring(nom), p.X, p.Y, p.Z })
	while #historique > 10 do table.remove(historique) end
	publierHistorique()
	sauvegardeModifiee = true
end

local function memoriserDepart()
	precedent = { cf = exterieur:GetPivot(), nom = tostring(exterieur:GetAttribute("Position") or "Départ") }
	exterieur:SetAttribute("PrecedentNom", precedent.nom)
	sauvegardeModifiee = true
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

local function majEcran(alerte)
	local dest = destinationChoisie()
	local ligneEtat = "ÉTAT : " .. libelles[etatActuel()]
	if exterieur:GetAttribute("Alerte") then
		ligneEtat = "!! ALERTE !!\n" .. ligneEtat
	end
	if exterieur:GetAttribute("DemarrageBloque") then
		ligneEtat ..= "\n(DÉMARRAGE BLOQUÉ)"
	end
	if exterieur:GetAttribute("Camouflage") then
		ligneEtat ..= "\n(CAMOUFLÉ)"
	end
	if exterieur:GetAttribute("Retreci") then
		ligneEtat ..= "\n(RÉTRÉCI)"
	end
	texte.Text = string.format("DESTINATION :\n%s\n\n%s", dest and dest.Name or "AUCUNE", alerte or ligneEtat)
	texte.TextColor3 = alerte and Color3.fromRGB(255, 90, 90) or Color3.fromRGB(120, 220, 255)
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
exterieur:SetAttribute("Urgence", false)
exterieur:SetAttribute("Express", false)
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
	local autorise = estPilote(joueur) or joueur:GetAttribute("TardisPiloteTemp_" .. def.Nom) == true
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
local occupe = false -- vrai pendant une animation (portes, demat, remat)

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
-- urgence = true : sons Demat_Urg et animation saccadée
--------------------------------------------------------------------
-- Vortex temporel (voyage classique) : pendant le vol, le TARDIS est visible très haut dans le ciel et tourne sur
-- lui-même, entouré du vortex (dessiné par les clients). Les passagers clandestins collés à la cabine au départ
-- sont emportés avec elle, puis déposés dehors à l'arrivée.
--------------------------------------------------------------------
local dansInterieur -- définie plus bas (section des joueurs)
local dansZoneRefusee -- définie plus bas (atterrissage)
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

-- express = true : démat éclair (V6.6), ignorée si l'urgence est demandée ou imposée
local function decoller(urgence, express)
	urgence = urgence == true
	if occupe then return false, "TARDIS OCCUPÉ" end
	if etatActuel() ~= E.Pose then return false, "DÉJÀ EN VOL" end
	if exterieur:GetAttribute("Porteur") then return false, "TARDIS PORTÉ" end
	if exterieur:GetAttribute("Alimentation") == false then return false, "HORS TENSION" end
	if exterieur:GetAttribute("DemarrageBloque") then return false, "DÉMARRAGE BLOQUÉ" end
	-- Alerte générale : toujours en urgence
	if exterieur:GetAttribute("Alerte") then urgence = true end
	express = express == true and not urgence

	occupe = true
	exterieur:SetAttribute("Verrouille", true)

	if not fermerPortes() then
		exterieur:SetAttribute("Verrouille", false)
		occupe = false
		return false, "PORTES BLOQUÉES"
	end
	memoriserDepart()
	exterieur:SetAttribute("SurEau", false)

	local camoufle = exterieur:GetAttribute("Camouflage") == true
	exterieur:SetAttribute("Urgence", urgence) -- posé AVANT l'état : les clients choisissent la bonne animation
	exterieur:SetAttribute("Express", express)
	setEtat(E.Demat)
	jouer(urgence and "Demat_Urg" or (express and "Demat_Express") or "Demat", not camoufle) -- camouflé : on ne l'entend que de l'intérieur
	local duree, decalage = Config.Timing(E.Demat, urgence, express)
	task.wait(decalage + duree) -- son d'abord, puis l'animation complète

	setCollisionsExterieur(false)
	setCamouflage(false, true) -- remis à zéro pendant le vol (invisible de toute façon)
	-- Passagers clandestins : ceux qui se collent à la cabine au moment du départ partent avec elle
	reperer_clandestins()
	setEtat(E.Vol) -- vol silencieux
	exterieur:SetAttribute("Express", false)
	-- Vortex temporel : le TARDIS visible, très haut dans le ciel, tournant dans son vortex jusqu'à la matérialisation
	partir_dans_le_ciel()

	occupe = false
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

local function cibleJoueur(joueurCible)
	local personnage = joueurCible.Character
	local racine = personnage and personnage:FindFirstChild("HumanoidRootPart")
	if not racine then return nil, "JOUEUR SANS PERSONNAGE" end
	if dansInterieur(racine.Position) then return nil, "JOUEUR DANS LE TARDIS" end

	local sol = chercherSol(racine.Position)
	if not sol then return nil, "PAS DE SOL SOUS LE JOUEUR" end
	local devant = racine.CFrame.LookVector * Vector3.new(1, 0, 1)
	devant = devant.Magnitude > 0.01 and devant.Unit or Vector3.new(0, 0, -1)
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
local function atterrir(cible, nom, invisible, partDestination, urgence, express)
	urgence = urgence == true
	if occupe then return false, "TARDIS OCCUPÉ" end
	if etatActuel() ~= E.Vol then return false, "PAS EN VOL" end
	if exterieur:GetAttribute("Alimentation") == false then return false, "HORS TENSION" end
	-- Alerte générale : toujours en urgence
	if exterieur:GetAttribute("Alerte") then urgence = true end

	-- Une partie du TARDIS dans un mur : atterrissage d'urgence obligatoire
	local urgenceForcee = false
	local okCollision, collision = pcall(enCollision, cible)
	if okCollision and collision and not urgence then
		urgence, urgenceForcee = true, true
	end
	-- Zone refusée (sous-dossier REFUSE des destinations) : la première tentative est repoussée à mi-chemin,
	-- puis le TARDIS se matérialise en urgence, au même endroit
	local zoneRefusee = not urgence and dansZoneRefusee(cible.Position)
	-- Express : seulement si rien n'impose l'urgence (alerte, collision, zone refusée)
	express = express == true and not urgence and not zoneRefusee

	occupe = true

	revenir_du_ciel()
	exterieur:PivotTo(cible)
	positionActuelle = partDestination
	exterieur:SetAttribute("Position", nom)
	deposer_clandestins()

	-- Le camouflage est posé AVANT l'état, pour qu'aucune image ne montre le TARDIS
	setCamouflage(invisible, true)
	if zoneRefusee then
		-- Première tentative, en mode normal : à la moitié, le TARDIS est repoussé dans le vortex
		exterieur:SetAttribute("Urgence", false)
		setEtat(E.Remat)
		jouer("Remat", not invisible)
		local dureeNormale, decalageNormal = Config.Timing(E.Remat, false)
		task.wait(decalageNormal + dureeNormale / 2)
		alerter("ZONE REFUSÉE : MATÉRIALISATION REPOUSSÉE")
		exterieur:SetAttribute("Urgence", true)
		setEtat(E.Demat) -- il redisparaît (démat d'urgence, courte)
		jouer("Demat_Urg", not invisible)
		local dureeDemat, decalageDemat = Config.Timing(E.Demat, true)
		task.wait(decalageDemat + dureeDemat)
		setEtat(E.Vol)
		task.wait(1.5)
		urgence, urgenceForcee = true, true
	end
	exterieur:SetAttribute("Urgence", urgence) -- posé AVANT l'état : les clients choisissent la bonne animation
	exterieur:SetAttribute("Express", express)
	setEtat(E.Remat)
	jouer(urgence and "Remat_Urg" or (express and "Remat_Express") or "Remat", not invisible) -- invisible : on ne l'entend que de l'intérieur
	local duree, decalage = Config.Timing(E.Remat, urgence, express)
	task.wait(decalage + duree) -- son d'abord, puis l'animation complète

	emmenerALInterieur() -- avant les collisions, sinon les joueurs seraient coincés dans la cabine
	setCollisionsExterieur(true)
	setEtat(E.Pose)
	exterieur:SetAttribute("Urgence", false)
	exterieur:SetAttribute("Express", false)
	-- Trop petit : les portes restent bloquées
	exterieur:SetAttribute("Verrouille", tropPetitPourLesPortes())
	occupe = false
	verifierEau()
	ajouterHistorique(nom, cible)
	-- Les portes restent fermées : elles s'ouvriront quand un joueur voudra sortir (voir plus bas)
	return true, nil, urgenceForcee
end

-- La position est-elle dans une zone refusée (Part du sous-dossier REFUSE de TARDIS_DESTINATIONS) ?
dansZoneRefusee = function(position)
	local dossier = Config.dossierDestinations(false)
	local zone = dossier and dossier:FindFirstChild(Config.ZoneRestreinte or "REFUSE")
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
	if occupe then return false, "TARDIS OCCUPÉ" end
	occupe = true
	local fermees = fermerPortes()
	occupe = false
	majEcran()
	if not fermees then return false, "PORTES BLOQUÉES" end
	return true
end

-- Ouverture des portes à la demande (menu) : les scripts Shut ouvrent les deux battants
local function ouvrirPortesSimple()
	if exterieur:GetAttribute("PorteOuverte") then return false, "PORTES DÉJÀ OUVERTES" end
	if occupe then return false, "TARDIS OCCUPÉ" end
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
		if occupe then return false, "TARDIS OCCUPÉ" end
		occupe = true
		local fermees = fermerPortes()
		occupe = false
		majEcran()
		if not fermees then return false, "PORTES BLOQUÉES" end
	end
	exterieur:SetAttribute("PortesVerrouillees", verrouiller)
	return true
end

-- Voyage complet (levier de la console quand le TARDIS est posé)
local function voyager(dest)
	local ok, erreur = decoller()
	if not ok then
		alerter(erreur)
		return
	end
	task.wait(Config.DureeVol)
	if exterieur:GetAttribute("Retreci") then
		local cible, nom = cibleSurPlace()
		ok, erreur = atterrir(cible, nom, false, positionActuelle)
	else
		ok, erreur = atterrir(dest.CFrame, dest.Name, false, dest)
	end
	if not ok and erreur ~= "PAS EN VOL" then -- "PAS EN VOL" : quelqu'un a déjà fait atterrir le TARDIS via le menu
		alerter(erreur)
	end
end

local function basculerCamouflage()
	if occupe then return false, "TARDIS OCCUPÉ" end
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
	if occupe then return false, "TARDIS OCCUPÉ" end
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
	if occupe or etatActuel() ~= E.Pose or exterieur:GetAttribute("Verrouille") then return end
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
	marquerActivite()
	if not disponible() then return end
	local dest = destinationChoisie()
	if not dest then alerter("AUCUNE DESTINATION") return end

	local etat = etatActuel()
	local retreci = exterieur:GetAttribute("Retreci") == true
	if etat == E.Pose then
		if dest == positionActuelle and not retreci then alerter("DÉJÀ SUR PLACE") return end
		task.spawn(voyager, dest)
	elseif etat == E.Vol then
		task.spawn(function()
			local ok, erreur
			if retreci then
				local cible, nom = cibleSurPlace()
				ok, erreur = atterrir(cible, nom, false, positionActuelle)
			else
				ok, erreur = atterrir(dest.CFrame, dest.Name, false, dest)
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
-- Alerte : Console > Circuit > Cloister > Switch
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
		and not occupe
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
	if occupe then return false, "TARDIS OCCUPÉ" end
	if etatActuel() ~= E.Pose then return false, "PAS POSÉ" end
	if exterieur:GetAttribute("Porteur") then return false, "TARDIS PORTÉ" end
	if exterieur:GetAttribute("Alimentation") == false then return false, "HORS TENSION" end

	local minimum = Config.TailleMin or 0.25
	facteur = math.clamp(facteur, minimum, 1)
	if facteur > 0.99 then facteur = 1 end
	local actuel = exterieur:GetAttribute("Echelle") or 1
	if math.abs(facteur - actuel) < 0.01 then return true end

	occupe = true
	majRamassage()

	-- Il passe sous le seuil des portes : on les ferme et on les bloque AVANT de rétrécir
	if tropPetitPourLesPortes(facteur) and not tropPetitPourLesPortes(actuel) then
		exterieur:SetAttribute("Verrouille", true)
		if not fermerPortes() then
			exterieur:SetAttribute("Verrouille", false)
			occupe = false
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

	occupe = false
	majRamassage()
	majEcran()
	return true
end

local function ramasser(joueur)
	if not exterieur:GetAttribute("Retreci") or exterieur:GetAttribute("Porteur") or occupe then return end
	setCollisionsExterieur(false) -- sinon il pousserait son porteur
	exterieur:SetAttribute("SurEau", false)
	exterieur:SetAttribute("ModePort", "Main")
	exterieur:SetAttribute("Porteur", joueur.UserId)
	exterieur:SetAttribute("Position", "Porté par " .. joueur.DisplayName)
	positionActuelle = nil
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
	sauvegardeModifiee = true
end

--------------------------------------------------------------------
-- Vol libre (piloté depuis la tablette)
-- Le pilote envoie la position du TARDIS ~15 fois par seconde ; le serveur la vérifie et la publie
-- dans l'attribut VolLibreCF, que tous les clients suivent. Les vraies pièces ne bougent qu'à l'atterrissage.
--------------------------------------------------------------------
local reglagesVol = Config.VolLibre or {}
local volLibre = { dernierCF = nil, dernierTemps = 0, enDescente = false }
local ATTRIBUTS_DESCENTE = { "DescenteMode", "DescenteDepart", "DescenteArrivee", "DescenteDebut", "DescenteDuree" }

-- Portes en plein vol : les passagers voient le paysage défiler et peuvent sauter.
-- Pendant le vol, les portes restent bloquées (Verrouille) : on ne les débloque que le temps de les ouvrir.
local function fermerPortesEnVol()
	if exterieur:GetAttribute("PorteOuverte") then
		exterieur:SetAttribute("FermerPortes", true)
		task.delay(1, function() exterieur:SetAttribute("FermerPortes", false) end)
	end
end

local function basculerPortesEnVol()
	if exterieur:GetAttribute("PorteOuverte") then
		fermerPortesEnVol()
		return
	end
	if exterieur:GetAttribute("PortesVerrouillees") or tropPetitPourLesPortes() then return end
	if exterieur:GetAttribute("VolPhase") ~= "Visible" then return end
	exterieur:SetAttribute("Verrouille", false)
	exterieur:SetAttribute("OuvrirPorte", false)
	task.wait()
	exterieur:SetAttribute("OuvrirPorte", true)
	task.delay(1, function()
		exterieur:SetAttribute("OuvrirPorte", false)
		if exterieur:GetAttribute("VolLibre") then
			exterieur:SetAttribute("Verrouille", true) -- refermables, mais pas rouvrables par quelqu'un d'autre
		end
	end)
end

-- Démat / remat EN VOL : le TARDIS devient invisible (ou réapparaît) sans arrêter le vol libre.
-- Phases : "Visible" -> "Demat" -> "Invisible" -> "Remat" -> "Visible" (animées chez les clients)
local function phaseVol(phase, urgence)
	exterieur:SetAttribute("VolPhaseUrgence", urgence == true)
	exterieur:SetAttribute("VolPhaseDebut", workspace:GetServerTimeNow())
	exterieur:SetAttribute("VolPhase", phase) -- en dernier : déclenche l'animation chez les clients
end

local function changerPhaseVol(depuis, transition, arrivee, etatAnimation, son)
	if exterieur:GetAttribute("VolPhase") ~= depuis or volLibre.enDescente then return end
	if transition == "Demat" then fermerPortesEnVol() end
	local urgence = exterieur:GetAttribute("VolUrgence") == true
	phaseVol(transition, urgence)
	-- Le son de la salle de contrôle est joué ici ; celui de dehors est joué par les clients, sur le TARDIS qui bouge
	jouer(urgence and (son .. "_Urg") or son, false)
	local duree, decalage = Config.Timing(etatAnimation, urgence)
	local jeton = {}
	volLibre.jetonPhase = jeton
	task.delay(duree + decalage, function()
		if volLibre.jetonPhase == jeton and exterieur:GetAttribute("VolPhase") == transition then
			phaseVol(arrivee, urgence)
		end
	end)
end

local function demarrerVolLibre(pilote)
	if exterieur:GetAttribute("VolLibre") then return false, "DÉJÀ EN VOL LIBRE" end
	if occupe then return false, "TARDIS OCCUPÉ" end
	if etatActuel() ~= E.Pose then return false, "PAS POSÉ" end
	if exterieur:GetAttribute("Porteur") then return false, "TARDIS PORTÉ" end
	if exterieur:GetAttribute("Alimentation") == false then return false, "HORS TENSION" end
	if exterieur:GetAttribute("DemarrageBloque") then return false, "DÉMARRAGE BLOQUÉ" end

	occupe = true -- rien d'autre ne peut être fait pendant le vol libre
	majRamassage()
	exterieur:SetAttribute("Verrouille", true)
	if not fermerPortes() then
		exterieur:SetAttribute("Verrouille", tropPetitPourLesPortes())
		occupe = false
		majRamassage()
		return false, "PORTES BLOQUÉES"
	end

	setCollisionsExterieur(false)
	exterieur:SetAttribute("VolVortex", false)
	exterieur:SetAttribute("VolUrgence", false)
	phaseVol("Visible", false)
	volLibre.dernierCF = exterieur:GetPivot()
	volLibre.dernierTemps = os.clock()
	volLibre.enDescente = false
	memoriserDepart()
	exterieur:SetAttribute("SurEau", false)
	volLibre.bonusDistance = 0
	exterieur:SetAttribute("VolLibreCF", volLibre.dernierCF)
	exterieur:SetAttribute("VolLibre", pilote.UserId)
	exterieur:SetAttribute("Position", "Vol libre")
	positionActuelle = nil
	majEcran()
	return true
end

-- Position envoyée par le pilote : vérifiée (format, zone, vitesse) avant d'être publiée
local function recevoirPositionVol(pilote, cf)
	if exterieur:GetAttribute("VolLibre") ~= pilote.UserId or volLibre.enDescente then return end
	if typeof(cf) ~= "CFrame" then return end
	local p = cf.Position
	if p.X ~= p.X or p.Y ~= p.Y or p.Z ~= p.Z then return end -- NaN
	if math.abs(p.X) > 100000 or math.abs(p.Y) > 100000 or math.abs(p.Z) > 100000 then return end
	if dansInterieur(p) then return end

	-- Vitesse maximale : si la position saute trop loin, on la ramène à la distance autorisée
	local maintenant = os.clock()
	local dt = math.clamp(maintenant - volLibre.dernierTemps, 0.03, 1)
	local vitesseMax = 0
	for _, v in reglagesVol.Niveaux or { reglagesVol.Vitesse or 40 } do
		vitesseMax = math.max(vitesseMax, v)
	end
	local maxDistance = (vitesseMax * 1.4 + 10) * dt + 2 + (volLibre.bonusDistance or 0)
	local ancien = volLibre.dernierCF.Position
	local ecart = p - ancien
	if ecart.Magnitude > maxDistance then
		p = ancien + ecart.Unit * maxDistance
	end
	volLibre.dernierCF = (CFrame.new(p) * cf.Rotation):Orthonormalize()
	volLibre.dernierTemps = maintenant
	volLibre.bonusDistance = 0 -- le bond du saut temporel ne sert qu'une fois
	exterieur:SetAttribute("VolLibreCF", volLibre.dernierCF)
end

-- Vol de précision : le TARDIS rapetisse (30 %) le temps du mode, puis reprend sa taille
local function echellerEnVol(facteur)
	if not hauteurNormale then return end
	facteur = math.clamp(facteur, Config.TailleMin or 0.25, 1)
	exterieur:ScaleTo(echelleNormale * facteur)
	exterieur:SetAttribute("Echelle", facteur)
	exterieur:SetAttribute("Retreci", facteur < 0.999)
end

local function finirVolLibre(arrivee)
	exterieur:SetAttribute("VolPrecision", false)
	exterieur:SetAttribute("Tempete", nil)
	exterieur:PivotTo(arrivee)
	exterieur:SetAttribute("DepotCF", arrivee) -- les clients s'y recalent en arrêtant de suivre le vol
	emmenerALInterieur()                      -- les joueurs sous le TARDIS se retrouvent à bord
	setCollisionsExterieur(true)
	exterieur:SetAttribute("VolLibre", nil)
	exterieur:SetAttribute("VolLibreCF", nil)
	exterieur:SetAttribute("VolVortex", false)
	exterieur:SetAttribute("VolUrgence", false)
	volLibre.jetonPhase = nil
	exterieur:SetAttribute("VolPhase", nil) -- de nouveau visible normalement
	for _, nom in ATTRIBUTS_DESCENTE do
		exterieur:SetAttribute(nom, nil)
	end
	exterieur:SetAttribute("DescenteVitesse", nil)
	exterieur:SetAttribute("DescenteGravite", nil)
	exterieur:SetAttribute("DescenteRebond", nil)
	exterieur:SetAttribute("DescenteGlisse", nil)
	exterieur:SetAttribute("Verrouille", tropPetitPourLesPortes())
	local p = arrivee.Position
	exterieur:SetAttribute("Position", string.format("Vol libre (%d, %d, %d)", p.X, p.Y, p.Z))
	verifierEau()
	sauvegardeModifiee = true
	volLibre.enDescente = false
	occupe = false
	majRamassage()
	majEcran()
end

-- mode "Chute" : chute libre à la verticale (effet de rentrée atmosphérique côté clients)
-- mode "Douce" : descente posée jusqu'au sol
-- Chute avec élan : on suit la trajectoire (vitesse initiale + gravité) jusqu'au premier obstacle
local function trajectoireChute(depart, vitesse, gravite)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclus = { exterieur, interieur }
	for _, autre in Players:GetPlayers() do
		if autre.Character then table.insert(exclus, autre.Character) end
	end
	params.FilterDescendantsInstances = exclus
	params.RespectCanCollide = true
	local pas = 0.05
	local position = depart.Position
	for i = 1, 200 do -- 10 s maximum
		local temps = i * pas
		local suivante = depart.Position + vitesse * temps + Vector3.new(0, -0.5 * gravite * temps * temps, 0)
		local resultat = workspace:Raycast(position, suivante - position, params)
		if resultat then
			return resultat.Position, temps, resultat.Normal
		end
		position = suivante
	end
	return nil
end

local function lancerDescente(mode, force, vitesseInitiale)
	if not exterieur:GetAttribute("VolLibre") or volLibre.enDescente then return false end
	-- Il faut être matérialisé pour se poser (sauf si le pilote part : on le pose quand même)
	if not force and exterieur:GetAttribute("VolPhase") ~= "Visible" then return false end
	volLibre.enDescente = true
	fermerPortesEnVol() -- on referme avant de se poser

	local depart = volLibre.dernierCF
	-- En urgence, la chute garde l'élan du vol : trajectoire balistique au lieu de la verticale
	if mode == "Chute" and exterieur:GetAttribute("VolUrgence") and typeof(vitesseInitiale) == "Vector3" and vitesseInitiale.Magnitude > 10 then
		local vitesseMax = (reglagesVol.VitesseUrgence or 220) * 1.2
		if vitesseInitiale.Magnitude > vitesseMax then vitesseInitiale = vitesseInitiale.Unit * vitesseMax end
		local gravite = reglagesVol.GraviteChute or 70
		local impact, duree = trajectoireChute(depart, vitesseInitiale, gravite)
		if impact then
			local devant = vitesseInitiale * Vector3.new(1, 0, 1)
			devant = devant.Magnitude > 0.01 and devant.Unit or Vector3.new(0, 0, -1)
			local arrivee = CFrame.lookAt(impact + Vector3.new(0, exterieur.PrimaryPart.Size.Y / 2, 0), impact + devant + Vector3.new(0, exterieur.PrimaryPart.Size.Y / 2, 0))
			exterieur:SetAttribute("DescenteMode", "Chute")
			exterieur:SetAttribute("DescenteDepart", depart)
			exterieur:SetAttribute("DescenteArrivee", arrivee)
			exterieur:SetAttribute("DescenteVitesse", vitesseInitiale) -- les clients animent la parabole
			exterieur:SetAttribute("DescenteGravite", gravite)
			exterieur:SetAttribute("DescenteDuree", duree)
			exterieur:SetAttribute("DescenteDebut", workspace:GetServerTimeNow())
			task.delay(duree, function() finirVolLibre(arrivee) end)
			return true
		end
	end
	exterieur:SetAttribute("DescenteVitesse", nil)
	exterieur:SetAttribute("DescenteGravite", nil)
	exterieur:SetAttribute("DescenteRebond", nil)
	exterieur:SetAttribute("DescenteGlisse", nil)
	local devant = depart.LookVector * Vector3.new(1, 0, 1)
	devant = devant.Magnitude > 0.01 and devant.Unit or Vector3.new(0, 0, -1)
	-- Le point d'impact est calculé par le serveur, à la verticale du TARDIS
	local sol = chercherSol(depart.Position + Vector3.new(0, 2, 0), 3000)
	local arrivee = sol and CFrame.lookAt(sol, sol + devant) or CFrame.lookAt(depart.Position, depart.Position + devant)

	local hauteur = math.max(depart.Position.Y - arrivee.Position.Y, 0)
	local duree
	if mode == "Chute" then
		duree = math.clamp(math.sqrt(2 * hauteur / (reglagesVol.GraviteChute or 70)), 0.8, 5)
	else
		duree = math.clamp(hauteur / (reglagesVol.VitesseDescente or 14), 0.8, 5)
	end

	-- Rebond : une chute très rapide fait rebondir le TARDIS une fois (0,9 s de plus)
	if mode == "Chute" and math.sqrt(2 * (reglagesVol.GraviteChute or 70) * hauteur) > 60 then
		exterieur:SetAttribute("DescenteRebond", math.clamp(hauteur * 0.08, 3, 10))
		duree += 0.9
	end
	exterieur:SetAttribute("DescenteMode", mode)
	exterieur:SetAttribute("DescenteDepart", depart)
	exterieur:SetAttribute("DescenteArrivee", arrivee)
	exterieur:SetAttribute("DescenteDuree", duree)
	exterieur:SetAttribute("DescenteDebut", workspace:GetServerTimeNow()) -- en dernier : lance l'animation chez les clients
	task.delay(duree, function()
		finirVolLibre(arrivee)
	end)
	return true
end

-- Atterrissage glissé (urgence, "Atterrir ici") : descente rapide puis glissade de quelques mètres avec étincelles
local function lancerGlisse(vitesse)
	if not exterieur:GetAttribute("VolLibre") or volLibre.enDescente then return false end
	if exterieur:GetAttribute("VolPhase") ~= "Visible" then return false end
	volLibre.enDescente = true
	fermerPortesEnVol()
	local depart = volLibre.dernierCF
	local horizontale = typeof(vitesse) == "Vector3" and vitesse * Vector3.new(1, 0, 1) or Vector3.zero
	local direction = horizontale.Magnitude > 1 and horizontale.Unit or depart.LookVector * Vector3.new(1, 0, 1)
	if direction.Magnitude < 0.01 then direction = Vector3.new(0, 0, -1) end
	direction = direction.Unit
	local sol1 = chercherSol(depart.Position + Vector3.new(0, 2, 0), 3000)
	if not sol1 then
		volLibre.enDescente = false
		return lancerDescente("Douce")
	end
	local longueur = math.clamp(horizontale.Magnitude * 0.25, 8, 25)
	local sol2 = chercherSol(sol1 + direction * longueur + Vector3.new(0, 4, 0), 30) or (sol1 + direction * longueur)
	local toucher = CFrame.lookAt(sol1, sol1 + direction)
	local arrivee = CFrame.lookAt(sol2, sol2 + direction)
	local hauteur = math.max(depart.Position.Y - sol1.Y, 0)
	local dureeDescente = math.clamp(hauteur / 40, 0.5, 2.5)
	local dureeGlisse = math.clamp(longueur / 12, 0.8, 2.2)
	exterieur:SetAttribute("DescenteMode", "Glisse")
	exterieur:SetAttribute("DescenteDepart", depart)
	exterieur:SetAttribute("DescenteGlisse", toucher)      -- point où il touche le sol
	exterieur:SetAttribute("DescenteGlisseDuree", dureeDescente)
	exterieur:SetAttribute("DescenteArrivee", arrivee)     -- fin de la glissade
	exterieur:SetAttribute("DescenteDuree", dureeDescente + dureeGlisse)
	exterieur:SetAttribute("DescenteDebut", workspace:GetServerTimeNow())
	task.delay(dureeDescente + dureeGlisse, function() finirVolLibre(arrivee) end)
	return true
end

-- "Atterrir ici" quand le chemin est bloqué : le TARDIS, déjà dématérialisé en vol, se rematérialise au point visé
local function teleAtterrir(position)
	if not exterieur:GetAttribute("VolLibre") or volLibre.enDescente then return false end
	if exterieur:GetAttribute("VolPhase") ~= "Invisible" then return false end
	if typeof(position) ~= "Vector3" or dansInterieur(position) then return false end
	local sol = chercherSol(position + Vector3.new(0, 20, 0), 3000)
	if not sol then return false end
	local devant = volLibre.dernierCF.LookVector * Vector3.new(1, 0, 1)
	devant = devant.Magnitude > 0.01 and devant.Unit or Vector3.new(0, 0, -1)
	local cible = CFrame.lookAt(sol, sol + devant)
	volLibre.dernierCF = cible
	exterieur:SetAttribute("VolLibreCF", cible) -- tout le monde se recale, invisible
	task.wait(0.2)
	changerPhaseVol("Invisible", "Remat", "Visible", E.Remat, "Remat")
	volLibre.enDescente = true
	local duree, decalage = Config.Timing(E.Remat, exterieur:GetAttribute("VolUrgence") == true)
	task.delay(duree + decalage + 0.1, function() finirVolLibre(cible) end)
	return true
end

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
local function resoudreDestination(donnees)
	local cible, nom, partDestination
	local joueurAFiger = nil
	if typeof(donnees.destination) == "string" and #donnees.destination <= 100 then
		-- Atterrissage sur une destination
		local dest = dossierDestinations:FindFirstChild(donnees.destination, true) -- sous-dossiers compris
		if not (dest and dest:IsA("BasePart")) then
			return nil, nil, nil, nil, "destination introuvable"
		end
		cible, nom, partDestination = dest.CFrame, dest.Name, dest

	elseif typeof(donnees.joueur) == "number" then
		-- Atterrissage près d'un joueur
		local joueurCible = Players:GetPlayerByUserId(donnees.joueur)
		if not joueurCible then
			return nil, nil, nil, nil, "joueur introuvable"
		end
		local erreur
		cible, erreur = cibleJoueur(joueurCible)
		if not cible then
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
	local groupe = sons[nom] or sons[(string.gsub(nom, "_Urg", ""))]
	local modele = groupe and (groupe.ext or groupe.int)
	local racine = joueurCible.Character and joueurCible.Character:FindFirstChild("HumanoidRootPart")
	if not (modele and racine) then return end
	local son = modele:Clone()
	son.Parent = racine
	son:Play()
	son.Ended:Connect(function() son:Destroy() end)
end

-- Téléportation de poche : le TARDIS porté se dématérialise dans les mains (ou sur l'épaule) de son porteur,
-- puis se rematérialise tout seul, toujours petit, à la destination choisie
local function teleporterEnPoche(porteur, cible, nom, partDestination, joueurAFiger)
	if exterieur:GetAttribute("Porteur") ~= porteur.UserId then return false, "TARDIS PAS PORTÉ" end
	if occupe then return false, "TARDIS OCCUPÉ" end
	if not estAlimente() then return false, "HORS TENSION" end
	if exterieur:GetAttribute("DemarrageBloque") then return false, "DÉMARRAGE BLOQUÉ" end
	local urgence = exterieur:GetAttribute("Alerte") == true

	occupe = true
	majRamassage()

	-- 1) Dématérialisation dans les mains du porteur (les clients continuent de le faire suivre)
	exterieur:SetAttribute("Urgence", urgence)
	setEtat(E.Demat)
	local son = urgence and "Demat_Urg" or "Demat"
	jouer(son, false)                -- dans la salle de contrôle
	jouerSurPersonnage(porteur, son) -- dehors : sur le porteur
	local duree, decalage = Config.Timing(E.Demat, urgence)
	task.wait(decalage + duree)

	-- 2) Invisible : il quitte le porteur et rejoint la destination
	exterieur:SetAttribute("DepotCF", cible) -- les clients s'y recalent en arrêtant de suivre le porteur
	exterieur:SetAttribute("Porteur", nil)
	exterieur:PivotTo(cible)
	setCamouflage(false, true)
	setEtat(E.Vol)
	occupe = false

	-- 3) Rematérialisation, toujours petit
	if joueurAFiger then figerJoueur(joueurAFiger, true) end
	local ok, erreur = atterrir(cible, nom, false, partDestination, urgence)
	if joueurAFiger then figerJoueur(joueurAFiger, false) end
	sauvegardeModifiee = true
	return ok, erreur
end

remote.OnServerEvent:Connect(function(joueur, action, donnees)
	-- Le serveur ne fait jamais confiance au client : permission, type et fréquence vérifiés ici
	if typeof(action) ~= "string" then return end

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
				changerPhaseVol("Visible", "Demat", "Invisible", E.Demat, "Demat")
			else
				changerPhaseVol("Invisible", "Remat", "Visible", E.Remat, "Remat")
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

	if not pilotes[joueur] then return end
	marquerActivite()
	-- Détruit (auto-destruction) ou compte à rebours en cours : plus aucune commande
	if exterieur:GetAttribute("Detruit") or exterieur:GetAttribute("AutoDestructionDebut") then
		remote:FireClient(joueur, exterieur:GetAttribute("Detruit") and "Impossible : TARDIS détruit, il se reconstitue bientôt." or "Impossible : auto-destruction en cours.", false)
		return
	end
	local maintenant = os.clock()
	if dernierOrdre[joueur] and maintenant - dernierOrdre[joueur] < Config.Cooldown then return end
	dernierOrdre[joueur] = maintenant

	local function repondre(ok, erreur, messageOk)
		remote:FireClient(joueur, ok and messageOk or ("Impossible : " .. string.lower(erreur or "erreur")), ok)
	end

	local urgence = typeof(donnees) == "table" and donnees.urgence == true
	local express = typeof(donnees) == "table" and donnees.express == true and not urgence

	if action == "Demat" then
		task.spawn(function()
			local ok, erreur = decoller(urgence, express)
			repondre(ok, erreur, urgence and "Décollage d'urgence réussi : le TARDIS est en vol."
				or (express and "Décollage express : le TARDIS est en vol.") or "Le TARDIS est en vol.")
		end)

	elseif action == "Remat" then
		if typeof(donnees) ~= "table" then return end
		local invisible = donnees.invisible == true
		local cible, nom, partDestination
		local joueurAFiger = nil

		if exterieur:GetAttribute("Retreci") then
			-- Rétréci : atterrissage sur place uniquement, la destination demandée est ignorée
			cible, nom = cibleSurPlace()
			partDestination = positionActuelle
		else
			local erreur
			cible, nom, partDestination, joueurAFiger, erreur = resoudreDestination(donnees)
			if not cible then
				if erreur then repondre(false, erreur) end
				return
			end
		end

		task.spawn(function()
			if joueurAFiger then figerJoueur(joueurAFiger, true) end
			local ok, erreur, urgenceForcee = atterrir(cible, nom, invisible, partDestination, urgence, express)
			if joueurAFiger then figerJoueur(joueurAFiger, false) end

			local texte = (invisible and "Atterri en secret : " or "Atterri : ") .. nom .. "."
			if urgenceForcee then
				texte = "Collision détectée : atterrissage d'urgence. " .. texte
			elseif urgence then
				texte = "Atterrissage d'urgence réussi. " .. texte
			elseif express then
				texte = "Atterrissage express. " .. texte
			end
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
			local ok, erreurPoche = teleporterEnPoche(joueur, cible, nom, partDestination, joueurAFiger)
			repondre(ok, erreurPoche, "Rematérialisé (petit) : " .. nom .. ".")
		end)

	elseif action == "Bouclier" then
		local type = typeof(donnees) == "table" and donnees.type
		if typeof(type) ~= "string" then return end
		local ok, erreur = basculerBouclier(type)
		local actif = exterieur:GetAttribute("Bouclier" .. type) == true
		local nom = (type == "Balles" and "Bouclier anti-balles") or (type == "Complet" and "Bouclier complet") or "Bouclier anti-joueurs"
		repondre(ok, erreur, nom .. (actif and " activé." or " désactivé."))

	elseif action == "VolLibreDebut" then
		task.spawn(function()
			local ok, erreur = demarrerVolLibre(joueur)
			repondre(ok, erreur, "Vol libre activé : à toi de piloter !")
		end)

	elseif action == "Camouflage" then
		local ok, erreur = basculerCamouflage()
		repondre(ok, erreur, exterieur:GetAttribute("Camouflage") and "Camouflage activé." or "Camouflage désactivé.")
	end
end)

Players.PlayerRemoving:Connect(function(joueur)
	dernierOrdre[joueur] = nil
end)

promptRamasser.Triggered:Connect(function(joueur)
	if not pilotes[joueur] then return end -- réservé aux joueurs autorisés (Config.Pilotes)
	ramasser(joueur)
end)

-- Si le porteur meurt, réapparaît ou quitte le jeu, le TARDIS est reposé là où il était
local function surveillerPorteur(joueur)
	joueur.CharacterRemoving:Connect(function(personnage)
		poserTardis(joueur, personnage)
		if exterieur:GetAttribute("VolLibre") == joueur.UserId then
			lancerDescente("Douce", true)
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
	local store = nil
	if reglagesSave.Actif ~= false then
		local ok, resultat = pcall(function()
			return game:GetService("DataStoreService"):GetDataStore((reglagesSave.NomStore or "TardisSauvegarde_v1") .. "_" .. def.Nom)
		end)
		if ok then store = resultat else warn("[TARDIS] Sauvegarde indisponible : " .. tostring(resultat)) end
	end
	local CLE = "place_" .. tostring(game.PlaceId)

	local function versTable(cf) return { cf:GetComponents() } end
	local function versCFrame(t) return CFrame.new(table.unpack(t)) end

	local function sauvegarder()
		if not store then return end
		-- On ne sauvegarde qu'un état stable (posé, pas en vol libre, pas porté)
		if etatActuel() ~= E.Pose or occupe or exterieur:GetAttribute("VolLibre") or exterieur:GetAttribute("Porteur") then return end
		local donnees = {
			version = 1,
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
		local ok, erreur = pcall(function() store:SetAsync(CLE, donnees) end)
		if ok then
			sauvegardeModifiee = false
		else
			warn("[TARDIS] Échec de la sauvegarde : " .. tostring(erreur))
		end
	end

	local function charger()
		if not store then return end
		local ok, donnees = pcall(function() return store:GetAsync(CLE) end)
		if not ok then
			warn("[TARDIS] Échec du chargement de la sauvegarde : " .. tostring(donnees))
			return
		end
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
				if type(h) == "table" and #h == 4 then table.insert(historique, h) end
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
		exterieur:GetAttributeChangedSignal(nom):Connect(function() sauvegardeModifiee = true end)
	end
	task.spawn(function()
		while true do
			task.wait(reglagesSave.Intervalle or 60)
			if sauvegardeModifiee then sauvegarder() end
		end
	end)
	game:BindToClose(sauvegarder)
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
		elseif action == "etat" then return etatActuel(), occupe
		elseif action == "alerter" then alerter(...) return true
		elseif action == "jouer" then jouer(...) return true
		elseif action == "sauvegarder" then sauvegardeModifiee = true return true
		elseif action == "setEtat" then setEtat(...) return true
		elseif action == "collisions" then setCollisionsExterieur(...) return true
		elseif action == "listeDestinations" then return listeDestinations()
		elseif action == "destinationChoisie" then return destinationChoisie()
		elseif action == "reglerAlimentation" then reglerAlimentation(...) return true
		elseif action == "ouvrirPortes" then return ouvrirPortesSimple()
		elseif action == "emmener" then emmenerALInterieur() return true
		end
		return nil
	end
end

print("[TARDIS] " .. def.Nom .. " : serveur prêt (V" .. tostring(Config.Version or "?") .. ").")