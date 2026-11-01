-- StarterPlayer > StarterPlayerScripts > TardisTablette (LocalScript)
-- TABLETTE DE BORD AVANCÉE du TARDIS : un grand écran façon tablette, avec tout en même temps.
--   Statut (anneau de progression), télémétrie, flux temporel · Navigation complète (lieux, joueurs,
--   coordonnées avec fantôme) · Scanner, occupants, journal · Systèmes, taille, voyants, statistiques.
-- Visible seulement pour les pilotes autorisés. Toutes les commandes sont revérifiées par le serveur.
-- Touche Y (ou le bouton "Tablette" du menu classique) : ouvrir / fermer.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")

local Config = require(ReplicatedStorage:WaitForChild("TardisConfig"))
local UI = require(ReplicatedStorage:WaitForChild("TardisUI"))
local E = Config.Etats
local C = UI.C
local creer, texte, animer = UI.creer, UI.texte, UI.animer

local joueur = Players.LocalPlayer
local camera = workspace.CurrentCamera
local def, monRole = Config.attendreMonTardis(joueur) -- le TARDIS de ce joueur (pilote ou technicien)
local exterieur, interieur = Config.modeles(def)
local remote = ReplicatedStorage:WaitForChild(Config.canal(def, "TardisCommande"))
-- Commandes de voyage et protocoles partagés avec le menu rapide
local Commandes = require(ReplicatedStorage:WaitForChild("TardisCommandes")).demarrer(exterieur, remote)

-- Réglages
local R = {
	TOUCHE = Enum.KeyCode.Y,     -- ouvrir / fermer
	LARGEUR = 1280,              -- taille de dessin de la tablette (mise à l'échelle selon l'écran)
	HAUTEUR = 760,
	PORTEE = 150,                -- rayon du scanner (studs)
	MAX_JOURNAL = 60,
	SEGMENTS = 48,               -- segments de l'anneau de statut
	BARRES = 34,                 -- barres du flux temporel
}

-- Tous les éléments d'interface (W) et l'état de la tablette (S), rangés dans deux tables
-- pour rester loin de la limite de 200 variables locales de Luau.
local W = {}
local V = {} -- volet latéral (outils, réglages, aide), construit plus bas
local LARGEUR_VOLET = 454 -- largeur du volet + son écart
local S = {
	ouvert = false,
	mode = "lieux",          -- "lieux", "joueurs", "coord"
	choix = nil,             -- { type = "lieu" | "joueur" | "position", ... }
	figer = false,
	positionPerso = nil,
	tailleChoisie = 1,
	glisseTaille = false,
	placement = nil,
	elementsListe = {},
	boutonsChoix = {},
	voyages = 0,
	tempsVortex = 0,
	debutVol = nil,
	debutSession = os.clock(),
	lignesJournal = {},
	compteurJournal = 0,
	points = {},
	modeScanner = "radar",   -- "radar" ou "carte"
	sentinelle = true,       -- alerte quand quelqu'un s'approche du TARDIS posé
	proches = {},            -- joueurs déjà signalés par la sentinelle
	marqueursCarte = {},     -- destinations affichées sur la mini-carte
	categories = {},         -- [nom de destination] = index de catégorie (serveur)
	pointsCarte = {},        -- joueurs affichés sur la mini-carte
	porteeCarte = 300,
}
local seuilPortes = Config.TailleOuverturePortes or 1
local TAILLE_MIN = Config.TailleMin or 0.25

--------------------------------------------------------------------
-- Construction de la tablette : panneaux, écran, barre du haut, colonnes A, B, C et dock : module Construction
--------------------------------------------------------------------
local Construction = require(script:WaitForChild("Construction"))({ C = C, Commandes = Commandes, Config = Config, Lighting = Lighting, R = R, TAILLE_MIN = TAILLE_MIN, UI = UI, W = W, creer = creer, exterieur = exterieur, joueur = joueur, remote = remote, seuilPortes = seuilPortes, texte = texte })
local panneaux = Construction.panneaux

--------------------------------------------------------------------
-- Journal, notifications et lecture de l'état du TARDIS : module Etat
--------------------------------------------------------------------
local Etat = require(script:WaitForChild("Etat"))({ C = C, Commandes = Commandes, Config = Config, E = E, Players = Players, R = R, S = S, UI = UI, W = W, animer = animer, creer = creer, exterieur = exterieur, joueur = joueur, seuilPortes = seuilPortes, texte = texte })
local cleDe, distanceDe, journaliser, lireEtat, majFiche, majInterface = Etat.cleDe, Etat.distanceDe, Etat.journaliser, Etat.lireEtat, Etat.majFiche, Etat.majInterface
local majTuile, notifier = Etat.majTuile, Etat.notifier

--------------------------------------------------------------------
-- Liste des lieux et des joueurs, commandes de voyage : module Navigation
--------------------------------------------------------------------
local Navigation = require(script:WaitForChild("Navigation"))({ C = C, Commandes = Commandes, Config = Config, E = E, Players = Players, S = S, TAILLE_MIN = TAILLE_MIN, UI = UI, UserInputService = UserInputService, W = W, animer = animer, cleDe = cleDe, creer = creer, distanceDe = distanceDe, exterieur = exterieur, joueur = joueur, majFiche = majFiche, majInterface = majInterface, notifier = notifier, remote = remote, seuilPortes = seuilPortes, texte = texte })
local changerMode, choisirFiger, construireListe, donneesDestination = Navigation.changerMode, Navigation.choisirFiger, Navigation.construireListe, Navigation.donneesDestination

--------------------------------------------------------------------
-- Ouverture et fermeture animées de la tablette : module Ouverture
--------------------------------------------------------------------
local Ouverture = require(script:WaitForChild("Ouverture"))({ LARGEUR_VOLET = LARGEUR_VOLET, R = R, S = S, UI = UI, V = V, W = W, animer = animer, camera = camera, construireListe = construireListe, def = def, joueur = joueur, panneaux = panneaux, remote = remote })
local fermer, majDisposition, ouvrir = Ouverture.fermer, Ouverture.majDisposition, Ouverture.ouvrir

--------------------------------------------------------------------
-- Placement d'une nouvelle localisation (fantôme du TARDIS) : module Placement
--------------------------------------------------------------------
require(script:WaitForChild("Placement"))({ C = C, Config = Config, GuiService = GuiService, Players = Players, S = S, UI = UI, UserInputService = UserInputService, W = W, camera = camera, creer = creer, exterieur = exterieur, interieur = interieur, notifier = notifier, ouvrir = ouvrir, texte = texte })

--------------------------------------------------------------------
-- Réglages, aide et volet latéral : module Volet
--------------------------------------------------------------------
require(script:WaitForChild("Volet"))({ C = C, Commandes = Commandes, Config = Config, R = R, S = S, UI = UI, UserInputService = UserInputService, V = V, W = W, creer = creer, def = def, exterieur = exterieur, joueur = joueur, ouvrir = ouvrir, texte = texte })

--------------------------------------------------------------------
-- Scanner (radar) et mini-carte : module Scanner
--------------------------------------------------------------------
local Scanner = require(script:WaitForChild("Scanner"))({ C = C, E = E, Players = Players, R = R, S = S, UI = UI, W = W, changerMode = changerMode, creer = creer, exterieur = exterieur, joueur = joueur, notifier = notifier, texte = texte })
local majCarte, majScanner = Scanner.majCarte, Scanner.majScanner

--------------------------------------------------------------------
-- Mises à jour lentes, balises de détresse, sentinelle et animations continues : module Suivi
--------------------------------------------------------------------
require(script:WaitForChild("Suivi"))({ C = C, Commandes = Commandes, Config = Config, E = E, Players = Players, R = R, RunService = RunService, S = S, UI = UI, W = W, animer = animer, camera = camera, def = def, distanceDe = distanceDe, exterieur = exterieur, interieur = interieur, joueur = joueur, journaliser = journaliser, lireEtat = lireEtat, majCarte = majCarte, majDisposition = majDisposition, majFiche = majFiche, majScanner = majScanner, notifier = notifier, remote = remote })

--------------------------------------------------------------------
-- Journal automatique, statistiques et mises à jour d'accès : module Journal
--------------------------------------------------------------------
require(script:WaitForChild("Journal"))({ C = C, Config = Config, E = E, Players = Players, S = S, W = W, changerMode = changerMode, choisirFiger = choisirFiger, construireListe = construireListe, def = def, exterieur = exterieur, fermer = fermer, joueur = joueur, journaliser = journaliser, majFiche = majFiche, majInterface = majInterface })

--------------------------------------------------------------------
-- Outils du volet latéral : grille par familles et pages : module Outils
--------------------------------------------------------------------
require(script:WaitForChild("Outils"))({ C = C, Config = Config, Players = Players, ReplicatedStorage = ReplicatedStorage, S = S, UI = UI, V = V, W = W, animer = animer, creer = creer, donneesDestination = donneesDestination, exterieur = exterieur, fermer = fermer, interieur = interieur, joueur = joueur, lireEtat = lireEtat, majInterface = majInterface, majTuile = majTuile, notifier = notifier, remote = remote, texte = texte })