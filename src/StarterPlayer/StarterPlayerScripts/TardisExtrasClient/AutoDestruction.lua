-- StarterPlayerScripts > TardisExtrasClient > AutoDestruction (ModuleScript)
-- Auto-destruction : compte à rebours puis explosion
-- Extrait du script principal en V6.6.3 : reçoit ce qu'il utilise, renvoie ce que la suite utilise.

return function(contexte)
	local ReplicatedStorage, RunService, animer, camera, creer, exterieur = contexte.ReplicatedStorage, contexte.RunService, contexte.animer, contexte.camera, contexte.creer, contexte.exterieur
	local jeSuisDedans, joueur, partTemporaire, secouer = contexte.jeSuisDedans, contexte.joueur, contexte.partTemporaire, contexte.secouer
	-- (V7.3.3) la console qui crache des étincelles et l'image délavée ont besoin de la config, de l'intérieur et de Lighting
	local Config = contexte.Config or require(ReplicatedStorage:WaitForChild("TardisConfig"))
	local interieur, Lighting = contexte.interieur, contexte.Lighting or game:GetService("Lighting")
	local reglages = Config.AlerteSalle or {}

	--------------------------------------------------------------------
	-- 13) Auto-destruction : compte à rebours (secousses, rouge, alarme) puis explosion
	--------------------------------------------------------------------
	do
		local UI = require(ReplicatedStorage:WaitForChild("TardisUI"))
		local enCours = nil -- { base = CFrame, rouge = Highlight, alarme = Sound, etincelles = { ParticleEmitter }, lueur = Highlight }
		-- (V7.3.3, G-179) Pièces de la console, réparties si elles sont nombreuses
		local function piecesConsole()
			local console = interieur and interieur:FindFirstChild("Console")
			if not console then return {} end
			local toutes = console:IsA("BasePart") and { console } or {}
			for _, objet in console:GetDescendants() do
				if objet:IsA("BasePart") then table.insert(toutes, objet) end
			end
			local maxi = math.max(reglages.MaxEtincelles or 30, 0)
			if #toutes <= maxi then return toutes end
			local choisies = {}
			for i = 1, maxi do choisies[i] = toutes[math.floor((i - 1) * #toutes / maxi) + 1] end
			return choisies
		end
		RunService.RenderStepped:Connect(function(dt)
			local debut = exterieur:GetAttribute("AutoDestructionDebut")
			if debut then
				local duree = exterieur:GetAttribute("AutoDestructionDuree") or 20
				local p = math.clamp((workspace:GetServerTimeNow() - debut) / duree, 0, 1)
				if not enCours then
					enCours = { base = exterieur:GetPivot() }
					enCours.rouge = creer("Highlight", { FillColor = Color3.fromRGB(255, 30, 30), OutlineColor = Color3.fromRGB(255, 120, 120),
						FillTransparency = 1, OutlineTransparency = 1, DepthMode = Enum.HighlightDepthMode.Occluded, Parent = exterieur })
					local assets = ReplicatedStorage:FindFirstChild("TardisAssets")
					local modele = assets and assets:FindFirstChild("Sons") and assets.Sons:FindFirstChild("Cloitre")
					if modele and exterieur.PrimaryPart then
						enCours.alarme = modele:Clone()
						enCours.alarme.Looped = true
						enCours.alarme.Parent = exterieur.PrimaryPart
						enCours.alarme:Play()
					end
				end
				-- Secousses de plus en plus fortes, teinte rouge qui pulse de plus en plus vite
				local force = 0.05 + p * p * 0.9
				local jitter = CFrame.new((math.random() - 0.5) * force, (math.random() - 0.5) * force * 0.4, (math.random() - 0.5) * force)
					* CFrame.Angles((math.random() - 0.5) * force * 0.06, 0, (math.random() - 0.5) * force * 0.06)
				if not exterieur:GetAttribute("Porteur") and not exterieur:GetAttribute("VolLibre") then exterieur:PivotTo(enCours.base * jitter) end
				-- (« aucun flash », V6.9.9 : le rouge monte sans battre, au lieu de clignoter de plus en plus vite)
				local pulsation = UI.sansFlash() and 0.7 or (0.5 + 0.5 * math.sin(os.clock() * (4 + p * 20)))
				enCours.rouge.FillTransparency = 1 - (0.2 + 0.5 * p) * pulsation
				enCours.rouge.OutlineTransparency = 1 - (0.4 + 0.6 * p)
				if enCours.alarme then enCours.alarme.PlaybackSpeed = 1 + p * 0.6 end
				-- (V7.3.3, G-179) Chaque seconde, une pièce de plus de la console crache des étincelles ; à la fin, toute la console rougeoie
				if reglages.EtincellesConsole ~= false and interieur then
					if not enCours.pieces then
						enCours.pieces, enCours.etincelles = piecesConsole(), {}
						local console = interieur:FindFirstChild("Console")
						if console then
							enCours.lueur = creer("Highlight", { Name = "TardisLueurConsole", FillColor = Color3.fromRGB(255, 70, 40), OutlineColor = Color3.fromRGB(255, 200, 160),
								FillTransparency = 1, OutlineTransparency = 1, DepthMode = Enum.HighlightDepthMode.Occluded, Parent = console })
						end
					end
					local voulues = Config.etincellesConsole(workspace:GetServerTimeNow() - debut, p, #enCours.pieces)
					local reduit = UI.effetsReduits()
					for i = #enCours.etincelles + 1, voulues do
						local piece = enCours.pieces[i]
						enCours.etincelles[i] = creer("ParticleEmitter", { Name = "TardisEtincelles", Texture = "rbxasset://textures/particles/sparkles_main.dds",
							Color = ColorSequence.new(Color3.fromRGB(255, 210, 130)), LightEmission = 1, Rate = reduit and 4 or 14,
							Lifetime = NumberRange.new(0.2, 0.5), Speed = NumberRange.new(6, 12), SpreadAngle = Vector2.new(70, 70),
							Size = NumberSequence.new(0.15, 0), Parent = piece })
					end
					if enCours.lueur then
						local lueur = Config.lueurConsole(p)
						enCours.lueur.FillTransparency = 1 - 0.6 * lueur
						enCours.lueur.OutlineTransparency = 1 - lueur
					end
				end
				local distance = (camera.CFrame.Position - enCours.base.Position).Magnitude
				if jeSuisDedans() or distance < 80 then secouer(p * 0.7) end
			elseif enCours then
				if not exterieur:GetAttribute("Detruit") then exterieur:PivotTo(enCours.base) end
				enCours.rouge:Destroy()
				if enCours.alarme then enCours.alarme:Destroy() end
				-- (V7.3.3) annulée (ou terminée) : plus d'étincelles ni de lueur
				for _, emetteur in enCours.etincelles or {} do emetteur:Destroy() end
				if enCours.lueur then enCours.lueur:Destroy() end
				enCours = nil
			end
		end)

		-- Explosion : boule de feu, onde de choc, fumée, débris, flash et secousse
		exterieur:GetAttributeChangedSignal("Explosion"):Connect(function()
			if not exterieur:GetAttribute("Explosion") then return end
			local centre = exterieur:GetPivot().Position + Vector3.new(0, 4, 0)
			local sansFlash = UI.sansFlash() -- V6.9.9
			local boule = partTemporaire({ Name = "TardisExplosion", Shape = Enum.PartType.Ball, Material = Enum.Material.Neon,
				Color = Color3.fromRGB(255, 230, 160), Size = sansFlash and Vector3.new(2, 2, 2) or Vector3.new(4, 4, 4), CFrame = CFrame.new(centre), Transparency = sansFlash and 0.8 or 0 })
			animer(boule, 0.5, { Size = Vector3.new(60, 60, 60), Color = Color3.fromRGB(255, 90, 20) }, Enum.EasingStyle.Quad)
			task.delay(0.5, function()
				animer(boule, 1.2, { Size = Vector3.new(90, 90, 90), Transparency = 1, Color = Color3.fromRGB(40, 20, 10) })
				task.delay(1.3, function() boule:Destroy() end)
			end)
			local onde = partTemporaire({ Name = "TardisOndeExplosion", Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon,
				Color = Color3.fromRGB(255, 200, 120), Transparency = 0.2, Size = Vector3.new(0.4, 6, 6),
				CFrame = CFrame.new(centre - Vector3.new(0, 3.5, 0)) * CFrame.Angles(0, 0, math.pi / 2) })
			animer(onde, 1.4, { Size = Vector3.new(0.2, 220, 220), Transparency = 1 })
			task.delay(1.5, function() onde:Destroy() end)
			-- « Aucun flash » (V6.9.9) : la lumière monte doucement et reste faible, au lieu d'un éclat de 150 studs
			local lumiere = creer("PointLight", { Color = Color3.fromRGB(255, 150, 60), Brightness = sansFlash and 0 or 20, Range = sansFlash and 60 or 150, Parent = boule })
			if sansFlash then
				animer(lumiere, 0.3, { Brightness = 4 })
				task.delay(0.3, function() if lumiere.Parent then animer(lumiere, 1.2, { Brightness = 0 }) end end)
			else
				animer(lumiere, 1.5, { Brightness = 0 })
			end
			-- Fumée et débris
			local support = partTemporaire({ Name = "TardisFumeeExplosion", Transparency = 1, Size = Vector3.new(6, 6, 6), CFrame = CFrame.new(centre) })
			local fumee = creer("Smoke", { Color = Color3.fromRGB(40, 35, 30), Opacity = 0.7, RiseVelocity = 12, Size = 25, Parent = support })
			task.delay(3, function() fumee.Enabled = false end)
			task.delay(10, function() support:Destroy() end)
			for _ = 1, 24 do
				local debris = partTemporaire({ Name = "TardisDebris", Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 160, 60),
					Size = Vector3.new(0.4, 0.4, 0.4), CFrame = CFrame.new(centre) })
				debris.Anchored = false
				debris.CanCollide = true
				local direction = Vector3.new(math.random() - 0.5, math.random() * 0.8 + 0.2, math.random() - 0.5).Unit
				debris.AssemblyLinearVelocity = direction * (40 + math.random() * 50)
				local feu = creer("Fire", { Size = 2, Heat = 5, Parent = debris })
				task.delay(2, function() feu.Enabled = false end)
				task.delay(6, function() debris:Destroy() end)
			end
			-- Flash à l'écran et secousse selon la distance
			local distance = (camera.CFrame.Position - centre).Magnitude
			local intensite = math.clamp(1 - distance / 200, 0, 1)
			if intensite > 0 and sansFlash then
				secouer(intensite * 1.5) -- « aucun flash » : la secousse sans le voile à l'écran
			elseif intensite > 0 then
				local flash = creer("ScreenGui", { Name = "TardisFlashExplosion", ResetOnSpawn = false, IgnoreGuiInset = true, Parent = joueur:WaitForChild("PlayerGui") })
				local reduit = require(ReplicatedStorage:WaitForChild("TardisUI")).effetsReduits()
				local voile = creer("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 240, 200), BackgroundTransparency = 1 - intensite * (reduit and 0.3 or 0.9),
					BorderSizePixel = 0, Parent = flash })
				animer(voile, 1.2, { BackgroundTransparency = 1 })
				task.delay(1.3, function() flash:Destroy() end)
				secouer(intensite * 1.5)
			end
			-- (V7.3.3, G-271) Image délavée : les joueurs proches voient gris, puis les couleurs reviennent en quelques secondes
			local gris = reglages.ImageDelavee ~= false and Config.forceDelavage(distance) or 0
			if gris > 0 then
				local duree = reglages.DureeDelavee or 4
				local effet = creer("ColorCorrectionEffect", { Name = "TardisImageDelavee", Saturation = -gris, Parent = Lighting })
				local depart = os.clock()
				local lien
				lien = RunService.RenderStepped:Connect(function()
					local ecoule = os.clock() - depart
					effet.Saturation = Config.delavage(ecoule, duree) * gris
					if ecoule >= duree then
						lien:Disconnect()
						effet:Destroy()
					end
				end)
			end
		end)
	end

	return {}
end
