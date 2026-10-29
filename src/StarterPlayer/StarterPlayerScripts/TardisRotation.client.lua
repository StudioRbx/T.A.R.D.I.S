-- StarterPlayer > StarterPlayerScripts > TardisRotation (LocalScript)
-- Menu "Rotation" : repositionnement fin du TARDIS posé.
--   La caméra tourne autour d'un TARDIS fantôme ; on le déplace et on le fait pivoter avec le panneau
--   (ou le clavier), puis "DÉMAT + REMAT AUTO" : le TARDIS se dématérialise, passe quelques secondes
--   dans le vortex et se rematérialise à la nouvelle position. La caméra revient aussitôt au joueur.
--   Si le fantôme est enfoncé dans un décor, la rematérialisation se fera en urgence (vérifié aussi par le serveur).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("TardisConfig"))
local UI = require(ReplicatedStorage:WaitForChild("TardisUI"))
local C = UI.C
local creer, texte = UI.creer, UI.texte

local joueur = Players.LocalPlayer
local camera = workspace.CurrentCamera
local def, monRole = Config.attendreMonTardis(joueur) -- le TARDIS de ce joueur (pilote ou technicien)
local exterieur, interieur = Config.modeles(def)
local remote = ReplicatedStorage:WaitForChild(Config.canal(def, "TardisCommande"))
local E = Config.Etats

-- Pas de déplacement (studs) et de rotation (degrés)
local PAS = {
	{ nom = "Normal", deplacement = 1, rotation = 15 },
	{ nom = "Fin", deplacement = 0.25, rotation = 5 },
	{ nom = "Large", deplacement = 5, rotation = 45 },
}

local R = {
	actif = false,
	cf = nil, depart = nil,      -- position voulue / position de départ (pivot = Racine)
	fantome = nil, surbrillance = nil,
	hauteur = 8,
	yaw = 0, pitch = -0.35, distance = 22, -- caméra en orbite
	pas = 1,
	collision = false,
	controles = nil,
	ancienType = nil,
}

--------------------------------------------------------------------
-- Interface : panneau sur le côté droit
--------------------------------------------------------------------
local gui = creer("ScreenGui", { Name = "TardisRotation", ResetOnSpawn = false, Enabled = false, IgnoreGuiInset = true,
	Parent = joueur:WaitForChild("PlayerGui") })
local panneau = creer("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -20, 0.5, 0),
	Size = UDim2.fromOffset(300, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.fond,
	BackgroundTransparency = 0.08, Parent = gui }, { UI.coin(16), UI.contour(C.cyan, 1.5, 0.3), UI.marges(14), UI.pile(8) })
local echelle = creer("UIScale", { Parent = panneau })

local ordre = 0
local function suivant()
	ordre += 1
	return ordre
end

texte({ Text = "◆  REPOSITIONNEMENT", Font = UI.POLICE_GRAS, TextSize = 15, TextColor3 = C.cyan, LayoutOrder = suivant(),
	Parent = panneau })
local etat = texte({ Text = "", Font = UI.POLICE_GRAS, TextSize = 12, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y,
	LayoutOrder = suivant(), Parent = panneau })
local infos = texte({ Text = "", Font = UI.POLICE_CODE, TextSize = 11, TextColor3 = C.texte2, TextWrapped = true,
	AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = suivant(), Parent = panneau })

local function titre(nom)
	texte({ Text = nom, Font = UI.POLICE_GRAS, TextSize = 10, TextColor3 = C.texte2, LayoutOrder = suivant(), Parent = panneau })
end

local function rangee(hauteur)
	return creer("Frame", { Size = UDim2.new(1, 0, 0, hauteur or 34), BackgroundTransparency = 1, LayoutOrder = suivant(),
		Parent = panneau }, { creer("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }) })
end

local function bouton(parent, txt, largeur, couleur, ordreBouton)
	local b = creer("TextButton", { Size = UDim2.new(largeur, -4, 1, 0), BackgroundColor3 = couleur or C.panneauClair,
		Text = txt, Font = UI.POLICE_GRAS, TextSize = 13, TextColor3 = C.texte, LayoutOrder = ordreBouton or 1, Parent = parent },
	{ UI.coin(8) })
	b:SetAttribute("CouleurBase", couleur or C.panneauClair)
	UI.rendreVivant(b)
	return b
end

-- Bouton qu'on peut maintenir enfoncé : l'action se répète
local function maintenu(b, action)
	local jeton = 0
	b.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
		jeton += 1
		local moi = jeton
		action()
		task.delay(0.35, function()
			while jeton == moi and R.actif do
				action()
				task.wait(0.08)
			end
		end)
	end)
	b.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			jeton += 1
		end
	end)
	b.MouseLeave:Connect(function() jeton += 1 end)
end

titre("DÉPLACEMENT (par rapport à la caméra)")
local r1 = rangee()
local bAvant = bouton(r1, "▲  Avant", 1 / 2, nil, 1)
local bMonter = bouton(r1, "Monter", 1 / 2, nil, 2)
local r2 = rangee()
local bGauche = bouton(r2, "◄", 1 / 3, nil, 1)
local bArriere = bouton(r2, "▼", 1 / 3, nil, 2)
local bDroite = bouton(r2, "►", 1 / 3, nil, 3)
local r3 = rangee()
bouton(r3, "", 1 / 2, C.fond, 1).Visible = false
local bDescendre = bouton(r3, "Descendre", 1 / 2, nil, 2)

titre("ROTATION")
local r4 = rangee()
local bTournerG = bouton(r4, "◄  Tourner", 1 / 2, nil, 1)
local bTournerD = bouton(r4, "Tourner  ►", 1 / 2, nil, 2)
local r5 = rangee()
local bPencherAv = bouton(r5, "▲  Pencher", 1 / 2, nil, 1)
local bPencherAr = bouton(r5, "Pencher  ▼", 1 / 2, nil, 2)
local r6 = rangee()
local bInclinerG = bouton(r6, "◄  Incliner", 1 / 2, nil, 1)
local bInclinerD = bouton(r6, "Incliner  ►", 1 / 2, nil, 2)

local r6b = rangee()
local bColler = bouton(r6b, "Coller à la surface visée (mur, plafond, sol)", 1, Color3.fromRGB(60, 90, 140), 1)

local r7 = rangee()
local bPas = bouton(r7, "", 1, C.bleu, 1)

local r8 = rangee()
local bReinit = bouton(r8, "Réinitialiser", 1 / 2, nil, 1)
local bAnnuler = bouton(r8, "Annuler", 1 / 2, Color3.fromRGB(110, 40, 50), 2)

local r9 = rangee(48)
local bValider = bouton(r9, "DÉMAT + REMAT AUTO", 1, Color3.fromRGB(30, 110, 70), 1)
bValider.TextSize = 15
local dureeVortex = Config.DureeVortexRepositionnement or 10
texte({ Text = string.format("Le TARDIS passe %d s dans le vortex puis réapparaît ici.", dureeVortex), TextSize = 11,
	TextColor3 = C.texte2, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = suivant(), Parent = panneau })
texte({ Text = "Caméra : clic droit + souris pour tourner, molette pour zoomer (sur mobile : glisser le doigt).\n"
	.. "Clavier : touches de marche pour déplacer, flèches gauche / droite pour tourner, haut / bas pour monter / descendre.",
	TextSize = 10, TextColor3 = C.texte2, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = suivant(),
	Parent = panneau })

--------------------------------------------------------------------
-- Logique
--------------------------------------------------------------------
local function testerCollision(cible)
	local taille = R.taille
	local hauteurRacine = exterieur.PrimaryPart.Size.Y / 2
	local marge = 0.4
	local centre = cible * CFrame.new(0, taille.Y / 2 - hauteurRacine + marge / 2, 0)
	local exclus = { exterieur, interieur, R.fantome }
	for _, autre in Players:GetPlayers() do
		if autre.Character then table.insert(exclus, autre.Character) end
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclus
	params.RespectCanCollide = true
	local reduite = Vector3.new(math.max(taille.X - marge, 0.1), math.max(taille.Y - marge, 0.1), math.max(taille.Z - marge, 0.1))
	return #workspace:GetPartBoundsInBox(centre, reduite, params) > 0
end

local function majApercu()
	if not R.actif then return end
	R.fantome:PivotTo(R.cf)
	R.collision = testerCollision(R.cf)
	local couleur = R.collision and C.rouge or C.vert
	R.surbrillance.FillColor = couleur
	R.surbrillance.OutlineColor = couleur
	etat.Text = R.collision and "▲ Trop enfoncé : la rematérialisation se fera en URGENCE." or "● Emplacement libre."
	etat.TextColor3 = couleur

	local ecart = R.cf.Position - R.depart.Position
	local _, cap = R.cf:ToEulerAnglesYXZ()
	local x, _, z = (R.depart.Rotation:Inverse() * R.cf.Rotation):ToEulerAnglesXYZ()
	infos.Text = string.format("Décalage : %.2f studs · hauteur %+.2f\nCap %d° · penché %+d° · incliné %+d°",
		Vector3.new(ecart.X, 0, ecart.Z).Magnitude, ecart.Y, math.floor((math.deg(-cap) + 360) % 360 + 0.5),
		math.floor(math.deg(x) + 0.5), math.floor(math.deg(z) + 0.5))

	local p = PAS[R.pas]
	bPas.Text = string.format("Pas : %s  (%s stud · %d°)", p.nom, tostring(p.deplacement), p.rotation)
	local possible = exterieur:GetAttribute("Alimentation") ~= false and not exterieur:GetAttribute("DemarrageBloque")
	UI.setDisponible(bValider, possible, Color3.fromRGB(30, 110, 70))
end

-- Déplacement relatif à la caméra (à plat), en studs
local function deplacer(avant, droite, haut)
	local d = PAS[R.pas].deplacement
	local regard = camera.CFrame.LookVector * Vector3.new(1, 0, 1)
	local cote = camera.CFrame.RightVector * Vector3.new(1, 0, 1)
	regard = regard.Magnitude > 0.01 and regard.Unit or Vector3.new(0, 0, -1)
	cote = cote.Magnitude > 0.01 and cote.Unit or Vector3.new(1, 0, 0)
	R.cf = R.cf + (regard * avant + cote * droite + Vector3.new(0, haut, 0)) * d
	majApercu()
end

-- Rotations : "tourner" autour de la verticale, "pencher" et "incliner" autour des axes du TARDIS
local function tourner(sens)
	local a = math.rad(PAS[R.pas].rotation) * sens
	R.cf = CFrame.new(R.cf.Position) * CFrame.Angles(0, a, 0) * R.cf.Rotation
	majApercu()
end
local function pencher(sens)
	R.cf = R.cf * CFrame.Angles(math.rad(PAS[R.pas].rotation) * sens, 0, 0)
	majApercu()
end
local function incliner(sens)
	R.cf = R.cf * CFrame.Angles(0, 0, math.rad(PAS[R.pas].rotation) * sens)
	majApercu()
end

local function creerFantome()
	local ancien = exterieur.Archivable
	exterieur.Archivable = true
	local fantome = exterieur:Clone()
	exterieur.Archivable = ancien
	if not fantome then return nil end
	local boucliers = fantome:FindFirstChild("Boucliers")
	if boucliers then boucliers:Destroy() end
	for _, objet in fantome:GetDescendants() do
		if objet:IsA("LuaSourceContainer") or objet:IsA("Sound") or objet:IsA("ProximityPrompt") or objet:IsA("ClickDetector")
			or objet:IsA("Light") or objet:IsA("LayerCollector") or objet:IsA("ParticleEmitter") or objet:IsA("Highlight") then
			objet:Destroy()
		elseif objet:IsA("BasePart") then
			objet.Anchored, objet.CanCollide, objet.CanQuery, objet.CanTouch = true, false, false, false
			objet.Transparency = (objet == fantome.PrimaryPart or objet.Name == Config.NomPortailExt) and 1 or 0.45
		elseif objet:IsA("Decal") then
			objet.Transparency = 0.45
		end
	end
	fantome.Name = "TardisFantomeRotation"
	return fantome
end

local function quitter()
	if not R.actif then return end
	R.actif = false
	gui.Enabled = false
	if R.fantome then R.fantome:Destroy() end
	R.fantome = nil
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	if R.controles then R.controles:Enable() end
	-- La caméra revient au joueur
	camera.CameraType = Enum.CameraType.Custom
	local humanoid = joueur.Character and joueur.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then camera.CameraSubject = humanoid end
	joueur:SetAttribute("TardisRotation", false)
end

local function demarrer()
	if R.actif then return end
	-- Seulement un TARDIS posé, ni porté, ni en vol libre
	local etatTardis = exterieur:GetAttribute("Etat") or E.Pose
	if joueur:GetAttribute("TardisPilote_" .. def.Nom) ~= true or etatTardis ~= E.Pose or exterieur:GetAttribute("Porteur")
		or exterieur:GetAttribute("VolLibre") then
		joueur:SetAttribute("TardisRotation", false)
		return
	end
	local fantome = creerFantome()
	if not fantome then
		joueur:SetAttribute("TardisRotation", false)
		return
	end
	R.actif = true
	R.depart = exterieur:GetPivot()
	R.cf = R.depart
	R.taille = exterieur:GetExtentsSize()
	R.hauteur = R.taille.Y
	R.fantome = fantome
	R.surbrillance = creer("Highlight", { FillTransparency = 0.75, OutlineTransparency = 0,
		DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Parent = fantome })
	fantome.Parent = workspace

	-- Caméra en orbite, derrière le TARDIS, un peu au-dessus
	local _, cap = R.depart:ToEulerAnglesYXZ()
	R.yaw, R.pitch = cap + math.pi, -0.35
	R.distance = math.clamp(math.max(R.taille.X, R.taille.Y, R.taille.Z) * 2.6, 12, 60)
	camera.CameraType = Enum.CameraType.Scriptable

	-- Le personnage ne bouge pas pendant le réglage (les touches de marche servent à déplacer le fantôme)
	local ok, module = pcall(function()
		return require(joueur:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")):GetControls()
	end)
	R.controles = ok and module or nil
	if R.controles then R.controles:Disable() end

	gui.Enabled = true
	majApercu()
end

-- Boutons
maintenu(bAvant, function() deplacer(1, 0, 0) end)
maintenu(bArriere, function() deplacer(-1, 0, 0) end)
maintenu(bGauche, function() deplacer(0, -1, 0) end)
maintenu(bDroite, function() deplacer(0, 1, 0) end)
maintenu(bMonter, function() deplacer(0, 0, 1) end)
maintenu(bDescendre, function() deplacer(0, 0, -1) end)
maintenu(bTournerG, function() tourner(1) end)
maintenu(bTournerD, function() tourner(-1) end)
maintenu(bPencherAv, function() pencher(-1) end)
maintenu(bPencherAr, function() pencher(1) end)
maintenu(bInclinerG, function() incliner(1) end)
maintenu(bInclinerD, function() incliner(-1) end)
-- Coller à la surface : le TARDIS se pose contre la surface visée par la caméra, même un mur ou un plafond
bColler.Activated:Connect(function()
	if not R.actif then return end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclus = { exterieur, interieur, R.fantome }
	for _, autre in Players:GetPlayers() do
		if autre.Character then table.insert(exclus, autre.Character) end
	end
	params.FilterDescendantsInstances = exclus
	params.RespectCanCollide = true
	local resultat = workspace:Raycast(camera.CFrame.Position, camera.CFrame.LookVector * 120, params)
	if not resultat then
		etat.Text = "Aucune surface dans la direction de la caméra."
		etat.TextColor3 = C.ambre
		return
	end
	local haut = resultat.Normal
	local devant = R.cf.LookVector - haut * R.cf.LookVector:Dot(haut)
	if devant.Magnitude < 0.05 then devant = camera.CFrame.RightVector:Cross(haut) end
	devant = devant.Unit
	local hauteurRacine = exterieur.PrimaryPart.Size.Y / 2
	R.cf = CFrame.fromMatrix(resultat.Position + haut * (hauteurRacine + 0.05), devant:Cross(haut), haut)
	majApercu()
end)

bPas.Activated:Connect(function()
	R.pas = R.pas % #PAS + 1
	majApercu()
end)
bReinit.Activated:Connect(function()
	R.cf = R.depart
	majApercu()
end)
bAnnuler.Activated:Connect(quitter)
bValider.Activated:Connect(function()
	if not R.actif or bValider:GetAttribute("Disponible") == false then return end
	local cible = R.cf
	quitter() -- la caméra revient tout de suite au joueur
	remote:FireServer("Repositionner", { position = cible })
end)

-- Clavier
local TOUCHES = {
	[Enum.KeyCode.W] = function() deplacer(1, 0, 0) end,
	[Enum.KeyCode.S] = function() deplacer(-1, 0, 0) end,
	[Enum.KeyCode.A] = function() deplacer(0, -1, 0) end,
	[Enum.KeyCode.D] = function() deplacer(0, 1, 0) end,
	[Enum.KeyCode.Up] = function() deplacer(0, 0, 1) end,
	[Enum.KeyCode.Down] = function() deplacer(0, 0, -1) end,
	[Enum.KeyCode.Left] = function() tourner(1) end,
	[Enum.KeyCode.Right] = function() tourner(-1) end,
}
UserInputService.InputBegan:Connect(function(input, traite)
	if not R.actif or traite then return end
	local action = TOUCHES[input.KeyCode]
	if action then
		action()
		-- Répétition tant que la touche est maintenue
		task.delay(0.35, function()
			while R.actif and UserInputService:IsKeyDown(input.KeyCode) do
				action()
				task.wait(0.08)
			end
		end)
	elseif input.KeyCode == Enum.KeyCode.Escape then
		quitter()
	end
end)

-- Caméra : clic droit + souris (ou doigt) pour tourner autour, molette pour zoomer
UserInputService.InputChanged:Connect(function(input, traite)
	if not R.actif then return end
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
			R.yaw -= input.Delta.X * 0.008
			R.pitch = math.clamp(R.pitch - input.Delta.Y * 0.008, -1.4, 0.6)
		else
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
	elseif input.UserInputType == Enum.UserInputType.MouseWheel and not traite then
		R.distance = math.clamp(R.distance - input.Position.Z * 2, 6, 90)
	elseif input.UserInputType == Enum.UserInputType.Touch and not traite then
		R.yaw -= input.Delta.X * 0.01
		R.pitch = math.clamp(R.pitch - input.Delta.Y * 0.01, -1.4, 0.6)
	end
end)

RunService.RenderStepped:Connect(function()
	if not R.actif then return end
	-- Si le TARDIS n'est plus posé (quelqu'un d'autre l'a fait décoller...), on sort du mode
	if (exterieur:GetAttribute("Etat") or E.Pose) ~= E.Pose or exterieur:GetAttribute("Porteur") or exterieur:GetAttribute("VolLibre") then
		quitter()
		return
	end
	local centre = (R.cf * CFrame.new(0, R.hauteur / 2, 0)).Position
	local orbite = CFrame.new(centre) * CFrame.Angles(0, R.yaw, 0) * CFrame.Angles(R.pitch, 0, 0) * CFrame.new(0, 0, R.distance)
	camera.CFrame = CFrame.lookAt(orbite.Position, centre)
	camera.Focus = CFrame.new(centre)
end)

-- Ouverture demandée par le menu (attribut local sur le joueur)
joueur:GetAttributeChangedSignal("TardisRotation"):Connect(function()
	if joueur:GetAttribute("TardisRotation") then demarrer() end
end)
joueur.CharacterRemoving:Connect(quitter)

local function majEchelle()
	echelle.Scale = math.clamp(camera.ViewportSize.Y / 900, 0.6, 1) * UI.tailleInterface()
end
UI.prefsChangees.Event:Connect(function(cle) if cle == "taille" then majEchelle() end end)
camera:GetPropertyChangedSignal("ViewportSize"):Connect(majEchelle)
majEchelle()