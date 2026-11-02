-- StarterPlayerScripts > TardisTablette > Outils (ModuleScript)
-- Outils du volet latéral : grille par familles et pages
-- Extrait du script principal en V6.6.3 : reçoit ce qu'il utilise, renvoie ce que la suite utilise.

return function(contexte)
	local C, Config, Players, ReplicatedStorage, S, UI = contexte.C, contexte.Config, contexte.Players, contexte.ReplicatedStorage, contexte.S, contexte.UI
	local V, W, animer, creer, donneesDestination, exterieur = contexte.V, contexte.W, contexte.animer, contexte.creer, contexte.donneesDestination, contexte.exterieur
	local fermer, interieur, joueur, lireEtat, majInterface, majTuile = contexte.fermer, contexte.interieur, contexte.joueur, contexte.lireEtat, contexte.majInterface, contexte.majTuile
	local notifier, remote, texte = contexte.notifier, contexte.remote, contexte.texte
	local def = contexte.def

	--------------------------------------------------------------------
	-- OUTILS (volet latéral) : grille par familles, puis pages dans le même volet
	--------------------------------------------------------------------
	local O = {}
	local T = O -- les raccourcis Boucliers, Stabilisateur et Rotation sont des outils comme les autres
	local function ouvrirSurcouche(nom, titre) return V.ouvrir(nom, titre) end
	local function ligneTexte(_, txt, ordre, couleur, taille) return V.ligne(txt, ordre, couleur, taille) end
	local function boutonSurcouche(_, txt, ordre, couleur, action) return V.bouton(txt, ordre, couleur, action) end
	local function fermerSurcouche() V.retour() end

	local function famille(nom, ordre)
		texte({ Text = nom, Font = UI.POLICE_GRAS, TextSize = 10, TextColor3 = C.texte2, LayoutOrder = ordre, ZIndex = 62, Parent = V.grille })
		return creer("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = ordre + 1,
			ZIndex = 62, Parent = V.grille }, { creer("UIGridLayout", { CellSize = UDim2.fromOffset(200, 60), CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder }) })
	end
	local function tuileOutil(parent, nom, icone, ordre)
		local bouton = creer("TextButton", { BackgroundColor3 = C.panneau, Text = "", LayoutOrder = ordre, ZIndex = 62, Parent = parent },
		{ UI.coin(10), UI.contour(C.bleu, 1, 0.4) })
		local lampe = creer("Frame", { Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(8, 8), BackgroundColor3 = C.gris, ZIndex = 63, Parent = bouton }, { UI.coin(99) })
		texte({ Text = icone, TextSize = 16, TextColor3 = C.ambre, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -10, 0, 6),
			Size = UDim2.fromOffset(20, 18), AnchorPoint = Vector2.new(1, 0), ZIndex = 63, Parent = bouton })
		texte({ Text = nom, Font = UI.POLICE_GRAS, TextSize = 13, Position = UDim2.fromOffset(10, 22), Size = UDim2.new(1, -20, 0, 16), ZIndex = 63, Parent = bouton })
		local etat = texte({ Text = "", TextSize = 10, TextColor3 = C.texte2, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(10, 40),
			Size = UDim2.new(1, -20, 0, 12), ZIndex = 63, Parent = bouton })
		bouton:SetAttribute("CouleurBase", C.panneau)
		UI.rendreVivant(bouton)
		return { bouton = bouton, lampe = lampe, etat = etat }
	end
	local fVoyage, fSecurite, fAmbiance = famille("VOYAGE", 1), famille("SÉCURITÉ", 3), famille("AMBIANCE", 5)
	O.rappel = tuileOutil(fVoyage, "Rappel", "●", 1)
	O.minuterie = tuileOutil(fVoyage, "Minuterie", "●", 2)
	O.leurre = tuileOutil(fVoyage, "Leurre", "●", 3)
	O.rotation = tuileOutil(fVoyage, "Rotation", "○", 4)
	O.replay = tuileOutil(fVoyage, "Replay", "►", 5)
	O.stabilisateur = tuileOutil(fVoyage, "Stabilisateur", "◆", 6)
	O.copilote = tuileOutil(fVoyage, "Copilote", "◆", 7) -- V6.9.1 : un joueur à bord gère la navigation
	O.carnet = tuileOutil(fVoyage, "Carnet de bord", "■", 8) -- V6.9.1 : notes par lieu
	O.boucliers = tuileOutil(fSecurite, "Boucliers", "●", 1)
	O.equipage = tuileOutil(fSecurite, "Équipage", "●", 2)
	O.inviter = tuileOutil(fSecurite, "Inviter", "●", 3)
	O.registre = tuileOutil(fSecurite, "Registre", "■", 4)
	O.fiche = tuileOutil(fSecurite, "Fiche", "■", 5)
	O.autodestruction = tuileOutil(fSecurite, "Auto-destruction", "▲", 6)
	O.regenerations = tuileOutil(fSecurite, "Régénérations", "◆", 7)
	O.ingenierie = tuileOutil(fSecurite, "Ingénierie", "◆", 8) -- V6.7.2 : ouvre la tablette technicien
	O.siege = tuileOutil(fSecurite, "Siège", "▲", 9) -- V6.9 : bouclier + verrou + alerte d'un seul geste
	O.cle = tuileOutil(fSecurite, "Clé du TARDIS", "◆", 10) -- V6.9 : verrou à distance
	O.theme = tuileOutil(fAmbiance, "Thème", "◆", 1)
	O.jukebox = tuileOutil(fAmbiance, "Jukebox", "●", 2)
	O.projecteur = tuileOutil(fAmbiance, "Projecteur", "▲", 3)
	O.cabine = tuileOutil(fAmbiance, "Customisation", "◆", 4)

	local function majTuile(t, actif, texteEtat, couleur, disponible)
		UI.setDisponible(t.bouton, disponible, C.panneau)
		animer(t.lampe, 0.2, { BackgroundColor3 = actif and couleur or C.gris })
		t.etat.Text = texteEtat
		t.etat.TextColor3 = actif and couleur or C.texte2
	end
	-- Carnet de bord (V6.9.1) : liste publiée par le serveur, la plus récente d'abord
	local HttpService = game:GetService("HttpService")
	local function lireCarnet()
		local ok, liste = pcall(HttpService.JSONDecode, HttpService, exterieur:GetAttribute("Carnet") or "[]")
		return (ok and type(liste) == "table") and liste or {}
	end
	local function majOutils(e)
		local pose, alimente, porte, bloque = e.pose and not e.volLibre, e.alimente, e.porte, e.bloque
		local choix = S.choix
		local minuterieFin = exterieur:GetAttribute("MinuterieFin")
		local resteMinuterie = minuterieFin and math.max(0, minuterieFin - workspace:GetServerTimeNow())
		majTuile(O.rappel, false, "Vient à moi", C.cyan, pose and alimente and not porte and not bloque)
		majTuile(O.minuterie, resteMinuterie ~= nil, resteMinuterie and string.format("Décollage : %d s", resteMinuterie) or "Départ différé", C.ambre,
			(pose and alimente and not porte and not bloque) or resteMinuterie ~= nil)
		local leurreActif = workspace:FindFirstChild("TardisLeurre") ~= nil
		majTuile(O.leurre, leurreActif, leurreActif and "ACTIF · retirer" or (choix and "Faux TARDIS" or "Choisis un lieu"), C.cyan, leurreActif or choix ~= nil)
		majTuile(O.rotation, false, "Ajuster position", C.vert, pose and alimente and not porte and not bloque)
		majTuile(O.replay, false, UI.replayDisponible and "Dernier vol" or "Aucun vol", C.cyan, UI.replayDisponible == true)
		local stabilisateur = exterieur:GetAttribute("Stabilisateur") ~= false
		majTuile(O.stabilisateur, stabilisateur, stabilisateur and "Activé" or "Coupé · la cabine vibre", C.vert, true)
		local copiloteNom = exterieur:GetAttribute("CopiloteNom")
		majTuile(O.copilote, copiloteNom ~= nil, copiloteNom and ("En poste : " .. copiloteNom) or "Nommer un joueur à bord", C.cyan,
			copiloteNom ~= nil or (Config.Copilote or {}).Actif ~= false)
		local ici = exterieur:GetAttribute("Position")
		local notesIci, total = 0, 0
		for _, n in lireCarnet() do
			total += 1
			if type(n) == "table" and n.lieu == ici then notesIci += 1 end
		end
		majTuile(O.carnet, notesIci > 0, notesIci > 0 and (notesIci .. " note(s) ici") or (total .. " note(s) en tout"), C.ambre, true)
		local unBouclier = exterieur:GetAttribute("BouclierJoueurs") == true or exterieur:GetAttribute("BouclierBalles") == true or exterieur:GetAttribute("BouclierComplet") == true
		local energie = exterieur:GetAttribute("BouclierEnergie") or 100
		majTuile(O.boucliers, unBouclier, unBouclier and string.format("LEVÉ · énergie %d %%", energie) or "Anti-joueurs · balles · complet",
			(unBouclier and energie <= 15) and C.rouge or Color3.fromRGB(135, 206, 250), unBouclier or (pose and alimente and not porte))
		local nbRoles = 0
		for _ in string.gmatch(exterieur:GetAttribute("Roles") or "", "[^\n]+") do nbRoles += 1 end
		majTuile(O.equipage, nbRoles > 0, nbRoles > 0 and (nbRoles .. " rôle(s) actif(s)") or "Pilotes · bannis", C.ambre, true)
		majTuile(O.inviter, false, "Téléporter à bord", C.cyan, true)
		local intrusion = exterieur:GetAttribute("Intrusion")
		majTuile(O.registre, intrusion ~= nil, intrusion and ("Intrusion : " .. intrusion) or "Entrées · sorties", C.rouge, true)
		majTuile(O.fiche, false, "Dossier d'anomalie", C.texte2, true)
		local compteARebours = exterieur:GetAttribute("AutoDestructionDebut")
		majTuile(O.autodestruction, compteARebours ~= nil, compteARebours and "EN COURS !" or "Danger", C.rouge, pose and not compteARebours)
		local okJ, journalRegen = pcall(function() return game:GetService("HttpService"):JSONDecode(ReplicatedStorage:GetAttribute("TardisRegenerations") or "[]") end)
		local nbRegen = okJ and type(journalRegen) == "table" and #journalRegen or 0
		local lien = ReplicatedStorage:GetAttribute("TardisLienTimeLord") == true
		-- Ingénierie : nombre de pannes en cours (mêmes critères que la tablette technicien)
		local pannes = 0
		for _, attribut in { "Avarie", "RedemarrageRequis", "VapeurSurcharge", "Incendie" } do
			if exterieur:GetAttribute(attribut) then pannes += 1 end
		end
		if (exterieur:GetAttribute("RegulAir") or 100) < ((Config.Technicien or {}).SeuilAirVicie or 25) then pannes += 1 end
		local siege = exterieur:GetAttribute("Siege") == true
		majTuile(O.siege, siege, siege and "EN SIÈGE · lever" or "Bouclier · verrou · alerte", C.rouge, siege or (pose and alimente))
		majTuile(O.cle, false, "Verrou à distance", Color3.fromRGB(214, 170, 60), (Config.Cle or {}).Pilotes ~= false)
		majTuile(O.ingenierie, pannes > 0, pannes > 0 and (pannes .. " intervention(s)") or "Systèmes nominaux", C.orange, true)
		majTuile(O.regenerations, nbRegen > 0, (nbRegen > 0 and (nbRegen .. " au journal") or "Aucune") .. (lien and " · lien actif" or ""), C.ambre, true)
		majTuile(O.theme, exterieur:GetAttribute("Theme") ~= nil, exterieur:GetAttribute("Theme") or "Classique", C.ambre, alimente)
		local piste = exterieur:GetAttribute("Jukebox")
		local nomPiste = (type(piste) == "string" and ("Playlist " .. piste)) or (piste and ((Config.Jukebox or {})[piste] or {}).nom) or nil
		majTuile(O.jukebox, piste ~= nil, nomPiste or (#(Config.Jukebox or {}) > 0 and "Musique à bord" or "Aucune piste (Config.Jukebox)"), C.ambre, #(Config.Jukebox or {}) > 0)
		local projecteur = exterieur:GetAttribute("Projecteur") == true
		majTuile(O.projecteur, projecteur, projecteur and "ALLUMÉ · vise caméra" or "Éteint", Color3.fromRGB(255, 240, 180), alimente)
		majTuile(O.cabine, exterieur:GetAttribute("StyleInterieur") ~= nil or exterieur:GetAttribute("Couleur") ~= nil, "Intérieur · console · extérieur", C.cyan, alimente)
	end
	-- Mise à jour avec l'interface, et sur les attributs des outils
	exterieur:GetAttributeChangedSignal("Etat"):Connect(function() if S.ouvert then majOutils(lireEtat()) end end)
	for _, attribut in { "CopiloteNom", "Carnet", "Position", "Siege", "MinuterieFin", "Intrusion", "Theme", "Projecteur", "Couleur", "StyleInterieur", "Jukebox", "Stabilisateur", "Roles", "BouclierEnergie",
		"BouclierJoueurs", "BouclierBalles", "BouclierComplet", "AutoDestructionDebut", "Alimentation", "Porteur", "VolLibre", "DemarrageBloque" } do
		exterieur:GetAttributeChangedSignal(attribut):Connect(function() if S.ouvert then majOutils(lireEtat()) end end)
	end
	task.spawn(function()
		while true do
			task.wait(1)
			if S.ouvert then majOutils(lireEtat()) end -- les commandes rapides sont sur la tablette, toujours à jour
		end
	end)

	-- Rotation : le menu se ferme et la vue de repositionnement s'ouvre (script TardisRotation)
	T.rotation.bouton.Activated:Connect(function()
		if T.rotation.bouton:GetAttribute("Disponible") == false then return end
		fermer()
		joueur:SetAttribute("TardisRotation", true)
	end)
	local joueurDedans -- défini plus bas (registre)

	-- Équipage : promouvoir un pilote temporaire, bannir, retirer (durées : session, 30 min, 2 h, 1 jour, 7 jours)
	local afficherEquipage
	afficherEquipage = function()
		local c = ouvrirSurcouche("equipage", "ÉQUIPAGE  ·  PILOTES TEMPORAIRES ET BANNISSEMENTS")
		local ordre = 0
		-- Rôles actifs
		local actifs = {}
		for ligne in string.gmatch(exterieur:GetAttribute("Roles") or "", "[^\n]+") do
			local id, nom, type_, fin = string.match(ligne, "^(%d+)\t(.-)\t(%a+)\t(%d+)$")
			if id then table.insert(actifs, { id = tonumber(id), nom = nom, type_ = type_, fin = tonumber(fin) }) end
		end
		ordre += 1
		ligneTexte(c, "RÔLES ACTIFS  ·  clique pour retirer", ordre, C.texte2, 11)
		if #actifs == 0 then
			ordre += 1
			ligneTexte(c, "Aucun pilote temporaire ni bannissement.", ordre, C.texte2)
		end
		for _, r in actifs do
			ordre += 1
			local reste = r.fin > 0 and (r.fin - os.time()) or nil
			local duree = reste and (reste >= 86400 and string.format("%d j", reste / 86400) or reste >= 3600 and string.format("%d h", reste / 3600)
				or string.format("%d min", math.max(reste / 60, 1))) or "session"
			boutonSurcouche(c, string.format("%s  ·  %s  ·  %s", r.nom, r.type_ == "pilotes" and "pilote" or "banni", duree), ordre,
				r.type_ == "pilotes" and C.bleu or Color3.fromRGB(110, 40, 50), function()
					remote:FireServer(r.type_ == "pilotes" and "Promouvoir" or "Bannir", { joueur = r.id, retirer = true })
					task.delay(0.5, afficherEquipage)
				end)
		end
		-- Joueurs connectés
		ordre += 1
		ligneTexte(c, "JOUEURS CONNECTÉS  ·  choisis une action puis une durée", ordre, C.texte2, 11)
		for _, autre in Players:GetPlayers() do
			if autre ~= joueur then
				ordre += 1
				local role = autre:GetAttribute("TardisPilote") and "pilote" or (autre:GetAttribute("TardisTechnicien") and "technicien" or "visiteur")
				local b
				b = boutonSurcouche(c, autre.DisplayName .. "  ·  " .. role .. "  ·  promouvoir / bannir", ordre, nil, function()
					-- Deuxième niveau : action puis durée
					local cc = ouvrirSurcouche("equipage", "ÉQUIPAGE  ·  " .. autre.DisplayName)
					local o = 0
					for _, action in { { "Promouvoir", "Promouvoir pilote pour…", C.bleu }, { "Bannir", "Bannir pour…", Color3.fromRGB(110, 40, 50) } } do
						o += 1
						ligneTexte(cc, action[2], o, C.texte2, 11)
						for _, d in Config.DureesRoles or {} do
							o += 1
							boutonSurcouche(cc, d.nom, o, action[3], function()
								local donnees = { joueur = autre.UserId }
								if d.session then donnees.session = true else donnees.minutes = (d.secondes or 60) / 60 end
								remote:FireServer(action[1], donnees)
								task.delay(0.5, afficherEquipage)
							end)
						end
					end
					o += 1
					boutonSurcouche(cc, "Retour", o, nil, afficherEquipage)
				end)
			end
		end
	end
	O.equipage.bouton.Activated:Connect(afficherEquipage)

	-- Inviter : un joueur hors du TARDIS reçoit une invitation, qu'il accepte ou refuse
	O.inviter.bouton.Activated:Connect(function()
		local c = ouvrirSurcouche("inviter", "INVITER À BORD")
		local ordre = 0
		for _, autre in Players:GetPlayers() do
			if not joueurDedans(autre) then
				ordre += 1
				local role = autre:GetAttribute("TardisPilote") and "  ·  pilote" or ""
				boutonSurcouche(c, autre == joueur and "Moi  ·  me téléporter à bord" or (autre.DisplayName .. role), ordre, autre == joueur and C.bleu or nil, function()
					remote:FireServer("Inviter", { joueur = autre.UserId })
					fermerSurcouche()
				end)
			end
		end
		if ordre == 0 then ligneTexte(c, "Personne à inviter : tout le monde est déjà à bord.", 1, C.texte2) end
	end)

	-- Auto-destruction : trois confirmations l'une après l'autre, la dernière après 15 secondes
	O.autodestruction.bouton.Activated:Connect(function()
		if O.autodestruction.bouton:GetAttribute("Disponible") == false then return end
		local c = ouvrirSurcouche("autodestruction", "AUTO-DESTRUCTION DU TARDIS")
		ligneTexte(c, "CONSÉQUENCES", 1, C.rouge, 11)
		ligneTexte(c, "Rupture du Cœur du TARDIS, l'Œil de l'Harmonie : l'énergie d'une étoile figée est libérée d'un coup. "
			.. "Dans les 20 secondes qui suivent, la cabine entre en résonance, vire au rouge et l'alarme du Cloître retentit. "
			.. "À l'explosion, tout ce qui se trouve à moins de 50 studs est détruit : joueurs, objets, véhicules. "
			.. "Les occupants sont éjectés dehors, dans la zone de l'explosion. "
			.. "Le TARDIS disparaît et se reconstitue de lui-même au bout de 7 minutes, sur un point enregistré choisi au hasard. "
			.. "Pendant ce temps, aucune commande n'est possible.", 2, C.texte, 12)
		local etape = 0
		local b1, b2, b3
		b1 = boutonSurcouche(c, "1 · Je comprends les conséquences", 3, Color3.fromRGB(90, 40, 40), function()
			if etape ~= 0 then return end
			etape = 1
			b1.Text = "1 · Compris  ●"
			b2.Visible = true
		end)
		b2 = boutonSurcouche(c, "2 · Engager la procédure", 4, Color3.fromRGB(130, 40, 40), function()
			if etape ~= 1 then return end
			etape = 2
			b2.Text = "2 · Procédure engagée  ●"
			b3.Visible = true
			-- Le dernier bouton se déverrouille au bout de 15 secondes
			for reste = 15, 1, -1 do
				if V.actif ~= "autodestruction" then return end
				b3.Text = string.format("3 · DÉTRUIRE LE TARDIS  (dans %d s)", reste)
				task.wait(1)
			end
			if V.actif == "autodestruction" then
				etape = 3
				b3.Text = "3 · DÉTRUIRE LE TARDIS"
			end
		end)
		b3 = boutonSurcouche(c, "3 · DÉTRUIRE LE TARDIS  (dans 15 s)", 5, Color3.fromRGB(200, 40, 40), function()
			if etape ~= 3 then return end
			remote:FireServer("AutoDestruction", { confirmation = 3 })
			fermerSurcouche()
		end)
		b2.Visible = false
		b3.Visible = false
	end)
	exterieur:GetAttributeChangedSignal("Roles"):Connect(function()
		if V.actif == "equipage" then afficherEquipage() end
		if S.ouvert then majInterface() end
	end)
	-- Outils
	O.rappel.bouton.Activated:Connect(function()
		if O.rappel.bouton:GetAttribute("Disponible") == false then return end
		remote:FireServer("Rappel")
	end)
	O.minuterie.bouton.Activated:Connect(function()
		if O.minuterie.bouton:GetAttribute("Disponible") == false then return end
		local c = ouvrirSurcouche("minuterie", "MINUTERIE DE DÉCOLLAGE")
		ligneTexte(c, "Le TARDIS décollera tout seul et restera dans le vortex jusqu'à ce que tu le fasses atterrir.", 1, C.texte2)
		local ordre = 1
		for _, duree in { 10, 30, 60, 120, 300 } do
			ordre += 1
			boutonSurcouche(c, duree >= 60 and string.format("Dans %d min", duree / 60) or string.format("Dans %d s", duree), ordre, nil, function()
				remote:FireServer("Minuterie", { secondes = duree })
				fermerSurcouche()
			end)
		end
		boutonSurcouche(c, "Annuler la minuterie en cours", ordre + 1, Color3.fromRGB(110, 40, 50), function()
			remote:FireServer("MinuterieAnnuler")
			fermerSurcouche()
		end)
	end)
	O.leurre.bouton.Activated:Connect(function()
		if O.leurre.bouton:GetAttribute("Disponible") == false then return end
		if workspace:FindFirstChild("TardisLeurre") then
			remote:FireServer("Leurre", { retirer = true })
			return
		end
		local donnees = donneesDestination()
		if donnees then remote:FireServer("Leurre", donnees) else notifier("Choisis d'abord un lieu.", false) end
	end)
	O.fiche.bouton.Activated:Connect(function()
		local f = Config.FicheAnomalie or {}
		local c = ouvrirSurcouche("fiche", "FICHE D'ANOMALIE  ·  " .. tostring(f.Numero or "SCP-TARDIS"))
		ligneTexte(c, "CLASSE : " .. tostring(f.Classe or "?"), 1, C.ambre, 14)
		ligneTexte(c, "DESCRIPTION", 2, C.texte2, 11)
		ligneTexte(c, tostring(f.Description or ""), 3)
		ligneTexte(c, "PROCÉDURES DE CONFINEMENT", 4, C.texte2, 11)
		ligneTexte(c, tostring(f.Confinement or ""), 5)
		ligneTexte(c, "Dernière position connue : " .. tostring(exterieur:GetAttribute("Position") or "?"), 6, C.cyan, 12)
	end)
	local boiteIntOutils, tailleIntOutils = interieur:GetBoundingBox()
	joueurDedans = function(autre)
		local racine = autre.Character and autre.Character:FindFirstChild("HumanoidRootPart")
		if not racine then return false end
		local l = boiteIntOutils:PointToObjectSpace(racine.Position)
		return math.abs(l.X) <= tailleIntOutils.X / 2 + 20 and math.abs(l.Y) <= tailleIntOutils.Y / 2 + 20 and math.abs(l.Z) <= tailleIntOutils.Z / 2 + 20
	end
	local function afficherRegistre()
		local c = ouvrirSurcouche("registre", "REGISTRE DES PASSAGERS")
		local intrusion = exterieur:GetAttribute("Intrusion")
		if intrusion then ligneTexte(c, "▲ Dernière intrusion : " .. intrusion, 1, C.rouge, 13) end
		ligneTexte(c, "OCCUPANTS  ·  clique pour expulser", 2, C.texte2, 11)
		local ordre = 2
		for _, autre in Players:GetPlayers() do
			if joueurDedans(autre) then
				ordre += 1
				local b
				b = boutonSurcouche(c, autre.DisplayName .. (autre == joueur and "  (toi)" or "  ·  expulser"), ordre,
					autre == joueur and C.panneau or Color3.fromRGB(110, 40, 50), function()
						if autre ~= joueur then
							UI.confirmer(b, function() remote:FireServer("Expulser", { joueur = autre.UserId }) end)
						end
					end)
			end
		end
		if ordre == 2 then ligneTexte(c, "Personne dans le TARDIS.", 3, C.texte2) ordre = 3 end
		ligneTexte(c, "HISTORIQUE", ordre + 1, C.texte2, 11)
		local lignes = {}
		for ligne in string.gmatch(exterieur:GetAttribute("Registre") or "", "[^\n]+") do
			local h, nom, action = string.match(ligne, "^(.-)\t(.-)\t(.*)$")
			if h then table.insert(lignes, string.format("%s  ·  %s  ·  %s", h, nom, action)) end
			if #lignes >= 14 then break end
		end
		ligneTexte(c, #lignes > 0 and table.concat(lignes, "\n") or "Aucune entrée pour l'instant.", ordre + 2, C.texte, 12)
		-- Dossiers d'incident (une fiche par intrusion)
		local ok, incidents = pcall(function() return game:GetService("HttpService"):JSONDecode(exterieur:GetAttribute("Incidents") or "[]") end)
		incidents = ok and type(incidents) == "table" and incidents or {}
		ligneTexte(c, string.format("DOSSIERS D'INCIDENT  ·  %d", #incidents), ordre + 3, C.texte2, 11)
		local fiches = {}
		for i, inc in incidents do
			if i > 6 then break end
			table.insert(fiches, string.format("%s  ·  %s (%s)  ·  %s  ·  %s", inc.heure or "?", inc.nom or "?", inc.role or "?", inc.lieu or "?", inc.position or "?"))
		end
		ligneTexte(c, #fiches > 0 and table.concat(fiches, "\n") or "Aucune intrusion.", ordre + 4, C.texte, 11)
		if #incidents > 0 then
			boutonSurcouche(c, "Exporter les dossiers (markdown)", ordre + 5, C.bleu, function()
				local cc = ouvrirSurcouche("incidents", "DOSSIERS D'INCIDENT  ·  EXPORT")
				ligneTexte(cc, "Clique dans la zone, Ctrl+A puis Ctrl+C pour copier.", 1, C.texte2, 11)
				local md = { "# Dossiers d'incident du TARDIS", "" }
				for i, inc in incidents do
					table.insert(md, string.format("## Incident %d — %s", i, inc.heure or "?"))
					table.insert(md, string.format("- **Joueur** : %s (@%s)", inc.nom or "?", inc.pseudo or "?"))
					table.insert(md, string.format("- **Rôle** : %s", inc.role or "?"))
					table.insert(md, string.format("- **Lieu** : %s", inc.lieu or "?"))
					table.insert(md, string.format("- **Position du TARDIS** : %s", inc.position or "?"))
					table.insert(md, "")
				end
				creer("TextBox", { Size = UDim2.new(1, 0, 0, 380), BackgroundColor3 = C.panneau, Text = table.concat(md, "\n"), TextEditable = false,
					ClearTextOnFocus = false, MultiLine = true, TextWrapped = true, Font = UI.POLICE_CODE, TextSize = 11, TextColor3 = C.texte,
					TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 2, ZIndex = 22, Parent = cc },
				{ UI.coin(8), creer("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingTop = UDim.new(0, 6) }) })
			end)
		end
	end
	O.registre.bouton.Activated:Connect(afficherRegistre)
	exterieur:GetAttributeChangedSignal("Registre"):Connect(function() if V.actif == "registre" then afficherRegistre() end end)
	O.theme.bouton.Activated:Connect(function()
		if O.theme.bouton:GetAttribute("Disponible") == false then return end
		local c = ouvrirSurcouche("theme", "THÈME DE L'INTÉRIEUR")
		for i, theme in Config.Themes or {} do
			boutonSurcouche(c, theme.nom, i, exterieur:GetAttribute("Theme") == theme.nom and C.bleu or nil, function()
				remote:FireServer("Theme", { nom = theme.nom })
				fermerSurcouche()
			end)
		end
	end)
	O.projecteur.bouton.Activated:Connect(function()
		if O.projecteur.bouton:GetAttribute("Disponible") == false then return end
		remote:FireServer("Projecteur")
	end)
	O.cabine.bouton.Activated:Connect(function()
		if O.cabine.bouton:GetAttribute("Disponible") == false then return end
		local c = ouvrirSurcouche("cabine", "CUSTOMISATION")
		local ordre = 0
		-- Intérieur : styles (murs + sol)
		ordre += 1
		ligneTexte(c, "INTÉRIEUR  ·  style des murs et du sol", ordre, C.texte2, 11)
		for i, style in Config.StylesInterieur or {} do
			ordre += 1
			boutonSurcouche(c, style.nom, ordre, exterieur:GetAttribute("StyleInterieur") == i and C.bleu or style.murs.couleur:Lerp(C.panneau, 0.5), function()
				remote:FireServer("StyleInterieur", { index = i })
			end)
		end
		-- Murs : couleur seule
		ordre += 1
		ligneTexte(c, "MURS  ·  couleur seule", ordre, C.texte2, 11)
		local rangeeMurs = creer("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, LayoutOrder = ordre + 1, ZIndex = 22, Parent = c },
		{ creer("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
		for i, choixCouleur in Config.Couleurs or {} do
			local b = creer("TextButton", { Size = UDim2.new(1 / #Config.Couleurs, -4, 1, 0), BackgroundColor3 = choixCouleur.couleur, Text = "", LayoutOrder = i, ZIndex = 22,
				Parent = rangeeMurs }, { UI.coin(6), UI.contour(C.blanc, exterieur:GetAttribute("CouleurMurs") == i and 2 or 0, 0.2) })
			b.Activated:Connect(function() remote:FireServer("Murs", { index = i }) end)
		end
		ordre += 1
		-- Console : styles
		ordre += 1
		ligneTexte(c, "CONSOLE  ·  matière et couleur", ordre, C.texte2, 11)
		local rangeeConsole = creer("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, LayoutOrder = ordre + 1, ZIndex = 22, Parent = c },
		{ creer("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
		for i, style in Config.StylesConsole or {} do
			local b = creer("TextButton", { Size = UDim2.new(1 / #Config.StylesConsole, -4, 1, 0), BackgroundColor3 = style.couleur:Lerp(C.panneau, 0.3), Text = style.nom,
				Font = UI.POLICE_GRAS, TextSize = 10, TextColor3 = C.texte, LayoutOrder = i, ZIndex = 22, Parent = rangeeConsole },
			{ UI.coin(6), UI.contour(C.blanc, exterieur:GetAttribute("StyleConsole") == i and 2 or 0, 0.2) })
			b.Activated:Connect(function() remote:FireServer("StyleConsole", { index = i }) end)
		end
		ordre += 1
		-- Extérieur : couleur de la cabine et enseigne
		ordre += 1
		ligneTexte(c, "EXTÉRIEUR  ·  couleur de la cabine", ordre, C.texte2, 11)
		for i, choixCouleur in Config.Couleurs or {} do
			ordre += 1
			boutonSurcouche(c, choixCouleur.nom, ordre, choixCouleur.couleur:Lerp(C.panneau, 0.45), function()
				remote:FireServer("Couleur", { index = i })
			end)
		end
		ligneTexte(c, "EXTÉRIEUR  ·  décorations et reflets", ordre + 1, C.texte2, 11)
		local rangeeDeco = creer("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, LayoutOrder = ordre + 2, ZIndex = 22, Parent = c },
		{ creer("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
		for i, info in { { "Aucune", "Sans décoration" }, { "Noel", "Noël : guirlandes et neige" }, { "Halloween", "Halloween : citrouille" } } do
			local actif = (exterieur:GetAttribute("Decoration") or "Aucune") == info[1]
			local b = creer("TextButton", { Size = UDim2.new(1 / 3, -4, 1, 0), BackgroundColor3 = actif and C.bleu or C.panneauClair, Text = info[2], Font = UI.POLICE_GRAS,
				TextSize = 10, TextColor3 = C.texte, LayoutOrder = i, ZIndex = 22, Parent = rangeeDeco }, { UI.coin(6) })
			b.Activated:Connect(function() remote:FireServer("Decoration", { nom = info[1] }) end)
		end
		boutonSurcouche(c, exterieur:GetAttribute("Reflets") and "Reflets des vitres : activés" or "Reflets des vitres : désactivés", ordre + 3,
			exterieur:GetAttribute("Reflets") and C.bleu or nil, function() remote:FireServer("Reflets") end)
		ordre += 3
		ligneTexte(c, "EXTÉRIEUR  ·  enseigne (24 caractères max, filtrée par Roblox)", ordre + 1, C.texte2, 11)
		local saisie = creer("TextBox", { Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = C.panneau, Text = exterieur:GetAttribute("Enseigne") or "POLICE PUBLIC CALL BOX",
			PlaceholderText = "Texte de l'enseigne…", Font = UI.POLICE_GRAS, TextSize = 13, TextColor3 = C.texte, ClearTextOnFocus = false,
			LayoutOrder = ordre + 2, ZIndex = 22, Parent = c }, { UI.coin(8), UI.contour(C.cyan, 1, 0.5) })
		boutonSurcouche(c, "Appliquer l'enseigne", ordre + 3, C.bleu, function()
			if #saisie.Text > 0 then remote:FireServer("Enseigne", { texte = string.sub(saisie.Text, 1, 24) }) end
		end)
	end)
	O.siege.bouton.Activated:Connect(function()
		if O.siege.bouton:GetAttribute("Disponible") == false then return end
		if exterieur:GetAttribute("Siege") then remote:FireServer("Siege") return end
		UI.confirmer(O.siege.etat, function() remote:FireServer("Siege") end)
	end)
	O.cle.bouton.Activated:Connect(function()
		if O.cle.bouton:GetAttribute("Disponible") == false then return end
		remote:FireServer("Outil", { outil = "Cle" })
		notifier("Clé du TARDIS dans ton inventaire : clique avec, à moins de " .. tostring((Config.Cle or {}).Portee or 80) .. " studs.", true)
	end)
	O.ingenierie.bouton.Activated:Connect(function()
		fermer()
		joueur:SetAttribute("TardisTabletteTech", def.Nom)
	end)
	O.jukebox.bouton.Activated:Connect(function()
		if O.jukebox.bouton:GetAttribute("Disponible") == false then return end
		local c = ouvrirSurcouche("jukebox", "JUKEBOX")
		ligneTexte(c, "La musique ne s'entend qu'à bord (elle baisse en fondu quand on sort). Volume : réglages de la tablette.", 1, C.texte2, 11)
		-- Playlists : une par catégorie (« Action » : musiques d'action, aléatoire et enchaînée)
		local categories, ordreCategories = {}, {}
		for _, piste in Config.Jukebox or {} do
			if piste.categorie and not categories[piste.categorie] then
				categories[piste.categorie] = 0
				table.insert(ordreCategories, piste.categorie)
			end
			if piste.categorie then categories[piste.categorie] += 1 end
		end
		local ordre = 1
		for _, categorie in ordreCategories do
			ordre += 1
			boutonSurcouche(c, string.format("►  Playlist %s  (%d, aléatoire)", categorie, categories[categorie]), ordre,
				exterieur:GetAttribute("Jukebox") == categorie and C.bleu or Color3.fromRGB(120, 70, 30), function()
				remote:FireServer("Jukebox", { liste = categorie })
				fermerSurcouche()
			end)
		end
		for i, piste in Config.Jukebox or {} do
			boutonSurcouche(c, piste.nom .. (piste.categorie and ("  ·  " .. piste.categorie) or ""), ordre + i, exterieur:GetAttribute("Jukebox") == i and C.bleu or nil, function()
				remote:FireServer("Jukebox", { index = i })
				fermerSurcouche()
			end)
		end
		boutonSurcouche(c, "Arrêter la musique", ordre + #(Config.Jukebox or {}) + 1, Color3.fromRGB(110, 40, 50), function()
			remote:FireServer("Jukebox", {})
			fermerSurcouche()
		end)
	end)
	O.replay.bouton.Activated:Connect(function()
		if O.replay.bouton:GetAttribute("Disponible") == false then return end
		fermer()
		joueur:SetAttribute("TardisReplay", true)
	end)
	-- La minuterie se met à jour chaque seconde
	task.spawn(function()
		while true do
			task.wait(1)
			if S.ouvert and exterieur:GetAttribute("MinuterieFin") then majInterface() end
		end
	end)

	T.boucliers.bouton.Activated:Connect(function()
		if T.boucliers.bouton:GetAttribute("Disponible") == false then return end
		local c = ouvrirSurcouche("boucliers", "BOUCLIERS")
		local energie = exterieur:GetAttribute("BouclierEnergie") or 100
		ligneTexte(c, string.format("Énergie : %d %%  ·  le bouclier tombe quand elle atteint 0 (environ 250 balles). Invisible, il se révèle au contact et sous les tirs.", energie),
			1, energie <= 15 and C.rouge or C.texte2, 11)
		for i, info in { { "Joueurs", "Anti-joueurs : personne n'approche" }, { "Balles", "Anti-balles : les tirs s'arrêtent" }, { "Complet", "Complet : joueurs et tirs, un seul bouclier" } } do
			local actif = exterieur:GetAttribute("Bouclier" .. info[1]) == true
			boutonSurcouche(c, (actif and "●  " or "○  ") .. info[2], i + 1, actif and C.bleu or nil, function()
				remote:FireServer("Bouclier", { type = info[1] })
				fermerSurcouche()
			end)
		end
	end)
	T.stabilisateur.bouton.Activated:Connect(function() remote:FireServer("Stabilisateur") end)

	-- Le volet s'ouvre sur la grille des outils (état à jour)
	W.btnOutils.Activated:Connect(function() if V.actif == "outils" then majOutils(lireEtat()) end end)

	-- Régénérations : journal (qui, quand, où, numéro), et le lien Time Lord
	local function afficherRegenerations()
		local c = ouvrirSurcouche("regenerations", "RÉGÉNÉRATIONS")
		local lien = ReplicatedStorage:GetAttribute("TardisLienTimeLord") == true
		ligneTexte(c, "LIEN TIME LORD : les membres de la C.A.T. ressentent les régénérations des autres (notification et flash).", 1, C.texte2, 11)
		boutonSurcouche(c, lien and "●  Lien Time Lord : activé (désactiver)" or "○  Lien Time Lord : désactivé (activer)", 2, lien and C.bleu or nil, function()
			remote:FireServer("LienTimeLord")
			task.delay(0.4, afficherRegenerations)
		end)
		local ok, journal = pcall(function() return game:GetService("HttpService"):JSONDecode(ReplicatedStorage:GetAttribute("TardisRegenerations") or "[]") end)
		journal = ok and type(journal) == "table" and journal or {}
		ligneTexte(c, string.format("JOURNAL  ·  %d entrée(s)", #journal), 3, C.texte2, 11)
		if #journal == 0 then
			ligneTexte(c, "Aucune régénération pour l'instant.", 4, C.texte2)
			return
		end
		local lignes = {}
		for _, e in journal do
			table.insert(lignes, string.format("%s  ·  %s  ·  %s%s  ·  %s", e.heure or "?", e.nom or "?", e.nature or "?",
				e.numero and (" n°" .. e.numero) or "", e.lieu or "?"))
		end
		ligneTexte(c, table.concat(lignes, "\n"), 4, C.texte, 11)
	end
	O.regenerations.bouton.Activated:Connect(afficherRegenerations)
	ReplicatedStorage:GetAttributeChangedSignal("TardisRegenerations"):Connect(function()
		if V.actif == "regenerations" then afficherRegenerations() end
	end)

	--------------------------------------------------------------------
	-- Copilote (V6.9.1) : nommer ou relever le joueur à bord qui gère la navigation
	--------------------------------------------------------------------
	local afficherCopilote
	afficherCopilote = function()
		local c = ouvrirSurcouche("copilote", "COPILOTE")
		ligneTexte(c, "Le copilote gère la navigation pendant que tu pilotes : destination, protocoles, démat et remat, camouflage, "
			.. "et l'atterrissage du vol libre une fois dans le vortex. Il n'a aucun autre droit, et perd son poste s'il quitte le TARDIS.", 1, C.texte2, 11)
		local ordre = 1
		local actuel = exterieur:GetAttribute("Copilote")
		local function rafraichir() task.delay(0.6, function() if V.actif == "copilote" then afficherCopilote() end end) end
		if actuel then
			ordre += 1
			boutonSurcouche(c, "Relever " .. tostring(exterieur:GetAttribute("CopiloteNom") or "le copilote") .. " de son poste", ordre,
				Color3.fromRGB(110, 40, 50), function() remote:FireServer("Copilote", {}) rafraichir() end)
		end
		ordre += 1
		ligneTexte(c, "À BORD  ·  clique pour nommer", ordre, C.texte2, 11)
		local n = 0
		for _, autre in Players:GetPlayers() do
			if autre ~= joueur and joueurDedans(autre) and autre:GetAttribute("TardisPilote_" .. def.Nom) ~= true then
				n += 1
				ordre += 1
				local enPoste = actuel == autre.UserId
				boutonSurcouche(c, autre.DisplayName .. (enPoste and "  ·  en poste" or ""), ordre, enPoste and C.bleu or nil, function()
					remote:FireServer("Copilote", { joueur = autre.UserId })
					rafraichir()
				end)
			end
		end
		if n == 0 then ligneTexte(c, "Personne à nommer : il n'y a pas de passager à bord (les pilotes ont déjà tous les droits).", ordre + 1, C.texte2) end
	end
	O.copilote.bouton.Activated:Connect(function()
		if O.copilote.bouton:GetAttribute("Disponible") == false then return end
		afficherCopilote()
	end)

	--------------------------------------------------------------------
	-- Carnet de bord RP (V6.9.1) : écrire une note sur un lieu, relire les notes de l'équipage
	--------------------------------------------------------------------
	local afficherCarnet
	afficherCarnet = function(lieuChoisi)
		local c = ouvrirSurcouche("carnet", "CARNET DE BORD")
		local ici = exterieur:GetAttribute("Position") or "Lieu inconnu"
		local destination = S.choix and S.choix.type == "lieu" and S.choix.nom or nil
		local lieu = lieuChoisi or ici
		local ordre = 1
		ligneTexte(c, "NOUVELLE NOTE  ·  " .. string.upper(lieu), ordre, C.ambre, 11)
		-- Le lieu de la note : ici, ou la destination choisie dans la navigation
		if destination and destination ~= ici then
			ordre += 1
			local rangee = creer("Frame", { Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, LayoutOrder = ordre, ZIndex = 62, Parent = c },
			{ creer("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
			for i, l in { ici, destination } do
				local actif = l == lieu
				local b = creer("TextButton", { Size = UDim2.new(0.5, -3, 1, 0), BackgroundColor3 = actif and C.bleu or C.panneauClair,
					Text = (i == 1 and "Ici : " or "Destination : ") .. l, Font = UI.POLICE_GRAS, TextSize = 11, TextColor3 = C.texte,
					TextTruncate = Enum.TextTruncate.AtEnd, LayoutOrder = i, ZIndex = 62, Parent = rangee }, { UI.coin(6) })
				b.Activated:Connect(function() afficherCarnet(l) end)
			end
		end
		ordre += 1
		local longueur = (Config.Carnet or {}).LongueurMax or 200
		local saisie = creer("TextBox", { Size = UDim2.new(1, 0, 0, 70), BackgroundColor3 = C.panneau, Text = "", PlaceholderText = "Ce qui s'est passé ici…",
			Font = UI.POLICE, TextSize = 13, TextColor3 = C.texte, PlaceholderColor3 = C.texte2, TextWrapped = true, MultiLine = true, ClearTextOnFocus = false,
			TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = ordre, ZIndex = 62, Parent = c },
		{ UI.coin(8), UI.contour(C.ambre, 1, 0.5), UI.marges(8) })
		ordre += 1
		local compteur = ligneTexte(c, "0 / " .. longueur .. " caractères  ·  filtrée par Roblox", ordre, C.texte2, 10)
		saisie:GetPropertyChangedSignal("Text"):Connect(function()
			local n = utf8.len(saisie.Text) or #saisie.Text
			if n > longueur then saisie.Text = string.sub(saisie.Text, 1, utf8.offset(saisie.Text, longueur + 1) - 1) n = longueur end
			compteur.Text = n .. " / " .. longueur .. " caractères  ·  filtrée par Roblox"
		end)
		ordre += 1
		boutonSurcouche(c, "Écrire dans le carnet", ordre, C.bleu, function()
			local n = utf8.len(saisie.Text) or 0
			if n < 2 then notifier("Écris d'abord quelques mots.", false) return end
			remote:FireServer("CarnetEcrire", { texte = saisie.Text, lieu = lieu })
			task.delay(1.5, function() if V.actif == "carnet" then afficherCarnet(lieuChoisi) end end)
		end)
		-- Les notes : celles du lieu d'abord, puis les autres lieux
		local notes = lireCarnet()
		local function afficherNote(index, note)
			ordre += 1
			local carte = creer("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.panneau,
				LayoutOrder = ordre, ZIndex = 62, Parent = c }, { UI.coin(8), UI.marges(8), UI.pile(2) })
			-- En-tête : lieu, auteur, date, et le bouton pour effacer (dans un cadre : la pile ne le déplace pas)
			local entete = creer("Frame", { Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, LayoutOrder = 0, ZIndex = 63, Parent = carte })
			texte({ Text = string.format("%s  ·  %s  ·  %s", tostring(note.lieu), tostring(note.auteur), os.date("%d/%m %H:%M", tonumber(note.quand) or 0)),
				TextSize = 10, TextColor3 = C.texte2, Size = UDim2.new(1, -28, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 63, Parent = entete })
			texte({ Text = tostring(note.texte), TextSize = 13, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 16),
				LayoutOrder = 1, ZIndex = 63, Parent = carte })
			local effacer = creer("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(20, 20),
				BackgroundColor3 = Color3.fromRGB(110, 40, 50), Text = "✕", Font = UI.POLICE_GRAS, TextSize = 11, TextColor3 = C.texte, ZIndex = 64, Parent = entete },
			{ UI.coin(6) })
			-- Deux clics : le premier arme (« ? » rouge vif pendant 3 s), le second efface
			local arme = false
			effacer.Activated:Connect(function()
				if not arme then
					arme = true
					effacer.Text, effacer.BackgroundColor3 = "?", C.rouge
					task.delay(3, function()
						if arme and effacer.Parent then arme = false effacer.Text, effacer.BackgroundColor3 = "✕", Color3.fromRGB(110, 40, 50) end
					end)
					return
				end
				arme = false
				remote:FireServer("CarnetEffacer", { index = index, quand = note.quand })
				task.delay(1, function() if V.actif == "carnet" then afficherCarnet(lieuChoisi) end end)
			end)
		end
		ordre += 1
		ligneTexte(c, "NOTES  ·  " .. string.upper(lieu), ordre, C.texte2, 11)
		local nIci, autres = 0, {}
		for index, note in notes do
			if type(note) == "table" then
				if note.lieu == lieu then nIci += 1 afficherNote(index, note) else table.insert(autres, { index, note }) end
			end
		end
		if nIci == 0 then ordre += 1 ligneTexte(c, "Aucune note sur ce lieu pour l'instant.", ordre, C.texte2, 12) end
		if #autres > 0 then
			ordre += 1
			ligneTexte(c, "AUTRES LIEUX", ordre, C.texte2, 11)
			for i, paire in autres do
				if i > 30 then break end
				afficherNote(paire[1], paire[2])
			end
		end
	end
	O.carnet.bouton.Activated:Connect(function() afficherCarnet(nil) end)

	-- Commandes rapides : ces outils quittent le volet et prennent place directement sur la tablette
	do
		local grille = creer("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = W.rapides },
		{ creer("UIGridLayout", { CellSize = UDim2.new(1 / 3, -5, 0.5, -3), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
		for ordre, cle in { "rappel", "minuterie", "inviter", "stabilisateur", "projecteur", "registre" } do
			local t = O[cle]
			if t then
				t.bouton.Parent = grille
				t.bouton.LayoutOrder = ordre
				t.etat.Visible = false -- l'état se lit au voyant
				t.lampe.Position = UDim2.new(0, 8, 0.5, -4)
				for _, enfant in t.bouton:GetChildren() do
					if enfant:IsA("TextLabel") and enfant ~= t.etat then
						if enfant.TextXAlignment == Enum.TextXAlignment.Right then
							enfant.Position = UDim2.new(1, -6, 0.5, -9) -- icône
						else
							enfant.Position = UDim2.new(0, 20, 0.5, -8) -- nom
							enfant.Size = UDim2.new(1, -40, 0, 16)
							enfant.TextSize = 12
							enfant.TextTruncate = Enum.TextTruncate.AtEnd
						end
					end
				end
			end
		end
	end

	return {}
end
