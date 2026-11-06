-- StarterPlayerScripts > TardisExtrasClient > SousTitres (ModuleScript) — V6.9.15 (proposition 190)
-- Sous-titres des sons importants : un bandeau en bas de l'écran écrit ce qu'on entend, pour les joueurs qui jouent
-- sans le son (ou sourds et malentendants) :
--   [Dématérialisation] / [Matérialisation] (avec le mode s'il n'est pas Classique), voyage ou vol libre ;
--   [Alarme du TARDIS] (alerte générale, à bord) ; [Alarme d'auto-destruction] ; [Explosion] ;
--   [Musique : nom de la piste] (jukebox, à bord).
-- Les sons de la cabine sont sous-titrés à bord, ou dehors à moins de Config.SousTitres.Portee studs ; ceux de la salle
-- (alarme, musique) seulement à bord. Rien en mode Silencieux : il ne fait aucun son.
-- Tout est local et en lecture seule (attributs posés par le serveur) ; option « Sous-titres des sons » des réglages.

return function(contexte)
	local C, Config, E, UI = contexte.C, contexte.Config, contexte.E, contexte.UI
	local creer, texte, def, exterieur, joueur = contexte.creer, contexte.texte, contexte.def, contexte.exterieur, contexte.joueur
	local jeSuisDedans, maRacine = contexte.jeSuisDedans, contexte.maRacine
	local REGLAGES = Config.SousTitres or {}
	local TEXTES = REGLAGES.Textes or {}

	local gui = creer("ScreenGui", { Name = "TardisSousTitres_" .. def.Nom, ResetOnSpawn = false, DisplayOrder = 13, IgnoreGuiInset = true,
		Parent = joueur:WaitForChild("PlayerGui") })
	local cadre = creer("Frame", { Name = "SousTitre", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -96), Size = UDim2.fromOffset(0, 34),
		AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = C.fond, BackgroundTransparency = 0.2, Visible = false, Parent = gui },
	{ UI.coin(6), UI.contour(C.cyan, 1, 0.5), creer("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }) })
	local etiquette = texte({ Name = "Texte", Text = "", Font = UI.POLICE_GRAS, TextSize = 17, TextColor3 = C.texte, TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, Parent = cadre })
	UI.suivreTaille(cadre) -- (proposition 72 : suit la taille de l'interface)

	-- À portée d'oreille : à bord, ou (sons de la cabine) dehors près d'elle
	local function aPortee(salleSeulement)
		if jeSuisDedans() then return true end
		if salleSeulement then return false end
		local proche = false
		pcall(function()
			local racine = maRacine()
			if not racine then return end
			local a, b = racine.Position, exterieur:GetPivot().Position
			local dx, dy, dz = a.X - b.X, a.Y - b.Y, a.Z - b.Z
			proche = math.sqrt(dx * dx + dy * dy + dz * dz) <= (tonumber(REGLAGES.Portee) or 120)
		end)
		return proche
	end

	local jeton = 0
	local function afficher(cle, salleSeulement, valeur)
		if REGLAGES.Actif == false or not UI.sousTitres() then return end
		local modele = TEXTES[cle]
		if type(modele) ~= "string" or not aPortee(salleSeulement) then return end
		local ok, phrase = pcall(string.format, modele, tostring(valeur or ""))
		etiquette.Text = ok and phrase or modele
		cadre.Visible = true
		jeton += 1
		local moi = jeton
		task.delay(tonumber(REGLAGES.Duree) or 4, function()
			if moi == jeton then cadre.Visible = false end
		end)
	end
	-- « · Urgence » après Dématérialisation, sauf en Classique ; nil en Silencieux (pas de son, pas de sous-titre)
	local function suffixeMode(mode)
		local reglages = Config.Modes[mode] or {}
		if reglages.Discret == true then return nil end
		if mode == "Normal" then return "" end
		return " · " .. Config.libelleMode(mode)
	end
	local function voyage(quoi, mode)
		local suffixe = suffixeMode(mode)
		if suffixe == nil then return end
		if quoi == E.Demat then afficher("Demat", false, suffixe) elseif quoi == E.Remat then afficher("Remat", false, suffixe) end
	end

	exterieur:GetAttributeChangedSignal("Etat"):Connect(function()
		voyage(exterieur:GetAttribute("Etat"), Config.modeDe(exterieur))
	end)
	-- Démat / remat du vol libre
	exterieur:GetAttributeChangedSignal("VolPhase"):Connect(function()
		voyage(exterieur:GetAttribute("VolPhase"), Config.modeVolDe(exterieur))
	end)
	exterieur:GetAttributeChangedSignal("Alerte"):Connect(function()
		if exterieur:GetAttribute("Alerte") == true then afficher("Alarme", true) end
	end)
	exterieur:GetAttributeChangedSignal("AutoDestructionDebut"):Connect(function()
		if exterieur:GetAttribute("AutoDestructionDebut") then afficher("AutoDestruction", false) end
	end)
	exterieur:GetAttributeChangedSignal("Explosion"):Connect(function()
		if exterieur:GetAttribute("Explosion") then afficher("Explosion", false) end
	end)
	-- Jukebox : un numéro de piste, ou le nom d'une catégorie (playlist)
	exterieur:GetAttributeChangedSignal("Jukebox"):Connect(function()
		local valeur = exterieur:GetAttribute("Jukebox")
		if valeur == nil then return end
		local nom = nil
		if type(valeur) == "number" then
			local ok, pistes = pcall(Config.pistesJukebox)
			local piste = ok and type(pistes) == "table" and pistes[valeur] or nil
			nom = type(piste) == "table" and piste.nom ~= nil and tostring(piste.nom) or ("piste " .. tostring(valeur))
		else
			nom = "playlist " .. tostring(valeur)
		end
		afficher("Musique", true, nom)
	end)

	return { afficher = afficher }
end
