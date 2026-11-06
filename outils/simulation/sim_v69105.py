"""Simulations de la V6.9.10.5 (retours du test dans Studio de la V6.9.10.4) : le vrai code, avec des maths réelles
(roblox.activer_maths : positions, rotations, points d'attache) et de faux services Roblox (InsertService, rayons).
  1. TardisConfig : nouveaux réglages marqués « (V6.9.10.5) » (hauteur des invites, caméra des casiers, dossier du
     jukebox), aucun identifiant de musique inventé, mots de recherche de la Toolbox dans le commentaire.
  2. Bouton Vol libre en Model (Console › Selecteur › Colors) : vrai TardisServeur (Selecteur, levier, traiterOrdre,
     bloc du bouton) et vrai module VolLibre : clic sur tout le Model, invite « Vol libre » (F) sur un point d'attache
     1,5 stud au-dessus du bouton, sans ligne de vue, 10 studs ; l'invite du Selecteur (E) reste visible, sur une autre
     pièce ; trop proches : écartées à l'écran ; clic ou invite → vol libre pour un pilote seulement.
  3. Mêmes invites relevées pour les autres commandes : jukebox en Model (vrai TardisExtras), alerte (vrai
     brancherCommande, même pièce qu'avant pour TardisSystemes).
  4. Caméra du casier (vrai module Interactions) : rayons depuis la tête, place la plus dégagée (devant, devant à gauche,
     devant à droite, plus haut), arrêt avant le mur, rien ne bouge si tout est bouché, personnage et pièces invisibles
     ou sans requête ignorés ; caméra rendue exactement (Échap, bouton, distance, mort, réapparition) ; casier en Model.
  5. Tenues sur le serveur (vrai TardisTenues, vrai TardisExtras) : identifiants du catalogue changés en vraies images
     (InsertService:LoadAsset simulé), cache par identifiant, 2 nouveaux essais, objet sans vêtement (identifiant pris
     comme image), ligne de l'Output seulement en cas d'échec, accessoires gardés, échec = vêtements gardés + message,
     dernier recours HumanoidDescription ; action « Tenue » (à bord seulement).
  6. Aperçu chez le joueur (vrai Interactions) : les images données par le serveur, jamais l'identifiant du catalogue ;
     introuvable ou en cours : vêtements gardés et message ; « __tenue » refusé : aperçu retiré.
  7. Régénération (vrai TardisSystemes, habillerTenueJeu) : même résolution, tenue introuvable = vêtements gardés.
  8. Jukebox : dossier ReplicatedStorage › TardisAssets › Jukebox créé, Sound = pistes (nom, attribut Categorie ou
     sous-dossier) réunies à Config.Jukebox et triées (catégorie puis nom), mêmes numéros sur le serveur et chez le
     joueur (Config.Jukebox mis à jour pour la tablette) ; vrai TardisExtras : seules les pistes et playlists connues
     passent ; vrai module Console : liste, liste vide qui explique comment la remplir ; vrai Ambiance : une piste du
     dossier joue une copie de son Sound."""
import os, sys, math, re
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from monde import *
import roblox
from roblox import Vec3, CF, activer_maths, en_vec3, _rx, _ry, _rz, Couleur
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
def de_classe(o, classe): return [e for e in descendants(o) if e.ClassName == classe]
def declencher(objet, signal, *args):
    objet.extra.setdefault(signal, Signal(signal)).declencher(*args)
def texte_de(o): return str(o.props.get("Text", "")) if o is not None else None
def trouve(racine_, nom):
    for e in descendants(racine_):
        if e.Name == nom: return e
R = {}

def piece(nom, parent, pos=(0, 0, 0), taille=(2, 2, 2), rot=None, classe="Part"):
    p = Instance(classe, nom, parent)
    p.props.update({"CFrame": CF(pos, rot), "Size": Vec3(*taille), "Position": Vec3(*pos)})
    return p
def boite_monde(parts):
    """Boîte du monde (min, max) de pièces orientées : la même règle que Config.pointInvite."""
    mn, mx = [math.inf] * 3, [-math.inf] * 3
    for p in parts:
        cf, s = p.props["CFrame"], p.props["Size"]
        for i in range(3):
            e = (abs(cf.R[i][0]) * s.x + abs(cf.R[i][1]) * s.y + abs(cf.R[i][2]) * s.z) / 2
            mn[i], mx[i] = min(mn[i], cf.p[i] - e), max(mx[i], cf.p[i] + e)
    return mn, mx
def monde_attache(att):
    if att.ClassName != "Attachment": return Vec3(*att.props["CFrame"].p)  # (V6.9.10.8) invite posée sur la pièce
    return att.parent.props["CFrame"].point(att.props["Position"])
def proche(a, b, tol=1e-6): return all(abs(x - y) <= tol for x, y in zip(a, b))
def dist(a, b): return math.sqrt(sum((x - y) ** 2 for x, y in zip(a.t(), b.t())))

cfgsrc = lire("ReplicatedStorage/TardisConfig.lua")
serveur = lire("ServerScriptService/TardisServeur/init.server.lua")
extras = lire("ServerScriptService/TardisExtras.server.lua")
systemes = lire("ServerScriptService/TardisSystemes.server.lua")
interactions_src = lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Interactions.lua")

# ================================================================== 1. TardisConfig
vider_cache(); roblox.ERREURS.clear()
I, G, game, pilote = monde(serveur=True)
activer_maths(G)
rs = game.m_FindFirstChild("ReplicatedStorage"); Players = game.m_FindFirstChild("Players"); ws = game.m_FindFirstChild("Workspace")
tache(lambda: R.update(Config=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisConfig")]))))
Config = R["Config"]; E = Config.get("Etats")
BV, IC, CA, JD = Config.get("BoutonVolLibre"), Config.get("InvitesConsole"), Config.get("Casiers"), Config.get("JukeboxDossier")
verifier("1. Config.BoutonVolLibre.HauteurInvite = 1,5 ; Distance au moins 10 ; touche F", BV.get("HauteurInvite") == 1.5 and BV.get("Distance") >= 10 and BV.get("Touche") == "F",
         (BV.get("HauteurInvite"), BV.get("Distance")))
verifier("1. Config.InvitesConsole.HauteurInvite = false (V6.9.10.8 : invites de la console revenues sur leur commande)", IC.get("HauteurInvite") is False)
verifier("1. Config.Casiers : caméra à 7 studs, dégagement minimal, marge, fermeture à 12 studs",
         (CA.get("DistanceCamera"), CA.get("DistanceMinimale"), CA.get("Marge"), CA.get("DistanceFermeture")) == (7, 2.5, 0.5, 12))
verifier("1. Config.JukeboxDossier : dossier « Jukebox », attribut « Categorie », catégories Doctor Who",
         JD.get("Nom") == "Jukebox" and JD.get("AttributCategorie") == "Categorie"
         and [JD.get("Categories").get(i) for i in range(1, 6)] == ["Thèmes", "Ambiance de bord", "Vortex", "Action", "Émotion"])
lignes_v = [l for l in cfgsrc.splitlines() if "(V6.9.10.5)" in l and re.match(r"\s*\w+ = ", l)]
noms_v = sorted(re.match(r"\s*(\w+) = ", l).group(1) for l in lignes_v)
verifier("1. Chaque nouveau réglage est marqué « (V6.9.10.5) » (8 lignes ; V6.9.10.8 : InvitesConsole.HauteurInvite remarqué)", noms_v == sorted(["HauteurInvite", "DistanceCamera", "DistanceMinimale", "Marge",
         "DistanceFermeture", "Nom", "AttributCategorie", "Categories"]), noms_v)
verifier("1. Version 6.9.10.5 ou plus récente", tuple(int(p) for p in str(Config.get("Version")).split(".") if p.isdigit()) >= (6, 9, 10, 5), Config.get("Version"))
bloc_j = cfgsrc[cfgsrc.index("Config.Jukebox = {"):cfgsrc.index("\n}", cfgsrc.index("Config.Jukebox = {"))]
verifier("1. Aucun identifiant de musique inventé : Config.Jukebox ne contient que l'exemple en commentaire",
         [l.strip() for l in bloc_j.splitlines()[1:] if l.strip()] == ['-- { nom = "Nom de la musique", id = 1234567890, categorie = "Action" },'], bloc_j)
debut_c = cfgsrc.index("-- Jukebox (tablette › Ambiance")
com_j = cfgsrc[debut_c:cfgsrc.index("Config.Jukebox = {")]
verifier("1. Le commentaire donne les mots à chercher dans la Toolbox (Audio › Music) et rappelle la BBC",
         all(m in com_j for m in ('"sci-fi orchestral"', '"time travel"', '"space mystery"', '"adventure orchestral"', '"electronic suspense"', '"synth arpeggio"', "Audio › Music", "BBC"))
         and all(c in com_j for c in ("« Thèmes »", "« Ambiance de bord »", "« Vortex »", "« Action »", "« Émotion »")))


# ================================================================== 2. Bouton Vol libre en Model : vrai TardisServeur et vrai VolLibre
visiteur = Instance("Player", "Amy", Players); visiteur.props.update({"UserId": 202, "DisplayName": "Amy"})

def console_proprietaire(interieur, x_colors=3.0):
    """Console › Selecteur (Model : Socle, Molette, Colors) ; Colors est un Model dont la PREMIÈRE pièce (« Cadre ») est
    invisible et enfouie dans le Selecteur, les boutons visibles au-dessus ; Controls › Matlever › Fly › Levier."""
    console = Instance("Model", "Console", interieur)
    sel = Instance("Model", "Selecteur", console)
    socle = piece("Socle", sel, (0, 3, 0), (3, 1, 3))
    molette = piece("Molette", sel, (0, 3.75, 0.8), (0.6, 0.5, 0.6))
    colors = Instance("Model", "Colors", sel)
    cadre = piece("Cadre", colors, (x_colors, 3.2, 0), (0.4, 0.2, 0.4)); cadre.props["Transparency"] = 1
    rouge = piece("Rouge", colors, (x_colors, 3.7, -0.3), (0.3, 0.2, 0.3), _ry(math.pi / 4))
    vert = piece("Vert", colors, (x_colors, 3.7, 0.3), (0.3, 0.2, 0.3))
    ctr = Instance("Model", "Controls", interieur); ml = Instance("Model", "Matlever", ctr); fly = Instance("Model", "Fly", ml)
    levier = piece("Levier", fly, (-3, 3, 0), (0.3, 1.5, 0.3))
    return {"console": console, "selecteur": sel, "socle": socle, "molette": molette, "colors": colors, "cadre": cadre, "rouge": rouge, "vert": vert, "levier": levier}

def charger_bouton(x_colors):
    roblox.ERREURS.clear()
    xv = Instance("Model", "Cabine"); xv.attrs.update({"Etat": "Pose", "Mode": "Normal"})
    rv = piece("Racine", xv, (0, 0, 100), (4, 9, 4)); xv.props["PrimaryPart"] = rv
    salle = Instance("Model", "Salle"); P = console_proprietaire(salle, x_colors)
    partage = Table({"occupe": False})
    stub = lambda nom, r=None: Fonction(nom, py=lambda *a: [] if r is None else [r])
    ctxv = Table({"Config": Config, "E": E, "Players": Players, "exterieur": xv, "interieur": salle, "partage": partage, "echelleNormale": 1, "hauteurNormale": 9,
                  "chercherSol": Fonction("chercherSol", py=lambda *a: Vec3(0, 5, 0)), "dansInterieur": Fonction("dansInterieur", py=lambda *a: False),
                  "emmenerALInterieur": stub("emmener"), "etatActuel": Fonction("etat", py=lambda: xv.attrs.get("Etat")), "fermerPortes": Fonction("fermerPortes", py=lambda: True),
                  "jouer": stub("jouer"), "majEcran": stub("majEcran"), "majRamassage": stub("majRamassage"), "memoriserDepart": stub("memoriserDepart"),
                  "setCollisionsExterieur": stub("collisions"), "tropPetitPourLesPortes": Fonction("petit", py=lambda *a: False), "verifierEau": stub("eau"),
                  "jouerVoyage": stub("jouerVoyage"), "modeAutorise": Fonction("modeAutorise", py=lambda m, p=None: m)})
    tache(lambda: R.update(V=premier(appeler(premier(I.executer(lire("ServerScriptService/TardisServeur/VolLibre.lua"), "VolLibre")), [ctxv]))))
    V = R["V"]
    canal = Instance("RemoteEvent", "TardisCommande_TARDIS_1", Instance("Folder", "RSVol"))
    alertes = []
    prelude = """
local remote, exterieur, interieur, Config, E, V, pilotes, alerter = ...
local Players = game:GetService("Players")
local volLibre, reglagesVol = V.volLibre, V.reglagesVol
local recevoirPositionVol, changerPhaseVol, basculerPortesEnVol, lancerGlisse = V.recevoirPositionVol, V.changerPhaseVol, V.basculerPortesEnVol, V.lancerGlisse
local teleAtterrir, lancerDescente, freinerVol, demarrerVolLibre = V.teleAtterrir, V.lancerDescente, V.freinerVol, V.demarrerVolLibre
local function poserTardis() end
local function setCamouflage() end
local function marquerActivite() end
local function journal() end
local function etatActuel() return exterieur:GetAttribute("Etat") or E.Pose end
local dernierOrdre = {}
local ACTIONS_COPILOTE = { Demat = true, Remat = true, Camouflage = true, NavAtterrir = true }
"""
    en_part = serveur[serveur.index("local function enPart(objet, exclu)"):serveur.index("-- Le Selecteur garde son prompt")]
    objets = serveur[serveur.index('local objetSelecteur = Config.Trouver(interieur, "Selecteur")'):serveur.index("assert(exterieur.PrimaryPart")]
    creer_prompt = serveur[serveur.index("local function creerPrompt("):serveur.index("local dernierUsage = 0")]
    invites = serveur[serveur.index("local promptSelecteur, pointSelecteur = creerPrompt("):serveur.index("promptSelecteur.Triggered:Connect")]
    ordres = serveur[serveur.index("local ACTIONS_AILLEURS = {}"):serveur.index("Players.PlayerRemoving:Connect(function(joueur)\n\tdernierOrdre[joueur] = nil")]
    code = prelude + en_part + objets + creer_prompt + invites + ordres + "\nreturn { promptSelecteur = promptSelecteur, pointSelecteur = pointSelecteur, selecteur = selecteur }\n"
    pil = Table({pilote: True})
    tache(lambda: R.update(S=premier(I.executer(code, "ordres-serveur", (canal, xv, salle, Config, E, V, pil, Fonction("alerter", py=lambda m: alertes.append(m) or []))))))
    H.avancer(0.2)
    return {"xv": xv, "salle": salle, "P": P, "V": V, "S": R.get("S"), "canal": canal, "alertes": alertes, "partage": partage}

B = charger_bouton(3.0)
P = B["P"]
verifier("2. Vrai TardisServeur (Selecteur, levier, traiterOrdre, bouton Vol libre) et vrai VolLibre chargés", B["S"] is not None and not roblox.ERREURS, roblox.ERREURS[:3])
tache(lambda: R.update(pd=premier(appeler(Config.get("partDe"), [P["colors"]]))))
verifier("2. Cause : Config.partDe(Colors) rend la PREMIÈRE pièce du Model (« Cadre », invisible, enfouie dans le Selecteur) : avant, invite et clic y étaient",
         R["pd"] is P["cadre"], R["pd"] and R["pd"].Name)
clics = enfant_classe(P["colors"], "ClickDetector")
verifier("2. Clic sur TOUT le Model Colors (ClickDetector du Model : chacune de ses pièces répond), pas sur une pièce",
         len(clics) == 1 and clics[0].Name == "TardisVolLibre" and not de_classe(P["cadre"], "ClickDetector") and not de_classe(P["rouge"], "ClickDetector"), [e.ClassName for e in P["colors"].enfants])
invV = [e for e in de_classe(P["colors"], "ProximityPrompt") if e.props.get("ActionText") == "Vol libre"]
verifier("2. Une invite « Vol libre », sur un point d'attache (Attachment) dans le Model", len(invV) == 1 and invV[0].parent.ClassName == "Attachment", [(e.parent.ClassName, e.props.get("ActionText")) for e in invV])
iv = invV[0]
mn, mx = boite_monde([P["rouge"], P["vert"]])  # pièces VISIBLES du bouton
pv = monde_attache(iv.parent)
verifier("2. Point de l'invite : 1,5 stud au-dessus du haut du bouton (pièces visibles), au milieu", proche(pv.t(), ((mn[0] + mx[0]) / 2, mx[1] + 1.5, (mn[2] + mx[2]) / 2), 1e-6),
         (pv.t(), ((mn[0] + mx[0]) / 2, mx[1] + 1.5, (mn[2] + mx[2]) / 2)))
verifier("2. … donc au-dessus de toutes les pièces du Selecteur (rien ne le cache)", pv.y > boite_monde([P["socle"], P["molette"], P["cadre"], P["rouge"], P["vert"]])[1][1])
verifier("2. Invite : touche F (manette Y), sans ligne de vue, 10 studs au moins, active TARDIS posé",
         iv.props["KeyboardKeyCode"].nom == "Enum.KeyCode.F" and iv.props["GamepadKeyCode"].nom == "Enum.KeyCode.ButtonY" and iv.props["RequiresLineOfSight"] is False
         and iv.props["MaxActivationDistance"] >= 10 and iv.props.get("Enabled") is True, {k: iv.props.get(k) for k in ("MaxActivationDistance", "RequiresLineOfSight", "Enabled")})
verifier("2. Clic aussi à 10 studs au moins", clics[0].props["MaxActivationDistance"] >= 10)
invS = [e for e in de_classe(P["selecteur"], "ProximityPrompt") if e.props.get("ActionText") == "Changer de destination"]
verifier("2. L'invite du Selecteur (touche E par défaut) reste sur une AUTRE pièce que Colors : directement sur le Socle (V6.9.10.8 : à sa place d'origine)",
         len(invS) == 1 and invS[0].parent is P["socle"] and "KeyboardKeyCode" not in invS[0].props
         and not invS[0].parent.m_IsDescendantOf(P["colors"]), [(e.parent.Name) for e in invS])
ps = Vec3(*P["socle"].props["CFrame"].p)
verifier("2. Pas de point d'attache « TardisInvite » ajouté au Selecteur (V6.9.10.8)", not [e for e in de_classe(P["socle"], "Attachment") if e.Name == "TardisInvite"])
verifier("2. Deux invites, deux touches (E et F), à deux endroits : toutes deux visibles (Roblox n'en montre qu'une par touche)",
         dist(ps, pv) >= 2 and invS[0].props.get("UIOffset") is None and iv.props.get("UIOffset") is None, (dist(ps, pv), invS[0].props.get("UIOffset")))
invL = [e for e in de_classe(P["levier"], "ProximityPrompt")]
verifier("2. Le levier aussi : invite « Décoller » directement sur lui (V6.9.10.8)", len(invL) == 1 and invL[0].props["ActionText"] == "Décoller"
         and invL[0].parent is P["levier"], [e.parent.ClassName for e in invL])
xv, canal, alertes = B["xv"], B["canal"], B["alertes"]
declencher(clics[0], "MouseClick", visiteur); H.avancer(0.2)
verifier("2. Clic d'un non-pilote sur le bouton : rien (pas de vol libre, pas de message)", xv.attrs.get("VolLibre") is None and not alertes and not canal.extra.get("envoisClient"))
declencher(iv, "Triggered", visiteur); H.avancer(0.2)
verifier("2. Invite d'un non-pilote : rien non plus", xv.attrs.get("VolLibre") is None and not canal.extra.get("envoisClient"))
H.avancer(1.1)
declencher(clics[0], "MouseClick", pilote); H.avancer(0.3)
verifier("2. Clic d'un pilote (n'importe quelle pièce du Model) : vol libre lancé pour lui", xv.attrs.get("VolLibre") == 101 and B["partage"].get("occupe") is True, dict(xv.attrs).get("VolLibre"))
verifier("2. … réponse habituelle, invite cachée pendant le vol", canal.extra["envoisClient"][-1] == [pilote, "Vol libre activé : à toi de piloter !", True] and iv.props.get("Enabled") is False)
tache(lambda: appeler(B["V"].get("lancerDescente"), ["Douce", False])); H.avancer(15)
verifier("2. Fin du vol : l'invite revient", xv.attrs.get("VolLibre") is None and iv.props.get("Enabled") is True)
H.avancer(1.1)
declencher(iv, "Triggered", pilote); H.avancer(0.3)
verifier("2. Invite (touche F) d'un pilote : vol libre aussi", xv.attrs.get("VolLibre") == 101)
tache(lambda: appeler(B["V"].get("lancerDescente"), ["Douce", False])); H.avancer(15)
verifier("2. Aucune erreur (serveur)", not roblox.ERREURS, roblox.ERREURS[:3])
# Bouton juste sur le Selecteur : les deux points presque confondus → les invites sont écartées à l'écran
B2 = charger_bouton(0.2)
iv2 = [e for e in de_classe(B2["P"]["colors"], "ProximityPrompt")][0]
is2 = [e for e in de_classe(B2["P"]["selecteur"], "ProximityPrompt") if e.props.get("ActionText") == "Changer de destination"][0]
d2 = dist(monde_attache(iv2.parent), monde_attache(is2.parent))
# (V6.9.10.8 : l'invite du Selecteur est revenue au centre de sa pièce, le Vol libre reste 1,5 stud au-dessus de son bouton ;
# les deux points sont donc rarement à moins de 2 studs : on vérifie la règle dans les deux sens)
ecartees = iv2.props.get("UIOffset") is not None and is2.props.get("UIOffset") is not None and iv2.props["UIOffset"].args != is2.props["UIOffset"].args
verifier("2. Bouton collé au Selecteur : invites écartées à l'écran (UIOffset ±40) si leurs points sont à moins de 2 studs, sinon laissées telles quelles",
         ecartees if d2 < 2 else (iv2.props.get("UIOffset") is None and is2.props.get("UIOffset") is None),
         (d2, iv2.props.get("UIOffset"), is2.props.get("UIOffset")))


# ================================================================== 3. Les autres commandes : jukebox en Model (vrai TardisExtras), alerte (vrai brancherCommande)
roblox.ERREURS.clear()
salleX = Instance("Model", "Salle"); consX = Instance("Model", "Console", salleX)
juke = Instance("Model", "JukeBox", consX)
caisse = piece("Caisse", juke, (5, 2, 5), (2, 3, 1.5)); disque = piece("Disque", juke, (5, 3.8, 5), (1, 0.2, 1))
dp = Instance("Model", "Datapanel", consX); rb = Instance("Model", "Redbutton", dp); bouton_alerte = piece("Button", rb, (-2, 3.2, 2), (0.5, 0.3, 0.5))
xx = Instance("Model", "Cabine"); xx.attrs.update({"Etat": "Pose"})
canalX = Instance("RemoteEvent", "TardisCommande_TARDIS_1", Instance("Folder", "RSExtras"))
prelude_x = """
local remote, exterieur, interieur, Config, pilotes, DITS, dedans = ...
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local E = Config.Etats
local function estPilote(joueur) return pilotes[joueur] == true end
local function dire(joueur, message, ok) table.insert(DITS, { joueur, message, ok ~= false }) end
local dernier, invitations, dernierCarnet = {}, {}, {}
"""
jb = extras.index("do\n\tlocal derniersJukebox = {}"); fjb = extras.index("\nend\n", jb) + 5
dx = extras.index("remote.OnServerEvent:Connect(function(joueur, action, donnees)"); fx = extras.index("\nend)\n", dx) + 6
DITS = Table(); DEDANS = Table(); PIL = Table({pilote: True})
assets_avant = rs.m_FindFirstChild("TardisAssets")
tache(lambda: I.executer(prelude_x + extras[jb:fjb] + extras[dx:fx], "extras-serveur", (canalX, xx, salleX, Config, PIL, DITS, DEDANS)))
H.avancer(0.2)
verifier("3. Vrai bloc du jukebox et vrai gestionnaire de TardisExtras chargés", not roblox.ERREURS, roblox.ERREURS[:3])
cj = enfant_classe(juke, "ClickDetector"); pj = de_classe(juke, "ProximityPrompt")
verifier("3. Jukebox en Model : clic sur tout le Model, invite « Musique » (Z) sur une de ses pièces (V6.9.10.8)", len(cj) == 1 and len(pj) == 1 and pj[0].parent in (caisse, disque)
         and pj[0].props["ActionText"] == "Musique" and pj[0].props["KeyboardKeyCode"].nom == "Enum.KeyCode.Z", ([e.ClassName for e in juke.enfants], len(pj)))
mnj, mxj = boite_monde([caisse, disque])
verifier("3. … sans point d'attache au-dessus (V6.9.10.8)", not [e for e in de_classe(juke, "Attachment") if e.Name == "TardisJukebox"])
n = len(canalX.extra.get("envoisClient", [])); declencher(cj[0], "MouseClick", pilote); H.avancer(0.6); declencher(pj[0], "Triggered", visiteur); H.avancer(0.6)
verifier("3. Clic d'un pilote sur le jukebox : le panneau s'ouvre ; non-pilote : « Réservé aux pilotes. »",
         canalX.extra.get("envoisClient", [])[n:] == [[pilote, "__jukebox", caisse], [visiteur, "__console", "Réservé aux pilotes.", False]], canalX.extra.get("envoisClient", [])[n:])
dj = rs.m_FindFirstChild("TardisAssets") and rs.m_FindFirstChild("TardisAssets").m_FindFirstChild("Jukebox")
verifier("8. Le dossier ReplicatedStorage › TardisAssets › Jukebox est créé au démarrage par le serveur (absent avant)", assets_avant is None and dj is not None and dj.ClassName == "Folder")
# Alerte : vrai brancherCommande, invite au-dessus du bouton, dans la MÊME pièce qu'avant (TardisSystemes y cherche les invites)
bloc_bc = serveur[serveur.index("local function brancherCommande("):serveur.index("-- Alimentation : Controls")]
creer_prompt = serveur[serveur.index("local function creerPrompt("):serveur.index("local dernierUsage = 0")]
en_part = serveur[serveur.index("local function enPart(objet, exclu)"):serveur.index("-- Le Selecteur garde son prompt")]
xa = Instance("Model", "Cabine"); xa.attrs["Alerte"] = False
code_bc = ("local Config, interieur, exterieur, pilotes, alerter = ...\n" + en_part + creer_prompt + "local function marquerActivite() end\nlocal function disponible() return true end\n" + bloc_bc +
           "\nbrancherCommande(\"Alerte\", \"Lever l'alerte\", \"Déclencher l'alerte\", \"Alerte\", true, function() exterieur:SetAttribute(\"Alerte\", not exterieur:GetAttribute(\"Alerte\")) return true end, \"ALERTE GÉNÉRALE\", \"FIN DE L'ALERTE\")\n")
ALX = []
tache(lambda: I.executer(code_bc, "brancher-serveur", (Config, salleX, xa, PIL, Fonction("alerter", py=lambda m: ALX.append(m) or []))))
H.avancer(0.2)
pa = de_classe(bouton_alerte, "ProximityPrompt")
verifier("3. Alerte (vrai brancherCommande) : invite directement dans le bouton (V6.9.10.8)",
         len(pa) == 1 and pa[0].parent is bouton_alerte, [e.parent.ClassName for e in pa])
declencher(pa[0], "Triggered", pilote); H.avancer(0.2)
verifier("3. … et elle marche toujours (alerte déclenchée par un pilote)", xa.attrs.get("Alerte") is True and ALX == ["ALERTE GÉNÉRALE"], (xa.attrs.get("Alerte"), ALX))
sys_src_redem = systemes[systemes.index('prompt.Name = "TardisRedemarrage"'):systemes.index("exterieur:GetAttributeChangedSignal(\"RedemarrageRequis\"):Connect(majInvites)")]
verifier("3. TardisSystemes cache l'invite du levier d'alimentation par levier:GetDescendants() : elle reste trouvée (point d'attache dans la même pièce)",
         "for _, autre in levier:GetDescendants() do" in sys_src_redem)
verifier("3. Aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])


# ================================================================== 5. Tenues sur le serveur : vrai TardisTenues
sss = game.m_FindFirstChild("ServerScriptService")
mt = Instance("ModuleScript", "TardisTenues", sss); mt.extra["chemin"] = DEPOT + "/ServerScriptService/TardisTenues.lua"
TENUES = [(Config.get("Tenues").get(i).get("nom"), Config.get("Tenues").get(i).get("shirt"), Config.get("Tenues").get(i).get("pant")) for i in range(1, Config.get("Tenues").longueur() + 1)]
TENUES = [t for t in TENUES if (t[1] or 0) > 0 and (t[2] or 0) > 0]  # (V6.9.14) tenues en attente (identifiants à 0) : ignorées par le serveur
IMAGE = {}
for i, (nom, s, p_) in enumerate(TENUES):
    IMAGE[s] = ("Shirt", "rbxassetid://%d" % (70000000 + i)); IMAGE[p_] = ("Pants", "rbxassetid://%d" % (80000000 + i))
APPELS, PANNES, ECHECS, NON_VETEMENT = {}, {}, set(), set()
def charger_objet(_s, id_):
    id_ = int(id_); APPELS[id_] = APPELS.get(id_, 0) + 1
    if id_ in ECHECS: raise LuaError("HTTP 403 (Forbidden) : InsertService refusé (simulé)")
    if PANNES.get(id_, 0) > 0:
        PANNES[id_] -= 1; raise LuaError("HTTP 500 : service indisponible (simulé)")
    m = Instance("Model", "Model")
    if id_ in NON_VETEMENT:
        Instance("Part", "Objet", m); return m
    genre, image = IMAGE[id_]
    v = Instance(genre, genre, m); v.props["ShirtTemplate" if genre == "Shirt" else "PantsTemplate"] = image
    return m
ins = Instance("InsertService", "InsertService", game); ins.extra["LoadAsset"] = Fonction("LoadAsset", py=charger_objet)
s1 = TENUES[0][1]
PANNES[s1] = 2  # échoue deux fois, puis répond
roblox.SORTIE.clear(); roblox.ERREURS.clear()
tache(lambda: R.update(T=premier(appeler(G["require"], [mt]))))
T = R["T"]
tache(lambda: appeler(T.get("demarrer"), [])); H.avancer(30)
dossierT = rs.m_FindFirstChild("TardisAssets").m_FindFirstChild("Tenues")
attrs = dossierT.attrs if dossierT else {}
verifier("5. Au démarrage, chaque vêtement de Config.Tenues est résolu en VRAIE image (LoadAsset → Shirt/Pants → ShirtTemplate/PantsTemplate)",
         dossierT is not None and all(attrs.get("Shirt_%d" % s) == IMAGE[s][1] and attrs.get("Pants_%d" % p_) == IMAGE[p_][1] for _, s, p_ in TENUES), dict(list(attrs.items())[:4]))
verifier("5. … publiées pour l'aperçu (ReplicatedStorage › TardisAssets › Tenues, attributs « Shirt_<id> » / « Pants_<id> »)", len(attrs) == 2 * len(TENUES), len(attrs))
verifier("5. Le service a échoué deux fois : 3 essais, puis résolu (pcall + 2 nouveaux essais)", APPELS.get(s1) == 3 and attrs.get("Shirt_%d" % s1) == IMAGE[s1][1], APPELS.get(s1))
verifier("5. Tout est résolu : AUCUNE ligne « Tenues » dans l'Output", not [l for l in roblox.SORTIE if "Tenues" in l], [l for l in roblox.SORTIE if "Tenues" in l])
avant = dict(APPELS)
tache(lambda: R.update(img=premier(appeler(T.get("image"), ["Shirt", s1])), img2=premier(appeler(T.get("image"), ["Pants", "rbxassetid://%d" % TENUES[0][2]]))))
verifier("5. Cache : une deuxième demande (même « rbxassetid://… » en texte) ne recharge rien", R["img"] == IMAGE[s1][1] and R["img2"] == IMAGE[TENUES[0][2]][1] and APPELS == avant)
# Le personnage du pilote : chemise et pantalon d'origine, un chapeau, une tête
def personnage_de(joueur, nom="Perso"):
    perso = Instance("Model", nom, ws); hum = Instance("Humanoid", "Humanoid", perso)
    piece("Head", perso, (0, 4.5, 0), (2, 1, 1)); piece("HumanoidRootPart", perso, (0, 3, 0), (2, 2, 1))
    sh = Instance("Shirt", "Shirt", perso); sh.props["ShirtTemplate"] = "rbxassetid://1111"
    pa_ = Instance("Pants", "Pants", perso); pa_.props["PantsTemplate"] = "rbxassetid://2222"
    Instance("Accessory", "Chapeau", perso)
    joueur.props["Character"] = perso
    return perso, hum
perso, hum = personnage_de(pilote)
DESC = {"applique": 0, "mode": "ok"}
IMAGES_DESC = {}
def description(_s):
    d = Instance("HumanoidDescription", "Description"); d.props.update({"Shirt": 1, "Pants": 2, "HatAccessory": "999"}); return d
def appliquer_desc(_s, d):
    DESC["applique"] += 1
    if DESC["mode"] == "erreur": raise LuaError("ApplyDescription : échec (simulé)")
    for classe, prop, champ_ in (("Shirt", "ShirtTemplate", "Shirt"), ("Pants", "PantsTemplate", "Pants")):
        vieux = _s.parent.m_FindFirstChildOfClass(classe)
        if vieux: vieux.set_parent(None)
        image = IMAGES_DESC.get(d.props.get(champ_))
        if DESC["mode"] == "ok" and image:
            nv = Instance(classe, classe, _s.parent); nv.props[prop] = image
    return []
def equiper(h):
    h.extra["GetAppliedDescription"] = Fonction("GetAppliedDescription", py=description)
    h.extra["ApplyDescription"] = Fonction("ApplyDescription", py=appliquer_desc)
equiper(hum)
# Le vrai code de TardisExtras : appliquerTenue (Tenues.appliquer) et le gestionnaire (action « Tenue »)
d_t = extras.index('local Tenues = require(script.Parent:WaitForChild("TardisTenues"))')
f_t = extras.index("Players.PlayerRemoving:Connect(function(joueur) tenuesEnCours[joueur] = nil end)")
canalT = Instance("RemoteEvent", "TardisCommande_TARDIS_1", Instance("Folder", "RSTenues"))
xt = Instance("Model", "Cabine"); xt.attrs.update({"Etat": "Pose"})
DEDANS_T = Table()
code_t = prelude_x + extras[d_t:f_t] + "\n" + extras[dx:fx] + "\nreturn appliquerTenue\n"
roblox.ERREURS.clear()
tache(lambda: R.update(AT=premier(I.executer(code_t, "tenues-serveur", (canalT, xt, salleX, Config, PIL, Table(), DEDANS_T)))))
H.avancer(0.1)
verifier("5. Vrai appliquerTenue et vrai gestionnaire de TardisExtras chargés (avec TardisTenues)", R.get("AT") is not None and not roblox.ERREURS, roblox.ERREURS[:3])
envT = lambda: canalT.extra.get("envoisClient", [])
def tenue_par_action(qui, index):
    canalT.__lua_index__("OnServerEvent").declencher(qui, "Tenue", Table({"index": index})); H.avancer(5)
tenue_par_action(pilote, 1)
verifier("5. Action « Tenue » hors du TARDIS : refusée (rien ne change)", perso.m_FindFirstChildOfClass("Shirt").props["ShirtTemplate"] == "rbxassetid://1111" and not envT())
DEDANS_T.set(pilote, True)
tenue_par_action(pilote, 1)
sh, pn = perso.m_FindFirstChildOfClass("Shirt"), perso.m_FindFirstChildOfClass("Pants")
verifier("5. À bord : la tenue est mise par le serveur avec les VRAIES images (plus « rbxassetid://<id du catalogue> »)",
         sh.props["ShirtTemplate"] == IMAGE[TENUES[0][1]][1] and pn.props["PantsTemplate"] == IMAGE[TENUES[0][2]][1]
         and sh.props["ShirtTemplate"] != "rbxassetid://%d" % TENUES[0][1], (sh.props["ShirtTemplate"], pn.props["PantsTemplate"]))
verifier("5. Accessoires, tête et corps gardés (rien d'autre ne change ; pas d'HumanoidDescription quand l'image est connue)",
         perso.m_FindFirstChild("Chapeau") is not None and perso.m_FindFirstChild("Head") is not None and DESC["applique"] == 0 and perso.attrs.get("TardisTenue") == 1)
verifier("5. Le joueur reçoit « __tenue » réussi (pour son aperçu)", envT()[-1] == [pilote, "__tenue", True, 1], envT()[-1:])
# Une tenue introuvable : identifiants refusés par InsertService ET par HumanoidDescription (qui retire les vêtements)
mauvaise = Table({"nom": "Fantôme", "description": "?", "pieces": 2, "shirt": 424242, "pant": 434343, "categorie": "Test"})
ECHECS.update({424242, 434343})
Config.get("Tenues").set(Config.get("Tenues").longueur() + 1, mauvaise); idx_m = Config.get("Tenues").longueur()
DESC["mode"] = "vide"
avantT = (sh.props["ShirtTemplate"], pn.props["PantsTemplate"])
tenue_par_action(pilote, idx_m)
sh2, pn2 = perso.m_FindFirstChildOfClass("Shirt"), perso.m_FindFirstChildOfClass("Pants")
verifier("5. Tenue introuvable (catalogue refusé, HumanoidDescription sans vêtements) : le joueur garde EXACTEMENT ses vêtements",
         sh2 is not None and pn2 is not None and (sh2.props["ShirtTemplate"], pn2.props["PantsTemplate"]) == avantT and DESC["applique"] == 1, (sh2 and sh2.props, pn2 and pn2.props))
verifier("5. … un court message (« indisponible : tu gardes tes vêtements ») et « __tenue » refusé", envT()[-2][1] == "__console" and "indisponible" in envT()[-2][2]
         and "gardes tes vêtements" in envT()[-2][2] and envT()[-1] == [pilote, "__tenue", False, idx_m], envT()[-2:])
verifier("5. … la tenue d'avant reste notée (attribut TardisTenue inchangé)", perso.attrs.get("TardisTenue") == 1)
DESC["mode"] = "erreur"; tenue_par_action(pilote, idx_m)
verifier("5. HumanoidDescription en erreur : vêtements gardés aussi", (perso.m_FindFirstChildOfClass("Shirt").props["ShirtTemplate"], perso.m_FindFirstChildOfClass("Pants").props["PantsTemplate"]) == avantT)
# Dernier recours qui marche : InsertService refuse, mais HumanoidDescription (identifiants du catalogue) habille
secours = Table({"nom": "Secours", "description": "?", "pieces": 2, "shirt": 515151, "pant": 525252, "categorie": "Test"})
ECHECS.update({515151, 525252}); IMAGES_DESC.update({515151: "rbxassetid://61", 525252: "rbxassetid://62"})
Config.get("Tenues").set(Config.get("Tenues").longueur() + 1, secours); idx_s = Config.get("Tenues").longueur()
DESC["mode"] = "ok"; tenue_par_action(pilote, idx_s)
verifier("5. Dernier recours : HumanoidDescription avec les identifiants du catalogue, depuis l'apparence actuelle (accessoires gardés)",
         perso.m_FindFirstChildOfClass("Shirt").props["ShirtTemplate"] == "rbxassetid://61" and perso.m_FindFirstChildOfClass("Pants").props["PantsTemplate"] == "rbxassetid://62"
         and perso.m_FindFirstChild("Chapeau") is not None and envT()[-1] == [pilote, "__tenue", True, idx_s], envT()[-1:])
verifier("5. … et l'image obtenue est publiée pour l'aperçu", dossierT.attrs.get("Shirt_515151") == "rbxassetid://61" and dossierT.attrs.get("Pants_525252") == "rbxassetid://62")
verifier("5. Aucune erreur (tenues, serveur)", not roblox.ERREURS, roblox.ERREURS[:3])
# Une ligne dans l'Output, seulement s'il y a des échecs, qui les liste ; un objet sans vêtement : l'identifiant pris comme image
vider_cache(); roblox.SORTIE.clear()
I2, G2, game2, joueur2 = monde(serveur=True)
activer_maths(G2)
rs2 = game2.m_FindFirstChild("ReplicatedStorage")
tache(lambda: R.update(C2=premier(appeler(G2["require"], [rs2.m_FindFirstChild("TardisConfig")]))))
C2 = R["C2"]
C2.set("Tenues", Table({1: Table({"nom": "Bonne", "shirt": TENUES[1][1], "pant": TENUES[1][2]}), 2: Table({"nom": "Perdue", "shirt": 999001, "pant": TENUES[2][2]}),
                        3: Table({"nom": "Image", "shirt": 999002, "pant": 999003})}))
ECHECS.add(999001); NON_VETEMENT.update({999002, 999003})
ins2 = Instance("InsertService", "InsertService", game2); ins2.extra["LoadAsset"] = Fonction("LoadAsset", py=charger_objet)
mt2 = Instance("ModuleScript", "TardisTenues", game2.m_FindFirstChild("ServerScriptService")); mt2.extra["chemin"] = DEPOT + "/ServerScriptService/TardisTenues.lua"
tache(lambda: R.update(T2=premier(appeler(G2["require"], [mt2]))))
APPELS.clear()
tache(lambda: appeler(R["T2"].get("demarrer"), [])); tache(lambda: appeler(R["T2"].get("demarrer"), [])); H.avancer(30)
lt = [l for l in roblox.SORTIE if "Tenues" in l]
verifier("5. Un identifiant introuvable : UNE ligne dans l'Output (même si demarrer est appelé deux fois), qui le liste", len(lt) == 1 and "Perdue (haut 999001)" in lt[0] and "Bonne" not in lt[0] and "Image" not in lt[0], lt)
verifier("5. … 3 essais pour lui, un seul pour les autres", APPELS.get(999001) == 3 and APPELS.get(TENUES[1][1]) == 1, APPELS)
at2 = rs2.m_FindFirstChild("TardisAssets").m_FindFirstChild("Tenues").attrs
verifier("5. Objet chargé sans Shirt ni Pants : l'identifiant est essayé tel quel comme image ; introuvable publié vide",
         at2.get("Shirt_999002") == "rbxassetid://999002" and at2.get("Pants_999003") == "rbxassetid://999003" and at2.get("Shirt_999001") == "", dict(at2))
IMAGES_PUBLIEES = dict(dossierT.attrs)  # repris par l'aperçu (6)


# ================================================================== 7. Régénération : vrai TardisSystemes (habillerTenueJeu)
roblox.ERREURS.clear()
d_r = systemes.index('local Tenues = require(script.Parent:WaitForChild("TardisTenues"))'); f_r = systemes.index("-- Applique l'avatar puis vérifie")
code_r = "local Config = ...\n" + systemes[d_r:f_r] + "\nreturn habillerTenueJeu\n"
C2.set("Tenues", Table({1: Table({"nom": "Bonne", "shirt": TENUES[1][1], "pant": TENUES[1][2]})}))
tache(lambda: R.update(HT=premier(I2.executer(code_r, "regeneration", (C2,)))))
regen, hr = personnage_de(joueur2, "Regenere")
regen.set_parent(game2.m_FindFirstChild("Workspace"))
tache(lambda: R.update(ok=premier(appeler(R["HT"], [regen])))); H.avancer(4)
verifier("7. Régénération sans avatar : la tenue du jeu est mise avec les vraies images (même résolution que les casiers)",
         R.get("ok") is True and regen.m_FindFirstChildOfClass("Shirt").props["ShirtTemplate"] == IMAGE[TENUES[1][1]][1]
         and regen.m_FindFirstChildOfClass("Pants").props["PantsTemplate"] == IMAGE[TENUES[1][2]][1] and regen.m_FindFirstChild("Chapeau") is not None,
         (R.get("ok"), regen.m_FindFirstChildOfClass("Shirt").props))
equiper(hr); DESC["mode"] = "erreur"
C2.set("Tenues", Table({1: Table({"nom": "Perdue", "shirt": 999001, "pant": 999001})}))
avantR = regen.m_FindFirstChildOfClass("Shirt").props["ShirtTemplate"]
tache(lambda: R.update(ok=premier(appeler(R["HT"], [regen])))); H.avancer(4)
verifier("7. Tenue du jeu introuvable : vêtements gardés, la fonction le dit (pour la ligne de l'Output)", R.get("ok") is False
         and regen.m_FindFirstChildOfClass("Shirt").props["ShirtTemplate"] == avantR, (R.get("ok"), regen.m_FindFirstChildOfClass("Shirt").props))
verifier("7. Plus aucun « rbxassetid:// » .. identifiant du catalogue dans le code des tenues (serveur et client)",
         not any('"rbxassetid://" .. tenue.' in src for src in (extras, systemes, interactions_src)))
verifier("7. Aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])


# ================================================================== 4 et 6. Client : casier en Model, caméra, aperçu (vrai Interactions)
vider_cache(); roblox.ERREURS.clear()
Ic, Gc, gamec, moi = monde(serveur=False)
activer_maths(Gc)
rsc = gamec.m_FindFirstChild("ReplicatedStorage"); wsc = gamec.m_FindFirstChild("Workspace")
tache(lambda: R.update(Cc=premier(appeler(Gc["require"], [rsc.m_FindFirstChild("TardisConfig")])), UIc=premier(appeler(Gc["require"], [rsc.m_FindFirstChild("TardisUI")]))))
Cc, UIc = R["Cc"], R["UIc"]
moi.props.update({"UserId": 101, "DisplayName": "Pilote"})
pg = Instance("PlayerGui", "PlayerGui", moi)
uis = gamec.m_FindFirstChild("UserInputService"); uis.extra["InputBegan"] = Signal("InputBegan")
remoteC = Instance("RemoteEvent", "TardisCommande_TARDIS_1", rsc)
# Les images publiées par le serveur (5), comme si elles étaient arrivées chez le joueur
tdc = Instance("Folder", "Tenues", Instance("Folder", "TardisAssets", rsc)); tdc.attrs.update(IMAGES_PUBLIEES)
# Rayons : boîtes alignées sur les axes ; RaycastParams garde ses réglages
Gc["RaycastParams"] = Table({"new": Fonction("RaycastParams.new", py=lambda: Instance("RaycastParams", "RaycastParams"))})
PARAMS = []
def rayon(_w, origine, direction, params=None):
    o, d = en_vec3(origine).t(), en_vec3(direction).t()
    PARAMS.append(params)
    exclus = []
    if isinstance(params, Instance):
        f = params.props.get("FilterDescendantsInstances")
        if isinstance(f, Table): exclus = [v for v in f.h.values()]
    meilleur = None
    for part in descendants(wsc):
        if not part.m_IsA("BasePart") or part.props.get("CanQuery") is False: continue
        if any(part is e or part.m_IsDescendantOf(e) for e in exclus): continue
        mn_, mx_ = boite_monde([part])
        t0, t1 = 0.0, 1.0
        for i in range(3):
            if abs(d[i]) < 1e-12:
                if o[i] < mn_[i] or o[i] > mx_[i]: t0, t1 = 1, 0; break
            else:
                a, b = (mn_[i] - o[i]) / d[i], (mx_[i] - o[i]) / d[i]
                t0, t1 = max(t0, min(a, b)), min(t1, max(a, b))
        if t0 <= t1 and (meilleur is None or t0 < meilleur[0]): meilleur = (t0, part)
    if not meilleur: return None
    L = math.sqrt(sum(x * x for x in d)); t, part = meilleur
    return Table({"Distance": t * L, "Position": Vec3(*(o[i] + d[i] * t for i in range(3))), "Instance": part})
wsc.extra["Raycast"] = Fonction("Raycast", py=rayon)
salleC = Instance("Model", "Salle", wsc)
consC = Instance("Model", "Console", salleC)
casierM = Instance("Model", "Casier", consC)
porte = piece("Porte", casierM, (0, 3, -1.5), (2, 3, 0.2)); corps = piece("Corps", casierM, (0, 2.5, -2), (2, 4, 0.8))
camera = Instance("Camera", "Camera", wsc)
perso, hum = personnage_de(moi, "Moi"); perso.set_parent(wsc)
racine_ = perso.m_FindFirstChild("HumanoidRootPart")
CAM0 = CF((0, 10, 14))
camera.props.update({"CFrame": CAM0, "CameraType": Valeur("Enum.CameraType.Custom"), "CameraSubject": hum})
ctx = Table({"C": UIc.get("C"), "Config": Cc, "UI": UIc, "UserInputService": uis, "creer": UIc.get("creer"), "texte": UIc.get("texte"), "animer": UIc.get("animer"),
             "def": Cc.get("Tardis").get(1), "exterieur": Instance("Model", "Cabine"), "interieur": salleC, "joueur": moi,
             "maRacine": Fonction("maRacine", py=lambda: (moi.props.get("Character").m_FindFirstChild("HumanoidRootPart") if moi.props.get("Character") else None)),
             "remote": remoteC, "camera": camera, "jeSuisDedans": Fonction("dedans", py=lambda: True)})
res = {}
tache(lambda: res.update(m=premier(appeler(premier(Ic.executer(interactions_src, "Interactions")), [ctx]))))
H.avancer(0.1)
verifier("4. Vrai module Interactions chargé (client, maths réelles, rayons)", res.get("m") is not None and not roblox.ERREURS, roblox.ERREURS[:3])
pcas = de_classe(casierM, "ProximityPrompt"); ccas = enfant_classe(casierM, "ClickDetector")
verifier("4. Casier en Model : clic sur tout le Model, invite « Choisir une tenue » (Z) sur une de ses pièces (V6.9.10.8)",
         len(ccas) == 1 and len(pcas) == 1 and pcas[0].parent.ClassName != "Attachment" and pcas[0].parent.m_IsDescendantOf(casierM) and pcas[0].props["ActionText"] == "Choisir une tenue",
         ([e.ClassName for e in casierM.enfants], pcas and pcas[0].parent.ClassName))
casierGui = pg.m_FindFirstChild("TardisCasier")
# Les murs (la console et le casier sont devant le joueur, qui regarde vers −Z)
murs = []
def mur(nom, centre, taille, **props):
    p = piece(nom, salleC, centre, taille); p.props.update(props); murs.append(p); return p
def vider_murs():
    for m in murs: m.set_parent(None)
    murs.clear()
for m in (porte, corps): m.set_parent(None)  # (le casier lui-même ne gêne pas les rayons ici)
echap = lambda: (uis.extra["InputBegan"].declencher(Table({"KeyCode": Valeur("Enum.KeyCode.Escape")}), False), H.avancer(0.01))
ouvrir = lambda: (declencher(pcas[0], "Triggered"), H.avancer(0.01))
cam_type = lambda: camera.props["CameraType"].nom
def dans_un_mur(p):
    for m in murs:
        mn_, mx_ = boite_monde([m])
        if all(mn_[i] < p[i] < mx_[i] for i in range(3)): return m.Name
    return None
tete = perso.m_FindFirstChild("Head").props["CFrame"].p
# A. Mur épais juste devant (la place d'avant, 7 studs devant, est DANS le mur), ouverture à droite, mur de côté à x = 4
mur("MurFace", (-9.75, 5, -5.1), (20.5, 10, 5.8))     # x de −20 à 0,5 ; z de −8 à −2,2
mur("MurDroit", (4.5, 5, -10), (1, 10, 20))           # x de 4 à 5
ancienne = (racine_.props["CFrame"].p[0], racine_.props["CFrame"].p[1] + 1.5, racine_.props["CFrame"].p[2] - 7)
verifier("4. Cause : la place d'avant (7 studs devant le joueur, sans vérification) est DANS le mur", dans_un_mur(ancienne) == "MurFace", ancienne)
ouvrir()
cp = camera.props["CFrame"].p
verifier("4. Mur devant : la caméra va devant à droite, la place la plus dégagée (5,16 studs, arrêtée 0,5 stud avant le mur de côté)",
         cam_type() == "Enum.CameraType.Scriptable" and proche(cp, (5.157 / math.sqrt(2), 4.5, -5.157 / math.sqrt(2)), 2e-3) and dans_un_mur(cp) is None, (cam_type(), cp))
prm = PARAMS[-1]  # réglages des rayons du module (avant le rayon de contrôle ci-dessous)
sans_perso = Instance("RaycastParams", "RaycastParams"); sans_perso.props["FilterDescendantsInstances"] = Table({1: perso})
touche_seg = rayon(None, Vec3(*tete), Vec3(*(cp[i] - tete[i] for i in range(3))), sans_perso)
verifier("4. … rien entre la tête et la caméra (vue dégagée), et elle regarde le joueur", touche_seg is None and camera.props["CFrame"].__lua_index__("LookVector").dot(Vec3(*(racine_.props["CFrame"].p[i] + (0, 0.5, 0)[i] - cp[i] for i in range(3))).unite()) > 0.999)
filtre = [v for v in prm.props["FilterDescendantsInstances"].h.values()]
verifier("4. Rayons : le personnage est ignoré (filtre Exclude)", perso in filtre and prm.props["FilterType"].nom == "Enum.RaycastFilterType.Exclude")
echap()
verifier("4. Échap : caméra rendue EXACTEMENT (même position, type Custom, sujet = le Humanoid)", camera.props["CFrame"] is CAM0 and cam_type() == "Enum.CameraType.Custom"
         and camera.props["CameraSubject"] is hum and casierGui.props.get("Enabled") is False, (camera.props["CFrame"].p, cam_type()))
# B. Tout est bouché (petite cabine autour du joueur) : la caméra ne bouge pas
vider_murs()
mur("Fond", (0, 5, -2), (6, 10, 1)); mur("Gauche", (-2, 5, 0), (1, 10, 6)); mur("Droite", (2, 5, 0), (1, 10, 6)); mur("Plafond", (0, 6.5, 0), (6, 1, 6))
ouvrir()
verifier("4. Tout est bouché : la caméra ne bouge pas (ni type ni position), le menu s'ouvre quand même",
         camera.props["CFrame"] is CAM0 and cam_type() == "Enum.CameraType.Custom" and casierGui.props.get("Enabled") is True, (camera.props["CFrame"].p, cam_type()))
appuyer = lambda b: (b.extra.setdefault("Activated", Signal("Activated")).declencher(), H.avancer(0.01))
bfermer = [e for e in descendants(casierGui) if e.ClassName == "TextButton" and texte_de(e) == "FERMER"][0]  # (V6.9.10.7 : bouton de la charte, en majuscules)
appuyer(bfermer)
verifier("4. … « Fermer » : rien à rendre, caméra intacte", camera.props["CFrame"] is CAM0 and casierGui.props.get("Enabled") is False)
# C. Pièce invisible (portail), pièce sans requête, objet du personnage juste devant : ignorés ; place devant à 7 studs
vider_murs()
mur("Portail", (0, 4.5, -2.5), (4, 6, 1), Transparency=1)
mur("ZoneClic", (0, 4.5, -4), (4, 6, 0.5), CanQuery=False)
chap = piece("Visiere", perso, (0, 4.5, -0.9), (1, 0.3, 0.4))
ouvrir()
cp = camera.props["CFrame"].p
filtre = [v for v in PARAMS[-1].props["FilterDescendantsInstances"].h.values()]
verifier("4. Portail invisible, zone sans requête et objet du personnage ignorés : caméra devant, à 7 studs", proche(cp, (0, 4.5, -7), 1e-6) and murs[0] in filtre and murs[1] in filtre, (cp, [e.Name for e in filtre]))
appuyer(bfermer)
verifier("4. « Fermer » : caméra rendue exactement", camera.props["CFrame"] is CAM0 and cam_type() == "Enum.CameraType.Custom" and camera.props["CameraSubject"] is hum)
chap.set_parent(None); vider_murs()
# Fermeture en s'éloignant, à la mort, à la réapparition
ouvrir(); racine_.props["Position"] = Vec3(0, 3, 20); H.avancer(0.6)
verifier("4. En s'éloignant (plus de 12 studs) : menu fermé, caméra rendue", casierGui.props.get("Enabled") is False and camera.props["CFrame"] is CAM0 and cam_type() == "Enum.CameraType.Custom")
racine_.props["Position"] = Vec3(0, 3, 0); ouvrir(); H.avancer(0.6)
verifier("4. Sans bouger : reste ouvert", casierGui.props.get("Enabled") is True and cam_type() == "Enum.CameraType.Scriptable")
hum.__lua_index__("Died").declencher(); H.avancer(0.01)
verifier("4. Mort : menu fermé, caméra rendue", casierGui.props.get("Enabled") is False and camera.props["CFrame"] is CAM0 and cam_type() == "Enum.CameraType.Custom")
ouvrir()
perso.set_parent(None)
perso2, hum2 = personnage_de(moi, "Moi2"); perso2.set_parent(wsc); equiper(hum2)
moi.__lua_index__("CharacterAdded").declencher(perso2); H.avancer(0.01)
verifier("4. Réapparition : menu fermé, caméra rendue (type, position), sujet = le NOUVEAU Humanoid", casierGui.props.get("Enabled") is False and camera.props["CFrame"] is CAM0
         and cam_type() == "Enum.CameraType.Custom" and camera.props["CameraSubject"] is hum2, camera.props.get("CameraSubject"))
perso, hum = perso2, hum2; racine_ = perso.m_FindFirstChild("HumanoidRootPart"); camera.props["CameraSubject"] = hum
# 6. Aperçu chez le joueur
def bouton_tenue(nom):
    # (V6.9.10.7 : tuiles de la charte, le nom en majuscules)
    for b in descendants(casierGui):
        if b.ClassName == "TextButton" and any(e.ClassName == "TextLabel" and texte_de(e) == nom.upper() for e in b.enfants): return b
aide_ = lambda: [e for e in descendants(casierGui) if e.ClassName == "TextLabel" and ("Clique pour essayer" in texte_de(e) or "Aperçu" in texte_de(e) or "chargement" in texte_de(e))][0]
habits = lambda: (perso.m_FindFirstChildOfClass("Shirt").props["ShirtTemplate"], perso.m_FindFirstChildOfClass("Pants").props["PantsTemplate"])
ouvrir()
appuyer(bouton_tenue(TENUES[0][0]))
verifier("6. Aperçu : les images données par le serveur (jamais l'identifiant du catalogue)", habits() == (IMAGE[TENUES[0][1]][1], IMAGE[TENUES[0][2]][1]), habits())
tdc.attrs["Shirt_%d" % TENUES[3][1]] = ""  # le serveur n'a pas trouvé ce vêtement
appuyer(bouton_tenue(TENUES[3][0]))
verifier("6. Vêtement introuvable : le joueur garde SES vêtements, court message", habits() == ("rbxassetid://1111", "rbxassetid://2222") and "Aperçu indisponible" in texte_de(aide_()),
         (habits(), texte_de(aide_())))
del tdc.attrs["Pants_%d" % TENUES[4][2]]  # pas encore publié
appuyer(bouton_tenue(TENUES[4][0]))
verifier("6. Images pas encore prêtes : vêtements gardés, « en cours de chargement »", habits() == ("rbxassetid://1111", "rbxassetid://2222") and "chargement" in texte_de(aide_()), texte_de(aide_()))
H.avancer(3.1)
verifier("6. Le message laisse ensuite la place à l'aide", "Clique pour essayer" in texte_de(aide_()))
appuyer(bouton_tenue(TENUES[1][0]))
bgarder = [e for e in descendants(casierGui) if e.ClassName == "TextButton" and texte_de(e) == "ENFILER"][0]  # (V6.9.10.7 : « Garder cette tenue » devient ENFILER)
n = len(remoteC.extra.get("envois", []))
appuyer(bgarder)
env_ = remoteC.extra.get("envois", [])[n:]
verifier("6. « Enfiler » (avant : « Garder cette tenue ») : demandée au serveur (action Tenue), le serveur décide", [(e[0], dict(e[1].h)) for e in env_] == [("Tenue", {"index": 2})] and habits()[0] == IMAGE[TENUES[1][1]][1], env_)
remoteC.__lua_index__("OnClientEvent").declencher("__tenue", False, 2); H.avancer(0.01)
verifier("6. Le serveur refuse (« __tenue » faux) : l'aperçu est retiré, vêtements d'avant", habits() == ("rbxassetid://1111", "rbxassetid://2222"), habits())
ouvrir(); appuyer(bouton_tenue(TENUES[2][0])); appuyer(bgarder)
remoteC.__lua_index__("OnClientEvent").declencher("__tenue", True, 3); H.avancer(0.01)
verifier("6. Le serveur accepte : la tenue reste (le serveur l'a mise, elle arrive par la réplication)", habits() == (IMAGE[TENUES[2][1]][1], IMAGE[TENUES[2][2]][1]), habits())
verifier("6. Aucune erreur (client)", not roblox.ERREURS, roblox.ERREURS[:3])


# ================================================================== 8. Jukebox : dossier, tri, mêmes numéros, serveur strict, panneau, lecture
def remplir_dossier(dossier):
    def son(nom, sid, parent=dossier, categorie=None, volume=0.5):
        s = Instance("Sound", nom, parent); s.props.update({"SoundId": "rbxassetid://%d" % sid, "Volume": volume, "PlaybackSpeed": 1})
        if categorie: s.attrs["Categorie"] = categorie
        return s
    son("Vortex Drift", 5001, categorie="Vortex"); son("Main Theme", 5002, categorie="Thèmes", volume=0.8); son("Chase", 5003, categorie="Action")
    sous = Instance("Folder", "Ambiance de bord", dossier); son("Ambient Hum", 5004, parent=sous); son("Zeta", 5005)
    Instance("Folder", "Vide", dossier)
    s = Instance("Sound", "SansId", dossier); s.props.update({"SoundId": "", "Volume": 0.5})
ATTENDU = [("Main Theme", "Thèmes"), ("Ambient Hum", "Ambiance de bord"), ("Vortex Drift", "Vortex"), ("Alpha", "Action"), ("Chase", "Action"), ("Calme", None), ("Zeta", None)]
CONFIG_J = lambda: Table({1: Table({"nom": "Calme", "id": 333}), 2: Table({"nom": "Alpha", "id": 111, "categorie": "Action"})})
# Serveur (monde du 1 à 3)
remplir_dossier(dj)
Config.set("Jukebox", CONFIG_J())
tache(lambda: R.update(pj=premier(appeler(Config.get("pistesJukebox"), []))))
pistes = R["pj"]
liste_srv = [(pistes.get(i).get("nom"), pistes.get(i).get("categorie")) for i in range(1, pistes.longueur() + 1)]
verifier("8. Pistes : Config.Jukebox + Sound du dossier (attribut Categorie, ou sous-dossier), triées par catégorie (Thèmes, Ambiance de bord, Vortex, Action, Émotion, puis sans) puis par nom",
         liste_srv == ATTENDU, liste_srv)
verifier("8. Un Sound sans SoundId est ignoré ; une piste du dossier garde son Sound", all(n_ != "SansId" for n_, _ in liste_srv) and pistes.get(3).get("son") is dj.m_FindFirstChild("Vortex Drift"))
verifier("8. La liste est rangée DANS Config.Jukebox (la tablette lit les mêmes numéros)", Config.get("Jukebox") is pistes)
tache(lambda: R.update(pj2=premier(appeler(Config.get("pistesJukebox"), []))))
verifier("8. Recalculée : même liste, rien en double", [(R["pj2"].get(i).get("nom")) for i in range(1, R["pj2"].longueur() + 1)] == [a for a, _ in ATTENDU])
envX = lambda qui, d: (canalX.__lua_index__("OnServerEvent").declencher(qui, "Jukebox", d), H.avancer(0.6))
dits = lambda: [DITS.get(i).get(2) for i in range(1, DITS.longueur() + 1)]
i_chase = [a for a, _ in ATTENDU].index("Chase") + 1
envX(pilote, Table({"index": i_chase}))
verifier("8. Serveur (vrai TardisExtras) : piste du dossier acceptée (attribut Jukebox = son numéro)", xx.attrs.get("Jukebox") == i_chase and dits()[-1] == "Jukebox : Chase.", (xx.attrs.get("Jukebox"), dits()[-1:]))
for mauvais in (99, 0, 2.5, "3", float("nan"), True):
    envX(pilote, Table({"index": mauvais}))
verifier("8. Piste inconnue (99, 0, 2,5, texte, NaN, booléen) : refusée, la musique continue", xx.attrs.get("Jukebox") == i_chase and dits()[-1] == "Piste inconnue du jukebox.", (xx.attrs.get("Jukebox"), dits()[-2:]))
envX(pilote, Table({"liste": "Vortex"}))
verifier("8. Playlist d'une catégorie du dossier (Vortex) : acceptée", xx.attrs.get("Jukebox") == "Vortex")
envX(pilote, Table({"liste": "Inconnue"})); envX(pilote, Table({"liste": 12}))
verifier("8. Playlist inconnue (ou pas un texte) : refusée, la musique continue", xx.attrs.get("Jukebox") == "Vortex" and dits()[-1] == "Playlist inconnue du jukebox.", dits()[-2:])
envX(visiteur, Table({"index": 1}))
verifier("8. Non-pilote : refusé", xx.attrs.get("Jukebox") == "Vortex")
envX(pilote, Table({}))
verifier("8. « Arrêter la musique » : arrêtée", xx.attrs.get("Jukebox") is None and dits()[-1] == "Jukebox arrêté.")
verifier("8. Aucune erreur (serveur)", not roblox.ERREURS, roblox.ERREURS[:3])
# Client (monde du 4) : le même dossier arrivé par la réplication
djc = Instance("Folder", "Jukebox", rsc.m_FindFirstChild("TardisAssets")); remplir_dossier(djc)
Cc.set("Jukebox", CONFIG_J())
xc = Instance("Model", "Cabine"); xc.attrs.update({"Etat": "Pose", "Alimentation": True})
salleJ = Instance("Model", "Salle", wsc); cj_ = Instance("Model", "Console", salleJ); jbp = piece("JukeBox", cj_, (3, 3, 3), (1, 2, 1))
racineJ = piece("HumanoidRootPart", Instance("Model", "Corps"), (3, 3, 5), (2, 2, 1))
def contexte_console():
    return Table({"C": UIc.get("C"), "Config": Cc, "UI": UIc, "UserInputService": uis, "creer": UIc.get("creer"), "texte": UIc.get("texte"), "def": Cc.get("Tardis").get(1),
                  "exterieur": xc, "interieur": salleJ, "joueur": moi, "maRacine": Fonction("maRacine", py=lambda: racineJ), "remote": remoteC})
tache(lambda: res.update(cm=premier(appeler(premier(Ic.executer(lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Console.lua"), "Console")), [contexte_console()]))))
H.avancer(0.1)
verifier("8. Vrai module Console chargé (client)", res.get("cm") is not None and not roblox.ERREURS, roblox.ERREURS[:3])
jukeGui = pg.m_FindFirstChild("TardisJukeboxConsole")
remoteC.__lua_index__("OnClientEvent").declencher("__jukebox", jbp); H.avancer(0.01)
listeJ = trouve(jukeGui, "Liste")
pl = [texte_de(e) for e in listeJ.enfants if e.Name == "Playlist"]; pi_ = [e for e in listeJ.enfants if e.Name == "Piste"]
# (V6.9.10.7 : tableau N° | PISTE | DURÉE de la charte, noms en majuscules ; une ligne se choisit, JOUER la lance)
cellule = lambda l, k: texte_de(trouve(l, "Cellule_" + k))
pl = [cellule(e, "piste") for e in listeJ.enfants if e.Name == "Playlist"]
noms_client = [cellule(e, "piste") for e in pi_]
verifier("8. Panneau de la console : les pistes du dossier et de Config.Jukebox, dans le MÊME ordre que sur le serveur", noms_client == [a.upper() for a, _ in ATTENDU], noms_client)
verifier("8. … une playlist par catégorie, dans l'ordre des catégories", [p.split("PLAYLIST ")[1] for p in pl] == ["THÈMES", "AMBIANCE DE BORD", "VORTEX", "ACTION"], pl)
n = len(remoteC.extra.get("envois", []))
appuyer(pi_[noms_client.index("CHASE")]); appuyer(trouve(jukeGui, "Jouer"))
e_ = remoteC.extra["envois"][n:]
verifier("8. Clic sur « Chase » : le numéro envoyé est celui du serveur pour la même musique", [(x[0], dict(x[1].h)) for x in e_] == [("Jukebox", {"index": i_chase})], e_)
verifier("8. Config.Jukebox du joueur = la liste triée (la tablette affiche la même chose)", [Cc.get("Jukebox").get(i).get("nom") for i in range(1, 8)] == [a for a, _ in ATTENDU])
appuyer(trouve(jukeGui, "Fermer"))
# Lecture à bord (vrai Ambiance) : une piste du dossier joue une copie de son Sound
Lc = gamec.m_FindFirstChild("Lighting"); Lc.props.update({"ClockTime": 13.5, "ExposureCompensation": 0, "Ambient": Couleur(0.5, 0.5, 0.5), "OutdoorAmbient": Couleur(0.5, 0.5, 0.5)})
xc.props["Pivot"] = CF((12, 34, 56)); xc.props["PrimaryPart"] = Instance("Part", "Racine", xc)
Instance("Folder", "Sons", rsc.m_FindFirstChild("TardisAssets"))
RunService = gamec.m_FindFirstChild("RunService")
ctxA = contexte_console()
for k, v in {"Lighting": Lc, "Players": gamec.m_FindFirstChild("Players"), "ReplicatedStorage": rsc, "RunService": RunService, "E": Cc.get("Etats"), "boiteInt": CF((0, 1000, 0)),
             "dansInterieur": Fonction("dansInterieur", py=lambda p: True), "jeSuisDedans": Fonction("dedans", py=lambda: True),
             "partTemporaire": Fonction("pt", py=lambda *a: Instance("Part", "Temp", wsc))}.items(): ctxA.set(k, v)
tache(lambda: res.update(am=premier(appeler(premier(Ic.executer(lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Ambiance.lua"), "Ambiance")), [ctxA]))))
H.avancer(0.2)
verifier("8. Vrai module Ambiance chargé (client)", not roblox.ERREURS, roblox.ERREURS[:3])
def image(dt=0.1, n_=1):
    for _ in range(n_):
        H.avancer(dt)
        sig = RunService.extra.get("Heartbeat")
        if sig: sig.declencher(dt)
sons_ = gamec.m_FindFirstChild("SoundService")
xc.m_SetAttribute("Jukebox", 1); image(0.1, 30)
jouee = sons_.m_FindFirstChild("TardisJukebox")
verifier("8. À bord, piste 1 (« Main Theme », du dossier) : une copie de son Sound joue (même SoundId), en boucle, à son volume",
         jouee is not None and jouee.props.get("SoundId") == "rbxassetid://5002" and jouee.props.get("Looped") is True and 0 < jouee.props.get("Volume", 0) <= 0.8,
         jouee and {k: jouee.props.get(k) for k in ("SoundId", "Looped", "Volume")})
xc.m_SetAttribute("Jukebox", [a for a, _ in ATTENDU].index("Calme") + 1); image(0.1, 5)
jouee = sons_.m_FindFirstChild("TardisJukebox")
verifier("8. Piste de Config.Jukebox (« Calme ») : son identifiant, comme avant", jouee is not None and jouee.props.get("SoundId") == "rbxassetid://333", jouee and jouee.props.get("SoundId"))
xc.m_SetAttribute("Jukebox", "Action"); image(0.1, 5)
jouee = sons_.m_FindFirstChild("TardisJukebox")
verifier("8. Playlist « Action » : une de ses pistes (dossier ou Config.Jukebox)", jouee is not None and jouee.props.get("SoundId") in ("rbxassetid://5003", "rbxassetid://111"), jouee and jouee.props.get("SoundId"))
xc.m_SetAttribute("Jukebox", None); image(0.1, 2)
verifier("8. Aucune erreur (lecture)", not roblox.ERREURS, roblox.ERREURS[:3])
# Liste vide : le panneau explique comment la remplir
djc.set_parent(None); Cc.set("Jukebox", Table())
remoteC.__lua_index__("OnClientEvent").declencher("__jukebox", jbp); H.avancer(0.01)
vide = trouve(trouve(jukeGui, "Liste"), "Vide")
verifier("8. Liste vide : le panneau dit comment la remplir (Toolbox › Audio › Music, TardisAssets › Jukebox, Config.Jukebox)",
         vide is not None and all(m in texte_de(vide) for m in ("vide", "Toolbox", "Audio › Music", "ReplicatedStorage › TardisAssets › Jukebox", "Config.Jukebox")), texte_de(vide))
verifier("8. Aucune erreur (client)", not roblox.ERREURS, roblox.ERREURS[:3])

print("\n".join("  ✓ " + o for o in OK)); print("\n".join("  ✗ " + k for k in KO))
print(f"V6.9.10.5 : {len(OK)}/{len(OK) + len(KO)} vérifications réussies")
sys.exit(1 if KO else 0)
