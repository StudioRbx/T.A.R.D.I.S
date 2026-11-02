-- StarterPlayerScripts > TardisExtrasClient > Signalisation (ModuleScript) — V6.9.3
-- Visuel et son des voyages :
--   1. Annonce de bord (ajout C17, modification 12) : « Départ dans 3… 2… 1… » pendant le son de départ, puis
--      « Matérialisation dans 3… 2… 1… » à la fin de l'arrivée, pour les joueurs à bord (bips en option).
--   2. Traînée au sol après un Rapide (ajout C15) : des lignes lumineuses vertes qui filent sur le sol, au départ et à
--      l'arrivée, et s'effacent en quelques secondes. Visibles par tous.
--   3. Enseigne « POLICE BOX » (ajout C16) : elle clignote pendant la démat et la remat, à un rythme propre au mode
--      (souffle lent en Classique, grésillement en Urgence, stroboscope en Rapide, fixe et vive en Sauvetage, éteinte
--      en Silencieux, chaos rouge en Catastrophe).
--   4. Ambiance sonore par thème d'intérieur (ajout C18) : chaque thème (Classique, Nuit, Alerte…) change la hauteur du
--      bourdonnement du moteur et peut jouer sa propre boucle d'ambiance (Config.AmbianceThemes), à bord seulement.
-- Tout est local (chaque client calcule à partir des attributs Etat, DebutEtat, Mode, Theme).

return function(contexte)
	local C, Config, E, RunService, UI = contexte.C, contexte.Config, contexte.E, contexte.RunService, contexte.UI
	local creer, texte, animer, def = contexte.creer, contexte.texte, contexte.animer, contexte.def
	local exterieur, interieur, joueur, jeSuisDedans, partTemporaire = contexte.exterieur, contexte.interieur, contexte.joueur, contexte.jeSuisDedans, contexte.partTemporaire
	local ANNONCE = Config.AnnonceBord or {}
	local VERT = UI.couleurMode("Express")

	local function etat() return exterieur:GetAttribute("Etat") or E.Pose end
	local function maintenant() return workspace:GetServerTimeNow() end

	--------------------------------------------------------------------
	-- 1. Annonce de bord : compte à rebours au centre de l'écran, pour ceux qui sont à bord
	--------------------------------------------------------------------
	local gui = creer("ScreenGui", { Name = "TardisAnnonceBord_" .. def.Nom, ResetOnSpawn = false, DisplayOrder = 12, IgnoreGuiInset = true,
		Parent = joueur:WaitForChild("PlayerGui") })
	local cadre = creer("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.16, 0), Size = UDim2.fromOffset(420, 92),
		BackgroundTransparency = 1, Visible = false, Parent = gui })
	local phrase = texte({ Text = "", Font = UI.POLICE_GRAS, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.texte2,
		Size = UDim2.new(1, 0, 0, 20), TextStrokeTransparency = 0.6, Parent = cadre })
	local chiffre = texte({ Text = "", Font = UI.POLICE_TITRE, TextSize = 56, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.ambre,
		Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 64), TextStrokeTransparency = 0.4, Parent = cadre })
	local echelleChiffre = creer("UIScale", { Parent = chiffre })
	local dernierAffiche = nil

	local function afficher(texteHaut, valeur, couleur, discret)
		if not cadre.Visible then cadre.Visible = true end
		phrase.Text = texteHaut
		if valeur ~= dernierAffiche then
			dernierAffiche = valeur
			chiffre.Text = valeur
			chiffre.TextColor3 = couleur
			echelleChiffre.Scale = 1.35
			chiffre.TextTransparency = 0
			animer(echelleChiffre, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
			if ANNONCE.Bip ~= false and not discret and tonumber(valeur) then UI.son("Notification") end
		end
	end
	local function cacher()
		if cadre.Visible then cadre.Visible = false end
		dernierAffiche = nil
	end

	local finAffichage = 0 -- « DÉMATÉRIALISATION » / « POSÉ » restent affichés un court moment
	RunService.Heartbeat:Connect(function()
		if ANNONCE.Actif == false or not jeSuisDedans() then cacher() return end
		local e = etat()
		local mode = Config.modeDe(exterieur)
		local discret = (Config.Modes[mode] or {}).Discret == true
		local couleur = (mode == "Normal") and C.ambre or UI.couleurMode(mode)
		local debut = exterieur:GetAttribute("DebutEtat") or 0
		local t = maintenant() - debut
		if e == E.Demat then
			local _, decalage = Config.Timing(E.Demat, mode)
			local reste = decalage - t
			if reste > 0 then
				afficher("DÉPART DANS", tostring(math.ceil(reste)), couleur, discret)
				return
			elseif reste > -1.2 then
				afficher(Config.libelleMode(mode):upper(), "DÉMATÉRIALISATION", couleur, discret)
				chiffre.TextSize = 30
				return
			end
		elseif e == E.Remat then
			local duree, decalage = Config.Timing(E.Remat, mode)
			local reste = decalage + duree - t
			if reste > 0 and reste <= (ANNONCE.Secondes or 3) then
				chiffre.TextSize = 56
				afficher("MATÉRIALISATION DANS", tostring(math.ceil(reste)), couleur, discret)
				finAffichage = os.clock() + 2.2
				return
			end
		elseif e == E.Pose and os.clock() < finAffichage then
			chiffre.TextSize = 30
			afficher("POSÉ", tostring(exterieur:GetAttribute("Position") or ""):upper(), C.vert, true)
			return
		end
		chiffre.TextSize = 56
		cacher()
	end)

	--------------------------------------------------------------------
	-- 2. Traînée au sol après un Rapide : lignes lumineuses qui filent et s'effacent
	--------------------------------------------------------------------
	local function sol(position)
		local parametres = RaycastParams.new()
		parametres.FilterType = Enum.RaycastFilterType.Exclude
		parametres.FilterDescendantsInstances = { exterieur, interieur, joueur.Character }
		local r = workspace:Raycast(position + Vector3.new(0, 4, 0), Vector3.new(0, -40, 0), parametres)
		return r and r.Position, r and r.Normal
	end
	local function trainee()
		if (Config.Signalisation or {}).Trainee == false then return end
		local pivot = exterieur:GetPivot()
		local point, normale = sol(pivot.Position)
		if not point then return end
		local reduit = UI.effetsReduits()
		local arriere = -(pivot.LookVector * Vector3.new(1, 0, 1))
		arriere = arriere.Magnitude > 0.01 and arriere.Unit or Vector3.new(0, 0, 1)
		local cote = arriere:Cross(Vector3.yAxis)
		local nombre = reduit and 3 or 7
		for i = 1, nombre do
			-- Lignes parallèles, de longueurs différentes, qui partent de sous la cabine vers l'arrière
			local decalage = (i - (nombre + 1) / 2) * 0.9 + (math.random() - 0.5) * 0.4
			local longueur = 10 + math.random() * 14
			local depart = point + cote * decalage + Vector3.new(0, 0.06, 0)
			local ligne = partTemporaire({ Name = "TardisTrainee", Material = Enum.Material.Neon, Color = VERT, Transparency = 0.15,
				Size = Vector3.new(0.18, 0.05, 0.1), CFrame = CFrame.lookAt(depart, depart + arriere) })
			-- Elle s'allonge d'un coup, puis s'efface en glissant vers l'arrière
			animer(ligne, 0.18, { Size = Vector3.new(0.18, 0.05, longueur), CFrame = CFrame.lookAt(depart + arriere * longueur / 2, depart + arriere * (longueur / 2 + 1)) },
				Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			task.delay(0.3 + i * 0.05, function()
				animer(ligne, 3.2, { Transparency = 1, Size = Vector3.new(0.05, 0.02, longueur * 1.3) }, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
			end)
			task.delay(3.8, function() ligne:Destroy() end)
		end
		-- Une marque circulaire sous la cabine, qui refroidit du vert au gris
		if not reduit and normale then
			local marque = partTemporaire({ Name = "TardisMarque", Material = Enum.Material.Neon, Color = VERT, Transparency = 0.35, Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.05, 7, 7), CFrame = CFrame.new(point + Vector3.new(0, 0.04, 0)) * CFrame.Angles(0, 0, math.rad(90)) })
			animer(marque, 2.5, { Color = Color3.fromRGB(60, 70, 60), Transparency = 1 }, Enum.EasingStyle.Sine)
			task.delay(2.6, function() marque:Destroy() end)
		end
	end
	local etatAvant = etat()
	exterieur:GetAttributeChangedSignal("Etat"):Connect(function()
		local e = etat()
		local mode = Config.modeDe(exterieur)
		if mode == "Express" then
			if e == E.Demat then
				-- Au départ : la traînée apparaît quand la cabine s'efface (après le son)
				local _, decalage = Config.Timing(E.Demat, mode)
				task.delay(decalage + 0.1, trainee)
			elseif e == E.Remat then
				local duree, decalage = Config.Timing(E.Remat, mode)
				task.delay(decalage + duree * 0.6, trainee)
			end
		end
		etatAvant = e
	end)

	--------------------------------------------------------------------
	-- 3. Enseigne « POLICE BOX » : un rythme par mode pendant la démat et la remat
	--------------------------------------------------------------------
	-- (TardisEffets fait déjà le fondu de la transparence : ici on ne touche qu'à la couleur du texte et à la brillance)
	local enseignes = {} -- { label, couleur, gui, brillance }
	for _, objet in exterieur:GetDescendants() do
		if objet:IsA("TextLabel") and string.find(string.upper(objet.Text), "POLICE") then
			local surface = objet:FindFirstAncestorWhichIsA("SurfaceGui")
			table.insert(enseignes, { label = objet, couleur = objet.TextColor3, gui = surface, brillance = surface and surface.Brightness or 1 })
		end
	end
	local SOMBRE = Color3.fromRGB(28, 30, 36)
	local function rythme(mode, t, reduit)
		-- Renvoie l'intensité (0 éteinte .. 1 normale .. 1,6 vive) et une teinte éventuelle
		if mode == "Silencieux" then return 0.08 end
		if mode == "Express" then
			local frequence = reduit and 2 or 8
			return (math.floor(t * frequence * 2) % 2 == 0) and 1.6 or 0.15
		end
		if mode == "Urgence" then
			-- Grésillement : longues coupures irrégulières
			local n = math.noise(t * 6, 3.1)
			return n > 0.15 and 0.1 or (reduit and 1 or (1 + math.random() * 0.4))
		end
		if mode == "Catastrophe" then
			local n = math.noise(t * 9, 7.7)
			return (n > 0 and 1.5 or 0.1), C.rouge
		end
		if mode == "Sauvetage" then return 1.5, Color3.fromRGB(200, 245, 255) end
		return 0.55 + 0.45 * math.sin(t * math.pi) -- Classique : un souffle toutes les 2 s
	end
	local actif = false
	RunService.Heartbeat:Connect(function()
		if #enseignes == 0 or (Config.Signalisation or {}).Enseigne == false then return end
		local e = etat()
		local enVoyage = e == E.Demat or e == E.Remat
		if enVoyage then
			actif = true
			local t = maintenant() - (exterieur:GetAttribute("DebutEtat") or 0)
			local intensite, teinte = rythme(Config.modeDe(exterieur), t, UI.effetsReduits())
			for _, en in enseignes do
				local base = teinte and en.couleur:Lerp(teinte, 0.6) or en.couleur
				en.label.TextColor3 = SOMBRE:Lerp(base, math.clamp(intensite, 0, 1))
				if en.gui then en.gui.Brightness = en.brillance * math.max(intensite, 0.05) end
			end
		elseif actif then
			actif = false
			for _, en in enseignes do
				en.label.TextColor3 = en.couleur
				if en.gui then en.gui.Brightness = en.brillance end
			end
		end
	end)

	--------------------------------------------------------------------
	-- 4. Ambiance sonore par thème d'intérieur
	--------------------------------------------------------------------
	local AMBIANCES = Config.AmbianceThemes or {}
	local boucle, boucleId = nil, nil
	local presence = 0
	local function themeActuel()
		if exterieur:GetAttribute("Alerte") == true then return "Alerte" end
		return exterieur:GetAttribute("Theme") or "Classique"
	end
	local moteurs = {}
	local function chercherMoteurs()
		table.clear(moteurs)
		for _, objet in interieur:GetDescendants() do
			if objet:IsA("Sound") and string.sub(objet.Name, 1, 7) == "Moteur_" then table.insert(moteurs, objet) end
		end
	end
	task.delay(3, chercherMoteurs) -- le module Ambiance les crée au démarrage
	local vitesse = 1
	RunService.Heartbeat:Connect(function(dt)
		local reglage = AMBIANCES[themeActuel()] or AMBIANCES.Classique or {}
		-- Hauteur du bourdonnement : glisse doucement vers celle du thème
		vitesse += ((reglage.Vitesse or 1) - vitesse) * math.min(dt * 0.8, 1)
		for _, son in moteurs do
			if son.Parent then son.PlaybackSpeed = vitesse end
		end
		-- Boucle d'ambiance du thème (si un son est renseigné), à bord seulement, en fondu
		local id = reglage.Son
		if id ~= boucleId then
			boucleId = id
			if boucle then
				local ancienne = boucle
				animer(ancienne, 1.5, { Volume = 0 })
				task.delay(1.6, function() ancienne:Destroy() end)
				boucle = nil
			end
			if id and id ~= 0 then
				boucle = creer("Sound", { Name = "TardisAmbianceTheme", SoundId = type(id) == "number" and ("rbxassetid://" .. id) or tostring(id), Looped = true,
					Volume = 0, Parent = game:GetService("SoundService") })
				boucle:Play()
			end
		end
		local alimente = exterieur:GetAttribute("Alimentation") ~= false and exterieur:GetAttribute("Detruit") ~= true
		presence += (((jeSuisDedans() and alimente) and 1 or 0) - presence) * math.min(dt * 1.2, 1)
		if boucle then
			-- La musique du jukebox passe devant : l'ambiance baisse
			local attenuation = exterieur:GetAttribute("Jukebox") ~= nil and 0.3 or 1
			boucle.Volume = (reglage.Volume or 0.3) * UI.volume() * presence * attenuation
		end
	end)
end
