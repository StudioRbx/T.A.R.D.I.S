"""Simulations de la V7.4.1 (confort de l'écran : secousses et nausée) : le vrai code, avec de faux objets Roblox.
  1. TardisConfig : décalage lisse des secousses (G-277), force effective (G-279), vignette des PV bas (G-268),
     dolly zoom (G-262), éblouissement par le projecteur (G-275).
  2. TardisUI : force des secousses, champ de vision fixe (G-280), lien Time Lord choisi par chacun (C-222).
  3. EffetsExterieurs (le module entier) : secousse × réglage, tremblement continu qui retombe en douceur, vignette rouge
     à bord quand les PV sont bas, écran qui blanchit dans le faisceau du projecteur.
  4. Preferences : dolly zoom à la découverte (et jamais avec « réduire les effets » ou « champ fixe »).
  5. Le code (vol libre, effets, régénération, tablette)."""
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
def descendants(o):
    r = []
    for e in o.enfants: r.append(e); r.extend(descendants(e))
    return r

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
CE = Config.get("ConfortEcran")
f = lambda nom, *a: appeler(Config.get(nom), list(a))
f1 = lambda nom, *a: premier(f(nom, *a))
verifier("Config.Version ≥ 7.4.1 (7.4.1 à sa sortie)", tuple(int(n) for n in Config.get("Version").split(".")) >= (7, 4, 1), Config.get("Version"))
verifier("Config.ConfortEcran : secousses lissées, dolly zoom, vignette et éblouissement actifs",
         all(CE.get(k) is True for k in ("SecoussesLissees", "DollyZoom", "VignettePV", "Aveuglement")))
verifier("Config.ConfortEcran : dolly zoom 1 s / +20°, vignette sous 25 % toutes les 1,6 s, éblouissement 60 studs / 15° / 0,35",
         (CE.get("DureeDollyZoom"), CE.get("AmplitudeDollyZoom"), CE.get("SeuilVignette"), CE.get("PeriodeVignette"),
          CE.get("PorteeAveuglement"), CE.get("AngleAveuglement"), CE.get("ForceAveuglement")) == (1, 20, 25, 1.6, 60, 15, 0.35))
# G-277
pts = [f("decalageSecousse", i / 60, 9, 1) for i in range(600)]
toutes = [v for p in pts for v in p]
verifier("G-277. decalageSecousse : trois valeurs entre -0,5 et 0,5", all(len(p) == 3 for p in pts) and min(toutes) >= -0.5 and max(toutes) <= 0.5,
         (min(toutes), max(toutes)))
sauts = max(abs(a - b) for p, q in zip(pts, pts[1:]) for a, b in zip(p, q))
verifier("G-277. decalageSecousse : continu (d'une image à l'autre, au plus 0,2 de saut) et il bouge vraiment",
         sauts <= 0.2 and max(toutes) - min(toutes) > 0.5, (sauts, max(toutes) - min(toutes)))
verifier("G-277. decalageSecousse : les trois axes et deux graines différentes ne vont pas pareil",
         len({round(v, 6) for v in pts[30]}) == 3 and f("decalageSecousse", 0.5, 9, 1) != f("decalageSecousse", 0.5, 9, 2))
# G-279
verifier("G-279. forceSecousseEffective : × réglage (borné à 0..1) × 0,3 en effets réduits",
         [f1("forceSecousseEffective", 1, 1, False), f1("forceSecousseEffective", 1, 0.5, False), f1("forceSecousseEffective", 1, 0.5, True),
          f1("forceSecousseEffective", 1, 0, False), f1("forceSecousseEffective", 1, 3, False), f1("forceSecousseEffective", 1, None, False)]
         == [1, 0.5, 0.15, 0, 1, 1])
# G-268
iv = lambda *a: f1("intensiteVignette", *a)
verifier("G-268. intensiteVignette : rien à 25 % et plus, ni sans PV", iv(25, 0, 25, 1.6) == 0 and iv(80, 0, 25, 1.6) == 0 and iv(None, 0, 25, 1.6) == 0)
bat = [iv(5, t / 20, 25, 1.6) for t in range(64)]
verifier("G-268. intensiteVignette : sous le seuil, elle bat lentement (de 60 % à 100 % de sa force)",
         min(bat) > 0 and max(bat) <= 1 and abs(min(bat) / max(bat) - 0.6) < 0.02, (min(bat), max(bat)))
verifier("G-268. intensiteVignette : plus forte quand les PV baissent", iv(20, 0.8, 25, 1.6) < iv(10, 0.8, 25, 1.6) < iv(0, 0.8, 25, 1.6) <= 1)
verifier("G-268. intensiteVignette : période 0 (aucun flash) → fixe", iv(10, 0, 25, 0) == iv(10, 0.7, 25, 0) > 0)
# G-262
dz = lambda p: f("dollyZoom", p, 70, 10, 20)
verifier("G-262. dollyZoom : au début et à la fin, le champ d'origine et aucune avance", list(dz(0)) == [70, 0] and list(dz(1)) == [70, 0])
c, a = dz(0.5)
verifier("G-262. dollyZoom : à mi-course, +20° et la caméra avance", abs(c - 90) < 1e-9 and a > 2, (c, a))
garde = all(abs((10 - dz(p)[1]) * math.tan(math.radians(dz(p)[0]) / 2) - 10 * math.tan(math.radians(70) / 2)) < 1e-9 for p in (0.1, 0.3, 0.5, 0.8))
verifier("G-262. dollyZoom : le sujet garde sa taille (distance × tan(champ/2) constant)", garde)
# G-275
av = lambda *a: f1("aveuglement", *a)
verifier("G-275. aveuglement : dans l'axe tout près → presque 1 ; loin ou hors angle → 0",
         av(1, 0, 60, 15) > 0.98 and av(60, 0, 60, 15) == 0 and av(10, 15, 60, 15) == 0 and av(10, -20, 60, 15) == 0)
verifier("G-275. aveuglement : baisse avec la distance et l'angle", av(10, 0, 60, 15) > av(30, 0, 60, 15) > av(30, 7, 60, 15) > 0)

# ================================================================== 2. TardisUI
def pref(cle, valeur): UI.get("prefs").set(cle, valeur)
u = lambda nom: premier(appeler(UI.get(nom), []))
verifier("G-279. UI.forceSecousses : 1 par défaut, borné à 0..1", u("forceSecousses") == 1 and (pref("forceSecousses", 0.25) or u("forceSecousses") == 0.25)
         and (pref("forceSecousses", 7) or u("forceSecousses") == 1) and (pref("forceSecousses", -1) or u("forceSecousses") == 0))
pref("forceSecousses", None)
verifier("G-280. UI.champFixe : non par défaut, oui une fois choisi", u("champFixe") is False and (pref("champFixe", True) or u("champFixe") is True))
pref("champFixe", None)
rs.m_SetAttribute("TardisLienTimeLord", True)
l1 = u("lienTimeLord")
rs.m_SetAttribute("TardisLienTimeLord", None)
l2 = u("lienTimeLord")
pref("lienTimeLord", True); l3 = u("lienTimeLord")
rs.m_SetAttribute("TardisLienTimeLord", True); pref("lienTimeLord", False); l4 = u("lienTimeLord")
rs.m_SetAttribute("TardisLienTimeLord", None); pref("lienTimeLord", None)
verifier("C-222. UI.lienTimeLord : sans choix, le réglage du serveur ; un choix personnel l'emporte (dans les deux sens)",
         (l1, l2, l3, l4) == (True, False, True, False), (l1, l2, l3, l4))

# ================================================================== Le monde (client, maths réelles)
ws = game.m_FindFirstChild("Workspace")
RunService = game.m_FindFirstChild("RunService")
Lighting = game.m_FindFirstChild("Lighting")
Lighting.props.update({"ClockTime": 12, "ExposureCompensation": 0, "Ambient": Couleur(0.5, 0.5, 0.5), "OutdoorAmbient": Couleur(0.5, 0.5, 0.5)})
PlayerGui = Instance("PlayerGui", "PlayerGui", joueur)
camera = Instance("Camera", "Camera", ws)
camera.props.update({"CFrame": CF((0, 9.5, -20)), "FieldOfView": 70, "ViewportSize": Valeur("Vector2", [1280, 720])})
ws.props["CurrentCamera"] = camera
ws.props["Terrain"] = Instance("Terrain", "Terrain")
ws.props["GlobalWind"] = Vec3(0, 0, 0)
ws.extra["Raycast"] = Fonction("Raycast", py=lambda *a: None)
dossier = Instance("Folder", "TARDIS", ws)
t_ = Instance("Folder", "TARDIS_1", dossier)
x = Instance("Model", "Cabine", Instance("Folder", "EXTERIEURE", t_))
interieur = Instance("Model", "Salle", Instance("Folder", "INTERIEURE", t_))
x.props.update({"Pivot": CF((0, 0.5, 0)), "ExtentsSize": Vec3(4, 9, 4), "BoiteCFrame": CF((0, 5, 0)), "BoiteTaille": Vec3(4, 9, 4)})
racine = Instance("Part", "Racine", x); racine.props.update({"Size": Vec3(4, 1, 4), "Transparency": 1, "CFrame": CF((0, 0.5, 0))}); x.props["PrimaryPart"] = racine
lampe = Instance("Part", "Lampe", x); lampe.props.update({"Size": Vec3(1, 1, 1), "CFrame": CF((0, 9.5, 0)), "Position": Vec3(0, 9.5, 0)})
Instance("PointLight", "PointLight", lampe).props.update({"Brightness": 2, "Range": 10})
Instance("Folder", "Boucliers", x)
Instance("ObjectValue", "TracteurCible", x).props["Value"] = None
rotor = Instance("Part", "Rotor", interieur); interieur.props.update({"PrimaryPart": rotor, "BoiteCFrame": CF((0, 1000, 0)), "BoiteTaille": Vec3(40, 20, 40)})
x.attrs.update({"Etat": "Pose", "DebutEtat": 1000.0, "Mode": "Normal"})
perso = Instance("Model", "Perso", ws); tete = Instance("Part", "Head", perso); tete.props.update({"CFrame": CF((0, 9.5, -20)), "Position": Vec3(0, 9.5, -20)})
joueur.props["Character"] = perso

def image(dt=1 / 60, n=1):
    for _ in range(n):
        H.avancer(dt)
        for nom in ("RenderStepped", "Heartbeat"):
            sig = RunService.extra.get(nom)
            if sig: sig.declencher(dt)
        for nom, fn in list(RunService.extra.get("rendu", {}).items()):
            tache(lambda fn=fn: appeler(fn, [dt]))

init = lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/init.client.lua")
outils = init[init.index("local function partTemporaire(proprietes)"):init.index("-- La lampe du toit : la pièce qui contient la PointLight")]
O = {}
tache(lambda: O.update(t=premier(I.executer("local exterieur, Config, E = ...\n" + outils + "\nreturn { partTemporaire = partTemporaire, progressionAnimation = progressionAnimation }",
                                            "outils-extras", (x, Config, E)))))
DEDANS = {"v": False}
remote = Instance("RemoteEvent", "TardisCommande_TARDIS_1", rs)
ENVOIS = []
remote.extra["FireServer"] = Fonction("FireServer", py=lambda *a: ENVOIS.append(a[1:]) or [])
def contexte(**plus):
    t = Table({"C": UI.get("C"), "Config": Config, "E": E, "Lighting": Lighting, "RunService": RunService, "UI": UI, "animer": UI.get("animer"),
               "camera": camera, "creer": UI.get("creer"), "texte": UI.get("texte"), "def": Table({"Nom": "TARDIS_1"}), "exterieur": x,
               "interieur": interieur, "joueur": joueur, "jeSuisDedans": Fonction("jeSuisDedans", py=lambda: DEDANS["v"]),
               "partTemporaire": O["t"].get("partTemporaire"), "progressionAnimation": O["t"].get("progressionAnimation"), "lampe": lampe,
               "remote": remote, "ReplicatedStorage": rs, "afficherInvitation": Fonction("afficherInvitation", py=lambda *a: [])})
    for k, v in plus.items(): t.set(k, v)
    return t
def module(nom):
    res = {}
    tache(lambda: res.update(m=premier(appeler(premier(I.executer(lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/" + nom + ".lua"), nom)), [contexte()]))))
    return res.get("m")

# ================================================================== 3. EffetsExterieurs
EE = module("EffetsExterieurs")
verifier("EffetsExterieurs se charge (maths réelles)", not roblox.ERREURS and EE is not None, roblox.ERREURS[:3])
verifier("Rien d'affiché tant qu'aucun effet de confort n'est utile (pas d'écran créé d'office)", PlayerGui.m_FindFirstChild("TardisConfort_TARDIS_1") is None)
secouer = EE.get("secouer")
rendu = lambda: RunService.extra["rendu"]["TardisExtrasSecousse_TARDIS_1"]
def angle_camera():
    R_ = camera.props["CFrame"].R
    return math.acos(max(-1, min(1, (R_[0][0] + R_[1][1] + R_[2][2] - 1) / 2)))
def secousse_un_coup(force, n=1):
    image(n=90)  # la précédente est retombée
    tache(lambda: appeler(secouer, [force]))
    angles = []
    for _ in range(n):
        camera.props["CFrame"] = CF((0, 9.5, -20))
        tache(lambda: appeler(rendu(), [1 / 60]))
        angles.append(angle_camera()); H.avancer(1 / 60)
    return angles
a_plein = max(secousse_un_coup(1, 30))
pref("forceSecousses", 0.5); a_moitie = max(secousse_un_coup(1, 30))
pref("forceSecousses", 0); a_zero = max(secousse_un_coup(1, 30))
pref("forceSecousses", None)
verifier("G-279. Secousse à 100 % : la caméra tremble", a_plein > 0.004, a_plein)
verifier("G-279. Réglage à 50 % : environ deux fois moins ; à 0 % : plus rien", 0.3 < a_moitie / a_plein < 0.7 and a_zero == 0, (a_plein, a_moitie, a_zero))
serie = secousse_un_coup(1, 40)
verifier("G-277. Tremblement continu : d'une image à l'autre, l'angle varie peu (pas de sauts au hasard)",
         max(abs(a - b) for a, b in zip(serie, serie[1:])) < 0.25 * max(serie), (max(serie), max(abs(a - b) for a, b in zip(serie, serie[1:]))))
image(n=90)
tache(lambda: appeler(secouer, [1]))
for _ in range(15): image()
camera.props["CFrame"] = CF((0, 9.5, -20)); image(n=0)
reste_quart = [None]
# niveau de secousse après 0,25 s puis 1 s : on lit la force par la caméra avec le tirage (comme sim_v6910)
def niveau():
    ancien = G["math"].h["random"]; G["math"].h["random"] = Fonction("random", py=lambda *a: 1.0)
    CE.set("SecoussesLissees", False)
    camera.props["CFrame"] = CF((0, 9.5, -20))
    tache(lambda: appeler(rendu(), [0]))
    CE.set("SecoussesLissees", True); G["math"].h["random"] = ancien
    a = angle_camera()
    return math.asin(a / math.sqrt(3)) / (0.035 * 0.5) if a else 0
n_quart = niveau()
for _ in range(45): image()
n_un = niveau()
verifier("G-277. Retombée douce : après 0,25 s il reste plus de la moitié, après 1 s presque rien", 0.5 < n_quart < 0.75 and n_un < 0.05, (n_quart, n_un))
verifier("Pas d'erreur (secousses)", not roblox.ERREURS, roblox.ERREURS[:3])

# Vignette des PV bas (G-268)
def bords():
    g = PlayerGui.m_FindFirstChild("TardisConfort_TARDIS_1")
    return [g.m_FindFirstChild("Vignette%d" % i) for i in range(1, 5)] if g else []
x.m_SetAttribute("PointsDeVie", 80); DEDANS["v"] = True; image(n=5)
verifier("G-268. PV à 80 % : pas de vignette (rien n'est créé)", not bords())
x.m_SetAttribute("PointsDeVie", 10); image(n=5)
b = bords()
verifier("G-268. PV à 10 %, à bord : quatre bords rouges dégradés apparaissent",
         len(b) == 4 and all(o and o.props["BackgroundTransparency"] < 0.8 and o.m_FindFirstChildOfClass("UIGradient") for o in b)
         and b[0].props["BackgroundColor3"].rgb255() == (200, 0, 0), [o and o.props.get("BackgroundTransparency") for o in b])
vals = []
for _ in range(100): image(); vals.append(b[0].props["BackgroundTransparency"])
verifier("G-268. La vignette bat lentement", max(vals) - min(vals) > 0.1 and max(abs(p - q) for p, q in zip(vals, vals[1:])) < 0.05, (min(vals), max(vals)))
pref("sansFlash", True); vals = []
for _ in range(60): image(); vals.append(b[0].props["BackgroundTransparency"])
pref("sansFlash", None)
verifier("G-268. « Aucun flash » : la vignette reste fixe", max(vals) - min(vals) < 1e-9 and vals[0] < 1, (min(vals), max(vals)))
DEDANS["v"] = False; image(n=2)
verifier("G-268. Dehors : pas de vignette", all(o.props["BackgroundTransparency"] == 1 for o in b))
DEDANS["v"] = True; x.m_SetAttribute("PointsDeVie", 60); image(n=2)
verifier("G-268. PV remontés : la vignette s'efface", all(o.props["BackgroundTransparency"] == 1 for o in b))
DEDANS["v"] = False

# Éblouissement (G-275) : la cabine en (0, 0,5, 0), la lampe à 9,5 de haut ; le joueur à 20 studs devant, au niveau de la lampe
def blanc():
    g = PlayerGui.m_FindFirstChild("TardisConfort_TARDIS_1")
    o = g and g.m_FindFirstChild("Aveuglement")
    return 1 - o.props["BackgroundTransparency"] if o else 0
def regarder(depuis, vers): camera.props["CFrame"] = roblox._regarder(Vec3(*depuis), Vec3(*vers))
x.m_SetAttribute("Projecteur", True); x.m_SetAttribute("ProjecteurDir", Vec3(0, 0, -1))
image(n=60)
regarder((0, 9.5, -20), (0, 9.5, 0)); image()
b1 = blanc()
verifier("G-275. Dans le faisceau, en regardant la lampe à 20 studs : l'écran blanchit (≈ 0,23)", 0.15 < b1 < 0.3, b1)
regarder((0, 9.5, -20), (0, 9.5, -40)); image()
verifier("G-275. Dos à la lampe : rien", blanc() < 1e-9, blanc())
regarder((0, 9.5, -20), (0, 9.5, 0)); x.m_SetAttribute("ProjecteurDir", Vec3(1, 0, -1)); image()
verifier("G-275. Faisceau tourné de 45° : rien", blanc() < 1e-9, blanc())
x.m_SetAttribute("ProjecteurDir", Vec3(0, 0, -1)); pref("effetsReduits", True); image()
b2 = blanc(); pref("effetsReduits", None)
verifier("G-275. « Réduire les effets » : moitié moins", abs(b2 - b1 / 2) < 0.02, (b1, b2))
joueur.m_SetAttribute("TardisPilote_TARDIS_1", True); image()
verifier("G-275. Le pilote (qui vise) n'est pas ébloui", blanc() < 1e-9, blanc())
joueur.m_SetAttribute("TardisPilote_TARDIS_1", None); DEDANS["v"] = True; image()
verifier("G-275. À bord : pas ébloui", blanc() < 1e-9, blanc())
DEDANS["v"] = False; x.m_SetAttribute("Projecteur", False); image(n=60)
verifier("G-275. Projecteur éteint : l'écran redevient clair", blanc() < 1e-9, blanc())
verifier("EffetsExterieurs : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])

# ================================================================== 4. Preferences : dolly zoom de la découverte (G-262)
PR = module("Preferences")
verifier("Preferences se charge", not roblox.ERREURS, roblox.ERREURS[:3])
recevoir = lambda *a: (tache(lambda: remote.__lua_index__("OnClientEvent").declencher(*a)), H.avancer(0.01))
camera.props.update({"CFrame": CF((0, 1000, 10)), "FieldOfView": 70})
recevoir("__decouverte", True)
dz = RunService.extra.get("rendu", {}).get("TardisDollyZoom")
verifier("G-262. Découverte : le dolly zoom démarre (et la carte s'affiche)", dz is not None and PlayerGui.m_FindFirstChild("TardisDecouverte") is not None)
champs, avances = [], []
for _ in range(70):
    camera.props["CFrame"] = CF((0, 1000, 10))
    image(1 / 60)
    champs.append(camera.props["FieldOfView"]); avances.append(10 - camera.props["CFrame"].p[2])
verifier("G-262. Le champ s'ouvre jusqu'à ≈ 90° puis revient à 70°, la caméra avance puis revient",
         88 < max(champs) <= 90.01 and champs[-1] == 70 and max(avances) > 2 and "TardisDollyZoom" not in RunService.extra.get("rendu", {}), (max(champs), champs[-1], max(avances)))
for p, nom in (("effetsReduits", "réduire les effets"), ("champFixe", "champ de vision fixe")):
    pref(p, True)
    recevoir("__decouverte", True)
    verifier("G-262. Pas de dolly zoom avec « %s »" % nom, "TardisDollyZoom" not in RunService.extra.get("rendu", {}))
    pref(p, None)
verifier("Preferences : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])

# ================================================================== 5. Le code
src = "StarterPlayer/StarterPlayerScripts/"
vl = lire(src + "TardisVolLibre.client.lua")
verifier("G-280. Vol libre : plus aucun à-coup direct du champ (tous par varierChamp, qui respecte le champ fixe)",
         "camera.FieldOfView +=" not in vl.replace("camera.FieldOfView += (champVise", "").replace("camera.FieldOfView += (vol.champOrigine + ((chute and not UI.champFixe())", "").replace("if not UI.champFixe() then camera.FieldOfView += delta end", "")
         and "camera.FieldOfView -=" not in vl and vl.count("varierChamp(") == 5)
verifier("G-280. Vol libre : le champ suit la vitesse et la chute, sauf en champ fixe",
         "local champVise = UI.champFixe() and vol.champOrigine or" in vl and "(chute and not UI.champFixe()) and 12 * t or 0" in vl)
verifier("G-279/G-277. Vol libre : secousse d'impact × réglage, tremblement continu",
         "Config.forceSecousseEffective(total * 0.03, UI.forceSecousses(), UI.effetsReduits())" in vl and "Config.decalageSecousse(os.clock(), cfgC.FrequenceSecousse, 3)" in vl)
te = lire(src + "TardisEffets.client.lua")
verifier("G-279/G-277. Démat et remat à bord : tremblement continu et × réglage (choc compris)",
         "Config.decalageSecousse(os.clock(), (cfgC.FrequenceSecousse or 9) * 1.4, 2)" in te and "offset *= UI.forceSecousses()" in te
         and te.index("offset *= UI.forceSecousses()") < te.index("humanoid.CameraOffset = offset"))
rg = lire(src + "TardisExtrasClient/Regeneration.lua")
verifier("G-280. Régénération : pas de zoom en champ fixe", "if not UI.champFixe() then camera.FieldOfView = champOrigine - 14 * zoom * zoom end" in rg)
verifier("C-222. Régénération : le lien suit le choix du joueur", "UI.lienTimeLord() and joueur.Team" in rg and "GetAttribute(\"TardisLienTimeLord\")" not in rg)
ou = lire(src + "TardisTablette/Outils.lua")
verifier("C-222. Tablette : la tuile et le bouton suivent le choix personnel (plus d'envoi au serveur)",
         ou.count("UI.lienTimeLord()") >= 3 and 'UI.setPref("lienTimeLord", not UI.lienTimeLord())' in ou and 'FireServer("LienTimeLord")' not in ou)
vo = lire(src + "TardisTablette/Volet.lua")
verifier("Réglages : force des secousses (0 à 100 %), champ de vision fixe et lien Time Lord",
         'UI.setPref("forceSecousses", niveau)' in vo and 'UI.setPref("champFixe", not UI.champFixe())' in vo and 'UI.setPref("lienTimeLord", not UI.lienTimeLord())' in vo)
ee = lire(src + "TardisExtrasClient/EffetsExterieurs.lua")
verifier("Aucune nouvelle boucle par image (vignette dans la secousse, éblouissement dans le projecteur)",
         ee.count("RenderStepped:Connect") == 3 and ee.count("BindToRenderStep") == 1)

print()
for n in OK: print("  ✓ " + n)
for n in KO: print("  ✗ " + n)
print("V7.4.1 : %d/%d vérifications réussies" % (len(OK), len(OK) + len(KO)))
sys.exit(1 if KO else 0)
