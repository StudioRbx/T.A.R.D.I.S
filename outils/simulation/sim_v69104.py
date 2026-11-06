"""Simulations de la V6.9.10.4 (sens du texte des écrans de la console) : le vrai module TardisServeur › Ecrans, avec des
maths réelles. Sur la face Top, le haut d'une SurfaceGui va vers la face Right de la pièce (Roblox) ; sur les faces
de côté, il suit le haut de la pièce. L'écran ingénieur (RotationEcran = Auto par défaut) tourne son contenu de 0, 90,
180 ou 270° pour que le haut du texte aille vers le haut du monde, ou vers le centre de la console s'il est à plat.
  1. Réglages : AttributRotation, RotationDestination 0, RotationIngenieur Auto, marqués « (V6.9.10.4) ».
  2. Sens automatique sur 7 poses (plaque inclinée des deux côtés, plaque tournée d'un quart de tour, pièce couchée
     sur le flanc, écran à plat, écran debout) : le haut du texte lu sur l'écran va vers le haut / l'intérieur.
  3. Quart de tour : les trois couches (affichage, hors tension, détruit) échangent largeur et hauteur ; les tailles
     minimales de texte suivent la hauteur lue.
  4. RotationEcran sur la pièce ou le Model : 0, 90, 180, 270, « auto », valeur inconnue (avertissement, 0) ; changé en jeu.
  5. Écrans de destination : jamais tournés par défaut ; RotationEcran accepté.
  6. Ligne de l'Output : le sens de chaque écran.
  7. (V6.9.10.5) Image de la face Top telle que Roblox la fait (largeur le long de Z, hauteur le long de X) : les couches
     tournées la remplissent exactement, plaque au grand côté le long de X ou de Z, sens 0, 90, 180, 270 et Auto."""
import os, sys, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from monde import *
import roblox
from roblox import Vec3, CF, activer_maths, _rx, _ry, _rz
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
def enfant_classe(o, classe, nom=None):
    return [e for e in o.enfants if e.ClassName == classe and (nom is None or e.Name == nom)]
def champ(g, nom):
    if g is None: return None
    for e in descendants(g):
        if e.Name == nom: return e
def texte_de(o): return str(o.props.get("Text", "")) if o is not None else None
R = {}

def piece(nom, parent, pos=(0, 0, 0), taille=(2, 2, 2), rot=None, classe="Part"):
    p = Instance(classe, nom, parent)
    p.props.update({"CFrame": CF(pos, rot), "Size": Vec3(*taille), "Position": Vec3(*pos)})
    return p

# ================================================================== 1. TardisConfig
vider_cache(); roblox.ERREURS.clear()
I, G, game, pilote = monde(serveur=True)
activer_maths(G)
rs = game.m_FindFirstChild("ReplicatedStorage"); Players = game.m_FindFirstChild("Players")
tache(lambda: R.update(Config=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisConfig")]))))
Config = R["Config"]; E = Config.get("Etats")
canal = Instance("RemoteEvent", "TardisCommande_TARDIS_1", rs)
pilote.attrs["TardisPilote_TARDIS_1"] = True
visiteur = Instance("Player", "Amy", Players); visiteur.props.update({"UserId": 202, "DisplayName": "Amy"})
SRC_ECRANS = lire("ServerScriptService/TardisServeur/Ecrans.lua")

def charger(construire, avancer=0.05):
    """Une salle : Console (Model, centre (0, 3, 0)) ; construire(console) y pose les écrans. Renvoie (cabine, salle, module, sortie)."""
    roblox.ERREURS.clear()
    xs = Instance("Model", "Cabine"); salle = Instance("Folder", "INTERIEURE")
    console = Instance("Model", "Console", salle)
    console.props.update({"BoiteCFrame": CF((0, 3, 0)), "BoiteTaille": Vec3(8, 4, 8)})
    piece("Socle", console, (0, 1.5, 0), (8, 3, 8))
    infos = construire(console) or {}
    xs.attrs.update({"Etat": "Pose", "Mode": "Normal", "Alimentation": True, "PointsDeVie": 80, "PV": 8000, "PVMax": 10000,
                     "RegulEnergie": 80, "RegulAir": 100, "RegulVapeur": 50, "BouclierEnergie": 100})
    ctx = Table({"Config": Config, "E": E, "Players": Players, "def": Config.get("Tardis").get(1), "exterieur": xs, "interieur": salle, "remote": canal,
                 "destinationChoisie": Fonction("destinationChoisie", py=lambda: [Instance("Part", "Site-19")]),
                 "etatActuel": Fonction("etatActuel", py=lambda: xs.attrs.get("Etat") or "Pose")})
    debut = len(roblox.SORTIE)
    res = {}
    tache(lambda: res.update(m=premier(appeler(premier(I.executer(SRC_ECRANS, "Ecrans")), [ctx]))))
    H.avancer(avancer)
    infos.update(xs=xs, salle=salle, console=console, module=res.get("m"), sortie=roblox.SORTIE[debut:], erreurs=list(roblox.ERREURS))
    return infos

gui_de = lambda p, nom="TardisEcranDestination": (enfant_classe(p, "SurfaceGui", nom) or [None])[0]
face_de = lambda g: g.props["Face"].nom.split(".")[-1] if g is not None else None
toile = lambda g, p: tuple(round(x * g.props["PixelsPerStud"], 3) for x in taille_face(p, face_de(g))) if g is not None else (0, 0)
def taille_face(p, face):
    """Taille (studs) de l'image d'une SurfaceGui, comme dans Roblox. V6.9.10.5 : sur Top et Bottom, le haut de l'image va
    vers la face Right (+X) : la largeur court le long de Z et la hauteur le long de X (avant : (X, Z), à l'envers)."""
    s = p.props["Size"]
    if face in ("Top", "Bottom"): return (s.z, s.x)
    if face in ("Left", "Right"): return (s.z, s.y)
    return (s.x, s.y)


import re
EC = Config.get("Ecrans")
verifier("1. Config.Ecrans : AttributRotation RotationEcran, RotationDestination 0, RotationIngenieur Auto",
         (EC.get("AttributRotation"), EC.get("RotationDestination"), EC.get("RotationIngenieur")) == ("RotationEcran", 0, "Auto"),
         (EC.get("AttributRotation"), EC.get("RotationDestination"), EC.get("RotationIngenieur")))
cfgsrc = lire("ReplicatedStorage/TardisConfig.lua")
bloc = cfgsrc[cfgsrc.index("Config.Ecrans = {"):cfgsrc.index("\n}", cfgsrc.index("Config.Ecrans = {"))]
nouv = [l for l in bloc.splitlines() if any(l.strip().startswith(n + " =") for n in ("AttributRotation", "RotationDestination", "RotationIngenieur"))]
verifier("1. Chaque nouveau réglage est marqué « (V6.9.10.4) »", len(nouv) == 3 and all("(V6.9.10.4)" in l for l in nouv), nouv)
verifier("1. Version 6.9.10.4 ou plus récente", str(Config.get("Version")).startswith("6.9.10.") and Config.get("Version") not in ("6.9.10", "6.9.10.1", "6.9.10.2", "6.9.10.3"), Config.get("Version"))

def mat_mul(a, b): return tuple(tuple(sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)) for i in range(3))
def col(R, j): return Vec3(R[0][j], R[1][j], R[2][j])
def neg(v): return Vec3(-v.x, -v.y, -v.z)
def dot(a, b): return a.x * b.x + a.y * b.y + a.z * b.z
def cross(a, b): return Vec3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
def repere(R, face):
    droite_p, haut_p, look = col(R, 0), col(R, 1), neg(col(R, 2))
    return {"Front": (look, haut_p), "Back": (neg(look), haut_p), "Right": (droite_p, haut_p), "Left": (neg(droite_p), haut_p),
            "Top": (haut_p, droite_p), "Bottom": (neg(haut_p), droite_p)}[face]
def haut_lu(p, gui):
    """Le haut du texte tel qu'il apparaît dans le monde : haut de la toile tourné de la rotation des couches."""
    R = p.props["CFrame"].R
    n, h = repere(R, face_de(gui))
    d = cross(neg(n), h)
    t = math.radians(champ(gui, "Fond").props.get("Rotation", 0))
    return Vec3(math.cos(t) * h.x + math.sin(t) * d.x, math.cos(t) * h.y + math.sin(t) * d.y, math.cos(t) * h.z + math.sin(t) * d.z), n
def voulu(p, n, centre=(0, 3, 0)):
    v = Vec3(-n.x * n.y, 1 - n.y * n.y, -n.z * n.y)
    if math.sqrt(dot(v, v)) < 0.35:
        pos = p.props["CFrame"].p
        d = Vec3(centre[0] - pos[0], centre[1] - pos[1], centre[2] - pos[2])
        k = dot(d, n); v = Vec3(d.x - n.x * k, d.y - n.y * k, d.z - n.z * k)
    l = math.sqrt(dot(v, v)) or 1
    return Vec3(v.x / l, v.y / l, v.z / l)

A30 = math.radians(30)
POSES = [
    ("plaque inclinée côté +X (face Top)", (4, 4, 0), (3, 0.2, 2), _rz(-A30)),
    ("plaque inclinée côté −X (face Top)", (-4, 4, 0), (3, 0.2, 2), _rz(A30)),
    ("plaque inclinée tournée d'un quart de tour (face Top)", (4, 4, 0), (2, 0.2, 3), mat_mul(_rz(-A30), _ry(math.pi / 2))),
    ("plaque inclinée côté +Z (face Top)", (0, 4, 4), (3, 0.2, 2), _rx(A30)),
    ("pièce couchée sur le flanc (face de côté, haut de la pièce à l'horizontale)", (0, 4, 4), (0.2, 3, 2), mat_mul(_rx(-A30), _rz(math.pi / 2))),
    ("écran à plat côté +X (le texte vers le centre)", (4, 4, 0), (3, 0.2, 2), None),
    ("écran debout, face vers l'extérieur", (0, 4, -4), (3, 2, 0.2), None),
]
for nom, pos, taille, rot in POSES:
    S = charger(lambda console, pos=pos, taille=taille, rot=rot: {"ing": piece("Ecran-Ingenieure", console, pos, taille, rot)})
    gi = gui_de(S["ing"], "TardisEcranIngenieur")
    if gi is None: verifier("2. " + nom, False, S["erreurs"][:2]); continue
    h, n = haut_lu(S["ing"], gi)
    ok = dot(h, voulu(S["ing"], n)) > 0.7
    verifier(f"2. {nom} : le haut du texte va vers le haut ou le centre (face {face_de(gi)}, sens {champ(gi, 'Fond').props.get('Rotation', 0)}°)", ok and not S["erreurs"],
             (face_de(gi), champ(gi, "Fond").props.get("Rotation"), round(dot(h, voulu(S["ing"], n)), 2), S["erreurs"][:2]))

# ================================================================== 3. Quart de tour
S = charger(lambda console: {"ing": piece("Ecran-Ingenieure", console, (4, 4, 0), (2, 0.2, 3), mat_mul(_rz(-A30), _ry(math.pi / 2)))})
gi = gui_de(S["ing"], "TardisEcranIngenieur")
rot = champ(gi, "Fond").props.get("Rotation", 0)
verifier("3. Cette pose demande un quart de tour (90 ou 270°)", rot in (90, 270), rot)
w, h_ = toile(gi, S["ing"])
couches = [champ(gi, n) for n in ("Fond", "Veille", "Detruit")]
verifier("3. Les trois couches tournent ensemble, centrées", all(c.props.get("Rotation") == rot and list(c.props["AnchorPoint"].args) == [0.5, 0.5]
         and [x for x in c.props["Position"].args] in ([0.5, 0.5], [0.5, 0, 0.5, 0]) for c in couches), [(c.Name, c.props.get("Rotation")) for c in couches])
verifier("3. … et échangent largeur et hauteur (elles remplissent la face une fois tournées)", all([round(x, 4) for x in c.props["Size"].args] == [round(h_ / w, 4), round(w / h_, 4)] for c in couches),
         [c.props["Size"].args for c in couches])
mins = [e.props.get("MinTextSize") for e in descendants(gi) if e.Name == "TailleMinimale"]
titre = champ(champ(gi, "Titre"), "TailleMinimale").props.get("MinTextSize")
verifier("3. Tailles minimales de texte calculées sur la hauteur lue (la largeur de la toile : 0,06 × largeur pour le titre)", titre == max(8, min(100, math.floor(w * 0.06 + 0.5))) and all(m >= 8 for m in mins), (titre, w, mins[:4]))
champ(gi, "Veille")  # présent
S["xs"].m_SetAttribute("Alimentation", False); H.avancer(0.2)
verifier("3. Hors tension : le voile tourné s'affiche", champ(gi, "Veille").props["Visible"] is True and champ(gi, "Veille").props.get("Rotation") == rot)

# ================================================================== 4. RotationEcran explicite
S = charger(lambda console: {"ing": piece("Ecran-Ingenieure", console, (4, 4, 0), (3, 0.2, 2), _rz(-A30))})
gi = gui_de(S["ing"], "TardisEcranIngenieur"); p = S["ing"]
sens = lambda: champ(gi, "Fond").props.get("Rotation", 0)
auto0 = sens()
resultats = []
for v in (0, 90, 180, 270, "90", 450):
    p.m_SetAttribute("RotationEcran", v); resultats.append(sens())
verifier("4. RotationEcran 0, 90, 180, 270 (nombre ou texte, 450 = 90) respecté, changé en jeu", resultats == [0, 90, 180, 270, 90, 90], resultats)
p.m_SetAttribute("RotationEcran", "AUTO")
verifier("4. « AUTO » (majuscules acceptées) : retour au sens automatique", sens() == auto0, (sens(), auto0))
n0 = len(roblox.SORTIE)
p.m_SetAttribute("RotationEcran", "penché")
verifier("4. Valeur inconnue : avertissement et sens 0", sens() == 0 and any("RotationEcran" in l and "penché" in l for l in roblox.SORTIE[n0:]), roblox.SORTIE[n0:][-2:])
p.m_SetAttribute("RotationEcran", None)
verifier("4. Attribut retiré : sens automatique", sens() == auto0)
def modele_rot(console):
    m = Instance("Model", "Ecran-Ingenieure", console); m.attrs["RotationEcran"] = 270
    piece("Vitre", m, (4, 4, 0), (3, 0.05, 2), _rz(-A30))
    return {"m": m}
S = charger(modele_rot); vitre = [e for e in S["m"].enfants if e.Name == "Vitre"][0]
gi = gui_de(vitre, "TardisEcranIngenieur")
verifier("4. RotationEcran posé sur le Model : respecté", gi is not None and champ(gi, "Fond").props.get("Rotation") == 270, gi and champ(gi, "Fond").props.get("Rotation"))
verifier("4. Aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])

# ================================================================== 5. Écrans de destination
S = charger(lambda console: {"e": piece("Ecran", console, (0, 4, 4), (0.2, 3, 2), mat_mul(_rx(-A30), _rz(math.pi / 2)))})
gd = gui_de(S["e"])
verifier("5. Écran de destination couché sur le flanc : pas tourné par défaut (RotationDestination 0)", champ(gd, "Fond").props.get("Rotation", 0) == 0)
S["e"].m_SetAttribute("RotationEcran", "Auto")
h, n = haut_lu(S["e"], gd)
verifier("5. … RotationEcran = Auto sur lui : remis droit", dot(h, voulu(S["e"], n)) > 0.7, champ(gd, "Fond").props.get("Rotation"))

# ================================================================== 6. Output
def complet(console):
    piece("Ecran", console, (0, 4, -4), (2, 1.2, 0.1))
    piece("Ecran-Ingenieure", console, (4, 4, 0), (3, 0.2, 2), _rz(-A30))
S = charger(complet, avancer=0.05)
L = ([l for l in S["sortie"] if "écrans de la console" in l] or [""])[0]
verifier("6. L'Output donne le sens de chaque écran (0° pour la destination, auto pour l'ingénieur)",
         "face Front, sens 0° (1024 × 614 px)" in L and re.search(r"ingénieur « Console › Ecran-Ingenieure » : face Top \(auto\), sens \d+° \(auto\)", L) is not None, L)

# ================================================================== 7. (V6.9.10.5) Les couches tournées remplissent EXACTEMENT la face Top
# Image de la face Top dans Roblox : largeur le long de Z, hauteur le long de X (haut de l'image = face Right). Une fois
# tournées, les couches doivent couvrir toute l'image (ni bande étroite, ni débord), et le contenu lu doit avoir toute la
# largeur de la face dans le sens de la lecture.
def emprise(c, Wp, Hp):
    """Taille (pixels) occupée sur l'image par une couche (taille relative, rotation en degrés)."""
    lw, lh = c.props["Size"].args[0] * Wp, c.props["Size"].args[1] * Hp
    t = math.radians(c.props.get("Rotation", 0))
    return abs(math.cos(t)) * lw + abs(math.sin(t)) * lh, abs(math.sin(t)) * lw + abs(math.cos(t)) * lh, lw, lh
def largeur_lue_studs(p, gui):
    """Étendue de la face (studs) le long de la droite du texte lu."""
    R = p.props["CFrame"].R
    n, h = repere(R, face_de(gui))
    d = cross(neg(n), h)
    t = math.radians(champ(gui, "Fond").props.get("Rotation", 0))
    droite = Vec3(math.cos(t) * d.x - math.sin(t) * h.x, math.cos(t) * d.y - math.sin(t) * h.y, math.cos(t) * d.z - math.sin(t) * h.z)
    taille = p.props["Size"]
    return abs(dot(droite, col(R, 0))) * taille.x + abs(dot(droite, col(R, 2))) * taille.z
CAS_TOP = [("grand côté le long de X", (3, 0.2, 2)), ("grand côté le long de Z", (2, 0.2, 3))]
for nom_cas, taille in CAS_TOP:
    for sens in (90, 270, 0, 180, "Auto"):
        def plaque(console, taille=taille, sens=sens):
            p = piece("Ecran-Ingenieure", console, (4, 4, 0), taille, _rz(-A30)); p.attrs["FaceEcran"] = "Top"; p.attrs["RotationEcran"] = sens
            return {"ing": p}
        S = charger(plaque); gi = gui_de(S["ing"], "TardisEcranIngenieur")
        if gi is None: verifier(f"7. Face Top, {nom_cas}, sens {sens}", False, S["erreurs"][:2]); continue
        Wp, Hp = toile(gi, S["ing"])
        couches = [champ(gi, n_) for n_ in ("Fond", "Veille", "Detruit")]
        empr = [emprise(c, Wp, Hp) for c in couches]
        remplit = all(abs(e[0] - Wp) < 0.5 and abs(e[1] - Hp) < 0.5 for e in empr)
        lue = largeur_lue_studs(S["ing"], gi)
        pleine = abs(empr[0][2] / gi.props["PixelsPerStud"] - lue) < 0.01
        verifier(f"7. Face Top, {nom_cas}, sens {sens} (→ {champ(gi, 'Fond').props.get('Rotation', 0)}°) : les 3 couches remplissent exactement l'image "
                 f"({Wp:.0f} × {Hp:.0f} px), le texte a toute la largeur de la face ({lue:g} studs)", remplit and pleine and not S["erreurs"],
                 ([(round(e[0]), round(e[1])) for e in empr], (Wp, Hp), round(empr[0][2] / gi.props["PixelsPerStud"], 3), lue, S["erreurs"][:2]))
# Le cas de la capture du propriétaire (V6.9.10.4) : avec l'ancienne taille (X, Z), la couche tournée d'un quart de tour
# ne couvrait qu'une bande étroite au milieu de la face (2/3 de la largeur lue × toute la hauteur, pour 3 × 2 studs)
def plaque_90(console):
    p = piece("Ecran-Ingenieure", console, (4, 4, 0), (3, 0.2, 2), _rz(-A30)); p.attrs["RotationEcran"] = 90
    return {"ing": p}
S = charger(plaque_90)
p_ = S["ing"]; gi = gui_de(p_, "TardisEcranIngenieur")
Wp, Hp = toile(gi, p_)
ancienne = (2 * 2 / 3, 3 * 3 / 2)  # tailles qu'avait la couche avec (X, Z) : (Z/X, X/Z) de la vraie image (2 × 3 studs)
vraie = emprise(champ(gi, "Fond"), Wp, Hp)
verifier("7. Sans la correction, la couche tournée ne faisait que 1,33 stud de large lu sur 3 (la bande étroite de la capture) ; maintenant 3",
         abs(ancienne[0] - 4 / 3) < 1e-9 and abs(vraie[2] / gi.props["PixelsPerStud"] - 3) < 0.01, (ancienne, round(vraie[2] / gi.props["PixelsPerStud"], 3)))
L = ([l for l in S["sortie"] if "écrans de la console" in l] or [""])[0]
verifier("7. Ligne de l'Output : taille de l'image lue, quart de tour (3 studs de large → 1024 px, 2 de haut → 683 px)", "face Top (auto), sens 90° (1024 × 683 px)" in L, L)
src_ecrans = SRC_ECRANS[SRC_ECRANS.index("local function tailleFace"):SRC_ECRANS.index("local function finesse")]
verifier("7. Code : tailleFace rend (Size.Z, Size.X) pour Top et Bottom", "return taille.Z, taille.X end" in src_ecrans and "return taille.X, taille.Z" not in src_ecrans, src_ecrans[:200])

print("\n".join("  ✓ " + o for o in OK)); print("\n".join("  ✗ " + k for k in KO))
print(f"V6.9.10.4 : {len(OK)}/{len(OK) + len(KO)} vérifications réussies")
sys.exit(1 if KO else 0)
