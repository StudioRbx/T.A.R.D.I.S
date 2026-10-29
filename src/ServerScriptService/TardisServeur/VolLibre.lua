-- ServerScriptService > TardisServeur > VolLibre (ModuleScript)
-- Vol libre (piloté depuis la tablette)
-- Extrait du script principal en V6.6.3 : reçoit ce qu'il utilise, renvoie ce que la suite utilise.

return function(contexte)
	local Config, E, Players, chercherSol, dansInterieur, echelleNormale = contexte.Config, contexte.E, contexte.Players, contexte.chercherSol, contexte.dansInterieur, contexte.echelleNormale
	local emmenerALInterieur, etatActuel, exterieur, fermerPortes, hauteurNormale, interieur = contexte.emmenerALInterieur, contexte.etatActuel, contexte.exterieur, contexte.fermerPortes, contexte.hauteurNormale, contexte.interieur
	local jouer, majEcran, majRamassage, memoriserDepart, partage, setCollisionsExterieur = contexte.jouer, contexte.majEcran, contexte.majRamassage, contexte.memoriserDepart, contexte.partage, contexte.setCollisionsExterieur
	local tropPetitPourLesPortes, verifierEau = contexte.tropPetitPourLesPortes, contexte.verifierEau

	--------------------------------------------------------------------
	-- Vol libre (piloté depuis la tablette)
	-- Le pilote envoie la position du TARDIS ~15 fois par seconde ; le serveur la vérifie et la publie
	-- dans l'attribut VolLibreCF, que tous les clients suivent. Les vraies pièces ne bougent qu'à l'atterrissage.
	--------------------------------------------------------------------
	local reglagesVol = Config.VolLibre or {}
	local volLibre = { dernierCF = nil, dernierTemps = 0, enDescente = false }
	local ATTRIBUTS_DESCENTE = { "DescenteMode", "DescenteDepart", "DescenteArrivee", "DescenteDebut", "DescenteDuree" }

	-- Portes en plein vol : les passagers voient le paysage défiler et peuvent sauter.
	-- Pendant le vol, les portes restent bloquées (Verrouille) : on ne les débloque que le temps de les ouvrir.
	local function fermerPortesEnVol()
		if exterieur:GetAttribute("PorteOuverte") then
			exterieur:SetAttribute("FermerPortes", true)
			task.delay(1, function() exterieur:SetAttribute("FermerPortes", false) end)
		end
	end

	local function basculerPortesEnVol()
		if exterieur:GetAttribute("PorteOuverte") then
			fermerPortesEnVol()
			return
		end
		if exterieur:GetAttribute("PortesVerrouillees") or tropPetitPourLesPortes() then return end
		if exterieur:GetAttribute("VolPhase") ~= "Visible" then return end
		exterieur:SetAttribute("Verrouille", false)
		exterieur:SetAttribute("OuvrirPorte", false)
		task.wait()
		exterieur:SetAttribute("OuvrirPorte", true)
		task.delay(1, function()
			exterieur:SetAttribute("OuvrirPorte", false)
			if exterieur:GetAttribute("VolLibre") then
				exterieur:SetAttribute("Verrouille", true) -- refermables, mais pas rouvrables par quelqu'un d'autre
			end
		end)
	end

	-- Démat / remat EN VOL : le TARDIS devient invisible (ou réapparaît) sans arrêter le vol libre.
	-- Phases : "Visible" -> "Demat" -> "Invisible" -> "Remat" -> "Visible" (animées chez les clients)
	local function phaseVol(phase, urgence)
		exterieur:SetAttribute("VolPhaseUrgence", urgence == true)
		exterieur:SetAttribute("VolPhaseDebut", workspace:GetServerTimeNow())
		exterieur:SetAttribute("VolPhase", phase) -- en dernier : déclenche l'animation chez les clients
	end

	local function changerPhaseVol(depuis, transition, arrivee, etatAnimation, son)
		if exterieur:GetAttribute("VolPhase") ~= depuis or volLibre.enDescente then return end
		if transition == "Demat" then fermerPortesEnVol() end
		local urgence = exterieur:GetAttribute("VolUrgence") == true
		phaseVol(transition, urgence)
		-- Le son de la salle de contrôle est joué ici ; celui de dehors est joué par les clients, sur le TARDIS qui bouge
		jouer(urgence and (son .. "_Urg") or son, false)
		local duree, decalage = Config.Timing(etatAnimation, urgence)
		local jeton = {}
		volLibre.jetonPhase = jeton
		task.delay(duree + decalage, function()
			if volLibre.jetonPhase == jeton and exterieur:GetAttribute("VolPhase") == transition then
				phaseVol(arrivee, urgence)
			end
		end)
	end

	local function demarrerVolLibre(pilote)
		if exterieur:GetAttribute("VolLibre") then return false, "DÉJÀ EN VOL LIBRE" end
		if partage.occupe then return false, "TARDIS OCCUPÉ" end
		if etatActuel() ~= E.Pose then return false, "PAS POSÉ" end
		if exterieur:GetAttribute("Porteur") then return false, "TARDIS PORTÉ" end
		if exterieur:GetAttribute("Alimentation") == false then return false, "HORS TENSION" end
		if exterieur:GetAttribute("DemarrageBloque") then return false, "DÉMARRAGE BLOQUÉ" end

		partage.occupe = true -- rien d'autre ne peut être fait pendant le vol libre
		majRamassage()
		exterieur:SetAttribute("Verrouille", true)
		if not fermerPortes() then
			exterieur:SetAttribute("Verrouille", tropPetitPourLesPortes())
			partage.occupe = false
			majRamassage()
			return false, "PORTES BLOQUÉES"
		end

		setCollisionsExterieur(false)
		exterieur:SetAttribute("VolVortex", false)
		exterieur:SetAttribute("VolUrgence", false)
		phaseVol("Visible", false)
		volLibre.dernierCF = exterieur:GetPivot()
		volLibre.dernierTemps = os.clock()
		volLibre.enDescente = false
		memoriserDepart()
		exterieur:SetAttribute("SurEau", false)
		volLibre.bonusDistance = 0
		exterieur:SetAttribute("VolLibreCF", volLibre.dernierCF)
		exterieur:SetAttribute("VolLibre", pilote.UserId)
		exterieur:SetAttribute("Position", "Vol libre")
		partage.positionActuelle = nil
		majEcran()
		return true
	end

	-- Position envoyée par le pilote : vérifiée (format, zone, vitesse) avant d'être publiée
	local function recevoirPositionVol(pilote, cf)
		if exterieur:GetAttribute("VolLibre") ~= pilote.UserId or volLibre.enDescente then return end
		if typeof(cf) ~= "CFrame" then return end
		local p = cf.Position
		if p.X ~= p.X or p.Y ~= p.Y or p.Z ~= p.Z then return end -- NaN
		if math.abs(p.X) > 100000 or math.abs(p.Y) > 100000 or math.abs(p.Z) > 100000 then return end
		if dansInterieur(p) then return end

		-- Vitesse maximale : si la position saute trop loin, on la ramène à la distance autorisée
		local maintenant = os.clock()
		local dt = math.clamp(maintenant - volLibre.dernierTemps, 0.03, 1)
		local vitesseMax = 0
		for _, v in reglagesVol.Niveaux or { reglagesVol.Vitesse or 40 } do
			vitesseMax = math.max(vitesseMax, v)
		end
		local maxDistance = (vitesseMax * 1.4 + 10) * dt + 2 + (volLibre.bonusDistance or 0)
		local ancien = volLibre.dernierCF.Position
		local ecart = p - ancien
		if ecart.Magnitude > maxDistance then
			p = ancien + ecart.Unit * maxDistance
		end
		volLibre.dernierCF = (CFrame.new(p) * cf.Rotation):Orthonormalize()
		volLibre.dernierTemps = maintenant
		volLibre.bonusDistance = 0 -- le bond du saut temporel ne sert qu'une fois
		exterieur:SetAttribute("VolLibreCF", volLibre.dernierCF)
	end

	-- Vol de précision : le TARDIS rapetisse (30 %) le temps du mode, puis reprend sa taille
	local function echellerEnVol(facteur)
		if not hauteurNormale then return end
		facteur = math.clamp(facteur, Config.TailleMin or 0.25, 1)
		exterieur:ScaleTo(echelleNormale * facteur)
		exterieur:SetAttribute("Echelle", facteur)
		exterieur:SetAttribute("Retreci", facteur < 0.999)
	end

	local function finirVolLibre(arrivee)
		exterieur:SetAttribute("VolPrecision", false)
		exterieur:SetAttribute("Tempete", nil)
		exterieur:PivotTo(arrivee)
		exterieur:SetAttribute("DepotCF", arrivee) -- les clients s'y recalent en arrêtant de suivre le vol
		emmenerALInterieur()                      -- les joueurs sous le TARDIS se retrouvent à bord
		setCollisionsExterieur(true)
		exterieur:SetAttribute("VolLibre", nil)
		exterieur:SetAttribute("VolLibreCF", nil)
		exterieur:SetAttribute("VolVortex", false)
		exterieur:SetAttribute("VolUrgence", false)
		volLibre.jetonPhase = nil
		exterieur:SetAttribute("VolPhase", nil) -- de nouveau visible normalement
		for _, nom in ATTRIBUTS_DESCENTE do
			exterieur:SetAttribute(nom, nil)
		end
		exterieur:SetAttribute("DescenteVitesse", nil)
		exterieur:SetAttribute("DescenteGravite", nil)
		exterieur:SetAttribute("DescenteRebond", nil)
		exterieur:SetAttribute("DescenteGlisse", nil)
		exterieur:SetAttribute("Verrouille", tropPetitPourLesPortes())
		local p = arrivee.Position
		exterieur:SetAttribute("Position", string.format("Vol libre (%d, %d, %d)", p.X, p.Y, p.Z))
		verifierEau()
		partage.sauvegardeModifiee = true
		volLibre.enDescente = false
		partage.occupe = false
		majRamassage()
		majEcran()
	end

	-- mode "Chute" : chute libre à la verticale (effet de rentrée atmosphérique côté clients)
	-- mode "Douce" : descente posée jusqu'au sol
	-- Chute avec élan : on suit la trajectoire (vitesse initiale + gravité) jusqu'au premier obstacle
	local function trajectoireChute(depart, vitesse, gravite)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local exclus = { exterieur, interieur }
		for _, autre in Players:GetPlayers() do
			if autre.Character then table.insert(exclus, autre.Character) end
		end
		params.FilterDescendantsInstances = exclus
		params.RespectCanCollide = true
		local pas = 0.05
		local position = depart.Position
		for i = 1, 200 do -- 10 s maximum
			local temps = i * pas
			local suivante = depart.Position + vitesse * temps + Vector3.new(0, -0.5 * gravite * temps * temps, 0)
			local resultat = workspace:Raycast(position, suivante - position, params)
			if resultat then
				return resultat.Position, temps, resultat.Normal
			end
			position = suivante
		end
		return nil
	end

	local function lancerDescente(mode, force, vitesseInitiale)
		if not exterieur:GetAttribute("VolLibre") or volLibre.enDescente then return false end
		-- Il faut être matérialisé pour se poser (sauf si le pilote part : on le pose quand même)
		if not force and exterieur:GetAttribute("VolPhase") ~= "Visible" then return false end
		volLibre.enDescente = true
		fermerPortesEnVol() -- on referme avant de se poser

		local depart = volLibre.dernierCF
		-- En urgence, la chute garde l'élan du vol : trajectoire balistique au lieu de la verticale
		if mode == "Chute" and exterieur:GetAttribute("VolUrgence") and typeof(vitesseInitiale) == "Vector3" and vitesseInitiale.Magnitude > 10 then
			local vitesseMax = (reglagesVol.VitesseUrgence or 220) * 1.2
			if vitesseInitiale.Magnitude > vitesseMax then vitesseInitiale = vitesseInitiale.Unit * vitesseMax end
			local gravite = reglagesVol.GraviteChute or 70
			local impact, duree = trajectoireChute(depart, vitesseInitiale, gravite)
			if impact then
				local devant = vitesseInitiale * Vector3.new(1, 0, 1)
				devant = devant.Magnitude > 0.01 and devant.Unit or Vector3.new(0, 0, -1)
				local arrivee = CFrame.lookAt(impact + Vector3.new(0, exterieur.PrimaryPart.Size.Y / 2, 0), impact + devant + Vector3.new(0, exterieur.PrimaryPart.Size.Y / 2, 0))
				exterieur:SetAttribute("DescenteMode", "Chute")
				exterieur:SetAttribute("DescenteDepart", depart)
				exterieur:SetAttribute("DescenteArrivee", arrivee)
				exterieur:SetAttribute("DescenteVitesse", vitesseInitiale) -- les clients animent la parabole
				exterieur:SetAttribute("DescenteGravite", gravite)
				exterieur:SetAttribute("DescenteDuree", duree)
				exterieur:SetAttribute("DescenteDebut", workspace:GetServerTimeNow())
				task.delay(duree, function() finirVolLibre(arrivee) end)
				return true
			end
		end
		exterieur:SetAttribute("DescenteVitesse", nil)
		exterieur:SetAttribute("DescenteGravite", nil)
		exterieur:SetAttribute("DescenteRebond", nil)
		exterieur:SetAttribute("DescenteGlisse", nil)
		local devant = depart.LookVector * Vector3.new(1, 0, 1)
		devant = devant.Magnitude > 0.01 and devant.Unit or Vector3.new(0, 0, -1)
		-- Le point d'impact est calculé par le serveur, à la verticale du TARDIS
		local sol = chercherSol(depart.Position + Vector3.new(0, 2, 0), 3000)
		local arrivee = sol and CFrame.lookAt(sol, sol + devant) or CFrame.lookAt(depart.Position, depart.Position + devant)

		local hauteur = math.max(depart.Position.Y - arrivee.Position.Y, 0)
		local duree
		if mode == "Chute" then
			duree = math.clamp(math.sqrt(2 * hauteur / (reglagesVol.GraviteChute or 70)), 0.8, 5)
		else
			duree = math.clamp(hauteur / (reglagesVol.VitesseDescente or 14), 0.8, 5)
		end

		-- Rebond : une chute très rapide fait rebondir le TARDIS une fois (0,9 s de plus)
		if mode == "Chute" and math.sqrt(2 * (reglagesVol.GraviteChute or 70) * hauteur) > 60 then
			exterieur:SetAttribute("DescenteRebond", math.clamp(hauteur * 0.08, 3, 10))
			duree += 0.9
		end
		exterieur:SetAttribute("DescenteMode", mode)
		exterieur:SetAttribute("DescenteDepart", depart)
		exterieur:SetAttribute("DescenteArrivee", arrivee)
		exterieur:SetAttribute("DescenteDuree", duree)
		exterieur:SetAttribute("DescenteDebut", workspace:GetServerTimeNow()) -- en dernier : lance l'animation chez les clients
		task.delay(duree, function()
			finirVolLibre(arrivee)
		end)
		return true
	end

	-- Atterrissage glissé (urgence, "Atterrir ici") : descente rapide puis glissade de quelques mètres avec étincelles
	local function lancerGlisse(vitesse)
		if not exterieur:GetAttribute("VolLibre") or volLibre.enDescente then return false end
		if exterieur:GetAttribute("VolPhase") ~= "Visible" then return false end
		volLibre.enDescente = true
		fermerPortesEnVol()
		local depart = volLibre.dernierCF
		local horizontale = typeof(vitesse) == "Vector3" and vitesse * Vector3.new(1, 0, 1) or Vector3.zero
		local direction = horizontale.Magnitude > 1 and horizontale.Unit or depart.LookVector * Vector3.new(1, 0, 1)
		if direction.Magnitude < 0.01 then direction = Vector3.new(0, 0, -1) end
		direction = direction.Unit
		local sol1 = chercherSol(depart.Position + Vector3.new(0, 2, 0), 3000)
		if not sol1 then
			volLibre.enDescente = false
			return lancerDescente("Douce")
		end
		local longueur = math.clamp(horizontale.Magnitude * 0.25, 8, 25)
		local sol2 = chercherSol(sol1 + direction * longueur + Vector3.new(0, 4, 0), 30) or (sol1 + direction * longueur)
		local toucher = CFrame.lookAt(sol1, sol1 + direction)
		local arrivee = CFrame.lookAt(sol2, sol2 + direction)
		local hauteur = math.max(depart.Position.Y - sol1.Y, 0)
		local dureeDescente = math.clamp(hauteur / 40, 0.5, 2.5)
		local dureeGlisse = math.clamp(longueur / 12, 0.8, 2.2)
		exterieur:SetAttribute("DescenteMode", "Glisse")
		exterieur:SetAttribute("DescenteDepart", depart)
		exterieur:SetAttribute("DescenteGlisse", toucher)      -- point où il touche le sol
		exterieur:SetAttribute("DescenteGlisseDuree", dureeDescente)
		exterieur:SetAttribute("DescenteArrivee", arrivee)     -- fin de la glissade
		exterieur:SetAttribute("DescenteDuree", dureeDescente + dureeGlisse)
		exterieur:SetAttribute("DescenteDebut", workspace:GetServerTimeNow())
		task.delay(dureeDescente + dureeGlisse, function() finirVolLibre(arrivee) end)
		return true
	end

	-- "Atterrir ici" quand le chemin est bloqué : le TARDIS, déjà dématérialisé en vol, se rematérialise au point visé
	local function teleAtterrir(position)
		if not exterieur:GetAttribute("VolLibre") or volLibre.enDescente then return false end
		if exterieur:GetAttribute("VolPhase") ~= "Invisible" then return false end
		if typeof(position) ~= "Vector3" or dansInterieur(position) then return false end
		local sol = chercherSol(position + Vector3.new(0, 20, 0), 3000)
		if not sol then return false end
		local devant = volLibre.dernierCF.LookVector * Vector3.new(1, 0, 1)
		devant = devant.Magnitude > 0.01 and devant.Unit or Vector3.new(0, 0, -1)
		local cible = CFrame.lookAt(sol, sol + devant)
		volLibre.dernierCF = cible
		exterieur:SetAttribute("VolLibreCF", cible) -- tout le monde se recale, invisible
		task.wait(0.2)
		changerPhaseVol("Invisible", "Remat", "Visible", E.Remat, "Remat")
		volLibre.enDescente = true
		local duree, decalage = Config.Timing(E.Remat, exterieur:GetAttribute("VolUrgence") == true)
		task.delay(duree + decalage + 0.1, function() finirVolLibre(cible) end)
		return true
	end

	return { basculerPortesEnVol = basculerPortesEnVol, changerPhaseVol = changerPhaseVol, demarrerVolLibre = demarrerVolLibre, lancerDescente = lancerDescente, lancerGlisse = lancerGlisse, recevoirPositionVol = recevoirPositionVol, reglagesVol = reglagesVol, teleAtterrir = teleAtterrir, volLibre = volLibre }
end
