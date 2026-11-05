-- StarterPlayerScripts > TardisExtrasClient > Copilote (ModuleScript) — V6.9.1, ajout C2
-- Poste du copilote : un panneau compact, sur le côté droit de l'écran, pour le joueur qu'un pilote a nommé copilote
-- (attribut du joueur TardisCopilote_<nom>, posé par le serveur). Il n'a pas la tablette des pilotes : ce poste lui
-- donne seulement la navigation.
--   • Protocole (Classique, Urgence, Rapide, Sauvetage, Silencieux) et destination (lieu, retour, joueur).
--   • DÉMAT et REMAT (avec la confirmation d'un paradoxe, comme le menu des pilotes).
--   • Pendant le vol libre du pilote : ATTERRIR À DESTINATION, dès que le pilote est passé dans le vortex.
--   • Camouflage, et une note rapide au carnet de bord.
-- Le serveur revérifie tout (TardisServeur : ACTIONS_COPILOTE ; TardisExtras : carnet).

return function(contexte)
	local C, Config, E, Players, UI = contexte.C, contexte.Config, contexte.E, contexte.Players, contexte.UI
	local creer, texte, animer, def = contexte.creer, contexte.texte, contexte.animer, contexte.def
	local exterieur, joueur, remote = contexte.exterieur, contexte.joueur, contexte.remote
	local ATTRIBUT = "TardisCopilote_" .. def.Nom

	--------------------------------------------------------------------
	-- Le panneau
	--------------------------------------------------------------------
	local LARGEUR, HAUTEUR = 360, 650
	local gui = creer("ScreenGui", { Name = "TardisCopilote_" .. def.Nom, ResetOnSpawn = false, Enabled = false, DisplayOrder = 19,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = joueur:WaitForChild("PlayerGui") })
	local panneau = creer("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Size = UDim2.fromOffset(LARGEUR, HAUTEUR),
		BackgroundColor3 = C.fond, Parent = gui }, { UI.coin(18), UI.contour(C.cyan, 1.5, 0.35) })
	local echelle = creer("UIScale", { Parent = panneau })
	UI.lignesEcran(panneau, 40, 0.97)
	local corps = creer("Frame", { Position = UDim2.fromOffset(14, 12), Size = UDim2.new(1, -28, 1, -24), BackgroundTransparency = 1, Parent = panneau }, { UI.pile(8) })

	-- En-tête : titre, TARDIS, bouton pour réduire
	local entete = creer("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = 1, Parent = corps })
	texte({ Text = "POSTE DU COPILOTE", Font = UI.POLICE_TITRE, TextSize = 16, TextColor3 = C.cyan, Size = UDim2.new(1, -40, 0, 20), Parent = entete })
	local sousTitre = texte({ Text = def.Nom, TextSize = 11, TextColor3 = C.texte2, Position = UDim2.fromOffset(0, 21), Size = UDim2.new(1, -40, 0, 16), Parent = entete })
	local reduire = creer("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 2), Size = UDim2.fromOffset(32, 32),
		BackgroundColor3 = C.panneau, Text = "–", Font = UI.POLICE_GRAS, TextSize = 18, TextColor3 = C.texte, Parent = entete }, { UI.coin(8) })

	-- État du TARDIS et du vol libre
	local etat = texte({ Text = "", Font = UI.POLICE_GRAS, TextSize = 13, LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 18), Parent = corps })
	local message = texte({ Text = "Le pilote t'a confié la navigation.", TextSize = 11, TextColor3 = C.texte2, TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Parent = corps })

	-- Protocole
	UI.titreSection(corps, "PROTOCOLE", 4, C.cyan)
	local mode = "Normal"
	local segments = UI.selecteurModes(corps, {
		{ cle = "Normal", nom = "Classique", couleur = Color3.fromRGB(110, 160, 230) },
		{ cle = "Urgence", nom = "Urgence", couleur = UI.couleurMode("Urgence") },
		{ cle = "Express", nom = "Rapide", couleur = UI.couleurMode("Express") },
		{ cle = "Sauvetage", nom = "Sauvetage", couleur = UI.couleurMode("Sauvetage") },
		{ cle = "Silencieux", nom = "Silence", couleur = UI.couleurMode("Silencieux") },
	}, 5, UDim2.new(1, 0, 0, 34))
	local function reglerMode(nouveau)
		mode = nouveau
		for cle, segment in segments do segment.regler(cle == mode) end
	end
	for cle, segment in segments do
		segment.surChangement = function(actif) reglerMode(actif and cle or "Normal") end
	end
	reglerMode("Normal")

	-- Destination
	UI.titreSection(corps, "DESTINATION", 6, C.cyan)
	local choix = nil -- { type = "lieu" | "precedent" | "joueur", nom, id }
	local choixTexte = texte({ Text = "Aucune destination choisie", Font = UI.POLICE_GRAS, TextSize = 12, TextColor3 = C.ambre, LayoutOrder = 7,
		TextTruncate = Enum.TextTruncate.AtEnd, Parent = corps })
	local liste = creer("ScrollingFrame", { Size = UDim2.new(1, 0, 0, 160), BackgroundColor3 = C.ecran, BorderSizePixel = 0, ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.cyan, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, LayoutOrder = 8, Parent = corps },
	{ UI.coin(10), UI.contour(C.bleu, 1, 0.5) })
	local contenuListe = creer("Frame", { Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -16, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1, Parent = liste }, { UI.pile(4) })

	local function donnees()
		if not choix then return nil end
		local d = { mode = mode, invisible = false }
		if choix.type == "lieu" then d.destination = choix.nom
		elseif choix.type == "precedent" then d.precedent = true
		elseif choix.type == "joueur" then d.joueur = choix.id end
		return d
	end

	local remplirListe
	local function ligneDestination(nom, sous, ordre, valeur)
		local actif = choix ~= nil and choix.type == valeur.type and choix.nom == valeur.nom and choix.id == valeur.id
		local b = creer("TextButton", { Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = actif and C.bleu or C.panneau, Text = "", LayoutOrder = ordre,
			Parent = contenuListe }, { UI.coin(6) })
		texte({ Text = nom, Font = UI.POLICE_GRAS, TextSize = 12, Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -90, 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd, Parent = b })
		texte({ Text = sous, TextSize = 10, TextColor3 = C.texte2, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 0), Size = UDim2.new(0, 80, 1, 0), Parent = b })
		b.Activated:Connect(function()
			choix = valeur
			choixTexte.Text = "→ " .. nom
			remplirListe()
		end)
	end
	remplirListe = function()
		for _, enfant in contenuListe:GetChildren() do
			if enfant:IsA("GuiObject") then enfant:Destroy() end
		end
		local ordre = 0
		local precedent = exterieur:GetAttribute("PrecedentNom")
		if precedent then
			ordre += 1
			ligneDestination("Retour : " .. precedent, "précédent", ordre, { type = "precedent", nom = precedent })
		end
		for nom in string.gmatch(exterieur:GetAttribute("ListeDestinations") or "", "[^\n]+") do
			ordre += 1
			ligneDestination(nom, "lieu", ordre, { type = "lieu", nom = nom })
		end
		for _, autre in Players:GetPlayers() do
			if autre ~= joueur then
				ordre += 1
				ligneDestination(autre.DisplayName, "joueur", ordre, { type = "joueur", nom = autre.DisplayName, id = autre.UserId })
			end
		end
	end

	-- Commandes de voyage
	local rangee = creer("Frame", { Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1, LayoutOrder = 9, Parent = corps }, { UI.pile(8, true) })
	local boutonDemat = UI.boutonPrincipal(rangee, "DÉMAT", "Décoller", 1, UDim2.new(0.5, -4, 1, 0))
	local boutonRemat = UI.boutonPrincipal(rangee, "REMAT", "À destination", 2, UDim2.new(0.5, -4, 1, 0))
	local boutonAtterrir = UI.boutonPrincipal(corps, "ATTERRIR À DESTINATION", "Vol libre : une fois dans le vortex", 10, UDim2.new(1, 0, 0, 46))
	local camouflage = UI.interrupteur(corps, "Camouflage", "La cabine se fond dans le décor", C.cyan, 11)

	-- Note rapide au carnet de bord (sur le lieu actuel)
	UI.titreSection(corps, "CARNET DE BORD", 12, C.ambre)
	local note = creer("TextBox", { Size = UDim2.new(1, -78, 0, 32), BackgroundColor3 = C.panneau, Text = "", PlaceholderText = "Note sur ce lieu…",
		Font = UI.POLICE, TextSize = 12, TextColor3 = C.texte, PlaceholderColor3 = C.texte2, ClearTextOnFocus = false, TextTruncate = Enum.TextTruncate.AtEnd,
		LayoutOrder = 1, Parent = nil }, { UI.coin(8), UI.marges(6) })
	local rangeeNote = creer("Frame", { Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, LayoutOrder = 13, Parent = corps }, { UI.pile(6, true) })
	note.Parent = rangeeNote
	local ecrire = creer("TextButton", { Size = UDim2.fromOffset(72, 32), BackgroundColor3 = C.bleu, Text = "Écrire", Font = UI.POLICE_GRAS, TextSize = 12,
		TextColor3 = C.texte, LayoutOrder = 2, Parent = rangeeNote }, { UI.coin(8) })

	-- Onglet affiché quand le panneau est réduit
	local onglet = creer("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Size = UDim2.fromOffset(150, 40),
		BackgroundColor3 = C.fond, Text = "◆  COPILOTE", Font = UI.POLICE_GRAS, TextSize = 13, TextColor3 = C.cyan, Visible = false, Parent = gui },
	{ UI.coin(12), UI.contour(C.cyan, 1.5, 0.35) })
	reduire.Activated:Connect(function() panneau.Visible = false onglet.Visible = true end)
	onglet.Activated:Connect(function() panneau.Visible = true onglet.Visible = false end)

	--------------------------------------------------------------------
	-- Mise à jour
	--------------------------------------------------------------------
	local paradoxeJusqua = nil
	local derniereDemande = nil
	-- Grise ou réactive un bouton seulement quand son état change (pas une animation tous les quarts de seconde)
	local etatsBoutons = {}
	local function disponible(bouton, valeur)
		if etatsBoutons[bouton] == valeur then return end
		etatsBoutons[bouton] = valeur
		UI.setDisponible(bouton, valeur, C.bleu)
	end

	local function maj()
		local e = exterieur:GetAttribute("Etat") or E.Pose
		local libelle = UI.LIBELLES[e] or { "?", C.texte2 }
		local volLibre = exterieur:GetAttribute("VolLibre")
		local phase = exterieur:GetAttribute("VolPhase")
		if volLibre then
			local pilote = Players:GetPlayerByUserId(volLibre)
			etat.Text = "VOL LIBRE  ·  " .. (pilote and pilote.DisplayName or "pilote") .. (phase == "Invisible" and "  ·  dans le vortex" or "  ·  visible")
			etat.TextColor3 = phase == "Invisible" and C.cyan or C.ambre
		else
			etat.Text = libelle[1]
			etat.TextColor3 = libelle[2]
		end
		sousTitre.Text = def.Nom .. "  ·  " .. tostring(exterieur:GetAttribute("Position") or "?")
		local alimente = exterieur:GetAttribute("Alimentation") ~= false
		disponible(boutonDemat, alimente and not volLibre and e == E.Pose)
		local arme = paradoxeJusqua ~= nil and os.clock() < paradoxeJusqua
		if arme then
			etatsBoutons[boutonRemat] = nil -- à la fin de la confirmation, la couleur est remise
			UI.confirmationBouton(boutonRemat, true)
		else
			UI.confirmationBouton(boutonRemat, false)
			disponible(boutonRemat, alimente and not volLibre and e == E.Vol and choix ~= nil)
		end
		boutonAtterrir.Visible = volLibre ~= nil
		disponible(boutonAtterrir, volLibre ~= nil and phase == "Invisible" and choix ~= nil)
		camouflage.regler(exterieur:GetAttribute("Camouflage") == true)
	end

	local function envoyer(action, d)
		derniereDemande = d
		remote:FireServer(action, d)
	end
	boutonDemat.Activated:Connect(function()
		if boutonDemat:GetAttribute("Disponible") == false then return end
		envoyer("Demat", { mode = mode })
	end)
	boutonRemat.Activated:Connect(function()
		if boutonRemat:GetAttribute("Disponible") == false then return end
		if paradoxeJusqua and os.clock() < paradoxeJusqua and derniereDemande then
			local d = table.clone(derniereDemande)
			d.forcer = true
			paradoxeJusqua = nil
			envoyer("Remat", d)
			return
		end
		local d = donnees()
		if d then envoyer("Remat", d) end
	end)
	boutonAtterrir.Activated:Connect(function()
		if boutonAtterrir:GetAttribute("Disponible") == false then return end
		local d = donnees()
		if d then envoyer("NavAtterrir", d) end
	end)
	camouflage.surChangement = function()
		remote:FireServer("Camouflage")
		task.delay(0.5, maj)
	end
	ecrire.Activated:Connect(function()
		local n = utf8.len(note.Text) or 0
		if n < 2 then return end
		remote:FireServer("CarnetEcrire", { texte = string.sub(note.Text, 1, utf8.offset(note.Text, math.min(n, (Config.Carnet or {}).LongueurMax or 200) + 1) - 1),
			lieu = exterieur:GetAttribute("Position") })
		note.Text = ""
	end)

	-- Réponses du serveur (seulement quand le poste est ouvert)
	remote.OnClientEvent:Connect(function(texteRecu, ok)
		if not gui.Enabled or typeof(texteRecu) ~= "string" then return end
		if texteRecu == "__paradoxe" then
			paradoxeJusqua = os.clock() + 15
			UI.son("Alerte")
			message.Text = "Paradoxe : la destination est dans le TARDIS. Clique encore sur REMAT pour forcer l'atterrissage."
			message.TextColor3 = C.rouge
			return
		end
		if string.sub(texteRecu, 1, 2) == "__" then return end -- (V6.9.10.1, relecture) messages techniques (« __console »…)
		message.Text = texteRecu
		message.TextColor3 = ok and C.vert or (ok == false and C.rouge or C.texte2)
	end)

	-- Ouverture : le poste n'existe que pour le copilote
	local function majAcces()
		local copilote = joueur:GetAttribute(ATTRIBUT) == true
		if copilote and not gui.Enabled then
			table.clear(etatsBoutons)
			paradoxeJusqua = nil
			panneau.Visible, onglet.Visible = true, false
			message.Text, message.TextColor3 = "Le pilote t'a confié la navigation.", C.texte2
			choix = nil
			choixTexte.Text = "Aucune destination choisie"
			reglerMode("Normal")
			remplirListe()
			UI.son("Notification")
		end
		gui.Enabled = copilote
	end
	joueur:GetAttributeChangedSignal(ATTRIBUT):Connect(majAcces)
	majAcces()
	for _, attribut in { "ListeDestinations", "PrecedentNom" } do
		exterieur:GetAttributeChangedSignal(attribut):Connect(function() if gui.Enabled then remplirListe() end end)
	end
	Players.PlayerAdded:Connect(function() if gui.Enabled then remplirListe() end end)
	Players.PlayerRemoving:Connect(function(autre)
		if choix and choix.type == "joueur" and choix.id == autre.UserId then choix = nil choixTexte.Text = "Aucune destination choisie" end
		if gui.Enabled then task.defer(remplirListe) end
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			if gui.Enabled then
				echelle.Scale = math.clamp(workspace.CurrentCamera.ViewportSize.Y / (HAUTEUR + 60), 0.55, 1)
				maj()
			end
		end
	end)
end
