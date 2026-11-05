# Glossaire du TARDIS

Les mots du système TARDIS de ZONE-TSADE, dans le jeu et dans le code (proposition 200, V6.9.8).
Entre parenthèses : le nom utilisé dans le code ou dans `TardisConfig`, quand il est différent.

## Le voyage

| Terme | Sens |
|---|---|
| **Démat** (dématérialisation) | Le TARDIS s'efface de l'endroit où il est posé, par à-coups calés sur le son. État `Demat`. |
| **Vortex** | L'entre-deux du voyage : le TARDIS n'est plus nulle part. État `Vol`. Depuis la V3.10, c'est aussi un décor de tunnel dans le ciel pendant le vol libre. |
| **Remat** (rematérialisation) | Le TARDIS apparaît à destination. État `Remat`, puis `Pose`. |
| **Posé** | Le TARDIS est à l'arrêt, portes utilisables. État `Pose`. |
| **Destination** | Une Part du dossier `TARDIS_DESTINATIONS`, un joueur, ou des coordonnées libres. Elle s'affiche sur les écrans de la console. |
| **Zones** | Sous-dossiers de `TARDIS_DESTINATIONS` : `ACCORDE` (atterrissage normal), `REFUSE` (seule une remat d'Urgence y est possible), `SANS_EXPRESS` (un voyage Rapide y devient Classique). |
| **Repli** | Si le joueur visé quitte le jeu pendant le voyage, le TARDIS revient à son point de départ (V6.9.7). |
| **Téléportation de poche** | Voyage lancé alors que le TARDIS est rapetissé et porté par un joueur (V4.1). |
| **Empreinte temporelle** | Silhouette translucide du TARDIS, en néon bleu clair, qui reste 30 s à l'ancien emplacement après un départ visible (V6.6.2). Rien à voir avec l'empreinte des scripts de `outils/manifeste.py`. |

## Les modes de voyage (`Config.Modes`)

| Terme | Sens |
|---|---|
| **Classique** (`Normal`) | Démat et remat complètes, avec le son d'origine. |
| **Urgence** | Saccades, arcs électriques, sons d'alarme. Le seul mode qui peut se poser en zone `REFUSE`. |
| **Rapide** (`Express`, renommé en V6.6) | Voyage éclair de 2 souffles, avec traînée lumineuse. |
| **Sauvetage** | Remat en tournant, phare de quatre SurfaceLights autour de la cabine (V6.7.1, V6.9.5). |
| **Silencieux** | Aucun son ni effet visible dehors ; rotor violet à bord (V6.9). |
| **Catastrophe** (paradoxe) | Ce qui arrive quand la destination est à l'intérieur du TARDIS : le voyage tourne mal, avec dégâts. Ce n'est pas un mode qu'on choisit. |

## Le vol libre

| Terme | Sens |
|---|---|
| **Vol libre** | Le pilote conduit la cabine elle-même dans le ciel (V3.8, refait en V3.9). |
| **Niveaux** | Les 4 vitesses : LENT, NORMAL, RAPIDE, TURBO (touche F). |
| **Saut temporel** | Bond en avant de quelques dizaines de studs (touche B). |
| **Formation** (verrouillage de cible) | Le TARDIS suit un joueur ou un véhicule à distance fixe (touche L). Distance, hauteur et portée : `Config.VolLibre.Formation` (V6.9.8). |
| **Stationnaire** / **Planeur** / **Précision** | Rester sur place (H), planer (J), demi-vitesse sans collision (P). |
| **Atterrir ici** | Le TARDIS se pose sous lui en douceur (touche N). Il le fait aussi seul si le pilote ne donne plus de nouvelles pendant 8 s (V6.9.7). |
| **Rayon tracteur** | Attire et transporte un objet ou un joueur (touche R). |
| **Turbulences** | Poussée sur les joueurs proches du TARDIS en vol. |

## La cabine et ses systèmes

| Terme | Sens |
|---|---|
| **Extérieur** (`EXTERIEURE`) / **Intérieur** (`INTERIEURE`) | La cabine bleue, et la salle plus grande que la cabine. La salle est soit le dossier `INTERIEURE` lui-même (quand il contient directement `Portail` ou `Rotor`, V6.9.10.2), soit le Model qu'il contient. |
| **Racine** | La Part principale (PrimaryPart) de l'extérieur, par laquelle le TARDIS est déplacé. |
| **Lampe** | Le fanal au sommet de la cabine ; elle clignote pendant les voyages. |
| **Portail** | La vue de l'intérieur à travers la porte ouverte, et le passage d'un côté à l'autre. |
| **Console** | Le pupitre central : levier de vol, sélecteur (avec le bouton Vol libre, `Colors`), écrans de destination, écran ingénieur, verrou, alimentation, alerte (`Datapanel`), démarrage, casier et jukebox. |
| **Écrans de destination** | Les pièces `Ecran` de la console (une, deux ou plus) : destination, état, mode, alertes ; affichage fait en script, face choisie par l'attribut `FaceEcran` (V6.9.10.1). |
| **Écran ingénieur** (`Ecran-Ingenieure`) | Écran de la console qui montre en direct l'intégrité, l'énergie, la régulation et les boucliers ; un clic d'un pilote ou d'un technicien ouvre le menu de gestion de l'énergie (V6.9.10.1). |
| **Rotor** | La colonne centrale de la console ; sa couleur suit le mode de voyage. |
| **Alimentation** | Courant du TARDIS : coupé, plus rien ne marche à bord. |
| **Boucliers** | Protection contre les joueurs et les balles (V3.14). |
| **Siège** | Bouclier complet, portes verrouillées et alerte d'un seul coup (V6.9). |
| **Camouflage** | Le TARDIS devient invisible quand il est posé. |
| **Points de vie**, **Pannes** | La santé du TARDIS, et les avaries que le technicien répare. |
| **Rapetisser** / **Porter** | Réduire le TARDIS et le prendre en main, à la ceinture ou sur l'épaule (V2.5). |
| **Sentinelle** | Prévient les pilotes quand quelqu'un s'approche du TARDIS posé. |
| **Maintenance** | Pilotes ou techniciens bloquent les voyages depuis la tablette, avec une raison affichée (V6.9.2, V6.9.4). |
| **Auto-destruction** | Procédure en 3 étapes, avec minuterie annulable. |
| **Sauvegarde** | Position, taille, réglages et historique gardés dans un DataStore versionné (V6.8.1). |

## L'équipage

| Terme | Sens |
|---|---|
| **Pilote** | Peut tout faire avec le TARDIS. Il y a un TARDIS par pilote à partir de la V11. |
| **Copilote** | Passager qui reçoit un poste de navigation donné par un pilote (V6.9.1). |
| **Technicien** | Répare les pannes, a sa propre tablette (V6.7.2). Ne se régénère pas. |
| **C.A.T.** | L'équipe Roblox des pilotes. |
| **C.T.A.T.** (Cellule Technique d'Autorité Temporelle) | L'équipe Roblox des techniciens (V6.9.5). |
| **Régénération** | Quand un pilote meurt, il change d'apparence au lieu de mourir, avec l'un des styles d'animation. |
| **Carnet de bord** | Les notes RP de l'équipage, par lieu, filtrées par Roblox et sauvegardées (les 80 plus récentes, V6.9.1). |
| **Journal** | Liste des événements (décollages, atterrissages, pannes, erreurs), envoyée au journal du jeu si `Config.Journal.Cible` est rempli (V6.8). |
| **Balise de détresse** | `/tardis` ou `/tardis help` dans le chat : signale le joueur aux pilotes des 3 TARDIS, avec un bouton Y ALLER. |

## Les interfaces

| Terme | Sens |
|---|---|
| **Menu rapide** (touche T) | Le menu classique : destinations avec recherche, démat, remat. |
| **Tablette** (touche Y) | L'interface avancée : navigation, scanner, outils, réglages, journal. |
| **Tablette technicien** | La tablette des techniciens : pannes et réparations. |
| **Thèmes** | Apparence des menus : Gallifrey (clair), Cristal et Police Box (sombres). |
| **Boutons tactiles** | Boutons T et Y sur téléphone et tablette (V6.8.1). |

## Le code et les outils

| Terme | Sens |
|---|---|
| **TARDIS_x** | Le modèle de référence dans `src/Workspace/TARDIS` ; il est copié pour chaque TARDIS (TARDIS_1, TARDIS_2…). |
| **Attributs** | Valeurs posées par le serveur sur l'extérieur (`Etat`, `Mode`, `Verrouille`…) et lues par les clients. |
| **RemoteEvent** | Canal entre les menus des joueurs et le serveur, un par TARDIS. Le serveur vérifie chaque demande. |
| **Pont interne** (`TardisInterne_<nom>`) | BindableFunction par laquelle les scripts serveur se parlent entre eux. |
| **Manifeste** / **Synchro Studio** | La liste des scripts avec leur empreinte, et le script qui met Studio à jour depuis le dépôt. |
| **Simulations** | `outils/simulation/` : le code Luau joué en Python sans Roblox, pour vérifier la logique avant les tests en jeu. |
| **État des tests** | `docs/ETAT_DES_TESTS.md` : ce qui a été essayé en jeu, version par version (V6.9.8). |
| **Release** | Une version publiée sur GitHub ; `outils/release.py` prépare son texte (V6.9.8). |
