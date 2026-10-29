-- ReplicatedStorage > TardisCommandes (ModuleScript)
-- Commandes de voyage partagées par le menu rapide (T) et la tablette (Y) :
--   • protocoles (mode Normal / Urgence / Express, atterrissage invisible) : un seul état pour les deux
--     interfaces, donc leurs interrupteurs restent synchronisés ;
--   • construction de la destination envoyée au serveur ;
--   • Démat / Remat, téléportation de poche et rematérialisation automatique (un seul minuteur).
-- Chaque joueur n'a qu'un exemplaire de ce module (require le partage entre ses LocalScripts).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("TardisConfig"))
local UI = require(ReplicatedStorage:WaitForChild("TardisUI"))
local E = Config.Etats

local Commandes = {}

local joueur = Players.LocalPlayer
local exterieur, remote = nil, nil

local DELAI_AUTO_REMAT = 15

-- Annonces pour les interfaces : (texte, réussite)
Commandes.annonce = Instance.new("BindableEvent")

--------------------------------------------------------------------
-- Protocoles
--------------------------------------------------------------------
local protocoles = { mode = "Normal", invisible = false }
local interrupteursLies = {} -- { { urgence = ..., express = ..., invisible = ... }, ... }

local function rafraichirInterrupteurs()
	for _, groupe in interrupteursLies do
		if groupe.urgence then groupe.urgence.regler(protocoles.mode == "Urgence") end
		if groupe.express then groupe.express.regler(protocoles.mode == "Express") end
		if groupe.invisible then groupe.invisible.regler(protocoles.invisible) end
	end
end

function Commandes.mode()
	return protocoles.mode
end

function Commandes.reglerMode(mode)
	protocoles.mode = Config.normaliserMode(mode)
	rafraichirInterrupteurs()
end

function Commandes.reglerInvisible(actif)
	protocoles.invisible = actif == true
	rafraichirInterrupteurs()
end

-- Branche les interrupteurs d'une interface sur l'état partagé. Urgence et Express s'excluent.
function Commandes.lierInterrupteurs(groupe)
	table.insert(interrupteursLies, groupe)
	if groupe.urgence then
		groupe.urgence.surChangement = function(actif)
			Commandes.reglerMode(actif and "Urgence" or (protocoles.mode == "Urgence" and "Normal" or protocoles.mode))
		end
	end
	if groupe.express then
		groupe.express.surChangement = function(actif)
			Commandes.reglerMode(actif and "Express" or (protocoles.mode == "Express" and "Normal" or protocoles.mode))
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
-- Rematérialisation automatique (mode de voyage « auto » des réglages)
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

local function surEtat()
	local etat = exterieur:GetAttribute("Etat")
	if etat == E.Vol and autoRemat and not autoRemat.fin then
		autoRemat.fin = os.clock() + DELAI_AUTO_REMAT
		local auto = autoRemat
		Commandes.annonce:Fire("Rematérialisation automatique dans " .. DELAI_AUTO_REMAT .. " s.", true)
		task.delay(DELAI_AUTO_REMAT, function()
			if autoRemat == auto then
				autoRemat = nil
				remote:FireServer("Remat", auto.donnees)
			end
		end)
	elseif etat == E.Pose then
		autoRemat = nil
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
	if UI.pref("modeVoyage", "auto") == "auto" and not estPetit() then
		local donnees = Commandes.donnees(choix, options)
		if not donnees then
			Commandes.annonce:Fire("Mode automatique : choisis une destination avant de décoller.", false)
			return
		end
		autoRemat = { donnees = donnees }
	end
	remote:FireServer("Demat", { mode = protocoles.mode })
end

-- Renvoie vrai si une commande a été envoyée
function Commandes.remat(choix, options)
	if autoRemat and etatActuel() == E.Vol then
		-- Appui manuel pendant le compte à rebours : on part tout de suite
		local donnees = autoRemat.donnees
		autoRemat = nil
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
	return Commandes
end

return Commandes
