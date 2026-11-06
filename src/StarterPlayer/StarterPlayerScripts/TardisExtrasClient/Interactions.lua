-- StarterPlayerScripts > TardisExtrasClient > Interactions (ModuleScript)
-- Invitation et casiers (V6.9.10.1 : casier de la console avec un vrai bouton)
-- Extrait du script principal en V6.6.3 : reçoit ce qu'il utilise, renvoie ce que la suite utilise.

return function(contexte)
	local C, Config, UI, UserInputService, animer, camera = contexte.C, contexte.Config, contexte.UI, contexte.UserInputService, contexte.animer, contexte.camera
	local creer, interieur, joueur, maRacine = contexte.creer, contexte.interieur, contexte.joueur, contexte.maRacine
	local remote, texte = contexte.remote, contexte.texte

	--------------------------------------------------------------------
	-- 14) Invitation : un pilote t'invite, tu acceptes ou tu refuses
	--------------------------------------------------------------------
	-- (V6.9.10.7) Notification de la charte (badge INVITATION) avec ACCEPTER (principal) et REFUSER (danger)
	local function afficherInvitation(pilote)
		local gui = creer("ScreenGui", { Name = "TardisInvitation", ResetOnSpawn = false, Parent = joueur:WaitForChild("PlayerGui") })
		local notif = UI.notification({ Name = "Invitation", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -140), Size = UDim2.fromOffset(420, 0),
			Parent = gui }, { retrait = 104, tailleTexte = 13 })
		notif.regler(tostring(pilote) .. " t'invite à bord du TARDIS. Tu y seras téléporté.", "info", "INVITATION")
		local carte = notif.cadre
		carte.Visible = true
		creer("UIScale", { Scale = UI.tailleInterface(), Parent = carte })
		local rangee = creer("Frame", { Name = "Boutons", Size = UDim2.new(1, 0, 0, UI.JETONS.cible), BackgroundTransparency = 1, LayoutOrder = 10, Parent = notif.contenu },
		{ creer("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
		local function bouton(txt, variante, ordre, accepter)
			local b = UI.boutonCoupe(rangee, txt, variante, { Name = accepter and "Accepter" or "Refuser", Size = UDim2.new(0.5, -4, 1, 0), LayoutOrder = ordre })
			b.Activated:Connect(function()
				remote:FireServer("InvitationReponse", { accepter = accepter })
				gui:Destroy()
			end)
		end
		bouton("Accepter", "principal", 1, true)
		bouton("Refuser", "danger", 2, false)
		UI.son("Notification")
		animer(carte, 0.5, { Position = UDim2.new(0.5, 0, 0, 100) }, Enum.EasingStyle.Back)
		task.delay(60, function() if gui.Parent then gui:Destroy() end end)
	end

	--------------------------------------------------------------------
	-- 16) Casiers : maintenir E 3 s sur un "Casier", la caméra recule face au joueur, un menu de tenues apparaît.
	-- Casier de la console (V6.9.10.1, Config.Chemins.Casier = Console › Casier, pièce ou Model) : un vrai bouton,
	-- l'invite « Choisir une tenue » (appui court) et un clic, qui ouvrent le même menu.
	-- (V6.9.10.5) Model : clic sur tout le Model, invite au-dessus du casier. Caméra : jamais dans un mur (placeCamera),
	-- rendue exactement à la fermeture (Échap, bouton, distance, mort, réapparition). Aperçu : les vraies images des
	-- vêtements, données par le serveur (TardisTenues) ; la tenue gardée est mise par le serveur.
	-- (V6.9.10.7) Charte « Hologramme de confinement » (maquette CASIER) : panneau à coins coupés à droite de l'écran (le
	-- joueur reste visible face à la caméra), plaque « CASIER » (badge : l'équipe du joueur), « CHOISIR UNE TENUE »,
	-- grille de tuiles (la tenue essayée en jaune, ○ / ● favori), boutons ENFILER (principal, garde la tenue) et FERMER.
	--------------------------------------------------------------------
	do
		local REGLAGES_CASIER = Config.Casiers or {}
		local objetConsole = Config.trouverCommande(interieur, "Casier")
		local partConsole = Config.partDe(objetConsole)
		local casiers = {}
		for _, objet in interieur:GetDescendants() do
			if objet.Name == "Casier" and objet ~= objetConsole then
				local part = objet:IsA("BasePart") and objet or (objet:IsA("Model") and (objet.PrimaryPart or objet:FindFirstChildWhichIsA("BasePart", true)))
				if part and part ~= partConsole then table.insert(casiers, part) end
			end
		end
		local gui = creer("ScreenGui", { Name = "TardisCasier", ResetOnSpawn = false, Enabled = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			Parent = joueur:WaitForChild("PlayerGui") })
		local LARGEUR_CASIER, HAUTEUR_CASIER = 360, 600
		local panneauCasier, panneau = UI.panneauCoupe({ Name = "Casier", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -20, 0.5, 0),
			Size = UDim2.fromOffset(LARGEUR_CASIER, HAUTEUR_CASIER), BackgroundColor3 = C.fond, BackgroundTransparency = 0.06, Parent = gui }, { coupe = 16, rayon = 16, marges = 18 })
		local echelleCasier = creer("UIScale", { Scale = UI.tailleInterface(), Parent = panneauCasier })
		local plaqueCasier = UI.plaque(panneau, "Casier", "", "Choisir une tenue", { largeurBande = LARGEUR_CASIER })
		local TEXTE_AIDE = "Clique pour essayer. ○ = mettre en favori (gardé pour toujours)."
		local aide = UI.ligneAide(panneau, TEXTE_AIDE, { Name = "Aide", AutomaticSize = Enum.AutomaticSize.None, Position = UDim2.fromOffset(0, 68),
			Size = UDim2.new(1, 0, 0, 28) })
		-- Échelle : suit l'écran (le panneau garde au plus 42 % de la largeur) et la taille de l'interface des réglages
		local function majEchelleCasier()
			local ok, taille = pcall(function() return camera.ViewportSize end)
			local base = 1
			if ok and typeof(taille) == "Vector2" and taille.X > 0 and taille.Y > 0 then
				base = math.clamp(math.min(taille.X * 0.42 / LARGEUR_CASIER, taille.Y * 0.88 / HAUTEUR_CASIER), 0.5, 1.15)
			end
			echelleCasier.Scale = base * UI.tailleInterface()
		end
		-- (V6.9.10.5) Un message court à la place de l'aide, 3 s (aperçu indisponible…)
		local jetonAide = 0
		local function signaler(message)
			jetonAide += 1
			local moi = jetonAide
			aide.Text = message
			task.delay(3, function()
				if moi == jetonAide then aide.Text = TEXTE_AIDE end
			end)
		end
		-- Grille des tenues (deux colonnes de tuiles de 80 px)
		local liste = creer("ScrollingFrame", { Name = "Tenues", Position = UDim2.fromOffset(0, 104), Size = UDim2.new(1, 0, 1, -164), BackgroundTransparency = 1,
			BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = C.cyan, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = panneau },
		{ creer("UIGridLayout", { CellSize = UDim2.new(0.5, -6, 0, 80), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
		local rangeeBas = creer("Frame", { Name = "Boutons", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 46),
			BackgroundTransparency = 1, Parent = panneau }, { UI.pile(8, true) })
		local garder = UI.boutonCoupe(rangeeBas, "Enfiler", "principal", { Name = "Enfiler", Size = UDim2.new(0.5, -4, 1, 0), LayoutOrder = 1 })
		local fermer = UI.boutonCoupe(rangeeBas, "Fermer", "secondaire", { Name = "Fermer", Size = UDim2.new(0.5, -4, 1, 0), LayoutOrder = 2 })

		local actif = false
		local apercu = nil -- index de la tenue essayée
		local origine = nil -- { personnage, shirt = template, pants = template } avant l'essayage
		local attenteTenue = nil -- (V6.9.10.5) l'origine d'une tenue gardée, tant que le serveur n'a pas répondu (« __tenue »)
		local function restaurer(o)
			o = o or origine
			local personnage = o and o.personnage
			if not personnage then return end
			local shirt = personnage:FindFirstChildOfClass("Shirt")
			local pants = personnage:FindFirstChildOfClass("Pants")
			if shirt then shirt.ShirtTemplate = o.shirt end
			if pants then pants.PantsTemplate = o.pants end
		end
		-- (V6.9.10.5) Images des vêtements publiées par le serveur (dossier TardisAssets › Tenues, Config.cleVetement) :
		-- nil = pas encore prêtes, "" = introuvables. Avant : l'identifiant du catalogue mis tel quel comme image (rien ne
		-- s'affichait, le joueur apparaissait sans vêtements).
		local function imagesApercu(tenue)
			local assets = game:GetService("ReplicatedStorage"):FindFirstChild("TardisAssets")
			local dossier = assets and assets:FindFirstChild("Tenues")
			if not dossier then return nil, nil end
			local cleHaut, cleBas = Config.cleVetement("Shirt", tenue.shirt), Config.cleVetement("Pants", tenue.pant)
			return cleHaut and dossier:GetAttribute(cleHaut), cleBas and dossier:GetAttribute(cleBas)
		end
		local function appliquerLocal(index)
			local personnage = origine and origine.personnage
			local tenue = (Config.Tenues or {})[index]
			if not personnage or not personnage.Parent or not tenue then return end
			local haut, bas = imagesApercu(tenue)
			if type(haut) ~= "string" or haut == "" or type(bas) ~= "string" or bas == "" then
				restaurer() -- l'aperçu impossible : le joueur garde ses vêtements
				signaler((haut == nil or bas == nil) and "Tenue en cours de chargement : réessaie dans un instant."
					or "Aperçu indisponible : vêtements introuvables.")
				return
			end
			local shirt = personnage:FindFirstChildOfClass("Shirt") or creer("Shirt", { Name = "Shirt", Parent = personnage })
			local pants = personnage:FindFirstChildOfClass("Pants") or creer("Pants", { Name = "Pants", Parent = personnage })
			shirt.ShirtTemplate = haut
			pants.PantsTemplate = bas
		end

		-- (V6.9.10.5) Place de la caméra : face au joueur, mais jamais dans un mur. Avant, elle allait toujours à 7 studs
		-- DEVANT lui, sans rien vérifier : le joueur regarde le casier, donc la console et le mur juste derrière, et la vue
		-- entière n'était plus que la texture du mur. Un rayon part de la tête vers chaque place (devant, devant à gauche,
		-- devant à droite, plus haut) et s'arrête avant le premier obstacle (le personnage et les pièces invisibles ou sans
		-- requête du TARDIS ne comptent pas) ; la place la plus dégagée gagne, si elle dépasse le minimum. Rien : nil (la
		-- caméra ne bouge pas).
		local function placeCamera(personnage, racine)
			local tete = personnage:FindFirstChild("Head")
			local depart = (tete and tete:IsA("BasePart")) and tete.Position or (racine.Position + Vector3.new(0, 1.5, 0))
			local regard = racine.CFrame.LookVector
			local devant = Vector3.new(regard.X, 0, regard.Z)
			if devant.Magnitude < 0.05 then devant = Vector3.new(0, 0, -1) end
			devant = devant.Unit
			local droite = devant:Cross(Vector3.new(0, 1, 0))
			local places = { devant, (devant - droite).Unit, (devant + droite).Unit, (devant + Vector3.new(0, 0.8, 0)).Unit }
			local ignores = { personnage }
			for _, objet in interieur:GetDescendants() do
				if objet:IsA("BasePart") and (objet.Transparency >= 0.95 or objet.CanQuery == false) then table.insert(ignores, objet) end
			end
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = ignores
			local voulu = REGLAGES_CASIER.DistanceCamera or 7
			local minimum = REGLAGES_CASIER.DistanceMinimale or 2.5
			local marge = REGLAGES_CASIER.Marge or 0.5
			local meilleure, meilleurLibre = nil, -math.huge
			for _, direction in places do
				local touche = workspace:Raycast(depart, direction * voulu, params)
				local libre = touche and math.min(touche.Distance - marge, voulu) or voulu
				if libre >= minimum and libre > meilleurLibre + 1e-6 then meilleure, meilleurLibre = direction, libre end
			end
			if not meilleure then return nil end
			return CFrame.lookAt(depart + meilleure * meilleurLibre, racine.Position + Vector3.new(0, 0.5, 0))
		end
		local cameraAvant = nil -- { type, sujet, cframe } : la caméra d'avant, si le menu l'a déplacée
		local function rendreCamera()
			local avant = cameraAvant
			cameraAvant = nil
			if not avant then return end
			camera.CFrame = avant.cframe
			camera.CameraType = avant.type
			local sujet = avant.sujet
			if not (sujet and sujet:IsDescendantOf(game)) then -- réapparu : le nouveau personnage
				sujet = joueur.Character and joueur.Character:FindFirstChildOfClass("Humanoid")
			end
			if sujet then camera.CameraSubject = sujet end
		end
		local surveillance = {} -- connexions du menu ouvert (mort, réapparition)
		local ouverture = nil -- jeton du menu ouvert (vérification de la distance)
		local construire
		construire = function()
			for _, e in liste:GetChildren() do
				if not e:IsA("UIGridLayout") then e:Destroy() end
			end
			local favoris = type(UI.prefs.tenuesFavorites) == "table" and UI.prefs.tenuesFavorites or {}
			local ordre = {}
			for i in Config.Tenues or {} do table.insert(ordre, i) end
			table.sort(ordre, function(a, b)
				local fa, fb = favoris[tostring(a)] == true, favoris[tostring(b)] == true
				if fa ~= fb then return fa end
				return a < b
			end)
			-- (V6.9.10.7) La tenue portée (gardée au casier, attribut du personnage posé par le serveur) est signalée
			local personnageActuel = joueur.Character
			local tenueActuelle = personnageActuel and personnageActuel:GetAttribute("TardisTenue")
			for rang, i in ordre do
				local tenue = Config.Tenues[i]
				local favori = favoris[tostring(i)] == true
				-- Tuile (maquette) : fond très légèrement éclairci, la tenue essayée en jaune (texte sombre), coins coupés
				local choisie = apercu == i
				local b = creer("TextButton", { Name = "Tenue", BackgroundColor3 = choisie and C.ambre or C.texte, BackgroundTransparency = choisie and 0 or 0.94, Text = "",
					AutoButtonColor = false, LayoutOrder = rang, Parent = liste }, { UI.coin(8) })
				b:SetAttribute("Choisie", choisie)
				UI.decouper(b, UI.JETONS.coupeBouton, { contour = choisie and C.ambre or C.ligne, transparenceContour = 0.2 })
				texte({ Name = "Nom", Text = UI.majuscules(tenue.nom), Font = UI.POLICE_GRAS, TextSize = 14, TextColor3 = choisie and C.sombre or C.texte,
					TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(12, 10), Size = UDim2.new(1, -52, 0, 18), Parent = b })
				texte({ Name = "Detail", Text = tostring(tenue.description or ""), Font = UI.POLICE_CODE, TextSize = 10, TextColor3 = choisie and C.sombre or C.texte2,
					TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(12, 33), Size = UDim2.new(1, -20, 0, 14), Parent = b })
				texte({ Name = "Categorie", Text = tenueActuelle == i and "●  TENUE ACTUELLE" or UI.majuscules(tostring(tenue.categorie or "")), Font = UI.POLICE_CODE,
					TextSize = 10, TextColor3 = choisie and C.sombre or (tenueActuelle == i and C.vert or C.texte2), TextTruncate = Enum.TextTruncate.AtEnd,
					Position = UDim2.fromOffset(12, 52), Size = UDim2.new(1, -20, 0, 14), Parent = b })
				local etoile = creer("TextButton", { Name = "Favori", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(44, 44),
					BackgroundTransparency = 1, Text = favori and "●" or "○", Font = UI.POLICE_GRAS, TextSize = 18, ZIndex = 3,
					TextColor3 = choisie and C.sombre or (favori and C.ambre or C.texte2), Parent = b })
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
			ouverture = nil
			for _, connexion in surveillance do connexion:Disconnect() end
			table.clear(surveillance)
			gui.Enabled = false
			rendreCamera() -- (V6.9.10.5) exactement la caméra d'avant (type, sujet, position)
			if garderTenue and apercu then
				attenteTenue = origine -- refusée par le serveur (« __tenue » faux) : l'aperçu est retiré
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
			origine = { personnage = personnage, shirt = shirt and shirt.ShirtTemplate or "", pants = pants and pants.PantsTemplate or "" }
			-- La caméra se place face au joueur, à la place la plus dégagée (V6.9.10.5) ; tout est bouché : elle ne bouge pas
			local okVue, vue = pcall(placeCamera, personnage, racine)
			if okVue and vue then
				cameraAvant = { type = camera.CameraType, sujet = camera.CameraSubject, cframe = camera.CFrame }
				camera.CameraType = Enum.CameraType.Scriptable
				camera.CFrame = vue
			end
			-- Fermeture (V6.9.10.5) : mort, réapparition, ou en s'éloignant (vérifié toutes les 0,5 s tant que le menu est ouvert)
			local humanoid = personnage:FindFirstChildOfClass("Humanoid")
			if humanoid then table.insert(surveillance, humanoid.Died:Connect(function() quitter(false) end)) end
			table.insert(surveillance, joueur.CharacterRemoving:Connect(function() quitter(false) end))
			table.insert(surveillance, joueur.CharacterAdded:Connect(function() quitter(false) end))
			local moi, point = {}, racine.Position
			ouverture = moi
			task.spawn(function()
				while ouverture == moi do
					task.wait(0.5)
					if ouverture ~= moi then break end
					local r = maRacine()
					if not r or (r.Position - point).Magnitude > (REGLAGES_CASIER.DistanceFermeture or 12) then quitter(false) end
				end
			end)
			-- (V6.9.10.7) Plaque : le badge dit l'équipe du joueur ; l'échelle suit l'écran
			plaqueCasier.majBadge(joueur.Team and UI.majuscules(joueur.Team.Name) or "", C.cyan)
			majEchelleCasier()
			construire()
			gui.Enabled = true
		end
		-- (V6.9.10.5) Réponse du serveur à « Garder cette tenue » : refusée (introuvable), l'aperçu est retiré
		remote.OnClientEvent:Connect(function(message, ok)
			if message ~= "__tenue" then return end
			local attente = attenteTenue
			attenteTenue = nil
			if ok ~= true and attente then restaurer(attente) end
		end)
		garder.Activated:Connect(function() quitter(true) end)
		fermer.Activated:Connect(function() quitter(false) end)
		for _, part in casiers do
			local prompt = creer("ProximityPrompt", { ActionText = "Ouvrir le casier", ObjectText = "Casier", HoldDuration = 3, MaxActivationDistance = 8,
				RequiresLineOfSight = false, Parent = part })
			prompt.Triggered:Connect(ouvrir)
		end
		-- Casier de la console : appui court (ou clic) ; les règles du choix de tenue ne changent pas (serveur : action Tenue)
		-- (V6.9.10.5) objet = la pièce ou le Model du casier : clic sur tout le Model, invite au-dessus du casier
		local function brancherCasierConsole(objet)
			local part = Config.partDe(objet)
			-- (V6.9.10.1, relecture) pas E : les invites du Selecteur, du levier et de l'alerte restent visibles
			local invites = Config.InvitesConsole or {}
			local okTouche, touche = pcall(function() return Enum.KeyCode[invites.Touche or "Z"] end)
			local okManette, manette = pcall(function() return Enum.KeyCode[invites.Manette or "DPadRight"] end)
			local prompt = creer("ProximityPrompt", { Name = "TardisCasierConsole", ActionText = "Choisir une tenue", ObjectText = "Casier", HoldDuration = 0,
				MaxActivationDistance = 8, RequiresLineOfSight = false, KeyboardKeyCode = okTouche and touche or Enum.KeyCode.Z,
				GamepadKeyCode = okManette and manette or Enum.KeyCode.DPadRight,
				Parent = Config.pointInvite(objet, invites.HauteurInvite, nil, part, "TardisCasierConsole") or part })
			prompt.Triggered:Connect(ouvrir)
			local clic = creer("ClickDetector", { Name = "TardisCasierConsole", MaxActivationDistance = 12, Parent = Config.cibleClic(objet) or part })
			clic.MouseClick:Connect(function(qui) if qui == joueur then ouvrir() end end)
		end
		if partConsole then
			brancherCasierConsole(objetConsole)
		elseif Config.Chemins.Casier then
			-- Pas encore chargé (Streaming) : on l'attend un peu, sans bloquer le reste
			task.spawn(function()
				local objet = Config.trouverCommande(interieur, "Casier", 10)
				if Config.partDe(objet) then brancherCasierConsole(objet) end
			end)
		end
		UserInputService.InputBegan:Connect(function(input)
			if actif and input.KeyCode == Enum.KeyCode.Escape then quitter(false) end
		end)
	end

	return { afficherInvitation = afficherInvitation }
end
