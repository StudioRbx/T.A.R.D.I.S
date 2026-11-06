"""Simulations de la V6.9.10.3 (écrans de la console nets et écran ingénieur visible) : le vrai module
TardisServeur › Ecrans, avec des maths réelles (roblox.activer_maths : pièces orientées, console avec un centre).
  1. TardisConfig : réglages Config.Ecrans (Resolution, ResolutionMax, PixelsParStud minimum, FaceDestination Front,
     FaceIngenieur Auto), marqués « (V6.9.10.3) ».
  2. Netteté : finesse calculée pour chaque écran (un écran de 2 studs a 1024 pixels sur son grand côté, avant 100),
     grand écran, écran géant (plafond ResolutionMax), pièce minuscule ; LightInfluence 0 ; recalculée si la pièce
     change de taille ou de face.
  3. Lisibilité : chaque ligne de texte fait au moins 8 % de la hauteur de l'écran (≥ 45 pixels sur un petit écran),
     taille de texte minimale (UITextSizeConstraint) sur les lignes longues, bande de la ligne vivante gardée.
  4. Écran ingénieur : contenu présent (PV, énergie, régulation, boucliers), pas de voile, sur la face visible
     choisie seule (Auto) : plaque inclinée (Top, Front ou Back selon sa construction), Model (pièce désignée par
     l'attribut, pièce nommée Vitre, plus grande pièce visible, jamais le premier bouton trouvé), FaceEcran explicite
     respecté (pièce ou Model), « Aucune », valeur inconnue ; clic sur tout le Model.
  5. Écrans de destination : Front par défaut (inchangé), « Auto » accepté.
  6. Output : une ligne au démarrage qui dit quelle pièce et quelle face chaque écran utilise."""
import os, sys, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from monde import *
import roblox
from roblox import Vec3, CF, activer_maths, _rx, _rz
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
def enfant_classe(o, classe, nom=None):
    return [e for e in o.enfants if e.ClassName == classe and (nom is None or e.Name == nom)]
def champ(g, nom):
    if g is None: return None
    for e in descendants(g):
        if e.Name == nom: return e
def texte_de(o): return str(o.props.get("Text", "")) if o is not None else None
R = {}

def piece(nom, parent, pos=(0, 0, 0), taille=(2, 2, 2), rot=None, classe="Part"):
    p = Instance(classe, nom, parent)
    p.props.update({"CFrame": CF(pos, rot), "Size": Vec3(*taille), "Position": Vec3(*pos)})
    return p

# ================================================================== 1. TardisConfig
vider_cache(); roblox.ERREURS.clear()
I, G, game, pilote = monde(serveur=True)
activer_maths(G)
rs = game.m_FindFirstChild("ReplicatedStorage"); Players = game.m_FindFirstChild("Players")
tache(lambda: R.update(Config=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisConfig")]))))
Config = R["Config"]; E = Config.get("Etats")
EC = Config.get("Ecrans")
verifier("1. Config.Ecrans : Resolution 1024, ResolutionMax 2048, PixelsParStud 20 (minimum), FaceDestination Front, FaceIngenieur Auto",
         (EC.get("Resolution"), EC.get("ResolutionMax"), EC.get("PixelsParStud"), EC.get("FaceDestination"), EC.get("FaceIngenieur")) == (1024, 2048, 20, "Front", "Auto"),
         (EC.get("Resolution"), EC.get("ResolutionMax"), EC.get("PixelsParStud"), EC.get("FaceDestination"), EC.get("FaceIngenieur")))
cfgsrc = lire("ReplicatedStorage/TardisConfig.lua")
bloc = cfgsrc[cfgsrc.index("Config.Ecrans = {"):cfgsrc.index("\n}", cfgsrc.index("Config.Ecrans = {"))]
nouvelles = [l for l in bloc.splitlines() if any(l.strip().startswith(n + " =") for n in ("Resolution", "ResolutionMax", "FaceDestination", "FaceIngenieur"))]
verifier("1. Chaque nouveau réglage est marqué « (V6.9.10.3) »", len(nouvelles) == 4 and all("(V6.9.10.3)" in l for l in nouvelles), nouvelles)
verifier("1. PixelsParStud décrit comme un minimum", "PixelsParStud = 20" in bloc and "minimum" in bloc.split("PixelsParStud = 20")[1].split("\n")[0])

canal = Instance("RemoteEvent", "TardisCommande_TARDIS_1", rs)
pilote.attrs["TardisPilote_TARDIS_1"] = True
visiteur = Instance("Player", "Amy", Players); visiteur.props.update({"UserId": 202, "DisplayName": "Amy"})
SRC_ECRANS = lire("ServerScriptService/TardisServeur/Ecrans.lua")

def charger(construire, avancer=0.05):
    """Une salle : Console (Model, centre (0, 3, 0)) ; construire(console) y pose les écrans. Renvoie (cabine, salle, module, sortie)."""
    roblox.ERREURS.clear()
    xs = Instance("Model", "Cabine"); salle = Instance("Folder", "INTERIEURE")
    console = Instance("Model", "Console", salle)
    console.props.update({"BoiteCFrame": CF((0, 3, 0)), "BoiteTaille": Vec3(8, 4, 8)})
    piece("Socle", console, (0, 1.5, 0), (8, 3, 8))
    infos = construire(console) or {}
    xs.attrs.update({"Etat": "Pose", "Mode": "Normal", "Alimentation": True, "PointsDeVie": 80, "PV": 8000, "PVMax": 10000,
                     "RegulEnergie": 80, "RegulAir": 100, "RegulVapeur": 50, "BouclierEnergie": 100})
    ctx = Table({"Config": Config, "E": E, "Players": Players, "def": Config.get("Tardis").get(1), "exterieur": xs, "interieur": salle, "remote": canal,
                 "destinationChoisie": Fonction("destinationChoisie", py=lambda: [Instance("Part", "Site-19")]),
                 "etatActuel": Fonction("etatActuel", py=lambda: xs.attrs.get("Etat") or "Pose")})
    debut = len(roblox.SORTIE)
    res = {}
    tache(lambda: res.update(m=premier(appeler(premier(I.executer(SRC_ECRANS, "Ecrans")), [ctx]))))
    H.avancer(avancer)
    infos.update(xs=xs, salle=salle, console=console, module=res.get("m"), sortie=roblox.SORTIE[debut:], erreurs=list(roblox.ERREURS))
    return infos

gui_de = lambda p, nom="TardisEcranDestination": (enfant_classe(p, "SurfaceGui", nom) or [None])[0]
face_de = lambda g: g.props["Face"].nom.split(".")[-1] if g is not None else None
toile = lambda g, p: tuple(round(x * g.props["PixelsPerStud"], 3) for x in taille_face(p, face_de(g))) if g is not None else (0, 0)
def taille_face(p, face):
    """Taille (studs) de l'image d'une SurfaceGui, comme dans Roblox. V6.9.10.5 : sur Top et Bottom, le haut de l'image va
    vers la face Right (+X) : la largeur court le long de Z et la hauteur le long de X (avant : (X, Z), à l'envers)."""
    s = p.props["Size"]
    if face in ("Top", "Bottom"): return (s.z, s.x)
    if face in ("Left", "Right"): return (s.z, s.y)
    return (s.x, s.y)

# ================================================================== 2. Netteté
def ecrans_tailles(console):
    return {"petit": piece("Ecran", console, (0, 4, -4), (2, 1.2, 0.1)),        # le petit écran du propriétaire (≈ 2 studs)
            "moyen": piece("Ecran", console, (0, 4, 4), (3.5, 2, 0.1)),
            "grand": piece("Ecran", console, (4, 6, 0), (30, 15, 0.2)),
            "geant": piece("Ecran", console, (-4, 6, 0), (200, 100, 0.2)),
            "minuscule": piece("Ecran", console, (-4, 4, 0), (0.3, 0.2, 0.05))}
S = charger(ecrans_tailles)
verifier("Module chargé sans erreur (cinq écrans de destination)", S["module"] is not None and not S["erreurs"], S["erreurs"][:3])
g = {k: gui_de(S[k]) for k in ("petit", "moyen", "grand", "geant", "minuscule")}
verifier("2. Un affichage sur chaque écran", all(g.values()), {k: v is not None for k, v in g.items()})
t = {k: toile(g[k], S[k]) for k in g}
verifier("2. Petit écran (2 × 1,2 studs) : 1024 × 614 pixels (avant : 100 × 60 avec 50 pixels par stud)", t["petit"] == (1024.0, 614.4), t["petit"])
verifier("2. Écran de 3,5 studs : 1024 pixels sur le grand côté", t["moyen"][0] == 1024.0, t["moyen"])
verifier("2. Grand écran (30 studs) : 1024 pixels aussi (pas d'image inutilement énorme)", t["grand"] == (1024.0, 512.0), t["grand"])
verifier("2. Écran géant (200 studs) : plafond de 2048 pixels (le minimum de 20 pixels par stud en donnerait 4000)", t["geant"][0] == 2048.0, t["geant"])
verifier("2. Pièce minuscule (0,3 stud) : 1024 pixels quand même", t["minuscule"][0] == 1024.0, t["minuscule"])
verifier("2. Au moins 1000 pixels sur le grand côté de chaque écran, au plus 2048", all(1000 <= max(v) <= 2048 for v in t.values()), t)
verifier("2. LightInfluence 0, taille en pixels par stud, au-dessus d'un Decal (ZOffset)", all(x.props["LightInfluence"] == 0 and x.props["SizingMode"].nom.endswith("PixelsPerStud")
         and x.props.get("ZOffset", 0) >= 1 for x in g.values()))
S["petit"].__lua_setindex__("Size", Vec3(4, 2.4, 0.1))  # la pièce grandit dans Studio pendant un test (signal Size)
verifier("2. La pièce change de taille (4 × 2,4 studs) : finesse recalculée (256 pixels par stud, toujours 1024 × 614)", g["petit"].props["PixelsPerStud"] == 256 and toile(g["petit"], S["petit"]) == (1024.0, 614.4),
         (g["petit"].props["PixelsPerStud"], toile(g["petit"], S["petit"])))
S["petit"].m_SetAttribute("FaceEcran", "Top")
verifier("2. La face change (FaceEcran = Top) : finesse recalculée pour cette face (image de 0,1 × 4 studs : Z en largeur, X en hauteur)",
         face_de(g["petit"]) == "Top" and toile(g["petit"], S["petit"]) == (25.6, 1024.0), toile(g["petit"], S["petit"]))
S["petit"].m_SetAttribute("FaceEcran", None)

# ================================================================== 3. Lisibilité
gp = gui_de(S["moyen"]); hauteur = toile(gp, S["moyen"])[1]
fond = champ(gp, "Fond")
labels = [e for e in descendants(fond) if e.ClassName == "TextLabel" and not (e.parent and e.parent.Name == "Bandeau")]
hauteurs = {e.Name: e.props["Size"].args[1] for e in labels}
verifier("3. Écran de destination : titre, « DESTINATION », lieu, état, mode, statuts", set(hauteurs) >= {"Titre", "EtiquetteDestination", "Destination", "Etat", "Mode", "Statuts"}, sorted(hauteurs))
verifier("3. Chaque ligne fait au moins 8 % de la hauteur de l'écran (avant : 6,5 % pour « DESTINATION », 7,5 % pour le mode)",
         all(h >= 0.08 for h in hauteurs.values()), hauteurs)
verifier("3. … soit au moins 45 pixels de haut sur un écran de 3,5 × 2 studs", all(h * hauteur >= 45 for h in hauteurs.values()), {k: round(v * hauteur) for k, v in hauteurs.items()})
verifier("3. Le lieu (destination) est la ligne la plus grande", hauteurs["Destination"] == max(hauteurs.values()) and hauteurs["Destination"] >= 0.2)
verifier("3. Cinq lignes au plus sous le titre (l'état et le mode partagent une ligne)",
         len({round(e.props["Position"].args[1], 3) for e in labels if e.Name != "Titre"}) <= 5, sorted({round(e.props["Position"].args[1], 3) for e in labels}))
contraintes = {e.Name: champ(e, "TailleMinimale") for e in labels}
longues = ("Titre", "Etat", "Mode", "Statuts")
verifier("3. Lignes longues : TextScaled avec UITextSizeConstraint (taille minimale), sur une ligne, coupées au bout (« … »)",
         all(contraintes[n] is not None and contraintes[n].ClassName == "UITextSizeConstraint" and labels[[l.Name for l in labels].index(n)].props["TextScaled"] is True
             and labels[[l.Name for l in labels].index(n)].props["TextWrapped"] is False for n in longues), {n: contraintes[n] is not None for n in longues})
mins = {n: contraintes[n].props.get("MinTextSize", 0) if contraintes[n] else 0 for n in longues}
verifier("3. Taille minimale du texte ≥ 4,5 % de la hauteur de l'écran, et jamais plus grande que la ligne", all(mins[n] >= 0.045 * hauteur and mins[n] <= hauteurs[n] * hauteur for n in longues), (mins, hauteur))
verifier("3. Le lieu peut passer sur deux lignes (nom long)", champ(fond, "Destination").props["TextWrapped"] is True)
band = champ(fond, "LigneVivante")
verifier("3. Bande de la ligne vivante (Ambiance › TardisVivant) gardée, plus haute (13 % de l'écran)", band is not None and band.ClassName == "Frame" and band.props["Size"].args[1] >= 0.12
         and band.props["BackgroundTransparency"] == 1 and not band.enfants, band and band.props["Size"].args)
cp = champ(champ(gui_de(S["petit"]), "Statuts"), "TailleMinimale")
verifier("3. Sur le petit écran (1,2 stud de haut), la taille minimale suit sa hauteur", cp is not None and
         cp.props.get("MinTextSize") == math.floor(0.05 * toile(gui_de(S["petit"]), S["petit"])[1] + 0.5))
verifier("3. Contenu toujours affiché (destination, état, mode, statuts)", texte_de(champ(fond, "Destination")) == "SITE-19" and texte_de(champ(fond, "Etat")) == "●  POSÉ"
         and texte_de(champ(fond, "Mode")) == "MODE : CLASSIQUE" and texte_de(champ(fond, "Statuts")) == "SYSTÈMES NOMINAUX")
verifier("2. Aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])

# ================================================================== 4. Écran ingénieur
A30 = math.radians(30)
def ing_plaque_top(console):
    # Plaque fine (épaisse en Y) posée sur la pente de la console, du côté +X : son grand côté Top regarde en haut et dehors.
    # Sa face Front (3 × 0,2 studs) n'est qu'une tranche : c'est là que l'écran était dessiné avant (rectangle sombre).
    return {"ing": piece("Ecran-Ingenieure", console, (4, 4, 0), (3, 0.2, 2), _rz(-A30))}
S = charger(ing_plaque_top)
gi = gui_de(S["ing"], "TardisEcranIngenieur")
verifier("4. Écran ingénieur fait en script, sans erreur", gi is not None and not S["erreurs"], S["erreurs"][:3])
verifier("4. Plaque inclinée (pièce) : face Top choisie seule (la face Front n'est qu'une tranche de 0,2 stud)", face_de(gi) == "Top", face_de(gi))
verifier("4. Allumé, sans voile (ni HORS TENSION, ni DÉTRUIT)", gi.props.get("Enabled") is True and champ(gi, "Veille").props["Visible"] is False and champ(gi, "Detruit").props["Visible"] is False)
val = lambda g_, cle: texte_de(champ(g_, "Valeur_" + cle))
# (V6.9.10.7 : « BOUCLIERS » et « INACTIFS », comme la maquette de l'écran ingénieur et la tablette)
verifier("4. Contenu présent : intégrité (PV), énergie, air, vapeur, bouclier", (val(gi, "integrite"), val(gi, "energie"), val(gi, "air"), val(gi, "vapeur"), val(gi, "bouclier"))
         == ("80 %  ·  8000 PV", "80 %", "100 %", "50 %", "INACTIFS  ·  100 %"), [val(gi, c) for c in ("integrite", "energie", "air", "vapeur", "bouclier")])
verifier("4. Noms des lignes et titre affichés", [texte_de(champ(gi, "Nom_" + c)) for c in ("integrite", "energie", "air", "vapeur", "bouclier")] == ["INTÉGRITÉ", "ÉNERGIE", "AIR", "VAPEUR", "BOUCLIERS"]
         and "INGÉNIERIE" in texte_de(champ(gi, "Titre")))
ti = toile(gi, S["ing"])
verifier("4. Écran ingénieur net : 683 × 1024 pixels (face Top de 3 × 2 studs : l'image a 2 studs de large le long de Z et 3 de haut le long de X)",
         ti == (round(2 * 1024 / 3, 3), 1024.0), ti)
labels_i = [e for e in descendants(champ(gi, "Fond")) if e.ClassName == "TextLabel"]
verifier("4. Chaque ligne de l'écran ingénieur fait au moins 8 % de sa hauteur (avant : 6,5 %)", all(e.props["Size"].args[1] >= 0.08 for e in labels_i), {e.Name: e.props["Size"].args[1] for e in labels_i})
verifier("4. Valeurs avec une taille de texte minimale", all(champ(champ(gi, "Valeur_" + c), "TailleMinimale") is not None for c in ("integrite", "energie", "air", "vapeur", "bouclier")))
xs = S["xs"]; xs.m_SetAttribute("PointsDeVie", 15); xs.m_SetAttribute("PV", 1500); H.avancer(0.2)
verifier("4. Mis à jour en direct (PV bas)", val(gi, "integrite") == "15 %  ·  1500 PV", val(gi, "integrite"))
S["ing"].m_SetAttribute("FaceEcran", "Left")
verifier("4. FaceEcran explicite sur la pièce (Left) respecté, en jeu aussi", face_de(gi) == "Left", face_de(gi))
S["ing"].m_SetAttribute("FaceEcran", "Aucune")
verifier("4. FaceEcran = Aucune : pas d'affichage", gi.props.get("Enabled") is False)
S["ing"].m_SetAttribute("FaceEcran", None)
verifier("4. Attribut retiré : retour à la face automatique (Top)", face_de(gi) == "Top" and gi.props.get("Enabled") is True)
clic = enfant_classe(S["ing"], "ClickDetector"); invite = enfant_classe(S["ing"], "ProximityPrompt")
verifier("4. Clic et invite toujours sur la pièce", len(clic) == 1 and len(invite) == 1)
n = len(canal.extra.get("envoisClient", [])); clic[0].extra.setdefault("MouseClick", Signal("MouseClick")).declencher(pilote); H.avancer(0.1)
verifier("4. Clic d'un pilote : menu de l'énergie, avec la pièce de l'écran", canal.extra.get("envoisClient", [])[n:] == [[pilote, "__energie", S["ing"]]], canal.extra.get("envoisClient", [])[n:])

def ing_plaque_front(console):
    # Plaque construite debout (fine en Z), basculée vers l'arrière, côté +Z : sa face Front regarde en haut et dehors
    return {"ing": piece("Ecran-Ingenieure", console, (0, 4, 4), (3, 2, 0.2), _rx(math.radians(150)))}
S = charger(ing_plaque_front); gi = gui_de(S["ing"], "TardisEcranIngenieur")
verifier("4. Plaque debout basculée (Front vers les joueurs) : face Front", face_de(gi) == "Front", face_de(gi))
def ing_plaque_back(console):
    return {"ing": piece("Ecran-Ingenieure", console, (0, 4, 4), (3, 2, 0.2), _rx(-A30))}
S = charger(ing_plaque_back); gi = gui_de(S["ing"], "TardisEcranIngenieur")
verifier("4. Même plaque à l'envers (Back vers les joueurs) : face Back (pas la face collée à la console)", face_de(gi) == "Back", face_de(gi))
def ing_plaque_cote(console):
    # De l'autre côté de la console (−X) : la face qui regarde dehors est l'autre
    return {"ing": piece("Ecran-Ingenieure", console, (-4, 4, 0), (3, 0.2, 2), _rz(A30))}
S = charger(ing_plaque_cote); gi = gui_de(S["ing"], "TardisEcranIngenieur")
verifier("4. Côté −X de la console : la face qui regarde vers −X et vers le haut (Top)", face_de(gi) == "Top", face_de(gi))

# Model : un bouton trouvé en premier, un boîtier, une vitre ; la vitre porte l'affichage
def ing_modele_vitre(console):
    m = Instance("Model", "Ecran-Ingenieure", console)
    bouton = piece("Bouton", m, (4, 4.3, 0.8), (0.3, 0.3, 0.3), _rz(-A30))
    boitier = piece("Boitier", m, (3.95, 3.9, 0), (3.4, 0.4, 2.4), _rz(-A30))
    vitre = piece("Vitre", m, (4.05, 4.1, 0), (3, 0.05, 2), _rz(-A30))
    return {"modele": m, "bouton": bouton, "boitier": boitier, "vitre": vitre}
S = charger(ing_modele_vitre)
verifier("4. Model : affichage sur la Vitre (pièce nommée comme un écran), pas sur le bouton trouvé en premier ni le boîtier",
         gui_de(S["vitre"], "TardisEcranIngenieur") is not None and gui_de(S["bouton"], "TardisEcranIngenieur") is None and gui_de(S["boitier"], "TardisEcranIngenieur") is None)
gi = gui_de(S["vitre"], "TardisEcranIngenieur")
verifier("4. Model : face automatique Top sur la vitre inclinée", face_de(gi) == "Top", face_de(gi))
verifier("4. Model : clic sur tout le Model (ClickDetector du Model), invite sur la vitre", len(enfant_classe(S["modele"], "ClickDetector")) == 1 and len(enfant_classe(S["vitre"], "ProximityPrompt")) == 1)
verifier("4. Model : contenu présent", val(gi, "energie") == "80 %" and val(gi, "bouclier") == "INACTIFS  ·  100 %")
verifier("4. Model : ecranIngenieur() rend la vitre (distance du menu de l'énergie)", premier(appeler(S["module"].get("ecranIngenieur"), [])) is S["vitre"])
S["modele"].m_SetAttribute("FaceEcran", "Bottom")
verifier("4. FaceEcran explicite sur le Model (Bottom) respecté", face_de(gi) == "Bottom", face_de(gi))

def ing_modele_sans_nom(console):
    m = Instance("Model", "Ecran-Ingenieure", console)
    m.props["PrimaryPart"] = None
    bouton = piece("Bouton", m, (4, 4.3, 0.8), (0.3, 0.3, 0.3))
    zone = piece("Zone", m, (4, 4, 0), (5, 3, 4)); zone.props["Transparency"] = 1   # zone de clic invisible, plus grande
    plaque = piece("Plaque", m, (4, 4, 0), (3, 0.2, 2), _rz(-A30))
    return {"modele": m, "bouton": bouton, "zone": zone, "plaque": plaque}
S = charger(ing_modele_sans_nom)
verifier("4. Model sans pièce nommée : la plus grande pièce VISIBLE (la plaque, pas la zone invisible ni le bouton)",
         gui_de(S["plaque"], "TardisEcranIngenieur") is not None and gui_de(S["zone"], "TardisEcranIngenieur") is None and gui_de(S["bouton"], "TardisEcranIngenieur") is None)

def ing_modele_designe(console):
    m = Instance("Model", "Ecran-Ingenieure", console)
    vitre = piece("Vitre", m, (4, 4, 0), (3, 0.05, 2))
    choisie = piece("Affiche", m, (4, 4.5, 0), (1, 1, 0.1)); choisie.attrs["FaceEcran"] = "Front"
    cadre = piece("Cadre", m, (4, 4, 0), (4, 0.3, 3)); cadre.attrs["FaceEcran"] = "Aucune"
    return {"vitre": vitre, "choisie": choisie, "cadre": cadre}
S = charger(ing_modele_designe)
gi = gui_de(S["choisie"], "TardisEcranIngenieur")
verifier("4. Model : la pièce qui porte l'attribut FaceEcran est choisie, avec sa face (Front)", gi is not None and face_de(gi) == "Front" and gui_de(S["vitre"], "TardisEcranIngenieur") is None
         and gui_de(S["cadre"], "TardisEcranIngenieur") is None, gi and face_de(gi))

def ing_inconnue(console):
    p = piece("Ecran-Ingenieure", console, (4, 4, 0), (3, 0.2, 2), _rz(-A30)); p.attrs["FaceEcran"] = "Dessus"
    return {"ing": p}
S = charger(ing_inconnue); gi = gui_de(S["ing"], "TardisEcranIngenieur")
verifier("4. FaceEcran inconnu : avertissement, puis la face automatique (Top)", face_de(gi) == "Top" and any("Dessus" in l and "Auto" in l for l in S["sortie"] if l.startswith("⚠")),
         [l for l in S["sortie"] if l.startswith("⚠")])

# Le cas du propriétaire avec un MeshPart (même règle : boîte de la pièce)
def ing_mesh(console):
    return {"ing": piece("Ecran-Ingenieure", console, (4, 4, 0), (3, 0.2, 2), _rz(-A30), classe="MeshPart")}
S = charger(ing_mesh); gi = gui_de(S["ing"], "TardisEcranIngenieur")
verifier("4. MeshPart : face automatique aussi (Top)", gi is not None and face_de(gi) == "Top")

# ================================================================== 5. Écrans de destination : Front par défaut, « Auto » accepté
def dest_auto(console):
    defaut = piece("Ecran", console, (0, 4, -4), (3, 0.2, 2), _rx(-A30))
    auto = piece("Ecran", console, (0, 4, -4), (3, 0.2, 2), _rx(-A30)); auto.attrs["FaceEcran"] = "Auto"
    modele = Instance("Model", "Ecran", console); modele.attrs["FaceEcran"] = "auto"
    gauche = piece("Gauche", modele, (4, 4, 0), (3, 0.2, 2), _rz(-A30))
    return {"defaut": defaut, "auto": auto, "gauche": gauche}
S = charger(dest_auto)
verifier("5. Écran de destination sans attribut : Front, comme avant (celui du propriétaire s'affiche déjà bien)", face_de(gui_de(S["defaut"])) == "Front")
# Côté −Z, basculée de −30° autour de X : UpVector = (0, 0,87, −0,5) → regarde en haut et vers −Z (dehors) : Top
verifier("5. FaceEcran = Auto sur un écran de destination : la face visible (Top)", face_de(gui_de(S["auto"])) == "Top", face_de(gui_de(S["auto"])))
verifier("5. « auto » sur le Model « Ecran » (minuscules acceptées)", face_de(gui_de(S["gauche"])) == "Top", face_de(gui_de(S["gauche"])))
verifier("5. Aucune erreur", not S["erreurs"], S["erreurs"][:3])

# ================================================================== 6. Output au démarrage
def complet(console):
    e1 = piece("Ecran", console, (0, 4, -4), (2, 1.2, 0.1))
    e2 = piece("Ecran", console, (0, 4, 4), (2, 1.2, 0.1)); e2.attrs["FaceEcran"] = "Back"
    m = Instance("Model", "Ecran-Ingenieure", console)
    piece("Bouton", m, (4, 4.3, 0.8), (0.3, 0.3, 0.3))
    piece("Vitre", m, (4, 4, 0), (3, 0.05, 2), _rz(-A30))
    return {}
S = charger(complet, avancer=0.01)
lignes = [l for l in S["sortie"] if "écrans de la console" in l]
verifier("6. Une seule ligne dans l'Output au démarrage", len(lignes) == 1, S["sortie"])
L = lignes[0] if lignes else ""
verifier("6. Elle nomme le TARDIS et chaque écran de destination, avec sa face et sa taille en pixels",
         L.startswith("[TARDIS] TARDIS_1 · écrans de la console : ") and L.count("destination « Console › Ecran » : face ") == 2
         and "face Front, sens 0° (1024 × 614 px)" in L and "face Back, sens 0° (1024 × 614 px)" in L, L)
verifier("6. … et l'écran ingénieur : la pièce choisie dans le Model et sa face automatique", "ingénieur « Console › Ecran-Ingenieure › Vitre » : face Top (auto), sens 180° (auto) (683 × 1024 px)" in L, L)  # V6.9.10.5 : vraie image de la face Top
n6 = len(roblox.SORTIE); H.avancer(12)
verifier("6. Pas de deuxième ligne ensuite (12 s plus tard)", not [l for l in roblox.SORTIE[n6:] if "écrans de la console" in l], roblox.SORTIE[n6:])
tard = piece("Ecran", S["console"], (0, 4, 0), (2, 1.2, 0.1))
S["console"].extra["DescendantAdded"].declencher(tard)  # (la simulation ne déclenche pas DescendantAdded seule)
verifier("6. Un écran ajouté plus tard a sa propre ligne", any("nouvel écran : destination « Console › Ecran » : face Front" in l for l in roblox.SORTIE[-3:]), roblox.SORTIE[-3:])
def sans_ingenieur(console):
    piece("Ecran", console, (0, 4, -4), (2, 1.2, 0.1))
S = charger(sans_ingenieur, avancer=11)
L = ([l for l in S["sortie"] if "écrans de la console" in l] or [""])[0]
verifier("6. Écran ingénieur absent : la ligne le dit (introuvable), après l'attente de 10 s", "ingénieur « Console › Ecran-Ingenieure » introuvable" in L and "destination « Console › Ecran »" in L, L)
def aucune(console):
    p = piece("Ecran", console, (0, 4, -4), (2, 1.2, 0.1)); p.attrs["FaceEcran"] = "Aucune"
    piece("Ecran-Ingenieure", console, (4, 4, 0), (3, 0.2, 2), _rz(-A30))
S = charger(aucune)
L = ([l for l in S["sortie"] if "écrans de la console" in l] or [""])[0]
verifier("6. « Aucune » dit dans la ligne", "aucune face (FaceEcran = Aucune)" in L and "ingénieur « Console › Ecran-Ingenieure » : face Top (auto)" in L, L)
verifier("Serveur (Ecrans) : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])

# ================================================================== Code : pas de boucle, pas de pcall autour du dessin
verifier("Pas de boucle côté serveur (ni while, ni Heartbeat, ni task.wait)", all(m not in SRC_ECRANS for m in ("while true", "task.wait(", "Heartbeat", "RenderStepped")))
verifier("La création des écrans n'est pas cachée dans un pcall (une erreur se verrait dans l'Output)", "pcall(creer" not in SRC_ECRANS and "pcall(function() creer" not in SRC_ECRANS)

print("\n".join("  ✓ " + o for o in OK)); print("\n".join("  ✗ " + k for k in KO))
print(f"V6.9.10.3 : {len(OK)}/{len(OK) + len(KO)} vérifications réussies")
sys.exit(1 if KO else 0)
