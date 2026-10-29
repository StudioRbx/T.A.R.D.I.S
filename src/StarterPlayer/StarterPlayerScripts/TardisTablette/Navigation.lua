-- StarterPlayerScripts > TardisTablette > Navigation (ModuleScript)
-- Liste des lieux et des joueurs, commandes de voyage
-- Extrait du script principal en V6.6.3 : reçoit ce qu'il utilise, renvoie ce que la suite utilise.

return function(contexte)
	local C, Commandes, Config, E, Players, S = contexte.C, contexte.Commandes, contexte.Config, contexte.E, contexte.Players, contexte.S
	local TAILLE_MIN, UI, UserInputService, W, animer, cleDe = contexte.TAILLE_MIN, contexte.UI, contexte.UserInputService, contexte.W, contexte.animer, contexte.cleDe
	local creer, distanceDe, exterieur, joueur, majFiche, majInterface = contexte.creer, contexte.distanceDe, contexte.exterieur, contexte.joueur, contexte.majFiche, contexte.majInterface
	local notifier, remote, seuilPortes, texte = contexte.notifier, contexte.remote, contexte.seuilPortes, contexte.texte

	--------------------------------------------------------------------
	-- Liste des lieux et des joueurs
	--------------------------------------------------------------------
	local construireListe -- définie plus bas (l'étoile des favoris en a besoin)
	local function ajouterElement(texteEl, c, ordre)
		local bouton = creer("TextButton", { Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = C.panneau, Text = "",
			LayoutOrder = ordre, Parent = W.liste }, { UI.coin(7) })
		creer("Frame", { Name = "Barre", Size = UDim2.new(0, 3, 1, -10), Position = UDim2.fromOffset(4, 5),
			BackgroundColor3 = C.ambre, Visible = false, Parent = bouton }, { UI.coin(99) })
		texte({ Text = (c.type == "lieu" and "◆") or (c.type == "precedent" and "◄") or (c.type == "historique" and "►") or "●", TextSize = 16, TextColor3 = C.ambre,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(12, 0), Size = UDim2.new(0, 22, 1, 0), Parent = bouton })
		texte({ Text = texteEl, Font = UI.POLICE_GRAS, TextSize = 13, Position = UDim2.fromOffset(42, 4),
			Size = UDim2.new(1, -150, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd, Parent = bouton })
		local sous = texte({ Text = (c.type == "joueur" and ("@" .. (c.pseudo or ""))) or (c.type == "precedent" and "Retour au point de départ")
			or (c.type == "historique" and c.sous) or (c.type == "lieu" and UI.estFavori(c.nom) and "Favori") or "Destination enregistrée", TextSize = 11,
			TextColor3 = C.texte2, Position = UDim2.fromOffset(42, 21), Size = UDim2.new(1, -150, 0, 14),
			TextTruncate = Enum.TextTruncate.AtEnd, Parent = bouton })
		local distance = texte({ Text = "", Font = UI.POLICE_CODE, TextSize = 12, TextColor3 = C.cyan,
			TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(100, 16), Parent = bouton })
		bouton:SetAttribute("CouleurBase", C.panneau)
		UI.rendreVivant(bouton)
		bouton.Activated:Connect(function()
			if UI.pref("modeVoyage", "auto") == "manuel" and (exterieur:GetAttribute("Etat") or E.Pose) == E.Pose
				and exterieur:GetAttribute("Porteur") ~= joueur.UserId then
				notifier("Mode manuel : décolle d'abord, les destinations se débloquent dans le vortex.", false)
				return
			end
			S.choix = c
			majInterface()
		end)
		if c.type == "lieu" then
			-- Étiquette de catégorie (couleur) si la destination en a une
			local categorie = S.categories[c.nom] and (Config.Categories or {})[S.categories[c.nom]]
			if categorie then
				creer("Frame", { Name = "Categorie", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -150, 0.5, 0), Size = UDim2.fromOffset(8, 22),
					BackgroundColor3 = categorie.couleur, Parent = bouton }, { UI.coin(99) })
				sous.Text = categorie.nom .. "  ·  " .. sous.Text
			end
			-- Étoile de favori : les favoris remontent en tête de liste
			local favori = UI.estFavori(c.nom)
			local etoile = creer("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -118, 0.5, 0), Size = UDim2.fromOffset(26, 26),
				BackgroundTransparency = 1, Text = favori and "●" or "○", Font = UI.POLICE_GRAS, TextSize = 16,
				TextColor3 = favori and C.ambre or C.texte2, Parent = bouton })
			etoile.Activated:Connect(function()
				UI.basculerFavori(c.nom)
				construireListe()
			end)
		end
		S.boutonsChoix[cleDe(c)] = { bouton = bouton, distance = distance, sous = sous, choix = c }
		table.insert(S.elementsListe, bouton)
	end

	construireListe = function()
		for _, element in S.elementsListe do element:Destroy() end
		table.clear(S.elementsListe)
		table.clear(S.boutonsChoix)

		local filtre = string.lower(W.recherche.Text)
		local function garde(nom)
			return filtre == "" or string.find(string.lower(nom), filtre, 1, true) ~= nil
		end
		local ordre = 0
		local noms = {}
		local precedentNom = exterieur:GetAttribute("PrecedentNom")
		local lieux = {}
		for nom in string.gmatch(exterieur:GetAttribute("ListeDestinations") or "", "[^\n]+") do
			noms[nom] = true
			table.insert(lieux, nom)
		end
		-- Les favoris d'abord, puis les autres dans l'ordre d'origine
		local ordreOrigine = {}
		for i, nom in lieux do ordreOrigine[nom] = i end
		local parDistance = UI.pref("tri", "nom") == "distance"
		local distances = {}
		if parDistance then
			for _, nom in lieux do distances[nom] = distanceDe({ type = "lieu", nom = nom }) or math.huge end
		end
		table.sort(lieux, function(a, b)
			local fa, fb = UI.estFavori(a), UI.estFavori(b)
			if fa ~= fb then return fa end
			if parDistance and distances[a] ~= distances[b] then return distances[a] < distances[b] end
			return ordreOrigine[a] < ordreOrigine[b]
		end)
		for _, nom in lieux do
			if S.mode == "lieux" and garde(nom) then
				ordre += 1
				ajouterElement(nom, { type = "lieu", nom = nom }, ordre)
			end
		end
		if S.mode == "histo" then
			-- En tête de l'historique : retour là d'où le TARDIS est parti
			if precedentNom and garde("Retour " .. precedentNom) then
				ordre += 1
				ajouterElement("Retour : " .. precedentNom, { type = "precedent", nom = precedentNom }, ordre)
			end
			local index = 0
			for ligne in string.gmatch(exterieur:GetAttribute("Historique") or "", "[^\n]+") do
				local nom, x, y, z, modeVoyage = string.match(ligne, "^(.-)\t([%-%d%.]+)\t([%-%d%.]+)\t([%-%d%.]+)\t?(%a*)$")
				if nom and garde(nom) then
					index += 1
					ordre += 1
					ajouterElement(nom, { type = "historique", index = index, nom = nom, cframe = CFrame.new(tonumber(x), tonumber(y), tonumber(z)),
						sous = string.format("Voyage n°%d  ·  %s%d, %d, %d", index,
							(modeVoyage == "Express" and "EXPRESS  ·  ") or (modeVoyage == "Urgence" and "URGENCE  ·  ") or "",
							tonumber(x), tonumber(y), tonumber(z)) }, ordre)
				end
			end
		end
		if S.mode == "joueurs" then
			local joueurs = Players:GetPlayers()
			table.sort(joueurs, function(a, b) return a.DisplayName:lower() < b.DisplayName:lower() end)
			for _, autre in joueurs do
				if garde(autre.DisplayName) or garde(autre.Name) then
					ordre += 1
					ajouterElement(autre.DisplayName .. (autre == joueur and "  (toi)" or ""),
						{ type = "joueur", id = autre.UserId, nom = autre.DisplayName, pseudo = autre.Name }, ordre)
				end
			end
		end
		W.listeVide.Text = (S.mode == "lieux" and (filtre == "" and "Aucun lieu.\nAjoute des Parts dans TARDIS_Destinations."
			or "Aucun lieu ne correspond.")) or (S.mode == "histo" and "Aucun voyage pour l'instant.") or "Aucun joueur ne correspond."
		W.listeVide.Visible = ordre == 0 and S.mode ~= "coord"

		if S.choix then
			local existe = (S.choix.type == "lieu" and noms[S.choix.nom])
				or (S.choix.type == "joueur" and Players:GetPlayerByUserId(S.choix.id))
				or (S.choix.type == "position" and S.positionPerso)
				or (S.choix.type == "precedent" and precedentNom)
				or (S.choix.type == "historique")
			if not existe then S.choix = nil end
		end
		majInterface()
	end

	local POSITIONS_SEGMENT = { lieux = 0, joueurs = 1, coord = 2, histo = 3 }
	local function changerMode(nouveau)
		S.mode = nouveau
		animer(W.curseur, 0.25, { Position = UDim2.new(POSITIONS_SEGMENT[nouveau] / 4, 3, 0, 3) })
		for nom, bouton in W.segments3 do
			bouton.TextColor3 = nom == nouveau and C.texte or C.texte2
		end
		local enCoord = nouveau == "coord"
		W.liste.Visible = not enCoord
		W.recherche.Visible = not enCoord
		W.panneauCoord.Visible = enCoord
		if enCoord and S.positionPerso then
			S.choix = { type = "position", nom = "Nouvelle localisation" }
		end
		construireListe()
	end
	for nom, bouton in W.segments3 do
		bouton.Activated:Connect(function() changerMode(nom) end)
	end
	W.recherche:GetPropertyChangedSignal("Text"):Connect(construireListe)
	W.boutonCategorie.Activated:Connect(function()
		if not (S.choix and S.choix.type == "lieu") then return end
		local index = (S.categories[S.choix.nom] or 0) + 1
		if index > #(Config.Categories or {}) then index = 0 end
		remote:FireServer("Categorie", { destination = S.choix.nom, index = index })
	end)

	local function choisirFiger(valeur)
		S.figer = valeur
		animer(W.curseurJoueur, 0.25, { Position = valeur and UDim2.new(0.5, 1, 0, 2) or UDim2.fromOffset(2, 2) })
		W.boutonDernierePos.TextColor3 = valeur and C.texte2 or C.texte
		W.boutonSurLui.TextColor3 = valeur and C.texte or C.texte2
		majFiche()
	end
	W.boutonDernierePos.Activated:Connect(function() choisirFiger(false) end)
	W.boutonSurLui.Activated:Connect(function() choisirFiger(true) end)

	--------------------------------------------------------------------
	-- Commandes
	--------------------------------------------------------------------
	-- Destination choisie, au format attendu par le serveur (nil si rien n'est choisi)
	local function optionsDestination()
		return { figer = S.figer, positionPerso = S.positionPerso }
	end
	local function donneesDestination()
		return Commandes.donnees(S.choix, optionsDestination())
	end

	-- La destination choisie est partagée avec les commandes de port (bouton DÉMAT quand on porte le TARDIS)
	task.spawn(function()
		local derniereCle = nil
		while true do
			task.wait(0.2)
			local cle = cleDe(S.choix)
			if cle ~= derniereCle then
				derniereCle = cle
				if S.choix then UI.destinationPoche = { fournir = donneesDestination, nom = S.choix.nom or "?" } end
			end
		end
	end)

	W.demat.Activated:Connect(function()
		if W.demat:GetAttribute("Disponible") == false then
			if exterieur:GetAttribute("Porteur") == joueur.UserId and not S.choix then
				notifier("Choisis d'abord une destination.", false)
			end
			return
		end
		Commandes.demat(S.choix, optionsDestination())
	end)

	W.remat.Activated:Connect(function()
		-- Pendant le compte à rebours de la rematérialisation automatique, un appui la lance tout de suite
		if not Commandes.secondesAutoRemat() and W.remat:GetAttribute("Disponible") == false then
			if (exterieur:GetAttribute("Etat") or E.Pose) == E.Vol and not S.choix then
				notifier("Choisis d'abord une destination.", false)
			end
			return
		end
		Commandes.remat(S.choix, optionsDestination())
	end)

	W.tuiles.camouflage.bouton.Activated:Connect(function()
		if W.tuiles.camouflage.bouton:GetAttribute("Disponible") == false then return end
		remote:FireServer("Camouflage")
	end)
	W.tuiles.verrou.bouton.Activated:Connect(function()
		remote:FireServer("Verrou")
	end)
	W.tuiles.portes.bouton.Activated:Connect(function()
		if W.tuiles.portes.bouton:GetAttribute("Disponible") == false then return end
		remote:FireServer("Portes")
	end)

	remote.OnClientEvent:Connect(notifier)
	Commandes.annonce.Event:Connect(notifier)

	-- Curseur de taille
	local function afficherTaille(facteur)
		local p = (facteur - TAILLE_MIN) / (1 - TAILLE_MIN)
		W.remplissageTaille.Size = UDim2.fromScale(p, 1)
		W.poignee.Position = UDim2.fromScale(p, 0.5)
		W.valeurTaille.Text = math.floor(facteur * 100 + 0.5) .. " %"
		W.valeurTaille.TextColor3 = (facteur < seuilPortes - 0.001) and C.orange or C.ambre
	end

	local function facteurDepuisSouris(x)
		local debut, largeur = W.railTaille.AbsolutePosition.X, W.railTaille.AbsoluteSize.X
		local p = math.clamp((x - debut) / math.max(largeur, 1), 0, 1)
		return math.floor((TAILLE_MIN + p * (1 - TAILLE_MIN)) * 20 + 0.5) / 20 -- par pas de 5 %
	end

	W.pisteTaille.InputBegan:Connect(function(input)
		if W.pisteTaille:GetAttribute("Disponible") == false then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			S.glisseTaille = true
			animer(W.poignee, 0.15, { Size = UDim2.fromOffset(22, 22) })
			S.tailleChoisie = facteurDepuisSouris(input.Position.X)
			afficherTaille(S.tailleChoisie)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not S.glisseTaille then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			S.tailleChoisie = facteurDepuisSouris(input.Position.X)
			afficherTaille(S.tailleChoisie)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if not S.glisseTaille then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			S.glisseTaille = false
			animer(W.poignee, 0.15, { Size = UDim2.fromOffset(18, 18) })
			if math.abs(S.tailleChoisie - (exterieur:GetAttribute("Echelle") or 1)) > 0.01 then
				remote:FireServer("Taille", { facteur = S.tailleChoisie })
			end
		end
	end)
	exterieur:GetAttributeChangedSignal("Echelle"):Connect(function()
		if not S.glisseTaille then
			S.tailleChoisie = exterieur:GetAttribute("Echelle") or 1
			afficherTaille(S.tailleChoisie)
		end
	end)
	afficherTaille(exterieur:GetAttribute("Echelle") or 1)

	return { changerMode = changerMode, choisirFiger = choisirFiger, construireListe = construireListe, donneesDestination = donneesDestination }
end
