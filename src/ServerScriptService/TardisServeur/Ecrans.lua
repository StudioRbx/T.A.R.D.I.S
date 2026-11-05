-- ServerScriptService > TardisServeur > Ecrans (ModuleScript)
-- Écrans de la console faits entièrement en script (V6.9.10.1). Aucun objet à préparer dans Studio, sauf les pièces.
--   Écrans de destination : TOUTES les pièces nommées « Ecran » de la Console, et toutes les pièces d'un Model ou
--     d'un Folder « Ecran » (deux écrans ou plus). Destination choisie, état, mode du voyage, alerte, démarrage bloqué,
--     camouflé, rétréci, maintenance ; les messages courts de la console (« PAS POSÉ »…) s'y affichent 2 s.
--   Écran ingénieur « Console › Ecran-Ingenieure » : intégrité (PV), énergie, régulation (énergie, air, vapeur) et
--     boucliers, en barres et en pourcentages, rouges quand c'est bas. Un clic (ou E) ouvre le menu de gestion de
--     l'énergie aux pilotes et aux techniciens ; les autres lisent « Réservé aux pilotes et aux ingénieurs ».
-- Face de l'affichage : attribut « FaceEcran » de la pièce (Front, Back, Top, Bottom, Left, Right), sinon celui du Model
-- « Ecran », sinon Front ; « Aucune » : pas d'affichage sur cette pièce (cadre, pied…).
-- Hors tension : écrans noirs, « HORS TENSION » en petit. TARDIS détruit : affichage d'alerte.
-- Aucune boucle : chaque écran est redessiné quand un attribut qu'il affiche change (l'écran ingénieur au plus
-- 10 fois par seconde, Config.Ecrans.Rafraichissement).
-- Reçoit ce qu'il utilise, renvoie majEcran (même rôle qu'avant : majEcran(message) affiche un message court).

return function(contexte)
	local Config, E, def, exterieur, interieur = contexte.Config, contexte.E, contexte.def, contexte.exterieur, contexte.interieur
	local Players, remote, destinationChoisie, etatActuel = contexte.Players, contexte.remote, contexte.destinationChoisie, contexte.etatActuel
	local UI = require(game:GetService("ReplicatedStorage"):WaitForChild("TardisUI")) -- palette et polices du TARDIS
	local C = UI.C
	local REGLAGES = Config.Ecrans or {}
	local ATTRIBUT_FACE = REGLAGES.AttributFace or "FaceEcran"
	local TECH = Config.Technicien or {}
	local NOIR = Color3.fromRGB(0, 0, 0)

	--------------------------------------------------------------------
	-- Construction commune
	--------------------------------------------------------------------
	local FACES = { front = "Front", back = "Back", top = "Top", bottom = "Bottom", left = "Left", right = "Right" }
	-- Face choisie (nil = pas d'affichage) : attribut de la pièce, sinon du Model « Ecran », sinon Front
	local function faceDe(part, modele)
		local valeur = part:GetAttribute(ATTRIBUT_FACE)
		if valeur == nil and modele then valeur = modele:GetAttribute(ATTRIBUT_FACE) end
		if valeur == nil then return Enum.NormalId.Front end
		local nom = type(valeur) == "string" and string.lower(valeur) or ""
		if nom == "aucune" or nom == "aucun" then return nil end
		if FACES[nom] then return Enum.NormalId[FACES[nom]] end
		warn("[TARDIS] " .. part:GetFullName() .. " : " .. ATTRIBUT_FACE .. " « " .. tostring(valeur) .. " » inconnu (Front, Back, Top, Bottom, Left, Right ou Aucune) : Front.")
		return Enum.NormalId.Front
	end

	local function cadre(parent, nom, position, taille, couleur, transparence)
		local f = Instance.new("Frame")
		f.Name = nom
		f.Position, f.Size = position, taille
		f.BackgroundColor3 = couleur or C.ecran
		f.BackgroundTransparency = transparence or 0
		f.BorderSizePixel = 0
		f.Parent = parent
		return f
	end
	local function etiquette(parent, nom, position, taille, couleur, police, alignement)
		local t = Instance.new("TextLabel")
		t.Name = nom
		t.Position, t.Size = position, taille
		t.BackgroundTransparency = 1
		t.Text = ""
		t.TextColor3 = couleur or C.texte
		t.Font = police or UI.POLICE_GRAS
		t.TextScaled = true
		t.TextWrapped = true
		t.TextXAlignment = alignement or Enum.TextXAlignment.Left
		t.Parent = parent
		return t
	end
	local function coin(parent, rayon)
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(rayon or 0.04, 0)
		c.Parent = parent
	end

	-- Une surface : le SurfaceGui, son fond, son cadre lumineux, et les deux voiles (hors tension, détruit)
	local function creerSurface(part, nom, face, accent, titre)
		local gui = Instance.new("SurfaceGui")
		gui.Name = nom
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = REGLAGES.PixelsParStud or 50
		gui.LightInfluence = 0
		gui.ClipsDescendants = true
		gui.Parent = part
		local fond = cadre(gui, "Fond", UDim2.new(), UDim2.fromScale(1, 1), C.ecran)
		local degrade = Instance.new("UIGradient")
		degrade.Rotation = 90
		degrade.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 165, 200))
		degrade.Parent = fond
		local bord = Instance.new("UIStroke")
		bord.Color, bord.Thickness, bord.Transparency = accent, 4, 0.35
		bord.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		bord.Parent = fond
		etiquette(fond, "Titre", UDim2.fromScale(0.05, 0.04), UDim2.fromScale(0.9, 0.1), accent, UI.POLICE_GRAS).Text = titre
		cadre(fond, "Filet", UDim2.fromScale(0.05, 0.155), UDim2.fromScale(0.9, 0.008), accent, 0.55)
		-- Hors tension : noir, un petit texte discret
		local veille = cadre(gui, "Veille", UDim2.new(), UDim2.fromScale(1, 1), NOIR)
		veille.Visible = false
		veille.ZIndex = 5
		local horsTension = etiquette(veille, "Texte", UDim2.fromScale(0.25, 0.45), UDim2.fromScale(0.5, 0.1), Color3.fromRGB(70, 70, 80), UI.POLICE, Enum.TextXAlignment.Center)
		horsTension.Text = "HORS TENSION"
		horsTension.ZIndex = 6
		-- Détruit : affichage d'alerte
		local detruit = cadre(gui, "Detruit", UDim2.new(), UDim2.fromScale(1, 1), Color3.fromRGB(40, 4, 8))
		detruit.Visible = false
		detruit.ZIndex = 7
		local alarme = etiquette(detruit, "Titre", UDim2.fromScale(0.05, 0.3), UDim2.fromScale(0.9, 0.2), C.rouge, UI.POLICE_GRAS, Enum.TextXAlignment.Center)
		alarme.Text = "!! TARDIS DÉTRUIT !!"
		alarme.ZIndex = 8
		local sous = etiquette(detruit, "SousTitre", UDim2.fromScale(0.1, 0.55), UDim2.fromScale(0.8, 0.1), Color3.fromRGB(255, 160, 160), UI.POLICE, Enum.TextXAlignment.Center)
		sous.Text = "RECONSTITUTION EN COURS"
		sous.ZIndex = 8
		return gui, fond
	end

	-- Hors tension et détruit : les voiles de chaque surface
	local function voiles(gui)
		local horsTension = exterieur:GetAttribute("Alimentation") == false
		local detruit = exterieur:GetAttribute("Detruit") == true
		gui.Veille.Visible = horsTension and not detruit
		gui.Detruit.Visible = detruit
		return horsTension or detruit
	end

	-- Un écran peut changer de face en jeu (attribut modifié dans Studio pendant un test)
	local function suivreFace(part, modele, gui)
		local function maj()
			local face = faceDe(part, modele)
			gui.Enabled = face ~= nil
			if face then gui.Face = face end
		end
		part:GetAttributeChangedSignal(ATTRIBUT_FACE):Connect(maj)
		if modele then modele:GetAttributeChangedSignal(ATTRIBUT_FACE):Connect(maj) end
	end

	-- Regroupe les mises à jour : un seul dessin pour plusieurs attributs changés en même temps
	local function planificateur(dessiner, delai)
		local prevu = false
		return function()
			if prevu then return end
			prevu = true
			local function faire()
				prevu = false
				dessiner()
			end
			if delai and delai > 0 then task.delay(delai, faire) else task.defer(faire) end
		end
	end

	--------------------------------------------------------------------
	-- Écrans de destination
	--------------------------------------------------------------------
	local cheminEcran = (Config.Chemins or {}).Ecran or { "Console", "Ecran" }
	local nomEcran = cheminEcran[#cheminEcran]
	local cheminIngenieur = (Config.Chemins or {}).EcranIngenieur
	local nomIngenieur = cheminIngenieur and cheminIngenieur[#cheminIngenieur]
	local destinations = {} -- [part] = { gui, fond, textes }
	local ordreDestinations = {}
	local messageActuel = nil

	local function lignesStatut()
		local statuts = {}
		if exterieur:GetAttribute("AutoDestructionDebut") then table.insert(statuts, "AUTO-DESTRUCTION") end
		if exterieur:GetAttribute("Alerte") then table.insert(statuts, "ALERTE") end
		if exterieur:GetAttribute("DemarrageBloque") then table.insert(statuts, "DÉMARRAGE BLOQUÉ") end
		if exterieur:GetAttribute("Maintenance") then table.insert(statuts, "MAINTENANCE") end
		if exterieur:GetAttribute("Camouflage") then table.insert(statuts, "CAMOUFLÉ") end
		if exterieur:GetAttribute("Retreci") then table.insert(statuts, "RÉTRÉCI") end
		return statuts
	end

	local function dessinerDestination(ecran)
		if voiles(ecran.gui) then return end
		local t = ecran.textes
		local dest = destinationChoisie()
		t.Destination.Text = dest and string.upper(dest.Name) or "AUCUNE"
		t.Destination.TextColor3 = dest and C.ambre or C.texte2
		-- État et mode du voyage
		local etat = etatActuel()
		local libelle = UI.LIBELLES[etat] or { tostring(etat), C.texte }
		local volLibre = exterieur:GetAttribute("VolLibre") ~= nil
		if volLibre then
			t.Etat.Text = "●  VOL LIBRE" .. (exterieur:GetAttribute("VolPhase") == "Invisible" and "  ·  DANS LE VORTEX" or "")
			t.Etat.TextColor3 = C.cyan
			t.Mode.Text = "MODE : VOL LIBRE" .. (exterieur:GetAttribute("VolUrgence") and "  ·  URGENCE" or "")
			t.Mode.TextColor3 = exterieur:GetAttribute("VolUrgence") and C.orange or C.texte2
		else
			t.Etat.Text = "●  " .. libelle[1]
			t.Etat.TextColor3 = libelle[2]
			local mode = Config.modeDe(exterieur)
			t.Mode.Text = "MODE : " .. Config.libelleMode(mode, true)
			t.Mode.TextColor3 = mode == "Normal" and C.texte2 or UI.couleurMode(mode)
		end
		local statuts = lignesStatut()
		t.Statuts.Text = #statuts > 0 and table.concat(statuts, "  ·  ") or "SYSTÈMES NOMINAUX"
		t.Statuts.TextColor3 = (exterieur:GetAttribute("Alerte") or exterieur:GetAttribute("AutoDestructionDebut")) and C.rouge
			or (#statuts > 0 and C.ambre) or C.vert
		-- Message court de la console (« PAS POSÉ », « ALERTE GÉNÉRALE »…)
		t.Bandeau.Visible = messageActuel ~= nil
		t.Message.Text = messageActuel or ""
	end
	local function dessinerDestinations()
		for _, part in ordreDestinations do
			local ecran = destinations[part]
			if ecran and part.Parent then dessinerDestination(ecran) end
		end
	end
	local planifierDestinations = planificateur(dessinerDestinations)

	local function ajouterDestination(part, modele)
		if destinations[part] or not part:IsA("BasePart") then return end
		if nomIngenieur then -- une pièce « Ecran » rangée dans l'écran ingénieur n'est pas un écran de destination
			local p = part
			while p and p ~= interieur do
				if p.Name == nomIngenieur then return end
				p = p.Parent
			end
		end
		local face = faceDe(part, modele)
		local gui, fond = creerSurface(part, "TardisEcranDestination", face or Enum.NormalId.Front, C.cyan, "◆  TARDIS  ·  NAVIGATION")
		gui.Enabled = face ~= nil
		local textes = {}
		textes.Etiquette = etiquette(fond, "EtiquetteDestination", UDim2.fromScale(0.05, 0.19), UDim2.fromScale(0.9, 0.07), C.texte2, UI.POLICE)
		textes.Etiquette.Text = "DESTINATION"
		textes.Destination = etiquette(fond, "Destination", UDim2.fromScale(0.05, 0.27), UDim2.fromScale(0.9, 0.19), C.ambre, UI.POLICE_TITRE)
		textes.Etat = etiquette(fond, "Etat", UDim2.fromScale(0.05, 0.5), UDim2.fromScale(0.9, 0.1), C.vert)
		textes.Mode = etiquette(fond, "Mode", UDim2.fromScale(0.05, 0.62), UDim2.fromScale(0.9, 0.075), C.texte2, UI.POLICE)
		textes.Statuts = etiquette(fond, "Statuts", UDim2.fromScale(0.05, 0.72), UDim2.fromScale(0.9, 0.08), C.vert)
		-- Bande du bas : la ligne vivante (coordonnées, horloge, scan d'identité) écrite par chaque joueur (Ambiance)
		cadre(fond, "LigneVivante", UDim2.fromScale(0.05, 0.84), UDim2.fromScale(0.9, 0.11), C.ecran, 1)
		local bandeau = cadre(fond, "Bandeau", UDim2.fromScale(0, 0.36), UDim2.fromScale(1, 0.26), Color3.fromRGB(120, 18, 24), 0.08)
		bandeau.Visible = false
		bandeau.ZIndex = 3
		textes.Bandeau = bandeau
		textes.Message = etiquette(bandeau, "Message", UDim2.fromScale(0.05, 0.12), UDim2.fromScale(0.9, 0.76), Color3.fromRGB(255, 225, 225), UI.POLICE_GRAS, Enum.TextXAlignment.Center)
		textes.Message.ZIndex = 4
		destinations[part] = { gui = gui, fond = fond, textes = textes }
		table.insert(ordreDestinations, part)
		suivreFace(part, modele, gui)
		dessinerDestination(destinations[part])
	end
	-- Toutes les pièces « Ecran » de la Console, et toutes les pièces d'un Model / Folder « Ecran »
	local function examiner(objet)
		if objet.Name ~= nomEcran then return end
		if objet:IsA("BasePart") then
			local modele = objet.Parent and objet.Parent.Name == nomEcran and objet.Parent or nil
			ajouterDestination(objet, modele)
		elseif objet:IsA("Model") or objet:IsA("Folder") then
			for _, piece in objet:GetDescendants() do
				if piece:IsA("BasePart") then ajouterDestination(piece, objet) end
			end
			objet.DescendantAdded:Connect(function(piece)
				if piece:IsA("BasePart") then ajouterDestination(piece, objet) end
			end)
		end
	end
	local function dossierDesEcrans(attente)
		local objet = interieur
		for i = 1, #cheminEcran - 1 do
			local suivant = objet:FindFirstChild(cheminEcran[i]) or (attente and objet:WaitForChild(cheminEcran[i], attente))
			if not suivant then return nil end
			objet = suivant
		end
		return objet
	end
	local console = dossierDesEcrans(10)
	if console then
		for _, objet in console:GetDescendants() do examiner(objet) end
		console.DescendantAdded:Connect(examiner)
	end
	if #ordreDestinations == 0 then
		warn("[TARDIS] " .. def.Nom .. " : aucun écran « " .. nomEcran .. " » dans " .. table.concat(cheminEcran, " › ", 1, math.max(#cheminEcran - 1, 1)) .. " (affichage de la destination absent).")
	end

	-- majEcran(message) : redessine tout de suite ; un message court remplace l'affichage jusqu'au prochain majEcran()
	local function majEcran(message)
		messageActuel = message
		dessinerDestinations()
	end

	--------------------------------------------------------------------
	-- Écran ingénieur
	--------------------------------------------------------------------
	local ingenieur = nil -- { part, gui, lignes = { [cle] = { valeur, barre } } }
	local function couleurNiveau(v, bas, haut)
		if v <= bas then return C.rouge end
		if v <= haut then return C.ambre end
		return C.vert
	end
	local function majLigne(cle, p, texteValeur, couleur)
		local ligne = ingenieur.lignes[cle]
		ligne.valeur.Text = texteValeur
		ligne.valeur.TextColor3 = couleur
		ligne.barre.Size = UDim2.fromScale(math.clamp(p, 0, 1), 1)
		ligne.barre.BackgroundColor3 = couleur
	end
	local function typeBouclier()
		if exterieur:GetAttribute("BouclierComplet") == true then return "COMPLET" end
		if exterieur:GetAttribute("BouclierBalles") == true then return "ANTI-BALLES" end
		if exterieur:GetAttribute("BouclierJoueurs") == true then return "ANTI-JOUEURS" end
		return nil
	end
	local function dessinerIngenieur()
		if not ingenieur or not ingenieur.part.Parent then return end
		if voiles(ingenieur.gui) then return end
		-- Intégrité de la structure
		local pv = tonumber(exterieur:GetAttribute("PointsDeVie")) or 100
		local avarie = exterieur:GetAttribute("Avarie") == true
		majLigne("integrite", pv / 100, avarie and "AVARIE  ·  0 %" or string.format("%d %%  ·  %s PV", pv, tostring(exterieur:GetAttribute("PV") or "?")),
			avarie and C.rouge or couleurNiveau(pv, 20, 50))
		-- Énergie (tension réglée par la régulation)
		local energie = tonumber(exterieur:GetAttribute("RegulEnergie")) or 80
		local horsBornes = energie < (TECH.SousTension or 20) or energie > (TECH.SurtensionAuDessus or 90)
		majLigne("energie", energie / 100, string.format("%d %%%s", energie,
			energie > (TECH.SurtensionAuDessus or 90) and "  ·  SURTENSION" or (energie < (TECH.SousTension or 20) and "  ·  SOUS-TENSION" or "")),
			horsBornes and C.rouge or C.vert)
		-- Air et vapeur
		local air = tonumber(exterieur:GetAttribute("RegulAir")) or 100
		majLigne("air", air / 100, string.format("%d %%%s", air, air < (TECH.SeuilAirVicie or 25) and "  ·  VICIÉ" or ""), couleurNiveau(air, TECH.SeuilAirVicie or 25, 50))
		local vapeur = tonumber(exterieur:GetAttribute("RegulVapeur")) or 50
		local fuite = exterieur:GetAttribute("VapeurSurcharge") ~= nil
		majLigne("vapeur", fuite and 1 or vapeur / 100, fuite and "FUITE" or string.format("%d %%", vapeur), fuite and C.rouge or (vapeur <= 10 and C.rouge or C.cyan))
		-- Boucliers
		local actif = typeBouclier()
		local energieBouclier = math.floor((tonumber(exterieur:GetAttribute("BouclierEnergie")) or 100) + 0.5)
		if actif then
			majLigne("bouclier", energieBouclier / 100, string.format("%s  ·  %d %%", actif, energieBouclier), couleurNiveau(energieBouclier, 15, 40))
		elseif energieBouclier <= 0 then
			majLigne("bouclier", 0, "TOMBÉ  ·  0 %", C.rouge)
		else
			majLigne("bouclier", energieBouclier / 100, string.format("INACTIF  ·  %d %%", energieBouclier), C.texte2)
		end
	end
	local planifierIngenieur = planificateur(dessinerIngenieur, REGLAGES.Rafraichissement or 0.1)

	-- Le menu de gestion de l'énergie : pilotes de ce TARDIS et techniciens (C.T.A.T. comprise). Vérifié ici, par le serveur
	-- (les attributs des joueurs sont écrits par le serveur ; un client ne peut pas les changer pour le serveur).
	local function autoriseEnergie(joueur)
		return joueur:GetAttribute("TardisPilote_" .. def.Nom) == true or joueur:GetAttribute("TardisTechnicien_" .. def.Nom) == true
			or Config.estTechnicienDe(def, joueur.UserId)
	end
	local derniersClics = {}
	local function cliquerIngenieur(joueur)
		local maintenant = os.clock()
		if derniersClics[joueur] and maintenant - derniersClics[joueur] < 0.5 then return end
		derniersClics[joueur] = maintenant
		if not autoriseEnergie(joueur) then
			remote:FireClient(joueur, "__console", "Réservé aux pilotes et aux ingénieurs.", false)
			return
		end
		if exterieur:GetAttribute("Detruit") then remote:FireClient(joueur, "__console", "TARDIS détruit : écran hors service.", false) return end
		if exterieur:GetAttribute("Alimentation") == false then remote:FireClient(joueur, "__console", "Écran éteint : hors tension.", false) return end
		remote:FireClient(joueur, "__energie", ingenieur and ingenieur.part)
	end
	Players.PlayerRemoving:Connect(function(joueur) derniersClics[joueur] = nil end)

	local function creerIngenieur(objet)
		local part = Config.partDe(objet)
		if not part then return end
		local modele = objet ~= part and objet or nil
		local face = faceDe(part, modele)
		local gui, fond = creerSurface(part, "TardisEcranIngenieur", face or Enum.NormalId.Front, C.ambre, "◆  INGÉNIERIE  ·  " .. def.Nom)
		gui.Enabled = face ~= nil
		local lignes = {}
		local NOMS = { { "integrite", "INTÉGRITÉ" }, { "energie", "ÉNERGIE" }, { "air", "AIR" }, { "vapeur", "VAPEUR" }, { "bouclier", "BOUCLIER" } }
		for i, info in NOMS do
			local y = 0.18 + (i - 1) * 0.14
			local nom = etiquette(fond, "Nom_" .. info[1], UDim2.fromScale(0.05, y), UDim2.fromScale(0.36, 0.065), C.texte2, UI.POLICE_GRAS)
			nom.Text = info[2]
			local valeur = etiquette(fond, "Valeur_" .. info[1], UDim2.fromScale(0.41, y), UDim2.fromScale(0.54, 0.065), C.vert, UI.POLICE_CODE, Enum.TextXAlignment.Right)
			local rail = cadre(fond, "Rail_" .. info[1], UDim2.fromScale(0.05, y + 0.078), UDim2.fromScale(0.9, 0.035), C.gris)
			coin(rail, 1)
			local barre = cadre(rail, "Barre", UDim2.new(), UDim2.fromScale(1, 1), C.vert)
			coin(barre, 1)
			lignes[info[1]] = { valeur = valeur, barre = barre }
		end
		local aide = etiquette(fond, "Aide", UDim2.fromScale(0.05, 0.89), UDim2.fromScale(0.9, 0.06), C.texte2, UI.POLICE, Enum.TextXAlignment.Center)
		aide.Text = "CLIQUER : GESTION DE L'ÉNERGIE (PILOTES ET INGÉNIEURS)"
		ingenieur = { part = part, gui = gui, lignes = lignes }
		suivreFace(part, modele, gui)
		-- Clic sans bouton (ClickDetector) et invite E pour la manette et le mobile
		local clic = Instance.new("ClickDetector")
		clic.Name = "TardisEcranIngenieur"
		clic.MaxActivationDistance = 12
		clic.Parent = part
		clic.MouseClick:Connect(cliquerIngenieur)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "TardisEcranIngenieur"
		prompt.ActionText = "Gestion de l'énergie"
		prompt.ObjectText = "Écran ingénieur"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = false
		-- (V6.9.10.1, relecture) pas E : les invites du Selecteur, du levier et de l'alerte restent visibles
		local invites = Config.InvitesConsole or {}
		local okTouche, touche = pcall(function() return Enum.KeyCode[invites.Touche or "Z"] end)
		local okManette, manette = pcall(function() return Enum.KeyCode[invites.Manette or "DPadRight"] end)
		prompt.KeyboardKeyCode = okTouche and touche or Enum.KeyCode.Z
		prompt.GamepadKeyCode = okManette and manette or Enum.KeyCode.DPadRight
		prompt.Parent = part
		prompt.Triggered:Connect(cliquerIngenieur)
		dessinerIngenieur()
	end
	if cheminIngenieur then
		task.spawn(function()
			local objet = Config.trouverCommande(interieur, "EcranIngenieur", 10)
			if objet then creerIngenieur(objet) end
		end)
	end

	--------------------------------------------------------------------
	-- Mises à jour : à chaque changement d'un attribut affiché (aucune boucle)
	--------------------------------------------------------------------
	for _, nom in { "Etat", "Mode", "VolLibre", "VolPhase", "VolUrgence", "Alerte", "DemarrageBloque", "Camouflage", "Retreci", "Maintenance",
		"AutoDestructionDebut", "Alimentation", "Detruit" } do
		exterieur:GetAttributeChangedSignal(nom):Connect(planifierDestinations)
	end
	for _, nom in { "PointsDeVie", "PV", "Avarie", "RegulEnergie", "RegulAir", "RegulVapeur", "VapeurSurcharge", "BouclierEnergie", "BouclierJoueurs",
		"BouclierBalles", "BouclierComplet", "Alimentation", "Detruit" } do
		exterieur:GetAttributeChangedSignal(nom):Connect(planifierIngenieur)
	end

	return {
		majEcran = majEcran,
		ecransDestination = function() return ordreDestinations end,
		ecranIngenieur = function() return ingenieur and ingenieur.part end,
		cliquerIngenieur = cliquerIngenieur,
	}
end
