-- ServerScriptService > TardisExtras (Script)
-- Fonctionnalités supplémentaires du TARDIS, côté serveur :
--   balise de détresse (/balisehelp), rappel, minuterie, leurre, registre des passagers, alerte d'intrusion,
--   expulsion, zones interdites, zone sûre, thèmes de l'intérieur, projecteur, personnalisation (couleur, enseigne),
--   rayon tracteur, relais des chocs en vol, préférences des joueurs (favoris, touches, thème d'interface).
-- Il s'appuie sur TardisServeur à travers le pont "TardisInterne" (ServerStorage).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("TardisConfig"))
local def = Config.demarrerPourChaqueTardis(script) -- cet exemplaire ne s'occupe que d'un TARDIS (voir Config.Tardis)
local exterieur, interieur = Config.modeles(def)
local remote = ReplicatedStorage:WaitForChild(Config.canal(def, "TardisCommande"))
local pont = ServerStorage:WaitForChild(Config.canal(def, "TardisInterne"), 60)
if not pont then
	error("[TARDIS] TardisExtras : le pont TardisInterne n'existe pas. TardisServeur a-t-il une erreur (voir l'Output) ?")
end
local E = Config.Etats

-- Déclarées ici, définies plus bas (elles sont utilisées par le registre et les réglages)
local surPremiereEntree, publierCategories, roleDe, ajouterIncident, appliquerPieces, appliquerStyleConsole
local categories = {} -- [nom de destination] = index de catégorie

local function interne(action, ...)
	return pont:Invoke(action, ...)
end
local function estPilote(joueur)
	return interne("estPilote", joueur) == true
end
local function dire(joueur, message, ok)
	remote:FireClient(joueur, message, ok ~= false)
end
local function direAuxPilotes(message, ok)
	for _, autre in Players:GetPlayers() do
		if estPilote(autre) then dire(autre, message, ok) end
	end
end
-- Journal du TARDIS (V6.8) : TardisSupervision l'envoie au journal du jeu (Config.Journal)
local function journal(categorie, message)
	local evenements = ServerStorage:FindFirstChild("TardisEvenements")
	if evenements then evenements:Fire("Journal", { categorie = categorie, message = message, tardis = def.Nom }) end
end
local function heure()
	return os.date("%H:%M")
end
local function racineDe(joueur)
	return joueur.Character and joueur.Character:FindFirstChild("HumanoidRootPart")
end

--------------------------------------------------------------------
-- Sauvegarde légère des réglages du TARDIS (thème, couleur, enseigne) et des préférences des joueurs
--------------------------------------------------------------------
-- (V6.8.1 : sauvegarde versionnée, voir TardisSauvegarde ; l'ancien magasin TardisExtras_v1_* n'est que lu)
local magasin = require(script.Parent:WaitForChild("TardisSauvegarde")).ouvrir(
	((Config.Sauvegarde or {}).NomStoreExtras or "TardisExtras_v2") .. "_" .. def.Nom, "TardisExtras_v1_" .. def.Nom)
local illisibles = {} -- clés dont la lecture a échoué : on ne les écrase pas pendant la session
local function charger(cle)
	local valeur, lu = magasin:lire(cle)
	if not lu then illisibles[cle] = true end
	return valeur
end
local function enregistrer(cle, valeur)
	if illisibles[cle] then return end
	magasin:ecrire(cle, valeur) -- attend la fin (comme avant) : à la fermeture du serveur, rien n'est perdu
end

--------------------------------------------------------------------
-- Balise de détresse : /balisehelp
--------------------------------------------------------------------
local balises = {} -- [UserId] = { nom, position, fin }
local function publierBalises()
	local lignes = {}
	for id, b in balises do
		table.insert(lignes, string.format("%d\t%s\t%.1f\t%.1f\t%.1f\t%.1f", id, b.nom, b.position.X, b.position.Y, b.position.Z, b.fin))
	end
	exterieur:SetAttribute("Balises", table.concat(lignes, "\n"))
end
local function allumerBalise(joueur)
	local racine = racineDe(joueur)
	if not racine then return end
	if interne("dansInterieur", racine.Position) then
		dire(joueur, "Tu es déjà dans le TARDIS.", false)
		return
	end
	local duree = (Config.Balise or {}).Duree or 300
	balises[joueur.UserId] = { nom = joueur.DisplayName, position = racine.Position, fin = workspace:GetServerTimeNow() + duree }
	publierBalises()
	dire(joueur, "Balise de détresse allumée : les pilotes du TARDIS sont prévenus et peuvent venir te chercher.", true)
	direAuxPilotes("BALISE DE DÉTRESSE : " .. joueur.DisplayName .. " appelle le TARDIS (voir la mini-carte).", true)
	interne("jouer", "Cloitre", false)
end
-- Commande de chat (nouveau système) + ancien système en secours
pcall(function()
	local TextChatService = game:GetService("TextChatService")
	-- Un seul TardisExtras (celui du premier TARDIS) crée la commande ; elle prévient tous les TARDIS par un BindableEvent
	local diffusion = ServerStorage:FindFirstChild("TardisBaliseDiffusion")
	if not diffusion then
		diffusion = Instance.new("BindableEvent")
		diffusion.Name = "TardisBaliseDiffusion"
		diffusion.Parent = ServerStorage
		local commande = Instance.new("TextChatCommand")
		commande.Name = "TardisBalise"
		commande.PrimaryAlias = (Config.Balise or {}).Commande or "/balisehelp"
		-- (V6.8 : "/tardis" et "/tardis help" passent par TardisSupervision, qui prévient la balise ; les autres "/tardis …"
		-- sont des commandes du staff et n'allument plus de balise)
		commande.Parent = TextChatService
		commande.Triggered:Connect(function(source)
			local joueur = Players:GetPlayerByUserId(source.UserId)
			if joueur then diffusion:Fire(joueur) end
		end)
	end
	diffusion.Event:Connect(function(joueur) allumerBalise(joueur) end)
end)
local function surMessage(joueur, message)
	local alias = string.lower((Config.Balise or {}).Commande or "/balisehelp")
	local texte = string.lower(message)
	if texte == alias or texte == "/balise" then allumerBalise(joueur) end
end
task.spawn(function()
	-- Balises expirées, ou atteintes par le TARDIS
	while true do
		task.wait(2)
		local maintenant = workspace:GetServerTimeNow()
		local change = false
		for id, b in balises do
			local proche = (exterieur:GetAttribute("Etat") or E.Pose) == E.Pose and (exterieur:GetPivot().Position - b.position).Magnitude < 35
			if maintenant > b.fin or proche then
				balises[id] = nil
				change = true
				local joueur = Players:GetPlayerByUserId(id)
				if joueur then dire(joueur, proche and "Le TARDIS est arrivé." or "Ta balise s'est éteinte.", proche) end
			end
		end
		if change then publierBalises() end
	end
end)

--------------------------------------------------------------------
-- Registre des passagers, alerte d'intrusion, zone sûre
--------------------------------------------------------------------
local dedans = {}       -- [joueur] = true s'il est dans le TARDIS
local registre = {}     -- lignes "HH:MM\tnom\tentré|sorti"
local function ajouterRegistre(nom, action, role)
	table.insert(registre, 1, string.format("%s\t%s\t%s", heure(), nom .. (role and (" (" .. role .. ")") or ""), action))
	while #registre > 40 do table.remove(registre) end
	exterieur:SetAttribute("Registre", table.concat(registre, "\n"))
end
local function tabletteLectureSeule(joueur, donner)
	local sac = joueur:FindFirstChildOfClass("Backpack")
	local existante = (sac and sac:FindFirstChild("TabletteTardis")) or (joueur.Character and joueur.Character:FindFirstChild("TabletteTardis"))
	if donner and not existante and sac then
		local outil = Instance.new("Tool")
		outil.Name = "TabletteTardis"
		outil.ToolTip = "Tablette TARDIS (lecture seule)"
		outil.CanBeDropped = false
		local manche = Instance.new("Part")
		manche.Name = "Handle"
		manche.Size = Vector3.new(1.2, 0.15, 0.8)
		manche.Color = Color3.fromRGB(10, 25, 60)
		manche.Material = Enum.Material.SmoothPlastic
		manche.CanCollide = false
		manche.Parent = outil
		outil.Parent = sac
	elseif not donner and existante then
		existante:Destroy()
	end
end
local function zoneSure(joueur, actif)
	local personnage = joueur.Character
	if not personnage then return end
	local champ = personnage:FindFirstChild("TardisZoneSure")
	if actif and not champ then
		champ = Instance.new("ForceField")
		champ.Name = "TardisZoneSure"
		champ.Visible = false
		champ.Parent = personnage
	elseif not actif and champ then
		champ:Destroy()
	end
	if actif then
		local humanoid = personnage:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then humanoid.Health = humanoid.MaxHealth end
	end
end
task.spawn(function()
	while true do
		task.wait(0.5)
		if not (roleDe and surPremiereEntree and ajouterIncident) then continue end -- le script n'a pas fini de se charger
		for _, joueur in Players:GetPlayers() do
			local racine = racineDe(joueur)
			local estDedans = racine ~= nil and interne("dansInterieur", racine.Position) == true
			if estDedans ~= (dedans[joueur] == true) then
				dedans[joueur] = estDedans or nil
				ajouterRegistre(joueur.DisplayName, estDedans and "entré" or "sorti", roleDe(joueur))
				if estDedans then
					surPremiereEntree(joueur)
					-- Scan d'identité : affiché sur l'écran de la console pendant quelques secondes
					exterieur:SetAttribute("DerniereEntree", string.format("%s · %s · %s", joueur.DisplayName, roleDe(joueur), heure()))
				end
				-- Tablette en lecture seule pour ceux qui ne pilotent pas (visiteurs et techniciens)
				tabletteLectureSeule(joueur, estDedans and not estPilote(joueur))
				if estDedans and not estPilote(joueur) then
					ajouterIncident(joueur)
					exterieur:SetAttribute("Intrusion", joueur.DisplayName .. " · " .. heure())
					direAuxPilotes("INTRUSION : " .. joueur.DisplayName .. " est entré dans le TARDIS.", false)
					interne("jouer", "Cloitre", false)
				end
			end
			if Config.ZoneSure ~= false then zoneSure(joueur, estDedans) end
		end
	end
end)
Players.PlayerRemoving:Connect(function(joueur)
	if dedans[joueur] then
		ajouterRegistre(joueur.DisplayName, "parti")
		dedans[joueur] = nil
	end
	balises[joueur.UserId] = nil
	publierBalises()
end)

-- Expulsion : le joueur est déposé devant la porte, dehors
local function expulser(cible)
	local racine = racineDe(cible)
	if not racine then return false end
	local pivot = exterieur:GetPivot()
	racine.CFrame = CFrame.new(pivot.Position + pivot.LookVector * 5 + Vector3.new(0, 3.5, 0), pivot.Position + pivot.LookVector * 20)
	ajouterRegistre(cible.DisplayName, "expulsé")
	dire(cible, "Tu as été expulsé du TARDIS.", false)
	return true
end

--------------------------------------------------------------------
-- Zones restreintes : dans TARDIS_DESTINATIONS, le sous-dossier REFUSE (Config.ZoneRestreinte) contient des Parts.
-- Si le TARDIS s'y pose en mode normal, il redécolle et atterrit sur la destination accessible la plus proche.
-- Seule une matérialisation en URGENCE permet de s'y poser.
--------------------------------------------------------------------
local function dossierDestinations()
	return Config.dossierDestinations(false)
end
local function dansZone(nomDossier, position, marge)
	local dossier = dossierDestinations()
	local sousDossier = dossier and dossier:FindFirstChild(nomDossier)
	if not sousDossier then return nil end
	for _, zone in sousDossier:GetDescendants() do
		if zone:IsA("BasePart") then
			local local_ = zone.CFrame:PointToObjectSpace(position)
			local demi = zone.Size / 2 + Vector3.new(marge, marge, marge)
			if math.abs(local_.X) <= demi.X and math.abs(local_.Y) <= demi.Y and math.abs(local_.Z) <= demi.Z then return zone end
		end
	end
	return nil
end
local function destinationAccessibleLaPlusProche(position)
	local dossier = dossierDestinations()
	local accessibles = dossier and dossier:FindFirstChild(Config.ZoneAccessible or "ACCORDE")
	local meilleur, distanceMin = nil, math.huge
	for _, part in (accessibles or dossier or Instance.new("Folder")):GetDescendants() do
		if part:IsA("BasePart") and not dansZone(Config.ZoneRestreinte or "REFUSE", part.Position, 0) then
			local d = (part.Position - position).Magnitude
			if d < distanceMin then meilleur, distanceMin = part, d end
		end
	end
	return meilleur
end
local derniereUrgence = false
exterieur:GetAttributeChangedSignal("Etat"):Connect(function()
	local etat = exterieur:GetAttribute("Etat")
	if etat == E.Remat then derniereUrgence = Config.modeDe(exterieur) == "Urgence" end
	if etat ~= E.Pose then return end
	task.delay(2, function()
		if exterieur:GetAttribute("Etat") ~= E.Pose then return end
		local zone = dansZone(Config.ZoneRestreinte or "REFUSE", exterieur:GetPivot().Position, 6)
		if zone and not derniereUrgence then
			local repli = destinationAccessibleLaPlusProche(exterieur:GetPivot().Position)
			interne("alerter", "ZONE RESTREINTE : REPLI")
			direAuxPilotes("ZONE RESTREINTE (" .. zone.Name .. ") : seule une matérialisation d'urgence est possible ici. Repli vers "
				.. (repli and repli.Name or "nulle part") .. ".", false)
			task.wait(1)
			local ok = interne("decoller", false)
			if ok and repli then
				task.wait(3)
				interne("atterrir", repli.CFrame, repli.Name, false, repli, false)
			end
		end
	end)
end)

--------------------------------------------------------------------
-- Saisie : posé 15 minutes sans qu'aucun pilote n'agisse ni ne soit à bord, le TARDIS est "saisi" :
-- démat et remat en urgence vers un point dont le nom commence par "ZDC-"
--------------------------------------------------------------------
local derniereActionPilote = os.clock()
task.spawn(function()
	while true do
		task.wait(15)
		local etat, occupe = interne("etat")
		local piloteABord = false
		for autre in dedans do
			if estPilote(autre) then piloteABord = true end
		end
		if piloteABord then derniereActionPilote = os.clock() end
		if etat == E.Pose and not occupe and not exterieur:GetAttribute("VolLibre") and not exterieur:GetAttribute("Porteur")
			and os.clock() - derniereActionPilote > 15 * 60 then
			local zdc = {}
			for _, part in interne("listeDestinations") or {} do
				if string.sub(part.Name, 1, 4) == "ZDC-" then table.insert(zdc, part) end
			end
			if #zdc > 0 then
				derniereActionPilote = os.clock()
				local cible = zdc[math.random(#zdc)]
				interne("alerter", "SAISIE DU TARDIS")
				direAuxPilotes("SAISIE : le TARDIS, sans pilote depuis 15 minutes, est transféré en urgence vers " .. cible.Name .. ".", false)
				local ok = interne("decoller", true)
				if ok then
					task.wait(3)
					interne("atterrir", cible.CFrame, cible.Name, false, cible, true)
				end
			end
		end
	end
end)

--------------------------------------------------------------------
-- Anomalies secondaires : une entité (modèle avec Humanoid qui n'est pas un joueur) ou un joueur SCP
-- (équipe dont le nom commence par "SCP") qui s'approche fait vaciller les lumières autour du TARDIS.
-- À moins de 10 studs, le TARDIS se dématérialise et reste dans le vortex jusqu'à l'action d'un pilote.
--------------------------------------------------------------------
local function estEntiteHostile(humanoid)
	local modele = humanoid.Parent
	if not modele or not modele:IsA("Model") then return false end
	local joueur = Players:GetPlayerFromCharacter(modele)
	if joueur then
		return joueur.Team ~= nil and string.sub(string.upper(joueur.Team.Name), 1, 3) == "SCP"
	end
	return humanoid.Health > 0 and not modele:IsDescendantOf(exterieur) and not modele:IsDescendantOf(interieur)
end
local humanoids, prochainScan = {}, 0
local lumieresVacillantes = {}
local lumieresProches = nil -- les lumières autour du TARDIS, cherchées une fois quand une anomalie approche
task.spawn(function()
	while true do
		task.wait(1)
		if os.clock() > prochainScan then
			prochainScan = os.clock() + 10 -- parcours complet du workspace : rare (gros jeux)
			humanoids = {}
			for _, objet in workspace:GetDescendants() do
				if objet:IsA("Humanoid") then table.insert(humanoids, objet) end
			end
		end
		local etat, occupe = interne("etat")
		if etat ~= E.Pose or occupe or exterieur:GetAttribute("VolLibre") or exterieur:GetAttribute("Porteur") then continue end
		local centre = exterieur:GetPivot().Position
		local plusProche = math.huge
		for _, humanoid in humanoids do
			local racine = humanoid.Parent and humanoid.Parent:FindFirstChild("HumanoidRootPart") or humanoid.RootPart
			if racine and humanoid.Parent and estEntiteHostile(humanoid) then
				plusProche = math.min(plusProche, (racine.Position - centre).Magnitude)
			end
		end
		if plusProche < 45 then
			-- Les lumières proches vacillent (puis sont remises)
			-- Les lumières proches : cherchées une seule fois, par les pièces autour (pas tout le workspace)
			if not lumieresProches then
				lumieresProches = {}
				for _, part in workspace:GetPartBoundsInRadius(centre, 45) do
					if not part:IsDescendantOf(interieur) then
						for _, objet in part:GetDescendants() do
							if objet:IsA("Light") then table.insert(lumieresProches, objet) end
						end
					end
				end
			end
			for _, objet in lumieresProches do
				if objet.Parent then
					lumieresVacillantes[objet] = lumieresVacillantes[objet] or objet.Brightness
					objet.Brightness = lumieresVacillantes[objet] * (math.random() < 0.4 and 0.1 or (0.5 + math.random() * 0.5))
				end
			end
		else
			for objet, brillance in lumieresVacillantes do
				if objet.Parent then objet.Brightness = brillance end
			end
			table.clear(lumieresVacillantes)
			lumieresProches = nil
		end
		if plusProche < 10 then
			interne("alerter", "ANOMALIE : DÉMATÉRIALISATION")
			direAuxPilotes("ANOMALIE DÉTECTÉE à moins de 10 studs : le TARDIS se dématérialise et attend dans le vortex.", false)
			for objet, brillance in lumieresVacillantes do
				if objet.Parent then objet.Brightness = brillance end
			end
			table.clear(lumieresVacillantes)
			interne("decoller", true)
		end
	end
end)

--------------------------------------------------------------------
-- Scan d'identité et dossiers d'incident
--------------------------------------------------------------------
local incidents = {} -- { heure, nom, role, position } : une fiche par intrusion (40 max)
roleDe = function(joueur)
	if estPilote(joueur) then return "pilote" end
	if joueur:GetAttribute("TardisTechnicien_" .. def.Nom) then return "technicien" end
	if joueur.Team then return joueur.Team.Name end
	return "visiteur"
end
ajouterIncident = function(joueur)
	local p = exterieur:GetPivot().Position
	table.insert(incidents, 1, { heure = os.date("%d/%m %H:%M:%S"), nom = joueur.DisplayName, pseudo = joueur.Name, role = roleDe(joueur),
		position = string.format("%d, %d, %d", p.X, p.Y, p.Z), lieu = tostring(exterieur:GetAttribute("Position") or "?") })
	while #incidents > 40 do table.remove(incidents) end
	exterieur:SetAttribute("Incidents", HttpService:JSONEncode(incidents))
end

--------------------------------------------------------------------
-- Minuterie
--------------------------------------------------------------------
local jetonMinuterie = 0
local function armerMinuterie(joueur, secondes)
	jetonMinuterie += 1
	local moi = jetonMinuterie
	exterieur:SetAttribute("MinuterieFin", workspace:GetServerTimeNow() + secondes)
	dire(joueur, string.format("Minuterie : décollage dans %d s.", secondes), true)
	task.delay(secondes, function()
		if moi ~= jetonMinuterie then return end
		exterieur:SetAttribute("MinuterieFin", nil)
		local ok, erreur = interne("decoller", false)
		if not ok then direAuxPilotes("Minuterie : décollage impossible (" .. string.lower(erreur or "erreur") .. ").", false) end
	end)
end

--------------------------------------------------------------------
-- Leurre : un faux TARDIS apparaît ailleurs
--------------------------------------------------------------------
local leurre = nil
local function retirerLeurre()
	local ancien = leurre
	leurre = nil
	if not ancien then return end
	ancien:SetAttribute("Disparition", true)
	task.delay(2.5, function() ancien:Destroy() end)
end
local function creerLeurre(cible)
	retirerLeurre()
	exterieur.Archivable = true
	local copie = exterieur:Clone()
	if not copie then return false end
	local boucliers = copie:FindFirstChild("Boucliers")
	if boucliers then boucliers:Destroy() end
	for _, objet in copie:GetDescendants() do
		if objet:IsA("LuaSourceContainer") or objet:IsA("Sound") or objet:IsA("ProximityPrompt") or objet:IsA("ClickDetector")
			or objet:IsA("Highlight") or objet:IsA("ParticleEmitter") or objet:IsA("Attachment") then
			objet:Destroy()
		elseif objet:IsA("BasePart") then
			objet.Anchored = true
		end
	end
	for nom, _ in copie:GetAttributes() do copie:SetAttribute(nom, nil) end
	copie.Name = "TardisLeurre_" .. def.Nom
	copie:SetAttribute("Leurre", true)
	copie:PivotTo(cible)
	copie.Parent = workspace
	leurre = copie
	task.delay(90, function() if leurre == copie then retirerLeurre() end end)
	return true
end

--------------------------------------------------------------------
-- Personnalisation : couleur de la cabine, texte de l'enseigne
--------------------------------------------------------------------
local couleursOrigine = {} -- [part] = couleur d'origine
local textesOrigine = {}   -- [label] = texte d'origine
local function couleurReference()
	-- Couleur dominante de la cabine : celle du plus gros volume de pièces non neutres
	local volumes = {}
	for _, objet in exterieur:GetDescendants() do
		if objet:IsA("BasePart") and objet.Transparency < 0.5 and objet ~= exterieur.PrimaryPart then
			local c = objet.Color
			local cle = string.format("%d,%d,%d", math.floor(c.R * 16), math.floor(c.G * 16), math.floor(c.B * 16))
			volumes[cle] = volumes[cle] or { volume = 0, couleur = c }
			volumes[cle].volume += objet.Size.X * objet.Size.Y * objet.Size.Z
		end
	end
	local meilleur = nil
	for _, v in volumes do
		if not meilleur or v.volume > meilleur.volume then meilleur = v end
	end
	return meilleur and meilleur.couleur or Color3.fromRGB(0, 61, 165)
end
local reference = couleurReference()
local function distanceCouleur(a, b)
	return math.sqrt((a.R - b.R) ^ 2 + (a.G - b.G) ^ 2 + (a.B - b.B) ^ 2)
end
local function peindre(couleur)
	local tolerance = Config.ToleranceCouleur or 0.25
	local boucliers = exterieur:FindFirstChild("Boucliers")
	for _, objet in exterieur:GetDescendants() do
		if objet:IsA("BasePart") and objet ~= exterieur.PrimaryPart then
			if not (boucliers and objet:IsDescendantOf(boucliers)) then
				local origine = couleursOrigine[objet] or objet.Color
				if distanceCouleur(origine, reference) <= tolerance then
					couleursOrigine[objet] = origine
					objet.Color = couleur
				end
			end
		end
	end
	exterieur:SetAttribute("Couleur", couleur)
end
local function enseigne(texte)
	for _, objet in exterieur:GetDescendants() do
		if objet:IsA("TextLabel") then
			local origine = textesOrigine[objet] or objet.Text
			if string.find(string.upper(origine), "POLICE") then
				textesOrigine[objet] = origine
				objet.Text = texte
			end
		end
	end
	exterieur:SetAttribute("Enseigne", texte)
end

-- Réglages du TARDIS sauvegardés (thème, couleur, enseigne)
local function sauverReglages()
	local c = exterieur:GetAttribute("Couleur")
	enregistrer("reglages", {
		theme = exterieur:GetAttribute("Theme"),
		couleur = typeof(c) == "Color3" and { c.R, c.G, c.B } or nil,
		enseigne = exterieur:GetAttribute("Enseigne"),
		categories = categories,
		murs = exterieur:GetAttribute("CouleurMurs"),
		styleInterieur = exterieur:GetAttribute("StyleInterieur"),
		styleConsole = exterieur:GetAttribute("StyleConsole"),
		decoration = exterieur:GetAttribute("Decoration"),
		reflets = exterieur:GetAttribute("Reflets") == true,
	})
end

--------------------------------------------------------------------
-- Rayon tracteur (vol libre) : attire l'objet non ancré ou le joueur le plus proche sous le TARDIS,
-- avec une contrainte physique (AlignPosition), qui marche aussi sur les personnages des joueurs
--------------------------------------------------------------------
local cibleTracteur = Instance.new("ObjectValue")
cibleTracteur.Name = "TracteurCible"
cibleTracteur.Parent = exterieur
local contrainteTracteur, attacheTracteur = nil, nil
local debutRecherche = nil

local function relacherTracteur()
	if contrainteTracteur then contrainteTracteur:Destroy() end
	if attacheTracteur then attacheTracteur:Destroy() end
	contrainteTracteur, attacheTracteur = nil, nil
	if cibleTracteur.Value then cibleTracteur.Value = nil end
end

local function candidatTracteur(position, pilote)
	local portee = (Config.Tracteur or {}).Portee or 40
	local meilleur, distanceMin = nil, portee
	-- Joueurs (sauf le pilote et ceux qui sont dans le TARDIS)
	for _, autre in Players:GetPlayers() do
		local racine = racineDe(autre)
		if autre ~= pilote and racine and not interne("dansInterieur", racine.Position) then
			local d = (racine.Position - position).Magnitude
			if d < distanceMin then meilleur, distanceMin = racine, d end
		end
	end
	-- Objets non ancrés
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclus = { exterieur, interieur }
	for _, autre in Players:GetPlayers() do
		if autre.Character then table.insert(exclus, autre.Character) end
	end
	params.FilterDescendantsInstances = exclus
	for _, part in workspace:GetPartBoundsInRadius(position, portee, params) do
		local racine = part.AssemblyRootPart
		if racine and not racine.Anchored and string.sub(racine.Name, 1, 11) ~= "TardisLeurr" then
			local d = (racine.Position - position).Magnitude
			if d < distanceMin then meilleur, distanceMin = racine, d end
		end
	end
	return meilleur
end

RunService.Heartbeat:Connect(function()
	local pilote = exterieur:GetAttribute("VolLibre") and Players:GetPlayerByUserId(exterieur:GetAttribute("VolLibre"))
	if not exterieur:GetAttribute("Tracteur") or not pilote then
		relacherTracteur()
		debutRecherche = nil
		return
	end
	local cf = exterieur:GetAttribute("VolLibreCF")
	if typeof(cf) ~= "CFrame" then return end
	local point = cf.Position - Vector3.new(0, 10, 0)
	local portee = (Config.Tracteur or {}).Portee or 40
	local cible = cibleTracteur.Value
	if not (cible and cible.Parent and not cible.Anchored and (cible.Position - point).Magnitude < portee * 1.6) then
		relacherTracteur()
		cible = candidatTracteur(cf.Position, pilote)
		if cible then
			cibleTracteur.Value = cible
			attacheTracteur = Instance.new("Attachment")
			attacheTracteur.Name = "TardisTracteur"
			attacheTracteur.Parent = cible
			contrainteTracteur = Instance.new("AlignPosition")
			contrainteTracteur.Mode = Enum.PositionAlignmentMode.OneAttachment
			contrainteTracteur.Attachment0 = attacheTracteur
			contrainteTracteur.MaxForce = math.max(cible.AssemblyMass, 10) * 1500
			contrainteTracteur.MaxVelocity = (Config.Tracteur or {}).Force or 60
			contrainteTracteur.Responsiveness = 12
			contrainteTracteur.Position = point
			contrainteTracteur.Parent = cible
			if not (cible.Parent and cible.Parent:FindFirstChildOfClass("Humanoid")) then
				pcall(function() cible:SetNetworkOwner(nil) end)
			end
			debutRecherche = nil
		else
			-- Rien à portée : on prévient le pilote une fois
			debutRecherche = debutRecherche or os.clock()
			if os.clock() - debutRecherche > 1.5 then
				debutRecherche = math.huge
				dire(pilote, string.format("Rayon tracteur : rien à portée (objet non ancré ou joueur, à moins de %d studs sous le TARDIS).", portee), false)
			end
		end
	elseif contrainteTracteur then
		contrainteTracteur.Position = point
	end
end)
exterieur:GetAttributeChangedSignal("Tracteur"):Connect(function()
	if not exterieur:GetAttribute("Tracteur") then relacherTracteur() debutRecherche = nil end
end)

--------------------------------------------------------------------
-- Rôles temporaires : pilotes promus et bannissements, avec une durée (ou "session" : tant que le pilote
-- qui l'a décidé est connecté). Les durées fixes sont sauvegardées ; les sessions non.
--------------------------------------------------------------------
local roles = charger("roles")
if type(roles) ~= "table" then roles = {} end
roles.pilotes = type(roles.pilotes) == "table" and roles.pilotes or {}
roles.bans = type(roles.bans) == "table" and roles.bans or {}

local function entreeActive(entree)
	if type(entree) ~= "table" then return false end
	if entree.session then return Players:GetPlayerByUserId(entree.session) ~= nil end
	return type(entree.fin) == "number" and entree.fin > os.time()
end
local function appliquerRoles(joueur)
	local id = tostring(joueur.UserId)
	joueur:SetAttribute("TardisPiloteTemp_" .. def.Nom, entreeActive(roles.pilotes[id]))
	joueur:SetAttribute("TardisBanni_" .. def.Nom, entreeActive(roles.bans[id]))
	-- Technicien : liste de la config, ou accès donné par le jeu (Adonis, WL : TardisSupervision, V6.8)
	joueur:SetAttribute("TardisTechnicien_" .. def.Nom, Config.estTechnicienDe(def, joueur.UserId) or joueur:GetAttribute("TardisAccesTechnicien") == true)
	local technicien_quelque_part = false
	for _, autre in Config.Tardis do
		if joueur:GetAttribute("TardisTechnicien_" .. autre.Nom) == true then technicien_quelque_part = true end
	end
	joueur:SetAttribute("TardisTechnicien", technicien_quelque_part)
end
local function publierRoles()
	-- Liste pour le menu Équipage : "id<TAB>nom<TAB>type<TAB>fin" (fin = 0 pour une session)
	local lignes = {}
	for _, type_ in { "pilotes", "bans" } do
		for id, entree in roles[type_] do
			if entreeActive(entree) then
				table.insert(lignes, string.format("%s	%s	%s	%d", id, entree.nom or "?", type_, entree.fin or 0))
			else
				roles[type_][id] = nil
			end
		end
	end
	exterieur:SetAttribute("Roles", table.concat(lignes, "\n"))
	for _, joueur in Players:GetPlayers() do appliquerRoles(joueur) end
end
local function sauverRoles()
	local persistants = { pilotes = {}, bans = {} }
	for _, type_ in { "pilotes", "bans" } do
		for id, entree in roles[type_] do
			if not entree.session and entreeActive(entree) then persistants[type_][id] = entree end
		end
	end
	enregistrer("roles", persistants)
end
local function definirRole(type_, cible, donnees, auteur)
	local id = tostring(cible.UserId)
	if donnees.retirer then
		roles[type_][id] = nil
	else
		local entree = { nom = cible.DisplayName }
		if donnees.session then
			entree.session = auteur.UserId
		else
			local secondes = (tonumber(donnees.jours) or 0) * 86400 + (tonumber(donnees.heures) or 0) * 3600 + (tonumber(donnees.minutes) or 0) * 60
			if secondes <= 0 then return false end
			entree.fin = os.time() + math.floor(secondes)
		end
		roles[type_][id] = entree
	end
	publierRoles()
	sauverRoles()
	return true
end
local function suivreAccesTechnicien(joueur)
	joueur:GetAttributeChangedSignal("TardisAccesTechnicien"):Connect(function() appliquerRoles(joueur) end)
end
Players.PlayerAdded:Connect(function(joueur) appliquerRoles(joueur) suivreAccesTechnicien(joueur) end)
for _, joueur in Players:GetPlayers() do suivreAccesTechnicien(joueur) end
Players.PlayerRemoving:Connect(function() task.delay(0.5, publierRoles) end) -- fin des sessions du joueur qui part
task.spawn(function()
	while true do task.wait(30) publierRoles() end
end)
publierRoles()

--------------------------------------------------------------------
-- Statistiques (par pilote : temps de vol, voyages, passagers ; serveur : total des voyages),
-- découverte (première entrée), catégories de destinations
--------------------------------------------------------------------
local stats = {}             -- [UserId] = { tempsVol, voyages, passagers = { nom = true } }
local statsServeur = charger("stats_serveur")
if type(statsServeur) ~= "table" then statsServeur = { voyages = 0 } end
local decouvertes = {}       -- [UserId] = true quand le joueur a déjà eu le message
local dernierPilote = nil    -- le dernier pilote à avoir commandé un voyage
local statsModifiees = false

local function publierStats(joueur)
	local st = stats[joueur.UserId]
	if st then joueur:SetAttribute("TardisStats", HttpService:JSONEncode(st)) end
	exterieur:SetAttribute("StatsServeur", statsServeur.voyages or 0)
end
local function chargerStats(joueur)
	local st = charger("stats_" .. joueur.UserId)
	if type(st) ~= "table" then st = { tempsVol = 0, voyages = 0, passagers = {} } end
	st.passagers = type(st.passagers) == "table" and st.passagers or {}
	stats[joueur.UserId] = st
	decouvertes[joueur.UserId] = charger("decouverte_" .. joueur.UserId) == true
	publierStats(joueur)
end
local function sauverStats(joueur)
	local st = stats[joueur.UserId]
	if st then enregistrer("stats_" .. joueur.UserId, st) end
end
Players.PlayerAdded:Connect(chargerStats)
for _, joueur in Players:GetPlayers() do task.spawn(chargerStats, joueur) end
Players.PlayerRemoving:Connect(function(joueur)
	sauverStats(joueur)
	stats[joueur.UserId] = nil
end)
-- Temps de vol libre
RunService.Heartbeat:Connect(function(dt)
	local id = exterieur:GetAttribute("VolLibre")
	local st = id and stats[id]
	if st then
		st.tempsVol = (st.tempsVol or 0) + dt
		statsModifiees = true
	end
end)
-- Un voyage compte quand le TARDIS se pose après une matérialisation
local etatPrecedent = exterieur:GetAttribute("Etat")
exterieur:GetAttributeChangedSignal("Etat"):Connect(function()
	local etat = exterieur:GetAttribute("Etat")
	if etat == E.Pose and etatPrecedent == E.Remat then
		statsServeur.voyages = (statsServeur.voyages or 0) + 1
		local pilote = dernierPilote and Players:GetPlayerByUserId(dernierPilote)
		local st = pilote and stats[pilote.UserId]
		if st then
			st.voyages = (st.voyages or 0) + 1
			for autre in dedans do
				if autre ~= pilote then st.passagers[autre.DisplayName] = true end
			end
			publierStats(pilote)
		end
		exterieur:SetAttribute("StatsServeur", statsServeur.voyages)
		statsModifiees = true
	end
	etatPrecedent = etat
end)
task.spawn(function()
	while true do
		task.wait(120)
		if statsModifiees then
			statsModifiees = false
			for _, joueur in Players:GetPlayers() do sauverStats(joueur) publierStats(joueur) end
			enregistrer("stats_serveur", statsServeur)
		end
	end
end)
game:BindToClose(function()
	for _, joueur in Players:GetPlayers() do sauverStats(joueur) end
	enregistrer("stats_serveur", statsServeur)
	sauverRoles()
end)

-- Découverte : à la première entrée dans le TARDIS (une seule fois, sauvegardé)
surPremiereEntree = function(joueur)
	if decouvertes[joueur.UserId] then return end
	decouvertes[joueur.UserId] = true
	enregistrer("decouverte_" .. joueur.UserId, true)
	remote:FireClient(joueur, "__decouverte", true)
end

-- Catégories de destinations (étiquettes de couleur, enregistrées)
publierCategories = function()
	local lignes = {}
	for nom, index in categories do
		table.insert(lignes, string.format("%s	%d", nom, index))
	end
	exterieur:SetAttribute("Categories", table.concat(lignes, "\n"))
end

--------------------------------------------------------------------
-- Intérieur : rotor interactif, console de secours, murs, styles, jukebox, tenues
--------------------------------------------------------------------
-- Rotor interactif : un clic (pas de bouton) fait jaillir des étincelles et accélère le rotor 3 s
do
	local rotor = interieur:FindFirstChild(Config.NomRotor or "Rotor")
	if rotor then
		local pieces = rotor:IsA("BasePart") and { rotor } or {}
		for _, objet in rotor:GetDescendants() do
			if objet:IsA("BasePart") then table.insert(pieces, objet) end
		end
		local dernierClic = 0
		for _, piece in pieces do
			local clic = Instance.new("ClickDetector")
			clic.MaxActivationDistance = 12
			clic.Parent = piece
			clic.MouseClick:Connect(function(joueur)
				if os.clock() - dernierClic < 0.5 or exterieur:GetAttribute("Alimentation") == false then return end
				dernierClic = os.clock()
				exterieur:SetAttribute("RotorBoost", workspace:GetServerTimeNow())
				local point = Instance.new("Attachment")
				point.Parent = piece
				local etincelles = Instance.new("ParticleEmitter")
				etincelles.Color = ColorSequence.new(Color3.fromRGB(180, 230, 255), Color3.fromRGB(255, 200, 120))
				etincelles.LightEmission = 1
				etincelles.Size = NumberSequence.new(0.2, 0)
				etincelles.Speed = NumberRange.new(6, 14)
				etincelles.Lifetime = NumberRange.new(0.3, 0.7)
				etincelles.SpreadAngle = Vector2.new(180, 180)
				etincelles.Rate = 0
				etincelles.Parent = point
				etincelles:Emit(40)
				task.delay(2, function() point:Destroy() end)
				interne("jouer", "Reparation", false)
			end)
		end
	end
end

-- Console de secours : une pièce "ConsoleSecours" avec deux commandes (décoller, atterrir), réservées aux pilotes
do
	local console = interieur:FindFirstChild("ConsoleSecours", true)
	if console and console:IsA("BasePart") then
		local function prompt(nom, texte, action)
			local p = Instance.new("ProximityPrompt")
			p.Name = nom
			p.ActionText = texte
			p.ObjectText = "Console de secours"
			p.MaxActivationDistance = 8
			p.RequiresLineOfSight = false
			p.UIOffset = nom == "Decoller" and Vector2.new(0, -40) or Vector2.new(0, 40)
			p.Parent = console
			p.Triggered:Connect(function(joueur)
				if not estPilote(joueur) then return end
				task.spawn(action, joueur)
			end)
		end
		prompt("Decoller", "Décoller (secours)", function(joueur)
			local ok, erreur = interne("decoller", false)
			if not ok then dire(joueur, "Impossible : " .. string.lower(erreur or "erreur"), false) end
		end)
		prompt("Atterrir", "Atterrir (sélecteur)", function(joueur)
			local dest = interne("destinationChoisie")
			if not dest then dire(joueur, "Aucune destination au sélecteur.", false) return end
			local ok, erreur = interne("atterrir", dest.CFrame, dest.Name, false, dest, false)
			if not ok then dire(joueur, "Impossible : " .. string.lower(erreur or "erreur"), false) end
		end)
	end
end

-- Peinture des murs et styles : dossiers "Murs" et "Sol" de l'intérieur ; console : modèle "Console"
appliquerPieces = function(dossierNom, reglage)
	local dossier = interieur:FindFirstChild(dossierNom, true)
	if not dossier or not reglage then return end
	for _, objet in dossier:GetDescendants() do
		if objet:IsA("BasePart") then
			if reglage.couleur then objet.Color = reglage.couleur end
			if reglage.materiau then objet.Material = reglage.materiau end
		end
	end
	if dossier:IsA("BasePart") then
		if reglage.couleur then dossier.Color = reglage.couleur end
		if reglage.materiau then dossier.Material = reglage.materiau end
	end
end
local consoleOrigine = {} -- [part] = { couleur, materiau }
appliquerStyleConsole = function(style)
	local console = interieur:FindFirstChild("Console")
	if not console or not style then return end
	-- Couleur dominante de la console : seules les pièces de cette couleur changent (pas les écrans ni les leviers)
	local volumes = {}
	for _, objet in console:GetDescendants() do
		if objet:IsA("BasePart") and objet.Transparency < 0.5 then
			local origine = consoleOrigine[objet] and consoleOrigine[objet].couleur or objet.Color
			local cle = string.format("%d,%d,%d", math.floor(origine.R * 12), math.floor(origine.G * 12), math.floor(origine.B * 12))
			volumes[cle] = volumes[cle] or { volume = 0, parts = {} }
			volumes[cle].volume += objet.Size.X * objet.Size.Y * objet.Size.Z
			table.insert(volumes[cle].parts, objet)
		end
	end
	local meilleur = nil
	for _, v in volumes do
		if not meilleur or v.volume > meilleur.volume then meilleur = v end
	end
	for _, objet in meilleur and meilleur.parts or {} do
		consoleOrigine[objet] = consoleOrigine[objet] or { couleur = objet.Color, materiau = objet.Material }
		objet.Color = style.couleur
		objet.Material = style.materiau
	end
end

-- Tenues (casiers, régénération) : haut et bas appliqués au personnage
local function appliquerTenue(joueur, index)
	local tenue = (Config.Tenues or {})[index]
	local personnage = joueur.Character
	if not tenue or not personnage then return false end
	local shirt = personnage:FindFirstChildOfClass("Shirt") or Instance.new("Shirt")
	shirt.Name = "Shirt"
	shirt.ShirtTemplate = "rbxassetid://" .. tenue.shirt
	shirt.Parent = personnage
	local pants = personnage:FindFirstChildOfClass("Pants") or Instance.new("Pants")
	pants.Name = "Pants"
	pants.PantsTemplate = "rbxassetid://" .. tenue.pant
	pants.Parent = personnage
	personnage:SetAttribute("TardisTenue", index)
	return true
end

--------------------------------------------------------------------
-- Auto-destruction : 20 s de compte à rebours (secousses, rouge, alarme), puis explosion : joueurs, objets
-- et véhicules à moins de 50 studs. Le TARDIS "détruit" disparaît 7 minutes puis se reconstitue sur une
-- destination enregistrée, au hasard. Les décors ancrés ne sont jamais touchés.
--------------------------------------------------------------------
local autoDestruction = nil
local function pointArriveeInterieur()
	local arrivee = interieur:FindFirstChild(Config.NomArrivee or "Arrivee")
	if arrivee and arrivee:IsA("BasePart") then
		return arrivee.CFrame * CFrame.new(0, arrivee.Size.Y / 2 + 3, 0)
	end
	local portailInt = interieur:FindFirstChild(Config.NomPortailInt or "Portail")
	if portailInt then
		return portailInt.CFrame * CFrame.new(0, -portailInt.Size.Y / 2 + 3, 5) * CFrame.Angles(0, math.pi, 0)
	end
	return interieur:GetPivot() + Vector3.new(0, 4, 0)
end
local function renaitre()
	local liste = interne("listeDestinations") or {}
	local cible = #liste > 0 and liste[math.random(#liste)] or nil
	local cf = cible and cible.CFrame or exterieur:GetPivot()
	exterieur:PivotTo(cf)
	exterieur:SetAttribute("Detruit", false)
	interne("collisions", true)
	interne("setEtat", E.Vol)
	task.wait(0.5)
	interne("atterrir", cf, cible and cible.Name or "Reconstitution", false, cible, false)
	local pilote = autoDestruction and Players:GetPlayerByUserId(autoDestruction.pilote)
	autoDestruction = nil
	direAuxPilotes("Le TARDIS s'est reconstitué" .. (cible and (" : " .. cible.Name) or "") .. ".", true)
	if pilote then dire(pilote, "Ton TARDIS est de retour.", true) end
end
local function lancerAutoDestruction(pilote)
	if autoDestruction or exterieur:GetAttribute("Detruit") then return false, "déjà en cours" end
	local etat, occupe = interne("etat")
	if etat ~= E.Pose or occupe or exterieur:GetAttribute("VolLibre") or exterieur:GetAttribute("Porteur") then return false, "le TARDIS doit être posé" end
	autoDestruction = { pilote = pilote.UserId }
	exterieur:SetAttribute("AutoDestructionDuree", 20)
	exterieur:SetAttribute("AutoDestructionDebut", workspace:GetServerTimeNow())
	interne("alerter", "AUTO-DESTRUCTION ENGAGÉE")
	direAuxPilotes("AUTO-DESTRUCTION engagée par " .. pilote.DisplayName .. " : explosion dans 20 secondes.", false)
	journal("Sécurité", def.Nom .. " : auto-destruction engagée par " .. pilote.Name .. ".")
	interne("jouer", "Demat_Urg", true)
	task.delay(19, function()
		-- Les occupants sont éjectés dehors, dans la zone de l'explosion
		local pivot = exterieur:GetPivot()
		for autre in dedans do
			local racine = racineDe(autre)
			if racine then racine.CFrame = CFrame.new(pivot.Position + pivot.LookVector * 6 + Vector3.new(0, 3, 0)) end
		end
	end)
	task.delay(20, function()
		local pivot = exterieur:GetPivot()
		local centre = pivot.Position + Vector3.new(0, 4, 0)
		local explosion = Instance.new("Explosion")
		explosion.Position = centre
		explosion.BlastRadius = 1000000
		explosion.BlastPressure = 1000000
		explosion.DestroyJointRadiusPercent = 1 -- les objets et véhicules non ancrés se disloquent, les décors ancrés restent
		explosion.Visible = false -- les clients dessinent leur propre explosion
		explosion.Parent = workspace
		for _, autre in Players:GetPlayers() do
			local racine = racineDe(autre)
			local humanoid = autre.Character and autre.Character:FindFirstChildOfClass("Humanoid")
			if racine and humanoid and (racine.Position - centre).Magnitude <= 50 then humanoid.Health = 0 end
		end
		exterieur:SetAttribute("Explosion", workspace:GetServerTimeNow())
		exterieur:SetAttribute("AutoDestructionDebut", nil)
		exterieur:SetAttribute("Detruit", true)
		interne("collisions", false)
		direAuxPilotes("TARDIS DÉTRUIT. Il se reconstituera dans 5 minutes.", false)
		task.delay(5 * 60, renaitre)
	end)
	return true
end

--------------------------------------------------------------------
-- Invitation, interphone, balise "y aller"
--------------------------------------------------------------------
local invitations = {} -- [UserId invité] = { pilote = UserId, fin = os.clock() }
local function filtrer(joueur, texte)
	local ok, filtre = pcall(function()
		return TextService:FilterStringAsync(texte, joueur.UserId):GetNonChatStringForBroadcastAsync()
	end)
	return ok and filtre or nil
end
local function allerVersJoueur(pilote, cible, nomVoyage)
	local racine = racineDe(cible)
	if not racine then dire(pilote, "Joueur introuvable.", false) return end
	local angle = math.random() * math.pi * 2
	local position = racine.Position + Vector3.new(math.cos(angle) * 2, 0, math.sin(angle) * 2)
	local cf, _, _, _, erreur = interne("resoudreDestination", { position = CFrame.new(position) })
	if not cf then
		cf = interne("cibleJoueur", cible)
		if not cf then dire(pilote, "Impossible : " .. string.lower(erreur or "aucun sol"), false) return end
	end
	local ok, erreurDemat = interne("decoller", false)
	if not ok then dire(pilote, "Impossible : " .. string.lower(erreurDemat or "erreur"), false) return end
	task.wait(3)
	local okRemat, erreurRemat = interne("atterrir", cf, nomVoyage, false, nil, false)
	dire(pilote, okRemat and ("Arrivé près de " .. cible.DisplayName .. ".") or ("Impossible : " .. string.lower(erreurRemat or "erreur")), okRemat)
end

--------------------------------------------------------------------
-- Préférences des joueurs (favoris, touches, thème d'interface, sons)
--------------------------------------------------------------------
local prefs = {} -- [UserId] = texte JSON
local function chargerPrefs(joueur)
	local json = charger("prefs_" .. joueur.UserId)
	if type(json) == "string" then prefs[joueur.UserId] = json end
	joueur:SetAttribute("TardisPrefs", prefs[joueur.UserId] or "{}")
end
Players.PlayerAdded:Connect(chargerPrefs)
for _, joueur in Players:GetPlayers() do task.spawn(chargerPrefs, joueur) end
Players.PlayerRemoving:Connect(function(joueur)
	if prefs[joueur.UserId] then enregistrer("prefs_" .. joueur.UserId, prefs[joueur.UserId]) end
end)
game:BindToClose(function()
	for id, json in prefs do enregistrer("prefs_" .. id, json) end
	sauverReglages()
end)

--------------------------------------------------------------------
-- Carnet de bord RP (V6.9.1, ajout C7) : les pilotes et le copilote écrivent des notes par lieu.
-- Notes filtrées par Roblox, publiées dans l'attribut « Carnet » (JSON, la plus récente d'abord), sauvegardées.
--------------------------------------------------------------------
local REGLAGES_CARNET = Config.Carnet or {}
local carnet = {} -- { { lieu, auteur, id, texte, quand }, ... }
local dernierCarnet = {}
local carnetCharge = false
local function publierCarnet()
	exterieur:SetAttribute("Carnet", HttpService:JSONEncode(carnet))
end
local function sauverCarnet()
	if carnetCharge then enregistrer("carnet", carnet) end -- jamais avant d'avoir lu : on n'écrase pas les notes
end
task.spawn(function()
	local lu = charger("carnet")
	if type(lu) == "table" then
		for _, n in lu do
			if type(n) == "table" and type(n.lieu) == "string" and type(n.texte) == "string" then table.insert(carnet, n) end
		end
	end
	carnetCharge = not illisibles.carnet
	publierCarnet()
end)
Players.PlayerRemoving:Connect(function(joueur) dernierCarnet[joueur] = nil end)
local function peutEcrireCarnet(joueur)
	return estPilote(joueur) or exterieur:GetAttribute("Copilote") == joueur.UserId
end

--------------------------------------------------------------------
-- Commandes (le menu et la tablette envoient le même RemoteEvent que TardisServeur)
--------------------------------------------------------------------
local dernier = {}
remote.OnServerEvent:Connect(function(joueur, action, donnees)
	if Config.Debug and action ~= "VolLibre" and action ~= "ProjecteurDir" and action ~= "Prefs" then
		print(string.format("[TARDIS] Extras reçoit '%s' de %s (pilote : %s)", tostring(action), joueur.Name, tostring(estPilote(joueur))))
	end
	if action == "Prefs" then
		if typeof(donnees) == "string" and #donnees <= 6000 and pcall(HttpService.JSONDecode, HttpService, donnees) then
			prefs[joueur.UserId] = donnees
			joueur:SetAttribute("TardisPrefs", donnees)
		end
		return
	end
	if action == "ProjecteurDir" then
		if exterieur:GetAttribute("Projecteur") and estPilote(joueur) and typeof(donnees) == "Vector3" and donnees.Magnitude > 0.1 then
			exterieur:SetAttribute("ProjecteurDir", donnees.Unit)
		end
		return
	end
	if action == "VolLibreChoc" then
		if exterieur:GetAttribute("VolLibre") == joueur.UserId and typeof(donnees) == "Vector3" then
			exterieur:SetAttribute("ChocPos", donnees)
			exterieur:SetAttribute("ChocTemps", workspace:GetServerTimeNow())
		end
		return
	end
	if action == "InvitationReponse" then
		local inv = invitations[joueur.UserId]
		invitations[joueur.UserId] = nil
		if not inv or os.clock() > inv.fin then return end
		local pilote = Players:GetPlayerByUserId(inv.pilote)
		if typeof(donnees) == "table" and donnees.accepter then
			local racine = racineDe(joueur)
			if racine then racine.CFrame = pointArriveeInterieur() end
			if pilote then dire(pilote, joueur.DisplayName .. " a accepté ton invitation.", true) end
		elseif pilote then
			dire(pilote, joueur.DisplayName .. " a refusé ton invitation.", false)
		end
		return
	end
	if action == "Interphone" then
		-- Tout le monde peut parler à l'interphone : de l'intérieur, ou de dehors à moins de 12 studs de la porte
		local texte = typeof(donnees) == "table" and donnees.texte
		if typeof(texte) ~= "string" or #texte == 0 or #texte > 120 then return end
		local racine = racineDe(joueur)
		if not racine then return end
		local dedansMoi = dedans[joueur] == true
		if not dedansMoi and (racine.Position - exterieur:GetPivot().Position).Magnitude > 12 then return end
		local filtre = filtrer(joueur, texte)
		if filtre then
			exterieur:SetAttribute("Interphone", string.format("%s\t%s\t%s\t%.2f", dedansMoi and "dedans" or "dehors", joueur.DisplayName, filtre,
				workspace:GetServerTimeNow()))
		end
		return
	end
	if action == "Tenue" then
		-- Casiers : tout le monde peut changer de tenue à bord
		local index = typeof(donnees) == "table" and tonumber(donnees.index)
		if index and dedans[joueur] then appliquerTenue(joueur, math.floor(index)) end
		return
	end
	if action == "Tracteur" then
		if exterieur:GetAttribute("VolLibre") == joueur.UserId then
			exterieur:SetAttribute("Tracteur", not exterieur:GetAttribute("Tracteur"))
		end
		return
	end

	if action == "CarnetEcrire" or action == "CarnetEffacer" then
		-- Carnet de bord (V6.9.1) : pilotes et copilote
		if not peutEcrireCarnet(joueur) or typeof(donnees) ~= "table" then return end
		local maintenant = os.clock()
		if dernierCarnet[joueur] and maintenant - dernierCarnet[joueur] < 3 then
			dire(joueur, "Une note toutes les 3 secondes au plus.", false)
			return
		end
		dernierCarnet[joueur] = maintenant
		if action == "CarnetEffacer" then
			-- Effacer : l'auteur ou un pilote ; la date évite d'effacer une autre note si la liste a bougé
			local index = tonumber(donnees.index)
			local note = index and carnet[index]
			if not note or note.quand ~= donnees.quand then dire(joueur, "Note introuvable (le carnet a changé).", false) return end
			if note.id ~= joueur.UserId and not estPilote(joueur) then dire(joueur, "Seul l'auteur ou un pilote peut effacer cette note.", false) return end
			table.remove(carnet, index)
			publierCarnet()
			task.spawn(sauverCarnet)
			dire(joueur, "Note effacée du carnet de bord.", true)
			return
		end
		local texte, lieu = donnees.texte, donnees.lieu
		local longueur = REGLAGES_CARNET.LongueurMax or 200
		if typeof(texte) ~= "string" or #texte < 2 or #texte > longueur * 2 or utf8.len(texte) == nil or utf8.len(texte) > longueur then return end
		if typeof(lieu) ~= "string" or #lieu == 0 then lieu = exterieur:GetAttribute("Position") or "Lieu inconnu" end
		lieu = string.sub(lieu, 1, 60)
		task.spawn(function()
			local filtre, lieuFiltre = filtrer(joueur, texte), filtrer(joueur, lieu)
			if not filtre or not lieuFiltre then dire(joueur, "Note refusée par le filtre de Roblox.", false) return end
			table.insert(carnet, 1, { lieu = lieuFiltre, auteur = joueur.DisplayName, id = joueur.UserId, texte = filtre, quand = os.time() })
			while #carnet > (REGLAGES_CARNET.Max or 80) do table.remove(carnet) end
			publierCarnet()
			sauverCarnet()
			journal("Carnet", string.format("%s : note de %s sur « %s ».", def.Nom, joueur.Name, lieuFiltre))
			dire(joueur, "Note ajoutée au carnet de bord : " .. lieuFiltre .. ".", true)
		end)
		return
	end
	if not estPilote(joueur) then
		if Config.Debug then print("[TARDIS] Extras : commande refusée, " .. joueur.Name .. " n'est pas pilote.") end
		return
	end
	-- Maintenance (V6.9.2) : seul le staff commande le TARDIS
	local maintenance = Config.bloqueParMaintenance(exterieur, joueur)
	if maintenance then
		dire(joueur, "Impossible : TARDIS en maintenance (" .. maintenance .. ").", false)
		return
	end
	derniereActionPilote = os.clock() -- pour la saisie
	if action == "Demat" or action == "Remat" or action == "Repositionner" or action == "Rappel" or action == "DematPorte" then
		dernierPilote = joueur.UserId -- pour les statistiques
	end
	local maintenant = os.clock()
	if (dernier[joueur] or 0) > maintenant - 0.5 then
		if Config.Debug then print("[TARDIS] Extras : commande ignorée (trop rapprochée de la précédente).") end
		return
	end
	dernier[joueur] = maintenant

	if action == "Promouvoir" or action == "Bannir" then
		local cible = typeof(donnees) == "table" and Players:GetPlayerByUserId(donnees.joueur or 0)
		if not cible or cible == joueur then return end
		if action == "Bannir" and Config.estPiloteDe(def, cible.UserId) then
			dire(joueur, "Impossible de bannir un pilote de la config.", false)
			return
		end
		local ok = definirRole(action == "Promouvoir" and "pilotes" or "bans", cible, donnees, joueur)
		if ok then
			journal("Rôles", string.format("%s : %s %s %s.", def.Nom, joueur.Name, donnees.retirer and "retire" or "donne",
				(action == "Promouvoir" and "le rôle de pilote à " or "un bannissement à ") .. cible.Name))
		end
		if ok then
			local verbe = donnees.retirer and (action == "Promouvoir" and "n'est plus pilote" or "n'est plus banni")
				or (action == "Promouvoir" and "est pilote" or "est banni")
			dire(joueur, cible.DisplayName .. " " .. verbe .. (donnees.session and " (session)" or "") .. ".", true)
			dire(cible, action == "Promouvoir" and (donnees.retirer and "Tes droits de pilote du TARDIS ont été retirés." or "Tu es maintenant pilote du TARDIS.")
				or (donnees.retirer and "Tu n'es plus banni du TARDIS." or "Tu es banni du TARDIS."), action == "Promouvoir" and not donnees.retirer)
		else
			dire(joueur, "Durée invalide.", false)
		end

	elseif action == "AutoDestruction" then
		if typeof(donnees) == "table" and donnees.confirmation == 3 then
			local ok, erreur = lancerAutoDestruction(joueur)
			if not ok then dire(joueur, "Impossible : " .. tostring(erreur), false) end
		end

	elseif action == "Inviter" then
		local cible = typeof(donnees) == "table" and Players:GetPlayerByUserId(donnees.joueur or 0)
		if not cible then return end
		if cible == joueur then
			local racine = racineDe(joueur)
			if racine then racine.CFrame = pointArriveeInterieur() end
			dire(joueur, "Te voilà à bord.", true)
			return
		end
		if dedans[cible] then dire(joueur, cible.DisplayName .. " est déjà à bord.", false) return end
		invitations[cible.UserId] = { pilote = joueur.UserId, fin = os.clock() + 60 }
		remote:FireClient(cible, "__invitation", joueur.DisplayName)
		dire(joueur, "Invitation envoyée à " .. cible.DisplayName .. " (valable 1 minute).", true)

	elseif action == "BaliseAller" then
		local cible = typeof(donnees) == "table" and Players:GetPlayerByUserId(donnees.joueur or 0)
		if not cible or not balises[cible.UserId] then dire(joueur, "Cette balise n'est plus active.", false) return end
		task.spawn(allerVersJoueur, joueur, cible, "Balise : " .. cible.DisplayName)

	elseif action == "Murs" then
		local index = typeof(donnees) == "table" and tonumber(donnees.index)
		local choix = index and (Config.Couleurs or {})[index]
		if choix then
			appliquerPieces("Murs", { couleur = choix.couleur })
			exterieur:SetAttribute("CouleurMurs", index)
			sauverReglages()
			dire(joueur, "Murs repeints : " .. choix.nom .. ".", true)
		end

	elseif action == "StyleInterieur" then
		local index = typeof(donnees) == "table" and tonumber(donnees.index)
		local style = index and (Config.StylesInterieur or {})[index]
		if style then
			appliquerPieces("Murs", style.murs)
			appliquerPieces("Sol", style.sol)
			exterieur:SetAttribute("StyleInterieur", index)
			exterieur:SetAttribute("CouleurMurs", nil)
			sauverReglages()
			dire(joueur, "Style de l'intérieur : " .. style.nom .. ".", true)
		end

	elseif action == "StyleConsole" then
		local index = typeof(donnees) == "table" and tonumber(donnees.index)
		local style = index and (Config.StylesConsole or {})[index]
		if style then
			appliquerStyleConsole(style)
			exterieur:SetAttribute("StyleConsole", index)
			sauverReglages()
			dire(joueur, "Style de la console : " .. style.nom .. ".", true)
		end

	elseif action == "Decoration" then
		local nom = typeof(donnees) == "table" and donnees.nom
		if nom == "Aucune" or nom == "Noel" or nom == "Halloween" then
			exterieur:SetAttribute("Decoration", nom ~= "Aucune" and nom or nil)
			sauverReglages()
			dire(joueur, "Décoration : " .. nom .. ".", true)
		end

	elseif action == "Reflets" then
		exterieur:SetAttribute("Reflets", not exterieur:GetAttribute("Reflets"))
		sauverReglages()
		dire(joueur, exterieur:GetAttribute("Reflets") and "Reflets des vitres activés." or "Reflets des vitres désactivés.", true)

	elseif action == "Jukebox" then
		local index = typeof(donnees) == "table" and tonumber(donnees.index)
		local liste = typeof(donnees) == "table" and donnees.liste
		if type(liste) == "string" and #liste <= 30 then
			-- Playlist (V6.7.3) : toutes les pistes d'une catégorie, en ordre aléatoire
			local nombre = 0
			for _, piste in Config.Jukebox or {} do if piste.categorie == liste then nombre += 1 end end
			if nombre > 0 then
				exterieur:SetAttribute("Jukebox", liste)
				exterieur:SetAttribute("JukeboxDebut", workspace:GetServerTimeNow())
				dire(joueur, string.format("Jukebox : playlist %s (%d piste(s), aléatoire).", liste, nombre), true)
			else
				dire(joueur, "Aucune piste « " .. liste .. " » dans Config.Jukebox.", false)
			end
		elseif index and (Config.Jukebox or {})[index] then
			exterieur:SetAttribute("Jukebox", math.floor(index))
			exterieur:SetAttribute("JukeboxDebut", workspace:GetServerTimeNow())
			dire(joueur, "Jukebox : " .. Config.Jukebox[index].nom .. ".", true)
		else
			exterieur:SetAttribute("Jukebox", nil)
			dire(joueur, "Jukebox arrêté.", true)
		end

	elseif action == "Categorie" then
		local nom = typeof(donnees) == "table" and donnees.destination
		local index = typeof(donnees) == "table" and tonumber(donnees.index)
		if typeof(nom) == "string" and #nom <= 100 and index then
			categories[nom] = (index >= 1 and index <= #(Config.Categories or {})) and math.floor(index) or nil
			publierCategories()
			sauverReglages()
		end

	elseif action == "Rappel" then
		task.spawn(function()
			local etat, occupe = interne("etat")
			if etat ~= E.Pose or occupe then dire(joueur, "Impossible : le TARDIS n'est pas posé.", false) return end
			local ok, erreur = interne("decoller", false)
			if not ok then dire(joueur, "Impossible : " .. string.lower(erreur or "erreur"), false) return end
			task.wait(Config.DureeVortexRappel or 6)
			local cible, erreurCible = interne("cibleJoueur", joueur)
			if not cible then dire(joueur, "Rappel impossible : " .. string.lower(erreurCible or "erreur"), false) return end
			local okRemat, erreurRemat = interne("atterrir", cible, "Rappel : " .. joueur.DisplayName, false, nil, false)
			dire(joueur, okRemat and "Le TARDIS est arrivé près de toi." or ("Impossible : " .. string.lower(erreurRemat or "erreur")), okRemat)
		end)

	elseif action == "Minuterie" then
		local secondes = typeof(donnees) == "table" and tonumber(donnees.secondes)
		if secondes and secondes >= 5 and secondes <= 600 then armerMinuterie(joueur, math.floor(secondes)) end

	elseif action == "MinuterieAnnuler" then
		jetonMinuterie += 1
		exterieur:SetAttribute("MinuterieFin", nil)
		dire(joueur, "Minuterie annulée.", true)

	elseif action == "Leurre" then
		if typeof(donnees) ~= "table" then return end
		if donnees.retirer then retirerLeurre() dire(joueur, "Leurre retiré.", true) return end
		local cible, nom, _, _, erreur = interne("resoudreDestination", donnees)
		if not cible then dire(joueur, "Impossible : " .. string.lower(erreur or "aucune destination"), false) return end
		dire(joueur, creerLeurre(cible) and ("Leurre déployé : " .. tostring(nom) .. ".") or "Impossible de créer le leurre.", true)

	elseif action == "Expulser" then
		local cible = typeof(donnees) == "table" and Players:GetPlayerByUserId(donnees.joueur or 0)
		if not cible or cible == joueur then return end
		local racine = racineDe(cible)
		if not (racine and interne("dansInterieur", racine.Position)) then dire(joueur, "Ce joueur n'est pas dans le TARDIS.", false) return end
		dire(joueur, expulser(cible) and (cible.DisplayName .. " a été expulsé.") or "Expulsion impossible.", true)

	elseif action == "Theme" then
		local nom = typeof(donnees) == "table" and donnees.nom
		for _, theme in Config.Themes or {} do
			if theme.nom == nom then
				exterieur:SetAttribute("Theme", nom)
				sauverReglages()
				dire(joueur, "Thème : " .. nom .. ".", true)
			end
		end

	elseif action == "Projecteur" then
		exterieur:SetAttribute("Projecteur", not exterieur:GetAttribute("Projecteur"))
		dire(joueur, exterieur:GetAttribute("Projecteur") and "Projecteur allumé : vise avec ta caméra." or "Projecteur éteint.", true)

	elseif action == "Couleur" then
		local index = typeof(donnees) == "table" and tonumber(donnees.index)
		local choix = index and (Config.Couleurs or {})[index]
		if choix then
			peindre(choix.couleur)
			sauverReglages()
			dire(joueur, "Cabine repeinte : " .. choix.nom .. ".", true)
		end

	elseif action == "Enseigne" then
		local texte = typeof(donnees) == "table" and donnees.texte
		if typeof(texte) ~= "string" or #texte == 0 or #texte > 24 then return end
		task.spawn(function()
			local ok, filtre = pcall(function()
				return TextService:FilterStringAsync(texte, joueur.UserId):GetNonChatStringForBroadcastAsync()
			end)
			if ok and filtre then
				enseigne(string.upper(filtre))
				sauverReglages()
				dire(joueur, "Enseigne : " .. string.upper(filtre), true)
			else
				dire(joueur, "Texte refusé par le filtre.", false)
			end
		end)
	end
end)

-- Ancien système de chat (si le nouveau n'est pas actif)
Players.PlayerAdded:Connect(function(joueur)
	joueur.Chatted:Connect(function(message) surMessage(joueur, message) end)
end)
for _, joueur in Players:GetPlayers() do
	joueur.Chatted:Connect(function(message) surMessage(joueur, message) end)
end

-- Réglages du TARDIS sauvegardés (thème, couleur, enseigne, styles, catégories, décoration) : chargés EN DERNIER,
-- une fois toutes les fonctions définies
local reglages = charger("reglages") or {}
if type(reglages.theme) == "string" then exterieur:SetAttribute("Theme", reglages.theme) end
if type(reglages.couleur) == "table" and #reglages.couleur == 3 then peindre(Color3.new(reglages.couleur[1], reglages.couleur[2], reglages.couleur[3])) end
if type(reglages.enseigne) == "string" then enseigne(reglages.enseigne) end
if type(reglages.murs) == "number" and (Config.Couleurs or {})[reglages.murs] then
	appliquerPieces("Murs", { couleur = Config.Couleurs[reglages.murs].couleur })
	exterieur:SetAttribute("CouleurMurs", reglages.murs)
end
if type(reglages.styleInterieur) == "number" and (Config.StylesInterieur or {})[reglages.styleInterieur] then
	local style = Config.StylesInterieur[reglages.styleInterieur]
	appliquerPieces("Murs", style.murs)
	appliquerPieces("Sol", style.sol)
	exterieur:SetAttribute("StyleInterieur", reglages.styleInterieur)
end
if type(reglages.styleConsole) == "number" and (Config.StylesConsole or {})[reglages.styleConsole] then
	appliquerStyleConsole(Config.StylesConsole[reglages.styleConsole])
	exterieur:SetAttribute("StyleConsole", reglages.styleConsole)
end
if type(reglages.decoration) == "string" then exterieur:SetAttribute("Decoration", reglages.decoration) end
if reglages.reflets == true then exterieur:SetAttribute("Reflets", true) end
if type(reglages.categories) == "table" then
	for nom, index in reglages.categories do
		if type(nom) == "string" and type(index) == "number" then categories[nom] = index end
	end
	publierCategories()
end

--------------------------------------------------------------------
-- Intercom du site (V6.7.3) : la première matérialisation VISIBLE de ce TARDIS pendant la session est publiée sur
-- l'événement ServerStorage › TardisEvenements ("FailleSpatioTemporelle"). Le script TardisPontFondation fait
-- l'annonce (OS Fondation si Config.Intercom.Cible est renseigné, sinon l'annonce intégrée). Ensuite, les pilotes
-- reçoivent un rappel toutes les Config.Intercom.RappelMinutes minutes.
--------------------------------------------------------------------
do
	local INTERCOM = Config.Intercom or {}
	local evenements = ServerStorage:FindFirstChild("TardisEvenements")
	if not evenements then
		evenements = Instance.new("BindableEvent")
		evenements.Name = "TardisEvenements"
		evenements.Parent = ServerStorage
	end
	local signalee = nil -- { lieu, heure } : la faille de cette session
	local etatAvant = exterieur:GetAttribute("Etat")
	local modeRemat = "Normal"
	exterieur:GetAttributeChangedSignal("Etat"):Connect(function()
		local etat = exterieur:GetAttribute("Etat")
		local avant = etatAvant
		etatAvant = etat
		if etat == E.Remat then modeRemat = Config.modeDe(exterieur) end
		if INTERCOM.Actif == false or signalee then return end
		if etat == E.Pose and (Config.Modes[modeRemat] or {}).Discret then return end -- Silencieux (V6.9) : pas d'annonce
		if exterieur:GetAttribute("Recette") then return end -- recette automatique (V6.9.2) : pas d'annonce
		-- Posé après une matérialisation, et visible (ni camouflé, ni porté)
		if etat ~= E.Pose or avant ~= E.Remat then return end
		if exterieur:GetAttribute("Camouflage") == true or exterieur:GetAttribute("Porteur") then return end
		local lieu = tostring(exterieur:GetAttribute("Position") or "lieu inconnu")
		signalee = { lieu = lieu, heure = os.date("%H:%M") }
		exterieur:SetAttribute("FailleSignalee", workspace:GetServerTimeNow())
		evenements:Fire("FailleSpatioTemporelle", {
			tardis = def.Nom, lieu = lieu, position = exterieur:GetPivot().Position,
			mode = Config.modeDe(exterieur), heure = os.time(),
		})
		print(string.format("[TARDIS] %s : faille spatio-temporelle signalée à l'intercom (%s).", def.Nom, lieu))
	end)
	task.spawn(function()
		local minutes = INTERCOM.RappelMinutes or 10
		if minutes <= 0 then return end
		while true do
			task.wait(minutes * 60)
			if signalee then
				direAuxPilotes(string.format(INTERCOM.Rappel or "Rappel : la faille spatio-temporelle de %s (%s) a été signalée à tout le site.",
					signalee.heure, signalee.lieu), false)
			end
		end
	end)
end

print("[TARDIS] " .. def.Nom .. " : extras prêts" .. (Config.Debug and " (diagnostic activé)." or "."))