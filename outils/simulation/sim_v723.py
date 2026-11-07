"""Simulations de la V7.2.3 (sur l'eau et au ras de l'eau) : le vrai code, exécuté avec de faux objets Roblox et des maths réelles.
  1. TardisConfig : réglages (V7.2.3) et fonctions sans effet de bord (caseEau, dansLEau, surfaceEau, remonteeEau,
     vitesseDansEau, nettoyageSalete), avec un faux Terrain (ReadVoxels).
  2. TardisServeur : la remontée à la surface est faite dans atterrir, avant le test des murs (C-62).
  3. TardisSystemes (le vrai Script serveur, banc d'essai) : l'eau et la pluie nettoient la cabine posée (C-179).
  4. TardisEffets (le script entier, image par image) : rides autour de la cabine qui flotte (G-25), vapeur pendant une
     remat au-dessus de l'eau (G-27), gerbe et anneau d'écume à l'arrivée sur l'eau (G-26).
  5. TardisVolLibre (le script entier, image par image) : vitesse réduite dans l'eau (C-77), annonce, gerbe du plongeon (G-26),
     sillage au ras de l'eau (G-35)."""
import os, sys, re, math
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


def faux_terrain(case):
    """Terrain dont ReadVoxels rend (matériau, occupation) de la case donnée par case(x, y, z) (bas de la case)."""
    t = Instance("Terrain", "Terrain")
    def lire_voxels(_s, region, _res):
        bas = roblox.en_vec3(region.args[0])
        mat, occ = case(bas.x, bas.y, bas.z)
        return [Table({1: Table({1: Table({1: Valeur("Enum.Material." + mat)})})}), Table({1: Table({1: Table({1: occ})})})]
    t.extra["ReadVoxels"] = Fonction("ReadVoxels", py=lire_voxels)
    return t


# ================================================================== 1. TardisConfig
vider_cache()
I, G, game, joueur = monde(serveur=False)
activer_maths(G)
rs = game.m_FindFirstChild("ReplicatedStorage")
R = {}
tache(lambda: R.update(Config=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisConfig")]))))
Config = R["Config"]
EF, VL, SY = Config.get("Effets"), Config.get("VolLibre"), Config.get("Systemes")
def f(nom, *a):
    res = {}
    tache(lambda: res.update(v=appeler(Config.get(nom), list(a))))
    return res.get("v") or [None]
verifier("Config.Version ≥ 7.2.3 (7.2.3 à sa sortie)", tuple(int(n) for n in Config.get("Version").split(".")) >= (7, 2, 3), Config.get("Version"))
attendus = {"RidesEau": 1.6, "GerbeEau": True, "VapeurEau": True, "SillageEau": 12}
verifier("Config.Effets : les 4 réglages de l'eau", all(EF.get(k) == v for k, v in attendus.items()), {k: EF.get(k) for k in attendus})
verifier("Config.VolLibre.FacteurEau = 0,5", VL.get("FacteurEau") == 0.5, VL.get("FacteurEau"))
verifier("Config.Systemes : NettoyageEau 4, NettoyagePluie 3, AttributPluie « Pluie », RemonteeEau 400",
         (SY.get("NettoyageEau"), SY.get("NettoyagePluie"), SY.get("AttributPluie"), SY.get("RemonteeEau")) == (4, 3, "Pluie", 400))
cfgsrc = lire("ReplicatedStorage/TardisConfig.lua")
i = cfgsrc.index("-- Sur l'eau (V7.2.3)")
bloc = [l for l in cfgsrc[i:cfgsrc.index("\n}", i)].splitlines() if re.match(r"\s*\w+ = ", l)]
verifier("Chaque réglage d'effet est commenté « (V7.2.3, G-…) »", len(bloc) == 4 and all("(V7.2.3, G-" in l for l in bloc), bloc)
verifier("Les réglages de la V7.2.2 restent là", all(EF.get(k) is not None for k in ("MarqueSelonMode", "GivreSol", "PoussierePlafond")))

def eau_ou_air(x_, y, z):
    if abs(x_) >= 100: return ("Grass", 1)
    if 0 <= y < 20: return ("Water", 1)
    if y == 20: return ("Water", 0.25)
    return ("Air", 0)
terrain = faux_terrain(eau_ou_air)
r = f("caseEau", Vec3(1, 2, 1), terrain)
verifier("caseEau : case d'eau pleine (bas à 0)", r[:3] == [True, 1, 0], r)
r = f("caseEau", Vec3(1, 21, 1), terrain)
verifier("caseEau : case de surface (occupation 0,25, bas à 20)", r[:3] == [True, 0.25, 20], r)
r = f("caseEau", Vec3(150, 2, 1), terrain)
verifier("caseEau : pas d'eau hors du lac", r[0] is False, r)
verifier("caseEau sans Terrain ou sans position : (false, 0, 0)", f("caseEau", Vec3(1, 2, 1), None)[:3] == [False, 0, 0] and f("caseEau", "x", terrain)[:3] == [False, 0, 0])
bris = Instance("Terrain", "Terrain"); bris.extra["ReadVoxels"] = Fonction("ReadVoxels", py=lambda *a: (_ for _ in ()).throw(__import__("luau").LuaError("ReadVoxels a échoué")))
nE = len(roblox.ERREURS)
verifier("caseEau : une erreur de ReadVoxels est rattrapée (pcall)", f("caseEau", Vec3(1, 2, 1), bris)[0] is False and len(roblox.ERREURS) == nE)
verifier("dansLEau : sous la surface, oui ; juste au-dessus (21,5), non", f("dansLEau", Vec3(1, 20.9, 1), terrain)[0] is True and f("dansLEau", Vec3(1, 21.5, 1), terrain)[0] is False)
verifier("dansLEau : dans l'air, non", f("dansLEau", Vec3(1, 40, 1), terrain)[0] is False)
r = f("surfaceEau", Vec3(1, 2, 1), terrain)[0]
verifier("surfaceEau depuis le fond : 21", r is not None and abs(r - 21) < 1e-9, r)
verifier("surfaceEau : nil hors de l'eau", f("surfaceEau", Vec3(1, 40, 1), terrain)[0] is None)
verifier("surfaceEau : nil si la surface est plus haut que « maxi » (10)", f("surfaceEau", Vec3(1, 2, 1), terrain, 10)[0] is None)
r = f("remonteeEau", CF((1, 2.5, 1)), 0.5, terrain)[0]
verifier("C-62. remonteeEau : la Racine (demi-hauteur 0,5) remonte, sa base à la surface (y = 21,5)", isinstance(r, CF) and abs(r.p[1] - 21.5) < 1e-9 and r.p[0] == 1, r)
verifier("C-62. remonteeEau : nil si la cible n'est pas dans l'eau", f("remonteeEau", CF((1, 30, 1)), 0.5, terrain)[0] is None)
verifier("C-62. remonteeEau : nil hors du lac", f("remonteeEau", CF((150, 2.5, 1)), 0.5, terrain)[0] is None)
verifier("C-62. remonteeEau : nil sans CFrame", f("remonteeEau", Vec3(1, 2, 1), 0.5, terrain)[0] is None)
SY.set("RemonteeEau", 0)
verifier("C-62. RemonteeEau à 0 : jamais", f("remonteeEau", CF((1, 2.5, 1)), 0.5, terrain)[0] is None)
SY.set("RemonteeEau", 10)
verifier("C-62. Eau plus profonde que RemonteeEau (10) : pas de remontée", f("remonteeEau", CF((1, 2.5, 1)), 0.5, terrain)[0] is None)
SY.set("RemonteeEau", 400)
niveaux = Table({1: 25, 2: 50, 3: 90, 4: 150})
verifier("C-77. vitesseDansEau : TURBO (4) ramené à l'avant-dernier niveau × 0,5 = 45", f("vitesseDansEau", niveaux, 4)[0] == 45, f("vitesseDansEau", niveaux, 4))
verifier("C-77. vitesseDansEau : NORMAL (2) = 25", f("vitesseDansEau", niveaux, 2)[0] == 25)
verifier("C-77. vitesseDansEau : niveau absent = le premier (12,5)", f("vitesseDansEau", niveaux, None)[0] == 12.5)
verifier("C-77. vitesseDansEau : sans niveaux, nil", f("vitesseDansEau", Table({}), 2)[0] is None and f("vitesseDansEau", None, 2)[0] is None)
VL.set("FacteurEau", 0)
verifier("C-77. FacteurEau à 0 : aucun ralentissement (nil)", f("vitesseDansEau", niveaux, 2)[0] is None)
VL.set("FacteurEau", 0.5)
r = f("nettoyageSalete", 50, True, False, 10, 0)
verifier("C-179. nettoyageSalete sur l'eau, 10 s : rien d'enlevé encore, reste 0,667", r[0] == 50 and abs(r[1] - 4 * 10 / 60) < 1e-9, r)
r = f("nettoyageSalete", 50, True, False, 10, 0.5)
verifier("C-179. … le reste s'accumule : 1 % enlevé, reste 0,167", r[0] == 49 and abs(r[1] - (0.5 + 4 / 6 - 1)) < 1e-9, r)
r = f("nettoyageSalete", 50, True, True, 60, 0)
verifier("C-179. Eau et pluie, une minute : 7 % enlevés", r[0] == 43 and abs(r[1]) < 1e-9, r)
r = f("nettoyageSalete", 50, False, True, 60, 0)
verifier("C-179. Pluie seule, une minute : 3 %", r[0] == 47, r)
verifier("C-179. Ni eau ni pluie : rien", f("nettoyageSalete", 50, False, False, 60, 0)[0] == 50)
verifier("C-179. Jamais sous 0", f("nettoyageSalete", 2, True, True, 600, 0)[0] == 0)
verifier("C-179. Valeur toujours entière", all(float(f("nettoyageSalete", 50, True, True, s, 0)[0]).is_integer() for s in (7, 13, 29, 41)))


# ================================================================== 2. TardisServeur : remontée avant le test des murs
serv = lire("ServerScriptService/TardisServeur/init.server.lua")
a = serv.index("local function atterrir")
corps_atterrir = serv[a:serv.index("\nend", a)]
iR, iC = corps_atterrir.find("Config.remonteeEau"), corps_atterrir.find("enCollision")
verifier("C-62. atterrir : remonteeEau appelé, avant le test des murs (enCollision)", 0 < iR < iC, (iR, iC))
verifier("C-62. atterrir : appel protégé (pcall) et Terrain de workspace", "pcall(Config.remonteeEau, cible" in corps_atterrir and 'workspace:FindFirstChildOfClass("Terrain")' in corps_atterrir)


# ================================================================== 3. TardisSystemes : l'eau et la pluie nettoient (C-179)
from banc import place, demarrer_serveur
P = place()
P["ws"].extra["GetPartBoundsInRadius"] = Fonction("GetPartBoundsInRadius", py=lambda *a: Table({}))
_, err = demarrer_serveur(P, duree=20)
verifier("TardisServeur et TardisSystemes démarrent (banc d'essai)", not err, err[:3])
ext, wsP = P["ext"], P["ws"]
ext.m_SetAttribute("Etat", "Pose")
def minute(salete, surEau=None, pluie=None, etat_="Pose", duree=60):
    ext.m_SetAttribute("SurEau", surEau); wsP.m_SetAttribute("Pluie", pluie); ext.m_SetAttribute("Etat", etat_)
    ext.m_SetAttribute("Salete", salete)
    H.avancer(duree)
    return ext.m_GetAttribute("Salete")
H.avancer(15)  # au milieu de deux passages de la boucle (toutes les 10 s)
verifier("C-179. Posée sur l'eau, une minute : −4 %", minute(50, surEau=True) == 46, ext.m_GetAttribute("Salete"))
verifier("C-179. Sous la pluie (workspace « Pluie »), une minute : −3 %", minute(50, pluie=True) == 47, ext.m_GetAttribute("Salete"))
verifier("C-179. Sur l'eau et sous la pluie : −7 %", minute(50, surEau=True, pluie=True) == 43, ext.m_GetAttribute("Salete"))
verifier("C-179. Au sec : rien", minute(50) == 50)
verifier("C-179. En vol : rien, même sous la pluie", minute(50, pluie=True, etat_="Vol") == 50)
ext.m_SetAttribute("Etat", "Pose")
verifier("C-179. Propre : reste à 0", minute(0, surEau=True, pluie=True) == 0)
verifier("C-179. Valeur entière", float(minute(30, surEau=True, duree=95)).is_integer())
wsP.m_SetAttribute("Pluie", None); ext.m_SetAttribute("SurEau", None)
verifier("TardisSystemes : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])


# ================================================================== 4. TardisEffets : rides, vapeur, gerbe d'arrivée
vider_cache()
I, G, game, joueur = monde(serveur=False)
activer_maths(G)
rs = game.m_FindFirstChild("ReplicatedStorage")
ws = game.m_FindFirstChild("Workspace")
RunService = game.m_FindFirstChild("RunService")
Lighting = game.m_FindFirstChild("Lighting")
Lighting.props.update({"ClockTime": 12, "ExposureCompensation": 0, "Ambient": Couleur(0.5, 0.5, 0.5), "OutdoorAmbient": Couleur(0.5, 0.5, 0.5)})
Instance("PlayerGui", "PlayerGui", joueur)
camera = Instance("Camera", "Camera", ws)
camera.props.update({"CFrame": CF((0, 10, 30)), "FieldOfView": 70, "ViewportSize": Valeur("Vector2", [1280, 720])})
ws.props["CurrentCamera"] = camera
ws.props["Terrain"] = Instance("Terrain", "Terrain", ws)
ws.props["StreamingEnabled"] = False
dossier = Instance("Folder", "TARDIS", ws)
t1 = Instance("Folder", "TARDIS_1", dossier)
x = Instance("Model", "Cabine", Instance("Folder", "EXTERIEURE", t1))
interieur = Instance("Model", "Salle", Instance("Folder", "INTERIEURE", t1))
BASE = CF((0, 0.5, 0))
x.props["Pivot"] = BASE
x.props["ExtentsSize"] = Vec3(4, 9, 4)
racine = PieceLiee("Part", "Racine", x, x, CF((0, 0, 0))); racine.props.update({"Size": Vec3(4, 1, 4), "Transparency": 1}); x.props["PrimaryPart"] = racine
corps = PieceLiee("Part", "Corps", x, x, CF((0, 4, 0))); corps.props["Size"] = Vec3(4, 8, 4)
lampe = PieceLiee("Part", "Lampe", x, x, CF((0, 9, 0))); lampe.props["Size"] = Vec3(1, 1, 1)
Instance("PointLight", "PointLight", lampe).props.update({"Brightness": 2, "Range": 10, "Color": Couleur(1, 1, 1)})
Instance("ObjectValue", "TracteurCible", x).props["Value"] = None
enseigne = Instance("SurfaceGui", "Enseigne", corps); enseigne.props["Brightness"] = 1
Instance("TextLabel", "Texte", enseigne).props.update({"Text": "POLICE BOX", "TextColor3": Couleur(1, 1, 1), "TextTransparency": 0, "TextStrokeTransparency": 1})
rotor = Instance("Part", "Rotor", interieur); interieur.props["PrimaryPart"] = rotor; rotor.props["Pivot"] = CF((0, 1000, 0))
Instance("PointLight", "Lumiere", Instance("Part", "Plafond", interieur)).props["Color"] = Couleur(1, 1, 1)
x.attrs.update({"Etat": "Pose", "DebutEtat": 1000.0, "Mode": "Normal"})
SOL = {"mat": "Water"}
solPart = Instance("Part", "Sol"); solPart.props["Color"] = Couleur(0.5, 0.5, 0.5)
def raycast(_w, origine, direction, params=None):
    o, d = roblox.en_vec3(origine), roblox.en_vec3(direction)
    if o is None or d is None or d.y >= 0 or o.y + d.y > 0: return None
    return Table({"Position": Vec3(o.x, 0, o.z), "Normal": Vec3(0, 1, 0), "Instance": ws.props["Terrain"] if SOL["mat"] == "Water" else solPart,
                  "Material": Valeur("Enum.Material." + SOL["mat"])})
ws.extra["Raycast"] = Fonction("Raycast", py=raycast)
def image(dt=1 / 30, n=1):
    for _ in range(n):
        H.avancer(dt)
        for nom in ("RenderStepped", "Heartbeat"):
            sig = RunService.extra.get(nom)
            if sig: sig.declencher(dt)
def maintenant(): return 1000.0 + H.t
def etat(nom, mode="Normal"):
    x.m_SetAttribute("Mode", mode); x.m_SetAttribute("DebutEtat", maintenant()); x.m_SetAttribute("Etat", nom)
def dans_ws(prefixe): return [e for e in ws.enfants if e.Name.startswith(prefixe)]

G["script"] = Instance("LocalScript", "TardisEffets", game.m_FindFirstChild("StarterPlayer"))
tache(lambda: I.executer(lire("StarterPlayer/StarterPlayerScripts/TardisEffets.client.lua"), "TardisEffets"))
verifier("TardisEffets se charge (avec les maths réelles)", not roblox.ERREURS, roblox.ERREURS[:3])
image(n=30)

# G-25 : rides autour de la cabine qui flotte
def ondes(): return len(dans_ws("TardisOnde"))
image(n=150)
verifier("G-25. Posée au sec : aucune ride", ondes() == 0, ondes())
x.m_SetAttribute("BaseEau", BASE); x.m_SetAttribute("SurEau", True)
vues = set()
for _ in range(450):  # 15 s, environ trois balancements (5,2 s)
    image()
    for o in dans_ws("TardisOnde"): vues.add(id(o))
verifier("G-25. Elle flotte : des rides partent de la base (une au plus bas de chaque balancement : 2 à 4 en 15 s)", 2 <= len(vues) <= 4, len(vues))
x.m_SetAttribute("Camouflage", True)
vues2 = set(); image(n=60)
for _ in range(240):
    image()
    for o in dans_ws("TardisOnde"):
        if id(o) not in vues: vues2.add(id(o))
verifier("G-25. Camouflée : plus de rides", len(vues2) == 0, len(vues2))
x.m_SetAttribute("Camouflage", None)
EF2 = R2 = None
res = {}
tache(lambda: res.update(c=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisConfig")]))))
EF2 = res["c"].get("Effets")
EF2.set("RidesEau", 0)
image(n=90); vues3 = set()
for _ in range(240):
    image()
    for o in dans_ws("TardisOnde"):
        if id(o) not in vues: vues3.add(id(o))
verifier("G-25. RidesEau à 0 : jamais", len(vues3) == 0, len(vues3))
EF2.set("RidesEau", 1.6)
x.m_SetAttribute("SurEau", None); x.m_SetAttribute("BaseEau", None)
image(n=90)

# G-27 : vapeur pendant une remat au-dessus de l'eau
etat("Remat")
image(n=120)  # 4 s de remat
vap = dans_ws("TardisVapeurEau")
emis = sum(e.emis for v in vap for e in v.enfants if e.ClassName == "ParticleEmitter")
verifier("G-27. Remat au-dessus de l'eau : une vapeur (une seule) qui monte à chaque souffle", len(vap) == 1 and emis >= 3, (len(vap), emis))
# G-26 : gerbe et écume à l'arrivée
etat("Pose")
image(n=2)
gerbe, ecume = dans_ws("TardisGerbeEau"), dans_ws("TardisEcume")
gouttes = sum(e.emis for g in gerbe for e in g.enfants if e.ClassName == "ParticleEmitter")
verifier("G-26. Arrivée sur l'eau : grande gerbe (60 gouttes) et anneau d'écume", len(gerbe) == 1 and gouttes == 60 and len(ecume) == 1, (len(gerbe), gouttes, len(ecume)))
image(n=150)
verifier("G-27. La vapeur se dissipe après l'arrivée (4 s)", not dans_ws("TardisVapeurEau"), len(dans_ws("TardisVapeurEau")))
verifier("G-26. Gerbe et écume nettoyées", not dans_ws("TardisGerbeEau") and not dans_ws("TardisEcume"))
# Au sec : ni vapeur, ni gerbe d'eau
SOL["mat"] = "Grass"
etat("Remat"); image(n=120); etat("Pose"); image(n=2)
verifier("G-26/27. Remat au sec : ni vapeur ni gerbe d'eau", not dans_ws("TardisVapeurEau") and not dans_ws("TardisGerbeEau"))
image(n=150)
# Réglages coupés
SOL["mat"] = "Water"; EF2.set("VapeurEau", False); EF2.set("GerbeEau", False)
etat("Remat"); image(n=120); etat("Pose"); image(n=2)
verifier("G-26/27. VapeurEau et GerbeEau à false : rien", not dans_ws("TardisVapeurEau") and not dans_ws("TardisGerbeEau"))
EF2.set("VapeurEau", True); EF2.set("GerbeEau", True)
image(n=150)
verifier("TardisEffets : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])


# ================================================================== 5. TardisVolLibre : dans l'eau et au ras de l'eau
vider_cache()
I, G, game, joueur = monde(serveur=False)
activer_maths(G)
rs = game.m_FindFirstChild("ReplicatedStorage")
ws = game.m_FindFirstChild("Workspace")
RunService = game.m_FindFirstChild("RunService")
uis = game.m_FindFirstChild("UserInputService")
for nom in ("InputBegan", "InputEnded", "InputChanged"): uis.extra[nom] = Signal("UserInputService." + nom)
uis.props["MouseBehavior"] = Valeur("Enum.MouseBehavior.Default")
joueur.attrs["TardisPilote_TARDIS_1"] = True
gui = Instance("PlayerGui", "PlayerGui", joueur)
scripts = Instance("Folder", "PlayerScripts", joueur)
MOUVEMENT = {"v": Vec3(0, 0, 0)}
controles = Table({"GetMoveVector": Fonction("GetMoveVector", py=lambda _s: MOUVEMENT["v"]),
                   "Enable": Fonction("Enable", py=lambda _s: []), "Disable": Fonction("Disable", py=lambda _s: [])})
module_joueur = Instance("ModuleScript", "PlayerModule", scripts)
module_joueur.extra["module"] = Table({"GetControls": Fonction("GetControls", py=lambda _s: controles)})
require_monde = G["require"]
G["require"] = Fonction("require", py=lambda obj: obj.extra["module"] if isinstance(obj, Instance) and "module" in obj.extra else premier(appeler(require_monde, [obj])))
camera = Instance("Camera", "Camera", ws)
camera.props.update({"CFrame": CF((0, 60, 20)), "FieldOfView": 70, "ViewportSize": Valeur("Vector2", [1280, 720]), "CameraType": Valeur("Enum.CameraType.Custom")})
ws.props["CurrentCamera"] = camera
ws.props["StreamingEnabled"] = False
EAU = {"actif": True}
def lac(x_, y, z):  # un lac profond (surface à 64) pour z < -100
    return ("Water", 1) if EAU["actif"] and z < -100 and y < 64 else ("Air", 0)
for _vieux in [e for e in ws.enfants if e.ClassName == "Terrain"]: _vieux.set_parent(None)
ws.props["Terrain"] = faux_terrain(lac)
ws.props["Terrain"].set_parent(ws)
remote = Instance("RemoteEvent", "TardisCommande_TARDIS_1", rs)
dossier = Instance("Folder", "TARDIS", ws)
t1 = Instance("Folder", "TARDIS_1", dossier)
x = Instance("Model", "Cabine", Instance("Folder", "EXTERIEURE", t1))
interieur = Instance("Model", "Salle", Instance("Folder", "INTERIEURE", t1))
x.props["Pivot"] = CF((0, 50, 0))
x.props["ExtentsSize"] = Vec3(4, 9, 4)
racine = PieceLiee("Part", "Racine", x, x, CF((0, 0, 0))); racine.props["Size"] = Vec3(4, 1, 4); x.props["PrimaryPart"] = racine
lampe = PieceLiee("Part", "Lampe", x, x, CF((0, 9, 0))); lampe.props["Size"] = Vec3(1, 1, 1)
Instance("PointLight", "PointLight", lampe)
Instance("ObjectValue", "TracteurCible", x).props["Value"] = None
console = Instance("Model", "Console", interieur)
Instance("Part", "BoutonCamera", console)
rotor = Instance("Part", "Rotor", interieur); interieur.props["PrimaryPart"] = rotor; rotor.props["Pivot"] = CF((0, 1000, 0))
x.attrs.update({"Etat": "Pose", "DebutEtat": 1000.0, "Mode": "Normal"})
SOLV = {"y": 0.0, "mat": "Grass"}
def raycastV(_w, origine, direction, params=None):
    o, d = roblox.en_vec3(origine), roblox.en_vec3(direction)
    if o is None or d is None: return None
    if d.y < 0 and o.y + d.y <= SOLV["y"] <= o.y:
        return Table({"Position": Vec3(o.x, SOLV["y"], o.z), "Normal": Vec3(0, 1, 0), "Instance": Instance("Part", "Sol"), "Distance": o.y - SOLV["y"],
                      "Material": Valeur("Enum.Material." + SOLV["mat"])})
    return None
ws.extra["Raycast"] = Fonction("Raycast", py=raycastV)
ws.extra["Blockcast"] = Fonction("Blockcast", py=lambda *a: None)
def imageV(dt=1 / 30, n=1):
    for _ in range(n):
        H.avancer(dt)
        sig = RunService.extra.get("RenderStepped")
        if sig: sig.declencher(dt)
        for f_rendu in list(RunService.extra.get("rendu", {}).values()):
            if f_rendu is not None: tache(lambda f_rendu=f_rendu: appeler(f_rendu, [dt]))
        sig = RunService.extra.get("Heartbeat")
        if sig: sig.declencher(dt)
def touche(nom):
    uis.extra["InputBegan"].declencher(Table({"KeyCode": Valeur("Enum.KeyCode." + nom), "UserInputType": Valeur("Enum.UserInputType.Keyboard")}), False)
def regarder_vers(direction):
    centre = x.m_GetPivot().fois(CF((0, 4.5, 0)))
    pos = Vec3(*centre.p)
    camera.props["CFrame"] = roblox._regarder(Vec3.arith("-", pos, Vec3.arith("*", direction, 20)), pos)
def position(): return Vec3(*x.m_GetPivot().p)
def textes(morceau):
    interface = gui.m_FindFirstChild("TardisVolLibre")
    if not interface: return []
    return [e for e in interface.m_GetDescendants().h.values() if e.ClassName == "TextLabel" and morceau in str(e.props.get("Text"))]
def vitesse(n=30):
    p = position(); imageV(n=n)
    return Vec3.arith("-", position(), p).norme() * 30 / n

G["script"] = Instance("LocalScript", "TardisVolLibre", game.m_FindFirstChild("StarterPlayer"))
tache(lambda: I.executer(lire("StarterPlayer/StarterPlayerScripts/TardisVolLibre.client.lua"), "TardisVolLibre"))
verifier("TardisVolLibre se charge (faux monde avec maths réelles)", not roblox.ERREURS, roblox.ERREURS[:3])
regarder_vers(Vec3(0, 0, -1))
x.m_SetAttribute("VolLibreCF", x.m_GetPivot())
x.m_SetAttribute("VolPhase", "Visible")
x.m_SetAttribute("VolLibre", 101)
imageV(n=3)
touche("Return"); imageV(n=30)
v0 = vitesse()
verifier("Croisière hors de l'eau : ~50 studs/s (NORMAL)", 47 < v0 < 53, v0)
verifier("Pas encore dans l'eau : pas d'annonce", not textes("Dans l'eau"))
while position().z > -100: imageV()
imageV(n=6)
verifier("C-77. Entrée dans l'eau : annonce « Dans l'eau : vitesse réduite, TURBO coupé »", len(textes("Dans l'eau : vitesse réduite")) == 1, [t.props.get("Text") for t in textes("eau")])
plongeon = dans_ws("TardisGerbeEau")
verifier("G-26. Plongeon à plus de 20 studs/s : une gerbe, à la surface du lac (y = 64)", len(plongeon) == 1 and abs(plongeon[0].props["CFrame"].p[1] - 64) < 1e-6,
         [p.props["CFrame"].p for p in plongeon])
imageV(n=60)
v1 = vitesse()
verifier("C-77. Dans l'eau : vitesse divisée par deux (~25 studs/s)", 22 < v1 < 28, v1)
EAU["actif"] = False
imageV(n=6)
verifier("C-77. Sortie de l'eau : annonce « Hors de l'eau »", len(textes("Hors de l'eau")) == 1, [t.props.get("Text") for t in textes("eau")])
imageV(n=90)
v2 = vitesse()
verifier("C-77. Hors de l'eau : la vitesse revient (~50 studs/s)", 47 < v2 < 53, v2)
imageV(n=90)
verifier("G-26. La gerbe du plongeon est nettoyée", not dans_ws("TardisGerbeEau"))
# G-35 : sillage au ras de l'eau
y = position().y
SOLV.update({"y": y - 6, "mat": "Water"})
imageV(n=10)
sillage = dans_ws("TardisSillage")
ecume = [e for s in sillage for e in s.enfants if e.ClassName == "ParticleEmitter"]
verifier("G-35. À 6 studs au-dessus de l'eau : sillage d'écume", len(sillage) == 1 and len(ecume) == 1 and ecume[0].props.get("Enabled") is True and ecume[0].props.get("Rate", 0) > 10,
         (len(sillage), [(e.props.get("Enabled"), e.props.get("Rate")) for e in ecume]))
if sillage:
    cf = sillage[0].props["CFrame"]
    verifier("G-35. Le sillage est posé à la surface et part vers l'arrière (+Z)", abs(cf.p[1] - (y - 6)) < 1 and cf.R[2][2] < -0.9, (cf.p, cf.R[2]))
SOLV.update({"mat": "Grass"})
imageV(n=10)
verifier("G-35. Au-dessus de l'herbe : l'écume s'arrête", ecume and ecume[0].props.get("Enabled") is False, [e.props.get("Enabled") for e in ecume])
SOLV.update({"y": 0.0})
verifier("TardisVolLibre : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])

src_vl = lire("StarterPlayer/StarterPlayerScripts/TardisVolLibre.client.lua")
verifier("C-77. Le boost est ignoré dans l'eau (vitesseDansEau après le boost)", src_vl.index("Config.vitesseDansEau(R.NIVEAUX, vol.niveau) or vitesseCible") > src_vl.index("vitesseCible", src_vl.index("local function piloter")))

print("\n".join("  ✓ " + n for n in OK))
print("\n".join("  ✗ " + n for n in KO))
print(f"SUR L'EAU (V7.2.3) : {len(OK)}/{len(OK) + len(KO)} vérifications réussies")
sys.exit(1 if KO else 0)
