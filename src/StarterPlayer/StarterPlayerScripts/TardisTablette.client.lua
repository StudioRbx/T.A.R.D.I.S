-- StarterPlayer > StarterPlayerScripts > TardisTablette (LocalScript)
-- TABLETTE DE BORD AVANCÉE du TARDIS : un grand écran façon tablette, avec tout en même temps.
--   Statut (anneau de progression), télémétrie, flux temporel · Navigation complète (lieux, joueurs,
--   coordonnées avec fantôme) · Scanner, occupants, journal · Systèmes, taille, voyants, statistiques.
-- Visible seulement pour les pilotes autorisés. Toutes les commandes sont revérifiées par le serveur.
-- Touche Y (ou le bouton "Tablette" du menu classique) : ouvrir / fermer.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")

local Config = require(ReplicatedStorage:WaitForChild("TardisConfig"))
local UI = require(ReplicatedStorage:WaitForChild("TardisUI"))
local E = Config.Etats
local C = UI.C
local creer, texte, animer = UI.creer, UI.texte, UI.animer

local joueur = Players.LocalPlayer
local camera = workspace.CurrentCamera
local def, monRole = Config.attendreMonTardis(joueur) -- le TARDIS de ce joueur (pilote ou technicien)
local exterieur, interieur = Config.modeles(def)
local remote = ReplicatedStorage:WaitForChild(Config.canal(def, "TardisCommande"))
-- Commandes de voyage et protocoles partagés avec le menu rapide
local Commandes = require(ReplicatedStorage:WaitForChild("TardisCommandes")).demarrer(exterieur, remote)

-- Réglages
local R = {
	TOUCHE = Enum.KeyCode.Y,     -- ouvrir / fermer
	LARGEUR = 1280,              -- taille de dessin de la tablette (mise à l'échelle selon l'écran)
	HAUTEUR = 760,
	PORTEE = 150,                -- rayon du scanner (studs)
	MAX_JOURNAL = 60,
	SEGMENTS = 48,               -- segments de l'anneau de statut
	BARRES = 34,                 -- barres du flux temporel
}

-- Tous les éléments d'interface (W) et l'état de la tablette (S), rangés dans deux tables
-- pour rester loin de la limite de 200 variables locales de Luau.
local W = {}
local V = {} -- volet latéral (outils, réglages, aide), construit plus bas
local LARGEUR_VOLET = 454 -- largeur du volet + son écart
local S = {
	ouvert = false,
	mode = "lieux",          -- "lieux", "joueurs", "coord"
	choix = nil,             -- { type = "lieu" | "joueur" | "position", ... }
	figer = false,
	positionPerso = nil,
	tailleChoisie = 1,
	glisseTaille = false,
	placement = nil,
	elementsListe = {},
	boutonsChoix = {},
	voyages = 0,
	tempsVortex = 0,
	debutVol = nil,
	debutSession = os.clock(),
	lignesJournal = {},
	compteurJournal = 0,
	points = {},
	modeScanner = "radar",   -- "radar" ou "carte"
	sentinelle = true,       -- alerte quand quelqu'un s'approche du TARDIS posé
	proches = {},            -- joueurs déjà signalés par la sentinelle
	marqueursCarte = {},     -- destinations affichées sur la mini-carte
	categories = {},         -- [nom de destination] = index de catégorie (serveur)
	pointsCarte = {},        -- joueurs affichés sur la mini-carte
	porteeCarte = 300,
}
local seuilPortes = Config.TailleOuverturePortes or 1
local TAILLE_MIN = Config.TailleMin or 0.25

--------------------------------------------------------------------
-- Petites fabriques
--------------------------------------------------------------------
-- Panneau de la tablette : cadre, barre de titre avec icône, zone de contenu
local panneaux = {}
local PANNEAUX_WIDGETS = { ["STATUT"] = "statut", ["TÉLÉMÉTRIE"] = "telemetrie", ["FLUX TEMPOREL"] = "flux", ["COMMANDES RAPIDES"] = "flux", ["NAVIGATION"] = "navigation",
	["SCANNER"] = "scanner", ["OCCUPANTS DE LA SALLE"] = "occupants", ["JOURNAL DE BORD"] = "journal" }
W.panneauxListe = {} -- { cadre, x, y, hauteur, widget } : pour réorganiser les colonnes selon les widgets affichés
local function panneau(parent, x, y, largeur, hauteur, titre, icone, couleur)
	couleur = couleur or C.ambre
	local cadre = creer("Frame", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(largeur, hauteur),
		BackgroundColor3 = C.panneau, BackgroundTransparency = 0.15, Parent = parent },
	{ UI.coin(14), UI.contour(C.bleu, 1, 0.35) })
	if PANNEAUX_WIDGETS[titre] then
		table.insert(W.panneauxListe, { cadre = cadre, x = x, y = y, hauteur = hauteur, widget = PANNEAUX_WIDGETS[titre] })
	end
	creer("UIScale", { Parent = cadre })
	-- Coin décoratif lumineux
	creer("Frame", { Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(26, 3), BackgroundColor3 = couleur,
		BorderSizePixel = 0, Parent = cadre }, { UI.coin(2) })
	creer("Frame", { Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(3, 18), BackgroundColor3 = couleur,
		BorderSizePixel = 0, Parent = cadre }, { UI.coin(2) })
	texte({ Text = icone .. "  " .. titre, Font = UI.POLICE_GRAS, TextSize = 12, TextColor3 = couleur,
		Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 16), Parent = cadre })
	local contenu = creer("Frame", { Position = UDim2.fromOffset(12, 32), Size = UDim2.new(1, -24, 1, -42),
		BackgroundTransparency = 1, Parent = cadre })
	table.insert(panneaux, cadre)
	return cadre, contenu
end

-- Ligne "clé : valeur" de la télémétrie
local function ligneInfo(parent, cle, ordre)
	local ligne = creer("Frame", { Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, LayoutOrder = ordre, Parent = parent })
	texte({ Text = cle, TextSize = 12, TextColor3 = C.texte2, Size = UDim2.new(0.42, 0, 1, 0), Parent = ligne })
	local valeur = texte({ Text = "—", Font = UI.POLICE_CODE, TextSize = 13, TextColor3 = C.cyan,
		TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromScale(0.42, 0), Size = UDim2.new(0.58, 0, 1, 0), Parent = ligne })
	creer("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = C.bleu, BackgroundTransparency = 0.6, BorderSizePixel = 0, Parent = ligne })
	return valeur
end

--------------------------------------------------------------------
-- Écran, voile, flou, cadre de la tablette
--------------------------------------------------------------------
W.gui = creer("ScreenGui", { Name = "TardisTablette", ResetOnSpawn = false, Enabled = false, DisplayOrder = 20,
	IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = joueur:WaitForChild("PlayerGui") })

-- Le voile assombrit le jeu et bloque les clics vers le monde derrière ;
-- "Modal" libère la souris même en vue à la première personne. Il ne ferme PAS la tablette.
W.voile = creer("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Modal = true, Visible = false, Parent = W.gui })

W.flou = creer("BlurEffect", { Name = "TardisTabletteFlou", Size = 0, Enabled = false, Parent = Lighting })

W.tablette = creer("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(R.LARGEUR, R.HAUTEUR), BackgroundColor3 = C.fond, Visible = false,
	Parent = W.gui }, { UI.coin(34), UI.contour(C.panneauClair, 2, 0.2) })
W.echelle = creer("UIScale", { Parent = W.tablette })
creer("UIGradient", { Rotation = 35, Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(150, 160, 180)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(230, 235, 245)),
}), Parent = W.tablette })

-- Détails du cadre : caméra frontale et boutons latéraux
creer("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(7, 7),
	BackgroundColor3 = Color3.fromRGB(20, 30, 50), Parent = W.tablette }, { UI.coin(99), UI.contour(Color3.fromRGB(50, 70, 110), 1, 0) })
for _, x in { 120, 170 } do
	creer("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(36, 4),
		BackgroundColor3 = Color3.fromRGB(40, 48, 66), Parent = W.tablette }, { UI.coin(2) })
end

-- L'écran lui-même
W.ecran = creer("Frame", { Position = UDim2.fromOffset(16, 16), Size = UDim2.new(1, -32, 1, -32),
	BackgroundColor3 = C.ecran, ClipsDescendants = true, Parent = W.tablette }, { UI.coin(22) })
creer("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(120, 140, 175)),
	Parent = W.ecran })

-- Décor de fond : grille légère + grand cadran qui tourne lentement
do
	local grille = creer("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = W.ecran })
	for i = 1, 15 do
		creer("Frame", { Position = UDim2.new(i / 16, 0, 0, 0), Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = C.cyan,
			BackgroundTransparency = 0.94, BorderSizePixel = 0, Parent = grille })
	end
	for i = 1, 9 do
		creer("Frame", { Position = UDim2.new(0, 0, i / 10, 0), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = C.cyan,
			BackgroundTransparency = 0.94, BorderSizePixel = 0, Parent = grille })
	end
	W.cadranFond = creer("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromOffset(900, 900), BackgroundTransparency = 1, Parent = W.ecran },
	{ UI.coin(999), UI.contour(C.cyan, 1, 0.9) })
	for k = 0, 59 do
		local angle = k / 60 * math.pi * 2
		creer("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Rotation = math.deg(angle) + 90,
			Position = UDim2.new(0.5 + math.cos(angle) * 0.5, 0, 0.5 + math.sin(angle) * 0.5, 0),
			Size = UDim2.fromOffset(k % 5 == 0 and 22 or 10, 2), BackgroundColor3 = C.cyan,
			BackgroundTransparency = k % 5 == 0 and 0.8 or 0.9, BorderSizePixel = 0, Parent = W.cadranFond })
	end
end

-- Ligne de balayage (animation d'ouverture)
W.balayageEcran = creer("Frame", { Position = UDim2.new(0, 0, 0, -4), Size = UDim2.new(1, 0, 0, 3),
	BackgroundColor3 = C.blanc, BorderSizePixel = 0, ZIndex = 50, Parent = W.ecran })
creer("UIGradient", { Color = ColorSequence.new(C.cyan, C.cyan),
	Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(1, 1) }), Parent = W.balayageEcran })

--------------------------------------------------------------------
-- Barre du haut
--------------------------------------------------------------------
do
	local barreHaut = creer("Frame", { Size = UDim2.new(1, 0, 0, 58), BackgroundColor3 = C.blanc, Parent = W.ecran },
	{ UI.coin(22) })
	W.vortexHaut = creer("UIGradient", { Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(8, 22, 60)),
		ColorSequenceKeypoint.new(0.4, Color3.fromRGB(22, 64, 140)),
		ColorSequenceKeypoint.new(0.7, Color3.fromRGB(10, 70, 110)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(6, 16, 44)),
	}), Parent = barreHaut })
	-- Le bas de la barre reste droit (on recouvre ses coins arrondis du bas)
	W.vortexHautBas = creer("UIGradient", { Color = W.vortexHaut.Color })
	creer("Frame", { Position = UDim2.new(0, 0, 1, -22), Size = UDim2.new(1, 0, 0, 22), BackgroundColor3 = C.blanc,
		BorderSizePixel = 0, Parent = barreHaut }, { W.vortexHautBas })
	-- Le haut de la tablette suit le thème
	local function majEntete()
		W.vortexHaut.Color = UI.degradeEntete()
		W.vortexHautBas.Color = UI.degradeEntete()
	end
	UI.prefsChangees.Event:Connect(function(cle) if cle == "theme" then majEntete() end end)
	majEntete()
	creer("Frame", { Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = C.ambre,
		BackgroundTransparency = 0.3, BorderSizePixel = 0, Parent = barreHaut })

	-- Emblème
	local embleme = creer("Frame", { Position = UDim2.fromOffset(14, 7), Size = UDim2.fromOffset(44, 44),
		BackgroundTransparency = 1, Parent = barreHaut })
	W.anneaux = {}
	for i, info in { { 44, C.ambre }, { 31, C.cyan }, { 18, C.ambre } } do
		local anneau = creer("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(info[1], info[1]), BackgroundTransparency = 1, Parent = embleme },
		{ UI.coin(99), UI.contour(info[2], 1.5, 0.15) })
		for k = 0, i do
			local angle = (k / (i + 1)) * math.pi * 2
			creer("Frame", { AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5 + math.cos(angle) * 0.5, 0, 0.5 + math.sin(angle) * 0.5, 0),
				Size = UDim2.fromOffset(4, 4), BackgroundColor3 = info[2], Parent = anneau }, { UI.coin(99) })
		end
		table.insert(W.anneaux, anneau)
	end
	creer("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(7, 7),
		BackgroundColor3 = C.ambre, Parent = embleme }, { UI.coin(99) })

	texte({ Text = "T.A.R.D.I.S.", Font = UI.POLICE_TITRE, TextSize = 20, Position = UDim2.fromOffset(70, 8),
		Size = UDim2.fromOffset(260, 24), Parent = barreHaut })
	texte({ Text = "TABLETTE DE BORD  ·  V" .. tostring(Config.Version or "?"), Font = UI.POLICE_CODE, TextSize = 11,
		TextColor3 = C.texte2, Position = UDim2.fromOffset(70, 33), Size = UDim2.fromOffset(260, 14), Parent = barreHaut })

	-- Pastille d'état au centre
	W.pastille = creer("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(0, 32), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = C.fond,
		BackgroundTransparency = 0.25, Parent = barreHaut },
	{ UI.coin(99), creer("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 16) }), UI.pile(10, true) })
	W.pastille:FindFirstChildOfClass("UIListLayout").VerticalAlignment = Enum.VerticalAlignment.Center
	W.contourPastille = UI.contour(C.vert, 1.5, 0.3)
	W.contourPastille.Parent = W.pastille
	W.pointPastille = creer("Frame", { Size = UDim2.fromOffset(10, 10), BackgroundColor3 = C.vert, LayoutOrder = 1,
		Parent = W.pastille }, { UI.coin(99) })
	W.textePastille = texte({ Text = "Posé", Font = UI.POLICE_GRAS, TextSize = 14, Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2, Parent = W.pastille })
	W.lieuPastille = texte({ Text = "", TextSize = 12, TextColor3 = C.texte2, Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 3, Parent = W.pastille })

	-- Droite : horloge, jauge d'énergie, fermeture
	W.horloge = texte({ Text = "00:00:00", Font = UI.POLICE_CODE, TextSize = 16, TextColor3 = C.cyan,
		TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -150, 0.5, 0),
		Size = UDim2.fromOffset(100, 20), Parent = barreHaut })
	local jauge = creer("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -66, 0.5, 0),
		Size = UDim2.fromOffset(62, 20), BackgroundTransparency = 1, Parent = barreHaut }, { UI.pile(3, true) })
	W.jauge = {}
	for i = 1, 5 do
		W.jauge[i] = creer("Frame", { Size = UDim2.fromOffset(9, 20), BackgroundColor3 = C.vert, LayoutOrder = i,
			Parent = jauge }, { UI.coin(2) })
	end
	W.fermer = creer("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(38, 38), BackgroundColor3 = Color3.fromRGB(90, 30, 40), Text = "×", Font = UI.POLICE_GRAS,
		TextSize = 24, TextColor3 = C.texte, Parent = barreHaut }, { UI.coin(10), UI.contour(C.rouge, 1, 0.4) })
	W.fermer:SetAttribute("CouleurBase", Color3.fromRGB(90, 30, 40))
	UI.rendreVivant(W.fermer)
	local function boutonBarre(txt, x, largeur)
		local b = creer("TextButton", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, x, 0.5, 0), Size = UDim2.fromOffset(largeur, 38),
			BackgroundColor3 = C.panneauClair, Text = txt, Font = UI.POLICE_GRAS, TextSize = 13, TextColor3 = C.texte, Parent = barreHaut },
		{ UI.coin(10), UI.contour(C.cyan, 1, 0.5) })
		b:SetAttribute("CouleurBase", C.panneauClair)
		UI.rendreVivant(b)
		return b
	end
	W.btnOutils = boutonBarre("◆  OUTILS", 236, 96)
	W.btnReglages = boutonBarre("RÉGLAGES", 340, 100)
	W.btnAide = boutonBarre("?", 448, 38)
end

-- TARDIS détruit : voile gris foncé sur toute la tablette, avec "TARDIS DÉTRUIT" en diagonale
W.voileDetruit = creer("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(28, 30, 36), BackgroundTransparency = 0.06,
	Visible = false, ZIndex = 40, Parent = W.tablette }, { UI.coin(26) })
texte({ Text = "TARDIS DÉTRUIT", Font = UI.POLICE_TITRE, TextSize = 90, TextColor3 = Color3.fromRGB(255, 70, 70), TextXAlignment = Enum.TextXAlignment.Center,
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1400, 120), Rotation = -22, ZIndex = 41, Parent = W.voileDetruit })
texte({ Text = "Reconstitution automatique dans quelques minutes.", TextSize = 16, TextColor3 = C.texte2, TextXAlignment = Enum.TextXAlignment.Center,
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 110), Size = UDim2.fromOffset(600, 24), ZIndex = 41, Parent = W.voileDetruit })
W.voileAvarie = creer("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(40, 32, 20), BackgroundTransparency = 0.15,
	Visible = false, ZIndex = 40, Parent = W.tablette }, { UI.coin(26) })
texte({ Text = "AVARIE", Font = UI.POLICE_TITRE, TextSize = 90, TextColor3 = C.ambre, TextXAlignment = Enum.TextXAlignment.Center,
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1400, 120), Rotation = -22, ZIndex = 41, Parent = W.voileAvarie })
texte({ Text = "Intégrité à 0 % : portes ouvertes, tension coupée. Réparez le rotor (maintenir E).", TextSize = 16, TextColor3 = C.texte,
	TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 110), Size = UDim2.fromOffset(800, 24),
	ZIndex = 41, Parent = W.voileAvarie })
local function majVoiles()
	W.voileDetruit.Visible = exterieur:GetAttribute("Detruit") == true
	W.voileAvarie.Visible = exterieur:GetAttribute("Avarie") == true and not W.voileDetruit.Visible
end
exterieur:GetAttributeChangedSignal("Detruit"):Connect(majVoiles)
exterieur:GetAttributeChangedSignal("Avarie"):Connect(majVoiles)
majVoiles()

-- Balise de détresse : alerte cliquable (bouton "Y aller" = démat + remat automatique à 2 studs du joueur)
W.alerteBalise = creer("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 340, 0, 170), Size = UDim2.fromOffset(300, 0),
	AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.fond, BackgroundTransparency = 0.1, Visible = false, ZIndex = 30,
	Parent = W.gui }, { UI.coin(12), UI.contour(C.rouge, 1.5, 0.2), UI.marges(12), UI.pile(8) })
W.alerteBaliseTexte = texte({ Text = "", TextSize = 13, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0),
	LayoutOrder = 1, ZIndex = 31, Parent = W.alerteBalise })
W.alerteBaliseBouton = creer("TextButton", { Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = Color3.fromRGB(150, 40, 40), Text = "Y ALLER  (démat + remat auto)",
	Font = UI.POLICE_GRAS, TextSize = 12, TextColor3 = C.texte, LayoutOrder = 2, ZIndex = 31, Parent = W.alerteBalise }, { UI.coin(8) })
W.alerteBaliseBouton:SetAttribute("CouleurBase", Color3.fromRGB(150, 40, 40))
UI.rendreVivant(W.alerteBaliseBouton)
W.alerteBaliseFermer = creer("TextButton", { Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = C.panneau, Text = "Ignorer", Font = UI.POLICE_GRAS,
	TextSize = 11, TextColor3 = C.texte2, LayoutOrder = 3, ZIndex = 31, Parent = W.alerteBalise }, { UI.coin(8) })

-- Alerte de la sentinelle : visible même quand la tablette est fermée
W.alerte = creer("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 20, 0, 90), Size = UDim2.fromOffset(300, 0),
	AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.fond, BackgroundTransparency = 0.1, Visible = false, ZIndex = 30,
	Parent = W.gui }, { UI.coin(12), UI.contour(C.ambre, 1.5, 0.2), UI.marges(12) })
W.alerteTexte = texte({ Text = "", TextSize = 13, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y,
	Size = UDim2.new(1, 0, 0, 0), ZIndex = 31, Parent = W.alerte })

-- Notification (en haut de l'écran de la tablette)
W.notification = creer("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -80),
	Size = UDim2.fromOffset(460, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.panneauClair,
	Visible = false, ZIndex = 40, Parent = W.ecran }, { UI.coin(12), UI.marges(12) })
W.contourNotif = UI.contour(C.vert, 1.5, 0)
W.contourNotif.Parent = W.notification
W.notifTexte = texte({ Text = "", TextSize = 14, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y,
	TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 0), ZIndex = 41, Parent = W.notification })

--------------------------------------------------------------------
-- COLONNE A : statut, télémétrie, flux temporel
--------------------------------------------------------------------
do
	local _, contenu = panneau(W.ecran, 14, 70, 360, 232, "STATUT", "●")
	-- Anneau de segments (progression, vortex, veille)
	local anneau = creer("Frame", { Position = UDim2.fromOffset(2, 6), Size = UDim2.fromOffset(150, 150),
		BackgroundTransparency = 1, Parent = contenu })
	W.segments = {}
	for i = 1, R.SEGMENTS do
		local angle = (i - 1) / R.SEGMENTS * math.pi * 2 - math.pi / 2 -- départ en haut
		W.segments[i] = creer("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Rotation = math.deg(angle) + 90,
			Position = UDim2.new(0.5 + math.cos(angle) * 0.45, 0, 0.5 + math.sin(angle) * 0.45, 0),
			Size = UDim2.fromOffset(7, 4), BackgroundColor3 = C.gris, BorderSizePixel = 0, Parent = anneau }, { UI.coin(2) })
	end
	creer("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.72, 0.72),
		BackgroundTransparency = 1, Parent = anneau }, { UI.coin(999), UI.contour(C.bleu, 1, 0.5) })
	W.anneauTexte = texte({ Text = "OK", Font = UI.POLICE_CODE, TextSize = 26, TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(110, 30), Parent = anneau })
	W.anneauSous = texte({ Text = "POSÉ", Font = UI.POLICE_CODE, TextSize = 11, TextColor3 = C.texte2,
		TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.64),
		Size = UDim2.fromOffset(110, 14), Parent = anneau })

	local droite = creer("Frame", { Position = UDim2.fromOffset(166, 0), Size = UDim2.new(1, -166, 1, 0),
		BackgroundTransparency = 1, Parent = contenu }, { UI.pile(6) })
	texte({ Text = "ÉTAT DU TARDIS", Font = UI.POLICE_GRAS, TextSize = 10, TextColor3 = C.texte2, LayoutOrder = 1, Parent = droite })
	W.etatGrand = texte({ Text = "POSÉ", Font = UI.POLICE_GRAS, TextSize = 17, TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 2, Parent = droite })
	W.chrono = texte({ Text = "", Font = UI.POLICE_CODE, TextSize = 20, TextColor3 = C.ambre, Size = UDim2.new(1, 0, 0, 24),
		LayoutOrder = 3, Parent = droite })
	local badges = creer("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1, LayoutOrder = 4, Parent = droite })
	local pileBadges = UI.pile(5, true)
	pcall(function() pileBadges.Wraps = true end)
	pileBadges.Parent = badges
	W.badges = {
		camouflage = UI.badge(badges, "CAMOUFLÉ", C.cyan, 1),
		verrou = UI.badge(badges, "VERROUILLÉ", C.rouge, 2),
		petit = UI.badge(badges, "RÉDUIT", C.ambre, 3),
		porte = UI.badge(badges, "PORTÉ", C.vert, 4),
		urgence = UI.badge(badges, "URGENCE", C.orange, 5),
		express = UI.badge(badges, "EXPRESS", C.vert, 9),
		horsTension = UI.badge(badges, "HORS TENSION", C.texte2, 6),
		alerte = UI.badge(badges, "ALERTE", C.rouge, 7),
		bloque = UI.badge(badges, "BLOQUÉ", C.orange, 8),
		eau = UI.badge(badges, "SUR L'EAU", C.cyan, 10),
	}
	-- Jauges : énergie du bouclier et intégrité du TARDIS (même style que le reste du panneau)
	local function jauge(nom, ordre, couleur)
		local cadre = creer("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, LayoutOrder = ordre, Parent = droite })
		local etiquette = texte({ Text = nom, Font = UI.POLICE_GRAS, TextSize = 10, TextColor3 = C.texte2, Size = UDim2.new(1, -50, 0, 12), Parent = cadre })
		local valeur = texte({ Text = "—", Font = UI.POLICE_CODE, TextSize = 11, TextColor3 = couleur, TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.new(1, -50, 0, 0), Size = UDim2.fromOffset(50, 12), Parent = cadre })
		local fond = creer("Frame", { Position = UDim2.fromOffset(0, 15), Size = UDim2.new(1, 0, 0, 7), BackgroundColor3 = C.gris, Parent = cadre }, { UI.coin(99) })
		local barre = creer("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = couleur, Parent = fond }, { UI.coin(99) })
		return { cadre = cadre, etiquette = etiquette, valeur = valeur, barre = barre }
	end
	W.jaugeBouclier = jauge("BOUCLIER", 5, C.cyan)
	W.jaugeIntegrite = jauge("INTÉGRITÉ", 6, C.vert)
	W.energieBouclier = W.jaugeBouclier.barre
	W.energieTexte = W.jaugeBouclier.valeur
end

do
	local _, contenu = panneau(W.ecran, 14, 314, 360, 196, "TÉLÉMÉTRIE", "▲", C.cyan)
	UI.pile(2).Parent = contenu
	W.infoLieu = ligneInfo(contenu, "Lieu actuel", 1)
	W.infoCoord = ligneInfo(contenu, "Coordonnées", 2)
	W.infoCap = ligneInfo(contenu, "Cap", 3)
	W.infoEchelle = ligneInfo(contenu, "Échelle", 4)
	W.infoPortes = ligneInfo(contenu, "Portes", 5)
	W.infoDestination = ligneInfo(contenu, "Destination", 6)
end

do
	-- Commandes rapides (à la place du flux temporel) : six outils directement sur la tablette, placés plus bas
	local cadre, contenu = panneau(W.ecran, 14, 522, 360, 86, "COMMANDES RAPIDES", "●", C.cyan)
	W.stabilite = texte({ Text = "STABLE", Font = UI.POLICE_CODE, TextSize = 11, TextColor3 = C.vert,
		TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, -14, 0, 16), Parent = cadre })
	W.barres = {}
	W.rapides = contenu
end

--------------------------------------------------------------------
-- COLONNE B : navigation
--------------------------------------------------------------------
do
	local _, contenu = panneau(W.ecran, 388, 70, 472, 538, "NAVIGATION", "◆")
	UI.pile(8).Parent = contenu

	-- Lieux / Joueurs / Coordonnées
	local segments = creer("Frame", { Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = C.fond, LayoutOrder = 1,
		Parent = contenu }, { UI.coin(9) })
	W.curseur = creer("Frame", { Size = UDim2.new(1 / 4, -4, 1, -6), Position = UDim2.fromOffset(3, 3),
		BackgroundColor3 = C.bleu, Parent = segments }, { UI.coin(7), UI.contour(C.ambre, 1, 0.45) })
	W.segments3 = {}
	for i, info in { { "lieux", "◆ Lieux" }, { "joueurs", "● Joueurs" }, { "coord", "○ Coord." }, { "histo", "► Historique" } } do
		W.segments3[info[1]] = creer("TextButton", { Text = info[2], Font = UI.POLICE_GRAS, TextSize = 12,
			TextColor3 = i == 1 and C.texte or C.texte2, BackgroundTransparency = 1,
			Position = UDim2.fromScale((i - 1) / 4, 0), Size = UDim2.fromScale(1 / 4, 1), Parent = segments })
	end

	W.recherche = creer("TextBox", { Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = C.fond, Text = "",
		PlaceholderText = "Rechercher un lieu ou un joueur…", PlaceholderColor3 = C.texte2, TextColor3 = C.texte,
		Font = UI.POLICE, TextSize = 13, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 2, Parent = contenu },
	{ UI.coin(9), UI.contour(C.bleu, 1, 0.3), creer("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }) })

	W.liste = creer("ScrollingFrame", { Size = UDim2.new(1, 0, 0, 176), BackgroundColor3 = Color3.fromRGB(4, 10, 24),
		BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = C.ambre, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Parent = contenu },
	{ UI.coin(9), UI.contour(C.bleu, 1, 0.5), UI.marges(6), UI.pile(4) })
	W.listeVide = texte({ Text = "", TextSize = 12, TextColor3 = C.texte2, TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 44), TextWrapped = true, LayoutOrder = 999, Visible = false, Parent = W.liste })

	-- Panneau Coordonnées (remplace la liste dans l'onglet Coordonnées)
	W.panneauCoord = creer("Frame", { Size = UDim2.new(1, 0, 0, 176), BackgroundColor3 = Color3.fromRGB(4, 10, 24),
		LayoutOrder = 3, Visible = false, Parent = contenu }, { UI.coin(9), UI.contour(C.bleu, 1, 0.5), UI.marges(14), UI.pile(10) })
	texte({ Text = "Place un aperçu du TARDIS n'importe où dans le monde, tourne-le et incline-le. "
		.. "S'il touche un obstacle, l'atterrissage passera automatiquement en urgence.", TextSize = 12, TextColor3 = C.texte2,
		TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 1, Parent = W.panneauCoord })
	W.boutonPlacer = creer("TextButton", { Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = C.bleu, Text = "",
		LayoutOrder = 2, Parent = W.panneauCoord }, { UI.coin(9), UI.contour(C.ambre, 1, 0.4) })
	texte({ Text = "○  Choisir une nouvelle localisation", Font = UI.POLICE_GRAS, TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = W.boutonPlacer })
	W.boutonPlacer:SetAttribute("CouleurBase", C.bleu)
	UI.rendreVivant(W.boutonPlacer)
	W.infoPlacement = texte({ Text = "Aucune localisation enregistrée.", Font = UI.POLICE_CODE, TextSize = 12, TextColor3 = C.texte2,
		TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 3, Parent = W.panneauCoord })

	-- Fiche de la destination choisie
	local fiche = creer("Frame", { Size = UDim2.new(1, 0, 0, 84), BackgroundColor3 = C.fond, LayoutOrder = 4, Parent = contenu },
	{ UI.coin(10), UI.contour(C.ambre, 1, 0.6) })
	W.ficheIcone = texte({ Text = "?", Font = UI.POLICE_GRAS, TextSize = 20, TextColor3 = C.ambre,
		TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(44, 44),
		BackgroundTransparency = 0.6, BackgroundColor3 = C.panneauClair, Parent = fiche })
	creer("UICorner", { CornerRadius = UDim.new(1, 0), Parent = W.ficheIcone })
	W.ficheNom = texte({ Text = "Aucune destination", Font = UI.POLICE_GRAS, TextSize = 15, TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(68, 12), Size = UDim2.new(1, -80, 0, 20), Parent = fiche })
	W.ficheInfo = texte({ Text = "Choisis un lieu, un joueur ou des coordonnées.", Font = UI.POLICE_CODE, TextSize = 11,
		TextColor3 = C.texte2, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(68, 34),
		Size = UDim2.new(1, -80, 0, 16), Parent = fiche })
	-- Joueur : dernière position ou sur lui (figé)
	-- Catégorie (lieux) : un clic passe à la catégorie suivante
	W.boutonCategorie = creer("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12), Size = UDim2.fromOffset(110, 22),
		BackgroundColor3 = C.fond, Text = "Catégorie", Font = UI.POLICE_GRAS, TextSize = 10, TextColor3 = C.texte2, Visible = false, Parent = fiche },
	{ UI.coin(6), UI.contour(C.bleu, 1, 0.4) })
	W.boutonCategorie:SetAttribute("CouleurBase", C.fond)
	UI.rendreVivant(W.boutonCategorie)
	W.modeJoueur = creer("Frame", { Position = UDim2.fromOffset(68, 54), Size = UDim2.new(1, -80, 0, 24),
		BackgroundColor3 = C.panneau, Visible = false, Parent = fiche }, { UI.coin(7) })
	W.curseurJoueur = creer("Frame", { Size = UDim2.new(0.5, -3, 1, -4), Position = UDim2.fromOffset(2, 2),
		BackgroundColor3 = C.bleu, Parent = W.modeJoueur }, { UI.coin(6), UI.contour(C.cyan, 1, 0.5) })
	W.boutonDernierePos = creer("TextButton", { Text = "Dernière position", Font = UI.POLICE_GRAS, TextSize = 11,
		TextColor3 = C.texte, BackgroundTransparency = 1, Size = UDim2.fromScale(0.5, 1), Parent = W.modeJoueur })
	W.boutonSurLui = creer("TextButton", { Text = "Sur lui (figé)", Font = UI.POLICE_GRAS, TextSize = 11,
		TextColor3 = C.texte2, BackgroundTransparency = 1, Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(0.5, 1),
		Parent = W.modeJoueur })

	-- Protocoles côte à côte
	local protocoles = creer("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = 5,
		Parent = contenu }, { UI.pile(16, true) })
	local gauche = creer("Frame", { Size = UDim2.new(1 / 3, -11, 1, 0), BackgroundTransparency = 1, LayoutOrder = 1, Parent = protocoles })
	local milieu = creer("Frame", { Size = UDim2.new(1 / 3, -11, 1, 0), BackgroundTransparency = 1, LayoutOrder = 2, Parent = protocoles })
	local droite = creer("Frame", { Size = UDim2.new(1 / 3, -11, 1, 0), BackgroundTransparency = 1, LayoutOrder = 3, Parent = protocoles })
	W.interUrgence = UI.interrupteur(gauche, "Urgence", "Vol instable", C.orange, 1)
	W.interExpress = UI.interrupteur(milieu, "Express", "Voyage en 2 s", C.vert, 1)
	W.interInvisible = UI.interrupteur(droite, "Invisible", "Déjà camouflé", C.cyan, 1)
	-- État partagé avec le menu rapide (Urgence et Express s'excluent)
	Commandes.lierInterrupteurs({ urgence = W.interUrgence, express = W.interExpress, invisible = W.interInvisible })

	-- Grands boutons
	local actions = creer("Frame", { Size = UDim2.new(1, 0, 0, 62), BackgroundTransparency = 1, LayoutOrder = 6,
		Parent = contenu }, { UI.pile(12, true) })
	local function grosBouton(nom, sousTitre, ordre)
		local bouton = creer("TextButton", { Size = UDim2.new(0.5, -6, 1, 0), BackgroundColor3 = C.bleu, Text = "",
			LayoutOrder = ordre, Parent = actions }, { UI.coin(12) })
		local lueur = UI.contour(C.ambre, 2, 0.5)
		lueur.Name = "Lueur"
		lueur.Parent = bouton
		texte({ Text = nom, Font = UI.POLICE_GRAS, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, 12), Size = UDim2.new(1, 0, 0, 20), Parent = bouton })
		texte({ Name = "SousTitre", Text = sousTitre, TextSize = 11, TextColor3 = C.texte2,
			TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 0, 14),
			Parent = bouton })
		creer("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.blanc, Color3.fromRGB(170, 180, 205)), Parent = bouton })
		UI.rendreVivant(bouton)
		return bouton
	end
	W.demat = grosBouton("DÉMATÉRIALISER", "Décoller", 1)
	W.remat = grosBouton("MATÉRIALISER", "Atterrir", 2)
end

--------------------------------------------------------------------
-- COLONNE C : scanner, occupants, journal
--------------------------------------------------------------------
do
	local cadreScanner, contenu = panneau(W.ecran, 874, 70, 360, 290, "SCANNER", "●", C.cyan)
	-- Choix entre le radar (joueurs proches) et la mini-carte (vue du dessus avec les destinations)
	local function boutonMode(nom, x)
		local b = creer("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, x, 0, 6), Size = UDim2.fromOffset(60, 20),
			BackgroundColor3 = C.fond, Text = nom, Font = UI.POLICE_GRAS, TextSize = 10, TextColor3 = C.texte2, Parent = cadreScanner },
		{ UI.coin(6), UI.contour(C.cyan, 1, 0.5) })
		b:SetAttribute("CouleurBase", C.fond)
		UI.rendreVivant(b)
		return b
	end
	W.btnCarte = boutonMode("CARTE", -10)
	W.btnRadar = boutonMode("RADAR", -76)

	W.carte = creer("Frame", { Position = UDim2.fromOffset(0, 4), Size = UDim2.fromOffset(226, 226),
		BackgroundColor3 = Color3.fromRGB(4, 14, 26), ClipsDescendants = true, Visible = false, Parent = contenu },
	{ UI.coin(12), UI.contour(C.cyan, 1.5, 0.3) })
	for i = 1, 3 do
		creer("Frame", { Position = UDim2.fromScale(i / 4, 0), Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = C.cyan,
			BackgroundTransparency = 0.88, BorderSizePixel = 0, Parent = W.carte })
		creer("Frame", { Position = UDim2.fromScale(0, i / 4), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = C.cyan,
			BackgroundTransparency = 0.88, BorderSizePixel = 0, Parent = W.carte })
	end
	texte({ Text = "N", Font = UI.POLICE_GRAS, TextSize = 11, TextColor3 = C.ambre, TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 3), Size = UDim2.fromOffset(20, 12), ZIndex = 6, Parent = W.carte })
	W.echelleCarteTexte = texte({ Text = "", Font = UI.POLICE_CODE, TextSize = 10, TextColor3 = C.texte2,
		TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -6, 1, -4),
		Size = UDim2.fromOffset(110, 12), ZIndex = 6, Parent = W.carte })
	W.calqueCarte = creer("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = W.carte })
	W.tardisCarte = texte({ Text = "▲", Font = UI.POLICE_GRAS, TextSize = 16, TextColor3 = C.ambre,
		TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(18, 18), ZIndex = 5, Parent = W.carte })

	local radar = creer("Frame", { Position = UDim2.fromOffset(0, 4), Size = UDim2.fromOffset(226, 226),
		BackgroundColor3 = Color3.fromRGB(3, 14, 22), Parent = contenu }, { UI.coin(999), UI.contour(C.cyan, 1.5, 0.3) })
	for _, f in { 0.33, 0.66 } do
		creer("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(f, f),
			BackgroundTransparency = 1, Parent = radar }, { UI.coin(999), UI.contour(C.cyan, 1, 0.75) })
	end
	creer("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = C.cyan, BackgroundTransparency = 0.85, BorderSizePixel = 0, Parent = radar })
	creer("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 1, 1, 0),
		BackgroundColor3 = C.cyan, BackgroundTransparency = 0.85, BorderSizePixel = 0, Parent = radar })
	texte({ Text = "PORTE", Font = UI.POLICE_CODE, TextSize = 10, TextColor3 = C.cyan, TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.fromOffset(60, 12), Parent = radar })
	W.balayageRadar = creer("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = radar })
	local trait = creer("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.5, 0, 0, 2), BackgroundColor3 = C.blanc, BorderSizePixel = 0, Parent = W.balayageRadar })
	creer("UIGradient", { Color = ColorSequence.new(C.cyan, C.cyan), Transparency = NumberSequence.new(0.05, 0.9), Parent = trait })
	creer("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(10, 14),
		BackgroundColor3 = C.bleu, ZIndex = 3, Parent = radar }, { UI.coin(2), UI.contour(C.ambre, 1.5, 0) })
	W.calquePoints = creer("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = radar })
	W.radar = radar
	W.signalPerdu = texte({ Text = "", Font = UI.POLICE_CODE, TextSize = 13, TextColor3 = C.ambre,
		TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.2,
		BackgroundColor3 = Color3.fromRGB(3, 14, 22), ZIndex = 8, Visible = false, Parent = radar })
	creer("UICorner", { CornerRadius = UDim.new(1, 0), Parent = W.signalPerdu })

	local lectures = creer("Frame", { Position = UDim2.fromOffset(236, 4), Size = UDim2.new(1, -236, 1, -4),
		BackgroundTransparency = 1, Parent = contenu }, { UI.pile(4) })
	local function lecture(titre, ordre)
		texte({ Text = titre, Font = UI.POLICE_GRAS, TextSize = 10, TextColor3 = C.texte2, Size = UDim2.new(1, 0, 0, 12),
			LayoutOrder = ordre, Parent = lectures })
		return texte({ Text = "—", Font = UI.POLICE_CODE, TextSize = 13, TextColor3 = C.cyan, Size = UDim2.new(1, 0, 0, 16),
			LayoutOrder = ordre + 1, Parent = lectures })
	end
	W.lectX = lecture("POSITION X", 1)
	W.lectY = lecture("POSITION Y", 3)
	W.lectZ = lecture("POSITION Z", 5)
	W.lectCap = lecture("CAP", 7)
	W.lectPortee = lecture("À PORTÉE", 9)
	texte({ Text = "Clique sur un point (radar) ou un lieu (carte) pour le viser.", TextSize = 10, TextColor3 = C.texte2, TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 11, Parent = lectures })
end

do
	local cadre, contenu = panneau(W.ecran, 874, 372, 360, 104, "OCCUPANTS DE LA SALLE", "●", C.vert)
	W.occCompte = texte({ Text = "0", Font = UI.POLICE_CODE, TextSize = 12, TextColor3 = C.vert,
		TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, -124, 0, 16), Parent = cadre })
	W.btnSentinelle = creer("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 6),
		Size = UDim2.fromOffset(104, 20), BackgroundColor3 = Color3.fromRGB(30, 90, 60), Text = "SENTINELLE  ●",
		Font = UI.POLICE_GRAS, TextSize = 10, TextColor3 = C.texte, Parent = cadre }, { UI.coin(6), UI.contour(C.vert, 1, 0.5) })
	W.btnSentinelle:SetAttribute("CouleurBase", Color3.fromRGB(30, 90, 60))
	UI.rendreVivant(W.btnSentinelle)
	W.occListe = texte({ Text = "Personne à bord.", TextSize = 12, TextColor3 = C.texte, TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top, Size = UDim2.fromScale(1, 1), Parent = contenu })
end

do
	local cadre, contenu = panneau(W.ecran, 874, 488, 360, 120, "JOURNAL DE BORD", "■")
	W.effacer = creer("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 6),
		Size = UDim2.fromOffset(62, 20), BackgroundColor3 = C.fond, Text = "Effacer", Font = UI.POLICE_GRAS, TextSize = 10,
		TextColor3 = C.texte2, Parent = cadre }, { UI.coin(6), UI.contour(C.bleu, 1, 0.4) })
	W.effacer:SetAttribute("CouleurBase", C.fond)
	UI.rendreVivant(W.effacer)
	W.exporter = creer("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -78, 0, 6),
		Size = UDim2.fromOffset(66, 20), BackgroundColor3 = C.fond, Text = "Exporter", Font = UI.POLICE_GRAS, TextSize = 10,
		TextColor3 = C.texte2, Parent = cadre }, { UI.coin(6), UI.contour(C.bleu, 1, 0.4) })
	W.exporter:SetAttribute("CouleurBase", C.fond)
	UI.rendreVivant(W.exporter)
	W.journal = creer("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 3, ScrollBarImageColor3 = C.ambre, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = contenu }, { UI.pile(3) })
	W.journalVide = texte({ Text = "Rien à signaler.", TextSize = 12, TextColor3 = C.texte2, LayoutOrder = 0, Parent = W.journal })
end

--------------------------------------------------------------------
-- DOCK : systèmes, taille, voyants, statistiques
--------------------------------------------------------------------
do
	local _, contenu = panneau(W.ecran, 14, 618, 1220, 98, "SYSTÈMES", "◆")
	local function tuile(nom, icone, x)
		local bouton = creer("TextButton", { Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(120, 56),
			BackgroundColor3 = C.fond, Text = "", Parent = contenu }, { UI.coin(10), UI.contour(C.bleu, 1, 0.4) })
		local lampe = creer("Frame", { Position = UDim2.fromOffset(10, 9), Size = UDim2.fromOffset(8, 8), BackgroundColor3 = C.gris,
			Parent = bouton }, { UI.coin(99) })
		texte({ Text = icone, TextSize = 15, TextColor3 = C.texte2, TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.fromOffset(0, 3), Size = UDim2.new(1, -10, 0, 18), Parent = bouton })
		texte({ Text = nom, Font = UI.POLICE_GRAS, TextSize = 12, Position = UDim2.fromOffset(10, 20),
			Size = UDim2.new(1, -16, 0, 16), Parent = bouton })
		local etat = texte({ Text = "", TextSize = 10, TextColor3 = C.texte2, Position = UDim2.fromOffset(10, 37),
			Size = UDim2.new(1, -16, 0, 14), Parent = bouton })
		UI.rendreVivant(bouton)
		return { bouton = bouton, lampe = lampe, etat = etat }
	end
	W.tuiles = {
		camouflage = tuile("Camouflage", "◐", 0),
		verrou = tuile("Verrou", "⊘", 128),
		portes = tuile("Portes", "■", 256),
		volLibre = tuile("Vol libre", "◆", 384),
	}

	-- Taille
	local zone = creer("Frame", { Position = UDim2.fromOffset(522, 0), Size = UDim2.fromOffset(206, 56),
		BackgroundTransparency = 1, Parent = contenu })
	texte({ Text = "Échelle de la cabine", Font = UI.POLICE_GRAS, TextSize = 12, Size = UDim2.new(1, -60, 0, 16), Parent = zone })
	W.valeurTaille = texte({ Text = "100 %", Font = UI.POLICE_CODE, TextSize = 14, TextColor3 = C.ambre,
		TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(1, 0, 0, 16), Parent = zone })
	W.pisteTaille = creer("TextButton", { Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1, Text = "", Parent = zone })
	W.railTaille = creer("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = C.gris, Parent = W.pisteTaille }, { UI.coin(99) })
	W.remplissageTaille = creer("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.ambre, Parent = W.railTaille },
	{ UI.coin(99) })
	if seuilPortes < 1 then
		creer("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale((seuilPortes - TAILLE_MIN) / (1 - TAILLE_MIN), 0.5),
			Size = UDim2.fromOffset(2, 14), BackgroundColor3 = C.cyan, BorderSizePixel = 0, Parent = W.railTaille })
	end
	W.poignee = creer("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(18, 18), BackgroundColor3 = C.texte, Parent = W.pisteTaille }, { UI.coin(99), UI.contour(C.ambre, 2, 0) })
	W.aideTaille = texte({ Text = "", TextSize = 10, TextColor3 = C.texte2, Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(1, 0, 0, 14), Parent = zone })

	-- Voyants de la console
	-- Boucliers : deux interrupteurs empilés
	local zoneBoucliers = creer("Frame", { Position = UDim2.fromOffset(742, 0), Size = UDim2.fromOffset(150, 56),
		BackgroundTransparency = 1, Parent = contenu }, { UI.pile(4) })
	local function boutonBouclier(nom, ordre)
		local b = creer("TextButton", { Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = C.fond, Text = nom,
			Font = UI.POLICE_GRAS, TextSize = 11, TextColor3 = C.texte2, LayoutOrder = ordre, Parent = zoneBoucliers },
		{ UI.coin(7), UI.contour(C.cyan, 1, 0.5) })
		b:SetAttribute("CouleurBase", C.fond)
		UI.rendreVivant(b)
		return b
	end
	W.boutonBoucliers = boutonBouclier("●  BOUCLIERS", 1)
	-- (l'énergie du bouclier est affichée dans le panneau Statut)
	W.boutonOutilsDock = boutonBouclier("◆  TOUS LES OUTILS", 2)
	-- Choix des boucliers : petite fenêtre au-dessus du dock
	W.choixBoucliers = creer("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0, 817, 0, -8), Size = UDim2.fromOffset(220, 0),
		AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.fond, BackgroundTransparency = 0.05, Visible = false, ZIndex = 20, Parent = contenu },
	{ UI.coin(10), UI.contour(C.cyan, 1, 0.3), UI.marges(8), UI.pile(5) })
	W.boutonsBouclier = {}
	for i, info in { { "Joueurs", "Anti-joueurs : personne n'approche" }, { "Balles", "Anti-balles : les tirs s'arrêtent" }, { "Complet", "Complet : joueurs et tirs" } } do
		local b = creer("TextButton", { Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = C.panneau, Text = info[2], Font = UI.POLICE_GRAS, TextSize = 11,
			TextColor3 = C.texte, LayoutOrder = i, ZIndex = 21, Parent = W.choixBoucliers }, { UI.coin(7) })
		b:SetAttribute("CouleurBase", C.panneau)
		UI.rendreVivant(b)
		b.Activated:Connect(function() remote:FireServer("Bouclier", { type = info[1] }) end)
		W.boutonsBouclier[info[1]] = b
	end

	local voyants = creer("Frame", { Position = UDim2.fromOffset(906, 0), Size = UDim2.fromOffset(140, 56),
		BackgroundTransparency = 1, Parent = contenu }, { UI.pile(1) })
	local function voyant(nom, ordre)
		local ligne = creer("Frame", { Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, LayoutOrder = ordre, Parent = voyants })
		local lampe = creer("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.fromOffset(8, 8), BackgroundColor3 = C.gris, Parent = ligne }, { UI.coin(99) })
		texte({ Text = nom, TextSize = 12, Position = UDim2.fromOffset(14, 0), Size = UDim2.new(0.6, 0, 1, 0), Parent = ligne })
		local valeur = texte({ Text = "", Font = UI.POLICE_CODE, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Right,
			Size = UDim2.fromScale(1, 1), Parent = ligne })
		return { lampe = lampe, valeur = valeur }
	end
	W.voyants = { energie = voyant("Énergie", 1), alerte = voyant("Alerte", 2), demarrage = voyant("Démarrage", 3) }

	-- Statistiques de la session
	local stats = creer("Frame", { Position = UDim2.fromOffset(1060, 0), Size = UDim2.fromOffset(136, 56),
		BackgroundTransparency = 1, Parent = contenu }, { UI.pile(1) })
	local function stat(nom, ordre)
		local ligne = creer("Frame", { Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, LayoutOrder = ordre, Parent = stats })
		texte({ Text = nom, TextSize = 12, TextColor3 = C.texte2, Size = UDim2.new(0.6, 0, 1, 0), Parent = ligne })
		return texte({ Text = "—", Font = UI.POLICE_CODE, TextSize = 12, TextColor3 = C.ambre,
			TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.fromScale(1, 1), Parent = ligne })
	end
	W.statVoyages = stat("Voyages", 1)
	W.statVortex = stat("Vortex", 2)
	W.statSession = stat("Session", 3)
end

--------------------------------------------------------------------
-- Journal et notifications
--------------------------------------------------------------------
S.journalEntrees = {}
local function journaliser(message, couleur)
	S.compteurJournal += 1
	table.insert(S.journalEntrees, 1, { heure = os.date("%H:%M:%S"), message = message })
	while #S.journalEntrees > 200 do table.remove(S.journalEntrees) end
	W.journalVide.Visible = false
	local ligne = creer("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
		LayoutOrder = -S.compteurJournal, Parent = W.journal })
	creer("Frame", { Position = UDim2.fromOffset(0, 4), Size = UDim2.fromOffset(3, 10), BackgroundColor3 = couleur or C.texte2,
		BorderSizePixel = 0, Parent = ligne }, { UI.coin(99) })
	texte({ Text = os.date("%H:%M:%S"), Font = UI.POLICE_CODE, TextSize = 10, TextColor3 = C.texte2,
		Position = UDim2.fromOffset(8, 0), Size = UDim2.fromOffset(54, 16), Parent = ligne })
	texte({ Text = message, TextSize = 11, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromOffset(64, 0), Size = UDim2.new(1, -66, 0, 16), Parent = ligne })
	table.insert(S.lignesJournal, 1, ligne)
	while #S.lignesJournal > R.MAX_JOURNAL do
		table.remove(S.lignesJournal):Destroy()
	end
end

W.effacer.Activated:Connect(function()
	for _, ligne in S.lignesJournal do ligne:Destroy() end
	table.clear(S.lignesJournal)
	W.journalVide.Visible = true
end)

local jeton = 0
local function notifier(message, reussi)
	if typeof(message) ~= "string" or string.sub(message, 1, 2) == "__" then return end
	local couleur = reussi and C.vert or C.rouge
	journaliser(message, couleur)
	if not S.ouvert then return end
	jeton += 1
	local moi = jeton
	W.contourNotif.Color = couleur
	W.notifTexte.TextColor3 = UI.eclaircir(couleur, 0.4)
	W.notifTexte.Text = (reussi and "●  " or "×  ") .. message
	UI.son(reussi and "Notification" or "Alerte")
	W.notification.Visible = true
	W.notification.Position = UDim2.new(0.5, 0, 0, -80)
	animer(W.notification, 0.4, { Position = UDim2.new(0.5, 0, 0, 66) }, Enum.EasingStyle.Back)
	task.delay(4, function()
		if moi ~= jeton then return end
		animer(W.notification, 0.3, { Position = UDim2.new(0.5, 0, 0, -80) }).Completed:Wait()
		if moi == jeton then W.notification.Visible = false end
	end)
end

--------------------------------------------------------------------
-- Lecture de l'état du TARDIS
--------------------------------------------------------------------
local function lireEtat()
	local etat = exterieur:GetAttribute("Etat") or E.Pose
	local idPorteur = exterieur:GetAttribute("Porteur")
	return {
		etat = etat,
		pose = etat == E.Pose,
		camoufle = exterieur:GetAttribute("Camouflage") == true,
		echelle = exterieur:GetAttribute("Echelle") or 1,
		porteur = idPorteur and Players:GetPlayerByUserId(idPorteur),
		porte = idPorteur ~= nil,
		verrouille = exterieur:GetAttribute("PortesVerrouillees") == true,
		urgence = Config.modeDe(exterieur) == "Urgence" and etat ~= E.Pose,
		express = Config.modeDe(exterieur) == "Express" and etat ~= E.Pose,
		alimente = exterieur:GetAttribute("Alimentation") ~= false,
		alerte = exterieur:GetAttribute("Alerte") == true,
		bloque = exterieur:GetAttribute("DemarrageBloque") == true,
		porteOuverte = exterieur:GetAttribute("PorteOuverte") == true,
		volLibre = exterieur:GetAttribute("VolLibre") ~= nil,
		surEau = exterieur:GetAttribute("SurEau") == true,
	}
end

local function cleDe(c)
	if not c then return nil end
	if c.type == "lieu" then return "lieu:" .. c.nom end
	if c.type == "joueur" then return "joueur:" .. c.id end
	if c.type == "precedent" then return "precedent" end
	if c.type == "historique" then return "histo:" .. tostring(c.index) end
	return "position"
end

-- Distance (studs) entre le TARDIS et la destination choisie, si on peut la connaître
local function distanceDe(c)
	if not c then return nil end
	local origine = exterieur:GetPivot().Position
	if c.type == "lieu" then
		local dossier = Config.dossierDestinations(false)
		local part = dossier and dossier:FindFirstChild(c.nom)
		return part and part:IsA("BasePart") and (part.Position - origine).Magnitude or nil
	elseif c.type == "joueur" then
		local autre = Players:GetPlayerByUserId(c.id)
		local racine = autre and autre.Character and autre.Character:FindFirstChild("HumanoidRootPart")
		return racine and (racine.Position - origine).Magnitude or nil
	elseif c.type == "historique" and c.cframe then
		return (c.cframe.Position - origine).Magnitude
	elseif c.type == "position" and S.positionPerso then
		return (S.positionPerso.cframe.Position - origine).Magnitude
	end
	return nil
end

local function majTuile(t, actif, texteEtat, couleur, disponible)
	UI.setDisponible(t.bouton, disponible, C.fond)
	animer(t.lampe, 0.2, { BackgroundColor3 = actif and couleur or C.gris })
	t.etat.Text = texteEtat
	t.etat.TextColor3 = actif and couleur or C.texte2
end

local function majVoyant(v, texteValeur, couleur)
	animer(v.lampe, 0.25, { BackgroundColor3 = couleur })
	v.valeur.Text = texteValeur
	v.valeur.TextColor3 = couleur
end

local function majFiche()
	local c = S.choix
	W.modeJoueur.Visible = c ~= nil and c.type == "joueur"
	W.boutonCategorie.Visible = c ~= nil and c.type == "lieu"
	if c and c.type == "lieu" then
		local categorie = S.categories[c.nom] and (Config.Categories or {})[S.categories[c.nom]]
		W.boutonCategorie.Text = categorie and ("● " .. categorie.nom) or "Catégorie : aucune"
		W.boutonCategorie.TextColor3 = categorie and categorie.couleur or C.texte2
	end
	if not c then
		W.ficheIcone.Text = "?"
		W.ficheNom.Text = "Aucune destination"
		W.ficheInfo.Text = "Choisis un lieu, un joueur ou des coordonnées."
		return
	end
	local distance = distanceDe(c)
	-- Temps de trajet : démat + remat (la durée dans le vortex dépend de toi)
	local dDemat, cDemat = Config.Timing(E.Demat, false)
	local dRemat, cRemat = Config.Timing(E.Remat, false)
	local trajet = string.format("trajet ~%d s", dDemat + cDemat + dRemat + cRemat)
	local texteDistance = (distance and string.format("%d studs", distance) or "distance inconnue") .. "  ·  " .. trajet
	if c.type == "lieu" then
		W.ficheIcone.Text = "◆"
		W.ficheNom.Text = c.nom
		W.ficheInfo.Text = "LIEU  ·  " .. texteDistance
	elseif c.type == "precedent" then
		W.ficheIcone.Text = "◄"
		W.ficheNom.Text = "Retour : " .. c.nom
		W.ficheInfo.Text = "DERNIÈRE DESTINATION  ·  là d'où le TARDIS est parti  ·  " .. trajet
	elseif c.type == "historique" then
		W.ficheIcone.Text = "►"
		W.ficheNom.Text = c.nom
		W.ficheInfo.Text = "HISTORIQUE  ·  " .. texteDistance
	elseif c.type == "joueur" then
		W.ficheIcone.Text = "●"
		W.ficheNom.Text = c.nom
		W.ficheInfo.Text = (S.figer and "JOUEUR · SUR LUI (FIGÉ)" or "JOUEUR · DERNIÈRE POSITION") .. "  ·  " .. texteDistance
	else
		W.ficheIcone.Text = "○"
		W.ficheNom.Text = "Nouvelle localisation"
		W.ficheInfo.Text = (S.positionPerso and S.positionPerso.collision and "COLLISION » URGENCE" or "COORDONNÉES")
			.. "  ·  " .. texteDistance
	end
end

local function majInterface()
	local e = lireEtat()
	local libelle = UI.LIBELLES[e.etat] or { "?", C.texte2, "?" }
	local couleurEtat, nomEtat, nomCourt = libelle[2], libelle[1], libelle[3]
	if not e.alimente then
		couleurEtat, nomEtat, nomCourt = C.gris, "HORS TENSION", "Hors tension"
	elseif e.volLibre then
		couleurEtat, nomEtat, nomCourt = C.cyan, "VOL LIBRE", "Vol libre"
	elseif e.alerte then
		couleurEtat = C.rouge
	end

	-- Barre du haut
	W.textePastille.Text = (e.alerte and "Alerte · " or "") .. nomCourt
	W.lieuPastille.Text = "·  " .. tostring(exterieur:GetAttribute("Position") or "?")
	animer(W.pointPastille, 0.3, { BackgroundColor3 = couleurEtat })
	W.contourPastille.Color = couleurEtat

	-- Statut
	W.etatGrand.Text = nomEtat
	W.etatGrand.TextColor3 = couleurEtat
	W.badges.camouflage.Visible = e.camoufle
	W.badges.verrou.Visible = e.verrouille
	W.badges.petit.Visible = e.echelle < 0.999
	W.badges.porte.Visible = e.porte
	W.badges.urgence.Visible = e.urgence
	W.badges.express.Visible = e.express
	W.badges.horsTension.Visible = not e.alimente
	W.badges.alerte.Visible = e.alerte
	W.badges.bloque.Visible = e.bloque
	W.badges.eau.Visible = e.surEau

	-- Actions principales
	local petit = e.echelle < 0.999
	local poche = exterieur:GetAttribute("Porteur") == joueur.UserId -- je porte le TARDIS : téléportation de poche
	local dematOk = e.pose and not e.porte and e.alimente and not e.bloque and not e.volLibre
	if poche then dematOk = S.choix ~= nil and e.alimente and not e.bloque end
	local rematOk = e.etat == E.Vol and (S.choix ~= nil or petit) and e.alimente
	W.demat.SousTitre.Text = poche and (S.choix and "Téléportation de poche" or "Choisis une destination") or "Décoller"
	UI.setDisponible(W.demat, dematOk, C.bleu)
	UI.setDisponible(W.remat, rematOk, C.bleu)
	if Commandes.secondesAutoRemat() and e.etat == E.Vol then
		W.remat.SousTitre.Text = string.format("Auto dans %d s", math.ceil(Commandes.secondesAutoRemat()))
	else
		W.remat.SousTitre.Text = petit and "Sur place (réduit)" or (UI.pref("modeVoyage", "auto") == "manuel" and e.etat ~= E.Vol and "Atterrir (choix dans le vortex)" or "Atterrir")
	end
	W.demat.Lueur.Color = dematOk and C.ambre or C.gris
	W.remat.Lueur.Color = rematOk and C.ambre or C.gris

	-- Systèmes
	majTuile(W.tuiles.camouflage, e.camoufle, e.camoufle and "ACTIVÉ" or "Inactif", C.cyan, e.pose and e.alimente)
	majTuile(W.tuiles.verrou, e.verrouille, e.verrouille and "VERROUILLÉ" or "Ouvert", C.rouge, true)
	local portesPossibles = e.pose and (e.porteOuverte or (not e.verrouille and e.echelle >= seuilPortes - 0.001))
	majTuile(W.tuiles.portes, e.porteOuverte, e.porteOuverte and "Ouvertes · fermer" or "Fermées · ouvrir", C.vert,
		portesPossibles and not e.volLibre)
	majTuile(W.tuiles.volLibre, e.volLibre, e.volLibre and "EN VOL" or "Piloter", C.cyan,
		e.pose and not e.porte and e.alimente and not e.bloque and not e.volLibre)
	majVoyant(W.voyants.energie, e.alimente and "NOMINALE" or "COUPÉE", e.alimente and C.vert or C.rouge)
	majVoyant(W.voyants.alerte, e.alerte and "ACTIVE" or "Aucune", e.alerte and C.rouge or C.texte2)
	majVoyant(W.voyants.demarrage, e.bloque and "BLOQUÉ" or "Libre", e.bloque and C.orange or C.vert)

	-- Boucliers : allumés quand actifs, grisés quand impossibles (pas posé, porté, hors tension)
	local boucliersPossibles = e.pose and not e.porte and e.alimente and not e.volLibre
	local unActif = false
	for type, bouton in W.boutonsBouclier do
		local actif = exterieur:GetAttribute("Bouclier" .. type) == true
		unActif = unActif or actif
		UI.colorer(bouton, actif and Color3.fromRGB(60, 120, 170) or C.panneau)
		bouton.Text = (actif and "●  " or "○  ") .. ({ Joueurs = "Anti-joueurs", Balles = "Anti-balles", Complet = "Complet (joueurs + tirs)" })[type]
	end
	UI.setDisponible(W.boutonBoucliers, unActif or boucliersPossibles, unActif and Color3.fromRGB(60, 120, 170) or C.fond)
	W.boutonBoucliers.TextColor3 = unActif and C.texte or C.texte2
	W.boutonBoucliers.Text = unActif and "●  BOUCLIERS  ●" or "●  BOUCLIERS"
	local energie = exterieur:GetAttribute("BouclierEnergie") or 100
	W.energieBouclier.Size = UDim2.fromScale(math.clamp(energie / 100, 0, 1), 1)
	W.energieBouclier.BackgroundColor3 = energie <= 15 and C.rouge or C.cyan -- sous 15 % : dans le rouge
	W.energieTexte.Text = unActif and string.format("%d %%", energie) or "—"
	W.energieTexte.TextColor3 = (unActif and energie <= 15) and C.rouge or (unActif and C.cyan or C.texte2)
	-- Intégrité (points de vie) : voyant "Énergie" étendu
	local integrite = exterieur:GetAttribute("PointsDeVie")
	if integrite then
		local couleurIntegrite = (integrite <= 20 and C.rouge) or (integrite <= 50 and C.ambre) or C.vert
		W.jaugeIntegrite.barre.Size = UDim2.fromScale(integrite / 100, 1)
		W.jaugeIntegrite.barre.BackgroundColor3 = couleurIntegrite
		W.jaugeIntegrite.valeur.Text = string.format("%d %%", integrite)
		W.jaugeIntegrite.valeur.TextColor3 = couleurIntegrite
	end

	-- Taille
	local tailleDispo = e.pose and not e.porte and e.alimente
	if not S.glisseTaille then S.tailleChoisie = e.echelle end
	W.pisteTaille:SetAttribute("Disponible", tailleDispo)
	W.remplissageTaille.BackgroundColor3 = tailleDispo and C.ambre or C.gris
	W.aideTaille.Text = (not e.alimente and "Hors tension.") or (e.porte and "Il doit d'abord être posé.")
		or (not e.pose and "Disponible quand il est posé.")
		or ("Trait bleu : seuil des portes (" .. math.floor(seuilPortes * 100 + 0.5) .. " %)")

	-- Énergie (en haut à droite)
	for i, barreEnergie in W.jauge do
		barreEnergie.BackgroundColor3 = (not e.alimente) and C.gris or (e.alerte and C.rouge or C.vert)
		barreEnergie.BackgroundTransparency = (not e.alimente and i > 1) and 0.7 or 0
	end

	-- Sélection dans la liste + fiche
	local cleChoisie = cleDe(S.choix)
	for cle, element in S.boutonsChoix do
		local choisi = cle == cleChoisie
		UI.colorer(element.bouton, choisi and C.panneauClair or C.panneau)
		element.bouton.Barre.Visible = choisi
	end
	majFiche()
end

--------------------------------------------------------------------
-- Liste des lieux et des joueurs
--------------------------------------------------------------------
local construireListe -- définie plus bas (l'étoile des favoris en a besoin)
local function ajouterElement(texteEl, c, ordre)
	local bouton = creer("TextButton", { Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = C.panneau, Text = "",
		LayoutOrder = ordre, Parent = W.liste }, { UI.coin(7) })
	creer("Frame", { Name = "Barre", Size = UDim2.new(0, 3, 1, -10), Position = UDim2.fromOffset(4, 5),
		BackgroundColor3 = C.ambre, Visible = false, Parent = bouton }, { UI.coin(99) })
	texte({ Text = (c.type == "lieu" and "◆") or (c.type == "precedent" and "◄") or (c.type == "historique" and "►") or "●", TextSize = 16, TextColor3 = C.ambre,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(12, 0), Size = UDim2.new(0, 22, 1, 0), Parent = bouton })
	texte({ Text = texteEl, Font = UI.POLICE_GRAS, TextSize = 13, Position = UDim2.fromOffset(42, 4),
		Size = UDim2.new(1, -150, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd, Parent = bouton })
	local sous = texte({ Text = (c.type == "joueur" and ("@" .. (c.pseudo or ""))) or (c.type == "precedent" and "Retour au point de départ")
		or (c.type == "historique" and c.sous) or (c.type == "lieu" and UI.estFavori(c.nom) and "Favori") or "Destination enregistrée", TextSize = 11,
		TextColor3 = C.texte2, Position = UDim2.fromOffset(42, 21), Size = UDim2.new(1, -150, 0, 14),
		TextTruncate = Enum.TextTruncate.AtEnd, Parent = bouton })
	local distance = texte({ Text = "", Font = UI.POLICE_CODE, TextSize = 12, TextColor3 = C.cyan,
		TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(100, 16), Parent = bouton })
	bouton:SetAttribute("CouleurBase", C.panneau)
	UI.rendreVivant(bouton)
	bouton.Activated:Connect(function()
		if UI.pref("modeVoyage", "auto") == "manuel" and (exterieur:GetAttribute("Etat") or E.Pose) == E.Pose
			and exterieur:GetAttribute("Porteur") ~= joueur.UserId then
			notifier("Mode manuel : décolle d'abord, les destinations se débloquent dans le vortex.", false)
			return
		end
		S.choix = c
		majInterface()
	end)
	if c.type == "lieu" then
		-- Étiquette de catégorie (couleur) si la destination en a une
		local categorie = S.categories[c.nom] and (Config.Categories or {})[S.categories[c.nom]]
		if categorie then
			creer("Frame", { Name = "Categorie", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -150, 0.5, 0), Size = UDim2.fromOffset(8, 22),
				BackgroundColor3 = categorie.couleur, Parent = bouton }, { UI.coin(99) })
			sous.Text = categorie.nom .. "  ·  " .. sous.Text
		end
		-- Étoile de favori : les favoris remontent en tête de liste
		local favori = UI.estFavori(c.nom)
		local etoile = creer("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -118, 0.5, 0), Size = UDim2.fromOffset(26, 26),
			BackgroundTransparency = 1, Text = favori and "●" or "○", Font = UI.POLICE_GRAS, TextSize = 16,
			TextColor3 = favori and C.ambre or C.texte2, Parent = bouton })
		etoile.Activated:Connect(function()
			UI.basculerFavori(c.nom)
			construireListe()
		end)
	end
	S.boutonsChoix[cleDe(c)] = { bouton = bouton, distance = distance, sous = sous, choix = c }
	table.insert(S.elementsListe, bouton)
end

construireListe = function()
	for _, element in S.elementsListe do element:Destroy() end
	table.clear(S.elementsListe)
	table.clear(S.boutonsChoix)

	local filtre = string.lower(W.recherche.Text)
	local function garde(nom)
		return filtre == "" or string.find(string.lower(nom), filtre, 1, true) ~= nil
	end
	local ordre = 0
	local noms = {}
	local precedentNom = exterieur:GetAttribute("PrecedentNom")
	local lieux = {}
	for nom in string.gmatch(exterieur:GetAttribute("ListeDestinations") or "", "[^\n]+") do
		noms[nom] = true
		table.insert(lieux, nom)
	end
	-- Les favoris d'abord, puis les autres dans l'ordre d'origine
	local ordreOrigine = {}
	for i, nom in lieux do ordreOrigine[nom] = i end
	local parDistance = UI.pref("tri", "nom") == "distance"
	local distances = {}
	if parDistance then
		for _, nom in lieux do distances[nom] = distanceDe({ type = "lieu", nom = nom }) or math.huge end
	end
	table.sort(lieux, function(a, b)
		local fa, fb = UI.estFavori(a), UI.estFavori(b)
		if fa ~= fb then return fa end
		if parDistance and distances[a] ~= distances[b] then return distances[a] < distances[b] end
		return ordreOrigine[a] < ordreOrigine[b]
	end)
	for _, nom in lieux do
		if S.mode == "lieux" and garde(nom) then
			ordre += 1
			ajouterElement(nom, { type = "lieu", nom = nom }, ordre)
		end
	end
	if S.mode == "histo" then
		-- En tête de l'historique : retour là d'où le TARDIS est parti
		if precedentNom and garde("Retour " .. precedentNom) then
			ordre += 1
			ajouterElement("Retour : " .. precedentNom, { type = "precedent", nom = precedentNom }, ordre)
		end
		local index = 0
		for ligne in string.gmatch(exterieur:GetAttribute("Historique") or "", "[^\n]+") do
			local nom, x, y, z = string.match(ligne, "^(.-)\t([%-%d%.]+)\t([%-%d%.]+)\t([%-%d%.]+)$")
			if nom and garde(nom) then
				index += 1
				ordre += 1
				ajouterElement(nom, { type = "historique", index = index, nom = nom, cframe = CFrame.new(tonumber(x), tonumber(y), tonumber(z)),
					sous = string.format("Voyage n°%d  ·  %d, %d, %d", index, tonumber(x), tonumber(y), tonumber(z)) }, ordre)
			end
		end
	end
	if S.mode == "joueurs" then
		local joueurs = Players:GetPlayers()
		table.sort(joueurs, function(a, b) return a.DisplayName:lower() < b.DisplayName:lower() end)
		for _, autre in joueurs do
			if garde(autre.DisplayName) or garde(autre.Name) then
				ordre += 1
				ajouterElement(autre.DisplayName .. (autre == joueur and "  (toi)" or ""),
					{ type = "joueur", id = autre.UserId, nom = autre.DisplayName, pseudo = autre.Name }, ordre)
			end
		end
	end
	W.listeVide.Text = (S.mode == "lieux" and (filtre == "" and "Aucun lieu.\nAjoute des Parts dans TARDIS_Destinations."
		or "Aucun lieu ne correspond.")) or (S.mode == "histo" and "Aucun voyage pour l'instant.") or "Aucun joueur ne correspond."
	W.listeVide.Visible = ordre == 0 and S.mode ~= "coord"

	if S.choix then
		local existe = (S.choix.type == "lieu" and noms[S.choix.nom])
			or (S.choix.type == "joueur" and Players:GetPlayerByUserId(S.choix.id))
			or (S.choix.type == "position" and S.positionPerso)
			or (S.choix.type == "precedent" and precedentNom)
			or (S.choix.type == "historique")
		if not existe then S.choix = nil end
	end
	majInterface()
end

local POSITIONS_SEGMENT = { lieux = 0, joueurs = 1, coord = 2, histo = 3 }
local function changerMode(nouveau)
	S.mode = nouveau
	animer(W.curseur, 0.25, { Position = UDim2.new(POSITIONS_SEGMENT[nouveau] / 4, 3, 0, 3) })
	for nom, bouton in W.segments3 do
		bouton.TextColor3 = nom == nouveau and C.texte or C.texte2
	end
	local enCoord = nouveau == "coord"
	W.liste.Visible = not enCoord
	W.recherche.Visible = not enCoord
	W.panneauCoord.Visible = enCoord
	if enCoord and S.positionPerso then
		S.choix = { type = "position", nom = "Nouvelle localisation" }
	end
	construireListe()
end
for nom, bouton in W.segments3 do
	bouton.Activated:Connect(function() changerMode(nom) end)
end
W.recherche:GetPropertyChangedSignal("Text"):Connect(construireListe)
W.boutonCategorie.Activated:Connect(function()
	if not (S.choix and S.choix.type == "lieu") then return end
	local index = (S.categories[S.choix.nom] or 0) + 1
	if index > #(Config.Categories or {}) then index = 0 end
	remote:FireServer("Categorie", { destination = S.choix.nom, index = index })
end)

local function choisirFiger(valeur)
	S.figer = valeur
	animer(W.curseurJoueur, 0.25, { Position = valeur and UDim2.new(0.5, 1, 0, 2) or UDim2.fromOffset(2, 2) })
	W.boutonDernierePos.TextColor3 = valeur and C.texte2 or C.texte
	W.boutonSurLui.TextColor3 = valeur and C.texte or C.texte2
	majFiche()
end
W.boutonDernierePos.Activated:Connect(function() choisirFiger(false) end)
W.boutonSurLui.Activated:Connect(function() choisirFiger(true) end)

--------------------------------------------------------------------
-- Commandes
--------------------------------------------------------------------
-- Destination choisie, au format attendu par le serveur (nil si rien n'est choisi)
local function optionsDestination()
	return { figer = S.figer, positionPerso = S.positionPerso }
end
local function donneesDestination()
	return Commandes.donnees(S.choix, optionsDestination())
end

-- La destination choisie est partagée avec les commandes de port (bouton DÉMAT quand on porte le TARDIS)
task.spawn(function()
	local derniereCle = nil
	while true do
		task.wait(0.2)
		local cle = cleDe(S.choix)
		if cle ~= derniereCle then
			derniereCle = cle
			if S.choix then UI.destinationPoche = { fournir = donneesDestination, nom = S.choix.nom or "?" } end
		end
	end
end)

W.demat.Activated:Connect(function()
	if W.demat:GetAttribute("Disponible") == false then
		if exterieur:GetAttribute("Porteur") == joueur.UserId and not S.choix then
			notifier("Choisis d'abord une destination.", false)
		end
		return
	end
	Commandes.demat(S.choix, optionsDestination())
end)

W.remat.Activated:Connect(function()
	-- Pendant le compte à rebours de la rematérialisation automatique, un appui la lance tout de suite
	if not Commandes.secondesAutoRemat() and W.remat:GetAttribute("Disponible") == false then
		if (exterieur:GetAttribute("Etat") or E.Pose) == E.Vol and not S.choix then
			notifier("Choisis d'abord une destination.", false)
		end
		return
	end
	Commandes.remat(S.choix, optionsDestination())
end)

W.tuiles.camouflage.bouton.Activated:Connect(function()
	if W.tuiles.camouflage.bouton:GetAttribute("Disponible") == false then return end
	remote:FireServer("Camouflage")
end)
W.tuiles.verrou.bouton.Activated:Connect(function()
	remote:FireServer("Verrou")
end)
W.tuiles.portes.bouton.Activated:Connect(function()
	if W.tuiles.portes.bouton:GetAttribute("Disponible") == false then return end
	remote:FireServer("Portes")
end)

remote.OnClientEvent:Connect(notifier)
Commandes.annonce.Event:Connect(notifier)

-- Curseur de taille
local function afficherTaille(facteur)
	local p = (facteur - TAILLE_MIN) / (1 - TAILLE_MIN)
	W.remplissageTaille.Size = UDim2.fromScale(p, 1)
	W.poignee.Position = UDim2.fromScale(p, 0.5)
	W.valeurTaille.Text = math.floor(facteur * 100 + 0.5) .. " %"
	W.valeurTaille.TextColor3 = (facteur < seuilPortes - 0.001) and C.orange or C.ambre
end

local function facteurDepuisSouris(x)
	local debut, largeur = W.railTaille.AbsolutePosition.X, W.railTaille.AbsoluteSize.X
	local p = math.clamp((x - debut) / math.max(largeur, 1), 0, 1)
	return math.floor((TAILLE_MIN + p * (1 - TAILLE_MIN)) * 20 + 0.5) / 20 -- par pas de 5 %
end

W.pisteTaille.InputBegan:Connect(function(input)
	if W.pisteTaille:GetAttribute("Disponible") == false then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		S.glisseTaille = true
		animer(W.poignee, 0.15, { Size = UDim2.fromOffset(22, 22) })
		S.tailleChoisie = facteurDepuisSouris(input.Position.X)
		afficherTaille(S.tailleChoisie)
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if not S.glisseTaille then return end
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		S.tailleChoisie = facteurDepuisSouris(input.Position.X)
		afficherTaille(S.tailleChoisie)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if not S.glisseTaille then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		S.glisseTaille = false
		animer(W.poignee, 0.15, { Size = UDim2.fromOffset(18, 18) })
		if math.abs(S.tailleChoisie - (exterieur:GetAttribute("Echelle") or 1)) > 0.01 then
			remote:FireServer("Taille", { facteur = S.tailleChoisie })
		end
	end
end)
exterieur:GetAttributeChangedSignal("Echelle"):Connect(function()
	if not S.glisseTaille then
		S.tailleChoisie = exterieur:GetAttribute("Echelle") or 1
		afficherTaille(S.tailleChoisie)
	end
end)
afficherTaille(exterieur:GetAttribute("Echelle") or 1)

--------------------------------------------------------------------
-- Ouverture / fermeture (animées)
--------------------------------------------------------------------
local function echelleBase()
	local ecran = camera.ViewportSize
	local largeur = R.LARGEUR + (V.actif and LARGEUR_VOLET or 0) -- volet ouvert : il faut aussi lui faire de la place
	return math.clamp(math.min(ecran.X * 0.95 / largeur, ecran.Y * 0.92 / R.HAUTEUR), 0.4, 1.25) * UI.tailleInterface()
end
-- Disposition : échelle de la tablette, et décalage vers la gauche quand le volet est ouvert
local function majDisposition()
	local echelle = echelleBase()
	W.echelle.Scale = echelle
	W.tablette.Position = UDim2.new(0.5, V.actif and -(LARGEUR_VOLET * echelle) / 2 or 0, 0.5, 0)
end
V.majDisposition = majDisposition

-- Widgets : les panneaux masqués libèrent leur place, les autres remontent dans leur colonne
local function appliquerWidgets()
	local colonnes = {}
	for _, p in W.panneauxListe do
		colonnes[p.x] = colonnes[p.x] or {}
		table.insert(colonnes[p.x], p)
	end
	for _, liste in colonnes do
		table.sort(liste, function(a, b) return a.y < b.y end)
		local y = liste[1].y
		for _, p in liste do
			local visible = UI.widgetVisible(p.widget)
			p.cadre.Visible = visible
			if visible then
				p.cadre.Position = UDim2.fromOffset(p.x, y)
				y += p.hauteur + 12
			end
		end
	end
end
UI.prefsChangees.Event:Connect(function(cle)
	if cle == "widgets" or cle == "debutant" then appliquerWidgets() end
	if cle == "taille" and S.ouvert then majDisposition() end
	if cle == "tri" then construireListe() end
end)
appliquerWidgets()

local function ouvrir()
	if S.ouvert or joueur:GetAttribute("TardisPilote_" .. def.Nom) ~= true then
		if joueur:GetAttribute("TardisPilote_" .. def.Nom) ~= true then joueur:SetAttribute("TardisTablette", false) end
		return
	end
	S.ouvert = true
	W.gui.Enabled = true
	W.voile.Visible = true
	W.tablette.Visible = true
	W.voile.BackgroundTransparency = 1
	animer(W.voile, 0.35, { BackgroundTransparency = 0.45 })
	W.flou.Enabled = true
	animer(W.flou, 0.45, { Size = 18 })

	local base = echelleBase()
	W.echelle.Scale = base * 0.86
	W.tablette.Position = UDim2.fromScale(0.5, 0.57)
	animer(W.echelle, 0.55, { Scale = base }, Enum.EasingStyle.Back)
	animer(W.tablette, 0.55, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Back)
	-- Les panneaux arrivent les uns après les autres
	for i, cadre in panneaux do
		local echelle = cadre:FindFirstChildOfClass("UIScale")
		echelle.Scale = 0.9
		animer(echelle, 0.45, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0.1 + i * 0.04)
	end
	-- Ligne de balayage qui traverse l'écran
	W.balayageEcran.Position = UDim2.new(0, 0, 0, -4)
	animer(W.balayageEcran, 0.9, { Position = UDim2.new(0, 0, 1, 4) }, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0.15)

	joueur:SetAttribute("TardisTablette", true)
	construireListe()
end

local function fermer(garderAttribut)
	if not S.ouvert then return end
	S.ouvert = false
	W.recherche:ReleaseFocus()
	animer(W.voile, 0.25, { BackgroundTransparency = 1 })
	animer(W.flou, 0.3, { Size = 0 })
	animer(W.echelle, 0.25, { Scale = echelleBase() * 0.9 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	animer(W.tablette, 0.25, { Position = UDim2.fromScale(0.5, 0.56) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(0.26, function()
		if S.ouvert then return end
		W.tablette.Visible = false
		W.voile.Visible = false
		W.flou.Enabled = false
	end)
	if not garderAttribut then joueur:SetAttribute("TardisTablette", false) end
end

W.fermer.Activated:Connect(function() fermer() end)
-- Le voile ne ferme rien : seule la croix rouge en haut à droite ferme la tablette

-- Boucliers
W.boutonBoucliers.Activated:Connect(function()
	if W.boutonBoucliers:GetAttribute("Disponible") == false then return end
	W.choixBoucliers.Visible = not W.choixBoucliers.Visible
end)

-- Vol libre : la tablette se range pour laisser voir le TARDIS
W.tuiles.volLibre.bouton.Activated:Connect(function()
	if W.tuiles.volLibre.bouton:GetAttribute("Disponible") == false then return end
	remote:FireServer("VolLibreDebut")
	task.delay(0.15, function() fermer() end)
end)


joueur:GetAttributeChangedSignal("TardisTablette"):Connect(function()
	if joueur:GetAttribute("TardisTablette") then ouvrir() else fermer(true) end
end)

--------------------------------------------------------------------
-- Placement d'une nouvelle localisation (fantôme du TARDIS)
--------------------------------------------------------------------
do
	local hud = creer("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(500, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.fond, Visible = false,
		Parent = W.gui }, { UI.coin(14), UI.contour(C.ambre, 1.5, 0.3), UI.marges(12), UI.pile(8) })
	W.echelleHud = creer("UIScale", { Parent = hud })
	local hudTitre = texte({ Text = "", Font = UI.POLICE_GRAS, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 1, Parent = hud })
	texte({ Text = "Clique dans le monde pour placer · Q/E : tourner · R/F : incliner · Entrée : valider", TextSize = 12,
		TextColor3 = C.texte2, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = hud })
	local rangee = creer("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, LayoutOrder = 3, Parent = hud },
	{ creer("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }) })
	local function bouton(txt, largeur, couleur, ordre)
		local b = creer("TextButton", { Size = UDim2.fromOffset(largeur, 36), BackgroundColor3 = couleur, Text = txt,
			Font = UI.POLICE_GRAS, TextSize = 13, TextColor3 = C.texte, LayoutOrder = ordre, Parent = rangee }, { UI.coin(8) })
		b:SetAttribute("CouleurBase", couleur)
		UI.rendreVivant(b)
		return b
	end
	local bGauche = bouton("◄ 15°", 64, C.panneauClair, 1)
	local bDroite = bouton("► 15°", 64, C.panneauClair, 2)
	local bHaut = bouton("▲ 5°", 58, C.panneauClair, 3)
	local bBas = bouton("▼ 5°", 58, C.panneauClair, 4)
	local bValider = bouton("Valider", 96, C.bleu, 5)
	local bAnnuler = bouton("Annuler", 96, Color3.fromRGB(110, 40, 50), 6)

	local function testerCollision(cible)
		local taille = exterieur:GetExtentsSize()
		local hauteurRacine = exterieur.PrimaryPart.Size.Y / 2
		local marge = 0.4
		local centre = cible * CFrame.new(0, taille.Y / 2 - hauteurRacine + marge / 2, 0)
		local exclus = { exterieur, interieur }
		if S.placement and S.placement.fantome then table.insert(exclus, S.placement.fantome) end
		for _, autre in Players:GetPlayers() do
			if autre.Character then table.insert(exclus, autre.Character) end
		end
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = exclus
		params.RespectCanCollide = true
		local reduite = Vector3.new(math.max(taille.X - marge, 0.1), math.max(taille.Y - marge, 0.1), math.max(taille.Z - marge, 0.1))
		return #workspace:GetPartBoundsInBox(centre, reduite, params) > 0
	end

	local function majPlacement()
		local p = S.placement
		if not p or not p.point then return end
		p.cframe = CFrame.new(p.point + Vector3.new(0, exterieur.PrimaryPart.Size.Y / 2, 0))
			* CFrame.Angles(0, math.rad(p.yaw), 0) * CFrame.Angles(math.rad(p.pitch), 0, 0)
		p.fantome:PivotTo(p.cframe)
		p.collision = testerCollision(p.cframe)
		p.surbrillance.FillColor = p.collision and C.rouge or C.vert
		p.surbrillance.OutlineColor = p.collision and C.rouge or C.vert
		hudTitre.Text = string.format("%s  ·  rotation %d°  ·  inclinaison %d°",
			p.collision and "▲ Collision : urgence automatique" or "Zone libre", p.yaw % 360, p.pitch)
		hudTitre.TextColor3 = p.collision and C.rouge or C.vert
	end

	local function quitter()
		if not S.placement then return end
		if S.placement.fantome then S.placement.fantome:Destroy() end
		S.placement = nil
		hud.Visible = false
		-- On rouvre la tablette
		S.ouvert = false
		ouvrir()
	end

	local function demarrer()
		if S.placement then return end
		local ancien = exterieur.Archivable
		exterieur.Archivable = true
		local fantome = exterieur:Clone()
		exterieur.Archivable = ancien
		if not fantome then
			notifier("Impossible de créer l'aperçu du TARDIS.", false)
			return
		end
		for _, objet in fantome:GetDescendants() do
			if objet:IsA("LuaSourceContainer") or objet:IsA("Sound") or objet:IsA("ProximityPrompt") or objet:IsA("ClickDetector")
				or objet:IsA("Light") or objet:IsA("LayerCollector") or objet:IsA("ParticleEmitter") then
				objet:Destroy()
			elseif objet:IsA("BasePart") then
				objet.Anchored, objet.CanCollide, objet.CanQuery, objet.CanTouch = true, false, false, false
				objet.Transparency = (objet == fantome.PrimaryPart or objet.Name == Config.NomPortailExt) and 1 or 0.55
			elseif objet:IsA("Decal") then
				objet.Transparency = 0.55
			end
		end
		fantome.Name = "TardisFantome"
		local surbrillance = creer("Highlight", { FillTransparency = 0.7, OutlineTransparency = 0,
			DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Parent = fantome })
		fantome.Parent = workspace
		S.placement = { fantome = fantome, surbrillance = surbrillance, yaw = 0, pitch = 0,
			point = exterieur:GetPivot().Position - Vector3.new(0, exterieur.PrimaryPart.Size.Y / 2, 0) }

		-- La tablette s'efface pendant le placement
		S.ouvert = false
		W.tablette.Visible = false
		W.voile.Visible = false
		W.flou.Enabled = false
		hud.Visible = true
		majPlacement()
	end

	local function viser(positionEcran)
		local p = S.placement
		if not p then return end
		local rayon = camera:ViewportPointToRay(positionEcran.X, positionEcran.Y)
		local exclus = { exterieur, interieur, p.fantome }
		for _, autre in Players:GetPlayers() do
			if autre.Character then table.insert(exclus, autre.Character) end
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = exclus
		local resultat = workspace:Raycast(rayon.Origin, rayon.Direction * 2000, params)
		if resultat then
			p.point = resultat.Position
			majPlacement()
		end
	end

	local function valider()
		local p = S.placement
		if not p or not p.cframe then return end
		S.positionPerso = { cframe = p.cframe, collision = p.collision }
		local pos = p.cframe.Position
		W.infoPlacement.Text = string.format("X %d   Y %d   Z %d\nRotation %d°  ·  inclinaison %d°%s",
			pos.X, pos.Y, pos.Z, p.yaw % 360, p.pitch, p.collision and "\n▲ Collision : atterrissage en urgence." or "")
		W.infoPlacement.TextColor3 = p.collision and C.orange or C.cyan
		S.choix = { type = "position", nom = "Nouvelle localisation" }
		quitter()
		notifier("Nouvelle localisation enregistrée.", true)
	end

	local function tourner(dYaw, dPitch)
		local p = S.placement
		if not p then return end
		p.yaw += dYaw
		p.pitch = math.clamp(p.pitch + dPitch, -90, 90)
		majPlacement()
	end

	W.boutonPlacer.Activated:Connect(demarrer)
	bGauche.Activated:Connect(function() tourner(-15, 0) end)
	bDroite.Activated:Connect(function() tourner(15, 0) end)
	bHaut.Activated:Connect(function() tourner(0, 5) end)
	bBas.Activated:Connect(function() tourner(0, -5) end)
	bValider.Activated:Connect(valider)
	bAnnuler.Activated:Connect(quitter)

	UserInputService.InputBegan:Connect(function(input, traite)
		if traite or not S.placement then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			viser(Vector2.new(input.Position.X, input.Position.Y) + GuiService:GetGuiInset())
		elseif input.KeyCode == Enum.KeyCode.Q then tourner(-15, 0)
		elseif input.KeyCode == Enum.KeyCode.E then tourner(15, 0)
		elseif input.KeyCode == Enum.KeyCode.R then tourner(0, 5)
		elseif input.KeyCode == Enum.KeyCode.F then tourner(0, -5)
		elseif input.KeyCode == Enum.KeyCode.Return then valider()
		end
	end)
end

--------------------------------------------------------------------
-- Réglages (thème de l'interface, sons, touches) et aide intégrée
--------------------------------------------------------------------
-- Volet latéral : un panneau qui s'ouvre à droite de la tablette (outils, réglages, aide).
-- V.ouvrir(nom, titre) affiche une page vide et renvoie son conteneur ; V.retour() revient aux outils ; V.fermer() le range.
do
	local volet = creer("Frame", { Position = UDim2.new(1, 14, 0, 0), Size = UDim2.new(0, 440, 1, 0), BackgroundColor3 = C.ecran,
		BackgroundTransparency = 0.02, Visible = false, ZIndex = 60, Parent = W.tablette }, { UI.coin(22), UI.contour(C.ambre, 2, 0.25), UI.marges(16) })
	creer("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.blanc, Color3.fromRGB(170, 180, 205)), Parent = volet })
	local titre = texte({ Text = "", Font = UI.POLICE_GRAS, TextSize = 16, TextColor3 = C.ambre, Size = UDim2.new(1, -40, 0, 24), ZIndex = 61, Parent = volet })
	local croix = creer("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, -4), Size = UDim2.fromOffset(32, 32),
		BackgroundColor3 = Color3.fromRGB(90, 30, 40), Text = "×", Font = UI.POLICE_GRAS, TextSize = 22, TextColor3 = C.texte, ZIndex = 61, Parent = volet },
	{ UI.coin(9), UI.contour(C.rouge, 1, 0.4) })
	croix:SetAttribute("CouleurBase", Color3.fromRGB(90, 30, 40))
	UI.rendreVivant(croix)
	-- Accueil : la grille des outils
	local accueil = creer("ScrollingFrame", { Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 1, -34), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 5, ScrollBarImageColor3 = C.ambre, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 61, Parent = volet })
	local grille = creer("Frame", { Size = UDim2.new(1, -12, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ZIndex = 61, Parent = accueil },
	{ UI.pile(8) })
	-- Pages : le contenu d'un outil, des réglages ou de l'aide
	local defilement = creer("ScrollingFrame", { Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 1, -76), BackgroundTransparency = 1,
		BorderSizePixel = 0, ScrollBarThickness = 5, ScrollBarImageColor3 = C.ambre, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false, ZIndex = 61, Parent = volet })
	local contenu = creer("Frame", { Size = UDim2.new(1, -12, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
		ZIndex = 61, Parent = defilement }, { UI.pile(8) })
	local retourBtn = creer("TextButton", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = C.panneauClair, Text = "◄  Retour aux outils", Font = UI.POLICE_GRAS, TextSize = 13, TextColor3 = C.texte, Visible = false,
		ZIndex = 61, Parent = volet }, { UI.coin(8) })
	retourBtn:SetAttribute("CouleurBase", C.panneauClair)
	UI.rendreVivant(retourBtn)
	local surcouche = volet
	V.grille = grille
	V.actif = nil

	local function vider()
		for _, e in contenu:GetChildren() do
			if not e:IsA("UIListLayout") then e:Destroy() end
		end
	end
	function V.ouvrir(nom, nouveauTitre)
		vider()
		titre.Text = nouveauTitre or ""
		accueil.Visible = false
		defilement.Visible = true
		retourBtn.Visible = true
		volet.Visible = true
		V.actif = nom
		V.majDisposition()
		return contenu
	end
	function V.retour()
		vider()
		titre.Text = "◆  OUTILS DU TARDIS"
		accueil.Visible = true
		defilement.Visible = false
		retourBtn.Visible = false
		volet.Visible = true
		V.actif = "outils"
		V.majDisposition()
	end
	function V.fermer()
		volet.Visible = false
		V.actif = nil
		V.majDisposition()
	end
	croix.Activated:Connect(V.fermer)
	retourBtn.Activated:Connect(V.retour)
	W.btnOutils.Activated:Connect(function() if V.actif == "outils" then V.fermer() else V.retour() end end)
	W.boutonOutilsDock.Activated:Connect(V.retour)

	local function ligne(txt, ordre, couleur, taille)
		return texte({ Text = txt, TextSize = taille or 13, TextColor3 = couleur or C.texte, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = ordre, ZIndex = 62, Parent = contenu })
	end
	local function boutonLigne(txt, ordre, couleur, action)
		local b = creer("TextButton", { Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = couleur or C.panneauClair, Text = txt, Font = UI.POLICE_GRAS,
			TextSize = 13, TextColor3 = C.texte, LayoutOrder = ordre, ZIndex = 62, Parent = contenu }, { UI.coin(8) })
		b:SetAttribute("CouleurBase", couleur or C.panneauClair)
		UI.rendreVivant(b)
		b.Activated:Connect(action)
		return b
	end
	V.ligne, V.bouton = ligne, boutonLigne
	local function ligne(txt, ordre, couleur, taille)
		return texte({ Text = txt, TextSize = taille or 13, TextColor3 = couleur or C.texte, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = ordre, ZIndex = 62, Parent = contenu })
	end
	local function boutonLigne(txt, ordre, couleur, action)
		local b = creer("TextButton", { Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = couleur or C.panneauClair, Text = txt, Font = UI.POLICE_GRAS,
			TextSize = 13, TextColor3 = C.texte, LayoutOrder = ordre, ZIndex = 62, Parent = contenu }, { UI.coin(8) })
		b:SetAttribute("CouleurBase", couleur or C.panneauClair)
		UI.rendreVivant(b)
		b.Activated:Connect(action)
		return b
	end

	local TOUCHES = {
		{ "menu", "Ouvrir le menu classique", "T" }, { "tablette", "Ouvrir la tablette", "Y" },
		{ "porterMode", "Porter : changer de mode", "V" }, { "porterPoser", "Porter : poser", "G" }, { "porterDemat", "Porter : téléportation de poche", "X" },
		{ "volVitesse", "Vol : vitesse suivante", "F" }, { "volUrgence", "Vol : urgence", "U" }, { "volVortex", "Vol : vortex", "V" },
		{ "volSaut", "Vol : saut temporel", "B" }, { "volPortes", "Vol : portes", "O" }, { "volDemat", "Vol : démat / remat", "X" },
		{ "volPoser", "Vol : se poser", "G" }, { "volTonneau", "Vol : tonneau", "C" }, { "volFrein", "Vol : frein", "LeftControl" },
		{ "volTracteur", "Vol : rayon tracteur", "R" }, { "volCamouflage", "Vol : camouflage", "K" },
		{ "volStationnaire", "Vol : stationnaire", "H" }, { "volSiege", "Vol : siège extérieur", "I" }, { "volBoost", "Vol : boost", "LeftShift" },
		{ "volAtterrir", "Vol : atterrir ici", "N" }, { "volPlaneur", "Vol : planeur", "J" }, { "volCible", "Vol : verrouillage de cible", "L" },
		{ "volPrecision", "Vol : précision", "P" }, { "volCap", "Vol : cap fixe", "M" },
	}
	local enAttente = nil
	local afficherReglages
	afficherReglages = function()
		V.ouvrir("reglages", "RÉGLAGES")
		local ordre = 0
		-- Taille de l'interface
		ordre += 1
		ligne("TAILLE DE L'INTERFACE", ordre, C.texte2, 11)
		ordre += 1
		local rangeeTaille = creer("Frame", { Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, LayoutOrder = ordre, ZIndex = 62, Parent = contenu },
		{ creer("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
		for i, info in { { "-", -0.1 }, { "Normale", 0 }, { "+", 0.1 } } do
			local b = creer("TextButton", { Size = UDim2.new(info[2] == 0 and 0.5 or 0.25, -6, 1, 0), BackgroundColor3 = C.panneauClair,
				Text = info[2] == 0 and string.format("Normale  ·  %d %%", UI.tailleInterface() * 100) or info[1], Font = UI.POLICE_GRAS, TextSize = 13,
				TextColor3 = C.texte, LayoutOrder = i, ZIndex = 62, Parent = rangeeTaille }, { UI.coin(8) })
			b:SetAttribute("CouleurBase", C.panneauClair)
			UI.rendreVivant(b)
			b.Activated:Connect(function()
				UI.setPref("taille", info[2] == 0 and 1 or math.clamp(UI.tailleInterface() + info[2], 0.6, 1.4))
				afficherReglages()
			end)
		end
		-- Volume
		ordre += 1
		ligne("VOLUME DES SONS DU TARDIS", ordre, C.texte2, 11)
		ordre += 1
		local rangeeVolume = creer("Frame", { Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, LayoutOrder = ordre, ZIndex = 62, Parent = contenu },
		{ creer("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
		for i, niveau in { 0, 0.25, 0.5, 0.75, 1 } do
			local b = creer("TextButton", { Size = UDim2.new(0.2, -5, 1, 0), BackgroundColor3 = math.abs(UI.volume() - niveau) < 0.01 and C.bleu or C.panneauClair,
				Text = string.format("%d %%", niveau * 100), Font = UI.POLICE_GRAS, TextSize = 12, TextColor3 = C.texte, LayoutOrder = i, ZIndex = 62,
				Parent = rangeeVolume }, { UI.coin(8) })
			b:SetAttribute("CouleurBase", b.BackgroundColor3)
			UI.rendreVivant(b)
			b.Activated:Connect(function() UI.setPref("volume", niveau) afficherReglages() end)
		end
		-- Options
		ordre += 1
		ligne("OPTIONS", ordre, C.texte2, 11)
		ordre += 1
		boutonLigne(UI.pref("confirmations", true) ~= false and "Confirmation des actions dangereuses : activée" or "Confirmation des actions dangereuses : désactivée",
			ordre, nil, function() UI.setPref("confirmations", UI.pref("confirmations", true) == false) afficherReglages() end)
		ordre += 1
		boutonLigne(UI.pref("debutant", false) and "Mode débutant : activé (l'essentiel seulement)" or "Mode débutant : désactivé", ordre,
			UI.pref("debutant", false) and C.bleu or nil, function() UI.setPref("debutant", not UI.pref("debutant", false)) afficherReglages() end)
		ordre += 1
		boutonLigne(UI.pref("modeVoyage", "auto") == "auto" and "Mode de voyage : automatique (destination, DEMAT, 15 s de vortex, REMAT seul)"
			or "Mode de voyage : manuel (DEMAT, choix dans le vortex, REMAT)", ordre, nil,
			function() UI.setPref("modeVoyage", UI.pref("modeVoyage", "auto") == "auto" and "manuel" or "auto") Commandes.annulerAutoRemat() afficherReglages() end)
		ordre += 1
		boutonLigne(UI.pref("tri", "nom") == "distance" and "Tri des lieux : par distance" or "Tri des lieux : par nom", ordre, nil,
			function() UI.setPref("tri", UI.pref("tri", "nom") == "distance" and "nom" or "distance") afficherReglages() end)
		ordre += 1
		local formes = { grille = "grille", anneaux = "anneaux", spirale = "spirale" }
		local forme = UI.pref("formeVortex", "grille")
		boutonLigne("Forme du vortex : " .. (formes[forme] or "grille") .. "  (clique pour changer)", ordre, nil, function()
			local suivante = { grille = "anneaux", anneaux = "spirale", spirale = "grille" }
			UI.setPref("formeVortex", suivante[forme] or "grille")
			afficherReglages()
		end)
		-- Widgets
		ordre += 1
		ligne("PANNEAUX AFFICHÉS (WIDGETS)", ordre, C.texte2, 11)
		local nomsWidgets = { statut = "Statut", telemetrie = "Télémétrie", flux = "Commandes rapides", navigation = "Navigation", scanner = "Scanner",
			occupants = "Occupants", journal = "Journal de bord" }
		for _, nom in UI.WIDGETS do
			ordre += 1
			local actif = type(UI.prefs.widgets) ~= "table" or UI.prefs.widgets[nom] ~= false
			boutonLigne((actif and "●  " or "○  ") .. nomsWidgets[nom], ordre, actif and C.panneauClair or C.fond, function()
				UI.prefs.widgets = type(UI.prefs.widgets) == "table" and UI.prefs.widgets or {}
				UI.prefs.widgets[nom] = not actif
				UI.setPref("widgets", UI.prefs.widgets)
				afficherReglages()
			end)
		end
		-- Statistiques
		ordre += 1
		ligne("STATISTIQUES", ordre, C.texte2, 11)
		local ok, st = pcall(function() return game:GetService("HttpService"):JSONDecode(joueur:GetAttribute("TardisStats") or "{}") end)
		st = ok and type(st) == "table" and st or {}
		local passagers = {}
		for nom in st.passagers or {} do table.insert(passagers, nom) end
		table.sort(passagers)
		ordre += 1
		ligne(string.format("Mes voyages : %d   ·   Temps de vol libre : %s   ·   Voyages sur le serveur : %d",
			st.voyages or 0, UI.formatTemps(st.tempsVol or 0), exterieur:GetAttribute("StatsServeur") or 0), ordre, C.texte, 12)
		ordre += 1
		ligne("Ont voyagé avec moi : " .. (#passagers > 0 and table.concat(passagers, ", ") or "personne pour l'instant"), ordre, C.texte2, 12)
		ordre += 1
		ligne("THÈME DE L'INTERFACE", ordre, C.texte2, 11)
		-- (le volet est déjà visible)
		for _, nom in UI.ORDRE_THEMES do
			ordre += 1
			boutonLigne(UI.THEMES[nom].nom or nom, ordre, UI.pref("theme", "Cristal") == nom and C.bleu or nil, function()
				UI.appliquerTheme(nom)
				UI.setPref("theme", nom)
				afficherReglages()
			end)
		end
		ordre += 1
		ligne("SONS", ordre, C.texte2, 11)
		ordre += 1
		boutonLigne(UI.pref("sons", true) and "Sons de notification : activés" or "Sons de notification : coupés", ordre, nil, function()
			UI.setPref("sons", not UI.pref("sons", true))
			afficherReglages()
		end)
		ordre += 1
		ligne("TOUCHES  ·  clique sur une ligne puis appuie sur la nouvelle touche (Échap pour annuler)", ordre, C.texte2, 11)
		for _, info in TOUCHES do
			ordre += 1
			local actuelle = UI.touche(info[1], Enum.KeyCode[info[3]])
			local b
			b = boutonLigne(info[2] .. "   ·   " .. actuelle.Name, ordre, nil, function()
				enAttente = info[1]
				b.Text = info[2] .. "   ·   appuie sur une touche…"
			end)
		end
		ordre += 1
		boutonLigne("Rétablir les touches par défaut", ordre, Color3.fromRGB(110, 40, 50), function()
			UI.prefs.touches = {}
			UI.sauverPrefs()
			afficherReglages()
		end)
	end
	UserInputService.InputBegan:Connect(function(input)
		if not enAttente or input.UserInputType ~= Enum.UserInputType.Keyboard then return end
		if input.KeyCode ~= Enum.KeyCode.Escape and input.KeyCode ~= Enum.KeyCode.Unknown then
			UI.setTouche(enAttente, input.KeyCode)
		end
		enAttente = nil
		afficherReglages()
	end)
	W.btnReglages.Activated:Connect(afficherReglages)

	-- Export du journal : du markdown à sélectionner puis copier avec Ctrl+C
	W.exporter.Activated:Connect(function()
		V.ouvrir("export", "JOURNAL DE BORD  ·  EXPORT")
		ligne("Clique dans la zone, Ctrl+A puis Ctrl+C pour copier.", 1, C.texte2, 11)
		local lignesMd = { "# Journal de bord du TARDIS", "", "| Heure | Événement |", "|---|---|" }
		for i = #S.journalEntrees, 1, -1 do
			local e = S.journalEntrees[i]
			table.insert(lignesMd, string.format("| %s | %s |", e.heure, e.message))
		end
		creer("TextBox", { Size = UDim2.new(1, 0, 0, 420), BackgroundColor3 = C.fond, Text = table.concat(lignesMd, "\n"), TextEditable = false,
			ClearTextOnFocus = false, MultiLine = true, TextWrapped = true, Font = UI.POLICE_CODE, TextSize = 11, TextColor3 = C.texte,
			TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 2, ZIndex = 62, Parent = contenu },
		{ UI.coin(8), UI.contour(C.bleu, 1, 0.5), creer("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingTop = UDim.new(0, 6) }) })
	end)

	W.btnAide.Activated:Connect(function()
		V.ouvrir("aide", "AIDE")
		local aide = {
			{ "MENUS", "T : menu classique · Y : tablette (la croix rouge la ferme) · E sur la console et devant les portes." },
			{ "VOYAGER", "Choisis une destination (lieu, joueur, coordonnées, historique, retour), puis Dématérialiser et Matérialiser. Urgence et Invisible sont des options." },
			{ "PORTER", "Quand il est réduit : E pour le ramasser, V pour changer de mode, G pour le poser, X pour la téléportation de poche vers la destination choisie." },
			{ "VOL LIBRE", "Tuile Vol libre. Regarde où tu veux aller. F vitesse · U urgence · V vortex · B saut · O portes · X démat/remat · C tonneau · Ctrl frein · R rayon tracteur · Espace ×2 chute · G se poser." },
			{ "ROTATION", "Tuile Rotation du menu : positionne le fantôme, puis DÉMAT + REMAT AUTO. Fantôme rouge = atterrissage d'urgence." },
			{ "OUTILS", "Rappel, minuterie, leurre, fiche d'anomalie, registre et expulsion, thème de l'intérieur, projecteur, cabine, replay : dans le menu classique, section Outils." },
			{ "BALISE", "N'importe quel joueur peut appeler le TARDIS avec la commande " .. ((Config.Balise or {}).Commande or "/balisehelp") .. " dans le chat. Les pilotes la voient sur la mini-carte." },
			{ "BOUCLIERS", "Anti-joueurs (personne n'approche) et anti-balles (les tirs s'arrêtent). TARDIS posé et alimenté uniquement." },
		}
		for i, bloc in aide do
			ligne(bloc[1], i * 2 - 1, C.ambre, 11)
			ligne(bloc[2], i * 2, C.texte, 12)
		end
	end)
end

-- Touche Y : ouvre la tablette. Seule la croix rouge la ferme.
UserInputService.InputBegan:Connect(function(input, traite)
	if traite or S.placement or input.KeyCode ~= UI.touche("tablette", R.TOUCHE) then return end
	if joueur:GetAttribute("TardisPilote_" .. def.Nom) ~= true or exterieur:GetAttribute("VolLibre") == joueur.UserId then return end
	if not S.ouvert then ouvrir() end
end)

--------------------------------------------------------------------
-- Scanner : points des joueurs
--------------------------------------------------------------------
local majScanner
do
	local function pointPour(autre)
		local point = S.points[autre]
		if point then return point end
		local cadre = creer("TextButton", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(10, 10),
			BackgroundColor3 = UI.couleurJoueur(autre, autre == joueur and C.cyan or C.ambre), Text = "", ZIndex = 5, Parent = W.calquePoints },
		{ UI.coin(99), UI.contour(C.blanc, 1, 0.6) })
		texte({ Text = autre.DisplayName, Font = UI.POLICE_CODE, TextSize = 10, AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 1, 2), Size = UDim2.fromOffset(90, 12), TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 5, Parent = cadre })
		cadre.Activated:Connect(function()
			S.choix = { type = "joueur", id = autre.UserId, nom = autre.DisplayName, pseudo = autre.Name }
			changerMode("joueurs")
			notifier("Destination : " .. autre.DisplayName .. ".", true)
		end)
		S.points[autre] = cadre
		return cadre
	end

	Players.PlayerRemoving:Connect(function(autre)
		if S.points[autre] then
			S.points[autre]:Destroy()
			S.points[autre] = nil
		end
	end)

	majScanner = function(e)
		local pivot = exterieur:GetPivot()
		local p = pivot.Position
		W.lectX.Text = string.format("%.1f", p.X)
		W.lectY.Text = string.format("%.1f", p.Y)
		W.lectZ.Text = string.format("%.1f", p.Z)
		local devant = pivot.LookVector
		W.lectCap.Text = string.format("%05.1f°", (math.deg(math.atan2(-devant.X, -devant.Z)) + 360) % 360)

		local horsService = e.etat == E.Vol or not e.alimente
		W.signalPerdu.Visible = horsService
		W.signalPerdu.Text = not e.alimente and "HORS TENSION\n— scanner éteint —" or "SIGNAL PERDU\n— dans le vortex —"

		local aPortee = 0
		for _, autre in Players:GetPlayers() do
			local racine = autre.Character and autre.Character:FindFirstChild("HumanoidRootPart")
			local cadre = pointPour(autre)
			local visible = false
			if racine and not horsService then
				local relatif = pivot:PointToObjectSpace(racine.Position)
				if Vector2.new(relatif.X, relatif.Z).Magnitude <= R.PORTEE then
					visible = true
					aPortee += 1
					cadre.Position = UDim2.fromScale(0.5 + relatif.X / (2 * R.PORTEE), 0.5 + relatif.Z / (2 * R.PORTEE))
					local choisi = S.choix and S.choix.type == "joueur" and S.choix.id == autre.UserId
					cadre.BackgroundColor3 = choisi and C.vert or (autre == joueur and C.cyan or C.ambre)
				end
			end
			cadre.Visible = visible
		end
		W.lectPortee.Text = horsService and "—" or (aPortee .. " joueur" .. (aPortee > 1 and "s" or ""))
	end
end

--------------------------------------------------------------------
-- Mini-carte : vue du dessus, nord en haut, zoom automatique (TARDIS, joueurs, destinations cliquables)
--------------------------------------------------------------------
local majCarte
do
	local cache, destinations = nil, {}

	local function lireDestinations()
		local brut = exterieur:GetAttribute("CarteDestinations") or ""
		if brut == cache then return destinations end
		cache, destinations = brut, {}
		for ligne in string.gmatch(brut, "[^\n]+") do
			local nom, x, z = string.match(ligne, "^(.-)\t([%-%d%.]+)\t([%-%d%.]+)$")
			if nom then table.insert(destinations, { nom = nom, x = tonumber(x), z = tonumber(z) }) end
		end
		for _, marqueur in S.marqueursCarte do marqueur:Destroy() end
		table.clear(S.marqueursCarte)
		for _, d in destinations do
			local marqueur = creer("TextButton", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(16, 16),
				BackgroundTransparency = 1, Text = "◆", Font = UI.POLICE_GRAS, TextSize = 13, TextColor3 = C.ambre, ZIndex = 4,
				Parent = W.calqueCarte })
			texte({ Text = d.nom, Font = UI.POLICE_CODE, TextSize = 9, TextColor3 = C.texte, TextXAlignment = Enum.TextXAlignment.Center,
				TextTruncate = Enum.TextTruncate.AtEnd, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 0),
				Size = UDim2.fromOffset(90, 10), ZIndex = 4, Parent = marqueur })
			marqueur.Activated:Connect(function()
				S.choix = { type = "lieu", nom = d.nom }
				changerMode("lieux")
				notifier("Destination : " .. d.nom .. ".", true)
			end)
			S.marqueursCarte[d.nom] = marqueur
		end
		return destinations
	end

	majCarte = function(e)
		local pivot = exterieur:GetPivot()
		local c = pivot.Position
		local liste = lireDestinations()

		-- Zoom automatique : toutes les destinations restent visibles
		local loin = 120
		for _, d in liste do
			loin = math.max(loin, math.abs(d.x - c.X), math.abs(d.z - c.Z))
		end
		S.porteeCarte += (math.clamp(loin * 1.15, 120, 5000) - S.porteeCarte) * 0.1
		local r = S.porteeCarte
		local function placer(x, z)
			return UDim2.fromScale(0.5 + (x - c.X) / (2 * r), 0.5 + (z - c.Z) / (2 * r))
		end

		for _, d in liste do
			local marqueur = S.marqueursCarte[d.nom]
			if marqueur then
				marqueur.Position = placer(d.x, d.z)
				local choisi = S.choix and S.choix.type == "lieu" and S.choix.nom == d.nom
				marqueur.TextColor3 = choisi and C.vert or C.ambre
			end
		end
		for _, autre in Players:GetPlayers() do
			local point = S.pointsCarte[autre]
			if not point then
				point = creer("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(6, 6),
					BackgroundColor3 = UI.couleurJoueur(autre, autre == joueur and C.cyan or C.blanc), ZIndex = 4, Parent = W.calqueCarte }, { UI.coin(99) })
				S.pointsCarte[autre] = point
			end
			local racine = autre.Character and autre.Character:FindFirstChild("HumanoidRootPart")
			point.Visible = racine ~= nil
			if racine then point.Position = placer(racine.Position.X, racine.Position.Z) end
		end

		-- Le TARDIS au centre, flèche dans la direction de sa porte
		local devant = pivot.LookVector
		W.tardisCarte.Rotation = math.deg(math.atan2(devant.X, -devant.Z))
		W.tardisCarte.TextColor3 = e.volLibre and C.cyan or C.ambre
		W.echelleCarteTexte.Text = string.format("± %d studs", r)
	end

	Players.PlayerRemoving:Connect(function(autre)
		if S.pointsCarte[autre] then
			S.pointsCarte[autre]:Destroy()
			S.pointsCarte[autre] = nil
		end
	end)
end

local function choisirModeScanner(mode)
	S.modeScanner = mode
	W.carte.Visible = mode == "carte"
	W.radar.Visible = mode == "radar"
	UI.colorer(W.btnCarte, mode == "carte" and C.bleu or C.fond)
	UI.colorer(W.btnRadar, mode == "radar" and C.bleu or C.fond)
	W.btnCarte.TextColor3 = mode == "carte" and C.texte or C.texte2
	W.btnRadar.TextColor3 = mode == "radar" and C.texte or C.texte2
end
W.btnRadar.Activated:Connect(function() choisirModeScanner("radar") end)
W.btnCarte.Activated:Connect(function() choisirModeScanner("carte") end)
choisirModeScanner("radar")

--------------------------------------------------------------------
-- Mises à jour lentes (télémétrie, occupants, distances, statistiques)
--------------------------------------------------------------------
local boiteCF, boiteTaille = interieur:GetBoundingBox()
local function dansInterieur(position)
	local p = boiteCF:PointToObjectSpace(position)
	return math.abs(p.X) <= boiteTaille.X / 2 and math.abs(p.Y) <= boiteTaille.Y / 2 and math.abs(p.Z) <= boiteTaille.Z / 2
end

local function majLente(e)
	-- Télémétrie
	local pivot = exterieur:GetPivot()
	local p = pivot.Position
	W.infoLieu.Text = tostring(exterieur:GetAttribute("Position") or "?")
	W.infoCoord.Text = string.format("%d, %d, %d", p.X, p.Y, p.Z)
	local devant = pivot.LookVector
	W.infoCap.Text = string.format("%05.1f°", (math.deg(math.atan2(-devant.X, -devant.Z)) + 360) % 360)
	W.infoEchelle.Text = math.floor(e.echelle * 100 + 0.5) .. " %" .. (e.porteur and ("  ·  porté par " .. e.porteur.DisplayName) or "")
	W.infoPortes.Text = (e.porteOuverte and "Ouvertes" or "Fermées") .. (e.verrouille and "  ·  verrouillées" or "")
	W.infoDestination.Text = S.choix and S.choix.nom or "—"

	-- Occupants de la salle de contrôle
	local noms = {}
	for _, autre in Players:GetPlayers() do
		local racine = autre.Character and autre.Character:FindFirstChild("HumanoidRootPart")
		if racine and dansInterieur(racine.Position) then
			table.insert(noms, autre.DisplayName)
		end
	end
	W.occCompte.Text = #noms .. " à bord"
	W.occListe.Text = #noms == 0 and "Personne à bord." or table.concat(noms, "  ·  ")

	-- Distances dans la liste
	for _, element in S.boutonsChoix do
		local distance = distanceDe(element.choix)
		element.distance.Text = distance and string.format("%d studs", distance) or ""
	end
	majFiche()

	-- Statistiques
	local vortex = S.tempsVortex
	if S.debutVol then vortex += os.clock() - S.debutVol end
	W.statVoyages.Text = tostring(S.voyages)
	W.statVortex.Text = UI.formatTemps(vortex)
	W.statSession.Text = UI.formatTemps(os.clock() - S.debutSession)
end

--------------------------------------------------------------------
-- Balises de détresse (/balisehelp ou /tardis help) : alerte cliquable pour les pilotes
--------------------------------------------------------------------
do
	local vues = {}
	local baliseCourante = nil
	local function cacher()
		animer(W.alerteBalise, 0.3, { Position = UDim2.new(1, 340, 0, 170) }).Completed:Wait()
		W.alerteBalise.Visible = false
	end
	W.alerteBaliseFermer.Activated:Connect(function() task.spawn(cacher) end)
	W.alerteBaliseBouton.Activated:Connect(function()
		if baliseCourante then remote:FireServer("BaliseAller", { joueur = baliseCourante }) end
		task.spawn(cacher)
	end)
	exterieur:GetAttributeChangedSignal("Balises"):Connect(function()
		if joueur:GetAttribute("TardisPilote_" .. def.Nom) ~= true then return end
		local actives = {}
		for ligne in string.gmatch(exterieur:GetAttribute("Balises") or "", "[^\n]+") do
			local id, nom = string.match(ligne, "^(%d+)\t(.-)\t")
			if id then
				actives[id] = true
				if not vues[id] then
					vues[id] = true
					baliseCourante = tonumber(id)
					W.alerteBaliseTexte.Text = "●  BALISE DE DÉTRESSE\n" .. nom .. " appelle le TARDIS."
					journaliser("Balise de détresse : " .. nom .. ".", C.rouge)
					if S.ouvert then notifier("Balise : " .. nom .. " appelle le TARDIS (voir l'alerte).", true) end
					W.alerteBalise.Visible = true
					W.alerteBalise.Position = UDim2.new(1, 340, 0, 170)
					animer(W.alerteBalise, 0.45, { Position = UDim2.new(1, -20, 0, 170) }, Enum.EasingStyle.Back)
				end
			end
		end
		for id in vues do
			if not actives[id] then vues[id] = nil end
		end
	end)
end

--------------------------------------------------------------------
-- Sentinelle : prévient les pilotes quand quelqu'un s'approche du TARDIS posé (même tablette fermée)
--------------------------------------------------------------------
do
	local jetonAlerte = 0
	local function alerteSentinelle(message)
		journaliser(message, C.ambre)
		if S.ouvert then
			notifier(message, true)
			return
		end
		jetonAlerte += 1
		local moi = jetonAlerte
		W.alerteTexte.Text = "●  SENTINELLE\n" .. message
		W.alerte.Visible = true
		W.alerte.Position = UDim2.new(1, 340, 0, 90)
		animer(W.alerte, 0.45, { Position = UDim2.new(1, -20, 0, 90) }, Enum.EasingStyle.Back)
		task.delay(5, function()
			if moi ~= jetonAlerte then return end
			animer(W.alerte, 0.3, { Position = UDim2.new(1, 340, 0, 90) }).Completed:Wait()
			if moi == jetonAlerte then W.alerte.Visible = false end
		end)
	end

	local function majBoutonSentinelle()
		W.btnSentinelle.Text = S.sentinelle and "SENTINELLE  ●" or "SENTINELLE  ○"
		UI.colorer(W.btnSentinelle, S.sentinelle and Color3.fromRGB(30, 90, 60) or C.fond)
	end
	W.btnSentinelle.Activated:Connect(function()
		S.sentinelle = not S.sentinelle
		table.clear(S.proches)
		majBoutonSentinelle()
		journaliser(S.sentinelle and "Sentinelle activée." or "Sentinelle désactivée.", C.vert)
	end)
	majBoutonSentinelle()

	local rayon = (Config.Sentinelle or {}).Rayon or 35
	task.spawn(function()
		while true do
			task.wait(0.5)
			local actif = S.sentinelle and joueur:GetAttribute("TardisPilote_" .. def.Nom) == true
				and (exterieur:GetAttribute("Etat") or E.Pose) == E.Pose and not exterieur:GetAttribute("VolLibre")
			if actif then
				local centre = exterieur:GetPivot().Position
				for _, autre in Players:GetPlayers() do
					if autre ~= joueur then
						local racine = autre.Character and autre.Character:FindFirstChild("HumanoidRootPart")
						if racine and not dansInterieur(racine.Position) then
							local distance = (racine.Position - centre).Magnitude
							if distance <= rayon and not S.proches[autre] then
								S.proches[autre] = true
								alerteSentinelle(string.format("%s s'approche du TARDIS (%d studs).", autre.DisplayName, distance))
							elseif distance > rayon * 1.4 then
								S.proches[autre] = nil
							end
						else
							S.proches[autre] = nil
						end
					end
				end
			else
				table.clear(S.proches)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(autre) S.proches[autre] = nil end)
end

--------------------------------------------------------------------
-- Animations continues
--------------------------------------------------------------------
local prochaineMajLente = 0
RunService.RenderStepped:Connect(function(dt)
	if not S.ouvert then return end
	local e = lireEtat()
	local t = os.clock()
	local ecoule = workspace:GetServerTimeNow() - (exterieur:GetAttribute("DebutEtat") or 0)
	local enMouvement = e.etat ~= E.Pose
	local vitesse = enMouvement and 3 or 1

	-- Décor : emblème, vortex, grand cadran, horloge
	for i, anneau in W.anneaux do
		anneau.Rotation += dt * (i % 2 == 0 and -1 or 1) * (20 + i * 18) * vitesse
	end
	W.vortexHaut.Rotation = (t * 8 * vitesse) % 360
	W.vortexHaut.Offset = Vector2.new(math.sin(t * 0.3) * 0.4, 0)
	W.cadranFond.Rotation += dt * 2 * vitesse
	W.horloge.Text = os.date("%H:%M:%S")

	-- Anneau de statut
	local n = R.SEGMENTS
	if not e.alimente then
		for i = 1, n do W.segments[i].BackgroundColor3 = C.gris end
		W.anneauTexte.Text = "—"
		W.anneauSous.Text = "HORS TENSION"
		W.chrono.Text = ""
	elseif e.etat == E.Demat or e.etat == E.Remat then
		local urgence = e.urgence
		local duree, decalage = Config.Timing(e.etat, Config.modeDe(exterieur))
		local total = duree + decalage
		local p = math.clamp(ecoule / total, 0, 1)
		local couleur = (urgence and C.orange) or (e.express and C.vert) or C.ambre
		for i = 1, n do
			local allume = (i - 1) / n < p
			W.segments[i].BackgroundColor3 = allume and couleur or C.gris
		end
		W.anneauTexte.Text = math.floor(p * 100) .. "%"
		W.anneauSous.Text = e.etat == E.Demat and "DÉCOLLAGE" or "ATTERRISSAGE"
		W.chrono.Text = "T-" .. UI.formatTemps(total - ecoule + 0.99)
	elseif e.etat == E.Vol then
		local tete = (t * 22) % n
		for i = 1, n do
			local d = (tete - i) % n
			W.segments[i].BackgroundColor3 = C.gris:Lerp(C.cyan, math.max(0, 1 - d / 16))
		end
		W.anneauTexte.Text = "VOL"
		W.anneauSous.Text = "VORTEX"
		W.chrono.Text = UI.formatTemps(ecoule)
	else
		local couleur = e.alerte and C.rouge or C.vert
		local rythme = e.alerte and 6 or 1.5
		for i = 1, n do
			local intensite = 0.35 + 0.35 * math.sin(t * rythme + i / n * math.pi * 2)
			W.segments[i].BackgroundColor3 = C.gris:Lerp(couleur, intensite)
		end
		W.anneauTexte.Text = e.alerte and "!" or "OK"
		W.anneauSous.Text = e.alerte and "ALERTE" or "POSÉ"
		W.chrono.Text = ""
	end
	W.anneauTexte.TextColor3 = (not e.alimente and C.gris) or (e.alerte and C.rouge) or C.texte

	-- Flux temporel (barres)
	local amplitude = (not e.alimente and 0.05) or ((e.etat == E.Vol and 0.9) or (enMouvement and 0.7) or 0.28)
	local agitation = (e.urgence or e.alerte) and 3 or 1
	local couleurBarres = (not e.alimente and C.gris) or (e.alerte and C.rouge) or (e.urgence and C.orange) or C.cyan
	for i, barreFlux in W.barres do
		local onde = math.abs(math.sin(t * 2.2 * agitation + i * 0.55) * math.cos(t * 1.3 * agitation + i * 0.27))
		barreFlux.Size = UDim2.new(barreFlux.Size.X.Scale, barreFlux.Size.X.Offset, math.clamp(0.08 + amplitude * onde, 0.05, 1), 0)
		barreFlux.BackgroundColor3 = couleurBarres
	end
	W.stabilite.Text = (not e.alimente and "HORS LIGNE") or (e.alerte and "ALERTE") or (e.urgence and "INSTABLE")
		or (e.etat == E.Vol and "VORTEX") or (enMouvement and "TRANSITION") or "STABLE"
	W.stabilite.TextColor3 = couleurBarres == C.cyan and C.vert or couleurBarres

	-- Grands boutons qui luisent
	local lueur = 0.2 + 0.5 * (0.5 + 0.5 * math.sin(t * 3))
	W.demat.Lueur.Transparency = W.demat:GetAttribute("Disponible") and lueur or 0.7
	W.remat.Lueur.Transparency = W.remat:GetAttribute("Disponible") and lueur or 0.7

	-- Scanner
	if S.modeScanner == "carte" then
		majCarte(e)
	else
		W.balayageRadar.Rotation = (W.balayageRadar.Rotation + dt * 90) % 360
		majScanner(e)
	end

	-- Le reste, 4 fois par seconde
	if t >= prochaineMajLente then
		prochaineMajLente = t + 0.25
		majLente(e)
	end
end)

local function majTaille()
	W.echelleHud.Scale = math.clamp(camera.ViewportSize.X / 720, 0.7, 1)
	if S.ouvert then majDisposition() end
end
camera:GetPropertyChangedSignal("ViewportSize"):Connect(majTaille)
majTaille()

--------------------------------------------------------------------
-- Journal automatique et statistiques
--------------------------------------------------------------------
local precedents = {}
local function surChangement(attribut, rappel)
	precedents[attribut] = exterieur:GetAttribute(attribut)
	exterieur:GetAttributeChangedSignal(attribut):Connect(function()
		local avant, apres = precedents[attribut], exterieur:GetAttribute(attribut)
		precedents[attribut] = apres
		if avant ~= apres then rappel(apres, avant) end
	end)
end

surChangement("Etat", function(etat, avant)
	local mode = Config.modeDe(exterieur)
	local position = tostring(exterieur:GetAttribute("Position") or "?")
	if avant == E.Vol and S.debutVol then
		S.tempsVortex += os.clock() - S.debutVol
		S.debutVol = nil
	end
	if etat == E.Demat then
		S.voyages += 1
		journaliser((mode == "Urgence" and "Dématérialisation d'URGENCE.") or (mode == "Express" and "Dématérialisation EXPRESS.") or "Dématérialisation.", C.ambre)
	elseif etat == E.Vol then
		S.debutVol = os.clock()
		journaliser("Entrée dans le vortex.", C.cyan)
	elseif etat == E.Remat then
		journaliser((urgence and "Matérialisation d'URGENCE : " or "Matérialisation : ") .. position, C.ambre)
	elseif etat == E.Pose then
		journaliser("Posé : " .. position, C.vert)
	end
end)
surChangement("Camouflage", function(actif) journaliser(actif and "Camouflage activé." or "Camouflage désactivé.", C.cyan) end)
surChangement("PortesVerrouillees", function(actif) journaliser(actif and "Portes verrouillées." or "Portes déverrouillées.", C.rouge) end)
surChangement("PorteOuverte", function(actif) journaliser(actif and "Portes ouvertes." or "Portes fermées.", C.texte2) end)
surChangement("Echelle", function(f) journaliser("Échelle réglée à " .. math.floor((f or 1) * 100 + 0.5) .. " %.", C.ambre) end)
surChangement("Alimentation", function(actif)
	journaliser(actif == false and "COUPURE D'ALIMENTATION." or "Alimentation rétablie.", actif == false and C.rouge or C.vert)
end)
surChangement("Alerte", function(actif) journaliser(actif and "ALERTE GÉNÉRALE." or "Fin de l'alerte.", actif and C.rouge or C.vert) end)
surChangement("VolLibre", function(id)
	local pilote = id and Players:GetPlayerByUserId(id)
	journaliser(id and ("Vol libre : " .. (pilote and pilote.DisplayName or "quelqu'un") .. " prend les commandes.")
		or "Fin du vol libre.", C.cyan)
end)
surChangement("DescenteMode", function(mode)
	if mode == "Chute" then
		journaliser("CHUTE LIBRE ! Rentrée atmosphérique.", C.orange)
	elseif mode == "Douce" then
		journaliser("Descente en douceur.", C.cyan)
	end
end)
surChangement("BouclierJoueurs", function(actif)
	journaliser(actif and "Bouclier anti-joueurs levé." or "Bouclier anti-joueurs abaissé.", C.cyan)
end)
surChangement("BouclierBalles", function(actif)
	journaliser(actif and "Bouclier anti-balles levé." or "Bouclier anti-balles abaissé.", C.cyan)
end)
surChangement("SurEau", function(actif) if actif then journaliser("Amerrissage : le TARDIS flotte.", C.cyan) end end)
surChangement("VolSaut", function() journaliser("Saut temporel.", C.cyan) end)
surChangement("DemarrageBloque", function(actif) journaliser(actif and "Démarrage bloqué." or "Démarrage débloqué.", C.orange) end)
surChangement("Porteur", function(id)
	local porteur = id and Players:GetPlayerByUserId(id)
	journaliser(id and ("Ramassé par " .. (porteur and porteur.DisplayName or "quelqu'un") .. ".") or "Reposé au sol.", C.vert)
end)

--------------------------------------------------------------------
-- Mises à jour automatiques et accès
--------------------------------------------------------------------
for _, attribut in { "Etat", "Camouflage", "Position", "PortesVerrouillees", "Retreci", "Porteur", "Mode", "PorteOuverte",
	"Echelle", "Alimentation", "Alerte", "DemarrageBloque", "VolLibre", "SurEau", "BouclierJoueurs", "BouclierBalles", "BouclierComplet", "BouclierEnergie", "PointsDeVie", "Avarie" } do
	exterieur:GetAttributeChangedSignal(attribut):Connect(function()
		if S.ouvert then majInterface() end
	end)
end
exterieur:GetAttributeChangedSignal("PrecedentNom"):Connect(construireListe)
exterieur:GetAttributeChangedSignal("Historique"):Connect(function() if S.mode == "histo" then construireListe() end end)
local function lireCategories()
	table.clear(S.categories)
	for ligne in string.gmatch(exterieur:GetAttribute("Categories") or "", "[^\n]+") do
		local nom, index = string.match(ligne, "^(.-)\t(%d+)$")
		if nom then S.categories[nom] = tonumber(index) end
	end
	construireListe()
	majFiche()
end
exterieur:GetAttributeChangedSignal("Categories"):Connect(lireCategories)
lireCategories()
exterieur:GetAttributeChangedSignal("ListeDestinations"):Connect(construireListe)
Players.PlayerAdded:Connect(construireListe)
Players.PlayerRemoving:Connect(function() task.defer(construireListe) end)

local function majAcces()
	local pilote = joueur:GetAttribute("TardisPilote_" .. def.Nom) == true
	W.gui.Enabled = pilote
	if not pilote then fermer() end
end
joueur:GetAttributeChangedSignal("TardisPilote_" .. def.Nom):Connect(majAcces)
majAcces()
joueur:SetAttribute("TardisTablette", false)
changerMode("lieux")
choisirFiger(false)
journaliser("Tablette initialisée.", C.texte2)

--------------------------------------------------------------------
-- OUTILS (volet latéral) : grille par familles, puis pages dans le même volet
--------------------------------------------------------------------
local O = {}
local T = O -- les raccourcis Boucliers, Stabilisateur et Rotation sont des outils comme les autres
local function ouvrirSurcouche(nom, titre) return V.ouvrir(nom, titre) end
local function ligneTexte(_, txt, ordre, couleur, taille) return V.ligne(txt, ordre, couleur, taille) end
local function boutonSurcouche(_, txt, ordre, couleur, action) return V.bouton(txt, ordre, couleur, action) end
local function fermerSurcouche() V.retour() end

local function famille(nom, ordre)
	texte({ Text = nom, Font = UI.POLICE_GRAS, TextSize = 10, TextColor3 = C.texte2, LayoutOrder = ordre, ZIndex = 62, Parent = V.grille })
	return creer("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = ordre + 1,
		ZIndex = 62, Parent = V.grille }, { creer("UIGridLayout", { CellSize = UDim2.fromOffset(200, 60), CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder }) })
end
local function tuileOutil(parent, nom, icone, ordre)
	local bouton = creer("TextButton", { BackgroundColor3 = C.panneau, Text = "", LayoutOrder = ordre, ZIndex = 62, Parent = parent },
	{ UI.coin(10), UI.contour(C.bleu, 1, 0.4) })
	local lampe = creer("Frame", { Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(8, 8), BackgroundColor3 = C.gris, ZIndex = 63, Parent = bouton }, { UI.coin(99) })
	texte({ Text = icone, TextSize = 16, TextColor3 = C.ambre, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -10, 0, 6),
		Size = UDim2.fromOffset(20, 18), AnchorPoint = Vector2.new(1, 0), ZIndex = 63, Parent = bouton })
	texte({ Text = nom, Font = UI.POLICE_GRAS, TextSize = 13, Position = UDim2.fromOffset(10, 22), Size = UDim2.new(1, -20, 0, 16), ZIndex = 63, Parent = bouton })
	local etat = texte({ Text = "", TextSize = 10, TextColor3 = C.texte2, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(10, 40),
		Size = UDim2.new(1, -20, 0, 12), ZIndex = 63, Parent = bouton })
	bouton:SetAttribute("CouleurBase", C.panneau)
	UI.rendreVivant(bouton)
	return { bouton = bouton, lampe = lampe, etat = etat }
end
local fVoyage, fSecurite, fAmbiance = famille("VOYAGE", 1), famille("SÉCURITÉ", 3), famille("AMBIANCE", 5)
O.rappel = tuileOutil(fVoyage, "Rappel", "●", 1)
O.minuterie = tuileOutil(fVoyage, "Minuterie", "●", 2)
O.leurre = tuileOutil(fVoyage, "Leurre", "●", 3)
O.rotation = tuileOutil(fVoyage, "Rotation", "○", 4)
O.replay = tuileOutil(fVoyage, "Replay", "►", 5)
O.stabilisateur = tuileOutil(fVoyage, "Stabilisateur", "◆", 6)
O.boucliers = tuileOutil(fSecurite, "Boucliers", "●", 1)
O.equipage = tuileOutil(fSecurite, "Équipage", "●", 2)
O.inviter = tuileOutil(fSecurite, "Inviter", "●", 3)
O.registre = tuileOutil(fSecurite, "Registre", "■", 4)
O.fiche = tuileOutil(fSecurite, "Fiche", "■", 5)
O.autodestruction = tuileOutil(fSecurite, "Auto-destruction", "▲", 6)
O.regenerations = tuileOutil(fSecurite, "Régénérations", "◆", 7)
O.theme = tuileOutil(fAmbiance, "Thème", "◆", 1)
O.jukebox = tuileOutil(fAmbiance, "Jukebox", "●", 2)
O.projecteur = tuileOutil(fAmbiance, "Projecteur", "▲", 3)
O.cabine = tuileOutil(fAmbiance, "Customisation", "◆", 4)

local function majTuile(t, actif, texteEtat, couleur, disponible)
	UI.setDisponible(t.bouton, disponible, C.panneau)
	animer(t.lampe, 0.2, { BackgroundColor3 = actif and couleur or C.gris })
	t.etat.Text = texteEtat
	t.etat.TextColor3 = actif and couleur or C.texte2
end
local function majOutils(e)
	local pose, alimente, porte, bloque = e.pose and not e.volLibre, e.alimente, e.porte, e.bloque
	local choix = S.choix
	local minuterieFin = exterieur:GetAttribute("MinuterieFin")
	local resteMinuterie = minuterieFin and math.max(0, minuterieFin - workspace:GetServerTimeNow())
	majTuile(O.rappel, false, "Vient à moi", C.cyan, pose and alimente and not porte and not bloque)
	majTuile(O.minuterie, resteMinuterie ~= nil, resteMinuterie and string.format("Décollage : %d s", resteMinuterie) or "Départ différé", C.ambre,
		(pose and alimente and not porte and not bloque) or resteMinuterie ~= nil)
	local leurreActif = workspace:FindFirstChild("TardisLeurre") ~= nil
	majTuile(O.leurre, leurreActif, leurreActif and "ACTIF · retirer" or (choix and "Faux TARDIS" or "Choisis un lieu"), C.cyan, leurreActif or choix ~= nil)
	majTuile(O.rotation, false, "Ajuster position", C.vert, pose and alimente and not porte and not bloque)
	majTuile(O.replay, false, UI.replayDisponible and "Dernier vol" or "Aucun vol", C.cyan, UI.replayDisponible == true)
	local stabilisateur = exterieur:GetAttribute("Stabilisateur") ~= false
	majTuile(O.stabilisateur, stabilisateur, stabilisateur and "Activé" or "Coupé · la cabine vibre", C.vert, true)
	local unBouclier = exterieur:GetAttribute("BouclierJoueurs") == true or exterieur:GetAttribute("BouclierBalles") == true or exterieur:GetAttribute("BouclierComplet") == true
	local energie = exterieur:GetAttribute("BouclierEnergie") or 100
	majTuile(O.boucliers, unBouclier, unBouclier and string.format("LEVÉ · énergie %d %%", energie) or "Anti-joueurs · balles · complet",
		(unBouclier and energie <= 15) and C.rouge or Color3.fromRGB(135, 206, 250), unBouclier or (pose and alimente and not porte))
	local nbRoles = 0
	for _ in string.gmatch(exterieur:GetAttribute("Roles") or "", "[^\n]+") do nbRoles += 1 end
	majTuile(O.equipage, nbRoles > 0, nbRoles > 0 and (nbRoles .. " rôle(s) actif(s)") or "Pilotes · bannis", C.ambre, true)
	majTuile(O.inviter, false, "Téléporter à bord", C.cyan, true)
	local intrusion = exterieur:GetAttribute("Intrusion")
	majTuile(O.registre, intrusion ~= nil, intrusion and ("Intrusion : " .. intrusion) or "Entrées · sorties", C.rouge, true)
	majTuile(O.fiche, false, "Dossier d'anomalie", C.texte2, true)
	local compteARebours = exterieur:GetAttribute("AutoDestructionDebut")
	majTuile(O.autodestruction, compteARebours ~= nil, compteARebours and "EN COURS !" or "Danger", C.rouge, pose and not compteARebours)
	local okJ, journalRegen = pcall(function() return game:GetService("HttpService"):JSONDecode(ReplicatedStorage:GetAttribute("TardisRegenerations") or "[]") end)
	local nbRegen = okJ and type(journalRegen) == "table" and #journalRegen or 0
	local lien = ReplicatedStorage:GetAttribute("TardisLienTimeLord") == true
	majTuile(O.regenerations, nbRegen > 0, (nbRegen > 0 and (nbRegen .. " au journal") or "Aucune") .. (lien and " · lien actif" or ""), C.ambre, true)
	majTuile(O.theme, exterieur:GetAttribute("Theme") ~= nil, exterieur:GetAttribute("Theme") or "Classique", C.ambre, alimente)
	local piste = exterieur:GetAttribute("Jukebox")
	majTuile(O.jukebox, piste ~= nil, piste and ((Config.Jukebox or {})[piste] or {}).nom or "Musique à bord", C.ambre, #(Config.Jukebox or {}) > 0)
	local projecteur = exterieur:GetAttribute("Projecteur") == true
	majTuile(O.projecteur, projecteur, projecteur and "ALLUMÉ · vise caméra" or "Éteint", Color3.fromRGB(255, 240, 180), alimente)
	majTuile(O.cabine, exterieur:GetAttribute("StyleInterieur") ~= nil or exterieur:GetAttribute("Couleur") ~= nil, "Intérieur · console · extérieur", C.cyan, alimente)
end
-- Mise à jour avec l'interface, et sur les attributs des outils
exterieur:GetAttributeChangedSignal("Etat"):Connect(function() if S.ouvert then majOutils(lireEtat()) end end)
for _, attribut in { "MinuterieFin", "Intrusion", "Theme", "Projecteur", "Couleur", "StyleInterieur", "Jukebox", "Stabilisateur", "Roles", "BouclierEnergie",
	"BouclierJoueurs", "BouclierBalles", "BouclierComplet", "AutoDestructionDebut", "Alimentation", "Porteur", "VolLibre", "DemarrageBloque" } do
	exterieur:GetAttributeChangedSignal(attribut):Connect(function() if S.ouvert then majOutils(lireEtat()) end end)
end
task.spawn(function()
	while true do
		task.wait(1)
		if S.ouvert then majOutils(lireEtat()) end -- les commandes rapides sont sur la tablette, toujours à jour
	end
end)

-- Rotation : le menu se ferme et la vue de repositionnement s'ouvre (script TardisRotation)
T.rotation.bouton.Activated:Connect(function()
	if T.rotation.bouton:GetAttribute("Disponible") == false then return end
	fermer()
	joueur:SetAttribute("TardisRotation", true)
end)
local joueurDedans -- défini plus bas (registre)

-- Équipage : promouvoir un pilote temporaire, bannir, retirer (durées : session, 30 min, 2 h, 1 jour, 7 jours)
local afficherEquipage
afficherEquipage = function()
	local c = ouvrirSurcouche("equipage", "ÉQUIPAGE  ·  PILOTES TEMPORAIRES ET BANNISSEMENTS")
	local ordre = 0
	-- Rôles actifs
	local actifs = {}
	for ligne in string.gmatch(exterieur:GetAttribute("Roles") or "", "[^\n]+") do
		local id, nom, type_, fin = string.match(ligne, "^(%d+)\t(.-)\t(%a+)\t(%d+)$")
		if id then table.insert(actifs, { id = tonumber(id), nom = nom, type_ = type_, fin = tonumber(fin) }) end
	end
	ordre += 1
	ligneTexte(c, "RÔLES ACTIFS  ·  clique pour retirer", ordre, C.texte2, 11)
	if #actifs == 0 then
		ordre += 1
		ligneTexte(c, "Aucun pilote temporaire ni bannissement.", ordre, C.texte2)
	end
	for _, r in actifs do
		ordre += 1
		local reste = r.fin > 0 and (r.fin - os.time()) or nil
		local duree = reste and (reste >= 86400 and string.format("%d j", reste / 86400) or reste >= 3600 and string.format("%d h", reste / 3600)
			or string.format("%d min", math.max(reste / 60, 1))) or "session"
		boutonSurcouche(c, string.format("%s  ·  %s  ·  %s", r.nom, r.type_ == "pilotes" and "pilote" or "banni", duree), ordre,
			r.type_ == "pilotes" and C.bleu or Color3.fromRGB(110, 40, 50), function()
				remote:FireServer(r.type_ == "pilotes" and "Promouvoir" or "Bannir", { joueur = r.id, retirer = true })
				task.delay(0.5, afficherEquipage)
			end)
	end
	-- Joueurs connectés
	ordre += 1
	ligneTexte(c, "JOUEURS CONNECTÉS  ·  choisis une action puis une durée", ordre, C.texte2, 11)
	for _, autre in Players:GetPlayers() do
		if autre ~= joueur then
			ordre += 1
			local role = autre:GetAttribute("TardisPilote") and "pilote" or (autre:GetAttribute("TardisTechnicien") and "technicien" or "visiteur")
			local b
			b = boutonSurcouche(c, autre.DisplayName .. "  ·  " .. role .. "  ·  promouvoir / bannir", ordre, nil, function()
				-- Deuxième niveau : action puis durée
				local cc = ouvrirSurcouche("equipage", "ÉQUIPAGE  ·  " .. autre.DisplayName)
				local o = 0
				for _, action in { { "Promouvoir", "Promouvoir pilote pour…", C.bleu }, { "Bannir", "Bannir pour…", Color3.fromRGB(110, 40, 50) } } do
					o += 1
					ligneTexte(cc, action[2], o, C.texte2, 11)
					for _, d in Config.DureesRoles or {} do
						o += 1
						boutonSurcouche(cc, d.nom, o, action[3], function()
							local donnees = { joueur = autre.UserId }
							if d.session then donnees.session = true else donnees.minutes = (d.secondes or 60) / 60 end
							remote:FireServer(action[1], donnees)
							task.delay(0.5, afficherEquipage)
						end)
					end
				end
				o += 1
				boutonSurcouche(cc, "Retour", o, nil, afficherEquipage)
			end)
		end
	end
end
O.equipage.bouton.Activated:Connect(afficherEquipage)

-- Inviter : un joueur hors du TARDIS reçoit une invitation, qu'il accepte ou refuse
O.inviter.bouton.Activated:Connect(function()
	local c = ouvrirSurcouche("inviter", "INVITER À BORD")
	local ordre = 0
	for _, autre in Players:GetPlayers() do
		if not joueurDedans(autre) then
			ordre += 1
			local role = autre:GetAttribute("TardisPilote") and "  ·  pilote" or ""
			boutonSurcouche(c, autre == joueur and "Moi  ·  me téléporter à bord" or (autre.DisplayName .. role), ordre, autre == joueur and C.bleu or nil, function()
				remote:FireServer("Inviter", { joueur = autre.UserId })
				fermerSurcouche()
			end)
		end
	end
	if ordre == 0 then ligneTexte(c, "Personne à inviter : tout le monde est déjà à bord.", 1, C.texte2) end
end)

-- Auto-destruction : trois confirmations l'une après l'autre, la dernière après 15 secondes
O.autodestruction.bouton.Activated:Connect(function()
	if O.autodestruction.bouton:GetAttribute("Disponible") == false then return end
	local c = ouvrirSurcouche("autodestruction", "AUTO-DESTRUCTION DU TARDIS")
	ligneTexte(c, "CONSÉQUENCES", 1, C.rouge, 11)
	ligneTexte(c, "Rupture du Cœur du TARDIS, l'Œil de l'Harmonie : l'énergie d'une étoile figée est libérée d'un coup. "
		.. "Dans les 20 secondes qui suivent, la cabine entre en résonance, vire au rouge et l'alarme du Cloître retentit. "
		.. "À l'explosion, tout ce qui se trouve à moins de 50 studs est détruit : joueurs, objets, véhicules. "
		.. "Les occupants sont éjectés dehors, dans la zone de l'explosion. "
		.. "Le TARDIS disparaît et se reconstitue de lui-même au bout de 7 minutes, sur un point enregistré choisi au hasard. "
		.. "Pendant ce temps, aucune commande n'est possible.", 2, C.texte, 12)
	local etape = 0
	local b1, b2, b3
	b1 = boutonSurcouche(c, "1 · Je comprends les conséquences", 3, Color3.fromRGB(90, 40, 40), function()
		if etape ~= 0 then return end
		etape = 1
		b1.Text = "1 · Compris  ●"
		b2.Visible = true
	end)
	b2 = boutonSurcouche(c, "2 · Engager la procédure", 4, Color3.fromRGB(130, 40, 40), function()
		if etape ~= 1 then return end
		etape = 2
		b2.Text = "2 · Procédure engagée  ●"
		b3.Visible = true
		-- Le dernier bouton se déverrouille au bout de 15 secondes
		for reste = 15, 1, -1 do
			if V.actif ~= "autodestruction" then return end
			b3.Text = string.format("3 · DÉTRUIRE LE TARDIS  (dans %d s)", reste)
			task.wait(1)
		end
		if V.actif == "autodestruction" then
			etape = 3
			b3.Text = "3 · DÉTRUIRE LE TARDIS"
		end
	end)
	b3 = boutonSurcouche(c, "3 · DÉTRUIRE LE TARDIS  (dans 15 s)", 5, Color3.fromRGB(200, 40, 40), function()
		if etape ~= 3 then return end
		remote:FireServer("AutoDestruction", { confirmation = 3 })
		fermerSurcouche()
	end)
	b2.Visible = false
	b3.Visible = false
end)
exterieur:GetAttributeChangedSignal("Roles"):Connect(function()
	if V.actif == "equipage" then afficherEquipage() end
	if S.ouvert then majInterface() end
end)
-- Outils
O.rappel.bouton.Activated:Connect(function()
	if O.rappel.bouton:GetAttribute("Disponible") == false then return end
	remote:FireServer("Rappel")
end)
O.minuterie.bouton.Activated:Connect(function()
	if O.minuterie.bouton:GetAttribute("Disponible") == false then return end
	local c = ouvrirSurcouche("minuterie", "MINUTERIE DE DÉCOLLAGE")
	ligneTexte(c, "Le TARDIS décollera tout seul et restera dans le vortex jusqu'à ce que tu le fasses atterrir.", 1, C.texte2)
	local ordre = 1
	for _, duree in { 10, 30, 60, 120, 300 } do
		ordre += 1
		boutonSurcouche(c, duree >= 60 and string.format("Dans %d min", duree / 60) or string.format("Dans %d s", duree), ordre, nil, function()
			remote:FireServer("Minuterie", { secondes = duree })
			fermerSurcouche()
		end)
	end
	boutonSurcouche(c, "Annuler la minuterie en cours", ordre + 1, Color3.fromRGB(110, 40, 50), function()
		remote:FireServer("MinuterieAnnuler")
		fermerSurcouche()
	end)
end)
O.leurre.bouton.Activated:Connect(function()
	if O.leurre.bouton:GetAttribute("Disponible") == false then return end
	if workspace:FindFirstChild("TardisLeurre") then
		remote:FireServer("Leurre", { retirer = true })
		return
	end
	local donnees = donneesDestination()
	if donnees then remote:FireServer("Leurre", donnees) else notifier("Choisis d'abord un lieu.", false) end
end)
O.fiche.bouton.Activated:Connect(function()
	local f = Config.FicheAnomalie or {}
	local c = ouvrirSurcouche("fiche", "FICHE D'ANOMALIE  ·  " .. tostring(f.Numero or "SCP-TARDIS"))
	ligneTexte(c, "CLASSE : " .. tostring(f.Classe or "?"), 1, C.ambre, 14)
	ligneTexte(c, "DESCRIPTION", 2, C.texte2, 11)
	ligneTexte(c, tostring(f.Description or ""), 3)
	ligneTexte(c, "PROCÉDURES DE CONFINEMENT", 4, C.texte2, 11)
	ligneTexte(c, tostring(f.Confinement or ""), 5)
	ligneTexte(c, "Dernière position connue : " .. tostring(exterieur:GetAttribute("Position") or "?"), 6, C.cyan, 12)
end)
local boiteIntOutils, tailleIntOutils = interieur:GetBoundingBox()
joueurDedans = function(autre)
	local racine = autre.Character and autre.Character:FindFirstChild("HumanoidRootPart")
	if not racine then return false end
	local l = boiteIntOutils:PointToObjectSpace(racine.Position)
	return math.abs(l.X) <= tailleIntOutils.X / 2 + 20 and math.abs(l.Y) <= tailleIntOutils.Y / 2 + 20 and math.abs(l.Z) <= tailleIntOutils.Z / 2 + 20
end
local function afficherRegistre()
	local c = ouvrirSurcouche("registre", "REGISTRE DES PASSAGERS")
	local intrusion = exterieur:GetAttribute("Intrusion")
	if intrusion then ligneTexte(c, "▲ Dernière intrusion : " .. intrusion, 1, C.rouge, 13) end
	ligneTexte(c, "OCCUPANTS  ·  clique pour expulser", 2, C.texte2, 11)
	local ordre = 2
	for _, autre in Players:GetPlayers() do
		if joueurDedans(autre) then
			ordre += 1
			local b
			b = boutonSurcouche(c, autre.DisplayName .. (autre == joueur and "  (toi)" or "  ·  expulser"), ordre,
				autre == joueur and C.panneau or Color3.fromRGB(110, 40, 50), function()
					if autre ~= joueur then
						UI.confirmer(b, function() remote:FireServer("Expulser", { joueur = autre.UserId }) end)
					end
				end)
		end
	end
	if ordre == 2 then ligneTexte(c, "Personne dans le TARDIS.", 3, C.texte2) ordre = 3 end
	ligneTexte(c, "HISTORIQUE", ordre + 1, C.texte2, 11)
	local lignes = {}
	for ligne in string.gmatch(exterieur:GetAttribute("Registre") or "", "[^\n]+") do
		local h, nom, action = string.match(ligne, "^(.-)\t(.-)\t(.*)$")
		if h then table.insert(lignes, string.format("%s  ·  %s  ·  %s", h, nom, action)) end
		if #lignes >= 14 then break end
	end
	ligneTexte(c, #lignes > 0 and table.concat(lignes, "\n") or "Aucune entrée pour l'instant.", ordre + 2, C.texte, 12)
	-- Dossiers d'incident (une fiche par intrusion)
	local ok, incidents = pcall(function() return game:GetService("HttpService"):JSONDecode(exterieur:GetAttribute("Incidents") or "[]") end)
	incidents = ok and type(incidents) == "table" and incidents or {}
	ligneTexte(c, string.format("DOSSIERS D'INCIDENT  ·  %d", #incidents), ordre + 3, C.texte2, 11)
	local fiches = {}
	for i, inc in incidents do
		if i > 6 then break end
		table.insert(fiches, string.format("%s  ·  %s (%s)  ·  %s  ·  %s", inc.heure or "?", inc.nom or "?", inc.role or "?", inc.lieu or "?", inc.position or "?"))
	end
	ligneTexte(c, #fiches > 0 and table.concat(fiches, "\n") or "Aucune intrusion.", ordre + 4, C.texte, 11)
	if #incidents > 0 then
		boutonSurcouche(c, "Exporter les dossiers (markdown)", ordre + 5, C.bleu, function()
			local cc = ouvrirSurcouche("incidents", "DOSSIERS D'INCIDENT  ·  EXPORT")
			ligneTexte(cc, "Clique dans la zone, Ctrl+A puis Ctrl+C pour copier.", 1, C.texte2, 11)
			local md = { "# Dossiers d'incident du TARDIS", "" }
			for i, inc in incidents do
				table.insert(md, string.format("## Incident %d — %s", i, inc.heure or "?"))
				table.insert(md, string.format("- **Joueur** : %s (@%s)", inc.nom or "?", inc.pseudo or "?"))
				table.insert(md, string.format("- **Rôle** : %s", inc.role or "?"))
				table.insert(md, string.format("- **Lieu** : %s", inc.lieu or "?"))
				table.insert(md, string.format("- **Position du TARDIS** : %s", inc.position or "?"))
				table.insert(md, "")
			end
			creer("TextBox", { Size = UDim2.new(1, 0, 0, 380), BackgroundColor3 = C.panneau, Text = table.concat(md, "\n"), TextEditable = false,
				ClearTextOnFocus = false, MultiLine = true, TextWrapped = true, Font = UI.POLICE_CODE, TextSize = 11, TextColor3 = C.texte,
				TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 2, ZIndex = 22, Parent = cc },
			{ UI.coin(8), creer("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingTop = UDim.new(0, 6) }) })
		end)
	end
end
O.registre.bouton.Activated:Connect(afficherRegistre)
exterieur:GetAttributeChangedSignal("Registre"):Connect(function() if V.actif == "registre" then afficherRegistre() end end)
O.theme.bouton.Activated:Connect(function()
	if O.theme.bouton:GetAttribute("Disponible") == false then return end
	local c = ouvrirSurcouche("theme", "THÈME DE L'INTÉRIEUR")
	for i, theme in Config.Themes or {} do
		boutonSurcouche(c, theme.nom, i, exterieur:GetAttribute("Theme") == theme.nom and C.bleu or nil, function()
			remote:FireServer("Theme", { nom = theme.nom })
			fermerSurcouche()
		end)
	end
end)
O.projecteur.bouton.Activated:Connect(function()
	if O.projecteur.bouton:GetAttribute("Disponible") == false then return end
	remote:FireServer("Projecteur")
end)
O.cabine.bouton.Activated:Connect(function()
	if O.cabine.bouton:GetAttribute("Disponible") == false then return end
	local c = ouvrirSurcouche("cabine", "CUSTOMISATION")
	local ordre = 0
	-- Intérieur : styles (murs + sol)
	ordre += 1
	ligneTexte(c, "INTÉRIEUR  ·  style des murs et du sol", ordre, C.texte2, 11)
	for i, style in Config.StylesInterieur or {} do
		ordre += 1
		boutonSurcouche(c, style.nom, ordre, exterieur:GetAttribute("StyleInterieur") == i and C.bleu or style.murs.couleur:Lerp(C.panneau, 0.5), function()
			remote:FireServer("StyleInterieur", { index = i })
		end)
	end
	-- Murs : couleur seule
	ordre += 1
	ligneTexte(c, "MURS  ·  couleur seule", ordre, C.texte2, 11)
	local rangeeMurs = creer("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, LayoutOrder = ordre + 1, ZIndex = 22, Parent = c },
	{ creer("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
	for i, choixCouleur in Config.Couleurs or {} do
		local b = creer("TextButton", { Size = UDim2.new(1 / #Config.Couleurs, -4, 1, 0), BackgroundColor3 = choixCouleur.couleur, Text = "", LayoutOrder = i, ZIndex = 22,
			Parent = rangeeMurs }, { UI.coin(6), UI.contour(C.blanc, exterieur:GetAttribute("CouleurMurs") == i and 2 or 0, 0.2) })
		b.Activated:Connect(function() remote:FireServer("Murs", { index = i }) end)
	end
	ordre += 1
	-- Console : styles
	ordre += 1
	ligneTexte(c, "CONSOLE  ·  matière et couleur", ordre, C.texte2, 11)
	local rangeeConsole = creer("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, LayoutOrder = ordre + 1, ZIndex = 22, Parent = c },
	{ creer("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
	for i, style in Config.StylesConsole or {} do
		local b = creer("TextButton", { Size = UDim2.new(1 / #Config.StylesConsole, -4, 1, 0), BackgroundColor3 = style.couleur:Lerp(C.panneau, 0.3), Text = style.nom,
			Font = UI.POLICE_GRAS, TextSize = 10, TextColor3 = C.texte, LayoutOrder = i, ZIndex = 22, Parent = rangeeConsole },
		{ UI.coin(6), UI.contour(C.blanc, exterieur:GetAttribute("StyleConsole") == i and 2 or 0, 0.2) })
		b.Activated:Connect(function() remote:FireServer("StyleConsole", { index = i }) end)
	end
	ordre += 1
	-- Extérieur : couleur de la cabine et enseigne
	ordre += 1
	ligneTexte(c, "EXTÉRIEUR  ·  couleur de la cabine", ordre, C.texte2, 11)
	for i, choixCouleur in Config.Couleurs or {} do
		ordre += 1
		boutonSurcouche(c, choixCouleur.nom, ordre, choixCouleur.couleur:Lerp(C.panneau, 0.45), function()
			remote:FireServer("Couleur", { index = i })
		end)
	end
	ligneTexte(c, "EXTÉRIEUR  ·  décorations et reflets", ordre + 1, C.texte2, 11)
	local rangeeDeco = creer("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, LayoutOrder = ordre + 2, ZIndex = 22, Parent = c },
	{ creer("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
	for i, info in { { "Aucune", "Sans décoration" }, { "Noel", "Noël : guirlandes et neige" }, { "Halloween", "Halloween : citrouille" } } do
		local actif = (exterieur:GetAttribute("Decoration") or "Aucune") == info[1]
		local b = creer("TextButton", { Size = UDim2.new(1 / 3, -4, 1, 0), BackgroundColor3 = actif and C.bleu or C.panneauClair, Text = info[2], Font = UI.POLICE_GRAS,
			TextSize = 10, TextColor3 = C.texte, LayoutOrder = i, ZIndex = 22, Parent = rangeeDeco }, { UI.coin(6) })
		b.Activated:Connect(function() remote:FireServer("Decoration", { nom = info[1] }) end)
	end
	boutonSurcouche(c, exterieur:GetAttribute("Reflets") and "Reflets des vitres : activés" or "Reflets des vitres : désactivés", ordre + 3,
		exterieur:GetAttribute("Reflets") and C.bleu or nil, function() remote:FireServer("Reflets") end)
	ordre += 3
	ligneTexte(c, "EXTÉRIEUR  ·  enseigne (24 caractères max, filtrée par Roblox)", ordre + 1, C.texte2, 11)
	local saisie = creer("TextBox", { Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = C.panneau, Text = exterieur:GetAttribute("Enseigne") or "POLICE PUBLIC CALL BOX",
		PlaceholderText = "Texte de l'enseigne…", Font = UI.POLICE_GRAS, TextSize = 13, TextColor3 = C.texte, ClearTextOnFocus = false,
		LayoutOrder = ordre + 2, ZIndex = 22, Parent = c }, { UI.coin(8), UI.contour(C.cyan, 1, 0.5) })
	boutonSurcouche(c, "Appliquer l'enseigne", ordre + 3, C.bleu, function()
		if #saisie.Text > 0 then remote:FireServer("Enseigne", { texte = string.sub(saisie.Text, 1, 24) }) end
	end)
end)
O.jukebox.bouton.Activated:Connect(function()
	if O.jukebox.bouton:GetAttribute("Disponible") == false then return end
	local c = ouvrirSurcouche("jukebox", "JUKEBOX")
	ligneTexte(c, "La musique s'entend dans la salle de contrôle. Volume : réglages de la tablette.", 1, C.texte2, 11)
	for i, piste in Config.Jukebox or {} do
		boutonSurcouche(c, piste.nom, i + 1, exterieur:GetAttribute("Jukebox") == i and C.bleu or nil, function()
			remote:FireServer("Jukebox", { index = i })
			fermerSurcouche()
		end)
	end
	boutonSurcouche(c, "Arrêter la musique", #(Config.Jukebox or {}) + 2, Color3.fromRGB(110, 40, 50), function()
		remote:FireServer("Jukebox", {})
		fermerSurcouche()
	end)
end)
O.replay.bouton.Activated:Connect(function()
	if O.replay.bouton:GetAttribute("Disponible") == false then return end
	fermer()
	joueur:SetAttribute("TardisReplay", true)
end)
-- La minuterie se met à jour chaque seconde
task.spawn(function()
	while true do
		task.wait(1)
		if S.ouvert and exterieur:GetAttribute("MinuterieFin") then majInterface() end
	end
end)

T.boucliers.bouton.Activated:Connect(function()
	if T.boucliers.bouton:GetAttribute("Disponible") == false then return end
	local c = ouvrirSurcouche("boucliers", "BOUCLIERS")
	local energie = exterieur:GetAttribute("BouclierEnergie") or 100
	ligneTexte(c, string.format("Énergie : %d %%  ·  le bouclier tombe quand elle atteint 0 (environ 250 balles). Invisible, il se révèle au contact et sous les tirs.", energie),
		1, energie <= 15 and C.rouge or C.texte2, 11)
	for i, info in { { "Joueurs", "Anti-joueurs : personne n'approche" }, { "Balles", "Anti-balles : les tirs s'arrêtent" }, { "Complet", "Complet : joueurs et tirs, un seul bouclier" } } do
		local actif = exterieur:GetAttribute("Bouclier" .. info[1]) == true
		boutonSurcouche(c, (actif and "●  " or "○  ") .. info[2], i + 1, actif and C.bleu or nil, function()
			remote:FireServer("Bouclier", { type = info[1] })
			fermerSurcouche()
		end)
	end
end)
T.stabilisateur.bouton.Activated:Connect(function() remote:FireServer("Stabilisateur") end)

-- Le volet s'ouvre sur la grille des outils (état à jour)
W.btnOutils.Activated:Connect(function() if V.actif == "outils" then majOutils(lireEtat()) end end)

-- Régénérations : journal (qui, quand, où, numéro), et le lien Time Lord
local function afficherRegenerations()
	local c = ouvrirSurcouche("regenerations", "RÉGÉNÉRATIONS")
	local lien = ReplicatedStorage:GetAttribute("TardisLienTimeLord") == true
	ligneTexte(c, "LIEN TIME LORD : les Voyageurs ressentent les régénérations des autres (notification et flash).", 1, C.texte2, 11)
	boutonSurcouche(c, lien and "●  Lien Time Lord : activé (désactiver)" or "○  Lien Time Lord : désactivé (activer)", 2, lien and C.bleu or nil, function()
		remote:FireServer("LienTimeLord")
		task.delay(0.4, afficherRegenerations)
	end)
	local ok, journal = pcall(function() return game:GetService("HttpService"):JSONDecode(ReplicatedStorage:GetAttribute("TardisRegenerations") or "[]") end)
	journal = ok and type(journal) == "table" and journal or {}
	ligneTexte(c, string.format("JOURNAL  ·  %d entrée(s)", #journal), 3, C.texte2, 11)
	if #journal == 0 then
		ligneTexte(c, "Aucune régénération pour l'instant.", 4, C.texte2)
		return
	end
	local lignes = {}
	for _, e in journal do
		table.insert(lignes, string.format("%s  ·  %s  ·  %s%s  ·  %s", e.heure or "?", e.nom or "?", e.nature or "?",
			e.numero and (" n°" .. e.numero) or "", e.lieu or "?"))
	end
	ligneTexte(c, table.concat(lignes, "\n"), 4, C.texte, 11)
end
O.regenerations.bouton.Activated:Connect(afficherRegenerations)
ReplicatedStorage:GetAttributeChangedSignal("TardisRegenerations"):Connect(function()
	if V.actif == "regenerations" then afficherRegenerations() end
end)

-- Commandes rapides : ces outils quittent le volet et prennent place directement sur la tablette
do
	local grille = creer("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = W.rapides },
	{ creer("UIGridLayout", { CellSize = UDim2.new(1 / 3, -5, 0.5, -3), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	for ordre, cle in { "rappel", "minuterie", "inviter", "stabilisateur", "projecteur", "registre" } do
		local t = O[cle]
		if t then
			t.bouton.Parent = grille
			t.bouton.LayoutOrder = ordre
			t.etat.Visible = false -- l'état se lit au voyant
			t.lampe.Position = UDim2.new(0, 8, 0.5, -4)
			for _, enfant in t.bouton:GetChildren() do
				if enfant:IsA("TextLabel") and enfant ~= t.etat then
					if enfant.TextXAlignment == Enum.TextXAlignment.Right then
						enfant.Position = UDim2.new(1, -6, 0.5, -9) -- icône
					else
						enfant.Position = UDim2.new(0, 20, 0.5, -8) -- nom
						enfant.Size = UDim2.new(1, -40, 0, 16)
						enfant.TextSize = 12
						enfant.TextTruncate = Enum.TextTruncate.AtEnd
					end
				end
			end
		end
	end
end