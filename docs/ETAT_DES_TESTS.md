# État des tests en jeu

Ce qui a été essayé dans Roblox Studio ou dans ZONE-TSADE, version par version (proposition 199, V6.9.8).
Page générée par `python3 outils/etat_tests.py` depuis les tableaux « À tester » de `docs/patch-notes/`.
Pour noter un résultat : remplacer ⬜ dans la colonne Résultat, ajouter une remarque si besoin, puis relancer
le script (les résultats notés sont gardés).

Légende : ⬜ à tester · ✅ marche · ⚠️ marche à moitié · ❌ ne marche pas · ➖ plus d'actualité

**Total : 86 tests** — ⬜ 68 · ✅ 0 · ⚠️ 0 · ❌ 0 · ➖ 18

Les simulations sans Roblox (`outils/simulation/lancer.sh`) vérifient la logique ; seuls ces tests en jeu
confirment l'affichage, les sons et les sensations.

## V6.9.8 — Vérification et outils de suivi

| Test | Attendu | Résultat | Remarque |
|---|---|---|---|
| Vol libre, touche L en visant un joueur | le TARDIS le suit, derrière et au-dessus ; L à nouveau : il le lâche | ⬜ |  |
| Vol libre, touche L sans personne en vue | « Aucune cible : vise un autre joueur ou un véhicule occupé (moins de 200 studs) » | ⬜ |  |
| Choisir une destination | l'écran de la console affiche « DESTINATION : » et le lieu | ⬜ |  |
| Menu T, taper le début d'un lieu | la liste ne garde que les lieux et joueurs qui correspondent | ⬜ |  |
| Tablette › réglages › thème Gallifrey, puis ouvrir la liste des destinations (menu T et tablette) | fond ivoire, texte foncé lisible ; retour à Cristal : fond sombre | ⬜ |  |

## V6.9.7 — Corrections : TARDIS bloqué ou perdu

| Test | Attendu | Résultat | Remarque |
|---|---|---|---|
| Porter le TARDIS, mode Silencieux, téléportation de poche | il part et arrive ; plus de TARDIS bloqué | ⬜ |  |
| Voyage vers un joueur qui quitte pendant le vortex | « … a quitté le jeu : retour à … », retour au départ | ⬜ |  |
| Vol libre, puis le pilote ne bouge plus (déconnexion simulée) | au bout de 8 s, le TARDIS se pose seul | ⬜ |  |
| Vol libre invisible, puis le pilote quitte | rematérialisation sur place, puis atterrissage | ⬜ |  |
| Membre de la C.A.T. qui saute hors de la carte | rattrapé sur la terre ferme, une seule régénération | ⬜ |  |
| Son de démat à 50, 150 et 300 studs | fort, faible, plus rien | ⬜ |  |

## V6.9.5 — Retouches et équipe C.T.A.T.

| Test | Attendu | Résultat | Remarque |
|---|---|---|---|
| Voyage à bord | plus de « Départ dans 3, 2, 1 » ; « Matérialisation dans 3, 2, 1 » à l'arrivée | ⬜ |  |
| Menu rapide, tablette, tablette technicien | plus de clé du TARDIS | ⬜ |  |
| Régénération | plus de vision floue ni de pas titubants ensuite | ⬜ |  |
| Remat en Sauvetage, de nuit | sol non éclairé ; quatre faisceaux horizontaux qui tournent avec la cabine | ⬜ |  |
| Joueur mis dans la C.T.A.T. | il apparaît dans le TARDIS, ouvre la tablette technicien (Y) ; tué, il meurt normalement (pas de régénération) | ⬜ |  |

## V6.9.4 — Commandes du staff retirées, maintenance dans la tablette

| Test | Attendu | Résultat | Remarque |
|---|---|---|---|
| Pilote : Outils › Maintenance › « Révision des systèmes » | bandeau orange ; DÉMAT : « Impossible : TARDIS en maintenance (Révision des systèmes) » | ⬜ |  |
| Pendant la maintenance : portes, boucliers, thème | ça marche | ⬜ |  |
| Technicien : MAINTENANCE puis LEVER LA MAINTENANCE | même chose, sans passer par un pilote | ⬜ |  |
| Maintenance demandée en vol | « le TARDIS doit être posé » | ⬜ |  |
| `/tardis statut` | rien ne se passe ; `/tardis help` allume toujours la balise | ⬜ |  |

## V6.9.3 — Annonce de bord, signalisation, ambiance et statistiques

| Test | Attendu | Résultat | Remarque |
|---|---|---|---|
| Voyage Classique, à bord | « DÉPART DANS 3, 2, 1 » avec bips, puis « MATÉRIALISATION DANS 3, 2, 1 » et « POSÉ » | ➖ | départ retiré en V6.9.5 (voir V6.9.5) |
| Voyage Silencieux, à bord | compte à rebours sans bip | ➖ | départ retiré en V6.9.5 (voir V6.9.5) |
| Voyage Rapide, vu de dehors | lignes vertes au sol au départ et à l'arrivée, qui s'effacent | ⬜ |  |
| Enseigne pendant une démat Urgence | elle grésille ; en Rapide : stroboscope ; en Silencieux : éteinte | ⬜ |  |
| Thème Nuit puis Alerte | bourdonnement plus grave, puis plus aigu | ⬜ |  |
| Réglages › Statistiques après 2 voyages Rapides | « Rapide 2 » et du temps gagné | ⬜ |  |

## V6.9.2 — Mode maintenance et recette automatique

| Test | Attendu | Résultat | Remarque |
|---|---|---|---|
| Staff : `/tardis maintenance on TARDIS_1 essai` | bandeau chez les pilotes ; un pilote non staff qui clique DÉMAT : « TARDIS en maintenance (Essai) » | ➖ | commandes du staff retirées en V6.9.4 : maintenance dans la tablette |
| Le staff, pendant la maintenance | ses commandes marchent ; son bandeau le lui rappelle | ➖ | commandes du staff retirées en V6.9.4 : maintenance dans la tablette |
| `/tardis maintenance off` | bandeau retiré, commandes rendues | ➖ | commandes du staff retirées en V6.9.4 : maintenance dans la tablette |
| `/tardis recette TARDIS_1` | 2 allers-retours ; rapport avec ✓ et chronos ; pas d'annonce à l'intercom | ➖ | recette retirée en V6.9.4 |
| `/tardis recette TARDIS_1 complete` | 5 modes testés (environ 2 min 30) | ➖ | recette retirée en V6.9.4 |
| Recette avec le TARDIS en vol | « Recette impossible : le TARDIS doit être posé et libre. » | ➖ | recette retirée en V6.9.4 |

## V6.9.1 — Copilote et carnet de bord

| Test | Attendu | Résultat | Remarque |
|---|---|---|---|
| Pilote : Outils › Copilote, clic sur un passager | le passager voit le poste du copilote ; la tuile affiche « En poste : … » | ⬜ |  |
| Copilote : Rapide, un lieu, DÉMAT puis REMAT | voyage rapide vers le lieu choisi | ⬜ |  |
| Copilote : destination dans le TARDIS | REMAT passe au rouge « VOUS CONFIRMEZ ? » ; second clic : Catastrophe | ⬜ |  |
| Pilote en vol libre, passé dans le vortex ; copilote : ATTERRIR À DESTINATION | rematérialisation à la destination ; le pilote reçoit « … pose le TARDIS » | ⬜ |  |
| Copilote qui sort du TARDIS | poste fermé, message « tu as quitté le TARDIS » | ⬜ |  |
| Copilote : essaie une autre commande (portes, bouclier) | refusée par le serveur | ⬜ |  |
| Carnet : note sur le lieu actuel, puis redémarrage du serveur | la note est toujours là | ⬜ |  |
| Carnet : ✕ puis « ? » | note effacée | ⬜ |  |

## V6.9 — Silencieux, mode Siège, clé du TARDIS, crise post-régénération

| Test | Attendu | Résultat | Remarque |
|---|---|---|---|
| Voyage Silencieux, vu de dehors | aucun son, lampe éteinte, aucun effet au sol, pas d'empreinte ; à bord, rotor violet | ⬜ |  |
| Premier atterrissage Silencieux de la session | pas d'annonce à l'intercom | ➖ | intercom en pause depuis V6.9.6 |
| Tablette : sélecteur de mode | un seul segment actif, synchronisé avec le menu rapide | ⬜ |  |
| Siège | bouclier complet, portes verrouillées, alerte ; second appui : tout relâché ; décollage : siège terminé | ⬜ |  |
| Clé (technicien, à 50 studs) | portes verrouillées, lampe qui clignote deux fois ; à 100 studs : « Trop loin » | ➖ | clé retirée en V6.9.5 |
| Régénération | 60 s de vision floue et de pas titubants, qui s'apaisent | ➖ | crise post-régénération retirée en V6.9.5 |

## V6.8.1 — Sauvegarde versionnée et accès sur mobile

| Test | Attendu | Résultat | Remarque |
|---|---|---|---|
| Premier démarrage après la mise à jour (avec l'accès aux API activé) | Output : « Sauvegarde migrée vers TardisSauvegarde_v2_TARDIS_1 : place_… », la dernière position et l'historique sont retrouvés | ⬜ |  |
| Redémarrage suivant | plus de message de migration, mêmes données | ⬜ |  |
| Préférences d'un joueur (thème, touches) | retrouvées après la migration | ⬜ |  |
| Téléphone ou tablette | boutons T et Y à gauche ; le menu et la tablette s'ouvrent | ⬜ |  |

## V6.8 — Intégration au jeu : accès, journal, commandes du staff, erreurs

| Test | Attendu | Résultat | Remarque |
|---|---|---|---|
| Démarrage | Output : « Supervision prête (Adonis : détecté / non détecté, journal : interne) » | ⬜ |  |
| `/tardis statut` (pilote de la config) | le statut dans le chat | ➖ | commandes du staff retirées en V6.9.4 |
| `/tardis statut` (joueur ordinaire) | « Commande réservée au staff du TARDIS. », **pas de balise** | ➖ | commandes du staff retirées en V6.9.4 |
| `/tardis help` | balise de détresse, comme avant | ⬜ |  |
| Un voyage puis `/tardis journal` | décollage et atterrissage, avec le nom du pilote | ➖ | commandes du staff retirées en V6.9.4 |
| `/tardis erreurs` après les tests des V6.7.x | les erreurs éventuelles des nouvelles versions | ➖ | commandes du staff retirées en V6.9.4 |

## V6.7.3 — Intercom du site, jukebox à bord, sons

| Test | Attendu | Résultat | Remarque |
|---|---|---|---|
| Premier atterrissage visible de la session | bandeau « INTERCOM DU SITE » chez tous les joueurs, alarme, message dans le chat ; Output : « faille spatio-temporelle signalée » | ➖ | intercom en pause depuis V6.9.6 |
| Deuxième atterrissage | rien (une fois par session) | ➖ | intercom en pause depuis V6.9.6 |
| 10 min plus tard | rappel chez les pilotes | ➖ | intercom en pause depuis V6.9.6 |
| Jukebox (après avoir rempli `Config.Jukebox`) | musique à bord seulement, fondu en sortant | ⬜ |  |
| Réparation du rotor | son `Reparation` audible (s'il existe dans `TardisAssets › Sons`) | ⬜ |  |
| Diagnostic au démarrage | liste des sons absents à la fin de la ligne | ⬜ |  |

## V6.7.2 — Tablette technicien

| Test | Attendu | Résultat | Remarque |
|---|---|---|---|
| Technicien, touche Y | la tablette s'ouvre, les jauges bougent | ⬜ |  |
| Curseur vapeur à 0 puis 100 | plus de vapeur, puis des jets deux fois plus forts | ⬜ |  |
| Curseur énergie à 95 % | « Surtension » en carte ; au bout d'une à deux minutes, une fuite de vapeur | ⬜ |  |
| Fuite de vapeur | carte avec la grille, Localiser la surligne, les étapes se cochent | ⬜ |  |
| Coupure après 15 voyages | Redémarrer à distance : 10 s puis courant rétabli | ⬜ |  |
| Purger l'air | jets blancs aux grilles, air à 100 % | ⬜ |  |
| Pilote, outil Ingénierie | la tablette technicien s'ouvre à la place de la tablette de pilotage | ⬜ |  |

## V6.7.1 — Modes de voyage, paradoxe, régénération entière, spawn

| Test | Attendu | Résultat | Remarque |
|---|---|---|---|
| Sauvetage vers le Pont | la cabine apparaît en l'air, tourne en descendant, projecteur allumé, portes ouvertes à l'arrivée | ⬜ |  |
| Rapide | aucun vert dehors ; éclair vert dans la salle au départ et à l'arrivée | ⬜ |  |
| Remat sur un joueur à bord | matérialisation qui commence, repoussée ; bouton rouge « VOUS CONFIRMEZ ? » ; second clic : cabine dans la salle, intégrité −15 %, alerte | ⬜ |  |
| Départ ou arrivée dans une zone REFUSE | urgence imposée avec le message sur l'écran | ⬜ |  |
| Destination avant DÉMAT | 10 s de vortex puis remat seule ; sans destination : attente | ⬜ |  |
| `:kill` sur un Voyageur | aucun morceau ne tombe, régénération sur place | ⬜ |  |
| Spawn | un membre de l'équipe réapparaît dans le TARDIS (Output : « spawn de l'équipe … placé ») | ⬜ |  |

## V6.7 — Refonte visuelle

| Test | Attendu | Résultat | Remarque |
|---|---|---|---|
| Démat normale (Pont) | la cabine s'efface par à-coups synchronisés avec le son, lampe qui éclate à chaque souffle, poussière qui tourne, anneaux au sol, 0 erreur | ⬜ |  |
| Remat normale | même chose à l'envers ; à la fin : éclat de la lampe, bouffée de poussière, à-coup de caméra à bord | ⬜ |  |
| Urgence | saccades comme avant + arcs électriques sur la cabine, étincelles à la lampe | ⬜ |  |
| Express | 2 souffles rapides, éclair Express toujours là | ⬜ |  |
| Camouflé | aucune poussière, aucune onde, aucun halo | ⬜ |  |
| Menu T | 5 blocs, fiche de destination, bouton qui se remplit pendant le voyage | ⬜ |  |
| Tablette Y | en-tête sans chevauchement (vérifier avec un long nom de lieu), allumage, boutons qui se remplissent | ⬜ |  |
| Régénération styles 1, 2, 3, 5, 6, 7 | jets visibles, éclat au changement, sol qui refroidit ; style 4 inchangé | ⬜ |  |
| Effets réduits | pas de scintillement, flashs atténués, choc à 40 % | ⬜ |  |
