-- ReplicatedStorage > TardisUI (ModuleScript)
-- Briques d'interface communes au menu classique (TardisMenu) et à la tablette avancée (TardisTablette) :
-- palette, polices, construction rapide, animations, boutons vivants, interrupteurs.

local TweenService = game:GetService("TweenService")
local Config = require(script.Parent:WaitForChild("TardisConfig"))
local E = Config.Etats

local UI = {}

UI.C = {
	fond = Color3.fromRGB(5, 12, 28),
	ecran = Color3.fromRGB(7, 16, 36),
	panneau = Color3.fromRGB(11, 27, 56),
	panneauClair = Color3.fromRGB(20, 46, 90),
	bleu = Color3.fromRGB(26, 75, 140),
	ambre = Color3.fromRGB(242, 179, 61),
	cyan = Color3.fromRGB(79, 209, 255),
	vert = Color3.fromRGB(74, 222, 128),
	rouge = Color3.fromRGB(240, 82, 82),
	orange = Color3.fromRGB(240, 130, 40),
	texte = Color3.fromRGB(232, 238, 249),
	texte2 = Color3.fromRGB(143, 163, 199),
	gris = Color3.fromRGB(40, 48, 66),
	blanc = Color3.new(1, 1, 1),
}
local C = UI.C

-- Polices : une police "console" si elle existe, sinon Gotham
UI.POLICE_TITRE = Enum.Font.GothamBlack
pcall(function() UI.POLICE_TITRE = Enum.Font.Michroma end)
UI.POLICE = Enum.Font.Gotham
UI.POLICE_GRAS = Enum.Font.GothamBold
UI.POLICE_CODE = Enum.Font.Code

-- Libellés des états : { texte long, couleur, texte court }
UI.LIBELLES = {
	[E.Pose] = { "POSÉ", C.vert, "Posé" },
	[E.Demat] = { "DÉMATÉRIALISATION", C.ambre, "Dématérialisation" },
	[E.Vol] = { "DANS LE VORTEX", C.cyan, "Dans le vortex" },
	[E.Remat] = { "MATÉRIALISATION", C.ambre, "Matérialisation" },
}

--------------------------------------------------------------------
-- Construction
--------------------------------------------------------------------
-- Thème d'interface : chaque élément créé ici mémorise le rôle de ses couleurs (cyan, ambre, panneau...)
-- pour pouvoir être recoloré d'un coup quand le joueur change de thème.
local ROLES_COULEUR = { "fond", "ecran", "panneau", "panneauClair", "bleu", "ambre", "cyan", "texte", "texte2", "gris" }
local registreCoins = setmetatable({}, { __mode = "k" })    -- [UICorner] = rayon de base
local registreBordures = setmetatable({}, { __mode = "k" }) -- [UIStroke] = { epaisseur, transparence }
local formeActuelle = { coins = 1, bordure = 1, transparence = 0 }
local PROPRIETES_COULEUR = { "BackgroundColor3", "TextColor3", "Color", "ImageColor3" }
local registreCouleurs = setmetatable({}, { __mode = "k" }) -- [objet] = { propriete = role }

local function roleDe(couleur)
	for _, role in ROLES_COULEUR do
		if C[role] == couleur then return role end
	end
	return nil
end

function UI.creer(classe, proprietes, enfants)
	local objet = Instance.new(classe)
	for cle, valeur in proprietes or {} do
		if cle ~= "Parent" then objet[cle] = valeur end
	end
	for _, propriete in PROPRIETES_COULEUR do
		local valeur = proprietes and proprietes[propriete]
		if typeof(valeur) == "Color3" then
			local role = roleDe(valeur)
			if role then
				registreCouleurs[objet] = registreCouleurs[objet] or {}
				registreCouleurs[objet][propriete] = role
			end
		end
	end
	for _, enfant in enfants or {} do
		enfant.Parent = objet
	end
	if proprietes and proprietes.Parent then objet.Parent = proprietes.Parent end
	return objet
end
local creer = UI.creer

function UI.coin(rayon)
	local coin = Instance.new("UICorner")
	coin.CornerRadius = UDim.new(0, math.floor((rayon or 10) * formeActuelle.coins + 0.5))
	registreCoins[coin] = rayon or 10
	return coin
end

function UI.contour(couleur, epaisseur, transparence)
	local stroke = creer("UIStroke", {
		Color = couleur, Thickness = (epaisseur or 1) * formeActuelle.bordure, Transparency = math.clamp((transparence or 0) + formeActuelle.transparence, 0, 1),
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
	registreBordures[stroke] = { epaisseur = epaisseur or 1, transparence = transparence or 0 }
	return stroke
end

function UI.marges(px)
	return creer("UIPadding", {
		PaddingTop = UDim.new(0, px), PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px), PaddingRight = UDim.new(0, px),
	})
end

function UI.pile(espace, horizontal)
	return creer("UIListLayout", {
		Padding = UDim.new(0, espace or 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
	})
end

function UI.texte(proprietes)
	local base = {
		BackgroundTransparency = 1, TextColor3 = C.texte, Font = UI.POLICE, TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
		Size = UDim2.new(1, 0, 0, 18),
	}
	for cle, valeur in proprietes do base[cle] = valeur end
	return creer("TextLabel", base)
end

--------------------------------------------------------------------
-- Animations
--------------------------------------------------------------------
function UI.animer(objet, duree, proprietes, style, direction, delai)
	local tween = TweenService:Create(objet,
		TweenInfo.new(duree, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out, 0, false, delai or 0),
		proprietes)
	tween:Play()
	return tween
end
local animer = UI.animer

function UI.eclaircir(couleur, quantite)
	return couleur:Lerp(C.blanc, quantite)
end

-- Onde au clic : un cercle qui s'agrandit et s'efface à l'endroit touché (indépendant de l'échelle)
function UI.onde(bouton, x, y)
	local taille = bouton.AbsoluteSize
	if taille.X < 1 or taille.Y < 1 then return end
	local rond = creer("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale((x - bouton.AbsolutePosition.X) / taille.X, (y - bouton.AbsolutePosition.Y) / taille.Y),
		Size = UDim2.fromScale(0, 0), BackgroundColor3 = C.blanc, BackgroundTransparency = 0.75, ZIndex = bouton.ZIndex + 3,
		Parent = bouton,
	}, { UI.coin(999), creer("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Width }) })
	animer(rond, 0.5, { Size = UDim2.fromScale(2.4, 2.4), BackgroundTransparency = 1 })
	task.delay(0.5, function() rond:Destroy() end)
end

-- Bouton vivant : s'éclaircit au survol, s'enfonce au clic, onde à l'endroit touché
function UI.rendreVivant(bouton)
	local echelle = creer("UIScale", { Parent = bouton })
	bouton.AutoButtonColor = false
	bouton.ClipsDescendants = true
	bouton.MouseEnter:Connect(function()
		if bouton:GetAttribute("Disponible") == false then return end
		local base = bouton:GetAttribute("CouleurBase")
		if typeof(base) == "Color3" then animer(bouton, 0.15, { BackgroundColor3 = UI.eclaircir(base, 0.12) }) end
	end)
	bouton.MouseLeave:Connect(function()
		local base = bouton:GetAttribute("CouleurBase")
		if typeof(base) == "Color3" then animer(bouton, 0.2, { BackgroundColor3 = base }) end
		animer(echelle, 0.15, { Scale = 1 })
	end)
	bouton.InputBegan:Connect(function(input)
		if bouton:GetAttribute("Disponible") == false then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			animer(echelle, 0.08, { Scale = 0.97 })
			UI.onde(bouton, input.Position.X, input.Position.Y)
		end
	end)
	bouton.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			animer(echelle, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
		end
	end)
end

function UI.colorer(bouton, couleur)
	bouton:SetAttribute("CouleurBase", couleur)
	animer(bouton, 0.2, { BackgroundColor3 = couleur })
end

-- Grise (ou réactive) un bouton et ses textes
function UI.setDisponible(bouton, disponible, couleur)
	bouton:SetAttribute("Disponible", disponible)
	UI.colorer(bouton, disponible and couleur or C.gris)
	for _, enfant in bouton:GetDescendants() do
		if enfant:IsA("TextLabel") then
			enfant.TextTransparency = disponible and 0 or 0.5
		end
	end
end

--------------------------------------------------------------------
-- Matière (V6.7) : reflets de verre, bords, lignes d'écran, vignette. Tous ces calques laissent passer les clics
-- (un Frame non « Active » ne capte pas la souris).
--------------------------------------------------------------------
-- Reflet de verre : une lumière douce qui tombe du haut de l'élément
function UI.verre(parent, force, rayon)
	return creer("Frame", { Name = "Verre", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.blanc, BorderSizePixel = 0,
		ZIndex = (parent.ZIndex or 1) + 1, Parent = parent },
	{ UI.coin(rayon or 10), creer("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1 - (force or 0.08)), NumberSequenceKeypoint.new(0.45, 1), NumberSequenceKeypoint.new(1, 1) }) }) })
end

-- Bord d'ombre en bas de l'élément : donne de l'épaisseur aux cartes et aux boutons
function UI.bordure(parent, rayon)
	return creer("Frame", { Name = "Bordure", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 3),
		BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.6, BorderSizePixel = 0, ZIndex = (parent.ZIndex or 1) + 1, Parent = parent },
	{ UI.coin(rayon or 10) })
end

-- Lignes d'écran : de fines lignes horizontales, à peine visibles, comme sur un vrai écran
function UI.lignesEcran(parent, nombre, transparence)
	local calque = creer("Frame", { Name = "LignesEcran", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = parent })
	for i = 1, nombre or 20 do
		creer("Frame", { Position = UDim2.fromScale(0, (i - 0.5) / (nombre or 20)), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = transparence or 0.9, BorderSizePixel = 0, Parent = calque })
	end
	return calque
end

-- Vignette : les bords de l'écran s'assombrissent légèrement
function UI.vignette(parent, force)
	local calque = creer("Frame", { Name = "Vignette", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = (parent.ZIndex or 1) + 1, Parent = parent })
	local f = force or 0.5
	for _, info in { { Rotation = 90, Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(1, 0.18), haut = true },
		{ Rotation = 270, Position = UDim2.fromScale(0, 0.82), Size = UDim2.fromScale(1, 0.18) },
		{ Rotation = 0, Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(0.1, 1) },
		{ Rotation = 180, Position = UDim2.fromScale(0.9, 0), Size = UDim2.fromScale(0.1, 1) } } do
		creer("Frame", { Position = info.Position, Size = info.Size, BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Parent = calque },
		{ creer("UIGradient", { Rotation = info.Rotation, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1 - f), NumberSequenceKeypoint.new(1, 1) }) }) })
	end
	return calque
end

--------------------------------------------------------------------
-- Éléments composés
--------------------------------------------------------------------
-- Carte : un panneau avec un reflet de verre en haut, une épaisseur en bas, et (optionnel) une barre de couleur à gauche
function UI.carte(parent, ordre, espace, couleurContour, accent)
	-- (la carte range ses enfants en pile : le relief vient d'un dégradé du fond, pas d'un calque)
	local carte = creer("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.panneau, LayoutOrder = ordre or 0, Parent = parent },
	{ UI.coin(10), UI.contour(accent or couleurContour or C.bleu, 1, accent and 0.3 or 0.45), UI.marges(12), UI.pile(espace or 8),
		creer("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.blanc, Color3.fromRGB(205, 212, 228)) }) })
	return carte
end

-- Titre de section : un repère de couleur, le nom, et une ligne qui file jusqu'au bord
function UI.titreSection(parent, nom, ordre, couleur)
	couleur = couleur or C.ambre
	local cadre = creer("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = ordre or 0, Parent = parent })
	creer("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(6, 6), BackgroundColor3 = couleur,
		BorderSizePixel = 0, Parent = cadre }, { UI.coin(1) })
	local etiquette = UI.texte({ Text = nom, Font = UI.POLICE_GRAS, TextSize = 11, TextColor3 = couleur, Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, Parent = cadre })
	creer("Frame", { BackgroundColor3 = couleur, BackgroundTransparency = 0.78, BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(1, -(utf8.len(nom) * 8 + 26), 0, 1), Parent = cadre })
	etiquette.Name = "Etiquette"
	return cadre
end

-- Grand bouton d'action (DÉMATÉRIALISER / MATÉRIALISER) partagé par le menu rapide et la tablette :
-- titre, sous-titre, lueur ambrée, reflet de verre, et une barre de remplissage pour la progression d'un voyage.
-- Enfants nommés : Titre, SousTitre, Lueur (UIStroke), Remplissage (Frame, largeur en Scale)
function UI.boutonPrincipal(parent, nom, sousTitre, ordre, taille, rayon)
	taille = taille or UDim2.new(0.5, -5, 1, 0)
	rayon = rayon or 10
	local bouton = creer("TextButton", { Size = taille, BackgroundColor3 = C.bleu, Text = "", LayoutOrder = ordre or 0, Parent = parent }, { UI.coin(rayon) })
	local lueur = UI.contour(C.ambre, 1.5, 0.5)
	lueur.Name = "Lueur"
	lueur.Parent = bouton
	creer("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.blanc, Color3.fromRGB(170, 180, 205)), Parent = bouton })
	-- Remplissage de progression (de gauche à droite), derrière le texte
	creer("Frame", { Name = "Remplissage", Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.ambre, BackgroundTransparency = 0.72,
		BorderSizePixel = 0, ZIndex = bouton.ZIndex + 1, Parent = bouton }, { UI.coin(rayon) })
	UI.texte({ Name = "Titre", Text = nom, Font = UI.POLICE_GRAS, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.new(0, 0, 0.5, -16), Size = UDim2.new(1, 0, 0, 18), ZIndex = bouton.ZIndex + 2, Parent = bouton })
	UI.texte({ Name = "SousTitre", Text = sousTitre, TextSize = 11, TextColor3 = C.texte2, TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.new(0, 0, 0.5, 3), Size = UDim2.new(1, 0, 0, 14), ZIndex = bouton.ZIndex + 2, Parent = bouton })
	UI.verre(bouton, 0.12, rayon)
	UI.bordure(bouton, rayon)
	UI.rendreVivant(bouton)
	return bouton
end

-- Met à jour la progression d'un bouton principal (0..1, ou nil pour l'effacer)
function UI.progressionBouton(bouton, p, couleur)
	local remplissage = bouton:FindFirstChild("Remplissage")
	if not remplissage then return end
	remplissage.Size = UDim2.fromScale(p or 0, 1)
	if couleur then remplissage.BackgroundColor3 = couleur end
end

function UI.badge(parent, nom, couleur, ordre)
	return creer("TextLabel", { Text = nom, Font = UI.POLICE_GRAS, TextSize = 10, TextColor3 = couleur,
		BackgroundColor3 = couleur, BackgroundTransparency = 0.85, AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 0, 20), LayoutOrder = ordre or 0, Visible = false, Parent = parent },
	{ UI.coin(99), creer("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }), UI.contour(couleur, 1, 0.5) })
end

-- Interrupteur à bascule : renvoie { regler(valeur), valeur() }
-- (V6.7 : piste creusée, bille avec reflet et point de couleur, le nom s'allume quand il est actif)
function UI.interrupteur(parent, nom, description, couleur, ordre)
	local ligne = creer("TextButton", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, Text = "",
		LayoutOrder = ordre or 0, Parent = parent })
	local etiquette = UI.texte({ Text = nom, Font = UI.POLICE_GRAS, TextSize = 14, Size = UDim2.new(1, -60, 0, 18), Parent = ligne })
	UI.texte({ Text = description, TextSize = 11, TextColor3 = C.texte2, Position = UDim2.fromOffset(0, 18),
		Size = UDim2.new(1, -60, 0, 16), Parent = ligne })
	local piste = creer("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(48, 26), BackgroundColor3 = C.gris, Parent = ligne }, { UI.coin(99), UI.contour(Color3.new(0, 0, 0), 1, 0.7) })
	creer("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(150, 150, 150), C.blanc), Parent = piste })
	local bille = creer("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(20, 20), BackgroundColor3 = C.texte, Parent = piste }, { UI.coin(99) })
	creer("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.blanc, Color3.fromRGB(190, 195, 210)), Parent = bille })
	local point = creer("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(6, 6),
		BackgroundColor3 = C.gris, Parent = bille }, { UI.coin(99) })
	local lueur = creer("UIStroke", { Color = couleur, Thickness = 2, Transparency = 1, Parent = piste })

	local etat = false
	local inter = {}
	function inter.regler(valeur)
		etat = valeur
		animer(piste, 0.2, { BackgroundColor3 = valeur and couleur or C.gris })
		animer(lueur, 0.2, { Transparency = valeur and 0.4 or 1 })
		animer(point, 0.2, { BackgroundColor3 = valeur and couleur or C.gris })
		animer(etiquette, 0.2, { TextColor3 = valeur and UI.eclaircir(couleur, 0.45) or C.texte })
		animer(bille, 0.3, { Position = valeur and UDim2.new(1, -23, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) }, Enum.EasingStyle.Back)
	end
	function inter.valeur()
		return etat
	end
	ligne.Activated:Connect(function()
		inter.regler(not etat)
		if inter.surChangement then inter.surChangement(etat) end
	end)
	return inter
end

--------------------------------------------------------------------
-- Thèmes d'interface
--------------------------------------------------------------------
UI.THEMES = {
	-- Le TARDIS du 15e Docteur : ivoire, gris perle, or miel
	Gallifrey = { fond = Color3.fromRGB(238, 233, 222), ecran = Color3.fromRGB(246, 242, 234), panneau = Color3.fromRGB(252, 250, 246),
		panneauClair = Color3.fromRGB(228, 220, 204), bleu = Color3.fromRGB(196, 150, 60), ambre = Color3.fromRGB(176, 120, 28),
		cyan = Color3.fromRGB(200, 140, 40), texte = Color3.fromRGB(42, 38, 34), texte2 = Color3.fromRGB(120, 110, 96), gris = Color3.fromRGB(214, 206, 192),
		coins = 1.7, bordure = 0.6, transparence = 0.3, nom = "Gallifrey (15e Docteur)" },
	-- Le TARDIS du 13e Docteur : bleu nuit et cristaux ambrés
	Cristal = { fond = Color3.fromRGB(6, 9, 24), ecran = Color3.fromRGB(9, 13, 32), panneau = Color3.fromRGB(16, 22, 52),
		panneauClair = Color3.fromRGB(32, 40, 86), bleu = Color3.fromRGB(46, 60, 130), ambre = Color3.fromRGB(255, 160, 40),
		cyan = Color3.fromRGB(255, 190, 90), texte = Color3.fromRGB(240, 236, 228), texte2 = Color3.fromRGB(170, 160, 150), gris = Color3.fromRGB(44, 48, 70),
		coins = 0.7, bordure = 1.1, transparence = 0, nom = "Cristal (13e Docteur)" },
	-- La cabine : bleu TARDIS, blanc crème, cyan pâle
	PoliceBox = { fond = Color3.fromRGB(8, 24, 70), ecran = Color3.fromRGB(10, 30, 86), panneau = Color3.fromRGB(16, 44, 118),
		panneauClair = Color3.fromRGB(28, 66, 156), bleu = Color3.fromRGB(0, 61, 165), ambre = Color3.fromRGB(245, 236, 210),
		cyan = Color3.fromRGB(150, 220, 255), texte = Color3.fromRGB(250, 248, 240), texte2 = Color3.fromRGB(180, 200, 230), gris = Color3.fromRGB(26, 50, 110),
		coins = 0.35, bordure = 1.6, transparence = 0, nom = "Police Box (la cabine)" },
}
UI.ORDRE_THEMES = { "Gallifrey", "Cristal", "PoliceBox" }

-- Dégradé des barres d'en-tête (tablette, menu), calculé depuis le thème courant
function UI.degradeEntete()
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, C.panneau), ColorSequenceKeypoint.new(0.4, C.panneauClair),
		ColorSequenceKeypoint.new(0.7, C.bleu), ColorSequenceKeypoint.new(1, C.ecran),
	})
end

function UI.appliquerTheme(nom)
	local theme = UI.THEMES[nom]
	if not theme then return end
	for _, role in ROLES_COULEUR do
		if theme[role] then C[role] = theme[role] end
	end
	-- Formes : coins et bordures
	formeActuelle = { coins = theme.coins or 1, bordure = theme.bordure or 1, transparence = theme.transparence or 0 }
	for coin, base in registreCoins do
		if coin.Parent then coin.CornerRadius = UDim.new(0, math.floor(base * formeActuelle.coins + 0.5)) end
	end
	for stroke, infos in registreBordures do
		if stroke.Parent then
			stroke.Thickness = infos.epaisseur * formeActuelle.bordure
			stroke.Transparency = math.clamp(infos.transparence + formeActuelle.transparence, 0, 1)
		end
	end
	for objet, roles in registreCouleurs do
		if objet.Parent then
			for propriete, role in roles do
				pcall(function() objet[propriete] = C[role] end)
			end
			-- Les boutons gardent leur couleur de base à jour (sinon le survol les ramènerait à l'ancienne)
			local base = roles.BackgroundColor3
			if base and objet:GetAttribute("CouleurBase") then objet:SetAttribute("CouleurBase", C[base]) end
		end
	end
end

--------------------------------------------------------------------
-- Préférences du joueur (favoris, touches, thème d'interface, sons), sauvegardées par le serveur
--------------------------------------------------------------------
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local joueurLocal = Players.LocalPlayer
UI.prefs = {}
local prefsChargees = false
local nouveauJoueur = false -- aucune préférence sauvegardée à l'arrivée : le joueur n'a jamais ouvert les réglages

local function lirePrefs()
	if not joueurLocal then return end
	local json = joueurLocal:GetAttribute("TardisPrefs")
	if typeof(json) ~= "string" then return end
	local ok, valeur = pcall(HttpService.JSONDecode, HttpService, json)
	if ok and type(valeur) == "table" then
		UI.prefs = valeur
		prefsChargees = true
		nouveauJoueur = next(valeur) == nil
		if type(valeur.theme) == "string" and UI.THEMES[valeur.theme] then UI.appliquerTheme(valeur.theme) end
	end
end
if joueurLocal then
	lirePrefs()
	joueurLocal:GetAttributeChangedSignal("TardisPrefs"):Connect(function()
		if not prefsChargees then lirePrefs() end -- la première valeur vient du serveur ; ensuite c'est nous qui écrivons
	end)
end

local envoiPrevu = false
function UI.sauverPrefs()
	-- Première sauvegarde : le mode débutant choisi d'office (voir UI.debutant) est gardé tel quel
	if UI.prefs.debutant == nil then UI.prefs.debutant = UI.debutant() end
	if envoiPrevu then return end
	envoiPrevu = true
	task.delay(0.5, function()
		envoiPrevu = false
		local remote = ReplicatedStorage:FindFirstChild("TardisCommande")
		if remote then remote:FireServer("Prefs", HttpService:JSONEncode(UI.prefs)) end
	end)
end
function UI.pref(cle, defaut)
	local valeur = UI.prefs[cle]
	if valeur == nil then return defaut end
	return valeur
end
-- Signal "une préférence a changé" (les menus s'y abonnent pour se mettre à jour : taille, widgets...)
UI.prefsChangees = Instance.new("BindableEvent")
function UI.setPref(cle, valeur)
	UI.prefs[cle] = valeur
	UI.sauverPrefs()
	UI.prefsChangees:Fire(cle)
end

-- Taille de l'interface (0.6 à 1.4), multipliée à l'échelle automatique de chaque menu
function UI.tailleInterface()
	return math.clamp(tonumber(UI.pref("taille", 1)) or 1, 0.6, 1.4)
end

-- Option « réduire les effets » (joueurs sensibles) : saccades d'urgence, flashs, secousses et thème Flashbang adoucis
function UI.effetsReduits()
	return UI.pref("effetsReduits", false) == true
end

-- Volume des sons du TARDIS (0 à 1)
function UI.volume()
	return math.clamp(tonumber(UI.pref("volume", 1)) or 1, 0, 1)
end

-- Confirmation des actions dangereuses : le premier clic transforme le bouton en "Confirmer ?",
-- le second (dans les 3 secondes) exécute l'action. Désactivable dans les réglages.
function UI.confirmer(bouton, action)
	if UI.pref("confirmations", true) == false then
		action()
		return
	end
	if bouton:GetAttribute("EnAttenteConfirmation") then
		bouton:SetAttribute("EnAttenteConfirmation", nil)
		bouton.Text = bouton:GetAttribute("TexteOrigine") or bouton.Text
		action()
		return
	end
	bouton:SetAttribute("TexteOrigine", bouton.Text)
	bouton:SetAttribute("EnAttenteConfirmation", true)
	bouton.Text = "CONFIRMER ?"
	task.delay(3, function()
		if bouton:GetAttribute("EnAttenteConfirmation") then
			bouton:SetAttribute("EnAttenteConfirmation", nil)
			bouton.Text = bouton:GetAttribute("TexteOrigine") or bouton.Text
		end
	end)
end

-- Mode débutant : le choix des réglages ; à défaut, activé d'office pour un nouveau pilote
-- (aucune préférence sauvegardée et aucun voyage), jamais imposé à un pilote qui a déjà voyagé
function UI.debutant()
	local choix = UI.prefs.debutant
	if choix ~= nil then return choix == true end
	if not nouveauJoueur then return false end
	local json = joueurLocal and joueurLocal:GetAttribute("TardisStats")
	local ok, st = pcall(HttpService.JSONDecode, HttpService, typeof(json) == "string" and json or "{}")
	return not (ok and type(st) == "table" and (tonumber(st.voyages) or 0) > 0)
end
if joueurLocal then
	-- Les statistiques arrivent après les préférences : la tablette se remet à jour
	joueurLocal:GetAttributeChangedSignal("TardisStats"):Connect(function()
		if UI.prefs.debutant == nil then UI.prefsChangees:Fire("debutant") end
	end)
end

-- Widgets de la tablette : quels panneaux sont affichés (le mode débutant n'affiche que l'essentiel)
UI.WIDGETS = { "statut", "telemetrie", "flux", "navigation", "scanner", "occupants", "journal" }
function UI.widgetVisible(nom)
	if UI.debutant() then
		return nom == "statut" or nom == "navigation"
	end
	local widgets = UI.prefs.widgets
	if type(widgets) ~= "table" then return true end
	return widgets[nom] ~= false
end

-- Couleur d'un joueur sur les cartes : celle de son équipe, sinon la couleur par défaut
function UI.couleurJoueur(autre, defaut)
	if autre and autre.Team then return autre.TeamColor.Color end
	return defaut
end

-- Touches personnalisables : UI.touche("menu", Enum.KeyCode.T)
function UI.touche(nom, defaut)
	local touches = UI.prefs.touches
	local choisie = type(touches) == "table" and touches[nom]
	if type(choisie) == "string" and Enum.KeyCode[choisie] then return Enum.KeyCode[choisie] end
	return defaut
end
function UI.setTouche(nom, keyCode)
	UI.prefs.touches = type(UI.prefs.touches) == "table" and UI.prefs.touches or {}
	UI.prefs.touches[nom] = keyCode and keyCode.Name or nil
	UI.sauverPrefs()
end

-- Favoris (destinations épinglées)
function UI.estFavori(nom)
	return type(UI.prefs.favoris) == "table" and UI.prefs.favoris[nom] == true
end
function UI.basculerFavori(nom)
	UI.prefs.favoris = type(UI.prefs.favoris) == "table" and UI.prefs.favoris or {}
	UI.prefs.favoris[nom] = not UI.prefs.favoris[nom] or nil
	UI.sauverPrefs()
end

-- Sons de notification (sons intégrés à Roblox)
local sonsInterface = nil
function UI.son(type)
	if UI.pref("sons", true) == false then return end
	local Config = require(ReplicatedStorage:WaitForChild("TardisConfig"))
	local ids = Config.SonsInterface or {}
	local id = ids[type] or ids.Notification
	if not id then return end
	if not sonsInterface then
		sonsInterface = Instance.new("Folder")
		sonsInterface.Name = "TardisSonsInterface"
		sonsInterface.Parent = game:GetService("SoundService")
	end
	local son = Instance.new("Sound")
	son.SoundId = id
	son.Volume = type == "Alerte" and 0.8 or 0.5
	son.PlaybackSpeed = type == "Alerte" and 0.7 or 1.2
	son.Parent = sonsInterface
	son:Play()
	son.Ended:Connect(function() son:Destroy() end)
end

function UI.formatTemps(secondes)
	secondes = math.max(0, math.floor(secondes))
	return string.format("%02d:%02d", secondes // 60, secondes % 60)
end

return UI