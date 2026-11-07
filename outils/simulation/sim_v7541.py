"""Simulations de la V7.5.4.1 (retours de test dans DEVMAP) : le vrai code, exécuté avec de faux objets Roblox.
  1. TardisConfig : poses du kit (poseKit, cframePose, pieceBouge, douceur), alarme (25 %), panneau 1, invite du vol
     libre posée sur les dalles, écran de l'énergie presque plein écran.
  2. Sources : serveur (poses du levier et du bouton du démarrage, alarme copiée dans TardisAssets › Sons, action
     BouclierDouble, clics du panneau 1 sans la Cloche), client (alarme bornée, écran de l'énergie en trois pages)."""
import os, sys, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from monde import *
import roblox
from roblox import Vec3, CF, activer_maths
OK, KO = [], []
def verifier(nom, condition, detail=""):
    (OK if condition else KO).append(nom + ("" if condition else "  →  " + str(detail)))
def tache(f): lancer(Fonction("t", py=f))
def lire(chemin): return open(os.path.join(DEPOT, chemin), encoding="utf-8").read()
def vider_cache(): roblox.charger_module.__defaults__[0].clear()
def proche(a, b, e=1e-6): return a is not None and b is not None and abs(float(a) - float(b)) <= e
def L(t, n=6): return [t.get(i) for i in range(1, n + 1) if t is not None and t.get(i) is not None]
def T(liste): return roblox.Table({i + 1: v for i, v in enumerate(liste)}) if hasattr(roblox, "Table") else __import__("luau").Table({i + 1: v for i, v in enumerate(liste)})
def dist(a, b): return math.sqrt(sum((x - y) ** 2 for x, y in zip(a.t(), b.t())))

# ================================================================== 1. TardisConfig
vider_cache()
I, G, game, joueur = monde(serveur=False)
activer_maths(G)
rs = game.m_FindFirstChild("ReplicatedStorage")
R = {}
tache(lambda: R.update(Config=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisConfig")]))))
Config = R["Config"]
f = lambda nom, *a: premier(appeler(Config.get(nom), list(a)))
CFn = lambda *a: premier(appeler(G["CFrame"].h["new"], list(a)))
CFaa = lambda axe, ang: premier(appeler(G["CFrame"].h["fromAxisAngle"], [axe, ang]))

verifier("Config.Version ≥ 7.5.4.1", tuple(int(n) for n in Config.get("Version").split(".")) >= (7, 5, 4, 1), Config.get("Version"))
verifier("Invite « Vol libre » posée sur les dalles de verre colorées (HauteurInvite 0,05)",
         proche(Config.get("BoutonVolLibre").get("HauteurInvite"), 0.05))
CC = Config.get("CommandesConsole")
PK = CC.get("PosesKit")
verifier("Poses du kit : levier Matlever › Fly / Land, démarrage Power › On / Off",
         L(PK.get("Levier").get("Visible")) == ["Controls", "Matlever", "Fly"] and L(PK.get("Levier").get("Autre")) == ["Controls", "Matlever", "Land"]
         and L(PK.get("Demarrage").get("Visible")) == ["Controls", "Power", "On"] and L(PK.get("Demarrage").get("Autre")) == ["Controls", "Power", "Off"],
         PK)
verifier("Durée de la pose 0,6 s, bouton du démarrage animé, clic du panneau 1 actif",
         proche(CC.get("DureePose"), 0.6) and CC.get("PoseDemarrage") is True and CC.get("PanneauClic") is True)
P1 = CC.get("Panneau1")
verifier("Panneau 1 : Bouclier, Siege, Cloak sous Console › Panel 1 ; la Cloche n'y est pas",
         all(L(P1.get(k)) == ["Console", "Panel 1", k] for k in ("Bouclier", "Siege", "Cloak")) and P1.get("Cloche") is None)
verifier("Le bouton Bouclier lève les deux boucliers (anti-joueurs et anti-balles)", L(CC.get("BoucliersPanneau")) == ["Joueurs", "Balles"])
AL = Config.get("Alarme")
verifier("Alarme : son du kit Rotor › Rotor › Warning1, volume au plus 25 %, ancienne alarme coupée",
         L(AL.get("Source")) == ["Rotor", "Rotor", "Warning1"] and proche(AL.get("VolumeMax"), 0.25) and AL.get("CouperAncienne") is True)
verifier("Écran de l'énergie : échelle jusqu'à 1,5 (presque plein écran)", proche(Config.get("EcranIngenieur").get("EchelleMax"), 1.5))

# --- poses du kit : un levier qui tourne de 40° autour d'un axe X passant par (2, 3, 4)
def compose(*cfs):
    r = cfs[0]
    for c in cfs[1:]: r = r.fois(c)
    return r
M = compose(CFn(2, 3, 4), CFaa(Vec3(1, 0, 0), math.radians(40)), CFn(-2, -3, -4))
bout = CFn(2, 6, 4)          # bout beige
bras = CFn(2.5, 4.5, 4.2)    # bras blanc
ampoule = CFn(5, 3, 9)       # ampoule : ne bouge pas
bout2, bras2 = M.fois(bout), M.fois(bras)
pose = f("poseKit", bout, bout2)
verifier("poseKit trouve l'axe (X) et l'angle (40°) entre les deux poses",
         pose is not None and proche(abs(pose.get("axe").x), 1, 1e-6) and proche(pose.get("angle"), math.radians(40), 1e-6), pose)
verifier("poseKit : pas de glissement le long de l'axe pour une rotation pure", pose is not None and pose.get("glisse").t()[0] ** 2 < 1e-9)
fin = f("cframePose", bras, pose, 1)
verifier("cframePose(…, 1) amène le bras blanc pile sur sa pose cachée (même mouvement que le bout)",
         fin is not None and dist(fin.__lua_index__("Position"), bras2.__lua_index__("Position")) < 1e-6)
verifier("cframePose(…, 0) laisse la pièce où elle est", dist(f("cframePose", bras, pose, 0).__lua_index__("Position"), bras.__lua_index__("Position")) < 1e-9)
mi = f("cframePose", bout, pose, 0.5).__lua_index__("Position")
verifier("À mi-course, le bout reste à la même distance de l'axe (il tourne, il ne coupe pas)",
         proche(math.hypot(mi.y - 3, mi.z - 4), 3, 1e-6), mi.t())
pos = [bout2.__lua_index__("Position"), bras2.__lua_index__("Position")]
positions = T(pos)
verifier("pieceBouge : le bout et le bras bougent (ils tombent sur la pose cachée)",
         f("pieceBouge", bout, pose, positions, 0.05) is True and f("pieceBouge", bras, pose, positions, 0.05) is True)
verifier("pieceBouge : l'ampoule ne bouge pas (rien de la pose cachée à son arrivée)", f("pieceBouge", ampoule, pose, positions, 0.05) is False)
verifier("pieceBouge : une pièce sur l'axe reste en place", f("pieceBouge", CFn(9, 3, 4), pose, T(pos + [Vec3(9, 3, 4)]), 0.05) is False)
verifier("poseKit : deux poses identiques → nil (rien à animer)", f("poseKit", bout, bout) is None)
# bouton du démarrage : rotation vers la droite (axe Z) avec un léger glissement
M2 = compose(CFn(0, 0, 0.3), CFn(1, 1, 0), CFaa(Vec3(0, 0, 1), math.radians(-30)), CFn(-1, -1, 0))
b0 = CFn(1, 2, 0); b1 = M2.fois(b0)
p2 = f("poseKit", b0, b1)
verifier("poseKit (vis) : rotation de 30° autour de Z et glissement de 0,3 le long de l'axe",
         p2 is not None and proche(p2.get("angle"), math.radians(30), 1e-6) and proche(abs(p2.get("glisse").t()[2]), 0.3, 1e-6), p2)
autre = CFn(1.4, 1.6, 0)
verifier("cframePose (vis) : chaque pièce suit le même mouvement que la pièce cliquable",
         dist(f("cframePose", autre, p2, 1).__lua_index__("Position"), M2.fois(autre).__lua_index__("Position")) < 1e-6)
verifier("douceur : 0 → 0, 0,5 → 0,5, 1 → 1, bornée",
         proche(f("douceur", 0), 0) and proche(f("douceur", 0.5), 0.5) and proche(f("douceur", 1), 1) and proche(f("douceur", 3), 1) and proche(f("douceur", -1), 0))
verifier("douceur : début et fin lents", f("douceur", 0.1) < 0.1 and f("douceur", 0.9) > 0.9)

# ================================================================== 2. Sources
srv = lire("ServerScriptService/TardisServeur/init.server.lua")
verifier("Serveur : le levier suit sa pose (baissé au décollage) quand le kit a la pose Land, sinon l'ancienne bascule",
         "local poseLevier = reglages.LevierVol ~= false and lirePose(\"Levier\") or nil" in srv
         and "allerPose(poseLevier, Config.levierVolBaisse(etatActuel()) and 1 or 0)" in srv
         and "if not poseLevier and reglages.LevierVol ~= false and levier and levier.Parent then" in srv)
verifier("Serveur : le bouton du démarrage tourne vers Off quand le démarrage est bloqué",
         "allerPose(poseDemarrage, exterieur:GetAttribute(\"DemarrageBloque\") == true and 1 or 0)" in srv
         and "exterieur:GetAttributeChangedSignal(\"DemarrageBloque\"):Connect(majPoseDemarrage)" in srv)
verifier("Serveur : toutes les pièces qui retombent sur la pose cachée bougent ensemble (bout + bras)",
         "objet == a or Config.pieceBouge(objet.CFrame, pose, positions, 0.05)" in srv and "part.CFrame = Config.cframePose(base, info.pose, x)" in srv)
verifier("Serveur : l'alarme du kit est copiée dans TardisAssets › Sons › Alarme (boucle, volume ≤ 25 %)",
         "alarme.Name = \"Alarme\"" in srv and "alarme.Looped = true" in srv and "alarme.Volume = math.min(alarme.Volume, maxi)" in srv)
verifier("Serveur : l'ancien script Warning reste éteint (une seule alarme)",
         "ancien.Enabled = false" in srv and "if ancien.Enabled then ancien.Enabled = false end" in srv)
verifier("Serveur : action BouclierDouble (les deux s'allument si l'un est éteint, sinon les deux s'éteignent)",
         "elseif action == \"BouclierDouble\" then" in srv and "basculerBouclier(t)" in srv
         and srv.index("elseif action == \"BouclierDouble\" then") < srv.index("elseif action == \"Siege\" then"))
verifier("Serveur : clic du panneau 1 (Bouclier → BouclierDouble, Siege, Cloak → Camouflage), passé par traiterOrdre",
         "local ACTIONS_PANNEAU = { Bouclier = \"BouclierDouble\", Siege = \"Siege\", Cloak = \"Camouflage\" }" in srv
         and "traiterOrdre(joueur, action)" in srv and "cle ~= \"Cloche\"" in srv)
amb = lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Ambiance.lua")
verifier("Client : l'alarme attend le son copié par le serveur et reste bornée à 25 %",
         "sons:WaitForChild(\"Alarme\", 10)" in amb and "math.min(alarme.Volume, tonumber((Config.Alarme or {}).VolumeMax) or 0.25)" in amb)
con = lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Console.lua")
verifier("Écran de l'énergie : 1120 × 760, pages de 540 px, plafond d'échelle propre au panneau",
         "local LARGEUR_ENERGIE, HAUTEUR_ENERGIE = 1120, 760" in con and "local HAUTEUR_COLONNES = 540" in con
         and "math.clamp(math.min(taille.X * 0.92 / p.largeur, taille.Y * 0.86 / p.hauteur), 0.5, p.maxi)" in con)
verifier("Écran de l'énergie : trois onglets (État & régulation, Systèmes, Diagnostic)",
         "{ cle = \"Etat\", nom = \"État & régulation\" }, { cle = \"Systemes\", nom = \"Systèmes\" }, { cle = \"Diagnostic\", nom = \"Diagnostic\" }" in con)
verifier("Page Systèmes : neuf cartes", all(("carte(grilleCartes, \"%s\"" % c) in con for c in
         ("boucliers", "alimentation", "alerte", "siege", "camouflage", "portes", "voyage", "demarrage", "equipage")))
verifier("Page Diagnostic : marche à suivre pour chaque panne, environnement et bilan",
         con.count("ajouter(\"") >= 8 and "ligne.conseil.Text" in con and "jaugesEnv[sys[1]]" in con and "bilan.Text" in con)
verifier("majEnergie met aussi à jour les pages 2 et 3", "majSystemes()\n\t\tmajDiagnostic()" in con)
verifier("Les autres panneaux gardent leur plafond d'échelle de 1,15", "maxi = echelleMax or 1.15" in con)

print(f"V7.5.4.1 : {len(OK)}/{len(OK) + len(KO)} vérifications réussies")
for k in KO: print("  ÉCHEC :", k)
sys.exit(1 if KO else 0)
