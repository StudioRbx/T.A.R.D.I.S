# Propositions — 29/10/2026 (après la V6.6)

25 modifications et 25 simplifications, tirées de la lecture du code (≈ 15 000 lignes) et de l'état de ZONE-TSADE. Rien n'est encore fait : c'est une liste de travail à trier.

---

## A. 25 modifications

### Mode Express (suite logique de la V6.6)
1. **Express en vol libre** : DÉMAT / REMAT en 2 s pendant le pilotage. Aujourd'hui, l'Express ne concerne que les voyages.
2. **Express pour la téléportation de poche et le levier de console**, avec une option `Config.LevierEnExpress`.
3. **Sons dédiés `Demat_Express` et `Remat_Express`**. Sans eux, le son normal est tronqué et coupé en fondu.
4. **Effet visuel propre** : flash blanc et onde de choc au sol, au lieu de 2 simples pulsations.
5. **Recharge de l'Express** (par exemple 30 s) pour éviter les allers-retours en boucle sur un serveur RP.
6. **Express interdit dans certaines zones** (sous-dossier `SANS_EXPRESS` des destinations), en plus de REFUSE.

### Livraison et installation
7. **Installer V6.5.13 et V6.5.14** : accessoires après régénération, et suppression de l'onglet à l'écran.
8. **Onglet tactile pour mobile** uniquement : sans clavier, un pilote ne peut plus ouvrir T ni Y.
9. **Remettre TARDIS_2 et TARDIS_3**, avec des intérieurs rangés comme TARDIS_1.
10. **Placer les objets manquants** : points `ZDC-…`, `Arrivee`, `Diagnostic1` à `4`, `Casier`, `Vanne`, `Murs` et `Sol`, `SiegeEquipage`.

### Pilotage et interface
11. **Interrupteurs synchronisés** : Urgence, Express et Invisible ont le même état dans le menu (T) et la tablette (Y). Ils sont indépendants aujourd'hui.
12. **Compte à rebours dans la salle** avant un départ (« Départ dans 3… 2… 1… »), surtout utile en Express.
13. **Historique marqué par mode** : une icône Urgence ou Express à côté de chaque voyage.
14. **Statistiques par mode** : voyages normaux, d'urgence et express, et temps gagné.
15. **Tablette technicien** (prévue depuis la V6.0) : toutes les infos, aucune commande de vol, et les commandes RP.
16. **Option « réduire les effets »** pour les joueurs sensibles : saccades d'urgence, flash, thème Flashbang.

### Intégration au jeu ZONE-TSADE
17. **Permissions par rang Adonis ou WL** : le jeu utilise déjà Adonis et `WLConfig`, alors que la liste des UserIds est écrite en dur.
18. **Journaux du TARDIS envoyés dans `RoSysLog`** (déjà présent dans ServerStorage) : décollages, auto-destruction, bannissements.
19. **Commande staff `/tardis statut`** : état, position, pilotes en ligne et dernière erreur.
20. **Détection par la Fondation** : une alerte sécurité quand un TARDIS se matérialise dans le site (idée de la V3.11 jamais réalisée).

### Contenu et RP
21. **Jukebox rempli** : `Config.Jukebox` est vide.
22. **Sons optionnels manquants** : `Camouflage`, `Cloitre`, `Moteur_*`, `Chute`, `Impact` et `Regeneration`.
23. **Crise post-régénération** : vision floue et démarche titubante pendant 1 min (idée de la V6.5.7 non retenue).
24. **Clé du TARDIS** : un outil donné aux techniciens pour ouvrir ou verrouiller à distance.
25. **Sauvegarde versionnée** (`TardisSauvegarde_v2` avec migration) pour pouvoir changer le format sans perdre les données.

---

## B. 25 simplifications

### Code partagé
1. **Un seul module de commandes** pour le menu et la tablette : `donneesDestination`, l'envoi de Démat / Remat et l'auto-remat de 15 s sont écrits deux fois.
2. **Un seul attribut `Mode`** (`Normal`, `Urgence`, `Express`) au lieu de deux booléens `Urgence` et `Express`.
3. **Une table `Config.Modes`** (`{ Normal = {...}, Urgence = {...}, Express = {...} }`) au lieu de 10 variables (`DureeDematUrg`, `DecalageRematUrg`…).
4. **Un helper unique pour la liste d'exclusion des raycasts** (TARDIS, intérieur, personnages), recopiée au moins 5 fois dans le serveur.
5. **Le pont `TardisInterne` en table de fonctions**, au lieu d'une chaîne de 17 `elseif`.
6. **Initialisation des attributs en boucle** sur une table de valeurs par défaut.
7. **Liste des sons partagée** entre le serveur (`LISTE_SONS`) et le préchargement côté client.
8. **Un seul format de réponse et d'alerte** (`repondre` / `alerter`) pour les 4 scripts serveur.
9. **Un journal unique à niveaux** (info, avertissement, debug) à la place de `Config.Debug` et des `print` / `warn` éparpillés.

### Découpage des gros scripts
10. **`TardisTablette` (2 955 lignes)** découpée en modules : Scanner, Carte, Outils, Réglages, Journal.
11. **`TardisExtrasClient` (2 022 lignes)** découpé par effet : hologramme, régénération, boucliers, casiers…
12. **`TardisServeur` (2 200 lignes)** : le vol libre dans un module à part.
13. **Supprimer les déclarations « définie plus bas »** en réordonnant le code : c'est la cause de 6 bugs « fonction appelée avant d'être définie » dans l'historique.

### Configuration
14. **Retirer les réglages morts** : `Config.NomExterieur`, `Config.NomInterieur` et le commentaire `RangMin`, inutilisés depuis la V6.
15. **Listes par TARDIS sans doublons** : les pilotes globaux sont recopiés dans `TARDIS_1`, ce qui n'a aucun effet.
16. **Chemins des commandes par tag (CollectionService)** au lieu de chemins en dur (`Config.Chemins`). Déplacer un bouton ne casserait plus rien.
17. **Renommer `Tardisporter` en `TardisPorter`**, pour suivre la convention de nommage.

### Modèle Studio
18. **Supprimer les scripts du kit désactivés** (`Default Mainscript`, `README:`, les `Move` / `MainPhase` désactivés…) plutôt que de les garder éteints.
19. **Supprimer les `Move` des portes du kit** : leurs ClickDetectors sont coupés par le serveur depuis la V4.0.
20. **Diagnostic automatique au démarrage** : une ligne « TARDIS_1 : 12/12 pièces obligatoires, 3/11 optionnelles » au lieu de commandes à coller.

### Interface et prise en main
21. **Vol libre : 21 boutons → 8**, les modes rares (planeur, cap fixe, compteur G…) étant regroupés dans un sous-menu.
22. **Mode débutant par défaut** pour un nouveau pilote.
23. **Une seule interface** : le menu rapide (T) comme vue réduite de la tablette, au lieu de deux scripts séparés.

### Livraison
24. **Projet Rojo** (`default.project.json`) pour synchroniser le dépôt et Studio, au lieu des ZIP et copier-coller.
25. **Releases GitHub par version** à la place des ZIP envoyés dans la conversation.
