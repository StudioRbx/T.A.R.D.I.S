# Journal des versions — T.A.R.D.I.S.

Index de toutes les versions et sous-versions. Le détail de chacune est dans [`docs/patch-notes/`](docs/patch-notes/).

⭐ = version officielle · 🎮 = version installée dans ZONE-TSADE

| Version | Date | Résumé |
|---|---|---|
| **[V1](docs/patch-notes/V1.md)** | 09/10/2026 | **Fondations** *(numérotation reconstituée)* |
| V1.0 | 09/10 | 4 scripts : intérieur plus grand, vue ViewportFrame, passage sans coupure, démat/remat, console, destinations |
| V1.1 | 09/10 | Intégration du kit : `Racine` comme PrimaryPart, rotor en Model, `Default Mainscript` désactivé (faille de sécurité) |
| V1.2 | 09/10 | `TardisLiaisonPortes` : pont avec les portes du kit (LeftOpen, RightOpen, Locked) |
| V1.2.1 | 09/10 | Script de débogage ; création de `Selecteur`, `Levier` et `Ecran` |
| V1.3 | 09/10 | Dossier `PortesInterieures` masqué dans la vue et porte ouverte |
| V1.4 | 09/10 | Fermeture auto au décollage, battant ouvert à l'atterrissage, vue de la rue depuis l'intérieur, `Shut` réécrits |
| V1.4.1 | 09/10 | 7 scripts complets ; permissions des sons |
| V1.4.2 | 10/10 | Vue de la rue : Terrain ignoré, copie en parallèle |
| **[V2](docs/patch-notes/V2.md)** | 10/10/2026 | **Caméra, menu à distance, rapetissement** *(numérotation reconstituée)* |
| V2.0 → V2.0.2 | 10/10 | `TardisCamera` au-dessus de la Lampe ; dispo dans tous les états ; Lampe en Model |
| V2.1 → V2.1.2 | 10/10 | `TardisMenu`, camouflage, atterrissage invisible, `Config.Pilotes` ; fondus corrigés et généralisés |
| V2.2 | 10/10 | Portes ouvertes quand un joueur sort |
| V2.3 → V2.3.1 | 10/10 | Deux battants, verrou dans le menu, atterrir sur un joueur, embarquement, `Arrivee` |
| V2.4 | 10/10 | `Config.Chemins` |
| V2.5 → V2.5.6 | 10/10 | Rapetisser et ramasser (`TardisPorter`), modes main, ceinture et épaule |
| V2.6 | 10/10 | Démat 14 s, remat 13,86 s |
| V2.7 | 10/10 | Levier de verrouillage sur la console |
| V2.8 → V2.8.1 | 10/10 | Décalage son / animation, préchargement ; premier ZIP |
| **[V3](docs/patch-notes/V3.md)** | 10/10/2026 | **Version officielle, urgence, menus, vol libre** |
| V3.0 ⭐ | 10/10 | Version officielle, `Config.Version` |
| V3.1 ⭐ | 10/10 | Animation complète après le son |
| V3.1.2 | 10/10 | Démat 3,25 s + 17 s, remat 2,5 s + 16,86 s |
| V3.2 → V3.2.3 | 10/10 | Mode urgence (sons `_Urg`, animation saccadée), adouci, durées, menu remonté |
| V3.3 | 10/10 | Menu dans le thème Doctor Who, touche T |
| V3.4 | 10/10 | Joueurs (dernière position / figé), curseur de taille, placement libre, collision = urgence |
| V3.5 | 10/10 | Portes à 70 %, alimentation, alerte, démarrage |
| V3.6 | 10/10 | Menu à 4 onglets (Pilotage, Scanner, Systèmes, Journal) |
| V3.7 | 10/10 | Menu classique + **tablette avancée** (`TardisTablette`, `TardisUI`) |
| V3.8 → V3.8.1 | 10/10 | **Vol libre** (`TardisVolLibre`), chute ; la tablette ne se ferme plus au clic |
| V3.9 | 10/10 | Vol refait : 3D, 4 vitesses, collisions |
| V3.10 | 10/10 | Vortex, urgence en vol (en feu), rotation |
| V3.11 | 10/10 | Démat en plein vol vers le vortex *(retirée en V3.12)* |
| V3.12 → V3.12.2 | 10/10 | Démat / remat en pilotant ; vortex en grille filaire ; couleurs de flamme |
| V3.13 | 10/10 | Saut temporel, turbulences, mini-carte, sauvegarde, sentinelle, eau… |
| V3.14 | 10/10 | Boucliers anti-joueurs / anti-balles ; pannes retirées |
| **[V4](docs/patch-notes/V4.md)** | 10–13/10/2026 | **Accès réservés, extras, systèmes** |
| V4.0 ⭐ | 10/10 | Tout réservé aux pilotes, vérifié par le serveur |
| V4.1 → V4.1.1 | 11/10 | Téléportation de poche ; départ à la position Studio |
| V4.2 ⭐ | 11/10 | Menu Rotation (`TardisRotation`) ; `UniquementUserIds` |
| V4.2.1 ⭐ | 11/10 | Symboles corrigés |
| V4.3 → V4.3.1 | 11/10 | `TardisExtras` et `TardisExtrasClient` (≈ 40 fonctionnalités) ; ajustements |
| V4.4 | 12/10 | Étape 1 : rôles temporaires, bannissement, techniciens, réglages, stats |
| V4.5 | 12/10 | Étape 2 : zones, saisie ZDC, anomalies, auto-destruction, invitation, interphone |
| V4.6 | 12/10 | Étape 3 : intérieur (sièges, rotor, vapeur, lumières, customisation, casiers) |
| V4.7 | 12/10 | Étape 4 : `TardisSystemes` (PV, boucliers, pannes, régénération, techniciens) |
| V4.8 | 12/10 | Étape 5 : 14 nouvelles mécaniques de vol |
| V4.9 | 12/10 | Étape 6 : vortex dans le ciel, décorations, tablette en lecture seule |
| V4.10 → V4.10.6 | 12–13/10 | Outils dans la tablette ; correctifs ; 3 styles d'interface |
| **[V5](docs/patch-notes/V5.md)** | 13/10/2026 | **Version officielle consolidée** |
| V5.0 ⭐ | 13/10 | Paquet officiel de tout le travail de la V4 |
| **[V6](docs/patch-notes/V6.md)** | 13–20/10/2026 | **Plusieurs TARDIS et régénération** |
| V6.0 | 13/10 | Trois TARDIS, nouvelle hiérarchie, ACCORDE / REFUSE |
| V6.0.1 → V6.0.7 | 13–14/10 | Destinations dans `TARDIS`, IDs tolérants, `Shut`, passage, `TardisUI`, zone REFUSE, coupure à 15 |
| V6.5 ⭐ | 14/10 | Version établie ; mode de voyage Auto / Manuel |
| V6.5.1 → V6.5.6 | 16–17/10 | IDs, ZIP, performances, crash du ciel, stabilisateur, alarme |
| V6.5.7 → V6.5.11 | 18/10 | Régénération « Le Voyageur » (infinie, avatars, refus, 5 styles), config de référence |
| V6.5.12 | 18/10 | Commandes rapides sur la tablette |
| V6.5.13 | 18/10 | Accessoires après régénération *(non installée)* |
| V6.5.14 | 20/10 | Plus d'onglet à l'écran *(non installée)* |
| Maintenance | 29/10 | Dans ZONE-TSADE : TARDIS_2 et TARDIS_3 mis en commentaire, scripts `Power` du kit désactivés, accès remis à la config du 18/10 ([détail](docs/ETAT_DES_LIEUX.md#6-corrections-appliquées-dans-zone-tsade-29102026)) |
| **V6.6** ⭐ | 29/10 | **Mode Express** : démat et remat en 2 s (l'inverse de l'urgence) ; crash de la rotation dans le ciel corrigé |
| **V6.6.1** ⭐ | 29/10 | Fondations : `Config.Modes`, attribut `Mode`, module `TardisCommandes`, interrupteurs synchronisés, diagnostic, archive du kit |
| **V6.6.2** ⭐ | 29/10 | Ajouts : rotor coloré selon le mode (bleu, orange, vert) et empreinte temporelle de 30 s après un départ |
| **V6.6.3** ⭐ | 29/10 | Gros scripts découpés : tablette (10 modules), effets (11 modules), vol libre du serveur ; aucun changement de jeu |
| **V6.6.4** ⭐ | 29/10 | Express en vol libre, en poche et au levier ; sons et éclair Express ; recharge de 5 s ; zones SANS_EXPRESS ; historique par mode |
| **V6.6.5** ⭐ | 29/10 | Régénération fiable (avatars préparés, 3 essais, R6, accessoires vérifiés) ; onglet supprimé ; option « réduire les effets » ; vol libre à 8 boutons ; mode débutant pour les nouveaux pilotes |
| **V6.6.6** ⭐🎮 | 30/10 | L'avatar change vraiment (avatars adaptés au R6, cheveux gardés) ; styles de régénération Supernova et Fracture avec onde de choc de 5 studs |
| **V6.7** ⭐ | 01/11 | **Refonte visuelle** : (dé)matérialisation qui respire avec le son (lampe, lumières, poussière, ondes, arcs d'urgence, choc d'arrivée) ; menu rapide et tablette refaits ; 6 régénérations refaites avec des jets d'énergie (le Tourbillon est gardé). *À installer dans ZONE-TSADE.* |
| **V6.7.1** ⭐ | 02/11 | **Modes de voyage** : Classique, Urgence, Rapide (ex-Express, couleur à l'intérieur seulement), **Sauvetage** (arrive en hauteur, descend en tournant, ouvre les portes) ; **Catastrophe** (destination dans le TARDIS : atterrissage avorté, puis REMAT rouge « Vous confirmez ? ») ; zone REFUSE → urgence au départ et à l'arrivée ; destination avant DÉMAT → 10 s de vortex puis REMAT auto, sinon manuel ; corps qui ne tombe plus en miettes à la régénération ; spawn de l'équipe dans le TARDIS. *À installer dans ZONE-TSADE.* |
| C.A.T. · C.T.A.T. | 02/11 | Équipes : **C.A.T.** (Cellule d'Autorité Temporelle, pilotes, régénération) ; **C.T.A.T.** (Cellule Technique d'Autorité Temporelle, techniciens, sans régénération), ajoutée après coup et livrée dans la V6.9.5. |
| **V6.7.2** ⭐ | 02/11 | **Tablette technicien** (Y, ou outil Ingénierie des pilotes) : 7 jauges, télémétrie, journal ; régulation de l'énergie, de l'air et de la vapeur, énergie, redémarrage à distance, purge, diagnostic ; interventions guidées avec localisation. Aucune commande de vol. *À installer dans ZONE-TSADE.* |
| **V6.7.3** ⭐ | 02/11 | **Intercom du site** : la 1re matérialisation visible de la session est annoncée à tout le serveur (OS Fondation via `TardisPontFondation`, sinon bandeau, alarme et chat), rappel aux pilotes toutes les 10 min ; **jukebox audible seulement à bord** avec playlist Action ; `Config.Sons` ; correctif : `Cloitre` et `Reparation` n'étaient jamais joués. *À installer dans ZONE-TSADE.* |
| **V6.8** | 02/11 | **Intégration au jeu** (branche `v6.8-integration-staff`) : accès par rang Adonis ou liste blanche, journal du TARDIS vers RoSysLog, commandes du staff `/tardis statut`, `journal`, `erreurs`, remontée des erreurs des joueurs ; correctif : un message `/tardis …` n'allume plus de balise. *À installer et à brancher dans ZONE-TSADE.* |
| **V6.8.1** | 02/11 | **Sauvegarde versionnée** (module `TardisSauvegarde`, magasins `_v2`, migration sans perte depuis `_v1`, 3 essais, plus d'écrasement après une lecture ratée) ; **boutons tactiles** T et Y sur mobile. |
| **V6.9** | 02/11 | **Protocole Silencieux** (ni son, ni lumière, ni annonce), **sélecteur de mode** dans la tablette, **mode Siège** (bouclier + verrou + alerte d'un geste), **clé du TARDIS** (verrou à distance, la lampe clignote), **crise post-régénération** (60 s de vision floue et de pas titubants). |
| **V6.9.1** | 02/11 | **Copilote** (un pilote nomme un joueur à bord, qui a son propre poste : protocole, destination, démat / remat, camouflage, atterrissage du vol libre) et **carnet de bord RP** (notes par lieu, filtrées par Roblox, sauvegardées). |
| **V6.9.2** | 02/11 | **Mode maintenance** (`/tardis maintenance on|off` : TARDIS bloqué pour tous sauf le staff, bandeau à l'écran) et **recette automatique** (`/tardis recette` : allers-retours chronométrés dans chaque mode, rapport au staff). |
| **V6.9.3** | 02/11 | **Annonce de bord** (« Départ dans 3… 2… 1… », « Matérialisation dans 3… 2… 1… »), **traînée au sol** après un Rapide, **enseigne POLICE BOX** qui clignote selon le mode, **ambiance sonore par thème**, **statistiques par mode** et temps gagné. |
| **V6.9.4** | 02/11 | **Commandes du staff retirées** (`/tardis statut`, `journal`, `erreurs`, `maintenance`, `recette`) ainsi que le rôle staff et la recette automatique ; **mode maintenance dans la tablette** : les pilotes (Outils › Maintenance) et les techniciens (Commandes › Maintenance) immobilisent le TARDIS. `/tardis help` reste la balise de détresse. |
| **V6.9.5** | 02/11 | **Retouches** : V6.9.3 sans « Départ dans 3, 2, 1 » (l'annonce d'arrivée reste) ; V6.9 sans la clé du TARDIS (remplacée plus tard) ni la crise post-régénération ; V6.7.1 : le Sauvetage n'éclaire plus le sol, quatre lumières aux fenêtres balaient les alentours comme un phare ; **équipe C.T.A.T.** (Cellule Technique d'Autorité Temporelle) pour les techniciens, sans régénération. |
| **V6.9.6** | 02/11 | **Simulations sans Roblox** (`outils/simulation` : analyse statique des 50 scripts, petit interpréteur Luau, 122 tests de la configuration, de la sauvegarde, des commandes de voyage et de la supervision : tout passe) ; **intercom mis en pause** (bloc `Config.Intercom` en commentaire). |
| **V6.9.7** | 03/11 | **Corrections** : téléportation de poche en Silencieux qui bloquait le TARDIS, retour au départ si le joueur visé a quitté, vol libre qui se pose seul si le pilote ne répond plus (et se rematérialise s'il était invisible), chute dans le vide rattrapée, portée des sons limitée. 24 simulations, revue indépendante. |
| **V6.9.8** | 03/11 | **Vérification et outils de suivi** : vol en formation réglable (`Config.VolLibre.Formation`), thème clair Gallifrey lisible (fond des listes qui suit le thème), page d'[état des tests](docs/ETAT_DES_TESTS.md) (81 tests), textes de release prêts (`outils/release.py`, 15 versions), [glossaire](docs/GLOSSAIRE.md). 31 simulations. |
| **V6.9.9** | 05/11 | **Effets visuels du voyage** : air qui ondule plus fort en Urgence et en Catastrophe, marque au sol après chaque atterrissage, lueurs plus fortes la nuit, lumières de la salle selon l'état (bleu, ambre, cyan, rouge), Catastrophe plus violente (fumée noire, étincelles, éclats), vitres qui s'éteignent en dernier, option **« Aucun flash »**. 137 simulations. |
| **V6.9.10** | 05/11 | **Vol libre et vortex** : **croisière** (cap, altitude et vitesse tenus sans touche), **caméra en orbite** autour de la cabine (en croisière), **freinage d'urgence ressenti à bord** (secousse, fumée, son ; action `VolLibreFrein` vérifiée par le serveur), rotor qui suit la vitesse du vol libre, **vent du vortex** à bord. 170 simulations. |
| V6.9.11 | 06/11 | **Navigation et fiches de lieux** : favoris du copilote en tête de sa liste ; **point de base** des pilotes (raccourci « Base » dans le menu T, la tablette et le poste du copilote, sauvegardé) ; **zones à vitesse réduite** (`VITESSE_REDUITE` : Classique ou Silencieux seulement, une urgence imposée n'est jamais désarmée) ; **fiche du lieu** affichée à bord sous « POSÉ » (description, dangers, niveau 0-3) |
| V6.9.12 | 06/11 | **Pannes : le socle commun** : **fréquence des pannes réglable** (`FrequencePannes` : Aucune, Rare, Normale, Fréquente ; tirage pondéré) ; **rapport de panne** aux pilotes (« PANNE · EFFET SUR LE VOL · QUI RÉPARE ») ; **historique des 20 dernières pannes** dans la tablette technicien (début, fin, « réparé par ») ; **zone de chaque panne** (dossier `Zones` facultatif, sinon autour de la console ; même grille chez tous les joueurs) ; **sons des pannes** facultatifs (vapeur, feu, grincement, étincelles du rotor) |
| V6.9.13 | 06/11 | **Nouvelles pannes et outils du technicien** : **fuite d'air** (l'air baisse de 2 % toutes les 5 s, purge refusée ; colmater 4 s, visseuse ou clé à molette en main ; dossier `Conduits` facultatif, sinon une grille) ; **rotor bloqué** (« ROTOR BLOQUÉ » au voyage, au vol libre et à la poche, une seule vérification `Config.raisonBlocageDepart` ; maintenir E 6 s sur le rotor) ; **scanner** du technicien (bulle d'état de la pièce visée, lecture seule) ; **soudeur** et **brèche** (explosion ou intégrité sous 60 % ; 4 passages, +500 PV ; dossier `Structure` facultatif) ; modèles d'outils facultatifs dans `TardisAssets › Outils` |
| V6.9.14 | 06/11 | **Équipage et garde-robe** : **casier rangé par catégorie** (en-têtes, favoris en tête) et **5 nouvelles tenues** en attente (identifiants à 0 : cachées et jamais tirées tant qu'ils ne sont pas donnés), `regeneration = false` sur les tenues de fête ; **uniforme de l'équipe** à l'apparition et au changement d'équipe (`Config.Equipe.Uniforme`, `Config.EquipeTechnique.Uniforme`, 0 = rien ; jamais pendant une régénération, réglage fixe `ApresRegeneration`) ; **badges C.A.T. et C.T.A.T.** au-dessus de la tête (`Badge`, `BadgeImage` dans `TardisConfig`) ; **portes intérieures animées** (Models `Gauche` / `Droite` avec une Part `Charniere`, sinon le masquage d'avant) |
| V6.9.15 | 06/11 | **Confort de l'interface et accessibilité** : **effets réduits d'office sur téléphone** (choix du téléphone gardé à part) ; **sous-titres des sons** (démat, remat avec le mode, alarme, auto-destruction, explosion, musique du jukebox ; `Config.SousTitres`, option des réglages) ; **taille de l'interface partout** (copilote, intercom, caméra, TARDIS porté, cartes…, et menu fermé qui ne dépasse plus à grande taille) ; option **ouverture des menus sans animation** ; option **fermer la tablette d'un clic à côté** ; **menu rapide déplaçable** en glissant son en-tête (position gardée, « rétablir » dans les réglages) |
| V6.9.16 | 07/11 | **Retouches de la console** : invite **« Vol libre » plus basse** (0,9 stud) ; **écran ingénieur à l'endroit** (haut de la face Top vers -X) et **ouvert d'un simple clic** (plus d'invite ni de touche) ; menu de **gestion de l'énergie plus large** (760 px, deux colonnes : état détaillé avec pannes en cours, régulation avec les plages) ; **animations du kit jouées** quand une commande réussit (BindableEvent `TardisAnimer`) |
| V6.9.17 | 07/11 | **Maps en Streaming** : sur une map `StreamingEnabled`, l'intérieur posé directement dans `INTERIEURE` est **rangé au démarrage dans un Model Persistent** `<TARDIS>_INTERIEURE` (le menu T et la tablette Y s'ouvrent à nouveau) ; **diagnostic** « streaming : ok / à régler » ; l'**import de la structure** range aussi l'intérieur |
| V6.9.10.9 | 06/11 | **Le leurre disparaît à chaque départ** du TARDIS (dématérialisation, début du vol libre, saut en vol libre) ; la tuile « Leurre » de la tablette voit enfin le leurre actif (« ACTIF · retirer ») |
| V6.9.10.8 | 06/11 | **Invites de la console remises à leur place** (seule l'invite « Vol libre » reste 1,5 stud au-dessus de son bouton) ; **bouton Vol libre retrouvé** quand un nom de la map a des espaces en trop (« Selecteur␣ ») ; simulations aussi sous Windows |
| V6.9.10.7 | 06/11 | **Menus « Hologramme de confinement » (2e passage)** : **gestion de l'énergie** plus grande (segments, boutons de 44 px), **jukebox** en tableau (choisir puis JOUER), **casier** en panneau à droite, **écrans de la console** au nouveau style, message de la console, bandeau de maintenance et poste du copilote |
| V6.9.10.6 | 06/11 | **Menus « Hologramme de confinement » (1er passage)** : nouveau style par défaut (coins coupés, filet cyan, balayage, plaque avec badge, bande de danger rouge en alerte, jauges à segments) sur le **menu rapide** (tableau des destinations avec statut, ↑ ↓ Entrée), la **tablette** (onglets en colonne) et la **tablette technicien** (tableau des pannes) ; 3 images facultatives dans `assets/interface/` |
| V6.9.10.5 | 06/11 | **Retours du test dans Studio** : bouton **Vol libre** sur un Model (clic sur tout le Model, invites de la console relevées de 1,5 stud), **caméra du casier** qui évite les murs, **tenues** enfin visibles (module `TardisTenues` : vraie image de chaque vêtement du catalogue), **jukebox** rempli par un dossier de sons (`TardisAssets › Jukebox`), écran ingénieur qui remplit toute la face |
| V6.9.10.4 | 05/11 | **Sens du texte des écrans** : l'écran ingénieur tourne son affichage pour être lu à l'endroit (Roblox oriente la face Top vers la droite de la pièce) ; attribut `RotationEcran` (0, 90, 180, 270, Auto) ; sens donné dans l'Output |
| V6.9.10.3 | 05/11 | **Écrans de la console** : écrans de destination **nets** (1024 pixels sur le grand côté, quelle que soit la taille ; moins de lignes, plus grandes), **écran ingénieur visible** (nouvelle face `Auto` : la grande face tournée vers les joueurs ; Model pris en charge), ligne d'Output qui donne la face de chaque écran |
| V6.9.10.2 | 05/11 | **Nouvelle hiérarchie de l'intérieur** : le dossier `INTERIEURE` peut contenir directement les pièces (`Portail`, `Rotor`…) et devient alors la salle, ce qui **répare le portail** ; ancienne organisation toujours prise en charge ; fonctions communes `Config.boite`, `Config.pivot`, `Config.partPrincipale` ; spawns de Studio (`Spawn C.A.T`, `Spawn C.T.A.T`) réutilisés |
| V6.9.10.1 | 05/11 | **Ajustements Studio** : néons de la salle aux couleurs de l'état, **deux écrans de destination** faits en script (attribut `FaceEcran`), alerte sur `Datapanel › Redbutton › Button`, bouton **Vol libre** sur `Selecteur › Colors`, **interphone supprimé**, **écran ingénieur** avec menu de gestion de l'énergie, boutons du **casier** et du **jukebox** de la console ; corrections de la relecture indépendante (écrans hors tension, délai des ordres, touches Z des invites…). 179 simulations. |
| *V7* | *à venir* | *Modifications : 357 propositions du second tri, en 10 sous-versions ([plan](docs/PLAN_V7.md), [feuille de route](docs/FEUILLE_DE_ROUTE.md))* |
| *V8* | *à venir* | *Sécurisation des scripts* |
| *V9* | *à venir* | *Optimisation et nettoyage du code* |
| *V10* | *à venir* | *Refonte presque totale de l'organisation des fichiers* |
| *V11* | *à venir* | *Les 3 TARDIS officialisés, un TARDIS attribué à chaque pilote* |
| *V12* | *à venir* | *Plus de menu : boutons et écrans sur la console (V12.1 → V12.4 : TARDIS_1 ; V12.5 → V12.12 : ne seront pas faites)* |
