-- ServerScriptService > TardisServeur > Ecrans (ModuleScript)
-- Écrans de la console faits entièrement en script (V6.9.10.1). Aucun objet à préparer dans Studio, sauf les pièces.
--   Écrans de destination : TOUTES les pièces nommées « Ecran » de la Console, et toutes les pièces d'un Model ou
--     d'un Folder « Ecran » (deux écrans ou plus). Destination choisie, état, mode du voyage, alerte, démarrage bloqué,
--     camouflé, rétréci, maintenance ; les messages courts de la console (« PAS POSÉ »…) s'y affichent 2 s.
--   Écran ingénieur « Console › Ecran-Ingenieure » : intégrité (PV), énergie, régulation (énergie, air, vapeur) et
--     boucliers, en barres et en pourcentages, rouges quand c'est bas. Un clic (ou Z) ouvre le menu de gestion de
--     l'énergie aux pilotes et aux techniciens ; les autres lisent « Réservé aux pilotes et aux ingénieurs ».
--     (V6.9.10.3) Un Model (ou un dossier) : la pièce qui porte l'attribut « FaceEcran », sinon une pièce nommée
--     Ecran / Screen / Vitre / Affichage / Display, sinon la plus grande pièce visible.
-- Face de l'affichage : attribut « FaceEcran » de la pièce (Front, Back, Top, Bottom, Left, Right, Auto), sinon celui
-- du Model, sinon Config.Ecrans.FaceDestination (Front) ou Config.Ecrans.FaceIngenieur (Auto) ; « Aucune » : pas
-- d'affichage sur cette pièce (cadre, pied…).
--   Auto (V6.9.10.3) : parmi les grandes faces de la pièce (au moins 60 % de la plus grande : pour une plaque, ses
--   deux grands côtés), celle qui regarde le plus vers le haut et vers l'extérieur de la console (vers les joueurs
--   debout autour) ; l'autre grand côté est collé à la console.
-- Netteté (V6.9.10.3) : la finesse (PixelsPerStud) est calculée pour chaque écran, pour que son grand côté fasse
-- Config.Ecrans.Resolution pixels quelle que soit sa taille (un petit écran n'est plus une image floue agrandie) ;
-- chaque ligne fait au moins 8 % de la hauteur de l'écran, et les lignes longues gardent une taille de texte minimale.
-- Au démarrage, une ligne dans l'Output dit quelle pièce et quelle face chaque écran utilise.
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
	local ATTRIBUT_ROTATION = REGLAGES.AttributRotation or "RotationEcran" -- (V6.9.10.4)
	local RESOLUTION = REGLAGES.Resolution or 1024        -- pixels voulus sur le grand côté de chaque écran
	local RESOLUTION_MAX = REGLAGES.ResolutionMax or 2048 -- jamais plus (mémoire), même avec le minimum de finesse
	local FINESSE_MIN = REGLAGES.PixelsParStud or 20      -- finesse minimale (pixels par stud) d'un grand écran
	local TECH = Config.Technicien or {}
	local NOIR = Color3.fromRGB(0, 0, 0)

	--------------------------------------------------------------------
	-- Face de l'affichage
	--------------------------------------------------------------------
	local FACES = { front = "Front", back = "Back", top = "Top", bottom = "Bottom", left = "Left", right = "Right" }
	local function estAucune(valeur)
		local nom = type(valeur) == "string" and string.lower(valeur) or ""
		return nom == "aucune" or nom == "aucun"
	end

	-- Le centre de la console (boîte de ses pièces), pour savoir de quel côté est « l'extérieur »
	local function centreDe(objet)
		if not objet then return nil end
		local ok, cf = pcall(function() return (Config.boite(objet)) end)
		return ok and cf and cf.Position or nil
	end

	-- Face « Auto » : les grandes faces (≥ 60 % de la plus grande), puis celle dont la normale va le plus vers le haut
	-- et vers l'extérieur de la console. À égalité : Top d'abord (ordre ci-dessous). Calcul fait composante par
	-- composante (sans Vector3.FromNormalId) : normale = ±UpVector (Top/Bottom), ±LookVector (Front/Back),
	-- ±RightVector (Right/Left) ; aire = les deux côtés de la pièce qui forment cette face.
	local ORDRE_AUTO = { "Top", "Front", "Back", "Right", "Left", "Bottom" }
	local function faceAuto(part, centre)
		local cf, taille = part.CFrame, part.Size
		local haut, devant, droite = cf.UpVector, cf.LookVector, cf.RightVector
		local faces = {
			Top = { haut, 1, taille.X * taille.Z }, Bottom = { haut, -1, taille.X * taille.Z },
			Front = { devant, 1, taille.X * taille.Y }, Back = { devant, -1, taille.X * taille.Y },
			Right = { droite, 1, taille.Y * taille.Z }, Left = { droite, -1, taille.Y * taille.Z },
		}
		-- Vers l'extérieur : du centre de la console vers la pièce, à l'horizontale (0 si la pièce est au centre)
		local dx, dz = 0, 0
		if centre then
			local p = cf.Position
			dx, dz = p.X - centre.X, p.Z - centre.Z
			local longueur = math.sqrt(dx * dx + dz * dz)
			if longueur > 0.01 then dx, dz = dx / longueur, dz / longueur else dx, dz = 0, 0 end
		end
		local aireMax = 0
		for _, f in faces do aireMax = math.max(aireMax, f[3]) end
		local choisie, meilleur = "Top", nil
		for _, nom in ORDRE_AUTO do
			local f = faces[nom]
			if f[3] >= aireMax * 0.6 then
				local v, signe = f[1], f[2]
				local score = signe * (v.Y + v.X * dx + v.Z * dz)
				if meilleur == nil or score > meilleur + 1e-6 then choisie, meilleur = nom, score end
			end
		end
		return Enum.NormalId[choisie]
	end

	-- Face choisie : attribut de la pièce, sinon du Model, sinon la face par défaut de ce type d'écran.
	-- Renvoie la face (nil = pas d'affichage) et vrai si elle a été choisie automatiquement.
	local function faceDe(part, modele, parDefaut, centre)
		local valeur = part:GetAttribute(ATTRIBUT_FACE)
		if valeur == nil and modele then valeur = modele:GetAttribute(ATTRIBUT_FACE) end
		if valeur == nil then valeur = parDefaut end
		if estAucune(valeur) then return nil, false end
		local nom = type(valeur) == "string" and string.lower(valeur) or ""
		if nom == "auto" then return faceAuto(part, centre), true end
		if FACES[nom] then return Enum.NormalId[FACES[nom]], false end
		warn("[TARDIS] " .. part:GetFullName() .. " : " .. ATTRIBUT_FACE .. " « " .. tostring(valeur) .. " » inconnu (Front, Back, Top, Bottom, Left, Right, Auto ou Aucune) : "
			.. tostring(parDefaut) .. ".")
		if string.lower(tostring(parDefaut)) == "auto" then return faceAuto(part, centre), true end
		return Enum.NormalId[FACES[string.lower(tostring(parDefaut))] or "Front"], false
	end

	--------------------------------------------------------------------
	-- Sens de l'affichage (V6.9.10.4)
	--------------------------------------------------------------------
	-- Une SurfaceGui n'a pas toujours le haut là où on lit : sur les faces de côté, son haut suit le haut de la pièce
	-- (une pièce couchée sur le flanc donne un texte tourné) ; sur la face Top, son haut va vers la face Right de la
	-- pièce (comportement connu de Roblox, différent des Decals). Le contenu est donc tourné de 0, 90, 180 ou 270°.
	-- Attribut « RotationEcran » sur la pièce (ou le Model) : 0, 90, 180, 270 ou Auto ; absent = réglage par défaut.
	-- Auto : le haut du texte va vers le haut du monde (écran incliné ou debout) ; pour un écran à plat, vers le centre
	-- de la console (le joueur lit depuis l'extérieur).
	local function repereFace(cf, face)
		if face == Enum.NormalId.Front then return cf.LookVector, cf.UpVector end
		if face == Enum.NormalId.Back then return -cf.LookVector, cf.UpVector end
		if face == Enum.NormalId.Right then return cf.RightVector, cf.UpVector end
		if face == Enum.NormalId.Left then return -cf.RightVector, cf.UpVector end
		if face == Enum.NormalId.Top then return cf.UpVector, cf.RightVector end
		return -cf.UpVector, cf.RightVector -- Bottom : supposé comme Top (à corriger avec RotationEcran au besoin)
	end
	local function rotationAuto(part, face, centre)
		local cf = part.CFrame
		local normale, haut = repereFace(cf, face)
		local droite = (-normale):Cross(haut) -- la droite de l'image, vue de face
		local voulu = Vector3.new(0, 1, 0) - normale * normale.Y
		if voulu.Magnitude < 0.35 then -- écran presque à plat : le haut du texte vers le centre de la console
			if not centre then return 0 end
			local d = centre - cf.Position
			voulu = d - normale * normale:Dot(d)
			if voulu.Magnitude < 0.01 then return 0 end
		end
		local a, b = voulu:Dot(haut), voulu:Dot(droite)
		local choix, meilleur = 0, a
		for _, c in { { 90, b }, { 180, -a }, { 270, -b } } do
			if c[2] > meilleur + 1e-6 then choix, meilleur = c[1], c[2] end
		end
		return choix
	end
	local function rotationDe(ecran, face)
		local valeur = ecran.part:GetAttribute(ATTRIBUT_ROTATION)
		if valeur == nil and ecran.modele then valeur = ecran.modele:GetAttribute(ATTRIBUT_ROTATION) end
		if valeur == nil then valeur = ecran.rotationParDefaut end
		if type(valeur) == "string" and string.lower(valeur) == "auto" then return rotationAuto(ecran.part, face, ecran.centre), true end
		local n = tonumber(valeur)
		if n and n % 90 == 0 then return n % 360, false end
		warn("[TARDIS] " .. ecran.part:GetFullName() .. " : " .. ATTRIBUT_ROTATION .. " « " .. tostring(valeur) .. " » inconnu (0, 90, 180, 270 ou Auto) : 0.")
		return 0, false
	end

	-- Taille (studs) d'une face : largeur et hauteur de l'image de la SurfaceGui posée dessus.
	-- Top et Bottom (V6.9.10.5) : Roblox oriente le haut de l'image vers la face Right de la pièce (+X, voir repereFace),
	-- donc la HAUTEUR de l'image court le long de X et sa LARGEUR le long de Z (sa droite = (-normale):Cross(haut) = +Z
	-- pour Top) : (Size.Z, Size.X). Avant : (Size.X, Size.Z), à l'envers ; une fois tournées d'un quart de tour, les
	-- couches de l'affichage recevaient des proportions inversées et l'écran ingénieur n'était plus qu'une bande étroite
	-- au milieu de la face.
	local function tailleFace(part, face)
		local taille = part.Size
		if face == Enum.NormalId.Top or face == Enum.NormalId.Bottom then return taille.Z, taille.X end
		if face == Enum.NormalId.Left or face == Enum.NormalId.Right then return taille.Z, taille.Y end
		return taille.X, taille.Y
	end
	-- Finesse d'un écran : RESOLUTION pixels sur le grand côté, au moins FINESSE_MIN pixels par stud, jamais plus de
	-- RESOLUTION_MAX pixels. Renvoie la finesse et la taille de l'image en pixels.
	local function finesse(part, face)
		local largeur, hauteur = tailleFace(part, face)
		local grand = math.max(largeur, hauteur, 0.05)
		local pps = math.min(math.max(RESOLUTION / grand, FINESSE_MIN), RESOLUTION_MAX / grand)
		return pps, largeur * pps, hauteur * pps
	end

	--------------------------------------------------------------------
	-- Construction commune
	--------------------------------------------------------------------
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

	-- Une ligne de texte sur une seule ligne : elle rétrécit pour tenir, mais jamais sous une taille minimale
	-- (proportion de la hauteur de l'écran, recalculée avec la finesse) ; au-delà, elle est coupée (« … »)
	local function uneLigne(ecran, label, proportion)
		label.TextWrapped = false
		label.TextTruncate = Enum.TextTruncate.AtEnd
		local contrainte = Instance.new("UITextSizeConstraint")
		contrainte.Name = "TailleMinimale"
		contrainte.MaxTextSize = 100
		contrainte.Parent = label
		table.insert(ecran.contraintes, { contrainte, proportion })
		return label
	end

	-- Applique la face et la finesse d'un écran (au démarrage, puis si l'attribut ou la taille de la pièce change)
	local function ajuster(ecran)
		local face, auto = faceDe(ecran.part, ecran.modele, ecran.faceParDefaut, ecran.centre)
		ecran.face, ecran.auto = face, auto
		ecran.gui.Enabled = face ~= nil
		if not face then return end
		local pps, largeur, hauteur = finesse(ecran.part, face)
		ecran.gui.Face = face
		ecran.gui.PixelsPerStud = pps
		-- Sens (V6.9.10.4) : les trois couches (affichage, hors tension, détruit) tournent ensemble ; tournées d'un quart
		-- de tour, elles échangent largeur et hauteur pour remplir toujours toute la face (V6.9.10.5 : avec la vraie taille
		-- de l'image, voir tailleFace, elles la remplissent exactement)
		local rotation, rotationAutoChoisie = rotationDe(ecran, face)
		ecran.rotation, ecran.rotationAuto = rotation, rotationAutoChoisie
		local quart = rotation % 180 == 90 and largeur > 0 and hauteur > 0
		for _, nom in { "Fond", "Veille", "Detruit" } do
			local couche = ecran.gui:FindFirstChild(nom)
			if couche then
				couche.AnchorPoint = Vector2.new(0.5, 0.5)
				couche.Position = UDim2.fromScale(0.5, 0.5)
				couche.Size = quart and UDim2.fromScale(hauteur / largeur, largeur / hauteur) or UDim2.fromScale(1, 1)
				couche.Rotation = rotation
			end
		end
		if quart then largeur, hauteur = hauteur, largeur end -- taille de l'affichage tel qu'on le lit
		ecran.largeur, ecran.hauteur = largeur, hauteur
		for _, c in ecran.contraintes do
			c[1].MinTextSize = math.clamp(math.floor(hauteur * c[2] + 0.5), 8, 100)
		end
	end

	-- Une surface : le SurfaceGui, son fond, son cadre lumineux, et les deux voiles (hors tension, détruit)
	local function creerSurface(part, modele, nom, faceParDefaut, centre, accent, titre)
		local gui = Instance.new("SurfaceGui")
		gui.Name = nom
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = FINESSE_MIN
		gui.LightInfluence = 0 -- ni assombri ni délavé par l'éclairage de la salle
		gui.ZOffset = 1 -- (V6.9.10.3) au-dessus d'un Decal ou d'une autre SurfaceGui sur la même face
		gui.ClipsDescendants = true
		gui.Parent = part
		local ecran = { part = part, modele = modele, gui = gui, faceParDefaut = faceParDefaut, centre = centre, contraintes = {},
			rotationParDefaut = nom == "TardisEcranIngenieur" and (REGLAGES.RotationIngenieur or "Auto") or (REGLAGES.RotationDestination or 0) }
		local fond = cadre(gui, "Fond", UDim2.new(), UDim2.fromScale(1, 1), C.ecran)
		ecran.fond = fond
		local degrade = Instance.new("UIGradient")
		degrade.Rotation = 90
		degrade.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 165, 200))
		degrade.Parent = fond
		local bord = Instance.new("UIStroke")
		bord.Color, bord.Thickness, bord.Transparency = accent, 6, 0.35
		bord.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		bord.Parent = fond
		local enTete = etiquette(fond, "Titre", UDim2.fromScale(0.05, 0.03), UDim2.fromScale(0.9, 0.11), accent, UI.POLICE_GRAS)
		enTete.Text = titre
		uneLigne(ecran, enTete, 0.06)
		cadre(fond, "Filet", UDim2.fromScale(0.05, 0.15), UDim2.fromScale(0.9, 0.006), accent, 0.55)
		-- Hors tension : noir, un petit texte discret
		local veille = cadre(gui, "Veille", UDim2.new(), UDim2.fromScale(1, 1), NOIR)
		veille.Visible = false
		veille.ZIndex = 5
		local horsTension = etiquette(veille, "Texte", UDim2.fromScale(0.2, 0.44), UDim2.fromScale(0.6, 0.12), Color3.fromRGB(70, 70, 80), UI.POLICE, Enum.TextXAlignment.Center)
		horsTension.Text = "HORS TENSION"
		horsTension.ZIndex = 6
		-- Détruit : affichage d'alerte
		local detruit = cadre(gui, "Detruit", UDim2.new(), UDim2.fromScale(1, 1), Color3.fromRGB(40, 4, 8))
		detruit.Visible = false
		detruit.ZIndex = 7
		local alarme = etiquette(detruit, "Titre", UDim2.fromScale(0.05, 0.3), UDim2.fromScale(0.9, 0.2), C.rouge, UI.POLICE_GRAS, Enum.TextXAlignment.Center)
		alarme.Text = "!! TARDIS DÉTRUIT !!"
		alarme.ZIndex = 8
		local sous = etiquette(detruit, "SousTitre", UDim2.fromScale(0.1, 0.55), UDim2.fromScale(0.8, 0.12), Color3.fromRGB(255, 160, 160), UI.POLICE, Enum.TextXAlignment.Center)
		sous.Text = "RECONSTITUTION EN COURS"
		sous.ZIndex = 8
		return ecran
	end

	-- Hors tension et détruit : les voiles de chaque surface
	local function voiles(gui)
		local horsTension = exterieur:GetAttribute("Alimentation") == false
		local detruit = exterieur:GetAttribute("Detruit") == true
		gui.Veille.Visible = horsTension and not detruit
		gui.Detruit.Visible = detruit
		return horsTension or detruit
	end

	-- Un écran peut changer de face ou de taille en jeu (attribut ou pièce modifiés dans Studio pendant un test)
	local function suivre(ecran)
		local function maj() ajuster(ecran) end
		ecran.part:GetAttributeChangedSignal(ATTRIBUT_FACE):Connect(maj)
		ecran.part:GetAttributeChangedSignal(ATTRIBUT_ROTATION):Connect(maj)
		if ecran.modele then
			ecran.modele:GetAttributeChangedSignal(ATTRIBUT_FACE):Connect(maj)
			ecran.modele:GetAttributeChangedSignal(ATTRIBUT_ROTATION):Connect(maj)
		end
		ecran.part:GetPropertyChangedSignal("Size"):Connect(maj)
	end

	-- Chemin lisible d'une pièce depuis l'intérieur (« Console › Ecran-Ingenieure › Vitre »)
	local function cheminLisible(objet)
		local noms = {}
		local o = objet
		while o and o ~= interieur and o ~= game do
			table.insert(noms, 1, o.Name)
			o = o.Parent
		end
		return table.concat(noms, " › ")
	end
	-- « destination « Console › Ecran » : face Front (1024 × 512 px) » : pour la ligne de l'Output
	local function description(genre, ecran)
		if not ecran.face then return genre .. " « " .. cheminLisible(ecran.part) .. " » : aucune face (" .. ATTRIBUT_FACE .. " = Aucune)" end
		return string.format("%s « %s » : face %s%s, sens %d°%s (%d × %d px)", genre, cheminLisible(ecran.part), ecran.face.Name, ecran.auto and " (auto)" or "",
			ecran.rotation or 0, ecran.rotationAuto and " (auto)" or "", math.floor(ecran.largeur + 0.5), math.floor(ecran.hauteur + 0.5))
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
	local destinations = {} -- [part] = écran { part, gui, fond, textes, face… }
	local ordreDestinations = {}
	local messageActuel = nil
	local demarrageAnnonce = false -- la ligne de l'Output du démarrage est écrite : les écrans ajoutés après ont la leur

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
			t.Etat.Text = "●  VOL LIBRE" .. (exterieur:GetAttribute("VolPhase") == "Invisible" and "  ·  VORTEX" or "")
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
	local centreConsole = centreDe(console)

	-- Disposition (V6.9.10.3) : cinq lignes, chacune d'au moins 8 % de la hauteur de l'écran (avant : 6,5 à 8 %) ;
	-- l'état et le mode partagent une ligne. Proportions : de la hauteur de l'écran.
	local function ajouterDestination(part, modele)
		if destinations[part] or not part:IsA("BasePart") then return end
		if nomIngenieur then -- une pièce « Ecran » rangée dans l'écran ingénieur n'est pas un écran de destination
			local p = part
			while p and p ~= interieur do
				if p.Name == nomIngenieur then return end
				p = p.Parent
			end
		end
		local ecran = creerSurface(part, modele, "TardisEcranDestination", REGLAGES.FaceDestination or "Front", centreConsole, C.cyan, "◆  TARDIS  ·  NAVIGATION")
		local fond = ecran.fond
		local textes = {}
		textes.Etiquette = etiquette(fond, "EtiquetteDestination", UDim2.fromScale(0.05, 0.175), UDim2.fromScale(0.9, 0.08), C.texte2, UI.POLICE_GRAS)
		textes.Etiquette.Text = "DESTINATION"
		textes.Destination = etiquette(fond, "Destination", UDim2.fromScale(0.05, 0.26), UDim2.fromScale(0.9, 0.22), C.ambre, UI.POLICE_TITRE)
		textes.Etat = uneLigne(ecran, etiquette(fond, "Etat", UDim2.fromScale(0.05, 0.51), UDim2.fromScale(0.5, 0.12), C.vert), 0.06)
		textes.Mode = uneLigne(ecran, etiquette(fond, "Mode", UDim2.fromScale(0.57, 0.51), UDim2.fromScale(0.38, 0.12), C.texte2, UI.POLICE_GRAS, Enum.TextXAlignment.Right), 0.05)
		textes.Statuts = uneLigne(ecran, etiquette(fond, "Statuts", UDim2.fromScale(0.05, 0.655), UDim2.fromScale(0.9, 0.1), C.vert), 0.05)
		-- Bande du bas : la ligne vivante (coordonnées, horloge, scan d'identité) écrite par chaque joueur (Ambiance)
		cadre(fond, "LigneVivante", UDim2.fromScale(0.05, 0.8), UDim2.fromScale(0.9, 0.13), C.ecran, 1)
		local bandeau = cadre(fond, "Bandeau", UDim2.fromScale(0, 0.36), UDim2.fromScale(1, 0.26), Color3.fromRGB(120, 18, 24), 0.08)
		bandeau.Visible = false
		bandeau.ZIndex = 3
		textes.Bandeau = bandeau
		textes.Message = etiquette(bandeau, "Message", UDim2.fromScale(0.05, 0.12), UDim2.fromScale(0.9, 0.76), Color3.fromRGB(255, 225, 225), UI.POLICE_GRAS, Enum.TextXAlignment.Center)
		textes.Message.ZIndex = 4
		ecran.textes = textes
		ajuster(ecran)
		destinations[part] = ecran
		table.insert(ordreDestinations, part)
		suivre(ecran)
		dessinerDestination(ecran)
		if demarrageAnnonce then print("[TARDIS] " .. def.Nom .. " · nouvel écran : " .. description("destination", ecran) .. ".") end
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
	local ingenieur = nil -- écran { part, gui, lignes = { [cle] = { valeur, barre } }, face… }
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

	-- (V6.9.10.3) La pièce qui porte l'affichage : la pièce elle-même ; dans un Model ou un dossier, la pièce qui porte
	-- l'attribut FaceEcran (sauf « Aucune »), sinon la plus grande pièce nommée comme un écran (Ecran, Screen, Vitre,
	-- Affichage, Display), sinon la plus grande pièce visible (sa plus grande face), sinon la plus grande tout court.
	-- (Avant : le PrimaryPart ou la PREMIÈRE pièce trouvée, souvent le boîtier ou un bouton : affichage invisible.)
	local MOTS_ECRAN = { "ecran", "écran", "screen", "vitre", "affichage", "display" }
	local function pieceAffichage(objet)
		if objet:IsA("BasePart") then return objet end
		local designee, nommee, visible, secours = nil, nil, nil, nil
		local aireNommee, aireVisible, aireSecours = -1, -1, -1
		for _, p in objet:GetDescendants() do
			if p:IsA("BasePart") then
				local valeur = p:GetAttribute(ATTRIBUT_FACE)
				if not estAucune(valeur) then
					if valeur ~= nil and not designee then designee = p end
					local taille = p.Size
					local aire = math.max(taille.X * taille.Y, taille.X * taille.Z, taille.Y * taille.Z)
					local nom = string.lower(p.Name)
					local commeEcran = false
					for _, mot in MOTS_ECRAN do
						if string.find(nom, mot, 1, true) then commeEcran = true end
					end
					if commeEcran and aire > aireNommee then nommee, aireNommee = p, aire end
					if (tonumber(p.Transparency) or 0) < 1 and aire > aireVisible then visible, aireVisible = p, aire end
					if aire > aireSecours then secours, aireSecours = p, aire end
				end
			end
		end
		return designee or nommee or visible or secours
	end

	-- Disposition (V6.9.10.3) : cinq lignes « NOM ……… VALEUR » d'au moins 8,5 % de la hauteur, chacune avec sa barre
	local function creerIngenieur(objet)
		local part = pieceAffichage(objet)
		if not part then
			warn("[TARDIS] " .. def.Nom .. " : « " .. cheminLisible(objet) .. " » ne contient aucune pièce : écran ingénieur absent.")
			return
		end
		local modele = objet ~= part and objet or nil
		local dossierConsole = objet.Parent
		local ecran = creerSurface(part, modele, "TardisEcranIngenieur", REGLAGES.FaceIngenieur or "Auto", centreDe(dossierConsole) or centreConsole,
			C.ambre, "◆  INGÉNIERIE  ·  " .. def.Nom)
		local fond = ecran.fond
		local lignes = {}
		local NOMS = { { "integrite", "INTÉGRITÉ" }, { "energie", "ÉNERGIE" }, { "air", "AIR" }, { "vapeur", "VAPEUR" }, { "bouclier", "BOUCLIER" } }
		for i, info in NOMS do
			local y = 0.18 + (i - 1) * 0.137
			local nom = uneLigne(ecran, etiquette(fond, "Nom_" .. info[1], UDim2.fromScale(0.05, y), UDim2.fromScale(0.36, 0.088), C.texte2, UI.POLICE_GRAS), 0.05)
			nom.Text = info[2]
			local valeur = uneLigne(ecran, etiquette(fond, "Valeur_" .. info[1], UDim2.fromScale(0.41, y), UDim2.fromScale(0.54, 0.088), C.vert, UI.POLICE_CODE, Enum.TextXAlignment.Right), 0.05)
			local rail = cadre(fond, "Rail_" .. info[1], UDim2.fromScale(0.05, y + 0.093), UDim2.fromScale(0.9, 0.03), C.gris)
			coin(rail, 1)
			local barre = cadre(rail, "Barre", UDim2.new(), UDim2.fromScale(1, 1), C.vert)
			coin(barre, 1)
			lignes[info[1]] = { valeur = valeur, barre = barre }
		end
		local aide = uneLigne(ecran, etiquette(fond, "Aide", UDim2.fromScale(0.05, 0.885), UDim2.fromScale(0.9, 0.08), C.texte2, UI.POLICE, Enum.TextXAlignment.Center), 0.045)
		aide.Text = "CLIC : GESTION DE L'ÉNERGIE"
		ecran.lignes = lignes
		ajuster(ecran)
		ingenieur = ecran
		suivre(ecran)
		-- Clic sans bouton (ClickDetector, sur tout le Model s'il y en a un) et invite pour la manette et le mobile
		local clic = Instance.new("ClickDetector")
		clic.Name = "TardisEcranIngenieur"
		clic.MaxActivationDistance = 12
		clic.Parent = (modele and modele:IsA("Model")) and modele or part
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

	-- (V6.9.10.3) Une ligne dans l'Output au démarrage : la pièce et la face de chaque écran (pour régler FaceEcran)
	local function annoncer()
		local morceaux = {}
		for _, part in ordreDestinations do table.insert(morceaux, description("destination", destinations[part])) end
		if ingenieur then
			table.insert(morceaux, description("ingénieur", ingenieur))
		elseif cheminIngenieur then
			table.insert(morceaux, "ingénieur « " .. table.concat(cheminIngenieur, " › ") .. " » introuvable")
		end
		if #morceaux == 0 then morceaux = { "aucun" } end
		print("[TARDIS] " .. def.Nom .. " · écrans de la console : " .. table.concat(morceaux, " ; ") .. ".")
		demarrageAnnonce = true
	end
	if cheminIngenieur then
		task.spawn(function()
			local objet = Config.trouverCommande(interieur, "EcranIngenieur", 10)
			if objet then creerIngenieur(objet) end
			annoncer()
		end)
	else
		annoncer()
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
