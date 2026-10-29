-- StarterPlayerScripts > TardisExtrasClient > Regeneration (ModuleScript)
-- Régénération (équipe Le Voyageur) et régénération à bord
-- Extrait du script principal en V6.6.3 : reçoit ce qu'il utilise, renvoie ce que la suite utilise.

return function(contexte)
	local C, Config, Lighting, Players, ReplicatedStorage, RunService = contexte.C, contexte.Config, contexte.Lighting, contexte.Players, contexte.ReplicatedStorage, contexte.RunService
	local UI, animer, camera, creer, def, exterieur = contexte.UI, contexte.animer, contexte.camera, contexte.creer, contexte.def, contexte.exterieur
	local interieur, jeSuisDedans, joueur, maRacine, partTemporaire, remote = contexte.interieur, contexte.jeSuisDedans, contexte.joueur, contexte.maRacine, contexte.partTemporaire, contexte.remote
	local secouer, texte = contexte.secouer, contexte.texte

	--------------------------------------------------------------------
	-- 18) Régénération (équipe "Le Voyageur") : énergie dorée qui jaillit de la tête et des mains, flash au moment du
	-- changement d'apparence. Un seul exemplaire du script s'en occupe (celui du premier TARDIS).
	--------------------------------------------------------------------
	if def.Nom == Config.Tardis[1].Nom then
		local function surveillerRegeneration(personnage)
			local dejaJoue = nil -- une régénération n'est jouée qu'une fois (signal ou rattrapage)
			local function effets()
				local debut = personnage:GetAttribute("TardisRegeneration")
				if not debut or debut == dejaJoue then return end
				dejaJoue = debut
				local racine = personnage:FindFirstChild("HumanoidRootPart")
				local tete = personnage:FindFirstChild("Head")
				if not racine or not tete then return end
				local REG = Config.Regeneration or {}
				local duree = personnage:GetAttribute("TardisRegenerationDuree") or 8
				local style = personnage:GetAttribute("TardisRegenerationStyle") or 1
				local moi = personnage == joueur.Character
				local humanoid = personnage:FindFirstChildOfClass("Humanoid")

				-- Palette de la série : cœur blanc-jaune, flammes dorées, bords orange
				local BLANC_OR, OR_CLAIR, OR, ORANGE = Color3.fromRGB(255, 250, 225), Color3.fromRGB(255, 225, 120), Color3.fromRGB(255, 170, 50), Color3.fromRGB(255, 105, 20)
				local FEU = "rbxasset://textures/particles/fire_main.dds"
				local FUMEE = "rbxasset://textures/particles/smoke_main.dds"
				local ETINCELLE = "rbxasset://textures/particles/sparkles_main.dds"
				local aDetruire, flux, connexions = {}, {}, {}
				local function garder(objet) table.insert(aDetruire, objet) return objet end
				-- Un émetteur dont le débit suit l'intensité de la régénération (montée, éruption, dissipation)
				local function emetteur(parent, proprietes, debitMax, seuil)
					proprietes.Parent = parent
					proprietes.Rate = 0
					local e = garder(creer("ParticleEmitter", proprietes))
					table.insert(flux, { e = e, debit = debitMax, seuil = seuil or 0 })
					return e
				end
				-- Panache de flammes dorées (la signature de la série) : cœur clair, bords orange, qui grossit en montant
				local function panache(parent, direction, puissance, couleurs)
					couleurs = couleurs or { BLANC_OR, OR, ORANGE }
					emetteur(parent, { Texture = FEU, LightEmission = 1, LightInfluence = 0, EmissionDirection = direction, ZOffset = 1,
						Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, couleurs[1]), ColorSequenceKeypoint.new(0.4, couleurs[2]), ColorSequenceKeypoint.new(1, couleurs[3]) }),
						Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6 * puissance), NumberSequenceKeypoint.new(0.5, 1.6 * puissance), NumberSequenceKeypoint.new(1, 0.4 * puissance) }),
						Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.7, 0.3), NumberSequenceKeypoint.new(1, 1) }),
						Speed = NumberRange.new(9 * puissance, 15 * puissance), Lifetime = NumberRange.new(0.35, 0.7), Drag = 2,
						SpreadAngle = Vector2.new(14, 14), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-120, 120) }, 110 * puissance, 0.12)
					-- Le cœur : plus petit, presque blanc, très lumineux
					emetteur(parent, { Texture = FEU, LightEmission = 1, LightInfluence = 0, EmissionDirection = direction, ZOffset = 2,
						Color = ColorSequence.new(BLANC_OR, OR_CLAIR), Size = NumberSequence.new(0.5 * puissance, 0.1),
						Transparency = NumberSequence.new(0, 1), Speed = NumberRange.new(12 * puissance, 18 * puissance), Lifetime = NumberRange.new(0.2, 0.4),
						SpreadAngle = Vector2.new(6, 6), Rotation = NumberRange.new(0, 360) }, 70 * puissance, 0.2)
				end
				-- Points d'émission : au-dessus de la tête (vers le haut), au bout des mains (le long des bras écartés)
				local pointTete = garder(creer("Attachment", { Position = Vector3.new(0, tete.Size.Y * 0.4, 0), Parent = tete }))
				local mains = {}
				for _, nom in { "Left Arm", "Right Arm", "LeftHand", "RightHand" } do
					local bras = personnage:FindFirstChild(nom)
					if bras then table.insert(mains, garder(creer("Attachment", { Position = Vector3.new(0, -bras.Size.Y / 2, 0), Parent = bras }))) end
				end
				local function panachesTeteEtMains(puissance, couleurs)
					panache(pointTete, Enum.NormalId.Top, puissance, couleurs)
					for _, main in mains do panache(main, Enum.NormalId.Bottom, puissance * 0.8, couleurs) end
				end

				-- Lueur sous la peau, lumière qui inonde les environs
				local lueur = garder(creer("Highlight", { FillColor = OR, OutlineColor = OR_CLAIR, FillTransparency = 1, OutlineTransparency = 1,
					DepthMode = Enum.HighlightDepthMode.Occluded, Parent = personnage }))
				local lumiere = garder(creer("PointLight", { Color = OR, Brightness = 0, Range = 10, Shadows = true, Parent = racine }))
				local lumiereTete = garder(creer("PointLight", { Color = OR_CLAIR, Brightness = 0, Range = 8, Parent = tete }))
				-- Montée : de petites volutes dorées s'échappent des mains et du visage
				for _, point in { pointTete, table.unpack(mains) } do
					emetteur(point, { Texture = FUMEE, LightEmission = 1, Color = ColorSequence.new(OR_CLAIR, OR), Size = NumberSequence.new(0.2, 0.6),
						Transparency = NumberSequence.new(0.4, 1), Speed = NumberRange.new(0.5, 1.5), Lifetime = NumberRange.new(0.6, 1.2),
						SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, 2, 0) }, 25, 0)
				end
				-- Étincelles dorées tout autour
				local etincelles = emetteur(racine, { Texture = ETINCELLE, LightEmission = 1, Color = ColorSequence.new(BLANC_OR, OR),
					Size = NumberSequence.new(0.35, 0), Speed = NumberRange.new(6, 16), Lifetime = NumberRange.new(0.4, 0.9), SpreadAngle = Vector2.new(180, 180),
					Acceleration = Vector3.new(0, -12, 0), Drag = 1 }, 40, 0.3)

				local secousseMax, couleurFlash, couleurAmbiance = 0.5, BLANC_OR, OR
				local parImage = nil -- animation propre au style, appelée à chaque image : parImage(p, i, t)
				local sol = racine.Position - Vector3.new(0, (humanoid and humanoid.HipHeight or 0) + racine.Size.Y / 2 + 2, 0)

				if style == 2 then
					-- VOLCAN (10e → 11e Docteur) : une éruption si violente qu'elle ravage tout autour
					panachesTeteEtMains(1.8, { BLANC_OR, OR, Color3.fromRGB(255, 70, 10) })
					etincelles.Rate = 0
					for _, f in flux do if f.e == etincelles then f.debit = 160 end end
					-- Flammes au sol, autour du Voyageur
					for k = 1, 6 do
						local angle = k / 6 * math.pi * 2
						local foyer = garder(partTemporaire({ Name = "TardisRegenFoyer", Transparency = 1, Size = Vector3.new(1, 1, 1),
							CFrame = CFrame.new(sol + Vector3.new(math.cos(angle) * 5, 0.5, math.sin(angle) * 5)) }))
						local feu = garder(creer("Fire", { Size = 0.1, Heat = 12, Color = OR, SecondaryColor = ORANGE, Enabled = false, Parent = foyer }))
						task.delay(duree * (0.3 + k * 0.03), function() if feu.Parent then feu.Enabled = true animer(feu, 1, { Size = 6 }) end end)
					end
					-- Ondes de choc qui balaient le sol pendant l'éruption
					local prochaineOnde = 0.35
					parImage = function(p)
						if p >= prochaineOnde and p < 0.8 then
							prochaineOnde += 0.12
							local onde = partTemporaire({ Name = "TardisRegenOnde", Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = OR_CLAIR,
								Transparency = 0.25, Size = Vector3.new(0.2, 3, 3), CFrame = CFrame.new(sol + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2) })
							animer(onde, 0.9, { Size = Vector3.new(0.15, 46, 46), Transparency = 1, Color = ORANGE })
							task.delay(1, function() onde:Destroy() end)
						end
					end
					-- Au moment du changement : une explosion de lumière
					task.delay(duree * 0.55, function()
						if not racine.Parent then return end
						local boule = partTemporaire({ Name = "TardisRegenExplosion", Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = BLANC_OR,
							Transparency = 0.1, Size = Vector3.new(3, 3, 3), CFrame = racine.CFrame })
						animer(boule, 0.7, { Size = Vector3.new(34, 34, 34), Transparency = 1, Color = ORANGE })
						task.delay(0.8, function() boule:Destroy() end)
						etincelles:Emit(120)
					end)
					secousseMax, couleurAmbiance = 1.3, ORANGE
				elseif style == 3 then
					-- DOUCE (Docteur de la Guerre → 9e, 8e Docteur) : un voile de lumière tiède, sans violence
					for _, f in flux do f.debit *= 0.3 end
					emetteur(racine, { Texture = FUMEE, LightEmission = 1, LightInfluence = 0, Color = ColorSequence.new(BLANC_OR, OR_CLAIR),
						Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(0.5, 3.5), NumberSequenceKeypoint.new(1, 4.5) }),
						Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.55), NumberSequenceKeypoint.new(1, 1) }),
						Speed = NumberRange.new(0.3, 1), Lifetime = NumberRange.new(1.5, 2.5), SpreadAngle = Vector2.new(180, 180),
						Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-20, 20) }, 30, 0.1)
					emetteur(racine, { Texture = ETINCELLE, LightEmission = 1, Color = ColorSequence.new(BLANC_OR), Size = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.25), NumberSequenceKeypoint.new(1, 0) }),
						Speed = NumberRange.new(0.5, 2), Lifetime = NumberRange.new(1, 2), SpreadAngle = Vector2.new(180, 180) }, 50, 0.15)
					lueur.FillColor, lueur.OutlineColor = BLANC_OR, Color3.new(1, 1, 1)
					lumiere.Color = Color3.fromRGB(255, 220, 170)
					secousseMax, couleurFlash, couleurAmbiance = 0.1, Color3.fromRGB(255, 252, 240), Color3.fromRGB(255, 225, 180)
				elseif style == 4 then
					-- TOURBILLON (5e, 6e, 7e Docteurs) : des sphères qui tournoient en spirale, des couleurs qui défilent
					panachesTeteEtMains(0.8)
					local spheres = {}
					for k = 1, 6 do
						local sphere = garder(partTemporaire({ Name = "TardisRegenTourbillon", Shape = Enum.PartType.Ball, Material = Enum.Material.Neon,
							Color = OR, Size = Vector3.new(0.7, 0.7, 0.7), CFrame = racine.CFrame }))
						local a0 = creer("Attachment", { Position = Vector3.new(0, 0.3, 0), Parent = sphere })
						local a1 = creer("Attachment", { Position = Vector3.new(0, -0.3, 0), Parent = sphere })
						local trainee = creer("Trail", { Attachment0 = a0, Attachment1 = a1, Lifetime = 0.6, LightEmission = 1, FaceCamera = true,
							Transparency = NumberSequence.new(0, 1), WidthScale = NumberSequence.new(1, 0), Parent = sphere })
						spheres[k] = { part = sphere, trainee = trainee, lumiere = creer("PointLight", { Range = 8, Brightness = 2, Parent = sphere }) }
					end
					parImage = function(p, i, t)
						for k, s in spheres do
							local angle = t * (5 + k * 0.4) * (k % 2 == 0 and 1 or -1) + k
							local rayon = 3.2 - 1.2 * i
							local hauteur = math.sin(t * 2 + k) * 2.4
							s.part.CFrame = racine.CFrame * CFrame.new(math.cos(angle) * rayon, hauteur, math.sin(angle) * rayon)
							local couleur = Color3.fromHSV((t * 0.25 + k / 6) % 1, 0.75, 1)
							s.part.Color = couleur
							s.trainee.Color = ColorSequence.new(couleur)
							s.lumiere.Color = couleur
							s.part.Transparency = 1 - math.clamp(i * 1.5, 0, 1)
						end
						lumiere.Color = Color3.fromHSV((t * 0.25) % 1, 0.5, 1)
					end
					-- Pour celui qui se régénère : un kaléidoscope qui tourne devant les yeux
					if moi then
						local kaleido = garder(creer("ScreenGui", { Name = "TardisRegenKaleidoscope", ResetOnSpawn = false, IgnoreGuiInset = true, Parent = joueur.PlayerGui }))
						local cadre = creer("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(2.2, 2.2),
							BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = kaleido })
						local degrade = creer("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0.8, 1)),
							ColorSequenceKeypoint.new(0.2, Color3.fromHSV(0.12, 0.8, 1)), ColorSequenceKeypoint.new(0.4, Color3.fromHSV(0.33, 0.8, 1)),
							ColorSequenceKeypoint.new(0.6, Color3.fromHSV(0.55, 0.8, 1)), ColorSequenceKeypoint.new(0.8, Color3.fromHSV(0.8, 0.8, 1)),
							ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 0.8, 1)) }), Parent = cadre })
						local ancien = parImage
						parImage = function(p, i, t)
							ancien(p, i, t)
							degrade.Rotation = (t * 140) % 360
							cadre.Rotation = -(t * 40) % 360
							cadre.BackgroundTransparency = 1 - 0.45 * i
						end
					end
					secousseMax, couleurAmbiance = 0.6, Color3.fromRGB(255, 200, 255)
				elseif style == 5 then
					-- COLONNE (bigénération) : une colonne de lumière descend du ciel, un sceau gallifreyen s'allume au sol
					panachesTeteEtMains(1.1)
					local colonne = garder(partTemporaire({ Name = "TardisRegenColonne", Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon,
						Color = OR_CLAIR, Transparency = 1, Size = Vector3.new(240, 0.4, 0.4), CFrame = CFrame.new(sol + Vector3.new(0, 120, 0)) * CFrame.Angles(0, 0, math.pi / 2) }))
					local halo = garder(partTemporaire({ Name = "TardisRegenColonneHalo", Shape = Enum.PartType.Cylinder, Material = Enum.Material.ForceField,
						Color = OR, Transparency = 1, Size = Vector3.new(240, 1, 1), CFrame = colonne.CFrame }))
					-- Le sceau : des cercles concentriques et de petits cercles, tracés en lumière (écriture gallifreyenne)
					local sceau = garder(partTemporaire({ Name = "TardisRegenSceau", Transparency = 1, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(sol + Vector3.new(0, 0.15, 0)) }))
					local traits = {}
					local function cercle(centre, rayon, segments, largeur)
						local points = {}
						for k = 0, segments - 1 do
							local a = k / segments * math.pi * 2
							points[k + 1] = creer("Attachment", { Position = centre + Vector3.new(math.cos(a) * rayon, 0, math.sin(a) * rayon), Parent = sceau })
						end
						for k = 1, segments do
							table.insert(traits, creer("Beam", { Attachment0 = points[k], Attachment1 = points[k % segments + 1], Width0 = largeur, Width1 = largeur,
								LightEmission = 1, LightInfluence = 0, Segments = 1, Color = ColorSequence.new(OR_CLAIR), Transparency = NumberSequence.new(1),
								FaceCamera = false, Parent = sceau }))
						end
					end
					cercle(Vector3.zero, 7, 40, 0.25)
					cercle(Vector3.zero, 5.4, 32, 0.15)
					cercle(Vector3.zero, 2.4, 20, 0.2)
					for k = 1, 6 do
						local a = k / 6 * math.pi * 2
						cercle(Vector3.new(math.cos(a) * 6.2, 0, math.sin(a) * 6.2), 0.7 + (k % 3) * 0.25, 14, 0.12)
					end
					local socle = garder(partTemporaire({ Name = "TardisRegenSocle", Transparency = 1, Size = Vector3.new(5, 0.2, 5), CFrame = CFrame.new(sol) }))
					emetteur(socle, { Texture = ETINCELLE, LightEmission = 1, Color = ColorSequence.new(BLANC_OR, OR), Size = NumberSequence.new(0.5, 0),
						Speed = NumberRange.new(16, 28), Lifetime = NumberRange.new(1.5, 2.5), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(8, 8) }, 90, 0.15)
					parImage = function(p, i, t)
						local ouverture = math.clamp(i * 1.2, 0, 1)
						colonne.Size = Vector3.new(240, 0.4 + 6.5 * ouverture, 0.4 + 6.5 * ouverture)
						colonne.Transparency = 1 - 0.6 * ouverture
						halo.Size = Vector3.new(240, 1 + 12 * ouverture, 1 + 12 * ouverture)
						halo.Transparency = 1 - 0.5 * ouverture
						sceau.CFrame = CFrame.new(sol + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, t * 0.6, 0)
						local transparence = NumberSequence.new(1 - 0.9 * math.clamp(p / 0.3, 0, 1) * (p > 0.85 and (1 - p) / 0.15 or 1))
						for _, trait in traits do trait.Transparency = transparence end
					end
					secousseMax = 0.7
				else
					-- CLASSIQUE (9e → 10e Docteur) : la tête renversée, les bras écartés, les flammes dorées jaillissent
					panachesTeteEtMains(1.2)
				end

				-- Son (optionnel) : TardisAssets > Sons > Regeneration
				local assets = ReplicatedStorage:FindFirstChild("TardisAssets")
				local modeleSon = assets and assets:FindFirstChild("Sons") and assets.Sons:FindFirstChild("Regeneration")
				if modeleSon and modeleSon:IsA("Sound") then
					local son = garder(modeleSon:Clone())
					son.Parent = racine
					son:Play()
				end

				-- Ambiance : la lumière dorée envahit l'image de ceux qui sont proches
				local teinte = garder(creer("ColorCorrectionEffect", { Name = "TardisRegenTeinte", TintColor = Color3.new(1, 1, 1), Parent = Lighting }))
				local eclat = garder(creer("BloomEffect", { Name = "TardisRegenEclat", Intensity = 0, Size = 32, Threshold = 0.85, Parent = Lighting }))

				-- Caméra : celui qui se régénère voit la scène de l'extérieur, la caméra tourne lentement autour de lui
				local cinematique = moi and REG.CameraCinematique ~= false
				local angleDepart = 0
				if cinematique then
					local regard = racine.CFrame.LookVector
					angleDepart = math.atan2(regard.Z, regard.X)
					camera.CameraType = Enum.CameraType.Scriptable
				end
				local function rendreCamera()
					if cinematique then
						cinematique = false
						camera.CameraType = Enum.CameraType.Custom
						local h = joueur.Character and joueur.Character:FindFirstChildOfClass("Humanoid")
						if h then camera.CameraSubject = h end
					end
				end

				-- Courbe d'intensité : montée (0-15 %), éruption (15-55 %), changement et pleine puissance (55-80 %), dissipation
				local function intensite(p)
					if p < 0.15 then return 0.18 * (p / 0.15) end
					if p < 0.55 then local q = (p - 0.15) / 0.4 return 0.18 + 0.82 * q * q end
					if p < 0.8 then return 1 end
					if p < 1 then return 1 - (p - 0.8) / 0.2 end
					return 0
				end
				local depart = os.clock()
				local flashFait = false
				table.insert(connexions, RunService.RenderStepped:Connect(function()
					local t = os.clock() - depart
					local p = math.clamp(t / duree, 0, 1)
					local i = intensite(p)
					local vacillement = (p > 0.2 and p < 0.85) and (0.9 + 0.1 * math.noise(t * 7, 0.5, 0.5) * 2) or 1
					-- Débit des flammes et des étincelles
					for _, f in flux do f.e.Rate = (p >= f.seuil and p < 0.9) and f.debit * i * vacillement or 0 end
					-- Lueur et lumière
					lueur.FillTransparency = 1 - 0.7 * i
					lueur.OutlineTransparency = 1 - i
					lumiere.Brightness = 14 * i * vacillement
					lumiere.Range = 10 + 45 * i
					lumiereTete.Brightness = 6 * i
					-- Ambiance, selon la distance
					local distance = (camera.CFrame.Position - racine.Position).Magnitude
					local proche = math.clamp(1 - distance / 90, 0, 1) * i
					teinte.TintColor = Color3.new(1, 1, 1):Lerp(couleurAmbiance, 0.35 * proche)
					teinte.Brightness = 0.12 * proche
					eclat.Intensity = 1.4 * proche
					if proche > 0.05 then secouer(secousseMax * proche * (moi and 1 or 0.6)) end
					-- Caméra cinématique
					if cinematique and tete.Parent then
						local angle = angleDepart + p * 2.4
						local rayon = 9.5 - 2.5 * i
						local cible = tete.Position + Vector3.new(0, 0.3, 0)
						camera.CFrame = CFrame.lookAt(cible + Vector3.new(math.cos(angle) * rayon, 1.6 + 1.4 * i, math.sin(angle) * rayon), cible)
					end
					-- Au moment du changement : la lumière avale tout l'écran de celui qui se régénère
					if moi and not flashFait and p >= 0.5 then
						flashFait = true
						local flash = creer("ScreenGui", { Name = "TardisRegenerationFlash", ResetOnSpawn = false, IgnoreGuiInset = true, Parent = joueur.PlayerGui })
						local voile = creer("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = couleurFlash, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = flash })
						animer(voile, duree * 0.05, { BackgroundTransparency = 0 })
						task.delay(duree * 0.12, function() animer(voile, duree * 0.35, { BackgroundTransparency = 1 }) end)
						task.delay(duree * 0.6, function() flash:Destroy() end)
					end
					if parImage then parImage(p, i, t) end
					if p >= 1 or not racine.Parent then rendreCamera() end
				end))

				-- Lien Time Lord : les autres Voyageurs ressentent la régénération, où qu'ils soient
				if not moi and ReplicatedStorage:GetAttribute("TardisLienTimeLord") == true and joueur.Team
					and joueur.Team.Name == (REG.Equipe or "Le Voyageur") then
					local autre = Players:GetPlayerFromCharacter(personnage)
					local maRacine_ = maRacine()
					local distance = maRacine_ and math.floor((maRacine_.Position - racine.Position).Magnitude) or 0
					local lien = creer("ScreenGui", { Name = "TardisLienTimeLord", ResetOnSpawn = false, IgnoreGuiInset = true, Parent = joueur.PlayerGui })
					local voile = creer("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = OR_CLAIR, BackgroundTransparency = 0.75, BorderSizePixel = 0, Parent = lien })
					animer(voile, 1.5, { BackgroundTransparency = 1 })
					task.delay(1.6, function() lien:Destroy() end)
					secouer(0.15)
					pcall(function()
						game:GetService("StarterGui"):SetCore("SendNotification", { Title = "Lien Time Lord",
							Text = string.format("%s se régénère (%d studs).", autre and autre.DisplayName or "Un Voyageur", distance), Duration = 6 })
					end)
				end

				-- Après : un souffle doré s'échappe du nouveau visage, les mains fument encore un moment
				task.delay(duree, function()
					rendreCamera()
					if tete.Parent then
						local souffle = creer("ParticleEmitter", { Texture = FUMEE, LightEmission = 1, Color = ColorSequence.new(OR_CLAIR, OR),
							Size = NumberSequence.new(0.3, 1.4), Transparency = NumberSequence.new(0.2, 1), Speed = NumberRange.new(3, 6),
							Lifetime = NumberRange.new(0.8, 1.3), SpreadAngle = Vector2.new(15, 15), EmissionDirection = Enum.NormalId.Front, Rate = 0, Parent = tete })
						task.delay(0.4, function() if souffle.Parent then souffle:Emit(35) end end)
						task.delay(2.5, function() souffle:Destroy() end)
					end
					for _, main in mains do
						if main.Parent then
							local volutes = creer("ParticleEmitter", { Texture = FUMEE, LightEmission = 1, Color = ColorSequence.new(OR_CLAIR, OR),
								Size = NumberSequence.new(0.15, 0.5), Transparency = NumberSequence.new(0.4, 1), Speed = NumberRange.new(0.5, 1.2),
								Lifetime = NumberRange.new(0.6, 1), SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, 2, 0), Rate = 14, Parent = main.Parent })
							task.delay(3.5, function() volutes.Enabled = false task.delay(1.2, function() volutes:Destroy() end) end)
						end
					end
					task.delay(1.2, function()
						for _, c in connexions do c:Disconnect() end
						for _, objet in aDetruire do if objet.Parent then objet:Destroy() end end
					end)
				end)
			end
			personnage:GetAttributeChangedSignal("TardisRegeneration"):Connect(effets)
			-- Corps neuf (après un corps disloqué) : la régénération a pu commencer avant qu'on l'écoute
			task.delay(0.3, effets)
		end
		for _, autre in Players:GetPlayers() do
			if autre.Character then surveillerRegeneration(autre.Character) end
			autre.CharacterAdded:Connect(surveillerRegeneration)
		end
		Players.PlayerAdded:Connect(function(autre) autre.CharacterAdded:Connect(surveillerRegeneration) end)

		-- Son propre personnage : pas de mort normale tant qu'il peut se régénérer (le serveur fait de même)
		local function surveillerMoi(personnage)
			local humanoid = personnage:WaitForChild("Humanoid", 10)
			if not humanoid then return end
			local function maj()
				local regenerateur = personnage:GetAttribute("TardisRegenerateur") == true and personnage:GetAttribute("TardisMortReelle") ~= true
				humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, not regenerateur)
				if personnage:GetAttribute("TardisMortReelle") == true then
					humanoid.Health = 0
					humanoid:ChangeState(Enum.HumanoidStateType.Dead)
				end
			end
			personnage:GetAttributeChangedSignal("TardisRegenerateur"):Connect(maj)
			personnage:GetAttributeChangedSignal("TardisMortReelle"):Connect(maj)
			maj()
			-- Le choix : se régénérer ou refuser (quelques secondes)
			personnage:GetAttributeChangedSignal("TardisRegenChoix"):Connect(function()
				local fin = personnage:GetAttribute("TardisRegenChoix")
				local ancien = joueur.PlayerGui:FindFirstChild("TardisRegenChoix")
				if ancien then ancien:Destroy() end
				if not fin then return end
				local gui = creer("ScreenGui", { Name = "TardisRegenChoix", ResetOnSpawn = false, IgnoreGuiInset = true, Parent = joueur.PlayerGui })
				creer("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 200, 100), BackgroundTransparency = 0.85, BorderSizePixel = 0, Parent = gui })
				local carte = creer("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.62), Size = UDim2.fromOffset(380, 0),
					AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.fond, BackgroundTransparency = 0.05, Parent = gui },
				{ UI.coin(14), UI.contour(C.ambre, 2, 0.2), UI.marges(14), UI.pile(8) })
				texte({ Text = "◆  L'ÉNERGIE DE RÉGÉNÉRATION MONTE", Font = UI.POLICE_GRAS, TextSize = 14, TextColor3 = C.ambre, LayoutOrder = 1, Parent = carte })
				texte({ Text = "Ne rien faire : tu te régénères. Refuser : c'est la fin de cette vie.", TextSize = 12, TextColor3 = C.texte, TextWrapped = true,
					AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = carte })
				local fond = creer("Frame", { Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = C.gris, LayoutOrder = 3, Parent = carte }, { UI.coin(99) })
				local barre = creer("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.ambre, Parent = fond }, { UI.coin(99) })
				local reste = math.max(fin - workspace:GetServerTimeNow(), 0.1)
				animer(barre, reste, { Size = UDim2.fromScale(0, 1) }, Enum.EasingStyle.Linear)
				local bouton = creer("TextButton", { Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = Color3.fromRGB(120, 35, 40), Text = "Refuser la régénération",
					Font = UI.POLICE_GRAS, TextSize = 13, TextColor3 = C.texte, LayoutOrder = 4, Parent = carte }, { UI.coin(8) })
				bouton:SetAttribute("CouleurBase", Color3.fromRGB(120, 35, 40))
				UI.rendreVivant(bouton)
				bouton.Activated:Connect(function()
					remote:FireServer("RefuserRegeneration")
					gui:Destroy()
				end)
				task.delay(reste + 0.2, function() if gui.Parent then gui:Destroy() end end)
			end)
		end
		joueur.CharacterAdded:Connect(surveillerMoi)
		if joueur.Character then task.spawn(surveillerMoi, joueur.Character) end

		-- Avatars sauvegardés : Roblox demande au joueur la permission de les lire, une fois, quand il rejoint l'équipe
		if (Config.Regeneration or {}).TenuesDuCompte ~= false then
			local AvatarEditorService = game:GetService("AvatarEditorService")
			local function notifier(texte)
				pcall(function()
					game:GetService("StarterGui"):SetCore("SendNotification", { Title = "Régénération", Text = texte, Duration = 6 })
				end)
			end
			local dejaDemande = false
			local function envoyerTenues()
				local equipe = (Config.Regeneration or {}).Equipe or "Le Voyageur"
				if dejaDemande or not (joueur.Team and joueur.Team.Name == equipe) then return end
				dejaDemande = true
				task.spawn(function()
					local okPrompt = pcall(function() AvatarEditorService:PromptAllowInventoryReadAccess() end)
					if not okPrompt then return end
					local resultat = AvatarEditorService.PromptAllowInventoryReadAccessCompleted:Wait()
					if resultat ~= Enum.AvatarPromptResult.Success then
						notifier("Sans accès à tes avatars, la régénération utilisera les tenues du jeu.")
						return
					end
					local okPages, pages = pcall(function() return AvatarEditorService:GetOutfits(Enum.OutfitSource.Created, Enum.OutfitType.Avatar) end)
					if not okPages or not pages then return end
					local ids = {}
					while #ids < 50 do
						for _, tenue in pages:GetCurrentPage() do
							if tenue.Id then table.insert(ids, tenue.Id) end
						end
						if pages.IsFinished then break end
						if not pcall(function() pages:AdvanceToNextPageAsync() end) then break end
					end
					if #ids > 0 then
						remote:FireServer("TenuesCompte", { ids = ids })
						notifier(string.format("%d avatar(s) de ton compte disponibles.", #ids))
					else
						notifier("Aucun avatar sauvegardé sur ton compte : la régénération utilisera les tenues du jeu.")
					end
				end)
			end
			joueur:GetPropertyChangedSignal("Team"):Connect(envoyerTenues)
			envoyerTenues()
		end
	end

	--------------------------------------------------------------------
	-- 18 bis) Régénération à bord de ce TARDIS : la console crache des étincelles, la salle tremble
	--------------------------------------------------------------------
	exterieur:GetAttributeChangedSignal("RegenerationABord"):Connect(function()
		local console = interieur:FindFirstChild("Console")
		if console then
			local pieces = {}
			for _, objet in console:GetDescendants() do
				if objet:IsA("BasePart") and objet.Size.Magnitude > 0.8 then table.insert(pieces, objet) end
			end
			for _ = 1, math.min(6, #pieces) do
				local part = table.remove(pieces, math.random(#pieces))
				local point = creer("Attachment", { Parent = part })
				local etincelles = creer("ParticleEmitter", { Color = ColorSequence.new(Color3.fromRGB(255, 235, 150), Color3.fromRGB(255, 120, 30)), LightEmission = 1,
					Size = NumberSequence.new(0.25, 0), Speed = NumberRange.new(8, 18), Lifetime = NumberRange.new(0.3, 0.7), SpreadAngle = Vector2.new(90, 90),
					Acceleration = Vector3.new(0, -30, 0), Rate = 0, Parent = point })
				for k = 0, 3 do task.delay(k * 0.6, function() etincelles:Emit(25) end) end
				task.delay(4, function() point:Destroy() end)
			end
		end
		if jeSuisDedans() then secouer(0.7) end
	end)

	return {}
end
