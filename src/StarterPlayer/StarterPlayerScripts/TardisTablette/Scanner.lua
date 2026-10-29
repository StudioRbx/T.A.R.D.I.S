-- StarterPlayerScripts > TardisTablette > Scanner (ModuleScript)
-- Scanner (radar) et mini-carte
-- Extrait du script principal en V6.6.3 : reçoit ce qu'il utilise, renvoie ce que la suite utilise.

return function(contexte)
	local C, E, Players, R, S, UI = contexte.C, contexte.E, contexte.Players, contexte.R, contexte.S, contexte.UI
	local W, changerMode, creer, exterieur, joueur, notifier = contexte.W, contexte.changerMode, contexte.creer, contexte.exterieur, contexte.joueur, contexte.notifier
	local texte = contexte.texte

	--------------------------------------------------------------------
	-- Scanner : points des joueurs
	--------------------------------------------------------------------
	local majScanner
	do
		local function pointPour(autre)
			local point = S.points[autre]
			if point then return point end
			local cadre = creer("TextButton", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(10, 10),
				BackgroundColor3 = UI.couleurJoueur(autre, autre == joueur and C.cyan or C.ambre), Text = "", ZIndex = 5, Parent = W.calquePoints },
			{ UI.coin(99), UI.contour(C.blanc, 1, 0.6) })
			texte({ Text = autre.DisplayName, Font = UI.POLICE_CODE, TextSize = 10, AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 1, 2), Size = UDim2.fromOffset(90, 12), TextXAlignment = Enum.TextXAlignment.Center,
				ZIndex = 5, Parent = cadre })
			cadre.Activated:Connect(function()
				S.choix = { type = "joueur", id = autre.UserId, nom = autre.DisplayName, pseudo = autre.Name }
				changerMode("joueurs")
				notifier("Destination : " .. autre.DisplayName .. ".", true)
			end)
			S.points[autre] = cadre
			return cadre
		end

		Players.PlayerRemoving:Connect(function(autre)
			if S.points[autre] then
				S.points[autre]:Destroy()
				S.points[autre] = nil
			end
		end)

		majScanner = function(e)
			local pivot = exterieur:GetPivot()
			local p = pivot.Position
			W.lectX.Text = string.format("%.1f", p.X)
			W.lectY.Text = string.format("%.1f", p.Y)
			W.lectZ.Text = string.format("%.1f", p.Z)
			local devant = pivot.LookVector
			W.lectCap.Text = string.format("%05.1f°", (math.deg(math.atan2(-devant.X, -devant.Z)) + 360) % 360)

			local horsService = e.etat == E.Vol or not e.alimente
			W.signalPerdu.Visible = horsService
			W.signalPerdu.Text = not e.alimente and "HORS TENSION\n— scanner éteint —" or "SIGNAL PERDU\n— dans le vortex —"

			local aPortee = 0
			for _, autre in Players:GetPlayers() do
				local racine = autre.Character and autre.Character:FindFirstChild("HumanoidRootPart")
				local cadre = pointPour(autre)
				local visible = false
				if racine and not horsService then
					local relatif = pivot:PointToObjectSpace(racine.Position)
					if Vector2.new(relatif.X, relatif.Z).Magnitude <= R.PORTEE then
						visible = true
						aPortee += 1
						cadre.Position = UDim2.fromScale(0.5 + relatif.X / (2 * R.PORTEE), 0.5 + relatif.Z / (2 * R.PORTEE))
						local choisi = S.choix and S.choix.type == "joueur" and S.choix.id == autre.UserId
						cadre.BackgroundColor3 = choisi and C.vert or (autre == joueur and C.cyan or C.ambre)
					end
				end
				cadre.Visible = visible
			end
			W.lectPortee.Text = horsService and "—" or (aPortee .. " joueur" .. (aPortee > 1 and "s" or ""))
		end
	end

	--------------------------------------------------------------------
	-- Mini-carte : vue du dessus, nord en haut, zoom automatique (TARDIS, joueurs, destinations cliquables)
	--------------------------------------------------------------------
	local majCarte
	do
		local cache, destinations = nil, {}

		local function lireDestinations()
			local brut = exterieur:GetAttribute("CarteDestinations") or ""
			if brut == cache then return destinations end
			cache, destinations = brut, {}
			for ligne in string.gmatch(brut, "[^\n]+") do
				local nom, x, z = string.match(ligne, "^(.-)\t([%-%d%.]+)\t([%-%d%.]+)$")
				if nom then table.insert(destinations, { nom = nom, x = tonumber(x), z = tonumber(z) }) end
			end
			for _, marqueur in S.marqueursCarte do marqueur:Destroy() end
			table.clear(S.marqueursCarte)
			for _, d in destinations do
				local marqueur = creer("TextButton", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(16, 16),
					BackgroundTransparency = 1, Text = "◆", Font = UI.POLICE_GRAS, TextSize = 13, TextColor3 = C.ambre, ZIndex = 4,
					Parent = W.calqueCarte })
				texte({ Text = d.nom, Font = UI.POLICE_CODE, TextSize = 9, TextColor3 = C.texte, TextXAlignment = Enum.TextXAlignment.Center,
					TextTruncate = Enum.TextTruncate.AtEnd, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 0),
					Size = UDim2.fromOffset(90, 10), ZIndex = 4, Parent = marqueur })
				marqueur.Activated:Connect(function()
					S.choix = { type = "lieu", nom = d.nom }
					changerMode("lieux")
					notifier("Destination : " .. d.nom .. ".", true)
				end)
				S.marqueursCarte[d.nom] = marqueur
			end
			return destinations
		end

		majCarte = function(e)
			local pivot = exterieur:GetPivot()
			local c = pivot.Position
			local liste = lireDestinations()

			-- Zoom automatique : toutes les destinations restent visibles
			local loin = 120
			for _, d in liste do
				loin = math.max(loin, math.abs(d.x - c.X), math.abs(d.z - c.Z))
			end
			S.porteeCarte += (math.clamp(loin * 1.15, 120, 5000) - S.porteeCarte) * 0.1
			local r = S.porteeCarte
			local function placer(x, z)
				return UDim2.fromScale(0.5 + (x - c.X) / (2 * r), 0.5 + (z - c.Z) / (2 * r))
			end

			for _, d in liste do
				local marqueur = S.marqueursCarte[d.nom]
				if marqueur then
					marqueur.Position = placer(d.x, d.z)
					local choisi = S.choix and S.choix.type == "lieu" and S.choix.nom == d.nom
					marqueur.TextColor3 = choisi and C.vert or C.ambre
				end
			end
			for _, autre in Players:GetPlayers() do
				local point = S.pointsCarte[autre]
				if not point then
					point = creer("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(6, 6),
						BackgroundColor3 = UI.couleurJoueur(autre, autre == joueur and C.cyan or C.blanc), ZIndex = 4, Parent = W.calqueCarte }, { UI.coin(99) })
					S.pointsCarte[autre] = point
				end
				local racine = autre.Character and autre.Character:FindFirstChild("HumanoidRootPart")
				point.Visible = racine ~= nil
				if racine then point.Position = placer(racine.Position.X, racine.Position.Z) end
			end

			-- Le TARDIS au centre, flèche dans la direction de sa porte
			local devant = pivot.LookVector
			W.tardisCarte.Rotation = math.deg(math.atan2(devant.X, -devant.Z))
			W.tardisCarte.TextColor3 = e.volLibre and C.cyan or C.ambre
			W.echelleCarteTexte.Text = string.format("± %d studs", r)
		end

		Players.PlayerRemoving:Connect(function(autre)
			if S.pointsCarte[autre] then
				S.pointsCarte[autre]:Destroy()
				S.pointsCarte[autre] = nil
			end
		end)
	end

	local function choisirModeScanner(mode)
		S.modeScanner = mode
		W.carte.Visible = mode == "carte"
		W.radar.Visible = mode == "radar"
		UI.colorer(W.btnCarte, mode == "carte" and C.bleu or C.fond)
		UI.colorer(W.btnRadar, mode == "radar" and C.bleu or C.fond)
		W.btnCarte.TextColor3 = mode == "carte" and C.texte or C.texte2
		W.btnRadar.TextColor3 = mode == "radar" and C.texte or C.texte2
	end
	W.btnRadar.Activated:Connect(function() choisirModeScanner("radar") end)
	W.btnCarte.Activated:Connect(function() choisirModeScanner("carte") end)
	choisirModeScanner("radar")

	return { majCarte = majCarte, majScanner = majScanner }
end
