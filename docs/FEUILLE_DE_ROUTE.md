# Feuille de route — V7 à V11

> Fixée le 02/11/2026, revue le même jour : la **sécurisation** (V7) et le **nettoyage** (V8) passent devant ; les versions prévues avant
> deviennent V9, V10 et V11. Les sous-versions V6.9.x continuent d'ici là. **Avant la V7 : tri des 200 propositions** (page dédiée).
> Pour chaque version : **le sujet** (décidé) puis **ce que ça implique** dans le code actuel (à valider ensemble avant de commencer).

| Version | Sujet | État |
|---|---|---|
| **V7** | Sécurisation des scripts | 🔜 prévue |
| **V8** | Optimisation et nettoyage du code | 🔜 prévue |
| **V9** | Refonte presque totale de l'organisation des fichiers | 🔜 prévue |
| **V10** | Les 3 TARDIS officialisés, un TARDIS attribué à chacun des trois pilotes | 🔜 prévue |
| **V11** | Plus de menu : tout passe par la console de commande et ses écrans | 🔜 prévue |
| V11.1 → V11.4 | TARDIS_1 | 🔜 prévue |
| V11.5 → V11.8 | TARDIS_3 | ✖ ne sera pas fait |
| V11.9 → V11.12 | TARDIS_2 | ✖ ne sera pas fait |

---

## V7 — Sécurisation des scripts

**Sujet :** sécuriser les scripts.

**Aujourd'hui :**
- le serveur vérifie déjà les droits de chaque commande (pilote, copilote, technicien), la fréquence (`Config.Cooldown`) et les types principaux ;
- mais chaque script serveur (`TardisServeur`, `TardisExtras`, `TardisSystemes`) a son propre `OnServerEvent` sur le même RemoteEvent, avec ses propres contrôles, écrits à la main action par action ;
- le vol libre accepte environ 15 positions par seconde venues du client.

**Ce que ça implique (proposition) :**
- **Un seul garde-barrière** pour le RemoteEvent : une liste des actions permises avec, pour chacune, qui peut l'envoyer, le **schéma des données** (types, bornes, longueur des textes) et une **limite de fréquence par joueur**. Tout ce qui sort du schéma est refusé et noté.
- **Vol libre** : vitesse et distance maximales vérifiées côté serveur (pas de téléportation par un client modifié), positions hors carte refusées.
- **Contrôles de distance** : les actions qui demandent d'être à bord ou près de la cabine (outils, carnet, interphone…) revérifiées sur le serveur.
- **Textes** : tous les textes de joueurs filtrés par Roblox, longueur bornée (déjà fait pour le carnet, l'enseigne, l'interphone : à généraliser).
- **Attributs** : le client n'écrit jamais d'attribut qui compte ; vérification que rien de ce qui est lu par le serveur ne vient d'un client.
- **Exploits courants** : spam de RemoteEvent, valeurs `NaN` ou infinies, tables énormes, chaînes géantes, UserId inventés. Un compteur de refus par joueur, noté au journal.
- **DataStore** : limites de taille, pas d'écriture tant que la lecture a échoué (déjà fait), données relues avec un schéma.
- **Tests** : de nouvelles simulations (`outils/simulation`) qui envoient de fausses requêtes de « tricheur » et vérifient qu'elles sont toutes refusées.

---

## V8 — Optimisation et nettoyage du code

**Sujet :** optimisation et nettoyage du code (contenu laissé à mon choix).

**Ce que je prévois :**
- **Nettoyage** (simplifications restantes de PROPOSITIONS.md) : un seul utilitaire pour les raycasts, le pont interne écrit en table au lieu d'une chaîne de `elseif`, une liste des sons partagée entre serveur et client, un seul format de réponse et d'alerte, un journal à niveaux (info, avertissement, debug), les réglages morts et le code mort supprimés (paramètres et outils qui ne servent plus depuis les retraits de la V6.9.4 et de la V6.9.5), les fonctions « définies plus bas » réordonnées.
- **Optimisation** : regrouper les boucles qui tournent à chaque image (Heartbeat, RenderStepped) par TARDIS, ne rien faire quand le joueur est loin ou que l'effet est invisible, moins de créations d'objets par image, moins de changements d'attributs répliqués, des effets qui s'allègent automatiquement quand les images par seconde baissent.
- **Mesures** : un compteur de temps par module (en debug) pour voir ce qui coûte, avant et après.
- **Comportement identique en jeu** : vérifié par les simulations et les tableaux « À tester ».

---

## V9 — Refonte de l'organisation des fichiers

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
- **`TardisConfig` découpée** en un module par domaine, avec les réglages de chaque TARDIS à part. Cela prépare la V10.
- **Comportement identique en jeu** : aucune nouveauté dans la V9, seulement des déplacements. Les simulations (`outils/simulation`) et les tableaux « À tester » des patch notes servent à vérifier que tout marche comme avant.
- `outils/synchro_studio.luau` et le README mis à jour pour la nouvelle arborescence.

À décider : les noms exacts des dossiers, et si on garde la convention Rojo actuelle (`.server.lua`, `.client.lua`, dossier + `init`).

---

## V10 — Les 3 TARDIS, un par pilote

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

## V11 — La console remplace le menu

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
| V11.1 | TARDIS_1 | Écrans d'affichage (lecture seule) |
| V11.2 | TARDIS_1 | Boutons de navigation : destinations, modes, DÉMAT / REMAT |
| V11.3 | TARDIS_1 | Boutons des systèmes : portes, verrou, camouflage, boucliers, siège, alerte, énergie |
| V11.4 | TARDIS_1 | Retrait du menu T et de la tablette Y, derniers réglages |
| V11.5 → V11.8 | TARDIS_3 | ✖ ne sera pas fait |
| V11.9 → V11.12 | TARDIS_2 | ✖ ne sera pas fait |

Questions ouvertes :
- le **vol libre** (piloté aujourd'hui depuis la tablette) ;
- les **joueurs sur mobile** ;
- le **poste du copilote** et la **tablette technicien**.

Restent-ils des interfaces à l'écran, ou passent-ils aussi par la console ?
