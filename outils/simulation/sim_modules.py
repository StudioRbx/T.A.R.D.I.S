import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from monde import *
from roblox import FauxDataStore
import roblox
OK, KO = [], []
def verifier(nom, condition, detail=""):
    (OK if condition else KO).append(nom + ("" if condition else "  →  " + str(detail)))
def tache(f, nom):
    t = lancer(Fonction(nom, py=f), nom=nom)
    return t

# ============================================================ Sauvegarde
I, G, game, joueur = monde(serveur=True)
module = game.m_FindFirstChild("ServerScriptService").m_FindFirstChild("TardisSauvegarde")
R = {}
def sauvegarde():
    S = premier(appeler(G["require"], [module])); R["S"] = S
    ouvrir = lambda n, a=None: premier(appeler(S.get("ouvrir"), [n, a]))
    lire = lambda m, c: appeler(m.get("lire"), [m, c])
    ecrire = lambda m, c, v: premier(appeler(m.get("ecrire"), [m, c, v]))
    # 1. Écriture puis lecture : enveloppe versionnée
    m = ouvrir("Neuf")
    verifier("Sauvegarde : écriture réussie", ecrire(m, "place", Table({"x": 3, "nom": "Pont"})) is True)
    brut = roblox.MAGASINS["Neuf"].donnees["place"]
    verifier("Sauvegarde : enveloppe { format = 2, donnees, ecrit, version }", isinstance(brut, Table) and brut.get("format") == 2 and isinstance(brut.get("version"), str) and brut.get("donnees") is not None,
             {k: v for k, v in brut.h.items()} if isinstance(brut, Table) else brut)
    v, lu = lire(m, "place")[:2]
    verifier("Sauvegarde : relecture des données", lu is True and isinstance(v, Table) and v.get("nom") == "Pont", (v, lu))
    # 2. Clé absente partout
    v, lu = lire(m, "rien")[:2]
    verifier("Sauvegarde : clé absente → nil, lecture réussie", v is None and lu is True, (v, lu))
    # 3. Migration depuis l'ancien magasin
    roblox.MAGASINS["Ancien"] = FauxDataStore("Ancien"); roblox.MAGASINS["Ancien"].donnees["place"] = Table({"vieux": True})
    m2 = ouvrir("Nouveau", "Ancien")
    v, lu = lire(m2, "place")[:2]
    verifier("Migration : l'ancienne valeur est reprise", lu is True and isinstance(v, Table) and v.get("vieux") is True, (v, lu))
    attendre_un_peu()
    verifier("Migration : recopiée dans le nouveau magasin, enveloppée", isinstance(roblox.MAGASINS["Nouveau"].donnees.get("place"), Table) and roblox.MAGASINS["Nouveau"].donnees["place"].get("format") == 2)
    verifier("Migration : l'ancien magasin n'est pas modifié", roblox.MAGASINS["Ancien"].ecritures == 0, roblox.MAGASINS["Ancien"].ecritures)
    # 4. Pannes de lecture : 2 pannes puis succès ; 3 pannes → échec signalé
    roblox.MAGASINS["Neuf"].pannes_lecture = 2
    v, lu = lire(m, "place")[:2]
    verifier("Lecture : 2 pannes puis réussite au 3e essai", lu is True and v is not None, (v, lu))
    roblox.MAGASINS["Neuf"].pannes_lecture = 3
    v, lu = lire(m, "place")[:2]
    verifier("Lecture : 3 pannes → nil et lu = false (on n'écrasera pas)", v is None and lu is False, (v, lu))
    # 5. Pannes d'écriture
    roblox.MAGASINS["Neuf"].pannes_ecriture = 2
    verifier("Écriture : 2 pannes puis réussite", ecrire(m, "place", Table({"x": 4})) is True)
    roblox.MAGASINS["Neuf"].pannes_ecriture = 3
    verifier("Écriture : 3 pannes → false", ecrire(m, "place", Table({"x": 5})) is False)
    # 6. Valeur ancienne sans enveloppe dans le nouveau magasin
    roblox.MAGASINS["Neuf"].donnees["brut"] = Table({"a": 1})
    v, lu = lire(m, "brut")[:2]
    verifier("Valeur sans enveloppe : relue telle quelle", isinstance(v, Table) and v.get("a") == 1, v)
    R["fini"] = True
def attendre_un_peu(): appeler(G["task"].get("wait"), [0.1])
t = tache(sauvegarde, "simulation sauvegarde")
for _ in range(200):
    if R.get("fini") or t.fini: break
    H.avancer(1)
verifier("Simulation sauvegarde terminée sans erreur", R.get("fini") is True and not roblox.ERREURS, roblox.ERREURS)

# ============================================================ Commandes de voyage (client)
roblox.ERREURS.clear()
I, G, game, joueur = monde(serveur=False)
joueur.m_SetAttribute("TardisPrefs", "{}")
rs = game.m_FindFirstChild("ReplicatedStorage")
C = {}
def commandes():
    Config = premier(appeler(G["require"], [rs.m_FindFirstChild("TardisConfig")]))
    Cmd = premier(appeler(G["require"], [rs.m_FindFirstChild("TardisCommandes")]))
    E = Config.get("Etats")
    x = Instance("Model", "TARDIS_1"); x.m_SetAttribute("Etat", E.get("Pose"))
    remote = Instance("RemoteEvent", "TardisCommande_TARDIS_1")
    appeler(Cmd.get("demarrer"), [x, remote])
    C.update(Config=Config, Cmd=Cmd, E=E, x=x, remote=remote, fini=True)
tache(commandes, "chargement commandes")
verifier("TardisUI et TardisCommandes se chargent", C.get("fini") is True and not roblox.ERREURS, roblox.ERREURS[:3])
if C.get("fini"):
    Cmd, E, x, remote = C["Cmd"], C["E"], C["x"], C["remote"]
    envois = lambda: remote.extra.setdefault("envois", [])
    c = lambda nom, *a: appeler(Cmd.get(nom), list(a))
    lieu = Table({"type": "lieu", "nom": "Pont"})
    def etat(nom): x.m_SetAttribute("Etat", E.get(nom))
    def scenario(f, nom):
        res = {}
        def corps(): f(); res["ok"] = True
        tache(corps, nom); return res
    # Modes
    def modes():
        c("reglerMode", "Express"); verifier("reglerMode(Express)", premier(c("mode")) == "Express")
        c("reglerMode", "Catastrophe"); verifier("Catastrophe ne se choisit pas : retour à Normal", premier(c("mode")) == "Normal")
        c("reglerMode", "Silencieux"); verifier("reglerMode(Silencieux)", premier(c("mode")) == "Silencieux")
        c("reglerMode", "Normal")
    scenario(modes, "modes")
    # Interrupteurs liés : un seul mode actif à la fois
    etats = {}
    def inter(nom):
        t = Table(); t.h["regler"] = Fonction("regler", py=lambda v: etats.__setitem__(nom, v) or []); return t
    groupe = Table({k: inter(k) for k in ("urgence", "express", "sauvetage", "silencieux", "classique", "invisible")})
    def liaison():
        c("lierInterrupteurs", groupe)
        appeler(groupe.get("express").get("surChangement"), [True])
        verifier("Interrupteur Rapide : seul Rapide allumé", etats == {"urgence": False, "express": True, "sauvetage": False, "silencieux": False, "classique": False, "invisible": False}, etats)
        appeler(groupe.get("urgence").get("surChangement"), [True])
        verifier("Interrupteur Urgence : Rapide s'éteint", etats["urgence"] and not etats["express"], etats)
        appeler(groupe.get("urgence").get("surChangement"), [False])
        verifier("Urgence décochée : retour à Classique", etats["classique"] and premier(c("mode")) == "Normal", etats)
    scenario(liaison, "interrupteurs")
    # Données de destination
    d = premier(c("donnees", lieu)); verifier("donnees(lieu) → destination = Pont", d.get("destination") == "Pont" and d.get("mode") == "Normal", d.h)
    d = premier(c("donnees", Table({"type": "joueur", "id": 55}), Table({"figer": True}))); verifier("donnees(joueur) → joueur et figer", d.get("joueur") == 55 and d.get("figer") is True, d.h)
    d = premier(c("donnees", Table({"type": "precedent"}))); verifier("donnees(précédent)", d.get("precedent") is True)
    verifier("donnees(position sans position) → nil", premier(c("donnees", Table({"type": "position"}))) is None)
    # Méthode de voyage : destination avant DÉMAT → 10 s de vortex puis REMAT automatique
    def voyage_auto():
        envois().clear()
        c("demat", lieu)
        verifier("DÉMAT envoyé avec le mode", envois() and envois()[-1][0] == "Demat" and envois()[-1][1].get("mode") == "Normal", envois())
        etat("Demat")
    scenario(voyage_auto, "voyage auto")
    H.avancer(5); etat("Vol")
    H.avancer(9.9)
    verifier("Vortex : pas de REMAT avant 10 s", all(e[0] != "Remat" for e in envois()), [e[0] for e in envois()])
    H.avancer(0.3)
    rem = [e for e in envois() if e[0] == "Remat"]
    verifier("REMAT automatique au bout de 10 s, vers la destination", len(rem) == 1 and rem[0][1].get("destination") == "Pont", [e[0] for e in envois()])
    etat("Remat"); H.avancer(3); etat("Pose"); H.avancer(30)
    verifier("Une seule REMAT automatique", len([e for e in envois() if e[0] == "Remat"]) == 1)
    # Sans destination : remat manuelle
    def voyage_manuel():
        envois().clear(); c("demat", None); etat("Demat")
    scenario(voyage_manuel, "voyage manuel"); H.avancer(5); etat("Vol"); H.avancer(60)
    verifier("Sans destination : aucune REMAT automatique", all(e[0] != "Remat" for e in envois()), [e[0] for e in envois()])
    def remat_manuelle():
        verifier("REMAT manuelle sans destination : refusée", premier(c("remat", None)) is False)
        verifier("REMAT manuelle avec destination : envoyée", premier(c("remat", lieu)) is True and envois()[-1][0] == "Remat")
    scenario(remat_manuelle, "remat manuelle")
    etat("Remat"); H.avancer(2); etat("Pose")
    # Appui manuel pendant le compte à rebours : départ immédiat, pas de doublon
    def appui():
        envois().clear(); c("demat", lieu); etat("Demat")
    scenario(appui, "appui pendant le compte à rebours"); H.avancer(4); etat("Vol"); H.avancer(3)
    scenario(lambda: c("remat", None), "remat pendant compte à rebours")
    H.avancer(20)
    verifier("Appui pendant le compte à rebours : une seule REMAT", len([e for e in envois() if e[0] == "Remat"]) == 1, [e[0] for e in envois()])
    # Paradoxe : le serveur refuse ; le 2e clic force
    def paradoxe():
        envois().clear()
        dedans = Table({"type": "lieu", "nom": "Salle de la console"})
        c("remat", dedans)
        remote.extra["OnClientEvent"].declencher("__paradoxe", False) if "OnClientEvent" in remote.extra else remote.__lua_index__("OnClientEvent").declencher("__paradoxe", False)
        verifier("Paradoxe : REMAT passe en confirmation", premier(c("paradoxeArme")) is True)
        c("remat", dedans)
        verifier("Paradoxe : 2e clic → forcer = true", envois()[-1][0] == "Remat" and envois()[-1][1].get("forcer") is True, envois()[-1][1].h)
        verifier("Paradoxe : confirmation consommée", premier(c("paradoxeArme")) is False)
    etat("Vol"); scenario(paradoxe, "paradoxe")
    remote.__lua_index__("OnClientEvent").declencher("__paradoxe", False); H.avancer(16)
    verifier("Paradoxe : la confirmation expire après 15 s", premier(c("paradoxeArme")) is False)
    # TARDIS porté : téléportation de poche
    x.m_SetAttribute("Porteur", 101); etat("Pose")
    scenario(lambda: c("demat", lieu), "poche")
    verifier("Porté : DÉMAT devient DematPorte", envois()[-1][0] == "DematPorte", envois()[-1][0])
    x.m_SetAttribute("Porteur", None)
    # TARDIS petit : remat sur place
    x.m_SetAttribute("Echelle", 0.5); etat("Vol")
    scenario(lambda: c("remat", None), "petit")
    verifier("Petit : REMAT sur place sans destination", envois()[-1][0] == "Remat" and envois()[-1][1].get("destination") is None)
    verifier("Commandes : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])
print("\n".join("  ✓ " + o for o in OK)); print("\n".join("  ✗ " + k for k in KO))
print(f"MODULES : {len(OK)} réussis, {len(KO)} échoués.")
sys.exit(1 if KO else 0)  # (V7.1.1, T-201) code d'échec pour lancer.sh
