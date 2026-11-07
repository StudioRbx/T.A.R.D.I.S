-- StarterPlayerScripts > TardisExtrasClient > Decor (ModuleScript)
-- Terrain réactif, décorations et reflets des vitres ; (V7.2.2) gerbe du sol aussi au départ, vent du décollage
-- Extrait du script principal en V6.6.3 : reçoit ce qu'il utilise, renvoie ce que la suite utilise.

-- (V7.2.2, G-23) Vent du décollage, partagé par tous les TARDIS du joueur (le module n'est chargé qu'une fois)
local VENT = { base = nil, ecrit = nil, poussees = {} }

return function(contexte)
	local Config, RunService, creer, exterieur, lampe, partTemporaire = contexte.Config, contexte.RunService, contexte.creer, contexte.exterieur, contexte.lampe, contexte.partTemporaire
	local secouer = contexte.secouer

	--------------------------------------------------------------------
	-- 20) Terrain réactif : l'effet d'atterrissage dépend du sol (sable, neige, métal, herbe, eau, pierre...)
	--------------------------------------------------------------------
	-- (V7.2.2, G-21) force : 1 à l'atterrissage, 0,5 au départ (gerbe plus petite, ni vapeur ni secousse)
	local function gerbe(materiau, force)
		local base = exterieur:GetPivot().Position - Vector3.new(0, (exterieur.PrimaryPart and exterieur.PrimaryPart.Size.Y / 2 or 0) - 0.2, 0)
		local taille = exterieur:GetExtentsSize()
		local support = partTemporaire({ Name = "TardisTerrain", Transparency = 1, Size = Vector3.new(taille.X * 1.4, 0.4, taille.Z * 1.4), CFrame = CFrame.new(base) })
		local function emetteur(proprietes)
			proprietes.Parent = support
			proprietes.Rate = 0
			local e = creer("ParticleEmitter", proprietes)
			return e
		end
		local chaud = materiau == "Metal" or materiau == "DiamondPlate" or materiau == "CorrodedMetal" or materiau == "Basalt" or materiau == "CrackedLava"
		if materiau == "Sand" or materiau == "Sandstone" then
			emetteur({ Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(Color3.fromRGB(225, 200, 150)), Size = NumberSequence.new(2, 7),
				Transparency = NumberSequence.new(0.4, 1), Lifetime = NumberRange.new(1.5, 2.5), Speed = NumberRange.new(10, 18), SpreadAngle = Vector2.new(60, 60) }):Emit(math.ceil(70 * force))
		elseif materiau == "Snow" or materiau == "Ice" or materiau == "Glacier" then
			emetteur({ Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(Color3.fromRGB(250, 252, 255)), Size = NumberSequence.new(1.5, 5),
				Transparency = NumberSequence.new(0.2, 1), Lifetime = NumberRange.new(1.5, 3), Speed = NumberRange.new(6, 12), SpreadAngle = Vector2.new(70, 70),
				Acceleration = Vector3.new(0, -4, 0) }):Emit(math.ceil(90 * force))
		elseif chaud then
			-- Métal ou sol chaud : étincelles, "clang", et vapeur qui monte
			emetteur({ Color = ColorSequence.new(Color3.fromRGB(255, 230, 150), Color3.fromRGB(255, 120, 30)), LightEmission = 1, Size = NumberSequence.new(0.25, 0),
				Speed = NumberRange.new(12, 24), Lifetime = NumberRange.new(0.3, 0.7), SpreadAngle = Vector2.new(70, 70), Acceleration = Vector3.new(0, -40, 0) }):Emit(math.ceil(60 * force))
			local vapeur = emetteur({ Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(Color3.fromRGB(235, 240, 245)), Size = NumberSequence.new(2, 6),
				Transparency = NumberSequence.new(0.6, 1), Lifetime = NumberRange.new(1, 2), Speed = NumberRange.new(4, 8), SpreadAngle = Vector2.new(20, 20) })
			vapeur.Rate = force >= 1 and 40 or 0
			task.delay(2.5, function() vapeur.Enabled = false end)
			if force >= 1 then secouer(0.3) end
		elseif materiau == "Grass" or materiau == "LeafyGrass" or materiau == "Ground" or materiau == "Mud" then
			emetteur({ Color = ColorSequence.new(Color3.fromRGB(90, 140, 60), Color3.fromRGB(60, 90, 40)), Size = NumberSequence.new(0.3, 0.1), Speed = NumberRange.new(8, 16),
				Lifetime = NumberRange.new(0.8, 1.5), SpreadAngle = Vector2.new(60, 60), Acceleration = Vector3.new(0, -25, 0) }):Emit(math.ceil(50 * force))
		elseif materiau ~= "Water" then
			emetteur({ Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(Color3.fromRGB(170, 165, 160)), Size = NumberSequence.new(2, 5),
				Transparency = NumberSequence.new(0.5, 1), Lifetime = NumberRange.new(1, 2), Speed = NumberRange.new(8, 14), SpreadAngle = Vector2.new(60, 60) }):Emit(math.ceil(40 * force))
		end
		task.delay(5, function() support:Destroy() end)
	end
	exterieur:GetAttributeChangedSignal("TerrainTemps"):Connect(function()
		gerbe(exterieur:GetAttribute("TerrainAtterrissage") or "", 1)
	end)
	-- (V7.2.2, G-21) Au départ, la même gerbe (plus petite) part quand la cabine commence à s'effacer, après le silence du son.
	-- Le sol est celui de la dernière arrivée (TerrainAtterrissage). Rien en Silencieux, camouflée, portée, en vol libre ou sur l'eau.
	exterieur:GetAttributeChangedSignal("Etat"):Connect(function()
		if (Config.Effets or {}).TerrainDepart == false or exterieur:GetAttribute("Etat") ~= Config.Etats.Demat then return end
		if exterieur:GetAttribute("Camouflage") == true or exterieur:GetAttribute("Porteur") ~= nil or exterieur:GetAttribute("VolLibre") ~= nil
			or exterieur:GetAttribute("SurEau") == true then return end
		local mode = Config.modeDe(exterieur)
		if (Config.Modes[Config.normaliserMode(mode)] or {}).Discret then return end
		local materiau = exterieur:GetAttribute("TerrainAtterrissage")
		if not materiau or materiau == "Inconnu" then return end
		local debut = exterieur:GetAttribute("DebutEtat")
		local _, decalage = Config.Timing(Config.Etats.Demat, mode)
		task.delay(decalage, function()
			if exterieur:GetAttribute("Etat") == Config.Etats.Demat and exterieur:GetAttribute("DebutEtat") == debut then gerbe(materiau, 0.5) end
		end)
	end)

	--------------------------------------------------------------------
	-- 20 bis) Vent du décollage (V7.2.2, G-23) : pour les joueurs proches, workspace.GlobalWind est poussé pendant les
	-- souffles (l'herbe du Terrain et les particules sensibles au vent s'agitent autour de la cabine), puis il revient
	-- à sa valeur. Si un autre script change le vent entre-temps, c'est sa valeur qui est gardée.
	--------------------------------------------------------------------
	do
		RunService.Heartbeat:Connect(function()
			local etat = exterieur:GetAttribute("Etat")
			local camera = workspace.CurrentCamera
			local force = 0
			if camera and (etat == Config.Etats.Demat or etat == Config.Etats.Remat) and exterieur:GetAttribute("Camouflage") ~= true then
				local mode = Config.modeDe(exterieur)
				if not (Config.Modes[Config.normaliserMode(mode)] or {}).Discret then
					local duree, decalage = Config.Timing(etat, mode)
					local ecoule = workspace:GetServerTimeNow() - (exterieur:GetAttribute("DebutEtat") or 0)
					force = Config.ventDecollage((camera.CFrame.Position - exterieur:GetPivot().Position).Magnitude, ecoule, duree, decalage)
				end
			end
			-- Chaque TARDIS range sa poussée dans la table partagée ; le vent écrit est la base + la somme des poussées
			-- (deux TARDIS qui décollent ensemble ne s'emballent pas l'un l'autre)
			if force > 0.05 then
				local dehors = (camera.CFrame.Position - exterieur:GetPivot().Position) * Vector3.new(1, 0, 1)
				dehors = dehors.Magnitude > 0.1 and dehors.Unit or Vector3.new(1, 0, 0)
				VENT.poussees[exterieur] = dehors * force
			else
				VENT.poussees[exterieur] = nil
			end
			local total, actif = Vector3.zero, false
			for _, v in VENT.poussees do total += v actif = true end
			if actif then
				if VENT.base == nil or (workspace.GlobalWind - VENT.ecrit).Magnitude > 0.01 then VENT.base = workspace.GlobalWind end
				VENT.ecrit = VENT.base + total
				workspace.GlobalWind = VENT.ecrit
			elseif VENT.base ~= nil then
				if (workspace.GlobalWind - VENT.ecrit).Magnitude <= 0.01 then workspace.GlobalWind = VENT.base end
				VENT.base, VENT.ecrit = nil, nil
			end
		end)
	end

	--------------------------------------------------------------------
	-- 21) Décorations (Noël : guirlandes et neige ; Halloween : citrouille sur la lampe) et reflets des vitres
	--------------------------------------------------------------------
	do
		local pieces = {}       -- pièces locales de la décoration, avec leur décalage par rapport au pivot
		local emetteur = nil
		local decorationActive = nil
		local function nettoyer()
			for _, p in pieces do p.part:Destroy() end
			table.clear(pieces)
			if emetteur then emetteur.Parent:Destroy() emetteur = nil end
		end
		local function construire(nom)
			nettoyer()
			decorationActive = nom
			if not nom then return end
			local pivot = exterieur:GetPivot()
			local taille = exterieur:GetExtentsSize()
			local racineHalf = exterieur.PrimaryPart and exterieur.PrimaryPart.Size.Y / 2 or 0.5
			local haut = taille.Y - racineHalf - 0.3
			local function ajouter(part, decalage) table.insert(pieces, { part = part, decalage = decalage }) end
			if nom == "Noel" then
				-- Guirlande : des ampoules colorées tout autour du toit
				local couleurs = { Color3.fromRGB(255, 60, 60), Color3.fromRGB(60, 255, 90), Color3.fromRGB(255, 220, 60), Color3.fromRGB(80, 140, 255) }
				local n = 0
				local dx, dz = taille.X / 2 + 0.15, taille.Z / 2 + 0.15
				for i = 0, 19 do
					local f = i / 20
					local x, z
					if f < 0.25 then x, z = -dx + f * 4 * 2 * dx, -dz
					elseif f < 0.5 then x, z = dx, -dz + (f - 0.25) * 4 * 2 * dz
					elseif f < 0.75 then x, z = dx - (f - 0.5) * 4 * 2 * dx, dz
					else x, z = -dx, dz - (f - 0.75) * 4 * 2 * dz end
					n += 1
					local ampoule = partTemporaire({ Name = "TardisDecoration", Shape = Enum.PartType.Ball, Material = Enum.Material.Neon,
						Color = couleurs[n % #couleurs + 1], Size = Vector3.new(0.35, 0.35, 0.35), CFrame = pivot * CFrame.new(x, haut, z) })
					creer("PointLight", { Color = ampoule.Color, Brightness = 1.5, Range = 5, Parent = ampoule })
					ajouter(ampoule, CFrame.new(x, haut, z))
				end
				-- Neige qui tombe autour de la cabine
				local support = partTemporaire({ Name = "TardisNeige", Transparency = 1, Size = Vector3.new(taille.X + 14, 0.5, taille.Z + 14),
					CFrame = pivot * CFrame.new(0, taille.Y + 8, 0) })
				emetteur = creer("ParticleEmitter", { Color = ColorSequence.new(Color3.new(1, 1, 1)), Size = NumberSequence.new(0.25, 0.15),
					Transparency = NumberSequence.new(0.1, 0.6), Lifetime = NumberRange.new(4, 6), Speed = NumberRange.new(2, 3), Rate = 25,
					EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(15, 15), Acceleration = Vector3.new(0, -1, 0), Parent = support })
				ajouter(support, CFrame.new(0, taille.Y + 8, 0))
			elseif nom == "Halloween" then
				-- Citrouille sur la lampe du toit
				local positionLampe = CFrame.new(0, haut + 1.2, 0)
				if lampe then positionLampe = pivot:ToObjectSpace(lampe.CFrame) * CFrame.new(0, lampe.Size.Y / 2 + 0.7, 0) end
				local citrouille = partTemporaire({ Name = "TardisDecoration", Shape = Enum.PartType.Ball, Material = Enum.Material.SmoothPlastic,
					Color = Color3.fromRGB(255, 120, 20), Size = Vector3.new(1.6, 1.3, 1.6), CFrame = pivot * positionLampe })
				creer("PointLight", { Color = Color3.fromRGB(255, 140, 30), Brightness = 2.5, Range = 10, Parent = citrouille })
				ajouter(citrouille, positionLampe)
				local tige = partTemporaire({ Name = "TardisDecoration", Shape = Enum.PartType.Cylinder, Material = Enum.Material.Grass,
					Color = Color3.fromRGB(70, 110, 40), Size = Vector3.new(0.5, 0.25, 0.25), CFrame = pivot * positionLampe * CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, math.pi / 2) })
				ajouter(tige, positionLampe * CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, math.pi / 2))
				-- Les yeux et la bouche, découpés en noir
				for _, decalage in { CFrame.new(-0.35, 0.15, -0.75), CFrame.new(0.35, 0.15, -0.75), CFrame.new(0, -0.3, -0.78) } do
					local trait = partTemporaire({ Name = "TardisDecoration", Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 230, 120),
						Size = decalage.Y < 0 and Vector3.new(0.8, 0.15, 0.1) or Vector3.new(0.25, 0.25, 0.1), CFrame = pivot * positionLampe * decalage })
					ajouter(trait, positionLampe * decalage)
				end
			end
		end
		RunService.RenderStepped:Connect(function()
			local nom = exterieur:GetAttribute("Decoration")
			if nom ~= decorationActive then construire(nom) end
			if #pieces == 0 then return end
			local pivot = exterieur:GetPivot()
			local t = os.clock()
			for i, p in pieces do
				p.part.CFrame = pivot * p.decalage
				if decorationActive == "Noel" and p.part.Name == "TardisDecoration" then
					p.part.Transparency = (math.floor(t * 2 + i) % 3 == 0) and 0.7 or 0 -- clignotement
				end
			end
		end)

		-- Reflets des vitres : les fenêtres prennent la lumière de l'intérieur (couleur du thème) et deviennent réfléchissantes
		local vitres = {} -- [part] = { materiau, couleur, reflectance }
		for _, objet in exterieur:GetDescendants() do
			if objet:IsA("BasePart") and objet ~= exterieur.PrimaryPart and objet.Name ~= (Config.NomPortailExt or "Portail")
				and (objet.Material == Enum.Material.Glass or (objet.Transparency > 0.1 and objet.Transparency < 0.95)) then
				vitres[objet] = { materiau = objet.Material, couleur = objet.Color, reflectance = objet.Reflectance }
			end
		end
		local function majReflets()
			local actif = exterieur:GetAttribute("Reflets") == true
			local theme = nil
			for _, th in Config.Themes or {} do
				if th.nom == exterieur:GetAttribute("Theme") then theme = th end
			end
			local lumiere = theme and theme.leds or Color3.fromRGB(255, 220, 160)
			for part, origine in vitres do
				if part.Parent then
					part.Material = actif and Enum.Material.Glass or origine.materiau
					part.Reflectance = actif and 0.5 or origine.reflectance
					part.Color = actif and origine.couleur:Lerp(lumiere, 0.45) or origine.couleur
				end
			end
		end
		exterieur:GetAttributeChangedSignal("Reflets"):Connect(majReflets)
		exterieur:GetAttributeChangedSignal("Theme"):Connect(majReflets)
		majReflets()
	end

	return {}
end
