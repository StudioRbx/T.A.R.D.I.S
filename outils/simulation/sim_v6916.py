"""Simulations de la V6.9.16 : retouches de la console (le vrai code, lu dans le dépôt).
  1. Invite « Vol libre » plus basse : Config.BoutonVolLibre.HauteurInvite = 0,9 (1,5 avant), même valeur par défaut
     côté serveur.
  2. Écran ingénieur à l'endroit : sur la face Top, le haut de la SurfaceGui va vers -X (repereFace) ; tailleFace inchangé.
  3. Écran ingénieur sans invite : plus de ProximityPrompt (touche et texte « Gestion de l'énergie »), le ClickDetector suffit.
  4. Menu de gestion de l'énergie plus large : 760 × 640, deux colonnes (ÉTAT + pannes en cours, RÉGULATION + plages).
  5. Animation du kit : BindableEvent « TardisAnimer » cherché sur la pièce et jusqu'à 3 parents, déclenché quand la
     commande réussit (commandes à attribut et verrou), jamais en cas d'échec.
  6. Version 6.9.16, ajouts marqués « V6.9.16 ».
Le comportement en jeu (écran, menu, clic) est aussi vérifié par sim_v69101, sim_v69103, sim_v69104 et sim_v69107."""
import os, sys, re
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from monde import DEPOT
OK, KO = [], []
def verifier(nom, condition, detail=""):
    (OK if condition else KO).append(nom + ("" if condition else "  →  " + str(detail)))
def lire(chemin): return open(os.path.join(DEPOT, chemin), encoding="utf-8").read()
def version(v): return tuple(int(x) for x in str(v).split(".") if x.isdigit())

config = lire("ReplicatedStorage/TardisConfig.lua")
serveur = lire("ServerScriptService/TardisServeur/init.server.lua")
ecrans = lire("ServerScriptService/TardisServeur/Ecrans.lua")
console = lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Console.lua")

# ================================================================== 1. Invite « Vol libre »
bloc = config[config.find("Config.BoutonVolLibre"):]
bloc = bloc[:bloc.find("\n}")]
lignes = [l for l in bloc.splitlines() if l.strip().startswith("HauteurInvite")]
verifier("1. Config.BoutonVolLibre.HauteurInvite = 0.9, marqué « V6.9.16 »",
         len(lignes) == 1 and re.match(r"\s*HauteurInvite\s*=\s*0\.9\s*,", lignes[0]) and "(V6.9.16) 1,5 → 0,9" in bloc, lignes)
verifier("1. Serveur : même valeur par défaut (0.9) si le réglage manque", "reglagesBouton.HauteurInvite or 0.9" in serveur
         and "reglagesBouton.HauteurInvite or 1.5" not in serveur)

# ================================================================== 2. Écran ingénieur à l'endroit
verifier("2. repereFace : face Top → (UpVector, -RightVector), marqué « V6.9.16 »",
         re.search(r"if face == Enum\.NormalId\.Top then return cf\.UpVector, -cf\.RightVector end -- \(V6\.9\.16\)", ecrans) is not None)
verifier("2. repereFace : plus de haut vers +X sur la face Top", "NormalId.Top then return cf.UpVector, cf.RightVector end" not in ecrans)

# ================================================================== 3. Écran ingénieur sans invite
verifier("3. Plus de ProximityPrompt « TardisEcranIngenieur » ni de texte « Gestion de l'énergie » dans Ecrans",
         'Instance.new("ProximityPrompt")' not in ecrans and "ActionText = \"Gestion de l'énergie\"" not in ecrans)
verifier("3. Le ClickDetector reste et ouvre le menu", 'Instance.new("ClickDetector")' in ecrans and "clic.MouseClick:Connect(cliquerIngenieur)" in ecrans)

# ================================================================== 4. Menu de gestion de l'énergie
def const(nom):
    m = re.search(r"local " + nom + r"\s*=\s*(\d+)", console)
    return int(m.group(1)) if m else None
verifier("4. Menu 760 × 640 (LARGEUR_ENERGIE, HAUTEUR_ENERGIE), passé au panneau",
         "local LARGEUR_ENERGIE, HAUTEUR_ENERGIE = 760, 640" in console and 'panneau("TardisMenuEnergie", LARGEUR_ENERGIE, HAUTEUR_ENERGIE)' in console)
verifier("4. Deux colonnes : ÉTAT (avec les pannes en cours) et RÉGULATION",
         "colRegulation" in console and "Pannes en cours" in console and const("HAUTEUR_COLONNES") == 432, const("HAUTEUR_COLONNES"))
verifier("4. Plages de la régulation affichées (tension nominale, air vicié, vapeur normale)",
         "Nominal %d–%d %%" in console and "Vicié sous %d %%" in console and "Normal : 50 %" in console)

# ================================================================== 5. Animation du kit
debut = serveur.find("local function animerKit(part)")
corps = serveur[debut:serveur.find("\nend\n", debut) + 5]
verifier("5. animerKit : BindableEvent « TardisAnimer », la pièce et 3 parents au plus, sans sortir de l'intérieur",
         debut >= 0 and 'local NOM_ANIMATION = "TardisAnimer"' in serveur and "for _ = 0, 3 do" in corps
         and "o == interieur then return end" in corps and 'ev:IsA("BindableEvent")' in corps and "ev:Fire()" in corps, corps[:200])
appels = re.findall(r"animerKit\((\w+)\) -- \(V6\.9\.16\)", serveur)
verifier("5. Déclenché après une commande réussie et après le verrou", appels == ["part", "partVerrou"], appels)
ok_avant = all(serveur[:serveur.find(f"animerKit({a}) -- (V6.9.16)")].rstrip().endswith("if ok then") for a in appels)
verifier("5. Seulement quand la commande a réussi (juste après « if ok then »)", ok_avant and len(appels) == 2)

# ================================================================== 6. Version et repères
m = re.search(r'Config\.Version\s*=\s*"([\d.]+)"', config)
verifier("6. Config.Version = 6.9.16 ou plus récente", m and version(m.group(1)) >= (6, 9, 16), m and m.group(1))
for nom, src in (("TardisConfig", config), ("TardisServeur", serveur), ("Ecrans", ecrans)):
    verifier(f"6. {nom} : ajouts marqués « V6.9.16 »", "V6.9.16" in src)

print("\n".join("  ✓ " + o for o in OK)); print("\n".join("  ✗ " + k for k in KO))
print(f"V6.9.16 : {len(OK)}/{len(OK) + len(KO)} vérifications réussies")
sys.exit(1 if KO else 0)
