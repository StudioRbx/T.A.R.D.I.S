"""Simulations de la V7.3.3 (alerte et auto-destruction) : le vrai code, avec de faux objets Roblox.
  1. TardisConfig : alerte de la salle, avancement du compte à rebours, écran « ALERTE » (G-175), lumières éteintes (G-177),
     rotor qui s'emballe (G-178), étincelles et lueur de la console (G-179), image délavée (G-271).
  2. Ambiance (le module entier) : hologramme rouge (G-119), gyrophares (G-133), écrans Diagnostic « ALERTE » (G-175).
  3. AutoDestruction (le module entier) : étincelles de la console (G-179), image délavée après l'explosion (G-271),
     et tout revient si on annule.
  4. TardisEffets (le script entier) : lumières qui s'éteignent une à une (G-177), rotor qui s'emballe et blanchit (G-178).
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
random.seed(733)

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
AS = Config.get("AlerteSalle")
C = UI.get("C")
f = lambda nom, *a: premier(appeler(Config.get(nom), list(a)))
fs = lambda nom, *a: list(appeler(Config.get(nom), list(a)))

verifier("Config.Version ≥ 7.3.3 (7.3.3 à sa sortie)", tuple(int(n) for n in Config.get("Version").split(".")) >= (7, 3, 3), Config.get("Version"))
verifier("Config.AlerteSalle : les 7 effets actifs par défaut",
         all(AS.get(k) is True for k in ("HologrammeRouge", "Gyrophares", "EcransAlerte", "ExtinctionLumieres", "RotorEmballe", "EtincellesConsole", "ImageDelavee")))
verifier("Config.AlerteSalle : gyrophares 3 rad/s sur 40 studs, rotor ×4, 30 pièces, gris 4 s sur 200 studs",
         (AS.get("VitesseGyrophares"), AS.get("PorteeGyrophares"), AS.get("VitesseRotorMax"), AS.get("MaxEtincelles"), AS.get("DureeDelavee"), AS.get("PorteeDelavee")) == (3, 40, 4, 30, 4, 200))
verifier("alerteSalle : alerte générale → oui ; auto-destruction → oui ; ni l'une ni l'autre → non",
         f("alerteSalle", True, None) is True and f("alerteSalle", None, 1234.0) is True and f("alerteSalle", None, None) is False and f("alerteSalle", False, None) is False)
verifier("progresAutoDestruction : pas de début → nil", f("progresAutoDestruction", None, 20, 50) is None)
verifier("progresAutoDestruction : 5 s sur 20 → 0,25 ; 30 s → 1 (plafonné) ; avant le début → 0",
         (f("progresAutoDestruction", 100, 20, 105), f("progresAutoDestruction", 100, 20, 130), f("progresAutoDestruction", 100, 20, 90)) == (0.25, 1, 0))
verifier("progresAutoDestruction : durée absente ou nulle → 20 s par défaut", f("progresAutoDestruction", 100, None, 110) == 0.5 and f("progresAutoDestruction", 100, 0, 110) == 0.5)
verifier("G-175. ecranAlerte : une seconde sur trois (0 oui, 1 non, 2 non, 3,5 oui)",
         [f("ecranAlerte", t) for t in (0, 1.2, 2.9, 3.5, 4, 6.01)] == [True, False, False, True, False, True])
verifier("G-177. lumieresEteintes : p = 0 → 0 ; 0,5 sur 7 → 3 ; 1 → 7", (f("lumieresEteintes", 0, 7), f("lumieresEteintes", 0.5, 7), f("lumieresEteintes", 1, 7)) == (0, 3, 7))
verifier("G-177. lumieresEteintes : pas de compte à rebours (nil) ou aucune lumière → 0", f("lumieresEteintes", None, 7) == 0 and f("lumieresEteintes", 0.5, 0) == 0)
verifier("G-178. rotorAutoDestruction : début ×1, moitié ×1,75, fin ×4 ; blanc = avancement",
         fs("rotorAutoDestruction", 0) == [1, 0] and fs("rotorAutoDestruction", 0.5) == [1.75, 0.5] and fs("rotorAutoDestruction", 1) == [4, 1])
verifier("G-178. rotorAutoDestruction : au-delà de 1 → plafonné (×4)", fs("rotorAutoDestruction", 3)[0] == 4)
AS.set("VitesseRotorMax", 2)
verifier("G-178. VitesseRotorMax = 2 → ×2 à la fin", fs("rotorAutoDestruction", 1)[0] == 2)
AS.set("VitesseRotorMax", 4)
verifier("G-179. etincellesConsole : une pièce dès le début, une de plus chaque seconde",
         [f("etincellesConsole", e, e / 20, 30) for e in (0, 0.5, 1, 2.5, 7)] == [1, 1, 2, 3, 10])
verifier("G-179. etincellesConsole : toutes à la fin, même s'il y a plus de pièces que de secondes (30 sur 20 s)", f("etincellesConsole", 19.5, 0.975, 30) == 29 and f("etincellesConsole", 20, 1, 30) == 30)
verifier("G-179. etincellesConsole : jamais plus que de pièces ; console vide → 0", f("etincellesConsole", 15, 0.75, 5) == 5 and f("etincellesConsole", 3, 0.1, 0) == 0)
verifier("G-179. lueurConsole : 0 jusqu'à 75 %, 0,5 à 87,5 %, 1 à la fin", (f("lueurConsole", 0.5), f("lueurConsole", 0.875), f("lueurConsole", 1)) == (0, 0.5, 1))
verifier("G-271. delavage : gris (-1) au début, -0,5 à mi-chemin, 0 à la fin et après", (f("delavage", 0, 4), f("delavage", 2, 4), f("delavage", 4, 4), f("delavage", 9, 4)) == (-1, -0.5, 0, 0))
verifier("G-271. delavage : durée nulle → 0 (rien)", f("delavage", 1, 0) == 0)
verifier("G-271. forceDelavage : tout près → 1 ; à 100 studs → 0,75 ; au bord (200) → 0,5 ; au-delà → 0",
         (f("forceDelavage", 0), f("forceDelavage", 100), f("forceDelavage", 200), f("forceDelavage", 201)) == (1, 0.75, 0.5, 0))

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
consoleA = Instance("Model", "Console", interieur)
piecesConsole = [piece("Plateau", consoleA, (0, 1000, 4))] + [piece("Levier" + str(i), consoleA, (i, 1001, 4), (0.5, 0.5, 0.5)) for i in range(1, 5)]
rotorA = piece("Rotor", interieur, (0, 1000, 0)); interieur.props["PrimaryPart"] = rotorA
diags = [piece("Diagnostic" + str(i), interieur, (i * 3, 1003, -10), (4, 3, 0.2)) for i in range(1, 5)]
x.attrs.update({"Etat": "Pose", "DebutEtat": 1000.0, "Mode": "Normal", "Alimentation": True})
Instance("Folder", "Sons", Instance("Folder", "TardisAssets", rs))
init = lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/init.client.lua")
outils = init[init.index("local function partTemporaire(proprietes)"):init.index("-- La lampe du toit : la pièce qui contient la PointLight")]
O = {}
tache(lambda: O.update(t=premier(I.executer("local exterieur, Config, E = ...\n" + outils + "\nreturn { partTemporaire = partTemporaire, progressionAnimation = progressionAnimation }",
                                            "outils-extras", (x, Config, E)))))
SECOUSSES = []
def contexte(salle):
    return Table({"C": C, "Config": Config, "E": E, "Lighting": Lighting, "RunService": RunService, "UI": UI, "animer": UI.get("animer"),
                  "camera": camera, "creer": UI.get("creer"), "texte": UI.get("texte"), "def": Config.get("Tardis").get(1), "exterieur": x, "interieur": salle,
                  "joueur": joueur, "jeSuisDedans": Fonction("jeSuisDedans", py=lambda: True), "partTemporaire": O["t"].get("partTemporaire"),
                  "progressionAnimation": O["t"].get("progressionAnimation"), "remote": remote, "ReplicatedStorage": rs, "Players": game.m_FindFirstChild("Players"),
                  "boiteInt": CF((0, 1000, 0)), "tailleInt": Vec3(40, 20, 40), "dansInterieur": Fonction("dansInterieur", py=lambda p: True),
                  "maRacine": Fonction("maRacine", py=lambda: None), "lampe": lampe, "secouer": Fonction("secouer", py=lambda f_: SECOUSSES.append(f_))})
def image(dt=0.1, n=1):
    for _ in range(n):
        H.avancer(dt)
        for nom in ("RenderStepped", "Heartbeat"):
            sig = RunService.extra.get(nom)
            if sig: sig.declencher(dt)
def maintenant(): return 1000.0 + H.t
def pref(cle, valeur): UI.get("prefs").set(cle, valeur)
ambiance = lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Ambiance.lua")
tache(lambda: appeler(premier(I.executer(ambiance, "Ambiance")), [contexte(interieur)]))
verifier("Ambiance se charge", not roblox.ERREURS, roblox.ERREURS[:3])

# G-119 : hologramme
holo = ws.m_FindFirstChild("TardisHologramme"); faisceau = ws.m_FindFirstChild("TardisHologrammeFaisceau")
contours = [e for e in descendants(holo) if e.ClassName == "UIStroke"] if holo else []
titreHolo = [e for e in descendants(holo) if e.ClassName == "TextLabel" and str(e.props.get("Text", "")).startswith(("HOLOGRAMME", "DESTINATION"))] if holo else []
image(0.1, 5)
titreHolo = [e for e in descendants(holo) if e.ClassName == "TextLabel" and str(e.props.get("Text", "")).startswith(("HOLOGRAMME", "DESTINATION"))] if holo else []
verifier("G-119. L'hologramme a son cadre et ses 3 anneaux (4 contours), cyan hors alerte",
         len(contours) == 4 and all(c.props.get("Color") is C.get("cyan") for c in contours) and faisceau.props.get("Color") is C.get("cyan"), [c.props.get("Color") for c in contours])
x.m_SetAttribute("Alerte", True); image(0.1, 4)
verifier("G-119. Alerte générale : les 4 contours, le faisceau et le titre passent au rouge",
         all(c.props.get("Color") is C.get("rouge") for c in contours) and faisceau.props.get("Color") is C.get("rouge")
         and titreHolo and titreHolo[0].props.get("TextColor3") is C.get("rouge"))
vals = set()
for _ in range(12): image(0.13); vals.add(round(faisceau.props["Transparency"], 3))
verifier("G-119. … le faisceau pulse fort (entre 0,45 et 0,8)", len(vals) >= 3 and min(vals) >= 0.45 - 1e-6 and max(vals) <= 0.8 + 1e-6 and max(vals) - min(vals) > 0.1, sorted(vals))
pref("sansFlash", True); vals = set()
for _ in range(8): image(0.13); vals.add(round(faisceau.props["Transparency"], 3))
verifier("G-119. « Aucun flash » : le faisceau reste rouge mais ne bat plus (0,6 fixe)", vals == {0.6}, vals)
pref("sansFlash", False)
x.m_SetAttribute("Alerte", None); image(0.1, 4)
verifier("G-119. Fin de l'alerte : tout revient au cyan", all(c.props.get("Color") is C.get("cyan") for c in contours) and faisceau.props.get("Color") is C.get("cyan")
         and titreHolo[0].props.get("TextColor3") is C.get("cyan"))
x.m_SetAttribute("AutoDestructionDebut", maintenant()); image(0.1, 4)
verifier("G-119. Auto-destruction (sans alerte générale) : rouge aussi", faisceau.props.get("Color") is C.get("rouge") and all(c.props.get("Color") is C.get("rouge") for c in contours))
x.m_SetAttribute("AutoDestructionDebut", None); image(0.1, 4)
verifier("G-119. Auto-destruction annulée : cyan", faisceau.props.get("Color") is C.get("cyan"))
AS.set("HologrammeRouge", False); x.m_SetAttribute("Alerte", True); image(0.1, 4)
verifier("G-119. HologrammeRouge = false : l'hologramme reste cyan en alerte", faisceau.props.get("Color") is C.get("cyan"))
x.m_SetAttribute("Alerte", None); AS.set("HologrammeRouge", True); image(0.1, 4)

# G-133 : gyrophares
gyros = [e for e in ws.enfants if e.Name == "TardisGyrophare"]
spots = [e.m_FindFirstChild("TardisGyrophareLumiere") for e in gyros]
verifier("G-133. Sans pièce « Gyrophare » : 2 projecteurs créés pour soi", len(gyros) == 2 and all(s is not None and s.ClassName == "SpotLight" for s in spots), len(gyros))
pos = sorted(tuple(round(c, 6) for c in g.props["CFrame"].p) for g in gyros)
verifier("G-133. … au-dessus de la console (3 studs de part et d'autre), sous le plafond (1009)", pos == [(-3, 1009, 4), (3, 1009, 4)], pos)
verifier("G-133. … rouges, portée 40, éteints hors alerte", all(s.props.get("Color").rgb255() == (255, 30, 30) and s.props.get("Range") == 40 and s.props.get("Enabled") is False for s in spots))
x.m_SetAttribute("Alerte", True); image(0.05)
r1 = [g.props["CFrame"].R for g in gyros]; image(0.1)
r2 = [g.props["CFrame"].R for g in gyros]
verifier("G-133. Alerte : les deux gyrophares s'allument et tournent", all(s.props.get("Enabled") is True for s in spots) and r1 != r2)
d1, d2 = (g.props["CFrame"].col(2) for g in gyros)
verifier("G-133. … penchés vers le bas, l'un à l'opposé de l'autre", d1.t()[1] > 0.5 and d2.t()[1] > 0.5 and abs(d1.t()[0] + d2.t()[0]) < 1e-6 and abs(d1.t()[2] + d2.t()[2]) < 1e-6, (d1.t(), d2.t()))
verifier("G-133. … restent à leur place (ils tournent sur eux-mêmes)", sorted(tuple(round(c, 6) for c in g.props["CFrame"].p) for g in gyros) == pos)
x.m_SetAttribute("Detruit", True); image(0.05)
verifier("G-133. TARDIS détruit : éteints", all(s.props.get("Enabled") is False for s in spots))
x.m_SetAttribute("Detruit", None); x.m_SetAttribute("Alerte", None); image(0.05)
verifier("G-133. Fin de l'alerte : éteints", all(s.props.get("Enabled") is False for s in spots))
x.m_SetAttribute("AutoDestructionDebut", maintenant()); image(0.05)
verifier("G-133. Auto-destruction : allumés aussi", all(s.props.get("Enabled") is True for s in spots))
x.m_SetAttribute("AutoDestructionDebut", None); image(0.05)
# Une salle avec ses pièces « Gyrophare »
salle2 = Instance("Model", "Salle2", Instance("Folder", "INTERIEURE", Instance("Folder", "TARDIS_9", ws)))
piece("Rotor", salle2, (0, 2000, 0))
vraiGyro = piece("Gyrophare", Instance("Folder", "Plafond", salle2), (7, 2012, -2), (1, 1, 1))
n_avant = len([e for e in ws.enfants if e.Name == "TardisGyrophare"])
tache(lambda: appeler(premier(I.executer(ambiance, "Ambiance")), [contexte(salle2)]))
nouveaux = [e for e in ws.enfants if e.Name == "TardisGyrophare"][n_avant:]
verifier("G-133. Une salle avec une pièce « Gyrophare » : un projecteur à sa place, aucun autre", len(nouveaux) == 1 and tuple(nouveaux[0].props["CFrame"].p) == (7, 2012, -2) and not roblox.ERREURS,
         ([tuple(n.props["CFrame"].p) for n in nouveaux], roblox.ERREURS[:2]))
x.m_SetAttribute("Alerte", True); image(0.1, 3); x.m_SetAttribute("Alerte", None); image(0.1)
verifier("G-133. … la pièce « Gyrophare » elle-même ne bouge jamais", tuple(vraiGyro.props["CFrame"].p) == (7, 2012, -2) and vraiGyro.props["CFrame"].R == CF((0, 0, 0)).R)

# G-175 : écrans Diagnostic
def titres(i):
    return [e for e in descendants(diags[i]) if e.ClassName == "TextLabel" and e.props.get("LayoutOrder") == 1]
def textes(i):
    return [str(e.props.get("Text", "")) for e in descendants(diags[i]) if e.ClassName == "TextLabel"]
vus = set()
for _ in range(14): image(0.5); vus.add(titres(0)[0].props.get("Text"))
verifier("G-175. Hors alerte : jamais « ALERTE » sur les écrans", "⚠ ALERTE ⚠" not in vus and "ÉNERGIE" in vus, vus)
x.m_SetAttribute("Alerte", True)
journal = []
for _ in range(14):
    image(0.5); journal.append((math.floor(H.t), [titres(i)[0].props.get("Text") for i in range(4)]))
alerte_vu = [t for t, ts in journal if all(v == "⚠ ALERTE ⚠" for v in ts)]
normal_vu = [t for t, ts in journal if ts == ["ÉNERGIE", "ACCÈS", "NAVIGATION", "SÉCURITÉ"]]
verifier("G-175. Alerte : les 4 écrans affichent « ⚠ ALERTE ⚠ » ensemble, une seconde sur trois",
         alerte_vu and normal_vu and all(t % 3 == 0 for t in alerte_vu) and all(t % 3 != 0 for t in normal_vu), journal[:8])
while math.floor(H.t + 0.5) % 3 != 0: image(0.5)
image(0.5)
t0 = titres(0)[0]
verifier("G-175. … en grand (44) et en rouge ; les lignes s'effacent",
         t0.props.get("Text") == "⚠ ALERTE ⚠" and t0.props.get("TextSize") == 44 and t0.props.get("TextColor3") is C.get("rouge")
         and all(s in ("", "⚠ ALERTE ⚠") for s in textes(1)), (t0.props.get("Text"), t0.props.get("TextSize"), textes(1)))
x.m_SetAttribute("AutoDestructionDebut", maintenant()); image(0.5)
verifier("G-175. Auto-destruction : « AUTO-DESTRUCTION » sous le titre", "AUTO-DESTRUCTION" in textes(0) if titres(0)[0].props.get("Text") == "⚠ ALERTE ⚠" else True, textes(0))
x.m_SetAttribute("AutoDestructionDebut", None); x.m_SetAttribute("Alerte", None)
image(0.5, 7)
t0 = titres(0)[0]
verifier("G-175. Fin de l'alerte : titre normal, taille 22, cyan", t0.props.get("Text") == "ÉNERGIE" and t0.props.get("TextSize") == 22 and t0.props.get("TextColor3") is C.get("cyan"))
AS.set("EcransAlerte", False); x.m_SetAttribute("Alerte", True); vus = set()
for _ in range(8): image(0.5); vus.add(titres(0)[0].props.get("Text"))
verifier("G-175. EcransAlerte = false : pas de « ALERTE » (l'écran garde ses voyants)", "⚠ ALERTE ⚠" not in vus, vus)
AS.set("EcransAlerte", True); x.m_SetAttribute("Alerte", None); image(0.5, 2)
verifier("Ambiance : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])

# ================================================================== 3. AutoDestruction (module entier)
auto = lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/AutoDestruction.lua")
tache(lambda: appeler(premier(I.executer(auto, "AutoDestruction")), [contexte(interieur)]))
verifier("AutoDestruction se charge (avec Config, intérieur et Lighting)", not roblox.ERREURS, roblox.ERREURS[:3])
def etincelles(): return [e for e in descendants(consoleA) if e.Name == "TardisEtincelles"]
def lueur(): return consoleA.m_FindFirstChild("TardisLueurConsole")
debut = maintenant()
x.m_SetAttribute("AutoDestructionDuree", 20); x.m_SetAttribute("AutoDestructionDebut", debut)
compte = []
for _ in range(30):
    image(0.1); compte.append(len(etincelles()))
verifier("G-179. Compte à rebours : une pièce de la console crache des étincelles tout de suite, puis une de plus chaque seconde",
         compte[0] == 1 and compte[5] == 1 and compte[15] == 2 and compte[25] == 3 and compte == sorted(compte) and max(compte) - min(compte) <= 3, compte)
em = etincelles()
verifier("G-179. … de vraies étincelles (ParticleEmitter, 14 par seconde, sur des pièces différentes)",
         all(e.ClassName == "ParticleEmitter" and e.props.get("Rate") == 14 for e in em) and len({id(e.parent) for e in em}) == len(em))
verifier("G-179. … la console ne rougeoie pas encore", lueur() is not None and lueur().props.get("FillTransparency") == 1)
while maintenant() - debut < 17.5: image(0.1)
verifier("G-179. À 17,5 s (sur 20) : les 5 pièces crachent, la console rougeoie à moitié",
         len(etincelles()) == 5 and abs(lueur().props.get("FillTransparency") - 0.7) < 0.02, (len(etincelles()), lueur().props.get("FillTransparency")))
x.m_SetAttribute("AutoDestructionDebut", None); image(0.1, 2)
verifier("G-179. Auto-destruction annulée : plus d'étincelles ni de lueur", len(etincelles()) == 0 and lueur() is None, (len(etincelles()), lueur()))
pref("effetsReduits", True)
x.m_SetAttribute("AutoDestructionDebut", maintenant()); image(0.1, 2)
verifier("G-179. Effets réduits : moins d'étincelles (4 par seconde)", etincelles() and all(e.props.get("Rate") == 4 for e in etincelles()))
x.m_SetAttribute("AutoDestructionDebut", None); image(0.1, 2); pref("effetsReduits", False)
AS.set("EtincellesConsole", False); x.m_SetAttribute("AutoDestructionDebut", maintenant()); image(0.1, 15)
verifier("G-179. EtincellesConsole = false : rien sur la console", len(etincelles()) == 0 and lueur() is None)
x.m_SetAttribute("AutoDestructionDebut", None); image(0.1, 2); AS.set("EtincellesConsole", True)
# G-179 : une grande console, répartie sur 30 pièces
for k in range(60): piece("Bouton" + str(k), consoleA, (k * 0.1, 1001, 5), (0.2, 0.2, 0.2))
debut = maintenant(); x.m_SetAttribute("AutoDestructionDebut", debut)
while maintenant() - debut < 19.95: image(0.1)
em = etincelles()
verifier("G-179. Console de 65 pièces : au plus 30 crachent à la fin (MaxEtincelles)", len(em) == 30 and len({id(e.parent) for e in em}) == 30, len(em))
x.m_SetAttribute("AutoDestructionDebut", None); image(0.1, 2)
# G-271 : image délavée après l'explosion
def delavee(): return Lighting.m_FindFirstChild("TardisImageDelavee")
x.m_SetAttribute("Explosion", True); image(0.05)
eff0 = delavee()
sat0 = eff0.props.get("Saturation") if eff0 else None
attendu = 0.5 + 0.5 * (1 - math.dist((0, 60, 20), (0, 54, 0)) / 200)
verifier("G-271. Explosion à 21 studs : l'image devient presque grise (saturation ≈ -0,95)", eff0 is not None and eff0.ClassName == "ColorCorrectionEffect" and abs(sat0 + attendu) < 0.03, (sat0, attendu))
image(0.05, 39)
sat2 = delavee().props.get("Saturation") if delavee() else None
verifier("G-271. … à mi-chemin (2 s) : moitié moins gris", sat2 is not None and abs(sat2 + attendu / 2) < 0.03, sat2)
image(0.1, 22)
verifier("G-271. … après 4 s : les couleurs sont revenues, l'effet est retiré", delavee() is None)
x.m_SetAttribute("Explosion", None); image(0.1)
camera.props["CFrame"] = CF((0, 60, 400))
x.m_SetAttribute("Explosion", True); image(0.05)
verifier("G-271. Explosion à 400 studs : pas d'image grise", delavee() is None)
x.m_SetAttribute("Explosion", None); camera.props["CFrame"] = CF((0, 60, 20)); image(0.1)
AS.set("ImageDelavee", False); x.m_SetAttribute("Explosion", True); image(0.05)
verifier("G-271. ImageDelavee = false : pas d'image grise", delavee() is None)
x.m_SetAttribute("Explosion", None); AS.set("ImageDelavee", True); image(0.1, 50)
verifier("AutoDestruction : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])

# AutoDestruction avec un contexte ancien (sans Config, intérieur ni Lighting) : pas d'erreur, pas d'étincelles
vider_cache()
I, G, game, joueur = monde(serveur=False)
activer_maths(G)
rs = game.m_FindFirstChild("ReplicatedStorage"); ws = game.m_FindFirstChild("Workspace")
RunService = game.m_FindFirstChild("RunService")
camera = Instance("Camera", "Camera", ws); camera.props["CFrame"] = CF((0, 60, 20)); ws.props["CurrentCamera"] = camera
Instance("PlayerGui", "PlayerGui", joueur)
x2 = Instance("Model", "Cabine", Instance("Folder", "EXTERIEURE", Instance("Folder", "TARDIS_1", Instance("Folder", "TARDIS", ws))))
x2.props.update({"Pivot": CF((0, 50, 0)), "ExtentsSize": Vec3(4, 9, 4)}); x2.props["PrimaryPart"] = piece("Racine", x2, (0, 50, 0), (4, 1, 4))
U2 = {}
tache(lambda: U2.update(UI=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisUI")]))))
ancien = Table({"ReplicatedStorage": rs, "RunService": RunService, "animer": U2["UI"].get("animer"), "camera": camera, "creer": U2["UI"].get("creer"), "exterieur": x2,
                "jeSuisDedans": Fonction("j", py=lambda: False), "joueur": joueur, "partTemporaire": Fonction("p", py=lambda props: Instance("Part", "P", ws)),
                "secouer": Fonction("s", py=lambda *a: None)})
tache(lambda: appeler(premier(I.executer(auto, "AutoDestruction")), [ancien]))
x2.m_SetAttribute("AutoDestructionDebut", 1000.0 + H.t); image(0.1, 5)
x2.m_SetAttribute("AutoDestructionDebut", None); image(0.1, 2)
x2.m_SetAttribute("Explosion", True); image(0.1, 5)
verifier("AutoDestruction avec l'ancien contexte (sans Config ni intérieur) : marche toujours, image grise comprise",
         not roblox.ERREURS and game.m_FindFirstChild("Lighting").m_FindFirstChild("TardisImageDelavee") is not None, roblox.ERREURS[:3])

# ================================================================== 4. TardisEffets : lumières et rotor
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
rotor = Instance("Part", "Rotor", interieur); interieur.props["PrimaryPart"] = rotor; rotor.props.update({"Pivot": CF((0, 1000, 0)), "Position": Vec3(0, 1000, 0)})
lr = Instance("PointLight", "LumiereRotor", rotor); lr.props.update({"Brightness": 2, "Color": Couleur(1, 1, 1)})
plafonds = []
for k in range(6):
    p_ = piece("Plafond" + str(k), interieur, (k - 3, 1005, 0), (1, 1, 1)); l_ = Instance("PointLight", "Lumiere", p_); l_.props.update({"Brightness": 2, "Color": Couleur(1, 1, 1)})
    plafonds.append(l_)
leds = Instance("Folder", "LedsAlerte", interieur); led = piece("Led", leds, (0, 1004, 2), (1, 1, 1)); ll = Instance("PointLight", "Lumiere", led); ll.props.update({"Brightness": 2, "Color": Couleur(1, 0, 0)})
perso = Instance("Model", "Perso", ws); piece("HumanoidRootPart", perso, (0, 1001, 4), (2, 2, 1)); joueur.props["Character"] = perso
x.attrs.update({"Etat": "Pose", "DebutEtat": 1000.0, "Mode": "Normal"})
G["script"] = Instance("LocalScript", "TardisEffets", game.m_FindFirstChild("StarterPlayer"))
tache(lambda: I.executer(lire("StarterPlayer/StarterPlayerScripts/TardisEffets.client.lua"), "TardisEffets"))
verifier("TardisEffets se charge", not roblox.ERREURS, roblox.ERREURS[:3])
image(1 / 30, 90)
def brillances(): return [round(l.props["Brightness"], 2) for l in plafonds]
verifier("Avant : les 6 lumières du plafond, la LED et le rotor à 2", brillances() == [2] * 6 and abs(ll.props["Brightness"] - 2) < 0.05 and abs(lr.props["Brightness"] - 2) < 0.05, brillances())
def course(n=150, dt=1 / 30):
    ys, croisements = [], 0
    for _ in range(n):
        image(dt); ys.append(rotor.props["Pivot"].p[1] - 1000)
    for a, b in zip(ys, ys[1:]):
        if (a < 0) != (b < 0): croisements += 1
    return max(abs(y) for y in ys), croisements
amp_pose, _ = course(60)
verifier("G-178. Posé, sans compte à rebours : le rotor ne bouge pas", amp_pose < 1e-6, amp_pose)
# Compte à rebours très long (1000 s) : on choisit l'avancement en reculant le début
x.m_SetAttribute("AutoDestructionDuree", 1000)
x.m_SetAttribute("AutoDestructionDebut", maintenant() - 500); image(1 / 30, 120)
b = brillances()
verifier("G-177. À mi-chemin : 3 lumières sur 6 éteintes, les 3 premières du plafond (les autres restent à 2)", b[:3] == [0, 0, 0] and b[3:] == [2, 2, 2], b)
verifier("G-177. … la LED d'alerte et le rotor restent allumés", ll.props["Brightness"] > 1.9 and lr.props["Brightness"] > 1.9, (ll.props["Brightness"], lr.props["Brightness"]))
x.m_SetAttribute("AutoDestructionDebut", maintenant() - 999); image(1 / 30, 120)
verifier("G-177. À la fin : toutes les lumières du plafond éteintes, restent la LED rouge et le rotor",
         brillances() == [0] * 6 and ll.props["Brightness"] > 1.9 and lr.props["Brightness"] > 1.9, (brillances(), ll.props["Brightness"]))
x.m_SetAttribute("AutoDestructionDebut", maintenant() - 2); image(1 / 30, 60)
couleur_debut = lr.props["Color"].rgb255()
amp_debut, cr_debut = course()
x.m_SetAttribute("AutoDestructionDebut", maintenant() - 999); image(1 / 30, 60)
couleur_fin = lr.props["Color"].rgb255()
amp_fin, cr_fin = course()
verifier("G-178. Compte à rebours : le rotor pompe même posé, à pleine course", amp_debut > 0.1 and amp_fin > 0.1, (amp_debut, amp_fin))
verifier("G-178. … de plus en plus vite : au moins 3 fois plus d'allers-retours à la fin qu'au début", cr_fin >= 3 * cr_debut and cr_debut > 0, (cr_debut, cr_fin))
verifier("G-178. … sa lumière vire du rouge (au début) au blanc-rouge (à la fin)", couleur_debut[1] < 110 and couleur_fin[1] > 200 and couleur_debut[0] > 240, (couleur_debut, couleur_fin))
x.m_SetAttribute("AutoDestructionDebut", None); image(1 / 30, 200)
verifier("Annulé : les lumières du plafond se rallument (2)", brillances() == [2] * 6, brillances())
amp_apres, _ = course(30, 1 / 30); image(1 / 30, 60); amp_apres, _ = course(30)
verifier("Annulé : le rotor s'arrête et sa lumière redevient blanche", amp_apres < 1e-6 and lr.props["Color"].rgb255() == (255, 255, 255), (amp_apres, lr.props["Color"].rgb255()))
AS2 = None
R2 = {}
tache(lambda: R2.update(c=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisConfig")]))))
AS2 = R2["c"].get("AlerteSalle")
AS2.set("ExtinctionLumieres", False); AS2.set("RotorEmballe", False)
x.m_SetAttribute("AutoDestructionDebut", maintenant() - 999); image(1 / 30, 90)
amp_off, _ = course(30)
verifier("ExtinctionLumieres = false et RotorEmballe = false : lumières allumées, rotor immobile", brillances() == [2] * 6 and amp_off < 1e-6, (brillances(), amp_off))
x.m_SetAttribute("AutoDestructionDebut", None); image(1 / 30, 30)
verifier("TardisEffets : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])

# ================================================================== 5. Le code
eff = lire("StarterPlayer/StarterPlayerScripts/TardisEffets.client.lua")
verifier("Ambiance : toujours deux boucles Heartbeat (les gyrophares tournent dans RenderStepped) et rien envoyé au serveur",
         ambiance.count("RunService.Heartbeat:Connect") == 2 and ambiance.count("RunService.RenderStepped:Connect") == 1 and "FireServer" not in ambiance)
verifier("TardisEffets : pas de nouvelle boucle par image (3 RenderStepped, 1 Heartbeat)", eff.count("RunService.RenderStepped:Connect") == 3 and eff.count("RunService.Heartbeat:Connect") == 1)
verifier("AutoDestruction : rien envoyé au serveur ; l'image grise se défait seule (Disconnect + Destroy)", "FireServer" not in auto and "lien:Disconnect()" in auto and "effet:Destroy()" in auto)
verifier("init.client : AutoDestruction reçoit Config, Lighting et l'intérieur", 'require(script:WaitForChild("AutoDestruction"))({ Config = Config, Lighting = Lighting, interieur = interieur,' in init)
verifier("Les gyrophares créés sont locaux (partTemporaire), aucun Instance.new dans Ambiance", "Instance.new" not in ambiance)

print("\n".join("  ✓ " + n for n in OK))
print("\n".join("  ✗ " + n for n in KO))
print(f"ALERTE ET AUTO-DESTRUCTION (V7.3.3) : {len(OK)}/{len(OK) + len(KO)} vérifications réussies")
sys.exit(1 if KO else 0)
