-- StarterPlayer > StarterPlayerScripts > TardisCamera (LocalScript)
-- Bouton "BoutonCamera" de la console : place la caméra au-dessus de la Lampe du TARDIS
-- pour voir tout autour. Tout est local : chaque joueur ne contrôle que sa propre caméra.
--
-- Commandes : clic droit maintenu + souris (ou glisser au doigt / stick droit) pour regarder,
-- molette pour monter/descendre, X (ou le bouton à l'écran) pour quitter.
--
-- Orbite (V6.9.10) : bouton « Orbite » à l'écran (ou ORBITE dans le vol libre) : la caméra tourne lentement autour de
-- la cabine. Réservée au pilote du vol libre en CROISIÈRE (sa caméra ne dirige plus le TARDIS) ; elle se ferme seule
-- quand la croisière s'arrête. Pas de boucle en plus : elle passe par la même boucle de rendu que la vue du toit.
--
-- V7.4.2 (Config.CameraExterieure) : parasites à l'entrée et à la sortie, V vue du dessus, Z zoom optique, N vision de
-- nuit, C cadre de surveillance, P point de vue (Lampe, au-dessus de la porte, sous la cabine en vol libre), clic sur
-- un joueur pour le suivre, image qui se brouille quand le TARDIS est abîmé. Ces touches sont réservées à la caméra
-- pendant qu'elle est ouverte (ContextActionService), et rendues à la sortie.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
-- V7.4.2 : touches de la caméra (comme TardisMenu : sans ContextActionService, elles passent par UserInputService)
local ContextActionService = nil
pcall(function() ContextActionService = game:GetService("ContextActionService") end)

local Config = require(ReplicatedStorage:WaitForChild("TardisConfig"))
local UI = require(ReplicatedStorage:WaitForChild("TardisUI")) -- V6.9.10 : « réduire les effets » (orbite plus lente)

local joueur = Players.LocalPlayer
local camera = workspace.CurrentCamera

local def, monRole = Config.attendreMonTardis(joueur) -- le TARDIS de ce joueur (pilote ou technicien)
local exterieur, interieur = Config.modeles(def)
local bouton = Config.Trouver(interieur, "BoutonCamera")
local lampe = exterieur:FindFirstChild(Config.NomLampe, true)

local HAUTEUR_DEPART = Config.HauteurCamera or 3
local HAUTEUR_MAX = Config.HauteurCameraMax or 40
local SENSIBILITE = 0.3           -- degrés par pixel de mouvement
local VITESSE_STICK = 120         -- degrés par seconde au stick de manette
local PITCH_MIN, PITCH_MAX = -85, 30
local ORBITE = Config.CameraOrbite or {} -- V6.9.10
local CAM = Config.CameraExterieure or {} -- V7.4.2
local GROSSISSEMENTS = CAM.Grossissements or { 1, 2, 4 }

if not lampe then
	warn("[TARDIS] Caméra : aucune Part nommée '" .. Config.NomLampe .. "' dans le TARDIS")
	return
end

-- Sommet de la Lampe, qu'elle soit une Part ou un Model (recalculé à chaque image : le TARDIS bouge)
local function sommetLampe()
	if lampe:IsA("BasePart") then
		return lampe.Position + Vector3.new(0, lampe.Size.Y / 2, 0)
	end
	local cf, taille = lampe:GetBoundingBox()
	return cf.Position + Vector3.new(0, taille.Y / 2, 0)
end

--------------------------------------------------------------------
-- Interface
--------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "TardisCameraGui"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = joueur:WaitForChild("PlayerGui")

local quitter = Instance.new("TextButton")
quitter.AnchorPoint = Vector2.new(0.5, 1)
quitter.Position = UDim2.new(0.5, 0, 1, -30)
quitter.Size = UDim2.fromOffset(260, 44)
quitter.BackgroundColor3 = Color3.fromRGB(10, 30, 70)
quitter.TextColor3 = Color3.new(1, 1, 1)
quitter.Font = Enum.Font.GothamBold
quitter.TextSize = 18
quitter.Text = "Quitter la caméra (X)"
quitter.Parent = gui
Instance.new("UICorner").Parent = quitter

-- V6.9.10 : passer de la vue du toit à l'orbite (et retour), à côté du bouton pour quitter
local boutonOrbite = Instance.new("TextButton")
boutonOrbite.AnchorPoint = Vector2.new(0, 1)
boutonOrbite.Position = UDim2.new(0.5, 140, 1, -30)
boutonOrbite.Size = UDim2.fromOffset(170, 44)
boutonOrbite.BackgroundColor3 = Color3.fromRGB(40, 40, 90)
boutonOrbite.TextColor3 = Color3.new(1, 1, 1)
boutonOrbite.Font = Enum.Font.GothamBold
boutonOrbite.TextSize = 16
boutonOrbite.Text = "Orbite"
boutonOrbite.Parent = gui
Instance.new("UICorner").Parent = boutonOrbite

local aide = Instance.new("TextLabel")
aide.AnchorPoint = Vector2.new(0.5, 1)
aide.Position = UDim2.new(0.5, 0, 1, -82)
aide.Size = UDim2.fromOffset(620, 60) -- V7.4.2 : trois lignes (aide, touches, état de la caméra)
aide.TextWrapped = true
aide.TextYAlignment = Enum.TextYAlignment.Bottom
aide.BackgroundTransparency = 1
aide.TextColor3 = Color3.new(1, 1, 1)
aide.TextStrokeTransparency = 0.5
aide.Font = Enum.Font.Gotham
aide.TextSize = 15
local AIDE_TOIT = "Clic droit + souris pour regarder · Molette pour monter/descendre"
local AIDE_ORBITE = "Orbite autour de la cabine · Clic droit + souris pour la hauteur · Molette pour la distance"
local TOUCHES = "V dessus · Z zoom · N nuit · C cadre · P point de vue · clic sur un joueur : le suivre" -- V7.4.2
local TOUCHES_ORBITE = "Z zoom · N nuit · C cadre"
aide.Text = AIDE_TOIT
aide.Parent = gui

-- V7.4.2 (G-283) Cadre de caméra de surveillance : heure, nom de la vue, « REC » qui clignote, lignes de balayage
local cadreSurveillance = Instance.new("Frame")
cadreSurveillance.Name = "CadreSurveillance"
cadreSurveillance.Size = UDim2.fromScale(1, 1)
cadreSurveillance.BackgroundTransparency = 1
cadreSurveillance.Visible = false
cadreSurveillance.Parent = gui
local function etiquetteCadre(position, ancre, alignement, couleur)
	local e = Instance.new("TextLabel")
	e.AnchorPoint = ancre
	e.Position = position
	e.Size = UDim2.fromOffset(320, 26)
	e.BackgroundTransparency = 1
	e.TextColor3 = couleur
	e.TextStrokeTransparency = 0.4
	e.Font = Enum.Font.Code
	e.TextSize = 22
	e.TextXAlignment = alignement
	e.Parent = cadreSurveillance
	return e
end
local heureCadre = etiquetteCadre(UDim2.fromOffset(18, 14), Vector2.zero, Enum.TextXAlignment.Left, Color3.new(1, 1, 1))
local vueCadre = etiquetteCadre(UDim2.fromOffset(18, 42), Vector2.zero, Enum.TextXAlignment.Left, Color3.new(1, 1, 1))
local recCadre = etiquetteCadre(UDim2.new(1, -18, 0, 14), Vector2.new(1, 0), Enum.TextXAlignment.Right, Color3.fromRGB(255, 50, 50))
recCadre.Text = "● REC"
for i = 0, 47 do
	local ligne = Instance.new("Frame")
	ligne.BorderSizePixel = 0
	ligne.BackgroundColor3 = Color3.new(0, 0, 0)
	ligne.BackgroundTransparency = 0.82
	ligne.Size = UDim2.new(1, 0, 0, 1)
	ligne.Position = UDim2.fromScale(0, i / 48)
	ligne.Parent = cadreSurveillance
end

-- V7.4.2 (G-282, G-289) Parasites : un écran à part, qui reste visible un instant après la sortie de la caméra
local guiParasites = Instance.new("ScreenGui")
guiParasites.Name = "TardisCameraParasites"
guiParasites.ResetOnSpawn = false
guiParasites.IgnoreGuiInset = true
guiParasites.DisplayOrder = 60
guiParasites.Enabled = false
guiParasites.Parent = joueur:WaitForChild("PlayerGui")
local fondParasites = Instance.new("Frame")
fondParasites.BorderSizePixel = 0
fondParasites.Size = UDim2.fromScale(1, 1)
fondParasites.Parent = guiParasites
local bandesParasites = {}
for _ = 1, 10 do
	local bande = Instance.new("Frame")
	bande.BorderSizePixel = 0
	bande.Parent = guiParasites
	table.insert(bandesParasites, bande)
end

-- (V6.9.15, proposition 72) Les boutons et l'aide suivent la taille de l'interface ; le bouton Orbite et l'aide se
-- recalent pour ne jamais chevaucher « Quitter » (à 100 % : exactement les positions d'avant)
local echellesCamera = {}
local function placerBoutonsCamera()
	local s = UI.tailleInterface()
	for _, echelle in echellesCamera do echelle.Scale = s end
	boutonOrbite.Position = UDim2.new(0.5, math.floor(130 * s + 10 + 0.5), 1, -30)
	aide.Position = UDim2.new(0.5, 0, 1, -math.floor(30 + 44 * s + 8 + 0.5))
end
for _, objet in { quitter, boutonOrbite, aide } do
	local echelle = Instance.new("UIScale")
	echelle.Parent = objet
	table.insert(echellesCamera, echelle)
end
placerBoutonsCamera()
UI.prefsChangees.Event:Connect(function(cle) if cle == "taille" then placerBoutonsCamera() end end)

local prompt = Instance.new("ProximityPrompt")
prompt.ActionText = "Caméra extérieure"
prompt.ObjectText = "Console"
prompt.HoldDuration = 0
prompt.MaxActivationDistance = 8
prompt.RequiresLineOfSight = false
prompt.Parent = bouton

--------------------------------------------------------------------
-- Contrôles du personnage (bloqués pendant la caméra)
--------------------------------------------------------------------
local function controlesPersonnage(actives)
	pcall(function()
		local module = require(joueur:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
		local controles = module:GetControls()
		if actives then controles:Enable() else controles:Disable() end
	end)
end

--------------------------------------------------------------------
-- Mode caméra
--------------------------------------------------------------------
local actif = false
local yaw, pitch, hauteur = 0, -25, HAUTEUR_DEPART
local clicDroit = false
local stick = Vector2.zero
-- Orbite (V6.9.10) : mode "toit" (au-dessus de la Lampe, comme avant) ou "orbite" (autour de la cabine)
local mode = "toit"
local angleOrbite, distanceOrbite, dernierChargement = 0, ORBITE.Distance or 30, 0
local ouverteParLeVol = false -- caméra ouverte par le bouton ORBITE du vol libre : la refermer rend la caméra de pilotage
-- V7.4.2 : point de vue (G-288), vue du dessus (G-278), zoom (G-285), vision de nuit (G-284), cadre (G-283), suivi (G-287)
local point, dessus, hauteurDessus = "Lampe", false, CAM.HauteurDessus or 60
local zoom, champDepart = 1, nil
local nuit, effetNuit = false, nil
local cadre = UI.pref("cameraCadre", CAM.CadreSurveillance == true) == true
local cible, angleSuivi, distanceSuivi = nil, 0, CAM.DistanceSuivi or 14
local debutParasites, dureeParasites, forceParasitesMax, parasitesEnCours = 0, 0, 0, false
local NOMS_POINTS = { Lampe = "CAM 1 · LAMPE", Porte = "CAM 2 · PORTE", Dessous = "CAM 3 · DESSOUS" }

local function chargerZone(position)
	-- Avec le Streaming, on demande à charger la zone autour du TARDIS (ou du joueur suivi)
	if workspace.StreamingEnabled then
		task.spawn(function()
			pcall(function()
				joueur:RequestStreamAroundAsync(position or sommetLampe())
			end)
		end)
	end
end

-- V7.4.2 (G-282, G-289) Une image de parasites ; faux quand le grésillement est fini
local function majParasites()
	local force = Config.forceParasites(os.clock() - debutParasites, dureeParasites) * forceParasitesMax
	if force <= 0 then
		guiParasites.Enabled = false
		return false
	end
	guiParasites.Enabled = true
	local gris = math.random(40, 200)
	fondParasites.BackgroundColor3 = Color3.fromRGB(gris, gris, gris)
	fondParasites.BackgroundTransparency = 1 - 0.85 * force
	for _, bande in bandesParasites do
		local g = math.random(0, 255)
		bande.BackgroundColor3 = Color3.fromRGB(g, g, g)
		bande.Position = UDim2.fromScale(0, math.random())
		bande.Size = UDim2.new(1, 0, 0, math.random(2, 24))
		bande.BackgroundTransparency = 1 - 0.9 * force
	end
	return true
end
-- Grésillement de « duree » secondes ; plus doux avec « réduire les effets » ou « aucun flash ». Une petite boucle
-- (task.wait) qui ne vit que le temps du grésillement.
local function gresiller(duree, force)
	if CAM.Parasites == false then return end
	debutParasites, dureeParasites = os.clock(), duree or CAM.DureeParasites or 0.3
	forceParasitesMax = (force or 1) * ((UI.effetsReduits() or UI.sansFlash()) and 0.4 or 1)
	if parasitesEnCours then return end
	parasitesEnCours = true
	task.spawn(function()
		while majParasites() do task.wait(0.03) end -- environ 30 images de parasites par seconde
		parasitesEnCours = false
	end)
end

local function grossissement() return GROSSISSEMENTS[zoom] or 1 end
-- V7.4.2 (G-288) Le TARDIS vole (vol libre) : le point de vue sous la cabine est permis
local function enVol() return exterieur:GetAttribute("VolLibre") ~= nil end
local function directionPorte()
	local devant = exterieur.PrimaryPart.CFrame.LookVector
	return devant, math.deg(math.atan2(-devant.X, -devant.Z))
end
-- Position des points de vue « Porte » (au-dessus de la porte, un peu devant) et « Dessous » (sous la cabine)
local function positionPointDeVue(nom)
	local cf, taille = exterieur:GetBoundingBox()
	if nom == "Porte" then
		local devant = directionPorte()
		return cf.Position + devant * (math.max(taille.X, taille.Z) / 2 + 1) + cf.UpVector * (taille.Y / 2 - 1)
	end
	return cf.Position - cf.UpVector * (taille.Y / 2 + 2)
end

-- Pilote du vol libre en cours (sa caméra dirige le TARDIS, sauf en croisière)
local function piloteDuVol()
	return exterieur:GetAttribute("VolLibre") == joueur.UserId
end
-- V6.9.10 : l'orbite n'est permise qu'au pilote du vol libre en croisière (attribut local posé par TardisVolLibre)
local function orbitePermise()
	return piloteDuVol() and joueur:GetAttribute("TardisCroisiere") == true and exterieur:GetAttribute("Alimentation") ~= false
end

-- Taille de la cabine (V6.9.10) : petit TARDIS (Echelle) et vol de précision (30 %) rapprochent la caméra
local function echelleCabine()
	local echelle = tonumber(exterieur:GetAttribute("Echelle")) or 1
	if exterieur:GetAttribute("VolPrecision") == true then echelle *= 0.3 end
	return math.clamp(echelle, 0.1, 2)
end

local sortir -- définie plus bas (l'orbite se ferme seule quand la croisière s'arrête)
local afficherMode -- V7.4.2 : définie plus bas

-- V7.4.2 (G-287) Relâche le joueur suivi : retour à la vue de la Lampe
local function relacher()
	if mode ~= "suivi" then return end
	mode, cible = "toit", nil
	gresiller(0.15, 0.5)
	afficherMode()
end

local function majCamera(dt)
	-- Stick droit de manette : rotation continue
	if stick.Magnitude > 0.15 then
		yaw -= stick.X * VITESSE_STICK * dt
		pitch = math.clamp(pitch + stick.Y * VITESSE_STICK * dt, PITCH_MIN, PITCH_MAX)
	end

	-- V7.4.2 (G-285) zoom optique (gardé à chaque image : d'autres effets changent aussi le champ)
	if champDepart then camera.FieldOfView = Config.champZoom(champDepart, grossissement()) end
	-- V7.4.2 (G-289) le TARDIS est abîmé : l'image se brouille par moments
	local pv = tonumber(exterieur:GetAttribute("PointsDeVie"))
	if pv and not parasitesEnCours and math.random() < Config.chanceBrouillage(pv, dt, CAM.SeuilBrouillage, CAM.BrouillagesParMinute) then
		local seuil = CAM.SeuilBrouillage or 50
		gresiller(CAM.DureeBrouillage or 0.2, 0.5 + 0.5 * math.clamp((seuil - pv) / seuil, 0, 1))
	end
	-- V7.4.2 (G-283) cadre de surveillance : heure et « REC » qui clignote
	if cadre then
		heureCadre.Text = os.date("%H:%M:%S")
		recCadre.Visible = os.clock() % 1 < 0.6
	end

	if mode == "suivi" then
		-- V7.4.2 (G-287) tourne lentement autour du joueur suivi ; il part ou disparaît : on le relâche
		local racine = cible and cible.Parent and cible.Character and cible.Character:FindFirstChild("HumanoidRootPart")
		if not racine then
			relacher()
			return
		end
		local vitesse = (CAM.VitesseSuivi or 12) * (UI.effetsReduits() and 0.5 or 1)
		angleSuivi = (angleSuivi + vitesse * dt) % 360
		local centre = racine.Position
		local elevation = math.rad(math.clamp(-pitch, -10, 70))
		local a = math.rad(angleSuivi + yaw)
		local position = centre + Vector3.new(math.sin(a) * math.cos(elevation), math.sin(elevation), math.cos(a) * math.cos(elevation)) * distanceSuivi
		camera.CFrame = CFrame.lookAt(position, centre)
		if os.clock() - dernierChargement > (ORBITE.RechargeZone or 4) then
			dernierChargement = os.clock()
			chargerZone(centre)
		end
		return
	end

	if mode == "orbite" then
		-- V6.9.10 : la croisière s'arrête (touche, frein, urgence, atterrissage, fin du vol) : la caméra revient au pilotage
		if not orbitePermise() then
			sortir()
			return
		end
		local vitesse = (ORBITE.Vitesse or 8) * (UI.effetsReduits() and 0.5 or 1)
		angleOrbite = (angleOrbite + vitesse * dt) % 360
		local pivot = exterieur:GetPivot()
		local centre = (pivot.Position + sommetLampe()) / 2 -- milieu de la cabine, qui bouge en vol chez chaque joueur
		local distance = distanceOrbite * echelleCabine()
		local elevation = math.rad(math.clamp(-pitch, -10, 70))
		local a = math.rad(angleOrbite + yaw)
		local position = centre + Vector3.new(math.sin(a) * math.cos(elevation), math.sin(elevation), math.cos(a) * math.cos(elevation)) * distance
		camera.CFrame = CFrame.lookAt(position, centre)
		-- Streaming : la zone autour de la cabine est rechargée régulièrement (le TARDIS avance)
		if os.clock() - dernierChargement > (ORBITE.RechargeZone or 4) then
			dernierChargement = os.clock()
			chargerZone()
		end
		return
	end

	-- V7.4.2 (G-288) sous la cabine : seulement en vol libre (à l'atterrissage, retour à la Lampe)
	if point == "Dessous" and not enVol() then
		point = "Lampe"
		afficherMode()
	end
	if point ~= "Lampe" then
		camera.CFrame = CFrame.new(positionPointDeVue(point))
			* CFrame.Angles(0, math.rad(yaw), 0)
			* CFrame.Angles(math.rad(pitch), 0, 0)
		return
	end
	-- V7.4.2 (G-278) vue du dessus : droit vers le bas, la souris fait tourner la carte
	if dessus then
		camera.CFrame = CFrame.new(sommetLampe() + Vector3.new(0, hauteurDessus, 0))
			* CFrame.Angles(0, math.rad(yaw), 0)
			* CFrame.Angles(math.rad(-90), 0, 0)
		return
	end

	local position = sommetLampe() + Vector3.new(0, hauteur, 0)
	camera.CFrame = CFrame.new(position)
		* CFrame.Angles(0, math.rad(yaw), 0)
		* CFrame.Angles(math.rad(pitch), 0, 0)
end

afficherMode = function()
	boutonOrbite.Text = mode == "orbite" and "Vue du toit" or "Orbite"
	boutonOrbite.BackgroundColor3 = (mode == "orbite" or orbitePermise()) and Color3.fromRGB(40, 40, 90) or Color3.fromRGB(45, 45, 55)
	-- V7.4.2 : aide, touches, puis l'état de la caméra (vue, zoom, nuit)
	local vue
	if mode == "orbite" then
		vue = "CAM · ORBITE"
	elseif mode == "suivi" then
		vue = "CAM · SUIVI " .. string.upper(cible and cible.DisplayName or "")
	else
		vue = dessus and "CAM 1 · DESSUS" or NOMS_POINTS[point]
	end
	local etat = { mode == "suivi" and ("Suivi de " .. (cible and cible.DisplayName or "?") .. " · clic pour le relâcher") or vue }
	if grossissement() > 1 then table.insert(etat, "Zoom × " .. grossissement()) end
	if nuit then table.insert(etat, "Vision de nuit") end
	aide.Text = (mode == "orbite" and AIDE_ORBITE or AIDE_TOIT) .. "\n" .. (mode == "orbite" and TOUCHES_ORBITE or TOUCHES) .. "\n" .. table.concat(etat, " · ")
	vueCadre.Text = vue
	cadreSurveillance.Visible = actif and cadre
	-- X sert à la démat en vol libre : le pilote du vol quitte par le bouton (ou B à la manette)
	quitter.Text = piloteDuVol() and "Quitter la caméra" or "Quitter la caméra (X)"
	joueur:SetAttribute("TardisOrbiteActive", (actif and mode == "orbite") or nil)
end

-- V7.4.2 (G-284) effet de vision de nuit, créé à la première utilisation (dans la caméra : local à ce joueur)
local function visionNuit()
	if not effetNuit then
		effetNuit = Instance.new("ColorCorrectionEffect")
		effetNuit.Name = "TardisVisionNuit"
		effetNuit.TintColor = CAM.CouleurNuit or Color3.fromRGB(110, 255, 120)
		effetNuit.Brightness = CAM.LuminositeNuit or 0.3
		effetNuit.Contrast = 0.15
		effetNuit.Saturation = -1
		effetNuit.Enabled = false
		effetNuit.Parent = camera
	end
	return effetNuit
end

-- V7.4.2 : les commandes des touches
local function basculerDessus() -- G-278
	if mode ~= "toit" then return end
	if point ~= "Lampe" then
		point, dessus = "Lampe", true
	else
		dessus = not dessus
	end
	if dessus then
		hauteurDessus = CAM.HauteurDessus or 60
		chargerZone()
	end
	gresiller(0.15, 0.5)
	afficherMode()
end
local function changerZoom() -- G-285
	zoom = zoom % #GROSSISSEMENTS + 1
	afficherMode()
end
local function basculerNuit() -- G-284
	nuit = not nuit
	visionNuit().Enabled = nuit
	afficherMode()
end
local function basculerCadre() -- G-283 (le choix est gardé dans les préférences)
	cadre = not cadre
	UI.setPref("cameraCadre", cadre)
	afficherMode()
end
local function changerPointDeVue() -- G-288
	if mode ~= "toit" then return end
	point = Config.pointDeVueSuivant(dessus and "Lampe" or point, enVol())
	dessus = false
	local _, angle = directionPorte()
	yaw = angle
	pitch = point == "Dessous" and -80 or (point == "Porte" and -20 or -25)
	gresiller(0.15, 0.5)
	afficherMode()
end

local ACTIONS = {
	{ nom = "TardisCameraDessus", touche = CAM.ToucheDessus or "V", manette = Enum.KeyCode.DPadUp, titre = "Dessus", f = basculerDessus },
	{ nom = "TardisCameraZoom", touche = CAM.ToucheZoom or "Z", manette = Enum.KeyCode.DPadDown, titre = "Zoom", f = changerZoom },
	{ nom = "TardisCameraNuit", touche = CAM.ToucheNuit or "N", manette = Enum.KeyCode.DPadLeft, titre = "Nuit", f = basculerNuit },
	{ nom = "TardisCameraCadre", touche = CAM.ToucheCadre or "C", titre = "Cadre", f = basculerCadre },
	{ nom = "TardisCameraPointDeVue", touche = CAM.TouchePointDeVue or "P", manette = Enum.KeyCode.DPadRight, titre = "Vue", f = changerPointDeVue },
}
local function lierTouches(lier)
	if not ContextActionService then return end
	for _, action in ACTIONS do
		if lier then
			-- (V7.5.4.2) Les touches sont mises en liste sans trou : une action sans touche de manette (Cadre) passait
			-- nil à BindActionAtPriority, qui levait une erreur au milieu d'entrer() : la caméra restait « active »
			-- sans s'ouvrir et le bouton ne répondait plus. Une touche mal écrite dans les réglages est ignorée.
			local touches = {}
			local okTouche, touche = pcall(function() return Enum.KeyCode[action.touche] end)
			if okTouche and touche then table.insert(touches, touche) end
			if action.manette then table.insert(touches, action.manette) end
			local okLien = pcall(function()
				ContextActionService:BindActionAtPriority(action.nom, function(_, etat)
					if etat == Enum.UserInputState.Begin then action.f() end
					return Enum.ContextActionResult.Sink
				end, true, Enum.ContextActionPriority.High.Value, table.unpack(touches))
				ContextActionService:SetTitle(action.nom, action.titre)
			end)
			if not okLien then warn("[TARDIS] Caméra : touche « " .. tostring(action.touche) .. " » non liée (" .. action.nom .. ")") end
		else
			ContextActionService:UnbindAction(action.nom)
		end
	end
end

-- V7.4.2 (G-287) Le joueur visé par un clic (coordonnées de l'écran), s'il y en a un
local function joueurVise(x, y)
	local rayon = camera:ScreenPointToRay(x, y)
	local autres, positions = {}, {}
	for _, autre in Players:GetPlayers() do
		local racine = autre ~= joueur and autre.Character and autre.Character:FindFirstChild("HumanoidRootPart")
		if racine then
			table.insert(autres, autre)
			table.insert(positions, racine.Position)
		end
	end
	local i = Config.cibleVisee(rayon.Origin, rayon.Direction.Unit, positions, CAM.ToleranceClic, CAM.PorteeClic)
	return i and autres[i]
end
local function cliquer(x, y)
	if not actif or mode == "orbite" then return end
	if mode == "suivi" then
		relacher()
		return
	end
	local autre = joueurVise(x, y)
	local racine = autre and autre.Character and autre.Character:FindFirstChild("HumanoidRootPart")
	if not racine then return end
	cible, mode = autre, "suivi"
	local ecart = camera.CFrame.Position - racine.Position -- on part du côté où l'on est
	angleSuivi = math.deg(math.atan2(ecart.X, ecart.Z))
	yaw, pitch, distanceSuivi, dernierChargement = 0, -20, CAM.DistanceSuivi or 14, 0
	gresiller(0.15, 0.5)
	afficherMode()
end

sortir = function()
	if not actif then return end
	actif = false
	mode = "toit"
	ouverteParLeVol = false
	RunService:UnbindFromRenderStep("TardisCamera")
	-- V7.4.2 : touches rendues, zoom et vision de nuit retirés, grésillement de sortie
	lierTouches(false)
	if champDepart then camera.FieldOfView = champDepart end
	champDepart, zoom, nuit, cible, point, dessus = nil, 1, false, nil, "Lampe", false
	if effetNuit then effetNuit.Enabled = false end
	gresiller()

	camera.CameraType = Enum.CameraType.Custom
	-- V6.9.10 : le pilote du vol libre retrouve sa caméra de pilotage (la cible créée par TardisVolLibre)
	local cibleVol = piloteDuVol() and workspace:FindFirstChild("TardisCibleCamera")
	local personnage = joueur.Character
	local humanoid = personnage and personnage:FindFirstChildOfClass("Humanoid")
	if cibleVol then
		camera.CameraSubject = cibleVol
	elseif humanoid then
		camera.CameraSubject = humanoid
	end

	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	clicDroit = false
	controlesPersonnage(true)
	gui.Enabled = false
	prompt.Enabled = exterieur:GetAttribute("Alimentation") ~= false
	afficherMode()
end

local function entrer()
	if joueur:GetAttribute("TardisPilote_" .. def.Nom) ~= true then return end -- réservé aux joueurs autorisés
	if actif then return end -- utilisable à tout moment : posé, décollage, vol, atterrissage
	if exterieur:GetAttribute("Alimentation") == false then return end -- plus de courant : plus de caméra
	actif = true
	mode = "toit"

	-- Regard de départ : dans la direction de la porte, un peu vers le bas
	local devant = exterieur.PrimaryPart.CFrame.LookVector
	yaw = math.deg(math.atan2(-devant.X, -devant.Z))
	pitch, hauteur = -25, HAUTEUR_DEPART
	-- V7.4.2 : champ de départ (rendu à la sortie), touches de la caméra, grésillement d'entrée
	point, dessus, zoom, nuit, cible, champDepart = "Lampe", false, 1, false, nil, camera.FieldOfView
	lierTouches(true)
	gresiller()

	chargerZone()

	controlesPersonnage(false)
	camera.CameraType = Enum.CameraType.Scriptable
	gui.Enabled = true
	prompt.Enabled = false
	RunService:BindToRenderStep("TardisCamera", Enum.RenderPriority.Camera.Value + 2, majCamera)
	afficherMode()
end

prompt.Triggered:Connect(entrer)

-- Orbite (V6.9.10) : bascule entre la vue du toit et l'orbite. Hors croisière, l'orbite est refusée (le message
-- d'aide le dit) ; depuis le vol libre (bouton ORBITE), la caméra s'ouvre directement en orbite.
local function basculerOrbite()
	if mode == "orbite" then
		if ouverteParLeVol then
			sortir() -- ouverte depuis le vol libre : on revient directement à la caméra de pilotage
			return
		end
		mode = "toit"
		afficherMode()
		return
	end
	if not orbitePermise() then
		if actif then aide.Text = "Orbite : seulement pour le pilote du vol libre, en croisière" end
		return
	end
	local depuisLeVol = not actif
	if not actif then entrer() end
	if not actif then return end
	ouverteParLeVol = depuisLeVol
	mode, cible = "orbite", nil
	-- Départ derrière la cabine, un peu au-dessus de l'horizon
	local devant = exterieur:GetPivot().LookVector
	angleOrbite = math.deg(math.atan2(-devant.X, -devant.Z))
	yaw = 0
	pitch = -(ORBITE.Elevation or 20)
	distanceOrbite = ORBITE.Distance or 30
	dernierChargement = 0
	afficherMode()
end
boutonOrbite.Activated:Connect(basculerOrbite)
joueur:GetAttributeChangedSignal("TardisDemandeOrbite"):Connect(basculerOrbite) -- bouton ORBITE du vol libre
joueur:GetAttributeChangedSignal("TardisCroisiere"):Connect(function()
	if actif then afficherMode() end
	-- (la fermeture de l'orbite se fait dans majCamera, à l'image suivante)
end)

-- Courant coupé : le bouton caméra ne répond plus
local function majPromptCamera()
	local alimente = exterieur:GetAttribute("Alimentation") ~= false
	if not alimente and actif then
		sortir() -- coupure de courant : la caméra extérieure s'éteint
	end
	prompt.Enabled = not actif and alimente
end
exterieur:GetAttributeChangedSignal("Alimentation"):Connect(majPromptCamera)
quitter.Activated:Connect(sortir)

--------------------------------------------------------------------
-- Entrées : souris, tactile, manette, clavier
--------------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, traite)
	if not actif then return end
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		clicDroit = true
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 and not traite then
		cliquer(input.Position.X, input.Position.Y) -- V7.4.2 (G-287) suivre le joueur cliqué, ou le relâcher
	elseif not traite and ((input.KeyCode == Enum.KeyCode.X and not piloteDuVol()) or input.KeyCode == Enum.KeyCode.ButtonB) then
		sortir() -- V6.9.10 : en vol libre, X fait la démat / remat ; le pilote quitte par le bouton ou B
	elseif not traite and not ContextActionService then
		for _, action in ACTIONS do -- V7.4.2 : sans ContextActionService, les touches de la caméra arrivent ici
			if input.KeyCode == Enum.KeyCode[action.touche] or (action.manette and input.KeyCode == action.manette) then action.f() end
		end
	end
end)
-- V7.4.2 (G-287) au doigt : une petite touche sur un joueur
UserInputService.TouchTap:Connect(function(positions, traite)
	if actif and not traite and positions[1] then cliquer(positions[1].X, positions[1].Y) end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		clicDroit = false
		if actif then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
	elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
		stick = Vector2.zero
	end
end)

UserInputService.InputChanged:Connect(function(input, traite)
	if not actif then return end

	if input.UserInputType == Enum.UserInputType.MouseMovement and clicDroit then
		yaw -= input.Delta.X * SENSIBILITE
		pitch = math.clamp(pitch - input.Delta.Y * SENSIBILITE, PITCH_MIN, PITCH_MAX)
	elseif input.UserInputType == Enum.UserInputType.Touch and not traite then
		yaw -= input.Delta.X * SENSIBILITE
		pitch = math.clamp(pitch - input.Delta.Y * SENSIBILITE, PITCH_MIN, PITCH_MAX)
	elseif input.UserInputType == Enum.UserInputType.MouseWheel and not traite then
		if mode == "orbite" then
			-- V6.9.10 : la molette rapproche ou éloigne la caméra de la cabine
			distanceOrbite = math.clamp(distanceOrbite - input.Position.Z * 2, ORBITE.DistanceMin or 25, ORBITE.DistanceMax or 35)
		elseif mode == "suivi" then
			distanceSuivi = math.clamp(distanceSuivi - input.Position.Z * 2, 6, 40) -- V7.4.2 : plus près ou plus loin du joueur
		elseif dessus then
			hauteurDessus = math.clamp(hauteurDessus + input.Position.Z * 5, CAM.HauteurDessusMin or 25, CAM.HauteurDessusMax or 150) -- V7.4.2
		else
			hauteur = math.clamp(hauteur + input.Position.Z * 2, 1, HAUTEUR_MAX)
		end
	elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
		stick = Vector2.new(input.Position.X, input.Position.Y)
	end
end)

--------------------------------------------------------------------
-- Sorties automatiques
--------------------------------------------------------------------
-- La caméra reste active pendant tout le voyage : elle suit la Lampe, donc pendant le vol
-- elle se retrouve au-dessus du point d'atterrissage et on voit le TARDIS se matérialiser.
-- À chaque changement d'état, on redemande le chargement de la zone (le TARDIS a pu changer d'endroit).
exterieur:GetAttributeChangedSignal("Etat"):Connect(function()
	if actif then
		chargerZone()
	end
end)

-- Le personnage meurt ou réapparaît : on rend la caméra
joueur.CharacterRemoving:Connect(sortir)