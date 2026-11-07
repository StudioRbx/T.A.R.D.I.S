"""Simulations de la V7.3.4 (console : commandes qui bougent) : le vrai code, avec de faux objets Roblox.
  1. TardisConfig : levier de vol baissé (G-101), position voulue d'un levier du kit (G-103, G-104), lampes du verrou (G-103),
     clignotement du refus (G-107), bascule autour d'un pivot (G-101, G-105).
  2. TardisServeur (le vrai Script serveur, banc d'essai) : invites avec « TardisCible », compteur « TardisRefus » (G-107),
     leviers du kit d'accord avec l'état changé ailleurs (G-103, G-104), lampes du verrou, étincelles à la coupure,
     interrupteur d'alerte (G-105), levier de vol (G-101).
  3. Console (module client) : contour cyan sur la commande visée (G-108), clignotement rouge au refus (G-107).
  4. Le code."""
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
    res = []
    def visite(x):
        for e in x.enfants: res.append(e); visite(e)
    visite(o); return res
def declencher(objet, signal, *args): objet.extra.setdefault(signal, Signal(signal)).declencher(*args)
def mat(m): return getattr(m, "nom", str(m))
def rgb(c): return c.rgb255() if hasattr(c, "rgb255") else None
def proche(a, b, eps=1e-4):
    return all(abs(x - y) < eps for x, y in zip(a.p, b.p)) and all(abs(x - y) < eps for la, lb in zip(a.R, b.R) for x, y in zip(la, lb))

# ================================================================== 1. TardisConfig
vider_cache()
I, G, game, joueur = monde(serveur=False)
activer_maths(G)
rs = game.m_FindFirstChild("ReplicatedStorage")
R = {}
tache(lambda: R.update(Config=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisConfig")]))))
Config = R["Config"]
E = Config.get("Etats")
CC = Config.get("CommandesConsole")
f = lambda nom, *a: premier(appeler(Config.get(nom), list(a)))
verifier("Config.Version ≥ 7.3.4 (7.3.4 à sa sortie)", tuple(int(n) for n in Config.get("Version").split(".")) >= (7, 3, 4), Config.get("Version"))
verifier("Config.CommandesConsole : contour, refus, leviers, lampes, étincelles, interrupteur et levier de vol actifs",
         all(CC.get(k) is True for k in ("ContourVise", "ClignoteRefus", "LeviersSuivent", "LampeVerrou", "EtincellesCoupure", "InterrupteurAlerte", "LevierVol")))
verifier("Config.CommandesConsole : 34° pour l'interrupteur, 35° pour le levier de vol, bascule en 0,4 s",
         (CC.get("AngleInterrupteur"), CC.get("AngleLevierVol"), CC.get("DureeBascule")) == (34, 35, 0.4))
verifier("Config.CommandesConsole.Interrupteur : Console › Circuit › Cloister › Switch",
         [CC.get("Interrupteur").get(i) for i in range(1, 5)] == ["Console", "Circuit", "Cloister", "Switch"])
verifier("Couleurs : contour cyan (0, 230, 255), refus rouge (255, 40, 40)", rgb(CC.get("CouleurContour")) == (0, 230, 255) and rgb(CC.get("CouleurRefus")) == (255, 40, 40))
etats = {n: E.get(n) for n in ("Pose", "Demat", "Vol", "Remat")}
verifier("G-101. levierVolBaisse : baissé en dématérialisation et en vol, levé posé et en rematérialisation",
         [f("levierVolBaisse", etats[n]) for n in ("Pose", "Demat", "Vol", "Remat")] == [False, True, True, False])
verifier("G-101. levierVolBaisse : état inconnu ou nil → levé", f("levierVolBaisse", "Autre") is False and f("levierVolBaisse", None) is False)
verifier("G-103. etatLevierKit : même état qu'au départ → la position du départ",
         (f("etatLevierKit", False, False, False), f("etatLevierKit", True, False, False), f("etatLevierKit", True, True, True)) == (False, True, True))
verifier("G-103. etatLevierKit : état inversé → la position inverse",
         (f("etatLevierKit", False, False, True), f("etatLevierKit", True, False, True), f("etatLevierKit", False, True, False)) == (True, False, True))
verifier("G-104. etatLevierKit : nil compte comme false", f("etatLevierKit", None, None, True) is True and f("etatLevierKit", None, None, None) is False)
verifier("G-103. couleurLampeVerrou : rouge verrouillé (255, 50, 40), vert ouvert (60, 255, 90)",
         rgb(f("couleurLampeVerrou", True)) == (255, 50, 40) and rgb(f("couleurLampeVerrou", False)) == (60, 255, 90))
verifier("G-107. clignotementRefus : allumé à 0 et 0,1 s, éteint à 0,2 s, rallumé à 0,35 s, éteint à 0,5 et 0,6 s",
         [f("clignotementRefus", t) for t in (0, 0.1, 0.2, 0.35, 0.5, 0.6)] == [True, True, False, True, False, False])
verifier("G-107. clignotementRefus : avant 0 et après 0,6 → éteint ; nil → allumé (début)",
         f("clignotementRefus", -1) is False and f("clignotementRefus", 3) is False and f("clignotementRefus", None) is True)
RC = {}
tache(lambda: RC.update(r=I.executer("""local Config = ...
local cf = CFrame.new(1, 2, 3) * CFrame.Angles(0.3, 0.2, 0.1)
local pivot = CFrame.new(1, 1.5, 3)
local a = Config.cframeBascule(cf, pivot, 35)
local b = Config.cframeBascule(a, pivot, -35)
local zero = Config.cframeBascule(cf, pivot, 0)
local surPivot = Config.cframeBascule(pivot, pivot, 90)
return (a.Position - cf.Position).Magnitude, (b.Position - cf.Position).Magnitude, (zero.Position - cf.Position).Magnitude,
	(surPivot.Position - pivot.Position).Magnitude, b.LookVector:Dot(cf.LookVector), (a.Position - pivot.Position).Magnitude""", "bascule", (Config,))))
r = list(RC["r"])
verifier("G-101. cframeBascule : la pièce bouge, et l'angle inverse la ramène pile au départ", r[0] > 0.1 and r[1] < 1e-6 and r[4] > 0.999999, r)
verifier("G-101. cframeBascule : angle 0 → rien ne bouge ; la distance au pivot est gardée ; le pivot reste en place sur lui-même",
         r[2] < 1e-6 and abs(r[5] - 0.5) < 1e-6 and r[3] < 1e-6, r)

# ================================================================== 2. TardisServeur (banc d'essai)
from banc import place, demarrer_serveur, part, valeur
P = place()
salle, ext, j = P["salle"], P["ext"], P["joueur"]
j.attrs["TardisAccesPilote"] = True
def chemin(*noms):
    o = salle
    for n in noms: o = o.m_FindFirstChild(n)
    return o
TIRS = {"Verrou": 0, "Alimentation": 0}
def kit(cle, modele):
    """Levier du kit : BoolValue LeverUp, BindableEvent TardisAnimer (qui bascule LeverUp, comme le script Move), lampes Bulb1 et Bulb2."""
    leve = valeur("BoolValue", "LeverUp", modele, False)
    ev = Instance("BindableEvent", "TardisAnimer", modele)
    def anime(*a):
        TIRS[cle] += 1; leve.props["Value"] = not leve.props["Value"]; return []
    ev.extra.setdefault("Event", Signal("TardisAnimer")).connecter(Fonction("Move", py=anime))
    for n in ("Bulb1", "Bulb2"):
        b = part(n, modele.parent, (0, 4, 0), (0.3, 0.3, 0.3)); b.props.update({"Color": Couleur(0.5, 0.5, 0.5), "Material": Valeur("Enum.Material.SmoothPlastic")})
    return leve
leveVerrou = kit("Verrou", chemin("Console", "LeverLeft", "Main", "Lever"))
leveAlim = kit("Alimentation", chemin("Controls", "LockLever", "Main", "Lever"))
circuit = Instance("Model", "Circuit", chemin("Console")); cloister = Instance("Model", "Cloister", circuit)
switch = part("Switch", cloister, (3, 3, 1), (0.2, 0.6, 0.2))  # UnionOperation dans DEVMAP (une BasePart ; le faux IsA ne le sait pas)
switch.props.update({"Color": Couleur(27 / 255, 42 / 255, 53 / 255), "Material": Valeur("Enum.Material.SmoothPlastic")})
bouton = chemin("Console", "Datapanel", "Redbutton", "Button")
bouton.props.update({"Color": Couleur(0.8, 0, 0), "Material": Valeur("Enum.Material.SmoothPlastic")})
levierVol = chemin("Controls", "Matlever", "Fly", "Levier")
levierVol.props["Size"] = Vec3(0.125, 0.62, 0.123)
cfLevier0 = levierVol.props["CFrame"]; cfSwitch0 = switch.props["CFrame"]
ext.attrs.update({"PortesVerrouillees": False, "Alimentation": True})
RP = {}
tache(lambda: RP.update(c=premier(appeler(P["G"]["require"], [P["rs"].m_FindFirstChild("TardisConfig")]))))
ids = RP["c"].get("Pilotes").get("UserIds"); ids.set(ids.longueur() + 1, j.props["UserId"])  # pilote de la config
_, err = demarrer_serveur(P, duree=20)
verifier("TardisServeur démarre avec les leviers du kit, l'interrupteur et le levier de vol (banc d'essai)", not err, err[:3])
MSG = []
canal = P["rs"].m_FindFirstChild("TardisCommande_TARDIS_1")
canal.extra["FireClient"] = Fonction("FireClient", py=lambda _s, qui, msg=None, *a: MSG.append(str(msg)))
canal.extra["FireAllClients"] = Fonction("FireAllClients", py=lambda _s, msg=None, *a: MSG.append(str(msg)))
invites = [e for e in descendants(P["t1"]) if e.ClassName == "ProximityPrompt"]
def invite(texte): return next((e for e in invites if e.props.get("ActionText") == texte), None)
pVerrou, pLevier, pSel = invite("Verrouiller les portes"), invite("Décoller"), invite("Changer de destination")
verifier("Les invites du levier, du sélecteur et du verrou existent", pVerrou is not None and pLevier is not None and pSel is not None, [e.props.get("ActionText") for e in invites])
cibles = [(e, e.m_FindFirstChild("TardisCible")) for e in invites if e.props.get("ObjectText") == "Console"]
verifier("G-107. Chaque invite de la console porte un ObjectValue « TardisCible » (la pièce de la commande)",
         cibles and all(c is not None and c.ClassName == "ObjectValue" and c.props.get("Value") is not None and c.props["Value"].ClassName in ("Part", "UnionOperation", "MeshPart") for _, c in cibles),
         [(e.props.get("ActionText"), c and c.props.get("Value")) for e, c in cibles])
verifier("G-107. … la cible du levier de vol est le levier, celle du verrou la pièce Main du levier",
         pLevier.m_FindFirstChild("TardisCible").props["Value"] is levierVol and pVerrou.m_FindFirstChild("TardisCible").props["Value"] is chemin("Console", "LeverLeft", "Main", "Lever", "Main"))
lampes = [chemin("Console", "LeverLeft", "Main", n) for n in ("Bulb1", "Bulb2")]
verifier("G-103. Au démarrage (portes ouvertes) : les lampes du verrou sont des néons verts",
         all(rgb(l.props["Color"]) == (60, 255, 90) and "Neon" in mat(l.props["Material"]) for l in lampes), [(rgb(l.props["Color"]), mat(l.props["Material"])) for l in lampes])
lampesAlim = [chemin("Controls", "LockLever", "Main", n) for n in ("Bulb1", "Bulb2")]
verifier("G-103. Les lampes du levier d'alimentation ne changent pas", all(rgb(l.props["Color"]) == (128, 128, 128) for l in lampesAlim))
# Verrou par l'invite : l'animation de la V6.9.16 (une fois), puis rien de plus (déjà d'accord)
declencher(pVerrou, "Triggered", j); H.avancer(1.5)
verifier("G-103. Verrou par l'invite : portes verrouillées, levier animé une seule fois (déjà dans la bonne position ensuite)",
         ext.attrs.get("PortesVerrouillees") is True and TIRS["Verrou"] == 1 and leveVerrou.props["Value"] is True, (ext.attrs.get("PortesVerrouillees"), TIRS, leveVerrou.props["Value"]))
verifier("G-103. Portes verrouillées : lampes en néon rouge", all(rgb(l.props["Color"]) == (255, 50, 40) and "Neon" in mat(l.props["Material"]) for l in lampes))
# le script Effects du kit éteint les lampes : elles se rallument
for l in lampes: l.props["Material"] = Valeur("Enum.Material.SmoothPlastic")
ext.m_SetAttribute("PortesVerrouillees", False); H.avancer(0.3)
for l in lampes: l.props["Material"] = Valeur("Enum.Material.SmoothPlastic")  # Effects, 0,2 s après
H.avancer(1.5)
verifier("G-103. Déverrouillé ailleurs (tablette, mode siège) : le levier du kit suit (une animation de plus)",
         TIRS["Verrou"] == 2 and leveVerrou.props["Value"] is False, (TIRS, leveVerrou.props["Value"]))
verifier("G-103. … et les lampes, éteintes par le script du kit, se rallument en vert", all(rgb(l.props["Color"]) == (60, 255, 90) and "Neon" in mat(l.props["Material"]) for l in lampes),
         [(rgb(l.props["Color"]), mat(l.props["Material"])) for l in lampes])
ext.m_SetAttribute("PortesVerrouillees", True); H.avancer(0.2); ext.m_SetAttribute("PortesVerrouillees", False); H.avancer(1.5)
verifier("G-103. Aller-retour rapide (0,2 s) : le levier n'est pas animé (il est déjà dans la bonne position)", TIRS["Verrou"] == 2, TIRS)
# Alimentation : coupure ailleurs (surchauffe, panne)
part_alim = chemin("Controls", "LockLever", "Main", "Lever", "Main")
ext.m_SetAttribute("Alimentation", False); H.avancer(0.1)
gerbes = [e for e in part_alim.enfants if e.Name == "TardisEtincellesCoupure"]
emis = [g.emis for a in gerbes for g in a.enfants if g.ClassName == "ParticleEmitter"]
verifier("G-104. Coupure : une gerbe de 25 étincelles sur le levier d'alimentation", len(gerbes) == 1 and emis == [25], (len(gerbes), emis))
H.avancer(1)
verifier("G-104. Coupure : le levier du kit bascule", TIRS["Alimentation"] == 1 and leveAlim.props["Value"] is True, (TIRS, leveAlim.props["Value"]))
H.avancer(1)
verifier("G-104. La gerbe disparaît d'elle-même (1,5 s)", not [e for e in part_alim.enfants if e.Name == "TardisEtincellesCoupure"])
ext.m_SetAttribute("Alimentation", True); H.avancer(1)
verifier("G-104. Retour du courant : le levier revient, sans étincelles", TIRS["Alimentation"] == 2 and leveAlim.props["Value"] is False
         and not [e for e in part_alim.enfants if e.Name == "TardisEtincellesCoupure"], TIRS)
# Alerte : interrupteur du Cloister et bouton rouge
ext.m_SetAttribute("Alerte", True); H.avancer(1)
verifier("G-105. Alerte : l'interrupteur et le bouton d'alerte deviennent des néons rouges",
         all("Neon" in mat(p.props["Material"]) and rgb(p.props["Color"]) == (255, 30, 30) for p in (switch, bouton)), [(mat(p.props["Material"]), rgb(p.props["Color"])) for p in (switch, bouton)])
cfSwitch1 = switch.props["CFrame"]
verifier("G-105. Alerte : l'interrupteur bascule (sur place, il tourne)", not proche(cfSwitch1, cfSwitch0) and all(abs(a - b) < 1e-6 for a, b in zip(cfSwitch1.p, cfSwitch0.p)), (cfSwitch1.p, cfSwitch0.p))
ext.m_SetAttribute("Alerte", False); H.avancer(1)
verifier("G-105. Fin de l'alerte : couleurs et matières d'origine", rgb(switch.props["Color"]) == (27, 42, 53) and "SmoothPlastic" in mat(switch.props["Material"])
         and rgb(bouton.props["Color"]) == (204, 0, 0) and "SmoothPlastic" in mat(bouton.props["Material"]))
verifier("G-105. Fin de l'alerte : l'interrupteur revient pile à sa position", proche(switch.props["CFrame"], cfSwitch0), switch.props["CFrame"].p)
# Levier de vol
ext.m_SetAttribute("Etat", "Demat"); H.avancer(1)
cfL1 = levierVol.props["CFrame"]
verifier("G-101. Décollage (dématérialisation) : le levier de vol s'abaisse", not proche(cfL1, cfLevier0), cfL1.p)
ext.m_SetAttribute("Etat", "Vol"); H.avancer(1)
verifier("G-101. En vol : il reste baissé", proche(levierVol.props["CFrame"], cfL1))
ext.m_SetAttribute("Etat", "Remat"); H.avancer(1)
verifier("G-101. Atterrissage : il remonte pile à sa position", proche(levierVol.props["CFrame"], cfLevier0), levierVol.props["CFrame"].p)
ext.m_SetAttribute("Etat", "Demat"); H.avancer(0.1); ext.m_SetAttribute("Etat", "Pose"); H.avancer(1)
verifier("G-101. Aller-retour rapide (0,1 s) : il revient quand même pile au départ", proche(levierVol.props["CFrame"], cfLevier0), levierVol.props["CFrame"].p)
# Refus (G-107) : PATIENTEZ, EN MAINTENANCE
avant = pLevier.attrs.get("TardisRefus") or 0
ext.m_SetAttribute("Etat", "Demat"); H.avancer(3)
declencher(pLevier, "Triggered", j); H.avancer(0.2)
verifier("G-107. Levier pendant la dématérialisation : « PATIENTEZ » et le compteur TardisRefus de l'invite augmente",
         (pLevier.attrs.get("TardisRefus") or 0) == avant + 1, (avant, pLevier.attrs.get("TardisRefus"), MSG[-3:]))
ext.m_SetAttribute("Etat", "Pose"); H.avancer(4)
ext.m_SetAttribute("Maintenance", "Révision")
bloquees = (RP["c"].get("Maintenance") or Table({})).get("Bloquees")
if bloquees is not None: bloquees.set("Demat", True)
declencher(pLevier, "Triggered", j); H.avancer(0.2)
verifier("G-107. Levier en maintenance : refus compté (EN MAINTENANCE)", (pLevier.attrs.get("TardisRefus") or 0) == avant + 2, (pLevier.attrs.get("TardisRefus"), MSG[-3:]))
ext.m_SetAttribute("Maintenance", None)
verifier("Une invite acceptée ne compte pas de refus (le verrou)", not pVerrou.attrs.get("TardisRefus"), pVerrou.attrs.get("TardisRefus"))
verifier("TardisServeur : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])

# Sans leviers du kit, sans interrupteur ni lampes : rien ne casse
P2 = place()
_, err2 = demarrer_serveur(P2, duree=10)
P2["ext"].m_SetAttribute("PortesVerrouillees", True); P2["ext"].m_SetAttribute("Alerte", True); P2["ext"].m_SetAttribute("Etat", "Demat"); H.avancer(2)
P2["ext"].m_SetAttribute("Alimentation", False); H.avancer(2)
verifier("Place sans leviers du kit ni interrupteur : aucune erreur (verrou, alerte, décollage, coupure)", not err2 and not roblox.ERREURS, (err2 + list(roblox.ERREURS))[:3])

# ================================================================== 3. Console (client)
CONSOLE = "StarterPlayer/StarterPlayerScripts/TardisExtrasClient/"
vider_cache(); roblox.ERREURS.clear()
I, G, game, joueur = monde(serveur=False)
activer_maths(G)
rs = game.m_FindFirstChild("ReplicatedStorage"); ws = game.m_FindFirstChild("Workspace")
pps = Instance("ProximityPromptService", "ProximityPromptService", game)
for n in ("PromptShown", "PromptHidden"): pps.extra[n] = Signal(n)
remote = Instance("RemoteEvent", "TardisCommande_TARDIS_1", rs)
R = {}
tache(lambda: R.update(Config=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisConfig")])), UI=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisUI")]))))
Config, UI = R["Config"], R["UI"]
Instance("PlayerGui", "PlayerGui", joueur)
uis = game.m_FindFirstChild("UserInputService"); uis.extra["InputBegan"] = Signal("InputBegan")
camera = Instance("Camera", "Camera", ws)
camera.props.update({"CFrame": CF((0, 10, 14)), "CameraType": Valeur("Enum.CameraType.Custom"), "ViewportSize": Valeur("Vector2", [1920, 1080]), "CameraSubject": None})
ws.props["CurrentCamera"] = camera
cab = Instance("Model", "Cabine"); cab.attrs.update({"Etat": "Pose", "Alimentation": True, "Alerte": False})
salle = Instance("Model", "Salle", ws)
consoleM = Instance("Model", "Console", salle)
petit = Instance("Model", "Lever", consoleM)
pieceLevier = part("Main", petit, (0, 3, 0), (0.3, 1, 0.3)); part("Bout", petit, (0, 3.5, 0), (0.3, 0.3, 0.3))
seule = part("Selecteur", consoleM, (2, 3, 0), (1, 0.3, 1))
grand = Instance("Model", "Panneau", consoleM)
piecesGrand = [part("P" + str(i), grand, (i, 2, 3), (0.5, 0.5, 0.5)) for i in range(15)]
dehors = part("Dehors", ws, (50, 3, 0), (1, 1, 1))
def creer_invite(cible, nom="Invite"):
    p = Instance("ProximityPrompt", nom, cible)
    v = Instance("ObjectValue", "TardisCible", p); v.props["Value"] = cible
    return p
iLevier, iSeule, iGrand, iDehors = creer_invite(pieceLevier), creer_invite(seule), creer_invite(piecesGrand[0]), creer_invite(dehors)
iSans = Instance("ProximityPrompt", "SansCible", seule)
racine = part("HumanoidRootPart", Instance("Model", "Corps"), (0, 3, 2), (2, 2, 1))
ctx = Table({"C": UI.get("C"), "Config": Config, "E": Config.get("Etats"), "Players": game.m_FindFirstChild("Players"), "UI": UI,
             "UserInputService": uis, "animer": UI.get("animer"), "camera": camera, "creer": UI.get("creer"), "texte": UI.get("texte"),
             "def": Config.get("Tardis").get(1), "exterieur": cab, "interieur": salle, "joueur": joueur,
             "maRacine": Fonction("maRacine", py=lambda: racine), "remote": remote, "jeSuisDedans": Fonction("dedans", py=lambda: True)})
tache(lambda: appeler(premier(I.executer(lire(CONSOLE + "Console.lua"), "Console")), [ctx]))
H.avancer(0.05)
verifier("Console se charge chez un joueur (avec ProximityPromptService)", not roblox.ERREURS, roblox.ERREURS[:3])
def montrer(p): declencher(pps, "PromptShown", p, Valeur("Enum.ProximityPromptInputType.Keyboard")); H.avancer(0.01)
def cacher(p): declencher(pps, "PromptHidden", p); H.avancer(0.01)
def contours(): return [e for e in descendants(salle) if e.ClassName == "Highlight" and e.Name == "TardisContourCommande"]
def refus(): return [e for e in descendants(salle) if e.ClassName == "Highlight" and e.Name == "TardisRefusCommande"]
montrer(iLevier)
c = contours()
verifier("G-108. Invite affichée sur une petite commande (Model de 2 pièces) : contour cyan sur le Model entier",
         len(c) == 1 and c[0].parent is petit and c[0].props.get("Adornee") is petit and rgb(c[0].props.get("OutlineColor")) == (0, 230, 255)
         and c[0].props.get("FillTransparency") == 1 and c[0].props.get("OutlineTransparency") == 0, [(e.parent.Name, e.props.get("Adornee")) for e in c])
montrer(iSeule)
c = contours()
verifier("G-108. Une autre invite : un seul contour, sur la nouvelle commande (pièce rangée directement dans la console)", len(c) == 1 and c[0].parent is seule, [e.parent.Name for e in c])
cacher(iLevier)
verifier("G-108. L'ancienne invite cachée : le contour de la nouvelle reste", len(contours()) == 1)
cacher(iSeule)
verifier("G-108. Invite cachée : plus de contour", not contours())
montrer(iGrand)
c = contours()
verifier("G-108. Commande dans un grand Model (15 pièces) : le contour sur la pièce seule", len(c) == 1 and c[0].parent is piecesGrand[0], [e.parent.Name for e in c])
cacher(iGrand)
montrer(iDehors); montrer(iSans)
verifier("G-108. Invite hors de l'intérieur, ou sans TardisCible : pas de contour", not contours())
montrer(iLevier)
iLevier.m_SetAttribute("TardisRefus", 1); H.avancer(0.01)
rf = refus()
verifier("G-107. Refus du serveur : la commande clignote en rouge (Highlight rempli à 35 %)",
         len(rf) == 1 and rf[0].parent is petit and rgb(rf[0].props.get("FillColor")) == (255, 40, 40) and rf[0].props.get("FillTransparency") == 0.35, [e.parent.Name for e in rf])
H.avancer(0.2)
verifier("G-107. … éteint à 0,2 s", rf and rf[0].props.get("Enabled") is False, rf and rf[0].props.get("Enabled"))
H.avancer(0.15)
verifier("G-107. … rallumé à 0,35 s", rf and rf[0].props.get("Enabled") is True, rf and rf[0].props.get("Enabled"))
H.avancer(0.35)
verifier("G-107. … et retiré à 0,7 s ; le contour cyan est toujours là", not refus() and len(contours()) == 1)
cacher(iLevier)
iLevier.m_SetAttribute("TardisRefus", 2); H.avancer(0.01)
verifier("G-107. Un refus quand l'invite n'est plus affichée clignote quand même (le joueur vient d'appuyer)", len(refus()) == 1)
iLevier.m_SetAttribute("TardisRefus", 3); H.avancer(0.01)
verifier("G-107. Deux refus d'affilée : un seul clignotement à la fois", len(refus()) == 1)
H.avancer(1)
verifier("G-107. … retiré ensuite", not refus())
Config.get("CommandesConsole").set("ContourVise", False)
montrer(iSeule)
verifier("ContourVise = false : pas de contour", not contours())
verifier("Console : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])

# ================================================================== 4. Le code
cfg = lire("ReplicatedStorage/TardisConfig.lua")
serv = lire("ServerScriptService/TardisServeur/init.server.lua")
cons = lire(CONSOLE + "Console.lua")
verifier("TardisConfig se termine toujours par « return Config »", cfg.rstrip().endswith("return Config"))
verifier("Serveur : chaque refus de commande passe par refuser() (alerter() reste pour les messages acceptés)",
         'refuser(promptLevier, "PATIENTEZ")' in serv and 'refuser(promptLevier, "EN MAINTENANCE")' in serv and 'refuser(promptVerrou, erreur)' in serv
         and 'refuser(prompt, erreur)' in serv and serv.count("refuser(") >= 8, serv.count("refuser("))
verifier("Serveur : aucune nouvelle boucle Heartbeat ni RenderStepped", serv.count("Heartbeat:Connect") == lire("ServerScriptService/TardisServeur/init.server.lua").count("Heartbeat:Connect")
         and "RenderStepped" not in serv[serv.index("(V7.3.4) Commandes de la console qui bougent"):serv.index("-- Rapetissement et ramassage")])
bloc = cons[cons.index("(V7.3.4, G-108)"):]
verifier("Console : pas de boucle par image ni d'envoi au serveur dans le nouveau bloc", "RenderStepped" not in bloc and "Heartbeat" not in bloc and "FireServer" not in bloc)
verifier("Console : ProximityPromptService pris dans un pcall (vieux clients et tests)", 'pcall(function() return game:GetService("ProximityPromptService") end)' in bloc)

print("\n".join("  ✓ " + n for n in OK))
print("\n".join("  ✗ " + n for n in KO))
print(f"CONSOLE : COMMANDES QUI BOUGENT (V7.3.4) : {len(OK)}/{len(OK) + len(KO)} vérifications réussies")
sys.exit(1 if KO else 0)
