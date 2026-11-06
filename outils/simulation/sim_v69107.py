"""Simulations de la V6.9.10.7 : la charte « Hologramme de confinement », deuxième passage (le vrai code).
  1. TardisConfig et TardisUI : nouveaux réglages marqués « (V6.9.10.7) » (badges du jukebox et du copilote), jeton du
     fond des écrans (#050B14), Titillium Web en gras pour le serveur (UI.FACE_GRAS).
  2. Le vrai module Console, menu de gestion de l'énergie : plus grand (440 px de large avant l'échelle, échelle qui
     suit l'écran), panneau de la charte, plaque GESTION DE L'ÉNERGIE (badge C.T.A.T., OBJ. TARDIS-01 · ÉCRAN INGÉNIEUR,
     bande rouge pendant l'alerte), ÉTAT et RÉGULATION en jauges à 10 segments (couleurs de la charte), − / + de 44 px
     qui envoient l'action EXISTANTE Tech / Reguler, fermeture (bouton, Échap, distance), « Réduire les effets ».
  3. Le panneau du jukebox : tableau N° | PISTE | CATÉGORIE (ou DURÉE quand toutes sont connues), playlists d'abord, la
     piste qui joue en jaune, ligne choisie, JOUER / PLAYLIST / ARRÊTER (l'action EXISTANTE Jukebox), volume en segments,
     liste vide expliquée ; le message de la console en notification (TARDIS / REFUSÉ).
  4. Le vrai module Interactions, casier : panneau à droite, plaque CASIER (badge : l'équipe), CHOISIR UNE TENUE, tuiles
     (la tenue essayée en jaune, favoris, tenue actuelle), ENFILER (action EXISTANTE Tenue), FERMER ; la caméra du casier
     (V6.9.10.5) toujours appelée et rendue exactement.
  5. Le vrai module TardisServeur › Ecrans : écrans de destination et écran ingénieur aux jetons fixes UI.JETONS (le
     serveur n'applique pas de thème), polices de la charte, jauges à segments, bande vivante (SurfaceGui › Fond ›
     LigneVivante gardée), voiles HORS TENSION et TARDIS DÉTRUIT.
  6. Les vrais modules Maintenance (bandeau en notification de la charte) et Copilote (panneau, plaque, messages en
     notification, tableau des destinations), sans erreur ; aucune nouvelle action réseau, aucune boucle de décor."""
import os, sys, re, json
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
def trouve(racine, nom):
    for e in descendants(racine):
        if e.Name == nom: return e
def tous(racine, nom): return [e for e in descendants(racine) if e.Name == nom]
def enfants(o, nom=None, classe=None): return [e for e in o.enfants if (nom is None or e.Name == nom) and (classe is None or e.ClassName == classe)]
def texte_de(o): return str(o.props.get("Text", "")) if o is not None else None
def rgb(c): return c.rgb255() if isinstance(c, Couleur) else None
def police(o): return o.props["Font"].nom.split(".")[-1] if o is not None and "Font" in o.props else None
def appuyer(b): b.extra.setdefault("Activated", Signal("Activated")).declencher(); H.avancer(0.01)
def declencher(objet, signal, *args): objet.extra.setdefault(signal, Signal(signal)).declencher(*args); H.avancer(0.01)
def appel(f, *a): return premier(appeler(f, list(a)))
def taille(o): return list(o.props["Size"].args)
JETONS = {"panneau": (10, 22, 38), "ligne": (31, 110, 140), "texte": (221, 246, 255), "discret": (134, 175, 195), "cyan": (91, 224, 255),
          "jaune": (242, 194, 48), "rouge": (255, 77, 106), "vert": (124, 255, 178), "sombre": (11, 11, 11)}
ECRAN = (5, 11, 20)
CONSOLE = "StarterPlayer/StarterPlayerScripts/TardisExtrasClient/"
def piece(nom, parent, pos=(0, 0, 0), taille_=(2, 2, 2)):
    p = Instance("Part", nom, parent)
    p.props.update({"CFrame": CF(pos), "Size": Vec3(*taille_), "Position": Vec3(*pos)})
    return p


def monde_client(viewport=(1920, 1080)):
    """Un joueur (pilote du TARDIS_1) avec le canal TardisCommande_TARDIS_1, une caméra, une cabine et une console
    (Ecran-Ingenieure, JukeBox, Casier en Model) ; TardisConfig et TardisUI chargés (thème Confinement)."""
    vider_cache(); roblox.ERREURS.clear()
    I, G, game, joueur = monde(serveur=False)
    activer_maths(G)
    rs = game.m_FindFirstChild("ReplicatedStorage"); ws = game.m_FindFirstChild("Workspace")
    remote = Instance("RemoteEvent", "TardisCommande_TARDIS_1", rs)
    R = {}
    tache(lambda: R.update(Config=appel(G["require"], rs.m_FindFirstChild("TardisConfig")), UI=appel(G["require"], rs.m_FindFirstChild("TardisUI"))))
    pg = Instance("PlayerGui", "PlayerGui", joueur)
    joueur.attrs["TardisPilote_TARDIS_1"] = True
    uis = game.m_FindFirstChild("UserInputService"); uis.extra["InputBegan"] = Signal("InputBegan")
    camera = Instance("Camera", "Camera", ws)
    camera.props.update({"CFrame": CF((0, 10, 14)), "CameraType": Valeur("Enum.CameraType.Custom"), "ViewportSize": Valeur("Vector2", list(viewport)), "CameraSubject": None})
    ws.props["CurrentCamera"] = camera
    ext = Instance("Model", "Cabine")
    ext.attrs.update({"Etat": "Pose", "Position": "Hall", "Mode": "Normal", "Alimentation": True, "Alerte": False, "PointsDeVie": 64, "PV": 6400,
                      "RegulEnergie": 80, "RegulAir": 100, "RegulVapeur": 50, "BouclierJoueurs": True, "BouclierEnergie": 72,
                      "ListeDestinations": "Hall\nLaboratoire"})
    salle = Instance("Model", "Salle", ws)
    console = Instance("Model", "Console", salle)
    ing = piece("Ecran-Ingenieure", console, (0, 3, -3), (3, 0.2, 2))
    juke = piece("JukeBox", console, (4, 2, 0), (1, 2, 1))
    casier = Instance("Model", "Casier", console)
    piece("Porte", casier, (-4, 3, 0), (2, 3, 0.2))
    racine = piece("HumanoidRootPart", Instance("Model", "Corps"), (0, 3, 2), (2, 2, 1))
    return dict(I=I, G=G, game=game, joueur=joueur, rs=rs, ws=ws, remote=remote, Config=R["Config"], UI=R["UI"], pg=pg, uis=uis, camera=camera,
                ext=ext, salle=salle, console=console, ing=ing, juke=juke, casier=casier, racine=racine)

def contexte(W, **plus):
    UI = W["UI"]
    t = Table({"C": UI.get("C"), "Config": W["Config"], "E": W["Config"].get("Etats"), "Players": W["game"].m_FindFirstChild("Players"), "UI": UI,
               "UserInputService": W["uis"], "animer": UI.get("animer"), "camera": W["camera"], "creer": UI.get("creer"), "texte": UI.get("texte"),
               "def": W["Config"].get("Tardis").get(1), "exterieur": W["ext"], "interieur": W["salle"], "joueur": W["joueur"],
               "maRacine": Fonction("maRacine", py=lambda: W["racine"]), "remote": W["remote"], "jeSuisDedans": Fonction("dedans", py=lambda: True)})
    for k, v in plus.items(): t.set(k, v)
    return t

def module(W, nom, ctx=None):
    res = {}
    tache(lambda: res.update(m=premier(appeler(premier(W["I"].executer(lire(CONSOLE + nom + ".lua"), nom)), [ctx or contexte(W)]))))
    H.avancer(0.05)
    return res.get("m")

def recevoir(W, *a): W["remote"].__lua_index__("OnClientEvent").declencher(*a); H.avancer(0.01)
def envois(W, n=0, action=None): return [e for e in W["remote"].extra.get("envois", [])[n:] if action is None or e[0] == action]
def echap(W): W["uis"].extra["InputBegan"].declencher(Table({"KeyCode": Valeur("Enum.KeyCode.Escape")}), False); H.avancer(0.01)
def segments_allumes(jauge):
    """(nombre allumé, couleurs des segments allumés) d'une jauge UI.jaugeSegments (cadre avec l'attribut Allumes)."""
    seg = sorted(tous(jauge, "Segment"), key=lambda s: s.props["LayoutOrder"])
    return jauge.attrs.get("Allumes"), {rgb(s.props["BackgroundColor3"]) for s in seg[:jauge.attrs.get("Allumes") or 0]}, len(seg)


# ================================================================== 1. TardisConfig et TardisUI
W = monde_client()
Config, UI = W["Config"], W["UI"]
verifier("TardisConfig et TardisUI se chargent chez un joueur (thème Confinement)", UI is not None and appel(UI.get("themeActuel")) == "Confinement" and not roblox.ERREURS, roblox.ERREURS[:3])
BA = Config.get("Interface").get("Badges")
verifier("1. Config.Interface.Badges.Jukebox = « PILOTE », Copilote = « COPILOTE » (les badges de la V6.9.10.6 gardés)",
         (BA.get("Jukebox"), BA.get("Copilote"), BA.get("Energie"), BA.get("Menu")) == ("PILOTE", "COPILOTE", "C.T.A.T.", "ACCÈS NIV. 3"))
cfg = lire("ReplicatedStorage/TardisConfig.lua")
nouvelles = [l for l in cfg.splitlines() if l.startswith("Config.Interface.Badges.")]
verifier("1. Chaque nouveau réglage est marqué « (V6.9.10.7) », juste avant « return Config »", len(nouvelles) == 2 and all("(V6.9.10.7)" in l for l in nouvelles)
         and cfg.rstrip().endswith("return Config") and cfg.index(nouvelles[-1]) > cfg.index("Config.Interface = {"), nouvelles)
JT = UI.get("JETONS")
verifier("1. Jeton du fond des écrans de la console : #050B14 ; les 9 couleurs de la charte inchangées",
         rgb(JT.get("ecran")) == ECRAN and all(rgb(JT.get(k)) == v for k, v in JETONS.items()))
fg = UI.get("FACE_GRAS")
verifier("1. UI.FACE_GRAS : Titillium Web en gras (pour les écrans faits par le serveur)", fg is not None and "TitilliumWeb" in str(fg.args[0]), fg and fg.args)


# ================================================================== 2. Menu de gestion de l'énergie (vrai module Console)
W = monde_client()
Config, UI, ext = W["Config"], W["UI"], W["ext"]
CM = module(W, "Console")
verifier("2. Module Console chargé (client, thème Confinement), sans erreur", CM is not None and not roblox.ERREURS, roblox.ERREURS[:3])
menu = W["pg"].m_FindFirstChild("TardisMenuEnergie")
carte = trouve(menu, "Carte")
verifier("2. Menu fermé au départ", menu.props.get("Enabled") is False)
recevoir(W, "__energie", W["ing"])
verifier("2. « __energie » : le menu s'ouvre", menu.props.get("Enabled") is True)
verifier("2. Plus grand : 440 × 612 px avant l'échelle (avant : 380 px de large)", taille(carte) == [440, 612] and carte.props["AnchorPoint"].args == [0.5, 0.5], taille(carte))
ech = enfants(carte, classe="UIScale")[0]
verifier("2. Échelle qui suit l'écran (1920 × 1080 : 1,15, plafond ; comme la tablette technicien)", abs(ech.props["Scale"] - 1.15) < 1e-9, ech.props["Scale"])
W["camera"].props["ViewportSize"] = Valeur("Vector2", [1024, 600]); W["camera"].m_GetPropertyChangedSignal("ViewportSize").declencher(); H.avancer(0.01)
verifier("2. Petite fenêtre (1024 × 600) : le menu rétrécit pour tenir (600 × 0,86 / 612)", abs(ech.props["Scale"] - 600 * 0.86 / 612) < 1e-9, ech.props["Scale"])
W["camera"].props["ViewportSize"] = Valeur("Vector2", [1920, 1080])
verifier("2. Panneau de la charte : fond #0A1626, filet cyan (Contour), coins coupés (deux traits en biais), lueur",
         rgb(carte.props["BackgroundColor3"]) == JETONS["panneau"] and rgb(enfants(carte, "Contour")[0].props["Color"]) == JETONS["cyan"]
         and len(enfants(carte, "Chanfrein")) == 2 and enfants(carte, "Lueur")[0].props["Visible"] is True)
pl_ = trouve(menu, "Plaque")
verifier("2. Plaque : « GESTION DE L'ÉNERGIE » (Michroma), badge « C.T.A.T. », « OBJ. TARDIS-01 · ÉCRAN INGÉNIEUR », bande de danger",
         texte_de(trouve(pl_, "Titre")) == "GESTION DE L'ÉNERGIE" and police(trouve(pl_, "Titre")) == "Michroma" and texte_de(trouve(pl_, "BadgePlaque")) == "C.T.A.T."
         and trouve(pl_, "BadgePlaque").props["Visible"] is True and texte_de(trouve(pl_, "SousLigne")) == "OBJ. TARDIS-01  ·  ÉCRAN INGÉNIEUR" and trouve(pl_, "BandeDanger") is not None,
         (texte_de(trouve(pl_, "Titre")), texte_de(trouve(pl_, "BadgePlaque")), texte_de(trouve(pl_, "SousLigne"))))
bandes = enfants(trouve(pl_, "BandeDanger"), "Bande")
ext.m_SetAttribute("Alerte", True)
verifier("2. Alerte : la bande de la plaque passe au rouge", all(rgb(b.props["BackgroundColor3"]) == JETONS["rouge"] for b in bandes))
ext.m_SetAttribute("Alerte", False)
verifier("2. Fin de l'alerte : cyan", all(rgb(b.props["BackgroundColor3"]) == JETONS["cyan"] for b in bandes))
etiquettes = [texte_de(e) for e in tous(menu, "Etiquette")]
verifier("2. Sections « ÉTAT » et « RÉGULATION » (étiquettes en police de données)", etiquettes == ["ÉTAT", "RÉGULATION"]
         and all(police(e) == "RobotoMono" for e in tous(menu, "Etiquette")), etiquettes)
J_ = lambda cle: trouve(menu, "Jauge_" + cle)
jv = lambda cle: texte_de(trouve(J_(cle), "Valeur")); jd = lambda cle: texte_de(trouve(J_(cle), "Detail"))
jc = lambda cle: rgb(trouve(J_(cle), "Valeur").props["TextColor3"])
verifier("2. ÉTAT : intégrité « 64 % » (vert) et « 6400 PV », alimentation « NOMINALE », boucliers « ANTI-JOUEURS » « 72 % »",
         (jv("integrite"), jd("integrite"), jc("integrite"), jv("alimentation"), jc("alimentation"), jd("bouclier"), jv("bouclier"))
         == ("64 %", "6400 PV", JETONS["vert"], "NOMINALE", JETONS["vert"], "ANTI-JOUEURS", "72 %"),
         (jv("integrite"), jd("integrite"), jc("integrite"), jv("alimentation"), jd("bouclier"), jv("bouclier")))
si, sb = segments_allumes(trouve(J_("integrite"), "Segments")), segments_allumes(trouve(J_("bouclier"), "Segments"))
verifier("2. Jauges à segments de l'ÉTAT : intégrité 64 % → 6 segments verts (16 px), boucliers 72 % → 7 segments (12 px), 10 chacune",
         si[0] == 6 and si[1] == {JETONS["vert"]} and si[2] == 10 and sb[0] == 7 and sb[2] == 10
         and taille(trouve(J_("integrite"), "Segments"))[3] == 16 and taille(trouve(J_("bouclier"), "Segments"))[3] == 12, (si, sb))
verifier("2. Pas de jauge pour l'alimentation", trouve(J_("alimentation"), "Segments") is None)
REG = lambda s: trouve(menu, "Regul_" + s)
rv = lambda s: texte_de(trouve(REG(s), "Valeur")); rc = lambda s: rgb(trouve(REG(s), "Valeur").props["TextColor3"])
rs_ = lambda s: segments_allumes(trouve(REG(s), "Segments"))
verifier("2. RÉGULATION : énergie 80 % cyan, air 100 % jaune, vapeur 50 % couleur du texte (valeurs et segments de 16 px)",
         (rv("Energie"), rc("Energie"), rv("Air"), rc("Air"), rv("Vapeur"), rc("Vapeur")) == ("80 %", JETONS["cyan"], "100 %", JETONS["jaune"], "50 %", JETONS["texte"])
         and rs_("Energie")[:2] == (8, {JETONS["cyan"]}) and rs_("Air")[:2] == (10, {JETONS["jaune"]}) and rs_("Vapeur")[:2] == (5, {JETONS["texte"]})
         and all(taille(trouve(REG(s), "Segments"))[3] == 16 for s in ("Energie", "Air", "Vapeur")), [(rv(s), rc(s), rs_(s)) for s in ("Energie", "Air", "Vapeur")])
noms_reg = [(texte_de(trouve(REG(s), "Nom")), texte_de(trouve(REG(s), "SousNom"))) for s in ("Energie", "Air", "Vapeur")]
verifier("2. Noms : ÉNERGIE (TENSION), AIR (RECYCLAGE), VAPEUR (REFROIDISSEMENT)", noms_reg == [("ÉNERGIE", "TENSION"), ("AIR", "RECYCLAGE"), ("VAPEUR", "REFROIDISSEMENT")], noms_reg)
bt = [trouve(REG(s), n) for s in ("Energie", "Air", "Vapeur") for n in ("Moins", "Plus")]
verifier("2. Boutons − / + à coins coupés de 44 × 44 px (cible tactile), variante secondaire",
         all(b.ClassName == "TextButton" and taille(b) == [44, 44] and b.attrs.get("Variante") == "secondaire" and len(enfants(b, "Chanfrein")) == 2 for b in bt)
         and [texte_de(b) for b in bt[:2]] == ["−", "+"], [(taille(b), b.attrs.get("Variante")) for b in bt])
fermer = trouve(menu, "Fermer")
verifier("2. « FERMER (ÉCHAP) » : bouton secondaire de 46 px", texte_de(fermer) == "FERMER (ÉCHAP)" and fermer.attrs.get("Variante") == "secondaire" and taille(fermer)[3] == 46)
aide = trouve(menu, "Aide")
verifier("2. Ligne d'aide de la maquette", aide is not None and texte_de(aide) == "Les réglages passent par la régulation, comme la tablette technicien." and police(aide) == "RobotoMono")
n = len(envois(W))
appuyer(trouve(REG("Energie"), "Plus"))
verifier("2. « + » sur l'énergie : 85 % affiché tout de suite, 9 segments", rv("Energie") == "85 %" and rs_("Energie")[0] == 9, (rv("Energie"), rs_("Energie")))
appuyer(trouve(REG("Air"), "Moins"))
H.avancer(1)
tech = [(e[1].get("commande"), e[1].get("systeme"), e[1].get("valeur")) for e in envois(W, n, "Tech")]
verifier("2. « + » énergie et « − » air : l'action EXISTANTE Tech / Reguler (Energie 85, Air 95), une à la fois", tech == [("Reguler", "Energie", 85), ("Reguler", "Air", 95)], tech)
H.avancer(1)
ext.m_SetAttribute("RegulAir", 20); ext.m_SetAttribute("RegulEnergie", 95); H.avancer(0.01)
verifier("2. Air vicié (20 %) et surtension (95 %) : valeurs et segments en rouge", rc("Air") == JETONS["rouge"] and rs_("Air")[1] == {JETONS["rouge"]}
         and rc("Energie") == JETONS["rouge"] and rs_("Energie")[:2] == (10, {JETONS["rouge"]}), (rc("Air"), rs_("Air"), rc("Energie"), rs_("Energie")))
ext.m_SetAttribute("PointsDeVie", 15); ext.m_SetAttribute("BouclierJoueurs", False); ext.m_SetAttribute("BouclierEnergie", 0); ext.m_SetAttribute("Alimentation", False); H.avancer(0.01)
verifier("2. En direct : intégrité 15 % rouge (2 segments), boucliers « TOMBÉS » rouges, alimentation « COUPÉE »",
         jv("integrite") == "15 %" and jc("integrite") == JETONS["rouge"] and segments_allumes(trouve(J_("integrite"), "Segments"))[0] == 2
         and jd("bouclier") == "TOMBÉS" and jc("bouclier") == JETONS["rouge"] and jv("alimentation") == "COUPÉE" and jc("alimentation") == JETONS["rouge"],
         (jv("integrite"), jd("bouclier"), jv("alimentation")))
ext.m_SetAttribute("BouclierEnergie", 100); ext.m_SetAttribute("Alimentation", True); H.avancer(0.01)
verifier("2. Boucliers inactifs : « INACTIFS », segments discrets (maquette)", jd("bouclier") == "INACTIFS" and segments_allumes(trouve(J_("bouclier"), "Segments"))[1] == {JETONS["discret"]})
echap(W)
verifier("2. Échap : le menu se ferme", menu.props.get("Enabled") is False)
recevoir(W, "__energie", W["ing"]); appuyer(fermer)
verifier("2. Bouton « FERMER (ÉCHAP) » : fermé", menu.props.get("Enabled") is False)
recevoir(W, "__energie", W["ing"]); H.avancer(0.6)
verifier("2. Près de l'écran : reste ouvert", menu.props.get("Enabled") is True)
W["racine"].props["Position"] = Vec3(0, 3, 40); H.avancer(0.6)
verifier("2. En s'éloignant (plus de 14 studs) : fermé", menu.props.get("Enabled") is False)
W["racine"].props["Position"] = Vec3(0, 3, 2)
recevoir(W, "__energie", W["ing"])
tache(lambda: appel(UI.get("setPref"), "effetsReduits", True)); H.avancer(0.01)
verifier("2. « Réduire les effets » : la lueur du panneau disparaît", enfants(carte, "Lueur")[0].props["Visible"] is False)
tache(lambda: appel(UI.get("setPref"), "effetsReduits", False)); H.avancer(0.01)
verifier("2. … et revient", enfants(carte, "Lueur")[0].props["Visible"] is True)
echap(W)
verifier("2. Menu de l'énergie : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])

# — Message de la console : notification de la charte
msg = W["pg"].m_FindFirstChild("TardisConsoleMessage")
recevoir(W, "__console", "Réservé aux pilotes et aux ingénieurs.", False)
nm = trouve(msg, "MessageConsole")
verifier("3. « __console » refusé : notification de la charte (coins coupés), badge « REFUSÉ » jaune, le message",
         nm.props["Visible"] is True and texte_de(trouve(nm, "Badge")) == "REFUSÉ" and rgb(trouve(nm, "Badge").props["TextColor3"]) == JETONS["jaune"]
         and texte_de(trouve(nm, "Texte")) == "Réservé aux pilotes et aux ingénieurs." and len(enfants(nm, "Chanfrein")) == 2)
H.avancer(3.1)
verifier("3. … disparaît après 3 s", nm.props["Visible"] is False)
recevoir(W, "__console", "Jukebox : Thème.", True)
verifier("3. Message réussi : badge « TARDIS » cyan", texte_de(trouve(nm, "Badge")) == "TARDIS" and rgb(trouve(nm, "Badge").props["TextColor3"]) == JETONS["cyan"])


# ================================================================== 3. Panneau du jukebox
juke = W["pg"].m_FindFirstChild("TardisJukeboxConsole")
Config.set("Jukebox", Table())
recevoir(W, "__jukebox", W["juke"])
liste = trouve(juke, "Liste")
pj = trouve(juke, "Plaque")
vide = trouve(liste, "Vide")
bouton = lambda nom: trouve(juke, nom)
verifier("3. Liste vide : panneau ouvert, l'explication gardée (Toolbox › Audio › Music, TardisAssets › Jukebox, Config.Jukebox), en police de données",
         juke.props.get("Enabled") is True and vide is not None and all(m in texte_de(vide) for m in ("vide", "Toolbox", "Audio › Music", "ReplicatedStorage › TardisAssets › Jukebox", "Config.Jukebox"))
         and police(vide) == "RobotoMono" and texte_de(trouve(pj, "SousLigne")) == "AUCUNE PISTE")
verifier("3. Liste vide : JOUER et PLAYLIST indisponibles", bouton("Jouer").attrs.get("Disponible") is False and bouton("JouerPlaylist").attrs.get("Disponible") is False)
appuyer(bouton("Fermer"))
verifier("3. Bouton × (« Fermer ») de la plaque : fermé", juke.props.get("Enabled") is False)
Config.set("Jukebox", Table({1: Table({"nom": "Thème", "id": 111, "categorie": "Action"}), 2: Table({"nom": "Vortex", "id": 222, "categorie": "Action"}), 3: Table({"nom": "Calme", "id": 333})}))
ext.m_SetAttribute("Jukebox", 2)
recevoir(W, "__jukebox", W["juke"])
verifier("3. Plaque : « JUKEBOX » (Michroma), badge « PILOTE », « EN LECTURE · PISTE 02 · VORTEX », bande de danger ; × de 44 px",
         texte_de(trouve(pj, "Titre")) == "JUKEBOX" and police(trouve(pj, "Titre")) == "Michroma" and texte_de(trouve(pj, "BadgePlaque")) == "PILOTE"
         and texte_de(trouve(pj, "SousLigne")) == "EN LECTURE  ·  PISTE 02  ·  VORTEX" and trouve(pj, "BandeDanger") is not None and taille(bouton("Fermer")) == [44, 44],
         (texte_de(trouve(pj, "Titre")), texte_de(trouve(pj, "SousLigne"))))
tab = trouve(juke, "Pistes")
verifier("3. Tableau N° | PISTE | CATÉGORIE (une durée inconnue : pistes de Config.Jukebox)", [texte_de(trouve(tab, "Titre_" + k)) for k in ("numero", "piste", "detail")] == ["N°", "PISTE", "CATÉGORIE"],
         [texte_de(trouve(tab, "Titre_" + k)) for k in ("numero", "piste", "detail")])
cel = lambda l, k: texte_de(trouve(l, "Cellule_" + k))
lignes = lambda: [e for e in liste.enfants if e.ClassName == "TextButton"]
rangs = [(e.Name, cel(e, "numero"), cel(e, "piste"), cel(e, "detail")) for e in sorted(lignes(), key=lambda e: e.props["LayoutOrder"])]
verifier("3. La playlist d'abord, puis les pistes triées comme sur le serveur (numéros 01, 02, 03)",
         rangs == [("Playlist", "►", "PLAYLIST ACTION", "2 PISTES"), ("Piste", "01", "THÈME", "ACTION"), ("Piste", "02", "VORTEX", "ACTION"), ("Piste", "03", "CALME", "—")], rangs)
piste = lambda num: next(e for e in lignes() if e.Name == "Piste" and cel(e, "numero") == num)
p2 = piste("02")
verifier("3. La piste qui joue (02) en jaune, texte sombre ; lignes de 44 px", p2.props["BackgroundTransparency"] == 0 and rgb(p2.props["BackgroundColor3"]) == JETONS["jaune"]
         and rgb(trouve(p2, "Cellule_piste").props["TextColor3"]) == JETONS["sombre"] and all(taille(e)[3] == 44 for e in lignes()))
verifier("3. À l'ouverture, la ligne choisie est celle qui joue", p2.attrs.get("Selection") is True and sum(1 for e in lignes() if e.attrs.get("Selection")) == 1)
bj, bpl, bar = bouton("Jouer"), bouton("JouerPlaylist"), bouton("Arreter")
verifier("3. Boutons JOUER (principal), PLAYLIST (secondaire), ARRÊTER (danger), à coins coupés, 46 px", (texte_de(bj), bj.attrs.get("Variante"), texte_de(bpl), bpl.attrs.get("Variante"), texte_de(bar), bar.attrs.get("Variante"))
         == ("JOUER", "principal", "PLAYLIST", "secondaire", "ARRÊTER", "danger") and taille(trouve(juke, "Boutons"))[3] == 46 and all(len(enfants(b, "Chanfrein")) == 2 for b in (bj, bpl, bar)))
appuyer(piste("03"))
p3 = piste("03")
verifier("3. Clic sur la piste 03 : ligne choisie (fond cyan léger), la 02 reste jaune ; CALME n'a pas de catégorie → PLAYLIST indisponible",
         p3.attrs.get("Selection") is True and p3.props["BackgroundTransparency"] == 0.82 and rgb(p3.props["BackgroundColor3"]) == JETONS["cyan"]
         and piste("02").props["BackgroundTransparency"] == 0 and bpl.attrs.get("Disponible") is False and bj.attrs.get("Disponible") is True)
n = len(envois(W))
appuyer(bj)
appuyer(piste("01")); appuyer(bpl)
appuyer(next(e for e in lignes() if e.Name == "Playlist")); appuyer(bj)
appuyer(bar)
jk = [dict(e[1].h) for e in envois(W, n, "Jukebox")]
verifier("3. JOUER (piste 03), PLAYLIST (catégorie de la piste 01), JOUER sur la playlist, ARRÊTER : l'action EXISTANTE Jukebox",
         jk == [{"index": 3}, {"liste": "Action"}, {"liste": "Action"}, {}], jk)
ext.m_SetAttribute("Jukebox", "Action"); H.avancer(0.01)
pll = next(e for e in lignes() if e.Name == "Playlist")
verifier("3. La playlist qui joue en jaune, « EN LECTURE · PLAYLIST ACTION »", pll.props["BackgroundTransparency"] == 0 and rgb(pll.props["BackgroundColor3"]) == JETONS["jaune"]
         and texte_de(trouve(pj, "SousLigne")) == "EN LECTURE  ·  PLAYLIST ACTION")
ext.m_SetAttribute("Jukebox", None); H.avancer(0.01)
verifier("3. Arrêtée : « À L'ARRÊT · 3 PISTES », plus de ligne jaune", texte_de(trouve(pj, "SousLigne")) == "À L'ARRÊT  ·  3 PISTES"
         and not any(e.props["BackgroundTransparency"] == 0 for e in lignes()))
vol = trouve(juke, "Volume")
verifier("3. Volume (réglages de la tablette) en 10 segments : 100 % → 10", vol.attrs.get("Allumes") == 10 and texte_de(trouve(vol, "Valeur")) == "100 %" and texte_de(trouve(vol, "Nom")) == "VOLUME")
tache(lambda: appel(UI.get("setPref"), "volume", 0.6)); H.avancer(0.01)
verifier("3. Volume réglé à 60 % : 6 segments, tout de suite", vol.attrs.get("Allumes") == 6 and texte_de(trouve(vol, "Valeur")) == "60 %", (vol.attrs.get("Allumes"), texte_de(trouve(vol, "Valeur"))))
# Durées connues : les Sound du dossier TardisAssets › Jukebox, chargés (TimeLength)
appuyer(bouton("Fermer"))
Config.set("Jukebox", Table())
dj = Instance("Folder", "Jukebox", Instance("Folder", "TardisAssets", W["rs"]))
for nom_, sid, duree_, cat in (("Thème du vortex", 5001, 161, "Thèmes"), ("Ambiance de bord", 5002, 185.4, "Ambiance de bord")):
    s_ = Instance("Sound", nom_, dj); s_.props.update({"SoundId": "rbxassetid://%d" % sid, "TimeLength": duree_}); s_.attrs["Categorie"] = cat
recevoir(W, "__jukebox", W["juke"])
rangs = [(cel(e, "piste"), cel(e, "detail")) for e in sorted(lignes(), key=lambda e: e.props["LayoutOrder"]) if e.Name == "Piste"]
verifier("3. Toutes les durées connues : colonne « DURÉE » (2:41, 3:05)", texte_de(trouve(tab, "Titre_detail")) == "DURÉE" and rangs == [("THÈME DU VORTEX", "2:41"), ("AMBIANCE DE BORD", "3:05")], rangs)
W["racine"].props["Position"] = Vec3(4, 2, 40); H.avancer(0.6)
verifier("3. En s'éloignant du jukebox : fermé", juke.props.get("Enabled") is False)
W["racine"].props["Position"] = Vec3(0, 3, 2)
recevoir(W, "__jukebox", W["juke"]); recevoir(W, "__energie", W["ing"])
verifier("3. Un seul panneau à la fois", juke.props.get("Enabled") is False and menu.props.get("Enabled") is True)
echap(W)
verifier("3. Jukebox et message : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])


# ================================================================== 4. Casier (vrai module Interactions)
W = monde_client()
Config, UI, joueur, camera = W["Config"], W["UI"], W["joueur"], W["camera"]
joueur.props["Team"] = Instance("Team", "C.A.T.")
perso = Instance("Model", "Moi", W["ws"]); hum = Instance("Humanoid", "Humanoid", perso)
piece("Head", perso, (0, 4.5, 0), (2, 1, 1)); W["racine"] = piece("HumanoidRootPart", perso, (0, 3, 0), (2, 2, 1))
sh = Instance("Shirt", "Shirt", perso); sh.props["ShirtTemplate"] = "rbxassetid://1111"
pa = Instance("Pants", "Pants", perso); pa.props["PantsTemplate"] = "rbxassetid://2222"
perso.attrs["TardisTenue"] = 4
joueur.props["Character"] = perso
CAM0 = camera.props["CFrame"]
camera.props["CameraSubject"] = hum
RAYONS = []
W["ws"].extra["Raycast"] = Fonction("Raycast", py=lambda *a: RAYONS.append(a) or [None])
TEN = Config.get("Tenues")
dossierT = Instance("Folder", "Tenues", Instance("Folder", "TardisAssets", W["rs"]))
for i in range(1, TEN.longueur() + 1):
    t_ = TEN.get(i)
    dossierT.attrs["Shirt_%d" % t_.get("shirt")] = "rbxassetid://%d" % (70000 + i); dossierT.attrs["Pants_%d" % t_.get("pant")] = "rbxassetid://%d" % (80000 + i)
IM = module(W, "Interactions")
verifier("4. Vrai module Interactions chargé (casier de la console en Model), sans erreur", IM is not None and not roblox.ERREURS, roblox.ERREURS[:3])
cgui = W["pg"].m_FindFirstChild("TardisCasier")
prompt = [e for e in descendants(W["casier"]) if e.ClassName == "ProximityPrompt"][0]
declencher(prompt, "Triggered")
verifier("4. Invite « Choisir une tenue » : le menu s'ouvre", cgui.props.get("Enabled") is True and prompt.props["ActionText"] == "Choisir une tenue")
verifier("4. Caméra du casier (V6.9.10.5) toujours appelée : rayons lancés, caméra placée face au joueur (Scriptable)",
         len(RAYONS) >= 1 and camera.props["CameraType"].nom == "Enum.CameraType.Scriptable" and camera.props["CFrame"] is not CAM0, (len(RAYONS), camera.props["CameraType"]))
pc = trouve(cgui, "Casier")
verifier("4. Panneau de la charte à droite de l'écran : 360 × 600 px avant l'échelle, coins coupés, filet cyan",
         taille(pc) == [360, 600] and pc.props["AnchorPoint"].args == [1, 0.5] and len(enfants(pc, "Chanfrein")) == 2 and rgb(enfants(pc, "Contour")[0].props["Color"]) == JETONS["cyan"],
         taille(pc))
verifier("4. Échelle qui suit l'écran (1920 × 1080 : 1,15)", abs(enfants(pc, classe="UIScale")[0].props["Scale"] - 1.15) < 1e-9, enfants(pc, classe="UIScale")[0].props["Scale"])
pq = trouve(cgui, "Plaque")
verifier("4. Plaque : « CASIER », badge = l'équipe du joueur (« C.A.T. »), « CHOISIR UNE TENUE », bande de danger",
         texte_de(trouve(pq, "Titre")) == "CASIER" and texte_de(trouve(pq, "BadgePlaque")) == "C.A.T." and trouve(pq, "BadgePlaque").props["Visible"] is True
         and texte_de(trouve(pq, "SousLigne")) == "CHOISIR UNE TENUE" and trouve(pq, "BandeDanger") is not None, (texte_de(trouve(pq, "BadgePlaque")),))
grille = trouve(cgui, "Tenues")
tuiles = lambda: sorted(enfants(grille, "Tenue"), key=lambda e: e.props["LayoutOrder"])
gl = enfants(grille, classe="UIGridLayout")
verifier("4. Grille de tuiles : une par tenue (%d), deux colonnes, 80 px de haut (cible tactile)" % TEN.longueur(),
         len(tuiles()) == TEN.longueur() and gl and gl[0].props["CellSize"].args[0] == 0.5 and gl[0].props["CellSize"].args[3] == 80)
tuile = lambda nom: next(e for e in tuiles() if texte_de(trouve(e, "Nom")) == nom.upper())
nom2, nom3, nom4 = TEN.get(2).get("nom"), TEN.get(3).get("nom"), TEN.get(4).get("nom")
t2 = tuile(nom2)
verifier("4. Tuile : nom en majuscules, description, catégorie ; favori ○ de 44 px ; aucune tuile en jaune au départ",
         texte_de(trouve(t2, "Detail")) == TEN.get(2).get("description") and texte_de(trouve(t2, "Categorie")) == TEN.get(2).get("categorie").upper()
         and texte_de(trouve(t2, "Favori")) == "○" and taille(trouve(t2, "Favori")) == [44, 44] and not any(e.attrs.get("Choisie") for e in tuiles()))
verifier("4. La tenue portée (attribut TardisTenue du personnage) est signalée « TENUE ACTUELLE »", texte_de(trouve(tuile(nom4), "Categorie")) == "●  TENUE ACTUELLE")
appuyer(t2)
t2 = tuile(nom2)
verifier("4. Clic sur une tuile : elle passe en jaune (texte sombre), l'aperçu est mis (images du serveur)",
         t2.attrs.get("Choisie") is True and t2.props["BackgroundTransparency"] == 0 and rgb(t2.props["BackgroundColor3"]) == JETONS["jaune"]
         and rgb(trouve(t2, "Nom").props["TextColor3"]) == JETONS["sombre"] and sh.props["ShirtTemplate"] == "rbxassetid://70002" and pa.props["PantsTemplate"] == "rbxassetid://80002",
         (t2.props["BackgroundTransparency"], sh.props["ShirtTemplate"]))
appuyer(trouve(tuile(nom3), "Favori"))
verifier("4. Favori (○ → ●) : gardé dans les préférences, la tuile passe en tête", UI.get("prefs").get("tenuesFavorites").get("3") is True
         and texte_de(trouve(tuile(nom3), "Favori")) == "●" and tuiles()[0] is tuile(nom3) and tuile(nom2).attrs.get("Choisie") is True)
benf, bfer = trouve(cgui, "Enfiler"), trouve(cgui, "Fermer")
verifier("4. Boutons ENFILER (principal) et FERMER (secondaire), à coins coupés, 46 px",
         (texte_de(benf), benf.attrs.get("Variante"), texte_de(bfer), bfer.attrs.get("Variante")) == ("ENFILER", "principal", "FERMER", "secondaire")
         and taille(trouve(cgui, "Boutons"))[3] == 46 and len(enfants(benf, "Chanfrein")) == 2)
n = len(envois(W))
appuyer(benf)
verifier("4. ENFILER : la tenue est demandée au serveur (action EXISTANTE Tenue, index 2), menu fermé, caméra rendue exactement",
         [(e[0], dict(e[1].h)) for e in envois(W, n)] == [("Tenue", {"index": 2})] and cgui.props.get("Enabled") is False
         and camera.props["CFrame"] is CAM0 and camera.props["CameraType"].nom == "Enum.CameraType.Custom" and camera.props["CameraSubject"] is hum, envois(W, n))
declencher(prompt, "Triggered"); appuyer(tuile(nom3)); appuyer(trouve(cgui, "Fermer"))
verifier("4. FERMER : rien demandé, l'essai retiré (la tenue portée à l'ouverture revient), caméra rendue", envois(W, n + 1, "Tenue") == [] and cgui.props.get("Enabled") is False
         and sh.props["ShirtTemplate"] == "rbxassetid://70002" and camera.props["CFrame"] is CAM0, (envois(W, n + 1), sh.props["ShirtTemplate"]))
declencher(prompt, "Triggered"); echap(W)
verifier("4. Échap : fermé, caméra rendue", cgui.props.get("Enabled") is False and camera.props["CFrame"] is CAM0)
verifier("4. Casier : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])
# Invitation (même module) : notification de la charte avec deux boutons
tache(lambda: appel(IM.get("afficherInvitation"), "Amy")); H.avancer(0.05)
inv = W["pg"].m_FindFirstChild("TardisInvitation")
ni = trouve(inv, "Invitation")
verifier("4. Invitation : notification de la charte, badge « INVITATION », ACCEPTER (principal) / REFUSER (danger) de 44 px",
         ni.props["Visible"] is True and texte_de(trouve(ni, "Badge")) == "INVITATION" and "Amy t'invite" in texte_de(trouve(ni, "Texte"))
         and trouve(ni, "Accepter").attrs.get("Variante") == "principal" and trouve(ni, "Refuser").attrs.get("Variante") == "danger" and taille(trouve(ni, "Boutons"))[3] == 44)
n = len(envois(W)); appuyer(trouve(ni, "Accepter"))
verifier("4. ACCEPTER : l'action EXISTANTE InvitationReponse, la notification disparaît", [(e[0], dict(e[1].h)) for e in envois(W, n)] == [("InvitationReponse", {"accepter": True})]
         and inv.parent is None and not roblox.ERREURS, (envois(W, n), roblox.ERREURS[:2]))


# ================================================================== 5. Écrans de la console (vrai module TardisServeur › Ecrans)
vider_cache(); roblox.ERREURS.clear()
I, G, game, pilote = monde(serveur=True)
rs = game.m_FindFirstChild("ReplicatedStorage"); Players = game.m_FindFirstChild("Players")
R = {}
tache(lambda: R.update(Config=appel(G["require"], rs.m_FindFirstChild("TardisConfig")), UI=appel(G["require"], rs.m_FindFirstChild("TardisUI"))))
Config, UIs = R["Config"], R["UI"]
canal = Instance("RemoteEvent", "TardisCommande_TARDIS_1", rs)
xs = Instance("Model", "Cabine"); salle = Instance("Model", "Salle")
consoleS = Instance("Model", "Console", salle)
e1 = Instance("Part", "Ecran", consoleS); ingS = Instance("Part", "Ecran-Ingenieure", consoleS)
xs.attrs.update({"Etat": "Pose", "Mode": "Normal", "Alimentation": True, "PointsDeVie": 80, "PV": 8000, "RegulEnergie": 80, "RegulAir": 100, "RegulVapeur": 50, "BouclierEnergie": 100})
DEST = {"nom": "Site-19"}
ctx = Table({"Config": Config, "E": Config.get("Etats"), "Players": Players, "def": Config.get("Tardis").get(1), "exterieur": xs, "interieur": salle, "remote": canal,
             "destinationChoisie": Fonction("destinationChoisie", py=lambda: [Instance("Part", DEST["nom"])]),
             "etatActuel": Fonction("etatActuel", py=lambda: xs.attrs.get("Etat") or "Pose")})
tache(lambda: R.update(m=premier(appeler(premier(I.executer(lire("ServerScriptService/TardisServeur/Ecrans.lua"), "Ecrans")), [ctx]))))
H.avancer(0.05)
Ec = R.get("m")
verifier("5. Module Ecrans chargé sur le serveur (aucun thème appliqué), sans erreur", Ec is not None and appel(UIs.get("themeActuel")) is None and not roblox.ERREURS, roblox.ERREURS[:3])
gd = enfants(e1, "TardisEcranDestination", "SurfaceGui")[0]
gi = enfants(ingS, "TardisEcranIngenieur", "SurfaceGui")[0]
champ = trouve
fd = champ(gd, "Fond")
verifier("5. Destination : fond bleu nuit #050B14 (UI.JETONS.ecran, sans dégradé), filet cyan, coins coupés (deux traits en biais)",
         rgb(fd.props["BackgroundColor3"]) == ECRAN and not enfants(fd, classe="UIGradient") and rgb(enfants(fd, "Contour", "UIStroke")[0].props["Color"]) == JETONS["cyan"]
         and len(enfants(fd, "Chanfrein")) == 2 and all(c.props["Rotation"] == 45 for c in enfants(fd, "Chanfrein")))
tt = champ(fd, "Titre")
verifier("5. Titre « ◢  TARDIS  ·  NAVIGATION » en cyan, Michroma", texte_de(tt) == "◢  TARDIS  ·  NAVIGATION" and rgb(tt.props["TextColor3"]) == JETONS["cyan"] and police(tt) == "Michroma")
ds = champ(fd, "Destination")
verifier("5. La destination en très grand (22 % de la hauteur, la ligne la plus haute), jaune, Michroma", texte_de(ds) == "SITE-19" and rgb(ds.props["TextColor3"]) == JETONS["jaune"]
         and police(ds) == "Michroma" and ds.props["Size"].args == [0.9, 0.22])
et, md, st, eti = champ(fd, "Etat"), champ(fd, "Mode"), champ(fd, "Statuts"), champ(fd, "EtiquetteDestination")
verifier("5. État · mode sur une ligne : « ●  POSÉ » (vert, Titillium Web gras), « MODE : CLASSIQUE » (texte)",
         texte_de(et) == "●  POSÉ" and rgb(et.props["TextColor3"]) == JETONS["vert"] and police(et) == "TitilliumWeb" and "TitilliumWeb" in str(et.props["FontFace"].args[0])
         and texte_de(md) == "MODE : CLASSIQUE" and rgb(md.props["TextColor3"]) == JETONS["texte"] and et.props["Position"].args[1] == md.props["Position"].args[1])
verifier("5. Statuts « SYSTÈMES NOMINAUX » discrets (maquette) ; « DESTINATION » en Roboto Mono discret",
         texte_de(st) == "SYSTÈMES NOMINAUX" and rgb(st.props["TextColor3"]) == JETONS["discret"] and police(eti) == "RobotoMono" and rgb(eti.props["TextColor3"]) == JETONS["discret"])
lv = champ(gd, "LigneVivante")
bv = champ(fd, "BandeVivante")
verifier("5. Bande vivante : SurfaceGui › Fond › LigneVivante gardée (transparente, vide, ≥ 12 % de haut), posée sur un fond cyan très léger",
         lv is not None and lv.parent is fd and fd.parent is gd and lv.props["BackgroundTransparency"] == 1 and not lv.enfants and lv.props["Size"].args[1] >= 0.12
         and bv.parent is fd and rgb(bv.props["BackgroundColor3"]) == JETONS["cyan"] and bv.props["BackgroundTransparency"] == 0.9 and fd.enfants.index(bv) < fd.enfants.index(lv))
verifier("5. Tailles minimales du texte gardées (titre, état, mode, statuts)", all(champ(x, "TailleMinimale") is not None for x in (tt, et, md, st)))
xs.m_SetAttribute("Alerte", True); xs.m_SetAttribute("Mode", "Urgence"); xs.m_SetAttribute("Etat", "Demat"); H.avancer(0.01)
verifier("5. Alerte : statut rouge ; dématérialisation en jaune ; Urgence à sa couleur", rgb(st.props["TextColor3"]) == JETONS["rouge"] and "ALERTE" in texte_de(st)
         and rgb(et.props["TextColor3"]) == JETONS["jaune"] and texte_de(md) == "MODE : URGENCE" and rgb(md.props["TextColor3"]) != JETONS["texte"])
xs.m_SetAttribute("Alerte", None); xs.m_SetAttribute("Camouflage", True); xs.m_SetAttribute("Mode", "Normal"); xs.m_SetAttribute("Etat", "Vol"); H.avancer(0.01)
verifier("5. Un statut (camouflé) : jaune ; dans le vortex : cyan", rgb(st.props["TextColor3"]) == JETONS["jaune"] and rgb(et.props["TextColor3"]) == JETONS["cyan"])
xs.m_SetAttribute("Camouflage", None); xs.m_SetAttribute("Etat", "Pose")
DEST["nom"] = "Bâtiment d'Éthique"; tache(lambda: appel(Ec.get("majEcran"))); H.avancer(0.01)
verifier("5. Accents en majuscules (« BÂTIMENT D'ÉTHIQUE »)", texte_de(ds) == "BÂTIMENT D'ÉTHIQUE", texte_de(ds))
tache(lambda: appel(Ec.get("majEcran"), "PAS POSÉ")); H.avancer(0.01)
bd = champ(fd, "Bandeau")
verifier("5. Message court : bandeau rouge sombre, filets rouges, texte en Michroma", bd.props["Visible"] is True and texte_de(champ(bd, "Message")) == "PAS POSÉ"
         and police(champ(bd, "Message")) == "Michroma" and all(rgb(b.props["BackgroundColor3"]) == JETONS["rouge"] for b in enfants(bd, "Bande")) and len(enfants(bd, "Bande")) == 2)
tache(lambda: appel(Ec.get("majEcran"))); H.avancer(0.01)
# — Écran ingénieur
fi = champ(gi, "Fond")
ti = champ(fi, "Titre")
verifier("5. Ingénieur : « ◢  INGÉNIERIE  ·  TARDIS_1 » en cyan, Michroma ; fond #050B14", texte_de(ti) == "◢  INGÉNIERIE  ·  TARDIS_1" and rgb(ti.props["TextColor3"]) == JETONS["cyan"]
         and police(ti) == "Michroma" and rgb(fi.props["BackgroundColor3"]) == ECRAN)
noms = [texte_de(champ(fi, "Nom_" + c)) for c in ("integrite", "energie", "air", "vapeur", "bouclier")]
verifier("5. Lignes INTÉGRITÉ, ÉNERGIE, AIR, VAPEUR, BOUCLIERS (Titillium Web gras, couleur du texte), valeurs en Roboto Mono",
         noms == ["INTÉGRITÉ", "ÉNERGIE", "AIR", "VAPEUR", "BOUCLIERS"] and all(rgb(champ(fi, "Nom_" + c).props["TextColor3"]) == JETONS["texte"] and police(champ(fi, "Valeur_" + c)) == "RobotoMono"
                                                                            for c in ("integrite", "energie", "air", "vapeur", "bouclier")), noms)
def jauge_i(cle):
    j = champ(fi, "Jauge_" + cle)
    seg = enfants(j, "Segment")
    on = [s for s in seg if s.props["BackgroundTransparency"] == 0]
    return j.attrs.get("Allumes"), {rgb(s.props["BackgroundColor3"]) for s in on}, len(seg), rgb(champ(fi, "Valeur_" + cle).props["TextColor3"])
verifier("5. Jauges à 10 segments : intégrité 80 % → 8 verts, énergie 80 % → 8 cyan, air 100 % → 10 jaunes, vapeur 50 % → 5 (texte), boucliers inactifs → 10 discrets",
         jauge_i("integrite") == (8, {JETONS["vert"]}, 10, JETONS["vert"]) and jauge_i("energie") == (8, {JETONS["cyan"]}, 10, JETONS["cyan"])
         and jauge_i("air") == (10, {JETONS["jaune"]}, 10, JETONS["jaune"]) and jauge_i("vapeur") == (5, {JETONS["texte"]}, 10, JETONS["texte"])
         and jauge_i("bouclier") == (10, {JETONS["discret"]}, 10, JETONS["discret"]), [jauge_i(c) for c in ("integrite", "energie", "air", "vapeur", "bouclier")])
off = [s for s in enfants(champ(fi, "Jauge_vapeur"), "Segment") if s.props["BackgroundTransparency"] != 0]
verifier("5. Segments éteints : le texte très transparent (maquette)", len(off) == 5 and all(rgb(s.props["BackgroundColor3"]) == JETONS["texte"] and s.props["BackgroundTransparency"] == 0.88 for s in off))
ai = champ(fi, "Aide")
verifier("5. Bande du bas : « CLIC : GESTION DE L'ÉNERGIE » en jaune (Roboto Mono) sur un fond cyan très léger", texte_de(ai) == "CLIC : GESTION DE L'ÉNERGIE"
         and rgb(ai.props["TextColor3"]) == JETONS["jaune"] and police(ai) == "RobotoMono" and rgb(champ(fi, "BandeAide").props["BackgroundColor3"]) == JETONS["cyan"])
xs.m_SetAttribute("RegulAir", 20); xs.m_SetAttribute("PointsDeVie", 15); xs.m_SetAttribute("BouclierBalles", True); xs.m_SetAttribute("BouclierEnergie", 30); H.avancer(0.2)
verifier("5. En direct : air vicié rouge (2 segments), intégrité 15 % rouge, anti-balles 30 % jaune (3 segments)",
         jauge_i("air")[:2] == (2, {JETONS["rouge"]}) and "VICIÉ" in texte_de(champ(fi, "Valeur_air")) and jauge_i("integrite")[1] == {JETONS["rouge"]}
         and jauge_i("bouclier")[:2] == (3, {JETONS["jaune"]}), [jauge_i(c)[:2] for c in ("air", "integrite", "bouclier")])
verifier("5. Plus de barres (Rail_ / Barre) ; tailles minimales du texte gardées sur chaque ligne", champ(gi, "Rail_air") is None and champ(gi, "Barre") is None
         and all(champ(champ(fi, n_), "TailleMinimale") is not None for n_ in ("Titre", "Nom_air", "Valeur_air", "Aide")))
def couleurs_de(g):
    res = set()
    for e in descendants(g):
        if e.ClassName in ("Frame", "TextLabel") and isinstance(e.props.get("BackgroundColor3"), Couleur) and e.props.get("BackgroundTransparency", 0) < 1: res.add(rgb(e.props["BackgroundColor3"]))
        if e.ClassName == "TextLabel": res.add(rgb(e.props["TextColor3"]))
        if e.ClassName == "UIStroke": res.add(rgb(e.props["Color"]))
    return res
ADMIS = set(JETONS.values()) | {ECRAN, (0, 0, 0), (58, 72, 86), (30, 5, 12), (255, 170, 185), (255, 225, 231), (255, 150, 70), (170, 140, 240)}
hors = (couleurs_de(gd) | couleurs_de(gi)) - ADMIS
verifier("5. Toutes les couleurs des écrans viennent des jetons de la charte (ou des teintes des voiles et des modes)", not hors, hors)
xs.m_SetAttribute("Alimentation", False); H.avancer(0.2)
vl = champ(gd, "Veille")
verifier("5. Hors tension : voile noir, « HORS TENSION » en Michroma discret", vl.props["Visible"] is True and rgb(vl.props["BackgroundColor3"]) == (0, 0, 0)
         and texte_de(champ(vl, "Texte")) == "HORS TENSION" and police(champ(vl, "Texte")) == "Michroma" and champ(gi, "Veille").props["Visible"] is True)
xs.m_SetAttribute("Alimentation", True); xs.m_SetAttribute("Detruit", True); H.avancer(0.2)
dt = champ(gd, "Detruit")
verifier("5. Détruit : voile rouge sombre, « TARDIS DÉTRUIT » rouge en Michroma, bandes rouges", dt.props["Visible"] is True and rgb(dt.props["BackgroundColor3"]) == (30, 5, 12)
         and texte_de(champ(dt, "Titre")) == "TARDIS DÉTRUIT" and rgb(champ(dt, "Titre").props["TextColor3"]) == JETONS["rouge"] and police(champ(dt, "Titre")) == "Michroma"
         and len(enfants(dt, "Bande")) == 2 and texte_de(champ(dt, "SousTitre")) == "RECONSTITUTION EN COURS")
xs.m_SetAttribute("Detruit", None); H.avancer(0.2)
verifier("5. Les trois couches (Fond, Veille, Detruit) tournent toujours ensemble (sens calculé par ajuster)", all(champ(gi, n_).props.get("Rotation") == fi.props.get("Rotation") for n_ in ("Veille", "Detruit")))
src_e = lire("ServerScriptService/TardisServeur/Ecrans.lua")
verifier("5. Code : aucune boucle (ni while, ni task.wait, ni image par image), plus de UI.C ni de dégradé sur les écrans",
         all(m not in src_e for m in ("while true", "task.wait(", "Heartbeat", "RenderStepped", "UIGradient")) and not re.search(r"\bUI\.C\.", src_e) and "local C = UI.C" not in src_e and "local J = UI.JETONS" in src_e)
verifier("5. Écrans : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])


# ================================================================== 6. Maintenance et Copilote (vrais modules)
W = monde_client()
Config, UI, ext, joueur = W["Config"], W["UI"], W["ext"], W["joueur"]
module(W, "Maintenance")
mg = W["pg"].m_FindFirstChild("TardisMaintenance_TARDIS_1")
verifier("6. Module Maintenance chargé, bandeau caché hors maintenance", mg is not None and mg.props.get("Enabled") is False and not roblox.ERREURS, roblox.ERREURS[:3])
ext.m_SetAttribute("MaintenancePar", "Techno"); ext.m_SetAttribute("Maintenance", "Réparations"); H.avancer(0.05)
bm = trouve(mg, "BandeauMaintenance")
verifier("6. En maintenance : notification de la charte (coins coupés), badge « MAINTENANCE » jaune, « TARDIS_1 EN MAINTENANCE · RÉPARATIONS »",
         mg.props.get("Enabled") is True and bm.props["Visible"] is True and texte_de(trouve(bm, "Badge")) == "MAINTENANCE" and rgb(trouve(bm, "Badge").props["TextColor3"]) == JETONS["jaune"]
         and texte_de(trouve(bm, "Texte")) == "TARDIS_1 EN MAINTENANCE  ·  RÉPARATIONS" and len(enfants(bm, "Chanfrein")) == 2, (texte_de(trouve(bm, "Texte")),))
verifier("6. … et la ligne de détail (ce qui reste possible, par qui)", "réparations, portes et boucliers restent possibles" in texte_de(trouve(bm, "Detail")) and "par Techno" in texte_de(trouve(bm, "Detail")))
H.avancer(2.1)
ext.m_SetAttribute("Maintenance", None); H.avancer(0.05)
verifier("6. Fin de la maintenance : bandeau caché ; aucune erreur", mg.props.get("Enabled") is False and not roblox.ERREURS, roblox.ERREURS[:3])
src_m = lire(CONSOLE + "Maintenance.lua")
verifier("6. Plus de rayures qui clignotent (aucune animation de décor en boucle)", "local rayures" not in src_m and "math.sin(" not in src_m and "RenderStepped" not in src_m and "Heartbeat" not in src_m)
# Copilote
module(W, "Copilote")
cg = W["pg"].m_FindFirstChild("TardisCopilote_TARDIS_1")
verifier("6. Module Copilote chargé, poste fermé tant que le joueur n'est pas copilote", cg is not None and cg.props.get("Enabled") is False and not roblox.ERREURS, roblox.ERREURS[:3])
joueur.m_SetAttribute("TardisCopilote_TARDIS_1", True); H.avancer(0.3)
poste = trouve(cg, "PosteCopilote")
pp = trouve(cg, "Plaque")
verifier("6. Copilote nommé : poste ouvert, panneau de la charte (coins coupés), plaque « POSTE DU COPILOTE » badge « COPILOTE », « OBJ. TARDIS-01 · TARDIS_1 · HALL »",
         cg.props.get("Enabled") is True and len(enfants(poste, "Chanfrein")) == 2 and texte_de(trouve(pp, "Titre")) == "POSTE DU COPILOTE"
         and texte_de(trouve(pp, "BadgePlaque")) == "COPILOTE" and texte_de(trouve(pp, "SousLigne")) == "OBJ. TARDIS-01  ·  TARDIS_1  ·  HALL" and trouve(pp, "BandeDanger") is not None,
         (texte_de(trouve(pp, "Titre")), texte_de(trouve(pp, "SousLigne"))))
nc = trouve(cg, "Message")
verifier("6. Message d'accueil en notification de la charte (badge TARDIS)", nc.props["Visible"] is True and texte_de(trouve(nc, "Badge")) == "TARDIS" and texte_de(trouve(nc, "Texte")) == "Le pilote t'a confié la navigation.")
recevoir(W, "Destination refusée.", False)
verifier("6. Réponse refusée du serveur : badge « REFUSÉ » jaune", texte_de(trouve(nc, "Badge")) == "REFUSÉ" and texte_de(trouve(nc, "Texte")) == "Destination refusée.")
recevoir(W, "__paradoxe")
verifier("6. Paradoxe : notification d'alerte (badge « PARADOXE » rouge, bande de danger rouge)", texte_de(trouve(nc, "Badge")) == "PARADOXE" and rgb(trouve(nc, "Badge").props["TextColor3"]) == JETONS["rouge"]
         and trouve(nc, "BandeDanger").props["Visible"] is True)
recevoir(W, "__console", "x", False)
verifier("6. Messages techniques « __… » ignorés", texte_de(trouve(nc, "Badge")) == "PARADOXE")
td = trouve(cg, "Destinations")
ld = {texte_de(trouve(l, "Cellule_nom")): l for l in tous(td, "Destination")}
verifier("6. Tableau DESTINATION | TYPE (lignes de 44 px) : Hall, Laboratoire", set(ld) >= {"HALL", "LABORATOIRE"} and all(taille(l)[3] == 44 for l in ld.values())
         and [texte_de(trouve(td, "Titre_" + k)) for k in ("nom", "genre")] == ["DESTINATION", "TYPE"], list(ld))
appuyer(ld["LABORATOIRE"])
ld = {texte_de(trouve(l, "Cellule_nom")): l for l in tous(td, "Destination")}
verifier("6. Choisir Laboratoire : ligne jaune, « → Laboratoire »", ld["LABORATOIRE"].props["BackgroundTransparency"] == 0 and rgb(ld["LABORATOIRE"].props["BackgroundColor3"]) == JETONS["jaune"]
         and any(texte_de(e) == "→ Laboratoire" for e in descendants(cg)))
n = len(envois(W))
dm = next(b for b in tous(cg, "BoutonPrincipal") if texte_de(trouve(b, "Titre")) == "DÉMAT")
appuyer(dm)
verifier("6. DÉMAT : l'action EXISTANTE Demat (avec le mode)", [e[0] for e in envois(W, n)] == ["Demat"], envois(W, n))
ecr = trouve(cg, "Ecrire")
verifier("6. Note au carnet : champ et bouton ÉCRIRE à coins coupés de 44 px", ecr.attrs.get("Variante") == "principal" and texte_de(ecr) == "ÉCRIRE" and taille(trouve(cg, "Note")) == [1, -92, 1, 0]
         and taille(ecr) == [0, 84, 1, 0] and taille(ecr.parent)[3] == 44)
appuyer(trouve(cg, "Reduire"))
verifier("6. Réduire : le panneau laisse la place à l'onglet COPILOTE (bouton de la charte)", poste.props["Visible"] is False and trouve(cg, "OngletCopilote").props["Visible"] is True
         and trouve(cg, "OngletCopilote").attrs.get("Variante") == "principal")
appuyer(trouve(cg, "OngletCopilote"))
verifier("6. … et revient ; Copilote : aucune erreur", poste.props["Visible"] is True and not roblox.ERREURS, roblox.ERREURS[:3])


# ================================================================== Avec les images 9 tranches (Config.Interface.Images)
W = monde_client()
for k, v in (("CoinFond", 11), ("CoinBord", 12), ("Balayage", 13)): W["Config"].get("Interface").get("Images").set(k, v)
W["joueur"].props["Character"] = Instance("Model", "Moi", W["ws"]); piece("HumanoidRootPart", W["joueur"].props["Character"], (0, 3, 0))
W["ws"].extra["Raycast"] = Fonction("Raycast", py=lambda *a: [None])
module(W, "Console"); module(W, "Interactions")
recevoir(W, "__energie", W["ing"])
carteI = trouve(W["pg"].m_FindFirstChild("TardisMenuEnergie"), "Carte")
moinsI = trouve(carteI, "Moins")
verifier("Images 9 tranches : menu de l'énergie dessiné par FondCoupe / BordCoupe (boutons − / + aussi), balayage, sans erreur",
         enfants(carteI, "FondCoupe") and enfants(carteI, "BordCoupe") and carteI.props["BackgroundTransparency"] == 1 and enfants(moinsI, "FondCoupe")
         and enfants(carteI, "Balayage") and not roblox.ERREURS, roblox.ERREURS[:3])
echap(W); recevoir(W, "__jukebox", W["juke"])
verifier("Images 9 tranches : panneau du jukebox, sans erreur", enfants(trouve(W["pg"].m_FindFirstChild("TardisJukeboxConsole"), "Carte"), "FondCoupe") and not roblox.ERREURS, roblox.ERREURS[:3])
echap(W)
declencher([e for e in descendants(W["casier"]) if e.ClassName == "ProximityPrompt"][0], "Triggered")
tuileI = enfants(trouve(W["pg"].m_FindFirstChild("TardisCasier"), "Tenues"), "Tenue")[0]
appuyer(tuileI); tuileI = sorted(enfants(trouve(W["pg"].m_FindFirstChild("TardisCasier"), "Tenues"), "Tenue"), key=lambda e: e.props["LayoutOrder"])[0]
verifier("Images 9 tranches : tuiles du casier à coins coupés, la tenue essayée en jaune (image de fond), sans erreur",
         enfants(tuileI, "FondCoupe") and rgb(enfants(tuileI, "FondCoupe")[0].props["ImageColor3"]) == JETONS["jaune"] and enfants(tuileI, "FondCoupe")[0].props["ImageTransparency"] == 0
         and not roblox.ERREURS, roblox.ERREURS[:3])


# ================================================================== Le code : rien de nouveau côté réseau, pas de décor image par image
fichiers = {n: lire(CONSOLE + n + ".lua") for n in ("Console", "Interactions", "Copilote", "Maintenance")}
actions = sorted(set(re.findall(r'FireServer\("(\w+)"', "".join(fichiers.values()))))
verifier("Aucune nouvelle action réseau (Tech, Jukebox, Tenue, InvitationReponse, Demat, Remat, NavAtterrir, Camouflage, CarnetEcrire)",
         set(actions) <= {"Tech", "Jukebox", "Tenue", "InvitationReponse", "Demat", "Remat", "NavAtterrir", "Camouflage", "CarnetEcrire"}, actions)
verifier("Aucun RenderStepped / Heartbeat dans les menus restylés (Console, Interactions, Copilote, Maintenance)", all("RenderStepped" not in s and "Heartbeat" not in s for s in fichiers.values()))
verifier("Console reçoit la caméra (échelle) ; la ligne vivante d'Ambiance prend la couleur du texte de la charte",
         "camera = camera, creer = creer, def = def" in lire(CONSOLE + "init.client.lua") and 'Name = "TardisVivant", Text = "", Font = UI.POLICE_CODE, TextScaled = true, TextColor3 = UI.JETONS.texte' in lire(CONSOLE + "Ambiance.lua"))


print("\n".join("  ✓ " + o for o in OK)); print("\n".join("  ✗ " + k for k in KO))
print(f"V6.9.10.7 : {len(OK)}/{len(OK) + len(KO)} vérifications réussies")
sys.exit(1 if KO else 0)
