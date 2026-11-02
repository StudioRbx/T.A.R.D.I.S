# Feuille de route — V7, V8, V9

> Fixée le 02/11/2026. Les sous-versions V6.9.x continuent d'ici là (modifications et ajouts de [PROPOSITIONS.md](PROPOSITIONS.md)).
> Pour chaque version : **le sujet** (décidé) puis **ce que ça implique** dans le code actuel (lecture du dépôt, à valider ensemble avant de commencer).

| Version | Sujet | État |
|---|---|---|
| **V7** | Refonte presque totale de l'organisation des fichiers | 🔜 prévue |
| **V8** | Les 3 TARDIS officialisés, un TARDIS attribué à chacun des trois pilotes | 🔜 prévue |
| **V9** | Plus de menu : tout passe par la console de commande et ses écrans | 🔜 prévue |
| V9.1 → V9.4 | TARDIS_1 | 🔜 prévue |
| V9.5 → V9.8 | TARDIS_3 | ✖ ne sera pas fait |
| V9.9 → V9.12 | TARDIS_2 | ✖ ne sera pas fait |

---

## V7 — Refonte de l'organisation des fichiers

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
  | `Staff` | supervision, maintenance, recette, journal |
  | `Sauvegarde` | sauvegarde |
  | `Interface` | menus, tablette, poste du copilote |
  | `Effets` | effets visuels et sonores |

- **Un seul point d'entrée** par côté : un Script serveur et un LocalScript client, qui chargent les modules de chaque domaine. On n'a plus de scripts qui se parlent par RemoteEvent et BindableFunction « parce qu'ils sont séparés ».
- **`TardisConfig` découpée** en un module par domaine, avec les réglages de chaque TARDIS à part. Cela prépare la V8.
- **Comportement identique en jeu** : aucune nouveauté dans la V7, seulement des déplacements. La recette automatique (`/tardis recette`, V6.9.2) sert à vérifier que tout marche comme avant.
- `outils/synchro_studio.luau` et le README mis à jour pour la nouvelle arborescence.

À décider : les noms exacts des dossiers, et si on garde la convention Rojo actuelle (`.server.lua`, `.client.lua`, dossier + `init`).

---

## V8 — Les 3 TARDIS, un par pilote

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

## V9 — La console remplace le menu

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
| V9.1 | TARDIS_1 | Écrans d'affichage (lecture seule) |
| V9.2 | TARDIS_1 | Boutons de navigation : destinations, modes, DÉMAT / REMAT |
| V9.3 | TARDIS_1 | Boutons des systèmes : portes, verrou, camouflage, boucliers, siège, alerte, énergie |
| V9.4 | TARDIS_1 | Retrait du menu T et de la tablette Y, derniers réglages |
| V9.5 → V9.8 | TARDIS_3 | ✖ ne sera pas fait |
| V9.9 → V9.12 | TARDIS_2 | ✖ ne sera pas fait |

Questions ouvertes :
- le **vol libre** (piloté aujourd'hui depuis la tablette) ;
- les **joueurs sur mobile** ;
- le **poste du copilote** et la **tablette technicien** ;
- les **commandes du staff**.

Restent-ils des interfaces à l'écran, ou passent-ils aussi par la console ?
