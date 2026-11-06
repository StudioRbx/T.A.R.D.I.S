"""Simulations de la V6.9.10.9 : le leurre disparaît à chaque départ du TARDIS (le vrai code de TardisExtras).
  1. Le vrai bloc « Leurre » de TardisExtras : création du faux TARDIS (nom TardisLeurre_<TARDIS>), puis retrait
     automatique à la dématérialisation (Etat = Demat), au début du vol libre (attribut VolLibre) et au saut en vol libre
     (VolPhase = Demat) ; rien ne bouge à l'atterrissage ou pendant le vol ; retrait à la main et minuterie de 90 s
     toujours là.
  2. La tablette (Outils) cherche le leurre sous son vrai nom (TardisLeurre_<TARDIS>) : la tuile passe à « ACTIF ·
     retirer » et le bouton le retire."""
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

extras = lire("ServerScriptService/TardisExtras.server.lua")
outils = lire("StarterPlayer/StarterPlayerScripts/TardisTablette/Outils.lua")

# ================================================================== 1. Vrai bloc du leurre
roblox.charger_module.__defaults__[0].clear(); roblox.ERREURS.clear()
I, G, game, pilote = monde(serveur=True)
rs = game.m_FindFirstChild("ReplicatedStorage")
tache(lambda: R.update(Config=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisConfig")]))))
Config = R["Config"]
verifier("1. Vrai TardisConfig chargé, version 6.9.10.9", Config.get("Version") == "6.9.10.9" and not roblox.ERREURS, (Config.get("Version"), roblox.ERREURS[:3]))

debut = extras.index("local leurre = nil")
fin = extras.index("-- Personnalisation : couleur de la cabine")
bloc = extras[debut:fin]
ws = game.m_FindFirstChild("Workspace")
ext = Instance("Model", "EXTERIEURE", ws); ext.attrs.update({"Etat": "Pose"})
Instance("Part", "Corps", ext)
prelude = """
local exterieur, Config, def = ...
local E = Config.Etats
"""
code = prelude + bloc + "\nreturn creerLeurre, retirerLeurre"
R.clear()
tache(lambda: R.update(f=I.executer(code, "leurre", (ext, Config, Table({"Nom": "TARDIS_1"})))))
creer, retirer = R["f"][0], R["f"][1]
verifier("1. Bloc du leurre chargé sans erreur", creer is not None and not roblox.ERREURS, roblox.ERREURS[:3])
NOM = "TardisLeurre_TARDIS_1"
def leurre(): return ws.m_FindFirstChild(NOM)
def deployer():
    tache(lambda: appeler(creer, [roblox.CF((10, 0, 10))])); H.avancer(0.1)
def attr(n, v): ext.m_SetAttribute(n, v); H.avancer(3)
def depart(n, v):
    avant = leurre() is not None
    attr(n, v)
    return avant and leurre() is None

deployer()
verifier("1. Leurre déployé dans le Workspace (TardisLeurre_TARDIS_1, attribut Leurre)", leurre() is not None and leurre().attrs.get("Leurre") is True)
verifier("1. Dématérialisation : le leurre disparaît", depart("Etat", "Demat"))

attr("Etat", "Vol"); attr("Etat", "Remat"); attr("Etat", "Pose")
deployer(); attr("Etat", "Vol")
verifier("1. Déployé pendant le vol : il reste (seul un départ le retire)", leurre() is not None)
attr("Etat", "Remat"); attr("Etat", "Pose")
verifier("1. Atterrissage : le leurre reste", leurre() is not None)
verifier("1. Départ suivant : retiré", depart("Etat", "Demat"))
attr("Etat", "Pose")

deployer()
verifier("1. Début du vol libre : le leurre disparaît", depart("VolLibre", 101))
deployer(); attr("VolPhase", "Invisible")
verifier("1. Vol libre en cours (VolPhase autre que Demat) : il reste", leurre() is not None)
verifier("1. Saut dans le vortex en vol libre (VolPhase = Demat) : retiré", depart("VolPhase", "Demat"))
attr("VolPhase", None); attr("VolLibre", None)
deployer(); H.avancer(3)
verifier("1. Fin du vol libre (VolLibre retiré) : le leurre déployé ensuite reste", leurre() is not None)

tache(lambda: appeler(retirer, [])); H.avancer(3)
verifier("1. Retrait à la main toujours possible", leurre() is None)
deployer(); H.avancer(60); encore = leurre() is not None; H.avancer(33)
verifier("1. Minuterie de 90 s toujours là", encore and leurre() is None)
verifier("1. Fondu de sortie gardé (attribut Disparition, puis destruction après 2,5 s)", 'ancien:SetAttribute("Disparition", true)' in bloc and "task.delay(2.5" in bloc)
verifier("1. Réglage marqué « (V6.9.10.9) »", "(V6.9.10.9) Le leurre disparaît à chaque départ" in bloc)
verifier("1. Aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])

# ================================================================== 2. Tablette
verifier("2. Tablette : la tuile cherche le leurre sous son vrai nom",
         'local leurreActif = workspace:FindFirstChild("TardisLeurre_" .. def.Nom) ~= nil' in outils)
verifier("2. Tablette : le bouton retire le leurre quand il existe",
         'if workspace:FindFirstChild("TardisLeurre_" .. def.Nom) then\n\t\t\tremote:FireServer("Leurre", { retirer = true })' in outils)
verifier("2. Plus aucune recherche de l'ancien nom « TardisLeurre » seul", 'FindFirstChild("TardisLeurre")' not in outils)
verifier("2. Le client (EffetsExterieurs) utilise le même nom", '"TardisLeurre_" .. def.Nom' in lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/EffetsExterieurs.lua"))

print("\n".join("  ✓ " + o for o in OK)); print("\n".join("  ✗ " + k for k in KO))
print(f"V6.9.10.9 : {len(OK)}/{len(OK) + len(KO)} vérifications réussies")
sys.exit(1 if KO else 0)
