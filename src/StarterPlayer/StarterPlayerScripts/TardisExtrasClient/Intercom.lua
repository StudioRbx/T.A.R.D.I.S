-- StarterPlayerScripts > TardisExtrasClient > Intercom (ModuleScript) — V6.7.3
-- Annonce intégrée de l'intercom du site (quand l'OS Fondation n'est pas branché, voir TardisPontFondation) :
-- bandeau d'alerte en haut de l'écran de tous les joueurs, texte qui s'écrit, alarme, et message dans le chat.
-- Un seul exemplaire du script s'en occupe (celui du premier TARDIS).

return function(contexte)
	local C, Config, ReplicatedStorage, UI, animer, creer = contexte.C, contexte.Config, contexte.ReplicatedStorage, contexte.UI, contexte.animer, contexte.creer
	local def, joueur, texte = contexte.def, contexte.joueur, contexte.texte
	if def.Nom ~= Config.Tardis[1].Nom then return {} end

	local gui = creer("ScreenGui", { Name = "TardisIntercom", ResetOnSpawn = false, DisplayOrder = 30, IgnoreGuiInset = true, Parent = joueur:WaitForChild("PlayerGui") })
	local bandeau = creer("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -140), Size = UDim2.fromOffset(620, 0),
		AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Color3.fromRGB(28, 10, 12), BackgroundTransparency = 0.05, Visible = false, Parent = gui },
	{ UI.coin(12), UI.contour(C.rouge, 2, 0.1), UI.marges(14), UI.pile(6) })
	local echelle = creer("UIScale", { Parent = bandeau })
	-- Bandes d'alerte qui défilent en haut du bandeau
	local bandes = creer("Frame", { Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = C.blanc, BorderSizePixel = 0, LayoutOrder = 0, Parent = bandeau }, { UI.coin(3) })
	local motif = {}
	for i = 0, 16 do
		table.insert(motif, ColorSequenceKeypoint.new(i / 16, i % 2 == 0 and C.rouge or Color3.fromRGB(255, 200, 60)))
	end
	local degrade = creer("UIGradient", { Color = ColorSequence.new(motif), Parent = bandes })
	local titre = texte({ Text = "", Font = UI.POLICE_TITRE, TextSize = 16, TextColor3 = C.rouge, TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 1, Parent = bandeau })
	local corps = texte({ Text = "", Font = UI.POLICE_CODE, TextSize = 14, TextColor3 = C.texte, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center,
		AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 2, Parent = bandeau })

	local function alarme()
		local assets = ReplicatedStorage:FindFirstChild("TardisAssets")
		local modele = assets and assets:FindFirstChild("Sons") and assets.Sons:FindFirstChild("Intercom")
		if modele and modele:IsA("Sound") then
			local son = modele:Clone()
			son.Volume = (modele.Volume or 0.8) * UI.volume()
			son.Parent = game:GetService("SoundService")
			son:Play()
			son.Ended:Connect(function() son:Destroy() end)
		else
			for k = 0, 2 do task.delay(k * 0.45, function() UI.son("Alerte") end) end
		end
	end

	local jeton = 0
	local function afficher(entete, message)
		jeton += 1
		local moi = jeton
		echelle.Scale = math.clamp(workspace.CurrentCamera.ViewportSize.X / 900, 0.6, 1)
		titre.Text = "◆  " .. tostring(entete) .. "  ◆"
		corps.Text = ""
		bandeau.Visible = true
		bandeau.Position = UDim2.new(0.5, 0, 0, -140)
		animer(bandeau, 0.45, { Position = UDim2.new(0.5, 0, 0, 18) }, Enum.EasingStyle.Back)
		alarme()
		-- Le message s'écrit lettre par lettre, comme sur un téléscripteur
		task.spawn(function()
			local longueur = utf8.len(message) or #message
			for i = 1, longueur do
				if moi ~= jeton then return end
				local fin = utf8.offset(message, i + 1)
				corps.Text = string.sub(message, 1, (fin or (#message + 1)) - 1)
				task.wait(0.022)
			end
		end)
		task.delay(10, function()
			if moi ~= jeton then return end
			animer(bandeau, 0.35, { Position = UDim2.new(0.5, 0, 0, -140) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Wait()
			if moi == jeton then bandeau.Visible = false end
		end)
		-- Dans le chat aussi
		pcall(function()
			local canal = game:GetService("TextChatService"):FindFirstChild("TextChannels")
			canal = canal and canal:FindFirstChild("RBXGeneral")
			if canal then canal:DisplaySystemMessage("<font color=\"#F05252\">[" .. tostring(entete) .. "]</font> " .. message) end
		end)
	end

	task.spawn(function()
		local annonce = ReplicatedStorage:WaitForChild("TardisAnnonceSite", 60)
		if annonce then annonce.OnClientEvent:Connect(afficher) end
	end)
	game:GetService("RunService").RenderStepped:Connect(function()
		if bandeau.Visible then degrade.Offset = Vector2.new((os.clock() * 0.25) % 0.125, 0) end
	end)

	return {}
end
