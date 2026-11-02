# T.A.R.D.I.S.

Système de TARDIS complet pour Roblox, développé pour la place **ZONE-TSADE** (serveur RP SCP) : intérieur plus grand que l'extérieur, (dé)matérialisation, menu et tablette de pilotage, vol libre, vortex, boucliers, régénération façon *Doctor Who*, et plusieurs TARDIS avec chacun ses accès.

**Version actuelle : V6.9.1** (copilote et carnet de bord RP ; V6.9 : protocole Silencieux, mode Siège, clé du TARDIS, crise post-régénération ; V6.8.1 : sauvegarde versionnée, boutons tactiles sur mobile ; V6.8 : accès Adonis / WL, journal vers RoSysLog, commandes du staff `/tardis statut`, remontée des erreurs ; V6.7.3 : intercom du site, jukebox à bord, sons ; V6.7.2 : tablette technicien ; V6.7.1 : modes Classique / Urgence / Rapide / Sauvetage, paradoxe « Catastrophe », zones REFUSE → urgence, méthode de voyage unifiée, spawn de la C.A.T. dans le TARDIS ; V6.7 : refonte visuelle). Voir le [journal des versions](CHANGELOG.md), l'[état des lieux](docs/ETAT_DES_LIEUX.md) et les [propositions](docs/PROPOSITIONS.md).

---

## Contenu du dépôt

```
src/
├─ ReplicatedStorage/
│  ├─ TardisConfig.lua                  ModuleScript : tous les réglages (dont Config.Modes), accès, outils multi-TARDIS
│  ├─ TardisUI.lua                      ModuleScript : briques d'interface et styles partagés
│  └─ TardisCommandes.lua               ModuleScript : commandes de voyage et protocoles partagés par le menu et la tablette
├─ ServerScriptService/
│  ├─ TardisServeur/                    Script : états, voyages, console (autorité serveur)
│  │  ├─ init.server.lua                le script lui-même
│  │  └─ VolLibre.lua                   module : vol libre piloté depuis la tablette
│  ├─ TardisExtras.server.lua           Script : outils, rôles, zones, auto-destruction, sauvegarde des préférences
│  ├─ TardisSystemes.server.lua         Script : PV, boucliers, pannes, régénération, techniciens
│  ├─ TardisLiaisonPortes.server.lua    Script : pont entre les portes du kit et le système
│  ├─ TardisPontFondation.server.lua    Script : annonce les failles spatio-temporelles (OS Fondation ou annonce intégrée)
│  ├─ TardisSupervision.server.lua      Script : accès Adonis / WL, journal, commandes du staff (/tardis statut), erreurs
│  ├─ TardisDiagnostic.lua              ModuleScript : diagnostic au démarrage (une ligne dans l'Output)
│  └─ TardisSauvegarde.lua              ModuleScript : sauvegarde versionnée (enveloppe, migration, réessais)
├─ StarterPlayer/StarterPlayerScripts/
│  ├─ TardisEffets.client.lua           (dé)matérialisation, lampe, rotor, lumières, secousses
│  ├─ TardisPortail.client.lua          vues à travers la porte et passage
│  ├─ TardisCamera.client.lua           caméra au-dessus de la Lampe
│  ├─ TardisMenu.client.lua             menu rapide (T)
│  ├─ TardisTablette/                   tablette avancée (Y) : init.client.lua + 10 modules
│  │                                   (Construction, Etat, Navigation, Ouverture, Placement, Volet, Scanner, Suivi, Journal, Outils)
│  ├─ TardisPorter.client.lua           TARDIS porté (main, ceinture, épaule)
│  ├─ TardisVolLibre.client.lua         vol libre à la 3ᵉ personne
│  ├─ TardisRotation.client.lua         repositionnement fin
│  └─ TardisExtrasClient/               effets et interfaces des extras et systèmes : init.client.lua + 14 modules
│                                      (Ambiance, EffetsExterieurs, Replay, AutoDestruction, Interactions, Boucliers,
│                                       Regeneration, Systemes, Decor, TabletteLecture, TabletteTechnicien, Intercom,
│                                       Supervision, Copilote, Preferences)
└─ Workspace/TARDIS/TARDIS_x/EXTERIEURE/TARDISDoors/
   ├─ LeftDoor/Shut.server.lua          battant gauche (dans chaque TARDIS)
   └─ RightDoor/Shut.server.lua         battant droit (dans chaque TARDIS)
docs/
├─ ETAT_DES_LIEUX.md                    reprise du 29/10/2026 et comparaison avec ZONE-TSADE
├─ PROPOSITIONS.md                      modifications, simplifications et ajouts proposés
└─ patch-notes/V1.md … V6.md            notes détaillées par version et sous-version
outils/
├─ manifeste.py                         liste les scripts de src/ avec leur empreinte (outils/manifeste.json)
├─ synchro_studio.luau                  met Studio à jour depuis le dépôt et vérifie chaque empreinte
├─ remplacer.py                         remplacements exacts et vérifiés dans les fichiers
├─ analyse_luau.py                      variables de niveau principal par section (qui déclare, lit, réaffecte)
└─ decouper.py                          découpe un script en modules, avec vérifications de sûreté
CHANGELOG.md                            index de toutes les versions
```

Le code de `src/` est **identique octet pour octet** à ce qui tourne dans ZONE-TSADE. Les suffixes `.server.lua` / `.client.lua` / `.lua` indiquent le type d'objet Roblox (Script / LocalScript / ModuleScript), selon la convention de Rojo.

## Synchroniser Studio avec le dépôt

```bash
python outils/manifeste.py
```

```bash
python -m http.server 35001 --bind 127.0.0.1
```

Puis, dans Studio (mode Édition), coller le contenu de `outils/synchro_studio.luau` dans la barre de commande. Seuls les scripts qui diffèrent sont réécrits ; chaque script est vérifié par son empreinte, et le rapport liste ce qui a été créé, mis à jour ou supprimé.

## Installation dans Studio

1. **ReplicatedStorage** : `TardisConfig`, `TardisUI` et `TardisCommandes` (ModuleScripts), plus le dossier `TardisAssets › Sons` (`Demat`, `Remat`, `Demat_Urg`, `Remat_Urg`, `Alarme`…).
2. **ServerScriptService** : les 6 **Script** (`TardisServeur`, `TardisExtras`, `TardisSystemes`, `TardisLiaisonPortes`, `TardisPontFondation`, `TardisSupervision`) et les ModuleScripts `TardisDiagnostic` et `TardisSauvegarde`. ⚠️ Ce sont des Script, pas des LocalScript.
3. **StarterPlayer › StarterPlayerScripts** : les 9 **LocalScript**.
4. Dans **chaque** TARDIS : un `Shut` (Script) dans `TARDISDoors › LeftDoor` et un autre dans `RightDoor`.
5. Workspace :
   ```
   TARDIS (Folder)
   ├─ TARDIS_1 (Folder) › EXTERIEURE (Folder) › <Model, PrimaryPart = Racine>
   │                    › INTERIEURE (Folder) › <Model>
   └─ TARDIS_DESTINATIONS (Folder) › ACCORDE / REFUSE / SANS_EXPRESS
   ```
6. `TardisConfig` : renseigner `Config.Pilotes`, `Config.Techniciens` et `Config.Tardis` (mettre en commentaire les TARDIS qui n'existent pas dans le Workspace).
7. Paramètres du jeu › Sécurité : **Enable Studio Access to API Services** (sauvegarde) ; avec StreamingEnabled, `ModelStreamingMode = Persistent` sur les Models du TARDIS.

Au lancement, l'Output (côté Server) doit afficher, pour chaque TARDIS actif : `serveur prêt`, `extras prêts`, `systèmes prêts`, puis une ligne de **diagnostic** (pièces obligatoires et optionnelles, sons, destinations).

## Touches principales

| Touche | Action |
|---|---|
| T | Menu rapide |
| Y | Tablette (technicien : tablette technicien) |
| E | Portes, commandes de la console, ramassage |
| `/tardis statut` · `journal` · `erreurs` | Commandes de chat du staff (lecture seule) ; `/tardis help` : balise de détresse |
| V / G / X | Porter : changer de mode / poser / téléportation de poche |

En vol libre : ZQSD et caméra pour se diriger, F pour la vitesse, V pour le vortex, U pour l'urgence, X pour démat / remat, B pour le saut, Espace ×2 pour la chute, G pour se poser, et H, I, N, P, J, L, M, C, R, O, K pour les modes avancés. Toutes les touches sont modifiables dans les réglages de la tablette.
