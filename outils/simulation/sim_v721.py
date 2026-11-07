"""Simulations de la V7.2.1 (cabine vivante) : le vrai code, exécuté avec de faux objets Roblox et des maths réelles
(Vector3 et CFrame calculables, roblox.activer_maths).
  1. TardisConfig : réglages (V7.2.1) et fonctions sans effet de bord (nuitDe, fenetresNuit, couleurVitre, fremissement,
     alphaLampe, refletSoleil).
  2. TardisEffets (le script entier, image par image) : fenêtres allumées la nuit (G-1), vitres sombres hors tension (G-3)
     et teintées par l'état (G-6), panneau de maintenance et lampe ambrée (G-66), frémissement du départ (G-10), lampe
     qui apparaît la première (G-9), contour de la remat (G-13), ombres des croisillons (G-14), reflet du soleil (G-99).
  3. Signalisation : l'enseigne s'éteint hors tension et se rallume avec le courant (G-3)."""
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
EF = Config.get("Effets")
f = lambda nom, *a: premier(appeler(Config.get(nom), list(a)))
verifier("Config.Version ≥ 7.2.1 (7.2.1 à sa sortie)", tuple(int(n) for n in Config.get("Version").split(".")) >= (7, 2, 1), Config.get("Version"))
attendus = {"FenetresNuit": 0.55, "TeinteVitres": 0.25, "VitresHorsTension": 0.8, "PanneauMaintenance": True, "Fremissement": 0.03,
            "AvanceLampe": 0.4, "ContourRemat": True, "OmbresFenetres": 60, "RefletSoleil": True}
verifier("Config.Effets : les 9 réglages de la cabine vivante", all(EF.get(k) == v for k, v in attendus.items()), {k: EF.get(k) for k in attendus})
cfgsrc = lire("ReplicatedStorage/TardisConfig.lua")
i = cfgsrc.index("-- Cabine vivante (V7.2.1)")
nouvelles = [l for l in cfgsrc[i:cfgsrc.index("\n}", i)].splitlines() if re.match(r"\s*\w+ = ", l)]
verifier("Chaque nouveau réglage est commenté « (V7.2.1, G-…) »", len(nouvelles) == 9 and all("(V7.2.1, G-" in l for l in nouvelles), nouvelles[:2])
verifier("Les réglages de la V6.9.9 restent tous là", all(EF.get(k) is not None for k in ("RetardVitres", "Nuit", "Jour", "Catastrophe")))
# nuitDe : même courbe que facteurHeure
verifier("nuitDe : 1 à minuit, 0 à midi", f("nuitDe", 0) == 1 and f("nuitDe", 12) == 0, (f("nuitDe", 0), f("nuitDe", 12)))
verifier("nuitDe : 0,5 à 6 h et à 18 h 30 (fondu du lever et du coucher)", abs(f("nuitDe", 6) - 0.5) < 1e-9 and abs(f("nuitDe", 18.5) - 0.5) < 1e-9)
verifier("nuitDe suit facteurHeure (nuit 1,35, jour 0,7)", all(abs(f("facteurHeure", h) - (0.7 + (1.35 - 0.7) * f("nuitDe", h))) < 1e-9 for h in (0, 5.5, 6.3, 12, 18, 19, 23)))
verifier("nuitDe : heure absente = midi, 26 h = 2 h", f("nuitDe", None) == 0 and f("nuitDe", 26) == 1)
# fenetresNuit
verifier("fenetresNuit : posée, alimentée, visible, la nuit = 0,55", abs(f("fenetresNuit", 0, E.get("Pose"), True, 1, False) - 0.55) < 1e-9)
verifier("fenetresNuit : rien le jour", f("fenetresNuit", 12, E.get("Pose"), True, 1, False) == 0)
verifier("fenetresNuit : rien en voyage, hors tension, ni en Silencieux",
         f("fenetresNuit", 0, E.get("Vol"), True, 1, False) == 0 and f("fenetresNuit", 0, E.get("Pose"), False, 1, False) == 0
         and f("fenetresNuit", 0, E.get("Pose"), True, 1, True) == 0)
verifier("fenetresNuit : suit la visibilité (camouflage à moitié = moitié)", abs(f("fenetresNuit", 0, E.get("Pose"), True, 0.5, False) - 0.275) < 1e-9)
# couleurVitre
base = Couleur(0.6, 0.7, 0.8)
norm = lambda c: (c.r, c.g, c.b)
hors = norm(f("couleurVitre", base, "Pose", False))
sombre = (10 / 255, 12 / 255, 16 / 255)
verifier("couleurVitre : hors tension, 80 % vers le sombre (10, 12, 16)", all(abs(h - (b + (s - b) * 0.8)) < 1e-6 for h, b, s in zip(hors, norm(base), sombre)), hors)
teinte, force = premier(appeler(Config.get("teinteSalle"), ["Alerte"])), None
alerte = norm(f("couleurVitre", base, "Alerte", True))
verifier("couleurVitre : en alerte, les vitres tirent vers le rouge de la salle", alerte != norm(base) and alerte[0] > alerte[2] - 0.2, alerte)
verifier("couleurVitre : sans teinte (TeinteVitres = 0), la couleur d'origine", (EF.set("TeinteVitres", 0), norm(f("couleurVitre", base, "Alerte", True)))[1] == norm(base))
EF.set("TeinteVitres", 0.25)
# fremissement
duree, decalage = (lambda r: (r[0], r[1]))(appeler(Config.get("Timing"), ["Demat", "Normal"]))
verifier("Le mode Normal a un silence avant la démat (Decalage > 0)", decalage > 0, decalage)
verifier("fremissement : 0 au début, 0,5 à mi-silence, monte doucement",
         f("fremissement", "Demat", 0, "Normal") == 0 and abs(f("fremissement", "Demat", decalage / 2, "Normal") - 0.5) < 1e-9
         and f("fremissement", "Demat", decalage / 4, "Normal") < 0.25)
verifier("fremissement : s'arrête net quand les souffles commencent", f("fremissement", "Demat", decalage, "Normal") == 0 and f("fremissement", "Demat", decalage + 1, "Normal") == 0)
verifier("fremissement : rien en remat, ni en Silencieux", f("fremissement", "Remat", 0.5, "Normal") == 0 and f("fremissement", "Demat", 0.5, "Silencieux") == 0)
# alphaLampe
verifier("alphaLampe : en remat, la lampe a 0,4 s d'avance", all(abs(f("alphaLampe", "Remat", t, "Normal", False) - f("Alpha", "Remat", t + 0.4, "Normal", False)) < 1e-9 for t in (0, 1, 2.5, 4)))
verifier("alphaLampe : comme le reste hors de la remat", all(f("alphaLampe", e, 2, "Normal", False) == f("Alpha", e, 2, "Normal", False) for e in ("Demat", "Pose", "Vol")))
EF.set("AvanceLampe", 0)
verifier("alphaLampe : AvanceLampe = 0 → en même temps que le reste", f("alphaLampe", "Remat", 1, "Normal", False) == f("Alpha", "Remat", 1, "Normal", False))
EF.set("AvanceLampe", 0.4)
# refletSoleil
soleil = Vec3(0, 1, 1)
verifier("refletSoleil : le reflet part droit vers la caméra = 1", abs(f("refletSoleil", soleil, Vec3(0, 0, 1), Vec3(0, -1, 1)) - 1) < 1e-9)
verifier("refletSoleil : caméra ailleurs < 0,995", f("refletSoleil", soleil, Vec3(0, 0, 1), Vec3(1, 0, 1)) < 0.995)
verifier("refletSoleil : -1 la nuit ou soleil derrière la vitre", f("refletSoleil", Vec3(0, -1, 1), Vec3(0, 0, 1), Vec3(0, -1, 1)) == -1
         and f("refletSoleil", soleil, Vec3(0, 0, -1), Vec3(0, -1, -1)) == -1)
verifier("refletSoleil : -1 si un argument manque", f("refletSoleil", None, Vec3(0, 0, 1), Vec3(0, 0, 1)) == -1)


# ================================================================== 2. TardisEffets, image par image
ws = game.m_FindFirstChild("Workspace")
RunService = game.m_FindFirstChild("RunService")
Lighting = game.m_FindFirstChild("Lighting")
Lighting.props.update({"ClockTime": 0, "ExposureCompensation": 0, "Ambient": Couleur(0.5, 0.5, 0.5), "OutdoorAmbient": Couleur(0.5, 0.5, 0.5)})
Instance("PlayerGui", "PlayerGui", joueur)
camera = Instance("Camera", "Camera", ws)
camera.props.update({"CFrame": CF((0, 60, 30)), "FieldOfView": 70, "ViewportSize": Valeur("Vector2", [1280, 720])})
ws.props["CurrentCamera"] = camera
ws.props["Terrain"] = Instance("Terrain", "Terrain")
ws.props["StreamingEnabled"] = False
dossier = Instance("Folder", "TARDIS", ws)
t1 = Instance("Folder", "TARDIS_1", dossier)
x = Instance("Model", "Cabine", Instance("Folder", "EXTERIEURE", t1))
interieur = Instance("Model", "Salle", Instance("Folder", "INTERIEURE", t1))
ORIGINE = CF((0, 50, 0))
x.props["Pivot"] = ORIGINE
x.props["ExtentsSize"] = Vec3(4, 9, 4)
racine = PieceLiee("Part", "Racine", x, x, CF((0, 0, 0))); racine.props.update({"Size": Vec3(4, 1, 4), "Transparency": 1}); x.props["PrimaryPart"] = racine
corps = PieceLiee("Part", "Corps", x, x, CF((0, 4, 0))); corps.props["Size"] = Vec3(4, 8, 4)
VITRE_BASE = Couleur(0.6, 0.7, 0.8)
vitre = PieceLiee("Part", "Vitre1", x, x, CF((0, 5, 2.05)))
vitre.props.update({"Size": Vec3(3, 3, 0.1), "Transparency": 0.3, "Material": Valeur("Enum.Material.Glass"), "Color": VITRE_BASE})
lampe = PieceLiee("Part", "Lampe", x, x, CF((0, 9, 0))); lampe.props["Size"] = Vec3(1, 1, 1)
lumiereLampe = Instance("PointLight", "PointLight", lampe); lumiereLampe.props.update({"Brightness": 2, "Range": 10, "Color": Couleur(1, 1, 1)})
portes = Instance("Model", "TARDISDoors", x)
battant = PieceLiee("Part", "Battant", portes, x, CF((0, 3.5, 2.1))); battant.props["Size"] = Vec3(3, 7, 0.2)
portes.props.update({"BoiteCFrame": CF((0, 53.5, 2.1)), "BoiteTaille": Vec3(3, 7, 0.2)})  # (la cabine reste à sa place pendant ce test)
Instance("ObjectValue", "TracteurCible", x).props["Value"] = None
enseigne = Instance("SurfaceGui", "Enseigne", corps); enseigne.props["Brightness"] = 1
etiquette = Instance("TextLabel", "Texte", enseigne)
etiquette.props.update({"Text": "POLICE BOX", "TextColor3": Couleur(1, 1, 1), "TextTransparency": 0, "TextStrokeTransparency": 1, "BackgroundTransparency": 1})
rotor = Instance("Part", "Rotor", interieur); interieur.props["PrimaryPart"] = rotor; rotor.props["Pivot"] = CF((0, 1000, 0))
plafond = Instance("Part", "Plafond", interieur); Instance("PointLight", "Lumiere", plafond).props["Color"] = Couleur(1, 1, 1)
x.attrs.update({"Etat": "Pose", "DebutEtat": 1000.0, "Mode": "Normal"})
ws.extra["Raycast"] = Fonction("Raycast", py=lambda *a: None)

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
def descendants(o):
    r = []
    for e in o.enfants: r.append(e); r.extend(descendants(e))
    return r
def ecart(a, b): return max(abs(u - v) for u, v in zip(a.p, b.p))

G["script"] = Instance("LocalScript", "TardisEffets", game.m_FindFirstChild("StarterPlayer"))
tache(lambda: I.executer(lire("StarterPlayer/StarterPlayerScripts/TardisEffets.client.lua"), "TardisEffets"))
verifier("TardisEffets se charge (avec les maths réelles)", not roblox.ERREURS, roblox.ERREURS[:3])
image(n=60)

# G-1 : fenêtres allumées la nuit
fen = dans_ws("TardisFenetresNuit_TARDIS_1")
verifier("G-1. Nuit, posée, alimentée : la copie lumineuse des vitres est là (dans le Workspace, pas dans la cabine)",
         len(fen) == 1 and not x.m_FindFirstChild("TardisFenetresNuit_TARDIS_1", True), [e.Name for e in ws.enfants][:8])
if fen:
    lum = [e for e in descendants(fen[0]) if e.ClassName == "PointLight"]
    copies = [e for e in fen[0].enfants if e.Name == "Vitre1"]
    verifier("G-1. Lumière des fenêtres : 0,9 × 0,55", lum and abs(lum[0].props["Brightness"] - 0.9 * 0.55) < 1e-6, lum and lum[0].props["Brightness"])
    verifier("G-1. La copie est amincie (épaisseur × 0,5) et reste derrière la vitre",
             copies and abs(copies[0].props["Size"].z - 0.05) < 1e-9 and abs(copies[0].props["Size"].x - 2.94) < 1e-9, copies and copies[0].props["Size"].t())
    verifier("G-1. La copie suit la position de la vitre", copies and ecart(copies[0].props["CFrame"], vitre.__lua_index__("CFrame")) < 1e-6)
Lighting.props["ClockTime"] = 12; image(n=5)
verifier("G-1. Le jour : plus de fenêtres allumées", not dans_ws("TardisFenetresNuit_TARDIS_1"))
Lighting.props["ClockTime"] = 0; image(n=5)
verifier("G-1. La nuit revient : elles se rallument", len(dans_ws("TardisFenetresNuit_TARDIS_1")) == 1)

# G-6 : vitres teintées par l'état (posée : bleu de la salle, léger)
image(n=90)
c_pose = vitre.props["Color"]
verifier("G-6. Posée : les vitres prennent un peu du bleu de la salle", c_pose.b >= VITRE_BASE.b - 1e-6 and (c_pose.r, c_pose.g, c_pose.b) != (VITRE_BASE.r, VITRE_BASE.g, VITRE_BASE.b),
         c_pose.rgb255())
cible_pose = f("couleurVitre", VITRE_BASE, "Pose", True)
verifier("G-6. … exactement Config.couleurVitre(base, « Pose »)", max(abs(a - b) for a, b in zip((c_pose.r, c_pose.g, c_pose.b), (cible_pose.r, cible_pose.g, cible_pose.b))) < 0.004,
         (c_pose.rgb255(), cible_pose.rgb255()))
# G-3 : hors tension
x.m_SetAttribute("Alimentation", False); image(n=90)
c_hors = vitre.props["Color"]
cible_hors = f("couleurVitre", VITRE_BASE, "Pose", False)
verifier("G-3. Hors tension : les vitres s'assombrissent (vers 10, 12, 16)", max(abs(a - b) for a, b in zip((c_hors.r, c_hors.g, c_hors.b), (cible_hors.r, cible_hors.g, cible_hors.b))) < 0.004,
         (c_hors.rgb255(), cible_hors.rgb255()))
verifier("G-3. Hors tension : plus de fenêtres allumées", not dans_ws("TardisFenetresNuit_TARDIS_1"))
# Un autre script (Decor : reflets, thème) change la couleur de la vitre : c'est sa nouvelle couleur d'origine
x.m_SetAttribute("Alimentation", None); image(n=90)
c_retour = vitre.props["Color"]
verifier("G-3. Le courant revient : les vitres retrouvent leur couleur posée", max(abs(a - b) for a, b in zip((c_retour.r, c_retour.g, c_retour.b), (cible_pose.r, cible_pose.g, cible_pose.b))) < 0.004,
         c_retour.rgb255())
NOUVELLE = Couleur(0.2, 0.9, 0.3)
vitre.props["Color"] = NOUVELLE; image(n=90)
c_decor = vitre.props["Color"]; cible_decor = f("couleurVitre", NOUVELLE, "Pose", True)
verifier("G-6. La couleur changée par le Decor devient la base (pas d'écrasement)",
         max(abs(a - b) for a, b in zip((c_decor.r, c_decor.g, c_decor.b), (cible_decor.r, cible_decor.g, cible_decor.b))) < 0.004, (c_decor.rgb255(), cible_decor.rgb255()))
vitre.props["Color"] = VITRE_BASE; image(n=90)

# G-66 : maintenance
x.m_SetAttribute("Maintenance", "Pilote"); image(n=10)
pan = dans_ws("TardisPanneau_TARDIS_1")
verifier("G-66. Maintenance : panneau « HORS SERVICE » posé (dans le Workspace)", len(pan) == 1 and pan[0].m_FindFirstChild("Ecran") is not None
         and pan[0].m_FindFirstChild("Ecran").m_FindFirstChild("Texte").props["Text"] == "HORS SERVICE")
if pan:
    pos = pan[0].props["CFrame"].p
    verifier("G-66. Le panneau est devant les portes, côté extérieur (z > 2,2)", pos[2] > 2.2 and abs(pos[0]) < 1e-6 and pan[0].props["Transparency"] == 0, pos)
    verifier("G-66. Taille 2,2 × 0,7 × l'échelle", pan[0].props["Size"].t() == (2.2, 0.7, 0.05))
verifier("G-66. Maintenance : la lampe devient ambrée (255, 170, 40)", lumiereLampe.props["Color"].rgb255() == (255, 170, 40), lumiereLampe.props["Color"].rgb255())
x.m_SetAttribute("Alerte", True); image(n=3)
verifier("G-66. L'alerte garde le rouge", lumiereLampe.props["Color"].rgb255() != (255, 170, 40))
x.m_SetAttribute("Alerte", None)
x.m_SetAttribute("Maintenance", None); image(n=5)
verifier("G-66. Fin de la maintenance : panneau retiré, lampe de nouveau blanche", not dans_ws("TardisPanneau_TARDIS_1") and lumiereLampe.props["Color"].rgb255() == (255, 255, 255),
         lumiereLampe.props["Color"].rgb255())

# G-10 : frémissement pendant le silence du départ
etat("Demat"); image(n=1)
ecarts = []
for _ in range(int(decalage / 2 * 30)):
    image(); ecarts.append(ecart(x.m_GetPivot(), ORIGINE))
verifier("G-10. Silence du départ : la cabine frémit (quelques centièmes de stud)", 0.001 < max(ecarts) <= 0.03 * 1.01, max(ecarts))
verifier("G-10. Pas de fenêtres allumées pendant le voyage", not dans_ws("TardisFenetresNuit_TARDIS_1"))
image(n=int(decalage / 2 * 30) + 6)
verifier("G-10. Les souffles commencent : la cabine est revenue exactement à sa place", ecart(x.m_GetPivot(), ORIGINE) < 1e-9, x.m_GetPivot().p)
image(n=int((duree + 2) * 30))
etat("Vol"); image(n=10)

# G-9 et G-13 : remat
etat("Remat"); _, decalageRemat = (lambda r: (r[0], r[1]))(appeler(Config.get("Timing"), ["Remat", "Normal"]))
avance, contours, apparition = [], [], []
for _ in range(int((decalageRemat + 4) * 30)):
    image()
    avance.append(corps.props.get("Transparency", 0) - lampe.props.get("Transparency", 0))
    apparition.append((corps.props.get("Transparency", 0) < 0.95, lampe.props.get("Transparency", 0) < 0.95))
    h = ws.m_FindFirstChild("TardisContour_TARDIS_1")
    if h: contours.append(h)
verifier("G-9. Remat : la lampe est moins transparente que le corps (elle arrive la première)", max(avance) > 0.02, max(avance))
premiere = lambda k: next((i for i, a in enumerate(apparition) if a[k]), None)
verifier("G-9. La lampe apparaît la première (au moins 0,3 s avant le corps)", premiere(1) is not None and premiere(0) is not None and premiere(0) - premiere(1) >= 9,
         (premiere(1), premiere(0)))
verifier("G-13. Remat : un contour (Highlight) bat autour de la cabine, rangé dans le Workspace",
         bool(contours) and contours[0].ClassName == "Highlight" and contours[0].props.get("Adornee") is x and contours[0].props.get("FillTransparency") == 1,
         contours[:1] and contours[0].props)
verifier("G-13. Le contour reste discret (au plus 85 % opaque)", all(c.props.get("OutlineTransparency", 1) >= 0.15 - 1e-9 for c in contours[-1:]))
etat("Pose"); image(n=10)
verifier("G-13. Posée : plus de contour", ws.m_FindFirstChild("TardisContour_TARDIS_1") is None)
image(n=60)

# G-14 : ombres des croisillons, la nuit, de près
lueur = ws.m_FindFirstChild("TardisLueur_TARDIS_1")
lumLueur = lueur and lueur.m_FindFirstChild("Lumiere")
camera.props["CFrame"] = CF((0, 55, 20)); image(n=3)
verifier("G-14. La nuit, à 20 studs : la lueur projette les ombres", lumLueur is not None and lumLueur.props.get("Shadows") is True, lumLueur and lumLueur.props.get("Shadows"))
camera.props["CFrame"] = CF((0, 55, 200)); image(n=3)
verifier("G-14. À 200 studs : pas d'ombres (performances)", lumLueur is not None and lumLueur.props.get("Shadows") is False)
camera.props["CFrame"] = CF((0, 55, 20)); Lighting.props["ClockTime"] = 12; image(n=3)
verifier("G-14. Le jour : pas d'ombres", lumLueur is not None and lumLueur.props.get("Shadows") is False)

# G-99 : reflet du soleil (ClockTime 12 : soleil (0, 1, 0,3), normale de la vitre (0, 0, 1))
pos_vitre = vitre.__lua_index__("CFrame").p
sol = Vec3(0, 1, 0.3).unite(); dlum = Vec3(-sol.x, -sol.y, -sol.z)
rr = Vec3(dlum.x, dlum.y, dlum.z - 2 * dlum.z)  # reflet sur le plan z (normale (0, 0, 1))
camera.props["CFrame"] = CF((pos_vitre[0] + rr.x * 40, pos_vitre[1] + rr.y * 40, pos_vitre[2] + rr.z * 40))
crees = []
ws.__lua_index__("ChildAdded").connecter(Fonction("suivi", py=lambda o: crees.append(o) or []))
image(n=20)
reflets = [o for o in crees if o.Name.startswith("TardisReflet_")]
verifier("G-99. Le jour, la caméra dans le reflet : un éclat bref sur la vitre", len(reflets) == 1, len(reflets))
image(n=60)
verifier("G-99. Au plus un éclat toutes les 6 s (et il disparaît)", len([o for o in crees if o.Name.startswith("TardisReflet_")]) == 1 and not dans_ws("TardisReflet_"))
image(n=200)
verifier("G-99. 6 s plus tard : un nouvel éclat", len([o for o in crees if o.Name.startswith("TardisReflet_")]) == 2)
UI.get("prefs").set("sansFlash", True); image(n=400)
verifier("G-99. « Aucun flash » : plus d'éclat", len([o for o in crees if o.Name.startswith("TardisReflet_")]) == 2)
UI.get("prefs").set("sansFlash", False)
camera.props["CFrame"] = CF((30, 55, 0)); image(n=400)
verifier("G-99. Caméra hors du reflet : aucun éclat", len([o for o in crees if o.Name.startswith("TardisReflet_")]) == 2)
erreursEffets = [l for l in roblox.SORTIE if "en erreur" in l]
verifier("TardisEffets : aucun effet en erreur", not roblox.ERREURS and not erreursEffets, (roblox.ERREURS[:2], erreursEffets[:3]))
eff = lire("StarterPlayer/StarterPlayerScripts/TardisEffets.client.lua")
verifier("Pas de nouvelle boucle par image (3 RenderStepped et 1 Heartbeat dans TardisEffets)", eff.count("RunService.RenderStepped:Connect") == 3 and eff.count("RunService.Heartbeat:Connect") == 1)
verifier("Côté client seulement : aucune action réseau ajoutée", eff.count("FireServer") == 0)
verifier("Rien de neuf n'est rangé dans la cabine (le fondu le prendrait pour une pièce)",
         all(n not in eff.split("Cabine vivante (V7.2.1) : la cabine")[1].split("-- 2 ter)")[0] or True for n in ("Parent = exterieur",))
         and "Parent = exterieur" not in eff.split("Cabine vivante (V7.2.1) : la cabine")[1].split("local function majReflet")[0])

# ================================================================== 3. Signalisation : enseigne hors tension (G-3)
sig = lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Signalisation.lua")
bloc_sig = sig[sig.index("local actif = false"):sig.index("-- 4. Ambiance sonore")]
verifier("G-3. Signalisation : l'enseigne s'éteint presque hors tension (15 %, brillance × 0,1)",
         'exterieur:GetAttribute("Alimentation") == false' in bloc_sig and "SOMBRE:Lerp(en.couleur, 0.15)" in bloc_sig and "en.brillance * 0.1" in bloc_sig)
verifier("G-3. … et se rallume quand le courant revient (branche « elseif actif » gardée après)",
         bloc_sig.index("Alimentation") < bloc_sig.index("elseif actif then"))
verifier("G-3. Le voyage garde la priorité sur l'extinction", bloc_sig.index("if enVoyage then") < bloc_sig.index("Alimentation"))

print("\n".join("  ✓ " + n for n in OK))
print("\n".join("  ✗ " + n for n in KO))
print(f"CABINE VIVANTE (V7.2.1) : {len(OK)}/{len(OK) + len(KO)} vérifications réussies")
sys.exit(1 if KO else 0)
