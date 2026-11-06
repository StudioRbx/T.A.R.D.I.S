-- StarterPlayerScripts > TardisTablette > Ouverture (ModuleScript)
-- Ouverture et fermeture animées de la tablette
-- Extrait du script principal en V6.6.3 : reçoit ce qu'il utilise, renvoie ce que la suite utilise.
-- V6.9.10.6 : la disposition suit l'écran (onglets en ligne sur téléphone, W.majCompact) ; les widgets se rangent par vue.

return function(contexte)
	local LARGEUR_VOLET, R, S, UI, V, W = contexte.LARGEUR_VOLET, contexte.R, contexte.S, contexte.UI, contexte.V, contexte.W
	local animer, camera, construireListe, def, joueur, panneaux = contexte.animer, contexte.camera, contexte.construireListe, contexte.def, contexte.joueur, contexte.panneaux
	local remote = contexte.remote

	--------------------------------------------------------------------
	-- Ouverture / fermeture (animées)
	--------------------------------------------------------------------
	local function echelleBase()
		local ecran = camera.ViewportSize
		local largeur = R.LARGEUR + (V.actif and LARGEUR_VOLET or 0) -- volet ouvert : il faut aussi lui faire de la place
		return math.clamp(math.min(ecran.X * 0.95 / largeur, ecran.Y * 0.92 / R.HAUTEUR), 0.4, 1.25) * UI.tailleInterface()
	end
	-- Disposition : échelle de la tablette, onglets en colonne ou en ligne (téléphone) ; V6.9.10.6 : le volet est une vue
	-- de la tablette, il ne la décale plus
	local function majDisposition()
		if W.majCompact then W.majCompact() end
		local echelle = echelleBase()
		W.echelle.Scale = echelle
		W.tablette.Position = UDim2.new(0.5, V.actif and -(LARGEUR_VOLET * echelle) / 2 or 0, 0.5, 0)
	end
	V.majDisposition = majDisposition

	-- Widgets : les panneaux masqués libèrent leur place, les autres remontent dans leur colonne (une colonne par vue et par x)
	local function appliquerWidgets()
		local colonnes = {}
		for _, p in W.panneauxListe do
			local cle = tostring(p.vue) .. ":" .. tostring(p.x)
			colonnes[cle] = colonnes[cle] or {}
			table.insert(colonnes[cle], p)
		end
		for _, liste in colonnes do
			table.sort(liste, function(a, b) return a.y < b.y end)
			local y = liste[1].y
			for _, p in liste do
				local visible = UI.widgetVisible(p.widget)
				p.cadre.Visible = visible
				if visible and not p.fixe then
					p.cadre.Position = UDim2.fromOffset(p.x, y)
					y += p.hauteur + 12
				end
			end
		end
	end
	UI.prefsChangees.Event:Connect(function(cle)
		if cle == "widgets" or cle == "debutant" then appliquerWidgets() end
		if cle == "taille" and S.ouvert then majDisposition() end
		if cle == "tri" or cle == "theme" then construireListe() end -- (thème : statuts et cartes d'état aux nouvelles couleurs)
	end)
	appliquerWidgets()

	local function ouvrir()
		if S.ouvert or joueur:GetAttribute("TardisPilote_" .. def.Nom) ~= true then
			if joueur:GetAttribute("TardisPilote_" .. def.Nom) ~= true then joueur:SetAttribute("TardisTablette", false) end
			return
		end
		S.ouvert = true
		W.gui.Enabled = true
		W.voile.Visible = true
		W.tablette.Visible = true
		W.voile.BackgroundTransparency = 1
		animer(W.voile, 0.35, { BackgroundTransparency = 0.45 })
		W.flou.Enabled = true
		animer(W.flou, 0.45, { Size = 18 })

		if W.majCompact then W.majCompact() end
		local base = echelleBase()
		W.echelle.Scale = base * 0.86
		W.tablette.Position = UDim2.fromScale(0.5, 0.57)
		-- (V6.9.10.6 : plus d'inclinaison à l'ouverture : un cadre tourné ne coupe plus ce qui dépasse, la bande de danger déborderait)
		W.tablette.Rotation = 0
		animer(W.echelle, 0.55, { Scale = base }, Enum.EasingStyle.Back)
		animer(W.tablette, 0.55, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Back)
		-- Allumage de l'écran (anciens thèmes) : il part du noir et s'éclaire en un quart de seconde
		if not UI.estConfinement() then
			local ecranOrigine = UI.C.ecran
			W.ecran.BackgroundColor3 = Color3.new(0, 0, 0)
			animer(W.ecran, 0.3, { BackgroundColor3 = ecranOrigine }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0.08)
		end
		-- Les panneaux s'allument les uns après les autres, par colonne
		for i, cadre in panneaux do
			local echelle = cadre:FindFirstChildOfClass("UIScale")
			echelle.Scale = 0.92
			animer(echelle, 0.45, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0.12 + i * 0.045)
		end
		-- Ligne de balayage qui traverse l'écran
		W.balayageEcran.Position = UDim2.new(0, 0, 0, -4)
		animer(W.balayageEcran, 0.9, { Position = UDim2.new(0, 0, 1, 4) }, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0.15)
		UI.son("Notification")

		joueur:SetAttribute("TardisTablette", true)
		construireListe()
	end

	local function fermer(garderAttribut)
		if not S.ouvert then return end
		S.ouvert = false
		W.recherche:ReleaseFocus()
		animer(W.voile, 0.25, { BackgroundTransparency = 1 })
		animer(W.flou, 0.3, { Size = 0 })
		animer(W.echelle, 0.25, { Scale = echelleBase() * 0.9 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		animer(W.tablette, 0.25, { Position = UDim2.fromScale(0.5, 0.56) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.26, function()
			if S.ouvert then return end
			W.tablette.Visible = false
			W.voile.Visible = false
			W.flou.Enabled = false
		end)
		if not garderAttribut then joueur:SetAttribute("TardisTablette", false) end
	end

	W.fermer.Activated:Connect(function() fermer() end)
	-- Le voile ne ferme rien : seule la croix rouge en haut à droite ferme la tablette

	-- Boucliers
	W.boutonBoucliers.Activated:Connect(function()
		if W.boutonBoucliers:GetAttribute("Disponible") == false then return end
		W.choixBoucliers.Visible = not W.choixBoucliers.Visible
	end)

	-- Vol libre : la tablette se range pour laisser voir le TARDIS (tuile des systèmes, bouton VOL LIBRE de la vue
	-- Navigation et bouton de la vue Vol libre : la même action)
	for _, bouton in { W.tuiles.volLibre.bouton, W.boutonVolLibre, W.boutonLancerVol } do
		bouton.Activated:Connect(function()
			if bouton:GetAttribute("Disponible") == false then return end
			remote:FireServer("VolLibreDebut")
			task.delay(0.15, function() fermer() end)
		end)
	end


	joueur:GetAttributeChangedSignal("TardisTablette"):Connect(function()
		if joueur:GetAttribute("TardisTablette") then ouvrir() else fermer(true) end
	end)

	return { fermer = fermer, majDisposition = majDisposition, ouvrir = ouvrir }
end
