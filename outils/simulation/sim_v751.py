"""Simulations de la V7.5.1 (régénération : caméra de cinéma) : le vrai code, exécuté avec de faux objets Roblox et des
maths réelles (Vector3 et CFrame calculables, roblox.activer_maths).
  1. TardisConfig : réglages Config.Regeneration.Cinema et calculs purs (trajetCinema, positionPlanFinal, poidsBordsRegen).
  2. Regeneration (le vrai code de cameraCinema et vignetteTemoin, extrait du module) : profondeur de champ (G-233),
     bandes noires (G-234), plan final sur le nouveau visage (G-235), trajet propre au style (G-236), braises devant
     l'objectif (G-264), touche pour passer la scène (G-238), bord doré pour les témoins (G-240).
  3. Sources : branchement dans la régénération."""
import os, sys, math
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
def proche(a, b, e=1e-6): return a is not None and b is not None and abs(a - b) <= e
def vec(v): return tuple(float(v.__lua_index__(k)) for k in "XYZ")
def dist(a, b): return math.sqrt(sum((x - y) ** 2 for x, y in zip(a, b)))

# ================================================================== 1. TardisConfig
vider_cache()
I, G, game, joueur = monde(serveur=False)
activer_maths(G)
rs = game.m_FindFirstChild("ReplicatedStorage")
R = {}
tache(lambda: R.update(Config=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisConfig")]))))
Config = R["Config"]
f = lambda nom, *a: premier(appeler(Config.get(nom), list(a)))
fs = lambda nom, *a: list(appeler(Config.get(nom), list(a)))
verifier("Config.Version ≥ 7.5.1 (7.5.1 à sa sortie)", tuple(int(n) for n in Config.get("Version").split(".")) >= (7, 5, 1), Config.get("Version"))
CIN = Config.get("Regeneration").get("Cinema")
verifier("Config.Regeneration.Cinema : passer avec Espace, profondeur de champ (zone nette 3, fond 0,6, avant 0,35)",
         CIN and (CIN.get("TouchePasser"), CIN.get("ProfondeurDeChamp"), CIN.get("ZoneNette"), CIN.get("FlouFond"), CIN.get("FlouAvant")) == ("Space", True, 3, 0.6, 0.35))
verifier("Config.Regeneration.Cinema : bandes noires 11 %, plan final 2 s à 3,2 studs, trajet par style",
         (CIN.get("BandesNoires"), CIN.get("HauteurBandes"), CIN.get("PlanFinal"), CIN.get("DureePlanFinal"), CIN.get("DistancePlanFinal"), CIN.get("TrajetParStyle")) == (True, 0.11, True, 2, 3.2, True))
verifier("Config.Regeneration.Cinema : braises (10 par seconde), vignette des témoins (force 0,55)",
         (CIN.get("Braises"), CIN.get("DebitBraises"), CIN.get("VignetteTemoins"), CIN.get("ForceVignette")) == (True, 10, True, 0.55))
def trajet(*a):
    t = f("trajetCinema", *a)
    return tuple(t.get(k) for k in ("angle", "rayon", "hauteur", "visee", "zoom"))
d1 = trajet(1, 0.5, 0, 0)
verifier("trajetCinema, style 1 (Tourbillon) : orbite large qui se resserre (9,5 → 7 studs), de plus en plus haute",
         proche(d1[0], 1.2) and proche(d1[1], 9.5) and proche(d1[2], 1.6) and d1[3] == 0 and d1[4] == 1
         and proche(trajet(1, 0.5, 1, 0)[1], 7) and proche(trajet(1, 0.5, 1, 0)[2], 3), d1)
d5 = trajet(5, 0.5, 1, 0)
verifier("trajetCinema, style 5 (Colonne) : caméra basse (−3,2) qui regarde la colonne monter (visée + 8), tour lent",
         proche(d5[0], 0.7) and proche(d5[1], 5.5) and proche(d5[2], -3.2) and proche(d5[3], 8) and proche(d5[4], 0.5), d5)
v_avant, v_apres = trajet(2, 0.5, 1, 0), trajet(2, 0.7, 1, 0)
verifier("trajetCinema, style 2 (Volcan) : proche avant l'explosion, puis recule (13 studs, plus haut), sans zoom",
         proche(v_avant[1], 5.5) and proche(v_avant[2], 1.4) and proche(v_apres[1], 13) and proche(v_apres[2], 4.9) and proche(v_apres[3], 1.5) and v_apres[4] == 0,
         (v_avant, v_apres))
mi = trajet(2, 0.59, 1, 0)
verifier("trajetCinema, style 2 : le recul est progressif (entre les deux à p = 0,59)", 5.5 < mi[1] < 13, mi)
d3 = trajet(3, 0.5, 1, 0)
verifier("trajetCinema, style 3 (Douce) : près, à hauteur des yeux, tour très lent", proche(d3[0], 0.45) and proche(d3[1], 3) and proche(d3[2], 0.5) and proche(d3[4], 0.6), d3)
verifier("trajetCinema : progression et intensité bornées (0..1), angle de départ ajouté",
         trajet(1, 2, 3, 0) == trajet(1, 1, 1, 0) and trajet(1, -1, -1, 0) == trajet(1, 0, 0, 0) and proche(trajet(1, 0, 0, 1.5)[0], 1.5))
pf = vec(f("positionPlanFinal", Vec3(0, 5, 0), Vec3(0, 0, -1), 3.2))
pf2 = vec(f("positionPlanFinal", Vec3(0, 5, 0), Vec3(0, 1, 0), 3.2))
verifier("positionPlanFinal : 3,2 studs devant le visage (à plat), un peu au-dessus ; regard vertical → devant par défaut",
         dist(pf, (0, 5.15, -3.2)) < 1e-6 and dist(pf2, (0, 5.15, -3.2)) < 1e-6, (pf, pf2))
pf3 = vec(f("positionPlanFinal", Vec3(0, 5, 0), Vec3(1, -1, 0), 2))
verifier("positionPlanFinal : un regard incliné est mis à plat", dist(pf3, (2, 5.15, 0)) < 1e-6, pf3)
def poids(x, y, z): return [round(v, 6) for v in fs("poidsBordsRegen", Vec3(x, y, z))]
verifier("poidsBordsRegen : à droite → bord droit plein, gauche vide", poids(1, 0, 0)[1] == 1 and poids(1, 0, 0)[0] == 0, poids(1, 0, 0))
verifier("poidsBordsRegen : droit devant → les quatre bords légers (0,25)", poids(0, 0, -1) == [0.25] * 4, poids(0, 0, -1))
verifier("poidsBordsRegen : derrière → tout le tour (0,5)", poids(0, 0, 1) == [0.5] * 4, poids(0, 0, 1))
p_hg = poids(-1, 1, 0)
verifier("poidsBordsRegen : en haut à gauche → bords gauche et haut, pas droite ni bas",
         p_hg[0] == p_hg[2] == 0.5 and p_hg[1] == 0 and p_hg[3] == 0, p_hg)
verifier("poidsBordsRegen : vecteur nul → 0,5 partout", poids(0, 0, 0) == [0.5] * 4)

# ================================================================== 2. Le vrai code de cameraCinema et vignetteTemoin
ws = game.m_FindFirstChild("Workspace")
RunService = game.m_FindFirstChild("RunService")
uis = game.m_FindFirstChild("UserInputService")
uis.extra["InputBegan"] = Signal("UserInputService.InputBegan")
cas = Instance("ContextActionService", "ContextActionService", game)
gui = Instance("PlayerGui", "PlayerGui", joueur)
camera = Instance("Camera", "Camera", ws)
camera.props.update({"CFrame": CF((0, 10, 20)), "FieldOfView": 70, "CameraType": Valeur("Enum.CameraType.Custom")})
ws.props["CurrentCamera"] = camera
MUR = {"distance": None, "rayons": 0}
def raycast(_ws, origine, direction, params=None):
    MUR["rayons"] += 1
    if MUR["distance"] is None: return [None]
    o, d = vec(origine), vec(direction)
    n = math.sqrt(sum(x * x for x in d)) or 1
    return [Table({"Position": Vec3(*(o[k] + d[k] / n * MUR["distance"] for k in range(3)))})]
ws.extra["Raycast"] = Fonction("Raycast", py=raycast)

perso = Instance("Model", "Voyageur", ws)
tete = Instance("Part", "Head", perso); tete.props.update({"CFrame": CF((0, 5, 0)), "Position": Vec3(0, 5, 0)})
racine = Instance("Part", "HumanoidRootPart", perso); racine.props.update({"CFrame": CF((0, 3, 0)), "Position": Vec3(0, 3, 0)})
hum = Instance("Humanoid", "Humanoid", perso)
joueur.props["Character"] = perso
CHAMP = {"fixe": False}
UIfaux = Table({"champFixe": Fonction("champFixe", py=lambda: [CHAMP["fixe"]])})
def animer_instant(obj, duree, props):
    for k, v in props.h.items(): obj.props[k] = v
    return []
creer_vrai = None
tache(lambda: R.update(UI=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisUI")]))))
creer_vrai = R["UI"].get("creer")

src = lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Regeneration.lua")
d_c = src.index("local CINEMA = "); f_c = src.index("local function surveillerRegeneration")
code = ("local Config, UI, camera, creer, animer, joueur, RunService, ContextActionService, UserInputService = ...\n"
        'local ETINCELLE = "rbxasset://textures/particles/sparkles_main.dds"\n' + src[d_c:f_c] +
        "\nreturn { cinema = cameraCinema, vignette = vignetteTemoin }\n")
def charger(avec_cas=True):
    tache(lambda: R.update(M=premier(I.executer(code, "regeneration_cinema",
          (Config, UIfaux, camera, creer_vrai, Fonction("animer", py=animer_instant), joueur, RunService, cas if avec_cas else None, uis)))))
    return R["M"]
M = charger()
verifier("Vrai code de Regeneration extrait (cameraCinema, vignetteTemoin), sans erreur", M is not None and not roblox.ERREURS, roblox.ERREURS[:3])

def ouvrir(style=1, reduit=False, module=None):
    o = Table({"personnage": perso, "tete": tete, "racine": racine, "style": style, "reduit": reduit})
    tache(lambda: R.update(S=premier(appeler((module or M).get("cinema"), [o]))))
    return R["S"]
def image(scene, p, i, t=1.0): tache(lambda: appeler(scene.get("image"), [p, i, t]))
def appel(scene, nom): tache(lambda: appeler(scene.get(nom), []))
def pos_cam(): return tuple(camera.props["CFrame"].p)
def regard_cam(): return vec(camera.props["CFrame"].__lua_index__("LookVector"))
def rendu(dt=1 / 30, n=1):
    for _ in range(n):
        H.avancer(dt); RunService.__lua_index__("RenderStepped").declencher(dt)

scene = ouvrir(1)
flou = camera.m_FindFirstChild("TardisRegenFlou")
ecran = gui.m_FindFirstChild("TardisRegenCinema")
verifier("Ouverture : caméra Scriptable", str(camera.props["CameraType"].nom).endswith("Scriptable"), camera.props["CameraType"].nom)
verifier("G-233 : profondeur de champ dans la caméra (zone nette 3, fond 0,6, avant 0,35)",
         flou is not None and flou.ClassName == "DepthOfFieldEffect" and (flou.props.get("InFocusRadius"), flou.props.get("FarIntensity"), flou.props.get("NearIntensity")) == (3, 0.6, 0.35))
bh, bb = ecran and ecran.m_FindFirstChild("BandeHaut"), ecran and ecran.m_FindFirstChild("BandeBas")
verifier("G-234 : bandes noires en haut et en bas, qui glissent jusqu'à 11 % de l'écran",
         bh is not None and bb is not None and list(bh.props["Size"].args) == [1, 0.11] and list(bb.props["Size"].args) == [1, 0.11]
         and ecran.props.get("DisplayOrder") == 40, (bh and bh.props.get("Size").args))
passer = ecran.m_FindFirstChild("Passer")
verifier("G-238 : aide « Espace : passer la scène » dans la bande du bas", passer is not None and passer.props.get("Text") == "Espace : passer la scène")
act = cas.extra.get("actions", {}).get("TardisRegenPasser")
verifier("G-238 : touche réservée (ContextActionService) : Espace et bouton B de la manette, titre « Passer »",
         act is not None and [t.nom for t in act[1]] == ["Enum.KeyCode.Space", "Enum.KeyCode.ButtonB"] and cas.extra.get("titres", {}).get("TardisRegenPasser") == "Passer",
         act and [t.nom for t in act[1]])
porte = ws.m_FindFirstChild("TardisRegenBraisesObjectif")
braises = porte and porte.m_FindFirstChild("Braises")
verifier("G-264 : braises devant l'objectif (pièce invisible, sans collision, sans requête), éteintes au départ",
         braises is not None and braises.ClassName == "ParticleEmitter" and porte.props.get("CanCollide") is False and porte.props.get("CanQuery") is False
         and porte.props.get("Transparency") == 1 and braises.props.get("Rate") == 0)

# Trajet du style 1 : position autour de la tête
image(scene, 0.2, 0.5, 0.0)
cible = (0, 5.3, 0)
a0 = math.atan2(-1, 0)
tr = trajet(1, 0.2, 0.5, a0)
attendu = (cible[0] + math.cos(tr[0]) * tr[1], cible[1] + tr[2], cible[2] + math.sin(tr[0]) * tr[1])
verifier("G-236 : style 1, la caméra suit trajetCinema autour de la tête (à la respiration près)", dist(pos_cam(), attendu) < 0.5, (pos_cam(), attendu))
lv = regard_cam(); vers = [cible[k] - pos_cam()[k] for k in range(3)]; nv = math.sqrt(sum(x * x for x in vers))
verifier("… et elle regarde la tête", sum(lv[k] * vers[k] / nv for k in range(3)) > 0.999, lv)
verifier("G-233 : mise au point à la distance de la tête", proche(flou.props.get("FocusDistance"), dist(pos_cam(), (0, 5, 0)), 1e-6), (flou.props.get("FocusDistance"), dist(pos_cam(), (0, 5, 0))))
pb = tuple(porte.props["CFrame"].p); dpb = dist(pb, pos_cam())
verifier("G-264 : les braises restent 2,5 studs devant l'objectif, leur débit suit l'intensité (5 à 50 %)",
         proche(dpb, 2.5, 1e-6) and braises.props.get("Rate") == 5, (dpb, braises.props.get("Rate")))
verifier("Champ de vision normal loin du changement (p = 0,2)", proche(camera.props["FieldOfView"], 70), camera.props["FieldOfView"])
image(scene, 0.55, 1)
verifier("Zoom au moment du changement (p = 0,55) : 70° → 56°", proche(camera.props["FieldOfView"], 56), camera.props["FieldOfView"])
camera.props["FieldOfView"] = 70; CHAMP["fixe"] = True
image(scene, 0.55, 1)
verifier("Champ de vision fixe (V7.4.1, G-280) : pas de zoom", proche(camera.props["FieldOfView"], 70), camera.props["FieldOfView"])
CHAMP["fixe"] = False
# mur derrière la caméra
MUR["distance"] = 3; n0 = MUR["rayons"]
image(scene, 0.2, 0.5, 0.0)
verifier("G-237 : un mur rapproche la caméra (rayon de la tête vers la caméra, 0,6 stud avant le mur)",
         MUR["rayons"] > n0 and abs(dist(pos_cam(), cible) - 2.4) < 0.4, dist(pos_cam(), cible))
MUR["distance"] = None
# fin : plan final
appel(scene, "fin")
verifier("G-264 : les braises s'éteignent au plan final", braises.props.get("Rate") == 0)
rendu(0.5)
pf_cam = pos_cam()
verifier("G-235 : plan final devant le nouveau visage (devant la tête, à 2,6–3,2 studs, un peu au-dessus)",
         pf_cam[2] < -2.4 and 2.5 < dist(pf_cam, (0, 5, 0)) < 3.25 and pf_cam[1] > 5, pf_cam)
lv = regard_cam()
verifier("… la caméra regarde le visage", lv[2] > 0.99, lv)
rendu(1.0); d_plus_tard = dist(pos_cam(), (0, 5, 0))
verifier("… et s'en approche doucement", d_plus_tard < dist(pf_cam, (0, 5, 0)), (d_plus_tard, dist(pf_cam, (0, 5, 0))))
pfige = pos_cam(); image(scene, 0.3, 1)
verifier("Pendant le plan final, l'orbite ne reprend pas la caméra", pos_cam() == pfige)
verifier("Pendant le plan final, la caméra n'est pas encore rendue", str(camera.props["CameraType"].nom).endswith("Scriptable"))
rendu(0.6)
verifier("Après 2 s : caméra rendue (Custom, sur le Humanoid, champ de vision d'origine)",
         str(camera.props["CameraType"].nom).endswith("Custom") and camera.props.get("CameraSubject") is hum and proche(camera.props["FieldOfView"], 70))
verifier("… flou et braises détruits, touche rendue", flou.parent is None and porte.parent is None and "TardisRegenPasser" not in cas.extra.get("actions", {}))
verifier("… les bandes se retirent", list(bh.props["Size"].args) == [1, 0])
H.avancer(0.5)
verifier("… et l'écran des bandes disparaît après 0,45 s", gui.m_FindFirstChild("TardisRegenCinema") is None)
appel(scene, "fin"); appel(scene, "rendre")
verifier("fin() et rendre() une seconde fois : sans effet ni erreur", not roblox.ERREURS, roblox.ERREURS[:3])

# Passer la scène (G-238)
camera.props["CameraType"] = Valeur("Enum.CameraType.Custom")
scene = ouvrir(1); image(scene, 0.3, 0.5)
f_, _t = cas.extra["actions"]["TardisRegenPasser"]
tache(lambda: appeler(f_, ["TardisRegenPasser", Valeur("Enum.UserInputState.Begin"), Table()]))
verifier("G-238 : Espace pendant la scène → caméra rendue tout de suite, flou et braises retirés",
         str(camera.props["CameraType"].nom).endswith("Custom") and camera.m_FindFirstChild("TardisRegenFlou") is None
         and ws.m_FindFirstChild("TardisRegenBraisesObjectif") is None and "TardisRegenPasser" not in cas.extra.get("actions", {}))
pav = pos_cam(); image(scene, 0.5, 1); appel(scene, "fin"); rendu(0.5)
verifier("… et la scène ne reprend plus la caméra (image, fin)", pos_cam() == pav and str(camera.props["CameraType"].nom).endswith("Custom"))
H.avancer(0.5)

# Styles 5, 2 et 3
scene = ouvrir(5); image(scene, 0.5, 1)
verifier("G-236 : style 5 (Colonne) : caméra sous la tête, qui regarde vers le haut", pos_cam()[1] < 5.3 - 2.5 and regard_cam()[1] > 0.3, (pos_cam(), regard_cam()))
appel(scene, "rendre"); H.avancer(0.5)
scene = ouvrir(2); image(scene, 0.9, 1)
verifier("G-236 : style 2 (Volcan) : la caméra a reculé (≈ 13,9 studs) et ne zoome pas", abs(dist(pos_cam(), cible) - math.hypot(13, 4.9)) < 0.5 and proche(camera.props["FieldOfView"], 70),
         (dist(pos_cam(), cible), camera.props["FieldOfView"]))
image(scene, 0.55, 1)
verifier("… pas de zoom au changement non plus (style 2)", proche(camera.props["FieldOfView"], 70), camera.props["FieldOfView"])
appel(scene, "rendre"); H.avancer(0.5)
scene = ouvrir(3); image(scene, 0.5, 1)
verifier("G-236 : style 3 (Douce) : tout près (≈ 3 studs)", abs(dist(pos_cam(), cible) - math.hypot(3, 0.5)) < 0.5, dist(pos_cam(), cible))
appel(scene, "rendre"); H.avancer(0.5)
CIN.set("TrajetParStyle", False)
scene = ouvrir(5); image(scene, 0.5, 1)
verifier("TrajetParStyle = false : le trajet du style 1 pour tous", pos_cam()[1] > 5.3, pos_cam())
appel(scene, "rendre"); H.avancer(0.5); CIN.set("TrajetParStyle", True)

# Réduire les effets : pas de braises ; plan final coupé ; réglages coupés
scene = ouvrir(1, reduit=True)
verifier("« Réduire les effets » : pas de braises devant l'objectif", ws.m_FindFirstChild("TardisRegenBraisesObjectif") is None)
image(scene, 0.3, 1)
verifier("… et la scène tourne quand même, sans erreur", not roblox.ERREURS, roblox.ERREURS[:3])
CIN.set("PlanFinal", False); appel(scene, "fin")
verifier("PlanFinal = false : la caméra est rendue tout de suite à la fin", str(camera.props["CameraType"].nom).endswith("Custom"))
CIN.set("PlanFinal", True); H.avancer(0.5)
for k in ("ProfondeurDeChamp", "BandesNoires", "Braises"): CIN.set(k, False)
scene = ouvrir(1); image(scene, 0.3, 1)
e2 = gui.m_FindFirstChild("TardisRegenCinema")
verifier("ProfondeurDeChamp, BandesNoires et Braises à false : ni flou, ni bandes, ni braises (l'aide reste)",
         camera.m_FindFirstChild("TardisRegenFlou") is None and list(e2.m_FindFirstChild("BandeHaut").props["Size"].args) == [1, 0]
         and ws.m_FindFirstChild("TardisRegenBraisesObjectif") is None and e2.m_FindFirstChild("Passer") is not None)
appel(scene, "rendre"); H.avancer(0.5)
for k in ("ProfondeurDeChamp", "BandesNoires", "Braises"): CIN.set(k, True)
# Tête disparue pendant la scène
scene = ouvrir(1); tete.set_parent(None)
appel(scene, "fin")
verifier("Tête disparue : la fin rend la caméra sans plan final", str(camera.props["CameraType"].nom).endswith("Custom"))
tete.set_parent(perso); H.avancer(0.5)

# Sans ContextActionService : UserInputService
M2 = charger(avec_cas=False)
scene = ouvrir(1, module=M2); image(scene, 0.3, 1)
verifier("Sans ContextActionService : rien de réservé", "TardisRegenPasser" not in cas.extra.get("actions", {}))
uis.extra["InputBegan"].declencher(Table({"KeyCode": Valeur("Enum.KeyCode.Space")}), False)
verifier("… et Espace passe quand même la scène (UserInputService)", str(camera.props["CameraType"].nom).endswith("Custom"))
H.avancer(0.5)

# Vignette des témoins (G-240)
camera.props["CFrame"] = CF((0, 0, 0))
tache(lambda: R.update(V=premier(appeler(M.get("vignette"), [Couleur(1, 0.8, 0.3)]))))
V = R["V"]; ev = V.get("ecran")
verifier("G-240 : écran de vignette (quatre bords dorés), caché au départ",
         ev is not None and ev.props.get("Enabled") is False and [e.Name for e in ev.enfants] == ["Gauche", "Droite", "Haut", "Bas"] and ev.props.get("DisplayOrder") == 35)
def transp(nom): return list(ev.m_FindFirstChild(nom).m_FindFirstChildOfClass("UIGradient").props["Transparency"].args)
tache(lambda: appeler(V.get("maj"), [Vec3(10, 0, 0), 1]))
verifier("G-240 : régénération à droite → l'or vient du bord droit (45 % de transparence), pas du gauche",
         ev.props.get("Enabled") is True and proche(transp("Droite")[0], 0.45) and proche(transp("Gauche")[0], 1), (transp("Droite"), transp("Gauche")))
tache(lambda: appeler(V.get("maj"), [Vec3(10, 0, 0), 0.5]))
verifier("G-240 : plus faible quand la régénération est moins proche", proche(transp("Droite")[0], 1 - 0.5 * 0.55), transp("Droite"))
tache(lambda: appeler(V.get("maj"), [Vec3(0, 0, 10), 1]))
verifier("G-240 : régénération derrière → tout le tour de l'écran", all(proche(transp(n)[0], 1 - 0.5 * 0.55) for n in ("Gauche", "Droite", "Haut", "Bas")))
tache(lambda: appeler(V.get("maj"), [Vec3(10, 0, 0), 0]))
verifier("G-240 : force nulle → vignette cachée", ev.props.get("Enabled") is False)

# ================================================================== 3. Sources
verifier("Regeneration : la caméra passe par la scène de cinéma (image à chaque image, fin à la fin)",
         "if scene then scene.image(p, i, t) end" in src and "if scene then scene.fin() end" in src and "cameraCinema({ personnage = personnage" in src)
verifier("Regeneration : témoins avec vignette, teinte plus légère (0,08 au lieu de 0,35)",
         "(temoin and 0.08 or 0.35) * proche" in src and "vignette.maj(racine.Position, proche)" in src and "garder(vignette.ecran)" in src)
verifier("Regeneration : l'orbite ne traverse toujours pas les murs (G-237)",
         "workspace:Raycast(cible, decalage, paramsCamera)" in src and "paramsCamera.RespectCanCollide = true" in src)
verifier("Aucune action réseau nouvelle", src.count("FireServer") == lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Regeneration.lua").count("FireServer") and "FireServer" not in src[d_c:f_c])
verifier("Aucune erreur Lua", not roblox.ERREURS, roblox.ERREURS[:3])

print()
for n in OK: print("  ✓", n)
for n in KO: print("  ✗", n)
print(f"\nV7.5.1 : {len(OK)}/{len(OK) + len(KO)} vérifications réussies")
sys.exit(1 if KO else 0)
