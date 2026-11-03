"""Simulations de la V6.9.7 : le vrai code des fonctions corrigées, exécuté avec de faux objets Roblox.
  1. Vol libre (module VolLibre) : pilote qui n'envoie plus rien → le TARDIS se pose seul ; pilote qui part pendant
     qu'il est invisible → la cabine se rematérialise d'abord, puis se pose.
  2. Destinations (extrait de TardisServeur) : joueur visé parti pendant le vol → retour au lieu de départ, avec message.
  3. Poche en Silencieux (extrait de TardisServeur) : jouerSurPersonnage(nil) ne plante plus."""
import os, sys, re
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from monde import *
import roblox
OK, KO = [], []
def verifier(nom, condition, detail=""):
    (OK if condition else KO).append(nom + ("" if condition else "  →  " + str(detail)))

# ------------------------------------------------------------------ 1. Vol libre
I, G, game, joueur = monde(serveur=True)
R = {}
def charger():
    Config = premier(appeler(G["require"], [game.m_FindFirstChild("ReplicatedStorage").m_FindFirstChild("TardisConfig")]))
    R["Config"] = Config
lancer(Fonction("config", py=charger))
Config = R["Config"]; E = Config.get("Etats")
x = Instance("Model", "EXTERIEURE"); x.m_SetAttribute("Etat", E.get("Pose"))
racine = Instance("Part", "Racine", x); racine.props["Size"] = Valeur("Vector3", [4, 9, 4]); x.props["PrimaryPart"] = racine
partage = Table({"occupe": False})
appels = []
def stub(nom, retour=None):
    return Fonction(nom, py=lambda *a: appels.append(nom) or ([] if retour is None else [retour]))
ctx = Table({"Config": Config, "E": E, "Players": game.m_FindFirstChild("Players"), "exterieur": x, "interieur": Instance("Model", "INTERIEURE"),
             "partage": partage, "echelleNormale": 1, "hauteurNormale": 9,
             "chercherSol": Fonction("chercherSol", py=lambda *a: Valeur("Vector3", [0, 5, 0])),
             "dansInterieur": Fonction("dansInterieur", py=lambda *a: False),
             "emmenerALInterieur": stub("emmener"), "etatActuel": Fonction("etat", py=lambda: x.attrs.get("Etat")),
             "fermerPortes": Fonction("fermerPortes", py=lambda: True), "jouer": stub("jouer"), "majEcran": stub("majEcran"),
             "majRamassage": stub("majRamassage"), "memoriserDepart": stub("memoriserDepart"), "setCollisionsExterieur": stub("collisions"),
             "tropPetitPourLesPortes": Fonction("petit", py=lambda *a: False), "verifierEau": stub("eau"),
             "jouerVoyage": stub("jouerVoyage"), "modeAutorise": Fonction("modeAutorise", py=lambda m, p=None: m)})
src = open(DEPOT + "/ServerScriptService/TardisServeur/VolLibre.lua", encoding="utf-8").read()
def chargerVol():
    usine = premier(I.executer(src, "VolLibre"))
    R["V"] = premier(appeler(usine, [ctx]))
lancer(Fonction("vol", py=chargerVol))
V = R["V"]
verifier("Module VolLibre chargé", V is not None and not roblox.ERREURS, roblox.ERREURS[:2])
pilote = joueur
def tache(f): lancer(Fonction("t", py=f))
# a) Pilote qui envoie ses positions : rien ne se passe
tache(lambda: R.__setitem__("ok", premier(appeler(V.get("demarrerVolLibre"), [pilote]))))
verifier("Vol libre démarré", R.get("ok") is True and x.attrs.get("VolLibre") == 101, (R.get("ok"), x.attrs.get("VolLibre")))
for _ in range(20):
    tache(lambda: appeler(V.get("recevoirPositionVol"), [pilote, Valeur("CFrame", [0, 50, 0])]))
    H.avancer(0.5)
verifier("Pilote actif pendant 10 s : pas d'atterrissage automatique", x.attrs.get("VolLibre") == 101 and not V.get("volLibre").get("enDescente"), x.attrs.get("DescenteMode"))
# b) Pilote muet : au bout de 8 s, descente automatique, puis fin du vol et TARDIS libéré
H.avancer(7.0)
verifier("Muet depuis 7 s : pas encore de descente", not V.get("volLibre").get("enDescente"))
H.avancer(2.5)
verifier("Muet depuis plus de 8 s : descente automatique lancée", V.get("volLibre").get("enDescente") is True or x.attrs.get("VolLibre") is None, dict(x.attrs))
H.avancer(10)
verifier("Descente terminée : vol libre fini, TARDIS libre", x.attrs.get("VolLibre") is None and partage.get("occupe") is False, (x.attrs.get("VolLibre"), partage.get("occupe")))
# c) Pilote qui part pendant qu'il est invisible : rematérialisation d'abord
tache(lambda: R.__setitem__("ok2", premier(appeler(V.get("demarrerVolLibre"), [pilote]))))
verifier("Second vol libre démarré", R.get("ok2") is True, R.get("ok2"))
x.m_SetAttribute("VolPhase", "Invisible")
phases = []
x.m_GetAttributeChangedSignal("VolPhase").connecter(Fonction("p", py=lambda: phases.append(x.attrs.get("VolPhase")) or []))
tache(lambda: appeler(V.get("lancerDescente"), ["Douce", True]))
H.avancer(1)
verifier("Pilote parti invisible : la rematérialisation commence", "Remat" in phases, phases)
H.avancer(25)
verifier("Puis la cabine redevient visible avant de se poser", phases[:2] == ["Remat", "Visible"], phases)
verifier("Puis le vol libre se termine", x.attrs.get("VolLibre") is None and partage.get("occupe") is False, (x.attrs.get("VolLibre"), partage.get("occupe")))
verifier("Vol libre : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])

# ------------------------------------------------------------------ 2 et 3. Extraits de TardisServeur
roblox.ERREURS.clear()
I2, G2, game2, joueur2 = monde(serveur=True)
serveur = open(DEPOT + "/ServerScriptService/TardisServeur/init.server.lua", encoding="utf-8").read()
debut = serveur.index("-- Noms des joueurs partis pendant la session (V6.9.7)")
fin = serveur.index("-- Téléportation de poche :")
extrait = serveur[debut:fin]
prelude = '''
local Players = game:GetService("Players")
local precedent = { cf = "CF_DEPART", nom = "Pont" }
local dossierDestinations = Instance.new("Folder")
local function dansInterieur() return false end
local function cibleJoueur(j) if j.Character then return "CF_JOUEUR" end return nil, "JOUEUR SANS PERSONNAGE" end
local exterieur = Instance.new("Model")
local joues = {}
local sons = { Demat = { ext = Instance.new("Sound") } }
local function appliquerPortee() end
'''
fin_test = '''
return { resoudre = resoudreDestination, jouer = jouerSurPersonnage, partir = function(j) j.Parent = nil end }
'''
R2 = {}
def charger2():
    R2["m"] = premier(I2.executer(prelude + extrait + fin_test, "extrait-serveur"))
lancer(Fonction("extrait", py=charger2))
M = R2.get("m")
verifier("Extrait de TardisServeur exécuté", M is not None and not roblox.ERREURS, roblox.ERREURS[:2])
if M:
    joueurs = game2.m_FindFirstChild("Players")
    vise = Instance("Player", "Visé", joueurs); vise.props.update({"UserId": 202, "DisplayName": "Amy", "Character": Instance("Model", "Amy")})
    def resoudre(d, repli):
        res = {}
        lancer(Fonction("r", py=lambda: res.__setitem__("v", appeler(M.get("resoudre"), [d, True, repli]))))
        return (res["v"] + [None] * 6)[:6]
    v = resoudre(Table({"joueur": 202}), True)
    verifier("Joueur présent : destination sur lui", v[0] == "CF_JOUEUR" and v[5] is None, v)
    vise.props["Character"] = None
    v = resoudre(Table({"joueur": 202}), True)
    verifier("Joueur sans personnage, en vol : retour au départ avec message", v[0] == "CF_DEPART" and "n'a plus de personnage" in (v[5] or ""), v)
    vise.set_parent(None); joueurs.extra.setdefault("PlayerRemoving", Signal()).declencher(vise); H.avancer(0.1)
    v = resoudre(Table({"joueur": 202}), True)
    verifier("Joueur parti, en vol : retour à « Pont » avec « Amy a quitté le jeu »", v[0] == "CF_DEPART" and "Amy a quitté le jeu" in (v[5] or "") and v[1] == "Pont", v)
    v = resoudre(Table({"joueur": 202}), False)
    verifier("Joueur parti, posé (sans repli) : refus clair « Amy a quitté le jeu »", v[0] is None and v[4] == "Amy a quitté le jeu", v)
    v = resoudre(Table({"joueur": 999}), False)
    verifier("Joueur inconnu : « joueur introuvable »", v[0] is None and v[4] == "joueur introuvable", v)
    res = {}
    lancer(Fonction("j", py=lambda: res.__setitem__("ok", appeler(M.get("jouer"), [vise, None]) is not None)))
    verifier("Poche en Silencieux : jouerSurPersonnage(nil) ne plante plus", res.get("ok") is True and not roblox.ERREURS, roblox.ERREURS[:2])
print("\n".join("  ✓ " + o for o in OK)); print("\n".join("  ✗ " + k for k in KO))
print(f"V6.9.7 : {len(OK)} réussis, {len(KO)} échoués.")
