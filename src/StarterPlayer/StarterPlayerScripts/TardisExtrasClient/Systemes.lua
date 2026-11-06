-- StarterPlayerScripts > TardisExtrasClient > Systemes (ModuleScript)
-- Incendie, extincteur, arcs statiques, saleté, vibrations, menu des techniciens
-- Extrait du script principal en V6.6.3 : reçoit ce qu'il utilise, renvoie ce que la suite utilise.

return function(contexte)
	local C, E, Players, RunService, UI, creer = contexte.C, contexte.E, contexte.Players, contexte.RunService, contexte.UI, contexte.creer
	local def, exterieur, interieur, jeSuisDedans, joueur, maRacine = contexte.def, contexte.exterieur, contexte.interieur, contexte.jeSuisDedans, contexte.joueur, contexte.maRacine
	local partTemporaire, progressionAnimation, remote, texte = contexte.partTemporaire, contexte.progressionAnimation, contexte.remote, contexte.texte

	--------------------------------------------------------------------
	-- 19) Incendie de console, extincteur, arcs statiques, saleté, vibrations (stabilisateur), menu des techniciens
	--------------------------------------------------------------------
	do
		-- Flammes sur la console
		local flammes = {}
		local console = interieur:FindFirstChild("Console")
		local function majFlammes()
			local actif = exterieur:GetAttribute("Incendie") == true and not exterieur:GetAttribute("IncendieEteint")
			if actif and #flammes == 0 and console then
				local pieces = {}
				for _, objet in console:GetDescendants() do
					if objet:IsA("BasePart") and objet.Size.Magnitude > 1 then table.insert(pieces, objet) end
				end
				for _ = 1, math.min(3, #pieces) do
					local part = table.remove(pieces, math.random(#pieces))
					local feu = creer("Fire", { Size = 3, Heat = 8, Color = Color3.fromRGB(255, 150, 50), SecondaryColor = Color3.fromRGB(255, 60, 20), Parent = part })
					local fumee = creer("Smoke", { Color = Color3.fromRGB(60, 55, 50), Opacity = 0.3, RiseVelocity = 4, Size = 2, Parent = part })
					table.insert(flammes, feu)
					table.insert(flammes, fumee)
				end
			elseif not actif and #flammes > 0 then
				for _, f in flammes do f.Enabled = false task.delay(2, function() f:Destroy() end) end
				table.clear(flammes)
			end
		end
		exterieur:GetAttributeChangedSignal("Incendie"):Connect(majFlammes)
		exterieur:GetAttributeChangedSignal("IncendieEteint"):Connect(majFlammes)
		majFlammes()
		-- Jet d'extincteur
		exterieur:GetAttributeChangedSignal("ExtincteurJet"):Connect(function()
			local nom = string.match(exterieur:GetAttribute("ExtincteurJet") or "", "^(.-)\t")
			local autre = nom and Players:FindFirstChild(nom)
			local racine = autre and autre.Character and autre.Character:FindFirstChild("HumanoidRootPart")
			if not racine then return end
			local support = partTemporaire({ Name = "TardisExtincteur", Transparency = 1, Size = Vector3.new(0.5, 0.5, 0.5), CFrame = racine.CFrame * CFrame.new(0.8, 0.5, -1) })
			local jet = creer("ParticleEmitter", { Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(Color3.fromRGB(240, 245, 255)),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }), Size = NumberSequence.new(0.8, 3),
				Lifetime = NumberRange.new(0.6, 1), Speed = NumberRange.new(18, 26), SpreadAngle = Vector2.new(12, 12), EmissionDirection = Enum.NormalId.Front,
				Rate = 120, Parent = support })
			task.delay(1.2, function() jet.Enabled = false end)
			task.delay(3, function() support:Destroy() end)
		end)
		-- Arcs statiques
		exterieur:GetAttributeChangedSignal("ArcStatique"):Connect(function()
			local x, y, z = string.match(exterieur:GetAttribute("ArcStatique") or "", "^([%-%d%.]+)\t([%-%d%.]+)\t([%-%d%.]+)")
			if not x then return end
			local position = Vector3.new(tonumber(x), tonumber(y), tonumber(z))
			local support = partTemporaire({ Name = "TardisArc", Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(position) })
			local points = {}
			for i = 1, 6 do
				points[i] = creer("Attachment", { Position = Vector3.new((math.random() - 0.5) * 2.5, (i - 1) * 0.6 + (math.random() - 0.5), (math.random() - 0.5) * 2.5), Parent = support })
			end
			for i = 1, 5 do
				creer("Beam", { Attachment0 = points[i], Attachment1 = points[i + 1], Width0 = 0.15, Width1 = 0.15, LightEmission = 1, LightInfluence = 0, Segments = 1,
					Color = ColorSequence.new(Color3.fromRGB(190, 230, 255)), Transparency = NumberSequence.new(0.1), FaceCamera = true, Parent = support })
			end
			creer("PointLight", { Color = Color3.fromRGB(180, 220, 255), Brightness = 4, Range = 10, Parent = support })
			task.delay(0.25, function() support:Destroy() end)
		end)
		-- Saleté : un voile brun-gris sur la cabine, proportionnel ; le nettoyage fait briller
		local salete = creer("Highlight", { FillColor = Color3.fromRGB(70, 55, 40), OutlineColor = Color3.fromRGB(70, 55, 40), FillTransparency = 1, OutlineTransparency = 1,
			DepthMode = Enum.HighlightDepthMode.Occluded, Parent = exterieur })
		local function majSalete()
			local niveau = (exterieur:GetAttribute("Salete") or 0) / 100
			salete.FillTransparency = 1 - 0.5 * niveau
			salete.OutlineTransparency = 1 - 0.3 * niveau
		end
		exterieur:GetAttributeChangedSignal("Salete"):Connect(majSalete)
		majSalete()
		exterieur:GetAttributeChangedSignal("Nettoyage"):Connect(function()
			if exterieur.PrimaryPart then
				local eclat = creer("Sparkles", { SparkleColor = Color3.fromRGB(255, 255, 255), Parent = exterieur.PrimaryPart })
				task.delay(1.2, function() eclat:Destroy() end)
			end
		end)
		-- Vibrations de la cabine sans stabilisateur : pendant une démat / remat, l'extérieur tremble et les occupants bougent un peu
		local base = nil
		RunService.RenderStepped:Connect(function()
			local p = progressionAnimation()
			local actif = p ~= nil and exterieur:GetAttribute("Stabilisateur") == false and (exterieur:GetAttribute("Etat") or E.Pose) ~= E.Pose
				and not exterieur:GetAttribute("Porteur") and not exterieur:GetAttribute("VolLibre")
			if actif then
				base = base or exterieur:GetPivot()
				local f = 0.06
				exterieur:PivotTo(base * CFrame.new((math.random() - 0.5) * f, (math.random() - 0.5) * f, (math.random() - 0.5) * f))
				local racine = maRacine()
				local humanoid = joueur.Character and joueur.Character:FindFirstChildOfClass("Humanoid")
				if racine and jeSuisDedans() and not (humanoid and humanoid.Sit) and math.random() < 0.08 then
					racine.AssemblyLinearVelocity += Vector3.new((math.random() - 0.5) * 3, 0, (math.random() - 0.5) * 3)
				end
			elseif base then
				exterieur:PivotTo(base)
				base = nil
			end
		end)
		-- Menu des techniciens : les outils (affiché dès que le rôle est connu) ; (V6.9.13) + scanner et soudeur
		local guiTechnicien = nil
		local function majTechnicien()
			local technicien = joueur:GetAttribute("TardisTechnicien_" .. def.Nom) == true
			if guiTechnicien then guiTechnicien.Enabled = technicien return end
			if not technicien then return end
			local gui = creer("ScreenGui", { Name = "TardisTechnicien_" .. def.Nom, ResetOnSpawn = false, Parent = joueur:WaitForChild("PlayerGui") })
			guiTechnicien = gui
			local panneau = creer("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 20, 1, -20), Size = UDim2.fromOffset(190, 0),
				AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.fond, BackgroundTransparency = 0.1, Parent = gui },
			{ UI.coin(12), UI.contour(C.ambre, 1, 0.4), UI.marges(10), UI.pile(5) })
			UI.suivreTaille(panneau) -- (V6.9.15, proposition 72) taille de l'interface
			texte({ Text = "◆  TECHNICIEN", Font = UI.POLICE_GRAS, TextSize = 12, TextColor3 = C.ambre, LayoutOrder = 1, Parent = panneau })
			local ordre = 1
			for _, info in { { "Chiffon", "Chiffon (nettoyer la cabine)" }, { "Visseuse", "Visseuse (surcharge de vapeur)" }, { "CleMolette", "Clé à molette (vanne)" },
				{ "Extincteur", "Extincteur" }, { "Scanner", "Scanner (état d'une pièce)" }, { "Soudeur", "Soudeur (brèches)" }, -- (V6.9.13)
				{ "Retirer", "Ranger les outils" } } do
				ordre += 1
				local b = creer("TextButton", { Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = info[1] == "Retirer" and C.fond or C.panneauClair, Text = info[2],
					Font = UI.POLICE_GRAS, TextSize = 11, TextColor3 = C.texte, LayoutOrder = ordre, Parent = panneau }, { UI.coin(7) })
				b:SetAttribute("CouleurBase", b.BackgroundColor3)
				UI.rendreVivant(b)
				b.Activated:Connect(function() remote:FireServer("Outil", { outil = info[1] }) end)
			end
		end
		joueur:GetAttributeChangedSignal("TardisTechnicien_" .. def.Nom):Connect(majTechnicien)
		majTechnicien()
	end

	return {}
end
