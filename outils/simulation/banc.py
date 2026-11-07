"""Banc d'essai (V7.1.2) : une fausse place complète et le démarrage des vrais Scripts du TARDIS.
  place(manque=(), serveur=True, streaming=False) : construit le jeu (TARDIS_1 seul, comme DEVMAP), sans les pièces de `manque`.
  demarrer_serveur(...) : lance les vrais Scripts serveur dans l'ordre de Roblox (tous à la fois, chacun dans sa tâche),
  fait avancer le temps et renvoie ce qu'ils ont affiché et les erreurs.
  demarrer_client(...) : lance les vrais LocalScripts du joueur, avec des pièces qui peuvent arriver en retard.
Les autres simulations peuvent s'en servir pour partir d'une place complète au lieu de reconstruire la leur."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from monde import *
import roblox
from roblox import Vec3, CF, activer_maths

RACINE = os.path.dirname(DEPOT)
SCRIPTS_SERVEUR = ["TardisServeur/init.server.lua", "TardisExtras.server.lua", "TardisSystemes.server.lua",
                   "TardisSupervision.server.lua", "TardisLiaisonPortes.server.lua", "TardisPontFondation.server.lua"]
MODULES_SERVEUR = ["TardisDiagnostic", "TardisSauvegarde", "TardisTenues"]
# Pièces facultatives : un script ne doit jamais planter si l'une d'elles manque (T-205). Chemin depuis l'extérieur
# (« ext/… ») ou l'intérieur (« int/… »).
import re
def _chemins():
    """Config.Chemins lu dans TardisConfig.lua : { clé : [dossier, …, pièce] }."""
    src = open(f"{DEPOT}/ReplicatedStorage/TardisConfig.lua", encoding="utf-8").read()
    bloc = src[src.index("Config.Chemins = {"):]; bloc = bloc[:bloc.index("\n}")]
    return {m.group(1): re.findall(r'"([^"]+)"', m.group(2)) for m in re.finditer(r"^\s*(\w+)\s*=\s*\{([^}]*)\}", bloc, re.M)}
CHEMINS = _chemins()
SONS = ["Demat", "Remat", "Demat_Urg", "Remat_Urg", "Demat_Express", "Remat_Express", "Camouflage", "Decamouflage", "Alarme",
        "Cloitre", "Reparation", "Moteur_Pose", "Moteur_Vol", "Moteur_Urgence", "Regeneration", "Intercom", "Vortex", "Frein",
        "Panne_Vapeur", "Panne_Feu", "Panne_Grincement", "Panne_Etincelles", "Panne_FuiteAir", "RotorBloque", "Soudure"]
FACULTATIVES = ["int/Arrivee", "int/Casier", "int/Vanne", "int/Murs", "int/LedsAlerte", "int/PortesInterieures",
                "int/Jukebox", "int/Spawn C.A.T", "ext/Lampe", "ext/Fenetres", "ext/Enseigne", "ext/Boucliers"] + \
               ["cmd/" + c for c in CHEMINS]

def part(nom, parent, pos=(0, 0, 0), taille=(2, 2, 2), classe="Part"):
    p = Instance(classe, nom, parent)
    p.props.update({"CFrame": CF(pos), "Size": Vec3(*taille), "Position": Vec3(*pos), "Anchored": True})
    return p

def valeur(classe, nom, parent, v):
    o = Instance(classe, nom, parent); o.props["Value"] = v; return o

def place(manque=(), serveur=True, streaming=False):
    """Fausse place : workspace › TARDIS › TARDIS_1 › EXTERIEURE (Model) et INTERIEURE (pièces directement dans le dossier)."""
    roblox.charger_module.__defaults__[0].clear(); roblox.ERREURS.clear(); roblox.SORTIE.clear()
    H.file.clear(); roblox.arreter_taches()  # les tâches d'une place précédente s'arrêtent (chaque place repart de zéro)
    I, G, game, joueur = monde(serveur=serveur)
    activer_maths(G)
    roblox.ATTENTE["reelle"] = True; roblox.ATTENTES.clear(); roblox.EN_ATTENTE.clear()
    game.props.update({"PlaceId": 0, "GameId": 0, "JobId": "", "CreatorId": 0, "PlaceVersion": 0,
                       "CreatorType": roblox.Valeur("Enum.CreatorType.User")})
    ws = game.m_FindFirstChild("Workspace"); ws.props["StreamingEnabled"] = streaming
    ws.extra["Raycast"] = Fonction("Raycast", py=lambda *a: None)  # aucun rayon ne touche rien (pas de physique ici)
    cam = Instance("Camera", "Camera", ws)
    cam.props.update({"CFrame": CF((0, 10, 320)), "FieldOfView": 70, "ViewportSize": roblox.Valeur("Vector2", [1280, 720]),
                      "CameraType": roblox.Valeur("Enum.CameraType.Custom"), "CameraSubject": None, "Focus": CF((0, 5, 300))})
    ws.props["CurrentCamera"] = cam
    game.m_FindFirstChild("Lighting").props.update({"ExposureCompensation": 0, "Brightness": 2, "ClockTime": 14, "Ambient": roblox.Couleur(0.5, 0.5, 0.5),
        "OutdoorAmbient": roblox.Couleur(0.5, 0.5, 0.5), "FogEnd": 100000, "FogStart": 0, "FogColor": roblox.Couleur(0.75, 0.75, 0.75),
        "GeographicLatitude": 41.7, "EnvironmentDiffuseScale": 0, "EnvironmentSpecularScale": 0, "GlobalShadows": True})
    game.m_FindFirstChild("Lighting").extra["GetSunDirection"] = Fonction("GetSunDirection", py=lambda *a: roblox.Valeur("Vector3", [0.3, 0.8, 0.5]))
    rs = game.m_FindFirstChild("ReplicatedStorage")
    sss = game.m_FindFirstChild("ServerScriptService")
    assets = Instance("Folder", "TardisAssets", rs); sons = Instance("Folder", "Sons", assets)
    if "sons" not in manque:
        for n in SONS: Instance("Sound", n, sons).props["SoundId"] = "rbxassetid://1"
    if "equipe/C.A.T." not in manque:  # l'équipe C.A.T. existe dans DEVMAP (la C.T.A.T. est créée par le TARDIS)
        e = Instance("Team", "C.A.T.", game.m_FindFirstChild("Teams")); e.props["TeamColor"] = roblox.Valeur("BrickColor", ["Bright blue"])
    racine = Instance("Folder", "TARDIS", ws)
    t1 = Instance("Folder", "TARDIS_1", racine)
    ext = Instance("Model", "TARDIS_1", Instance("Folder", "EXTERIEURE", t1))
    base = part("Base", ext, (0, 0.5, 300), (6, 1, 6)); ext.props["PrimaryPart"] = base
    part("Portail", ext, (0, 4, 303), (4, 7, 1)).props["Transparency"] = 1
    portes = Instance("Model", "TARDISDoors", ext)
    for n in ("LeftOpen", "RightOpen", "Locked"): valeur("BoolValue", n, portes, False)
    part("Gauche", portes, (-1, 4, 303), (2, 7, 0.3)); part("Droite", portes, (1, 4, 303), (2, 7, 0.3))
    if "ext/Lampe" not in manque:
        lampe = part("Lampe", ext, (0, 10, 300), (1, 1.5, 1)); Instance("PointLight", "Lumiere", lampe)
    if "ext/Fenetres" not in manque:
        f = Instance("Folder", "Fenetres", ext); part("Vitre", f, (0, 6, 303.1), (2, 2, 0.1))
    if "ext/Enseigne" not in manque: part("Enseigne", ext, (0, 8.5, 303.1), (5, 0.8, 0.1))
    if "ext/Boucliers" not in manque: Instance("Folder", "Boucliers", ext)
    salle = Instance("Folder", "INTERIEURE", t1)
    part("Sol", salle, (0, -1, 0), (60, 2, 60))
    part("Portail", salle, (0, 4, 25), (6, 8, 1)).props["Transparency"] = 1
    rotor = Instance("Model", "Rotor", salle); part("Colonne", rotor, (0, 5, 0), (2, 8, 2))
    console = Instance("Model", "Console", salle); part("Socle", console, (0, 1.5, 0), (10, 3, 10))
    Instance("Model", "Controls", salle)
    # Les commandes de la console, aux emplacements de Config.Chemins (la dernière pièce est une Part cliquable)
    for i, (cle, chemin) in enumerate(CHEMINS.items()):
        if "cmd/" + cle in manque: continue
        o = salle
        for j, n in enumerate(chemin):
            suivant = o.m_FindFirstChild(n)
            if suivant is None:
                suivant = part(n, o, (i - 6, 3.2, j - 2), (0.6, 0.6, 0.6)) if j == len(chemin) - 1 else Instance("Model", n, o)
            o = suivant
    if "int/Arrivee" not in manque: part("Arrivee", salle, (0, 1, 18), (4, 1, 4)).props["Transparency"] = 1
    if "int/Casier" not in manque: part("Casier", salle, (15, 4, 10), (3, 7, 2))
    if "int/Vanne" not in manque: part("Vanne", salle, (-15, 3, 10), (1, 1, 1))
    if "int/Murs" not in manque:
        m = Instance("Folder", "Murs", salle); part("MurNord", m, (0, 10, -30), (60, 20, 1))
    if "int/LedsAlerte" not in manque:
        l = Instance("Folder", "LedsAlerte", salle); part("Led", l, (0, 12, 0), (1, 1, 1), "Part")
    if "int/PortesInterieures" not in manque:
        p = Instance("Folder", "PortesInterieures", salle); part("PorteSalle", p, (25, 4, 0), (1, 8, 4))
    if "int/Jukebox" not in manque: part("Jukebox", salle, (-15, 3, -10), (2, 4, 2))
    if "int/Spawn C.A.T" not in manque: part("Spawn C.A.T", salle, (5, 0.5, 10), (6, 1, 6), "SpawnLocation")
    dest = Instance("Folder", "TARDIS_DESTINATIONS", racine)
    for i, (n, pos) in enumerate([("Accueil", (0, 0.5, 300)), ("Plage", (200, 0.5, 0)), ("Zone 2", (-200, 0.5, 0))]):
        d = part(n, dest, pos, (4, 1, 4)); d.props["Transparency"] = 1
    for nom in MODULES_SERVEUR:
        if not sss.m_FindFirstChild(nom):
            m = Instance("ModuleScript", nom, sss); m.extra["chemin"] = f"{DEPOT}/ServerScriptService/{nom}.lua"
    return {"I": I, "G": G, "game": game, "joueur": joueur, "ws": ws, "rs": rs, "sss": sss, "ext": ext, "salle": salle, "t1": t1}

def _executer(P, chemin, script_obj, sortie_erreurs):
    I, G = P["I"], P["G"]
    src = roblox.propre_script(I, open(chemin, encoding="utf-8").read(), script_obj)  # `script` propre à chaque script
    def go():
        G["script"] = script_obj
        try: I.executer(src, os.path.basename(chemin))
        except LuaError as e: sortie_erreurs.append(f"[{os.path.basename(chemin)}] {e}")
    lancer(Fonction(os.path.basename(chemin), py=go), nom=os.path.basename(chemin))

def demarrer_serveur(P, duree=20.0, scripts=None):
    """Lance les vrais Scripts serveur (TARDIS_1) et fait avancer le temps de `duree` secondes.
    Renvoie (sorties, erreurs) : les lignes de l'Output et toutes les erreurs (levées au démarrage ou dans une tâche)."""
    sss = P["sss"]; erreurs = []
    for rel in scripts or SCRIPTS_SERVEUR:
        nom = rel.split("/")[0].replace(".server.lua", "")
        s = Instance("Script", nom, sss); s.props["Name"] = nom
        s.attrs["Tardis"] = "TARDIS_1"  # un seul TARDIS : pas de copie du Script pour TARDIS_2 et TARDIS_3
        if rel.startswith("TardisServeur/"):
            for mod in ("Ecrans", "VolLibre"):
                m = Instance("ModuleScript", mod, s); m.extra["chemin"] = f"{DEPOT}/ServerScriptService/TardisServeur/{mod}.lua"
        _executer(P, f"{DEPOT}/ServerScriptService/{rel}", s, erreurs)
    pas = 0.5
    t = 0.0
    while t < duree:
        H.avancer(pas); t += pas
    return list(roblox.SORTIE), erreurs + list(roblox.ERREURS)

SPS = f"{DEPOT}/StarterPlayer/StarterPlayerScripts"
SCRIPTS_CLIENT = ["TardisCamera.client.lua", "TardisEffets.client.lua", "TardisExtrasClient/init.client.lua", "TardisMenu.client.lua",
                  "TardisPortail.client.lua", "TardisPorter.client.lua", "TardisRotation.client.lua", "TardisTablette/init.client.lua",
                  "TardisVolLibre.client.lua"]

def retarder(P, objets, delai):
    """Streaming (T-206) : les objets quittent la place et n'y reviennent qu'au bout de `delai` secondes."""
    for o in objets:
        parent = o.parent; o.set_parent(None)
        H.plus_tard(delai, lambda o=o, parent=parent: o.set_parent(parent))

def demarrer_client(P, duree=20.0, scripts=None, remote=True):
    """Lance les vrais LocalScripts du joueur (TARDIS_1). remote : le canal TardisCommande du serveur existe déjà
    (sinon, il faut le créer soi-même, en retard). Renvoie (sorties, erreurs)."""
    rs, joueur = P["rs"], P["joueur"]; erreurs = []
    if remote and not rs.m_FindFirstChild("TardisCommande_TARDIS_1"): Instance("RemoteEvent", "TardisCommande_TARDIS_1", rs)
    for n in ("PlayerGui", "PlayerScripts", "Backpack"):
        if not joueur.m_FindFirstChild(n): Instance(n if n != "PlayerScripts" else "PlayerScripts", n, joueur)
    ps = joueur.m_FindFirstChild("PlayerScripts")
    for rel in scripts or SCRIPTS_CLIENT:
        nom = rel.split("/")[0].replace(".client.lua", "")
        s = Instance("LocalScript", nom, ps); s.attrs["Tardis"] = "TARDIS_1"
        if "/" in rel:  # script dossier : ses modules (TardisExtrasClient, TardisTablette)
            dossier = f"{SPS}/{rel.split('/')[0]}"
            for f in sorted(os.listdir(dossier)):
                if f.endswith(".lua") and not f.startswith("init."):
                    m = Instance("ModuleScript", f[:-4], s); m.extra["chemin"] = f"{dossier}/{f}"
        _executer(P, f"{SPS}/{rel}", s, erreurs)
    t = 0.0
    while t < duree:
        H.avancer(0.5); t += 0.5
    return list(roblox.SORTIE), erreurs + list(roblox.ERREURS)
