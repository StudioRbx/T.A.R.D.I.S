-- StarterPlayerScripts > TardisExtrasClient > Preferences (ModuleScript)
-- Volume des sons et découverte
-- Extrait du script principal en V6.6.3 : reçoit ce qu'il utilise, renvoie ce que la suite utilise.

return function(contexte)
	local C, Config, UI, afficherInvitation, animer, creer = contexte.C, contexte.Config, contexte.UI, contexte.afficherInvitation, contexte.animer, contexte.creer
	local exterieur, interieur, joueur, remote, texte = contexte.exterieur, contexte.interieur, contexte.joueur, contexte.remote, contexte.texte

	--------------------------------------------------------------------
	-- 11) Volume des sons du TARDIS (réglages) : appliqué localement à tous les sons du TARDIS
	--------------------------------------------------------------------
	do
		local volumesOrigine = setmetatable({}, { __mode = "k" })
		local function regler(son)
			if not son:IsA("Sound") then return end
			volumesOrigine[son] = volumesOrigine[son] or son.Volume
			son.Volume = volumesOrigine[son] * UI.volume()
		end
		local function surveiller(racine)
			for _, objet in racine:GetDescendants() do regler(objet) end
			racine.DescendantAdded:Connect(regler)
		end
		surveiller(exterieur)
		surveiller(interieur)
		workspace.ChildAdded:Connect(function(objet)
			if string.sub(objet.Name, 1, 6) == "Tardis" then task.defer(surveiller, objet) end
		end)
		UI.prefsChangees.Event:Connect(function(cle)
			if cle ~= "volume" then return end
			for son, origine in volumesOrigine do
				if son.Parent then son.Volume = origine * UI.volume() end
			end
		end)
	end

	--------------------------------------------------------------------
	-- 12) Découverte : un achievement en haut à droite à la première entrée dans le TARDIS
	--------------------------------------------------------------------
	local function afficherDecouverte()
		local info = Config.Decouverte or {}
		local gui = creer("ScreenGui", { Name = "TardisDecouverte", ResetOnSpawn = false, Parent = joueur:WaitForChild("PlayerGui") })
		local carte = creer("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 360, 0, 90), Size = UDim2.fromOffset(340, 0),
			AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.fond, BackgroundTransparency = 0.05, Parent = gui },
		{ UI.coin(14), UI.contour(C.ambre, 2, 0.1), UI.marges(14), UI.pile(4) })
		-- (V6.9.15, proposition 72) taille de l'interface ; cachée assez loin à droite pour ne pas dépasser, même agrandie
		local echelleCarte = UI.suivreTaille(carte)
		local CACHEE = UDim2.new(1, math.max(360, math.ceil(340 * echelleCarte.Scale) + 20), 0, 90)
		carte.Position = CACHEE
		texte({ Text = "◆  " .. (info.Titre or "DÉCOUVERTE"), Font = UI.POLICE_GRAS, TextSize = 15, TextColor3 = C.ambre, LayoutOrder = 1, Parent = carte })
		texte({ Text = info.Texte or "", TextSize = 12, TextColor3 = C.texte, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = carte })
		UI.son("Notification")
		animer(carte, 0.6, { Position = UDim2.new(1, -20, 0, 90) }, Enum.EasingStyle.Back)
		task.delay(7, function()
			animer(carte, 0.4, { Position = CACHEE }).Completed:Wait() -- (V6.9.15 : CACHEE)
			gui:Destroy()
		end)
	end

	-- Sons de notification pour les messages du serveur (balise, intrusion...)
	remote.OnClientEvent:Connect(function(message, ok)
		if typeof(message) ~= "string" then return end
		if message == "__decouverte" then afficherDecouverte() return end
		if message == "__invitation" then afficherInvitation(ok) return end
		if string.find(message, "INTRUSION") or string.find(message, "BALISE") or string.find(message, "ZONE INTERDITE") then
			UI.son("Alerte")
		end
	end)

	return {}
end
