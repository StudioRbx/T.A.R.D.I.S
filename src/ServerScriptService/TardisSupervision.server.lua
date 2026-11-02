-- ServerScriptService > TardisSupervision (Script) — V6.8
-- Intégration du TARDIS au jeu, un seul exemplaire pour tous les TARDIS :
--   1. Accès venant du jeu (Config.Acces) : niveau Adonis et liste blanche (WL) → attributs du joueur
--      TardisAccesPilote, TardisAccesTechnicien (lus par TardisServeur et TardisExtras).
--   2. Journal (Config.Journal) : tout ce qui passe sur ServerStorage › TardisEvenements ("Journal"), plus les
--      changements d'état des TARDIS, envoyés au journal du jeu (RoSysLog) si Config.Journal.Cible est renseigné.
--   3. Commande de chat : /tardis (ou /tardis help, /tardis aide) allume la balise de détresse, pour tout le monde.
--      (Les commandes du staff — statut, journal, erreurs, maintenance, recette — ont été retirées en V6.9.4 ;
--      la maintenance se règle maintenant dans la tablette des pilotes et des techniciens.)
--   4. Erreurs : celles des scripts du TARDIS chez les joueurs (RemoteEvent TardisErreursClient) et sur le serveur
--      sont notées au journal à leur première apparition.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ScriptContext = game:GetService("ScriptContext")

local Config = require(ReplicatedStorage:WaitForChild("TardisConfig"))
local E = Config.Etats
local ACCES = Config.Acces or {}
local JOURNAL = Config.Journal or {}
local SUPERVISION = Config.Supervision or {}

local function bus(nom, classe, parent)
	local objet = parent:FindFirstChild(nom)
	if not objet then
		objet = Instance.new(classe)
		objet.Name = nom
		objet.Parent = parent
	end
	return objet
end
local evenements = bus("TardisEvenements", "BindableEvent", ServerStorage)
local erreursClient = bus("TardisErreursClient", "RemoteEvent", ReplicatedStorage)

--------------------------------------------------------------------
-- 1. Accès venant du jeu
--------------------------------------------------------------------
-- Niveau Adonis du joueur (nil si Adonis n'expose pas son API : réglage G_API d'Adonis)
local function niveauAdonis(joueur)
	local api = rawget(_G, "Adonis")
	if api == nil then return nil end
	for _, nom in { "GetLevel", "GetAdminLevel", "CheckAdmin" } do
		local okF, fonction = pcall(function() return api[nom] end)
		if okF and type(fonction) == "function" then
			local ok, valeur = pcall(fonction, joueur)
			if ok then
				if type(valeur) == "number" then return valeur end
				if valeur == true then return 100 end
				if valeur == false then return 0 end
			end
		end
	end
	return nil
end

-- Le joueur est-il dans la liste nommée du module WL ?
local moduleWL, moduleWLCharge = nil, false
local function dansListeWL(joueur, nomListe)
	if type(nomListe) ~= "string" then return false end
	if not moduleWLCharge then
		moduleWLCharge = true
		local script_ = Config.trouverChemin((ACCES.WL or {}).Module)
		if script_ and script_:IsA("ModuleScript") then
			local ok, valeur = pcall(require, script_)
			if ok then moduleWL = valeur else warn("[TARDIS] Accès WL : module illisible (" .. tostring(valeur) .. ").") end
		elseif (ACCES.WL or {}).Module then
			warn("[TARDIS] Accès WL : « " .. tostring(ACCES.WL.Module) .. " » introuvable.")
		end
	end
	if type(moduleWL) ~= "table" then return false end
	local liste = moduleWL[nomListe]
	if type(liste) == "function" then
		local ok, resultat = pcall(liste, joueur)
		return ok and resultat == true
	end
	if type(liste) ~= "table" then return false end
	local nom, id = string.lower(joueur.Name), joueur.UserId
	for cle, valeur in liste do
		if valeur == id or tonumber(valeur) == id or (type(valeur) == "string" and string.lower(valeur) == nom) then return true end
		if (cle == id or tonumber(cle) == id or (type(cle) == "string" and string.lower(cle) == nom)) and valeur then return true end
	end
	return false
end

local function verifierAcces(joueur)
	local niveau = niveauAdonis(joueur)
	local adonis = ACCES.Adonis or {}
	local function parNiveau(seuil) return niveau ~= nil and (seuil or 0) > 0 and niveau >= seuil end
	local pilote = parNiveau(adonis.NiveauPilote) or dansListeWL(joueur, (ACCES.WL or {}).Pilotes)
	local technique = Config.EquipeTechnique or {}
	local dansLaCTAT = technique.DonneLeRoleTechnicien ~= false and joueur.Team ~= nil and joueur.Team.Name == (technique.Nom or "C.T.A.T.")
	local technicien = parNiveau(adonis.NiveauTechnicien) or dansListeWL(joueur, (ACCES.WL or {}).Techniciens) or dansLaCTAT
	-- On n'écrit que ce qui change (TardisServeur et TardisExtras écoutent ces attributs)
	if (joueur:GetAttribute("TardisAccesPilote") == true) ~= pilote then joueur:SetAttribute("TardisAccesPilote", pilote) end
	if (joueur:GetAttribute("TardisAccesTechnicien") == true) ~= technicien then joueur:SetAttribute("TardisAccesTechnicien", technicien) end
	if niveau ~= nil then joueur:SetAttribute("TardisNiveauAdonis", niveau) end
end
local function suivreAcces(joueur)
	task.defer(verifierAcces, joueur)
	-- Changer d'équipe (entrer dans la C.T.A.T. ou en sortir) change le rôle de technicien tout de suite
	joueur:GetPropertyChangedSignal("Team"):Connect(function() task.spawn(verifierAcces, joueur) end)
end
Players.PlayerAdded:Connect(suivreAcces)
for _, joueur in Players:GetPlayers() do suivreAcces(joueur) end
task.spawn(function()
	while true do
		task.wait(math.max(ACCES.Verification or 60, 10))
		for _, joueur in Players:GetPlayers() do task.spawn(verifierAcces, joueur) end
	end
end)

--------------------------------------------------------------------
-- 2. Journal
--------------------------------------------------------------------
local function versJournalDuJeu(categorie, message, donnees)
	local cible = Config.trouverChemin(JOURNAL.Cible)
	if not cible then return end
	local ok, erreur = pcall(function()
		if cible:IsA("BindableEvent") then
			cible:Fire("TARDIS", categorie, message, donnees)
		elseif cible:IsA("BindableFunction") then
			cible:Invoke("TARDIS", categorie, message, donnees)
		elseif cible:IsA("ModuleScript") then
			local module = require(cible)
			local fonction = type(module) == "table" and (module.log or module.Log or module.ajouter or module.Ajouter or module.Add) or module
			assert(type(fonction) == "function", "aucune fonction log / Log / ajouter / Ajouter / Add")
			fonction("TARDIS", categorie, message, donnees)
		end
	end)
	if not ok then warn("[TARDIS] Journal : le journal du jeu a refusé une ligne (" .. tostring(erreur) .. ").") end
end
local function journaliser(categorie, message, donnees)
	if JOURNAL.Output then print(string.format("[TARDIS] [%s] %s", categorie, message)) end
	if JOURNAL.Cible then task.spawn(versJournalDuJeu, categorie, message, donnees) end
end
evenements.Event:Connect(function(nom, donnees)
	if nom == "Journal" and type(donnees) == "table" then
		journaliser(tostring(donnees.categorie or "TARDIS"), tostring(donnees.message or "?"), donnees)
	elseif nom == "FailleSpatioTemporelle" and type(donnees) == "table" then
		journaliser("Sécurité", string.format("%s : faille spatio-temporelle signalée (%s).", tostring(donnees.tardis), tostring(donnees.lieu)), donnees)
	end
end)

-- Suivi des TARDIS : état, mode, pannes (les commandes, avec leur auteur, viennent de TardisServeur et TardisExtras)
local tardis = {} -- [nom] = { exterieur, interieur }
for _, def in Config.Tardis do
	task.spawn(function()
		local exterieur, interieur = Config.modeles(def)
		tardis[def.Nom] = { exterieur = exterieur, interieur = interieur, def = def }
		local nom = def.Nom
		local modeRemat = "Normal"
		local avant = exterieur:GetAttribute("Etat")
		exterieur:GetAttributeChangedSignal("Etat"):Connect(function()
			local etat = exterieur:GetAttribute("Etat")
			local lieu = tostring(exterieur:GetAttribute("Position") or "?")
			local mode = Config.modeDe(exterieur)
			if etat == E.Demat then
				journaliser("Voyage", string.format("%s : décollage %sdepuis %s.", nom, mode ~= "Normal" and (Config.libelleMode(mode) .. " ") or "", lieu))
			elseif etat == E.Remat then
				modeRemat = mode
			elseif etat == E.Pose and avant == E.Remat then
				journaliser(modeRemat == "Catastrophe" and "Sécurité" or "Voyage",
					string.format("%s : atterrissage %sà %s.", nom, modeRemat ~= "Normal" and (Config.libelleMode(modeRemat) .. " ") or "", lieu))
			end
			avant = etat
		end)
		local suivis = {
			Avarie = function(v) return v and "Sécurité", v and (nom .. " : AVARIE, intégrité à 0 %.") end,
			Detruit = function(v) return v and "Sécurité", v and (nom .. " : TARDIS détruit.") end,
			Catastrophe = function(v) return v and "Sécurité", v and (nom .. " : paradoxe, le TARDIS s'est matérialisé dans lui-même.") end,
			Incendie = function(v) return v and "Panne", v and (nom .. " : incendie de console.") end,
			VapeurSurcharge = function(v) return v and "Panne", v and (nom .. " : fuite de vapeur.") end,
			RedemarrageRequis = function(v) return v and "Panne", v and (nom .. " : coupure de sécurité, redémarrage requis.") end,
			Alerte = function(v) return "Sécurité", nom .. (v and " : alerte générale." or " : fin de l'alerte.") end,
		}
		for attribut, decrire in suivis do
			exterieur:GetAttributeChangedSignal(attribut):Connect(function()
				local categorie, message = decrire(exterieur:GetAttribute(attribut))
				if categorie and message then journaliser(categorie, message) end
			end)
		end
	end)
end

--------------------------------------------------------------------
-- 4. Erreurs (clients et serveur)
--------------------------------------------------------------------
local erreurs = {} -- [clé] = { message, origine, compte, joueurs = { [nom] = true }, premier, dernier }
local ordreErreurs = {}
local function noterErreur(origine, message, joueur)
	message = string.sub(tostring(message), 1, 300)
	local cle = origine .. "|" .. message
	local fiche = erreurs[cle]
	if not fiche then
		if #ordreErreurs >= 100 then return end -- assez pour ne pas remplir la mémoire
		fiche = { message = message, origine = origine, compte = 0, joueurs = {}, premier = os.date("!%H:%M:%S") }
		erreurs[cle] = fiche
		table.insert(ordreErreurs, cle)
		journaliser("Erreur", string.format("%s : %s%s", origine, message, joueur and (" (" .. joueur.Name .. ")") or ""))
	end
	fiche.compte += 1
	fiche.dernier = os.date("!%H:%M:%S")
	if joueur then fiche.joueurs[joueur.Name] = true end
end
-- Côté serveur : les erreurs des scripts du TARDIS
ScriptContext.Error:Connect(function(message, trace, script_)
	if script_ and string.find(script_:GetFullName(), "Tardis") then
		noterErreur("Serveur · " .. script_.Name, message)
	end
end)
-- Côté joueurs (TardisExtrasClient › Supervision) : limité à 30 messages par minute et par joueur
local quotas = {}
erreursClient.OnServerEvent:Connect(function(joueur, origine, message)
	if SUPERVISION.ErreursClients == false then return end
	if typeof(origine) ~= "string" or typeof(message) ~= "string" then return end
	local maintenant = os.clock()
	local quota = quotas[joueur]
	if not quota or maintenant - quota.debut > 60 then quota = { debut = maintenant, nombre = 0 } quotas[joueur] = quota end
	quota.nombre += 1
	if quota.nombre > 30 then return end
	noterErreur("Client · " .. string.sub(origine, 1, 60), message, joueur)
end)
Players.PlayerRemoving:Connect(function(joueur) quotas[joueur] = nil end)

--------------------------------------------------------------------
-- 3. Commande de chat : balise de détresse (/tardis, /tardis help, /tardis aide), pour tout le monde
--------------------------------------------------------------------
local derniereCommande = {}
local function commande(joueur, texte)
	texte = string.lower(texte or "")
	local alias = string.lower(SUPERVISION.CommandeChat or "/tardis")
	if string.sub(texte, 1, #alias) ~= alias then return end
	local reste = string.match(string.sub(texte, #alias + 1), "^%s*(.-)%s*$") or ""
	-- Le même message peut arriver par les deux systèmes de chat : on ne le traite qu'une fois
	local cle = joueur.UserId .. texte
	if derniereCommande[cle] and os.clock() - derniereCommande[cle] < 1 then return end
	derniereCommande[cle] = os.clock()
	if reste == "" or reste == "help" or reste == "aide" then
		local diffusion = ServerStorage:FindFirstChild("TardisBaliseDiffusion")
		if diffusion then diffusion:Fire(joueur) end
	end
end
Players.PlayerRemoving:Connect(function(joueur)
	for cle in derniereCommande do
		if string.sub(cle, 1, #tostring(joueur.UserId)) == tostring(joueur.UserId) then derniereCommande[cle] = nil end
	end
end)

-- Nouveau système de chat : une commande /tardis ; ancien système : Chatted
pcall(function()
	local TextChatService = game:GetService("TextChatService")
	local cmd = TextChatService:FindFirstChild("TardisCommandeStaff") or Instance.new("TextChatCommand")
	cmd.Name = "TardisCommandeStaff"
	cmd.PrimaryAlias = SUPERVISION.CommandeChat or "/tardis"
	cmd.Parent = TextChatService
	cmd.Triggered:Connect(function(source, texte)
		local joueur = Players:GetPlayerByUserId(source.UserId)
		if joueur then commande(joueur, texte) end
	end)
end)
local function ecouterChat(joueur) joueur.Chatted:Connect(function(message) commande(joueur, message) end) end
Players.PlayerAdded:Connect(ecouterChat)
for _, joueur in Players:GetPlayers() do ecouterChat(joueur) end

print("[TARDIS] Supervision prête (Adonis : " .. (rawget(_G, "Adonis") and "détecté" or "non détecté") .. ", journal : "
	.. (JOURNAL.Cible and JOURNAL.Cible or "interne") .. ").")
