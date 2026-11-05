# État des tests en jeu

Ce qui a été essayé dans Roblox Studio ou dans ZONE-TSADE, version par version (proposition 199, V6.9.8).
Page générée par `python3 outils/etat_tests.py` depuis les tableaux « À tester » de `docs/patch-notes/`.
Pour noter un résultat : remplacer ⬜ dans la colonne Résultat, ajouter une remarque si besoin, puis relancer
le script (les résultats notés sont gardés).

Légende : ⬜ à tester · ✅ marche · ⚠️ marche à moitié · ❌ ne marche pas · ➖ plus d'actualité

**Total : 142 tests** — ⬜ 124 · ✅ 0 · ⚠️ 0 · ❌ 0 · ➖ 18

Les simulations sans Roblox (`outils/simulation/lancer.sh`) vérifient la logique ; seuls ces tests en jeu
confirment l'affichage, les sons et les sensations.

## V6.9.10.4 — Sens du texte des écrans de la console

| Test | Attendu | Résultat | Remarque |
|---|---|---|---|
| Regarder l'écran ingénieur | texte à l'endroit, lisible depuis le joueur | ⬜ |  |
| Output au démarrage | la ligne « écrans de la console » donne la face et le sens de chaque écran | ⬜ |  |
| Si le texte est encore tourné ou à l'envers | attribut `RotationEcran` sur la pièce (90, 180 ou 270) : il tourne tout de suite | ⬜ |  |

## V6.9.10.3 — Écrans de la console nets et écran ingénieur visible

| Test | Attendu | Résultat | Remarque |
|---|---|---|---|
| Regarder les deux écrans de destination de près | texte net, lisible même pour l'état, le mode et la ligne du bas | ⬜ |  |
| Regarder l'écran ingénieur | intégrité, énergie, régulation et boucliers affichés sur la face visible | ⬜ |  |
| Output au démarrage | une ligne « écrans de la console » qui donne la pièce et la face de chaque écran | ⬜ |  |
| Si un écran est sur la mauvaise face | attribut texte `FaceEcran` sur la pièce (`Auto`, `Top`, `Back`…) : l'affichage change de face tout de suite | ⬜ |  |
| Cliquer sur l'écran ingénieur | le menu de l'énergie s'ouvre toujours | ⬜ |  |

## V6.9.10.2 — Nouvelle hiérarchie de l'intérieur

| Test | Attendu | Résultat | Remarque |
|---|---|---|---|
| Ouvrir la porte du TARDIS, regarder dedans depuis la rue, puis entrer et ressortir | l'intérieur se voit par la porte ; on passe d'un côté à l'autre sans coupure | ⬜ |  |
| Output au démarrage | aucune attente infinie (« Infinite yield ») sur `Portail` ou `Rotor` ; « spawn « Spawn C.A.T » utilisé pour l'équipe « C.A.T. » » et pareil pour la C.T.A.T. | ⬜ |  |
| Rejoindre l'équipe C.A.T., puis C.T.A.T. (ou se régénérer) | on apparaît sur `Spawn C.A.T`, puis sur `Spawn C.T.A.T` ; aucun spawn `TardisSpawn_…` n'apparaît dans `INTERIEURE` | ⬜ |  |
| Toucher un spawn de l'autre équipe | on ne change pas d'équipe | ⬜ |  |
| Pendant un voyage, à bord | les effets de la salle (couleurs, secousses, vortex) se font bien à l'intérieur | ⬜ |  |
| Tomber hors de la carte (membre de l'équipe) | retour dans le TARDIS, sur le spawn de son équipe | ⬜ |  |

## V6.9.10.1 — Ajustements Studio

| Test | Attendu | Résultat | Remarque |
|---|---|---|---|
| Regarder les néons de la salle, posé, puis pendant un voyage, en alerte, hors tension | bleutés posé, ambrés en démat / remat, cyan dans le vortex, rouges en alerte, rouge fixe hors tension ; changements en douceur | ⬜ |  |
| Mettre `Config.CouleursSalle.Pose = false`, relancer, voyager puis se poser | les néons reprennent exactement leurs couleurs d'origine une fois posé | ⬜ |  |
| Pendant un voyage, regarder le rotor, les LedsAlerte et les écrans | le rotor garde la couleur du mode ; LedsAlerte et écrans ne changent pas | ⬜ |  |
| Regarder les deux écrans de destination, puis changer de destination au Selecteur | les deux affichent la destination, l'état et le mode ; ils changent ensemble | ⬜ |  |
| Un écran affiché sur la mauvaise face | poser l'attribut texte `FaceEcran` (`Back`, `Top`…) sur la pièce : l'affichage passe sur cette face | ⬜ |  |
| Couper le courant, puis le rétablir | les deux écrans et l'écran ingénieur deviennent noirs (« HORS TENSION »), puis reviennent | ⬜ |  |
| Appuyer sur `Console › Datapanel › Redbutton › Button` | alerte générale (et « ALERTE » sur les écrans) ; un second appui la lève | ⬜ |  |
| Pilote : cliquer sur `Console › Selecteur › Colors` (ou F) | le vol libre démarre ; le Selecteur (E) change toujours de destination | ⬜ |  |
| Visiteur : cliquer sur Colors | rien | ⬜ |  |
| Chercher l'interphone près de la porte, dehors et à bord | plus aucun panneau ni bulle d'interphone | ⬜ |  |
| Regarder l'écran ingénieur, puis tirer sur le bouclier ou régler la régulation | PV, énergie, air, vapeur, boucliers à jour ; rouge quand c'est bas | ⬜ |  |
| Pilote ou technicien C.T.A.T. : cliquer sur l'écran ingénieur, régler l'énergie avec − / + | le menu s'ouvre ; la tablette technicien et l'écran montrent la nouvelle valeur | ⬜ |  |
| Visiteur : cliquer sur l'écran ingénieur | « Réservé aux pilotes et aux ingénieurs », pas de menu | ⬜ |  |
| Menu ouvert : Échap, puis rouvrir et s'éloigner | il se ferme les deux fois | ⬜ |  |
| `Console › Casier` : « Choisir une tenue » (Z) ou clic | le menu des tenues s'ouvre ; les autres casiers demandent toujours 3 s | ⬜ |  |
| Pilote : `Console › JukeBox` (« Musique », Z, ou clic), choisir une piste, puis « Arrêter la musique » | la musique joue à bord, puis s'arrête ; avec `Config.Jukebox` vide, le panneau le dit | ⬜ |  |
| Visiteur : `Console › JukeBox` | « Réservé aux pilotes. » | ⬜ |  |
| Output au démarrage | le diagnostic trouve Alerte ; VolLibre, Casier, JukeBox, EcranIngenieur absents seraient dans les optionnelles | ⬜ |  |
| Près du Selecteur, du jukebox et de l'écran ingénieur | les invites E (Selecteur…), F (Vol libre) et Z (jukebox ou écran ingénieur) sont visibles en même temps | ⬜ |  |
| Couper le courant (levier de l'alimentation) | les écrans montrent « HORS TENSION » (et non plus rien du tout) ; un refus de la console s'y affiche | ⬜ |  |
| Pilote : changer de thème ou de musique, puis tout de suite DÉMAT ou Colors | le voyage ou le vol libre part sans attendre | ⬜ |  |

## V6.9.10 — Vol libre et vortex

| Test | Attendu | Résultat | Remarque |
|---|---|---|---|
| Vol libre, sous-menu PLUS › CROISIÈRE (ou Entrée), lâcher les touches | le TARDIS avance seul, droit, à la même altitude ; « CROISIÈRE ● » | ⬜ |  |
| En croisière, tourner la caméra | le TARDIS garde son cap et ne se tourne pas vers la caméra | ⬜ |  |
| En croisière, appuyer sur une touche de direction, puis relancer et freiner | la croisière s'arrête (message), le frein arrête net le TARDIS | ⬜ |  |
| Croisière en TURBO vers un mur | il s'arrête en stationnaire avant le mur, sans choc ni dégâts | ⬜ |  |
| En croisière, PLUS › ORBITE | la caméra tourne lentement autour de la cabine qui avance ; molette : plus près / plus loin | ⬜ |  |
| Pendant l'orbite, freiner (Ctrl) | l'orbite se ferme, la caméra revient derrière le TARDIS, on pilote normalement | ⬜ |  |
| Console › BoutonCamera pendant la croisière, puis « Orbite », puis « Vue du toit », puis « Quitter la caméra » | vue du toit, orbite, vue du toit, retour au pilotage (pas sur le personnage) | ⬜ |  |
| Hors croisière, bouton « Orbite » de la caméra de la console | refusé, l'aide explique « seulement en croisière » | ⬜ |  |
| Un passager à bord quand le pilote freine | secousse à l'écran (plus douce avec « réduire les effets ») ; dehors : fumée autour de la cabine | ⬜ |  |
| Vol libre en TURBO, puis à l'arrêt, en regardant le rotor dans la salle | le rotor pompe bien plus vite en TURBO, revient doucement à son rythme normal | ⬜ |  |
| Donner un son « Vortex » (Config.Sons ou TardisAssets › Sons), voyage classique, rester à bord puis sortir | vent du vortex pendant le vol, à bord seulement ; il s'estompe et s'arrête en sortant ou à l'arrivée | ⬜ |  |
| Voyage Silencieux avec `SilenceABord = true` | pas de vent du vortex à bord | ⬜ |  |
| Output au démarrage sans son Vortex | « sons absents » cite Vortex et Frein | ⬜ |  |

## V6.9.9 — Effets visuels du voyage

| Test | Attendu | Résultat | Remarque |
|---|---|---|---|
| Voyage d'urgence (démat puis remat), en étant près de la cabine | l'air ondule et l'image se trouble nettement plus qu'en Classique, dès la démat | ⬜ |  |
| Atterrissage en Classique, puis en Rapide, sur de l'herbe | une trace carrée sombre sous la cabine, qui s'efface en 30 s | ⬜ |  |
| Atterrissage en Silencieux, puis sur l'eau | aucune trace au sol | ⬜ |  |
| Voyage de nuit (ClockTime 0), puis de jour (ClockTime 12) | lueur, halo et lampe nettement plus forts la nuit, plus discrets le jour | ⬜ |  |
| Dans la salle de contrôle : posé, démat, vol, alerte, hors tension | lumières bleutées, ambrées, cyan, rouges ; hors tension : lumière de secours rouge ; le rotor garde la couleur du mode | ⬜ |  |
| Paradoxe : destination dans le TARDIS, puis confirmer pour forcer | fumée noire et étincelles autour de la cabine, puis éclats et fumée qui traîne environ 20 s | ⬜ |  |
| Démat en Classique, en regardant les vitres de la cabine | les vitres restent lumineuses (lueur chaude) environ une seconde après le reste | ⬜ |  |
| Tablette › Réglages › « Aucun flash », puis un voyage d'urgence, un bouclier et un Rapide à bord | aucun éclat, aucun clignotement, aucun arc ; l'enseigne reste fixe ; « Réduire les effets » s'est activé | ⬜ |  |

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
