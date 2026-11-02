-- ReplicatedStorage > TardisConfig (ModuleScript)
-- Tous les réglages du TARDIS au même endroit.

local Config = {}

Config.Version = "6.9.1"

-- Noms des objets dans le Workspace
-- Hiérarchie V6 : Workspace > TARDIS > <TARDIS_1> > EXTERIEURE (le Model extérieur) et INTERIEURE (le Model intérieur)
Config.NomDossierTardis = "TARDIS"
Config.NomDossierExterieur = "EXTERIEURE"
Config.NomDossierInterieur = "INTERIEURE"
Config.NomExterieur = "TARDIS" -- (ancien réglage, conservé pour compatibilité ; non utilisé en V6)                     -- Model de l'extérieur (PrimaryPart obligatoire)
Config.NomInterieur = "TARDIS_Interieur"           -- Model de l'intérieur
Config.NomDestinations = "TARDIS_DESTINATIONS" -- dossier commun aux trois TARDIS
Config.ZoneAccessible = "ACCORDE"   -- sous-dossier : atterrissage normal
Config.ZoneRestreinte = "REFUSE"    -- sous-dossier : seule une matérialisation d'URGENCE y est possible     -- Folder contenant les Parts de destination
Config.ZoneSansExpress = "SANS_EXPRESS" -- sous-dossier (V6.6.4) : un voyage Express y devient un voyage normal

-- Noms des pièces
Config.NomPortailExt = "Portail"     -- Part invisible dans l'encadrement de la porte extérieure
Config.NomPortailInt = "Portail"     -- Part invisible dans l'encadrement de la porte intérieure
Config.NomLampe = "Lampe"            -- Part avec une PointLight (sur le toit)
Config.NomRotor = "Rotor"            -- Part centrale de la console qui monte/descend

-- Emplacement des commandes dans TARDIS_Interieur, dossier par dossier.
-- Si tu déplaces un bouton, change seulement son chemin ici.
Config.Chemins = {
	Levier = { "Controls", "Matlever", "Fly", "Levier" },  -- décoller / atterrir
	Selecteur = { "Console", "Selecteur" },                -- changer de destination
	Ecran = { "Console", "Ecran" },                        -- affichage destination / état
	BoutonCamera = { "Console", "BoutonCamera" },          -- caméra au-dessus de la Lampe
	Verrou = { "Console", "LeverLeft", "Main", "Lever", "Main" }, -- verrouiller / déverrouiller les portes
	Alimentation = { "Controls", "LockLever", "Main", "Lever", "Main" }, -- couper / rétablir le courant
	Alerte = { "Console", "Circuit", "Cloister", "Switch" },  -- alerte générale (lumières rouges, urgence)
	Demarrage = { "Controls", "Power", "On" },                -- bloquer / débloquer le décollage
}

-- Alerte : si TARDIS_Interieur contient un Folder portant ce nom, seules ses lumières passent au rouge.
-- Sinon, toutes les lumières et tous les néons de l'intérieur passent au rouge.
Config.NomLedsAlerte = "LedsAlerte"
Config.CouleurAlerte = Color3.fromRGB(255, 30, 30)
Config.NomIgnorerVue = "IgnorerVue"  -- Folder optionnel : son contenu n'apparaît pas dans la vue depuis l'extérieur
Config.NomPortesInt = "PortesInterieures" -- Folder des portes de l'intérieur (cachées quand la porte est ouverte)
Config.NomArrivee = "Arrivee"             -- Part optionnelle de l'intérieur : où arrivent les joueurs embarqués
Config.NomDossierPortes = "TARDISDoors"   -- Model des battants extérieurs

-- Modes de voyage (secondes). Pour chaque mode :
--   Duree    = durée de l'ANIMATION de (dé)matérialisation
--   Decalage = le son démarre ce nombre de secondes AVANT l'animation (silence au début du fichier audio)
--   Durée totale = Decalage + Duree. Pour que l'animation finisse pile avec le son : Duree = longueur du son - Decalage
-- L'urgence (demandée ou imposée : alerte, collision, zone REFUSE au départ ou à l'arrivée) l'emporte sur les autres.
-- Libelle : le nom affiché dans les menus (la clé interne ne change pas, pour l'historique et les sauvegardes).
Config.Modes = {
	Normal = {
		Libelle = "Classique",
		Demat = { Duree = 17, Decalage = 3.25 },   -- 20,25 s au total
		Remat = { Duree = 16.86, Decalage = 2.5 }, -- 19,36 s au total
		Pulsations = 4,                            -- nombre de fondus pendant la (dé)matérialisation
		CouleurRotor = Color3.fromRGB(80, 160, 255), -- couleur du rotor pendant le voyage (V6.6.2)
		Sons = { Demat = "Demat", Remat = "Remat" },
	},
	-- Urgence : il a du mal à décoller / atterrir (animation saccadée)
	Urgence = {
		Libelle = "Urgence",
		Demat = { Duree = 14, Decalage = 2.25 },
		Remat = { Duree = 23, Decalage = 2 },
		Saccades = 0.75,       -- force des saccades : 0 = aucune, 1 = forte
		Stabilisation = 5,     -- les saccades s'apaisent pendant ces dernières secondes de l'animation
		CouleurRotor = Color3.fromRGB(255, 130, 40),
		Sons = { Demat = "Demat_Urg", Remat = "Remat_Urg" }, -- absents : sons du mode Normal
	},
	-- Rapide (ex-Express, V6.6) : voyage éclair, sans silence de départ ni saccades.
	-- Sa couleur (vert) ne se voit qu'à l'intérieur : dehors, les effets restent neutres (V6.7.1).
	Express = {
		Libelle = "Rapide",
		Demat = { Duree = 2, Decalage = 0 },
		Remat = { Duree = 2, Decalage = 0 },
		Pulsations = 2,
		Recharge = 5,          -- secondes après un voyage rapide avant d'en refaire un (sinon : voyage classique)
		CouleurRotor = Color3.fromRGB(74, 222, 128),
		CouleurDehors = false, -- la couleur du mode ne colore pas les effets extérieurs
		-- Absents : le son normal est joué sans son silence de départ, puis coupé en fondu à la fin
		Sons = { Demat = "Demat_Express", Remat = "Remat_Express" },
	},
	-- Sauvetage (V6.7.1) : décollage classique ; à l'arrivée, la cabine apparaît en hauteur, tourne lentement sur
	-- elle-même en se matérialisant et en descendant, puis ouvre ses portes toute seule.
	Sauvetage = {
		Libelle = "Sauvetage",
		Demat = { Duree = 17, Decalage = 3.25 },
		Remat = { Duree = 16.86, Decalage = 2.5 },
		Pulsations = 4,
		Hauteur = 22,          -- hauteur d'apparition au-dessus du point d'atterrissage (studs)
		Tours = 1.25,          -- tours sur elle-même pendant la descente
		OuvrirPortes = true,   -- portes ouvertes automatiquement une fois posée
		CouleurRotor = Color3.fromRGB(90, 220, 230),
		Sons = { Demat = "Demat", Remat = "Remat" },
	},
	-- Silencieux (V6.9, ajout C1) : pour les infiltrations. Ni son, ni lumière, ni poussière, ni empreinte, ni
	-- annonce à l'intercom ; la cabine s'efface et revient en souffles lents et réguliers.
	Silencieux = {
		Libelle = "Silencieux",
		Demat = { Duree = 9, Decalage = 0 },
		Remat = { Duree = 9, Decalage = 0 },
		Pulsations = 3,
		Discret = true,        -- aucun son, aucune lumière, aucun effet au sol, pas d'empreinte ni d'intercom
		CouleurRotor = Color3.fromRGB(150, 120, 230), -- à l'intérieur seulement
		CouleurDehors = false,
		Sons = {},
	},
	-- Catastrophe (V6.7.1) : la destination est À L'INTÉRIEUR du TARDIS (un joueur à bord, un lieu dans la salle).
	-- Première tentative : la matérialisation commence puis est repoussée dans le vortex (paradoxe). Le pilote doit
	-- confirmer (deuxième clic sur REMAT) pour forcer l'atterrissage : saccades violentes, console qui crache des
	-- étincelles, lumières rouges, intégrité abîmée, alerte générale.
	Catastrophe = {
		Libelle = "Catastrophe",
		Demat = { Duree = 14, Decalage = 2.25 },
		Remat = { Duree = 20, Decalage = 2 },
		Saccades = 1,
		Stabilisation = 3,
		Degats = 1500,         -- intégrité perdue à l'atterrissage forcé
		CouleurRotor = Color3.fromRGB(255, 40, 40),
		Sons = { Demat = "Demat_Urg", Remat = "Remat_Urg" },
	},
}
Config.DureeVol = 8       -- temps passé dans le vortex quand le levier fait un voyage complet
Config.DureeVortexAuto = 10 -- destination choisie avant la démat : secondes dans le vortex avant la remat automatique (V6.7.1)
Config.LevierEnExpress = false -- true : le levier de la console fait des voyages Rapides (V6.6.4)

-- L'équipe C.A.T. — Cellule d'Autorité Temporelle (V6.7.1) : ses joueurs se régénèrent (Config.Regeneration) et apparaissent dans le TARDIS.
-- Nom : celui de la Team dans le service Teams de Studio (à renommer là aussi si tu changes ce nom).
Config.Equipe = {
	Nom = "C.A.T.", -- nom exact de la Team dans Studio › Teams (Cellule d'Autorité Temporelle)
	SpawnDansLeTardis = true, -- un SpawnLocation réservé à l'équipe est créé dans l'intérieur (sur la Part "Arrivee", sinon derrière la porte)
}

-- Empreinte temporelle (V6.6.2) : après un départ visible, une silhouette translucide du TARDIS reste
-- à l'ancien emplacement, puis s'efface. Pas d'empreinte pour un départ camouflé, porté ou en vol libre.
Config.Empreinte = {
	Duree = 30,                              -- secondes avant qu'elle ait complètement disparu
	Couleur = Color3.fromRGB(120, 180, 255),
	Transparence = 0.75,                     -- transparence au départ (1 = invisible)
}
Config.Cooldown = 1       -- délai minimum entre deux actions sur la console
Config.DureeCamouflage = 2  -- durée du fondu quand le TARDIS se camoufle / réapparaît

-- Effets
Config.VitesseLampe = 6
Config.VitesseRotor = 2
Config.AmplitudeRotor = 1.5
Config.ForceSecousse = 0.3
-- Effets de (dé)matérialisation (V6.7) : chacun peut être coupé. Tout est calculé à partir du temps du serveur,
-- donc identique chez tous les joueurs.
Config.Effets = {
	Tourbillon = true,   -- poussière (ou eau) qui tourbillonne autour de la cabine à chaque souffle, près du sol
	Lueur = true,        -- la cabine irradie à chaque souffle (lumière qui fuit par les fenêtres, halo de la lampe)
	Ondes = true,        -- un anneau court au sol à chaque souffle
	Arcs = true,         -- urgence : arcs électriques sur la cabine, étincelles à la lampe
	Choc = true,         -- atterrissage : secousse d'arrivée dans la salle, bouffée de poussière dehors
	Contrejour = true,   -- intérieur : flash doux à chaque souffle pour ceux qui sont à bord (très atténué en « effets réduits »)
}

-- Vue de l'intérieur depuis l'extérieur
Config.DistanceVueMax = 60
Config.PixelsParStud = 40
Config.LumiereAmbiante = Color3.fromRGB(170, 170, 170)

-- Caméra extérieure (au-dessus de la Lampe)
Config.HauteurCamera = 3        -- hauteur de départ au-dessus de la Lampe (studs)
Config.HauteurCameraMax = 40    -- hauteur maximale avec la molette

-- Vue de la rue depuis l'intérieur
Config.RayonVueExterieur = 120                       -- rayon des décors copiés autour du TARDIS (studs)
Config.CouleurCiel = Color3.fromRGB(150, 190, 230)   -- fond derrière les décors

-- Taille réglable depuis le menu (curseur) : de TailleMin à 1 (= 100 %, taille normale)
Config.TailleMin = 0.25
Config.TaillePetite = 0.25          -- taille utilisée par le bouton "Petit" du menu classique
Config.TailleOuverturePortes = 0.7  -- en dessous de 70 % : portes bloquées, pas de vue ni de passage

-- Rapetissement et ramassage
Config.Ramassage = {
	HauteurMax = 3,                            -- on ne peut le ramasser que s'il mesure au plus 3 studs de haut
	DureeAnimation = 1.5,                      -- durée du rétrécissement / agrandissement
	AjustementMain = CFrame.new(0, 0, 0),      -- réglage fin de la prise en main (vide = tenu par le milieu)
	AjustementCeinture = CFrame.new(0, 0, 0),  -- réglage fin contre la cuisse (mode ceinture)
	DecalageEpaule = CFrame.new(1.8, 1.5, 2),  -- droite, hauteur, arrière (par rapport au torse)
	ToursParSeconde = 0.5,                     -- vitesse de rotation sur lui-même en mode épaule
}

-- Diagnostic : écrit dans l'Output chaque commande reçue par TardisExtras (à remettre à false une fois les tests finis)
Config.Debug = false

-- Vortex temporel : pendant un voyage, le TARDIS est visible et tourne à cette position, très haut dans le ciel
Config.PositionCiel = Vector3.new(2000, 2000, 2000)

-- Menu "Rotation" : temps passé dans le vortex entre la démat et la remat (secondes)
Config.DureeVortexRepositionnement = 10
-- Rappel (menu) : temps passé dans le vortex avant de réapparaître près du pilote (secondes)
Config.DureeVortexRappel = 6

-- Balise de détresse : commande de chat pour appeler le TARDIS
Config.Balise = { Commande = "/balisehelp", Duree = 300 } -- la balise s'éteint après 5 min ou quand le TARDIS arrive

-- Zones : dans TARDIS_Destinations, deux sous-dossiers possibles : "Zone accessible" (atterrissage normal)
-- et "Zone restreinte" (seule une matérialisation d'URGENCE y est possible ; sinon repli vers la destination
-- accessible la plus proche). Les points dont le nom commence par "ZDC-" servent à la saisie.

-- Zone sûre : aucun dégât à l'intérieur du TARDIS
Config.ZoneSure = true

-- Thèmes de l'intérieur (menu) : ambiance lumineuse de la salle de contrôle
Config.Themes = {
	{ nom = "Classique", ambiance = Color3.fromRGB(80, 90, 110), exterieur = Color3.fromRGB(120, 130, 150), leds = Color3.fromRGB(255, 200, 120), exposition = 0 },
	{ nom = "Alerte", ambiance = Color3.fromRGB(140, 30, 30), exterieur = Color3.fromRGB(120, 20, 20), leds = Color3.fromRGB(255, 40, 40), exposition = -0.3 },
	{ nom = "Nuit", ambiance = Color3.fromRGB(20, 25, 60), exterieur = Color3.fromRGB(15, 20, 50), leds = Color3.fromRGB(60, 90, 255), exposition = -1.2 },
	{ nom = "Flashbang", ambiance = Color3.fromRGB(255, 255, 255), exterieur = Color3.fromRGB(255, 255, 255), leds = Color3.fromRGB(255, 255, 255), exposition = 2.5 },
	{ nom = "Festive", ambiance = Color3.fromRGB(120, 60, 160), exterieur = Color3.fromRGB(80, 40, 120), leds = Color3.fromRGB(255, 80, 200), exposition = 0.2, festive = true },
	{ nom = "Ambre", ambiance = Color3.fromRGB(140, 100, 40), exterieur = Color3.fromRGB(110, 80, 30), leds = Color3.fromRGB(255, 170, 60), exposition = 0 },
}

-- Personnalisation (menu) : couleurs de la cabine proposées, et texte de l'enseigne par défaut
Config.Couleurs = {
	{ nom = "Bleu classique", couleur = Color3.fromRGB(0, 61, 165) },
	{ nom = "Bleu nuit", couleur = Color3.fromRGB(15, 30, 80) },
	{ nom = "Vert", couleur = Color3.fromRGB(20, 110, 60) },
	{ nom = "Rouge", couleur = Color3.fromRGB(150, 30, 30) },
	{ nom = "Noir", couleur = Color3.fromRGB(25, 25, 30) },
	{ nom = "Blanc", couleur = Color3.fromRGB(230, 230, 235) },
}
Config.ToleranceCouleur = 0.25 -- les pièces dont la couleur est proche de celle de la cabine sont repeintes

-- Fiche d'anomalie (menu)
Config.FicheAnomalie = {
	Numero = "SCP-TARDIS",
	Classe = "Thaumiel",
	Description = "Cabine de police britannique des années 1960, plus grande à l'intérieur qu'à l'extérieur. "
		.. "Capable de se dématérialiser et de réapparaître en tout point de l'espace. "
		.. "Réagit aux commandes de pilotes autorisés uniquement.",
	Confinement = "Doit rester sous le contrôle du personnel autorisé. Toute tentative d'entrée non autorisée doit être signalée.",
}

-- Rayon tracteur (vol libre) : portée et force
Config.Tracteur = { Portee = 40, Force = 60 }

-- Sons de l'interface (notifications) : sons intégrés à Roblox, pas de permission à accorder
Config.SonsInterface = { Notification = "rbxasset://sounds/electronicpingshort.wav", Alerte = "rbxasset://sounds/electronicpingshort.wav" }

-- Vol libre (tablette) : le TARDIS piloté à la troisième personne, dans la direction de la caméra
Config.VolLibre = {
	Niveaux = { 25, 50, 90, 150 },                       -- vitesses (studs/s) des 4 niveaux
	NomsNiveaux = { "LENT", "NORMAL", "RAPIDE", "TURBO" },
	NiveauDepart = 2,                                      -- niveau au décollage
	Inclinaison = 18,          -- inclinaison max dans la direction du mouvement (degrés)
	AltitudeMax = 600,         -- hauteur max au-dessus du point de départ (studs)
	RotationMax = 120,         -- rotation sur lui-même à pleine vitesse (degrés/s) ; elle suit la vitesse
	VitesseUrgence = 220,      -- vitesse en mode urgence (il fonce dans tous les sens et prend feu)
	ErratiqueUrgence = 0.9,    -- à quel point il part dans tous les sens en urgence (0 = tout droit)
	VentAltitude = 0.4,        -- dérive due au vent en altitude (0 = aucun vent)
	SautDistance = 45,         -- saut temporel (touche B) : distance du bond (studs)
	SautRecharge = 0.25,       -- saut temporel : délai entre deux sauts (secondes)
	TurbulencesRayon = 28,     -- turbulences : rayon autour du TARDIS en vol (studs)
	TurbulencesForce = 1,      -- turbulences : force de la poussée (0 = désactivées)
	ChampDeVision = 22,        -- degrés de champ de vision ajoutés à pleine vitesse (pilote)
	GraviteChute = 70,         -- gravité de la chute (double Espace) : plus petit = chute plus lente
	VitesseDescente = 14,      -- vitesse de l'atterrissage en douceur (studs/s)
}

-- Sentinelle : prévient les pilotes quand quelqu'un s'approche du TARDIS posé
Config.Sentinelle = {
	Rayon = 35,                -- distance de détection (studs)
}

-- Sauvegarde (DataStore) : position, taille, camouflage, verrou, alimentation, dernière destination
-- (dans Studio, il faut activer "Enable Studio Access to API Services" dans les paramètres du jeu)
Config.Sauvegarde = {
	Actif = true,
	-- V6.8.1 : sauvegarde versionnée (module TardisSauvegarde). Les anciens magasins « _v1 » sont lus une fois pour
	-- migrer, jamais modifiés : pour revenir à une version d'avant la V6.8.1, rien n'est perdu.
	NomStore = "TardisSauvegarde_v2",
	AncienStore = "TardisSauvegarde_v1",
	NomStoreExtras = "TardisExtras_v2",
	Intervalle = 60,           -- sauvegarde automatique (secondes), si quelque chose a changé
}

-- Menu de contrôle à distance : qui a le droit de l'utiliser (vérifié par le serveur)
-- Par défaut : le propriétaire du jeu. Si le jeu appartient à un groupe : les membres de rang >= RangMin.
Config.Pilotes = {
	UserIds = { 2039993113, 2973741851, 10819409819, 4366160002, 2467966666, 3855328330 },      -- joueurs autorisés
	UniquementUserIds = true, -- true : SEULS les UserIds ci-dessus ont accès (ni le propriétaire du jeu, ni le groupe)
}

-- Techniciens de TOUS les TARDIS : menu des outils (chiffon, visseuse, clé à molette, extincteur), réparations, tablette technicien
Config.Techniciens = {
	UserIds = { 10829137819, 3192865267, 2644152451 },
	UniquementUserIds = true,
}

-- Les TARDIS : un par entrée. Les listes globales ci-dessus (Config.Pilotes, Config.Techniciens) donnent déjà
-- accès à TOUS les TARDIS : n'ajoute ici que les joueurs qui ne doivent avoir accès qu'à CE TARDIS.
-- Le dossier Workspace > TARDIS > <Nom> doit contenir EXTERIEURE (avec le Model extérieur) et INTERIEURE (avec le Model intérieur).
Config.Tardis = {
	{ Nom = "TARDIS_1", Pilotes = { UserIds = {} }, Techniciens = { UserIds = {} } },
	-- { Nom = "TARDIS_2", Pilotes = { UserIds = {} }, Techniciens = { UserIds = {} } },
	-- { Nom = "TARDIS_3", Pilotes = { UserIds = {} }, Techniciens = { UserIds = {} } },
}

-- Outils multi-TARDIS (utilisés par tous les scripts)
function Config.definition(nom)
	for _, def in Config.Tardis do
		if def.Nom == nom then return def end
	end
	return nil
end
-- Une liste d'IDs, écrite { UserIds = { ... } } ou simplement { ... } : les deux sont acceptées
local function listeIds(bloc)
	if type(bloc) ~= "table" then return {} end
	if type(bloc.UserIds) == "table" then return bloc.UserIds end
	return bloc
end
local function contient(bloc, userId)
	for _, id in listeIds(bloc) do
		if tonumber(id) == tonumber(userId) then return true end
	end
	return false
end
function Config.estPiloteDe(def, userId)
	return contient(Config.Pilotes, userId) or contient(def and def.Pilotes, userId)
end
function Config.estTechnicienDe(def, userId)
	return contient(Config.Techniciens, userId) or contient(def and def.Techniciens, userId)
end
-- Le TARDIS d'un joueur : celui où il est pilote (de la config ou temporaire), sinon technicien ; nil sinon
function Config.tardisDuJoueur(joueur)
	for _, def in Config.Tardis do
		if Config.estPiloteDe(def, joueur.UserId) or joueur:GetAttribute("TardisPilote_" .. def.Nom) == true then return def, "pilote" end
	end
	for _, def in Config.Tardis do
		if Config.estTechnicienDe(def, joueur.UserId) or joueur:GetAttribute("TardisTechnicien_" .. def.Nom) == true then return def, "technicien" end
	end
	return nil
end
-- Attend que le joueur ait un TARDIS (les rôles temporaires peuvent arriver plus tard)
function Config.attendreMonTardis(joueur)
	while true do
		local def, role = Config.tardisDuJoueur(joueur)
		if def then return def, role end
		task.wait(2)
	end
end
-- Les deux Models d'un TARDIS, dans sa hiérarchie (attend qu'ils existent)
function Config.modeles(def)
	local dossier = workspace:WaitForChild(Config.NomDossierTardis):WaitForChild(def.Nom)
	local dossierExt = dossier:WaitForChild(Config.NomDossierExterieur)
	local dossierInt = dossier:WaitForChild(Config.NomDossierInterieur)
	local exterieur, interieur = dossierExt:FindFirstChildWhichIsA("Model"), dossierInt:FindFirstChildWhichIsA("Model")
	while not exterieur or not interieur do
		task.wait(0.5)
		exterieur, interieur = dossierExt:FindFirstChildWhichIsA("Model"), dossierInt:FindFirstChildWhichIsA("Model")
	end
	return exterieur, interieur
end
-- Le dossier des destinations : à la racine du Workspace, ou dans le dossier TARDIS (attend qu'il existe)
local cacheDestinations = nil
function Config.dossierDestinations(attendre)
	-- Mémorisé : la recherche ne se fait qu'une fois (elle est appelée très souvent par les menus)
	if cacheDestinations and cacheDestinations.Parent then return cacheDestinations end
	local nom = Config.NomDestinations or "TARDIS_DESTINATIONS"
	while true do
		local dossierTardis = workspace:FindFirstChild(Config.NomDossierTardis or "TARDIS")
		local dossier = workspace:FindFirstChild(nom) or (dossierTardis and dossierTardis:FindFirstChild(nom))
		if dossier then
			cacheDestinations = dossier
			return dossier
		end
		if not attendre then return nil end
		task.wait(1)
	end
end
-- Nom d'un canal propre à un TARDIS (RemoteEvent, pont, sauvegarde...)
function Config.canal(def, base) return base .. "_" .. def.Nom end
-- Un exemplaire de script par TARDIS : le script d'origine se clone pour les TARDIS 2, 3... et garde le premier.
-- Renvoie la définition du TARDIS dont cet exemplaire s'occupe.
function Config.demarrerPourChaqueTardis(scriptCourant)
	local nom = scriptCourant:GetAttribute("Tardis")
	if not nom then
		nom = Config.Tardis[1].Nom
		scriptCourant:SetAttribute("Tardis", nom)
		for i = 2, #Config.Tardis do
			local clone = scriptCourant:Clone()
			clone:SetAttribute("Tardis", Config.Tardis[i].Nom)
			clone.Name = scriptCourant.Name .. "_" .. Config.Tardis[i].Nom
			clone.Parent = scriptCourant.Parent
		end
	end
	return Config.definition(nom)
end

-- Rôles temporaires (menu Équipage) : durées proposées pour promouvoir un pilote ou bannir un joueur
Config.DureesRoles = {
	{ nom = "Session", session = true },        -- tant que le pilote qui l'a décidé est connecté
	{ nom = "30 min", secondes = 30 * 60 },
	{ nom = "2 heures", secondes = 2 * 3600 },
	{ nom = "1 jour", secondes = 24 * 3600 },
	{ nom = "7 jours", secondes = 7 * 24 * 3600 },
}

-- Tenues (casiers, régénération du pilote) : identifiants du haut (shirt) et du bas (pants)
Config.Tenues = {
	{ nom = "Pannaro", description = "Tenue de soirée, festive", pieces = 3, shirt = 100019804704944, pant = 121690600465062, categorie = "Festive" },
	{ nom = "Abete", description = "Tenue classique, verte", pieces = 3, shirt = 130782275960154, pant = 135250026467746, categorie = "Comité d'Éthique" },
	{ nom = "Corde", description = "Tenue élégante, beige", pieces = 3, shirt = 76558494418103, pant = 105107391069292, categorie = "Ressources Humaines" },
	{ nom = "Fausto", description = "Tenue élégante, bleu encre", pieces = 3, shirt = 88333401988867, pant = 114724562684426, categorie = "Bureau de l'Admin" },
	{ nom = "Vittorio", description = "Tenue bureautique, bleu nuit", pieces = 2, shirt = 80041210803159, pant = 92288629740957, categorie = "Bureau de l'Admin" },
	{ nom = "Bluastro", description = "Tenue élégante, bleu nuit", pieces = 3, shirt = 129300251186581, pant = 93694737125546, categorie = "Bureau de l'Admin" },
	{ nom = "Bosco", description = "Tenue de soirée, verte empire", pieces = 3, shirt = 71805702832032, pant = 140628082900995, categorie = "Comité d'Éthique" },
	{ nom = "Azzurro Regale", description = "Tenue de soirée, festive", pieces = 2, shirt = 136905636988372, pant = 115784919982763, categorie = "Festive" },
	{ nom = "Canard", description = "Tenue de riche, blanc et or", pieces = 3, shirt = 12608642007, pant = 12608643961, categorie = "Festive" },
}

-- Styles de l'intérieur (menu Customisation) : appliqués aux pièces des dossiers "Murs" et "Sol" de l'intérieur
Config.StylesInterieur = {
	{ nom = "Classique", murs = { couleur = Color3.fromRGB(45, 60, 90), materiau = Enum.Material.Metal }, sol = { couleur = Color3.fromRGB(35, 40, 55), materiau = Enum.Material.DiamondPlate } },
	{ nom = "Victorien", murs = { couleur = Color3.fromRGB(96, 60, 36), materiau = Enum.Material.Wood }, sol = { couleur = Color3.fromRGB(70, 42, 25), materiau = Enum.Material.WoodPlanks } },
	{ nom = "Futuriste", murs = { couleur = Color3.fromRGB(235, 240, 245), materiau = Enum.Material.SmoothPlastic }, sol = { couleur = Color3.fromRGB(200, 205, 215), materiau = Enum.Material.Marble } },
	{ nom = "Sombre", murs = { couleur = Color3.fromRGB(22, 22, 28), materiau = Enum.Material.Slate }, sol = { couleur = Color3.fromRGB(15, 15, 20), materiau = Enum.Material.Basalt } },
	{ nom = "Corail", murs = { couleur = Color3.fromRGB(150, 95, 60), materiau = Enum.Material.Concrete }, sol = { couleur = Color3.fromRGB(90, 60, 40), materiau = Enum.Material.Cobblestone } },
	{ nom = "Cristal", murs = { couleur = Color3.fromRGB(120, 200, 230), materiau = Enum.Material.Glass }, sol = { couleur = Color3.fromRGB(60, 120, 160), materiau = Enum.Material.Ice } },
}
-- Styles de la console (menu Customisation) : couleur dominante et matériau des pièces de la console
Config.StylesConsole = {
	{ nom = "Classique", couleur = Color3.fromRGB(120, 125, 135), materiau = Enum.Material.Metal },
	{ nom = "Cuivre", couleur = Color3.fromRGB(170, 100, 50), materiau = Enum.Material.Metal },
	{ nom = "Bois", couleur = Color3.fromRGB(110, 70, 40), materiau = Enum.Material.Wood },
	{ nom = "Blanc", couleur = Color3.fromRGB(230, 232, 236), materiau = Enum.Material.SmoothPlastic },
	{ nom = "Obsidienne", couleur = Color3.fromRGB(25, 25, 30), materiau = Enum.Material.Glass },
}

-- Jukebox (tablette › Ambiance) : musiques audibles SEULEMENT à bord (V6.7.3 : son local, en fondu quand on entre
-- ou sort). categorie = "Action" : la piste fait partie de la playlist Action (lecture aléatoire, enchaînée).
-- Les identifiants doivent être des sons publics (ou appartenant au jeu) : à vérifier dans la Toolbox de Studio.
Config.Jukebox = {
	-- { nom = "Nom de la musique", id = 1234567890, categorie = "Action" },
}

-- Sons créés au démarrage s'ils n'existent pas déjà dans ReplicatedStorage › TardisAssets › Sons (V6.7.3).
-- Valeur : un identifiant Roblox (nombre), un lien rbxasset://, ou { Id = ..., Volume = ..., Vitesse = ... } ; 0 = aucun.
-- Un Sound placé à la main dans Studio avec le même nom est toujours prioritaire.
Config.Sons = {
	Camouflage = 0, Decamouflage = 0, Cloitre = 0, Reparation = 0, Regeneration = 0, Intercom = 0,
	Moteur_Pose = 0, Moteur_Vol = 0, Moteur_Urgence = 0,
	-- Replis intégrés à Roblox (toujours disponibles) : à remplacer par de vrais sons de TARDIS si tu en as
	Chute = { Id = "rbxasset://sounds/action_falling.mp3", Volume = 0.9 },
	Impact = { Id = "rbxasset://sounds/action_jump_land.mp3", Volume = 1, Vitesse = 0.55 },
}

-- Accès venant du jeu (V6.8) : en plus des listes de UserIds (Config.Pilotes, Config.Techniciens), un joueur peut être
-- pilote, technicien ou staff selon son niveau Adonis ou une liste blanche (WL) du jeu. Vérifié par le serveur.
--   Adonis : il faut G_API = true dans les réglages d'Adonis. Niveaux usuels : 0 joueur, 100 modérateur, 200 admin,
--            300 head admin, 900 créateur. 0 = ce rôle n'est jamais donné par Adonis.
--   WL     : Module = chemin d'un ModuleScript du jeu (ex. "ServerScriptService.WLConfig") ; Pilotes / Techniciens = nom
--            de la liste dans ce module (une liste de UserIds ou de pseudos, ou une fonction(joueur) qui renvoie vrai).
--   Staff  : peut utiliser les commandes de chat /tardis statut, journal, erreurs (lecture seule, aucun pilotage).
Config.Acces = {
	Adonis = { NiveauPilote = 0, NiveauTechnicien = 0, NiveauStaff = 100 },
	WL = { Module = nil, Pilotes = nil, Techniciens = nil },
	Staff = { UserIds = {} }, -- les pilotes de Config.Pilotes et le propriétaire du jeu sont toujours staff
	Verification = 60,        -- secondes entre deux vérifications (un rang peut changer en cours de partie)
}

-- Journal du TARDIS (V6.8) : décollages, atterrissages, paradoxes, auto-destructions, pannes, rôles, erreurs.
-- Cible : chemin d'un objet du journal du jeu (RoSysLog), BindableEvent / BindableFunction / ModuleScript avec une fonction
-- log / Log / ajouter / Ajouter, par exemple "ServerStorage.RoSysLog". Vide : journal interne seulement (/tardis journal).
Config.Journal = {
	Cible = nil,
	Taille = 200,       -- lignes gardées en mémoire pour /tardis journal
	Output = false,     -- true : chaque ligne est aussi écrite dans l'Output
}

-- Appareils sans clavier (V6.8.1) : boutons tactiles au bord gauche pour ouvrir le menu (T), la tablette (Y)
-- et la tablette technicien. N'apparaissent jamais sur ordinateur.
Config.BoutonsTactiles = true

-- Supervision (V6.8) : les erreurs des scripts du TARDIS chez les joueurs remontent au serveur (/tardis erreurs, journal)
Config.Supervision = {
	ErreursClients = true,
	CommandeChat = "/tardis", -- /tardis statut · /tardis journal · /tardis erreurs · /tardis commandes ; /tardis help = balise de détresse
}

-- Retrouve un objet par son chemin "Service.Dossier.Objet" (nil s'il n'existe pas)
function Config.trouverChemin(chemin)
	if type(chemin) ~= "string" or chemin == "" then return nil end
	local objet = nil
	for nom in string.gmatch(chemin, "[^%.]+") do
		if not objet then
			local ok, service = pcall(game.GetService, game, nom)
			objet = (ok and service) or game:FindFirstChild(nom)
		else
			objet = objet:FindFirstChild(nom)
		end
		if not objet then return nil end
	end
	return objet
end

-- Clé du TARDIS (V6.9, modification 24) : outil des techniciens (et des pilotes) qui verrouille ou déverrouille
-- les portes à distance, comme une clé de voiture. La lampe clignote deux fois.
Config.Cle = {
	Portee = 80,            -- distance maximale à la cabine (studs) ; à bord, elle marche toujours
	Pilotes = true,         -- les pilotes peuvent aussi la prendre (menu Systèmes)
}

-- Mode Siège (V6.9, ajout C6) : un seul bouton lève le bouclier complet, verrouille les portes et déclenche l'alerte.
-- Un second appui lève le siège. Il prend fin tout seul si le TARDIS décolle.
Config.Siege = { Bouclier = "Complet", Verrou = true, Alerte = true }

-- Copilote (V6.9.1, ajout C2) : un pilote nomme un joueur à bord (tablette › Outils › Copilote). Le copilote a son
-- propre poste (navigation, protocoles, démat / remat, camouflage, atterrissage du vol libre, carnet de bord) et
-- aucun autre droit. Il perd son poste dès qu'il quitte le TARDIS.
Config.Copilote = { Actif = true }

-- Carnet de bord RP (V6.9.1, ajout C7) : notes des pilotes et du copilote par lieu, filtrées par Roblox et sauvegardées.
Config.Carnet = {
	Max = 80,            -- nombre de notes gardées (les plus anciennes partent)
	LongueurMax = 200,   -- caractères par note
}

-- Intercom du site (V6.7.3) : la première matérialisation visible d'un TARDIS pendant la session est annoncée à tout
-- le serveur (« faille spatio-temporelle »), puis les pilotes reçoivent un rappel toutes les RappelMinutes.
-- Cible : chemin d'un objet de l'OS Fondation qui fait l'annonce (BindableEvent, BindableFunction ou ModuleScript
-- avec une fonction annoncer / Annoncer), par exemple "ServerScriptService.OSFondation.OSAppsServeur.Intercom".
-- Vide : le TARDIS fait l'annonce lui-même (bandeau en haut de l'écran, alarme, message dans le chat).
Config.Intercom = {
	Actif = true,
	Cible = nil,
	RappelMinutes = 10,
	Titre = "INTERCOM DU SITE",
	Message = "Alerte : faille spatio-temporelle détectée. Lieu : %s. Personnel de sécurité, restez vigilants.",
	Rappel = "Rappel : la faille spatio-temporelle de %s (%s) a été signalée à tout le site.",
}

-- Vapeur de refroidissement : plaques nommées "Grille" (ou dans un dossier "Grilles") de l'intérieur
Config.Vapeur = { Intensite = 1, IntervalleMin = 4, IntervalleMax = 14 } -- intensité 0 = aucune vapeur

-- Tablette technicien (V6.7.2) : touche Y pour un technicien qui n'est pas pilote (les pilotes l'ouvrent par l'outil
-- « Ingénierie » de leur tablette). Informations complètes et commandes RP, aucune commande de vol.
Config.Technicien = {
	Regulation = { Energie = 80, Air = 100, Vapeur = 50 }, -- valeurs de départ (%) ; Vapeur 50 = intensité normale
	UsureAir = 1,            -- points d'air perdus toutes les 30 s tant que quelqu'un est à bord (0 = l'air ne s'use jamais)
	SeuilAirVicie = 25,      -- en dessous : l'air est vicié (voile grisâtre pour les occupants)
	SurtensionAuDessus = 90, -- au-dessus : une chance sur quatre, toutes les 30 s, qu'une grille de vapeur lâche
	SousTension = 20,        -- en dessous : les lumières de la salle baissent
	DureePurge = 6,          -- secondes d'une purge de l'air
}

-- Bourdonnement du moteur : Sound "Moteur_Pose", "Moteur_Vol", "Moteur_Urgence" dans TardisAssets > Sons (optionnels)

-- Systèmes (points de vie, boucliers, pannes, régénération, saleté)
Config.Systemes = {
	PointsDeVie = 10000,            -- énorme : même en le faisant exprès, il est difficile d'arriver à 0
	ReparationParMaintien = 1500,   -- PV rendus à chaque maintien de E (5 s) sur le rotor
	DegatsChoc = 25, DegatsChute = 80, DegatsBalle = 4, DegatsExplosion = 300,
	BouclierCoups = 250,            -- balles encaissées avant que le bouclier ne tombe
	PannesIntervalleMin = 20 * 60,  -- délai entre deux pannes aléatoires (secondes)
	PannesIntervalleMax = 40 * 60,
	VoyagesAvantCoupure = 15,       -- après N voyages consécutifs, le système se coupe (10 s sur l'alimentation pour redémarrer)
	RedemarrageDuree = 10,
	SaleteParVoyage = 8,            -- % de saleté gagné à chaque atterrissage (le chiffon en enlève 15)
	DegatsStatique = 0.5,           -- dégâts d'un arc statique (toucher la cabine pendant une démat)
}

-- Régénération : les joueurs de cette équipe ne meurent pas, ils se régénèrent (invulnérables pendant la régénération)
Config.Regeneration = {
	Equipe = nil,            -- nom exact de l'équipe (Team) ; vide = celui de Config.Equipe.Nom
	Nombre = 0,              -- nombre de régénérations avant la vraie mort ; 0 = infini
	Duree = 8,               -- durée de la régénération (secondes) : montée, éruption, changement, dissipation
	CameraCinematique = true, -- celui qui se régénère voit la scène de l'extérieur (caméra qui tourne autour de lui)
	-- Son optionnel : un Sound "Regeneration" dans ReplicatedStorage > TardisAssets > Sons
	BonusPV = 100,           -- PV en plus après une régénération...
	BonusDuree = 300,        -- ...pendant ce temps (secondes)
	TenuesDuCompte = true,   -- nouvelle apparence tirée des avatars sauvegardés du joueur (sinon : AvatarsDuJeu, puis Config.Tenues)
	AvatarsDuJeu = {},       -- UserIds de comptes dont l'avatar actuel sert de nouvelle apparence aux joueurs qui n'ont pas partagé les leurs
	Style = 0,               -- animation : 0 = au hasard ; 1 Classique, 2 Volcan, 3 Douce, 4 Tourbillon, 5 Colonne, 6 Supernova, 7 Fracture
	OndeChoc = { Rayon = 5, Force = 70 }, -- styles 6 et 7 : onde de choc qui repousse les joueurs proches (rayon en studs, vitesse d'éjection)
	ChoixRefus = true,       -- au moment de mourir, le joueur peut refuser de se régénérer...
	DelaiChoix = 3,          -- ...pendant ce temps (secondes)
	DegatsTardis = 400,      -- une régénération à bord abîme le TARDIS (intégrité), avec étincelles et alarme
	RepousseDuree = 300,     -- après une régénération, un membre perdu repousse pendant ce temps (secondes)
	-- Crise post-régénération (V6.9, modification 23) : vision trouble et démarche titubante pour celui qui vient de
	-- se régénérer. 0 = aucune crise.
	CriseDuree = 60,
	-- Le lien Time Lord (les membres de la C.A.T. ressentent les régénérations des autres) s'active dans la tablette : outil Régénérations
}

-- Découverte : message affiché la première fois qu'un joueur entre dans le TARDIS (une seule fois, sauvegardé)
Config.Decouverte = {
	Titre = "DÉCOUVERTE",
	Texte = "Tu es entré dans le TARDIS pour la première fois. C'est plus grand à l'intérieur.",
}

-- Catégories de destinations (étiquettes de couleur dans la tablette, enregistrées)
Config.Categories = {
	{ nom = "Site", couleur = Color3.fromRGB(79, 209, 255) },
	{ nom = "Surface", couleur = Color3.fromRGB(74, 222, 128) },
	{ nom = "Danger", couleur = Color3.fromRGB(240, 82, 82) },
	{ nom = "Secret", couleur = Color3.fromRGB(170, 100, 255) },
	{ nom = "Événement", couleur = Color3.fromRGB(242, 179, 61) },
}

-- États
Config.Etats = {
	Pose = "Pose",
	Demat = "Demat",
	Vol = "Vol",
	Remat = "Remat",
}

-- Retrouve une commande à partir de son chemin (attend qu'elle existe)
function Config.Trouver(racine, cle)
	local objet = racine
	for _, nom in Config.Chemins[cle] do
		objet = objet:WaitForChild(nom)
	end
	return objet
end

-- Nom de mode valide ("Normal", "Urgence", "Express", "Sauvetage", "Catastrophe"). Accepte aussi un booléen :
-- true = "Urgence" (c'est ainsi que le vol libre désigne sa démat / remat d'urgence).
function Config.normaliserMode(mode)
	if mode == true then return "Urgence" end
	if type(mode) == "string" and Config.Modes[mode] then return mode end
	return "Normal"
end

-- Nom affiché d'un mode (Libelle), en majuscules si demandé
function Config.libelleMode(mode, majuscules)
	local reglages = Config.Modes[Config.normaliserMode(mode)]
	local libelle = reglages.Libelle or Config.normaliserMode(mode)
	return majuscules and string.upper(libelle) or libelle
end

-- Un mode « saccadé » (urgence ou catastrophe) : animation contrariée, sons d'urgence
function Config.modeSaccade(mode)
	return (Config.Modes[Config.normaliserMode(mode)].Saccades or 0) > 0
end

-- Couleur d'un mode pour les effets extérieurs : celle du mode, sauf si elle est réservée à l'intérieur
-- (Rapide), auquel cas une lumière neutre
function Config.couleurDehors(mode)
	local reglages = Config.Modes[Config.normaliserMode(mode)]
	if reglages.CouleurDehors == false then return Color3.fromRGB(235, 240, 255) end
	return reglages.CouleurRotor or Color3.fromRGB(235, 240, 255)
end

-- Nom de l'équipe (C.A.T.)
function Config.nomEquipe()
	return (Config.Regeneration and Config.Regeneration.Equipe) or (Config.Equipe and Config.Equipe.Nom) or "C.A.T."
end

-- Mode du voyage en cours d'un TARDIS (attribut "Mode" de son extérieur)
-- Mode de la démat / remat en vol libre (attribut "VolPhaseMode" ; avant la V6.6.4, seulement "VolPhaseUrgence")
function Config.modeVolDe(exterieur)
	local mode = exterieur:GetAttribute("VolPhaseMode")
	if mode then return Config.normaliserMode(mode) end
	return exterieur:GetAttribute("VolPhaseUrgence") == true and "Urgence" or "Normal"
end

function Config.modeDe(exterieur)
	return Config.normaliserMode(exterieur:GetAttribute("Mode"))
end

-- Durée de l'animation et décalage du son pour un état et un mode
function Config.Timing(etat, mode)
	local reglages = Config.Modes[Config.normaliserMode(mode)]
	local phase = (etat == Config.Etats.Demat and reglages.Demat) or (etat == Config.Etats.Remat and reglages.Remat)
	if not phase then return 0, 0 end
	return phase.Duree, phase.Decalage or 0
end

-- Nom du son d'un état dans un mode (le serveur se rabat sur le son Normal s'il n'existe pas)
function Config.Son(etat, mode)
	local sons = Config.Modes[Config.normaliserMode(mode)].Sons
	return sons[etat == Config.Etats.Demat and "Demat" or "Remat"]
end

-- Bruit pseudo-aléatoire mais identique chez tous les joueurs (dépend seulement du temps)
local function bruit(t, frequence)
	local n = math.floor(t * frequence)
	local x = math.sin(n * 12.9898 + 78.233) * 43758.5453
	return x - math.floor(x)
end
Config.Bruit = bruit

-- Animation saccadée (urgence, catastrophe) : progression contrariée, reculs, grésillements, tremblements
-- (reduit = option « réduire les effets » du joueur : saccades à 30 %, sans les disparitions brèves)
local function alphaUrgence(etat, p, t, duree, reduit, reglages)
	reglages = reglages or Config.Modes.Urgence
	if p <= 0 then return etat == Config.Etats.Remat and 1 or 0 end
	if p >= 1 then return etat == Config.Etats.Remat and 0 or 1 end

	-- Visibilité de base (0 = invisible, 1 = visible)
	local v = (etat == Config.Etats.Remat) and p or (1 - p)

	-- Stabilisation : pendant les dernières secondes, les perturbations s'apaisent progressivement
	-- jusqu'à disparaître (le TARDIS "s'accroche" à l'atterrissage, ou lâche prise au décollage)
	local restant = (1 - p) * duree
	local fenetre = reglages.Stabilisation or 5
	local calme = math.clamp(restant / fenetre, 0, 1)   -- 1 = loin de la fin, 0 = fin
	calme = calme * calme * (3 - 2 * calme)              -- transition douce
	local intensite = (reglages.Saccades or 0.75) * calme * (reduit and 0.3 or 1)

	-- Reculs : il gagne du terrain puis est repoussé, de façon irrégulière
	local recul = math.max(0, math.sin(t * 2.3) * math.sin(t * 0.9 + 1))
	v *= 1 - 0.6 * recul * intensite

	-- Grésillements : disparitions brèves, moins fréquentes et moins profondes que la V3.2
	-- (8 changements par seconde au lieu de 12 : moins agressif pour les yeux)
	if not reduit and bruit(t, 8) < 0.14 * intensite then
		v *= 0.35
	end

	-- Tremblement de l'image, plus doux
	v += (bruit(t + 3.7, 10) - 0.5) * 0.14 * intensite

	return 1 - math.clamp(v, 0, 1)
end

-- Un souffle (le « VWORP » de la série) : montée brusque, retombée lente. frac = position dans le souffle (0..1)
local function formeSouffle(frac)
	if frac < 0.3 then
		local x = frac / 0.3
		return x * x * (3 - 2 * x)
	end
	local x = (frac - 0.3) / 0.7
	return 1 - x * x * (3 - 2 * x)
end

-- Respiration de la (dé)matérialisation (V6.7) : tout ce qui bat au rythme du son (fondu, lampe, lumières de la
-- salle, poussière, ondes au sol) lit la même valeur, donc tout est synchronisé chez tous les joueurs.
-- Renvoie : souffle (0 = creux, 1 = sommet du souffle), p (progression de l'animation, 0..1),
-- fond (0 = le TARDIS est là, 1 = il n'est plus là : invisibilité « de fond », sans les souffles).
-- Dans le vortex : une respiration lente ; posé : rien.
function Config.Souffle(etat, ecoule, mode)
	if etat == Config.Etats.Vol then return 0.5 + 0.5 * math.sin(ecoule * 1.3), 1, 1 end
	if etat ~= Config.Etats.Demat and etat ~= Config.Etats.Remat then return 0, 0, 0 end
	mode = Config.normaliserMode(mode)
	local duree, decalage = Config.Timing(etat, mode)
	local p = math.clamp((ecoule - math.max(decalage, 0)) / duree, 0, 1)
	local avancee = (etat == Config.Etats.Remat) and (1 - p) or p
	local fond = avancee ^ 1.4
	local souffle
	if Config.modeSaccade(mode) then
		-- Urgence, catastrophe : les souffles sont irréguliers, le moteur peine
		souffle = formeSouffle((p * 5 + 0.4 * math.sin(ecoule * 1.9)) % 1)
	else
		souffle = formeSouffle((p * (Config.Modes[mode].Pulsations or 4)) % 1)
	end
	-- Avant le décalage (le son commence par un silence), rien ne bouge
	if p <= 0 or p >= 1 then souffle = 0 end
	return souffle, p, fond
end

-- Transparence de l'extérieur (0 = visible, 1 = disparu) selon l'état, le temps écoulé et le mode
-- (reduit : le joueur a choisi « réduire les effets »)
function Config.Alpha(etat, ecoule, mode, reduit)
	if etat == Config.Etats.Pose then return 0 end
	if etat == Config.Etats.Vol then return 1 end

	mode = Config.normaliserMode(mode)
	local duree, decalage = Config.Timing(etat, mode)
	decalage = math.max(decalage, 0)
	-- Avant le décalage : seul le son joue, rien ne bouge (visible au décollage, invisible à l'atterrissage).
	-- Ensuite l'animation dure sa durée complète.
	local p = math.clamp((ecoule - decalage) / duree, 0, 1)

	if Config.modeSaccade(mode) then
		return alphaUrgence(etat, p, ecoule, duree, reduit, Config.Modes[mode])
	end

	-- Animation normale (ou rapide, plus courte ; sauvetage : la même, en descendant) : à chaque souffle, la cabine s'efface d'un coup puis revient
	-- lentement, de moins en moins (décollage) ou de plus en plus (atterrissage). Elle ne disparaît tout à fait
	-- qu'aux derniers souffles.
	local souffle, _, fond = Config.Souffle(etat, ecoule, mode)
	local profondeur = 0.6 + 0.4 * fond
	local alpha = fond + (1 - fond) * souffle * profondeur
	-- Scintillement : l'image hésite au sommet de chaque souffle (pas en « effets réduits »)
	if not reduit then
		alpha += (bruit(ecoule, 28) - 0.5) * 0.12 * souffle * (1 - fond)
	end
	return math.clamp(alpha, 0, 1)
end

return Config