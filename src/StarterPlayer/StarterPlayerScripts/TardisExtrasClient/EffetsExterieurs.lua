-- StarterPlayerScripts > TardisExtrasClient > EffetsExterieurs (ModuleScript)
-- Halo et projecteur, ombre, air, distorsion, givre, impacts, leurre, rayon tracteur, chocs et secousse,
-- freinage d'urgence ressenti à bord (V6.9.10)
-- Extrait du script principal en V6.6.3 : reçoit ce qu'il utilise, renvoie ce que la suite utilise.

return function(contexte)
	local C, Config, E, Lighting, RunService, animer = contexte.C, contexte.Config, contexte.E, contexte.Lighting, contexte.RunService, contexte.animer
	local camera, creer, def, exterieur, interieur, jeSuisDedans = contexte.camera, contexte.creer, contexte.def, contexte.exterieur, contexte.interieur, contexte.jeSuisDedans
	local joueur, lampe, partTemporaire, progressionAnimation, remote = contexte.joueur, contexte.lampe, contexte.partTemporaire, contexte.progressionAnimation, contexte.remote

	--------------------------------------------------------------------
	-- 4) Halo de la lampe (visible de loin la nuit) et projecteur
	--------------------------------------------------------------------
	if lampe then
		-- (le halo de la lampe a été retiré à la demande du pilote)
		local lumiere = lampe:FindFirstChildOfClass("PointLight") or (lampe:FindFirstChildOfClass("Attachment") and lampe:FindFirstChildOfClass("Attachment"):FindFirstChildOfClass("PointLight"))

		-- Projecteur : un cône de lumière orienté, piloté par la caméra du pilote
		local supportProj = partTemporaire({ Name = "TardisProjecteur", Transparency = 1, Size = Vector3.new(0.5, 0.5, 0.5), CFrame = lampe.CFrame })
		local spot = creer("SpotLight", { Angle = 38, Brightness = 0, Range = 220, Face = Enum.NormalId.Front, Shadows = true, Color = Color3.fromRGB(255, 245, 210), Parent = supportProj })
		local a0 = creer("Attachment", { Parent = supportProj })
		local a1 = creer("Attachment", { Position = Vector3.new(0, 0, -60), Parent = supportProj })
		local cone = creer("Beam", { Attachment0 = a0, Attachment1 = a1, Width0 = 1, Width1 = 16, LightEmission = 1, LightInfluence = 0,
			Color = ColorSequence.new(Color3.fromRGB(255, 245, 210)), Transparency = NumberSequence.new(1), FaceCamera = true, Parent = supportProj })
		local dernierEnvoi = 0
		RunService.RenderStepped:Connect(function(dt)
			local allumee = exterieur:GetAttribute("Alimentation") ~= false and (lumiere == nil or lumiere.Brightness > 0.05)

			local projecteur = exterieur:GetAttribute("Projecteur") == true and allumee
			local direction = exterieur:GetAttribute("ProjecteurDir")
			if typeof(direction) ~= "Vector3" or direction.Magnitude < 0.1 then direction = exterieur:GetPivot().LookVector end
			supportProj.CFrame = CFrame.lookAt(lampe.Position, lampe.Position + direction)
			spot.Brightness += ((projecteur and 8 or 0) - spot.Brightness) * math.min(dt * 6, 1)
			cone.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, projecteur and 0.86 or 1), NumberSequenceKeypoint.new(1, 1) })
			-- Le pilote vise avec sa caméra
			if projecteur and joueur:GetAttribute("TardisPilote_" .. def.Nom) == true and os.clock() - dernierEnvoi > 0.12 then
				dernierEnvoi = os.clock()
				remote:FireServer("ProjecteurDir", camera.CFrame.LookVector)
			end
		end)
	end

	--------------------------------------------------------------------
	-- 5) Ombre annonciatrice, air qui ondule, distorsion d'écran, givre d'urgence
	-- (V6.9.9) En Urgence et en Catastrophe, l'air ondule plus fort et plus loin (Config.facteurDistorsion), aussi
	-- pendant la démat ; en « effets réduits », seul l'excédent est divisé par 2.
	--------------------------------------------------------------------
	do
		local UI_ = require(game:GetService("ReplicatedStorage"):WaitForChild("TardisUI"))
		local ombre, air, givre = nil, nil, nil
		local facteurAir = nil -- force pour laquelle la transparence des volutes a été réglée
		local flou = creer("BlurEffect", { Size = 0, Name = "TardisDistorsion", Parent = Lighting })
		local teinte = creer("ColorCorrectionEffect", { Name = "TardisDistorsionTeinte", Parent = Lighting })
		local function solSous(position)
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			local exclus = { exterieur, interieur }
			if ombre then table.insert(exclus, ombre) end
			if air then table.insert(exclus, air) end
			params.FilterDescendantsInstances = exclus
			return workspace:Raycast(position + Vector3.new(0, 1, 0), Vector3.new(0, -12, 0), params)
		end
		RunService.RenderStepped:Connect(function(dt)
			local p, remat = progressionAnimation()
			-- Silencieux (V6.9) : ni ombre, ni air qui ondule, ni distorsion
			local modeAnime = exterieur:GetAttribute("VolPhase") and Config.modeVolDe(exterieur) or Config.modeDe(exterieur)
			if p and (Config.Modes[modeAnime] or {}).Discret then p = nil end
			local base = exterieur:GetPivot().Position
			local facteur = Config.facteurDistorsion(modeAnime, UI_.effetsReduits())
			-- Ombre au sol avant l'apparition, et air qui ondule pendant la matérialisation (et la démat d'urgence)
			-- (démat d'urgence : pas pour une cabine camouflée ou portée, qui se trahirait — correction de relecture V6.9.9)
			local cache = exterieur:GetAttribute("Camouflage") == true or exterieur:GetAttribute("Porteur") ~= nil
			if p and (remat or (facteur > 1 and not cache)) then
				local sol = solSous(base)
				if sol then
					local taille = exterieur:GetExtentsSize()
					if remat then
						if not ombre then
							ombre = partTemporaire({ Name = "TardisOmbre", Shape = Enum.PartType.Cylinder, Color = Color3.new(0, 0, 0), Material = Enum.Material.SmoothPlastic,
								Transparency = 1, Size = Vector3.new(0.05, 1, 1) })
						end
						local diametre = math.max(taille.X, taille.Z) * 1.3
						ombre.Size = Vector3.new(0.05, diametre, diametre)
						ombre.CFrame = CFrame.new(sol.Position + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, 0, math.pi / 2)
						ombre.Transparency = 0.45 + 0.5 * math.clamp(p * 1.5, 0, 1) -- bien visible au début, s'efface quand le TARDIS apparaît
					elseif ombre then
						ombre:Destroy()
						ombre = nil
					end
					if not air then
						air = partTemporaire({ Name = "TardisAir", Transparency = 1, Size = Vector3.new(taille.X * 1.6, 0.5, taille.Z * 1.6) })
						local emetteur = creer("ParticleEmitter", { Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(Color3.fromRGB(235, 245, 255)),
							Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.93), NumberSequenceKeypoint.new(0.5, 0.86), NumberSequenceKeypoint.new(1, 1) }),
							Size = NumberSequence.new(5, 9), Lifetime = NumberRange.new(1.2, 2), Speed = NumberRange.new(2, 4), Rate = 0, LightEmission = 0.4,
							Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-20, 20), Parent = air })
						emetteur.Name = "Emetteur"
						facteurAir = nil
					end
					-- Plus de force (V6.9.9) : des volutes plus nombreuses et plus opaques (réglées seulement quand la force change)
					if facteurAir ~= facteur then
						facteurAir = facteur
						local opacite = math.clamp(facteur, 1, 2.5)
						air.Emetteur.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1 - 0.07 * opacite),
							NumberSequenceKeypoint.new(0.5, 1 - 0.14 * opacite), NumberSequenceKeypoint.new(1, 1) })
					end
					air.CFrame = CFrame.new(sol.Position + Vector3.new(0, 1, 0))
					air.Emetteur.Rate = 6 * math.sin(p * math.pi) * facteur
				end
			else
				if ombre then ombre:Destroy() ombre = nil end
				if air then
					local vieux = air
					air = nil
					vieux.Emetteur.Enabled = false
					task.delay(2.5, function() vieux:Destroy() end)
				end
			end
			-- Distorsion d'écran : près du TARDIS, l'image se trouble pendant une démat / remat
			local intensite = 0
			if p then
				local distance = (camera.CFrame.Position - base).Magnitude
				intensite = math.sin(p * math.pi) * math.clamp(1 - distance / (45 * facteur), 0, 1) * facteur
			end
			flou.Size += (intensite * 10 - flou.Size) * math.min(dt * 6, 1)
			teinte.Saturation += (math.max(-0.35 * intensite, -0.8) - teinte.Saturation) * math.min(dt * 6, 1)
			teinte.TintColor = teinte.TintColor:Lerp(Color3.new(1 - 0.08 * intensite, 1 - 0.04 * intensite, 1), math.min(dt * 6, 1))
		end)

		-- Givre : après un atterrissage d'urgence, la cabine se couvre de givre qui fond lentement
		exterieur:GetAttributeChangedSignal("Etat"):Connect(function()
			if exterieur:GetAttribute("Etat") ~= E.Pose or Config.modeDe(exterieur) ~= "Urgence" then return end
			if givre then givre:Destroy() end
			givre = creer("Highlight", { FillColor = Color3.fromRGB(215, 240, 255), OutlineColor = Color3.fromRGB(240, 250, 255),
				FillTransparency = 0.55, OutlineTransparency = 0.35, DepthMode = Enum.HighlightDepthMode.Occluded, Parent = exterieur })
			local cristaux = creer("Sparkles", { SparkleColor = Color3.fromRGB(220, 240, 255), Parent = exterieur.PrimaryPart })
			animer(givre, 25, { FillTransparency = 1, OutlineTransparency = 1 }, Enum.EasingStyle.Linear)
			task.delay(6, function() cristaux.Enabled = false end)
			task.delay(10, function() cristaux:Destroy() end)
			local moi = givre
			task.delay(25.5, function() if givre == moi then givre:Destroy() givre = nil end end)
		end)
	end

	--------------------------------------------------------------------
	-- 6) Impacts sur le bouclier anti-balles : une ondulation là où un tir touche la bulle
	--------------------------------------------------------------------
	do
		local function ondulation(bulle, position)
			local centre = bulle.Position
			local normale = (position - centre)
			if normale.Magnitude < 0.1 then return end
			normale = normale.Unit
			local anneau = partTemporaire({ Name = "TardisImpactBouclier", Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon,
				Color = bulle.Color, Transparency = 0.1, Size = Vector3.new(0.1, 0.6, 0.6),
				CFrame = CFrame.lookAt(position, position + normale) * CFrame.Angles(0, math.pi / 2, 0) })
			animer(anneau, 0.45, { Size = Vector3.new(0.1, 6, 6), Transparency = 1 })
			task.delay(0.5, function() anneau:Destroy() end)
		end
		local function surveiller(modele)
			local bulle = modele:WaitForChild("Bulle", 5)
			if not bulle then return end
			bulle.DescendantAdded:Connect(function(objet)
				-- Les systèmes d'armes attachent leurs impacts (Attachment, Decal...) à la pièce touchée
				local position = (objet:IsA("Attachment") and objet.WorldPosition) or (objet:IsA("BasePart") and objet.Position)
				if position then ondulation(bulle, position) end
			end)
			bulle.Touched:Connect(function(autre)
				if not autre:IsDescendantOf(exterieur) and not (autre.Parent and autre.Parent:FindFirstChildOfClass("Humanoid")) then
					ondulation(bulle, autre.Position)
				end
			end)
		end
		task.spawn(function()
			local dossier = exterieur:WaitForChild("Boucliers", 30)
			if not dossier then return end
			dossier.ChildAdded:Connect(function(modele)
				if modele.Name == "BouclierBalles" then task.spawn(surveiller, modele) end
			end)
			for _, modele in dossier:GetChildren() do
				if modele.Name == "BouclierBalles" then task.spawn(surveiller, modele) end
			end
		end)
	end

	--------------------------------------------------------------------
	-- 7) Leurre : le faux TARDIS apparaît et disparaît en fondu
	--------------------------------------------------------------------
	workspace.ChildAdded:Connect(function(objet)
		if objet.Name ~= "TardisLeurre_" .. def.Nom then return end
		task.wait()
		local cibles = {}
		for _, part in objet:GetDescendants() do
			if part:IsA("BasePart") then
				cibles[part] = part.Transparency
				part.Transparency = 1
				animer(part, 2, { Transparency = cibles[part] })
			end
		end
		objet:GetAttributeChangedSignal("Disparition"):Connect(function()
			for part, _ in cibles do
				if part.Parent then animer(part, 2, { Transparency = 1 }) end
			end
		end)
	end)

	--------------------------------------------------------------------
	-- 8) Rayon tracteur : un faisceau entre le TARDIS et l'objet attiré
	--------------------------------------------------------------------
	do
		local a0, a1, faisceau = nil, nil, nil
		local cible = exterieur:WaitForChild("TracteurCible", 30)
		if cible then
			RunService.RenderStepped:Connect(function()
				local objet = cible.Value
				local base = exterieur.PrimaryPart
				if objet and base then
					if not faisceau then
						a0 = creer("Attachment", { Parent = base })
						a1 = creer("Attachment", { Parent = objet })
						faisceau = creer("Beam", { Attachment0 = a0, Attachment1 = a1, Width0 = 2.5, Width1 = 1.2, LightEmission = 1, LightInfluence = 0,
							Color = ColorSequence.new(C.cyan, Color3.fromRGB(180, 240, 255)), Transparency = NumberSequence.new(0.35), FaceCamera = true,
							TextureSpeed = 2, Parent = base })
					elseif a1.Parent ~= objet then
						a1.Parent = objet
					end
					faisceau.Transparency = NumberSequence.new(0.3 + 0.15 * math.sin(os.clock() * 8))
				elseif faisceau then
					faisceau:Destroy() a0:Destroy() a1:Destroy()
					faisceau, a0, a1 = nil, nil, nil
				end
			end)
		end
	end

	--------------------------------------------------------------------
	-- 9) Chocs en vol : étincelles et secousse (le pilote les signale, le serveur les relaie)
	--------------------------------------------------------------------
	local secousse = 0
	-- Les autres effets demandent une secousse par cette fonction (la plus forte demande l'emporte)
	local UI = require(game:GetService("ReplicatedStorage"):WaitForChild("TardisUI"))
	local function secouer(force) secousse = math.max(secousse, force * (UI.effetsReduits() and 0.3 or 1)) end
	exterieur:GetAttributeChangedSignal("ChocTemps"):Connect(function()
		local position = exterieur:GetAttribute("ChocPos")
		if typeof(position) ~= "Vector3" then return end
		local support = partTemporaire({ Name = "TardisChoc", Transparency = 1, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(position) })
		local etincelles = creer("ParticleEmitter", { Color = ColorSequence.new(Color3.fromRGB(255, 230, 150), Color3.fromRGB(255, 120, 30)), LightEmission = 1,
			Size = NumberSequence.new(0.25, 0), Speed = NumberRange.new(15, 30), Lifetime = NumberRange.new(0.3, 0.7), SpreadAngle = Vector2.new(180, 180),
			Acceleration = Vector3.new(0, -40, 0), Rate = 0, Parent = support })
		etincelles:Emit(60)
		task.delay(2, function() support:Destroy() end)
		local distance = (camera.CFrame.Position - position).Magnitude
		secouer(math.clamp(1 - distance / 80, 0, 1) * 0.8)
		if jeSuisDedans() then secouer(0.6) end
	end)

	--------------------------------------------------------------------
	-- 9 bis) Freinage d'urgence (V6.9.10) : le serveur publie FreinTemps (pilote vérifié, un frein par seconde au plus).
	-- Secousse pour les passagers à bord (plus douce avec « réduire les effets », par secouer), petite secousse dehors
	-- tout près de la cabine, fumée de freinage autour de la cabine pour tout le monde (pas camouflée ni invisible),
	-- et le son « Frein » s'il existe (TardisAssets › Sons) : à bord, ou près de la cabine.
	--------------------------------------------------------------------
	local reglagesFrein = (Config.VolLibre or {}).Frein or {}
	exterieur:GetAttributeChangedSignal("FreinTemps"):Connect(function()
		local temps = exterieur:GetAttribute("FreinTemps")
		if type(temps) ~= "number" or workspace:GetServerTimeNow() - temps > 2 then return end -- ancien frein : rien ne se rejoue
		local dedans = jeSuisDedans()
		local base = exterieur.PrimaryPart
		-- Le pilote a déjà sa propre secousse (TardisVolLibre) : pas de seconde secousse pour lui
		if exterieur:GetAttribute("VolLibre") ~= joueur.UserId then
			if dedans then
				secouer(reglagesFrein.SecousseABord or 0.5)
			elseif base then
				local distance = (camera.CFrame.Position - base.Position).Magnitude
				secouer(math.clamp(1 - distance / (reglagesFrein.PorteeDehors or 60), 0, 1) * (reglagesFrein.SecousseDehors or 0.4))
			end
		end
		local visible = exterieur:GetAttribute("Camouflage") ~= true and (exterieur:GetAttribute("VolPhase") or "Visible") == "Visible"
		if base and visible then
			-- Petit TARDIS ou vol de précision : une fumée à sa taille
			local echelle = (tonumber(exterieur:GetAttribute("Echelle")) or 1) * (exterieur:GetAttribute("VolPrecision") == true and 0.3 or 1)
			local fumee = creer("Smoke", { Name = "TardisFumeeFrein", Color = Color3.fromRGB(150, 150, 150), Opacity = 0.4, RiseVelocity = 2,
				Size = math.max(5 * echelle, 0.5), Parent = base })
			task.delay(reglagesFrein.DureeFumee or 0.5, function() fumee.Enabled = false end)
			task.delay(3, function() fumee:Destroy() end)
		end
		-- Son « Frein » (facultatif) : non positionné à bord, autour de la cabine dehors (pas pour une cabine cachée)
		local assets = game:GetService("ReplicatedStorage"):FindFirstChild("TardisAssets")
		local modele = assets and assets:FindFirstChild("Sons") and assets.Sons:FindFirstChild("Frein")
		if modele and modele:IsA("Sound") and (dedans or (base and visible)) then
			local son = modele:Clone()
			son.Name = "TardisSonFrein"
			son.Looped = false
			if dedans then
				son.Volume = modele.Volume * UI.volume()
				son.Parent = game:GetService("SoundService")
			else
				local portee = (Config.PorteeSons or {}).Dehors
				if portee then
					son.RollOffMode = Enum.RollOffMode.InverseTapered
					son.RollOffMinDistance, son.RollOffMaxDistance = portee.Min or 12, portee.Max or 220
				end
				son.Parent = base -- le volume des réglages s'applique tout seul (sons de l'extérieur)
			end
			son:Play()
			son.Ended:Connect(function() son:Destroy() end)
			task.delay(10, function() if son.Parent then son:Destroy() end end) -- au cas où Ended ne viendrait pas
		end
	end)
	RunService:BindToRenderStep("TardisExtrasSecousse_" .. def.Nom, Enum.RenderPriority.Camera.Value + 3, function(dt)
		if secousse <= 0 then return end
		local force = secousse * 0.035
		camera.CFrame = camera.CFrame * CFrame.Angles((math.random() - 0.5) * force, (math.random() - 0.5) * force, (math.random() - 0.5) * force)
		secousse = math.max(0, secousse - dt * 1.4)
	end)

	return { secouer = secouer }
end
