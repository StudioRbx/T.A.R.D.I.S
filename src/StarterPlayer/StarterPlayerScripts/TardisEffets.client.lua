-- StarterPlayer > StarterPlayerScripts > TardisEffets (LocalScript)
-- Fondu pulsé de l'extérieur, lampe qui clignote, rotor qui monte/descend, secousses dans l'intérieur.
-- Tout est calculé à partir des attributs "Etat" et "DebutEtat" posés par le serveur,
-- donc tous les joueurs voient la même chose au même moment (même ceux qui arrivent en cours de vol).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("TardisConfig"))
local E = Config.Etats
local joueur = Players.LocalPlayer

local def = Config.demarrerPourChaqueTardis(script) -- un exemplaire par TARDIS : tout le monde voit les trois
local exterieur, interieur = Config.modeles(def)
local rotor = interieur:WaitForChild(Config.NomRotor)
local lampe = exterieur:FindFirstChild(Config.NomLampe, true)
local lumiere = lampe and lampe:FindFirstChildWhichIsA("Light", true)

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
local couleurLampe = lumiere and lumiere.Color or Color3.new(1, 1, 1)

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
		return Config.Alpha(phase, ecoule, exterieur:GetAttribute("VolPhaseUrgence") == true)
	end
	return 0
end

local alphaActuel = 0
local secousseActive = false

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
	local alpha = math.max(Config.Alpha(etat, ecoule, mode), camouflage)
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

RunService.RenderStepped:Connect(function(dt)
	local etat = exterieur:GetAttribute("Etat") or E.Pose
	local ecoule = workspace:GetServerTimeNow() - (exterieur:GetAttribute("DebutEtat") or 0)
	local t = os.clock()

	-- 1) Fondu de l'extérieur (le plus invisible des deux : voyage ou camouflage)
	local camouflage = 0
	proteger("camouflage", function()
		-- Le camouflage et la démat en vol rendent tous les deux le TARDIS invisible : on garde le plus fort
		camouflage = math.max(alphaCamouflage(), alphaVol())
	end)
	local mode = Config.modeDe(exterieur)
	local urgence = mode == "Urgence"
	-- Vortex temporel : pendant le vol, le TARDIS est visible dans le ciel (le vortex est dessiné par TardisVolLibre)
	local etatFondu = (etat == E.Vol and exterieur:GetAttribute("Ciel") == true) and E.Pose or etat
	proteger("fondu", fondu, etatFondu, ecoule, camouflage, mode)

	-- 2) Lampe du toit
	if lumiere then
		local brillance = brillanceBase
		if etat ~= E.Pose then
			if urgence then
				-- Urgence : la lampe vacille et coupe de façon irrégulière
				brillance *= (Config.Bruit(ecoule, 15) < 0.35) and 0.05 or (0.6 + 0.4 * Config.Bruit(ecoule + 1.3, 9))
			else
				brillance *= 0.5 + 0.5 * math.sin(t * Config.VitesseLampe)
			end
		end
		if exterieur:GetAttribute("Alimentation") == false then
			brillance = 0 -- plus de courant
		end
		lumiere.Brightness = brillance * (1 - camouflage) -- éteinte quand le TARDIS est camouflé
		-- Alerte : la lampe du toit passe au rouge
		lumiere.Color = exterieur:GetAttribute("Alerte") and (Config.CouleurAlerte or Color3.fromRGB(255, 30, 30)) or couleurLampe
	end

	-- 2 bis) Ambiance pour le joueur qui se trouve dans l'intérieur
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
		teinte.TintColor = Color3.new(1, 1 - 0.45 * intensite, 1 - 0.45 * intensite)
		teinte.Saturation = -0.2 * noirActuel
		teinte.Brightness = -0.05 * intensite
	end)

	-- 3) Rotor de la console (il accélère un instant quand on clique dessus : rotor interactif)
	local boost = exterieur:GetAttribute("RotorBoost")
	local boostActif = boost ~= nil and workspace:GetServerTimeNow() - boost < 3
	if etat == E.Pose and not boostActif then
		if rotor:GetPivot() ~= rotorBase then
			rotor:PivotTo(rotorBase)
		end
	else
		local vitesse = Config.VitesseRotor * (boostActif and 3 or 1)
		local amplitude = Config.AmplitudeRotor * (etat == E.Pose and 0.5 or 1)
		rotor:PivotTo(rotorBase * CFrame.new(0, math.sin(t * vitesse) * amplitude, 0))
	end

	-- 3 ter) Couleur du rotor selon le mode (sauf hors tension et en alerte, qui ont leurs propres couleurs)
	proteger("couleurRotor", function()
		local actif = etat ~= E.Pose and exterieur:GetAttribute("Alimentation") ~= false and exterieur:GetAttribute("Alerte") ~= true
		if actif then couleurRotor = Config.Modes[Config.modeDe(exterieur)].CouleurRotor or couleurRotor end
		local avant = melangeRotor
		melangeRotor += ((actif and 1 or 0) - melangeRotor) * math.min(dt * 2, 1)
		if melangeRotor < 0.002 then melangeRotor = 0 end
		if melangeRotor == 0 and avant == 0 then return end
		for part, origine in neonsRotor do
			part.Color = origine:Lerp(couleurRotor, melangeRotor)
		end
	end)

	-- 3 bis) Lumières de la salle : secours hors tension, pièces vides éteintes, pénombre après 5 min,
	-- nuit automatique, et pulsation avec le rotor en vol (les LEDs d'alerte restent gérées par le thème)
	proteger("lumieres", function()
		local horsTension = exterieur:GetAttribute("Alimentation") == false
		local activite = exterieur:GetAttribute("ActivitePilote")
		local tabletteOuverte = joueur:GetAttribute("TardisTablette") == true
		local inactif = not tabletteOuverte and activite ~= nil and workspace:GetServerTimeNow() - activite > 5 * 60
		local heure = Lighting.ClockTime
		local nuit = heure < 6 or heure > 18.5
		local enVol = etat ~= E.Pose
		local pulsation = 0.6 + 0.4 * (0.5 + 0.5 * math.sin(t * Config.VitesseRotor))
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
					if enVol then cible *= pulsation end
					-- Lumières du rotor : couleur du mode du voyage
					if melangeRotor > 0 and objet:IsDescendantOf(rotor) then couleur = couleur:Lerp(couleurRotor, 0.85 * melangeRotor) end
				end
				infos.facteur += (cible - infos.facteur) * math.min(dt * 2, 1)
				objet.Brightness = infos.brillance * infos.facteur
				if not objet:IsDescendantOf(interieur:FindFirstChild(Config.NomLedsAlerte or "LedsAlerte") or interieur.PrimaryPart or Instance.new("Folder")) then
					objet.Color = couleur
				end
			end
		end
	end)

	-- 4) Secousses de caméra pendant le décollage et l'atterrissage
	local personnage = joueur.Character
	local humanoid = personnage and personnage:FindFirstChildOfClass("Humanoid")
	local racine = personnage and personnage:FindFirstChild("HumanoidRootPart")
	if humanoid and racine then
		-- Les secousses commencent en même temps que l'animation (après le silence du début du son)
		local _, decalage = Config.Timing(etat, Config.modeDe(exterieur))
		-- Stabilisateur actif : aucune secousse en voyage normal ; en urgence, il n'en absorbe qu'une partie
		local stabilise = exterieur:GetAttribute("Stabilisateur") ~= false
		local secouer = (etat == E.Demat or etat == E.Remat) and ecoule >= decalage and dansInterieur(racine.Position)
			and not (stabilise and not urgence)
		if secouer then
			local f = Config.ForceSecousse * (urgence and 2.5 or 1) -- urgence : ça secoue beaucoup plus
			if stabilise then f *= 0.05 end -- urgence avec stabilisateur : à peine une vibration (5 %)
			-- Sièges d'équipage : assis, on est bien moins secoué
			if humanoid.Sit and humanoid.SeatPart and string.sub(humanoid.SeatPart.Name, 1, 13) == "SiegeEquipage" then f *= 0.3 end
			humanoid.CameraOffset = Vector3.new(
				(math.random() - 0.5) * f,
				(math.random() - 0.5) * f,
				(math.random() - 0.5) * f
			)
			secousseActive = true
		elseif secousseActive then
			humanoid.CameraOffset = Vector3.zero
			secousseActive = false
		end
	end
end)

--------------------------------------------------------------------
-- Atterrissage sur l'eau : le TARDIS flotte et tangue doucement
-- Souffle de matérialisation : poussière (ou gerbes d'eau) soufflée tout autour quand il se matérialise près du sol
--------------------------------------------------------------------
do
	local flottait = false
	local souffle = nil -- { part, emetteurs, eau }

	local function exclusionsSol()
		local liste = { exterieur, interieur }
		if souffle then table.insert(liste, souffle.part) end
		for _, autre in Players:GetPlayers() do
			if autre.Character then table.insert(liste, autre.Character) end
		end
		return liste
	end

	local function arreterSouffle()
		if not souffle then return end
		local ancien = souffle
		souffle = nil
		for _, emetteur in ancien.emetteurs do emetteur.Enabled = false end
		task.delay(2, function() ancien.part:Destroy() end)
	end

	local function creerSouffle(position, couleur, eau)
		local part = Instance.new("Part")
		part.Name = "TardisSouffle"
		part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
		part.Transparency = 1
		part.Size = Vector3.new(1, 1, 1)
		part.CFrame = CFrame.new(position)
		part.Parent = workspace
		local taille = exterieur:GetExtentsSize()
		local rayon = math.max(taille.X, taille.Z) * 0.55
		local emetteurs = {}
		for i = 1, 12 do
			local angle = i / 12 * math.pi * 2
			local local_ = Vector3.new(math.cos(angle) * rayon, 0.4, math.sin(angle) * rayon)
			local point = Instance.new("Attachment")
			point.CFrame = CFrame.lookAt(local_, local_ * Vector3.new(2, 1, 2)) -- tourné vers l'extérieur
			point.Parent = part
			local emetteur = Instance.new("ParticleEmitter")
			emetteur.Texture = "rbxasset://textures/particles/smoke_main.dds"
			emetteur.EmissionDirection = Enum.NormalId.Front
			emetteur.Color = ColorSequence.new(couleur)
			emetteur.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, eau and 0.6 or 0.9), NumberSequenceKeypoint.new(1, eau and 2.5 or 4) })
			emetteur.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, eau and 0.25 or 0.45), NumberSequenceKeypoint.new(1, 1) })
			emetteur.Lifetime = NumberRange.new(0.6, 1.3)
			emetteur.Speed = NumberRange.new(14, 26)
			emetteur.SpreadAngle = Vector2.new(12, eau and 40 or 25)
			emetteur.Drag = 3
			emetteur.Acceleration = Vector3.new(0, eau and -25 or 1.5, 0) -- l'eau retombe, la poussière flotte
			emetteur.Rotation = NumberRange.new(0, 360)
			emetteur.RotSpeed = NumberRange.new(-60, 60)
			emetteur.Rate = 0
			emetteur.Parent = point
			table.insert(emetteurs, emetteur)
		end
		souffle = { part = part, emetteurs = emetteurs, eau = eau }
	end

	-- Intensité de la matérialisation en cours (0 = rien, 1 = au plus fort), voyage ou démat en vol
	local function intensiteRemat()
		local maintenant = workspace:GetServerTimeNow()
		local etat = exterieur:GetAttribute("Etat")
		local debut, mode
		if etat == E.Remat then
			debut, mode = exterieur:GetAttribute("DebutEtat"), Config.modeDe(exterieur)
		elseif exterieur:GetAttribute("VolPhase") == E.Remat then
			debut, mode = exterieur:GetAttribute("VolPhaseDebut"), exterieur:GetAttribute("VolPhaseUrgence") == true
		else
			return 0
		end
		local duree, decalage = Config.Timing(E.Remat, mode)
		local p = ((maintenant - (debut or 0)) - decalage) / duree
		if p <= 0 or p >= 1 then return 0 end
		return math.sin(p * math.pi) -- monte, culmine au milieu, retombe
	end

	RunService.RenderStepped:Connect(function()
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

		-- 2) Souffle de matérialisation près du sol
		local intensite = intensiteRemat()
		if intensite > 0 then
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = exclusionsSol()
			params.IgnoreWater = false
			local depart = exterieur:GetPivot().Position + Vector3.new(0, 1, 0)
			local resultat = workspace:Raycast(depart, Vector3.new(0, -14, 0), params)
			if resultat then
				local eau = resultat.Material == Enum.Material.Water
				if not souffle or souffle.eau ~= eau then
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
				souffle.part.CFrame = CFrame.new(resultat.Position)
				for _, emetteur in souffle.emetteurs do
					emetteur.Rate = 22 * intensite
				end
			else
				arreterSouffle()
			end
		elseif souffle then
			arreterSouffle()
		end
	end)
end

--------------------------------------------------------------------
-- Boucliers : apparition rapide (la bulle jaillit avec un rebond, flash lumineux, onde au sol)
-- et disparition (la bulle se rétracte en s'effaçant)
--------------------------------------------------------------------
do
	local TweenService = game:GetService("TweenService")

	local function tween(objet, duree, proprietes, style, direction)
		local t = TweenService:Create(objet, TweenInfo.new(duree, style or Enum.EasingStyle.Quad,
			direction or Enum.EasingDirection.Out), proprietes)
		t:Play()
		return t
	end

	local function effetTemporaire(proprietes)
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Material = Enum.Material.Neon
		for cle, valeur in proprietes do p[cle] = valeur end
		p.Parent = workspace
		return p
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
			for _, piece in pieces do piece.Transparency = transparence end
		end)
	end

	exterieur:GetAttributeChangedSignal("Etat"):Connect(function()
		local etat = exterieur:GetAttribute("Etat")
		if etat == E.Demat then
			if enAttente then enAttente:Destroy() enAttente = nil end
			-- Pas d'empreinte pour un départ discret : camouflé, porté (téléportation de poche) ou en vol libre
			if exterieur:GetAttribute("Camouflage") == true or exterieur:GetAttribute("Porteur") or exterieur:GetAttribute("VolLibre") then return end
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