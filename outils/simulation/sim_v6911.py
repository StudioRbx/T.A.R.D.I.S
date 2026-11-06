"""Simulations de la V6.9.11 (navigation et fiches de lieux) : le vrai code, extrait des scripts et exécuté.
  1. TardisConfig : version, zone VITESSE_REDUITE, réglages FicheLieu et Config.ficheLieu (attributs de la Part ou
     Config.FichesLieux, niveau borné 0-3, textes vides ignorés, textes trop longs coupés).
  2. Serveur, modeAutorise (extrait) : en zone à vitesse réduite, Urgence, Rapide et Sauvetage deviennent Classique ;
     Silencieux, Classique et Catastrophe passent ; une urgence imposée (alerte, collision, REFUSE) n'est jamais désarmée.
     decoller et atterrir : urgence imposée transmise, fiche du lieu publiée, mode joué renvoyé.
  3. Serveur, definirBase et resoudreDestination (extraits) : base sur une destination, « ici », retrait, refus ;
     voyage vers la base (Part suivie si elle bouge, position gardée si elle disparaît) ; sauvegarde ; action réservée aux pilotes.
  4. Client : UI.statutDestination (VITESSE RÉDUITE), Commandes.donnees (base), favoris du copilote en tête (extrait),
     menu T, tablette et poste du copilote (entrée Base).
  5. Signalisation (le module entier) : la carte « fiche du lieu » sous « POSÉ », à bord seulement, couleur du niveau."""
import os, sys, json
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
V3 = lambda x, y, z: Valeur("Vector3", [x, y, z])
def version(v):
    try: return tuple(int(p) for p in str(v).split("."))
    except ValueError: return ()
R = {}

serveur = lire("ServerScriptService/TardisServeur/init.server.lua")
menu = lire("StarterPlayer/StarterPlayerScripts/TardisMenu.client.lua")
navigation = lire("StarterPlayer/StarterPlayerScripts/TardisTablette/Navigation.lua")
etatTab = lire("StarterPlayer/StarterPlayerScripts/TardisTablette/Etat.lua")
construction = lire("StarterPlayer/StarterPlayerScripts/TardisTablette/Construction.lua")
journalTab = lire("StarterPlayer/StarterPlayerScripts/TardisTablette/Journal.lua")
copilote = lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Copilote.lua")
signalisation = lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Signalisation.lua")
volLibre = lire("ServerScriptService/TardisServeur/VolLibre.lua")

# ================================================================== 1. TardisConfig
roblox.charger_module.__defaults__[0].clear(); roblox.ERREURS.clear()
I, G, game, pilote = monde(serveur=True)
rs = game.m_FindFirstChild("ReplicatedStorage")
tache(lambda: R.update(Config=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisConfig")]))))
Config = R["Config"]
verifier("1. Vrai TardisConfig chargé, version 6.9.11 ou plus", version(Config.get("Version")) >= (6, 9, 11) and not roblox.ERREURS, (Config.get("Version"), roblox.ERREURS[:3]))
verifier("1. Zone à vitesse réduite : sous-dossier « VITESSE_REDUITE »", Config.get("ZoneVitesseReduite") == "VITESSE_REDUITE")
FL = Config.get("FicheLieu")
verifier("1. Fiche du lieu : 6 à 8 s, 300 caractères au plus", FL is not None and 6 <= FL.get("Duree") <= 8 and FL.get("LongueurMax") == 300, FL and (FL.get("Duree"), FL.get("LongueurMax")))
niv = FL.get("Niveaux")
verifier("1. Quatre niveaux de danger (0 à 3)", [niv.get(i) for i in range(4)] == ["SANS DANGER", "PRUDENCE", "DANGEREUX", "DANGER EXTRÊME"], [niv.get(i) for i in range(4)])
verifier("1. Config.FichesLieux existe (vide par défaut)", isinstance(Config.get("FichesLieux"), Table))

def fiche(part):
    res = {}
    tache(lambda: res.update(v=premier(appeler(Config.get("ficheLieu"), [part]))))
    v = res.get("v")
    return None if v is None else {k: v.get(k) for k in ("nom", "description", "dangers", "niveau")}
hangar = Instance("Part", "Hangar"); hangar.attrs.update({"Description": "Un hangar sombre.", "NiveauDanger": 2.6})
verifier("1. Attributs de la Part : description et niveau (arrondi : 2,6 → 3)", fiche(hangar) == {"nom": "Hangar", "description": "Un hangar sombre.", "dangers": None, "niveau": 3}, fiche(hangar))
vide = Instance("Part", "Plaine")
verifier("1. Part sans fiche : rien (nil)", fiche(vide) is None, fiche(vide))
vide.attrs.update({"Description": "", "Dangers": 42})
verifier("1. Texte vide ou qui n'est pas du texte : ignoré (nil)", fiche(vide) is None, fiche(vide))
seul = Instance("Part", "Puits"); seul.attrs["NiveauDanger"] = 9
verifier("1. Niveau seul, borné (9 → 3)", fiche(seul) == {"nom": "Puits", "description": None, "dangers": None, "niveau": 3}, fiche(seul))
seul.attrs["NiveauDanger"] = -4
verifier("1. Niveau négatif ramené à 0", (fiche(seul) or {}).get("niveau") == 0, fiche(seul))
seul.attrs["NiveauDanger"] = "beaucoup"
verifier("1. Niveau illisible : ignoré", fiche(seul) is None, fiche(seul))
Config.get("FichesLieux").set("Pont", Table({"Description": "Le pont principal.", "Dangers": "Vent fort.", "NiveauDanger": 1}))
pont = Instance("Part", "Pont")
verifier("1. Config.FichesLieux[nom] : la fiche vient du tableau", fiche(pont) == {"nom": "Pont", "description": "Le pont principal.", "dangers": "Vent fort.", "niveau": 1}, fiche(pont))
pont.attrs["Dangers"] = "Tempête."
verifier("1. Un attribut de la Part l'emporte sur le tableau", (fiche(pont) or {}).get("dangers") == "Tempête." and (fiche(pont) or {}).get("description") == "Le pont principal.", fiche(pont))
# (texte ASCII : dans la simulation, string.sub compte en caractères et utf8.offset en octets ; en Luau, tout est en octets)
long = Instance("Part", "Long"); long.attrs["Description"] = "a" * 400
d = (fiche(long) or {}).get("description") or ""
verifier("1. Texte trop long coupé à 300 caractères, avec « … »", len(d) == 301 and d.endswith("…") and d[:300] == "a" * 300, len(d))
tache(lambda: R.update(rien=premier(appeler(Config.get("ficheLieu"), ["Hangar"]))))
verifier("1. Pas une Part : nil", R.get("rien") is None)
verifier("1. Config : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])

# ================================================================== 2. modeAutorise, decoller, atterrir
blocMode = entre(serveur, "local function modeAutorise(mode, position, urgenceImposee)", "local function decoller(mode)")
ALERTES = []
ZONES = {"lent": False, "sansExpress": False}
partage = Table({"expressPret": 0})
prelude = "local partage, alerter, dansZoneSansExpress, dansZoneVitesseReduite = ...\n"
tache(lambda: R.update(ma=premier(I.executer(prelude + blocMode + "\nreturn modeAutorise", "modeAutorise",
      (partage, Fonction("alerter", py=lambda m: ALERTES.append(m) or []), Fonction("sans", py=lambda p: ZONES["sansExpress"]),
       Fonction("lent", py=lambda p: ZONES["lent"]))))))
MA = R.get("ma")
verifier("2. Vrai modeAutorise extrait et chargé", MA is not None and not roblox.ERREURS, roblox.ERREURS[:3])
def autorise(mode, impose=None):
    res = {}
    tache(lambda: res.update(v=premier(appeler(MA, [mode, "POS", impose]))))
    return res.get("v")
ZONES["lent"] = True
for m in ("Urgence", "Express", "Sauvetage"):
    ALERTES.clear()
    verifier(f"2. Zone à vitesse réduite : {m} → Classique, avec message", autorise(m) == "Normal" and ALERTES == ["ZONE À VITESSE RÉDUITE : VOYAGE CLASSIQUE"], (autorise(m), ALERTES))
for m in ("Normal", "Silencieux", "Catastrophe"):
    ALERTES.clear()
    verifier(f"2. Zone à vitesse réduite : {m} gardé, sans message", autorise(m) == m and ALERTES == [], (autorise(m), ALERTES))
ALERTES.clear()
verifier("2. Urgence imposée (alerte, collision, REFUSE) : jamais désarmée", autorise("Urgence", True) == "Urgence" and ALERTES == [], (autorise("Urgence", True), ALERTES))
ZONES["lent"] = False
verifier("2. Hors zone : Urgence, Rapide, Sauvetage passent", [autorise(m) for m in ("Urgence", "Express", "Sauvetage")] == ["Urgence", "Express", "Sauvetage"])
ZONES["sansExpress"] = True; ZONES["lent"] = True; ALERTES.clear()
verifier("2. Zone sans express d'abord (un seul message)", autorise("Express") == "Normal" and ALERTES == ["ZONE SANS EXPRESS : VOYAGE NORMAL"], ALERTES)
ZONES["sansExpress"] = False; ZONES["lent"] = False
tache(lambda: R.update(clock=premier(I.executer("return os.clock()", "horloge"))))
partage.set("expressPret", (R.get("clock") or 0) + 30); ALERTES.clear()
verifier("2. Recharge du Rapide toujours là", autorise("Express") == "Normal" and ALERTES and ALERTES[0].startswith("EXPRESS EN RECHARGE"), ALERTES)
partage.set("expressPret", 0)
verifier("2. modeAutorise : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])

decoller = entre(serveur, "local function decoller(mode)", "partage.occupe = true")
atterrir = entre(serveur, "local function atterrir(cible, nom, invisible, partDestination, mode)", "\nend\n")
verifier("2. decoller : « true » d'un autre script = urgence imposée", "local urgenceImposee = mode == true" in decoller)
verifier("2. decoller : l'alerte impose l'urgence", 'if exterieur:GetAttribute("Alerte") then mode, urgenceImposee = "Urgence", true end' in decoller)
verifier("2. decoller : zone REFUSE au départ = urgence imposée, transmise à modeAutorise",
         decoller.index("urgenceImposee = true") < decoller.index("mode = modeAutorise(mode, exterieur:GetPivot().Position, urgenceImposee)"))
verifier("2. atterrir : alerte, collision et REFUSE imposent l'urgence", atterrir.count("urgenceImposee = true") == 2 and 'mode, urgenceImposee = "Urgence", true' in atterrir
         and "local urgenceImposee = mode == true" in atterrir)
verifier("2. atterrir : modeAutorise reçoit l'urgence imposée", "mode = modeAutorise(mode, cible.Position, urgenceImposee)" in atterrir)
verifier("2. atterrir : fiche du lieu publiée juste après la position", 'exterieur:SetAttribute("Position", nom)\n\tpublierFicheLieu(partDestination)' in atterrir)
verifier("2. atterrir renvoie le mode vraiment joué", "return true, nil, urgenceForcee, mode" in atterrir)
verifier("2. Remat : message « Voyage classique imposé » si le serveur a changé le mode",
         'elseif ok and modeJoue == "Normal" and mode ~= "Normal" then' in serveur and "Voyage classique imposé (zone ou recharge). " in serveur
         and "local ok, erreur, urgenceForcee, modeJoue = atterrir(" in serveur)
verifier("2. Poche : l'alerte reste une urgence imposée", 'modeAutorise(mode, exterieur:GetPivot().Position, exterieur:GetAttribute("Alerte") == true)' in serveur)
verifier("2. Zone cherchée comme les autres (dansZone, marge commune)",
         'dansZoneVitesseReduite = function(position) return dansZone(position, Config.ZoneVitesseReduite or "VITESSE_REDUITE") end' in serveur)
verifier("2. Fiche retirée en vol libre, porté et posé à la main", volLibre.count('exterieur:SetAttribute("FicheLieu", nil)') == 2 and serveur.count("publierFicheLieu(nil)") == 2)

# Le vrai publierFicheLieu (JSON) avec le vrai Config.ficheLieu
blocFiche = entre(serveur, "local HttpService = game:GetService(\"HttpService\")", "-- Écrans de la console (V6.9.10.1)")
ext = Instance("Model", "EXTERIEURE")
tache(lambda: R.update(pf=premier(I.executer("local exterieur, Config = ...\n" + blocFiche + "\nreturn publierFicheLieu", "publierFicheLieu", (ext, Config)))))
def publier(part): tache(lambda: appeler(R["pf"], [part]))
publier(hangar)
try: publiee = json.loads(ext.attrs.get("FicheLieu") or "null")
except ValueError: publiee = "illisible"
verifier("2. FicheLieu publiée en JSON (nom, description, niveau)", isinstance(publiee, dict) and publiee.get("nom") == "Hangar" and publiee.get("description") == "Un hangar sombre."
         and publiee.get("niveau") == 3, ext.attrs.get("FicheLieu"))
publier(Instance("Part", "Rien"))
verifier("2. Lieu sans fiche : attribut retiré", ext.attrs.get("FicheLieu") is None, ext.attrs.get("FicheLieu"))
publier(hangar); publier(None)
verifier("2. Sans Part (coordonnées, joueur) : attribut retiré", ext.attrs.get("FicheLieu") is None)
verifier("2. Fiche : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])

# ================================================================== 3. Point de base
blocBase = entre(serveur, "-- Point de base (V6.9.11) : les pilotes le définissent", "-- Téléportation de poche :")
dossierDest = Instance("Folder", "TARDIS_DESTINATIONS")
def piece(nom, pos, parent=dossierDest):
    p = Instance("Part", nom, parent); p.props.update({"Position": V3(*pos), "CFrame": roblox.CF(pos), "Size": V3(4, 1, 4)}); return p
hall = piece("Hall", (100, 0, 0))
salleDest = piece("Placard", (0, 1000, 0))
extB = Instance("Model", "EXTERIEURE"); extB.props["Pivot"] = roblox.CF((50, 0, 50)); extB.attrs.update({"Etat": "Pose", "Position": "Plaine"})
partageB = Table({"occupe": False, "sauvegardeModifiee": False})
preludeBase = """
local dossierDestinations, exterieur, partage, Config, dansInterieurPy = ...
local E = Config.Etats
local Players = game:GetService("Players")
local precedent = nil
local nomsPartis = {}
local base = nil
local function publierBase()
	exterieur:SetAttribute("BaseNom", base and base.nom or nil)
	exterieur:SetAttribute("BaseCF", base and base.cf or nil)
end
local function etatActuel() return exterieur:GetAttribute("Etat") end
local function dansInterieur(p) return dansInterieurPy(p) end
local function cibleJoueur() return nil, "JOUEUR SANS PERSONNAGE" end
"""
def dansInt(p):
    return p is salleDest.props["Position"]
fin = "\nreturn { definir = definirBase, resoudre = resoudreDestination, base = function() return base end }"
tache(lambda: R.update(mb=premier(I.executer(preludeBase + blocBase + fin, "base", (dossierDest, extB, partageB, Config, Fonction("dansInterieur", py=dansInt))))))
MB = R.get("mb")
verifier("3. Vrais definirBase et resoudreDestination extraits et chargés", MB is not None and not roblox.ERREURS, roblox.ERREURS[:3])
def definir(d):
    res = {}
    tache(lambda: res.update(v=appeler(MB.get("definir"), [d])))
    return (list(res.get("v") or []) + [None] * 3)[:3]
def resoudre(d):
    res = {}
    tache(lambda: res.update(v=appeler(MB.get("resoudre"), [d, False, False])))
    return (list(res.get("v") or []) + [None] * 6)[:6]
verifier("3. Retirer sans base : refus « aucune base définie »", definir(Table({"retirer": True}))[:2] == [False, "aucune base définie"])
verifier("3. Voyage vers la base sans base : « aucune base définie »", resoudre(Table({"base": True}))[4] == "aucune base définie", resoudre(Table({"base": True})))
verifier("3. Demande invalide ou vide : refus", definir("Hall")[1] == "demande invalide" and definir(Table({}))[1] == "aucune destination choisie")
verifier("3. Destination inconnue : refus", definir(Table({"destination": "Atlantide"}))[1] == "destination introuvable")
verifier("3. Destination dans le TARDIS : refus", definir(Table({"destination": "Placard"}))[1] == "destination dans le TARDIS")
r = definir(Table({"destination": "Hall"}))
verifier("3. Base sur une destination : « Base définie : Hall. », publiée (BaseNom, BaseCF), à sauvegarder",
         r == [True, None, "Base définie : Hall."] and extB.attrs.get("BaseNom") == "Hall" and extB.attrs.get("BaseCF") is hall.props["CFrame"] and partageB.get("sauvegardeModifiee") is True, (r, extB.attrs.get("BaseNom")))
v = resoudre(Table({"base": True}))
verifier("3. Voyage vers la base : la Part de destination (la fiche du lieu marche)", v[0] is hall.props["CFrame"] and v[1] == "Hall" and v[2] is hall and v[4] is None, v)
hall.props["CFrame"] = roblox.CF((120, 0, 0)); hall.props["Position"] = V3(120, 0, 0)
v = resoudre(Table({"base": True}))
verifier("3. La Part a bougé : la base la suit", v[0] is hall.props["CFrame"], v)
tache(lambda: R.update(cfBase=premier(appeler(MB.get("base"), [])).get("cf")))
hall.set_parent(None)
v = resoudre(Table({"base": True}))
verifier("3. La Part a disparu : position gardée, sans Part", v[0] is R["cfBase"] and v[1] == "Hall" and v[2] is None and v[4] is None, v)
hall.set_parent(dossierDest)
extB.attrs["Etat"] = "Vol"
verifier("3. « Ici » en vol : refus", definir(Table({"ici": True}))[1] == "le TARDIS doit être posé")
extB.attrs["Etat"] = "Pose"; extB.attrs["Porteur"] = 101
verifier("3. « Ici » porté : refus", definir(Table({"ici": True}))[1] == "le TARDIS doit être posé")
extB.attrs.pop("Porteur"); partageB.set("occupe", True)
verifier("3. « Ici » pendant une animation : refus", definir(Table({"ici": True}))[1] == "le TARDIS doit être posé")
partageB.set("occupe", False)
r = definir(Table({"ici": True}))
verifier("3. « Ici » posé : base sur la position actuelle, nommée d'après Position (rien à construire)",
         r == [True, None, "Base définie : Plaine."] and extB.attrs.get("BaseNom") == "Plaine" and extB.attrs.get("BaseCF") is extB.props["Pivot"], r)
v = resoudre(Table({"base": True}))
verifier("3. Voyage vers une base sans Part : sa position", v[0] is extB.props["Pivot"] and v[1] == "Plaine" and v[2] is None, v)
r = definir(Table({"retirer": True}))
verifier("3. Retrait : « Base retirée. », attributs effacés", r == [True, None, "Base retirée."] and extB.attrs.get("BaseNom") is None and extB.attrs.get("BaseCF") is None, r)
verifier("3. Les autres destinations marchent toujours", resoudre(Table({"destination": "Hall"}))[1] == "Hall" and resoudre(Table({"precedent": True}))[4] == "aucune destination précédente")
verifier("3. Base : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])
verifier("3. Sauvegarde et chargement de la base", "base = base and { cf = versTable(base.cf), nom = base.nom } or nil" in serveur
         and 'base = { cf = versCFrame(donnees.base.cf), nom = tostring(donnees.base.nom or "Base") }' in serveur and "#donnees.base.cf == 12" in serveur)
copiloteActions = serveur[serveur.index("local ACTIONS_COPILOTE ="):].split("\n")[0]
verifier("3. Action DefinirBase réservée aux pilotes (pas dans ACTIONS_COPILOTE)", 'elseif action == "DefinirBase" then' in serveur and "DefinirBase" not in copiloteActions, copiloteActions)

# ================================================================== 4. Client : statut, données, favoris, menus
roblox.charger_module.__defaults__[0].clear(); roblox.ERREURS.clear()
I, G, game, joueur = monde(serveur=False)
activer_maths(G)  # vrais calculs de CFrame : les zones des pièces (marge de 6 studs)
rs = game.m_FindFirstChild("ReplicatedStorage"); ws = game.m_FindFirstChild("Workspace")
dest = Instance("Folder", "TARDIS_DESTINATIONS", ws)
def piece(dossier, nom, pos, taille=(4, 1, 4)):
    p = Instance("Part", nom, dossier); p.props.update({"Position": Vec3(*pos), "CFrame": CF(pos), "Size": Vec3(*taille)}); return p
accorde, lent, refuse = Instance("Folder", "ACCORDE", dest), Instance("Folder", "VITESSE_REDUITE", dest), Instance("Folder", "REFUSE", dest)
piece(accorde, "Hall", (140, 0, 0))
piece(lent, "Port", (0, 0, 455))
piece(lent, "Quai", (600, 0, 0), (40, 2, 40))
piece(accorde, "Ponton", (605, 1, 0))   # dans la zone du Quai : vitesse réduite par la zone
piece(lent, "Digue", (-300, 0, 0), (20, 2, 20))
piece(refuse, "Bunker", (-300, 0, 0), (20, 2, 20))
piece(accorde, "Abri", (-302, 1, 0))  # dans les deux zones : REFUSE l'emporte
tache(lambda: R.update(C=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisConfig")])), UI=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisUI")])),
                       Cmd=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisCommandes")]))))
UI, Cmd = R["UI"], R["Cmd"]
def statut(nom):
    res = {}
    tache(lambda: res.update(v=appeler(UI.get("statutDestination"), [nom])))
    return tuple((res.get("v") or [None, None])[:2])
verifier("4. Statut : lieu du dossier VITESSE_REDUITE → « VITESSE RÉDUITE »", statut("Port") == ("VITESSE_REDUITE", "VITESSE RÉDUITE"), statut("Port"))
verifier("4. Statut : lieu dans la zone d'une pièce VITESSE_REDUITE → « VITESSE RÉDUITE »", statut("Ponton") == ("VITESSE_REDUITE", "VITESSE RÉDUITE"), statut("Ponton"))
verifier("4. Statut : REFUSE l'emporte sur la vitesse réduite", statut("Abri")[0] == "REFUSE", statut("Abri"))
verifier("4. Statut : lieu ordinaire toujours « ACCORDÉ »", statut("Hall") == ("ACCORDE", "ACCORDÉ"), statut("Hall"))
tache(lambda: R.update(d=premier(appeler(Cmd.get("donnees"), [Table({"type": "base", "nom": "Hall"})]))))
d = R.get("d")
verifier("4. Commandes.donnees : choix « base » → { base = true } (le serveur sait où elle est)", d is not None and d.get("base") is True and d.get("destination") is None and d.get("position") is None, d)
verifier("4. Client : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])

# Le vrai tri des favoris du copilote
blocTri = entre(copilote, "-- (V6.9.11) Les favoris du copilote d'abord", "\t\tfor _, nom in lieux do")
extC = Instance("Model", "EXTERIEURE"); extC.attrs["ListeDestinations"] = "Alpha\nBravo\nCharlie\nDelta\nEcho"
UI.get("prefs").set("favoris", Table({"Delta": True, "Bravo": True}))
tache(lambda: R.update(tri=premier(I.executer("local exterieur, UI = ...\n" + blocTri + "\nreturn lieux", "tri-copilote", (extC, UI)))))
tri = R.get("tri"); tri = [tri.get(i) for i in range(1, 6)] if tri is not None else None
verifier("4. Copilote : ses favoris en tête (dans l'ordre d'origine), puis les autres", tri == ["Bravo", "Delta", "Alpha", "Charlie", "Echo"], tri)
UI.get("prefs").set("favoris", Table({}))
tache(lambda: R.update(tri=premier(I.executer("local exterieur, UI = ...\n" + blocTri + "\nreturn lieux", "tri-copilote", (extC, UI)))))
tri = R.get("tri"); tri = [tri.get(i) for i in range(1, 6)] if tri is not None else None
verifier("4. Copilote : sans favori, l'ordre d'origine", tri == ["Alpha", "Bravo", "Charlie", "Delta", "Echo"], tri)
verifier("4. Copilote : favori marqué « ● », entrée « Base : X », données base, suivi de BaseNom et des favoris",
         '(favori and "● " or "") .. nom' in copilote and 'ligneDestination("Base : " .. baseNom, "base"' in copilote
         and 'elseif choix.type == "base" then d.base = true' in copilote and '"BaseNom" }' in copilote
         and 'UI.prefsChangees.Event:Connect(function(cle) if cle == "favoris"' in copilote)
verifier("4. Copilote : ne peut pas définir la base (aucun DefinirBase envoyé)", "DefinirBase" not in copilote)
verifier("4. Menu T : entrée « Base : X », clé « base », distance par BaseCF, suivi de BaseNom",
         '"Base : "' in menu and '"base"' in menu and 'GetAttribute("BaseCF")' in menu and 'GetAttributeChangedSignal("BaseNom")' in menu)
verifier("4. Tablette : entrée Base toujours en tête des lieux (« non définie » sinon)", 'type = "base"' in navigation and "Base : non définie" in navigation and "ligneBase" in navigation)
verifier("4. Tablette : bouton « ■ » qui envoie DefinirBase (destination, ici, retirer)",
         navigation.count('remote:FireServer("DefinirBase"') >= 1 and "ici = true" in navigation and "retirer = true" in navigation and "destination = " in navigation)
verifier("4. Tablette : bouton construit en code (W.boutonBase) et textes de la fiche",
         "W.boutonBase = creer(\"TextButton\"" in construction and "DÉFINIR COMME BASE" in etatTab and "DÉFINIR LA BASE ICI" in etatTab and "RETIRER LA BASE" in etatTab)
verifier("4. Tablette : la liste suit BaseNom", 'GetAttributeChangedSignal("BaseNom"):Connect(construireListe)' in journalTab)

# ================================================================== 5. Signalisation : la carte « fiche du lieu »
roblox.charger_module.__defaults__[0].clear(); roblox.ERREURS.clear()
I, G, game, joueur = monde(serveur=False)
rs = game.m_FindFirstChild("ReplicatedStorage"); ws = game.m_FindFirstChild("Workspace")
RunService = game.m_FindFirstChild("RunService")
tache(lambda: R.update(Config=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisConfig")])), UI=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisUI")]))))
Config, UI = R["Config"], R["UI"]
E = Config.get("Etats")
camera = Instance("Camera", "Camera", ws); camera.props["CFrame"] = Valeur("CFrame"); ws.props["CurrentCamera"] = camera
ws.props["Terrain"] = Instance("Terrain", "Terrain")
Instance("PlayerGui", "PlayerGui", joueur)
tardis = Instance("Folder", "TARDIS_1", Instance("Folder", "TARDIS", ws))
x = Instance("Model", "Cabine", Instance("Folder", "EXTERIEURE", tardis))
interieur = Instance("Model", "Salle", Instance("Folder", "INTERIEURE", tardis))
racine = Instance("Part", "Racine", x); x.props["PrimaryPart"] = racine
Instance("Part", "Corps", x)
interieur.props["PrimaryPart"] = Instance("Part", "Rotor", interieur)
x.attrs.update({"Etat": "Pose", "DebutEtat": 1000.0, "Mode": "Normal", "Position": "Hall"})
ws.extra["Raycast"] = Fonction("Raycast", py=lambda *a: None)
def image(dt=0.1, n=1):
    for _ in range(n):
        H.avancer(dt)
        for nom in ("RenderStepped", "Heartbeat"):
            sig = RunService.extra.get(nom)
            if sig: sig.declencher(dt)
def etat(nom, mode="Normal"):
    x.m_SetAttribute("Mode", mode); x.m_SetAttribute("DebutEtat", 1000.0 + H.t); x.m_SetAttribute("Etat", nom)
init = lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/init.client.lua")
outils = init[init.index("local function partTemporaire(proprietes)"):init.index("-- La lampe du toit : la pièce qui contient la PointLight")]
tache(lambda: R.update(o=premier(I.executer("local exterieur, Config, E = ...\n" + outils + "\nreturn { partTemporaire = partTemporaire }", "outils-extras", (x, Config, E)))))
DEDANS = {"v": True}
ctx = Table({"C": UI.get("C"), "Config": Config, "E": E, "RunService": RunService, "UI": UI, "animer": UI.get("animer"), "creer": UI.get("creer"),
             "texte": UI.get("texte"), "def": Config.get("Tardis").get(1), "exterieur": x, "interieur": interieur, "joueur": joueur,
             "jeSuisDedans": Fonction("jeSuisDedans", py=lambda: DEDANS["v"]), "partTemporaire": R["o"].get("partTemporaire")})
tache(lambda: appeler(premier(I.executer(signalisation, "Signalisation")), [ctx]))
verifier("5. Signalisation se charge (avec la carte de la fiche)", not roblox.ERREURS, roblox.ERREURS[:3])
gui = joueur.m_FindFirstChild("PlayerGui").m_FindFirstChild("TardisAnnonceBord_TARDIS_1")
carte = gui and gui.m_FindFirstChild("FicheLieu")
verifier("5. Carte « FicheLieu » faite en code, cachée au départ", carte is not None and carte.props.get("Visible") is False)
def trouve(nom):
    pile = [carte]
    while pile:
        o = pile.pop()
        if o.Name == nom and o is not carte: return o
        pile.extend(o.enfants)
    return None
def arrivee(fiche, dedans=True, mode="Normal"):
    DEDANS["v"] = dedans
    x.m_SetAttribute("FicheLieu", json.dumps(fiche, ensure_ascii=False) if isinstance(fiche, dict) else fiche)
    etat("Remat", mode); image(0.1, 3)
    x.m_SetAttribute("Mode", "Normal"); etat("Pose"); image(0.1, 2)
C = UI.get("C")
arrivee({"nom": "Hall", "description": "Grand hall d'entrée.", "dangers": "Sol glissant.", "niveau": 2})
verifier("5. Arrivée sur un lieu avec fiche, à bord : la carte s'affiche", carte.props.get("Visible") is True)
verifier("5. Nom, description et dangers venus du serveur",
         trouve("Nom").props.get("Text") == "◆  HALL" and trouve("Description").props.get("Text") == "Grand hall d'entrée." and trouve("Dangers").props.get("Text") == "⚠ Sol glissant.",
         (trouve("Nom").props.get("Text"), trouve("Description").props.get("Text"), trouve("Dangers").props.get("Text")))
verifier("5. Niveau 2 : « NIVEAU 2 · DANGEREUX », en orange", trouve("Niveau").props.get("Text") == "NIVEAU 2 · DANGEREUX" and trouve("Niveau").props.get("TextColor3") is (C.get("orange") or C.get("ambre")),
         trouve("Niveau").props.get("Text"))
contour = carte.m_FindFirstChild("Contour")
verifier("5. Le filet de la carte prend la couleur du niveau", contour is not None and contour.props.get("Color") is (C.get("orange") or C.get("ambre")))
image(0.1, 50)
verifier("5. Toujours là après 5 s", carte.props.get("Visible") is True)
image(0.1, 25)
verifier("5. Partie après Config.FicheLieu.Duree (7 s)", carte.props.get("Visible") is False)
arrivee({"nom": "Parc", "description": "Un parc calme.", "niveau": 0})
verifier("5. Niveau 0 : vert, pas de ligne de dangers", trouve("Niveau").props.get("TextColor3") is C.get("vert") and trouve("Dangers").props.get("Visible") is False
         and trouve("Niveau").props.get("Text") == "NIVEAU 0 · SANS DANGER")
DEDANS["v"] = False; image(0.1, 2)
verifier("5. Le joueur descend : la carte disparaît", carte.props.get("Visible") is False)
arrivee({"nom": "Gouffre", "dangers": "Chute mortelle.", "niveau": 3}); etat("Demat"); image(0.1, 2)
verifier("5. Le TARDIS repart : la carte disparaît", carte.props.get("Visible") is False)
etat("Pose"); image(0.1, 2)
arrivee({"nom": "Gouffre", "dangers": "Chute mortelle.", "niveau": 3})
verifier("5. Niveau 3 : rouge", trouve("Niveau").props.get("TextColor3") is C.get("rouge") and trouve("Description").props.get("Visible") is False)
image(0.1, 80)
arrivee({"nom": "Hall", "description": "x"}, dedans=False)
verifier("5. Dehors : pas de carte", carte.props.get("Visible") is False)
arrivee(None)
verifier("5. Lieu sans fiche (attribut absent) : pas de carte", carte.props.get("Visible") is False)
arrivee("{pas du json")
verifier("5. Fiche illisible : pas de carte, pas d'erreur", carte.props.get("Visible") is False and not roblox.ERREURS, roblox.ERREURS[:3])
arrivee({"nom": "Hall", "niveau": 1}, mode="Silencieux")
verifier("5. Aussi après un voyage Silencieux (elle est à bord)", carte.props.get("Visible") is True)
verifier("5. Le client ne fait que lire FicheLieu (aucun FireServer)", "FireServer" not in signalisation and 'GetAttribute("FicheLieu")' in signalisation)
verifier("5. Signalisation : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])

print("\n".join("  ✓ " + o for o in OK)); print("\n".join("  ✗ " + k for k in KO))
print(f"V6.9.11 : {len(OK)}/{len(OK) + len(KO)} vérifications réussies")
sys.exit(1 if KO else 0)
