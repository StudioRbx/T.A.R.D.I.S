-- StarterPlayerScripts > TardisExtrasClient > Console (ModuleScript)
-- Commandes de la console qui ouvrent un panneau (V6.9.10.1). Le serveur décide qui peut, ce module ne fait qu'afficher :
--   « __energie » : menu de gestion de l'énergie (clic sur Console › Ecran-Ingenieure, pilotes et ingénieurs) :
--     intégrité, énergie, boucliers, et la régulation (énergie, air, vapeur) par l'action existante « Tech / Reguler » ;
--   « __jukebox » : panneau du jukebox (Console › JukeBox, pilotes) : pistes et playlists de Config.Jukebox et du dossier
--     ReplicatedStorage › TardisAssets › Jukebox (V6.9.10.5, Config.pistesJukebox), par l'action existante « Jukebox » ;
--   « __console » : un message court (« Réservé aux pilotes. »…) en bas de l'écran.
-- Chaque panneau se ferme avec son bouton, Échap, ou en s'éloignant de l'objet. Aucune boucle par image : mises à jour
-- sur les changements d'attributs, et une vérification de la distance toutes les 0,5 s tant qu'un panneau est ouvert.
-- V6.9.10.7 : charte « Hologramme de confinement » (maquettes GESTION DE L'ÉNERGIE, JUKEBOX et NOTIFICATIONS) :
--   • menu de l'énergie plus grand (440 px de large avant l'échelle, qui suit l'écran comme la tablette technicien) :
--     plaque « GESTION DE L'ÉNERGIE », badge C.T.A.T., « OBJ. TARDIS-01 · ÉCRAN INGÉNIEUR », bande de danger (rouge
--     pendant l'alerte) ; ÉTAT (intégrité et PV, alimentation, boucliers) et RÉGULATION (énergie cyan, air jaune, vapeur)
--     en jauges à 10 segments, boutons − / + à coins coupés de 44 px ; « FERMER (ÉCHAP) » ;
--   • jukebox en tableau N° | PISTE | DURÉE (CATÉGORIE si une durée est inconnue), la piste ou la playlist qui joue en
--     jaune, la ligne choisie en cyan léger, puis JOUER (principal), PLAYLIST, ARRÊTER (danger) ; volume en segments ;
--   • le message de la console est une notification de la charte (badge TARDIS, ou REFUSÉ).
-- V6.9.16 : menu de l'énergie élargi (760 px) en deux colonnes : ÉTAT (intégrité, alimentation, boucliers, alerte,
--   démarrage, portes) et PANNES EN COURS à gauche ; RÉGULATION à droite, chaque réglage avec son état et sa plage.

return function(contexte)
	local C, Config, UI, UserInputService = contexte.C, contexte.Config, contexte.UI, contexte.UserInputService
	local creer, texte = contexte.creer, contexte.texte
	local def, exterieur, interieur, joueur, maRacine, remote = contexte.def, contexte.exterieur, contexte.interieur, contexte.joueur, contexte.maRacine, contexte.remote
	local camera = contexte.camera
	local TECH = Config.Technicien or {}
	local REGLAGES = Config.EcranIngenieur or {}
	local PAS = math.max(tonumber(REGLAGES.Pas) or 5, 1)
	local playerGui = joueur:WaitForChild("PlayerGui")
	local FACE_DONNEES_GRAS = nil -- Roboto Mono en gras (valeurs des jauges), si la plateforme le permet
	pcall(function() FACE_DONNEES_GRAS = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold) end)
	local function valeurGrasse(label)
		if FACE_DONNEES_GRAS then pcall(function() label.FontFace = FACE_DONNEES_GRAS end) end
		return label
	end

	--------------------------------------------------------------------
	-- Message court de la console (en bas de l'écran, 3 s) : notification de la charte
	--------------------------------------------------------------------
	local guiMessage = creer("ScreenGui", { Name = "TardisConsoleMessage", ResetOnSpawn = false, DisplayOrder = 20, Parent = playerGui })
	local notifMessage = UI.notification({ Name = "MessageConsole", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -110),
		Size = UDim2.fromOffset(420, 0), Parent = guiMessage }, { tailleTexte = 14 })
	local echelleMessage = creer("UIScale", { Scale = UI.tailleInterface(), Parent = notifMessage.cadre })
	local jetonMessage = 0
	local function afficherMessage(message, ok)
		jetonMessage += 1
		local moi = jetonMessage
		notifMessage.regler(tostring(message), ok and "info" or "refus")
		echelleMessage.Scale = UI.tailleInterface()
		notifMessage.cadre.Visible = true
		notifMessage.cadre.Position = UDim2.new(0.5, 0, 1, -90)
		UI.animer(notifMessage.cadre, 0.3, { Position = UDim2.new(0.5, 0, 1, -110) }, Enum.EasingStyle.Back)
		UI.son(ok and "Notification" or "Alerte")
		task.delay(3, function()
			if moi == jetonMessage then notifMessage.cadre.Visible = false end
		end)
	end

	--------------------------------------------------------------------
	-- Cadre commun des panneaux : panneau de la charte (coins coupés, filet cyan, lueur, balayage), centré, à taille fixe
	-- avant l'échelle ; le contenu est une pile (marges de 18 px). L'échelle suit la taille de l'écran (à l'ouverture et
	-- quand la fenêtre change) et la taille de l'interface des réglages.
	--------------------------------------------------------------------
	local panneaux = {} -- [gui] = { cadre, echelle, largeur, hauteur }
	local function panneau(nom, largeur, hauteur)
		local gui = creer("ScreenGui", { Name = nom, ResetOnSpawn = false, Enabled = false, DisplayOrder = 15, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			Parent = playerGui })
		local carte, contenu = UI.panneauCoupe({ Name = "Carte", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(largeur, hauteur), BackgroundColor3 = C.fond, BackgroundTransparency = 0.04, Parent = gui },
			{ coupe = 16, rayon = 16, marges = 18, pile = 10 })
		local echelle = creer("UIScale", { Scale = UI.tailleInterface(), Parent = carte })
		panneaux[gui] = { cadre = carte, echelle = echelle, largeur = largeur, hauteur = hauteur }
		return gui, carte, contenu
	end
	-- Taille de l'écran (pixels), ou nil (caméra pas encore là)
	local function tailleEcran()
		local ok, taille = pcall(function() return (camera or workspace.CurrentCamera).ViewportSize end)
		if ok and typeof(taille) == "Vector2" and taille.X > 0 and taille.Y > 0 then return taille end
		return nil
	end
	local function majEchelle(gui)
		local p = panneaux[gui]
		if not p then return end
		local taille = tailleEcran()
		local base = taille and math.clamp(math.min(taille.X * 0.92 / p.largeur, taille.Y * 0.86 / p.hauteur), 0.5, 1.15) or 1
		p.echelle.Scale = base * UI.tailleInterface()
	end

	-- Le panneau ouvert : { gui, part, fermer } ; un seul à la fois
	local ouvert = nil
	local function fermerPanneau()
		if not ouvert then return end
		local p = ouvert
		ouvert = nil
		p.gui.Enabled = false
	end
	local function ouvrirPanneau(gui, part, distance)
		fermerPanneau()
		-- Sans la pièce (pas encore chargée, Streaming), la distance se mesure depuis l'endroit où le panneau a été ouvert
		local racineOuverture = maRacine()
		ouvert = { gui = gui, part = part, distance = distance, origine = racineOuverture and racineOuverture.Position }
		majEchelle(gui)
		gui.Enabled = true
		-- Fermeture en s'éloignant de l'objet (toutes les 0,5 s, seulement tant que ce panneau est ouvert)
		local moi = ouvert
		task.spawn(function()
			while ouvert == moi do
				task.wait(0.5)
				if ouvert ~= moi then break end
				local racine = maRacine()
				local reference = (moi.part and moi.part.Parent and moi.part.Position) or moi.origine
				if not racine or (reference and (racine.Position - reference).Magnitude > moi.distance) then
					fermerPanneau()
				end
			end
		end)
	end
	UserInputService.InputBegan:Connect(function(input)
		if ouvert and input.KeyCode == Enum.KeyCode.Escape then fermerPanneau() end
	end)
	-- La fenêtre change de taille : le panneau ouvert suit (aucune boucle)
	pcall(function()
		(camera or workspace.CurrentCamera):GetPropertyChangedSignal("ViewportSize"):Connect(function()
			if ouvert then majEchelle(ouvert.gui) end
		end)
	end)

	--------------------------------------------------------------------
	-- Menu de gestion de l'énergie (écran ingénieur)
	--------------------------------------------------------------------
	-- (V6.9.16) Plus large (760 px avant l'échelle, 440 avant) et plus détaillé, en deux colonnes : à gauche l'ÉTAT
	-- (intégrité, alimentation, boucliers, alerte, démarrage, portes) et les PANNES EN COURS ; à droite la RÉGULATION,
	-- chaque réglage avec son état (nominal, sous-tension, surtension, air vicié, fuite de vapeur) et sa plage.
	local LARGEUR_ENERGIE, HAUTEUR_ENERGIE = 760, 640
	local HAUTEUR_COLONNES = 432
	local guiEnergie, _, corpsEnergie = panneau("TardisMenuEnergie", LARGEUR_ENERGIE, HAUTEUR_ENERGIE)
	UI.plaque(corpsEnergie, "Gestion de l'énergie", UI.texteBadge("Energie", "C.T.A.T."), UI.codeObjet(def) .. "  ·  ÉCRAN INGÉNIEUR",
		{ ordre = 1, largeurBande = LARGEUR_ENERGIE, exterieur = exterieur })
	local colonnes = creer("Frame", { Name = "Colonnes", Size = UDim2.new(1, 0, 0, HAUTEUR_COLONNES), BackgroundTransparency = 1, LayoutOrder = 2,
		Parent = corpsEnergie })
	local function colonne(nom, droite)
		local cadre = creer("Frame", { Name = nom, Position = UDim2.new(droite and 0.5 or 0, droite and 12 or 0, 0, 0), Size = UDim2.new(0.5, -12, 1, 0),
			BackgroundTransparency = 1, Parent = colonnes })
		creer("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8), Parent = cadre })
		return cadre
	end
	local colEtat, colRegulation = colonne("Etat", false), colonne("Regulation", true)
	creer("Frame", { Name = "Separateur", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(0, 1, 1, 0),
		BackgroundColor3 = C.ligne, BackgroundTransparency = 0.3, BorderSizePixel = 0, Parent = colonnes })
	UI.etiquette(colEtat, "État", { LayoutOrder = 1 })

	-- Une ligne d'état « NOM ······ VALEUR DÉTAIL » (la valeur en gras à sa couleur, le détail discret) et, si
	-- hauteurJauge > 0, sa jauge à 10 segments dessous. detailApres : le détail tout à droite (intégrité : « 99 % 9875 PV ») ;
	-- sinon la valeur tout à droite (boucliers : « INACTIFS 100 % »).
	local jauges = {} -- [cle] = { valeur, detail, segments }
	local function ligneEtat(cle, nom, ordre, hauteurJauge, detailApres)
		local cadre = creer("Frame", { Name = "Jauge_" .. cle, Size = UDim2.new(1, 0, 0, 22 + (hauteurJauge > 0 and 4 + hauteurJauge or 0)),
			BackgroundTransparency = 1, LayoutOrder = ordre, Parent = colEtat })
		texte({ Name = "Nom", Text = UI.majuscules(nom), Font = UI.POLICE_GRAS, TextSize = 14, Size = UDim2.new(1, -230, 0, 22), Parent = cadre })
		-- (V6.9.16) valeur plus large (« VERROUILLÉES ») quand le détail est à sa gauche
		local valeur = valeurGrasse(texte({ Name = "Valeur", Text = "—", Font = UI.POLICE_CODE, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, detailApres and -98 or 0, 0, 0), Size = UDim2.fromOffset(detailApres and 92 or 128, 22), Parent = cadre }))
		local detail = texte({ Name = "Detail", Text = "", Font = UI.POLICE_CODE, TextSize = 11, TextColor3 = C.texte2, TextXAlignment = Enum.TextXAlignment.Right,
			TextTruncate = Enum.TextTruncate.AtEnd, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, detailApres and 0 or -134, 0, 0),
			Size = UDim2.fromOffset(detailApres and 90 or 110, 22), Parent = cadre })
		local segments = nil
		if hauteurJauge > 0 then
			segments = UI.jaugeSegments(cadre, nil, { hauteurSegment = hauteurJauge, nomObjet = "Segments" })
			segments.cadre.Position = UDim2.fromOffset(0, 26)
		end
		jauges[cle] = { valeur = valeur, detail = detail, segments = segments }
	end
	ligneEtat("integrite", "Intégrité", 2, 16, true)
	ligneEtat("alimentation", "Alimentation", 3, 0, false)
	ligneEtat("bouclier", "Boucliers", 4, 12, false)
	ligneEtat("alerte", "Alerte", 5, 0, false)         -- (V6.9.16)
	ligneEtat("demarrage", "Démarrage", 6, 0, false)   -- (V6.9.16)
	ligneEtat("portes", "Portes", 7, 0, false)         -- (V6.9.16)
	creer("Frame", { Name = "Filet", Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = C.ligne, BackgroundTransparency = 0.3, BorderSizePixel = 0, LayoutOrder = 8,
		Parent = colEtat })
	-- (V6.9.16) Pannes en cours : une ligne par panne (rouge : critique, ambre : à régler), « SYSTÈMES NOMINAUX » sinon
	UI.etiquette(colEtat, "Pannes en cours", { LayoutOrder = 9 })
	local MAX_PANNES = 8
	local cadrePannes = creer("Frame", { Name = "Pannes", Size = UDim2.new(1, 0, 0, MAX_PANNES * 17), BackgroundTransparency = 1, LayoutOrder = 10, Parent = colEtat })
	creer("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = cadrePannes })
	local lignesPannes = {}
	for n = 1, MAX_PANNES do
		lignesPannes[n] = texte({ Name = "Panne" .. n, Text = "", Font = UI.POLICE_CODE, TextSize = 12, TextTruncate = Enum.TextTruncate.AtEnd,
			Size = UDim2.new(1, 0, 0, 17), LayoutOrder = n, Visible = false, Parent = cadrePannes })
	end
	local function pannesEnCours()
		local liste = {}
		local function ajouter(libelle, critique) table.insert(liste, { libelle = libelle, critique = critique }) end
		if exterieur:GetAttribute("Incendie") == true and not exterieur:GetAttribute("IncendieEteint") then ajouter("Incendie de console", true) end
		if exterieur:GetAttribute("Breche") ~= nil then ajouter("Brèche dans la structure", true) end
		if exterieur:GetAttribute("RedemarrageRequis") == true then ajouter("Coupure de sécurité : redémarrage requis", true) end
		if exterieur:GetAttribute("Avarie") == true then ajouter("Avarie des systèmes", true) end
		if exterieur:GetAttribute("RotorBloque") == true then ajouter("Rotor bloqué", true) end
		local grille = exterieur:GetAttribute("VapeurSurcharge")
		if grille ~= nil then ajouter("Fuite de vapeur : grille n°" .. tostring(grille), false) end
		if exterieur:GetAttribute("FuiteAir") ~= nil then ajouter("Fuite d'air", false) end
		if exterieur:GetAttribute("Alimentation") == false then ajouter("Hors tension", false) end
		return liste
	end
	local function majPannes()
		local liste = pannesEnCours()
		for n, ligne in lignesPannes do
			local panne = liste[n]
			if n == 1 and not panne then
				ligne.Text, ligne.TextColor3, ligne.Visible = "●  SYSTÈMES NOMINAUX", C.vert, true
			elseif panne then
				ligne.Text = "●  " .. UI.majuscules(panne.libelle)
				ligne.TextColor3 = panne.critique and C.rouge or C.ambre
				ligne.Visible = true
			else
				ligne.Visible = false
			end
		end
	end
	UI.etiquette(colRegulation, "Régulation", { LayoutOrder = 1 })

	-- Envoi des réglages : un à la fois (le serveur refuse deux commandes Tech à moins de 0,25 s), la dernière valeur gagne
	local aEnvoyer, ordreEnvoi, envoiEnCours = {}, {}, false
	local regulations = {} -- [systeme] = { valeur, segments, role, voulu } ; voulu = valeur demandée, affichée en attendant le serveur
	local majEnergie -- (définie plus bas)
	local function envoyerReglages()
		if envoiEnCours then return end
		envoiEnCours = true
		task.spawn(function()
			task.wait(0.25) -- les clics rapprochés sur un même réglage ne font qu'un envoi
			while #ordreEnvoi > 0 do
				local systeme = table.remove(ordreEnvoi, 1)
				local valeur = aEnvoyer[systeme]
				aEnvoyer[systeme] = nil
				if valeur then
					remote:FireServer("Tech", { commande = "Reguler", systeme = systeme, valeur = valeur })
					-- (V6.9.10.1, relecture) sans réponse au bout d'1 s (refus, même valeur) : on revient à la valeur du serveur
					task.delay(1, function()
						local r = regulations[systeme]
						if r and r.voulu == valeur and not aEnvoyer[systeme] then
							r.voulu = nil
							if ouvert and ouvert.gui == guiEnergie then majEnergie() end
						end
					end)
					task.wait(0.3)
				end
			end
			envoiEnCours = false
		end)
	end
	-- Couleur d'une valeur de la régulation : celle de son système (énergie cyan, air jaune, vapeur couleur du texte),
	-- rouge hors des bornes (sous-tension, surtension, air vicié)
	local function couleurRegulation(systeme, v)
		local r = regulations[systeme]
		local alerte = (systeme == "Energie" and (v < (TECH.SousTension or 20) or v > (TECH.SurtensionAuDessus or 90)))
			or (systeme == "Air" and v < (TECH.SeuilAirVicie or 25))
		return alerte and C.rouge or C[r.role]
	end
	-- (V6.9.16) Ce que fait le réglage à cette valeur, et sa couleur
	local function etatRegulation(systeme, v)
		if systeme == "Energie" then
			if v < (TECH.SousTension or 20) then return "Sous-tension : lumières baissées", C.rouge end
			if v > (TECH.SurtensionAuDessus or 90) then return "Surtension : risque de fuite de vapeur", C.rouge end
			return "Tension nominale", C.vert
		elseif systeme == "Air" then
			if v < (TECH.SeuilAirVicie or 25) then return "Air vicié", C.rouge end
			if exterieur:GetAttribute("FuiteAir") ~= nil then return "Fuite d'air en cours", C.ambre end
			return "Air respirable", C.vert
		end
		if exterieur:GetAttribute("VapeurSurcharge") ~= nil then return "Grille en surcharge", C.ambre end
		if v <= 0 then return "Vapeur coupée", C.texte2 end
		return string.format("Intensité × %.1f", v / 50), C.vert
	end
	local function afficherRegulation(systeme, v)
		local r = regulations[systeme]
		local couleur = couleurRegulation(systeme, v)
		r.valeur.Text = string.format("%d %%", v)
		r.valeur.TextColor3 = couleur
		r.segments.regler(v, couleur)
		local libelle, couleurEtat = etatRegulation(systeme, v)
		r.etat.Text = "●  " .. UI.majuscules(libelle)
		r.etat.TextColor3 = couleurEtat
	end
	-- Une ligne de la régulation : le nom (et ce qu'il règle), − valeur + (boutons à coins coupés de 44 px), jauge de 16 px
	-- (V6.9.16) dessous : l'état du réglage (à gauche) et sa plage (à droite)
	local function reguler(systeme, nom, sousNom, role, ordre, plage)
		local cadre = creer("Frame", { Name = "Regul_" .. systeme, Size = UDim2.new(1, 0, 0, 88), BackgroundTransparency = 1, LayoutOrder = ordre, Parent = colRegulation })
		texte({ Name = "Nom", Text = UI.majuscules(nom), Font = UI.POLICE_GRAS, TextSize = 14, Position = UDim2.fromOffset(0, 3), Size = UDim2.new(1, -170, 0, 20), Parent = cadre })
		texte({ Name = "SousNom", Text = UI.majuscules(sousNom), Font = UI.POLICE_CODE, TextSize = 10, TextColor3 = C.texte2, Position = UDim2.fromOffset(0, 24),
			Size = UDim2.new(1, -170, 0, 14), Parent = cadre })
		local moins = UI.boutonCoupe(cadre, "−", "secondaire", { Name = "Moins", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -112, 0, 0),
			Size = UDim2.fromOffset(UI.JETONS.cible, UI.JETONS.cible), Font = UI.POLICE_GRAS, TextSize = 22 })
		local valeur = valeurGrasse(texte({ Name = "Valeur", Text = "—", Font = UI.POLICE_CODE, TextSize = 16, TextColor3 = C[role], TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -48, 0, 0), Size = UDim2.fromOffset(64, UI.JETONS.cible), Parent = cadre }))
		local plus = UI.boutonCoupe(cadre, "+", "secondaire", { Name = "Plus", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0),
			Size = UDim2.fromOffset(UI.JETONS.cible, UI.JETONS.cible), Font = UI.POLICE_GRAS, TextSize = 22 })
		local segments = UI.jaugeSegments(cadre, nil, { hauteurSegment = 16, nomObjet = "Segments" })
		segments.cadre.Position = UDim2.fromOffset(0, 50)
		local etat = texte({ Name = "Etat", Text = "", Font = UI.POLICE_CODE, TextSize = 11, TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(0, 70), Size = UDim2.new(1, -120, 0, 16), Parent = cadre })
		texte({ Name = "Plage", Text = UI.majuscules(plage), Font = UI.POLICE_CODE, TextSize = 10, TextColor3 = C.texte2, TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 70), Size = UDim2.fromOffset(116, 16), Parent = cadre })
		local r = { valeur = valeur, segments = segments, role = role, voulu = nil, etat = etat }
		regulations[systeme] = r
		local function changer(delta)
			local actuel = r.voulu or tonumber(exterieur:GetAttribute("Regul" .. systeme)) or 50
			local nouveau = math.clamp(math.floor((actuel + delta) / PAS + 0.5) * PAS, 0, 100) -- toujours entre 0 et 100
			if nouveau == actuel then return end
			r.voulu = nouveau
			afficherRegulation(systeme, nouveau)
			if not aEnvoyer[systeme] then table.insert(ordreEnvoi, systeme) end
			aEnvoyer[systeme] = nouveau
			envoyerReglages()
		end
		moins.Activated:Connect(function() changer(-PAS) end)
		plus.Activated:Connect(function() changer(PAS) end)
	end
	reguler("Energie", "Énergie", "Tension", "cyan", 2, string.format("Nominal %d–%d %%", TECH.SousTension or 20, TECH.SurtensionAuDessus or 90))
	reguler("Air", "Air", "Recyclage", "ambre", 3, string.format("Vicié sous %d %%", TECH.SeuilAirVicie or 25))
	reguler("Vapeur", "Vapeur", "Refroidissement", "texte", 4, "Normal : 50 %")
	UI.ligneAide(colRegulation, "Les réglages passent par la régulation, comme la tablette technicien. Une surtension "
		.. "prolongée fait lâcher les grilles de vapeur ; un air trop bas voile la salle.", { LayoutOrder = 5 })
	local fermerEnergie = UI.boutonCoupe(corpsEnergie, "Fermer (Échap)", "secondaire", { Name = "Fermer", LayoutOrder = 3 })
	fermerEnergie.Activated:Connect(fermerPanneau)

	local function couleurNiveau(v, bas, haut)
		if v <= bas then return C.rouge end
		if v <= haut then return C.ambre end
		return C.vert
	end
	-- p : pourcentage de la jauge (nil : pas de jauge) ; couleurJauge : celle des segments (sinon la couleur de la valeur)
	local function majJauge(cle, p, valeurTexte, couleur, detailTexte, couleurJauge)
		local j = jauges[cle]
		j.valeur.Text = valeurTexte
		j.valeur.TextColor3 = couleur
		j.detail.Text = UI.majuscules(detailTexte or "")
		if j.segments and p then j.segments.regler(p, couleurJauge or couleur) end
	end
	majEnergie = function(attributChange)
		local pv = tonumber(exterieur:GetAttribute("PointsDeVie")) or 100
		majJauge("integrite", pv, string.format("%d %%", pv), couleurNiveau(pv, 20, 50), string.format("%s PV", tostring(exterieur:GetAttribute("PV") or "?")))
		local alimente = exterieur:GetAttribute("Alimentation") ~= false
		majJauge("alimentation", nil, alimente and "NOMINALE" or "COUPÉE", alimente and C.vert or C.rouge, "")
		local actif = (exterieur:GetAttribute("BouclierComplet") == true and "COMPLET") or (exterieur:GetAttribute("BouclierBalles") == true and "ANTI-BALLES")
			or (exterieur:GetAttribute("BouclierJoueurs") == true and "ANTI-JOUEURS") or nil
		local energieBouclier = math.floor((tonumber(exterieur:GetAttribute("BouclierEnergie")) or 100) + 0.5)
		local couleurBouclier = actif and couleurNiveau(energieBouclier, 15, 40) or (energieBouclier <= 0 and C.rouge or C.texte2)
		majJauge("bouclier", energieBouclier, string.format("%d %%", energieBouclier), (actif or energieBouclier <= 0) and couleurBouclier or C.texte,
			actif or (energieBouclier <= 0 and "TOMBÉS" or "INACTIFS"), couleurBouclier)
		jauges.bouclier.detail.TextColor3 = actif and couleurBouclier or C.texte2
		-- (V6.9.16) alerte, démarrage, portes, puis les pannes en cours
		local alerte = exterieur:GetAttribute("Alerte") == true
		majJauge("alerte", nil, alerte and "ACTIVE" or "AUCUNE", alerte and C.rouge or C.vert, "")
		local blocage = nil
		if exterieur:GetAttribute("Alimentation") == false then blocage = "HORS TENSION"
		elseif exterieur:GetAttribute("DemarrageBloque") then blocage = "BLOQUÉ"
		elseif exterieur:GetAttribute("RotorBloque") then blocage = "ROTOR BLOQUÉ" end
		majJauge("demarrage", nil, blocage and "IMPOSSIBLE" or "PRÊT", blocage and C.rouge or C.vert, blocage or "")
		local verrouillees = exterieur:GetAttribute("PortesVerrouillees") == true or exterieur:GetAttribute("Verrouille") == true
		majJauge("portes", nil, verrouillees and "VERROUILLÉES" or "LIBRES", verrouillees and C.ambre or C.vert,
			exterieur:GetAttribute("PorteOuverte") == true and "OUVERTES" or "FERMÉES")
		majPannes()
		for systeme, r in regulations do
			local v = tonumber(exterieur:GetAttribute("Regul" .. systeme)) or 50
			-- Le serveur a répondu (ou un autre a réglé) et rien ne reste à envoyer : sa valeur fait foi
			if r.voulu and not aEnvoyer[systeme] and (r.voulu == v or attributChange == "Regul" .. systeme) then r.voulu = nil end
			afficherRegulation(systeme, r.voulu or v)
		end
	end
	for _, nom in { "PointsDeVie", "PV", "Alimentation", "BouclierEnergie", "BouclierJoueurs", "BouclierBalles", "BouclierComplet", "RegulEnergie", "RegulAir", "RegulVapeur",
		-- (V6.9.16) détails : alerte, démarrage, portes et pannes
		"Alerte", "DemarrageBloque", "RotorBloque", "PortesVerrouillees", "Verrouille", "PorteOuverte", "Incendie", "IncendieEteint", "Breche",
		"RedemarrageRequis", "Avarie", "VapeurSurcharge", "FuiteAir" } do
		exterieur:GetAttributeChangedSignal(nom):Connect(function()
			if ouvert and ouvert.gui == guiEnergie then majEnergie(nom) end
		end)
	end

	--------------------------------------------------------------------
	-- Panneau du jukebox
	--------------------------------------------------------------------
	local LARGEUR_JUKEBOX, HAUTEUR_JUKEBOX = 380, 490
	local guiJukebox, _, corpsJukebox = panneau("TardisJukeboxConsole", LARGEUR_JUKEBOX, HAUTEUR_JUKEBOX)
	local plaqueJukebox = UI.plaque(corpsJukebox, "Jukebox", UI.texteBadge("Jukebox", "PILOTE"), "À l'arrêt",
		{ ordre = 1, droite = 52, largeurBande = LARGEUR_JUKEBOX, exterieur = exterieur })
	local fermerJukebox = UI.boutonCoupe(plaqueJukebox.cadre, "×", "secondaire", { Name = "Fermer", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, -6),
		Size = UDim2.fromOffset(UI.JETONS.cible, UI.JETONS.cible), Font = UI.POLICE_GRAS, TextSize = 22, ZIndex = 3 })
	fermerJukebox.Activated:Connect(fermerPanneau)
	-- Tableau N° | PISTE | DURÉE (la colonne dit la CATÉGORIE tant qu'une durée est inconnue) ; ses lignes vont dans « Liste »
	local tableauJukebox = UI.tableau(corpsJukebox, {
		{ cle = "numero", titre = "N°", largeur = UDim.new(0, 52), donnees = true },
		{ cle = "piste", titre = "Piste", largeur = UDim.new(1, -168) },
		{ cle = "detail", titre = "Durée", largeur = UDim.new(0, 116), droite = true, donnees = true },
	}, { nom = "Pistes", taille = UDim2.new(1, 0, 0, 20 + UI.JETONS.cible * 5), ordre = 2 })
	local listeJukebox = tableauJukebox.corps
	listeJukebox.Name = "Liste"
	local jaugeVolume = UI.jaugeSegments(corpsJukebox, "Volume", { ordre = 3, nomObjet = "Volume", hauteurSegment = 12, largeurValeur = 80 })
	local function majVolume() jaugeVolume.regler(math.floor(UI.volume() * 100 + 0.5), C.cyan) end
	UI.prefsChangees.Event:Connect(function(cle) if cle == "volume" then majVolume() end end)
	UI.ligneAide(corpsJukebox, "La musique ne s'entend qu'à bord. Choisis une ligne, puis JOUER. Volume : réglages de la tablette.", { LayoutOrder = 4 })
	local rangeeJukebox = creer("Frame", { Name = "Boutons", Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1, LayoutOrder = 5, Parent = corpsJukebox },
	{ creer("UIGridLayout", { CellSize = UDim2.new(1 / 3, -6, 1, 0), CellPadding = UDim2.fromOffset(8, 0), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local jouer = UI.boutonCoupe(rangeeJukebox, "Jouer", "principal", { Name = "Jouer", LayoutOrder = 1 })
	local jouerPlaylist = UI.boutonCoupe(rangeeJukebox, "Playlist", "secondaire", { Name = "JouerPlaylist", LayoutOrder = 2 })
	local arreter = UI.boutonCoupe(rangeeJukebox, "Arrêter", "danger", { Name = "Arreter", LayoutOrder = 3 })

	-- La ligne choisie : { piste = numéro } ou { liste = catégorie } ; JOUER la lance (le serveur décide, comme avant)
	local selection = nil
	local pistesAffichees = {}
	local function memeChoix(a, b)
		return a ~= nil and b ~= nil and a.piste == b.piste and a.liste == b.liste
	end
	-- Catégorie que PLAYLIST lancerait : la playlist choisie, ou celle de la piste choisie
	local function categorieChoisie()
		if not selection then return nil end
		if selection.liste then return selection.liste end
		local piste = pistesAffichees[selection.piste]
		return piste and piste.categorie or nil
	end
	-- Ligne choisie (pas encore lancée) : fond cyan léger ; la piste qui joue reste jaune (ligne.choisir)
	local function marquer(ligne, oui)
		ligne.bouton:SetAttribute("Selection", oui == true)
		if not oui then return end
		local peindre = ligne.peindre
		ligne.peindre = function()
			peindre()
			if not ligne.choisi then
				ligne.bouton.BackgroundColor3 = C.cyan
				ligne.bouton.BackgroundTransparency = 0.82
				ligne.cellules.numero.TextColor3 = C.cyan
			end
		end
		ligne.peindre()
	end
	local construireJukebox
	local function choisirLigne(choix)
		selection = choix
		construireJukebox()
	end
	local function duree(secondes)
		secondes = math.floor(secondes + 0.5)
		return string.format("%d:%02d", secondes // 60, secondes % 60)
	end
	construireJukebox = function()
		tableauJukebox.vider()
		local ancienVide = listeJukebox:FindFirstChild("Vide")
		if ancienVide then ancienVide:Destroy() end
		local enCours = exterieur:GetAttribute("Jukebox")
		-- (V6.9.10.5) Config.Jukebox ET les Sound du dossier TardisAssets › Jukebox, triés comme sur le serveur
		local pistes = Config.pistesJukebox()
		pistesAffichees = pistes
		local categories, ordreCategories = {}, {}
		for _, piste in pistes do
			if piste.categorie and not categories[piste.categorie] then
				categories[piste.categorie] = 0
				table.insert(ordreCategories, piste.categorie)
			end
			if piste.categorie then categories[piste.categorie] += 1 end
		end
		-- Durées : connues pour les Sound du dossier déjà chargés (TimeLength) ; une seule inconnue, et la colonne dit la catégorie
		local durees, toutesConnues = {}, #pistes > 0
		for i, piste in pistes do
			local ok, d = pcall(function() return piste.son and piste.son.TimeLength end)
			d = ok and tonumber(d) or nil
			if d and d > 0 then durees[i] = d else toutesConnues = false end
		end
		local titreDetail = tableauJukebox.entete:FindFirstChild("Titre_detail")
		if titreDetail then titreDetail.Text = toutesConnues and "DURÉE" or "CATÉGORIE" end
		-- Ligne choisie : gardée si elle existe encore ; sinon ce qui joue, sinon la première piste
		if selection and ((selection.piste and not pistes[selection.piste]) or (selection.liste and not categories[selection.liste])) then selection = nil end
		if not selection then
			if type(enCours) == "number" and pistes[enCours] then selection = { piste = enCours }
			elseif type(enCours) == "string" and categories[enCours] then selection = { liste = enCours }
			elseif pistes[1] then selection = { piste = 1 } end
		end
		local ordre = 0
		if #pistes == 0 then
			local vide = texte({ Name = "Vide", Text = "Aucune musique : la liste est vide. Pour la remplir, glisse des Sound (Toolbox de Studio › Audio › Music) dans "
				.. "ReplicatedStorage › TardisAssets › " .. ((Config.JukeboxDossier or {}).Nom or "Jukebox") .. ", ou ajoute des pistes à Config.Jukebox.",
				Font = UI.POLICE_CODE, TextSize = 12, TextColor3 = C.texte2, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.new(1, -4, 0, 0), LayoutOrder = 0, Parent = listeJukebox })
			creer("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = vide })
		end
		-- Les playlists d'abord (une par catégorie, dans l'ordre des catégories), puis les pistes (comme avant)
		for _, categorie in ordreCategories do
			ordre += 1
			local choix = { liste = categorie }
			local n = categories[categorie]
			local ligne = tableauJukebox.ajouter({ numero = "►", piste = "Playlist " .. categorie, detail = string.format("%d piste%s", n, n > 1 and "s" or "") },
				{ nom = "Playlist", ordre = ordre, action = function() choisirLigne(choix) end })
			if enCours == categorie then ligne.choisir(true) end
			marquer(ligne, memeChoix(selection, choix))
		end
		for i, piste in pistes do
			ordre += 1
			local choix = { piste = i }
			local detail = toutesConnues and duree(durees[i]) or (piste.categorie or "—")
			local ligne = tableauJukebox.ajouter({ numero = string.format("%02d", i), piste = tostring(piste.nom), detail = detail },
				{ nom = "Piste", ordre = ordre, action = function() choisirLigne(choix) end })
			if enCours == i then ligne.choisir(true) end
			marquer(ligne, memeChoix(selection, choix))
		end
		-- Plaque : ce qui joue (maquette : « EN LECTURE · PISTE 01 »)
		if type(enCours) == "number" and pistes[enCours] then
			plaqueJukebox.majSousLigne(string.format("En lecture  ·  piste %02d  ·  %s", enCours, tostring(pistes[enCours].nom)))
		elseif type(enCours) == "string" then
			plaqueJukebox.majSousLigne("En lecture  ·  playlist " .. enCours)
		else
			plaqueJukebox.majSousLigne(#pistes > 0 and string.format("À l'arrêt  ·  %d piste%s", #pistes, #pistes > 1 and "s" or "") or "Aucune piste")
		end
		UI.setDisponible(jouer, selection ~= nil)
		UI.setDisponible(jouerPlaylist, categorieChoisie() ~= nil)
		majVolume()
	end
	jouer.Activated:Connect(function()
		if not selection then return end
		if selection.liste then
			remote:FireServer("Jukebox", { liste = selection.liste })
		else
			remote:FireServer("Jukebox", { index = selection.piste })
		end
	end)
	jouerPlaylist.Activated:Connect(function()
		local categorie = categorieChoisie()
		if categorie then remote:FireServer("Jukebox", { liste = categorie }) end
	end)
	arreter.Activated:Connect(function()
		remote:FireServer("Jukebox", {})
	end)
	exterieur:GetAttributeChangedSignal("Jukebox"):Connect(function()
		if ouvert and ouvert.gui == guiJukebox then construireJukebox() end
	end)
	-- (V6.9.10.5) La liste des pistes (rangée dans Config.Jukebox, lue aussi par la tablette) suit le dossier du jukebox
	-- dès qu'il est arrivé chez le joueur
	task.spawn(function()
		local assets = game:GetService("ReplicatedStorage"):WaitForChild("TardisAssets", 30)
		if assets then assets:WaitForChild((Config.JukeboxDossier or {}).Nom or "Jukebox", 30) end
		Config.pistesJukebox()
	end)

	--------------------------------------------------------------------
	-- Messages du serveur
	--------------------------------------------------------------------
	local function partOu(objet, cle)
		if typeof(objet) == "Instance" and objet:IsA("BasePart") then return objet end
		return Config.partDe(Config.trouverCommande(interieur, cle))
	end
	remote.OnClientEvent:Connect(function(message, info, ok)
		if message == "__console" then
			afficherMessage(info, ok == true)
		elseif message == "__energie" then
			for _, r in regulations do r.voulu = nil end -- chaque ouverture repart des valeurs du serveur
			majEnergie()
			ouvrirPanneau(guiEnergie, partOu(info, "EcranIngenieur"), REGLAGES.DistanceFermeture or 14)
		elseif message == "__jukebox" then
			selection = nil -- chaque ouverture part de ce qui joue
			construireJukebox()
			ouvrirPanneau(guiJukebox, partOu(info, "JukeBox"), (Config.JukeboxConsole or {}).DistanceFermeture or 14)
		end
	end)

	return { fermer = fermerPanneau }
end
