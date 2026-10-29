-- StarterPlayerScripts > TardisTablette > Volet (ModuleScript)
-- Réglages, aide et volet latéral
-- Extrait du script principal en V6.6.3 : reçoit ce qu'il utilise, renvoie ce que la suite utilise.

return function(contexte)
	local C, Commandes, Config, R, S, UI = contexte.C, contexte.Commandes, contexte.Config, contexte.R, contexte.S, contexte.UI
	local UserInputService, V, W, creer, def, exterieur = contexte.UserInputService, contexte.V, contexte.W, contexte.creer, contexte.def, contexte.exterieur
	local joueur, ouvrir, texte = contexte.joueur, contexte.ouvrir, contexte.texte

	--------------------------------------------------------------------
	-- Réglages (thème de l'interface, sons, touches) et aide intégrée
	--------------------------------------------------------------------
	-- Volet latéral : un panneau qui s'ouvre à droite de la tablette (outils, réglages, aide).
	-- V.ouvrir(nom, titre) affiche une page vide et renvoie son conteneur ; V.retour() revient aux outils ; V.fermer() le range.
	do
		local volet = creer("Frame", { Position = UDim2.new(1, 14, 0, 0), Size = UDim2.new(0, 440, 1, 0), BackgroundColor3 = C.ecran,
			BackgroundTransparency = 0.02, Visible = false, ZIndex = 60, Parent = W.tablette }, { UI.coin(22), UI.contour(C.ambre, 2, 0.25), UI.marges(16) })
		creer("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.blanc, Color3.fromRGB(170, 180, 205)), Parent = volet })
		local titre = texte({ Text = "", Font = UI.POLICE_GRAS, TextSize = 16, TextColor3 = C.ambre, Size = UDim2.new(1, -40, 0, 24), ZIndex = 61, Parent = volet })
		local croix = creer("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, -4), Size = UDim2.fromOffset(32, 32),
			BackgroundColor3 = Color3.fromRGB(90, 30, 40), Text = "×", Font = UI.POLICE_GRAS, TextSize = 22, TextColor3 = C.texte, ZIndex = 61, Parent = volet },
		{ UI.coin(9), UI.contour(C.rouge, 1, 0.4) })
		croix:SetAttribute("CouleurBase", Color3.fromRGB(90, 30, 40))
		UI.rendreVivant(croix)
		-- Accueil : la grille des outils
		local accueil = creer("ScrollingFrame", { Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 1, -34), BackgroundTransparency = 1, BorderSizePixel = 0,
			ScrollBarThickness = 5, ScrollBarImageColor3 = C.ambre, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 61, Parent = volet })
		local grille = creer("Frame", { Size = UDim2.new(1, -12, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ZIndex = 61, Parent = accueil },
		{ UI.pile(8) })
		-- Pages : le contenu d'un outil, des réglages ou de l'aide
		local defilement = creer("ScrollingFrame", { Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 1, -76), BackgroundTransparency = 1,
			BorderSizePixel = 0, ScrollBarThickness = 5, ScrollBarImageColor3 = C.ambre, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
			Visible = false, ZIndex = 61, Parent = volet })
		local contenu = creer("Frame", { Size = UDim2.new(1, -12, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
			ZIndex = 61, Parent = defilement }, { UI.pile(8) })
		local retourBtn = creer("TextButton", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 34),
			BackgroundColor3 = C.panneauClair, Text = "◄  Retour aux outils", Font = UI.POLICE_GRAS, TextSize = 13, TextColor3 = C.texte, Visible = false,
			ZIndex = 61, Parent = volet }, { UI.coin(8) })
		retourBtn:SetAttribute("CouleurBase", C.panneauClair)
		UI.rendreVivant(retourBtn)
		local surcouche = volet
		V.grille = grille
		V.actif = nil

		local function vider()
			for _, e in contenu:GetChildren() do
				if not e:IsA("UIListLayout") then e:Destroy() end
			end
		end
		function V.ouvrir(nom, nouveauTitre)
			vider()
			titre.Text = nouveauTitre or ""
			accueil.Visible = false
			defilement.Visible = true
			retourBtn.Visible = true
			volet.Visible = true
			V.actif = nom
			V.majDisposition()
			return contenu
		end
		function V.retour()
			vider()
			titre.Text = "◆  OUTILS DU TARDIS"
			accueil.Visible = true
			defilement.Visible = false
			retourBtn.Visible = false
			volet.Visible = true
			V.actif = "outils"
			V.majDisposition()
		end
		function V.fermer()
			volet.Visible = false
			V.actif = nil
			V.majDisposition()
		end
		croix.Activated:Connect(V.fermer)
		retourBtn.Activated:Connect(V.retour)
		W.btnOutils.Activated:Connect(function() if V.actif == "outils" then V.fermer() else V.retour() end end)
		W.boutonOutilsDock.Activated:Connect(V.retour)

		local function ligne(txt, ordre, couleur, taille)
			return texte({ Text = txt, TextSize = taille or 13, TextColor3 = couleur or C.texte, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = ordre, ZIndex = 62, Parent = contenu })
		end
		local function boutonLigne(txt, ordre, couleur, action)
			local b = creer("TextButton", { Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = couleur or C.panneauClair, Text = txt, Font = UI.POLICE_GRAS,
				TextSize = 13, TextColor3 = C.texte, LayoutOrder = ordre, ZIndex = 62, Parent = contenu }, { UI.coin(8) })
			b:SetAttribute("CouleurBase", couleur or C.panneauClair)
			UI.rendreVivant(b)
			b.Activated:Connect(action)
			return b
		end
		V.ligne, V.bouton = ligne, boutonLigne
		local function ligne(txt, ordre, couleur, taille)
			return texte({ Text = txt, TextSize = taille or 13, TextColor3 = couleur or C.texte, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = ordre, ZIndex = 62, Parent = contenu })
		end
		local function boutonLigne(txt, ordre, couleur, action)
			local b = creer("TextButton", { Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = couleur or C.panneauClair, Text = txt, Font = UI.POLICE_GRAS,
				TextSize = 13, TextColor3 = C.texte, LayoutOrder = ordre, ZIndex = 62, Parent = contenu }, { UI.coin(8) })
			b:SetAttribute("CouleurBase", couleur or C.panneauClair)
			UI.rendreVivant(b)
			b.Activated:Connect(action)
			return b
		end

		local TOUCHES = {
			{ "menu", "Ouvrir le menu classique", "T" }, { "tablette", "Ouvrir la tablette", "Y" },
			{ "porterMode", "Porter : changer de mode", "V" }, { "porterPoser", "Porter : poser", "G" }, { "porterDemat", "Porter : téléportation de poche", "X" },
			{ "volVitesse", "Vol : vitesse suivante", "F" }, { "volUrgence", "Vol : urgence", "U" }, { "volVortex", "Vol : vortex", "V" },
			{ "volSaut", "Vol : saut temporel", "B" }, { "volPortes", "Vol : portes", "O" }, { "volDemat", "Vol : démat / remat", "X" },
			{ "volPoser", "Vol : se poser", "G" }, { "volTonneau", "Vol : tonneau", "C" }, { "volFrein", "Vol : frein", "LeftControl" },
			{ "volTracteur", "Vol : rayon tracteur", "R" }, { "volCamouflage", "Vol : camouflage", "K" },
			{ "volStationnaire", "Vol : stationnaire", "H" }, { "volSiege", "Vol : siège extérieur", "I" }, { "volBoost", "Vol : boost", "LeftShift" },
			{ "volAtterrir", "Vol : atterrir ici", "N" }, { "volPlaneur", "Vol : planeur", "J" }, { "volCible", "Vol : verrouillage de cible", "L" },
			{ "volPrecision", "Vol : précision", "P" }, { "volCap", "Vol : cap fixe", "M" },
		}
		local enAttente = nil
		local afficherReglages
		afficherReglages = function()
			V.ouvrir("reglages", "RÉGLAGES")
			local ordre = 0
			-- Taille de l'interface
			ordre += 1
			ligne("TAILLE DE L'INTERFACE", ordre, C.texte2, 11)
			ordre += 1
			local rangeeTaille = creer("Frame", { Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, LayoutOrder = ordre, ZIndex = 62, Parent = contenu },
			{ creer("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
			for i, info in { { "-", -0.1 }, { "Normale", 0 }, { "+", 0.1 } } do
				local b = creer("TextButton", { Size = UDim2.new(info[2] == 0 and 0.5 or 0.25, -6, 1, 0), BackgroundColor3 = C.panneauClair,
					Text = info[2] == 0 and string.format("Normale  ·  %d %%", UI.tailleInterface() * 100) or info[1], Font = UI.POLICE_GRAS, TextSize = 13,
					TextColor3 = C.texte, LayoutOrder = i, ZIndex = 62, Parent = rangeeTaille }, { UI.coin(8) })
				b:SetAttribute("CouleurBase", C.panneauClair)
				UI.rendreVivant(b)
				b.Activated:Connect(function()
					UI.setPref("taille", info[2] == 0 and 1 or math.clamp(UI.tailleInterface() + info[2], 0.6, 1.4))
					afficherReglages()
				end)
			end
			-- Volume
			ordre += 1
			ligne("VOLUME DES SONS DU TARDIS", ordre, C.texte2, 11)
			ordre += 1
			local rangeeVolume = creer("Frame", { Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, LayoutOrder = ordre, ZIndex = 62, Parent = contenu },
			{ creer("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
			for i, niveau in { 0, 0.25, 0.5, 0.75, 1 } do
				local b = creer("TextButton", { Size = UDim2.new(0.2, -5, 1, 0), BackgroundColor3 = math.abs(UI.volume() - niveau) < 0.01 and C.bleu or C.panneauClair,
					Text = string.format("%d %%", niveau * 100), Font = UI.POLICE_GRAS, TextSize = 12, TextColor3 = C.texte, LayoutOrder = i, ZIndex = 62,
					Parent = rangeeVolume }, { UI.coin(8) })
				b:SetAttribute("CouleurBase", b.BackgroundColor3)
				UI.rendreVivant(b)
				b.Activated:Connect(function() UI.setPref("volume", niveau) afficherReglages() end)
			end
			-- Options
			ordre += 1
			ligne("OPTIONS", ordre, C.texte2, 11)
			ordre += 1
			boutonLigne(UI.pref("confirmations", true) ~= false and "Confirmation des actions dangereuses : activée" or "Confirmation des actions dangereuses : désactivée",
				ordre, nil, function() UI.setPref("confirmations", UI.pref("confirmations", true) == false) afficherReglages() end)
			ordre += 1
			boutonLigne(UI.pref("debutant", false) and "Mode débutant : activé (l'essentiel seulement)" or "Mode débutant : désactivé", ordre,
				UI.pref("debutant", false) and C.bleu or nil, function() UI.setPref("debutant", not UI.pref("debutant", false)) afficherReglages() end)
			ordre += 1
			boutonLigne(UI.pref("modeVoyage", "auto") == "auto" and "Mode de voyage : automatique (destination, DEMAT, 15 s de vortex, REMAT seul)"
				or "Mode de voyage : manuel (DEMAT, choix dans le vortex, REMAT)", ordre, nil,
				function() UI.setPref("modeVoyage", UI.pref("modeVoyage", "auto") == "auto" and "manuel" or "auto") Commandes.annulerAutoRemat() afficherReglages() end)
			ordre += 1
			boutonLigne(UI.pref("tri", "nom") == "distance" and "Tri des lieux : par distance" or "Tri des lieux : par nom", ordre, nil,
				function() UI.setPref("tri", UI.pref("tri", "nom") == "distance" and "nom" or "distance") afficherReglages() end)
			ordre += 1
			local formes = { grille = "grille", anneaux = "anneaux", spirale = "spirale" }
			local forme = UI.pref("formeVortex", "grille")
			boutonLigne("Forme du vortex : " .. (formes[forme] or "grille") .. "  (clique pour changer)", ordre, nil, function()
				local suivante = { grille = "anneaux", anneaux = "spirale", spirale = "grille" }
				UI.setPref("formeVortex", suivante[forme] or "grille")
				afficherReglages()
			end)
			-- Widgets
			ordre += 1
			ligne("PANNEAUX AFFICHÉS (WIDGETS)", ordre, C.texte2, 11)
			local nomsWidgets = { statut = "Statut", telemetrie = "Télémétrie", flux = "Commandes rapides", navigation = "Navigation", scanner = "Scanner",
				occupants = "Occupants", journal = "Journal de bord" }
			for _, nom in UI.WIDGETS do
				ordre += 1
				local actif = type(UI.prefs.widgets) ~= "table" or UI.prefs.widgets[nom] ~= false
				boutonLigne((actif and "●  " or "○  ") .. nomsWidgets[nom], ordre, actif and C.panneauClair or C.fond, function()
					UI.prefs.widgets = type(UI.prefs.widgets) == "table" and UI.prefs.widgets or {}
					UI.prefs.widgets[nom] = not actif
					UI.setPref("widgets", UI.prefs.widgets)
					afficherReglages()
				end)
			end
			-- Statistiques
			ordre += 1
			ligne("STATISTIQUES", ordre, C.texte2, 11)
			local ok, st = pcall(function() return game:GetService("HttpService"):JSONDecode(joueur:GetAttribute("TardisStats") or "{}") end)
			st = ok and type(st) == "table" and st or {}
			local passagers = {}
			for nom in st.passagers or {} do table.insert(passagers, nom) end
			table.sort(passagers)
			ordre += 1
			ligne(string.format("Mes voyages : %d   ·   Temps de vol libre : %s   ·   Voyages sur le serveur : %d",
				st.voyages or 0, UI.formatTemps(st.tempsVol or 0), exterieur:GetAttribute("StatsServeur") or 0), ordre, C.texte, 12)
			ordre += 1
			ligne("Ont voyagé avec moi : " .. (#passagers > 0 and table.concat(passagers, ", ") or "personne pour l'instant"), ordre, C.texte2, 12)
			ordre += 1
			ligne("THÈME DE L'INTERFACE", ordre, C.texte2, 11)
			-- (le volet est déjà visible)
			for _, nom in UI.ORDRE_THEMES do
				ordre += 1
				boutonLigne(UI.THEMES[nom].nom or nom, ordre, UI.pref("theme", "Cristal") == nom and C.bleu or nil, function()
					UI.appliquerTheme(nom)
					UI.setPref("theme", nom)
					afficherReglages()
				end)
			end
			ordre += 1
			ligne("SONS", ordre, C.texte2, 11)
			ordre += 1
			boutonLigne(UI.pref("sons", true) and "Sons de notification : activés" or "Sons de notification : coupés", ordre, nil, function()
				UI.setPref("sons", not UI.pref("sons", true))
				afficherReglages()
			end)
			ordre += 1
			ligne("TOUCHES  ·  clique sur une ligne puis appuie sur la nouvelle touche (Échap pour annuler)", ordre, C.texte2, 11)
			for _, info in TOUCHES do
				ordre += 1
				local actuelle = UI.touche(info[1], Enum.KeyCode[info[3]])
				local b
				b = boutonLigne(info[2] .. "   ·   " .. actuelle.Name, ordre, nil, function()
					enAttente = info[1]
					b.Text = info[2] .. "   ·   appuie sur une touche…"
				end)
			end
			ordre += 1
			boutonLigne("Rétablir les touches par défaut", ordre, Color3.fromRGB(110, 40, 50), function()
				UI.prefs.touches = {}
				UI.sauverPrefs()
				afficherReglages()
			end)
		end
		UserInputService.InputBegan:Connect(function(input)
			if not enAttente or input.UserInputType ~= Enum.UserInputType.Keyboard then return end
			if input.KeyCode ~= Enum.KeyCode.Escape and input.KeyCode ~= Enum.KeyCode.Unknown then
				UI.setTouche(enAttente, input.KeyCode)
			end
			enAttente = nil
			afficherReglages()
		end)
		W.btnReglages.Activated:Connect(afficherReglages)

		-- Export du journal : du markdown à sélectionner puis copier avec Ctrl+C
		W.exporter.Activated:Connect(function()
			V.ouvrir("export", "JOURNAL DE BORD  ·  EXPORT")
			ligne("Clique dans la zone, Ctrl+A puis Ctrl+C pour copier.", 1, C.texte2, 11)
			local lignesMd = { "# Journal de bord du TARDIS", "", "| Heure | Événement |", "|---|---|" }
			for i = #S.journalEntrees, 1, -1 do
				local e = S.journalEntrees[i]
				table.insert(lignesMd, string.format("| %s | %s |", e.heure, e.message))
			end
			creer("TextBox", { Size = UDim2.new(1, 0, 0, 420), BackgroundColor3 = C.fond, Text = table.concat(lignesMd, "\n"), TextEditable = false,
				ClearTextOnFocus = false, MultiLine = true, TextWrapped = true, Font = UI.POLICE_CODE, TextSize = 11, TextColor3 = C.texte,
				TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 2, ZIndex = 62, Parent = contenu },
			{ UI.coin(8), UI.contour(C.bleu, 1, 0.5), creer("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingTop = UDim.new(0, 6) }) })
		end)

		W.btnAide.Activated:Connect(function()
			V.ouvrir("aide", "AIDE")
			local aide = {
				{ "MENUS", "T : menu classique · Y : tablette (la croix rouge la ferme) · E sur la console et devant les portes." },
				{ "VOYAGER", "Choisis une destination (lieu, joueur, coordonnées, historique, retour), puis Dématérialiser et Matérialiser. Urgence et Invisible sont des options." },
				{ "PORTER", "Quand il est réduit : E pour le ramasser, V pour changer de mode, G pour le poser, X pour la téléportation de poche vers la destination choisie." },
				{ "VOL LIBRE", "Tuile Vol libre. Regarde où tu veux aller. F vitesse · U urgence · V vortex · B saut · O portes · X démat/remat · C tonneau · Ctrl frein · R rayon tracteur · Espace ×2 chute · G se poser." },
				{ "ROTATION", "Tuile Rotation du menu : positionne le fantôme, puis DÉMAT + REMAT AUTO. Fantôme rouge = atterrissage d'urgence." },
				{ "OUTILS", "Rappel, minuterie, leurre, fiche d'anomalie, registre et expulsion, thème de l'intérieur, projecteur, cabine, replay : dans le menu classique, section Outils." },
				{ "BALISE", "N'importe quel joueur peut appeler le TARDIS avec la commande " .. ((Config.Balise or {}).Commande or "/balisehelp") .. " dans le chat. Les pilotes la voient sur la mini-carte." },
				{ "BOUCLIERS", "Anti-joueurs (personne n'approche) et anti-balles (les tirs s'arrêtent). TARDIS posé et alimenté uniquement." },
			}
			for i, bloc in aide do
				ligne(bloc[1], i * 2 - 1, C.ambre, 11)
				ligne(bloc[2], i * 2, C.texte, 12)
			end
		end)
	end

	-- Touche Y : ouvre la tablette. Seule la croix rouge la ferme.
	UserInputService.InputBegan:Connect(function(input, traite)
		if traite or S.placement or input.KeyCode ~= UI.touche("tablette", R.TOUCHE) then return end
		if joueur:GetAttribute("TardisPilote_" .. def.Nom) ~= true or exterieur:GetAttribute("VolLibre") == joueur.UserId then return end
		if not S.ouvert then ouvrir() end
	end)

	return {}
end
