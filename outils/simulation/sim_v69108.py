"""Simulations de la V6.9.10.8 (retour du test dans Studio de la V6.9.10.7) : le vrai code.
  1. TardisConfig : Config.InvitesConsole.HauteurInvite = false (invites de la console revenues sur leur commande),
     Config.BoutonVolLibre.HauteurInvite toujours à 1,5 (seule l'invite « Vol libre » reste relevée), réglage marqué
     « (V6.9.10.8) ».
  2. Config.trouverCommande : un nom avec des espaces en trop compte aussi (« Selecteur␣ », comme dans DEVMAP) ; si
     deux objets répondent au même nom, celui où la suite du chemin existe est gardé (Colors dans le Model
     « Selecteur␣ », pas dans la pièce « Selecteur ») ; le nom exact passe d'abord ; chemin absent : nil.
  3. Le code qui pose les invites : creerPrompt (TardisServeur), jukebox (TardisExtras) et casier (Interactions)
     ne créent un point d'attache que si une hauteur est donnée ; le Vol libre passe la sienne."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from monde import *
import roblox
OK, KO = [], []
def verifier(nom, condition, detail=""):
    (OK if condition else KO).append(nom + ("" if condition else "  →  " + str(detail)))
def tache(f): lancer(Fonction("t", py=f))
def lire(chemin): return open(os.path.join(DEPOT, chemin), encoding="utf-8").read()
R = {}

cfgsrc = lire("ReplicatedStorage/TardisConfig.lua")
serveur = lire("ServerScriptService/TardisServeur/init.server.lua")
extras = lire("ServerScriptService/TardisExtras.server.lua")
interactions = lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Interactions.lua")

# ================================================================== 1. TardisConfig
roblox.charger_module.__defaults__[0].clear(); roblox.ERREURS.clear()
I, G, game, pilote = monde(serveur=True)
rs = game.m_FindFirstChild("ReplicatedStorage")
tache(lambda: R.update(Config=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisConfig")]))))
Config = R["Config"]
verifier("1. Vrai TardisConfig chargé, version 6.9.10.8 ou suivante", Config is not None and tuple(int(x) for x in str(Config.get("Version")).split(".")) >= (6, 9, 10, 8) and not roblox.ERREURS, (Config and Config.get("Version"), roblox.ERREURS[:3]))
IC, BV = Config.get("InvitesConsole"), Config.get("BoutonVolLibre")
verifier("1. Config.InvitesConsole.HauteurInvite = false : invites de la console sur leur commande", IC.get("HauteurInvite") is False, IC.get("HauteurInvite"))
verifier("1. Config.BoutonVolLibre.HauteurInvite = 1,5 : seule l'invite « Vol libre » reste relevée", BV.get("HauteurInvite") == 1.5, BV.get("HauteurInvite"))
ligne = [l for l in cfgsrc.splitlines() if l.strip().startswith("HauteurInvite = false")]
verifier("1. Réglage marqué « (V6.9.10.8) »", len(ligne) == 1 and "(V6.9.10.8)" in ligne[0], ligne)

# ================================================================== 2. Config.trouverCommande
tc = Config.get("trouverCommande")
def chercher(racine, cle, attente=None):
    R.pop("t", None)
    tache(lambda: R.update(t=premier(appeler(tc, [racine, cle] + ([attente] if attente is not None else [])))))
    return R.get("t")

# DEVMAP : une pièce « Selecteur » sans enfant, et un Model « Selecteur␣ » qui contient Colors
salle = Instance("Model", "INTERIEURE"); console = Instance("Model", "Console", salle)
sel_piece = Instance("Part", "Selecteur", console)
sel_model = Instance("Model", "Selecteur ", console)
colors = Instance("Model", "Colors", sel_model)
verifier("2. DEVMAP : Colors trouvé dans le Model « Selecteur␣ » malgré la pièce « Selecteur » (sans Colors)", chercher(salle, "VolLibre") is colors, R.get("t") and R["t"].Name)
verifier("2. … avec une attente aussi (premier passage sans attendre : rien ne bloque)", chercher(salle, "VolLibre", 10) is colors)
verifier("2. Le Selecteur lui-même : la pièce au nom exact passe avant « Selecteur␣ »", chercher(salle, "Selecteur") is sel_piece, R.get("t") and repr(R["t"].Name))

# Rangement normal : Colors dans la pièce Selecteur
salle2 = Instance("Model", "INTERIEURE"); console2 = Instance("Model", "Console", salle2)
sel2 = Instance("Part", "Selecteur", console2); colors2 = Instance("Model", "Colors", sel2)
leurre = Instance("Model", " Selecteur  ", console2); Instance("Model", "Colors", leurre)
verifier("2. Rangement normal : le Colors de la pièce au nom exact est gardé (espaces avant et après aussi acceptés)", chercher(salle2, "VolLibre") is colors2)

# Espaces en trop à chaque niveau
salle3 = Instance("Model", "INTERIEURE"); c3 = Instance("Model", "Console ", salle3)
s3 = Instance("Model", "  Selecteur", c3); col3 = Instance("Part", "Colors\t", s3)
verifier("2. Espaces (ou tabulation) en trop à chaque niveau du chemin", chercher(salle3, "VolLibre") is col3)

# Absent
salle4 = Instance("Model", "INTERIEURE"); c4 = Instance("Model", "Console", salle4); Instance("Part", "Selecteur", c4)
verifier("2. Chemin absent (sans attente) : nil, sans erreur", chercher(salle4, "VolLibre") is None and not roblox.ERREURS, roblox.ERREURS[:3])
salle5 = Instance("Model", "INTERIEURE"); Instance("Model", "Console", salle5)
verifier("2. Pas de « Selecteurs » ni de « Sélecteur » : seuls les espaces en trop sont tolérés",
         [chercher(salle5, "VolLibre"), (Instance("Model", "Selecteurs", salle5.m_FindFirstChild("Console")), chercher(salle5, "VolLibre"))[1]] == [None, None])
verifier("2. Clé inconnue ou racine absente : nil", chercher(salle, "PasUneCommande") is None and chercher(None, "VolLibre") is None)
verifier("2. Aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])

# ================================================================== 3. Où les invites sont posées
cp = serveur[serveur.index("local function creerPrompt("):serveur.index("local dernierUsage = 0")]
verifier("3. creerPrompt : point d'attache seulement si une hauteur est donnée, sinon l'invite reste sur la pièce",
         "local h = hauteur or (Config.InvitesConsole or {}).HauteurInvite" in cp and "if h then attache, point = Config.pointInvite(objet or part, h, exclu, part) end" in cp
         and "prompt.Parent = attache or part" in cp and "return prompt, point or part.Position" in cp)
verifier("3. Vol libre : sa propre hauteur (Config.BoutonVolLibre.HauteurInvite, 1,5 par défaut)", "reglagesBouton.HauteurInvite or 1.5" in serveur)
verifier("3. Jukebox (TardisExtras) : sur sa pièce quand la hauteur vaut false",
         'invites.HauteurInvite and Config.pointInvite(objet, invites.HauteurInvite, nil, part, "TardisJukebox") or part' in extras)
verifier("3. Casier (Interactions) : sur sa pièce quand la hauteur vaut false",
         'invites.HauteurInvite and Config.pointInvite(objet, invites.HauteurInvite, nil, part, "TardisCasierConsole") or part' in interactions)


print("\n".join("  ✓ " + o for o in OK)); print("\n".join("  ✗ " + k for k in KO))
print(f"V6.9.10.8 : {len(OK)}/{len(OK) + len(KO)} vérifications réussies")
sys.exit(1 if KO else 0)
