# État des tests en jeu

Ce qui a été essayé dans Roblox Studio ou dans ZONE-TSADE, version par version (proposition 199, V6.9.8).
Page générée par `python3 outils/etat_tests.py` depuis les tableaux « À tester » de `docs/patch-notes/`.
Pour noter un résultat : remplacer ⬜ dans la colonne Résultat, ajouter une remarque si besoin, puis relancer
le script (les résultats notés sont gardés).

Légende : ⬜ à tester · ✅ marche · ⚠️ marche à moitié · ❌ ne marche pas · ➖ plus d'actualité

**Total : 230 tests** — ⬜ 206 · ✅ 6 · ⚠️ 0 · ❌ 0 · ➖ 18

Les simulations sans Roblox (`outils/simulation/lancer.sh`) vérifient la logique ; seuls ces tests en jeu
confirment l'affichage, les sons et les sensations.

## V6.9.17 — Maps en Streaming

| Test | Attendu | Résultat | Remarque |
|---|---|---|---|
| Map en Streaming, pièces directement dans `INTERIEURE`, lancer Play | avertissement « rangé dans le Model TARDIS_1_INTERIEURE (Persistent) » ; diagnostic « streaming : ok » | ⬜ |  |
| Appuyer sur T, puis sur Y (pilote) | le menu et la tablette s'ouvrent | ⬜ |  |
| Map en Streaming déjà rangée dans un Model Persistent | aucun avertissement, « streaming : ok » | ⬜ |  |
| Map sans Streaming (DEVMAP) | rien ne change, pas de mention du Streaming | ⬜ |  |

## V6.9.16 — Retouches de la console

| Test | Attendu | Résultat | Remarque |
|---|---|---|---|
| S'approcher du bouton Vol libre | l'invite « Vol libre » est un peu plus basse qu'avant, toujours au-dessus des autres | ⬜ |  |
| Regarder l'écran ingénieur | le texte est à l'endroit | ⬜ |  |
| Cliquer sur l'écran ingénieur (pilote ou technicien) | le menu de gestion de l'énergie s'ouvre ; plus de touche « Z » ni de texte d'invite | ⬜ |  |
| Ouvrir le menu de l'énergie | deux colonnes : ÉTAT (avec alerte, démarrage, portes, pannes en cours) et RÉGULATION (avec les plages) | ⬜ |  |
| Le même menu sur un petit écran (émulateur) | il tient entier à l'écran | ⬜ |  |
| Actionner le levier de démarrage, puis le verrou des portes | les leviers du kit s'animent | ⬜ |  |
| Lancer l'alerte | le bouton rouge s'enfonce et remonte avec son son | ⬜ |  |
| Commande refusée (par exemple sans être pilote) | aucune animation | ⬜ |  |

## V6.9.15 — Confort de l'interface et accessibilité

| Test | Attendu | Résultat | Remarque |
|---|---|---|---|
| Ouvrir la tablette sur téléphone (émulateur), onglet Réglages | « Réduire les effets : activé », menus sans balayage ni lueur | ⬜ |  |
| Couper « Réduire les effets » sur téléphone, revenir | toujours coupé sur téléphone ; sur ordinateur, le réglage n'a pas changé | ⬜ |  |
| Partir en Classique, puis en Urgence | « [Dématérialisation] », puis « [Dématérialisation · Urgence] » en bas de l'écran pendant 4 s | ⬜ |  |
| Lancer une alerte à bord, puis une piste du jukebox | « [Alarme du TARDIS] », puis « [Musique : nom de la piste] » | ⬜ |  |
| Partir en Silencieux | aucun sous-titre | ⬜ |  |
| Couper « Sous-titres des sons » dans les réglages, repartir | aucun sous-titre | ⬜ |  |
| Taille de l'interface à 140 %, ouvrir le copilote, la caméra du toit, le TARDIS porté | tout est plus grand ; le bouton Orbite ne chevauche pas « Quitter » | ⬜ |  |
| Taille à 140 %, fermer le menu rapide (T) | le menu fermé ne dépasse plus du bord gauche | ⬜ |  |
| Activer « Ouverture des menus sans animation », ouvrir la tablette (Y) et le menu (T) | ils s'ouvrent et se ferment d'un coup, sans glissement ni balayage | ⬜ |  |
| Activer « Fermer la tablette en cliquant à côté », cliquer à côté | la tablette se ferme ; un clic sur un fond vide dans la tablette ne la ferme pas | ⬜ |  |
| Sans l'option, cliquer à côté | la tablette reste ouverte (seule la croix la ferme) | ⬜ |  |
| Glisser l'en-tête du menu rapide, le fermer, le rouvrir, puis revenir en jeu plus tard | il se rouvre là où on l'a laissé | ⬜ |  |
| Glisser le menu contre un bord | il reste entier à l'écran | ⬜ |  |
| Réglages, « Menu rapide : rétablir sa position » | le menu revient à gauche | ⬜ |  |

## V6.9.14 — Équipage et garde-robe

| Test | Attendu | Résultat | Remarque |
|---|---|---|---|
| Ouvrir un casier | tenues rangées par groupe : FESTIVE, COMITÉ D'ÉTHIQUE, RESSOURCES HUMAINES, BUREAU DE L'ADMIN (avec leur nombre), sans Chronos, Nebula, Atelier, Soudeur ni Gala | ⬜ |  |
| Mettre une tenue en favori, rouvrir le casier | un groupe FAVORIS en ambre, en tête | ⬜ |  |
| Donner des identifiants à Chronos dans `Config.Tenues`, relancer | Chronos dans un groupe VOYAGE, et elle s'enfile | ⬜ |  |
| Régénérer plusieurs fois | jamais Pannaro, Azzurro Regale ni Canard comme nouvelle tenue | ⬜ |  |
| Régler `Config.Equipe.Uniforme` (shirt, pant), apparaître dans la C.A.T. | l'uniforme est mis une fois l'avatar chargé | ⬜ |  |
| Uniforme à 0, apparaître | ses propres vêtements, rien dans l'Output | ⬜ |  |
| Passer de Visiteurs à la C.A.T. | l'uniforme est mis | ⬜ |  |
| Se régénérer avec l'uniforme réglé | la nouvelle apparence est gardée (`ApresRegeneration` faux) | ⬜ |  |
| Deux joueurs, l'un dans la C.A.T. | l'autre voit le badge « C.A.T. » au-dessus de sa tête, à sa couleur ; pas de badge sur soi | ⬜ |  |
| Changer d'équipe vers la C.T.A.T. puis Visiteurs | le badge devient « C.T.A.T. », puis disparaît | ⬜ |  |
| Ranger `PortesInterieures` en `Gauche` / `Droite` avec `Charniere`, ouvrir la porte | les battants intérieurs tournent avec les extérieurs, on passe ; refermés, ils sont solides | ⬜ |  |
| Sans ce rangement, ouvrir la porte | portes intérieures cachées comme avant, la Part `Portail` visible | ⬜ |  |

## V6.9.13 — Nouvelles pannes et outils du technicien

| Test | Attendu | Résultat | Remarque |
|---|---|---|---|
| Provoquer une fuite d'air (ou attendre, `FrequencePannes = "Frequente"`) | « PANNE : Fuite d'air (zone …) », jet d'air sur une grille, l'air baisse de 2 % toutes les 5 s | ⬜ |  |
| Pendant la fuite, tablette technicien › Purger | « Impossible : colmatez d'abord la fuite d'air. » | ⬜ |  |
| Maintenir E sur la fuite sans outil, puis visseuse en main | d'abord « Il faut la visseuse ou la clé à molette en main. », puis « Fuite d'air colmatée par » ton nom | ⬜ |  |
| Rotor bloqué, posé : tenter voyage, vol libre et téléportation de poche | « ROTOR BLOQUÉ » à chaque fois, le rotor rougeoie ; hors tension : toujours « HORS TENSION » | ⬜ |  |
| Maintenir E 6 s sur le rotor bloqué (pilote ou technicien) | « Rotor débloqué par … : le TARDIS peut repartir. », le décollage refonctionne | ⬜ |  |
| Tablette technicien › « SCAN. », viser le rotor, une grille, la console, la cabine | bulle « ◆ … » avec l'état de la pièce, rouge si anomalie, cadre autour de la pièce | ⬜ |  |
| Faire passer l'intégrité sous 60 % (ou une explosion) | « PANNE : Brèche dans la structure », fumée et étincelles sur la console (ou une pièce du dossier `Structure`) | ⬜ |  |
| « SOUD. », cliquer loin puis près de la brèche, 4 fois | « Approche-toi de la brèche. », puis « Soudure 1/4… » → « Brèche refermée par » ton nom, intégrité +500 | ⬜ |  |
| Poser un Tool `Soudeur` avec `Handle` dans `TardisAssets › Outils`, puis « SOUD. » | le modèle en main au lieu du bloc de couleur | ⬜ |  |

## V6.9.12 — Pannes : le socle commun

| Test | Attendu | Résultat | Remarque |
|---|---|---|---|
| Régler `Config.Systemes.FrequencePannes = "Frequente"`, attendre posé | une panne au hasard toutes les 8 à 15 min ; avec `"Aucune"`, plus aucune | ⬜ |  |
| Provoquer une surcharge de vapeur | un seul message « PANNE : Surcharge de vapeur (grille n°…, zone …) · EFFET SUR LE VOL : aucun effet sur le vol · QUI RÉPARE : … » | ⬜ |  |
| Réparer la grille à la visseuse, puis tablette technicien › « HISTORIQUE » | la panne est en vert, avec début → fin et « réparé par » ton nom | ⬜ |  |
| Créer un dossier `Zones` (Parts invisibles) dans l'intérieur, puis une panne | la tablette affiche « · ZONE » suivi du nom de la Part ; sans dossier : Console, Avant, Arrière, Gauche ou Droite | ⬜ |  |
| Tablette technicien, grille en surcharge | la carte désigne la grille qui fume (même grille chez tous les joueurs) | ⬜ |  |
| Ajouter les sons `Panne_*`, puis vapeur, incendie, avarie et clic sur le rotor | sifflement sur la grille, crépitement sur la console (coupé par l'extincteur), grincements, étincelles | ⬜ |  |
| Clic sur le rotor pendant une avarie | quelques étincelles orange, le rotor n'accélère pas | ⬜ |  |

## V6.9.11 — Navigation et fiches de lieux

| Test | Attendu | Résultat | Remarque |
|---|---|---|---|
| Tablette, ligne Base, TARDIS posé : « ■ DÉFINIR LA BASE ICI », puis voyager ailleurs et choisir « Base : X » | le TARDIS revient à la base ; « Base : X » est aussi dans le menu T et chez le copilote | ⬜ |  |
| Copilote : épingler deux lieux (menu T), puis ouvrir le poste du copilote | les deux favoris sont en tête, marqués « ● » | ⬜ |  |
| Créer `TARDIS_DESTINATIONS › VITESSE_REDUITE` avec une Part, puis y atterrir en Rapide | voyage classique, message « ZONE À VITESSE RÉDUITE », statut « VITESSE RÉDUITE » dans les menus | ⬜ |  |
| Même zone, alerte générale active | l'atterrissage reste en urgence | ⬜ |  |
| Ajouter `Description`, `Dangers` et `NiveauDanger = 2` à une destination, puis y atterrir à bord | carte orange de 7 s sous « POSÉ » avec la description et les dangers | ⬜ |  |
| Même arrivée vue de dehors | pas de carte | ⬜ |  |

## V6.9.10.9 — Le leurre disparaît à chaque départ

| Test | Attendu | Résultat | Remarque |
|---|---|---|---|
| Déployer un leurre (tablette), puis lancer un voyage | le leurre s'efface en fondu dès la dématérialisation | ✅ | vérifié dans DEVMAP le 06/11 |
| Déployer un leurre, puis lancer le vol libre | le leurre s'efface au départ du vol libre | ✅ | vérifié dans DEVMAP le 06/11 |
| Regarder la tuile « Leurre » de la tablette, leurre déployé | elle affiche « ACTIF · retirer » ; un clic retire le leurre | ✅ | vérifié dans DEVMAP le 06/11 |

## V6.9.10.8 — Invites de la console remises à leur place, bouton Vol libre retrouvé

| Test | Attendu | Résultat | Remarque |
|---|---|---|---|
| S'approcher de la console | les invites sont sur leur commande (Selecteur, levier, alerte, jukebox, écran ingénieur, casier), pas au-dessus | ✅ | vérifié dans DEVMAP le 06/11 |
| S'approcher du bouton Vol libre (`Colors`) en pilote | l'invite « Vol libre » (F) flotte au-dessus du bouton ; F ou un clic lance le vol libre | ✅ | vérifié dans DEVMAP le 06/11 |
| Lire l'Output au démarrage | plus de ligne « Bouton Vol libre … introuvable » | ✅ | vérifié dans DEVMAP le 06/11 |

## V6.9.10.7 — Menus « Hologramme de confinement », second passage

| Test | Attendu | Résultat | Remarque |
|---|---|---|---|
| Cliquer sur l'écran ingénieur | le menu de l'énergie, plus grand, au nouveau style ; − / + changent la régulation | ⬜ |  |
| Lever l'alerte, menu ouvert | sa bande de danger passe au rouge | ⬜ |  |
| Jukebox : choisir une ligne, puis JOUER, puis ARRÊTER | la ligne passe en jaune, la musique joue puis s'arrête | ⬜ |  |
| Casier : essayer une tenue, puis ENFILER | panneau à droite, tuile à l'essai en jaune, la tenue reste sur le personnage | ⬜ |  |
| Regarder les écrans de la console | nouveau style ; le titre de l'écran ingénieur n'est pas coupé (police large) | ⬜ |  |
| Activer la maintenance depuis la tablette | bandeau MAINTENANCE au nouveau style | ⬜ |  |
| Copilote : ouvrir son poste | panneau au nouveau style, tableau des destinations | ⬜ |  |

## V6.9.10.6 — Menus « Hologramme de confinement », premier passage

| Test | Attendu | Résultat | Remarque |
|---|---|---|---|
| Touche T | le menu rapide au nouveau style : plaque, bande, tableau des destinations avec statut, puces, DÉMAT / REMAT | ⬜ |  |
| Menu ouvert : ↑ ↓ puis Entrée | la ligne jaune se déplace, Entrée lance la démat | ⬜ |  |
| Touche Y | la tablette : onglets en colonne, vue Navigation comme la maquette | ⬜ |  |
| Lever l'alerte | la bande de danger des menus passe au rouge | ⬜ |  |
| Technicien C.T.A.T. : touche Y | la tablette technicien : tableau des pannes, intervention guidée, segments | ⬜ |  |
| Réglages › thème | « Hologramme de confinement » en premier ; les anciens thèmes marchent encore | ⬜ |  |
| Importer les 3 images de `assets/interface/` et coller leurs identifiants dans `Config.Interface.Images` | coins vraiment coupés et lignes de balayage | ⬜ |  |
| Sur téléphone | onglets de la tablette en ligne, boutons faciles à toucher | ⬜ |  |

## V6.9.10.5 — Retours du test dans Studio : Vol libre, casier, tenues, jukebox, écran ingénieur

| Test | Attendu | Résultat | Remarque |
|---|---|---|---|
| Près du Selecteur | deux invites visibles au-dessus de la console : E (destination) et F (Vol libre) | ⬜ |  |
| Pilote : cliquer n'importe où sur `Colors`, ou F | le vol libre démarre | ⬜ |  |
| Ouvrir le casier de la console | la caméra montre le personnage, jamais l'intérieur d'un mur | ⬜ |  |
| Essayer une tenue, puis « Garder cette tenue » | les vrais vêtements à l'essai, puis sur le personnage | ⬜ |  |
| Output au démarrage | aucune ligne « Tenues : vêtements introuvables » (sinon, corriger les numéros listés) | ⬜ |  |
| Glisser des sons dans `ReplicatedStorage › TardisAssets › Jukebox`, puis ouvrir le jukebox | les pistes apparaissent, rangées par catégorie, et se jouent à bord | ⬜ |  |
| Regarder l'écran ingénieur | l'affichage remplit tout l'écran, texte à l'endroit | ⬜ |  |

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
