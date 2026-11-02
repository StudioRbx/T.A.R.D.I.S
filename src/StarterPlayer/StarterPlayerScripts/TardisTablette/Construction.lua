-- StarterPlayerScripts > TardisTablette > Construction (ModuleScript)
-- Construction de la tablette : panneaux, écran, barre du haut, colonnes A, B, C et dock
-- Extrait du script principal en V6.6.3 : reçoit ce qu'il utilise, renvoie ce que la suite utilise.

return function(contexte)
	local C, Commandes, Config, Lighting, R, TAILLE_MIN = contexte.C, contexte.Commandes, contexte.Config, contexte.Lighting, contexte.R, contexte.TAILLE_MIN
	local UI, W, creer, exterieur, joueur, remote = contexte.UI, contexte.W, contexte.creer, contexte.exterieur, contexte.joueur, contexte.remote
	local seuilPortes, texte = contexte.seuilPortes, contexte.texte

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
			BackgroundColor3 = C.panneau, BackgroundTransparency = 0.1, Parent = parent },
		{ UI.coin(14), UI.contour(C.bleu, 1, 0.35), creer("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.blanc, Color3.fromRGB(200, 208, 226)) }) })
		if PANNEAUX_WIDGETS[titre] then
			table.insert(W.panneauxListe, { cadre = cadre, x = x, y = y, hauteur = hauteur, widget = PANNEAUX_WIDGETS[titre] })
		end
		creer("UIScale", { Parent = cadre })
		-- Bande de titre : une teinte de la couleur du panneau qui s'efface vers le bas, et un trait fin dessous
		creer("Frame", { Name = "Bande", Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = couleur, BorderSizePixel = 0, Parent = cadre },
		{ UI.coin(14), creer("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.84),
			NumberSequenceKeypoint.new(1, 1) }) }) })
		creer("Frame", { Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -24, 0, 1), BackgroundColor3 = couleur, BackgroundTransparency = 0.7,
			BorderSizePixel = 0, Parent = cadre })
		-- Coin décoratif lumineux
		creer("Frame", { Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(26, 3), BackgroundColor3 = couleur,
			BorderSizePixel = 0, Parent = cadre }, { UI.coin(2) })
		creer("Frame", { Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(3, 18), BackgroundColor3 = couleur,
			BorderSizePixel = 0, Parent = cadre }, { UI.coin(2) })
		texte({ Text = icone .. "  " .. titre, Font = UI.POLICE_GRAS, TextSize = 12, TextColor3 = couleur,
			Position = UDim2.fromOffset(14, 7), Size = UDim2.new(1, -28, 0, 16), Parent = cadre })
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
	-- Boîtier : une bordure sombre extérieure, comme une vraie coque
	creer("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 4, Transparency = 0.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = W.tablette })

	-- Détails du cadre : caméra frontale et boutons latéraux
	creer("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(7, 7),
		BackgroundColor3 = Color3.fromRGB(20, 30, 50), Parent = W.tablette }, { UI.coin(99), UI.contour(Color3.fromRGB(50, 70, 110), 1, 0) })
	creer("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(3, 3),
		BackgroundColor3 = Color3.fromRGB(90, 130, 200), Parent = W.tablette }, { UI.coin(99) })
	for _, x in { 120, 170 } do
		creer("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(36, 4),
			BackgroundColor3 = Color3.fromRGB(40, 48, 66), Parent = W.tablette }, { UI.coin(2) })
	end

	-- L'écran lui-même
	W.ecran = creer("Frame", { Position = UDim2.fromOffset(16, 16), Size = UDim2.new(1, -32, 1, -32),
		BackgroundColor3 = C.ecran, ClipsDescendants = true, Parent = W.tablette }, { UI.coin(22), UI.contour(Color3.new(0, 0, 0), 2, 0.4) })
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

	-- Matière de l'écran (V6.7) : lignes fines, vignette et reflet du verre, au-dessus des panneaux, sous les voiles
	UI.lignesEcran(W.ecran, 44, 0.94).ZIndex = 30
	UI.vignette(W.ecran, 0.38).ZIndex = 31
	local reflet = creer("Frame", { Name = "Reflet", Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(1, 0.5), BackgroundColor3 = C.blanc,
		BorderSizePixel = 0, ZIndex = 32, Parent = W.ecran }, { UI.coin(22) })
	creer("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.94), NumberSequenceKeypoint.new(0.35, 0.985),
		NumberSequenceKeypoint.new(1, 1) }), Parent = reflet })

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
			Size = UDim2.fromOffset(200, 24), Parent = barreHaut })
		texte({ Text = "TABLETTE DE BORD  ·  V" .. tostring(Config.Version or "?"), Font = UI.POLICE_CODE, TextSize = 11,
			TextColor3 = C.texte2, Position = UDim2.fromOffset(70, 33), Size = UDim2.fromOffset(200, 14), Parent = barreHaut })
		UI.verre(barreHaut, 0.1, 22)

		-- Pastille d'état, à droite de la marque (V6.7 : elle ne chevauche plus les boutons, quelle que soit sa largeur)
		W.pastille = creer("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 290, 0.5, 0),
			Size = UDim2.fromOffset(0, 32), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = C.fond,
			BackgroundTransparency = 0.25, ZIndex = 3, Parent = barreHaut },
		{ UI.coin(99), creer("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 16) }), UI.pile(10, true),
			creer("UISizeConstraint", { MaxSize = Vector2.new(420, 32) }) })
		W.pastille:FindFirstChildOfClass("UIListLayout").VerticalAlignment = Enum.VerticalAlignment.Center
		W.contourPastille = UI.contour(C.vert, 1.5, 0.3)
		W.contourPastille.Parent = W.pastille
		W.pointPastille = creer("Frame", { Size = UDim2.fromOffset(10, 10), BackgroundColor3 = C.vert, LayoutOrder = 1, ZIndex = 4,
			Parent = W.pastille }, { UI.coin(99) })
		W.textePastille = texte({ Text = "Posé", Font = UI.POLICE_GRAS, TextSize = 14, Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2, ZIndex = 4, Parent = W.pastille })
		W.lieuPastille = texte({ Text = "", TextSize = 12, TextColor3 = C.texte2, Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 3, ZIndex = 4, TextTruncate = Enum.TextTruncate.AtEnd, Parent = W.pastille })

		-- Droite, de droite à gauche : fermeture, jauge d'énergie, horloge, puis les boutons Outils / Réglages / Aide
		W.fermer = creer("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0),
			Size = UDim2.fromOffset(38, 38), BackgroundColor3 = Color3.fromRGB(90, 30, 40), Text = "×", Font = UI.POLICE_GRAS,
			TextSize = 24, TextColor3 = C.texte, ZIndex = 3, Parent = barreHaut }, { UI.coin(10), UI.contour(C.rouge, 1, 0.4) })
		W.fermer:SetAttribute("CouleurBase", Color3.fromRGB(90, 30, 40))
		UI.rendreVivant(W.fermer)
		local jauge = creer("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -66, 0.5, 0),
			Size = UDim2.fromOffset(62, 20), BackgroundTransparency = 1, ZIndex = 3, Parent = barreHaut }, { UI.pile(3, true) })
		W.jauge = {}
		for i = 1, 5 do
			W.jauge[i] = creer("Frame", { Size = UDim2.fromOffset(9, 20), BackgroundColor3 = C.vert, LayoutOrder = i, ZIndex = 4,
				Parent = jauge }, { UI.coin(2) })
		end
		W.horloge = texte({ Text = "00:00:00", Font = UI.POLICE_CODE, TextSize = 16, TextColor3 = C.cyan,
			TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -140, 0.5, 0),
			Size = UDim2.fromOffset(90, 20), ZIndex = 3, Parent = barreHaut })
		local function boutonBarre(txt, droite, largeur)
			local b = creer("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -droite, 0.5, 0), Size = UDim2.fromOffset(largeur, 38),
				BackgroundColor3 = C.panneauClair, Text = txt, Font = UI.POLICE_GRAS, TextSize = 13, TextColor3 = C.texte, ZIndex = 3, Parent = barreHaut },
			{ UI.coin(10), UI.contour(C.cyan, 1, 0.5) })
			UI.verre(b, 0.1, 10)
			b:SetAttribute("CouleurBase", C.panneauClair)
			UI.rendreVivant(b)
			return b
		end
		W.btnAide = boutonBarre("?", 242, 38)
		W.btnReglages = boutonBarre("RÉGLAGES", 290, 100)
		W.btnOutils = boutonBarre("◆  OUTILS", 400, 96)
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

		W.liste = creer("ScrollingFrame", { Size = UDim2.new(1, 0, 0, 170), BackgroundColor3 = Color3.fromRGB(4, 10, 24),
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

		-- Protocoles (V6.9) : le mode dans un sélecteur à segments (un seul actif), l'atterrissage invisible à droite
		local protocoles = creer("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = 5,
			Parent = contenu }, { UI.pile(10, true) })
		local modes = UI.selecteurModes(protocoles, {
			{ cle = "classique", nom = "Classique", couleur = C.cyan },
			{ cle = "urgence", nom = "Urgence", couleur = C.orange },
			{ cle = "express", nom = "Rapide", couleur = C.vert },
			{ cle = "sauvetage", nom = "Sauvetage", couleur = UI.couleurMode("Sauvetage") },
			{ cle = "silencieux", nom = "Silencieux", couleur = UI.couleurMode("Silencieux") },
		}, 1, UDim2.new(1, -150, 1, 0))
		local droite = creer("Frame", { Size = UDim2.new(0, 140, 1, 0), BackgroundTransparency = 1, LayoutOrder = 2, Parent = protocoles })
		W.interInvisible = UI.interrupteur(droite, "Invisible", "Déjà camouflé", C.cyan, 1)
		W.modes = modes
		-- État partagé avec le menu rapide
		Commandes.lierInterrupteurs({ classique = modes.classique, urgence = modes.urgence, express = modes.express, sauvetage = modes.sauvetage,
			silencieux = modes.silencieux, invisible = W.interInvisible })

		-- Grands boutons
		local actions = creer("Frame", { Size = UDim2.new(1, 0, 0, 62), BackgroundTransparency = 1, LayoutOrder = 6,
			Parent = contenu }, { UI.pile(12, true) })
		-- Grands boutons partagés avec le menu rapide (UI.boutonPrincipal) : lueur, reflet, barre de progression du voyage
		W.demat = UI.boutonPrincipal(actions, "DÉMATÉRIALISER", "Décoller", 1, UDim2.new(0.5, -6, 1, 0), 12)
		W.remat = UI.boutonPrincipal(actions, "MATÉRIALISER", "Atterrir", 2, UDim2.new(0.5, -6, 1, 0), 12)
		W.demat.Titre.TextSize, W.remat.Titre.TextSize = 15, 15
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

	return { panneaux = panneaux }
end
