"""Simulations de la V6.9.12 (pannes : le socle commun) : le vrai code, extrait des scripts et exécuté.
  1. TardisConfig : version, sons Panne_* (0 = facultatifs), fréquence des pannes (préréglages Aucune, Rare, Normale,
     Frequente, valeurs sur mesure), grilles (Config.grillesDe, Config.grilleEnPanne : numéro TardisGrille, chemin
     VapeurGrille, puis n-ième), zones (Config.zoneDe : attribut Zone, dossier Zones, sinon autour de la console).
  2. Serveur, socle commun (extrait) : fiches des 6 pannes, annonce unique PANNE / EFFET SUR LE VOL / QUI RÉPARE,
     alerte courte sur la console, historique (20 au plus, la plus récente d'abord, JSON), « réparé par » en simple
     mention (joueur ou nom), réparation envoyée au bus TardisEvenements.
  3. Serveur, pannes aléatoires (extrait) : tirage pondéré, repli sur les autres pannes, boucle arrêtée avec Aucune.
  4. Serveur : l'air vicié se ferme avec le technicien de la dernière action (extrait) ; chaque panne branchée sur le socle.
  5. Serveur, rotor en panne (extrait de TardisExtras) : étincelles brèves, attribut PanneEtincelles, pas d'accélération.
  6. La vraie tablette technicien : zone dans le titre des pannes, bouton HISTORIQUE (début, fin, réparé par).
  7. Ambiance (le module entier) : sons des pannes (grille en surcharge, console en feu, grincement, étincelles),
     absents = silence, sans nouvelle boucle image par image.
  8. Le code : repères (V6.9.12), aucun compteur par technicien, diagnostic des sons et du dossier Zones."""
import os, sys, json, re
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from monde import *
import roblox
from roblox import Couleur, Vec3, CF, activer_maths
OK, KO = [], []
def verifier(nom, condition, detail=""):
    (OK if condition else KO).append(nom + ("" if condition else "  →  " + str(detail)))
def tache(f): lancer(Fonction("t", py=f))
def lire(chemin): return open(os.path.join(DEPOT, chemin), encoding="utf-8").read()
def entre(texte, debut, fin): return texte[texte.index(debut):texte.index(fin, texte.index(debut))]
def vider_cache(): roblox.charger_module.__defaults__[0].clear()
def version(v):
    try: return tuple(int(p) for p in str(v).split("."))
    except ValueError: return ()
def descendants(o):
    res = []
    def visite(x):
        for e in x.enfants: res.append(e); visite(e)
    visite(o); return res
def trouve(racine, nom):
    for e in descendants(racine):
        if e.Name == nom: return e
def texte_de(o): return str(o.props.get("Text", "")) if o is not None else None
def appel(f, *a):
    res = {}
    tache(lambda: res.update(v=list(appeler(f, list(a)) or [])))
    return (res.get("v") or []) + [None, None]
def piece(nom, parent, pos, taille=(2, 2, 2), classe="Part"):
    p = Instance(classe, nom, parent)
    p.props.update({"Position": Vec3(*pos), "CFrame": CF(pos), "Pivot": CF(pos), "Size": Vec3(*taille)})
    return p
R = {}

systemes = lire("ServerScriptService/TardisSystemes.server.lua")
extras = lire("ServerScriptService/TardisExtras.server.lua")
tablette = lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/TabletteTechnicien.lua")
ambiance = lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Ambiance.lua")
config_src = lire("ReplicatedStorage/TardisConfig.lua")
diagnostic = lire("ServerScriptService/TardisDiagnostic.lua")

# ================================================================== 1. TardisConfig
vider_cache(); roblox.ERREURS.clear()
I, G, game, pilote = monde(serveur=True)
activer_maths(G)  # vrais calculs de CFrame : les zones (Part qui contient, la plus proche, côté de la console)
rs = game.m_FindFirstChild("ReplicatedStorage")
tache(lambda: R.update(Config=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisConfig")]))))
Config = R["Config"]
verifier("1. Vrai TardisConfig chargé, version 6.9.12 ou plus", version(Config.get("Version")) >= (6, 9, 12) and not roblox.ERREURS, (Config.get("Version"), roblox.ERREURS[:3]))
SONS = Config.get("Sons")
verifier("1. Config.Sons : Panne_Vapeur, Panne_Feu, Panne_Grincement, Panne_Etincelles à 0 (facultatifs, rien n'est créé)",
         all(SONS.get(n) == 0 for n in ("Panne_Vapeur", "Panne_Feu", "Panne_Grincement", "Panne_Etincelles")))
verifier("1. Config.Systemes.FrequencePannes = « Normale » par défaut", Config.get("Systemes").get("FrequencePannes") == "Normale")
def intervalle(systemes):
    v = appel(Config.get("intervallePannes"), systemes)
    return (v[0], v[1])
verifier("1. Aucune : pas d'intervalle (la boucle s'arrête)", intervalle(Table({"FrequencePannes": "Aucune"})) == (None, None))
verifier("1. Rare : 40 à 80 min", intervalle(Table({"FrequencePannes": "Rare"})) == (2400, 4800), intervalle(Table({"FrequencePannes": "Rare"})))
verifier("1. Normale : 20 à 40 min (comme avant)", intervalle(Table({"FrequencePannes": "Normale"})) == (1200, 2400))
verifier("1. Frequente : 8 à 15 min", intervalle(Table({"FrequencePannes": "Frequente"})) == (480, 900))
verifier("1. Sans argument : le réglage de Config.Systemes (Normale)", intervalle(None) == (1200, 2400))
verifier("1. Réglage inconnu : les valeurs sur mesure PannesIntervalleMin / Max",
         intervalle(Table({"FrequencePannes": "Bizarre", "PannesIntervalleMin": 300, "PannesIntervalleMax": 600})) == (300, 600))
verifier("1. Sur mesure à l'envers (maxi < mini) : maxi ramené à mini", intervalle(Table({"PannesIntervalleMin": 600, "PannesIntervalleMax": 60})) == (600, 600))
verifier("1. Sur mesure illisible : 20 à 40 min", intervalle(Table({"PannesIntervalleMin": "vite", "PannesIntervalleMax": None})) == (1200, 2400))
ZP = Config.get("ZonesPannes")
verifier("1. Config.ZonesPannes : dossier « Zones », attribut « Zone », 8 studs autour de la console",
         ZP and (ZP.get("Dossier"), ZP.get("Attribut"), ZP.get("PresConsole")) == ("Zones", "Zone", 8))

# Grilles
salle = Instance("Model", "Salle")
console = piece("Console", salle, (0, 1000, 0), (6, 4, 6))
dossierGrilles = Instance("Folder", "Grilles", salle)
g1 = piece("Grille", dossierGrilles, (10, 1000, 0)); g2 = piece("GrilleNord", dossierGrilles, (0, 1000, -12)); g3 = piece("Grille", dossierGrilles, (-10, 1000, 0))
autre = piece("Grille", Instance("Model", "Machines", salle), (0, 1000, 15))
Instance("Folder", "Grille", salle)  # pas une pièce : ignoré
liste = appel(Config.get("grillesDe"), salle)[0]
liste = [liste.get(i) for i in range(1, 6)] if liste is not None else []
verifier("1. Config.grillesDe : les pièces « Grille » et celles du dossier « Grilles » (pas les dossiers)",
         set(id(x) for x in liste if x is not None) == {id(g1), id(g2), id(g3), id(autre)} and liste[4] is None, [getattr(x, "Name", x) for x in liste])
ext = Instance("Model", "Cabine")
def en_panne(grilles=None):
    v = appel(Config.get("grilleEnPanne"), ext, salle, grilles)
    return v[0], v[1]
verifier("1. Config.grilleEnPanne : pas de surcharge → rien", en_panne() == (None, None))
ext.attrs["VapeurSurcharge"] = 2
verifier("1. Sans numéro ni chemin : la n-ième de la liste (comme avant)", en_panne()[0] is liste[1] and en_panne()[1] == 2, en_panne())
for i, g in enumerate(liste[:4]): g.attrs["TardisGrille"] = 4 - i   # numéros du serveur dans l'ordre inverse
verifier("1. Numéro TardisGrille posé par le serveur : c'est lui qui compte (pas l'ordre de la liste)", en_panne()[0] is liste[2], getattr(en_panne()[0], "Name", None))
for g in liste[:4]: g.attrs.pop("TardisGrille")
ext.attrs["VapeurGrille"] = "Grilles/GrilleNord"
verifier("1. Chemin VapeurGrille publié par le serveur : la pièce de ce chemin", en_panne() == (g2, 2), en_panne())
ext.attrs["VapeurGrille"] = "Grilles/Introuvable"
verifier("1. Chemin introuvable : repli sur la n-ième", en_panne()[0] is liste[1])
ext.attrs["VapeurSurcharge"] = 9; ext.attrs.pop("VapeurGrille")
verifier("1. Numéro hors liste : rien, sans erreur", en_panne() == (None, None) and not roblox.ERREURS, roblox.ERREURS[:3])
ext.attrs.pop("VapeurSurcharge")

# Zones
def zone(objet, interieur=salle): return appel(Config.get("zoneDe"), interieur, objet)[0]
p_attr = piece("Levier", salle, (30, 1000, 30)); p_attr.attrs["Zone"] = "Salle des machines"
verifier("1. Config.zoneDe : attribut « Zone » de la pièce", zone(p_attr) == "Salle des machines", zone(p_attr))
modele = Instance("Model", "Vanne", salle); modele.attrs["Zone"] = "Chaufferie"; tuyau = piece("Tuyau", modele, (30, 1000, -30))
verifier("1. Attribut « Zone » du parent (pièce d'un Model)", zone(tuyau) == "Chaufferie" and zone(modele) == "Chaufferie", (zone(tuyau), zone(modele)))
verifier("1. Sans dossier Zones : près de la console (moins de 8 studs) → « Console »", zone(piece("Bouton", salle, (3, 1001, 4))) == "Console")
verifier("1. Sans dossier Zones : direction par rapport à la console (Avant, Arrière, Gauche, Droite)",
         [zone(g2), zone(autre), zone(g3), zone(g1)] == ["Avant", "Arrière", "Gauche", "Droite"], [zone(g2), zone(autre), zone(g3), zone(g1)])
dossierZones = Instance("Folder", "Zones", salle)
piece("Couloir", dossierZones, (10, 1000, 0), (6, 6, 6)); piece("Atelier", dossierZones, (-25, 1000, 0), (6, 6, 6))
verifier("1. Dossier Zones : la Part qui contient la pièce donne son nom", zone(g1) == "Couloir", zone(g1))
verifier("1. Dossier Zones : hors de toute zone, la plus proche", zone(g3) == "Atelier" and zone(g2) == "Couloir", (zone(g3), zone(g2)))
verifier("1. L'attribut l'emporte sur le dossier Zones", zone(p_attr) == "Salle des machines")
dossierZones.set_parent(None)
sansConsole = Instance("Model", "Vide"); orpheline = piece("Grille", sansConsole, (1, 2, 3))
verifier("1. Ni Zones ni console : rien (nil)", zone(orpheline, sansConsole) is None)
verifier("1. Objet sans pièce, objet absent, pas un objet : rien, sans erreur",
         zone(Instance("Folder", "Dossier", salle)) is None and zone(None) is None and zone("Grille") is None and not roblox.ERREURS, roblox.ERREURS[:3])
verifier("1. Config : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])

# ================================================================== 2. Serveur : socle commun des pannes (extrait)
vider_cache(); roblox.ERREURS.clear()
I, G, game, pilote = monde(serveur=True)
rs = game.m_FindFirstChild("ReplicatedStorage"); ss = game.m_FindFirstChild("ServerStorage")
tache(lambda: R.update(Config=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisConfig")]))))
Config = R["Config"]
socle = entre(systemes, "local FICHES_PANNES = {", "\n--------------------------------------------------------------------\n-- Points de vie et avarie")
INTERNE, MESSAGES, BUS = [], [], []
extS = Instance("Model", "Cabine"); salleS = Instance("Model", "Salle")
prelude = "local exterieur, interieur, def, ServerStorage, interne, direAuxPilotes = ...\n"
fin = "\nreturn { fiches = FICHES_PANNES, signaler = signalerPanne, ouvrir = ouvrirPanne, fermer = fermerPanne, chemin = cheminDepuisInterieur }"
tache(lambda: R.update(socle=premier(I.executer(prelude + socle + fin, "socle-pannes",
      (extS, salleS, Config.get("Tardis").get(1), ss, Fonction("interne", py=lambda *a: INTERNE.append(a) or []),
       Fonction("direAuxPilotes", py=lambda m, ok=None: MESSAGES.append((m, ok)) or []))))))
SO = R.get("socle")
verifier("2. Vrai socle des pannes extrait et chargé", SO is not None and not roblox.ERREURS, roblox.ERREURS[:3])
FICHES = SO.get("fiches")
cles = ("Avarie", "Vapeur", "Incendie", "Coupure", "Bouclier", "AirVicie")
verifier("2. FICHES_PANNES : les 6 pannes, chacune avec titre, texte court, effet sur le vol et qui répare",
         all(FICHES.get(c) is not None and all(isinstance(FICHES.get(c).get(k), str) and FICHES.get(c).get(k) for k in ("titre", "court", "effet", "repare")) for c in cles))
verifier("2. Effet sur le vol : avarie et coupure empêchent le décollage ; vapeur, incendie, air vicié n'y changent rien ; bouclier coupé",
         all("décollage impossible" in FICHES.get(c).get("effet") for c in ("Avarie", "Coupure"))
         and all(FICHES.get(c).get("effet") == "aucun effet sur le vol" for c in ("Vapeur", "Incendie", "AirVicie"))
         and "bouclier coupé" in FICHES.get("Bouclier").get("effet"))
def historique():
    try: return json.loads(extS.attrs.get("HistoriquePannes") or "[]")
    except ValueError: return "illisible"
appel(SO.get("signaler"), "Vapeur", "grille n°2, zone Couloir")
verifier("2. Annonce : alerte courte sur l'écran de la console (interne « alerter »)", INTERNE == [("alerter", "SURCHARGE DE VAPEUR")], INTERNE)
verifier("2. Annonce aux pilotes et techniciens : PANNE / EFFET SUR LE VOL / QUI RÉPARE, en rouge",
         MESSAGES == [("PANNE : Surcharge de vapeur (grille n°2, zone Couloir) · EFFET SUR LE VOL : aucun effet sur le vol · QUI RÉPARE : technicien : visseuse sur la grille (3 fois).", False)], MESSAGES)
h = historique()
verifier("2. Historique publié en JSON (attribut HistoriquePannes) : type, titre, détail, début, pas encore de fin",
         isinstance(h, list) and len(h) == 1 and h[0].get("type") == "Vapeur" and h[0].get("titre") == "Surcharge de vapeur" and h[0].get("detail") == "grille n°2, zone Couloir"
         and isinstance(h[0].get("debut"), (int, float)) and "fin" not in h[0], h)
appel(SO.get("signaler"), "Vapeur", "grille n°3")
verifier("2. Même panne déjà ouverte : pas de deuxième ligne", len(historique()) == 1)
H.avancer(125)
ok = appel(SO.get("fermer"), "Vapeur", pilote)[0]
h = historique()
verifier("2. Réparée par un joueur : heure de fin et « par » = son nom affiché", ok is True and h[0].get("fin") == h[0].get("debut") + 125 and h[0].get("par") == "Pilote", h)
verifier("2. Réparation envoyée au bus TardisEvenements… s'il existe (sinon rien, sans erreur)", not BUS and not roblox.ERREURS)
bus = Instance("BindableEvent", "TardisEvenements", ss)
bus.extra["Fire"] = Fonction("Fire", py=lambda _s, *a: BUS.append(a) or [])
appel(SO.get("signaler"), "Incendie")
appel(SO.get("fermer"), "Incendie", "Alice")
d = BUS[0][1] if BUS and len(BUS[0]) > 1 else None
verifier("2. Bus : « Journal », catégorie Panne, « TARDIS_1 : Incendie de console, panne réglée par Alice. »",
         len(BUS) == 1 and BUS[0][0] == "Journal" and d is not None and d.get("categorie") == "Panne" and d.get("tardis") == "TARDIS_1"
         and d.get("message") == "TARDIS_1 : Incendie de console, panne réglée par Alice.", [(b[0], b[1].get("message") if len(b) > 1 else None) for b in BUS])
appel(SO.get("signaler"), "Bouclier"); appel(SO.get("fermer"), "Bouclier", None)
h = historique()
verifier("2. Réparateur inconnu (bouclier relancé par le serveur) : fin sans « par »", h[0].get("type") == "Bouclier" and h[0].get("fin") and "par" not in h[0]
         and BUS[-1][1].get("message") == "TARDIS_1 : Bouclier tombé, panne réglée.", (h[0], BUS[-1][1].get("message")))
n = len(BUS)
verifier("2. Fermer une panne qui n'est pas ouverte : rien (false), pas de message au bus", appel(SO.get("fermer"), "Coupure", pilote)[0] is False and len(BUS) == n)
verifier("2. Panne inconnue : rien d'annoncé, rien de noté", appel(SO.get("ouvrir"), "Martiens")[0] is False and appel(SO.get("fermer"), "Martiens")[0] is False
         and (appel(SO.get("signaler"), "Martiens") or True) and len(historique()) == 3 and len(MESSAGES) == 4, (len(historique()), len(MESSAGES)))
verifier("2. La plus récente d'abord", [e["type"] for e in historique()] == ["Bouclier", "Incendie", "Vapeur"], [e["type"] for e in historique()])
for i in range(1, 26):
    appel(SO.get("signaler"), "Coupure", "n°%d" % i); appel(SO.get("fermer"), "Coupure", "Bob" if i % 2 else pilote)
h = historique()
verifier("2. 20 pannes au plus : les plus anciennes partent", len(h) == 20 and h[0].get("detail") == "n°25" and h[-1].get("detail") == "n°6", (len(h), h[0].get("detail"), h[-1].get("detail")))
verifier("2. « Réparé par » reste une mention : aucun compteur, aucun autre champ", all(set(e) <= {"type", "titre", "detail", "debut", "fin", "par"} for e in h)
         and {e.get("par") for e in h} == {"Bob", "Pilote"}, sorted({k for e in h for k in e}))
appel(SO.get("signaler"), "AirVicie", "air à 20 %")
verifier("2. Une panne ouverte s'ajoute devant, l'historique reste à 20", len(historique()) == 20 and historique()[0].get("type") == "AirVicie" and "fin" not in historique()[0])
gr = Instance("Folder", "Grilles", salleS); grille = Instance("Part", "Grille", gr)
verifier("2. Chemin d'une pièce depuis l'intérieur : « Grilles/Grille » ; hors de l'intérieur : rien",
         appel(SO.get("chemin"), grille)[0] == "Grilles/Grille" and appel(SO.get("chemin"), Instance("Part", "Ailleurs"))[0] is None)
verifier("2. Socle : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])

# ================================================================== 3. Pannes aléatoires : tirage pondéré, fréquence (extraits)
blocTirage = entre(systemes, "local PANNES_ALEATOIRES = {", "-- (V6.9.12) Fréquence réglable")
POSSIBLE = {"Vapeur": True, "Incendie": True}; ESSAIS = []
def declencheur(nom):
    return Fonction(nom, py=lambda: ESSAIS.append(nom) or [POSSIBLE[nom]])
tache(lambda: R.update(ti=premier(I.executer("local panneVapeur, panneIncendie = ...\n" + blocTirage + "\nreturn { tirer = tirerPanneAleatoire, liste = PANNES_ALEATOIRES }",
                                            "tirage-pannes", (declencheur("Vapeur"), declencheur("Incendie"))))))
TI = R.get("ti")
verifier("3. Vrai tirage pondéré extrait et chargé (vapeur et incendie, poids 1)", TI is not None and [(TI.get("liste").get(i).get("nom"), TI.get("liste").get(i).get("poids")) for i in (1, 2)]
         == [("Vapeur", 1), ("Incendie", 1)], roblox.ERREURS[:3])
tirages = []
for _ in range(200):
    ESSAIS.clear(); tirages.append((appel(TI.get("tirer"))[0], list(ESSAIS)))
verifier("3. Les deux possibles : une seule panne déclenchée par tirage, les deux sortent", all(len(e) == 1 and t == e[0] for t, e in tirages)
         and {t for t, _ in tirages} == {"Vapeur", "Incendie"}, tirages[:5])
POSSIBLE["Vapeur"] = False; tirages = []
for _ in range(100):
    ESSAIS.clear(); tirages.append((appel(TI.get("tirer"))[0], list(ESSAIS)))
verifier("3. Vapeur impossible (pas de grille, déjà en cours) : on tente l'incendie", all(t == "Incendie" for t, _ in tirages)
         and any(e == ["Vapeur", "Incendie"] for _, e in tirages), tirages[:5])
POSSIBLE["Incendie"] = False; ESSAIS.clear()
verifier("3. Aucune possible : rien, chaque panne tentée une fois", appel(TI.get("tirer"))[0] is None and sorted(ESSAIS) == ["Incendie", "Vapeur"], ESSAIS)
TI.get("liste").get(1).set("poids", 0); POSSIBLE["Vapeur"] = True; ESSAIS.clear()
verifier("3. Poids 0 : jamais tirée", appel(TI.get("tirer"))[0] is None and ESSAIS == ["Incendie"], ESSAIS)
TI.get("liste").get(1).set("poids", 1)

blocBoucle = entre(systemes, "-- (V6.9.12) Fréquence réglable", "\n--------------------------------------------------------------------\n-- Régénération")
E = Config.get("Etats")
TIRES, ETATS = [], []
S = Table({"FrequencePannes": "Aucune"})
extA = Instance("Model", "Cabine")
def lancer_boucle(S):
    tache(lambda: I.executer("local Config, S, E, exterieur, interne, tirerPanneAleatoire = ...\n" + blocBoucle, "boucle-pannes",
          (Config, S, E, extA, Fonction("interne", py=lambda a: ETATS.append(a) or [E.get("Pose"), False]), Fonction("tirer", py=lambda: TIRES.append(H.t) or ["Vapeur"]))))
lancer_boucle(S); H.avancer(5 * 3600)
verifier("3. Fréquence « Aucune » : aucune panne aléatoire (la boucle s'arrête)", not TIRES and not ETATS, (len(TIRES), len(ETATS)))
S2 = Table({"FrequencePannes": "Frequente"}); TIRES.clear(); t0 = H.t
lancer_boucle(S2); H.avancer(9000)
verifier("3. « Frequente » : une panne toutes les 8 à 15 min (10 à 18 en 2 h 30)", 10 <= len(TIRES) <= 19 and all(480 <= b - a <= 900 for a, b in zip([t0] + TIRES, TIRES)), len(TIRES))
extA.attrs["Alimentation"] = False; n = len(TIRES); H.avancer(1800)
verifier("3. Hors tension : pas de panne aléatoire", len(TIRES) == n)
extA.attrs.pop("Alimentation"); S2.set("FrequencePannes", "Aucune"); H.avancer(900); n = len(TIRES); H.avancer(3 * 3600)
verifier("3. Réglage passé à « Aucune » en cours de partie : la boucle s'arrête au tour suivant", len(TIRES) == n)
verifier("3. Tirage : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])

# ================================================================== 4. Air vicié fermé, pannes branchées sur le socle
blocAir = entre(systemes, "-- (V6.9.12) Air revenu au-dessus du seuil", "\nlocal derniereMaintenance = {}")
FERMES = []; extAir = Instance("Model", "Cabine"); extAir.attrs["RegulAir"] = 20
tache(lambda: I.executer("local exterieur, TECH, fermerPanne = ...\n" + blocAir, "air-vicie",
      (extAir, Config.get("Technicien"), Fonction("fermerPanne", py=lambda c, p=None: FERMES.append((c, p)) or [True]))))
extAir.m_SetAttribute("RegulAir", 22)
verifier("4. Air encore sous le seuil : la panne reste ouverte", not FERMES, FERMES)
extAir.m_SetAttribute("TechDernier", "Alice\tPurge de l'air\t%.2f" % (1000.0 + H.t)); extAir.m_SetAttribute("RegulAir", 100)
verifier("4. Purge terminée : air vicié fermé, réparé par le technicien de la purge", FERMES == [("AirVicie", "Alice")], FERMES)
extAir.m_SetAttribute("RegulAir", 10); H.avancer(30); FERMES.clear()
extAir.m_SetAttribute("RegulAir", 60)
verifier("4. Dernière action trop ancienne (plus de 10 s) : fermée sans « par »", FERMES == [("AirVicie", None)], FERMES)
verifier("4. Air : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])
reguler = entre(systemes, 'if commande == "Reguler" then', 'elseif commande == "Energie" then')
verifier("4. Régulation et purge : l'auteur est noté AVANT que l'air remonte",
         reguler.index('SetAttribute("TechDernier"') < reguler.index('SetAttribute("Regul" .. systeme, valeur)')
         and systemes.index('"Purge de l\'air", workspace:GetServerTimeNow()))\n\t\t\texterieur:SetAttribute("RegulAir", 100)') > 0)
for cle in cles:
    verifier(f"4. Panne {cle} : annoncée par signalerPanne", f'signalerPanne("{cle}"' in systemes)
verifier("4. Réparations notées : rotor (avarie), bouclier, vanne, visseuse, levier et redémarrage à distance, air",
         systemes.count('fermerPanne("Avarie", dernierReparateurRotor)') == 1 and 'fermerPanne("Bouclier")' in systemes
         and 'fermerPanne("Incendie", joueur)' in systemes and 'fermerPanne("Vapeur", joueur)' in systemes
         and systemes.count('fermerPanne("Coupure", joueur)') == 2 and 'fermerPanne("AirVicie", par)' in systemes)
verifier("4. Plus d'anciens messages de panne en double (une seule annonce, via le socle)",
         "SURCHARGE DE VAPEUR" not in systemes.replace('court = "SURCHARGE DE VAPEUR"', "") and systemes.count('interne("alerter", fiche.court)') == 1)
verifier("4. Grilles numérotées par le serveur (TardisGrille) et chemin publié (VapeurGrille), retiré à la réparation",
         'SetAttribute("TardisGrille"' in systemes and 'SetAttribute("VapeurGrille", cheminDepuisInterieur(grille))' in systemes
         and 'SetAttribute("VapeurGrille", nil)' in systemes and "Config.grillesDe(interieur)" in systemes)
diag = entre(systemes, 'elseif commande == "Diagnostic" then', "Players.PlayerRemoving:Connect(function(joueur) dernierTech[joueur] = nil end)")
verifier("4. Diagnostic : avarie, redémarrage, vapeur et incendie situés dans leur zone (Config.zoneDe)",
         "Config.zoneDe(interieur, objet)" in diag and diag.count("situer(") == 5 and 'string.format("fuite de vapeur : grille n°%d", numero)' in diag)
verifier("4. Pannes aléatoires : la fréquence vient de Config.intervallePannes", "Config.intervallePannes(S)" in systemes and "if not mini then return end" in systemes)

# ================================================================== 5. Rotor en panne (extrait de TardisExtras)
blocRotor = entre(extras, "-- Rotor interactif : un clic", "-- Console de secours")
salleR = Instance("Model", "Salle"); rotor = Instance("Part", "Rotor", salleR); extR = Instance("Model", "Cabine")
JOUES = []
tache(lambda: I.executer("local interieur, exterieur, Config, interne = ...\n" + blocRotor, "rotor",
      (salleR, extR, Config, Fonction("interne", py=lambda *a: JOUES.append(a) or []))))
clic = rotor.m_FindFirstChildWhichIsA("ClickDetector") if hasattr(rotor, "m_FindFirstChildWhichIsA") else next((e for e in rotor.enfants if e.ClassName == "ClickDetector"), None)
def cliquer():
    H.avancer(1); tache(lambda: clic.__lua_index__("MouseClick").declencher(pilote))
def etincelles():
    return [e for a in rotor.enfants if a.ClassName == "Attachment" for e in a.enfants if e.ClassName == "ParticleEmitter"]
verifier("5. Rotor cliquable (ClickDetector)", clic is not None and not roblox.ERREURS, roblox.ERREURS[:3])
cliquer()
verifier("5. Rotor normal : 40 étincelles, accélération (RotorBoost), son Reparation (comme avant)",
         [e.emis for e in etincelles()] == [40] and extR.attrs.get("RotorBoost") and extR.attrs.get("PanneEtincelles") is None and JOUES == [("jouer", "Reparation", False)], ([e.emis for e in etincelles()], JOUES))
H.avancer(3); extR.attrs.pop("RotorBoost"); JOUES.clear()
extR.attrs.update({"Avarie": True, "Alimentation": False})
cliquer()
verifier("5. Avarie (tension coupée) : quelques étincelles brèves (15), PanneEtincelles pour le son, sans accélérer ni jouer Reparation",
         [e.emis for e in etincelles()] == [15] and extR.attrs.get("PanneEtincelles") == 1000.0 + H.t and extR.attrs.get("RotorBoost") is None and not JOUES, ([e.emis for e in etincelles()], extR.attrs, JOUES))
H.avancer(3); extR.attrs.pop("Avarie"); extR.attrs["RedemarrageRequis"] = True; avant = extR.attrs["PanneEtincelles"]
cliquer()
verifier("5. Redémarrage requis : aussi des étincelles de panne", extR.attrs.get("PanneEtincelles") != avant and extR.attrs.get("RotorBoost") is None)
H.avancer(3); extR.attrs.pop("RedemarrageRequis"); avant = extR.attrs["PanneEtincelles"]
cliquer()
verifier("5. Hors tension sans panne : rien (comme avant)", not etincelles() and extR.attrs.get("PanneEtincelles") == avant and extR.attrs.get("RotorBoost") is None)
verifier("5. Rotor : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])

# ================================================================== 6. La vraie tablette technicien : zones et historique
vider_cache(); roblox.ERREURS.clear()
I, G, game, joueur = monde(serveur=False)
activer_maths(G)
rs = game.m_FindFirstChild("ReplicatedStorage"); ws = game.m_FindFirstChild("Workspace")
remote = Instance("RemoteEvent", "TardisCommande_TARDIS_1", rs)
tache(lambda: R.update(Config=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisConfig")])), UI=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisUI")]))))
Config, UI = R["Config"], R["UI"]
camera = Instance("Camera", "Camera", ws); camera.props.update({"CFrame": CF((0, 20, 40)), "ViewportSize": Valeur("Vector2", [1920, 1080])}); ws.props["CurrentCamera"] = camera
Instance("PlayerGui", "PlayerGui", joueur)
joueur.attrs["TardisTechnicien_TARDIS_1"] = True
uis = game.m_FindFirstChild("UserInputService"); uis.props.update({"TouchEnabled": False, "KeyboardEnabled": True, "MouseEnabled": True})
t1 = Instance("Folder", "TARDIS_1", Instance("Folder", "TARDIS", ws))
ext = Instance("Model", "Cabine", Instance("Folder", "EXTERIEURE", t1)); ext.props.update({"Pivot": CF((0, 0, 0)), "PrimaryPart": Instance("Part", "Racine", ext)})
ext.attrs.update({"Etat": "Pose", "Position": "Hall", "Alimentation": True, "PointsDeVie": 84, "BouclierEnergie": 72, "Alerte": False, "Mode": "Normal",
                  "RegulEnergie": 80, "RegulAir": 84, "RegulVapeur": 50, "PV": 8400, "Salete": 0})
salle = Instance("Model", "Salle", Instance("Folder", "INTERIEURE", t1))
salle.props.update({"BoiteCFrame": CF((0, 1000, 0)), "BoiteTaille": Vec3(40, 20, 40)})
for nom in ("Rotor", "Portail"): piece(nom, salle, (0, 1000, 0))
piece("Console", salle, (0, 1000, 5)); piece("Vanne", salle, (0, 1000, 5))
gr = Instance("Folder", "Grilles", salle)
for i in range(3):
    g_ = piece("Grille", gr, (i, 1000, 0), (2, 0.2, 2)); g_.attrs["TardisGrille"] = 3 - i
zones = Instance("Folder", "Zones", salle)
piece("Machines", zones, (1, 1000, 0), (10, 4, 4)); piece("Pont", zones, (0, 1000, 6), (10, 4, 4))
C = UI.get("C")
contexte = Table({"C": C, "Config": Config, "E": Config.get("Etats"), "Lighting": game.m_FindFirstChild("Lighting"), "Players": game.m_FindFirstChild("Players"),
                  "RunService": game.m_FindFirstChild("RunService"), "UI": UI, "UserInputService": uis, "animer": UI.get("animer"), "camera": camera,
                  "creer": UI.get("creer"), "dansInterieur": Fonction("dansInterieur", py=lambda p: False), "def": Config.get("Tardis").get(1), "exterieur": ext,
                  "interieur": salle, "jeSuisDedans": Fonction("dedans", py=lambda: True), "joueur": joueur,
                  "partTemporaire": Fonction("pt", py=lambda *a: Instance("Part", "Temp")), "remote": remote, "texte": UI.get("texte")})
tache(lambda: R.update(m=premier(appeler(premier(I.executer(tablette, "TabletteTechnicien")), [contexte]))))
tech = joueur.m_FindFirstChild("PlayerGui").m_FindFirstChild("TardisTabletteTechnicien_TARDIS_1")
verifier("6. Tablette technicien construite, sans erreur", tech is not None and not roblox.ERREURS, roblox.ERREURS[:3])
RS = game.m_FindFirstChild("RunService")
def images(duree, pas=0.05):
    t = 0.0
    while t < duree - 1e-9:
        RS.__lua_index__("RenderStepped").declencher(pas); RS.__lua_index__("Heartbeat").declencher(pas)
        H.avancer(pas); t += pas
def appuyer(b): b.extra.setdefault("Activated", Signal("Activated")).declencher(); H.avancer(0.01)
joueur.m_SetAttribute("TardisTabletteTech", "TARDIS_1"); H.avancer(0.3)
ext.m_SetAttribute("VapeurSurcharge", 1); images(0.6)
guide = trouve(tech, "Intervention")
verifier("6. Carte de la fuite : la grille désignée par le serveur (TardisGrille), sa zone dans le titre",
         texte_de(trouve(guide, "Titre")) == "▲  FUITE DE VAPEUR : GRILLE N°1  ·  ZONE MACHINES", texte_de(trouve(guide, "Titre")))
lp = [e for e in descendants(tech) if e.Name == "Cellule_zone"]
verifier("6. Le tableau PANNE | ZONE | ÉTAT ne change pas (colonne ZONE = la pièce)", [texte_de(e) for e in lp] == ["GRILLE N°1"], [texte_de(e) for e in lp])
ext.m_SetAttribute("VapeurSurcharge", None); ext.m_SetAttribute("Incendie", True); images(0.6)
titres = [texte_de(e) for e in descendants(guide) if e.Name == "Titre"]
verifier("6. Incendie : « ZONE PONT » (la Part du dossier Zones qui contient la console)", titres == ["▲  INCENDIE À LA CONSOLE  ·  ZONE PONT"] or (titres and titres[0].endswith("·  ZONE PONT")), titres)
ext.m_SetAttribute("Incendie", None); images(0.6)
bh = trouve(tech, "BoutonHistorique"); hist = trouve(tech, "HistoriquePannes")
verifier("6. Bouton HISTORIQUE et panneau (caché) construits en code", bh is not None and texte_de(bh) == "HISTORIQUE" and hist is not None and hist.props.get("Visible") is False)
contenu = hist.parent and [e for e in hist.parent.enfants if e is not hist and e.ClassName in ("Frame", "ScrollingFrame") and e.props.get("Visible") is not False]
appuyer(bh)
verifier("6. Clic : l'historique remplace le tableau ; « ◂ PANNES » pour revenir", hist.props.get("Visible") is True and texte_de(bh) == "◂ PANNES")
verifier("6. Pas encore d'historique : « Aucune panne depuis le démarrage du serveur. »", texte_de(trouve(hist, "Vide")) == "Aucune panne depuis le démarrage du serveur.")
debut = 1_800_000_000
ext.m_SetAttribute("HistoriquePannes", json.dumps([
    {"type": "AirVicie", "titre": "Air vicié", "detail": "air à 20 %", "debut": debut + 3600},
    {"type": "Incendie", "titre": "Incendie de console", "debut": debut, "fin": debut + 480, "par": "Alice"},
    {"type": "Bouclier", "titre": "Bouclier tombé", "debut": debut - 600, "fin": debut - 300}], ensure_ascii=False)); H.avancer(0.05)
e1, e2, e3 = trouve(hist, "Entree1"), trouve(hist, "Entree2"), trouve(hist, "Entree3")
verifier("6. Une ligne par panne, la plus récente d'abord", e1 is not None and e2 is not None and e3 is not None and trouve(hist, "Vide") is None)
verifier("6. Panne en cours : titre orange, détail, « … · en cours »",
         texte_de(trouve(e1, "TitreEntree")) == "●  AIR VICIÉ" and texte_de(trouve(e1, "Detail")) == "air à 20 %"
         and texte_de(trouve(e1, "Horaire")) == "15/01 09:00  ·  en cours" and trouve(e1, "TitreEntree").props.get("TextColor3") is C.get("orange"),
         (texte_de(trouve(e1, "TitreEntree")), texte_de(trouve(e1, "Horaire"))))
verifier("6. Panne réglée : début → fin et « réparé par Alice », en vert",
         texte_de(trouve(e2, "Horaire")) == "15/01 08:00 → 08:08  ·  réparé par Alice" and trouve(e2, "TitreEntree").props.get("TextColor3") is C.get("vert"),
         texte_de(trouve(e2, "Horaire")))
verifier("6. Réparateur inconnu : pas de « réparé par »", texte_de(trouve(e3, "Horaire")) == "15/01 07:50 → 07:55", texte_de(trouve(e3, "Horaire")))
ext.m_SetAttribute("HistoriquePannes", "{pas du json"); H.avancer(0.05)
verifier("6. Historique illisible : « Aucune panne… », sans erreur", trouve(hist, "Vide") is not None and trouve(hist, "Entree1") is None and not roblox.ERREURS, roblox.ERREURS[:3])
appuyer(bh)
verifier("6. Re-clic : retour au tableau des pannes", hist.props.get("Visible") is False and texte_de(bh) == "HISTORIQUE")
verifier("6. La tablette ne fait que lire HistoriquePannes (aucun envoi au serveur)",
         'GetAttribute("HistoriquePannes")' in tablette and "HistoriquePannes" not in "".join(l for l in tablette.split("\n") if "FireServer" in l))
verifier("6. Tablette : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])

# ================================================================== 7. Ambiance : sons des pannes (module entier)
vider_cache(); roblox.ERREURS.clear()
I, G, game, joueur = monde(serveur=False)
activer_maths(G)
rs = game.m_FindFirstChild("ReplicatedStorage"); ws = game.m_FindFirstChild("Workspace")
RunService = game.m_FindFirstChild("RunService"); Lighting = game.m_FindFirstChild("Lighting")
tache(lambda: R.update(Config=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisConfig")])), UI=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisUI")]))))
Config, UI = R["Config"], R["UI"]; E = Config.get("Etats")
camera = Instance("Camera", "Camera", ws); camera.props.update({"CFrame": CF((0, 60, 20)), "FieldOfView": 70, "ViewportSize": Valeur("Vector2", [1280, 720])})
ws.props["CurrentCamera"] = camera; ws.props["Terrain"] = Instance("Terrain", "Terrain")
ws.extra["Raycast"] = Fonction("Raycast", py=lambda *a: None)
Lighting.props.update({"ClockTime": 12, "ExposureCompensation": 0, "Ambient": Couleur(0.5, 0.5, 0.5), "OutdoorAmbient": Couleur(0.5, 0.5, 0.5)})
remote = Instance("RemoteEvent", "TardisCommande_TARDIS_1", rs)
t1 = Instance("Folder", "TARDIS_1", Instance("Folder", "TARDIS", ws))
x = Instance("Model", "Cabine", Instance("Folder", "EXTERIEURE", t1)); x.props.update({"Pivot": CF((0, 50, 0)), "ExtentsSize": Vec3(4, 9, 4)})
racine = piece("Racine", x, (0, 50, 0), (4, 1, 4)); x.props["PrimaryPart"] = racine
Instance("Folder", "Boucliers", x)
interieur = Instance("Model", "Salle", Instance("Folder", "INTERIEURE", t1))
consoleA = Instance("Model", "Console", interieur); plateau = piece("Plateau", consoleA, (0, 1000, 4))
rotorA = piece("Rotor", interieur, (0, 1000, 0)); interieur.props["PrimaryPart"] = rotorA
grA = Instance("Folder", "Grilles", interieur)
grillesA = [piece("Grille", grA, (6 * i, 1000, 10), (2, 0.2, 2)) for i in range(3)]
for i, g_ in enumerate(grillesA): g_.attrs["TardisGrille"] = 3 - i   # numéros du serveur : la grille n°1 est la dernière de la liste
x.attrs.update({"Etat": "Pose", "DebutEtat": 1000.0, "Mode": "Normal", "Alimentation": True})
assets = Instance("Folder", "TardisAssets", rs); sonsAssets = Instance("Folder", "Sons", assets)
init = lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/init.client.lua")
outils = init[init.index("local function partTemporaire(proprietes)"):init.index("-- La lampe du toit : la pièce qui contient la PointLight")]
O = {}
tache(lambda: O.update(t=premier(I.executer("local exterieur, Config, E = ...\n" + outils + "\nreturn { partTemporaire = partTemporaire, progressionAnimation = progressionAnimation }",
                                            "outils-extras", (x, Config, E)))))
DEDANS = {"v": True}
ctxA = Table({"C": UI.get("C"), "Config": Config, "E": E, "Lighting": Lighting, "RunService": RunService, "UI": UI, "animer": UI.get("animer"),
              "camera": camera, "creer": UI.get("creer"), "texte": UI.get("texte"), "def": Config.get("Tardis").get(1), "exterieur": x, "interieur": interieur,
              "joueur": joueur, "jeSuisDedans": Fonction("jeSuisDedans", py=lambda: DEDANS["v"]), "partTemporaire": O["t"].get("partTemporaire"),
              "progressionAnimation": O["t"].get("progressionAnimation"), "remote": remote, "ReplicatedStorage": rs, "Players": game.m_FindFirstChild("Players"),
              "boiteInt": CF((0, 1000, 0)), "dansInterieur": Fonction("dansInterieur", py=lambda p: DEDANS["v"]),
              "maRacine": Fonction("maRacine", py=lambda: None), "lampe": None})
def image(dt=0.1, n=1):
    for _ in range(n):
        H.avancer(dt)
        for nom in ("RenderStepped", "Heartbeat"):
            sig = RunService.extra.get(nom)
            if sig: sig.declencher(dt)
tache(lambda: appeler(premier(I.executer(ambiance, "Ambiance")), [ctxA]))
verifier("7. Ambiance se charge (sons des pannes compris)", not roblox.ERREURS, roblox.ERREURS[:3])
def sons(nom): return [e for e in descendants(interieur) if e.ClassName == "Sound" and e.Name == "Tardis" + nom]
jets = lambda: [next(p for a in g_.enfants if a.ClassName == "Attachment" for p in a.enfants if p.ClassName == "ParticleEmitter").props.get("Rate") for g_ in grillesA]
x.m_SetAttribute("VapeurSurcharge", 1); x.m_SetAttribute("Incendie", True); x.m_SetAttribute("Avarie", True); image(0.1, 200)
x.m_SetAttribute("PanneEtincelles", 1020.0); image(0.1, 3)
verifier("7. Sans Sound Panne_* : silence, aucune erreur (pannes en cours, clic sur le rotor)",
         not any(sons(n) for n in ("Panne_Vapeur", "Panne_Feu", "Panne_Grincement", "Panne_Etincelles")) and not roblox.ERREURS, roblox.ERREURS[:3])
verifier("7. Jet de vapeur constant sur la grille désignée par le serveur (TardisGrille 1 = la 3e de la liste)", jets()[2] == 160 and jets()[0] != 160, jets())
for nom in ("Panne_Vapeur", "Panne_Feu", "Panne_Grincement", "Panne_Etincelles"):
    s_ = Instance("Sound", nom, sonsAssets); s_.props.update({"Volume": 0.7, "TimeLength": 1.5, "Looped": False})
image(0.1, 30)
sv = sons("Panne_Vapeur")
verifier("7. Panne_Vapeur : sifflement en boucle sur la grille en surcharge (portée 40)", len(sv) == 1 and sv[0].parent is grillesA[2] and sv[0].props.get("Looped") is True
         and sv[0].props.get("RollOffMaxDistance") == 40, [(s_.parent.Name, s_.props.get("Looped")) for s_ in sv])
sf = sons("Panne_Feu")
verifier("7. Panne_Feu : crépitement en boucle sur la console en feu", len(sf) == 1 and sf[0].parent is plateau and sf[0].props.get("Looped") is True, [s_.parent.Name for s_ in sf])
x.m_SetAttribute("VapeurSurcharge", 3); image(0.1, 5)
sv = sons("Panne_Vapeur")
verifier("7. Une autre grille lâche : le sifflement passe sur elle (un seul son)", len(sv) == 1 and sv[0].parent is grillesA[0], [s_.parent.Name for s_ in sv])
x.m_SetAttribute("IncendieEteint", 1050.0); image(0.1, 5)
verifier("7. Flammes éteintes (extincteur) : le crépitement s'arrête", not sons("Panne_Feu"))
x.m_SetAttribute("IncendieEteint", None); image(0.1, 5)
verifier("7. Les flammes repartent : le crépitement reprend", len(sons("Panne_Feu")) == 1)
x.m_SetAttribute("Incendie", False); x.m_SetAttribute("VapeurSurcharge", None); image(0.1, 5)
verifier("7. Pannes réglées : plus de sifflement ni de crépitement (rien ne reste)", not sons("Panne_Vapeur") and not sons("Panne_Feu"))
grincements = []
for _ in range(400):
    image(0.1); n_ = len(sons("Panne_Grincement"))
    if n_ and (not grincements or grincements[-1][1] == 0): grincements.append((H.t, n_))
    elif not n_ and grincements and grincements[-1][1]: grincements.append((H.t, 0))
debuts = [t for t, n_ in grincements if n_]
verifier("7. Avarie : un grincement au hasard toutes les 8 à 15 s, sur le rotor, joué une fois puis retiré",
         len(debuts) >= 2 and all(7.9 <= b - a <= 15.3 for a, b in zip(debuts, debuts[1:])) and all(s_.parent is rotorA and s_.props.get("Looped") is False for s_ in sons("Panne_Grincement") or [])
         and any(n_ == 0 for _, n_ in grincements), [round(b - a, 1) for a, b in zip(debuts, debuts[1:])])
x.m_SetAttribute("Avarie", None); image(0.1, 200); n_ = len([1 for _ in range(200) if (image(0.1) or True) and sons("Panne_Grincement")])
verifier("7. Avarie réparée : plus de grincement", n_ == 0, n_)
x.m_SetAttribute("PanneEtincelles", 1100.0 + H.t); image(0.1, 2)
se = sons("Panne_Etincelles")
verifier("7. Clic sur le rotor en panne (PanneEtincelles) : le son des étincelles joue une fois, sur le rotor", len(se) == 1 and se[0].parent is rotorA and se[0].props.get("Looped") is False)
image(0.1, 80)
verifier("7. … puis il est retiré", not sons("Panne_Etincelles"))
x.m_SetAttribute("Detruit", True); x.m_SetAttribute("Incendie", True); x.m_SetAttribute("VapeurSurcharge", 2); image(0.1, 5)
verifier("7. TARDIS détruit : silence", not sons("Panne_Feu") and not sons("Panne_Vapeur"))
verifier("7. Ambiance : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])
blocSons = entre(ambiance, "-- (V6.9.12) Sons des pannes, chez chaque joueur", "\n\t--------------------------------------------------------------------\n\t-- 3 ter)")
verifier("7. Pas de nouvelle boucle image par image (2 Heartbeat comme avant) : une tâche toutes les 0,25 s",
         ambiance.count("RunService.Heartbeat:Connect") == 2 and "RunService" not in blocSons and "task.wait(0.25)" in blocSons)
verifier("7. Le client ne fait qu'écouter (aucun envoi au serveur)", "FireServer" not in ambiance)

# ================================================================== 8. Le code
for chemin, src in (("TardisConfig", config_src), ("TardisSystemes", systemes), ("TardisExtras", extras), ("TabletteTechnicien", tablette),
                    ("Ambiance", ambiance), ("TardisDiagnostic", diagnostic)):
    verifier(f"8. {chemin} : ajouts marqués « (V6.9.12) »", "(V6.9.12)" in src)
verifier("8. Version 6.9.12 dans TardisConfig", 'Config.Version = "6.9.12"' in config_src)
verifier("8. Aucun compteur de réparations par technicien (« réparé par » = une mention)",
         not re.search(r"(reparations|compteur\w*|nbReparations|totalReparations)\s*\[", systemes) and "par = nom" in systemes)
verifier("8. Diagnostic : les 4 sons Panne_* dans les sons facultatifs, le dossier Zones dans les pièces facultatives",
         all(f'"{n}"' in entre(diagnostic, "local SONS_OPTIONNELS", "local function chercherDans") for n in ("Panne_Vapeur", "Panne_Feu", "Panne_Grincement", "Panne_Etincelles"))
         and '{ "Zones", "zones des pannes" }' in diagnostic)
verifier("8. Le serveur décide : rien de nouveau n'arrive du client (pas de nouvelle action réseau)",
         "HistoriquePannes" not in "".join(l for l in tablette.split("\n") if "FireServer" in l) and "PanneEtincelles" not in "".join(l for l in ambiance.split("\n") if "FireServer" in l))

print("\n".join("  ✓ " + o for o in OK)); print("\n".join("  ✗ " + k for k in KO))
print(f"V6.9.12 : {len(OK)}/{len(OK) + len(KO)} vérifications réussies")
sys.exit(1 if KO else 0)
