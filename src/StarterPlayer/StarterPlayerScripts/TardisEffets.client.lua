-- StarterPlayer > StarterPlayerScripts > TardisEffets (LocalScript)
-- (Dé)matérialisation de l'extérieur, lampe, rotor, lumières de la salle, secousses, et depuis la V6.7 :
-- lueur de la cabine, tourbillon de poussière, ondes au sol, arcs d'urgence, choc d'atterrissage.
-- Tout est calculé à partir des attributs "Etat" et "DebutEtat" posés par le serveur (Config.Souffle),
-- donc tous les joueurs voient la même chose au même moment (même ceux qui arrivent en cours de vol).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("TardisConfig"))
local UI = require(ReplicatedStorage:WaitForChild("TardisUI"))
local E = Config.Etats
local EFFETS = Config.Effets or {}
local joueur = Players.LocalPlayer

local def = Config.demarrerPourChaqueTardis(script) -- un exemplaire par TARDIS : tout le monde voit les trois
local exterieur, interieur = Config.modeles(def)
local rotor = interieur:WaitForChild(Config.NomRotor)
local lampe = exterieur:FindFirstChild(Config.NomLampe, true)
local lumiere = lampe and lampe:FindFirstChildWhichIsA("Light", true)

-- Pièce d'effet : ancrée, sans collision, ignorée par les raycasts
local function piece(proprietes)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	for cle, valeur in proprietes do p[cle] = valeur end
	p.Parent = workspace
	return p
end
local function tween(objet, duree, proprietes, style, direction)
	local t = TweenService:Create(objet, TweenInfo.new(duree, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), proprietes)
	t:Play()
	return t
end

-- Tout ce qui s'affiche sur l'extérieur, avec ses valeurs d'origine.
-- Chaque type d'objet a ses propres propriétés à faire disparaître.
local PROPRIETES = {
	-- { classe, { propriétés de transparence }, { propriétés de luminosité }, { propriétés à couper } }
	{ "BasePart",     { "Transparency" }, {}, {} },
	{ "Decal",        { "Transparency" }, {}, {} }, -- inclut les Textures
	{ "ImageLabel",   { "ImageTransparency", "BackgroundTransparency" }, {}, {} },
	{ "ImageButton",  { "ImageTransparency", "BackgroundTransparency" }, {}, {} },
	{ "TextLabel",    { "TextTransparency", "TextStrokeTransparency", "BackgroundTransparency" }, {}, {} },
	{ "TextButton",   { "TextTransparency", "TextStrokeTransparency", "BackgroundTransparency" }, {}, {} },
	{ "GuiObject",    { "BackgroundTransparency" }, {}, {} }, -- Frames et autres éléments d'interface
	{ "Highlight",    { "FillTransparency", "OutlineTransparency" }, {}, {} },
	{ "Light",        {}, { "Brightness" }, {} },
	{ "ParticleEmitter", {}, {}, { "Enabled" } },
	{ "Beam",         {}, {}, { "Enabled" } },
	{ "Trail",        {}, {}, { "Enabled" } },
	{ "Fire",         {}, {}, { "Enabled" } },
	{ "Smoke",        {}, {}, { "Enabled" } },
	{ "Sparkles",     {}, {}, { "Enabled" } },
}

local visuels = {} -- [objet] = { transparences = {...}, luminosites = {...}, actifs = {...} }

local function enregistrer(objet)
	if visuels[objet] or objet == lumiere then return end -- la lumière de la Lampe est gérée à part
	for _, regle in PROPRIETES do
		if objet:IsA(regle[1]) then
			local fiche = { transparences = {}, luminosites = {}, actifs = {} }
			for _, prop in regle[2] do fiche.transparences[prop] = objet[prop] end
			for _, prop in regle[3] do fiche.luminosites[prop] = objet[prop] end
			for _, prop in regle[4] do fiche.actifs[prop] = objet[prop] end
			visuels[objet] = fiche
			return
		end
	end
end

for _, objet in exterieur:GetDescendants() do
	enregistrer(objet)
end
exterieur.DescendantAdded:Connect(enregistrer)
exterieur.DescendantRemoving:Connect(function(objet)
	visuels[objet] = nil
end)

local rotorBase = rotor:GetPivot() -- marche avec une Part OU un Model
local brillanceBase = lumiere and lumiere.Brightness or 0
local porteeBase = lumiere and lumiere.Range or 8
local couleurLampe = lumiere and lumiere.Color or Color3.new(1, 1, 1)

-- Position de la lampe dans le monde (sa lumière est sur une pièce ou sur un Attachment)
local function positionLampe()
	if not lumiere then return exterieur:GetPivot().Position + Vector3.new(0, exterieur:GetExtentsSize().Y / 2, 0) end
	local support = lumiere.Parent
	if support and support:IsA("Attachment") then return support.WorldPosition end
	if support and support:IsA("BasePart") then return support.Position end
	return exterieur:GetPivot().Position + Vector3.new(0, exterieur:GetExtentsSize().Y / 2, 0)
end

-- Rotor coloré selon le mode du voyage (V6.6.2) : ses néons et ses lumières prennent la couleur du mode
-- (Config.Modes[mode].CouleurRotor) pendant le voyage, en fondu, puis retrouvent leur couleur d'origine.
local melangeRotor, couleurRotor = 0, Color3.new(1, 1, 1)
local neonsRotor = {} -- [part] = couleur d'origine
for _, objet in rotor:GetDescendants() do
	if objet:IsA("BasePart") and objet.Material == Enum.Material.Neon then neonsRotor[objet] = objet.Color end
end
if rotor:IsA("BasePart") and rotor.Material == Enum.Material.Neon then neonsRotor[rotor] = rotor.Color end

-- Ambiance de l'intérieur (locale) : noir quand le courant est coupé, teinte rouge en alerte
local Lighting = game:GetService("Lighting")
local expositionOrigine = Lighting.ExposureCompensation
local expositionEcrite = false
local lumieresSalle = {} -- [Light] = { brillance, couleur, facteur } : gestion des lumières de la salle
local listeLumieres = nil -- les Light de la salle, mémorisées
local ambianceOrigine, exterieureOrigine = Lighting.Ambient, Lighting.OutdoorAmbient
local themeActuel = 0 -- 0 = éclairage normal, 1 = thème appliqué (lissé)
local ledsOrigine = {} -- [Light] = couleur d'origine (thèmes de l'intérieur)
local function themeChoisi()
	local nom = exterieur:GetAttribute("Theme")
	for _, theme in Config.Themes or {} do
		if theme.nom == nom then return theme end
	end
	return nil
end
local teinte = Instance.new("ColorCorrectionEffect")
teinte.Name = "TardisAmbiance"
teinte.Parent = Lighting
local noirActuel, rougeActuel = 0, 0 -- 0 = rien, 1 = effet complet (lissés)
local boiteCF, boiteTaille = interieur:GetBoundingBox()

local function dansInterieur(position)
	local p = boiteCF:PointToObjectSpace(position)
	return math.abs(p.X) <= boiteTaille.X / 2
		and math.abs(p.Y) <= boiteTaille.Y / 2
		and math.abs(p.Z) <= boiteTaille.Z / 2
end

-- Camouflage : fondu de 0 (visible) à 1 (invisible) sur Config.DureeCamouflage secondes
local function alphaCamouflage()
	local duree = Config.DureeCamouflage or 2
	local ecoule = workspace:GetServerTimeNow() - (exterieur:GetAttribute("DebutCamouflage") or 0)
	local p = math.clamp(ecoule / duree, 0, 1)
	if exterieur:GetAttribute("Camouflage") then
		return p
	end
	return 1 - p
end

-- Préchargement des sons du TARDIS (sinon le premier son peut arriver en retard le temps de se charger)
task.spawn(function()
	local assets = ReplicatedStorage:FindFirstChild("TardisAssets")
	local sons = assets and assets:FindFirstChild("Sons")
	if sons then
		pcall(function()
			game:GetService("ContentProvider"):PreloadAsync(sons:GetChildren())
		end)
	end
end)

-- Démat / remat pendant le vol libre : même animation que pour un voyage, mais en plein vol
local function alphaVol()
	local phase = exterieur:GetAttribute("VolPhase")
	if phase == "Invisible" or exterieur:GetAttribute("Detruit") == true then return 1 end
	if phase == E.Demat or phase == E.Remat then
		local ecoule = workspace:GetServerTimeNow() - (exterieur:GetAttribute("VolPhaseDebut") or 0)
		return Config.Alpha(phase, ecoule, Config.modeVolDe(exterieur), UI.effetsReduits())
	end
	return 0
end

-- Respiration en cours (voyage ou phase de vol libre) : souffle 0..1, progression 0..1, fond 0..1, et l'état animé
local function respiration()
	local etat = exterieur:GetAttribute("Etat") or E.Pose
	if etat == E.Demat or etat == E.Remat then
		local ecoule = workspace:GetServerTimeNow() - (exterieur:GetAttribute("DebutEtat") or 0)
		local s, p, fond = Config.Souffle(etat, ecoule, Config.modeDe(exterieur))
		return s, p, fond, etat, Config.modeDe(exterieur)
	end
	local phase = exterieur:GetAttribute("VolPhase")
	if phase == E.Demat or phase == E.Remat then
		local ecoule = workspace:GetServerTimeNow() - (exterieur:GetAttribute("VolPhaseDebut") or 0)
		local s, p, fond = Config.Souffle(phase, ecoule, Config.modeVolDe(exterieur))
		return s, p, fond, phase, Config.modeVolDe(exterieur)
	end
	return 0, 0, 0, nil, nil
end

local alphaActuel = 0
local secousseActive = false
local dernierModeAnime = "Normal" -- mode de la dernière animation (le serveur le remet à Normal en posant le TARDIS)
local courseRotor = 0 -- hauteur actuelle du rotor (lissée)
local choc = 0        -- secousse d'arrivée (atterrissage), décroît
local flashLampe = 0  -- éclat de la lampe au départ et à l'arrivée, décroît
local etatPrecedent = exterieur:GetAttribute("Etat") or E.Pose

-- Une erreur dans un effet est signalée une seule fois dans l'Output, sans bloquer les autres effets
local erreursSignalees = {}
local function proteger(nom, fonction, ...)
	local ok, erreur = pcall(fonction, ...)
	if not ok and not erreursSignalees[nom] then
		erreursSignalees[nom] = true
		warn("[TARDIS] Effet '" .. nom .. "' en erreur : " .. tostring(erreur))
	end
end

local function fondu(etat, ecoule, camouflage, mode)
	local alpha = math.max(Config.Alpha(etat, ecoule, mode, UI.effetsReduits()), camouflage)
	if alpha ~= alphaActuel then
		alphaActuel = alpha
		for objet, fiche in visuels do
			if objet.Parent then
				for prop, origine in fiche.transparences do
					objet[prop] = origine + (1 - origine) * alpha
				end
				for prop, origine in fiche.luminosites do
					objet[prop] = origine * (1 - alpha)
				end
				for prop, origine in fiche.actifs do
					objet[prop] = origine and alpha < 0.5
				end
			end
		end
	end
end

--------------------------------------------------------------------
-- Lueur de la cabine (V6.7) : à chaque souffle, la lumière fuit par les fenêtres et la lampe s'entoure d'un halo.
-- Deux pièces d'effet indépendantes du modèle (le fondu de l'extérieur ne les touche pas).
--------------------------------------------------------------------
local lueur, halo = nil, nil
if EFFETS.Lueur ~= false then
	lueur = piece({ Name = "TardisLueur_" .. def.Nom, Transparency = 1, Size = Vector3.one, CFrame = exterieur:GetPivot() })
	local lumiereLueur = Instance.new("PointLight")
	lumiereLueur.Name = "Lumiere"
	lumiereLueur.Brightness, lumiereLueur.Range, lumiereLueur.Shadows = 0, 12, false
	lumiereLueur.Parent = lueur
	halo = piece({ Name = "TardisHalo_" .. def.Nom, Shape = Enum.PartType.Ball, Transparency = 1, Size = Vector3.one, Color = couleurLampe })
end

-- Clé du TARDIS (V6.9) : la lampe clignote deux fois, comme une voiture qu'on verrouille
exterieur:GetAttributeChangedSignal("CleSignal"):Connect(function()
	flashLampe = 0.9
	task.delay(0.35, function() flashLampe = 0.9 end)
end)

RunService.RenderStepped:Connect(function(dt)
	local etat = exterieur:GetAttribute("Etat") or E.Pose
	local ecoule = workspace:GetServerTimeNow() - (exterieur:GetAttribute("DebutEtat") or 0)
	local t = os.clock()
	local reduit = UI.effetsReduits()

	-- 0) Changement d'état : départ (la cabine vient de disparaître) et arrivée (elle vient de se poser)
	-- (Silencieux, V6.9 : aucun éclat ; le serveur remet Mode à Normal en posant le TARDIS, d'où dernierModeAnime)
	local modeDiscret = (Config.Modes[dernierModeAnime] or {}).Discret == true
	if etat ~= etatPrecedent then
		if etat == E.Vol and etatPrecedent == E.Demat then
			if not modeDiscret then flashLampe = 1 end
		elseif etat == E.Pose and etatPrecedent == E.Remat then
			if not modeDiscret then flashLampe = 1 end
			if EFFETS.Choc ~= false then
				local racine = joueur.Character and joueur.Character:FindFirstChild("HumanoidRootPart")
				if racine and dansInterieur(racine.Position) then
					local stabilise = exterieur:GetAttribute("Stabilisateur") ~= false
					local modeArrivee = Config.modeDe(exterieur)
					local force = (modeArrivee == "Catastrophe" and 2.2) or (Config.modeSaccade(modeArrivee) and 1.5) or (modeArrivee == "Sauvetage" and 0.7) or 1
					choc = force * (stabilise and 0.45 or 1) * (reduit and 0.4 or 1)
				end
			end
		end
		etatPrecedent = etat
	end
	flashLampe = math.max(0, flashLampe - dt * 1.8)

	-- 1) Fondu de l'extérieur (le plus invisible des deux : voyage ou camouflage)
	local camouflage = 0
	proteger("camouflage", function()
		-- Le camouflage et la démat en vol rendent tous les deux le TARDIS invisible : on garde le plus fort
		camouflage = math.max(alphaCamouflage(), alphaVol())
	end)
	local mode = Config.modeDe(exterieur)
	local urgence = Config.modeSaccade(mode) -- urgence ou catastrophe : animation contrariée
	-- Vortex temporel : pendant le vol, le TARDIS est visible dans le ciel (le vortex est dessiné par TardisVolLibre)
	local etatFondu = (etat == E.Vol and exterieur:GetAttribute("Ciel") == true) and E.Pose or etat
	proteger("fondu", fondu, etatFondu, ecoule, camouflage, mode)

	-- Respiration : le souffle en cours (voyage ou phase de vol libre), lu une fois par image
	local souffle, progression, fond, etatAnime, modeAnime = 0, 0, 0, nil, nil
	proteger("souffle", function() souffle, progression, fond, etatAnime, modeAnime = respiration() end)
	local enVoyage = etatAnime ~= nil
	if modeAnime then dernierModeAnime = modeAnime end
	local discret = enVoyage and (Config.Modes[modeAnime] or {}).Discret == true -- Silencieux : ni lumière ni effet dehors
	local camoufle = exterieur:GetAttribute("Camouflage") == true
	local visible = (1 - alphaActuel) * (1 - camouflage)

	-- 2) Lampe du toit : elle bat au rythme des souffles, vacille en urgence, éclate au départ et à l'arrivée
	if lumiere then
		local brillance = brillanceBase
		if etat ~= E.Pose or enVoyage then
			if urgence or Config.modeSaccade(modeAnime) then
				-- Urgence : la lampe vacille et coupe de façon irrégulière
				brillance *= (Config.Bruit(ecoule, 15) < 0.35) and 0.05 or (0.5 + 0.5 * Config.Bruit(ecoule + 1.3, 9)) * (0.7 + 0.8 * souffle)
			elseif enVoyage then
				brillance *= 0.3 + 1.6 * souffle -- un éclat à chaque souffle
			else
				brillance *= 0.5 + 0.5 * math.sin(t * Config.VitesseLampe)
			end
		end
		brillance += brillanceBase * 2.5 * flashLampe
		if discret then brillance = 0 end -- Silencieux : la lampe reste éteinte
		if exterieur:GetAttribute("Alimentation") == false then
			brillance = 0 -- plus de courant
		end
		lumiere.Brightness = brillance * (1 - camouflage) -- éteinte quand le TARDIS est camouflé
		lumiere.Range = porteeBase * (1 + 0.6 * souffle + flashLampe)
		-- Alerte : la lampe du toit passe au rouge
		lumiere.Color = exterieur:GetAttribute("Alerte") and (Config.CouleurAlerte or Color3.fromRGB(255, 30, 30)) or couleurLampe
	end

	-- 2 bis) Lueur de la cabine et halo de la lampe
	if lueur then
		proteger("lueur", function()
			local alimente = exterieur:GetAttribute("Alimentation") ~= false
			local intensite = (enVoyage and alimente and not discret) and souffle * visible or 0
			-- Couleur du mode dehors (le Rapide garde sa couleur pour l'intérieur : lumière neutre ici)
			local couleur = Color3.fromRGB(255, 240, 210):Lerp(Config.couleurDehors(modeAnime or mode), 0.45)
			local pivot = exterieur:GetPivot()
			local taille = exterieur:GetExtentsSize()
			lueur.CFrame = pivot
			lueur.Lumiere.Brightness = 3.2 * intensite + 2 * flashLampe * (1 - camouflage)
			lueur.Lumiere.Range = math.max(taille.X, taille.Z) * 1.8 + 6 * souffle
			lueur.Lumiere.Color = couleur
			-- Halo : une sphère de lumière autour de la lampe, qui gonfle à chaque souffle
			local haloIntensite = math.max(intensite, flashLampe * (1 - camouflage) * (alimente and 1 or 0))
			if haloIntensite > 0.01 then
				halo.CFrame = CFrame.new(positionLampe())
				halo.Size = Vector3.one * (0.9 + 2.2 * haloIntensite)
				halo.Color = (exterieur:GetAttribute("Alerte") and (Config.CouleurAlerte or Color3.fromRGB(255, 30, 30)) or couleurLampe):Lerp(Color3.new(1, 1, 1), 0.5)
				halo.Transparency = 1 - 0.55 * haloIntensite
			else
				halo.Transparency = 1
			end
		end)
	end

	-- 2 ter) Ambiance pour le joueur qui se trouve dans l'intérieur
	proteger("ambiance", function()
		local personnage = joueur.Character
		local racineJoueur = personnage and personnage:FindFirstChild("HumanoidRootPart")
		local dedans = racineJoueur ~= nil and dansInterieur(racineJoueur.Position)
		local horsTension = exterieur:GetAttribute("Alimentation") == false
		local alerte = exterieur:GetAttribute("Alerte") == true

		local lissage = math.clamp(dt * 3, 0, 1)
		local cibleNoir = (dedans and horsTension) and 1 or 0
		local cibleRouge = (dedans and alerte) and 1 or 0
		noirActuel += (cibleNoir - noirActuel) * lissage
		rougeActuel += (cibleRouge - rougeActuel) * lissage

		-- Thème de l'intérieur (menu) : ambiance lumineuse de la salle, seulement quand on y est, avec du courant
		local theme = themeChoisi()
		local cibleTheme = (dedans and not horsTension and theme) and 1 or 0
		themeActuel += (cibleTheme - themeActuel) * lissage
		local ambiance, exterieure, exposition = ambianceOrigine, exterieureOrigine, 0
		if theme then
			ambiance, exterieure, exposition = theme.ambiance, theme.exterieur, theme.exposition or 0
			if reduit then exposition = math.min(exposition, 0.6) end -- Flashbang : beaucoup moins éblouissant
			if theme.festive then
				-- Festive : les couleurs tournent
				local teinteFestive = Color3.fromHSV((t * 0.08) % 1, 0.8, 0.9)
				ambiance, exterieure = teinteFestive, teinteFestive:Lerp(Color3.new(0, 0, 0), 0.4)
			end
		end
		Lighting.Ambient = ambianceOrigine:Lerp(ambiance, themeActuel)
		Lighting.OutdoorAmbient = exterieureOrigine:Lerp(exterieure, themeActuel)
		local leds = interieur:FindFirstChild(Config.NomLedsAlerte or "LedsAlerte")
		if leds and not alerte then
			local couleurLeds = theme and theme.leds
			if theme and theme.festive then couleurLeds = Color3.fromHSV((t * 0.08 + 0.5) % 1, 0.9, 1) end
			for _, objet in leds:GetDescendants() do
				if objet:IsA("Light") then
					ledsOrigine[objet] = ledsOrigine[objet] or objet.Color
					objet.Color = couleurLeds and ledsOrigine[objet]:Lerp(couleurLeds, themeActuel) or ledsOrigine[objet]
				end
			end
		end

		-- Courant coupé : l'image s'assombrit fortement
		-- (trois exemplaires tournent, un par TARDIS : seul celui qui a quelque chose à assombrir écrit l'exposition)
		if noirActuel > 0.002 or themeActuel > 0.002 then
			Lighting.ExposureCompensation = expositionOrigine - 3 * noirActuel + exposition * themeActuel
			expositionEcrite = true
		elseif expositionEcrite then
			Lighting.ExposureCompensation = expositionOrigine
			expositionEcrite = false
		end
		-- Alerte : teinte rouge qui pulse doucement (comme une alarme)
		local pulsation = 0.75 + 0.25 * math.sin(t * 4)
		local intensite = rougeActuel * pulsation
		-- Contre-jour (V6.7) : à bord, chaque souffle éclaire doucement l'image (la salle respire avec le moteur)
		local contrejour = 0
		if EFFETS.Contrejour ~= false and dedans and enVoyage and not horsTension then
			contrejour = (discret and 0 or souffle * (reduit and 0.02 or 0.07)) + choc * 0.05
		end
		teinte.TintColor = Color3.new(1, 1 - 0.45 * intensite, 1 - 0.45 * intensite)
		teinte.Saturation = -0.2 * noirActuel
		teinte.Brightness = -0.05 * intensite + contrejour
	end)

	-- 3) Rotor de la console : il pompe pendant le voyage, s'arrête en douceur une fois posé
	-- (il accélère un instant quand on clique dessus : rotor interactif)
	proteger("rotor", function()
		local boost = exterieur:GetAttribute("RotorBoost")
		local boostActif = boost ~= nil and workspace:GetServerTimeNow() - boost < 3
		local actif = etat ~= E.Pose or boostActif or exterieur:GetAttribute("VolLibre") ~= nil
		local vitesse = Config.VitesseRotor * (boostActif and 3 or 1)
		local amplitude = Config.AmplitudeRotor * ((etat == E.Pose and not boostActif) and 0.5 or 1)
		-- Atterrissage : la course se réduit pendant les 2 dernières secondes, pour s'arrêter sans à-coup
		if etat == E.Remat then
			local duree, decalage = Config.Timing(E.Remat, mode)
			amplitude *= math.clamp((duree + decalage - ecoule) / 2, 0.1, 1)
		end
		local cible = actif and math.sin(t * vitesse) * amplitude or 0
		courseRotor += (cible - courseRotor) * math.min(dt * (actif and 12 or 4), 1)
		if math.abs(courseRotor) < 0.002 and not actif then courseRotor = 0 end
		local voulu = rotorBase * CFrame.new(0, courseRotor, 0)
		if rotor:GetPivot() ~= voulu then rotor:PivotTo(voulu) end
	end)

	-- 3 ter) Couleur du rotor selon le mode (sauf hors tension et en alerte, qui ont leurs propres couleurs)
	proteger("couleurRotor", function()
		local actif = etat ~= E.Pose and exterieur:GetAttribute("Alimentation") ~= false and exterieur:GetAttribute("Alerte") ~= true
		if actif then couleurRotor = Config.Modes[Config.modeDe(exterieur)].CouleurRotor or couleurRotor end
		local avant = melangeRotor
		melangeRotor += ((actif and 1 or 0) - melangeRotor) * math.min(dt * 2, 1)
		if melangeRotor < 0.002 then melangeRotor = 0 end
		if melangeRotor == 0 and avant == 0 then return end
		-- Les néons battent au rythme des souffles
		local battement = 1 - 0.35 * souffle * melangeRotor
		for part, origine in neonsRotor do
			part.Color = origine:Lerp(couleurRotor:Lerp(Color3.new(1, 1, 1), 0.25 * souffle), melangeRotor * battement)
		end
	end)

	-- 3 bis) Lumières de la salle : secours hors tension, pièces vides éteintes, pénombre après 5 min,
	-- nuit automatique, et respiration avec le moteur en voyage (les LEDs d'alerte restent gérées par le thème)
	proteger("lumieres", function()
		local horsTension = exterieur:GetAttribute("Alimentation") == false
		local activite = exterieur:GetAttribute("ActivitePilote")
		local tabletteOuverte = joueur:GetAttribute("TardisTablette") == true
		local inactif = not tabletteOuverte and activite ~= nil and workspace:GetServerTimeNow() - activite > 5 * 60
		local heure = Lighting.ClockTime
		local nuit = heure < 6 or heure > 18.5
		local enVol = etat ~= E.Pose
		-- En démat / remat : chaque souffle fait monter puis redescendre la lumière ; dans le vortex : respiration lente
		local pulsation = enVoyage and (0.5 + 0.5 * souffle) or (0.7 + 0.3 * (0.5 + 0.5 * math.sin(t * Config.VitesseRotor)))
		-- Positions des joueurs (une seule fois par image)
		local racines = {}
		for _, autre in Players:GetPlayers() do
			local r = autre.Character and autre.Character:FindFirstChild("HumanoidRootPart")
			if r then table.insert(racines, r.Position) end
		end
		-- Trois exemplaires tournent (un par TARDIS) : on ne travaille que si la caméra est près de cette salle
		if (workspace.CurrentCamera.CFrame.Position - interieur:GetPivot().Position).Magnitude > 350 then return end
		if not listeLumieres then
			listeLumieres = {}
			for _, objet in interieur:GetDescendants() do
				if objet:IsA("Light") then table.insert(listeLumieres, objet) end
			end
			interieur.DescendantAdded:Connect(function(objet) if objet:IsA("Light") then table.insert(listeLumieres, objet) end end)
		end
		local dossierLeds = interieur:FindFirstChild(Config.NomLedsAlerte or "LedsAlerte")
		for _, objet in listeLumieres do
			if objet.Parent then
				local infos = lumieresSalle[objet]
				if not infos then
					infos = { brillance = objet.Brightness, couleur = objet.Color, facteur = 1 }
					lumieresSalle[objet] = infos
				end
				local part = objet.Parent:IsA("Attachment") and objet.Parent.Parent or objet.Parent
				local cible, couleur = 1, infos.couleur
				if horsTension then
					-- Lumière de secours : rouge, qui s'éteint et se rallume lentement
					cible = 0.25 * (0.5 + 0.5 * math.sin(t * 1.1))
					couleur = Color3.fromRGB(255, 40, 40)
				else
					-- Pièce vide : éteinte (personne à moins de 28 studs de la lampe)
					local quelquUn = false
					if part and part:IsA("BasePart") then
						for _, position in racines do
							if (position - part.Position).Magnitude < 28 then quelquUn = true break end
						end
					end
					if not quelquUn then cible = 0
					elseif inactif then cible = 0.35 -- pénombre
					elseif nuit then cible = 0.7 end -- nuit automatique
					if nuit and cible > 0 then couleur = couleur:Lerp(Color3.fromRGB(255, 200, 140), 0.35) end
					if enVol or enVoyage then cible *= pulsation end
					-- Régulation de l'énergie (tablette technicien, V6.7.2) : en sous-tension, la salle baisse
					local tension = exterieur:GetAttribute("RegulEnergie")
					if tension then cible *= 0.3 + 0.7 * math.clamp(tension / math.max((Config.Technicien or {}).SousTension or 20, 1) * 0.5, 0, 1) end
					-- Choc d'atterrissage : la lumière vacille
					if choc > 0 then cible *= 1 - 0.5 * choc * Config.Bruit(t, 20) end
					-- Lumières du rotor : couleur du mode du voyage
					if melangeRotor > 0 and objet:IsDescendantOf(rotor) then couleur = couleur:Lerp(couleurRotor, 0.85 * melangeRotor) end
				end
				-- Les souffles se suivent vite : la lumière les suit de près ; le reste change en douceur
				infos.facteur += (cible - infos.facteur) * math.min(dt * (enVoyage and 8 or 2), 1)
				objet.Brightness = infos.brillance * infos.facteur
				if not (dossierLeds and objet:IsDescendantOf(dossierLeds)) then
					objet.Color = couleur
				end
			end
		end
	end)

	-- 4) Secousses de caméra pendant le décollage et l'atterrissage, et choc d'arrivée
	local personnage = joueur.Character
	local humanoid = personnage and personnage:FindFirstChildOfClass("Humanoid")
	local racine = personnage and personnage:FindFirstChild("HumanoidRootPart")
	if humanoid and racine then
		-- Les secousses commencent en même temps que l'animation (après le silence du début du son)
		local _, decalage = Config.Timing(etat, Config.modeDe(exterieur))
		-- Stabilisateur actif : aucune secousse en voyage normal ; en urgence, il n'en absorbe qu'une partie
		local stabilise = exterieur:GetAttribute("Stabilisateur") ~= false
		local dedans = dansInterieur(racine.Position)
		local secouer = (etat == E.Demat or etat == E.Remat) and ecoule >= decalage and dedans
			and not (stabilise and not urgence)
		local offset = Vector3.zero
		if secouer then
			local f = Config.ForceSecousse * (urgence and 2.5 or 1) -- urgence : ça secoue beaucoup plus
			if stabilise then f *= 0.05 end -- urgence avec stabilisateur : à peine une vibration (5 %)
			-- Sièges d'équipage : assis, on est bien moins secoué
			if humanoid.Sit and humanoid.SeatPart and string.sub(humanoid.SeatPart.Name, 1, 13) == "SiegeEquipage" then f *= 0.3 end
			if reduit then f *= 0.3 end
			-- Chaque souffle secoue plus fort que le creux qui le suit
			f *= 0.4 + 0.6 * souffle
			offset = Vector3.new((math.random() - 0.5) * f, (math.random() - 0.5) * f, (math.random() - 0.5) * f)
		end
		-- Choc d'atterrissage : un à-coup vers le bas qui s'amortit en une demi-seconde
		if choc > 0 then
			if dedans then
				offset += Vector3.new((math.random() - 0.5) * 0.5 * choc, -0.55 * choc * (0.5 + 0.5 * math.cos(choc * 6)), (math.random() - 0.5) * 0.5 * choc)
			end
			choc = math.max(0, choc - dt * 2.2)
		end
		if offset ~= Vector3.zero then
			humanoid.CameraOffset = offset
			secousseActive = true
		elseif secousseActive then
			humanoid.CameraOffset = Vector3.zero
			secousseActive = false
		end
	else
		choc = math.max(0, choc - dt * 2.2)
	end
end)

--------------------------------------------------------------------
-- Atterrissage sur l'eau : le TARDIS flotte et tangue doucement.
-- Tourbillon de matérialisation (V6.7) : près du sol, la poussière (ou l'eau) tourbillonne autour de la cabine,
-- avec une rafale à chaque souffle ; une onde court au sol à chaque souffle ; urgence : arcs électriques ;
-- arrivée : bouffée de poussière.
--------------------------------------------------------------------
do
	local flottait = false
	local souffleSol = nil -- { part, emetteurs, eau, couleur }
	local dernierSouffle = 0
	local etatSol = nil    -- état animé à l'image précédente (pour l'arrivée)
	local arcsPart = nil   -- étincelles de la lampe en urgence
	local modeSol = "Normal" -- mode de la dernière animation (pour l'arrivée)

	local function exclusionsSol()
		local liste = { exterieur, interieur }
		for _, autre in Players:GetPlayers() do
			if autre.Character then table.insert(liste, autre.Character) end
		end
		return liste
	end

	local function arreterSouffle()
		if not souffleSol then return end
		local ancien = souffleSol
		souffleSol = nil
		for _, emetteur in ancien.emetteurs do emetteur.Enabled = false end
		task.delay(2.5, function() ancien.part:Destroy() end)
	end

	-- Anneau d'émetteurs autour de la cabine : la matière est soufflée en tournant (tangente + un peu vers l'extérieur)
	local function creerSouffle(position, couleur, eau)
		local part = piece({ Name = "TardisSouffle", Transparency = 1, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(position) })
		local taille = exterieur:GetExtentsSize()
		local rayon = math.max(taille.X, taille.Z) * 0.6
		local emetteurs = {}
		for i = 1, 14 do
			local angle = i / 14 * math.pi * 2
			local local_ = Vector3.new(math.cos(angle) * rayon, 0.3, math.sin(angle) * rayon)
			local tangente = Vector3.new(-math.sin(angle), 0, math.cos(angle))
			local dehors = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local point = Instance.new("Attachment")
			point.CFrame = CFrame.lookAt(local_, local_ + tangente + dehors * 0.4 + Vector3.new(0, eau and 0.6 or 0.25, 0))
			point.Parent = part
			local emetteur = Instance.new("ParticleEmitter")
			emetteur.Texture = "rbxasset://textures/particles/smoke_main.dds"
			emetteur.EmissionDirection = Enum.NormalId.Front
			emetteur.Color = ColorSequence.new(couleur)
			emetteur.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, eau and 0.5 or 0.7), NumberSequenceKeypoint.new(0.5, eau and 1.8 or 2.6), NumberSequenceKeypoint.new(1, eau and 2.2 or 3.6) })
			emetteur.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, eau and 0.3 or 0.5), NumberSequenceKeypoint.new(0.6, eau and 0.6 or 0.75), NumberSequenceKeypoint.new(1, 1) })
			emetteur.Lifetime = NumberRange.new(0.7, 1.4)
			emetteur.Speed = NumberRange.new(10, 22)
			emetteur.SpreadAngle = Vector2.new(10, eau and 35 or 18)
			emetteur.Drag = 2.5
			emetteur.Acceleration = Vector3.new(0, eau and -28 or 1.2, 0) -- l'eau retombe, la poussière flotte
			emetteur.Rotation = NumberRange.new(0, 360)
			emetteur.RotSpeed = NumberRange.new(-90, 90)
			emetteur.LightInfluence = 1
			emetteur.Rate = 0
			emetteur.Parent = point
			table.insert(emetteurs, emetteur)
		end
		-- Étincelles de poussière brillante, soulevées au centre (rafales seulement)
		local centre = Instance.new("Attachment")
		centre.Parent = part
		local paillettes = Instance.new("ParticleEmitter")
		paillettes.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		paillettes.Color = ColorSequence.new(couleur:Lerp(Color3.new(1, 1, 1), 0.6))
		paillettes.LightEmission = 0.6
		paillettes.Size = NumberSequence.new(0.25, 0)
		paillettes.Transparency = NumberSequence.new(0.2, 1)
		paillettes.Lifetime = NumberRange.new(0.8, 1.6)
		paillettes.Speed = NumberRange.new(6, 14)
		paillettes.SpreadAngle = Vector2.new(180, 180)
		paillettes.Acceleration = Vector3.new(0, eau and -20 or -3, 0)
		paillettes.Drag = 1.5
		paillettes.Rate = 0
		paillettes.Parent = centre
		table.insert(emetteurs, paillettes)
		souffleSol = { part = part, emetteurs = emetteurs, eau = eau, couleur = couleur, rayon = rayon }
	end

	-- Onde au sol : un anneau fin qui court sur le sol en s'effaçant
	local function onde(position, couleur, largeur, duree, transparence)
		local anneau = piece({ Name = "TardisOnde", Shape = Enum.PartType.Cylinder, Color = couleur, Transparency = transparence or 0.55,
			Size = Vector3.new(0.12, largeur, largeur), CFrame = CFrame.new(position + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.pi / 2) })
		tween(anneau, duree or 0.8, { Size = Vector3.new(0.12, largeur * 2.6, largeur * 2.6), Transparency = 1 })
		Debris:AddItem(anneau, (duree or 0.8) + 0.1)
	end

	-- Arc électrique (urgence) : un éclair bref en zigzag entre deux points de la cabine
	local function arc(cf, taille)
		local function pointSurface()
			local face = math.random(3)
			local x, y, z = (math.random() - 0.5) * taille.X, (math.random() - 0.5) * taille.Y, (math.random() - 0.5) * taille.Z
			local signe = math.random() < 0.5 and -1 or 1
			if face == 1 then x = signe * taille.X / 2 elseif face == 2 then z = signe * taille.Z / 2 else y = signe * taille.Y / 2 end
			return cf:PointToWorldSpace(Vector3.new(x, y, z))
		end
		local depart, arrivee = pointSurface(), pointSurface()
		if (arrivee - depart).Magnitude < 1 then arrivee = pointSurface() end
		local precedent = depart
		local n = 5
		for k = 1, n do
			local suivant = k == n and arrivee or depart:Lerp(arrivee, k / n) + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 0.9
			local segment = piece({ Name = "TardisArc", Color = k % 2 == 0 and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 220, 255),
				Size = Vector3.new(0.1, 0.1, (suivant - precedent).Magnitude), CFrame = CFrame.lookAt((precedent + suivant) / 2, suivant) })
			Debris:AddItem(segment, 0.08 + math.random() * 0.06)
			precedent = suivant
		end
		local eclat = piece({ Name = "TardisArcEclat", Shape = Enum.PartType.Ball, Color = Color3.fromRGB(200, 235, 255), Transparency = 0.3,
			Size = Vector3.one * 0.6, CFrame = CFrame.new(arrivee) })
		local lum = Instance.new("PointLight")
		lum.Color, lum.Brightness, lum.Range = Color3.fromRGB(170, 220, 255), 4, 12
		lum.Parent = eclat
		tween(eclat, 0.15, { Size = Vector3.one * 1.6, Transparency = 1 })
		Debris:AddItem(eclat, 0.2)
	end

	-- Intensité de la matérialisation en cours (0 = rien, 1 = au plus fort) : voyage ou phase de vol libre, démat ou remat
	local function intensiteSol()
		local s, p, _, etatAnime, modeAnime = respiration()
		if not etatAnime then return 0, 0, nil, nil end
		if p <= 0 or p >= 1 then return 0, s, etatAnime, modeAnime end
		return math.sin(p * math.pi), s, etatAnime, modeAnime
	end

	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()

		-- 1) Sur l'eau : flottaison (seulement quand personne ne le porte ni ne le pilote)
		local surEau = exterieur:GetAttribute("SurEau") == true and not exterieur:GetAttribute("VolLibre")
			and not exterieur:GetAttribute("Porteur")
		local base = exterieur:GetAttribute("BaseEau")
		if surEau and typeof(base) == "CFrame" then
			flottait = true
			exterieur:PivotTo(base * CFrame.new(0, math.sin(t * 1.2) * 0.25 - 0.15, 0)
				* CFrame.Angles(math.sin(t * 0.9) * math.rad(2), 0, math.cos(t * 0.7) * math.rad(2.5)))
		elseif flottait then
			flottait = false
			if typeof(base) == "CFrame" and not exterieur:GetAttribute("VolLibre") and not exterieur:GetAttribute("Porteur") then
				exterieur:PivotTo(base) -- on revient exactement à la position du serveur
			end
		end

		-- 2) Tourbillon, ondes et arcs près du sol
		local intensite, s, etatAnime, modeAnime = 0, 0, nil, nil
		proteger("intensiteSol", function() intensite, s, etatAnime, modeAnime = intensiteSol() end)
		local camoufle = exterieur:GetAttribute("Camouflage") == true or exterieur:GetAttribute("Detruit") == true
		local pivot = exterieur:GetPivot()
		local nouveauSouffle = s > 0.5 and dernierSouffle <= 0.5 -- début d'un souffle à cette image
		dernierSouffle = s
		local couleurMode = Config.couleurDehors(modeAnime or "Normal") -- Rapide : neutre dehors

		local discretSol = etatAnime ~= nil and (Config.Modes[modeAnime] or {}).Discret == true
		if etatAnime and modeAnime then modeSol = modeAnime end
		if etatAnime and not camoufle and not discretSol then
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = exclusionsSol()
			params.IgnoreWater = false
			local depart = pivot.Position + Vector3.new(0, 1, 0)
			local resultat = workspace:Raycast(depart, Vector3.new(0, -14, 0), params)
			if resultat and EFFETS.Tourbillon ~= false then
				local eau = resultat.Material == Enum.Material.Water
				if not souffleSol or souffleSol.eau ~= eau then
					arreterSouffle()
					local couleur
					if eau then
						couleur = Color3.fromRGB(225, 240, 255)
					elseif resultat.Instance:IsA("Terrain") then
						couleur = workspace.Terrain:GetMaterialColor(resultat.Material)
					else
						couleur = resultat.Instance.Color
					end
					if not eau then couleur = couleur:Lerp(Color3.fromRGB(200, 190, 170), 0.35) end
					creerSouffle(resultat.Position, couleur, eau)
				end
				souffleSol.part.CFrame = CFrame.new(resultat.Position)
				-- Débit continu qui suit la respiration, plus une rafale au début de chaque souffle
				for i, emetteur in souffleSol.emetteurs do
					if i < #souffleSol.emetteurs then
						emetteur.Rate = 16 * intensite * (0.25 + 0.75 * s)
						if nouveauSouffle then emetteur:Emit(math.floor(4 + 6 * intensite)) end
					elseif nouveauSouffle then
						emetteur:Emit(math.floor(10 + 25 * intensite))
					end
				end
			else
				arreterSouffle()
			end
			-- Onde au sol à chaque souffle (même sans poussière : sol dur ou cabine en l'air à moins de 14 studs)
			if resultat and nouveauSouffle and EFFETS.Ondes ~= false then
				local taille = exterieur:GetExtentsSize()
				local largeur = math.max(taille.X, taille.Z) * 1.1
				onde(resultat.Position, couleurMode:Lerp(Color3.new(1, 1, 1), 0.3), largeur, 0.7 + 0.5 * intensite, 0.6 - 0.25 * intensite)
			end
			-- Urgence et catastrophe : arcs sur la cabine et étincelles à la lampe (deux fois plus en catastrophe)
			if Config.modeSaccade(modeAnime) and EFFETS.Arcs ~= false and intensite > 0.05 then
				local cf, taille = exterieur:GetBoundingBox()
				if math.random() < dt * (3 + 9 * s) * intensite * (modeAnime == "Catastrophe" and 2 or 1) then arc(cf, taille) end
				if not arcsPart or not arcsPart.Parent then
					arcsPart = piece({ Name = "TardisEtincellesLampe", Transparency = 1, Size = Vector3.one, CFrame = CFrame.new(positionLampe()) })
					local etincelles = Instance.new("ParticleEmitter")
					etincelles.Name = "Etincelles"
					etincelles.Color = ColorSequence.new(Color3.fromRGB(255, 240, 200), Color3.fromRGB(255, 140, 60))
					etincelles.LightEmission = 1
					etincelles.Size = NumberSequence.new(0.2, 0)
					etincelles.Speed = NumberRange.new(8, 16)
					etincelles.Lifetime = NumberRange.new(0.3, 0.7)
					etincelles.SpreadAngle = Vector2.new(60, 60)
					etincelles.Acceleration = Vector3.new(0, -35, 0)
					etincelles.Rate = 0
					etincelles.Parent = arcsPart
				end
				arcsPart.CFrame = CFrame.new(positionLampe())
				if nouveauSouffle or math.random() < dt * 2 then arcsPart.Etincelles:Emit(math.floor(6 + 14 * s)) end
			elseif arcsPart then
				arcsPart:Destroy()
				arcsPart = nil
			end
		else
			arreterSouffle()
			if arcsPart then arcsPart:Destroy() arcsPart = nil end
		end

		-- 3) Arrivée : la cabine vient de se poser (fin d'une remat) : bouffée de poussière et onde d'arrivée
		local etatMaintenant = exterieur:GetAttribute("Etat") or E.Pose
		if etatSol == E.Remat and etatMaintenant == E.Pose and not camoufle and EFFETS.Choc ~= false and not (Config.Modes[modeSol] or {}).Discret then
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = exclusionsSol()
			params.IgnoreWater = false
			local resultat = workspace:Raycast(pivot.Position + Vector3.new(0, 1, 0), Vector3.new(0, -14, 0), params)
			if resultat then
				local taille = exterieur:GetExtentsSize()
				local largeur = math.max(taille.X, taille.Z) * 1.2
				onde(resultat.Position, Color3.fromRGB(235, 235, 235), largeur, 1, 0.5)
				if souffleSol then
					for _, emetteur in souffleSol.emetteurs do emetteur:Emit(14) end
				end
			end
		end
		etatSol = etatMaintenant
	end)
end

--------------------------------------------------------------------
-- Boucliers : apparition rapide (la bulle jaillit avec un rebond, flash lumineux, onde au sol)
-- et disparition (la bulle se rétracte en s'effaçant)
--------------------------------------------------------------------
do
	local function effetTemporaire(proprietes)
		return piece(proprietes)
	end

	local function animerBouclier(modele)
		local bulle = modele:WaitForChild("Bulle", 5)
		if not bulle then return end
		local cible = bulle:GetAttribute("TailleCible") or bulle.Size

		-- 1) La bulle jaillit du TARDIS
		bulle.Size = cible * 0.05
		tween(bulle, 0.35, { Size = cible }, Enum.EasingStyle.Back)

		-- 2) Flash lumineux qui déborde un peu de la bulle
		local flash = effetTemporaire({ Name = "TardisFlashBouclier", Shape = Enum.PartType.Ball, Color = bulle.Color,
			Size = cible * 0.3, CFrame = bulle.CFrame, Transparency = 0.25 })
		tween(flash, 0.45, { Size = cible * 1.12, Transparency = 1 })
		task.delay(0.5, function() flash:Destroy() end)

		-- 3) Onde au sol
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { exterieur, interieur, flash }
		local sol = workspace:Raycast(bulle.Position, Vector3.new(0, -cible.Y, 0), params)
		if sol then
			local onde = effetTemporaire({ Name = "TardisOndeBouclier", Shape = Enum.PartType.Cylinder, Color = bulle.Color,
				Size = Vector3.new(0.15, 2, 2), Transparency = 0.2,
				CFrame = CFrame.new(sol.Position + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.pi / 2) })
			tween(onde, 0.5, { Size = Vector3.new(0.1, cible.X * 1.7, cible.X * 1.7), Transparency = 1 })
			task.delay(0.55, function() onde:Destroy() end)
		end

		-- 4) Disparition : la bulle se rétracte en s'effaçant
		modele:GetAttributeChangedSignal("Disparition"):Connect(function()
			if bulle.Parent then
				tween(bulle, 0.3, { Size = cible * 0.05, Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			end
		end)
	end

	task.spawn(function()
		local dossier = exterieur:WaitForChild("Boucliers", 30)
		if not dossier then return end
		dossier.ChildAdded:Connect(function(modele)
			task.spawn(animerBouclier, modele)
		end)
	end)
end

--------------------------------------------------------------------
-- Invites du TARDIS (E) : invisibles pour les joueurs non autorisés (Config.Pilotes).
-- La vraie sécurité est sur le serveur, qui ignore leurs actions ; ceci évite juste de les afficher.
--------------------------------------------------------------------
do
	local function regler(objet)
		if objet:IsA("ProximityPrompt") then
			objet.Style = joueur:GetAttribute("TardisPilote_" .. def.Nom) == true and Enum.ProximityPromptStyle.Default
				or Enum.ProximityPromptStyle.Custom -- "Custom" sans interface = rien ne s'affiche
		end
	end
	local function toutRegler()
		for _, racine in { exterieur, interieur } do
			for _, objet in racine:GetDescendants() do regler(objet) end
		end
	end
	exterieur.DescendantAdded:Connect(regler)
	interieur.DescendantAdded:Connect(regler)
	joueur:GetAttributeChangedSignal("TardisPilote_" .. def.Nom):Connect(toutRegler)
	toutRegler()
end

--------------------------------------------------------------------
-- Empreinte temporelle (V6.6.2) : après un départ, une silhouette translucide du TARDIS reste là où il
-- était, scintille légèrement, puis s'efface (Config.Empreinte). Chaque joueur la construit lui-même à
-- partir de l'attribut "Etat" : tout le monde la voit au même endroit.
--------------------------------------------------------------------
do
	local reglages = Config.Empreinte or {}
	local DUREE = reglages.Duree or 30
	local COULEUR = reglages.Couleur or Color3.fromRGB(120, 180, 255)
	local TRANSPARENCE = reglages.Transparence or 0.75
	local enAttente = nil -- silhouette préparée au début de la démat, montrée quand le TARDIS est parti

	-- Copie de la cabine à sa position actuelle (pièces visibles seulement, sans scripts ni interfaces)
	local function preparer()
		local modele = Instance.new("Model")
		modele.Name = "TardisEmpreinte_" .. def.Nom
		for _, part in exterieur:GetDescendants() do
			local fiche = visuels[part]
			local origine = fiche and fiche.transparences.Transparency
			if part:IsA("BasePart") and part ~= exterieur.PrimaryPart and part.Name ~= Config.NomPortailExt
				and (origine or part.Transparency) < 0.95 then
				local fantome = part:Clone()
				if fantome then
					fantome:ClearAllChildren()
					fantome.Anchored, fantome.CanCollide, fantome.CanTouch, fantome.CanQuery = true, false, false, false
					fantome.CastShadow = false
					fantome.Material = Enum.Material.Neon
					fantome.Color = COULEUR
					if fantome:IsA("UnionOperation") then fantome.UsePartColor = true end
					if fantome:IsA("MeshPart") then fantome.TextureID = "" end
					fantome.Transparency = 1
					fantome.Parent = modele
				end
			end
		end
		return modele
	end

	local function montrer(modele)
		local pieces = modele:GetChildren()
		modele.Parent = workspace
		local debut = os.clock()
		local connexion
		connexion = RunService.Heartbeat:Connect(function()
			local ecoule = os.clock() - debut
			local p = ecoule / DUREE
			if p >= 1 or not modele.Parent then
				connexion:Disconnect()
				modele:Destroy()
				return
			end
			-- Apparition rapide, puis effacement lent, avec un léger scintillement
			local apparition = math.clamp(ecoule / 0.6, 0, 1)
			local visibilite = (1 - TRANSPARENCE) * apparition * (1 - p) * (1 + 0.15 * math.sin(ecoule * 9))
			local transparence = math.clamp(1 - visibilite, 0, 1)
			for _, piece_ in pieces do piece_.Transparency = transparence end
		end)
	end

	exterieur:GetAttributeChangedSignal("Etat"):Connect(function()
		local etat = exterieur:GetAttribute("Etat")
		if etat == E.Demat then
			if enAttente then enAttente:Destroy() enAttente = nil end
			-- Pas d'empreinte pour un départ discret : camouflé, porté (téléportation de poche), en vol libre ou Silencieux
			if exterieur:GetAttribute("Camouflage") == true or exterieur:GetAttribute("Porteur") or exterieur:GetAttribute("VolLibre")
				or (Config.Modes[Config.modeDe(exterieur)] or {}).Discret then return end
			enAttente = preparer()
		elseif etat == E.Vol and enAttente then
			local modele = enAttente
			enAttente = nil
			montrer(modele)
		elseif enAttente then
			enAttente:Destroy() -- démat interrompue
			enAttente = nil
		end
	end)
end
--------------------------------------------------------------------
-- Effets propres aux modes (V6.7.1)
--  • Rapide : sa couleur ne se voit qu'à l'intérieur : un éclair vert dans la salle de contrôle au départ et à
--    l'arrivée (plus d'éclair vert dehors : l'ancien Éclair Express de la V6.6.4 est remplacé par les ondes neutres)
--  • Sauvetage : la lampe devient un projecteur braqué vers le sol pendant la descente, avec son cône de lumière
--  • Catastrophe : à bord, la console crache des étincelles et la salle bat en rouge pendant la matérialisation
--------------------------------------------------------------------
do
	local COULEUR_RAPIDE = Config.Modes.Express.CouleurRotor or Color3.fromRGB(74, 222, 128)
	local ROUGE = Color3.fromRGB(255, 60, 60)
	local teinteMode = Instance.new("ColorCorrectionEffect")
	teinteMode.Name = "TardisTeinteMode_" .. def.Nom
	teinteMode.Parent = Lighting
	local supportRotor = rotor:IsA("BasePart") and rotor or rotor:FindFirstChildWhichIsA("BasePart", true) or interieur.PrimaryPart
	local lumiereRotor = Instance.new("PointLight")
	lumiereRotor.Brightness, lumiereRotor.Range, lumiereRotor.Shadows = 0, 40, false
	lumiereRotor.Parent = supportRotor
	local eclat, couleurEclat = 0, COULEUR_RAPIDE -- éclair intérieur (décroît)

	-- Projecteur de sauvetage : sous la lampe, braqué vers le bas, avec un cône visible
	local projecteur = piece({ Name = "TardisProjecteur_" .. def.Nom, Transparency = 1, Size = Vector3.one, CFrame = CFrame.new(positionLampe()) })
	local spot = Instance.new("SpotLight")
	spot.Angle, spot.Range, spot.Brightness, spot.Face, spot.Shadows = 58, 70, 0, Enum.NormalId.Bottom, true
	spot.Color = Color3.fromRGB(255, 245, 215)
	spot.Parent = projecteur
	local a0 = Instance.new("Attachment")
	a0.Parent = projecteur
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -45, 0)
	a1.Parent = projecteur
	local cone = Instance.new("Beam")
	cone.Attachment0, cone.Attachment1 = a0, a1
	cone.Width0, cone.Width1 = 1, 22
	cone.LightEmission, cone.LightInfluence = 1, 0
	cone.Color = ColorSequence.new(Color3.fromRGB(255, 245, 215))
	cone.Transparency = NumberSequence.new(1)
	cone.FaceCamera = true
	cone.Parent = projecteur

	-- Étincelles de la console (catastrophe) : préparées à la demande
	local pointsConsole = nil
	local function preparerEtincelles()
		pointsConsole = {}
		local console = interieur:FindFirstChild("Console")
		if not console then return end
		local pieces = {}
		for _, objet in console:GetDescendants() do
			if objet:IsA("BasePart") and objet.Size.Magnitude > 0.8 then table.insert(pieces, objet) end
		end
		for _ = 1, math.min(8, #pieces) do
			local part = table.remove(pieces, math.random(#pieces))
			local point = Instance.new("Attachment")
			point.Parent = part
			local etincelles = Instance.new("ParticleEmitter")
			etincelles.Color = ColorSequence.new(Color3.fromRGB(255, 235, 150), Color3.fromRGB(255, 90, 30))
			etincelles.LightEmission = 1
			etincelles.Size = NumberSequence.new(0.25, 0)
			etincelles.Speed = NumberRange.new(8, 20)
			etincelles.Lifetime = NumberRange.new(0.3, 0.8)
			etincelles.SpreadAngle = Vector2.new(90, 90)
			etincelles.Acceleration = Vector3.new(0, -30, 0)
			etincelles.Rate = 0
			etincelles.Parent = point
			table.insert(pointsConsole, etincelles)
		end
	end

	local etatAvant, modeAvant = exterieur:GetAttribute("Etat") or E.Pose, "Normal"
	exterieur:GetAttributeChangedSignal("Etat"):Connect(function()
		local etat = exterieur:GetAttribute("Etat")
		local modeMaintenant = Config.modeDe(exterieur)
		-- Rapide : éclair vert dans la salle au début de la démat, au début de la remat et une fois posé
		if ((etat == E.Demat or etat == E.Remat) and modeMaintenant == "Express")
			or (etat == E.Pose and etatAvant == E.Remat and (modeMaintenant == "Express" or modeAvant == "Express")) then
			eclat, couleurEclat = 1, COULEUR_RAPIDE
		end
		etatAvant, modeAvant = etat, modeMaintenant
	end)
	exterieur:GetAttributeChangedSignal("VolPhase"):Connect(function()
		local phase = exterieur:GetAttribute("VolPhase")
		if (phase == E.Demat or phase == E.Remat) and Config.modeVolDe(exterieur) == "Express" then
			eclat, couleurEclat = 1, COULEUR_RAPIDE
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		local etat = exterieur:GetAttribute("Etat") or E.Pose
		local mode = Config.modeDe(exterieur)
		local reduit = UI.effetsReduits()
		local racine = joueur.Character and joueur.Character:FindFirstChild("HumanoidRootPart")
		local dedans = racine ~= nil and dansInterieur(racine.Position)

		-- Éclair intérieur du Rapide, et battement rouge de la catastrophe (seulement pour ceux qui sont à bord)
		eclat = math.max(0, eclat - dt * 2.5)
		local intensiteEclat = dedans and eclat * (reduit and 0.4 or 1) or 0
		local catastrophe = etat == E.Remat and mode == "Catastrophe"
		local battement = (catastrophe and dedans) and (0.5 + 0.5 * math.sin(t * 9)) * (reduit and 0.25 or 0.5) or 0
		local teinte = Color3.new(1, 1, 1):Lerp(couleurEclat, 0.4 * intensiteEclat):Lerp(ROUGE, 0.5 * battement)
		teinteMode.TintColor = teinte
		teinteMode.Brightness = 0.12 * intensiteEclat
		lumiereRotor.Color = catastrophe and ROUGE or couleurEclat
		lumiereRotor.Brightness = 10 * intensiteEclat + (catastrophe and 5 * (0.5 + 0.5 * math.sin(t * 9)) or 0)
		-- Catastrophe : la console crache des étincelles (chez tout le monde : elle est visible de dehors par la porte)
		if catastrophe then
			if not pointsConsole then preparerEtincelles() end
			if #pointsConsole > 0 and math.random() < dt * 7 then
				pointsConsole[math.random(#pointsConsole)]:Emit(math.random(10, 25))
			end
		end

		-- Projecteur de sauvetage : allumé pendant la descente (pas camouflé, avec du courant)
		local sauvetage = etat == E.Remat and mode == "Sauvetage" and exterieur:GetAttribute("Camouflage") ~= true
			and exterieur:GetAttribute("Alimentation") ~= false
		spot.Brightness += ((sauvetage and 7 or 0) - spot.Brightness) * math.min(dt * 4, 1)
		if sauvetage or spot.Brightness > 0.05 then
			projecteur.CFrame = CFrame.new(positionLampe())
			local part = spot.Brightness / 7
			cone.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1 - 0.18 * part), NumberSequenceKeypoint.new(1, 1 - 0.03 * part) })
			cone.Enabled = true
		else
			cone.Enabled = false
		end
	end)
end
