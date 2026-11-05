"""Simulation du paquet de mise à jour pour Studio (outils/paquet_studio.py + outils/installer_paquet.luau).
Le vrai script d'installation est exécuté sur une fausse place « ancienne version » : scripts à jour, périmés,
absents, de mauvais type, ancien nom à supprimer, script inconnu à signaler ; puis une seconde fois (rien à réécrire).
Comme dans Roblox, # et string.byte comptent des octets UTF-8 (roblox.py)."""
import os, sys, re, json, tempfile, importlib
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from monde import *
import roblox
from luau import Interp
OK, KO = [], []
def verifier(nom, condition, detail=""):
    (OK if condition else KO).append(nom + ("" if condition else "  →  " + str(detail)))
RACINE = os.path.normpath(os.path.join(DEPOT, ".."))
sys.path.insert(0, os.path.join(RACINE, "outils"))
import paquet_studio
import xml.etree.ElementTree as ET

# 1. Paquet : XML valide, chaque script identique au dépôt
sortie = tempfile.mkdtemp()
import io, contextlib
with contextlib.redirect_stdout(io.StringIO()):
    chemin = paquet_studio.principal(sortie)
racine = ET.parse(chemin).getroot()
modules = {}
for it in racine.iter("Item"):
    if it.get("class") == "ModuleScript":
        p = it.find("Properties")
        modules[p.find("string[@name='Name']").text] = p.find("ProtectedString[@name='Source']").text
infos = json.loads(re.match(r"return \[==\[(.*)\]==\]$", modules["_manifeste"], re.S).group(1))
verifier("Paquet : XML valide, un module par script + le manifeste", len(modules) == len(infos["entrees"]) + 1, len(modules))
identiques = all(modules[e["cle"]].encode("utf-8") == open(os.path.join(RACINE, e["fichier"]), "rb").read() for e in infos["entrees"])
verifier("Paquet : chaque script identique octet pour octet au dépôt", identiques)

# 2. Fausse place Studio
I, G, game, joueur = monde(serveur=True)
Instance("ScriptEditorService", "ScriptEditorService", game)
ses = game.m_FindFirstChild("ScriptEditorService")
ses.m_UpdateSourceAsync = lambda s, f: s.props.__setitem__("Source", premier(appeler(f, [s.props.get("Source", "")]))) or []
ws = game.m_FindFirstChild("Workspace")
octets = lambda t: t  # les chaînes restent en Unicode : # et string.byte comptent les octets UTF-8, comme Roblox
# TARDIS_1 avec ses portes
tardis = Instance("Folder", "TARDIS", ws)
for n in ("TARDIS_1",):
    d = Instance("Folder", n, tardis); ext = Instance("Folder", "EXTERIEURE", d); mod = Instance("Model", "Cabine", ext)
    portes = Instance("Model", "TARDISDoors", mod); Instance("Model", "LeftDoor", portes); Instance("Model", "RightDoor", portes)
# Ancienne version : certains scripts à jour, d'autres périmés, d'autres absents
entrees = infos["entrees"]
def parent_de(e):
    obj = game
    for nom in e["parent"].split("/"):
        if obj is None: return None
        obj = game.m_FindFirstChild(nom) if obj is game else obj.m_FindFirstChild(nom)
    return obj
spp = Instance("StarterPlayerScripts", "StarterPlayerScripts", game.m_FindFirstChild("StarterPlayer"))
a_jour = perimes = 0
for i, e in enumerate(entrees):
    if e["parTardis"] or i % 3 == 2: continue          # absents : à créer
    p = parent_de(e)
    if p is None: continue
    s = Instance(e["classe"], e["nom"], p)
    if i % 3 == 0: s.props["Source"] = octets(modules[e["cle"]]); a_jour += 1
    else: s.props["Source"] = "-- ancienne version"; perimes += 1
Instance("LocalScript", "Tardisporter", spp).props["Source"] = "-- ancien nom"
Instance("Script", "TardisVieuxScript", game.m_FindFirstChild("ServerScriptService")).props["Source"] = "-- inconnu"
# Le paquet inséré dans Workspace
dossier = Instance("Folder", "TARDIS_MiseAJour", ws)
for nom, src in modules.items():
    Instance("ModuleScript", nom, dossier).props["Source"] = octets(src)
# LuaSourceContainer : classe parente des scripts
ancien_isa = roblox.Instance.m_IsA
roblox.Instance.m_IsA = lambda s, c: ancien_isa(s, c) or (c == "LuaSourceContainer" and s.ClassName in ("Script", "LocalScript", "ModuleScript"))
code = open(os.path.join(RACINE, "outils", "installer_paquet.luau"), encoding="utf-8").read()
def installer():
    roblox.SORTIE.clear()
    I.pas = 0  # le calcul des empreintes (1 Mo de code, deux fois) dépasse le garde-fou cumulé de l'interpréteur
    lancer(Fonction("installer", py=lambda: I.executer(code, "installer_paquet")))
    return "\n".join(str(x) for x in roblox.SORTIE)
rapport = installer()
verifier("Installation sans erreur Luau", not roblox.ERREURS, roblox.ERREURS[:2])
fin = rapport.strip().splitlines()[-1] if rapport.strip() else ""
verifier("Rapport : 0 erreur, paquet retiré", " 0 erreur(s)" in fin and "paquet retiré" in fin, fin)
tous = all(s is not None and premier([s.props.get("Source")]) == octets(modules[e["cle"]])
           for e in entrees for s in ([parent_de(e).m_FindFirstChild(e["nom"])] if not e["parTardis"] else []))
verifier("Chaque script hors TARDIS est à jour et du bon type", tous)
portes = [p for p in ("LeftDoor", "RightDoor")]
cab = tardis.m_FindFirstChild("TARDIS_1").m_FindFirstChild("EXTERIEURE").m_FindFirstChild("Cabine").m_FindFirstChild("TARDISDoors")
verifier("Scripts des portes posés dans la cabine de TARDIS_1", all(cab.m_FindFirstChild(p).m_FindFirstChild("Shut") is not None for p in portes))
nb = len(entrees) - a_jour + 1  # périmés + absents, + la seconde porte
verifier(f"Seuls les scripts qui diffèrent sont réécrits ({nb})", f"{nb} réécrit(s)" in fin, fin)
verifier("Ancien nom « Tardisporter » supprimé", spp.m_FindFirstChild("Tardisporter") is None and "supprimé : StarterPlayer/StarterPlayerScripts/Tardisporter" in rapport)
verifier("Script inconnu signalé, pas supprimé", "à vérifier (absent du dépôt)" in rapport and game.m_FindFirstChild("ServerScriptService").m_FindFirstChild("TardisVieuxScript") is not None)
verifier("Dossier du paquet retiré", ws.m_FindFirstChild("TARDIS_MiseAJour") is None)
# Seconde installation : rien à réécrire
dossier = Instance("Folder", "TARDIS_MiseAJour", ws)
for nom, src in modules.items():
    Instance("ModuleScript", nom, dossier).props["Source"] = octets(src)
fin2 = installer().strip().splitlines()[-1]
verifier("Seconde installation : 0 réécrit, 0 erreur", "0 réécrit(s), 0 erreur(s)" in fin2, fin2)
# Paquet abîmé : refusé et gardé
dossier = Instance("Folder", "TARDIS_MiseAJour", ws)
for nom, src in modules.items():
    Instance("ModuleScript", nom, dossier).props["Source"] = octets(src)
dossier.m_FindFirstChild(entrees[0]["cle"]).props["Source"] = "-- abîmé"
fin3 = installer()
verifier("Paquet abîmé : erreur signalée, script non écrit, paquet gardé",
         "ERREUR paquet abîmé" in fin3 and ws.m_FindFirstChild("TARDIS_MiseAJour") is not None, fin3.strip().splitlines()[-1])
roblox.Instance.m_IsA = ancien_isa

print("\n".join("  ✓ " + o for o in OK))
print("\n".join("  ✗ " + k for k in KO))
print(f"PAQUET : {len(OK)}/{len(OK) + len(KO)} vérifications réussies")
sys.exit(1 if KO else 0)
