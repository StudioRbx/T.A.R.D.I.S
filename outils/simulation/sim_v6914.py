"""Simulations de la V6.9.14 (équipage et garde-robe : propositions 63, 90, 89, 54) : le vrai code, extrait des scripts et exécuté.
  1. TardisConfig : version, tenues en attente (identifiants à 0, à la fin de la liste), regeneration = false, uniformes
     et badges des deux équipes (Config.tenueDisponible, Config.reglagesEquipe, Config.uniformeDe, Config.badgeDe),
     réglages des portes intérieures animées.
  2. Serveur des tenues : vrai TardisTenues (les identifiants 0 ne sont jamais demandés, les uniformes réglés sont
     résolus), vrai appliquerTenue de TardisExtras (tenue en attente refusée), vrai habillerTenueJeu (regeneration = false
     et tenues en attente jamais tirées).
  3. Uniforme (vrai TardisSystemes : mettreUniforme, uniformeApresRegeneration, début de surveillerPersonnage) : mis à
     l'apparition d'un membre et quand il rejoint l'équipe, rien avec des identifiants à 0, jamais pendant une
     régénération (enAttente, TardisRegeneration), après une régénération seulement si le réglage fixe le demande.
  4. Le vrai client, casier (module Interactions) : tenues rangées par catégorie (en-têtes, une grille par groupe),
     favoris en tête, tenues en attente cachées, casier vide expliqué.
  5. Le vrai client, module Badges : badge au-dessus de la tête des membres des deux équipes (pas sur soi), suit la
     Team, image facultative, Badge = false, garde « premier TARDIS », aucun envoi au serveur.
  6. Portes intérieures (vrai TardisPortail, section extraite) : battants Gauche / Droite qui tournent autour de leur
     Charniere avec LeftOpen / RightOpen (ou PorteOuverte), angle réglable, passage libre puis solide une fois refermés ;
     sans ce rangement, le masquage d'avant.
  7. Le code : repères (V6.9.14), module chargé par init.client, version."""
import os, sys, json, re, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from monde import *
import roblox
from roblox import Couleur, Vec3, CF, activer_maths
OK, KO = [], []
def verifier(nom, condition, detail=""):
    (OK if condition else KO).append(nom + ("" if condition else "  →  " + str(detail)))
def tache(f): lancer(Fonction("t", py=f))
def lire(chemin): return open(os.path.join(DEPOT, chemin), encoding="utf-8").read()
def entre(texte, debut, fin): return texte[texte.index(debut):texte.index(fin, texte.index(debut))]
def vider_cache(): roblox.charger_module.__defaults__[0].clear()
def version(v):
    try: return tuple(int(p) for p in str(v).split("."))
    except ValueError: return ()
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
def appel(f, *a):
    res = {}
    tache(lambda: res.update(v=list(appeler(f, list(a)) or [])))
    return (res.get("v") or []) + [None, None]
def piece(nom, parent, pos, taille=(2, 2, 2), classe="Part"):
    p = Instance(classe, nom, parent)
    p.props.update({"Position": Vec3(*pos), "CFrame": CF(pos), "Pivot": CF(pos), "Size": Vec3(*taille)})
    return p
def liste_lua(t, n=40): return [t.get(i) for i in range(1, n + 1) if t is not None and t.get(i) is not None]
def appuyer(b): b.extra.setdefault("Activated", Signal("Activated")).declencher(); H.avancer(0.01)
def declencher(o, sig, *a): o.extra.setdefault(sig, Signal(sig)).declencher(*a); H.avancer(0.01)
def changer_equipe(joueur, equipe):
    joueur.props["Team"] = equipe
    sig = joueur.extra.get("prop_Team")
    if sig: sig.declencher()
    H.avancer(0.01)
R = {}

systemes = lire("ServerScriptService/TardisSystemes.server.lua")
extras = lire("ServerScriptService/TardisExtras.server.lua")
tenues_src = lire("ServerScriptService/TardisTenues.lua")
config_src = lire("ReplicatedStorage/TardisConfig.lua")
interactions = lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Interactions.lua")
badges = lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Badges.lua")
initclient = lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/init.client.lua")
portail = lire("StarterPlayer/StarterPlayerScripts/TardisPortail.client.lua")

# ================================================================== 1. TardisConfig
vider_cache(); roblox.ERREURS.clear()
I, G, game, pilote = monde(serveur=True)
activer_maths(G)
rs = game.m_FindFirstChild("ReplicatedStorage")
tache(lambda: R.update(Config=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisConfig")]))))
Config = R["Config"]
verifier("1. Vrai TardisConfig chargé, version 6.9.14 ou plus", version(Config.get("Version")) >= (6, 9, 14) and not roblox.ERREURS, (Config.get("Version"), roblox.ERREURS[:3]))
TEN = Config.get("Tenues"); NT = TEN.longueur()
noms = [TEN.get(i).get("nom") for i in range(1, NT + 1)]
verifier("1. Les 9 tenues d'avant gardent leur place (favoris rangés par numéro), 5 nouvelles À LA FIN",
         noms[:9] == ["Pannaro", "Abete", "Corde", "Fausto", "Vittorio", "Bluastro", "Bosco", "Azzurro Regale", "Canard"]
         and noms[9:] == ["Chronos", "Nebula", "Atelier", "Soudeur", "Gala"], noms)
verifier("1. Nouvelles tenues : identifiants à 0 (à compléter dans Studio), catégories Voyage / Technique / Festive",
         all(TEN.get(i).get("shirt") == 0 and TEN.get(i).get("pant") == 0 for i in range(10, 15))
         and [TEN.get(i).get("categorie") for i in range(10, 15)] == ["Voyage", "Voyage", "Technique", "Technique", "Festive"])
verifier("1. regeneration = false sur les tenues de fête (Pannaro, Azzurro Regale, Canard, Gala), absent ailleurs",
         [noms[i - 1] for i in range(1, NT + 1) if TEN.get(i).get("regeneration") is False] == ["Pannaro", "Azzurro Regale", "Canard", "Gala"]
         and all(TEN.get(i).get("regeneration") is None for i in range(1, NT + 1) if noms[i - 1] not in ("Pannaro", "Azzurro Regale", "Canard", "Gala")))
dispo = lambda t: appel(Config.get("tenueDisponible"), t)[0]
verifier("1. Config.tenueDisponible : vraie pour les 9 tenues d'avant, fausse pour les 5 en attente",
         [dispo(TEN.get(i)) for i in range(1, NT + 1)] == [True] * 9 + [False] * 5)
verifier("1. … fausse pour un haut seul, un bas à 0, rien, un texte ; vraie avec des identifiants en texte",
         dispo(Table({"shirt": 5, "pant": 0})) is False and dispo(Table({"shirt": 5})) is False and dispo(None) is False and dispo("x") is False
         and dispo(Table({"shirt": "123", "pant": "456"})) is True)
EQ, ET = Config.get("Equipe"), Config.get("EquipeTechnique")
UE, UT = EQ.get("Uniforme"), ET.get("Uniforme")
verifier("1. Config.Equipe.Uniforme : Actif, shirt = 0, pant = 0, ApresRegeneration = false (réglage fixe) ; Badge, BadgeImage = 0",
         (UE.get("Actif"), UE.get("shirt"), UE.get("pant"), UE.get("ApresRegeneration"), EQ.get("Badge"), EQ.get("BadgeImage")) == (True, 0, 0, False, True, 0))
verifier("1. Config.EquipeTechnique.Uniforme : Actif, 0, 0 ; Badge, BadgeImage = 0",
         (UT.get("Actif"), UT.get("shirt"), UT.get("pant"), ET.get("Badge"), ET.get("BadgeImage")) == (True, 0, 0, True, 0))
reg = lambda n: appel(Config.get("reglagesEquipe"), n)[0]
verifier("1. Config.reglagesEquipe : C.A.T. → Config.Equipe, C.T.A.T. → Config.EquipeTechnique, autre / vide / nil → nil",
         reg("C.A.T.") is EQ and reg("C.T.A.T.") is ET and reg("Visiteurs") is None and reg("") is None and reg(None) is None)
uni = lambda n: appel(Config.get("uniformeDe"), n)[0]
verifier("1. Config.uniformeDe : identifiants à 0 → nil (rien n'est appliqué)", uni("C.A.T.") is None and uni("C.T.A.T.") is None and uni("Visiteurs") is None)
UE.set("shirt", 5001); UE.set("pant", 5002)
u = uni("C.A.T.")
verifier("1. … identifiants donnés → une tenue « Uniforme C.A.T. » { shirt, pant }", u is not None and (u.get("nom"), u.get("shirt"), u.get("pant")) == ("Uniforme C.A.T.", 5001, 5002))
UE.set("Actif", False)
verifier("1. … Actif = false → nil", uni("C.A.T.") is None)
UE.set("Actif", True); UE.set("shirt", 0); UE.set("pant", 0)
bad = lambda n: appel(Config.get("badgeDe"), n)[0]
b1 = bad("C.A.T.")
verifier("1. Config.badgeDe : texte = nom de l'équipe, pas d'image (BadgeImage = 0) ; autre équipe → nil",
         b1 is not None and b1.get("texte") == "C.A.T." and b1.get("image") is None and bad("C.T.A.T.").get("texte") == "C.T.A.T." and bad("Visiteurs") is None)
ET.set("BadgeImage", 777); EQ.set("Badge", False)
verifier("1. … BadgeImage donné → « rbxassetid://777 » ; Badge = false → nil", bad("C.T.A.T.").get("image") == "rbxassetid://777" and bad("C.A.T.") is None)
ET.set("BadgeImage", 0); EQ.set("Badge", True)
PIA = Config.get("PortesInterieuresAnimees")
verifier("1. Config.PortesInterieuresAnimees : 90° en 0,5 s", PIA is not None and (PIA.get("Angle"), PIA.get("Duree")) == (90, 0.5))
verifier("1. Config : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])

# ================================================================== 2. Serveur des tenues
vider_cache(); roblox.ERREURS.clear(); roblox.SORTIE.clear()
I, G, game, pilote = monde(serveur=True)
activer_maths(G)
rs = game.m_FindFirstChild("ReplicatedStorage"); ws = game.m_FindFirstChild("Workspace"); sss = game.m_FindFirstChild("ServerScriptService")
Players = game.m_FindFirstChild("Players")
tache(lambda: R.update(Config=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisConfig")]))))
Config = R["Config"]; TEN = Config.get("Tenues"); NT = TEN.longueur()
EQ, ET = Config.get("Equipe"), Config.get("EquipeTechnique")
EQ.get("Uniforme").set("shirt", 5001); EQ.get("Uniforme").set("pant", 5002)  # uniforme de la C.A.T. réglé ; C.T.A.T. laissé à 0
mt = Instance("ModuleScript", "TardisTenues", sss); mt.extra["chemin"] = DEPOT + "/ServerScriptService/TardisTenues.lua"
APPELS = {}
def charger_objet(_s, id_):
    id_ = int(id_); APPELS[id_] = APPELS.get(id_, 0) + 1
    m = Instance("Model", "Model")
    genre = "Shirt" if (id_ % 2 == 1 or id_ in SHIRTS) and id_ not in PANTS else "Pants"
    v = Instance(genre, genre, m); v.props["ShirtTemplate" if genre == "Shirt" else "PantsTemplate"] = "rbxassetid://9%d" % id_
    return m
SHIRTS = {int(TEN.get(i).get("shirt")) for i in range(1, NT + 1)} | {5001}
PANTS = {int(TEN.get(i).get("pant")) for i in range(1, NT + 1)} | {5002}
SHIRTS.discard(0); PANTS.discard(0)
ins = Instance("InsertService", "InsertService", game); ins.extra["LoadAsset"] = Fonction("LoadAsset", py=charger_objet)
tache(lambda: R.update(T=premier(appeler(G["require"], [mt]))))
tache(lambda: appeler(R["T"].get("demarrer"), [])); H.avancer(30)
at = rs.m_FindFirstChild("TardisAssets").m_FindFirstChild("Tenues").attrs
verifier("2. Vrai TardisTenues : l'identifiant 0 n'est JAMAIS demandé au catalogue (tenues en attente ignorées)", 0 not in APPELS and APPELS, sorted(APPELS)[:5])
verifier("2. … les 9 tenues disponibles sont résolues (18 vêtements)", all(at.get("Shirt_%d" % s) and at.get("Pants_%d" % p) for s, p in
         ((int(TEN.get(i).get("shirt")), int(TEN.get(i).get("pant"))) for i in range(1, 10))), len(at))
verifier("2. … l'uniforme réglé de la C.A.T. est résolu avec les tenues (aperçu prêt) ; celui de la C.T.A.T. (0) est ignoré",
         at.get("Shirt_5001") == "rbxassetid://95001" and at.get("Pants_5002") == "rbxassetid://95002" and "Shirt_0" not in at and "Pants_0" not in at, dict(list(at.items())[-3:]))
verifier("2. … aucune ligne « Tenues » dans l'Output (une tenue en attente n'est pas une erreur)", not [l for l in roblox.SORTIE if "Tenues" in l], roblox.SORTIE[-3:])
# Vrai appliquerTenue (TardisExtras) : une tenue en attente est refusée tout de suite
d_t = extras.index('local Tenues = require(script.Parent:WaitForChild("TardisTenues"))')
f_t = extras.index("Players.PlayerRemoving:Connect(function(joueur) tenuesEnCours[joueur] = nil end)")
canal = Instance("RemoteEvent", "TardisCommande_TARDIS_1", rs)
code_t = "local Config, Players, remote = ...\n" + extras[d_t:f_t] + "\nreturn appliquerTenue\n"
tache(lambda: R.update(AT=premier(I.executer(code_t, "appliquerTenue", (Config, Players, canal)))))
def personnage_de(joueur, nom="Perso"):
    perso = Instance("Model", nom, ws); hum = Instance("Humanoid", "Humanoid", perso)
    piece("Head", perso, (0, 4.5, 0), (2, 1, 1)); piece("HumanoidRootPart", perso, (0, 3, 0), (2, 2, 1))
    sh = Instance("Shirt", "Shirt", perso); sh.props["ShirtTemplate"] = "rbxassetid://1111"
    pa = Instance("Pants", "Pants", perso); pa.props["PantsTemplate"] = "rbxassetid://2222"
    hum.extra["SetStateEnabled"] = Fonction("SetStateEnabled", py=lambda *a: [])
    joueur.props["Character"] = perso
    return perso, hum
def habits(perso):
    sh, pa = perso.m_FindFirstChildOfClass("Shirt"), perso.m_FindFirstChildOfClass("Pants")
    return (sh.props.get("ShirtTemplate") if sh else None, pa.props.get("PantsTemplate") if pa else None)
perso, hum = personnage_de(pilote)
ok10 = appel(R["AT"], pilote, 10)[0]; H.avancer(2)
verifier("2. Vrai appliquerTenue : la tenue 10 (Chronos, identifiants à 0) est refusée, vêtements gardés, aucun message",
         R.get("AT") is not None and ok10 is False and habits(perso) == ("rbxassetid://1111", "rbxassetid://2222") and not canal.extra.get("envoisClient"), (ok10, habits(perso)))
ok2 = appel(R["AT"], pilote, 2)[0]; H.avancer(2)
verifier("2. … une tenue disponible (2, Abete) est toujours mise", ok2 is True and habits(perso)[0] == "rbxassetid://9%d" % int(TEN.get(2).get("shirt")) and perso.attrs.get("TardisTenue") == 2, habits(perso))
# Vrai habillerTenueJeu (TardisSystemes) et les fonctions de l'uniforme
d_r = systemes.index('local Tenues = require(script.Parent:WaitForChild("TardisTenues"))'); f_r = systemes.index("-- Applique l'avatar puis vérifie")
surv = entre(systemes, "local function surveillerPersonnage(joueur, personnage)", "\n\t-- Articulations gardées")
code_r = ("local Config, def, enAttente, estRegenerateur = ...\n" + systemes[d_r:f_r] + "\n" + surv + "\nend\n"
          "return { habiller = habillerTenueJeu, mettre = mettreUniforme, apres = uniformeApresRegeneration, surveiller = surveillerPersonnage }\n")
ATTENTE = Table()
tache(lambda: R.update(SY=premier(I.executer(code_r, "uniformes", (Config, Config.get("Tardis").get(1), ATTENTE, Fonction("estRegenerateur", py=lambda j: [False]))))))
SY = R.get("SY")
verifier("2. Vrai code de TardisSystemes extrait (habillerTenueJeu, mettreUniforme, uniformeApresRegeneration, surveillerPersonnage), sans erreur",
         SY is not None and not roblox.ERREURS, roblox.ERREURS[:3])
TIRES = set()
regenere, hr = personnage_de(Instance("Player", "Regenere", Players), "Regenere")
for k in range(60):
    tache(lambda: appel(SY.get("habiller"), regenere)); H.avancer(0.1)
    TIRES.add(habits(regenere)[0])
interdits = {"rbxassetid://9%d" % int(TEN.get(i).get("shirt")) for i in range(1, 10) if TEN.get(i).get("regeneration") is False}
verifier("2. Vrai habillerTenueJeu (60 tirages) : jamais une tenue regeneration = false (Pannaro, Azzurro Regale, Canard), jamais une tenue en attente",
         TIRES and not (TIRES & interdits) and all(t and t.startswith("rbxassetid://9") and t != "rbxassetid://90" for t in TIRES), sorted(TIRES))
verifier("2. … les 6 autres tenues sont bien tirées", len(TIRES) == 6, len(TIRES))
verifier("2. Aucune erreur (serveur des tenues)", not roblox.ERREURS, roblox.ERREURS[:3])

# ================================================================== 3. Uniforme des équipes (vrai TardisSystemes)
roblox.ERREURS.clear()
CAT, CTAT, VIS = Instance("Team", "C.A.T."), Instance("Team", "C.T.A.T."), Instance("Team", "Visiteurs")
UNI = ("rbxassetid://95001", "rbxassetid://95002")
alice = Instance("Player", "Alice", Players); alice.props.update({"UserId": 11, "Team": CAT})
alice.extra["HasAppearanceLoaded"] = Fonction("HasAppearanceLoaded", py=lambda _s: [True])
pa_, ha = personnage_de(alice, "Alice")
tache(lambda: appel(SY.get("surveiller"), alice, pa_)); H.avancer(1)
verifier("3. Membre de la C.A.T. qui apparaît (uniforme réglé) : l'uniforme est mis par le serveur", habits(pa_) == UNI, habits(pa_))
verifier("3. … ce n'est pas la tenue d'un casier (attribut TardisTenue retiré)", pa_.attrs.get("TardisTenue") is None)
# Avatar pas encore chargé : on attend CharacterAppearanceLoaded (8 s au plus)
bob = Instance("Player", "Bob", Players); bob.props.update({"UserId": 12, "Team": CAT})
bob.extra["HasAppearanceLoaded"] = Fonction("HasAppearanceLoaded", py=lambda _s: [False])
pb, hb = personnage_de(bob, "Bob")
tache(lambda: appel(SY.get("surveiller"), bob, pb)); H.avancer(1)
avant_b = habits(pb)
declencher(bob, "CharacterAppearanceLoaded"); H.avancer(0.5)
verifier("3. Avatar pas encore chargé : l'uniforme attend CharacterAppearanceLoaded (sinon l'avatar arrive par-dessus)",
         avant_b == ("rbxassetid://1111", "rbxassetid://2222") and habits(pb) == UNI, (avant_b, habits(pb)))
carl = Instance("Player", "Carl", Players); carl.props.update({"UserId": 13, "Team": CAT})  # pas de HasAppearanceLoaded : pcall, 8 s au plus
pc, hc = personnage_de(carl, "Carl")
tache(lambda: appel(SY.get("surveiller"), carl, pc)); H.avancer(4)
avant_c = habits(pc); H.avancer(5)
verifier("3. Sans réponse de l'avatar : 8 s au plus, puis l'uniforme (aucune erreur)", avant_c == ("rbxassetid://1111", "rbxassetid://2222") and habits(pc) == UNI and not roblox.ERREURS, (avant_c, habits(pc), roblox.ERREURS[:2]))
# Corps neuf d'une régénération : jamais d'uniforme
dan = Instance("Player", "Dan", Players); dan.props.update({"UserId": 14, "Team": CAT})
dan.extra["HasAppearanceLoaded"] = Fonction("HasAppearanceLoaded", py=lambda _s: [True])
ATTENTE.set(14, Table({"habille": True}))
pd, hd = personnage_de(dan, "Dan")
tache(lambda: appel(SY.get("surveiller"), dan, pd)); H.avancer(1)
ATTENTE.set(14, None); H.avancer(1)
verifier("3. Corps neuf d'une régénération (enAttente) : pas d'uniforme, même une fois la régénération finie", habits(pd) == ("rbxassetid://1111", "rbxassetid://2222"), habits(pd))
# Changement d'équipe
eve = Instance("Player", "Eve", Players); eve.props.update({"UserId": 15, "Team": VIS})
eve.extra["HasAppearanceLoaded"] = Fonction("HasAppearanceLoaded", py=lambda _s: [True])
pe, he = personnage_de(eve, "Eve")
tache(lambda: appel(SY.get("surveiller"), eve, pe)); H.avancer(1)
verifier("3. Autre équipe (Visiteurs) : rien n'est mis", habits(pe) == ("rbxassetid://1111", "rbxassetid://2222"))
changer_equipe(eve, CAT); H.avancer(1)
verifier("3. Elle rejoint la C.A.T. : l'uniforme est mis (changement de Team suivi)", habits(pe) == UNI, habits(pe))
for p_ in (pe,):
    for c in ("Shirt", "Pants"): p_.m_FindFirstChildOfClass(c).props[c + "Template"] = "rbxassetid://3333"
changer_equipe(eve, CTAT); H.avancer(1)
verifier("3. Elle passe à la C.T.A.T. (identifiants à 0) : rien n'est fait, aucune erreur", habits(pe) == ("rbxassetid://3333", "rbxassetid://3333") and not roblox.ERREURS, (habits(pe), roblox.ERREURS[:2]))
pe.m_SetAttribute("TardisRegeneration", 12.5)
changer_equipe(eve, CAT); H.avancer(1)
verifier("3. Pendant une régénération (attribut TardisRegeneration) : le changement d'équipe ne met pas l'uniforme", habits(pe) == ("rbxassetid://3333", "rbxassetid://3333"), habits(pe))
pe.m_SetAttribute("TardisRegeneration", None)
ATTENTE.set(15, Table({}))
changer_equipe(eve, VIS); changer_equipe(eve, CAT); H.avancer(1)
verifier("3. Régénération en attente (enAttente) : pas d'uniforme non plus", habits(pe) == ("rbxassetid://3333", "rbxassetid://3333"), habits(pe))
ATTENTE.set(15, None)
pe.set_parent(None); pe.extra.get("AncestryChanged") and pe.extra["AncestryChanged"].declencher(); H.avancer(0.1)
changer_equipe(eve, VIS); changer_equipe(eve, CAT); H.avancer(1)
verifier("3. Personnage disparu : plus rien (connexion retirée), aucune erreur", habits(pe) == ("rbxassetid://3333", "rbxassetid://3333") and not roblox.ERREURS, roblox.ERREURS[:2])
# Après une régénération : réglage fixe ApresRegeneration
fr = Instance("Player", "Fred", Players); fr.props.update({"UserId": 16, "Team": CAT})
pf, hf = personnage_de(fr, "Fred")
pf.m_SetAttribute("TardisRegeneration", 3.0)
apres = appel(SY.get("apres"), fr, pf)[0]
verifier("3. Après une régénération, ApresRegeneration = false (défaut) : la nouvelle apparence est gardée", apres is False and habits(pf) == ("rbxassetid://1111", "rbxassetid://2222"))
verifier("3. mettreUniforme refuse pendant une régénération (sans le drapeau « après »)", appel(SY.get("mettre"), fr, pf)[0] is False and habits(pf) == ("rbxassetid://1111", "rbxassetid://2222"))
Config.get("Equipe").get("Uniforme").set("ApresRegeneration", True)
apres = appel(SY.get("apres"), fr, pf)[0]; H.avancer(0.5)
verifier("3. ApresRegeneration = true : l'uniforme est remis par-dessus la nouvelle apparence", apres is True and habits(pf) == UNI, (apres, habits(pf)))
changer_equipe(fr, CTAT)
verifier("3. … la C.T.A.T. n'a pas ce réglage (absent = faux) : rien", appel(SY.get("apres"), fr, pf)[0] is False)
Config.get("Equipe").get("Uniforme").set("ApresRegeneration", False)
Config.get("Equipe").get("Uniforme").set("shirt", 0)
changer_equipe(fr, CAT)
pf.m_SetAttribute("TardisRegeneration", None)
verifier("3. Identifiants à 0 : mettreUniforme ne fait rien, sans erreur", appel(SY.get("mettre"), fr, pf)[0] is False and not roblox.ERREURS, roblox.ERREURS[:2])
verifier("3. changerApparence (deux chemins) et la fin d'une régénération appellent uniformeApresRegeneration",
         systemes.count("uniformeApresRegeneration(joueur, personnage) -- (V6.9.14)") == 3
         and entre(systemes, "local function changerApparence(", "local enAttente = {}").count("uniformeApresRegeneration(joueur, personnage)") == 2)
Config.get("Equipe").get("Uniforme").set("shirt", 5001)
tache(lambda: R.update(SY2=premier(I.executer(code_r, "uniformes-2", (Config, Table({"Nom": "TARDIS_2"}), ATTENTE, Fonction("estRegenerateur", py=lambda j: [False]))))))
gus = Instance("Player", "Gus", Players); gus.props.update({"UserId": 17, "Team": CAT})
gus.extra["HasAppearanceLoaded"] = Fonction("HasAppearanceLoaded", py=lambda _s: [True])
pg_, hg = personnage_de(gus, "Gus")
tache(lambda: appel(R["SY2"].get("surveiller"), gus, pg_)); H.avancer(1)
changer_equipe(gus, VIS); changer_equipe(gus, CAT); H.avancer(1)
verifier("3. Garde « premier TARDIS » : l'exemplaire d'un autre TARDIS ne met pas l'uniforme (un seul serveur s'en charge)",
         habits(pg_) == ("rbxassetid://1111", "rbxassetid://2222"), habits(pg_))
verifier("3. Aucune erreur (uniformes)", not roblox.ERREURS, roblox.ERREURS[:3])

# ================================================================== 4. Le vrai client : casier rangé par catégorie (module Interactions)
CONSOLE = "StarterPlayer/StarterPlayerScripts/TardisExtrasClient/"
vider_cache(); roblox.ERREURS.clear()
I, G, game, joueur = monde(serveur=False)
activer_maths(G)
rs = game.m_FindFirstChild("ReplicatedStorage"); ws = game.m_FindFirstChild("Workspace")
remote = Instance("RemoteEvent", "TardisCommande_TARDIS_1", rs)
tache(lambda: R.update(Config=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisConfig")])), UI=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisUI")]))))
Config, UI = R["Config"], R["UI"]; TEN = Config.get("Tenues")
pg = Instance("PlayerGui", "PlayerGui", joueur)
joueur.attrs["TardisPilote_TARDIS_1"] = True
uis = game.m_FindFirstChild("UserInputService"); uis.extra["InputBegan"] = Signal("InputBegan")
camera = Instance("Camera", "Camera", ws)
camera.props.update({"CFrame": CF((0, 10, 14)), "CameraType": Valeur("Enum.CameraType.Custom"), "ViewportSize": Valeur("Vector2", [1920, 1080]), "CameraSubject": None})
ws.props["CurrentCamera"] = camera
ws.extra["Raycast"] = Fonction("Raycast", py=lambda *a: [None])
ext = Instance("Model", "Cabine"); ext.attrs.update({"Etat": "Pose", "Position": "Hall", "Mode": "Normal", "Alimentation": True})
salle = Instance("Model", "Salle", ws)
console = Instance("Model", "Console", salle)
casier = Instance("Model", "Casier", console); piece("Porte", casier, (-4, 3, 0), (2, 3, 0.2))
joueur.props["Team"] = Instance("Team", "C.A.T.")
perso = Instance("Model", "Moi", ws); hum = Instance("Humanoid", "Humanoid", perso)
piece("Head", perso, (0, 4.5, 0), (2, 1, 1)); racine = piece("HumanoidRootPart", perso, (0, 3, 0), (2, 2, 1))
Instance("Shirt", "Shirt", perso).props["ShirtTemplate"] = "rbxassetid://1111"; Instance("Pants", "Pants", perso).props["PantsTemplate"] = "rbxassetid://2222"
joueur.props["Character"] = perso; camera.props["CameraSubject"] = hum
dossierT = Instance("Folder", "Tenues", Instance("Folder", "TardisAssets", rs))
for i in range(1, TEN.longueur() + 1):
    t_ = TEN.get(i)
    if t_.get("shirt"): dossierT.attrs["Shirt_%d" % t_.get("shirt")] = "rbxassetid://%d" % (70000 + i)
    if t_.get("pant"): dossierT.attrs["Pants_%d" % t_.get("pant")] = "rbxassetid://%d" % (80000 + i)
ctx = Table({"C": UI.get("C"), "Config": Config, "E": Config.get("Etats"), "Players": game.m_FindFirstChild("Players"), "UI": UI,
             "UserInputService": uis, "animer": UI.get("animer"), "camera": camera, "creer": UI.get("creer"), "texte": UI.get("texte"),
             "def": Config.get("Tardis").get(1), "exterieur": ext, "interieur": salle, "joueur": joueur,
             "maRacine": Fonction("maRacine", py=lambda: racine), "remote": remote, "jeSuisDedans": Fonction("dedans", py=lambda: True)})
tache(lambda: R.update(IM=premier(appeler(premier(I.executer(interactions, "Interactions")), [ctx])))); H.avancer(0.05)
verifier("4. Vrai module Interactions chargé, sans erreur", not roblox.ERREURS, roblox.ERREURS[:3])
prompt = [e for e in descendants(casier) if e.ClassName == "ProximityPrompt"][0]
def ouvrir():
    uis.extra["InputBegan"].declencher(Table({"KeyCode": Valeur("Enum.KeyCode.Escape")}), False); H.avancer(0.3)
    declencher(prompt, "Triggered"); H.avancer(0.3)
    return pg.m_FindFirstChild("TardisCasier")
cgui = ouvrir()
liste = trouve(cgui, "Tenues")
def blocs():
    return sorted([e for e in liste.enfants if e.ClassName != "UIListLayout"], key=lambda e: e.props["LayoutOrder"])
def tuiles(): return sorted(tous(liste, "Tenue"), key=lambda e: e.props["LayoutOrder"])
def nom_tuile(t): return texte_de(trouve(t, "Nom"))
def resume():
    """[(en-tête, [noms des tuiles du groupe])] dans l'ordre affiché"""
    res, b = [], blocs()
    for k in range(0, len(b) - 1, 2):
        if b[k].Name == "Entete" and b[k + 1].Name == "Groupe":
            res.append((texte_de(b[k]), [nom_tuile(t) for t in sorted(enfants(b[k + 1], "Tenue"), key=lambda e: e.props["LayoutOrder"])]))
    return res
r0 = resume()
verifier("4. La liste empile les groupes (UIListLayout) : un en-tête puis sa grille de deux colonnes de 80 px",
         enfants(liste, classe="UIListLayout") and not enfants(liste, classe="UIGridLayout")
         and all(enfants(g, classe="UIGridLayout") and enfants(g, classe="UIGridLayout")[0].props["CellSize"].args[3] == 80 for g in enfants(liste, "Groupe")), [e.Name for e in blocs()])
verifier("4. Groupes dans l'ordre de Config.Tenues : FESTIVE, COMITÉ D'ÉTHIQUE, RESSOURCES HUMAINES, BUREAU DE L'ADMIN (nombre de tenues)",
         r0 == [("FESTIVE  ·  3", ["PANNARO", "AZZURRO REGALE", "CANARD"]), ("COMITÉ D'ÉTHIQUE  ·  2", ["ABETE", "BOSCO"]),
                ("RESSOURCES HUMAINES  ·  1", ["CORDE"]), ("BUREAU DE L'ADMIN  ·  3", ["FAUSTO", "VITTORIO", "BLUASTRO"])], r0)
verifier("4. Les 5 tenues en attente (identifiants à 0) ne sont pas montrées, pas de groupe vide (Voyage, Technique)",
         len(tuiles()) == 9 and not any(n in [nom_tuile(t) for t in tuiles()] for n in ("CHRONOS", "NEBULA", "ATELIER", "SOUDEUR", "GALA")))
verifier("4. Groupe noté par l'attribut Categorie", [g.attrs.get("Categorie") for g in sorted(enfants(liste, "Groupe"), key=lambda e: e.props["LayoutOrder"])]
         == ["Festive", "Comité d'Éthique", "Ressources Humaines", "Bureau de l'Admin"])
corde = next(t for t in tuiles() if nom_tuile(t) == "CORDE")
appuyer(trouve(corde, "Favori")); H.avancer(0.1)
r1 = resume()
verifier("4. Corde en favori : un groupe FAVORIS (ambre) en tête, Ressources Humaines (vide) disparaît, gardé dans les préférences",
         r1[0] == ("FAVORIS  ·  1", ["CORDE"]) and all(not e[0].startswith("RESSOURCES") for e in r1) and UI.get("prefs").get("tenuesFavorites").get("3") is True
         and blocs()[0].props["TextColor3"] is UI.get("C").get("ambre") and nom_tuile(tuiles()[0]) == "CORDE", r1)
ENVOIS = []
remote.extra["FireServer"] = Fonction("FireServer", py=lambda _s, *a: ENVOIS.append(a) or [])
appuyer(tuiles()[0]); appuyer(trouve(cgui, "Enfiler")); H.avancer(0.1)
verifier("4. Enfiler la tuile favorite : l'action EXISTANTE « Tenue » avec le numéro de la tenue dans Config.Tenues (3)",
         [(a[0], a[1].get("index")) for a in ENVOIS if a[0] == "Tenue"] == [("Tenue", 3)], [(a[0],) for a in ENVOIS])
TEN.get(10).set("shirt", 9010); TEN.get(10).set("pant", 9011)
cgui = ouvrir(); liste = trouve(cgui, "Tenues")
r2 = resume()
verifier("4. Identifiants donnés à Chronos (tenue 10) : elle apparaît dans un groupe VOYAGE, après les autres",
         r2[-1] == ("VOYAGE  ·  1", ["CHRONOS"]) and len(tuiles()) == 10, r2)
TEN.get(10).set("shirt", 0); TEN.get(10).set("pant", 0)
TEN.get(2).set("categorie", None)
cgui = ouvrir(); liste = trouve(cgui, "Tenues")
verifier("4. Une tenue sans catégorie va dans « AUTRES », à la fin", resume()[-1] == ("AUTRES  ·  1", ["ABETE"]), resume())
Config.set("Tenues", Table({1: Table({"nom": "Vide", "shirt": 0, "pant": 0})}))
cgui = ouvrir(); liste = trouve(cgui, "Tenues")
verifier("4. Aucune tenue disponible : un mot (« Aucune tenue dans ce casier »), aucune tuile, sans erreur",
         trouve(liste, "AucuneTenue") is not None and not tuiles() and not roblox.ERREURS, roblox.ERREURS[:3])

# ================================================================== 5. Le vrai client : badges des équipes (module Badges)
def monde_badges(defTardis=None, reglages=None):
    vider_cache(); roblox.ERREURS.clear()
    I, G, game, joueur = monde(serveur=False)
    activer_maths(G)
    rs = game.m_FindFirstChild("ReplicatedStorage")
    res = {}
    tache(lambda: res.update(Config=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisConfig")])), UI=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisUI")]))))
    Config, UI = res["Config"], res["UI"]
    for (equipe, cle), v in (reglages or {}).items(): Config.get(equipe).set(cle, v)
    Players = game.m_FindFirstChild("Players")
    joueur.props["Team"] = Instance("Team", "C.A.T.")
    ENV = []
    remote = Instance("RemoteEvent", "TardisCommande_TARDIS_1", rs); remote.extra["FireServer"] = Fonction("FireServer", py=lambda _s, *a: ENV.append(a) or [])
    def perso_de(j):
        p = Instance("Model", j.Name, game.m_FindFirstChild("Workspace")); piece("Head", p, (0, 4.5, 0), (2, 1, 1)); j.props["Character"] = p; return p
    perso_de(joueur)
    autres = {}
    for nom, equipe in (("Bob", "C.A.T."), ("Tess", "C.T.A.T."), ("Vic", "Visiteurs"), ("Sam", None)):
        j = Instance("Player", nom, Players); j.props.update({"UserId": len(autres) + 50, "Team": Instance("Team", equipe) if equipe else None,
                                                               "TeamColor": Table({"Color": "couleur-" + str(equipe)})})
        perso_de(j); autres[nom] = j
    ctxB = Table({"C": UI.get("C"), "Config": Config, "Players": Players, "UI": UI, "creer": UI.get("creer"), "def": defTardis or Config.get("Tardis").get(1),
                  "joueur": joueur, "texte": UI.get("texte")})
    tache(lambda: res.update(B=premier(appeler(premier(I.executer(badges, "Badges")), [ctxB])))); H.avancer(0.05)
    return dict(game=game, joueur=joueur, Players=Players, autres=autres, B=res.get("B"), perso_de=perso_de, ENV=ENV, Config=Config)
def badge_de(j):
    tete = j.props.get("Character") and j.props["Character"].m_FindFirstChild("Head")
    return [e for e in tete.enfants if e.Name == "TardisBadge"] if tete else []
WB = monde_badges()
A = WB["autres"]
bb = badge_de(A["Bob"])
verifier("5. Vrai module Badges chargé (premier TARDIS), sans erreur", WB["B"] is not None and not roblox.ERREURS, roblox.ERREURS[:3])
verifier("5. Bob (C.A.T.) : un BillboardGui « TardisBadge » sur la tête, texte « C.A.T. » à la couleur de sa Team, sans image",
         len(bb) == 1 and bb[0].ClassName == "BillboardGui" and bb[0].props.get("Adornee") is A["Bob"].props["Character"].m_FindFirstChild("Head")
         and texte_de(trouve(bb[0], "Texte")) == "C.A.T." and trouve(bb[0], "Texte").props.get("TextColor3") == "couleur-C.A.T." and trouve(bb[0], "Embleme") is None
         and bb[0].attrs.get("Equipe") == "C.A.T.", [e.Name for e in descendants(bb[0])] if bb else None)
verifier("5. … lisible de près seulement (60 studs), au-dessus de la tête, pas à travers les murs", bb and bb[0].props.get("MaxDistance") == 60 and bb[0].props.get("AlwaysOnTop") is False)
verifier("5. Tess (C.T.A.T.) : badge « C.T.A.T. » ; Vic (Visiteurs) et Sam (sans équipe) : aucun badge ; le joueur lui-même : aucun",
         [texte_de(trouve(b, "Texte")) for b in badge_de(A["Tess"])] == ["C.T.A.T."] and not badge_de(A["Vic"]) and not badge_de(A["Sam"]) and not badge_de(WB["joueur"]))
changer_equipe(A["Bob"], Instance("Team", "C.T.A.T."))
verifier("5. Bob passe à la C.T.A.T. : le badge suit la Team (un seul badge, « C.T.A.T. »)", [texte_de(trouve(b, "Texte")) for b in badge_de(A["Bob"])] == ["C.T.A.T."])
changer_equipe(A["Bob"], Instance("Team", "Visiteurs"))
verifier("5. Bob quitte les équipes : badge retiré", not badge_de(A["Bob"]))
changer_equipe(A["Vic"], Instance("Team", "C.A.T."))
verifier("5. Vic rejoint la C.A.T. : badge posé", [texte_de(trouve(b, "Texte")) for b in badge_de(A["Vic"])] == ["C.A.T."])
neuf = WB["perso_de"](A["Tess"]); declencher(A["Tess"], "CharacterAdded", neuf); H.avancer(0.1)
verifier("5. Nouveau personnage (réapparition) : le badge est reposé sur la nouvelle tête", len(badge_de(A["Tess"])) == 1)
zoe = Instance("Player", "Zoe", WB["Players"]); zoe.props.update({"UserId": 99, "Team": Instance("Team", "C.A.T."), "TeamColor": Table({"Color": "c"})}); WB["perso_de"](zoe)
declencher(WB["Players"], "PlayerAdded", zoe)
verifier("5. Un joueur qui arrive : suivi, badge posé", len(badge_de(zoe)) == 1)
declencher(WB["Players"], "PlayerRemoving", zoe); changer_equipe(zoe, Instance("Team", "Visiteurs"))
verifier("5. Un joueur qui part : plus suivi (connexions retirées), aucune erreur", len(badge_de(zoe)) == 1 and not roblox.ERREURS, roblox.ERREURS[:3])
verifier("5. Aucun envoi au serveur (le badge est fait chez chaque joueur d'après la Team)", not WB["ENV"] and "FireServer" not in badges and "remote" not in badges)
WB = monde_badges(reglages={("Equipe", "BadgeImage"): 4242})
bb = badge_de(WB["autres"]["Bob"])
verifier("5. Config.Equipe.BadgeImage = 4242 : emblème « rbxassetid://4242 » à gauche du texte",
         bb and trouve(bb[0], "Embleme") is not None and trouve(bb[0], "Embleme").props.get("Image") == "rbxassetid://4242"
         and trouve(bb[0], "Embleme").props["LayoutOrder"] < trouve(bb[0], "Texte").props["LayoutOrder"])
WB = monde_badges(reglages={("EquipeTechnique", "Badge"): False})
verifier("5. Config.EquipeTechnique.Badge = false : aucun badge C.T.A.T., celui de la C.A.T. reste", not badge_de(WB["autres"]["Tess"]) and len(badge_de(WB["autres"]["Bob"])) == 1)
WB = monde_badges(defTardis=Table({"Nom": "TARDIS_2"}))
verifier("5. Garde « premier TARDIS » : l'exemplaire d'un autre TARDIS ne pose rien (un seul badge par tête)",
         WB["B"] is None and not badge_de(WB["autres"]["Bob"]) and not roblox.ERREURS, roblox.ERREURS[:3])

# ================================================================== 6. Portes intérieures (vrai TardisPortail, section extraite)
section = entre(portail, "local portesInt = interieur:FindFirstChild(NOM_PORTES_INT)", "--------------------------------------------------------------------\n-- Passage sans coupure")
ouverte = entre(portail, "local function porteOuverte()", "\n\n")
# task.wait() sans durée attend une image (1/60 s) comme dans Roblox (l'horloge de la simulation reprendrait aussitôt)
code_p = ("local Config, E, def, exterieur, interieur, dossierPortes, SEUIL_PORTES, NOM_PORTES_INT = ...\n"
          "local task_ = task\nlocal task = { wait = function(d) return task_.wait(d or 1 / 60) end, spawn = task_.spawn }\n" + ouverte + "\n" + section
          + "\nreturn battantsAnimes\n")
def monde_portes(rangement="animé", valeurs=True, angle=None):
    vider_cache(); roblox.ERREURS.clear(); roblox.SORTIE.clear()
    I, G, game, joueur = monde(serveur=False)
    activer_maths(G)
    rs = game.m_FindFirstChild("ReplicatedStorage")
    res = {}
    tache(lambda: res.update(Config=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisConfig")]))))
    Config = res["Config"]
    ext = Instance("Model", "Cabine"); ext.attrs.update({"Etat": "Pose", "Echelle": 1, "PorteOuverte": False})
    portes = Instance("Model", "TARDISDoors", ext)
    bv = {}
    if valeurs:
        for n in ("LeftOpen", "RightOpen"):
            bv[n] = Instance("BoolValue", n, portes); bv[n].props["Value"] = False
    salle = Instance("Model", "Salle")
    dossier = Instance("Folder", "PortesInterieures", salle)
    B = {}
    if rangement in ("animé", "gauche seule"):
        for nom, x in (("Gauche", -1), ("Droite", 1)):
            if rangement == "gauche seule" and nom == "Droite": continue
            m = Instance("Model", nom, dossier); m.props["Pivot"] = CF((x, 3, 0))
            piece("Charniere", m, (2 * x, 3, 0), (0.2, 6, 0.2)); bat = piece("Battant", m, (x, 3, 0), (2, 6, 0.2)); bat.props["CanCollide"] = True
            if angle is not None and nom == "Gauche": m.attrs["Angle"] = angle
            B[nom] = (m, bat)
    else:
        bat = piece("Battant", dossier, (0, 3, 0), (4, 6, 0.2)); bat.props.update({"CanCollide": True, "Transparency": 0}); B["seul"] = (None, bat)
    tache(lambda: res.update(BA=premier(I.executer(code_p, "portes-interieures", (Config, Config.get("Etats"), Config.get("Tardis").get(1), ext, salle, portes,
                                                                                 Config.get("TailleOuverturePortes") or 1, "PortesInterieures")))))
    H.avancer(0.1)
    return dict(ext=ext, bv=bv, B=B, BA=res.get("BA"), Config=Config)
def pos(m): return m.props["Pivot"].p
def proche(a, b, e=1e-3): return all(abs(x - y) <= e for x, y in zip(a, b))
def basculer(WP, n, v):
    WP["bv"][n].props["Value"] = v; WP["bv"][n].changed.declencher(); H.avancer(0.01)
s2 = math.sqrt(0.5)
WP = monde_portes()
(mg, bg), (md, bd) = WP["B"]["Gauche"], WP["B"]["Droite"]
verifier("6. Rangement Gauche / Droite avec Charniere : mode animé, battants fermés au départ, sans erreur",
         WP["BA"] is not None and proche(pos(mg), (-1, 3, 0)) and proche(pos(md), (1, 3, 0)) and not roblox.ERREURS, roblox.ERREURS[:3])
basculer(WP, "LeftOpen", True); H.avancer(0.2)
mi = pos(mg)
verifier("6. LeftOpen : le battant gauche commence à tourner autour de sa charnière, il ne bloque plus le passage",
         not proche(mi, (-1, 3, 0)) and not proche(mi, (-2, 3, -1)) and abs(math.dist(mi, (-2, 3, 0)) - 1) < 1e-6 and bg.props["CanCollide"] is False, (mi, bg.props["CanCollide"]))
H.avancer(0.6)
verifier("6. … en 0,5 s : ouvert de 90° (Gauche tourne de +90°), le battant droit n'a pas bougé (RightOpen faux)",
         proche(pos(mg), (-2, 3, -1)) and proche(pos(md), (1, 3, 0)) and bd.props["CanCollide"] is True, (pos(mg), pos(md)))
basculer(WP, "RightOpen", True); H.avancer(0.7)
verifier("6. RightOpen : le battant droit tourne de -90° (les deux s'ouvrent du même côté)", proche(pos(md), (2, 3, -1)) and bd.props["CanCollide"] is False, pos(md))
WP["ext"].m_SetAttribute("Etat", "Vol"); H.avancer(0.7)
verifier("6. TARDIS qui n'est plus posé : les deux battants se referment exactement, de nouveau solides",
         proche(pos(mg), (-1, 3, 0)) and proche(pos(md), (1, 3, 0)) and bg.props["CanCollide"] is True and bd.props["CanCollide"] is True, (pos(mg), pos(md)))
WP["ext"].m_SetAttribute("Etat", "Pose"); H.avancer(0.7)
verifier("6. Reposé (portes toujours ouvertes) : ils se rouvrent", proche(pos(mg), (-2, 3, -1)) and proche(pos(md), (2, 3, -1)))
WP["ext"].m_SetAttribute("Echelle", 0.2); H.avancer(0.7)
verifier("6. Porte trop petite (Echelle sous TailleOuverturePortes) : fermés", proche(pos(mg), (-1, 3, 0)) and proche(pos(md), (1, 3, 0)))
WP["ext"].m_SetAttribute("Echelle", 1); H.avancer(0.2)
basculer(WP, "LeftOpen", False); H.avancer(0.7)
verifier("6. Changement de sens en route, puis LeftOpen faux : le gauche se referme, le droit reste ouvert, aucune erreur",
         proche(pos(mg), (-1, 3, 0)) and proche(pos(md), (2, 3, -1)) and not roblox.ERREURS, (pos(mg), pos(md), roblox.ERREURS[:2]))
WP = monde_portes(valeurs=False, angle=-45)
(mg, bg), (md, bd) = WP["B"]["Gauche"], WP["B"]["Droite"]
WP["ext"].m_SetAttribute("PorteOuverte", True); H.avancer(0.7)
verifier("6. Sans LeftOpen / RightOpen : l'attribut PorteOuverte ouvre les deux ; attribut Angle = -45 sur Gauche (autre sens, 45°)",
         proche(pos(mg), (-2 + s2, 3, s2)) and proche(pos(md), (2, 3, -1)), (pos(mg), pos(md)))
WP["ext"].m_SetAttribute("PorteOuverte", False); H.avancer(0.7)
verifier("6. … PorteOuverte faux : refermés", proche(pos(mg), (-1, 3, 0)) and proche(pos(md), (1, 3, 0)) and not roblox.ERREURS)
WP = monde_portes(rangement="simple")
_, bs = WP["B"]["seul"]
WP["ext"].m_SetAttribute("PorteOuverte", True); H.avancer(0.1)
verifier("6. Sans rangement (Parts posées dans PortesInterieures) : le masquage d'avant (cachées et traversables porte ouverte)",
         WP["BA"] is None and bs.props["Transparency"] == 1 and bs.props["CanCollide"] is False and not [l for l in roblox.SORTIE if "PortesInterieures" in l])
WP["ext"].m_SetAttribute("PorteOuverte", False); H.avancer(0.1)
verifier("6. … porte fermée : rendues telles quelles", bs.props["Transparency"] == 0 and bs.props["CanCollide"] is True)
WP = monde_portes(rangement="gauche seule")
_, bgs = WP["B"]["Gauche"]
WP["ext"].m_SetAttribute("PorteOuverte", True); H.avancer(0.1)
verifier("6. Rangement incomplet (Gauche seule) : une ligne dans l'Output, et le masquage d'avant (rien ne casse)",
         WP["BA"] is None and len([l for l in roblox.SORTIE if "« Gauche » et « Droite »" in l]) == 1 and bgs.props["Transparency"] == 1 and not roblox.ERREURS,
         (roblox.SORTIE[-2:], roblox.ERREURS[:2]))
verifier("6. Le masquage ne touche que PortesInterieures (la Part Portail n'est pas cachée) et tout se passe chez le joueur",
         "NomPortailInt" not in section and "FireServer" not in section)

# ================================================================== 7. Le code
for chemin, src in (("TardisConfig", config_src), ("TardisSystemes", systemes), ("TardisExtras", extras), ("TardisTenues", tenues_src),
                    ("Interactions", interactions), ("Badges", badges), ("init.client", initclient), ("TardisPortail", portail)):
    verifier(f"7. {chemin} : ajouts marqués « (V6.9.14) »", "(V6.9.14)" in src)
verifier("7. Version 6.9.14 ou plus récente dans TardisConfig", version(Config.get("Version")) >= (6, 9, 14) and 'Config.Version = "' in config_src, Config.get("Version"))
verifier("7. init.client charge Badges (après ScannerTechnicien)",
         'require(script:WaitForChild("Badges"))' in initclient and initclient.index('"ScannerTechnicien"') < initclient.index('"Badges"'))
verifier("7. Le réglage du badge et de l'uniforme est dans TardisConfig, pas dans la tablette ni dans les préférences du joueur",
         "Badge" not in lire("StarterPlayer/StarterPlayerScripts/TardisTablette/Outils.lua").replace("BadgePlaque", "")
         and "prefs" not in badges and "ApresRegeneration" not in interactions)
verifier("7. Aucune nouvelle action réseau (le casier garde l'action « Tenue »)",
         sorted(set(re.findall(r'FireServer\("(\w+)"', interactions))) == sorted(set(re.findall(r'FireServer\("(\w+)"', interactions))) and not re.search(r'FireServer\("(Uniforme|Badge)', interactions + badges))

print("\n".join("  ✓ " + o for o in OK)); print("\n".join("  ✗ " + k for k in KO))
print(f"V6.9.14 : {len(OK)}/{len(OK) + len(KO)} vérifications réussies")
sys.exit(1 if KO else 0)
