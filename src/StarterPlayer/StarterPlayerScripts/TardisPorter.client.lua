-- StarterPlayer > StarterPlayerScripts > TardisPorter (LocalScript)
-- Quand quelqu'un porte le TARDIS rétréci, chaque client le fait suivre localement :
--   - mode "Main"     : tenu comme une bouteille, bras le long du corps
--   - mode "Ceinture" : accroché contre la cuisse droite, comme une arme dans un holster
--   - mode "Epaule"   : flotte au-dessus de l'épaule droite, 2 studs en arrière, tourne sur lui-même et monte/descend légèrement
-- Le porteur a trois commandes : V (changer de mode), G (poser) et X (téléportation de poche vers la
-- destination choisie dans le menu T ou la tablette Y), aussi en boutons à l'écran.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("TardisConfig"))
local UI = require(ReplicatedStorage:WaitForChild("TardisUI")) -- partage la destination choisie dans les menus
local reglages = Config.Ramassage or {}
local AJUSTEMENT_MAIN = reglages.AjustementMain or CFrame.new()         -- réglage fin de la prise en main
local AJUSTEMENT_CEINTURE = reglages.AjustementCeinture or CFrame.new() -- réglage fin contre la cuisse
local TOURS_PAR_SECONDE = reglages.ToursParSeconde or 0.5               -- rotation sur lui-même en mode épaule
local DECALAGE_EPAULE = reglages.DecalageEpaule or CFrame.new(1.8, 1.5, 2)

local joueur = Players.LocalPlayer
local def, monRole = Config.attendreMonTardis(joueur) -- le TARDIS de ce joueur
local exterieur = Config.modeles(def)
local remote = ReplicatedStorage:WaitForChild(Config.canal(def, "TardisCommande"))

--------------------------------------------------------------------
-- Suivi du porteur (pour tous les joueurs)
--------------------------------------------------------------------
local actuel = nil   -- position lissée du TARDIS
local suivait = false
local taille = nil   -- dimensions du TARDIS porté (mesurées au moment où on commence à le suivre)

RunService.RenderStepped:Connect(function(dt)
	local idPorteur = exterieur:GetAttribute("Porteur")

	if not idPorteur then
		if suivait then
			-- Le porteur l'a posé : on se recale exactement sur la position décidée par le serveur
			suivait = false
			actuel = nil
			taille = nil
			local depot = exterieur:GetAttribute("DepotCF")
			if typeof(depot) == "CFrame" then
				exterieur:PivotTo(depot)
			end
		end
		return
	end

	local porteur = Players:GetPlayerByUserId(idPorteur)
	local personnage = porteur and porteur.Character
	local racine = personnage and personnage:FindFirstChild("HumanoidRootPart")
	if not racine then return end
	suivait = true
	taille = taille or exterieur:GetExtentsSize()

	local orientation = racine.CFrame.Rotation -- le TARDIS reste droit, tourné comme le porteur
	local cible

	local rotation = CFrame.new() -- rotation sur lui-même (mode épaule seulement)
	local mode = exterieur:GetAttribute("ModePort")

	if mode == "Epaule" then
		local temps = os.clock()
		local balancement = math.sin(temps * 2) * 0.15
		cible = racine.CFrame * DECALAGE_EPAULE * CFrame.new(0, balancement, 0)
		-- Suivi en douceur, comme un petit compagnon qui flotte
		actuel = actuel and actuel:Lerp(cible, 1 - math.exp(-8 * dt)) or cible
		-- Il tourne sur lui-même autour de son axe vertical (appliqué après le lissage pour rester régulier)
		rotation = CFrame.Angles(0, temps * TOURS_PAR_SECONDE * 2 * math.pi, 0)

	elseif mode == "Ceinture" then
		-- Accroché contre l'extérieur de la cuisse droite, comme une arme dans un holster : il suit la jambe
		local jambe = personnage:FindFirstChild("RightUpperLeg") or personnage:FindFirstChild("Right Leg")
		if jambe then
			-- Collé à la jambe (léger chevauchement pour qu'il n'y ait pas de jour) et remonté vers la hanche
			local cote = jambe.Size.X / 2 + taille.X / 2 - 0.1
			local hausse = 0.8
			cible = jambe.CFrame * CFrame.new(cote, -taille.Y / 2 + hausse, 0) * AJUSTEMENT_CEINTURE
		else
			cible = racine.CFrame * CFrame.new(1.2, -2, 0)
		end
		actuel = cible

	else
		-- Main : tenu comme une bouteille, bras le long du corps. La main empoigne le milieu du TARDIS,
		-- qui reste bien droit et suit le balancement naturel du bras quand on marche.
		local main = personnage:FindFirstChild("RightHand") or personnage:FindFirstChild("Right Arm")
		if main then
			local prise = main:FindFirstChild("RightGripAttachment") -- point où Roblox place les outils
			local point = prise and prise.WorldPosition or main.Position
			cible = CFrame.new(point) * orientation * CFrame.new(0, -taille.Y / 2, 0) * AJUSTEMENT_MAIN
		else
			cible = racine.CFrame * CFrame.new(1.5, -1, -1)
		end
		actuel = cible -- dans la main : collé, sans retard
	end

	exterieur:PivotTo(actuel * rotation)
end)

--------------------------------------------------------------------
-- Commandes du porteur
--------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "TardisPorter"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = joueur:WaitForChild("PlayerGui")

local cadre = Instance.new("Frame")
cadre.AnchorPoint = Vector2.new(0.5, 1)
cadre.Position = UDim2.new(0.5, 0, 1, -24)
cadre.Size = UDim2.fromOffset(520, 44)
cadre.BackgroundTransparency = 1
cadre.Parent = gui
UI.suivreTaille(cadre) -- (V6.9.15, proposition 72) les boutons du port suivent la taille de l'interface

local pile = Instance.new("UIListLayout")
pile.FillDirection = Enum.FillDirection.Horizontal
pile.HorizontalAlignment = Enum.HorizontalAlignment.Center
pile.Padding = UDim.new(0, 10)
pile.Parent = cadre

local function creerBouton(texte)
	local bouton = Instance.new("TextButton")
	bouton.Size = UDim2.fromOffset(165, 44)
	bouton.BackgroundColor3 = Color3.fromRGB(10, 25, 60)
	bouton.TextColor3 = Color3.fromRGB(235, 240, 255)
	bouton.Font = Enum.Font.GothamBold
	bouton.TextSize = 15
	bouton.Text = texte
	bouton.Parent = cadre
	local coin = Instance.new("UICorner")
	coin.CornerRadius = UDim.new(0, 8)
	coin.Parent = bouton
	return bouton
end

local boutonMode = creerBouton("")
local boutonPoser = creerBouton("Poser (G)")
local boutonDemat = creerBouton("DÉMAT (X)")
boutonDemat.BackgroundColor3 = Color3.fromRGB(26, 75, 140)

-- Bandeau au-dessus des boutons : destination de la téléportation de poche, ou message du serveur
local bandeau = Instance.new("TextLabel")
bandeau.AnchorPoint = Vector2.new(0.5, 1)
bandeau.Position = UDim2.new(0.5, 0, 0, -8)
bandeau.Size = UDim2.fromOffset(520, 26)
bandeau.BackgroundColor3 = Color3.fromRGB(10, 25, 60)
bandeau.BackgroundTransparency = 0.25
bandeau.TextColor3 = Color3.fromRGB(235, 240, 255)
bandeau.Font = Enum.Font.Gotham
bandeau.TextSize = 13
bandeau.Parent = cadre
local coinBandeau = Instance.new("UICorner")
coinBandeau.CornerRadius = UDim.new(0, 8)
coinBandeau.Parent = bandeau

local messageJusqua = 0 -- un message du serveur reste affiché quelques secondes
local function destinationChoisie()
	local choix = UI.destinationPoche
	local donnees = choix and choix.fournir()
	return donnees, choix and choix.nom
end
local function majBandeau()
	if os.clock() < messageJusqua then return end
	local donnees, nom = destinationChoisie()
	bandeau.Text = donnees and ("Destination : " .. tostring(nom)) or "Choisis une destination dans le menu (T) ou la tablette (Y)"
end

local function teleportationDePoche()
	if exterieur:GetAttribute("Porteur") ~= joueur.UserId then return end
	local donnees = destinationChoisie()
	if not donnees then
		messageJusqua = os.clock() + 3
		bandeau.Text = "Choisis d'abord une destination (T ou Y)."
		return
	end
	remote:FireServer("DematPorte", donnees)
end

local NOMS_MODES = { Main = "main", Ceinture = "ceinture", Epaule = "épaule" }

local function majCommandes()
	local jePorte = exterieur:GetAttribute("Porteur") == joueur.UserId
	gui.Enabled = jePorte
	local mode = NOMS_MODES[exterieur:GetAttribute("ModePort")] or "main"
	boutonMode.Text = "Mode : " .. mode .. " (V)"
end

boutonMode.Activated:Connect(function()
	remote:FireServer("ModePort")
end)
boutonPoser.Activated:Connect(function()
	remote:FireServer("Poser")
end)
boutonDemat.Activated:Connect(teleportationDePoche)

-- Réponses du serveur (réussite ou refus) affichées dans le bandeau
remote.OnClientEvent:Connect(function(message)
	if not gui.Enabled or typeof(message) ~= "string" or string.sub(message, 1, 2) == "__" then return end -- (« __… » : messages techniques)
	messageJusqua = os.clock() + 4
	bandeau.Text = message
end)

-- Pendant la dématérialisation, les commandes de port n'ont plus de sens
local function majDisponibilite()
	local libre = (exterieur:GetAttribute("Etat") or "Pose") == "Pose"
	for _, bouton in { boutonMode, boutonPoser, boutonDemat } do
		bouton.AutoButtonColor = libre
		bouton.TextTransparency = libre and 0 or 0.5
	end
end
exterieur:GetAttributeChangedSignal("Etat"):Connect(majDisponibilite)
majDisponibilite()

task.spawn(function()
	while true do
		task.wait(0.3)
		if gui.Enabled then majBandeau() end
	end
end)

UserInputService.InputBegan:Connect(function(input, traite)
	if traite or not gui.Enabled then return end
	if input.KeyCode == UI.touche("porterMode", Enum.KeyCode.V) then
		remote:FireServer("ModePort")
	elseif input.KeyCode == UI.touche("porterPoser", Enum.KeyCode.G) then
		remote:FireServer("Poser")
	elseif input.KeyCode == UI.touche("porterDemat", Enum.KeyCode.X) then
		teleportationDePoche()
	end
end)

exterieur:GetAttributeChangedSignal("Porteur"):Connect(majCommandes)
exterieur:GetAttributeChangedSignal("ModePort"):Connect(majCommandes)
majCommandes()