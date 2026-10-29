-- StarterPlayerScripts > TardisExtrasClient > Interactions (ModuleScript)
-- Invitation, interphone et casiers
-- Extrait du script principal en V6.6.3 : reçoit ce qu'il utilise, renvoie ce que la suite utilise.

return function(contexte)
	local C, Config, UI, UserInputService, animer, camera = contexte.C, contexte.Config, contexte.UI, contexte.UserInputService, contexte.animer, contexte.camera
	local creer, exterieur, interieur, jeSuisDedans, joueur, maRacine = contexte.creer, contexte.exterieur, contexte.interieur, contexte.jeSuisDedans, contexte.joueur, contexte.maRacine
	local remote, texte = contexte.remote, contexte.texte

	--------------------------------------------------------------------
	-- 14) Invitation : un pilote t'invite, tu acceptes ou tu refuses
	--------------------------------------------------------------------
	local function afficherInvitation(pilote)
		local gui = creer("ScreenGui", { Name = "TardisInvitation", ResetOnSpawn = false, Parent = joueur:WaitForChild("PlayerGui") })
		local carte = creer("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -140), Size = UDim2.fromOffset(380, 0),
			AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.fond, BackgroundTransparency = 0.05, Parent = gui },
		{ UI.coin(14), UI.contour(C.cyan, 2, 0.2), UI.marges(14), UI.pile(8) })
		texte({ Text = "◆  INVITATION", Font = UI.POLICE_GRAS, TextSize = 15, TextColor3 = C.cyan, LayoutOrder = 1, Parent = carte })
		texte({ Text = tostring(pilote) .. " t'invite à bord du TARDIS. Tu y seras téléporté.", TextSize = 12, TextColor3 = C.texte, TextWrapped = true,
			AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = carte })
		local rangee = creer("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, LayoutOrder = 3, Parent = carte },
		{ creer("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
		local function bouton(txt, couleur, ordre, accepter)
			local b = creer("TextButton", { Size = UDim2.new(0.5, -4, 1, 0), BackgroundColor3 = couleur, Text = txt, Font = UI.POLICE_GRAS, TextSize = 13,
				TextColor3 = C.texte, LayoutOrder = ordre, Parent = rangee }, { UI.coin(8) })
			b:SetAttribute("CouleurBase", couleur)
			UI.rendreVivant(b)
			b.Activated:Connect(function()
				remote:FireServer("InvitationReponse", { accepter = accepter })
				gui:Destroy()
			end)
		end
		bouton("Accepter", Color3.fromRGB(30, 110, 70), 1, true)
		bouton("Refuser", Color3.fromRGB(110, 40, 50), 2, false)
		UI.son("Notification")
		animer(carte, 0.5, { Position = UDim2.new(0.5, 0, 0, 100) }, Enum.EasingStyle.Back)
		task.delay(60, function() if gui.Parent then gui:Destroy() end end)
	end

	--------------------------------------------------------------------
	-- 15) Interphone : parler entre l'extérieur et l'intérieur
	--------------------------------------------------------------------
	do
		local gui = creer("ScreenGui", { Name = "TardisInterphone", ResetOnSpawn = false, Enabled = false, Parent = joueur:WaitForChild("PlayerGui") })
		local panneau = creer("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, -20), Size = UDim2.fromOffset(300, 0),
			AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.fond, BackgroundTransparency = 0.1, Parent = gui },
		{ UI.coin(12), UI.contour(C.cyan, 1, 0.4), UI.marges(10), UI.pile(6) })
		texte({ Text = "●  INTERPHONE", Font = UI.POLICE_GRAS, TextSize = 12, TextColor3 = C.cyan, LayoutOrder = 1, Parent = panneau })
		local saisie = creer("TextBox", { Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = C.panneau, Text = "", PlaceholderText = "Message… (Entrée pour envoyer)",
			PlaceholderColor3 = C.texte2, Font = UI.POLICE, TextSize = 12, TextColor3 = C.texte, ClearTextOnFocus = false, LayoutOrder = 2, Parent = panneau },
		{ UI.coin(8), creer("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }) })
		saisie.FocusLost:Connect(function(entree)
			if entree and #saisie.Text > 0 then
				remote:FireServer("Interphone", { texte = string.sub(saisie.Text, 1, 120) })
				saisie.Text = ""
			end
		end)
		-- Le panneau n'apparaît qu'à l'intérieur, ou dehors à moins de 12 studs de la porte
		task.spawn(function()
			while true do
				task.wait(0.5)
				local racine = maRacine()
				local pres = racine and (jeSuisDedans() or (racine.Position - exterieur:GetPivot().Position).Magnitude < 12)
				gui.Enabled = pres == true and exterieur:GetAttribute("Detruit") ~= true
			end
		end)
		-- Les messages : bulle au-dessus de la porte extérieure (venus de l'intérieur) ou de la porte intérieure (venus de dehors)
		local bulle = nil
		exterieur:GetAttributeChangedSignal("Interphone"):Connect(function()
			local brut = exterieur:GetAttribute("Interphone")
			local origine, nom, message = string.match(brut or "", "^(%a+)\t(.-)\t(.-)\t")
			if not origine then return end
			if bulle then bulle:Destroy() end
			local support
			if origine == "dedans" then
				support = exterieur.PrimaryPart
			else
				support = interieur:FindFirstChild(Config.NomPortailInt or "Portail")
			end
			if not support then return end
			bulle = creer("BillboardGui", { Size = UDim2.fromOffset(260, 60), StudsOffsetWorldSpace = Vector3.new(0, origine == "dedans" and 11 or 4, 0),
				AlwaysOnTop = true, MaxDistance = 60, Parent = support })
			local cadre = creer("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.fond, BackgroundTransparency = 0.15, Parent = bulle },
			{ UI.coin(10), UI.contour(C.cyan, 1, 0.3), UI.marges(8) })
			texte({ Text = "INTERPHONE  ·  " .. nom, Font = UI.POLICE_GRAS, TextSize = 11, TextColor3 = C.cyan, Size = UDim2.new(1, 0, 0, 14), Parent = cadre })
			texte({ Text = message, TextSize = 12, TextColor3 = C.texte, TextWrapped = true, Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 1, -16),
				TextYAlignment = Enum.TextYAlignment.Top, Parent = cadre })
			-- Notification pour ceux qui sont du côté concerné
			local concerne = (origine == "dedans" and not jeSuisDedans() and (camera.CFrame.Position - exterieur:GetPivot().Position).Magnitude < 40)
				or (origine == "dehors" and jeSuisDedans())
			if concerne then UI.son("Notification") end
			local moi = bulle
			task.delay(10, function() if bulle == moi then bulle:Destroy() bulle = nil end end)
		end)
	end

	--------------------------------------------------------------------
	-- 16) Casiers : maintenir E 3 s sur un "Casier", la caméra recule face au joueur, un menu de tenues apparaît
	--------------------------------------------------------------------
	do
		local casiers = {}
		for _, objet in interieur:GetDescendants() do
			if objet.Name == "Casier" then
				local part = objet:IsA("BasePart") and objet or (objet:IsA("Model") and (objet.PrimaryPart or objet:FindFirstChildWhichIsA("BasePart", true)))
				if part then table.insert(casiers, part) end
			end
		end
		local gui = creer("ScreenGui", { Name = "TardisCasier", ResetOnSpawn = false, Enabled = false, Parent = joueur:WaitForChild("PlayerGui") })
		local panneau = creer("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -20, 0.5, 0), Size = UDim2.new(0, 320, 0.8, 0),
			BackgroundColor3 = C.fond, BackgroundTransparency = 0.08, Parent = gui }, { UI.coin(16), UI.contour(C.ambre, 1.5, 0.3), UI.marges(14) })
		texte({ Text = "◆  CASIER  ·  TENUES", Font = UI.POLICE_GRAS, TextSize = 15, TextColor3 = C.ambre, Size = UDim2.new(1, 0, 0, 20), Parent = panneau })
		texte({ Text = "Clique pour essayer. ○ = mettre en favori (gardé pour toujours).", TextSize = 11, TextColor3 = C.texte2, TextWrapped = true,
			Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 28), Parent = panneau })
		local liste = creer("ScrollingFrame", { Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 1, -140), BackgroundTransparency = 1, BorderSizePixel = 0,
			ScrollBarThickness = 4, ScrollBarImageColor3 = C.ambre, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = panneau },
		{ UI.pile(6) })
		local function boutonBas(txt, couleur, y)
			local b = creer("TextButton", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, y), Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = couleur,
				Text = txt, Font = UI.POLICE_GRAS, TextSize = 13, TextColor3 = C.texte, Parent = panneau }, { UI.coin(8) })
			b:SetAttribute("CouleurBase", couleur)
			UI.rendreVivant(b)
			return b
		end
		local garder = boutonBas("Garder cette tenue", Color3.fromRGB(30, 110, 70), -40)
		local fermer = boutonBas("Fermer", C.panneauClair, 0)

		local actif = false
		local apercu = nil -- index de la tenue essayée
		local origine = nil -- { shirt = template, pants = template } avant l'essayage
		local function appliquerLocal(index)
			local personnage = joueur.Character
			local tenue = (Config.Tenues or {})[index]
			if not personnage or not tenue then return end
			local shirt = personnage:FindFirstChildOfClass("Shirt") or creer("Shirt", { Name = "Shirt", Parent = personnage })
			local pants = personnage:FindFirstChildOfClass("Pants") or creer("Pants", { Name = "Pants", Parent = personnage })
			shirt.ShirtTemplate = "rbxassetid://" .. tenue.shirt
			pants.PantsTemplate = "rbxassetid://" .. tenue.pant
		end
		local function restaurer()
			local personnage = joueur.Character
			if not personnage or not origine then return end
			local shirt = personnage:FindFirstChildOfClass("Shirt")
			local pants = personnage:FindFirstChildOfClass("Pants")
			if shirt then shirt.ShirtTemplate = origine.shirt end
			if pants then pants.PantsTemplate = origine.pants end
		end
		local construire
		construire = function()
			for _, e in liste:GetChildren() do
				if not e:IsA("UIListLayout") then e:Destroy() end
			end
			local favoris = type(UI.prefs.tenuesFavorites) == "table" and UI.prefs.tenuesFavorites or {}
			local ordre = {}
			for i in Config.Tenues or {} do table.insert(ordre, i) end
			table.sort(ordre, function(a, b)
				local fa, fb = favoris[tostring(a)] == true, favoris[tostring(b)] == true
				if fa ~= fb then return fa end
				return a < b
			end)
			for rang, i in ordre do
				local tenue = Config.Tenues[i]
				local favori = favoris[tostring(i)] == true
				local b = creer("TextButton", { Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = apercu == i and C.bleu or C.panneau, Text = "", LayoutOrder = rang,
					Parent = liste }, { UI.coin(8) })
				texte({ Text = tenue.nom, Font = UI.POLICE_GRAS, TextSize = 13, Position = UDim2.fromOffset(12, 5), Size = UDim2.new(1, -60, 0, 18), Parent = b })
				texte({ Text = tenue.description .. "  ·  " .. tenue.categorie, TextSize = 10, TextColor3 = C.texte2, Position = UDim2.fromOffset(12, 24),
					Size = UDim2.new(1, -60, 0, 14), TextTruncate = Enum.TextTruncate.AtEnd, Parent = b })
				local etoile = creer("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(30, 30),
					BackgroundTransparency = 1, Text = favori and "●" or "○", Font = UI.POLICE_GRAS, TextSize = 18, TextColor3 = favori and C.ambre or C.texte2, Parent = b })
				etoile.Activated:Connect(function()
					UI.prefs.tenuesFavorites = type(UI.prefs.tenuesFavorites) == "table" and UI.prefs.tenuesFavorites or {}
					UI.prefs.tenuesFavorites[tostring(i)] = not favori or nil
					UI.setPref("tenuesFavorites", UI.prefs.tenuesFavorites)
					construire()
				end)
				b:SetAttribute("CouleurBase", b.BackgroundColor3)
				UI.rendreVivant(b)
				b.Activated:Connect(function()
					apercu = i
					appliquerLocal(i)
					construire()
				end)
			end
		end
		local function quitter(garderTenue)
			if not actif then return end
			actif = false
			gui.Enabled = false
			camera.CameraType = Enum.CameraType.Custom
			local humanoid = joueur.Character and joueur.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then camera.CameraSubject = humanoid end
			if garderTenue and apercu then
				remote:FireServer("Tenue", { index = apercu })
			else
				restaurer()
			end
			apercu, origine = nil, nil
		end
		local function ouvrir()
			if actif then return end
			local racine = maRacine()
			local personnage = joueur.Character
			if not racine or not personnage then return end
			actif = true
			local shirt = personnage:FindFirstChildOfClass("Shirt")
			local pants = personnage:FindFirstChildOfClass("Pants")
			origine = { shirt = shirt and shirt.ShirtTemplate or "", pants = pants and pants.PantsTemplate or "" }
			-- La caméra recule et se place face au joueur
			camera.CameraType = Enum.CameraType.Scriptable
			local devant = racine.CFrame.LookVector
			camera.CFrame = CFrame.lookAt(racine.Position + devant * 7 + Vector3.new(0, 1.5, 0), racine.Position + Vector3.new(0, 0.5, 0))
			construire()
			gui.Enabled = true
		end
		garder.Activated:Connect(function() quitter(true) end)
		fermer.Activated:Connect(function() quitter(false) end)
		for _, part in casiers do
			local prompt = creer("ProximityPrompt", { ActionText = "Ouvrir le casier", ObjectText = "Casier", HoldDuration = 3, MaxActivationDistance = 8,
				RequiresLineOfSight = false, Parent = part })
			prompt.Triggered:Connect(ouvrir)
		end
		UserInputService.InputBegan:Connect(function(input)
			if actif and input.KeyCode == Enum.KeyCode.Escape then quitter(false) end
		end)
	end

	return { afficherInvitation = afficherInvitation }
end
