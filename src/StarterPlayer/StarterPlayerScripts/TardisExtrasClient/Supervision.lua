-- StarterPlayerScripts > TardisExtrasClient > Supervision (ModuleScript) — V6.8
--   • Remonte au serveur les erreurs des scripts du TARDIS chez ce joueur (et les avertissements « [TARDIS] … »),
--     pour le journal (TardisSupervision). Une même erreur n'est envoyée qu'une fois par minute.
--   (Les réponses des commandes du staff, affichées ici jusqu'en V6.9.3, ont été retirées en V6.9.4.)
-- Un seul exemplaire du script s'en occupe (celui du premier TARDIS).

return function(contexte)
	local Config, ReplicatedStorage, def = contexte.Config, contexte.ReplicatedStorage, contexte.def
	if def.Nom ~= Config.Tardis[1].Nom then return {} end
	local SUPERVISION = Config.Supervision or {}

	--------------------------------------------------------------------
	-- Erreurs
	--------------------------------------------------------------------
	if SUPERVISION.ErreursClients ~= false then
		task.spawn(function()
			local remote = ReplicatedStorage:WaitForChild("TardisErreursClient", 60)
			if not remote then return end
			local envoyees = {} -- [clé] = os.clock() du dernier envoi
			local function envoyer(origine, message)
				local cle = origine .. "|" .. message
				local maintenant = os.clock()
				if envoyees[cle] and maintenant - envoyees[cle] < 60 then return end
				envoyees[cle] = maintenant
				remote:FireServer(origine, string.sub(message, 1, 300))
			end
			game:GetService("ScriptContext").Error:Connect(function(message, _, script_)
				if script_ and string.find(script_:GetFullName(), "Tardis") then
					envoyer(script_.Name, tostring(message))
				end
			end)
			-- Les effets protégés (pcall) ne plantent pas : ils écrivent « [TARDIS] … » dans l'Output, qu'on relève aussi
			game:GetService("LogService").MessageOut:Connect(function(message, type_)
				if type_ == Enum.MessageType.MessageWarning and string.sub(message, 1, 8) == "[TARDIS]" then
					envoyer("Avertissement", message)
				end
			end)
		end)
	end

	return {}
end
