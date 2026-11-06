"""Simulations de la V6.9.10.2 (nouvelle hiérarchie de l'intérieur) : le vrai code, avec la place du propriétaire
réorganisée comme dans Studio : INTERIEURE est un dossier qui contient directement Portail, Rotor (Model), Console,
Controls, PortesInterieures, Chameleon, Cloak, Door, Screen, et deux SpawnLocations « Spawn C.A.T » et « Spawn C.T.A.T ».
  1. Config.modeles : le dossier INTERIEURE devient la salle quand il contient directement le Portail ou le Rotor
     (même si un autre Model, « Chameleon », est trouvé avant) ; l'ancienne organisation (un seul Model) marche encore.
  2. Config.boite / Config.pivot / Config.partPrincipale : sur un dossier (boîte calculée sur ses pièces, gardée en
     mémoire), sur un Model et sur une pièce.
  3. Spawns (vrai TardisSystemes) : les SpawnLocations posés dans Studio sont réutilisés (équipe, couleur, pas de
     changement d'équipe au toucher), aucun « TardisSpawn_ » créé ; sans eux, création comme avant ; rattrapage du vide.
  4. Portail (vrai TardisPortail, chargé jusqu'aux fenêtres) : il trouve le Portail et le Rotor du dossier, sans attente sans fin.
  5. Plus aucun appel réservé aux Models sur l'intérieur dans le code."""
import os, sys, re
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
R = {}

def part(nom, parent, pos=(0, 0, 0), taille=(2, 2, 2), classe="Part"):
    p = Instance(classe, nom, parent)
    p.props.update({"CFrame": CF(pos), "Size": Vec3(*taille), "Position": Vec3(*pos)})
    return p

def place(nouveau_format=True, spawns=True):
    """La place du propriétaire : Workspace › TARDIS › TARDIS_1 › EXTERIEURE / INTERIEURE."""
    vider_cache(); roblox.ERREURS.clear()
    I, G, game, joueur = monde(serveur=True)
    activer_maths(G)
    ws = game.m_FindFirstChild("Workspace")
    t1 = Instance("Folder", "TARDIS_1", Instance("Folder", "TARDIS", ws))
    ext = Instance("Model", "TARDIS_1", Instance("Folder", "EXTERIEURE", t1))
    racine = part("Racine", ext); ext.props["PrimaryPart"] = racine
    dossierInt = Instance("Folder", "INTERIEURE", t1)
    salle = dossierInt if nouveau_format else Instance("Model", "Salle", dossierInt)
    Instance("Model", "Chameleon", salle); Instance("Model", "Cloak", salle)
    Instance("Folder", "PortesInterieures", salle)
    Instance("Script", "Default Mainscript", salle).props["Enabled"] = False
    Instance("Model", "Console", salle); Instance("Model", "Controls", salle); Instance("Model", "Door", salle)
    rotor = Instance("Model", "Rotor", salle); part("Colonne", rotor, (0, 5, 0), (2, 10, 2))
    portail = part("Portail", salle, (0, 4, 20), (6, 8, 1))
    part("Sol", salle, (0, -1, 0), (40, 2, 40))
    Instance("Model", "Screen", salle)
    if spawns:
        part("Spawn C.A.T", salle, (5, 0, 10), (6, 1, 6), "SpawnLocation")
        part("Spawn C.T.A.T", salle, (-5, 0, 10), (6, 1, 6), "SpawnLocation")
    Instance("Folder", "TARDIS_DESTINATIONS", t1.parent)
    rs = game.m_FindFirstChild("ReplicatedStorage")
    tache(lambda: R.update(Config=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisConfig")]))))
    return I, G, game, joueur, ws, t1, ext, dossierInt, salle, rotor, portail

# ================================================================== 1. Config.modeles
I, G, game, joueur, ws, t1, ext, dossierInt, salle, rotor, portail = place()
Config = R["Config"]
verifier("Version 6.9.10.2 ou plus récente", tuple(int(p) for p in str(Config.get("Version")).split(".") if p.isdigit()) >= (6, 9, 10, 2), Config.get("Version"))
def_1 = Config.get("Tardis").get(1)
tache(lambda: R.update(m=appeler(Config.get("modeles"), [def_1])))
verifier("1. Nouveau format : l'extérieur est le Model de EXTERIEURE", R["m"][0] is ext)
verifier("1. Nouveau format : la salle est le dossier INTERIEURE (pas « Chameleon », le premier Model)", R["m"][1] is dossierInt, R["m"][1])
I2, G2, game2, _, _, _, ext2, dossierInt2, salle2, _, _ = place(nouveau_format=False)
tache(lambda: R.update(m2=appeler(R["Config"].get("modeles"), [R["Config"].get("Tardis").get(1)])))
verifier("1. Ancien format (un Model « Salle » dans INTERIEURE) : toujours ce Model", R["m2"][1] is salle2, R["m2"][1])
# Rotor seul (pas encore de Portail) : le dossier est quand même la salle
I3, G3, game3, _, _, _, _, dossierInt3, _, _, portail3 = place()
portail3.m_Destroy()
tache(lambda: R.update(m3=appeler(R["Config"].get("modeles"), [R["Config"].get("Tardis").get(1)])))
verifier("1. Dossier avec le Rotor seul : le dossier est la salle", R["m3"][1] is dossierInt3, R["m3"][1])

# ================================================================== 2. Boîte, repère et pièce principale
I, G, game, joueur, ws, t1, ext, dossierInt, salle, rotor, portail = place()
Config = R["Config"]
f = lambda nom, *a: appeler(Config.get(nom), list(a))
tache(lambda: R.update(b=f("boite", dossierInt), p=f("pivot", dossierInt), pp=f("partPrincipale", dossierInt), bm=f("boite", rotor), bp=f("boite", portail)))
cf, taille = R["b"][0], R["b"][1]
# Pièces : sol 40×2×40 en (0,-1,0) → y de -2 à 0, x/z de -20 à 20 ; colonne y 0→10 ; portail z 19,5→20,5, y 0→8 ; spawns y -0,5→0,5
verifier("2. Boîte du dossier : de (−20, −2, −20) à (20, 10, 20,5), soit 40 × 12 × 40,5", tuple(round(v, 2) for v in taille.t()) == (40, 12, 40.5), taille.t())
verifier("2. Centre de la boîte du dossier : (0, 4, 0,25)", tuple(round(v, 2) for v in cf.p) == (0, 4, 0.25), cf)
verifier("2. Repère du dossier = centre de sa boîte", premier(R["p"]).p == cf.p)
verifier("2. Pièce principale du dossier : le Portail", premier(R["pp"]) is portail, premier(R["pp"]))
verifier("2. Boîte d'un Model : GetBoundingBox (mock 10 × 10 × 10)", list(R["bm"][1].args) == [10, 10, 10], R["bm"][1])
verifier("2. Boîte d'une pièce : sa CFrame et sa taille", R["bp"][0] is portail.props["CFrame"] and tuple(R["bp"][1].t()) == (6, 8, 1))
part("Ajout", dossierInt, (100, 0, 0))
tache(lambda: R.update(b2=f("boite", dossierInt)))
verifier("2. Boîte du dossier gardée en mémoire (calculée une seule fois)", tuple(R["b2"][1].t()) == tuple(taille.t()))
verifier("Config : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])

# ================================================================== 3. Spawns : vrai TardisSystemes
sysrc = lire("ServerScriptService/TardisSystemes.server.lua")
d = sysrc.index("local spawnsEquipes = {}"); fin = sysrc.index("-- Main qui repousse")
d2 = sysrc.index("local function pointDeSecours("); fin2 = sysrc.index("local function surveillerPersonnage")
d0 = sysrc.index("local function solSous(") if "local function solSous(" in sysrc else d2
prelude = """
local interieur, Config, def = ...
local positionsSures, derniersRattrapages = {}, {}
local function solSous() return false end
"""
def spawns(nouveau_format=True, avec_spawns=True, equipes=True):
    I, G, game, joueur, ws, t1, ext, dossierInt, salle, rotor, portail = place(nouveau_format, avec_spawns)
    Config = R["Config"]
    teams = game.m_FindFirstChild("Teams")
    if equipes:
        for nom, coul in (("C.A.T.", "Bright blue"), ("C.T.A.T.", "Deep orange")):
            e = Instance("Team", nom, teams); e.props["TeamColor"] = Valeur("BrickColor", [coul])
    code = prelude + sysrc[d:fin] + sysrc[d2:fin2] + "\nreturn pointDeSecours"
    tache(lambda: R.update(ps=premier(I.executer(code, "spawns", (salle, Config, Config.get("Tardis").get(1))))))
    H.avancer(1)
    return game, salle, teams
game, salle, teams = spawns()
crees = [e.Name for e in salle.enfants if e.Name.startswith("TardisSpawn_")]
verifier("3. Spawns de Studio réutilisés : aucun « TardisSpawn_ » créé", crees == [], crees)
cat, ctat = salle.m_FindFirstChild("Spawn C.A.T"), salle.m_FindFirstChild("Spawn C.T.A.T")
verifier("3. « Spawn C.A.T » : équipe C.A.T. (couleur, pas neutre, pas de changement d'équipe au toucher)",
         cat.attrs.get("TardisEquipe") == "C.A.T." and cat.props.get("Neutral") is False and cat.props.get("AllowTeamChangeOnTouch") is False
         and cat.props.get("TeamColor") is teams.m_FindFirstChild("C.A.T.").props["TeamColor"], (cat.attrs, cat.props.get("Neutral")))
verifier("3. « Spawn C.T.A.T » : équipe C.T.A.T. (et pas confondu avec la C.A.T.)",
         ctat.attrs.get("TardisEquipe") == "C.T.A.T." and ctat.props.get("TeamColor") is teams.m_FindFirstChild("C.T.A.T.").props["TeamColor"], ctat.attrs)
verifier("3. Les spawns gardent leur place (non déplacés)", cat.props["CFrame"].p == (5, 0, 10))
pilote = Instance("Player", "P", game.m_FindFirstChild("Players")); pilote.props["UserId"] = 7
tache(lambda: R.update(sec=premier(appeler(R["ps"], [pilote, Instance("Model", "Perso")]))))
verifier("3. Rattrapage du vide : au-dessus de « Spawn C.A.T »", isinstance(R["sec"], CF) and R["sec"].p == (5, 3, 10), R["sec"])
game, salle, teams = spawns(avec_spawns=False)
crees = sorted(e.Name for e in salle.enfants if e.Name.startswith("TardisSpawn_"))
verifier("3. Sans spawn dans Studio : créés comme avant (un par équipe)", crees == ["TardisSpawn_TARDIS_1_C.A.T.", "TardisSpawn_TARDIS_1_C.T.A.T."], crees)
game, salle, teams = spawns(nouveau_format=False)
verifier("3. Ancien format avec spawns de Studio : réutilisés aussi", not [e for e in salle.enfants if e.Name.startswith("TardisSpawn_")]
         and salle.m_FindFirstChild("Spawn C.A.T").attrs.get("TardisEquipe") == "C.A.T.")
verifier("Spawns : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])

# ================================================================== 4. Portail : vrai TardisPortail
I, G, game, joueur, ws, t1, ext, dossierInt, salle, rotor, portail = place()
part("Portail", ext, (0, 4, 2), (4, 8, 1))
Instance("Model", "TARDISDoors", ext)
camera = Instance("Camera", "Camera", ws); camera.props["CFrame"] = Valeur("CFrame"); ws.props["CurrentCamera"] = camera
ws.props["Terrain"] = Instance("Terrain", "Terrain")
Instance("PlayerGui", "PlayerGui", joueur)
game.extra["serveur"] = False
G["script"] = Instance("LocalScript", "TardisPortail", game.m_FindFirstChild("StarterPlayer"))
src = lire("StarterPlayer/StarterPlayerScripts/TardisPortail.client.lua")
tache(lambda: I.executer(src, "TardisPortail"))
H.avancer(2)
erreurs = [e for e in roblox.ERREURS if "WaitForChild" in str(e) or "Portail" in str(e) or "Rotor" in str(e)]
def descendants(o):
    res = []
    def visite(x):
        for e in x.enfants: res.append(e); visite(e)
    visite(o); return res
fenetres = [o for o in descendants(ws) + descendants(joueur) + descendants(portail) if str(o.Name).startswith("TardisVue")]
verifier("4. TardisPortail trouve Portail et Rotor dans le dossier : aucune attente sans fin ni erreur dessus", not erreurs, erreurs[:3])
verifier("4. Fenêtres du portail créées (TardisVueExterieur / TardisVueInterieur)", len(fenetres) >= 1, ([f.Name for f in fenetres][:2], roblox.ERREURS[:2]))

# ================================================================== 5. Analyse du code
src_tout = []
for racine, _, fichiers in os.walk(DEPOT):
    for n in fichiers:
        if n.endswith(".lua"): src_tout.append((n, open(os.path.join(racine, n), encoding="utf-8").read()))
restes = [(n, m.group(0)) for n, s in src_tout for m in re.finditer(r"\binterieur(:GetPivot\(\)|:GetBoundingBox\(\)|\.PrimaryPart|:PivotTo\(|:ScaleTo\()", s)]
verifier("5. Plus aucun GetPivot / GetBoundingBox / PrimaryPart / PivotTo direct sur l'intérieur", not restes, restes[:5])

print("\n".join("  ✓ " + o for o in OK)); print("\n".join("  ✗ " + k for k in KO))
print(f"V6.9.10.2 : {len(OK)}/{len(OK) + len(KO)} vérifications réussies")
sys.exit(1 if KO else 0)
