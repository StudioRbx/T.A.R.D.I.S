# Feuille de route — V7 à V12

> Fixée le 02/11/2026, revue le même jour : la **sécurisation** (V8) et le **nettoyage** (V9) passent devant ; les versions prévues avant
> deviennent V10, V11 et V12. **Revue le 03/11/2026 après le tri des 200 propositions** : les 110 propositions gardées sont réparties
> dans des sous-versions (V6.9.7 → V6.9.15 avant la V8, puis V8.x, V9.x, V10, V11.x et V12.x) : voir **[Plan des 110 propositions gardées](#plan-des-110-propositions-gardées)**.
> **Revue le 05/11/2026 après le second tri (1200 propositions)** : les 357 gardées forment la nouvelle **V7 « Modifications »**
> (10 sous-versions, 52 sous-sous-versions de 10 propositions au plus : voir [PLAN_V7.md](PLAN_V7.md)) ; les versions suivantes sont décalées de +1.
> Pour chaque version : **le sujet** (décidé) puis **ce que ça implique** dans le code actuel (à valider ensemble avant de commencer).

| Version | Sujet | État |
|---|---|---|
| V6.9.7 | Corrections : TARDIS bloqué ou perdu | ✅ faite (03/11) |
| V6.9.8 | Vérification et outils de suivi | ✅ faite (03/11) |
| V6.9.9 | Effets visuels du voyage | ✅ faite (05/11) |
| V6.9.10 | Vol libre et vortex | ✅ faite (05/11) |
| V6.9.11 | Navigation et fiches de lieux | ✅ faite (06/11) |
| V6.9.12 | Pannes : le socle commun | ✅ faite (06/11) |
| V6.9.13 | Nouvelles pannes et outils du technicien | ✅ faite (06/11) |
| V6.9.14 | Équipage et garde-robe | ✅ faite (06/11) |
| V6.9.15 | Confort de l'interface et accessibilité | ✅ faite (06/11) |
| V6.9.16 | Retouches de la console (demandées après les tests) | ✅ faite (07/11) |
| V6.9.17 | Maps en Streaming (menu T et tablette Y) | ✅ faite (07/11) |
| **V7** | Modifications : 357 propositions du second tri | 🚧 en cours |
| V7.1 | Corrections et banc d'essai (2 lots) | ✅ faite (07/11) |
| V7.1.1 | Corrections et oublis du code actuel | ✅ faite (07/11) |
| V7.1.2 | Banc d'essai des simulations | ✅ faite (07/11) |
| V7.2 | Cabine et monde extérieur (4 lots) | 🚧 en cours |
| V7.2.1 | Cabine : lampe et vitres vivantes | ✅ faite (07/11) |
| V7.2.2 | Traces au sol à l'arrivée | ✅ faite (07/11) |
| V7.3 | Salle de contrôle et console (5 lots) | 🔜 prévue |
| V7.4 | Caméras et confort de l'écran (2 lots) | 🔜 prévue |
| V7.5 | Régénération de la C.A.T. (6 lots) | 🔜 prévue |
| V7.6 | Vol libre et rayon tracteur (5 lots) | 🔜 prévue |
| V7.7 | Systèmes du TARDIS (7 lots) | 🔜 prévue |
| V7.8 | Voyage : modes, zones et destinations (11 lots) | 🔜 prévue |
| V7.9 | Équipage, visiteurs et RP (7 lots) | 🔜 prévue |
| V7.10 | Sauvegarde et plusieurs TARDIS (3 lots) | 🔜 prévue |
| **V8** | Sécurisation des scripts | 🔜 prévue |
| **V9** | Optimisation et nettoyage du code | 🔜 prévue |
| **V10** | Refonte presque totale de l'organisation des fichiers | 🔜 prévue |
| **V11** | Les 3 TARDIS officialisés, un TARDIS attribué à chacun des trois pilotes | 🔜 prévue |
| **V12** | Plus de menu : tout passe par la console de commande et ses écrans | 🔜 prévue |
| V12.1 → V12.4 | TARDIS_1 | 🔜 prévue |
| V12.5 → V12.8 | TARDIS_3 | ✖ ne sera pas fait |
| V12.9 → V12.12 | TARDIS_2 | ✖ ne sera pas fait |

---

## Roadmap GitHub : types, priorités et dates

Chaque version a sa carte dans le [projet GitHub T.A.R.D.I.S.](https://github.com/orgs/StudioRbx/projects/4), avec un **type** (🐛 bug, ✨ fonctionnalité, 🔧 tâche technique), une **priorité**, un **effort** et des **dates** (début, fin) qui alimentent la vue Roadmap. Chronologie complète : [#130](https://github.com/StudioRbx/T.A.R.D.I.S/issues/130).

Dates **indicatives** (réglées le 03/11/2026) : environ 2 jours par lot avant la V8, puis 3 à 4 jours par lot ; la V10, un seul gros lot, a une semaine. Elles glissent si les tests en jeu demandent des corrections.

| Lot | Carte | Type | Priorité | Effort | Début → fin |
|---|---|---|---|---|---|
| **Avant la V8 · Propositions gardées** | [#89](https://github.com/StudioRbx/T.A.R.D.I.S/issues/89) | ✨ Fonctionnalité | 🟠 Haute | gros | 03/11 → 17/11 |
| ✅ V6.9.7 — Corrections : TARDIS bloqué ou perdu | [#90](https://github.com/StudioRbx/T.A.R.D.I.S/issues/90) | 🐛 Bug | faite | moyen | 03/11 → 03/11 |
| ✅ V6.9.8 — Vérification et outils de suivi | [#91](https://github.com/StudioRbx/T.A.R.D.I.S/issues/91) | 🔧 Tâche | faite | moyen | 03/11 → 03/11 |
| V6.9.9 — Effets visuels du voyage | [#92](https://github.com/StudioRbx/T.A.R.D.I.S/issues/92) | ✨ Fonctionnalité | 🟠 Haute | moyen | 04/11 → 05/11 |
| V6.9.10 — Vol libre et vortex | [#93](https://github.com/StudioRbx/T.A.R.D.I.S/issues/93) | ✨ Fonctionnalité | 🟡 Moyenne | moyen | 06/11 → 07/11 |
| ✅ V6.9.11 — Navigation et fiches de lieux | [#94](https://github.com/StudioRbx/T.A.R.D.I.S/issues/94) | ✨ Fonctionnalité | faite | petit | 06/11 → 06/11 |
| ✅ V6.9.12 — Pannes : le socle commun | [#95](https://github.com/StudioRbx/T.A.R.D.I.S/issues/95) | ✨ Fonctionnalité | faite | moyen | 06/11 → 06/11 |
| ✅ V6.9.13 — Nouvelles pannes et outils du technicien | [#96](https://github.com/StudioRbx/T.A.R.D.I.S/issues/96) | ✨ Fonctionnalité | faite | gros | 06/11 → 06/11 |
| ✅ V6.9.14 — Équipage et garde-robe | [#97](https://github.com/StudioRbx/T.A.R.D.I.S/issues/97) | ✨ Fonctionnalité | faite | moyen | 06/11 → 06/11 |
| ✅ V6.9.15 — Confort de l'interface et accessibilité | [#98](https://github.com/StudioRbx/T.A.R.D.I.S/issues/98) | ✨ Fonctionnalité | faite | moyen | 06/11 → 06/11 |
| **V8 · Sécurisation des scripts** | [#99](https://github.com/StudioRbx/T.A.R.D.I.S/issues/99) | 🔧 Tâche | 🟠 Haute | gros | 18/11 → 28/11 |
| V8 — Sécurité : banc d'essai, audits et sauvegarde | [#100](https://github.com/StudioRbx/T.A.R.D.I.S/issues/100) | 🔧 Tâche | 🟠 Haute | gros | 18/11 → 21/11 |
| V8.1 — Sécurité : garde-barrière unique et pont interne | [#101](https://github.com/StudioRbx/T.A.R.D.I.S/issues/101) | 🔧 Tâche | 🟠 Haute | moyen | 22/11 → 25/11 |
| V8.2 — Sécurité : schéma des données et tests de triche | [#102](https://github.com/StudioRbx/T.A.R.D.I.S/issues/102) | 🔧 Tâche | 🟠 Haute | gros | 26/11 → 28/11 |
| **V9 · Optimisation et nettoyage du code** | [#103](https://github.com/StudioRbx/T.A.R.D.I.S/issues/103) | 🔧 Tâche | 🟠 Haute | gros | 29/11 → 12/12 |
| V9 — Nettoyage : journal, mesure et code mort | [#104](https://github.com/StudioRbx/T.A.R.D.I.S/issues/104) | 🔧 Tâche | 🟠 Haute | moyen | 29/11 → 01/12 |
| V9.1 — Sons : liste unique et volumes par catégorie | [#105](https://github.com/StudioRbx/T.A.R.D.I.S/issues/105) | 🔧 Tâche | 🟡 Moyenne | moyen | 02/12 → 04/12 |
| V9.2 — Code partagé et ordre des fonctions | [#106](https://github.com/StudioRbx/T.A.R.D.I.S/issues/106) | 🔧 Tâche | 🟡 Moyenne | petit | 05/12 → 07/12 |
| V9.3 — Boucles par image et effets à distance | [#107](https://github.com/StudioRbx/T.A.R.D.I.S/issues/107) | 🔧 Tâche | 🟡 Moyenne | gros | 08/12 → 10/12 |
| V9.4 — Moins d'attributs envoyés sur le réseau | [#108](https://github.com/StudioRbx/T.A.R.D.I.S/issues/108) | 🔧 Tâche | 🟡 Moyenne | moyen | 11/12 → 12/12 |
| **V10 · Refonte de l'organisation des fichiers** | [#109](https://github.com/StudioRbx/T.A.R.D.I.S/issues/109) | 🔧 Tâche | 🟡 Moyenne | gros | 13/12 → 19/12 |
| V10 — Guide d'installation | [#110](https://github.com/StudioRbx/T.A.R.D.I.S/issues/110) | 🔧 Tâche | 🟡 Moyenne | moyen | 13/12 → 19/12 |
| **V11 · Les 3 TARDIS, un par pilote** | [#112](https://github.com/StudioRbx/T.A.R.D.I.S/issues/112) | ✨ Fonctionnalité | 🟠 Haute | gros | 20/12 → 18/01/27 |
| V11.1 — Régénération : nouveaux styles et choix du style | [#113](https://github.com/StudioRbx/T.A.R.D.I.S/issues/113) | ✨ Fonctionnalité | 🟡 Moyenne | moyen | 20/12 → 23/12 |
| V11.2 — Régénération : fins et réactions | [#114](https://github.com/StudioRbx/T.A.R.D.I.S/issues/114) | ✨ Fonctionnalité | 🟢 Basse | moyen | 24/12 → 27/12 |
| V11.3 — Départ annulable et remat ratée | [#115](https://github.com/StudioRbx/T.A.R.D.I.S/issues/115) | ✨ Fonctionnalité | 🟡 Moyenne | moyen | 28/12 → 30/12 |
| V11.4 — Voyage de groupe synchronisé | [#116](https://github.com/StudioRbx/T.A.R.D.I.S/issues/116) | ✨ Fonctionnalité | 🟡 Moyenne | gros | 31/12 → 03/01/27 |
| V11.5 — Accès à bord : sonnette, passages secrets, chambres | [#117](https://github.com/StudioRbx/T.A.R.D.I.S/issues/117) | ✨ Fonctionnalité | 🟡 Moyenne | gros | 04/01/27 → 07/01/27 |
| V11.6 — Nouvelles salles : machines, infirmerie, bibliothèque | [#118](https://github.com/StudioRbx/T.A.R.D.I.S/issues/118) | ✨ Fonctionnalité | 🟡 Moyenne | gros | 08/01/27 → 11/01/27 |
| V11.7 — Réglages personnels hors de la tablette | [#119](https://github.com/StudioRbx/T.A.R.D.I.S/issues/119) | ✨ Fonctionnalité | 🟠 Haute | moyen | 12/01/27 → 14/01/27 |
| V11.8 — Textes à clés et langue anglaise | [#120](https://github.com/StudioRbx/T.A.R.D.I.S/issues/120) | ✨ Fonctionnalité | 🟡 Moyenne | gros | 15/01/27 → 18/01/27 |
| **V12 · La console remplace le menu (TARDIS_1)** | [#121](https://github.com/StudioRbx/T.A.R.D.I.S/issues/121) | ✨ Fonctionnalité | 🟡 Moyenne | gros | 19/01/27 → 10/02/27 |
| V12.1.1 — Écrans de la console : accueil, équipage, statistiques | [#122](https://github.com/StudioRbx/T.A.R.D.I.S/issues/122) | ✨ Fonctionnalité | 🟡 Moyenne | moyen | 19/01/27 → 22/01/27 |
| V12.1.2 — Écrans de la console : journal de l'équipage | [#123](https://github.com/StudioRbx/T.A.R.D.I.S/issues/123) | ✨ Fonctionnalité | 🟡 Moyenne | moyen | 23/01/27 → 25/01/27 |
| V12.1.3 — Écrans de la console : parasites et panne d'écrans | [#124](https://github.com/StudioRbx/T.A.R.D.I.S/issues/124) | ✨ Fonctionnalité | 🟢 Basse | moyen | 26/01/27 → 28/01/27 |
| V12.2 — Boutons de navigation de la console | [#125](https://github.com/StudioRbx/T.A.R.D.I.S/issues/125) | ✨ Fonctionnalité | 🟡 Moyenne | moyen | 29/01/27 → 02/02/27 |
| V12.3 — Boutons des systèmes : énergie, Artron et décoratifs | [#126](https://github.com/StudioRbx/T.A.R.D.I.S/issues/126) | ✨ Fonctionnalité | 🟡 Moyenne | gros | 03/02/27 → 06/02/27 |
| V12.4 — Retrait de T et Y sur TARDIS_1 : ce qui reste à l'écran | [#127](https://github.com/StudioRbx/T.A.R.D.I.S/issues/127) | ✨ Fonctionnalité | 🟡 Moyenne | gros | 07/02/27 → 10/02/27 |
| ✖ V12.5 → V12.8 — Console de commande de TARDIS_3 | [#128](https://github.com/StudioRbx/T.A.R.D.I.S/issues/128) | ✨ Fonctionnalité | ne sera pas fait | petit | — |
| ✖ V12.9 → V12.12 — Console de commande de TARDIS_2 | [#129](https://github.com/StudioRbx/T.A.R.D.I.S/issues/129) | ✨ Fonctionnalité | ne sera pas fait | petit | — |

**Bilan des versions faites** (cartes fermées) : 64 ✨ Fonctionnalité, 16 🔧 Tâche, 10 🐛 Bug.

**Comment c'est décidé :** 🐛 bug = la version corrige surtout des défauts ; ✨ fonctionnalité = elle ajoute surtout quelque chose de visible en jeu ; 🔧 tâche = travail technique sans nouveauté pour le joueur (sécurité, nettoyage, organisation, outils, docs). Priorité : 🟠 haute = prochain lot, sécurité (V8) ou prérequis de beaucoup d'autres lots ; 🟡 moyenne = fonctionnalité prévue utile ; 🟢 basse = mise en scène, polish. Une étape prend la priorité la plus haute de ses lots ouverts.

---
## V7 — Modifications

**Sujet :** les 357 propositions gardées au second tri des 1200 (05/11/2026) : surtout des graphismes (187) et des changements de jeu (155), plus 12 techniques et 3 de menus.

**Structure :** 1 version, 10 sous-versions (V7.1 à V7.10), chacune découpée en sous-sous-versions (V7.x.y) de 10 propositions au plus. Le détail de chaque sous-sous-version (propositions, Studio, raison de sa place) est dans **[PLAN_V7.md](PLAN_V7.md)**.

| Sous-version | Sous-sous-versions | Propositions | Dates prévues |
|---|---|---|---|
| **V7.1 — Corrections et banc d'essai** | V7.1.1, V7.1.2 | 14 | 18/11 → 21/11 |
| **V7.2 — Cabine et monde extérieur** | V7.2.1, V7.2.2, V7.2.3, V7.2.4 | 29 | 22/11 → 29/11 |
| **V7.3 — Salle de contrôle et console** | V7.3.1, V7.3.2, V7.3.3, V7.3.4, V7.3.5 | 31 | 30/11 → 09/12 |
| **V7.4 — Caméras et confort de l'écran** | V7.4.1, V7.4.2 | 15 | 10/12 → 13/12 |
| **V7.5 — Régénération de la C.A.T.** | V7.5.1, V7.5.2, V7.5.3, V7.5.4, V7.5.5, V7.5.6 | 38 | 14/12 → 25/12 |
| **V7.6 — Vol libre et rayon tracteur** | V7.6.1, V7.6.2, V7.6.3, V7.6.4, V7.6.5 | 37 | 26/12 → 04/01/27 |
| **V7.7 — Systèmes du TARDIS** | V7.7.1, V7.7.2, V7.7.3, V7.7.4, V7.7.5, V7.7.6, V7.7.7 | 53 | 05/01/27 → 18/01/27 |
| **V7.8 — Voyage : modes, zones et destinations** | V7.8.1, V7.8.2, V7.8.3, V7.8.4, V7.8.5, V7.8.6, V7.8.7, V7.8.8, V7.8.9, V7.8.10, V7.8.11 | 76 | 19/01/27 → 09/02/27 |
| **V7.9 — Équipage, visiteurs et RP** | V7.9.1, V7.9.2, V7.9.3, V7.9.4, V7.9.5, V7.9.6, V7.9.7 | 45 | 10/02/27 → 23/02/27 |
| **V7.10 — Sauvegarde et plusieurs TARDIS** | V7.10.1, V7.10.2, V7.10.3 | 19 | 24/02/27 → 01/03/27 |

**Ordre :** corrections et banc d'essai d'abord, puis la cabine, la salle, les caméras, la régénération, le vol libre, les systèmes, le voyage, l'équipage, et enfin la sauvegarde et la préparation des 3 TARDIS. Une règle de jeu passe avant son effet visuel ; un socle passe avant ce qui l'utilise.

**Décisions à prendre avant certains lots :** signal d'orage (G-31, V7.2.4) ; option pour couper le départ portes ouvertes (C-17, V7.8.2) ; vraie mort ou non (V7.5.5) ; pilotage à distance réservé coupé par défaut (C-97).

---
## V8 — Sécurisation des scripts

**Sujet :** sécuriser les scripts.

**Aujourd'hui :**
- le serveur vérifie déjà les droits de chaque commande (pilote, copilote, technicien), la fréquence (`Config.Cooldown`) et les types principaux ;
- mais chaque script serveur (`TardisServeur`, `TardisExtras`, `TardisSystemes`) a son propre `OnServerEvent` sur le même RemoteEvent, avec ses propres contrôles, écrits à la main action par action ;
- le vol libre accepte environ 15 positions par seconde venues du client.

**Ce que ça contient (d'après le tri du 03/11) :**
- **Banc d'essai d'abord** (185) : les simulations couvrent aussi le serveur de voyage, le copilote et la maintenance, pour vérifier que rien ne casse pendant la sécurisation.
- **Un seul garde-barrière** (156) pour le RemoteEvent : la liste des actions permises et, pour chacune, qui peut l'envoyer.
- **Schéma des données par action** (157) : types, bornes et longueur de chaque champ envoyé par le client.
- **Attributs** (166) : audit automatique, rien de ce que lit le serveur ne doit venir d'un client.
- **Tests de triche** (167) : des simulations qui envoient de fausses requêtes et vérifient qu'elles sont refusées, et que les vraies passent.
- **Sauvegarde protégée** (168) : taille maximale et schéma vérifié à la lecture.
- **Pont interne protégé** (169, avec le pont en table 172) : liste blanche des actions internes.
- **Verrou d'urgence** (170) : une option qui coupe toutes les commandes si une faille est découverte.
- **Refus clairs pour les visiteurs** (194) : chacun voit ce qu'il peut faire ou non.
- **Écarté au tri** (ne sera pas fait) : limite de fréquence générale par joueur et par action (158), vitesse du vol libre plafonnée par le serveur (159), positions hors carte refusées (160), distance vérifiée pour les actions à bord (161), refus général des nombres invalides (162), filtre et longueur généralisés à tous les textes (163), compteur de refus (164), expulsion automatique des tricheurs (165).

---

## V9 — Optimisation et nettoyage du code

**Sujet :** optimisation et nettoyage du code (contenu laissé à mon choix).

**Ce que ça contient (d'après le tri du 03/11) :**
- **Journal et mesures** : journal à niveaux (175), compteur de temps par module (181), code mort supprimé (176), configuration validée au démarrage (183).
- **Sons** : une seule liste partagée (173), préchargement au bon moment (182), volume et interrupteur par catégorie de son (132, 133, 82).
- **Code partagé** : un utilitaire unique pour les raycasts (171), fonctions « définies plus bas » réordonnées (184).
- **Performance** : boucles par image regroupées (177), effets coupés loin du joueur (178) et allégés quand les images par seconde baissent (47), moins d'attributs envoyés sur le réseau (180).
- **Plus tard** (pas dans la V9) : format de réponse unique (174), moins d'objets créés par image (179).
- **Comportement identique en jeu**, sauf les réglages de volume par catégorie (seul changement visible, signalé dans la note de version). Vérifié par les simulations et les tableaux « À tester ».

---

## V10 — Refonte de l'organisation des fichiers

**Sujet :** refonte presque totale de l'organisation des fichiers.

**Aujourd'hui :**
- 3 services (`ReplicatedStorage`, `ServerScriptService`, `StarterPlayerScripts`), environ 19 500 lignes ;
- quelques très gros scripts : `TardisServeur` (≈ 2 200 lignes), `TardisVolLibre` client (≈ 1 600), `TardisExtras` (≈ 1 500), `TardisSystemes` (≈ 1 300), `TardisEffets` (≈ 1 100), `TardisMenu` (≈ 900) ;
- les fonctionnalités sont réparties par ordre d'arrivée, pas par sujet. Exemples : le carnet de bord est dans `TardisExtras`, la clé dans `TardisSystemes`, le copilote dans `TardisServeur` ;
- chaque script est cloné une fois par TARDIS (`Config.demarrerPourChaqueTardis`) ;
- `TardisConfig` fait ≈ 800 lignes d'un seul tenant.

**Ce que ça implique (proposition) :**
- **Un dossier par domaine**, côté serveur comme côté client :

  | Dossier | Contenu |
  |---|---|
  | `Voyage` | démat, remat, modes, destinations, paradoxe |
  | `VolLibre` | vol libre |
  | `Systemes` | énergie, air, pannes, boucliers, siège |
  | `Equipage` | pilotes, techniciens, copilote, rôles, bannissements |
  | `Bord` | carnet, jukebox, intercom, ambiance |
  | `Supervision` | accès Adonis / WL, journal, erreurs, maintenance |
  | `Sauvegarde` | sauvegarde |
  | `Interface` | menus, tablette, poste du copilote |
  | `Effets` | effets visuels et sonores |

- **Un seul point d'entrée** par côté : un Script serveur et un LocalScript client, qui chargent les modules de chaque domaine. On n'a plus de scripts qui se parlent par RemoteEvent et BindableFunction « parce qu'ils sont séparés ».
- **`TardisConfig` découpée** en un module par domaine, avec les réglages de chaque TARDIS à part. Cela prépare la V11.
- **Comportement identique en jeu** : aucune nouveauté dans la V10, seulement des déplacements. Les simulations (`outils/simulation`) et les tableaux « À tester » des patch notes servent à vérifier que tout marche comme avant.
- `outils/synchro_studio.luau` et le README mis à jour pour la nouvelle arborescence.

À décider : les noms exacts des dossiers, et si on garde la convention Rojo actuelle (`.server.lua`, `.client.lua`, dossier + `init`).

---

## V11 — Les 3 TARDIS, un par pilote

**Sujet :** création des 3 TARDIS pour les officialiser ; chacun des trois pilotes a **son** TARDIS attribué, sans possibilité d'en choisir un autre.

**Aujourd'hui :**
- `Config.Tardis` ne contient que `TARDIS_1` (TARDIS_2 et TARDIS_3 sont en commentaire depuis le 18/10) ;
- les intérieurs de TARDIS_2 et TARDIS_3 ne sont pas rangés comme celui de TARDIS_1 (modifications 9 et 10 de PROPOSITIONS) ;
- un joueur peut être pilote de plusieurs TARDIS : liste globale `Config.Pilotes`, accès Adonis / WL de la V6.8 qui vaut pour tous les TARDIS, rôles temporaires.

**Ce que ça implique :**
- les 3 TARDIS déclarés et leurs modèles rangés dans Studio (Racine, Lampe, Console, Rotor, points `Arrivee`, destinations…) ;
- **un pilote = un TARDIS** : chaque pilote est rattaché à un seul TARDIS. Le serveur refuse toute commande sur un autre TARDIS, et les interfaces n'affichent que le sien ;
- la liste globale `Config.Pilotes` et l'accès Adonis / WL deviennent « pilote **de** TARDIS_x », pas « pilote de tous » ;
- même règle à décider pour les techniciens, les pilotes temporaires et le copilote (aujourd'hui, rien ne leur interdit d'aider sur un autre TARDIS) ;
- sauvegarde, statistiques, carnet de bord et journal déjà séparés par TARDIS : rien à changer de ce côté.

À fournir : **les UserIds des trois pilotes** et le TARDIS de chacun.

---

## V12 — La console remplace le menu

**Sujet :** retrait du menu principal (options). Tous les boutons du menu sont **sur la console de commande**. Les affichages (radar, vie du TARDIS, etc.) sont sur des **écrans de la console**.

**Aujourd'hui :** le pilote commande par le menu rapide (touche T), la tablette (touche Y, avec le vol libre et les outils), les boutons tactiles sur mobile, et quelques prompts sur la console (levier, sélecteur).

**Ce que ça implique :**
- des **écrans** (SurfaceGui sur des pièces de la console) : état et mode, radar / mini-carte, intégrité, énergie, air, boucliers, destination, journal ;
- des **boutons physiques** sur la console (clic ou prompt) pour chaque commande du menu : destinations, modes, DÉMAT / REMAT, portes, verrou, camouflage, boucliers, siège, alerte, etc. ;
- la console devra contenir des pièces nommées pour chaque écran et chaque bouton (à placer dans Studio) ;
- retrait des menus T et Y une fois que tout est sur la console.

**Découpage :**
| Sous-version | TARDIS | Contenu (proposition) |
|---|---|---|
| V12.1 | TARDIS_1 | Écrans d'affichage (lecture seule) |
| V12.2 | TARDIS_1 | Boutons de navigation : destinations, modes, DÉMAT / REMAT |
| V12.3 | TARDIS_1 | Boutons des systèmes : portes, verrou, camouflage, boucliers, siège, alerte, énergie |
| V12.4 | TARDIS_1 | Retrait du menu T et de la tablette Y, derniers réglages |
| V12.5 → V12.8 | TARDIS_3 | ✖ ne sera pas fait |
| V12.9 → V12.12 | TARDIS_2 | ✖ ne sera pas fait |

Questions ouvertes :
- le **vol libre** (piloté aujourd'hui depuis la tablette) ;
- les **joueurs sur mobile** ;
- le **poste du copilote** et la **tablette technicien**.

Restent-ils des interfaces à l'écran, ou passent-ils aussi par la console ?

---

## Plan des 110 propositions gardées

> Construit le 03/11/2026 par une analyse du code (110 propositions lues une à une), 3 plans indépendants (valeur pour les joueurs, dépendances et risque,
> par système), 3 juges, une synthèse et une critique de complétude. Chaque proposition gardée est dans **exactement un** lot. Le détail de chaque
> proposition (ce qui existe déjà, fichiers, approche) est dans [ANALYSE_PROPOSITIONS.md](ANALYSE_PROPOSITIONS.md).

| Version | Lot | Propositions |
|---|---|---|
| **V6.9.7** | Corrections : TARDIS bloqué ou perdu | 141, 9, 24, 108, 134 |
| **V6.9.8** | Vérification et outils de suivi | 27, 51, 69, 71, 198, 199, 200 |
| **V6.9.9** | Effets visuels du voyage | 36, 38, 46, 53, 43, 41, 191 |
| **V6.9.10** | Vol libre et vortex | 23, 26, 30, 52, 136 |
| **V6.9.11** | Navigation et fiches de lieux | 1, 8, 16, 144 |
| **V6.9.12** | Pannes : le socle commun | 117, 125, 129, 122, 142 |
| **V6.9.13** | Nouvelles pannes et outils du technicien | 118, 119, 127, 128 |
| **V6.9.14** | Équipage et garde-robe | 63, 90, 89, 54 |
| **V6.9.15** | Confort de l'interface et accessibilité | 188, 190, 72, 81, 78, 80 |
| **V8** | Sécurité : banc d'essai, audits et sauvegarde | 185, 166, 168 |
| **V8.1** | Sécurité : garde-barrière unique et pont interne | 156, 170, 172, 169, 194 |
| **V8.2** | Sécurité : schéma des données et tests de triche | 157, 167 |
| **V9** | Nettoyage : journal, mesure et code mort | 175, 181, 176, 183 |
| **V9.1** | Sons : liste unique et volumes par catégorie | 173, 132, 182, 82, 133 |
| **V9.2** | Code partagé et ordre des fonctions | 171, 184 |
| **V9.3** | Boucles par image et effets à distance | 177, 178, 47 |
| **V9.4** | Moins d'attributs envoyés sur le réseau | 180 |
| **V10** | Guide d'installation | 196 |
| **V11.1** | Régénération : nouveaux styles et choix du style | 103, 104, 102 |
| **V11.2** | Régénération : fins et réactions | 107, 114, 115 |
| **V11.3** | Départ annulable et remat ratée | 11, 45 |
| **V11.4** | Voyage de groupe synchronisé | 18 |
| **V11.5** | Accès à bord : sonnette, passages secrets, chambres | 68, 93, 57 |
| **V11.6** | Nouvelles salles : machines, infirmerie, bibliothèque | 58, 59, 56 |
| **V11.7** | Réglages personnels hors de la tablette | 193, 186, 187 |
| **V11.8** | Textes à clés et langue anglaise | 85 |
| **V12.1.1** | Écrans de la console : accueil, équipage, statistiques | 86, 79, 76 |
| **V12.1.2** | Écrans de la console : journal de l'équipage | 96, 113, 106 |
| **V12.1.3** | Écrans de la console : parasites et panne d'écrans | 64, 120 |
| **V12.2** | Boutons de navigation de la console | 137, 77, 138 |
| **V12.3** | Boutons des systèmes : énergie, Artron et décoratifs | 17, 131, 66 |
| **V12.4** | Retrait de T et Y sur TARDIS_1 : ce qui reste à l'écran | 101, 192, 29, 84 |

### V6.9.7 — Corrections : TARDIS bloqué ou perdu ✅ faite (03/11)

**Objectif :** Corriger les cas où le TARDIS reste bloqué (occupé, dans le vortex, en l'air), où un pilote enchaîne les régénérations dans le vide, et où les sons de voyage s'entendent de trop loin.

- **141. Silence total en Silencieux à bord aussi** *(en partie déjà là)* : Option : le Silencieux coupe aussi les sons à l'intérieur.
- **9. Voyage vers un joueur hors ligne refusé proprement** *(en partie déjà là)* : Message clair si le joueur visé a quitté pendant le vol, avec repli sur le lieu précédent.
- **24. Retour au sol automatique** *(en partie déjà là)* : Si le pilote se déconnecte en vol, le TARDIS descend en douceur au lieu de rester figé.
- **108. Régénération dans le vide** : Gérer proprement une mort par chute hors de la carte.
- **134. Sons 3D dehors** *(en partie déjà là)* : Les sons de voyage s'entendent plus fort près de la cabine et faiblissent avec la distance.

**Dans Studio :** Rien à construire. Scénarios à jouer en Play : téléportation de poche en mode Silencieux ; joueur visé qui quitte le jeu pendant une remat ; pilote qui se déconnecte en vol libre invisible, puis pilote qui ne bouge plus ; chute d'un membre de la C.A.T. sous la limite du vide ; écoute d'un son Demat posé à la main à 50, 150 et 300 studs.

*Pourquoi ici :* Ce sont des défauts actifs : ils passent avant toute nouveauté. Le plus urgent est la 141 : en poche, le mode Silencieux fait planter le script juste après partage.occupe = true, et un client modifié peut le provoquer exprès. Les autres corrections sont petites, côté serveur et à faible risque : 9 (TARDIS laissé dans le vortex), 24 (pilote muet ou déconnecté pendant qu'il est invisible ; avancée depuis la V8 parce que c'est un blocage), 108 (régénérations en boucle dans le vide) et 134 (sons posés à la main audibles à 10 000 studs). Les cinq cas se testent en une seule session.

### V6.9.8 — Vérification et outils de suivi ✅ faite (03/11)

**Objectif :** Confirmer et marquer comme faites les quatre propositions qui existent déjà, puis mettre en place la page d'état des tests, le script de publication et le glossaire, qui serviront à toutes les versions suivantes.

- **27. Vol en formation avec un joueur** *(déjà fait : à vérifier en jeu et cocher)* : Suivre automatiquement un joueur ou un véhicule à distance fixe.
- **51. Écran de destination sur la console** *(déjà fait : à vérifier en jeu et cocher)* : La destination choisie s'affiche sur un écran physique de la console.
- **69. Recherche dans les destinations** *(déjà fait : à vérifier en jeu et cocher)* : Un champ de recherche dans le menu rapide aussi (pas seulement la tablette).
- **71. Thème clair de la tablette** *(déjà fait : à vérifier en jeu et cocher)* : Un thème clair pour la tablette, en plus des thèmes sombres.
- **198. Releases GitHub automatiques** *(en partie déjà là)* : Un modèle de release pour chaque version, prêt à publier.
- **199. Page d'état des tests** *(en partie déjà là)* : Une page qui liste ce qui a été testé en jeu, version par version.
- **200. Glossaire du TARDIS** : Un lexique des termes (démat, remat, vortex, modes, équipes).

**Dans Studio :** Rien à construire. Vérifier en jeu : verrouillage de cible du vol libre (touche L), écran DESTINATION de la console, recherche du menu T, thème clair Gallifrey. Donner ensuite les résultats des tableaux « À tester » de V6.7 à V6.9.7, pour remplir docs/ETAT_DES_TESTS.md.

*Pourquoi ici :* 27, 51, 69 et 71 sont déjà faits : on les présente comme existants, avec au plus une petite retouche (valeurs de formation dans Config, quelques couleurs écrites en dur du thème clair). Avec 199 (état des tests), 198 (outils/release.py et rattrapage des 13 releases manquantes) et 200 (glossaire) en place tôt, chaque sous-version suivante est publiée et suivie proprement. Les V8, V9 et V10 promettent un jeu identique, et c'est la page des tests qui permettra de le vérifier. Ce lot ne touche presque pas au code du jeu.

### V6.9.9 — Effets visuels du voyage ✅ faite (05/11)

**Objectif :** Rendre la démat, la remat et l'atterrissage plus spectaculaires selon le mode et l'heure, et ajouter une option « aucun flash » pour les joueurs sensibles.

- **36. Distorsion de l'air plus forte en Urgence** *(en partie déjà là)* : L'air ondule autour de la cabine en urgence, plus que pour les autres modes.
- **38. Marques au sol après l'atterrissage** : Une trace carrée légère reste 30 s là où la cabine s'est posée.
- **46. Effets selon l'heure du jeu** : La lueur est plus forte la nuit, plus discrète le jour.
- **53. Lumières de la salle selon l'état** *(en partie déjà là)* : Bleu posé, ambré en voyage, cyan dans le vortex, rouge en alerte.
- **43. Effet Catastrophe plus violent** *(en partie déjà là)* : Éclats, fumée noire et étincelles autour de la cabine lors d'un paradoxe.
- **41. Vitres qui s'éteignent en dernier** : En démat, les fenêtres restent lumineuses une seconde après le reste.
- **191. Pas de flash** *(en partie déjà là)* : Une option qui supprime tout flash lumineux.

**Dans Studio :** Conseillé : ranger les vitres de la cabine dans un dossier « Fenetres » de l'extérieur, ou les nommer « Vitre » (41). Pour l'instant sur TARDIS_1 seulement : à reproduire sur TARDIS_2 et TARDIS_3 en V11 (voir la liste de contrôle de la V11.1). Vérifier que la salle contient des PointLight ou des SpotLight (53).

*Pourquoi ici :* Tout le serveur voit ces effets à chaque voyage, et ils ne demandent presque rien dans Studio. Tout se passe côté client (TardisEffets, EffetsExterieurs, Signalisation), sans nouvelle action réseau : la V8 n'aura rien de plus à sécuriser. Correction de l'analyse : 38 existe en partie. Depuis la V6.9.3, après un voyage Rapide, une marque ronde sous la cabine passe du vert au gris en 2,5 s (Signalisation.lua:118-123, Config.Signalisation.Trainee). On l'étend à tous les modes et on la fait durer plus longtemps dans Signalisation, au lieu de créer un second effet dans TardisEffets. 191 met une garde dans les mêmes fonctions (flashLampe, flash du bouclier, flashTemporel), d'où sa place ici. Ordre interne, du plus sûr au plus délicat : 36, 38, 46, 53, 43, 191, puis 41 (la seconde de retard des vitres déborde sur l'état Vol).

### V6.9.10 — Vol libre et vortex ✅ faite (05/11)

**Objectif :** Rendre le vol libre plus agréable (croisière, caméra cinématique) et plus perceptible pour les passagers (freinage ressenti à bord, rotor qui suit la vitesse, bruit du vortex).

- **23. Pilote automatique de croisière** *(en partie déjà là)* : Garder cap et altitude sans toucher aux touches.
- **26. Caméra cinématique** : Une caméra extérieure lente qui tourne autour de la cabine pendant le vol.
- **30. Freinage d'urgence** *(en partie déjà là)* : Une touche qui arrête net le TARDIS (avec secousse à bord).
- **52. Rotor qui suit la vitesse du vol** *(en partie déjà là)* : Le rotor monte et descend plus vite en vol libre rapide.
- **136. Ambiance du vortex** : Un son de vent cosmique pendant le vol, seulement à bord.

**Dans Studio :** Donner l'identifiant d'un son « Vortex » (ou placer le Sound dans TardisAssets > Sons). En option, un son « Frein ». Le bouton BoutonCamera de la console suffit pour l'orbite.

*Pourquoi ici :* Ce code vit dans l'interface de vol libre, dans TardisCamera et dans Ambiance, pas dans le menu T ni dans la tablette Y. 23 passe avant 26, parce que l'orbite n'est permise qu'en croisière. L'orbite se branche sur la boucle de rendu qui existe déjà dans TardisCamera, sans boucle en plus, en prévision de la 177. La nouvelle action VolLibreFrein (30) sera recensée par le garde-barrière de la V8. Son « un frein par seconde au plus » est un temps de recharge propre à cette action, comme Config.Cooldown : ce n'est pas la limite générale de la 158, et il ne passe pas par le garde. Le son Vortex (136) est déclaré avec Id 0 dans Config.Sons et dans la liste du diagnostic ; la V9.1 le fusionnera dans la liste unique.

### V6.9.11 — Navigation et fiches de lieux ✅ faite (06/11)

**Objectif :** Améliorer le choix des destinations (favoris du copilote, point de base, zones à vitesse réduite) et donner à chaque lieu une fiche affichée à l'arrivée.

- **1. Destinations favorites en tête de liste** *(en partie déjà là)* : Les lieux épinglés passent en premier dans le menu, la tablette et le poste du copilote.
- **8. Point de base** : Un lieu « Base » défini par les pilotes, raccourci dans tous les menus.
- **16. Zones à vitesse réduite** *(en partie déjà là)* : Un dossier de destinations où seuls Classique et Silencieux sont permis.
- **144. Fiches de lieux** : Une fiche RP par destination (description, dangers), affichée à l'arrivée.

**Dans Studio :** Créer dans Workspace > TARDIS_DESTINATIONS un sous-dossier VITESSE_REDUITE avec des Parts qui couvrent les zones. Ce dossier est commun aux trois TARDIS : rien à refaire en V11. En option : des attributs Description, Dangers et NiveauDanger sur les Parts de destination.

*Pourquoi ici :* Ces propositions touchent toutes resoudreDestination, modeAutorise et atterrir(), avec un faible risque. La fiche (144) s'affiche dans le bandeau d'arrivée, qui n'appartient ni à T ni à Y : elle survit à la V12. Elle sert aussi de source unique à la bibliothèque (56), repoussée avec les autres salles en V11.6. Pour la 8, la logique reste côté serveur et l'interface est minimale : la base deviendra un réglage par TARDIS en V11 et un bouton BASE sur la console en V12.2. La 1 complète seulement le poste du copilote. La 16 ne désarme jamais une urgence imposée.

### V6.9.12 — Pannes : le socle commun ✅ faite (06/11)

**Objectif :** Rendre la fréquence des pannes réglable, dire aux pilotes l'effet de chaque panne sur le vol, garder l'historique des réparations, situer les pannes par zone et leur donner un son.

- **117. Pannes aléatoires réglables** *(en partie déjà là)* : Fréquence des pannes réglable (aucune, rare, normale, fréquente).
- **125. Rapport de panne aux pilotes** *(en partie déjà là)* : Un message clair aux pilotes : quelle panne, quel effet sur le vol.
- **129. Historique des pannes** *(en partie déjà là)* : Les 20 dernières pannes et qui les a réparées.
- **122. Diagnostic par zone** *(en partie déjà là)* : Le diagnostic montre la zone de l'intérieur où se trouve la panne.
- **142. Sons de pannes** : Grincements, sifflements de vapeur, étincelles selon la panne.

**Dans Studio :** Conseillé : un dossier « Zones » dans l'intérieur de TARDIS_1, avec des Parts invisibles, sans collision et ancrées, nommées Console, Couloir, etc. (122). À reproduire dans TARDIS_2 et TARDIS_3 en V11. Sans ce dossier, la zone est donnée par rapport à la console. Donner les identifiants des sons Panne_Vapeur, Panne_Feu, Panne_Grincement et Panne_Etincelles (4 sons au plus dans ce lot).

*Pourquoi ici :* Le lot des pannes est coupé en deux sessions, avec une seule construction Studio chacune. Ce socle est à faible risque et sert à tout le reste. 117 crée la liste pondérée où se branchent 118, 119 et 120. 125 crée FICHES_PANNES et signalerPanne, réutilisés par 129 et 86. 129 tient un historique côté serveur. 122 publie le nom de la grille au lieu d'un numéro qui dépend de l'ordre de GetDescendants, ce qui corrige un défaut. Garde-fou : dans l'historique de la 129, « réparé par » reste une simple mention, jamais un compteur par technicien (la 98 a été refusée).

### V6.9.13 — Nouvelles pannes et outils du technicien ✅ faite (06/11)

**Objectif :** Donner du travail concret à la C.T.A.T. : fuite d'air, rotor bloqué, scanner qui lit l'état des pièces, soudeur pour refermer les brèches.

- **118. Nouvelle panne : fuite d'air** *(en partie déjà là)* : L'air baisse vite tant qu'un technicien n'a pas colmaté.
- **119. Nouvelle panne : rotor bloqué** : Le TARDIS ne peut plus décoller tant que le rotor n'est pas débloqué.
- **127. Outil : scanner portatif** : Un outil qui montre l'état d'un système en le visant.
- **128. Outil : soudeur** *(en partie déjà là)* : Un outil pour les pannes de structure (intégrité).

**Dans Studio :** À construire dans l'intérieur de TARDIS_1 : un dossier « Structure » (ou « Breches ») de Parts ancrées et invisibles aux endroits où une brèche peut s'ouvrir (128). À reproduire dans TARDIS_2 et TARDIS_3 en V11. Facultatif : des Parts « FuiteAir », un son RotorBloque, des modèles de scanner et de soudeur dans TardisAssets.

*Pourquoi ici :* Ce sont les ajouts à risque moyen, isolés après le socle. 118 et 119 se branchent sur le tirage de la 117. La 119 crée au passage une seule fonction « raison de blocage au départ », utilisée par decoller, demarrerVolLibre et teleporterEnPoche, ce que la V9 aurait de toute façon regroupé. 127 et 128 sont des Tools du sac : ils survivent à la V12. Les affichages restent dans les cartes existantes de la tablette technicien, sans nouvel écran dans la tablette Y. Ce lot doit précéder la 58 (salle des machines).

### V6.9.14 — Équipage et garde-robe ✅ faite (06/11)

**Objectif :** Donner une identité visible aux équipes (badges, uniformes), ranger la garde-robe par catégorie et animer les portes intérieures.

- **63. Garde-robe améliorée** *(en partie déjà là)* : Plus de tenues dans les casiers, rangées par catégorie.
- **90. Tenue de l'équipe au spawn** : Une tenue d'uniforme donnée à l'apparition (C.A.T. et C.T.A.T.).
- **89. Badges des équipes** : Un badge au-dessus de la tête des membres C.A.T. et C.T.A.T. (option).
- **54. Portes intérieures animées** *(en partie déjà là)* : Les portes intérieures s'ouvrent et se ferment avec les extérieures.

**Dans Studio :** Fournir les identifiants Shirt et Pants des nouvelles tenues et des uniformes C.A.T. et C.T.A.T. Ranger PortesInterieures de TARDIS_1 en deux Models « Gauche » et « Droite », chacun avec une Part « Charniere » sur l'axe, sans cacher la Part Portail (à reproduire dans TARDIS_2 et TARDIS_3 en V11). En option : une image d'emblème par équipe.

*Pourquoi ici :* 63 et 90 partagent le même code d'habillage (appliquerTenue, habillerTenueJeu) : les faire ensemble évite d'y revenir deux fois. Les nouvelles tenues vont en fin de liste, ou bien la clé des favoris passe au nom de la tenue. La 90 ne s'applique pas pendant une régénération (enAttente). Le retour de l'uniforme après une régénération reste un réglage fixe dans Config, jamais un choix du joueur (la 112 a été refusée). La 89 passe par Config, avec une garde « premier TARDIS » pour qu'il n'y ait pas trois badges après la V11. Seule construction importante : les portes (54), qui gardent le masquage actuel si le rangement est absent. TARDIS_2 et TARDIS_3 fonctionnent donc sans rien changer jusqu'à la V11.

### V6.9.15 — Confort de l'interface et accessibilité ✅ faite (06/11)

**Objectif :** Apporter les derniers réglages utiles jusqu'à la V12 (taille partout, fermeture par clic à côté, ouverture sans animation, menu déplaçable) et ceux qui survivront à la V12 (effets réduits par défaut sur mobile, sous-titres).

- **188. Effets réduits par défaut sur mobile** : Les téléphones démarrent en effets réduits.
- **190. Sous-titres des sons** : Un petit texte pour les sons importants (alarme, départ, arrivée).
- **72. Taille de l'interface** *(en partie déjà là)* : Agrandir ou réduire toute l'interface (accessibilité).
- **81. Animation d'ouverture plus courte** : Option pour ouvrir le menu sans animation.
- **78. Fermer la tablette en cliquant dehors** : Option pour fermer la tablette d'un clic à côté.
- **80. Menu rapide repositionnable** : Glisser le menu rapide où on veut sur l'écran (position retenue).

**Dans Studio :** Rien.

*Pourquoi ici :* Ce lot vient juste avant la V8, pour que toutes les nouvelles préférences (188, 190, et 191 en V6.9.9) existent quand la V8 fixera le schéma de l'action Prefs (157, 168). 188 et 190 vivent dans TardisUI et survivent à la V12 : seul leur interrupteur passera dans le panneau 193. La 72 sort de la V9 (idée du plan 3) : elle étend la taille à des postes qui l'ignorent, donc elle change ce qu'on voit, alors que la V9 promet un jeu identique. 78, 80 et 81 ne servent que jusqu'à la V12.4 : elles passent en dernier, et la 80 est la moins rentable (voir les remarques). Pour la 188, le choix est sauvegardé dans une clé à part sur mobile.

### V8 — Sécurité : banc d'essai, audits et sauvegarde

**Objectif :** Installer le filet de non-régression (simulations du serveur), automatiser l'audit des attributs et protéger la sauvegarde contre les données corrompues, avant de réécrire la réception des requêtes.

- **185. Simulations élargies** *(en partie déjà là)* : Couvrir le serveur de voyage, le copilote et la maintenance dans les simulations.
- **166. Attributs : audit** *(en partie déjà là)* : Vérifier qu'aucun attribut lu par le serveur ne peut venir d'un client.
- **168. Protection de la sauvegarde** *(en partie déjà là)* : Taille maximale et schéma vérifié à la lecture.

**Dans Studio :** Rien à construire : les outils tournent hors de Roblox.

*Pourquoi ici :* La 185 est un gros chantier, placé en tête : il faut un banc d'essai avant de toucher aux trois OnServerEvent (156), et les tests de triche (167) s'y brancheront. La 166 vérifie automatiquement, dans analyse.py, qu'aucun attribut lu par le serveur n'est écrit par le client. La 168 corrige une vraie faille : un cf corrompu dans la sauvegarde fait planter TardisServeur avant la création du pont interne, et TardisExtras puis TardisSystemes tombent en panne. Elle doit aussi précéder la 193 (taille des préférences).

### V8.1 — Sécurité : garde-barrière unique et pont interne

**Objectif :** Faire passer chaque requête du client par une liste unique (qui peut envoyer quoi), ajouter un verrou d'urgence, fermer le pont interne par une liste blanche et expliquer clairement les refus aux visiteurs.

- **156. Garde-barrière unique pour le RemoteEvent** *(en partie déjà là)* : Une seule liste des actions permises, avec qui peut les envoyer.
- **170. Mode verrouillé d'urgence** : Une option qui coupe toutes les commandes en un réglage si un exploit est découvert.
- **172. Pont interne en table** : Remplacer la chaîne de elseif par une table de fonctions.
- **169. Bindables protégés** *(en partie déjà là)* : Les BindableFunction internes renommées et vérifiées.
- **194. Mode lecture seule clair** *(en partie déjà là)* : Les visiteurs voient clairement ce qu'ils peuvent et ne peuvent pas faire.

**Dans Studio :** Rien. Le ModuleScript TardisGarde est créé par outils/synchro_studio.luau.

*Pourquoi ici :* La 156 est la fondation de toute la sécurité : 157, 167, 170, 194, 93, 131, 11 et 18 en dépendent. Les actions ajoutées en V6.9.x (VolLibreFrein, DefinirBase, actions des 118 et 119) y sont recensées. La 170 est un verrou réglé dans Config ou par un attribut serveur, sans commande de chat ni rôle staff. 172 et 169 touchent les mêmes lignes de pont.OnInvoke : on écrit une seule table ACTIONS_INTERNES avec les types attendus, qui sert aussi de liste blanche. La 194 met tout de suite dans le garde le message « Réservé aux pilotes de la C.A.T. », renvoyé à chaque refus comme les messages actuels, sans limite ni compteur, et ajoute l'encart « vous pouvez / vous ne pouvez pas » à la tablette en lecture seule. Les libellés des prompts de la console viendront avec l'utilitaire des boutons (V12.2 et V12.3). Refus respectés : aucune limite de fréquence par action dans le garde (158), aucun compteur de refus (164), aucune carte d'accueil à l'entrée (148, « Plus tard »).

### V8.2 — Sécurité : schéma des données et tests de triche

**Objectif :** Vérifier le type, les bornes et la longueur de chaque champ envoyé par le client, puis prouver par des simulations que les requêtes de tricheur sont refusées et que les vraies passent.

- **157. Schéma de données par action** *(en partie déjà là)* : Types, bornes et longueurs vérifiés pour chaque action.
- **167. Simulations de triche** *(en partie déjà là)* : De nouveaux tests qui envoient de fausses requêtes et vérifient qu'elles sont refusées.

**Dans Studio :** Rien.

*Pourquoi ici :* La 157 est le chantier le plus lourd de la V8 : environ 90 actions à relire, avec le risque de casser une requête légitime. Elle est donc isolée avec ses propres tests (167), qui dépendent des 156, 157, 170 et 185, toutes déjà faites. Le schéma reste écrit action par action, sans filtre général sur les nombres ni sur les textes, puisque les 162 et 163 ont été refusées.

### V9 — Nettoyage : journal, mesure et code mort

**Objectif :** Mettre en place un journal à niveaux et la mesure du coût de chaque module (le point de comparaison « avant »), retirer le code mort et valider la configuration au démarrage, sans rien changer en jeu.

- **175. Journal à niveaux** *(en partie déjà là)* : Info, avertissement, debug, à la place des print épars.
- **181. Mesure du coût par module** : Un compteur de temps par module en mode debug.
- **176. Code mort supprimé** *(en partie déjà là)* : Paramètres et outils qui ne servent plus depuis les retraits de V6.9.4 et V6.9.5.
- **183. Configuration validée au démarrage** *(en partie déjà là)* : Une vérification des réglages avec un message clair en cas d'erreur.

**Dans Studio :** Rien. Passer Config.Debug (ou Config.Mesure) à true le temps d'une session, pour relever les mesures « avant ».

*Pourquoi ici :* La 175 passe en premier : 181 et 183 en dépendent. La 181 fournit la référence avec laquelle on comparera 177, 178 et 180. La 176 doit précéder la 184. On ne supprime pas ce qui est seulement en pause : Intercom, TardisPontFondation et la balise /tardis help.

### V9.1 — Sons : liste unique et volumes par catégorie

**Objectif :** Réunir tous les sons dans une seule liste, la précharger au bon moment, et donner au joueur un volume et un interrupteur par catégorie de son.

- **173. Liste des sons partagée** *(en partie déjà là)* : Une seule liste entre le serveur et le préchargement client.
- **132. Banque de sons dans TardisAssets** *(en partie déjà là)* : Tous les sons rangés et nommés dans ReplicatedStorage › TardisAssets › Sons.
- **182. Préchargement intelligent** *(en partie déjà là)* : Charger les sons et images au premier besoin plutôt qu'au démarrage.
- **82. Sons d'interface désactivables par type** *(en partie déjà là)* : Couper séparément les bips, les alertes et les confirmations.
- **133. Volume par catégorie** *(en partie déjà là)* : Volumes séparés : voyages, moteur, alarmes, jukebox, interface.

**Dans Studio :** Placer dans TardisAssets > Sons les Sounds qui n'ont pas d'identifiant (Demat, Remat, Demat_Urg, Remat_Urg, Demat_Express, Remat_Express, Alarme, Moteur), ou donner leurs identifiants publics.

*Pourquoi ici :* 173 et 132 restent en V9, comme le prévoit la feuille de route, et reprennent les sons déclarés avec Id 0 pendant les V6.9.x (Vortex, Panne_*). L'ordre suit les dépendances : 173, 132, puis 182, qui dépend des deux. 82 et 133 sont réunis pour définir une seule fois les catégories de sons (Bip, Alerte, Confirmation, Ouverture, et les SoundGroup), comme le demande l'analyse. C'est le seul lot de la V9 qui change ce qu'on entend : le moteur du vol libre suivra enfin le réglage de volume, et l'interrupteur des sons sera détaillé par catégorie. À signaler dans la note de version.

### V9.2 — Code partagé et ordre des fonctions

**Objectif :** Remplacer les copies de la liste d'exclusion des raycasts par un utilitaire commun, et supprimer les déclarations anticipées de fonctions.

- **171. Utilitaire unique pour les raycasts** *(en partie déjà là)* : Une seule fonction pour la liste d'exclusion, recopiée 5 fois aujourd'hui.
- **184. Fonctions « définies plus bas » réordonnées** *(en partie déjà là)* : Supprimer les déclarations anticipées qui ont causé 6 bugs.

**Dans Studio :** Rien.

*Pourquoi ici :* C'est du nettoyage à faible risque, fait sur un code déjà débarrassé du code mort (176) et protégé par les simulations (185). On ne touche pas aux modules de la tablette Y. Ce lot passe avant les boucles par image (V9.3), pour que les gros changements se fassent sur un code propre.

### V9.3 — Boucles par image et effets à distance

**Objectif :** Remplacer les connexions par image de chaque TARDIS par un répartiteur unique, couper les effets décoratifs loin du joueur et les alléger automatiquement quand les images par seconde baissent.

- **177. Boucles par image regroupées** : Une seule boucle Heartbeat par TARDIS côté client.
- **178. Effets coupés loin du joueur** *(en partie déjà là)* : Ne rien calculer pour un TARDIS hors de vue.
- **47. Réduction automatique des effets** : Effets allégés quand les images par seconde baissent.

**Dans Studio :** Rien à construire. À tester dans Studio : une démat à 1 000 studs puis un retour près de la cabine, et un client lent (effets allégés).

*Pourquoi ici :* C'est un chantier à risque moyen (ordre des BindToRenderStep, état final d'une cabine lointaine), isolé dans son lot. L'ordre suit les dépendances : 177, puis 178, puis 47. Tout est mesuré avec la 181. La 178 est conçue pour N TARDIS dès maintenant, avant la V11, où son gain se multiplie. La 47 reste automatique et ne touche jamais Config.Alpha. Les boucles de T et de Y ne sont pas converties.

### V9.4 — Moins d'attributs envoyés sur le réseau

**Objectif :** Réduire le trafic réseau (positions du vol libre en non fiable, écritures moins fréquentes, aucune réécriture d'une valeur identique) sans changer le format des attributs.

- **180. Moins d'attributs répliqués** : Regrouper les changements fréquents pour soulager le réseau.

**Dans Studio :** Rien à construire. Comparer les statistiques réseau de la console développeur avant et après.

*Pourquoi ici :* Ce chantier est isolé pour qu'une régression soit facile à attribuer. Il touche recevoirPositionVol, déjà retravaillé en V6.9.7 et en V8. Il dépend des 166, 181 et 185, et doit être fait avant la V12, pour que la console soit construite sur le format allégé.

### V10 — Guide d'installation

**Objectif :** Écrire un guide d'installation pas à pas pour la nouvelle organisation des fichiers.

- **196. Guide d'installation pas à pas** *(en partie déjà là)* : Un document illustré pour installer une version dans Studio.

**Dans Studio :** Rien à construire. Pour un guide illustré, l'utilisateur fournit des captures de l'Explorer de Studio. Sinon, le guide utilise des arborescences en texte.

*Pourquoi ici :* La V10 change tous les chemins d'installation : c'est le seul moment où écrire ce guide n'est pas du travail perdu. Il s'appuie sur le glossaire (200, en V6.9.8). On le complétera en V11 (3 TARDIS, avec la liste de contrôle Studio par intérieur de la V11.1) puis en V12 (pièces de la console).

### V11.1 — Régénération : nouveaux styles et choix du style

**Objectif :** Ajouter les styles Cristal et Écho, puis laisser chaque membre de la C.A.T. choisir son style à la garde-robe.

- **103. Nouveau style : Cristal** : Le corps se couvre d'éclats lumineux qui se brisent.
- **104. Nouveau style : Écho** : Plusieurs silhouettes des anciens visages apparaissent puis s'effacent.
- **102. Choix du style par le joueur** : Chaque membre de la C.A.T. choisit son style de régénération préféré.

**Dans Studio :** D'abord, avec l'officialisation des 3 TARDIS (V11), une liste de contrôle à reproduire dans TARDIS_2 et TARDIS_3 pour ce qui a été construit sur TARDIS_1 avant la V11 : dossier « Fenetres » de l'extérieur (41), dossier « Zones » (122), dossier « Structure » (128), PortesInterieures en Models Gauche et Droite avec Charniere (54). Pour ce lot, rien d'obligatoire : en option, un son Regeneration_Cristal dans TardisAssets > Sons, et une Part avec un ProximityPrompt à la garde-robe si le choix ne passe pas par le panneau du casier.

*Pourquoi ici :* Ce lot vient après le découpage de Regeneration.lua en V10 : chaque style a alors son propre module (conseil de l'analyse et de deux juges sur trois). Il est placé en tête de la V11 parce que la régénération est l'un des moments forts du RP de la C.A.T. La 102 vient après 103 et 104, pour que la liste Config.Regeneration.Styles soit complète. C'est un choix personnel : il va dans le panneau du casier ou de la garde-robe (Interactions.lua), qui survit à la V12, plutôt que sur la console partagée.

### V11.2 — Régénération : fins et réactions

**Objectif :** Ajouter une dernière régénération de cycle spectaculaire, une mort mise en scène quand on refuse de se régénérer, et la réaction du TARDIS quand un membre de la C.A.T. se régénère tout près.

- **107. Dernière régénération** *(en partie déjà là)* : Après N régénérations, une version plus dramatique, puis remise à zéro.
- **114. Régénération refusée : chute dramatique** : Si le joueur refuse, une animation de mort différente.
- **115. Effet sur le TARDIS proche** *(en partie déjà là)* : Une régénération près du TARDIS fait trembler la cabine.

**Dans Studio :** Rien d'obligatoire. En option, les sons RegenerationRefusee et Regeneration_Ultime dans TardisAssets > Sons.

*Pourquoi ici :* Ce lot est séparé du précédent, pour ne pas enchaîner trop de morts dans une seule session de test. Avant la 107, il faut une décision : cycle qui recommence ou vraie mort (voir les remarques). Pour la 114, la réparation automatique des articulations et la mise à mort côté client doivent attendre la fin de l'animation : risque moyen. La 115 a besoin de la détection des 3 TARDIS officiels et réutilise la boucle de vibration de Systemes.lua.

### V11.3 — Départ annulable et remat ratée

**Objectif :** Permettre d'annuler un départ au levier de la console, et ajouter un raté rare, purement visuel, de rematérialisation.

- **11. Annuler un départ** : Pendant le son de départ (avant que la cabine s'efface), un bouton annule le voyage.
- **45. Rematérialisation partielle ratée** : Rare : la cabine clignote, disparaît, puis réapparaît (bug d'atterrissage RP).

**Dans Studio :** Rien : le levier existant de la console (promptLevier) sert à l'annulation. Il existe dans chaque intérieur, puisque le script serveur est cloné pour chaque TARDIS : vérifier sa présence sur TARDIS_2 et TARDIS_3.

*Pourquoi ici :* Les deux propositions touchent le cœur du voyage (decoller, atterrir, Config.Alpha), que les V8 à V10 retravaillent : elles se font sur le code refondu. La 11 se branche sur le levier physique qui existe déjà (aucun bouton dans T ni dans Y) et n'ajoute aucun compte à rebours. Elle passe avant la 18, qui réutilise son jeton d'annulation. Les deux se testent sur les mêmes cycles de démat et de remat.

### V11.4 — Voyage de groupe synchronisé

**Objectif :** Faire décoller et atterrir deux TARDIS ensemble, après une invitation et une confirmation entre leurs pilotes.

- **18. Voyage de groupe synchronisé** : Deux TARDIS qui partent et arrivent ensemble (quand il y en aura plusieurs).

**Dans Studio :** Au moins deux TARDIS complets (extérieur, intérieur, console). Avant de commencer, il faut avoir décidé où se trouve le bouton d'invitation sur TARDIS_2 et TARDIS_3, qui n'auront pas la console de la V12 (question bloquante, voir les remarques).

*Pourquoi ici :* C'est le chantier le plus risqué du plan (effort G, risque élevé) : il est isolé. Il a besoin des 3 TARDIS officiels, de la règle « un pilote = un TARDIS », du garde-barrière (156, 157) et de l'annulation de la 11, déjà testée en V11.3. Il ne démarre pas tant que la question de l'emplacement des commandes sur TARDIS_2 et TARDIS_3 n'est pas tranchée.

### V11.5 — Accès à bord : sonnette, passages secrets, chambres

**Objectif :** Gérer qui entre dans le TARDIS et dans ses pièces : sonnette à la porte avec réponse des pilotes, passages réservés aux pilotes, chambre pour chaque membre de l'équipage.

- **68. Zones d'intérieur cachées** : Des pièces secrètes que seuls les pilotes peuvent ouvrir.
- **93. Demande d'accès à bord** *(en partie déjà là)* : Un joueur dehors peut sonner ; les pilotes acceptent ou refusent.
- **57. Chambres de l'équipage** : Des petites pièces privées, une par membre de la C.A.T.

**Dans Studio :** Dans chaque intérieur officiel : un dossier « ZonesCachees » (une Part Passage et une Part Declencheur par zone), puis les pièces Chambre1 à ChambreN, chacune avec une Part PorteChambre et une Part Plaque. En option : une Part « Sonnette » sur l'extérieur et un son Sonnette.

*Pourquoi ici :* La 57 dépend de la 68 (même porte réservée) et doit savoir qui appartient à quel TARDIS, ce que fixe la V11. La 93 ajoute deux actions qui passent par le garde-barrière. Sa liste d'invités supprime aussi l'alerte INTRUSION déclenchée à tort par l'invitation actuelle. Garde-fous : cette liste ne vaut que pour la visite en cours et ne donne aucun accès temporaire de passager (la 100 a été refusée) ; l'attente de 30 s entre deux coups de sonnette est un temps de recharge propre à cette action, pas une limite du garde (158). Tout passe par des ProximityPrompts serveur.

### V11.6 — Nouvelles salles : machines, infirmerie, bibliothèque

**Objectif :** Ajouter dans chaque intérieur officiel une salle des machines sous la console, une infirmerie et une bibliothèque qui reprend les fiches de lieux.

- **58. Salle des machines** *(en partie déjà là)* : Une pièce sous la console où les techniciens réparent les pannes.
- **59. Infirmerie** *(en partie déjà là)* : Une pièce qui soigne lentement les joueurs à bord.
- **56. Bibliothèque** : Une pièce avec des livres qui affichent des fiches RP (lieux, anomalies).

**Dans Studio :** Dans chaque intérieur (Model TARDIS_Interieur) : la salle des machines, avec une trappe ou un escalier, les Grilles, la Vanne et éventuellement le levier d'alimentation ; l'infirmerie, avec une Part invisible « Infirmerie » ; la pièce « Bibliotheque », avec des étagères et des Parts « Livre » qui portent un attribut « Fiche ».

*Pourquoi ici :* Ce sont des salles à construire dans chaque intérieur : elles viennent une fois les intérieurs de TARDIS_2 et TARDIS_3 rangés comme celui de TARDIS_1 (V11). La 56 rejoint ce lot pour ne pas construire une salle entière trois fois. Elle réutilise les fiches de la 144 (V6.9.11) et sa propre logique est en lecture seule, sans rien à sécuriser. La 58 dépend des 118 et 119 (V6.9.13) et de la V10, qui range les pannes dans « Systemes ». La 59 ne sert que si Config.ZoneSure change (voir les remarques). Agrandir l'intérieur modifie dansInterieur : à tester.

### V11.7 — Réglages personnels hors de la tablette

**Objectif :** Créer le panneau « Mes réglages », ouvert à tous (pilotes, techniciens, visiteurs), avec le mode daltonien et une police plus grande, avant de construire les écrans de la console.

- **193. Réglages retenus entre appareils** *(en partie déjà là)* : Les préférences suivent le joueur (déjà sauvegardées) et sont résumées dans un écran.
- **186. Mode daltonien** : Couleurs des modes et alertes adaptées, avec des symboles en plus.
- **187. Textes plus gros** *(en partie déjà là)* : Une option de grande police pour toutes les interfaces.

**Dans Studio :** Rien.

*Pourquoi ici :* Ce lot prépare la V12 et passe avant la V12.1. 186 et 187 dépendent de la 193. Les écrans de la console sont ainsi écrits dès le départ avec UI.couleurMode et les symboles de mode, et le panneau de réglages existe avant le retrait de la tablette Y, qui porte aujourd'hui les seuls réglages et n'est ouverte qu'aux pilotes. Il est numéroté en V11.x, pour garder intacts les numéros V12.1 à V12.4 de la feuille de route.

### V11.8 — Textes à clés et langue anglaise

**Objectif :** Mettre en place le module de textes à clés (TardisTextes, UI.t), faire envoyer par le serveur des codes plutôt que des phrases, et traduire en anglais les messages et le panneau de réglages.

- **85. Langue anglaise** : Une traduction anglaise de toute l'interface (option).

**Dans Studio :** Rien.

*Pourquoi ici :* C'est un gros chantier à risque élevé, isolé hors du lot de retrait de T et de Y. Placé avant la V12.1, il permet d'écrire tous les écrans et boutons de la console directement avec des clés, puis de les traduire au fur et à mesure, sans reprise. On ne traduit pas le menu T ni la tablette Y. Les tests qui reconnaissent un message à son texte (Preferences.lua:61) sont remplacés par des codes, sinon les alertes ne sonneraient plus en anglais.

### V12.1.1 — Écrans de la console : accueil, équipage, statistiques

**Objectif :** Afficher sur la console de TARDIS_1 un écran d'accueil (état, destination, pannes en cours), l'équipage en ligne et les statistiques de voyage du TARDIS.

- **86. Écran d'accueil de la tablette** *(en partie déjà là)* : Un résumé à l'ouverture : état, destination, pannes, équipage.
- **79. Indicateur de connexion des pilotes** *(en partie déjà là)* : Voir qui est pilote, copilote et technicien en ligne, d'un coup d'œil.
- **76. Tablette : onglet Statistiques** *(en partie déjà là)* : Un vrai onglet de statistiques avec graphiques (voyages par jour, par mode).

**Dans Studio :** Placer sur la console de TARDIS_1 (ou sur un mur de la salle de contrôle) les pièces écrans nommées EcranAccueil, EcranEquipage et EcranStatistiques, chacune avec une face visible.

*Pourquoi ici :* La V12.1 est coupée en trois petites étapes, pour qu'une régression soit facile à attribuer. Celle-ci ne contient que de l'affichage plus un seul nouveau format de données (l'historique par jour de la 76, compté par TARDIS et plafonné). La 86 reprend lirePannes et la 125 (V6.9.12). 79 et 86 partagent la même liste de l'équipage, qui montre qui pilote quel TARDIS. Ces affichages étaient prévus dans la tablette Y : on les construit une seule fois, sur la console.

### V12.1.2 — Écrans de la console : journal de l'équipage

**Objectif :** Afficher un journal unique de l'équipage sur la console : entrées et sorties, pilotage, réparations, régénérations (avec style et numéro).

- **96. Journal de l'équipage** *(en partie déjà là)* : Qui est entré, sorti, a piloté et a réparé, dans la tablette.
- **113. Journal des régénérations détaillé** *(en partie déjà là)* : Lieu, heure, style et avatar avant/après dans la tablette.
- **106. Compteur de régénérations visible** *(en partie déjà là)* : Le nombre de régénérations du joueur dans sa fiche.

**Dans Studio :** Placer sur la console de TARDIS_1 une pièce écran nommée EcranJournal, avec une face visible.

*Pourquoi ici :* 96, 113 et 106 forment un seul journal par catégories, avec un seul attribut publié (40 lignes au plus) au lieu de trois. La partie serveur (journalEquipage par le pont interne, style et avatar dans noterRegeneration, attribut TardisRegenNombre) s'écrit et se teste avant l'écran. Isoler ce lot permet de vérifier séparément le nouveau format de données et son affichage.

### V12.1.3 — Écrans de la console : parasites et panne d'écrans

**Objectif :** Faire grésiller les écrans de la console selon la panne en cours, et ajouter la panne « écrans morts », réparable à la console.

- **64. Console qui réagit aux pannes** *(en partie déjà là)* : Fumée, étincelles et écrans qui grésillent selon la panne en cours.
- **120. Nouvelle panne : écrans morts** : Les écrans de la console s'éteignent, l'interface affiche des parasites.

**Dans Studio :** Facultatif : un dossier « PointsPanne » d'Attachments (Fumee, Etincelles) dans la console, et un son « Parasites ».

*Pourquoi ici :* 64 et 120 partagent un seul module de parasites, appliqué à tous les écrans posés en V12.1.1 et V12.1.2, à majEcran, à la ligne vivante et à Diagnostic1-4. La 120 ajoute une vraie panne au tirage de la 117 : elle est isolée en dernier pour ne pas mêler une nouvelle panne aux premiers écrans. Seuls les affichages sont touchés, jamais les commandes.

### V12.2 — Boutons de navigation de la console

**Objectif :** Créer l'utilitaire commun des boutons physiques (animation, bip, libellé « Réservé aux pilotes »), puis poser la grande carte cliquable des destinations et les commandes du jukebox.

- **137. Bips de la console** : Des petits sons quand on touche la console.
- **77. Carte des destinations en grand** *(en partie déjà là)* : Une carte plein écran avec tous les lieux, cliquable.
- **138. Jukebox : file d'attente** : Ajouter des musiques à une file au lieu d'en jouer une seule.

**Dans Studio :** Une grande Part EcranCarte (environ 6 × 4 studs). Les boutons de navigation (destinations, modes, DÉMAT / REMAT), le bouton BASE (8) et les boutons du jukebox, tous sur TARDIS_1. Facultatif : un son Bip_Console.

*Pourquoi ici :* La 137 (bip au toucher) fait partie de l'utilitaire commun des boutons physiques, qui porte aussi l'animation et les libellés de la 194 ; les boutons des systèmes de la V12.3 le réutiliseront. Le délai entre deux bips est un simple anti-répétition du son, pas une limite du garde (158). La 77 envoie un choix de destination : elle va avec les boutons de navigation, pas avec les écrans en lecture seule. Elle dépend de la 51. La logique serveur de la 138 corrige aussi le décalage actuel du jukebox entre les joueurs. L'aide (84) et les décoratifs (66) attendent que la console soit complète.

### V12.3 — Boutons des systèmes : énergie, Artron et décoratifs

**Objectif :** Concevoir ensemble la réserve d'Artron et la répartition de l'énergie, avec leurs leviers et leurs écrans, puis, une fois tous les vrais boutons posés, ajouter les interrupteurs décoratifs.

- **17. Carburant temporel (Artron)** : Une jauge qui baisse à chaque voyage selon le mode et se recharge posé.
- **131. Énergie partagée entre systèmes** *(en partie déjà là)* : Répartir l'énergie entre boucliers, moteurs et vie à bord.
- **66. Interrupteurs physiques décoratifs** : Des leviers et boutons qui bougent quand on les touche (sans commande).

**Dans Studio :** Sur la console de TARDIS_1 : les boutons des systèmes prévus par la feuille de route (portes, verrou, camouflage, boucliers, siège, alerte, énergie), des Parts nommées pour les leviers de répartition et un écran pour la jauge d'Artron. Ensuite seulement, sur les emplacements restés libres : un dossier « Decoratifs » de Models LevierDeco, BoutonDeco et InterrupteurDeco, chacun avec une PrimaryPart servant de pivot.

*Pourquoi ici :* 17 et 131 se recoupent (l'Artron peut servir de réserve aux moteurs) : on les conçoit ensemble, avec RegulEnergie et la coupure après N voyages. Les valeurs par défaut redonnent exactement le comportement actuel, et une simulation sert à l'équilibrage. Garde-fous : une jauge vide ne bloque jamais les pilotes. Tant que la 130 (« bouclier qui faiblit avec l'énergie ») reste en « Plus tard », la part Boucliers ne peut qu'accélérer la recharge au-delà du niveau actuel, sans jamais faire baisser ni tomber le bouclier. Si ce n'est pas assez utile, on réduit la 131 à deux parts, Moteurs et Vie (question bloquante, voir les remarques). La 66 passe en fin de lot, une fois toutes les vraies commandes posées, pour ne prendre aucun de leurs emplacements ni tromper le pilote. Elle réutilise l'utilitaire de la V12.2. Sa limite de clics par joueur est un anti-répétition local au ClickDetector, pas une limite du garde (158).

### V12.4 — Retrait de T et Y sur TARDIS_1 : ce qui reste à l'écran

**Objectif :** Retirer le menu T et la tablette Y pour TARDIS_1 (sauf autre décision pour TARDIS_2 et TARDIS_3), faire passer les messages du TARDIS dans le chat avec les couleurs d'équipe, écrire l'aide de la console finale, rendre utilisables à la manette les interfaces qui restent et décider des commandes tactiles du vol libre.

- **101. Couleurs d'équipe dans le chat** : Noms colorés selon l'équipe dans les messages du TARDIS.
- **192. Manette : navigation des menus** : Parcourir le menu et la tablette à la manette.
- **29. Mobile : joystick virtuel** *(en partie déjà là)* : Un vrai joystick tactile pour le vol libre sur téléphone.
- **84. Aide intégrée** *(en partie déjà là)* : Une page d'aide dans la tablette qui explique chaque fonction.

**Dans Studio :** Rien à construire, sauf un bouton « ? » nommé sur la console de TARDIS_1 pour l'aide (84). Vérifier dans Studio > Teams que la C.A.T. et la C.T.A.T. ont des TeamColor différentes. Tester sur un vrai téléphone et avec une manette.

*Pourquoi ici :* Le retrait de T et Y ne vise que TARDIS_1, seul à avoir une console complète (V12.5 et suivantes ne seront pas faites). Sans décision contraire, TARDIS_2 et TARDIS_3 gardent T et Y, sinon ils ne seraient plus pilotables (question bloquante, voir les remarques). Le lot reste léger, puisque le panneau de réglages (193), l'accessibilité (186, 187) et la langue (85) sont déjà en place. La 101 remplace dans le chat les notifications qui disparaissent avec T et Y. La 84 vient ici, une fois la console complète et les menus retirés, pour décrire la console finale à partir d'une table partagée. La 192 ne vise que les interfaces qui restent (panneau 193, copilote, tablette technicien) et ferme avec ButtonB par ContextActionService, pour ne pas gêner la caméra. La 29 suit la décision de la V12 sur le vol libre à l'écran.

### Questions et arbitrages à trancher

- À trancher maintenant (V6.9.7) : veux-tu sortir les cinq corrections (141, 9, 24, 108, 134) tout de suite, en correctif V6.9.6.1, ou attendre la V6.9.7 ?
- À trancher avant la V6.9.8 : as-tu donné ton accord pour rattraper les 13 releases GitHub manquantes (v6.7 à v6.9.6) avec outils/release.py ? Pour remplir la page d'état des tests, il me faudra aussi tes résultats en jeu sur V6.7 à V6.9.6.
- Correction de l'analyse, vérifiée dans le code : la 38 (marques au sol) n'est pas entièrement nouvelle. Après un voyage Rapide, une marque ronde sous la cabine passe déjà du vert au gris en 2,5 s (Signalisation.lua:118-123, Config.Signalisation.Trainee). Je propose de l'étendre à tous les modes et de la faire durer plus longtemps, plutôt que de créer un second effet. D'accord ?
- Arbitrage sur les sons : je garde la liste unique (173, 132) en V9.1, comme le prévoit la feuille de route. Les sons ajoutés avant (Vortex, Panne_*) sont déclarés avec Id 0, puis fusionnés en V9.1. Autre choix possible : avancer la liste unique avant la V6.9.10 pour ne jamais déclarer un son dans trois listes. Le jeu ne changerait pas, mais on s'écarterait de la feuille de route. Que préfères-tu ?
- Arbitrage V9 : la 72 (taille appliquée partout) sort de la V9 et passe en V6.9.15, parce qu'elle change ce qu'on voit. La 82 et la 133 restent ensemble en V9.1, pour définir les catégories de sons une seule fois : c'est le seul lot de la V9 qui change le jeu (volume du moteur du vol libre, interrupteurs par catégorie). Es-tu d'accord pour le signaler dans la note de version ?
- À valider : plusieurs propositions ont un petit délai propre à une seule action : un frein par seconde au plus (30), 30 s entre deux coups de sonnette (93), une limite de clics sur les décoratifs (66), un délai entre deux bips (137). Ce sont des temps de recharge de jeu, comme les délais actuels (Config.Cooldown, 3 s pour le carnet). Ils ne passent pas par le garde-barrière et ne sont jamais notés : ce n'est donc pas la limite générale par joueur et par action de la 158, que tu as refusée. Le message de refus de la 194 sera renvoyé à chaque refus, sans limite. Ça te convient, ou veux-tu retirer ces délais ?
- Constructions Studio avant la V11 : les dossiers Fenetres (41), Zones (122), Structure (128) et le rangement des PortesInterieures (54) ne sont faits que sur TARDIS_1. Ils sont facultatifs : sans eux, TARDIS_2 et TARDIS_3 gardent le comportement actuel. Ils sont à reproduire dans la liste de contrôle de la V11.1, une fois les intérieurs rangés. La bibliothèque (56), qui est une salle entière, est repoussée en V11.6 avec les autres salles pour n'être construite qu'une fois par intérieur. Préfères-tu l'avoir tout de suite sur TARDIS_1 seulement ?
- Question 80 (menu T déplaçable) : c'est la proposition la moins rentable du plan (effort M pour un menu supprimé en V12.4). On la garde en V6.9.15, ou tu la passes en « Non » ?
- Question 26 (caméra en orbite) : les passagers à bord y ont-ils droit, ou seulement les pilotes, comme le bouton caméra aujourd'hui ?
- Question 119 (rotor bloqué) : je propose que les pilotes puissent eux aussi débloquer le rotor, pour ne pas immobiliser le TARDIS quand aucun technicien n'est en ligne. Et pour la 128, garde-t-on la réparation au rotor, avec un gain réduit quand une brèche est ouverte ?
- Question 90 (uniformes) : après une régénération, l'uniforme revient-il par-dessus la nouvelle apparence ? Ce sera un réglage fixe dans Config, pas un choix du joueur (la 112 a été refusée). Et le jeu SCP affiche-t-il déjà des étiquettes de grade au-dessus des têtes, qui feraient doublon avec les badges de la 89 ?
- Pour la 84 (aide) : les deux lignes fausses de la page AIDE actuelle (Volet.lua:290-291) peuvent être corrigées en passant dans la V6.9.15, sans attendre la vraie aide de la V12.4. D'accord ?
- À trancher avant la V11.2, question 107 : quel modèle de fin de vie pour la C.A.T. ? Le cycle qui recommence (par exemple Cycle = 12, puis remise à zéro), ou l'actuel Nombre qui mène à la vraie mort ? Il faut un seul réglage clair.
- Arbitrage sur la régénération : j'ai suivi l'analyse et deux juges sur trois en la plaçant après la V10 et la V11 (V11.1 et V11.2). Si tu la veux plus tôt parce que c'est un moment fort du RP, les styles 103 et 104 peuvent passer avant la V8, mais Regeneration.lua grossirait juste avant son découpage.
- Question 11 : jusqu'où peut-on annuler un départ ? La fenêtre est nulle en Rapide et en Silencieux, et ne dure que 3,25 s en Classique. Faut-il permettre l'annulation pendant une partie de l'animation, par exemple sous 30 % ?
- QUESTION BLOQUANTE avant la V11.4 et la V12.4 : la console n'est construite que sur TARDIS_1 (les V12.5 à V12.12 ne seront pas faites). Sur TARDIS_2 et TARDIS_3, où placer le bouton d'invitation au voyage de groupe (18), les leviers d'énergie (17, 131), la carte (77), le jukebox (138) et les écrans de la V12.1 ? Par défaut, le plan suppose que TARDIS_2 et TARDIS_3 gardent le menu T et la tablette Y, et que la V12.4 ne les retire que sur TARDIS_1. Confirmes-tu, ou veux-tu une autre solution ?
- Question 57 (chambres) : combien de membres compte la C.A.T. ? L'attribution est-elle fixe par UserId, ou automatique au premier passage ? Pour la 68, le copilote et les pilotes temporaires peuvent-ils ouvrir les passages secrets ?
- À trancher avant la V11.6, question 59 (infirmerie) : Config.ZoneSure = true soigne déjà instantanément partout à bord. Passe-t-on la zone sûre à « pas de dégâts, sans soin complet », ou la désactive-t-on ? Sinon, l'infirmerie n'est que décorative.
- Numérotation : le panneau de réglages (193, 186, 187) et la langue (85) sont en V11.7 et V11.8, pour garder intacts les numéros V12.1 à V12.4 de la feuille de route (pas de V12.5 ni de V12). La V12.1 est découpée en V12.1.1, V12.1.2 et V12.1.3, pour ne pas mélanger dans un seul test les écrans, un nouveau journal et une nouvelle panne. Question 85 : veux-tu toujours la version anglaise (effort G, risque élevé) ? Si non, on ne garde que le module de textes à clés.
- QUESTION BLOQUANTE avant la V12.3 (17 et 131) : qui limite les voyages, l'Artron, la part « moteurs » de l'énergie ou la coupure actuelle après N voyages ? Règle proposée : une jauge vide n'autorise plus que le Classique, sans jamais bloquer les pilotes. Et la part « Boucliers » : comme la 130 (bouclier qui faiblit avec l'énergie) est en « Plus tard », je propose qu'elle accélère seulement la recharge, sans jamais faire baisser ni tomber le bouclier. Sinon, on réduit la répartition à deux parts (Moteurs, Vie). Que choisis-tu ?
- Question ouverte de la feuille de route, qui fixe le contenu de la V12.4 : le vol libre reste-t-il à l'écran (29), et quels postes à l'écran survivent (copilote, tablette technicien, tablette en lecture seule) ? Cela touche aussi les 1, 122, 127, 129 et 192.
- Rappel des refus respectés : aucune limite de fréquence par action dans le garde-barrière (158), aucun compteur de refus (164), aucun filtre général des nombres ou des textes (162, 163), aucun compteur par technicien (98), aucun accès invité temporaire (100), aucun choix de tenue après régénération (112). Rien de ce qui a été retiré n'est réintroduit : staff, clé, recette, crise post-régénération, compte à rebours, intercom, OS Fondation, signaux de détresse, équipage scanné. Rien non plus de ce qui est en « Plus tard » : 130 et 148.

### Non planifié

- **Plus tard** (25) : 5 (Orientation à l'arrivée), 15 (Protocole Ancrage), 19 (Confirmation des voyages lointains), 22 (Altimètre et compas), 25 (Limites de la carte visibles), 32 (Vent et météo), 35 (Atterrissage de précision assisté), 37 (Feuilles et poussière soulevées), 39 (Effet pour la téléportation de poche), 48 (Son et effet synchronisés sur mobile), 50 (Effet à bord pendant la démat), 67 (Bruit de pas sur le sol métallique), 70 (Raccourcis clavier configurables partout), 74 (Infobulles sur chaque bouton), 92 (Liste d'équipage du jour), 97 (Missions de la C.T.A.T.), 109 (Énergie de régénération partagée), 111 (Nouvelle voix à la régénération), 123 (Alarme par type de panne), 130 (Bouclier qui faiblit avec l'énergie), 135 (Écho dans la salle), 148 (Accueil des visiteurs), 174 (Format de réponse unique), 179 (Moins d'objets créés par image), 189 (Boutons tactiles plus grands).
- **Non** (65) : voir [PROPOSITIONS_200.md](PROPOSITIONS_200.md).
