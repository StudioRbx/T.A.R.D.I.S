import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from monde import *
I, G, game, joueur = monde()
OK, KO = [], []
def verifier(nom, condition, detail=""):
    (OK if condition else KO).append(nom + ("" if condition else "  →  " + str(detail)))
resultat = {}
def principal():
    Config = premier(appeler(G["require"], [game.m_FindFirstChild("ReplicatedStorage").m_FindFirstChild("TardisConfig")]))
    resultat["Config"] = Config
lancer(Fonction("principal", py=principal), nom="chargement TardisConfig")
Config = resultat.get("Config")
verifier("TardisConfig se charge sans erreur", Config is not None and not ERREURS, ERREURS)
f = lambda nom, *a: appeler(Config.get(nom), list(a))
E = Config.get("Etats")
verifier("Config.Version est un texte", isinstance(Config.get("Version"), str), Config.get("Version"))
# Modes
modes = [k for k in Config.get("Modes").h]
verifier("6 modes définis", sorted(modes) == sorted(["Normal", "Urgence", "Express", "Sauvetage", "Silencieux", "Catastrophe"]), modes)
for entree, attendu in [("Normal", "Normal"), ("Urgence", "Urgence"), ("Express", "Express"), (True, "Urgence"), ("Sauvetage", "Sauvetage"),
                        ("Silencieux", "Silencieux"), (None, "Normal"), ("n'importe quoi", "Normal"), ("Classique", "Normal")]:
    r = premier(f("normaliserMode", entree))
    verifier(f"normaliserMode({entree!r}) = {attendu}", r == attendu, r)
for mode in modes:
    for etat in ("Demat", "Remat"):
        d, dec = f("Timing", E.get(etat), mode)
        verifier(f"Timing({etat}, {mode}) : durée > 0, décalage ≥ 0", isinstance(d, (int, float)) and d > 0 and dec >= 0, (d, dec))
    lib = premier(f("libelleMode", mode))
    verifier(f"libelleMode({mode}) est un texte", isinstance(lib, str) and lib, lib)
verifier("libelleMode(Express) = Rapide", premier(f("libelleMode", "Express")) == "Rapide")
verifier("Rapide : dehors, couleur neutre (blanc 235, 240, 255)", premier(f("couleurDehors", "Express")).args == [235, 240, 255], premier(f("couleurDehors", "Express")).args)
verifier("Silencieux : discret, sans son", Config.get("Modes").get("Silencieux").get("Discret") is True)
# Souffles et transparence : toujours entre 0 et 1, et la cabine finit visible (remat) ou effacée (démat)
for mode in modes:
    for etat in ("Demat", "Remat"):
        vals = [premier(f("Alpha", E.get(etat), p / 20, mode)) for p in range(21)] if Config.get("Alpha") else []
        if vals:
            ok = all(isinstance(v, (int, float)) and -1e-9 <= v <= 1 + 1e-9 for v in vals)
            verifier(f"Alpha({etat}, {mode}) reste entre 0 et 1", ok, [round(v, 2) if isinstance(v, (int, float)) else v for v in vals][:6])
# Maintenance
x = Instance("Model", "TARDIS_1")
verifier("Maintenance absente : rien de bloqué", premier(f("bloqueParMaintenance", x, "Demat")) is None)
x.m_SetAttribute("Maintenance", "Révision des systèmes")
verifier("Maintenance : DÉMAT bloqué avec sa raison", premier(f("bloqueParMaintenance", x, "Demat")) == "Révision des systèmes")
verifier("Maintenance : portes permises", premier(f("bloqueParMaintenance", x, "Portes")) is None)
verifier("Maintenance : bouclier permis", premier(f("bloqueParMaintenance", x, "Bouclier")) is None)
for a in ("Remat", "VolLibreDebut", "NavAtterrir", "Rappel", "Minuterie", "AutoDestruction", "Ramasser", "DematPorte"):
    verifier(f"Maintenance : {a} bloqué", premier(f("bloqueParMaintenance", x, a)) is not None)
# Pilotes
defs = Config.get("Tardis")
d1 = defs.get(1)
verifier("TARDIS_1 déclaré", d1.get("Nom") == "TARDIS_1")
verifier("UserId inconnu : pas pilote", premier(f("estPiloteDe", d1, 99999)) in (False, None))
d1.get("Pilotes").get("UserIds").h[1] = 4242
verifier("UserId dans la liste du TARDIS : pilote", premier(f("estPiloteDe", d1, 4242)) is True)
verifier("UserId en texte accepté", premier(f("estPiloteDe", d1, "4242")) is True)
# Équipes
verifier("Équipe des pilotes : C.A.T.", premier(f("nomEquipe")) == "C.A.T.")
verifier("Équipe des techniciens : C.T.A.T.", Config.get("EquipeTechnique").get("Nom") == "C.T.A.T.")
verifier("La C.T.A.T. ne se régénère pas (seule l'équipe nomEquipe() le fait)", premier(f("nomEquipe")) != Config.get("EquipeTechnique").get("Nom"))
verifier("Clé du TARDIS retirée (Config.Cle absent)", Config.get("Cle") is None)
verifier("Crise retirée (Config.Regeneration.CriseDuree absent)", Config.get("Regeneration").get("CriseDuree") is None)
verifier("Recette retirée (Config.Recette absent)", Config.get("Recette") is None)
verifier("Annonce de bord active", Config.get("AnnonceBord").get("Actif") is not False)
print("\n".join("  ✓ " + o for o in OK)); print("\n".join("  ✗ " + k for k in KO))
print(f"CONFIG : {len(OK)} réussis, {len(KO)} échoués. Erreurs : {ERREURS}")
sys.exit(1 if KO else 0)  # (V7.1.1, T-201) code d'échec pour lancer.sh
