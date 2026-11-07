# T.A.R.D.I.S.

Système de TARDIS complet pour Roblox, développé pour la place **ZONE-TSADE** (serveur RP SCP) : intérieur plus grand que l'extérieur, (dé)matérialisation, menu et tablette de pilotage, vol libre, vortex, boucliers, régénération façon *Doctor Who*, et plusieurs TARDIS avec chacun ses accès.

**Version actuelle : V7.2.2** (traces au sol : marque selon le mode, givre après une Urgence, gerbe du sol au départ, vent du décollage, brume de nuit, cercle gallifreyen, poussière du plafond, saleté selon le sol ; V7.2.1 : cabine vivante : fenêtres allumées la nuit, vitres sombres sans courant et teintées par l'état de la salle, maintenance visible dehors, frémissement du départ, lampe qui arrive la première, contour pendant la remat, ombres des croisillons, reflet du soleil ; V7.1.2 : banc d'essai des simulations : simulations rangées par sujet, démarrage complet du serveur et du client testé, pièces absentes ou en retard sans plantage, diagnostic des portes intérieures et des vitres, message clair quand une commande obligatoire manque ; V7.1.1 : premier lot de la V7, corrections et oublis du code actuel : auto-destruction annulable, l'équipage ne déclenche plus d'intrusion, outils rendus à la perte du rôle de technicien, reconstitution hors des zones interdites, saut visible sans flash, kaléidoscope plus doux, caméra de la régénération qui évite les murs, effets de voyage à l'échelle de la cabine, simulations qui échouent pour de vrai ; V6.9.17 : maps en Streaming : l'intérieur est rangé au démarrage dans un Model Persistent, le menu T et la tablette Y s'ouvrent sur une map `StreamingEnabled`, diagnostic et import de la structure adaptés ; V6.9.16 : retouches de la console : invite « Vol libre » plus basse, écran ingénieur à l'endroit et ouvert d'un clic, gestion de l'énergie plus large et plus détaillée, animations du kit jouées par les commandes ; V6.9.15 : confort de l'interface et accessibilité : effets réduits d'office sur téléphone, sous-titres des sons, taille de l'interface partout, menus sans animation, tablette fermée d'un clic à côté, menu rapide déplaçable ; V6.9.14 : équipage et garde-robe : casier rangé par catégorie et nouvelles tenues, uniforme de l'équipe à l'apparition, badges des équipes, portes intérieures animées ; V6.9.13 : nouvelles pannes et outils du technicien : fuite d'air, rotor bloqué, scanner, soudeur et brèches ; V6.9.12 : pannes : le socle commun : fréquence des pannes réglable, rapport de panne aux pilotes, historique des 20 dernières pannes, zone de chaque panne, sons des pannes ; V6.9.11 : navigation et fiches de lieux : favoris du copilote en tête, point de base des pilotes, zones à vitesse réduite, fiche du lieu à l'arrivée ; V6.9.10.9 : le leurre disparaît à chaque départ du TARDIS, tuile « Leurre » de la tablette réparée ; V6.9.10.8 : invites de la console remises sur leur commande, seule celle du Vol libre reste relevée ; bouton Vol libre trouvé même si un nom de la map a des espaces en trop ; V6.9.10.7 : tous les menus au nouveau style « Hologramme de confinement » : menu rapide, tablette, tablette technicien, gestion de l'énergie, jukebox, casier, écrans de la console, messages ; V6.9.10.5 : Vol libre sur un Model, caméra du casier, tenues visibles, jukebox par dossier de sons, écran ingénieur pleine face ; V6.9.10.4 : texte des écrans de la console toujours à l'endroit ; V6.9.10.3 : écrans de la console nets et écran ingénieur sur la face visible ; V6.9.10.2 : nouvelle hiérarchie de l'intérieur : le dossier `INTERIEURE` peut contenir directement les pièces, ce qui répare le portail, et les spawns posés dans Studio sont réutilisés ; V6.9.10.1 : ajustements Studio : néons de la salle aux couleurs de l'état, deux écrans de destination faits en script, nouveaux emplacements de l'alerte et du bouton Vol libre, interphone supprimé, écran ingénieur avec menu de l'énergie, casier et jukebox de la console ; V6.9.10 : vol libre et vortex : croisière, caméra en orbite, freinage d'urgence ressenti à bord, rotor qui suit la vitesse du vol, vent du vortex à bord ; V6.9.9 : effets visuels du voyage : distorsion plus forte en Urgence, marque au sol, lueurs selon l'heure, lumières de la salle selon l'état, Catastrophe plus violente, vitres qui s'éteignent en dernier, option « Aucun flash » ; V6.9.8 : vol en formation réglable, thème clair lisible, page d'[état des tests](docs/ETAT_DES_TESTS.md), textes de release, [glossaire](docs/GLOSSAIRE.md) ; V6.9.7 : corrections : poche en Silencieux, joueur visé parti, vol libre sans pilote, chute dans le vide, portée des sons ; V6.9.6 : simulations du code sans Roblox dans `outils/simulation`, intercom mis en pause ; V6.9.5 : équipe C.T.A.T. des techniciens, phare du Sauvetage, clé du TARDIS et crise post-régénération retirées, plus de « Départ dans 3, 2, 1 » ; V6.9.4 : commandes du staff retirées, mode maintenance dans la tablette des pilotes et des techniciens ; V6.9.3 : annonce de bord, traînée du Rapide, enseigne qui clignote, ambiance par thème, statistiques par mode ; V6.9.2 : mode maintenance ; V6.9.1 : copilote et carnet de bord RP ; V6.9 : protocole Silencieux, mode Siège ; V6.8.1 : sauvegarde versionnée, boutons tactiles sur mobile ; V6.8 : accès Adonis / WL, journal vers RoSysLog, remontée des erreurs ; V6.7.3 : intercom du site, jukebox à bord, sons ; V6.7.2 : tablette technicien ; V6.7.1 : modes Classique / Urgence / Rapide / Sauvetage, paradoxe « Catastrophe », zones REFUSE → urgence, méthode de voyage unifiée, spawn de la C.A.T. dans le TARDIS ; V6.7 : refonte visuelle). Voir le [journal des versions](CHANGELOG.md), l'[état des lieux](docs/ETAT_DES_LIEUX.md), les [propositions](docs/PROPOSITIONS.md) la [feuille de route V7 → V12](docs/FEUILLE_DE_ROUTE.md) avec le [plan des 110 propositions gardées](docs/FEUILLE_DE_ROUTE.md#plan-des-110-propositions-gardées) ([tri des 200](docs/PROPOSITIONS_200.md), [analyse détaillée](docs/ANALYSE_PROPOSITIONS.md)) et les [rappels après tests](docs/RAPPELS.md).

**À venir :** V7 · modifications (357 propositions, [plan](docs/PLAN_V7.md)) ; V8 · sécurisation des scripts ; V9 · optimisation et nettoyage du code ; V10 · refonte de l'organisation des fichiers ; V11 · les 3 TARDIS, un par pilote ; V12 · plus de menu, tout sur la console (V12.1 → V12.4 : TARDIS_1).

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
│  ├─ TardisSupervision.server.lua      Script : accès Adonis / WL, journal, erreurs, balise /tardis
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
│                                       Supervision, Copilote, Maintenance, Signalisation,
│                                       Preferences)
└─ Workspace/TARDIS/TARDIS_x/EXTERIEURE/TARDISDoors/
   ├─ LeftDoor/Shut.server.lua          battant gauche (dans chaque TARDIS)
   └─ RightDoor/Shut.server.lua         battant droit (dans chaque TARDIS)
structure/                              le build Studio complet, relevé dans DEVMAP (voir structure/LISEZMOI.md)
├─ Workspace.TARDIS.TARDIS_1.INTERIEURE.rbxm   intérieur du TARDIS_1 (console, commandes, portail, rotor, spawns)
├─ Workspace.TARDIS.TARDIS_1.EXTERIEURE.rbxm   extérieur du TARDIS_1 (cabine, portes)
├─ Workspace.TARDIS.TARDIS_DESTINATIONS.rbxm   destinations de la map de test
├─ Workspace.TARDIS_2.rbxm / TARDIS_3.rbxm     TARDIS de réserve (pas actifs)
├─ ReplicatedStorage.TardisAssets.rbxm         sons du voyage et outils du technicien
├─ index.json                                  parent, taille, empreinte, descendants et position de chaque fichier
└─ ARBORESCENCE.md                             l'arbre lisible de toute la structure
docs/
├─ ETAT_DES_LIEUX.md                    reprise du 29/10/2026 et comparaison avec ZONE-TSADE
├─ ETAT_DES_TESTS.md                    ce qui a été testé en jeu, version par version
├─ GLOSSAIRE.md                         les mots du TARDIS
├─ releases/                            textes des releases GitHub, prêts à coller
├─ PROPOSITIONS.md                      modifications, simplifications et ajouts proposés
└─ patch-notes/V1.md … V6.md            notes détaillées par version et sous-version
outils/
├─ manifeste.py                         liste les scripts de src/ avec leur empreinte (outils/manifeste.json)
├─ synchro_studio.luau                  met Studio à jour depuis le dépôt et vérifie chaque empreinte
├─ importer_structure.luau              charge la structure (structure/*.rbxm) dans une map depuis GitHub, vérifiée par empreinte
├─ remplacer.py                         remplacements exacts et vérifiés dans les fichiers
├─ analyse_luau.py                      variables de niveau principal par section (qui déclare, lit, réaffecte)
├─ decouper.py                          découpe un script en modules, avec vérifications de sûreté
├─ release.py                           prépare le texte de la release GitHub d'une version
├─ etat_tests.py                        refait docs/ETAT_DES_TESTS.md sans perdre les résultats notés
└─ simulation/                          le code joué sans Roblox (sh outils/simulation/lancer.sh)
CHANGELOG.md                            index de toutes les versions
```

Le code de `src/` est **identique octet pour octet** à ce qui tourne dans ZONE-TSADE. Le build (pièces, modèles, petits scripts du kit) est dans `structure/`, au format `.rbxm`. Les suffixes `.server.lua` / `.client.lua` / `.lua` indiquent le type d'objet Roblox (Script / LocalScript / ModuleScript), selon la convention de Rojo.

## Synchroniser Studio avec le dépôt

### Le plus simple : depuis GitHub

Le dépôt est public : dans Studio (mode Édition), coller le contenu de `outils/synchro_github.luau` dans la barre de commande (**View › Command Bar**) et valider. En haut du script, `BRANCHE = "main"` prend la version publiée ; mettre le nom d'une autre branche pour tester une version en cours. Le script lit le commit exact de la branche, télécharge chaque script, vérifie son empreinte et ne réécrit que ce qui diffère. `outils/manifeste.json` est suivi par git : relancer `python3 outils/manifeste.py` avant chaque commit qui touche `src/`.

### Avec un serveur local

```bash
python outils/manifeste.py
```

```bash
python -m http.server 35001 --bind 127.0.0.1
```

Puis, dans Studio (mode Édition), coller le contenu de `outils/synchro_studio.luau` dans la barre de commande. Seuls les scripts qui diffèrent sont réécrits ; chaque script est vérifié par son empreinte, et le rapport liste ce qui a été créé, mis à jour ou supprimé.

### Sans serveur : le paquet .rbxmx

Quand Studio ne peut pas joindre le dépôt (dépôt privé, autre ordinateur) :

```bash
python3 outils/paquet_studio.py
```

Le fichier `dist/TARDIS_MiseAJour_V<version>.rbxmx` contient tous les scripts. Dans Studio (mode Édition) : clic droit sur **Workspace › Insert from File…**, choisir le fichier, puis coller le contenu de `outils/installer_paquet.luau` dans la barre de commande (**View › Command Bar**) et valider. Même vérification par empreinte ; le dossier du paquet est retiré s'il n'y a aucune erreur. Les scripts « Tardis… » de Studio absents du dépôt sont signalés, jamais supprimés.

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

Pour partir du build complet de DEVMAP plutôt que de son propre kit : `structure/` (voir [structure/LISEZMOI.md](structure/LISEZMOI.md)).

Au lancement, l'Output (côté Server) doit afficher, pour chaque TARDIS actif : `serveur prêt`, `extras prêts`, `systèmes prêts`, puis une ligne de **diagnostic** (pièces obligatoires et optionnelles, sons, destinations).

## Touches principales

| Touche | Action |
|---|---|
| T | Menu rapide |
| Y | Tablette (technicien : tablette technicien) |
| E | Portes, commandes de la console, ramassage |
| `/tardis` · `/tardis help` | Balise de détresse (tout le monde) |
| V / G / X | Porter : changer de mode / poser / téléportation de poche |

En vol libre : ZQSD et caméra pour se diriger, F pour la vitesse, V pour le vortex, U pour l'urgence, X pour démat / remat, B pour le saut, Espace ×2 pour la chute, G pour se poser, et H, I, N, P, J, L, M, C, R, O, K pour les modes avancés. Toutes les touches sont modifiables dans les réglages de la tablette.
