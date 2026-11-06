-- StarterPlayerScripts > TardisTablette > Suivi (ModuleScript)
-- Mises à jour lentes, balises de détresse, sentinelle et animations continues
-- Extrait du script principal en V6.6.3 : reçoit ce qu'il utilise, renvoie ce que la suite utilise.

return function(contexte)
	local C, Config, E, Players, R, RunService = contexte.C, contexte.Config, contexte.E, contexte.Players, contexte.R, contexte.RunService
	local S, UI, W, animer, camera, def = contexte.S, contexte.UI, contexte.W, contexte.animer, contexte.camera, contexte.def
	local Commandes = contexte.Commandes
	local distanceDe, exterieur, interieur, joueur, journaliser, lireEtat = contexte.distanceDe, contexte.exterieur, contexte.interieur, contexte.joueur, contexte.journaliser, contexte.lireEtat
	local majCarte, majDisposition, majFiche, majScanner, notifier, remote = contexte.majCarte, contexte.majDisposition, contexte.majFiche, contexte.majScanner, contexte.notifier, contexte.remote

	--------------------------------------------------------------------
	-- Mises à jour lentes (télémétrie, occupants, distances, statistiques)
	--------------------------------------------------------------------
	local boiteCF, boiteTaille = Config.boite(interieur)
	local function dansInterieur(position)
		local p = boiteCF:PointToObjectSpace(position)
		return math.abs(p.X) <= boiteTaille.X / 2 and math.abs(p.Y) <= boiteTaille.Y / 2 and math.abs(p.Z) <= boiteTaille.Z / 2
	end

	local function majLente(e)
		-- Télémétrie
		local pivot = exterieur:GetPivot()
		local p = pivot.Position
		W.infoLieu.Text = tostring(exterieur:GetAttribute("Position") or "?")
		W.infoCoord.Text = string.format("%d, %d, %d", p.X, p.Y, p.Z)
		local devant = pivot.LookVector
		W.infoCap.Text = string.format("%05.1f°", (math.deg(math.atan2(-devant.X, -devant.Z)) + 360) % 360)
		W.infoEchelle.Text = math.floor(e.echelle * 100 + 0.5) .. " %" .. (e.porteur and ("  ·  porté par " .. e.porteur.DisplayName) or "")
		W.infoPortes.Text = (e.porteOuverte and "Ouvertes" or "Fermées") .. (e.verrouille and "  ·  verrouillées" or "")
		W.infoDestination.Text = S.choix and S.choix.nom or "—"

		-- Occupants de la salle de contrôle
		local noms = {}
		for _, autre in Players:GetPlayers() do
			local racine = autre.Character and autre.Character:FindFirstChild("HumanoidRootPart")
			if racine and dansInterieur(racine.Position) then
				table.insert(noms, autre.DisplayName)
			end
		end
		W.occCompte.Text = #noms .. " à bord"
		W.occListe.Text = #noms == 0 and "Personne à bord." or table.concat(noms, "  ·  ")

		-- Distances dans le tableau (colonne DIST.)
		for _, element in S.boutonsChoix do
			local distance = distanceDe(element.choix)
			element.ligne.regler("dist", distance and string.format("%d", distance) or "—")
		end
		majFiche()

		-- Statistiques
		local vortex = S.tempsVortex
		if S.debutVol then vortex += os.clock() - S.debutVol end
		W.statVoyages.Text = tostring(S.voyages)
		W.statVortex.Text = UI.formatTemps(vortex)
		W.statSession.Text = UI.formatTemps(os.clock() - S.debutSession)
	end

	--------------------------------------------------------------------
	-- Balises de détresse (/balisehelp ou /tardis help) : alerte cliquable pour les pilotes
	--------------------------------------------------------------------
	do
		local vues = {}
		local baliseCourante = nil
		local function cacher()
			animer(W.alerteBalise, 0.3, { Position = UDim2.new(1, 340, 0, 170) }).Completed:Wait()
			W.alerteBalise.Visible = false
		end
		W.alerteBaliseFermer.Activated:Connect(function() task.spawn(cacher) end)
		W.alerteBaliseBouton.Activated:Connect(function()
			if baliseCourante then remote:FireServer("BaliseAller", { joueur = baliseCourante }) end
			task.spawn(cacher)
		end)
		exterieur:GetAttributeChangedSignal("Balises"):Connect(function()
			if joueur:GetAttribute("TardisPilote_" .. def.Nom) ~= true then return end
			local actives = {}
			for ligne in string.gmatch(exterieur:GetAttribute("Balises") or "", "[^\n]+") do
				local id, nom = string.match(ligne, "^(%d+)\t(.-)\t")
				if id then
					actives[id] = true
					if not vues[id] then
						vues[id] = true
						baliseCourante = tonumber(id)
						W.alerteBaliseNotif.regler("Balise de détresse : " .. nom .. " appelle le TARDIS.", "alerte", "BALISE")
						journaliser("Balise de détresse : " .. nom .. ".", C.rouge)
						if S.ouvert then notifier("Balise : " .. nom .. " appelle le TARDIS (voir l'alerte).", true) end
						W.alerteBalise.Visible = true
						W.alerteBalise.Position = UDim2.new(1, 340, 0, 170)
						animer(W.alerteBalise, 0.45, { Position = UDim2.new(1, -20, 0, 170) }, Enum.EasingStyle.Back)
					end
				end
			end
			for id in vues do
				if not actives[id] then vues[id] = nil end
			end
		end)
	end

	--------------------------------------------------------------------
	-- Sentinelle : prévient les pilotes quand quelqu'un s'approche du TARDIS posé (même tablette fermée)
	--------------------------------------------------------------------
	do
		local jetonAlerte = 0
		local function alerteSentinelle(message)
			journaliser(message, C.ambre)
			if S.ouvert then
				notifier(message, true)
				return
			end
			jetonAlerte += 1
			local moi = jetonAlerte
			W.alerteNotif.regler(message, "attention", "SENTINELLE")
			W.alerte.Visible = true
			W.alerte.Position = UDim2.new(1, 340, 0, 90)
			animer(W.alerte, 0.45, { Position = UDim2.new(1, -20, 0, 90) }, Enum.EasingStyle.Back)
			task.delay(5, function()
				if moi ~= jetonAlerte then return end
				animer(W.alerte, 0.3, { Position = UDim2.new(1, 340, 0, 90) }).Completed:Wait()
				if moi == jetonAlerte then W.alerte.Visible = false end
			end)
		end

		local function majBoutonSentinelle()
			W.btnSentinelle.Text = S.sentinelle and "SENTINELLE  ●" or "SENTINELLE  ○"
			UI.colorer(W.btnSentinelle, S.sentinelle and Color3.fromRGB(30, 90, 60) or C.fond)
		end
		W.btnSentinelle.Activated:Connect(function()
			S.sentinelle = not S.sentinelle
			table.clear(S.proches)
			majBoutonSentinelle()
			journaliser(S.sentinelle and "Sentinelle activée." or "Sentinelle désactivée.", C.vert)
		end)
		majBoutonSentinelle()

		local rayon = (Config.Sentinelle or {}).Rayon or 35
		task.spawn(function()
			while true do
				task.wait(0.5)
				local actif = S.sentinelle and joueur:GetAttribute("TardisPilote_" .. def.Nom) == true
					and (exterieur:GetAttribute("Etat") or E.Pose) == E.Pose and not exterieur:GetAttribute("VolLibre")
				if actif then
					local centre = exterieur:GetPivot().Position
					for _, autre in Players:GetPlayers() do
						if autre ~= joueur then
							local racine = autre.Character and autre.Character:FindFirstChild("HumanoidRootPart")
							if racine and not dansInterieur(racine.Position) then
								local distance = (racine.Position - centre).Magnitude
								if distance <= rayon and not S.proches[autre] then
									S.proches[autre] = true
									alerteSentinelle(string.format("%s s'approche du TARDIS (%d studs).", autre.DisplayName, distance))
								elseif distance > rayon * 1.4 then
									S.proches[autre] = nil
								end
							else
								S.proches[autre] = nil
							end
						end
					end
				else
					table.clear(S.proches)
				end
			end
		end)
		Players.PlayerRemoving:Connect(function(autre) S.proches[autre] = nil end)
	end

	--------------------------------------------------------------------
	-- Animations continues
	--------------------------------------------------------------------
	local prochaineMajLente = 0
	RunService.RenderStepped:Connect(function(dt)
		if not S.ouvert then return end
		local e = lireEtat()
		local t = os.clock()
		local ecoule = workspace:GetServerTimeNow() - (exterieur:GetAttribute("DebutEtat") or 0)
		local enMouvement = e.etat ~= E.Pose
		local vitesse = enMouvement and 3 or 1

		-- Décor : grand cadran des anciens thèmes (caché en Confinement : rien ne tourne), horloge
		if W.cadranFond.Visible and not UI.effetsReduits() then
			W.cadranFond.Rotation += dt * 2 * vitesse
		end
		W.horloge.Text = os.date("%H:%M:%S")

		-- Anneau de statut (il respire avec le moteur : Config.Souffle), et progression sur les grands boutons
		local n = R.SEGMENTS
		local souffle = Config.Souffle(e.etat, ecoule, Config.modeDe(exterieur))
		if not e.alimente then
			for i = 1, n do W.segments[i].BackgroundColor3 = C.gris end
			W.anneauTexte.Text = "—"
			W.anneauSous.Text = "HORS TENSION"
			W.chrono.Text = ""
			UI.progressionBouton(W.demat, 0)
			UI.progressionBouton(W.remat, 0)
		elseif e.etat == E.Demat or e.etat == E.Remat then
			local urgence = e.urgence
			local duree, decalage = Config.Timing(e.etat, Config.modeDe(exterieur))
			local total = duree + decalage
			local p = math.clamp(ecoule / total, 0, 1)
			local couleur = (urgence and C.orange) or (e.express and C.vert) or C.ambre
			local couleurVive = couleur:Lerp(C.blanc, 0.5 * souffle)
			for i = 1, n do
				local allume = (i - 1) / n < p
				W.segments[i].BackgroundColor3 = allume and couleurVive or C.gris
			end
			W.anneauTexte.Text = math.floor(p * 100) .. "%"
			W.anneauSous.Text = e.etat == E.Demat and "DÉCOLLAGE" or "ATTERRISSAGE"
			W.chrono.Text = "T-" .. UI.formatTemps(total - ecoule + 0.99)
			UI.progressionBouton(e.etat == E.Demat and W.demat or W.remat, p, couleur)
			UI.progressionBouton(e.etat == E.Demat and W.remat or W.demat, 0)
		elseif e.etat == E.Vol then
			UI.progressionBouton(W.demat, 1, C.cyan)
			local secondesAuto = Commandes.secondesAutoRemat()
			UI.progressionBouton(W.remat, secondesAuto and (1 - secondesAuto / Commandes.DELAI_AUTO_REMAT) or 0, C.ambre)
			local tete = (t * 22) % n
			for i = 1, n do
				local d = (tete - i) % n
				W.segments[i].BackgroundColor3 = C.gris:Lerp(C.cyan, math.max(0, 1 - d / 16))
			end
			W.anneauTexte.Text = "VOL"
			W.anneauSous.Text = "VORTEX"
			W.chrono.Text = UI.formatTemps(ecoule)
		else
			local couleur = e.alerte and C.rouge or C.vert
			local rythme = e.alerte and 6 or 1.5
			for i = 1, n do
				local intensite = 0.35 + 0.35 * math.sin(t * rythme + i / n * math.pi * 2)
				W.segments[i].BackgroundColor3 = C.gris:Lerp(couleur, intensite)
			end
			W.anneauTexte.Text = e.alerte and "!" or "OK"
			W.anneauSous.Text = e.alerte and "ALERTE" or "POSÉ"
			W.chrono.Text = ""
			UI.progressionBouton(W.demat, 0)
			UI.progressionBouton(W.remat, 0)
		end
		W.anneauTexte.TextColor3 = (not e.alimente and C.gris) or (e.alerte and C.rouge) or C.texte

		-- Flux temporel (barres)
		local amplitude = (not e.alimente and 0.05) or ((e.etat == E.Vol and 0.9) or (enMouvement and 0.7) or 0.28)
		local agitation = (e.urgence or e.alerte) and 3 or 1
		local couleurBarres = (not e.alimente and C.gris) or (e.alerte and C.rouge) or (e.urgence and C.orange) or C.cyan
		for i, barreFlux in W.barres do
			local onde = math.abs(math.sin(t * 2.2 * agitation + i * 0.55) * math.cos(t * 1.3 * agitation + i * 0.27))
			barreFlux.Size = UDim2.new(barreFlux.Size.X.Scale, barreFlux.Size.X.Offset, math.clamp(0.08 + amplitude * onde, 0.05, 1), 0)
			barreFlux.BackgroundColor3 = couleurBarres
		end
		W.stabilite.Text = (not e.alimente and "HORS LIGNE") or (e.alerte and "ALERTE") or (e.urgence and "INSTABLE")
			or (e.etat == E.Vol and "VORTEX") or (enMouvement and "TRANSITION") or "STABLE"
		W.stabilite.TextColor3 = couleurBarres == C.cyan and C.vert or couleurBarres

		-- Grands boutons qui luisent (lueur fixe avec « Réduire les effets ») ; en confirmation de paradoxe, REMAT clignote en rouge
		local lueur = UI.effetsReduits() and 0.35 or (0.2 + 0.5 * (0.5 + 0.5 * math.sin(t * 3)))
		W.demat.Lueur.Transparency = W.demat:GetAttribute("Disponible") and lueur or 0.7
		local arme = Commandes.paradoxeArme()
		if arme ~= S.confirmationAffichee then
			S.confirmationAffichee = arme
			UI.confirmationBouton(W.remat, arme)
			if not arme then task.defer(majFiche) end
		end
		W.remat.Lueur.Transparency = arme and (0.2 + 0.5 * (0.5 + 0.5 * math.sin(t * 8))) or (W.remat:GetAttribute("Disponible") and lueur or 0.7)

		-- Scanner
		if S.modeScanner == "carte" then
			majCarte(e)
		else
			W.balayageRadar.Rotation = (W.balayageRadar.Rotation + dt * 90) % 360
			majScanner(e)
		end

		-- Le reste, 4 fois par seconde
		if t >= prochaineMajLente then
			prochaineMajLente = t + 0.25
			majLente(e)
		end
	end)

	local function majTaille()
		W.echelleHud.Scale = math.clamp(camera.ViewportSize.X / 720, 0.7, 1)
		if S.ouvert then majDisposition() end
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(majTaille)
	majTaille()

	return {}
end
