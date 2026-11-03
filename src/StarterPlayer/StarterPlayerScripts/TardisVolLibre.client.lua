-- StarterPlayer > StarterPlayerScripts > TardisVolLibre (LocalScript)
-- VOL LIBRE du TARDIS (lancé depuis la tablette).
--   Pilote : vol en 3D dans la direction de la caméra (regarder en haut = monter), 4 vitesses,
--            collisions avec glissement le long des murs, inclinaison dans le sens du mouvement,
--            double Espace = chute (rentrée atmosphérique), G = se poser, F / bouton = vitesse suivante.
--   Tous les joueurs : le TARDIS suit les positions publiées par le serveur, avec traînées lumineuses,
--            particules temporelles, aura en Turbo, chute et impact.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("TardisConfig"))
local UI = require(ReplicatedStorage:WaitForChild("TardisUI"))
-- Protocoles partagés avec le menu et la tablette : l'Express s'applique aussi à la démat / remat en vol (V6.6.4)
local Commandes = require(ReplicatedStorage:WaitForChild("TardisCommandes"))
local C = UI.C
local creer, texte, animer = UI.creer, UI.texte, UI.animer

local joueur = Players.LocalPlayer
local camera = workspace.CurrentCamera
local def, monRole = Config.attendreMonTardis(joueur) -- le TARDIS de ce joueur (pilote ou technicien)
local exterieur, interieur = Config.modeles(def)
local remote = ReplicatedStorage:WaitForChild(Config.canal(def, "TardisCommande"))

local reglages = Config.VolLibre or {}
local R = {
	NIVEAUX = reglages.Niveaux or { 25, 50, 90, 150 },
	NOMS = reglages.NomsNiveaux or { "LENT", "NORMAL", "RAPIDE", "TURBO" },
	INCLINAISON = math.rad(reglages.Inclinaison or 18),
	ALTITUDE_MAX = reglages.AltitudeMax or 600,
	ROTATION_MAX = math.rad(reglages.RotationMax or 120),
	VITESSE_URGENCE = reglages.VitesseUrgence or 120,
	CHAMP_VISION = reglages.ChampDeVision or 22,
	ENVOIS_PAR_SECONDE = 15,
	DOUBLE_ESPACE = 0.35,
	TOUCHE_VITESSE = Enum.KeyCode.F,
	TOUCHE_URGENCE = Enum.KeyCode.U,
	TOUCHE_VORTEX = Enum.KeyCode.V,
	TOUCHE_SAUT = Enum.KeyCode.B,
	TOUCHE_PORTES = Enum.KeyCode.O,
	SAUT_DISTANCE = reglages.SautDistance or 45,
	SAUT_RECHARGE = reglages.SautRecharge or 4,
	TURB_RAYON = reglages.TurbulencesRayon or 28,
	TURB_FORCE = reglages.TurbulencesForce or 1,
	ERRATIQUE = reglages.ErratiqueUrgence or 0.9,
	VENT = reglages.VentAltitude or 0.4,
	TOUCHE_TONNEAU = Enum.KeyCode.C,
	TOUCHE_FREIN = Enum.KeyCode.LeftControl,
	TOUCHE_TRACTEUR = Enum.KeyCode.R,
	TOUCHE_CAMOUFLAGE = Enum.KeyCode.K,
	TOUCHE_STATIONNAIRE = Enum.KeyCode.H,
	TOUCHE_SIEGE = Enum.KeyCode.I,
	TOUCHE_BOOST = Enum.KeyCode.LeftShift,
	TOUCHE_ATTERRIR = Enum.KeyCode.N,
	TOUCHE_PLANEUR = Enum.KeyCode.J,
	TOUCHE_CIBLE = Enum.KeyCode.L,
	TOUCHE_PRECISION = Enum.KeyCode.P,
	TOUCHE_CAP = Enum.KeyCode.M,
	BOOST_DUREE = 1.5, BOOST_RECHARGE = 6,
}
R.VITESSE_MAX = math.max(table.unpack(R.NIVEAUX))

--------------------------------------------------------------------
-- État
--------------------------------------------------------------------
local vol = {
	pilote = false, suivait = false,
	centre = nil, vitesse = Vector3.zero,
	yaw = 0, rotation = 0, inclinaison = CFrame.new(),
	niveau = reglages.NiveauDepart or 2,
	taille = Vector3.new(4, 8, 4), altitudeDepart = 0,
	dernierEnvoi = 0, derniereEspace = 0,
	affiche = nil, dernierePosition = nil, vitesseVue = 0,
	descente = nil, effetsChute = nil, effetsVol = nil,
	cibleCamera = nil, ancrage = nil, champOrigine = 70,
	vortex = nil, effetsUrgence = nil, vitesseVecteur = Vector3.zero, teinte = nil,
	dernierSaut = 0, sautEnAttente = false,
	tonneau = 0, tonneauActif = false, dernierChoc = 0, viseur = nil, bruitUrgence = Vector3.zero,
	stationnaire = false, altitudeFixe = 0, planeur = false, capFixe = nil, cible = nil, atterrissage = nil,
	dernierBoost = -99, vitessePrecedente = Vector3.zero, gMax = 0, siege = nil, poseSiege = 1,
	controles = nil,
}

local function controles()
	if vol.controles then return vol.controles end
	local ok, module = pcall(function()
		return require(joueur:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")):GetControls()
	end)
	vol.controles = ok and module or nil
	return vol.controles
end

local function angleVers(actuel, cible, facteur)
	local ecart = (cible - actuel + math.pi) % (2 * math.pi) - math.pi
	return actuel + ecart * facteur
end

local function exclusions(...)
	local liste = { exterieur, interieur, ... }
	if vol.cibleCamera then table.insert(liste, vol.cibleCamera) end
	for _, autre in Players:GetPlayers() do
		if autre.Character then table.insert(liste, autre.Character) end
	end
	return liste
end

--------------------------------------------------------------------
-- Interface du pilote : boussole, réticule, lignes de vitesse, tableau de bord
--------------------------------------------------------------------
local H = {} -- éléments de l'interface du pilote
do
	H.gui = creer("ScreenGui", { Name = "TardisVolLibre", ResetOnSpawn = false, Enabled = false, IgnoreGuiInset = true,
		Parent = joueur:WaitForChild("PlayerGui") })

	-- Lignes de vitesse sur les bords de l'écran
	H.lignes = {}
	for i = 1, 18 do
		local angle = i / 18 * math.pi * 2
		local ligne = creer("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Rotation = math.deg(angle) + 90,
			Position = UDim2.fromScale(0.5 + math.cos(angle) * 0.46, 0.5 + math.sin(angle) * 0.46),
			Size = UDim2.fromOffset(2, 120), BackgroundColor3 = C.blanc, BackgroundTransparency = 1, BorderSizePixel = 0,
			Parent = H.gui })
		creer("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0), Parent = ligne })
		table.insert(H.lignes, { cadre = ligne, angle = angle, phase = math.random() * 6 })
	end

	-- Réticule
	local reticule = creer("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(26, 26), BackgroundTransparency = 1, Parent = H.gui }, { UI.coin(99), UI.contour(C.cyan, 1.5, 0.35) })
	creer("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(4, 4),
		BackgroundColor3 = C.cyan, Parent = reticule }, { UI.coin(99) })
	H.reticule = reticule

	-- Boussole défilante en haut de l'écran
	local boussole = creer("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 52),
		Size = UDim2.fromOffset(420, 40), BackgroundColor3 = C.fond, BackgroundTransparency = 0.25, ClipsDescendants = true,
		Parent = H.gui }, { UI.coin(10), UI.contour(C.cyan, 1, 0.5) })
	H.echelleBoussole = creer("UIScale", { Parent = boussole })
	creer("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0),
		NumberSequenceKeypoint.new(0.85, 0), NumberSequenceKeypoint.new(1, 1) }), Parent = boussole })
	creer("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(2, 12),
		BackgroundColor3 = C.ambre, BorderSizePixel = 0, ZIndex = 3, Parent = boussole })
	H.reperes = {}
	local noms = { [0] = "N", [45] = "NE", [90] = "E", [135] = "SE", [180] = "S", [225] = "SO", [270] = "O", [315] = "NO" }
	for degre = 0, 345, 15 do
		local nom = noms[degre]
		local repere = texte({ Text = nom or "·", Font = nom and UI.POLICE_GRAS or UI.POLICE, TextSize = nom and 14 or 12,
			TextColor3 = (degre == 0) and C.ambre or (nom and C.texte or C.texte2), TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.6), Size = UDim2.fromOffset(30, 20),
			Parent = boussole })
		table.insert(H.reperes, { cadre = repere, degre = degre })
	end
	H.cap = texte({ Text = "000°", Font = UI.POLICE_CODE, TextSize = 11, TextColor3 = C.ambre,
		TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 4),
		Size = UDim2.fromOffset(60, 14), Parent = boussole })
	boussole.ClipsDescendants = true

	-- Panneau d'informations, en bas à gauche
	local tableau = creer("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 20, 1, -24),
		Size = UDim2.fromOffset(330, 150), BackgroundColor3 = C.fond, BackgroundTransparency = 0.12, Parent = H.gui },
	{ UI.coin(18), UI.contour(C.cyan, 1.5, 0.35) })
	H.echelleTableau = creer("UIScale", { Parent = tableau })
	creer("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.blanc, Color3.fromRGB(150, 165, 195)), Parent = tableau })
	texte({ Text = "◆  VOL LIBRE", Font = UI.POLICE_GRAS, TextSize = 12, TextColor3 = C.cyan, Position = UDim2.fromOffset(18, 10),
		Size = UDim2.fromOffset(200, 14), Parent = tableau })
	texte({ Text = "Regarde où tu veux aller", TextSize = 11, TextColor3 = C.texte2, TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(0, 0, 0, 10), Size = UDim2.new(1, -18, 0, 14), Parent = tableau })

	-- Compteur de vitesse
	H.vitesse = texte({ Text = "0", Font = UI.POLICE_CODE, TextSize = 40, TextColor3 = C.texte,
		Position = UDim2.fromOffset(18, 30), Size = UDim2.fromOffset(110, 44), Parent = tableau })
	texte({ Text = "studs/s", Font = UI.POLICE_CODE, TextSize = 11, TextColor3 = C.texte2, Position = UDim2.fromOffset(20, 74),
		Size = UDim2.fromOffset(100, 12), Parent = tableau })
	local jauge = creer("Frame", { Position = UDim2.fromOffset(18, 96), Size = UDim2.new(1, -36, 0, 8), BackgroundColor3 = C.gris,
		Parent = tableau }, { UI.coin(99) })
	H.jauge = creer("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.blanc, Parent = jauge }, { UI.coin(99) })
	creer("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C.cyan), ColorSequenceKeypoint.new(0.6, C.ambre),
		ColorSequenceKeypoint.new(1, C.orange) }), Parent = H.jauge })

	-- Niveau de vitesse et phase (au centre), altitude (à droite)
	H.nomNiveau = texte({ Text = "NORMAL", Font = UI.POLICE_GRAS, TextSize = 16, TextColor3 = C.ambre,
		TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(130, 32), Size = UDim2.fromOffset(110, 20),
		Parent = tableau })
	local pastilles = creer("Frame", { Position = UDim2.fromOffset(130, 56), Size = UDim2.fromOffset(110, 10),
		BackgroundTransparency = 1, Parent = tableau }, { creer("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 5), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }) })
	H.phase = texte({ Text = "MATÉRIALISÉ", Font = UI.POLICE_CODE, TextSize = 10, TextColor3 = C.vert,
		TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(120, 70), Size = UDim2.fromOffset(130, 14),
		Parent = tableau })
	H.pastilles = {}
	for i = 1, #R.NIVEAUX do
		H.pastilles[i] = creer("Frame", { Size = UDim2.fromOffset(20, 7), BackgroundColor3 = C.gris, LayoutOrder = i,
			Parent = pastilles }, { UI.coin(99) })
	end
	texte({ Text = "ALTITUDE", Font = UI.POLICE_GRAS, TextSize = 10, TextColor3 = C.texte2, TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(1, -90, 0, 32), Size = UDim2.fromOffset(72, 12), Parent = tableau })
	H.altitude = texte({ Text = "0", Font = UI.POLICE_CODE, TextSize = 24, TextColor3 = C.cyan, TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(1, -90, 0, 44), Size = UDim2.fromOffset(72, 28), Parent = tableau })
	H.infosSecondaires = texte({ Text = "", Font = UI.POLICE_CODE, TextSize = 10, TextColor3 = C.texte2, TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(18, 112), Size = UDim2.new(1, -36, 0, 14), Parent = tableau })

	-- Panneau des boutons, à droite (deux colonnes) : 8 boutons essentiels, les autres dans le sous-menu PLUS.
	-- Toutes les touches du clavier restent les mêmes, sous-menu ouvert ou fermé.
	local panneauBoutons = creer("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -20, 0.5, 0),
		Size = UDim2.fromOffset(352, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.fond, BackgroundTransparency = 0.12,
		Parent = H.gui }, { UI.coin(18), UI.contour(C.cyan, 1.5, 0.35), UI.marges(12),
		creer("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
	H.echelleBoutons = creer("UIScale", { Parent = panneauBoutons })
	local function grille(ordre)
		return creer("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
			LayoutOrder = ordre, Parent = panneauBoutons }, { creer("UIGridLayout", { CellSize = UDim2.fromOffset(160, 34),
			CellPadding = UDim2.fromOffset(8, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }) })
	end
	local rangee = grille(1)
	H.sousMenu = grille(2)
	H.sousMenu.Visible = false
	local function bouton(txt, largeur, couleur, ordre, parent)
		local b = creer("TextButton", { Size = UDim2.fromOffset(largeur, 34), BackgroundColor3 = couleur, Text = txt,
			Font = UI.POLICE_GRAS, TextSize = 12, TextColor3 = C.texte, LayoutOrder = ordre, Parent = parent or rangee },
		{ UI.coin(10), UI.contour(C.blanc, 1, 0.8) })
		b:SetAttribute("CouleurBase", couleur)
		UI.rendreVivant(b)
		return b
	end
	-- Les 8 essentiels (DÉMAT et REMAT partagent une place : un seul est affiché selon la phase)
	H.boutonVitesse = bouton("VITESSE  ►  (F)", 160, C.bleu, 1)
	H.boutonUrgence = bouton("URGENCE  (U)", 160, Color3.fromRGB(110, 45, 25), 2)
	H.boutonVortex = bouton("VORTEX  (V)", 160, Color3.fromRGB(70, 40, 130), 3)
	H.boutonDemat = bouton("DÉMAT  (X)", 160, Color3.fromRGB(26, 75, 140), 4)
	H.boutonRemat = bouton("REMAT  (X)", 160, Color3.fromRGB(26, 75, 140), 4)
	H.boutonRemat.Visible = false
	H.boutonChute = bouton("CHUTE  (Espace ×2)", 160, Color3.fromRGB(150, 60, 20), 5)
	H.boutonPoser = bouton("SE POSER  (G)", 160, Color3.fromRGB(30, 100, 70), 6)
	H.boutonCamouflage = bouton("CAMOUFLAGE  (K)", 160, Color3.fromRGB(50, 80, 110), 7)
	H.boutonPlus = bouton("PLUS  ▼", 160, Color3.fromRGB(45, 55, 75), 8)
	-- Le sous-menu
	local sous = H.sousMenu
	H.boutonSaut = bouton("SAUT  (B)", 160, Color3.fromRGB(40, 110, 160), 1, sous)
	H.boutonPortes = bouton("PORTES  (O)", 160, Color3.fromRGB(60, 70, 95), 2, sous)
	H.boutonAtterrir = bouton("ATTERRIR ICI  (N)", 160, Color3.fromRGB(30, 110, 100), 3, sous)
	H.boutonStationnaire = bouton("STATIONNAIRE  (H)", 160, Color3.fromRGB(60, 90, 120), 4, sous)
	H.boutonBoost = bouton("BOOST  (Maj)", 160, Color3.fromRGB(150, 110, 30), 5, sous)
	H.boutonFrein = bouton("FREIN  (Ctrl)", 160, Color3.fromRGB(120, 90, 30), 6, sous)
	H.boutonTonneau = bouton("TONNEAU  (C)", 160, Color3.fromRGB(70, 90, 140), 7, sous)
	H.boutonTracteur = bouton("TRACTEUR  (R)", 160, Color3.fromRGB(30, 110, 120), 8, sous)
	H.boutonSiege = bouton("SIÈGE EXT.  (I)", 160, Color3.fromRGB(90, 70, 120), 9, sous)
	H.boutonPlaneur = bouton("PLANEUR  (J)", 160, Color3.fromRGB(70, 100, 90), 10, sous)
	H.boutonCible = bouton("CIBLE  (L)", 160, Color3.fromRGB(110, 60, 90), 11, sous)
	H.boutonPrecision = bouton("PRÉCISION  (P)", 160, Color3.fromRGB(60, 110, 60), 12, sous)
	H.boutonCap = bouton("CAP FIXE  (M)", 160, Color3.fromRGB(80, 80, 110), 13, sous)
end
H.boutonPlus.Activated:Connect(function()
	H.sousMenu.Visible = not H.sousMenu.Visible
	H.boutonPlus.Text = H.sousMenu.Visible and "MOINS  ▲" or "PLUS  ▼"
end)

local function afficherNiveau()
	H.nomNiveau.Text = R.NOMS[vol.niveau] or tostring(vol.niveau)
	H.nomNiveau.TextColor3 = vol.niveau == #R.NIVEAUX and C.orange or C.ambre
	for i, pastille in H.pastilles do
		animer(pastille, 0.2, { BackgroundColor3 = i <= vol.niveau and (i == #R.NIVEAUX and C.orange or C.ambre) or C.gris })
	end
end

local function vitesseSuivante()
	if not vol.pilote or vol.descente then return end
	vol.niveau = vol.niveau % #R.NIVEAUX + 1
	afficherNiveau()
	local echelle = H.nomNiveau:FindFirstChildOfClass("UIScale") or creer("UIScale", { Parent = H.nomNiveau })
	echelle.Scale = 1.35
	animer(echelle, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end

local tonneau, freiner -- définis plus bas (pilotage)
local basculerStationnaire, basculerSiege, boost, atterrirIci, basculerPlaneur, basculerCible, basculerCap -- idem
local function majBoutonsModes()
	UI.colorer(H.boutonStationnaire, vol.stationnaire and Color3.fromRGB(80, 140, 190) or Color3.fromRGB(60, 90, 120))
	H.boutonStationnaire.Text = vol.stationnaire and "STATIONNAIRE  ●" or "STATIONNAIRE  (H)"
	UI.setDisponible(H.boutonSiege, vol.stationnaire, vol.siege and Color3.fromRGB(140, 100, 190) or Color3.fromRGB(90, 70, 120))
	H.boutonSiege.Text = vol.siege and string.format("SIÈGE  ●  pose %d/4 (V)", vol.poseSiege) or "SIÈGE EXT.  (I)"
	UI.colorer(H.boutonPlaneur, vol.planeur and Color3.fromRGB(100, 160, 140) or Color3.fromRGB(70, 100, 90))
	H.boutonPlaneur.Text = vol.planeur and "PLANEUR  ●" or "PLANEUR  (J)"
	UI.colorer(H.boutonCible, vol.cible and Color3.fromRGB(170, 80, 140) or Color3.fromRGB(110, 60, 90))
	H.boutonCible.Text = vol.cible and ("CIBLE  ●  " .. tostring(vol.cible.nom)) or "CIBLE  (L)"
	local precision = exterieur:GetAttribute("VolPrecision") == true
	UI.colorer(H.boutonPrecision, precision and Color3.fromRGB(90, 170, 90) or Color3.fromRGB(60, 110, 60))
	H.boutonPrecision.Text = precision and "PRÉCISION  ●" or "PRÉCISION  (P)"
	UI.colorer(H.boutonCap, vol.capFixe and Color3.fromRGB(120, 120, 170) or Color3.fromRGB(80, 80, 110))
	H.boutonCap.Text = vol.capFixe and "CAP FIXE  ●" or "CAP FIXE  (M)"
	UI.colorer(H.boutonAtterrir, vol.atterrissage and Color3.fromRGB(40, 160, 140) or Color3.fromRGB(30, 110, 100))
	H.boutonAtterrir.Text = vol.atterrissage and "ATTERRISSAGE…  (N annule)" or "ATTERRIR ICI  (N)"
end
exterieur:GetAttributeChangedSignal("VolPrecision"):Connect(majBoutonsModes)
H.boutonVitesse.Activated:Connect(vitesseSuivante)
H.boutonCamouflage.Activated:Connect(function() if vol.pilote and not vol.descente then remote:FireServer("VolLibreCamouflage") end end)
exterieur:GetAttributeChangedSignal("Camouflage"):Connect(function()
	local actif = exterieur:GetAttribute("Camouflage") == true
	H.boutonCamouflage.Text = actif and "CAMOUFLAGE  ●" or "CAMOUFLAGE  (K)"
	UI.colorer(H.boutonCamouflage, actif and Color3.fromRGB(70, 140, 190) or Color3.fromRGB(50, 80, 110))
end)
H.boutonTonneau.Activated:Connect(function() if tonneau then tonneau() end end)
H.boutonStationnaire.Activated:Connect(function() if basculerStationnaire then basculerStationnaire() end end)
H.boutonSiege.Activated:Connect(function() if basculerSiege and H.boutonSiege:GetAttribute("Disponible") ~= false then basculerSiege() end end)
H.boutonBoost.Activated:Connect(function() if boost then boost() end end)
H.boutonAtterrir.Activated:Connect(function() if atterrirIci then atterrirIci() end end)
H.boutonPlaneur.Activated:Connect(function() if basculerPlaneur then basculerPlaneur() end end)
H.boutonCible.Activated:Connect(function() if basculerCible then basculerCible() end end)
H.boutonPrecision.Activated:Connect(function() if vol.pilote and not vol.descente then remote:FireServer("VolLibrePrecision") end end)
H.boutonCap.Activated:Connect(function() if basculerCap then basculerCap() end end)
H.boutonFrein.Activated:Connect(function() if freiner then freiner() end end)
H.boutonTracteur.Activated:Connect(function() if vol.pilote and not vol.descente then remote:FireServer("Tracteur") end end)
exterieur:GetAttributeChangedSignal("Tracteur"):Connect(function()
	local actif = exterieur:GetAttribute("Tracteur") == true
	H.boutonTracteur.Text = actif and "TRACTEUR  ●" or "TRACTEUR  (R)"
	UI.colorer(H.boutonTracteur, actif and Color3.fromRGB(0, 170, 190) or Color3.fromRGB(30, 110, 120))
end)
H.boutonDemat.Activated:Connect(function()
	if vol.pilote and not vol.descente and H.boutonDemat:GetAttribute("Disponible") ~= false then
		remote:FireServer("VolLibreDemat", { mode = Commandes.mode() })
	end
end)
H.boutonRemat.Activated:Connect(function()
	if vol.pilote and not vol.descente and H.boutonRemat:GetAttribute("Disponible") ~= false then
		remote:FireServer("VolLibreRemat", { mode = Commandes.mode() })
	end
end)
H.boutonUrgence.Activated:Connect(function() if vol.pilote and not vol.descente then remote:FireServer("VolLibreUrgence") end end)
H.boutonVortex.Activated:Connect(function() if vol.pilote and not vol.descente then remote:FireServer("VolLibreVortex") end end)

-- Les boutons Urgence et Vortex s'allument quand ils sont actifs
local function majBoutonsBascule()
	local urgence = exterieur:GetAttribute("VolUrgence") == true
	local vortex = exterieur:GetAttribute("VolVortex") == true
	UI.colorer(H.boutonUrgence, urgence and Color3.fromRGB(220, 70, 30) or Color3.fromRGB(110, 45, 25))
	UI.colorer(H.boutonVortex, vortex and Color3.fromRGB(140, 80, 255) or Color3.fromRGB(70, 40, 130))
	H.boutonUrgence.Text = urgence and "URGENCE  ●" or "URGENCE  (U)"
	H.boutonVortex.Text = vortex and "VORTEX  ●" or "VORTEX  (V)"
	local portesOuvertes = exterieur:GetAttribute("PorteOuverte") == true
	H.boutonPortes.Text = portesOuvertes and "PORTES  ●" or "PORTES  (O)"
	UI.colorer(H.boutonPortes, portesOuvertes and Color3.fromRGB(40, 150, 90) or Color3.fromRGB(60, 70, 95))
	-- En urgence, la vitesse est imposée : le bouton vitesse est grisé
	UI.setDisponible(H.boutonVitesse, not urgence, C.bleu)
	-- Démat / remat en vol ; on ne peut se poser (ou chuter) que matérialisé
	local phase = exterieur:GetAttribute("VolPhase") or "Visible"
	local invisible = phase == "Invisible" or phase == "Remat"
	H.boutonDemat.Visible, H.boutonRemat.Visible = not invisible, invisible
	UI.setDisponible(H.boutonDemat, phase == "Visible", Color3.fromRGB(26, 75, 140))
	UI.setDisponible(H.boutonRemat, phase == "Invisible", Color3.fromRGB(26, 75, 140))
	UI.setDisponible(H.boutonChute, phase == "Visible", Color3.fromRGB(150, 60, 20))
	UI.setDisponible(H.boutonPoser, phase == "Visible", Color3.fromRGB(30, 100, 70))
	local textes = { Visible = "MATÉRIALISÉ", Demat = "DÉMATÉRIALISATION…", Invisible = "INVISIBLE", Remat = "MATÉRIALISATION…" }
	H.phase.Text = textes[phase] or phase
	H.phase.TextColor3 = (phase == "Visible" and C.vert) or (phase == "Invisible" and C.cyan) or C.ambre
	H.nomNiveau.Text = urgence and "URGENCE" or (R.NOMS[vol.niveau] or "")
	H.nomNiveau.TextColor3 = urgence and C.rouge or (vol.niveau == #R.NIVEAUX and C.orange or C.ambre)
end
exterieur:GetAttributeChangedSignal("VolUrgence"):Connect(majBoutonsBascule)
exterieur:GetAttributeChangedSignal("VolVortex"):Connect(majBoutonsBascule)
exterieur:GetAttributeChangedSignal("VolPhase"):Connect(majBoutonsBascule)
exterieur:GetAttributeChangedSignal("PorteOuverte"):Connect(majBoutonsBascule)
H.boutonPortes.Activated:Connect(function()
	if vol.pilote and not vol.descente then remote:FireServer("VolLibrePortes") end
end)
H.boutonChute.Activated:Connect(function()
	if vol.pilote and not vol.descente and H.boutonChute:GetAttribute("Disponible") ~= false then
		UI.confirmer(H.boutonChute, function() remote:FireServer("VolLibreChute", vol.vitesse) end) -- action dangereuse : confirmation
	end
end)
H.boutonPoser.Activated:Connect(function()
	if vol.pilote and not vol.descente and H.boutonPoser:GetAttribute("Disponible") ~= false then remote:FireServer("VolLibrePoser") end
end)

--------------------------------------------------------------------
-- Effets de vol (chez tout le monde) : traînées, particules, aura, moteur
--------------------------------------------------------------------
local function sonAsset(nom)
	local assets = ReplicatedStorage:FindFirstChild("TardisAssets")
	local sons = assets and assets:FindFirstChild("Sons")
	return sons and sons:FindFirstChild(nom)
end

local function creerEffetsVol()
	local base = exterieur.PrimaryPart
	if not base or vol.effetsVol then return end
	local e = {}
	-- Particules temporelles autour de la cabine (discrètes)
	e.particules = creer("ParticleEmitter", { Rate = 0, Lifetime = NumberRange.new(0.5, 1), Speed = NumberRange.new(1, 4),
		SpreadAngle = Vector2.new(180, 180), LightEmission = 1, Color = ColorSequence.new(C.cyan, C.ambre),
		Size = NumberSequence.new(0.3, 0), Transparency = NumberSequence.new(0.3, 1), Parent = base })
	e.particules.Shape = Enum.ParticleEmitterShape.Box
	-- Moteur (optionnel : Sound "Moteur" dans TardisAssets > Sons)
	local moteur = sonAsset("Moteur")
	if moteur then
		e.moteur = moteur:Clone()
		e.moteur.Looped = true
		e.moteur.Volume = 0
		e.moteur.Parent = base
		e.moteur:Play()
	end
	vol.effetsVol = e
end

local function majEffetsVol(vitesse)
	local e = vol.effetsVol
	if not e then return end
	local f = math.clamp(vitesse / R.VITESSE_MAX, 0, 1)
	e.particules.Rate = 3 + 40 * f
	if e.moteur then
		e.moteur.Volume = 0.3 + 0.6 * f
		e.moteur.PlaybackSpeed = 0.8 + 0.6 * f
	end
end

local function detruireEffetsVol()
	local e = vol.effetsVol
	vol.effetsVol = nil
	if not e then return end
	e.particules.Enabled = false
	task.delay(1.2, function() e.particules:Destroy() end)
	if e.moteur then e.moteur:Destroy() end
end

-- Éclair de lumière d'un saut temporel (au départ et à l'arrivée)
local function flashTemporel(position)
	if UI.effetsReduits() then return end
	local boule = creer("Part", { Name = "TardisFlash", Shape = Enum.PartType.Ball, Anchored = true, CanCollide = false,
		CanQuery = false, CanTouch = false, CastShadow = false, Material = Enum.Material.Neon,
		Color = Color3.fromRGB(190, 235, 255), Transparency = 0.1, Size = Vector3.new(2, 2, 2), CFrame = CFrame.new(position),
		Parent = workspace })
	local lumiere = creer("PointLight", { Color = Color3.fromRGB(150, 220, 255), Brightness = 8, Range = 30, Parent = boule })
	local taille = math.max(vol.taille.X, vol.taille.Y, vol.taille.Z) * 2.2
	animer(boule, 0.4, { Size = Vector3.new(taille, taille, taille), Transparency = 1 }, Enum.EasingStyle.Quad)
	animer(lumiere, 0.4, { Brightness = 0 })
	task.delay(0.45, function() boule:Destroy() end)
end

--------------------------------------------------------------------
-- Démat / remat en vol : sons extérieurs et visibilité des effets
--------------------------------------------------------------------
-- Même calcul que TardisEffets : 0 = visible, 1 = invisible
local function alphaVol()
	local phase = exterieur:GetAttribute("VolPhase")
	if phase == "Invisible" or exterieur:GetAttribute("Camouflage") == true then return 1 end
	if phase == "Demat" or phase == "Remat" then
		local ecoule = workspace:GetServerTimeNow() - (exterieur:GetAttribute("VolPhaseDebut") or 0)
		return Config.Alpha(phase, ecoule, Config.modeVolDe(exterieur), UI.effetsReduits())
	end
	return 0
end

exterieur:GetAttributeChangedSignal("VolSaut"):Connect(function()
	if vol.pilote or not exterieur:GetAttribute("VolLibre") then return end -- le pilote a déjà ses éclairs
	vol.sautEnAttente = true
	flashTemporel((exterieur:GetPivot() * CFrame.new(0, vol.taille.Y / 2, 0)).Position)
end)

exterieur:GetAttributeChangedSignal("VolPhase"):Connect(function()
	local phase = exterieur:GetAttribute("VolPhase")
	if phase ~= "Demat" and phase ~= "Remat" then return end
	local base = exterieur.PrimaryPart
	-- Son du mode (urgence, express ou normal), sinon le son normal
	local nomSon = Config.Son(phase, Config.modeVolDe(exterieur))
	local modele = (nomSon and sonAsset(nomSon)) or sonAsset(phase)
	if base and modele then
		local son = modele:Clone()
		-- Portée (V6.9.7) : audible près de la cabine, muet au-delà de Config.PorteeSons.Dehors.Max
		local portee = (Config.PorteeSons or {}).Dehors
		if portee then
			son.RollOffMode = Enum.RollOffMode.InverseTapered
			son.RollOffMinDistance, son.RollOffMaxDistance = portee.Min or 12, portee.Max or 220
		end
		son.Parent = base -- le son suit le TARDIS en vol
		son:Play()
		son.Ended:Connect(function() son:Destroy() end)
	end
end)

--------------------------------------------------------------------
-- Vortex temporel (bouton VORTEX) : un tunnel en grille filaire lumineuse.
-- Étroit autour du TARDIS (la "gorge"), il s'évase derrière lui. La caméra du pilote, placée derrière,
-- se retrouve dans le tunnel et regarde vers la gorge. Les cercles défilent vers le TARDIS et la grille
-- est légèrement torsadée : on a l'impression d'être aspiré dans le vortex.
--------------------------------------------------------------------
local VORTEX = {
	ANNEAUX = 12,          -- cercles le long du tunnel
	POINTS = 20,           -- points par cercle (= lignes longitudinales)
	LONGUEUR = 75,         -- longueur du tunnel derrière le TARDIS (studs)
	EVASEMENT = 1.55,      -- plus grand = le tunnel s'ouvre plus vite
	TORSION = 0.035,       -- torsion de la grille (radians par stud)
	DEFILEMENT = 16,       -- vitesse de défilement des cercles vers le TARDIS (studs/s)
	ROTATION = 0.35,       -- rotation lente de la grille (radians/s)
	EPAISSEUR = 0.14,      -- épaisseur des lignes (studs)
	PRES = Color3.fromRGB(120, 220, 255),  -- couleur près de la gorge
	LOIN = Color3.fromRGB(30, 60, 220),    -- couleur au bout du tunnel
	-- En urgence, le vortex prend les couleurs des flammes
	FEU_PRES = Color3.fromRGB(255, 225, 120),
	FEU_MILIEU = Color3.fromRGB(255, 120, 30),
	FEU_LOIN = Color3.fromRGB(190, 25, 10),
}

local function creerVortex()
	if vol.vortex then return end
	local v = { apparition = 0, rotation = 0, defilement = 0, feu = 0, points = {}, cercles = {}, lignes = {} }
	v.dossier = creer("Folder", { Name = "TardisVortex", Parent = workspace })
	-- Pièce d'ancrage invisible à l'origine : la position de ses Attachments = position dans le monde
	v.ancre = creer("Part", { Name = "Ancre", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
		Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(), Parent = v.dossier })
	v.rayon = math.max(vol.taille.X, vol.taille.Y, vol.taille.Z) * 0.8

	local function ligne(a0, a1)
		return creer("Beam", { Attachment0 = a0, Attachment1 = a1, Width0 = VORTEX.EPAISSEUR, Width1 = VORTEX.EPAISSEUR,
			FaceCamera = true, LightEmission = 1, LightInfluence = 0, Segments = 1, Transparency = NumberSequence.new(1),
			Color = ColorSequence.new(VORTEX.PRES), Parent = v.ancre })
	end
	for a = 1, VORTEX.ANNEAUX do
		v.points[a] = {}
		for k = 1, VORTEX.POINTS do
			v.points[a][k] = creer("Attachment", { Parent = v.ancre })
		end
	end
	for a = 1, VORTEX.ANNEAUX do
		v.cercles[a] = {}
		for k = 1, VORTEX.POINTS do
			v.cercles[a][k] = ligne(v.points[a][k], v.points[a][k % VORTEX.POINTS + 1]) -- tour du cercle
		end
		if a < VORTEX.ANNEAUX then
			v.lignes[a] = {}
			for k = 1, VORTEX.POINTS do
				v.lignes[a][k] = ligne(v.points[a][k], v.points[a + 1][k]) -- vers le cercle suivant
			end
		end
	end
	-- Éclairs : 3 arcs en zigzag réutilisés (8 points, 7 segments chacun)
	v.eclairs = {}
	for e = 1, 3 do
		local eclair = { points = {}, segments = {}, vie = 0 }
		for i = 1, 8 do
			eclair.points[i] = creer("Attachment", { Parent = v.ancre })
		end
		for i = 1, 7 do
			eclair.segments[i] = creer("Beam", { Attachment0 = eclair.points[i], Attachment1 = eclair.points[i + 1],
				Width0 = 0.3, Width1 = 0.3, FaceCamera = true, LightEmission = 1, LightInfluence = 0, Segments = 1,
				Transparency = NumberSequence.new(1), Color = ColorSequence.new(C.blanc), Parent = v.ancre })
		end
		v.eclairs[e] = eclair
	end
	v.prochainEclair = 0
	vol.vortex = v
end

local function detruireVortex()
	local v = vol.vortex
	vol.vortex = nil
	if v then v.dossier:Destroy() end
end

local function majVortex(dt, centre, direction, t, tube)
	local v = vol.vortex
	if not v then return end
	local forme = UI.pref("formeVortex", "grille") -- grille, anneaux ou spirale
	v.apparition = math.min(v.apparition + dt * 1.2, 1) -- le tunnel apparaît en fondu
	-- Passage progressif aux couleurs des flammes quand l'urgence est active
	local urgence = exterieur:GetAttribute("VolUrgence") == true
	v.feu += ((urgence and 1 or 0) - v.feu) * math.min(dt * 2.5, 1)
	-- En urgence, le tunnel tourne et défile plus vite, comme un brasier
	-- Le tunnel réagit à la vitesse : plus long, plus rapide quand le TARDIS accélère
	local fractionVitesse = math.clamp(direction.Magnitude / R.VITESSE_MAX, 0, 1)
	v.vitesse = (v.vitesse or 0) + (fractionVitesse - (v.vitesse or 0)) * math.min(dt * 2, 1) -- lissé
	local longueur = tube and VORTEX.LONGUEUR * 1.6 or VORTEX.LONGUEUR * (0.6 + 0.8 * v.vitesse)
	local allure = 0.5 + 1.5 * v.vitesse
	v.rotation += dt * VORTEX.ROTATION * (1 + 1.5 * v.feu) * allure
	local espacement = longueur / VORTEX.ANNEAUX
	v.defilement = (v.defilement + dt * VORTEX.DEFILEMENT * (1 + v.feu) * allure / espacement) % 1

	-- Le tunnel s'étire derrière le TARDIS, dans le sens du déplacement.
	-- En tube (dans le ciel), son axe est fixé une fois pour toutes : le TARDIS tourne dedans, pas le tube.
	local axe
	if tube then
		v.axeTube = v.axeTube or Vector3.new(0, 0, -1)
		axe = v.axeTube
	else
		axe = direction.Magnitude > 2 and direction.Unit or exterieur:GetPivot().LookVector
	end
	local base = CFrame.lookAt(centre, centre + axe)

	local transparences, couleurs = {}, {}
	for a = 1, VORTEX.ANNEAUX do
		-- Les cercles avancent vers la gorge ; arrivés au bout, ils repartent de l'arrière (sans coupure visible)
		local distance = ((a - 1) + (1 - v.defilement)) * espacement
		local progression = math.clamp(distance / longueur, 0, 1)
		-- Tube (dans le ciel) : rayon constant, tunnel centré sur le TARDIS, devant et derrière
		local rayon = tube and v.rayon * 1.6 or v.rayon * (1 + VORTEX.EVASEMENT * progression ^ 1.6 * longueur / v.rayon * 0.35)
		local cercle = base * CFrame.new(0, 0, tube and (distance - longueur / 2) or distance)
		local torsion = v.rotation + VORTEX.TORSION * distance * (forme == "spirale" and 4 or 1)
		for k, point in v.points[a] do
			local angle = (k - 1) / VORTEX.POINTS * math.pi * 2 + torsion
			local position = cercle * Vector3.new(math.cos(angle) * rayon, math.sin(angle) * rayon, 0)
			-- Tempête : au-delà de la vitesse max, le tunnel devient instable (la grille tremble)
			if v.vitesse > 0.95 then
				position += Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 2.5 * (v.vitesse - 0.95) * 20
			end
			point.Position = position
		end
		-- Lumineux près de la gorge, s'efface au bout ; la gorge "respire" légèrement
		local respiration = 0.06 * math.sin(t * 3 - distance * 0.15)
		transparences[a] = 1 - (1 - math.clamp(0.1 + 0.9 * progression ^ 1.3 + respiration, 0, 1)) * v.apparition
		local couleurBleue = VORTEX.PRES:Lerp(VORTEX.LOIN, progression)
		-- Flammes : jaune près de la gorge, orange au milieu, rouge sombre au bout, avec un léger vacillement
		local couleurFeu = progression < 0.5 and VORTEX.FEU_PRES:Lerp(VORTEX.FEU_MILIEU, progression * 2)
			or VORTEX.FEU_MILIEU:Lerp(VORTEX.FEU_LOIN, (progression - 0.5) * 2)
		local vacillement = 0.12 * v.feu * math.abs(math.sin(t * 9 + a * 1.7))
		couleurs[a] = couleurBleue:Lerp(couleurFeu, v.feu):Lerp(Color3.fromRGB(255, 240, 200), vacillement)
	end

	-- Éclairs : de temps en temps, un arc en zigzag entre deux points de la grille
	if t >= v.prochainEclair and v.apparition > 0.5 then
		v.prochainEclair = t + 0.35 + math.random() * 1.1
		for _, eclair in v.eclairs do
			if eclair.vie <= 0 then
				local a = math.random(1, VORTEX.ANNEAUX - 3)
				local k = math.random(1, VORTEX.POINTS)
				local a2 = a + math.random(1, 3)
				local k2 = (k + math.random(-4, 4) - 1) % VORTEX.POINTS + 1
				local depart, arrivee = v.points[a][k].Position, v.points[a2][k2].Position
				for i, point in eclair.points do
					local f = (i - 1) / (#eclair.points - 1)
					local zigzag = (i == 1 or i == #eclair.points) and Vector3.zero
						or Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 2.4
					point.Position = depart:Lerp(arrivee, f) + zigzag
				end
				eclair.vie = 0.22
				local couleur = C.blanc:Lerp(Color3.fromRGB(150, 230, 255), 0.4):Lerp(Color3.fromRGB(255, 190, 90), v.feu)
				for _, segment in eclair.segments do segment.Color = ColorSequence.new(couleur) end
				break
			end
		end
	end
	for _, eclair in v.eclairs do
		if eclair.vie > 0 then
			eclair.vie -= dt
			local transparence = NumberSequence.new(1 - math.clamp(eclair.vie / 0.22, 0, 1) * v.apparition)
			for _, segment in eclair.segments do segment.Transparency = transparence end
		end
	end

	-- Couleurs et transparences : une seule séquence par cercle (et par tronçon de lignes)
	for a = 1, VORTEX.ANNEAUX do
		local transparenceCercle = NumberSequence.new(transparences[a])
		local couleurCercle = ColorSequence.new(couleurs[a])
		-- Formes : "anneaux" = cercles seuls, "spirale" = lignes seules (très torsadées), "grille" = les deux
		for _, beam in v.cercles[a] do
			beam.Transparency = forme == "spirale" and NumberSequence.new(1) or transparenceCercle
			beam.Color = couleurCercle
		end
		if v.lignes[a] then
			local transparenceLigne = NumberSequence.new(transparences[a], transparences[a + 1])
			local couleurLigne = ColorSequence.new(couleurs[a], couleurs[a + 1])
			for _, beam in v.lignes[a] do
				beam.Transparency = forme == "anneaux" and NumberSequence.new(1) or transparenceLigne
				beam.Color = couleurLigne
			end
		end
	end
end

--------------------------------------------------------------------
-- Urgence (bouton URGENCE) : le TARDIS fonce et prend feu
--------------------------------------------------------------------
local function majUrgence(actif, t)
	local base = exterieur.PrimaryPart
	if actif and not vol.effetsUrgence and base then
		local e = {}
		e.feu = creer("Fire", { Size = 10, Heat = 18, Color = Color3.fromRGB(255, 140, 40),
			SecondaryColor = Color3.fromRGB(255, 50, 20), Parent = base })
		e.feuHaut = creer("Fire", { Size = 7, Heat = 12, Color = Color3.fromRGB(255, 170, 60),
			SecondaryColor = Color3.fromRGB(255, 70, 20), Parent = base })
		e.fumee = creer("Smoke", { Color = Color3.fromRGB(35, 30, 28), Opacity = 0.45, RiseVelocity = 6, Size = 9, Parent = base })
		e.lumiere = creer("PointLight", { Color = Color3.fromRGB(255, 120, 40), Brightness = 3, Range = 24, Shadows = false, Parent = base })
		e.chaleur = creer("Highlight", { FillColor = Color3.fromRGB(255, 100, 30), OutlineColor = Color3.fromRGB(255, 200, 90),
			FillTransparency = 0.75, OutlineTransparency = 0.4, DepthMode = Enum.HighlightDepthMode.Occluded, Parent = exterieur })
		vol.effetsUrgence = e
	elseif not actif and vol.effetsUrgence then
		local e = vol.effetsUrgence
		vol.effetsUrgence = nil
		for _, objet in e do
			if objet:IsA("Fire") or objet:IsA("Smoke") then
				objet.Enabled = false
				task.delay(2, function() objet:Destroy() end)
			else
				objet:Destroy()
			end
		end
	end
	local e = vol.effetsUrgence
	if e then
		-- Les flammes vacillent, la lueur pulse
		e.feu.Size = 9 + 3 * math.abs(math.sin(t * 7))
		e.feuHaut.Size = 6 + 2 * math.abs(math.sin(t * 9 + 1))
		e.lumiere.Brightness = 2.5 + 1.5 * math.abs(math.sin(t * 11))
		e.chaleur.FillTransparency = 0.7 + 0.12 * math.sin(t * 6)
	end
end

--------------------------------------------------------------------
-- Effets de chute : rentrée atmosphérique, impact
--------------------------------------------------------------------
local function demarrerEffetsChute(chute)
	local base = exterieur.PrimaryPart
	if not base or vol.effetsChute then return end
	local e = {}
	if chute then
		e.feu = creer("Fire", { Size = 2, Heat = 25, Color = Color3.fromRGB(255, 150, 50),
			SecondaryColor = Color3.fromRGB(255, 60, 20), Parent = base })
		e.fumee = creer("Smoke", { Color = Color3.fromRGB(70, 62, 55), Opacity = 0.2, RiseVelocity = 10, Size = 4, Parent = base })
		e.lumiere = creer("PointLight", { Color = Color3.fromRGB(255, 130, 40), Brightness = 4, Range = 0, Shadows = false, Parent = base })
		e.chaleur = creer("Highlight", { FillColor = Color3.fromRGB(255, 110, 30), OutlineColor = Color3.fromRGB(255, 220, 120),
			FillTransparency = 1, OutlineTransparency = 1, DepthMode = Enum.HighlightDepthMode.Occluded, Parent = exterieur })
		local son = sonAsset("Chute")
		if son then
			e.son = son:Clone()
			e.son.Parent = base
			e.son:Play()
		end
	end
	vol.effetsChute = e
end

local function majEffetsChute(t)
	local e = vol.effetsChute
	if not e or not e.feu then return end
	e.feu.Size = 2 + 16 * t
	e.fumee.Size = 4 + 12 * t
	e.fumee.Opacity = 0.15 + 0.25 * t
	e.lumiere.Range = 6 + 30 * t
	e.chaleur.FillTransparency = 1 - 0.55 * t
	e.chaleur.OutlineTransparency = 1 - 0.75 * t
end

local function arreterEffetsChute()
	local e = vol.effetsChute
	vol.effetsChute = nil
	if not e then return end
	for _, objet in e do
		if typeof(objet) == "Instance" then
			if objet:IsA("Fire") or objet:IsA("Smoke") then
				objet.Enabled = false
				task.delay(2, function() objet:Destroy() end)
			else
				objet:Destroy()
			end
		end
	end
end

local secousse = 0
local function impact(position, fort)
	local anneau = creer("Part", { Shape = Enum.PartType.Cylinder, Anchored = true, CanCollide = false, CanQuery = false,
		CanTouch = false, Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 190, 110), Transparency = 0.2,
		Size = Vector3.new(0.4, 4, 4), CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2), Parent = workspace })
	local taille = fort and 70 or 22
	animer(anneau, fort and 0.8 or 0.6, { Size = Vector3.new(0.2, taille, taille), Transparency = 1 }, Enum.EasingStyle.Quad)
	task.delay(1, function() anneau:Destroy() end)

	local support = creer("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1,
		Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(position), Parent = workspace })
	local poussiere = creer("Smoke", { Color = Color3.fromRGB(150, 140, 125), Opacity = fort and 0.6 or 0.3, RiseVelocity = 6,
		Size = fort and 20 or 8, Parent = support })
	task.delay(fort and 0.7 or 0.4, function() poussiere.Enabled = false end)
	task.delay(4, function() support:Destroy() end)

	if fort then
		local son = sonAsset("Impact")
		if son then
			local copie = son:Clone()
			copie.Parent = support
			copie:Play()
		end
		local distance = (camera.CFrame.Position - position).Magnitude
		secousse = math.max(secousse, math.clamp(1 - distance / 120, 0, 1))
	end
end

-- Secousses de caméra (impact, et légère vibration du pilote en Turbo)
RunService:BindToRenderStep("TardisImpact", Enum.RenderPriority.Camera.Value + 2, function(dt)
	local vibration = 0
	if vol.pilote and not vol.descente then
		vibration = math.clamp((vol.vitesse.Magnitude - R.VITESSE_MAX * 0.7) / (R.VITESSE_MAX * 0.3), 0, 1) * 0.12
		if exterieur:GetAttribute("VolUrgence") then vibration += 0.3 end
	end
	local total = secousse + vibration
	if total <= 0 then return end
	local force = total * 0.03 * (UI.effetsReduits() and 0.3 or 1)
	camera.CFrame = camera.CFrame * CFrame.Angles((math.random() - 0.5) * force, (math.random() - 0.5) * force, (math.random() - 0.5) * force)
	secousse = math.max(0, secousse - dt * 1.6)
end)

--------------------------------------------------------------------
-- Entrer / sortir du pilotage
--------------------------------------------------------------------
local function entrerPilotage()
	if vol.pilote then return end
	vol.pilote = true
	local pivot = exterieur:GetPivot()
	vol.centre = (pivot * CFrame.new(0, vol.taille.Y / 2, 0)).Position
	vol.altitudeDepart = pivot.Position.Y
	vol.vitesse = Vector3.zero
	local _, yaw = pivot:ToEulerAnglesYXZ()
	vol.yaw, vol.rotation, vol.inclinaison = yaw, 0, CFrame.new()
	vol.niveau = math.clamp(reglages.NiveauDepart or 2, 1, #R.NIVEAUX)
	afficherNiveau()

	local racine = joueur.Character and joueur.Character:FindFirstChild("HumanoidRootPart")
	if racine then
		vol.ancrage = racine
		racine.Anchored = true -- le personnage reste figé là où il est
	end
	vol.cibleCamera = creer("Part", { Name = "TardisCibleCamera", Anchored = true, CanCollide = false, CanQuery = false,
		CanTouch = false, Transparency = 1, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(vol.centre), Parent = workspace })
	camera.CameraType = Enum.CameraType.Custom
	camera.CameraSubject = vol.cibleCamera
	vol.champOrigine = camera.FieldOfView
	vol.teinte = creer("ColorCorrectionEffect", { Name = "TardisVortexTeinte", Parent = game:GetService("Lighting") })
	H.gui.Enabled = true
	majBoutonsBascule()
end

local function sortirPilotage()
	if not vol.pilote then return end
	vol.pilote = false
	if vol.teinte then vol.teinte:Destroy() end
	vol.teinte = nil
	H.gui.Enabled = false
	if vol.ancrage and vol.ancrage.Parent then vol.ancrage.Anchored = false end
	vol.ancrage = nil
	local humanoid = joueur.Character and joueur.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then camera.CameraSubject = humanoid end
	if vol.cibleCamera then vol.cibleCamera:Destroy() end
	vol.cibleCamera = nil
	if vol.viseur then vol.viseur:Destroy() end
	vol.viseur = nil
	vol.tonneau, vol.tonneauActif = 0, false
	if vol.siege then remote:FireServer("SiegePose", { pose = 0 }) end
	vol.stationnaire, vol.planeur, vol.capFixe, vol.cible, vol.atterrissage, vol.siege = false, false, nil, nil, nil, nil
	vol.gMax = 0
	animer(camera, 0.4, { FieldOfView = vol.champOrigine })
end

local sautTemporel -- défini plus bas, après deplacer (il en a besoin)

--------------------------------------------------------------------
-- Commandes clavier
--------------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, traite)
	if traite or not vol.pilote or vol.descente then return end
	if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
		local maintenant = os.clock()
		if maintenant - vol.derniereEspace < R.DOUBLE_ESPACE then
			remote:FireServer("VolLibreChute", vol.vitesse)
			vol.derniereEspace = 0
		else
			vol.derniereEspace = maintenant
		end
	elseif input.KeyCode == UI.touche("volPoser", Enum.KeyCode.G) then
		remote:FireServer("VolLibrePoser")
	elseif input.KeyCode == UI.touche("volVitesse", R.TOUCHE_VITESSE) or input.KeyCode == Enum.KeyCode.ButtonY then
		if not exterieur:GetAttribute("VolUrgence") then vitesseSuivante() end
	elseif input.KeyCode == UI.touche("volTonneau", R.TOUCHE_TONNEAU) then
		if tonneau then tonneau() end
	elseif input.KeyCode == UI.touche("volFrein", R.TOUCHE_FREIN) then
		if freiner then freiner() end
	elseif input.KeyCode == UI.touche("volTracteur", R.TOUCHE_TRACTEUR) then
		remote:FireServer("Tracteur")
	elseif input.KeyCode == UI.touche("volCamouflage", R.TOUCHE_CAMOUFLAGE) then
		remote:FireServer("VolLibreCamouflage")
	elseif input.KeyCode == UI.touche("volStationnaire", R.TOUCHE_STATIONNAIRE) then
		if basculerStationnaire then basculerStationnaire() end
	elseif input.KeyCode == UI.touche("volSiege", R.TOUCHE_SIEGE) then
		if basculerSiege and vol.stationnaire then basculerSiege() end
	elseif input.KeyCode == UI.touche("volBoost", R.TOUCHE_BOOST) then
		if boost then boost() end
	elseif input.KeyCode == UI.touche("volAtterrir", R.TOUCHE_ATTERRIR) then
		if atterrirIci then atterrirIci() end
	elseif input.KeyCode == UI.touche("volPlaneur", R.TOUCHE_PLANEUR) then
		if basculerPlaneur then basculerPlaneur() end
	elseif input.KeyCode == UI.touche("volCible", R.TOUCHE_CIBLE) then
		if basculerCible then basculerCible() end
	elseif input.KeyCode == UI.touche("volPrecision", R.TOUCHE_PRECISION) then
		remote:FireServer("VolLibrePrecision")
	elseif input.KeyCode == UI.touche("volCap", R.TOUCHE_CAP) then
		if basculerCap then basculerCap() end
	elseif input.KeyCode == UI.touche("volSaut", R.TOUCHE_SAUT) then
		task.defer(function() sautTemporel() end)
	elseif input.KeyCode == UI.touche("volPortes", R.TOUCHE_PORTES) then
		remote:FireServer("VolLibrePortes")
	elseif input.KeyCode == UI.touche("volDemat", Enum.KeyCode.X) then
		local phase = exterieur:GetAttribute("VolPhase") or "Visible"
		if phase == "Visible" then
			remote:FireServer("VolLibreDemat", { mode = Commandes.mode() })
		elseif phase == "Invisible" then
			remote:FireServer("VolLibreRemat", { mode = Commandes.mode() })
		end
	elseif input.KeyCode == UI.touche("volUrgence", R.TOUCHE_URGENCE) then
		remote:FireServer("VolLibreUrgence")
	elseif input.KeyCode == UI.touche("volVortex", R.TOUCHE_VORTEX) or input.KeyCode == Enum.KeyCode.ButtonX then
		if vol.siege then
			vol.poseSiege = vol.poseSiege % 4 + 1
			remote:FireServer("SiegePose", { pose = vol.poseSiege })
			majBoutonsModes()
		else
			remote:FireServer("VolLibreVortex")
		end
	end
end)

--------------------------------------------------------------------
-- Pilotage
--------------------------------------------------------------------
-- Déplacement avec collisions : la boîte du TARDIS glisse le long des obstacles
local function deplacer(centre, deplacement)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclusions()
	params.RespectCanCollide = true
	local boite = vol.taille * 0.92
	local reste = deplacement
	for _ = 1, 3 do
		if reste.Magnitude < 0.001 then break end
		local resultat = workspace:Blockcast(CFrame.new(centre) * CFrame.Angles(0, vol.yaw, 0), boite, reste, params)
		if not resultat then
			centre += reste
			break
		end
		local direction = reste.Unit
		local avance = math.max(resultat.Distance - 0.05, 0)
		centre += direction * avance
		local normale = resultat.Normal
		local restant = reste - direction * avance
		reste = restant - normale * restant:Dot(normale) -- glisse le long de la surface
		local contre = vol.vitesse:Dot(normale)
		if contre < 0 then
			if -contre > 35 and os.clock() - vol.dernierChoc > 0.6 then
				-- Choc violent : rebond, étincelles pour tout le monde, secousse
				vol.dernierChoc = os.clock()
				vol.vitesse -= normale * contre * 1.6 -- une partie de la vitesse repart dans l'autre sens
				remote:FireServer("VolLibreChoc", resultat.Position)
				secousse = math.max(secousse, 0.9)
				camera.FieldOfView -= 6
			else
				vol.vitesse -= normale * contre -- on perd la vitesse qui va dans le mur
			end
		end
	end
	return centre
end

-- Saut temporel : un bond vers l'avant, dans la direction de la caméra (collisions respectées)
sautTemporel = function()
	if not vol.pilote or vol.descente or os.clock() - vol.dernierSaut < R.SAUT_RECHARGE then return end
	vol.dernierSaut = os.clock()
	remote:FireServer("VolLibreSaut") -- le serveur autorise le bond (sinon la position serait refusée)
	local depart = vol.centre
	local arrivee = deplacer(vol.centre, camera.CFrame.LookVector * R.SAUT_DISTANCE)
	local plafond = vol.altitudeDepart + R.ALTITUDE_MAX
	if arrivee.Y > plafond then arrivee = Vector3.new(arrivee.X, plafond, arrivee.Z) end
	vol.centre = arrivee
	vol.dernierEnvoi = 0 -- la nouvelle position part tout de suite
	flashTemporel(depart)
	flashTemporel(arrivee)
	-- Petit choc à l'écran : champ de vision qui s'ouvre d'un coup
	camera.FieldOfView += 18
	secousse = math.max(secousse, 0.35)
end
H.boutonSaut.Activated:Connect(sautTemporel)

local function hauteurSol(centre)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclusions()
	params.RespectCanCollide = true
	local resultat = workspace:Raycast(centre, Vector3.new(0, -2000, 0), params)
	return resultat and resultat.Position.Y or nil
end

local function pivotDepuis(centre)
	-- Inclinaison, rotation et tonneau autour du centre du TARDIS, puis retour à la Racine (en bas)
	return CFrame.new(centre) * vol.inclinaison * CFrame.Angles(0, vol.yaw, 0) * CFrame.Angles(0, 0, vol.tonneau)
		* CFrame.Angles(0, vol.rotation, 0) * CFrame.new(0, -vol.taille.Y / 2, 0)
end

-- Tonneau et freinage d'urgence
tonneau = function()
	if vol.pilote and not vol.descente and not vol.tonneauActif then vol.tonneauActif = true end
end
freiner = function()
	if not vol.pilote or vol.descente then return end
	if exterieur:GetAttribute("VolUrgence") then return end -- en urgence, rien ne l'arrête
	vol.vitesse = Vector3.zero
	secousse = math.max(secousse, 0.5)
	camera.FieldOfView -= 8
	-- Fumée de freinage
	if exterieur.PrimaryPart then
		local fumee = creer("Smoke", { Color = Color3.fromRGB(150, 150, 150), Opacity = 0.4, RiseVelocity = 2, Size = 5, Parent = exterieur.PrimaryPart })
		task.delay(0.5, function() fumee.Enabled = false end)
		task.delay(3, function() fumee:Destroy() end)
	end
end

basculerStationnaire = function()
	if not vol.pilote or vol.descente then return end
	vol.stationnaire = not vol.stationnaire
	vol.altitudeFixe = vol.centre.Y
	if not vol.stationnaire and vol.siege then basculerSiege() end
	majBoutonsModes()
end
basculerSiege = function()
	if not vol.pilote or vol.descente or not vol.ancrage then return end
	if vol.siege then
		vol.siege = nil
		remote:FireServer("SiegePose", { pose = 0 })
		vol.ancrage.CFrame = vol.siege_retour or vol.ancrage.CFrame
		majBoutonsModes()
		return
	end
	if not vol.stationnaire then return end
	vol.siege = true
	vol.poseSiege = 1
	vol.siege_retour = vol.ancrage.CFrame
	if not exterieur:GetAttribute("PorteOuverte") then remote:FireServer("VolLibrePortes") end
	remote:FireServer("SiegePose", { pose = 1 })
	majBoutonsModes()
end
boost = function()
	if not vol.pilote or vol.descente or os.clock() - vol.dernierBoost < R.BOOST_RECHARGE then return end
	vol.dernierBoost = os.clock()
	camera.FieldOfView += 10
	secousse = math.max(secousse, 0.3)
end
atterrirIci = function()
	if not vol.pilote or vol.descente then return end
	if vol.atterrissage then
		vol.atterrissage = nil
		majBoutonsModes()
		return
	end
	-- Le point visé par la caméra, au sol
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclusions(vol.viseur)
	params.RespectCanCollide = true
	local resultat = workspace:Raycast(camera.CFrame.Position, camera.CFrame.LookVector * 600, params)
	if not resultat then return end
	local sol = workspace:Raycast(resultat.Position + Vector3.new(0, 2, 0), Vector3.new(0, -3000, 0), params)
	local cible = sol and sol.Position or resultat.Position
	vol.atterrissage = { cible = cible, dernierePosition = vol.centre, dernierProgres = os.clock() }
	vol.stationnaire, vol.planeur, vol.cible = false, false, nil
	majBoutonsModes()
end
basculerPlaneur = function()
	if not vol.pilote or vol.descente then return end
	vol.planeur = not vol.planeur
	if vol.planeur then vol.stationnaire = false end
	majBoutonsModes()
end
basculerCible = function()
	if not vol.pilote or vol.descente then return end
	if vol.cible then
		vol.cible = nil
		majBoutonsModes()
		return
	end
	-- La cible : le joueur ou le véhicule le plus proche du centre de l'écran, à moins de 200 studs
	local meilleur, meilleurScore = nil, 0.92
	local candidats = {}
	for _, autre in Players:GetPlayers() do
		local racine = autre ~= joueur and autre.Character and autre.Character:FindFirstChild("HumanoidRootPart")
		if racine then table.insert(candidats, { objet = racine, nom = autre.DisplayName }) end
	end
	for _, objet in workspace:GetDescendants() do
		if objet:IsA("VehicleSeat") and objet.Occupant then
			table.insert(candidats, { objet = objet.AssemblyRootPart or objet, nom = "véhicule" })
		end
	end
	for _, c in candidats do
		local vers = c.objet.Position - camera.CFrame.Position
		if vers.Magnitude < 200 then
			local score = vers.Unit:Dot(camera.CFrame.LookVector)
			if score > meilleurScore then meilleur, meilleurScore = c, score end
		end
	end
	vol.cible = meilleur
	if vol.cible then
		vol.stationnaire, vol.planeur, vol.atterrissage = false, false, nil
	else
		H.infosSecondaires.Text = "Aucune cible : vise un autre joueur ou un véhicule occupé (moins de 200 studs)"
	end
	majBoutonsModes()
end
basculerCap = function()
	if not vol.pilote or vol.descente then return end
	if vol.capFixe then
		vol.capFixe = nil
	else
		local regard = camera.CFrame.LookVector * Vector3.new(1, 0, 1)
		vol.capFixe = regard.Magnitude > 0.1 and regard.Unit or Vector3.new(0, 0, -1)
	end
	majBoutonsModes()
end

-- Viseur d'atterrissage : un cercle au sol montre où il se poserait (vert : libre, rouge : collision)
local function majViseur(arrivee, chute)
	if not vol.viseur then
		vol.viseur = creer("Part", { Name = "TardisViseur", Shape = Enum.PartType.Cylinder, Anchored = true, CanCollide = false, CanQuery = false,
			CanTouch = false, CastShadow = false, Material = Enum.Material.Neon, Color = C.vert, Transparency = 0.5,
			Size = Vector3.new(0.1, 1, 1), Parent = workspace })
	end
	local diametre = math.max(vol.taille.X, vol.taille.Z) * 1.4
	vol.viseur.Size = Vector3.new(0.1, diametre, diametre)
	local sol = arrivee.Position - Vector3.new(0, (exterieur.PrimaryPart and exterieur.PrimaryPart.Size.Y / 2 or 0) - 0.08, 0)
	vol.viseur.CFrame = CFrame.new(sol) * arrivee.Rotation * CFrame.Angles(0, 0, math.pi / 2)
	vol.viseur.Color = chute and C.rouge or C.vert
	vol.viseur.Transparency = 0.4 + 0.2 * math.sin(os.clock() * 6)
end

local function piloter(dt, t)
	-- Direction : là où regarde la caméra (en 3D), plus les déplacements latéraux
	local direction = Vector3.zero
	local ctrl = controles()
	if ctrl then
		local mouvement = ctrl:GetMoveVector()
		direction = camera.CFrame.RightVector * mouvement.X + camera.CFrame.LookVector * -mouvement.Z
		if direction.Magnitude > 1 then direction = direction.Unit end
	end
	local vitesseCible = R.NIVEAUX[vol.niveau] or 50
	local urgence = exterieur:GetAttribute("VolUrgence") == true
	local precision = exterieur:GetAttribute("VolPrecision") == true
	-- Cap fixe : la direction "avant" ne suit plus la caméra
	if vol.capFixe and ctrl then
		local mouvement = ctrl:GetMoveVector()
		local droite = vol.capFixe:Cross(Vector3.yAxis)
		direction = droite * mouvement.X + vol.capFixe * -mouvement.Z
		if direction.Magnitude > 1 then direction = direction.Unit end
	end
	-- Boost : accélération brève
	if os.clock() - vol.dernierBoost < R.BOOST_DUREE then vitesseCible *= 2.2 end
	-- Précision : demi-vitesse, pas de rotation, aucune collision
	if precision then vitesseCible *= 0.5 end
	-- Verrouillage de cible : rester au-dessus et en arrière du joueur ou du véhicule suivi
	if vol.cible then
		local objet = vol.cible.objet
		if not objet or not objet.Parent then
			vol.cible = nil
			majBoutonsModes()
		else
			local regard = objet.CFrame.LookVector * Vector3.new(1, 0, 1)
			regard = regard.Magnitude > 0.1 and regard.Unit or Vector3.new(0, 0, -1)
			local voulu = objet.Position - regard * 14 + Vector3.new(0, 16, 0)
			local ecart = voulu - vol.centre
			direction = ecart.Magnitude > 0.5 and ecart.Unit * math.clamp(ecart.Magnitude / 12, 0, 1) or Vector3.zero
			-- Évitement : si un obstacle est devant, on monte
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = exclusions(objet.Parent)
			params.RespectCanCollide = true
			if direction.Magnitude > 0.1 and workspace:Raycast(vol.centre, direction.Unit * 18, params) then
				direction = (direction + Vector3.new(0, 1.5, 0)).Unit
			end
		end
	end
	-- Atterrir ici : il rejoint le point visé en descendant progressivement ; en urgence il fonce et glisse à l'arrivée
	if vol.atterrissage then
		local a = vol.atterrissage
		local horizontal = (a.cible - vol.centre) * Vector3.new(1, 0, 1)
		local distance = horizontal.Magnitude
		if urgence then
			if distance < 18 and not a.glisseEnvoyee then
				a.glisseEnvoyee = true
				remote:FireServer("VolLibreGlisse", vol.vitesse)
			end
			local voulu = Vector3.new(a.cible.X, a.cible.Y + vol.taille.Y / 2 + math.clamp(distance * 0.25, 2, 30), a.cible.Z)
			direction = (voulu - vol.centre).Unit
			vitesseCible = R.VITESSE_URGENCE
		else
			local hauteurVoulue = a.cible.Y + vol.taille.Y / 2 + math.clamp(distance * 0.5, 0.5, 40)
			local voulu = Vector3.new(a.cible.X, hauteurVoulue, a.cible.Z)
			local ecart = voulu - vol.centre
			direction = ecart.Magnitude > 0.3 and ecart.Unit or Vector3.zero
			vitesseCible = math.min(vitesseCible, math.max(ecart.Magnitude * 1.2, 6))
			if distance < 2.5 and vol.centre.Y - vol.taille.Y / 2 - a.cible.Y < 2 then
				vol.atterrissage = nil
				majBoutonsModes()
				remote:FireServer("VolLibrePoser")
			end
			-- Chemin bloqué (aucun progrès pendant 2 s) : démat en vol puis remat au point visé
			if (vol.centre - a.dernierePosition).Magnitude > 0.5 then a.dernierePosition, a.dernierProgres = vol.centre, t
			elseif t - a.dernierProgres > 2 and not a.teleEnvoyee then
				a.teleEnvoyee = true
				task.spawn(function()
					remote:FireServer("VolLibreDemat", { mode = Commandes.mode() })
					local attente = 0
					while exterieur:GetAttribute("VolPhase") ~= "Invisible" and attente < 40 do task.wait(0.5) attente += 0.5 end
					remote:FireServer("VolLibreTeleAtterrir", a.cible)
					vol.atterrissage = nil
					majBoutonsModes()
				end)
			end
		end
	end
	-- Planeur : moteur coupé, il plane doucement jusqu'au sol
	if vol.planeur then
		direction = Vector3.zero
		vol.vitesse = Vector3.new(vol.vitesse.X * (1 - dt * 0.15), -9, vol.vitesse.Z * (1 - dt * 0.15))
	end
	-- Stationnaire : altitude figée, il tourne très lentement sur lui-même
	if vol.stationnaire then
		direction = Vector3.new(direction.X, 0, direction.Z)
	end
	if urgence then
		-- Urgence : il fonce à toute vitesse et part dans tous les sens (une dérive qui change sans cesse)
		vitesseCible = R.VITESSE_URGENCE
		local tt = os.clock() * 0.9
		local bruit = Vector3.new(math.noise(tt, 0.3, 7.1), math.noise(0.7, tt, 3.3) * 0.6, math.noise(5.9, 2.1, tt)) * 2.4
		vol.bruitUrgence = vol.bruitUrgence:Lerp(bruit, math.min(dt * 3, 1))
		direction = (camera.CFrame.LookVector + vol.bruitUrgence * R.ERRATIQUE).Unit
	end
	-- Vent en altitude : plus on monte, plus il dérive
	local altitudeRelative = math.max(vol.centre.Y - vol.altitudeDepart, 0)
	if R.VENT > 0 and altitudeRelative > 20 then
		local tv = os.clock() * 0.15
		local vent = Vector3.new(math.noise(tv, 1.5, 0), 0, math.noise(0, 2.5, tv)) * R.VENT * math.min(altitudeRelative / 150, 1) * 12
		vol.centre += vent * dt
	end

	-- Inertie : il accélère et freine comme un objet lourd
	local reactivite = urgence and 4 or (direction.Magnitude > 0.05 and 2.2 or 1.6)
	if not vol.planeur then vol.vitesse = vol.vitesse:Lerp(direction * vitesseCible, 1 - math.exp(-reactivite * dt)) end
	if vol.stationnaire then vol.vitesse = Vector3.new(vol.vitesse.X, 0, vol.vitesse.Z) end
	local centre = precision and (vol.centre + vol.vitesse * dt) or deplacer(vol.centre, vol.vitesse * dt) -- précision : il traverse tout
	if vol.stationnaire then centre = Vector3.new(centre.X, vol.altitudeFixe, centre.Z) end
	-- Planeur : au sol, il se pose en douceur
	if vol.planeur then
		local sol = hauteurSol(centre)
		if sol and centre.Y - vol.taille.Y / 2 - sol < 1 then
			vol.planeur = false
			majBoutonsModes()
			remote:FireServer("VolLibrePoser")
		end
	end
	-- Tempête temporelle : une rafale dévie le TARDIS
	local tempete = exterieur:GetAttribute("Tempete")
	if tempete then
		local x, y, z, debut, duree = string.match(tempete, "^([%-%d%.]+)\t([%-%d%.]+)\t([%-%d%.]+)\t([%d%.]+)\t(%d+)")
		if x and workspace:GetServerTimeNow() - tonumber(debut) < tonumber(duree) then
			local rafale = Vector3.new(tonumber(x), tonumber(y), tonumber(z)) * (18 + 10 * math.noise(t * 2, 0.5, 0.5))
			centre += rafale * dt
			secousse = math.max(secousse, 0.4)
		end
	end
	-- Compteur de G
	local acceleration = (vol.vitesse - vol.vitessePrecedente) / math.max(dt, 0.001)
	vol.vitessePrecedente = vol.vitesse
	local g = acceleration.Magnitude / 196.2
	vol.gMax = math.max(vol.gMax * (1 - dt * 0.02), g)

	-- Plafond
	local plafond = vol.altitudeDepart + R.ALTITUDE_MAX
	if centre.Y > plafond then
		centre = Vector3.new(centre.X, plafond, centre.Z)
		vol.vitesse = Vector3.new(vol.vitesse.X, math.min(vol.vitesse.Y, 0), vol.vitesse.Z)
	end
	vol.centre = centre

	-- Orientation : suit la caméra, et il tourne sur lui-même d'autant plus vite qu'il va vite
	local _, yawCamera = camera.CFrame:ToEulerAnglesYXZ()
	vol.yaw = angleVers(vol.yaw, yawCamera, 1 - math.exp(-3 * dt))
	local fraction = math.clamp(vol.vitesse.Magnitude / R.VITESSE_MAX, 0, 1)
	if vol.stationnaire then
		vol.rotation = (vol.rotation + dt * 0.08) % (2 * math.pi) -- très très lentement
	elseif not precision then
		vol.rotation = (vol.rotation + dt * R.ROTATION_MAX * fraction * (urgence and 2.5 or 1)) % (2 * math.pi)
	end
	if vol.capFixe then
		local capVoulu = math.atan2(-vol.capFixe.X, -vol.capFixe.Z)
		vol.yaw = angleVers(vol.yaw, capVoulu, 1 - math.exp(-3 * dt))
	end

	-- Inclinaison dans la direction du mouvement horizontal (à droite = penche à droite, etc.)
	local horizontal = vol.vitesse * Vector3.new(1, 0, 1)
	local cibleInclinaison = CFrame.new()
	if horizontal.Magnitude > 0.5 then
		local axe = Vector3.yAxis:Cross(horizontal.Unit)
		local angle = math.clamp(horizontal.Magnitude / math.max(vitesseCible, 1), 0, 1) * R.INCLINAISON
		cibleInclinaison = CFrame.fromAxisAngle(axe, angle)
	end
	vol.inclinaison = vol.inclinaison:Lerp(cibleInclinaison, 1 - math.exp(-4 * dt))

	-- Flottement léger, plus présent à l'arrêt
	local flottement = Vector3.new(0, math.sin(t * 1.6) * 0.18 * (1 - fraction), 0)
	-- Tonneau : un tour complet en 0,8 s
	if vol.tonneauActif then
		vol.tonneau += dt / 0.8 * math.pi * 2
		if vol.tonneau >= math.pi * 2 then vol.tonneau, vol.tonneauActif = 0, false end
	end
	local pivot = pivotDepuis(vol.centre + flottement)
	exterieur:PivotTo(pivot)
	if vol.cibleCamera then vol.cibleCamera.CFrame = CFrame.new(vol.centre) end
	if vol.viseur then vol.viseur:Destroy() vol.viseur = nil end

	-- Envoi au serveur (~15 fois par seconde)
	if t - vol.dernierEnvoi >= 1 / R.ENVOIS_PAR_SECONDE then
		vol.dernierEnvoi = t
		remote:FireServer("VolLibre", pivot)
	end

	-- Sensations : champ de vision, lignes de vitesse
	local bonusVortex = exterieur:GetAttribute("VolVortex") and 8 or 0
	camera.FieldOfView += (vol.champOrigine + R.CHAMP_VISION * fraction + bonusVortex - camera.FieldOfView) * (1 - math.exp(-3 * dt))
	for _, ligne in H.lignes do
		local scintillement = 0.5 + 0.5 * math.sin(t * 13 + ligne.phase)
		ligne.cadre.BackgroundTransparency = 1 - math.clamp((fraction - 0.25) * 1.1, 0, 0.75) * scintillement
	end

	-- Tableau de bord
	local vitesseActuelle = vol.vitesse.Magnitude
	H.vitesse.Text = tostring(math.floor(vitesseActuelle))
	H.infosSecondaires.Text = string.format("G %.1f  ·  max %.1f  ·  %s", g, vol.gMax,
		os.clock() - vol.dernierBoost < R.BOOST_RECHARGE and string.format("boost dans %d s", R.BOOST_RECHARGE - (os.clock() - vol.dernierBoost)) or "boost prêt")
	-- Siège extérieur : le joueur assis suit le TARDIS
	if vol.siege and vol.ancrage then
		local pivotTardis = exterieur:GetPivot()
		local racineHalf = exterieur.PrimaryPart and exterieur.PrimaryPart.Size.Y / 2 or 0.5
		local decalages = {
			CFrame.new(0, racineHalf + 2.6, -vol.taille.Z / 2 - 0.6) * CFrame.Angles(0, math.pi, 0),          -- assis, jambes dans le vide
			CFrame.new(0, racineHalf + 2.6, -vol.taille.Z / 2 - 0.6) * CFrame.Angles(0, math.pi, 0),          -- une jambe remontée
			CFrame.new(0, racineHalf - 1.6, -vol.taille.Z / 2 - 0.9) * CFrame.Angles(0, math.pi, 0),          -- accroché au bas, deux mains
			CFrame.new(0.6, racineHalf - 1.4, -vol.taille.Z / 2 - 0.9) * CFrame.Angles(0, math.pi, 0.25),     -- accroché d'une main
		}
		vol.ancrage.CFrame = pivotTardis * decalages[vol.poseSiege]
	end
	H.jauge.Size = UDim2.fromScale(fraction, 1)
	local sol = hauteurSol(vol.centre)
	H.altitude.Text = sol and string.format("%.0f", vol.centre.Y - vol.taille.Y / 2 - sol) or "—"
	local cap = (math.deg(-yawCamera) + 360) % 360
	H.cap.Text = string.format("%03d°", cap)
	for _, repere in H.reperes do
		local ecart = (repere.degre - cap + 540) % 360 - 180
		repere.cadre.Position = UDim2.new(0.5, ecart * 2.2, 0.6, 0)
		repere.cadre.Visible = math.abs(ecart) < 100
	end
end

--------------------------------------------------------------------
-- Descente (chute ou atterrissage), animée chez tout le monde
--------------------------------------------------------------------
local function animerDescente()
	local depart = exterieur:GetAttribute("DescenteDepart")
	local arrivee = exterieur:GetAttribute("DescenteArrivee")
	local debut = exterieur:GetAttribute("DescenteDebut")
	local duree = exterieur:GetAttribute("DescenteDuree")
	if typeof(depart) ~= "CFrame" or typeof(arrivee) ~= "CFrame" or not debut or not duree then return end
	local mode = exterieur:GetAttribute("DescenteMode")
	local chute = mode == "Chute"

	if not vol.descente then
		vol.descente = { impact = false }
		demarrerEffetsChute(chute)
	end

	local maintenant = workspace:GetServerTimeNow()
	local t = math.clamp((maintenant - debut) / duree, 0, 1)
	local progression = chute and t * t or 1 - (1 - t) ^ 3
	local position = depart.Position:Lerp(arrivee.Position, progression)
	-- Rebond : après l'impact, un saut de quelques studs
	local rebond = exterieur:GetAttribute("DescenteRebond")
	if chute and rebond then
		local tChute = (duree - 0.9) / duree
		if t < tChute then
			local tt = t / tChute
			position = depart.Position:Lerp(arrivee.Position, tt * tt)
		else
			local tr = (t - tChute) / (1 - tChute)
			position = arrivee.Position + Vector3.new(0, 4 * rebond * tr * (1 - tr), 0)
			if not vol.descente.impactRebond then
				vol.descente.impactRebond = true
				impact(arrivee.Position - Vector3.new(0, (exterieur.PrimaryPart and exterieur.PrimaryPart.Size.Y / 2) or 0, 0), true)
			end
		end
	end
	-- Glissade (urgence) : descente rapide jusqu'au sol, puis il glisse en freinant, étincelles et fumée
	local toucher = exterieur:GetAttribute("DescenteGlisse")
	if mode == "Glisse" and typeof(toucher) == "CFrame" then
		local dureeDescente = exterieur:GetAttribute("DescenteGlisseDuree") or 1
		local temps = t * duree
		if temps < dureeDescente then
			local td = temps / dureeDescente
			position = depart.Position:Lerp(toucher.Position, td * td)
		else
			local tg = math.clamp((temps - dureeDescente) / math.max(duree - dureeDescente, 0.1), 0, 1)
			position = toucher.Position:Lerp(arrivee.Position, 1 - (1 - tg) ^ 2)
			if not vol.descente.glisseEffets and exterieur.PrimaryPart then
				vol.descente.glisseEffets = true
				impact(toucher.Position - Vector3.new(0, exterieur.PrimaryPart.Size.Y / 2, 0), false)
				local etincelles = creer("ParticleEmitter", { Color = ColorSequence.new(Color3.fromRGB(255, 230, 150), Color3.fromRGB(255, 120, 30)), LightEmission = 1,
					Size = NumberSequence.new(0.25, 0), Speed = NumberRange.new(10, 25), Lifetime = NumberRange.new(0.3, 0.6), SpreadAngle = Vector2.new(60, 60),
					Acceleration = Vector3.new(0, -30, 0), Rate = 120, Parent = exterieur.PrimaryPart })
				local fumee = creer("Smoke", { Color = Color3.fromRGB(120, 120, 120), Opacity = 0.35, RiseVelocity = 3, Size = 4, Parent = exterieur.PrimaryPart })
				task.delay(duree - dureeDescente, function() etincelles.Enabled = false fumee.Enabled = false end)
				task.delay(duree - dureeDescente + 2, function() etincelles:Destroy() fumee:Destroy() end)
				secousse = math.max(secousse, 0.6)
			end
		end
	end
	local vitesseInitiale = exterieur:GetAttribute("DescenteVitesse")
	if chute and typeof(vitesseInitiale) == "Vector3" then
		-- Chute avec élan : trajectoire balistique, recalée sur le point d'impact calculé par le serveur
		local gravite = exterieur:GetAttribute("DescenteGravite") or 70
		local temps = t * duree
		local balistique = depart.Position + vitesseInitiale * temps + Vector3.new(0, -0.5 * gravite * temps * temps, 0)
		position = balistique:Lerp(arrivee.Position, math.clamp((t - 0.85) / 0.15, 0, 1))
	end
	if vol.pilote then majViseur(arrivee, chute) end
	local rotation = depart.Rotation:Lerp(arrivee.Rotation, chute and math.min(t * 1.5, 1) or progression)

	-- Tangage très léger pendant la chute
	local tangage = CFrame.new()
	if chute and t < 1 then
		local force = (1 - t * 0.5) * math.rad(1.2)
		tangage = CFrame.Angles(math.sin(maintenant * 23) * force, 0, math.cos(maintenant * 19) * force)
		position += Vector3.new(math.sin(maintenant * 37) * 0.04, 0, math.cos(maintenant * 31) * 0.04)
	end
	exterieur:PivotTo(CFrame.new(position) * rotation * tangage)
	majEffetsChute(t)
	if vol.cibleCamera then vol.cibleCamera.CFrame = CFrame.new(position + Vector3.new(0, vol.taille.Y / 2, 0)) end
	if vol.pilote then
		camera.FieldOfView += (vol.champOrigine + (chute and 12 * t or 0) - camera.FieldOfView) * 0.1
		for _, ligne in H.lignes do
			ligne.cadre.BackgroundTransparency = chute and (1 - 0.6 * t) or 1
		end
	end

	if t >= 1 and not vol.descente.impact then
		vol.descente.impact = true
		impact(arrivee.Position - Vector3.new(0, (exterieur.PrimaryPart and exterieur.PrimaryPart.Size.Y / 2) or 0, 0), chute)
		arreterEffetsChute()
	end
end

--------------------------------------------------------------------
-- Boucle principale
--------------------------------------------------------------------
RunService.RenderStepped:Connect(function(dt)
	local idPilote = exterieur:GetAttribute("VolLibre")
	local t = os.clock()

	-- Vortex temporel du voyage classique : un long tube autour du TARDIS qui tourne dans le ciel
	if not idPilote then
		if exterieur:GetAttribute("Ciel") == true then
			if not vol.vortex then
				vol.taille = exterieur:GetExtentsSize()
				creerVortex()
			end
			local centre = (exterieur:GetPivot() * CFrame.new(0, vol.taille.Y / 2, 0)).Position
			majVortex(dt, centre, exterieur:GetPivot().LookVector * 60, t, true)
			return
		elseif vol.vortex and not vol.suivait then
			detruireVortex()
		end
	end

	if not idPilote then
		if vol.suivait then
			-- Fin du vol : on se recale exactement sur la position décidée par le serveur
			vol.suivait = false
			vol.affiche, vol.dernierePosition, vol.descente = nil, nil, nil
			vol.vitesseVecteur = Vector3.zero
			arreterEffetsChute()
			detruireEffetsVol()
			detruireVortex()
			majUrgence(false, t)
			if vol.precisionAppliquee then
				vol.precisionAppliquee = false
				if vol.echelleBase then exterieur:ScaleTo(vol.echelleBase) end
			end
			vol.echelleBase = nil
			sortirPilotage()
			local depot = exterieur:GetAttribute("DepotCF")
			if typeof(depot) == "CFrame" then exterieur:PivotTo(depot) end
		end
		return
	end

	if not vol.suivait then
		vol.suivait = true
		vol.taille = exterieur:GetExtentsSize()
		creerEffetsVol()
	end
	if idPilote == joueur.UserId and not vol.pilote then
		entrerPilotage()
	end

	-- Vol de précision : le TARDIS rapetisse à 30 % (sur chaque client), puis reprend sa taille
	local precisionVoulue = exterieur:GetAttribute("VolPrecision") == true
	if precisionVoulue ~= (vol.precisionAppliquee == true) then
		vol.precisionAppliquee = precisionVoulue
		local base = vol.echelleBase or exterieur:GetScale()
		vol.echelleBase = base
		exterieur:ScaleTo(precisionVoulue and base * 0.3 or base)
		vol.taille = exterieur:GetExtentsSize()
	end

	if exterieur:GetAttribute("DescenteDebut") then
		animerDescente()
		majEffetsVol(0)
		vol.vitesseVecteur = Vector3.zero
	elseif vol.pilote then
		piloter(dt, t)
		majEffetsVol(vol.vitesse.Magnitude)
		vol.vitesseVecteur = vol.vitesse
	else
		-- Autres joueurs : suivi fluide, et vitesse estimée pour les effets
		local cible = exterieur:GetAttribute("VolLibreCF")
		if typeof(cible) == "CFrame" then
			if vol.sautEnAttente and vol.affiche and (cible.Position - vol.affiche.Position).Magnitude > R.SAUT_DISTANCE * 0.5 then
				-- La position du saut est arrivée : téléportation nette + éclair à l'arrivée
				vol.sautEnAttente = false
				vol.affiche = cible
				flashTemporel((cible * CFrame.new(0, vol.taille.Y / 2, 0)).Position)
			end
			vol.affiche = vol.affiche and vol.affiche:Lerp(cible, 1 - math.exp(-10 * dt)) or cible
			exterieur:PivotTo(vol.affiche)
			if vol.dernierePosition and dt > 0 then
				local deplacement = (vol.affiche.Position - vol.dernierePosition) / dt
				vol.vitesseVecteur = vol.vitesseVecteur:Lerp(deplacement, math.min(dt * 5, 1))
				vol.vitesseVue = vol.vitesseVecteur.Magnitude
			end
			vol.dernierePosition = vol.affiche.Position
		end
		majEffetsVol(vol.vitesseVue)
	end

	-- Turbulences : le passage rapide du TARDIS repousse les joueurs proches et secoue leur caméra
	if not vol.pilote and R.TURB_FORCE > 0 and not exterieur:GetAttribute("DescenteDebut") then
		local racine = joueur.Character and joueur.Character:FindFirstChild("HumanoidRootPart")
		if racine and not racine.Anchored then
			local centreTardis = (exterieur:GetPivot() * CFrame.new(0, vol.taille.Y / 2, 0)).Position
			local ecart = racine.Position - centreTardis
			local distance = ecart.Magnitude
			local fractionVitesse = math.clamp((vol.vitesseVue - 15) / (R.VITESSE_MAX - 15), 0, 1)
			if distance < R.TURB_RAYON and distance > 0.5 and fractionVitesse > 0 then
				local proximite = 1 - distance / R.TURB_RAYON
				local poussee = (ecart.Unit + Vector3.new(0, 0.35, 0)) * proximite * fractionVitesse * 90 * R.TURB_FORCE
				racine.AssemblyLinearVelocity += poussee * dt * 8
				secousse = math.max(secousse, proximite * fractionVitesse * 0.6)
			end
		end
	end

	-- Vortex et urgence, chez tout le monde (cachés quand le TARDIS est dématérialisé)
	local enDescente = exterieur:GetAttribute("DescenteDebut") ~= nil
	local invisibilite = alphaVol()
	if vol.effetsVol then
		vol.effetsVol.particules.Enabled = invisibilite < 0.5
	end
	if exterieur:GetAttribute("VolVortex") and not enDescente and invisibilite < 0.95 then
		creerVortex()
		local centre = (exterieur:GetPivot() * CFrame.new(0, vol.taille.Y / 2, 0)).Position
		majVortex(dt, centre, vol.vitesseVecteur, t)
	elseif vol.vortex then
		detruireVortex()
	end
	majUrgence(exterieur:GetAttribute("VolUrgence") == true and not enDescente and invisibilite < 0.5, t)
	if vol.teinte then
		local actif = exterieur:GetAttribute("VolVortex") == true
		local teinteVortex = exterieur:GetAttribute("VolUrgence") and Color3.fromRGB(255, 215, 185) or Color3.fromRGB(205, 200, 255)
		vol.teinte.TintColor = vol.teinte.TintColor:Lerp(actif and teinteVortex or Color3.new(1, 1, 1), math.min(dt * 3, 1))
		vol.teinte.Saturation += ((actif and 0.25 or 0) - vol.teinte.Saturation) * math.min(dt * 3, 1)
	end
end)

-- Taille de l'interface selon l'écran
local function majEchelle()
	local echelle = math.clamp(camera.ViewportSize.X / 760, 0.6, 1) * UI.tailleInterface()
	H.echelleTableau.Scale = echelle * 1.25 -- panneau d'informations un peu plus grand
	H.echelleBoussole.Scale = echelle
	H.echelleBoutons.Scale = math.clamp(camera.ViewportSize.Y / 760, 0.6, 1) * UI.tailleInterface() * 1.1
end
camera:GetPropertyChangedSignal("ViewportSize"):Connect(majEchelle)
UI.prefsChangees.Event:Connect(function(cle) if cle == "taille" then majEchelle() end end)
majEchelle()
afficherNiveau()