-- ReplicatedStorage > TardisCommandes (ModuleScript)
-- Commandes de voyage partagées par le menu rapide (T) et la tablette (Y) :
--   • protocoles (mode Normal / Urgence / Rapide / Sauvetage, atterrissage invisible) : un seul état pour les deux
--     interfaces, donc leurs interrupteurs restent synchronisés ;
--   • construction de la destination envoyée au serveur ;
--   • Démat / Remat, téléportation de poche et rematérialisation automatique (un seul minuteur) ;
--   • méthode de voyage (V6.7.1) : destination choisie avant la démat → Config.DureeVortexAuto secondes dans le
--     vortex puis remat automatique ; sinon le pilote choisit dans le vortex et clique REMAT lui-même ;
--   • paradoxe (V6.7.1) : destination dans le TARDIS → le serveur avorte et demande une confirmation ("__paradoxe") ;
--     le second clic sur REMAT force l'atterrissage (mode Catastrophe).
-- Chaque joueur n'a qu'un exemplaire de ce module (require le partage entre ses LocalScripts).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("TardisConfig"))
local UI = require(ReplicatedStorage:WaitForChild("TardisUI"))
local E = Config.Etats

local Commandes = {}

local joueur = Players.LocalPlayer
local exterieur, remote = nil, nil

local DELAI_AUTO_REMAT = Config.DureeVortexAuto or 10
local DELAI_CONFIRMATION = 15 -- secondes pendant lesquelles un second clic sur REMAT force l'atterrissage
Commandes.DELAI_AUTO_REMAT = DELAI_AUTO_REMAT

-- Annonces pour les interfaces : (texte, réussite)
Commandes.annonce = Instance.new("BindableEvent")

--------------------------------------------------------------------
-- Protocoles
--------------------------------------------------------------------
local protocoles = { mode = "Normal", invisible = false }
local interrupteursLies = {} -- { { urgence = ..., express = ..., sauvetage = ..., invisible = ... }, ... }

local function rafraichirInterrupteurs()
	for _, groupe in interrupteursLies do
		if groupe.urgence then groupe.urgence.regler(protocoles.mode == "Urgence") end
		if groupe.express then groupe.express.regler(protocoles.mode == "Express") end
		if groupe.sauvetage then groupe.sauvetage.regler(protocoles.mode == "Sauvetage") end
		if groupe.invisible then groupe.invisible.regler(protocoles.invisible) end
	end
end

function Commandes.mode()
	return protocoles.mode
end

function Commandes.reglerMode(mode)
	protocoles.mode = Config.normaliserMode(mode)
	if protocoles.mode == "Catastrophe" then protocoles.mode = "Normal" end
	rafraichirInterrupteurs()
end

function Commandes.reglerInvisible(actif)
	protocoles.invisible = actif == true
	rafraichirInterrupteurs()
end

-- Branche les interrupteurs d'une interface sur l'état partagé. Urgence, Rapide et Sauvetage s'excluent.
function Commandes.lierInterrupteurs(groupe)
	table.insert(interrupteursLies, groupe)
	for cle, mode in { urgence = "Urgence", express = "Express", sauvetage = "Sauvetage" } do
		local inter = groupe[cle]
		if inter then
			inter.surChangement = function(actif)
				Commandes.reglerMode(actif and mode or (protocoles.mode == mode and "Normal" or protocoles.mode))
			end
		end
	end
	if groupe.invisible then
		groupe.invisible.surChangement = function(actif) Commandes.reglerInvisible(actif) end
	end
	rafraichirInterrupteurs()
end

--------------------------------------------------------------------
-- Destination
--------------------------------------------------------------------
-- choix : { type = "precedent" | "lieu" | "joueur" | "position" | "historique", nom, id, cframe }
-- options (tablette) : { figer = bool, positionPerso = { cframe = CFrame } }
-- Renvoie la table attendue par le serveur, ou nil si la destination est incomplète.
function Commandes.donnees(choix, options)
	if not choix then return nil end
	options = options or {}
	local donnees = { invisible = protocoles.invisible, mode = protocoles.mode }
	if choix.type == "precedent" then
		donnees.precedent = true
	elseif choix.type == "lieu" then
		donnees.destination = choix.nom
	elseif choix.type == "joueur" then
		donnees.joueur = choix.id
		donnees.figer = options.figer == true
	elseif choix.type == "position" and options.positionPerso then
		donnees.position = options.positionPerso.cframe
	elseif choix.type == "historique" and choix.cframe then
		donnees.position = choix.cframe
	else
		return nil
	end
	return donnees
end

--------------------------------------------------------------------
-- Paradoxe : confirmation d'un atterrissage dans le TARDIS lui-même
--------------------------------------------------------------------
local paradoxeJusqua = nil -- os.clock() de fin de la fenêtre de confirmation
local paradoxeDonnees = nil -- la destination à forcer

-- Vrai tant que le bouton REMAT demande une confirmation
function Commandes.paradoxeArme()
	return paradoxeJusqua ~= nil and os.clock() < paradoxeJusqua
end

local function desarmerParadoxe()
	paradoxeJusqua, paradoxeDonnees = nil, nil
end

--------------------------------------------------------------------
-- Rematérialisation automatique (destination choisie avant la démat)
--------------------------------------------------------------------
local autoRemat = nil -- { donnees = ..., fin = os.clock() de départ, ou nil tant qu'il n'est pas dans le vortex }

-- Secondes restantes avant la rematérialisation automatique (nil s'il n'y en a pas)
function Commandes.secondesAutoRemat()
	if autoRemat and autoRemat.fin then return math.max(0, autoRemat.fin - os.clock()) end
	return nil
end

function Commandes.annulerAutoRemat()
	autoRemat = nil
end

local derniereDonnees = nil -- dernière demande de remat envoyée (pour forcer après un paradoxe)

local function surEtat()
	local etat = exterieur:GetAttribute("Etat")
	if etat == E.Vol and autoRemat and not autoRemat.fin then
		autoRemat.fin = os.clock() + DELAI_AUTO_REMAT
		local auto = autoRemat
		Commandes.annonce:Fire("Rematérialisation automatique dans " .. DELAI_AUTO_REMAT .. " s.", true)
		task.delay(DELAI_AUTO_REMAT, function()
			if autoRemat == auto then
				autoRemat = nil
				derniereDonnees = auto.donnees
				remote:FireServer("Remat", auto.donnees)
			end
		end)
	elseif etat == E.Pose then
		autoRemat = nil
		desarmerParadoxe()
	end
end

--------------------------------------------------------------------
-- Démat / Remat
--------------------------------------------------------------------
local function etatActuel() return exterieur:GetAttribute("Etat") or E.Pose end
local function estPetit() return (exterieur:GetAttribute("Echelle") or 1) < 0.999 end

function Commandes.demat(choix, options)
	if exterieur:GetAttribute("Porteur") == joueur.UserId then
		-- Téléportation de poche : il se dématérialise dans tes mains et réapparaît (petit) à la destination
		local donnees = Commandes.donnees(choix, options)
		if not donnees then
			Commandes.annonce:Fire("Choisis d'abord une destination.", false)
			return
		end
		remote:FireServer("DematPorte", donnees)
		return
	end
	-- Méthode de voyage : avec une destination, la remat sera automatique après le vortex ; sans, elle sera manuelle
	local donnees = Commandes.donnees(choix, options)
	if donnees and not estPetit() then
		autoRemat = { donnees = donnees }
	else
		autoRemat = nil
		if not estPetit() then Commandes.annonce:Fire("Sans destination : choisis-la dans le vortex, puis clique sur REMAT.", true) end
	end
	remote:FireServer("Demat", { mode = protocoles.mode })
end

-- Renvoie vrai si une commande a été envoyée
function Commandes.remat(choix, options)
	-- Confirmation d'un paradoxe : le second clic force l'atterrissage dans le TARDIS lui-même
	if Commandes.paradoxeArme() and paradoxeDonnees then
		local donnees = table.clone(paradoxeDonnees)
		donnees.forcer = true
		desarmerParadoxe()
		autoRemat = nil
		remote:FireServer("Remat", donnees)
		return true
	end
	if autoRemat and etatActuel() == E.Vol then
		-- Appui manuel pendant le compte à rebours : on part tout de suite
		local donnees = autoRemat.donnees
		autoRemat = nil
		derniereDonnees = donnees
		remote:FireServer("Remat", donnees)
		return true
	end
	local donnees
	if estPetit() then
		donnees = { invisible = protocoles.invisible, mode = protocoles.mode } -- petit : il se rematérialise sur place
	else
		donnees = Commandes.donnees(choix, options)
		if not donnees then
			if etatActuel() == E.Vol then Commandes.annonce:Fire("Choisis d'abord une destination.", false) end
			return false
		end
	end
	derniereDonnees = donnees
	remote:FireServer("Remat", donnees)
	return true
end

--------------------------------------------------------------------
-- Démarrage (appelé par chaque interface ; seul le premier appel compte)
--------------------------------------------------------------------
function Commandes.demarrer(exterieurDuJoueur, remoteDuJoueur)
	if exterieur then return Commandes end
	exterieur, remote = exterieurDuJoueur, remoteDuJoueur
	exterieur:GetAttributeChangedSignal("Etat"):Connect(surEtat)
	-- Le serveur signale un paradoxe (destination dans le TARDIS) : le bouton REMAT passe en confirmation
	remote.OnClientEvent:Connect(function(message)
		if message == "__paradoxe" and derniereDonnees then
			paradoxeJusqua = os.clock() + DELAI_CONFIRMATION
			paradoxeDonnees = derniereDonnees
			UI.son("Alerte")
			Commandes.annonce:Fire("Paradoxe : la destination est dans le TARDIS. Clique encore sur REMAT pour forcer l'atterrissage.", false)
		end
	end)
	return Commandes
end

return Commandes
