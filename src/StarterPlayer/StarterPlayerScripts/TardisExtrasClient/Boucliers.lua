-- StarterPlayerScripts > TardisExtrasClient > Boucliers (ModuleScript)
-- Boucliers : révélation, fissures, chute
-- Extrait du script principal en V6.6.3 : reçoit ce qu'il utilise, renvoie ce que la suite utilise.

return function(contexte)
	local Players, RunService, UI, animer, exterieur, partTemporaire = contexte.Players, contexte.RunService, contexte.UI, contexte.animer, contexte.exterieur, contexte.partTemporaire

	--------------------------------------------------------------------
	-- 17) Boucliers : invisibles, ils se révèlent au contact ou sous les tirs ; fissures selon l'énergie ; chute
	--------------------------------------------------------------------
	do
		local fissures = {}
		local function bullePrincipale()
			local dossier = exterieur:FindFirstChild("Boucliers")
			if not dossier then return nil end
			for _, nom in { "BouclierComplet", "BouclierBalles", "BouclierJoueurs" } do
				local modele = dossier:FindFirstChild(nom)
				local bulle = modele and modele:FindFirstChild("Bulle")
				if bulle then return bulle end
			end
			return nil
		end
		local function reveler(bulle, position, duree)
			-- Un disque de bouclier (ForceField) tangent à la bulle, là où elle est touchée
			local centre = bulle.Position
			local normale = position - centre
			if normale.Magnitude < 0.1 then return nil end
			normale = normale.Unit
			local rayon = bulle.Size.X / 2
			local patch = partTemporaire({ Name = "TardisBouclierPatch", Shape = Enum.PartType.Cylinder, Material = Enum.Material.ForceField, Color = bulle.Color,
				Transparency = 0.1, Size = Vector3.new(0.3, 7, 7), CFrame = CFrame.lookAt(centre + normale * rayon, centre + normale * (rayon + 1)) * CFrame.Angles(0, math.pi / 2, 0) })
			animer(patch, duree or 1.2, { Transparency = 1, Size = Vector3.new(0.3, 10, 10) })
			task.delay((duree or 1.2) + 0.1, function() patch:Destroy() end)
			return patch
		end
		-- Contact des joueurs : une partie du bouclier apparaît et les suit
		local patchsContact = {}
		RunService.Heartbeat:Connect(function()
			local bulle = bullePrincipale()
			if not bulle then
				for _, p in patchsContact do p:Destroy() end
				table.clear(patchsContact)
				return
			end
			local rayon = bulle.Size.X / 2
			for _, autre in Players:GetPlayers() do
				local racine = autre.Character and autre.Character:FindFirstChild("HumanoidRootPart")
				local patch = patchsContact[autre]
				if racine and math.abs((racine.Position - bulle.Position).Magnitude - rayon) < 3 then
					local normale = (racine.Position - bulle.Position).Unit
					local cf = CFrame.lookAt(bulle.Position + normale * rayon, bulle.Position + normale * (rayon + 1)) * CFrame.Angles(0, math.pi / 2, 0)
					if not patch then
						patch = partTemporaire({ Name = "TardisBouclierContact", Shape = Enum.PartType.Cylinder, Material = Enum.Material.ForceField, Color = bulle.Color,
							Transparency = 0.15, Size = Vector3.new(0.3, 8, 8), CFrame = cf })
						patchsContact[autre] = patch
					else
						patch.CFrame = cf
					end
				elseif patch then
					patch:Destroy()
					patchsContact[autre] = nil
				end
			end
		end)
		-- Impacts de tirs : révélation + fissures proportionnelles à l'énergie perdue
		local function majFissures(bulle)
			local energie = exterieur:GetAttribute("BouclierEnergie") or 100
			local voulu = math.floor((100 - energie) / 100 * 14)
			local rayon = bulle.Size.X / 2
			while #fissures < voulu do
				local direction = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5).Unit
				local longueur = 2 + math.random() * 4
				local f = partTemporaire({ Name = "TardisFissure", Material = Enum.Material.Neon, Color = Color3.fromRGB(10, 10, 20), Transparency = 0.2,
					Size = Vector3.new(0.12, 0.12, longueur), CFrame = CFrame.lookAt(bulle.Position + direction * rayon, bulle.Position + direction * rayon
						+ Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)) })
				table.insert(fissures, f)
			end
			while #fissures > voulu do table.remove(fissures):Destroy() end
		end
		exterieur:GetAttributeChangedSignal("BouclierImpactTemps"):Connect(function()
			local bulle = bullePrincipale()
			local position = exterieur:GetAttribute("BouclierImpact")
			if bulle and typeof(position) == "Vector3" then
				reveler(bulle, position, 0.8)
				majFissures(bulle)
			end
		end)
		exterieur:GetAttributeChangedSignal("BouclierEnergie"):Connect(function()
			local bulle = bullePrincipale()
			if bulle then majFissures(bulle) else for _, f in fissures do f:Destroy() end table.clear(fissures) end
		end)
		-- Chute du bouclier : il se brise en éclats
		exterieur:GetAttributeChangedSignal("BouclierBrise"):Connect(function()
			for _, f in fissures do f:Destroy() end
			table.clear(fissures)
			local centre = (exterieur:GetPivot() * CFrame.new(0, 4, 0)).Position
			for _ = 1, 30 do
				local eclat = partTemporaire({ Name = "TardisEclat", Material = Enum.Material.ForceField, Color = Color3.fromRGB(135, 206, 250), Size = Vector3.new(1.2, 1.2, 0.2),
					CFrame = CFrame.new(centre) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6) })
				eclat.Anchored = false
				eclat.CanCollide = true
				eclat.AssemblyLinearVelocity = Vector3.new(math.random() - 0.5, math.random() * 0.6 + 0.2, math.random() - 0.5).Unit * (15 + math.random() * 15)
				task.delay(3, function() eclat:Destroy() end)
			end
			UI.son("Alerte")
		end)
		task.spawn(function()
			local dossier = exterieur:WaitForChild("Boucliers", 30)
			if dossier then
				dossier.ChildRemoved:Connect(function()
					task.defer(function() if not bullePrincipale() then for _, f in fissures do f:Destroy() end table.clear(fissures) end end)
				end)
			end
		end)
	end

	return {}
end
