-- StarterPlayerScripts > TardisExtrasClient > Replay (ModuleScript)
-- Enregistrement et replay du dernier vol libre
-- Extrait du script principal en V6.6.3 : reçoit ce qu'il utilise, renvoie ce que la suite utilise.

return function(contexte)
	local C, RunService, UI, UserInputService, camera, creer = contexte.C, contexte.RunService, contexte.UI, contexte.UserInputService, contexte.camera, contexte.creer
	local exterieur, joueur, texte = contexte.exterieur, contexte.joueur, contexte.texte

	--------------------------------------------------------------------
	-- 10) Replay du dernier vol libre (menu) : on enregistre quand je pilote, on rejoue avec une caméra qui suit
	--------------------------------------------------------------------
	do
		local enregistrement = {}
		local dernierEchantillon = 0
		local rejoue = nil
		RunService.Heartbeat:Connect(function()
			if exterieur:GetAttribute("VolLibre") == joueur.UserId and not rejoue then
				if os.clock() - dernierEchantillon >= 0.1 then
					dernierEchantillon = os.clock()
					table.insert(enregistrement, exterieur:GetPivot())
					if #enregistrement > 6000 then table.remove(enregistrement, 1) end
				end
			end
		end)
		exterieur:GetAttributeChangedSignal("VolLibre"):Connect(function()
			if exterieur:GetAttribute("VolLibre") == joueur.UserId then table.clear(enregistrement) end
			UI.replayDisponible = #enregistrement > 10
		end)

		local bandeau = creer("ScreenGui", { Name = "TardisReplay", ResetOnSpawn = false, Enabled = false, Parent = joueur:WaitForChild("PlayerGui") })
		local etiquette = texte({ Text = "REPLAY DU DERNIER VOL  ·  Échap pour quitter", Font = UI.POLICE_GRAS, TextSize = 16, TextColor3 = C.cyan,
			TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 60), Size = UDim2.fromOffset(500, 24), Parent = bandeau })

		local function arreter()
			if not rejoue then return end
			if rejoue.fantome then rejoue.fantome:Destroy() end
			rejoue = nil
			bandeau.Enabled = false
			camera.CameraType = Enum.CameraType.Custom
			local humanoid = joueur.Character and joueur.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then camera.CameraSubject = humanoid end
			joueur:SetAttribute("TardisReplay", false)
		end
		local function demarrer()
			if rejoue or #enregistrement < 10 then joueur:SetAttribute("TardisReplay", false) return end
			exterieur.Archivable = true
			local fantome = exterieur:Clone()
			if not fantome then joueur:SetAttribute("TardisReplay", false) return end
			local boucliers = fantome:FindFirstChild("Boucliers")
			if boucliers then boucliers:Destroy() end
			for _, objet in fantome:GetDescendants() do
				if objet:IsA("LuaSourceContainer") or objet:IsA("Sound") or objet:IsA("ProximityPrompt") or objet:IsA("ClickDetector") or objet:IsA("Highlight")
					or objet:IsA("BillboardGui") or objet:IsA("ParticleEmitter") then
					objet:Destroy()
				elseif objet:IsA("BasePart") then
					objet.Anchored, objet.CanCollide, objet.CanQuery, objet.CanTouch = true, false, false, false
					if objet.Transparency < 1 then objet.Transparency = 0.3 end
				end
			end
			fantome.Name = "TardisReplayFantome"
			fantome.Parent = workspace
			rejoue = { fantome = fantome, index = 1, temps = 0, taille = exterieur:GetExtentsSize() }
			bandeau.Enabled = true
			camera.CameraType = Enum.CameraType.Scriptable
		end
		RunService.RenderStepped:Connect(function(dt)
			if not rejoue then return end
			rejoue.temps += dt
			local position = rejoue.temps / 0.1 + 1
			local i = math.floor(position)
			if i >= #enregistrement then arreter() return end
			local cf = enregistrement[i]:Lerp(enregistrement[i + 1], position - i)
			rejoue.fantome:PivotTo(cf)
			local centre = (cf * CFrame.new(0, rejoue.taille.Y / 2, 0)).Position
			local suivant = enregistrement[math.min(i + 8, #enregistrement)].Position
			local direction = (suivant - cf.Position)
			direction = direction.Magnitude > 1 and direction.Unit or cf.LookVector
			local cible = centre - direction * 24 + Vector3.new(0, 8, 0)
			camera.CFrame = camera.CFrame:Lerp(CFrame.lookAt(cible, centre), math.min(dt * 4, 1))
			etiquette.Text = string.format("REPLAY DU DERNIER VOL  ·  %s  ·  Échap pour quitter", UI.formatTemps(rejoue.temps))
		end)
		UserInputService.InputBegan:Connect(function(input, traite)
			if rejoue and input.KeyCode == Enum.KeyCode.Escape then arreter() end
		end)
		joueur:GetAttributeChangedSignal("TardisReplay"):Connect(function()
			if joueur:GetAttribute("TardisReplay") then demarrer() else arreter() end
		end)
	end

	return {}
end
