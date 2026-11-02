-- StarterPlayerScripts > TardisTablette > Etat (ModuleScript)
-- Journal, notifications et lecture de l'état du TARDIS
-- Extrait du script principal en V6.6.3 : reçoit ce qu'il utilise, renvoie ce que la suite utilise.

return function(contexte)
	local C, Commandes, Config, E, Players, R = contexte.C, contexte.Commandes, contexte.Config, contexte.E, contexte.Players, contexte.R
	local S, UI, W, animer, creer, exterieur = contexte.S, contexte.UI, contexte.W, contexte.animer, contexte.creer, contexte.exterieur
	local joueur, seuilPortes, texte = contexte.joueur, contexte.seuilPortes, contexte.texte

	--------------------------------------------------------------------
	-- Journal et notifications
	--------------------------------------------------------------------
	S.journalEntrees = {}
	local function journaliser(message, couleur)
		S.compteurJournal += 1
		table.insert(S.journalEntrees, 1, { heure = os.date("%H:%M:%S"), message = message })
		while #S.journalEntrees > 200 do table.remove(S.journalEntrees) end
		W.journalVide.Visible = false
		local ligne = creer("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
			LayoutOrder = -S.compteurJournal, Parent = W.journal })
		creer("Frame", { Position = UDim2.fromOffset(0, 4), Size = UDim2.fromOffset(3, 10), BackgroundColor3 = couleur or C.texte2,
			BorderSizePixel = 0, Parent = ligne }, { UI.coin(99) })
		texte({ Text = os.date("%H:%M:%S"), Font = UI.POLICE_CODE, TextSize = 10, TextColor3 = C.texte2,
			Position = UDim2.fromOffset(8, 0), Size = UDim2.fromOffset(54, 16), Parent = ligne })
		texte({ Text = message, TextSize = 11, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y,
			Position = UDim2.fromOffset(64, 0), Size = UDim2.new(1, -66, 0, 16), Parent = ligne })
		table.insert(S.lignesJournal, 1, ligne)
		while #S.lignesJournal > R.MAX_JOURNAL do
			table.remove(S.lignesJournal):Destroy()
		end
	end

	W.effacer.Activated:Connect(function()
		for _, ligne in S.lignesJournal do ligne:Destroy() end
		table.clear(S.lignesJournal)
		W.journalVide.Visible = true
	end)

	local jeton = 0
	local function notifier(message, reussi)
		if typeof(message) ~= "string" or string.sub(message, 1, 2) == "__" then return end
		local couleur = reussi and C.vert or C.rouge
		journaliser(message, couleur)
		if not S.ouvert then return end
		jeton += 1
		local moi = jeton
		W.contourNotif.Color = couleur
		W.notifTexte.TextColor3 = UI.eclaircir(couleur, 0.4)
		W.notifTexte.Text = (reussi and "●  " or "×  ") .. message
		UI.son(reussi and "Notification" or "Alerte")
		W.notification.Visible = true
		W.notification.Position = UDim2.new(0.5, 0, 0, -80)
		animer(W.notification, 0.4, { Position = UDim2.new(0.5, 0, 0, 66) }, Enum.EasingStyle.Back)
		task.delay(4, function()
			if moi ~= jeton then return end
			animer(W.notification, 0.3, { Position = UDim2.new(0.5, 0, 0, -80) }).Completed:Wait()
			if moi == jeton then W.notification.Visible = false end
		end)
	end

	--------------------------------------------------------------------
	-- Lecture de l'état du TARDIS
	--------------------------------------------------------------------
	local function lireEtat()
		local etat = exterieur:GetAttribute("Etat") or E.Pose
		local idPorteur = exterieur:GetAttribute("Porteur")
		return {
			etat = etat,
			pose = etat == E.Pose,
			camoufle = exterieur:GetAttribute("Camouflage") == true,
			echelle = exterieur:GetAttribute("Echelle") or 1,
			porteur = idPorteur and Players:GetPlayerByUserId(idPorteur),
			porte = idPorteur ~= nil,
			verrouille = exterieur:GetAttribute("PortesVerrouillees") == true,
			urgence = Config.modeDe(exterieur) == "Urgence" and etat ~= E.Pose,
			express = Config.modeDe(exterieur) == "Express" and etat ~= E.Pose,
			sauvetage = Config.modeDe(exterieur) == "Sauvetage" and etat ~= E.Pose,
			catastrophe = Config.modeDe(exterieur) == "Catastrophe" and etat ~= E.Pose,
			silencieux = Config.modeDe(exterieur) == "Silencieux" and etat ~= E.Pose,
			siege = exterieur:GetAttribute("Siege") == true,
			mode = Config.modeDe(exterieur),
			alimente = exterieur:GetAttribute("Alimentation") ~= false,
			alerte = exterieur:GetAttribute("Alerte") == true,
			bloque = exterieur:GetAttribute("DemarrageBloque") == true,
			porteOuverte = exterieur:GetAttribute("PorteOuverte") == true,
			volLibre = exterieur:GetAttribute("VolLibre") ~= nil,
			surEau = exterieur:GetAttribute("SurEau") == true,
		}
	end

	local function cleDe(c)
		if not c then return nil end
		if c.type == "lieu" then return "lieu:" .. c.nom end
		if c.type == "joueur" then return "joueur:" .. c.id end
		if c.type == "precedent" then return "precedent" end
		if c.type == "historique" then return "histo:" .. tostring(c.index) end
		return "position"
	end

	-- Distance (studs) entre le TARDIS et la destination choisie, si on peut la connaître
	local function distanceDe(c)
		if not c then return nil end
		local origine = exterieur:GetPivot().Position
		if c.type == "lieu" then
			local dossier = Config.dossierDestinations(false)
			local part = dossier and dossier:FindFirstChild(c.nom)
			return part and part:IsA("BasePart") and (part.Position - origine).Magnitude or nil
		elseif c.type == "joueur" then
			local autre = Players:GetPlayerByUserId(c.id)
			local racine = autre and autre.Character and autre.Character:FindFirstChild("HumanoidRootPart")
			return racine and (racine.Position - origine).Magnitude or nil
		elseif c.type == "historique" and c.cframe then
			return (c.cframe.Position - origine).Magnitude
		elseif c.type == "position" and S.positionPerso then
			return (S.positionPerso.cframe.Position - origine).Magnitude
		end
		return nil
	end

	local function majTuile(t, actif, texteEtat, couleur, disponible)
		UI.setDisponible(t.bouton, disponible, C.fond)
		animer(t.lampe, 0.2, { BackgroundColor3 = actif and couleur or C.gris })
		t.etat.Text = texteEtat
		t.etat.TextColor3 = actif and couleur or C.texte2
	end

	local function majVoyant(v, texteValeur, couleur)
		animer(v.lampe, 0.25, { BackgroundColor3 = couleur })
		v.valeur.Text = texteValeur
		v.valeur.TextColor3 = couleur
	end

	local function majFiche()
		local c = S.choix
		W.modeJoueur.Visible = c ~= nil and c.type == "joueur"
		W.boutonCategorie.Visible = c ~= nil and c.type == "lieu"
		if c and c.type == "lieu" then
			local categorie = S.categories[c.nom] and (Config.Categories or {})[S.categories[c.nom]]
			W.boutonCategorie.Text = categorie and ("● " .. categorie.nom) or "Catégorie : aucune"
			W.boutonCategorie.TextColor3 = categorie and categorie.couleur or C.texte2
		end
		if not c then
			W.ficheIcone.Text = "?"
			W.ficheNom.Text = "Aucune destination"
			W.ficheInfo.Text = "Choisis un lieu, un joueur ou des coordonnées."
			return
		end
		local distance = distanceDe(c)
		-- Temps de trajet : démat + vortex automatique + remat, selon le protocole choisi
		local modeVoyage = Commandes.mode()
		local dDemat, cDemat = Config.Timing(E.Demat, modeVoyage)
		local dRemat, cRemat = Config.Timing(E.Remat, modeVoyage)
		local trajet = string.format("trajet ~%d s", dDemat + cDemat + dRemat + cRemat + (Config.DureeVortexAuto or 10))
			.. (modeVoyage ~= "Normal" and ("  ·  " .. Config.libelleMode(modeVoyage, true)) or "")
		local texteDistance = (distance and string.format("%d studs", distance) or "distance inconnue") .. "  ·  " .. trajet
		if c.type == "lieu" then
			W.ficheIcone.Text = "◆"
			W.ficheNom.Text = c.nom
			W.ficheInfo.Text = "LIEU  ·  " .. texteDistance
		elseif c.type == "precedent" then
			W.ficheIcone.Text = "◄"
			W.ficheNom.Text = "Retour : " .. c.nom
			W.ficheInfo.Text = "DERNIÈRE DESTINATION  ·  là d'où le TARDIS est parti  ·  " .. trajet
		elseif c.type == "historique" then
			W.ficheIcone.Text = "►"
			W.ficheNom.Text = c.nom
			W.ficheInfo.Text = "HISTORIQUE  ·  " .. texteDistance
		elseif c.type == "joueur" then
			W.ficheIcone.Text = "●"
			W.ficheNom.Text = c.nom
			W.ficheInfo.Text = (S.figer and "JOUEUR · SUR LUI (FIGÉ)" or "JOUEUR · DERNIÈRE POSITION") .. "  ·  " .. texteDistance
		else
			W.ficheIcone.Text = "○"
			W.ficheNom.Text = "Nouvelle localisation"
			W.ficheInfo.Text = (S.positionPerso and S.positionPerso.collision and "COLLISION » URGENCE" or "COORDONNÉES")
				.. "  ·  " .. texteDistance
		end
	end

	local function majInterface()
		local e = lireEtat()
		local libelle = UI.LIBELLES[e.etat] or { "?", C.texte2, "?" }
		local couleurEtat, nomEtat, nomCourt = libelle[2], libelle[1], libelle[3]
		if not e.alimente then
			couleurEtat, nomEtat, nomCourt = C.gris, "HORS TENSION", "Hors tension"
		elseif e.volLibre then
			couleurEtat, nomEtat, nomCourt = C.cyan, "VOL LIBRE", "Vol libre"
		elseif e.alerte then
			couleurEtat = C.rouge
		end

		-- Barre du haut
		W.textePastille.Text = (e.alerte and "Alerte · " or "") .. nomCourt
		W.lieuPastille.Text = "·  " .. tostring(exterieur:GetAttribute("Position") or "?")
		animer(W.pointPastille, 0.3, { BackgroundColor3 = couleurEtat })
		W.contourPastille.Color = couleurEtat

		-- Statut
		W.etatGrand.Text = nomEtat
		W.etatGrand.TextColor3 = couleurEtat
		W.badges.camouflage.Visible = e.camoufle
		W.badges.verrou.Visible = e.verrouille
		W.badges.petit.Visible = e.echelle < 0.999
		W.badges.porte.Visible = e.porte
		W.badges.urgence.Visible = e.urgence
		W.badges.express.Visible = e.express
		W.badges.sauvetage.Visible = e.sauvetage
		W.badges.catastrophe.Visible = e.catastrophe
		W.badges.silencieux.Visible = e.silencieux
		W.badges.siege.Visible = e.siege
		W.badges.horsTension.Visible = not e.alimente
		W.badges.alerte.Visible = e.alerte
		W.badges.bloque.Visible = e.bloque
		W.badges.eau.Visible = e.surEau

		-- Actions principales
		local petit = e.echelle < 0.999
		local poche = exterieur:GetAttribute("Porteur") == joueur.UserId -- je porte le TARDIS : téléportation de poche
		local dematOk = e.pose and not e.porte and e.alimente and not e.bloque and not e.volLibre
		if poche then dematOk = S.choix ~= nil and e.alimente and not e.bloque end
		local rematOk = e.etat == E.Vol and (S.choix ~= nil or petit) and e.alimente
		W.demat.SousTitre.Text = poche and (S.choix and "Téléportation de poche" or "Choisis une destination") or "Décoller"
		UI.setDisponible(W.demat, dematOk, C.bleu)
		UI.setDisponible(W.remat, rematOk, C.bleu)
		if Commandes.secondesAutoRemat() and e.etat == E.Vol then
			W.remat.SousTitre.Text = string.format("Auto dans %d s", math.ceil(Commandes.secondesAutoRemat()))
		else
			W.remat.SousTitre.Text = petit and "Sur place (réduit)" or (e.etat == E.Vol and not S.choix and "Choisis une destination" or "Atterrir")
		end
		W.demat.Lueur.Color = dematOk and C.ambre or C.gris
		W.remat.Lueur.Color = rematOk and C.ambre or C.gris
		-- Paradoxe : le bouton MATÉRIALISER demande une confirmation (rouge)
		UI.confirmationBouton(W.remat, Commandes.paradoxeArme())

		-- Systèmes
		majTuile(W.tuiles.camouflage, e.camoufle, e.camoufle and "ACTIVÉ" or "Inactif", C.cyan, e.pose and e.alimente)
		majTuile(W.tuiles.verrou, e.verrouille, e.verrouille and "VERROUILLÉ" or "Ouvert", C.rouge, true)
		local portesPossibles = e.pose and (e.porteOuverte or (not e.verrouille and e.echelle >= seuilPortes - 0.001))
		majTuile(W.tuiles.portes, e.porteOuverte, e.porteOuverte and "Ouvertes · fermer" or "Fermées · ouvrir", C.vert,
			portesPossibles and not e.volLibre)
		majTuile(W.tuiles.volLibre, e.volLibre, e.volLibre and "EN VOL" or "Piloter", C.cyan,
			e.pose and not e.porte and e.alimente and not e.bloque and not e.volLibre)
		majVoyant(W.voyants.energie, e.alimente and "NOMINALE" or "COUPÉE", e.alimente and C.vert or C.rouge)
		majVoyant(W.voyants.alerte, e.alerte and "ACTIVE" or "Aucune", e.alerte and C.rouge or C.texte2)
		majVoyant(W.voyants.demarrage, e.bloque and "BLOQUÉ" or "Libre", e.bloque and C.orange or C.vert)

		-- Boucliers : allumés quand actifs, grisés quand impossibles (pas posé, porté, hors tension)
		local boucliersPossibles = e.pose and not e.porte and e.alimente and not e.volLibre
		local unActif = false
		for type, bouton in W.boutonsBouclier do
			local actif = exterieur:GetAttribute("Bouclier" .. type) == true
			unActif = unActif or actif
			UI.colorer(bouton, actif and Color3.fromRGB(60, 120, 170) or C.panneau)
			bouton.Text = (actif and "●  " or "○  ") .. ({ Joueurs = "Anti-joueurs", Balles = "Anti-balles", Complet = "Complet (joueurs + tirs)" })[type]
		end
		UI.setDisponible(W.boutonBoucliers, unActif or boucliersPossibles, unActif and Color3.fromRGB(60, 120, 170) or C.fond)
		W.boutonBoucliers.TextColor3 = unActif and C.texte or C.texte2
		W.boutonBoucliers.Text = unActif and "●  BOUCLIERS  ●" or "●  BOUCLIERS"
		local energie = exterieur:GetAttribute("BouclierEnergie") or 100
		W.energieBouclier.Size = UDim2.fromScale(math.clamp(energie / 100, 0, 1), 1)
		W.energieBouclier.BackgroundColor3 = energie <= 15 and C.rouge or C.cyan -- sous 15 % : dans le rouge
		W.energieTexte.Text = unActif and string.format("%d %%", energie) or "—"
		W.energieTexte.TextColor3 = (unActif and energie <= 15) and C.rouge or (unActif and C.cyan or C.texte2)
		-- Intégrité (points de vie) : voyant "Énergie" étendu
		local integrite = exterieur:GetAttribute("PointsDeVie")
		if integrite then
			local couleurIntegrite = (integrite <= 20 and C.rouge) or (integrite <= 50 and C.ambre) or C.vert
			W.jaugeIntegrite.barre.Size = UDim2.fromScale(integrite / 100, 1)
			W.jaugeIntegrite.barre.BackgroundColor3 = couleurIntegrite
			W.jaugeIntegrite.valeur.Text = string.format("%d %%", integrite)
			W.jaugeIntegrite.valeur.TextColor3 = couleurIntegrite
		end

		-- Taille
		local tailleDispo = e.pose and not e.porte and e.alimente
		if not S.glisseTaille then S.tailleChoisie = e.echelle end
		W.pisteTaille:SetAttribute("Disponible", tailleDispo)
		W.remplissageTaille.BackgroundColor3 = tailleDispo and C.ambre or C.gris
		W.aideTaille.Text = (not e.alimente and "Hors tension.") or (e.porte and "Il doit d'abord être posé.")
			or (not e.pose and "Disponible quand il est posé.")
			or ("Trait bleu : seuil des portes (" .. math.floor(seuilPortes * 100 + 0.5) .. " %)")

		-- Énergie (en haut à droite)
		for i, barreEnergie in W.jauge do
			barreEnergie.BackgroundColor3 = (not e.alimente) and C.gris or (e.alerte and C.rouge or C.vert)
			barreEnergie.BackgroundTransparency = (not e.alimente and i > 1) and 0.7 or 0
		end

		-- Sélection dans la liste + fiche
		local cleChoisie = cleDe(S.choix)
		for cle, element in S.boutonsChoix do
			local choisi = cle == cleChoisie
			UI.colorer(element.bouton, choisi and C.panneauClair or C.panneau)
			element.bouton.Barre.Visible = choisi
		end
		majFiche()
	end

	return { cleDe = cleDe, distanceDe = distanceDe, journaliser = journaliser, lireEtat = lireEtat, majFiche = majFiche, majInterface = majInterface, majTuile = majTuile, notifier = notifier }
end
