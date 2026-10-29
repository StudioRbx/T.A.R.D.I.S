-- StarterPlayer > StarterPlayerScripts > TardisCamera (LocalScript)
-- Bouton "BoutonCamera" de la console : place la caméra au-dessus de la Lampe du TARDIS
-- pour voir tout autour. Tout est local : chaque joueur ne contrôle que sa propre caméra.
--
-- Commandes : clic droit maintenu + souris (ou glisser au doigt / stick droit) pour regarder,
-- molette pour monter/descendre, X (ou le bouton à l'écran) pour quitter.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("TardisConfig"))

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

local aide = Instance.new("TextLabel")
aide.AnchorPoint = Vector2.new(0.5, 1)
aide.Position = UDim2.new(0.5, 0, 1, -82)
aide.Size = UDim2.fromOffset(420, 24)
aide.BackgroundTransparency = 1
aide.TextColor3 = Color3.new(1, 1, 1)
aide.TextStrokeTransparency = 0.5
aide.Font = Enum.Font.Gotham
aide.TextSize = 15
aide.Text = "Clic droit + souris pour regarder · Molette pour monter/descendre"
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

local function majCamera(dt)
	-- Stick droit de manette : rotation continue
	if stick.Magnitude > 0.15 then
		yaw -= stick.X * VITESSE_STICK * dt
		pitch = math.clamp(pitch + stick.Y * VITESSE_STICK * dt, PITCH_MIN, PITCH_MAX)
	end

	local position = sommetLampe() + Vector3.new(0, hauteur, 0)
	camera.CFrame = CFrame.new(position)
		* CFrame.Angles(0, math.rad(yaw), 0)
		* CFrame.Angles(math.rad(pitch), 0, 0)
end

local function sortir()
	if not actif then return end
	actif = false
	RunService:UnbindFromRenderStep("TardisCamera")

	camera.CameraType = Enum.CameraType.Custom
	local personnage = joueur.Character
	local humanoid = personnage and personnage:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end

	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	clicDroit = false
	controlesPersonnage(true)
	gui.Enabled = false
	prompt.Enabled = exterieur:GetAttribute("Alimentation") ~= false
end

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

local function entrer()
	if joueur:GetAttribute("TardisPilote_" .. def.Nom) ~= true then return end -- réservé aux joueurs autorisés
	if actif then return end -- utilisable à tout moment : posé, décollage, vol, atterrissage
	if exterieur:GetAttribute("Alimentation") == false then return end -- plus de courant : plus de caméra
	actif = true

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
end

prompt.Triggered:Connect(entrer)

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
	elseif not traite and (input.KeyCode == Enum.KeyCode.X or input.KeyCode == Enum.KeyCode.ButtonB) then
		sortir()
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
		hauteur = math.clamp(hauteur + input.Position.Z * 2, 1, HAUTEUR_MAX)
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