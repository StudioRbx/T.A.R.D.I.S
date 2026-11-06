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
	-- V6.9.10.6 : le journal est un tableau HEURE | ÉVÉNEMENT | DÉTAIL (vue Journal), et ses trois dernières lignes sont
	-- recopiées dans la vue Navigation. « Posé : Hall » donne l'événement « Posé » et le détail « Hall ».
	S.journalEntrees = {}
	local function decouperMessage(message)
		local evenement, detail = string.match(message, "^(.-)%s:%s(.+)$")
		if not evenement then evenement, detail = message, "" end
		evenement = string.gsub(evenement, "%.$", "")
		detail = string.gsub(detail, "%.$", "")
		return evenement, detail
	end
	local function ligneJournal(tableau, entree, ordre)
		local evenement, detail = decouperMessage(entree.message)
		local ligne = tableau.ajouter({ heure = entree.heure, evenement = evenement, detail = detail },
			{ ordre = ordre, nom = "Evenement", couleurs = { heure = C.texte2 } })
		creer("Frame", { Name = "Repere", Position = UDim2.fromOffset(0, 9), Size = UDim2.fromOffset(3, 14), BackgroundColor3 = entree.couleur or C.texte2,
			BorderSizePixel = 0, Parent = ligne.bouton })
		return ligne
	end
	local function majJournalRecent()
		W.journalMini.vider()
		for i = 1, math.min(3, #S.journalEntrees) do ligneJournal(W.journalMini, S.journalEntrees[i], i) end
	end
	local function journaliser(message, couleur)
		S.compteurJournal += 1
		local entree = { heure = os.date("%H:%M:%S"), message = message, couleur = couleur }
		table.insert(S.journalEntrees, 1, entree)
		while #S.journalEntrees > 200 do table.remove(S.journalEntrees) end
		W.journalVide.Visible = false
		table.insert(S.lignesJournal, 1, ligneJournal(W.journalTableau, entree, -S.compteurJournal))
		while #S.lignesJournal > R.MAX_JOURNAL do
			W.journalTableau.retirer(table.remove(S.lignesJournal))
		end
		majJournalRecent()
	end

	W.effacer.Activated:Connect(function()
		for _, ligne in S.lignesJournal do W.journalTableau.retirer(ligne) end
		table.clear(S.lignesJournal)
		W.journalMini.vider()
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
		-- Charte : badge REFUSÉ (échec), ALERTE (message d'alerte, bande rouge) ou TARDIS
		local genre = (not reussi and "refus") or (string.find(string.lower(message), "alerte", 1, true) and "alerte") or "info"
		W.notif.regler(message, genre)
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

	-- Position de la destination choisie, si on peut la connaître (V6.9.10.6 : lieux cherchés aussi dans les sous-dossiers
	-- ACCORDE, REFUSE…, comme le menu rapide)
	local function positionDe(c)
		if not c then return nil end
		if c.type == "lieu" then
			local dossier = Config.dossierDestinations(false)
			local part = dossier and dossier:FindFirstChild(c.nom, true)
			return part and part:IsA("BasePart") and part.Position or nil
		elseif c.type == "joueur" then
			local autre = Players:GetPlayerByUserId(c.id)
			local racine = autre and autre.Character and autre.Character:FindFirstChild("HumanoidRootPart")
			return racine and racine.Position or nil
		elseif c.type == "historique" and c.cframe then
			return c.cframe.Position
		elseif c.type == "position" and S.positionPerso then
			return S.positionPerso.cframe.Position
		end
		return nil
	end
	-- Distance (studs) entre le TARDIS et la destination choisie, si on peut la connaître
	local function distanceDe(c)
		local position = positionDe(c)
		return position and (position - exterieur:GetPivot().Position).Magnitude or nil
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
			W.ficheNom.Text = "AUCUNE DESTINATION"
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
		-- Charte : « X −14 · Y 0 · Z −480 · 312 studs » quand la position est connue
		local position = positionDe(c)
		local coordonnees = position and string.format("X %d · Y %d · Z %d  ·  ", position.X, position.Y, position.Z) or ""
		local texteDistance = coordonnees .. (distance and string.format("%d studs", distance) or "distance inconnue") .. "  ·  " .. trajet
		if c.type == "lieu" then
			W.ficheIcone.Text = "◆"
			W.ficheNom.Text = UI.majuscules(c.nom)
			W.ficheInfo.Text = texteDistance
		elseif c.type == "precedent" then
			W.ficheIcone.Text = "◄"
			W.ficheNom.Text = UI.majuscules("Retour : " .. c.nom)
			W.ficheInfo.Text = "DERNIÈRE DESTINATION  ·  là d'où le TARDIS est parti  ·  " .. trajet
		elseif c.type == "historique" then
			W.ficheIcone.Text = "►"
			W.ficheNom.Text = UI.majuscules(c.nom)
			W.ficheInfo.Text = "HISTORIQUE  ·  " .. texteDistance
		elseif c.type == "joueur" then
			W.ficheIcone.Text = "●"
			W.ficheNom.Text = UI.majuscules(c.nom)
			W.ficheInfo.Text = (S.figer and "JOUEUR · SUR LUI (FIGÉ)" or "JOUEUR · DERNIÈRE POSITION") .. "  ·  " .. texteDistance
		else
			W.ficheIcone.Text = "○"
			W.ficheNom.Text = "NOUVELLE LOCALISATION"
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
		-- (couleurs : celles de la variante du bouton, voir UI.boutonPrincipal)
		UI.setDisponible(W.demat, dematOk, C.bleu)
		UI.setDisponible(W.remat, rematOk, C.bleu)
		if Commandes.secondesAutoRemat() and e.etat == E.Vol then
			W.remat.SousTitre.Text = string.format("Auto dans %d s", math.ceil(Commandes.secondesAutoRemat()))
		else
			W.remat.SousTitre.Text = petit and "Sur place (réduit)" or (e.etat == E.Vol and not S.choix and "Choisis une destination" or "Atterrir")
		end
		-- Paradoxe : le bouton REMAT demande une confirmation (rouge)
		UI.confirmationBouton(W.remat, Commandes.paradoxeArme())

		-- Vue Navigation (V6.9.10.6) : cartes d'état (bord gauche de couleur), VOL LIBRE et ALERTE
		local modeAffiche = e.etat ~= E.Pose and e.mode or Commandes.mode()
		local dDemat, cDemat = Config.Timing(E.Demat, modeAffiche)
		local dRemat, cRemat = Config.Timing(E.Remat, modeAffiche)
		W.cartesEtat.etat.regler(nomCourt, couleurEtat, couleurEtat)
		W.cartesEtat.mode.regler(string.format("%s · %d s", Config.libelleMode(modeAffiche), dDemat + cDemat + dRemat + cRemat + (Config.DureeVortexAuto or 10)),
			modeAffiche == "Normal" and C.texte or UI.couleurMode(modeAffiche), modeAffiche == "Normal" and C.ligne or UI.couleurMode(modeAffiche))
		if e.verrouille then
			W.cartesEtat.portes.regler("Verrouillées", C.texte, C.vert)
		elseif e.porteOuverte then
			W.cartesEtat.portes.regler("Ouvertes", C.ambre, C.ambre)
		else
			W.cartesEtat.portes.regler("Fermées", C.texte, C.ligne)
		end
		local volLibreOk = e.pose and not e.porte and e.alimente and not e.bloque and not e.volLibre
		UI.setDisponible(W.boutonVolLibre, volLibreOk)
		UI.setDisponible(W.boutonLancerVol, volLibreOk)
		W.volLibreEtat.Text = (e.volLibre and "EN VOL") or (volLibreOk and "PRÊT") or "INDISPONIBLE"
		W.volLibreEtat.TextColor3 = (e.volLibre and C.cyan) or (volLibreOk and C.vert) or C.texte2
		W.volLibreRaison.Text = (e.volLibre and "Le TARDIS est déjà en vol libre.") or (not e.alimente and "Hors tension : rétablis l'énergie.")
			or (e.bloque and "Démarrage bloqué à la console.") or (e.porte and "Il est porté : pose-le d'abord.")
			or (not e.pose and "Disponible quand il est posé.") or "Posé et alimenté : tu peux prendre les commandes."
		local siege = exterieur:GetAttribute("Siege") == true
		if not W.boutonAlerte:GetAttribute("EnAttenteConfirmation") then
			W.boutonAlerte.Text = siege and "LEVER L'ALERTE" or "ALERTE"
		end
		UI.setDisponible(W.boutonAlerte, siege or (e.pose and e.alimente))

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
		-- Jauges à segments (V6.9.10.6) : sous 15 %, le bouclier passe dans le rouge
		W.jaugeBouclier.regler(energie, unActif and (energie <= 15 and C.rouge or C.cyan) or C.texte2, unActif and string.format("%d %%", energie) or "—")
		W.cartesEtat.boucliers.regler(unActif and string.format("Actifs · %d %%", energie) or "Inactifs", unActif and C.cyan or C.texte2,
			unActif and (energie <= 15 and C.rouge or C.cyan) or C.ligne)
		-- Intégrité (points de vie) : voyant "Énergie" étendu
		local integrite = exterieur:GetAttribute("PointsDeVie")
		if integrite then
			local couleurIntegrite = (integrite <= 20 and C.rouge) or (integrite <= 50 and C.ambre) or C.vert
			W.jaugeIntegrite.regler(integrite, couleurIntegrite, string.format("%d %%", integrite))
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

		-- Sélection dans le tableau (ligne choisie en jaune) + fiche
		local cleChoisie = cleDe(S.choix)
		for cle, element in S.boutonsChoix do
			element.ligne.choisir(cle == cleChoisie)
		end
		majFiche()
	end

	return { cleDe = cleDe, distanceDe = distanceDe, journaliser = journaliser, lireEtat = lireEtat, majFiche = majFiche, majInterface = majInterface, majTuile = majTuile, notifier = notifier }
end
