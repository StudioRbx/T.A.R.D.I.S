-- StarterPlayerScripts > TardisExtrasClient > Console (ModuleScript)
-- Commandes de la console qui ouvrent un panneau (V6.9.10.1). Le serveur décide qui peut, ce module ne fait qu'afficher :
--   « __energie » : menu de gestion de l'énergie (clic sur Console › Ecran-Ingenieure, pilotes et ingénieurs) :
--     intégrité, énergie, boucliers, et la régulation (énergie, air, vapeur) par l'action existante « Tech / Reguler » ;
--   « __jukebox » : panneau du jukebox (Console › JukeBox, pilotes) : pistes et playlists de Config.Jukebox, par
--     l'action existante « Jukebox » ;
--   « __console » : un message court (« Réservé aux pilotes. »…) en bas de l'écran.
-- Chaque panneau se ferme avec son bouton, Échap, ou en s'éloignant de l'objet. Aucune boucle par image : mises à jour
-- sur les changements d'attributs, et une vérification de la distance toutes les 0,5 s tant qu'un panneau est ouvert.

return function(contexte)
	local C, Config, UI, UserInputService = contexte.C, contexte.Config, contexte.UI, contexte.UserInputService
	local creer, texte = contexte.creer, contexte.texte
	local def, exterieur, interieur, joueur, maRacine, remote = contexte.def, contexte.exterieur, contexte.interieur, contexte.joueur, contexte.maRacine, contexte.remote
	local TECH = Config.Technicien or {}
	local REGLAGES = Config.EcranIngenieur or {}
	local PAS = math.max(tonumber(REGLAGES.Pas) or 5, 1)
	local playerGui = joueur:WaitForChild("PlayerGui")

	local function bouton(parent, txt, couleur, taille, ordre, action)
		local b = creer("TextButton", { Size = taille, BackgroundColor3 = couleur or C.panneauClair, Text = txt, Font = UI.POLICE_GRAS, TextSize = 13,
			TextColor3 = C.texte, TextWrapped = true, LayoutOrder = ordre or 0, Parent = parent }, { UI.coin(8) })
		b:SetAttribute("CouleurBase", b.BackgroundColor3)
		UI.rendreVivant(b)
		b.Activated:Connect(action)
		return b
	end

	--------------------------------------------------------------------
	-- Message court de la console (en bas de l'écran, 3 s)
	--------------------------------------------------------------------
	local guiMessage = creer("ScreenGui", { Name = "TardisConsoleMessage", ResetOnSpawn = false, DisplayOrder = 20, Parent = playerGui })
	local carteMessage = creer("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -110), Size = UDim2.fromOffset(360, 0),
		AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.fond, BackgroundTransparency = 0.05, Visible = false, Parent = guiMessage },
	{ UI.coin(12), UI.marges(10) })
	local contourMessage = UI.contour(C.rouge, 1.5, 0.1)
	contourMessage.Parent = carteMessage
	local texteMessage = texte({ Name = "Texte", Text = "", Font = UI.POLICE_GRAS, TextSize = 14, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y,
		TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 0), Parent = carteMessage })
	local jetonMessage = 0
	local function afficherMessage(message, ok)
		jetonMessage += 1
		local moi = jetonMessage
		local couleur = ok and C.vert or C.rouge
		contourMessage.Color = couleur
		texteMessage.TextColor3 = UI.eclaircir(couleur, 0.4)
		texteMessage.Text = (ok and "●  " or "×  ") .. tostring(message)
		carteMessage.Visible = true
		UI.son(ok and "Notification" or "Alerte")
		task.delay(3, function()
			if moi == jetonMessage then carteMessage.Visible = false end
		end)
	end

	--------------------------------------------------------------------
	-- Cadre commun des panneaux (centrés, compacts, style TardisUI)
	--------------------------------------------------------------------
	local function panneau(nom, titre, sousTitre, couleur, largeur)
		local gui = creer("ScreenGui", { Name = nom, ResetOnSpawn = false, Enabled = false, DisplayOrder = 15, Parent = playerGui })
		local carte = creer("Frame", { Name = "Carte", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(largeur, 0),
			AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.fond, BackgroundTransparency = 0.04, Parent = gui },
		{ UI.coin(16), UI.contour(couleur, 1.5, 0.3), UI.marges(14), UI.pile(8) })
		creer("UIScale", { Scale = UI.tailleInterface(), Parent = carte })
		texte({ Name = "Titre", Text = titre, Font = UI.POLICE_GRAS, TextSize = 16, TextColor3 = couleur, LayoutOrder = 1, Parent = carte })
		texte({ Name = "SousTitre", Text = sousTitre, TextSize = 11, TextColor3 = C.texte2, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2, Parent = carte })
		return gui, carte
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

	--------------------------------------------------------------------
	-- Menu de gestion de l'énergie (écran ingénieur)
	--------------------------------------------------------------------
	local guiEnergie, carteEnergie = panneau("TardisMenuEnergie", "◆  GESTION DE L'ÉNERGIE", def.Nom .. "  ·  écran ingénieur. Les réglages passent par la régulation, comme la tablette technicien.", C.ambre, 380)
	local jauges = {} -- [cle] = { valeur, barre }
	local function jauge(parent, cle, nom, ordre)
		local cadre = creer("Frame", { Name = "Jauge_" .. cle, Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, LayoutOrder = ordre, Parent = parent })
		texte({ Text = nom, Font = UI.POLICE_GRAS, TextSize = 11, TextColor3 = C.texte2, Size = UDim2.new(0.45, 0, 0, 14), Parent = cadre })
		local valeur = texte({ Name = "Valeur", Text = "—", Font = UI.POLICE_CODE, TextSize = 12, TextColor3 = C.vert, TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.fromScale(0.45, 0), Size = UDim2.new(0.55, 0, 0, 14), Parent = cadre })
		local fond = creer("Frame", { Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 8), BackgroundColor3 = C.gris, Parent = cadre }, { UI.coin(99) })
		local barre = creer("Frame", { Name = "Barre", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.vert, Parent = fond }, { UI.coin(99) })
		jauges[cle] = { valeur = valeur, barre = barre }
	end
	UI.titreSection(carteEnergie, "ÉTAT", 3, C.cyan)
	local carteEtat = creer("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 4,
		Parent = carteEnergie }, { UI.pile(4) })
	jauge(carteEtat, "integrite", "INTÉGRITÉ", 1)
	jauge(carteEtat, "alimentation", "ALIMENTATION", 2)
	jauge(carteEtat, "bouclier", "BOUCLIERS", 3)
	UI.titreSection(carteEnergie, "RÉGULATION", 5, C.ambre)
	local carteRegul = creer("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 6,
		Parent = carteEnergie }, { UI.pile(6) })

	-- Envoi des réglages : un à la fois (le serveur refuse deux commandes Tech à moins de 0,25 s), la dernière valeur gagne
	local aEnvoyer, ordreEnvoi, envoiEnCours = {}, {}, false
	local regulations = {} -- [systeme] = { valeur, barre, couleur, voulu } ; voulu = valeur demandée, affichée en attendant le serveur
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
	local function reguler(systeme, nom, couleur, ordre)
		local cadre = creer("Frame", { Name = "Regul_" .. systeme, Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, LayoutOrder = ordre, Parent = carteRegul })
		texte({ Text = nom, Font = UI.POLICE_GRAS, TextSize = 11, TextColor3 = C.texte2, Size = UDim2.new(1, -150, 0, 14), Parent = cadre })
		local valeur = texte({ Name = "Valeur", Text = "—", Font = UI.POLICE_CODE, TextSize = 13, TextColor3 = couleur, TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.new(1, -150, 0, 0), Size = UDim2.fromOffset(60, 14), Parent = cadre })
		local fond = creer("Frame", { Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, -150, 0, 8), BackgroundColor3 = C.gris, Parent = cadre }, { UI.coin(99) })
		local barre = creer("Frame", { Name = "Barre", Size = UDim2.fromScale(0.5, 1), BackgroundColor3 = couleur, Parent = fond }, { UI.coin(99) })
		local r = { valeur = valeur, barre = barre, couleur = couleur, voulu = nil }
		regulations[systeme] = r
		local function changer(delta)
			local actuel = r.voulu or tonumber(exterieur:GetAttribute("Regul" .. systeme)) or 50
			local nouveau = math.clamp(math.floor((actuel + delta) / PAS + 0.5) * PAS, 0, 100) -- toujours entre 0 et 100
			if nouveau == actuel then return end
			r.voulu = nouveau
			valeur.Text = string.format("%d %%", nouveau)
			barre.Size = UDim2.fromScale(nouveau / 100, 1)
			if not aEnvoyer[systeme] then table.insert(ordreEnvoi, systeme) end
			aEnvoyer[systeme] = nouveau
			envoyerReglages()
		end
		local moins = bouton(cadre, "−", C.panneauClair, UDim2.fromOffset(40, 30), 0, function() changer(-PAS) end)
		moins.Name = "Moins"
		moins.AnchorPoint, moins.Position = Vector2.new(1, 0), UDim2.new(1, -46, 0, 2)
		local plus = bouton(cadre, "+", C.panneauClair, UDim2.fromOffset(40, 30), 0, function() changer(PAS) end)
		plus.Name = "Plus"
		plus.AnchorPoint, plus.Position = Vector2.new(1, 0), UDim2.new(1, 0, 0, 2)
	end
	reguler("Energie", "ÉNERGIE (TENSION)", C.ambre, 1)
	reguler("Air", "AIR (RECYCLAGE)", C.cyan, 2)
	reguler("Vapeur", "VAPEUR (REFROIDISSEMENT)", Color3.fromRGB(220, 230, 240), 3)
	local rangee = creer("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, LayoutOrder = 7, Parent = carteEnergie })
	local fermerEnergie = bouton(rangee, "Fermer  (Échap)", C.panneauClair, UDim2.fromScale(1, 1), 0, fermerPanneau)
	fermerEnergie.Name = "Fermer"

	local function couleurNiveau(v, bas, haut)
		if v <= bas then return C.rouge end
		if v <= haut then return C.ambre end
		return C.vert
	end
	local function majJauge(cle, p, valeurTexte, couleur)
		jauges[cle].valeur.Text = valeurTexte
		jauges[cle].valeur.TextColor3 = couleur
		jauges[cle].barre.Size = UDim2.fromScale(math.clamp(p, 0, 1), 1)
		jauges[cle].barre.BackgroundColor3 = couleur
	end
	majEnergie = function(attributChange)
		local pv = tonumber(exterieur:GetAttribute("PointsDeVie")) or 100
		majJauge("integrite", pv / 100, string.format("%d %%  (%s PV)", pv, tostring(exterieur:GetAttribute("PV") or "?")), couleurNiveau(pv, 20, 50))
		local alimente = exterieur:GetAttribute("Alimentation") ~= false
		majJauge("alimentation", alimente and 1 or 0, alimente and "NOMINALE" or "COUPÉE", alimente and C.vert or C.rouge)
		local actif = (exterieur:GetAttribute("BouclierComplet") == true and "COMPLET") or (exterieur:GetAttribute("BouclierBalles") == true and "ANTI-BALLES")
			or (exterieur:GetAttribute("BouclierJoueurs") == true and "ANTI-JOUEURS") or nil
		local energieBouclier = math.floor((tonumber(exterieur:GetAttribute("BouclierEnergie")) or 100) + 0.5)
		majJauge("bouclier", energieBouclier / 100, (actif or (energieBouclier <= 0 and "TOMBÉ" or "INACTIF")) .. string.format("  ·  %d %%", energieBouclier),
			actif and couleurNiveau(energieBouclier, 15, 40) or (energieBouclier <= 0 and C.rouge or C.texte2))
		for systeme, r in regulations do
			local v = tonumber(exterieur:GetAttribute("Regul" .. systeme)) or 50
			-- Le serveur a répondu (ou un autre a réglé) et rien ne reste à envoyer : sa valeur fait foi
			if r.voulu and not aEnvoyer[systeme] and (r.voulu == v or attributChange == "Regul" .. systeme) then r.voulu = nil end
			local affiche = r.voulu or v
			r.valeur.Text = string.format("%d %%", affiche)
			r.barre.Size = UDim2.fromScale(affiche / 100, 1)
			local alerte = (systeme == "Energie" and (affiche < (TECH.SousTension or 20) or affiche > (TECH.SurtensionAuDessus or 90)))
				or (systeme == "Air" and affiche < (TECH.SeuilAirVicie or 25))
			r.valeur.TextColor3 = alerte and C.rouge or r.couleur
			r.barre.BackgroundColor3 = alerte and C.rouge or r.couleur
		end
	end
	for _, nom in { "PointsDeVie", "PV", "Alimentation", "BouclierEnergie", "BouclierJoueurs", "BouclierBalles", "BouclierComplet", "RegulEnergie", "RegulAir", "RegulVapeur" } do
		exterieur:GetAttributeChangedSignal(nom):Connect(function()
			if ouvert and ouvert.gui == guiEnergie then majEnergie(nom) end
		end)
	end

	--------------------------------------------------------------------
	-- Panneau du jukebox
	--------------------------------------------------------------------
	local guiJukebox, carteJukebox = panneau("TardisJukeboxConsole", "♪  JUKEBOX", "La musique ne s'entend qu'à bord. Volume : réglages de la tablette.", C.cyan, 300)
	local listeJukebox = creer("ScrollingFrame", { Name = "Liste", Size = UDim2.new(1, 0, 0, 220), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.cyan, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Parent = carteJukebox }, { UI.pile(6) })
	local function construireJukebox()
		for _, e in listeJukebox:GetChildren() do
			if not e:IsA("UIListLayout") then e:Destroy() end
		end
		local enCours = exterieur:GetAttribute("Jukebox")
		local pistes = Config.Jukebox or {}
		local categories, ordreCategories = {}, {}
		for _, piste in pistes do
			if piste.categorie and not categories[piste.categorie] then
				categories[piste.categorie] = 0
				table.insert(ordreCategories, piste.categorie)
			end
			if piste.categorie then categories[piste.categorie] += 1 end
		end
		local ordre = 0
		if #pistes == 0 then
			ordre += 1
			texte({ Name = "Vide", Text = "Aucune musique : Config.Jukebox est vide.", TextSize = 12, TextColor3 = C.texte2, TextWrapped = true,
				AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = ordre, Parent = listeJukebox })
		end
		for _, categorie in ordreCategories do
			ordre += 1
			local b = bouton(listeJukebox, string.format("►  Playlist %s  (%d, aléatoire)", categorie, categories[categorie]),
				enCours == categorie and C.bleu or Color3.fromRGB(120, 70, 30), UDim2.new(1, -6, 0, 32), ordre, function()
				remote:FireServer("Jukebox", { liste = categorie })
			end)
			b.Name = "Playlist"
		end
		for i, piste in pistes do
			ordre += 1
			local b = bouton(listeJukebox, tostring(piste.nom) .. (piste.categorie and ("  ·  " .. piste.categorie) or ""), enCours == i and C.bleu or C.panneauClair,
				UDim2.new(1, -6, 0, 32), ordre, function()
				remote:FireServer("Jukebox", { index = i })
			end)
			b.Name = "Piste"
		end
	end
	local rangeeJukebox = creer("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, LayoutOrder = 4, Parent = carteJukebox },
	{ UI.pile(8, true) })
	local arreter = bouton(rangeeJukebox, "Arrêter la musique", Color3.fromRGB(110, 40, 50), UDim2.new(0.6, -4, 1, 0), 1, function()
		remote:FireServer("Jukebox", {})
	end)
	arreter.Name = "Arreter"
	local fermerJukebox = bouton(rangeeJukebox, "Fermer", C.panneauClair, UDim2.new(0.4, -4, 1, 0), 2, fermerPanneau)
	fermerJukebox.Name = "Fermer"
	exterieur:GetAttributeChangedSignal("Jukebox"):Connect(function()
		if ouvert and ouvert.gui == guiJukebox then construireJukebox() end
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
			construireJukebox()
			ouvrirPanneau(guiJukebox, partOu(info, "JukeBox"), (Config.JukeboxConsole or {}).DistanceFermeture or 14)
		end
	end)

	return { fermer = fermerPanneau }
end
