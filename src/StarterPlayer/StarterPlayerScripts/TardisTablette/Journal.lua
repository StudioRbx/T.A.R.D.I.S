-- StarterPlayerScripts > TardisTablette > Journal (ModuleScript)
-- Journal automatique, statistiques et mises à jour d'accès
-- Extrait du script principal en V6.6.3 : reçoit ce qu'il utilise, renvoie ce que la suite utilise.

return function(contexte)
	local C, Config, E, Players, S, W = contexte.C, contexte.Config, contexte.E, contexte.Players, contexte.S, contexte.W
	local changerMode, choisirFiger, construireListe, def, exterieur, fermer = contexte.changerMode, contexte.choisirFiger, contexte.construireListe, contexte.def, contexte.exterieur, contexte.fermer
	local joueur, journaliser, majFiche, majInterface = contexte.joueur, contexte.journaliser, contexte.majFiche, contexte.majInterface

	--------------------------------------------------------------------
	-- Journal automatique et statistiques
	--------------------------------------------------------------------
	local precedents = {}
	local function surChangement(attribut, rappel)
		precedents[attribut] = exterieur:GetAttribute(attribut)
		exterieur:GetAttributeChangedSignal(attribut):Connect(function()
			local avant, apres = precedents[attribut], exterieur:GetAttribute(attribut)
			precedents[attribut] = apres
			if avant ~= apres then rappel(apres, avant) end
		end)
	end

	surChangement("Etat", function(etat, avant)
		local mode = Config.modeDe(exterieur)
		local position = tostring(exterieur:GetAttribute("Position") or "?")
		if avant == E.Vol and S.debutVol then
			S.tempsVortex += os.clock() - S.debutVol
			S.debutVol = nil
		end
		if etat == E.Demat then
			S.voyages += 1
			journaliser((mode == "Urgence" and "Dématérialisation d'URGENCE.") or (mode ~= "Normal" and ("Dématérialisation " .. Config.libelleMode(mode, true) .. ".")) or "Dématérialisation.", C.ambre)
		elseif etat == E.Vol then
			S.debutVol = os.clock()
			journaliser("Entrée dans le vortex.", C.cyan)
		elseif etat == E.Remat then
			local prefixe = (mode == "Urgence" and "Matérialisation d'URGENCE : ") or (mode == "Catastrophe" and "PARADOXE, matérialisation dans le TARDIS : ")
				or (mode ~= "Normal" and ("Matérialisation " .. Config.libelleMode(mode, true) .. " : ")) or "Matérialisation : "
			journaliser(prefixe .. position, mode == "Catastrophe" and C.rouge or C.ambre)
		elseif etat == E.Pose then
			journaliser("Posé : " .. position, C.vert)
		end
	end)
	surChangement("Camouflage", function(actif) journaliser(actif and "Camouflage activé." or "Camouflage désactivé.", C.cyan) end)
	surChangement("PortesVerrouillees", function(actif) journaliser(actif and "Portes verrouillées." or "Portes déverrouillées.", C.rouge) end)
	surChangement("PorteOuverte", function(actif) journaliser(actif and "Portes ouvertes." or "Portes fermées.", C.texte2) end)
	surChangement("Echelle", function(f) journaliser("Échelle réglée à " .. math.floor((f or 1) * 100 + 0.5) .. " %.", C.ambre) end)
	surChangement("Alimentation", function(actif)
		journaliser(actif == false and "COUPURE D'ALIMENTATION." or "Alimentation rétablie.", actif == false and C.rouge or C.vert)
	end)
	surChangement("Alerte", function(actif) journaliser(actif and "ALERTE GÉNÉRALE." or "Fin de l'alerte.", actif and C.rouge or C.vert) end)
	surChangement("VolLibre", function(id)
		local pilote = id and Players:GetPlayerByUserId(id)
		journaliser(id and ("Vol libre : " .. (pilote and pilote.DisplayName or "quelqu'un") .. " prend les commandes.")
			or "Fin du vol libre.", C.cyan)
	end)
	surChangement("DescenteMode", function(mode)
		if mode == "Chute" then
			journaliser("CHUTE LIBRE ! Rentrée atmosphérique.", C.orange)
		elseif mode == "Douce" then
			journaliser("Descente en douceur.", C.cyan)
		end
	end)
	surChangement("BouclierJoueurs", function(actif)
		journaliser(actif and "Bouclier anti-joueurs levé." or "Bouclier anti-joueurs abaissé.", C.cyan)
	end)
	surChangement("BouclierBalles", function(actif)
		journaliser(actif and "Bouclier anti-balles levé." or "Bouclier anti-balles abaissé.", C.cyan)
	end)
	surChangement("SurEau", function(actif) if actif then journaliser("Amerrissage : le TARDIS flotte.", C.cyan) end end)
	surChangement("VolSaut", function() journaliser("Saut temporel.", C.cyan) end)
	surChangement("DemarrageBloque", function(actif) journaliser(actif and "Démarrage bloqué." or "Démarrage débloqué.", C.orange) end)
	surChangement("Porteur", function(id)
		local porteur = id and Players:GetPlayerByUserId(id)
		journaliser(id and ("Ramassé par " .. (porteur and porteur.DisplayName or "quelqu'un") .. ".") or "Reposé au sol.", C.vert)
	end)

	--------------------------------------------------------------------
	-- Mises à jour automatiques et accès
	--------------------------------------------------------------------
	for _, attribut in { "Etat", "Camouflage", "Position", "PortesVerrouillees", "Retreci", "Porteur", "Mode", "PorteOuverte",
		"Echelle", "Alimentation", "Alerte", "DemarrageBloque", "VolLibre", "SurEau", "BouclierJoueurs", "BouclierBalles", "BouclierComplet", "BouclierEnergie", "PointsDeVie", "Avarie" } do
		exterieur:GetAttributeChangedSignal(attribut):Connect(function()
			if S.ouvert then majInterface() end
		end)
	end
	exterieur:GetAttributeChangedSignal("PrecedentNom"):Connect(construireListe)
	exterieur:GetAttributeChangedSignal("BaseNom"):Connect(construireListe) -- (V6.9.11) point de base
	exterieur:GetAttributeChangedSignal("Historique"):Connect(function() if S.mode == "histo" then construireListe() end end)
	local function lireCategories()
		table.clear(S.categories)
		for ligne in string.gmatch(exterieur:GetAttribute("Categories") or "", "[^\n]+") do
			local nom, index = string.match(ligne, "^(.-)\t(%d+)$")
			if nom then S.categories[nom] = tonumber(index) end
		end
		construireListe()
		majFiche()
	end
	exterieur:GetAttributeChangedSignal("Categories"):Connect(lireCategories)
	lireCategories()
	exterieur:GetAttributeChangedSignal("ListeDestinations"):Connect(construireListe)
	Players.PlayerAdded:Connect(construireListe)
	Players.PlayerRemoving:Connect(function() task.defer(construireListe) end)

	local function majAcces()
		local pilote = joueur:GetAttribute("TardisPilote_" .. def.Nom) == true
		W.gui.Enabled = pilote
		if not pilote then fermer() end
	end
	joueur:GetAttributeChangedSignal("TardisPilote_" .. def.Nom):Connect(majAcces)
	majAcces()
	joueur:SetAttribute("TardisTablette", false)
	changerMode("lieux")
	choisirFiger(false)
	journaliser("Tablette initialisée.", C.texte2)

	return {}
end
