-- ServerScriptService > TardisSupervision (Script) — V6.8
-- Intégration du TARDIS au jeu, un seul exemplaire pour tous les TARDIS :
--   1. Accès venant du jeu (Config.Acces) : niveau Adonis et liste blanche (WL) → attributs du joueur
--      TardisAccesPilote, TardisAccesTechnicien, TardisStaff (lus par TardisServeur et TardisExtras).
--   2. Journal (Config.Journal) : tout ce qui passe sur ServerStorage › TardisEvenements ("Journal"), plus les
--      changements d'état des TARDIS, envoyés au journal du jeu (RoSysLog) si Config.Journal.Cible est renseigné.
--   3. Commandes de chat du staff : /tardis statut · /tardis journal [n] · /tardis erreurs · /tardis commandes
--      · /tardis maintenance on|off [TARDIS_x] [raison] (V6.9.2) · /tardis recette [TARDIS_x] [complete] (V6.9.2)
--      (/tardis et /tardis help allument toujours la balise de détresse).
--   4. Erreurs : celles des scripts du TARDIS chez les joueurs (RemoteEvent TardisErreursClient) et sur le serveur
--      sont comptées, résumées dans /tardis erreurs et notées au journal à leur première apparition.

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
local messageStaff = bus("TardisMessageStaff", "RemoteEvent", ReplicatedStorage)
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

local function estStaffConfig(joueur)
	for _, id in (ACCES.Staff or {}).UserIds or {} do
		if tonumber(id) == joueur.UserId then return true end
	end
	for _, def in Config.Tardis do
		if Config.estPiloteDe(def, joueur.UserId) then return true end
	end
	return game.CreatorType == Enum.CreatorType.User and joueur.UserId == game.CreatorId
end

local function verifierAcces(joueur)
	local niveau = niveauAdonis(joueur)
	local adonis = ACCES.Adonis or {}
	local function parNiveau(seuil) return niveau ~= nil and (seuil or 0) > 0 and niveau >= seuil end
	local pilote = parNiveau(adonis.NiveauPilote) or dansListeWL(joueur, (ACCES.WL or {}).Pilotes)
	local technicien = parNiveau(adonis.NiveauTechnicien) or dansListeWL(joueur, (ACCES.WL or {}).Techniciens)
	local staff = estStaffConfig(joueur) or parNiveau(adonis.NiveauStaff)
	-- On n'écrit que ce qui change (TardisServeur et TardisExtras écoutent ces attributs)
	if (joueur:GetAttribute("TardisAccesPilote") == true) ~= pilote then joueur:SetAttribute("TardisAccesPilote", pilote) end
	if (joueur:GetAttribute("TardisAccesTechnicien") == true) ~= technicien then joueur:SetAttribute("TardisAccesTechnicien", technicien) end
	if (joueur:GetAttribute("TardisStaff") == true) ~= staff then joueur:SetAttribute("TardisStaff", staff) end
	if niveau ~= nil then joueur:SetAttribute("TardisNiveauAdonis", niveau) end
end
Players.PlayerAdded:Connect(function(joueur) task.defer(verifierAcces, joueur) end)
for _, joueur in Players:GetPlayers() do task.spawn(verifierAcces, joueur) end
task.spawn(function()
	while true do
		task.wait(math.max(ACCES.Verification or 60, 10))
		for _, joueur in Players:GetPlayers() do task.spawn(verifierAcces, joueur) end
	end
end)

--------------------------------------------------------------------
-- 2. Journal
--------------------------------------------------------------------
local lignes = {} -- { heure, categorie, message } (la plus récente en premier)
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
	table.insert(lignes, 1, { heure = os.date("!%H:%M:%S"), categorie = categorie, message = message })
	while #lignes > (JOURNAL.Taille or 200) do table.remove(lignes) end
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
-- 3. Commandes de chat du staff
--------------------------------------------------------------------
local function repondre(joueur, lignesReponse)
	messageStaff:FireClient(joueur, lignesReponse)
end

local function occupantsDe(entree)
	local pont = ServerStorage:FindFirstChild(Config.canal(entree.def, "TardisInterne"))
	local noms = {}
	for _, autre in Players:GetPlayers() do
		local racine = autre.Character and autre.Character:FindFirstChild("HumanoidRootPart")
		if racine and pont then
			local ok, dedans = pcall(function() return pont:Invoke("dansInterieur", racine.Position) end)
			if ok and dedans then table.insert(noms, autre.DisplayName) end
		end
	end
	return noms
end

local function statut()
	local reponse = { "◆ TARDIS · STATUT" }
	for _, def in Config.Tardis do
		local entree = tardis[def.Nom]
		if not entree then
			table.insert(reponse, def.Nom .. " : modèles introuvables dans le Workspace.")
		else
			local x = entree.exterieur
			local etat = x:GetAttribute("Etat") or E.Pose
			local libelle = ({ [E.Pose] = "posé", [E.Demat] = "dématérialisation", [E.Vol] = "dans le vortex", [E.Remat] = "matérialisation" })[etat] or etat
			local mode = Config.modeDe(x)
			local p = x:GetPivot().Position
			local pilotes = {}
			for _, autre in Players:GetPlayers() do
				if autre:GetAttribute("TardisPilote_" .. def.Nom) == true then table.insert(pilotes, autre.DisplayName) end
			end
			local occupants = occupantsDe(entree)
			table.insert(reponse, string.format("%s : %s%s · %s (%d, %d, %d)", def.Nom, libelle, (etat ~= E.Pose and mode ~= "Normal") and (" " .. Config.libelleMode(mode)) or "",
				tostring(x:GetAttribute("Position") or "?"), p.X, p.Y, p.Z))
			table.insert(reponse, string.format("   intégrité %s %% · énergie %s · air %s %% · %s%s%s", tostring(x:GetAttribute("PointsDeVie") or "?"),
				x:GetAttribute("Alimentation") == false and "COUPÉE" or "ok", tostring(x:GetAttribute("RegulAir") or "?"),
				(x:GetAttribute("Maintenance") and "MAINTENANCE · " or "") .. (x:GetAttribute("Alerte") and "ALERTE · " or ""), x:GetAttribute("VolLibre") and "vol libre · " or "", x:GetAttribute("Camouflage") and "camouflé" or "visible"))
			table.insert(reponse, string.format("   pilotes en ligne : %s · à bord : %s", #pilotes > 0 and table.concat(pilotes, ", ") or "aucun",
				#occupants > 0 and table.concat(occupants, ", ") or "personne"))
		end
	end
	local derniere = ordreErreurs[#ordreErreurs] and erreurs[ordreErreurs[#ordreErreurs]]
	table.insert(reponse, derniere and string.format("Dernière erreur (%s, ×%d) : %s", derniere.origine, derniere.compte, derniere.message) or "Aucune erreur depuis le démarrage.")
	return reponse
end

local function journalReponse(nombre)
	local reponse = { string.format("◆ TARDIS · JOURNAL (%d dernières lignes, heures UTC)", nombre) }
	for i = 1, math.min(nombre, #lignes) do
		local l = lignes[i]
		table.insert(reponse, string.format("%s [%s] %s", l.heure, l.categorie, l.message))
	end
	if #lignes == 0 then table.insert(reponse, "Rien depuis le démarrage.") end
	return reponse
end

local function erreursReponse()
	local reponse = { string.format("◆ TARDIS · ERREURS (%d différentes)", #ordreErreurs) }
	local triees = table.clone(ordreErreurs)
	table.sort(triees, function(a, b) return erreurs[a].compte > erreurs[b].compte end)
	for i = 1, math.min(8, #triees) do
		local f = erreurs[triees[i]]
		local joueurs = {}
		for nom in f.joueurs do table.insert(joueurs, nom) end
		table.insert(reponse, string.format("×%d · %s · %s (%s → %s)%s", f.compte, f.origine, f.message, f.premier, f.dernier,
			#joueurs > 0 and (" · " .. #joueurs .. " joueur(s)") or ""))
	end
	if #ordreErreurs == 0 then table.insert(reponse, "Aucune erreur depuis le démarrage.") end
	return reponse
end

local AIDE = {
	"◆ TARDIS · COMMANDES DU STAFF",
	"/tardis statut : état, position, intégrité, pilotes en ligne et occupants de chaque TARDIS",
	"/tardis journal [n] : les n dernières lignes du journal (10 par défaut, 30 au plus)",
	"/tardis erreurs : les erreurs des scripts du TARDIS (joueurs et serveur)",
	"/tardis maintenance on|off [TARDIS_x] [raison] : bloque (ou rend) le TARDIS pour tous sauf le staff ; sans TARDIS : tous",
	"/tardis recette [TARDIS_x] [complete] : allers-retours chronométrés sur place (Classique et Rapide ; complete : les 5 modes)",
	"/tardis help : balise de détresse (pour tout le monde)",
}

--------------------------------------------------------------------
-- Maintenance et recette (V6.9.2, ajouts C11 et C12)
--------------------------------------------------------------------
-- Les TARDIS visés : celui nommé dans les mots (« tardis_2 »), sinon tous ; renvoie la liste et les mots restants
local function ciblesEtReste(mots)
	local cibles, reste = {}, {}
	for _, mot in mots do
		local trouve = nil
		for _, def in Config.Tardis do
			if string.lower(def.Nom) == mot then trouve = def.Nom end
		end
		if trouve and tardis[trouve] then table.insert(cibles, trouve)
		elseif mot ~= "tous" and mot ~= "all" then table.insert(reste, mot) end
	end
	if #cibles == 0 then
		for _, def in Config.Tardis do if tardis[def.Nom] then table.insert(cibles, def.Nom) end end
	end
	return cibles, reste
end

local function maintenanceReponse(joueur, argument)
	local mots = {}
	for mot in string.gmatch(argument, "%S+") do table.insert(mots, mot) end
	local action = table.remove(mots, 1)
	if action ~= "on" and action ~= "off" then
		local reponse = { "◆ TARDIS · MAINTENANCE  (/tardis maintenance on|off [TARDIS_x] [raison])" }
		for _, def in Config.Tardis do
			local entree = tardis[def.Nom]
			local raison = entree and entree.exterieur:GetAttribute("Maintenance")
			table.insert(reponse, string.format("%s : %s", def.Nom, raison and ("EN MAINTENANCE · " .. tostring(raison)) or "en service"))
		end
		return reponse
	end
	local cibles, reste = ciblesEtReste(mots)
	local raison = #reste > 0 and table.concat(reste, " ") or ((Config.Maintenance or {}).Raison or "Mise à jour en cours")
	raison = string.upper(string.sub(raison, 1, 1)) .. string.sub(raison, 2, 60)
	for _, nom in cibles do
		local x = tardis[nom].exterieur
		x:SetAttribute("Maintenance", action == "on" and raison or nil)
		x:SetAttribute("MaintenancePar", action == "on" and joueur.DisplayName or nil)
	end
	journaliser("Maintenance", string.format("%s : maintenance %s par %s%s.", table.concat(cibles, ", "), action == "on" and "commencée" or "terminée",
		joueur.Name, action == "on" and (" (" .. raison .. ")") or ""), { joueur = joueur.UserId })
	return { action == "on" and string.format("Maintenance : %s bloqué(s) pour tous sauf le staff (%s).", table.concat(cibles, ", "), raison)
		or string.format("Fin de maintenance : %s de nouveau en service.", table.concat(cibles, ", ")) }
end

local recetteEnCours = {}
local function lancerRecette(joueur, argument)
	local mots = {}
	for mot in string.gmatch(argument, "%S+") do table.insert(mots, mot) end
	local cibles, reste = ciblesEtReste(mots)
	local nom = cibles[1]
	-- Sans TARDIS nommé : le premier ; avec plusieurs TARDIS, il vaut mieux le nommer
	if not nom then return { "Recette impossible : aucun TARDIS trouvé." } end
	local complete = table.find(reste, "complete") or table.find(reste, "complète") or table.find(reste, "tout")
	local modes = complete and ((Config.Recette or {}).Complete or { "Normal", "Urgence", "Express", "Sauvetage", "Silencieux" })
		or ((Config.Recette or {}).Rapide or { "Normal", "Express" })
	if recetteEnCours[nom] then return { "Une recette de " .. nom .. " est déjà en cours." } end
	local entree = tardis[nom]
	local pont = ServerStorage:FindFirstChild(Config.canal(entree.def, "TardisInterne"))
	if not pont then return { "Recette impossible : " .. nom .. " ne répond pas (pont interne absent)." } end
	local duree = 0
	for _, mode in modes do
		local d, dd = Config.Timing(E.Demat, mode)
		local r, rr = Config.Timing(E.Remat, mode)
		duree += d + dd + r + rr + 2.5
	end
	recetteEnCours[nom] = true
	task.spawn(function()
		-- Pendant les tests, le TARDIS est en maintenance (on remet l'état d'avant à la fin)
		local x = entree.exterieur
		local avant, avantPar = x:GetAttribute("Maintenance"), x:GetAttribute("MaintenancePar")
		if not avant then
			x:SetAttribute("Maintenance", "Recette automatique en cours")
			x:SetAttribute("MaintenancePar", joueur.DisplayName)
		end
		local okInvoke, ok, rapport = pcall(function() return pont:Invoke("recette", modes) end)
		if not avant then
			x:SetAttribute("Maintenance", nil)
			x:SetAttribute("MaintenancePar", avantPar)
		end
		recetteEnCours[nom] = nil
		if not okInvoke then rapport = { "Recette interrompue par une erreur : " .. tostring(ok) } ok = false end
		if type(rapport) ~= "table" then rapport = { "Recette : pas de rapport." } end
		journaliser("Recette", string.format("%s : recette %s par %s (%s).", nom, ok and "réussie" or "à revoir", joueur.Name, tostring(rapport[1])),
			{ joueur = joueur.UserId })
		if joueur.Parent then repondre(joueur, rapport) end
	end)
	return { string.format("Recette de %s lancée : %d mode(s), environ %d s. Le TARDIS passe en maintenance pendant les tests ; le rapport arrive ici.",
		nom, #modes, math.ceil(duree)) }
end

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
	local sous, argument = string.match(reste, "^(%S*)%s*(.-)$")
	-- Balise de détresse : /tardis et /tardis help (comme avant la V6.8)
	if sous == "" or sous == "help" or sous == "aide" then
		local diffusion = ServerStorage:FindFirstChild("TardisBaliseDiffusion")
		if diffusion then diffusion:Fire(joueur) end
		return
	end
	if joueur:GetAttribute("TardisStaff") ~= true then
		repondre(joueur, { "Commande réservée au staff du TARDIS." })
		return
	end
	if sous == "statut" or sous == "status" then
		repondre(joueur, statut())
	elseif sous == "journal" or sous == "log" then
		repondre(joueur, journalReponse(math.clamp(tonumber(argument) or 10, 1, 30)))
	elseif sous == "erreurs" or sous == "errors" then
		repondre(joueur, erreursReponse())
	elseif sous == "maintenance" then
		repondre(joueur, maintenanceReponse(joueur, argument))
	elseif sous == "recette" or sous == "test" then
		repondre(joueur, lancerRecette(joueur, argument))
	else
		repondre(joueur, AIDE)
	end
end

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
