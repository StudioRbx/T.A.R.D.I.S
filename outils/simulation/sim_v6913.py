"""Simulations de la V6.9.13 (nouvelles pannes et outils du technicien) : le vrai code, extrait des scripts et exécuté.
  1. TardisConfig : version, sons facultatifs (Panne_FuiteAir, RotorBloque, Soudure à 0), réglages, pièces des pannes
     situées (Config.piecesDePanne, Config.pieceEnPanne : numéro d'abord, chemin pour le repli), raison de blocage
     d'un départ (Config.raisonBlocageDepart : messages existants identiques, « ROTOR BLOQUÉ », tentative notée côté serveur).
  2. Serveur (extrait de TardisSystemes : socle des pannes, tirage, nouvelles pannes, outils, purge et diagnostic) :
     fuite d'air (repli sur une grille, pièces Conduits, air qui baisse, colmatage réservé, purge refusée), rotor
     bloqué (débloqué au rotor par un pilote ou un technicien), brèche (explosion, seuil d'intégrité, soudeur : distance,
     pause, passages, PV rendus), modèles d'outils TardisAssets › Outils (sinon le bloc de couleur), diagnostic.
  3. Les trois départs (voyage, vol libre, poche) passent par Config.raisonBlocageDepart ; messages inchangés.
  4. Le vrai client : tablette technicien (cartes guidées, 7 boutons d'outils), module ScannerTechnicien (lecture
     seule : bulle et cadre sur la pièce visée, effets de la fuite, de la brèche, du soudeur, du rotor bloqué).
  5. Ambiance (le module entier) : sifflement de la fuite, raclement du rotor bloqué, grésillement du soudeur.
  6. Le code : repères (V6.9.13), écrans, supervision, diagnostic Studio, aucun envoi au serveur côté scanner."""
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
def liste_lua(t, n=20): return [t.get(i) for i in range(1, n + 1) if t is not None and t.get(i) is not None]
R = {}

systemes = lire("ServerScriptService/TardisSystemes.server.lua")
serveur = lire("ServerScriptService/TardisServeur/init.server.lua")
vollibre = lire("ServerScriptService/TardisServeur/VolLibre.lua")
tablette = lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/TabletteTechnicien.lua")
scanner = lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/ScannerTechnicien.lua")
ambiance = lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Ambiance.lua")
initclient = lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/init.client.lua")
systemesClient = lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Systemes.lua")
config_src = lire("ReplicatedStorage/TardisConfig.lua")
diagnostic = lire("ServerScriptService/TardisDiagnostic.lua")
ecrans = lire("ServerScriptService/TardisServeur/Ecrans.lua")
supervision = lire("ServerScriptService/TardisSupervision.server.lua")
outilsTablette = lire("StarterPlayer/StarterPlayerScripts/TardisTablette/Outils.lua")

# ================================================================== 1. TardisConfig
vider_cache(); roblox.ERREURS.clear()
I, G, game, pilote = monde(serveur=True)
activer_maths(G)
rs = game.m_FindFirstChild("ReplicatedStorage")
tache(lambda: R.update(Config=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisConfig")]))))
Config = R["Config"]
verifier("1. Vrai TardisConfig chargé, version 6.9.13 ou plus", version(Config.get("Version")) >= (6, 9, 13) and not roblox.ERREURS, (Config.get("Version"), roblox.ERREURS[:3]))
SONS = Config.get("Sons")
verifier("1. Config.Sons : Panne_FuiteAir, RotorBloque, Soudure à 0 (facultatifs, rien n'est créé)",
         all(SONS.get(n) == 0 for n in ("Panne_FuiteAir", "RotorBloque", "Soudure")))
TECH = Config.get("Technicien"); SY = Config.get("Systemes")
verifier("1. Config.Technicien : fuite (2 % toutes les 5 s), colmatage 4 s, portée du scanner 30 studs",
         (TECH.get("FuiteAirPerte"), TECH.get("FuiteAirIntervalle"), TECH.get("ColmatageDuree"), TECH.get("ScannerPortee")) == (2, 5, 4, 30))
verifier("1. Config.Systemes : poids 1 et 1, déblocage 6 s, brèche sous 60 %, explosion, rotor à 50 %, 4 passages, pause 1 s, 8 studs, 500 PV",
         (SY.get("PoidsFuiteAir"), SY.get("PoidsRotorBloque"), SY.get("DeblocageRotorDuree"), SY.get("BrecheSousPV"), SY.get("BrecheExplosion"),
          SY.get("BrecheReparationRotor"), SY.get("SoudureEtapes"), SY.get("SoudurePause"), SY.get("SoudureDistance"), SY.get("SoudurePV"))
         == (1, 1, 6, 60, True, 0.5, 4, 1, 8, 500))
salle = Instance("Model", "Salle")
cond = Instance("Folder", "Conduits", salle)
t1_ = piece("Tuyau", cond, (0, 1000, 0)); t2_ = piece("Tuyau", Instance("Model", "Coude", cond), (4, 1000, 0))
Instance("Folder", "Tuyau", cond)
seule = piece("FuiteAir", Instance("Model", "Machines", salle), (8, 1000, 0))
piece("FuiteAir", cond, (9, 1000, 0)).Name  # dans le dossier ET au bon nom : une seule fois
def pieces(cle, interieur=salle): return liste_lua(appel(Config.get("piecesDePanne"), interieur, cle)[0])
pf = pieces("FuiteAir")
verifier("1. Config.piecesDePanne : les Parts du dossier Conduits (même dans un Model), puis les Parts « FuiteAir », sans doublon ni dossier",
         len(pf) == 4 and pf[0] is t1_ and pf[1] is t2_ and pf[3] is seule, [getattr(p, "Name", p) for p in pf])
verifier("1. Brèche sans dossier Structure ni Breches : aucune pièce ; clé inconnue ou intérieur absent : liste vide, sans erreur",
         pieces("Breche") == [] and pieces("Martiens") == [] and pieces("FuiteAir", None) == [] and not roblox.ERREURS, roblox.ERREURS[:3])
st = Instance("Folder", "Breches", salle); b1 = piece("Mur", st, (0, 1000, 9))
verifier("1. Dossier « Breches » (autre nom de « Structure ») accepté", pieces("Breche") == [b1])
ext = Instance("Model", "Cabine")
def en_panne(cle="FuiteAir"):
    v = appel(Config.get("pieceEnPanne"), ext, salle, cle)
    return v[0], v[1]
verifier("1. Config.pieceEnPanne : pas de panne → rien", en_panne() == (None, None))
ext.attrs.update({"FuiteAir": 2, "FuiteAirChemin": "Conduits/Tuyau"})
verifier("1. Numéro 2 : la 2e pièce, même si le chemin (deux « Tuyau ») mène à la première", en_panne() == (t2_, 2), en_panne())
ext.attrs.update({"FuiteAir": 0, "FuiteAirChemin": "Machines/FuiteAir"})
verifier("1. Numéro 0 (repli) : la pièce du chemin", en_panne() == (seule, 0), en_panne())
ext.attrs.update({"FuiteAir": 9, "FuiteAirChemin": "Machines/FuiteAir"})
verifier("1. Numéro hors liste : le chemin sert de secours", en_panne() == (seule, 9))
ext.attrs.update({"FuiteAir": 0, "FuiteAirChemin": "Conduits"})
verifier("1. Chemin vers un dossier (pas une pièce), chemin introuvable : rien, sans erreur", en_panne() == (None, None) and not roblox.ERREURS)
ext.attrs.update({"FuiteAir": False}); verifier("1. Attribut à false : rien", en_panne() == (None, None))
ext.attrs.clear()
def raison(e): return appel(Config.get("raisonBlocageDepart"), e)[0]
cab = Instance("Model", "Cabine")
verifier("1. Config.raisonBlocageDepart : rien ne bloque → nil ; pas de cabine → nil", raison(cab) is None and raison(None) is None)
cab.attrs["RotorBloque"] = True
verifier("1. Rotor bloqué → « ROTOR BLOQUÉ », tentative notée par le serveur (RotorTentative)", raison(cab) == "ROTOR BLOQUÉ" and cab.attrs.get("RotorTentative") == 1000.0 + H.t, cab.attrs)
cab.attrs["DemarrageBloque"] = True
verifier("1. Démarrage bloqué l'emporte : « DÉMARRAGE BLOQUÉ » (message inchangé)", raison(cab) == "DÉMARRAGE BLOQUÉ")
cab.attrs["Alimentation"] = False
verifier("1. Hors tension l'emporte sur tout : « HORS TENSION » (message inchangé)", raison(cab) == "HORS TENSION")
cab.attrs.update({"Alimentation": True, "DemarrageBloque": False, "RotorBloque": False})
verifier("1. Alimentation true, attributs à false : rien ne bloque", raison(cab) is None)
verifier("1. Config : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])
# Côté client : le rotor bloqué bloque aussi, sans écrire d'attribut
vider_cache(); roblox.ERREURS.clear()
Ic, Gc, gamec, _ = monde(serveur=False)
tache(lambda: R.update(Cc=premier(appeler(Gc["require"], [gamec.m_FindFirstChild("ReplicatedStorage").m_FindFirstChild("TardisConfig")]))))
cabc = Instance("Model", "Cabine"); cabc.attrs["RotorBloque"] = True
verifier("1. Chez le client : « ROTOR BLOQUÉ » aussi, mais aucune tentative notée (seul le serveur écrit)",
         appel(R["Cc"].get("raisonBlocageDepart"), cabc)[0] == "ROTOR BLOQUÉ" and "RotorTentative" not in cabc.attrs and not roblox.ERREURS, (cabc.attrs, roblox.ERREURS[:3]))

# ================================================================== 2. Serveur : nouvelles pannes et outils (extraits réels)
vider_cache(); roblox.ERREURS.clear()
I, G, game, pilote = monde(serveur=True)
activer_maths(G)
rs = game.m_FindFirstChild("ReplicatedStorage"); ss = game.m_FindFirstChild("ServerStorage"); Players = game.m_FindFirstChild("Players")
tache(lambda: R.update(Config=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisConfig")]))))
Config = R["Config"]; E = Config.get("Etats"); S = Config.get("Systemes")
partDe = entre(systemes, "local function partDe(objet)", "local function trouverChemin(cle)")
socle = entre(systemes, "local FICHES_PANNES = {", "\n--------------------------------------------------------------------\n-- Points de vie et avarie")
tirage = entre(systemes, "local PANNES_ALEATOIRES = {", "-- (V6.9.12) Fréquence réglable")
nouvelles = entre(systemes, "-- (V6.9.13) Nouvelles pannes : fuite d'air et rotor bloqué", "local function retirerOutils(joueur, garderCle")
technique = entre(systemes, '\telseif commande == "Purger" then', "\nPlayers.PlayerRemoving:Connect(function(joueur) dernierTech[joueur] = nil end)")
salleS = Instance("Model", "Salle")
rotorS = piece("Rotor", salleS, (0, 1000, 0))
consoleS = Instance("Model", "Console", salleS); plateauS = piece("Plateau", consoleS, (0, 1000, 5)); consoleS.props["PrimaryPart"] = plateauS
grS = Instance("Folder", "Grilles", salleS)
grillesS = [piece("Grille", grS, (10 + 2 * i, 1000, 0)) for i in range(3)]
extS = Instance("Model", "Cabine"); extS.props["Pivot"] = CF((0, 0, 0))
extS.attrs.update({"RegulAir": 30, "Alimentation": True, "PointsDeVie": 100})
INTERNE, DIRE, PILOTES, ETAT = [], [], [], {"v": E.get("Pose")}
def interne(action, *a):
    INTERNE.append((action,) + a)
    if action == "etat": return [ETAT["v"], False]
    return []
def perso(joueur, pos):
    p = Instance("Model", joueur.Name, game.m_FindFirstChild("Workspace")); piece("HumanoidRootPart", p, pos); joueur.props["Character"] = p; return p
alice = Instance("Player", "Alice", Players); alice.props.update({"UserId": 202, "DisplayName": "Alice"}); alice.attrs["TardisTechnicien_TARDIS_1"] = True
bob = Instance("Player", "Bob", Players); bob.props.update({"UserId": 303, "DisplayName": "Bob"})
for j in (alice, bob, pilote): Instance("Backpack", "Backpack", j)
persoA = perso(alice, (10, 1000, 3)); perso(bob, (10, 1000, 3)); perso(pilote, (0, 1000, 2))
prelude = ("local Config, S, E, exterieur, interieur, def, ServerStorage, Players, ReplicatedStorage, interne, dire, estPilote, estTechnicien, direAuxPilotes, panneVapeur, panneIncendie = ...\n"
           "local TECH = Config.Technicien or {}\n" + partDe +
           "local function racineDe(joueur) return joueur.Character and joueur.Character:FindFirstChild(\"HumanoidRootPart\") end\n"
           "local function trouverChemin(cle) return nil end\n"
           "local rotorPart = partDe(interieur:FindFirstChild(Config.NomRotor or \"Rotor\"))\n" + socle +
           "\nlocal pvMax = 10000\nlocal pv = pvMax\nlocal REPARE = {}\n"
           "local function reparer(montant) pv = math.clamp(pv + montant, 0, pvMax) table.insert(REPARE, montant) end\n"
           "local grilles = Config.grillesDe(interieur)\n" + tirage + "\n" + nouvelles +
           "\nlocal function technique(commande, joueur)\n\tif commande == \"__aucune\" then\n" + technique)
fin = ("\nreturn { fiches = FICHES_PANNES, liste = PANNES_ALEATOIRES, tirer = tirerPanneAleatoire, fuite = panneFuiteAir, colmater = colmaterFuiteAir,"
       " rotor = panneRotorBloque, breche = ouvrirBreche, souder = souderBreche, defauts = defautsNouvellesPannes, donner = donnerOutil, outils = OUTILS,"
       " technique = technique, regler = function(v) pv = v end, lirePV = function() return pv end, repare = REPARE }")
tache(lambda: R.update(srv=premier(I.executer(prelude + fin, "nouvelles-pannes",
      (Config, S, E, extS, salleS, Config.get("Tardis").get(1), ss, Players, rs, Fonction("interne", py=interne),
       Fonction("dire", py=lambda j, m, ok=None: DIRE.append((j.Name, m, ok)) or []),
       Fonction("estPilote", py=lambda j: [j is pilote]), Fonction("estTechnicien", py=lambda j: [j.attrs.get("TardisTechnicien_TARDIS_1") is True]),
       Fonction("direAuxPilotes", py=lambda m, ok=None: PILOTES.append((m, ok)) or []),
       Fonction("panneVapeur", py=lambda: [False]), Fonction("panneIncendie", py=lambda: [False]))))))
SV = R.get("srv")
verifier("2. Vrai code serveur extrait et chargé (socle, tirage, nouvelles pannes, outils, purge, diagnostic)", SV is not None and not roblox.ERREURS, roblox.ERREURS[:3])
FI = SV.get("fiches")
verifier("2. Trois nouvelles fiches (titre, court, effet sur le vol, qui répare) : fuite d'air, rotor bloqué, brèche",
         all(FI.get(c) is not None and all(isinstance(FI.get(c).get(k), str) and FI.get(c).get(k) for k in ("titre", "court", "effet", "repare")) for c in ("FuiteAir", "RotorBloque", "Breche"))
         and "décollage impossible" in FI.get("RotorBloque").get("effet") and FI.get("FuiteAir").get("effet").startswith("aucun effet sur le vol"))
LP = liste_lua(SV.get("liste"))
verifier("2. Tirage des pannes aléatoires : vapeur, incendie, fuite d'air, rotor bloqué (poids de Config.Systemes)",
         [(p.get("nom"), p.get("poids")) for p in LP] == [("Vapeur", 1), ("Incendie", 1), ("FuiteAir", 1), ("RotorBloque", 1)], [(p.get("nom"), p.get("poids")) for p in LP])
def historique():
    try: return json.loads(extS.attrs.get("HistoriquePannes") or "[]")
    except ValueError: return "illisible"
def prompts(nom): return [e for e in descendants(salleS) if e.ClassName == "ProximityPrompt" and e.Name == nom]
def declencher(o, sig, *a): o.extra.setdefault(sig, Signal(sig)).declencher(*a); H.avancer(0.01)

# --- Fuite d'air, repli sur une grille
pdr = prompts("TardisDeblocageRotor")
verifier("2. Invite « Débloquer le rotor » posée sur le rotor, éteinte tant qu'il n'est pas bloqué (6 s, 9 studs)",
         len(pdr) == 1 and pdr[0].parent is rotorS and pdr[0].props.get("Enabled") is False and pdr[0].props.get("HoldDuration") == 6 and pdr[0].props.get("MaxActivationDistance") == 9)
INTERNE.clear()
ok = appel(SV.get("fuite"))[0]
pc = prompts("TardisColmatage")
verifier("2. Fuite d'air sans pièce Conduits/FuiteAir : sur une grille (numéro 0 = repli), chemin publié",
         ok is True and extS.attrs.get("FuiteAir") == 0 and extS.attrs.get("FuiteAirChemin") == "Grilles/Grille", (ok, extS.attrs.get("FuiteAir"), extS.attrs.get("FuiteAirChemin")))
verifier("2. Grilles du même nom : la fuite est sur celle que le client retrouvera (la première), l'invite aussi",
         len(pc) == 1 and pc[0].parent is grillesS[0] and appel(Config.get("pieceEnPanne"), extS, salleS, "FuiteAir")[0] is grillesS[0], [p.parent.Name for p in pc])
verifier("2. Invite de colmatage : maintenir E 4 s, 8 studs", pc and pc[0].props.get("HoldDuration") == 4 and pc[0].props.get("MaxActivationDistance") == 8 and pc[0].props.get("ActionText", "").startswith("Colmater"))
verifier("2. Annonce commune : alerte « FUITE D'AIR », PANNE / EFFET SUR LE VOL / QUI RÉPARE, historique",
         ("alerter", "FUITE D'AIR") in INTERNE and PILOTES and PILOTES[-1][0].startswith("PANNE : Fuite d'air") and "QUI RÉPARE : technicien : colmater la fuite" in PILOTES[-1][0]
         and historique()[0].get("type") == "FuiteAir" and "fin" not in historique()[0], (INTERNE, PILOTES[-1:]))
verifier("2. Déjà une fuite : pas de deuxième", appel(SV.get("fuite"))[0] is False and len(prompts("TardisColmatage")) == 1)
H.avancer(5.05)
verifier("2. L'air baisse de 2 % toutes les 5 s pendant la fuite", extS.attrs.get("RegulAir") == 28, extS.attrs.get("RegulAir"))
n = len(PILOTES); H.avancer(5)
verifier("2. Air encore au-dessus du seuil (26 %) : pas d'air vicié", extS.attrs.get("RegulAir") == 26 and len(PILOTES) == n)
H.avancer(5)
verifier("2. L'air passe sous le seuil (24 %) : panne « Air vicié » annoncée, avec la cause",
         extS.attrs.get("RegulAir") == 24 and any(m.startswith("PANNE : Air vicié (air à 24 %, fuite d'air)") for m, _ in PILOTES[n:]), PILOTES[n:])
extS.attrs["TechPurgeFin"] = 1e9; H.avancer(10)
verifier("2. Pendant une purge déjà lancée : l'air ne baisse pas", extS.attrs.get("RegulAir") == 24)
extS.attrs.pop("TechPurgeFin")
DIRE.clear(); SV.get("technique")
appel(SV.get("technique"), "Purger", alice)
verifier("2. Purge refusée pendant la fuite : « Impossible : colmatez d'abord la fuite d'air. »",
         DIRE == [("Alice", "Impossible : colmatez d'abord la fuite d'air.", False)] and "TechPurgeFin" not in extS.attrs, DIRE)
declencher(pc[0], "Triggered", bob)
verifier("2. Colmatage par un visiteur (ni pilote ni technicien) : rien", extS.attrs.get("FuiteAir") == 0 and not [d for d in DIRE if d[0] == "Bob"])
DIRE.clear(); declencher(pc[0], "Triggered", alice)
verifier("2. Technicien sans outil en main : « Il faut la visseuse ou la clé à molette en main. », la fuite reste",
         DIRE == [("Alice", "Il faut la visseuse ou la clé à molette en main.", False)] and extS.attrs.get("FuiteAir") == 0, DIRE)
Instance("Tool", "Visseuse", alice.m_FindFirstChild("Backpack"))
DIRE.clear(); declencher(pc[0], "Triggered", alice)
verifier("2. L'outil rangé dans le sac ne compte pas : il faut l'avoir en main", extS.attrs.get("FuiteAir") == 0 and DIRE and DIRE[0][2] is False)
outilMain = Instance("Tool", "CleMolette", persoA)
declencher(pc[0], "Triggered", alice)
h = historique()
verifier("2. Clé à molette en main : fuite colmatée (attributs retirés, invite retirée, « réparé par Alice »)",
         "FuiteAir" not in extS.attrs and "FuiteAirChemin" not in extS.attrs and not prompts("TardisColmatage") and PILOTES[-1] == ("Fuite d'air colmatée par Alice.", True)
         and h[0].get("type") == "AirVicie" and [e for e in h if e["type"] == "FuiteAir"][0].get("par") == "Alice", (extS.attrs, PILOTES[-1:]))
r = extS.attrs.get("RegulAir"); H.avancer(15)
verifier("2. Fuite colmatée : l'air ne baisse plus", extS.attrs.get("RegulAir") == r)
DIRE.clear(); appel(SV.get("technique"), "Purger", alice)
verifier("2. Purge de nouveau possible après le colmatage", extS.attrs.get("TechPurgeFin") is not None, DIRE)
H.avancer(7)
# --- Fuite d'air sur les pièces Conduits (noms en double)
condS = Instance("Folder", "Conduits", salleS)
tuyaux = [piece("Tuyau", condS, (20, 1000, 4 * i)) for i in range(3)]
vus = set()
for _ in range(40):
    appel(SV.get("fuite"))
    num = extS.attrs.get("FuiteAir"); pc = prompts("TardisColmatage")
    lu = appel(Config.get("pieceEnPanne"), extS, salleS, "FuiteAir")[0]
    vus.add((num, len(pc) == 1 and pc[0].parent is tuyaux[num - 1] and lu is tuyaux[num - 1]))
    appel(SV.get("colmater"), alice)
verifier("2. Pièces du dossier Conduits : une au hasard, numérotée ; client et serveur sur la même (même avec trois « Tuyau »)",
         {v for v, _ in vus} == {1, 2, 3} and all(b for _, b in vus), sorted(vus))
condS.set_parent(None)
# --- Rotor bloqué
ETAT["v"] = E.get("Vol") if E.get("Vol") is not None else "Vol"
verifier("2. Rotor bloqué seulement posé : en vol, rien", appel(SV.get("rotor"))[0] is False and "RotorBloque" not in extS.attrs)
ETAT["v"] = E.get("Pose"); INTERNE.clear()
ok = appel(SV.get("rotor"))[0]; H.avancer(0.01)
verifier("2. Rotor bloqué (posé) : attribut RotorBloque, invite allumée, alerte « ROTOR BLOQUÉ »",
         ok is True and extS.attrs.get("RotorBloque") is True and pdr[0].props.get("Enabled") is True and ("alerter", "ROTOR BLOQUÉ") in INTERNE
         and "EFFET SUR LE VOL : décollage impossible" in PILOTES[-1][0])
verifier("2. Déjà bloqué : rien de plus", appel(SV.get("rotor"))[0] is False)
verifier("2. Départ tenté : « ROTOR BLOQUÉ », tentative notée", appel(Config.get("raisonBlocageDepart"), extS)[0] == "ROTOR BLOQUÉ" and extS.attrs.get("RotorTentative"))
declencher(pdr[0], "Triggered", bob)
verifier("2. Déblocage par un visiteur : rien", extS.attrs.get("RotorBloque") is True)
declencher(pdr[0], "Triggered", pilote); H.avancer(0.01)
h = historique()
verifier("2. Déblocage par un pilote : rotor libre, tentative effacée, invite éteinte, « réparé par Pilote »",
         "RotorBloque" not in extS.attrs and "RotorTentative" not in extS.attrs and pdr[0].props.get("Enabled") is False
         and PILOTES[-1] == ("Rotor débloqué par Pilote : le TARDIS peut repartir.", True) and h[0].get("type") == "RotorBloque" and h[0].get("par") == "Pilote", PILOTES[-1:])
verifier("2. Rotor débloqué : plus rien n'empêche le départ", appel(Config.get("raisonBlocageDepart"), extS)[0] is None)
appel(SV.get("rotor")); declencher(pdr[0], "Triggered", alice)
verifier("2. Un technicien peut aussi débloquer le rotor", "RotorBloque" not in extS.attrs and historique()[0].get("par") == "Alice")
# --- Brèche
def degat(raison, montant, pv_apres):
    appel(SV.get("regler"), pv_apres); extS.m_SetAttribute("DernierDegat", "%s\t%d\t%.2f" % (raison, montant, 1000.0 + H.t)); H.avancer(0.01)
INTERNE.clear()
degat("Tir", 500, 9000)
verifier("2. Dégât ordinaire au-dessus du seuil : pas de brèche", "Breche" not in extS.attrs)
degat("Explosion", 300, 8700)
verifier("2. Explosion : brèche sur la console (sans dossier Structure), numéro 0, chemin publié, avancement 0",
         extS.attrs.get("Breche") == 0 and extS.attrs.get("BrecheChemin") == "Console/Plateau" and extS.attrs.get("BrecheAvancement") == 0
         and ("alerter", "BRÈCHE DANS LA STRUCTURE") in INTERNE and PILOTES[-1][0].startswith("PANNE : Brèche dans la structure (après une explosion"), (extS.attrs, PILOTES[-1:]))
n = len(PILOTES); degat("Explosion", 300, 8400)
verifier("2. Une seule brèche à la fois", len(PILOTES) == n and extS.attrs.get("BrecheAvancement") == 0)
DIRE.clear(); appel(SV.get("technique"), "Diagnostic", alice)
H.avancer(3)
verifier("2. Diagnostic de la tablette : « brèche dans la structure (soudure 0/4) » avec sa zone",
         DIRE and "brèche dans la structure (soudure 0/4)" in DIRE[-1][1], DIRE[-1:])
# Soudeur
sac = alice.m_FindFirstChild("Backpack")
appel(SV.get("donner"), alice, "Soudeur")
soudeur = sac.m_FindFirstChild("Soudeur")
verifier("2. Soudeur donné (sans modèle) : un Tool avec son manche, RequiresHandle, pas lâchable",
         soudeur is not None and soudeur.ClassName == "Tool" and soudeur.props.get("ToolTip") == "Soudeur" and trouve(soudeur, "Handle") is not None
         and soudeur.props.get("RequiresHandle") is True and soudeur.props.get("CanBeDropped") is False)
appel(SV.get("donner"), alice, "Soudeur")
verifier("2. Redemandé : pas de deuxième soudeur", len([e for e in sac.enfants if e.Name == "Soudeur"]) == 1)
racineA = persoA.m_FindFirstChild("HumanoidRootPart")
def souder():
    soudeur.extra.setdefault("Activated", Signal("Activated")).declencher(); H.avancer(0.01)
DIRE.clear(); racineA.props["Position"] = Vec3(0, 1000, 20); souder()
verifier("2. Soudeur trop loin (15 studs > 8) : « Approche-toi de la brèche. »", DIRE == [("Alice", "Approche-toi de la brèche.", False)] and extS.attrs.get("BrecheAvancement") == 0, DIRE)
racineA.props["Position"] = Vec3(0, 1000, 9); DIRE.clear(); souder()
verifier("2. Assez près : soudure 1/4, SoudureTemps posé (effets chez les joueurs)",
         extS.attrs.get("BrecheAvancement") == 1 and DIRE == [("Alice", "Soudure 1/4…", True)] and extS.attrs.get("SoudureTemps"), DIRE)
souder()
verifier("2. Deuxième clic aussitôt : ignoré (pause de 1 s)", extS.attrs.get("BrecheAvancement") == 1)
REP = SV.get("repare")
for _ in range(2): H.avancer(1.05); souder()
verifier("2. Passages suivants : 3/4", extS.attrs.get("BrecheAvancement") == 3 and not liste_lua(REP))
pv_av = appel(SV.get("lirePV"))[0]; H.avancer(1.05); souder()
h = historique()
verifier("2. 4e passage : brèche refermée, 500 PV rendus, « Brèche refermée par Alice. », « réparé par Alice »",
         "Breche" not in extS.attrs and "BrecheChemin" not in extS.attrs and "BrecheAvancement" not in extS.attrs and liste_lua(REP) == [500]
         and appel(SV.get("lirePV"))[0] == pv_av + 500 and PILOTES[-1] == ("Brèche refermée par Alice.", True) and h[0].get("type") == "Breche" and h[0].get("par") == "Alice", (extS.attrs, PILOTES[-1:]))
DIRE.clear(); H.avancer(1.05); souder()
verifier("2. Plus de brèche : « Aucune brèche à souder. »", DIRE == [("Alice", "Aucune brèche à souder.", False)], DIRE)
# Seuil d'intégrité
degat("Tir", 1000, 5500)
verifier("2. Intégrité qui passe sous 60 % : brèche « intégrité sous 60 % »", extS.attrs.get("Breche") == 0 and "(intégrité sous 60 %" in PILOTES[-1][0], PILOTES[-1:])
for k in ("Breche", "BrecheChemin", "BrecheAvancement"): extS.attrs.pop(k, None)
degat("Tir", 500, 5000)
verifier("2. Déjà sous le seuil : pas de nouvelle brèche à chaque tir", "Breche" not in extS.attrs)
S.set("BrecheExplosion", False); degat("Explosion", 100, 9900)
verifier("2. BrecheExplosion = false : une explosion n'ouvre pas de brèche", "Breche" not in extS.attrs)
S.set("BrecheExplosion", True); S.set("BrecheSousPV", 0); degat("Tir", 3000, 5000)
verifier("2. BrecheSousPV = 0 : pas de brèche au seuil", "Breche" not in extS.attrs)
S.set("BrecheSousPV", 60)
extS.m_SetAttribute("DernierDegat", "pas un dégât"); extS.m_SetAttribute("DernierDegat", 12); H.avancer(0.01)
verifier("2. DernierDegat illisible : rien, sans erreur", "Breche" not in extS.attrs and not roblox.ERREURS, roblox.ERREURS[:3])
strS = Instance("Folder", "Structure", salleS); murs = [piece("Mur", strS, (0, 1000, -10 - 4 * i)) for i in range(2)]
degat("Explosion", 300, 9000)
num = extS.attrs.get("Breche"); lu = appel(Config.get("pieceEnPanne"), extS, salleS, "Breche")[0]
verifier("2. Dossier Structure : la brèche s'ouvre sur une de ses pièces (numéro 1 ou 2), retrouvée par le client", num in (1, 2) and lu is murs[num - 1], (num, getattr(lu, "Name", lu)))
DIRE.clear(); racineA.props["Position"] = Vec3(0, 1000, 9); H.avancer(1.05); souder()
verifier("2. Soudeur près de la console mais loin de la vraie brèche : refusé", DIRE == [("Alice", "Approche-toi de la brèche.", False)], DIRE)
for k in ("Breche", "BrecheChemin", "BrecheAvancement"): extS.attrs.pop(k, None)
extS.attrs["Detruit"] = True; degat("Explosion", 300, 9000)
verifier("2. TARDIS détruit : pas de brèche", "Breche" not in extS.attrs)
extS.attrs.pop("Detruit")
# Diagnostic : les trois pannes, chacune dans sa zone
appel(SV.get("fuite")); appel(SV.get("rotor")); degat("Explosion", 300, 9000)
lignes = liste_lua(appel(SV.get("defauts"))[0])
verifier("2. Diagnostic : fuite d'air, rotor bloqué, brèche (soudure 0/4), chacune avec sa zone",
         len(lignes) == 3 and lignes[0].startswith("fuite d'air") and lignes[1].startswith("rotor bloqué") and lignes[2].startswith("brèche dans la structure (soudure 0/4)")
         and all("(zone " in l for l in lignes), lignes)
appel(SV.get("colmater"), alice); declencher(pdr[0], "Triggered", pilote)
for k in ("Breche", "BrecheChemin", "BrecheAvancement"): extS.attrs.pop(k, None)
verifier("2. Plus aucune nouvelle panne : aucune ligne de diagnostic", liste_lua(appel(SV.get("defauts"))[0]) == [])
# Modèles d'outils
assets = Instance("Folder", "TardisAssets", rs); dosOutils = Instance("Folder", "Outils", assets)
mod = Instance("Tool", "Scanner", dosOutils); mod.props.update({"ToolTip": ""}); mod.attrs["Modele"] = "scanner de Studio"; piece("Handle", mod, (0, 0, 0))
mauvais = Instance("Model", "Soudeur", dosOutils); piece("Handle", mauvais, (0, 0, 0))
sansManche = Instance("Tool", "Chiffon", dosOutils); sansManche.props["ToolTip"] = ""
appel(SV.get("donner"), alice, "Scanner")
sc = sac.m_FindFirstChild("Scanner")
verifier("2. Scanner avec modèle TardisAssets › Outils › Scanner : le modèle est cloné (infobulle « Scanner »)",
         sc is not None and sc.attrs.get("Modele") == "scanner de Studio" and sc.props.get("ToolTip") == "Scanner" and sc.props.get("RequiresHandle") is True and sc.props.get("CanBeDropped") is False)
appel(SV.get("donner"), alice, "Chiffon")
ch = sac.m_FindFirstChild("Chiffon")
verifier("2. Modèle sans Handle : ignoré, bloc de couleur comme avant", ch is not None and "Modele" not in ch.attrs and trouve(ch, "Handle") is not None)
soudeur.set_parent(None); appel(SV.get("donner"), alice, "Soudeur")
sd = sac.m_FindFirstChild("Soudeur")
verifier("2. Modèle qui n'est pas un Tool : ignoré, bloc de couleur", sd is not None and sd.ClassName == "Tool" and trouve(sd, "Handle") is not None)
DIRE.clear(); sc.extra.setdefault("Activated", Signal("Activated")).declencher(); H.avancer(0.01)
verifier("2. Clic avec le scanner : rien côté serveur (lecture seule, chez le joueur)", not DIRE and not roblox.ERREURS, (DIRE, roblox.ERREURS[:3]))
verifier("2. Outil inconnu : rien", appel(SV.get("donner"), alice, "Tronçonneuse") and sac.m_FindFirstChild("Tronçonneuse") is None)
O_ = SV.get("outils")
verifier("2. OUTILS : chiffon, visseuse, clé, extincteur, scanner, soudeur", all(O_.get(c) is not None for c in ("Chiffon", "Visseuse", "CleMolette", "Extincteur", "Scanner", "Soudeur")))
verifier("2. Serveur : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])
verifier("2. Outils réservés aux techniciens (action « Outil » : estTechnicien vérifié en premier)",
         'if action == "Outil" then\n\t\tif not estTechnicien(joueur) then return end' in systemes)
verifier("2. Réparation au rotor : moitié moins pendant une brèche (BrecheReparationRotor)",
         'local facteur = exterieur:GetAttribute("Breche") ~= nil and (S.BrecheReparationRotor or 0.5) or 1' in systemes
         and "reparer((S.ReparationParMaintien or 1500) * facteur)" in systemes)

# ================================================================== 3. Les trois départs
dec = entre(serveur, "local function decoller(mode)", "-- Alerte générale : toujours en urgence")
poche = entre(serveur, "local function teleporterEnPoche(", "-- Mode : celui des protocoles")
vl = entre(vollibre, 'if exterieur:GetAttribute("VolLibre") then return false, "DÉJÀ EN VOL LIBRE" end', "partage.occupe = true")
for nom, bloc in (("décollage", dec), ("vol libre", vl), ("téléportation de poche", poche)):
    verifier(f"3. {nom.capitalize()} : vérification commune Config.raisonBlocageDepart",
             "local blocage = Config.raisonBlocageDepart(exterieur)" in bloc and "if blocage then return false, blocage end" in bloc
             and 'GetAttribute("DemarrageBloque")' not in bloc)
verifier("3. Messages existants identiques (TARDIS OCCUPÉ, DÉJÀ EN VOL, TARDIS PORTÉ, PAS POSÉ, TARDIS PAS PORTÉ, DÉJÀ EN VOL LIBRE)",
         'if partage.occupe then return false, "TARDIS OCCUPÉ" end' in dec and '"DÉJÀ EN VOL"' in dec and '"TARDIS PORTÉ"' in dec
         and '"TARDIS PAS PORTÉ"' in poche and 'if partage.occupe then return false, "TARDIS OCCUPÉ" end' in poche
         and '"PAS POSÉ"' in vl and '"TARDIS OCCUPÉ"' in vl and '"TARDIS PORTÉ"' in vl)
verifier("3. Ordre conservé : occupé / état / porté AVANT tension et démarrage",
         dec.index('"TARDIS OCCUPÉ"') < dec.index('"TARDIS PORTÉ"') < dec.index("raisonBlocageDepart")
         and poche.index('"TARDIS OCCUPÉ"') < poche.index("raisonBlocageDepart") and vl.index('"TARDIS PORTÉ"') < vl.index("raisonBlocageDepart"))
verifier("3. « HORS TENSION » et « DÉMARRAGE BLOQUÉ » : textes exacts dans TardisConfig",
         'return "HORS TENSION" end' in config_src and 'return "DÉMARRAGE BLOQUÉ" end' in config_src and 'return "ROTOR BLOQUÉ"' in config_src)

# ================================================================== 4. Le vrai client : tablette technicien et scanner
vider_cache(); roblox.ERREURS.clear()
I, G, game, joueur = monde(serveur=False)
activer_maths(G)
rs = game.m_FindFirstChild("ReplicatedStorage"); ws = game.m_FindFirstChild("Workspace")
remote = Instance("RemoteEvent", "TardisCommande_TARDIS_1", rs)
ENVOIS = []
remote.extra["FireServer"] = Fonction("FireServer", py=lambda _s, *a: ENVOIS.append(a) or [])
tache(lambda: R.update(Config=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisConfig")])), UI=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisUI")]))))
Config, UI = R["Config"], R["UI"]
camera = Instance("Camera", "Camera", ws); camera.props.update({"CFrame": CF((0, 20, 40)), "ViewportSize": Valeur("Vector2", [1920, 1080])}); ws.props["CurrentCamera"] = camera
Instance("PlayerGui", "PlayerGui", joueur)
joueur.attrs["TardisTechnicien_TARDIS_1"] = True
uis = game.m_FindFirstChild("UserInputService"); uis.props.update({"TouchEnabled": False, "KeyboardEnabled": True, "MouseEnabled": True})
t1 = Instance("Folder", "TARDIS_1", Instance("Folder", "TARDIS", ws))
ext = Instance("Model", "Cabine", Instance("Folder", "EXTERIEURE", t1)); ext.props.update({"Pivot": CF((0, 0, 0)), "PrimaryPart": Instance("Part", "Racine", ext)})
racineExt = ext.props["PrimaryPart"]; racineExt.props.update({"Position": Vec3(0, 0, 0), "Size": Vec3(4, 9, 4)})
ext.attrs.update({"Etat": "Pose", "Position": "Hall", "Alimentation": True, "PointsDeVie": 84, "BouclierEnergie": 72, "Alerte": False, "Mode": "Normal",
                  "RegulEnergie": 80, "RegulAir": 84, "RegulVapeur": 50, "PV": 8400, "Salete": 0})
salle = Instance("Model", "Salle", Instance("Folder", "INTERIEURE", t1))
salle.props.update({"BoiteCFrame": CF((0, 1000, 0)), "BoiteTaille": Vec3(40, 20, 40)})
rotorC = piece("Rotor", salle, (0, 1000, 0)); piece("Portail", salle, (0, 1000, 0))
consoleC = piece("Console", salle, (0, 1000, 5)); piece("Vanne", salle, (0, 1000, 5))
gr = Instance("Folder", "Grilles", salle)
grillesC = []
for i in range(3):
    g_ = piece("Grille", gr, (i, 1000, 0), (2, 0.2, 2)); g_.attrs["TardisGrille"] = 3 - i; grillesC.append(g_)
zones = Instance("Folder", "Zones", salle)
piece("Machines", zones, (1, 1000, 0), (10, 4, 4)); piece("Pont", zones, (0, 1000, 6), (10, 4, 4))
persoJ = Instance("Model", "Pilote", ws); piece("HumanoidRootPart", persoJ, (0, 1000, 2)); joueur.props["Character"] = persoJ
C = UI.get("C")
contexte = Table({"C": C, "Config": Config, "E": Config.get("Etats"), "Lighting": game.m_FindFirstChild("Lighting"), "Players": game.m_FindFirstChild("Players"),
                  "RunService": game.m_FindFirstChild("RunService"), "UI": UI, "UserInputService": uis, "animer": UI.get("animer"), "camera": camera,
                  "creer": UI.get("creer"), "dansInterieur": Fonction("dansInterieur", py=lambda p: False), "def": Config.get("Tardis").get(1), "exterieur": ext,
                  "interieur": salle, "jeSuisDedans": Fonction("dedans", py=lambda: True), "joueur": joueur,
                  "partTemporaire": Fonction("pt", py=lambda *a: Instance("Part", "Temp")), "remote": remote, "texte": UI.get("texte")})
tache(lambda: R.update(m=premier(appeler(premier(I.executer(tablette, "TabletteTechnicien")), [contexte]))))
tech = joueur.m_FindFirstChild("PlayerGui").m_FindFirstChild("TardisTabletteTechnicien_TARDIS_1")
verifier("4. Tablette technicien construite, sans erreur", tech is not None and not roblox.ERREURS, roblox.ERREURS[:3])
RS = game.m_FindFirstChild("RunService")
def images(duree, pas=0.05):
    t = 0.0
    while t < duree - 1e-9:
        RS.__lua_index__("RenderStepped").declencher(pas); RS.__lua_index__("Heartbeat").declencher(pas)
        H.avancer(pas); t += pas
def appuyer(b): b.extra.setdefault("Activated", Signal("Activated")).declencher(); H.avancer(0.01)
def par_texte(racine, t): return [e for e in descendants(racine) if texte_de(e) == t]
joueur.m_SetAttribute("TardisTabletteTech", "TARDIS_1"); H.avancer(0.3)
boutons = [par_texte(tech, t.upper()) for t in ("Chiffon", "Visseuse", "Molette", "Extinct.", "Scan.", "Soud.", "Ranger")]
verifier("4. Panneau OUTILS : 7 boutons (Chiffon, Visseuse, Molette, Extinct., Scan., Soud., Ranger)", all(len(b) >= 1 for b in boutons), [len(b) for b in boutons])
ENVOIS.clear(); appuyer(boutons[4][0]); appuyer(boutons[5][0])
verifier("4. Scan. et Soud. demandent l'outil au serveur (« Outil », Scanner / Soudeur)",
         [(a[0], a[1].get("outil")) for a in ENVOIS] == [("Outil", "Scanner"), ("Outil", "Soudeur")], [(a[0], a[1].get("outil") if len(a) > 1 else None) for a in ENVOIS])
def guide(): return trouve(tech, "Intervention")
def etapes(): return [texte_de(trouve(guide(), "Etape%d" % k)) for k in range(1, 6) if trouve(guide(), "Etape%d" % k) is not None]
ext.m_SetAttribute("FuiteAirChemin", "Grilles/Grille"); ext.m_SetAttribute("FuiteAir", 0); images(0.6)
tt = texte_de(trouve(guide(), "Titre"))
verifier("4. Carte FUITE D'AIR : titre, zone, « Prendre : Visseuse », « Localiser : GRILLE », 4 étapes",
         tt and tt.startswith("▲  FUITE D'AIR") and "ZONE" in tt and texte_de(trouve(guide(), "Prendre")) == "PRENDRE : VISSEUSE"
         and texte_de(trouve(guide(), "Localiser")) == "LOCALISER : GRILLE" and len(etapes()) == 4 and "L'air baisse de 2 % toutes les 5 s" in etapes()[0], (tt, etapes()))
lp = [texte_de(e) for e in descendants(tech) if e.Name == "Cellule_panne"]
verifier("4. Tableau des pannes : « FUITE D'AIR »", "FUITE D'AIR" in lp, lp)
ext.m_SetAttribute("FuiteAir", None); ext.m_SetAttribute("FuiteAirChemin", None); ext.m_SetAttribute("RotorBloque", True); images(0.6)
tt = texte_de(trouve(guide(), "Titre"))
verifier("4. Carte ROTOR BLOQUÉ : « décollage impossible », « Localiser : ROTOR », pas d'outil, maintenir E 6 s",
         tt and tt.startswith("▲  ROTOR BLOQUÉ : DÉCOLLAGE IMPOSSIBLE") and texte_de(trouve(guide(), "Localiser")) == "LOCALISER : ROTOR" and trouve(guide(), "Prendre") is None
         and any("Maintiens E 6 s sur le rotor" in (e or "") for e in etapes()), (tt, etapes()))
ext.m_SetAttribute("RotorBloque", None); ext.m_SetAttribute("BrecheChemin", "Console"); ext.m_SetAttribute("BrecheAvancement", 2); ext.m_SetAttribute("Breche", 0); images(0.6)
tt = texte_de(trouve(guide(), "Titre"))
verifier("4. Carte BRÈCHE : « Prendre : Soudeur », « Localiser : STRUCTURE », « soudure 2 / 4 »",
         tt and tt.startswith("▲  BRÈCHE DANS LA STRUCTURE") and texte_de(trouve(guide(), "Prendre")) == "PRENDRE : SOUDEUR"
         and texte_de(trouve(guide(), "Localiser")) == "LOCALISER : STRUCTURE" and any("soudure 2 / 4" in (e or "") for e in etapes()), (tt, etapes()))
ENVOIS.clear(); appuyer(trouve(guide(), "Prendre"))
verifier("4. « Prendre : Soudeur » envoie seulement la demande d'outil", [(a[0], a[1].get("outil")) for a in ENVOIS] == [("Outil", "Soudeur")])
ext.m_SetAttribute("Breche", None); ext.m_SetAttribute("BrecheChemin", None); ext.m_SetAttribute("BrecheAvancement", None); images(0.6)
verifier("4. Pannes réglées : « tous les systèmes sont nominaux »", trouve(guide(), "Nominal") is not None)
verifier("4. Tablette : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])
# Scanner
ENVOIS.clear()
ctxS = Table({"C": C, "Config": Config, "UI": UI, "UserInputService": uis, "camera": camera, "creer": UI.get("creer"), "def": Config.get("Tardis").get(1),
              "exterieur": ext, "interieur": salle, "jeSuisDedans": Fonction("dedans", py=lambda: True), "joueur": joueur, "texte": UI.get("texte")})
tache(lambda: R.update(sc=premier(appeler(premier(I.executer(scanner, "ScannerTechnicien")), [ctxS]))))
SC = R.get("sc")
verifier("4. Module ScannerTechnicien chargé (bulle, cadre), sans erreur", SC is not None and joueur.m_FindFirstChild("PlayerGui").m_FindFirstChild("TardisScanner_TARDIS_1") is not None
         and joueur.m_FindFirstChild("PlayerGui").m_FindFirstChild("TardisScannerCadre_TARDIS_1") is not None and not roblox.ERREURS, roblox.ERREURS[:3])
def decrire(p):
    v = appel(SC.get("decrire"), p)
    return v[0], liste_lua(v[1]) if v[1] is not None else None, v[2]
t_, l_, a_ = decrire(grillesC[2])
verifier("4. Scanner sur une grille : « GRILLE N°1 », pression nominale, air, zone ; pas d'anomalie",
         t_ == "GRILLE N°1" and l_[0] == "Pression nominale" and l_[1] == "Air : 84 %" and l_[-1].startswith("Zone : ") and a_ is False, (t_, l_, a_))
ext.m_SetAttribute("VapeurSurcharge", 1)
t_, l_, a_ = decrire(grillesC[2])
verifier("4. Grille en surcharge : « SURCHARGE DE VAPEUR : visseuse », anomalie", l_[0] == "SURCHARGE DE VAPEUR : visseuse" and a_ is True, l_)
ext.m_SetAttribute("VapeurSurcharge", None)
t_, l_, a_ = decrire(rotorC)
verifier("4. Rotor libre : « ROTOR », intégrité 84 %, « Rotor libre »", t_ == "ROTOR" and l_[0] == "Intégrité : 84 %" and l_[1] == "Rotor libre" and a_ is False, (t_, l_))
ext.m_SetAttribute("RotorBloque", True)
t_, l_, a_ = decrire(rotorC)
verifier("4. Rotor bloqué : « BLOQUÉ : décollage impossible (maintenir E) », anomalie", "BLOQUÉ : décollage impossible (maintenir E)" in l_ and a_ is True, l_)
ext.m_SetAttribute("FuiteAirChemin", "Grilles/Grille"); ext.m_SetAttribute("FuiteAir", 0)
t_, l_, a_ = decrire(grillesC[0])
verifier("4. Fuite d'air sur la grille : « FUITE D'AIR : colmater… », anomalie", "FUITE D'AIR : colmater (visseuse ou clé, maintenir E)" in l_ and a_ is True, l_)
ext.m_SetAttribute("BrecheChemin", "Console"); ext.m_SetAttribute("BrecheAvancement", 3); ext.m_SetAttribute("Breche", 0)
t_, l_, a_ = decrire(consoleC)
verifier("4. Brèche sur la console : « CONSOLE », « BRÈCHE : soudure 3 / 4 (soudeur) »", t_ == "CONSOLE" and "BRÈCHE : soudure 3 / 4 (soudeur)" in l_ and a_ is True, (t_, l_))
ext.attrs["Salete"] = 55
t_, l_, a_ = decrire(racineExt)
verifier("4. La cabine : saleté 55 %, intégrité, anomalie (sale)", t_ == "CABINE" and l_ == ["Saleté : 55 %", "Intégrité : 84 %"] and a_ is True, (t_, l_))
ext.attrs["Salete"] = 0
dehors = piece("Arbre", ws, (50, 0, 50))
verifier("4. Pièce hors du TARDIS, ou pas une pièce : rien", decrire(dehors)[0] is None and decrire(None)[0] is None and decrire(gr)[0] is None)
# Effets
def effet(part, nom): return [e for a in part.enfants if a.Name == nom for e in a.enfants]
jet = effet(grillesC[0], "TardisFuiteAir")
verifier("4. Fuite d'air : jet d'air (ParticleEmitter « JetAir ») sur la grille de la fuite", [e.Name for e in jet] == ["JetAir"], [e.Name for e in jet])
fb = effet(consoleC, "TardisBreche")
verifier("4. Brèche : fumée et étincelles sur la pièce de la brèche", sorted(e.Name for e in fb) == ["EtincellesBreche", "FumeeBreche"], [e.Name for e in fb])
ext.m_SetAttribute("FuiteAir", None); ext.m_SetAttribute("FuiteAirChemin", None); H.avancer(2.5)
verifier("4. Fuite colmatée : le jet s'arrête puis disparaît", not effet(grillesC[0], "TardisFuiteAir"))
ext.m_SetAttribute("SoudureTemps", 1234.5); H.avancer(0.01)
sd = [a for a in consoleC.enfants if a.Name == "TardisSoudure"]
gerbe = [e for a in sd for e in a.enfants if e.ClassName == "ParticleEmitter"]
verifier("4. Passage du soudeur : gerbe de 30 étincelles et éclair sur la brèche", len(sd) == 1 and [g.emis for g in gerbe] == [30]
         and any(e.ClassName == "PointLight" for e in sd[0].enfants), [(a.Name, [e.ClassName for e in a.enfants]) for a in sd])
H.avancer(2)
verifier("4. … puis l'effet est retiré", not [a for a in consoleC.enfants if a.Name == "TardisSoudure"])
ext.m_SetAttribute("RotorTentative", 1300.0); H.avancer(0.01)
verifier("4. Départ tenté rotor bloqué : le rotor rougeoie (PointLight « TardisRotorBloque »)", rotorC.m_FindFirstChild("TardisRotorBloque") is not None)
H.avancer(1.5)
verifier("4. … un instant", rotorC.m_FindFirstChild("TardisRotorBloque") is None)
ext.m_SetAttribute("Breche", None); ext.m_SetAttribute("BrecheChemin", None); H.avancer(2.5)
verifier("4. Brèche refermée : fumée retirée", not effet(consoleC, "TardisBreche"))
# Visée : outil en main, rayon de la souris
bulle = trouve(joueur.m_FindFirstChild("PlayerGui").m_FindFirstChild("TardisScanner_TARDIS_1"), "Bulle")
cadre = joueur.m_FindFirstChild("PlayerGui").m_FindFirstChild("TardisScannerCadre_TARDIS_1")
VISE = {"p": rotorC}; RAYONS = []
uis.extra["GetMouseLocation"] = Fonction("GetMouseLocation", py=lambda _s: Table({"X": 960, "Y": 540}))
camera.extra["ViewportPointToRay"] = Fonction("ViewportPointToRay", py=lambda _s, x, y: Table({"Origin": Vec3(0, 1000, 10), "Direction": Vec3(0, 0, -1)}))
def raycast(_s, origine, direction, params):
    RAYONS.append(direction)
    return Table({"Instance": VISE["p"]}) if VISE["p"] is not None else None
ws.extra["Raycast"] = Fonction("Raycast", py=raycast)
H.avancer(1)
verifier("4. Scanner pas en main : ni bulle ni cadre, aucun rayon", bulle.props.get("Enabled") is False and cadre.props.get("Visible") is False and not RAYONS)
Instance("Tool", "Scanner", persoJ); H.avancer(1)
verifier("4. Scanner en main, rotor bloqué visé : bulle « ◆  ROTOR » en rouge, cadre sur le rotor",
         bulle.props.get("Enabled") is True and bulle.props.get("Adornee") is rotorC and cadre.props.get("Adornee") is rotorC
         and texte_de(trouve(bulle, "Titre")) == "◆  ROTOR" and trouve(bulle, "Titre").props.get("TextColor3") is C.get("rouge")
         and "BLOQUÉ" in texte_de(trouve(bulle, "Lignes")), (bulle.props.get("Enabled"), texte_de(trouve(bulle, "Titre"))))
verifier("4. Portée du rayon : Config.Technicien.ScannerPortee (30 studs)", RAYONS and abs(RAYONS[-1].z + 30) < 1e-6, RAYONS[-1:])
ext.m_SetAttribute("RotorBloque", None); H.avancer(0.5)
verifier("4. Plus d'anomalie : bulle en cyan", trouve(bulle, "Titre").props.get("TextColor3") is C.get("cyan"))
VISE["p"] = dehors; H.avancer(0.5)
verifier("4. Visée hors du TARDIS : bulle cachée", bulle.props.get("Enabled") is False and cadre.props.get("Visible") is False)
VISE["p"] = None; H.avancer(0.5)
verifier("4. Rien de visé : bulle cachée", bulle.props.get("Enabled") is False)
ws.extra["Raycast"] = Fonction("Raycast", py=lambda *a: (_ for _ in ()).throw(roblox.LuaError("raycast cassé")))
H.avancer(0.5)
verifier("4. Erreur de visée : rattrapée (pcall), bulle cachée", bulle.props.get("Enabled") is False)
roblox.ERREURS.clear()
for o in list(persoJ.enfants):
    if o.Name == "Scanner": o.set_parent(None)
ws.extra["Raycast"] = Fonction("Raycast", py=raycast); VISE["p"] = rotorC; n = len(RAYONS); H.avancer(1)
verifier("4. Scanner rangé : plus de rayon, bulle cachée", len(RAYONS) == n and bulle.props.get("Enabled") is False)
verifier("4. Le scanner n'envoie rien au serveur (lecture seule)", "FireServer" not in scanner and "remote" not in scanner and not ENVOIS)
verifier("4. Scanner : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])

# ================================================================== 5. Ambiance : sons des nouvelles pannes (module entier)
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
condA = Instance("Folder", "Conduits", interieur); tuyauxA = [piece("Tuyau", condA, (20, 1000, 4 * i)) for i in range(2)]
x.attrs.update({"Etat": "Pose", "DebutEtat": 1000.0, "Mode": "Normal", "Alimentation": True})
assets = Instance("Folder", "TardisAssets", rs); sonsAssets = Instance("Folder", "Sons", assets)
init = initclient
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
verifier("5. Ambiance se charge (sons des nouvelles pannes compris)", not roblox.ERREURS, roblox.ERREURS[:3])
def sons(nom): return [e for e in descendants(interieur) if e.ClassName == "Sound" and e.Name == "Tardis" + nom]
x.m_SetAttribute("FuiteAir", 2); x.m_SetAttribute("FuiteAirChemin", "Conduits/Tuyau"); image(0.1, 10)
x.m_SetAttribute("RotorTentative", 1010.0); x.m_SetAttribute("SoudureTemps", 1011.0); image(0.1, 3)
verifier("5. Sans Sound Panne_FuiteAir, RotorBloque, Soudure : silence, aucune erreur",
         not any(sons(n) for n in ("Panne_FuiteAir", "RotorBloque", "Soudure")) and not roblox.ERREURS, roblox.ERREURS[:3])
for nom in ("Panne_FuiteAir", "RotorBloque", "Soudure"):
    s_ = Instance("Sound", nom, sonsAssets); s_.props.update({"Volume": 0.7, "TimeLength": 1.5, "Looped": False})
image(0.1, 30)
sf = sons("Panne_FuiteAir")
verifier("5. Panne_FuiteAir : sifflement en boucle sur la fuite (la 2e pièce Conduits, malgré les noms en double)",
         len(sf) == 1 and sf[0].parent is tuyauxA[1] and sf[0].props.get("Looped") is True and sf[0].props.get("RollOffMaxDistance") == 40, [(s_.parent.Name, s_.props.get("Looped")) for s_ in sf])
x.m_SetAttribute("FuiteAir", None); x.m_SetAttribute("FuiteAirChemin", None); image(0.1, 5)
verifier("5. Fuite colmatée : plus de sifflement", not sons("Panne_FuiteAir"))
x.m_SetAttribute("RotorTentative", 1100.0 + H.t); image(0.1, 2)
sr = sons("RotorBloque")
verifier("5. Départ tenté rotor bloqué : raclement joué une fois, sur le rotor", len(sr) == 1 and sr[0].parent is rotorA and sr[0].props.get("Looped") is False, [s_.parent.Name for s_ in sr])
x.m_SetAttribute("RotorTentative", None); image(0.1, 2)
verifier("5. Rotor débloqué (RotorTentative effacée) : pas de nouveau raclement", len(sons("RotorBloque")) <= 1)
image(0.1, 80)
verifier("5. … le raclement est retiré après lecture", not sons("RotorBloque"))
x.m_SetAttribute("Breche", 0); x.m_SetAttribute("BrecheChemin", "Console/Plateau"); x.m_SetAttribute("SoudureTemps", 1200.0 + H.t); image(0.1, 2)
ss_ = sons("Soudure")
verifier("5. Passage du soudeur : grésillement une fois, sur la brèche", len(ss_) == 1 and ss_[0].parent is plateau and ss_[0].props.get("Looped") is False, [s_.parent.Name for s_ in ss_])
x.m_SetAttribute("Detruit", True); x.m_SetAttribute("FuiteAir", 1); image(0.1, 5)
verifier("5. TARDIS détruit : pas de sifflement", not sons("Panne_FuiteAir"))
verifier("5. Ambiance : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])
blocSons = entre(ambiance, "-- (V6.9.12) Sons des pannes, chez chaque joueur", "\n\t--------------------------------------------------------------------\n\t-- 3 ter)")
verifier("5. Pas de nouvelle boucle image par image, le client ne fait qu'écouter",
         ambiance.count("RunService.Heartbeat:Connect") == 2 and "RunService" not in blocSons and "FireServer" not in ambiance)

# ================================================================== 6. Le code
for chemin, src in (("TardisConfig", config_src), ("TardisSystemes", systemes), ("TardisServeur", serveur), ("VolLibre", vollibre),
                    ("TabletteTechnicien", tablette), ("ScannerTechnicien", scanner), ("Ambiance", ambiance), ("TardisDiagnostic", diagnostic),
                    ("Ecrans", ecrans), ("TardisSupervision", supervision), ("Tablette › Outils", outilsTablette), ("Systemes (client)", systemesClient),
                    ("init.client", initclient)):
    verifier(f"6. {chemin} : ajouts marqués « (V6.9.13) »", "(V6.9.13)" in src)
verifier("6. Version 6.9.13 ou plus récente dans TardisConfig", version(Config.get("Version")) >= (6, 9, 13) and 'Config.Version = "' in config_src, Config.get("Version"))
verifier("6. init.client charge ScannerTechnicien (après la tablette technicien)",
         'require(script:WaitForChild("ScannerTechnicien"))' in initclient and initclient.index('"TabletteTechnicien"') < initclient.index('"ScannerTechnicien"'))
verifier("6. Menu technicien (Systemes) : Scanner et Soudeur", '{ "Scanner", "Scanner (état d\'une pièce)" }' in systemesClient and '{ "Soudeur", "Soudeur (brèches)" }' in systemesClient)
verifier("6. Écrans : ROTOR BLOQUÉ, BRÈCHE, FUITE", "ROTOR BLOQUÉ" in ecrans and "BRÈCHE" in ecrans and "FUITE" in ecrans)
verifier("6. Supervision : fuite d'air, rotor bloqué, brèche suivis", all(f"{a} = function(v)" in supervision for a in ("FuiteAir", "RotorBloque", "Breche")))
verifier("6. Tablette › Outils : les trois nouvelles pannes comptées", all(f'"{a}"' in outilsTablette for a in ("FuiteAir", "RotorBloque", "Breche")))
verifier("6. Diagnostic Studio : sons Panne_FuiteAir, RotorBloque, Soudure ; dossiers Structure / Breches et FuiteAir / Conduits facultatifs",
         all(f'"{n}"' in entre(diagnostic, "local SONS_OPTIONNELS", "local function chercherDans") for n in ("Panne_FuiteAir", "RotorBloque", "Soudure"))
         and '{ "Structure", "brèches de la structure", "Breches" }' in diagnostic and '{ "FuiteAir", "fuites d\'air", "Conduits" }' in diagnostic)
verifier("6. Le serveur décide : aucune nouvelle action réseau (outils par l'action « Outil » existante)",
         not re.search(r'FireServer\("(Souder|Colmater|Debloquer|Scanner)', tablette + scanner + ambiance + systemesClient))
verifier("6. Purge refusée pendant une fuite", 'if exterieur:GetAttribute("FuiteAir") ~= nil then dire(joueur, "Impossible : colmatez d\'abord la fuite d\'air.", false) return end' in systemes)

print("\n".join("  ✓ " + o for o in OK)); print("\n".join("  ✗ " + k for k in KO))
print(f"V6.9.13 : {len(OK)}/{len(OK) + len(KO)} vérifications réussies")
sys.exit(1 if KO else 0)
