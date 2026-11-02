-- StarterPlayer > StarterPlayerScripts > TardisMenu (LocalScript)
-- Menu RAPIDE du TARDIS : simple et rapide, dans un tiroir sur le bord gauche de l'écran.
--   Statut (état, lieu, badges, progression) · Destination (lieux / joueurs, fiche) · Protocoles
--   Dématérialiser / Matérialiser (avec la progression du voyage) · Systèmes (intégrité, bouclier, raccourcis)
--   Bouton "Tablette" : ouvre la tablette avancée (script TardisTablette).
-- Visible seulement pour les pilotes autorisés. Toutes les commandes sont revérifiées par le serveur.
-- Touche T : ouvrir / fermer. (V6.7 : refonte de l'apparence et de l'organisation.)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

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
-- Commandes de voyage et protocoles partagés avec la tablette
local Commandes = require(ReplicatedStorage:WaitForChild("TardisCommandes")).demarrer(exterieur, remote)

--------------------------------------------------------------------
-- Réglages
--------------------------------------------------------------------
local LARGEUR = 340
local POSITION_Y = 0.55          -- centre vertical du menu (0 = haut de l'écran, 1 = bas)
local HAUTEUR_ECRAN = 0.82       -- hauteur max du menu en proportion de l'écran
local TOUCHE = Enum.KeyCode.T    -- ouvrir / fermer
local TAILLE_PETITE = Config.TaillePetite or Config.TailleMin or 0.25

--------------------------------------------------------------------
-- Tiroir (ouvert et fermé avec la touche T : il n'y a plus d'onglet à l'écran depuis la V6.6.5)
--------------------------------------------------------------------
local gui = creer("ScreenGui", { Name = "TardisMenu", ResetOnSpawn = false, Enabled = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = joueur:WaitForChild("PlayerGui") })

local OUVERT = UDim2.new(0, 12, POSITION_Y, 0)
local FERME = UDim2.new(0, -LARGEUR - 24, POSITION_Y, 0)

local tiroir = creer("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = FERME, Size = UDim2.fromOffset(LARGEUR, 560),
	BackgroundColor3 = C.fond, ClipsDescendants = true, Parent = gui }, { UI.coin(18), UI.contour(C.ambre, 1.5, 0.5) })
local echelleTiroir = creer("UIScale", { Parent = tiroir })
creer("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.blanc, Color3.fromRGB(150, 160, 190)), Parent = tiroir })
-- Cadre extérieur : une seconde bordure sombre, comme un boîtier
creer("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 3, Transparency = 0.55, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = tiroir })

--------------------------------------------------------------------
-- En-tête
--------------------------------------------------------------------
local HAUTEUR_ENTETE = 78
local entete = creer("Frame", { Size = UDim2.new(1, 0, 0, HAUTEUR_ENTETE), BackgroundColor3 = C.blanc, Parent = tiroir },
{ UI.coin(18) })
local vortex = creer("UIGradient", { Color = UI.degradeEntete(), Parent = entete })
local vortexBas = creer("UIGradient", { Color = UI.degradeEntete() })
creer("Frame", { Position = UDim2.new(0, 0, 1, -18), Size = UDim2.new(1, 0, 0, 18), BackgroundColor3 = C.blanc,
	BorderSizePixel = 0, Parent = entete }, { vortexBas })
UI.verre(entete, 0.1, 18)
UI.prefsChangees.Event:Connect(function(cle)
	if cle == "theme" then
		vortex.Color = UI.degradeEntete()
		vortexBas.Color = UI.degradeEntete()
	end
end)
creer("Frame", { Position = UDim2.new(0, 0, 0, HAUTEUR_ENTETE), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = C.ambre,
	BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 3, Parent = tiroir })

-- Emblème : trois anneaux gallifreyens qui tournent
local embleme = creer("Frame", { Position = UDim2.fromOffset(14, 15), Size = UDim2.fromOffset(48, 48),
	BackgroundTransparency = 1, ZIndex = 3, Parent = entete })
local anneaux = {}
for i, info in { { 48, C.ambre, 1.5 }, { 34, C.cyan, 1.5 }, { 20, C.ambre, 1 } } do
	local anneau = creer("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(info[1], info[1]), BackgroundTransparency = 1, ZIndex = 3, Parent = embleme },
	{ UI.coin(99), UI.contour(info[2], info[3], 0.15) })
	for k = 0, i do
		local angle = (k / (i + 1)) * math.pi * 2
		creer("Frame", { AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5 + math.cos(angle) * 0.5, 0, 0.5 + math.sin(angle) * 0.5, 0),
			Size = UDim2.fromOffset(4, 4), BackgroundColor3 = info[2], ZIndex = 4, Parent = anneau }, { UI.coin(99) })
	end
	table.insert(anneaux, anneau)
end
local coeurEmbleme = creer("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(8, 8),
	BackgroundColor3 = C.ambre, ZIndex = 4, Parent = embleme }, { UI.coin(99) })

texte({ Text = "T.A.R.D.I.S.", Font = UI.POLICE_TITRE, TextSize = 18, Position = UDim2.fromOffset(74, 12),
	Size = UDim2.new(1, -170, 0, 22), ZIndex = 3, Parent = entete })
texte({ Text = "MENU RAPIDE  ·  V" .. tostring(Config.Version or "?"), Font = UI.POLICE_CODE, TextSize = 10, TextColor3 = C.texte2,
	Position = UDim2.fromOffset(74, 33), Size = UDim2.new(1, -170, 0, 12), ZIndex = 3, Parent = entete })
local pastille = creer("Frame", { Position = UDim2.fromOffset(74, 48), Size = UDim2.fromOffset(0, 20),
	AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = C.fond, BackgroundTransparency = 0.35, ZIndex = 3, Parent = entete },
{ UI.coin(99), creer("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 10) }), UI.pile(6, true),
	creer("UISizeConstraint", { MaxSize = Vector2.new(170, 20) }) })
pastille:FindFirstChildOfClass("UIListLayout").VerticalAlignment = Enum.VerticalAlignment.Center
local contourPastille = UI.contour(C.vert, 1, 0.4)
contourPastille.Parent = pastille
local pointPastille = creer("Frame", { Size = UDim2.fromOffset(7, 7), BackgroundColor3 = C.vert, LayoutOrder = 1, ZIndex = 4,
	Parent = pastille }, { UI.coin(99) })
local textePastille = texte({ Text = "Posé", Font = UI.POLICE_GRAS, TextSize = 11, Size = UDim2.new(0, 0, 1, 0),
	AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2, ZIndex = 4, TextTruncate = Enum.TextTruncate.AtEnd, Parent = pastille })

-- Bouton vers la tablette avancée
local boutonTablette = creer("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
	Size = UDim2.fromOffset(84, 40), BackgroundColor3 = C.bleu, Text = "", ZIndex = 3, Parent = entete },
{ UI.coin(10), UI.contour(C.ambre, 1, 0.3) })
texte({ Text = "TABLETTE", Font = UI.POLICE_GRAS, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center,
	Position = UDim2.fromOffset(0, 7), Size = UDim2.new(1, 0, 0, 14), ZIndex = 4, Parent = boutonTablette })
texte({ Text = "touche Y", TextSize = 10, TextColor3 = C.texte2, TextXAlignment = Enum.TextXAlignment.Center,
	Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 12), ZIndex = 4, Parent = boutonTablette })
UI.verre(boutonTablette, 0.12, 10)
boutonTablette:SetAttribute("CouleurBase", C.bleu)
UI.rendreVivant(boutonTablette)

--------------------------------------------------------------------
-- Contenu
--------------------------------------------------------------------
local contenu = creer("ScrollingFrame", { Position = UDim2.fromOffset(0, HAUTEUR_ENTETE + 1),
	Size = UDim2.new(1, 0, 1, -(HAUTEUR_ENTETE + 1)), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 3, ScrollBarImageColor3 = C.ambre, CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, Parent = tiroir },
{ UI.marges(12), UI.pile(10) })

-- 1) Statut
local carteStatut = UI.carte(contenu, 1, 6)
local ligneEtat = creer("Frame", { Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, LayoutOrder = 1, Parent = carteStatut })
local voyant = creer("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0),
	Size = UDim2.fromOffset(12, 12), BackgroundColor3 = C.vert, Parent = ligneEtat }, { UI.coin(99) })
local halo = creer("UIStroke", { Color = C.vert, Thickness = 3, Transparency = 0.6, Parent = voyant })
local etatTexte = texte({ Text = "POSÉ", Font = UI.POLICE_GRAS, TextSize = 15, Position = UDim2.fromOffset(24, 0),
	Size = UDim2.new(1, -90, 1, 0), Parent = ligneEtat })
local modeTexte = texte({ Text = "NORMAL", Font = UI.POLICE_CODE, TextSize = 10, TextColor3 = C.texte2, TextXAlignment = Enum.TextXAlignment.Right,
	Position = UDim2.new(1, -66, 0, 0), Size = UDim2.fromOffset(66, 24), Parent = ligneEtat })
local positionTexte = texte({ Text = "", TextSize = 12, TextColor3 = C.texte2, LayoutOrder = 2,
	TextTruncate = Enum.TextTruncate.AtEnd, Parent = carteStatut })
local badges = creer("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1, LayoutOrder = 3, Parent = carteStatut })
local pileBadges = UI.pile(6, true)
pcall(function() pileBadges.Wraps = true end)
pileBadges.Parent = badges
local B = {
	camouflage = UI.badge(badges, "CAMOUFLÉ", C.cyan, 1),
	verrou = UI.badge(badges, "VERROUILLÉ", C.rouge, 2),
	retreci = UI.badge(badges, "PETIT", C.ambre, 3),
	urgence = UI.badge(badges, "URGENCE", C.orange, 4),
	horsTension = UI.badge(badges, "HORS TENSION", C.texte2, 5),
	alerte = UI.badge(badges, "ALERTE", C.rouge, 6),
	bloque = UI.badge(badges, "DÉMARRAGE BLOQUÉ", C.orange, 7),
	volLibre = UI.badge(badges, "VOL LIBRE", C.cyan, 8),
	express = UI.badge(badges, "RAPIDE", C.vert, 9),
	sauvetage = UI.badge(badges, "SAUVETAGE", UI.couleurMode("Sauvetage"), 10),
	catastrophe = UI.badge(badges, "PARADOXE", C.rouge, 11),
}
local zoneProgression = creer("Frame", { Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, LayoutOrder = 4,
	Visible = false, Parent = carteStatut })
local progressionTexte = texte({ Text = "", Font = UI.POLICE_CODE, TextSize = 12, TextColor3 = C.texte2,
	Size = UDim2.new(1, 0, 0, 14), Parent = zoneProgression })
local barreFond = creer("Frame", { Position = UDim2.fromOffset(0, 21), Size = UDim2.new(1, 0, 0, 7),
	BackgroundColor3 = C.gris, Parent = zoneProgression }, { UI.coin(99), UI.contour(Color3.new(0, 0, 0), 1, 0.7) })
local barre = creer("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.blanc, Parent = barreFond }, { UI.coin(99) })
creer("UIGradient", { Color = ColorSequence.new(C.ambre, C.cyan), Parent = barre })
-- Le souffle du moteur : des points qui s'allument au rythme de la (dé)matérialisation
local souffles = creer("Frame", { Size = UDim2.new(1, 0, 0, 10), BackgroundTransparency = 1, LayoutOrder = 5, Visible = false, Parent = carteStatut },
{ UI.pile(4, true) })
souffles:FindFirstChildOfClass("UIListLayout").HorizontalAlignment = Enum.HorizontalAlignment.Center
local pointsSouffle = {}
for i = 1, 12 do
	pointsSouffle[i] = creer("Frame", { Size = UDim2.fromOffset(16, 4), BackgroundColor3 = C.gris, LayoutOrder = i, Parent = souffles }, { UI.coin(99) })
end

-- 2) Destination
UI.titreSection(contenu, "DESTINATION", 2)
local destination = creer("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1, LayoutOrder = 3, Parent = contenu }, { UI.pile(8) })
local recherche = creer("TextBox", { Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = C.panneau, Text = "",
	PlaceholderText = "Rechercher…", PlaceholderColor3 = C.texte2, TextColor3 = C.texte, Font = UI.POLICE, TextSize = 13,
	ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1, Parent = destination },
{ UI.coin(8), UI.contour(C.bleu, 1, 0.3), creer("UIPadding", { PaddingLeft = UDim.new(0, 30), PaddingRight = UDim.new(0, 12) }) })
texte({ Text = "○", TextSize = 14, TextColor3 = C.texte2, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(-22, 0),
	Size = UDim2.fromOffset(16, 32), Parent = recherche })
local segments = creer("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = C.panneau, LayoutOrder = 2,
	Parent = destination }, { UI.coin(8), UI.contour(Color3.new(0, 0, 0), 1, 0.7) })
local curseur = creer("Frame", { Size = UDim2.new(0.5, -4, 1, -6), Position = UDim2.fromOffset(3, 3),
	BackgroundColor3 = C.bleu, Parent = segments }, { UI.coin(6), UI.contour(C.ambre, 1, 0.5) })
UI.verre(curseur, 0.12, 6)
local segmentLieux = creer("TextButton", { Text = "◆  Lieux", Font = UI.POLICE_GRAS, TextSize = 12, TextColor3 = C.texte,
	BackgroundTransparency = 1, Size = UDim2.fromScale(0.5, 1), ZIndex = 3, Parent = segments })
local segmentJoueurs = creer("TextButton", { Text = "●  Joueurs", Font = UI.POLICE_GRAS, TextSize = 12, TextColor3 = C.texte2,
	BackgroundTransparency = 1, Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(0.5, 1), ZIndex = 3, Parent = segments })
local liste = creer("ScrollingFrame", { Size = UDim2.new(1, 0, 0, 156), BackgroundColor3 = Color3.fromRGB(4, 10, 24),
	BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = C.ambre, CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Parent = destination },
{ UI.coin(8), UI.contour(C.bleu, 1, 0.5), UI.marges(6), UI.pile(4) })
local listeVide = texte({ Text = "", TextSize = 12, TextColor3 = C.texte2, TextXAlignment = Enum.TextXAlignment.Center,
	Size = UDim2.new(1, 0, 0, 40), TextWrapped = true, LayoutOrder = 999, Visible = false, Parent = liste })
-- Fiche de la destination choisie
local fiche = creer("Frame", { Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = C.fond, LayoutOrder = 4, Parent = destination },
{ UI.coin(8), UI.contour(C.ambre, 1, 0.6) })
local ficheIcone = texte({ Text = "?", Font = UI.POLICE_GRAS, TextSize = 16, TextColor3 = C.ambre, TextXAlignment = Enum.TextXAlignment.Center,
	Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(36, 36), BackgroundTransparency = 0.6, BackgroundColor3 = C.panneauClair, Parent = fiche })
creer("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ficheIcone })
local ficheNom = texte({ Text = "Aucune destination", Font = UI.POLICE_GRAS, TextSize = 13, TextTruncate = Enum.TextTruncate.AtEnd,
	Position = UDim2.fromOffset(52, 9), Size = UDim2.new(1, -60, 0, 18), Parent = fiche })
local ficheInfo = texte({ Text = "Choisis un lieu ou un joueur.", Font = UI.POLICE_CODE, TextSize = 10, TextColor3 = C.texte2,
	TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(52, 28), Size = UDim2.new(1, -60, 0, 14), Parent = fiche })

-- 3) Protocoles
UI.titreSection(contenu, "PROTOCOLES", 4)
local protocoles = UI.carte(contenu, 5, 4)
local interrupteurUrgence = UI.interrupteur(protocoles, "Urgence", "Sons d'urgence et vol instable", C.orange, 1)
local interrupteurExpress = UI.interrupteur(protocoles, "Rapide", "Démat et remat en 2 secondes", C.vert, 2)
local interrupteurSauvetage = UI.interrupteur(protocoles, "Sauvetage", "Arrive en hauteur, descend en tournant, ouvre les portes", UI.couleurMode("Sauvetage"), 3)
local interrupteurInvisible = UI.interrupteur(protocoles, "Atterrissage invisible", "Il se pose déjà camouflé", C.cyan, 4)
-- État partagé avec la tablette (Urgence, Rapide et Sauvetage s'excluent)
Commandes.lierInterrupteurs({ urgence = interrupteurUrgence, express = interrupteurExpress, sauvetage = interrupteurSauvetage, invisible = interrupteurInvisible })
texte({ Text = "Zone REFUSE au départ ou à l'arrivée : urgence imposée. Destination choisie avant DÉMAT : " .. tostring(Config.DureeVortexAuto or 10)
	.. " s de vortex puis REMAT automatique ; sinon, choisis dans le vortex et clique REMAT.", TextSize = 10, TextColor3 = C.texte2, TextWrapped = true,
	AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 5, Parent = protocoles })

-- 4) Actions
local actions = creer("Frame", { Size = UDim2.new(1, 0, 0, 58), BackgroundTransparency = 1, LayoutOrder = 6,
	Parent = contenu }, { UI.pile(10, true) })
local boutonDemat = UI.boutonPrincipal(actions, "DÉMATÉRIALISER", "Décoller", 1)
local boutonRemat = UI.boutonPrincipal(actions, "MATÉRIALISER", "Atterrir", 2)

-- 5) Systèmes : intégrité, bouclier, raccourcis
UI.titreSection(contenu, "SYSTÈMES", 7)
local carteSystemes = UI.carte(contenu, 8, 8)
local function jauge(nom, ordre, couleur)
	local cadre = creer("Frame", { Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, LayoutOrder = ordre, Parent = carteSystemes })
	texte({ Text = nom, Font = UI.POLICE_GRAS, TextSize = 10, TextColor3 = C.texte2, Size = UDim2.new(1, -60, 0, 12), Parent = cadre })
	local valeur = texte({ Text = "—", Font = UI.POLICE_CODE, TextSize = 11, TextColor3 = couleur, TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(1, -60, 0, 0), Size = UDim2.fromOffset(60, 12), Parent = cadre })
	local fond = creer("Frame", { Position = UDim2.fromOffset(0, 15), Size = UDim2.new(1, 0, 0, 7), BackgroundColor3 = C.gris, Parent = cadre },
	{ UI.coin(99), UI.contour(Color3.new(0, 0, 0), 1, 0.7) })
	local barreJauge = creer("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = couleur, Parent = fond }, { UI.coin(99) })
	return { cadre = cadre, valeur = valeur, barre = barreJauge }
end
local jaugeIntegrite = jauge("INTÉGRITÉ", 1, C.vert)
local jaugeBouclier = jauge("BOUCLIER", 2, C.cyan)
local raccourcis = creer("Frame", { Size = UDim2.new(1, 0, 0, 128), BackgroundTransparency = 1, LayoutOrder = 3, Parent = carteSystemes },
{ creer("UIGridLayout", { CellSize = UDim2.new(0.5, -5, 0, 60), CellPadding = UDim2.fromOffset(10, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
local function tuile(nom, icone, ordre)
	local bouton = creer("TextButton", { BackgroundColor3 = C.fond, Text = "", LayoutOrder = ordre, Parent = raccourcis },
	{ UI.coin(10), UI.contour(C.bleu, 1, 0.4) })
	local lampe = creer("Frame", { Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(8, 8),
		BackgroundColor3 = C.gris, Parent = bouton }, { UI.coin(99) })
	local haloLampe = creer("UIStroke", { Color = C.gris, Thickness = 2, Transparency = 0.7, Parent = lampe })
	texte({ Text = icone, TextSize = 15, TextColor3 = C.texte2, TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, -10, 0, 18), Parent = bouton })
	texte({ Text = nom, Font = UI.POLICE_GRAS, TextSize = 12, Position = UDim2.fromOffset(10, 24),
		Size = UDim2.new(1, -20, 0, 16), Parent = bouton })
	local etat = texte({ Text = "", TextSize = 10, TextColor3 = C.texte2, Position = UDim2.fromOffset(10, 40),
		Size = UDim2.new(1, -20, 0, 14), TextTruncate = Enum.TextTruncate.AtEnd, Parent = bouton })
	UI.verre(bouton, 0.06, 10)
	UI.rendreVivant(bouton)
	return { bouton = bouton, lampe = lampe, halo = haloLampe, etat = etat }
end
local T = {
	camouflage = tuile("Camouflage", "◐", 1),
	portes = tuile("Portes", "■", 2),
	verrou = tuile("Verrou", "⊘", 3),
	taille = tuile("Taille", "◢", 4),
}

-- Pied de page : les touches
texte({ Text = "T  fermer   ·   Y  tablette   ·   E  portes et console", Font = UI.POLICE_CODE, TextSize = 10, TextColor3 = C.texte2,
	TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 98, Parent = contenu })
creer("Frame", { Size = UDim2.new(1, 0, 0, 10), BackgroundTransparency = 1, LayoutOrder = 99, Parent = contenu })

-- Matière de l'écran : lignes fines et vignette (au-dessus du contenu, sous les voiles)
local lignes = UI.lignesEcran(tiroir, 28, 0.93)
lignes.ZIndex = 10
UI.vignette(tiroir, 0.35).ZIndex = 11
-- Ligne de balayage à l'ouverture
local balayage = creer("Frame", { Position = UDim2.new(0, 0, 0, -4), Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = C.blanc,
	BorderSizePixel = 0, ZIndex = 12, Parent = tiroir })
creer("UIGradient", { Color = ColorSequence.new(C.cyan, C.cyan), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }), Parent = balayage })

-- TARDIS détruit : un voile gris foncé sur tout le menu, avec "TARDIS DÉTRUIT" en diagonale
local voileAvarie = creer("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(40, 32, 20), BackgroundTransparency = 0.12,
	Visible = false, ZIndex = 14, Parent = tiroir }, { UI.coin(18) })
texte({ Text = "AVARIE", Font = UI.POLICE_TITRE, TextSize = 36, TextColor3 = C.ambre, TextXAlignment = Enum.TextXAlignment.Center,
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(600, 50), Rotation = -30, ZIndex = 15, Parent = voileAvarie })
texte({ Text = "Intégrité à 0 % : réparez le rotor (maintenir E).", TextSize = 12, TextColor3 = C.texte, TextXAlignment = Enum.TextXAlignment.Center,
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 60), Size = UDim2.fromOffset(300, 20), ZIndex = 15, Parent = voileAvarie })
local voileDetruit = creer("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(28, 30, 36), BackgroundTransparency = 0.08,
	Visible = false, ZIndex = 15, Parent = tiroir }, { UI.coin(18) })
texte({ Text = "TARDIS DÉTRUIT", Font = UI.POLICE_TITRE, TextSize = 34, TextColor3 = Color3.fromRGB(255, 70, 70), TextXAlignment = Enum.TextXAlignment.Center,
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(600, 50), Rotation = -30, ZIndex = 16, Parent = voileDetruit })
texte({ Text = "Reconstitution automatique dans quelques minutes.", TextSize = 12, TextColor3 = C.texte2, TextXAlignment = Enum.TextXAlignment.Center,
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 60), Size = UDim2.fromOffset(300, 20), ZIndex = 16, Parent = voileDetruit })

-- Notification
local notification = creer("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 60),
	Size = UDim2.new(1, -24, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.panneauClair,
	Visible = false, ZIndex = 20, Parent = tiroir }, { UI.coin(10), UI.marges(10) })
local contourNotif = UI.contour(C.vert, 1.5, 0)
contourNotif.Parent = notification
local notifTexte = texte({ Text = "", TextSize = 13, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y,
	Size = UDim2.new(1, 0, 0, 0), ZIndex = 21, Parent = notification })

local jeton = 0
local function notifier(message, reussi)
	if typeof(message) ~= "string" or string.sub(message, 1, 2) == "__" then return end
	jeton += 1
	local moi = jeton
	local couleur = reussi and C.vert or C.rouge
	contourNotif.Color = couleur
	notifTexte.TextColor3 = UI.eclaircir(couleur, 0.4)
	notifTexte.Text = (reussi and "●  " or "×  ") .. message
	UI.son(reussi and "Notification" or "Alerte")
	notification.Visible = true
	notification.Position = UDim2.new(0.5, 0, 1, 60)
	animer(notification, 0.35, { Position = UDim2.new(0.5, 0, 1, -12) }, Enum.EasingStyle.Back)
	task.delay(4, function()
		if moi ~= jeton then return end
		animer(notification, 0.3, { Position = UDim2.new(0.5, 0, 1, 70) }).Completed:Wait()
		if moi == jeton then notification.Visible = false end
	end)
end

--------------------------------------------------------------------
-- État et mises à jour
--------------------------------------------------------------------
local ouvert = false
local mode = "lieux"
local choix = nil -- { type = "lieu", nom } ou { type = "joueur", id, nom } ou { type = "precedent", nom }
local elementsListe, boutonsChoix = {}, {}

local function cleDe(c)
	if not c then return nil end
	if c.type == "precedent" then return "precedent" end
	return c.type == "lieu" and ("lieu:" .. c.nom) or ("joueur:" .. c.id)
end

-- Distance (studs) entre le TARDIS et la destination choisie, si on peut la connaître
local function distanceDe(c)
	if not c then return nil end
	local origine = exterieur:GetPivot().Position
	if c.type == "lieu" then
		local dossier = Config.dossierDestinations(false)
		local part = dossier and dossier:FindFirstChild(c.nom, true)
		return part and part:IsA("BasePart") and (part.Position - origine).Magnitude or nil
	elseif c.type == "joueur" then
		local autre = Players:GetPlayerByUserId(c.id)
		local racine = autre and autre.Character and autre.Character:FindFirstChild("HumanoidRootPart")
		return racine and (racine.Position - origine).Magnitude or nil
	end
	return nil
end

local function majFiche()
	local c = choix
	if not c then
		ficheIcone.Text = "?"
		ficheNom.Text = "Aucune destination"
		ficheInfo.Text = "Choisis un lieu ou un joueur."
		return
	end
	local modeVoyage = Commandes.mode()
	local dDemat, cDemat = Config.Timing(E.Demat, modeVoyage)
	local dRemat, cRemat = Config.Timing(E.Remat, modeVoyage)
	local trajet = string.format("~%d s", dDemat + cDemat + dRemat + cRemat + (Config.DureeVortexAuto or 10))
		.. (modeVoyage ~= "Normal" and ("  ·  " .. Config.libelleMode(modeVoyage, true)) or "")
	local distance = distanceDe(c)
	local texteDistance = distance and string.format("%d studs", distance) or "—"
	if c.type == "lieu" then
		ficheIcone.Text = "◆"
		ficheNom.Text = c.nom
		ficheInfo.Text = "LIEU  ·  " .. texteDistance .. "  ·  " .. trajet
	elseif c.type == "precedent" then
		ficheIcone.Text = "◄"
		ficheNom.Text = "Retour : " .. c.nom
		ficheInfo.Text = "DERNIÈRE DESTINATION  ·  " .. trajet
	else
		ficheIcone.Text = "●"
		ficheNom.Text = c.nom
		ficheInfo.Text = "JOUEUR  ·  " .. texteDistance .. "  ·  " .. trajet
	end
end

local function majTuile(t, actif, texteEtat, couleur, disponible)
	UI.setDisponible(t.bouton, disponible, C.fond)
	animer(t.lampe, 0.2, { BackgroundColor3 = actif and couleur or C.gris })
	t.halo.Color = actif and couleur or C.gris
	t.etat.Text = texteEtat
	t.etat.TextColor3 = actif and couleur or C.texte2
end

local function majInterface()
	local etat = exterieur:GetAttribute("Etat") or E.Pose
	local camoufle = exterieur:GetAttribute("Camouflage") == true
	local echelle = exterieur:GetAttribute("Echelle") or 1
	local petit = echelle < 0.999
	local porte = exterieur:GetAttribute("Porteur") ~= nil
	local verrouille = exterieur:GetAttribute("PortesVerrouillees") == true
	local modeEnCours = Config.modeDe(exterieur)
	local urgenceEnCours = modeEnCours == "Urgence" and etat ~= E.Pose
	local alimente = exterieur:GetAttribute("Alimentation") ~= false
	local alerte = exterieur:GetAttribute("Alerte") == true
	local bloque = exterieur:GetAttribute("DemarrageBloque") == true
	local porteOuverte = exterieur:GetAttribute("PorteOuverte") == true
	local volLibre = exterieur:GetAttribute("VolLibre") ~= nil
	local pose = etat == E.Pose and not volLibre -- en vol libre, il n'est plus vraiment "posé"

	-- Statut
	local libelle = UI.LIBELLES[etat] or { "?", C.texte2, "?" }
	local couleurEtat, nomEtat, nomCourt = libelle[2], libelle[1], libelle[3]
	if not alimente then
		couleurEtat, nomEtat, nomCourt = C.gris, "HORS TENSION", "Hors tension"
	elseif volLibre then
		couleurEtat, nomEtat, nomCourt = C.cyan, "VOL LIBRE", "Vol libre"
	elseif alerte then
		couleurEtat = C.rouge
	end
	etatTexte.Text = nomEtat
	etatTexte.TextColor3 = couleurEtat
	animer(voyant, 0.3, { BackgroundColor3 = couleurEtat })
	halo.Color = couleurEtat
	-- Mode : celui du voyage en cours, sinon le protocole choisi
	local modeAffiche = etat ~= E.Pose and modeEnCours or Commandes.mode()
	modeTexte.Text = Config.libelleMode(modeAffiche, true)
	modeTexte.TextColor3 = UI.couleurMode(modeAffiche)
	positionTexte.Text = "●  " .. tostring(exterieur:GetAttribute("Position") or "?")
	textePastille.Text = (alerte and "Alerte · " or "") .. nomCourt
	animer(pointPastille, 0.3, { BackgroundColor3 = couleurEtat })
	contourPastille.Color = couleurEtat
	animer(coeurEmbleme, 0.3, { BackgroundColor3 = couleurEtat })

	B.camouflage.Visible = camoufle
	B.verrou.Visible = verrouille
	B.retreci.Visible = petit
	B.urgence.Visible = urgenceEnCours
	B.express.Visible = modeEnCours == "Express" and etat ~= E.Pose
	B.sauvetage.Visible = modeEnCours == "Sauvetage" and etat ~= E.Pose
	B.catastrophe.Visible = modeEnCours == "Catastrophe" and etat ~= E.Pose
	B.horsTension.Visible = not alimente
	B.alerte.Visible = alerte
	B.bloque.Visible = bloque
	B.volLibre.Visible = volLibre
	badges.Visible = camoufle or verrouille or petit or urgenceEnCours or B.express.Visible or B.sauvetage.Visible or B.catastrophe.Visible
		or not alimente or alerte or bloque or volLibre

	-- Actions principales
	local poche = exterieur:GetAttribute("Porteur") == joueur.UserId -- je porte le TARDIS : téléportation de poche
	local dematOk = pose and not porte and alimente and not bloque
	if poche then dematOk = choix ~= nil and alimente and not bloque end
	local rematOk = etat == E.Vol and (choix ~= nil or petit) and alimente
	boutonDemat.SousTitre.Text = poche and (choix and "Téléportation de poche" or "Choisis une destination") or "Décoller"
	UI.setDisponible(boutonDemat, dematOk, C.bleu)
	UI.setDisponible(boutonRemat, rematOk, C.bleu)
	if Commandes.secondesAutoRemat() and etat == E.Vol then
		boutonRemat.SousTitre.Text = string.format("Auto dans %d s", math.ceil(Commandes.secondesAutoRemat()))
	else
		boutonRemat.SousTitre.Text = petit and "Sur place (petit)" or (etat == E.Vol and not choix and "Choisis une destination" or "Atterrir")
	end
	boutonDemat.Lueur.Color = dematOk and C.ambre or C.gris
	boutonRemat.Lueur.Color = rematOk and C.ambre or C.gris
	-- Paradoxe : le bouton MATÉRIALISER demande une confirmation (rouge)
	UI.confirmationBouton(boutonRemat, Commandes.paradoxeArme())

	-- Systèmes
	majTuile(T.camouflage, camoufle, camoufle and "ACTIVÉ" or "Inactif", C.cyan, pose and alimente)
	local seuil = Config.TailleOuverturePortes or 1
	local portesPossibles = pose and (porteOuverte or (not verrouille and echelle >= seuil - 0.001))
	majTuile(T.portes, porteOuverte, porteOuverte and "Ouvertes · fermer" or "Fermées · ouvrir", C.vert, portesPossibles)
	majTuile(T.verrou, verrouille, verrouille and "VERROUILLÉ" or "Ouvert", C.rouge, true)
	majTuile(T.taille, petit, petit and "PETIT · agrandir" or "Grand · rapetisser", C.ambre, pose and alimente and not porte)
	-- Intégrité (points de vie) et bouclier
	local integrite = exterieur:GetAttribute("PointsDeVie")
	if integrite then
		local couleurIntegrite = integrite <= 20 and C.rouge or (integrite <= 50 and C.ambre or C.vert)
		jaugeIntegrite.barre.Size = UDim2.fromScale(math.clamp(integrite / 100, 0, 1), 1)
		jaugeIntegrite.barre.BackgroundColor3 = couleurIntegrite
		jaugeIntegrite.valeur.Text = string.format("%d %%", integrite)
		jaugeIntegrite.valeur.TextColor3 = couleurIntegrite
	end
	local bouclierActif = exterieur:GetAttribute("BouclierJoueurs") == true or exterieur:GetAttribute("BouclierBalles") == true
		or exterieur:GetAttribute("BouclierComplet") == true
	local energie = exterieur:GetAttribute("BouclierEnergie") or 100
	jaugeBouclier.barre.Size = UDim2.fromScale(bouclierActif and math.clamp(energie / 100, 0, 1) or 0, 1)
	jaugeBouclier.barre.BackgroundColor3 = energie <= 15 and C.rouge or C.cyan
	jaugeBouclier.valeur.Text = bouclierActif and string.format("%d %%", energie) or "inactif"
	jaugeBouclier.valeur.TextColor3 = bouclierActif and (energie <= 15 and C.rouge or C.cyan) or C.texte2

	voileAvarie.Visible = exterieur:GetAttribute("Avarie") == true and not voileDetruit.Visible
	voileDetruit.Visible = exterieur:GetAttribute("Detruit") == true

	-- Sélection
	local cleChoisie = cleDe(choix)
	for cle, bouton in boutonsChoix do
		local choisi = cle == cleChoisie
		UI.colorer(bouton, choisi and C.panneauClair or C.panneau)
		bouton.Barre.Visible = choisi
	end
	majFiche()
end

local function ajouterElement(texteEl, sousTexte, c, ordre)
	local bouton = creer("TextButton", { Size = UDim2.new(1, 0, 0, sousTexte and 38 or 30), BackgroundColor3 = C.panneau,
		Text = "", LayoutOrder = ordre, Parent = liste }, { UI.coin(6) })
	creer("Frame", { Name = "Barre", Size = UDim2.new(0, 3, 1, -10), Position = UDim2.fromOffset(4, 5),
		BackgroundColor3 = C.ambre, Visible = false, Parent = bouton }, { UI.coin(99) })
	texte({ Text = (c.type == "lieu" and "◆") or (c.type == "precedent" and "◄") or "●", TextSize = 12, TextColor3 = C.ambre,
		TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(0, 16, 1, 0), Parent = bouton })
	texte({ Text = texteEl, Font = UI.POLICE_GRAS, TextSize = 13, Position = UDim2.fromOffset(30, sousTexte and 3 or 6),
		Size = UDim2.new(1, -36, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd, Parent = bouton })
	if sousTexte then
		texte({ Text = sousTexte, TextSize = 11, TextColor3 = C.texte2, Position = UDim2.fromOffset(30, 20),
			Size = UDim2.new(1, -36, 0, 14), TextTruncate = Enum.TextTruncate.AtEnd, Parent = bouton })
	end
	bouton:SetAttribute("CouleurBase", C.panneau)
	UI.rendreVivant(bouton)
	bouton.Activated:Connect(function()
		choix = c
		majInterface()
	end)
	boutonsChoix[cleDe(c)] = bouton
	table.insert(elementsListe, bouton)
end

local function construireListe()
	for _, element in elementsListe do element:Destroy() end
	table.clear(elementsListe)
	table.clear(boutonsChoix)
	local filtre = string.lower(recherche.Text)
	local function garde(nom)
		return filtre == "" or string.find(string.lower(nom), filtre, 1, true) ~= nil
	end

	local ordre = 0
	local noms = {}
	-- En tête de liste : retour là d'où le TARDIS est parti
	local precedentNom = exterieur:GetAttribute("PrecedentNom")
	if mode == "lieux" and precedentNom and garde("Retour " .. precedentNom) then
		ordre += 1
		ajouterElement("Retour : " .. precedentNom, "Dernière destination", { type = "precedent", nom = precedentNom }, ordre)
	end
	-- Les favoris (étoilés dans la tablette) d'abord
	local lieux = {}
	for nom in string.gmatch(exterieur:GetAttribute("ListeDestinations") or "", "[^\n]+") do
		noms[nom] = true
		table.insert(lieux, nom)
	end
	local ordreOrigine = {}
	for i, nom in lieux do ordreOrigine[nom] = i end
	table.sort(lieux, function(a, b)
		local fa, fb = UI.estFavori(a), UI.estFavori(b)
		if fa ~= fb then return fa end
		return ordreOrigine[a] < ordreOrigine[b]
	end)
	for _, nom in lieux do
		if mode == "lieux" and garde(nom) then
			ordre += 1
			ajouterElement(nom, UI.estFavori(nom) and "Favori" or nil, { type = "lieu", nom = nom }, ordre)
		end
	end
	if mode == "joueurs" then
		local joueurs = Players:GetPlayers()
		table.sort(joueurs, function(a, b) return a.DisplayName:lower() < b.DisplayName:lower() end)
		for _, autre in joueurs do
			if garde(autre.DisplayName) or garde(autre.Name) then
				ordre += 1
				ajouterElement(autre.DisplayName .. (autre == joueur and "  (toi)" or ""), "@" .. autre.Name,
					{ type = "joueur", id = autre.UserId, nom = autre.DisplayName }, ordre)
			end
		end
	end
	listeVide.Text = mode == "lieux" and "Aucun lieu." or "Aucun joueur."
	listeVide.Visible = ordre == 0

	if choix then
		local existe = (choix.type == "lieu" and noms[choix.nom]) or (choix.type == "joueur" and Players:GetPlayerByUserId(choix.id))
			or (choix.type == "precedent" and precedentNom)
		if not existe then choix = nil end
	end
	majInterface()
end

local function changerMode(nouveau)
	mode = nouveau
	animer(curseur, 0.25, { Position = nouveau == "lieux" and UDim2.fromOffset(3, 3) or UDim2.new(0.5, 1, 0, 3) })
	segmentLieux.TextColor3 = nouveau == "lieux" and C.texte or C.texte2
	segmentJoueurs.TextColor3 = nouveau == "joueurs" and C.texte or C.texte2
	construireListe()
end
segmentLieux.Activated:Connect(function() changerMode("lieux") end)
segmentJoueurs.Activated:Connect(function() changerMode("joueurs") end)
recherche:GetPropertyChangedSignal("Text"):Connect(construireListe)

--------------------------------------------------------------------
-- Commandes
--------------------------------------------------------------------
local function basculerMenu()
	ouvert = not ouvert
	animer(tiroir, 0.45, { Position = ouvert and OUVERT or FERME }, ouvert and Enum.EasingStyle.Quint or Enum.EasingStyle.Quad,
		ouvert and Enum.EasingDirection.Out or Enum.EasingDirection.In)
	if ouvert then
		-- Allumage : la ligne de balayage traverse le tiroir
		balayage.Position = UDim2.new(0, 0, 0, -4)
		animer(balayage, 0.7, { Position = UDim2.new(0, 0, 1, 4) }, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0.1)
		UI.son("Notification")
		majInterface()
	else
		recherche:ReleaseFocus()
	end
end

-- La tablette (script TardisTablette) écoute cet attribut local du joueur
boutonTablette.Activated:Connect(function()
	joueur:SetAttribute("TardisTablette", true)
end)
joueur:GetAttributeChangedSignal("TardisTablette"):Connect(function()
	if joueur:GetAttribute("TardisTablette") and ouvert then
		basculerMenu()
	end
end)

-- Destination choisie, au format attendu par le serveur (nil si rien n'est choisi)
local function donneesDestination()
	return Commandes.donnees(choix)
end

-- La destination choisie est partagée avec les commandes de port (bouton DÉMAT quand on porte le TARDIS)
task.spawn(function()
	local derniereCle = nil
	while true do
		task.wait(0.2)
		local cle = cleDe(choix)
		if cle ~= derniereCle then
			derniereCle = cle
			if choix then UI.destinationPoche = { fournir = donneesDestination, nom = choix.nom or "?" } end
		end
	end
end)

boutonDemat.Activated:Connect(function()
	if boutonDemat:GetAttribute("Disponible") == false then
		if exterieur:GetAttribute("Porteur") == joueur.UserId and not choix then
			notifier("Choisis d'abord un lieu ou un joueur.", false)
		end
		return
	end
	Commandes.demat(choix)
end)

boutonRemat.Activated:Connect(function()
	-- Pendant le compte à rebours de la rematérialisation automatique, un appui la lance tout de suite
	if not Commandes.secondesAutoRemat() and boutonRemat:GetAttribute("Disponible") == false then
		if (exterieur:GetAttribute("Etat") or E.Pose) == E.Vol and not choix then
			notifier("Choisis d'abord un lieu ou un joueur.", false)
		end
		return
	end
	Commandes.remat(choix)
end)

T.camouflage.bouton.Activated:Connect(function()
	if T.camouflage.bouton:GetAttribute("Disponible") == false then return end
	remote:FireServer("Camouflage")
end)
T.portes.bouton.Activated:Connect(function()
	if T.portes.bouton:GetAttribute("Disponible") == false then return end
	remote:FireServer("Portes")
end)
T.verrou.bouton.Activated:Connect(function()
	remote:FireServer("Verrou")
end)
T.taille.bouton.Activated:Connect(function()
	if T.taille.bouton:GetAttribute("Disponible") == false then return end
	local petit = (exterieur:GetAttribute("Echelle") or 1) < 0.999
	remote:FireServer("Taille", { facteur = petit and 1 or TAILLE_PETITE })
end)

Commandes.annonce.Event:Connect(function(message, reussi)
	if ouvert then notifier(message, reussi) end
end)
remote.OnClientEvent:Connect(function(message, reussi)
	if ouvert then notifier(message, reussi) end
end)

UserInputService.InputBegan:Connect(function(input, traite)
	if traite or not gui.Enabled then return end
	if input.KeyCode == UI.touche("menu", TOUCHE) then basculerMenu() end
end)

--------------------------------------------------------------------
-- Animations
--------------------------------------------------------------------
local derniereSecondeAuto = nil
local prochaineMajLente = 0
local confirmationAffichee = false
RunService.RenderStepped:Connect(function(dt)
	if not gui.Enabled then return end
	local etat = exterieur:GetAttribute("Etat") or E.Pose
	local enMouvement = etat ~= E.Pose
	local vitesse = enMouvement and 3 or 1
	local t = os.clock()
	if not ouvert then return end
	-- Deux fois par seconde : la fiche (distance) et le mode (il peut changer depuis la tablette)
	if t >= prochaineMajLente then
		prochaineMajLente = t + 0.5
		majFiche()
		local modeAffiche = etat ~= E.Pose and Config.modeDe(exterieur) or Commandes.mode()
		modeTexte.Text = Config.libelleMode(modeAffiche, true)
		modeTexte.TextColor3 = UI.couleurMode(modeAffiche)
	end
	-- Confirmation d'un paradoxe : le bouton rouge clignote, puis revient à la normale quand la fenêtre se ferme
	local arme = Commandes.paradoxeArme()
	if arme ~= confirmationAffichee then
		confirmationAffichee = arme
		majInterface()
	end
	if arme then boutonRemat.Lueur.Transparency = 0.2 + 0.5 * (0.5 + 0.5 * math.sin(t * 8)) end

	for i, anneau in anneaux do
		anneau.Rotation += dt * (i % 2 == 0 and -1 or 1) * (20 + i * 18) * vitesse
	end
	vortex.Rotation = (t * 10 * vitesse) % 360
	vortex.Offset = Vector2.new(math.sin(t * 0.35) * 0.35, 0)
	local lueur = 0.2 + 0.5 * (0.5 + 0.5 * math.sin(t * 3))
	for _, bouton in { boutonDemat, boutonRemat } do
		if not (bouton == boutonRemat and Commandes.paradoxeArme()) then
			bouton.Lueur.Transparency = bouton:GetAttribute("Disponible") and lueur or 0.7
		end
	end

	local ecoule = workspace:GetServerTimeNow() - (exterieur:GetAttribute("DebutEtat") or 0)
	local modeEnCours = Config.modeDe(exterieur)
	local souffle = Config.Souffle(etat, ecoule, modeEnCours)
	-- Le voyant respire avec le moteur en voyage, bat lentement posé, vite en alerte
	local rythme = exterieur:GetAttribute("Alerte") and 6 or 2
	halo.Transparency = enMouvement and (0.75 - 0.55 * souffle) or (0.5 + 0.4 * (0.5 + 0.5 * math.sin(t * rythme)))
	halo.Thickness = enMouvement and (2 + 3 * souffle) or 3

	if etat == E.Demat or etat == E.Remat then
		local duree, decalage = Config.Timing(etat, modeEnCours)
		local total = duree + decalage
		local p = math.clamp(ecoule / total, 0, 1)
		zoneProgression.Visible = true
		souffles.Visible = true
		barreFond.Visible = true
		barre.Size = UDim2.fromScale(p, 1)
		progressionTexte.Text = string.format("%3d %%  ·  T-%s", math.floor(p * 100), UI.formatTemps(total - ecoule + 0.99))
		local couleurMode = (Config.Modes[modeEnCours] or Config.Modes.Normal).CouleurRotor or C.ambre
		for i, point in pointsSouffle do
			local allume = (i - 1) / #pointsSouffle < p
			point.BackgroundColor3 = allume and couleurMode:Lerp(C.blanc, 0.6 * souffle) or C.gris
		end
		-- Le bouton de la phase en cours se remplit
		UI.progressionBouton(etat == E.Demat and boutonDemat or boutonRemat, p, couleurMode)
		UI.progressionBouton(etat == E.Demat and boutonRemat or boutonDemat, 0)
	elseif etat == E.Vol then
		zoneProgression.Visible = true
		souffles.Visible = true
		barreFond.Visible = false
		progressionTexte.Text = "VORTEX  ·  " .. UI.formatTemps(ecoule)
		local tete = (t * 10) % #pointsSouffle
		for i, point in pointsSouffle do
			local d = (tete - i) % #pointsSouffle
			point.BackgroundColor3 = C.gris:Lerp(C.cyan, math.max(0, 1 - d / 5))
		end
		UI.progressionBouton(boutonDemat, 1, C.cyan)
		-- Compte à rebours de la rematérialisation automatique : le bouton MATÉRIALISER se remplit
		local secondes = Commandes.secondesAutoRemat()
		UI.progressionBouton(boutonRemat, secondes and (1 - secondes / Commandes.DELAI_AUTO_REMAT) or 0, C.ambre)
		local entiere = secondes and math.ceil(secondes) or nil
		if entiere ~= derniereSecondeAuto then
			derniereSecondeAuto = entiere
			majInterface()
		end
	else
		zoneProgression.Visible = false
		souffles.Visible = false
		UI.progressionBouton(boutonDemat, 0)
		UI.progressionBouton(boutonRemat, 0)
	end
end)

local function majTaille()
	local ecran = camera.ViewportSize
	local echelle = math.clamp(ecran.Y / 820, 0.72, 1) * UI.tailleInterface()
	echelleTiroir.Scale = echelle
	tiroir.Size = UDim2.fromOffset(LARGEUR, math.clamp(ecran.Y * HAUTEUR_ECRAN / echelle, 380, 760))
end
camera:GetPropertyChangedSignal("ViewportSize"):Connect(majTaille)
UI.prefsChangees.Event:Connect(function(cle) if cle == "taille" then majTaille() end end)
majTaille()

--------------------------------------------------------------------
-- Mises à jour automatiques
--------------------------------------------------------------------
for _, attribut in { "Etat", "Camouflage", "Position", "PortesVerrouillees", "Retreci", "Porteur", "Mode", "PorteOuverte",
	"Echelle", "Alimentation", "Alerte", "DemarrageBloque", "VolLibre", "BouclierJoueurs", "BouclierBalles", "MinuterieFin", "Intrusion", "Theme", "Projecteur", "Couleur", "Enseigne", "Detruit", "AutoDestructionDebut", "StyleInterieur", "StyleConsole", "CouleurMurs", "Jukebox", "BouclierComplet", "BouclierEnergie", "PointsDeVie", "Avarie", "Stabilisateur", "Decoration", "Reflets" } do
	exterieur:GetAttributeChangedSignal(attribut):Connect(majInterface)
end
exterieur:GetAttributeChangedSignal("ListeDestinations"):Connect(construireListe)
exterieur:GetAttributeChangedSignal("PrecedentNom"):Connect(construireListe)
Players.PlayerAdded:Connect(construireListe)
Players.PlayerRemoving:Connect(function() task.defer(construireListe) end)
-- Les protocoles changent (ici ou dans la tablette) : le mode affiché et le temps de trajet suivent
for _, inter in { interrupteurUrgence, interrupteurExpress, interrupteurSauvetage, interrupteurInvisible } do
	local ancien = inter.surChangement
	inter.surChangement = function(actif)
		if ancien then ancien(actif) end
		majInterface()
	end
end
UI.prefsChangees.Event:Connect(function(cle) if cle == "favoris" or cle == "modeVoyage" then construireListe() end end)

local function majAcces()
	gui.Enabled = joueur:GetAttribute("TardisPilote_" .. def.Nom) == true
end
joueur:GetAttributeChangedSignal("TardisPilote_" .. def.Nom):Connect(majAcces)
majAcces()
changerMode("lieux")
