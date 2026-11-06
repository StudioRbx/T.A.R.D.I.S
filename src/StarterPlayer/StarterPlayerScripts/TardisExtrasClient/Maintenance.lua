-- StarterPlayerScripts > TardisExtrasClient > Maintenance (ModuleScript) — V6.9.2, revu en V6.9.4
-- Bandeau « EN MAINTENANCE » en haut de l'écran, tant qu'un pilote ou un technicien a mis ce TARDIS en maintenance
-- (tablette), pour ceux que ça concerne : pilotes, techniciens, copilote de ce TARDIS, et joueurs à bord.
-- Le blocage lui-même (plus de voyage ni de vol) est fait par le serveur.
-- (V6.9.10.7) Notification de la charte « Hologramme de confinement » (maquette NOTIFICATIONS : badge jaune, texte en
-- majuscules), avec une ligne de détail ; plus de rayures qui clignotent (aucune animation en boucle).

return function(contexte)
	local Config, UI, creer, animer = contexte.Config, contexte.UI, contexte.creer, contexte.animer
	local def, exterieur, joueur, jeSuisDedans = contexte.def, contexte.exterieur, contexte.joueur, contexte.jeSuisDedans

	-- Un bandeau par TARDIS : on les empile s'il y en a plusieurs
	local rang = 0
	for i, autre in Config.Tardis do
		if autre.Nom == def.Nom then rang = i - 1 end
	end
	local ECART = 84 -- hauteur d'un bandeau et de son espace (px)
	local gui = creer("ScreenGui", { Name = "TardisMaintenance_" .. def.Nom, ResetOnSpawn = false, Enabled = false, DisplayOrder = 30,
		Parent = joueur:WaitForChild("PlayerGui") })
	local notif = UI.notification({ Name = "BandeauMaintenance", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 52 + rang * ECART),
		Size = UDim2.fromOffset(480, 0), Parent = gui }, { retrait = 112, tailleTexte = 14 })
	local bandeau = notif.cadre
	bandeau.Visible = true
	local echelle = creer("UIScale", { Scale = UI.tailleInterface(), Parent = bandeau })
	local detail = UI.ligneAide(notif.contenu, "", { Name = "Detail", LayoutOrder = 3 })

	local function concerne()
		return joueur:GetAttribute("TardisPilote_" .. def.Nom) == true or joueur:GetAttribute("TardisTechnicien_" .. def.Nom) == true
			or joueur:GetAttribute("TardisCopilote_" .. def.Nom) == true or jeSuisDedans()
	end
	local function maj()
		local raison = exterieur:GetAttribute("Maintenance")
		local visible = raison ~= nil and raison ~= false and concerne()
		if visible then
			notif.regler(UI.majuscules(string.format("%s en maintenance  ·  %s", def.Nom, tostring(raison))), "attention", "MAINTENANCE")
			local par = exterieur:GetAttribute("MaintenancePar")
			detail.Text = "Voyages et vol bloqués ; réparations, portes et boucliers restent possibles."
				.. (par and ("  ·  par " .. tostring(par)) or "")
		end
		if visible and not gui.Enabled then
			echelle.Scale = UI.tailleInterface()
			bandeau.Position = UDim2.new(0.5, 0, 0, 30 + rang * ECART)
			gui.Enabled = true
			animer(bandeau, 0.35, { Position = UDim2.new(0.5, 0, 0, 52 + rang * ECART) }, Enum.EasingStyle.Back)
			UI.son("Notification")
		elseif not visible then
			gui.Enabled = false
		end
	end
	for _, attribut in { "Maintenance", "MaintenancePar" } do exterieur:GetAttributeChangedSignal(attribut):Connect(maj) end
	for _, attribut in { "TardisPilote_" .. def.Nom, "TardisTechnicien_" .. def.Nom, "TardisCopilote_" .. def.Nom } do
		joueur:GetAttributeChangedSignal(attribut):Connect(maj)
	end
	-- Monter à bord ou sortir change aussi qui voit le bandeau (une vérification par seconde, seulement en maintenance)
	task.spawn(function()
		while true do
			task.wait(1)
			if exterieur:GetAttribute("Maintenance") then maj() end
		end
	end)
	maj()
end
