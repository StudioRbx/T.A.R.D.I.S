"""Simulations de la V7.2.2 (traces au sol à l'arrivée) : le vrai code, exécuté avec de faux objets Roblox et des maths réelles.
  1. TardisConfig : réglages (V7.2.2) et fonctions sans effet de bord (saleteAtterrissage, styleMarque, ventDecollage, brumeNuit).
  2. Signalisation (le module entier) : marque selon le mode (G-19), givre après une Urgence (G-20), brume la nuit (G-29),
     poussière du plafond sous un toit (G-22).
  3. Decor (le module entier) : gerbe du sol au départ (G-21), vent du décollage poussé puis rendu (G-23), deux TARDIS ensemble.
  4. EffetsExterieurs (le module entier) : cercle gallifreyen sous l'ombre de la remat (G-12).
  5. TardisSystemes (le vrai Script serveur, banc d'essai) : saleté selon le sol de l'atterrissage (C-178)."""
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
def norm(c): return (c.r, c.g, c.b)
def proche(a, b, tol=1e-6): return all(abs(u - v) <= tol for u, v in zip(a, b))

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
SY = Config.get("Systemes")
f = lambda nom, *a: premier(appeler(Config.get(nom), list(a)))
verifier("Config.Version ≥ 7.2.2 (7.2.2 à sa sortie)", tuple(int(n) for n in Config.get("Version").split(".")) >= (7, 2, 2), Config.get("Version"))
attendus = {"MarqueSelonMode": True, "GivreSol": 25, "TerrainDepart": True, "VentDecollage": 25, "BrumeNuit": 8, "CercleGallifreyen": True,
            "ImageCercle": "", "PoussierePlafond": 20}
verifier("Config.Effets : les 8 réglages des traces au sol", all(EF.get(k) == v for k, v in attendus.items()), {k: EF.get(k) for k in attendus})
cfgsrc = lire("ReplicatedStorage/TardisConfig.lua")
i = cfgsrc.index("-- Traces au sol (V7.2.2)")
nouvelles = [l for l in cfgsrc[i:cfgsrc.index("\n}", i)].splitlines() if re.match(r"\s*\w+ = ", l)]
verifier("Chaque nouveau réglage est commenté « (V7.2.2, G-…) »", len(nouvelles) == 8 and all("(V7.2.2, G-" in l for l in nouvelles), nouvelles[:2])
verifier("Les réglages de la V7.2.1 restent tous là", all(EF.get(k) is not None for k in ("FenetresNuit", "RefletSoleil", "MarquesSol", "DureeMarques")))
ST = SY.get("SaleteTerrain")
verifier("Systemes.SaleteTerrain : sable × 1,5, boue × 1,75, neige × 0,5, herbe × 0,75",
         ST.get("Sand") == 1.5 and ST.get("Mud") == 1.75 and ST.get("Snow") == 0.5 and ST.get("Grass") == 0.75 and SY.get("SaleteParVoyage") == 8)
# saleteAtterrissage
for sol_, attendu in [("Sand", 12), ("Mud", 14), ("Snow", 4), ("Grass", 6), ("Water", 2), ("Concrete", 8), ("Inconnu", 8), (None, 8)]:
    verifier(f"saleteAtterrissage({sol_}) = {attendu}", abs(f("saleteAtterrissage", sol_) - attendu) < 1e-9, f("saleteAtterrissage", sol_))
ST.set("Sand", -3)
verifier("saleteAtterrissage : jamais négative (facteur mal réglé)", f("saleteAtterrissage", "Sand") == 0)
ST.set("Sand", 1.5)
# styleMarque
def style(m):
    t = f("styleMarque", m)
    return {k: t.get(k) for k in ("assombri", "transparence", "fumee", "neon")}
verifier("styleMarque(Normal) : la marque de la V6.9.9 (assombrie 0,65, transparence 0,7)", style("Normal") == {"assombri": 0.65, "transparence": 0.7, "fumee": None, "neon": None}, style("Normal"))
verifier("styleMarque(Urgence) et (Catastrophe) : brûlée (0,85) et fumante", style("Urgence") == style("Catastrophe") == {"assombri": 0.85, "transparence": 0.55, "fumee": True, "neon": None}, style("Urgence"))
verifier("styleMarque(Express) : nette et verte (néon)", style("Express") == {"assombri": 0, "transparence": 0.6, "fumee": None, "neon": True}, style("Express"))
verifier("styleMarque : les autres modes gardent la marque classique", style("Sauvetage") == style("Normal") and style(None) == style("Normal"))
EF.set("MarqueSelonMode", False)
verifier("styleMarque : MarqueSelonMode = false → toujours la marque classique", style("Urgence") == style("Normal") and style("Express") == style("Normal"))
EF.set("MarqueSelonMode", True)
# ventDecollage
duree, decalage = (lambda r: (r[0], r[1]))(appeler(Config.get("Timing"), ["Demat", "Normal"]))
v = lambda d, t: f("ventDecollage", d, t, duree, decalage)
verifier("ventDecollage : 0 pendant le silence, 0 après la fin de l'animation", v(0, decalage / 2) == 0 and v(0, decalage + duree + 0.1) == 0)
verifier("ventDecollage : 25 au milieu des souffles, tout près", abs(v(0, decalage + duree / 2) - 25) < 1e-9, v(0, decalage + duree / 2))
verifier("ventDecollage : moitié à 40 studs, rien à 80 et au-delà", abs(v(40, decalage + duree / 2) - 12.5) < 1e-9 and v(80, decalage + duree / 2) == 0 and v(500, decalage + duree / 2) == 0)
verifier("ventDecollage : monte puis redescend (début < milieu > fin)", v(0, decalage + duree * 0.1) < v(0, decalage + duree / 2) > v(0, decalage + duree * 0.9))
verifier("ventDecollage : durée nulle ou argument absent → 0", f("ventDecollage", 0, 1, 0, 0) == 0 and f("ventDecollage", None, None, duree, decalage) == 0)
EF.set("VentDecollage", 0)
verifier("ventDecollage : VentDecollage = 0 → jamais", v(0, decalage + duree / 2) == 0)
EF.set("VentDecollage", 25)
# brumeNuit
verifier("brumeNuit : 8 s la nuit (22 h, minuit), rien le jour (midi, 16 h)", f("brumeNuit", 22) == 8 and f("brumeNuit", 0) == 8 and f("brumeNuit", 12) == 0 and f("brumeNuit", 16) == 0)
EF.set("BrumeNuit", 0)
verifier("brumeNuit : BrumeNuit = 0 → jamais", f("brumeNuit", 0) == 0)
EF.set("BrumeNuit", 8)


# ================================================================== Le monde (client, maths réelles)
ws = game.m_FindFirstChild("Workspace")
RunService = game.m_FindFirstChild("RunService")
Lighting = game.m_FindFirstChild("Lighting")
Lighting.props.update({"ClockTime": 12, "ExposureCompensation": 0, "Ambient": Couleur(0.5, 0.5, 0.5), "OutdoorAmbient": Couleur(0.5, 0.5, 0.5)})
Instance("PlayerGui", "PlayerGui", joueur)
camera = Instance("Camera", "Camera", ws)
camera.props.update({"CFrame": CF((10, 0.5, 0)), "FieldOfView": 70, "ViewportSize": Valeur("Vector2", [1280, 720])})
ws.props["CurrentCamera"] = camera
ws.props["Terrain"] = Instance("Terrain", "Terrain")
ws.props["GlobalWind"] = Vec3(0, 0, 0)
dossier = Instance("Folder", "TARDIS", ws)
def cabine(nom, pos):
    t = Instance("Folder", nom, dossier)
    x = Instance("Model", "Cabine", Instance("Folder", "EXTERIEURE", t))
    salle = Instance("Model", "Salle", Instance("Folder", "INTERIEURE", t))
    x.props.update({"Pivot": CF(pos), "ExtentsSize": Vec3(4, 9, 4), "BoiteCFrame": CF((pos[0], pos[1] + 4.5, pos[2])), "BoiteTaille": Vec3(4, 9, 4)})
    racine = Instance("Part", "Racine", x); racine.props.update({"Size": Vec3(4, 1, 4), "Transparency": 1, "CFrame": CF(pos)}); x.props["PrimaryPart"] = racine
    lampe = Instance("Part", "Lampe", x); lampe.props.update({"Size": Vec3(1, 1, 1), "CFrame": CF((pos[0], pos[1] + 9, pos[2]))})
    Instance("PointLight", "PointLight", lampe).props.update({"Brightness": 2, "Range": 10})
    Instance("Folder", "Boucliers", x)
    Instance("ObjectValue", "TracteurCible", x).props["Value"] = None
    corps = Instance("Part", "Corps", x)
    enseigne = Instance("SurfaceGui", "Enseigne", corps); enseigne.props["Brightness"] = 1
    Instance("TextLabel", "Texte", enseigne).props.update({"Text": "POLICE BOX", "TextColor3": Couleur(1, 1, 1), "TextTransparency": 0, "TextStrokeTransparency": 1})
    rotor = Instance("Part", "Rotor", salle); salle.props.update({"PrimaryPart": rotor, "BoiteCFrame": CF((pos[0], 1000, pos[2])), "BoiteTaille": Vec3(40, 20, 40)})
    Instance("PointLight", "Lumiere", Instance("Part", "Plafond", salle)).props["Color"] = Couleur(1, 1, 1)
    x.attrs.update({"Etat": "Pose", "DebutEtat": 1000.0, "Mode": "Normal"})
    return x, salle, lampe
x, interieur, lampe = cabine("TARDIS_1", (0, 0.5, 0))
# Le sol (y = 0) sous la cabine ; un toit (TOIT["y"]) au-dessus si on en met un
solPart = Instance("Part", "Sol"); solPart.props["Color"] = Couleur(0.5, 0.5, 0.5)
toitPart = Instance("Part", "Toit")
SOL = {"materiau": "Grass", "present": True}
TOIT = {"y": None}
RAYONS = []
def raycast(_w, origine, direction, params=None):
    RAYONS.append((origine, direction))
    if direction.y < 0:
        if not SOL["present"] or origine.y + direction.y > 0: return None
        return Table({"Position": Vec3(origine.x, 0, origine.z), "Normal": Vec3(0, 1, 0), "Instance": solPart, "Material": Valeur("Enum.Material." + SOL["materiau"])})
    if direction.y > 0 and TOIT["y"] is not None and origine.y < TOIT["y"] <= origine.y + direction.y:
        return Table({"Position": Vec3(origine.x, TOIT["y"], origine.z), "Normal": Vec3(0, -1, 0), "Instance": toitPart, "Material": Valeur("Enum.Material.Concrete")})
    return None
ws.extra["Raycast"] = Fonction("Raycast", py=raycast)

def image(dt=0.1, n=1):
    for _ in range(n):
        H.avancer(dt)
        for nom in ("RenderStepped", "Heartbeat"):
            sig = RunService.extra.get(nom)
            if sig: sig.declencher(dt)
def maintenant(): return 1000.0 + H.t
def etat(nom, mode="Normal", cab=None):
    cab = cab or x
    cab.m_SetAttribute("Mode", mode); cab.m_SetAttribute("DebutEtat", maintenant()); cab.m_SetAttribute("Etat", nom)
def pref(cle, valeur): UI.get("prefs").set(cle, valeur)
def dans_ws(prefixe): return [e for e in ws.enfants if e.Name.startswith(prefixe)]
def descendants(o):
    r = []
    for e in o.enfants: r.append(e); r.extend(descendants(e))
    return r
def nettoyer(*prefixes):
    for p in prefixes:
        for o in dans_ws(p): o.set_parent(None)

init = lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/init.client.lua")
outils = init[init.index("local function partTemporaire(proprietes)"):init.index("-- La lampe du toit : la pièce qui contient la PointLight")]
def outils_de(cab):
    O = {}
    tache(lambda: O.update(t=premier(I.executer("local exterieur, Config, E = ...\n" + outils + "\nreturn { partTemporaire = partTemporaire, progressionAnimation = progressionAnimation }",
                                                "outils-extras", (cab, Config, E)))))
    return O["t"]
SECOUSSES = []
def contexte(cab=x, salle=None, lampe_=None, nom="TARDIS_1"):
    o = outils_de(cab)
    return Table({"C": UI.get("C"), "Config": Config, "E": E, "Lighting": Lighting, "RunService": RunService, "UI": UI, "animer": UI.get("animer"),
                  "camera": camera, "creer": UI.get("creer"), "texte": UI.get("texte"), "def": Table({"Nom": nom}), "exterieur": cab,
                  "interieur": salle or interieur, "joueur": joueur, "jeSuisDedans": Fonction("jeSuisDedans", py=lambda: False),
                  "partTemporaire": o.get("partTemporaire"), "progressionAnimation": o.get("progressionAnimation"), "lampe": lampe_ or lampe,
                  "remote": Instance("RemoteEvent", "TardisCommande_" + nom, rs), "ReplicatedStorage": rs,
                  "secouer": Fonction("secouer", py=lambda *a: SECOUSSES.append(a) or [])})
def module(nom, ctx=None):
    res = {}
    tache(lambda: res.update(m=premier(appeler(premier(I.executer(lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/" + nom + ".lua"), nom)), [ctx or contexte()]))))
    return res.get("m")


# ================================================================== 2. Signalisation : traces au sol
module("Signalisation")
verifier("Signalisation se charge (maths réelles)", not roblox.ERREURS, roblox.ERREURS[:3])
VERT = premier(appeler(UI.get("couleurMode"), ["Express"]))
def atterrir(mode, **attrs):
    for k, v in attrs.items(): x.m_SetAttribute(k, v)
    etat("Remat", mode); image(0.1, 5)
    x.m_SetAttribute("Mode", "Normal"); etat("Pose"); image(0.1, 2)  # le serveur remet Mode à Normal en posant
    for k in attrs: x.m_SetAttribute(k, None)
    return ws.m_FindFirstChild("TardisMarqueSol_TARDIS_1")
m = atterrir("Normal")
verifier("G-19. Classique : la marque de la V6.9.9 (5 × 0,05 × 5, transparence 0,7, couleur du sol assombrie)",
         m is not None and m.props["Size"].t() == (5.0, 0.05, 5.0) and m.props["Transparency"] == 0.7 and m.props["Material"].nom == "Enum.Material.SmoothPlastic"
         and proche(norm(m.props["Color"]), (0.175, 0.175, 0.175), 0.005), m and (m.props["Size"].t(), m.props["Transparency"], m.props["Color"].rgb255()))
verifier("G-19. Classique : ni fumée, ni givre", m is not None and not m.m_FindFirstChild("Fumee") and not dans_ws("TardisGivreSol"))
m = atterrir("Urgence")
fumee = m and m.m_FindFirstChild("Fumee")
verifier("G-19. Urgence : marque brûlée (plus sombre, 0,075) et plus visible (0,55)",
         m is not None and m.props["Transparency"] == 0.55 and proche(norm(m.props["Color"]), (0.075, 0.075, 0.075), 0.005), m and (m.props["Transparency"], m.props["Color"].rgb255()))
verifier("G-19. Urgence : un filet de fumée monte de la trace", fumee is not None and fumee.ClassName == "ParticleEmitter" and fumee.props["Rate"] == 6, fumee)
g = ws.m_FindFirstChild("TardisGivreSol_TARDIS_1")
verifier("G-20. Urgence : disque de givre au sol (glace, 2,4 × la cabine, transparence 0,3)",
         g is not None and g.props["Material"].nom == "Enum.Material.Ice" and g.props["Shape"].nom == "Enum.PartType.Cylinder"
         and proche(g.props["Size"].t(), (0.04, 9.6, 9.6)) and g.props["Transparency"] == 0.3, g and (g.props["Size"].t(), g.props["Transparency"]))
verifier("G-20. Le givre est posé juste au-dessus du sol, sous la marque", g is not None and abs(g.props["CFrame"].p[1] - 0.015) < 1e-9 and abs(m.props["CFrame"].p[1] - 0.03) < 1e-9)
H.avancer(8.5); image(0.1)
verifier("G-19. La fumée s'arrête après 8 s", fumee is not None and fumee.props.get("Enabled") is False)
H.avancer(17); image(0.1)
verifier("G-20. Le givre a fondu après 25 s (et la marque est toujours là jusqu'à 30 s)", g.parent is None and not dans_ws("TardisGivreSol") and m.parent is not None)
m = atterrir("Catastrophe")
verifier("G-19. Catastrophe : brûlée et fumante aussi, mais pas de givre", m is not None and m.props["Transparency"] == 0.55 and m.m_FindFirstChild("Fumee") and not dans_ws("TardisGivreSol"))
m = atterrir("Express")
verifier("G-19. Rapide : trace nette et verte (néon, couleur du mode, transparence 0,6)",
         m is not None and m.props["Material"].nom == "Enum.Material.Neon" and m.props["Color"] == VERT and m.props["Transparency"] == 0.6 and not m.m_FindFirstChild("Fumee"),
         m and (m.props["Material"].nom, m.props["Transparency"]))
verifier("G-19. Toujours une seule marque par TARDIS", len(dans_ws("TardisMarqueSol")) == 1, len(dans_ws("TardisMarqueSol")))
pref("effetsReduits", True)
m = atterrir("Urgence")
verifier("G-19. Effets réduits : marque brûlée mais sans fumée", m is not None and m.props["Transparency"] == 0.55 and not m.m_FindFirstChild("Fumee"))
pref("effetsReduits", False)
atterrir("Urgence")
verifier("G-20. Un seul disque de givre par TARDIS (le nouveau remplace l'ancien)", len(dans_ws("TardisGivreSol")) == 1, len(dans_ws("TardisGivreSol")))
nettoyer("TardisMarqueSol", "TardisGivreSol")
EF.set("MarqueSelonMode", False)
m = atterrir("Urgence")
verifier("G-19. MarqueSelonMode = false : marque classique même en Urgence (le givre reste)", m is not None and m.props["Transparency"] == 0.7 and dans_ws("TardisGivreSol"))
EF.set("MarqueSelonMode", True); nettoyer("TardisMarqueSol", "TardisGivreSol")
EF.set("GivreSol", 0)
atterrir("Urgence")
verifier("G-20. GivreSol = 0 : pas de givre", not dans_ws("TardisGivreSol"))
EF.set("GivreSol", 25); nettoyer("TardisMarqueSol")
EF.set("MarquesSol", False)
m = atterrir("Urgence")
verifier("G-20. MarquesSol = false : pas de marque, mais le givre de l'Urgence est là", m is None and len(dans_ws("TardisGivreSol")) == 1)
EF.set("MarquesSol", True); nettoyer("TardisMarqueSol", "TardisGivreSol")
verifier("G-19/20. Silencieux : ni marque ni givre", atterrir("Silencieux") is None and not dans_ws("TardisGivreSol"))
verifier("G-19/20. Sur l'eau, camouflée : rien", atterrir("Urgence", SurEau=True) is None and atterrir("Urgence", Camouflage=True) is None and not dans_ws("TardisGivreSol"))
# G-29 : brume la nuit
verifier("G-29. Le jour : pas de brume", not dans_ws("TardisBrume"))
nettoyer("TardisMarqueSol")
Lighting.props["ClockTime"] = 22
atterrir("Normal")
b = ws.m_FindFirstChild("TardisBrume_TARDIS_1")
em = b and b.m_FindFirstChild("Brume")
verifier("G-29. La nuit : une nappe de brume basse autour de la base (invisible elle-même, 2,6 × la cabine)",
         b is not None and b.props["Transparency"] == 1 and proche(b.props["Size"].t(), (10.4, 0.4, 10.4)) and abs(b.props["CFrame"].p[1] - 0.4) < 1e-9, b and b.props["Size"].t())
verifier("G-29. Émetteur de brume (débit 9)", em is not None and em.props["Rate"] == 9 and em.props.get("Enabled") is not False, em and em.props.get("Rate"))
H.avancer(8.2); image(0.1)
verifier("G-29. La brume cesse d'être émise après 8 s…", em.props.get("Enabled") is False and b.parent is not None)
H.avancer(6.1); image(0.1)
verifier("G-29. … et la nappe disparaît 6 s plus tard", b.parent is None and not dans_ws("TardisBrume"))
pref("effetsReduits", True); atterrir("Normal")
b = ws.m_FindFirstChild("TardisBrume_TARDIS_1")
verifier("G-29. Effets réduits : brume plus légère (débit 4)", b is not None and b.m_FindFirstChild("Brume").props["Rate"] == 4)
pref("effetsReduits", False); nettoyer("TardisBrume", "TardisMarqueSol")
EF.set("BrumeNuit", 0); atterrir("Normal")
verifier("G-29. BrumeNuit = 0 : jamais de brume", not dans_ws("TardisBrume"))
EF.set("BrumeNuit", 8); nettoyer("TardisMarqueSol")
Lighting.props["ClockTime"] = 12
# G-22 : poussière du plafond
atterrir("Normal")
verifier("G-22. Sans toit : pas de poussière", not dans_ws("TardisPoussiere"))
haut = [o for o, d in RAYONS if d.y > 0]
verifier("G-22. Le rayon vers le haut part du haut de la cabine (y = 9,7) sur 20 studs", haut and abs(haut[-1].y - 9.7) < 1e-9 and [d for o, d in RAYONS if d.y > 0][-1].y == 20,
         haut and haut[-1].t())
nettoyer("TardisMarqueSol")
TOIT["y"] = 15
atterrir("Normal")
p_ = ws.m_FindFirstChild("TardisPoussiere_TARDIS_1")
pou, deb = p_ and p_.m_FindFirstChild("Poussiere"), p_ and p_.m_FindFirstChild("Debris")
verifier("G-22. Sous un toit à 15 studs : poussière et débris tombent du plafond (60 et 20 particules)",
         p_ is not None and abs(p_.props["CFrame"].p[1] - 14.7) < 1e-9 and pou and pou.emis == 60 and deb and deb.emis == 20,
         p_ and (p_.props["CFrame"].p, pou and pou.emis, deb and deb.emis))
verifier("G-22. Les particules tombent (direction vers le bas, gravité)", pou is not None and pou.props["EmissionDirection"].nom == "Enum.NormalId.Bottom" and pou.props["Acceleration"].y < 0)
H.avancer(4.2); image(0.1)
verifier("G-22. Nettoyée après 4 s", p_.parent is None)
nettoyer("TardisMarqueSol")
pref("effetsReduits", True); atterrir("Normal")
p_ = ws.m_FindFirstChild("TardisPoussiere_TARDIS_1")
verifier("G-22. Effets réduits : moins de particules (25 et 8)", p_ is not None and p_.m_FindFirstChild("Poussiere").emis == 25 and p_.m_FindFirstChild("Debris").emis == 8)
pref("effetsReduits", False); nettoyer("TardisPoussiere", "TardisMarqueSol")
TOIT["y"] = 40
atterrir("Normal")
verifier("G-22. Toit trop haut (au-delà de PoussierePlafond) : rien", not dans_ws("TardisPoussiere"))
TOIT["y"] = 15; EF.set("PoussierePlafond", 0); nettoyer("TardisMarqueSol")
atterrir("Normal")
verifier("G-22. PoussierePlafond = 0 : jamais", not dans_ws("TardisPoussiere"))
EF.set("PoussierePlafond", 20); TOIT["y"] = None; nettoyer("TardisMarqueSol")
verifier("Signalisation : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])


# ================================================================== 3. Decor : gerbe au départ et vent du décollage
decor_src = lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Decor.lua")
FN = {}
tache(lambda: FN.update(f=premier(I.executer(decor_src, "Decor"))))
tache(lambda: appeler(FN["f"], [contexte()]))
verifier("Decor se charge (maths réelles)", not roblox.ERREURS, roblox.ERREURS[:3])
def emissions():
    return sorted(e.emis for s in dans_ws("TardisTerrain") for e in s.enfants if e.ClassName == "ParticleEmitter" and e.emis)
nettoyer("TardisTerrain")
x.m_SetAttribute("TerrainAtterrissage", "Sand"); x.m_SetAttribute("TerrainTemps", maintenant()); image(0.1)
verifier("G-21. Atterrissage sur le sable : la gerbe de toujours (70 particules)", emissions() == [70], emissions())
H.avancer(5.5); image(0.1); nettoyer("TardisTerrain")
duree, decalage = (lambda r: (r[0], r[1]))(appeler(Config.get("Timing"), ["Demat", "Normal"]))
camera.props["CFrame"] = CF((500, 0.5, 0))  # (loin : le vent ne compte pas ici)
etat("Demat", "Normal"); image(0.1, int(decalage / 0.1) - 2)
verifier("G-21. Départ : rien pendant le silence du son", not dans_ws("TardisTerrain"))
image(0.1, 4)
verifier("G-21. Départ : la gerbe part quand la cabine s'efface, moitié moins forte (35)", emissions() == [35], emissions())
etat("Pose"); H.avancer(5.5); image(0.1); nettoyer("TardisTerrain")
x.m_SetAttribute("TerrainAtterrissage", "Metal"); n0 = len(SECOUSSES)
etat("Demat", "Normal"); image(0.1, int(decalage / 0.1) + 2)
vap = [e for s in dans_ws("TardisTerrain") for e in s.enfants if e.ClassName == "ParticleEmitter" and not e.emis]
verifier("G-21. Départ sur du métal : étincelles (30), sans vapeur ni secousse", emissions() == [30] and vap and all(e.props["Rate"] == 0 for e in vap) and len(SECOUSSES) == n0,
         (emissions(), [e.props["Rate"] for e in vap], len(SECOUSSES) - n0))
etat("Pose"); H.avancer(5.5); image(0.1); nettoyer("TardisTerrain")
x.m_SetAttribute("TerrainTemps", maintenant()); image(0.1)
verifier("G-21. Atterrissage sur du métal : vapeur et secousse comme avant", len(SECOUSSES) == n0 + 1 and any(e.props["Rate"] == 40 for s in dans_ws("TardisTerrain") for e in s.enfants if e.ClassName == "ParticleEmitter"))
H.avancer(5.5); image(0.1); nettoyer("TardisTerrain")
x.m_SetAttribute("TerrainAtterrissage", "Sand")
def depart(mode="Normal", **attrs):
    for k, v in attrs.items(): x.m_SetAttribute(k, v)
    etat("Demat", mode); d = (lambda r: r[1])(appeler(Config.get("Timing"), ["Demat", mode]))
    image(0.1, int(d / 0.1) + 3); n = emissions()
    etat("Pose"); H.avancer(5.5); image(0.1); nettoyer("TardisTerrain")
    for k in attrs: x.m_SetAttribute(k, None)
    return n
verifier("G-21. Départ en Silencieux, camouflée, en vol libre ou sur l'eau : pas de gerbe",
         depart("Silencieux") == [] and depart(Camouflage=True) == [] and depart(VolLibre=1) == [] and depart(SurEau=True) == [])
x.m_SetAttribute("TerrainAtterrissage", "Inconnu")
verifier("G-21. Sol inconnu : pas de gerbe au départ", depart() == [])
x.m_SetAttribute("TerrainAtterrissage", "Sand")
EF.set("TerrainDepart", False)
verifier("G-21. TerrainDepart = false : pas de gerbe au départ", depart() == [])
EF.set("TerrainDepart", True)
verifier("G-21. Urgence (silence plus court) : la gerbe part aussi", depart("Urgence") == [35])
etat("Demat", "Normal"); image(0.1, 3); etat("Pose"); image(0.1, int(decalage / 0.1) + 3)
verifier("G-21. Départ annulé pendant le silence : pas de gerbe", not dans_ws("TardisTerrain"))
# G-23 : vent
camera.props["CFrame"] = CF((10, 0.5, 0))
def vol(mode="Normal", pendant=None):
    etat("Demat", mode); d, dc = (lambda r: (r[0], r[1]))(appeler(Config.get("Timing"), ["Demat", mode]))
    vents = []
    for k in range(int((dc + d) / 0.1) + 5):
        if pendant and k == pendant[0]: ws.props["GlobalWind"] = pendant[1]
        image(0.1); vents.append(ws.props["GlobalWind"])
    etat("Pose"); image(0.1, 3)
    return vents
ws.props["GlobalWind"] = Vec3(0, 0, 0)
vents = vol()
xs = [w.x for w in vents]
silence = int(decalage / 0.1) - 1
verifier("G-23. Pendant le silence : le vent ne bouge pas", all(abs(w.x) < 1e-9 and abs(w.z) < 1e-9 for w in vents[:silence]), xs[:silence])
verifier("G-23. Pendant les souffles : le vent pousse vers l'extérieur de la cabine (+X ici), jusqu'à ≈ 21,9 à 10 studs",
         max(xs) > 20 and max(xs) < 21.9 + 1e-6 and all(abs(w.z) < 1e-9 and abs(w.y) < 1e-9 for w in vents), max(xs))
verifier("G-23. Fin du voyage : le vent revient exactement à sa valeur d'avant", ws.props["GlobalWind"].t() == (0, 0, 0), ws.props["GlobalWind"].t())
ws.props["GlobalWind"] = Vec3(0, 0, 4)
vol()
verifier("G-23. Avec un vent déjà là (0, 0, 4) : il est rendu tel quel", ws.props["GlobalWind"].t() == (0, 0, 4), ws.props["GlobalWind"].t())
vol(pendant=(int(decalage / 0.1) + 10, Vec3(3, 0, 0)))
verifier("G-23. Un autre script change le vent pendant le voyage : c'est sa valeur qui reste", proche(ws.props["GlobalWind"].t(), (3, 0, 0)), ws.props["GlobalWind"].t())
ws.props["GlobalWind"] = Vec3(0, 0, 0)
camera.props["CFrame"] = CF((120, 0.5, 0))
verifier("G-23. De loin (120 studs) : le vent ne bouge pas", all(w.t() == (0, 0, 0) for w in vol()))
camera.props["CFrame"] = CF((10, 0.5, 0))
verifier("G-23. Silencieux : pas de vent", all(w.t() == (0, 0, 0) for w in vol("Silencieux")))
x.m_SetAttribute("Camouflage", True)
verifier("G-23. Camouflée : pas de vent", all(w.t() == (0, 0, 0) for w in vol()))
x.m_SetAttribute("Camouflage", None)
EF.set("VentDecollage", 0)
verifier("G-23. VentDecollage = 0 : jamais", all(w.t() == (0, 0, 0) for w in vol()))
EF.set("VentDecollage", 25)
etat("Remat", "Normal"); dR, dcR = (lambda r: (r[0], r[1]))(appeler(Config.get("Timing"), ["Remat", "Normal"]))
rem = []
for _ in range(int((dcR + dR) / 0.1) + 5): image(0.1); rem.append(ws.props["GlobalWind"].x)
etat("Pose"); image(0.1, 3)
verifier("G-23. À l'arrivée aussi, puis retour au calme", max(rem) > 20 and ws.props["GlobalWind"].t() == (0, 0, 0), (max(rem), ws.props["GlobalWind"].t()))
# Deux TARDIS qui décollent ensemble, l'un à gauche, l'autre à droite : le vent ne s'emballe pas
x2, salle2, lampe2 = cabine("TARDIS_2", (20, 0.5, 0))
tache(lambda: appeler(FN["f"], [contexte(x2, salle2, lampe2, "TARDIS_2")]))  # même module chargé une fois : table du vent partagée
camera.props["CFrame"] = CF((10, 0.5, 5))
x2.m_SetAttribute("TerrainAtterrissage", "Sand")
etat("Demat", "Normal"); etat("Demat", "Normal", x2)
deux = []
for _ in range(int((decalage + duree) / 0.1) + 5): image(0.1); deux.append(ws.props["GlobalWind"])
etat("Pose"); etat("Pose", "Normal", x2); image(0.1, 3)
verifier("G-23. Deux TARDIS ensemble : leurs poussées s'ajoutent (en X elles s'annulent, en Z elles s'ajoutent) sans s'emballer",
         max(abs(w.x) for w in deux) < 1e-6 and 0 < max(w.z for w in deux) <= 2 * 25 + 1e-6, (max(abs(w.x) for w in deux), max(w.z for w in deux)))
verifier("G-23. Deux TARDIS : le vent revient à zéro à la fin", ws.props["GlobalWind"].t() == (0, 0, 0), ws.props["GlobalWind"].t())
H.avancer(6); image(0.1); nettoyer("TardisTerrain")
for o in (x2.parent.parent,): o.set_parent(None)
camera.props["CFrame"] = CF((10, 0.5, 0))
verifier("Decor : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])


# ================================================================== 4. EffetsExterieurs : cercle gallifreyen (G-12)
module("EffetsExterieurs")
verifier("EffetsExterieurs se charge (maths réelles)", not roblox.ERREURS, roblox.ERREURS[:3])
def remat(mode="Normal", a=0.3):
    etat("Remat", mode); d, dc = (lambda r: (r[0], r[1]))(appeler(Config.get("Timing"), ["Remat", mode]))
    image(0.1, int((dc + d * a) / 0.1))
    return ws.m_FindFirstChild("TardisCercle_TARDIS_1")
c = remat()
gui = c and c.m_FindFirstChild("Ecran"); gr = gui and gui.m_FindFirstChild("Groupe")
verifier("G-12. Remat : un cercle sous l'ombre (1,9 × la cabine), à peine au-dessus d'elle",
         c is not None and proche(c.props["Size"].t(), (7.6, 0.05, 7.6)) and abs(c.props["CFrame"].p[1] - 0.09) < 1e-9 and ws.m_FindFirstChild("TardisOmbre"),
         c and (c.props["Size"].t(), c.props["CFrame"].p))
verifier("G-12. Dessiné sur le dessus (SurfaceGui Top, lumineux, sans ombre de la lumière)",
         gui is not None and gui.props["Face"].nom == "Enum.NormalId.Top" and gui.props["Brightness"] == 2 and gui.props["LightInfluence"] == 0)
frames = [o for o in descendants(gr) if o.ClassName == "Frame"] if gr else []
traits = [o for o in descendants(gr) if o.ClassName == "UIStroke"] if gr else []
verifier("G-12. Sans image : écriture dessinée par le code (4 anneaux, 8 « mots », 4 points)", len(frames) == 16 and len(traits) == 12, (len(frames), len(traits)))
t1_ = gr.props["GroupTransparency"] if gr else None
a1 = c.props["CFrame"]; image(0.1, 5); a2 = c.props["CFrame"]
verifier("G-12. Le cercle tourne lentement", a1 is not a2 and a1.fois(CF((1, 0, 0))).p != a2.fois(CF((1, 0, 0))).p)
t2_ = gr.props["GroupTransparency"] if gr else None
verifier("G-12. Bien visible au début, il s'efface à mesure que la cabine apparaît", t1_ is not None and 0.15 < t1_ < t2_ <= 1, (t1_, t2_))
etat("Pose"); image(0.1, 3)
verifier("G-12. Cabine posée : le cercle est retiré avec l'ombre", c.parent is None and not dans_ws("TardisCercle") and not dans_ws("TardisOmbre"))
EF.set("ImageCercle", "rbxassetid://123")
c = remat()
im = c and c.m_FindFirstChild("Ecran").m_FindFirstChild("Groupe").m_FindFirstChild("Image")
verifier("G-12. Avec Effets.ImageCercle : l'image est utilisée à la place du dessin", im is not None and im.props["Image"] == "rbxassetid://123"
         and not [o for o in descendants(c) if o.ClassName == "Frame"])
etat("Pose"); image(0.1, 3)
EF.set("ImageCercle", "")
EF.set("CercleGallifreyen", False)
remat()
verifier("G-12. CercleGallifreyen = false : l'ombre seule", not dans_ws("TardisCercle") and dans_ws("TardisOmbre"))
etat("Pose"); image(0.1, 3)
EF.set("CercleGallifreyen", True)
verifier("G-12. Silencieux : ni ombre ni cercle", remat("Silencieux") is None and not dans_ws("TardisOmbre"))
etat("Pose"); image(0.1, 3)
etat("Demat", "Urgence"); image(0.1, 30)
verifier("G-12. Démat d'urgence (air qui ondule) : pas de cercle", not dans_ws("TardisCercle"))
etat("Pose"); image(0.1, 40)
verifier("EffetsExterieurs : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])

# Le code
sig = lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Signalisation.lua")
eff = lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/EffetsExterieurs.lua")
verifier("Côté client seulement : aucune action réseau ajoutée (Decor, Signalisation)", decor_src.count("FireServer") == 0 and sig.count("FireServer") == 0)
verifier("Decor : la table du vent est en dehors de la fonction (partagée par tous les TARDIS)",
         decor_src.index("local VENT = {") < decor_src.index("return function(contexte)"))
verifier("Signalisation : l'appel passe le mode de l'arrivée", "task.defer(marqueAtterrissage, modeArrivee)" in sig)


# ================================================================== 5. TardisSystemes : saleté selon le sol (C-178)
from banc import place, demarrer_serveur
P = place()
P["ws"].extra["GetPartBoundsInRadius"] = Fonction("GetPartBoundsInRadius", py=lambda *a: Table({}))  # rien autour (pas de physique ici)
_, err = demarrer_serveur(P, duree=20)  # TardisServeur crée le canal attendu par TardisSystemes
verifier("TardisServeur et TardisSystemes démarrent (banc d'essai)", not err, err[:3])
ext = P["ext"]
def poser(sol_):
    avant = ext.m_GetAttribute("Salete") or 0
    ext.m_SetAttribute("Etat", "Remat"); H.avancer(0.5)
    ext.m_SetAttribute("Etat", "Pose")
    H.avancer(0.1); ext.m_SetAttribute("TerrainAtterrissage", sol_)  # comme surAtterrissage, 0,1 s après
    H.avancer(0.5)
    return (ext.m_GetAttribute("Salete") or 0) - avant
ext.m_SetAttribute("Salete", 0)
gains = {s: poser(s) for s in ("Sand", "Snow", "Mud", "Concrete")}
verifier("C-178. Saleté gagnée : sable 12, neige 4, boue 14, béton 8 (le sol lu après l'arrivée)",
         all(abs(gains[k] - v) < 1e-9 for k, v in {"Sand": 12, "Snow": 4, "Mud": 14, "Concrete": 8}.items()), gains)
ext.m_SetAttribute("Salete", 95)
verifier("C-178. Plafonnée à 100", (poser("Mud"), ext.m_GetAttribute("Salete"))[1] == 100)
verifier("TardisSystemes : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])

print("\n".join("  ✓ " + n for n in OK))
print("\n".join("  ✗ " + n for n in KO))
print(f"TRACES AU SOL (V7.2.2) : {len(OK)}/{len(OK) + len(KO)} vérifications réussies")
sys.exit(1 if KO else 0)
