-- StarterPlayerScripts > TardisExtrasClient > Maintenance (ModuleScript) — V6.9.2, revu en V6.9.4
-- Bandeau « EN MAINTENANCE » en haut de l'écran, tant qu'un pilote ou un technicien a mis ce TARDIS en maintenance
-- (tablette), pour ceux que ça concerne : pilotes, techniciens, copilote de ce TARDIS, et joueurs à bord.
-- Le blocage lui-même (plus de voyage ni de vol) est fait par le serveur.

return function(contexte)
	local C, Config, UI, creer, texte, animer = contexte.C, contexte.Config, contexte.UI, contexte.creer, contexte.texte, contexte.animer
	local def, exterieur, joueur, jeSuisDedans = contexte.def, contexte.exterieur, contexte.joueur, contexte.jeSuisDedans

	-- Un bandeau par TARDIS : on les empile s'il y en a plusieurs
	local rang = 0
	for i, autre in Config.Tardis do
		if autre.Nom == def.Nom then rang = i - 1 end
	end
	local ORANGE = C.orange
	local gui = creer("ScreenGui", { Name = "TardisMaintenance_" .. def.Nom, ResetOnSpawn = false, Enabled = false, DisplayOrder = 30,
		Parent = joueur:WaitForChild("PlayerGui") })
	local bandeau = creer("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 52 + rang * 52), Size = UDim2.fromOffset(0, 44),
		AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = C.fond, BackgroundTransparency = 0.08, Parent = gui },
	{ UI.coin(12), UI.contour(ORANGE, 1.5, 0.25), creer("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 16) }) })
	-- Rayures de chantier sur la gauche
	local rayures = creer("Frame", { Position = UDim2.new(0, -14, 0, 0), Size = UDim2.new(0, 8, 1, 0), BackgroundColor3 = ORANGE, BorderSizePixel = 0,
		Parent = bandeau }, { UI.coin(4) })
	creer("UIGradient", { Rotation = 90, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 80)),
		ColorSequenceKeypoint.new(1, ORANGE) }), Parent = rayures })
	local titre = texte({ Text = "", Font = UI.POLICE_GRAS, TextSize = 14, TextColor3 = UI.eclaircir(ORANGE, 0.3), Position = UDim2.fromOffset(4, 5),
		Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X, Parent = bandeau })
	local detail = texte({ Text = "", TextSize = 11, TextColor3 = C.texte2, Position = UDim2.fromOffset(4, 23), Size = UDim2.fromOffset(0, 16),
		AutomaticSize = Enum.AutomaticSize.X, Parent = bandeau })

	local function concerne()
		return joueur:GetAttribute("TardisPilote_" .. def.Nom) == true or joueur:GetAttribute("TardisTechnicien_" .. def.Nom) == true
			or joueur:GetAttribute("TardisCopilote_" .. def.Nom) == true or jeSuisDedans()
	end
	local function maj()
		local raison = exterieur:GetAttribute("Maintenance")
		local visible = raison ~= nil and raison ~= false and concerne()
		if visible then
			titre.Text = string.format("%s EN MAINTENANCE  ·  %s", def.Nom, tostring(raison))
			local par = exterieur:GetAttribute("MaintenancePar")
			detail.Text = "Voyages et vol bloqués ; réparations, portes et boucliers restent possibles."
				.. (par and ("  ·  par " .. tostring(par)) or "")
		end
		if visible and not gui.Enabled then
			bandeau.Position = UDim2.new(0.5, 0, 0, 30 + rang * 52)
			gui.Enabled = true
			animer(bandeau, 0.35, { Position = UDim2.new(0.5, 0, 0, 52 + rang * 52) }, Enum.EasingStyle.Back)
			UI.son("Notification")
		elseif not visible then
			gui.Enabled = false
		end
	end
	for _, attribut in { "Maintenance", "MaintenancePar" } do exterieur:GetAttributeChangedSignal(attribut):Connect(maj) end
	for _, attribut in { "TardisPilote_" .. def.Nom, "TardisTechnicien_" .. def.Nom, "TardisCopilote_" .. def.Nom } do
		joueur:GetAttributeChangedSignal(attribut):Connect(maj)
	end
	-- Monter à bord ou sortir change aussi qui voit le bandeau
	task.spawn(function()
		while true do
			task.wait(1)
			if exterieur:GetAttribute("Maintenance") then
				maj()
				rayures.BackgroundTransparency = 0.15 + 0.35 * (0.5 + 0.5 * math.sin(os.clock() * 3))
			end
		end
	end)
	maj()
end
