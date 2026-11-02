-- ServerScriptService > TardisPontFondation (Script) — V6.7.3
-- Pont entre les TARDIS et l'intercom du site (OS Fondation de ZONE-TSADE).
-- Écoute ServerStorage › TardisEvenements (publié par TardisExtras) et, pour une faille spatio-temporelle :
--   1. si Config.Intercom.Cible est renseigné, transmet l'annonce à cet objet de l'OS Fondation :
--        BindableEvent    → :Fire(message, donnees)
--        BindableFunction → :Invoke(message, donnees)
--        ModuleScript     → require(...).annoncer(message, donnees)  (ou .Annoncer, .Annonce, .Broadcast)
--   2. sinon (ou si l'appel échoue), fait l'annonce lui-même : bandeau en haut de l'écran de tous les joueurs,
--      alarme, et message dans le chat (RemoteEvent ReplicatedStorage › TardisAnnonceSite).
-- Un seul exemplaire pour tout le jeu (il ne se clone pas par TARDIS).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage:WaitForChild("TardisConfig"))
local INTERCOM = Config.Intercom or {}

local annonce = ReplicatedStorage:FindFirstChild("TardisAnnonceSite")
if not annonce then
	annonce = Instance.new("RemoteEvent")
	annonce.Name = "TardisAnnonceSite"
	annonce.Parent = ReplicatedStorage
end

local evenements = ServerStorage:FindFirstChild("TardisEvenements")
if not evenements then
	evenements = Instance.new("BindableEvent")
	evenements.Name = "TardisEvenements"
	evenements.Parent = ServerStorage
end

-- "ServerScriptService.OSFondation.OSAppsServeur.Intercom" → l'objet, ou nil
local function trouver(chemin)
	if type(chemin) ~= "string" or chemin == "" then return nil end
	local objet = nil
	for nom in string.gmatch(chemin, "[^%.]+") do
		if not objet then
			local ok, service = pcall(game.GetService, game, nom)
			objet = ok and service or game:FindFirstChild(nom)
		else
			objet = objet:FindFirstChild(nom)
		end
		if not objet then return nil end
	end
	return objet
end

local function versOSFondation(message, donnees)
	local cible = trouver(INTERCOM.Cible)
	if not cible then
		if INTERCOM.Cible then warn("[TARDIS] Intercom : « " .. tostring(INTERCOM.Cible) .. " » introuvable, annonce intégrée utilisée.") end
		return false
	end
	local ok, erreur = pcall(function()
		if cible:IsA("BindableEvent") then
			cible:Fire(message, donnees)
		elseif cible:IsA("BindableFunction") then
			cible:Invoke(message, donnees)
		elseif cible:IsA("ModuleScript") then
			local module = require(cible)
			local fonction = type(module) == "table" and (module.annoncer or module.Annoncer or module.Annonce or module.Broadcast)
			if type(module) == "function" then fonction = module end
			assert(type(fonction) == "function", "aucune fonction annoncer / Annoncer / Annonce / Broadcast")
			fonction(message, donnees)
		else
			error("type non géré : " .. cible.ClassName)
		end
	end)
	if not ok then warn("[TARDIS] Intercom : l'OS Fondation a refusé l'annonce (" .. tostring(erreur) .. "), annonce intégrée utilisée.") end
	return ok
end

evenements.Event:Connect(function(nom, donnees)
	if nom ~= "FailleSpatioTemporelle" or type(donnees) ~= "table" or INTERCOM.Actif == false then return end
	local message = string.format(INTERCOM.Message or "Alerte : faille spatio-temporelle détectée. Lieu : %s.", tostring(donnees.lieu or "?"))
	if not versOSFondation(message, donnees) then
		annonce:FireAllClients(INTERCOM.Titre or "INTERCOM DU SITE", message)
	end
end)

print("[TARDIS] Pont intercom prêt (" .. (INTERCOM.Cible and ("OS Fondation : " .. INTERCOM.Cible) or "annonce intégrée") .. ").")
