"""Simulations de la V7.1.2 (banc d'essai des simulations) : les vrais scripts du TARDIS lancés ensemble dans une fausse place.
  1. Version 7.1.2 (le vrai TardisConfig).
  2. T-202 : simulations rangées par sujet (sim_voyage, sim_effets, sim_outils), index des sujets et filtre de lancer.sh.
  3. T-204 : les 6 vrais Scripts serveur démarrent ensemble (banc.py) : « serveur prêt », « extras prêts », « systèmes prêts »,
     Supervision, pont ; diagnostic complet ; aucune erreur, aucune attente sans fin.
  4. T-205 : chaque pièce facultative retirée tour à tour (cabine, salle, commandes facultatives, sons, équipe C.A.T.) :
     tout démarre quand même, sans erreur ; le diagnostic signale les pièces suivies. Commande obligatoire absente :
     message clair de Config.Trouver (chemin complet), puis attente.
  5. T-206 : les 9 vrais LocalScripts démarrent (Streaming) ; la salle, la cabine, le rotor, les portails et le canal
     du serveur arrivent en retard : les scripts attendent puis repartent, sans erreur et sans rester bloqués.
  6. Le simulateur : WaitForChild qui attend pour de vrai, `script` propre à chaque script, tâches arrêtées entre deux places."""
import os, sys, re
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from banc import *
import roblox
OK, KO = [], []
def verifier(nom, condition, detail=""):
    (OK if condition else KO).append(nom + ("" if condition else "  →  " + str(detail)))
SIM = os.path.dirname(os.path.abspath(__file__))
def version(v): return tuple(int(n) for n in str(v).split("."))
def lire(chemin): return open(os.path.join(DEPOT, chemin), encoding="utf-8").read()

# ================================================================== 1. Version
config = lire("ReplicatedStorage/TardisConfig.lua")
v = re.search(r'Config\.Version = "([\d.]+)"', config).group(1)
verifier("1. Config.Version 7.1.2 ou plus récente", version(v) >= (7, 1, 2), v)

# ================================================================== 2. T-202 : rangées par sujet
lanceur = open(os.path.join(SIM, "lancer.sh"), encoding="utf-8").read()
liste = re.search(r"for s in ([^;]+); do", lanceur).group(1).split()
for nouveau, ancien in (("sim_voyage", "sim_v697"), ("sim_effets", "sim_v699"), ("sim_outils", "sim_v698")):
    verifier(f"2. {ancien} devient {nouveau} (fichier et lancer.sh)",
             os.path.exists(os.path.join(SIM, nouveau + ".py")) and not os.path.exists(os.path.join(SIM, ancien + ".py"))
             and nouveau in liste and ancien not in liste)
index = dict(re.findall(r"\t\t(sim_\w+)\) echo \"([^\"]*)\" ;;", lanceur))
verifier("2. Chaque simulation de lancer.sh a ses sujets dans l'index (et l'index ne cite rien d'autre)",
         sorted(index) == sorted(liste) and all(index[s].strip() for s in liste), set(index) ^ set(liste))
verifier("2. lancer.sh <sujet> : filtre par sujet ou par nom, analyse statique seulement sans filtre",
         'filtre="$1"' in lanceur and 'grep -qw -- "$filtre"' in lanceur and '[ "$s" != "$filtre" ]' in lanceur
         and '[ -z "$filtre" ] || [ "$filtre" = "analyse" ]' in lanceur)
verifier("2. Sujet inconnu : échec clair (aucune simulation lancée)", "aucune simulation pour le sujet" in lanceur and "lancees -eq 0" in lanceur)
for sujet in ("voyage", "effets", "console", "pannes", "banc"):
    verifier(f"2. Le sujet « {sujet} » regroupe au moins une simulation", any(sujet in index[s].split() for s in liste))
lisez = open(os.path.join(SIM, "LISEZMOI.md"), encoding="utf-8").read()
verifier("2. LISEZMOI : nouveaux noms, index des sujets et banc d'essai",
         all(n in lisez for n in ("sim_voyage.py", "sim_effets.py", "sim_outils.py", "banc.py", "sim_v712.py", "lancer.sh voyage"))
         and "sim_v697.py" not in lisez)

# ================================================================== 3. T-204 : démarrage complet du serveur
P = place()
sortie, erreurs = demarrer_serveur(P, duree=20)
def ligne(motif): return next((x for x in sortie if motif in x), None)
verifier("3. Les 6 Scripts serveur chargés depuis le dépôt", len(SCRIPTS_SERVEUR) == 6 and all(os.path.exists(os.path.join(DEPOT, "ServerScriptService", s)) for s in SCRIPTS_SERVEUR))
verifier("3. « TARDIS_1 : serveur prêt (V…) » avec la version de Config", ligne(f"serveur prêt (V{v})") is not None, sortie[:4])
for motif in ("extras prêts", "systèmes prêts", "Supervision prête", "Pont intercom prêt"):
    verifier(f"3. « {motif} »", ligne(motif) is not None, sortie[:12])
diag = ligne("diagnostic ·")
verifier("3. Diagnostic : toutes les commandes obligatoires et tous les sons", diag is not None and re.search(r"obligatoires (\d+)/\1 ", diag) and re.search(r"sons (\d+)/\1 ", diag), diag)
verifier("3. Aucune erreur au démarrage ni dans une tâche", not erreurs, erreurs[:3])
verifier("3. Aucune attente sans fin (« Infinite yield possible »)", not roblox.ATTENTES, roblox.ATTENTES[:3])
verifier("3. Le canal TardisCommande_TARDIS_1 créé par le serveur", P["rs"].m_FindFirstChild("TardisCommande_TARDIS_1") is not None)
verifier("3. Une seule ligne « serveur prêt » (pas de copie pour TARDIS_2 ou TARDIS_3)", sum("serveur prêt" in x for x in sortie) == 1)

# ================================================================== 4. T-205 : pièces manquantes
def absentes(d):
    m = re.search(r"absentes : (.*)$", d or ""); return set(x.strip() for x in m.group(1).split(",")) if m else set()
def optionnelles(d):
    m = re.search(r"optionnelles (\d+)/(\d+)", d or ""); return int(m.group(1)) if m else -1
base_abs, base_opt = absentes(diag), optionnelles(diag)
OBLIGATOIRES_BLOQUANTES = ("cmd/Levier",)  # attendue au démarrage, avant « serveur prêt »
ATTENDUES = {"cmd/Verrou": "LeverLeft"}     # attendue dans une tâche : le serveur démarre, l'attente est signalée
plantes, muets, signalees = [], [], []
for m in FACULTATIVES + ["sons", "equipe/C.A.T."]:
    if m in OBLIGATOIRES_BLOQUANTES: continue
    P = place(manque=(m,))
    s, e = demarrer_serveur(P, duree=70)
    prets = sum(1 for x in s if "prêt" in x)
    attentes = [a for a in roblox.ATTENTES if not (m in ATTENDUES and ATTENDUES[m] in a)]
    if e or prets != 5 or attentes: plantes.append((m, prets, e[:2], attentes[:2]))
    d = next((x for x in s if "diagnostic ·" in x), None)
    nom = m.split("/", 1)[1] if "/" in m else m
    if m.startswith(("int/", "ext/")):
        if (absentes(d) - base_abs) or optionnelles(d) < base_opt: signalees.append(nom)
        else: muets.append(nom)
verifier(f"4. {len(FACULTATIVES) + 2 - len(OBLIGATOIRES_BLOQUANTES)} pièces retirées tour à tour : les 5 « prêt », aucune erreur, aucune attente imprévue",
         not plantes, plantes[:4])
# Suivies par le diagnostic (V7.1.2 : portes intérieures et vitres de la cabine en plus). Les autres : Lampe (obligatoire),
# Boucliers (dossier recréé par le serveur), Enseigne (texte en attribut), Casier et Jukebox (aussi des commandes de la console),
# Spawn C.A.T (spawn placé par le serveur s'il manque).
SUIVIES = {"Arrivee", "Vanne", "Murs", "LedsAlerte", "PortesInterieures", "Fenetres"}
verifier("4. Le diagnostic signale chaque pièce facultative qu'il suit quand elle manque (dont portes intérieures et vitres)",
         SUIVIES <= set(signalees), {"signalées": signalees, "non suivies": muets})
P = place(manque=("ext/Fenetres",)); Instance("Part", "Vitre2", P["ext"])
s, e = demarrer_serveur(P, duree=5)
d = next((x for x in s if "diagnostic ·" in x), "")
verifier("4. Vitres en pièces « Vitre… » sans dossier Fenetres : pas signalées absentes", d and "Fenetres" not in d, d)
P = place(manque=("ext/Lampe",))
s, e = demarrer_serveur(P, duree=5)
d = next((x for x in s if "diagnostic ·" in x), "")
verifier("4. Lampe absente : comptée parmi les obligatoires manquantes (13/14), sans erreur", "obligatoires 13/14" in d and not e, d)
# Commande obligatoire absente : le message clair de Config.Trouver
P = place(manque=("cmd/Levier",))
s, e = demarrer_serveur(P, duree=15)
msg = next((x for x in s if "Commande obligatoire 'Levier' introuvable" in x), None)
verifier("4. Levier absent : « Commande obligatoire 'Levier' introuvable » au bout de 10 s, avec le chemin complet",
         msg is not None and "Matlever" in msg and "Config.Chemins" in msg and "Controls" in msg, s[:6])
verifier("4. Levier absent : aucune erreur, le serveur attend (pas de « serveur prêt »)", not e and not any("serveur prêt" in x for x in s), (e[:2], s[:3]))
# il arrive enfin : le serveur repart
chemin = CHEMINS["Levier"]; parent = P["salle"]
for n in chemin[:-1]: parent = parent.m_FindFirstChild(n) or Instance("Model", n, parent)
part(chemin[-1], parent, (0, 3, 0), (1, 1, 1))
s2, e2 = demarrer_serveur(P, duree=10, scripts=[])
verifier("4. Levier posé ensuite : le serveur démarre (« serveur prêt »), sans erreur", any("serveur prêt" in x for x in roblox.SORTIE) and not roblox.ERREURS, (roblox.SORTIE[-4:], roblox.ERREURS[:2]))
P = place(manque=("cmd/Verrou",))
s, e = demarrer_serveur(P, duree=15)
verifier("4. Verrou absent : message clair aussi (attente dans une tâche, le reste démarre)",
         any("Commande obligatoire 'Verrou' introuvable" in x for x in s) and sum("prêt" in x for x in s) == 5 and not e, s[:4])
verifier("4. Config.Trouver : WaitForChild avec un délai de 10 s, puis attente sans délai", "objet:WaitForChild(nom, 10)" in config and "suivant = objet:WaitForChild(nom)" in config)

# ================================================================== 5. T-206 : pièces en retard (client)
def bilan(P): return sorted(e.Name for e in P["joueur"].m_FindFirstChild("PlayerGui").enfants)
P = place(serveur=False, streaming=True)
s0, e0 = demarrer_client(P, duree=15); b0 = bilan(P)
verifier("5. Les 9 LocalScripts démarrent (Streaming, tout présent) sans erreur", len(SCRIPTS_CLIENT) == 9 and not e0, e0[:3])
verifier("5. Aucune attente sans fin côté client quand tout est là", not roblox.ATTENTES, roblox.ATTENTES[:3])
verifier("5. Les interfaces du joueur sont créées", len(b0) >= 2, b0)
def cas_retard(nom):
    P = place(serveur=False, streaming=True); sal, ext = P["salle"], P["ext"]
    remote = True
    if nom == "salle": retarder(P, [sal], 8)
    elif nom == "cabine": retarder(P, [ext], 8)
    elif nom == "rotor": retarder(P, [sal.m_FindFirstChild("Rotor")], 8)
    elif nom == "portails": retarder(P, [sal.m_FindFirstChild("Portail"), ext.m_FindFirstChild("Portail")], 8)
    elif nom == "canal":
        remote = False; H.plus_tard(8, lambda: Instance("RemoteEvent", "TardisCommande_TARDIS_1", P["rs"]))
    elif nom == "tout":
        remote = False; retarder(P, [sal, ext], 8); H.plus_tard(9, lambda: Instance("RemoteEvent", "TardisCommande_TARDIS_1", P["rs"]))
    s, e = demarrer_client(P, duree=25, remote=remote)
    bloques = [x for x in roblox.EN_ATTENTE if "TracteurCible" not in x]  # TracteurCible : posé par le serveur (absent ici), délai de 30 s
    return e, bloques, bilan(P), list(roblox.ATTENTES)
for nom in ("salle", "cabine", "rotor", "portails", "canal", "tout"):
    e, bloques, b, att = cas_retard(nom)
    verifier(f"5. En retard de 8 s : {nom} → aucune erreur, aucun script resté bloqué, mêmes interfaces", not e and not bloques and b == b0, (e[:2], bloques, set(b) ^ set(b0)))
    if nom == "salle": verifier("5. … et l'attente est bien réelle (Roblox l'aurait signalée après 5 s)", any("INTERIEURE" in a for a in att), att[:2])

# ================================================================== 6. Le simulateur
P = place()
roblox.ATTENTE["reelle"] = True
R = {}
def essai():
    R["a"] = P["salle"].m_WaitForChild("PasEncore", 2)
    R["b"] = P["salle"].m_WaitForChild("Bientot")
roblox.lancer(Fonction("essai", py=essai)); H.plus_tard(3, lambda: Instance("Part", "Bientot", P["salle"]))
for _ in range(10): H.avancer(0.5)
verifier("6. WaitForChild avec délai : nil au bout du délai ; sans délai : attend que la pièce arrive", R.get("a") is None and R.get("b") is not None and R["b"].Name == "Bientot", R)
verifier("6. Plus aucune attente en cours ensuite", not roblox.EN_ATTENTE, roblox.EN_ATTENTE)
I, G = P["I"], P["G"]
a, b = Instance("Script", "ScriptA", P["sss"]), Instance("Script", "ScriptB", P["sss"])
src_a, src_b = roblox.propre_script(I, "task.wait(1); _G.vuA = script.Name", a), roblox.propre_script(I, "_G.vuB = script.Name", b)
roblox.lancer(Fonction("a", py=lambda: I.executer(src_a, "a"))); roblox.lancer(Fonction("b", py=lambda: I.executer(src_b, "b")))
for _ in range(4): H.avancer(0.5)
verifier("6. Chaque script garde sa propre variable `script`, même après une attente", G["_G"].get("vuA") == "ScriptA" and G["_G"].get("vuB") == "ScriptB", (G["_G"].get("vuA"), G["_G"].get("vuB")))
verifier("6. Une ligne de plus en tête, sur la même ligne (numéros de ligne inchangés)", src_a.count("\n") == 0)
avant = len(roblox.TACHES)
P = place()
verifier("6. Les tâches d'une place précédente sont arrêtées (chaque place repart de zéro)", not roblox.TACHES and avant >= 1, (avant, len(roblox.TACHES)))
verifier("6. Caméra et Lighting de la fausse place (CurrentCamera, ExposureCompensation, GetSunDirection)",
         P["ws"].props.get("CurrentCamera") is not None and "ExposureCompensation" in P["game"].m_FindFirstChild("Lighting").props)

print("\n".join("  ✓ " + o for o in OK))
print("\n".join("  ✗ " + k for k in KO))
print(f"V7.1.2 : {len(OK)}/{len(OK) + len(KO)} vérifications réussies")
sys.exit(1 if KO else 0)
