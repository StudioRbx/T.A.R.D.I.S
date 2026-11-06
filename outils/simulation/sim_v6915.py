"""Simulations de la V6.9.15 : confort de l'interface et accessibilité (le vrai code).
  1. TardisUI : « réduire les effets » activé d'office sur téléphone (choix gardé à part de l'ordinateur), nouvelles
     options (sous-titres, ouverture sans animation, fermer en cliquant à côté), UI.suivreTaille (taille de l'interface).
  2. Le vrai menu rapide (TardisMenu) : ouverture sans animation, menu déplacé en glissant son en-tête (seuil, bornes
     de l'écran, position gardée dans les préférences, rétablie), menu fermé bien caché à grande taille, ligne d'aide.
  3. La vraie tablette (TardisTablette et ses 10 modules) : ouverture et fermeture sans animation, clic à côté (option),
     nouvelles lignes des réglages, « réduire les effets » sur téléphone, aide.
  4. Le vrai module SousTitres : démat / remat (avec le mode), Silencieux muet, portée, alarme et musique à bord seulement,
     option coupée, masqué après la durée.
  5. Taille de l'interface (proposition 72) : les menus qui ne la suivaient pas la suivent.
  6. Le code : repères (V6.9.15), chargement du module, version, rien de nouveau côté serveur."""
import os, sys, re, json, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from monde import *
import roblox
from roblox import Couleur, Vec3, CF, activer_maths, constructeur
OK, KO = [], []
def verifier(nom, condition, detail=""):
    (OK if condition else KO).append(nom + ("" if condition else "  →  " + str(detail)))
def tache(f): lancer(Fonction("t", py=f))
def lire(chemin): return open(os.path.join(DEPOT, chemin), encoding="utf-8").read()
def vider_cache(): roblox.charger_module.__defaults__[0].clear()
def version(v): return tuple(int(x) for x in str(v).split("."))
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
def appuyer(b): b.extra.setdefault("Activated", Signal("Activated")).declencher(); H.avancer(0.01)
def appel(f, *a): return premier(appeler(f, list(a)))
def envois_prefs(remote): return [json.loads(e[1]) for e in remote.extra.get("envois", []) if e[0] == "Prefs"]
def lua(I, UI, code, *args):
    """Exécute un bout de Luau avec UI ; renvoie la première valeur."""
    res = {}
    tache(lambda: res.update(f=premier(I.executer("return function(UI, A, B) " + code + " end", "essai"))))
    tache(lambda: res.update(v=appeler(res["f"], [UI] + list(args) + [None] * (2 - len(args)))))
    return res.get("v", [None])[0] if res.get("v") else None


# UDim2 calculable pour cette simulation : .X / .Y donnent un UDim dont on lit Scale et Offset (le simulateur de base
# rend 0 pour tout composant), afin de suivre les vraies positions du menu pendant un glissement.
class UD(Valeur):
    def __lua_index__(s, k):
        if k == "Scale": return s.args[0]
        if k == "Offset": return s.args[1]
        return super().__lua_index__(k)
class UD2(Valeur):
    def __lua_index__(s, k):
        if k in ("X", "Width"): return UD("UDim", s.args[0:2])
        if k in ("Y", "Height"): return UD("UDim", s.args[2:4])
        return super().__lua_index__(k)
def udim2_calculable(G):
    num = lambda x: x if isinstance(x, (int, float)) else 0
    t = constructeur("UDim2")
    t.h.update({"new": Fonction("UDim2.new", py=lambda xs=0, xo=0, ys=0, yo=0: UD2("UDim2", [num(xs), num(xo), num(ys), num(yo)])),
                "fromOffset": Fonction("UDim2.fromOffset", py=lambda x=0, y=0: UD2("UDim2", [0, num(x), 0, num(y)])),
                "fromScale": Fonction("UDim2.fromScale", py=lambda x=0, y=0: UD2("UDim2", [num(x), 0, num(y), 0]))})
    G["UDim2"] = t


def monde_client(prefs=None, tactile=False, clavier=None):
    """Un joueur (ordinateur, ou téléphone si tactile), avec le canal TardisCommande_TARDIS_1."""
    vider_cache(); roblox.ERREURS.clear()
    I, G, game, joueur = monde(serveur=False)
    activer_maths(G)
    udim2_calculable(G)
    rs = game.m_FindFirstChild("ReplicatedStorage")
    remote = Instance("RemoteEvent", "TardisCommande_TARDIS_1", rs)
    uis = game.m_FindFirstChild("UserInputService")
    uis.props.update({"TouchEnabled": tactile, "KeyboardEnabled": (not tactile) if clavier is None else clavier, "MouseEnabled": not tactile})
    if prefs is not None: joueur.attrs["TardisPrefs"] = json.dumps(prefs)
    R = {}
    tache(lambda: R.update(Config=appel(G["require"], rs.m_FindFirstChild("TardisConfig")), UI=appel(G["require"], rs.m_FindFirstChild("TardisUI"))))
    return I, G, game, joueur, rs, remote, R["Config"], R["UI"], uis


# ================================================================== 1. TardisUI
I, G, game, joueur, rs, remote, Config, UI, uis = monde_client()
verifier("1. TardisUI se charge chez un joueur, sans erreur", UI is not None and not roblox.ERREURS, roblox.ERREURS[:3])
verifier("1. Ordinateur : pas un téléphone, clé « effetsReduits », « réduire les effets » désactivé par défaut (comme avant)",
         appel(UI.get("estMobile")) is False and appel(UI.get("cleEffetsReduits")) == "effetsReduits" and appel(UI.get("effetsReduits")) is False)
verifier("1. Nouvelles options par défaut : ouverture animée, la tablette ne se ferme pas d'un clic à côté, sous-titres activés",
         appel(UI.get("ouvertureInstantanee")) is False and appel(UI.get("fermerDehors")) is False and appel(UI.get("sousTitres")) is True)
tache(lambda: [appel(UI.get("setPref"), k, v) for k, v in (("ouvertureRapide", True), ("fermerDehors", True), ("sousTitres", False))]); H.avancer(1)
verifier("1. … qui suivent les préférences « ouvertureRapide », « fermerDehors », « sousTitres » (envoyées par l'action EXISTANTE Prefs)",
         appel(UI.get("ouvertureInstantanee")) is True and appel(UI.get("fermerDehors")) is True and appel(UI.get("sousTitres")) is False
         and envois_prefs(remote) and {k: envois_prefs(remote)[-1].get(k) for k in ("ouvertureRapide", "fermerDehors", "sousTitres")}
         == {"ouvertureRapide": True, "fermerDehors": True, "sousTitres": False}, envois_prefs(remote)[-1:])
# Ordinateur : l'option se règle comme avant (clé effetsReduits)
tache(lambda: appel(UI.get("setEffetsReduits"), True)); H.avancer(1)
verifier("1. Ordinateur : UI.setEffetsReduits(true) règle la clé « effetsReduits » (celle d'avant)",
         appel(UI.get("effetsReduits")) is True and envois_prefs(remote)[-1].get("effetsReduits") is True and "effetsReduitsMobile" not in envois_prefs(remote)[-1])

# Téléphone : tactile sans clavier
I, G, game, joueur, rs, remote, Config, UI, uis = monde_client({"effetsReduits": False}, tactile=True)
verifier("1. Téléphone (tactile sans clavier) : reconnu, clé à part « effetsReduitsMobile »",
         appel(UI.get("estMobile")) is True and appel(UI.get("cleEffetsReduits")) == "effetsReduitsMobile")
verifier("1. Téléphone : « réduire les effets » activé d'office, même si l'ordinateur l'a désactivé (rien n'est envoyé pour autant)",
         appel(UI.get("effetsReduits")) is True and envois_prefs(remote) == [], envois_prefs(remote))
vus = lua(I, UI, "local vus = {} UI.prefsChangees.Event:Connect(function(c) table.insert(vus, c) end) UI.setEffetsReduits(false) return vus")
H.avancer(1)
p = envois_prefs(remote)
verifier("1. Téléphone : la couper la garde coupée sur ce téléphone (effetsReduitsMobile = false), le réglage de l'ordinateur ne bouge pas",
         appel(UI.get("effetsReduits")) is False and p and p[-1].get("effetsReduitsMobile") is False and p[-1].get("effetsReduits") is False, p[-1:])
verifier("1. … et les écouteurs sont prévenus sous le nom « effetsReduits » (menus, balayages, lueurs se mettent à jour)",
         vus is not None and "effetsReduits" in [vus.get(i) for i in range(1, 5)] and "effetsReduitsMobile" in [vus.get(i) for i in range(1, 5)],
         vus and [vus.get(i) for i in range(1, 5)])
I, G, game, joueur, rs, remote, Config, UI, uis = monde_client({"effetsReduitsMobile": False}, tactile=True)
verifier("1. Téléphone : le choix gardé (désactivé) est relu à la connexion suivante", appel(UI.get("effetsReduits")) is False)
I, G, game, joueur, rs, remote, Config, UI, uis = monde_client(tactile=True, clavier=True)
verifier("1. Tablette avec clavier, ordinateur tactile : pas un téléphone (rien d'activé d'office)",
         appel(UI.get("estMobile")) is False and appel(UI.get("effetsReduits")) is False)
# UI.suivreTaille
I, G, game, joueur, rs, remote, Config, UI, uis = monde_client()
ecran = Instance("ScreenGui", "Essai", Instance("PlayerGui", "PlayerGui", joueur))
cadre = Instance("Frame", "Cadre", ecran); dejaEchelle = Instance("Frame", "AvecEchelle", ecran); ancienne = Instance("UIScale", "UIScale", dejaEchelle)
autre = Instance("Frame", "AvecBase", ecran); fonc = Instance("Frame", "AvecFonction", ecran)
G["CADRE"], G["DEJA"], G["AUTRE"], G["FONC"] = cadre, dejaEchelle, autre, fonc
lua(I, UI, "UI.suivreTaille(CADRE) UI.suivreTaille(DEJA) UI.suivreTaille(AUTRE, 0.5) UI.suivreTaille(FONC, function() return 0.8 end)")
echelle = lambda o: [e.props.get("Scale") for e in enfants(o, classe="UIScale")]
verifier("1. UI.suivreTaille : un UIScale à 1 (taille 100 %), l'UIScale existant est repris (pas de second), base en nombre ou en fonction",
         echelle(cadre) == [1] and echelle(dejaEchelle) == [1] and echelle(autre) == [0.5] and echelle(fonc) == [0.8] and not roblox.ERREURS,
         (echelle(cadre), echelle(dejaEchelle), echelle(autre), echelle(fonc), roblox.ERREURS[:2]))
tache(lambda: appel(UI.get("setPref"), "taille", 1.2)); H.avancer(0.05)
proche = lambda a, b: a is not None and abs(a - b) < 1e-6
verifier("1. Taille 120 % dans les réglages : chacun suit (1,2 ; 1,2 ; 0,6 ; 0,96)",
         proche(echelle(cadre)[0], 1.2) and proche(echelle(dejaEchelle)[0], 1.2) and proche(echelle(autre)[0], 0.6) and proche(echelle(fonc)[0], 0.96),
         (echelle(cadre), echelle(autre), echelle(fonc)))
tache(lambda: appel(UI.get("setPref"), "taille", 3)); H.avancer(0.05)
verifier("1. Taille hors bornes (3) : ramenée à 140 %", proche(echelle(cadre)[0], 1.4), echelle(cadre))
cadre.parent = None; enfants_cadre = enfants(cadre, classe="UIScale")
enfants_cadre[0].parent = None
tache(lambda: appel(UI.get("setPref"), "taille", 1)); H.avancer(0.05)
verifier("1. UIScale détruit : le lien se coupe sans erreur (les autres suivent toujours)", not roblox.ERREURS and proche(echelle(autre)[0], 0.5), roblox.ERREURS[:2])


# ================================================================== Monde d'un pilote : le TARDIS, la caméra (comme la V6.9.10.6)
def monde_pilote(tactile=False, prefs=None):
    I, G, game, joueur, rs, remote, Config, UI, uis = monde_client(prefs, tactile=tactile)
    ws = game.m_FindFirstChild("Workspace")
    camera = Instance("Camera", "Camera", ws)
    camera.props.update({"CFrame": CF((0, 20, 40)), "ViewportSize": Valeur("Vector2", [1920, 1080])})
    ws.props["CurrentCamera"] = camera
    Instance("PlayerGui", "PlayerGui", joueur)
    joueur.attrs["TardisPilote_TARDIS_1"] = True
    cas = Instance("ContextActionService", "ContextActionService", game)
    liaisons = {}
    cas.extra["BindActionAtPriority"] = Fonction("BindActionAtPriority", py=lambda _s, nom, f, *a: liaisons.__setitem__(nom, (f, a)) or [])
    cas.extra["UnbindAction"] = Fonction("UnbindAction", py=lambda _s, nom: liaisons.pop(nom, None) and [] or [])
    tardis = Instance("Folder", "TARDIS", ws); t1 = Instance("Folder", "TARDIS_1", tardis)
    ext = Instance("Model", "Cabine", Instance("Folder", "EXTERIEURE", t1))
    ext.props.update({"Pivot": CF((0, 0, 0)), "PrimaryPart": Instance("Part", "Racine", ext)})
    ext.attrs.update({"Etat": "Pose", "Position": "Hall", "Alimentation": True, "PointsDeVie": 84, "BouclierEnergie": 72, "Alerte": False,
                      "ListeDestinations": "Hall\nParking", "Mode": "Normal"})
    salle = Instance("Model", "Salle", Instance("Folder", "INTERIEURE", t1))
    salle.props.update({"BoiteCFrame": CF((0, 1000, 0)), "BoiteTaille": Vec3(40, 20, 40)})
    for nom in ("Rotor", "Portail"):
        piece = Instance("Part", nom, salle); piece.props.update({"Position": Vec3(0, 1000, 0), "CFrame": CF((0, 1000, 0)), "Size": Vec3(2, 2, 2)})
    dest = Instance("Folder", "TARDIS_DESTINATIONS", ws)
    accorde = Instance("Folder", "ACCORDE", dest)
    for nom, pos in (("Hall", (140, 0, 0)), ("Parking", (0, 0, 455))):
        pc = Instance("Part", nom, accorde); pc.props.update({"Position": Vec3(*pos), "CFrame": CF(pos), "Size": Vec3(4, 1, 4)})
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
def touche_T(uis):
    uis.__lua_index__("InputBegan").declencher(Table({"KeyCode": Valeur("Enum.KeyCode.T")}), False); H.avancer(0.6)
def entree(type_, x=0, y=0): return Table({"UserInputType": Valeur("Enum.UserInputType." + type_), "Position": Valeur("Vector3", [x, y, 0])})


# ================================================================== 2. Le vrai menu rapide (TardisMenu)
I, G, game, joueur, rs, remote, Config, UI, ext, salle, uis, liaisons, camera = monde_pilote()
lancer_script(I, G, "StarterPlayer/StarterPlayerScripts/TardisMenu.client.lua")
menu = joueur.m_FindFirstChild("PlayerGui").m_FindFirstChild("TardisMenu")
tiroir = trouve(menu, "Tiroir")
balayage = next((e for e in tous(menu, "Balayage") if e.ClassName == "Frame"), None)
plaque = trouve(menu, "Plaque")
echelleTiroir = enfants(tiroir, classe="UIScale")[0] if tiroir else None
pos = lambda: list(tiroir.props["Position"].args)
verifier("2. Menu rapide construit, sans erreur ; fermé, caché à gauche (−394 px à 100 %, comme avant)",
         menu is not None and not roblox.ERREURS and pos()[:2] == [0, -394] and echelleTiroir.props["Scale"] == 1, (roblox.ERREURS[:3], pos()))
aideD = trouve(menu, "AideDeplacer")
verifier("2. Nouvelle ligne d'aide « Glisser l'en-tête : déplacer le menu » (après « Y tablette · E portes et console »)",
         aideD is not None and texte_de(aideD) == "Glisser l'en-tête : déplacer le menu" and aideD.props["LayoutOrder"] == 100)
verifier("2. L'en-tête (la plaque) capte la souris et le doigt (Active)", plaque.props.get("Active") is True)
# Ouverture animée (comme avant) : le balayage traverse le tiroir
touche_T(uis)
verifier("2. Sans l'option : ouverture animée comme avant (le tiroir glisse, le balayage traverse)",
         balayage.props["Visible"] is True and "TardisMenuNavigation" in liaisons)
touche_T(uis)
# Ouverture sans animation
tache(lambda: appel(UI.get("setPref"), "ouvertureRapide", True)); H.avancer(0.05)
touche_T(uis)
verifier("2. « Ouverture des menus sans animation » : T pose le tiroir d'un coup à sa place (0, 12, 0,55, 0), sans balayage",
         pos() == [0, 12, 0.55, 0] and balayage.props["Visible"] is False and "TardisMenuNavigation" in liaisons, (pos(), balayage.props["Visible"]))
# Glisser l'en-tête
n0 = len(envois_prefs(remote))
plaque.__lua_index__("InputBegan").declencher(entree("MouseButton1", 100, 100)); H.avancer(0.01)
uis.__lua_index__("InputChanged").declencher(entree("MouseMovement", 103, 101), False); H.avancer(0.01)
verifier("2. Glisser : en dessous de 6 px, rien ne bouge (un simple clic sur l'en-tête ne déplace pas le menu)", pos() == [0, 12, 0.55, 0], pos())
uis.__lua_index__("InputChanged").declencher(entree("MouseMovement", 400, 0), False); H.avancer(0.01)
gauche_attendu, centre_attendu = 12 + 300, round(0.55 * 1080) - 100
verifier("2. Glisser de 300 px à droite et 100 px vers le haut : le menu suit (bord gauche 312, centre 494)",
         pos() == [0, gauche_attendu, 0, centre_attendu], pos())
s = echelleTiroir.props["Scale"]; hauteur = tiroir.props["Size"].args[3] * s
uis.__lua_index__("InputChanged").declencher(entree("MouseMovement", 9000, 9000), False); H.avancer(0.01)
verifier("2. Glisser très loin : le menu reste entier à l'écran (bord droit et bas de l'écran)",
         pos() == [0, round(1920 - 370 * s), 0, round(1080 - hauteur / 2)], (pos(), s, hauteur))
uis.__lua_index__("InputChanged").declencher(entree("MouseMovement", 400, 0), False); H.avancer(0.01)
uis.__lua_index__("InputEnded").declencher(entree("MouseButton1", 400, 0), False); H.avancer(1)
p = envois_prefs(remote)[n0:]
verifier("2. Au lâcher : la position est gardée dans les préférences (proportion de l'écran : x 0,163 ; y 0,457), par l'action EXISTANTE Prefs",
         len(p) == 1 and p[0].get("positionMenu") == {"x": 0.163, "y": 0.457}, p)
uis.__lua_index__("InputChanged").declencher(entree("MouseMovement", 900, 300), False); H.avancer(0.01)
verifier("2. Après le lâcher, la souris ne déplace plus le menu (il reste à la position gardée, à 1 px près)",
         abs(pos()[1] - gauche_attendu) <= 1 and abs(pos()[3] - centre_attendu) <= 1, pos())
touche_T(uis); touche_T(uis)
verifier("2. Fermé puis rouvert : le menu revient à la position choisie (à 1 px près)",
         pos()[0] == 0 and abs(pos()[1] - gauche_attendu) <= 1 and pos()[2] == 0 and abs(pos()[3] - centre_attendu) <= 1, pos())
# Simple clic : rien n'est envoyé
n1 = len(envois_prefs(remote))
plaque.__lua_index__("InputBegan").declencher(entree("MouseButton1", 200, 200)); H.avancer(0.01)
uis.__lua_index__("InputEnded").declencher(entree("MouseButton1", 200, 200), False); H.avancer(1)
verifier("2. Un simple clic sur l'en-tête : rien n'est sauvegardé", len(envois_prefs(remote)) == n1, envois_prefs(remote)[n1:])
# Au doigt
plaque.__lua_index__("InputBegan").declencher(entree("Touch", 300, 300)); H.avancer(0.01)
uis.__lua_index__("InputChanged").declencher(entree("Touch", 250, 300), False); H.avancer(0.01)
verifier("2. Au doigt aussi (Touch) : le menu suit", abs(pos()[1] - (gauche_attendu - 50)) <= 1, pos())
uis.__lua_index__("InputEnded").declencher(entree("Touch", 250, 300), False); H.avancer(1)
# Menu fermé : l'en-tête ne se prend pas
touche_T(uis)
ferme = pos()
plaque.__lua_index__("InputBegan").declencher(entree("MouseButton1", 100, 100)); H.avancer(0.01)
uis.__lua_index__("InputChanged").declencher(entree("MouseMovement", 600, 600), False); H.avancer(0.01)
uis.__lua_index__("InputEnded").declencher(entree("MouseButton1", 600, 600), False); H.avancer(0.01)
verifier("2. Menu fermé : caché à gauche, à la hauteur choisie ; on ne le déplace pas", ferme[1] == -394 and pos() == ferme, (ferme, pos()))
# Rétablir la position
touche_T(uis)
tache(lambda: appel(UI.get("setPref"), "positionMenu", None)); H.avancer(0.05)
verifier("2. Position rétablie (préférence effacée) : le menu ouvert revient à gauche, à sa place d'origine", pos() == [0, 12, 0.55, 0], pos())
# Préférence abîmée : la place d'origine
lua(I, UI, "UI.prefs.positionMenu = { x = 'a', y = 0 / 0 } UI.prefsChangees:Fire('positionMenu')"); H.avancer(0.05)
verifier("2. Préférence abîmée (texte, NaN) : la place d'origine, sans erreur", pos() == [0, 12, 0.55, 0] and not roblox.ERREURS, (pos(), roblox.ERREURS[:2]))
lua(I, UI, "UI.prefs.positionMenu = nil")
# Grande taille : le menu fermé ne dépasse plus
touche_T(uis)
tache(lambda: appel(UI.get("setPref"), "taille", 1.4)); H.avancer(0.05)
s = echelleTiroir.props["Scale"]
verifier("2. Taille 140 % : le menu fermé est entièrement caché (avant, il dépassait de l'écran)",
         s > 1.3 and pos()[1] + 370 * s < 0 and pos()[1] == -math.ceil(370 * s) - 24, (pos(), s))
touche_T(uis)
verifier("2. … et ouvert à 140 % : à sa place d'origine", pos() == [0, 12, 0.55, 0], pos())
verifier("2. Menu rapide : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])
# Téléphone : les boutons tactiles restent au bord quand le menu est déplacé
I, G, game, joueur, rs, remote, Config, UI, ext, salle, uis, liaisons, camera = monde_pilote(tactile=True, prefs={"ouvertureRapide": True, "positionMenu": {"x": 0.5, "y": 0.5}})
lancer_script(I, G, "StarterPlayer/StarterPlayerScripts/TardisMenu.client.lua")
menuT = joueur.m_FindFirstChild("PlayerGui").m_FindFirstChild("TardisMenu")
tiroirT = trouve(menuT, "Tiroir")
balT = next((e for e in tous(menuT, "Balayage") if e.ClassName == "Frame"), None)
touche_T(uis)
verifier("2. Téléphone : menu ouvert à la position gardée (milieu de l'écran), sans balayage (effets réduits d'office), sans erreur",
         tiroirT.props["Position"].args[1] == 960 and tiroirT.props["Position"].args[3] == 540 and balT.props["Visible"] is False and not roblox.ERREURS,
         (tiroirT.props["Position"].args, roblox.ERREURS[:2]))
menu_src = lire("StarterPlayer/StarterPlayerScripts/TardisMenu.client.lua")
verifier("2. Boutons tactiles : décalés à droite du menu seulement s'il est resté près du bord gauche",
         "if gauche < 70 then cible = UDim2.new(0, gauche + LARGEUR * echelleTiroir.Scale + 10, 0.38, 0) end" in menu_src)


# ================================================================== 3. La vraie tablette
def lancer_tablette(tactile=False, prefs=None):
    I, G, game, joueur, rs, remote, Config, UI, ext, salle, uis, liaisons, camera = monde_pilote(tactile=tactile, prefs=prefs)
    sps = Instance("StarterPlayerScripts", "StarterPlayerScripts", game.m_FindFirstChild("StarterPlayer"))
    script_t = Instance("LocalScript", "TardisTablette", sps)
    for nom in ("Construction", "Etat", "Navigation", "Ouverture", "Placement", "Volet", "Scanner", "Suivi", "Journal", "Outils"):
        m = Instance("ModuleScript", nom, script_t); m.extra["chemin"] = os.path.join(DEPOT, "StarterPlayer/StarterPlayerScripts/TardisTablette", nom + ".lua")
    lancer_script(I, G, "StarterPlayer/StarterPlayerScripts/TardisTablette/init.client.lua", script_t)
    tab = joueur.m_FindFirstChild("PlayerGui").m_FindFirstChild("TardisTablette")
    lighting = game.m_FindFirstChild("Lighting")
    return dict(I=I, G=G, joueur=joueur, remote=remote, UI=UI, tab=tab, tablette=trouve(tab, "Tablette"), flou=lighting.m_FindFirstChild("TardisTabletteFlou"),
                voile=next((e for e in tab.enfants if e.ClassName == "TextButton" and e.props.get("Modal") is True), None))
def ouvrir(T): T["joueur"].m_SetAttribute("TardisTablette", True); H.avancer(0.05)
def clic_voile(T, x, y): T["voile"].extra.setdefault("Activated", Signal("Activated")).declencher(entree("MouseButton1", x, y)); H.avancer(0.05)
T = lancer_tablette()
verifier("3. Tablette construite (10 modules), sans erreur ; le voile est trouvé", T["tab"] is not None and T["voile"] is not None and not roblox.ERREURS, roblox.ERREURS[:3])
T["tablette"].props.update({"AbsolutePosition": Valeur("Vector2", [560, 240]), "AbsoluteSize": Valeur("Vector2", [800, 600])})
ouvrir(T)
verifier("3. Sans l'option : ouverture animée comme avant (le voile part transparent et s'assombrit)",
         T["tablette"].props["Visible"] is True and T["voile"].props["BackgroundTransparency"] == 1)
clic_voile(T, 100, 100); H.avancer(0.4)
verifier("3. Sans l'option : un clic à côté ne ferme rien (seule la croix rouge, comme avant)",
         T["tablette"].props["Visible"] is True and T["joueur"].attrs.get("TardisTablette") is True)
tache(lambda: appel(T["UI"].get("setPref"), "fermerDehors", True)); H.avancer(0.05)
clic_voile(T, 900, 500); H.avancer(0.4)
verifier("3. Option « fermer en cliquant à côté » : un clic SUR la tablette (fond non cliquable) ne la ferme pas",
         T["tablette"].props["Visible"] is True and T["joueur"].attrs.get("TardisTablette") is True)
clic_voile(T, 100, 100); H.avancer(0.4)
verifier("3. … un clic à côté la ferme, comme la croix (attribut TardisTablette rendu)",
         T["tablette"].props["Visible"] is False and T["voile"].props["Visible"] is False and T["joueur"].attrs.get("TardisTablette") is False)
# Sans animation
tache(lambda: appel(T["UI"].get("setPref"), "ouvertureRapide", True)); H.avancer(0.05)
ouvrir(T)
echT = enfants(T["tablette"], classe="UIScale")
verifier("3. « Ouverture sans animation » : tout est posé d'un coup (voile 0,45, flou 18, taille finale, au centre)",
         T["voile"].props["BackgroundTransparency"] == 0.45 and T["flou"].props["Size"] == 18 and T["flou"].props["Enabled"] is True
         and T["tablette"].props["Position"].args == [0.5, 0, 0.5, 0] and echT and echT[0].props["Scale"] > 0.5,
         (T["voile"].props["BackgroundTransparency"], T["flou"].props["Size"], T["tablette"].props["Position"].args))
appuyer(trouve(T["tablette"], "Fermer"))
verifier("3. … et la croix la fait disparaître tout de suite (sans attendre la fin d'une animation)",
         T["tablette"].props["Visible"] is False and T["voile"].props["Visible"] is False and T["flou"].props["Enabled"] is False
         and T["joueur"].attrs.get("TardisTablette") is False)
# Réglages
ouvrir(T)
onglets = trouve(T["tab"], "Onglets")
appuyer(trouve(onglets, "Onglet_reglages"))
def ligne_reglage(debut):
    return next((b for b in descendants(T["tab"]) if b.ClassName == "TextButton" and texte_de(b).startswith(debut)), None)
lignes = {k: texte_de(ligne_reglage(k)) for k in ("Sous-titres des sons", "Ouverture des menus sans animation", "Fermer la tablette en cliquant à côté",
                                                   "Menu rapide", "Réduire les effets")}
verifier("3. Réglages : nouvelles lignes « Sous-titres des sons », « Ouverture des menus sans animation », « Fermer la tablette en cliquant à côté », « Menu rapide »",
         lignes["Sous-titres des sons"].startswith("Sous-titres des sons : activés") and lignes["Ouverture des menus sans animation"].endswith(": activée (tablette et menu rapide d'un coup)")
         and lignes["Fermer la tablette en cliquant à côté"].endswith(": activé") and lignes["Menu rapide"] == "Menu rapide : à sa place (glisse son en-tête pour le déplacer)"
         and lignes["Réduire les effets"] == "Réduire les effets : désactivé", lignes)
appuyer(ligne_reglage("Sous-titres des sons")); H.avancer(1)
verifier("3. Cliquer « Sous-titres des sons » : désactivés (préférence sousTitres envoyée)",
         texte_de(ligne_reglage("Sous-titres des sons")) == "Sous-titres des sons : désactivés" and envois_prefs(T["remote"])[-1].get("sousTitres") is False)
tache(lambda: appel(T["UI"].get("setPref"), "positionMenu", Table({"x": 0.4, "y": 0.5}))); H.avancer(0.05)
appuyer(trouve(onglets, "Onglet_aide")); appuyer(trouve(onglets, "Onglet_reglages"))
verifier("3. Menu rapide déplacé : la ligne propose « rétablir sa position (à gauche) »", texte_de(ligne_reglage("Menu rapide")) == "Menu rapide : rétablir sa position (à gauche)")
appuyer(ligne_reglage("Menu rapide")); H.avancer(1)
verifier("3. … un clic l'efface (le menu revient à gauche)", T["UI"].get("prefs").get("positionMenu") is None
         and texte_de(ligne_reglage("Menu rapide")).startswith("Menu rapide : à sa place") and "positionMenu" not in envois_prefs(T["remote"])[-1])
appuyer(ligne_reglage("Fermer la tablette en cliquant à côté"))
verifier("3. « Fermer en cliquant à côté » : se coupe d'un clic", texte_de(ligne_reglage("Fermer la tablette en cliquant à côté")).endswith(": désactivé")
         and T["UI"].get("prefs").get("fermerDehors") is False)
appuyer(trouve(onglets, "Onglet_aide"))
aide_txt = " ".join(texte_de(e) for e in descendants(T["tab"]) if e.ClassName in ("TextLabel", "TextButton"))
verifier("3. Aide : la croix ferme la tablette, un clic à côté aussi si l'option est activée ; glisser l'en-tête du menu rapide",
         "un clic à côté aussi si l'option des réglages est activée" in aide_txt and "glisse l'en-tête du menu rapide pour le déplacer" in aide_txt)
verifier("3. Tablette : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])
# Téléphone
T = lancer_tablette(tactile=True)
ouvrir(T)
appuyer(trouve(trouve(T["tab"], "Onglets"), "Onglet_reglages"))
verifier("3. Téléphone : « Réduire les effets : activé » d'office", texte_de(ligne_reglage("Réduire les effets")).startswith("Réduire les effets : activé"))
appuyer(ligne_reglage("Réduire les effets")); H.avancer(1)
p = envois_prefs(T["remote"])
verifier("3. Téléphone : la couper → « désactivé (activé d'office sur téléphone) », gardé sous effetsReduitsMobile (l'ordinateur n'est pas touché)",
         texte_de(ligne_reglage("Réduire les effets")) == "Réduire les effets : désactivé (activé d'office sur téléphone)"
         and p and p[-1].get("effetsReduitsMobile") is False and "effetsReduits" not in p[-1], p[-1:])
appuyer(ligne_reglage("Aucun flash")); H.avancer(1)
verifier("3. Téléphone : « Aucun flash » réactive « réduire les effets » sur ce téléphone",
         texte_de(ligne_reglage("Réduire les effets")).startswith("Réduire les effets : activé") and envois_prefs(T["remote"])[-1].get("effetsReduitsMobile") is True
         and "effetsReduits" not in envois_prefs(T["remote"])[-1])
verifier("3. Téléphone : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])
ouv = lire("StarterPlayer/StarterPlayerScripts/TardisTablette/Ouverture.lua")
verifier("3. Le clic à côté ne ferme jamais pendant un placement de destination, ni sans l'option",
         "if not UI.fermerDehors() or not S.ouvert or S.placement then return end" in ouv)


# ================================================================== 4. Le vrai module SousTitres
st_src = lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/SousTitres.lua")
def monde_soustitres(prefs=None, dedans=True, distance=10):
    I, G, game, joueur, rs, remote, Config, UI, uis = monde_client(prefs)
    Instance("PlayerGui", "PlayerGui", joueur)
    ws = game.m_FindFirstChild("Workspace")
    ext = Instance("Model", "Cabine", ws); ext.props["Pivot"] = CF((0, 0, 0))
    racine = Instance("Part", "HumanoidRootPart", ws); racine.props["Position"] = Vec3(distance, 0, 0)
    etat = {"dedans": dedans}
    Config.set("Jukebox", Table({1: Table({"nom": "Thème du Docteur"})}))
    ctx = Table({"C": UI.get("C"), "Config": Config, "E": Config.get("Etats"), "UI": UI, "creer": UI.get("creer"), "texte": UI.get("texte"),
                 "def": Config.get("Tardis").get(1), "exterieur": ext, "joueur": joueur,
                 "jeSuisDedans": Fonction("jeSuisDedans", py=lambda: etat["dedans"]), "maRacine": Fonction("maRacine", py=lambda: racine)})
    R = {}
    tache(lambda: R.update(M=premier(appeler(premier(I.executer(st_src, "SousTitres")), [ctx])))); H.avancer(0.05)
    gui = joueur.m_FindFirstChild("PlayerGui").m_FindFirstChild("TardisSousTitres_TARDIS_1")
    return dict(UI=UI, Config=Config, ext=ext, etat=etat, racine=racine, M=R.get("M"), gui=gui, cadre=gui and trouve(gui, "SousTitre"), texte=gui and trouve(gui, "Texte"))
def sous_titre(S): return texte_de(S["texte"]) if S["cadre"].props["Visible"] is True else None
def attr(S, k, v): S["ext"].m_SetAttribute(k, v); H.avancer(0.05)
S = monde_soustitres()
verifier("4. Module SousTitres chargé : bandeau « TardisSousTitres_TARDIS_1 » en bas de l'écran, caché, sans erreur",
         S["M"] is not None and S["gui"] is not None and S["cadre"].props["Visible"] is False and S["cadre"].props["AnchorPoint"].args == [0.5, 1]
         and not roblox.ERREURS, roblox.ERREURS[:3])
verifier("4. Le bandeau suit la taille de l'interface (UIScale)", len(enfants(S["cadre"], classe="UIScale")) == 1)
attr(S, "Mode", "Normal"); attr(S, "Etat", "Demat")
verifier("4. Démat en Classique : « [Dématérialisation] »", sous_titre(S) == "[Dématérialisation]", sous_titre(S))
attr(S, "Etat", "Vol"); attr(S, "Mode", "Urgence"); attr(S, "Etat", "Remat")
verifier("4. Remat en Urgence : « [Matérialisation · Urgence] »", sous_titre(S) == "[Matérialisation · Urgence]", sous_titre(S))
H.avancer(4.1)
verifier("4. Masqué après Config.SousTitres.Duree (4 s)", sous_titre(S) is None)
attr(S, "Etat", "Pose"); attr(S, "Mode", "Silencieux"); attr(S, "Etat", "Demat")
verifier("4. Mode Silencieux : aucun sous-titre (il ne fait aucun son)", sous_titre(S) is None, sous_titre(S))
attr(S, "Etat", "Pose"); attr(S, "Mode", "Normal")
S["ext"].attrs["VolPhaseMode"] = "Express"; attr(S, "VolPhase", "Demat")
verifier("4. Vol libre : la démat de la phase de vol est sous-titrée avec son mode", sous_titre(S) is not None and sous_titre(S).startswith("[Dématérialisation · "), sous_titre(S))
attr(S, "Alerte", True)
verifier("4. Alerte générale à bord : « [Alarme du TARDIS] »", sous_titre(S) == "[Alarme du TARDIS]", sous_titre(S))
attr(S, "Jukebox", 1)
verifier("4. Jukebox à bord : « [Musique : Thème du Docteur] » (nom de la piste)", sous_titre(S) == "[Musique : Thème du Docteur]", sous_titre(S))
attr(S, "Jukebox", 7)
verifier("4. Piste inconnue : « [Musique : piste 7] » ; playlist : son nom", sous_titre(S) == "[Musique : piste 7]", sous_titre(S))
attr(S, "Jukebox", "Calme")
verifier("4. … playlist « Calme » : « [Musique : playlist Calme] »", sous_titre(S) == "[Musique : playlist Calme]", sous_titre(S))
attr(S, "AutoDestructionDebut", 1234)
verifier("4. Auto-destruction : « [Alarme d'auto-destruction] »", sous_titre(S) == "[Alarme d'auto-destruction]", sous_titre(S))
attr(S, "Explosion", 1250)
verifier("4. Explosion : « [Explosion] »", sous_titre(S) == "[Explosion]", sous_titre(S))
H.avancer(1); attr(S, "Jukebox", None); H.avancer(3.5)
verifier("4. Arrêt du jukebox : rien ; un nouveau sous-titre repart pour sa propre durée (l'ancien délai ne le coupe pas)", sous_titre(S) is None)
verifier("4. Sous-titres : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])
# Dehors
S = monde_soustitres(dedans=False, distance=60)
attr(S, "Etat", "Demat")
verifier("4. Dehors, à 60 studs de la cabine : la démat est sous-titrée", sous_titre(S) == "[Dématérialisation]", sous_titre(S))
H.avancer(5); attr(S, "Alerte", True); attr(S, "Jukebox", 1)
verifier("4. Dehors : ni l'alarme ni la musique de la salle (on ne les entend qu'à bord)", sous_titre(S) is None, sous_titre(S))
S = monde_soustitres(dedans=False, distance=500)
attr(S, "Etat", "Demat")
verifier("4. Dehors, à 500 studs (au-delà de Config.SousTitres.Portee = 120) : rien", sous_titre(S) is None, sous_titre(S))
S = monde_soustitres({"sousTitres": False})
attr(S, "Etat", "Demat"); attr(S, "Alerte", True)
verifier("4. Option « Sous-titres des sons » coupée : rien", sous_titre(S) is None, sous_titre(S))
S = monde_soustitres()
S["Config"].get("SousTitres").set("Actif", False)
attr(S, "Etat", "Demat")
verifier("4. Config.SousTitres.Actif = false : rien, pour tout le monde", sous_titre(S) is None, sous_titre(S))
verifier("4. Réglages dans Config.SousTitres (Actif, Duree 4, Portee 120, Textes modifiables)",
         [S["Config"].get("SousTitres").get(k) for k in ("Duree", "Portee")] == [4, 120]
         and S["Config"].get("SousTitres").get("Textes").get("Musique") == "[Musique : %s]")
verifier("4. Tout est local : aucun envoi au serveur, aucun son joué", "FireServer" not in st_src and ":Play()" not in st_src)


# ================================================================== 5. Taille de l'interface (proposition 72)
B = "StarterPlayer/StarterPlayerScripts/"
for chemin, marque in (("TardisExtrasClient/Signalisation.lua", "UI.suivreTaille(cadre)"), ("TardisExtrasClient/TabletteLecture.lua", "UI.suivreTaille(panneau)"),
                       ("TardisExtrasClient/Replay.lua", "UI.suivreTaille(etiquette)"), ("TardisExtrasClient/Systemes.lua", "UI.suivreTaille(panneau)"),
                       ("TardisExtrasClient/Preferences.lua", "UI.suivreTaille(carte)"), ("TardisExtrasClient/Regeneration.lua", "UI.suivreTaille(carte)"),
                       ("TardisExtrasClient/SousTitres.lua", "UI.suivreTaille(cadre)"), ("TardisPorter.client.lua", "UI.suivreTaille(cadre)"),
                       ("TardisExtrasClient/Copilote.lua", "0.55, 1) * UI.tailleInterface()"), ("TardisExtrasClient/Intercom.lua", "0.6, 1) * UI.tailleInterface()")):
    verifier(f"5. {os.path.basename(chemin)} suit la taille de l'interface", marque in lire(B + chemin))
pref_src = lire(B + "TardisExtrasClient/Preferences.lua")
verifier("5. Carte de découverte : cachée assez loin à droite pour ne pas dépasser, même agrandie (à l'aller comme au retour)",
         "local CACHEE = UDim2.new(1, math.max(360, math.ceil(340 * echelleCarte.Scale) + 20), 0, 90)" in pref_src
         and "animer(carte, 0.4, { Position = CACHEE })" in pref_src and "UDim2.new(1, 360, 0, 90) })" not in pref_src)
cam = lire(B + "TardisCamera.client.lua")
verifier("5. Caméra du toit : « Quitter », « Orbite » et l'aide suivent la taille ; Orbite et l'aide se recalent (positions d'avant à 100 %)",
         "for _, objet in { quitter, boutonOrbite, aide } do" in cam and "math.floor(130 * s + 10 + 0.5)" in cam and "-math.floor(30 + 44 * s + 8 + 0.5)" in cam
         and 'if cle == "taille" then placerBoutonsCamera() end' in cam)
verifier("5. À 100 % : Orbite à (0,5, 140, 1, −30) et l'aide à (0,5, 0, 1, −82), comme avant",
         math.floor(130 * 1 + 10 + 0.5) == 140 and math.floor(30 + 44 * 1 + 8 + 0.5) == 82
         and "boutonOrbite.Position = UDim2.new(0.5, 140, 1, -30)" in cam and "aide.Position = UDim2.new(0.5, 0, 1, -82)" in cam)
# Exécution réelle d'un module : Signalisation suit la taille (son cadre)
I, G, game, joueur, rs, remote, Config, UI, uis = monde_client()
ecran = Instance("ScreenGui", "Essai", Instance("PlayerGui", "PlayerGui", joueur)); G["ECRAN"] = ecran
lua(I, UI, "local c = UI.creer('Frame', { Name = 'Annonce', Parent = ECRAN }) UI.suivreTaille(c)")
tache(lambda: appel(UI.get("setPref"), "taille", 0.8)); H.avancer(0.05)
verifier("5. Taille 80 % : un menu suivi passe à 0,8", [e.props.get("Scale") for e in enfants(trouve(ecran, "Annonce"), classe="UIScale")] == [0.8])


# ================================================================== 6. Le code
config_src = lire("ReplicatedStorage/TardisConfig.lua")
ui_src = lire("ReplicatedStorage/TardisUI.lua")
volet = lire(B + "TardisTablette/Volet.lua")
initc = lire(B + "TardisExtrasClient/init.client.lua")
for chemin, src in (("TardisConfig", config_src), ("TardisUI", ui_src), ("TardisMenu", menu_src), ("Ouverture", ouv), ("Volet", volet),
                    ("SousTitres", st_src), ("init.client", initc), ("TardisCamera", cam), ("Preferences", pref_src)):
    verifier(f"6. {chemin} : ajouts marqués « V6.9.15 »", "V6.9.15" in src)
verifier("6. Version 6.9.15 ou plus récente dans TardisConfig", version(Config.get("Version")) >= (6, 9, 15) and 'Config.Version = "' in config_src, Config.get("Version"))
verifier("6. init.client charge SousTitres (avant Preferences)",
         'require(script:WaitForChild("SousTitres"))' in initc and initc.index('"SousTitres"') < initc.index('"Preferences"'))
serveur = "".join(open(os.path.join(r, f), encoding="utf-8").read() for r, _, fs in os.walk(os.path.join(DEPOT, "ServerScriptService")) for f in fs if f.endswith(".lua"))
verifier("6. Rien de nouveau côté serveur (préférences gardées telles quelles, déjà validées : JSON, taille)",
         "V6.9.15" not in serveur and "prefs[joueur.UserId] = donnees" in serveur)
actions = set(re.findall(r'FireServer\("(\w+)"', menu_src + ouv + volet + st_src))
verifier("6. Aucune nouvelle action réseau (les options passent par l'action EXISTANTE Prefs de TardisUI)",
         actions == {"Camouflage", "Portes", "Siege", "Taille", "Verrou", "VolLibreDebut"} and 'FireServer("Prefs"' in ui_src, actions)
verifier("6. Les raccourcis T, Y et E ne changent pas", "local TOUCHE = Enum.KeyCode.T" in menu_src and "Y : tablette" in volet)

print("\n".join("  ✓ " + o for o in OK)); print("\n".join("  ✗ " + k for k in KO))
print(f"V6.9.15 : {len(OK)}/{len(OK) + len(KO)} vérifications réussies")
sys.exit(1 if KO else 0)
