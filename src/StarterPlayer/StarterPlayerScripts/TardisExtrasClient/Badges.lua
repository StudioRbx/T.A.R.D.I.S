-- StarterPlayerScripts > TardisExtrasClient > Badges (ModuleScript)
-- (V6.9.14) Badges des équipes : un petit badge au-dessus de la tête des membres de la C.A.T. et de la C.T.A.T. (le nom
-- de l'équipe, à la couleur de sa Team, et en option une image d'emblème : Config.Equipe.BadgeImage,
-- Config.EquipeTechnique.BadgeImage). Le réglage est dans TardisConfig seulement (Config.Equipe.Badge,
-- Config.EquipeTechnique.Badge) : ce n'est pas un choix du joueur, et il n'est pas dans la tablette.
-- Tout se fait chez chaque joueur d'après la Team (déjà connue de tous) : rien n'est envoyé au serveur, aucune
-- RemoteEvent. Le module est chargé une fois par TARDIS : seul le premier TARDIS pose les badges (un seul badge par
-- tête, même avec plusieurs TARDIS). Pas de badge sur son propre personnage (comme les noms de Roblox).

return function(contexte)
	local C, Config, Players, UI = contexte.C, contexte.Config, contexte.Players, contexte.UI
	local creer, def, joueur, texte = contexte.creer, contexte.def, contexte.joueur, contexte.texte
	if def.Nom ~= Config.Tardis[1].Nom then return end -- (V6.9.14) garde « premier TARDIS »
	local NOM_BADGE = "TardisBadge"
	local DISTANCE = 60 -- studs : au-delà, le badge n'est plus dessiné

	-- Pose, met à jour ou retire le badge d'un joueur selon sa Team
	local function majBadge(autre)
		if autre == joueur then return end
		local personnage = autre.Character
		local tete = personnage and personnage:FindFirstChild("Head")
		if not tete then return end
		local ancien = tete:FindFirstChild(NOM_BADGE)
		local equipe = autre.Team
		local badge = equipe and Config.badgeDe(equipe.Name)
		if ancien then ancien:Destroy() end
		if not badge then return end
		local couleur = UI.couleurJoueur(autre, C.cyan)
		local gui = creer("BillboardGui", { Name = NOM_BADGE, Adornee = tete, Size = UDim2.fromOffset(140, 26), StudsOffset = Vector3.new(0, 2.8, 0),
			MaxDistance = DISTANCE, AlwaysOnTop = false, LightInfluence = 0, ResetOnSpawn = false, Parent = tete })
		gui:SetAttribute("Equipe", equipe.Name)
		local cadre = creer("Frame", { Name = "Cadre", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = gui },
		{ creer("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
		if badge.image then
			creer("ImageLabel", { Name = "Embleme", BackgroundTransparency = 1, Image = badge.image, Size = UDim2.fromOffset(22, 22), LayoutOrder = 1, Parent = cadre })
		end
		texte({ Name = "Texte", Text = badge.texte, Font = UI.POLICE_GRAS, TextSize = 14, TextColor3 = couleur, TextStrokeTransparency = 0.4,
			AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 22), LayoutOrder = 2, Parent = cadre })
	end

	local suivis = {} -- [joueur] = connexions
	local function suivre(autre)
		if autre == joueur or suivis[autre] then return end
		local connexions = {}
		suivis[autre] = connexions
		table.insert(connexions, autre.CharacterAdded:Connect(function(personnage)
			task.spawn(function()
				if personnage:WaitForChild("Head", 10) then majBadge(autre) end
			end)
		end))
		table.insert(connexions, autre:GetPropertyChangedSignal("Team"):Connect(function() majBadge(autre) end))
		majBadge(autre)
	end
	Players.PlayerAdded:Connect(suivre)
	Players.PlayerRemoving:Connect(function(autre)
		for _, connexion in suivis[autre] or {} do connexion:Disconnect() end
		suivis[autre] = nil
	end)
	for _, autre in Players:GetPlayers() do suivre(autre) end

	return { majBadge = majBadge }
end
