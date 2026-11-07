-- StarterPlayerScripts > TardisExtrasClient > Regeneration (ModuleScript)
-- Régénération (équipe C.A.T., Config.Equipe) et régénération à bord
-- Extrait du script principal en V6.6.3 ; animations refaites en V6.7 (sauf le Tourbillon, gardé tel quel).

return function(contexte)
	local C, Config, Lighting, Players, ReplicatedStorage, RunService = contexte.C, contexte.Config, contexte.Lighting, contexte.Players, contexte.ReplicatedStorage, contexte.RunService
	local UI, animer, camera, creer, def, exterieur = contexte.UI, contexte.animer, contexte.camera, contexte.creer, contexte.def, contexte.exterieur
	local interieur, jeSuisDedans, joueur, maRacine, partTemporaire, remote = contexte.interieur, contexte.jeSuisDedans, contexte.joueur, contexte.maRacine, contexte.partTemporaire, contexte.remote
	local secouer, texte = contexte.secouer, contexte.texte
	local Debris = game:GetService("Debris")
	local UserInputService = game:GetService("UserInputService")
	local ContextActionService = nil -- (V7.5.1) touche pour passer la scène
	pcall(function() ContextActionService = game:GetService("ContextActionService") end)

	--------------------------------------------------------------------
	-- 18) Régénération (équipe C.A.T.) : l'énergie monte sous la peau, jaillit de la tête et des mains en
	-- jets solides (Beams) habillés de flammes, le changement d'apparence est caché par un éclat de lumière, puis
	-- l'énergie se dissipe et le nouveau visage fume encore pendant un moment.
	-- Un seul exemplaire du script s'en occupe (celui du premier TARDIS).
	--------------------------------------------------------------------
	if def.Nom == Config.Tardis[1].Nom then
		local FEU = "rbxasset://textures/particles/fire_main.dds"
		local FUMEE = "rbxasset://textures/particles/smoke_main.dds"
		local ETINCELLE = "rbxasset://textures/particles/sparkles_main.dds"
		local CINEMA = (Config.Regeneration or {}).Cinema or {} -- V7.5.1

		-- (V7.5.1) Caméra de cinéma de celui qui se régénère : trajet propre au style (G-236), profondeur de champ (G-233),
		-- bandes noires (G-234), braises devant l'objectif (G-264), plan final sur le nouveau visage (G-235) et une touche
		-- pour passer la scène (G-238). o = { personnage, tete, racine, style, reduit }.
		-- scene.image(p, i, t) à chaque image ; scene.fin() à la fin (plan final, puis la caméra rendue) ; scene.rendre()
		-- rend la caméra tout de suite.
		local function cameraCinema(o)
			local tete, racine = o.tete, o.racine
			local scene = { actif = true }
			-- (V7.1.1, G-237) L'orbite ne traverse plus les murs : un rayon de la tête vers la caméra la rapproche
			local paramsCamera = RaycastParams.new()
			paramsCamera.FilterType = Enum.RaycastFilterType.Exclude
			paramsCamera.FilterDescendantsInstances = { o.personnage }
			paramsCamera.RespectCanCollide = true
			local champOrigine = camera.FieldOfView
			local regard = racine.CFrame.LookVector
			local angleDepart = math.atan2(regard.Z, regard.X)
			camera.CameraType = Enum.CameraType.Scriptable
			local style = CINEMA.TrajetParStyle ~= false and o.style or 1
			local debutFinal, connexionFinal, connexionTouche = nil, nil, nil

			-- G-233 : mise au point sur la tête
			local flou = nil
			if CINEMA.ProfondeurDeChamp ~= false then
				flou = creer("DepthOfFieldEffect", { Name = "TardisRegenFlou", FocusDistance = 9, InFocusRadius = CINEMA.ZoneNette or 3,
					FarIntensity = CINEMA.FlouFond or 0.6, NearIntensity = CINEMA.FlouAvant or 0.35, Parent = camera })
			end
			-- G-234 : bandes noires, qui glissent depuis les bords ; l'aide de la touche est écrite dans la bande du bas
			local ecran = creer("ScreenGui", { Name = "TardisRegenCinema", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 40, Parent = joueur.PlayerGui })
			local NOIR = Color3.new(0, 0, 0)
			local bandeHaut = creer("Frame", { Name = "BandeHaut", BackgroundColor3 = NOIR, BorderSizePixel = 0, Size = UDim2.fromScale(1, 0), Parent = ecran })
			local bandeBas = creer("Frame", { Name = "BandeBas", BackgroundColor3 = NOIR, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0), Parent = ecran })
			local hauteurBandes = CINEMA.BandesNoires ~= false and (CINEMA.HauteurBandes or 0.11) or 0
			if hauteurBandes > 0 then
				animer(bandeHaut, 0.5, { Size = UDim2.fromScale(1, hauteurBandes) })
				animer(bandeBas, 0.5, { Size = UDim2.fromScale(1, hauteurBandes) })
			end
			local touche = CINEMA.TouchePasser or "Space"
			creer("TextLabel", { Name = "Passer", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -8), Size = UDim2.fromOffset(300, 22),
				BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(200, 200, 200), TextTransparency = 0.2, Font = Enum.Font.Gotham, TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Right, Text = (touche == "Space" and "Espace" or touche) .. " : passer la scène", Parent = ecran })
			-- G-264 : quelques braises tout près de l'objectif (floues avec la profondeur de champ)
			local porteBraises, braises = nil, nil
			if CINEMA.Braises ~= false and not o.reduit then
				porteBraises = creer("Part", { Name = "TardisRegenBraisesObjectif", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
					Transparency = 1, Size = Vector3.new(6, 4, 0.2), CFrame = camera.CFrame * CFrame.new(0, 0, -2.5), Parent = workspace })
				braises = creer("ParticleEmitter", { Name = "Braises", Texture = ETINCELLE, LightEmission = 1,
					Color = ColorSequence.new(Color3.fromRGB(255, 225, 120), Color3.fromRGB(255, 105, 20)),
					Size = NumberSequence.new(0.18, 0.04), Transparency = NumberSequence.new(0.25, 1), Speed = NumberRange.new(0.6, 1.6),
					Lifetime = NumberRange.new(0.8, 1.4), SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, 1.5, 0), Rate = 0, Parent = porteBraises })
			end

			function scene.rendre()
				if not scene.actif then return end
				scene.actif = false
				if connexionFinal then connexionFinal:Disconnect() end
				if connexionTouche then connexionTouche:Disconnect() end
				if ContextActionService then ContextActionService:UnbindAction("TardisRegenPasser") end
				camera.CameraType = Enum.CameraType.Custom
				camera.FieldOfView = champOrigine
				local h = joueur.Character and joueur.Character:FindFirstChildOfClass("Humanoid")
				if h then camera.CameraSubject = h end
				if flou then flou:Destroy() end
				if porteBraises then porteBraises:Destroy() end
				animer(bandeHaut, 0.4, { Size = UDim2.fromScale(1, 0) })
				animer(bandeBas, 0.4, { Size = UDim2.fromScale(1, 0) })
				task.delay(0.45, function() ecran:Destroy() end)
			end

			-- G-238 : la touche rend la caméra (les autres voient toujours l'effet)
			if ContextActionService then
				ContextActionService:BindActionAtPriority("TardisRegenPasser", function(_, etat)
					if etat == Enum.UserInputState.Begin then scene.rendre() end
					return Enum.ContextActionResult.Sink
				end, true, Enum.ContextActionPriority.High.Value, Enum.KeyCode[touche], Enum.KeyCode.ButtonB)
				ContextActionService:SetTitle("TardisRegenPasser", "Passer")
			else
				connexionTouche = UserInputService.InputBegan:Connect(function(input)
					if input.KeyCode == Enum.KeyCode[touche] or input.KeyCode == Enum.KeyCode.ButtonB then scene.rendre() end
				end)
			end

			local function placer(position, vise)
				camera.CFrame = CFrame.lookAt(position, vise)
				if flou then flou.FocusDistance = (position - tete.Position).Magnitude end
			end

			function scene.image(p, i, t)
				if not scene.actif or debutFinal or not tete.Parent then return end
				local trajet = Config.trajetCinema(style, p, i, angleDepart)
				local respiration = Vector3.new(math.noise(t * 0.6, 1, 1) * 0.25, math.noise(t * 0.5, 2, 2) * 0.2, 0)
				local cible = tete.Position + Vector3.new(0, 0.3, 0)
				local decalage = Vector3.new(math.cos(trajet.angle) * trajet.rayon, trajet.hauteur, math.sin(trajet.angle) * trajet.rayon)
				local obstacle = workspace:Raycast(cible, decalage, paramsCamera)
				if obstacle then decalage = decalage.Unit * math.max((obstacle.Position - cible).Magnitude - 0.6, 1.5) end
				placer(cible + decalage + respiration, cible + Vector3.new(0, trajet.visee, 0))
				local zoom = math.clamp(1 - math.abs(p - 0.55) / 0.12, 0, 1) * trajet.zoom
				if not UI.champFixe() then camera.FieldOfView = champOrigine - 14 * zoom * zoom end -- (V7.4.1, G-280)
				if porteBraises then
					porteBraises.CFrame = camera.CFrame * CFrame.new(0, 0, -2.5)
					braises.Rate = (CINEMA.DebitBraises or 10) * i
				end
			end

			-- G-235 : plan final devant le nouveau visage, qui s'approche doucement, puis la caméra est rendue
			function scene.fin()
				if not scene.actif or debutFinal then return end
				if CINEMA.PlanFinal == false or not tete.Parent or not racine.Parent then
					scene.rendre()
					return
				end
				debutFinal = os.clock()
				if braises then braises.Rate = 0 end
				camera.FieldOfView = champOrigine
				local dureePlan = CINEMA.DureePlanFinal or 2
				local distance = CINEMA.DistancePlanFinal or 3.2
				connexionFinal = RunService.RenderStepped:Connect(function()
					local t = os.clock() - debutFinal
					if t >= dureePlan or not tete.Parent then
						scene.rendre()
						return
					end
					local q = math.sin(math.clamp(t / dureePlan, 0, 1) * math.pi / 2)
					local position = Config.positionPlanFinal(tete.Position, tete.CFrame.LookVector, distance * (1 - 0.2 * q))
					local obstacle = workspace:Raycast(tete.Position, position - tete.Position, paramsCamera)
					if obstacle then position = tete.Position + (position - tete.Position).Unit * math.max((obstacle.Position - tete.Position).Magnitude - 0.4, 1) end
					placer(position, tete.Position)
				end)
			end
			return scene
		end

		-- (V7.5.1, G-240) Pour les témoins : l'or vient du bord de l'écran tourné vers la régénération.
		-- vignette.maj(position, force) à chaque image ; l'écran est rendu par la fonction pour être détruit à la fin.
		local function vignetteTemoin(couleur)
			local ecran = creer("ScreenGui", { Name = "TardisRegenVignette", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 35, Enabled = false, Parent = joueur.PlayerGui })
			local degrades = {}
			for _, b in { { "Gauche", UDim2.fromScale(0, 0), UDim2.fromScale(0.3, 1), 0 }, { "Droite", UDim2.fromScale(0.7, 0), UDim2.fromScale(0.3, 1), 180 },
				{ "Haut", UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.3), 90 }, { "Bas", UDim2.fromScale(0, 0.7), UDim2.fromScale(1, 0.3), -90 } } do
				local bord = creer("Frame", { Name = b[1], BorderSizePixel = 0, BackgroundColor3 = couleur, Position = b[2], Size = b[3], Parent = ecran })
				table.insert(degrades, creer("UIGradient", { Rotation = b[4], Transparency = NumberSequence.new(1), Parent = bord }))
			end
			local vignette = { ecran = ecran }
			function vignette.maj(position, force)
				ecran.Enabled = force > 0.01
				if not ecran.Enabled then return end
				local poids = { Config.poidsBordsRegen(camera.CFrame:VectorToObjectSpace(position - camera.CFrame.Position)) }
				for k, degrade in degrades do
					degrade.Transparency = NumberSequence.new(1 - math.clamp(poids[k] * force, 0, 1) * (CINEMA.ForceVignette or 0.55), 1)
				end
			end
			return vignette
		end

		local CORPS = (Config.Regeneration or {}).Corps or {} -- V7.5.2

		-- (V7.5.2, G-209) Copie d'un accessoire, préparée avant le changement : la pièce seule, sans soudure ni attache, prête à
		-- brûler à l'endroit où elle était quand le serveur retire l'accessoire. nil si l'accessoire ne se copie pas.
		local function copieAccessoire(accessoire)
			local poignee = accessoire:FindFirstChild("Handle")
			if not poignee or not poignee:IsA("BasePart") then return nil end
			local ok, copie = pcall(function() return poignee:Clone() end)
			if not ok or not copie then return nil end
			for _, d in copie:GetDescendants() do
				if d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("Attachment") or d:IsA("BaseScript")
					or d:IsA("ParticleEmitter") or d:IsA("Sound") then d:Destroy() end
			end
			copie.Name = "TardisRegenCendre"
			copie.Anchored, copie.CanCollide, copie.CanQuery, copie.CanTouch, copie.Massless = true, false, false, false, true
			return { copie = copie, poignee = poignee, cf = poignee.CFrame }
		end

		-- (V7.5.2, G-209) L'ancien accessoire rougeoie, se met à tomber en tournant et part en cendres. Renvoie la copie.
		local function brulerAccessoire(c, solY, reduit)
			local copie, depart = c.copie, c.cf
			copie.CFrame = depart
			copie.Parent = workspace
			creer("Highlight", { Name = "Braise", FillColor = Color3.fromRGB(255, 70, 20), OutlineColor = Color3.fromRGB(255, 170, 60),
				FillTransparency = 0.15, OutlineTransparency = 0.3, DepthMode = Enum.HighlightDepthMode.Occluded, Parent = copie })
			if not reduit then
				local cendres = creer("ParticleEmitter", { Name = "Cendres", Texture = FUMEE, Color = ColorSequence.new(Color3.fromRGB(90, 70, 60), Color3.fromRGB(30, 28, 26)),
					Size = NumberSequence.new(0.25, 0.05), Transparency = NumberSequence.new(0.2, 1), Speed = NumberRange.new(0.5, 2),
					Lifetime = NumberRange.new(0.8, 1.6), SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, -4, 0), Rate = 0, Parent = copie })
				cendres:Emit(20)
			end
			local duree = CORPS.DureeCendres or 1.4
			local chute = math.max(depart.Position.Y - (solY or depart.Position.Y - 3) - 0.2, 0)
			animer(copie, duree, { CFrame = CFrame.new(0, -chute, 0) * depart * CFrame.Angles(0.7, 0, 0.4), Transparency = 1, Size = copie.Size * 0.4 }, Enum.EasingStyle.Quad)
			Debris:AddItem(copie, duree + 0.6)
			return copie
		end

		-- (V7.5.2, G-210) Les nouveaux accessoires apparaissent un par un, chacun avec une étincelle.
		-- suivi.ajouter(accessoire, t) quand un accessoire arrive ; suivi.maj(t) à chaque image ; suivi.finir() rend tout visible.
		local function apparitionsAccessoires(reduit)
			local suivi, file, dernier = {}, {}, -math.huge
			local intervalle, dureeFondu = CORPS.IntervalleApparition or 0.25, CORPS.DureeApparition or 0.5
			function suivi.ajouter(accessoire, t)
				local poignee = accessoire:FindFirstChild("Handle")
				if not poignee or not poignee:IsA("BasePart") then return end
				poignee.LocalTransparencyModifier = 1
				dernier = math.max(t, dernier + intervalle)
				table.insert(file, { poignee = poignee, debut = dernier })
			end
			function suivi.maj(t)
				for k = #file, 1, -1 do
					local a = file[k]
					if not a.poignee.Parent then
						table.remove(file, k)
					elseif t >= a.debut then
						if not a.etincelle then
							a.etincelle = true
							local e = creer("ParticleEmitter", { Name = "TardisRegenEtincelle", Texture = ETINCELLE, LightEmission = 1,
								Color = ColorSequence.new(Color3.fromRGB(255, 250, 225), Color3.fromRGB(255, 170, 50)), Size = NumberSequence.new(0.3, 0),
								Speed = NumberRange.new(2, 6), Lifetime = NumberRange.new(0.3, 0.6), SpreadAngle = Vector2.new(180, 180), Rate = 0, Parent = a.poignee })
							e:Emit(reduit and 4 or 14)
							Debris:AddItem(e, 1)
						end
						local reste = Config.fonduApparition(t, a.debut, dureeFondu)
						a.poignee.LocalTransparencyModifier = reste
						if reste <= 0 then table.remove(file, k) end
					end
				end
			end
			function suivi.finir()
				for _, a in file do if a.poignee.Parent then a.poignee.LocalTransparencyModifier = 0 end end
				table.clear(file)
			end
			function suivi.enAttente() return #file end
			return suivi
		end

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
				local reduit = UI.effetsReduits()
				local sansFlash = UI.sansFlash() -- « aucun flash » (V6.9.9) : ni éclat, ni explosion de lumière, ni voile blanc
				-- (V7.5.4, G-217) Sous l'eau ? (il nage, ou l'eau du Terrain l'entoure)
				local LIEU = REG.Lieu or {}
				local sousEau = false
				if LIEU.SousEau ~= false then
					local occupation = 0
					pcall(function()
						local region = Region3.new(racine.Position - Vector3.new(2, 2, 2), racine.Position + Vector3.new(2, 2, 2)):ExpandToGrid(4)
						local materiaux, occupations = workspace.Terrain:ReadVoxels(region, 4)
						local taille = materiaux.Size
						for x = 1, taille.X do
							for y = 1, taille.Y do
								for z = 1, taille.Z do
									if materiaux[x][y][z] == Enum.Material.Water then occupation = math.max(occupation, occupations[x][y][z]) end
								end
							end
						end
					end)
					sousEau = Config.sousEau(humanoid and humanoid:GetState().Name, occupation)
				end

				-- Palette de la série : cœur blanc-jaune, flammes dorées, bords orange
				local BLANC_OR, OR_CLAIR, OR, ORANGE = Color3.fromRGB(255, 250, 225), Color3.fromRGB(255, 225, 120), Color3.fromRGB(255, 170, 50), Color3.fromRGB(255, 105, 20)
				local BLANC = Color3.new(1, 1, 1)
				local aDetruire, flux, connexions, jets = {}, {}, {}, {}
				local function garder(objet) table.insert(aDetruire, objet) return objet end
				-- Un émetteur dont le débit suit l'intensité de la régénération (montée, éruption, dissipation)
				local function emetteur(parent, proprietes, debitMax, seuil)
					proprietes.Parent = parent
					proprietes.Rate = 0
					if sousEau and proprietes.Texture == FEU then
						-- (V7.5.4, G-217) sous l'eau, les flammes deviennent des bulles qui montent
						proprietes.Texture = ETINCELLE
						proprietes.Color = ColorSequence.new(Color3.fromRGB(235, 248, 255), Color3.fromRGB(170, 215, 245))
						proprietes.LightEmission = 0.4
						proprietes.Acceleration = Vector3.new(0, 8, 0)
						proprietes.Drag = 3
					end
					local e = garder(creer("ParticleEmitter", proprietes))
					table.insert(flux, { e = e, debit = debitMax, seuil = seuil or 0 })
					return e
				end
				-- Jet d'énergie : un faisceau solide (Beam) qui part du corps et s'allonge avec l'intensité, légèrement courbé
				local function jet(part, origine, direction, longueur, largeur, couleurs)
					couleurs = couleurs or { BLANC_OR, OR, ORANGE }
					local a0 = garder(creer("Attachment", { Position = origine, Parent = part }))
					local a1 = garder(creer("Attachment", { Position = origine + direction * 0.5, Parent = part }))
					local faisceau = garder(creer("Beam", { Attachment0 = a0, Attachment1 = a1, Texture = FEU, TextureMode = Enum.TextureMode.Wrap,
						TextureLength = 2, TextureSpeed = 3, LightEmission = 1, LightInfluence = 0, Segments = 12, FaceCamera = true,
						CurveSize0 = 0, CurveSize1 = longueur * 0.35, Width0 = 0.1, Width1 = 0.05, Enabled = false,
						Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, couleurs[1]), ColorSequenceKeypoint.new(0.45, couleurs[2]), ColorSequenceKeypoint.new(1, couleurs[3]) }),
						Transparency = NumberSequence.new(1), Parent = part }))
					-- Un second faisceau, plus fin et presque blanc : le cœur du jet
					local coeur = garder(creer("Beam", { Attachment0 = a0, Attachment1 = a1, LightEmission = 1, LightInfluence = 0, Segments = 12, FaceCamera = true,
						CurveSize0 = 0, CurveSize1 = longueur * 0.35, Width0 = 0.05, Width1 = 0.02, Enabled = false,
						Color = ColorSequence.new(couleurs[1], couleurs[2]), Transparency = NumberSequence.new(1), Parent = part }))
					table.insert(jets, { faisceau = faisceau, coeur = coeur, a1 = a1, origine = origine, direction = direction, longueur = longueur, largeur = largeur, phase = math.random() * 10 })
				end
				-- Panache de flammes (la signature de la série) : cœur clair, bords orange, qui grossit en montant
				local function panache(parent, direction, puissance, couleurs)
					couleurs = couleurs or { BLANC_OR, OR, ORANGE }
					emetteur(parent, { Texture = FEU, LightEmission = 1, LightInfluence = 0, EmissionDirection = direction, ZOffset = 1,
						Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, couleurs[1]), ColorSequenceKeypoint.new(0.4, couleurs[2]), ColorSequenceKeypoint.new(1, couleurs[3]) }),
						Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6 * puissance), NumberSequenceKeypoint.new(0.5, 1.6 * puissance), NumberSequenceKeypoint.new(1, 0.4 * puissance) }),
						Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.7, 0.3), NumberSequenceKeypoint.new(1, 1) }),
						Speed = NumberRange.new(9 * puissance, 15 * puissance), Lifetime = NumberRange.new(0.35, 0.7), Drag = 2,
						SpreadAngle = Vector2.new(12, 12), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-120, 120) }, 110 * puissance, 0.12)
					emetteur(parent, { Texture = FEU, LightEmission = 1, LightInfluence = 0, EmissionDirection = direction, ZOffset = 2,
						Color = ColorSequence.new(couleurs[1], couleurs[2]), Size = NumberSequence.new(0.5 * puissance, 0.1),
						Transparency = NumberSequence.new(0, 1), Speed = NumberRange.new(12 * puissance, 18 * puissance), Lifetime = NumberRange.new(0.2, 0.4),
						SpreadAngle = Vector2.new(5, 5), Rotation = NumberRange.new(0, 360) }, 70 * puissance, 0.2)
				end
				-- Points d'émission : au-dessus de la tête (vers le haut), au bout des mains (le long des bras écartés)
				local pointTete = garder(creer("Attachment", { Position = Vector3.new(0, tete.Size.Y * 0.4, 0), Parent = tete }))
				local mains, bras = {}, {}
				for _, nom in { "Left Arm", "Right Arm", "LeftHand", "RightHand" } do
					local membre = personnage:FindFirstChild(nom)
					if membre then
						table.insert(bras, membre)
						table.insert(mains, garder(creer("Attachment", { Position = Vector3.new(0, -membre.Size.Y / 2, 0), Parent = membre })))
					end
				end
				-- (V7.5.2, G-206) Des fils d'or coulent de l'épaule à la main, avant que les mains ne s'embrasent
				local filsBras = {}
				if CORPS.FluxBras ~= false then
					for _, paire in { { "Left Arm", "Left Arm" }, { "Right Arm", "Right Arm" }, { "LeftUpperArm", "LeftHand" }, { "RightUpperArm", "RightHand" } } do
						local epaule, main = personnage:FindFirstChild(paire[1]), personnage:FindFirstChild(paire[2])
						if epaule and main then
							local a0 = garder(creer("Attachment", { Name = "TardisRegenEpaule", Position = Vector3.new(0, epaule.Size.Y / 2 - 0.1, 0), Parent = epaule }))
							local a1 = garder(creer("Attachment", { Name = "TardisRegenPoignet", Position = Vector3.new(0, -main.Size.Y / 2 + 0.1, 0), Parent = main }))
							table.insert(filsBras, garder(creer("Beam", { Name = "TardisRegenFilBras", Attachment0 = a0, Attachment1 = a1, Texture = FEU,
								TextureMode = Enum.TextureMode.Wrap, TextureLength = 1.5, TextureSpeed = 2.5, LightEmission = 1, LightInfluence = 0,
								Segments = 6, FaceCamera = true, Width0 = 0.22, Width1 = 0.12, Enabled = false,
								Color = ColorSequence.new(OR_CLAIR, OR), Transparency = NumberSequence.new(1), Parent = epaule })))
						end
					end
				end
				-- Jets de la tête et des mains : faisceaux + flammes
				local function jetsTeteEtMains(puissance, couleurs, longueurTete, longueurMains)
					jet(tete, Vector3.new(0, tete.Size.Y * 0.4, 0), Vector3.new(0, 1, 0), longueurTete or 7 * puissance, 1.1 * puissance, couleurs)
					for _, membre in bras do
						jet(membre, Vector3.new(0, -membre.Size.Y / 2, 0), Vector3.new(0, -1, 0), longueurMains or 6 * puissance, 0.9 * puissance, couleurs)
					end
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
					emetteur(point, { Texture = FUMEE, LightEmission = 1, Color = ColorSequence.new(OR_CLAIR, OR), Size = NumberSequence.new(0.2, 0.7),
						Transparency = NumberSequence.new(0.4, 1), Speed = NumberRange.new(0.5, 1.5), Lifetime = NumberRange.new(0.6, 1.3),
						SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, 2, 0) }, 25, 0)
				end
				-- Étincelles dorées tout autour, qui retombent
				local etincelles = emetteur(racine, { Texture = ETINCELLE, LightEmission = 1, Color = ColorSequence.new(BLANC_OR, OR),
					Size = NumberSequence.new(0.35, 0), Speed = NumberRange.new(6, 16), Lifetime = NumberRange.new(0.5, 1.1), SpreadAngle = Vector2.new(180, 180),
					Acceleration = Vector3.new(0, -12, 0), Drag = 1 }, 40, 0.3)
				-- Braises : des points qui montent lentement autour du corps (l'air chauffe)
				emetteur(racine, { Texture = ETINCELLE, LightEmission = 1, Color = ColorSequence.new(OR, ORANGE), Size = NumberSequence.new(0.12, 0),
					Speed = NumberRange.new(1, 3), Lifetime = NumberRange.new(1.2, 2.2), SpreadAngle = Vector2.new(180, 180),
					Acceleration = Vector3.new(0, 3, 0), Drag = 0.5 }, 30, 0.05)
				-- (V7.5.4, G-217) Sous l'eau : de la vapeur monte du corps
				if sousEau then
					emetteur(racine, { Texture = FUMEE, LightEmission = 0.2, Color = ColorSequence.new(Color3.fromRGB(240, 245, 250)), Size = NumberSequence.new(0.8, 3),
						Transparency = NumberSequence.new(0.5, 1), Speed = NumberRange.new(2, 4), Lifetime = NumberRange.new(1.2, 2.2), SpreadAngle = Vector2.new(40, 40),
						EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(0, 4, 0) }, 35, 0.1)
				end

				local secousseMax, couleurFlash, couleurAmbiance = 0.5, BLANC_OR, OR
				local parImage = nil -- animation propre au style, appelée à chaque image : parImage(p, i, t)
				local sol = racine.Position - Vector3.new(0, (humanoid and humanoid.HipHeight or 0) + racine.Size.Y / 2 + 2, 0)
				local solTrouve, materiauSol = false, nil
				do
					-- Le vrai sol sous les pieds, s'il est à portée
					local params = RaycastParams.new()
					params.FilterType = Enum.RaycastFilterType.Exclude
					params.FilterDescendantsInstances = { personnage }
					local r = workspace:Raycast(racine.Position, Vector3.new(0, -12, 0), params)
					if r then sol, solTrouve, materiauSol = r.Position, true, r.Material end
				end
				local flashPour = nil -- couleur de l'éclat du changement (nil = celle du style) ; `false` = aucun éclat
				local avecSolBrulant = not sousEau -- (V7.5.4, G-217) pas de sol brûlant sous l'eau

				-- Sol brûlant : un disque qui rougeoie sous les pieds, s'élargit avec l'intensité, et met longtemps à refroidir
				local brulure, genreSol = nil, nil
				local function solBrulant(couleur)
					if not solTrouve or not avecSolBrulant then return end
					-- (V7.5.4, G-223) selon le matériau : herbe noircie, neige en flaque, métal qui rougeoie
					genreSol = LIEU.SolSelonMateriau ~= false and materiauSol and Config.solBrulantSelon(materiauSol.Name) or nil
					couleur = genreSol and genreSol.couleur or couleur
					brulure = partTemporaire({ Name = "TardisRegenBrulure", Shape = Enum.PartType.Cylinder, Material = Enum.Material[genreSol and genreSol.materiau or "Neon"], Color = couleur,
						Transparency = 1, Size = Vector3.new(0.08, 1, 1), CFrame = CFrame.new(sol + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.pi / 2) })
					creer("PointLight", { Color = couleur, Brightness = 0, Range = 12, Parent = brulure })
				end

				-- Onde de choc des styles violents : un dôme d'énergie jusqu'au rayon, un anneau qui court loin au sol,
				-- et tout joueur à moins de Rayon studs est projeté. Chaque joueur s'occupe de son propre personnage.
				local ONDE = REG.OndeChoc or {}
				local RAYON_ONDE, FORCE_ONDE = ONDE.Rayon or 5, ONDE.Force or 70
				local function ondeDeChoc(couleur, puissance)
					if not racine.Parent then return end
					local centre = racine.Position
					local dome = partTemporaire({ Name = "TardisRegenDome", Shape = Enum.PartType.Ball, Material = Enum.Material.ForceField, Color = couleur,
						Transparency = 0.05, Size = Vector3.one, CFrame = CFrame.new(centre) })
					animer(dome, 0.3, { Size = Vector3.one * RAYON_ONDE * 2 }, Enum.EasingStyle.Quad)
					task.delay(0.3, function() animer(dome, 0.5, { Transparency = 1 }) end)
					Debris:AddItem(dome, 0.9)
					local anneau = partTemporaire({ Name = "TardisRegenAnneau", Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = couleur,
						Transparency = 0.1, Size = Vector3.new(0.3, 2, 2), CFrame = CFrame.new(sol + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.pi / 2) })
					animer(anneau, 1.1, { Size = Vector3.new(0.15, 60 * puissance, 60 * puissance), Transparency = 1 }, Enum.EasingStyle.Quad)
					Debris:AddItem(anneau, 1.2)
					etincelles:Emit(math.floor(90 * puissance))
					secouer(1.6 * puissance)
					if moi then return end
					local mienne = maRacine()
					local monHumanoid = joueur.Character and joueur.Character:FindFirstChildOfClass("Humanoid")
					if not mienne or not monHumanoid or monHumanoid.Sit then return end
					local ecart = mienne.Position - centre
					if ecart.Magnitude > RAYON_ONDE then return end
					local plat = Vector3.new(ecart.X, 0, ecart.Z)
					local direction = plat.Magnitude > 0.1 and plat.Unit or -racine.CFrame.LookVector
					monHumanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
					mienne.AssemblyLinearVelocity = direction * FORCE_ONDE * puissance + Vector3.new(0, FORCE_ONDE * 0.45 * puissance, 0)
				end

				-- Anneau de lumière qui s'élargit au sol (sans projeter personne)
				local function anneauSol(couleur, rayonFinal, dureeAnneau, transparence)
					local anneau = partTemporaire({ Name = "TardisRegenAnneau", Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = couleur,
						Transparency = transparence or 0.2, Size = Vector3.new(0.15, 1.5, 1.5), CFrame = CFrame.new(sol + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2) })
					animer(anneau, dureeAnneau or 0.9, { Size = Vector3.new(0.12, rayonFinal * 2, rayonFinal * 2), Transparency = 1 }, Enum.EasingStyle.Quad)
					Debris:AddItem(anneau, (dureeAnneau or 0.9) + 0.1)
				end

				-- Courbe d'intensité : montée (0-15 %), éruption (15-55 %), changement et pleine puissance (55-80 %), dissipation
				local function intensiteBase(p)
					if p < 0.15 then return 0.18 * (p / 0.15) end
					if p < 0.55 then local q = (p - 0.15) / 0.4 return 0.18 + 0.82 * q * q end
					if p < 0.8 then return 1 end
					if p < 1 then return 1 - (p - 0.8) / 0.2 end
					return 0
				end
				local intensite = intensiteBase

				if style == 2 then
					-- VOLCAN (10e → 11e Docteur) : une éruption si violente qu'elle ravage tout autour
					local ROUGE_FEU = Color3.fromRGB(255, 70, 10)
					jetsTeteEtMains(1.8, { BLANC_OR, OR, ROUGE_FEU }, 14, 11)
					for _, f in flux do if f.e == etincelles then f.debit = 160 end end
					-- Colonne de fumée sombre qui monte au-dessus de la tête
					emetteur(pointTete, { Texture = FUMEE, LightEmission = 0.2, Color = ColorSequence.new(Color3.fromRGB(90, 60, 50), Color3.fromRGB(30, 25, 25)),
						Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 6) }),
						Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) }),
						Speed = NumberRange.new(6, 10), Lifetime = NumberRange.new(2, 3.5), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(20, 20),
						Acceleration = Vector3.new(0, 4, 0), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-20, 20) }, 18, 0.3)
					-- Débris incandescents projetés au loin
					emetteur(racine, { Texture = ETINCELLE, LightEmission = 1, Color = ColorSequence.new(OR_CLAIR, ROUGE_FEU), Size = NumberSequence.new(0.5, 0.1),
						Speed = NumberRange.new(20, 40), Lifetime = NumberRange.new(0.8, 1.6), SpreadAngle = Vector2.new(180, 180),
						Acceleration = Vector3.new(0, -40, 0), Drag = 0.5 }, 60, 0.45)
					-- Flammes au sol, autour du Voyageur
					for k = 1, 6 do
						local angle = k / 6 * math.pi * 2
						local foyer = garder(partTemporaire({ Name = "TardisRegenFoyer", Transparency = 1, Size = Vector3.new(1, 1, 1),
							CFrame = CFrame.new(sol + Vector3.new(math.cos(angle) * 5, 0.5, math.sin(angle) * 5)) }))
						local feu = garder(creer("Fire", { Size = 0.1, Heat = 12, Color = OR, SecondaryColor = ORANGE, Enabled = false, Parent = foyer }))
						task.delay(duree * (0.3 + k * 0.03), function() if feu.Parent then feu.Enabled = true animer(feu, 1, { Size = 6 }) end end)
					end
					solBrulant(ORANGE)
					-- Ondes qui balaient le sol pendant l'éruption
					local prochaineOnde = 0.35
					parImage = function(p)
						if p >= prochaineOnde and p < 0.8 then
							prochaineOnde += 0.12
							anneauSol(OR_CLAIR, 23, 0.9, 0.25)
						end
					end
					-- Au moment du changement : une explosion de lumière et une vraie onde de choc
					task.delay(duree * 0.55, function()
						if not racine.Parent then return end
						if sansFlash then ondeDeChoc(OR_CLAIR, 0.8) return end -- l'onde de choc seule, sans la boule de lumière
						local boule = partTemporaire({ Name = "TardisRegenExplosion", Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = BLANC_OR,
							Transparency = reduit and 0.6 or 0.1, Size = Vector3.new(3, 3, 3), CFrame = racine.CFrame })
						animer(boule, 0.7, { Size = Vector3.new(34, 34, 34), Transparency = 1, Color = ORANGE }, Enum.EasingStyle.Quad)
						Debris:AddItem(boule, 0.8)
						etincelles:Emit(120)
						ondeDeChoc(OR_CLAIR, 0.8)
					end)
					flashPour = false -- l'explosion fait office d'éclat
					secousseMax, couleurAmbiance = 1.3, ORANGE
				elseif style == 3 then
					-- DOUCE (Docteur de la Guerre → 9e, 8e Docteur) : un voile de lumière tiède, sans violence, un halo derrière la tête
					for _, f in flux do f.debit *= 0.3 end
					avecSolBrulant = false
					intensite = function(p) return 0.9 * math.sin(math.pi * math.clamp(p, 0, 1)) ^ 1.3 end
					emetteur(racine, { Texture = FUMEE, LightEmission = 1, LightInfluence = 0, Color = ColorSequence.new(BLANC_OR, OR_CLAIR),
						Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(0.5, 3.5), NumberSequenceKeypoint.new(1, 4.5) }),
						Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.55), NumberSequenceKeypoint.new(1, 1) }),
						Speed = NumberRange.new(0.3, 1), Lifetime = NumberRange.new(1.5, 2.5), SpreadAngle = Vector2.new(180, 180),
						Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-20, 20) }, 30, 0.1)
					-- Poussières de lumière qui montent lentement
					emetteur(racine, { Texture = ETINCELLE, LightEmission = 1, Color = ColorSequence.new(BLANC_OR), Size = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.3), NumberSequenceKeypoint.new(1, 0) }),
						Speed = NumberRange.new(0.5, 2), Lifetime = NumberRange.new(1.5, 2.5), SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, 1.5, 0) }, 50, 0.15)
					-- Halo : un anneau de lumière derrière la tête, toujours tourné vers la caméra
					local haloDoux = garder(partTemporaire({ Name = "TardisRegenHalo", Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = BLANC_OR,
						Transparency = 1, Size = Vector3.new(0.05, 4, 4), CFrame = tete.CFrame }))
					local haloInterieur = garder(partTemporaire({ Name = "TardisRegenHaloCoeur", Shape = Enum.PartType.Cylinder, Material = Enum.Material.ForceField, Color = OR_CLAIR,
						Transparency = 1, Size = Vector3.new(0.05, 3, 3), CFrame = tete.CFrame }))
					lueur.FillColor, lueur.OutlineColor = BLANC_OR, BLANC
					lumiere.Color = Color3.fromRGB(255, 220, 170)
					parImage = function(p, i, t)
						if not tete.Parent then return end
						local versCamera = (camera.CFrame.Position - tete.Position)
						if versCamera.Magnitude < 0.1 then return end
						local cf = CFrame.lookAt(tete.Position - versCamera.Unit * 0.8 + Vector3.new(0, 0.6, 0), tete.Position - versCamera.Unit * 2) * CFrame.Angles(0, math.pi / 2, 0)
						local taille = 3.5 + 2 * i + 0.3 * math.sin(t * 2)
						haloDoux.CFrame, haloDoux.Size, haloDoux.Transparency = cf, Vector3.new(0.05, taille, taille), 1 - 0.55 * i
						haloInterieur.CFrame, haloInterieur.Size, haloInterieur.Transparency = cf * CFrame.new(0.02, 0, 0), Vector3.new(0.05, taille * 0.8, taille * 0.8), 1 - 0.5 * i
					end
					secousseMax, couleurFlash, couleurAmbiance = 0.1, Color3.fromRGB(255, 252, 240), Color3.fromRGB(255, 225, 180)
				elseif style == 4 then
					-- TOURBILLON (5e, 6e, 7e Docteurs) : des sphères qui tournoient en spirale, des couleurs qui défilent (inchangé)
					panache(pointTete, Enum.NormalId.Top, 0.8)
					for _, main in mains do panache(main, Enum.NormalId.Bottom, 0.8 * 0.8) end
					avecSolBrulant = false
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
							-- (V7.1.1, G-232) « effets réduits » : plus transparent et trois fois plus lent
							local vitesse = reduit and 0.35 or 1
							degrade.Rotation = (t * 140 * vitesse) % 360
							cadre.Rotation = -(t * 40 * vitesse) % 360
							cadre.BackgroundTransparency = 1 - (reduit and 0.15 or 0.45) * i
						end
					end
					secousseMax, couleurAmbiance = 0.6, Color3.fromRGB(255, 200, 255)
				elseif style == 5 then
					-- COLONNE (bigénération) : une colonne de lumière descend du ciel, des anneaux de runes tournent autour,
					-- des rayons tombent en cercle, et un sceau gallifreyen s'allume au sol
					jet(tete, Vector3.new(0, tete.Size.Y * 0.4, 0), Vector3.new(0, 1, 0), 22, 1.4)
					panache(pointTete, Enum.NormalId.Top, 1.1)
					for _, main in mains do panache(main, Enum.NormalId.Bottom, 0.7) end
					local colonne = garder(partTemporaire({ Name = "TardisRegenColonne", Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon,
						Color = OR_CLAIR, Transparency = 1, Size = Vector3.new(240, 0.4, 0.4), CFrame = CFrame.new(sol + Vector3.new(0, 120, 0)) * CFrame.Angles(0, 0, math.pi / 2) }))
					local haloColonne = garder(partTemporaire({ Name = "TardisRegenColonneHalo", Shape = Enum.PartType.Cylinder, Material = Enum.Material.ForceField,
						Color = OR, Transparency = 1, Size = Vector3.new(240, 1, 1), CFrame = colonne.CFrame }))
					-- Anneaux de runes : trois cercles fins à des hauteurs différentes, qui tournent en sens contraires
					local anneauxRunes = {}
					for k = 1, 3 do
						local anneau = garder(partTemporaire({ Name = "TardisRegenRune", Transparency = 1, Size = Vector3.one, CFrame = CFrame.new(sol) }))
						local traits = {}
						local rayon, segments = 2.6 + k * 0.9, 10 + k * 4
						local points = {}
						for s = 0, segments - 1 do
							local a = s / segments * math.pi * 2
							points[s + 1] = creer("Attachment", { Position = Vector3.new(math.cos(a) * rayon, 0, math.sin(a) * rayon), Parent = anneau })
						end
						for s = 1, segments do
							-- Un trait sur deux : des runes espacées, pas un cercle plein
							if s % 2 == 1 then
								table.insert(traits, creer("Beam", { Attachment0 = points[s], Attachment1 = points[s % segments + 1], Width0 = 0.25, Width1 = 0.25,
									LightEmission = 1, LightInfluence = 0, Segments = 1, Color = ColorSequence.new(OR_CLAIR, BLANC_OR), Transparency = NumberSequence.new(1),
									FaceCamera = false, Parent = anneau }))
							end
						end
						anneauxRunes[k] = { part = anneau, traits = traits, hauteur = 1.5 + k * 1.6, vitesse = (k % 2 == 0 and -1 or 1) * (0.9 + k * 0.3) }
					end
					-- Rayons qui tombent du ciel en cercle autour du Voyageur
					local sommet = garder(partTemporaire({ Name = "TardisRegenSommet", Transparency = 1, Size = Vector3.one, CFrame = CFrame.new(sol + Vector3.new(0, 28, 0)) }))
					local baseRayons = garder(partTemporaire({ Name = "TardisRegenBaseRayons", Transparency = 1, Size = Vector3.one, CFrame = CFrame.new(sol) }))
					local rayons = {}
					local haut = creer("Attachment", { Parent = sommet })
					for k = 1, 8 do
						local a = k / 8 * math.pi * 2
						local bas = creer("Attachment", { Position = Vector3.new(math.cos(a) * 6, 0, math.sin(a) * 6), Parent = baseRayons })
						table.insert(rayons, creer("Beam", { Attachment0 = haut, Attachment1 = bas, Width0 = 0.3, Width1 = 1.6, LightEmission = 1, LightInfluence = 0,
							Segments = 1, Color = ColorSequence.new(BLANC_OR, OR_CLAIR), Transparency = NumberSequence.new(1), FaceCamera = true, Parent = baseRayons }))
					end
					-- Le sceau : des cercles concentriques et de petits cercles, tracés en lumière (écriture gallifreyenne)
					local sceau = garder(partTemporaire({ Name = "TardisRegenSceau", Transparency = 1, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(sol + Vector3.new(0, 0.15, 0)) }))
					local traitsSceau = {}
					local function cercle(centre, rayon, segments, largeur)
						local points = {}
						for k = 0, segments - 1 do
							local a = k / segments * math.pi * 2
							points[k + 1] = creer("Attachment", { Position = centre + Vector3.new(math.cos(a) * rayon, 0, math.sin(a) * rayon), Parent = sceau })
						end
						for k = 1, segments do
							table.insert(traitsSceau, creer("Beam", { Attachment0 = points[k], Attachment1 = points[k % segments + 1], Width0 = largeur, Width1 = largeur,
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
					local eclatFait = false
					parImage = function(p, i, t)
						local ouverture = math.clamp(i * 1.2, 0, 1)
						colonne.Size = Vector3.new(240, 0.4 + 6.5 * ouverture, 0.4 + 6.5 * ouverture)
						colonne.Transparency = 1 - 0.6 * ouverture
						haloColonne.Size = Vector3.new(240, 1 + 12 * ouverture, 1 + 12 * ouverture)
						haloColonne.Transparency = 1 - 0.5 * ouverture
						sceau.CFrame = CFrame.new(sol + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, t * 0.6, 0)
						local transparence = NumberSequence.new(1 - 0.9 * math.clamp(p / 0.3, 0, 1) * (p > 0.85 and (1 - p) / 0.15 or 1))
						for _, trait in traitsSceau do trait.Transparency = transparence end
						for _, r in anneauxRunes do
							r.part.CFrame = CFrame.new(sol + Vector3.new(0, r.hauteur + 0.4 * math.sin(t * 1.5 + r.hauteur), 0)) * CFrame.Angles(0, t * r.vitesse, 0)
							local tr = NumberSequence.new(1 - 0.8 * ouverture)
							for _, trait in r.traits do trait.Transparency = tr end
						end
						sommet.CFrame = CFrame.new(sol + Vector3.new(0, 28, 0))
						baseRayons.CFrame = CFrame.new(sol) * CFrame.Angles(0, -t * 0.4, 0)
						local trRayons = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1 - 0.5 * ouverture), NumberSequenceKeypoint.new(1, 1 - 0.15 * ouverture) })
						for _, r in rayons do r.Transparency = trRayons end
						-- Au changement : la colonne devient blanche un instant et les anneaux s'écartent
						if p >= 0.55 and not eclatFait then
							eclatFait = true
							if not sansFlash then -- « aucun flash » (V6.9.9) : la colonne ne passe pas au blanc
								colonne.Color = BLANC
								animer(colonne, 1.2, { Color = OR_CLAIR })
							end
							anneauSol(BLANC_OR, 14, 1.2, 0.1)
						end
					end
					secousseMax = 0.7
				elseif style == 6 then
					-- SUPERNOVA : l'énergie est aspirée vers le Voyageur, se comprime en un cœur aveuglant, puis tout explose d'un coup
					jetsTeteEtMains(1.5, { BLANC_OR, OR_CLAIR, ORANGE }, 9, 7)
					intensite = function(p)
						if p < 0.55 then local q = p / 0.55 return 0.1 + 0.5 * q * q end
						if p < 0.8 then return 1 end
						if p < 1 then return 1 - (p - 0.8) / 0.2 end
						return 0
					end
					local coque = garder(partTemporaire({ Name = "TardisRegenCoque", Transparency = 1, Size = Vector3.one * 10, CFrame = racine.CFrame }))
					local aspiration = emetteur(coque, { Texture = ETINCELLE, LightEmission = 1, LightInfluence = 0, Color = ColorSequence.new(OR, BLANC_OR),
						Size = NumberSequence.new(0.15, 0.45), Speed = NumberRange.new(9, 12), Lifetime = NumberRange.new(0.45, 0.55),
						Shape = Enum.ParticleEmitterShape.Sphere, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
						ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface }, 220, 0)
					-- Débris lancés dans tous les sens après l'explosion
					local debris = emetteur(racine, { Texture = ETINCELLE, LightEmission = 1, Color = ColorSequence.new(BLANC, ORANGE), Size = NumberSequence.new(0.6, 0),
						Speed = NumberRange.new(30, 60), Lifetime = NumberRange.new(0.8, 1.5), SpreadAngle = Vector2.new(180, 180), Drag = 1 }, 0, 0.56)
					local coeur = garder(partTemporaire({ Name = "TardisRegenCoeur", Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = BLANC_OR,
						Transparency = 1, Size = Vector3.one * 0.5, CFrame = racine.CFrame }))
					creer("PointLight", { Color = BLANC_OR, Brightness = 6, Range = 14, Parent = coeur })
					-- Voile sombre qui se resserre : l'espace se plie autour du Voyageur
					local voileSombre = garder(partTemporaire({ Name = "TardisRegenVoile", Shape = Enum.PartType.Ball, Material = Enum.Material.ForceField, Color = Color3.fromRGB(20, 10, 40),
						Transparency = 1, Size = Vector3.one * 14, CFrame = racine.CFrame }))
					solBrulant(OR)
					local explose = false
					parImage = function(p, i, t)
						if not explose then
							local charge = math.clamp(p / 0.55, 0, 1)
							coeur.Size = Vector3.one * (0.5 + 3 * charge * charge) * (sansFlash and 1 or (1 + 0.12 * math.sin(t * 30 * charge)))
							coeur.Transparency = 1 - 0.85 * charge
							coeur.CFrame = racine.CFrame
							voileSombre.CFrame = racine.CFrame
							voileSombre.Size = Vector3.one * (14 - 9 * charge)
							voileSombre.Transparency = 1 - 0.55 * charge
							lueur.FillColor = OR:Lerp(BLANC, charge)
						end
						if p >= 0.55 and not explose then
							explose = true
							for _, f in flux do if f.e == aspiration then f.debit = 0 end end
							coeur.Transparency = 1
							voileSombre.Transparency = 1
							if not sansFlash then -- « aucun flash » (V6.9.9) : ni boule de lumière ni anneaux ; l'onde de choc et les débris restent
							local boule = partTemporaire({ Name = "TardisRegenSupernova", Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = BLANC,
								Transparency = reduit and 0.7 or 0, Size = Vector3.one * 4, CFrame = racine.CFrame })
							animer(boule, 0.55, { Size = Vector3.one * 48, Transparency = 1, Color = ORANGE }, Enum.EasingStyle.Quad)
							Debris:AddItem(boule, 0.6)
							-- Trois anneaux dans trois plans : le disque d'une supernova
							for _, rotation in { CFrame.Angles(0, 0, math.pi / 2), CFrame.Angles(0, 0, 0), CFrame.Angles(0, math.pi / 2, 0) } do
								local anneau = partTemporaire({ Name = "TardisRegenAnneau", Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = BLANC_OR,
									Transparency = 0.1, Size = Vector3.new(0.2, 2, 2), CFrame = CFrame.new(racine.Position) * rotation })
								animer(anneau, 0.9, { Size = Vector3.new(0.1, 40, 40), Transparency = 1, Color = ORANGE }, Enum.EasingStyle.Quad)
								Debris:AddItem(anneau, 1)
							end
							end
							debris:Emit(160)
							ondeDeChoc(BLANC_OR, 1.2)
						end
					end
					flashPour = false
					secousseMax, couleurFlash, couleurAmbiance = 1.4, BLANC, OR_CLAIR
				elseif style == 7 then
					-- FRACTURE : une régénération instable, rouge et blanche ; des éclairs jaillissent du corps et courent sur la peau,
					-- l'image tressaute, le sol se fend, et trois ondes de choc successives repoussent tout le monde
					local ROUGE, ROUGE_CLAIR = Color3.fromRGB(255, 55, 30), Color3.fromRGB(255, 140, 110)
					jetsTeteEtMains(1.6, { BLANC_OR, ROUGE_CLAIR, ROUGE }, 8, 6)
					intensite = function(p) return intensiteBase(p) * (0.7 + 0.3 * Config.Bruit(p * 100, 1)) end
					lueur.FillColor, lueur.OutlineColor = ROUGE, ROUGE_CLAIR
					lumiere.Color = ROUGE
					solBrulant(ROUGE)
					-- Fissures : 8 traits de lumière qui partent des pieds et s'allongent
					local fissures = {}
					for k = 1, 8 do
						local angle = k / 8 * math.pi * 2 + math.random() * 0.4
						fissures[k] = { angle = angle, part = garder(partTemporaire({ Name = "TardisRegenFissure", Material = Enum.Material.Neon, Color = ROUGE,
							Transparency = 1, Size = Vector3.new(0.25, 0.1, 1), CFrame = CFrame.new(sol) })) }
					end
					-- Un éclair en zigzag entre deux points (quelques segments qui ne vivent qu'un instant)
					local function eclair(depart, arrivee)
						local precedent = depart
						for k = 1, 6 do
							local suivant = k == 6 and arrivee or depart:Lerp(arrivee, k / 6) + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 2.4
							local segment = partTemporaire({ Name = "TardisRegenEclair", Material = Enum.Material.Neon, Color = k % 2 == 0 and BLANC_OR or ROUGE_CLAIR,
								Size = Vector3.new(0.16, 0.16, (suivant - precedent).Magnitude), CFrame = CFrame.lookAt((precedent + suivant) / 2, suivant) })
							Debris:AddItem(segment, 0.12)
							precedent = suivant
						end
					end
					-- Arcs sur la peau : des éclairs courts entre deux membres, qui changent sans cesse
					local membres = {}
					for _, nom in { "Head", "Torso", "UpperTorso", "Left Arm", "Right Arm", "Left Leg", "Right Leg", "LeftHand", "RightHand", "LeftFoot", "RightFoot" } do
						local m = personnage:FindFirstChild(nom)
						if m then table.insert(membres, m) end
					end
					local function arcPeau()
						if #membres < 2 then return end
						local a, b = membres[math.random(#membres)], membres[math.random(#membres)]
						if a == b then return end
						local pa, pb = a.Position + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 0.8, b.Position + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 0.8
						local precedent = pa
						for k = 1, 4 do
							local suivant = k == 4 and pb or pa:Lerp(pb, k / 4) + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 0.7
							local segment = partTemporaire({ Name = "TardisRegenArc", Material = Enum.Material.Neon, Color = k % 2 == 0 and BLANC or ROUGE_CLAIR,
								Size = Vector3.new(0.08, 0.08, (suivant - precedent).Magnitude), CFrame = CFrame.lookAt((precedent + suivant) / 2, suivant) })
							Debris:AddItem(segment, 0.07)
							precedent = suivant
						end
					end
					local ondes = { { p = 0.35, puissance = 0.6 }, { p = 0.55, puissance = 1.1 }, { p = 0.75, puissance = 0.8 } }
					parImage = function(p, i, t)
						for k, f in fissures do
							local longueur = 0.5 + 9 * math.clamp((p - 0.25) / 0.4, 0, 1)
							local direction = Vector3.new(math.cos(f.angle), 0, math.sin(f.angle))
							f.part.Size = Vector3.new(0.25 + 0.15 * i, 0.1, longueur)
							f.part.CFrame = CFrame.lookAt(sol + Vector3.new(0, 0.12, 0) + direction * (longueur / 2), sol + Vector3.new(0, 0.12, 0) + direction * longueur)
							f.part.Transparency = p > 0.25 and (1 - 0.9 * i * (0.7 + 0.3 * Config.Bruit(t + k, 12))) or 1
						end
						if i > 0.3 and p < 0.85 and math.random() < 0.4 * i and not sansFlash then
							local a = math.random() * math.pi * 2
							local loin = 2 + math.random() * 5
							eclair(racine.Position + Vector3.new(0, math.random() * 2, 0), sol + Vector3.new(math.cos(a) * loin, 0.2, math.sin(a) * loin))
						end
						if i > 0.2 and math.random() < 0.6 * i and not sansFlash then arcPeau() end
						-- L'image tressaute : la lueur et la lumière saccadent (couleur fixe avec « aucun flash », V6.9.9)
						local saccade = sansFlash and 0 or Config.Bruit(t, 18)
						lueur.OutlineColor = saccade < 0.5 and ROUGE_CLAIR or BLANC
						lumiere.Color = saccade < 0.7 and ROUGE or BLANC
						while ondes[1] and p >= ondes[1].p do
							ondeDeChoc(ondes[1].puissance > 1 and BLANC_OR or ROUGE_CLAIR, table.remove(ondes, 1).puissance)
						end
					end
					flashPour = false -- la seconde onde fait office d'éclat
					secousseMax, couleurFlash, couleurAmbiance = 1.6, ROUGE_CLAIR, ROUGE
				else
					-- CLASSIQUE (9e → 10e Docteur) : la tête renversée, les bras écartés, les jets dorés jaillissent, l'air se remplit de braises
					jetsTeteEtMains(1.2, nil, 8, 6.5)
					solBrulant(OR)
					-- Rubans d'énergie : trois traînées qui tournent autour du corps
					local rubans = {}
					for k = 1, 3 do
						local porteur = garder(partTemporaire({ Name = "TardisRegenRuban", Transparency = 1, Size = Vector3.one * 0.2, CFrame = racine.CFrame }))
						local a0 = creer("Attachment", { Position = Vector3.new(0, 0.35, 0), Parent = porteur })
						local a1 = creer("Attachment", { Position = Vector3.new(0, -0.35, 0), Parent = porteur })
						local trainee = creer("Trail", { Attachment0 = a0, Attachment1 = a1, Lifetime = 0.5, LightEmission = 1, FaceCamera = true,
							Color = ColorSequence.new(BLANC_OR, OR), Transparency = NumberSequence.new(1), WidthScale = NumberSequence.new(1, 0), Parent = porteur })
						rubans[k] = { part = porteur, trainee = trainee, phase = k / 3 * math.pi * 2 }
					end
					parImage = function(p, i, t)
						for _, r in rubans do
							local angle = t * 3.2 + r.phase
							local rayon = 1.6 + 0.8 * i
							r.part.CFrame = racine.CFrame * CFrame.new(math.cos(angle) * rayon, math.sin(t * 1.7 + r.phase) * 1.6, math.sin(angle) * rayon)
							r.trainee.Transparency = NumberSequence.new(1 - 0.8 * i, 1)
						end
					end
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

				-- Caméra : celui qui se régénère voit la scène de l'extérieur ; la caméra tourne lentement autour de lui,
				-- respire comme à l'épaule, et se rapproche au moment du changement (V7.5.1 : cameraCinema, plus haut)
				local scene = (moi and REG.CameraCinematique ~= false)
					and cameraCinema({ personnage = personnage, tete = tete, racine = racine, style = style, reduit = reduit }) or nil
				-- Fin de la régénération : plan final sur le nouveau visage, puis la caméra est rendue
				local function rendreCamera()
					if scene then scene.fin() end
				end
				-- (V7.5.1, G-240) bord doré pour les témoins (créé quand la régénération est assez proche)
				local temoin = not moi and CINEMA.VignetteTemoins ~= false
				local vignette = nil

				-- Éclat du changement : pour tout le monde, la lumière avale le Voyageur un instant (la nouvelle apparence
				-- apparaît dessous) ; pour celui qui se régénère, l'écran entier devient blanc
				local function eclatChangement()
					if flashPour == false then return end
					if not racine.Parent then return end
					local couleur = flashPour or couleurFlash
					if sansFlash then
						-- Sans flash (V6.9.9) : l'anneau au sol et les étincelles seulement, sans boule de lumière ni lueur blanche
						anneauSol(couleur, 9, 0.8, 0.3)
						etincelles:Emit(60)
						secouer(0.5)
						return
					end
					local boule = partTemporaire({ Name = "TardisRegenEclatChangement", Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = BLANC,
						Transparency = reduit and 0.6 or 0.05, Size = Vector3.one * 2.5, CFrame = racine.CFrame })
					creer("PointLight", { Color = couleur, Brightness = 10, Range = 40, Shadows = true, Parent = boule })
					animer(boule, 0.5, { Size = Vector3.one * 9, Transparency = 1, Color = couleur }, Enum.EasingStyle.Quad)
					Debris:AddItem(boule, 0.6)
					lueur.FillColor = BLANC
					lueur.FillTransparency = 0
					animer(lueur, 0.6, { FillColor = couleurAmbiance, FillTransparency = 0.3 })
					anneauSol(couleur, 9, 0.8, 0.3)
					etincelles:Emit(60)
					secouer(0.5)
				end

				-- (V7.5.2, G-209, G-210) Les accessoires : les anciens brûlent quand le serveur les retire, les nouveaux apparaissent
				-- un par un. Les copies des anciens sont préparées un peu avant le changement (40 %).
				local depart = os.clock()
				local anciens, brules = {}, 0
				local apparitions = CORPS.Apparition ~= false and apparitionsAccessoires(reduit) or nil
				local copiesPretes = false
				local function preparerCopies()
					copiesPretes = true
					if CORPS.Cendres == false then return end
					for _, objet in personnage:GetChildren() do
						if objet:IsA("Accessory") and not anciens[objet] then
							local c = copieAccessoire(objet)
							if c then anciens[objet] = c end
						end
					end
				end
				table.insert(connexions, personnage.ChildRemoved:Connect(function(objet)
					local c = anciens[objet]
					if not c then return end
					anciens[objet] = nil
					if brules < (CORPS.CendresMax or 8) then
						brules += 1
						brulerAccessoire(c, solTrouve and sol.Y or nil, reduit)
					else
						c.copie:Destroy()
					end
				end))
				table.insert(connexions, personnage.ChildAdded:Connect(function(objet)
					if apparitions and copiesPretes and objet:IsA("Accessory") then apparitions.ajouter(objet, os.clock() - depart) end
				end))

				depart = os.clock()
				local flashFait, eclatFait = false, false
				table.insert(connexions, RunService.RenderStepped:Connect(function()
					local t = os.clock() - depart
					local p = math.clamp(t / duree, 0, 1)
					local i = intensite(p)
					-- (V7.5.2) fils d'or dans les bras, copies des anciens accessoires (suivies jusqu'au changement), nouveaux accessoires
					local fb = Config.fluxBras(p)
					for _, fil in filsBras do
						fil.Enabled = fb > 0.01
						fil.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1 - 0.85 * fb), NumberSequenceKeypoint.new(0.5, 1 - 0.6 * fb), NumberSequenceKeypoint.new(1, 1 - 0.85 * fb) })
					end
					if not copiesPretes and p >= 0.4 then preparerCopies() end
					for objet, c in anciens do if objet.Parent and c.poignee.Parent then c.cf = c.poignee.CFrame end end
					if apparitions then apparitions.maj(t) end
					local vacillement = (p > 0.2 and p < 0.85) and (0.9 + 0.1 * math.noise(t * 7, 0.5, 0.5) * 2) or 1
					-- Débit des flammes et des étincelles
					for _, f in flux do f.e.Rate = (p >= f.seuil and p < 0.9) and f.debit * i * vacillement or 0 end
					-- Jets : ils s'allongent avec l'intensité et ondulent
					for _, j in jets do
						local actif = i > 0.03 and p < 0.92
						j.faisceau.Enabled, j.coeur.Enabled = actif, actif
						if actif then
							local longueur = j.longueur * (0.2 + 0.8 * i) * (0.88 + 0.12 * math.noise(t * 6 + j.phase, 0.3, 0.3) * 2) * vacillement
							j.a1.Position = j.origine + j.direction * longueur
							j.faisceau.Width0 = j.largeur * (0.35 + 0.65 * i)
							j.faisceau.Width1 = j.largeur * 0.12
							j.coeur.Width0 = j.largeur * 0.45 * (0.35 + 0.65 * i)
							j.coeur.Width1 = j.largeur * 0.05
							j.faisceau.CurveSize1 = longueur * 0.3 * math.sin(t * 1.3 + j.phase)
							j.coeur.CurveSize1 = j.faisceau.CurveSize1
							j.faisceau.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1 - 0.85 * i), NumberSequenceKeypoint.new(0.6, 1 - 0.5 * i), NumberSequenceKeypoint.new(1, 1) })
							j.coeur.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1 - 0.95 * i), NumberSequenceKeypoint.new(0.5, 1 - 0.4 * i), NumberSequenceKeypoint.new(1, 1) })
						end
					end
					-- Lueur et lumière
					-- (V7.5.2, G-207) la lueur bat comme un cœur, de plus en plus vite jusqu'à l'éruption
					local coeur = CORPS.Battement ~= false and (0.45 + 0.55 * Config.battementCoeur(t, duree, CORPS.BattementDebut, CORPS.BattementFin)) or 1
					if not (eclatFait and t - duree * 0.52 < 0.6) then
						lueur.FillTransparency = 1 - 0.7 * i * coeur
					end
					lueur.OutlineTransparency = 1 - i * coeur
					lumiere.Brightness = 14 * i * vacillement
					lumiere.Range = 10 + 45 * i
					lumiereTete.Brightness = 6 * i * coeur
					-- Sol brûlant
					if brulure then
						local largeur = 1 + 7 * i
						brulure.Size = Vector3.new(0.08, largeur, largeur)
						brulure.Transparency = 1 - 0.55 * i
						brulure.PointLight.Brightness = 3 * i * (genreSol and genreSol.lumiere or 1)
					end
					-- Ambiance, selon la distance
					local distance = (camera.CFrame.Position - racine.Position).Magnitude
					local proche = math.clamp(1 - distance / 90, 0, 1) * i
					-- (V7.5.1, G-240) les témoins : l'image n'est presque plus teintée, l'or vient du bord tourné vers la régénération
					teinte.TintColor = Color3.new(1, 1, 1):Lerp(couleurAmbiance, (temoin and 0.08 or 0.35) * proche)
					if temoin and (vignette or proche > 0.01) then
						if not vignette then
							vignette = vignetteTemoin(couleurAmbiance)
							garder(vignette.ecran)
						end
						vignette.maj(racine.Position, proche)
					end
					teinte.Brightness = 0.12 * proche
					eclat.Intensity = 1.4 * proche
					if proche > 0.05 then secouer(secousseMax * proche * (moi and 1 or 0.6)) end
					-- Caméra cinématique : trajet du style, respiration à l'épaule, zoom au changement (V7.5.1 : cameraCinema)
					if scene then scene.image(p, i, t) end
					-- Au moment du changement : l'éclat pour tout le monde, et la lumière avale l'écran de celui qui se régénère
					if not eclatFait and p >= 0.52 then
						eclatFait = true
						eclatChangement()
					end
					if moi and not flashFait and p >= 0.5 and not sansFlash then
						flashFait = true
						local flash = creer("ScreenGui", { Name = "TardisRegenerationFlash", ResetOnSpawn = false, IgnoreGuiInset = true, Parent = joueur.PlayerGui })
						local voile = creer("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = couleurFlash, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = flash })
						animer(voile, duree * 0.05, { BackgroundTransparency = reduit and 0.7 or 0 })
						task.delay(duree * 0.12, function() animer(voile, duree * 0.35, { BackgroundTransparency = 1 }) end)
						task.delay(duree * 0.6, function() flash:Destroy() end)
					end
					if parImage then parImage(p, i, t) end
					if p >= 1 or not racine.Parent then rendreCamera() end
				end))

				-- Lien Time Lord : les autres membres de la C.A.T. ressentent la régénération, où qu'ils soient
				if not moi and UI.lienTimeLord() and joueur.Team
					and joueur.Team.Name == Config.nomEquipe() then
					local autre = Players:GetPlayerFromCharacter(personnage)
					local maRacine_ = maRacine()
					local distance = maRacine_ and math.floor((maRacine_.Position - racine.Position).Magnitude) or 0
					if not sansFlash then -- (V6.9.9) le voile doré n'apparaît pas avec « aucun flash » ; la notification reste
						local lien = creer("ScreenGui", { Name = "TardisLienTimeLord", ResetOnSpawn = false, IgnoreGuiInset = true, Parent = joueur.PlayerGui })
						local voile = creer("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = OR_CLAIR, BackgroundTransparency = 0.75, BorderSizePixel = 0, Parent = lien })
						animer(voile, 1.5, { BackgroundTransparency = 1 })
						task.delay(1.6, function() lien:Destroy() end)
					end
					secouer(0.15)
					pcall(function()
						game:GetService("StarterGui"):SetCore("SendNotification", { Title = "Lien Time Lord",
							Text = string.format("%s se régénère (%d studs).", autre and autre.DisplayName or "Un membre de la C.A.T.", distance), Duration = 6 })
					end)
				end

				-- Après : un souffle doré s'échappe du nouveau visage, les mains fument, des braises s'échappent encore pendant
				-- une quinzaine de secondes, et le sol brûlant refroidit lentement
				task.delay(duree, function()
					rendreCamera()
					-- (V7.5.2) les nouveaux accessoires encore en attente apparaissent ; les copies inutilisées sont jetées
					task.delay(1.1, function()
						if apparitions then apparitions.finir() end
						for objet, c in anciens do c.copie:Destroy() anciens[objet] = nil end
					end)
					-- (V7.5.2, G-213) les cheveux fument aussi, et s'arrêtent avec les mains
					if CORPS.FumeeCheveux ~= false then
						for _, objet in personnage:GetChildren() do
							local typeNom = nil
							pcall(function() typeNom = objet.AccessoryType.Name end)
							local poignee = objet:IsA("Accessory") and objet:FindFirstChild("Handle")
							if poignee and Config.estCheveux(objet.Name, typeNom) then
								local fumee = creer("ParticleEmitter", { Name = "TardisRegenFumeeCheveux", Texture = FUMEE, LightEmission = 1, Color = ColorSequence.new(OR_CLAIR, OR),
									Size = NumberSequence.new(0.2, 0.7), Transparency = NumberSequence.new(0.45, 1), Speed = NumberRange.new(0.4, 1),
									Lifetime = NumberRange.new(0.8, 1.4), SpreadAngle = Vector2.new(60, 60), EmissionDirection = Enum.NormalId.Top,
									Acceleration = Vector3.new(0, 1.5, 0), Rate = Config.debitFumeeApres(0) * 0.7, Parent = poignee })
								task.spawn(function()
									for k = 1, 15 do
										task.wait(1)
										if not fumee.Parent then return end
										fumee.Rate = Config.debitFumeeApres(k) * 0.7
									end
								end)
								Debris:AddItem(fumee, 17)
								break
							end
						end
					end
					if tete.Parent then
						local souffle = creer("ParticleEmitter", { Texture = FUMEE, LightEmission = 1, Color = ColorSequence.new(OR_CLAIR, OR),
							Size = NumberSequence.new(0.3, 1.4), Transparency = NumberSequence.new(0.2, 1), Speed = NumberRange.new(3, 6),
							Lifetime = NumberRange.new(0.8, 1.3), SpreadAngle = Vector2.new(15, 15), EmissionDirection = Enum.NormalId.Front, Rate = 0, Parent = tete })
						task.delay(0.4, function() if souffle.Parent then souffle:Emit(35) end end)
						-- Deux autres expirations plus faibles, comme le 10e Docteur qui recrache l'énergie
						task.delay(4.5, function() if souffle.Parent then souffle:Emit(14) end end)
						task.delay(9, function() if souffle.Parent then souffle:Emit(8) end end)
						Debris:AddItem(souffle, 12)
					end
					for _, main in mains do
						if main.Parent then
							local volutes = creer("ParticleEmitter", { Texture = FUMEE, LightEmission = 1, Color = ColorSequence.new(OR_CLAIR, OR),
								Size = NumberSequence.new(0.15, 0.5), Transparency = NumberSequence.new(0.4, 1), Speed = NumberRange.new(0.5, 1.2),
								Lifetime = NumberRange.new(0.6, 1), SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, 2, 0), Rate = 14, Parent = main.Parent })
							local braises = creer("ParticleEmitter", { Texture = ETINCELLE, LightEmission = 1, Color = ColorSequence.new(OR, ORANGE),
								Size = NumberSequence.new(0.1, 0), Speed = NumberRange.new(0.5, 2), Lifetime = NumberRange.new(1, 2), SpreadAngle = Vector2.new(180, 180),
								Acceleration = Vector3.new(0, 2.5, 0), Rate = 6, Parent = main.Parent })
							task.spawn(function()
								for k = 1, 15 do
									task.wait(1)
									if not volutes.Parent then return end
									volutes.Rate = Config.debitFumeeApres(k)
									braises.Rate = math.max(0, 6 - k * 0.4)
								end
							end)
							Debris:AddItem(volutes, 17)
							Debris:AddItem(braises, 17)
						end
					end
					if brulure then
						local ancienne = brulure
						brulure = nil
						-- (V7.5.4, G-223) le refroidissement dépend du sol : tache noire sur l'herbe, flaque sur la neige, métal qui rougeoie longtemps
						local g = genreSol or {}
						local refroidi = g.refroidi or 12
						animer(ancienne, refroidi, { Transparency = g.transparenceFin or 1, Color = g.couleurFin or Color3.fromRGB(40, 20, 10) }, Enum.EasingStyle.Quad)
						animer(ancienne.PointLight, refroidi * 0.85, { Brightness = 0 })
						if g.materiauFin then
							task.delay(refroidi * 0.5, function() if ancienne.Parent then ancienne.Material = Enum.Material[g.materiauFin] end end)
						end
						if (g.transparenceFin or 1) < 1 then
							task.delay(refroidi, function() if ancienne.Parent then animer(ancienne, 3, { Transparency = 1 }) end end)
						end
						Debris:AddItem(ancienne, refroidi + 3.5)
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
			-- Avant la régénération (V6.7.1) : pendant le temps du choix, la peau se met à luire et des volutes dorées
			-- s'échappent des mains, pour tout le monde (le Voyageur « sent » l'énergie monter)
			personnage:GetAttributeChangedSignal("TardisRegenChoix"):Connect(function()
				local fin = personnage:GetAttribute("TardisRegenChoix")
				if not fin then return end
				local reste = math.max(fin - workspace:GetServerTimeNow(), 0.2)
				local avant = creer("Highlight", { FillColor = Color3.fromRGB(255, 170, 50), OutlineColor = Color3.fromRGB(255, 225, 120), FillTransparency = 1,
					OutlineTransparency = 1, DepthMode = Enum.HighlightDepthMode.Occluded, Parent = personnage })
				animer(avant, reste, { FillTransparency = 0.55, OutlineTransparency = 0.4 }, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
				local volutes = {}
				for _, nom in { "Left Arm", "Right Arm", "LeftHand", "RightHand", "Head" } do
					local membre = personnage:FindFirstChild(nom)
					if membre then
						table.insert(volutes, creer("ParticleEmitter", { Texture = FUMEE, LightEmission = 1, Color = ColorSequence.new(Color3.fromRGB(255, 225, 120), Color3.fromRGB(255, 170, 50)),
							Size = NumberSequence.new(0.15, 0.6), Transparency = NumberSequence.new(0.5, 1), Speed = NumberRange.new(0.5, 1.5), Lifetime = NumberRange.new(0.6, 1.2),
							SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, 2, 0), Rate = 10, Parent = membre }))
					end
				end
				task.delay(reste + 0.3, function()
					avant:Destroy()
					for _, v in volutes do v:Destroy() end
				end)
			end)
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
				UI.suivreTaille(carte) -- (V6.9.15, proposition 72) taille de l'interface
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
				local equipe = Config.nomEquipe()
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
	-- (V7.5.4, G-65 / G-141 / G-220) Vitres dorées qui pulsent, lumière dorée dans la salle, rotor qui brille en or et
	-- jets attirés par le rotor ; d = durée de la régénération (0 : rien, seulement les étincelles)
	local function orABord(d)
		local ABORD = (Config.Regeneration or {}).ABord or {}
		local OR = Color3.fromRGB(255, 190, 70)
		local reduit = UI.effetsReduits()
		local debut = os.clock()
		local objets, vitres, faisceaux = {}, {}, {}
		local function garder(o) table.insert(objets, o) return o end
		if ABORD.Vitres ~= false then
			local dossier = exterieur:FindFirstChild(Config.NomFenetres or "Fenetres", true)
			local prefixe = Config.NomVitre or "Vitre"
			for _, o in exterieur:GetDescendants() do
				if #vitres >= 8 then break end
				if o:IsA("BasePart") and ((dossier and o:IsDescendantOf(dossier)) or string.sub(o.Name, 1, #prefixe) == prefixe) then
					table.insert(vitres, {
						halo = garder(creer("Highlight", { Name = "TardisRegenVitre", Adornee = o, FillColor = OR, FillTransparency = 1, OutlineTransparency = 1,
							DepthMode = Enum.HighlightDepthMode.Occluded, Parent = o })),
						lumiere = garder(creer("PointLight", { Name = "TardisRegenVitre", Color = OR, Brightness = 0, Range = 10, Parent = o })),
					})
				end
			end
		end
		local rotor = interieur:FindFirstChild(Config.NomRotor or "Rotor")
		local rotorPart = rotor and (rotor:IsA("BasePart") and rotor or rotor:FindFirstChildWhichIsA("BasePart", true))
		local salle = (ABORD.LueurSalle ~= false and rotorPart)
			and garder(creer("PointLight", { Name = "TardisRegenSalle", Color = OR, Brightness = 0, Range = 60, Parent = rotorPart })) or nil
		local haloRotor = (ABORD.JetsVersRotor ~= false and rotorPart) and garder(creer("Highlight", { Name = "TardisRegenRotor", Adornee = rotor, FillColor = OR,
			OutlineColor = Color3.fromRGB(255, 240, 190), FillTransparency = 1, OutlineTransparency = 1, Parent = rotor })) or nil
		-- Les jets attirés : du torse de celui qui se régénère dans la salle jusqu'au rotor, courbés au hasard
		if haloRotor then
			task.delay(0.3, function()
				if not rotorPart.Parent or os.clock() - debut >= d then return end
				local cible = garder(creer("Attachment", { Name = "TardisRegenRotorCible", Parent = rotorPart }))
				local maintenant = workspace:GetServerTimeNow()
				for _, autre in Players:GetPlayers() do
					local perso = autre.Character
					local torse = perso and (perso:FindFirstChild("UpperTorso") or perso:FindFirstChild("Torso"))
					local quand = perso and tonumber(perso:GetAttribute("TardisRegeneration"))
					if torse and quand and maintenant - quand < 3 and (torse.Position - rotorPart.Position).Magnitude < 120 then
						local depart = garder(creer("Attachment", { Name = "TardisRegenVersRotor", Parent = torse }))
						for _ = 1, reduit and 1 or 3 do
							table.insert(faisceaux, garder(creer("Beam", { Name = "TardisRegenVersRotor", Attachment0 = depart, Attachment1 = cible,
								Texture = "rbxasset://textures/particles/fire_main.dds", TextureMode = Enum.TextureMode.Wrap, TextureLength = 3, TextureSpeed = 4,
								LightEmission = 1, LightInfluence = 0, Segments = 16, FaceCamera = true, CurveSize0 = math.random(-8, 8), CurveSize1 = math.random(-8, 8),
								Width0 = 0.5, Width1 = 0.15, Color = ColorSequence.new(Color3.fromRGB(255, 250, 225), OR), Transparency = NumberSequence.new(1), Parent = torse })))
						end
					end
				end
			end)
		end
		local connexion
		connexion = RunService.RenderStepped:Connect(function()
			local t = os.clock() - debut
			if t >= d then
				connexion:Disconnect()
				for _, o in objets do if o.Parent then o:Destroy() end end
				return
			end
			local p = Config.pulsationOr(t, d)
			for _, v in vitres do
				v.halo.FillTransparency = 1 - 0.6 * p
				v.lumiere.Brightness = 3 * p
			end
			-- La salle : une vague dorée de quelques secondes, au début de l'éruption
			if salle then salle.Brightness = 4 * math.clamp(1 - math.abs(t - d * 0.3) / (d * 0.2), 0, 1) end
			-- Les jets vers le rotor pendant l'éruption (15 % à 52 %) ; le rotor brille en or
			local e = math.clamp(math.min((t - d * 0.15) / (d * 0.05), (d * 0.52 - t) / (d * 0.08)), 0, 1)
			if haloRotor then
				haloRotor.FillTransparency = 1 - 0.55 * math.max(e, p * 0.4)
				haloRotor.OutlineTransparency = 1 - 0.8 * e
			end
			for _, f in faisceaux do
				if f.Parent then f.Transparency = NumberSequence.new(1 - 0.8 * e, 1 - 0.4 * e) end
			end
		end)
	end
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
		local d = tonumber(exterieur:GetAttribute("RegenerationABordDuree")) or 0
		if d > 0 then orABord(d) end
	end)

	return {}
end
