-- StarterPlayerScripts > TardisExtrasClient > Decor (ModuleScript)
-- Terrain réactif, décorations et reflets des vitres ; (V7.2.2) gerbe du sol aussi au départ, vent du décollage
-- (V7.2.4) décorations selon la date, Pâques, Nouvel An, anniversaire, salle décorée, neige ou feuilles sur le toit, éclair pendant l'orage
-- Extrait du script principal en V6.6.3 : reçoit ce qu'il utilise, renvoie ce que la suite utilise.

-- (V7.2.2, G-23) Vent du décollage, partagé par tous les TARDIS du joueur (le module n'est chargé qu'une fois)
local VENT = { base = nil, ecrit = nil, poussees = {} }

return function(contexte)
	local Config, RunService, creer, exterieur, lampe, partTemporaire = contexte.Config, contexte.RunService, contexte.creer, contexte.exterieur, contexte.lampe, contexte.partTemporaire
	local secouer = contexte.secouer
	local UI, interieur, boiteInt, ReplicatedStorage = contexte.UI, contexte.interieur, contexte.boiteInt, contexte.ReplicatedStorage -- (V7.2.4)
	local function sansFlash() return UI ~= nil and UI.sansFlash ~= nil and UI.sansFlash() == true end
	local function effetsReduits() return UI ~= nil and UI.effetsReduits ~= nil and UI.effetsReduits() == true end

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
	-- (V7.2.4) Pâques, Nouvel An, anniversaire ; en « Auto » la date choisit (C-186) ; Noël et Halloween décorent aussi la salle (G-190)
	--------------------------------------------------------------------
	do
		local pieces = {}       -- pièces locales de la décoration, avec leur décalage par rapport au pivot
		local piecesSalle = {}  -- (V7.2.4, G-190) pièces locales de la salle (immobiles)
		local emetteur = nil
		local decorationActive = nil
		local voulue, prochainCalcul = nil, 0 -- (V7.2.4, C-186) décoration voulue, recalculée une fois par seconde
		local prochainFeu = 0                  -- (V7.2.4, G-100) prochain feu d'artifice du Nouvel An
		local function nettoyer()
			for _, p in pieces do p.part:Destroy() end
			table.clear(pieces)
			for _, p in piecesSalle do p:Destroy() end
			table.clear(piecesSalle)
			if emetteur then emetteur.Parent:Destroy() emetteur = nil end
		end
		exterieur:GetAttributeChangedSignal("Decoration"):Connect(function() prochainCalcul = 0 end)
		-- (G-190) Centre et taille de la console (sinon le centre de la salle)
		local function console()
			local objet = interieur and interieur:FindFirstChild("Console")
			if objet and objet:IsA("Model") then return objet:GetBoundingBox() end
			if objet and objet:IsA("BasePart") then return objet.CFrame, objet.Size end
			if boiteInt then return boiteInt, Vector3.new(8, 4, 8) end
			return nil, nil
		end
		local function decorerSalle(nom)
			if (Config.Saisons or {}).Salle == false or (nom ~= "Noel" and nom ~= "Halloween") then return end
			local centre, taille = console()
			if not centre then return end
			local rayon = math.max(taille.X, taille.Z) / 2 + (nom == "Noel" and 1.5 or 3)
			local bas = centre.Position.Y - taille.Y / 2
			if nom == "Noel" then
				-- Guirlande lumineuse en cercle au-dessus de la console
				local couleurs = { Color3.fromRGB(255, 60, 60), Color3.fromRGB(60, 255, 90), Color3.fromRGB(255, 220, 60), Color3.fromRGB(80, 140, 255) }
				for i = 1, 24 do
					local angle = i / 24 * math.pi * 2
					local ampoule = partTemporaire({ Name = "TardisDecorationSalle", Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = couleurs[i % #couleurs + 1],
						Size = Vector3.new(0.35, 0.35, 0.35), CFrame = CFrame.new(centre.Position.X + math.cos(angle) * rayon, bas + taille.Y + 0.4, centre.Position.Z + math.sin(angle) * rayon) })
					if i % 3 == 0 then creer("PointLight", { Color = ampoule.Color, Brightness = 1, Range = 6, Parent = ampoule }) end
					table.insert(piecesSalle, ampoule)
				end
			else
				-- Citrouilles au sol autour de la console, avec une lueur orange
				for i = 1, 4 do
					local angle = (i - 0.5) / 4 * math.pi * 2
					local citrouille = partTemporaire({ Name = "TardisDecorationSalle", Shape = Enum.PartType.Ball, Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(255, 120, 20),
						Size = Vector3.new(1.4, 1.4, 1.4), CFrame = CFrame.new(centre.Position.X + math.cos(angle) * rayon, bas + 0.7, centre.Position.Z + math.sin(angle) * rayon) })
					creer("PointLight", { Color = Color3.fromRGB(255, 140, 30), Brightness = 2, Range = 12, Parent = citrouille })
					table.insert(piecesSalle, citrouille)
				end
			end
		end
		-- (G-100) Position f (0 à 1) sur le tour du toit : x, z et l'angle qui regarde dehors
		local function contour(f, dx, dz)
			if f < 0.25 then return -dx + f * 8 * dx, -dz, 0 end
			if f < 0.5 then return dx, -dz + (f - 0.25) * 8 * dz, -math.pi / 2 end
			if f < 0.75 then return dx - (f - 0.5) * 8 * dx, dz, math.pi end
			return -dx, dz - (f - 0.75) * 8 * dz, math.pi / 2
		end
		-- (G-100) Un petit feu d'artifice local au-dessus du toit (Nouvel An)
		local function feuDArtifice()
			local taille = exterieur:GetExtentsSize()
			local position = exterieur:GetPivot().Position + Vector3.new((math.random() - 0.5) * 6, taille.Y + 6 + math.random() * 4, (math.random() - 0.5) * 6)
			local support = partTemporaire({ Name = "TardisFeu", Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(position) })
			local couleurs = { Color3.fromRGB(255, 80, 80), Color3.fromRGB(255, 210, 70), Color3.fromRGB(90, 200, 255), Color3.fromRGB(180, 110, 255), Color3.fromRGB(120, 255, 140) }
			creer("ParticleEmitter", { Color = ColorSequence.new(couleurs[math.random(1, #couleurs)]), LightEmission = 1, Size = NumberSequence.new(0.3, 0),
				Speed = NumberRange.new(8, 14), Lifetime = NumberRange.new(0.6, 1.2), SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, -10, 0),
				Rate = 0, Parent = support }):Emit(effetsReduits() and 15 or 40)
			creer("PointLight", { Color = Color3.fromRGB(255, 230, 180), Brightness = 2, Range = 16, Parent = support })
			task.delay(2, function() support:Destroy() end)
		end
		local function construire(nom)
			nettoyer()
			decorationActive = nom
			if not nom then return end
			decorerSalle(nom) -- (V7.2.4, G-190)
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
			elseif nom == "Paques" then
				-- (V7.2.4, G-100) Oeufs de couleur posés sur le toit
				local couleurs = { Color3.fromRGB(255, 170, 200), Color3.fromRGB(170, 220, 255), Color3.fromRGB(255, 240, 150), Color3.fromRGB(180, 240, 170), Color3.fromRGB(220, 180, 255) }
				local dx, dz = taille.X / 2 - 0.5, taille.Z / 2 - 0.5
				for i, position in { Vector3.new(-dx, 0, -dz), Vector3.new(dx, 0, -dz), Vector3.new(dx, 0, dz), Vector3.new(-dx, 0, dz), Vector3.new(0, 0, -dz), Vector3.new(0, 0, dz) } do
					local decalage = CFrame.new(position.X, haut + 0.7, position.Z) * CFrame.Angles(0, i, 0.25)
					local oeuf = partTemporaire({ Name = "TardisDecoration", Material = Enum.Material.SmoothPlastic, Color = couleurs[(i - 1) % #couleurs + 1],
						Size = Vector3.new(0.55, 0.8, 0.55), CFrame = pivot * decalage })
					creer("SpecialMesh", { MeshType = Enum.MeshType.Sphere, Parent = oeuf }) -- forme d'oeuf (sphère étirée)
					ajouter(oeuf, decalage)
				end
			elseif nom == "NouvelAn" then
				-- (V7.2.4, G-100) Petites fusées dorées aux coins du toit ; un feu d'artifice part de temps en temps (boucle plus bas)
				local dx, dz = taille.X / 2 - 0.3, taille.Z / 2 - 0.3
				for _, position in { Vector3.new(-dx, 0, -dz), Vector3.new(dx, 0, -dz), Vector3.new(dx, 0, dz), Vector3.new(-dx, 0, dz) } do
					local decalage = CFrame.new(position.X, haut + 0.9, position.Z) * CFrame.Angles(0, 0, math.pi / 2)
					local fusee = partTemporaire({ Name = "TardisDecoration", Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 200, 70),
						Size = Vector3.new(1.2, 0.3, 0.3), CFrame = pivot * decalage })
					ajouter(fusee, decalage)
				end
				prochainFeu = os.clock() + 1
			elseif nom == "Anniversaire" then
				-- (V7.2.4, G-100) Guirlande de fanions de couleur tout autour du toit
				local couleurs = { Color3.fromRGB(255, 90, 90), Color3.fromRGB(255, 210, 60), Color3.fromRGB(90, 200, 255), Color3.fromRGB(150, 230, 120), Color3.fromRGB(220, 130, 255) }
				local dx, dz = taille.X / 2 + 0.1, taille.Z / 2 + 0.1
				for i = 0, 15 do
					local x, z, angle = contour(i / 16, dx, dz)
					local decalage = CFrame.new(x, haut - 0.3, z) * CFrame.Angles(0, angle, 0) * CFrame.Angles(0, 0, math.pi / 4)
					local fanion = partTemporaire({ Name = "TardisDecoration", Material = Enum.Material.SmoothPlastic, Color = couleurs[i % #couleurs + 1],
						Size = Vector3.new(0.5, 0.5, 0.05), CFrame = pivot * decalage })
					ajouter(fanion, decalage)
				end
			end
		end
		RunService.RenderStepped:Connect(function()
			local t = os.clock()
			if t >= prochainCalcul then
				prochainCalcul = t + 1
				voulue = Config.decorationEffective(exterieur:GetAttribute("Decoration"), workspace:GetServerTimeNow())
			end
			if voulue ~= decorationActive then construire(voulue) end
			-- (G-100) Feu d'artifice du Nouvel An : toutes les 3 s (6 s en « effets réduits »), jamais en « aucun flash » ni camouflée
			if decorationActive == "NouvelAn" and t >= prochainFeu then
				prochainFeu = t + (effetsReduits() and 6 or 3)
				if not sansFlash() and exterieur:GetAttribute("Camouflage") ~= true then feuDArtifice() end
			end
			if decorationActive == "Noel" then
				for i, p in piecesSalle do p.Transparency = (math.floor(t * 2 + i) % 3 == 0) and 0.7 or 0 end -- (G-190) la guirlande de la salle clignote aussi
			end
			if #pieces == 0 then return end
			local pivot = exterieur:GetPivot()
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

	--------------------------------------------------------------------
	-- 21 bis) (V7.2.4, G-32) Neige ou feuilles sur le toit : posée sur la neige ou sous un arbre, la cabine se couvre peu à peu
	-- d'une fine couche (Saisons.ToitNeige secondes pour une couche pleine) ; au début de la démat, elle glisse du toit et tombe.
	--------------------------------------------------------------------
	do
		local couche = nil      -- { type, debut, haut, parts = { { part, decalage } } }
		local chutes = {}       -- pièces qui glissent : { part, vitesse, fin }
		local prochainTest, testeDebut = 0, nil
		local function vider(glisser)
			if not couche then return end
			for _, p in couche.parts do
				if glisser and p.part.Transparency < 0.95 then
					local angle = math.random() * math.pi * 2
					local dehors = p.decalage.Position * Vector3.new(1, 0, 1)
					dehors = dehors.Magnitude > 0.3 and dehors.Unit or Vector3.new(math.cos(angle), 0, math.sin(angle))
					table.insert(chutes, { part = p.part, vitesse = dehors * (4 + math.random() * 3) + Vector3.new(0, 2, 0), fin = os.clock() + 2.5 })
					if couche.type == "Neige" then
						creer("ParticleEmitter", { Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(Color3.fromRGB(250, 252, 255)),
							Size = NumberSequence.new(1, 3), Transparency = NumberSequence.new(0.3, 1), Lifetime = NumberRange.new(0.8, 1.5), Speed = NumberRange.new(2, 5),
							SpreadAngle = Vector2.new(60, 60), Rate = 0, Parent = p.part }):Emit(effetsReduits() and 10 or 30)
					end
				else
					p.part:Destroy()
				end
			end
			couche = nil
		end
		local function sousUnArbre(haut)
			local parametres = RaycastParams.new()
			parametres.FilterType = Enum.RaycastFilterType.Exclude
			parametres.FilterDescendantsInstances = { exterieur }
			local touche = workspace:Raycast(exterieur:GetPivot().Position + Vector3.new(0, haut + 0.5, 0), Vector3.new(0, 40, 0), parametres)
			return touche ~= nil and Config.estArbre(touche.Instance and touche.Instance.Name, touche.Material and touche.Material.Name)
		end
		local function construireCouche(genre, haut)
			local pivot = exterieur:GetPivot()
			local taille = exterieur:GetExtentsSize()
			couche = { type = genre, debut = os.clock(), haut = haut, parts = {} }
			if genre == "Neige" then
				local decalage = CFrame.new(0, haut + 0.05, 0)
				local part = partTemporaire({ Name = "TardisCoucheToit", Material = Enum.Material.Snow, Color = Color3.fromRGB(245, 248, 255), Transparency = 1,
					Size = Vector3.new(taille.X * 0.9, 0.1, taille.Z * 0.9), CFrame = pivot * decalage })
				table.insert(couche.parts, { part = part, decalage = decalage })
			else
				local couleurs = { Color3.fromRGB(190, 120, 40), Color3.fromRGB(160, 90, 30), Color3.fromRGB(120, 140, 50), Color3.fromRGB(210, 160, 60) }
				for i = 1, 8 do
					local decalage = CFrame.new((math.random() - 0.5) * taille.X * 0.8, haut + 0.04, (math.random() - 0.5) * taille.Z * 0.8) * CFrame.Angles(0, math.random() * math.pi, 0)
					local part = partTemporaire({ Name = "TardisCoucheToit", Material = Enum.Material.SmoothPlastic, Color = couleurs[i % #couleurs + 1], Transparency = 1,
						Size = Vector3.new(0.5, 0.05, 0.35), CFrame = pivot * decalage })
					table.insert(couche.parts, { part = part, decalage = decalage })
				end
			end
		end
		local function majCouche()
			local epaisseur = Config.epaisseurToit(os.clock() - couche.debut)
			local pivot = exterieur:GetPivot()
			for i, p in couche.parts do
				if couche.type == "Neige" then
					local h = 0.05 + 0.3 * epaisseur
					p.part.Size = Vector3.new(p.part.Size.X, h, p.part.Size.Z)
					p.decalage = CFrame.new(0, couche.haut + h / 2, 0)
					p.part.Transparency = 1 - 0.9 * math.min(1, epaisseur * 2)
				else
					p.part.Transparency = (i <= math.ceil(epaisseur * #couche.parts)) and 0 or 1
				end
				p.part.CFrame = pivot * p.decalage
			end
		end
		exterieur:GetAttributeChangedSignal("Etat"):Connect(function()
			local etat = exterieur:GetAttribute("Etat")
			if etat == Config.Etats.Demat then vider(true) elseif etat ~= Config.Etats.Pose then vider(false) end
		end)
		RunService.RenderStepped:Connect(function(dt)
			local maintenant = os.clock()
			-- Les pièces qui glissent du toit et tombent en s'effaçant
			for i = #chutes, 1, -1 do
				local c = chutes[i]
				if maintenant >= c.fin or not c.part.Parent then
					c.part:Destroy()
					table.remove(chutes, i)
				else
					c.vitesse += Vector3.new(0, -30 * dt, 0)
					c.part.CFrame = c.part.CFrame + c.vitesse * dt
					c.part.Transparency = math.min(1, c.part.Transparency + dt * 0.4)
				end
			end
			if maintenant < prochainTest then return end
			prochainTest = maintenant + 1
			local posee = exterieur:GetAttribute("Etat") == Config.Etats.Pose and exterieur:GetAttribute("VolLibre") == nil and exterieur:GetAttribute("Porteur") == nil
				and exterieur:GetAttribute("SurEau") ~= true and exterieur:GetAttribute("Camouflage") ~= true
			if not posee then
				if exterieur:GetAttribute("Etat") ~= Config.Etats.Demat then vider(false) end
				return
			end
			if not couche then
				-- Un seul test par arrivée (le sol est celui de TerrainAtterrissage ; l'arbre, un rayon vers le haut)
				local debut = exterieur:GetAttribute("DebutEtat")
				if testeDebut == debut then return end
				testeDebut = debut
				local haut = exterieur:GetExtentsSize().Y - (exterieur.PrimaryPart and exterieur.PrimaryPart.Size.Y / 2 or 0.5)
				local materiau = exterieur:GetAttribute("TerrainAtterrissage")
				local genre = Config.coucheToit(materiau, materiau ~= "Snow" and materiau ~= "Glacier" and materiau ~= "Ice" and sousUnArbre(haut))
				if not genre then return end
				construireCouche(genre, haut)
			end
			majCouche()
		end)
	end

	--------------------------------------------------------------------
	-- 21 ter) (V7.2.4, G-31) Éclair attiré par la cabine pendant l'orage : le serveur pose l'attribut Eclair (heure serveur),
	-- chaque joueur dessine l'éclair jusqu'à la lampe, avec étincelles et lumière qui grésille. Rien en « aucun flash ».
	--------------------------------------------------------------------
	exterieur:GetAttributeChangedSignal("Eclair"):Connect(function()
		local quand = exterieur:GetAttribute("Eclair")
		if type(quand) ~= "number" or workspace:GetServerTimeNow() - quand > 2 or sansFlash() then return end
		local taille = exterieur:GetExtentsSize()
		local cible = lampe and (lampe.Position + Vector3.new(0, lampe.Size.Y / 2, 0)) or (exterieur:GetPivot().Position + Vector3.new(0, taille.Y, 0))
		local depart = cible + Vector3.new((math.random() - 0.5) * 30, 90, (math.random() - 0.5) * 30)
		local precedent, morceaux = depart, {}
		for i = 1, 8 do
			local point = depart:Lerp(cible, i / 8)
			if i < 8 then point += Vector3.new((math.random() - 0.5) * 6, 0, (math.random() - 0.5) * 6) end
			table.insert(morceaux, partTemporaire({ Name = "TardisEclair", Material = Enum.Material.Neon, Color = Color3.fromRGB(210, 225, 255),
				Size = Vector3.new(0.35, 0.35, (point - precedent).Magnitude), CFrame = CFrame.lookAt((precedent + point) / 2, point) }))
			precedent = point
		end
		task.delay(0.25, function() for _, m in morceaux do m:Destroy() end end)
		local support = partTemporaire({ Name = "TardisEclair", Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(cible) })
		creer("ParticleEmitter", { Color = ColorSequence.new(Color3.fromRGB(255, 240, 180), Color3.fromRGB(140, 180, 255)), LightEmission = 1, Size = NumberSequence.new(0.25, 0),
			Speed = NumberRange.new(10, 22), Lifetime = NumberRange.new(0.3, 0.8), SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, -35, 0),
			Rate = 0, Parent = support }):Emit(effetsReduits() and 15 or 40)
		-- La lumière grésille quelques instants, comme la lampe frappée
		local lumiere = creer("PointLight", { Color = Color3.fromRGB(200, 220, 255), Brightness = 8, Range = 40, Parent = support })
		task.spawn(function()
			for i = 1, 6 do
				task.wait(0.08)
				lumiere.Brightness = (i % 2 == 0) and 6 or 1
			end
			lumiere.Enabled = false
		end)
		-- Tonnerre facultatif : un Sound « Tonnerre » dans ReplicatedStorage.TardisAssets
		local actifs = ReplicatedStorage and ReplicatedStorage:FindFirstChild("TardisAssets")
		local tonnerre = actifs and actifs:FindFirstChild("Tonnerre")
		if tonnerre and tonnerre:IsA("Sound") then
			local son = tonnerre:Clone()
			son.Parent = support
			son:Play()
		end
		task.delay(6, function() support:Destroy() end)
	end)

	return {}
end
