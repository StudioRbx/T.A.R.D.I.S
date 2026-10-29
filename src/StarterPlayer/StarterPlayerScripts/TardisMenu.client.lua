-- StarterPlayer > StarterPlayerScripts > TardisMenu (LocalScript)
-- Menu CLASSIQUE du TARDIS : simple et rapide, dans un tiroir sur le bord gauche de l'écran.
--   État + progression · lieux et joueurs · urgence / atterrissage invisible
--   Dématérialiser / Matérialiser · Camouflage · Portes (ouvrir / fermer) · Taille (grand / petit)
--   Bouton "Tablette" : ouvre la tablette avancée (script TardisTablette).
-- Visible seulement pour les pilotes autorisés. Toutes les commandes sont revérifiées par le serveur.
-- Touche T : ouvrir / fermer.

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
local LARGEUR = 330
local POSITION_Y = 0.55          -- centre vertical du menu (0 = haut de l'écran, 1 = bas)
local HAUTEUR_ECRAN = 0.8        -- hauteur max du menu en proportion de l'écran
local TOUCHE = Enum.KeyCode.T    -- ouvrir / fermer
local TAILLE_PETITE = Config.TaillePetite or Config.TailleMin or 0.25

--------------------------------------------------------------------
-- Tiroir (ouvert et fermé avec la touche T : il n'y a plus d'onglet à l'écran depuis la V6.6.5)
--------------------------------------------------------------------
local gui = creer("ScreenGui", { Name = "TardisMenu", ResetOnSpawn = false, Enabled = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = joueur:WaitForChild("PlayerGui") })

local OUVERT = UDim2.new(0, 12, POSITION_Y, 0)
local FERME = UDim2.new(0, -LARGEUR - 20, POSITION_Y, 0)

local tiroir = creer("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = FERME, Size = UDim2.fromOffset(LARGEUR, 540),
	BackgroundColor3 = C.fond, Parent = gui }, { UI.coin(16), UI.contour(C.ambre, 1.5, 0.5) })
local echelleTiroir = creer("UIScale", { Parent = tiroir })
creer("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.blanc, Color3.fromRGB(150, 160, 190)), Parent = tiroir })

--------------------------------------------------------------------
-- En-tête
--------------------------------------------------------------------
local HAUTEUR_ENTETE = 74
local entete = creer("Frame", { Size = UDim2.new(1, 0, 0, HAUTEUR_ENTETE), BackgroundColor3 = C.blanc, Parent = tiroir },
{ UI.coin(16) })
local COULEURS_VORTEX = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(8, 22, 60)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(24, 70, 150)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(6, 18, 50)),
})
local vortex = creer("UIGradient", { Color = UI.degradeEntete(), Parent = entete })
local vortexBas = creer("UIGradient", { Color = UI.degradeEntete() })
creer("Frame", { Position = UDim2.new(0, 0, 1, -16), Size = UDim2.new(1, 0, 0, 16), BackgroundColor3 = C.blanc,
	BorderSizePixel = 0, Parent = entete }, { vortexBas })
UI.prefsChangees.Event:Connect(function(cle)
	if cle == "theme" then
		vortex.Color = UI.degradeEntete()
		vortexBas.Color = UI.degradeEntete()
	end
end)
creer("Frame", { Position = UDim2.new(0, 0, 0, HAUTEUR_ENTETE), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = C.ambre,
	BackgroundTransparency = 0.35, BorderSizePixel = 0, Parent = tiroir })

local embleme = creer("Frame", { Position = UDim2.fromOffset(14, 13), Size = UDim2.fromOffset(48, 48),
	BackgroundTransparency = 1, Parent = entete })
local anneaux = {}
for i, info in { { 48, C.ambre, 1.5 }, { 34, C.cyan, 1.5 }, { 20, C.ambre, 1 } } do
	local anneau = creer("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(info[1], info[1]), BackgroundTransparency = 1, Parent = embleme },
	{ UI.coin(99), UI.contour(info[2], info[3], 0.15) })
	for k = 0, i do
		local angle = (k / (i + 1)) * math.pi * 2
		creer("Frame", { AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5 + math.cos(angle) * 0.5, 0, 0.5 + math.sin(angle) * 0.5, 0),
			Size = UDim2.fromOffset(4, 4), BackgroundColor3 = info[2], Parent = anneau }, { UI.coin(99) })
	end
	table.insert(anneaux, anneau)
end
creer("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(8, 8),
	BackgroundColor3 = C.ambre, Parent = embleme }, { UI.coin(99) })

texte({ Text = "T.A.R.D.I.S.", Font = UI.POLICE_TITRE, TextSize = 18, Position = UDim2.fromOffset(74, 12),
	Size = UDim2.new(1, -160, 0, 22), Parent = entete })
local pastille = creer("Frame", { Position = UDim2.fromOffset(74, 40), Size = UDim2.fromOffset(0, 20),
	AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = C.fond, BackgroundTransparency = 0.35, Parent = entete },
{ UI.coin(99), creer("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 10) }), UI.pile(6, true) })
pastille:FindFirstChildOfClass("UIListLayout").VerticalAlignment = Enum.VerticalAlignment.Center
local contourPastille = UI.contour(C.vert, 1, 0.4)
contourPastille.Parent = pastille
local pointPastille = creer("Frame", { Size = UDim2.fromOffset(7, 7), BackgroundColor3 = C.vert, LayoutOrder = 1,
	Parent = pastille }, { UI.coin(99) })
local textePastille = texte({ Text = "Posé", Font = UI.POLICE_GRAS, TextSize = 11, Size = UDim2.new(0, 0, 1, 0),
	AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2, Parent = pastille })

-- Bouton vers la tablette avancée
local boutonTablette = creer("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
	Size = UDim2.fromOffset(78, 34), BackgroundColor3 = C.bleu, Text = "", Parent = entete },
{ UI.coin(9), UI.contour(C.ambre, 1, 0.3) })
texte({ Text = "■  Tablette", Font = UI.POLICE_GRAS, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center,
	Size = UDim2.fromScale(1, 1), Parent = boutonTablette })
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

-- Statut
local carteStatut = UI.carte(contenu, 1, 6)
local ligneEtat = creer("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, LayoutOrder = 1, Parent = carteStatut })
local voyant = creer("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 0),
	Size = UDim2.fromOffset(11, 11), BackgroundColor3 = C.vert, Parent = ligneEtat }, { UI.coin(99) })
local halo = creer("UIStroke", { Color = C.vert, Thickness = 3, Transparency = 0.6, Parent = voyant })
local etatTexte = texte({ Text = "POSÉ", Font = UI.POLICE_GRAS, TextSize = 15, Position = UDim2.fromOffset(22, 0),
	Size = UDim2.new(1, -22, 1, 0), Parent = ligneEtat })
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
	express = UI.badge(badges, "EXPRESS", C.vert, 9),
}
local zoneProgression = creer("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, LayoutOrder = 4,
	Visible = false, Parent = carteStatut })
local progressionTexte = texte({ Text = "", Font = UI.POLICE_CODE, TextSize = 12, TextColor3 = C.texte2,
	Size = UDim2.new(1, 0, 0, 14), Parent = zoneProgression })
local barreFond = creer("Frame", { Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 6),
	BackgroundColor3 = C.gris, Parent = zoneProgression }, { UI.coin(99) })
local barre = creer("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.blanc, Parent = barreFond }, { UI.coin(99) })
creer("UIGradient", { Color = ColorSequence.new(C.ambre, C.cyan), Parent = barre })

-- Destination
UI.titreSection(contenu, "DESTINATION", 2)
local destination = creer("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1, LayoutOrder = 3, Parent = contenu }, { UI.pile(8) })
local recherche = creer("TextBox", { Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = C.panneau, Text = "",
	PlaceholderText = "Rechercher…", PlaceholderColor3 = C.texte2, TextColor3 = C.texte, Font = UI.POLICE, TextSize = 13,
	ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1, Parent = destination },
{ UI.coin(8), UI.contour(C.bleu, 1, 0.3), creer("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }) })
local segments = creer("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = C.panneau, LayoutOrder = 2,
	Parent = destination }, { UI.coin(8) })
local curseur = creer("Frame", { Size = UDim2.new(0.5, -4, 1, -6), Position = UDim2.fromOffset(3, 3),
	BackgroundColor3 = C.bleu, Parent = segments }, { UI.coin(6), UI.contour(C.ambre, 1, 0.5) })
local segmentLieux = creer("TextButton", { Text = "Lieux", Font = UI.POLICE_GRAS, TextSize = 12, TextColor3 = C.texte,
	BackgroundTransparency = 1, Size = UDim2.fromScale(0.5, 1), Parent = segments })
local segmentJoueurs = creer("TextButton", { Text = "Joueurs", Font = UI.POLICE_GRAS, TextSize = 12, TextColor3 = C.texte2,
	BackgroundTransparency = 1, Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(0.5, 1), Parent = segments })
local liste = creer("ScrollingFrame", { Size = UDim2.new(1, 0, 0, 150), BackgroundColor3 = Color3.fromRGB(4, 10, 24),
	BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = C.ambre, CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Parent = destination },
{ UI.coin(8), UI.contour(C.bleu, 1, 0.5), UI.marges(6), UI.pile(4) })
local listeVide = texte({ Text = "", TextSize = 12, TextColor3 = C.texte2, TextXAlignment = Enum.TextXAlignment.Center,
	Size = UDim2.new(1, 0, 0, 40), TextWrapped = true, LayoutOrder = 999, Visible = false, Parent = liste })

-- Protocoles
UI.titreSection(contenu, "PROTOCOLES", 4)
local protocoles = UI.carte(contenu, 5, 6)
local interrupteurUrgence = UI.interrupteur(protocoles, "Urgence", "Sons d'urgence et vol instable", C.orange, 1)
local interrupteurExpress = UI.interrupteur(protocoles, "Express", "Démat et remat en 2 secondes", C.vert, 2)
local interrupteurInvisible = UI.interrupteur(protocoles, "Atterrissage invisible", "Il se pose déjà camouflé", C.cyan, 3)
-- État partagé avec la tablette (Urgence et Express s'excluent)
Commandes.lierInterrupteurs({ urgence = interrupteurUrgence, express = interrupteurExpress, invisible = interrupteurInvisible })

-- Actions
local actions = creer("Frame", { Size = UDim2.new(1, 0, 0, 54), BackgroundTransparency = 1, LayoutOrder = 6,
	Parent = contenu }, { UI.pile(10, true) })
local function grosBouton(nom, sousTitre, ordre)
	local bouton = creer("TextButton", { Size = UDim2.new(0.5, -5, 1, 0), BackgroundColor3 = C.bleu, Text = "",
		LayoutOrder = ordre, Parent = actions }, { UI.coin(10) })
	local lueur = UI.contour(C.ambre, 1.5, 0.5)
	lueur.Name = "Lueur"
	lueur.Parent = bouton
	texte({ Text = nom, Font = UI.POLICE_GRAS, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 18), Parent = bouton })
	texte({ Name = "SousTitre", Text = sousTitre, TextSize = 11, TextColor3 = C.texte2, TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 14), Parent = bouton })
	creer("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.blanc, Color3.fromRGB(170, 180, 205)), Parent = bouton })
	UI.rendreVivant(bouton)
	return bouton
end
local boutonDemat = grosBouton("DÉMATÉRIALISER", "Décoller", 1)
local boutonRemat = grosBouton("MATÉRIALISER", "Atterrir", 2)

-- Raccourcis
-- Intégrité du TARDIS (points de vie)
local cadreIntegrite = creer("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, LayoutOrder = 6, Parent = contenu })
local texteIntegrite = texte({ Text = "Intégrité  100 %", Font = UI.POLICE_GRAS, TextSize = 11, TextColor3 = C.texte2, Size = UDim2.new(1, 0, 0, 14), Parent = cadreIntegrite })
local fondIntegrite = creer("Frame", { Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 8), BackgroundColor3 = C.gris, Parent = cadreIntegrite }, { UI.coin(99) })
local barreIntegrite = creer("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.vert, Parent = fondIntegrite }, { UI.coin(99) })
UI.titreSection(contenu, "RACCOURCIS", 7)
local raccourcis = creer("Frame", { Size = UDim2.new(1, 0, 0, 70), BackgroundTransparency = 1, LayoutOrder = 8,
	Parent = contenu }, { UI.pile(8, true) })
local function tuile(nom, icone, ordre, parent, largeur)
	local bouton = creer("TextButton", { Size = UDim2.new(largeur or 1 / 3, -6, 1, 0), BackgroundColor3 = C.panneau, Text = "",
		LayoutOrder = ordre, Parent = parent or raccourcis }, { UI.coin(10), UI.contour(C.bleu, 1, 0.4) })
	local lampe = creer("Frame", { Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(8, 8),
		BackgroundColor3 = C.gris, Parent = bouton }, { UI.coin(99) })
	texte({ Text = icone, TextSize = 15, TextColor3 = C.texte2, TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, -10, 0, 18), Parent = bouton })
	texte({ Text = nom, Font = UI.POLICE_GRAS, TextSize = 12, Position = UDim2.fromOffset(10, 26),
		Size = UDim2.new(1, -20, 0, 16), Parent = bouton })
	local etat = texte({ Text = "", TextSize = 10, TextColor3 = C.texte2, Position = UDim2.fromOffset(10, 44),
		Size = UDim2.new(1, -20, 0, 14), Parent = bouton })
	UI.rendreVivant(bouton)
	return { bouton = bouton, lampe = lampe, etat = etat }
end
local T = {
	camouflage = tuile("Camouflage", "◐", 1),
	portes = tuile("Portes", "■", 2),
	taille = tuile("Taille", "◢", 3),
}

creer("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, LayoutOrder = 99, Parent = contenu })

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
local choix = nil -- { type = "lieu", nom } ou { type = "joueur", id, nom }
local elementsListe, boutonsChoix = {}, {}

local function cleDe(c)
	if not c then return nil end
	if c.type == "precedent" then return "precedent" end
	return c.type == "lieu" and ("lieu:" .. c.nom) or ("joueur:" .. c.id)
end

local function majTuile(t, actif, texteEtat, couleur, disponible)
	UI.setDisponible(t.bouton, disponible, C.panneau)
	animer(t.lampe, 0.2, { BackgroundColor3 = actif and couleur or C.gris })
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
	local mode = Config.modeDe(exterieur)
	local urgenceEnCours = mode == "Urgence" and etat ~= E.Pose
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
	animer(voyant, 0.3, { BackgroundColor3 = couleurEtat })
	halo.Color = couleurEtat
	positionTexte.Text = "●  " .. tostring(exterieur:GetAttribute("Position") or "?")
	textePastille.Text = (alerte and "Alerte · " or "") .. nomCourt
	animer(pointPastille, 0.3, { BackgroundColor3 = couleurEtat })
	contourPastille.Color = couleurEtat

	B.camouflage.Visible = camoufle
	B.verrou.Visible = verrouille
	B.retreci.Visible = petit
	B.urgence.Visible = urgenceEnCours
	B.express.Visible = mode == "Express" and etat ~= E.Pose
	B.horsTension.Visible = not alimente
	B.alerte.Visible = alerte
	B.bloque.Visible = bloque
	B.volLibre.Visible = volLibre
	badges.Visible = camoufle or verrouille or petit or urgenceEnCours or B.express.Visible or not alimente or alerte or bloque or volLibre

	-- Actions principales
	local poche = exterieur:GetAttribute("Porteur") == joueur.UserId -- je porte le TARDIS : téléportation de poche
	local dematOk = pose and not porte and alimente and not bloque
	if poche then dematOk = choix ~= nil and alimente and not bloque end
	local rematOk = etat == E.Vol and (choix ~= nil or petit) and alimente
	boutonDemat.SousTitre.Text = poche and (choix and "Téléportation de poche" or "Choisis une destination") or "Décoller"
	UI.setDisponible(boutonDemat, dematOk, C.bleu)
	UI.setDisponible(boutonRemat, rematOk, C.bleu)
	boutonRemat.SousTitre.Text = petit and "Sur place (petit)" or "Atterrir"
	boutonDemat.Lueur.Color = dematOk and C.ambre or C.gris
	boutonRemat.Lueur.Color = rematOk and C.ambre or C.gris

	-- Raccourcis
	majTuile(T.camouflage, camoufle, camoufle and "ACTIVÉ" or "Inactif", C.cyan, pose and alimente)
	local seuil = Config.TailleOuverturePortes or 1
	local portesPossibles = pose and (porteOuverte or (not verrouille and echelle >= seuil - 0.001))
	majTuile(T.portes, porteOuverte, porteOuverte and "Ouvertes · fermer" or "Fermées · ouvrir", C.vert, portesPossibles)
	majTuile(T.taille, petit, petit and "PETIT · agrandir" or "Grand · rapetisser", C.ambre, pose and alimente and not porte)
	-- Intégrité (points de vie)
	local integrite = exterieur:GetAttribute("PointsDeVie")
	if integrite then
		barreIntegrite.Size = UDim2.fromScale(integrite / 100, 1)
		barreIntegrite.BackgroundColor3 = integrite <= 20 and C.rouge or (integrite <= 50 and C.ambre or C.vert)
		texteIntegrite.Text = string.format("Intégrité  %d %%", integrite)
	end
	voileAvarie.Visible = exterieur:GetAttribute("Avarie") == true and not voileDetruit.Visible

	voileDetruit.Visible = exterieur:GetAttribute("Detruit") == true

	-- Sélection
	local cleChoisie = cleDe(choix)
	for cle, bouton in boutonsChoix do
		local choisi = cle == cleChoisie
		UI.colorer(bouton, choisi and C.panneauClair or C.panneau)
		bouton.Barre.Visible = choisi
	end
end

local function ajouterElement(texteEl, sousTexte, c, ordre)
	local bouton = creer("TextButton", { Size = UDim2.new(1, 0, 0, sousTexte and 38 or 30), BackgroundColor3 = C.panneau,
		Text = "", LayoutOrder = ordre, Parent = liste }, { UI.coin(6) })
	creer("Frame", { Name = "Barre", Size = UDim2.new(0, 3, 1, -10), Position = UDim2.fromOffset(4, 5),
		BackgroundColor3 = C.ambre, Visible = false, Parent = bouton }, { UI.coin(99) })
	texte({ Text = texteEl, Font = UI.POLICE_GRAS, TextSize = 13, Position = UDim2.fromOffset(14, sousTexte and 3 or 6),
		Size = UDim2.new(1, -20, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd, Parent = bouton })
	if sousTexte then
		texte({ Text = sousTexte, TextSize = 11, TextColor3 = C.texte2, Position = UDim2.fromOffset(14, 20),
			Size = UDim2.new(1, -20, 0, 14), TextTruncate = Enum.TextTruncate.AtEnd, Parent = bouton })
	end
	bouton:SetAttribute("CouleurBase", C.panneau)
	UI.rendreVivant(bouton)
	bouton.Activated:Connect(function()
		if UI.pref("modeVoyage", "auto") == "manuel" and (exterieur:GetAttribute("Etat") or E.Pose) == E.Pose
			and exterieur:GetAttribute("Porteur") ~= joueur.UserId then
			notifier("Mode manuel : décolle d'abord, les destinations se débloquent dans le vortex.", false)
			return
		end
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
		ajouterElement("◄  Retour : " .. precedentNom, "Dernière destination", { type = "precedent", nom = precedentNom }, ordre)
	end
	for nom in string.gmatch(exterieur:GetAttribute("ListeDestinations") or "", "[^\n]+") do
		noms[nom] = true
		if mode == "lieux" and garde(nom) then
			ordre += 1
			ajouterElement(nom, nil, { type = "lieu", nom = nom }, ordre)
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
	animer(tiroir, 0.45, { Position = ouvert and OUVERT or FERME })
	if not ouvert then recherche:ReleaseFocus() end
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
RunService.RenderStepped:Connect(function(dt)
	if not gui.Enabled then return end
	local etat = exterieur:GetAttribute("Etat") or E.Pose
	local enMouvement = etat ~= E.Pose
	local vitesse = enMouvement and 3 or 1
	local t = os.clock()
	if not ouvert then return end

	for i, anneau in anneaux do
		anneau.Rotation += dt * (i % 2 == 0 and -1 or 1) * (20 + i * 18) * vitesse
	end
	vortex.Rotation = (t * 10 * vitesse) % 360
	vortex.Offset = Vector2.new(math.sin(t * 0.35) * 0.35, 0)
	halo.Transparency = 0.5 + 0.4 * (0.5 + 0.5 * math.sin(t * (enMouvement and 6 or 2)))
	local lueur = 0.2 + 0.5 * (0.5 + 0.5 * math.sin(t * 3))
	for _, bouton in { boutonDemat, boutonRemat } do
		bouton.Lueur.Transparency = bouton:GetAttribute("Disponible") and lueur or 0.7
	end

	local ecoule = workspace:GetServerTimeNow() - (exterieur:GetAttribute("DebutEtat") or 0)
	if etat == E.Demat or etat == E.Remat then
		local duree, decalage = Config.Timing(etat, Config.modeDe(exterieur))
		local total = duree + decalage
		local p = math.clamp(ecoule / total, 0, 1)
		zoneProgression.Visible = true
		barreFond.Visible = true
		barre.Size = UDim2.fromScale(p, 1)
		progressionTexte.Text = string.format("%3d %%  ·  T-%s", math.floor(p * 100), UI.formatTemps(total - ecoule + 0.99))
	elseif etat == E.Vol then
		zoneProgression.Visible = true
		barreFond.Visible = false
		progressionTexte.Text = "VORTEX  ·  " .. UI.formatTemps(ecoule)
	else
		zoneProgression.Visible = false
	end
end)

local function majTaille()
	local ecran = camera.ViewportSize
	local echelle = math.clamp(ecran.Y / 820, 0.72, 1) * UI.tailleInterface()
	echelleTiroir.Scale = echelle
	tiroir.Size = UDim2.fromOffset(LARGEUR, math.clamp(ecran.Y * HAUTEUR_ECRAN / echelle, 360, 700))
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

local function majAcces()
	gui.Enabled = joueur:GetAttribute("TardisPilote_" .. def.Nom) == true
end
joueur:GetAttributeChangedSignal("TardisPilote_" .. def.Nom):Connect(majAcces)
majAcces()
changerMode("lieux")