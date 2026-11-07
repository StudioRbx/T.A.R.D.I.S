"""Simulations de la V7.4.2 (caméra extérieure de la lampe) : le vrai code, exécuté avec de faux objets Roblox et des
maths réelles (Vector3 et CFrame calculables, roblox.activer_maths).
  1. TardisConfig : réglages Config.CameraExterieure et calculs purs (champZoom, forceParasites, chanceBrouillage,
     cibleVisee, pointDeVueSuivant).
  2. TardisCamera (le script entier, image par image) : parasites à l'entrée et à la sortie (G-282), vue du dessus (G-278),
     zoom optique (G-285), vision de nuit (G-284), cadre de surveillance gardé dans les préférences (G-283), image
     brouillée quand le TARDIS est abîmé (G-289), clic sur un joueur pour le suivre (G-287), points de vue Porte et
     Dessous (G-288), touches réservées pendant la caméra puis rendues."""
import os, sys, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from monde import *
import roblox
from roblox import Couleur, Vec3, CF, activer_maths
import random
random.seed(742)
OK, KO = [], []
def verifier(nom, condition, detail=""):
    (OK if condition else KO).append(nom + ("" if condition else "  →  " + str(detail)))
def tache(f): lancer(Fonction("t", py=f))
def lire(chemin): return open(os.path.join(DEPOT, chemin), encoding="utf-8").read()
def vider_cache(): roblox.charger_module.__defaults__[0].clear()


class PieceLiee(Instance):
    """Pièce d'un Model qui suit le pivot du Model (comme dans Roblox, où PivotTo déplace les pièces)."""
    def __init__(s, classe, nom, parent, modele, decalage):
        super().__init__(classe, nom, parent); s.modele, s.decalage = modele, decalage
    def __lua_index__(s, k):
        if k in ("CFrame", "Position"):
            pivot = s.modele.m_GetPivot()
            cf = pivot.fois(s.decalage) if isinstance(pivot, CF) else s.decalage
            return cf if k == "CFrame" else Vec3(*cf.p)
        return super().__lua_index__(k)


# ================================================================== 1. TardisConfig
vider_cache()
I, G, game, joueur = monde(serveur=False)
activer_maths(G)
rs = game.m_FindFirstChild("ReplicatedStorage")
R = {}
tache(lambda: R.update(Config=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisConfig")])),
                       UI=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisUI")]))))
Config, UI = R["Config"], R["UI"]
f = lambda nom, *a: premier(appeler(Config.get(nom), list(a)))
verifier("Config.Version ≥ 7.4.2 (7.4.2 à sa sortie)", tuple(int(n) for n in Config.get("Version").split(".")) >= (7, 4, 2), Config.get("Version"))
CAM = Config.get("CameraExterieure")
verifier("Config.CameraExterieure : touches V, Z, N, C, P", CAM and (CAM.get("ToucheDessus"), CAM.get("ToucheZoom"), CAM.get("ToucheNuit"), CAM.get("ToucheCadre"), CAM.get("TouchePointDeVue")) == ("V", "Z", "N", "C", "P"))
verifier("Config.CameraExterieure : parasites 0,3 s, dessus à 60 studs (25 à 150), grossissements 1, 2, 4",
         (CAM.get("Parasites"), CAM.get("DureeParasites"), CAM.get("HauteurDessus"), CAM.get("HauteurDessusMin"), CAM.get("HauteurDessusMax"),
          [CAM.get("Grossissements").get(i) for i in (1, 2, 3)]) == (True, 0.3, 60, 25, 150, [1, 2, 4]))
verifier("Config.CameraExterieure : brouillage sous 50 PV (12 par minute au plus, 0,2 s), suivi à 14 studs, cadre coupé",
         (CAM.get("SeuilBrouillage"), CAM.get("BrouillagesParMinute"), CAM.get("DureeBrouillage"), CAM.get("DistanceSuivi"), CAM.get("CadreSurveillance")) == (50, 12, 0.2, 14, False))
verifier("champZoom : × 1 garde le champ, × 2 et × 4 le resserrent (70° → 38,6° → 19,9°)",
         abs(f("champZoom", 70, 1) - 70) < 1e-6 and abs(f("champZoom", 70, 2) - 38.58) < 0.05 and abs(f("champZoom", 70, 4) - 19.85) < 0.05, (f("champZoom", 70, 2), f("champZoom", 70, 4)))
verifier("champZoom : borné à 1..120°, grossissement < 1 ignoré", f("champZoom", 130, 1) == 120 and f("champZoom", 1, 4) == 1 and abs(f("champZoom", 70, 0.5) - 70) < 1e-6)
verifier("forceParasites : 1 au début, 0,75 à mi-chemin, 0 à la fin et hors du grésillement",
         f("forceParasites", 0, 0.3) == 1 and abs(f("forceParasites", 0.15, 0.3) - 0.75) < 1e-9 and f("forceParasites", 0.3, 0.3) == 0 and f("forceParasites", -1, 0.3) == 0 and f("forceParasites", 0.1, 0) == 0)
verifier("chanceBrouillage : 0 au-dessus de 50 PV, plus forte quand les PV baissent",
         f("chanceBrouillage", 50, 1, 50, 12) == 0 and f("chanceBrouillage", 80, 1, 50, 12) == 0
         and abs(f("chanceBrouillage", 0, 1, 50, 12) - 0.2) < 1e-9 and abs(f("chanceBrouillage", 25, 1, 50, 12) - 0.1) < 1e-9 and f("chanceBrouillage", None, 1, 50, 12) == 0)
def liste(*v):
    t = Table()
    for i, e in enumerate(v): t.set(i + 1, e)
    return t
o, d = Vec3(0, 0, 0), Vec3(0, 0, -1)
verifier("cibleVisee : la position la plus proche du rayon, devant", f("cibleVisee", o, d, liste(Vec3(3, 0, -50), Vec3(0.5, 0, -40), Vec3(0, 0, 30)), 4, 400) == 2)
verifier("cibleVisee : rien derrière, trop loin ou trop à côté (tolérance + 2 % par stud)",
         f("cibleVisee", o, d, liste(Vec3(0, 0, 30)), 4, 400) is None and f("cibleVisee", o, d, liste(Vec3(0, 0, -500)), 4, 400) is None
         and f("cibleVisee", o, d, liste(Vec3(6, 0, -50)), 4, 400) is None and f("cibleVisee", o, d, liste(Vec3(4.5, 0, -50)), 4, 400) == 1)
verifier("pointDeVueSuivant : Lampe → Porte → Lampe posé ; Lampe → Porte → Dessous → Lampe en vol",
         (f("pointDeVueSuivant", "Lampe", False), f("pointDeVueSuivant", "Porte", False), f("pointDeVueSuivant", "Porte", True), f("pointDeVueSuivant", "Dessous", True), f("pointDeVueSuivant", "?", False))
         == ("Porte", "Lampe", "Dessous", "Lampe", "Lampe"))

# ================================================================== 2. Client : TardisCamera, image par image
ws = game.m_FindFirstChild("Workspace")
RunService = game.m_FindFirstChild("RunService")
uis = game.m_FindFirstChild("UserInputService")
for nom in ("InputBegan", "InputEnded", "InputChanged", "TouchTap"): uis.extra[nom] = Signal("UserInputService." + nom)
uis.props["MouseBehavior"] = Valeur("Enum.MouseBehavior.Default")
cas = Instance("ContextActionService", "ContextActionService", game)
joueur.attrs["TardisPilote_TARDIS_1"] = True
gui = Instance("PlayerGui", "PlayerGui", joueur)
scripts = Instance("Folder", "PlayerScripts", joueur)
CONTROLES = {"actifs": True}
controles = Table({"Enable": Fonction("Enable", py=lambda _s: CONTROLES.__setitem__("actifs", True) or []),
                   "Disable": Fonction("Disable", py=lambda _s: CONTROLES.__setitem__("actifs", False) or [])})
module_joueur = Instance("ModuleScript", "PlayerModule", scripts)
module_joueur.extra["module"] = Table({"GetControls": Fonction("GetControls", py=lambda _s: controles)})
require_monde = G["require"]
G["require"] = Fonction("require", py=lambda obj: obj.extra["module"] if isinstance(obj, Instance) and "module" in obj.extra else premier(appeler(require_monde, [obj])))
camera = Instance("Camera", "Camera", ws)
camera.props.update({"CFrame": CF((0, 60, 20)), "FieldOfView": 70, "ViewportSize": Valeur("Vector2", [1280, 720]), "CameraType": Valeur("Enum.CameraType.Custom")})
ws.props["CurrentCamera"] = camera
ws.props["StreamingEnabled"] = False
Instance("RemoteEvent", "TardisCommande_TARDIS_1", rs)
dossier = Instance("Folder", "TARDIS", ws)
t1 = Instance("Folder", "TARDIS_1", dossier)
x = Instance("Model", "Cabine", Instance("Folder", "EXTERIEURE", t1))
interieur = Instance("Model", "Salle", Instance("Folder", "INTERIEURE", t1))
x.props["Pivot"] = CF((0, 50, 0))
x.props["ExtentsSize"] = Vec3(4, 9, 4)
x.props.update({"BoiteCFrame": CF((0, 54.5, 0)), "BoiteTaille": Vec3(4, 10, 4)})  # la cabine ne bouge pas ici : de 49,5 à 59,5
racine = PieceLiee("Part", "Racine", x, x, CF((0, 0, 0))); racine.props["Size"] = Vec3(4, 1, 4); x.props["PrimaryPart"] = racine
lampe = PieceLiee("Part", "Lampe", x, x, CF((0, 9, 0))); lampe.props["Size"] = Vec3(1, 1, 1)
console = Instance("Model", "Console", interieur)
bouton = Instance("Part", "BoutonCamera", console)
x.attrs.update({"Etat": "Pose", "DebutEtat": 1000.0, "Mode": "Normal"})

def image(dt=1 / 30, n=1):
    for _ in range(n):
        H.avancer(dt)
        for f_rendu in list(RunService.extra.get("rendu", {}).values()):
            if f_rendu is not None: tache(lambda f_rendu=f_rendu: appeler(f_rendu, [dt]))
def action(nom):
    f_, _t = cas.extra["actions"][nom]
    tache(lambda: appeler(f_, [nom, Valeur("Enum.UserInputState.Begin"), Table()]))
def clic(px, py):
    uis.extra["InputBegan"].declencher(Table({"UserInputType": Valeur("Enum.UserInputType.MouseButton1"), "KeyCode": Valeur("Enum.KeyCode.Unknown"),
                                              "Position": Vec3(px, py, 0)}), False)
def molette(z):
    uis.extra["InputChanged"].declencher(Table({"UserInputType": Valeur("Enum.UserInputType.MouseWheel"), "KeyCode": Valeur("Enum.KeyCode.Unknown"),
                                                "Position": Vec3(0, 0, z)}), False)
def touche(nom):
    uis.extra["InputBegan"].declencher(Table({"KeyCode": Valeur("Enum.KeyCode." + nom), "UserInputType": Valeur("Enum.UserInputType.Keyboard")}), False)

G["script"] = Instance("LocalScript", "TardisCamera", game.m_FindFirstChild("StarterPlayer"))
tache(lambda: I.executer(lire("StarterPlayer/StarterPlayerScripts/TardisCamera.client.lua"), "TardisCamera"))
verifier("TardisCamera se charge (avec ContextActionService)", not roblox.ERREURS, roblox.ERREURS[:3])
guiCam = gui.m_FindFirstChild("TardisCameraGui")
guiPar = gui.m_FindFirstChild("TardisCameraParasites")
cadreS = guiCam and guiCam.m_FindFirstChild("CadreSurveillance")
aide = [e for e in guiCam.enfants if e.ClassName == "TextLabel"][0]
verifier("Interface : écran de parasites (au-dessus de tout) et cadre de surveillance prêts, cachés",
         guiPar is not None and guiPar.props.get("Enabled") is False and guiPar.props.get("DisplayOrder") == 60 and cadreS is not None and cadreS.props.get("Visible") is False,
         (guiPar and guiPar.props.get("Enabled"), cadreS and cadreS.props.get("Visible")))
verifier("Aucune touche réservée tant que la caméra est fermée", not cas.extra.get("actions"))
prompt = bouton.m_FindFirstChildOfClass("ProximityPrompt")

# ------------------------------------------------------------------ entrée : parasites, touches (G-282)
prompt.extra.setdefault("Triggered", Signal("Triggered")).declencher(joueur); image()
verifier("Entrée : caméra ouverte (Scriptable), contrôles bloqués", guiCam.props.get("Enabled") is True and camera.props["CameraType"].nom == "Enum.CameraType.Scriptable" and not CONTROLES["actifs"])
verifier("G-282. Entrée : l'image grésille (parasites affichés)", guiPar.props.get("Enabled") is True)
fond = [e for e in guiPar.enfants if e.ClassName == "Frame"]
verifier("G-282. Parasites : un fond et 10 bandes qui bougent", len(fond) == 11, len(fond))
image(n=12)
verifier("G-282. … puis l'image se dégage (0,3 s)", guiPar.props.get("Enabled") is False)
acts = cas.extra.get("actions", {})
verifier("Touches de la caméra réservées : Dessus (V), Zoom (Z), Nuit (N), Cadre (C), Vue (P)",
         sorted(acts) == sorted(["TardisCameraDessus", "TardisCameraZoom", "TardisCameraNuit", "TardisCameraCadre", "TardisCameraPointDeVue"])
         and [t.nom for t in acts["TardisCameraDessus"][1]][:1] == ["Enum.KeyCode.V"] and [t.nom for t in acts["TardisCameraPointDeVue"][1]][:1] == ["Enum.KeyCode.P"],
         {k: [getattr(t, "nom", t) for t in v[1]] for k, v in acts.items()})
verifier("Touches à la manette sur la croix (DPad)", [getattr(t, "nom", t) for t in acts.get("TardisCameraZoom", (0, []))[1]] == ["Enum.KeyCode.Z", "Enum.KeyCode.DPadDown"],
         [getattr(t, "nom", t) for t in acts.get("TardisCameraZoom", (0, []))[1]])
verifier("Titres des boutons tactiles", cas.extra.get("titres", {}).get("TardisCameraNuit") == "Nuit")
verifier("Aide : la liste des touches et « CAM 1 · LAMPE »", "CAM 1 · LAMPE" in aide.props["Text"] and "V" in aide.props["Text"], aide.props["Text"])
def position_cam(): return Vec3(*camera.props["CFrame"].p)
def regard(): return camera.props["CFrame"].__lua_index__("LookVector")
sommet = Vec3(0, 59.5, 0)
verifier("Vue de la Lampe : au-dessus de la lampe (3 studs)", Vec3.arith("-", position_cam(), sommet).norme() < 3.1, position_cam())

# ------------------------------------------------------------------ G-278 vue du dessus
action("TardisCameraDessus"); image()
p, l = position_cam(), regard()
verifier("G-278. V : vue du dessus, 60 studs au-dessus de la lampe, droit vers le bas", abs(p.y - (59.5 + 60)) < 0.01 and abs(p.x) < 0.01 and l.y < -0.999, (p, l))
verifier("G-278. Aide « CAM 1 · DESSUS »", "CAM 1 · DESSUS" in aide.props["Text"], aide.props["Text"])
molette(-3); image()
verifier("G-278. Molette : la vue du dessus descend (5 studs par cran)", abs(position_cam().y - (59.5 + 45)) < 0.01, position_cam())
for _ in range(10): molette(-3)
image()
verifier("G-278. … jusqu'à 25 studs au plus bas", abs(position_cam().y - (59.5 + 25)) < 0.01, position_cam())
action("TardisCameraDessus"); image()
verifier("G-278. V à nouveau : retour à la vue de la lampe", position_cam().y < 59.5 + 4 and regard().y > -0.99)

# ------------------------------------------------------------------ G-285 zoom
action("TardisCameraZoom"); image()
verifier("G-285. Z : zoom × 2 (champ 38,6°)", abs(camera.props["FieldOfView"] - 38.58) < 0.05 and "Zoom × 2" in aide.props["Text"], (camera.props["FieldOfView"], aide.props["Text"]))
action("TardisCameraZoom"); image()
verifier("G-285. Z : zoom × 4 (champ 19,9°)", abs(camera.props["FieldOfView"] - 19.85) < 0.05)
camera.props["FieldOfView"] = 90; image()
verifier("G-285. Le zoom est gardé si un autre effet change le champ", abs(camera.props["FieldOfView"] - 19.85) < 0.05)
action("TardisCameraZoom"); image()
verifier("G-285. Z : retour à × 1 (70°)", abs(camera.props["FieldOfView"] - 70) < 1e-6 and "Zoom" not in aide.props["Text"].split("\n")[-1], (camera.props["FieldOfView"], aide.props["Text"]))

# ------------------------------------------------------------------ G-284 vision de nuit
action("TardisCameraNuit"); image()
nuit = camera.m_FindFirstChild("TardisVisionNuit")
verifier("G-284. N : vision de nuit (effet vert dans la caméra, local au joueur)", nuit is not None and nuit.ClassName == "ColorCorrectionEffect" and nuit.props.get("Enabled") is True
         and nuit.props.get("Saturation") == -1 and "Vision de nuit" in aide.props["Text"])
action("TardisCameraNuit"); image()
verifier("G-284. N à nouveau : coupée", nuit.props.get("Enabled") is False and "Vision de nuit" not in aide.props["Text"])

# ------------------------------------------------------------------ G-283 cadre de surveillance
action("TardisCameraCadre"); image()
heure = [e for e in cadreS.enfants if e.ClassName == "TextLabel"]
verifier("G-283. C : cadre de surveillance affiché, choix gardé dans les préférences", cadreS.props.get("Visible") is True and UI.get("prefs").get("cameraCadre") is True)
verifier("G-283. Cadre : heure, nom de la vue et « ● REC »", any(str(e.props.get("Text", "")).count(":") == 2 and len(str(e.props.get("Text"))) == 8 for e in heure)
         and any(e.props.get("Text") == "CAM 1 · LAMPE" for e in heure) and any(e.props.get("Text") == "● REC" for e in heure), [e.props.get("Text") for e in heure])
rec = [e for e in heure if e.props.get("Text") == "● REC"]
vus = set()
for _ in range(40):
    image()
    if rec: vus.add(rec[0].props.get("Visible"))
verifier("G-283. « ● REC » clignote", vus == {True, False}, vus)
lignes = [e for e in cadreS.enfants if e.ClassName == "Frame"]
verifier("G-283. Lignes de balayage (48)", len(lignes) == 48, len(lignes))

# ------------------------------------------------------------------ G-289 image brouillée par les dégâts
def compter_brouillages(secondes):
    n, avant = 0, guiPar.props.get("Enabled")
    for _ in range(int(secondes * 30)):
        image(); e = guiPar.props.get("Enabled")
        if e and not avant: n += 1
        avant = e
    return n
x.attrs["PointsDeVie"] = 80
b80 = compter_brouillages(30)
verifier("G-289. TARDIS en bon état (80 PV) : l'image ne se brouille jamais", b80 == 0, b80)
x.attrs["PointsDeVie"] = 5
b5 = compter_brouillages(60)
verifier("G-289. TARDIS très abîmé (5 PV) : l'image se brouille par moments (environ 11 fois par minute)", 4 <= b5 <= 20, b5)
x.attrs.pop("PointsDeVie", None)
image(n=15)

# ------------------------------------------------------------------ G-287 suivre un joueur
autre = Instance("Player", "Amy", game.m_FindFirstChild("Players")); autre.props.update({"UserId": 202, "DisplayName": "Amy"})
persoAmy = Instance("Model", "Amy", ws); racineAmy = Instance("Part", "HumanoidRootPart", persoAmy); autre.props["Character"] = persoAmy
cible = Vec3.arith("+", position_cam(), Vec3.arith("*", regard(), 40))
racineAmy.props["Position"] = cible; racineAmy.props["CFrame"] = CF(cible.t())
clic(100, 100); image()
verifier("G-287. Clic à côté du joueur : rien ne change", "Suivi" not in aide.props["Text"])
clic(640, 360); image(n=2)
ecart = Vec3.arith("-", position_cam(), cible)
vise = regard().dot(Vec3.arith("*", ecart, -1).unite())
verifier("G-287. Clic sur Amy : la caméra la suit, à 14 studs, et la regarde", abs(ecart.norme() - 14) < 0.05 and vise > 0.999, (ecart.norme(), vise))
verifier("G-287. Aide « Suivi de Amy », cadre « CAM · SUIVI AMY »", "Suivi de Amy" in aide.props["Text"] and any(e.props.get("Text") == "CAM · SUIVI AMY" for e in heure), aide.props["Text"])
a0 = math.atan2(ecart.x, ecart.z); image(n=30)
e2 = Vec3.arith("-", position_cam(), cible); a1 = math.atan2(e2.x, e2.z)
verifier("G-287. Elle tourne lentement autour d'Amy (12°/s)", abs(abs(math.degrees(a1 - a0)) - 12) < 0.5, math.degrees(a1 - a0))
cible = Vec3(20, 0, 20); racineAmy.props["Position"] = cible; image()
verifier("G-287. Amy bouge : la caméra la suit", abs(Vec3.arith("-", position_cam(), cible).norme() - 14) < 0.05)
molette(-5); image()
verifier("G-287. Molette : plus loin (24 studs)", abs(Vec3.arith("-", position_cam(), cible).norme() - 24) < 0.05, Vec3.arith("-", position_cam(), cible).norme())
action("TardisCameraDessus"); image()
verifier("G-287. Pendant le suivi, V ne change rien", "Suivi de Amy" in aide.props["Text"])
clic(640, 360); image()
verifier("G-287. Nouveau clic : Amy est relâchée, retour à la lampe", "Suivi" not in aide.props["Text"] and "CAM 1 · LAMPE" in aide.props["Text"] and position_cam().y > 59, aide.props["Text"])
image(n=10)
cible = Vec3.arith("+", position_cam(), Vec3.arith("*", regard(), 40)); racineAmy.props["Position"] = cible
clic(640, 360); image()
verifier("G-287. On la reprend…", "Suivi de Amy" in aide.props["Text"])
autre.set_parent(None); image()
verifier("G-287. … Amy quitte le jeu : relâchée toute seule", "Suivi" not in aide.props["Text"] and not roblox.ERREURS, (aide.props["Text"], roblox.ERREURS[:2]))
persoAmy.set_parent(None)
image(n=10)

# ------------------------------------------------------------------ G-288 points de vue
action("TardisCameraPointDeVue"); image()
p = position_cam()
verifier("G-288. P : au-dessus de la porte (devant la cabine, en haut), regard vers l'avant et un peu vers le bas",
         "CAM 2 · PORTE" in aide.props["Text"] and p.z < -2.9 and abs(p.y - 58.5) < 0.01 and abs(p.z + 3) < 0.01 and regard().z < -0.8 and regard().y < -0.2, (p, regard(), aide.props["Text"]))
action("TardisCameraPointDeVue"); image()
verifier("G-288. Posé : P revient à la lampe (pas de vue de dessous)", "CAM 1 · LAMPE" in aide.props["Text"])
x.attrs["VolLibre"] = 999
action("TardisCameraPointDeVue"); image(); action("TardisCameraPointDeVue"); image()
p = position_cam()
verifier("G-288. En vol libre : P, P : sous la cabine, regard vers le bas", "CAM 3 · DESSOUS" in aide.props["Text"] and abs(p.y - 47.5) < 0.01 and regard().y < -0.9, (p, regard(), aide.props["Text"]))
x.attrs.pop("VolLibre", None); image(n=2)
verifier("G-288. Fin du vol : retour tout seul à la lampe", "CAM 1 · LAMPE" in aide.props["Text"] and position_cam().y > 59, aide.props["Text"])
action("TardisCameraPointDeVue"); image(); action("TardisCameraDessus"); image()
verifier("G-288. Depuis la porte, V passe à la vue du dessus", "CAM 1 · DESSUS" in aide.props["Text"] and regard().y < -0.999)

# ------------------------------------------------------------------ sortie
action("TardisCameraZoom"); action("TardisCameraNuit"); image(n=20)
touche("X"); image()
verifier("Sortie (X) : caméra rendue, contrôles rendus", guiCam.props.get("Enabled") is False and camera.props["CameraType"].nom == "Enum.CameraType.Custom" and CONTROLES["actifs"])
verifier("G-282. Sortie : l'image grésille", guiPar.props.get("Enabled") is True)
verifier("Sortie : champ de vision rendu (70°), vision de nuit coupée, cadre caché", abs(camera.props["FieldOfView"] - 70) < 1e-6 and nuit.props.get("Enabled") is False and cadreS.props.get("Visible") is False,
         (camera.props["FieldOfView"], nuit.props.get("Enabled")))
verifier("Sortie : toutes les touches de la caméra sont rendues", not cas.extra.get("actions"), list(cas.extra.get("actions", {})))
image(n=12)
verifier("Sortie : parasites finis, aucune boucle de la caméra", guiPar.props.get("Enabled") is False and "TardisCamera" not in RunService.extra.get("rendu", {}))
prompt.extra["Triggered"].declencher(joueur); image()
verifier("Réouverture : vue de la lampe, zoom × 1, cadre gardé (préférence)", "CAM 1 · LAMPE" in aide.props["Text"] and abs(camera.props["FieldOfView"] - 70) < 1e-6 and cadreS.props.get("Visible") is True)
action("TardisCameraCadre"); image(); touche("X"); image(n=15)

# ------------------------------------------------------------------ sources
src = lire("StarterPlayer/StarterPlayerScripts/TardisCamera.client.lua")
verifier("Sans ContextActionService, les touches arrivent par UserInputService", "not ContextActionService then" in src and "for _, action in ACTIONS do" in src)
verifier("Une seule boucle par image (BindToRenderStep), parasites dans une petite boucle qui s'arrête", src.count("BindToRenderStep(") == 1 and "RenderStepped" not in src and "Heartbeat" not in src
         and "while majParasites() do task.wait(" in src)
verifier("Parasites plus doux avec « réduire les effets » ou « aucun flash »", "(UI.effetsReduits() or UI.sansFlash()) and 0.4" in src)
verifier("Aucune action réseau nouvelle", "FireServer" not in src)
verifier("Aucune erreur Lua", not roblox.ERREURS, roblox.ERREURS[:3])

print()
for n in OK: print("  ✓", n)
for n in KO: print("  ✗", n)
print(f"\nV7.4.2 : {len(OK)}/{len(OK) + len(KO)} vérifications réussies")
sys.exit(1 if KO else 0)
