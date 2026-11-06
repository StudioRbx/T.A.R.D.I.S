"""Simulations de la V6.9.10.1 (ajustements Studio) : le vrai code, exécuté avec de faux objets Roblox qui reprennent
la place du propriétaire (canal TardisCommande_TARDIS_1, chemins réels de la console).
  1. TardisConfig : version 6.9.10.1, nouveaux chemins (Alerte, VolLibre, EcranIngenieur, Casier, JukeBox), réglages
     marqués « (V6.9.10.1) », Config.trouverCommande / Config.partDe.
  2. TardisEffets (le script entier, image par image) : les néons de la salle prennent la couleur de l'état puis
     retrouvent exactement leur couleur d'origine ; rotor, LedsAlerte et écrans jamais touchés ; repeints seulement
     quand leur couleur change ; « réduire les effets », hors tension, couleur changée par le serveur.
  3. Serveur, module TardisServeur › Ecrans : deux écrans de destination (deux pièces « Ecran », ou un Model « Ecran »),
     attribut FaceEcran, destination, état, mode, alerte, messages, hors tension, détruit ; écran ingénieur (PV, énergie,
     régulation, boucliers) ; clic : pilote ou technicien → menu, autre → message.
  4. Serveur : le vrai gestionnaire des ordres de TardisServeur (traiterOrdre) et le module VolLibre : le bouton
     Console › Selecteur › Colors lance le vol libre pour un pilote, rien pour un autre ; le Selecteur garde sa pièce.
  5. TardisDiagnostic : nouveaux chemins Alerte et VolLibre trouvés ; Casier, JukeBox, EcranIngenieur facultatifs.
  6. Interphone supprimé : plus aucune trace dans le code, l'action est ignorée par TardisExtras (vrai gestionnaire).
  7. Régulation (vrai TardisSystemes) : pilote et technicien acceptés, autre refusé, hors bornes et mauvais types refusés.
  8. Client, module Console : menu de gestion de l'énergie (réglage envoyé, rejoué sur le vrai serveur, écran
     ingénieur mis à jour), panneau du jukebox (pistes, playlist, arrêt, vide), messages, fermeture (bouton, Échap, distance).
  9. Jukebox de la console (vrai TardisExtras) : pilote → panneau, autre → « Réservé aux pilotes. » ; l'action Jukebox
     appliquée pour un pilote, refusée pour un autre.
 10. Client, module Interactions : casier de la console (invite « Choisir une tenue » et clic), autres casiers inchangés.
 11. Client, module Ambiance : la ligne vivante va dans la bande du bas de chaque écran de destination."""
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
def maintenant(): return 1000.0 + H.t
def descendants(o):
    res = []
    def visite(x):
        for e in x.enfants: res.append(e); visite(e)
    visite(o); return res
def enfant_classe(o, classe, nom=None):
    return [e for e in o.enfants if e.ClassName == classe and (nom is None or e.Name == nom)]
def declencher(objet, signal, *args):
    objet.extra.setdefault(signal, Signal(signal)).declencher(*args)
def texte_de(o): return str(o.props.get("Text", ""))
V3 = lambda x, y, z: Valeur("Vector3", [x, y, z])
SRC = lambda chemin: lire(chemin)


def console_reelle(interieur, ecrans="deux"):
    """La console du propriétaire : Selecteur (Model) › Colors, Datapanel › Redbutton › Button, Ecran(s), Ecran-Ingenieure,
    Casier (Model), JukeBox ; et les autres commandes de Config.Chemins."""
    console = Instance("Model", "Console", interieur)
    sel = Instance("Model", "Selecteur", console)
    Instance("Part", "Molette", sel)
    colors = Instance("Part", "Colors", sel)
    dp = Instance("Model", "Datapanel", console); rb = Instance("Model", "Redbutton", dp); Instance("Part", "Button", rb)
    if ecrans == "deux":
        e1 = Instance("Part", "Ecran", console); e2 = Instance("Part", "Ecran", console); e2.attrs["FaceEcran"] = "Back"
        ecr = [e1, e2]
    else:
        m = Instance("Model", "Ecran", console); m.attrs["FaceEcran"] = "Back"
        e1 = Instance("Part", "Gauche", m); e2 = Instance("Part", "Droite", m); e2.attrs["FaceEcran"] = "top"
        cadre = Instance("Part", "Cadre", m); cadre.attrs["FaceEcran"] = "Aucune"
        ecr = [e1, e2, cadre]
    ing = Instance("Part", "Ecran-Ingenieure", console)
    casier = Instance("Model", "Casier", console); Instance("Part", "Porte", casier)
    juke = Instance("Part", "JukeBox", console)
    Instance("Part", "BoutonCamera", console)
    lv = Instance("Model", "LeverLeft", console); m_ = Instance("Model", "Main", lv); l_ = Instance("Model", "Lever", m_); Instance("Part", "Main", l_)
    ctr = Instance("Model", "Controls", interieur)
    ml = Instance("Model", "Matlever", ctr); fly = Instance("Model", "Fly", ml); Instance("Part", "Levier", fly)
    ll = Instance("Model", "LockLever", ctr); m2 = Instance("Model", "Main", ll); l2 = Instance("Model", "Lever", m2); Instance("Part", "Main", l2)
    pw = Instance("Model", "Power", ctr); Instance("Part", "On", pw)
    return {"console": console, "selecteur": sel, "colors": colors, "ecrans": ecr, "ingenieur": ing, "casier": casier, "jukebox": juke}


# ================================================================== 1. TardisConfig
vider_cache()
I, G, game, joueur = monde(serveur=True)
rs = game.m_FindFirstChild("ReplicatedStorage")
R = {}
tache(lambda: R.update(Config=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisConfig")]))))
Config = R["Config"]
CH = Config.get("Chemins")
chemin = lambda cle: [CH.get(cle).get(i) for i in range(1, CH.get(cle).longueur() + 1)] if CH.get(cle) else None
verifier("Config.Version = 6.9.10.1 ou plus récente", tuple(int(p) for p in str(Config.get("Version")).split(".") if p.isdigit()) >= (6, 9, 10, 1), Config.get("Version"))
verifier("Version à 4 nombres lue comme ≥ 6.9.10 (sim_v699, sim_v6910, release, état des tests)", tuple(int(n) for n in Config.get("Version").split(".")) >= (6, 9, 10))
verifier("3. Config.Chemins.Alerte = Console › Datapanel › Redbutton › Button", chemin("Alerte") == ["Console", "Datapanel", "Redbutton", "Button"], chemin("Alerte"))
verifier("4. Config.Chemins.VolLibre = Console › Selecteur › Colors", chemin("VolLibre") == ["Console", "Selecteur", "Colors"], chemin("VolLibre"))
verifier("6. Config.Chemins.EcranIngenieur = Console › Ecran-Ingenieure", chemin("EcranIngenieur") == ["Console", "Ecran-Ingenieure"])
verifier("7. Config.Chemins.Casier = Console › Casier", chemin("Casier") == ["Console", "Casier"])
verifier("8. Config.Chemins.JukeBox = Console › JukeBox (casse respectée)", chemin("JukeBox") == ["Console", "JukeBox"])
verifier("2. Config.Chemins.Ecran gardé (diagnostic)", chemin("Ecran") == ["Console", "Ecran"])
FAC = Config.get("CheminsFacultatifs")
verifier("Relecture 8. VolLibre, Casier, JukeBox et EcranIngenieur facultatifs pour le diagnostic", FAC and FAC.get("VolLibre") and FAC.get("Casier") and FAC.get("JukeBox") and FAC.get("EcranIngenieur"))
SEC = Config.get("CheminsSecours")
verifier("Relecture 7. Ancien emplacement de l'alerte gardé en secours (Config.CheminsSecours.Alerte)", SEC and [SEC.get("Alerte").get(i) for i in range(1, 5)] == ["Console", "Circuit", "Cloister", "Switch"])
INV = Config.get("InvitesConsole")
verifier("Relecture 9. Config.InvitesConsole : touche Z (ni E, ni une touche du vol libre), manette DPadRight", INV and (INV.get("Touche"), INV.get("Manette")) == ("Z", "DPadRight"))
cfgsrc = lire("ReplicatedStorage/TardisConfig.lua")
def bloc(debut, fin="\n}"):
    i = cfgsrc.index(debut); return cfgsrc[i:cfgsrc.index(fin, i)]
blocs = [bloc("Config.Ecrans = {"), bloc("Config.EcranIngenieur = {"), bloc("Config.JukeboxConsole = {"), bloc("Config.BoutonVolLibre = {"), bloc("Config.NeonsSalle = {"), bloc("Config.InvitesConsole = {")]
nouvelles = [l for b in blocs for l in b.splitlines()[1:] if re.match(r"\s*\w+ = ", l) and "(V6.9.10.3)" not in l and "(V6.9.10.4)" not in l and "(V6.9.10.5)" not in l and "(V6.9.10.8)" not in l]  # V6.9.10.8 : invites remises sur leur commande (sim_v69108) ; V6.9.10.3 : réglages des écrans ajoutés depuis (sim_v69103) ; V6.9.10.5 : hauteur des invites (sim_v69105)
nouvelles += [l for l in cfgsrc.splitlines() if re.match(r"\s*(Alerte|VolLibre|EcranIngenieur|Casier|JukeBox) = \{ \"Console\"", l) or l.startswith("Config.CheminsFacultatifs") or l.startswith("Config.CheminsSecours")]
verifier("Chaque nouveau réglage est marqué « (V6.9.10.1) »", len(nouvelles) == 24 and all("(V6.9.10.1)" in l for l in nouvelles),
         (len(nouvelles), [l for l in nouvelles if "(V6.9.10.1)" not in l][:3]))
NE = Config.get("NeonsSalle")
verifier("Config.NeonsSalle : actif, force 0,5, réduite × 0,5, secours rouge 0,6", NE and (NE.get("Actif"), NE.get("Force"), NE.get("ForceReduite"), NE.get("ForceSecours")) == (True, 0.5, 0.5, 0.6))
salle = Instance("Model", "Salle")
pieces = console_reelle(salle)
f = lambda nom, *a: premier(appeler(Config.get(nom), list(a)))
R2 = {}
tache(lambda: R2.update(a=f("trouverCommande", salle, "VolLibre"), b=f("trouverCommande", salle, "Inconnu"), c=f("partDe", f("trouverCommande", salle, "Casier")),
                        d=f("trouverCommande", Instance("Model", "Vide"), "JukeBox", 5)))
verifier("Config.trouverCommande : trouve Colors, nil pour une clé inconnue ou une pièce absente (sans bloquer)", R2["a"] is pieces["colors"] and R2["b"] is None and R2["d"] is None)
verifier("Config.partDe : la première pièce d'un Model (casier)", R2["c"] is pieces["casier"].enfants[0])


# ================================================================== 2. TardisEffets : néons de la salle (1)
roblox.ERREURS.clear(); vider_cache()
I, G, game, joueur = monde(serveur=False)
rs = game.m_FindFirstChild("ReplicatedStorage"); ws = game.m_FindFirstChild("Workspace")
Lighting = game.m_FindFirstChild("Lighting"); RunService = game.m_FindFirstChild("RunService")
tache(lambda: R.update(Config=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisConfig")])), UI=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisUI")]))))
Config, UI = R["Config"], R["UI"]
Lighting.props.update({"ClockTime": 12, "ExposureCompensation": 0, "Ambient": Couleur(0.5, 0.5, 0.5), "OutdoorAmbient": Couleur(0.5, 0.5, 0.5)})
camera = Instance("Camera", "Camera", ws); camera.props["CFrame"] = Valeur("CFrame"); ws.props["CurrentCamera"] = camera
ws.props["Terrain"] = Instance("Terrain", "Terrain")
Instance("PlayerGui", "PlayerGui", joueur)
t1 = Instance("Folder", "TARDIS_1", Instance("Folder", "TARDIS", ws))
x = Instance("Model", "Cabine", Instance("Folder", "EXTERIEURE", t1))
interieur = Instance("Model", "Salle", Instance("Folder", "INTERIEURE", t1))
racine = Instance("Part", "Racine", x); racine.props["Transparency"] = 1; x.props["PrimaryPart"] = racine
lampe = Instance("Part", "Lampe", x); Instance("PointLight", "PointLight", lampe)
Instance("Folder", "Boucliers", x)
Instance("ObjectValue", "TracteurCible", x).props["Value"] = None
x.attrs.update({"Etat": "Pose", "DebutEtat": 1000.0, "Mode": "Normal"})
NEON = lambda: Valeur("Enum.Material.Neon")
def neon(nom, parent, couleur):
    p = Instance("Part", nom, parent); p.props.update({"Material": NEON(), "Color": couleur}); return p
rotor = neon("Rotor", interieur, Couleur(1, 1, 1)); interieur.props["PrimaryPart"] = rotor
anneau = neon("Anneau", rotor, Couleur(1, 1, 1))
pieces = console_reelle(interieur)
blanc, orange = Couleur(1, 1, 1), Couleur(1, 0.5, 0)
neon1 = neon("Neon1", interieur, blanc)
deco = Instance("Model", "Deco", interieur); neon2 = neon("Bande", deco, orange)
mur = Instance("Part", "Mur", interieur); mur.props["Color"] = Couleur(0.3, 0.3, 0.3)
MUR_RGB = mur.props["Color"].rgb255()
ws.extra["Raycast"] = Fonction("Raycast", py=lambda *a: None)
leds = Instance("Folder", "LedsAlerte", interieur); led = neon("Led", leds, Couleur(0, 1, 0))
for e in pieces["ecrans"]: e.props.update({"Material": NEON(), "Color": Couleur(0, 0, 1)})
pieces["ingenieur"].props.update({"Material": NEON(), "Color": Couleur(0, 0, 1)})
cadreIng = neon("Cadre", pieces["ingenieur"], Couleur(0, 0, 1))
ignorer = Instance("Folder", "IgnorerVue", interieur); neonIgnore = neon("Lueur", ignorer, blanc)
ecritures = {"n": 0}
for p in (neon1, neon2):
    p.m_GetPropertyChangedSignal("Color").connecter(Fonction("compte", py=lambda: ecritures.__setitem__("n", ecritures["n"] + 1) or []))
def image(dt=0.1, n=1):
    for _ in range(n):
        H.avancer(dt)
        for nom in ("RenderStepped", "Heartbeat"):
            sig = RunService.extra.get(nom)
            if sig: sig.declencher(dt)
def etat(nom, mode="Normal"):
    x.m_SetAttribute("Mode", mode); x.m_SetAttribute("DebutEtat", maintenant()); x.m_SetAttribute("Etat", nom)
def rgb(p): return p.props["Color"].rgb255()
def proche(a, b, tol=3): return all(abs(u - v) <= tol for u, v in zip(a, b))
def melange(base, cible, k): return tuple(round((b + (c - b) * k) * 255) for b, c in zip((base.r, base.g, base.b), (cible.r, cible.g, cible.b)))
G["script"] = Instance("LocalScript", "TardisEffets", game.m_FindFirstChild("StarterPlayer"))
tache(lambda: I.executer(lire("StarterPlayer/StarterPlayerScripts/TardisEffets.client.lua"), "TardisEffets"))
verifier("TardisEffets se charge (salle avec néons, rotor, LedsAlerte, écrans)", not roblox.ERREURS, roblox.ERREURS[:3])
CS = Config.get("CouleursSalle")
image(0.1, 80)
verifier("1. Posé : les néons tirent vers le bleu (50 %)", proche(rgb(neon1), melange(blanc, CS.get("Pose"), 0.5)) and proche(rgb(neon2), melange(orange, CS.get("Pose"), 0.5)), (rgb(neon1), rgb(neon2)))
intacts = lambda: rgb(rotor) == (255, 255, 255) and rgb(anneau) == (255, 255, 255) and rgb(led) == (0, 255, 0) and all(rgb(e) == (0, 0, 255) for e in pieces["ecrans"] + [pieces["ingenieur"], cadreIng]) and rgb(mur) == MUR_RGB
verifier("1. Rotor (et ses néons), LedsAlerte, écrans (et leur contenu), pièces non néon : jamais touchés", intacts(), (rgb(rotor), rgb(led), [rgb(e) for e in pieces["ecrans"]]))
verifier("1. Le dossier IgnorerVue n'est pas exclu par défaut (réglage ExclureIgnorerVue)", rgb(neonIgnore) != (255, 255, 255))
n0 = ecritures["n"]; image(0.1, 30)
verifier("1. Couleur atteinte : plus aucune écriture (repeint seulement quand la couleur change)", ecritures["n"] == n0, ecritures["n"] - n0)
etat("Remat"); image(0.1, 40)
verifier("1. Remat : ambre", proche(rgb(neon1), melange(blanc, CS.get("Voyage"), 0.5)), rgb(neon1))
verifier("1. Pendant le voyage, le rotor garde la couleur du mode (pas l'ambre de la salle)", rgb(anneau) != melange(blanc, CS.get("Voyage"), 0.5))
etat("Vol"); image(0.1, 50)
verifier("1. Dans le vortex : cyan", proche(rgb(neon1), melange(blanc, CS.get("Vortex"), 0.5)), rgb(neon1))
x.m_SetAttribute("Alerte", True); image(0.1, 50)
verifier("1. Alerte : rouge", proche(rgb(neon1), melange(blanc, CS.get("Alerte"), 0.5)), rgb(neon1))
x.m_SetAttribute("Alerte", None); etat("Pose"); image(0.1, 60)
# « aucun flash » : jamais de saut brusque (une image de 0,1 s change la couleur de moins de 4 %)
UI.get("prefs").set("sansFlash", True)
x.m_SetAttribute("Alerte", True)
sauts = []
for _ in range(40):
    avant = rgb(neon1); image(0.1); apres = rgb(neon1)
    sauts.append(max(abs(a - b) for a, b in zip(avant, apres)))
verifier("1. « Aucun flash » : changement lent, pas de battement (moins de 10/255 par image)", max(sauts) < 10 and sauts[-1] <= sauts[0] + 1, max(sauts))
UI.get("prefs").set("sansFlash", False); x.m_SetAttribute("Alerte", None); image(0.1, 80)
UI.get("prefs").set("effetsReduits", True); image(0.1, 80)
verifier("1. « Réduire les effets » : force moitié (25 %)", proche(rgb(neon1), melange(blanc, CS.get("Pose"), 0.25)), rgb(neon1))
UI.get("prefs").set("effetsReduits", False); image(0.1, 80)
x.m_SetAttribute("Alimentation", False); image(0.1, 80)
verifier("1. Hors tension : rouge de secours fixe (60 %)", proche(rgb(neon1), melange(blanc, Couleur(1, 40 / 255, 40 / 255), 0.6)), rgb(neon1))
a1 = rgb(neon1); image(0.1, 5)
verifier("1. Hors tension : pas de battement", rgb(neon1) == a1)
x.m_SetAttribute("Alimentation", None); image(0.1, 80)
# Le serveur change lui-même la couleur d'un néon (alerte sans dossier LedsAlerte, style de la console) : nouvelle origine
neon1.__lua_setindex__("Color", Couleur(0.2, 0.8, 0.2))
image(0.1, 80)
verifier("1. Couleur changée par le serveur : c'est la nouvelle couleur d'origine (puis teintée de bleu)", proche(rgb(neon1), melange(Couleur(0.2, 0.8, 0.2), CS.get("Pose"), 0.5)), rgb(neon1))
neon1.__lua_setindex__("Color", blanc); image(0.1, 80)
# L'effet retombe : Pose = false → couleur d'origine EXACTE
CS.set("Pose", False); image(0.1, 100)
verifier("1. L'effet retombe : chaque néon retrouve EXACTEMENT sa couleur d'origine", neon1.props["Color"] == blanc and neon2.props["Color"] == orange, (rgb(neon1), rgb(neon2)))
n0 = ecritures["n"]; image(0.1, 30)
verifier("1. … et n'est plus repeint ensuite", ecritures["n"] == n0)
verifier("1. Rotor, LedsAlerte et écrans toujours intacts", intacts())
# Relecture 5 : un dossier LedsAlerte qui arrive après le chargement (Streaming, ajout en jeu) protège aussi ses néons
leds.set_parent(None)
nouvelles_leds = Instance("Folder", "LedsAlerte", interieur); led2 = neon("Led2", nouvelles_leds, Couleur(0, 1, 0))
neon3 = neon("Neon3", interieur, blanc)
CS.set("Pose", Couleur(120 / 255, 170 / 255, 1, [120, 170, 255]))
x.m_SetAttribute("Alimentation", False); image(0.1, 2); x.m_SetAttribute("Alimentation", None); image(0.1, 100)  # le courant revient : nouveaux néons cherchés
verifier("Relecture 5. Dossier LedsAlerte arrivé après le chargement : ses néons ne sont pas recolorés (les autres si)",
         rgb(led2) == (0, 255, 0) and proche(rgb(neon3), melange(blanc, CS.get("Pose"), 0.5)), (rgb(led2), rgb(neon3)))
CS.set("Pose", False); image(0.1, 100)
eff = lire("StarterPlayer/StarterPlayerScripts/TardisEffets.client.lua")
verifier("1. Pas de nouvelle boucle par image (3 RenderStepped et 1 Heartbeat dans TardisEffets, comme avant)", eff.count("RunService.RenderStepped:Connect") == 3 and eff.count("RunService.Heartbeat:Connect") == 1)
verifier("Relecture 5. LedsAlerte cherché à chaque fois (pas une seule fois au chargement)", "local dossierLedsNeons = interieur:FindFirstChild" in eff[eff.index("local function neonExclu"):eff.index("local function enregistrerNeon")])
verifier("1. Branché sur la boucle des lumières de la salle", 'lisserNeons(dt, horsTension, cibleCouleurSalle)' in eff and eff.index("lisserNeons(dt, horsTension, cibleCouleurSalle) --") > eff.index('proteger("lumieres"'))
verifier("1. Les lumières sont gardées (sans danger)", "lumieresSalle[objet] = infos" in eff)
verifier("TardisEffets : aucun effet en erreur", not roblox.ERREURS and not [l for l in roblox.SORTIE if "en erreur" in l], roblox.ERREURS[:2])


# ================================================================== 3. Serveur : module Ecrans (2 et 6)
roblox.ERREURS.clear(); vider_cache()
I, G, game, pilote = monde(serveur=True)
rs = game.m_FindFirstChild("ReplicatedStorage"); ws = game.m_FindFirstChild("Workspace"); Players = game.m_FindFirstChild("Players")
tache(lambda: R.update(Config=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisConfig")]))))
Config = R["Config"]; E = Config.get("Etats")
canal = Instance("RemoteEvent", "TardisCommande_TARDIS_1", rs)
pilote.attrs["TardisPilote_TARDIS_1"] = True
tech = Instance("Player", "Techno", Players); tech.props.update({"UserId": 10829137819, "DisplayName": "Techno"})  # technicien de Config.Techniciens
techAttr = Instance("Player", "Ctat", Players); techAttr.props.update({"UserId": 303, "DisplayName": "Ctat"}); techAttr.attrs["TardisTechnicien_TARDIS_1"] = True
visiteur = Instance("Player", "Amy", Players); visiteur.props.update({"UserId": 202, "DisplayName": "Amy"})
DEST = {"nom": "Site-19"}
def charger_ecrans(ecrans="deux"):
    xs = Instance("Model", "Cabine"); salle = Instance("Model", "Salle")
    p = console_reelle(salle, ecrans)
    xs.attrs.update({"Etat": "Pose", "Mode": "Normal", "Alimentation": True, "PointsDeVie": 80, "PV": 8000, "PVMax": 10000,
                     "RegulEnergie": 80, "RegulAir": 100, "RegulVapeur": 50, "BouclierEnergie": 100})
    ctx = Table({"Config": Config, "E": E, "Players": Players, "def": Config.get("Tardis").get(1), "exterieur": xs, "interieur": salle, "remote": canal,
                 "destinationChoisie": Fonction("destinationChoisie", py=lambda: [Instance("Part", DEST["nom"])] if DEST["nom"] else [None, 0]),
                 "etatActuel": Fonction("etatActuel", py=lambda: xs.attrs.get("Etat") or "Pose")})
    res = {}
    tache(lambda: res.update(m=premier(appeler(premier(I.executer(lire("ServerScriptService/TardisServeur/Ecrans.lua"), "Ecrans")), [ctx]))))
    H.avancer(0.05)
    return xs, salle, p, res.get("m")
xs, salle, P, Ec = charger_ecrans("deux")
verifier("2. Module Ecrans chargé (Console avec deux pièces « Ecran »)", Ec is not None and not roblox.ERREURS, roblox.ERREURS[:3])
guis = [enfant_classe(e, "SurfaceGui", "TardisEcranDestination") for e in P["ecrans"]]
verifier("2. Un affichage fait en script sur CHAQUE pièce « Ecran » (deux)", all(len(g) == 1 for g in guis), [len(g) for g in guis])
g1, g2 = guis[0][0], guis[1][0]
verifier("2. Face : Front par défaut, « Back » avec l'attribut FaceEcran", g1.props["Face"].nom == "Enum.NormalId.Front" and g2.props["Face"].nom == "Enum.NormalId.Back", (g1.props["Face"], g2.props["Face"]))
def champ(g, nom):
    for e in descendants(g):
        if e.Name == nom: return e
champs = lambda nom: [champ(g, nom) for g in (g1, g2)]
verifier("2. Destination, état et mode affichés sur les deux écrans", all(texte_de(d) == "SITE-19" for d in champs("Destination"))
         and all(texte_de(e) == "●  POSÉ" for e in champs("Etat")) and all(texte_de(m) == "MODE : CLASSIQUE" for m in champs("Mode")),
         [texte_de(d) for d in champs("Destination") + champs("Etat") + champs("Mode")])
# (V6.9.10.7 : jetons fixes de la charte, UI.JETONS : destination jaune #F2C230, fond des écrans #050B14)
verifier("2. Couleurs de la charte (UI.JETONS) : destination jaune, fond d'écran bleu nuit", champ(g1, "Destination").props["TextColor3"].rgb255() == (242, 194, 48) and champ(g1, "Fond").props["BackgroundColor3"].rgb255() == (5, 11, 20))
verifier("2. Statuts : « SYSTÈMES NOMINAUX »", texte_de(champ(g1, "Statuts")) == "SYSTÈMES NOMINAUX")
DEST["nom"] = "Zone-Tsade"; tache(lambda: appeler(Ec.get("majEcran"), []))
verifier("2. Changement de destination (majEcran) : les deux écrans suivent", all(texte_de(d) == "ZONE-TSADE" for d in champs("Destination")))
xs.m_SetAttribute("Alerte", True); H.avancer(0.01)
verifier("2. Alerte : mise à jour tout de suite (sans boucle), statut rouge « ALERTE »", all("ALERTE" in texte_de(s) and s.props["TextColor3"].rgb255() == (255, 77, 106) for s in champs("Statuts")), [texte_de(s) for s in champs("Statuts")])
for a in ("DemarrageBloque", "Camouflage", "Retreci"): xs.m_SetAttribute(a, True)
H.avancer(0.01)
st = texte_de(champ(g2, "Statuts"))
verifier("2. Démarrage bloqué, camouflé, rétréci affichés", all(m in st for m in ("DÉMARRAGE BLOQUÉ", "CAMOUFLÉ", "RÉTRÉCI")), st)
for a in ("Alerte", "DemarrageBloque", "Camouflage", "Retreci"): xs.m_SetAttribute(a, None)
xs.m_SetAttribute("Mode", "Urgence"); xs.m_SetAttribute("Etat", "Demat"); H.avancer(0.01)
verifier("2. Mode du voyage : « MODE : URGENCE », état « DÉMATÉRIALISATION »", texte_de(champ(g1, "Mode")) == "MODE : URGENCE" and texte_de(champ(g1, "Etat")) == "●  DÉMATÉRIALISATION", (texte_de(champ(g1, "Mode")), texte_de(champ(g1, "Etat"))))
xs.m_SetAttribute("Mode", "Normal"); xs.m_SetAttribute("Etat", "Pose"); xs.m_SetAttribute("VolLibre", 101); H.avancer(0.01)
verifier("2. Vol libre : « VOL LIBRE »", texte_de(champ(g1, "Etat")) == "●  VOL LIBRE" and texte_de(champ(g1, "Mode")) == "MODE : VOL LIBRE")
xs.m_SetAttribute("VolLibre", None); H.avancer(0.01)
tache(lambda: appeler(Ec.get("majEcran"), ["PAS POSÉ"]))
verifier("2. Message court de la console (alerter) sur les deux écrans", all(b.props["Visible"] is True for b in champs("Bandeau")) and all(texte_de(m) == "PAS POSÉ" for m in champs("Message")))
tache(lambda: appeler(Ec.get("majEcran"), []))
verifier("2. … puis l'affichage normal revient (majEcran())", all(b.props["Visible"] is False for b in champs("Bandeau")))
xs.m_SetAttribute("Alimentation", False); H.avancer(0.01)
verifier("2. Hors tension : les deux écrans s'éteignent (fond noir, « HORS TENSION » discret)", all(champ(g, "Veille").props["Visible"] is True and champ(g, "Veille").props["BackgroundColor3"].rgb255() == (0, 0, 0)
         and texte_de(champ(champ(g, "Veille"), "Texte")) == "HORS TENSION" for g in (g1, g2)))
xs.m_SetAttribute("Alimentation", True); H.avancer(0.01)
verifier("2. Courant rétabli : affichage normal", all(champ(g, "Veille").props["Visible"] is False for g in (g1, g2)))
xs.m_SetAttribute("Detruit", True); H.avancer(0.01)
verifier("2. TARDIS détruit : affichage d'alerte", all(champ(g, "Detruit").props["Visible"] is True for g in (g1, g2)) and "DÉTRUIT" in texte_de(champ(champ(g1, "Detruit"), "Titre")))
xs.m_SetAttribute("Detruit", None); H.avancer(0.01)
P["ecrans"][0].m_SetAttribute("FaceEcran", "Left")
verifier("2. FaceEcran changé en jeu : la face suit", g1.props["Face"].nom == "Enum.NormalId.Left", g1.props["Face"])
verifier("2. La bande du bas est gardée pour la ligne vivante de chaque joueur", champ(g1, "LigneVivante") is not None)
# Un Model « Ecran » contenant deux pièces (et un cadre « Aucune »)
xs2, salle2, P2, Ec2 = charger_ecrans("modele")
gm = [enfant_classe(e, "SurfaceGui", "TardisEcranDestination") for e in P2["ecrans"]]
verifier("2. Model « Ecran » : un affichage sur chacune de ses pièces", all(len(g) == 1 for g in gm), [len(g) for g in gm])
verifier("2. Model « Ecran » : face du Model (Back), de la pièce (« top » → Top), « Aucune » = rien d'affiché",
         gm[0][0].props["Face"].nom == "Enum.NormalId.Back" and gm[1][0].props["Face"].nom == "Enum.NormalId.Top" and gm[2][0].props.get("Enabled") is False
         and gm[0][0].props.get("Enabled") is True, [(g[0].props["Face"], g[0].props.get("Enabled")) for g in gm])
verifier("2. Pas d'affichage de destination sur l'écran ingénieur", not enfant_classe(P["ingenieur"], "SurfaceGui", "TardisEcranDestination"))
verifier("2. Pas de boucle côté serveur (ni while, ni Heartbeat, ni RenderStepped dans Ecrans)", all(m not in lire("ServerScriptService/TardisServeur/Ecrans.lua") for m in ("while true", "task.wait(", "Heartbeat", "RenderStepped", "Stepped")))
serveur = lire("ServerScriptService/TardisServeur/init.server.lua")
verifier("2. TardisServeur : l'ancien écran unique (guiEcran, texte) remplacé par le module Ecrans", "guiEcran" not in serveur and "local texte = Instance.new" not in serveur
         and 'require(script:WaitForChild("Ecrans"))' in serveur and "local majEcran = Ecrans.majEcran" in serveur)

# ------------------------------------------------------------------ 6. Écran ingénieur
gi = enfant_classe(P["ingenieur"], "SurfaceGui", "TardisEcranIngenieur")
verifier("6. Écran ingénieur fait en script sur Console › Ecran-Ingenieure", len(gi) == 1, len(gi))
gi = gi[0]
val = lambda cle: texte_de(champ(gi, "Valeur_" + cle))
coul = lambda cle: champ(gi, "Valeur_" + cle).props["TextColor3"].rgb255()
# (V6.9.10.7 : jauges à 10 segments au lieu des barres ; couleurs de la charte, UI.JETONS)
allumes = lambda cle: champ(gi, "Jauge_" + cle).attrs.get("Allumes")
ROUGE, VERT, AMBRE, CYAN = (255, 77, 106), (124, 255, 178), (242, 194, 48), (91, 224, 255)
verifier("6. PV, énergie, air, vapeur, bouclier affichés (jauges à segments et pourcentages)", val("integrite") == "80 %  ·  8000 PV" and val("energie") == "80 %" and val("air") == "100 %"
         and val("vapeur") == "50 %" and val("bouclier") == "INACTIFS  ·  100 %" and allumes("integrite") == 8, [val(c) for c in ("integrite", "energie", "air", "vapeur", "bouclier")])
H.avancer(0.3)  # rien en attente
xs.m_SetAttribute("PointsDeVie", 15); xs.m_SetAttribute("PV", 1500); H.avancer(0.05)
verifier("6. Mises à jour regroupées (au plus 10 par seconde) : pas encore redessiné après 0,05 s", val("integrite") == "80 %  ·  8000 PV")
H.avancer(0.1)
verifier("6. PV bas : rouge, mis à jour en direct", val("integrite") == "15 %  ·  1500 PV" and coul("integrite") == ROUGE, (val("integrite"), coul("integrite")))
xs.m_SetAttribute("RegulEnergie", 95); xs.m_SetAttribute("RegulAir", 20); xs.m_SetAttribute("VapeurSurcharge", 2); H.avancer(0.2)
verifier("6. Régulation : surtension rouge, air vicié rouge, fuite de vapeur", "SURTENSION" in val("energie") and coul("energie") == ROUGE and "VICIÉ" in val("air") and coul("air") == ROUGE and val("vapeur") == "FUITE")
xs.m_SetAttribute("BouclierBalles", True); xs.m_SetAttribute("BouclierEnergie", 30); H.avancer(0.2)
verifier("6. Bouclier anti-balles à 30 % (jaune)", val("bouclier") == "ANTI-BALLES  ·  30 %" and coul("bouclier") == AMBRE, (val("bouclier"), coul("bouclier")))
xs.m_SetAttribute("BouclierBalles", False); xs.m_SetAttribute("BouclierEnergie", 0); H.avancer(0.2)
verifier("6. Boucliers tombés : « TOMBÉS », rouge", val("bouclier") == "TOMBÉS  ·  0 %" and coul("bouclier") == ROUGE)
xs.m_SetAttribute("BouclierComplet", True); xs.m_SetAttribute("BouclierEnergie", 90); xs.m_SetAttribute("PointsDeVie", 100); xs.m_SetAttribute("PV", 10000)
xs.m_SetAttribute("RegulEnergie", 60); xs.m_SetAttribute("RegulAir", 70); xs.m_SetAttribute("VapeurSurcharge", None); H.avancer(0.2)
# (V6.9.10.7 : chaque système à sa couleur de la charte : intégrité verte, énergie cyan, air jaune)
verifier("6. Tout redevient normal (intégrité verte, énergie cyan, air jaune)", coul("integrite") == VERT and coul("energie") == CYAN and coul("air") == AMBRE and val("bouclier") == "COMPLET  ·  90 %")
xs.m_SetAttribute("Alimentation", False); H.avancer(0.2)
verifier("6. Hors tension : l'écran ingénieur s'éteint aussi", champ(gi, "Veille").props["Visible"] is True)
xs.m_SetAttribute("Alimentation", True); H.avancer(0.2)
# Clic sans bouton : ClickDetector et invite
clic = enfant_classe(P["ingenieur"], "ClickDetector"); invite = enfant_classe(P["ingenieur"], "ProximityPrompt")
verifier("6. Clic sur l'écran (ClickDetector) et invite (mobile, manette)", len(clic) == 1 and len(invite) == 1 and invite[0].props["HoldDuration"] == 0)
verifier("Relecture 9. Invite de l'écran ingénieur : touche Z (pas E, qui cacherait Selecteur, levier, alerte)", invite[0].props["KeyboardKeyCode"].nom == "Enum.KeyCode.Z"
         and invite[0].props["GamepadKeyCode"].nom == "Enum.KeyCode.DPadRight", invite[0].props.get("KeyboardKeyCode"))
envoisC = lambda: canal.extra.get("envoisClient", [])
def cliquer_ecran(qui, par="clic"):
    n = len(envoisC())
    if par == "clic": declencher(clic[0], "MouseClick", qui)
    else: declencher(invite[0], "Triggered", qui)
    H.avancer(0.6)
    return envoisC()[n:]
r_ = cliquer_ecran(pilote)
verifier("6. Clic d'un pilote : le menu de gestion de l'énergie s'ouvre (« __energie »)", r_ == [[pilote, "__energie", P["ingenieur"]]], r_)
r_ = cliquer_ecran(tech, "invite")
verifier("6. Invite d'un technicien de Config.Techniciens : menu ouvert", r_ and r_[0][1] == "__energie", r_)
r_ = cliquer_ecran(techAttr)
verifier("6. Technicien C.T.A.T. (attribut TardisTechnicien_TARDIS_1) : menu ouvert", r_ and r_[0][1] == "__energie", r_)
r_ = cliquer_ecran(visiteur)
verifier("6. Clic d'un joueur sans droit : « Réservé aux pilotes et aux ingénieurs », rien d'autre", r_ == [[visiteur, "__console", "Réservé aux pilotes et aux ingénieurs.", False]], r_)
visiteur.m_SetAttribute("TardisPilote_TARDIS_1", False)
r_ = cliquer_ecran(visiteur)
verifier("6. (pilote d'un AUTRE TARDIS ou attribut faux : toujours refusé)", r_ and r_[0][1] == "__console")
n = len(envoisC()); declencher(clic[0], "MouseClick", pilote); declencher(clic[0], "MouseClick", pilote); H.avancer(0.01)
verifier("6. Deux clics rapprochés : un seul envoi (0,5 s entre deux)", len(envoisC()) - n == 1, len(envoisC()) - n)
H.avancer(0.6)
xs.m_SetAttribute("Alimentation", False)
r_ = cliquer_ecran(pilote)
verifier("6. Hors tension : écran éteint, pas de menu", r_ and r_[0][1] == "__console" and "hors tension" in r_[0][2], r_)
xs.m_SetAttribute("Alimentation", True); H.avancer(0.2)
verifier("Serveur (Ecrans) : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])
# Relecture 1 : la vraie coupure de courant de TardisServeur (memoriserEclairage, appliquerEclairage) ne doit pas éteindre
# les SurfaceGui des écrans (sinon le voile « HORS TENSION », AVARIE et les refus ne s'affichent jamais)
serveur = lire("ServerScriptService/TardisServeur/init.server.lua")
bloc_ecl = serveur[serveur.index("local function estAlimente()"):serveur.index("local function reglerAlimentation(allumer)")]
affiche = Instance("SurfaceGui", "Affiche", Instance("Part", "Panneau", salle)); affiche.props["Enabled"] = True
code_ecl = "local exterieur, interieur, Config = ...\nlocal function preparerSon() return nil end\nlocal partRotor = nil\n" + bloc_ecl + "\nreturn appliquerEclairage\n"
tache(lambda: R.update(ecl=premier(I.executer(code_ecl, "eclairage-serveur", (xs, salle, Config)))))
xs.m_SetAttribute("Alimentation", False); tache(lambda: appeler(R["ecl"], [])); H.avancer(0.2)
verifier("Relecture 1. Coupure de courant (vrai appliquerEclairage) : les SurfaceGui des écrans restent allumés, voile « HORS TENSION » visible",
         g1.props.get("Enabled") is True and gi.props.get("Enabled") is True and champ(g1, "Veille").props["Visible"] is True and champ(gi, "Veille").props["Visible"] is True,
         (g1.props.get("Enabled"), gi.props.get("Enabled")))
verifier("Relecture 1. … les autres SurfaceGui de la salle s'éteignent toujours", affiche.props.get("Enabled") is False)
tache(lambda: appeler(Ec.get("majEcran"), ["HORS TENSION"]))
xs.m_SetAttribute("Alimentation", True); tache(lambda: appeler(R["ecl"], [])); H.avancer(0.2)
tache(lambda: appeler(Ec.get("majEcran"), ["ALIMENTATION RÉTABLIE"]))
verifier("Relecture 1. Courant rétabli : écrans allumés, message de la console affiché", g1.props.get("Enabled") is True and texte_de(champ(g1, "Message")) == "ALIMENTATION RÉTABLIE"
         and champ(g1, "Bandeau").props["Visible"] is True and affiche.props.get("Enabled") is True)
tache(lambda: appeler(Ec.get("majEcran"), []))
xs.m_SetAttribute("Avarie", True); xs.m_SetAttribute("PointsDeVie", 0); H.avancer(0.2)
verifier("Relecture 1. AVARIE affichée sur l'écran ingénieur", val("integrite") == "AVARIE  ·  0 %" and coul("integrite") == ROUGE, val("integrite"))
xs.m_SetAttribute("Avarie", None); xs.m_SetAttribute("PointsDeVie", 100); H.avancer(0.2)
ECRAN_SERVEUR = P["ecrans"][0]  # repris par le client (11)


# ================================================================== 4. Serveur : bouton Vol libre (Colors) et vrai gestionnaire des ordres
vider_cache()
xv = Instance("Model", "Cabine"); xv.attrs.update({"Etat": "Pose", "Mode": "Normal"})
rv = Instance("Part", "Racine", xv); rv.props["Size"] = V3(4, 9, 4); xv.props["PrimaryPart"] = rv
salleV = Instance("Model", "Salle"); PV_ = console_reelle(salleV)
partage = Table({"occupe": False})
stub = lambda nom, r=None: Fonction(nom, py=lambda *a: [] if r is None else [r])
ctxv = Table({"Config": Config, "E": E, "Players": Players, "exterieur": xv, "interieur": salleV, "partage": partage, "echelleNormale": 1, "hauteurNormale": 9,
              "chercherSol": Fonction("chercherSol", py=lambda *a: V3(0, 5, 0)), "dansInterieur": Fonction("dansInterieur", py=lambda *a: False),
              "emmenerALInterieur": stub("emmener"), "etatActuel": Fonction("etat", py=lambda: xv.attrs.get("Etat")), "fermerPortes": Fonction("fermerPortes", py=lambda: True),
              "jouer": stub("jouer"), "majEcran": stub("majEcran"), "majRamassage": stub("majRamassage"), "memoriserDepart": stub("memoriserDepart"),
              "setCollisionsExterieur": stub("collisions"), "tropPetitPourLesPortes": Fonction("petit", py=lambda *a: False), "verifierEau": stub("eau"),
              "jouerVoyage": stub("jouerVoyage"), "modeAutorise": Fonction("modeAutorise", py=lambda m, p=None: m)})
tache(lambda: R.update(V=premier(appeler(premier(I.executer(lire("ServerScriptService/TardisServeur/VolLibre.lua"), "VolLibre")), [ctxv]))))
V = R["V"]
canalV = Instance("RemoteEvent", "TardisCommande_TARDIS_1", Instance("Folder", "ReplicatedStorageVol"))
ALERTES = []
debut = serveur.index("local ACTIONS_AILLEURS = {}")
fin_ = serveur.index("Players.PlayerRemoving:Connect(function(joueur)\n\tdernierOrdre[joueur] = nil")
en_part = serveur[serveur.index("local function enPart(objet, exclu)"):serveur.index("-- Le Selecteur garde son prompt")]
creer_prompt = serveur[serveur.index("local function creerPrompt("):serveur.index("local dernierUsage = 0")]
prelude = """
local remote, exterieur, interieur, Config, E, V, pilotes, alerter = ...
local Players = game:GetService("Players")
local volLibre, reglagesVol = V.volLibre, V.reglagesVol
local recevoirPositionVol, changerPhaseVol, basculerPortesEnVol, lancerGlisse = V.recevoirPositionVol, V.changerPhaseVol, V.basculerPortesEnVol, V.lancerGlisse
local teleAtterrir, lancerDescente, freinerVol, demarrerVolLibre = V.teleAtterrir, V.lancerDescente, V.freinerVol, V.demarrerVolLibre
local function poserTardis() end
local function setCamouflage() end
local function marquerActivite() end
local function journal() end
local function etatActuel() return exterieur:GetAttribute("Etat") or E.Pose end
local dernierOrdre = {}
local ACTIONS_COPILOTE = { Demat = true, Remat = true, Camouflage = true, NavAtterrir = true }
"""
code = prelude + en_part + creer_prompt + serveur[debut:fin_] + "\nreturn { enPart = enPart, traiterOrdre = traiterOrdre }\n"
PILOTES = Table({pilote: True})
tache(lambda: R.update(S=premier(I.executer(code, "ordres-serveur", (canalV, xv, salleV, Config, E, V, PILOTES, Fonction("alerter", py=lambda m: ALERTES.append(m) or []))))))
S = R.get("S")
H.avancer(0.1)
verifier("4. Vrai gestionnaire des ordres (traiterOrdre) et bloc du bouton Vol libre chargés", S is not None and not roblox.ERREURS, roblox.ERREURS[:3])
tache(lambda: R.update(sel=premier(appeler(S.get("enPart"), [PV_["selecteur"], PV_["colors"]]))))
verifier("4. Le Selecteur garde son prompt sur une autre pièce que Colors", R["sel"] is PV_["selecteur"].enfants[0], R["sel"] and R["sel"].Name)
pv_ = [e for e in descendants(PV_["colors"]) if e.ClassName == "ProximityPrompt"]; cv_ = enfant_classe(PV_["colors"], "ClickDetector")  # V6.9.10.5 : invite sur un point d'attache
verifier("4. Colors : une invite « Vol libre » (touche F, pas E) et un clic", len(pv_) == 1 and len(cv_) == 1 and pv_[0].props["ActionText"] == "Vol libre"
         and pv_[0].props["KeyboardKeyCode"].nom == "Enum.KeyCode.F", pv_ and pv_[0].props)
verifier("4. L'invite est active TARDIS posé", pv_[0].props.get("Enabled") is True)
verifier("4. Réponses au client par le canal du TARDIS (TardisCommande_TARDIS_1)", len(canalV.__lua_index__("OnServerEvent").connexions) == 1)
declencher(cv_[0], "MouseClick", visiteur); H.avancer(0.1)
verifier("4. Clic d'un non-pilote : rien (pas de vol libre, pas de message)", xv.attrs.get("VolLibre") is None and not ALERTES and not canalV.extra.get("envoisClient"))
xv.m_SetAttribute("Maintenance", "Révision des systèmes")
declencher(pv_[0], "Triggered", pilote); H.avancer(0.1)
verifier("4. En maintenance : refusé comme VolLibreDebut (message, écran « EN MAINTENANCE »)", xv.attrs.get("VolLibre") is None and ALERTES == ["EN MAINTENANCE"]
         and "maintenance" in canalV.extra["envoisClient"][-1][1], (ALERTES, canalV.extra.get("envoisClient")))
xv.m_SetAttribute("Maintenance", None); H.avancer(1.1)
declencher(cv_[0], "MouseClick", pilote); H.avancer(0.2)
verifier("4. Clic d'un pilote : vol libre lancé pour LUI (même fonction que VolLibreDebut)", xv.attrs.get("VolLibre") == 101 and partage.get("occupe") is True, dict(xv.attrs).get("VolLibre"))
verifier("4. … avec la réponse habituelle", canalV.extra["envoisClient"][-1] == [pilote, "Vol libre activé : à toi de piloter !", True], canalV.extra["envoisClient"][-1])
verifier("4. L'invite disparaît pendant le vol libre", pv_[0].props.get("Enabled") is False)
H.avancer(1.1); declencher(cv_[0], "MouseClick", pilote); H.avancer(0.2)
verifier("4. Clic pendant le vol : refus de demarrerVolLibre affiché sur les écrans", ALERTES[-1] == "DÉJÀ EN VOL LIBRE", ALERTES)
n = len(ALERTES); H.avancer(0.3); declencher(cv_[0], "MouseClick", pilote); H.avancer(0.1)
verifier("4. Même délai entre deux ordres que la tablette (Config.Cooldown), « PATIENTEZ » sur les écrans", ALERTES[n:] == ["PATIENTEZ"], ALERTES[n:])
tache(lambda: appeler(V.get("lancerDescente"), ["Douce", False])); H.avancer(15)
verifier("4. Fin du vol : l'invite revient", xv.attrs.get("VolLibre") is None and pv_[0].props.get("Enabled") is True, (xv.attrs.get("VolLibre"), pv_[0].props.get("Enabled")))
canalV.__lua_index__("OnServerEvent").declencher(visiteur, "VolLibreDebut"); H.avancer(0.1)
verifier("4. (contrôle) VolLibreDebut d'un non-pilote par le réseau : refusé aussi", xv.attrs.get("VolLibre") is None)
# (Roblox n'envoie pas de fonction par un RemoteEvent : un client ne peut glisser qu'une valeur, ignorée)
n = len(ALERTES); H.avancer(1.1)
canalV.__lua_index__("OnServerEvent").declencher(pilote, "VolLibreDebut", None, Table({"rappel": True})); H.avancer(0.2)
verifier("4. Un 4e argument venu d'un client (pas une fonction) est ignoré : seul le serveur passe un rappel",
         len(ALERTES) == n and not roblox.ERREURS and "if typeof(rappel) ~= \"function\" then rappel = nil end" in serveur, (ALERTES[n:], roblox.ERREURS[:1]))
tache(lambda: appeler(V.get("lancerDescente"), ["Douce", False])); H.avancer(15)
# Relecture 7 : le vrai brancherCommande, sans bloquer, avec l'ancien emplacement de l'alerte en secours
bloc_bc = serveur[serveur.index("local function brancherCommande("):serveur.index("-- Alimentation : Controls")]
def brancher_alerte(salle_):
    roblox.SORTIE.clear()
    xa = Instance("Model", "Cabine"); xa.attrs["Alerte"] = False
    code_bc = ("local Config, interieur, exterieur, pilotes, alerter, enPart = ...\n" + creer_prompt +
               "local function marquerActivite() end\nlocal function disponible() return true end\n" + bloc_bc +
               "\nbrancherCommande(\"Alerte\", \"Lever l'alerte\", \"Déclencher l'alerte\", \"Alerte\", true, function() exterieur:SetAttribute(\"Alerte\", not exterieur:GetAttribute(\"Alerte\")) return true end, \"ALERTE GÉNÉRALE\", \"FIN DE L'ALERTE\")\n")
    tache(lambda: I.executer(code_bc, "brancher-serveur", (Config, salle_, xa, PILOTES, Fonction("alerter", py=lambda m: ALERTES.append(m) or []), S.get("enPart"))))
    H.avancer(0.1)
    return xa, list(roblox.SORTIE)
salleN = Instance("Model", "Salle"); PN = console_reelle(salleN)
xa, sortie = brancher_alerte(salleN)
bn = PN["console"].m_FindFirstChild("Datapanel").m_FindFirstChild("Redbutton").m_FindFirstChild("Button")
invites_de = lambda o: [e for e in descendants(o) if e.ClassName == "ProximityPrompt"]  # V6.9.10.5 : invites sur un point d'attache
verifier("Relecture 7. Nouveau chemin : invite sur Datapanel › Redbutton › Button", invites_de(bn) and not [l for l in sortie if "introuvable" in l], sortie)
salleA = Instance("Model", "Salle"); PA = console_reelle(salleA); PA["console"].m_FindFirstChild("Datapanel").set_parent(None)
ciA = Instance("Model", "Circuit", PA["console"]); clA = Instance("Model", "Cloister", ciA); sw = Instance("Part", "Switch", clA)
xa, sortie = brancher_alerte(salleA)
pa_sw = invites_de(sw)
verifier("Relecture 7. Place pas encore mise à jour : l'ancien Circuit › Cloister › Switch répond, avec un avertissement", pa_sw and [l for l in sortie if "ancien emplacement utilisé" in l], sortie)
n = len(ALERTES); declencher(pa_sw[0], "Triggered", pilote); H.avancer(0.1)
verifier("Relecture 7. … et déclenche bien l'alerte", xa.attrs.get("Alerte") is True and ALERTES[n:] == ["ALERTE GÉNÉRALE"], ALERTES[n:])
salleB = Instance("Model", "Salle"); PB = console_reelle(salleB); PB["console"].m_FindFirstChild("Datapanel").set_parent(None)
xa, sortie = brancher_alerte(salleB)
verifier("Relecture 7. Ni l'un ni l'autre : avertissement clair, sans erreur ni blocage", [l for l in sortie if "introuvable : ni Console › Datapanel › Redbutton › Button ni Console › Circuit › Cloister › Switch" in l]
         and not roblox.ERREURS, (sortie, roblox.ERREURS[:1]))
verifier("Relecture 7. brancherCommande n'attend plus sans fin (Config.Trouver remplacé)", "Config.Trouver(interieur, cle)" not in bloc_bc and "Config.trouverCommande(interieur, cle, 10)" in bloc_bc)
# Relecture 4 : les actions traitées ailleurs (Tech, Jukebox, Tenue, Theme…) ne consomment plus le délai des ordres
H.avancer(1.1)
for action, donnees in (("Tech", Table({"commande": "Reguler", "systeme": "Air", "valeur": 50})), ("Jukebox", Table({})), ("Tenue", Table({"index": 1})), ("Theme", Table({"nom": "Nuit"}))):
    canalV.__lua_index__("OnServerEvent").declencher(pilote, action, donnees)
n = len(ALERTES); declencher(cv_[0], "MouseClick", pilote); H.avancer(0.2)
verifier("Relecture 4. Tech, Jukebox, Tenue, Theme juste avant : le bouton Vol libre part quand même (pas de délai consommé)", xv.attrs.get("VolLibre") == 101 and ALERTES[n:] == [], (xv.attrs.get("VolLibre"), ALERTES[n:]))
ailleurs = serveur[serveur.index("local ACTIONS_AILLEURS = {}"):serveur.index("local function traiterOrdre")]
gerees_serveur = set(re.findall(r'action == "(\w+)"', serveur[serveur.index("local function traiterOrdre"):serveur.index("remote.OnServerEvent:Connect(traiterOrdre)")]))
autres = set(re.findall(r'action == "(\w+)"', lire("ServerScriptService/TardisExtras.server.lua"))) | set(re.findall(r'action == "(\w+)"', lire("ServerScriptService/TardisSystemes.server.lua")))
bloquees = set(re.findall(r"(\w+) = true", cfgsrc[cfgsrc.index("Bloquees = {"):cfgsrc.index("}", cfgsrc.index("Bloquees = {"))]))
attendues = autres - gerees_serveur - bloquees
listees = set(re.findall(r'"(\w+)"', ailleurs))
verifier("Relecture 4. La liste couvre toutes les actions de TardisExtras et TardisSystemes sans voyage (les bloquées en maintenance gardent leur message)",
         attendues == listees, (sorted(attendues - listees), sorted(listees - attendues)))
tache(lambda: appeler(V.get("lancerDescente"), ["Douce", False])); H.avancer(15)
verifier("Serveur (ordres) : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])


# ================================================================== 5. TardisDiagnostic : nouveaux chemins
md = Instance("ModuleScript", "TardisDiagnostic", game.m_FindFirstChild("ServerScriptService")); md.extra["chemin"] = DEPOT + "/ServerScriptService/TardisDiagnostic.lua"
xd = Instance("Model", "Cabine"); xd.props["PrimaryPart"] = Instance("Part", "Racine", xd); Instance("Part", "Portail", xd); Instance("Model", "TARDISDoors", xd); Instance("Part", "Lampe", xd)
sd = Instance("Model", "Salle"); Instance("Part", "Portail", sd); Instance("Part", "Rotor", sd)
PD = console_reelle(sd)
def diag():
    roblox.SORTIE.clear()
    tache(lambda: R.update(ligne=premier(appeler(premier(appeler(G["require"], [md])), [Config.get("Tardis").get(1), xd, sd]))))
    return R.get("ligne") or "", [l for l in roblox.SORTIE if "OBLIGATOIRES" in l]
ligne, alertes = diag()
m = re.search(r"obligatoires (\d+)/(\d+)", ligne)
verifier("5. Diagnostic : tous les chemins trouvés (Alerte › Datapanel › Redbutton › Button, VolLibre › Selecteur › Colors)", m and m.group(1) == m.group(2) and not alertes, (ligne[:160], alertes))
PD["colors"].set_parent(None); PD["ingenieur"].set_parent(None); PD["jukebox"].set_parent(None)
ligne, alertes = diag()
verifier("Relecture 8. Sans Colors : « commande VolLibre » dans les optionnelles absentes, pas dans les obligatoires", not alertes and "commande VolLibre (Console > Selecteur > Colors)" in ligne, (alertes, ligne[-250:]))
verifier("5. Sans écran ingénieur ni jukebox : rangés dans les optionnelles absentes, pas dans les obligatoires",
         "commande EcranIngenieur" in ligne and "commande JukeBox" in ligne and not alertes, (ligne[-200:], alertes))
verifier("5. L'ancien chemin de l'alerte n'est plus demandé", "Circuit" not in ligne and "Circuit" not in "".join(alertes))
dp_ = PD["console"].m_FindFirstChild("Datapanel"); dp_.set_parent(None)
ligne, alertes = diag()
verifier("Relecture 7. Sans Datapanel : alerte signalée parmi les obligatoires", alertes and "commande Alerte (Console > Datapanel > Redbutton > Button)" in alertes[0], alertes)
ci = Instance("Model", "Circuit", PD["console"]); cl = Instance("Model", "Cloister", ci); Instance("Part", "Switch", cl)
ligne, alertes = diag()
verifier("Relecture 7. Ancien emplacement Circuit › Cloister › Switch encore en place : accepté par le diagnostic", not alertes, alertes)


# ================================================================== 6. Interphone supprimé
traces = []
for d, _, fs in os.walk(DEPOT):
    for f_ in fs:
        if f_.endswith(".lua") and "nterphone" in open(os.path.join(d, f_), encoding="utf-8").read().lower():
            traces.append(f_)
verifier("5. Plus aucune trace d'« Interphone » dans le code (actions, attribut, interface, menus)", not traces, traces)
verifier("5. Intercom du site intact (en pause, pas supprimé)", "-- Config.Intercom = {" in lire("ReplicatedStorage/TardisConfig.lua") and os.path.exists(os.path.join(DEPOT, "ServerScriptService/TardisPontFondation.server.lua")))
extras = lire("ServerScriptService/TardisExtras.server.lua")
dx = extras.index("remote.OnServerEvent:Connect(function(joueur, action, donnees)")
fx = extras.index("\nend)\n", dx) + 6
canalX = Instance("RemoteEvent", "TardisCommande_TARDIS_1", Instance("Folder", "RSExtras"))
xx = Instance("Model", "Cabine"); xx.attrs.update({"Etat": "Pose"})
DITS = []
prelude_x = """
local remote, exterieur, interieur, Config, pilotes, DITS = ...
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local E = Config.Etats
local function estPilote(joueur) return pilotes[joueur] == true end
local function dire(joueur, message, ok) table.insert(DITS, { joueur, message, ok ~= false }) end
local dernier, dedans, invitations, dernierCarnet = {}, {}, {}, {}
"""
jb = extras.index("do\n\tlocal derniersJukebox = {}")
fjb = extras.index("\nend\n", jb) + 5
salleX = Instance("Model", "Salle"); PX = console_reelle(salleX)
code_x = prelude_x + extras[jb:fjb] + extras[dx:fx]
DITS = Table()
tache(lambda: I.executer(code_x, "extras-serveur", (canalX, xx, salleX, Config, PILOTES, DITS)))
# (dire écrit dans une table Lua : on relit les réponses par remote ou par les attributs)
H.avancer(0.1)
verifier("Vrai gestionnaire de TardisExtras et bloc du jukebox de la console chargés", len(canalX.__lua_index__("OnServerEvent").connexions) == 1 and not roblox.ERREURS, roblox.ERREURS[:3])
envX = lambda qui, *a: (canalX.__lua_index__("OnServerEvent").declencher(qui, *a), H.avancer(0.6))
envX(visiteur, "Interphone", Table({"texte": "Bonjour"})); envX(pilote, "Interphone", Table({"texte": "Bonjour"}))
verifier("5. Action « Interphone » (pilote ou non) : ignorée par le serveur, aucun attribut", "Interphone" not in xx.attrs and not roblox.ERREURS, (dict(xx.attrs), roblox.ERREURS[:2]))


# ================================================================== 9. Jukebox de la console (serveur)
pj = [e for e in descendants(PX["jukebox"]) if e.ClassName == "ProximityPrompt"]; cj = enfant_classe(PX["jukebox"], "ClickDetector")  # V6.9.10.5 : invite sur un point d'attache
verifier("8. Console › JukeBox : invite « Musique » et clic", len(pj) == 1 and len(cj) == 1 and pj[0].props["ActionText"] == "Musique")
verifier("Relecture 9. Invite du jukebox : touche Z", pj[0].props["KeyboardKeyCode"].nom == "Enum.KeyCode.Z")
n = len(canalX.extra.get("envoisClient", []))
declencher(cj[0], "MouseClick", pilote); H.avancer(0.1)
declencher(pj[0], "Triggered", visiteur); H.avancer(0.6)
r_ = canalX.extra.get("envoisClient", [])[n:]
verifier("8. Pilote : le panneau s'ouvre (« __jukebox ») ; non-pilote : « Réservé aux pilotes. »", r_ == [[pilote, "__jukebox", PX["jukebox"]], [visiteur, "__console", "Réservé aux pilotes.", False]], r_)
Config.set("Jukebox", Table({1: Table({"nom": "Thème", "id": 111, "categorie": "Action"}), 2: Table({"nom": "Vortex", "id": 222, "categorie": "Action"}), 3: Table({"nom": "Calme", "id": 333})}))
envX(pilote, "Jukebox", Table({"index": 3}))
verifier("8. Action Jukebox (piste) appliquée pour un pilote", xx.attrs.get("Jukebox") == 3, xx.attrs.get("Jukebox"))
envX(pilote, "Jukebox", Table({"liste": "Action"}))
verifier("8. Action Jukebox (playlist) appliquée", xx.attrs.get("Jukebox") == "Action")
envX(visiteur, "Jukebox", Table({}))
verifier("8. Action Jukebox d'un non-pilote : refusée (la musique continue)", xx.attrs.get("Jukebox") == "Action")
envX(pilote, "Jukebox", Table({}))
verifier("8. « Arrêter la musique » (pilote) : arrêtée", xx.attrs.get("Jukebox") is None)
verifier("Serveur (TardisExtras) : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])


# ================================================================== 7. Régulation : vrai TardisSystemes
sysrc = lire("ServerScriptService/TardisSystemes.server.lua")
canalS = Instance("RemoteEvent", "TardisCommande_TARDIS_1", Instance("Folder", "RSSystemes"))
pont = Instance("BindableFunction", "TardisInterne_TARDIS_1")
pont.props["OnInvoke"] = Fonction("pont", py=lambda action, *a: [PILOTES.get(a[0]) is True] if action == "estPilote" else [None])
d_fn = sysrc[sysrc.index("local function interne(action, ...)"):sysrc.index("local function direAuxPilotes")]
d_tech = sysrc[sysrc.index("local TECH = Config.Technicien or {}"):sysrc.index("-- Usure de l'air")]
d_h = sysrc.index("remote.OnServerEvent:Connect(function(joueur, action, donnees)")
f_h = sysrc.index("\nend)\n", d_h) + 6
prelude_s = """
local remote, exterieur, interieur, Config, pont, def = ...
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local E = Config.Etats
local S = Config.Systemes or {}
local voyagesConsecutifs = 0
"""
code_s = prelude_s + d_fn + d_tech + sysrc[d_h:f_h]
tache(lambda: I.executer(code_s, "systemes-serveur", (canalS, xs, salle, Config, pont, Config.get("Tardis").get(1))))
verifier("7. Vrai code de la régulation (TardisSystemes) chargé, branché sur xs (écran ingénieur du 3)", len(canalS.__lua_index__("OnServerEvent").connexions) == 1 and not roblox.ERREURS, roblox.ERREURS[:3])
def reguler(qui, systeme, valeur):
    canalS.__lua_index__("OnServerEvent").declencher(qui, "Tech", Table({"commande": "Reguler", "systeme": systeme, "valeur": valeur})); H.avancer(0.3)
reguler(techAttr, "Energie", 40)
verifier("7. Technicien : la régulation change côté serveur (RegulEnergie 40)", xs.attrs.get("RegulEnergie") == 40, xs.attrs.get("RegulEnergie"))
reguler(pilote, "Air", 55)
verifier("7. Pilote : accepté (RegulAir 55)", xs.attrs.get("RegulAir") == 55)
reguler(visiteur, "Energie", 90)
verifier("7. Joueur sans droit : refusé", xs.attrs.get("RegulEnergie") == 40)
for mauvais in (150, -5, 100.5, "60", float("nan"), None, True):
    reguler(techAttr, "Energie", mauvais)
verifier("7. Hors bornes (150, −5, 100,5) et mauvais types (texte, NaN, rien, booléen) : refusés", xs.attrs.get("RegulEnergie") == 40, xs.attrs.get("RegulEnergie"))
reguler(techAttr, "Gravite", 50); reguler(techAttr, Table({}), 50)
verifier("7. Système inconnu : refusé", "RegulGravite" not in xs.attrs)
canalS.__lua_index__("OnServerEvent").declencher(techAttr, "Tech", Table({"commande": "Reguler", "systeme": "Vapeur", "valeur": 70}))
canalS.__lua_index__("OnServerEvent").declencher(techAttr, "Tech", Table({"commande": "Reguler", "systeme": "Vapeur", "valeur": 80})); H.avancer(0.3)
verifier("7. Fréquence : deux réglages à moins de 0,25 s → seul le premier passe", xs.attrs.get("RegulVapeur") == 70, xs.attrs.get("RegulVapeur"))
verifier("7. L'écran ingénieur suit la régulation en direct", val("energie") == "40 %" and val("air") == "55 %" and val("vapeur") == "70 %", (val("energie"), val("air"), val("vapeur")))
verifier("Serveur (TardisSystemes) : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])


# ================================================================== 8. Client, module Console : menu de l'énergie et panneau du jukebox
vider_cache()
Ic, Gc, gamec, moi = monde(serveur=False)
activer_maths(Gc)
rsc = gamec.m_FindFirstChild("ReplicatedStorage"); wsc = gamec.m_FindFirstChild("Workspace")
tache(lambda: R.update(Cc=premier(appeler(Gc["require"], [rsc.m_FindFirstChild("TardisConfig")])), UIc=premier(appeler(Gc["require"], [rsc.m_FindFirstChild("TardisUI")]))))
Cc, UIc = R["Cc"], R["UIc"]
moi.props.update({"UserId": 303, "DisplayName": "Ctat"})
pg = Instance("PlayerGui", "PlayerGui", moi)
uis = gamec.m_FindFirstChild("UserInputService")
uis.extra["InputBegan"] = Signal("InputBegan")
remoteC = Instance("RemoteEvent", "TardisCommande_TARDIS_1", rsc)
xc = Instance("Model", "Cabine"); xc.attrs.update({"Etat": "Pose", "PointsDeVie": 64, "PV": 6400, "Alimentation": True, "RegulEnergie": 80, "RegulAir": 100, "RegulVapeur": 50,
                                                    "BouclierJoueurs": True, "BouclierEnergie": 72})
salleC = Instance("Model", "Salle"); PC = console_reelle(salleC)
PC["ingenieur"].props["Position"] = Vec3(0, 0, 0); PC["jukebox"].props["Position"] = Vec3(4, 0, 0)
racineMoi = Instance("Part", "HumanoidRootPart"); racineMoi.props["Position"] = Vec3(0, 0, 5)
racineMoi.props["CFrame"] = CF((0, 0, 5))
def contexte_client(**plus):
    t = Table({"C": UIc.get("C"), "Config": Cc, "UI": UIc, "UserInputService": uis, "creer": UIc.get("creer"), "texte": UIc.get("texte"), "animer": UIc.get("animer"),
               "def": Cc.get("Tardis").get(1), "exterieur": xc, "interieur": salleC, "joueur": moi, "maRacine": Fonction("maRacine", py=lambda: racineMoi),
               "remote": remoteC, "camera": Instance("Camera", "Camera", wsc), "jeSuisDedans": Fonction("dedans", py=lambda: True)})
    for k, v in plus.items(): t.set(k, v)
    return t
def module_client(nom):
    res = {}
    tache(lambda: res.update(m=premier(appeler(premier(Ic.executer(lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/" + nom + ".lua"), nom)), [contexte_client()]))))
    return res.get("m")
CM = module_client("Console")
verifier("Module Console chargé (client)", CM is not None and not roblox.ERREURS, roblox.ERREURS[:3])
menu = pg.m_FindFirstChild("TardisMenuEnergie"); juke = pg.m_FindFirstChild("TardisJukeboxConsole"); msg = pg.m_FindFirstChild("TardisConsoleMessage")
recevoir = lambda *a: (remoteC.__lua_index__("OnClientEvent").declencher(*a), H.avancer(0.01))
def trouve(racine_, nom):
    for e in descendants(racine_):
        if e.Name == nom: return e
appuyer = lambda b: (b.extra.setdefault("Activated", Signal("Activated")).declencher(), H.avancer(0.01))
verifier("6. Menus fermés au départ", menu.props.get("Enabled") is False and juke.props.get("Enabled") is False)
recevoir("__energie", PC["ingenieur"])
verifier("6. « __energie » : le menu de gestion de l'énergie s'ouvre", menu.props.get("Enabled") is True)
jv = lambda cle: texte_de(trouve(trouve(menu, "Jauge_" + cle), "Valeur"))
jd = lambda cle: texte_de(trouve(trouve(menu, "Jauge_" + cle), "Detail"))  # (V6.9.10.7 : la valeur et son détail, comme la maquette)
verifier("6. Menu : PV, alimentation et boucliers", jv("integrite") == "64 %" and jd("integrite") == "6400 PV" and jv("alimentation") == "NOMINALE" and jv("bouclier") == "72 %"
         and jd("bouclier") == "ANTI-JOUEURS", (jv("integrite"), jd("integrite"), jv("alimentation"), jv("bouclier"), jd("bouclier")))
rv_ = lambda s_: texte_de(trouve(trouve(menu, "Regul_" + s_), "Valeur"))
verifier("6. Menu : les trois réglages de la régulation (énergie, air, vapeur)", (rv_("Energie"), rv_("Air"), rv_("Vapeur")) == ("80 %", "100 %", "50 %"))
plusE = trouve(trouve(menu, "Regul_Energie"), "Plus"); moinsV = trouve(trouve(menu, "Regul_Vapeur"), "Moins"); plusA = trouve(trouve(menu, "Regul_Air"), "Plus")
appuyer(plusE); appuyer(plusE); appuyer(moinsV); appuyer(plusA)
H.avancer(1)
tech_envois = [e for e in remoteC.extra.get("envois", []) if e[0] == "Tech"]
donnees = [(e[1].get("commande"), e[1].get("systeme"), e[1].get("valeur")) for e in tech_envois]
verifier("6. « + » deux fois sur l'énergie, « − » sur la vapeur : l'action EXISTANTE Tech / Reguler, dernière valeur, un envoi à la fois",
         donnees == [("Reguler", "Energie", 90), ("Reguler", "Vapeur", 45)], donnees)
verifier("6. « + » sur l'air à 100 % : rien d'envoyé (jamais au-delà des bornes)", rv_("Air") == "100 %" and all(d[1] != "Air" for d in donnees))
verifier("6. Affichage immédiat de la valeur demandée", rv_("Energie") == "90 %" and rv_("Vapeur") == "45 %")
# Rejoué sur le vrai serveur (TardisSystemes du 7) par un technicien : la régulation change, l'écran ingénieur suit
for e in tech_envois: canalS.__lua_index__("OnServerEvent").declencher(techAttr, *e); H.avancer(0.3)
H.avancer(0.2)
verifier("6. Réglage du menu rejoué sur le serveur (technicien) : la régulation change, l'écran ingénieur suit",
         xs.attrs.get("RegulEnergie") == 90 and xs.attrs.get("RegulVapeur") == 45 and val("energie") == "90 %", (xs.attrs.get("RegulEnergie"), xs.attrs.get("RegulVapeur"), val("energie")))
for e in tech_envois: canalS.__lua_index__("OnServerEvent").declencher(visiteur, "Tech", Table({"commande": "Reguler", "systeme": "Energie", "valeur": 10})); H.avancer(0.3)
verifier("6. … et le même envoi par un joueur sans droit : refusé", xs.attrs.get("RegulEnergie") == 90)
xc.m_SetAttribute("RegulEnergie", 90); xc.m_SetAttribute("PointsDeVie", 30); H.avancer(0.01)
verifier("6. Menu mis à jour en direct (attributs)", jv("integrite").startswith("30 %") and rv_("Energie") == "90 %")
# Relecture 2 : la valeur demandée n'est jamais affichée trop longtemps
plusA_ = trouve(trouve(menu, "Regul_Air"), "Plus"); moinsA = trouve(trouve(menu, "Regul_Air"), "Moins"); moinsE = trouve(trouve(menu, "Regul_Energie"), "Moins")
appuyer(plusE)
verifier("Relecture 2. « + » : la valeur demandée s'affiche tout de suite (95 %)", rv_("Energie") == "95 %")
H.avancer(1.6)
verifier("Relecture 2. Le serveur refuse (aucun changement) : retour à sa valeur au bout d'1 s", rv_("Energie") == "90 %", rv_("Energie"))
appuyer(plusE); appuyer(moinsE); H.avancer(1.6)
verifier("Relecture 2. « + » puis « − » rapides : la valeur du serveur", rv_("Energie") == "90 %", rv_("Energie"))
appuyer(moinsA); H.avancer(0.6)
xc.m_SetAttribute("RegulAir", 40); H.avancer(0.01)
verifier("Relecture 2. Réglé par un autre pendant l'attente (rien à envoyer) : sa valeur s'affiche", rv_("Air") == "40 %", rv_("Air"))
appuyer(plusE); recevoir("__energie", PC["ingenieur"])
verifier("Relecture 2. Chaque ouverture repart des valeurs du serveur", rv_("Energie") == "90 %", rv_("Energie"))
H.avancer(1.6)
uis.extra["InputBegan"].declencher(Table({"KeyCode": Valeur("Enum.KeyCode.Escape")}), False); H.avancer(0.01)
verifier("6. Échap : le menu se ferme", menu.props.get("Enabled") is False)
recevoir("__energie", PC["ingenieur"]); appuyer(trouve(menu, "Fermer"))
verifier("6. Bouton « Fermer » : fermé", menu.props.get("Enabled") is False)
recevoir("__energie", PC["ingenieur"]); H.avancer(0.6)
verifier("6. Près de l'écran : reste ouvert", menu.props.get("Enabled") is True)
racineMoi.props["Position"] = Vec3(0, 0, 30); H.avancer(0.6)
verifier("6. En s'éloignant (plus de 14 studs) : fermé", menu.props.get("Enabled") is False)
racineMoi.props["Position"] = Vec3(0, 0, 5)
# Relecture 6 : pièce pas encore chargée (Streaming) : la distance se mesure depuis l'endroit de l'ouverture
PC["ingenieur"].set_parent(None)
recevoir("__energie", None); H.avancer(0.6)
verifier("Relecture 6. Sans la pièce : le menu s'ouvre et reste ouvert sur place", menu.props.get("Enabled") is True)
racineMoi.props["Position"] = Vec3(0, 0, 30); H.avancer(0.6)
verifier("Relecture 6. Sans la pièce : il se ferme quand même en s'éloignant", menu.props.get("Enabled") is False)
racineMoi.props["Position"] = Vec3(0, 0, 5); PC["ingenieur"].set_parent(PC["console"])
recevoir("__console", "Réservé aux pilotes et aux ingénieurs.", False)
# (V6.9.10.7 : le message est une notification de la charte, cadre « MessageConsole »)
verifier("6. « __console » : le message s'affiche (« Réservé aux pilotes et aux ingénieurs »)", trouve(msg, "Texte") and "Réservé aux pilotes et aux ingénieurs." in texte_de(trouve(msg, "Texte"))
         and trouve(msg, "MessageConsole").props.get("Visible") is True and menu.props.get("Enabled") is False)
H.avancer(3.1)
verifier("6. Le message disparaît après 3 s", trouve(msg, "MessageConsole").props.get("Visible") is False)
# Jukebox
recevoir("__jukebox", PC["jukebox"])
liste = trouve(juke, "Liste")
verifier("8. « __jukebox » : panneau ouvert ; Config.Jukebox vide → le panneau le dit", juke.props.get("Enabled") is True and trouve(liste, "Vide") is not None and "vide" in texte_de(trouve(liste, "Vide")))
appuyer(trouve(juke, "Fermer"))
Cc.set("Jukebox", Table({1: Table({"nom": "Thème", "id": 111, "categorie": "Action"}), 2: Table({"nom": "Vortex", "id": 222, "categorie": "Action"}), 3: Table({"nom": "Calme", "id": 333})}))
recevoir("__jukebox", PC["jukebox"])
# (V6.9.10.7 : tableau N° | PISTE | DURÉE de la charte ; une ligne se choisit, JOUER la lance)
cel = lambda l, k: texte_de(trouve(l, "Cellule_" + k))
lignesJ = lambda nom: [e for e in trouve(juke, "Liste").enfants if e.Name == nom]
pl, pi = lignesJ("Playlist"), lignesJ("Piste")
verifier("8. Pistes et playlists de Config.Jukebox (mêmes données que la tablette), en tableau", len(pl) == 1 and len(pi) == 3 and cel(pl[0], "piste") == "PLAYLIST ACTION"
         and cel(pl[0], "detail") == "2 PISTES" and cel(pi[2], "piste") == "CALME", [(cel(e, "numero"), cel(e, "piste"), cel(e, "detail")) for e in pl + pi])
n = len(remoteC.extra.get("envois", []))
appuyer(pi[1]); appuyer(trouve(juke, "Jouer")); appuyer(lignesJ("Playlist")[0]); appuyer(trouve(juke, "Jouer")); appuyer(trouve(juke, "Arreter"))
j_ = [(e[0], dict(e[1].h)) for e in remoteC.extra["envois"][n:]]
verifier("8. Piste, playlist, arrêt : l'action EXISTANTE Jukebox ({index}, {liste}, {})", j_ == [("Jukebox", {"index": 2}), ("Jukebox", {"liste": "Action"}), ("Jukebox", {})], j_)
xc.m_SetAttribute("Jukebox", 2); H.avancer(0.01)
pi = lignesJ("Piste")
verifier("8. La piste qui joue est mise en évidence (ligne jaune de la charte)", pi[1].props["BackgroundTransparency"] == 0
         and pi[1].props["BackgroundColor3"].rgb255() == (242, 194, 48) and pi[1].attrs.get("Choisi") is True)
racineMoi.props["Position"] = Vec3(4, 0, 40); H.avancer(0.6)
verifier("8. En s'éloignant du jukebox : fermé", juke.props.get("Enabled") is False)
racineMoi.props["Position"] = Vec3(0, 0, 5)
recevoir("__jukebox", PC["jukebox"]); recevoir("__energie", PC["ingenieur"])
verifier("Un seul panneau à la fois", juke.props.get("Enabled") is False and menu.props.get("Enabled") is True)
appuyer(trouve(menu, "Fermer"))
verifier("Client (Console) : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])


copi = lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Copilote.lua")
h_ = copi[copi.index("remote.OnClientEvent:Connect(function(texteRecu, ok)"):]
verifier("Relecture 3. Poste du copilote : les messages techniques « __… » (__console…) ne s'affichent plus, après le cas __paradoxe",
         'if string.sub(texteRecu, 1, 2) == "__" then return end' in h_ and h_.index('"__paradoxe"') < h_.index('string.sub(texteRecu, 1, 2) == "__"') < h_.index("afficherMessage(texteRecu"))  # (V6.9.10.7 : notification de la charte)


# ================================================================== 10. Client, module Interactions : casier de la console
autreCasier = Instance("Part", "Casier", salleC)
IM = module_client("Interactions")
verifier("Module Interactions chargé (client)", IM is not None and IM.get("afficherInvitation") is not None and not roblox.ERREURS, roblox.ERREURS[:3])
porte = PC["casier"].enfants[0]
pc_ = [e for e in descendants(PC["casier"]) if e.ClassName == "ProximityPrompt"]; cc_ = enfant_classe(PC["casier"], "ClickDetector")  # V6.9.10.5 : invite au-dessus, clic sur tout le Model
verifier("7. Console › Casier (Model) trouvé : invite « Choisir une tenue » (appui court) et clic", len(pc_) == 1 and pc_[0].props["ActionText"] == "Choisir une tenue" and pc_[0].props["HoldDuration"] == 0 and len(cc_) == 1,
         [(e.props.get("ActionText"), e.props.get("HoldDuration")) for e in pc_])
verifier("Relecture 9. Invite du casier de la console : touche Z", pc_[0].props["KeyboardKeyCode"].nom == "Enum.KeyCode.Z")
pa_ = enfant_classe(autreCasier, "ProximityPrompt")
verifier("7. Les autres casiers de l'intérieur gardent « maintenir E 3 s »", len(pa_) == 1 and pa_[0].props["HoldDuration"] == 3 and pa_[0].props["ActionText"] == "Ouvrir le casier")
casierGui = pg.m_FindFirstChild("TardisCasier")
moi.props["Character"] = Instance("Model", "Ctat", wsc)
declencher(pc_[0], "Triggered"); H.avancer(0.01)
verifier("7. L'invite ouvre le même menu des tenues", casierGui.props.get("Enabled") is True)
uis.extra["InputBegan"].declencher(Table({"KeyCode": Valeur("Enum.KeyCode.Escape")}), False); H.avancer(0.01)
declencher(cc_[0], "MouseClick", moi); H.avancer(0.01)
verifier("7. Le clic aussi", casierGui.props.get("Enabled") is True)
uis.extra["InputBegan"].declencher(Table({"KeyCode": Valeur("Enum.KeyCode.Escape")}), False); H.avancer(0.01)
verifier("5. Plus d'interface d'interphone chez le joueur", pg.m_FindFirstChild("TardisInterphone") is None)
verifier("7. Règles des tenues inchangées (action Tenue, tout le monde à bord)", 'remote:FireServer("Tenue", { index = apercu })' in lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Interactions.lua")
         and 'if index and dedans[joueur] then appliquerTenue(joueur, math.floor(index)) end' in extras)
verifier("Client (Interactions) : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])


# ================================================================== 11. Client, module Ambiance : ligne vivante dans chaque écran de destination
ecranCopie = ECRAN_SERVEUR  # l'écran fait par le serveur (3), avec sa SurfaceGui
ancien = [e for e in PC["console"].enfants if e.Name == "Ecran"]
for e in ancien: e.set_parent(None)
ecranCopie.set_parent(PC["console"])
Lc = gamec.m_FindFirstChild("Lighting"); Lc.props.update({"ClockTime": 13.5, "ExposureCompensation": 0, "Ambient": Couleur(0.5, 0.5, 0.5), "OutdoorAmbient": Couleur(0.5, 0.5, 0.5)})
xc.props["Pivot"] = CF((12, 34, 56)); xc.props["PrimaryPart"] = Instance("Part", "Racine", xc)
Instance("Folder", "Sons", Instance("Folder", "TardisAssets", rsc))
ctxA = contexte_client(Lighting=Lc, Players=gamec.m_FindFirstChild("Players"), ReplicatedStorage=rsc, RunService=gamec.m_FindFirstChild("RunService"), E=Cc.get("Etats"),
                       boiteInt=CF((0, 1000, 0)), dansInterieur=Fonction("dansInterieur", py=lambda p: True), partTemporaire=Fonction("pt", py=lambda *a: Instance("Part", "Temp", wsc)))
res = {}
tache(lambda: res.update(m=premier(appeler(premier(Ic.executer(lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Ambiance.lua"), "Ambiance")), [ctxA]))))
H.avancer(1.2)
vivant = trouve(ecranCopie, "TardisVivant")
verifier("11. Ligne vivante (coordonnées, horloge) dans la bande du bas de l'écran du serveur", vivant is not None and vivant.parent.Name == "LigneVivante"
         and texte_de(vivant) == "X 12 · Y 34 · Z 56 · 13:30", vivant and texte_de(vivant))
sg = enfant_classe(ecranCopie, "SurfaceGui")[0]
verifier("11. Le reste de l'affichage du serveur n'est pas déformé (la destination garde sa place : 0,9 × 0,22 depuis la V6.9.10.3)", list(champ(sg, "Destination").props["Size"].args) == [0.9, 0.22], champ(sg, "Destination").props["Size"].args)
xc.m_SetAttribute("Alimentation", False); H.avancer(0.6)
verifier("11. Hors tension : la ligne vivante disparaît", vivant.props.get("Visible") is False)
verifier("Client (Ambiance) : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])

print("\n".join("  ✓ " + o for o in OK)); print("\n".join("  ✗ " + k for k in KO))
print(f"V6.9.10.1 : {len(OK)}/{len(OK) + len(KO)} vérifications réussies")
sys.exit(1 if KO else 0)
