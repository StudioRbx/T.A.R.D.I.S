"""Simulations de la V7.1.1 (corrections et oublis du code actuel) : le vrai code, lu dans le dépôt ou extrait et exécuté.
  1. Version 7.1.1 (le vrai TardisConfig).
  2. T-201 : lancer.sh rend un code d'échec et nomme les étapes ratées ; chaque simulation se termine par
     sys.exit(1 if KO else 0) ; analyse.py échoue dès qu'il a une remarque ; toutes les simulations sont dans lancer.sh.
  3. C-215 (le vrai membreEquipage de TardisExtras, exécuté) : pilote, copilote, technicien de ce TARDIS, équipes C.A.T.
     et C.T.A.T., invité accepté ne sont pas des intrus ; un inconnu l'est ; l'invitation tombe à la sortie.
     La sentinelle de la tablette (Suivi) suit la même règle.
  4. C-155 (le vrai bloc de l'auto-destruction, exécuté) : annulée pendant le compte à rebours par le pilote qui l'a
     engagée, plus d'explosion ; refusée à un autre pilote ; impossible après l'explosion. Bouton de la tablette.
  5. C-158 (le vrai bloc, exécuté) : la reconstitution ne tire jamais une ZDC, une pièce du dossier REFUSE ni une
     destination dans une zone REFUSE ; sans destination permise, il reste où il était.
  6. C-242 : les outils donnés sont marqués (TardisOutil) et retirés dès que le rôle de technicien disparaît.
  7. G-44, G-232, G-237, G-79 : saut sans flash, kaléidoscope réduit, caméra qui évite les murs, effets à l'échelle."""
import os, sys, re
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from monde import *
import roblox
from roblox import Vec3, CF
OK, KO = [], []
def verifier(nom, condition, detail=""):
    (OK if condition else KO).append(nom + ("" if condition else "  →  " + str(detail)))
def tache(f): lancer(Fonction("t", py=f))
def lire(chemin): return open(os.path.join(DEPOT, chemin), encoding="utf-8").read()
def entre(texte, debut, fin): return texte[texte.index(debut):texte.index(fin, texte.index(debut))]
def version(v):
    try: return tuple(int(p) for p in str(v).split("."))
    except ValueError: return ()
SIM = os.path.dirname(os.path.abspath(__file__))
R = {}

extras = lire("ServerScriptService/TardisExtras.server.lua")
systemes = lire("ServerScriptService/TardisSystemes.server.lua")
serveur = lire("ServerScriptService/TardisServeur/init.server.lua")
suivi = lire("StarterPlayer/StarterPlayerScripts/TardisTablette/Suivi.lua")
outils = lire("StarterPlayer/StarterPlayerScripts/TardisTablette/Outils.lua")
vollibre = lire("StarterPlayer/StarterPlayerScripts/TardisVolLibre.client.lua")
regen = lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Regeneration.lua")
effets = lire("StarterPlayer/StarterPlayerScripts/TardisEffets.client.lua")

# ================================================================== 1. Version
roblox.charger_module.__defaults__[0].clear(); roblox.ERREURS.clear()
I, G, game, pilote = monde(serveur=True)
rs = game.m_FindFirstChild("ReplicatedStorage")
tache(lambda: R.update(Config=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisConfig")]))))
Config = R["Config"]
verifier("1. Vrai TardisConfig chargé, version 7.1.1 ou plus récente", version(Config.get("Version")) >= (7, 1, 1) and not roblox.ERREURS,
         (Config.get("Version"), roblox.ERREURS[:3]))

# ================================================================== 2. T-201
lanceur = open(os.path.join(SIM, "lancer.sh"), encoding="utf-8").read()
verifier("2. lancer.sh : retient les étapes ratées et finit par « exit 1 »",
         'echecs="$echecs $s"' in lanceur and 'echecs="$echecs analyse"' in lanceur and "exit 1" in lanceur and 'echo "ÉCHEC :$echecs"' in lanceur)
verifier("2. lancer.sh : lit le code de sortie de chaque simulation (plus seulement la dernière ligne)", "code=$?" in lanceur and "[ $code -ne 0 ]" in lanceur)
verifier("2. lancer.sh : python3, sinon python (Windows)", "PY=python3" in lanceur and "PY=python" in lanceur)
liste = re.search(r"for s in ([^;]+); do", lanceur).group(1).split()
fichiers = sorted(f[:-3] for f in os.listdir(SIM) if f.startswith("sim_") and f.endswith(".py"))
verifier("2. Toutes les simulations sont dans lancer.sh (et rien qui n'existe pas)", sorted(liste) == fichiers, set(liste) ^ set(fichiers))
sans_code = [f for f in fichiers if "sys.exit(1 if KO else 0)" not in open(os.path.join(SIM, f + ".py"), encoding="utf-8").read()
             and f != "sim_paquet"]
verifier("2. Chaque simulation se termine par sys.exit(1 if KO else 0)", not sans_code, sans_code)
paquet = open(os.path.join(SIM, "sim_paquet.py"), encoding="utf-8").read()
verifier("2. sim_paquet rend aussi un code d'échec", "sys.exit(" in paquet)
analyse = open(os.path.join(SIM, "analyse.py"), encoding="utf-8").read()
verifier("2. analyse.py : une remarque fait échouer lancer.sh", "sys.exit(1 if main(" in analyse and "return total" in analyse)

# ================================================================== 3. C-215 : l'équipage n'est pas un intrus
bloc = entre(extras, "local function membreEquipage(joueur)", "\nend\n") + "\nend\n"
ws = game.m_FindFirstChild("Workspace")
ext = Instance("Model", "EXTERIEURE", ws)
prelude = """
local exterieur, Config, def, pilotes, invitesAcceptes = ...
local function estPilote(j) return pilotes[j] == true end
"""
pilotes, invites = Table({}), Table({})
R.clear()
tache(lambda: R.update(f=I.executer(prelude + bloc + "\nreturn membreEquipage", "equipage", (ext, Config, Table({"Nom": "TARDIS_1"}), pilotes, invites))))
membre = R["f"][0] if R.get("f") else None
verifier("3. Vrai membreEquipage chargé sans erreur", membre is not None and not roblox.ERREURS, roblox.ERREURS[:3])
joueurs = game.m_FindFirstChild("Players")
def gens(nom, uid, equipe=None):
    j = Instance("Player", nom, joueurs); j.props.update({"UserId": uid, "DisplayName": nom, "Team": equipe, "Character": None}); return j
def est_membre(j):
    R.pop("m", None); tache(lambda: R.update(m=premier(appeler(membre, [j])))); return R.get("m") is True
teams = game.m_FindFirstChild("Teams")
def equipe(nom): t = Instance("Team", nom, teams); return t
nomCAT = None
tache(lambda: R.update(n=premier(appeler(Config.get("nomEquipe"), []))))
nomCAT = R.get("n")
technique = Config.get("EquipeTechnique")
nomCTAT = (technique.get("Nom") if technique is not None else None) or "C.T.A.T."
inconnu = gens("Inconnu", 200)
copilote = gens("Copilote", 201); ext.m_SetAttribute("Copilote", 201)
tech = gens("Tech", 202); tech.m_SetAttribute("TardisTechnicien_TARDIS_1", True)
techAutre = gens("TechAutre", 203); techAutre.m_SetAttribute("TardisTechnicien_TARDIS_2", True)
cat = gens("Cat", 204, equipe(nomCAT)) if nomCAT else None
ctat = gens("Ctat", 205, equipe(nomCTAT))
autreEquipe = gens("Visiteur", 206, equipe("Visiteurs"))
invite = gens("Invite", 207)
pilotes.set(pilote, True)
verifier("3. Un inconnu est un intrus", not est_membre(inconnu))
verifier("3. Le pilote n'en est pas un", est_membre(pilote))
verifier("3. Le copilote n'en est pas un", est_membre(copilote))
verifier("3. Un technicien de CE TARDIS n'en est pas un", est_membre(tech))
verifier("3. Un technicien d'un AUTRE TARDIS en est un", not est_membre(techAutre))
verifier(f"3. L'équipe C.A.T. ({nomCAT}) n'en est pas une", cat is not None and est_membre(cat), nomCAT)
verifier(f"3. L'équipe C.T.A.T. ({nomCTAT}) n'en est pas une", est_membre(ctat))
verifier("3. Une autre équipe du jeu en est une", not est_membre(autreEquipe))
verifier("3. Un invité qui n'a pas accepté en est un", not est_membre(invite))
invites.set(invite, True)
verifier("3. Un invité qui a accepté n'en est pas un", est_membre(invite))
boucle = entre(extras, "dedans[joueur] = ", "Players.PlayerRemoving")
verifier("3. La boucle du registre ne sonne que pour un non-membre, et l'invitation tombe à la sortie",
         "if estDedans and not membreEquipage(joueur) then" in boucle and "if not estDedans then invitesAcceptes[joueur] = nil end" in boucle)
verifier("3. L'invitation acceptée est notée (InvitationReponse), oubliée au départ du joueur",
         "invitesAcceptes[joueur] = true" in extras and extras.count("invitesAcceptes[joueur] = nil") >= 2)
verifier("3. Sentinelle de la tablette (Suivi) : même règle (pilote, technicien de ce TARDIS, copilote, équipes)",
         "local function membreEquipage(autre)" in suivi and "not membreEquipage(autre)" in suivi and '"TardisTechnicien_" .. def.Nom' in suivi
         and "Config.reglagesEquipe(autre.Team.Name)" in suivi and 'GetAttribute("Copilote") == autre.UserId' in suivi)

# ================================================================== 4. C-155 et 5. C-158 : auto-destruction (le vrai bloc)
bloc = entre(extras, "local autoDestruction = nil", "-- Invitation, balise")
prelude = """
local exterieur, interieur, Config, def, Players, destinations, trace = ...
local E = Config.Etats
local dedans = {}
local function racineDe() return nil end
local function journal(c, t) table.insert(trace, "journal:" .. t) end
local function direAuxPilotes(t) table.insert(trace, "pilotes:" .. t) end
local function dire(j, t) table.insert(trace, "dire:" .. t) end
local function interne(action, a, ...)
	if action == "etat" then return E.Pose, false end
	if action == "listeDestinations" then return destinations end
	if action == "dansZoneRefusee" then return a.X > 1000 end
	if action == "alerter" then table.insert(trace, "alerte:" .. a) end
	if action == "atterrir" then table.insert(trace, "atterrir:" .. tostring(a and a.Position.X)) end
	return nil
end
"""
def auto(dests):
    roblox.ERREURS.clear()
    ws2 = game.m_FindFirstChild("Workspace")
    e = Instance("Model", "EXT_AD", ws2); e.props["Pivot"] = CF((5, 0, 5))
    interieur = Instance("Model", "INT_AD", ws2)
    trace = Table({})
    R.clear()
    tache(lambda: R.update(f=I.executer(prelude + bloc + "\nreturn lancerAutoDestruction, annulerAutoDestruction, destinationsReconstitution",
                                        "autodestruction", (e, interieur, Config, Table({"Nom": "TARDIS_1"}), joueurs, Table({i + 1: d for i, d in enumerate(dests)}), trace))))
    f = R.get("f") or [None, None, None]
    return e, trace, f[0], f[1], f[2]
def appel(f, *a):
    res = {}
    tache(lambda: res.update(v=list(appeler(f, list(a)) or [])))
    return (res.get("v") or []) + [None, None]
def lignes(trace): return [trace.get(i) for i in range(1, 200) if trace.get(i) is not None]

e, trace, lancerAD, annulerAD, _ = auto([])
verifier("4. Vrai bloc de l'auto-destruction chargé sans erreur", lancerAD is not None and annulerAD is not None and not roblox.ERREURS, roblox.ERREURS[:3])
autrePilote = gens("AutrePilote", 300)
ok = appel(lancerAD, pilote)[0]
H.avancer(5)
verifier("4. Engagée : compte à rebours en cours (AutoDestructionDebut)", ok is True and e.attrs.get("AutoDestructionDebut") is not None, e.attrs)
ok2, err2 = appel(annulerAD, autrePilote)[:2]
verifier("4. Un autre pilote ne peut pas l'annuler", ok2 is False and "seul le pilote" in str(err2), (ok2, err2))
ok3 = appel(annulerAD, pilote)[0]
verifier("4. Le pilote qui l'a engagée l'annule : attributs du compte à rebours effacés",
         ok3 is True and e.attrs.get("AutoDestructionDebut") is None and e.attrs.get("AutoDestructionDuree") is None, e.attrs)
verifier("4. Alerte « AUTO-DESTRUCTION ANNULÉE », message aux pilotes et journal",
         "alerte:AUTO-DESTRUCTION ANNULÉE" in lignes(trace) and any(l.startswith("pilotes:Auto-destruction ANNULÉE") for l in lignes(trace))
         and any("annulée par" in l for l in lignes(trace) if l.startswith("journal:")), lignes(trace))
H.avancer(30)
verifier("4. Après l'annulation, plus d'explosion (les délais ne font rien)", e.attrs.get("Detruit") is not True and e.attrs.get("Explosion") is None, e.attrs)
ok4 = appel(annulerAD, pilote)[0]
verifier("4. Rien à annuler une seconde fois", ok4 is False)
ok5 = appel(lancerAD, pilote)[0]
verifier("4. On peut la relancer après l'annulation", ok5 is True and e.attrs.get("AutoDestructionDebut") is not None)
H.avancer(21)
verifier("4. Sans annulation : explosion au bout de 20 s", e.attrs.get("Detruit") is True and e.attrs.get("Explosion") is not None, e.attrs)
ok6, err6 = appel(annulerAD, pilote)[:2]
verifier("4. Après l'explosion, l'annulation est refusée", ok6 is False, (ok6, err6))
verifier("4. Action « AutoDestructionAnnuler » côté serveur (dans les actions du pilote)",
         'elseif action == "AutoDestructionAnnuler" then' in extras and "annulerAutoDestruction(joueur)" in extras)
verifier("4. Tablette : la tuile reste cliquable pendant le compte à rebours et envoie AutoDestructionAnnuler",
         '"EN COURS ! · annuler"' in outils and 'remote:FireServer("AutoDestructionAnnuler")' in outils
         and "pose or compteARebours ~= nil" in outils and "ANNULER L'AUTO-DESTRUCTION" in outils)

# 5. C-158
dossier = Instance("Folder", "TARDIS_DESTINATIONS", ws)
refuse = Instance("Folder", "REFUSE", dossier)
def dest(nom, parent, x):
    p = Instance("Part", nom, parent); p.props.update({"Position": Vec3(x, 0, 0), "CFrame": CF((x, 0, 0)), "Size": Vec3(4, 1, 4)}); return p
permis = dest("Plage", dossier, 10)
zdc = dest("ZDC-Base", dossier, 20)
dansRefuse = dest("Bunker", refuse, 30)
zoneLointaine = dest("Interdit", dossier, 5000)  # dansZoneRefusee (simulé) : X > 1000
e, trace, lancerAD, annulerAD, destinations = auto([permis, zdc, dansRefuse, zoneLointaine])
res = appel(destinations)[0]
noms = [res.get(i).Name for i in range(1, 10) if res is not None and res.get(i) is not None]
verifier("5. Tirage : seulement les destinations permises (ni ZDC, ni dossier REFUSE, ni zone REFUSE)", noms == ["Plage"], noms)
appel(lancerAD, pilote); H.avancer(21); H.avancer(5 * 60 + 2)
verifier("5. Reconstitution sur la seule destination permise", e.attrs.get("Detruit") is False and ("atterrir:10" in lignes(trace) or "atterrir:10.0" in lignes(trace)), lignes(trace)[-4:])
e, trace, lancerAD, annulerAD, destinations = auto([zdc, dansRefuse])
appel(lancerAD, pilote); H.avancer(21); H.avancer(5 * 60 + 2)
verifier("5. Aucune destination permise : il se reconstitue là où il était (pas d'erreur)",
         e.attrs.get("Detruit") is False and not roblox.ERREURS and any(l.startswith("pilotes:Le TARDIS s'est reconstitué.") for l in lignes(trace)), (roblox.ERREURS[:2], lignes(trace)[-3:]))
verifier("5. Le pont serveur répond à « dansZoneRefusee »", 'elseif action == "dansZoneRefusee" then return dansZoneRefusee(...)' in serveur)

# ================================================================== 6. C-242
verifier("6. Les outils donnés sont marqués TardisOutil", 'outil:SetAttribute("TardisOutil", true)' in systemes)
corps = entre(systemes, "local function retirerOutils(joueur, garderCle, seulementMarques)", "\nend\n")
verifier("6. retirerOutils : ne retire que les outils marqués si demandé, et compte les retraits",
         'outil:GetAttribute("TardisOutil") == true' in corps and "retires += 1" in corps and "return retires" in corps)
verifier("6. La boucle retire les outils dès que le rôle disparaît (sauf technicien d'un autre TARDIS)",
         'elseif joueur:GetAttribute("TardisTechnicien") ~= true then' in systemes and "retirerOutils(joueur, false, true) > 0" in systemes
         and "OUTILS RENDUS : VOUS N'ÊTES PLUS TECHNICIEN" in systemes)

# ================================================================== 7. Retouches client
verifier("7. G-44 : sans flash, distorsion temporelle (verre, ni lumière ni Neon) au lieu de l'éclair",
         "local function distorsionTemporelle(position, direction)" in vollibre
         and "if UI.effetsReduits() or UI.sansFlash() then distorsionTemporelle(position, direction) return end" in vollibre
         and "Enum.Material.Glass" in entre(vollibre, "local function distorsionTemporelle", "local function flashTemporel")
         and "PointLight" not in entre(vollibre, "local function distorsionTemporelle", "local function flashTemporel"))
verifier("7. G-44 : au départ, la cabine s'étire dans le sens du saut", "flashTemporel(depart, arrivee - depart)" in vollibre
         and "pivot.LookVector)" in vollibre)
verifier("7. G-232 : kaléidoscope plus lent et plus transparent en « effets réduits »",
         "local vitesse = reduit and 0.35 or 1" in regen and "t * 140 * vitesse" in regen and "(reduit and 0.15 or 0.45) * i" in regen)
verifier("7. G-237 : la caméra cinématique raccourcit l'orbite devant un mur (raycast)",
         "workspace:Raycast(cible, decalage, paramsCamera)" in regen and "paramsCamera.RespectCanCollide = true" in regen
         and "math.max((obstacle.Position - cible).Magnitude - 0.6, 1.5)" in regen)
verifier("7. G-79 : portée de la lampe à l'échelle de la cabine", "lumiere.Range = porteeBase * echelle() *" in effets
         and 'tonumber(exterieur:GetAttribute("Echelle"))' in effets)
souffle = entre(effets, "local function creerSouffle", "local function onde")
verifier("7. G-79 : tourbillon (tailles, vitesses) à l'échelle, recréé si la taille change",
         souffle.count("* e") >= 8 and "echelle = e" in souffle and "math.abs((souffleSol.echelle or 1) - echelle()) > 0.01" in effets)
arc = entre(effets, "local function arc(cf, taille)", "local function intensiteSol")
verifier("7. G-79 : arcs électriques et étincelles de la lampe à l'échelle",
         "12 * e" in arc and "0.6 * e" in arc and "1.6 * e" in arc and "NumberSequence.new(0.2 * e, 0)" in effets
         and 'arcsPart:SetAttribute("Echelle", e)' in effets)
verifier("7. G-79 : particules du vol libre à l'échelle", "Size = NumberSequence.new(0.3 * k, 0)" in vollibre)
for nom, src in (("TardisExtras", extras), ("TardisSystemes", systemes), ("Suivi", suivi), ("Outils", outils), ("TardisVolLibre", vollibre),
                 ("Regeneration", regen), ("TardisEffets", effets)):
    verifier(f"7. {nom} : ajouts marqués « V7.1.1 »", "V7.1.1" in src)
ailleurs = serveur[serveur.index("local ACTIONS_AILLEURS = {}"):serveur.index("local function traiterOrdre")]
verifier("C-155. AutoDestructionAnnuler traitée ailleurs : elle ne consomme pas le délai des ordres", '"AutoDestructionAnnuler"' in ailleurs)

print("\n".join("  ✓ " + o for o in OK)); print("\n".join("  ✗ " + k for k in KO))
print(f"V7.1.1 : {len(OK)}/{len(OK) + len(KO)} vérifications réussies")
sys.exit(1 if KO else 0)
