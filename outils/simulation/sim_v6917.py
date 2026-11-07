"""Simulations de la V6.9.17 (maps en Streaming) : le vrai TardisConfig et le vrai TardisDiagnostic.
  1. Serveur, Streaming activé, pièces posées directement dans INTERIEURE : Config.modeles range tout le contenu du dossier
     dans un Model « TARDIS_1_INTERIEURE » en ModelStreamingMode Persistent, repère au centre de l'ancienne boîte, et le renvoie ;
     un second appel renvoie le même Model, sans rien ranger de nouveau.
  2. Sans Streaming (DEVMAP) : rien ne change, le dossier reste la salle.
  3. Côté client : jamais de rangement (c'est le serveur qui le fait).
  4. Ancienne organisation (un Model dans INTERIEURE) : rien ne change, même en Streaming.
  5. Diagnostic : en Streaming, un intérieur ou un extérieur qui n'est pas un Model Persistent est signalé.
  6. outils/importer_structure.luau range aussi l'intérieur dans un Model Persistent quand la map est en Streaming."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from monde import *
import roblox
from roblox import Vec3, CF, activer_maths, charger_module
OK, KO = [], []
def verifier(nom, condition, detail=""):
    (OK if condition else KO).append(nom + ("" if condition else "  →  " + str(detail)))
def tache(f): lancer(Fonction("t", py=f))
def vider_cache(): roblox.charger_module.__defaults__[0].clear()
RACINE = os.path.dirname(DEPOT)
R = {}

def part(nom, parent, pos=(0, 0, 0), taille=(2, 2, 2), classe="Part"):
    p = Instance(classe, nom, parent)
    p.props.update({"CFrame": CF(pos), "Size": Vec3(*taille), "Position": Vec3(*pos)})
    return p

def place(streaming=True, serveur=True, ancien_format=False, ext_persistant=True):
    vider_cache(); roblox.ERREURS.clear(); roblox.SORTIE.clear()
    I, G, game, joueur = monde(serveur=serveur)
    activer_maths(G)
    ws = game.m_FindFirstChild("Workspace")
    ws.props["StreamingEnabled"] = streaming
    t1 = Instance("Folder", "TARDIS_1", Instance("Folder", "TARDIS", ws))
    ext = Instance("Model", "TARDIS_1", Instance("Folder", "EXTERIEURE", t1))
    racine = part("Racine", ext); ext.props["PrimaryPart"] = racine
    if ext_persistant: ext.props["ModelStreamingMode"] = Valeur("Enum.ModelStreamingMode.Persistent")
    dossierInt = Instance("Folder", "INTERIEURE", t1)
    salle = Instance("Model", "Salle", dossierInt) if ancien_format else dossierInt
    Instance("Model", "Console", salle); Instance("Model", "Controls", salle)
    rotor = Instance("Model", "Rotor", salle); part("Colonne", rotor, (0, 5, 0), (2, 10, 2))
    part("Portail", salle, (0, 4, 20), (6, 8, 1))
    part("Sol", salle, (0, -1, 0), (40, 2, 40))
    part("Spawn C.A.T", salle, (5, 0, 10), (6, 1, 6), "SpawnLocation")
    Instance("Folder", "TARDIS_DESTINATIONS", t1.parent)
    rs = game.m_FindFirstChild("ReplicatedStorage")
    tache(lambda: R.update(Config=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisConfig")]))))
    return I, G, game, ws, t1, ext, dossierInt, salle

def modeles(Config):
    R.pop("m", None)
    tache(lambda: R.update(m=appeler(Config.get("modeles"), [Config.get("Tardis").get(1)])))
    return R.get("m") or [None, None]

def enum(v): return str(getattr(v, "nom", v))

# ================================================================== 1. Serveur en Streaming, pièces dans le dossier
I, G, game, ws, t1, ext, dossierInt, salle = place()
Config = R["Config"]
verifier("Version 6.9.17", Config.get("Version") == "6.9.17", Config.get("Version"))
enfants_avant = sorted(e.Name for e in dossierInt.enfants)
exterieur, interieur = modeles(Config)
verifier("1. L'extérieur est toujours le Model de EXTERIEURE", exterieur is ext)
verifier("1. L'intérieur renvoyé est un Model « TARDIS_1_INTERIEURE »", interieur is not None and interieur.ClassName == "Model" and interieur.Name == "TARDIS_1_INTERIEURE", interieur)
verifier("1. Ce Model est en ModelStreamingMode Persistent", interieur is not None and enum(interieur.props.get("ModelStreamingMode")) == "Enum.ModelStreamingMode.Persistent", interieur and interieur.props.get("ModelStreamingMode"))
verifier("1. Il est rangé dans le dossier INTERIEURE, qui ne contient plus que lui", interieur is not None and interieur.parent is dossierInt and dossierInt.enfants == [interieur], [e.Name for e in dossierInt.enfants])
verifier("1. Tout le contenu y est passé (Portail, Rotor, Console, spawn…)", interieur is not None and sorted(e.Name for e in interieur.enfants) == enfants_avant, interieur and [e.Name for e in interieur.enfants])
pivot = interieur.props.get("WorldPivot") if interieur is not None else None
R.pop("p", None)
tache(lambda: R.update(p=pivot.__lua_index__("Position") if pivot is not None else None))
centre = [round(float(x), 2) for x in R["p"].t()] if R.get("p") is not None else None
verifier("1. Repère du Model = centre de l'ancienne boîte du dossier (x 0, y 4, z 0,25)", centre == [0.0, 4.0, 0.25], (pivot, centre))
avert = [l for l in roblox.SORTIE if l.startswith("⚠") and "Streaming" in l and "TARDIS_1_INTERIEURE" in l]
verifier("1. Un avertissement dans l'Output explique le rangement", len(avert) == 1, roblox.SORTIE[-3:])
_, interieur2 = modeles(Config)
verifier("1. Second appel : le même Model, rien de rangé en plus", interieur2 is interieur and dossierInt.enfants == [interieur], interieur2)
verifier("1. Une seule fois l'avertissement", len([l for l in roblox.SORTIE if "TARDIS_1_INTERIEURE" in l and l.startswith("⚠")]) == 1)
verifier("1. Les pièces trouvées dans le Model comme avant (Portail, Rotor)", interieur.m_FindFirstChild("Portail") is not None and interieur.m_FindFirstChild("Rotor") is not None)
verifier("1. Aucune erreur", not roblox.ERREURS, roblox.ERREURS[:2])

# ================================================================== 2. Sans Streaming (DEVMAP)
I, G, game, ws, t1, ext, dossierInt, salle = place(streaming=False)
_, interieur = modeles(R["Config"])
verifier("2. Sans Streaming : le dossier INTERIEURE reste la salle", interieur is dossierInt, interieur)
verifier("2. Sans Streaming : aucun Model ajouté", not any(e.ClassName == "Model" and e.Name.endswith("_INTERIEURE") for e in dossierInt.enfants))

# ================================================================== 3. Côté client
I, G, game, ws, t1, ext, dossierInt, salle = place(serveur=False)
_, interieur = modeles(R["Config"])
verifier("3. Client : il ne range rien lui-même (le dossier n'est pas touché)", interieur is dossierInt and not any(e.Name.endswith("_INTERIEURE") for e in dossierInt.enfants), interieur)

# ================================================================== 4. Ancienne organisation
I, G, game, ws, t1, ext, dossierInt, salle = place(ancien_format=True)
_, interieur = modeles(R["Config"])
verifier("4. Un Model dans INTERIEURE : toujours ce Model, même en Streaming", interieur is salle and dossierInt.enfants == [salle], interieur)

# ================================================================== 5. Diagnostic
def diagnostic(G, game, ext, interieur):
    sss = game.m_FindFirstChild("ServerScriptService")
    m = Instance("ModuleScript", "TardisDiagnostic", sss); m.extra["chemin"] = f"{DEPOT}/ServerScriptService/TardisDiagnostic.lua"
    R.pop("d", None)
    tache(lambda: R.update(d=premier(appeler(premier(appeler(G["require"], [m])), [R["Config"].get("Tardis").get(1), ext, interieur]))))
    return str(R.get("d"))

I, G, game, ws, t1, ext, dossierInt, salle = place()
_, interieur = modeles(R["Config"])
roblox.SORTIE.clear()
ligne = diagnostic(G, game, ext, interieur)
verifier("5. Streaming, intérieur rangé et extérieur Persistent : « streaming : ok »", "streaming : ok" in ligne, ligne[-160:])
verifier("5. … et aucun avertissement sur le Streaming", not [l for l in roblox.SORTIE if "Persistent" in l], roblox.SORTIE[-2:])
I, G, game, ws, t1, ext, dossierInt, salle = place(ancien_format=True, ext_persistant=False)
_, interieur = modeles(R["Config"])
roblox.SORTIE.clear()
ligne = diagnostic(G, game, ext, interieur)
avert = [l for l in roblox.SORTIE if "Persistent" in l]
verifier("5. Streaming, Models non Persistent : « streaming : à régler »", "streaming : à régler" in ligne, ligne[-160:])
verifier("5. … avec l'avertissement qui nomme l'intérieur et l'extérieur", len(avert) == 1 and "Salle" in avert[0] and "EXTERIEURE" in avert[0], avert)
I, G, game, ws, t1, ext, dossierInt, salle = place(streaming=False)
_, interieur = modeles(R["Config"])
ligne = diagnostic(G, game, ext, interieur)
verifier("5. Sans Streaming : rien sur le Streaming dans le diagnostic", "streaming" not in ligne, ligne[-160:])

# ================================================================== 6. Importeur de la structure
imp = open(os.path.join(RACINE, "outils", "importer_structure.luau"), encoding="utf-8").read()
verifier("6. L'importeur range l'intérieur dans un Model Persistent en Streaming",
         "workspace.StreamingEnabled" in imp and 'f.nom == "INTERIEURE"' in imp and "Enum.ModelStreamingMode.Persistent" in imp and '"_INTERIEURE"' in imp)
verifier("6. … avant de le mettre à sa place (le client le reçoit déjà rangé)",
         imp.index("Enum.ModelStreamingMode.Persistent") < imp.index("place.Parent = parent"))

print("\n".join("  ✓ " + o for o in OK)); print("\n".join("  ✗ " + k for k in KO))
print(f"V6.9.17 : {len(OK)}/{len(OK) + len(KO)} vérifications réussies")
sys.exit(1 if KO else 0)
