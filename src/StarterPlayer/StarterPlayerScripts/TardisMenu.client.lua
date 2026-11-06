-- StarterPlayer > StarterPlayerScripts > TardisMenu (LocalScript)
-- Menu RAPIDE du TARDIS : simple et rapide, dans un tiroir sur le bord gauche de l'écran.
--   Statut (état, lieu, badges, progression) · Destination (lieux / joueurs, tableau avec distance et statut) · Protocoles
--   Démat / Remat (avec la progression du voyage) · Systèmes (intégrité, bouclier, raccourcis)
--   Bouton "Tablette" : ouvre la tablette avancée (script TardisTablette).
-- Visible seulement pour les pilotes autorisés. Toutes les commandes sont revérifiées par le serveur.
-- Touche T : ouvrir / fermer. (V6.7 : refonte de l'apparence et de l'organisation.)
-- V6.9.10.6 : charte « Hologramme de confinement » : plaque (titre, badge, ligne de données, bande de danger), tableau
-- des destinations DESTINATION | DIST. | STATUT (zones REFUSE et SANS_EXPRESS), puces des modes, boutons à coins coupés,
-- ligne d'aide ; ↑ ↓ choisissent une destination et Entrée lance DÉMAT (REMAT dans le vortex) tant que le menu est ouvert.
-- V6.9.15 : le menu se déplace en glissant son en-tête (position gardée dans les préférences, rétablie depuis les
-- réglages de la tablette) ; option « ouverture des menus sans animation » ; le menu fermé ne dépasse plus à grande taille.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = nil
pcall(function() ContextActionService = game:GetService("ContextActionService") end)

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
local LARGEUR = 370
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

-- Panneau de la charte (coins coupés, filet lumineux, lueur, balayage) ; « corps » reçoit tout le contenu
local tiroir, corps = UI.panneauCoupe({ Name = "Tiroir", AnchorPoint = Vector2.new(0, 0.5), Position = FERME, Size = UDim2.fromOffset(LARGEUR, 560),
	BackgroundColor3 = C.fond, Parent = gui }, { coupe = 16, rayon = 18, balayage = false }) -- (balayage : UI.lignesEcran, plus bas)
local echelleTiroir = creer("UIScale", { Parent = tiroir })

--------------------------------------------------------------------
-- Position du menu (V6.9.15, proposition 80) : la préférence « positionMenu » = { x = bord gauche, y = centre vertical },
-- en proportion de l'écran (elle suit donc un changement de taille d'écran). Sans préférence : à gauche, comme avant.
--------------------------------------------------------------------
local glisser = nil       -- (V6.9.15) glissement de l'en-tête en cours
local finAnimation = 0    -- (V6.9.15) pas de glissement pendant l'animation d'ouverture
local hauteurTiroir = 560 -- (V6.9.15) hauteur du tiroir avant l'échelle (tenue à jour par majTaille)
local function tailleEcran()
	local largeur, hauteur = 1920, 1080
	pcall(function()
		local ecran = camera.ViewportSize
		if ecran.X > 0 and ecran.Y > 0 then largeur, hauteur = ecran.X, ecran.Y end
	end)
	return largeur, hauteur
end
-- (V6.9.15) Garde le menu entier à l'écran : bord gauche et centre vertical en pixels
local function bornerMenu(gauche, centre)
	local largeurEcran, hauteurEcran = tailleEcran()
	local s = echelleTiroir.Scale
	local largeur, hauteur = LARGEUR * s, hauteurTiroir * s
	gauche = math.clamp(gauche, 0, math.max(0, largeurEcran - largeur))
	centre = math.clamp(centre, math.min(hauteur / 2, hauteurEcran / 2), math.max(hauteurEcran - hauteur / 2, hauteurEcran / 2))
	return math.floor(gauche + 0.5), math.floor(centre + 0.5)
end
-- (V6.9.15) Place choisie en pixels (bord gauche, centre vertical), déjà bornée ; nil sans préférence valable
local function placeChoisie()
	local p = UI.pref("positionMenu", nil)
	if type(p) ~= "table" or type(p.x) ~= "number" or type(p.y) ~= "number" or p.x ~= p.x or p.y ~= p.y then return nil end
	local largeurEcran, hauteurEcran = tailleEcran()
	return bornerMenu(math.clamp(p.x, 0, 1) * largeurEcran, math.clamp(p.y, 0, 1) * hauteurEcran)
end
local function positionOuverte()
	local gauche, centre = placeChoisie()
	if not gauche then return OUVERT end
	return UDim2.new(0, gauche, 0, centre)
end
-- (V6.9.15) Fermé : caché à gauche, à la hauteur choisie ; à une taille d'interface > 100 %, il ne dépasse plus de l'écran
local function positionFermee()
	local x = -math.ceil(LARGEUR * math.max(echelleTiroir.Scale, 1)) - 24
	local _, centre = placeChoisie()
	if not centre then return UDim2.new(0, x, POSITION_Y, 0) end
	return UDim2.new(0, x, 0, centre)
end
-- (V6.9.15) Bord gauche et centre vertical du menu ouvert, en pixels
local function pixelsOuverts()
	local gauche, centre = placeChoisie()
	if gauche then return gauche, centre end
	local _, hauteurEcran = tailleEcran()
	return 12, POSITION_Y * hauteurEcran
end

--------------------------------------------------------------------
-- En-tête : la plaque (titre, badge d'accès, ligne de données, bande de danger rouge pendant l'alerte)
--------------------------------------------------------------------
local HAUTEUR_ENTETE = 84
local plaque = UI.plaque(corps, "Navigation", UI.texteBadge("Menu", "ACCÈS NIV. 3"), UI.codeObjet(def),
	{ position = UDim2.fromOffset(16, 14), taille = UDim2.new(1, -32, 0, 60), largeurBande = LARGEUR, exterieur = exterieur })

--------------------------------------------------------------------
-- Contenu
--------------------------------------------------------------------
local contenu = creer("ScrollingFrame", { Name = "Contenu", Position = UDim2.fromOffset(0, HAUTEUR_ENTETE),
	Size = UDim2.new(1, 0, 1, -HAUTEUR_ENTETE), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 3, ScrollBarImageColor3 = C.cyan, CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, Parent = corps },
{ creer("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }), UI.pile(10) })

-- 1) Statut
local carteStatut = UI.carte(contenu, 1, 6)
local ligneEtat = creer("Frame", { Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, LayoutOrder = 1, Parent = carteStatut })
local voyant = creer("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0),
	Size = UDim2.fromOffset(12, 12), BackgroundColor3 = C.vert, Parent = ligneEtat }, { UI.coin(99, true) })
local halo = creer("UIStroke", { Color = C.vert, Thickness = 3, Transparency = 0.6, Parent = voyant })
local etatTexte = texte({ Text = "POSÉ", Font = UI.POLICE_GRAS, TextSize = 15, Position = UDim2.fromOffset(24, 0),
	Size = UDim2.new(1, -110, 1, 0), Parent = ligneEtat })
local modeTexte = texte({ Text = "NORMAL", Font = UI.POLICE_CODE, TextSize = 11, TextColor3 = C.texte2, TextXAlignment = Enum.TextXAlignment.Right,
	Position = UDim2.new(1, -86, 0, 0), Size = UDim2.fromOffset(86, 24), Parent = ligneEtat })
local positionTexte = texte({ Text = "", Font = UI.POLICE_CODE, TextSize = 12, TextColor3 = C.texte2, LayoutOrder = 2,
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
	silencieux = UI.badge(badges, "SILENCIEUX", UI.couleurMode("Silencieux"), 12),
	siege = UI.badge(badges, "SIÈGE", C.rouge, 13),
}
local zoneProgression = creer("Frame", { Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, LayoutOrder = 4,
	Visible = false, Parent = carteStatut })
local progressionTexte = texte({ Text = "", Font = UI.POLICE_CODE, TextSize = 12, TextColor3 = C.texte2,
	Size = UDim2.new(1, 0, 0, 14), Parent = zoneProgression })
local barreFond = creer("Frame", { Position = UDim2.fromOffset(0, 21), Size = UDim2.new(1, 0, 0, 7),
	BackgroundColor3 = C.gris, Parent = zoneProgression }, { UI.coin(99, true) })
local barre = creer("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.blanc, Parent = barreFond }, { UI.coin(99, true) })
creer("UIGradient", { Color = ColorSequence.new(C.ambre, C.cyan), Parent = barre })
-- Le souffle du moteur : des points qui s'allument au rythme de la (dé)matérialisation
local souffles = creer("Frame", { Size = UDim2.new(1, 0, 0, 10), BackgroundTransparency = 1, LayoutOrder = 5, Visible = false, Parent = carteStatut },
{ UI.pile(4, true) })
souffles:FindFirstChildOfClass("UIListLayout").HorizontalAlignment = Enum.HorizontalAlignment.Center
local pointsSouffle = {}
for i = 1, 12 do
	pointsSouffle[i] = creer("Frame", { Size = UDim2.fromOffset(16, 4), BackgroundColor3 = C.gris, LayoutOrder = i, Parent = souffles }, { UI.coin(99, true) })
end

-- 2) Destination : recherche, lieux / joueurs, tableau, fiche
local destination = creer("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1, LayoutOrder = 3, Parent = contenu }, { UI.pile(8) })
local recherche = UI.champRecherche(destination, { LayoutOrder = 1 })
local segments = creer("Frame", { Name = "LieuxJoueurs", Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, LayoutOrder = 2,
	Parent = destination }, { UI.pile(6, true) })
local segmentLieux = UI.puce(segments, "◆  Lieux", { Size = UDim2.new(0.5, -3, 1, 0), LayoutOrder = 1 })
local segmentJoueurs = UI.puce(segments, "●  Joueurs", { Size = UDim2.new(0.5, -3, 1, 0), LayoutOrder = 2 })
local tableau = UI.tableau(destination, {
	{ cle = "nom", titre = "Destination", largeur = UDim.new(1, -150) },
	{ cle = "dist", titre = "Dist.", largeur = UDim.new(0, 60), droite = true, donnees = true },
	{ cle = "statut", titre = "Statut", largeur = UDim.new(0, 90), donnees = true },
}, { nom = "Destinations", taille = UDim2.new(1, 0, 0, 20 + 44 * 4), ordre = 3 })
local liste = tableau.corps
local listeVide = texte({ Text = "", TextSize = 12, TextColor3 = C.texte2, TextXAlignment = Enum.TextXAlignment.Center,
	Size = UDim2.new(1, 0, 0, 40), TextWrapped = true, LayoutOrder = 999, Visible = false, Parent = liste })
-- Fiche de la destination choisie
local fiche = creer("Frame", { Name = "Fiche", Size = UDim2.new(1, 0, 0, 66), BackgroundColor3 = C.panneau, LayoutOrder = 4, Parent = destination },
{ UI.coin(8), UI.contour(C.ligne, 1, 0.6) })
UI.etiquette(fiche, "Destination", { Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -60, 0, 14) })
local ficheIcone = texte({ Text = "?", Font = UI.POLICE_GRAS, TextSize = 14, TextColor3 = C.ambre, TextXAlignment = Enum.TextXAlignment.Right,
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 6), Size = UDim2.fromOffset(30, 18), Parent = fiche })
local ficheNom = texte({ Text = "Aucune destination", Font = UI.POLICE_TITRE, TextSize = 14, TextColor3 = C.ambre, TextTruncate = Enum.TextTruncate.AtEnd,
	Position = UDim2.fromOffset(12, 24), Size = UDim2.new(1, -24, 0, 20), Parent = fiche })
local ficheInfo = texte({ Text = "Choisis un lieu ou un joueur.", Font = UI.POLICE_CODE, TextSize = 10, TextColor3 = C.texte2,
	TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(12, 46), Size = UDim2.new(1, -24, 0, 14), Parent = fiche })

-- 3) Protocoles : le mode dans des puces (un seul actif), l'atterrissage invisible dessous
UI.titreSection(contenu, "PROTOCOLES", 4)
local protocoles = creer("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
	LayoutOrder = 5, Parent = contenu }, { UI.pile(6) })
local modes = UI.selecteurModes(protocoles, {
	{ cle = "classique", nom = "Classique", couleur = C.cyan },
	{ cle = "express", nom = "Rapide", couleur = C.vert },
	{ cle = "urgence", nom = "Urgence", couleur = C.orange },
	{ cle = "sauvetage", nom = "Sauvetage", couleur = UI.couleurMode("Sauvetage") },
	{ cle = "silencieux", nom = "Silencieux", couleur = UI.couleurMode("Silencieux") },
}, 1, UDim2.new(1, 0, 0, 94), { colonnes = 3 })
local interrupteurInvisible = UI.interrupteur(protocoles, "Atterrissage invisible", "Il se pose déjà camouflé", C.cyan, 2)
-- État partagé avec la tablette (Classique, Urgence, Rapide, Sauvetage et Silencieux s'excluent)
Commandes.lierInterrupteurs({ classique = modes.classique, urgence = modes.urgence, express = modes.express, sauvetage = modes.sauvetage,
	silencieux = modes.silencieux, invisible = interrupteurInvisible })
UI.ligneAide(protocoles, "Zone REFUSE au départ ou à l'arrivée : urgence imposée ; zone VITESSE RÉDUITE : Classique ou Silencieux. Destination choisie avant DÉMAT : " .. tostring(Config.DureeVortexAuto or 10)
	.. " s de vortex puis REMAT automatique ; sinon, choisis dans le vortex et clique REMAT.", { LayoutOrder = 3 })

-- 4) Actions
local actions = creer("Frame", { Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1, LayoutOrder = 6,
	Parent = contenu }, { UI.pile(8, true) })
local boutonDemat = UI.boutonPrincipal(actions, "DÉMAT", "Décoller", 1, UDim2.new(0.5, -4, 1, 0), 10, "principal")
local boutonRemat = UI.boutonPrincipal(actions, "REMAT", "Atterrir", 2, UDim2.new(0.5, -4, 1, 0), 10, "secondaire")
-- Bouton vers la tablette avancée
local boutonTablette = UI.boutonCoupe(contenu, "Tablette  ·  Y", "secondaire", { Name = "BoutonTablette", Size = UDim2.new(1, 0, 0, 44), LayoutOrder = 7 })

-- 5) Systèmes : intégrité, bouclier, raccourcis
UI.titreSection(contenu, "SYSTÈMES", 8)
local carteSystemes = UI.carte(contenu, 9, 8)
local jaugeIntegrite = UI.jaugeSegments(carteSystemes, "Intégrité", { ordre = 1, nomObjet = "JaugeIntegrite", hauteurSegment = 12 })
local jaugeBouclier = UI.jaugeSegments(carteSystemes, "Bouclier", { ordre = 2, nomObjet = "JaugeBouclier", hauteurSegment = 12 })
local raccourcis = creer("Frame", { Size = UDim2.new(1, 0, 0, 196), BackgroundTransparency = 1, LayoutOrder = 3, Parent = carteSystemes },
{ creer("UIGridLayout", { CellSize = UDim2.new(0.5, -5, 0, 60), CellPadding = UDim2.fromOffset(10, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
local function tuile(nom, icone, ordre)
	local bouton = creer("TextButton", { BackgroundColor3 = C.fond, Text = "", LayoutOrder = ordre, Parent = raccourcis },
	{ UI.coin(10), UI.contour(C.ligne, 1, 0.4) })
	local lampe = creer("Frame", { Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(8, 8),
		BackgroundColor3 = C.gris, Parent = bouton }, { UI.coin(99, true) })
	local haloLampe = creer("UIStroke", { Color = C.gris, Thickness = 2, Transparency = 0.7, Parent = lampe })
	texte({ Text = icone, TextSize = 15, TextColor3 = C.texte2, TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, -10, 0, 18), Parent = bouton })
	texte({ Text = UI.majuscules(nom), Font = UI.POLICE_GRAS, TextSize = 12, Position = UDim2.fromOffset(10, 24),
		Size = UDim2.new(1, -20, 0, 16), Parent = bouton })
	local etat = texte({ Text = "", Font = UI.POLICE_CODE, TextSize = 10, TextColor3 = C.texte2, Position = UDim2.fromOffset(10, 40),
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
	siege = tuile("Siège", "▲", 5),        -- V6.9 : bouclier + verrou + alerte
}

-- Pied de page : la ligne d'aide (les touches)
UI.ligneAide(contenu, "↑ ↓ choisir  ·  Entrée DÉMAT  ·  T fermer", { Name = "AideTouches", TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 98 })
UI.ligneAide(contenu, "Y tablette  ·  E portes et console", { TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 99 })
UI.ligneAide(contenu, "Glisser l'en-tête : déplacer le menu", { Name = "AideDeplacer", TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 100 }) -- (V6.9.15)

-- Matière de l'écran : lignes de balayage (anciens thèmes : lignes fines et vignette), au-dessus du contenu, sous les voiles
local lignes = UI.lignesEcran(tiroir, 28, 0.93)
lignes.ZIndex = 10
UI.decor(UI.vignette(tiroir, 0.35), "horsConfinement").ZIndex = 11
-- Ligne de balayage à l'ouverture (une seule traversée, coupée par « Réduire les effets »)
local balayage = creer("Frame", { Name = "Balayage", Position = UDim2.new(0, 0, 0, -4), Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = C.blanc,
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

-- Notification (charte : panneau à coins coupés, badge TARDIS / ALERTE / REFUSÉ)
local notification = UI.notification({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 60), Size = UDim2.new(1, -24, 0, 0),
	ZIndex = 20, Parent = tiroir }, { tailleTexte = 13 })

-- Genre d'une notification : refus (échec), alerte (message d'alerte), sinon information
local function genreNotification(message, reussi)
	if not reussi then return "refus" end
	if string.find(string.lower(message), "alerte", 1, true) then return "alerte" end
	return "info"
end

local jeton = 0
local function notifier(message, reussi)
	if typeof(message) ~= "string" or string.sub(message, 1, 2) == "__" then return end
	jeton += 1
	local moi = jeton
	notification.regler(message, genreNotification(message, reussi))
	UI.son(reussi and "Notification" or "Alerte")
	notification.cadre.Visible = true
	notification.cadre.Position = UDim2.new(0.5, 0, 1, 60)
	animer(notification.cadre, 0.35, { Position = UDim2.new(0.5, 0, 1, -12) }, Enum.EasingStyle.Back)
	task.delay(4, function()
		if moi ~= jeton then return end
		animer(notification.cadre, 0.3, { Position = UDim2.new(0.5, 0, 1, 70) }).Completed:Wait()
		if moi == jeton then notification.cadre.Visible = false end
	end)
end

--------------------------------------------------------------------
-- État et mises à jour
--------------------------------------------------------------------
local ouvert = false
local mode = "lieux"
local choix = nil -- { type = "lieu", nom } ou { type = "joueur", id, nom } ou { type = "precedent", nom } ou { type = "base", nom } (V6.9.11)
local lignesChoix, ordreLignes = {}, {} -- [clé] = ligne du tableau (avec .choix) ; liste dans l'ordre affiché

local function cleDe(c)
	if not c then return nil end
	if c.type == "precedent" then return "precedent" end
	if c.type == "base" then return "base" end -- (V6.9.11)
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
	elseif c.type == "base" then
		-- (V6.9.11) position publiée par le serveur
		local cf = exterieur:GetAttribute("BaseCF")
		return typeof(cf) == "CFrame" and (cf.Position - origine).Magnitude or nil
	end
	return nil
end
local function texteDistance(c)
	local d = distanceDe(c)
	return d and string.format("%d", d) or "—"
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
	local texteDist = distance and string.format("%d studs", distance) or "—"
	if c.type == "lieu" then
		ficheIcone.Text = "◆"
		ficheNom.Text = UI.majuscules(c.nom)
		ficheInfo.Text = "LIEU  ·  " .. texteDist .. "  ·  " .. trajet
	elseif c.type == "precedent" then
		ficheIcone.Text = "◄"
		ficheNom.Text = UI.majuscules("Retour : " .. c.nom)
		ficheInfo.Text = "DERNIÈRE DESTINATION  ·  " .. trajet
	elseif c.type == "base" then
		-- (V6.9.11) point de base défini par les pilotes (tablette)
		ficheIcone.Text = "■"
		ficheNom.Text = UI.majuscules("Base : " .. c.nom)
		ficheInfo.Text = "POINT DE BASE  ·  " .. texteDist .. "  ·  " .. trajet
	else
		ficheIcone.Text = "●"
		ficheNom.Text = UI.majuscules(c.nom)
		ficheInfo.Text = "JOUEUR  ·  " .. texteDist .. "  ·  " .. trajet
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
	local couleurEtat, nomEtat = libelle[2], libelle[1]
	if not alimente then
		couleurEtat, nomEtat = C.gris, "HORS TENSION"
	elseif volLibre then
		couleurEtat, nomEtat = C.cyan, "VOL LIBRE"
	elseif alerte then
		couleurEtat = C.rouge
	end
	etatTexte.Text = nomEtat
	etatTexte.TextColor3 = couleurEtat
	animer(voyant, 0.3, { BackgroundColor3 = couleurEtat })
	halo.Color = couleurEtat
	-- Mode : celui du voyage en cours, sinon le protocole choisi
	local modeAffiche = etat ~= E.Pose and modeEnCours or Commandes.mode()
	modeTexte.Text = UI.majuscules(Config.libelleMode(modeAffiche, true))
	modeTexte.TextColor3 = UI.couleurMode(modeAffiche)
	positionTexte.Text = "●  " .. tostring(exterieur:GetAttribute("Position") or "?")
	-- Plaque : « OBJ. TARDIS-01 · POSÉ · CLASSIQUE » (l'alerte passe la bande au rouge, voir UI.plaque)
	plaque.majSousLigne(UI.codeObjet(def) .. "  ·  " .. (alerte and "ALERTE  ·  " or "") .. nomEtat .. "  ·  " .. Config.libelleMode(modeAffiche, true))

	B.camouflage.Visible = camoufle
	B.verrou.Visible = verrouille
	B.retreci.Visible = petit
	B.urgence.Visible = urgenceEnCours
	B.express.Visible = modeEnCours == "Express" and etat ~= E.Pose
	B.sauvetage.Visible = modeEnCours == "Sauvetage" and etat ~= E.Pose
	B.catastrophe.Visible = modeEnCours == "Catastrophe" and etat ~= E.Pose
	B.silencieux.Visible = modeEnCours == "Silencieux" and etat ~= E.Pose
	B.siege.Visible = exterieur:GetAttribute("Siege") == true
	B.horsTension.Visible = not alimente
	B.alerte.Visible = alerte
	B.bloque.Visible = bloque
	B.volLibre.Visible = volLibre
	badges.Visible = camoufle or verrouille or petit or urgenceEnCours or B.express.Visible or B.sauvetage.Visible or B.catastrophe.Visible
		or B.silencieux.Visible or B.siege.Visible
		or not alimente or alerte or bloque or volLibre

	-- Actions principales (couleurs : celles de la variante du bouton, voir UI.boutonPrincipal)
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
	-- Paradoxe : le bouton REMAT demande une confirmation (rouge)
	UI.confirmationBouton(boutonRemat, Commandes.paradoxeArme())

	-- Systèmes
	majTuile(T.camouflage, camoufle, camoufle and "ACTIVÉ" or "Inactif", C.cyan, pose and alimente)
	local seuil = Config.TailleOuverturePortes or 1
	local portesPossibles = pose and (porteOuverte or (not verrouille and echelle >= seuil - 0.001))
	majTuile(T.portes, porteOuverte, porteOuverte and "Ouvertes · fermer" or "Fermées · ouvrir", C.vert, portesPossibles)
	majTuile(T.verrou, verrouille, verrouille and "VERROUILLÉ" or "Ouvert", C.rouge, true)
	majTuile(T.taille, petit, petit and "PETIT · agrandir" or "Grand · rapetisser", C.ambre, pose and alimente and not porte)
	local siege = exterieur:GetAttribute("Siege") == true
	majTuile(T.siege, siege, siege and "EN SIÈGE · lever" or "Bouclier · verrou · alerte", C.rouge, siege or (pose and alimente))
	-- Intégrité (points de vie) et bouclier : jauges à segments, la valeur exacte à côté
	local integrite = exterieur:GetAttribute("PointsDeVie")
	if integrite then
		local couleurIntegrite = integrite <= 20 and C.rouge or (integrite <= 50 and C.ambre or C.vert)
		jaugeIntegrite.regler(integrite, couleurIntegrite, string.format("%d %%", integrite))
	end
	local bouclierActif = exterieur:GetAttribute("BouclierJoueurs") == true or exterieur:GetAttribute("BouclierBalles") == true
		or exterieur:GetAttribute("BouclierComplet") == true
	local energie = exterieur:GetAttribute("BouclierEnergie") or 100
	jaugeBouclier.regler(bouclierActif and energie or 0, bouclierActif and (energie <= 15 and C.rouge or C.cyan) or C.texte2,
		bouclierActif and string.format("%d %%", energie) or "INACTIF")

	voileAvarie.Visible = exterieur:GetAttribute("Avarie") == true and not voileDetruit.Visible
	voileDetruit.Visible = exterieur:GetAttribute("Detruit") == true

	-- Sélection : la ligne choisie passe en jaune
	local cleChoisie = cleDe(choix)
	for cle, ligne in lignesChoix do
		ligne.choisir(cle == cleChoisie)
	end
	majFiche()
end

-- Une ligne du tableau : nom, distance, statut (lieux : zone ACCORDÉ / REFUSÉ / SANS RAPIDE ; joueurs, retour)
local function ajouterElement(texteEl, c, ordre)
	local statut, couleurStatut, discret = "—", C.texte2, false
	if c.type == "lieu" then
		local code, libelle, couleur = UI.statutDestination(c.nom)
		statut, couleurStatut, discret = libelle, couleur, code == "REFUSE"
	elseif c.type == "precedent" then
		statut, couleurStatut = "RETOUR", C.cyan
	elseif c.type == "base" then
		statut, couleurStatut = "BASE", C.cyan -- (V6.9.11)
	else
		statut, couleurStatut = "JOUEUR", C.texte2
	end
	local ligne = tableau.ajouter({ nom = texteEl, dist = texteDistance(c), statut = statut },
		{ couleurs = { statut = couleurStatut, dist = discret and C.texte2 or nil }, discret = discret, ordre = ordre, nom = "Destination",
			action = function()
				choix = c
				majInterface()
			end })
	ligne.choix = c
	ligne.bouton:SetAttribute("Statut", statut)
	lignesChoix[cleDe(c)] = ligne
	table.insert(ordreLignes, ligne)
end

local function construireListe()
	tableau.vider()
	table.clear(lignesChoix)
	table.clear(ordreLignes)
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
		ajouterElement("Retour : " .. precedentNom, { type = "precedent", nom = precedentNom }, ordre)
	end
	-- (V6.9.11) Puis le point de base, s'il est défini (raccourci : le serveur sait où il est)
	local baseNom = exterieur:GetAttribute("BaseNom")
	if mode == "lieux" and baseNom and garde("Base " .. baseNom) then
		ordre += 1
		ajouterElement("Base : " .. baseNom, { type = "base", nom = baseNom }, ordre)
	end
	-- Les favoris (étoilés dans la tablette) d'abord, marqués d'un point
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
			ajouterElement((UI.estFavori(nom) and "● " or "") .. nom, { type = "lieu", nom = nom }, ordre)
		end
	end
	if mode == "joueurs" then
		local joueurs = Players:GetPlayers()
		table.sort(joueurs, function(a, b) return a.DisplayName:lower() < b.DisplayName:lower() end)
		for _, autre in joueurs do
			if garde(autre.DisplayName) or garde(autre.Name) then
				ordre += 1
				ajouterElement(autre.DisplayName .. (autre == joueur and "  (toi)" or ""),
					{ type = "joueur", id = autre.UserId, nom = autre.DisplayName }, ordre)
			end
		end
	end
	listeVide.Text = mode == "lieux" and "Aucun lieu." or "Aucun joueur."
	listeVide.Visible = ordre == 0

	if choix then
		local existe = (choix.type == "lieu" and noms[choix.nom]) or (choix.type == "joueur" and Players:GetPlayerByUserId(choix.id))
			or (choix.type == "precedent" and precedentNom) or (choix.type == "base" and baseNom)
		if not existe then choix = nil end
	end
	majInterface()
end

local function changerMode(nouveau)
	mode = nouveau
	segmentLieux.regler(nouveau == "lieux")
	segmentJoueurs.regler(nouveau == "joueurs")
	construireListe()
end
segmentLieux.bouton.Activated:Connect(function() changerMode("lieux") end)
segmentJoueurs.bouton.Activated:Connect(function() changerMode("joueurs") end)
recherche:GetPropertyChangedSignal("Text"):Connect(construireListe)

--------------------------------------------------------------------
-- Commandes
--------------------------------------------------------------------
-- Destination choisie, au format attendu par le serveur (nil si rien n'est choisi)
local function donneesDestination()
	return Commandes.donnees(choix)
end

local function lancerDemat()
	if boutonDemat:GetAttribute("Disponible") == false then
		if exterieur:GetAttribute("Porteur") == joueur.UserId and not choix then
			notifier("Choisis d'abord un lieu ou un joueur.", false)
		end
		return
	end
	Commandes.demat(choix)
end
local function lancerRemat()
	-- Pendant le compte à rebours de la rematérialisation automatique, un appui la lance tout de suite
	if not Commandes.secondesAutoRemat() and boutonRemat:GetAttribute("Disponible") == false then
		if (exterieur:GetAttribute("Etat") or E.Pose) == E.Vol and not choix then
			notifier("Choisis d'abord un lieu ou un joueur.", false)
		end
		return
	end
	Commandes.remat(choix)
end

-- Clavier du menu ouvert (V6.9.10.6, ligne d'aide) : ↑ ↓ choisissent une destination du tableau, Entrée lance DÉMAT
-- (REMAT dans le vortex). Branché seulement pendant que le menu est ouvert ; les touches ne font alors pas marcher le personnage.
local ACTION_CLAVIER = "TardisMenuNavigation"
local function choisirVoisin(sens)
	if #ordreLignes == 0 then return end
	local index = 0
	for i, ligne in ordreLignes do
		if ligne.choix and cleDe(ligne.choix) == cleDe(choix) then index = i end
	end
	if index == 0 then index = sens > 0 and 1 or #ordreLignes else index = math.clamp(index + sens, 1, #ordreLignes) end
	choix = ordreLignes[index].choix
	majInterface()
end
local function actionClavier(_, etatEntree, input)
	if etatEntree ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
	if not ouvert then return Enum.ContextActionResult.Pass end
	local touche = input.KeyCode
	if touche == Enum.KeyCode.Up then
		choisirVoisin(-1)
	elseif touche == Enum.KeyCode.Down then
		choisirVoisin(1)
	elseif (exterieur:GetAttribute("Etat") or E.Pose) == E.Vol then
		lancerRemat()
	else
		lancerDemat()
	end
	return Enum.ContextActionResult.Sink
end
local function brancherClavier(actif)
	if not ContextActionService then return end
	pcall(function()
		if actif then
			ContextActionService:BindActionAtPriority(ACTION_CLAVIER, actionClavier, false, Enum.ContextActionPriority.High.Value,
				Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Return, Enum.KeyCode.KeypadEnter)
		else
			ContextActionService:UnbindAction(ACTION_CLAVIER)
		end
	end)
end

local function basculerMenu()
	ouvert = not ouvert
	glisser = nil -- (V6.9.15)
	-- (V6.9.15, proposition 81) « Ouverture des menus sans animation » : le tiroir est posé d'un coup, sans balayage
	local instantane = UI.ouvertureInstantanee()
	if instantane then
		tiroir.Position = ouvert and positionOuverte() or positionFermee()
		finAnimation = 0
	else
		animer(tiroir, 0.45, { Position = ouvert and positionOuverte() or positionFermee() }, ouvert and Enum.EasingStyle.Quint or Enum.EasingStyle.Quad,
			ouvert and Enum.EasingDirection.Out or Enum.EasingDirection.In) -- (V6.9.15 : à la position choisie)
		finAnimation = os.clock() + 0.45
	end
	brancherClavier(ouvert)
	if ouvert then
		-- Allumage : la ligne de balayage traverse le tiroir (sauf « Réduire les effets », et V6.9.15 : sans animation)
		balayage.Visible = not UI.effetsReduits() and not instantane
		balayage.Position = UDim2.new(0, 0, 0, -4)
		if not instantane then
			animer(balayage, 0.7, { Position = UDim2.new(0, 0, 1, 4) }, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0.1)
		end
		UI.son("Notification")
		majInterface()
	else
		recherche:ReleaseFocus()
	end
end

-- Glisser l'en-tête (V6.9.15, proposition 80) : la plaque du menu ouvert se prend à la souris ou au doigt ; au-delà de
-- 6 px, le menu suit (sans jamais sortir de l'écran) ; au lâcher, la position est gardée dans les préférences.
-- Un simple clic sur l'en-tête ne déplace rien.
plaque.cadre.Active = true
plaque.cadre.InputBegan:Connect(function(input)
	if not ouvert or os.clock() < finAnimation then return end
	local tactile = input.UserInputType == Enum.UserInputType.Touch
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and not tactile then return end
	local gauche, centre = pixelsOuverts() -- (le menu ouvert, hors animation, est toujours à sa place)
	glisser = { x = input.Position.X, y = input.Position.Y, tactile = tactile, entree = input, bouge = false,
		gauche = gauche, centre = centre, actuelGauche = gauche, actuelCentre = centre }
end)
UserInputService.InputChanged:Connect(function(input)
	local g = glisser
	if not g or not ouvert then return end
	if g.tactile then
		if input ~= g.entree and input.UserInputType ~= Enum.UserInputType.Touch then return end
	elseif input.UserInputType ~= Enum.UserInputType.MouseMovement then
		return
	end
	local dx, dy = input.Position.X - g.x, input.Position.Y - g.y
	if not g.bouge and math.abs(dx) + math.abs(dy) < 6 then return end
	g.bouge = true
	local gauche, centre = bornerMenu(g.gauche + dx, g.centre + dy)
	g.actuelGauche, g.actuelCentre = gauche, centre
	tiroir.Position = UDim2.new(0, gauche, 0, centre)
end)
UserInputService.InputEnded:Connect(function(input)
	local g = glisser
	if not g then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
	glisser = nil
	if not g.bouge or not ouvert then return end
	local largeurEcran, hauteurEcran = tailleEcran()
	local gauche, centre = g.actuelGauche, g.actuelCentre
	UI.setPref("positionMenu", { x = math.floor(gauche / largeurEcran * 1000 + 0.5) / 1000, y = math.floor(centre / hauteurEcran * 1000 + 0.5) / 1000 })
end)

-- La tablette (script TardisTablette) écoute cet attribut local du joueur
boutonTablette.Activated:Connect(function()
	joueur:SetAttribute("TardisTablette", true)
end)
joueur:GetAttributeChangedSignal("TardisTablette"):Connect(function()
	if joueur:GetAttribute("TardisTablette") and ouvert then
		basculerMenu()
	end
end)

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

boutonDemat.Activated:Connect(lancerDemat)
boutonRemat.Activated:Connect(lancerRemat)

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
T.siege.bouton.Activated:Connect(function()
	if T.siege.bouton:GetAttribute("Disponible") == false then return end
	if exterieur:GetAttribute("Siege") then remote:FireServer("Siege") return end
	UI.confirmer(T.siege.etat, function() remote:FireServer("Siege") end)
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
-- Boutons tactiles (V6.8.1, modification 8) : sur un appareil sans clavier, deux boutons au bord gauche ouvrent
-- le menu rapide (T) et la tablette (Y). Rien ne change sur ordinateur. (V6.9.10.6 : coins coupés, 52 px.)
--------------------------------------------------------------------
if Config.BoutonsTactiles ~= false and UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
	local barreTactile = creer("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.38, 0), Size = UDim2.fromOffset(52, 0),
		AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ZIndex = 30, Parent = gui }, { UI.pile(10) })
	local function boutonTactile(lettre, legende, ordre, action)
		local b = creer("TextButton", { Name = "BoutonTactile", Size = UDim2.fromOffset(52, 52), BackgroundColor3 = C.fond, BackgroundTransparency = 0.15, Text = "",
			LayoutOrder = ordre, ZIndex = 30, Parent = barreTactile }, { UI.coin(99), UI.contour(C.cyan, 1.5, 0.3) })
		UI.decouper(b, 10, { contour = C.cyan })
		texte({ Text = lettre, Font = UI.POLICE_TITRE, TextSize = 18, TextColor3 = C.cyan, TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 22), ZIndex = 31, Parent = b })
		texte({ Text = legende, Font = UI.POLICE_CODE, TextSize = 9, TextColor3 = C.texte2, TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, 31), Size = UDim2.new(1, 0, 0, 12), ZIndex = 31, Parent = b })
		b:SetAttribute("CouleurBase", C.fond)
		UI.rendreVivant(b)
		b.Activated:Connect(action)
		return b
	end
	boutonTactile("T", "menu", 1, basculerMenu)
	boutonTactile("Y", "tablette", 2, function() joueur:SetAttribute("TardisTablette", not joueur:GetAttribute("TardisTablette")) end)
	-- Le menu ouvert recouvre le bord gauche : les boutons se décalent à sa droite
	-- (V6.9.15 : seulement si le menu est resté près du bord gauche ; déplacé ailleurs, ils restent au bord)
	RunService.Heartbeat:Connect(function()
		local cible = UDim2.new(0, 8, 0.38, 0)
		if ouvert then
			local gauche = (glisser and glisser.bouge) and glisser.actuelGauche or (pixelsOuverts())
			if gauche < 70 then cible = UDim2.new(0, gauche + LARGEUR * echelleTiroir.Scale + 10, 0.38, 0) end
		end
		if barreTactile.Position ~= cible then barreTactile.Position = barreTactile.Position:Lerp(cible, 0.25) end
	end)
end

--------------------------------------------------------------------
-- Animations (voyage et paradoxe seulement : le décor de la charte est posé une fois, sans boucle)
--------------------------------------------------------------------
local derniereSecondeAuto = nil
local prochaineMajLente = 0
local confirmationAffichee = false
RunService.RenderStepped:Connect(function()
	if not gui.Enabled then return end
	local etat = exterieur:GetAttribute("Etat") or E.Pose
	local enMouvement = etat ~= E.Pose
	local t = os.clock()
	if not ouvert then return end
	-- Deux fois par seconde : la fiche, les distances du tableau et le mode (il peut changer depuis la tablette)
	if t >= prochaineMajLente then
		prochaineMajLente = t + 0.5
		majFiche()
		for _, ligne in ordreLignes do
			if ligne.choix then ligne.regler("dist", texteDistance(ligne.choix)) end
		end
		local modeAffiche = etat ~= E.Pose and Config.modeDe(exterieur) or Commandes.mode()
		modeTexte.Text = UI.majuscules(Config.libelleMode(modeAffiche, true))
		modeTexte.TextColor3 = UI.couleurMode(modeAffiche)
	end
	-- Confirmation d'un paradoxe : le bouton rouge clignote, puis revient à la normale quand la fenêtre se ferme
	local arme = Commandes.paradoxeArme()
	if arme ~= confirmationAffichee then
		confirmationAffichee = arme
		majInterface()
	end
	if arme then boutonRemat.Lueur.Transparency = 0.2 + 0.5 * (0.5 + 0.5 * math.sin(t * 8)) end

	-- Lueur des boutons disponibles (fixe avec « Réduire les effets »)
	local reduit = UI.effetsReduits()
	local lueur = reduit and 0.35 or (0.2 + 0.5 * (0.5 + 0.5 * math.sin(t * 3)))
	for _, bouton in { boutonDemat, boutonRemat } do
		if not (bouton == boutonRemat and arme) then
			bouton.Lueur.Transparency = bouton:GetAttribute("Disponible") and lueur or 0.7
		end
	end

	local ecoule = workspace:GetServerTimeNow() - (exterieur:GetAttribute("DebutEtat") or 0)
	local modeEnCours = Config.modeDe(exterieur)
	local souffle = Config.Souffle(etat, ecoule, modeEnCours)
	-- Le voyant respire avec le moteur en voyage, bat lentement posé, vite en alerte
	local rythme = exterieur:GetAttribute("Alerte") and 6 or 2
	if reduit then
		halo.Transparency, halo.Thickness = 0.5, 3
	else
		halo.Transparency = enMouvement and (0.75 - 0.55 * souffle) or (0.5 + 0.4 * (0.5 + 0.5 * math.sin(t * rythme)))
		halo.Thickness = enMouvement and (2 + 3 * souffle) or 3
	end

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
		-- Compte à rebours de la rematérialisation automatique : le bouton REMAT se remplit
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
	hauteurTiroir = math.clamp(ecran.Y * HAUTEUR_ECRAN / echelle, 380, 760) -- (V6.9.15 : gardée pour bornerMenu)
	tiroir.Size = UDim2.fromOffset(LARGEUR, hauteurTiroir)
	-- (V6.9.15) le menu reste entier à l'écran à sa nouvelle taille (ouvert : à sa place ; fermé : bien caché)
	if not glisser then tiroir.Position = ouvert and positionOuverte() or positionFermee() end
end
camera:GetPropertyChangedSignal("ViewportSize"):Connect(majTaille)
UI.prefsChangees.Event:Connect(function(cle)
	if cle == "taille" then majTaille() end
	if cle == "positionMenu" and not glisser then tiroir.Position = ouvert and positionOuverte() or positionFermee() end -- (V6.9.15)
	if cle == "theme" then construireListe() end -- les couleurs posées à la volée (statuts, état) suivent le nouveau thème
end)
majTaille()

--------------------------------------------------------------------
-- Mises à jour automatiques
--------------------------------------------------------------------
for _, attribut in { "Siege", "Etat", "Camouflage", "Position", "PortesVerrouillees", "Retreci", "Porteur", "Mode", "PorteOuverte",
	"Echelle", "Alimentation", "Alerte", "DemarrageBloque", "VolLibre", "BouclierJoueurs", "BouclierBalles", "MinuterieFin", "Intrusion", "Theme", "Projecteur", "Couleur", "Enseigne", "Detruit", "AutoDestructionDebut", "StyleInterieur", "StyleConsole", "CouleurMurs", "Jukebox", "BouclierComplet", "BouclierEnergie", "PointsDeVie", "Avarie", "Stabilisateur", "Decoration", "Reflets" } do
	exterieur:GetAttributeChangedSignal(attribut):Connect(majInterface)
end
exterieur:GetAttributeChangedSignal("ListeDestinations"):Connect(construireListe)
exterieur:GetAttributeChangedSignal("PrecedentNom"):Connect(construireListe)
exterieur:GetAttributeChangedSignal("BaseNom"):Connect(construireListe) -- (V6.9.11) point de base
Players.PlayerAdded:Connect(construireListe)
Players.PlayerRemoving:Connect(function() task.defer(construireListe) end)
-- Les protocoles changent (ici ou dans la tablette) : le mode affiché et le temps de trajet suivent
for _, inter in { modes.classique, modes.urgence, modes.express, modes.sauvetage, modes.silencieux, interrupteurInvisible } do
	local ancien = inter.surChangement
	inter.surChangement = function(actif)
		if ancien then ancien(actif) end
		majInterface()
	end
end
UI.prefsChangees.Event:Connect(function(cle) if cle == "favoris" or cle == "modeVoyage" then construireListe() end end)

local function majAcces()
	gui.Enabled = joueur:GetAttribute("TardisPilote_" .. def.Nom) == true
	if not gui.Enabled and ouvert then basculerMenu() end
end
joueur:GetAttributeChangedSignal("TardisPilote_" .. def.Nom):Connect(majAcces)
majAcces()
changerMode("lieux")
