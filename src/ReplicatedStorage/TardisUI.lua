-- ReplicatedStorage > TardisUI (ModuleScript)
-- Briques d'interface communes au menu classique (TardisMenu) et à la tablette avancée (TardisTablette) :
-- palette, polices, construction rapide, animations, boutons vivants, interrupteurs.
-- V6.9.10.6 : charte « Hologramme de confinement » (thème Confinement, par défaut pour tout le monde) et briques
-- réutilisables pour la phase 2 (menu de l'énergie, jukebox, casier, écrans de la console) :
--   UI.panneauCoupe, UI.decouper, UI.plaque, UI.bandeDanger, UI.jaugeSegments, UI.tableau, UI.boutonCoupe, UI.puce,
--   UI.carteEtat, UI.etiquette, UI.ligneAide, UI.champRecherche, UI.notification (voir leurs commentaires plus bas).

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Config = require(script.Parent:WaitForChild("TardisConfig"))
local E = Config.Etats

local UI = {}

-- Palette de départ (avant tout thème). Le serveur la garde telle quelle (V6.9.10.7 : les écrans de la console prennent
-- les jetons fixes UI.JETONS, voir plus bas).
UI.C = {
	fond = Color3.fromRGB(5, 12, 28),
	ecran = Color3.fromRGB(7, 16, 36),
	panneau = Color3.fromRGB(11, 27, 56),
	panneauClair = Color3.fromRGB(20, 46, 90),
	bleu = Color3.fromRGB(26, 75, 140),
	ligne = Color3.fromRGB(26, 75, 140), -- V6.9.10.6 : filets et bords (le bleu, hors Confinement)
	ambre = Color3.fromRGB(242, 179, 61),
	cyan = Color3.fromRGB(79, 209, 255),
	vert = Color3.fromRGB(74, 222, 128),
	rouge = Color3.fromRGB(240, 82, 82),
	orange = Color3.fromRGB(240, 130, 40),
	texte = Color3.fromRGB(232, 238, 249),
	texte2 = Color3.fromRGB(143, 163, 199),
	gris = Color3.fromRGB(40, 48, 66),
	creux = Color3.fromRGB(4, 10, 24), -- V6.9.8 : fond enfoncé des listes (suit le thème, clair en Gallifrey)
	sombre = Color3.fromRGB(11, 11, 11), -- V6.9.10.6 : texte posé sur le cyan ou le jaune
	blanc = Color3.new(1, 1, 1),
}
local C = UI.C
-- Copie de la palette de départ : un thème qui ne donne pas une couleur reprend celle-ci
UI.BASE = {}
for role, couleur in C do UI.BASE[role] = couleur end

-- Jetons de la charte « Hologramme de confinement » (V6.9.10.6) : fixes, quel que soit le thème choisi.
-- Pour les écrans de la console faits par le serveur, qui n'applique pas de thème (V6.9.10.7) : UI.JETONS.cyan, etc.
UI.JETONS = {
	panneau = Color3.fromRGB(10, 22, 38),  -- #0A1626 : fond de tous les menus (transparence 0,1)
	ligne = Color3.fromRGB(31, 110, 140),  -- #1F6E8C : bords, séparateurs, boutons secondaires
	texte = Color3.fromRGB(221, 246, 255), -- #DDF6FF : texte principal
	discret = Color3.fromRGB(134, 175, 195), -- #86AFC3 : étiquettes, aide, désactivé
	cyan = Color3.fromRGB(91, 224, 255),   -- #5BE0FF : action principale, lueur, bande de danger
	jaune = Color3.fromRGB(242, 194, 48),  -- #F2C230 : ligne choisie, mode choisi
	rouge = Color3.fromRGB(255, 77, 106),  -- #FF4D6A : refus, alerte, panne
	vert = Color3.fromRGB(124, 255, 178),  -- #7CFFB2 : accordé, posé, réparé
	sombre = Color3.fromRGB(11, 11, 11),   -- #0B0B0B : texte sur cyan ou jaune
	scene = Color3.fromRGB(4, 7, 12),      -- #04070C : bandes sombres de la bande de danger
	ecran = Color3.fromRGB(5, 11, 20),     -- #050B14 : fond des écrans de la console (V6.9.10.7, maquettes des écrans)
	transparencePanneau = 0.1,
	coupe = 16, coupeBouton = 10, coupePuce = 8, -- coins coupés (px)
	bande = 8,                                    -- hauteur de la bande de danger (px)
	cible = 44,                                   -- hauteur minimale d'une cible tactile (px)
}
local J = UI.JETONS

-- Polices (V6.9.10.6) : titres Michroma, texte Titillium Web, données Roboto Mono ; chacune protégée, avec Gotham en secours.
UI.POLICE_TITRE = Enum.Font.GothamBlack
pcall(function() UI.POLICE_TITRE = Enum.Font.Michroma end)
UI.POLICE = Enum.Font.Gotham
pcall(function() UI.POLICE = Enum.Font.TitilliumWeb end)
-- Le gras garde la valeur GothamBold comme repère : UI.creer la remplace par Titillium Web en gras (FontFace) quand c'est possible
UI.POLICE_GRAS = Enum.Font.GothamBold
UI.POLICE_CODE = Enum.Font.Code
pcall(function() UI.POLICE_CODE = Enum.Font.RobotoMono end)
UI.POLICE_CORPS = UI.POLICE        -- (V6.9.10.6) noms de la charte : texte…
UI.POLICE_DONNEES = UI.POLICE_CODE -- … et données
local FACE_GRAS = nil
pcall(function() FACE_GRAS = Font.new("rbxasset://fonts/families/TitilliumWeb.json", Enum.FontWeight.Bold) end)
UI.FACE_GRAS = FACE_GRAS -- (V6.9.10.7) Titillium Web en gras, pour les écrans de la console faits par le serveur (nil : indisponible)

-- Libellés des états : { texte long, couleur, texte court } (couleurs remises à jour à chaque thème)
UI.LIBELLES = {
	[E.Pose] = { "POSÉ", C.vert, "Posé" },
	[E.Demat] = { "DÉMATÉRIALISATION", C.ambre, "Dématérialisation" },
	[E.Vol] = { "DANS LE VORTEX", C.cyan, "Dans le vortex" },
	[E.Remat] = { "MATÉRIALISATION", C.ambre, "Matérialisation" },
}
-- Couleur d'interface d'un mode de voyage (interrupteurs, badges, texte du mode)
function UI.couleurMode(mode)
	return ({ Urgence = C.orange, Express = C.vert, Sauvetage = Color3.fromRGB(90, 220, 230), Catastrophe = C.rouge,
		Silencieux = Color3.fromRGB(170, 140, 240) })[mode] or C.texte2
end

-- Majuscules françaises (V6.9.10.6) : string.upper ne connaît pas les lettres accentuées
local ACCENTS = { ["é"] = "É", ["è"] = "È", ["ê"] = "Ê", ["ë"] = "Ë", ["à"] = "À", ["â"] = "Â", ["ä"] = "Ä", ["î"] = "Î", ["ï"] = "Ï",
	["ô"] = "Ô", ["ö"] = "Ö", ["ù"] = "Ù", ["û"] = "Û", ["ü"] = "Ü", ["ç"] = "Ç", ["œ"] = "Œ", ["æ"] = "Æ" }
function UI.majuscules(s)
	s = string.upper(tostring(s or ""))
	for petit, grand in ACCENTS do s = string.gsub(s, petit, grand) end
	return s
end

--------------------------------------------------------------------
-- Construction
--------------------------------------------------------------------
-- Thème d'interface : chaque élément créé ici mémorise le rôle de ses couleurs (cyan, ambre, panneau...)
-- pour pouvoir être recoloré d'un coup quand le joueur change de thème.
-- (« ligne » passe avant « bleu » : en Confinement les deux sont égaux, et un filet doit rester un filet.)
local ROLES_COULEUR = { "fond", "ecran", "panneau", "panneauClair", "ligne", "bleu", "ambre", "cyan", "texte", "texte2", "gris", "creux",
	"vert", "rouge", "sombre" }
local registreCoins = setmetatable({}, { __mode = "k" })    -- [UICorner] = { rayon de base, anguleux }
local registreBordures = setmetatable({}, { __mode = "k" }) -- [UIStroke] = { epaisseur, transparence }
local formeActuelle = { coins = 1, bordure = 1, transparence = 0 }
local PROPRIETES_COULEUR = { "BackgroundColor3", "TextColor3", "Color", "ImageColor3" }
local registreCouleurs = setmetatable({}, { __mode = "k" }) -- [objet] = { propriete = role }
local themeActuel = nil -- nom du thème appliqué (nil : palette de départ)

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
	-- Gras (V6.9.10.6) : Titillium Web en gras quand la plateforme le permet (sinon GothamBold reste)
	if proprietes and proprietes.Font == UI.POLICE_GRAS and FACE_GRAS then
		pcall(function() objet.FontFace = FACE_GRAS end)
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

-- Rayon d'un coin selon le thème : un rayon de 99 ou plus (rond, pastille) reste rond, sauf s'il est « anguleux »
-- (badges, interrupteurs : carrés en Confinement)
local function rayonDe(base, anguleux)
	if base >= 99 and not (anguleux and formeActuelle.coins == 0) then return base end
	return math.floor(base * formeActuelle.coins + 0.5)
end

-- UI.coin(rayon, anguleux) : coin arrondi qui suit le thème (Confinement : coins droits, voir UI.decouper pour les coins coupés)
function UI.coin(rayon, anguleux)
	local coin = Instance.new("UICorner")
	coin.CornerRadius = UDim.new(0, rayonDe(rayon or 10, anguleux))
	registreCoins[coin] = { rayon = rayon or 10, anguleux = anguleux == true }
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
-- Décor selon le thème (V6.9.10.6) : chaque élément décoratif dit dans quels thèmes il est visible.
--   "horsConfinement" : reflets, reliefs et épaisseurs des anciens thèmes
--   "confinement"     : coins coupés (traits en biais, images 9 tranches)
--   "effet"           : lueur et lignes de balayage (Confinement, coupées par « Réduire les effets »)
--   "effetHors"       : lignes d'écran des anciens thèmes (coupées par « Réduire les effets »)
-- Aucun calque n'a de boucle image par image : tout est posé une fois, puis remis à jour au changement de thème.
--------------------------------------------------------------------
local registreDecor = setmetatable({}, { __mode = "k" })   -- [objet] = genre
local registreFonds = setmetatable({}, { __mode = "k" })   -- [objet] = { hors = transparence, conf = transparence }
local registreDuo = setmetatable({}, { __mode = "k" })     -- [objet] = { propriete, hors (Color3), horsRole, conf (rôle) }
local registreBoutons = setmetatable({}, { __mode = "k" }) -- [bouton à variante] = true
local registrePuces = setmetatable({}, { __mode = "k" })   -- [bouton] = puce
local registreBandes = setmetatable({}, { __mode = "k" })  -- [cadre] = { bandes }
local registreJauges = setmetatable({}, { __mode = "k" })  -- [cadre] = jauge
local registreTableaux = setmetatable({}, { __mode = "k" }) -- [cadre] = tableau

function UI.estConfinement()
	return themeActuel == "Confinement"
end
function UI.themeActuel()
	return themeActuel
end

local function idImage(v)
	if type(v) == "number" and v > 0 then return "rbxassetid://" .. tostring(math.floor(v)) end
	if type(v) == "string" and v ~= "" and v ~= "0" then
		if string.match(v, "^%d+$") then return "rbxassetid://" .. v end
		return v
	end
	return nil
end
-- Images 9 tranches facultatives (Config.Interface.Images) : { fond, bord, balayage } (nil = absente)
function UI.imagesInterface()
	local reglages = (Config.Interface or {}).Images or {}
	return { fond = idImage(reglages.CoinFond), bord = idImage(reglages.CoinBord), balayage = idImage(reglages.Balayage) }
end

local function decorVisible(genre)
	local conf = UI.estConfinement()
	local reduit = UI.effetsReduits and UI.effetsReduits() or false
	if genre == "horsConfinement" then return not conf end
	if genre == "confinement" then return conf end
	if genre == "effet" then return conf and not reduit end
	if genre == "effetHors" then return not conf and not reduit end
	return true
end
local function appliquerDecor(objet, genre)
	local visible = decorVisible(genre)
	if objet.ClassName == "UIStroke" or objet.ClassName == "UIGradient" then objet.Enabled = visible else objet.Visible = visible end
end
-- UI.decor(objet, genre) : range un élément décoratif (voir les genres ci-dessus) ; renvoie l'objet
function UI.decor(objet, genre)
	registreDecor[objet] = genre
	appliquerDecor(objet, genre)
	return objet
end
-- UI.fondSelonTheme(objet, transparenceHors, transparenceConfinement) : transparence du fond selon le thème
function UI.fondSelonTheme(objet, hors, conf)
	registreFonds[objet] = { hors = hors, conf = conf }
	objet.BackgroundTransparency = UI.estConfinement() and conf or hors
	return objet
end
-- UI.couleurSelonTheme(objet, propriete, couleurHors, roleConfinement) : une couleur hors Confinement, un rôle en Confinement
function UI.couleurSelonTheme(objet, propriete, hors, conf)
	registreDuo[objet] = { propriete = propriete, hors = hors, horsRole = roleDe(hors), conf = conf }
	objet[propriete] = UI.estConfinement() and C[conf] or hors
	return objet
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

--------------------------------------------------------------------
-- Boutons à variante (V6.9.10.6) : "principal" (cyan plein, texte sombre), "secondaire" (filet), "danger" (filet rouge).
-- La couleur suit le thème et la disponibilité (UI.setDisponible) ; attribut « Variante ».
--------------------------------------------------------------------
local function couleursVariante(variante, disponible)
	local conf = UI.estConfinement()
	if variante == "principal" then
		if conf then
			return { fond = disponible and C.cyan or C.gris, tf = 0, texte = disponible and C.sombre or C.texte2,
				contour = disponible and C.cyan or C.ligne, tc = disponible and 0 or 0.4 }
		end
		return { fond = disponible and C.bleu or C.gris, tf = 0, texte = C.texte, contour = C.cyan, tc = 0.5 }
	elseif variante == "danger" then
		if conf then
			return { fond = C.rouge, tf = disponible and 0.9 or 1, texte = disponible and C.rouge or C.texte2,
				contour = disponible and C.rouge or C.ligne, tc = disponible and 0 or 0.4 }
		end
		return { fond = disponible and Color3.fromRGB(110, 40, 50) or C.gris, tf = 0, texte = C.texte, contour = C.rouge, tc = 0.4 }
	end
	if conf then
		return { fond = C.cyan, tf = 1, texte = disponible and C.texte or C.texte2, contour = C.ligne, tc = disponible and 0 or 0.45 }
	end
	return { fond = disponible and C.panneauClair or C.gris, tf = 0, texte = C.texte, contour = C.cyan, tc = 0.55 }
end

-- Teinte le contour d'un élément découpé : UIStroke « Contour » / « Lueur », traits en biais et image du bord
function UI.teinterContour(objet, couleur, transparence)
	for _, enfant in objet:GetChildren() do
		local nom = enfant.Name
		if enfant.ClassName == "UIStroke" and (nom == "Contour" or nom == "Lueur") then
			enfant.Color = couleur
			if transparence then enfant.Transparency = transparence end
		elseif nom == "Chanfrein" then
			enfant.BackgroundColor3 = couleur
		elseif nom == "BordCoupe" then
			enfant.ImageColor3 = couleur
			if transparence then enfant.ImageTransparency = transparence end
		end
	end
end

-- Fond d'un élément découpé : son propre fond, ou l'image 9 tranches « FondCoupe » quand elle est là (Confinement)
local function poserFond(objet, couleur, transparence)
	objet.BackgroundColor3 = couleur
	local image = objet:FindFirstChild("FondCoupe")
	if image and UI.estConfinement() then
		image.ImageColor3 = couleur
		image.ImageTransparency = transparence
		objet.BackgroundTransparency = 1
	else
		objet.BackgroundTransparency = transparence
	end
end

function UI.peindreBouton(bouton)
	local variante = bouton:GetAttribute("Variante") or "secondaire"
	local disponible = bouton:GetAttribute("Disponible") ~= false
	local v = couleursVariante(variante, disponible)
	bouton:SetAttribute("CouleurBase", v.fond)
	bouton:SetAttribute("TransparenceBase", v.tf)
	poserFond(bouton, v.fond, v.tf)
	if bouton.ClassName == "TextButton" and bouton.Text ~= "" then
		bouton.TextColor3 = v.texte
		bouton.TextTransparency = 0
	end
	for _, nom in { "Titre", "SousTitre" } do
		local t = bouton:FindFirstChild(nom)
		if t then
			t.TextColor3 = v.texte
			t.TextTransparency = (nom == "SousTitre" and 0.25 or 0)
		end
	end
	UI.teinterContour(bouton, v.contour, v.tc)
end

-- Survol d'un bouton à variante : le principal s'éclaircit, les autres se teintent légèrement
local function survolerVariante(bouton, actif)
	if not actif then UI.peindreBouton(bouton) return end
	local variante = bouton:GetAttribute("Variante")
	local base = bouton:GetAttribute("CouleurBase")
	if variante == "principal" and typeof(base) == "Color3" then
		poserFond(bouton, UI.eclaircir(base, 0.15), bouton:GetAttribute("TransparenceBase") or 0)
	else
		poserFond(bouton, variante == "danger" and C.rouge or C.cyan, 0.84)
	end
end

-- Bouton vivant : s'éclaircit au survol, s'enfonce au clic, onde à l'endroit touché
function UI.rendreVivant(bouton)
	local echelle = creer("UIScale", { Parent = bouton })
	bouton.AutoButtonColor = false
	bouton.ClipsDescendants = true
	bouton.MouseEnter:Connect(function()
		if bouton:GetAttribute("Disponible") == false then return end
		if bouton:GetAttribute("Variante") then survolerVariante(bouton, true) return end
		local base = bouton:GetAttribute("CouleurBase")
		if typeof(base) == "Color3" then animer(bouton, 0.15, { BackgroundColor3 = UI.eclaircir(base, 0.12) }) end
	end)
	bouton.MouseLeave:Connect(function()
		if bouton:GetAttribute("Variante") then
			if bouton:GetAttribute("Disponible") ~= false then survolerVariante(bouton, false) end
		else
			local base = bouton:GetAttribute("CouleurBase")
			if typeof(base) == "Color3" then animer(bouton, 0.2, { BackgroundColor3 = base }) end
		end
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

-- Grise (ou réactive) un bouton et ses textes (bouton à variante : couleurs de sa variante)
function UI.setDisponible(bouton, disponible, couleur)
	bouton:SetAttribute("Disponible", disponible)
	if bouton:GetAttribute("Variante") then
		UI.peindreBouton(bouton)
		return
	end
	UI.colorer(bouton, disponible and couleur or C.gris)
	for _, enfant in bouton:GetDescendants() do
		if enfant:IsA("TextLabel") then
			enfant.TextTransparency = disponible and 0 or 0.5
		end
	end
end

--------------------------------------------------------------------
-- Matière (V6.7) : reflets de verre, bords, lignes d'écran, vignette. Tous ces calques laissent passer les clics
-- (un Frame non « Active » ne capte pas la souris). V6.9.10.6 : reflets et épaisseurs cachés en Confinement.
--------------------------------------------------------------------
-- Reflet de verre : une lumière douce qui tombe du haut de l'élément
function UI.verre(parent, force, rayon)
	return UI.decor(creer("Frame", { Name = "Verre", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.blanc, BorderSizePixel = 0,
		ZIndex = (parent.ZIndex or 1) + 1, Parent = parent },
	{ UI.coin(rayon or 10), creer("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1 - (force or 0.08)), NumberSequenceKeypoint.new(0.45, 1), NumberSequenceKeypoint.new(1, 1) }) }) }), "horsConfinement")
end

-- Bord d'ombre en bas de l'élément : donne de l'épaisseur aux cartes et aux boutons
function UI.bordure(parent, rayon)
	return UI.decor(creer("Frame", { Name = "Bordure", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 3),
		BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.6, BorderSizePixel = 0, ZIndex = (parent.ZIndex or 1) + 1, Parent = parent },
	{ UI.coin(rayon or 10) }), "horsConfinement")
end

-- Lignes de balayage (V6.9.10.6) : l'image « Balayage » répétée (Confinement, si elle est importée) ; dans les anciens
-- thèmes, de fines lignes horizontales. Les deux sont coupées par « Réduire les effets ». Renvoie le calque.
function UI.balayage(parent, transparence)
	local images = UI.imagesInterface()
	if not images.balayage then return nil end
	return UI.decor(creer("ImageLabel", { Name = "Balayage", BackgroundTransparency = 1, Image = images.balayage, ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(8, 3), ResampleMode = Enum.ResamplerMode.Pixelated, ImageColor3 = C.texte, ImageTransparency = transparence or 0.9,
		Size = UDim2.fromScale(1, 1), ZIndex = 0, Parent = parent }), "effet")
end
function UI.lignesEcran(parent, nombre, transparence)
	local calque = creer("Frame", { Name = "LignesEcran", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = parent })
	local anciennes = UI.decor(creer("Frame", { Name = "Lignes", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = calque }), "effetHors")
	for i = 1, nombre or 20 do
		creer("Frame", { Position = UDim2.fromScale(0, (i - 0.5) / (nombre or 20)), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = transparence or 0.9, BorderSizePixel = 0, Parent = anciennes })
	end
	UI.balayage(calque)
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
-- Coins coupés (V6.9.10.6). Roblox ne sait pas découper un cadre en biais :
--   • avec les images 9 tranches de Config.Interface.Images (CoinFond, CoinBord) : le fond et le bord sont dessinés par
--     deux ImageLabel « FondCoupe » et « BordCoupe » (ScaleType Slice, SliceCenter 16,16,48,48) teintées par ImageColor3 ;
--   • sans image : coins droits, et un petit trait en biais « Chanfrein » dans les deux coins coupés (haut droit, bas gauche).
-- UI.decouper(objet, coupe, options) ajoute ces calques à un cadre ou à un bouton qui n'a PAS de UIListLayout ni de
-- UIPadding (sinon les calques seraient rangés avec le contenu). options : { contour = Color3, transparenceContour }.
-- Renvoie { image = bool, fond, bord, chanfreins = { ... } }.
--------------------------------------------------------------------
function UI.decouper(objet, coupe, options)
	options = options or {}
	coupe = coupe or J.coupe
	local images = UI.imagesInterface()
	local couleurBord = options.contour or C.ligne
	local resultat = { image = false, chanfreins = {} }
	if images.fond then
		resultat.image = true
		resultat.fond = UI.decor(creer("ImageLabel", { Name = "FondCoupe", BackgroundTransparency = 1, Image = images.fond, ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(16, 16, 48, 48), SliceScale = coupe / 16, ImageColor3 = objet.BackgroundColor3, ImageTransparency = objet.BackgroundTransparency,
			Size = UDim2.fromScale(1, 1), ZIndex = 0, Parent = objet }), "confinement")
		registreFonds[objet] = { hors = objet.BackgroundTransparency, conf = 1 }
		if images.bord then
			resultat.bord = UI.decor(creer("ImageLabel", { Name = "BordCoupe", BackgroundTransparency = 1, Image = images.bord, ScaleType = Enum.ScaleType.Slice,
				SliceCenter = Rect.new(16, 16, 48, 48), SliceScale = coupe / 16, ImageColor3 = couleurBord, ImageTransparency = options.transparenceContour or 0.3,
				Size = UDim2.fromScale(1, 1), ZIndex = (objet.ZIndex or 1) + 3, Parent = objet }), "confinement")
		end
		-- Le UIStroke dessinerait un cadre carré autour de la découpe : réservé aux anciens thèmes
		for _, enfant in objet:GetChildren() do
			if enfant.ClassName == "UIStroke" then UI.decor(enfant, "horsConfinement") end
		end
		objet.BackgroundTransparency = UI.estConfinement() and 1 or objet.BackgroundTransparency
	else
		local longueur = math.floor(coupe * 1.4142 + 0.5)
		for _, position in { UDim2.new(1, -coupe / 2, 0, coupe / 2), UDim2.new(0, coupe / 2, 1, -coupe / 2) } do
			table.insert(resultat.chanfreins, UI.decor(creer("Frame", { Name = "Chanfrein", AnchorPoint = Vector2.new(0.5, 0.5), Position = position,
				Size = UDim2.fromOffset(longueur, 1), Rotation = 45, BackgroundColor3 = couleurBord, BackgroundTransparency = options.transparenceContour or 0.2,
				BorderSizePixel = 0, ZIndex = (objet.ZIndex or 1) + 3, Parent = objet }), "confinement"))
		end
	end
	objet:SetAttribute("Coupe", coupe)
	return resultat
end

-- Lueur d'un panneau : un filet épais et très transparent autour du cadre (image du bord, plus grande, avec les images)
function UI.lueur(objet)
	local images = UI.imagesInterface()
	if images.fond and images.bord then
		return UI.decor(creer("ImageLabel", { Name = "Lueur", BackgroundTransparency = 1, Image = images.bord, ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(16, 16, 48, 48), ImageColor3 = C.cyan, ImageTransparency = 0.7, Position = UDim2.fromOffset(-3, -3),
			Size = UDim2.new(1, 6, 1, 6), ZIndex = 0, Parent = objet }), "effet")
	end
	return UI.decor(creer("Frame", { Name = "Lueur", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 0, Parent = objet },
	{ creer("UIStroke", { Color = C.cyan, Thickness = 3, Transparency = 0.8, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) }), "effet")
end

-- UI.panneauCoupe(proprietes, options) → cadre, contenu
-- Panneau de la charte : fond bleu nuit (transparence 0,1), filet cyan lumineux (UIStroke « Contour »), coins coupés
-- (UI.decouper), lueur (UI.lueur) et lignes de balayage (UI.balayage). Le contenu va dans « contenu » (un Frame
-- transparent de la taille du panneau) : c'est là qu'on met UIListLayout et UIPadding.
-- proprietes : celles du Frame (Size, Position, AnchorPoint, Parent, Name, ZIndex, LayoutOrder, BackgroundColor3…).
-- options : { coupe = 16, rayon = 14 (anciens thèmes), contour = Color3, transparenceContour = 0.55, lueur = true,
--             balayage = true, marges = px, pile = espace (UIListLayout vertical dans le contenu) }
function UI.panneauCoupe(proprietes, options)
	options = options or {}
	local base = { Name = "Panneau", BackgroundColor3 = C.fond, BackgroundTransparency = J.transparencePanneau, BorderSizePixel = 0 }
	for cle, valeur in proprietes or {} do base[cle] = valeur end
	local cadre = creer("Frame", base, { UI.coin(options.rayon or 14) })
	local contour = UI.contour(options.contour or C.cyan, options.epaisseur or 1, options.transparenceContour or 0.55)
	contour.Name = "Contour"
	contour.Parent = cadre
	UI.decouper(cadre, options.coupe or J.coupe, { contour = options.contour or C.cyan, transparenceContour = 0.3 })
	if options.lueur ~= false then UI.lueur(cadre) end
	if options.balayage ~= false then UI.balayage(cadre) end
	local contenu = creer("Frame", { Name = "Contenu", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = cadre })
	if options.marges then UI.marges(options.marges).Parent = contenu end
	if options.pile then UI.pile(options.pile).Parent = contenu end
	return cadre, contenu
end

-- UI.bandeDanger(proprietes, options) → cadre : la bande de danger (8 px), faite en code : des bandes inclinées
-- cyan dans un cadre sombre qui coupe ce qui dépasse (ClipsDescendants). Aucune image.
-- options : { hauteur = 8, largeur = 1400 (largeur maximale prévue, pour le nombre de bandes) }
-- UI.reglerBande(cadre, alerte) la passe au rouge ; UI.lierBandeAlerte(cadre, exterieur) suit l'attribut « Alerte ».
function UI.bandeDanger(proprietes, options)
	options = options or {}
	local hauteur = options.hauteur or J.bande
	local base = { Name = "BandeDanger", Size = UDim2.new(1, 0, 0, hauteur), BackgroundColor3 = J.scene, BorderSizePixel = 0, ClipsDescendants = true }
	for cle, valeur in proprietes or {} do base[cle] = valeur end
	local cadre = creer("Frame", base)
	local pas = 16 * 1.4142 -- une bande cyan de 8 px et une sombre de 8 px, mesurées en travers (comme la charte)
	local bandes = {}
	local nombre = math.ceil(((options.largeur or 1400) + hauteur * 2) / pas) + 1
	for i = 0, nombre do
		table.insert(bandes, creer("Frame", { Name = "Bande", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, math.floor(i * pas - hauteur + 0.5), 0.5, 0),
			Size = UDim2.fromOffset(8, hauteur * 3), Rotation = 45, BackgroundColor3 = C.cyan, BorderSizePixel = 0, Parent = cadre }))
	end
	registreBandes[cadre] = bandes
	cadre:SetAttribute("Alerte", false)
	return cadre
end
function UI.reglerBande(cadre, alerte)
	cadre:SetAttribute("Alerte", alerte == true)
	for _, bande in registreBandes[cadre] or {} do
		bande.BackgroundColor3 = alerte and C.rouge or C.cyan
	end
end
function UI.lierBandeAlerte(cadre, exterieur, attribut)
	attribut = attribut or "Alerte"
	local function maj() UI.reglerBande(cadre, exterieur:GetAttribute(attribut) == true) end
	exterieur:GetAttributeChangedSignal(attribut):Connect(maj)
	maj()
end

--------------------------------------------------------------------
-- Éléments composés
--------------------------------------------------------------------
-- Carte : un panneau avec un reflet de verre en haut, une épaisseur en bas, et (optionnel) une barre de couleur à gauche
-- (V6.9.10.6 : en Confinement, un bloc plat à coins droits avec un filet ; le contour prend la couleur d'accent)
function UI.carte(parent, ordre, espace, couleurContour, accent)
	-- (la carte range ses enfants en pile : le relief vient d'un dégradé du fond, pas d'un calque)
	local carte = creer("Frame", { Name = "Carte", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.panneau, LayoutOrder = ordre or 0, Parent = parent },
	{ UI.coin(10), UI.contour(accent or couleurContour or C.ligne, 1, accent and 0.3 or 0.5), UI.marges(12), UI.pile(espace or 8),
		UI.decor(creer("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.blanc, Color3.fromRGB(205, 212, 228)) }), "horsConfinement") })
	return carte
end

-- Titre de section : un repère de couleur, le nom, et une ligne qui file jusqu'au bord
-- (V6.9.10.6 : étiquette en police de données ; en Confinement, discrète, sans repère, filet couleur de ligne)
function UI.titreSection(parent, nom, ordre, couleur)
	couleur = couleur or C.ambre
	local cadre = creer("Frame", { Name = "TitreSection", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = ordre or 0, Parent = parent })
	UI.decor(creer("Frame", { Name = "Repere", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(6, 6),
		BackgroundColor3 = couleur, BorderSizePixel = 0, Parent = cadre }, { UI.coin(1) }), "horsConfinement")
	local etiquette = UI.texte({ Text = UI.majuscules(nom), Font = UI.POLICE_CODE, TextSize = 11, TextColor3 = couleur, Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, Parent = cadre })
	UI.couleurSelonTheme(etiquette, "TextColor3", couleur, "texte2")
	local trait = creer("Frame", { Name = "Trait", BackgroundColor3 = couleur, BackgroundTransparency = 0.6, BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(1, -(utf8.len(nom) * 8 + 26), 0, 1), Parent = cadre })
	UI.couleurSelonTheme(trait, "BackgroundColor3", couleur, "ligne")
	etiquette.Name = "Etiquette"
	return cadre
end

-- Grand bouton d'action (DÉMAT / REMAT) partagé par le menu rapide et la tablette :
-- titre, sous-titre, lueur, et une barre de remplissage pour la progression d'un voyage.
-- Enfants nommés : Titre, SousTitre, Lueur (UIStroke), Remplissage (Frame, largeur en Scale)
-- V6.9.10.6 : coins coupés (10 px) et variante (7e paramètre : "principal" par défaut, "secondaire", "danger").
function UI.boutonPrincipal(parent, nom, sousTitre, ordre, taille, rayon, variante)
	taille = taille or UDim2.new(0.5, -5, 1, 0)
	rayon = rayon or 10
	local bouton = creer("TextButton", { Name = "BoutonPrincipal", Size = taille, BackgroundColor3 = C.bleu, Text = "", LayoutOrder = ordre or 0, Parent = parent }, { UI.coin(rayon) })
	local lueur = UI.contour(C.cyan, 1.5, 0.5)
	lueur.Name = "Lueur"
	lueur.Parent = bouton
	UI.decor(creer("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.blanc, Color3.fromRGB(170, 180, 205)), Parent = bouton }), "horsConfinement")
	UI.decouper(bouton, J.coupeBouton, { contour = C.cyan })
	-- Remplissage de progression (de gauche à droite), derrière le texte
	creer("Frame", { Name = "Remplissage", Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.ambre, BackgroundTransparency = 0.72,
		BorderSizePixel = 0, ZIndex = bouton.ZIndex + 1, Parent = bouton }, { UI.coin(rayon) })
	UI.texte({ Name = "Titre", Text = nom, Font = UI.POLICE_TITRE, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.new(0, 0, 0.5, -16), Size = UDim2.new(1, 0, 0, 18), ZIndex = bouton.ZIndex + 2, Parent = bouton })
	UI.texte({ Name = "SousTitre", Text = sousTitre, TextSize = 11, TextColor3 = C.texte2, TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.new(0, 0, 0.5, 3), Size = UDim2.new(1, 0, 0, 14), ZIndex = bouton.ZIndex + 2, Parent = bouton })
	UI.verre(bouton, 0.12, rayon)
	UI.bordure(bouton, rayon)
	bouton:SetAttribute("Variante", variante or "principal")
	registreBoutons[bouton] = true
	UI.rendreVivant(bouton)
	UI.peindreBouton(bouton)
	return bouton
end

-- Met à jour la progression d'un bouton principal (0..1, ou nil pour l'effacer)
function UI.progressionBouton(bouton, p, couleur)
	local remplissage = bouton:FindFirstChild("Remplissage")
	if not remplissage then return end
	remplissage.Size = UDim2.fromScale(p or 0, 1)
	if couleur then remplissage.BackgroundColor3 = couleur end
end

-- Bouton principal en mode confirmation (V6.7.1, paradoxe) : rouge, « VOUS CONFIRMEZ ? », qui clignote ;
-- arme = faux : retour au titre et au sous-titre d'origine
function UI.confirmationBouton(bouton, arme, sousTitre)
	local titre, sous = bouton:FindFirstChild("Titre"), bouton:FindFirstChild("SousTitre")
	if not titre or not sous then return end
	if arme then
		if not bouton:GetAttribute("ConfirmationTitre") then
			bouton:SetAttribute("ConfirmationTitre", titre.Text)
			bouton:SetAttribute("ConfirmationSous", sous.Text)
		end
		titre.Text = "VOUS CONFIRMEZ ?"
		sous.Text = sousTitre or "Destination dans le TARDIS"
		bouton:SetAttribute("Disponible", true)
		if bouton:GetAttribute("Variante") then
			local fond = UI.estConfinement() and C.rouge or Color3.fromRGB(150, 35, 40)
			bouton:SetAttribute("CouleurBase", fond)
			poserFond(bouton, fond, 0)
			for _, t in { titre, sous } do t.TextColor3 = UI.estConfinement() and C.sombre or C.texte end
		else
			UI.colorer(bouton, Color3.fromRGB(150, 35, 40))
		end
		bouton.Lueur.Color = C.rouge
		bouton.Lueur.Transparency = 0.2 + 0.5 * (0.5 + 0.5 * math.sin(os.clock() * 8))
		for _, enfant in bouton:GetDescendants() do
			if enfant:IsA("TextLabel") then enfant.TextTransparency = 0 end
		end
	elseif bouton:GetAttribute("ConfirmationTitre") then
		titre.Text = bouton:GetAttribute("ConfirmationTitre")
		sous.Text = bouton:GetAttribute("ConfirmationSous") or sous.Text
		bouton:SetAttribute("ConfirmationTitre", nil)
		bouton:SetAttribute("ConfirmationSous", nil)
		if bouton:GetAttribute("Variante") then UI.peindreBouton(bouton) end
	end
end

-- Badge (V6.9.10.6 : police de données, filet de sa couleur ; rectangle en Confinement, pastille ailleurs)
function UI.badge(parent, nom, couleur, ordre)
	return creer("TextLabel", { Name = "Badge", Text = UI.majuscules(nom), Font = UI.POLICE_CODE, TextSize = 11, TextColor3 = couleur,
		BackgroundColor3 = couleur, BackgroundTransparency = 0.9, AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 0, 20), LayoutOrder = ordre or 0, Visible = false, Parent = parent },
	{ UI.coin(99, true), creer("UIPadding", { PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7) }), UI.contour(couleur, 1, 0.1) })
end
-- Change le texte et la couleur d'un badge
function UI.reglerBadge(badge, nom, couleur)
	if nom then badge.Text = UI.majuscules(nom) end
	if couleur then
		badge.TextColor3 = couleur
		badge.BackgroundColor3 = couleur
		local stroke = badge:FindFirstChildOfClass("UIStroke")
		if stroke then stroke.Color = couleur end
	end
end

-- Interrupteur à bascule : renvoie { regler(valeur), valeur() }
-- (V6.7 : piste creusée, bille avec reflet et point de couleur, le nom s'allume quand il est actif ;
--  V6.9.10.6 : ligne de 44 px (cible tactile), piste et bille carrées en Confinement)
function UI.interrupteur(parent, nom, description, couleur, ordre)
	local ligne = creer("TextButton", { Name = "Interrupteur", Size = UDim2.new(1, 0, 0, J.cible), BackgroundTransparency = 1, Text = "",
		LayoutOrder = ordre or 0, Parent = parent })
	local etiquette = UI.texte({ Text = nom, Font = UI.POLICE_GRAS, TextSize = 14, Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, -60, 0, 18), Parent = ligne })
	UI.texte({ Text = description, TextSize = 11, TextColor3 = C.texte2, Position = UDim2.fromOffset(0, 22),
		Size = UDim2.new(1, -60, 0, 16), Parent = ligne })
	local piste = creer("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(48, 26), BackgroundColor3 = C.gris, Parent = ligne }, { UI.coin(99, true), UI.contour(Color3.new(0, 0, 0), 1, 0.7) })
	UI.decor(creer("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(150, 150, 150), C.blanc), Parent = piste }), "horsConfinement")
	local bille = creer("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(20, 20), BackgroundColor3 = C.texte, Parent = piste }, { UI.coin(99, true) })
	UI.decor(creer("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.blanc, Color3.fromRGB(190, 195, 210)), Parent = bille }), "horsConfinement")
	local point = creer("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(6, 6),
		BackgroundColor3 = C.gris, Parent = bille }, { UI.coin(99) })
	local lueur = creer("UIStroke", { Color = couleur, Thickness = 2, Transparency = 1, Parent = piste })

	local etat = false
	local inter = { ligne = ligne }
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

-- UI.puce(parent, texte, proprietes) → puce { bouton, regler(actif), actif }
-- Puce de la charte : coins coupés (8 px), filet ; choisie = fond jaune et texte sombre. 44 px de haut par défaut.
function UI.puce(parent, texteBouton, proprietes)
	local base = { Name = "Puce", Size = UDim2.new(0, 120, 0, J.cible), BackgroundColor3 = C.ambre, BackgroundTransparency = 1, Text = UI.majuscules(texteBouton),
		Font = UI.POLICE_GRAS, TextSize = 13, TextColor3 = C.texte2, TextTruncate = Enum.TextTruncate.AtEnd, AutoButtonColor = false, Parent = parent }
	for cle, valeur in proprietes or {} do base[cle] = valeur end
	local bouton = creer("TextButton", base, { UI.coin(8) })
	local contour = UI.contour(C.ligne, 1, 0)
	contour.Name = "Contour"
	contour.Parent = bouton
	UI.decouper(bouton, J.coupePuce, { contour = C.ligne, transparenceContour = 0 })
	local puce = { bouton = bouton, actif = false }
	function puce.regler(actif)
		puce.actif = actif == true
		bouton:SetAttribute("Actif", puce.actif)
		poserFond(bouton, C.ambre, puce.actif and 0 or 1)
		bouton.TextColor3 = puce.actif and C.sombre or C.texte2
		UI.teinterContour(bouton, puce.actif and C.ambre or C.ligne, 0)
	end
	bouton.MouseEnter:Connect(function() if not puce.actif then bouton.TextColor3 = C.texte end end)
	bouton.MouseLeave:Connect(function() puce.regler(puce.actif) end)
	registrePuces[bouton] = puce
	puce.regler(false)
	return puce
end

-- Sélecteur de mode (V6.9) : une rangée de segments, un seul actif à la fois. Chaque segment se comporte comme un
-- interrupteur pour TardisCommandes.lierInterrupteurs (regler(valeur), valeur(), surChangement(actif)).
-- modes = { { cle = "classique", nom = "Classique", couleur = Color3 }, ... } ; renvoie { [cle] = segment }, cadre
-- V6.9.10.6 : les segments sont des puces (UI.puce) ; options = { colonnes = n } pour les ranger sur plusieurs lignes.
function UI.selecteurModes(parent, modes, ordre, taille, options)
	options = options or {}
	local cadre = creer("Frame", { Name = "SelecteurModes", Size = taille or UDim2.new(1, 0, 0, J.cible), BackgroundTransparency = 1, LayoutOrder = ordre or 0, Parent = parent })
	local n = #modes
	local colonnes = math.max(1, math.min(options.colonnes or n, n))
	local lignes = math.ceil(n / colonnes)
	creer("UIGridLayout", { CellSize = UDim2.new(1 / colonnes, -6 * (colonnes - 1) / colonnes, 1 / lignes, -6 * (lignes - 1) / lignes),
		CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = cadre })
	local segments = {}
	for i, m in modes do
		-- (cinq puces ou plus sur une ligne : texte un peu plus petit, pour « SAUVETAGE » et « SILENCIEUX »)
		local puce = UI.puce(cadre, m.nom, { LayoutOrder = i, Name = "Mode_" .. m.cle, TextSize = colonnes >= 5 and 11 or 13 })
		local segment = { actif = false, bouton = puce.bouton, puce = puce }
		function segment.regler(valeur)
			segment.actif = valeur == true
			puce.regler(segment.actif)
		end
		function segment.valeur() return segment.actif end
		puce.bouton.Activated:Connect(function() if segment.surChangement then segment.surChangement(not segment.actif) end end)
		segments[m.cle] = segment
	end
	return segments, cadre
end

--------------------------------------------------------------------
-- Briques de la charte (V6.9.10.6), pour les menus et pour la phase 2
--------------------------------------------------------------------
-- UI.boutonCoupe(parent, texte, variante, proprietes) → TextButton
-- Bouton à coins coupés (10 px), 46 px de haut par défaut, titre en Michroma majuscules.
-- variante : "principal" (cyan plein, texte sombre), "secondaire" (filet), "danger" (filet rouge). Gère UI.setDisponible.
function UI.boutonCoupe(parent, texteBouton, variante, proprietes)
	local base = { Name = "BoutonCoupe", Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = C.cyan, BackgroundTransparency = 1, Text = UI.majuscules(texteBouton),
		Font = UI.POLICE_TITRE, TextSize = 13, TextColor3 = C.texte, TextWrapped = true, Parent = parent }
	for cle, valeur in proprietes or {} do base[cle] = valeur end
	local bouton = creer("TextButton", base, { UI.coin(10) })
	local contour = UI.contour(C.ligne, 1, 0)
	contour.Name = "Contour"
	contour.Parent = bouton
	UI.decouper(bouton, J.coupeBouton, { contour = C.ligne, transparenceContour = 0 })
	bouton:SetAttribute("Variante", variante or "secondaire")
	registreBoutons[bouton] = true
	UI.rendreVivant(bouton)
	UI.peindreBouton(bouton)
	return bouton
end

-- UI.plaque(parent, titre, badge, sousLigne, options) → plaque { cadre, titre, badge, sousLigne, bande, majSousLigne(t), majBadge(t, c) }
-- En-tête « plaque » : titre en Michroma majuscules, badge d'accès (ACCÈS NIV. 3, PILOTE, C.T.A.T., TECHNICIEN), ligne de
-- données discrète (« OBJ. TARDIS-01 · POSÉ · CLASSIQUE ») et la bande de danger en bas (rouge pendant l'alerte).
-- options : { hauteur = 60, position, taille, tailleTitre = 16, droite = px réservés à droite, badgeColle = bool (badge juste
--             après le titre au lieu du bord droit), largeurBande, exterieur (bande liée à son alerte), zIndex, ordre }
function UI.plaque(parent, titre, texteBadge, sousLigne, options)
	options = options or {}
	local hauteur = options.hauteur or 60
	local droite = options.droite or 0
	local cadre = creer("Frame", { Name = "Plaque", Position = options.position or UDim2.new(), Size = options.taille or UDim2.new(1, 0, 0, hauteur),
		BackgroundTransparency = 1, ZIndex = options.zIndex or 1, LayoutOrder = options.ordre or 0, Parent = parent })
	local etiquette, badge
	if options.badgeColle then
		local rangee = creer("Frame", { Name = "LigneTitre", Size = UDim2.new(1, -droite, 0, 24), BackgroundTransparency = 1, Parent = cadre }, { UI.pile(12, true) })
		rangee:FindFirstChildOfClass("UIListLayout").VerticalAlignment = Enum.VerticalAlignment.Center
		etiquette = UI.texte({ Name = "Titre", Text = UI.majuscules(titre), Font = UI.POLICE_TITRE, TextSize = options.tailleTitre or 16,
			Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 1, Parent = rangee })
		badge = UI.badge(rangee, texteBadge or "", C.cyan, 2)
	else
		etiquette = UI.texte({ Name = "Titre", Text = UI.majuscules(titre), Font = UI.POLICE_TITRE, TextSize = options.tailleTitre or 16,
			Size = UDim2.new(1, -droite - 120, 0, 24), TextTruncate = Enum.TextTruncate.AtEnd, Parent = cadre })
		badge = UI.badge(cadre, texteBadge or "", C.cyan, 0)
		badge.AnchorPoint = Vector2.new(1, 0)
		badge.Position = UDim2.new(1, -droite, 0, 2)
	end
	badge.Name = "BadgePlaque"
	badge.Visible = texteBadge ~= nil and texteBadge ~= ""
	local sous = UI.texte({ Name = "SousLigne", Text = UI.majuscules(sousLigne or ""), Font = UI.POLICE_CODE, TextSize = 11, TextColor3 = C.texte2,
		Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, -droite, 0, 14), TextTruncate = Enum.TextTruncate.AtEnd, Parent = cadre })
	local bande = UI.bandeDanger({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Parent = cadre }, { largeur = options.largeurBande or 1400 })
	local plaque = { cadre = cadre, titre = etiquette, badge = badge, sousLigne = sous, bande = bande }
	function plaque.majSousLigne(t)
		local texteMaj = UI.majuscules(t)
		if sous.Text ~= texteMaj then sous.Text = texteMaj end
	end
	function plaque.majBadge(t, couleur)
		UI.reglerBadge(badge, t, couleur)
		badge.Visible = t ~= nil and t ~= ""
	end
	if options.exterieur then UI.lierBandeAlerte(bande, options.exterieur) end
	return plaque
end

-- UI.jaugeSegments(parent, nom, options) → jauge { cadre, nom, valeur, segments, allumes, regler(pourcent, couleur, texte) }
-- Jauge de la charte : 10 petits cadres alignés, le nombre allumé suit la valeur (de 10 % en 10 %, arrondi ; au moins un
-- segment dès que la valeur dépasse 0), le chiffre exact est écrit à côté (« Valeur »). nom = nil : les segments seuls.
-- options : { segments = 10, hauteurSegment = 12 (16 : grosse jauge), ordre, nomObjet, largeurValeur = 110 }
function UI.jaugeSegments(parent, nom, options)
	options = options or {}
	local nombre = options.segments or 10
	local hauteur = options.hauteurSegment or 12
	local haut = nom and 22 or 0
	local cadre = creer("Frame", { Name = options.nomObjet or "JaugeSegments", Size = UDim2.new(1, 0, 0, haut + hauteur), BackgroundTransparency = 1,
		LayoutOrder = options.ordre or 0, Parent = parent })
	local jauge = { cadre = cadre, segments = {}, allumes = 0, dernier = nil }
	if nom then
		local largeur = options.largeurValeur or 110
		jauge.nom = UI.texte({ Name = "Nom", Text = UI.majuscules(nom), Font = UI.POLICE_GRAS, TextSize = 13, Size = UDim2.new(1, -largeur, 0, 18), Parent = cadre })
		jauge.valeur = UI.texte({ Name = "Valeur", Text = "—", Font = UI.POLICE_CODE, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.new(1, -largeur, 0, 0), Size = UDim2.fromOffset(largeur, 18), Parent = cadre })
	end
	local rangee = creer("Frame", { Name = "Segments", Position = UDim2.fromOffset(0, haut), Size = UDim2.new(1, 0, 0, hauteur), BackgroundTransparency = 1, Parent = cadre },
	{ UI.pile(3, true) })
	for i = 1, nombre do
		jauge.segments[i] = creer("Frame", { Name = "Segment", Size = UDim2.new(1 / nombre, -3 * (nombre - 1) / nombre, 1, 0), BackgroundColor3 = C.gris,
			BorderSizePixel = 0, LayoutOrder = i, Parent = rangee })
	end
	function jauge.regler(pourcent, couleur, texteValeur)
		local p = math.clamp(tonumber(pourcent) or 0, 0, 100)
		local allumes = math.floor(p / 100 * nombre + 0.5)
		if p > 0 and allumes == 0 then allumes = 1 end
		for i, segment in jauge.segments do
			segment.BackgroundColor3 = i <= allumes and (couleur or C.cyan) or C.gris
		end
		jauge.allumes = allumes
		jauge.dernier = { p, couleur, texteValeur }
		cadre:SetAttribute("Allumes", allumes)
		if jauge.valeur then
			jauge.valeur.Text = texteValeur or string.format("%d %%", p)
			jauge.valeur.TextColor3 = couleur or C.texte
		end
	end
	registreJauges[cadre] = jauge
	return jauge
end

-- UI.tableau(parent, colonnes, options) → tableau { cadre, entete, corps, lignes, ajouter(valeurs, opts) → ligne, vider() }
-- Tableau de la charte (destinations, pannes, journal, pistes) : en-têtes en police de données discrète, lignes séparées
-- par un filet, ligne choisie sur fond jaune avec un texte sombre. Trois colonnes au plus sur téléphone.
-- colonnes = { { cle = "nom", titre = "DESTINATION", largeur = UDim.new(1, -150), droite = bool, donnees = bool,
--                majuscules = bool (vrai par défaut), retrait = px }, ... }
-- options : { taille = UDim2, hauteurLigne = 44, ordre, nom, defilement = true }
-- ligne : { bouton, cellules = { [cle] = TextLabel }, choisir(oui), regler(cle, texte, couleur), discret, couleurs } ;
-- tableau.retirer(ligne) enlève une seule ligne
-- opts de ajouter : { couleurs = { [cle] = Color3 }, discret = bool (ligne grisée), ordre, nom, action = fonction }
function UI.tableau(parent, colonnes, options)
	options = options or {}
	local hauteurLigne = options.hauteurLigne or J.cible
	local cadre = creer("Frame", { Name = options.nom or "Tableau", Size = options.taille or UDim2.new(1, 0, 0, 20 + hauteurLigne * 4), BackgroundTransparency = 1,
		LayoutOrder = options.ordre or 0, Parent = parent })
	local entete = creer("Frame", { Name = "Entete", Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Parent = cadre })
	local positions = {}
	local xs, xo = 0, 0
	for i, col in colonnes do
		positions[i] = { xs, xo }
		xs += col.largeur.Scale
		xo += col.largeur.Offset
	end
	for i, col in colonnes do
		UI.texte({ Name = "Titre_" .. col.cle, Text = UI.majuscules(col.titre or ""), Font = UI.POLICE_CODE, TextSize = 11, TextColor3 = C.texte2,
			TextXAlignment = col.droite and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left,
			Position = UDim2.new(positions[i][1], positions[i][2] + 8, 0, 0), Size = UDim2.new(col.largeur.Scale, col.largeur.Offset - 16, 1, 0), Parent = entete })
	end
	local corps
	if options.defilement == false then
		corps = creer("Frame", { Name = "Corps", Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 1, -20), BackgroundTransparency = 1, Parent = cadre }, { UI.pile(0) })
	else
		corps = creer("ScrollingFrame", { Name = "Corps", Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 1, -20), BackgroundTransparency = 1,
			BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = C.cyan, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y, Parent = cadre }, { UI.pile(0) })
	end
	local tableau = { cadre = cadre, entete = entete, corps = corps, lignes = {}, colonnes = colonnes }
	function tableau.ajouter(valeurs, opts)
		opts = opts or {}
		local ligne = { valeurs = valeurs, cellules = {}, couleurs = opts.couleurs or {}, discret = opts.discret == true, choisi = false }
		local bouton = creer("TextButton", { Name = opts.nom or "Ligne", Size = UDim2.new(1, -4, 0, hauteurLigne), BackgroundColor3 = C.ambre, BackgroundTransparency = 1,
			Text = "", AutoButtonColor = false, LayoutOrder = opts.ordre or (#tableau.lignes + 1), Parent = corps })
		creer("Frame", { Name = "Filet", Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = C.ligne, BackgroundTransparency = 0.4, BorderSizePixel = 0, Parent = bouton })
		for i, col in colonnes do
			local valeur = tostring(valeurs[col.cle] or "")
			ligne.cellules[col.cle] = UI.texte({ Name = "Cellule_" .. col.cle, Text = col.majuscules == false and valeur or UI.majuscules(valeur),
				Font = col.donnees and UI.POLICE_CODE or UI.POLICE, TextSize = col.donnees and 12 or 14,
				TextXAlignment = col.droite and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.new(positions[i][1], positions[i][2] + 8 + (col.retrait or 0), 0, 1),
				Size = UDim2.new(col.largeur.Scale, col.largeur.Offset - 16 - (col.retrait or 0), 1, -1), Parent = bouton })
		end
		ligne.bouton = bouton
		function ligne.peindre()
			bouton.BackgroundColor3 = C.ambre
			bouton.BackgroundTransparency = ligne.choisi and 0 or 1
			for cle, cellule in ligne.cellules do
				cellule.TextColor3 = ligne.choisi and C.sombre or (ligne.couleurs[cle] or (ligne.discret and C.texte2 or C.texte))
			end
		end
		function ligne.choisir(oui)
			ligne.choisi = oui == true
			bouton:SetAttribute("Choisi", ligne.choisi)
			ligne.peindre()
		end
		function ligne.regler(cle, texteCellule, couleur)
			local cellule = ligne.cellules[cle]
			if not cellule then return end
			if texteCellule then cellule.Text = UI.majuscules(texteCellule) end
			if couleur ~= nil then ligne.couleurs[cle] = couleur end
			ligne.peindre()
		end
		bouton.MouseEnter:Connect(function()
			if ligne.choisi then return end
			bouton.BackgroundColor3 = C.cyan
			bouton.BackgroundTransparency = 0.92
		end)
		bouton.MouseLeave:Connect(function() ligne.peindre() end)
		if opts.action then bouton.Activated:Connect(opts.action) end
		table.insert(tableau.lignes, ligne)
		ligne.peindre()
		return ligne
	end
	function tableau.vider()
		for _, ligne in tableau.lignes do ligne.bouton:Destroy() end
		table.clear(tableau.lignes)
	end
	-- Retire une seule ligne (journal limité à N lignes, par exemple)
	function tableau.retirer(ligne)
		local index = table.find(tableau.lignes, ligne)
		if index then table.remove(tableau.lignes, index) end
		ligne.bouton:Destroy()
	end
	registreTableaux[cadre] = tableau
	return tableau
end

-- UI.carteEtat(parent, titre, proprietes) → carte { cadre, bord, titre, valeur, regler(texte, couleurTexte, couleurBord) }
-- Carte d'état de la tablette : bord gauche de couleur (3 px), étiquette discrète, valeur en majuscules.
function UI.carteEtat(parent, titre, proprietes)
	local base = { Name = "CarteEtat", Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = C.panneau, BorderSizePixel = 0, Parent = parent }
	for cle, valeur in proprietes or {} do base[cle] = valeur end
	local cadre = creer("Frame", base, { UI.coin(6) })
	local bord = creer("Frame", { Name = "Bord", Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = C.ligne, BorderSizePixel = 0, Parent = cadre })
	local etiquette = UI.texte({ Name = "Titre", Text = UI.majuscules(titre), Font = UI.POLICE_CODE, TextSize = 11, TextColor3 = C.texte2,
		Position = UDim2.fromOffset(13, 7), Size = UDim2.new(1, -20, 0, 14), Parent = cadre })
	local valeur = UI.texte({ Name = "Valeur", Text = "—", Font = UI.POLICE_GRAS, TextSize = 15, TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(13, 23), Size = UDim2.new(1, -20, 0, 22), Parent = cadre })
	local carte = { cadre = cadre, bord = bord, titre = etiquette, valeur = valeur }
	function carte.regler(texteValeur, couleur, couleurBord)
		valeur.Text = UI.majuscules(texteValeur)
		valeur.TextColor3 = couleur or C.texte
		bord.BackgroundColor3 = couleurBord or C.ligne
	end
	return carte
end

-- UI.etiquette(parent, texte, proprietes) → TextLabel : petite étiquette en police de données, discrète, en majuscules
function UI.etiquette(parent, texteEtiquette, proprietes)
	local base = { Name = "Etiquette", Text = UI.majuscules(texteEtiquette), Font = UI.POLICE_CODE, TextSize = 11, TextColor3 = C.texte2,
		Size = UDim2.new(1, 0, 0, 14), Parent = parent }
	for cle, valeur in proprietes or {} do base[cle] = valeur end
	return UI.texte(base)
end

-- UI.ligneAide(parent, texte, proprietes) → TextLabel : ligne d'aide en police de données (« ↑ ↓ choisir · Entrée DÉMAT »)
function UI.ligneAide(parent, texteAide, proprietes)
	local base = { Name = "Aide", Text = texteAide, Font = UI.POLICE_CODE, TextSize = 11, TextColor3 = C.texte2, TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), Parent = parent }
	for cle, valeur in proprietes or {} do base[cle] = valeur end
	return UI.texte(base)
end

-- UI.champRecherche(parent, proprietes) → TextBox : champ de recherche de la charte (fond légèrement éclairci, icône à gauche)
function UI.champRecherche(parent, proprietes)
	local base = { Name = "Recherche", Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = C.panneau, Text = "", PlaceholderText = "Rechercher une destination",
		PlaceholderColor3 = C.texte2, TextColor3 = C.texte, Font = UI.POLICE, TextSize = 14, ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left, Parent = parent }
	for cle, valeur in proprietes or {} do base[cle] = valeur end
	local champ = creer("TextBox", base, { UI.coin(8), UI.contour(C.ligne, 1, 0.5),
		creer("UIPadding", { PaddingLeft = UDim.new(0, 32), PaddingRight = UDim.new(0, 12) }) })
	UI.texte({ Name = "Icone", Text = "○", TextSize = 14, TextColor3 = C.texte2, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(-24, 0),
		Size = UDim2.new(0, 16, 1, 0), Parent = champ })
	return champ
end

-- UI.notification(proprietes, options) → notification { cadre, contenu, badge, message, bande, regler(message, genre, badge) }
-- Notification de la charte : panneau à coins coupés (10 px), badge à gauche, message à droite. Genres :
--   "info" (badge TARDIS, cyan) · "alerte" (badge ALERTE rouge, filet rouge et bande de danger rouge) ·
--   "refus" (badge REFUSÉ jaune) · "attention" (badge jaune, texte au choix).
-- Le contenu est une pile : on peut y ajouter des boutons (LayoutOrder 10 et plus). Le cadre reste caché (Visible = false)
-- jusqu'à ce que l'appelant l'affiche ; il garde ses propres animations.
local GENRES_NOTIFICATION = { info = { "TARDIS", "cyan" }, alerte = { "ALERTE", "rouge" }, refus = { "REFUSÉ", "ambre" }, attention = { "ATTENTION", "ambre" } }
function UI.notification(proprietes, options)
	options = options or {}
	local base = { Name = "Notification", Size = UDim2.fromOffset(420, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.fond,
		BackgroundTransparency = 0.04, Visible = false }
	for cle, valeur in proprietes or {} do base[cle] = valeur end
	local cadre, contenu = UI.panneauCoupe(base, { coupe = 10, rayon = 12, balayage = false })
	contenu.Size = UDim2.new(1, 0, 0, 0)
	contenu.AutomaticSize = Enum.AutomaticSize.Y
	creer("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), Parent = contenu })
	UI.pile(8).Parent = contenu
	local ligne = creer("Frame", { Name = "Ligne", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 1, Parent = contenu })
	local badge = UI.badge(ligne, "TARDIS", C.cyan, 0)
	badge.Visible = true
	local retrait = options.retrait or 96
	local message = UI.texte({ Name = "Texte", Text = "", TextSize = options.tailleTexte or 14, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromOffset(retrait, 0), Size = UDim2.new(1, -retrait, 0, 0), TextXAlignment = options.alignement or Enum.TextXAlignment.Left, Parent = ligne })
	local bande = UI.bandeDanger({ LayoutOrder = 2, Visible = false, Parent = contenu }, { largeur = 520 })
	UI.reglerBande(bande, true)
	local notification = { cadre = cadre, contenu = contenu, badge = badge, message = message, bande = bande }
	function notification.regler(texteMessage, genre, texteBadge)
		genre = GENRES_NOTIFICATION[genre] and genre or "info"
		local g = GENRES_NOTIFICATION[genre]
		local couleur = C[g[2]]
		UI.reglerBadge(badge, texteBadge or g[1], couleur)
		message.Text = texteMessage or ""
		message.TextColor3 = genre == "alerte" and UI.eclaircir(C.rouge, 0.55) or C.texte
		UI.teinterContour(cadre, genre == "alerte" and C.rouge or (genre == "info" and C.cyan or C.ligne), genre == "alerte" and 0 or 0.45)
		bande.Visible = genre == "alerte"
		cadre:SetAttribute("Genre", genre)
	end
	notification.regler("", "info")
	return notification
end

-- Code d'objet d'un TARDIS pour les plaques : « OBJ. TARDIS-01 » (sa place dans Config.Tardis)
function UI.codeObjet(def)
	local index = 1
	for i, d in Config.Tardis or {} do
		if d == def or (def and d.Nom == def.Nom) then index = i end
	end
	return string.format("OBJ. TARDIS-%02d", index)
end

-- Texte d'un badge de plaque (Config.Interface.Badges), avec sa valeur par défaut
function UI.texteBadge(cle, defaut)
	local badges = (Config.Interface or {}).Badges or {}
	local valeur = badges[cle]
	if type(valeur) == "string" then return valeur end
	return defaut
end

-- Statut d'une destination (colonne STATUT) : "REFUSE" (dans le sous-dossier REFUSE ou dans une de ses zones : seule
-- l'urgence y atterrit), "VITESSE_REDUITE" (V6.9.11 : Classique ou Silencieux seulement), "SANS_EXPRESS" (le Rapide y
-- devient Classique), sinon "ACCORDE". Renvoie code, libellé, couleur ;
-- nil, "—" si la pièce n'est pas visible (Streaming). Mêmes zones que le serveur (marge de 6 studs).
function UI.statutDestination(nom)
	local dossier = Config.dossierDestinations(false)
	local part = dossier and dossier:FindFirstChild(nom, true)
	if not part then return nil, "—", C.texte2 end
	local function dans(nomZone)
		local zone = dossier:FindFirstChild(nomZone)
		if not zone then return false end
		if part:IsDescendantOf(zone) then return true end
		if not part:IsA("BasePart") then return false end
		for _, piece in zone:GetDescendants() do
			if piece:IsA("BasePart") and piece ~= part then
				local p = piece.CFrame:PointToObjectSpace(part.Position)
				local demi = piece.Size / 2 + Vector3.new(6, 6, 6)
				if math.abs(p.X) <= demi.X and math.abs(p.Y) <= demi.Y and math.abs(p.Z) <= demi.Z then return true end
			end
		end
		return false
	end
	if dans(Config.ZoneRestreinte or "REFUSE") then return "REFUSE", "REFUSÉ", C.rouge end
	-- (V6.9.11) Zone à vitesse réduite : seuls le Classique et le Silencieux (avant SANS_EXPRESS : elle interdit plus)
	if dans(Config.ZoneVitesseReduite or "VITESSE_REDUITE") then return "VITESSE_REDUITE", "VITESSE RÉDUITE", C.ambre end
	if dans(Config.ZoneSansExpress or "SANS_EXPRESS") then return "SANS_EXPRESS", "SANS RAPIDE", C.ambre end
	return "ACCORDE", "ACCORDÉ", C.vert
end

--------------------------------------------------------------------
-- Thèmes d'interface
--------------------------------------------------------------------
UI.THEMES = {
	-- V6.9.10.6 : la charte « Hologramme de confinement » (ZONE-TSADE), thème par défaut : bleu nuit, filet cyan, jaune choisi
	Confinement = { fond = J.panneau, ecran = Color3.fromRGB(8, 18, 31), panneau = Color3.fromRGB(20, 33, 49),
		panneauClair = Color3.fromRGB(30, 46, 63), ligne = J.ligne, bleu = J.ligne, ambre = J.jaune, cyan = J.cyan,
		texte = J.texte, texte2 = J.discret, gris = Color3.fromRGB(35, 49, 64), creux = Color3.fromRGB(7, 16, 29),
		vert = J.vert, rouge = J.rouge, sombre = J.sombre, coins = 0, bordure = 1, transparence = 0, nom = "Hologramme de confinement" },
	-- Le TARDIS du 15e Docteur : ivoire, gris perle, or miel
	Gallifrey = { fond = Color3.fromRGB(238, 233, 222), ecran = Color3.fromRGB(246, 242, 234), panneau = Color3.fromRGB(252, 250, 246),
		panneauClair = Color3.fromRGB(228, 220, 204), bleu = Color3.fromRGB(196, 150, 60), ambre = Color3.fromRGB(176, 120, 28),
		cyan = Color3.fromRGB(200, 140, 40), texte = Color3.fromRGB(42, 38, 34), texte2 = Color3.fromRGB(120, 110, 96), gris = Color3.fromRGB(214, 206, 192),
		creux = Color3.fromRGB(226, 218, 202), coins = 1.7, bordure = 0.6, transparence = 0.3, nom = "Gallifrey (15e Docteur)" },
	-- Le TARDIS du 13e Docteur : bleu nuit et cristaux ambrés
	Cristal = { fond = Color3.fromRGB(6, 9, 24), ecran = Color3.fromRGB(9, 13, 32), panneau = Color3.fromRGB(16, 22, 52),
		panneauClair = Color3.fromRGB(32, 40, 86), bleu = Color3.fromRGB(46, 60, 130), ambre = Color3.fromRGB(255, 160, 40),
		cyan = Color3.fromRGB(255, 190, 90), texte = Color3.fromRGB(240, 236, 228), texte2 = Color3.fromRGB(170, 160, 150), gris = Color3.fromRGB(44, 48, 70),
		creux = Color3.fromRGB(4, 6, 18), coins = 0.7, bordure = 1.1, transparence = 0, nom = "Cristal (13e Docteur)" },
	-- La cabine : bleu TARDIS, blanc crème, cyan pâle
	PoliceBox = { fond = Color3.fromRGB(8, 24, 70), ecran = Color3.fromRGB(10, 30, 86), panneau = Color3.fromRGB(16, 44, 118),
		panneauClair = Color3.fromRGB(28, 66, 156), bleu = Color3.fromRGB(0, 61, 165), ambre = Color3.fromRGB(245, 236, 210),
		cyan = Color3.fromRGB(150, 220, 255), texte = Color3.fromRGB(250, 248, 240), texte2 = Color3.fromRGB(180, 200, 230), gris = Color3.fromRGB(26, 50, 110),
		creux = Color3.fromRGB(4, 12, 40), coins = 0.35, bordure = 1.6, transparence = 0, nom = "Police Box (la cabine)" },
}
UI.ORDRE_THEMES = { "Confinement", "Gallifrey", "Cristal", "PoliceBox" }
UI.THEME_DEFAUT = "Confinement" -- (V6.9.10.6) thème de tout le monde, sauf choix contraire dans les réglages

-- Dégradé des barres d'en-tête (tablette, menu), calculé depuis le thème courant
function UI.degradeEntete()
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, C.panneau), ColorSequenceKeypoint.new(0.4, C.panneauClair),
		ColorSequenceKeypoint.new(0.7, C.bleu), ColorSequenceKeypoint.new(1, C.ecran),
	})
end

-- Remet à jour tout le décor qui dépend du thème ou de « Réduire les effets » (aucune boucle image par image)
function UI.majDecor()
	for objet, genre in registreDecor do
		if objet.Parent then appliquerDecor(objet, genre) end
	end
	local conf = UI.estConfinement()
	for objet, t in registreFonds do
		if objet.Parent then objet.BackgroundTransparency = conf and t.conf or t.hors end
	end
	for objet, d in registreDuo do
		if objet.Parent then
			objet[d.propriete] = conf and C[d.conf] or (d.horsRole and C[d.horsRole] or d.hors)
		end
	end
	for bouton in registreBoutons do
		if bouton.Parent then UI.peindreBouton(bouton) end
	end
	for bouton, puce in registrePuces do
		if bouton.Parent then puce.regler(puce.actif) end
	end
	for cadre in registreBandes do
		if cadre.Parent then UI.reglerBande(cadre, cadre:GetAttribute("Alerte") == true) end
	end
	for cadre, jauge in registreJauges do
		if cadre.Parent and jauge.dernier then jauge.regler(jauge.dernier[1], jauge.dernier[2], jauge.dernier[3]) end
		if cadre.Parent and not jauge.dernier then
			for _, segment in jauge.segments do segment.BackgroundColor3 = C.gris end
		end
	end
	for cadre, tableau in registreTableaux do
		if cadre.Parent then
			for _, ligne in tableau.lignes do ligne.peindre() end
		end
	end
end

function UI.appliquerTheme(nom)
	local theme = UI.THEMES[nom]
	if not theme then return end
	themeActuel = nom
	for _, role in ROLES_COULEUR do
		C[role] = theme[role] or (role == "ligne" and theme.bleu) or UI.BASE[role]
	end
	-- Libellés des états : leurs couleurs suivent le thème
	UI.LIBELLES[E.Pose][2] = C.vert
	UI.LIBELLES[E.Demat][2] = C.ambre
	UI.LIBELLES[E.Vol][2] = C.cyan
	UI.LIBELLES[E.Remat][2] = C.ambre
	-- Formes : coins et bordures
	formeActuelle = { coins = theme.coins or 1, bordure = theme.bordure or 1, transparence = theme.transparence or 0 }
	for coin, infos in registreCoins do
		if coin.Parent then coin.CornerRadius = UDim.new(0, rayonDe(infos.rayon, infos.anguleux)) end
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
	UI.majDecor()
end

--------------------------------------------------------------------
-- Préférences du joueur (favoris, touches, thème d'interface, sons), sauvegardées par le serveur
--------------------------------------------------------------------
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local joueurLocal = Players.LocalPlayer
-- Le thème ne s'applique que chez les joueurs : le serveur garde la palette de départ (écrans de la console)
local estClient = false
pcall(function() estClient = RunService:IsClient() end)
UI.prefs = {}
local prefsChargees = false
local nouveauJoueur = false -- aucune préférence sauvegardée à l'arrivée : le joueur n'a jamais ouvert les réglages

local envoiPrevu = false
function UI.sauverPrefs()
	-- Première sauvegarde : le mode débutant choisi d'office (voir UI.debutant) est gardé tel quel
	if UI.prefs.debutant == nil then UI.prefs.debutant = UI.debutant() end
	if envoiPrevu then return end
	envoiPrevu = true
	task.delay(0.5, function()
		envoiPrevu = false
		-- V6.9.9 (correction T-1) : depuis les canaux par TARDIS, il n'existe plus de « TardisCommande » tout court.
		-- Les préférences partent par le canal du premier TARDIS (ordre alphabétique : toujours le même).
		local remote = nil
		for _, enfant in ReplicatedStorage:GetChildren() do
			if enfant:IsA("RemoteEvent") and string.sub(enfant.Name, 1, 15) == "TardisCommande_" and (remote == nil or enfant.Name < remote.Name) then
				remote = enfant
			end
		end
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

-- Choix du thème dans les réglages (V6.9.10.6) : appliqué, sauvegardé, et la migration ne reviendra plus dessus
function UI.choisirTheme(nom)
	if not UI.THEMES[nom] then return end
	UI.appliquerTheme(nom)
	UI.prefs.migrationConfinement = true
	UI.setPref("theme", nom)
end

local function lirePrefs()
	if not joueurLocal then return end
	local json = joueurLocal:GetAttribute("TardisPrefs")
	if typeof(json) ~= "string" then return end
	local ok, valeur = pcall(HttpService.JSONDecode, HttpService, json)
	if ok and type(valeur) == "table" then
		UI.prefs = valeur
		prefsChargees = true
		nouveauJoueur = next(valeur) == nil
		-- Migration unique (V6.9.10.6) : un ancien thème sauvegardé passe une fois à « Hologramme de confinement » ;
		-- le joueur peut ensuite reprendre Gallifrey, Cristal ou Police Box dans les réglages (choix gardé ensuite).
		local migrer = type(valeur.theme) == "string" and valeur.theme ~= UI.THEME_DEFAUT and valeur.migrationConfinement ~= true
		if migrer then
			valeur.theme = UI.THEME_DEFAUT
			valeur.migrationConfinement = true
		end
		if estClient then
			UI.appliquerTheme(type(valeur.theme) == "string" and UI.THEMES[valeur.theme] and valeur.theme or UI.THEME_DEFAUT)
			UI.prefsChangees:Fire("theme")
			if migrer then UI.sauverPrefs() end
		end
	end
end

-- Taille de l'interface (0.6 à 1.4), multipliée à l'échelle automatique de chaque menu
function UI.tailleInterface()
	return math.clamp(tonumber(UI.pref("taille", 1)) or 1, 0.6, 1.4)
end

-- Option « réduire les effets » (joueurs sensibles) : saccades d'urgence, flashs, secousses et thème Flashbang adoucis
-- (V6.9.10.6 : coupe aussi les lignes de balayage et la lueur des menus)
function UI.effetsReduits()
	return UI.pref("effetsReduits", false) == true
end
UI.prefsChangees.Event:Connect(function(cle)
	if cle == "effetsReduits" then UI.majDecor() end
end)

-- Option « aucun flash » (V6.9.9, joueurs sensibles à la lumière) : plus aucun éclat, voile blanc, stroboscope ni
-- clignotement rapide (lampe, bouclier, saut temporel, régénération, explosion, enseigne, arcs, éclair du Rapide…).
-- Les grésillements de la cabine en urgence sont aussi adoucis, comme en « réduire les effets ».
function UI.sansFlash()
	return UI.pref("sansFlash", false) == true
end

-- Volume des sons du TARDIS (0 à 1)
function UI.volume()
	return math.clamp(tonumber(UI.pref("volume", 1)) or 1, 0, 1)
end

-- Écran compact (V6.9.10.6) : téléphone (tactile sans clavier) ou fenêtre étroite ; la tablette range alors ses onglets en ligne
function UI.ecranCompact()
	local UserInputService = game:GetService("UserInputService")
	local tactile = false
	pcall(function() tactile = UserInputService.TouchEnabled == true and UserInputService.KeyboardEnabled ~= true end)
	local largeur = 1920
	pcall(function() largeur = workspace.CurrentCamera.ViewportSize.X end)
	return tactile or (largeur > 0 and largeur < 900)
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

-- Thème par défaut chez les joueurs (V6.9.10.6), puis les préférences sauvegardées (elles peuvent arriver plus tard)
if estClient then UI.appliquerTheme(UI.THEME_DEFAUT) end
if joueurLocal then
	lirePrefs()
	joueurLocal:GetAttributeChangedSignal("TardisPrefs"):Connect(function()
		if not prefsChargees then lirePrefs() end -- la première valeur vient du serveur ; ensuite c'est nous qui écrivons
	end)
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
