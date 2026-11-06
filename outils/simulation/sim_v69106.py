"""Simulations de la V6.9.10.6 : la charte « Hologramme de confinement » sur tous les menus du TARDIS (le vrai code).
  1. TardisUI : jetons de la charte (couleurs exactes), polices (Michroma, Titillium Web, Roboto Mono), thème Confinement
     en tête des réglages et appliqué d'office chez les joueurs (pas sur le serveur : écrans de la console inchangés).
  2. Migration unique : un ancien thème sauvegardé passe une fois à Confinement (et c'est sauvegardé) ; un choix fait
     ensuite (Gallifrey…) est gardé ; un nouveau joueur n'envoie rien.
  3. Briques : panneau à coins coupés sans image (traits en biais) et avec les images 9 tranches (SliceCenter, SliceScale),
     changement de thème (décor des anciens thèmes), bande de danger qui passe au rouge avec l'alerte, jauge à 10 segments,
     tableau (ligne choisie jaune), boutons à variante, puces, notification (TARDIS / ALERTE / REFUSÉ), « Réduire les effets ».
  4. Le vrai menu rapide (TardisMenu, touche T) : plaque, bande liée à l'alerte, tableau DESTINATION | DIST. | STATUT
     (ACCORDÉ, REFUSÉ par sous-dossier ou par zone, SANS RAPIDE), puces des modes reliées aux protocoles, DÉMAT / REMAT,
     ligne d'aide, ↑ ↓ et Entrée.
  5. La vraie tablette (TardisTablette et ses 10 modules, touche Y) : plaque PILOTE, 8 onglets en colonne (en ligne sur
     téléphone), vues, tableau des destinations, cartes d'état, journal en tableau, DÉMAT / REMAT / VOL LIBRE / ALERTE,
     réglages (thèmes, Confinement d'abord).
  6. La vraie tablette technicien : plaque TECHNICIEN, tableau des pannes PANNE | ZONE | ÉTAT, intervention guidée,
     panne réglée → RÉPARÉ, jauges à segments, boutons à coins coupés."""
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
def appuyer(b): b.extra.setdefault("Activated", Signal("Activated")).declencher(); H.avancer(0.01)
def appel(f, *a): return premier(appeler(f, list(a)))
JETONS = {"panneau": (10, 22, 38), "ligne": (31, 110, 140), "texte": (221, 246, 255), "discret": (134, 175, 195), "cyan": (91, 224, 255),
          "jaune": (242, 194, 48), "rouge": (255, 77, 106), "vert": (124, 255, 178), "sombre": (11, 11, 11)}


def monde_client(prefs=None, serveur=False):
    """Un joueur pilote (ou le serveur), avec le canal TardisCommande_TARDIS_1 ; prefs = l'attribut TardisPrefs (dict)."""
    vider_cache(); roblox.ERREURS.clear()
    I, G, game, joueur = monde(serveur=serveur)
    rs = game.m_FindFirstChild("ReplicatedStorage")
    remote = Instance("RemoteEvent", "TardisCommande_TARDIS_1", rs)
    if prefs is not None: joueur.attrs["TardisPrefs"] = json.dumps(prefs)
    R = {}
    tache(lambda: R.update(Config=appel(G["require"], rs.m_FindFirstChild("TardisConfig")), UI=appel(G["require"], rs.m_FindFirstChild("TardisUI"))))
    return I, G, game, joueur, rs, remote, R["Config"], R["UI"]


# ================================================================== 1. Jetons, polices, thème par défaut
I, G, game, joueur, rs, remote, Config, UI = monde_client()
verifier("TardisUI se charge chez un joueur", UI is not None and not roblox.ERREURS, roblox.ERREURS[:3])
JT = UI.get("JETONS")
verifier("1. Jetons de la charte : les 9 couleurs exactes (#0A1626, #1F6E8C, #DDF6FF, #86AFC3, #5BE0FF, #F2C230, #FF4D6A, #7CFFB2, #0B0B0B)",
         all(rgb(JT.get(k)) == v for k, v in JETONS.items()), {k: rgb(JT.get(k)) for k in JETONS})
verifier("1. Panneau : transparence 0,1 ; coins coupés 16 / 10 / 8 px ; bande 8 px ; cibles tactiles 44 px",
         (JT.get("transparencePanneau"), JT.get("coupe"), JT.get("coupeBouton"), JT.get("coupePuce"), JT.get("bande"), JT.get("cible")) == (0.1, 16, 10, 8, 8, 44))
nom_police = lambda k: UI.get(k).nom
verifier("1. Polices : titres Michroma, texte Titillium Web, données Roboto Mono",
         (nom_police("POLICE_TITRE"), nom_police("POLICE"), nom_police("POLICE_CODE"), nom_police("POLICE_CORPS"), nom_police("POLICE_DONNEES"))
         == ("Enum.Font.Michroma", "Enum.Font.TitilliumWeb", "Enum.Font.RobotoMono", "Enum.Font.TitilliumWeb", "Enum.Font.RobotoMono"))
src_ui = lire("ReplicatedStorage/TardisUI.lua")
verifier("1. Polices protégées (pcall) avec Gotham en secours ; gras en Titillium Web (FontFace) quand c'est possible",
         all(f"pcall(function() UI.{k} = Enum.Font.{v} end)" in src_ui for k, v in (("POLICE_TITRE", "Michroma"), ("POLICE", "TitilliumWeb"), ("POLICE_CODE", "RobotoMono")))
         and 'Font.new("rbxasset://fonts/families/TitilliumWeb.json", Enum.FontWeight.Bold)' in src_ui and "UI.POLICE_TITRE = Enum.Font.GothamBlack" in src_ui)
TH = UI.get("THEMES"); ORDRE = UI.get("ORDRE_THEMES")
conf = TH.get("Confinement")
verifier("1. Thème « Hologramme de confinement » en tête des réglages, les trois anciens gardés",
         [ORDRE.get(i) for i in range(1, 5)] == ["Confinement", "Gallifrey", "Cristal", "PoliceBox"] and conf.get("nom") == "Hologramme de confinement")
C = UI.get("C")
verifier("1. Thème par défaut appliqué chez le joueur : Confinement", appel(UI.get("themeActuel")) == "Confinement" and appel(UI.get("estConfinement")) is True)
verifier("1. Palette Confinement : fond = panneau, ligne = filet, ambre = jaune, cyan, texte, texte2 = discret, vert, rouge, sombre",
         (rgb(C.get("fond")), rgb(C.get("ligne")), rgb(C.get("ambre")), rgb(C.get("cyan")), rgb(C.get("texte")), rgb(C.get("texte2")), rgb(C.get("vert")), rgb(C.get("rouge")), rgb(C.get("sombre")))
         == (JETONS["panneau"], JETONS["ligne"], JETONS["jaune"], JETONS["cyan"], JETONS["texte"], JETONS["discret"], JETONS["vert"], JETONS["rouge"], JETONS["sombre"]))
def luminance(c):
    def canal(x):
        x = x / 255
        return x / 12.92 if x <= 0.03928 else ((x + 0.055) / 1.055) ** 2.4
    return 0.2126 * canal(c[0]) + 0.7152 * canal(c[1]) + 0.0722 * canal(c[2])
def contraste(a, b):
    la, lb = sorted((luminance(a), luminance(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)
k1, k2, k3 = contraste(JETONS["texte"], JETONS["panneau"]), contraste(JETONS["discret"], rgb(conf.get("creux"))), contraste(JETONS["sombre"], JETONS["cyan"])
verifier(f"1. Lisible : texte sur panneau ({k1:.1f}), discret sur le fond des listes ({k2:.1f}), sombre sur cyan ({k3:.1f}), sombre sur jaune",
         min(k1, k2, k3, contraste(JETONS["sombre"], JETONS["jaune"])) >= 4.5)
LIB = UI.get("LIBELLES")
ET = Config.get("Etats")
verifier("1. Libellés des états aux couleurs du thème (posé vert, vortex cyan, démat jaune)",
         (rgb(LIB.get(ET.get("Pose")).get(2)), rgb(LIB.get(ET.get("Vol")).get(2)), rgb(LIB.get(ET.get("Demat")).get(2))) == (JETONS["vert"], JETONS["cyan"], JETONS["jaune"]))
verifier("1. Majuscules françaises (accents)", appel(UI.get("majuscules"), "Gestion de l'énergie · Bâtiment") == "GESTION DE L'ÉNERGIE · BÂTIMENT")
verifier("1. Code d'objet de la plaque : « OBJ. TARDIS-01 »", appel(UI.get("codeObjet"), Config.get("Tardis").get(1)) == "OBJ. TARDIS-01")
CI = Config.get("Interface")
verifier("1. Config.Interface.Images = { CoinFond = 0, CoinBord = 0, Balayage = 0 } et badges des plaques",
         CI and [CI.get("Images").get(k) for k in ("CoinFond", "CoinBord", "Balayage")] == [0, 0, 0]
         and [CI.get("Badges").get(k) for k in ("Menu", "Tablette", "Technicien", "Energie")] == ["ACCÈS NIV. 3", "PILOTE", "TECHNICIEN", "C.T.A.T."])
cfg = lire("ReplicatedStorage/TardisConfig.lua")
bloc = cfg[cfg.index("Config.Interface = {"):cfg.index("return Config")]
verifier("1. Bloc Config.Interface juste avant « return Config », chaque réglage marqué « (V6.9.10.6) »",
         cfg.rstrip().endswith("return Config") and cfg.index("Config.Interface = {") > cfg.index("function Config.bloqueParMaintenance")
         and all("(V6.9.10.6)" in l for l in bloc.splitlines() if re.match(r"\s*(Config\.Interface|Images|Badges) = ", l)))
verifier("Chargement et thème : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])

# Le serveur n'applique aucun thème : les écrans de la console gardent leur palette (phase 2)
_, _, _, _, _, _, _, UIs = monde_client(serveur=True)
verifier("1. Serveur : aucun thème appliqué (palette de départ : écrans de la console inchangés)",
         appel(UIs.get("themeActuel")) is None and rgb(UIs.get("C").get("ambre")) == (242, 179, 61) and rgb(UIs.get("C").get("ecran")) == (7, 16, 36))


# ================================================================== 2. Migration unique du thème
def envois_prefs(remote): return [json.loads(e[1]) for e in remote.extra.get("envois", []) if e[0] == "Prefs"]
_, _, _, j2, _, r2, _, U2 = monde_client({"theme": "Cristal", "volume": 0.5})
H.avancer(1)
p2 = envois_prefs(r2)
verifier("2. Ancien thème sauvegardé (Cristal) : passé une fois à Confinement", appel(U2.get("themeActuel")) == "Confinement" and U2.get("prefs").get("theme") == "Confinement")
verifier("2. … et la migration est sauvegardée (drapeau migrationConfinement, volume gardé)",
         len(p2) == 1 and p2[0].get("theme") == "Confinement" and p2[0].get("migrationConfinement") is True and p2[0].get("volume") == 0.5, p2)
_, _, _, _, _, r3, _, U3 = monde_client({"theme": "Gallifrey", "migrationConfinement": True})
H.avancer(1)
verifier("2. Choix fait après la migration (Gallifrey) : gardé, rien de renvoyé",
         appel(U3.get("themeActuel")) == "Gallifrey" and rgb(U3.get("C").get("fond")) == (238, 233, 222) and envois_prefs(r3) == [])
_, _, _, _, _, r4, _, U4 = monde_client({})
H.avancer(1)
verifier("2. Nouveau joueur (aucune préférence) : Confinement, rien d'envoyé (le mode débutant n'est pas figé)",
         appel(U4.get("themeActuel")) == "Confinement" and envois_prefs(r4) == [] and U4.get("prefs").get("debutant") is None)
tache(lambda: appel(U4.get("choisirTheme"), "PoliceBox")); H.avancer(1)
p4 = envois_prefs(r4)
verifier("2. Choisir un thème dans les réglages (UI.choisirTheme) : appliqué, sauvegardé avec le drapeau",
         appel(U4.get("themeActuel")) == "PoliceBox" and p4 and p4[-1].get("theme") == "PoliceBox" and p4[-1].get("migrationConfinement") is True, p4)
verifier("2. La migration : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])


# ================================================================== 3. Briques de la charte
I, G, game, joueur, rs, remote, Config, UI = monde_client()
C = UI.get("C")
ecran = Instance("ScreenGui", "Essai", Instance("PlayerGui", "PlayerGui", joueur))
G["ECRAN"] = ecran
def lua(code, *args):
    """Exécute un bout de Luau avec UI et ECRAN ; renvoie la première valeur."""
    res = {}
    tache(lambda: res.update(f=premier(I.executer("return function(UI, A, B) " + code + " end", "essai"))))
    tache(lambda: res.update(v=appeler(res["f"], [UI] + list(args) + [None] * (2 - len(args)))))
    return res.get("v", [None])[0] if res.get("v") else None
images = Config.get("Interface").get("Images")
# — sans image : coins droits et traits en biais
p = lua("local p = UI.panneauCoupe({ Name = 'SansImage', Parent = ECRAN, Size = UDim2.fromOffset(300, 200) }) return p")
ch = enfants(p, "Chanfrein")
coin = enfants(p, classe="UICorner")[0]
verifier("3. Panneau sans image : fond panneau (0,1), coins droits, deux traits en biais à 45° dans les coins coupés",
         rgb(p.props["BackgroundColor3"]) == JETONS["panneau"] and p.props["BackgroundTransparency"] == 0.1 and coin.props["CornerRadius"].args[1] == 0
         and len(ch) == 2 and all(c.props["Rotation"] == 45 and c.props["Visible"] is True for c in ch) and not enfants(p, "FondCoupe"))
contour = enfants(p, "Contour", "UIStroke")
lueur = enfants(p, "Lueur")
verifier("3. Filet cyan lumineux (UIStroke « Contour ») et lueur (UIStroke épais et transparent)",
         contour and rgb(contour[0].props["Color"]) == JETONS["cyan"] and contour[0].props.get("Enabled", True) is True
         and lueur and lueur[0].props["Visible"] is True and enfants(lueur[0], classe="UIStroke")[0].props["Thickness"] == 3)
verifier("3. Sans image : pas de lignes de balayage", not enfants(p, "Balayage") and enfants(p, "Contenu"))
le = lua("return UI.lignesEcran(ECRAN, 10, 0.9)")
verifier("3. Lignes d'écran des anciens thèmes cachées en Confinement, pas d'image de balayage", enfants(le, "Lignes")[0].props["Visible"] is False and not enfants(le, "Balayage"))
# Changement de thème : le décor des anciens thèmes revient, les traits en biais disparaissent
lua("UI.appliquerTheme('Gallifrey')")
verifier("3. Gallifrey : coins arrondis, traits en biais et lueur cachés, lignes d'écran revenues",
         coin.props["CornerRadius"].args[1] > 0 and all(c.props["Visible"] is False for c in ch) and lueur[0].props["Visible"] is False
         and enfants(le, "Lignes")[0].props["Visible"] is True and rgb(p.props["BackgroundColor3"]) == (238, 233, 222))
lua("UI.appliquerTheme('Confinement')")
verifier("3. Retour à Confinement : coins droits et traits en biais", coin.props["CornerRadius"].args[1] == 0 and all(c.props["Visible"] is True for c in ch))
# — avec les images 9 tranches
images.set("CoinFond", 111); images.set("CoinBord", 222); images.set("Balayage", 333)
pi = lua("return UI.panneauCoupe({ Name = 'AvecImages', Parent = ECRAN, Size = UDim2.fromOffset(300, 200) }, { coupe = 16 })")
fond, bord, bal = enfants(pi, "FondCoupe"), enfants(pi, "BordCoupe"), enfants(pi, "Balayage")
verifier("3. Avec les images : FondCoupe et BordCoupe en 9 tranches (Slice, SliceCenter 16,16,48,48, SliceScale 1), teintées",
         fond and bord and fond[0].props["Image"] == "rbxassetid://111" and bord[0].props["Image"] == "rbxassetid://222"
         and fond[0].props["ScaleType"].nom == "Enum.ScaleType.Slice" and fond[0].props["SliceCenter"].args == [16, 16, 48, 48]
         and fond[0].props["SliceScale"] == 1 and rgb(fond[0].props["ImageColor3"]) == JETONS["panneau"] and rgb(bord[0].props["ImageColor3"]) == JETONS["cyan"])
verifier("3. Avec les images : le cadre est transparent, le UIStroke carré est coupé, aucun trait en biais",
         pi.props["BackgroundTransparency"] == 1 and enfants(pi, "Contour")[0].props["Enabled"] is False and not enfants(pi, "Chanfrein"))
verifier("3. Avec l'image de balayage : répétée (Tile 8 × 3, pixels nets), sous le contenu",
         bal and bal[0].props["ScaleType"].nom == "Enum.ScaleType.Tile" and bal[0].props["TileSize"].args == [8, 3] and bal[0].props["ZIndex"] == 0 and bal[0].props["Visible"] is True)
bc = lua("return UI.boutonCoupe(ECRAN, 'Démat', 'principal')")
pc = lua("return UI.puce(ECRAN, 'Classique').bouton")
verifier("3. Bouton (10 px) et puce (8 px) : SliceScale 0,625 et 0,5", enfants(bc, "FondCoupe")[0].props["SliceScale"] == 0.625 and enfants(pc, "FondCoupe")[0].props["SliceScale"] == 0.5)
verifier("3. Bouton principal avec images : l'image de fond prend le cyan, le texte est sombre",
         rgb(enfants(bc, "FondCoupe")[0].props["ImageColor3"]) == JETONS["cyan"] and enfants(bc, "FondCoupe")[0].props["ImageTransparency"] == 0
         and bc.props["BackgroundTransparency"] == 1 and rgb(bc.props["TextColor3"]) == JETONS["sombre"] and bc.props["Text"] == "DÉMAT")
# — « Réduire les effets » : balayage et lueur coupés
lua("UI.setPref('effetsReduits', true)")
verifier("3. « Réduire les effets » : plus de lignes de balayage ni de lueur", bal[0].props["Visible"] is False and enfants(pi, "Lueur")[0].props["Visible"] is False
         and lueur[0].props["Visible"] is False)
lua("UI.setPref('effetsReduits', false)")
verifier("3. … et elles reviennent quand l'option est coupée", bal[0].props["Visible"] is True and lueur[0].props["Visible"] is True)
images.set("CoinFond", 0); images.set("CoinBord", 0); images.set("Balayage", 0)
# — bande de danger
ext = Instance("Model", "Cabine"); ext.attrs["Alerte"] = False
bd = lua("local b = UI.bandeDanger({ Parent = ECRAN }, { largeur = 370 }) UI.lierBandeAlerte(b, A) return b", ext)
bandes = enfants(bd, "Bande")
verifier("3. Bande de danger : 8 px, cadre qui coupe ce qui dépasse, bandes inclinées à 45° (assez pour 370 px), en cyan",
         bd.props["Size"].args == [1, 0, 0, 8] and bd.props["ClipsDescendants"] is True and len(bandes) >= 370 // 22 + 1
         and all(b.props["Rotation"] == 45 for b in bandes) and all(rgb(b.props["BackgroundColor3"]) == JETONS["cyan"] for b in bandes) and not enfants(bd, classe="ImageLabel"))
ext.m_SetAttribute("Alerte", True); H.avancer(0.01)
verifier("3. Alerte du TARDIS : la bande passe au rouge", all(rgb(b.props["BackgroundColor3"]) == JETONS["rouge"] for b in bandes) and bd.attrs.get("Alerte") is True)
lua("UI.appliquerTheme('Cristal') UI.appliquerTheme('Confinement')")
verifier("3. … et le reste après un changement de thème", all(rgb(b.props["BackgroundColor3"]) == JETONS["rouge"] for b in bandes))
ext.m_SetAttribute("Alerte", False); H.avancer(0.01)
verifier("3. Fin de l'alerte : cyan à nouveau", all(rgb(b.props["BackgroundColor3"]) == JETONS["cyan"] for b in bandes))
# — jauge à segments
jg = lua("return UI.jaugeSegments(ECRAN, 'Intégrité', {})")
def allumes(v, couleur=None):
    lua("A.regler(B, UI.C.vert)", jg, v)
    return jg.get("allumes"), sum(1 for s in jg.get("segments").h.values() if rgb(s.props["BackgroundColor3"]) == JETONS["vert"])
res = {v: allumes(v) for v in (0, 4, 50, 60, 84, 99, 100)}
verifier("3. Jauge à 10 segments : 0 → 0, 4 → 1, 50 → 5, 60 → 6, 84 → 8, 99 → 10, 100 → 10 (allumés en vert)",
         {v: r[0] for v, r in res.items()} == {0: 0, 4: 1, 50: 5, 60: 6, 84: 8, 99: 10, 100: 10} and all(r[0] == r[1] for r in res.values()), res)
verifier("3. … la valeur exacte écrite à côté", texte_de(jg.get("valeur")) == "100 %" and jg.get("segments").longueur() == 10)
# — tableau, notification
tb = lua("""local t = UI.tableau(ECRAN, { { cle = 'nom', titre = 'Destination', largeur = UDim.new(1, -150) }, { cle = 'dist', titre = 'Dist.', largeur = UDim.new(0, 60), droite = true, donnees = true },
  { cle = 'statut', titre = 'Statut', largeur = UDim.new(0, 90), donnees = true } })
local a = t.ajouter({ nom = 'Hall', dist = '140', statut = 'ACCORDÉ' }, { couleurs = { statut = UI.C.vert } })
local b = t.ajouter({ nom = 'Toit', dist = '—', statut = 'REFUSÉ' }, { couleurs = { statut = UI.C.rouge }, discret = true })
a.choisir(true) return t""")
la, lb = tb.get("lignes").get(1), tb.get("lignes").get(2)
cel = lambda l, k: l.get("cellules").get(k)
verifier("3. Tableau : en-têtes DESTINATION | DIST. | STATUT en police de données, lignes de 44 px",
         [texte_de(trouve(tb.get("entete"), "Titre_" + k)) for k in ("nom", "dist", "statut")] == ["DESTINATION", "DIST.", "STATUT"]
         and la.get("bouton").props["Size"].args[3] == 44 and trouve(tb.get("entete"), "Titre_nom").props["Font"].nom == "Enum.Font.RobotoMono")
verifier("3. Ligne choisie : fond jaune, texte sombre ; autre ligne : statut rouge, nom grisé",
         la.get("bouton").props["BackgroundTransparency"] == 0 and rgb(la.get("bouton").props["BackgroundColor3"]) == JETONS["jaune"]
         and rgb(cel(la, "nom").props["TextColor3"]) == JETONS["sombre"] and rgb(cel(lb, "statut").props["TextColor3"]) == JETONS["rouge"]
         and rgb(cel(lb, "nom").props["TextColor3"]) == JETONS["discret"] and texte_de(cel(la, "nom")) == "HALL")
nt = lua("local n = UI.notification({ Parent = ECRAN }) n.regler('Alerte générale · boucliers levés', 'alerte') return n")
verifier("3. Notification ALERTE : badge rouge, filet rouge, bande de danger rouge visible",
         texte_de(nt.get("badge")) == "ALERTE" and rgb(nt.get("badge").props["TextColor3"]) == JETONS["rouge"] and nt.get("bande").props["Visible"] is True
         and rgb(enfants(nt.get("cadre"), "Contour")[0].props["Color"]) == JETONS["rouge"])
lua("A.regler('En maintenance', 'refus')", nt)
verifier("3. Notification REFUSÉ : badge jaune, sans bande", texte_de(nt.get("badge")) == "REFUSÉ" and rgb(nt.get("badge").props["TextColor3"]) == JETONS["jaune"]
         and nt.get("bande").props["Visible"] is False)
lua("A.regler('Démat dans 3 s', 'info')", nt)
verifier("3. Notification TARDIS : badge cyan", texte_de(nt.get("badge")) == "TARDIS" and rgb(nt.get("badge").props["TextColor3"]) == JETONS["cyan"])
# — boutons à variante et disponibilité
bs = lua("return UI.boutonCoupe(ECRAN, 'Remat', 'secondaire')")
bdg = lua("return UI.boutonCoupe(ECRAN, 'Alerte', 'danger')")
bp = lua("return UI.boutonCoupe(ECRAN, 'Démat', 'principal')")
verifier("3. Boutons : principal cyan plein (texte sombre), secondaire filet (fond transparent), danger filet rouge",
         rgb(bp.props["BackgroundColor3"]) == JETONS["cyan"] and bp.props["BackgroundTransparency"] == 0 and rgb(bp.props["TextColor3"]) == JETONS["sombre"]
         and bs.props["BackgroundTransparency"] == 1 and rgb(enfants(bs, "Contour")[0].props["Color"]) == JETONS["ligne"]
         and rgb(bdg.props["TextColor3"]) == JETONS["rouge"] and rgb(enfants(bdg, "Contour")[0].props["Color"]) == JETONS["rouge"])
lua("UI.setDisponible(A, false, UI.C.bleu)", bp)
verifier("3. Bouton principal indisponible : gris, texte discret (UI.setDisponible)", rgb(bp.props["BackgroundColor3"]) == rgb(C.get("gris")) and rgb(bp.props["TextColor3"]) == JETONS["discret"])
pu = lua("local s = UI.selecteurModes(ECRAN, { { cle = 'a', nom = 'Classique' }, { cle = 'b', nom = 'Rapide' }, { cle = 'c', nom = 'Urgence' } }, 1, nil, { colonnes = 2 }) s.a.regler(true) return s")
pa, pb = pu.get("a").get("bouton"), pu.get("b").get("bouton")
verifier("3. Puces des modes : la choisie en jaune (texte sombre), les autres en filet ; grille sur 2 colonnes",
         pa.props["BackgroundTransparency"] == 0 and rgb(pa.props["BackgroundColor3"]) == JETONS["jaune"] and rgb(pa.props["TextColor3"]) == JETONS["sombre"]
         and pb.props["BackgroundTransparency"] == 1 and enfants(pa.parent, classe="UIGridLayout") and texte_de(pa) == "CLASSIQUE")
verifier("3. Briques : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])


# ================================================================== Monde d'un pilote : le TARDIS, les destinations, la caméra
def monde_pilote(tactile=False, technicien=False):
    I, G, game, joueur, rs, remote, Config, UI = monde_client()
    activer_maths(G)
    ws = game.m_FindFirstChild("Workspace")
    camera = Instance("Camera", "Camera", ws)
    camera.props.update({"CFrame": CF((0, 20, 40)), "ViewportSize": Valeur("Vector2", [1920, 1080])})
    ws.props["CurrentCamera"] = camera
    Instance("PlayerGui", "PlayerGui", joueur)
    joueur.attrs["TardisTechnicien_TARDIS_1" if technicien else "TardisPilote_TARDIS_1"] = True
    uis = game.m_FindFirstChild("UserInputService")
    uis.props.update({"TouchEnabled": tactile, "KeyboardEnabled": not tactile, "MouseEnabled": not tactile})
    # ContextActionService : on garde les actions branchées (touches ↑ ↓ Entrée du menu rapide)
    cas = Instance("ContextActionService", "ContextActionService", game)
    liaisons = {}
    cas.extra["BindActionAtPriority"] = Fonction("BindActionAtPriority", py=lambda _s, nom, f, *a: liaisons.__setitem__(nom, (f, a)) or [])
    cas.extra["UnbindAction"] = Fonction("UnbindAction", py=lambda _s, nom: liaisons.pop(nom, None) and [] or [])
    tardis = Instance("Folder", "TARDIS", ws); t1 = Instance("Folder", "TARDIS_1", tardis)
    ext = Instance("Model", "Cabine", Instance("Folder", "EXTERIEURE", t1))
    ext.props.update({"Pivot": CF((0, 0, 0)), "PrimaryPart": Instance("Part", "Racine", ext)})
    ext.attrs.update({"Etat": "Pose", "Position": "Hall", "Alimentation": True, "PointsDeVie": 84, "BouclierEnergie": 72, "Alerte": False,
                      "ListeDestinations": "Hall\nLaboratoire\nParking\nToit", "Mode": "Normal"})
    salle = Instance("Model", "Salle", Instance("Folder", "INTERIEURE", t1))
    salle.props.update({"BoiteCFrame": CF((0, 1000, 0)), "BoiteTaille": Vec3(40, 20, 40)})
    for nom in ("Rotor", "Portail"):
        piece = Instance("Part", nom, salle); piece.props.update({"Position": Vec3(0, 1000, 0), "CFrame": CF((0, 1000, 0)), "Size": Vec3(2, 2, 2)})
    dest = Instance("Folder", "TARDIS_DESTINATIONS", ws)
    def piece(dossier, nom, pos, taille=(4, 1, 4)):
        p = Instance("Part", nom, dossier); p.props.update({"Position": Vec3(*pos), "CFrame": CF(pos), "Size": Vec3(*taille)}); return p
    accorde, refuse, sans = Instance("Folder", "ACCORDE", dest), Instance("Folder", "REFUSE", dest), Instance("Folder", "SANS_EXPRESS", dest)
    piece(accorde, "Hall", (140, 0, 0))
    piece(accorde, "Laboratoire", (300, 52, 0))   # dans la zone du Toit (sous-dossier REFUSE) : refusé par la zone
    piece(sans, "Parking", (0, 0, 455))
    piece(refuse, "Toit", (300, 50, 0), (20, 2, 20))
    return I, G, game, joueur, rs, remote, Config, UI, ext, salle, uis, liaisons, camera


def lancer_script(I, G, chemin, script_obj=None):
    src = lire(chemin)
    def go():
        ancien = G.get("script")
        if script_obj is not None: G["script"] = script_obj
        try: I.executer(src, os.path.basename(chemin))
        finally: G["script"] = ancien
    tache(go)
    H.avancer(0.05)


# ================================================================== 4. Le vrai menu rapide (TardisMenu)
I, G, game, joueur, rs, remote, Config, UI, ext, salle, uis, liaisons, camera = monde_pilote()
C = UI.get("C")
lancer_script(I, G, "StarterPlayer/StarterPlayerScripts/TardisMenu.client.lua")
pg = joueur.m_FindFirstChild("PlayerGui")
menu = pg.m_FindFirstChild("TardisMenu")
verifier("4. Menu rapide construit sous le thème Confinement, sans erreur", menu is not None and menu.props.get("Enabled") is True and not roblox.ERREURS, roblox.ERREURS[:3])
tiroir = trouve(menu, "Tiroir")
verifier("4. Tiroir : panneau de la charte (fond #0A1626, transparence 0,1, filet cyan, coins coupés)",
         tiroir and rgb(tiroir.props["BackgroundColor3"]) == JETONS["panneau"] and tiroir.props["BackgroundTransparency"] == 0.1
         and len(enfants(tiroir, "Chanfrein")) == 2 and rgb(enfants(tiroir, "Contour")[0].props["Color"]) == JETONS["cyan"])
plaque = trouve(menu, "Plaque")
bande = trouve(plaque, "BandeDanger")
verifier("4. Plaque : « NAVIGATION » en Michroma, badge « ACCÈS NIV. 3 », ligne « OBJ. TARDIS-01 · POSÉ · CLASSIQUE », bande de danger",
         texte_de(trouve(plaque, "Titre")) == "NAVIGATION" and trouve(plaque, "Titre").props["Font"].nom == "Enum.Font.Michroma"
         and texte_de(trouve(plaque, "BadgePlaque")) == "ACCÈS NIV. 3" and trouve(plaque, "BadgePlaque").props["Visible"] is True
         and texte_de(trouve(plaque, "SousLigne")).startswith("OBJ. TARDIS-01  ·  POSÉ  ·  CLASSIQUE") and bande is not None,
         (texte_de(trouve(plaque, "Titre")), texte_de(trouve(plaque, "BadgePlaque")), texte_de(trouve(plaque, "SousLigne"))))
ext.m_SetAttribute("Alerte", True); H.avancer(0.01)
verifier("4. Alerte : la bande de la plaque passe au rouge, la ligne de données le dit",
         all(rgb(b.props["BackgroundColor3"]) == JETONS["rouge"] for b in enfants(bande, "Bande")) and "ALERTE" in texte_de(trouve(plaque, "SousLigne")))
ext.m_SetAttribute("Alerte", False); H.avancer(0.01)
verifier("4. Fin de l'alerte : cyan", all(rgb(b.props["BackgroundColor3"]) == JETONS["cyan"] for b in enfants(bande, "Bande")))
recherche = trouve(menu, "Recherche")
verifier("4. Champ de recherche « Rechercher une destination »", recherche and recherche.props["PlaceholderText"] == "Rechercher une destination")
tableauD = trouve(menu, "Destinations")
lignes = {texte_de(trouve(l, "Cellule_nom")): l for l in tous(tableauD, "Destination")}
statut = lambda n: (texte_de(trouve(lignes[n], "Cellule_statut")), rgb(trouve(lignes[n], "Cellule_statut").props["TextColor3"])) if n in lignes else None
verifier("4. Tableau DESTINATION | DIST. | STATUT : les 4 lieux", set(lignes) == {"HALL", "LABORATOIRE", "PARKING", "TOIT"}
         and [texte_de(trouve(tableauD, "Titre_" + k)) for k in ("nom", "dist", "statut")] == ["DESTINATION", "DIST.", "STATUT"], list(lignes))
verifier("4. Statut : Hall ACCORDÉ (vert), Toit REFUSÉ (sous-dossier REFUSE, rouge), Laboratoire REFUSÉ (dans la zone du Toit), Parking SANS RAPIDE",
         statut("HALL") == ("ACCORDÉ", JETONS["vert"]) and statut("TOIT") == ("REFUSÉ", JETONS["rouge"]) and statut("LABORATOIRE") == ("REFUSÉ", JETONS["rouge"])
         and statut("PARKING")[0] == "SANS RAPIDE", {n: statut(n) for n in lignes})
verifier("4. Distances réelles (studs) : Hall 140, Parking 455 ; ligne refusée grisée",
         texte_de(trouve(lignes["HALL"], "Cellule_dist")) == "140" and texte_de(trouve(lignes["PARKING"], "Cellule_dist")) == "455"
         and rgb(trouve(lignes["TOIT"], "Cellule_nom").props["TextColor3"]) == JETONS["discret"])
modesM = trouve(menu, "SelecteurModes")
puce = lambda cle: trouve(modesM, "Mode_" + cle)
verifier("4. Puces des modes (Classique, Rapide, Urgence, Sauvetage, Silencieux) : Classique choisie (jaune)",
         all(puce(k) for k in ("classique", "express", "urgence", "sauvetage", "silencieux")) and puce("classique").props["BackgroundTransparency"] == 0
         and rgb(puce("classique").props["BackgroundColor3"]) == JETONS["jaune"] and puce("express").props["BackgroundTransparency"] == 1)
appuyer(puce("express"))
verifier("4. Puce « Rapide » : le protocole partagé passe en Rapide (la puce passe en jaune, Classique s'éteint)",
         puce("express").props["BackgroundTransparency"] == 0 and puce("classique").props["BackgroundTransparency"] == 1 and "RAPIDE" in texte_de(trouve(plaque, "SousLigne")))
appuyer(puce("classique"))
boutons = [b for b in tous(menu, "BoutonPrincipal")]
demat = next(b for b in boutons if texte_de(trouve(b, "Titre")) == "DÉMAT")
remat = next(b for b in boutons if texte_de(trouve(b, "Titre")) == "REMAT")
verifier("4. DÉMAT : bouton principal à coins coupés (cyan plein, texte sombre) ; REMAT : secondaire, indisponible au sol",
         demat.attrs.get("Variante") == "principal" and rgb(demat.props["BackgroundColor3"]) == JETONS["cyan"] and rgb(trouve(demat, "Titre").props["TextColor3"]) == JETONS["sombre"]
         and len(enfants(demat, "Chanfrein")) == 2 and remat.attrs.get("Variante") == "secondaire" and remat.attrs.get("Disponible") is False)
aide = trouve(menu, "AideTouches")
verifier("4. Ligne d'aide en police de données : « ↑ ↓ choisir · Entrée DÉMAT · T fermer »", aide and "↑ ↓ choisir" in texte_de(aide) and "Entrée DÉMAT" in texte_de(aide)
         and "T fermer" in texte_de(aide) and aide.props["Font"].nom == "Enum.Font.RobotoMono")
ji = trouve(menu, "JaugeIntegrite")
verifier("4. Jauge d'intégrité à segments : 84 % → 8 segments, « 84 % » écrit à côté", ji.attrs.get("Allumes") == 8 and texte_de(trouve(ji, "Valeur")) == "84 %")
# Ouverture (T), clavier ↑ ↓ Entrée
uis.__lua_index__("InputBegan").declencher(Table({"KeyCode": Valeur("Enum.KeyCode.T")}), False); H.avancer(0.6)
verifier("4. Touche T : le menu s'ouvre et branche ↑ ↓ Entrée (ContextActionService)", "TardisMenuNavigation" in liaisons)
action = liaisons.get("TardisMenuNavigation", (None,))[0]
def touche(nom):
    r = {}
    tache(lambda: r.update(v=appeler(action, ["TardisMenuNavigation", Valeur("Enum.UserInputState.Begin"), Table({"KeyCode": Valeur("Enum.KeyCode." + nom)})])))
    H.avancer(0.01)
    return r.get("v", [None])[0]
res = touche("Down")
choisies = [n for n, l in lignes.items() if l.parent and l.props["BackgroundTransparency"] == 0]
lignes = {texte_de(trouve(l, "Cellule_nom")): l for l in tous(tableauD, "Destination")}
choisies = [n for n, l in lignes.items() if l.props["BackgroundTransparency"] == 0]
verifier("4. ↓ : la première ligne est choisie (fond jaune), l'entrée ne fait pas bouger le personnage (Sink)",
         choisies == ["HALL"] and res is not None and res.nom == "Enum.ContextActionResult.Sink", (choisies, res))
touche("Down")
choisies = [n for n, l in lignes.items() if l.props["BackgroundTransparency"] == 0]
verifier("4. ↓ encore : la ligne suivante", choisies == ["LABORATOIRE"], choisies)
touche("Up")
n = len(remote.extra.get("envois", []))
touche("Return"); H.avancer(0.1)
envoi = [e for e in remote.extra.get("envois", [])[n:] if e[0] == "Demat"]
verifier("4. Entrée : DÉMAT (l'action EXISTANTE Demat, avec le mode)", len(envoi) == 1 and envoi[0][1].get("mode") == "Normal", remote.extra.get("envois", [])[n:])
# Notification de la charte
remote.__lua_index__("OnClientEvent").declencher("En maintenance", False); H.avancer(0.05)
nm = trouve(menu, "Notification")
verifier("4. Notification d'un refus : panneau à coins coupés, badge REFUSÉ jaune", nm.props["Visible"] is True and texte_de(trouve(nm, "Badge")) == "REFUSÉ"
         and rgb(trouve(nm, "Badge").props["TextColor3"]) == JETONS["jaune"])
remote.__lua_index__("OnClientEvent").declencher("ALERTE GÉNÉRALE", True); H.avancer(0.05)
verifier("4. Notification d'alerte : badge ALERTE rouge et bande rouge", texte_de(trouve(nm, "Badge")) == "ALERTE" and trouve(nm, "BandeDanger").props["Visible"] is True)
# Recherche
recherche.props["Text"] = "lab"; recherche.extra.get("prop_Text") and recherche.extra["prop_Text"].declencher(); H.avancer(0.01)
lignes = {texte_de(trouve(l, "Cellule_nom")): l for l in tous(tableauD, "Destination")}
verifier("4. Recherche « lab » : le tableau ne garde que Laboratoire", list(lignes) == ["LABORATOIRE"], list(lignes))
uis.__lua_index__("InputBegan").declencher(Table({"KeyCode": Valeur("Enum.KeyCode.T")}), False); H.avancer(0.6)
verifier("4. T à nouveau : fermé, les touches ↑ ↓ Entrée sont rendues", "TardisMenuNavigation" not in liaisons)
verifier("4. Menu rapide : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])
# Changement de thème avec le menu construit, puis le menu avec les images 9 tranches
tache(lambda: appel(UI.get("choisirTheme"), "Cristal")); H.avancer(0.6)
lignes = {texte_de(trouve(l, "Cellule_nom")): l for l in tous(tableauD, "Destination")}
verifier("4. Thème Cristal pendant la partie : le menu se recolore (tiroir, statuts recalculés), sans erreur",
         rgb(tiroir.props["BackgroundColor3"]) == (6, 9, 24) and rgb(trouve(lignes["LABORATOIRE"], "Cellule_statut").props["TextColor3"]) == rgb(UI.get("C").get("rouge"))
         and all(c.props["Visible"] is False for c in enfants(tiroir, "Chanfrein")) and not roblox.ERREURS, roblox.ERREURS[:3])
I, G, game, joueur, rs, remote, Config, UI, ext, salle, uis, liaisons, camera = monde_pilote()
for k, v in (("CoinFond", 11), ("CoinBord", 12), ("Balayage", 13)): Config.get("Interface").get("Images").set(k, v)
lancer_script(I, G, "StarterPlayer/StarterPlayerScripts/TardisMenu.client.lua")
menuI = joueur.m_FindFirstChild("PlayerGui").m_FindFirstChild("TardisMenu")
tiroirI = trouve(menuI, "Tiroir")
verifier("4. Avec les images : tiroir dessiné par FondCoupe / BordCoupe, boutons et puces aussi, balayage par-dessus, sans erreur",
         enfants(tiroirI, "FondCoupe") and enfants(tiroirI, "BordCoupe") and tiroirI.props["BackgroundTransparency"] == 1
         and enfants(trouve(menuI, "Mode_classique"), "FondCoupe") and all(enfants(b, "FondCoupe") for b in tous(menuI, "BoutonPrincipal"))
         and trouve(trouve(menuI, "LignesEcran"), "Balayage") is not None and not roblox.ERREURS, roblox.ERREURS[:3])


# ================================================================== 5. La vraie tablette (TardisTablette et ses modules)
def lancer_tablette(tactile=False, images=False):
    I, G, game, joueur, rs, remote, Config, UI, ext, salle, uis, liaisons, camera = monde_pilote(tactile=tactile)
    if images:
        for k, v in (("CoinFond", 11), ("CoinBord", 12), ("Balayage", 13)): Config.get("Interface").get("Images").set(k, v)
    sps = Instance("StarterPlayerScripts", "StarterPlayerScripts", game.m_FindFirstChild("StarterPlayer"))
    script_t = Instance("LocalScript", "TardisTablette", sps)
    for nom in ("Construction", "Etat", "Navigation", "Ouverture", "Placement", "Volet", "Scanner", "Suivi", "Journal", "Outils"):
        m = Instance("ModuleScript", nom, script_t); m.extra["chemin"] = os.path.join(DEPOT, "StarterPlayer/StarterPlayerScripts/TardisTablette", nom + ".lua")
    lancer_script(I, G, "StarterPlayer/StarterPlayerScripts/TardisTablette/init.client.lua", script_t)
    return I, G, game, joueur, rs, remote, Config, UI, ext, uis, joueur.m_FindFirstChild("PlayerGui").m_FindFirstChild("TardisTablette")
I, G, game, joueur, rs, remote, Config, UI, ext, uis, tab = lancer_tablette()
C = UI.get("C")
verifier("5. Tablette construite (10 modules) sous le thème Confinement, sans erreur", tab is not None and not roblox.ERREURS, roblox.ERREURS[:3])
tablette = trouve(tab, "Tablette")
ecranT = trouve(tablette, "Ecran")
verifier("5. La tablette est un panneau de la charte (coins coupés, filet cyan) ; l'écran intérieur est transparent en Confinement",
         rgb(tablette.props["BackgroundColor3"]) == JETONS["panneau"] and len(enfants(tablette, "Chanfrein")) == 2 and ecranT.props["BackgroundTransparency"] == 1)
plaqueT = trouve(tab, "Plaque")
verifier("5. Plaque : « TABLETTE DE PILOTAGE », badge « PILOTE », ligne « OBJ. TARDIS-01 · TARDIS_1 », bande de danger",
         texte_de(trouve(plaqueT, "Titre")) == "TABLETTE DE PILOTAGE" and texte_de(trouve(plaqueT, "BadgePlaque")) == "PILOTE"
         and texte_de(trouve(plaqueT, "SousLigne")) == "OBJ. TARDIS-01  ·  TARDIS_1" and trouve(plaqueT, "BandeDanger") is not None)
ext.m_SetAttribute("Alerte", True); H.avancer(0.01)
verifier("5. Alerte : bande de la plaque rouge", all(rgb(b.props["BackgroundColor3"]) == JETONS["rouge"] for b in enfants(trouve(plaqueT, "BandeDanger"), "Bande")))
ext.m_SetAttribute("Alerte", False); H.avancer(0.01)
onglets = trouve(tab, "Onglets")
noms = [texte_de(o).strip() for o in sorted(enfants(onglets, classe="TextButton"), key=lambda o: o.props["LayoutOrder"])]
pile = enfants(onglets, classe="UIListLayout")[0]
verifier("5. Onglets en colonne : NAVIGATION, SYSTÈMES, SCANNER, VOL LIBRE, OUTILS, JOURNAL, RÉGLAGES, AIDE (44 px chacun)",
         noms == ["NAVIGATION", "SYSTÈMES", "SCANNER", "VOL LIBRE", "OUTILS", "JOURNAL", "RÉGLAGES", "AIDE"] and pile.props["FillDirection"].nom == "Enum.FillDirection.Vertical"
         and all(o.props["Size"].args[3] == 44 for o in enfants(onglets, classe="TextButton")), noms)
onglet = lambda cle: trouve(onglets, "Onglet_" + cle)
vue = lambda nom: trouve(tab, "Vue_" + nom)
verifier("5. Vue Navigation affichée, onglet Navigation en jaune", vue("navigation").props["Visible"] is True and vue("systemes").props["Visible"] is False
         and onglet("navigation").props["BackgroundTransparency"] == 0 and rgb(onglet("navigation").props["BackgroundColor3"]) == JETONS["jaune"])
joueur.m_SetAttribute("TardisTablette", True); H.avancer(1)
nav = vue("navigation")
tabD = trouve(nav, "Destinations")
lignesT = {texte_de(trouve(l, "Cellule_nom")): l for l in tous(tabD, "Destination")}
st = lambda n: texte_de(trouve(lignesT[n], "Cellule_statut")) if n in lignesT else None
verifier("5. Navigation : tableau des destinations avec statut (ACCORDÉ, REFUSÉ, SANS RAPIDE) et distance",
         {n: st(n) for n in lignesT} == {"HALL": "ACCORDÉ", "LABORATOIRE": "REFUSÉ", "PARKING": "SANS RAPIDE", "TOIT": "REFUSÉ"}
         and texte_de(trouve(lignesT["HALL"], "Cellule_dist")) == "140", {n: st(n) for n in lignesT})
appuyer(lignesT["HALL"])
fiche = trouve(nav, "Fiche")
verifier("5. Choisir Hall : ligne jaune, destination « HALL » en grand (Michroma, jaune) avec ses coordonnées",
         lignesT["HALL"].props["BackgroundTransparency"] == 0
         and any(texte_de(e) == "HALL" and e.props["Font"].nom == "Enum.Font.Michroma" and rgb(e.props["TextColor3"]) == JETONS["jaune"] for e in descendants(fiche))
         and any("X 140 · Y 0 · Z 0" in texte_de(e) for e in descendants(fiche) if e.ClassName == "TextLabel"))
cartes = trouve(nav, "CartesEtat")
carte = lambda k: trouve(cartes, "Carte_" + k)
verifier("5. Cartes d'état : ÉTAT « POSÉ » (bord vert), MODE « CLASSIQUE · … S », PORTES, BOUCLIERS",
         texte_de(trouve(carte("etat"), "Valeur")) == "POSÉ" and rgb(trouve(carte("etat"), "Bord").props["BackgroundColor3"]) == JETONS["vert"]
         and texte_de(trouve(carte("mode"), "Valeur")).startswith("CLASSIQUE · ") and texte_de(trouve(carte("portes"), "Valeur")) == "FERMÉES"
         and texte_de(trouve(carte("boucliers"), "Valeur")) == "INACTIFS", [texte_de(trouve(carte(k), "Valeur")) for k in ("etat", "mode", "portes", "boucliers")])
ext.m_SetAttribute("PortesVerrouillees", True); H.avancer(0.05)
verifier("5. Portes verrouillées : carte « VERROUILLÉES », bord vert", texte_de(trouve(carte("portes"), "Valeur")) == "VERROUILLÉES"
         and rgb(trouve(carte("portes"), "Bord").props["BackgroundColor3"]) == JETONS["vert"])
mini = trouve(nav, "JournalRecent")
ev = [(texte_de(trouve(l, "Cellule_evenement")), texte_de(trouve(l, "Cellule_detail"))) for l in tous(mini, "Evenement")]
verifier("5. Journal récent en tableau HEURE | ÉVÉNEMENT | DÉTAIL (3 lignes au plus, la plus récente d'abord)",
         0 < len(ev) <= 3 and ev[0][0] == "PORTES VERROUILLÉES" and [texte_de(trouve(mini, "Titre_" + k)) for k in ("heure", "evenement", "detail")] == ["HEURE", "ÉVÉNEMENT", "DÉTAIL"], ev)
actions = trouve(nav, "Actions")
dm = next(b for b in tous(actions, "BoutonPrincipal") if texte_de(trouve(b, "Titre")) == "DÉMAT")
vl, al = trouve(actions, "VolLibre"), trouve(actions, "Alerte")
verifier("5. Boutons DÉMAT (principal) / REMAT / VOL LIBRE (secondaire) / ALERTE (danger), à coins coupés",
         dm.attrs.get("Variante") == "principal" and vl.attrs.get("Variante") == "secondaire" and al.attrs.get("Variante") == "danger"
         and texte_de(vl) == "VOL LIBRE" and texte_de(al) == "ALERTE" and enfants(vl, "Chanfrein") and enfants(al, "Chanfrein"))
n = len(remote.extra.get("envois", []))
appuyer(al); appuyer(al)
verifier("5. ALERTE (deux appuis, confirmation) : l'action EXISTANTE Siege (bouclier + verrou + alerte)",
         [e[0] for e in remote.extra["envois"][n:]] == ["Siege"], remote.extra["envois"][n:])
n = len(remote.extra.get("envois", []))
appuyer(dm); H.avancer(0.1)
verifier("5. DÉMAT : l'action EXISTANTE Demat", [e[0] for e in remote.extra["envois"][n:]][:1] == ["Demat"], remote.extra["envois"][n:])
modesT = trouve(nav, "SelecteurModes")
verifier("5. Puces des modes dans la vue Navigation (Classique choisie)", trouve(modesT, "Mode_classique").props["BackgroundTransparency"] == 0)
# Onglets
appuyer(onglet("systemes"))
verifier("5. Onglet Systèmes : vue Systèmes (statut, télémétrie, systèmes, commandes rapides), onglet en jaune",
         vue("systemes").props["Visible"] is True and vue("navigation").props["Visible"] is False and onglet("systemes").props["BackgroundTransparency"] == 0
         and len([p for p in enfants(vue("systemes"), "Panneau")]) == 4)
jb = trouve(vue("systemes"), "JaugeIntegrite")
verifier("5. Jauges à segments du panneau Statut : intégrité 84 % → 8 segments", jb.attrs.get("Allumes") == 8 and texte_de(trouve(jb, "Valeur")) == "84 %")
appuyer(onglet("volLibre"))
tv = trouve(vue("volLibre"), "TouchesVol")
verifier("5. Onglet Vol libre : état « PRÊT », bouton de lancement, tableau des touches (F, Entrée…)",
         vue("volLibre").props["Visible"] is True and texte_de(trouve(vue("volLibre"), "Etat")) == "PRÊT"
         and trouve(vue("volLibre"), "LancerVol").attrs.get("Disponible") is True
         and trouve(vue("volLibre"), "LancerVol") is not None and any(texte_de(trouve(l, "Cellule_touche")) == "F" for l in enfants(trouve(tv, "Corps"))))
appuyer(onglet("reglages"))
volet = trouve(tab, "Volet")
themes = [texte_de(b) for b in descendants(volet) if b.ClassName == "TextButton" and texte_de(b) in ("Hologramme de confinement", "Gallifrey (15e Docteur)", "Cristal (13e Docteur)", "Police Box (la cabine)")]
verifier("5. Onglet Réglages : la vue du volet, les 4 thèmes avec « Hologramme de confinement » en premier",
         vue("volet").props["Visible"] is True and onglet("reglages").props["BackgroundTransparency"] == 0 and themes[:1] == ["Hologramme de confinement"] and len(themes) == 4, themes)
gal = next(b for b in descendants(volet) if b.ClassName == "TextButton" and texte_de(b) == "Gallifrey (15e Docteur)")
appuyer(gal); H.avancer(1)
verifier("5. Choisir Gallifrey : thème appliqué (la tablette se recolore), sauvegardé",
         appel(UI.get("themeActuel")) == "Gallifrey" and rgb(tablette.props["BackgroundColor3"]) == (238, 233, 222)
         and any(e[0] == "Prefs" and json.loads(e[1]).get("theme") == "Gallifrey" for e in remote.extra["envois"]))
conf_btn = next(b for b in descendants(volet) if b.ClassName == "TextButton" and texte_de(b) == "Hologramme de confinement")
appuyer(conf_btn); H.avancer(1)
verifier("5. … et retour à Confinement", appel(UI.get("themeActuel")) == "Confinement" and rgb(tablette.props["BackgroundColor3"]) == JETONS["panneau"])
appuyer(onglet("outils"))
verifier("5. Onglet Outils : la grille des outils du volet", vue("volet").props["Visible"] is True and onglet("outils").props["BackgroundTransparency"] == 0
         and onglet("reglages").props["BackgroundTransparency"] == 1)
appuyer(onglet("journal"))
jt = trouve(vue("journal"), "Journal")
verifier("5. Onglet Journal : le journal de bord en tableau", vue("journal").props["Visible"] is True and len(tous(jt, "Evenement")) >= 1)
verifier("5. Tablette : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])
# Téléphone : onglets en ligne au-dessus du contenu
I, G, game, joueur, rs, remote, Config, UI, ext, uis, tab = lancer_tablette(tactile=True)
onglets = trouve(tab, "Onglets")
pile = enfants(onglets, classe="UIListLayout")[0]
vues = trouve(tab, "Vues")
verifier("5. Téléphone (tactile sans clavier) : onglets en ligne au-dessus du contenu (toute la largeur), toujours 44 px de haut",
         pile.props["FillDirection"].nom == "Enum.FillDirection.Horizontal" and onglets.props["Size"].args == [1, -28, 0, 44]
         and vues.props["Position"].args[1] > onglets.props["Position"].args[1] and vues.props["Position"].args[0] == onglets.props["Position"].args[0]
         and all(o.props["Size"].args[2] == 1 for o in enfants(onglets, classe="TextButton")),
         (pile.props["FillDirection"], onglets.props["Size"].args, vues.props["Position"].args))
verifier("5. Tablette sur téléphone : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])
# Le menu rapide sur téléphone : ses deux boutons tactiles (T, Y) à coins coupés
lancer_script(I, G, "StarterPlayer/StarterPlayerScripts/TardisMenu.client.lua")
bt = tous(joueur.m_FindFirstChild("PlayerGui").m_FindFirstChild("TardisMenu"), "BoutonTactile")
verifier("5. Téléphone : boutons tactiles T et Y du menu rapide (52 px, coins coupés)", len(bt) == 2 and all(b.props["Size"].args == [52, 52] and len(enfants(b, "Chanfrein")) == 2 for b in bt))
verifier("5. Menu rapide sur téléphone : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])
I, G, game, joueur, rs, remote, Config, UI, ext, uis, tab = lancer_tablette(images=True)
joueur.m_SetAttribute("TardisTablette", True); H.avancer(1)
verifier("5. Avec les images 9 tranches : la tablette, ses onglets et ses boutons sont dessinés par les images, sans erreur",
         tab is not None and enfants(trouve(tab, "Tablette"), "FondCoupe") and enfants(trouve(tab, "Onglet_navigation"), "FondCoupe")
         and enfants(trouve(tab, "VolLibre"), "BordCoupe") and not roblox.ERREURS, roblox.ERREURS[:3])


# ================================================================== 6. La vraie tablette technicien
I, G, game, joueur, rs, remote, Config, UI, ext, salle, uis, liaisons, camera = monde_pilote(technicien=True)
C = UI.get("C")
RS = game.m_FindFirstChild("RunService")
def images(duree, pas=0.05):
    """Fait tourner les images (RenderStepped, Heartbeat) pendant « duree » secondes de temps virtuel."""
    t = 0.0
    while t < duree - 1e-9:
        RS.__lua_index__("RenderStepped").declencher(pas); RS.__lua_index__("Heartbeat").declencher(pas)
        H.avancer(pas); t += pas
ext.attrs.update({"RegulEnergie": 80, "RegulAir": 84, "RegulVapeur": 50, "PV": 8400, "Salete": 0})
for nom in ("Console", "Vanne"):
    p_ = Instance("Part", nom, salle); p_.props.update({"Position": Vec3(0, 1000, 5), "CFrame": CF((0, 1000, 5)), "Size": Vec3(2, 2, 2)})
grilles = Instance("Folder", "Grilles", salle)
for i in range(3):
    g_ = Instance("Part", "Grille", grilles); g_.props.update({"Position": Vec3(i, 1000, 0), "Size": Vec3(2, 0.2, 2)})
contexte = Table({"C": C, "Config": Config, "E": Config.get("Etats"), "Lighting": game.m_FindFirstChild("Lighting"), "Players": game.m_FindFirstChild("Players"),
                  "RunService": game.m_FindFirstChild("RunService"), "UI": UI, "UserInputService": uis, "animer": UI.get("animer"), "camera": camera,
                  "creer": UI.get("creer"), "dansInterieur": Fonction("dansInterieur", py=lambda p: False), "def": Config.get("Tardis").get(1), "exterieur": ext,
                  "interieur": salle, "jeSuisDedans": Fonction("dedans", py=lambda: True), "joueur": joueur,
                  "partTemporaire": Fonction("pt", py=lambda *a: Instance("Part", "Temp")), "remote": remote, "texte": UI.get("texte")})
res = {}
tache(lambda: res.update(m=premier(appeler(premier(I.executer(lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/TabletteTechnicien.lua"), "TabletteTechnicien")), [contexte]))))
tech = joueur.m_FindFirstChild("PlayerGui").m_FindFirstChild("TardisTabletteTechnicien_TARDIS_1")
verifier("6. Tablette technicien construite sous le thème Confinement, sans erreur", tech is not None and not roblox.ERREURS, roblox.ERREURS[:3])
joueur.m_SetAttribute("TardisTabletteTech", "TARDIS_1"); H.avancer(0.3)
verifier("6. Ouverte (outil Ingénierie / touche Y du technicien)", tech.props.get("Enabled") is True)
pt = trouve(tech, "Plaque")
verifier("6. Plaque : « INGÉNIERIE », badge « TECHNICIEN », ligne « OBJ. TARDIS-01 · SYSTÈMES NOMINAUX », bande de danger",
         texte_de(trouve(pt, "Titre")) == "INGÉNIERIE" and texte_de(trouve(pt, "BadgePlaque")) == "TECHNICIEN"
         and texte_de(trouve(pt, "SousLigne")) == "OBJ. TARDIS-01  ·  SYSTÈMES NOMINAUX" and trouve(pt, "BandeDanger") is not None, texte_de(trouve(pt, "SousLigne")))
ja = trouve(tech, "Jauge_air")
verifier("6. Jauges à segments : air 84 % → 8 segments (valeur écrite à côté), 7 jauges",
         ja.attrs.get("Allumes") == 8 and texte_de(trouve(ja, "Valeur")) == "84 %" and len([e for e in descendants(tech) if e.Name.startswith("Jauge_")]) == 7)
guide = trouve(tech, "Intervention")
verifier("6. Aucune panne : l'intervention guidée dit « TOUS LES SYSTÈMES SONT NOMINAUX »", texte_de(trouve(guide, "Nominal")) == "●  TOUS LES SYSTÈMES SONT NOMINAUX")
ext.m_SetAttribute("Incendie", True); ext.m_SetAttribute("VapeurSurcharge", 2); images(0.6)
tp = trouve(tech, "Pannes")
lp = {texte_de(trouve(l, "Cellule_panne")): l for l in enfants(trouve(tp, "Corps")) if l.ClassName == "TextButton"}
cellp = lambda n, k: texte_de(trouve(lp[n], "Cellule_" + k)) if n in lp else None
verifier("6. Tableau PANNE | ZONE | ÉTAT : fuite de vapeur (grille) et incendie (console)",
         set(lp) == {"FUITE DE VAPEUR", "INCENDIE"} and [texte_de(trouve(tp, "Titre_" + k)) for k in ("panne", "zone", "etat")] == ["PANNE", "ZONE", "ÉTAT"]
         and cellp("INCENDIE", "zone") == "CONSOLE" and cellp("FUITE DE VAPEUR", "zone") == "GRILLE N°2", {n: (cellp(n, "zone"), cellp(n, "etat")) for n in lp})
choisie = [n for n, l in lp.items() if l.props["BackgroundTransparency"] == 0]
verifier("6. La première panne est choisie (ligne jaune, EN COURS), l'autre À RÉPARER (rouge)",
         len(choisie) == 1 and cellp(choisie[0], "etat") == "EN COURS" and [cellp(n, "etat") for n in lp if n not in choisie] == ["À RÉPARER"]
         and rgb(trouve(lp[[n for n in lp if n not in choisie][0]], "Cellule_etat").props["TextColor3"]) == JETONS["rouge"], {n: cellp(n, "etat") for n in lp})
appuyer(lp["INCENDIE"]); images(0.3)
lp = {texte_de(trouve(l, "Cellule_panne")): l for l in enfants(trouve(tp, "Corps")) if l.ClassName == "TextButton"}
etapes = [texte_de(e) for e in sorted([e for e in descendants(guide) if e.Name.startswith("Etape")], key=lambda e: e.Name)]
verifier("6. Clic sur INCENDIE : intervention guidée de l'incendie (▸ étape en cours, · à faire), boutons Prendre et Localiser",
         lp["INCENDIE"].props["BackgroundTransparency"] == 0 and texte_de(trouve(guide, "TitreGuide")) == "INTERVENTION GUIDÉE  ·  INCENDIE"
         and etapes and etapes[0].startswith("▸  Prends l'extincteur") and all(e.startswith("·  ") for e in etapes[1:])
         and trouve(guide, "Prendre").attrs.get("Variante") == "principal" and trouve(guide, "Localiser") is not None, etapes)
ext.m_SetAttribute("Incendie", None); images(0.6)
lp = {texte_de(trouve(l, "Cellule_panne")): l for l in enfants(trouve(tp, "Corps")) if l.ClassName == "TextButton"}
verifier("6. Incendie éteint : la ligne reste, en vert « RÉPARÉ » (grisée) ; la fuite passe en cours",
         cellp("INCENDIE", "etat") == "RÉPARÉ" and rgb(trouve(lp["INCENDIE"], "Cellule_etat").props["TextColor3"]) == JETONS["vert"]
         and cellp("FUITE DE VAPEUR", "etat") == "EN COURS", {n: cellp(n, "etat") for n in lp})
verifier("6. Plaque : « 1 PANNE »", texte_de(trouve(pt, "SousLigne")) == "OBJ. TARDIS-01  ·  1 PANNE")
images(61, 0.5)
lp = {texte_de(trouve(l, "Cellule_panne")): l for l in enfants(trouve(tp, "Corps")) if l.ClassName == "TextButton"}
verifier("6. Une minute plus tard, la panne réglée quitte le tableau", "INCENDIE" not in lp and "FUITE DE VAPEUR" in lp, list(lp))
boutonsT = [e for e in descendants(tech) if e.ClassName == "TextButton" and e.attrs.get("Variante")]
red = next(b for b in boutonsT if texte_de(b).startswith("REDÉMARR"))
en = next(b for b in boutonsT if "ÉNERGIE" in texte_de(b))
verifier("6. Commandes à coins coupés : REDÉMARRER en principal (indisponible sans coupure), COUPER L'ÉNERGIE en danger",
         red.attrs.get("Variante") == "principal" and red.attrs.get("Disponible") is False and en.attrs.get("Variante") == "danger"
         and texte_de(en) == "COUPER L'ÉNERGIE" and enfants(en, "Chanfrein"))
ext.m_SetAttribute("Alimentation", False); images(0.3)
verifier("6. Hors tension : RÉTABLIR L'ÉNERGIE devient le bouton principal", en.attrs.get("Variante") == "principal" and texte_de(en) == "RÉTABLIR L'ÉNERGIE")
ext.m_SetAttribute("Alimentation", True); images(0.3)
n = len(remote.extra.get("envois", []))
diag = next(b for b in boutonsT if texte_de(b) == "DIAGNOSTIC")
appuyer(diag)
verifier("6. DIAGNOSTIC : l'action EXISTANTE Tech / Diagnostic", [(e[0], e[1].get("commande")) for e in remote.extra["envois"][n:]] == [("Tech", "Diagnostic")])
remote.__lua_index__("OnClientEvent").declencher("Diagnostic lancé.", True); H.avancer(0.05)
nt_ = trouve(tech, "Notification")
verifier("6. Notification de la charte : badge TARDIS", nt_.props["Visible"] is True and texte_de(trouve(nt_, "Badge")) == "TARDIS")
ext.m_SetAttribute("Alerte", True); H.avancer(0.05)
verifier("6. Alerte : la bande de la plaque passe au rouge", all(rgb(b.props["BackgroundColor3"]) == JETONS["rouge"] for b in enfants(trouve(pt, "BandeDanger"), "Bande")))
verifier("6. Tablette technicien : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])


# ================================================================== Le code : rien de nouveau côté réseau, pas de décor image par image
src = {n: lire(n) for n in ("ReplicatedStorage/TardisUI.lua", "StarterPlayer/StarterPlayerScripts/TardisMenu.client.lua",
                            "StarterPlayer/StarterPlayerScripts/TardisTablette/Construction.lua", "StarterPlayer/StarterPlayerScripts/TardisExtrasClient/TabletteTechnicien.lua")}
actions = sorted(set(re.findall(r'FireServer\("(\w+)"', "".join(src.values()))))
verifier("Aucune nouvelle action réseau (Siege, Demat, Bouclier, Outil, Tech, Maintenance, Camouflage, Portes, Verrou, Taille, Prefs…)",
         set(actions) <= {"Siege", "Bouclier", "Outil", "Tech", "Maintenance", "Camouflage", "Portes", "Verrou", "Taille", "Prefs"}, actions)
verifier("Pas de boucle image par image pour le décor : TardisUI ne se branche sur aucun RenderStepped / Heartbeat",
         "RenderStepped" not in src["ReplicatedStorage/TardisUI.lua"] and "Heartbeat" not in src["ReplicatedStorage/TardisUI.lua"])
verifier("Plus de dégradé d'en-tête ni de roue qui tournent (menu, tablette technicien)", "vortex.Rotation" not in src["StarterPlayer/StarterPlayerScripts/TardisMenu.client.lua"]
         and "roue.Rotation" not in src["StarterPlayer/StarterPlayerScripts/TardisExtrasClient/TabletteTechnicien.lua"])
images = [os.path.join(DEPOT, "..", "assets", "interface", f) for f in ("coin_fond.png", "coin_bord.png", "balayage.png", "LISEZMOI.md")]
verifier("Les 3 images 9 tranches et leur mode d'emploi sont dans assets/interface", all(os.path.exists(f) for f in images))
try:
    from PIL import Image
    fo, bo, ba = (Image.open(f) for f in images[:3])
    a = fo.getchannel("A"); b = bo.getchannel("A")
    verifier("Images : coin_fond 64 × 64 blanc plein, coins coupés de 16 px (haut droit et bas gauche transparents)",
             fo.size == (64, 64) and fo.getpixel((32, 32)) == (255, 255, 255, 255) and a.getpixel((63, 0)) == 0 and a.getpixel((0, 63)) == 0
             and a.getpixel((0, 0)) == 255 and a.getpixel((63, 63)) == 255 and a.getpixel((47, 0)) > 200 and a.getpixel((60, 2)) == 0)
    verifier("Images : coin_bord, le même contour de 2 px (centre transparent) ; balayage 8 × 3, une ligne sur trois",
             bo.size == (64, 64) and b.getpixel((32, 32)) == 0 and b.getpixel((0, 32)) == 255 and b.getpixel((32, 0)) == 255 and b.getpixel((63, 0)) == 0
             and ba.size == (8, 3) and ba.getpixel((0, 0))[3] == 128 and ba.getpixel((0, 1))[3] == 0 and ba.getpixel((0, 2))[3] == 0)
except ImportError:
    verifier("Images : (Pillow absent, vérification des pixels sautée)", True)


print("\n".join("  ✓ " + o for o in OK)); print("\n".join("  ✗ " + k for k in KO))
print(f"V6.9.10.6 : {len(OK)}/{len(OK) + len(KO)} vérifications réussies")
sys.exit(1 if KO else 0)
