-- StarterPlayerScripts > TardisExtrasClient > TabletteTechnicien (ModuleScript)
-- Tablette technicien (V6.7.2) : toutes les informations des systèmes et les commandes RP de l'ingénierie
-- (régulation de l'énergie, de l'air et de la vapeur, énergie, redémarrage à distance, purge, diagnostic),
-- avec des interventions guidées sur les pannes. AUCUNE commande de voyage, de vol, de portes ni de boucliers.
--   • Technicien (non pilote) : touche Y.
--   • Pilote : outil « Ingénierie » de sa tablette (attribut local TardisTabletteTech = nom du TARDIS).
-- Effets visibles par tous à bord : purge de l'air (jets aux grilles), balayage du diagnostic, air vicié.
-- Toutes les commandes sont revérifiées par le serveur (TardisSystemes, action "Tech").
-- (V6.9.12) Zone de chaque panne dans son titre (dossier Zones facultatif), bouton HISTORIQUE (20 dernières pannes :
-- début, fin, « réparé par », publiées par le serveur dans l'attribut HistoriquePannes).
-- (V6.9.13) Interventions guidées des nouvelles pannes (fuite d'air, rotor bloqué, brèche) et outils Scanner et Soudeur.

return function(contexte)
	local C, Config, E, Lighting, Players, RunService = contexte.C, contexte.Config, contexte.E, contexte.Lighting, contexte.Players, contexte.RunService
	local UI, UserInputService, animer, camera, creer, def = contexte.UI, contexte.UserInputService, contexte.animer, contexte.camera, contexte.creer, contexte.def
	local exterieur, interieur, jeSuisDedans, joueur, partTemporaire, remote = contexte.exterieur, contexte.interieur, contexte.jeSuisDedans, contexte.joueur, contexte.partTemporaire, contexte.remote
	local texte, dansInterieur = contexte.texte, contexte.dansInterieur
	local TECH = Config.Technicien or {}
	local S = Config.Systemes or {}

	--------------------------------------------------------------------
	-- Repères de l'intérieur (les mêmes que le serveur, dans le même ordre)
	--------------------------------------------------------------------
	local function partDe(objet)
		if not objet then return nil end
		if objet:IsA("BasePart") then return objet end
		if objet:IsA("Model") then return objet.PrimaryPart or objet:FindFirstChildWhichIsA("BasePart", true) end
		return objet:FindFirstChildWhichIsA("BasePart", true)
	end
	local grilles = Config.grillesDe(interieur) -- (V6.9.12) même recherche que le serveur (TardisConfig)
	local rotorPart = partDe(interieur:FindFirstChild(Config.NomRotor or "Rotor"))
	local consolePart = partDe(interieur:FindFirstChild("Console"))
	local vannePart = partDe(interieur:FindFirstChild("Vanne", true)) or rotorPart
	local levierPart = nil
	do
		local objet = interieur
		for _, nom in (Config.Chemins and Config.Chemins.Alimentation) or {} do objet = objet and objet:FindFirstChild(nom) end
		levierPart = partDe(objet)
	end
	local function aLOutil(nom)
		local sac = joueur:FindFirstChildOfClass("Backpack")
		return (joueur.Character and joueur.Character:FindFirstChild(nom) ~= nil) or (sac and sac:FindFirstChild(nom) ~= nil) or false
	end
	local function distanceA(part)
		local racine = joueur.Character and joueur.Character:FindFirstChild("HumanoidRootPart")
		if not racine or not part then return nil end
		return (racine.Position - part.Position).Magnitude
	end

	--------------------------------------------------------------------
	-- Effets visibles par tous à bord : purge, diagnostic, air vicié
	--------------------------------------------------------------------
	do
		-- Purge : les grilles crachent un jet d'air blanc puissant pendant toute la durée
		local jets = nil
		local function purge()
			local fin = exterieur:GetAttribute("TechPurgeFin")
			if fin and not jets then
				jets = {}
				for _, grille in grilles do
					local point = creer("Attachment", { Position = Vector3.new(0, grille.Size.Y / 2 + 0.2, 0), Parent = grille })
					creer("ParticleEmitter", { Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(Color3.fromRGB(240, 246, 255)),
						Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) }),
						Size = NumberSequence.new(1.5, 5), Lifetime = NumberRange.new(1, 1.8), Speed = NumberRange.new(16, 24), SpreadAngle = Vector2.new(14, 14),
						EmissionDirection = Enum.NormalId.Top, Rate = 70, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-40, 40), Parent = point })
					table.insert(jets, point)
				end
			elseif not fin and jets then
				for _, point in jets do
					for _, e in point:GetChildren() do if e:IsA("ParticleEmitter") then e.Enabled = false end end
					task.delay(2, function() point:Destroy() end)
				end
				jets = nil
			end
		end
		exterieur:GetAttributeChangedSignal("TechPurgeFin"):Connect(purge)
		purge()

		-- Diagnostic : un plan de lumière cyan balaie la salle du sol au plafond
		local boiteCF, boiteTaille = Config.boite(interieur)
		exterieur:GetAttributeChangedSignal("TechDiagnostic"):Connect(function()
			if not jeSuisDedans() then return end
			local plan = partTemporaire({ Name = "TardisBalayage", Material = Enum.Material.Neon, Color = C.cyan, Transparency = 0.82,
				Size = Vector3.new(boiteTaille.X, 0.06, boiteTaille.Z), CFrame = boiteCF * CFrame.new(0, -boiteTaille.Y / 2, 0) })
			animer(plan, 2.4, { CFrame = boiteCF * CFrame.new(0, boiteTaille.Y / 2, 0) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			task.delay(2.4, function() animer(plan, 0.3, { Transparency = 1 }) end)
			task.delay(2.8, function() plan:Destroy() end)
		end)

		-- Air vicié : l'image se ternit doucement pour ceux qui sont à bord
		local voile = creer("ColorCorrectionEffect", { Name = "TardisAirVicie_" .. def.Nom, Parent = Lighting })
		local niveau = 0
		RunService.Heartbeat:Connect(function(dt)
			local seuil = TECH.SeuilAirVicie or 25
			local air = exterieur:GetAttribute("RegulAir") or 100
			local cible = (air < seuil and jeSuisDedans()) and (1 - air / seuil) or 0
			niveau += (cible - niveau) * math.min(dt * 1.5, 1)
			if niveau < 0.002 and cible == 0 then
				if voile.Saturation ~= 0 then voile.Saturation, voile.Contrast, voile.TintColor = 0, 0, Color3.new(1, 1, 1) end
				return
			end
			voile.Saturation = -0.45 * niveau
			voile.Contrast = -0.12 * niveau
			voile.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(215, 220, 200), niveau)
		end)
	end

	--------------------------------------------------------------------
	-- La tablette
	--------------------------------------------------------------------
	-- V6.9.10.6 : charte « Hologramme de confinement » : plaque (INGÉNIERIE, badge TECHNICIEN, nombre de pannes, bande de
	-- danger rouge pendant l'alerte), tableau des pannes PANNE | ZONE | ÉTAT, intervention guidée de la panne choisie,
	-- jauges à segments et boutons à coins coupés.
	local LARGEUR, HAUTEUR = 1040, 664
	local gui = creer("ScreenGui", { Name = "TardisTabletteTechnicien_" .. def.Nom, ResetOnSpawn = false, Enabled = false, DisplayOrder = 21,
		IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = joueur:WaitForChild("PlayerGui") })
	local tablette = UI.panneauCoupe({ Name = "TabletteTechnicien", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(LARGEUR, HAUTEUR), BackgroundColor3 = C.fond, BackgroundTransparency = 0.04, Parent = gui }, { coupe = 16, rayon = 28, balayage = false })
	-- Libère la souris (vue à la première personne) sans voile : le technicien voit la salle et ses outils restent
	-- utilisables hors de la tablette (seule la tablette capte les clics)
	creer("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Modal = true, ZIndex = 0, Parent = tablette })
	local echelle = creer("UIScale", { Parent = tablette })
	UI.decor(creer("UIGradient", { Rotation = 35, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(150, 160, 180)), ColorSequenceKeypoint.new(1, Color3.fromRGB(230, 235, 245)) }), Parent = tablette }), "horsConfinement")
	local ecran = creer("Frame", { Name = "Ecran", Position = UDim2.fromOffset(14, 14), Size = UDim2.new(1, -28, 1, -28), BackgroundColor3 = C.ecran, ClipsDescendants = true,
		Parent = tablette }, { UI.coin(18), UI.decor(UI.contour(Color3.new(0, 0, 0), 2, 0.4), "horsConfinement") })
	UI.fondSelonTheme(ecran, 0, 1)
	UI.decor(creer("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(120, 140, 175)), Parent = ecran }), "horsConfinement")

	-- En-tête : la plaque ; à droite la pastille d'état, l'horloge et la fermeture
	local plaque = UI.plaque(ecran, "Ingénierie", UI.texteBadge("Technicien", "TECHNICIEN"), UI.codeObjet(def) .. "  ·  " .. def.Nom,
		{ position = UDim2.fromOffset(14, 8), taille = UDim2.new(1, -28, 0, 50), badgeColle = true, droite = 470, largeurBande = LARGEUR, exterieur = exterieur })
	local entete = plaque.cadre
	local pastille = creer("Frame", { Name = "Pastille", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -160, 0, 0), Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = C.panneau, BackgroundTransparency = 0.25, ZIndex = 3, Parent = entete },
	{ UI.coin(99, true), creer("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 14) }), UI.pile(8, true), creer("UISizeConstraint", { MaxSize = Vector2.new(300, 30) }) })
	pastille:FindFirstChildOfClass("UIListLayout").VerticalAlignment = Enum.VerticalAlignment.Center
	local contourPastille = UI.contour(C.vert, 1, 0.3)
	contourPastille.Parent = pastille
	local pointPastille = creer("Frame", { Size = UDim2.fromOffset(9, 9), BackgroundColor3 = C.vert, LayoutOrder = 1, ZIndex = 4, Parent = pastille }, { UI.coin(99, true) })
	local textePastille = texte({ Text = "Nominal", Font = UI.POLICE_GRAS, TextSize = 13, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 2, ZIndex = 4, Parent = pastille })
	local horloge = texte({ Text = "00:00:00", Font = UI.POLICE_CODE, TextSize = 15, TextColor3 = C.cyan, TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -54, 0, 5), Size = UDim2.fromOffset(92, 20), ZIndex = 3, Parent = entete })
	local boutonFermer = UI.boutonCoupe(entete, "×", "danger", { Name = "Fermer", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, -4),
		Size = UDim2.fromOffset(44, 40), Font = UI.POLICE_GRAS, TextSize = 22, ZIndex = 3 })

	-- Panneau à coins coupés (même style que la tablette de pilotage)
	local panneaux = {}
	local function panneau(x, y, largeur, hauteur, titre, icone, couleur)
		couleur = couleur or C.ambre
		local cadre = UI.panneauCoupe({ Name = "Panneau", Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(largeur, hauteur), BackgroundColor3 = C.panneau,
			BackgroundTransparency = 0.1, Parent = ecran }, { coupe = 12, rayon = 12, lueur = false, balayage = false, contour = C.ligne, transparenceContour = 0.3 })
		UI.decor(creer("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.blanc, Color3.fromRGB(200, 208, 226)), Parent = cadre }), "horsConfinement")
		creer("UIScale", { Parent = cadre })
		UI.decor(creer("Frame", { Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = couleur, BorderSizePixel = 0, Parent = cadre },
		{ UI.coin(12), creer("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.84), NumberSequenceKeypoint.new(1, 1) }) }) }), "horsConfinement")
		UI.couleurSelonTheme(creer("Frame", { Name = "Filet", Position = UDim2.fromOffset(12, 26), Size = UDim2.new(1, -24, 0, 1), BackgroundColor3 = couleur,
			BackgroundTransparency = 0.6, BorderSizePixel = 0, Parent = cadre }), "BackgroundColor3", couleur, "ligne")
		UI.decor(creer("Frame", { Size = UDim2.fromOffset(24, 3), BackgroundColor3 = couleur, BorderSizePixel = 0, Parent = cadre }, { UI.coin(2) }), "horsConfinement")
		UI.decor(creer("Frame", { Size = UDim2.fromOffset(3, 16), BackgroundColor3 = couleur, BorderSizePixel = 0, Parent = cadre }, { UI.coin(2) }), "horsConfinement")
		UI.couleurSelonTheme(texte({ Name = "TitrePanneau", Text = icone .. "  " .. UI.majuscules(titre), Font = UI.POLICE_TITRE, TextSize = 11, TextColor3 = couleur,
			Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -28, 0, 16), Parent = cadre }), "TextColor3", couleur, "texte")
		local contenu = creer("Frame", { Position = UDim2.fromOffset(12, 34), Size = UDim2.new(1, -24, 1, -44), BackgroundTransparency = 1, Parent = cadre })
		table.insert(panneaux, cadre)
		return cadre, contenu
	end

	-- Bouton à coins coupés de la charte (variante : "principal", "secondaire" ou "danger")
	local function bouton(parent, txt, variante, taille, position)
		local b = UI.boutonCoupe(parent, txt, variante or "secondaire", { Size = taille, Position = position or UDim2.new(), Font = UI.POLICE_GRAS, TextSize = 12 })
		return b
	end
	local function envoyer(commande, donnees)
		donnees = donnees or {}
		donnees.commande = commande
		remote:FireServer("Tech", donnees)
	end

	--------------------------------------------------------------------
	-- Colonne A : systèmes (jauges) et télémétrie
	--------------------------------------------------------------------
	local J = {}
	do
		local _, contenu = panneau(14, 66, 320, 286, "SYSTÈMES", "●", C.vert)
		UI.pile(4).Parent = contenu
		-- Jauges à segments (V6.9.10.6) : 10 segments, la valeur exacte à côté
		local function jauge(cle, nom, ordre)
			J[cle] = UI.jaugeSegments(contenu, nom, { ordre = ordre, nomObjet = "Jauge_" .. cle, hauteurSegment = 8, largeurValeur = 100 })
			J[cle].nom.TextSize = 11
			J[cle].nom.TextColor3 = C.texte2
			J[cle].valeur.TextSize = 12
		end
		jauge("integrite", "INTÉGRITÉ DE LA STRUCTURE", 1)
		jauge("tension", "TENSION (RÉGULATION DE L'ÉNERGIE)", 2)
		jauge("air", "QUALITÉ DE L'AIR", 3)
		jauge("vapeur", "PRESSION DE VAPEUR", 4)
		jauge("bouclier", "ÉNERGIE DU BOUCLIER", 5)
		jauge("salete", "PROPRETÉ DE LA CABINE", 6)
		jauge("voyages", "USURE (VOYAGES AVANT COUPURE)", 7)
	end
	local T = {}
	do
		local _, contenu = panneau(14, 364, 320, 260, "TÉLÉMÉTRIE", "▲", C.cyan)
		UI.pile(1).Parent = contenu
		local function ligne(cle, nom, ordre)
			local l = creer("Frame", { Size = UDim2.new(1, 0, 0, 19), BackgroundTransparency = 1, LayoutOrder = ordre, Parent = contenu })
			texte({ Text = nom, TextSize = 11, TextColor3 = C.texte2, Size = UDim2.new(0.42, 0, 1, 0), Parent = l })
			T[cle] = texte({ Text = "—", Font = UI.POLICE_CODE, TextSize = 11, TextColor3 = C.cyan, TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromScale(0.42, 0), Size = UDim2.new(0.58, 0, 1, 0), Parent = l })
			creer("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = C.ligne,
				BackgroundTransparency = 0.6, BorderSizePixel = 0, Parent = l })
		end
		ligne("etat", "État", 1)
		ligne("lieu", "Lieu", 2)
		ligne("coord", "Coordonnées", 3)
		ligne("alim", "Alimentation", 4)
		ligne("alerte", "Alerte", 5)
		ligne("stab", "Stabilisateur", 6)
		ligne("degat", "Dernier dégât", 7)
		ligne("pilotes", "Pilotes en ligne", 8)
		T.occupants = texte({ Text = "À bord : personne", TextSize = 11, TextColor3 = C.texte, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 9, Parent = contenu })
	end

	--------------------------------------------------------------------
	-- Colonne B : interventions guidées
	--------------------------------------------------------------------
	-- (V6.9.10.6 : tableau des pannes PANNE | ZONE | ÉTAT, puis l'intervention guidée de la panne choisie)
	local tableauPannes, guide
	local historique, boutonHistorique, contenuInterventions -- (V6.9.12)
	do
		local cadre, contenu = panneau(346, 66, 368, 558, "INTERVENTIONS", "◆", C.ambre)
		-- (V6.9.12) le compteur laisse la place au bouton HISTORIQUE, à droite du titre
		local compteur = texte({ Name = "Compteur", Text = "", Font = UI.POLICE_CODE, TextSize = 11, TextColor3 = C.vert, TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, -120, 0, 16), Parent = cadre })
		UI.pile(10).Parent = contenu
		tableauPannes = UI.tableau(contenu, {
			{ cle = "panne", titre = "Panne", largeur = UDim.new(1, -200) },
			{ cle = "zone", titre = "Zone", largeur = UDim.new(0, 100) },
			{ cle = "etat", titre = "État", largeur = UDim.new(0, 100), donnees = true },
		}, { nom = "Pannes", taille = UDim2.new(1, 0, 0, 20 + 44 * 5), ordre = 1 })
		-- Intervention guidée : les étapes de la panne choisie (✓ fait, ▸ en cours, · à faire), l'outil et la cible
		guide = creer("Frame", { Name = "Intervention", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.panneau,
			LayoutOrder = 2, Parent = contenu }, { UI.coin(8), UI.marges(12), UI.pile(5) })
		T.compteurInterventions = compteur
		-- (V6.9.12) Historique des pannes : il prend la place du tableau et de l'intervention guidée tant qu'il est ouvert
		historique = creer("ScrollingFrame", { Name = "HistoriquePannes", Position = contenu.Position, Size = contenu.Size, BackgroundTransparency = 1,
			BorderSizePixel = 0, ScrollBarThickness = 4, ScrollBarImageColor3 = C.ambre, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
			Visible = false, Parent = cadre }, { UI.pile(6) })
		boutonHistorique = bouton(cadre, "Historique", "secondaire", UDim2.fromOffset(96, 20), UDim2.new(1, -110, 0, 4))
		boutonHistorique.Name = "BoutonHistorique"
		boutonHistorique.TextSize = 10
		contenuInterventions = contenu
	end

	--------------------------------------------------------------------
	-- Colonne C : régulation, commandes, outils, journal
	--------------------------------------------------------------------
	local curseurs = {}
	do
		local _, contenu = panneau(726, 66, 286, 214, "RÉGULATION", "◆", C.cyan)
		UI.pile(10).Parent = contenu
		local function curseur(systeme, nom, couleur, ordre, reperes)
			local cadre = creer("Frame", { Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1, LayoutOrder = ordre, Parent = contenu })
			texte({ Text = nom, Font = UI.POLICE_GRAS, TextSize = 11, TextColor3 = C.texte2, Size = UDim2.new(1, -60, 0, 14), Parent = cadre })
			local valeur = texte({ Text = "—", Font = UI.POLICE_CODE, TextSize = 13, TextColor3 = couleur, TextXAlignment = Enum.TextXAlignment.Right,
				Position = UDim2.new(1, -60, 0, 0), Size = UDim2.fromOffset(60, 14), Parent = cadre })
			local piste = creer("TextButton", { Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, Text = "", Parent = cadre })
			local rail = creer("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 7), BackgroundColor3 = C.gris,
				Parent = piste }, { UI.coin(99, true), UI.decor(UI.contour(Color3.new(0, 0, 0), 1, 0.7), "horsConfinement") })
			local remplissage = creer("Frame", { Size = UDim2.fromScale(0.5, 1), BackgroundColor3 = couleur, Parent = rail }, { UI.coin(99, true) })
			for _, repere in reperes or {} do
				creer("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(repere / 100, 0.5), Size = UDim2.fromOffset(2, 15), BackgroundColor3 = C.rouge,
					BorderSizePixel = 0, Parent = rail })
			end
			local poignee = creer("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(18, 18), BackgroundColor3 = C.texte,
				Parent = piste }, { UI.coin(99, true), UI.contour(couleur, 2, 0) })
			local c = { glisse = false, valeur = 50 }
			local function afficher(v)
				c.valeur = v
				remplissage.Size = UDim2.fromScale(v / 100, 1)
				poignee.Position = UDim2.fromScale(v / 100, 0.5)
				valeur.Text = string.format("%d %%", v)
			end
			local function depuisSouris(x)
				local debut, largeur = rail.AbsolutePosition.X, math.max(rail.AbsoluteSize.X, 1)
				return math.floor(math.clamp((x - debut) / largeur, 0, 1) * 20 + 0.5) * 5 -- par pas de 5 %
			end
			piste.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					c.glisse = true
					animer(poignee, 0.12, { Size = UDim2.fromOffset(22, 22) })
					afficher(depuisSouris(input.Position.X))
				end
			end)
			UserInputService.InputChanged:Connect(function(input)
				if c.glisse and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
					afficher(depuisSouris(input.Position.X))
				end
			end)
			UserInputService.InputEnded:Connect(function(input)
				if c.glisse and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
					c.glisse = false
					animer(poignee, 0.12, { Size = UDim2.fromOffset(18, 18) })
					envoyer("Reguler", { systeme = systeme, valeur = c.valeur })
				end
			end)
			function c.regler(v) if not c.glisse then afficher(v) end end
			curseurs[systeme] = c
		end
		curseur("Energie", "ÉNERGIE", C.ambre, 1, { TECH.SousTension or 20, TECH.SurtensionAuDessus or 90 })
		curseur("Air", "AIR (RECYCLAGE)", C.cyan, 2, { TECH.SeuilAirVicie or 25 })
		curseur("Vapeur", "VAPEUR (REFROIDISSEMENT)", Color3.fromRGB(220, 230, 240), 3, {})
	end
	local B = {}
	do
		local _, contenu = panneau(726, 292, 286, 142, "COMMANDES", "■", C.ambre)
		-- (V6.9.4 : 3 colonnes, pour le bouton MAINTENANCE ; V6.9.10.6 : boutons à coins coupés de 44 px, REDÉMARRER en principal)
		creer("UIGridLayout", { CellSize = UDim2.new(1 / 3, -6, 0, UI.JETONS.cible), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = contenu })
		B.energie = bouton(contenu, "ÉNERGIE", "danger", UDim2.new())
		B.redemarrer = bouton(contenu, "REDÉMARRER À DISTANCE", "principal", UDim2.new())
		B.purger = bouton(contenu, "PURGER L'AIR", "secondaire", UDim2.new())
		B.diagnostic = bouton(contenu, "DIAGNOSTIC", "secondaire", UDim2.new())
		B.maintenance = bouton(contenu, "MAINTENANCE", "secondaire", UDim2.new())
		for i, cle in { "energie", "redemarrer", "purger", "diagnostic", "maintenance" } do B[cle].LayoutOrder = i B[cle].TextSize = 11 end
		-- Maintenance (V6.9.4) : immobilise le TARDIS posé (raison : la première de Config.Maintenance.Raisons) ; un second appui la lève
		B.maintenance.Activated:Connect(function()
			if exterieur:GetAttribute("Maintenance") then
				remote:FireServer("Maintenance", { actif = false })
			else
				UI.confirmer(B.maintenance, function() remote:FireServer("Maintenance", { actif = true, raison = 1 }) end)
			end
		end)
		B.energie.Activated:Connect(function() UI.confirmer(B.energie, function() envoyer("Energie") end) end)
		B.redemarrer.Activated:Connect(function() envoyer("Redemarrer") end)
		B.purger.Activated:Connect(function() envoyer("Purger") end)
		B.diagnostic.Activated:Connect(function() envoyer("Diagnostic") end)
	end
	do
		local _, contenu = panneau(726, 446, 286, 88, "OUTILS", "◆", C.vert)
		UI.pile(4, true).Parent = contenu
		-- (V6.9.13) sept boutons : + Scanner et Soudeur
		local liste = { { "Chiffon", "Chiffon" }, { "Visseuse", "Visseuse" }, { "CleMolette", "Molette" }, { "Extincteur", "Extinct." },
			{ "Scanner", "Scan." }, { "Soudeur", "Soud." }, { "Retirer", "Ranger" } }
		for i, info in liste do
			local b = bouton(contenu, info[2], "secondaire", UDim2.new(1 / #liste, -4, 1, 0))
			b.LayoutOrder = i
			b.TextSize = 9
			b.Activated:Connect(function() remote:FireServer("Outil", { outil = info[1] }) end)
		end
	end
	local journal
	do
		local _, contenu = panneau(726, 546, 286, 78, "JOURNAL TECHNIQUE", "■", C.texte2)
		journal = creer("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
			ScrollBarImageColor3 = C.cyan, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = contenu }, { UI.pile(2) })
	end

	-- Matière de l'écran (lignes de balayage ; vignette des anciens thèmes) et notification de la charte
	UI.lignesEcran(ecran, 40, 0.94).ZIndex = 30
	UI.decor(UI.vignette(ecran, 0.35), "horsConfinement").ZIndex = 31
	local notif = UI.notification({ Name = "Notification", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -80), Size = UDim2.fromOffset(460, 0),
		ZIndex = 40, Parent = ecran }, { tailleTexte = 13 })
	local notification = notif.cadre

	--------------------------------------------------------------------
	-- Journal technique
	--------------------------------------------------------------------
	local lignes, compteurLignes = {}, 0
	local function journaliser(message, couleur)
		compteurLignes += 1
		local l = creer("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = -compteurLignes, Parent = journal })
		creer("Frame", { Position = UDim2.fromOffset(0, 3), Size = UDim2.fromOffset(3, 9), BackgroundColor3 = couleur or C.texte2, BorderSizePixel = 0, Parent = l }, { UI.coin(99) })
		texte({ Text = os.date("%H:%M"), Font = UI.POLICE_CODE, TextSize = 10, TextColor3 = C.texte2, Position = UDim2.fromOffset(7, 0), Size = UDim2.fromOffset(36, 14), Parent = l })
		texte({ Text = message, TextSize = 10, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.fromOffset(44, 0), Size = UDim2.new(1, -46, 0, 14), Parent = l })
		table.insert(lignes, 1, l)
		while #lignes > 40 do table.remove(lignes):Destroy() end
	end
	local function suivre(attribut, fonction)
		local avant = exterieur:GetAttribute(attribut)
		exterieur:GetAttributeChangedSignal(attribut):Connect(function()
			local valeur = exterieur:GetAttribute(attribut)
			fonction(valeur, avant)
			avant = valeur
		end)
	end
	suivre("Alimentation", function(v) journaliser(v == false and "Énergie coupée." or "Énergie rétablie.", v == false and C.rouge or C.vert) end)
	suivre("Alerte", function(v) journaliser(v and "Alerte générale." or "Fin de l'alerte.", v and C.rouge or C.vert) end)
	suivre("RedemarrageRequis", function(v) journaliser(v and "Système coupé : redémarrage requis." or "Système redémarré.", v and C.orange or C.vert) end)
	suivre("VapeurSurcharge", function(v) journaliser(v and string.format("Fuite de vapeur : grille n°%d.", v) or "Fuite de vapeur réglée.", v and C.orange or C.vert) end)
	suivre("Incendie", function(v) journaliser(v and "Incendie de console." or "Incendie terminé.", v and C.rouge or C.vert) end)
	suivre("Avarie", function(v) journaliser(v and "AVARIE : intégrité à 0 %." or "Fin de l'avarie.", v and C.rouge or C.vert) end)
	-- (V6.9.13) nouvelles pannes
	suivre("FuiteAir", function(v) journaliser(v ~= nil and "Fuite d'air." or "Fuite d'air colmatée.", v ~= nil and C.orange or C.vert) end)
	suivre("RotorBloque", function(v) journaliser(v and "Rotor bloqué : décollage impossible." or "Rotor débloqué.", v and C.rouge or C.vert) end)
	suivre("Breche", function(v) journaliser(v ~= nil and "Brèche dans la structure." or "Brèche refermée.", v ~= nil and C.rouge or C.vert) end)
	suivre("Catastrophe", function(v) if v then journaliser("Paradoxe : le TARDIS s'est matérialisé dans lui-même.", C.rouge) end end)
	suivre("DernierDegat", function(v)
		local raison, montant = string.match(v or "", "^(.-)\t(%d+)")
		if raison then journaliser(string.format("Dégât : %s (−%s PV).", raison, montant), C.orange) end
	end)
	suivre("TechDernier", function(v)
		local qui, quoi = string.match(v or "", "^(.-)\t(.-)\t")
		if qui then journaliser(quoi .. " (" .. qui .. ").", C.cyan) end
	end)
	suivre("TechPurgeFin", function(v) if v then journaliser("Purge de l'air en cours.", C.cyan) end end)
	journaliser("Tablette technicien prête.", C.vert)

	--------------------------------------------------------------------
	-- Marqueur de localisation (seulement chez celui qui a demandé)
	--------------------------------------------------------------------
	local marqueur = nil -- { cible, highlight, billboard, etiquette }
	local function retirerMarqueur()
		if marqueur then
			marqueur.highlight:Destroy()
			marqueur.billboard:Destroy()
			marqueur = nil
		end
	end
	local function localiser(cible, nom)
		if marqueur and marqueur.cible == cible then retirerMarqueur() return end
		retirerMarqueur()
		if not cible then return end
		local modele = cible.Parent and cible.Parent:IsA("Model") and cible.Parent ~= interieur and cible.Parent or cible
		-- (créés chez ce joueur seulement : les autres ne voient pas le marqueur)
		local highlight = creer("Highlight", { FillColor = C.ambre, OutlineColor = C.ambre, FillTransparency = 0.7, OutlineTransparency = 0,
			DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Parent = modele })
		local billboard = creer("BillboardGui", { Size = UDim2.fromOffset(180, 46), StudsOffsetWorldSpace = Vector3.new(0, cible.Size.Y / 2 + 2, 0), AlwaysOnTop = true,
			LightInfluence = 0, Adornee = cible, Parent = gui })
		local etiquette = texte({ Text = "▼  " .. nom, Font = UI.POLICE_GRAS, TextSize = 14, TextColor3 = C.ambre, TextXAlignment = Enum.TextXAlignment.Center,
			TextStrokeTransparency = 0.4, Size = UDim2.fromScale(1, 1), Parent = billboard })
		marqueur = { cible = cible, highlight = highlight, billboard = billboard, etiquette = etiquette, nom = nom }
	end
	RunService.RenderStepped:Connect(function()
		if not marqueur then return end
		local d = distanceA(marqueur.cible)
		marqueur.etiquette.Text = "▼  " .. marqueur.nom .. (d and string.format("\n%d studs", d) or "")
		marqueur.highlight.FillTransparency = 0.55 + 0.25 * math.sin(os.clock() * 5)
	end)

	--------------------------------------------------------------------
	-- Lecture des pannes : chaque intervention a ses étapes, son outil et sa cible
	--------------------------------------------------------------------
	-- (V6.9.12) Zone d'une pièce de l'intérieur, gardée en mémoire une fois trouvée (les zones ne bougent pas)
	local zonesConnues = {}
	local function zoneDeCible(cible)
		if typeof(cible) ~= "Instance" or not cible:IsDescendantOf(interieur) then return nil end
		if zonesConnues[cible] == nil then zonesConnues[cible] = Config.zoneDe(interieur, cible) or false end
		return zonesConnues[cible] or nil
	end
	local function lirePannes()
		local liste = {}
		local maintenant = workspace:GetServerTimeNow()
		local pv = exterieur:GetAttribute("PointsDeVie") or 100
		if exterieur:GetAttribute("Avarie") then
			table.insert(liste, { cle = "avarie", titre = "AVARIE : STRUCTURE À 0 %", couleur = C.rouge, cible = rotorPart, nomCible = "ROTOR", etapes = {
				{ "Portes ouvertes et tension coupée tant que l'intégrité est à 0 %.", false },
				{ "Va au rotor de la console.", (distanceA(rotorPart) or 99) < 9 },
				{ string.format("Maintiens E 5 s sur le rotor (+%d %% par réparation). Intégrité : %d %%.", math.floor((S.ReparationParMaintien or 1500) / (S.PointsDeVie or 10000) * 100), pv), false },
			} })
		end
		if exterieur:GetAttribute("RedemarrageRequis") then
			local fin = exterieur:GetAttribute("TechRedemarrageFin")
			table.insert(liste, { cle = "redemarrage", titre = "SYSTÈME COUPÉ : REDÉMARRAGE REQUIS", couleur = C.orange, cible = levierPart, nomCible = "LEVIER D'ALIMENTATION", etapes = {
				{ string.format("Coupure de sécurité après %d voyages consécutifs.", S.VoyagesAvantCoupure or 15), true },
				{ string.format("Maintiens E %d s sur le levier d'alimentation…", S.RedemarrageDuree or 10), false },
				{ fin and string.format("…ou redémarrage à distance en cours : %d s.", math.max(0, math.ceil(fin - maintenant))) or "…ou lance « Redémarrer à distance » (Commandes).", fin ~= nil },
			} })
		end
		local index = exterieur:GetAttribute("VapeurSurcharge")
		if index then
			local grille = Config.grilleEnPanne(exterieur, interieur, grilles) -- (V6.9.12) la grille désignée par le serveur
			local avancement = exterieur:GetAttribute("VapeurSurchargeAvancement") or 0
			table.insert(liste, { cle = "vapeur", titre = string.format("FUITE DE VAPEUR : GRILLE N°%d", index), couleur = C.orange, outil = "Visseuse", cible = grille,
				nomCible = string.format("GRILLE N°%d", index), etapes = {
				{ "Prends la visseuse.", aLOutil("Visseuse") },
				{ "Approche-toi de la grille (moins de 8 studs).", (distanceA(grille) or 99) < 8 },
				{ string.format("Clique avec la visseuse en main : réglage %d / 3.", avancement), avancement >= 3 },
			} })
		end
		if exterieur:GetAttribute("Incendie") then
			local eteint = exterieur:GetAttribute("IncendieEteint")
			local reste = eteint and math.max(0, math.ceil(20 - (maintenant - eteint))) or nil
			table.insert(liste, { cle = "incendie", titre = "INCENDIE DE CONSOLE", couleur = C.rouge, outil = eteint and "CleMolette" or "Extincteur",
				cible = eteint and vannePart or consolePart, nomCible = eteint and "VANNE" or "CONSOLE", etapes = {
				{ "Prends l'extincteur.", aLOutil("Extincteur") or eteint ~= nil },
				{ "Éteins les flammes de la console (clique à moins de 12 studs).", eteint ~= nil },
				{ "Prends la clé à molette.", aLOutil("CleMolette") },
				{ reste and string.format("Ferme la vanne (maintiens E 4 s) avant que les flammes repartent : %d s.", reste) or "Ferme la vanne (maintiens E 4 s).", false },
			} })
		end
		-- (V6.9.13) Nouvelles pannes : la pièce désignée par le serveur (Config.pieceEnPanne), sinon le repli
		if exterieur:GetAttribute("FuiteAir") ~= nil then
			local fuite = Config.pieceEnPanne(exterieur, interieur, "FuiteAir") or rotorPart
			local nomFuite = (fuite == rotorPart and "ROTOR") or (table.find(grilles, fuite) and "GRILLE") or "CONDUIT"
			table.insert(liste, { cle = "fuiteair", titre = "FUITE D'AIR", couleur = C.orange, outil = "Visseuse", cible = fuite, nomCible = nomFuite, etapes = {
				{ string.format("L'air baisse de %s %% toutes les %s s tant que la fuite reste ouverte.", tostring(TECH.FuiteAirPerte or 2), tostring(TECH.FuiteAirIntervalle or 5)), true },
				{ "Prends la visseuse ou la clé à molette.", aLOutil("Visseuse") or aLOutil("CleMolette") },
				{ "Approche-toi de la fuite (moins de 8 studs).", (distanceA(fuite) or 99) < 8 },
				{ string.format("Maintiens E %s s sur la fuite, l'outil en main.", tostring(TECH.ColmatageDuree or 4)), false },
			} })
		end
		if exterieur:GetAttribute("RotorBloque") then
			table.insert(liste, { cle = "rotor", titre = "ROTOR BLOQUÉ : DÉCOLLAGE IMPOSSIBLE", couleur = C.rouge, cible = rotorPart, nomCible = "ROTOR", etapes = {
				{ "Le rotor est grippé : ni voyage, ni vol libre, ni saut de poche.", true },
				{ "Va au rotor de la console.", (distanceA(rotorPart) or 99) < 9 },
				{ string.format("Maintiens E %s s sur le rotor pour le débloquer.", tostring(S.DeblocageRotorDuree or 6)), false },
			} })
		end
		if exterieur:GetAttribute("Breche") ~= nil then
			local breche = Config.pieceEnPanne(exterieur, interieur, "Breche") or consolePart or rotorPart
			local total = math.max(math.floor(tonumber(S.SoudureEtapes) or 4), 1)
			local avancement = tonumber(exterieur:GetAttribute("BrecheAvancement")) or 0
			local portee = tonumber(S.SoudureDistance) or 8
			table.insert(liste, { cle = "breche", titre = "BRÈCHE DANS LA STRUCTURE", couleur = C.rouge, outil = "Soudeur", cible = breche, nomCible = "STRUCTURE", etapes = {
				{ "Tant que la brèche est ouverte, la réparation au rotor rend moitié moins.", true },
				{ "Prends le soudeur.", aLOutil("Soudeur") },
				{ string.format("Approche-toi de la brèche (moins de %s studs).", tostring(portee)), (distanceA(breche) or 99) < portee },
				{ string.format("Clique avec le soudeur en main : soudure %d / %d.", math.floor(avancement), total), avancement >= total },
			} })
		end
		if exterieur:GetAttribute("Alimentation") == false and not exterieur:GetAttribute("RedemarrageRequis") and not exterieur:GetAttribute("Avarie") then
			table.insert(liste, { cle = "tension", titre = "HORS TENSION", couleur = C.texte2, cible = levierPart, nomCible = "ALIMENTATION", etapes = {
				{ "Le courant est coupé : lumières de secours, aucun voyage possible.", true },
				{ "Rétablis l'énergie (Commandes › Énergie, ou le levier d'alimentation).", false },
			} })
		end
		local air = exterieur:GetAttribute("RegulAir") or 100
		if air < (TECH.SeuilAirVicie or 25) then
			table.insert(liste, { cle = "air", titre = string.format("AIR VICIÉ : %d %%", air), couleur = C.ambre, etapes = {
				{ "L'air se dégrade quand des personnes sont à bord.", true },
				{ "Lance une purge (Commandes › Purger l'air) : l'air revient à 100 %.", exterieur:GetAttribute("TechPurgeFin") ~= nil },
			} })
		end
		local energie = exterieur:GetAttribute("RegulEnergie") or 80
		if energie > (TECH.SurtensionAuDessus or 90) then
			table.insert(liste, { cle = "surtension", titre = string.format("SURTENSION : %d %%", energie), couleur = C.orange, etapes = {
				{ "Au-dessus du repère rouge, une grille de vapeur peut lâcher à tout moment.", true },
				{ string.format("Baisse la régulation de l'énergie sous %d %%.", TECH.SurtensionAuDessus or 90), false },
			} })
		elseif energie < (TECH.SousTension or 20) and exterieur:GetAttribute("Alimentation") ~= false then
			table.insert(liste, { cle = "soustension", titre = string.format("SOUS-TENSION : %d %%", energie), couleur = C.ambre, etapes = {
				{ "La salle est dans la pénombre.", true },
				{ string.format("Monte la régulation de l'énergie au-dessus de %d %%.", TECH.SousTension or 20), false },
			} })
		end
		if pv < 60 and not exterieur:GetAttribute("Avarie") then
			table.insert(liste, { cle = "integrite", titre = string.format("STRUCTURE ABÎMÉE : %d %%", pv), couleur = C.ambre, cible = rotorPart, nomCible = "ROTOR", etapes = {
				{ "Maintiens E 5 s sur le rotor pour réparer.", false },
			} })
		end
		local salete = exterieur:GetAttribute("Salete") or 0
		if salete >= 40 then
			table.insert(liste, { cle = "salete", titre = string.format("CABINE SALE : %d %%", salete), couleur = C.texte2, outil = "Chiffon", cible = exterieur.PrimaryPart,
				nomCible = "CABINE", etapes = {
				{ "Prends le chiffon.", aLOutil("Chiffon") },
				{ "Sors et frotte la cabine (clique à moins de 10 studs, −15 % par passage).", false },
			} })
		end
		-- (V6.9.12) La zone de la panne (dossier Zones de l'intérieur, sinon par rapport à la console) dans son titre
		for _, panne in liste do
			local zone = zoneDeCible(panne.cible)
			if zone then panne.titre = panne.titre .. "  ·  ZONE " .. UI.majuscules(zone) end
		end
		return liste
	end

	--------------------------------------------------------------------
	-- Tableau des pannes et intervention guidée (V6.9.10.6, charte) : le tableau n'est reconstruit que quand la liste
	-- change ; la panne choisie (ligne jaune, la première par défaut) détaille ses étapes dans l'encadré dessous.
	-- Une panne réglée reste une minute dans le tableau, en vert : RÉPARÉ.
	--------------------------------------------------------------------
	local OUTILS_NOMS = { Visseuse = "Visseuse", Extincteur = "Extincteur", CleMolette = "Clé à molette", Chiffon = "Chiffon",
		Scanner = "Scanner", Soudeur = "Soudeur" } -- (V6.9.13) Scanner, Soudeur
	local COURTS = { avarie = { "Avarie", "Rotor" }, redemarrage = { "Redémarrage", "Alimentation" }, vapeur = { "Fuite de vapeur", "Grille" },
		incendie = { "Incendie", "Console" }, tension = { "Hors tension", "Alimentation" }, air = { "Air vicié", "Grilles" }, surtension = { "Surtension", "Régulation" },
		soustension = { "Sous-tension", "Régulation" }, integrite = { "Structure", "Rotor" }, salete = { "Cabine sale", "Cabine" },
		fuiteair = { "Fuite d'air", "Conduit" }, rotor = { "Rotor bloqué", "Rotor" }, breche = { "Brèche", "Structure" } } -- (V6.9.13)
	local REPARE_DUREE = 60
	local signatureListe, panneChoisie = nil, nil
	local reparees = {} -- { cle, court, zone, fin }
	local lignesPannes = {} -- [cle] = ligne du tableau
	local precedentes = {} -- [cle] = { court, zone } (pannes de la mise à jour précédente)
	local function courtDe(panne)
		local info = COURTS[panne.cle] or { panne.titre, "—" }
		local zone = panne.nomCible and string.gsub(string.lower(panne.nomCible), "^%l", string.upper) or info[2]
		return info[1], zone
	end
	-- État dans le tableau : la panne choisie est celle qu'on traite (EN COURS), les autres attendent (À RÉPARER)
	local function etatPanne(panne)
		if panne.cle == panneChoisie then return "EN COURS", C.ambre end
		return "À RÉPARER", C.rouge
	end
	local GARDER = { UIListLayout = true, UIPadding = true, UICorner = true, UIStroke = true }
	local function construireGuide(liste)
		for _, e in guide:GetChildren() do
			if not GARDER[e.ClassName] then e:Destroy() end
		end
		local panne = nil
		for _, p in liste do if p.cle == panneChoisie then panne = p end end
		if not panne then
			UI.etiquette(guide, "Intervention guidée", { LayoutOrder = 1 })
			texte({ Name = "Nominal", Text = "●  TOUS LES SYSTÈMES SONT NOMINAUX", Font = UI.POLICE_GRAS, TextSize = 13, TextColor3 = C.vert, LayoutOrder = 2, Parent = guide })
			texte({ Text = "Aucune intervention en cours. Surveille l'air et la tension, et lance un diagnostic en cas de doute.", TextSize = 12, TextColor3 = C.texte2,
				TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 3, Parent = guide })
			return
		end
		local court = courtDe(panne)
		UI.etiquette(guide, "Intervention guidée  ·  " .. court, { Name = "TitreGuide", LayoutOrder = 1 })
		texte({ Name = "Titre", Text = "▲  " .. panne.titre, Font = UI.POLICE_GRAS, TextSize = 12, TextColor3 = panne.couleur, TextWrapped = true,
			AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 2, Parent = guide })
		for k in panne.etapes do
			texte({ Name = "Etape" .. k, Text = "", TextSize = 12, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0),
				LayoutOrder = 2 + k, Parent = guide })
		end
		if panne.outil or panne.cible then
			local rangee = creer("Frame", { Size = UDim2.new(1, 0, 0, UI.JETONS.cible), BackgroundTransparency = 1, LayoutOrder = 99, Parent = guide }, { UI.pile(6, true) })
			if panne.outil then
				local b = bouton(rangee, "Prendre : " .. (OUTILS_NOMS[panne.outil] or panne.outil), "principal", UDim2.new(0.5, -3, 1, 0))
				b.Name = "Prendre"
				b.LayoutOrder = 1
				b.TextSize = 11
				b.Activated:Connect(function() remote:FireServer("Outil", { outil = panne.outil }) end)
			end
			if panne.cible then
				local b = bouton(rangee, "Localiser : " .. panne.nomCible, "secondaire", UDim2.new(0.5, -3, 1, 0))
				b.Name = "Localiser"
				b.LayoutOrder = 2
				b.TextSize = 11
				local cible, nom = panne.cible, panne.nomCible
				b.Activated:Connect(function() localiser(cible, nom) end)
			end
		end
	end
	local function majCartes(liste)
		local maintenant = os.clock()
		-- Pannes réglées depuis la dernière mise à jour : RÉPARÉ pendant une minute
		local actuelles = {}
		for _, panne in liste do actuelles[panne.cle] = true end
		for cle, info in precedentes do
			if not actuelles[cle] then table.insert(reparees, { cle = cle, court = info[1], zone = info[2], fin = maintenant + REPARE_DUREE }) end
		end
		table.clear(precedentes)
		for _, panne in liste do
			local court, zone = courtDe(panne)
			precedentes[panne.cle] = { court, zone }
		end
		for i = #reparees, 1, -1 do
			if reparees[i].fin < maintenant or actuelles[reparees[i].cle] then table.remove(reparees, i) end
		end
		local trouvee = false
		for _, panne in liste do if panne.cle == panneChoisie then trouvee = true end end
		if not trouvee then panneChoisie = liste[1] and liste[1].cle or nil end

		local signature = { tostring(panneChoisie) }
		for _, panne in liste do table.insert(signature, panne.cle .. ":" .. tostring(panne.outil) .. ":" .. tostring(panne.cible)) end
		for _, r in reparees do table.insert(signature, "ok:" .. r.cle) end
		signature = table.concat(signature, "|")
		if signature ~= signatureListe then
			signatureListe = signature
			tableauPannes.vider()
			table.clear(lignesPannes)
			for i, panne in liste do
				local court, zone = courtDe(panne)
				local cle = panne.cle
				lignesPannes[cle] = tableauPannes.ajouter({ panne = court, zone = zone, etat = "À RÉPARER" }, { ordre = i, nom = "Panne_" .. cle,
					action = function()
						panneChoisie = cle
						signatureListe = nil
						majCartes(lirePannes())
					end })
			end
			for i, r in reparees do
				tableauPannes.ajouter({ panne = r.court, zone = r.zone, etat = "RÉPARÉ" }, { ordre = 100 + i, nom = "Repare_" .. r.cle, discret = true,
					couleurs = { etat = C.vert } })
			end
			construireGuide(liste)
			-- La cible localisée a disparu (panne réglée) : on retire le marqueur
			if marqueur then
				local encore = false
				for _, panne in liste do if panne.cible == marqueur.cible then encore = true end end
				if not encore then retirerMarqueur() end
			end
		end
		-- État de chaque panne et étapes de la panne choisie, mis à jour à chaque fois (progression, compte à rebours)
		for _, panne in liste do
			local ligne = lignesPannes[panne.cle]
			if ligne then
				local etat, couleur = etatPanne(panne)
				ligne.regler("etat", etat, couleur)
				ligne.choisir(panne.cle == panneChoisie)
			end
			if panne.cle == panneChoisie then
				local premiereAFaire = true
				for k, etape in panne.etapes do
					local l = guide:FindFirstChild("Etape" .. k)
					if l then
						local fait = etape[2]
						local courante = not fait and premiereAFaire
						if courante then premiereAFaire = false end
						l.Text = (fait and "✓  " or (courante and "▸  " or "·  ")) .. etape[1]
						l.TextColor3 = fait and C.vert or (courante and C.ambre or C.texte2)
					end
				end
			end
		end
		T.compteurInterventions.Text = #liste == 0 and "nominal" or (#liste .. " en cours")
		T.compteurInterventions.TextColor3 = #liste == 0 and C.vert or C.orange
		return #liste
	end

	--------------------------------------------------------------------
	-- (V6.9.12) Historique des pannes : « ● TITRE », le détail, puis « 06/11 14:32 → 14:40 · réparé par X » (heure locale)
	--------------------------------------------------------------------
	local HttpService = game:GetService("HttpService")
	local vueHistorique, dernierHistorique = false, false -- false = rien affiché encore (différent de nil : pas d'historique)
	local function horairePanne(entree)
		local debut = tonumber(entree.debut)
		local fin = tonumber(entree.fin)
		local texteHoraire = debut and os.date("%d/%m %H:%M", debut) or "—"
		if not fin then return texteHoraire .. "  ·  en cours" end
		texteHoraire ..= " → " .. os.date("%H:%M", fin)
		if type(entree.par) == "string" and entree.par ~= "" then texteHoraire ..= "  ·  réparé par " .. entree.par end
		return texteHoraire
	end
	local function majHistorique()
		if not vueHistorique then return end
		local json = exterieur:GetAttribute("HistoriquePannes")
		if json == dernierHistorique then return end
		dernierHistorique = json
		for _, e in historique:GetChildren() do
			if not e:IsA("UIListLayout") then e:Destroy() end
		end
		local ok, liste = false, nil
		if type(json) == "string" and json ~= "" then ok, liste = pcall(function() return HttpService:JSONDecode(json) end) end
		if not ok or type(liste) ~= "table" or #liste == 0 then
			texte({ Name = "Vide", Text = "Aucune panne depuis le démarrage du serveur.", TextSize = 12, TextColor3 = C.texte2, TextWrapped = true,
				AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, -8, 0, 0), LayoutOrder = 1, Parent = historique })
			return
		end
		for i, entree in liste do
			if type(entree) == "table" and i <= 20 then
				local couleur = entree.fin and C.vert or C.orange
				local ligne = creer("Frame", { Name = "Entree" .. i, Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.panneau,
					BackgroundTransparency = 0.3, LayoutOrder = i, Parent = historique }, { UI.coin(6), UI.marges(8), UI.pile(2) })
				texte({ Name = "TitreEntree", Text = "●  " .. UI.majuscules(tostring(entree.titre or entree.type or "Panne")), Font = UI.POLICE_GRAS, TextSize = 12,
					TextColor3 = couleur, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 1, Parent = ligne })
				if type(entree.detail) == "string" and entree.detail ~= "" then
					texte({ Name = "Detail", Text = entree.detail, TextSize = 11, TextColor3 = C.texte2, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y,
						Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 2, Parent = ligne })
				end
				texte({ Name = "Horaire", Text = horairePanne(entree), Font = UI.POLICE_CODE, TextSize = 11, TextColor3 = entree.fin and C.texte2 or C.orange,
					TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 3, Parent = ligne })
			end
		end
	end
	boutonHistorique.Activated:Connect(function()
		vueHistorique = not vueHistorique
		contenuInterventions.Visible = not vueHistorique
		historique.Visible = vueHistorique
		boutonHistorique.Text = vueHistorique and "◂ PANNES" or "HISTORIQUE"
		dernierHistorique = false
		majHistorique()
	end)
	exterieur:GetAttributeChangedSignal("HistoriquePannes"):Connect(majHistorique)

	--------------------------------------------------------------------
	-- Mise à jour
	--------------------------------------------------------------------
	local function couleurNiveau(v, bas, haut)
		if v <= bas then return C.rouge end
		if v <= haut then return C.ambre end
		return C.vert
	end
	-- Jauge à segments : p de 0 à 1 (un segment par tranche de 10 %), la valeur exacte écrite à côté
	local function majJauge(cle, p, texteValeur, couleur)
		J[cle].regler(math.clamp(p, 0, 1) * 100, couleur, texteValeur)
	end
	local function majTout()
		local pv = exterieur:GetAttribute("PointsDeVie") or 100
		majJauge("integrite", pv / 100, string.format("%d %%  (%s PV)", pv, tostring(exterieur:GetAttribute("PV") or "?")), couleurNiveau(pv, 20, 50))
		local energie = exterieur:GetAttribute("RegulEnergie") or 80
		local alimente = exterieur:GetAttribute("Alimentation") ~= false
		majJauge("tension", alimente and energie / 100 or 0, alimente and string.format("%d %%", energie) or "COUPÉE",
			(not alimente and C.gris) or ((energie > (TECH.SurtensionAuDessus or 90) or energie < (TECH.SousTension or 20)) and C.rouge) or C.vert)
		local air = exterieur:GetAttribute("RegulAir") or 100
		majJauge("air", air / 100, string.format("%d %%", air), couleurNiveau(air, TECH.SeuilAirVicie or 25, 50))
		local vapeur = exterieur:GetAttribute("RegulVapeur") or 50
		local fuite = exterieur:GetAttribute("VapeurSurcharge") ~= nil
		majJauge("vapeur", fuite and 1 or vapeur / 100, fuite and "FUITE" or string.format("%d %%", vapeur), fuite and C.rouge or C.cyan)
		local bouclierActif = exterieur:GetAttribute("BouclierJoueurs") == true or exterieur:GetAttribute("BouclierBalles") == true or exterieur:GetAttribute("BouclierComplet") == true
		local energieBouclier = exterieur:GetAttribute("BouclierEnergie") or 100
		majJauge("bouclier", bouclierActif and energieBouclier / 100 or 0, bouclierActif and string.format("%d %%", energieBouclier) or "inactif",
			bouclierActif and couleurNiveau(energieBouclier, 15, 40) or C.texte2)
		local salete = exterieur:GetAttribute("Salete") or 0
		majJauge("salete", 1 - salete / 100, string.format("%d %%", 100 - salete), couleurNiveau(100 - salete, 30, 60))
		local avant = S.VoyagesAvantCoupure or 15
		local fait = exterieur:GetAttribute("VoyagesConsecutifs")
		majJauge("voyages", fait and (1 - fait / avant) or 1, fait and string.format("%d / %d", avant - fait, avant) or string.format("max %d", avant),
			exterieur:GetAttribute("RedemarrageRequis") and C.rouge or C.vert)

		-- Télémétrie
		local etat = exterieur:GetAttribute("Etat") or E.Pose
		local libelle = (UI.LIBELLES[etat] or { "?" })[1]
		local modeEnCours = Config.modeDe(exterieur)
		T.etat.Text = libelle .. (etat ~= E.Pose and modeEnCours ~= "Normal" and ("  ·  " .. Config.libelleMode(modeEnCours, true)) or "")
		T.lieu.Text = tostring(exterieur:GetAttribute("Position") or "?")
		local p = exterieur:GetPivot().Position
		T.coord.Text = string.format("%d, %d, %d", p.X, p.Y, p.Z)
		T.alim.Text = alimente and "NOMINALE" or "COUPÉE"
		T.alim.TextColor3 = alimente and C.vert or C.rouge
		T.alerte.Text = exterieur:GetAttribute("Alerte") and "ACTIVE" or "aucune"
		T.alerte.TextColor3 = exterieur:GetAttribute("Alerte") and C.rouge or C.texte2
		T.stab.Text = exterieur:GetAttribute("Stabilisateur") ~= false and "actif" or "coupé"
		local raison, montant = string.match(exterieur:GetAttribute("DernierDegat") or "", "^(.-)\t(%d+)")
		T.degat.Text = raison and string.format("%s (−%s)", raison, montant) or "—"
		local pilotes, occupants = {}, {}
		for _, autre in Players:GetPlayers() do
			if autre:GetAttribute("TardisPilote_" .. def.Nom) == true then table.insert(pilotes, autre.DisplayName) end
			local racine = autre.Character and autre.Character:FindFirstChild("HumanoidRootPart")
			if racine and dansInterieur(racine.Position) then table.insert(occupants, autre.DisplayName) end
		end
		T.pilotes.Text = #pilotes > 0 and tostring(#pilotes) .. "  ·  " .. table.concat(pilotes, ", ") or "aucun"
		T.occupants.Text = #occupants == 0 and "À bord : personne" or ("À bord (" .. #occupants .. ") : " .. table.concat(occupants, "  ·  "))

		-- Curseurs
		for systeme, c in curseurs do c.regler(exterieur:GetAttribute("Regul" .. systeme) or 50) end

		-- Commandes (boutons à variante : couper l'énergie = danger, la rétablir = principal ; maintenance en cours = danger)
		if not B.energie:GetAttribute("EnAttenteConfirmation") then
			B.energie.Text = alimente and "COUPER L'ÉNERGIE" or "RÉTABLIR L'ÉNERGIE"
		end
		local varianteEnergie = alimente and "danger" or "principal"
		if B.energie:GetAttribute("Variante") ~= varianteEnergie then
			B.energie:SetAttribute("Variante", varianteEnergie)
			UI.peindreBouton(B.energie)
		end
		local finRedemarrage = exterieur:GetAttribute("TechRedemarrageFin")
		local requis = exterieur:GetAttribute("RedemarrageRequis") == true
		if not B.maintenance:GetAttribute("EnAttenteConfirmation") then
			local enMaintenance = exterieur:GetAttribute("Maintenance") ~= nil
			B.maintenance.Text = enMaintenance and "LEVER LA MAINTENANCE" or "MAINTENANCE"
			local varianteMaintenance = enMaintenance and "danger" or "secondaire"
			if B.maintenance:GetAttribute("Variante") ~= varianteMaintenance then
				B.maintenance:SetAttribute("Variante", varianteMaintenance)
				UI.peindreBouton(B.maintenance)
			end
		end
		B.redemarrer.Text = finRedemarrage and string.format("REDÉMARRAGE… %d s", math.max(0, math.ceil(finRedemarrage - workspace:GetServerTimeNow())))
			or "REDÉMARRER À DISTANCE"
		UI.setDisponible(B.redemarrer, requis and not finRedemarrage, C.panneauClair)
		local finPurge = exterieur:GetAttribute("TechPurgeFin")
		B.purger.Text = finPurge and string.format("PURGE… %d s", math.max(0, math.ceil(finPurge - workspace:GetServerTimeNow()))) or "PURGER L'AIR"
		UI.setDisponible(B.purger, alimente and not finPurge, C.panneauClair)

		-- Interventions et pastille
		local liste = lirePannes()
		local nombre = majCartes(liste)
		local critique = exterieur:GetAttribute("Avarie") or exterieur:GetAttribute("Incendie") or requis
			or exterieur:GetAttribute("RotorBloque") or exterieur:GetAttribute("Breche") ~= nil -- (V6.9.13)
		local couleur = (nombre == 0 and C.vert) or (critique and C.rouge) or C.orange
		textePastille.Text = nombre == 0 and "Systèmes nominaux" or (nombre .. (nombre > 1 and " interventions" or " intervention"))
		pointPastille.BackgroundColor3 = couleur
		contourPastille.Color = couleur
		-- Plaque : « OBJ. TARDIS-01 · 2 PANNES »
		plaque.majSousLigne(UI.codeObjet(def) .. "  ·  " .. (nombre == 0 and "SYSTÈMES NOMINAUX" or (nombre .. (nombre > 1 and " PANNES" or " PANNE"))))
	end

	--------------------------------------------------------------------
	-- Ouverture et fermeture
	--------------------------------------------------------------------
	local ouvert = false
	local function accesTechnicien()
		return joueur:GetAttribute("TardisTechnicien_" .. def.Nom) == true or joueur:GetAttribute("TardisPilote_" .. def.Nom) == true
	end
	local function majEchelle()
		local taille = camera.ViewportSize
		echelle.Scale = math.clamp(math.min(taille.X * 0.94 / LARGEUR, taille.Y * 0.9 / HAUTEUR), 0.4, 1.2) * UI.tailleInterface()
	end
	local function ouvrir()
		if ouvert or not accesTechnicien() then return end
		ouvert = true
		gui.Enabled = true
		majEchelle()
		majTout()
		local base = echelle.Scale
		echelle.Scale = base * 0.88
		tablette.Position = UDim2.fromScale(0.5, 0.56)
		-- (V6.9.10.6 : sans inclinaison : un cadre tourné ne coupe plus ce qui dépasse, la bande de danger déborderait)
		animer(echelle, 0.5, { Scale = base }, Enum.EasingStyle.Back)
		animer(tablette, 0.5, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Back)
		for i, cadre in panneaux do
			local e = cadre:FindFirstChildOfClass("UIScale")
			e.Scale = 0.92
			animer(e, 0.4, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0.1 + i * 0.04)
		end
		UI.son("Notification")
	end
	local function fermer()
		if not ouvert then return end
		ouvert = false
		joueur:SetAttribute("TardisTabletteTech", nil)
		animer(tablette, 0.22, { Position = UDim2.fromScale(0.5, 0.56) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.23, function() if not ouvert then gui.Enabled = false end end)
	end
	boutonFermer.Activated:Connect(fermer)
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(function() if ouvert then majEchelle() end end)
	-- Technicien (non pilote) : touche Y. Pilote : outil « Ingénierie » de sa tablette.
	UserInputService.InputBegan:Connect(function(input, traite)
		if traite then return end
		if input.KeyCode ~= UI.touche("tablette", Enum.KeyCode.Y) then return end
		if joueur:GetAttribute("TardisPilote_" .. def.Nom) == true then
			if ouvert then fermer() end -- Y sert à la tablette de pilotage
			return
		end
		if joueur:GetAttribute("TardisTechnicien_" .. def.Nom) ~= true then return end
		-- Avec plusieurs TARDIS, seul celui du technicien répond
		local mien = Config.tardisDuJoueur(joueur)
		if mien and mien.Nom ~= def.Nom then return end
		if ouvert then fermer() else ouvrir() end
	end)
	-- Appareil sans clavier (V6.8.1) : un bouton au bord gauche pour le technicien qui n'est pas pilote
	if Config.BoutonsTactiles ~= false and UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		local guiTactile = creer("ScreenGui", { Name = "TardisBoutonTechnicien_" .. def.Nom, ResetOnSpawn = false, Enabled = false,
			Parent = joueur:WaitForChild("PlayerGui") })
		local b = creer("TextButton", { Name = "BoutonTactile", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.38, 0), Size = UDim2.fromOffset(52, 52),
			BackgroundColor3 = C.fond, BackgroundTransparency = 0.15, Text = "", Parent = guiTactile }, { UI.coin(99), UI.contour(C.cyan, 1.5, 0.3) })
		UI.decouper(b, 10, { contour = C.cyan })
		texte({ Text = "Y", Font = UI.POLICE_TITRE, TextSize = 18, TextColor3 = C.cyan, TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 22), Parent = b })
		texte({ Text = "ingénierie", Font = UI.POLICE_CODE, TextSize = 9, TextColor3 = C.texte2, TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, 31), Size = UDim2.new(1, 0, 0, 12), Parent = b })
		b:SetAttribute("CouleurBase", C.fond)
		UI.rendreVivant(b)
		b.Activated:Connect(function() if ouvert then fermer() else ouvrir() end end)
		local function majBouton()
			local mien = Config.tardisDuJoueur(joueur)
			guiTactile.Enabled = joueur:GetAttribute("TardisTechnicien_" .. def.Nom) == true and joueur:GetAttribute("TardisPilote_" .. def.Nom) ~= true
				and (mien == nil or mien.Nom == def.Nom)
		end
		joueur:GetAttributeChangedSignal("TardisTechnicien_" .. def.Nom):Connect(majBouton)
		joueur:GetAttributeChangedSignal("TardisPilote_" .. def.Nom):Connect(majBouton)
		majBouton()
	end
	joueur:GetAttributeChangedSignal("TardisTabletteTech"):Connect(function()
		if joueur:GetAttribute("TardisTabletteTech") == def.Nom then ouvrir() end
	end)
	joueur:GetAttributeChangedSignal("TardisTechnicien_" .. def.Nom):Connect(function() if not accesTechnicien() then fermer() end end)

	-- Réponses du serveur : notification sur la tablette
	local jeton = 0
	remote.OnClientEvent:Connect(function(message, reussi)
		if not ouvert or typeof(message) ~= "string" or string.sub(message, 1, 2) == "__" then return end
		jeton += 1
		local moi = jeton
		-- Charte : badge TARDIS, REFUSÉ (échec) ou ALERTE (message d'alerte, bande rouge)
		notif.regler(message, (not reussi and "refus") or (string.find(string.lower(message), "alerte", 1, true) and "alerte") or "info")
		notification.Visible = true
		notification.Position = UDim2.new(0.5, 0, 0, -80)
		animer(notification, 0.35, { Position = UDim2.new(0.5, 0, 0, 62) }, Enum.EasingStyle.Back)
		task.delay(4, function()
			if moi ~= jeton then return end
			animer(notification, 0.3, { Position = UDim2.new(0.5, 0, 0, -80) }).Completed:Wait()
			if moi == jeton then notification.Visible = false end
		end)
	end)

	-- Mises à jour (V6.9.10.6 : plus de roue ni de dégradé qui tournent : le décor de la charte est posé une fois)
	local prochaine = 0
	RunService.RenderStepped:Connect(function()
		if not ouvert then return end
		local t = os.clock()
		horloge.Text = os.date("%H:%M:%S")
		if t >= prochaine then
			prochaine = t + 0.25
			majTout()
		end
	end)

	return {}
end
