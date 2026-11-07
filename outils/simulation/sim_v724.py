"""Simulations de la V7.2.4 (saisons et météo) : le vrai code, exécuté avec de faux objets Roblox et des maths réelles.
  1. TardisConfig : dates sans os.date (joursDe, dateDe), Pâques, saison du jour, décoration effective (C-186, G-100),
     couche sur le toit (G-32), éclair (G-31).
  2. Decor (le module entier) : la date choisit la décoration ; Pâques, Nouvel An (feu d'artifice), anniversaire ; la salle
     décorée à Noël et à Halloween (G-190) ; neige ou feuilles sur le toit qui glissent à la démat (G-32) ; éclair (G-31).
  3. TardisSystemes (le vrai Script serveur, banc d'essai) : éclair pendant l'orage, l'orage compte comme pluie.
  4. Le code : bouton de la tablette, choix du serveur, contexte de Decor."""
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
random.seed(724)

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
SA = Config.get("Saisons")
f = lambda nom, *a: premier(appeler(Config.get(nom), list(a)))
fs = lambda nom, *a: list(appeler(Config.get(nom), list(a)))
import datetime
def sec(a, m, j, h=12): return (datetime.datetime(a, m, j, h, tzinfo=datetime.timezone.utc) - datetime.datetime(1970, 1, 1, tzinfo=datetime.timezone.utc)).total_seconds()

verifier("Config.Version ≥ 7.2.4 (7.2.4 à sa sortie)", tuple(int(n) for n in Config.get("Version").split(".")) >= (7, 2, 4), Config.get("Version"))
verifier("Config.Saisons : Automatique, Anniversaire vide, Salle, ToitNeige 60, AttributOrage « Orage », ChanceEclair 0,15",
         (SA.get("Automatique"), SA.get("Anniversaire"), SA.get("Salle"), SA.get("ToitNeige"), SA.get("AttributOrage"), SA.get("ChanceEclair")) == (True, "", True, 60, "Orage", 0.15))
decos = [Config.get("Decorations").get(i) for i in range(1, 7)]
verifier("Config.Decorations : les six décorations (Aucune, Noël, Halloween, Pâques, Nouvel An, anniversaire)",
         decos == ["Aucune", "Noel", "Halloween", "Paques", "NouvelAn", "Anniversaire"], decos)
ND = Config.get("NomsDecorations")
verifier("Config.NomsDecorations : un nom lisible pour chacune et pour Auto", all(ND.get(k) for k in decos + ["Auto"]) and ND.get("Noel") == "Noël")
# joursDe / dateDe
ok = True
for a, m, j in [(1970, 1, 1), (2000, 2, 29), (2024, 12, 31), (2026, 11, 7), (2027, 3, 1), (2100, 3, 1), (1999, 12, 31)]:
    n = f("joursDe", a, m, j)
    attendu = (datetime.date(a, m, j) - datetime.date(1970, 1, 1)).days
    if n != attendu or fs("dateDe", sec(a, m, j)) != [a, m, j]: ok = False; print("  date", a, m, j, n, attendu, fs("dateDe", sec(a, m, j)))
verifier("joursDe et dateDe : justes (années bissextiles, 2000, 2100, 1970)", ok)
verifier("dateDe : 23 h 59 reste le même jour, minuit passe au suivant", fs("dateDe", sec(2026, 12, 24, 23) + 3599) == [2026, 12, 24] and fs("dateDe", sec(2026, 12, 25, 0)) == [2026, 12, 25])
verifier("dateDe : valeur absente → 1er janvier 1970", fs("dateDe", None) == [1970, 1, 1])
# Pâques
paques = {2024: [3, 31], 2025: [4, 20], 2026: [4, 5], 2027: [3, 28], 2028: [4, 16], 2038: [4, 25], 2285: [3, 22]}
verifier("paques : 31/03/2024, 20/04/2025, 05/04/2026, 28/03/2027, 16/04/2028, 25/04/2038, 22/03/2285",
         all(fs("paques", a) == v for a, v in paques.items()), {a: fs("paques", a) for a in paques})
# saisonDe
s = lambda *d: f("saisonDe", sec(*d))
verifier("saisonDe : décembre → Noël (1er et 24/12)", s(2026, 12, 1) == "Noel" and s(2026, 12, 24) == "Noel")
verifier("saisonDe : Nouvel An du 31/12 au 2/01, pas le 3/01", s(2026, 12, 31) == "NouvelAn" and s(2027, 1, 1) == "NouvelAn" and s(2027, 1, 2) == "NouvelAn" and s(2027, 1, 3) is None)
verifier("saisonDe : octobre → Halloween (1er et 31/10)", s(2026, 10, 1) == "Halloween" and s(2026, 10, 31) == "Halloween")
verifier("saisonDe : Pâques 2027 (28/03) : du 21/03 au lundi 29/03", s(2027, 3, 21) == "Paques" and s(2027, 3, 28) == "Paques" and s(2027, 3, 29) == "Paques"
         and s(2027, 3, 20) is None and s(2027, 3, 30) is None)
verifier("saisonDe : Pâques 2026 (05/04) : le 30/03 oui, le 7/04 non", s(2026, 3, 30) == "Paques" and s(2026, 4, 7) is None)
verifier("saisonDe : hors saison (juillet, novembre) → rien", s(2026, 7, 14) is None and s(2026, 11, 7) is None)
SA.set("Anniversaire", "06-21")
verifier("saisonDe : anniversaire du serveur « 06-21 » le 21/06, pas le 22", s(2027, 6, 21) == "Anniversaire" and s(2027, 6, 22) is None)
SA.set("Anniversaire", "12-25")
verifier("saisonDe : l'anniversaire passe avant Noël", s(2026, 12, 25) == "Anniversaire" and s(2026, 12, 24) == "Noel")
SA.set("Anniversaire", "3-5")
verifier("saisonDe : « 3-5 » (sans zéro) marche aussi ; un texte mal écrit est ignoré", s(2026, 3, 5) == "Anniversaire" and (SA.set("Anniversaire", "juin") or s(2026, 6, 1)) is None)
SA.set("Anniversaire", "")
# decorationEffective
d = lambda a, *t: f("decorationEffective", a, sec(*t) if t else None)
verifier("C-186. Sans attribut (Auto) : la date choisit (décembre → Noël, juillet → rien)", d(None, 2026, 12, 10) == "Noel" and d(None, 2026, 7, 10) is None)
verifier("C-186. « Auto » écrit en toutes lettres : pareil", d("Auto", 2026, 10, 10) == "Halloween")
verifier("C-186. « Aucune » : rien, même à Noël", d("Aucune", 2026, 12, 10) is None)
verifier("C-186. Un choix fixe gagne sur la date (Pâques en décembre, Noël en juillet)", d("Paques", 2026, 12, 10) == "Paques" and d("Noel", 2026, 7, 10) == "Noel")
verifier("C-186. Nom inconnu : rien", d("Carnaval", 2026, 12, 10) is None)
verifier("C-186. Heure serveur pas encore connue (avant 2000) : rien en Auto, le choix fixe reste",
         f("decorationEffective", None, 1000) is None and f("decorationEffective", "Noel", 1000) == "Noel" and f("decorationEffective", None, None) is None)
SA.set("Automatique", False)
verifier("C-186. Automatique = false : rien en Auto, le choix fixe reste", d(None, 2026, 12, 10) is None and d("Halloween", 2026, 12, 10) == "Halloween")
SA.set("Automatique", True)
# coucheToit, epaisseurToit, estArbre
verifier("G-32. coucheToit : neige sur la neige, la glace, le glacier", f("coucheToit", "Snow", False) == "Neige" and f("coucheToit", "Ice", True) == "Neige" and f("coucheToit", "Glacier", False) == "Neige")
verifier("G-32. coucheToit : feuilles sous un arbre, rien sinon", f("coucheToit", "Grass", True) == "Feuilles" and f("coucheToit", "Grass", False) is None and f("coucheToit", None, None) is None)
verifier("G-32. epaisseurToit : 0, moitié à 30 s, pleine à 60 s et après", f("epaisseurToit", 0) == 0 and f("epaisseurToit", 30) == 0.5 and f("epaisseurToit", 60) == 1 and f("epaisseurToit", 500) == 1 and f("epaisseurToit", -3) == 0)
SA.set("ToitNeige", 0)
verifier("G-32. ToitNeige = 0 : jamais de couche, épaisseur 0", f("coucheToit", "Snow", True) is None and f("epaisseurToit", 30) == 0)
SA.set("ToitNeige", 60)
verifier("G-32. estArbre : herbe et feuillage, ou un nom d'arbre (Tree, Arbre, Leaves, Feuillage)",
         f("estArbre", "Bloc", "Grass") and f("estArbre", "Bloc", "LeafyGrass") and f("estArbre", "OakTree", "Wood") and f("estArbre", "GrandArbre", "Plastic")
         and f("estArbre", "Leaves", "Plastic") and f("estArbre", "Feuillage", "Plastic"))
verifier("G-32. estArbre : un toit en béton ou une pièce sans nom n'est pas un arbre", not f("estArbre", "Toit", "Concrete") and not f("estArbre", None, None))
# eclairPossible
e_ = lambda *a: f("eclairPossible", *a)
verifier("G-31. eclairPossible : orage, posée, visible, tirage sous 0,15", e_(True, True, False, 0.1) is True and e_(True, True, None, 0.149) is True)
verifier("G-31. eclairPossible : pas d'orage, en vol, camouflée, ou tirage trop haut → non",
         not e_(False, True, False, 0.0) and not e_(None, True, False, 0.0) and not e_(True, False, False, 0.0) and not e_(True, True, True, 0.0) and not e_(True, True, False, 0.15))
SA.set("ChanceEclair", 0)
verifier("G-31. ChanceEclair = 0 : jamais", not e_(True, True, False, 0.0))
SA.set("ChanceEclair", 0.15)
cfgsrc = lire("ReplicatedStorage/TardisConfig.lua")
bloc = cfgsrc[cfgsrc.index("Config.Saisons = {"):cfgsrc.index("\n}", cfgsrc.index("Config.Saisons = {"))]
reglages = [l for l in bloc.splitlines() if re.match(r"\s*\w+ = ", l)]
verifier("Chaque réglage de Config.Saisons est commenté « (V7.2.4, … »", len(reglages) == 6 and all("(V7.2.4, " in l for l in reglages), reglages[:2])
verifier("Config : aucun appel à os.date (la date se calcule à la main, pareil partout)", "os.date(" not in cfgsrc)


# ================================================================== Le monde (client, maths réelles)
ws = game.m_FindFirstChild("Workspace")
RunService = game.m_FindFirstChild("RunService")
Lighting = game.m_FindFirstChild("Lighting")
Lighting.props.update({"ClockTime": 12, "ExposureCompensation": 0, "Ambient": Couleur(0.5, 0.5, 0.5), "OutdoorAmbient": Couleur(0.5, 0.5, 0.5)})
Instance("PlayerGui", "PlayerGui", joueur)
camera = Instance("Camera", "Camera", ws)
camera.props.update({"CFrame": CF((500, 0.5, 0)), "FieldOfView": 70, "ViewportSize": Valeur("Vector2", [1280, 720])})
ws.props["CurrentCamera"] = camera
ws.props["Terrain"] = Instance("Terrain", "Terrain")
ws.props["GlobalWind"] = Vec3(0, 0, 0)
HEURE = {"t0": sec(2026, 7, 14)}
def horloge(): return HEURE["t0"] + H.t
ws.extra["GetServerTimeNow"] = Fonction("GetServerTimeNow", py=lambda *_a: horloge())
def le(a, m, j): HEURE["t0"] = sec(a, m, j) - H.t
dossier = Instance("Folder", "TARDIS", ws)
def cabine(nom, pos):
    t = Instance("Folder", nom, dossier)
    x = Instance("Model", "Cabine", Instance("Folder", "EXTERIEURE", t))
    salle = Instance("Model", "Salle", Instance("Folder", "INTERIEURE", t))
    x.props.update({"Pivot": CF(pos), "ExtentsSize": Vec3(4, 9, 4), "BoiteCFrame": CF((pos[0], pos[1] + 4.5, pos[2])), "BoiteTaille": Vec3(4, 9, 4)})
    racine = Instance("Part", "Racine", x); racine.props.update({"Size": Vec3(4, 1, 4), "Transparency": 1, "CFrame": CF(pos)}); x.props["PrimaryPart"] = racine
    lampe = Instance("Part", "Lampe", x); lampe.props.update({"Size": Vec3(1, 1, 1), "CFrame": CF((pos[0], pos[1] + 9, pos[2])), "Position": Vec3(pos[0], pos[1] + 9, pos[2])})
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
console = Instance("Part", "Console", interieur); console.props.update({"Size": Vec3(6, 4, 6), "CFrame": CF((0, 1002, 0))})
solPart = Instance("Part", "Sol"); solPart.props["Color"] = Couleur(0.5, 0.5, 0.5)
toitPart = Instance("Part", "Toit")
SOL = {"materiau": "Grass", "present": True}
TOIT = {"y": None, "materiau": "Concrete"}
def raycast(_w, origine, direction, params=None):
    if direction.y < 0:
        if not SOL["present"] or origine.y + direction.y > 0: return None
        return Table({"Position": Vec3(origine.x, 0, origine.z), "Normal": Vec3(0, 1, 0), "Instance": solPart, "Material": Valeur("Enum.Material." + SOL["materiau"])})
    if direction.y > 0 and TOIT["y"] is not None and origine.y < TOIT["y"] <= origine.y + direction.y:
        return Table({"Position": Vec3(origine.x, TOIT["y"], origine.z), "Normal": Vec3(0, -1, 0), "Instance": toitPart, "Material": Valeur("Enum.Material." + TOIT["materiau"])})
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
def nom_exact(n): return [e for e in ws.enfants if e.Name == n]
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
o = outils_de(x)
ctx = Table({"Config": Config, "ReplicatedStorage": rs, "RunService": RunService, "UI": UI, "boiteInt": CF((0, 1000, 0)), "creer": UI.get("creer"),
             "exterieur": x, "interieur": interieur, "lampe": lampe, "partTemporaire": o.get("partTemporaire"), "secouer": Fonction("secouer", py=lambda *a: [])})
decor_src = lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Decor.lua")
FN = {}
tache(lambda: FN.update(f=premier(I.executer(decor_src, "Decor"))))
tache(lambda: appeler(FN["f"], [ctx]))
verifier("Decor se charge avec son nouveau contexte (maths réelles)", not roblox.ERREURS, roblox.ERREURS[:3])


# ================================================================== 2. Decor : la date choisit la décoration
def deco(): return nom_exact("TardisDecoration")
def salle(): return nom_exact("TardisDecorationSalle")
image(0.1, 12)
verifier("C-186. Le 14 juillet, sans attribut : aucune décoration", not deco() and not salle() and not dans_ws("TardisNeige"))
le(2026, 12, 10); image(0.1, 12)
verifier("C-186. Le 10 décembre, sans attribut : Noël tout seul (20 ampoules sur le toit, neige qui tombe)", len(deco()) == 20 and len(dans_ws("TardisNeige")) == 1, len(deco()))
s_ = salle()
verifier("G-190. Noël : guirlande de 24 ampoules dans la salle, en cercle au-dessus de la console",
         len(s_) == 24 and all(abs(p.props["CFrame"].p[1] - 1004.4) < 1e-6 for p in s_)
         and all(abs(math.hypot(p.props["CFrame"].p[0], p.props["CFrame"].p[2]) - 4.5) < 1e-6 for p in s_), s_ and s_[0].props["CFrame"].p)
verifier("G-190. Noël : une ampoule sur trois éclaire (8 lumières)", sum(1 for p in s_ if p.m_FindFirstChild("PointLight")) == 8)
image(0.25, 4)
verifier("G-190. La guirlande de la salle clignote (certaines ampoules à 0,7)", any(p.props.get("Transparency") == 0.7 for p in salle()) and any(p.props.get("Transparency") == 0 for p in salle()))
x.m_SetAttribute("Decoration", "Aucune"); image(0.1)
verifier("C-186. « Aucune » choisie à la tablette : tout part tout de suite (toit et salle)", not deco() and not salle() and not dans_ws("TardisNeige"))
x.m_SetAttribute("Decoration", None); image(0.1)
verifier("C-186. Retour en Auto : Noël revient", len(deco()) == 20 and len(salle()) == 24)
le(2026, 10, 20); image(0.1, 12)
s_ = salle()
verifier("C-186. Le 20 octobre : Halloween (citrouille sur la lampe)", any(p.props["Size"].t() == (1.6, 1.3, 1.6) for p in deco()) and len(salle()) == 4)
verifier("G-190. Halloween : 4 citrouilles au sol de la salle, autour de la console, avec une lueur orange (portée 12)",
         len(s_) == 4 and all(abs(p.props["CFrame"].p[1] - 1000.7) < 1e-6 and abs(math.hypot(p.props["CFrame"].p[0], p.props["CFrame"].p[2]) - 6) < 1e-6 for p in s_)
         and all(p.m_FindFirstChild("PointLight") and p.m_FindFirstChild("PointLight").props["Range"] == 12 for p in s_), [p.props["CFrame"].p for p in s_][:1])
SA.set("Salle", False); x.m_SetAttribute("Decoration", "Noel"); image(0.1)
verifier("G-190. Saisons.Salle = false : rien dans la salle (le toit reste décoré)", len(deco()) == 20 and not salle())
SA.set("Salle", True); x.m_SetAttribute("Decoration", None)
SA.set("Automatique", False); image(0.1, 12)
verifier("C-186. Saisons.Automatique = false : rien en Auto, même en octobre", not deco() and not salle())
SA.set("Automatique", True); image(0.1, 12)
# Pâques
le(2027, 3, 28); image(0.1, 12)
oeufs = deco()
verifier("G-100. Pâques (28/03/2027) : 6 oeufs posés sur le toit, en forme d'oeuf (SpecialMesh sphère)",
         len(oeufs) == 6 and all(p.props["Size"].t() == (0.55, 0.8, 0.55) and p.m_FindFirstChild("SpecialMesh") for p in oeufs), len(oeufs))
verifier("G-100. Les oeufs sont sur le toit (y = 9,4 : haut de la cabine + la moitié de l'oeuf)", all(abs(p.props["CFrame"].p[1] - 9.4) < 1e-6 for p in oeufs), [p.props["CFrame"].p for p in oeufs][:2])
verifier("G-100. Pâques : de cinq couleurs, rien dans la salle", len({p.props["Color"].rgb255() for p in oeufs}) == 5 and not salle())
x.props["Pivot"] = CF((10, 0.5, 0)); image(0.1)
verifier("G-100. Les oeufs suivent la cabine qui bouge", all(abs(p.props["CFrame"].p[0] - 10) <= 1.6 for p in deco()), [p.props["CFrame"].p for p in deco()][:2])
x.props["Pivot"] = CF((0, 0.5, 0)); image(0.1)
# Nouvel An
le(2026, 12, 31); image(0.1, 12)
fusees = deco()
verifier("G-100. Nouvel An (31/12) : 4 fusées dorées aux coins du toit", len(fusees) == 4 and all(p.props["Shape"].nom == "Enum.PartType.Cylinder" and p.props["Material"].nom == "Enum.Material.Neon" for p in fusees), len(fusees))
def voir_feux(duree):
    vus = {}
    for _ in range(int(duree / 0.1)):
        image(0.1)
        for p in dans_ws("TardisFeu"): vus.setdefault(id(p), (p, H.t))
    return [v for v in vus.values()]
feux = voir_feux(9.05)
emis = [e.emis for p, _ in feux for e in p.enfants if e.ClassName == "ParticleEmitter"]
verifier("G-100. Un feu d'artifice toutes les 3 s au-dessus du toit (40 étincelles chacun)",
         len(feux) == 3 and all(p.props["CFrame"].p[1] >= 9.5 + 6 for p, _ in feux) and emis == [40, 40, 40], (len(feux), emis))
verifier("G-100. Chaque feu s'efface après 2 s", all(p.parent is None for p, _ in feux[:-1]) and (image(0.1, 21) or True) and feux[-1][0].parent is None)
pref("effetsReduits", True); image(0.1, 70)
feux = voir_feux(12.05)
emis = [e.emis for p, _ in feux for e in p.enfants if e.ClassName == "ParticleEmitter"]
verifier("G-100. Effets réduits : feux plus petits (15) et plus rares (toutes les 6 s)", len(feux) == 2 and emis == [15, 15], (len(feux), emis))
pref("effetsReduits", False); nettoyer("TardisFeu"); pref("sansFlash", True); image(0.1, 70)
verifier("G-100. « Aucun flash » : pas de feu d'artifice (les fusées restent)", not dans_ws("TardisFeu") and len(deco()) == 4)
pref("sansFlash", False); x.m_SetAttribute("Camouflage", True); image(0.1, 70)
verifier("G-100. Cabine camouflée : pas de feu d'artifice", not dans_ws("TardisFeu"))
x.m_SetAttribute("Camouflage", None)
# Anniversaire
SA.set("Anniversaire", "06-21"); le(2027, 6, 21); image(0.1, 12)
fanions = deco()
verifier("G-100. Anniversaire du serveur (21/06) : 16 fanions tout autour du toit", len(fanions) == 16 and all(p.props["Size"].t() == (0.5, 0.5, 0.05) for p in fanions), len(fanions))
cotes = {(round(p.props["CFrame"].p[0], 2) == 2.1, round(p.props["CFrame"].p[0], 2) == -2.1, round(p.props["CFrame"].p[2], 2) == 2.1, round(p.props["CFrame"].p[2], 2) == -2.1) for p in fanions}
verifier("G-100. Les fanions sont sur les quatre côtés", len([c for c in cotes if any(c)]) >= 4, cotes)
verifier("G-100. Plus de feu d'artifice hors du Nouvel An", (image(0.1, 40) or True) and not dans_ws("TardisFeu"))
SA.set("Anniversaire", ""); le(2026, 7, 14); image(0.1, 12)
verifier("Retour hors saison : plus rien du tout", not deco() and not salle() and not dans_ws("TardisFeu"))
verifier("Decor (décorations) : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])


# ================================================================== 2 bis. Neige ou feuilles sur le toit (G-32)
def couche(): return nom_exact("TardisCoucheToit")
def arriver(sol_, attendre=1.2):
    etat("Remat"); image(0.1, 3)
    x.m_SetAttribute("TerrainAtterrissage", sol_); etat("Pose"); image(0.1, int(attendre / 0.1))
SOL["materiau"] = "Snow"; arriver("Snow")
c = couche()
verifier("G-32. Posée sur la neige : une couche de neige fine apparaît sur le toit (90 % du toit, encore invisible)",
         len(c) == 1 and c[0].props["Material"].nom == "Enum.Material.Snow" and abs(c[0].props["Size"].t()[0] - 3.6) < 1e-6 and c[0].props["Transparency"] > 0.9,
         c and (c[0].props["Size"].t(), c[0].props["Transparency"]))
image(1, 29)
c = couche()
verifier("G-32. Après 30 s : à moitié (0,2 d'épaisseur) et bien visible", c and abs(c[0].props["Size"].t()[1] - 0.2) < 0.02 and c[0].props["Transparency"] < 0.15,
         c and (c[0].props["Size"].t(), c[0].props["Transparency"]))
image(1, 40)
c = couche()
verifier("G-32. Après 60 s : couche pleine (0,35), posée sur le toit (y = 9,175)", c and abs(c[0].props["Size"].t()[1] - 0.35) < 1e-6 and abs(c[0].props["CFrame"].p[1] - 9.175) < 1e-6,
         c and (c[0].props["Size"].t(), c[0].props["CFrame"].p))
neige = c[0]
etat("Demat"); image(0.1, 5)
bouffee = [e for e in neige.enfants if e.ClassName == "ParticleEmitter"]
verifier("G-32. Démat : la neige glisse du toit (elle s'écarte et tombe) avec une bouffée blanche (30)",
         neige.parent is not None and math.hypot(neige.props["CFrame"].p[0], neige.props["CFrame"].p[2]) > 1 and bouffee and bouffee[0].emis == 30,
         (neige.props["CFrame"].p, [b.emis for b in bouffee]))
verifier("G-32. Elle s'efface en tombant", neige.props["Transparency"] > 0.1)
image(0.1, 25)
verifier("G-32. Et disparaît après 2,5 s", neige.parent is None and not couche())
etat("Vol"); image(0.1, 12)
SOL["materiau"] = "Grass"; arriver("Grass", 3)
verifier("G-32. Posée sur l'herbe, à découvert : pas de couche", not couche())
TOIT["y"] = 20; toitPart.props["Name"] = "Toit"; etat("Vol"); image(0.1, 3); arriver("Grass", 3)
verifier("G-32. Sous un toit en béton : pas de feuilles", not couche())
toitPart.props["Name"] = "GrandArbre"; etat("Vol"); image(0.1, 3); arriver("Grass", 1.2)
f_ = couche()
verifier("G-32. Sous un arbre : 8 feuilles sur le toit, encore cachées", len(f_) == 8 and all(p.props["Transparency"] == 1 for p in f_), [p.props["Transparency"] for p in f_])
image(1, 28)
visibles = sum(1 for p in couche() if p.props["Transparency"] == 0)
verifier("G-32. Après 30 s : la moitié des feuilles est tombée sur le toit", visibles == 4, visibles)
verifier("G-32. Les feuilles restent sur le toit (dans la cabine, à hauteur du toit)", all(abs(p.props["CFrame"].p[0]) <= 1.6 and abs(p.props["CFrame"].p[1] - 9.04) < 1e-6 for p in couche()))
etat("Vol"); image(0.1)
verifier("G-32. Départ sans démat (vol libre, téléportation) : la couche part sans glisser", not couche())
toitPart.props["Name"] = "Toit"; TOIT["y"] = None
etat("Vol"); image(0.1, 3); SOL["materiau"] = "Ice"; arriver("Ice")
verifier("G-32. Posée sur la glace : neige aussi", len(couche()) == 1)
x.m_SetAttribute("Camouflage", True); image(1, 2)
verifier("G-32. Camouflée : la couche part", not couche())
x.m_SetAttribute("Camouflage", None); image(1, 2)
verifier("G-32. Un seul essai par arrivée (rien ne revient pendant la même pose)", not couche())
SA.set("ToitNeige", 0); etat("Vol"); image(0.1, 3); arriver("Snow", 3)
verifier("G-32. ToitNeige = 0 : jamais de couche", not couche())
SA.set("ToitNeige", 60); SOL["materiau"] = "Grass"; etat("Vol"); image(0.1, 3); etat("Pose"); image(0.1, 5)
verifier("Decor (toit) : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])


# ================================================================== 2 ter. Éclair (G-31)
actifs = Instance("Folder", "TardisAssets", rs)
tonnerre = Instance("Sound", "Tonnerre", actifs)
def eclairs(): return nom_exact("TardisEclair")
x.m_SetAttribute("Eclair", horloge()); image(0.05)
e_ = eclairs()
traits = [p for p in e_ if p.props.get("Material") is not None and p.props["Material"].nom == "Enum.Material.Neon"]
verifier("G-31. Éclair : 8 traits de néon en zigzag, plus un point d'impact", len(traits) == 8 and len(e_) == 9, len(e_))
haut_trait = max(p.props["CFrame"].p[1] for p in traits); bas_trait = min(p.props["CFrame"].p[1] for p in traits)
verifier("G-31. Il descend du ciel (≈ 90 studs) jusqu'au sommet de la lampe (y = 10)", haut_trait > 80 and 10 < bas_trait < 17, (haut_trait, bas_trait))
impact = [p for p in e_ if p not in traits][0]
verifier("G-31. Point d'impact sur la lampe", all(abs(a - b) < 1e-6 for a, b in zip(impact.props["CFrame"].p, (0, 10, 0))), impact.props["CFrame"].p)
etincelles = [c_ for c_ in impact.enfants if c_.ClassName == "ParticleEmitter"]
lumiere = impact.m_FindFirstChild("PointLight")
verifier("G-31. Étincelles (40) et grande lumière (luminosité 8, portée 40)", etincelles and etincelles[0].emis == 40 and lumiere and lumiere.props["Range"] == 40, [e.emis for e in etincelles])
verifier("G-31. Le tonnerre de TardisAssets est joué au point d'impact", impact.m_FindFirstChild("Tonnerre") is not None)
image(0.1, 3)
verifier("G-31. Les traits s'effacent vite (0,25 s), l'impact reste un peu", not [p for p in eclairs() if p in traits] and impact.parent is not None)
image(0.5, 12)
verifier("G-31. La lumière grésille puis s'éteint", lumiere.props.get("Enabled") is False and lumiere.props["Brightness"] in (1, 6))
verifier("G-31. Tout est parti après 6 s", not eclairs())
x.m_SetAttribute("Eclair", horloge() - 5); image(0.1)
verifier("G-31. Un vieil éclair (joueur arrivé après) n'est pas redessiné", not eclairs())
x.m_SetAttribute("Eclair", "oui"); image(0.1)
verifier("G-31. Valeur qui n'est pas une heure : rien", not eclairs())
pref("sansFlash", True); x.m_SetAttribute("Eclair", horloge()); image(0.1)
verifier("G-31. « Aucun flash » : pas d'éclair", not eclairs())
pref("sansFlash", False); pref("effetsReduits", True); actifs.set_parent(None); x.m_SetAttribute("Eclair", horloge() + 0.01); image(0.05)
imp = [p for p in eclairs() if p.props.get("Transparency") == 1]
verifier("G-31. Effets réduits : moins d'étincelles (15) ; sans son Tonnerre, l'éclair marche quand même",
         imp and [c_.emis for c_ in imp[0].enfants if c_.ClassName == "ParticleEmitter"] == [15] and not imp[0].m_FindFirstChild("Tonnerre"), imp)
pref("effetsReduits", False); image(0.5, 14)
verifier("Decor (éclair) : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])


# ================================================================== 3. TardisSystemes : orage
from banc import place, demarrer_serveur
P = place()
P["ws"].extra["GetPartBoundsInRadius"] = Fonction("GetPartBoundsInRadius", py=lambda *a: Table({}))
_, err = demarrer_serveur(P, duree=20)
verifier("TardisServeur et TardisSystemes démarrent (banc d'essai)", not err, err[:3])
ext, wsP = P["ext"], P["ws"]
RC = {}
tache(lambda: RC.update(c=premier(appeler(P["G"]["require"], [P["rs"].m_FindFirstChild("TardisConfig")]))))
SAs = RC["c"].get("Saisons")
ext.m_SetAttribute("Etat", "Pose"); ext.m_SetAttribute("Eclair", None)
H.avancer(35)
verifier("G-31. Pas d'orage : pas d'éclair", ext.m_GetAttribute("Eclair") is None)
SAs.set("ChanceEclair", 1); wsP.m_SetAttribute("Orage", True); H.avancer(10.5)
q = ext.m_GetAttribute("Eclair")
verifier("G-31. Orage (workspace « Orage ») et chance 1 : l'éclair frappe dans les 10 s (heure serveur)", isinstance(q, (int, float)) and abs(q - (1000 + H.t)) <= 10.5, q)
ext.m_SetAttribute("Eclair", None); ext.m_SetAttribute("Camouflage", True); H.avancer(30)
verifier("G-31. Cabine camouflée : pas d'éclair", ext.m_GetAttribute("Eclair") is None)
ext.m_SetAttribute("Camouflage", None); ext.m_SetAttribute("Etat", "Vol"); H.avancer(30)
verifier("G-31. En vol : pas d'éclair", ext.m_GetAttribute("Eclair") is None)
ext.m_SetAttribute("Etat", "Pose"); ext.m_SetAttribute("VolLibre", True); H.avancer(30)
verifier("G-31. En vol libre : pas d'éclair", ext.m_GetAttribute("Eclair") is None)
ext.m_SetAttribute("VolLibre", None); SAs.set("ChanceEclair", 0); H.avancer(30)
verifier("G-31. ChanceEclair = 0 : jamais", ext.m_GetAttribute("Eclair") is None)
SAs.set("ChanceEclair", 0.15)
ext.m_SetAttribute("Salete", 50); wsP.m_SetAttribute("Pluie", None); H.avancer(60)
verifier("L'orage compte comme pluie : la saleté baisse de 3 % par minute", ext.m_GetAttribute("Salete") == 47, ext.m_GetAttribute("Salete"))
wsP.m_SetAttribute("Orage", None); ext.m_SetAttribute("Salete", 50); H.avancer(60)
verifier("Après l'orage, au sec : la saleté ne bouge plus", ext.m_GetAttribute("Salete") == 50, ext.m_GetAttribute("Salete"))
verifier("TardisSystemes : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])


# ================================================================== 4. Le code
ext_src = lire("ServerScriptService/TardisExtras.server.lua")
verifier("TardisExtras : la tablette peut choisir Auto ou une des six décorations (table Config.Decorations)",
         'if nom == "Auto" or (type(nom) == "string" and table.find(Config.Decorations or {}, nom)) then' in ext_src)
verifier("TardisExtras : Auto efface l'attribut (la date choisit), « Aucune » est gardée",
         'exterieur:SetAttribute("Decoration", nom ~= "Auto" and nom or nil)' in ext_src)
verifier("TardisExtras : le message donne le nom lisible (Noël, Pâques…)", "(Config.NomsDecorations or {})[nom] or nom" in ext_src)
verifier("TardisExtras : une décoration sauvée inconnue n'est pas remise", "if type(reglages.decoration) == \"string\" and table.find(Config.Decorations or {}, reglages.decoration) then" in ext_src)
out = lire("StarterPlayer/StarterPlayerScripts/TardisTablette/Outils.lua")
bloc_out = out[out.index("local rangeeDeco"):out.index("local rangeeDeco") + 1500]
choix = re.findall(r'\{ "(\w+)", "[^"]+" \}', bloc_out)
verifier("Tablette : 7 boutons (Auto, Aucune, Noël, Halloween, Pâques, Nouvel An, anniversaire) sur une grille",
         choix[:7] == ["Auto", "Aucune", "Noel", "Halloween", "Paques", "NouvelAn", "Anniversaire"] and "UIGridLayout" in bloc_out, choix)
verifier("Tablette : sans attribut, c'est « Auto » qui est allumé", '(exterieur:GetAttribute("Decoration") or "Auto") == info[1]' in bloc_out)
verifier("init : Decor reçoit UI, la salle, sa boîte et ReplicatedStorage",
         all(k in init for k in ("ReplicatedStorage = ReplicatedStorage, RunService = RunService, UI = UI, boiteInt = boiteInt", "interieur = interieur, lampe = lampe")))
sysrc = lire("ServerScriptService/TardisSystemes.server.lua")
verifier("TardisSystemes : l'éclair n'est qu'un attribut (aucun dégât, aucune action réseau)", "SetAttribute(\"Eclair\", workspace:GetServerTimeNow())" in sysrc and decor_src.count("FireServer") == 0)
verifier("Decor : neige, feuilles et éclair n'existent que chez le joueur (partTemporaire)", decor_src.count("Instance.new") == 0)

print("\n".join("  ✓ " + n for n in OK))
print("\n".join("  ✗ " + n for n in KO))
print(f"SAISONS ET MÉTÉO (V7.2.4) : {len(OK)}/{len(OK) + len(KO)} vérifications réussies")
sys.exit(1 if KO else 0)
