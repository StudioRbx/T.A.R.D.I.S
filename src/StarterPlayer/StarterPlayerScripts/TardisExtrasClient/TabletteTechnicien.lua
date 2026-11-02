-- StarterPlayerScripts > TardisExtrasClient > TabletteTechnicien (ModuleScript)
-- Tablette technicien (V6.7.2) : toutes les informations des systèmes et les commandes RP de l'ingénierie
-- (régulation de l'énergie, de l'air et de la vapeur, énergie, redémarrage à distance, purge, diagnostic),
-- avec des interventions guidées sur les pannes. AUCUNE commande de voyage, de vol, de portes ni de boucliers.
--   • Technicien (non pilote) : touche Y.
--   • Pilote : outil « Ingénierie » de sa tablette (attribut local TardisTabletteTech = nom du TARDIS).
-- Effets visibles par tous à bord : purge de l'air (jets aux grilles), balayage du diagnostic, air vicié.
-- Toutes les commandes sont revérifiées par le serveur (TardisSystemes, action "Tech").

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
	local grilles = {}
	for _, objet in interieur:GetDescendants() do
		if objet:IsA("BasePart") and (objet.Name == "Grille" or (objet.Parent and objet.Parent.Name == "Grilles")) then table.insert(grilles, objet) end
	end
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
		local boiteCF, boiteTaille = interieur:GetBoundingBox()
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
	local LARGEUR, HAUTEUR = 1040, 664
	local gui = creer("ScreenGui", { Name = "TardisTabletteTechnicien_" .. def.Nom, ResetOnSpawn = false, Enabled = false, DisplayOrder = 21,
		IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = joueur:WaitForChild("PlayerGui") })
	local tablette = creer("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(LARGEUR, HAUTEUR),
		BackgroundColor3 = C.fond, Parent = gui }, { UI.coin(28), UI.contour(C.ambre, 2, 0.35) })
	-- Libère la souris (vue à la première personne) sans voile : le technicien voit la salle et ses outils restent
	-- utilisables hors de la tablette (seule la tablette capte les clics)
	creer("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Modal = true, ZIndex = 0, Parent = tablette })
	local echelle = creer("UIScale", { Parent = tablette })
	creer("UIGradient", { Rotation = 35, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(150, 160, 180)), ColorSequenceKeypoint.new(1, Color3.fromRGB(230, 235, 245)) }), Parent = tablette })
	creer("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 4, Transparency = 0.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = tablette })
	local ecran = creer("Frame", { Position = UDim2.fromOffset(14, 14), Size = UDim2.new(1, -28, 1, -28), BackgroundColor3 = C.ecran, ClipsDescendants = true,
		Parent = tablette }, { UI.coin(18), UI.contour(Color3.new(0, 0, 0), 2, 0.4) })
	creer("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(120, 140, 175)), Parent = ecran })

	-- En-tête
	local entete = creer("Frame", { Size = UDim2.new(1, 0, 0, 54), BackgroundColor3 = C.blanc, Parent = ecran }, { UI.coin(18) })
	local degrade = creer("UIGradient", { Color = UI.degradeEntete(), Parent = entete })
	creer("Frame", { Position = UDim2.new(0, 0, 1, -18), Size = UDim2.new(1, 0, 0, 18), BackgroundColor3 = C.blanc, BorderSizePixel = 0, Parent = entete },
	{ creer("UIGradient", { Color = UI.degradeEntete() }) })
	UI.verre(entete, 0.1, 18)
	creer("Frame", { Position = UDim2.new(0, 0, 0, 54), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = C.ambre, BackgroundTransparency = 0.3, BorderSizePixel = 0, Parent = ecran })
	local roue = creer("Frame", { Position = UDim2.fromOffset(14, 9), Size = UDim2.fromOffset(36, 36), BackgroundTransparency = 1, ZIndex = 3, Parent = entete },
	{ UI.coin(99), UI.contour(C.ambre, 2, 0.1) })
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		creer("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5 + math.cos(a) * 0.5, 0, 0.5 + math.sin(a) * 0.5, 0), Rotation = math.deg(a),
			Size = UDim2.fromOffset(7, 4), BackgroundColor3 = C.ambre, BorderSizePixel = 0, ZIndex = 4, Parent = roue })
	end
	creer("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = C.cyan, ZIndex = 4,
		Parent = roue }, { UI.coin(99) })
	texte({ Text = "T.A.R.D.I.S.  ·  INGÉNIERIE", Font = UI.POLICE_TITRE, TextSize = 17, Position = UDim2.fromOffset(62, 8), Size = UDim2.fromOffset(330, 22), ZIndex = 3, Parent = entete })
	texte({ Text = "TABLETTE TECHNICIEN  ·  " .. def.Nom .. "  ·  V" .. tostring(Config.Version or "?"), Font = UI.POLICE_CODE, TextSize = 10, TextColor3 = C.texte2,
		Position = UDim2.fromOffset(62, 31), Size = UDim2.fromOffset(330, 14), ZIndex = 3, Parent = entete })
	local pastille = creer("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 410, 0.5, 0), Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = C.fond, BackgroundTransparency = 0.25, ZIndex = 3, Parent = entete },
	{ UI.coin(99), creer("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 14) }), UI.pile(8, true), creer("UISizeConstraint", { MaxSize = Vector2.new(360, 30) }) })
	pastille:FindFirstChildOfClass("UIListLayout").VerticalAlignment = Enum.VerticalAlignment.Center
	local contourPastille = UI.contour(C.vert, 1.5, 0.3)
	contourPastille.Parent = pastille
	local pointPastille = creer("Frame", { Size = UDim2.fromOffset(9, 9), BackgroundColor3 = C.vert, LayoutOrder = 1, ZIndex = 4, Parent = pastille }, { UI.coin(99) })
	local textePastille = texte({ Text = "Nominal", Font = UI.POLICE_GRAS, TextSize = 13, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 2, ZIndex = 4, Parent = pastille })
	local horloge = texte({ Text = "00:00:00", Font = UI.POLICE_CODE, TextSize = 15, TextColor3 = C.cyan, TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -64, 0.5, 0), Size = UDim2.fromOffset(90, 20), ZIndex = 3, Parent = entete })
	local boutonFermer = creer("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = Color3.fromRGB(90, 30, 40), Text = "×", Font = UI.POLICE_GRAS, TextSize = 22, TextColor3 = C.texte, ZIndex = 3, Parent = entete },
	{ UI.coin(10), UI.contour(C.rouge, 1, 0.4) })
	boutonFermer:SetAttribute("CouleurBase", Color3.fromRGB(90, 30, 40))
	UI.rendreVivant(boutonFermer)

	-- Panneau à bande de titre (même style que la tablette de pilotage)
	local panneaux = {}
	local function panneau(x, y, largeur, hauteur, titre, icone, couleur)
		couleur = couleur or C.ambre
		local cadre = creer("Frame", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(largeur, hauteur), BackgroundColor3 = C.panneau,
			BackgroundTransparency = 0.1, Parent = ecran }, { UI.coin(12), UI.contour(C.bleu, 1, 0.35),
			creer("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.blanc, Color3.fromRGB(200, 208, 226)) }) })
		creer("UIScale", { Parent = cadre })
		creer("Frame", { Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = couleur, BorderSizePixel = 0, Parent = cadre },
		{ UI.coin(12), creer("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.84), NumberSequenceKeypoint.new(1, 1) }) }) })
		creer("Frame", { Position = UDim2.fromOffset(12, 26), Size = UDim2.new(1, -24, 0, 1), BackgroundColor3 = couleur, BackgroundTransparency = 0.7, BorderSizePixel = 0, Parent = cadre })
		creer("Frame", { Size = UDim2.fromOffset(24, 3), BackgroundColor3 = couleur, BorderSizePixel = 0, Parent = cadre }, { UI.coin(2) })
		creer("Frame", { Size = UDim2.fromOffset(3, 16), BackgroundColor3 = couleur, BorderSizePixel = 0, Parent = cadre }, { UI.coin(2) })
		texte({ Text = icone .. "  " .. titre, Font = UI.POLICE_GRAS, TextSize = 12, TextColor3 = couleur, Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -28, 0, 16), Parent = cadre })
		local contenu = creer("Frame", { Position = UDim2.fromOffset(12, 34), Size = UDim2.new(1, -24, 1, -44), BackgroundTransparency = 1, Parent = cadre })
		table.insert(panneaux, cadre)
		return cadre, contenu
	end

	local function bouton(parent, txt, couleur, taille, position)
		local b = creer("TextButton", { Size = taille, Position = position or UDim2.new(), BackgroundColor3 = couleur or C.panneauClair, Text = txt, Font = UI.POLICE_GRAS,
			TextSize = 12, TextColor3 = C.texte, TextWrapped = true, Parent = parent }, { UI.coin(9), UI.contour(C.cyan, 1, 0.55) })
		UI.verre(b, 0.1, 9)
		b:SetAttribute("CouleurBase", b.BackgroundColor3)
		UI.rendreVivant(b)
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
		UI.pile(6).Parent = contenu
		local function jauge(cle, nom, ordre)
			local cadre = creer("Frame", { Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, LayoutOrder = ordre, Parent = contenu })
			texte({ Text = nom, Font = UI.POLICE_GRAS, TextSize = 11, TextColor3 = C.texte2, Size = UDim2.new(1, -90, 0, 14), Parent = cadre })
			local valeur = texte({ Text = "—", Font = UI.POLICE_CODE, TextSize = 12, TextColor3 = C.vert, TextXAlignment = Enum.TextXAlignment.Right,
				Position = UDim2.new(1, -90, 0, 0), Size = UDim2.fromOffset(90, 14), Parent = cadre })
			local fond = creer("Frame", { Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 9), BackgroundColor3 = C.gris, Parent = cadre },
			{ UI.coin(99), UI.contour(Color3.new(0, 0, 0), 1, 0.7) })
			local barre = creer("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.vert, Parent = fond }, { UI.coin(99) })
			J[cle] = { valeur = valeur, barre = barre }
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
			creer("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = C.bleu,
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
	local listeInterventions
	do
		local cadre, contenu = panneau(346, 66, 368, 558, "INTERVENTIONS", "◆", C.ambre)
		local compteur = texte({ Name = "Compteur", Text = "", Font = UI.POLICE_CODE, TextSize = 11, TextColor3 = C.vert, TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, -14, 0, 16), Parent = cadre })
		listeInterventions = creer("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
			ScrollBarImageColor3 = C.ambre, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = contenu }, { UI.pile(8) })
		T.compteurInterventions = compteur
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
				Parent = piste }, { UI.coin(99), UI.contour(Color3.new(0, 0, 0), 1, 0.7) })
			local remplissage = creer("Frame", { Size = UDim2.fromScale(0.5, 1), BackgroundColor3 = couleur, Parent = rail }, { UI.coin(99) })
			for _, repere in reperes or {} do
				creer("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(repere / 100, 0.5), Size = UDim2.fromOffset(2, 15), BackgroundColor3 = C.rouge,
					BorderSizePixel = 0, Parent = rail })
			end
			local poignee = creer("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(18, 18), BackgroundColor3 = C.texte,
				Parent = piste }, { UI.coin(99), UI.contour(couleur, 2, 0) })
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
		local _, contenu = panneau(726, 292, 286, 138, "COMMANDES", "■", C.ambre)
		creer("UIGridLayout", { CellSize = UDim2.new(0.5, -4, 0, 40), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = contenu })
		B.energie = bouton(contenu, "ÉNERGIE", C.panneauClair, UDim2.new())
		B.redemarrer = bouton(contenu, "REDÉMARRER À DISTANCE", C.panneauClair, UDim2.new())
		B.purger = bouton(contenu, "PURGER L'AIR", C.panneauClair, UDim2.new())
		B.diagnostic = bouton(contenu, "DIAGNOSTIC", C.panneauClair, UDim2.new())
		for i, cle in { "energie", "redemarrer", "purger", "diagnostic" } do B[cle].LayoutOrder = i end
		B.energie.Activated:Connect(function() UI.confirmer(B.energie, function() envoyer("Energie") end) end)
		B.redemarrer.Activated:Connect(function() envoyer("Redemarrer") end)
		B.purger.Activated:Connect(function() envoyer("Purger") end)
		B.diagnostic.Activated:Connect(function() envoyer("Diagnostic") end)
	end
	do
		local _, contenu = panneau(726, 442, 286, 74, "OUTILS", "◆", C.vert)
		UI.pile(5, true).Parent = contenu
		for i, info in { { "Chiffon", "Chiffon" }, { "Visseuse", "Visseuse" }, { "CleMolette", "Clé" }, { "Extincteur", "Extinct." }, { "Retirer", "Ranger" } } do
			local b = bouton(contenu, info[2], info[1] == "Retirer" and C.fond or C.panneauClair, UDim2.new(0.2, -4, 1, 0))
			b.LayoutOrder = i
			b.TextSize = 11
			b.Activated:Connect(function() remote:FireServer("Outil", { outil = info[1] }) end)
		end
	end
	local journal
	do
		local _, contenu = panneau(726, 528, 286, 96, "JOURNAL TECHNIQUE", "■", C.texte2)
		journal = creer("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
			ScrollBarImageColor3 = C.ambre, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = contenu }, { UI.pile(2) })
	end

	-- Matière de l'écran et notification
	UI.lignesEcran(ecran, 40, 0.94).ZIndex = 30
	UI.vignette(ecran, 0.35).ZIndex = 31
	local notification = creer("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -80), Size = UDim2.fromOffset(440, 0),
		AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.panneauClair, Visible = false, ZIndex = 40, Parent = ecran }, { UI.coin(12), UI.marges(12) })
	local contourNotif = UI.contour(C.vert, 1.5, 0)
	contourNotif.Parent = notification
	local texteNotif = texte({ Text = "", TextSize = 13, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 0), ZIndex = 41, Parent = notification })

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
			local grille = grilles[index]
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
		return liste
	end

	--------------------------------------------------------------------
	-- Cartes d'intervention (reconstruites seulement quand la liste change)
	--------------------------------------------------------------------
	local cartes, signatureListe = {}, nil
	local OUTILS_NOMS = { Visseuse = "Visseuse", Extincteur = "Extincteur", CleMolette = "Clé à molette", Chiffon = "Chiffon" }
	local function construireCartes(liste)
		for _, carte in cartes do carte.cadre:Destroy() end
		table.clear(cartes)
		if #liste == 0 then
			local carte = UI.carte(listeInterventions, 1, 6, nil, C.vert)
			texte({ Text = "●  TOUS LES SYSTÈMES SONT NOMINAUX", Font = UI.POLICE_GRAS, TextSize = 12, TextColor3 = C.vert, LayoutOrder = 1, Parent = carte })
			texte({ Text = "Aucune intervention en cours. Surveille l'air et la tension, et lance un diagnostic en cas de doute.", TextSize = 11, TextColor3 = C.texte2,
				TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 2, Parent = carte })
			table.insert(cartes, { cadre = carte, lignes = {} })
			return
		end
		for i, panne in liste do
			local carte = UI.carte(listeInterventions, i, 5, nil, panne.couleur)
			texte({ Text = "▲  " .. panne.titre, Font = UI.POLICE_GRAS, TextSize = 12, TextColor3 = panne.couleur, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 1, Parent = carte })
			local lignesEtapes = {}
			for k in panne.etapes do
				lignesEtapes[k] = texte({ Text = "", TextSize = 11, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0),
					LayoutOrder = 1 + k, Parent = carte })
			end
			if panne.outil or panne.cible then
				local rangee = creer("Frame", { Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, LayoutOrder = 99, Parent = carte }, { UI.pile(6, true) })
				if panne.outil then
					local b = bouton(rangee, "Prendre : " .. (OUTILS_NOMS[panne.outil] or panne.outil), C.panneauClair, UDim2.new(0.5, -3, 1, 0))
					b.LayoutOrder = 1
					b.TextSize = 11
					b.Activated:Connect(function() remote:FireServer("Outil", { outil = panne.outil }) end)
				end
				if panne.cible then
					local b = bouton(rangee, "Localiser : " .. panne.nomCible, C.fond, UDim2.new(0.5, -3, 1, 0))
					b.LayoutOrder = 2
					b.TextSize = 11
					local cible, nom = panne.cible, panne.nomCible
					b.Activated:Connect(function() localiser(cible, nom) end)
				end
			end
			table.insert(cartes, { cadre = carte, lignes = lignesEtapes })
		end
	end
	local function majCartes(liste)
		local signature = {}
		for _, panne in liste do table.insert(signature, panne.cle .. ":" .. tostring(panne.outil) .. ":" .. tostring(panne.cible)) end
		signature = table.concat(signature, "|")
		if signature ~= signatureListe then
			signatureListe = signature
			construireCartes(liste)
			-- La cible localisée a disparu (panne réglée) : on retire le marqueur
			if marqueur then
				local encore = false
				for _, panne in liste do if panne.cible == marqueur.cible then encore = true end end
				if not encore then retirerMarqueur() end
			end
		end
		-- Étapes : texte et coche mis à jour à chaque fois (progression, compte à rebours)
		for i, panne in liste do
			local carte = cartes[i]
			if carte then
				local premiereAFaire = true
				for k, etape in panne.etapes do
					local l = carte.lignes[k]
					if l then
						local fait = etape[2]
						local courante = not fait and premiereAFaire
						if courante then premiereAFaire = false end
						l.Text = (fait and "✓  " or (courante and "►  " or "○  ")) .. etape[1]
						l.TextColor3 = fait and C.vert or (courante and C.texte or C.texte2)
					end
				end
			end
		end
		T.compteurInterventions.Text = #liste == 0 and "nominal" or (#liste .. " en cours")
		T.compteurInterventions.TextColor3 = #liste == 0 and C.vert or C.orange
		return #liste
	end

	--------------------------------------------------------------------
	-- Mise à jour
	--------------------------------------------------------------------
	local function couleurNiveau(v, bas, haut)
		if v <= bas then return C.rouge end
		if v <= haut then return C.ambre end
		return C.vert
	end
	local function majJauge(cle, p, texteValeur, couleur)
		J[cle].barre.Size = UDim2.fromScale(math.clamp(p, 0, 1), 1)
		J[cle].barre.BackgroundColor3 = couleur
		J[cle].valeur.Text = texteValeur
		J[cle].valeur.TextColor3 = couleur
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

		-- Commandes
		if not B.energie:GetAttribute("EnAttenteConfirmation") then
			B.energie.Text = alimente and "COUPER L'ÉNERGIE" or "RÉTABLIR L'ÉNERGIE"
		end
		UI.colorer(B.energie, alimente and Color3.fromRGB(110, 40, 50) or Color3.fromRGB(30, 100, 60))
		local finRedemarrage = exterieur:GetAttribute("TechRedemarrageFin")
		local requis = exterieur:GetAttribute("RedemarrageRequis") == true
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
		local couleur = (nombre == 0 and C.vert) or (critique and C.rouge) or C.orange
		textePastille.Text = nombre == 0 and "Systèmes nominaux" or (nombre .. (nombre > 1 and " interventions" or " intervention"))
		pointPastille.BackgroundColor3 = couleur
		contourPastille.Color = couleur
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
		tablette.Rotation = -1.5
		animer(echelle, 0.5, { Scale = base }, Enum.EasingStyle.Back)
		animer(tablette, 0.5, { Position = UDim2.fromScale(0.5, 0.5), Rotation = 0 }, Enum.EasingStyle.Back)
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
		local b = creer("TextButton", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.38, 0), Size = UDim2.fromOffset(52, 52),
			BackgroundColor3 = C.fond, BackgroundTransparency = 0.15, Text = "", Parent = guiTactile }, { UI.coin(99), UI.contour(C.ambre, 1.5, 0.2) })
		texte({ Text = "Y", Font = UI.POLICE_TITRE, TextSize = 18, TextColor3 = C.ambre, TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 22), Parent = b })
		texte({ Text = "ingénierie", TextSize = 9, TextColor3 = C.texte2, TextXAlignment = Enum.TextXAlignment.Center,
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
		local couleur = reussi and C.vert or C.rouge
		contourNotif.Color = couleur
		texteNotif.TextColor3 = UI.eclaircir(couleur, 0.4)
		texteNotif.Text = (reussi and "●  " or "×  ") .. message
		notification.Visible = true
		notification.Position = UDim2.new(0.5, 0, 0, -80)
		animer(notification, 0.35, { Position = UDim2.new(0.5, 0, 0, 62) }, Enum.EasingStyle.Back)
		task.delay(4, function()
			if moi ~= jeton then return end
			animer(notification, 0.3, { Position = UDim2.new(0.5, 0, 0, -80) }).Completed:Wait()
			if moi == jeton then notification.Visible = false end
		end)
	end)

	-- Animations et mises à jour
	local prochaine = 0
	RunService.RenderStepped:Connect(function(dt)
		if not ouvert then return end
		local t = os.clock()
		roue.Rotation = (roue.Rotation + dt * 25) % 360
		degrade.Rotation = (t * 8) % 360
		horloge.Text = os.date("%H:%M:%S")
		if t >= prochaine then
			prochaine = t + 0.25
			majTout()
		end
	end)

	return {}
end
