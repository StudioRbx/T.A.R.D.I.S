-- StarterPlayerScripts > TardisExtrasClient > Ambiance (ModuleScript)
-- Hologramme, écrans vivants, gravité folle, moteur et vapeur, écrans de diagnostic, vent du vortex à bord (V6.9.10)
-- (V6.9.12) Sons des pannes (Panne_Vapeur, Panne_Feu, Panne_Grincement, Panne_Etincelles : facultatifs, absents = silence)
-- Extrait du script principal en V6.6.3 : reçoit ce qu'il utilise, renvoie ce que la suite utilise.

return function(contexte)
	local C, Config, E, Lighting, Players, ReplicatedStorage = contexte.C, contexte.Config, contexte.E, contexte.Lighting, contexte.Players, contexte.ReplicatedStorage
	local RunService, UI, boiteInt, creer, dansInterieur, exterieur = contexte.RunService, contexte.UI, contexte.boiteInt, contexte.creer, contexte.dansInterieur, contexte.exterieur
	local interieur, jeSuisDedans, joueur, maRacine, partTemporaire, texte = contexte.interieur, contexte.jeSuisDedans, contexte.joueur, contexte.maRacine, contexte.partTemporaire, contexte.texte
	local tailleInt = contexte.tailleInt -- (V7.3.2) taille de l'intérieur, pour les câbles du plafond

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
		local contours = { UI.contour(C.cyan, 3, 0.2) } -- (V7.3.3, G-119) gardés pour passer au rouge en alerte
		local cadre = creer("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(0, 40, 70), BackgroundTransparency = 0.55,
			Parent = ecran }, { UI.coin(999), contours[1] })
		for i = 1, 3 do
			contours[i + 1] = UI.contour(C.cyan, 1, 0.7)
			creer("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(i / 3.2, i / 3.2),
				BackgroundTransparency = 1, Parent = cadre }, { UI.coin(999), contours[i + 1] })
		end
		local rougeHolo = nil -- (G-119) dernier état appliqué
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
				-- (V7.3.3, G-119) Alerte ou auto-destruction : anneaux, faisceau et titre rouges, qui pulsent (sans battre en « aucun flash »)
				local enAlerte = (Config.AlerteSalle or {}).HologrammeRouge ~= false
					and Config.alerteSalle(exterieur:GetAttribute("Alerte"), exterieur:GetAttribute("AutoDestructionDebut"))
				if enAlerte ~= rougeHolo then
					rougeHolo = enAlerte
					local couleur = enAlerte and C.rouge or C.cyan
					for _, contour in contours do contour.Color = couleur end
					faisceau.Color = couleur
					titre.TextColor3 = couleur
					cadre.BackgroundColor3 = enAlerte and Color3.fromRGB(70, 0, 0) or Color3.fromRGB(0, 40, 70)
				end
				if enAlerte and visible then
					faisceau.Transparency = UI.sansFlash() and 0.6 or (0.45 + 0.35 * (0.5 + 0.5 * math.sin(os.clock() * 8)))
				end
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
					if rougeHolo and not UI.sansFlash() then cadre.BackgroundTransparency = 0.35 + 0.25 * (0.5 + 0.5 * math.sin(os.clock() * 8)) end
				end
			end
		end)
		Players.PlayerRemoving:Connect(function(autre)
			if points[autre] then points[autre]:Destroy() points[autre] = nil end
		end)
	end

	--------------------------------------------------------------------
	-- 2) Écrans vivants + horloge de bord : une ligne en direct dans la bande du bas de chaque écran de destination
	-- (V6.9.10.1 : les écrans sont faits par le serveur, module TardisServeur › Ecrans, un ou plusieurs ; la ligne va
	-- dans leur cadre « LigneVivante », sans toucher au reste de l'affichage)
	--------------------------------------------------------------------
	do
		local chemin = Config.Chemins and Config.Chemins.Ecran or { "Console", "Ecran" }
		local vivants = {} -- [TextLabel] = true, un par écran
		local function brancher(objet)
			if not (objet:IsA("SurfaceGui") and objet.Name == "TardisEcranDestination") then return end
			task.spawn(function()
				local fond = objet:WaitForChild("Fond", 10)
				local zone = fond and fond:WaitForChild("LigneVivante", 10)
				if not zone or zone:FindFirstChild("TardisVivant") then return end
				-- (V6.9.10.7) Maquette de l'écran de destination : Roboto Mono, couleur du texte de la charte, à gauche
				local vivant = texte({ Name = "TardisVivant", Text = "", Font = UI.POLICE_CODE, TextScaled = true, TextColor3 = UI.JETONS.texte,
					TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.fromScale(1, 1), Parent = zone })
				vivants[vivant] = true
			end)
		end
		-- Les écrans sont dans le dossier de Config.Chemins.Ecran (la Console), qui peut arriver plus tard (Streaming)
		task.spawn(function()
			local dossier = interieur
			for i = 1, #chemin - 1 do
				dossier = dossier and (dossier:FindFirstChild(chemin[i]) or dossier:WaitForChild(chemin[i], 30))
			end
			if not dossier then return end
			for _, objet in dossier:GetDescendants() do brancher(objet) end
			dossier.DescendantAdded:Connect(brancher)
		end)
		local dernierScan, dernierTexteScan = nil, nil
		task.spawn(function()
			while true do
				task.wait(0.5)
				if next(vivants) then
					local p = exterieur:GetPivot().Position
					local heure = Lighting.ClockTime
					local entree = exterieur:GetAttribute("DerniereEntree")
					local age = entree and (os.clock() - (dernierScan or 0)) or 99
					if entree ~= dernierTexteScan then dernierTexteScan, dernierScan, age = entree, os.clock(), 0 end
					local ligne, couleur
					if entree and age < 12 then
						ligne, couleur = "ENTRÉE : " .. entree, UI.JETONS.jaune -- scan d'identité
					else
						ligne = string.format("X %d · Y %d · Z %d · %02d:%02d", p.X, p.Y, p.Z, math.floor(heure), math.floor((heure % 1) * 60))
						couleur = UI.JETONS.texte
					end
					local visible = exterieur:GetAttribute("Alimentation") ~= false
					for vivant in vivants do
						if vivant.Parent then
							vivant.Text, vivant.TextColor3, vivant.Visible = ligne, couleur, visible
						else
							vivants[vivant] = nil
						end
					end
				end
			end
		end)
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
		local support = rotor and (rotor:IsA("BasePart") and rotor or rotor:FindFirstChildWhichIsA("BasePart", true)) or Config.partPrincipale(interieur)
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
		-- (V7.5.4.1) Le serveur copie l'alarme du kit dans TardisAssets › Sons › Alarme au démarrage : on l'attend (10 s au
		-- plus, sans bloquer le reste) ; son volume est limité à Config.Alarme.VolumeMax (25 %)
		task.spawn(function()
		local alarme = nil
		local modeleAlarme = sons and (sons:FindFirstChild("Alarme") or sons:WaitForChild("Alarme", 10))
		if support and modeleAlarme and modeleAlarme:IsA("Sound") then
			alarme = modeleAlarme:Clone()
			alarme.Name = "TardisAlarme"
			alarme.Looped = true
			alarme.Volume = math.min(alarme.Volume, tonumber((Config.Alarme or {}).VolumeMax) or 0.25)
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
		end)
		-- Jukebox (V6.7.3) : son LOCAL (pas positionné), audible seulement à bord, en fondu quand on entre ou sort.
		-- Attribut "Jukebox" : un numéro de piste (en boucle) ou un nom de playlist ("Action" : aléatoire, enchaînée).
		-- (V6.9.10.5) Pistes : Config.Jukebox et les Sound du dossier TardisAssets › Jukebox (Config.pistesJukebox, mêmes
		-- numéros que sur le serveur). Une piste du dossier joue une copie de son Sound (son volume et sa vitesse gardés).
		local jukebox, jukeboxIndex, presence = nil, nil, 0
		local volumeJukebox = 0.5
		local playlist, positionPlaylist = nil, 0
		local function piste(index) return Config.pistesJukebox()[index] end
		local function jouerPiste(index, enBoucle)
			if jukebox then jukebox:Destroy() jukebox = nil end
			local p = piste(index)
			if not p then return end
			if typeof(p.son) == "Instance" and p.son:IsA("Sound") then
				volumeJukebox = p.son.Volume
				jukebox = p.son:Clone()
				jukebox.Name = "TardisJukebox"
				jukebox.Looped = enBoucle
				jukebox.Volume = 0
				jukebox.Parent = game:GetService("SoundService")
			else
				volumeJukebox = 0.5
				jukebox = creer("Sound", { Name = "TardisJukebox", SoundId = "rbxassetid://" .. tostring(p.id), Looped = enBoucle, Volume = 0,
					Parent = game:GetService("SoundService") })
			end
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
		-- Vent du vortex (V6.9.10) : le Sound « Vortex » en boucle, LOCAL (pas positionné) comme le jukebox, seulement à bord,
		-- en fondu, pendant le vol (état Vol, ou vol libre dématérialisé ou dans le VORTEX). Il disparaît quand il s'est tu.
		local reglagesVortex = Config.AmbianceVortex or {}
		local vortex, volumeVortex, prochaineRecherche = nil, 0, 0
		local function majVortex(dt, etat, alimente)
			local vol = etat == E.Vol or (exterieur:GetAttribute("VolLibre") ~= nil
				and (exterieur:GetAttribute("VolPhase") == "Invisible" or exterieur:GetAttribute("VolVortex") == true))
			local voulu = (vol and alimente and jeSuisDedans()) and 1 or 0
			volumeVortex += (voulu - volumeVortex) * math.min(dt * (reglagesVortex.Fondu or 1), 1)
			if voulu == 0 and volumeVortex < 0.01 then
				volumeVortex = 0
				if vortex then vortex:Destroy() vortex = nil end -- se coupe proprement : aucun son ne reste
				return
			end
			if not vortex and os.clock() >= prochaineRecherche then
				prochaineRecherche = os.clock() + 2 -- le Sound peut arriver plus tard (créé par le serveur depuis Config.Sons)
				local modele = sons and sons:FindFirstChild("Vortex")
				if not modele then
					local dossier = ReplicatedStorage:FindFirstChild("TardisAssets")
					modele = dossier and dossier:FindFirstChild("Sons") and dossier.Sons:FindFirstChild("Vortex")
				end
				if modele and modele:IsA("Sound") then
					vortex = modele:Clone()
					vortex.Name = "TardisVortex"
					vortex.Looped = true
					vortex.Volume = 0
					vortex.Parent = game:GetService("SoundService")
					vortex:Play()
				end
			end
			if vortex then
				local jukeboxJoue = exterieur:GetAttribute("Jukebox") ~= nil
				vortex.Volume = (reglagesVortex.Volume or 0.4) * UI.volume() * volumeVortex * (jukeboxJoue and (reglagesVortex.AvecJukebox or 0.5) or 1)
			end
		end
		local function nouvellePlaylist(categorie)
			local liste = {}
			for i, p in Config.pistesJukebox() do
				if p.categorie == categorie then table.insert(liste, i) end
			end
			for i = #liste, 2, -1 do
				local j = math.random(i)
				liste[i], liste[j] = liste[j], liste[i]
			end
			return liste
		end
		-- (V7.3.2, G-163) Câbles du plafond : les pièces ancrées « Cable » de l'intérieur (pendues par leur haut), sinon
		-- Config.Salle.CordesLocales câbles créés pour soi en cercle autour du centre. Ils se balancent en voyage (plus en
		-- urgence, moins stabilisé), sursautent à l'atterrissage et reprennent leur place au repos.
		local reglagesSalle = Config.Salle or {}
		local cables = {}
		if reglagesSalle.Cables ~= false then
			for _, objet in interieur:GetDescendants() do
				if objet:IsA("BasePart") and objet.Name == "Cable" and objet.Anchored then
					table.insert(cables, { part = objet, repos = objet.CFrame, haut = objet.CFrame * CFrame.new(0, objet.Size.Y / 2, 0), longueur = objet.Size.Y })
				end
			end
			if #cables == 0 and (reglagesSalle.CordesLocales or 0) > 0 and boiteInt and tailleInt then
				local n = math.floor(reglagesSalle.CordesLocales)
				local longueur = reglagesSalle.LongueurCordes or 4
				local rayon = math.min(math.min(tailleInt.X, tailleInt.Z) * 0.3, 12)
				for i = 1, n do
					local a = (i / n) * math.pi * 2
					local haut = boiteInt * CFrame.new(math.cos(a) * rayon, tailleInt.Y / 2 - 0.2, math.sin(a) * rayon)
					local repos = haut * CFrame.new(0, -longueur / 2, 0)
					local part = partTemporaire({ Name = "TardisCable", Size = Vector3.new(0.15, longueur, 0.15), CFrame = repos,
						Color = Color3.fromRGB(35, 35, 40), Material = Enum.Material.SmoothPlastic })
					table.insert(cables, { part = part, repos = repos, haut = haut, longueur = longueur })
				end
			end
			for i, c in cables do c.phase = i * 1.3 end
		end
		local forceCables, chocCables, etatCables, auRepos = 0, 0, nil, true
		local function majCables(dt, etat, urgence)
			if #cables == 0 then return end
			if etat ~= etatCables then
				if etat == E.Pose and etatCables == E.Remat then chocCables = 1 end
				etatCables = etat
			end
			chocCables = math.max(chocCables - dt * 0.5, 0)
			local cible = Config.forceCables(etat, urgence, exterieur:GetAttribute("Stabilisateur") ~= false, chocCables)
			if UI.effetsReduits ~= nil and UI.effetsReduits() == true then cible *= 0.3 end
			forceCables += (cible - forceCables) * math.min(dt * 2, 1)
			if forceCables < 0.01 and cible == 0 then
				forceCables = 0
				if not auRepos then
					auRepos = true
					for _, c in cables do if c.part.Parent then c.part.CFrame = c.repos end end
				end
				return
			end
			auRepos = false
			local t = os.clock()
			for _, c in cables do
				if c.part.Parent then
					local ax, az = Config.angleCable(t, forceCables, c.phase)
					c.part.CFrame = c.haut * CFrame.Angles(ax, 0, az) * CFrame.new(0, -c.longueur / 2, 0)
				end
			end
		end
		local derniereMusique = nil
		RunService.Heartbeat:Connect(function(dt)
			local etat = exterieur:GetAttribute("Etat") or E.Pose
			local urgence = (Config.modeSaccade(Config.modeDe(exterieur)) and etat ~= E.Pose) or exterieur:GetAttribute("VolUrgence") == true
				or exterieur:GetAttribute("Alerte") == true or exterieur:GetAttribute("AutoDestructionDebut") ~= nil
			local alimente = exterieur:GetAttribute("Alimentation") ~= false and exterieur:GetAttribute("Detruit") ~= true
			-- Silence à bord (V6.9.7, Config.Modes.Silencieux.SilenceABord) : moteur et jukebox se taisent pendant un voyage Silencieux
			local silence = (Config.Modes.Silencieux or {}).SilenceABord == true and etat ~= E.Pose and Config.modeDe(exterieur) == "Silencieux"
			if silence then alimente = false end
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
			if jukebox then jukebox.Volume = volumeJukebox * UI.volume() * presence end
			-- (V7.3.2, G-140) Volume de la musique entendue, pour les LEDs de la salle (TardisEffets) : attribut local
			local musique = nil
			if jukebox and presence > 0.05 and reglagesSalle.LumieresMusique ~= false then
				musique = math.floor((tonumber(jukebox.PlaybackLoudness) or 0) * presence)
			end
			if musique ~= derniereMusique then
				derniereMusique = musique
				interieur:SetAttribute("TardisMusique", musique)
			end
			majCables(dt, etat, urgence)
			-- V6.9.10 : vent du vortex (alimente est déjà faux hors tension, détruit, ou en Silencieux avec SilenceABord)
			majVortex(dt, etat, alimente)
		end)

		-- Vapeur de refroidissement : un jet sous chaque plaque "Grille", par bouffées aléatoires (les mêmes pour tous)
		local grilles = {}
		local partsGrilles = {} -- (V6.9.12) les pièces, pour retrouver la grille en surcharge comme le serveur (Config.grilleEnPanne)
		for _, objet in interieur:GetDescendants() do
			if objet:IsA("BasePart") and (objet.Name == "Grille" or (objet.Parent and objet.Parent.Name == "Grilles")) then
				local point = creer("Attachment", { Position = Vector3.new(0, -objet.Size.Y / 2 - 0.3, 0), Parent = objet })
				local jet = creer("ParticleEmitter", { Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(Color3.fromRGB(235, 240, 245)),
					Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) }),
					Size = NumberSequence.new(1, 3), Lifetime = NumberRange.new(0.8, 1.6), Speed = NumberRange.new(8, 14), SpreadAngle = Vector2.new(10, 10),
					EmissionDirection = Enum.NormalId.Top, Rate = 0, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-30, 30), Parent = point })
				-- (V7.3.1, G-145/G-147) lueur orange sous la grille, et air qui tremble au-dessus en surcharge (après le jet)
				local lueur = creer("PointLight", { Name = "TardisLueurGrille", Color = Color3.fromRGB(255, 140, 50), Brightness = 0, Range = 10, Enabled = false, Parent = point })
				local tremble = creer("ParticleEmitter", { Name = "TardisAirTremble", Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(Color3.fromRGB(255, 255, 255)),
					Transparency = NumberSequence.new(0.92, 1), Size = NumberSequence.new(2, 4), Lifetime = NumberRange.new(0.6, 1), Speed = NumberRange.new(2, 4),
					EmissionDirection = Enum.NormalId.Top, Rate = 0, Parent = point })
				table.insert(grilles, { jet = jet, part = objet, periode = 0, phase = 0, lueur = lueur, tremble = tremble })
				table.insert(partsGrilles, objet) -- (V6.9.12)
			end
		end
		local reglagesVapeur = Config.Vapeur or {}
		local reglagesSurchauffe = Config.Surchauffe or {} -- (V7.3.1)
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
					if exterieur:GetAttribute("Surchauffe") then intensite *= 2 end -- (V7.3.1, C-117) la surchauffe se voit
					local alimente = exterieur:GetAttribute("Alimentation") ~= false
					local temps = workspace:GetServerTimeNow()
					local enVol = alimente and (exterieur:GetAttribute("Etat") ~= E.Pose or exterieur:GetAttribute("VolLibre") ~= nil)
					-- (V6.9.12) la grille désignée par le serveur (attribut TardisGrille), plus seulement la n-ième de la liste
					local enPanne = Config.grilleEnPanne(exterieur, interieur, partsGrilles)
					for _, g in grilles do
						local surcharge = enPanne ~= nil and g.part == enPanne
						if surcharge then
							g.jet.Rate = 160 -- surcharge : jet constant et fort (panne, à régler à la visseuse)
						else
							local bouffee = ((temps + g.phase) % g.periode) < 0.7
							g.jet.Rate = (alimente and bouffee) and 50 * intensite or 0
						end
						-- (V7.3.1, G-145/G-147) rougeoiement : fort et vacillant en surcharge, doux en vol
						if surcharge and reglagesSurchauffe.LueurSurcharge ~= false then
							g.lueur.Enabled, g.lueur.Brightness = true, 2.5 + math.sin(temps * 9) * 0.8
						elseif enVol and reglagesSurchauffe.LueurVol ~= false then
							g.lueur.Enabled, g.lueur.Brightness = true, 1
						else
							g.lueur.Enabled, g.lueur.Brightness = false, 0
						end
						g.tremble.Rate = (surcharge and reglagesSurchauffe.LueurSurcharge ~= false) and 12 or 0
					end
				end
			end)
			-- (V7.3.1, G-143/G-144) Bouffée de toutes les grilles à l'atterrissage ; au départ, une vague qui fait le tour de la salle
			local etatAvant = exterieur:GetAttribute("Etat")
			exterieur:GetAttributeChangedSignal("Etat"):Connect(function()
				local etat = exterieur:GetAttribute("Etat")
				local avant = etatAvant
				etatAvant = etat
				if exterieur:GetAttribute("Alimentation") == false or exterieur:GetAttribute("Detruit") == true then return end
				local reduits = UI.effetsReduits ~= nil and UI.effetsReduits() == true
				if etat == E.Pose and avant == E.Remat and reglagesSurchauffe.BouffeeAtterrissage ~= false then
					for _, g in grilles do g.jet:Emit(reduits and 10 or 30) end
				elseif etat == E.Demat and reglagesSurchauffe.VagueDemat ~= false then
					local centre = boiteInt and boiteInt.Position or Vector3.zero
					local ordre = table.clone(grilles)
					local function angle(g)
						local d = g.part.Position - centre
						return math.atan2(d.Z, d.X)
					end
					table.sort(ordre, function(a, b) return angle(a) < angle(b) end)
					for i, g in ordre do
						task.delay((i - 1) * 0.15, function() g.jet:Emit(reduits and 6 or 18) end)
					end
				end
			end)
		end

		-- (V6.9.12) Sons des pannes, chez chaque joueur, positionnés dans la salle (le volume des réglages s'applique tout
		-- seul, comme pour l'alarme). Tous facultatifs (TardisAssets › Sons, ou Config.Sons) : un son absent = silence.
		--   Panne_Vapeur : sifflement en boucle sur la grille en surcharge ; Panne_Feu : crépitement en boucle sur la
		--   console en feu ; Panne_Grincement : grincement au hasard (8 à 15 s) pendant une avarie ou une coupure ;
		--   Panne_Etincelles : une fois, quand on clique sur le rotor en panne (attribut PanneEtincelles du serveur).
		-- (V6.9.13) Panne_FuiteAir : sifflement en boucle sur la fuite d'air ; RotorBloque : raclement, une fois, à chaque
		--   tentative de départ rotor bloqué (attribut RotorTentative) ; Soudure : grésillement à chaque passage du soudeur
		--   (attribut SoudureTemps), sur la brèche.
		do
			local partConsole = Config.partDe(interieur:FindFirstChild("Console")) or support
			local enBoucle = {} -- [nom] = { son, part }
			local prochaineRechercheSons, prochainGrincement = 0, 0
			local function modeleSon(nom)
				if os.clock() >= prochaineRechercheSons or not sons then
					prochaineRechercheSons = os.clock() + 2 -- les Sound peuvent arriver plus tard (créés par le serveur)
					local dossier = ReplicatedStorage:FindFirstChild("TardisAssets")
					sons = (dossier and dossier:FindFirstChild("Sons")) or sons
				end
				local modele = sons and sons:FindFirstChild(nom)
				if modele and modele:IsA("Sound") then return modele end
				return nil
			end
			local function boucle(nom, part)
				local actuel = enBoucle[nom]
				if actuel and (not part or actuel.part ~= part or not actuel.son.Parent) then
					actuel.son:Destroy()
					enBoucle[nom] = nil
					actuel = nil
				end
				if part and not actuel then
					local modele = modeleSon(nom)
					if modele then
						local son = modele:Clone()
						son.Name = "Tardis" .. nom
						son.Looped = true
						son.RollOffMaxDistance = 40
						son.Parent = part
						son:Play()
						enBoucle[nom] = { son = son, part = part }
					end
				end
			end
			local function unCoup(nom, part)
				local modele = part and modeleSon(nom)
				if not modele then return end
				local son = modele:Clone()
				son.Name = "Tardis" .. nom
				son.Looped = false
				son.RollOffMaxDistance = 40
				son.Parent = part
				son:Play()
				task.delay(math.max(tonumber(son.TimeLength) or 0, 5) + 1, function() son:Destroy() end) -- (le son peut ne pas être encore chargé)
			end
			task.spawn(function()
				while true do
					task.wait(0.25)
					local detruit = exterieur:GetAttribute("Detruit") == true
					local grille = (not detruit) and Config.grilleEnPanne(exterieur, interieur, partsGrilles) or nil
					boucle("Panne_Vapeur", grille)
					local feu = not detruit and exterieur:GetAttribute("Incendie") == true and not exterieur:GetAttribute("IncendieEteint") -- IncendieEteint = heure de l'extincteur
					boucle("Panne_Feu", feu and partConsole or nil)
					boucle("Panne_FuiteAir", (not detruit) and Config.pieceEnPanne(exterieur, interieur, "FuiteAir") or nil) -- (V6.9.13)
					local grince = not detruit and (exterieur:GetAttribute("Avarie") == true or exterieur:GetAttribute("RedemarrageRequis") == true)
					if grince and os.clock() >= prochainGrincement then
						if prochainGrincement > 0 then unCoup("Panne_Grincement", support) end
						prochainGrincement = os.clock() + 8 + math.random() * 7
					elseif not grince then
						prochainGrincement = 0
					end
				end
			end)
			exterieur:GetAttributeChangedSignal("PanneEtincelles"):Connect(function()
				unCoup("Panne_Etincelles", support)
			end)
			-- (V6.9.13) rotor bloqué et soudeur
			exterieur:GetAttributeChangedSignal("RotorTentative"):Connect(function()
				if exterieur:GetAttribute("RotorTentative") then unCoup("RotorBloque", support) end
			end)
			exterieur:GetAttributeChangedSignal("SoudureTemps"):Connect(function()
				unCoup("Soudure", Config.pieceEnPanne(exterieur, interieur, "Breche") or support)
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
		-- (V7.3.1, G-200) Courbe du moteur sur le premier écran : 30 barres qui défilent (calme posé, ondulée en vol, en dents
		-- de scie en urgence, plate hors tension)
		if ecrans[1] and (Config.Surchauffe or {}).CourbeMoteur ~= false then
			local cadre = creer("Frame", { Name = "TardisCourbeMoteur", Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = 10,
				Parent = ecrans[1].titre.Parent })
			local barres, historique = {}, {}
			for k = 1, 30 do
				barres[k] = creer("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new((k - 1) / 30, 0, 1, 0), Size = UDim2.new(1 / 30, -1, 0.03, 0),
					BorderSizePixel = 0, BackgroundColor3 = C.cyan, Parent = cadre })
				historique[k] = 0
			end
			local couleurs = { Pose = C.cyan, Vol = C.vert, Urgence = C.rouge, HorsTension = C.rouge }
			task.spawn(function()
				while true do
					task.wait(0.1)
					local etat = exterieur:GetAttribute("Etat") or E.Pose
					local urgence = (Config.modeSaccade(Config.modeDe(exterieur)) and etat ~= E.Pose) or exterieur:GetAttribute("VolUrgence") == true
						or exterieur:GetAttribute("Alerte") == true or exterieur:GetAttribute("AutoDestructionDebut") ~= nil
					local alimente = exterieur:GetAttribute("Alimentation") ~= false and exterieur:GetAttribute("Detruit") ~= true
					local regime = Config.regimeMoteur(alimente, urgence, etat ~= E.Pose or exterieur:GetAttribute("VolLibre") ~= nil)
					table.remove(historique, 1)
					table.insert(historique, Config.courbeMoteur(os.clock(), regime))
					for k, barre in barres do
						barre.Size = UDim2.new(1 / 30, -1, math.max(historique[k], 0.03), 0)
						barre.BackgroundColor3 = couleurs[regime] or C.cyan
					end
				end
			end)
		end
		if next(ecrans) then
			-- (V7.3.1, G-199) chaque voyant a sa couleur : vert si bon, ambre sinon, rouge si c'est grave
			local function voyant(ok, texteOk, texteKo, grave)
				local signe, couleur = Config.voyantDiagnostic(ok, grave)
				return { signe .. " " .. (ok and texteOk or texteKo), C[couleur] or C.texte }
			end
			task.spawn(function()
				while true do
					task.wait(0.5)
					local alimente = exterieur:GetAttribute("Alimentation") ~= false
					local pv = exterieur:GetAttribute("PointsDeVie")
					local contenu = {
						{ "ÉNERGIE", { voyant(alimente, "Alimentation nominale", "HORS TENSION", true), voyant(not exterieur:GetAttribute("DemarrageBloque"), "Démarrage libre", "Démarrage bloqué", true),
							pv and string.format("Intégrité : %d %%", pv) or "Intégrité : —", voyant(not exterieur:GetAttribute("Alerte"), "Pas d'alerte", "ALERTE GÉNÉRALE", true) } },
						{ "ACCÈS", { voyant(not exterieur:GetAttribute("PorteOuverte"), "Portes fermées", "Portes ouvertes"), voyant(exterieur:GetAttribute("PortesVerrouillees") == true, "Verrou mis", "Verrou libre"),
							voyant(exterieur:GetAttribute("BouclierJoueurs") == true, "Bouclier anti-joueurs levé", "Bouclier anti-joueurs baissé"), voyant(exterieur:GetAttribute("BouclierBalles") == true, "Bouclier anti-balles levé", "Bouclier anti-balles baissé") } },
						{ "NAVIGATION", { "État : " .. tostring(exterieur:GetAttribute("Etat") or "?"), "Position : " .. tostring(exterieur:GetAttribute("Position") or "?"),
							voyant(exterieur:GetAttribute("Camouflage") ~= true, "Visible", "Camouflé"), voyant(exterieur:GetAttribute("VolLibre") == nil, "Vol libre inactif", "VOL LIBRE") } },
						{ "SÉCURITÉ", { "Dernière entrée : " .. tostring(exterieur:GetAttribute("DerniereEntree") or "—"), "Intrusion : " .. tostring(exterieur:GetAttribute("Intrusion") or "aucune"),
							voyant(exterieur:GetAttribute("Detruit") ~= true, "Structure intacte", "TARDIS DÉTRUIT", true), "Voyages du serveur : " .. tostring(exterieur:GetAttribute("StatsServeur") or 0) } },
					}
					-- (V7.3.3, G-175) En alerte, les 4 écrans affichent un grand « ALERTE » rouge une seconde sur trois
					local alerteEcran = (Config.AlerteSalle or {}).EcransAlerte ~= false
						and Config.alerteSalle(exterieur:GetAttribute("Alerte"), exterieur:GetAttribute("AutoDestructionDebut"))
						and Config.ecranAlerte(os.clock())
					local autoDestruction = exterieur:GetAttribute("AutoDestructionDebut") ~= nil
					for i, ecran in ecrans do
						local bloc = contenu[i]
						ecran.titre.Text = alerteEcran and "⚠ ALERTE ⚠" or bloc[1]
						ecran.titre.TextSize = alerteEcran and 44 or 22
						for k = 1, 4 do
							local ligne = bloc[2][k] or ""
							if alerteEcran then
								ecran.lignes[k].Text, ecran.lignes[k].TextColor3 = (k == 1 and autoDestruction) and "AUTO-DESTRUCTION" or "", C.rouge
							elseif type(ligne) == "table" then
								ecran.lignes[k].Text, ecran.lignes[k].TextColor3 = ligne[1], ligne[2]
							else
								ecran.lignes[k].Text, ecran.lignes[k].TextColor3 = ligne, C.texte
							end
						end
						ecran.titre.TextColor3 = (alimente and not alerteEcran) and C.cyan or C.rouge
					end
				end
			end)
		end
	end

	--------------------------------------------------------------------
	-- 3 quater) (V7.3.3, G-133) Gyrophares : deux projecteurs rouges qui tournent au plafond pendant une alerte
	-- (aux pièces « Gyrophare » de l'intérieur s'il y en a, sinon au-dessus de la console ; ces pièces ne bougent jamais)
	--------------------------------------------------------------------
	do
		local reglages = Config.AlerteSalle or {}
		if reglages.Gyrophares ~= false then
			local positions = {}
			for _, objet in interieur:GetDescendants() do
				if objet:IsA("BasePart") and objet.Name == "Gyrophare" and #positions < 4 then table.insert(positions, objet.Position) end
			end
			if #positions == 0 then
				local partConsole = Config.partDe(interieur:FindFirstChild("Console"))
				local centre = (partConsole and typeof(partConsole.Position) == "Vector3" and partConsole.Position)
					or (boiteInt and boiteInt.Position) or Vector3.zero
				local plafond = (boiteInt and tailleInt) and (boiteInt.Position.Y + tailleInt.Y / 2 - 1) or (centre.Y + 10)
				local haut = math.min(centre.Y + 10, plafond)
				positions = { Vector3.new(centre.X - 3, haut, centre.Z), Vector3.new(centre.X + 3, haut, centre.Z) }
			end
			local gyros = {}
			for i, position in positions do
				local support = partTemporaire({ Name = "TardisGyrophare", Transparency = 1, Size = Vector3.new(0.4, 0.4, 0.4), CFrame = CFrame.new(position) })
				local spot = creer("SpotLight", { Name = "TardisGyrophareLumiere", Color = Color3.fromRGB(255, 30, 30), Brightness = 4, Angle = 45,
					Range = reglages.PorteeGyrophares or 40, Face = Enum.NormalId.Front, Enabled = false, Parent = support })
				gyros[i] = { support = support, spot = spot, base = position, decalage = (i - 1) * math.pi }
			end
			local allumes = false
			RunService.RenderStepped:Connect(function() -- (rotation à chaque image, côté client)
				local alerte = Config.alerteSalle(exterieur:GetAttribute("Alerte"), exterieur:GetAttribute("AutoDestructionDebut"))
					and exterieur:GetAttribute("Detruit") ~= true
				if alerte ~= allumes then
					allumes = alerte
					for _, g in gyros do g.spot.Enabled = alerte end
				end
				if not alerte then return end
				local vitesse = (reglages.VitesseGyrophares or 3) * (UI.sansFlash() and 0.4 or 1) -- « aucun flash » : ils tournent lentement
				local angle = os.clock() * vitesse
				for _, g in gyros do
					g.support.CFrame = CFrame.new(g.base) * CFrame.Angles(0, angle + g.decalage, 0) * CFrame.Angles(-math.rad(35), 0, 0)
				end
			end)
		end
	end

	return {}
end
