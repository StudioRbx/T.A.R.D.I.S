"""Simulations de la V7.5.3 (régénération : poses du corps) : le vrai code, exécuté avec de faux objets Roblox et des
maths réelles (Vector3 et CFrame calculables, roblox.activer_maths).
  1. TardisConfig : réglages Config.Regeneration.Poses et calculs purs (poseRegeneration, tremblement, poseDecouverte).
  2. TardisSystemes (le vrai code des poses, extrait du script) : pose par style (G-201), flexion puis redressement
     (G-203), lévitation (G-204), assis (G-218), mains qui tremblent (G-205), découverte des mains (G-202).
  3. Sources : branchement dans la régénération (style, vitesses gardées jusqu'à la fin du geste, choix)."""
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
def proche(a, b, e=1e-6): return a is not None and b is not None and abs(float(a) - float(b)) <= e
def vec(v): return tuple(float(v.__lua_index__(k)) for k in "XYZ")
def liste(t): return [t.get(i) for i in (1, 2, 3)] if t is not None else None
def meme(a, b, e=1e-6):
    return isinstance(a, CF) and isinstance(b, CF) and all(abs(x - y) <= e for x, y in zip(a.p, b.p)) \
        and all(abs(a.R[i][j] - b.R[i][j]) <= e for i in range(3) for j in range(3))
_isa = roblox.Instance.m_IsA
roblox.Instance.m_IsA = lambda s, c: (c == "JointInstance" and s.ClassName in ("Weld", "Motor6D")) or _isa(s, c)

# ================================================================== 1. TardisConfig
vider_cache()
I, G, game, joueur = monde(serveur=False)
activer_maths(G)
rs = game.m_FindFirstChild("ReplicatedStorage")
R = {}
tache(lambda: R.update(Config=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisConfig")]))))
Config = R["Config"]
f = lambda nom, *a: premier(appeler(Config.get(nom), list(a)))
fs = lambda nom, *a: appeler(Config.get(nom), list(a))
verifier("Config.Version ≥ 7.5.3 (7.5.3 à sa sortie)", tuple(int(n) for n in Config.get("Version").split(".")) >= (7, 5, 3), Config.get("Version"))
REGEN = Config.get("Regeneration")
P = REGEN.get("Poses")
verifier("Config.Regeneration.Poses : par style, tremblement (4°), genou à terre (22°, 0,6 stud)",
         P and (P.get("ParStyle"), P.get("Tremblement"), P.get("AmplitudeTremblement"), P.get("GenouATerre"), P.get("Flexion"), P.get("Baisse")) == (True, True, 4, True, 22, 0.6))
verifier("Config.Regeneration.Poses : assis, lévitation (1,5 stud), regard des mains (2,6 s)",
         (P.get("Assis"), P.get("Levitation"), P.get("HauteurLevitation"), P.get("RegarderMains"), P.get("DureeRegardMains")) == (True, True, 1.5, True, 2.6))

def pose(style, assis=False):
    p = f("poseRegeneration", style, assis)
    a = p.get("articulations")
    return {k: liste(a.get(k)) for k in ("Right Shoulder", "Left Shoulder", "Neck", "Right Hip", "Left Hip")}, p
c1, p1 = pose(1)
verifier("G-201 : le style Classique garde la pose d'avant (épaules -72° et ±8°, tête -28°, hanches -6°)",
         c1 == {"Right Shoulder": [-72, 0, 8], "Left Shoulder": [-72, 0, -8], "Neck": [-28, 0, 0], "Right Hip": [-6, 0, 0], "Left Hip": [-6, 0, 0]}
         and p1.get("cambrure") == 0 and p1.get("acoups") is False and p1.get("levitation") is False, c1)
poses = {s: pose(s) for s in range(1, 8)}
verifier("G-201 : les six autres styles ont chacun leur pose (Fracture : celle du Classique, par à-coups)",
         len({str(poses[s][0]) for s in range(1, 7)}) == 6 and poses[7][0] == c1, {s: poses[s][0]["Right Shoulder"] for s in poses})
verifier("G-201 : Colonne lève les bras au ciel (plus de 150°), Douce à peine (moins de 30°)",
         poses[5][0]["Right Shoulder"][0] <= -150 and poses[3][0]["Right Shoulder"][0] >= -30)
verifier("G-201 : la gauche est le miroir de la droite (y et z opposés), pour chaque style",
         all(poses[s][0]["Left Shoulder"] == [poses[s][0]["Right Shoulder"][0], -poses[s][0]["Right Shoulder"][1], -poses[s][0]["Right Shoulder"][2]] for s in poses))
verifier("G-201 : cambrure pour Volcan (12°), Colonne (6°), Supernova (8°) seulement",
         [poses[s][1].get("cambrure") for s in range(1, 8)] == [0, 12, 0, 0, 6, 8, 0])
verifier("G-204 : lévitation pour Douce et Colonne seulement ; G-201 : à-coups pour Fracture seulement",
         [poses[s][1].get("levitation") for s in range(1, 8)] == [False, False, True, False, True, False, False]
         and [poses[s][1].get("acoups") for s in range(1, 8)] == [False] * 6 + [True])
verifier("Style inconnu ou absent → Classique", pose(42)[0] == c1 and pose(None)[0] == c1)
ca, pa = pose(2, True)
verifier("G-218 : assis : bras au ciel (-160°), tête renversée, sans les jambes, sans cambrure ni lévitation",
         ca["Right Shoulder"] == [-160, 0, 0] and ca["Neck"] == [-25, 0, 0] and ca["Right Hip"] is None and ca["Left Hip"] is None
         and pa.get("cambrure") == 0 and pa.get("levitation") is False, ca)

tr = [fs("tremblement", i * 0.013, 4) for i in range(800)]
verifier("G-205 : tremblement jamais plus que l'amplitude (4°), sur x comme sur z", all(abs(x) <= 4 + 1e-9 and abs(z) <= 4 + 1e-9 for x, z in tr))
verifier("G-205 : … et il tremble vraiment (dépasse 3° et change de signe)", max(abs(x) for x, _ in tr) > 3 and min(x for x, _ in tr) < 0 < max(x for x, _ in tr))
verifier("G-205 : amplitude 0 → immobile ; sans valeur → 4°", all(abs(v) < 1e-12 for v in fs("tremblement", 0.7, 0)) and
         all(proche(a, b) for a, b in zip(fs("tremblement", 0.7, None), fs("tremblement", 0.7, 4))))
d1, d2 = f("poseDecouverte", 1), f("poseDecouverte", 2)
verifier("G-202 : découverte, temps 1 : les deux mains devant les yeux (100° vers l'avant), tête baissée (20°)",
         liste(d1.get("Right Shoulder")) == [0, 25, 100] and liste(d1.get("Left Shoulder")) == [0, -25, -100] and liste(d1.get("Neck")) == [20, 0, 0])
verifier("G-202 : découverte, temps 2 : la main droite au visage (150°), la gauche redescend",
         liste(d2.get("Right Shoulder")) == [0, 40, 150] and liste(d2.get("Left Shoulder")) == [0, 0, 0] and liste(d2.get("Neck")) == [5, 0, 0])

# ================================================================== 2. Le vrai code (serveur)
TW = []
class FauxTween(roblox.Instance):
    def m_Create(s, obj, info, props):
        d = dict(props.h); TW.append((obj, d))
        for k, v in d.items(): obj.props[k] = v
        return roblox.Instance("Tween")
tween = FauxTween("TweenService")
sysrc = lire("ServerScriptService/TardisSystemes.server.lua")
d_p = sysrc.index("-- Pose de la série (R6)"); f_p = sysrc.index("-- Chute dans le vide (V6.9.7)")
extrait = sysrc[d_p:f_p]
code = ("local Config, REGEN, TweenFaux = ...\n" + extrait.replace('game:GetService("TweenService")', "TweenFaux") +
        "\nreturn { pose = poseRegeneration, trembler = tremblerMains, geste = gesteDecouverte }\n"
        "  , { mul = function(o, x, y, z) return o * (CFrame.Angles(math.rad(x), 0, 0) * CFrame.Angles(0, math.rad(y), 0) * CFrame.Angles(0, 0, math.rad(z))) end,\n"
        "      racine = function(o, b, p) return CFrame.new(0, -b, 0) * CFrame.Angles(-math.rad(p), 0, 0) * o end,\n"
        "      lerp = function(o, x, y, z, k) return o:Lerp(o * (CFrame.Angles(math.rad(x), 0, 0) * CFrame.Angles(0, math.rad(y), 0) * CFrame.Angles(0, 0, math.rad(z))), k) end }\n")
tache(lambda: R.update(r=I.executer(code, "poses_serveur", (Config, REGEN, tween))))
r = R.get("r") or [None, None]
M, A = (r[0], r[1]) if len(r) >= 2 else (None, None)
verifier("Vrai code des poses extrait de TardisSystemes (poseRegeneration, tremblerMains, gesteDecouverte), sans erreur",
         M is not None and A is not None and not roblox.ERREURS, (r, roblox.ERREURS[:3]))
appel = lambda nom, *a: tache(lambda: appeler(M.get(nom), list(a)))
mul = lambda o, a: premier(appeler(A.get("mul"), [o] + list(a)))
rac = lambda o, b, p: premier(appeler(A.get("racine"), [o, b, p]))

ws = game.m_FindFirstChild("Workspace")
ORIG = {"Right Shoulder": CF((1, 0.5, 0)), "Left Shoulder": CF((-1, 0.5, 0)), "Neck": CF((0, 1, 0)), "Right Hip": CF((1, -1, 0)), "Left Hip": CF((-1, -1, 0))}
def personnage(assis=False):
    p = Instance("Model", "Voyageur", ws)
    h = Instance("Humanoid", "Humanoid", p); h.props["Sit"] = assis
    t = Instance("Part", "Torso", p)
    for n, c in ORIG.items():
        m = Instance("Motor6D", n, t); m.props["C0"] = c
    hrp = Instance("Part", "HumanoidRootPart", p); hrp.props["Position"] = Vec3(0, 3, 0); hrp.props["CFrame"] = CF((0, 3, 0))
    rj = Instance("Motor6D", "RootJoint", hrp); rj.props["C0"] = CF((0, 0, 0))
    return p
def mot(p, n): return (p.m_FindFirstChild("HumanoidRootPart") if n == "RootJoint" else p.m_FindFirstChild("Torso")).m_FindFirstChild(n)
def c0(p, n): return mot(p, n).props["C0"]
def au_repos(p): return all(meme(c0(p, n), ORIG[n]) for n in ORIG) and meme(c0(p, "RootJoint"), CF((0, 0, 0)))
def sans_attribut(p): return all(mot(p, n).attrs.get("TardisC0") is None for n in list(ORIG) + ["RootJoint"])
def en_pose(p, articulations, noms=None):
    return all(meme(c0(p, n), mul(ORIG[n], articulations[n])) for n in (noms or articulations))

# Classique : flexion, puis redressement
p = personnage()
appel("pose", p, True, 1.0, 1, 8)
verifier("G-203 : d'abord le corps fléchit : penché en avant de 22° et abaissé de 0,6 stud (RootJoint, repère de la racine)",
         meme(c0(p, "RootJoint"), rac(CF((0, 0, 0)), 0.6, 22)))
verifier("G-203 : … un genou presque à terre (hanche droite en arrière, gauche en avant), la tête baissée",
         meme(c0(p, "Right Hip"), mul(ORIG["Right Hip"], [0, 0, -50])) and meme(c0(p, "Left Hip"), mul(ORIG["Left Hip"], [0, 0, -35])) and meme(c0(p, "Neck"), mul(ORIG["Neck"], [15, 0, 0])))
verifier("Les C0 d'origine sont gardés (attribut TardisC0) pour le retour", all(meme(mot(p, n).attrs.get("TardisC0"), ORIG[n]) for n in ORIG))
H.avancer(0.81)
verifier("G-203 : puis il se redresse d'un coup (à 80 % du temps de pose) : la pose du Classique, le corps droit",
         en_pose(p, c1) and meme(c0(p, "RootJoint"), CF((0, 0, 0))), [c0(p, "Right Shoulder").p])
appel("pose", p, False)
verifier("Retour au repos : chaque articulation reprend son C0 d'origine, attributs effacés", au_repos(p) and sans_attribut(p))

# Volcan : cambrure
p = personnage(); appel("pose", p, True, 1.0, 2, 8); H.avancer(0.81)
verifier("G-201 : Volcan : bras plus haut (-88°), tête très renversée, dos cambré de 12° (vers l'arrière)",
         en_pose(p, poses[2][0], ["Right Shoulder", "Left Shoulder", "Neck", "Right Hip"]) and meme(c0(p, "RootJoint"), rac(CF((0, 0, 0)), 0, -12)))
appel("pose", p, False)

# Jeton : un retour avant le redressement annule le redressement
p = personnage(); appel("pose", p, True, 1.0, 1, 8); appel("pose", p, False); H.avancer(1)
verifier("Un nouvel ordre de pose annule les étapes encore prévues (pas de redressement après un retour au repos)", au_repos(p) and sans_attribut(p))

# Fracture : à-coups
p = personnage(); appel("pose", p, True, 1.0, 7, 8); H.avancer(0.01)
lerp = lambda o, a, k: premier(appeler(A.get("lerp"), [o] + list(a) + [k]))
verifier("G-201 : Fracture : pas de flexion, la pose arrive par crans (un quart d'abord)",
         meme(c0(p, "Right Shoulder"), lerp(ORIG["Right Shoulder"], c1["Right Shoulder"], 0.25)) and meme(c0(p, "RootJoint"), CF((0, 0, 0))))
H.avancer(0.26)
verifier("G-201 : … puis la moitié (au deuxième cran)", meme(c0(p, "Right Shoulder"), lerp(ORIG["Right Shoulder"], c1["Right Shoulder"], 0.5)))
H.avancer(0.6)
verifier("G-201 : … et toute la pose au quatrième cran", en_pose(p, c1))
appel("pose", p, False)

# Assis
p = personnage(assis=True); appel("pose", p, True, 1.0, 5, 8); H.avancer(1)
verifier("G-218 : assis : bras au ciel et tête renversée, sans flexion ni lévitation, les jambes et le corps ne bougent pas",
         en_pose(p, ca, ["Right Shoulder", "Left Shoulder", "Neck"]) and meme(c0(p, "Right Hip"), ORIG["Right Hip"]) and meme(c0(p, "RootJoint"), CF((0, 0, 0)))
         and mot(p, "Right Hip").attrs.get("TardisC0") is None and p.m_FindFirstChild("HumanoidRootPart").m_FindFirstChild("TardisRegenLevitation") is None)
appel("pose", p, False)

# Lévitation (Douce, régénération de 8 s)
p = personnage(); hrp = p.m_FindFirstChild("HumanoidRootPart")
appel("pose", p, True, 1.2, 3, 8)
H.avancer(1.19)
verifier("G-204 : pas de lévitation avant 15 % de la durée", hrp.m_FindFirstChild("TardisRegenLevitation") is None)
H.avancer(0.02)
al = hrp.m_FindFirstChild("TardisRegenLevitation"); pt = hrp.m_FindFirstChild("TardisRegenLevitationPoint")
verifier("G-204 : Douce : à 15 %, un AlignPosition (une attache, 1e5 de force) soulève le corps de 1,5 stud",
         al is not None and al.ClassName == "AlignPosition" and pt is not None and pt.ClassName == "Attachment" and al.props.get("Attachment0") is pt
         and al.props.get("MaxForce") == 1e5 and proche(vec(al.props["Position"])[1], 4.5), al and al.props.get("Position"))
H.avancer(3.2)
verifier("G-204 : … puis il redescend (à 55 %) à sa place", al.parent is not None and proche(vec(al.props["Position"])[1], 3))
H.avancer(1.5)
verifier("G-204 : … et la lévitation disparaît avant la fin", al.parent is None and pt.parent is None)
appel("pose", p, False)
p = personnage(); hrp = p.m_FindFirstChild("HumanoidRootPart"); appel("pose", p, True, 1.2, 5, 8); H.avancer(1.3)
verifier("G-204 : Colonne flotte aussi", hrp.m_FindFirstChild("TardisRegenLevitation") is not None)
appel("pose", p, False)
verifier("G-204 : le retour au repos retire la lévitation tout de suite", hrp.m_FindFirstChild("TardisRegenLevitation") is None and hrp.m_FindFirstChild("TardisRegenLevitationPoint") is None)
p = personnage(); hrp = p.m_FindFirstChild("HumanoidRootPart"); appel("pose", p, True, 1.2, 1, 8); H.avancer(3)
verifier("G-204 : pas de lévitation pour le Classique", hrp.m_FindFirstChild("TardisRegenLevitation") is None)
appel("pose", p, False)

# Réglages coupés
P.set("ParStyle", False); P.set("GenouATerre", False); P.set("Levitation", False)
p = personnage(); hrp = p.m_FindFirstChild("HumanoidRootPart"); appel("pose", p, True, 1.0, 5, 8)
verifier("ParStyle = false : la pose du Classique pour tous les styles ; GenouATerre = false : pas de flexion",
         en_pose(p, c1) and meme(c0(p, "RootJoint"), CF((0, 0, 0))))
H.avancer(2)
verifier("Levitation = false : il ne flotte pas", hrp.m_FindFirstChild("TardisRegenLevitation") is None)
appel("pose", p, False)
P.set("ParStyle", True); P.set("GenouATerre", True); P.set("Levitation", True)

# Tremblement des mains
p = personnage()
R4 = {}
tache(lambda: R4.update(stop=premier(appeler(M.get("trembler"), [p]))))
H.avancer(0.5)
def ecart(m, o):
    # angle de la rotation relative (degrés)
    Rm, Ro = m.R, o.R
    tr_ = sum(Ro[k][i] * Rm[k][i] for i in range(3) for k in range(3))
    return math.degrees(math.acos(max(-1, min(1, (tr_ - 1) / 2))))
e1, e2 = ecart(c0(p, "Right Shoulder"), ORIG["Right Shoulder"]), ecart(c0(p, "Left Shoulder"), ORIG["Left Shoulder"])
verifier("G-205 : pendant le choix, les deux mains tremblent (rotation de l'épaule, 6° au plus en tout)",
         0.05 < e1 <= 4 * math.sqrt(2) + 1e-6 and 0.05 < e2 <= 4 * math.sqrt(2) + 1e-6 and meme(c0(p, "Neck"), ORIG["Neck"]), (e1, e2))
avant = c0(p, "Right Shoulder"); H.avancer(0.07)
verifier("G-205 : … et le tremblement bouge sans cesse", not meme(c0(p, "Right Shoulder"), avant))
tache(lambda: appeler(R4["stop"], []))
verifier("G-205 : à la fin du choix, les épaules reviennent exactement à leur place, attribut effacé",
         meme(c0(p, "Right Shoulder"), ORIG["Right Shoulder"]) and meme(c0(p, "Left Shoulder"), ORIG["Left Shoulder"]) and sans_attribut(p))
H.avancer(0.3)
verifier("G-205 : … et plus rien ne bouge ensuite", meme(c0(p, "Right Shoulder"), ORIG["Right Shoulder"]))
P.set("Tremblement", False)
tache(lambda: R4.update(stop2=premier(appeler(M.get("trembler"), [p])))); H.avancer(0.3)
verifier("Tremblement = false : rien ne tremble (et l'arrêt ne fait rien)", meme(c0(p, "Right Shoulder"), ORIG["Right Shoulder"]) and R4.get("stop2") is not None)
P.set("Tremblement", True)

# Découverte des mains
FINI = []
p = personnage(); appel("pose", p, True, 1.2, 3, 8); H.avancer(1.25)
hrp = p.m_FindFirstChild("HumanoidRootPart")
appel("geste", p, Fonction("fini", py=lambda *a: FINI.append(H.t) or []))
verifier("G-202 : à la fin, il regarde ses mains (devant les yeux, tête baissée), le corps se redresse, il ne flotte plus",
         en_pose(p, {k: liste(d1.get(k)) for k in ("Right Shoulder", "Left Shoulder", "Neck")}) and meme(c0(p, "Right Hip"), ORIG["Right Hip"])
         and meme(c0(p, "RootJoint"), CF((0, 0, 0))) and hrp.m_FindFirstChild("TardisRegenLevitation") is None and not FINI)
t0 = H.t
H.avancer(2.6 * 0.55 + 0.01)
verifier("G-202 : … puis (à 55 % des 2,6 s) la main droite touche son visage", en_pose(p, {k: liste(d2.get(k)) for k in ("Right Shoulder", "Left Shoulder", "Neck")}) and not FINI)
H.avancer(2.6 * 0.45)
verifier("G-202 : … puis il revient au repos, et la fin est annoncée une seule fois (il peut repartir)",
         au_repos(p) and sans_attribut(p) and len(FINI) == 1 and proche(FINI[0] - t0, 2.6, 0.02), FINI)
H.avancer(2)
verifier("G-202 : … les étapes du lévitation encore prévues ne reviennent pas", hrp.m_FindFirstChild("TardisRegenLevitation") is None and au_repos(p))
FINI.clear()
p = personnage(); appel("pose", p, True, 1.0, 1, 8); H.avancer(1)
appel("geste", p, Fonction("fini", py=lambda *a: FINI.append(1) or [])); appel("pose", p, True, 1.0, 1, 8)
H.avancer(3)
verifier("G-202 : une nouvelle régénération pendant le geste l'interrompt (le geste ne remet pas le repos) et la fin est annoncée",
         len(FINI) == 1 and not au_repos(p) and en_pose(p, c1))
appel("pose", p, False); FINI.clear()
P.set("RegarderMains", False)
p = personnage(); appel("pose", p, True, 1.0, 1, 8); H.avancer(1)
appel("geste", p, Fonction("fini", py=lambda *a: FINI.append(1) or []))
verifier("RegarderMains = false : retour au repos tout de suite, fin annoncée tout de suite", len(FINI) == 1 and au_repos(p) and sans_attribut(p))
P.set("RegarderMains", True); FINI.clear()
p = personnage(assis=True); appel("pose", p, True, 1.0, 1, 8); H.avancer(1)
appel("geste", p, Fonction("fini", py=lambda *a: FINI.append(1) or []))
verifier("G-218 : assis, pas de geste des mains : retour au repos tout de suite", len(FINI) == 1 and au_repos(p))
FINI.clear()
p = Instance("Model", "SansTorse", ws); Instance("Humanoid", "Humanoid", p).props["Sit"] = False
appel("pose", p, True, 1.0, 2, 8); appel("geste", p, Fonction("fini", py=lambda *a: FINI.append(1) or [])); H.avancer(3)
verifier("Un corps sans articulations R6 (R15) : rien ne casse, la fin est annoncée", len(FINI) == 1 and not roblox.ERREURS, roblox.ERREURS[:2])

# ================================================================== 3. Sources (branchement)
der = sysrc[sysrc.index("local function derouler(changerTenue)"):sysrc.index("-- Chute dans le vide (V6.9.7) : on retient")]
verifier("La régénération passe son style et sa durée à la pose",
         "poseRegeneration(personnage, true, math.max((REGEN.Duree or 7) * 0.15, 0.5), style, duree)" in der
         and der.index("personnage:SetAttribute(\"TardisRegenerationStyle\", style)") < der.index("poseRegeneration(personnage, true"))
verifier("Vitesses d'avant gardées une seule fois (pas de 0 retenu si une régénération recommence pendant le geste)",
         "if not vitessesAvant then vitessesAvant = { humanoid.WalkSpeed, humanoid.JumpPower, humanoid.JumpHeight } end" in der
         and "local vitesse, saut, hauteurSaut" not in der)
fin = der[der.index("task.delay(duree, function()"):]
verifier("G-202 : à la fin, le geste de découverte vient après enCours = false, et rend les vitesses seulement si aucune régénération n'a repris",
         fin.index("enCours = false") < fin.index("gesteDecouverte(personnage, function() if not enCours then rendreVitesses() end end)")
         and "poseRegeneration(personnage, false)" not in fin[:fin.index("gesteDecouverte")])
avt = sysrc[sysrc.index("local vitessesAvant = nil"):sysrc.index("local function derouler(changerTenue)")]
verifier("rendreVitesses remet les trois vitesses et oublie la mémoire",
         "humanoid.WalkSpeed, humanoid.JumpPower, humanoid.JumpHeight = vitessesAvant[1], vitessesAvant[2], vitessesAvant[3]" in avt and "vitessesAvant = nil" in avt)
ch = sysrc[sysrc.index("personnage:SetAttribute(\"TardisRegenChoix\", workspace:GetServerTimeNow() + delai)"):sysrc.index("personnage:SetAttribute(\"TardisRegenChoix\", nil)")]
verifier("G-205 : les mains tremblent pendant tout le choix, et s'arrêtent avant la suite",
         ch.index("local arreterTremblement = tremblerMains(personnage)") < ch.index("while os.clock() < fin") < ch.index("arreterTremblement()"))
verifier("L'ancienne table POSE a disparu (tout passe par Config.poseRegeneration)", "local POSE = {" not in sysrc and "Config.poseRegeneration(" in sysrc)

print(f"V7.5.3 : {len(OK)}/{len(OK) + len(KO)} vérifications réussies")
for k in KO: print("  ÉCHEC :", k)
sys.exit(1 if KO else 0)
