-- StarterPlayerScripts > TardisExtrasClient > ScannerTechnicien (ModuleScript)
-- (V6.9.13) Outils du technicien et nouvelles pannes, côté joueur :
--   • Scanner : l'outil en main, la pièce visée à la souris (jusqu'à Config.Technicien.ScannerPortee studs) est
--     encadrée et une bulle donne son état (grille, rotor, console, alimentation, cabine, fuite d'air, brèche, zone).
--     LECTURE SEULE : le scanner ne lit que les attributs publiés par le serveur et n'envoie rien.
--   • Effets visibles par tous à bord : jet d'air à l'endroit de la fuite, fumée et étincelles sur la brèche,
--     gerbe d'étincelles à chaque passage du soudeur (attribut SoudureTemps), lueur rouge du rotor quand on
--     essaie de partir rotor bloqué (attribut RotorTentative).
-- Toutes les pièces viennent de TardisConfig (Config.pieceEnPanne, Config.grillesDe), comme chez le serveur.

return function(contexte)
	local C, Config, UI, UserInputService = contexte.C, contexte.Config, contexte.UI, contexte.UserInputService
	local camera, creer, def, exterieur, interieur = contexte.camera, contexte.creer, contexte.def, contexte.exterieur, contexte.interieur
	local jeSuisDedans, joueur, texte = contexte.jeSuisDedans, contexte.joueur, contexte.texte
	local TECH = Config.Technicien or {}
	local S = Config.Systemes or {}

	local rotorObjet = interieur:FindFirstChild(Config.NomRotor or "Rotor")
	local rotorPart = Config.partDe(rotorObjet)
	local consoleObjet = interieur:FindFirstChild("Console")
	local grilles = Config.grillesDe(interieur)
	local levierObjet = interieur
	for _, nom in (Config.Chemins and Config.Chemins.Alimentation) or {} do levierObjet = levierObjet and levierObjet:FindFirstChild(nom) end
	if levierObjet == interieur then levierObjet = nil end

	local function dans(part, objet)
		return objet ~= nil and (part == objet or part:IsDescendantOf(objet))
	end
	local function entier(nom, defaut)
		return math.floor((tonumber(exterieur:GetAttribute(nom)) or defaut) + 0.5)
	end

	--------------------------------------------------------------------
	-- Ce que le scanner lit d'une pièce : un titre, des lignes, et si l'une d'elles signale une anomalie
	--------------------------------------------------------------------
	local function decrire(part)
		if typeof(part) ~= "Instance" or not part:IsA("BasePart") then return nil end
		local dedans, cabine = part:IsDescendantOf(interieur), part:IsDescendantOf(exterieur)
		if not (dedans or cabine) then return nil end
		local lignes, anomalie = {}, false
		local function ajouter(ligne, mauvais)
			table.insert(lignes, ligne)
			if mauvais then anomalie = true end
		end
		local titre = UI.majuscules(part.Name)
		local pv = entier("PointsDeVie", 100)
		if cabine then
			titre = "CABINE"
			local salete = entier("Salete", 0)
			ajouter(string.format("Saleté : %d %%", salete), salete >= 40)
			ajouter(string.format("Intégrité : %d %%", pv), pv < 60)
		elseif dans(part, rotorObjet) then
			titre = "ROTOR"
			ajouter(string.format("Intégrité : %d %%", pv), pv < 60)
			if exterieur:GetAttribute("Avarie") then ajouter("AVARIE : structure à 0 %", true) end
			if exterieur:GetAttribute("RotorBloque") then ajouter("BLOQUÉ : décollage impossible (maintenir E)", true) else ajouter("Rotor libre") end
		elseif dans(part, consoleObjet) then
			titre = "CONSOLE"
			if exterieur:GetAttribute("Incendie") then
				ajouter(exterieur:GetAttribute("IncendieEteint") and "Flammes éteintes : fermer la vanne" or "INCENDIE en cours", true)
			else
				ajouter("Aucun départ de feu")
			end
		elseif dans(part, levierObjet) then
			titre = "ALIMENTATION"
			if exterieur:GetAttribute("RedemarrageRequis") then ajouter("Coupure de sécurité : redémarrage requis", true)
			elseif exterieur:GetAttribute("Alimentation") == false then ajouter("HORS TENSION", true)
			else ajouter(string.format("Sous tension · énergie %d %%", entier("RegulEnergie", 80))) end
		else
			for numero, grille in grilles do
				if dans(part, grille) then
					titre = string.format("GRILLE N°%d", tonumber(grille:GetAttribute("TardisGrille")) or numero)
					local enPanne = Config.grilleEnPanne(exterieur, interieur, grilles)
					ajouter(enPanne == grille and "SURCHARGE DE VAPEUR : visseuse" or "Pression nominale", enPanne == grille)
					ajouter(string.format("Air : %d %%", entier("RegulAir", 100)), entier("RegulAir", 100) < (TECH.SeuilAirVicie or 25))
					break
				end
			end
		end
		if dedans then
			local fuite = Config.pieceEnPanne(exterieur, interieur, "FuiteAir")
			if fuite and dans(part, fuite) then ajouter("FUITE D'AIR : colmater (visseuse ou clé, maintenir E)", true) end
			local breche = Config.pieceEnPanne(exterieur, interieur, "Breche")
			if breche and dans(part, breche) then
				local total = math.max(math.floor(tonumber(S.SoudureEtapes) or 4), 1)
				ajouter(string.format("BRÈCHE : soudure %d / %d (soudeur)", math.floor(tonumber(exterieur:GetAttribute("BrecheAvancement")) or 0), total), true)
			end
			local zone = Config.zoneDe(interieur, part)
			if zone then ajouter("Zone : " .. tostring(zone)) end
		end
		if #lignes == 0 then ajouter("Aucune anomalie") end
		return titre, lignes, anomalie
	end

	--------------------------------------------------------------------
	-- Le scanner : bulle et cadre sur la pièce visée, tant que l'outil est en main
	--------------------------------------------------------------------
	local gui = creer("ScreenGui", { Name = "TardisScanner_" .. def.Nom, ResetOnSpawn = false, Parent = joueur:WaitForChild("PlayerGui") })
	local cadre = creer("SelectionBox", { Name = "TardisScannerCadre_" .. def.Nom, Color3 = C.cyan, LineThickness = 0.04, SurfaceTransparency = 1, Visible = false,
		Parent = gui.Parent })
	local bulle = creer("BillboardGui", { Name = "Bulle", Size = UDim2.fromOffset(250, 104), StudsOffset = Vector3.new(0, 2, 0), AlwaysOnTop = true,
		LightInfluence = 0, Enabled = false, Parent = gui })
	local fond = creer("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.fond, BackgroundTransparency = 0.12, Parent = bulle },
		{ UI.coin(10), UI.marges(8) })
	local contour = UI.contour(C.cyan, 1, 0.2)
	contour.Parent = fond
	local titreBulle = texte({ Name = "Titre", Text = "", Font = UI.POLICE_GRAS, TextSize = 13, TextColor3 = C.cyan, Size = UDim2.new(1, 0, 0, 16), Parent = fond })
	local corps = texte({ Name = "Lignes", Text = "", TextSize = 12, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 1, -20), Parent = fond })

	local function cacher()
		bulle.Enabled, bulle.Adornee = false, nil
		cadre.Visible, cadre.Adornee = false, nil
	end
	local function afficher(part)
		local titre, lignes, anomalie = decrire(part)
		if not titre then cacher() return end
		local couleur = anomalie and C.rouge or C.cyan
		titreBulle.Text = "◆  " .. titre
		titreBulle.TextColor3 = couleur
		corps.Text = table.concat(lignes, "\n")
		contour.Color = couleur
		cadre.Color3 = couleur
		bulle.Adornee, bulle.Enabled = part, true
		cadre.Adornee, cadre.Visible = part, true
	end
	local function scannerEnMain()
		local outil = joueur.Character and joueur.Character:FindFirstChild("Scanner")
		return outil ~= nil and outil:IsA("Tool")
	end
	local function viser()
		local portee = math.clamp(tonumber(TECH.ScannerPortee) or 30, 4, 200)
		local souris = UserInputService:GetMouseLocation()
		local rayon = camera:ViewportPointToRay(souris.X, souris.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { joueur.Character }
		local touche = workspace:Raycast(rayon.Origin, rayon.Direction * portee, params)
		return touche and touche.Instance or nil
	end
	task.spawn(function()
		while true do
			if scannerEnMain() then
				local ok, part = pcall(viser)
				if ok and part then afficher(part) else cacher() end
				task.wait(0.15)
			else
				if bulle.Enabled or cadre.Visible then cacher() end
				task.wait(0.4)
			end
		end
	end)

	--------------------------------------------------------------------
	-- Effets des nouvelles pannes (chez chaque joueur ; seul le serveur pose les attributs)
	--------------------------------------------------------------------
	local function eteindre(attache)
		for _, e in attache:GetDescendants() do
			if e:IsA("ParticleEmitter") then e.Enabled = false end
			if e:IsA("Smoke") then e.Enabled = false end
		end
		task.delay(2, function() attache:Destroy() end)
	end
	-- Une source d'effet qui suit la pièce d'une panne située (Config.pieceEnPanne) : refaite si la pièce change
	local function suivrePanne(cle, fabriquer)
		local actuel = nil -- { attache, part }
		local function maj()
			local part = (not exterieur:GetAttribute("Detruit")) and Config.pieceEnPanne(exterieur, interieur, cle) or nil
			if actuel and actuel.part ~= part then
				eteindre(actuel.attache)
				actuel = nil
			end
			if part and not actuel then
				local attache = creer("Attachment", { Name = "Tardis" .. cle, Position = Vector3.new(0, part.Size.Y / 2, 0), Parent = part })
				fabriquer(attache)
				actuel = { attache = attache, part = part }
			end
		end
		for _, nom in { cle, cle .. "Chemin", "Detruit" } do exterieur:GetAttributeChangedSignal(nom):Connect(maj) end
		maj()
	end
	suivrePanne("FuiteAir", function(attache)
		creer("ParticleEmitter", { Name = "JetAir", Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(Color3.fromRGB(235, 242, 255)),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) }),
			Size = NumberSequence.new(0.4, 2.2), Lifetime = NumberRange.new(0.6, 1), Speed = NumberRange.new(10, 14), SpreadAngle = Vector2.new(8, 8),
			EmissionDirection = Enum.NormalId.Top, Rate = 35, Rotation = NumberRange.new(0, 360), Parent = attache })
	end)
	suivrePanne("Breche", function(attache)
		creer("Smoke", { Name = "FumeeBreche", Color = Color3.fromRGB(70, 65, 60), Opacity = 0.25, RiseVelocity = 3, Size = 1.5, Parent = attache })
		creer("ParticleEmitter", { Name = "EtincellesBreche", Color = ColorSequence.new(Color3.fromRGB(255, 190, 90)), LightEmission = 1,
			Size = NumberSequence.new(0.12, 0), Lifetime = NumberRange.new(0.3, 0.6), Speed = NumberRange.new(6, 10), SpreadAngle = Vector2.new(40, 40),
			Acceleration = Vector3.new(0, -30, 0), Rate = 5, Parent = attache })
	end)
	-- Soudure : une gerbe d'étincelles bleutées et un éclair sur la brèche, à chaque passage du soudeur
	exterieur:GetAttributeChangedSignal("SoudureTemps"):Connect(function()
		local part = Config.pieceEnPanne(exterieur, interieur, "Breche") or Config.partDe(consoleObjet) or rotorPart
		if not (part and jeSuisDedans()) then return end
		local attache = creer("Attachment", { Name = "TardisSoudure", Position = Vector3.new(0, part.Size.Y / 2, 0), Parent = part })
		local gerbe = creer("ParticleEmitter", { Color = ColorSequence.new(Color3.fromRGB(190, 225, 255)), LightEmission = 1, Size = NumberSequence.new(0.15, 0),
			Lifetime = NumberRange.new(0.2, 0.5), Speed = NumberRange.new(10, 18), SpreadAngle = Vector2.new(70, 70), Acceleration = Vector3.new(0, -40, 0),
			Rate = 0, Parent = attache })
		gerbe:Emit(30)
		creer("PointLight", { Color = Color3.fromRGB(170, 210, 255), Brightness = 4, Range = 10, Parent = attache })
		task.delay(0.25, function() local lumiere = attache:FindFirstChildOfClass("PointLight") if lumiere then lumiere.Enabled = false end end)
		task.delay(1.5, function() attache:Destroy() end)
	end)
	-- Rotor bloqué : le rotor rougeoie un instant quand on tente de partir
	exterieur:GetAttributeChangedSignal("RotorTentative"):Connect(function()
		if not (rotorPart and exterieur:GetAttribute("RotorTentative") and jeSuisDedans()) then return end
		local lumiere = creer("PointLight", { Name = "TardisRotorBloque", Color = C.rouge, Brightness = 3, Range = 12, Parent = rotorPart })
		task.delay(1.2, function() lumiere:Destroy() end)
	end)

	return { decrire = decrire }
end
