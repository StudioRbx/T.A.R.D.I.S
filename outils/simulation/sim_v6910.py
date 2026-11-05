"""Simulations de la V6.9.10 (vol libre et vortex) : le vrai code, exécuté avec de faux objets Roblox et des maths réelles
(Vector3 et CFrame calculables, roblox.activer_maths).
  1. TardisConfig : réglages (V6.9.10), sons Vortex et Frein à 0, facteur du rotor (Config.facteurRotorVol).
  2. Serveur : module VolLibre (freinerVol) et le vrai aiguillage des actions de TardisServeur : VolLibreFrein validé
     (pilote seul, aucune donnée, jamais en urgence ni en descente, un frein par seconde au plus, sans passer par le
     délai des ordres) ; diagnostic des sons ; sons de Config.Sons créés seulement avec un identifiant.
  3. TardisVolLibre (le script entier, image par image) : croisière (23), freinage d'urgence envoyé au serveur (30),
     bouton ORBITE.
  4. TardisCamera (le script entier) : caméra en orbite autour de la cabine, seulement en croisière (26).
  5. EffetsExterieurs (le module entier) : secousse à bord, fumée et son du frein (30).
  6. TardisEffets (le script entier) : rotor qui suit la vitesse du vol libre (52).
  7. Ambiance (le module entier) : vent du vortex à bord (136)."""
import os, sys, re, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from monde import *
import roblox
from roblox import Couleur, Vec3, CF, activer_maths
import random
random.seed(6910)  # secousses et bruits : toujours le même tirage
OK, KO = [], []
def verifier(nom, condition, detail=""):
    (OK if condition else KO).append(nom + ("" if condition else "  →  " + str(detail)))
def tache(f): lancer(Fonction("t", py=f))
def lire(chemin): return open(os.path.join(DEPOT, chemin), encoding="utf-8").read()
def vider_cache(): roblox.charger_module.__defaults__[0].clear()  # chaque monde charge ses propres modules


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
E = Config.get("Etats")
VL = Config.get("VolLibre")
verifier("Config.Version ≥ 6.9.10 (6.9.10 à sa sortie)", tuple(int(n) for n in Config.get("Version").split(".")) >= (6, 9, 10), Config.get("Version"))
CR, FR = VL.get("Croisiere"), VL.get("Frein")
verifier("Config.VolLibre.Croisiere.DistanceObstacle = 25", CR and CR.get("DistanceObstacle") == 25)
verifier("Config.VolLibre.Frein : recharge 1 s, secousses, portée, fumée", FR and (FR.get("Recharge"), FR.get("SecousseABord"), FR.get("SecousseDehors"), FR.get("PorteeDehors"), FR.get("DureeFumee")) == (1, 0.5, 0.4, 60, 0.5))
CO = Config.get("CameraOrbite")
verifier("Config.CameraOrbite : 8°/s, 30 studs (25 à 35), 20°, zone rechargée toutes les 4 s",
         CO and (CO.get("Vitesse"), CO.get("Distance"), CO.get("DistanceMin"), CO.get("DistanceMax"), CO.get("Elevation"), CO.get("RechargeZone")) == (8, 30, 25, 35, 20, 4))
RV = Config.get("RotorVolLibre")
verifier("Config.RotorVolLibre : facteur max 3, bonus vortex 0,5 et urgence 1", RV and (RV.get("FacteurMax"), RV.get("BonusVortex"), RV.get("BonusUrgence"), RV.get("Lissage")) == (3, 0.5, 1, 2))
AV = Config.get("AmbianceVortex")
verifier("Config.AmbianceVortex : volume 0,4, moitié avec le jukebox", AV and (AV.get("Volume"), AV.get("AvecJukebox"), AV.get("Fondu")) == (0.4, 0.5, 1))
SONS = Config.get("Sons")
verifier("Config.Sons : Vortex et Frein déclarés avec l'Id 0", SONS.get("Vortex") == 0 and SONS.get("Frein") == 0, (SONS.get("Vortex"), SONS.get("Frein")))
cfgsrc = lire("ReplicatedStorage/TardisConfig.lua")
def bloc(debut, fin="\n}"):
    i = cfgsrc.index(debut); return cfgsrc[i:cfgsrc.index(fin, i)]
blocs = [bloc("Config.CameraOrbite = {"), bloc("\tCroisiere = {", "\n\t}"), bloc("\tFrein = {", "\n\t}"), bloc("Config.AmbianceVortex = {"), bloc("Config.RotorVolLibre = {")]
nouvelles = [l for b in blocs for l in b.splitlines()[1:] if re.match(r"\s*\w+ = ", l)]
nouvelles += [l for l in cfgsrc.splitlines() if re.match(r"\s*(Vortex|Frein) = 0,", l)]
verifier("Chaque nouveau réglage est commenté « (V6.9.10) »", len(nouvelles) == 21 and all("(V6.9.10)" in l for l in nouvelles),
         (len(nouvelles), [l for l in nouvelles if "(V6.9.10)" not in l][:3]))
f = lambda *a: premier(appeler(Config.get("facteurRotorVol"), list(a)))
for args, attendu in [((0, False, False), 1), ((75, False, False), 2), ((150, False, False), 3), ((400, False, False), 3), ((150, True, False), 3.5),
                      ((220, False, True), 4), ((0, True, True), 2.5), ((None, False, False), 1), ((float("nan"), False, False), 1)]:
    v = f(*args)
    verifier(f"facteurRotorVol{args} = {attendu}", abs(v - attendu) < 1e-9, v)


# ================================================================== 3 et 4. Client : TardisVolLibre et TardisCamera, image par image
ws = game.m_FindFirstChild("Workspace")
RunService = game.m_FindFirstChild("RunService")
uis = game.m_FindFirstChild("UserInputService")
for nom in ("InputBegan", "InputEnded", "InputChanged"): uis.extra[nom] = Signal("UserInputService." + nom)
uis.props["MouseBehavior"] = Valeur("Enum.MouseBehavior.Default")
joueur.attrs["TardisPilote_TARDIS_1"] = True
gui = Instance("PlayerGui", "PlayerGui", joueur)
scripts = Instance("Folder", "PlayerScripts", joueur)
MOUVEMENT = {"v": Vec3(0, 0, 0)}
CONTROLES = {"actifs": True}
controles = Table({"GetMoveVector": Fonction("GetMoveVector", py=lambda _s: MOUVEMENT["v"] if CONTROLES["actifs"] else Vec3(0, 0, 0)),
                   "Enable": Fonction("Enable", py=lambda _s: CONTROLES.__setitem__("actifs", True) or []),
                   "Disable": Fonction("Disable", py=lambda _s: CONTROLES.__setitem__("actifs", False) or [])})
module_joueur = Instance("ModuleScript", "PlayerModule", scripts)
module_joueur.extra["module"] = Table({"GetControls": Fonction("GetControls", py=lambda _s: controles)})
require_monde = G["require"]
G["require"] = Fonction("require", py=lambda obj: obj.extra["module"] if isinstance(obj, Instance) and "module" in obj.extra else premier(appeler(require_monde, [obj])))
camera = Instance("Camera", "Camera", ws)
camera.props.update({"CFrame": CF((0, 60, 20)), "FieldOfView": 70, "ViewportSize": Valeur("Vector2", [1280, 720]), "CameraType": Valeur("Enum.CameraType.Custom")})
ws.props["CurrentCamera"] = camera
ws.props["StreamingEnabled"] = False
remote = Instance("RemoteEvent", "TardisCommande_TARDIS_1", rs)
Instance("RemoteEvent", "TardisCommande_TARDIS_2", rs)
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
bouton = Instance("Part", "BoutonCamera", console)
rotor = Instance("Part", "Rotor", interieur)
interieur.props["PrimaryPart"] = rotor
rotor.props["Pivot"] = CF((0, 1000, 0))
x.attrs.update({"Etat": "Pose", "DebutEtat": 1000.0, "Mode": "Normal"})
SOL = {"y": 0.0}
MUR = {"z": None}  # un mur perpendiculaire à l'axe Z (devant le TARDIS qui va vers -Z)
def raycast(_w, origine, direction, params=None):
    o, d = roblox.en_vec3(origine), roblox.en_vec3(direction)
    if o is None or d is None: return None
    if d.y < 0 and o.y + d.y <= SOL["y"] <= o.y:
        return Table({"Position": Vec3(o.x, SOL["y"], o.z), "Normal": Vec3(0, 1, 0), "Instance": Instance("Part", "Sol"), "Distance": o.y - SOL["y"],
                      "Material": Valeur("Enum.Material.Grass")})
    return None
def blockcast(_w, cf, taille, direction, params=None):
    d = roblox.en_vec3(direction)
    if MUR["z"] is None or not isinstance(cf, CF) or d is None: return None
    z0, z1 = cf.p[2], cf.p[2] + d.z
    if z1 <= MUR["z"] <= z0 and d.z < 0:
        dist = (z0 - MUR["z"]) / max(abs(d.z) / d.norme(), 1e-9)
        return Table({"Position": Vec3(cf.p[0], cf.p[1], MUR["z"]), "Normal": Vec3(0, 0, 1), "Distance": dist})
    return None
ws.extra["Raycast"] = Fonction("Raycast", py=raycast)
ws.extra["Blockcast"] = Fonction("Blockcast", py=blockcast)

def image(dt=1 / 30, n=1):
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
def envois(action=None):
    return [e for e in remote.extra.get("envois", []) if action is None or e[0] == action]
def boutons(prefixe):
    res = []
    def visite(o):
        for e in o.enfants:
            if e.ClassName == "TextButton" and str(e.props.get("Text", "")).startswith(prefixe): res.append(e)
            visite(e)
    visite(gui)
    return res
def cliquer(b): b.extra.setdefault("Activated", Signal("Activated")).declencher()
def regarder_vers(direction):  # la caméra du pilote regarde dans cette direction (depuis derrière le TARDIS)
    centre = x.m_GetPivot().fois(CF((0, 4.5, 0)))
    pos = Vec3(*centre.p)
    camera.props["CFrame"] = roblox._regarder(Vec3.arith("-", pos, Vec3.arith("*", direction, 20)), pos)
def position(): return Vec3(*x.m_GetPivot().p)
def lacet():
    """Orientation de la cabine autour de la verticale, inclinaison de vol retirée (R = inclinaison × rotation en Y)."""
    R_ = x.m_GetPivot().R
    haut = (R_[0][1], R_[1][1], R_[2][1])
    axe = Vec3(0, 1, 0).cross(Vec3(*haut))
    if axe.norme() > 1e-9:
        u = axe.unite(); a = math.acos(max(-1, min(1, haut[1]))); c, s_ = math.cos(a), math.sin(a); X, Y, Z = u.t(); t = 1 - c
        T = ((t * X * X + c, t * X * Y - s_ * Z, t * X * Z + s_ * Y), (t * X * Y + s_ * Z, t * Y * Y + c, t * Y * Z - s_ * X), (t * X * Z - s_ * Y, t * Y * Z + s_ * X, t * Z * Z + c))
        R_ = roblox._mat(roblox._tr(T), R_)
    return math.degrees(math.atan2(R_[0][2], R_[2][2]))

G["script"] = Instance("LocalScript", "TardisVolLibre", game.m_FindFirstChild("StarterPlayer"))
tache(lambda: I.executer(lire("StarterPlayer/StarterPlayerScripts/TardisVolLibre.client.lua"), "TardisVolLibre"))
verifier("TardisVolLibre se charge (faux monde avec maths réelles)", not roblox.ERREURS, roblox.ERREURS[:3])
G["script"] = Instance("LocalScript", "TardisCamera", game.m_FindFirstChild("StarterPlayer"))
tache(lambda: I.executer(lire("StarterPlayer/StarterPlayerScripts/TardisCamera.client.lua"), "TardisCamera"))
verifier("TardisCamera se charge", not roblox.ERREURS, roblox.ERREURS[:3])

# ------------------------------------------------------------------ 3. Le vol libre commence : le pilote est ce joueur
regarder_vers(Vec3(0, 0, -1))
x.m_SetAttribute("VolLibreCF", x.m_GetPivot())
x.m_SetAttribute("VolPhase", "Visible")
x.m_SetAttribute("VolLibre", 101)
image(n=3)
interface = gui.m_FindFirstChild("TardisVolLibre")
verifier("Vol libre : interface du pilote affichée", interface is not None and interface.props.get("Enabled") is True)
cibleCamera = ws.m_FindFirstChild("TardisCibleCamera")
verifier("Vol libre : la caméra suit la cible de pilotage", cibleCamera is not None and camera.props.get("CameraSubject") is cibleCamera)
bCroisiere, bOrbite, bFrein = boutons("CROISIÈRE"), boutons("ORBITE"), boutons("FREIN")
verifier("23. Bouton CROISIÈRE (Entrée) et bouton ORBITE dans le sous-menu PLUS", len(bCroisiere) == 1 and len(bOrbite) == 1
         and bCroisiere[0].props["Text"] == "CROISIÈRE  (Entrée)", [b.props["Text"] for b in bCroisiere + bOrbite])
verifier("26. ORBITE grisé tant que la croisière n'est pas active", bOrbite[0].attrs.get("Disponible") is False, bOrbite[0].attrs)
cliquer(bOrbite[0]); image()
verifier("26. ORBITE hors croisière : aucune demande à la caméra", joueur.attrs.get("TardisDemandeOrbite") is None)
volet = lire("StarterPlayer/StarterPlayerScripts/TardisTablette/Volet.lua")
verifier("23. Touche de la croisière réglable dans la tablette (UI.touche « volCroisiere »)", '{ "volCroisiere", "Vol : croisière", "Return" }' in volet)

# Sans croisière : sans touche, le TARDIS ralentit et reste sur place
p0 = position(); image(n=60)
verifier("Sans croisière ni touche : le TARDIS ne part pas", Vec3.arith("-", position(), p0).norme() < 1, Vec3.arith("-", position(), p0).norme())
# 23. Croisière : Entrée
touche("Return"); image()
verifier("23. Entrée : croisière active (attribut local TardisCroisiere pour la caméra)", joueur.attrs.get("TardisCroisiere") is True, joueur.attrs)
verifier("23. Le bouton s'allume « CROISIÈRE ● » et ORBITE devient disponible", bCroisiere[0].props["Text"] == "CROISIÈRE  ●" and bOrbite[0].attrs.get("Disponible") is True)
p0, y0 = position(), position().y
image(n=150)  # 5 s
d = Vec3.arith("-", position(), p0)
verifier("23. Croisière : il avance tout seul, droit devant (vers -Z, ~50 studs/s au niveau NORMAL)", d.z < -150 and abs(d.x) < 5, d.t())
verifier("23. Croisière : altitude tenue", abs(position().y - y0) < 0.5, (y0, position().y))
p1 = position(); image(n=30)
v = Vec3.arith("-", position(), p1).norme()
verifier("23. Croisière : vitesse du niveau tenue (NORMAL = 50 studs/s)", 47 < v < 53, v)
dernier = envois("VolLibre")[-1]
verifier("Les positions partent au serveur pendant la croisière (~15 par seconde)", len(envois("VolLibre")) > 60 and isinstance(dernier[1], CF), len(envois("VolLibre")))
# La caméra tourne (regard libre, orbite) : le cap et l'orientation ne bougent pas. La cabine tourne sur elle-même en
# vol (RotationMax, selon la vitesse) : on compare sa rotation pendant 2 s, caméra devant puis caméra sur le côté.
tour = lambda a, b: ((b - a + 180) % 360) - 180
l0 = lacet(); image(n=60); rotationSeule = tour(l0, lacet())
regarder_vers(Vec3(1, 0, 0)); p1 = position(); l0 = lacet(); image(n=60)
d = Vec3.arith("-", position(), p1)
verifier("23. La caméra regarde ailleurs : le cap reste le même (toujours vers -Z)", d.z < -80 and abs(d.x) < 3, d.t())
verifier("23. … et la cabine ne se tourne pas vers la caméra (seule sa rotation de vol continue)", abs(tour(l0, lacet()) - rotationSeule) < 2, (rotationSeule, tour(l0, lacet())))
# Une touche de direction l'arrête
MOUVEMENT["v"] = Vec3(1, 0, 0); image(n=2); MOUVEMENT["v"] = Vec3(0, 0, 0)
verifier("23. Une touche de direction arrête la croisière", joueur.attrs.get("TardisCroisiere") is None and bCroisiere[0].props["Text"] == "CROISIÈRE  (Entrée)")
info = [e for e in interface.m_GetDescendants().h.values() if e.ClassName == "TextLabel" and "Croisière arrêtée" in str(e.props.get("Text"))]
verifier("23. Message « Croisière arrêtée » sur le tableau de bord", len(info) == 1)
image(n=60); p1 = position(); image(n=30)
verifier("23. Arrêtée : il ralentit et ne repart pas tout seul", Vec3.arith("-", position(), p1).norme() < 10, Vec3.arith("-", position(), p1).norme())
# Le bouton CROISIÈRE la relance, et l'éteint
regarder_vers(Vec3(0, 0, -1))
cliquer(bCroisiere[0]); image()
verifier("23. Bouton CROISIÈRE : croisière active", joueur.attrs.get("TardisCroisiere") is True)
cliquer(bCroisiere[0]); image()
verifier("23. Second clic : croisière arrêtée", joueur.attrs.get("TardisCroisiere") is None)
# Chute (double Espace), CIBLE, ATTERRIR ICI, stationnaire, planeur, cap fixe : chacun l'arrête
def arrete_par(action, nom):
    touche("Return"); image()
    actif = joueur.attrs.get("TardisCroisiere") is True
    action(); image()
    verifier(f"23. {nom} arrête la croisière", actif and joueur.attrs.get("TardisCroisiere") is None, (actif, joueur.attrs.get("TardisCroisiere")))
def double_espace():
    touche("Space"); H.avancer(0.1); touche("Space")
arrete_par(double_espace, "La chute (double Espace)")
verifier("23. … et la chute part bien au serveur", len(envois("VolLibreChute")) == 1, len(envois("VolLibreChute")))
arrete_par(lambda: touche("H"), "STATIONNAIRE (H)")
touche("H"); image()  # on retire le stationnaire
arrete_par(lambda: touche("J"), "PLANEUR (J)")
touche("J"); image()
arrete_par(lambda: touche("M"), "CAP FIXE (M)")
touche("M"); image()
def atterrir_ici():
    regarder_vers(Vec3(0, -0.6, -1).unite()); touche("N")
arrete_par(atterrir_ici, "ATTERRIR ICI (N)")
touche("N"); image(); regarder_vers(Vec3(0, 0, -1))  # annule l'atterrissage
autre = Instance("Player", "Amy", game.m_FindFirstChild("Players")); autre.props.update({"UserId": 202, "DisplayName": "Amy"})
persoAmy = Instance("Model", "Amy", ws); racineAmy = Instance("Part", "HumanoidRootPart", persoAmy); autre.props["Character"] = persoAmy
racineAmy.props["Position"] = Vec3.arith("+", Vec3(*camera.props["CFrame"].p), Vec3.arith("*", camera.props["CFrame"].__lua_index__("LookVector"), 60))
racineAmy.props["CFrame"] = CF(racineAmy.props["Position"].t())
arrete_par(lambda: touche("L"), "CIBLE (L)")
touche("L"); image()
autre.set_parent(None); persoAmy.set_parent(None)
# L'urgence l'arrête, et on ne peut pas la lancer en urgence
touche("Return"); image()
x.m_SetAttribute("VolUrgence", True); image(n=2)
verifier("23. L'urgence arrête la croisière", joueur.attrs.get("TardisCroisiere") is None)
touche("Return"); image()
verifier("23. Pas de croisière en urgence", joueur.attrs.get("TardisCroisiere") is None)
x.m_SetAttribute("VolUrgence", False); image(n=20)
# Obstacle devant : stationnaire
regarder_vers(Vec3(0, 0, -1)); touche("Return"); image()
MUR["z"] = position().z - 60
image(n=60)
verifier("23. Obstacle à moins de 25 studs devant : croisière arrêtée", joueur.attrs.get("TardisCroisiere") is None)
verifier("23. … le TARDIS s'arrête avant le mur, sans choc (portée + distance de freinage)", position().z > MUR["z"] + 15 and not envois("VolLibreChoc"), (position().z, MUR["z"]))
image(n=60); p1 = position(); image(n=30)
verifier("23. … et reste en stationnaire, à la même altitude", Vec3.arith("-", position(), p1).norme() < 1.5 and boutons("STATIONNAIRE  ●"), Vec3.arith("-", position(), p1).norme())
touche("H"); image(); MUR["z"] = None
# Vol de précision (TARDIS rapetissé) : la croisière marche, sans test d'obstacle (il traverse tout)
x.m_SetAttribute("VolPrecision", True); image(n=2)
touche("Return"); image()
MUR["z"] = position().z - 30; image(n=60)
verifier("23. Vol de précision : la croisière continue à travers l'obstacle (comme le vol de précision)", joueur.attrs.get("TardisCroisiere") is True and position().z < MUR["z"], (position().z, MUR["z"]))
MUR["z"] = None
touche("Return"); x.m_SetAttribute("VolPrecision", False); image(n=30)

# ------------------------------------------------------------------ 30. Freinage d'urgence (côté pilote)
touche("Return"); image(n=30)
n0 = len(envois("VolLibreFrein"))
touche("LeftControl"); image()
verifier("30. Ctrl : frein envoyé au serveur (VolLibreFrein, sans donnée)", len(envois("VolLibreFrein")) == n0 + 1 and len(envois("VolLibreFrein")[-1]) == 1, envois("VolLibreFrein")[-1:])
verifier("30. Le frein arrête la croisière", joueur.attrs.get("TardisCroisiere") is None)
p1 = position(); image()
verifier("30. Arrêt net (vitesse à zéro)", Vec3.arith("-", position(), p1).norme() < 0.5, Vec3.arith("-", position(), p1).norme())
H.avancer(0.4); touche("LeftControl"); image()
verifier("30. Second frein moins d'une seconde après : rien n'est renvoyé", len(envois("VolLibreFrein")) == n0 + 1)
H.avancer(1.0); touche("LeftControl"); image()
verifier("30. Une seconde plus tard : de nouveau envoyé", len(envois("VolLibreFrein")) == n0 + 2)
cliquer(bFrein[0]); H.avancer(1.1); cliquer(bFrein[0]); image()
verifier("30. Le bouton FREIN fait pareil", len(envois("VolLibreFrein")) == n0 + 3, len(envois("VolLibreFrein")) - n0)
x.m_SetAttribute("VolUrgence", True); image(); H.avancer(1.1)
touche("LeftControl"); image()
verifier("30. En urgence, rien ne l'arrête : pas de frein", len(envois("VolLibreFrein")) == n0 + 3)
x.m_SetAttribute("VolUrgence", False); image(n=10)
vl = lire("StarterPlayer/StarterPlayerScripts/TardisVolLibre.client.lua")
corps = vl[vl.index("freiner = function()"):vl.index("basculerStationnaire = function()")]
verifier("30. Plus de fumée locale chez le pilote seul (elle passe par le serveur, pour tout le monde)", "Smoke" not in corps)
verifier("30. Secousse du pilote plus douce avec « réduire les effets »", "camera.FieldOfView -= UI.effetsReduits() and 3 or 8" in corps
         and "local force = total * 0.03 * (UI.effetsReduits() and 0.3 or 1)" in vl)


# ------------------------------------------------------------------ 4. TardisCamera : caméra en orbite (26)
guiCam = gui.m_FindFirstChild("TardisCameraGui")
bOrbiteCam = [b for b in guiCam.enfants if b.ClassName == "TextButton" and b.props.get("Text") == "Orbite"]
bQuitter = [b for b in guiCam.enfants if b.ClassName == "TextButton" and str(b.props.get("Text")).startswith("Quitter")]
verifier("26. Caméra de la console : bouton « Orbite » à côté de « Quitter la caméra »", len(bOrbiteCam) == 1 and len(bQuitter) == 1)
def centre_cabine():  # milieu entre le bas de la cabine et le haut de sa lampe (la cabine penche un peu en vol)
    haut = Vec3.arith("+", lampe.__lua_index__("Position"), Vec3(0, 0.5, 0))
    return Vec3.arith("*", Vec3.arith("+", position(), haut), 0.5)
def mesure_camera():
    cf = camera.props["CFrame"]
    ecart = Vec3.arith("-", Vec3(*cf.p), centre_cabine())
    vise = cf.__lua_index__("LookVector").dot(Vec3.arith("*", ecart, -1).unite())
    return ecart.norme(), math.degrees(math.atan2(ecart.x, ecart.z)), math.degrees(math.asin(ecart.y / ecart.norme())), vise
cam_active = lambda: guiCam.props.get("Enabled") is True
touche("Return"); image()
verifier("26. Croisière active : ORBITE disponible", bOrbite[0].attrs.get("Disponible") is True)
image(n=60); p_a = position(); image(n=30); cap = Vec3.arith("-", position(), p_a).unite()  # le cap de la croisière (vitesse atteinte)
cliquer(bOrbite[0]); image(n=2)
verifier("26. ORBITE (vol libre) : la caméra s'ouvre directement en orbite", cam_active() and joueur.attrs.get("TardisOrbiteActive") is True
         and camera.props["CameraType"].nom == "Enum.CameraType.Scriptable", (cam_active(), joueur.attrs.get("TardisOrbiteActive")))
verifier("26. Le bouton du vol libre s'allume « ORBITE ● »", bOrbite[0].props["Text"] == "ORBITE  ●", bOrbite[0].props["Text"])
d0, a0, e0, vise = mesure_camera()
verifier("26. À 30 studs du centre de la cabine, 20° au-dessus de l'horizon, et elle la regarde", abs(d0 - 30) < 0.5 and abs(e0 - 20) < 1 and vise > 0.999, (d0, e0, vise))
rendus = RunService.extra.get("rendu", {})
verifier("26. Branchée sur la boucle de rendu de TardisCamera (« TardisCamera »), pas de nouvelle boucle", "TardisCamera" in rendus)
camsrc = lire("StarterPlayer/StarterPlayerScripts/TardisCamera.client.lua")
verifier("26. TardisCamera : une seule boucle par image (BindToRenderStep), aucun RenderStepped / Heartbeat", camsrc.count("BindToRenderStep(") == 1
         and "RenderStepped" not in camsrc and "Heartbeat" not in camsrc)
p1 = position(); image(n=150)
d1, a1, e1, vise = mesure_camera()
verifier("26. Elle tourne lentement autour de la cabine (~8°/s : ~40° en 5 s)", 36 < (a1 - a0) % 360 < 44, (a0, a1))
verifier("26. Elle suit la cabine qui avance (toujours à 30 studs, et la regarde)", Vec3.arith("-", position(), p1).norme() > 200 and abs(d1 - 30) < 0.5 and vise > 0.999, (d1, vise))
d = Vec3.arith("-", position(), p1)
verifier("26. Pendant l'orbite, la croisière garde son cap (la caméra ne dirige plus le TARDIS)", d.norme() > 200 and d.unite().dot(cap) > 0.9998, (d.t(), cap.t()))
MOUVEMENT["v"] = Vec3(1, 0, 0); image(n=5)
verifier("26. Pendant l'orbite, les touches de déplacement sont bloquées : la croisière continue", joueur.attrs.get("TardisCroisiere") is True and not CONTROLES["actifs"])
MOUVEMENT["v"] = Vec3(0, 0, 0)
UI.get("prefs").set("effetsReduits", True)
a0 = mesure_camera()[1]; image(n=150); a1 = mesure_camera()[1]
verifier("26. « Réduire les effets » : moitié moins vite (~20° en 5 s)", 17 < (a1 - a0) % 360 < 23, (a0, a1))
UI.get("prefs").set("effetsReduits", False)
for _ in range(5): uis.extra["InputChanged"].declencher(Table({"UserInputType": Valeur("Enum.UserInputType.MouseWheel"), "Position": Vec3(0, 0, 1), "KeyCode": Valeur("Enum.KeyCode.Unknown")}), False)
image()
verifier("26. Molette : plus près, jusqu'à 25 studs au plus près", abs(mesure_camera()[0] - 25) < 0.5, mesure_camera()[0])
for _ in range(9): uis.extra["InputChanged"].declencher(Table({"UserInputType": Valeur("Enum.UserInputType.MouseWheel"), "Position": Vec3(0, 0, -1), "KeyCode": Valeur("Enum.KeyCode.Unknown")}), False)
image()
verifier("26. Molette : plus loin, jusqu'à 35 studs au plus loin", abs(mesure_camera()[0] - 35) < 0.5, mesure_camera()[0])
x.m_SetAttribute("VolPrecision", True); image(n=3)
verifier("26. TARDIS rapetissé (vol de précision, 30 %) : la caméra se rapproche d'autant", abs(mesure_camera()[0] - 35 * 0.3) < 0.3, mesure_camera()[0])
x.m_SetAttribute("VolPrecision", False); x.m_SetAttribute("Echelle", 0.5); image()
verifier("26. Petit TARDIS (Echelle 0,5) : la caméra se rapproche aussi", abs(mesure_camera()[0] - 17.5) < 0.3, mesure_camera()[0])
x.m_SetAttribute("Echelle", None)
n0 = len(envois("VolLibreDemat")); touche("X"); image()
verifier("26. X en vol libre : la démat part, la caméra reste ouverte (le pilote quitte par le bouton)", cam_active() and len(envois("VolLibreDemat")) == n0 + 1
         and bQuitter[0].props["Text"] == "Quitter la caméra", (cam_active(), len(envois("VolLibreDemat")) - n0, bQuitter[0].props["Text"]))
# La croisière s'arrête (frein) : l'orbite se ferme et rend la caméra de pilotage
H.avancer(1.1); touche("LeftControl"); image(n=2)
verifier("26. Le frein arrête la croisière : l'orbite se ferme toute seule", not cam_active() and joueur.attrs.get("TardisOrbiteActive") is None)
verifier("26. … et la caméra revient au pilotage (sujet : la cible du vol libre, contrôles rendus)", camera.props.get("CameraSubject") is ws.m_FindFirstChild("TardisCibleCamera")
         and camera.props["CameraType"].nom == "Enum.CameraType.Custom" and CONTROLES["actifs"], camera.props.get("CameraSubject"))
verifier("26. Plus aucune boucle de la caméra après la fermeture", "TardisCamera" not in RunService.extra.get("rendu", {}))
# Par le bouton de la console : vue du toit, puis Orbite
prompt = bouton.m_FindFirstChildOfClass("ProximityPrompt")
prompt.extra.setdefault("Triggered", Signal("Triggered")).declencher(joueur); image()
verifier("26. Bouton de la console : la vue du toit, comme avant", cam_active() and joueur.attrs.get("TardisOrbiteActive") is None)
cliquer(bOrbiteCam[0]); image()
aide = [e for e in guiCam.enfants if e.ClassName == "TextLabel"][0]
verifier("26. « Orbite » hors croisière : refusée, l'aide l'explique", joueur.attrs.get("TardisOrbiteActive") is None and "seulement" in aide.props["Text"], aide.props["Text"])
touche("Return"); image(); cliquer(bOrbiteCam[0]); image(n=2)
verifier("26. En croisière, « Orbite » : la caméra passe en orbite", joueur.attrs.get("TardisOrbiteActive") is True and abs(mesure_camera()[0] - 30) < 0.5)
cliquer(bOrbiteCam[0]); image()
verifier("26. « Vue du toit » : retour au-dessus de la lampe, caméra toujours ouverte", cam_active() and joueur.attrs.get("TardisOrbiteActive") is None)
cliquer(bOrbiteCam[0]); image()
cliquer(bQuitter[0]); image()
verifier("26. « Quitter la caméra » : fermée, retour au pilotage", not cam_active() and camera.props.get("CameraSubject") is ws.m_FindFirstChild("TardisCibleCamera"))
# Un autre pilote reprend le vol : l'orbite n'est plus permise
cliquer(bOrbite[0]); image()
verifier("26. (orbite rouverte depuis le vol libre)", joueur.attrs.get("TardisOrbiteActive") is True)
cliquer(bOrbite[0]); image()
verifier("26. Second clic sur ORBITE (vol libre) : la caméra se ferme, retour direct au pilotage", not cam_active() and joueur.attrs.get("TardisOrbiteActive") is None)
cliquer(bOrbite[0]); image()
x.m_SetAttribute("Alimentation", False); image()
verifier("26. Coupure de courant : la caméra en orbite s'éteint", not cam_active())
x.m_SetAttribute("Alimentation", None); image()
cliquer(bOrbite[0]); image()
CONTROLES["actifs"] = True
verifier("Pas d'erreur jusqu'ici (vol libre et caméra)", not roblox.ERREURS, roblox.ERREURS[:3])


# ------------------------------------------------------------------ Fin du vol : tout est rendu
touche("Return"); image()
x.m_SetAttribute("VolLibre", None); x.m_SetAttribute("DepotCF", x.m_GetPivot()); image(n=3)
verifier("Fin du vol : croisière oubliée, interface fermée", joueur.attrs.get("TardisCroisiere") is None and interface.props.get("Enabled") is False)
verifier("Fin du vol : cible de la caméra détruite", ws.m_FindFirstChild("TardisCibleCamera") is None)

# ------------------------------------------------------------------ 5. EffetsExterieurs : le frein ressenti à bord (30)
init = lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/init.client.lua")
outils = init[init.index("local function partTemporaire(proprietes)"):init.index("-- La lampe du toit : la pièce qui contient la PointLight")]
O = {}
tache(lambda: O.update(t=premier(I.executer("local exterieur, Config, E = ...\n" + outils + "\nreturn { partTemporaire = partTemporaire, progressionAnimation = progressionAnimation }",
                                            "outils-extras", (x, Config, E)))))
DEDANS = {"v": False}
Lighting = game.m_FindFirstChild("Lighting")
Lighting.props.update({"ClockTime": 12, "ExposureCompensation": 0, "Ambient": Couleur(0.5, 0.5, 0.5), "OutdoorAmbient": Couleur(0.5, 0.5, 0.5)})
ws.props["Terrain"] = Instance("Terrain", "Terrain")
Instance("Folder", "Boucliers", x)
assets = Instance("Folder", "TardisAssets", rs); sonsAssets = Instance("Folder", "Sons", assets)
SoundService = game.m_FindFirstChild("SoundService")
def contexte(**plus):
    t = Table({"C": UI.get("C"), "Config": Config, "E": E, "Lighting": Lighting, "RunService": RunService, "UI": UI, "animer": UI.get("animer"),
               "camera": camera, "creer": UI.get("creer"), "texte": UI.get("texte"), "def": Config.get("Tardis").get(1), "exterieur": x, "interieur": interieur,
               "joueur": joueur, "jeSuisDedans": Fonction("jeSuisDedans", py=lambda: DEDANS["v"]), "partTemporaire": O["t"].get("partTemporaire"),
               "progressionAnimation": O["t"].get("progressionAnimation"), "remote": remote, "ReplicatedStorage": rs, "Players": game.m_FindFirstChild("Players"),
               "boiteInt": CF((0, 1000, 0)), "dansInterieur": Fonction("dansInterieur", py=lambda p: DEDANS["v"]),
               "maRacine": Fonction("maRacine", py=lambda: None), "lampe": None})
    for k, v in plus.items(): t.set(k, v)
    return t
def module(nom):
    res = {}
    tache(lambda: res.update(m=premier(appeler(premier(I.executer(lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/" + nom + ".lua"), nom)), [contexte()]))))
    return res.get("m")
module("EffetsExterieurs")
verifier("EffetsExterieurs se charge", not roblox.ERREURS, roblox.ERREURS[:3])
def secousse_mesuree():
    """Secousse en cours, lue sur la caméra : la boucle de secousse est appelée une fois, avec math.random qui rend 1."""
    f_rendu = RunService.extra["rendu"].get("TardisExtrasSecousse_TARDIS_1")
    camera.props["CFrame"] = CF((0, 60, 30))
    ancien = G["math"].h["random"]; G["math"].h["random"] = Fonction("random", py=lambda *a: 1.0)
    tache(lambda: appeler(f_rendu, [0]))
    G["math"].h["random"] = ancien
    R_ = camera.props["CFrame"].R
    angle = math.acos(max(-1, min(1, (R_[0][0] + R_[1][1] + R_[2][2] - 1) / 2)))
    a = math.asin(angle / math.sqrt(3)) if angle else 0
    return a / (0.035 * 0.5)
def freiner_serveur():
    image(n=60)  # la secousse précédente est retombée
    x.m_SetAttribute("FreinTemps", 1000.0 + H.t)
fumees = lambda: [e for e in racine.enfants if e.Name == "TardisFumeeFrein"]
x.m_SetAttribute("VolLibre", 202); x.m_SetAttribute("VolPhase", "Visible")
DEDANS["v"] = True; freiner_serveur()
sec = secousse_mesuree()
verifier("30. Passager à bord : secousse au frein (0,5)", abs(sec - 0.5) < 0.02, sec)
verifier("30. Fumée de freinage autour de la cabine, pour tout le monde", len(fumees()) == 1 and fumees()[0].props.get("Enabled") is not False and abs(fumees()[0].props["Size"] - 5) < 1e-9)
image(0.1, 6)
verifier("30. La fumée s'arrête après 0,5 s", fumees() and fumees()[0].props.get("Enabled") is False)
image(0.1, 30)
verifier("30. Puis elle est détruite (rien ne reste)", not fumees())
UI.get("prefs").set("effetsReduits", True); freiner_serveur(); sec = secousse_mesuree()
verifier("30. « Réduire les effets » : secousse à bord plus douce (× 0,3)", abs(sec - 0.15) < 0.01, sec)
UI.get("prefs").set("effetsReduits", False)
DEDANS["v"] = False
for distance, attendu in [(30, 0.2), (100, 0.0)]:
    image(n=60); camera.props["CFrame"] = CF(Vec3.arith("+", position(), Vec3(0, 0, distance)).t())
    x.m_SetAttribute("FreinTemps", 1000.0 + H.t); sec = secousse_mesuree()
    verifier(f"30. Dehors à {distance} studs : secousse {attendu}", abs(sec - attendu) < 0.02, sec)
x.m_SetAttribute("VolLibre", 101); DEDANS["v"] = True; freiner_serveur(); sec = secousse_mesuree()
verifier("30. Le pilote n'a pas de seconde secousse (il a déjà la sienne)", sec < 1e-6, sec)
x.m_SetAttribute("VolLibre", 202)
image(0.1, 40)
x.m_SetAttribute("Camouflage", True); freiner_serveur()
verifier("30. Cabine camouflée : pas de fumée (la secousse à bord reste)", not fumees() and secousse_mesuree() > 0.4)
x.m_SetAttribute("Camouflage", None); x.m_SetAttribute("VolPhase", "Invisible"); freiner_serveur()
verifier("30. Cabine dématérialisée en vol : pas de fumée", not fumees())
x.m_SetAttribute("VolPhase", "Visible"); x.m_SetAttribute("Echelle", 0.5); x.m_SetAttribute("VolPrecision", True); freiner_serveur()
verifier("30. TARDIS rapetissé : fumée à sa taille", fumees() and abs(fumees()[-1].props["Size"] - 5 * 0.5 * 0.3) < 1e-9, fumees() and fumees()[-1].props["Size"])
x.m_SetAttribute("Echelle", None); x.m_SetAttribute("VolPrecision", None); image(0.1, 40)
n_fumees = len(fumees()); x.m_SetAttribute("FreinTemps", 1000.0 + H.t - 5)
verifier("30. Ancien frein (5 s) : rien ne se rejoue (joueur qui arrive)", len(fumees()) == n_fumees and secousse_mesuree() < 1e-6)
x.m_SetAttribute("FreinTemps", None)
verifier("30. FreinTemps effacé : rien", len(fumees()) == n_fumees)
# Son « Frein » (facultatif)
DEDANS["v"] = True; freiner_serveur()
verifier("30. Sans son « Frein » dans TardisAssets : rien ne joue, aucune erreur", not SoundService.m_FindFirstChild("TardisSonFrein") and not roblox.ERREURS, roblox.ERREURS[:2])
sonFrein = Instance("Sound", "Frein", sonsAssets); sonFrein.props["Volume"] = 0.8
UI.get("prefs").set("volume", 0.5)
freiner_serveur()
s_ = SoundService.m_FindFirstChild("TardisSonFrein")
verifier("30. Son « Frein » à bord : non positionné, au volume des réglages", s_ is not None and abs(s_.props["Volume"] - 0.4) < 1e-9, s_ and s_.props["Volume"])
image(0.5, 21)
verifier("30. Le son du frein est détruit après (rien ne reste)", not SoundService.m_FindFirstChild("TardisSonFrein"))
UI.get("prefs").set("volume", 1)
DEDANS["v"] = False; freiner_serveur()
s_ = [e for e in racine.enfants if e.Name == "TardisSonFrein"]
verifier("30. Dehors : le son part de la cabine, avec la portée des sons du dehors", len(s_) == 1 and s_[0].props.get("RollOffMaxDistance") == 220)
image(0.5, 21)
x.m_SetAttribute("Camouflage", True); freiner_serveur()
verifier("30. Dehors, cabine camouflée : aucun son", not [e for e in racine.enfants if e.Name == "TardisSonFrein"])
x.m_SetAttribute("Camouflage", None); sonFrein.set_parent(None); image(0.5, 21)
verifier("EffetsExterieurs : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])

# ------------------------------------------------------------------ 7. Ambiance : vent du vortex à bord (136)
module("Ambiance")
verifier("Ambiance se charge", not roblox.ERREURS, roblox.ERREURS[:3])
vortex = lambda: [e for e in SoundService.enfants if e.Name == "TardisVortex"]
x.m_SetAttribute("VolLibre", None); x.m_SetAttribute("VolPhase", None); x.m_SetAttribute("Etat", "Pose")
DEDANS["v"] = True; image(0.1, 30)
verifier("136. Sans Sound « Vortex » : rien, aucune erreur", not vortex() and not roblox.ERREURS)
sonVortex = Instance("Sound", "Vortex", sonsAssets); sonVortex.props["Volume"] = 0.8
image(0.1, 30)
verifier("136. Posé, à bord : pas de vent du vortex", not vortex())
x.m_SetAttribute("Etat", "Vol"); DEDANS["v"] = False; image(0.1, 30)
verifier("136. En vol, dehors : rien (seulement à bord)", not vortex())
DEDANS["v"] = True; image(0.1, 10)
v_ = vortex()
verifier("136. En vol, à bord : le vent du vortex joue en boucle, non positionné (SoundService)", len(v_) == 1 and v_[0].props.get("Looped") is True)
vol1 = v_[0].props["Volume"]; image(0.1, 60); vol2 = v_[0].props["Volume"]
verifier("136. En fondu jusqu'à 0,4 × volume des réglages", 0.1 < vol1 < vol2 and abs(vol2 - 0.4) < 0.01, (vol1, vol2))
UI.get("prefs").set("volume", 0.5); image(0.1)
verifier("136. Volume des réglages à 50 % : 0,2", abs(vortex()[0].props["Volume"] - 0.2) < 0.01, vortex()[0].props["Volume"])
x.m_SetAttribute("Jukebox", 3); image(0.1)
verifier("136. Le jukebox joue : le vent baisse de moitié", abs(vortex()[0].props["Volume"] - 0.1) < 0.01, vortex()[0].props["Volume"])
x.m_SetAttribute("Jukebox", None); UI.get("prefs").set("volume", 1)
DEDANS["v"] = False; image(0.1, 20)
verifier("136. On sort : le vent s'estompe…", vortex() and vortex()[0].props["Volume"] < 0.1)
image(0.1, 60)
verifier("136. … puis se coupe proprement (plus aucun son)", not vortex())
DEDANS["v"] = True; image(0.1, 60)
x.m_SetAttribute("Alimentation", False); image(0.1, 80)
verifier("136. Hors tension : le vent se tait et disparaît", not vortex())
x.m_SetAttribute("Alimentation", None); image(0.1, 60)
x.m_SetAttribute("Detruit", True); image(0.1, 80)
verifier("136. TARDIS détruit : silence", not vortex())
x.m_SetAttribute("Detruit", None)
x.m_SetAttribute("Mode", "Silencieux"); image(0.1, 60)
verifier("136. Voyage Silencieux (SilenceABord désactivé) : le vent reste à bord", len(vortex()) == 1)
Config.get("Modes").get("Silencieux").set("SilenceABord", True); image(0.1, 80)
verifier("136. Silencieux avec SilenceABord : le vent se tait et disparaît", not vortex())
Config.get("Modes").get("Silencieux").set("SilenceABord", False); x.m_SetAttribute("Mode", "Normal")
x.m_SetAttribute("Etat", "Pose"); image(0.1, 80)
verifier("136. Arrivée (posé) : le vent disparaît", not vortex())
x.m_SetAttribute("VolLibre", 202); x.m_SetAttribute("VolPhase", "Visible"); image(0.1, 40)
verifier("136. Vol libre matérialisé : pas de vent du vortex", not vortex())
x.m_SetAttribute("VolPhase", "Invisible"); image(0.1, 20)
verifier("136. Vol libre dématérialisé (dans le vortex) : le vent joue", len(vortex()) == 1)
x.m_SetAttribute("VolPhase", "Visible"); x.m_SetAttribute("VolVortex", True); image(0.1, 20)
verifier("136. Vol libre, bouton VORTEX : le vent joue aussi (un seul son)", len(vortex()) == 1)
x.m_SetAttribute("VolLibre", None); x.m_SetAttribute("VolVortex", None); x.m_SetAttribute("VolPhase", None); image(0.1, 80)
verifier("136. Fin du vol libre : plus aucun son", not vortex())
verifier("Ambiance : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])
amb = lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Ambiance.lua")
verifier("136. Pas de nouvelle boucle : le vent passe par la boucle Heartbeat du moteur et du jukebox", amb.count("RunService.Heartbeat:Connect") == 2 and "majVortex(dt, etat, alimente)" in amb)


# ------------------------------------------------------------------ 6. TardisEffets : le rotor suit la vitesse du vol libre (52)
plafond = Instance("Part", "Plafond", interieur); Instance("PointLight", "Lumiere", plafond)
G["script"] = Instance("LocalScript", "TardisEffets", game.m_FindFirstChild("StarterPlayer"))
tache(lambda: I.executer(lire("StarterPlayer/StarterPlayerScripts/TardisEffets.client.lua"), "TardisEffets"))
verifier("TardisEffets se charge (avec les maths réelles)", not roblox.ERREURS, roblox.ERREURS[:3])
course = lambda: rotor.m_GetPivot().p[1] - 1000
def vol_a(vitesse, secondes, **attrs):
    """Le pilote (un autre joueur) fait avancer la cabine à vitesse constante ; ce client la suit (VolLibreCF).
    Renvoie le nombre de passages du rotor par sa position de repos et le plus grand saut d'une image à l'autre."""
    for k, v in attrs.items(): x.m_SetAttribute(k, v)
    passages, saut, avant = 0, 0, course()
    for _ in range(int(secondes * 30)):
        cf = x.attrs.get("VolLibreCF") or x.m_GetPivot()
        x.m_SetAttribute("VolLibreCF", CF((cf.p[0], cf.p[1], cf.p[2] - vitesse / 30)))
        image()
        c = course()
        if (c > 0) != (avant > 0): passages += 1
        saut = max(saut, abs(c - avant)); avant = c
    for k in attrs: x.m_SetAttribute(k, None)
    return passages, saut
x.m_SetAttribute("Etat", "Pose"); x.m_SetAttribute("VolLibre", None); image(n=90)
verifier("52. Posé : le rotor est au repos", abs(course()) < 0.01, course())
x.m_SetAttribute("VolLibreCF", x.m_GetPivot()); x.m_SetAttribute("VolLibre", 202)
vol_a(0, 4)
lent = vol_a(0, 10)[0]
verifier("52. Vol libre à l'arrêt : vitesse normale du rotor (~6 passages en 10 s, Config.VitesseRotor = 2)", 5 <= lent <= 8, lent)
saut = vol_a(150, 4)[1]
verifier("52. La cabine accélère d'un coup : le rotor ne saute pas (phase cumulée)", saut < 0.35, saut)
rapide = vol_a(150, 10)[0]
verifier("52. TURBO (150 studs/s) : le rotor va 3 fois plus vite (~19 passages en 10 s)", 16 <= rapide <= 22 and rapide >= 2.5 * lent, (lent, rapide))
vol_a(75, 4); moyen = vol_a(75, 10)[0]
verifier("52. 75 studs/s : entre les deux (~2 fois, ~13 passages)", 10 <= moyen <= 15, moyen)
vol_a(220, 4, VolUrgence=True); urg = vol_a(220, 10, VolUrgence=True)[0]
verifier("52. URGENCE (220 studs/s) : 3 + 1 = 4 fois plus vite (~25 passages)", 22 <= urg <= 28, urg)
vol_a(150, 4, VolVortex=True); vtx = vol_a(150, 10, VolVortex=True)[0]
verifier("52. VORTEX en TURBO : 3,5 fois plus vite (~22 passages)", 19 <= vtx <= 25, vtx)
vol_a(0, 5); retour = vol_a(0, 10)[0]
verifier("52. La cabine s'arrête : le rotor revient à sa vitesse normale", 5 <= retour <= 8, retour)
x.m_SetAttribute("VolLibre", None); x.m_SetAttribute("VolLibreCF", None); image(n=150)
verifier("52. Fin du vol libre, posé : le rotor s'arrête en douceur", abs(course()) < 0.01, course())
eff = lire("StarterPlayer/StarterPlayerScripts/TardisEffets.client.lua")
verifier("52. Pas de nouvelle boucle par image (3 RenderStepped et 1 Heartbeat dans TardisEffets, comme avant)", eff.count("RunService.RenderStepped:Connect") == 3 and eff.count("RunService.Heartbeat:Connect") == 1)
verifier("52. Côté client seulement : aucune action réseau ajoutée", eff.count("FireServer") == 0)
erreursEffets = [l for l in roblox.SORTIE if "en erreur" in l]
verifier("TardisEffets : aucun effet en erreur", not roblox.ERREURS and not erreursEffets, (roblox.ERREURS[:2], erreursEffets[:3]))


# ================================================================== 2. Serveur : VolLibreFrein validé par le serveur (30)
roblox.ERREURS.clear()
vider_cache()
I2, G2, game2, pilote = monde(serveur=True)
R2 = {}
lancer(Fonction("config", py=lambda: R2.update(Config=premier(appeler(G2["require"], [game2.m_FindFirstChild("ReplicatedStorage").m_FindFirstChild("TardisConfig")])))))
Config2 = R2["Config"]; E2 = Config2.get("Etats")
xs = Instance("Model", "EXTERIEURE"); xs.m_SetAttribute("Etat", E2.get("Pose"))
rs_ = Instance("Part", "Racine", xs); rs_.props["Size"] = Valeur("Vector3", [4, 9, 4]); xs.props["PrimaryPart"] = rs_
partage = Table({"occupe": False})
stub = lambda nom, r=None: Fonction(nom, py=lambda *a: [] if r is None else [r])
ctx = Table({"Config": Config2, "E": E2, "Players": game2.m_FindFirstChild("Players"), "exterieur": xs, "interieur": Instance("Model", "INTERIEURE"),
             "partage": partage, "echelleNormale": 1, "hauteurNormale": 9,
             "chercherSol": Fonction("chercherSol", py=lambda *a: Valeur("Vector3", [0, 5, 0])), "dansInterieur": Fonction("dansInterieur", py=lambda *a: False),
             "emmenerALInterieur": stub("emmener"), "etatActuel": Fonction("etat", py=lambda: xs.attrs.get("Etat")), "fermerPortes": Fonction("fermerPortes", py=lambda: True),
             "jouer": stub("jouer"), "majEcran": stub("majEcran"), "majRamassage": stub("majRamassage"), "memoriserDepart": stub("memoriserDepart"),
             "setCollisionsExterieur": stub("collisions"), "tropPetitPourLesPortes": Fonction("petit", py=lambda *a: False), "verifierEau": stub("eau"),
             "jouerVoyage": stub("jouerVoyage"), "modeAutorise": Fonction("modeAutorise", py=lambda m, p=None: m)})
lancer(Fonction("vol", py=lambda: R2.update(V=premier(appeler(premier(I2.executer(lire("ServerScriptService/TardisServeur/VolLibre.lua"), "VolLibre")), [ctx])))))
V = R2["V"]
verifier("Serveur : module VolLibre chargé, freinerVol exporté", V is not None and V.get("freinerVol") is not None and not roblox.ERREURS, roblox.ERREURS[:2])
# Le vrai aiguillage des actions de TardisServeur (du début du gestionnaire jusqu'aux actions des pilotes)
serveur = lire("ServerScriptService/TardisServeur/init.server.lua")
debut = serveur.index("local function traiterOrdre(joueur, action, donnees, rappel)")  # V6.9.10.1 : le gestionnaire a un nom
fin_ = serveur.index("\t-- Copilote (V6.9.1) : seulement la navigation", debut)
canal = Instance("RemoteEvent", "TardisCommande_TARDIS_1", game2.m_FindFirstChild("ReplicatedStorage"))
GENERAL = []  # actions arrivées jusqu'au traitement des pilotes (délai entre deux ordres, activité…)
prelude = """
local remote, exterieur, Config, E, V, general = ...
local Players = game:GetService("Players")
local volLibre, reglagesVol = V.volLibre, V.reglagesVol
local recevoirPositionVol, changerPhaseVol, basculerPortesEnVol, lancerGlisse = V.recevoirPositionVol, V.changerPhaseVol, V.basculerPortesEnVol, V.lancerGlisse
local teleAtterrir, lancerDescente, freinerVol = V.teleAtterrir, V.lancerDescente, V.freinerVol
local function poserTardis() end
local function setCamouflage() end
"""
code = prelude + serveur[debut:fin_] + "\tgeneral(joueur, action)\nend\nremote.OnServerEvent:Connect(traiterOrdre)\n"
lancer(Fonction("aiguillage", py=lambda: I2.executer(code, "aiguillage-serveur", (canal, xs, Config2, E2, V, Fonction("general", py=lambda j, a: GENERAL.append(a) or [])))))
verifier("Serveur : vrai aiguillage des actions extrait et branché sur TardisCommande_TARDIS_1", len(canal.__lua_index__("OnServerEvent").connexions) == 1 and not roblox.ERREURS, roblox.ERREURS[:2])
autreJ = Instance("Player", "Amy", game2.m_FindFirstChild("Players")); autreJ.props.update({"UserId": 202, "DisplayName": "Amy"})
def envoyer(joueur_, *args):
    canal.__lua_index__("OnServerEvent").declencher(joueur_, *args); H.avancer(0.01)
changements = []
xs.m_GetAttributeChangedSignal("FreinTemps").connecter(Fonction("suivi", py=lambda: changements.append(xs.attrs.get("FreinTemps")) or []))
envoyer(pilote, "VolLibreFrein")
verifier("30. Serveur : pas de vol libre, pas de frein", xs.attrs.get("FreinTemps") is None)
lancer(Fonction("t", py=lambda: R2.update(ok=premier(appeler(V.get("demarrerVolLibre"), [pilote])))))
verifier("Serveur : vol libre démarré par le pilote 101", R2.get("ok") is True and xs.attrs.get("VolLibre") == 101)
H.avancer(2)
envoyer(autreJ, "VolLibreFrein")
verifier("30. Serveur : un autre joueur (pas le pilote du vol) est refusé", xs.attrs.get("FreinTemps") is None and not changements)
for mauvais in (5, "frein", Table({"force": 10}), Valeur("Vector3", [0, 0, 0]), True):
    envoyer(pilote, "VolLibreFrein", mauvais)
verifier("30. Serveur : données en trop (nombre, texte, table, Vector3, booléen) refusées", xs.attrs.get("FreinTemps") is None and not changements)
envoyer(pilote, "VolLibreFrein")
verifier("30. Serveur : le pilote, sans données : frein publié (FreinTemps = heure du serveur)", changements and abs(xs.attrs.get("FreinTemps") - (1000.0 + H.t)) < 0.05, xs.attrs.get("FreinTemps"))
premier_frein = xs.attrs.get("FreinTemps")
H.avancer(0.4); envoyer(pilote, "VolLibreFrein"); H.avancer(0.4); envoyer(pilote, "VolLibreFrein")
verifier("30. Serveur : deux autres freins en moins d'une seconde : un seul frein publié", len(changements) == 1 and xs.attrs.get("FreinTemps") == premier_frein, changements)
H.avancer(0.3); envoyer(pilote, "VolLibreFrein")
verifier("30. Serveur : une seconde après le premier : de nouveau accepté", len(changements) == 2, changements)
verifier("30. Serveur : VolLibreFrein ne passe jamais par le délai entre deux ordres (Config.Cooldown)", "VolLibreFrein" not in GENERAL, GENERAL)
envoyer(pilote, "ActionInconnue")
verifier("(contrôle : une action inconnue, elle, arrive au traitement des pilotes)", GENERAL == ["ActionInconnue"], GENERAL)
envoyer(pilote, 42)
verifier("30. Serveur : action qui n'est pas un texte ignorée", GENERAL == ["ActionInconnue"] and not roblox.ERREURS, (GENERAL, roblox.ERREURS[:2]))
H.avancer(1.1); envoyer(pilote, "VolLibreUrgence")
verifier("Serveur : urgence activée par le pilote", xs.attrs.get("VolUrgence") is True)
envoyer(pilote, "VolLibreFrein")
verifier("30. Serveur : en urgence, le frein est refusé (rien ne l'arrête, comme chez le pilote)", len(changements) == 2)
envoyer(pilote, "VolLibreUrgence"); H.avancer(1.1)
envoyer(pilote, "VolLibrePoser"); H.avancer(0.1)
verifier("Serveur : descente lancée (se poser)", V.get("volLibre").get("enDescente") is True)
envoyer(pilote, "VolLibreFrein")
verifier("30. Serveur : pendant la descente, le frein est refusé", len(changements) == 2)
H.avancer(6)
verifier("30. Serveur : fin du vol : FreinTemps effacé (rien ne se rejoue)", xs.attrs.get("VolLibre") is None and xs.attrs.get("FreinTemps") is None)
envoyer(pilote, "VolLibreFrein")
verifier("30. Serveur : posé, plus de frein", xs.attrs.get("FreinTemps") is None)
vlsrc = lire("ServerScriptService/TardisServeur/VolLibre.lua")
corps = vlsrc[vlsrc.index("local function freinerVol"):vlsrc.index("-- Vol de précision")]
code_frein = "\n".join(l.split("--")[0] for l in corps.splitlines())
verifier("30. Serveur : la recharge vient de Config.VolLibre.Frein.Recharge (propre à cette action, pas le délai général des ordres)",
         "(reglagesVol.Frein or {}).Recharge" in code_frein and "Cooldown" not in code_frein and "dernierOrdre" not in code_frein)

# Diagnostic des sons : Vortex et Frein listés
dsons = Instance("Folder", "Sons", Instance("Folder", "TardisAssets", game2.m_FindFirstChild("ReplicatedStorage")))
md = Instance("ModuleScript", "TardisDiagnostic", game2.m_FindFirstChild("ServerScriptService")); md.extra["chemin"] = DEPOT + "/ServerScriptService/TardisDiagnostic.lua"
xd = Instance("Model", "Cabine"); xd.props["PrimaryPart"] = Instance("Part", "Racine", xd)
idd = Instance("Model", "Salle")
lancer(Fonction("diag", py=lambda: R2.update(ligne=premier(appeler(premier(appeler(G2["require"], [md])), [Config2.get("Tardis").get(1), xd, idd])))))
ligne = R2.get("ligne") or ""
verifier("136. Diagnostic : le son Vortex (et Frein) dans la liste des sons", "Vortex" in ligne.split("sons absents")[-1] and "Frein" in ligne.split("sons absents")[-1], ligne[-200:])
Instance("Sound", "Vortex", dsons); Instance("Sound", "Frein", dsons)
lancer(Fonction("diag", py=lambda: R2.update(ligne=premier(appeler(premier(appeler(G2["require"], [md])), [Config2.get("Tardis").get(1), xd, idd])))))
verifier("136. Diagnostic : une fois posés dans TardisAssets › Sons, ils ne sont plus « absents »", "Vortex" not in R2["ligne"].split("sons absents")[-1] and "Frein" not in R2["ligne"].split("sons absents")[-1], R2["ligne"][-200:])
for e in list(dsons.enfants): e.set_parent(None)
# Sons de Config.Sons créés au démarrage : seulement avec un identifiant (Id 0 = rien)
bloc_sons = serveur[serveur.index("for nom, reglage in Config.Sons or {} do"):serveur.index("-- [nom] = { son extérieur, son intérieur }")]
lancer(Fonction("sons", py=lambda: I2.executer("local Config, dossierSons = ...\n" + bloc_sons, "sons-config", (Config2, dsons))))
verifier("136. Config.Sons.Vortex = 0 : aucun Sound créé (à poser dans Studio, ou à donner un identifiant)", dsons.m_FindFirstChild("Vortex") is None and dsons.m_FindFirstChild("Frein") is None)
Config2.get("Sons").set("Vortex", 1234567)
lancer(Fonction("sons", py=lambda: I2.executer("local Config, dossierSons = ...\n" + bloc_sons, "sons-config", (Config2, dsons))))
sv = dsons.m_FindFirstChild("Vortex")
verifier("136. Avec un identifiant : le Sound « Vortex » est créé au démarrage", sv is not None and sv.props.get("SoundId") == "rbxassetid://1234567", sv and sv.props.get("SoundId"))
verifier("Serveur : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])

print("\n".join("  ✓ " + o for o in OK)); print("\n".join("  ✗ " + k for k in KO))
print(f"V6.9.10 : {len(OK)}/{len(OK) + len(KO)} vérifications réussies")
sys.exit(1 if KO else 0)
