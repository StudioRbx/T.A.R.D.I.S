-- StarterPlayer > StarterPlayerScripts > TardisExtrasClient (LocalScript)
-- Effets et affichages supplémentaires :
--   hologramme de la map au-dessus de la console, écrans vivants et horloge de bord, gravité folle en urgence,
--   lumières synchronisées au rotor, halo de la lampe, ombre annonciatrice, air qui ondule, givre d'urgence,
--   distorsion d'écran près du TARDIS, impacts sur le bouclier, projecteur, leurre, rayon tracteur, chocs en vol,
--   enregistrement et replay du dernier vol.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local Config = require(ReplicatedStorage:WaitForChild("TardisConfig"))
local UI = require(ReplicatedStorage:WaitForChild("TardisUI"))
local C = UI.C
local creer, texte, animer = UI.creer, UI.texte, UI.animer

local joueur = Players.LocalPlayer
local camera = workspace.CurrentCamera
local def = Config.demarrerPourChaqueTardis(script) -- un exemplaire par TARDIS : tout le monde voit les trois
local exterieur, interieur = Config.modeles(def)
local remote = ReplicatedStorage:WaitForChild(Config.canal(def, "TardisCommande"))
local E = Config.Etats

local boiteInt, tailleInt = Config.boite(interieur) -- Model ou dossier (V6.9.10.2)
local function dansInterieur(position)
	local local_ = boiteInt:PointToObjectSpace(position)
	return math.abs(local_.X) <= tailleInt.X / 2 + 20 and math.abs(local_.Y) <= tailleInt.Y / 2 + 20 and math.abs(local_.Z) <= tailleInt.Z / 2 + 20
end
local function maRacine()
	return joueur.Character and joueur.Character:FindFirstChild("HumanoidRootPart")
end
local function jeSuisDedans()
	local racine = maRacine()
	return racine ~= nil and dansInterieur(racine.Position)
end
local function partTemporaire(proprietes)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	for cle, valeur in proprietes do p[cle] = valeur end
	p.Parent = workspace
	return p
end
-- Progression (0..1) de l'animation en cours (voyage ou démat en vol), et si c'est une matérialisation
local function progressionAnimation()
	local etat = exterieur:GetAttribute("Etat") or E.Pose
	local phase = exterieur:GetAttribute("VolPhase")
	local debut, mode, quoi
	if etat == E.Demat or etat == E.Remat then
		debut, mode, quoi = exterieur:GetAttribute("DebutEtat"), Config.modeDe(exterieur), etat
	elseif phase == E.Demat or phase == E.Remat then
		debut, mode, quoi = exterieur:GetAttribute("VolPhaseDebut"), Config.modeVolDe(exterieur), phase
	else
		return nil
	end
	local duree, decalage = Config.Timing(quoi, mode)
	local p = ((workspace:GetServerTimeNow() - (debut or 0)) - decalage) / duree
	if p < -0.3 or p > 1 then return nil end
	return math.clamp(p, 0, 1), quoi == E.Remat
end
-- La lampe du toit : la pièce qui contient la PointLight de l'extérieur
local lampe = nil
for _, objet in exterieur:GetDescendants() do
	if objet:IsA("PointLight") and not objet:IsDescendantOf(exterieur:FindFirstChild("Boucliers") or exterieur.PrimaryPart) then
		local support = objet.Parent:IsA("Attachment") and objet.Parent.Parent or objet.Parent
		-- La lumière peut être dans un Model "Lampe" : on prend une vraie pièce
		if support and support:IsA("Model") then support = support.PrimaryPart or support:FindFirstChildWhichIsA("BasePart", true) end
		if support and support:IsA("BasePart") then lampe = support break end
	end
end

--------------------------------------------------------------------
-- Hologramme, écrans vivants, gravité folle, moteur et vapeur, écrans de diagnostic : module Ambiance
--------------------------------------------------------------------
require(script:WaitForChild("Ambiance"))({ C = C, Config = Config, E = E, Lighting = Lighting, Players = Players, ReplicatedStorage = ReplicatedStorage, RunService = RunService, UI = UI, boiteInt = boiteInt, creer = creer, dansInterieur = dansInterieur, exterieur = exterieur, interieur = interieur, jeSuisDedans = jeSuisDedans, joueur = joueur, maRacine = maRacine, partTemporaire = partTemporaire, texte = texte })

--------------------------------------------------------------------
-- Halo et projecteur, ombre, air, distorsion, givre, impacts, leurre, rayon tracteur, chocs et secousse : module EffetsExterieurs
--------------------------------------------------------------------
local EffetsExterieurs = require(script:WaitForChild("EffetsExterieurs"))({ C = C, Config = Config, E = E, Lighting = Lighting, RunService = RunService, animer = animer, camera = camera, creer = creer, def = def, exterieur = exterieur, interieur = interieur, jeSuisDedans = jeSuisDedans, joueur = joueur, lampe = lampe, partTemporaire = partTemporaire, progressionAnimation = progressionAnimation, remote = remote })
local secouer = EffetsExterieurs.secouer

--------------------------------------------------------------------
-- Enregistrement et replay du dernier vol libre : module Replay
--------------------------------------------------------------------
require(script:WaitForChild("Replay"))({ C = C, RunService = RunService, UI = UI, UserInputService = UserInputService, camera = camera, creer = creer, exterieur = exterieur, joueur = joueur, texte = texte })

--------------------------------------------------------------------
-- Auto-destruction : compte à rebours puis explosion : module AutoDestruction
--------------------------------------------------------------------
require(script:WaitForChild("AutoDestruction"))({ ReplicatedStorage = ReplicatedStorage, RunService = RunService, animer = animer, camera = camera, creer = creer, exterieur = exterieur, jeSuisDedans = jeSuisDedans, joueur = joueur, partTemporaire = partTemporaire, secouer = secouer })

--------------------------------------------------------------------
-- Invitation et casiers (dont celui de la console) : module Interactions
--------------------------------------------------------------------
local Interactions = require(script:WaitForChild("Interactions"))({ C = C, Config = Config, UI = UI, UserInputService = UserInputService, animer = animer, camera = camera, creer = creer, exterieur = exterieur, interieur = interieur, jeSuisDedans = jeSuisDedans, joueur = joueur, maRacine = maRacine, remote = remote, texte = texte })
local afficherInvitation = Interactions.afficherInvitation

--------------------------------------------------------------------
-- Commandes de la console qui ouvrent un panneau (V6.9.10.1) : gestion de l'énergie (écran ingénieur), jukebox,
-- messages « réservé aux… » : module Console
--------------------------------------------------------------------
require(script:WaitForChild("Console"))({ C = C, Config = Config, UI = UI, UserInputService = UserInputService, camera = camera, creer = creer, def = def, exterieur = exterieur, interieur = interieur, joueur = joueur, maRacine = maRacine, remote = remote, texte = texte })

--------------------------------------------------------------------
-- Boucliers : révélation, fissures, chute : module Boucliers
--------------------------------------------------------------------
require(script:WaitForChild("Boucliers"))({ Players = Players, RunService = RunService, UI = UI, animer = animer, exterieur = exterieur, partTemporaire = partTemporaire })

--------------------------------------------------------------------
-- Régénération (équipe C.A.T.) et régénération à bord : module Regeneration
--------------------------------------------------------------------
require(script:WaitForChild("Regeneration"))({ C = C, Config = Config, Lighting = Lighting, Players = Players, ReplicatedStorage = ReplicatedStorage, RunService = RunService, UI = UI, animer = animer, camera = camera, creer = creer, def = def, exterieur = exterieur, interieur = interieur, jeSuisDedans = jeSuisDedans, joueur = joueur, maRacine = maRacine, partTemporaire = partTemporaire, remote = remote, secouer = secouer, texte = texte })

--------------------------------------------------------------------
-- Incendie, extincteur, arcs statiques, saleté, vibrations, menu des techniciens : module Systemes
--------------------------------------------------------------------
require(script:WaitForChild("Systemes"))({ C = C, E = E, Players = Players, RunService = RunService, UI = UI, creer = creer, def = def, exterieur = exterieur, interieur = interieur, jeSuisDedans = jeSuisDedans, joueur = joueur, maRacine = maRacine, partTemporaire = partTemporaire, progressionAnimation = progressionAnimation, remote = remote, texte = texte })

--------------------------------------------------------------------
-- Terrain réactif, décorations et reflets des vitres : module Decor
--------------------------------------------------------------------
require(script:WaitForChild("Decor"))({ Config = Config, ReplicatedStorage = ReplicatedStorage, RunService = RunService, UI = UI, boiteInt = boiteInt, creer = creer, exterieur = exterieur, interieur = interieur, lampe = lampe, partTemporaire = partTemporaire, secouer = secouer })

--------------------------------------------------------------------
-- Tablette en lecture seule (visiteurs et techniciens) : module TabletteLecture
--------------------------------------------------------------------
require(script:WaitForChild("TabletteLecture"))({ C = C, Players = Players, UI = UI, creer = creer, dansInterieur = dansInterieur, exterieur = exterieur, joueur = joueur, texte = texte })

--------------------------------------------------------------------
-- Tablette technicien (V6.7.2) : systèmes, régulation, interventions guidées : module TabletteTechnicien
--------------------------------------------------------------------
require(script:WaitForChild("TabletteTechnicien"))({ C = C, Config = Config, E = E, Lighting = Lighting, Players = Players, RunService = RunService, UI = UI, UserInputService = UserInputService, animer = animer, camera = camera, creer = creer, dansInterieur = dansInterieur, def = def, exterieur = exterieur, interieur = interieur, jeSuisDedans = jeSuisDedans, joueur = joueur, partTemporaire = partTemporaire, remote = remote, texte = texte })

--------------------------------------------------------------------
-- (V6.9.13) Scanner du technicien (lecture seule) et effets des nouvelles pannes : module ScannerTechnicien
--------------------------------------------------------------------
require(script:WaitForChild("ScannerTechnicien"))({ C = C, Config = Config, UI = UI, UserInputService = UserInputService, camera = camera, creer = creer, def = def, exterieur = exterieur, interieur = interieur, jeSuisDedans = jeSuisDedans, joueur = joueur, texte = texte })

--------------------------------------------------------------------
-- (V6.9.14) Badges des équipes C.A.T. et C.T.A.T. au-dessus de la tête (premier TARDIS seulement) : module Badges
--------------------------------------------------------------------
require(script:WaitForChild("Badges"))({ C = C, Config = Config, Players = Players, UI = UI, creer = creer, def = def, joueur = joueur, texte = texte })

--------------------------------------------------------------------
-- Annonce intégrée de l'intercom du site (V6.7.3) : module Intercom
--------------------------------------------------------------------
require(script:WaitForChild("Intercom"))({ C = C, Config = Config, ReplicatedStorage = ReplicatedStorage, UI = UI, animer = animer, creer = creer, def = def, joueur = joueur, texte = texte })

--------------------------------------------------------------------
-- Poste du copilote (V6.9.1) : navigation pour le joueur nommé copilote : module Copilote
--------------------------------------------------------------------
require(script:WaitForChild("Copilote"))({ C = C, Config = Config, E = E, Players = Players, UI = UI, animer = animer, creer = creer, def = def, exterieur = exterieur, joueur = joueur, remote = remote, texte = texte })

--------------------------------------------------------------------
-- Annonce de bord, traînée du Rapide, enseigne, ambiance par thème (V6.9.3) : module Signalisation
--------------------------------------------------------------------
require(script:WaitForChild("Signalisation"))({ C = C, Config = Config, E = E, RunService = RunService, UI = UI, animer = animer, creer = creer, def = def, exterieur = exterieur, interieur = interieur, jeSuisDedans = jeSuisDedans, joueur = joueur, partTemporaire = partTemporaire, texte = texte })

--------------------------------------------------------------------
-- Bandeau « en maintenance » (V6.9.2) : module Maintenance
--------------------------------------------------------------------
require(script:WaitForChild("Maintenance"))({ C = C, Config = Config, UI = UI, animer = animer, creer = creer, def = def, exterieur = exterieur, jeSuisDedans = jeSuisDedans, joueur = joueur, texte = texte })

--------------------------------------------------------------------
-- Remontée des erreurs et réponses du staff (V6.8) : module Supervision
--------------------------------------------------------------------
require(script:WaitForChild("Supervision"))({ Config = Config, ReplicatedStorage = ReplicatedStorage, def = def })

--------------------------------------------------------------------
-- (V6.9.15) Sous-titres des sons importants (démat, remat, alarme, musique…) : module SousTitres
--------------------------------------------------------------------
require(script:WaitForChild("SousTitres"))({ C = C, Config = Config, E = E, UI = UI, creer = creer, def = def, exterieur = exterieur, jeSuisDedans = jeSuisDedans, joueur = joueur, maRacine = maRacine, texte = texte })

--------------------------------------------------------------------
-- Volume des sons et découverte : module Preferences
--------------------------------------------------------------------
require(script:WaitForChild("Preferences"))({ C = C, Config = Config, UI = UI, afficherInvitation = afficherInvitation, animer = animer, creer = creer, exterieur = exterieur, interieur = interieur, joueur = joueur, remote = remote, texte = texte })