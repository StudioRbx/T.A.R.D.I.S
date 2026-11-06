-- StarterPlayerScripts > TardisTablette > Construction (ModuleScript)
-- Construction de la tablette : panneaux, écran, barre du haut, colonnes A, B, C et dock
-- Extrait du script principal en V6.6.3 : reçoit ce qu'il utilise, renvoie ce que la suite utilise.
-- V6.9.10.6 : charte « Hologramme de confinement ». Plaque en haut (titre, badge PILOTE, ligne de données, bande de danger),
-- onglets en colonne à gauche (en ligne au-dessus du contenu sur téléphone) et une vue par onglet :
--   NAVIGATION (destination, cartes d'état, journal, DÉMAT / REMAT / VOL LIBRE / ALERTE) · SYSTÈMES · SCANNER · VOL LIBRE ·
--   OUTILS, RÉGLAGES et AIDE (le volet, module Volet) · JOURNAL. W.afficherVue(nom, onglet) change de vue.

return function(contexte)
	local C, Commandes, Config, Lighting, R, TAILLE_MIN = contexte.C, contexte.Commandes, contexte.Config, contexte.Lighting, contexte.R, contexte.TAILLE_MIN
	local UI, W, creer, exterieur, joueur, remote = contexte.UI, contexte.W, contexte.creer, contexte.exterieur, contexte.joueur, contexte.remote
	local seuilPortes, texte = contexte.seuilPortes, contexte.texte
	local V, def = contexte.V, contexte.def

	--------------------------------------------------------------------
	-- Petites fabriques
	--------------------------------------------------------------------
	-- Panneau de la tablette : cadre à coins coupés, titre, zone de contenu
	local panneaux = {}
	local PANNEAUX_WIDGETS = { ["STATUT"] = "statut", ["TÉLÉMÉTRIE"] = "telemetrie", ["FLUX TEMPOREL"] = "flux", ["COMMANDES RAPIDES"] = "flux", ["NAVIGATION"] = "navigation",
		["SCANNER"] = "scanner", ["OCCUPANTS DE LA SALLE"] = "occupants", ["JOURNAL DE BORD"] = "journal" }
	W.panneauxListe = {} -- { cadre, vue, x, y, hauteur, widget } : pour réorganiser les colonnes selon les widgets affichés
	local function panneau(parent, x, y, largeur, hauteur, titre, icone, couleur)
		couleur = couleur or C.ambre
		local cadre = UI.panneauCoupe({ Name = "Panneau", Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(largeur, hauteur),
			BackgroundColor3 = C.panneau, BackgroundTransparency = 0.1, Parent = parent },
		{ coupe = 12, rayon = 14, lueur = false, balayage = false, contour = C.ligne, transparenceContour = 0.3 })
		UI.decor(creer("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.blanc, Color3.fromRGB(200, 208, 226)), Parent = cadre }), "horsConfinement")
		if PANNEAUX_WIDGETS[titre] then
			table.insert(W.panneauxListe, { cadre = cadre, vue = parent, x = x, y = y, hauteur = hauteur, widget = PANNEAUX_WIDGETS[titre] })
		end
		creer("UIScale", { Parent = cadre })
		-- Anciens thèmes : bande de titre teintée et coin lumineux ; Confinement : titre clair et filet couleur de ligne
		UI.decor(creer("Frame", { Name = "Bande", Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = couleur, BorderSizePixel = 0, Parent = cadre },
		{ UI.coin(14), creer("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.84),
			NumberSequenceKeypoint.new(1, 1) }) }) }), "horsConfinement")
		UI.couleurSelonTheme(creer("Frame", { Name = "Filet", Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -24, 0, 1), BackgroundColor3 = couleur,
			BackgroundTransparency = 0.6, BorderSizePixel = 0, Parent = cadre }), "BackgroundColor3", couleur, "ligne")
		UI.decor(creer("Frame", { Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(26, 3), BackgroundColor3 = couleur,
			BorderSizePixel = 0, Parent = cadre }, { UI.coin(2) }), "horsConfinement")
		UI.decor(creer("Frame", { Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(3, 18), BackgroundColor3 = couleur,
			BorderSizePixel = 0, Parent = cadre }, { UI.coin(2) }), "horsConfinement")
		UI.couleurSelonTheme(texte({ Name = "TitrePanneau", Text = icone .. "  " .. UI.majuscules(titre), Font = UI.POLICE_TITRE, TextSize = 11, TextColor3 = couleur,
			Position = UDim2.fromOffset(14, 7), Size = UDim2.new(1, -28, 0, 16), Parent = cadre }), "TextColor3", couleur, "texte")
		local contenu = creer("Frame", { Position = UDim2.fromOffset(12, 34), Size = UDim2.new(1, -24, 1, -44),
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
			BackgroundColor3 = C.ligne, BackgroundTransparency = 0.6, BorderSizePixel = 0, Parent = ligne })
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

	-- La tablette : un panneau de la charte (coins coupés, filet cyan, lueur, balayage)
	W.tablette = UI.panneauCoupe({ Name = "Tablette", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(R.LARGEUR, R.HAUTEUR), BackgroundColor3 = C.fond, BackgroundTransparency = 0.04, Visible = false,
		Parent = W.gui }, { coupe = 16, rayon = 34, balayage = false }) -- (le balayage est posé sur l'écran, plus bas : UI.lignesEcran)
	W.echelle = creer("UIScale", { Parent = W.tablette })
	UI.decor(creer("UIGradient", { Rotation = 35, Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(150, 160, 180)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(230, 235, 245)),
	}), Parent = W.tablette }), "horsConfinement")

	-- Anciens thèmes : détails du cadre (caméra frontale et boutons latéraux)
	UI.decor(creer("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(7, 7),
		BackgroundColor3 = Color3.fromRGB(20, 30, 50), Parent = W.tablette }, { UI.coin(99), UI.contour(Color3.fromRGB(50, 70, 110), 1, 0) }), "horsConfinement")
	for _, x in { 120, 170 } do
		UI.decor(creer("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(36, 4),
			BackgroundColor3 = Color3.fromRGB(40, 48, 66), Parent = W.tablette }, { UI.coin(2) }), "horsConfinement")
	end

	-- L'écran lui-même (transparent en Confinement : la tablette est un seul panneau)
	W.ecran = creer("Frame", { Name = "Ecran", Position = UDim2.fromOffset(16, 16), Size = UDim2.new(1, -32, 1, -32),
		BackgroundColor3 = C.ecran, ClipsDescendants = true, Parent = W.tablette }, { UI.coin(22), UI.decor(UI.contour(Color3.new(0, 0, 0), 2, 0.4), "horsConfinement") })
	UI.fondSelonTheme(W.ecran, 0, 1)
	UI.decor(creer("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(120, 140, 175)),
		Parent = W.ecran }), "horsConfinement")

	-- Décor de fond des anciens thèmes : grille légère + grand cadran qui tourne lentement
	do
		local grille = UI.decor(creer("Frame", { Name = "Grille", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = W.ecran }), "horsConfinement")
		for i = 1, 15 do
			creer("Frame", { Position = UDim2.new(i / 16, 0, 0, 0), Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = C.cyan,
				BackgroundTransparency = 0.94, BorderSizePixel = 0, Parent = grille })
		end
		for i = 1, 9 do
			creer("Frame", { Position = UDim2.new(0, 0, i / 10, 0), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = C.cyan,
				BackgroundTransparency = 0.94, BorderSizePixel = 0, Parent = grille })
		end
		W.cadranFond = UI.decor(creer("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55),
			Size = UDim2.fromOffset(900, 900), BackgroundTransparency = 1, Parent = W.ecran },
		{ UI.coin(999), UI.contour(C.cyan, 1, 0.9) }), "horsConfinement")
		for k = 0, 59 do
			local angle = k / 60 * math.pi * 2
			creer("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Rotation = math.deg(angle) + 90,
				Position = UDim2.new(0.5 + math.cos(angle) * 0.5, 0, 0.5 + math.sin(angle) * 0.5, 0),
				Size = UDim2.fromOffset(k % 5 == 0 and 22 or 10, 2), BackgroundColor3 = C.cyan,
				BackgroundTransparency = k % 5 == 0 and 0.8 or 0.9, BorderSizePixel = 0, Parent = W.cadranFond })
		end
	end

	-- Matière de l'écran (V6.7) : lignes de balayage, vignette et reflet du verre (anciens thèmes), au-dessus des panneaux
	UI.lignesEcran(W.ecran, 44, 0.94).ZIndex = 30
	UI.decor(UI.vignette(W.ecran, 0.38), "horsConfinement").ZIndex = 31
	local reflet = UI.decor(creer("Frame", { Name = "Reflet", Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(1, 0.5), BackgroundColor3 = C.blanc,
		BorderSizePixel = 0, ZIndex = 32, Parent = W.ecran }, { UI.coin(22) }), "horsConfinement")
	creer("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.94), NumberSequenceKeypoint.new(0.35, 0.985),
		NumberSequenceKeypoint.new(1, 1) }), Parent = reflet })

	-- Ligne de balayage (animation d'ouverture)
	W.balayageEcran = creer("Frame", { Name = "BalayageOuverture", Position = UDim2.new(0, 0, 0, -4), Size = UDim2.new(1, 0, 0, 3),
		BackgroundColor3 = C.blanc, BorderSizePixel = 0, ZIndex = 50, Parent = W.ecran })
	creer("UIGradient", { Color = ColorSequence.new(C.cyan, C.cyan),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1) }), Parent = W.balayageEcran })

	--------------------------------------------------------------------
	-- Plaque (en haut) : titre, badge PILOTE, ligne de données, bande de danger (rouge pendant l'alerte) ;
	-- à droite : pastille d'état, horloge, jauge d'énergie, fermeture
	--------------------------------------------------------------------
	local HAUT = 88 -- haut des onglets et des vues
	do
		W.plaque = UI.plaque(W.ecran, "Tablette de pilotage", UI.texteBadge("Tablette", "PILOTE"), UI.codeObjet(def) .. "  ·  " .. def.Nom,
			{ position = UDim2.fromOffset(14, 12), taille = UDim2.new(1, -28, 0, 66), tailleTitre = 17, badgeColle = true, droite = 470,
				largeurBande = R.LARGEUR, exterieur = exterieur })
		local barreHaut = W.plaque.cadre
		-- (anciens thèmes : l'emblème et le dégradé animé ont laissé la place à la plaque ; Suivi ne fait plus rien tourner)
		W.anneaux = {}

		-- Pastille d'état, à gauche de l'horloge
		W.pastille = creer("Frame", { Name = "Pastille", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -232, 0, 2),
			Size = UDim2.fromOffset(0, 32), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = C.panneau,
			BackgroundTransparency = 0.25, ZIndex = 3, Parent = barreHaut },
		{ UI.coin(99, true), creer("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 14) }), UI.pile(10, true),
			creer("UISizeConstraint", { MaxSize = Vector2.new(240, 32) }) })
		W.pastille:FindFirstChildOfClass("UIListLayout").VerticalAlignment = Enum.VerticalAlignment.Center
		W.contourPastille = UI.contour(C.vert, 1, 0.3)
		W.contourPastille.Parent = W.pastille
		W.pointPastille = creer("Frame", { Size = UDim2.fromOffset(9, 9), BackgroundColor3 = C.vert, LayoutOrder = 1, ZIndex = 4,
			Parent = W.pastille }, { UI.coin(99, true) })
		W.textePastille = texte({ Text = "Posé", Font = UI.POLICE_GRAS, TextSize = 13, Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2, ZIndex = 4, Parent = W.pastille })
		W.lieuPastille = texte({ Text = "", Font = UI.POLICE_CODE, TextSize = 11, TextColor3 = C.texte2, Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 3, ZIndex = 4, TextTruncate = Enum.TextTruncate.AtEnd, Parent = W.pastille })

		-- Droite, de droite à gauche : fermeture, jauge d'énergie, horloge
		W.fermer = UI.boutonCoupe(barreHaut, "×", "danger", { Name = "Fermer", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, -2),
			Size = UDim2.fromOffset(44, 44), Font = UI.POLICE_GRAS, TextSize = 24, ZIndex = 3 })
		local jauge = creer("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -56, 0, 8),
			Size = UDim2.fromOffset(62, 20), BackgroundTransparency = 1, ZIndex = 3, Parent = barreHaut }, { UI.pile(3, true) })
		W.jauge = {}
		for i = 1, 5 do
			W.jauge[i] = creer("Frame", { Size = UDim2.fromOffset(9, 20), BackgroundColor3 = C.vert, LayoutOrder = i, ZIndex = 4,
				Parent = jauge }, { UI.coin(2) })
		end
		W.horloge = texte({ Text = "00:00:00", Font = UI.POLICE_CODE, TextSize = 15, TextColor3 = C.cyan,
			TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -128, 0, 8),
			Size = UDim2.fromOffset(92, 20), ZIndex = 3, Parent = barreHaut })
	end

	--------------------------------------------------------------------
	-- Onglets (colonne à gauche ; en ligne au-dessus du contenu sur téléphone) et vues
	--------------------------------------------------------------------
	local ONGLETS = { { "navigation", "Navigation" }, { "systemes", "Systèmes" }, { "scanner", "Scanner" }, { "volLibre", "Vol libre" },
		{ "outils", "Outils" }, { "journal", "Journal" }, { "reglages", "Réglages" }, { "aide", "Aide" } }
	W.onglets = creer("Frame", { Name = "Onglets", Position = UDim2.fromOffset(14, HAUT), Size = UDim2.new(0, 150, 1, -(HAUT + 12)),
		BackgroundTransparency = 1, ZIndex = 2, Parent = W.ecran }, { UI.pile(6) })
	W.ongletsPuces = {}
	for i, info in ONGLETS do
		-- (pas de UIPadding dans une puce : il décalerait ses coins coupés ; le retrait du texte vient des espaces)
		W.ongletsPuces[info[1]] = UI.puce(W.onglets, "   " .. info[2], { Name = "Onglet_" .. info[1], Size = UDim2.new(1, 0, 0, UI.JETONS.cible), LayoutOrder = i,
			TextXAlignment = Enum.TextXAlignment.Left })
	end
	-- Les onglets Outils, Réglages et Aide ouvrent le volet (module Volet)
	W.btnOutils = W.ongletsPuces.outils.bouton
	W.btnReglages = W.ongletsPuces.reglages.bouton
	W.btnAide = W.ongletsPuces.aide.bouton
	-- Statistiques de la session, sous les onglets (cachées sur téléphone)
	W.statsSession = creer("Frame", { Name = "Statistiques", Size = UDim2.new(1, 0, 0, 66), BackgroundTransparency = 1, LayoutOrder = 20, Parent = W.onglets },
	{ UI.pile(2), creer("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 4) }) })
	local function stat(nom, ordre)
		local ligne = creer("Frame", { Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, LayoutOrder = ordre, Parent = W.statsSession })
		texte({ Text = UI.majuscules(nom), Font = UI.POLICE_CODE, TextSize = 10, TextColor3 = C.texte2, Size = UDim2.new(0.6, 0, 1, 0), Parent = ligne })
		return texte({ Text = "—", Font = UI.POLICE_CODE, TextSize = 11, TextColor3 = C.ambre,
			TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(1, -6, 1, 0), Parent = ligne })
	end
	W.statVoyages = stat("Voyages", 1)
	W.statVortex = stat("Vortex", 2)
	W.statSession = stat("Session", 3)

	W.vuesCadre = creer("Frame", { Name = "Vues", Position = UDim2.fromOffset(178, HAUT), Size = UDim2.new(1, -192, 1, -(HAUT + 12)),
		BackgroundTransparency = 1, Parent = W.ecran })
	W.vues = {}
	for _, nom in { "navigation", "systemes", "scanner", "volLibre", "journal", "volet" } do
		W.vues[nom] = creer("Frame", { Name = "Vue_" .. nom, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = nom == "navigation", Parent = W.vuesCadre })
	end
	W.vueVolet = W.vues.volet
	W.vueActive = "navigation"
	-- Change de vue ; onglet = l'onglet allumé (le volet sert à Outils, Réglages et Aide)
	function W.afficherVue(nom, onglet)
		W.vueActive = nom
		for cle, vue in W.vues do vue.Visible = cle == nom end
		local actif = onglet or nom
		for cle, puce in W.ongletsPuces do puce.regler(cle == actif) end
		if nom ~= "volet" and V then V.actif = nil end
		if nom == "volLibre" and W.majTouchesVol then W.majTouchesVol() end
	end
	for _, cle in { "navigation", "systemes", "scanner", "volLibre", "journal" } do
		W.ongletsPuces[cle].bouton.Activated:Connect(function() W.afficherVue(cle) end)
	end
	W.afficherVue("navigation")
	-- Téléphone (ou fenêtre étroite) : onglets en ligne au-dessus du contenu
	function W.majCompact()
		local compact = UI.ecranCompact()
		W.compact = compact
		local pile = W.onglets:FindFirstChildOfClass("UIListLayout")
		local n = #ONGLETS
		if compact then
			W.onglets.Size = UDim2.new(1, -28, 0, UI.JETONS.cible)
			pile.FillDirection = Enum.FillDirection.Horizontal
			for _, info in ONGLETS do W.ongletsPuces[info[1]].bouton.Size = UDim2.new(1 / n, -6 * (n - 1) / n, 1, 0) end
			W.vuesCadre.Position = UDim2.fromOffset(14, HAUT + UI.JETONS.cible + 8)
			W.vuesCadre.Size = UDim2.new(1, -28, 1, -(HAUT + UI.JETONS.cible + 20))
		else
			W.onglets.Size = UDim2.new(0, 150, 1, -(HAUT + 12))
			pile.FillDirection = Enum.FillDirection.Vertical
			for _, info in ONGLETS do W.ongletsPuces[info[1]].bouton.Size = UDim2.new(1, 0, 0, UI.JETONS.cible) end
			W.vuesCadre.Position = UDim2.fromOffset(178, HAUT)
			W.vuesCadre.Size = UDim2.new(1, -192, 1, -(HAUT + 12))
		end
		W.statsSession.Visible = not compact
	end
	W.majCompact()

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

	-- Balise de détresse : notification ALERTE cliquable (bouton "Y aller" = démat + remat automatique à 2 studs du joueur)
	W.alerteBaliseNotif = UI.notification({ Name = "AlerteBalise", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 340, 0, 170), Size = UDim2.fromOffset(320, 0),
		ZIndex = 30, Parent = W.gui }, { tailleTexte = 13 })
	W.alerteBalise = W.alerteBaliseNotif.cadre
	W.alerteBaliseTexte = W.alerteBaliseNotif.message
	W.alerteBaliseBouton = UI.boutonCoupe(W.alerteBaliseNotif.contenu, "Y aller  (démat + remat auto)", "principal", { Name = "YAller", Size = UDim2.new(1, 0, 0, UI.JETONS.cible),
		Font = UI.POLICE_GRAS, TextSize = 12, LayoutOrder = 10 })
	W.alerteBaliseFermer = UI.boutonCoupe(W.alerteBaliseNotif.contenu, "Ignorer", "secondaire", { Name = "Ignorer", Size = UDim2.new(1, 0, 0, UI.JETONS.cible),
		Font = UI.POLICE_GRAS, TextSize = 12, LayoutOrder = 11 })

	-- Alerte de la sentinelle : visible même quand la tablette est fermée
	W.alerteNotif = UI.notification({ Name = "AlerteSentinelle", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 20, 0, 90), Size = UDim2.fromOffset(320, 0),
		ZIndex = 30, Parent = W.gui }, { tailleTexte = 13 })
	W.alerte = W.alerteNotif.cadre
	W.alerteTexte = W.alerteNotif.message

	-- Notification (en haut de l'écran de la tablette) : badge TARDIS / ALERTE / REFUSÉ
	W.notif = UI.notification({ Name = "Notification", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -80), Size = UDim2.fromOffset(480, 0),
		ZIndex = 40, Parent = W.ecran })
	W.notification = W.notif.cadre
	W.notifTexte = W.notif.message

	--------------------------------------------------------------------
	-- VUE SYSTÈMES : statut, télémétrie, systèmes (dock), commandes rapides
	--------------------------------------------------------------------
	local vueSystemes = W.vues.systemes
	do
		local _, contenu = panneau(vueSystemes, 0, 0, 360, 232, "STATUT", "●")
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
			BackgroundTransparency = 1, Parent = anneau }, { UI.coin(999), UI.contour(C.ligne, 1, 0.5) })
		W.anneauTexte = texte({ Text = "OK", Font = UI.POLICE_CODE, TextSize = 26, TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(110, 30), Parent = anneau })
		W.anneauSous = texte({ Text = "POSÉ", Font = UI.POLICE_CODE, TextSize = 11, TextColor3 = C.texte2,
			TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.64),
			Size = UDim2.fromOffset(110, 14), Parent = anneau })

		local droite = creer("Frame", { Position = UDim2.fromOffset(166, 0), Size = UDim2.new(1, -166, 1, 0),
			BackgroundTransparency = 1, Parent = contenu }, { UI.pile(6) })
		UI.etiquette(droite, "État du TARDIS", { LayoutOrder = 1 })
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
			express = UI.badge(badges, "RAPIDE", C.vert, 9),
			sauvetage = UI.badge(badges, "SAUVETAGE", UI.couleurMode("Sauvetage"), 11),
			silencieux = UI.badge(badges, "SILENCIEUX", UI.couleurMode("Silencieux"), 13),
			siege = UI.badge(badges, "SIÈGE", C.rouge, 14),
			catastrophe = UI.badge(badges, "PARADOXE", C.rouge, 12),
			horsTension = UI.badge(badges, "HORS TENSION", C.texte2, 6),
			alerte = UI.badge(badges, "ALERTE", C.rouge, 7),
			bloque = UI.badge(badges, "BLOQUÉ", C.orange, 8),
			eau = UI.badge(badges, "SUR L'EAU", C.cyan, 10),
		}
		-- Jauges à segments : énergie du bouclier et intégrité du TARDIS (la valeur exacte à côté)
		W.jaugeBouclier = UI.jaugeSegments(droite, "Bouclier", { ordre = 5, nomObjet = "JaugeBouclier", hauteurSegment = 10, largeurValeur = 70 })
		W.jaugeIntegrite = UI.jaugeSegments(droite, "Intégrité", { ordre = 6, nomObjet = "JaugeIntegrite", hauteurSegment = 10, largeurValeur = 70 })
	end

	do
		local _, contenu = panneau(vueSystemes, 0, 244, 360, 196, "TÉLÉMÉTRIE", "▲", C.cyan)
		UI.pile(2).Parent = contenu
		W.infoLieu = ligneInfo(contenu, "Lieu actuel", 1)
		W.infoCoord = ligneInfo(contenu, "Coordonnées", 2)
		W.infoCap = ligneInfo(contenu, "Cap", 3)
		W.infoEchelle = ligneInfo(contenu, "Échelle", 4)
		W.infoPortes = ligneInfo(contenu, "Portes", 5)
		W.infoDestination = ligneInfo(contenu, "Destination", 6)
	end

	do
		-- Commandes rapides (à la place du flux temporel) : six outils directement sur la tablette (module Outils)
		local cadre, contenu = panneau(vueSystemes, 374, 192, 682, 120, "COMMANDES RAPIDES", "●", C.cyan)
		W.stabilite = texte({ Text = "STABLE", Font = UI.POLICE_CODE, TextSize = 11, TextColor3 = C.vert,
			TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, -14, 0, 16), Parent = cadre })
		W.barres = {}
		W.rapides = contenu
	end

	do
		-- Systèmes : tuiles, échelle, boucliers, voyants (au-dessus des commandes rapides : la fenêtre des boucliers les recouvre)
		local cadreDock, contenu = panneau(vueSystemes, 374, 0, 682, 180, "SYSTÈMES", "◆")
		cadreDock.ZIndex = 2
		local function tuile(nom, icone, x)
			local bouton = creer("TextButton", { Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(120, 56),
				BackgroundColor3 = C.fond, Text = "", Parent = contenu }, { UI.coin(10), UI.contour(C.ligne, 1, 0.4) })
			local lampe = creer("Frame", { Position = UDim2.fromOffset(10, 9), Size = UDim2.fromOffset(8, 8), BackgroundColor3 = C.gris,
				Parent = bouton }, { UI.coin(99, true) })
			texte({ Text = icone, TextSize = 15, TextColor3 = C.texte2, TextXAlignment = Enum.TextXAlignment.Right,
				Position = UDim2.fromOffset(0, 3), Size = UDim2.new(1, -10, 0, 18), Parent = bouton })
			texte({ Text = UI.majuscules(nom), Font = UI.POLICE_GRAS, TextSize = 12, Position = UDim2.fromOffset(10, 20),
				Size = UDim2.new(1, -16, 0, 16), Parent = bouton })
			local etat = texte({ Text = "", Font = UI.POLICE_CODE, TextSize = 10, TextColor3 = C.texte2, Position = UDim2.fromOffset(10, 37),
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
		local zone = creer("Frame", { Position = UDim2.fromOffset(0, 72), Size = UDim2.fromOffset(300, 56),
			BackgroundTransparency = 1, Parent = contenu })
		texte({ Text = "ÉCHELLE DE LA CABINE", Font = UI.POLICE_GRAS, TextSize = 12, Size = UDim2.new(1, -60, 0, 16), Parent = zone })
		W.valeurTaille = texte({ Text = "100 %", Font = UI.POLICE_CODE, TextSize = 14, TextColor3 = C.ambre,
			TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(1, 0, 0, 16), Parent = zone })
		W.pisteTaille = creer("TextButton", { Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 22),
			BackgroundTransparency = 1, Text = "", Parent = zone })
		W.railTaille = creer("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = C.gris, Parent = W.pisteTaille }, { UI.coin(99, true) })
		W.remplissageTaille = creer("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.ambre, Parent = W.railTaille },
		{ UI.coin(99, true) })
		if seuilPortes < 1 then
			creer("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale((seuilPortes - TAILLE_MIN) / (1 - TAILLE_MIN), 0.5),
				Size = UDim2.fromOffset(2, 14), BackgroundColor3 = C.cyan, BorderSizePixel = 0, Parent = W.railTaille })
		end
		W.poignee = creer("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(18, 18), BackgroundColor3 = C.texte, Parent = W.pisteTaille }, { UI.coin(99, true), UI.contour(C.ambre, 2, 0) })
		W.aideTaille = texte({ Text = "", Font = UI.POLICE_CODE, TextSize = 10, TextColor3 = C.texte2, Position = UDim2.fromOffset(0, 42),
			Size = UDim2.new(1, 0, 0, 14), Parent = zone })

		-- Boucliers : deux boutons empilés
		local zoneBoucliers = creer("Frame", { Position = UDim2.fromOffset(518, 0), Size = UDim2.fromOffset(140, 56),
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
		-- Choix des boucliers : petite fenêtre sous les boutons
		W.choixBoucliers = creer("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0, 588, 0, 62), Size = UDim2.fromOffset(240, 0),
			AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.fond, BackgroundTransparency = 0.05, Visible = false, ZIndex = 20, Parent = contenu },
		{ UI.coin(10), UI.contour(C.cyan, 1, 0.3), UI.marges(8), UI.pile(5) })
		W.boutonsBouclier = {}
		for i, info in { { "Joueurs", "Anti-joueurs : personne n'approche" }, { "Balles", "Anti-balles : les tirs s'arrêtent" }, { "Complet", "Complet : joueurs et tirs" } } do
			local b = creer("TextButton", { Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = C.panneau, Text = info[2], Font = UI.POLICE_GRAS, TextSize = 11,
				TextColor3 = C.texte, LayoutOrder = i, ZIndex = 21, Parent = W.choixBoucliers }, { UI.coin(7) })
			b:SetAttribute("CouleurBase", C.panneau)
			UI.rendreVivant(b)
			b.Activated:Connect(function() remote:FireServer("Bouclier", { type = info[1] }) end)
			W.boutonsBouclier[info[1]] = b
		end

		local voyants = creer("Frame", { Position = UDim2.fromOffset(320, 72), Size = UDim2.fromOffset(180, 56),
			BackgroundTransparency = 1, Parent = contenu }, { UI.pile(1) })
		local function voyant(nom, ordre)
			local ligne = creer("Frame", { Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, LayoutOrder = ordre, Parent = voyants })
			local lampe = creer("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
				Size = UDim2.fromOffset(8, 8), BackgroundColor3 = C.gris, Parent = ligne }, { UI.coin(99, true) })
			texte({ Text = nom, TextSize = 12, Position = UDim2.fromOffset(14, 0), Size = UDim2.new(0.6, 0, 1, 0), Parent = ligne })
			local valeur = texte({ Text = "", Font = UI.POLICE_CODE, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Right,
				Size = UDim2.fromScale(1, 1), Parent = ligne })
			return { lampe = lampe, valeur = valeur }
		end
		W.voyants = { energie = voyant("Énergie", 1), alerte = voyant("Alerte", 2), demarrage = voyant("Démarrage", 3) }
	end

	--------------------------------------------------------------------
	-- VUE SCANNER : scanner (radar / mini-carte) et occupants
	--------------------------------------------------------------------
	local vueScanner = W.vues.scanner
	do
		local cadreScanner, contenu = panneau(vueScanner, 0, 0, 520, 290, "SCANNER", "●", C.cyan)
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

		local lectures = creer("Frame", { Position = UDim2.fromOffset(240, 4), Size = UDim2.new(1, -240, 1, -4),
			BackgroundTransparency = 1, Parent = contenu }, { UI.pile(4) })
		local function lecture(titre, ordre)
			UI.etiquette(lectures, titre, { LayoutOrder = ordre, Size = UDim2.new(1, 0, 0, 12) })
			return texte({ Text = "—", Font = UI.POLICE_CODE, TextSize = 13, TextColor3 = C.cyan, Size = UDim2.new(1, 0, 0, 16),
				LayoutOrder = ordre + 1, Parent = lectures })
		end
		W.lectX = lecture("POSITION X", 1)
		W.lectY = lecture("POSITION Y", 3)
		W.lectZ = lecture("POSITION Z", 5)
		W.lectCap = lecture("CAP", 7)
		W.lectPortee = lecture("À PORTÉE", 9)
		UI.ligneAide(lectures, "Clique sur un point (radar) ou un lieu (carte) pour le viser.", { LayoutOrder = 11 })
	end

	do
		local cadre, contenu = panneau(vueScanner, 536, 0, 520, 104, "OCCUPANTS DE LA SALLE", "●", C.vert)
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

	--------------------------------------------------------------------
	-- VUE JOURNAL : le journal de bord en tableau HEURE | ÉVÉNEMENT | DÉTAIL
	--------------------------------------------------------------------
	do
		local cadre, contenu = panneau(W.vues.journal, 0, 0, 1056, 560, "JOURNAL DE BORD", "■")
		W.effacer = UI.boutonCoupe(cadre, "Effacer", "secondaire", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 4),
			Size = UDim2.fromOffset(96, 24), Font = UI.POLICE_GRAS, TextSize = 11 })
		W.exporter = UI.boutonCoupe(cadre, "Exporter", "secondaire", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -114, 0, 4),
			Size = UDim2.fromOffset(96, 24), Font = UI.POLICE_GRAS, TextSize = 11 })
		W.journalTableau = UI.tableau(contenu, {
			{ cle = "heure", titre = "Heure", largeur = UDim.new(0, 90), donnees = true },
			{ cle = "evenement", titre = "Événement", largeur = UDim.new(1, -370) },
			{ cle = "detail", titre = "Détail", largeur = UDim.new(0, 280), donnees = true },
		}, { nom = "Journal", taille = UDim2.fromScale(1, 1), hauteurLigne = 32 })
		W.journal = W.journalTableau.corps
		W.journalVide = texte({ Text = "Rien à signaler.", TextSize = 12, TextColor3 = C.texte2, LayoutOrder = 0, Parent = W.journal })
	end

	--------------------------------------------------------------------
	-- VUE NAVIGATION (charte) : à gauche la liste des destinations, à droite la destination, l'état, le journal, les actions
	--------------------------------------------------------------------
	do
		local vue = W.vues.navigation
		local gauche = creer("Frame", { Name = "Gauche", Size = UDim2.new(0.5, -8, 1, 0), BackgroundTransparency = 1, Parent = vue }, { UI.pile(8) })
		table.insert(W.panneauxListe, { cadre = gauche, vue = vue, x = 0, y = 0, hauteur = 0, widget = "navigation", fixe = true })

		-- Lieux / Joueurs / Coordonnées / Historique
		local segments = creer("Frame", { Name = "Segments", Size = UDim2.new(1, 0, 0, UI.JETONS.cible), BackgroundTransparency = 1, LayoutOrder = 1,
			Parent = gauche }, { UI.pile(6, true) })
		W.segments3 = {}
		for i, info in { { "lieux", "◆ Lieux" }, { "joueurs", "● Joueurs" }, { "coord", "○ Coord." }, { "histo", "► Historique" } } do
			W.segments3[info[1]] = UI.puce(segments, info[2], { Name = "Segment_" .. info[1], Size = UDim2.new(0.25, -4.5, 1, 0), LayoutOrder = i, TextSize = 12 })
		end

		W.recherche = UI.champRecherche(gauche, { PlaceholderText = "Rechercher un lieu ou un joueur…", LayoutOrder = 2 })

		W.tableauDest = UI.tableau(gauche, {
			{ cle = "nom", titre = "Destination", largeur = UDim.new(1, -176), retrait = 26 },
			{ cle = "dist", titre = "Dist.", largeur = UDim.new(0, 66), droite = true, donnees = true },
			{ cle = "statut", titre = "Statut", largeur = UDim.new(0, 110), donnees = true },
		}, { nom = "Destinations", taille = UDim2.new(1, 0, 0, 20 + 44 * 6), ordre = 3 })
		W.liste = W.tableauDest.cadre
		W.listeCorps = W.tableauDest.corps
		W.listeVide = texte({ Text = "", TextSize = 12, TextColor3 = C.texte2, TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 44), TextWrapped = true, LayoutOrder = 999, Visible = false, Parent = W.listeCorps })

		-- Panneau Coordonnées (remplace la liste dans l'onglet Coordonnées)
		W.panneauCoord = creer("Frame", { Name = "Coordonnees", Size = UDim2.new(1, 0, 0, 20 + 44 * 6), BackgroundColor3 = C.panneau,
			LayoutOrder = 3, Visible = false, Parent = gauche }, { UI.coin(9), UI.contour(C.ligne, 1, 0.5), UI.marges(14), UI.pile(10) })
		texte({ Text = "Place un aperçu du TARDIS n'importe où dans le monde, tourne-le et incline-le. "
			.. "S'il touche un obstacle, l'atterrissage passera automatiquement en urgence.", TextSize = 13, TextColor3 = C.texte2,
			TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 1, Parent = W.panneauCoord })
		W.boutonPlacer = UI.boutonCoupe(W.panneauCoord, "○  Choisir une nouvelle localisation", "principal", { Name = "Placer", Size = UDim2.new(1, 0, 0, 46), LayoutOrder = 2 })
		W.infoPlacement = texte({ Text = "Aucune localisation enregistrée.", Font = UI.POLICE_CODE, TextSize = 12, TextColor3 = C.texte2,
			TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 3, Parent = W.panneauCoord })

		-- Protocoles (V6.9) : le mode dans des puces (un seul actif), l'atterrissage invisible à droite
		local protocoles = creer("Frame", { Name = "Protocoles", Size = UDim2.new(1, 0, 0, UI.JETONS.cible), BackgroundTransparency = 1, LayoutOrder = 5,
			Parent = gauche }, { UI.pile(10, true) })
		local modes = UI.selecteurModes(protocoles, {
			{ cle = "classique", nom = "Classique", couleur = C.cyan },
			{ cle = "urgence", nom = "Urgence", couleur = C.orange },
			{ cle = "express", nom = "Rapide", couleur = C.vert },
			{ cle = "sauvetage", nom = "Sauvetage", couleur = UI.couleurMode("Sauvetage") },
			{ cle = "silencieux", nom = "Silencieux", couleur = UI.couleurMode("Silencieux") },
		}, 1, UDim2.new(1, -150, 1, 0))
		local droiteProtocoles = creer("Frame", { Size = UDim2.new(0, 140, 1, 0), BackgroundTransparency = 1, LayoutOrder = 2, Parent = protocoles })
		W.interInvisible = UI.interrupteur(droiteProtocoles, "Invisible", "Déjà camouflé", C.cyan, 1)
		W.modes = modes
		-- État partagé avec le menu rapide
		Commandes.lierInterrupteurs({ classique = modes.classique, urgence = modes.urgence, express = modes.express, sauvetage = modes.sauvetage,
			silencieux = modes.silencieux, invisible = W.interInvisible })

		local droite = creer("Frame", { Name = "Droite", Position = UDim2.new(0.5, 8, 0, 0), Size = UDim2.new(0.5, -8, 1, 0), BackgroundTransparency = 1,
			Parent = vue }, { UI.pile(10) })
		-- Destination choisie (le nom en grand, en jaune)
		local fiche = creer("Frame", { Name = "Fiche", Size = UDim2.new(1, 0, 0, 134), BackgroundColor3 = C.panneau, LayoutOrder = 1, Parent = droite },
		{ UI.coin(10), UI.contour(C.ligne, 1, 0.6) })
		W.ficheIcone = texte({ Text = "?", Font = UI.POLICE_GRAS, TextSize = 13, TextColor3 = C.ambre, TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(10, 7), Size = UDim2.fromOffset(18, 18), Parent = fiche })
		UI.etiquette(fiche, "Destination", { Position = UDim2.fromOffset(32, 9), Size = UDim2.new(1, -180, 0, 14) })
		W.ficheNom = texte({ Text = "Aucune destination", Font = UI.POLICE_TITRE, TextSize = 22, TextColor3 = C.ambre, TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(14, 28), Size = UDim2.new(1, -28, 0, 32), Parent = fiche })
		W.ficheInfo = texte({ Text = "Choisis un lieu, un joueur ou des coordonnées.", Font = UI.POLICE_CODE, TextSize = 12,
			TextColor3 = C.texte2, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(14, 62),
			Size = UDim2.new(1, -28, 0, 16), Parent = fiche })
		-- Catégorie (lieux) : un clic passe à la catégorie suivante
		W.boutonCategorie = creer("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 6), Size = UDim2.fromOffset(140, 24),
			BackgroundColor3 = C.fond, Text = "Catégorie", Font = UI.POLICE_GRAS, TextSize = 11, TextColor3 = C.texte2, Visible = false, Parent = fiche },
		{ UI.coin(6), UI.contour(C.ligne, 1, 0.4) })
		W.boutonCategorie:SetAttribute("CouleurBase", C.fond)
		UI.rendreVivant(W.boutonCategorie)
		-- Joueur : dernière position ou sur lui (figé)
		W.modeJoueur = creer("Frame", { Name = "ModeJoueur", Position = UDim2.fromOffset(14, 86), Size = UDim2.new(1, -28, 0, 40),
			BackgroundTransparency = 1, Visible = false, Parent = fiche }, { UI.pile(6, true) })
		W.puceDernierePos = UI.puce(W.modeJoueur, "Dernière position", { Size = UDim2.new(0.5, -3, 1, 0), LayoutOrder = 1, TextSize = 12 })
		W.puceSurLui = UI.puce(W.modeJoueur, "Sur lui (figé)", { Size = UDim2.new(0.5, -3, 1, 0), LayoutOrder = 2, TextSize = 12 })
		W.boutonDernierePos = W.puceDernierePos.bouton
		W.boutonSurLui = W.puceSurLui.bouton

		-- Cartes d'état (bord gauche de couleur)
		local grille = creer("Frame", { Name = "CartesEtat", Size = UDim2.new(1, 0, 0, 112), BackgroundTransparency = 1, LayoutOrder = 2, Parent = droite },
		{ creer("UIGridLayout", { CellSize = UDim2.new(0.5, -5, 0, 52), CellPadding = UDim2.fromOffset(10, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
		W.cartesEtat = {
			etat = UI.carteEtat(grille, "État", { LayoutOrder = 1, Name = "Carte_etat" }),
			mode = UI.carteEtat(grille, "Mode", { LayoutOrder = 2, Name = "Carte_mode" }),
			portes = UI.carteEtat(grille, "Portes", { LayoutOrder = 3, Name = "Carte_portes" }),
			boucliers = UI.carteEtat(grille, "Boucliers", { LayoutOrder = 4, Name = "Carte_boucliers" }),
		}

		-- Les derniers événements du journal
		W.journalMini = UI.tableau(droite, {
			{ cle = "heure", titre = "Heure", largeur = UDim.new(0, 70), donnees = true },
			{ cle = "evenement", titre = "Événement", largeur = UDim.new(1, -210) },
			{ cle = "detail", titre = "Détail", largeur = UDim.new(0, 140), donnees = true },
		}, { nom = "JournalRecent", taille = UDim2.new(1, 0, 0, 20 + 32 * 3), hauteurLigne = 32, ordre = 3, defilement = false })

		-- Actions : DÉMAT (principal), REMAT, VOL LIBRE, ALERTE (siège : bouclier + verrou + alerte)
		local actions = creer("Frame", { Name = "Actions", Size = UDim2.new(1, 0, 0, 50), BackgroundTransparency = 1, LayoutOrder = 4, Parent = droite },
		{ UI.pile(8, true) })
		-- Grands boutons partagés avec le menu rapide (UI.boutonPrincipal) : lueur, barre de progression du voyage
		W.demat = UI.boutonPrincipal(actions, "DÉMAT", "Décoller", 1, UDim2.new(0.25, -6, 1, 0), 10, "principal")
		W.remat = UI.boutonPrincipal(actions, "REMAT", "Atterrir", 2, UDim2.new(0.25, -6, 1, 0), 10, "secondaire")
		W.boutonVolLibre = UI.boutonCoupe(actions, "Vol libre", "secondaire", { Name = "VolLibre", Size = UDim2.new(0.25, -6, 1, 0), LayoutOrder = 3, TextSize = 12 })
		W.boutonAlerte = UI.boutonCoupe(actions, "Alerte", "danger", { Name = "Alerte", Size = UDim2.new(0.25, -6, 1, 0), LayoutOrder = 4, TextSize = 12 })
		UI.ligneAide(droite, "Clique une ligne pour choisir  ·  DÉMAT décolle  ·  ALERTE : bouclier, verrou et alerte  ·  × ferme la tablette", { LayoutOrder = 5 })
	end

	--------------------------------------------------------------------
	-- VUE VOL LIBRE : état, lancement et touches du vol
	--------------------------------------------------------------------
	do
		local vue = W.vues.volLibre
		local gauche = creer("Frame", { Name = "Gauche", Size = UDim2.new(0.5, -8, 1, 0), BackgroundTransparency = 1, Parent = vue }, { UI.pile(10) })
		local bloc = creer("Frame", { Name = "EtatVol", Size = UDim2.new(1, 0, 0, 120), BackgroundColor3 = C.panneau, LayoutOrder = 1, Parent = gauche },
		{ UI.coin(10), UI.contour(C.ligne, 1, 0.6) })
		UI.etiquette(bloc, "Vol libre", { Position = UDim2.fromOffset(14, 10) })
		W.volLibreEtat = texte({ Name = "Etat", Text = "PRÊT", Font = UI.POLICE_TITRE, TextSize = 24, TextColor3 = C.vert,
			Position = UDim2.fromOffset(14, 30), Size = UDim2.new(1, -28, 0, 34), Parent = bloc })
		W.volLibreRaison = texte({ Name = "Raison", Text = "", Font = UI.POLICE_CODE, TextSize = 12, TextColor3 = C.texte2, TextWrapped = true,
			Position = UDim2.fromOffset(14, 68), Size = UDim2.new(1, -28, 0, 40), TextYAlignment = Enum.TextYAlignment.Top, Parent = bloc })
		W.boutonLancerVol = UI.boutonCoupe(gauche, "Lancer le vol libre", "principal", { Name = "LancerVol", Size = UDim2.new(1, 0, 0, 56), LayoutOrder = 2 })
		UI.ligneAide(gauche, "La tablette se range pour laisser voir le TARDIS. Regarde où tu veux aller ; les touches du vol sont à droite "
			.. "(modifiables dans Réglages).", { LayoutOrder = 3 })

		local touches = UI.tableau(vue, {
			{ cle = "touche", titre = "Touche", largeur = UDim.new(0, 130), donnees = true, majuscules = false },
			{ cle = "commande", titre = "Commande", largeur = UDim.new(1, -130) },
		}, { nom = "TouchesVol", taille = UDim2.new(0.5, -8, 1, 0), hauteurLigne = 32 })
		touches.cadre.Position = UDim2.new(0.5, 8, 0, 0)
		local TOUCHES_VOL = {
			{ "volVitesse", "Vitesse suivante", "F" }, { "volCroisiere", "Croisière", "Return" }, { "volFrein", "Frein", "LeftControl" },
			{ "volBoost", "Boost", "LeftShift" }, { "volUrgence", "Urgence", "U" }, { "volVortex", "Vortex", "V" }, { "volSaut", "Saut temporel", "B" },
			{ "volPortes", "Portes", "O" }, { "volDemat", "Démat / remat", "X" }, { "volTonneau", "Tonneau", "C" }, { "volTracteur", "Rayon tracteur", "R" },
			{ "volCamouflage", "Camouflage", "K" }, { "volStationnaire", "Stationnaire", "H" }, { "volPoser", "Se poser", "G" }, { "volAtterrir", "Atterrir ici", "N" },
		}
		function W.majTouchesVol()
			touches.vider()
			for i, info in TOUCHES_VOL do
				local touche = UI.touche(info[1], Enum.KeyCode[info[3]])
				touches.ajouter({ touche = touche and touche.Name or info[3], commande = info[2] }, { ordre = i, nom = "Touche_" .. info[1], couleurs = { touche = C.cyan } })
			end
		end
		W.majTouchesVol()
	end

	return { panneaux = panneaux }
end
