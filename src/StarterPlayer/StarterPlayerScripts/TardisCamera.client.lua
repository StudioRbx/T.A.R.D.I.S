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

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

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
aide.Size = UDim2.fromOffset(420, 24)
aide.BackgroundTransparency = 1
aide.TextColor3 = Color3.new(1, 1, 1)
aide.TextStrokeTransparency = 0.5
aide.Font = Enum.Font.Gotham
aide.TextSize = 15
local AIDE_TOIT = "Clic droit + souris pour regarder · Molette pour monter/descendre"
local AIDE_ORBITE = "Orbite autour de la cabine · Clic droit + souris pour la hauteur · Molette pour la distance"
aide.Text = AIDE_TOIT
aide.Parent = gui

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

local function chargerZone()
	-- Avec le Streaming, on demande à charger la zone autour du TARDIS
	if workspace.StreamingEnabled then
		task.spawn(function()
			pcall(function()
				joueur:RequestStreamAroundAsync(sommetLampe())
			end)
		end)
	end
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

local function majCamera(dt)
	-- Stick droit de manette : rotation continue
	if stick.Magnitude > 0.15 then
		yaw -= stick.X * VITESSE_STICK * dt
		pitch = math.clamp(pitch + stick.Y * VITESSE_STICK * dt, PITCH_MIN, PITCH_MAX)
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

	local position = sommetLampe() + Vector3.new(0, hauteur, 0)
	camera.CFrame = CFrame.new(position)
		* CFrame.Angles(0, math.rad(yaw), 0)
		* CFrame.Angles(math.rad(pitch), 0, 0)
end

local function afficherMode()
	boutonOrbite.Text = mode == "orbite" and "Vue du toit" or "Orbite"
	boutonOrbite.BackgroundColor3 = (mode == "orbite" or orbitePermise()) and Color3.fromRGB(40, 40, 90) or Color3.fromRGB(45, 45, 55)
	aide.Text = mode == "orbite" and AIDE_ORBITE or AIDE_TOIT
	-- X sert à la démat en vol libre : le pilote du vol quitte par le bouton (ou B à la manette)
	quitter.Text = piloteDuVol() and "Quitter la caméra" or "Quitter la caméra (X)"
	joueur:SetAttribute("TardisOrbiteActive", (actif and mode == "orbite") or nil)
end

sortir = function()
	if not actif then return end
	actif = false
	mode = "toit"
	ouverteParLeVol = false
	RunService:UnbindFromRenderStep("TardisCamera")

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
	mode = "orbite"
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
	elseif not traite and ((input.KeyCode == Enum.KeyCode.X and not piloteDuVol()) or input.KeyCode == Enum.KeyCode.ButtonB) then
		sortir() -- V6.9.10 : en vol libre, X fait la démat / remat ; le pilote quitte par le bouton ou B
	end
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