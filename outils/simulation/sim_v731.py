"""Simulations de la V7.3.1 (surchauffe, vapeur et écrans Diagnostic) : le vrai code, avec de faux objets Roblox.
  1. TardisConfig : refroidissement (C-98), surchauffe (C-117), rotor surmené (C-184), chaleur de la cabine (G-63),
     régime et courbe du moteur (G-200), voyants (G-199).
  2. Ambiance (le module entier) : grilles qui rougeoient (G-145, G-147), bouffée à l'atterrissage (G-143), vague au
     départ (G-144), vapeur doublée en surchauffe, voyants en couleur (G-199), courbe du moteur (G-200).
     Decor (le module entier) : la cabine qui chauffe (G-63).
  3. TardisSystemes et TardisExtras (les vrais Scripts serveur, banc d'essai) : avertissement, coupure, refroidissement,
     rotor surmené, remise à zéro.
  4. Le code."""
import os, sys, re, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from monde import *
import roblox
from roblox import Couleur, Vec3, CF, activer_maths
OK, KO = [], []
def verifier(nom, condition, detail=""):
    (OK if condition else KO).append(nom + ("" if condition else "  →  " + str(detail)))
def tache(f): lancer(Fonction("t", py=f))
def lire(chemin): return open(os.path.join(DEPOT, chemin), encoding="utf-8").read()
def vider_cache(): roblox.charger_module.__defaults__[0].clear()
def descendants(o):
    res = []
    def visite(x):
        for e in x.enfants: res.append(e); visite(e)
    visite(o); return res
def declencher(objet, signal, *args): objet.extra.setdefault(signal, Signal(signal)).declencher(*args)
def piece(nom, parent, pos=(0, 0, 0), taille=(2, 2, 2), classe="Part"):
    p = Instance(classe, nom, parent)
    p.props.update({"CFrame": CF(pos), "Size": Vec3(*taille), "Position": Vec3(*pos)})
    return p
random.seed(731)

# ================================================================== 1. TardisConfig
vider_cache()
I, G, game, joueur = monde(serveur=False)
activer_maths(G)
rs = game.m_FindFirstChild("ReplicatedStorage")
R = {}
tache(lambda: R.update(Config=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisConfig")])),
                       UI=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisUI")]))))
Config, UI = R["Config"], R["UI"]
E = Config.get("Etats")
SU = Config.get("Surchauffe")
f = lambda nom, *a: premier(appeler(Config.get(nom), list(a)))
fs = lambda nom, *a: list(appeler(Config.get(nom), list(a)))

verifier("Config.Version ≥ 7.3.1 (7.3.1 à sa sortie)", tuple(int(n) for n in Config.get("Version").split(".")) >= (7, 3, 1), Config.get("Version"))
verifier("Config.Surchauffe : Refroidissement 60, Avertissement 2, ClicsRotor 8, FenetreClics 10, Chaleur 0,6",
         (SU.get("Refroidissement"), SU.get("Avertissement"), SU.get("ClicsRotor"), SU.get("FenetreClics"), SU.get("Chaleur")) == (60, 2, 8, 10, 0.6))
verifier("Config.Surchauffe : les cinq effets sont actifs par défaut",
         all(SU.get(k) is True for k in ("BouffeeAtterrissage", "VagueDemat", "LueurVol", "LueurSurcharge", "CourbeMoteur")))
# refroidissement
verifier("C-98. refroidissement : 59 s posé ne suffisent pas (5 voyages, reste 59)", fs("refroidissement", 5, 59) == [5, 59])
verifier("C-98. refroidissement : 60 s → un voyage de moins, reste 0", fs("refroidissement", 5, 60) == [4, 0])
verifier("C-98. refroidissement : 150 s → deux de moins, reste 30", fs("refroidissement", 5, 150) == [3, 30])
verifier("C-98. refroidissement : jamais sous zéro, et le reste repart à zéro", fs("refroidissement", 2, 1000) == [0, 0])
verifier("C-98. refroidissement : compteur à zéro → rien à faire", fs("refroidissement", 0, 500) == [0, 0])
SU.set("Refroidissement", 0)
verifier("C-98. Refroidissement = 0 : le compteur ne baisse jamais", fs("refroidissement", 5, 1000) == [5, 0])
SU.set("Refroidissement", 60)
# enSurchauffe
verifier("C-117. enSurchauffe (limite 15, avertissement 2) : 12 non, 13 oui, 15 oui", (f("enSurchauffe", 12, 15), f("enSurchauffe", 13, 15), f("enSurchauffe", 15, 15)) == (False, True, True))
verifier("C-117. enSurchauffe : jamais à 0 voyage (même avec une petite limite)", f("enSurchauffe", 0, 1) is False)
SU.set("Avertissement", 0)
verifier("C-117. Avertissement = 0 : jamais en surchauffe", f("enSurchauffe", 15, 15) is False)
SU.set("Avertissement", 2)
# chaleurCabine
verifier("G-63. chaleurCabine (limite 15, Chaleur 0,6 → dès 9) : 8 → 0", f("chaleurCabine", 8, 15) == 0)
c9, c12, c15 = f("chaleurCabine", 9, 15), f("chaleurCabine", 12, 15), f("chaleurCabine", 15, 15)
verifier("G-63. chaleurCabine : 9 → 1/7, 12 → 4/7, 15 → 1 (monte jusqu'à la coupure)", abs(c9 - 1 / 7) < 1e-9 and abs(c12 - 4 / 7) < 1e-9 and c15 == 1, (c9, c12, c15))
verifier("G-63. chaleurCabine : jamais plus de 1 (compteur au-delà de la limite)", f("chaleurCabine", 30, 15) == 1)
SU.set("Chaleur", 0)
verifier("G-63. Chaleur = 0 : la cabine ne chauffe jamais", f("chaleurCabine", 15, 15) == 0)
SU.set("Chaleur", 0.6)
# rotorSurmene
clics = Table({})
res = [f("rotorSurmene", clics, t) for t in (0, 1, 2, 3, 4, 5, 6)]
verifier("C-184. rotorSurmene : 7 clics en 6 s → pas encore", res == [False] * 7 and clics.longueur() == 7, res)
verifier("C-184. rotorSurmene : le 8e clic dans les 10 s → surmené, la liste est vidée", f("rotorSurmene", clics, 7) is True and clics.longueur() == 0)
clics = Table({})
res = [f("rotorSurmene", clics, t * 2) for t in range(12)]
verifier("C-184. rotorSurmene : un clic toutes les 2 s (5 dans la fenêtre) → jamais", res == [False] * 12, res)
SU.set("ClicsRotor", 0)
verifier("C-184. ClicsRotor = 0 : jamais", not any(f("rotorSurmene", Table({}), t) for t in range(20)))
SU.set("ClicsRotor", 8)
# moteur
verifier("G-200. regimeMoteur : hors tension, urgence, vol, posé",
         (f("regimeMoteur", False, True, True), f("regimeMoteur", True, True, False), f("regimeMoteur", True, False, True), f("regimeMoteur", True, False, False))
         == ("HorsTension", "Urgence", "Vol", "Pose"))
pose = [f("courbeMoteur", t / 10, "Pose") for t in range(100)]
vol = [f("courbeMoteur", t / 10, "Vol") for t in range(100)]
urg = [f("courbeMoteur", t / 10, "Urgence") for t in range(100)]
verifier("G-200. courbeMoteur : posé, calme autour de 0,5 (0,4 à 0,6)", min(pose) >= 0.4 - 1e-9 and max(pose) <= 0.6 + 1e-9, (min(pose), max(pose)))
verifier("G-200. courbeMoteur : en vol, plus ample (au moins 0,5 d'écart)", max(vol) - min(vol) > 0.5, (min(vol), max(vol)))
verifier("G-200. courbeMoteur : en urgence, en dents de scie et dans 0..1", all(0 <= v <= 1 for v in urg) and len(set(round(v, 3) for v in urg)) > 5)
verifier("G-200. courbeMoteur : la même valeur chez tout le monde au même instant (pas de hasard)", f("courbeMoteur", 3.3, "Urgence") == f("courbeMoteur", 3.3, "Urgence"))
verifier("G-200. courbeMoteur : hors tension, plate à 0", all(f("courbeMoteur", t, "HorsTension") == 0 for t in range(10)))
verifier("G-199. voyantDiagnostic : bon → « ● » vert ; mauvais → « ○ » ambre ; grave → « ○ » rouge",
         (fs("voyantDiagnostic", True, True), fs("voyantDiagnostic", False, False), fs("voyantDiagnostic", False, True)) == (["●", "vert"], ["○", "ambre"], ["○", "rouge"]))

# ================================================================== 2. Ambiance et Decor (client, modules entiers)
ws = game.m_FindFirstChild("Workspace")
RunService = game.m_FindFirstChild("RunService"); Lighting = game.m_FindFirstChild("Lighting")
camera = Instance("Camera", "Camera", ws); camera.props.update({"CFrame": CF((0, 60, 20)), "FieldOfView": 70, "ViewportSize": Valeur("Vector2", [1280, 720])})
ws.props["CurrentCamera"] = camera; ws.props["Terrain"] = Instance("Terrain", "Terrain")
ws.props["GlobalWind"] = Vec3(0, 0, 0)
ws.extra["Raycast"] = Fonction("Raycast", py=lambda *a: None)
Lighting.props.update({"ClockTime": 12, "ExposureCompensation": 0, "Ambient": Couleur(0.5, 0.5, 0.5), "OutdoorAmbient": Couleur(0.5, 0.5, 0.5)})
Instance("PlayerGui", "PlayerGui", joueur)
remote = Instance("RemoteEvent", "TardisCommande_TARDIS_1", rs)
t1 = Instance("Folder", "TARDIS_1", Instance("Folder", "TARDIS", ws))
x = Instance("Model", "Cabine", Instance("Folder", "EXTERIEURE", t1)); x.props.update({"Pivot": CF((0, 50, 0)), "ExtentsSize": Vec3(4, 9, 4)})
racine = piece("Racine", x, (0, 50, 0), (4, 1, 4)); x.props["PrimaryPart"] = racine
lampe = piece("Lampe", x, (0, 59, 0), (1, 1, 1)); Instance("PointLight", "PointLight", lampe).props.update({"Brightness": 2, "Range": 10})
Instance("Folder", "Boucliers", x)
interieur = Instance("Model", "Salle", Instance("Folder", "INTERIEURE", t1))
consoleA = Instance("Model", "Console", interieur); piece("Plateau", consoleA, (0, 1000, 4))
rotorA = piece("Rotor", interieur, (0, 1000, 0)); interieur.props["PrimaryPart"] = rotorA
grA = Instance("Folder", "Grilles", interieur)
# trois grilles autour du centre (0, 1000, 0) : à l'est (angle 0), au nord (π/2), à l'ouest (π) ; créées dans le désordre
grilles = [piece("Grille", grA, p, (2, 0.2, 2)) for p in ((0, 1000, 10), (-10, 1000, 0), (10, 1000, 0))]
diag = piece("Diagnostic1", interieur, (0, 1003, -10), (4, 3, 0.2))
x.attrs.update({"Etat": "Pose", "DebutEtat": 1000.0, "Mode": "Normal", "Alimentation": True})
Instance("Folder", "Sons", Instance("Folder", "TardisAssets", rs))
init = lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/init.client.lua")
outils = init[init.index("local function partTemporaire(proprietes)"):init.index("-- La lampe du toit : la pièce qui contient la PointLight")]
O = {}
tache(lambda: O.update(t=premier(I.executer("local exterieur, Config, E = ...\n" + outils + "\nreturn { partTemporaire = partTemporaire, progressionAnimation = progressionAnimation }",
                                            "outils-extras", (x, Config, E)))))
ctxA = Table({"C": UI.get("C"), "Config": Config, "E": E, "Lighting": Lighting, "RunService": RunService, "UI": UI, "animer": UI.get("animer"),
              "camera": camera, "creer": UI.get("creer"), "texte": UI.get("texte"), "def": Config.get("Tardis").get(1), "exterieur": x, "interieur": interieur,
              "joueur": joueur, "jeSuisDedans": Fonction("jeSuisDedans", py=lambda: True), "partTemporaire": O["t"].get("partTemporaire"),
              "progressionAnimation": O["t"].get("progressionAnimation"), "remote": remote, "ReplicatedStorage": rs, "Players": game.m_FindFirstChild("Players"),
              "boiteInt": CF((0, 1000, 0)), "dansInterieur": Fonction("dansInterieur", py=lambda p: True),
              "maRacine": Fonction("maRacine", py=lambda: None), "lampe": lampe})
def image(dt=0.1, n=1):
    for _ in range(n):
        H.avancer(dt)
        for nom in ("RenderStepped", "Heartbeat"):
            sig = RunService.extra.get(nom)
            if sig: sig.declencher(dt)
def maintenant(): return 1000.0 + H.t
def etat(nom):
    x.m_SetAttribute("DebutEtat", maintenant()); x.m_SetAttribute("Etat", nom)
def pref(cle, valeur): UI.get("prefs").set(cle, valeur)
ambiance = lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Ambiance.lua")
tache(lambda: appeler(premier(I.executer(ambiance, "Ambiance")), [ctxA]))
verifier("Ambiance se charge (grilles, écran de diagnostic, courbe du moteur)", not roblox.ERREURS, roblox.ERREURS[:3])
C = UI.get("C")

def emetteurs(g): return [e for e in descendants(g) if e.ClassName == "ParticleEmitter"]
def jet(g): return emetteurs(g)[0]
def lueur(g): return [e for e in descendants(g) if e.Name == "TardisLueurGrille"][0]
def tremble(g): return [e for e in descendants(g) if e.Name == "TardisAirTremble"][0]
verifier("G-145/G-147. Chaque grille : le jet d'abord, puis l'air qui tremble, et une lueur orange éteinte",
         all(emetteurs(g)[0].Name != "TardisAirTremble" and len(emetteurs(g)) == 2 and lueur(g).props.get("Enabled") is False for g in grilles))
image(0.1, 3)
verifier("G-147. Posée : les grilles ne rougeoient pas", all(lueur(g).props.get("Enabled") is False for g in grilles))
etat("Demat")
image(0.05)
# vague : les grilles partent dans l'ordre de leur angle autour du centre : ouest (-π... en fait π), puis est (0), puis nord (π/2)
emis0 = [jet(g).emis for g in grilles]
image(0.1, 1)
emis1 = [jet(g).emis for g in grilles]
image(0.1, 2)
emis2 = [jet(g).emis for g in grilles]
verifier("G-144. Départ : une vague de vapeur, une grille après l'autre (0,15 s d'écart), 18 bouffées chacune",
         sorted(emis0) == [0, 0, 18] and sorted(emis1) == [0, 18, 18] and emis2 == [18, 18, 18], (emis0, emis1, emis2))
ordre = sorted(range(3), key=lambda i: (emis0[i] == 0, emis1[i] == 0))
verifier("G-144. La vague fait le tour de la salle (dans l'ordre des angles : est, nord, ouest)", ordre == [2, 0, 1], ordre)
etat("Vol"); image(0.1, 3)
verifier("G-147. En vol : toutes les grilles rougeoient doucement (1)", all(lueur(g).props.get("Enabled") is True and lueur(g).props.get("Brightness") == 1 for g in grilles))
verifier("G-145. En vol, sans surcharge : l'air ne tremble pas", all(tremble(g).props.get("Rate") == 0 for g in grilles))
x.m_SetAttribute("VapeurSurcharge", 1); image(0.1, 3)
en_panne = [g for g in grilles if jet(g).props.get("Rate") == 160]
verifier("G-145. Grille en surcharge (jet 160) : elle rougeoit fort (2,5 ± 0,8) et l'air tremble au-dessus",
         len(en_panne) == 1 and 1.6 <= lueur(en_panne[0]).props.get("Brightness") <= 3.4 and tremble(en_panne[0]).props.get("Rate") == 12,
         [(jet(g).props.get("Rate"), lueur(g).props.get("Brightness")) for g in grilles])
autres = [g for g in grilles if g not in en_panne]
verifier("G-145. Les autres grilles : lueur douce du vol, air calme", all(lueur(g).props.get("Brightness") == 1 and tremble(g).props.get("Rate") == 0 for g in autres))
SU.set("LueurSurcharge", False); image(0.1, 2)
verifier("G-145. LueurSurcharge = false : la grille en surcharge garde la lueur du vol, sans air qui tremble",
         en_panne and lueur(en_panne[0]).props.get("Brightness") == 1 and tremble(en_panne[0]).props.get("Rate") == 0)
SU.set("LueurSurcharge", True); SU.set("LueurVol", False); x.m_SetAttribute("VapeurSurcharge", None); image(0.1, 2)
verifier("G-147. LueurVol = false : en vol, pas de lueur", all(lueur(g).props.get("Enabled") is False for g in grilles))
SU.set("LueurVol", True)
avant = [jet(g).emis for g in grilles]
etat("Remat"); image(0.1, 2); etat("Pose"); image(0.05)
verifier("G-143. Atterrissage : bouffée de toutes les grilles en même temps (30 chacune)", [jet(g).emis - a for g, a in zip(grilles, avant)] == [30, 30, 30],
         [jet(g).emis - a for g, a in zip(grilles, avant)])
image(0.1, 3)
verifier("G-147. Reposée : les lueurs s'éteignent", all(lueur(g).props.get("Enabled") is False for g in grilles))
pref("effetsReduits", True)
avant = [jet(g).emis for g in grilles]
etat("Remat"); image(0.1, 2); etat("Pose"); image(0.05)
verifier("G-143. En « effets réduits » : petite bouffée (10)", [jet(g).emis - a for g, a in zip(grilles, avant)] == [10, 10, 10])
avant = [jet(g).emis for g in grilles]
etat("Demat"); image(0.1, 5)
verifier("G-144. En « effets réduits » : petite vague (6)", [jet(g).emis - a for g, a in zip(grilles, avant)] == [6, 6, 6])
pref("effetsReduits", False)
SU.set("BouffeeAtterrissage", False); SU.set("VagueDemat", False)
avant = [jet(g).emis for g in grilles]
etat("Remat"); image(0.1, 2); etat("Pose"); image(0.1, 2); etat("Demat"); image(0.1, 5)
verifier("G-143/G-144. Réglages à false : ni bouffée ni vague", [jet(g).emis for g in grilles] == avant)
SU.set("BouffeeAtterrissage", True); SU.set("VagueDemat", True)
x.m_SetAttribute("Alimentation", False)
avant = [jet(g).emis for g in grilles]
etat("Remat"); image(0.1, 2); etat("Pose"); image(0.1, 2)
verifier("G-143. Hors tension : pas de bouffée à l'atterrissage", [jet(g).emis for g in grilles] == avant)
x.m_SetAttribute("Alimentation", True)
# vapeur doublée en surchauffe (C-117) : on mesure le Rate d'une grille pendant une bouffée
def max_rate(n=200):
    m = 0
    for _ in range(n):
        image(0.1); m = max(m, max(jet(g).props.get("Rate") or 0 for g in grilles))
    return m
r_normal = max_rate()
x.m_SetAttribute("Surchauffe", True)
r_chaud = max_rate()
x.m_SetAttribute("Surchauffe", None)
verifier("C-117. En surchauffe, les bouffées de vapeur sont deux fois plus fortes (50 → 100)", r_normal == 50 and r_chaud == 100, (r_normal, r_chaud))

# Écran de diagnostic : voyants en couleur (G-199) et courbe du moteur (G-200)
labels = [e for e in descendants(diag) if e.ClassName == "TextLabel"]
lignes = [l for l in labels if str(l.props.get("Text", "")).startswith(("●", "○"))]
image(0.6)
lignes = [l for l in labels if str(l.props.get("Text", "")).startswith(("●", "○"))]
verifier("G-199. Écran ÉNERGIE : 3 voyants, tous verts quand tout va bien",
         len(lignes) == 3 and all(l.props.get("TextColor3") is C.get("vert") for l in lignes), [(l.props.get("Text"), l.props.get("TextColor3")) for l in lignes])
integ = [l for l in labels if str(l.props.get("Text", "")).startswith("Intégrité")]
verifier("G-199. La ligne sans voyant (intégrité) garde la couleur du texte", integ and integ[0].props.get("TextColor3") is C.get("texte"))
x.m_SetAttribute("Alimentation", False); x.m_SetAttribute("DemarrageBloque", True); image(0.6)
def ligne(debut): return [l for l in labels if str(l.props.get("Text", "")).startswith(debut)]
verifier("G-199. Hors tension et démarrage bloqué : « ○ HORS TENSION » et « ○ Démarrage bloqué » en rouge",
         ligne("○ HORS TENSION") and ligne("○ HORS TENSION")[0].props.get("TextColor3") is C.get("rouge")
         and ligne("○ Démarrage bloqué") and ligne("○ Démarrage bloqué")[0].props.get("TextColor3") is C.get("rouge"))
x.m_SetAttribute("Alimentation", True); x.m_SetAttribute("DemarrageBloque", None); image(0.6)
courbe = [e for e in descendants(diag) if e.Name == "TardisCourbeMoteur"]
barres = [e for e in courbe[0].enfants if e.ClassName == "Frame"] if courbe else []
verifier("G-200. Le premier écran a sa courbe du moteur : 30 barres sous les lignes", len(courbe) == 1 and len(barres) == 30 and courbe[0].props.get("LayoutOrder") == 10, len(barres))
def hauteurs(): return [float(b.props["Size"].args[2]) for b in barres]
image(0.1, 31)
h_pose = hauteurs()
verifier("G-200. Posée : barres cyan, entre 0,4 et 0,6", all(b.props.get("BackgroundColor3") is C.get("cyan") for b in barres) and all(h is not None and 0.39 <= h <= 0.61 for h in h_pose), h_pose[:5])
etat("Vol"); image(0.1, 31)
h_vol = hauteurs()
verifier("G-200. En vol : barres vertes, la courbe ondule davantage", all(b.props.get("BackgroundColor3") is C.get("vert") for b in barres) and max(h_vol) - min(h_vol) > max(h_pose) - min(h_pose), (min(h_vol), max(h_vol)))
x.m_SetAttribute("VolUrgence", True); image(0.1, 31)
verifier("G-200. En urgence : barres rouges", all(b.props.get("BackgroundColor3") is C.get("rouge") for b in barres))
x.m_SetAttribute("VolUrgence", None); etat("Pose"); x.m_SetAttribute("Alimentation", False); image(0.1, 31)
verifier("G-200. Hors tension : la courbe est plate (barres au minimum 0,03), rouges", all(abs(h - 0.03) < 1e-9 for h in hauteurs()) and all(b.props.get("BackgroundColor3") is C.get("rouge") for b in barres))
x.m_SetAttribute("Alimentation", True)
verifier("Ambiance : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])

# Decor : la cabine qui chauffe (G-63)
ctxD = Table({"Config": Config, "ReplicatedStorage": rs, "RunService": RunService, "UI": UI, "boiteInt": CF((0, 1000, 0)), "creer": UI.get("creer"),
              "exterieur": x, "interieur": interieur, "lampe": lampe, "partTemporaire": O["t"].get("partTemporaire"), "secouer": Fonction("secouer", py=lambda *a: [])})
decor_src = lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Decor.lua")
FN = {}
tache(lambda: FN.update(f=premier(I.executer(decor_src, "Decor"))))
tache(lambda: appeler(FN["f"], [ctxD]))
verifier("Decor se charge (cabine qui chauffe)", not roblox.ERREURS, roblox.ERREURS[:3])
def chaleur(): return [e for e in ws.enfants if e.Name == "TardisChaleur"]
def air(): return [e for e in ws.enfants if e.Name == "TardisChaleurAir"]
def emetteur(p): return [e for e in p.enfants if e.ClassName == "ParticleEmitter"][0]
x.m_SetAttribute("VoyagesConsecutifs", 8); image(0.1, 6)
verifier("G-63. 8 voyages sur 15 : la cabine ne chauffe pas", not chaleur() and not air())
x.m_SetAttribute("VoyagesConsecutifs", 12); image(0.1, 6)
ch = chaleur()
verifier("G-63. 12 voyages : vapeur sur le toit (à 8,5 au-dessus de la base) et air qui ondule autour",
         len(ch) == 1 and len(air()) == 1 and abs(ch[0].props["CFrame"].p[1] - 58.5) < 1e-6 and ch[0].props["Size"].t()[0] == 4,
         ch and (ch[0].props["CFrame"].p, ch[0].props["Size"].t()))
r12 = emetteur(ch[0]).props.get("Rate")
verifier("G-63. La vapeur suit la chaleur (12 × 4/7)", abs(r12 - 12 * 4 / 7) < 1e-6, r12)
x.m_SetAttribute("VoyagesConsecutifs", 15); image(0.1, 6)
verifier("G-63. 15 voyages : vapeur au maximum (12), air (8)", abs(emetteur(chaleur()[0]).props.get("Rate") - 12) < 1e-6 and abs(emetteur(air()[0]).props.get("Rate") - 8) < 1e-6)
pref("effetsReduits", True); image(0.1, 6)
verifier("G-63. En « effets réduits » : moins de vapeur (40 %)", abs(emetteur(chaleur()[0]).props.get("Rate") - 4.8) < 1e-6)
pref("effetsReduits", False)
etat("Demat"); image(0.1, 6)
verifier("G-63. Au départ : la chaleur disparaît", not chaleur() and not air())
etat("Pose"); x.m_SetAttribute("Camouflage", True); image(0.1, 6)
verifier("G-63. Camouflée : rien", not chaleur())
x.m_SetAttribute("Camouflage", None); image(0.1, 6)
verifier("G-63. Visible à nouveau : la chaleur revient", len(chaleur()) == 1)
x.m_SetAttribute("VoyagesConsecutifs", 0); image(0.1, 6)
verifier("G-63. Compteur remis à zéro : la chaleur part", not chaleur() and not air())
verifier("Decor : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])


# ================================================================== 3. TardisSystemes et TardisExtras (banc d'essai)
from banc import place, demarrer_serveur
P = place()
P["ws"].extra["GetPartBoundsInRadius"] = Fonction("GetPartBoundsInRadius", py=lambda *a: Table({}))
_, err = demarrer_serveur(P, duree=20)
verifier("TardisServeur, TardisExtras et TardisSystemes démarrent (banc d'essai)", not err, err[:3])
ext, j = P["ext"], P["joueur"]
RC = {}
tache(lambda: RC.update(c=premier(appeler(P["G"]["require"], [P["rs"].m_FindFirstChild("TardisConfig")]))))
ids = RC["c"].get("Techniciens").get("UserIds"); ids.set(ids.longueur() + 1, j.props["UserId"])  # technicien de la config : durable
j.m_SetAttribute("TardisTechnicien_TARDIS_1", True)
MSG = []
canal = P["rs"].m_FindFirstChild("TardisCommande_TARDIS_1")
canal.extra["FireClient"] = Fonction("FireClient", py=lambda _s, qui, msg=None, *a: MSG.append(str(msg)))
def voyage():
    ext.m_SetAttribute("Etat", "Remat"); H.avancer(0.3); ext.m_SetAttribute("Etat", "Pose"); H.avancer(0.3)
def compteur(): return ext.m_GetAttribute("VoyagesConsecutifs")
ext.m_SetAttribute("Etat", "Pose"); H.avancer(1)
for _ in range(12): voyage()
verifier("C-117. 12 voyages (limite 15) : pas encore de surchauffe", compteur() == 12 and not ext.m_GetAttribute("Surchauffe"), (compteur(), ext.m_GetAttribute("Surchauffe")))
MSG.clear(); voyage()
verifier("C-117. 13e voyage : Surchauffe, et les pilotes sont prévenus (« plus que 2 voyage(s) »)",
         ext.m_GetAttribute("Surchauffe") is True and any("plus que 2 voyage(s)" in m for m in MSG), MSG)
MSG.clear(); voyage()
verifier("C-117. 14e voyage : pas de nouveau message (déjà prévenu)", compteur() == 14 and not any("Surchauffe" in m for m in MSG), MSG)
voyage(); H.avancer(2.5)
verifier("15e voyage : coupure comme avant (RedemarrageRequis, alimentation coupée)", ext.m_GetAttribute("RedemarrageRequis") is True and ext.m_GetAttribute("Alimentation") is False,
         (ext.m_GetAttribute("RedemarrageRequis"), ext.m_GetAttribute("Alimentation")))
H.avancer(130)
verifier("C-98. Pendant la coupure, le compteur ne refroidit pas", compteur() == 15)
prompts = [e for e in descendants(P["t1"]) if e.ClassName == "ProximityPrompt" and e.Name == "TardisRedemarrage"]
if prompts: declencher(prompts[0], "Triggered", j); H.avancer(0.5)
verifier("Redémarrage (E maintenu) : compteur à 0 et plus de surchauffe", prompts and compteur() == 0 and ext.m_GetAttribute("Surchauffe") is None, (len(prompts), compteur(), ext.m_GetAttribute("Surchauffe")))
for _ in range(5): voyage()
H.avancer(64)
verifier("C-98. Posée 1 min : un voyage de moins (5 → 4)", compteur() == 4, compteur())
H.avancer(120)
verifier("C-98. Encore 2 min : 4 → 2", compteur() == 2, compteur())
ext.m_SetAttribute("Etat", "Vol"); H.avancer(130)
verifier("C-98. En vol : pas de refroidissement", compteur() == 2, compteur())
ext.m_SetAttribute("Etat", "Pose"); ext.m_SetAttribute("VolLibre", True); H.avancer(130)
verifier("C-98. En vol libre : pas de refroidissement", compteur() == 2, compteur())
ext.m_SetAttribute("VolLibre", None)
for _ in range(11): voyage()
verifier("C-98. Remonté à 13 : en surchauffe", compteur() == 13 and ext.m_GetAttribute("Surchauffe") is True, compteur())
H.avancer(64)
verifier("C-98. Le refroidissement (13 → 12) éteint la surchauffe", compteur() == 12 and ext.m_GetAttribute("Surchauffe") is None, (compteur(), ext.m_GetAttribute("Surchauffe")))
# Rotor surmené (C-184) : clics sur le rotor de la salle
clics = [e for e in descendants(P["t1"]) if e.ClassName == "ClickDetector" and e.parent is not None and e.parent.Name == "Colonne"]
verifier("Le rotor de la salle est cliquable", len(clics) >= 1, len(clics))
def cliquer(n, ecart):
    for _ in range(n): declencher(clics[0], "MouseClick", j); H.avancer(ecart)
n0 = compteur(); MSG.clear()
cliquer(7, 0.6)
verifier("C-184. 7 clics sur le rotor en 4 s : rien", compteur() == n0 and not ext.m_GetAttribute("RotorSurmene"), compteur())
cliquer(1, 0.6)
verifier("C-184. 8e clic : rotor surmené, un voyage de plus au compteur, message aux pilotes",
         compteur() == n0 + 1 and ext.m_GetAttribute("RotorSurmene") is not None and any("Rotor surmené" in m for m in MSG), (compteur(), MSG))
n1 = compteur(); cliquer(8, 2)
verifier("C-184. Un clic toutes les 2 s : jamais surmené", compteur() == n1, compteur())
n2 = compteur(); cliquer(8, 0.1)
verifier("C-184. Les clics trop rapprochés (moins de 0,5 s) ne comptent qu'une fois", compteur() == n2, compteur())
ext.m_SetAttribute("Etat", "Vol"); H.avancer(1)
cliquer(8, 0.6); cliquer(8, 0.6)
verifier("C-184. En vol, le rotor surmené peut dépasser la limite sans coupure", compteur() >= 15 and not ext.m_GetAttribute("RedemarrageRequis"), compteur())
ext.m_SetAttribute("Etat", "Remat"); H.avancer(0.3); ext.m_SetAttribute("Etat", "Pose"); H.avancer(2.5)
verifier("C-184. … et coupe à l'atterrissage suivant", ext.m_GetAttribute("RedemarrageRequis") is True)
verifier("TardisSystemes et TardisExtras : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])


# ================================================================== 4. Le code
sysrc = lire("ServerScriptService/TardisSystemes.server.lua")
ext_src = lire("ServerScriptService/TardisExtras.server.lua")
verifier("TardisSystemes : un seul endroit compte les voyages et coupe (compterVoyage)", sysrc.count("voyagesConsecutifs += 1") == 1 and sysrc.count('signalerPanne("Coupure"') == 1)
verifier("TardisSystemes : les deux redémarrages effacent la surchauffe", sysrc.count('exterieur:SetAttribute("Surchauffe", nil) -- (V7.3.1)') == 2)
verifier("TardisExtras : le rotor surmené n'est qu'un attribut (TardisSystemes fait le reste)", 'exterieur:SetAttribute("RotorSurmene", workspace:GetServerTimeNow())' in ext_src)
verifier("Ambiance : pas de nouvelle boucle Heartbeat (deux, comme avant) et rien envoyé au serveur", ambiance.count("RunService.Heartbeat:Connect") == 2 and "FireServer" not in ambiance)
verifier("Decor : la chaleur n'existe que chez le joueur (partTemporaire, aucun Instance.new)", decor_src.count("Instance.new") == 0 and "FireServer" not in decor_src)

print("\n".join("  ✓ " + n for n in OK))
print("\n".join("  ✗ " + n for n in KO))
print(f"SURCHAUFFE ET VAPEUR (V7.3.1) : {len(OK)}/{len(OK) + len(KO)} vérifications réussies")
sys.exit(1 if KO else 0)
