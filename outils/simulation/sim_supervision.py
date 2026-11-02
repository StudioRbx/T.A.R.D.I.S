import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from monde import *
import roblox
OK, KO = [], []
def verifier(nom, condition, detail=""):
    (OK if condition else KO).append(nom + ("" if condition else "  →  " + str(detail)))
I, G, game, joueur = monde(serveur=True)
G["script"] = Instance("Script", "TardisSupervision", game.m_FindFirstChild("ServerScriptService"))
# Le modèle du TARDIS dans le Workspace (Config.modeles)
ws = game.m_FindFirstChild("Workspace")
dossier = Instance("Folder", "TARDIS", ws); t1 = Instance("Folder", "TARDIS_1", dossier)
Instance("Model", "EXTERIEURE", t1); Instance("Model", "INTERIEURE", t1)
teams = game.m_FindFirstChild("Teams")
ctat = Instance("Team", "C.T.A.T.", teams)
balises = []
diffusion = Instance("BindableEvent", "TardisBaliseDiffusion", game.m_FindFirstChild("ServerStorage"))
diffusion.__lua_index__("Event").connecter(Fonction("balise", py=lambda j: balises.append(j) or []))
src = open(DEPOT + "/ServerScriptService/TardisSupervision.server.lua", encoding="utf-8").read()
lancer(Fonction("supervision", py=lambda: I.executer(src, "TardisSupervision")), nom="TardisSupervision")
H.avancer(1)
verifier("TardisSupervision démarre sans erreur", not roblox.ERREURS, roblox.ERREURS[:3])
verifier("Pas encore technicien", joueur.attrs.get("TardisAccesTechnicien") in (None, False), joueur.attrs)
# Le joueur rejoint la C.T.A.T.
joueur.__lua_setindex__("Team", ctat); H.avancer(1)
verifier("Rejoint la C.T.A.T. → technicien", joueur.attrs.get("TardisAccesTechnicien") is True, joueur.attrs)
joueur.__lua_setindex__("Team", None); H.avancer(1)
verifier("Quitte la C.T.A.T. → plus technicien", joueur.attrs.get("TardisAccesTechnicien") is False, joueur.attrs)
verifier("Plus d'attribut TardisStaff", "TardisStaff" not in joueur.attrs, joueur.attrs)
# Chat
chat = joueur.__lua_index__("Chatted")
for msg in ("/tardis help", "/tardis", "/tardis aide"):
    avant = len(balises); chat.declencher(msg); H.avancer(2)
    verifier(f"« {msg} » allume la balise", len(balises) == avant + 1, len(balises))
for msg in ("/tardis statut", "/tardis journal", "/tardis maintenance on", "/tardis recette", "bonjour"):
    avant = len(balises); chat.declencher(msg); H.avancer(2)
    verifier(f"« {msg} » ne fait rien", len(balises) == avant, len(balises))
staff = game.m_FindFirstChild("ReplicatedStorage").m_FindFirstChild("TardisMessageStaff")
verifier("Le RemoteEvent TardisMessageStaff n'existe plus", staff is None)
verifier("Aucune erreur pendant la simulation", not roblox.ERREURS, roblox.ERREURS[:3])
print("\n".join("  ✓ " + o for o in OK)); print("\n".join("  ✗ " + k for k in KO))
print(f"SUPERVISION : {len(OK)} réussis, {len(KO)} échoués.")
