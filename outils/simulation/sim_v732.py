"""Simulations de la V7.3.2 (salle : ambiance, jukebox et style) : le vrai code, avec de faux objets Roblox.
  1. TardisConfig : qui règle le jukebox (C-189), lumière de la musique (G-140), force et angle des câbles (G-163),
     délai de la vague (G-189).
  2. Ambiance (le module entier) : volume de la musique pour les LEDs (G-140), câbles du plafond (G-163).
  3. TardisEffets (le script entier) : les LedsAlerte battent avec la musique, pas en alerte (G-140).
  4. TardisExtras (le vrai Script serveur, banc d'essai) : jukebox de l'équipage à bord (C-189), style en vague (G-189).
  5. Le code."""
import os, sys, math, random
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
def piece(nom, parent, pos=(0, 0, 0), taille=(2, 2, 2), classe="Part"):
    p = Instance(classe, nom, parent)
    p.props.update({"CFrame": CF(pos), "Size": Vec3(*taille), "Position": Vec3(*pos)})
    return p
class PieceLiee(Instance):
    """Pièce d'un Model qui suit le pivot du Model."""
    def __init__(s, classe, nom, parent, modele, decalage):
        super().__init__(classe, nom, parent); s.modele, s.decalage = modele, decalage
    def __lua_index__(s, k):
        if k in ("CFrame", "Position"):
            pivot = s.modele.m_GetPivot()
            cf = pivot.fois(s.decalage) if isinstance(pivot, CF) else s.decalage
            return cf if k == "CFrame" else Vec3(*cf.p)
        return super().__lua_index__(k)
random.seed(732)

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
SA = Config.get("Salle")
f = lambda nom, *a: premier(appeler(Config.get(nom), list(a)))
fs = lambda nom, *a: list(appeler(Config.get(nom), list(a)))

verifier("Config.Version ≥ 7.3.2 (7.3.2 à sa sortie)", tuple(int(n) for n in Config.get("Version").split(".")) >= (7, 3, 2), Config.get("Version"))
verifier("Config.Salle : JukeboxEquipage, LumieresMusique et Cables actifs ; ForceMusique 0,6, VolumeMusique 300",
         SA.get("JukeboxEquipage") is True and SA.get("LumieresMusique") is True and SA.get("Cables") is True and SA.get("ForceMusique") == 0.6 and SA.get("VolumeMusique") == 300)
verifier("Config.Salle : 6 câbles de 4 studs, 8°, vague de 2 s", (SA.get("CordesLocales"), SA.get("LongueurCordes"), SA.get("AngleCables"), SA.get("DureeVague")) == (6, 4, 8, 2))
# peutJukebox
verifier("C-189. peutJukebox : le pilote toujours (à bord ou non)", f("peutJukebox", "pilote", False) is True and f("peutJukebox", "pilote", True) is True)
verifier("C-189. peutJukebox : copilote et technicien à bord → oui", f("peutJukebox", "copilote", True) is True and f("peutJukebox", "technicien", True) is True)
verifier("C-189. peutJukebox : copilote et technicien dehors → non", f("peutJukebox", "copilote", False) is False and f("peutJukebox", "technicien", False) is False)
verifier("C-189. peutJukebox : un visiteur, même à bord → non", f("peutJukebox", "visiteur", True) is False)
SA.set("JukeboxEquipage", False)
verifier("C-189. JukeboxEquipage = false : seuls les pilotes", f("peutJukebox", "copilote", True) is False and f("peutJukebox", "pilote", False) is True)
SA.set("JukeboxEquipage", True)
# lumiereMusique
verifier("G-140. lumiereMusique : pas de musique (nil) → nil (on ne touche à rien)", f("lumiereMusique", None) is None)
verifier("G-140. lumiereMusique : silence → 0,4 ; moitié (150) → 1 ; fort (300) → 1,6", (round(f("lumiereMusique", 0), 6), round(f("lumiereMusique", 150), 6), round(f("lumiereMusique", 300), 6)) == (0.4, 1, 1.6))
verifier("G-140. lumiereMusique : plus fort que VolumeMusique → plafonné à 1,6", round(f("lumiereMusique", 900), 6) == 1.6)
SA.set("LumieresMusique", False)
verifier("G-140. LumieresMusique = false → nil", f("lumiereMusique", 300) is None)
SA.set("LumieresMusique", True)
# forceCables
verifier("G-163. forceCables : posé et immobile → 0", f("forceCables", "Pose", False, False, 0) == 0)
verifier("G-163. forceCables : voyage sans stabilisateur → 1 ; en urgence → 2,5", f("forceCables", "Demat", False, False, 0) == 1 and f("forceCables", "Remat", True, False, 0) == 2.5)
verifier("G-163. forceCables : stabilisé → 0,3 ; mais l'urgence passe le stabilisateur (2,5)",
         abs(f("forceCables", "Demat", False, True, 0) - 0.3) < 1e-9 and f("forceCables", "Demat", True, True, 0) == 2.5)
verifier("G-163. forceCables : le choc d'atterrissage compte même posé (0,8)", f("forceCables", "Pose", False, False, 0.8) == 0.8)
verifier("G-163. forceCables : dans le vortex (Vol), les câbles pendent (0)", f("forceCables", "Vol", False, False, 0) == 0)
ax, az = fs("angleCable", 0.7, 1, 0.5)
verifier("G-163. angleCable : au plus 8° autour de X, 4,8° autour de Z, à force 1", abs(ax) <= math.radians(8) + 1e-9 and abs(az) <= math.radians(8) * 0.6 + 1e-9 and (ax != 0 or az != 0), (ax, az))
verifier("G-163. angleCable : force 0 → immobile", fs("angleCable", 3, 0, 1) == [0, 0])
verifier("G-163. angleCable : deux câbles de phases différentes ne bougent pas pareil", fs("angleCable", 2, 1, 0) != fs("angleCable", 2, 1, 1.3))
# delaiVague
verifier("G-189. delaiVague : au centre 0 ; au plus loin la durée (2) ; à mi-chemin 1", (f("delaiVague", 0, 30, 2), f("delaiVague", 30, 30, 2), f("delaiVague", 15, 30, 2)) == (0, 2, 1))
verifier("G-189. delaiVague : arrondi au dixième (7 sur 30 → 0,5)", f("delaiVague", 7, 30, 2) == 0.5, f("delaiVague", 7, 30, 2))
verifier("G-189. delaiVague : durée 0 ou salle sans taille → 0", f("delaiVague", 20, 30, 0) == 0 and f("delaiVague", 20, 0, 2) == 0)

# ================================================================== 2. Ambiance (client, module entier)
ws = game.m_FindFirstChild("Workspace")
RunService = game.m_FindFirstChild("RunService"); Lighting = game.m_FindFirstChild("Lighting")
camera = Instance("Camera", "Camera", ws); camera.props.update({"CFrame": CF((0, 60, 20)), "FieldOfView": 70, "ViewportSize": Valeur("Vector2", [1280, 720])})
ws.props["CurrentCamera"] = camera; ws.props["Terrain"] = Instance("Terrain", "Terrain")
ws.props["GlobalWind"] = Vec3(0, 0, 0)
ws.extra["Raycast"] = Fonction("Raycast", py=lambda *a: None)
Lighting.props.update({"ClockTime": 12, "ExposureCompensation": 0, "Ambient": Couleur(0.5, 0.5, 0.5), "OutdoorAmbient": Couleur(0.5, 0.5, 0.5)})
Instance("PlayerGui", "PlayerGui", joueur)
remote = Instance("RemoteEvent", "TardisCommande_TARDIS_1", rs)
t1 = Instance("Folder", "TARDIS_1", Instance("Folder", "TARDIS", ws))
x = Instance("Model", "Cabine", Instance("Folder", "EXTERIEURE", t1)); x.props.update({"Pivot": CF((0, 50, 0)), "ExtentsSize": Vec3(4, 9, 4)})
racine = piece("Racine", x, (0, 50, 0), (4, 1, 4)); x.props["PrimaryPart"] = racine
lampe = piece("Lampe", x, (0, 59, 0), (1, 1, 1)); Instance("PointLight", "PointLight", lampe).props.update({"Brightness": 2, "Range": 10})
Instance("Folder", "Boucliers", x)
interieur = Instance("Model", "Salle", Instance("Folder", "INTERIEURE", t1))
consoleA = Instance("Model", "Console", interieur); piece("Plateau", consoleA, (0, 1000, 4))
rotorA = piece("Rotor", interieur, (0, 1000, 0)); interieur.props["PrimaryPart"] = rotorA
x.attrs.update({"Etat": "Pose", "DebutEtat": 1000.0, "Mode": "Normal", "Alimentation": True})
Instance("Folder", "Sons", Instance("Folder", "TardisAssets", rs))
Config.set("Jukebox", Table({1: Table({"nom": "Calme", "id": 333})}))
init = lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/init.client.lua")
outils = init[init.index("local function partTemporaire(proprietes)"):init.index("-- La lampe du toit : la pièce qui contient la PointLight")]
O = {}
tache(lambda: O.update(t=premier(I.executer("local exterieur, Config, E = ...\n" + outils + "\nreturn { partTemporaire = partTemporaire, progressionAnimation = progressionAnimation }",
                                            "outils-extras", (x, Config, E)))))
def contexte(salle):
    return Table({"C": UI.get("C"), "Config": Config, "E": E, "Lighting": Lighting, "RunService": RunService, "UI": UI, "animer": UI.get("animer"),
                  "camera": camera, "creer": UI.get("creer"), "texte": UI.get("texte"), "def": Config.get("Tardis").get(1), "exterieur": x, "interieur": salle,
                  "joueur": joueur, "jeSuisDedans": Fonction("jeSuisDedans", py=lambda: True), "partTemporaire": O["t"].get("partTemporaire"),
                  "progressionAnimation": O["t"].get("progressionAnimation"), "remote": remote, "ReplicatedStorage": rs, "Players": game.m_FindFirstChild("Players"),
                  "boiteInt": CF((0, 1000, 0)), "tailleInt": Vec3(40, 20, 40), "dansInterieur": Fonction("dansInterieur", py=lambda p: True),
                  "maRacine": Fonction("maRacine", py=lambda: None), "lampe": lampe})
def image(dt=0.1, n=1):
    for _ in range(n):
        H.avancer(dt)
        for nom in ("RenderStepped", "Heartbeat"):
            sig = RunService.extra.get(nom)
            if sig: sig.declencher(dt)
def maintenant(): return 1000.0 + H.t
def etat(nom):
    x.m_SetAttribute("DebutEtat", maintenant()); x.m_SetAttribute("Etat", nom)
def pref(cle, valeur): UI.get("prefs").set(cle, valeur)
ambiance = lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Ambiance.lua")
tache(lambda: appeler(premier(I.executer(ambiance, "Ambiance")), [contexte(interieur)]))
verifier("Ambiance se charge (avec la taille de l'intérieur)", not roblox.ERREURS, roblox.ERREURS[:3])

# G-163 : câbles créés pour soi (pas de pièce « Cable » dans cette salle)
cordes = [e for e in ws.enfants if e.Name == "TardisCable"]
verifier("G-163. Sans pièce « Cable » : 6 câbles créés pour soi dans le workspace", len(cordes) == 6, len(cordes))
hauts = [c.props["CFrame"].p for c in cordes]
verifier("G-163. … pendus sous le plafond (centre à 1009,8 − 2 = 1007,8), en cercle de 12 studs autour du centre",
         all(abs(p[1] - 1007.8) < 1e-6 and abs(math.hypot(p[0], p[2]) - 12) < 1e-6 for p in hauts), hauts[:2])
verifier("G-163. … fins (0,15 × 4 × 0,15), sans collision", all(tuple(c.props["Size"].t()) == (0.15, 4, 0.15) and c.props.get("CanCollide") is False for c in cordes))
repos = [c.props["CFrame"].p for c in cordes]
def ecart():
    return max(math.dist(c.props["CFrame"].p, r) for c, r in zip(cordes, repos))
def ecart_max(n=40, dt=0.1, attente=0):
    image(dt, attente); m = 0
    for _ in range(n): image(dt); m = max(m, ecart())
    return m
image(0.1, 10)
verifier("G-163. Posé : les câbles ne bougent pas", ecart() < 1e-9, ecart())
x.m_SetAttribute("Stabilisateur", False)
etat("Demat"); m_libre = ecart_max()
verifier("G-163. Démat sans stabilisateur : les câbles se balancent (le bas s'écarte de plus de 0,15 stud)", m_libre > 0.15, m_libre)
verifier("G-163. … au plus 8° : le milieu du câble ne s'écarte pas de plus de 0,35 stud", m_libre < 0.35, m_libre)
x.m_SetAttribute("Stabilisateur", None)
m_stab = ecart_max(attente=40)
verifier("G-163. Stabilisé : bien plus calme (moins de la moitié)", 0 < m_stab < m_libre * 0.5, (m_stab, m_libre))
x.m_SetAttribute("Alerte", True); m_urg = ecart_max(attente=20)
verifier("G-163. En urgence (alerte) : le stabilisateur ne suffit plus, plus fort qu'en vol libre", m_urg > m_libre, (m_urg, m_libre))
x.m_SetAttribute("Alerte", None)
etat("Vol"); image(0.1, 60)
verifier("G-163. Dans le vortex : les câbles retombent à leur place", ecart() < 1e-9, ecart())
etat("Remat"); image(0.1, 2); etat("Pose")
x.m_SetAttribute("Stabilisateur", False)
image(0.1, 3); m_choc = ecart_max(10)
verifier("G-163. Atterrissage : les câbles sursautent un moment", m_choc > 0.05, m_choc)
image(0.1, 60)
verifier("G-163. … puis s'immobilisent à leur place", ecart() < 1e-9, ecart())
pref("effetsReduits", True)
etat("Demat"); m_red = ecart_max(attente=40)
verifier("G-163. Effets réduits : balancement bien plus petit", 0 < m_red < m_libre * 0.5, (m_red, m_libre))
pref("effetsReduits", False)
etat("Pose"); image(0.1, 40)
x.m_SetAttribute("Stabilisateur", None)

# G-163 : une salle qui a ses propres pièces « Cable »
salle2 = Instance("Model", "Salle2", Instance("Folder", "INTERIEURE", Instance("Folder", "TARDIS_9", ws)))
piece("Rotor", salle2, (0, 2000, 0)); vrai = piece("Cable", salle2, (5, 2008, 0), (0.3, 6, 0.3)); vrai.props["Anchored"] = True
libre = piece("Cable", salle2, (-5, 2008, 0), (0.3, 6, 0.3)); libre.props["Anchored"] = False
n_avant = len([e for e in ws.enfants if e.Name == "TardisCable"])
tache(lambda: appeler(premier(I.executer(ambiance, "Ambiance")), [contexte(salle2)]))
verifier("G-163. Une salle avec des pièces « Cable » : aucun câble créé en plus", len([e for e in ws.enfants if e.Name == "TardisCable"]) == n_avant and not roblox.ERREURS, roblox.ERREURS[:3])
p0 = vrai.props["CFrame"].p
x.m_SetAttribute("Stabilisateur", False); etat("Demat")
bouge = 0
for _ in range(30): image(0.1); bouge = max(bouge, math.dist(vrai.props["CFrame"].p, p0))
verifier("G-163. … la pièce « Cable » ancrée se balance, pendue par son haut", bouge > 0.1, bouge)
verifier("G-163. … une pièce « Cable » non ancrée (la physique s'en charge) n'est pas touchée", libre.props["CFrame"].p == (-5, 2008, 0))
etat("Pose"); image(0.1, 60)
verifier("G-163. … et reprend exactement sa place au repos", vrai.props["CFrame"].p == p0, vrai.props["CFrame"].p)
x.m_SetAttribute("Stabilisateur", None)

# G-140 : volume de la musique
verifier("G-140. Pas de musique : pas d'attribut TardisMusique", interieur.attrs.get("TardisMusique") is None)
x.m_SetAttribute("Jukebox", 1); image(0.1, 30)
sons = [e for e in descendants(game.m_FindFirstChild("SoundService")) if e.Name == "TardisJukebox"]
verifier("G-140. Le jukebox joue (un Sound local par salle chargée : 2)", len(sons) == 2, len(sons))
if sons:
    for s_ in sons: s_.props["PlaybackLoudness"] = 250
    image(0.1, 3)
    verifier("G-140. Musique à 250 : l'intérieur reçoit TardisMusique ≈ 250 (local, rien envoyé au serveur)", 240 <= (interieur.attrs.get("TardisMusique") or 0) <= 250, interieur.attrs.get("TardisMusique"))
    for s_ in sons: s_.props["PlaybackLoudness"] = 20
    image(0.1, 1)
    verifier("G-140. Le volume baisse : l'attribut suit à l'image suivante", (interieur.attrs.get("TardisMusique") or 999) <= 20, interieur.attrs.get("TardisMusique"))
    SA.set("LumieresMusique", False); image(0.1, 1)
    verifier("G-140. LumieresMusique = false : plus d'attribut", interieur.attrs.get("TardisMusique") is None)
    SA.set("LumieresMusique", True)
x.m_SetAttribute("Jukebox", None); image(0.1, 2)
verifier("G-140. Musique arrêtée : l'attribut disparaît", interieur.attrs.get("TardisMusique") is None, interieur.attrs.get("TardisMusique"))
verifier("Ambiance : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])

# ================================================================== 3. TardisEffets : les LEDs suivent la musique
vider_cache()
I, G, game, joueur = monde(serveur=False)
activer_maths(G)
rs = game.m_FindFirstChild("ReplicatedStorage"); ws = game.m_FindFirstChild("Workspace")
RunService = game.m_FindFirstChild("RunService"); Lighting = game.m_FindFirstChild("Lighting")
Lighting.props.update({"ClockTime": 12, "ExposureCompensation": 0, "Ambient": Couleur(0.5, 0.5, 0.5), "OutdoorAmbient": Couleur(0.5, 0.5, 0.5)})
Instance("PlayerGui", "PlayerGui", joueur)
camera = Instance("Camera", "Camera", ws)
camera.props.update({"CFrame": CF((0, 1002, 10)), "FieldOfView": 70, "ViewportSize": Valeur("Vector2", [1280, 720])})
ws.props["CurrentCamera"] = camera; ws.props["Terrain"] = Instance("Terrain", "Terrain", ws); ws.props["StreamingEnabled"] = False
ws.extra["Raycast"] = Fonction("Raycast", py=lambda *a: None)
t1 = Instance("Folder", "TARDIS_1", Instance("Folder", "TARDIS", ws))
x = Instance("Model", "Cabine", Instance("Folder", "EXTERIEURE", t1))
interieur = Instance("Model", "Salle", Instance("Folder", "INTERIEURE", t1))
x.props["Pivot"] = CF((0, 0.5, 0)); x.props["ExtentsSize"] = Vec3(4, 9, 4)
racine = PieceLiee("Part", "Racine", x, x, CF((0, 0, 0))); racine.props.update({"Size": Vec3(4, 1, 4), "Transparency": 1}); x.props["PrimaryPart"] = racine
lampeX = PieceLiee("Part", "Lampe", x, x, CF((0, 9, 0))); lampeX.props["Size"] = Vec3(1, 1, 1)
Instance("PointLight", "PointLight", lampeX).props.update({"Brightness": 2, "Range": 10, "Color": Couleur(1, 1, 1)})
Instance("ObjectValue", "TracteurCible", x).props["Value"] = None
rotor = Instance("Part", "Rotor", interieur); interieur.props["PrimaryPart"] = rotor; rotor.props["Pivot"] = CF((0, 1000, 0))
plafond = piece("Plafond", interieur, (0, 1005, 0), (2, 1, 2)); lp = Instance("PointLight", "Lumiere", plafond); lp.props.update({"Brightness": 2, "Color": Couleur(1, 1, 1)})
leds = Instance("Folder", "LedsAlerte", interieur); led = piece("Led", leds, (0, 1004, 2), (1, 1, 1)); ll = Instance("PointLight", "Lumiere", led); ll.props.update({"Brightness": 2, "Color": Couleur(1, 0, 0)})
perso = Instance("Model", "Perso", ws); piece("HumanoidRootPart", perso, (0, 1001, 4), (2, 2, 1)); joueur.props["Character"] = perso
x.attrs.update({"Etat": "Pose", "DebutEtat": 1000.0, "Mode": "Normal"})
G["script"] = Instance("LocalScript", "TardisEffets", game.m_FindFirstChild("StarterPlayer"))
tache(lambda: I.executer(lire("StarterPlayer/StarterPlayerScripts/TardisEffets.client.lua"), "TardisEffets"))
verifier("TardisEffets se charge", not roblox.ERREURS, roblox.ERREURS[:3])
image(1 / 30, 90)
b_led, b_pla = ll.props["Brightness"], lp.props["Brightness"]
verifier("G-140. Sans musique : LED et plafond à leur brillance d'origine (2)", abs(b_led - 2) < 0.05 and abs(b_pla - 2) < 0.05, (b_led, b_pla))
interieur.m_SetAttribute("TardisMusique", 300); image(1 / 30, 30)
verifier("G-140. Musique forte (300) : la LED monte à 1,6 × (3,2)", abs(ll.props["Brightness"] - 3.2) < 0.05, ll.props["Brightness"])
verifier("G-140. … le plafond (hors LedsAlerte) ne bouge pas", abs(lp.props["Brightness"] - 2) < 0.05, lp.props["Brightness"])
interieur.m_SetAttribute("TardisMusique", 0); image(1 / 30, 15)
verifier("G-140. Silence entre deux notes : la LED descend vite à 0,4 × (0,8) en une demi-seconde", abs(ll.props["Brightness"] - 0.8) < 0.1, ll.props["Brightness"])
verifier("G-140. … la LED garde sa couleur (rouge, non recolorée)", ll.props["Color"].rgb255() == (255, 0, 0), ll.props["Color"])
x.m_SetAttribute("Alerte", True); interieur.m_SetAttribute("TardisMusique", 300); image(1 / 30, 60)
verifier("G-140. En alerte : la musique ne pilote plus les LEDs (pas de 3,2)", ll.props["Brightness"] < 2.6, ll.props["Brightness"])
x.m_SetAttribute("Alerte", None); interieur.m_SetAttribute("TardisMusique", None); image(1 / 30, 120)
verifier("G-140. Musique arrêtée : la LED revient à 2", abs(ll.props["Brightness"] - 2) < 0.05, ll.props["Brightness"])
verifier("TardisEffets : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])

# ================================================================== 4. TardisExtras (banc d'essai)
from banc import place, demarrer_serveur
P = place()
P["ws"].extra["GetPartBoundsInRadius"] = Fonction("GetPartBoundsInRadius", py=lambda *a: Table({}))
salleB = P["t1"].m_FindFirstChild("INTERIEURE")
mursB = salleB.m_FindFirstChild("Murs")
murs_proches = piece("MurProche", mursB, (0, 10, -6), (4, 4, 1))
murs_loin = piece("MurLoin", mursB, (28, 10, 28), (4, 4, 1))
_, err = demarrer_serveur(P, duree=20)
verifier("TardisServeur, TardisExtras et TardisSystemes démarrent (banc d'essai)", not err, err[:3])
ext, j = P["ext"], P["joueur"]
RC = {}
tache(lambda: RC.update(c=premier(appeler(P["G"]["require"], [P["rs"].m_FindFirstChild("TardisConfig")]))))
CB = RC["c"]
MSG = []
canal = P["rs"].m_FindFirstChild("TardisCommande_TARDIS_1")
canal.extra["FireClient"] = Fonction("FireClient", py=lambda _s, qui, msg=None, *a: MSG.append((qui.Name, str(msg), str(a[0]) if a else "")))
joueurs = P["game"].m_FindFirstChild("Players") if "game" in P else j.parent
def gens(nom, uid):
    g = Instance("Player", nom, joueurs); g.props.update({"UserId": uid, "DisplayName": nom, "Team": None, "Character": None}); return g
def corps(qui, pos):
    m = Instance("Model", qui.Name + "Corps", P["ws"]); piece("HumanoidRootPart", m, pos, (2, 2, 1)); qui.props["Character"] = m
copi = gens("Copi", 301); tech = gens("Tech", 302); visi = gens("Visi", 303)
ext.m_SetAttribute("Copilote", 301)
ids = CB.get("Techniciens").get("UserIds"); ids.set(ids.longueur() + 1, 302)
j.m_SetAttribute("TardisAccesPilote", True)  # le joueur du banc devient pilote (accès donné par le jeu)
for g in (copi, visi): corps(g, (3, 1, 5))
corps(tech, (0, 1, 500))  # le technicien est dehors pour commencer
H.avancer(2)
tech.m_SetAttribute("TardisTechnicien_TARDIS_1", True)
def envoyer(qui, action, donnees):
    canal.__lua_index__("OnServerEvent").declencher(qui, action, donnees); H.avancer(0.6)
x0 = ext.m_GetAttribute("Jukebox")
envoyer(visi, "Jukebox", Table({"index": 1}))
verifier("C-189. Un visiteur à bord : le jukebox refuse", ext.m_GetAttribute("Jukebox") == x0, ext.m_GetAttribute("Jukebox"))
CB.set("Jukebox", Table({1: Table({"nom": "Calme", "id": 333}), 2: Table({"nom": "Alpha", "id": 111, "categorie": "Action"})}))
envoyer(copi, "Jukebox", Table({"index": 1}))
verifier("C-189. Le copilote à bord : piste choisie (attribut Jukebox = 1)", ext.m_GetAttribute("Jukebox") == 1, ext.m_GetAttribute("Jukebox"))
envoyer(copi, "Jukebox", Table({"liste": "Action"}))
verifier("C-189. Le copilote : playlist Action", ext.m_GetAttribute("Jukebox") == "Action", ext.m_GetAttribute("Jukebox"))
envoyer(tech, "Jukebox", Table({}))
verifier("C-189. Le technicien dehors : refusé (la musique continue)", ext.m_GetAttribute("Jukebox") == "Action", ext.m_GetAttribute("Jukebox"))
tech.props["Character"].m_FindFirstChild("HumanoidRootPart").props.update({"Position": Vec3(-3, 1, 5), "CFrame": CF((-3, 1, 5))}); H.avancer(1.5)
envoyer(tech, "Jukebox", Table({}))
verifier("C-189. Le technicien à bord : « Arrêter la musique » accepté", ext.m_GetAttribute("Jukebox") is None, ext.m_GetAttribute("Jukebox"))
envoyer(copi, "Jukebox", Table({"index": 2.5}))
verifier("C-189. Le copilote : une piste inconnue reste refusée (mêmes règles que les pilotes)", ext.m_GetAttribute("Jukebox") is None and any(m[2] == "Piste inconnue du jukebox." or "Piste inconnue" in m[1] or "Piste inconnue" in m[2] for m in MSG), MSG[-2:])
n_av = ext.m_GetAttribute("JukeboxDebut")
canal.__lua_index__("OnServerEvent").declencher(copi, "Jukebox", Table({"index": 1})); H.avancer(0.1)
canal.__lua_index__("OnServerEvent").declencher(copi, "Jukebox", Table({"index": 2})); H.avancer(0.6)
verifier("C-189. Anti-spam : deux ordres en 0,1 s, seul le premier passe", ext.m_GetAttribute("Jukebox") == 1, ext.m_GetAttribute("Jukebox"))
envoyer(copi, "Murs", Table({"index": 1}))
verifier("C-189. Le copilote ne gagne que le jukebox : pas les murs", ext.m_GetAttribute("CouleurMurs") is None, ext.m_GetAttribute("CouleurMurs"))
CB.get("Salle").set("JukeboxEquipage", False)
envoyer(copi, "Jukebox", Table({}))
verifier("C-189. JukeboxEquipage = false : le copilote est refusé", ext.m_GetAttribute("Jukebox") == 1)
CB.get("Salle").set("JukeboxEquipage", True)
# Le jukebox de la console : l'invite répond au copilote
invites = [e for e in descendants(P["t1"]) if e.ClassName == "ProximityPrompt" and e.Name == "TardisJukebox"]
if invites:
    MSG.clear(); declencher(invites[0], "Triggered", copi); H.avancer(0.1)
    verifier("C-189. Invite « Musique » de la console : le copilote ouvre le panneau du jukebox", any(m[0] == "Copi" and m[1] == "__jukebox" for m in MSG), MSG)
    H.avancer(1); MSG.clear(); declencher(invites[0], "Triggered", visi); H.avancer(0.1)
    verifier("C-189. … un visiteur lit « Réservé aux pilotes, au copilote et aux techniciens à bord. »",
             any(m[0] == "Visi" and m[1] == "__console" and "copilote" in m[2] for m in MSG), MSG)
else:
    verifier("C-189. Le banc a une invite TardisJukebox sur la console", False, "pas d'invite")

# G-189 : style en vague
S_I = CB.get("StylesInterieur")
def couleur(p):
    c = p.props.get("Color"); return c.rgb255() if isinstance(c, Couleur) else c
st2 = S_I.get(2)
envoyer(j, "StyleInterieur", Table({"index": 2}))  # (envoyer avance de 0,6 s)
def rgb(c): return c.rgb255() if isinstance(c, Couleur) else c
murs2 = rgb(st2.get("murs").get("couleur"))
verifier("G-189. Style de l'intérieur : 0,6 s après, le mur proche de la console a changé", couleur(murs_proches) == murs2, couleur(murs_proches))
verifier("G-189. … le mur au fond de la salle pas encore", couleur(murs_loin) != murs2, couleur(murs_loin))
H.avancer(1.6)
verifier("G-189. … 2,2 s après : toute la salle a changé (mur du fond, sol)", couleur(murs_loin) == murs2 and couleur(salleB.m_FindFirstChild("Sol")) == rgb(st2.get("sol").get("couleur")))
st3 = S_I.get(3)
canal.__lua_index__("OnServerEvent").declencher(j, "StyleInterieur", Table({"index": 2})); H.avancer(0.6)
canal.__lua_index__("OnServerEvent").declencher(j, "StyleInterieur", Table({"index": 3})); H.avancer(0.05)
verifier("G-189. Un nouveau style pendant une vague : l'ancienne se termine d'un coup (pas de mélange)", couleur(murs_loin) == murs2)
H.avancer(2.5)
verifier("G-189. … puis le nouveau style arrive partout", couleur(murs_loin) == rgb(st3.get("murs").get("couleur")) and couleur(murs_proches) == rgb(st3.get("murs").get("couleur")))
S_C = CB.get("StylesConsole")
socle = salleB.m_FindFirstChild("Console").m_FindFirstChild("Socle")
envoyer(j, "StyleConsole", Table({"index": 2}))
verifier("G-189. Style de la console : la couleur dominante change (vague rapide sur la console)", (H.avancer(2.5) or True) and couleur(socle) == rgb(S_C.get(2).get("couleur")), couleur(socle))
CB.get("Salle").set("DureeVague", 0)
canal.__lua_index__("OnServerEvent").declencher(j, "StyleInterieur", Table({"index": 4})); H.avancer(0.6)  # (anti-spam)
canal.__lua_index__("OnServerEvent").declencher(j, "StyleInterieur", Table({"index": 4})); H.avancer(0.01)
verifier("G-189. DureeVague = 0 : tout d'un coup", couleur(murs_loin) == rgb(S_I.get(4).get("murs").get("couleur")))
CB.get("Salle").set("DureeVague", 2)
verifier("TardisExtras : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])

# Le style sauvegardé revient d'un coup au démarrage (pas de vague)
P2 = place()
P2["ws"].extra["GetPartBoundsInRadius"] = Fonction("GetPartBoundsInRadius", py=lambda *a: Table({}))
loin2 = piece("MurLoin", P2["t1"].m_FindFirstChild("INTERIEURE").m_FindFirstChild("Murs"), (28, 10, 28), (4, 4, 1))
ds = P2.get("ds") or P2.get("DataStore")
ext_src = lire("ServerScriptService/TardisExtras.server.lua")
verifier("G-189. Au démarrage, les styles sauvegardés sont appliqués d'un coup (immediat = true, 4 appels)",
         ext_src.count('appliquerPieces("Murs", style.murs, true)') == 1 and ext_src.count('appliquerPieces("Sol", style.sol, true)') == 1
         and 'appliquerStyleConsole(Config.StylesConsole[reglages.styleConsole], true)' in ext_src and '.couleur }, true)' in ext_src)

# ================================================================== 5. Le code
amb = ambiance
eff = lire("StarterPlayer/StarterPlayerScripts/TardisEffets.client.lua")
verifier("Ambiance : pas de nouvelle boucle Heartbeat (deux, comme avant) et rien envoyé au serveur", amb.count("RunService.Heartbeat:Connect") == 2 and "FireServer" not in amb)
verifier("Ambiance : les câbles créés le sont par partTemporaire (locaux), aucun Instance.new", "Instance.new" not in amb[amb.index("(V7.3.2, G-163)"):amb.index("local derniereMusique")])
verifier("TardisEffets : la musique ne recolore pas les LEDs (seule la brillance)", eff.count("if not led then") == 1)
verifier("TardisExtras : une seule fonction règle le jukebox (pilotes et équipage)", ext_src.count("local function reglerJukebox") == 1 and ext_src.count("reglerJukebox(joueur, donnees)") == 3)
verifier("init.client : Ambiance reçoit tailleInt", "tailleInt = tailleInt" in init)

print("\n".join("  ✓ " + n for n in OK))
print("\n".join("  ✗ " + n for n in KO))
print(f"SALLE : AMBIANCE, JUKEBOX ET STYLE (V7.3.2) : {len(OK)}/{len(OK) + len(KO)} vérifications réussies")
sys.exit(1 if KO else 0)
