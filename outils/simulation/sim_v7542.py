"""Simulations de la V7.5.4.2 (retours DEVMAP) : vérifications sur les sources.
  1. Caméra extérieure : les touches sont liées sans trou (le cadre n'a pas de touche de manette), un échec de liaison
     n'arrête plus l'ouverture de la caméra.
  2. Câbles gris autour de la porte : les pièces « Cable » du kit ne se balancent plus, sauf celles marquées
     TardisBalance ; les câbles créés pour soi ne viennent que si l'intérieur n'a aucune pièce « Cable ».
  3. Outils du technicien : la même règle (dans le TARDIS ou à 20 studs de la cabine) sert pour les donner et pour
     les retirer ; un outil demandé ailleurs est refusé au lieu d'être donné puis retiré."""
import os, sys
DEPOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OK, KO = [], []
def verifier(nom, condition, detail=""):
    (OK if condition else KO).append(nom + ("" if condition else "  →  " + str(detail)))
def lire(chemin): return open(os.path.join(DEPOT, chemin), encoding="utf-8").read()

cfg = lire("src/ReplicatedStorage/TardisConfig.lua")
cam = lire("src/StarterPlayer/StarterPlayerScripts/TardisCamera.client.lua")
amb = lire("src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Ambiance.lua")
sysm = lire("src/ServerScriptService/TardisSystemes.server.lua")

import re
m = re.search(r'Config\.Version\s*=\s*"([\d.]+)"', cfg)
verifier("Config.Version ≥ 7.5.4.2", m and tuple(int(n) for n in m.group(1).split(".")) >= (7, 5, 4, 2), m and m.group(1))

# 1. Caméra
verifier("Caméra : plus de liste de touches avec un trou (Enum.KeyCode[...], action.manette)",
         "Enum.KeyCode[action.touche], action.manette)" not in cam)
verifier("Caméra : touches mises en liste puis passées par table.unpack", "table.unpack(touches)" in cam and "local touches = {}" in cam)
verifier("Caméra : la touche de manette n'est ajoutée que si elle existe", "if action.manette then table.insert(touches, action.manette) end" in cam)
verifier("Caméra : une touche mal écrite est ignorée (pcall autour de Enum.KeyCode)", "pcall(function() return Enum.KeyCode[action.touche] end)" in cam)
verifier("Caméra : la liaison est protégée et signale l'échec sans arrêter entrer()",
         "local okLien = pcall(function()" in cam and "non liée (" in cam)
i_cadre = cam.find('nom = "TardisCameraCadre"')
verifier("Caméra : l'action Cadre existe toujours", i_cadre > 0)

# 2. Câbles
verifier("Câbles : seules les pièces marquées (Config.Salle.AttributBalance) se balancent",
         "objet:GetAttribute(attributBalance) == true" in amb and 'local attributBalance = reglagesSalle.AttributBalance or "TardisBalance"' in amb)
verifier("Câbles : le nom de l'attribut est un réglage (TardisBalance par défaut)", 'AttributBalance = "TardisBalance"' in cfg)
verifier("Câbles : toutes les pièces « Cable » du kit sont comptées", "piecesCable += 1" in amb)
verifier("Câbles : les câbles créés pour soi ne viennent que sans aucune pièce « Cable »",
         "if piecesCable == 0 and (reglagesSalle.CordesLocales or 0) > 0" in amb and "if #cables == 0 and (reglagesSalle.CordesLocales" not in amb)
i_tag = amb.find("GetAttribute(attributBalance)")
i_ins = amb.find("table.insert(cables, { part = objet")
verifier("Câbles : l'ajout d'une pièce du kit est dans le test TardisBalance", 0 < i_tag < i_ins)
verifier("Câbles : sans câble à balancer, majCables ne fait rien", "if #cables == 0 then return end" in amb)

# 3. Outils du technicien
verifier("Outils : une seule règle outilsPermis", sysm.count("local function outilsPermis(joueur)") == 1)
i_regle = sysm.find("local function outilsPermis(joueur)")
regle = sysm[i_regle:sysm.find("\nend", i_regle)]
verifier("Outils : la règle accepte l'intérieur et 20 studs de la cabine",
         'interne("dansInterieur", racine.Position) == true' in regle and "Magnitude <= 20" in regle)
i_act = sysm.find('if action == "Outil" then')
i_fin = sysm.find("\n\t\treturn\n\tend", i_act)
bloc = sysm[i_act:i_fin]
verifier("Outils : la demande est refusée hors de la zone, avec un message",
         "if not outilsPermis(joueur) then" in bloc and "Les outils se prennent dans le TARDIS ou près de la cabine." in bloc)
verifier("Outils : le refus vient avant de donner l'outil",
         0 <= bloc.find("if not outilsPermis(joueur) then") < bloc.find("donnerOutil(joueur, cle)"))
verifier("Outils : la boucle retire avec la même règle", "if racineDe(joueur) and not outilsPermis(joueur) then" in sysm)
verifier("Outils : l'ancienne condition en double a disparu",
         '(racine.Position - exterieur:GetPivot().Position).Magnitude > 20' not in sysm)
verifier("Outils : la règle est définie avant son usage", 0 < i_regle < i_act)

print(f"V7.5.4.2 : {len(OK)}/{len(OK) + len(KO)} vérifications réussies")
for k in KO: print("  ÉCHEC :", k)
sys.exit(1 if KO else 0)
