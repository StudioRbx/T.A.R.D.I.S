-- StarterPlayerScripts > TardisExtrasClient > TabletteLecture (ModuleScript)
-- Tablette en lecture seule (visiteurs et techniciens)
-- Extrait du script principal en V6.6.3 : reçoit ce qu'il utilise, renvoie ce que la suite utilise.

return function(contexte)
	local C, Players, UI, creer, dansInterieur, exterieur = contexte.C, contexte.Players, contexte.UI, contexte.creer, contexte.dansInterieur, contexte.exterieur
	local joueur, texte = contexte.joueur, contexte.texte

	--------------------------------------------------------------------
	-- 22) Tablette en lecture seule : outil "TabletteTardis" (visiteurs et techniciens à bord)
	--------------------------------------------------------------------
	do
		local gui = creer("ScreenGui", { Name = "TardisTabletteLecture", ResetOnSpawn = false, Enabled = false, Parent = joueur:WaitForChild("PlayerGui") })
		local panneau = creer("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -20, 0.5, 0), Size = UDim2.fromOffset(360, 520),
			BackgroundColor3 = C.fond, BackgroundTransparency = 0.06, Parent = gui }, { UI.coin(16), UI.contour(C.cyan, 1.5, 0.3), UI.marges(14) })
		UI.suivreTaille(panneau) -- (V6.9.15, proposition 72) taille de l'interface
		texte({ Text = "◆  TABLETTE TARDIS  ·  LECTURE SEULE", Font = UI.POLICE_GRAS, TextSize = 13, TextColor3 = C.cyan, Size = UDim2.new(1, 0, 0, 18), Parent = panneau })
		local infos = texte({ Text = "", Font = UI.POLICE_CODE, TextSize = 12, TextColor3 = C.texte, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 150), Parent = panneau })
		local carte = creer("Frame", { Position = UDim2.fromOffset(0, 184), Size = UDim2.fromOffset(330, 230), BackgroundColor3 = Color3.fromRGB(4, 14, 26),
			ClipsDescendants = true, Parent = panneau }, { UI.coin(12), UI.contour(C.cyan, 1, 0.4) })
		local calque = creer("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = carte })
		texte({ Text = "▲", Font = UI.POLICE_GRAS, TextSize = 16, TextColor3 = C.ambre, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(18, 18), ZIndex = 3, Parent = carte })
		local lieux = texte({ Text = "", Font = UI.POLICE_CODE, TextSize = 11, TextColor3 = C.texte2, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(0, 422), Size = UDim2.new(1, 0, 0, 80), Parent = panneau })
		local marqueurs, points = {}, {}
		local equipe = false
		local dernierePosition, vitesse = nil, 0
		task.spawn(function()
			while true do
				task.wait(0.5)
				if not equipe then continue end
				local pivot = exterieur:GetPivot()
				local p = pivot.Position
				if dernierePosition then vitesse = vitesse + ((p - dernierePosition).Magnitude / 0.5 - vitesse) * 0.5 end
				dernierePosition = p
				local occupants = 0
				for _, autre in Players:GetPlayers() do
					local racine = autre.Character and autre.Character:FindFirstChild("HumanoidRootPart")
					if racine and dansInterieur(racine.Position) then occupants += 1 end
				end
				local destinations, plusProche, distanceMin = {}, nil, math.huge
				for ligne in string.gmatch(exterieur:GetAttribute("CarteDestinations") or "", "[^\n]+") do
					local nom, x, z = string.match(ligne, "^(.-)\t([%-%d%.]+)\t([%-%d%.]+)$")
					if nom then
						local d = (Vector3.new(tonumber(x), p.Y, tonumber(z)) - p).Magnitude
						table.insert(destinations, { nom = nom, x = tonumber(x), z = tonumber(z), d = d })
						if d < distanceMin then plusProche, distanceMin = nom, d end
					end
				end
				infos.Text = string.format("État : %s\nPosition : %s\nCoordonnées : %d, %d, %d\nVitesse : %d studs/s\nIntégrité : %s %%\nÀ bord : %d\nLieu le plus proche : %s (%d studs)",
					tostring(exterieur:GetAttribute("Etat") or "?"), tostring(exterieur:GetAttribute("Position") or "?"), p.X, p.Y, p.Z, vitesse,
					tostring(exterieur:GetAttribute("PointsDeVie") or "—"), occupants, plusProche or "—", distanceMin < math.huge and distanceMin or 0)
				-- Carte
				local portee = 150
				for _, d in destinations do portee = math.max(portee, math.abs(d.x - p.X) * 1.15, math.abs(d.z - p.Z) * 1.15) end
				portee = math.min(portee, 5000)
				local function placer(x, z) return UDim2.fromScale(0.5 + (x - p.X) / (2 * portee), 0.5 + (z - p.Z) / (2 * portee)) end
				for _, m in marqueurs do m.Visible = false end
				table.sort(destinations, function(a, b) return a.d < b.d end)
				local lignesLieux = {}
				for i, d in destinations do
					local m = marqueurs[i]
					if not m then
						m = texte({ Text = "◆", Font = UI.POLICE_GRAS, TextSize = 12, TextColor3 = C.ambre, TextXAlignment = Enum.TextXAlignment.Center,
							AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(14, 14), ZIndex = 2, Parent = calque })
						texte({ Name = "Nom", Text = "", TextSize = 9, TextColor3 = C.texte, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0),
							Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(80, 10), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 2, Parent = m })
						marqueurs[i] = m
					end
					m.Visible = true
					m.Position = placer(d.x, d.z)
					m.Nom.Text = d.nom
					if i <= 5 then table.insert(lignesLieux, string.format("%s  ·  %d studs", d.nom, d.d)) end
				end
				lieux.Text = table.concat(lignesLieux, "\n")
				for _, autre in Players:GetPlayers() do
					local point = points[autre]
					if not point then
						point = creer("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(6, 6), BackgroundColor3 = UI.couleurJoueur(autre, autre == joueur and C.cyan or C.blanc),
							ZIndex = 2, Parent = calque }, { UI.coin(99) })
						points[autre] = point
					end
					local racine = autre.Character and autre.Character:FindFirstChild("HumanoidRootPart")
					point.Visible = racine ~= nil
					if racine then point.Position = placer(racine.Position.X, racine.Position.Z) end
				end
			end
		end)
		local function surveillerOutil(outil)
			if outil.Name ~= "TabletteTardis" or not outil:IsA("Tool") then return end
			outil.Equipped:Connect(function() equipe = true gui.Enabled = true end)
			outil.Unequipped:Connect(function() equipe = false gui.Enabled = false end)
			outil.AncestryChanged:Connect(function() if not outil:IsDescendantOf(game) then equipe = false gui.Enabled = false end end)
		end
		local function surveillerConteneur(conteneur)
			if not conteneur then return end
			for _, o in conteneur:GetChildren() do surveillerOutil(o) end
			conteneur.ChildAdded:Connect(surveillerOutil)
		end
		surveillerConteneur(joueur:FindFirstChildOfClass("Backpack"))
		joueur.ChildAdded:Connect(function(o) if o:IsA("Backpack") then surveillerConteneur(o) end end)
		Players.PlayerRemoving:Connect(function(autre) if points[autre] then points[autre]:Destroy() points[autre] = nil end end)
	end

	return {}
end
