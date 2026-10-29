-- StarterPlayerScripts > TardisTablette > Placement (ModuleScript)
-- Placement d'une nouvelle localisation (fantôme du TARDIS)
-- Extrait du script principal en V6.6.3 : reçoit ce qu'il utilise, renvoie ce que la suite utilise.

return function(contexte)
	local C, Config, GuiService, Players, S, UI = contexte.C, contexte.Config, contexte.GuiService, contexte.Players, contexte.S, contexte.UI
	local UserInputService, W, camera, creer, exterieur, interieur = contexte.UserInputService, contexte.W, contexte.camera, contexte.creer, contexte.exterieur, contexte.interieur
	local notifier, ouvrir, texte = contexte.notifier, contexte.ouvrir, contexte.texte

	--------------------------------------------------------------------
	-- Placement d'une nouvelle localisation (fantôme du TARDIS)
	--------------------------------------------------------------------
	do
		local hud = creer("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24),
			Size = UDim2.fromOffset(500, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.fond, Visible = false,
			Parent = W.gui }, { UI.coin(14), UI.contour(C.ambre, 1.5, 0.3), UI.marges(12), UI.pile(8) })
		W.echelleHud = creer("UIScale", { Parent = hud })
		local hudTitre = texte({ Text = "", Font = UI.POLICE_GRAS, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center,
			LayoutOrder = 1, Parent = hud })
		texte({ Text = "Clique dans le monde pour placer · Q/E : tourner · R/F : incliner · Entrée : valider", TextSize = 12,
			TextColor3 = C.texte2, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true,
			AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = hud })
		local rangee = creer("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, LayoutOrder = 3, Parent = hud },
		{ creer("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6),
			HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }) })
		local function bouton(txt, largeur, couleur, ordre)
			local b = creer("TextButton", { Size = UDim2.fromOffset(largeur, 36), BackgroundColor3 = couleur, Text = txt,
				Font = UI.POLICE_GRAS, TextSize = 13, TextColor3 = C.texte, LayoutOrder = ordre, Parent = rangee }, { UI.coin(8) })
			b:SetAttribute("CouleurBase", couleur)
			UI.rendreVivant(b)
			return b
		end
		local bGauche = bouton("◄ 15°", 64, C.panneauClair, 1)
		local bDroite = bouton("► 15°", 64, C.panneauClair, 2)
		local bHaut = bouton("▲ 5°", 58, C.panneauClair, 3)
		local bBas = bouton("▼ 5°", 58, C.panneauClair, 4)
		local bValider = bouton("Valider", 96, C.bleu, 5)
		local bAnnuler = bouton("Annuler", 96, Color3.fromRGB(110, 40, 50), 6)

		local function testerCollision(cible)
			local taille = exterieur:GetExtentsSize()
			local hauteurRacine = exterieur.PrimaryPart.Size.Y / 2
			local marge = 0.4
			local centre = cible * CFrame.new(0, taille.Y / 2 - hauteurRacine + marge / 2, 0)
			local exclus = { exterieur, interieur }
			if S.placement and S.placement.fantome then table.insert(exclus, S.placement.fantome) end
			for _, autre in Players:GetPlayers() do
				if autre.Character then table.insert(exclus, autre.Character) end
			end
			local params = OverlapParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = exclus
			params.RespectCanCollide = true
			local reduite = Vector3.new(math.max(taille.X - marge, 0.1), math.max(taille.Y - marge, 0.1), math.max(taille.Z - marge, 0.1))
			return #workspace:GetPartBoundsInBox(centre, reduite, params) > 0
		end

		local function majPlacement()
			local p = S.placement
			if not p or not p.point then return end
			p.cframe = CFrame.new(p.point + Vector3.new(0, exterieur.PrimaryPart.Size.Y / 2, 0))
				* CFrame.Angles(0, math.rad(p.yaw), 0) * CFrame.Angles(math.rad(p.pitch), 0, 0)
			p.fantome:PivotTo(p.cframe)
			p.collision = testerCollision(p.cframe)
			p.surbrillance.FillColor = p.collision and C.rouge or C.vert
			p.surbrillance.OutlineColor = p.collision and C.rouge or C.vert
			hudTitre.Text = string.format("%s  ·  rotation %d°  ·  inclinaison %d°",
				p.collision and "▲ Collision : urgence automatique" or "Zone libre", p.yaw % 360, p.pitch)
			hudTitre.TextColor3 = p.collision and C.rouge or C.vert
		end

		local function quitter()
			if not S.placement then return end
			if S.placement.fantome then S.placement.fantome:Destroy() end
			S.placement = nil
			hud.Visible = false
			-- On rouvre la tablette
			S.ouvert = false
			ouvrir()
		end

		local function demarrer()
			if S.placement then return end
			local ancien = exterieur.Archivable
			exterieur.Archivable = true
			local fantome = exterieur:Clone()
			exterieur.Archivable = ancien
			if not fantome then
				notifier("Impossible de créer l'aperçu du TARDIS.", false)
				return
			end
			for _, objet in fantome:GetDescendants() do
				if objet:IsA("LuaSourceContainer") or objet:IsA("Sound") or objet:IsA("ProximityPrompt") or objet:IsA("ClickDetector")
					or objet:IsA("Light") or objet:IsA("LayerCollector") or objet:IsA("ParticleEmitter") then
					objet:Destroy()
				elseif objet:IsA("BasePart") then
					objet.Anchored, objet.CanCollide, objet.CanQuery, objet.CanTouch = true, false, false, false
					objet.Transparency = (objet == fantome.PrimaryPart or objet.Name == Config.NomPortailExt) and 1 or 0.55
				elseif objet:IsA("Decal") then
					objet.Transparency = 0.55
				end
			end
			fantome.Name = "TardisFantome"
			local surbrillance = creer("Highlight", { FillTransparency = 0.7, OutlineTransparency = 0,
				DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Parent = fantome })
			fantome.Parent = workspace
			S.placement = { fantome = fantome, surbrillance = surbrillance, yaw = 0, pitch = 0,
				point = exterieur:GetPivot().Position - Vector3.new(0, exterieur.PrimaryPart.Size.Y / 2, 0) }

			-- La tablette s'efface pendant le placement
			S.ouvert = false
			W.tablette.Visible = false
			W.voile.Visible = false
			W.flou.Enabled = false
			hud.Visible = true
			majPlacement()
		end

		local function viser(positionEcran)
			local p = S.placement
			if not p then return end
			local rayon = camera:ViewportPointToRay(positionEcran.X, positionEcran.Y)
			local exclus = { exterieur, interieur, p.fantome }
			for _, autre in Players:GetPlayers() do
				if autre.Character then table.insert(exclus, autre.Character) end
			end
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = exclus
			local resultat = workspace:Raycast(rayon.Origin, rayon.Direction * 2000, params)
			if resultat then
				p.point = resultat.Position
				majPlacement()
			end
		end

		local function valider()
			local p = S.placement
			if not p or not p.cframe then return end
			S.positionPerso = { cframe = p.cframe, collision = p.collision }
			local pos = p.cframe.Position
			W.infoPlacement.Text = string.format("X %d   Y %d   Z %d\nRotation %d°  ·  inclinaison %d°%s",
				pos.X, pos.Y, pos.Z, p.yaw % 360, p.pitch, p.collision and "\n▲ Collision : atterrissage en urgence." or "")
			W.infoPlacement.TextColor3 = p.collision and C.orange or C.cyan
			S.choix = { type = "position", nom = "Nouvelle localisation" }
			quitter()
			notifier("Nouvelle localisation enregistrée.", true)
		end

		local function tourner(dYaw, dPitch)
			local p = S.placement
			if not p then return end
			p.yaw += dYaw
			p.pitch = math.clamp(p.pitch + dPitch, -90, 90)
			majPlacement()
		end

		W.boutonPlacer.Activated:Connect(demarrer)
		bGauche.Activated:Connect(function() tourner(-15, 0) end)
		bDroite.Activated:Connect(function() tourner(15, 0) end)
		bHaut.Activated:Connect(function() tourner(0, 5) end)
		bBas.Activated:Connect(function() tourner(0, -5) end)
		bValider.Activated:Connect(valider)
		bAnnuler.Activated:Connect(quitter)

		UserInputService.InputBegan:Connect(function(input, traite)
			if traite or not S.placement then return end
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				viser(Vector2.new(input.Position.X, input.Position.Y) + GuiService:GetGuiInset())
			elseif input.KeyCode == Enum.KeyCode.Q then tourner(-15, 0)
			elseif input.KeyCode == Enum.KeyCode.E then tourner(15, 0)
			elseif input.KeyCode == Enum.KeyCode.R then tourner(0, 5)
			elseif input.KeyCode == Enum.KeyCode.F then tourner(0, -5)
			elseif input.KeyCode == Enum.KeyCode.Return then valider()
			end
		end)
	end

	return {}
end
