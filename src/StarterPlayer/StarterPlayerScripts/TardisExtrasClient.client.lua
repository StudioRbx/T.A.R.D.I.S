-- StarterPlayer > StarterPlayerScripts > TardisExtrasClient (LocalScript)
-- Effets et affichages supplémentaires :
--   hologramme de la map au-dessus de la console, écrans vivants et horloge de bord, gravité folle en urgence,
--   lumières synchronisées au rotor, halo de la lampe, ombre annonciatrice, air qui ondule, givre d'urgence,
--   distorsion d'écran près du TARDIS, impacts sur le bouclier, projecteur, leurre, rayon tracteur, chocs en vol,
--   enregistrement et replay du dernier vol.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local Config = require(ReplicatedStorage:WaitForChild("TardisConfig"))
local UI = require(ReplicatedStorage:WaitForChild("TardisUI"))
local C = UI.C
local creer, texte, animer = UI.creer, UI.texte, UI.animer

local joueur = Players.LocalPlayer
local camera = workspace.CurrentCamera
local def = Config.demarrerPourChaqueTardis(script) -- un exemplaire par TARDIS : tout le monde voit les trois
local exterieur, interieur = Config.modeles(def)
local remote = ReplicatedStorage:WaitForChild(Config.canal(def, "TardisCommande"))
local E = Config.Etats

local boiteInt, tailleInt = interieur:GetBoundingBox()
local function dansInterieur(position)
	local local_ = boiteInt:PointToObjectSpace(position)
	return math.abs(local_.X) <= tailleInt.X / 2 + 20 and math.abs(local_.Y) <= tailleInt.Y / 2 + 20 and math.abs(local_.Z) <= tailleInt.Z / 2 + 20
end
local function maRacine()
	return joueur.Character and joueur.Character:FindFirstChild("HumanoidRootPart")
end
local function jeSuisDedans()
	local racine = maRacine()
	return racine ~= nil and dansInterieur(racine.Position)
end
local function partTemporaire(proprietes)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	for cle, valeur in proprietes do p[cle] = valeur end
	p.Parent = workspace
	return p
end
-- Progression (0..1) de l'animation en cours (voyage ou démat en vol), et si c'est une matérialisation
local function progressionAnimation()
	local etat = exterieur:GetAttribute("Etat") or E.Pose
	local phase = exterieur:GetAttribute("VolPhase")
	local debut, urgence, quoi
	if etat == E.Demat or etat == E.Remat then
		debut, urgence, quoi = exterieur:GetAttribute("DebutEtat"), exterieur:GetAttribute("Urgence") == true, etat
	elseif phase == E.Demat or phase == E.Remat then
		debut, urgence, quoi = exterieur:GetAttribute("VolPhaseDebut"), exterieur:GetAttribute("VolPhaseUrgence") == true, phase
	else
		return nil
	end
	local duree, decalage = Config.Timing(quoi, urgence, exterieur:GetAttribute("Express") == true)
	local p = ((workspace:GetServerTimeNow() - (debut or 0)) - decalage) / duree
	if p < -0.3 or p > 1 then return nil end
	return math.clamp(p, 0, 1), quoi == E.Remat
end
-- La lampe du toit : la pièce qui contient la PointLight de l'extérieur
local lampe = nil
for _, objet in exterieur:GetDescendants() do
	if objet:IsA("PointLight") and not objet:IsDescendantOf(exterieur:FindFirstChild("Boucliers") or exterieur.PrimaryPart) then
		local support = objet.Parent:IsA("Attachment") and objet.Parent.Parent or objet.Parent
		-- La lumière peut être dans un Model "Lampe" : on prend une vraie pièce
		if support and support:IsA("Model") then support = support.PrimaryPart or support:FindFirstChildWhichIsA("BasePart", true) end
		if support and support:IsA("BasePart") then lampe = support break end
	end
end

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
	local urgence = (exterieur:GetAttribute("Urgence") == true and etat ~= E.Pose) or exterieur:GetAttribute("VolUrgence") == true
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
	local jukebox, jukeboxIndex = nil, nil
	RunService.Heartbeat:Connect(function(dt)
		local etat = exterieur:GetAttribute("Etat") or E.Pose
		local urgence = (exterieur:GetAttribute("Urgence") == true and etat ~= E.Pose) or exterieur:GetAttribute("VolUrgence") == true
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
		-- Jukebox : la musique choisie dans le menu, audible dans la salle
		local index = exterieur:GetAttribute("Jukebox")
		if index ~= jukeboxIndex then
			jukeboxIndex = index
			if jukebox then jukebox:Destroy() jukebox = nil end
			local piste = index and (Config.Jukebox or {})[index]
			if piste and support then
				jukebox = creer("Sound", { SoundId = "rbxassetid://" .. tostring(piste.id), Looped = true, Volume = 0.5 * UI.volume(),
					RollOffMaxDistance = 90, Parent = support })
				jukebox:Play()
			end
		elseif jukebox then
			jukebox.Volume = 0.5 * UI.volume()
		end
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

--------------------------------------------------------------------
-- 4) Halo de la lampe (visible de loin la nuit) et projecteur
--------------------------------------------------------------------
if lampe then
	-- (le halo de la lampe a été retiré à la demande du pilote)
	local lumiere = lampe:FindFirstChildOfClass("PointLight") or (lampe:FindFirstChildOfClass("Attachment") and lampe:FindFirstChildOfClass("Attachment"):FindFirstChildOfClass("PointLight"))

	-- Projecteur : un cône de lumière orienté, piloté par la caméra du pilote
	local supportProj = partTemporaire({ Name = "TardisProjecteur", Transparency = 1, Size = Vector3.new(0.5, 0.5, 0.5), CFrame = lampe.CFrame })
	local spot = creer("SpotLight", { Angle = 38, Brightness = 0, Range = 220, Face = Enum.NormalId.Front, Shadows = true, Color = Color3.fromRGB(255, 245, 210), Parent = supportProj })
	local a0 = creer("Attachment", { Parent = supportProj })
	local a1 = creer("Attachment", { Position = Vector3.new(0, 0, -60), Parent = supportProj })
	local cone = creer("Beam", { Attachment0 = a0, Attachment1 = a1, Width0 = 1, Width1 = 16, LightEmission = 1, LightInfluence = 0,
		Color = ColorSequence.new(Color3.fromRGB(255, 245, 210)), Transparency = NumberSequence.new(1), FaceCamera = true, Parent = supportProj })
	local dernierEnvoi = 0
	RunService.RenderStepped:Connect(function(dt)
		local allumee = exterieur:GetAttribute("Alimentation") ~= false and (lumiere == nil or lumiere.Brightness > 0.05)

		local projecteur = exterieur:GetAttribute("Projecteur") == true and allumee
		local direction = exterieur:GetAttribute("ProjecteurDir")
		if typeof(direction) ~= "Vector3" or direction.Magnitude < 0.1 then direction = exterieur:GetPivot().LookVector end
		supportProj.CFrame = CFrame.lookAt(lampe.Position, lampe.Position + direction)
		spot.Brightness += ((projecteur and 8 or 0) - spot.Brightness) * math.min(dt * 6, 1)
		cone.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, projecteur and 0.86 or 1), NumberSequenceKeypoint.new(1, 1) })
		-- Le pilote vise avec sa caméra
		if projecteur and joueur:GetAttribute("TardisPilote_" .. def.Nom) == true and os.clock() - dernierEnvoi > 0.12 then
			dernierEnvoi = os.clock()
			remote:FireServer("ProjecteurDir", camera.CFrame.LookVector)
		end
	end)
end

--------------------------------------------------------------------
-- 5) Ombre annonciatrice, air qui ondule, distorsion d'écran, givre d'urgence
--------------------------------------------------------------------
do
	local ombre, air, givre = nil, nil, nil
	local flou = creer("BlurEffect", { Size = 0, Name = "TardisDistorsion", Parent = Lighting })
	local teinte = creer("ColorCorrectionEffect", { Name = "TardisDistorsionTeinte", Parent = Lighting })
	local function solSous(position)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local exclus = { exterieur, interieur }
		if ombre then table.insert(exclus, ombre) end
		if air then table.insert(exclus, air) end
		params.FilterDescendantsInstances = exclus
		return workspace:Raycast(position + Vector3.new(0, 1, 0), Vector3.new(0, -12, 0), params)
	end
	RunService.RenderStepped:Connect(function(dt)
		local p, remat = progressionAnimation()
		local base = exterieur:GetPivot().Position
		-- Ombre au sol avant l'apparition, et air qui ondule pendant la matérialisation
		if p and remat then
			local sol = solSous(base)
			if sol then
				if not ombre then
					ombre = partTemporaire({ Name = "TardisOmbre", Shape = Enum.PartType.Cylinder, Color = Color3.new(0, 0, 0), Material = Enum.Material.SmoothPlastic,
						Transparency = 1, Size = Vector3.new(0.05, 1, 1) })
				end
				local taille = exterieur:GetExtentsSize()
				local diametre = math.max(taille.X, taille.Z) * 1.3
				ombre.Size = Vector3.new(0.05, diametre, diametre)
				ombre.CFrame = CFrame.new(sol.Position + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, 0, math.pi / 2)
				ombre.Transparency = 0.45 + 0.5 * math.clamp(p * 1.5, 0, 1) -- bien visible au début, s'efface quand le TARDIS apparaît
				if not air then
					air = partTemporaire({ Name = "TardisAir", Transparency = 1, Size = Vector3.new(taille.X * 1.6, 0.5, taille.Z * 1.6) })
					local emetteur = creer("ParticleEmitter", { Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(Color3.fromRGB(235, 245, 255)),
						Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.93), NumberSequenceKeypoint.new(0.5, 0.86), NumberSequenceKeypoint.new(1, 1) }),
						Size = NumberSequence.new(5, 9), Lifetime = NumberRange.new(1.2, 2), Speed = NumberRange.new(2, 4), Rate = 0, LightEmission = 0.4,
						Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-20, 20), Parent = air })
					emetteur.Name = "Emetteur"
				end
				air.CFrame = CFrame.new(sol.Position + Vector3.new(0, 1, 0))
				air.Emetteur.Rate = 6 * math.sin(p * math.pi)
			end
		else
			if ombre then ombre:Destroy() ombre = nil end
			if air then
				local vieux = air
				air = nil
				vieux.Emetteur.Enabled = false
				task.delay(2.5, function() vieux:Destroy() end)
			end
		end
		-- Distorsion d'écran : près du TARDIS, l'image se trouble pendant une démat / remat
		local intensite = 0
		if p then
			local distance = (camera.CFrame.Position - base).Magnitude
			intensite = math.sin(p * math.pi) * math.clamp(1 - distance / 45, 0, 1)
		end
		flou.Size += (intensite * 10 - flou.Size) * math.min(dt * 6, 1)
		teinte.Saturation += (-0.35 * intensite - teinte.Saturation) * math.min(dt * 6, 1)
		teinte.TintColor = teinte.TintColor:Lerp(Color3.new(1 - 0.08 * intensite, 1 - 0.04 * intensite, 1), math.min(dt * 6, 1))
	end)

	-- Givre : après un atterrissage d'urgence, la cabine se couvre de givre qui fond lentement
	exterieur:GetAttributeChangedSignal("Etat"):Connect(function()
		if exterieur:GetAttribute("Etat") ~= E.Pose or exterieur:GetAttribute("Urgence") ~= true then return end
		if givre then givre:Destroy() end
		givre = creer("Highlight", { FillColor = Color3.fromRGB(215, 240, 255), OutlineColor = Color3.fromRGB(240, 250, 255),
			FillTransparency = 0.55, OutlineTransparency = 0.35, DepthMode = Enum.HighlightDepthMode.Occluded, Parent = exterieur })
		local cristaux = creer("Sparkles", { SparkleColor = Color3.fromRGB(220, 240, 255), Parent = exterieur.PrimaryPart })
		animer(givre, 25, { FillTransparency = 1, OutlineTransparency = 1 }, Enum.EasingStyle.Linear)
		task.delay(6, function() cristaux.Enabled = false end)
		task.delay(10, function() cristaux:Destroy() end)
		local moi = givre
		task.delay(25.5, function() if givre == moi then givre:Destroy() givre = nil end end)
	end)
end

--------------------------------------------------------------------
-- 6) Impacts sur le bouclier anti-balles : une ondulation là où un tir touche la bulle
--------------------------------------------------------------------
do
	local function ondulation(bulle, position)
		local centre = bulle.Position
		local normale = (position - centre)
		if normale.Magnitude < 0.1 then return end
		normale = normale.Unit
		local anneau = partTemporaire({ Name = "TardisImpactBouclier", Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon,
			Color = bulle.Color, Transparency = 0.1, Size = Vector3.new(0.1, 0.6, 0.6),
			CFrame = CFrame.lookAt(position, position + normale) * CFrame.Angles(0, math.pi / 2, 0) })
		animer(anneau, 0.45, { Size = Vector3.new(0.1, 6, 6), Transparency = 1 })
		task.delay(0.5, function() anneau:Destroy() end)
	end
	local function surveiller(modele)
		local bulle = modele:WaitForChild("Bulle", 5)
		if not bulle then return end
		bulle.DescendantAdded:Connect(function(objet)
			-- Les systèmes d'armes attachent leurs impacts (Attachment, Decal...) à la pièce touchée
			local position = (objet:IsA("Attachment") and objet.WorldPosition) or (objet:IsA("BasePart") and objet.Position)
			if position then ondulation(bulle, position) end
		end)
		bulle.Touched:Connect(function(autre)
			if not autre:IsDescendantOf(exterieur) and not (autre.Parent and autre.Parent:FindFirstChildOfClass("Humanoid")) then
				ondulation(bulle, autre.Position)
			end
		end)
	end
	task.spawn(function()
		local dossier = exterieur:WaitForChild("Boucliers", 30)
		if not dossier then return end
		dossier.ChildAdded:Connect(function(modele)
			if modele.Name == "BouclierBalles" then task.spawn(surveiller, modele) end
		end)
		for _, modele in dossier:GetChildren() do
			if modele.Name == "BouclierBalles" then task.spawn(surveiller, modele) end
		end
	end)
end

--------------------------------------------------------------------
-- 7) Leurre : le faux TARDIS apparaît et disparaît en fondu
--------------------------------------------------------------------
workspace.ChildAdded:Connect(function(objet)
	if objet.Name ~= "TardisLeurre_" .. def.Nom then return end
	task.wait()
	local cibles = {}
	for _, part in objet:GetDescendants() do
		if part:IsA("BasePart") then
			cibles[part] = part.Transparency
			part.Transparency = 1
			animer(part, 2, { Transparency = cibles[part] })
		end
	end
	objet:GetAttributeChangedSignal("Disparition"):Connect(function()
		for part, _ in cibles do
			if part.Parent then animer(part, 2, { Transparency = 1 }) end
		end
	end)
end)

--------------------------------------------------------------------
-- 8) Rayon tracteur : un faisceau entre le TARDIS et l'objet attiré
--------------------------------------------------------------------
do
	local a0, a1, faisceau = nil, nil, nil
	local cible = exterieur:WaitForChild("TracteurCible", 30)
	if cible then
		RunService.RenderStepped:Connect(function()
			local objet = cible.Value
			local base = exterieur.PrimaryPart
			if objet and base then
				if not faisceau then
					a0 = creer("Attachment", { Parent = base })
					a1 = creer("Attachment", { Parent = objet })
					faisceau = creer("Beam", { Attachment0 = a0, Attachment1 = a1, Width0 = 2.5, Width1 = 1.2, LightEmission = 1, LightInfluence = 0,
						Color = ColorSequence.new(C.cyan, Color3.fromRGB(180, 240, 255)), Transparency = NumberSequence.new(0.35), FaceCamera = true,
						TextureSpeed = 2, Parent = base })
				elseif a1.Parent ~= objet then
					a1.Parent = objet
				end
				faisceau.Transparency = NumberSequence.new(0.3 + 0.15 * math.sin(os.clock() * 8))
			elseif faisceau then
				faisceau:Destroy() a0:Destroy() a1:Destroy()
				faisceau, a0, a1 = nil, nil, nil
			end
		end)
	end
end

--------------------------------------------------------------------
-- 9) Chocs en vol : étincelles et secousse (le pilote les signale, le serveur les relaie)
--------------------------------------------------------------------
local secousse = 0
exterieur:GetAttributeChangedSignal("ChocTemps"):Connect(function()
	local position = exterieur:GetAttribute("ChocPos")
	if typeof(position) ~= "Vector3" then return end
	local support = partTemporaire({ Name = "TardisChoc", Transparency = 1, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(position) })
	local etincelles = creer("ParticleEmitter", { Color = ColorSequence.new(Color3.fromRGB(255, 230, 150), Color3.fromRGB(255, 120, 30)), LightEmission = 1,
		Size = NumberSequence.new(0.25, 0), Speed = NumberRange.new(15, 30), Lifetime = NumberRange.new(0.3, 0.7), SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, -40, 0), Rate = 0, Parent = support })
	etincelles:Emit(60)
	task.delay(2, function() support:Destroy() end)
	local distance = (camera.CFrame.Position - position).Magnitude
	secousse = math.max(secousse, math.clamp(1 - distance / 80, 0, 1) * 0.8)
	if jeSuisDedans() then secousse = math.max(secousse, 0.6) end
end)
RunService:BindToRenderStep("TardisExtrasSecousse_" .. def.Nom, Enum.RenderPriority.Camera.Value + 3, function(dt)
	if secousse <= 0 then return end
	local force = secousse * 0.035
	camera.CFrame = camera.CFrame * CFrame.Angles((math.random() - 0.5) * force, (math.random() - 0.5) * force, (math.random() - 0.5) * force)
	secousse = math.max(0, secousse - dt * 1.4)
end)

--------------------------------------------------------------------
-- 10) Replay du dernier vol libre (menu) : on enregistre quand je pilote, on rejoue avec une caméra qui suit
--------------------------------------------------------------------
do
	local enregistrement = {}
	local dernierEchantillon = 0
	local rejoue = nil
	RunService.Heartbeat:Connect(function()
		if exterieur:GetAttribute("VolLibre") == joueur.UserId and not rejoue then
			if os.clock() - dernierEchantillon >= 0.1 then
				dernierEchantillon = os.clock()
				table.insert(enregistrement, exterieur:GetPivot())
				if #enregistrement > 6000 then table.remove(enregistrement, 1) end
			end
		end
	end)
	exterieur:GetAttributeChangedSignal("VolLibre"):Connect(function()
		if exterieur:GetAttribute("VolLibre") == joueur.UserId then table.clear(enregistrement) end
		UI.replayDisponible = #enregistrement > 10
	end)

	local bandeau = creer("ScreenGui", { Name = "TardisReplay", ResetOnSpawn = false, Enabled = false, Parent = joueur:WaitForChild("PlayerGui") })
	local etiquette = texte({ Text = "REPLAY DU DERNIER VOL  ·  Échap pour quitter", Font = UI.POLICE_GRAS, TextSize = 16, TextColor3 = C.cyan,
		TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 60), Size = UDim2.fromOffset(500, 24), Parent = bandeau })

	local function arreter()
		if not rejoue then return end
		if rejoue.fantome then rejoue.fantome:Destroy() end
		rejoue = nil
		bandeau.Enabled = false
		camera.CameraType = Enum.CameraType.Custom
		local humanoid = joueur.Character and joueur.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then camera.CameraSubject = humanoid end
		joueur:SetAttribute("TardisReplay", false)
	end
	local function demarrer()
		if rejoue or #enregistrement < 10 then joueur:SetAttribute("TardisReplay", false) return end
		exterieur.Archivable = true
		local fantome = exterieur:Clone()
		if not fantome then joueur:SetAttribute("TardisReplay", false) return end
		local boucliers = fantome:FindFirstChild("Boucliers")
		if boucliers then boucliers:Destroy() end
		for _, objet in fantome:GetDescendants() do
			if objet:IsA("LuaSourceContainer") or objet:IsA("Sound") or objet:IsA("ProximityPrompt") or objet:IsA("ClickDetector") or objet:IsA("Highlight")
				or objet:IsA("BillboardGui") or objet:IsA("ParticleEmitter") then
				objet:Destroy()
			elseif objet:IsA("BasePart") then
				objet.Anchored, objet.CanCollide, objet.CanQuery, objet.CanTouch = true, false, false, false
				if objet.Transparency < 1 then objet.Transparency = 0.3 end
			end
		end
		fantome.Name = "TardisReplayFantome"
		fantome.Parent = workspace
		rejoue = { fantome = fantome, index = 1, temps = 0, taille = exterieur:GetExtentsSize() }
		bandeau.Enabled = true
		camera.CameraType = Enum.CameraType.Scriptable
	end
	RunService.RenderStepped:Connect(function(dt)
		if not rejoue then return end
		rejoue.temps += dt
		local position = rejoue.temps / 0.1 + 1
		local i = math.floor(position)
		if i >= #enregistrement then arreter() return end
		local cf = enregistrement[i]:Lerp(enregistrement[i + 1], position - i)
		rejoue.fantome:PivotTo(cf)
		local centre = (cf * CFrame.new(0, rejoue.taille.Y / 2, 0)).Position
		local suivant = enregistrement[math.min(i + 8, #enregistrement)].Position
		local direction = (suivant - cf.Position)
		direction = direction.Magnitude > 1 and direction.Unit or cf.LookVector
		local cible = centre - direction * 24 + Vector3.new(0, 8, 0)
		camera.CFrame = camera.CFrame:Lerp(CFrame.lookAt(cible, centre), math.min(dt * 4, 1))
		etiquette.Text = string.format("REPLAY DU DERNIER VOL  ·  %s  ·  Échap pour quitter", UI.formatTemps(rejoue.temps))
	end)
	UserInputService.InputBegan:Connect(function(input, traite)
		if rejoue and input.KeyCode == Enum.KeyCode.Escape then arreter() end
	end)
	joueur:GetAttributeChangedSignal("TardisReplay"):Connect(function()
		if joueur:GetAttribute("TardisReplay") then demarrer() else arreter() end
	end)
end

--------------------------------------------------------------------
-- 13) Auto-destruction : compte à rebours (secousses, rouge, alarme) puis explosion
--------------------------------------------------------------------
do
	local enCours = nil -- { base = CFrame, rouge = Highlight, alarme = Sound }
	RunService.RenderStepped:Connect(function(dt)
		local debut = exterieur:GetAttribute("AutoDestructionDebut")
		if debut then
			local duree = exterieur:GetAttribute("AutoDestructionDuree") or 20
			local p = math.clamp((workspace:GetServerTimeNow() - debut) / duree, 0, 1)
			if not enCours then
				enCours = { base = exterieur:GetPivot() }
				enCours.rouge = creer("Highlight", { FillColor = Color3.fromRGB(255, 30, 30), OutlineColor = Color3.fromRGB(255, 120, 120),
					FillTransparency = 1, OutlineTransparency = 1, DepthMode = Enum.HighlightDepthMode.Occluded, Parent = exterieur })
				local assets = ReplicatedStorage:FindFirstChild("TardisAssets")
				local modele = assets and assets:FindFirstChild("Sons") and assets.Sons:FindFirstChild("Cloitre")
				if modele and exterieur.PrimaryPart then
					enCours.alarme = modele:Clone()
					enCours.alarme.Looped = true
					enCours.alarme.Parent = exterieur.PrimaryPart
					enCours.alarme:Play()
				end
			end
			-- Secousses de plus en plus fortes, teinte rouge qui pulse de plus en plus vite
			local force = 0.05 + p * p * 0.9
			local jitter = CFrame.new((math.random() - 0.5) * force, (math.random() - 0.5) * force * 0.4, (math.random() - 0.5) * force)
				* CFrame.Angles((math.random() - 0.5) * force * 0.06, 0, (math.random() - 0.5) * force * 0.06)
			if not exterieur:GetAttribute("Porteur") and not exterieur:GetAttribute("VolLibre") then exterieur:PivotTo(enCours.base * jitter) end
			local pulsation = 0.5 + 0.5 * math.sin(os.clock() * (4 + p * 20))
			enCours.rouge.FillTransparency = 1 - (0.2 + 0.5 * p) * pulsation
			enCours.rouge.OutlineTransparency = 1 - (0.4 + 0.6 * p)
			if enCours.alarme then enCours.alarme.PlaybackSpeed = 1 + p * 0.6 end
			local distance = (camera.CFrame.Position - enCours.base.Position).Magnitude
			if jeSuisDedans() or distance < 80 then secousse = math.max(secousse, p * 0.7) end
		elseif enCours then
			if not exterieur:GetAttribute("Detruit") then exterieur:PivotTo(enCours.base) end
			enCours.rouge:Destroy()
			if enCours.alarme then enCours.alarme:Destroy() end
			enCours = nil
		end
	end)

	-- Explosion : boule de feu, onde de choc, fumée, débris, flash et secousse
	exterieur:GetAttributeChangedSignal("Explosion"):Connect(function()
		if not exterieur:GetAttribute("Explosion") then return end
		local centre = exterieur:GetPivot().Position + Vector3.new(0, 4, 0)
		local boule = partTemporaire({ Name = "TardisExplosion", Shape = Enum.PartType.Ball, Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 230, 160), Size = Vector3.new(4, 4, 4), CFrame = CFrame.new(centre) })
		animer(boule, 0.5, { Size = Vector3.new(60, 60, 60), Color = Color3.fromRGB(255, 90, 20) }, Enum.EasingStyle.Quad)
		task.delay(0.5, function()
			animer(boule, 1.2, { Size = Vector3.new(90, 90, 90), Transparency = 1, Color = Color3.fromRGB(40, 20, 10) })
			task.delay(1.3, function() boule:Destroy() end)
		end)
		local onde = partTemporaire({ Name = "TardisOndeExplosion", Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 200, 120), Transparency = 0.2, Size = Vector3.new(0.4, 6, 6),
			CFrame = CFrame.new(centre - Vector3.new(0, 3.5, 0)) * CFrame.Angles(0, 0, math.pi / 2) })
		animer(onde, 1.4, { Size = Vector3.new(0.2, 220, 220), Transparency = 1 })
		task.delay(1.5, function() onde:Destroy() end)
		local lumiere = creer("PointLight", { Color = Color3.fromRGB(255, 150, 60), Brightness = 20, Range = 150, Parent = boule })
		animer(lumiere, 1.5, { Brightness = 0 })
		-- Fumée et débris
		local support = partTemporaire({ Name = "TardisFumeeExplosion", Transparency = 1, Size = Vector3.new(6, 6, 6), CFrame = CFrame.new(centre) })
		local fumee = creer("Smoke", { Color = Color3.fromRGB(40, 35, 30), Opacity = 0.7, RiseVelocity = 12, Size = 25, Parent = support })
		task.delay(3, function() fumee.Enabled = false end)
		task.delay(10, function() support:Destroy() end)
		for _ = 1, 24 do
			local debris = partTemporaire({ Name = "TardisDebris", Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 160, 60),
				Size = Vector3.new(0.4, 0.4, 0.4), CFrame = CFrame.new(centre) })
			debris.Anchored = false
			debris.CanCollide = true
			local direction = Vector3.new(math.random() - 0.5, math.random() * 0.8 + 0.2, math.random() - 0.5).Unit
			debris.AssemblyLinearVelocity = direction * (40 + math.random() * 50)
			local feu = creer("Fire", { Size = 2, Heat = 5, Parent = debris })
			task.delay(2, function() feu.Enabled = false end)
			task.delay(6, function() debris:Destroy() end)
		end
		-- Flash à l'écran et secousse selon la distance
		local distance = (camera.CFrame.Position - centre).Magnitude
		local intensite = math.clamp(1 - distance / 200, 0, 1)
		if intensite > 0 then
			local flash = creer("ScreenGui", { Name = "TardisFlashExplosion", ResetOnSpawn = false, IgnoreGuiInset = true, Parent = joueur:WaitForChild("PlayerGui") })
			local voile = creer("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 240, 200), BackgroundTransparency = 1 - intensite * 0.9,
				BorderSizePixel = 0, Parent = flash })
			animer(voile, 1.2, { BackgroundTransparency = 1 })
			task.delay(1.3, function() flash:Destroy() end)
			secousse = math.max(secousse, intensite * 1.5)
		end
	end)
end

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

--------------------------------------------------------------------
-- 17) Boucliers : invisibles, ils se révèlent au contact ou sous les tirs ; fissures selon l'énergie ; chute
--------------------------------------------------------------------
do
	local fissures = {}
	local function bullePrincipale()
		local dossier = exterieur:FindFirstChild("Boucliers")
		if not dossier then return nil end
		for _, nom in { "BouclierComplet", "BouclierBalles", "BouclierJoueurs" } do
			local modele = dossier:FindFirstChild(nom)
			local bulle = modele and modele:FindFirstChild("Bulle")
			if bulle then return bulle end
		end
		return nil
	end
	local function reveler(bulle, position, duree)
		-- Un disque de bouclier (ForceField) tangent à la bulle, là où elle est touchée
		local centre = bulle.Position
		local normale = position - centre
		if normale.Magnitude < 0.1 then return nil end
		normale = normale.Unit
		local rayon = bulle.Size.X / 2
		local patch = partTemporaire({ Name = "TardisBouclierPatch", Shape = Enum.PartType.Cylinder, Material = Enum.Material.ForceField, Color = bulle.Color,
			Transparency = 0.1, Size = Vector3.new(0.3, 7, 7), CFrame = CFrame.lookAt(centre + normale * rayon, centre + normale * (rayon + 1)) * CFrame.Angles(0, math.pi / 2, 0) })
		animer(patch, duree or 1.2, { Transparency = 1, Size = Vector3.new(0.3, 10, 10) })
		task.delay((duree or 1.2) + 0.1, function() patch:Destroy() end)
		return patch
	end
	-- Contact des joueurs : une partie du bouclier apparaît et les suit
	local patchsContact = {}
	RunService.Heartbeat:Connect(function()
		local bulle = bullePrincipale()
		if not bulle then
			for _, p in patchsContact do p:Destroy() end
			table.clear(patchsContact)
			return
		end
		local rayon = bulle.Size.X / 2
		for _, autre in Players:GetPlayers() do
			local racine = autre.Character and autre.Character:FindFirstChild("HumanoidRootPart")
			local patch = patchsContact[autre]
			if racine and math.abs((racine.Position - bulle.Position).Magnitude - rayon) < 3 then
				local normale = (racine.Position - bulle.Position).Unit
				local cf = CFrame.lookAt(bulle.Position + normale * rayon, bulle.Position + normale * (rayon + 1)) * CFrame.Angles(0, math.pi / 2, 0)
				if not patch then
					patch = partTemporaire({ Name = "TardisBouclierContact", Shape = Enum.PartType.Cylinder, Material = Enum.Material.ForceField, Color = bulle.Color,
						Transparency = 0.15, Size = Vector3.new(0.3, 8, 8), CFrame = cf })
					patchsContact[autre] = patch
				else
					patch.CFrame = cf
				end
			elseif patch then
				patch:Destroy()
				patchsContact[autre] = nil
			end
		end
	end)
	-- Impacts de tirs : révélation + fissures proportionnelles à l'énergie perdue
	local function majFissures(bulle)
		local energie = exterieur:GetAttribute("BouclierEnergie") or 100
		local voulu = math.floor((100 - energie) / 100 * 14)
		local rayon = bulle.Size.X / 2
		while #fissures < voulu do
			local direction = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5).Unit
			local longueur = 2 + math.random() * 4
			local f = partTemporaire({ Name = "TardisFissure", Material = Enum.Material.Neon, Color = Color3.fromRGB(10, 10, 20), Transparency = 0.2,
				Size = Vector3.new(0.12, 0.12, longueur), CFrame = CFrame.lookAt(bulle.Position + direction * rayon, bulle.Position + direction * rayon
					+ Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)) })
			table.insert(fissures, f)
		end
		while #fissures > voulu do table.remove(fissures):Destroy() end
	end
	exterieur:GetAttributeChangedSignal("BouclierImpactTemps"):Connect(function()
		local bulle = bullePrincipale()
		local position = exterieur:GetAttribute("BouclierImpact")
		if bulle and typeof(position) == "Vector3" then
			reveler(bulle, position, 0.8)
			majFissures(bulle)
		end
	end)
	exterieur:GetAttributeChangedSignal("BouclierEnergie"):Connect(function()
		local bulle = bullePrincipale()
		if bulle then majFissures(bulle) else for _, f in fissures do f:Destroy() end table.clear(fissures) end
	end)
	-- Chute du bouclier : il se brise en éclats
	exterieur:GetAttributeChangedSignal("BouclierBrise"):Connect(function()
		for _, f in fissures do f:Destroy() end
		table.clear(fissures)
		local centre = (exterieur:GetPivot() * CFrame.new(0, 4, 0)).Position
		for _ = 1, 30 do
			local eclat = partTemporaire({ Name = "TardisEclat", Material = Enum.Material.ForceField, Color = Color3.fromRGB(135, 206, 250), Size = Vector3.new(1.2, 1.2, 0.2),
				CFrame = CFrame.new(centre) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6) })
			eclat.Anchored = false
			eclat.CanCollide = true
			eclat.AssemblyLinearVelocity = Vector3.new(math.random() - 0.5, math.random() * 0.6 + 0.2, math.random() - 0.5).Unit * (15 + math.random() * 15)
			task.delay(3, function() eclat:Destroy() end)
		end
		UI.son("Alerte")
	end)
	task.spawn(function()
		local dossier = exterieur:WaitForChild("Boucliers", 30)
		if dossier then
			dossier.ChildRemoved:Connect(function()
				task.defer(function() if not bullePrincipale() then for _, f in fissures do f:Destroy() end table.clear(fissures) end end)
			end)
		end
	end)
end

--------------------------------------------------------------------
-- 18) Régénération (équipe "Le Voyageur") : énergie dorée qui jaillit de la tête et des mains, flash au moment du
-- changement d'apparence. Un seul exemplaire du script s'en occupe (celui du premier TARDIS).
--------------------------------------------------------------------
if def.Nom == Config.Tardis[1].Nom then
	local function surveillerRegeneration(personnage)
		local dejaJoue = nil -- une régénération n'est jouée qu'une fois (signal ou rattrapage)
		local function effets()
			local debut = personnage:GetAttribute("TardisRegeneration")
			if not debut or debut == dejaJoue then return end
			dejaJoue = debut
			local racine = personnage:FindFirstChild("HumanoidRootPart")
			local tete = personnage:FindFirstChild("Head")
			if not racine or not tete then return end
			local REG = Config.Regeneration or {}
			local duree = personnage:GetAttribute("TardisRegenerationDuree") or 8
			local style = personnage:GetAttribute("TardisRegenerationStyle") or 1
			local moi = personnage == joueur.Character
			local humanoid = personnage:FindFirstChildOfClass("Humanoid")

			-- Palette de la série : cœur blanc-jaune, flammes dorées, bords orange
			local BLANC_OR, OR_CLAIR, OR, ORANGE = Color3.fromRGB(255, 250, 225), Color3.fromRGB(255, 225, 120), Color3.fromRGB(255, 170, 50), Color3.fromRGB(255, 105, 20)
			local FEU = "rbxasset://textures/particles/fire_main.dds"
			local FUMEE = "rbxasset://textures/particles/smoke_main.dds"
			local ETINCELLE = "rbxasset://textures/particles/sparkles_main.dds"
			local aDetruire, flux, connexions = {}, {}, {}
			local function garder(objet) table.insert(aDetruire, objet) return objet end
			-- Un émetteur dont le débit suit l'intensité de la régénération (montée, éruption, dissipation)
			local function emetteur(parent, proprietes, debitMax, seuil)
				proprietes.Parent = parent
				proprietes.Rate = 0
				local e = garder(creer("ParticleEmitter", proprietes))
				table.insert(flux, { e = e, debit = debitMax, seuil = seuil or 0 })
				return e
			end
			-- Panache de flammes dorées (la signature de la série) : cœur clair, bords orange, qui grossit en montant
			local function panache(parent, direction, puissance, couleurs)
				couleurs = couleurs or { BLANC_OR, OR, ORANGE }
				emetteur(parent, { Texture = FEU, LightEmission = 1, LightInfluence = 0, EmissionDirection = direction, ZOffset = 1,
					Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, couleurs[1]), ColorSequenceKeypoint.new(0.4, couleurs[2]), ColorSequenceKeypoint.new(1, couleurs[3]) }),
					Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6 * puissance), NumberSequenceKeypoint.new(0.5, 1.6 * puissance), NumberSequenceKeypoint.new(1, 0.4 * puissance) }),
					Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.7, 0.3), NumberSequenceKeypoint.new(1, 1) }),
					Speed = NumberRange.new(9 * puissance, 15 * puissance), Lifetime = NumberRange.new(0.35, 0.7), Drag = 2,
					SpreadAngle = Vector2.new(14, 14), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-120, 120) }, 110 * puissance, 0.12)
				-- Le cœur : plus petit, presque blanc, très lumineux
				emetteur(parent, { Texture = FEU, LightEmission = 1, LightInfluence = 0, EmissionDirection = direction, ZOffset = 2,
					Color = ColorSequence.new(BLANC_OR, OR_CLAIR), Size = NumberSequence.new(0.5 * puissance, 0.1),
					Transparency = NumberSequence.new(0, 1), Speed = NumberRange.new(12 * puissance, 18 * puissance), Lifetime = NumberRange.new(0.2, 0.4),
					SpreadAngle = Vector2.new(6, 6), Rotation = NumberRange.new(0, 360) }, 70 * puissance, 0.2)
			end
			-- Points d'émission : au-dessus de la tête (vers le haut), au bout des mains (le long des bras écartés)
			local pointTete = garder(creer("Attachment", { Position = Vector3.new(0, tete.Size.Y * 0.4, 0), Parent = tete }))
			local mains = {}
			for _, nom in { "Left Arm", "Right Arm", "LeftHand", "RightHand" } do
				local bras = personnage:FindFirstChild(nom)
				if bras then table.insert(mains, garder(creer("Attachment", { Position = Vector3.new(0, -bras.Size.Y / 2, 0), Parent = bras }))) end
			end
			local function panachesTeteEtMains(puissance, couleurs)
				panache(pointTete, Enum.NormalId.Top, puissance, couleurs)
				for _, main in mains do panache(main, Enum.NormalId.Bottom, puissance * 0.8, couleurs) end
			end

			-- Lueur sous la peau, lumière qui inonde les environs
			local lueur = garder(creer("Highlight", { FillColor = OR, OutlineColor = OR_CLAIR, FillTransparency = 1, OutlineTransparency = 1,
				DepthMode = Enum.HighlightDepthMode.Occluded, Parent = personnage }))
			local lumiere = garder(creer("PointLight", { Color = OR, Brightness = 0, Range = 10, Shadows = true, Parent = racine }))
			local lumiereTete = garder(creer("PointLight", { Color = OR_CLAIR, Brightness = 0, Range = 8, Parent = tete }))
			-- Montée : de petites volutes dorées s'échappent des mains et du visage
			for _, point in { pointTete, table.unpack(mains) } do
				emetteur(point, { Texture = FUMEE, LightEmission = 1, Color = ColorSequence.new(OR_CLAIR, OR), Size = NumberSequence.new(0.2, 0.6),
					Transparency = NumberSequence.new(0.4, 1), Speed = NumberRange.new(0.5, 1.5), Lifetime = NumberRange.new(0.6, 1.2),
					SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, 2, 0) }, 25, 0)
			end
			-- Étincelles dorées tout autour
			local etincelles = emetteur(racine, { Texture = ETINCELLE, LightEmission = 1, Color = ColorSequence.new(BLANC_OR, OR),
				Size = NumberSequence.new(0.35, 0), Speed = NumberRange.new(6, 16), Lifetime = NumberRange.new(0.4, 0.9), SpreadAngle = Vector2.new(180, 180),
				Acceleration = Vector3.new(0, -12, 0), Drag = 1 }, 40, 0.3)

			local secousseMax, couleurFlash, couleurAmbiance = 0.5, BLANC_OR, OR
			local parImage = nil -- animation propre au style, appelée à chaque image : parImage(p, i, t)
			local sol = racine.Position - Vector3.new(0, (humanoid and humanoid.HipHeight or 0) + racine.Size.Y / 2 + 2, 0)

			if style == 2 then
				-- VOLCAN (10e → 11e Docteur) : une éruption si violente qu'elle ravage tout autour
				panachesTeteEtMains(1.8, { BLANC_OR, OR, Color3.fromRGB(255, 70, 10) })
				etincelles.Rate = 0
				for _, f in flux do if f.e == etincelles then f.debit = 160 end end
				-- Flammes au sol, autour du Voyageur
				for k = 1, 6 do
					local angle = k / 6 * math.pi * 2
					local foyer = garder(partTemporaire({ Name = "TardisRegenFoyer", Transparency = 1, Size = Vector3.new(1, 1, 1),
						CFrame = CFrame.new(sol + Vector3.new(math.cos(angle) * 5, 0.5, math.sin(angle) * 5)) }))
					local feu = garder(creer("Fire", { Size = 0.1, Heat = 12, Color = OR, SecondaryColor = ORANGE, Enabled = false, Parent = foyer }))
					task.delay(duree * (0.3 + k * 0.03), function() if feu.Parent then feu.Enabled = true animer(feu, 1, { Size = 6 }) end end)
				end
				-- Ondes de choc qui balaient le sol pendant l'éruption
				local prochaineOnde = 0.35
				parImage = function(p)
					if p >= prochaineOnde and p < 0.8 then
						prochaineOnde += 0.12
						local onde = partTemporaire({ Name = "TardisRegenOnde", Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = OR_CLAIR,
							Transparency = 0.25, Size = Vector3.new(0.2, 3, 3), CFrame = CFrame.new(sol + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2) })
						animer(onde, 0.9, { Size = Vector3.new(0.15, 46, 46), Transparency = 1, Color = ORANGE })
						task.delay(1, function() onde:Destroy() end)
					end
				end
				-- Au moment du changement : une explosion de lumière
				task.delay(duree * 0.55, function()
					if not racine.Parent then return end
					local boule = partTemporaire({ Name = "TardisRegenExplosion", Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = BLANC_OR,
						Transparency = 0.1, Size = Vector3.new(3, 3, 3), CFrame = racine.CFrame })
					animer(boule, 0.7, { Size = Vector3.new(34, 34, 34), Transparency = 1, Color = ORANGE })
					task.delay(0.8, function() boule:Destroy() end)
					etincelles:Emit(120)
				end)
				secousseMax, couleurAmbiance = 1.3, ORANGE
			elseif style == 3 then
				-- DOUCE (Docteur de la Guerre → 9e, 8e Docteur) : un voile de lumière tiède, sans violence
				for _, f in flux do f.debit *= 0.3 end
				emetteur(racine, { Texture = FUMEE, LightEmission = 1, LightInfluence = 0, Color = ColorSequence.new(BLANC_OR, OR_CLAIR),
					Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(0.5, 3.5), NumberSequenceKeypoint.new(1, 4.5) }),
					Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.55), NumberSequenceKeypoint.new(1, 1) }),
					Speed = NumberRange.new(0.3, 1), Lifetime = NumberRange.new(1.5, 2.5), SpreadAngle = Vector2.new(180, 180),
					Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-20, 20) }, 30, 0.1)
				emetteur(racine, { Texture = ETINCELLE, LightEmission = 1, Color = ColorSequence.new(BLANC_OR), Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.25), NumberSequenceKeypoint.new(1, 0) }),
					Speed = NumberRange.new(0.5, 2), Lifetime = NumberRange.new(1, 2), SpreadAngle = Vector2.new(180, 180) }, 50, 0.15)
				lueur.FillColor, lueur.OutlineColor = BLANC_OR, Color3.new(1, 1, 1)
				lumiere.Color = Color3.fromRGB(255, 220, 170)
				secousseMax, couleurFlash, couleurAmbiance = 0.1, Color3.fromRGB(255, 252, 240), Color3.fromRGB(255, 225, 180)
			elseif style == 4 then
				-- TOURBILLON (5e, 6e, 7e Docteurs) : des sphères qui tournoient en spirale, des couleurs qui défilent
				panachesTeteEtMains(0.8)
				local spheres = {}
				for k = 1, 6 do
					local sphere = garder(partTemporaire({ Name = "TardisRegenTourbillon", Shape = Enum.PartType.Ball, Material = Enum.Material.Neon,
						Color = OR, Size = Vector3.new(0.7, 0.7, 0.7), CFrame = racine.CFrame }))
					local a0 = creer("Attachment", { Position = Vector3.new(0, 0.3, 0), Parent = sphere })
					local a1 = creer("Attachment", { Position = Vector3.new(0, -0.3, 0), Parent = sphere })
					local trainee = creer("Trail", { Attachment0 = a0, Attachment1 = a1, Lifetime = 0.6, LightEmission = 1, FaceCamera = true,
						Transparency = NumberSequence.new(0, 1), WidthScale = NumberSequence.new(1, 0), Parent = sphere })
					spheres[k] = { part = sphere, trainee = trainee, lumiere = creer("PointLight", { Range = 8, Brightness = 2, Parent = sphere }) }
				end
				parImage = function(p, i, t)
					for k, s in spheres do
						local angle = t * (5 + k * 0.4) * (k % 2 == 0 and 1 or -1) + k
						local rayon = 3.2 - 1.2 * i
						local hauteur = math.sin(t * 2 + k) * 2.4
						s.part.CFrame = racine.CFrame * CFrame.new(math.cos(angle) * rayon, hauteur, math.sin(angle) * rayon)
						local couleur = Color3.fromHSV((t * 0.25 + k / 6) % 1, 0.75, 1)
						s.part.Color = couleur
						s.trainee.Color = ColorSequence.new(couleur)
						s.lumiere.Color = couleur
						s.part.Transparency = 1 - math.clamp(i * 1.5, 0, 1)
					end
					lumiere.Color = Color3.fromHSV((t * 0.25) % 1, 0.5, 1)
				end
				-- Pour celui qui se régénère : un kaléidoscope qui tourne devant les yeux
				if moi then
					local kaleido = garder(creer("ScreenGui", { Name = "TardisRegenKaleidoscope", ResetOnSpawn = false, IgnoreGuiInset = true, Parent = joueur.PlayerGui }))
					local cadre = creer("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(2.2, 2.2),
						BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = kaleido })
					local degrade = creer("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0.8, 1)),
						ColorSequenceKeypoint.new(0.2, Color3.fromHSV(0.12, 0.8, 1)), ColorSequenceKeypoint.new(0.4, Color3.fromHSV(0.33, 0.8, 1)),
						ColorSequenceKeypoint.new(0.6, Color3.fromHSV(0.55, 0.8, 1)), ColorSequenceKeypoint.new(0.8, Color3.fromHSV(0.8, 0.8, 1)),
						ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 0.8, 1)) }), Parent = cadre })
					local ancien = parImage
					parImage = function(p, i, t)
						ancien(p, i, t)
						degrade.Rotation = (t * 140) % 360
						cadre.Rotation = -(t * 40) % 360
						cadre.BackgroundTransparency = 1 - 0.45 * i
					end
				end
				secousseMax, couleurAmbiance = 0.6, Color3.fromRGB(255, 200, 255)
			elseif style == 5 then
				-- COLONNE (bigénération) : une colonne de lumière descend du ciel, un sceau gallifreyen s'allume au sol
				panachesTeteEtMains(1.1)
				local colonne = garder(partTemporaire({ Name = "TardisRegenColonne", Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon,
					Color = OR_CLAIR, Transparency = 1, Size = Vector3.new(240, 0.4, 0.4), CFrame = CFrame.new(sol + Vector3.new(0, 120, 0)) * CFrame.Angles(0, 0, math.pi / 2) }))
				local halo = garder(partTemporaire({ Name = "TardisRegenColonneHalo", Shape = Enum.PartType.Cylinder, Material = Enum.Material.ForceField,
					Color = OR, Transparency = 1, Size = Vector3.new(240, 1, 1), CFrame = colonne.CFrame }))
				-- Le sceau : des cercles concentriques et de petits cercles, tracés en lumière (écriture gallifreyenne)
				local sceau = garder(partTemporaire({ Name = "TardisRegenSceau", Transparency = 1, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(sol + Vector3.new(0, 0.15, 0)) }))
				local traits = {}
				local function cercle(centre, rayon, segments, largeur)
					local points = {}
					for k = 0, segments - 1 do
						local a = k / segments * math.pi * 2
						points[k + 1] = creer("Attachment", { Position = centre + Vector3.new(math.cos(a) * rayon, 0, math.sin(a) * rayon), Parent = sceau })
					end
					for k = 1, segments do
						table.insert(traits, creer("Beam", { Attachment0 = points[k], Attachment1 = points[k % segments + 1], Width0 = largeur, Width1 = largeur,
							LightEmission = 1, LightInfluence = 0, Segments = 1, Color = ColorSequence.new(OR_CLAIR), Transparency = NumberSequence.new(1),
							FaceCamera = false, Parent = sceau }))
					end
				end
				cercle(Vector3.zero, 7, 40, 0.25)
				cercle(Vector3.zero, 5.4, 32, 0.15)
				cercle(Vector3.zero, 2.4, 20, 0.2)
				for k = 1, 6 do
					local a = k / 6 * math.pi * 2
					cercle(Vector3.new(math.cos(a) * 6.2, 0, math.sin(a) * 6.2), 0.7 + (k % 3) * 0.25, 14, 0.12)
				end
				local socle = garder(partTemporaire({ Name = "TardisRegenSocle", Transparency = 1, Size = Vector3.new(5, 0.2, 5), CFrame = CFrame.new(sol) }))
				emetteur(socle, { Texture = ETINCELLE, LightEmission = 1, Color = ColorSequence.new(BLANC_OR, OR), Size = NumberSequence.new(0.5, 0),
					Speed = NumberRange.new(16, 28), Lifetime = NumberRange.new(1.5, 2.5), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(8, 8) }, 90, 0.15)
				parImage = function(p, i, t)
					local ouverture = math.clamp(i * 1.2, 0, 1)
					colonne.Size = Vector3.new(240, 0.4 + 6.5 * ouverture, 0.4 + 6.5 * ouverture)
					colonne.Transparency = 1 - 0.6 * ouverture
					halo.Size = Vector3.new(240, 1 + 12 * ouverture, 1 + 12 * ouverture)
					halo.Transparency = 1 - 0.5 * ouverture
					sceau.CFrame = CFrame.new(sol + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, t * 0.6, 0)
					local transparence = NumberSequence.new(1 - 0.9 * math.clamp(p / 0.3, 0, 1) * (p > 0.85 and (1 - p) / 0.15 or 1))
					for _, trait in traits do trait.Transparency = transparence end
				end
				secousseMax = 0.7
			else
				-- CLASSIQUE (9e → 10e Docteur) : la tête renversée, les bras écartés, les flammes dorées jaillissent
				panachesTeteEtMains(1.2)
			end

			-- Son (optionnel) : TardisAssets > Sons > Regeneration
			local assets = ReplicatedStorage:FindFirstChild("TardisAssets")
			local modeleSon = assets and assets:FindFirstChild("Sons") and assets.Sons:FindFirstChild("Regeneration")
			if modeleSon and modeleSon:IsA("Sound") then
				local son = garder(modeleSon:Clone())
				son.Parent = racine
				son:Play()
			end

			-- Ambiance : la lumière dorée envahit l'image de ceux qui sont proches
			local teinte = garder(creer("ColorCorrectionEffect", { Name = "TardisRegenTeinte", TintColor = Color3.new(1, 1, 1), Parent = Lighting }))
			local eclat = garder(creer("BloomEffect", { Name = "TardisRegenEclat", Intensity = 0, Size = 32, Threshold = 0.85, Parent = Lighting }))

			-- Caméra : celui qui se régénère voit la scène de l'extérieur, la caméra tourne lentement autour de lui
			local cinematique = moi and REG.CameraCinematique ~= false
			local angleDepart = 0
			if cinematique then
				local regard = racine.CFrame.LookVector
				angleDepart = math.atan2(regard.Z, regard.X)
				camera.CameraType = Enum.CameraType.Scriptable
			end
			local function rendreCamera()
				if cinematique then
					cinematique = false
					camera.CameraType = Enum.CameraType.Custom
					local h = joueur.Character and joueur.Character:FindFirstChildOfClass("Humanoid")
					if h then camera.CameraSubject = h end
				end
			end

			-- Courbe d'intensité : montée (0-15 %), éruption (15-55 %), changement et pleine puissance (55-80 %), dissipation
			local function intensite(p)
				if p < 0.15 then return 0.18 * (p / 0.15) end
				if p < 0.55 then local q = (p - 0.15) / 0.4 return 0.18 + 0.82 * q * q end
				if p < 0.8 then return 1 end
				if p < 1 then return 1 - (p - 0.8) / 0.2 end
				return 0
			end
			local depart = os.clock()
			local flashFait = false
			table.insert(connexions, RunService.RenderStepped:Connect(function()
				local t = os.clock() - depart
				local p = math.clamp(t / duree, 0, 1)
				local i = intensite(p)
				local vacillement = (p > 0.2 and p < 0.85) and (0.9 + 0.1 * math.noise(t * 7, 0.5, 0.5) * 2) or 1
				-- Débit des flammes et des étincelles
				for _, f in flux do f.e.Rate = (p >= f.seuil and p < 0.9) and f.debit * i * vacillement or 0 end
				-- Lueur et lumière
				lueur.FillTransparency = 1 - 0.7 * i
				lueur.OutlineTransparency = 1 - i
				lumiere.Brightness = 14 * i * vacillement
				lumiere.Range = 10 + 45 * i
				lumiereTete.Brightness = 6 * i
				-- Ambiance, selon la distance
				local distance = (camera.CFrame.Position - racine.Position).Magnitude
				local proche = math.clamp(1 - distance / 90, 0, 1) * i
				teinte.TintColor = Color3.new(1, 1, 1):Lerp(couleurAmbiance, 0.35 * proche)
				teinte.Brightness = 0.12 * proche
				eclat.Intensity = 1.4 * proche
				if proche > 0.05 then secousse = math.max(secousse, secousseMax * proche * (moi and 1 or 0.6)) end
				-- Caméra cinématique
				if cinematique and tete.Parent then
					local angle = angleDepart + p * 2.4
					local rayon = 9.5 - 2.5 * i
					local cible = tete.Position + Vector3.new(0, 0.3, 0)
					camera.CFrame = CFrame.lookAt(cible + Vector3.new(math.cos(angle) * rayon, 1.6 + 1.4 * i, math.sin(angle) * rayon), cible)
				end
				-- Au moment du changement : la lumière avale tout l'écran de celui qui se régénère
				if moi and not flashFait and p >= 0.5 then
					flashFait = true
					local flash = creer("ScreenGui", { Name = "TardisRegenerationFlash", ResetOnSpawn = false, IgnoreGuiInset = true, Parent = joueur.PlayerGui })
					local voile = creer("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = couleurFlash, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = flash })
					animer(voile, duree * 0.05, { BackgroundTransparency = 0 })
					task.delay(duree * 0.12, function() animer(voile, duree * 0.35, { BackgroundTransparency = 1 }) end)
					task.delay(duree * 0.6, function() flash:Destroy() end)
				end
				if parImage then parImage(p, i, t) end
				if p >= 1 or not racine.Parent then rendreCamera() end
			end))

			-- Lien Time Lord : les autres Voyageurs ressentent la régénération, où qu'ils soient
			if not moi and ReplicatedStorage:GetAttribute("TardisLienTimeLord") == true and joueur.Team
				and joueur.Team.Name == (REG.Equipe or "Le Voyageur") then
				local autre = Players:GetPlayerFromCharacter(personnage)
				local maRacine_ = maRacine()
				local distance = maRacine_ and math.floor((maRacine_.Position - racine.Position).Magnitude) or 0
				local lien = creer("ScreenGui", { Name = "TardisLienTimeLord", ResetOnSpawn = false, IgnoreGuiInset = true, Parent = joueur.PlayerGui })
				local voile = creer("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = OR_CLAIR, BackgroundTransparency = 0.75, BorderSizePixel = 0, Parent = lien })
				animer(voile, 1.5, { BackgroundTransparency = 1 })
				task.delay(1.6, function() lien:Destroy() end)
				secousse = math.max(secousse, 0.15)
				pcall(function()
					game:GetService("StarterGui"):SetCore("SendNotification", { Title = "Lien Time Lord",
						Text = string.format("%s se régénère (%d studs).", autre and autre.DisplayName or "Un Voyageur", distance), Duration = 6 })
				end)
			end

			-- Après : un souffle doré s'échappe du nouveau visage, les mains fument encore un moment
			task.delay(duree, function()
				rendreCamera()
				if tete.Parent then
					local souffle = creer("ParticleEmitter", { Texture = FUMEE, LightEmission = 1, Color = ColorSequence.new(OR_CLAIR, OR),
						Size = NumberSequence.new(0.3, 1.4), Transparency = NumberSequence.new(0.2, 1), Speed = NumberRange.new(3, 6),
						Lifetime = NumberRange.new(0.8, 1.3), SpreadAngle = Vector2.new(15, 15), EmissionDirection = Enum.NormalId.Front, Rate = 0, Parent = tete })
					task.delay(0.4, function() if souffle.Parent then souffle:Emit(35) end end)
					task.delay(2.5, function() souffle:Destroy() end)
				end
				for _, main in mains do
					if main.Parent then
						local volutes = creer("ParticleEmitter", { Texture = FUMEE, LightEmission = 1, Color = ColorSequence.new(OR_CLAIR, OR),
							Size = NumberSequence.new(0.15, 0.5), Transparency = NumberSequence.new(0.4, 1), Speed = NumberRange.new(0.5, 1.2),
							Lifetime = NumberRange.new(0.6, 1), SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, 2, 0), Rate = 14, Parent = main.Parent })
						task.delay(3.5, function() volutes.Enabled = false task.delay(1.2, function() volutes:Destroy() end) end)
					end
				end
				task.delay(1.2, function()
					for _, c in connexions do c:Disconnect() end
					for _, objet in aDetruire do if objet.Parent then objet:Destroy() end end
				end)
			end)
		end
		personnage:GetAttributeChangedSignal("TardisRegeneration"):Connect(effets)
		-- Corps neuf (après un corps disloqué) : la régénération a pu commencer avant qu'on l'écoute
		task.delay(0.3, effets)
	end
	for _, autre in Players:GetPlayers() do
		if autre.Character then surveillerRegeneration(autre.Character) end
		autre.CharacterAdded:Connect(surveillerRegeneration)
	end
	Players.PlayerAdded:Connect(function(autre) autre.CharacterAdded:Connect(surveillerRegeneration) end)

	-- Son propre personnage : pas de mort normale tant qu'il peut se régénérer (le serveur fait de même)
	local function surveillerMoi(personnage)
		local humanoid = personnage:WaitForChild("Humanoid", 10)
		if not humanoid then return end
		local function maj()
			local regenerateur = personnage:GetAttribute("TardisRegenerateur") == true and personnage:GetAttribute("TardisMortReelle") ~= true
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, not regenerateur)
			if personnage:GetAttribute("TardisMortReelle") == true then
				humanoid.Health = 0
				humanoid:ChangeState(Enum.HumanoidStateType.Dead)
			end
		end
		personnage:GetAttributeChangedSignal("TardisRegenerateur"):Connect(maj)
		personnage:GetAttributeChangedSignal("TardisMortReelle"):Connect(maj)
		maj()
		-- Le choix : se régénérer ou refuser (quelques secondes)
		personnage:GetAttributeChangedSignal("TardisRegenChoix"):Connect(function()
			local fin = personnage:GetAttribute("TardisRegenChoix")
			local ancien = joueur.PlayerGui:FindFirstChild("TardisRegenChoix")
			if ancien then ancien:Destroy() end
			if not fin then return end
			local gui = creer("ScreenGui", { Name = "TardisRegenChoix", ResetOnSpawn = false, IgnoreGuiInset = true, Parent = joueur.PlayerGui })
			creer("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 200, 100), BackgroundTransparency = 0.85, BorderSizePixel = 0, Parent = gui })
			local carte = creer("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.62), Size = UDim2.fromOffset(380, 0),
				AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.fond, BackgroundTransparency = 0.05, Parent = gui },
			{ UI.coin(14), UI.contour(C.ambre, 2, 0.2), UI.marges(14), UI.pile(8) })
			texte({ Text = "◆  L'ÉNERGIE DE RÉGÉNÉRATION MONTE", Font = UI.POLICE_GRAS, TextSize = 14, TextColor3 = C.ambre, LayoutOrder = 1, Parent = carte })
			texte({ Text = "Ne rien faire : tu te régénères. Refuser : c'est la fin de cette vie.", TextSize = 12, TextColor3 = C.texte, TextWrapped = true,
				AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = carte })
			local fond = creer("Frame", { Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = C.gris, LayoutOrder = 3, Parent = carte }, { UI.coin(99) })
			local barre = creer("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.ambre, Parent = fond }, { UI.coin(99) })
			local reste = math.max(fin - workspace:GetServerTimeNow(), 0.1)
			animer(barre, reste, { Size = UDim2.fromScale(0, 1) }, Enum.EasingStyle.Linear)
			local bouton = creer("TextButton", { Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = Color3.fromRGB(120, 35, 40), Text = "Refuser la régénération",
				Font = UI.POLICE_GRAS, TextSize = 13, TextColor3 = C.texte, LayoutOrder = 4, Parent = carte }, { UI.coin(8) })
			bouton:SetAttribute("CouleurBase", Color3.fromRGB(120, 35, 40))
			UI.rendreVivant(bouton)
			bouton.Activated:Connect(function()
				remote:FireServer("RefuserRegeneration")
				gui:Destroy()
			end)
			task.delay(reste + 0.2, function() if gui.Parent then gui:Destroy() end end)
		end)
	end
	joueur.CharacterAdded:Connect(surveillerMoi)
	if joueur.Character then task.spawn(surveillerMoi, joueur.Character) end

	-- Avatars sauvegardés : Roblox demande au joueur la permission de les lire, une fois, quand il rejoint l'équipe
	if (Config.Regeneration or {}).TenuesDuCompte ~= false then
		local AvatarEditorService = game:GetService("AvatarEditorService")
		local function notifier(texte)
			pcall(function()
				game:GetService("StarterGui"):SetCore("SendNotification", { Title = "Régénération", Text = texte, Duration = 6 })
			end)
		end
		local dejaDemande = false
		local function envoyerTenues()
			local equipe = (Config.Regeneration or {}).Equipe or "Le Voyageur"
			if dejaDemande or not (joueur.Team and joueur.Team.Name == equipe) then return end
			dejaDemande = true
			task.spawn(function()
				local okPrompt = pcall(function() AvatarEditorService:PromptAllowInventoryReadAccess() end)
				if not okPrompt then return end
				local resultat = AvatarEditorService.PromptAllowInventoryReadAccessCompleted:Wait()
				if resultat ~= Enum.AvatarPromptResult.Success then
					notifier("Sans accès à tes avatars, la régénération utilisera les tenues du jeu.")
					return
				end
				local okPages, pages = pcall(function() return AvatarEditorService:GetOutfits(Enum.OutfitSource.Created, Enum.OutfitType.Avatar) end)
				if not okPages or not pages then return end
				local ids = {}
				while #ids < 50 do
					for _, tenue in pages:GetCurrentPage() do
						if tenue.Id then table.insert(ids, tenue.Id) end
					end
					if pages.IsFinished then break end
					if not pcall(function() pages:AdvanceToNextPageAsync() end) then break end
				end
				if #ids > 0 then
					remote:FireServer("TenuesCompte", { ids = ids })
					notifier(string.format("%d avatar(s) de ton compte disponibles.", #ids))
				else
					notifier("Aucun avatar sauvegardé sur ton compte : la régénération utilisera les tenues du jeu.")
				end
			end)
		end
		joueur:GetPropertyChangedSignal("Team"):Connect(envoyerTenues)
		envoyerTenues()
	end
end

--------------------------------------------------------------------
-- 18 bis) Régénération à bord de ce TARDIS : la console crache des étincelles, la salle tremble
--------------------------------------------------------------------
exterieur:GetAttributeChangedSignal("RegenerationABord"):Connect(function()
	local console = interieur:FindFirstChild("Console")
	if console then
		local pieces = {}
		for _, objet in console:GetDescendants() do
			if objet:IsA("BasePart") and objet.Size.Magnitude > 0.8 then table.insert(pieces, objet) end
		end
		for _ = 1, math.min(6, #pieces) do
			local part = table.remove(pieces, math.random(#pieces))
			local point = creer("Attachment", { Parent = part })
			local etincelles = creer("ParticleEmitter", { Color = ColorSequence.new(Color3.fromRGB(255, 235, 150), Color3.fromRGB(255, 120, 30)), LightEmission = 1,
				Size = NumberSequence.new(0.25, 0), Speed = NumberRange.new(8, 18), Lifetime = NumberRange.new(0.3, 0.7), SpreadAngle = Vector2.new(90, 90),
				Acceleration = Vector3.new(0, -30, 0), Rate = 0, Parent = point })
			for k = 0, 3 do task.delay(k * 0.6, function() etincelles:Emit(25) end) end
			task.delay(4, function() point:Destroy() end)
		end
	end
	if jeSuisDedans() then secousse = math.max(secousse, 0.7) end
end)

--------------------------------------------------------------------
-- 19) Incendie de console, extincteur, arcs statiques, saleté, vibrations (stabilisateur), menu des techniciens
--------------------------------------------------------------------
do
	-- Flammes sur la console
	local flammes = {}
	local console = interieur:FindFirstChild("Console")
	local function majFlammes()
		local actif = exterieur:GetAttribute("Incendie") == true and not exterieur:GetAttribute("IncendieEteint")
		if actif and #flammes == 0 and console then
			local pieces = {}
			for _, objet in console:GetDescendants() do
				if objet:IsA("BasePart") and objet.Size.Magnitude > 1 then table.insert(pieces, objet) end
			end
			for _ = 1, math.min(3, #pieces) do
				local part = table.remove(pieces, math.random(#pieces))
				local feu = creer("Fire", { Size = 3, Heat = 8, Color = Color3.fromRGB(255, 150, 50), SecondaryColor = Color3.fromRGB(255, 60, 20), Parent = part })
				local fumee = creer("Smoke", { Color = Color3.fromRGB(60, 55, 50), Opacity = 0.3, RiseVelocity = 4, Size = 2, Parent = part })
				table.insert(flammes, feu)
				table.insert(flammes, fumee)
			end
		elseif not actif and #flammes > 0 then
			for _, f in flammes do f.Enabled = false task.delay(2, function() f:Destroy() end) end
			table.clear(flammes)
		end
	end
	exterieur:GetAttributeChangedSignal("Incendie"):Connect(majFlammes)
	exterieur:GetAttributeChangedSignal("IncendieEteint"):Connect(majFlammes)
	majFlammes()
	-- Jet d'extincteur
	exterieur:GetAttributeChangedSignal("ExtincteurJet"):Connect(function()
		local nom = string.match(exterieur:GetAttribute("ExtincteurJet") or "", "^(.-)\t")
		local autre = nom and Players:FindFirstChild(nom)
		local racine = autre and autre.Character and autre.Character:FindFirstChild("HumanoidRootPart")
		if not racine then return end
		local support = partTemporaire({ Name = "TardisExtincteur", Transparency = 1, Size = Vector3.new(0.5, 0.5, 0.5), CFrame = racine.CFrame * CFrame.new(0.8, 0.5, -1) })
		local jet = creer("ParticleEmitter", { Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(Color3.fromRGB(240, 245, 255)),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }), Size = NumberSequence.new(0.8, 3),
			Lifetime = NumberRange.new(0.6, 1), Speed = NumberRange.new(18, 26), SpreadAngle = Vector2.new(12, 12), EmissionDirection = Enum.NormalId.Front,
			Rate = 120, Parent = support })
		task.delay(1.2, function() jet.Enabled = false end)
		task.delay(3, function() support:Destroy() end)
	end)
	-- Arcs statiques
	exterieur:GetAttributeChangedSignal("ArcStatique"):Connect(function()
		local x, y, z = string.match(exterieur:GetAttribute("ArcStatique") or "", "^([%-%d%.]+)\t([%-%d%.]+)\t([%-%d%.]+)")
		if not x then return end
		local position = Vector3.new(tonumber(x), tonumber(y), tonumber(z))
		local support = partTemporaire({ Name = "TardisArc", Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(position) })
		local points = {}
		for i = 1, 6 do
			points[i] = creer("Attachment", { Position = Vector3.new((math.random() - 0.5) * 2.5, (i - 1) * 0.6 + (math.random() - 0.5), (math.random() - 0.5) * 2.5), Parent = support })
		end
		for i = 1, 5 do
			creer("Beam", { Attachment0 = points[i], Attachment1 = points[i + 1], Width0 = 0.15, Width1 = 0.15, LightEmission = 1, LightInfluence = 0, Segments = 1,
				Color = ColorSequence.new(Color3.fromRGB(190, 230, 255)), Transparency = NumberSequence.new(0.1), FaceCamera = true, Parent = support })
		end
		creer("PointLight", { Color = Color3.fromRGB(180, 220, 255), Brightness = 4, Range = 10, Parent = support })
		task.delay(0.25, function() support:Destroy() end)
	end)
	-- Saleté : un voile brun-gris sur la cabine, proportionnel ; le nettoyage fait briller
	local salete = creer("Highlight", { FillColor = Color3.fromRGB(70, 55, 40), OutlineColor = Color3.fromRGB(70, 55, 40), FillTransparency = 1, OutlineTransparency = 1,
		DepthMode = Enum.HighlightDepthMode.Occluded, Parent = exterieur })
	local function majSalete()
		local niveau = (exterieur:GetAttribute("Salete") or 0) / 100
		salete.FillTransparency = 1 - 0.5 * niveau
		salete.OutlineTransparency = 1 - 0.3 * niveau
	end
	exterieur:GetAttributeChangedSignal("Salete"):Connect(majSalete)
	majSalete()
	exterieur:GetAttributeChangedSignal("Nettoyage"):Connect(function()
		if exterieur.PrimaryPart then
			local eclat = creer("Sparkles", { SparkleColor = Color3.fromRGB(255, 255, 255), Parent = exterieur.PrimaryPart })
			task.delay(1.2, function() eclat:Destroy() end)
		end
	end)
	-- Vibrations de la cabine sans stabilisateur : pendant une démat / remat, l'extérieur tremble et les occupants bougent un peu
	local base = nil
	RunService.RenderStepped:Connect(function()
		local p = progressionAnimation()
		local actif = p ~= nil and exterieur:GetAttribute("Stabilisateur") == false and (exterieur:GetAttribute("Etat") or E.Pose) ~= E.Pose
			and not exterieur:GetAttribute("Porteur") and not exterieur:GetAttribute("VolLibre")
		if actif then
			base = base or exterieur:GetPivot()
			local f = 0.06
			exterieur:PivotTo(base * CFrame.new((math.random() - 0.5) * f, (math.random() - 0.5) * f, (math.random() - 0.5) * f))
			local racine = maRacine()
			local humanoid = joueur.Character and joueur.Character:FindFirstChildOfClass("Humanoid")
			if racine and jeSuisDedans() and not (humanoid and humanoid.Sit) and math.random() < 0.08 then
				racine.AssemblyLinearVelocity += Vector3.new((math.random() - 0.5) * 3, 0, (math.random() - 0.5) * 3)
			end
		elseif base then
			exterieur:PivotTo(base)
			base = nil
		end
	end)
	-- Menu des techniciens : quatre outils (affiché dès que le rôle est connu)
	local guiTechnicien = nil
	local function majTechnicien()
		local technicien = joueur:GetAttribute("TardisTechnicien_" .. def.Nom) == true
		if guiTechnicien then guiTechnicien.Enabled = technicien return end
		if not technicien then return end
		local gui = creer("ScreenGui", { Name = "TardisTechnicien_" .. def.Nom, ResetOnSpawn = false, Parent = joueur:WaitForChild("PlayerGui") })
		guiTechnicien = gui
		local panneau = creer("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 20, 1, -20), Size = UDim2.fromOffset(190, 0),
			AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.fond, BackgroundTransparency = 0.1, Parent = gui },
		{ UI.coin(12), UI.contour(C.ambre, 1, 0.4), UI.marges(10), UI.pile(5) })
		texte({ Text = "◆  TECHNICIEN", Font = UI.POLICE_GRAS, TextSize = 12, TextColor3 = C.ambre, LayoutOrder = 1, Parent = panneau })
		local ordre = 1
		for _, info in { { "Chiffon", "Chiffon (nettoyer la cabine)" }, { "Visseuse", "Visseuse (surcharge de vapeur)" }, { "CleMolette", "Clé à molette (vanne)" },
			{ "Extincteur", "Extincteur" }, { "Retirer", "Ranger les outils" } } do
			ordre += 1
			local b = creer("TextButton", { Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = info[1] == "Retirer" and C.fond or C.panneauClair, Text = info[2],
				Font = UI.POLICE_GRAS, TextSize = 11, TextColor3 = C.texte, LayoutOrder = ordre, Parent = panneau }, { UI.coin(7) })
			b:SetAttribute("CouleurBase", b.BackgroundColor3)
			UI.rendreVivant(b)
			b.Activated:Connect(function() remote:FireServer("Outil", { outil = info[1] }) end)
		end
	end
	joueur:GetAttributeChangedSignal("TardisTechnicien_" .. def.Nom):Connect(majTechnicien)
	majTechnicien()
end

--------------------------------------------------------------------
-- 20) Terrain réactif : l'effet d'atterrissage dépend du sol (sable, neige, métal, herbe, eau, pierre...)
--------------------------------------------------------------------
exterieur:GetAttributeChangedSignal("TerrainTemps"):Connect(function()
	local materiau = exterieur:GetAttribute("TerrainAtterrissage") or ""
	local base = exterieur:GetPivot().Position - Vector3.new(0, (exterieur.PrimaryPart and exterieur.PrimaryPart.Size.Y / 2 or 0) - 0.2, 0)
	local taille = exterieur:GetExtentsSize()
	local support = partTemporaire({ Name = "TardisTerrain", Transparency = 1, Size = Vector3.new(taille.X * 1.4, 0.4, taille.Z * 1.4), CFrame = CFrame.new(base) })
	local function emetteur(proprietes)
		proprietes.Parent = support
		proprietes.Rate = 0
		local e = creer("ParticleEmitter", proprietes)
		return e
	end
	local chaud = materiau == "Metal" or materiau == "DiamondPlate" or materiau == "CorrodedMetal" or materiau == "Basalt" or materiau == "CrackedLava"
	if materiau == "Sand" or materiau == "Sandstone" then
		emetteur({ Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(Color3.fromRGB(225, 200, 150)), Size = NumberSequence.new(2, 7),
			Transparency = NumberSequence.new(0.4, 1), Lifetime = NumberRange.new(1.5, 2.5), Speed = NumberRange.new(10, 18), SpreadAngle = Vector2.new(60, 60) }):Emit(70)
	elseif materiau == "Snow" or materiau == "Ice" or materiau == "Glacier" then
		emetteur({ Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(Color3.fromRGB(250, 252, 255)), Size = NumberSequence.new(1.5, 5),
			Transparency = NumberSequence.new(0.2, 1), Lifetime = NumberRange.new(1.5, 3), Speed = NumberRange.new(6, 12), SpreadAngle = Vector2.new(70, 70),
			Acceleration = Vector3.new(0, -4, 0) }):Emit(90)
	elseif chaud then
		-- Métal ou sol chaud : étincelles, "clang", et vapeur qui monte
		emetteur({ Color = ColorSequence.new(Color3.fromRGB(255, 230, 150), Color3.fromRGB(255, 120, 30)), LightEmission = 1, Size = NumberSequence.new(0.25, 0),
			Speed = NumberRange.new(12, 24), Lifetime = NumberRange.new(0.3, 0.7), SpreadAngle = Vector2.new(70, 70), Acceleration = Vector3.new(0, -40, 0) }):Emit(60)
		local vapeur = emetteur({ Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(Color3.fromRGB(235, 240, 245)), Size = NumberSequence.new(2, 6),
			Transparency = NumberSequence.new(0.6, 1), Lifetime = NumberRange.new(1, 2), Speed = NumberRange.new(4, 8), SpreadAngle = Vector2.new(20, 20) })
		vapeur.Rate = 40
		task.delay(2.5, function() vapeur.Enabled = false end)
		secousse = math.max(secousse, 0.3)
	elseif materiau == "Grass" or materiau == "LeafyGrass" or materiau == "Ground" or materiau == "Mud" then
		emetteur({ Color = ColorSequence.new(Color3.fromRGB(90, 140, 60), Color3.fromRGB(60, 90, 40)), Size = NumberSequence.new(0.3, 0.1), Speed = NumberRange.new(8, 16),
			Lifetime = NumberRange.new(0.8, 1.5), SpreadAngle = Vector2.new(60, 60), Acceleration = Vector3.new(0, -25, 0) }):Emit(50)
	elseif materiau ~= "Water" then
		emetteur({ Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(Color3.fromRGB(170, 165, 160)), Size = NumberSequence.new(2, 5),
			Transparency = NumberSequence.new(0.5, 1), Lifetime = NumberRange.new(1, 2), Speed = NumberRange.new(8, 14), SpreadAngle = Vector2.new(60, 60) }):Emit(40)
	end
	task.delay(5, function() support:Destroy() end)
end)

--------------------------------------------------------------------
-- 21) Décorations (Noël : guirlandes et neige ; Halloween : citrouille sur la lampe) et reflets des vitres
--------------------------------------------------------------------
do
	local pieces = {}       -- pièces locales de la décoration, avec leur décalage par rapport au pivot
	local emetteur = nil
	local decorationActive = nil
	local function nettoyer()
		for _, p in pieces do p.part:Destroy() end
		table.clear(pieces)
		if emetteur then emetteur.Parent:Destroy() emetteur = nil end
	end
	local function construire(nom)
		nettoyer()
		decorationActive = nom
		if not nom then return end
		local pivot = exterieur:GetPivot()
		local taille = exterieur:GetExtentsSize()
		local racineHalf = exterieur.PrimaryPart and exterieur.PrimaryPart.Size.Y / 2 or 0.5
		local haut = taille.Y - racineHalf - 0.3
		local function ajouter(part, decalage) table.insert(pieces, { part = part, decalage = decalage }) end
		if nom == "Noel" then
			-- Guirlande : des ampoules colorées tout autour du toit
			local couleurs = { Color3.fromRGB(255, 60, 60), Color3.fromRGB(60, 255, 90), Color3.fromRGB(255, 220, 60), Color3.fromRGB(80, 140, 255) }
			local n = 0
			local dx, dz = taille.X / 2 + 0.15, taille.Z / 2 + 0.15
			for i = 0, 19 do
				local f = i / 20
				local x, z
				if f < 0.25 then x, z = -dx + f * 4 * 2 * dx, -dz
				elseif f < 0.5 then x, z = dx, -dz + (f - 0.25) * 4 * 2 * dz
				elseif f < 0.75 then x, z = dx - (f - 0.5) * 4 * 2 * dx, dz
				else x, z = -dx, dz - (f - 0.75) * 4 * 2 * dz end
				n += 1
				local ampoule = partTemporaire({ Name = "TardisDecoration", Shape = Enum.PartType.Ball, Material = Enum.Material.Neon,
					Color = couleurs[n % #couleurs + 1], Size = Vector3.new(0.35, 0.35, 0.35), CFrame = pivot * CFrame.new(x, haut, z) })
				creer("PointLight", { Color = ampoule.Color, Brightness = 1.5, Range = 5, Parent = ampoule })
				ajouter(ampoule, CFrame.new(x, haut, z))
			end
			-- Neige qui tombe autour de la cabine
			local support = partTemporaire({ Name = "TardisNeige", Transparency = 1, Size = Vector3.new(taille.X + 14, 0.5, taille.Z + 14),
				CFrame = pivot * CFrame.new(0, taille.Y + 8, 0) })
			emetteur = creer("ParticleEmitter", { Color = ColorSequence.new(Color3.new(1, 1, 1)), Size = NumberSequence.new(0.25, 0.15),
				Transparency = NumberSequence.new(0.1, 0.6), Lifetime = NumberRange.new(4, 6), Speed = NumberRange.new(2, 3), Rate = 25,
				EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(15, 15), Acceleration = Vector3.new(0, -1, 0), Parent = support })
			ajouter(support, CFrame.new(0, taille.Y + 8, 0))
		elseif nom == "Halloween" then
			-- Citrouille sur la lampe du toit
			local positionLampe = CFrame.new(0, haut + 1.2, 0)
			if lampe then positionLampe = pivot:ToObjectSpace(lampe.CFrame) * CFrame.new(0, lampe.Size.Y / 2 + 0.7, 0) end
			local citrouille = partTemporaire({ Name = "TardisDecoration", Shape = Enum.PartType.Ball, Material = Enum.Material.SmoothPlastic,
				Color = Color3.fromRGB(255, 120, 20), Size = Vector3.new(1.6, 1.3, 1.6), CFrame = pivot * positionLampe })
			creer("PointLight", { Color = Color3.fromRGB(255, 140, 30), Brightness = 2.5, Range = 10, Parent = citrouille })
			ajouter(citrouille, positionLampe)
			local tige = partTemporaire({ Name = "TardisDecoration", Shape = Enum.PartType.Cylinder, Material = Enum.Material.Grass,
				Color = Color3.fromRGB(70, 110, 40), Size = Vector3.new(0.5, 0.25, 0.25), CFrame = pivot * positionLampe * CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, math.pi / 2) })
			ajouter(tige, positionLampe * CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, math.pi / 2))
			-- Les yeux et la bouche, découpés en noir
			for _, decalage in { CFrame.new(-0.35, 0.15, -0.75), CFrame.new(0.35, 0.15, -0.75), CFrame.new(0, -0.3, -0.78) } do
				local trait = partTemporaire({ Name = "TardisDecoration", Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 230, 120),
					Size = decalage.Y < 0 and Vector3.new(0.8, 0.15, 0.1) or Vector3.new(0.25, 0.25, 0.1), CFrame = pivot * positionLampe * decalage })
				ajouter(trait, positionLampe * decalage)
			end
		end
	end
	RunService.RenderStepped:Connect(function()
		local nom = exterieur:GetAttribute("Decoration")
		if nom ~= decorationActive then construire(nom) end
		if #pieces == 0 then return end
		local pivot = exterieur:GetPivot()
		local t = os.clock()
		for i, p in pieces do
			p.part.CFrame = pivot * p.decalage
			if decorationActive == "Noel" and p.part.Name == "TardisDecoration" then
				p.part.Transparency = (math.floor(t * 2 + i) % 3 == 0) and 0.7 or 0 -- clignotement
			end
		end
	end)

	-- Reflets des vitres : les fenêtres prennent la lumière de l'intérieur (couleur du thème) et deviennent réfléchissantes
	local vitres = {} -- [part] = { materiau, couleur, reflectance }
	for _, objet in exterieur:GetDescendants() do
		if objet:IsA("BasePart") and objet ~= exterieur.PrimaryPart and objet.Name ~= (Config.NomPortailExt or "Portail")
			and (objet.Material == Enum.Material.Glass or (objet.Transparency > 0.1 and objet.Transparency < 0.95)) then
			vitres[objet] = { materiau = objet.Material, couleur = objet.Color, reflectance = objet.Reflectance }
		end
	end
	local function majReflets()
		local actif = exterieur:GetAttribute("Reflets") == true
		local theme = nil
		for _, th in Config.Themes or {} do
			if th.nom == exterieur:GetAttribute("Theme") then theme = th end
		end
		local lumiere = theme and theme.leds or Color3.fromRGB(255, 220, 160)
		for part, origine in vitres do
			if part.Parent then
				part.Material = actif and Enum.Material.Glass or origine.materiau
				part.Reflectance = actif and 0.5 or origine.reflectance
				part.Color = actif and origine.couleur:Lerp(lumiere, 0.45) or origine.couleur
			end
		end
	end
	exterieur:GetAttributeChangedSignal("Reflets"):Connect(majReflets)
	exterieur:GetAttributeChangedSignal("Theme"):Connect(majReflets)
	majReflets()
end

--------------------------------------------------------------------
-- 22) Tablette en lecture seule : outil "TabletteTardis" (visiteurs et techniciens à bord)
--------------------------------------------------------------------
do
	local gui = creer("ScreenGui", { Name = "TardisTabletteLecture", ResetOnSpawn = false, Enabled = false, Parent = joueur:WaitForChild("PlayerGui") })
	local panneau = creer("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -20, 0.5, 0), Size = UDim2.fromOffset(360, 520),
		BackgroundColor3 = C.fond, BackgroundTransparency = 0.06, Parent = gui }, { UI.coin(16), UI.contour(C.cyan, 1.5, 0.3), UI.marges(14) })
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
	texte({ Text = "◆  " .. (info.Titre or "DÉCOUVERTE"), Font = UI.POLICE_GRAS, TextSize = 15, TextColor3 = C.ambre, LayoutOrder = 1, Parent = carte })
	texte({ Text = info.Texte or "", TextSize = 12, TextColor3 = C.texte, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = carte })
	UI.son("Notification")
	animer(carte, 0.6, { Position = UDim2.new(1, -20, 0, 90) }, Enum.EasingStyle.Back)
	task.delay(7, function()
		animer(carte, 0.4, { Position = UDim2.new(1, 360, 0, 90) }).Completed:Wait()
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