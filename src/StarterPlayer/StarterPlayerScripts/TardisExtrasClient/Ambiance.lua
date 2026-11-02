-- StarterPlayerScripts > TardisExtrasClient > Ambiance (ModuleScript)
-- Hologramme, écrans vivants, gravité folle, moteur et vapeur, écrans de diagnostic
-- Extrait du script principal en V6.6.3 : reçoit ce qu'il utilise, renvoie ce que la suite utilise.

return function(contexte)
	local C, Config, E, Lighting, Players, ReplicatedStorage = contexte.C, contexte.Config, contexte.E, contexte.Lighting, contexte.Players, contexte.ReplicatedStorage
	local RunService, UI, boiteInt, creer, dansInterieur, exterieur = contexte.RunService, contexte.UI, contexte.boiteInt, contexte.creer, contexte.dansInterieur, contexte.exterieur
	local interieur, jeSuisDedans, joueur, maRacine, partTemporaire, texte = contexte.interieur, contexte.jeSuisDedans, contexte.joueur, contexte.maRacine, contexte.partTemporaire, contexte.texte

	--------------------------------------------------------------------
	-- 1) Hologramme de la map au-dessus de la console
	--------------------------------------------------------------------
	do
		local console = interieur:FindFirstChild("Console")
		local centreConsole, tailleConsole
		if console and console:IsA("Model") then
			centreConsole, tailleConsole = console:GetBoundingBox()
		elseif console and console:IsA("BasePart") then
			centreConsole, tailleConsole = console.CFrame, console.Size
		else
			centreConsole, tailleConsole = boiteInt, Vector3.new(8, 4, 8)
		end
		local support = partTemporaire({ Name = "TardisHologramme", Transparency = 1, Size = Vector3.new(7, 0.2, 7),
			CFrame = CFrame.new(centreConsole.Position + Vector3.new(0, tailleConsole.Y / 2 + 4.5, 0)) })
		local faisceau = partTemporaire({ Name = "TardisHologrammeFaisceau", Material = Enum.Material.Neon, Color = C.cyan,
			Transparency = 0.85, Size = Vector3.new(0.3, tailleConsole.Y / 2 + 4.5, 0.3),
			CFrame = CFrame.new(centreConsole.Position + Vector3.new(0, tailleConsole.Y / 4 + 2.25, 0)) })
		local ecran = creer("SurfaceGui", { Face = Enum.NormalId.Top, LightInfluence = 0, PixelsPerStud = 40, AlwaysOnTop = false, Parent = support })
		local cadre = creer("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(0, 40, 70), BackgroundTransparency = 0.55,
			Parent = ecran }, { UI.coin(999), UI.contour(C.cyan, 3, 0.2) })
		for i = 1, 3 do
			creer("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(i / 3.2, i / 3.2),
				BackgroundTransparency = 1, Parent = cadre }, { UI.coin(999), UI.contour(C.cyan, 1, 0.7) })
		end
		local calque = creer("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = cadre })
		local titre = texte({ Text = "HOLOGRAMME", Font = UI.POLICE_GRAS, TextSize = 14, TextColor3 = C.cyan, TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(200, 16), Parent = cadre })
		local tardisPoint = texte({ Text = "▲", Font = UI.POLICE_GRAS, TextSize = 20, TextColor3 = C.ambre, TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(22, 22), Parent = cadre })
		local marqueurs, points, balisesPoints = {}, {}, {}
		local cacheDest, destinations = nil, {}
		local portee = 300

		local function destinationsLues()
			local brut = exterieur:GetAttribute("CarteDestinations") or ""
			if brut == cacheDest then return destinations end
			cacheDest, destinations = brut, {}
			for _, m in marqueurs do m:Destroy() end
			table.clear(marqueurs)
			for ligne in string.gmatch(brut, "[^\n]+") do
				local nom, x, z = string.match(ligne, "^(.-)\t([%-%d%.]+)\t([%-%d%.]+)$")
				if nom then
					table.insert(destinations, { nom = nom, x = tonumber(x), z = tonumber(z) })
					local m = texte({ Text = "◆", Font = UI.POLICE_GRAS, TextSize = 14, TextColor3 = C.ambre, TextXAlignment = Enum.TextXAlignment.Center,
						AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(16, 16), Parent = calque })
					texte({ Text = nom, TextSize = 9, TextColor3 = C.texte, TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd,
						AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(80, 10), Parent = m })
					marqueurs[nom] = m
				end
			end
			return destinations
		end

		task.spawn(function()
			while true do
				task.wait(0.25)
				local visible = jeSuisDedans()
				support.Transparency = 1
				ecran.Enabled = visible
				faisceau.Transparency = visible and (0.82 + 0.08 * math.sin(os.clock() * 6)) or 1
				if visible then
					local pivot = exterieur:GetPivot()
					local c = pivot.Position
					local liste = destinationsLues()
					local loin = 120
					for _, d in liste do loin = math.max(loin, math.abs(d.x - c.X), math.abs(d.z - c.Z)) end
					portee += (math.clamp(loin * 1.15, 120, 5000) - portee) * 0.2
					local function placer(x, z) return UDim2.fromScale(0.5 + (x - c.X) / (2 * portee), 0.5 + (z - c.Z) / (2 * portee)) end
					local choix = UI.destinationPoche and UI.destinationPoche.nom
					for _, d in liste do
						local m = marqueurs[d.nom]
						if m then
							m.Position = placer(d.x, d.z)
							m.TextColor3 = (choix == d.nom) and C.vert or C.ambre
						end
					end
					for _, autre in Players:GetPlayers() do
						local point = points[autre]
						if not point then
							point = creer("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(6, 6),
								BackgroundColor3 = UI.couleurJoueur(autre, autre == joueur and C.cyan or C.blanc), Parent = calque }, { UI.coin(99) })
							points[autre] = point
						end
						local racine = autre.Character and autre.Character:FindFirstChild("HumanoidRootPart")
						point.Visible = racine ~= nil and not dansInterieur(racine.Position)
						if racine then point.Position = placer(racine.Position.X, racine.Position.Z) end
					end
					-- Balises de détresse : points rouges qui clignotent
					for _, b in balisesPoints do b.Visible = false end
					local i = 0
					for ligne in string.gmatch(exterieur:GetAttribute("Balises") or "", "[^\n]+") do
						local _, nom, x, _, z = string.match(ligne, "^(%d+)\t(.-)\t([%-%d%.]+)\t([%-%d%.]+)\t([%-%d%.]+)")
						if nom then
							i += 1
							local b = balisesPoints[i]
							if not b then
								b = texte({ Text = "●", Font = UI.POLICE_GRAS, TextSize = 16, TextColor3 = C.rouge, TextXAlignment = Enum.TextXAlignment.Center,
									AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(18, 18), Parent = calque })
								texte({ Text = "", Name = "Nom", TextSize = 9, TextColor3 = C.rouge, TextXAlignment = Enum.TextXAlignment.Center,
									AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(80, 10), Parent = b })
								balisesPoints[i] = b
							end
							b.Visible = math.floor(os.clock() * 2) % 2 == 0
							b.Position = placer(tonumber(x), tonumber(z))
							b.Nom.Text = nom
						end
					end
					local devant = pivot.LookVector
					tardisPoint.Rotation = math.deg(math.atan2(devant.X, -devant.Z))
					titre.Text = choix and ("DESTINATION : " .. string.upper(choix)) or string.format("HOLOGRAMME · ±%d STUDS", portee)
					cadre.BackgroundTransparency = 0.5 + 0.08 * math.sin(os.clock() * 9) -- léger scintillement d'hologramme
				end
			end
		end)
		Players.PlayerRemoving:Connect(function(autre)
			if points[autre] then points[autre]:Destroy() points[autre] = nil end
		end)
	end

	--------------------------------------------------------------------
	-- 2) Écrans vivants + horloge de bord : une ligne en direct sous le texte de l'écran de la console
	--------------------------------------------------------------------
	do
		local chemin = Config.Chemins and Config.Chemins.Ecran
		local objet = interieur
		for _, nom in chemin or {} do objet = objet and objet:FindFirstChild(nom) end
		local surface = objet and objet:FindFirstChildOfClass("SurfaceGui")
		if surface then
			-- Le texte du serveur garde toute la place sauf une bande en bas, pour la ligne vivante
			for _, etiquette in surface:GetChildren() do
				if etiquette:IsA("TextLabel") then etiquette.Size = UDim2.new(1, 0, 1, -36) end
			end
			local vivant = texte({ Text = "", Font = UI.POLICE_CODE, TextSize = 20, TextColor3 = Color3.fromRGB(120, 230, 255),
				TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd, AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(1, -16, 0, 28), Parent = surface })
			local dernierScan, dernierTexteScan = nil, nil
			task.spawn(function()
				while true do
					task.wait(0.5)
					local p = exterieur:GetPivot().Position
					local heure = Lighting.ClockTime
					local entree = exterieur:GetAttribute("DerniereEntree")
					local age = entree and (os.clock() - (dernierScan or 0)) or 99
					if entree ~= dernierTexteScan then dernierTexteScan, dernierScan, age = entree, os.clock(), 0 end
					if entree and age < 12 then
						vivant.Text = "ENTRÉE : " .. entree -- scan d'identité
						vivant.TextColor3 = Color3.fromRGB(255, 200, 120)
					else
						vivant.Text = string.format("X %d · Y %d · Z %d · %02d:%02d", p.X, p.Y, p.Z, math.floor(heure), math.floor((heure % 1) * 60))
						vivant.TextColor3 = Color3.fromRGB(120, 230, 255)
					end
					vivant.Visible = exterieur:GetAttribute("Alimentation") ~= false
				end
			end)
		end
	end

	--------------------------------------------------------------------
	-- 3) Gravité folle (urgence) : les joueurs à l'intérieur glissent d'un côté puis de l'autre (pas les assis)
	--------------------------------------------------------------------
	RunService.Heartbeat:Connect(function()
		local etat = exterieur:GetAttribute("Etat") or E.Pose
		local urgence = (Config.modeSaccade(Config.modeDe(exterieur)) and etat ~= E.Pose) or exterieur:GetAttribute("VolUrgence") == true
		if not (urgence and jeSuisDedans()) then return end
		if exterieur:GetAttribute("Stabilisateur") ~= false then return end -- le stabilisateur annule la gravité folle
		local racine = maRacine()
		local humanoid = joueur.Character and joueur.Character:FindFirstChildOfClass("Humanoid")
		if racine and not racine.Anchored and not (humanoid and humanoid.Sit) then
			local t = os.clock()
			local poussee = Vector3.new(math.sin(t * 1.3), 0, math.cos(t * 0.9)) * 14
			racine.AssemblyLinearVelocity = Vector3.new(poussee.X, racine.AssemblyLinearVelocity.Y, poussee.Z)
		end
	end)

	--------------------------------------------------------------------
	-- 3 bis) Bourdonnement du moteur (3 sons en fondu enchaîné), vapeur des grilles, jukebox
	--------------------------------------------------------------------
	do
		local rotor = interieur:FindFirstChild(Config.NomRotor or "Rotor")
		local support = rotor and (rotor:IsA("BasePart") and rotor or rotor:FindFirstChildWhichIsA("BasePart", true)) or interieur.PrimaryPart
		local assets = ReplicatedStorage:FindFirstChild("TardisAssets")
		local sons = assets and assets:FindFirstChild("Sons")
		local moteurs = {}
		if support and sons then
			for _, nom in { "Moteur_Pose", "Moteur_Vol", "Moteur_Urgence" } do
				local modele = sons:FindFirstChild(nom)
				if modele then
					local son = modele:Clone()
					son.Looped = true
					son.Volume = 0
					son.RollOffMaxDistance = 80
					son.Parent = support
					son:Play()
					moteurs[nom] = son
				end
			end
		end
		-- Alarme : le son "Alarme" (TardisAssets > Sons) tourne en boucle dans la salle tant que l'alerte est activée
		local alarme = nil
		local modeleAlarme = sons and sons:FindFirstChild("Alarme")
		if support and modeleAlarme and modeleAlarme:IsA("Sound") then
			alarme = modeleAlarme:Clone()
			alarme.Name = "TardisAlarme"
			alarme.Looped = true
			alarme.Parent = support -- le volume des réglages s'applique tout seul (sons de l'intérieur)
			local function majAlarme()
				local active = exterieur:GetAttribute("Alerte") == true and exterieur:GetAttribute("Alimentation") ~= false
					and exterieur:GetAttribute("Detruit") ~= true
				if active and not alarme.IsPlaying then
					alarme.TimePosition = 0
					alarme:Play()
				elseif not active and alarme.IsPlaying then
					alarme:Stop()
				end
			end
			for _, attribut in { "Alerte", "Alimentation", "Detruit" } do
				exterieur:GetAttributeChangedSignal(attribut):Connect(majAlarme)
			end
			majAlarme()
		end
		-- Jukebox (V6.7.3) : son LOCAL (pas positionné), audible seulement à bord, en fondu quand on entre ou sort.
		-- Attribut "Jukebox" : un numéro de piste (en boucle) ou un nom de playlist ("Action" : aléatoire, enchaînée).
		local jukebox, jukeboxIndex, presence = nil, nil, 0
		local playlist, positionPlaylist = nil, 0
		local function piste(index) return (Config.Jukebox or {})[index] end
		local function jouerPiste(index, enBoucle)
			if jukebox then jukebox:Destroy() jukebox = nil end
			local p = piste(index)
			if not p then return end
			jukebox = creer("Sound", { Name = "TardisJukebox", SoundId = "rbxassetid://" .. tostring(p.id), Looped = enBoucle, Volume = 0,
				Parent = game:GetService("SoundService") })
			jukebox:Play()
			if not enBoucle then
				local courant = jukebox
				courant.Ended:Connect(function()
					if jukebox ~= courant or not playlist then return end
					positionPlaylist = positionPlaylist % #playlist + 1
					jouerPiste(playlist[positionPlaylist], false)
				end)
			end
		end
		local function nouvellePlaylist(categorie)
			local liste = {}
			for i, p in Config.Jukebox or {} do
				if p.categorie == categorie then table.insert(liste, i) end
			end
			for i = #liste, 2, -1 do
				local j = math.random(i)
				liste[i], liste[j] = liste[j], liste[i]
			end
			return liste
		end
		RunService.Heartbeat:Connect(function(dt)
			local etat = exterieur:GetAttribute("Etat") or E.Pose
			local urgence = (Config.modeSaccade(Config.modeDe(exterieur)) and etat ~= E.Pose) or exterieur:GetAttribute("VolUrgence") == true
				or exterieur:GetAttribute("Alerte") == true or exterieur:GetAttribute("AutoDestructionDebut") ~= nil
			local alimente = exterieur:GetAttribute("Alimentation") ~= false and exterieur:GetAttribute("Detruit") ~= true
			local cibles = {
				Moteur_Pose = (alimente and not urgence and etat == E.Pose and not exterieur:GetAttribute("VolLibre")) and 1 or 0,
				Moteur_Vol = (alimente and not urgence and (etat ~= E.Pose or exterieur:GetAttribute("VolLibre"))) and 1 or 0,
				Moteur_Urgence = (alimente and urgence) and 1 or 0,
			}
			for nom, son in moteurs do
				son.Volume += (cibles[nom] * 0.5 * UI.volume() - son.Volume) * math.min(dt * 1.5, 1)
			end
			-- Jukebox : la musique choisie dans la tablette, seulement pour ceux qui sont à bord
			local index = exterieur:GetAttribute("Jukebox")
			if index ~= jukeboxIndex then
				jukeboxIndex = index
				playlist = nil
				if type(index) == "string" then
					playlist = nouvellePlaylist(index)
					positionPlaylist = 1
					if #playlist > 0 then jouerPiste(playlist[1], false) elseif jukebox then jukebox:Destroy() jukebox = nil end
				elseif type(index) == "number" then
					jouerPiste(index, true)
				elseif jukebox then
					jukebox:Destroy()
					jukebox = nil
				end
			end
			presence += (((jeSuisDedans() and alimente) and 1 or 0) - presence) * math.min(dt * 1.2, 1)
			if jukebox then jukebox.Volume = 0.5 * UI.volume() * presence end
		end)

		-- Vapeur de refroidissement : un jet sous chaque plaque "Grille", par bouffées aléatoires (les mêmes pour tous)
		local grilles = {}
		for _, objet in interieur:GetDescendants() do
			if objet:IsA("BasePart") and (objet.Name == "Grille" or (objet.Parent and objet.Parent.Name == "Grilles")) then
				local point = creer("Attachment", { Position = Vector3.new(0, -objet.Size.Y / 2 - 0.3, 0), Parent = objet })
				local jet = creer("ParticleEmitter", { Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(Color3.fromRGB(235, 240, 245)),
					Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) }),
					Size = NumberSequence.new(1, 3), Lifetime = NumberRange.new(0.8, 1.6), Speed = NumberRange.new(8, 14), SpreadAngle = Vector2.new(10, 10),
					EmissionDirection = Enum.NormalId.Top, Rate = 0, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-30, 30), Parent = point })
				table.insert(grilles, { jet = jet, periode = 0, phase = 0 })
			end
		end
		local reglagesVapeur = Config.Vapeur or {}
		for i, g in grilles do
			local mini, maxi = reglagesVapeur.IntervalleMin or 4, reglagesVapeur.IntervalleMax or 14
			g.periode = mini + ((i * 7919) % 100) / 100 * (maxi - mini)
			g.phase = (i * 3571) % 100 / 100 * g.periode
		end
		if #grilles > 0 then
			task.spawn(function()
				while true do
					task.wait(0.1)
					local intensite = exterieur:GetAttribute("VapeurIntensite") or reglagesVapeur.Intensite or 1
					local alimente = exterieur:GetAttribute("Alimentation") ~= false
					local temps = workspace:GetServerTimeNow()
					local surcharge = exterieur:GetAttribute("VapeurSurcharge")
					for i, g in grilles do
						if surcharge == i then
							g.jet.Rate = 160 -- surcharge : jet constant et fort (panne, à régler à la visseuse)
						else
							local bouffee = ((temps + g.phase) % g.periode) < 0.7
							g.jet.Rate = (alimente and bouffee) and 50 * intensite or 0
						end
					end
				end
			end)
		end
	end

	--------------------------------------------------------------------
	-- 3 ter) Écrans de diagnostic : les pièces "Diagnostic1" à "Diagnostic4" affichent l'état des systèmes
	--------------------------------------------------------------------
	do
		local ecrans = {}
		for i = 1, 4 do
			local part = interieur:FindFirstChild("Diagnostic" .. i, true)
			if part and part:IsA("BasePart") then
				local surface = creer("SurfaceGui", { Face = Enum.NormalId.Front, LightInfluence = 0, PixelsPerStud = 50, Parent = part })
				local fond = creer("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(2, 10, 20), Parent = surface },
				{ UI.marges(10), UI.pile(4) })
				local titre = texte({ Text = "", Font = UI.POLICE_GRAS, TextSize = 22, TextColor3 = C.cyan, LayoutOrder = 1, Parent = fond })
				local lignes = {}
				for k = 1, 4 do
					lignes[k] = texte({ Text = "", Font = UI.POLICE_CODE, TextSize = 18, TextColor3 = C.texte, LayoutOrder = k + 1, Parent = fond })
				end
				ecrans[i] = { titre = titre, lignes = lignes }
			end
		end
		if next(ecrans) then
			local function voyant(ok, texteOk, texteKo) return (ok and "● " or "○ ") .. (ok and texteOk or texteKo) end
			task.spawn(function()
				while true do
					task.wait(0.5)
					local alimente = exterieur:GetAttribute("Alimentation") ~= false
					local pv = exterieur:GetAttribute("PointsDeVie")
					local contenu = {
						{ "ÉNERGIE", { voyant(alimente, "Alimentation nominale", "HORS TENSION"), voyant(not exterieur:GetAttribute("DemarrageBloque"), "Démarrage libre", "Démarrage bloqué"),
							pv and string.format("Intégrité : %d %%", pv) or "Intégrité : —", voyant(not exterieur:GetAttribute("Alerte"), "Pas d'alerte", "ALERTE GÉNÉRALE") } },
						{ "ACCÈS", { voyant(not exterieur:GetAttribute("PorteOuverte"), "Portes fermées", "Portes ouvertes"), voyant(exterieur:GetAttribute("PortesVerrouillees") == true, "Verrou mis", "Verrou libre"),
							voyant(exterieur:GetAttribute("BouclierJoueurs") == true, "Bouclier anti-joueurs levé", "Bouclier anti-joueurs baissé"), voyant(exterieur:GetAttribute("BouclierBalles") == true, "Bouclier anti-balles levé", "Bouclier anti-balles baissé") } },
						{ "NAVIGATION", { "État : " .. tostring(exterieur:GetAttribute("Etat") or "?"), "Position : " .. tostring(exterieur:GetAttribute("Position") or "?"),
							voyant(exterieur:GetAttribute("Camouflage") ~= true, "Visible", "Camouflé"), voyant(exterieur:GetAttribute("VolLibre") == nil, "Vol libre inactif", "VOL LIBRE") } },
						{ "SÉCURITÉ", { "Dernière entrée : " .. tostring(exterieur:GetAttribute("DerniereEntree") or "—"), "Intrusion : " .. tostring(exterieur:GetAttribute("Intrusion") or "aucune"),
							voyant(exterieur:GetAttribute("Detruit") ~= true, "Structure intacte", "TARDIS DÉTRUIT"), "Voyages du serveur : " .. tostring(exterieur:GetAttribute("StatsServeur") or 0) } },
					}
					for i, ecran in ecrans do
						local bloc = contenu[i]
						ecran.titre.Text = bloc[1]
						for k = 1, 4 do ecran.lignes[k].Text = bloc[2][k] or "" end
						ecran.titre.TextColor3 = alimente and C.cyan or C.rouge
					end
				end
			end)
		end
	end

	return {}
end
