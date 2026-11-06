"""Simulations de la V6.9.8 : vérification des propositions déjà faites et nouveaux outils de suivi.
  1. Thème clair (71) : le vrai module TardisUI ; le fond des listes suit le thème et reste lisible.
  2. Vol en formation (27) : réglages dans Config, lus par le client du vol libre.
  3. Écran de destination (51) et recherche du menu rapide (69) : présents dans le code.
  4. Outils : release.py (198), etat_tests.py (199) et glossaire (200)."""
import os, sys, re, shutil, tempfile, importlib
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from monde import *
import roblox
OK, KO = [], []
def verifier(nom, condition, detail=""):
    (OK if condition else KO).append(nom + ("" if condition else "  →  " + str(detail)))
def tache(f): lancer(Fonction("t", py=f))
RACINE = os.path.normpath(os.path.join(DEPOT, ".."))
def lire(chemin): return open(os.path.join(DEPOT, chemin), encoding="utf-8").read()

# ------------------------------------------------------------------ 1. Thème clair
I, G, game, joueur = monde(serveur=False)
rs = game.m_FindFirstChild("ReplicatedStorage")
R = {}
def chargerUI():
    R["UI"] = premier(appeler(G["require"], [rs.m_FindFirstChild("TardisUI")]))
tache(chargerUI)
UI = R.get("UI")
verifier("TardisUI se charge", UI is not None and not roblox.ERREURS, roblox.ERREURS[:2])
C = UI.get("C")
rgb = lambda v: tuple(int(a) for a in v.args)
# (V6.9.10.6 : la palette de départ est gardée dans UI.BASE ; chez un joueur, le thème par défaut Confinement s'applique d'office)
verifier("Rôle « creux » dans la palette de départ", UI.get("BASE").get("creux") is not None and rgb(UI.get("BASE").get("creux")) == (4, 10, 24)
         and C.get("creux") is not None and rgb(C.get("creux")) == rgb(UI.get("THEMES").get("Confinement").get("creux")), C.get("creux"))
themes = UI.get("THEMES")
noms = ["Gallifrey", "Cristal", "PoliceBox"]
verifier("Chaque thème donne sa couleur « creux »", all(themes.get(n).get("creux") is not None for n in noms))
# Un cadre créé avec C.creux, puis changement de thème : il est recoloré
cadre = {}
def creerCadre():
    ecran = Instance("ScreenGui", "TardisTablette")  # seuls les éléments affichés (avec un parent) sont recolorés
    cadre["f"] = premier(appeler(UI.get("creer"), ["Frame", Table({"BackgroundColor3": C.get("creux"), "Parent": ecran})]))
tache(creerCadre)
f = cadre.get("f")
def theme(nom): tache(lambda: appeler(UI.get("appliquerTheme"), [nom]))
theme("Gallifrey")
verifier("Gallifrey : fond des listes clair", f is not None and rgb(f.props["BackgroundColor3"]) == (226, 218, 202), f and f.props.get("BackgroundColor3"))
theme("Cristal")
verifier("Cristal : fond des listes sombre", rgb(f.props["BackgroundColor3"]) == (4, 6, 18), f.props.get("BackgroundColor3"))
theme("Gallifrey")
verifier("Retour à Gallifrey : fond clair à nouveau", rgb(f.props["BackgroundColor3"]) == (226, 218, 202))
# Lisibilité : contraste texte / fond des listes (WCAG, 4,5 minimum pour un texte normal)
def luminance(c):
    def canal(x):
        x = x / 255
        return x / 12.92 if x <= 0.03928 else ((x + 0.055) / 1.055) ** 2.4
    r, g, b = c
    return 0.2126 * canal(r) + 0.7152 * canal(g) + 0.0722 * canal(b)
def contraste(a, b):
    la, lb = sorted((luminance(a), luminance(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)
for n in noms:
    t = themes.get(n)
    k = contraste(rgb(t.get("texte")), rgb(t.get("creux")))
    verifier(f"{n} : texte lisible sur le fond des listes (contraste {k:.1f})", k >= 4.5, k)
# Avant la V6.9.8, le fond (4, 10, 24) restait sombre en Gallifrey : texte foncé illisible
verifier("Ancien fond sombre illisible en Gallifrey (le défaut corrigé)", contraste(rgb(themes.get("Gallifrey").get("texte")), (4, 10, 24)) < 2)
verifier("Plus de fond de liste écrit en dur (menu T, tablette)",
         "Color3.fromRGB(4, 10, 24)" not in lire("StarterPlayer/StarterPlayerScripts/TardisMenu.client.lua")
         and "Color3.fromRGB(4, 10, 24)" not in lire("StarterPlayer/StarterPlayerScripts/TardisTablette/Construction.lua"))
verifier("Thème clair : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])

# ------------------------------------------------------------------ 2. Vol en formation
roblox.ERREURS.clear()
R2 = {}
tache(lambda: R2.__setitem__("Config", premier(appeler(G["require"], [rs.m_FindFirstChild("TardisConfig")]))))
F = R2["Config"].get("VolLibre").get("Formation")
verifier("Config.VolLibre.Formation", F is not None and (F.get("Distance"), F.get("Hauteur"), F.get("Portee")) == (14, 16, 200),
         F and (F.get("Distance"), F.get("Hauteur"), F.get("Portee")))
client = lire("StarterPlayer/StarterPlayerScripts/TardisVolLibre.client.lua")
verifier("Le client lit les trois réglages de formation", all(f"reglages.Formation.{k}" in client for k in ("Distance", "Hauteur", "Portee")))
verifier("Suivi de la cible : distance et hauteur venues de Config", "objet.Position - regard * R.FORMATION_DISTANCE + Vector3.new(0, R.FORMATION_HAUTEUR, 0)" in client)
verifier("Choix de la cible : portée venue de Config", "vers.Magnitude < R.FORMATION_PORTEE" in client and "< 200 then" not in client)
# Le calcul de la position voulue, rejoué : derrière la cible, au-dessus
def voulu(pos, regard, d=14, h=16): return (pos[0] - regard[0] * d, pos[1] + h, pos[2] - regard[2] * d)
verifier("Formation : 14 studs derrière, 16 au-dessus", voulu((0, 5, 0), (0, 0, -1)) == (0, 21, 14))
verifier("Touche L toujours liée au verrouillage", "TOUCHE_CIBLE = Enum.KeyCode.L" in client and 'UI.touche("volCible", R.TOUCHE_CIBLE)' in client)

# ------------------------------------------------------------------ 3. Écran de destination et recherche du menu T
serveur = lire("ServerScriptService/TardisServeur/init.server.lua")
# (V6.9.10.1 : l'écran est fait par le module TardisServeur › Ecrans, sur un ou plusieurs écrans : voir sim_v69101)
ecrans = lire("ServerScriptService/TardisServeur/Ecrans.lua")
verifier("Écran de la console : « DESTINATION » puis le lieu", 'textes.Etiquette.Text = "DESTINATION"' in ecrans and "t.Destination.Text = dest and string.upper(dest.Name)" in ecrans)
menu = lire("StarterPlayer/StarterPlayerScripts/TardisMenu.client.lua")
# (V6.9.10.6 : le champ vient de UI.champRecherche, « Rechercher une destination » comme sur la charte)
verifier("Menu rapide : champ de recherche relié à la liste",
         "local recherche = UI.champRecherche(" in menu and 'PlaceholderText = "Rechercher une destination"' in lire("ReplicatedStorage/TardisUI.lua")
         and 'recherche:GetPropertyChangedSignal("Text"):Connect(construireListe)' in menu and "string.lower(recherche.Text)" in menu)

# ------------------------------------------------------------------ 4. Outils de suivi
sys.path.insert(0, os.path.join(RACINE, "outils"))
import suivi_versions, release, etat_tests
verifier("Tri des versions numérique (V6.9.10 après V6.9.9)", suivi_versions.cle_tri("V6.9.10") > suivi_versions.cle_tri("V6.9.9"))
versions = [v["version"] for v in release.suivies()]
verifier("release.py : V6.5 → V6.9.7 suivies, sans plages", versions[0] == "V6.5" and "V6.9.7" in versions and not any("–" in v for v in versions), versions[:3])
manquantes = [v for v in release.suivies() if release.tag_de(v["version"]) not in release.publiees()]
attendues = [v["version"] for v in release.suivies() if suivi_versions.cle_tri(v["version"]) > (6, 6, 6)]
verifier("release.py : à rattraper = tout ce qui suit V6.6.6 (au moins V6.7 → V6.9.7)",
         [m["version"] for m in manquantes] == attendues and len(attendues) >= 14 and attendues[0] == "V6.7", [m["version"] for m in manquantes])
titre, texte = release.texte_release(next(v for v in release.suivies() if v["version"] == "V6.9.7"))
verifier("Texte de release : titre, tag et lien vers l'état des tests",
         titre == "V6.9.7 — Corrections : TARDIS bloqué ou perdu" and "`v6.9.7`" in texte and "ETAT_DES_TESTS.md" in texte, titre)
verifier("Texte de release : liens relatifs rendus complets",
         "](../" not in texte and release.liens_absolus("[a](../GLOSSAIRE.md) [b](https://x.y) [c](#ancre)")
         == "[a](https://github.com/StudioRbx/T.A.R.D.I.S/blob/main/docs/GLOSSAIRE.md) [b](https://x.y) [c](#ancre)")
verifier("Titre de release sans date ni mention d'installation",
         suivi_versions.titre_propre("Mode Express (29/10/2026) ⭐ installée dans ZONE-TSADE") == "Mode Express")
# État des tests : sur une copie, un résultat noté survit à la régénération
tmp = tempfile.mkdtemp()
page = os.path.join(tmp, "ETAT.md")
shutil.copy(os.path.join(RACINE, "docs", "ETAT_DES_TESTS.md"), page)
from pathlib import Path
etat_tests.PAGE = Path(page)
txt = open(page, encoding="utf-8").read()
cible = "| Son de démat à 50, 150 et 300 studs | fort, faible, plus rien | ⬜ |  |"
verifier("Page d'état : le test du son de la V6.9.7 est listé", cible in txt)
open(page, "w", encoding="utf-8").write(txt.replace(cible, cible.replace("| ⬜ |  |", "| ✅ | essai simulé |")))
total, compte = etat_tests.generer()
apres = open(page, encoding="utf-8").read()
verifier("Régénération de la page : le ✅ noté est gardé", "| ✅ | essai simulé |" in apres and compte["✅"] == 1, compte)
verifier("Régénération : les ➖ (fonctions retirées) sont gardés", compte["➖"] == 18, compte)
avecTests = [v for v in suivi_versions.lire_versions() if "–" not in v["version"] and suivi_versions.tableaux_a_tester(v["lignes"])]
verifier("Chaque version avec un tableau « À tester » a sa section", apres.count("\n## V") == len(avecTests) >= 13
         and total == sum(len(suivi_versions.tableaux_a_tester(v["lignes"])) for v in avecTests) >= 81, (total, apres.count("\n## V")))
shutil.rmtree(tmp)
# Glossaire
glossaire = open(os.path.join(RACINE, "docs", "GLOSSAIRE.md"), encoding="utf-8").read()
termes = ["Démat", "Remat", "Vortex", "Classique", "Urgence", "Rapide", "Sauvetage", "Silencieux", "Catastrophe", "C.A.T.", "C.T.A.T.", "Pilote", "Technicien", "Copilote"]
manque = [t for t in termes if f"**{t}" not in glossaire]
verifier("Glossaire : démat, remat, vortex, les modes et les équipes", not manque, manque)
modes = re.findall(r"^\t(\w+) = \{", lire("ReplicatedStorage/TardisConfig.lua").split("Config.Modes = {")[1].split("\n}")[0], re.M)
verifier("Glossaire : chaque mode de Config.Modes est expliqué", all(m in glossaire for m in modes), modes)

print("\n".join("  ✓ " + o for o in OK))
print("\n".join("  ✗ " + k for k in KO))
print(f"V6.9.8 : {len(OK)}/{len(OK) + len(KO)} vérifications réussies")
sys.exit(1 if KO else 0)
