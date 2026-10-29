# T.A.R.D.I.S.

Système de TARDIS complet pour Roblox, développé pour la place **ZONE-TSADE** (serveur RP SCP) : intérieur plus grand que l'extérieur, (dé)matérialisation, menu et tablette de pilotage, vol libre, vortex, boucliers, régénération façon *Doctor Who*, et plusieurs TARDIS avec chacun ses accès.

**Version actuelle : V6.6** (mode Express). Voir le [journal des versions](CHANGELOG.md), l'[état des lieux](docs/ETAT_DES_LIEUX.md) et les [propositions](docs/PROPOSITIONS.md).

---

## Contenu du dépôt

```
src/
├─ ReplicatedStorage/
│  ├─ TardisConfig.lua                  ModuleScript : tous les réglages, accès, outils multi-TARDIS
│  └─ TardisUI.lua                      ModuleScript : briques d'interface et styles partagés
├─ ServerScriptService/
│  ├─ TardisServeur.server.lua          Script : états, voyages, console, vol libre (autorité serveur)
│  ├─ TardisExtras.server.lua           Script : outils, rôles, zones, auto-destruction, sauvegarde des préférences
│  ├─ TardisSystemes.server.lua         Script : PV, boucliers, pannes, régénération, techniciens
│  └─ TardisLiaisonPortes.server.lua    Script : pont entre les portes du kit et le système
├─ StarterPlayer/StarterPlayerScripts/
│  ├─ TardisEffets.client.lua           (dé)matérialisation, lampe, rotor, lumières, secousses
│  ├─ TardisPortail.client.lua          vues à travers la porte et passage
│  ├─ TardisCamera.client.lua           caméra au-dessus de la Lampe
│  ├─ TardisMenu.client.lua             menu rapide (T)
│  ├─ TardisTablette.client.lua         tablette avancée (Y)
│  ├─ Tardisporter.client.lua           TARDIS porté (main, ceinture, épaule)
│  ├─ TardisVolLibre.client.lua         vol libre à la 3ᵉ personne
│  ├─ TardisRotation.client.lua         repositionnement fin
│  └─ TardisExtrasClient.client.lua     effets et interfaces des extras et systèmes
└─ Workspace/TARDIS/TARDIS_x/EXTERIEURE/TARDISDoors/
   ├─ LeftDoor/Shut.server.lua          battant gauche (dans chaque TARDIS)
   └─ RightDoor/Shut.server.lua         battant droit (dans chaque TARDIS)
docs/
├─ ETAT_DES_LIEUX.md                    reprise du 29/10/2026 et comparaison avec ZONE-TSADE
└─ patch-notes/V1.md … V6.md            notes détaillées par version et sous-version
CHANGELOG.md                            index de toutes les versions
```

Le code de `src/` a été **exporté directement depuis ZONE-TSADE** le 29/10/2026, et il est identique octet pour octet à ce qui tourne dans le jeu. Les suffixes `.server.lua` / `.client.lua` / `.lua` indiquent le type d'objet Roblox (Script / LocalScript / ModuleScript), selon la convention de Rojo.

## Installation dans Studio

1. **ReplicatedStorage** : `TardisConfig` et `TardisUI` (ModuleScripts), plus le dossier `TardisAssets › Sons` (`Demat`, `Remat`, `Demat_Urg`, `Remat_Urg`, `Alarme`…).
2. **ServerScriptService** : les 4 **Script** (`TardisServeur`, `TardisExtras`, `TardisSystemes`, `TardisLiaisonPortes`). ⚠️ Ce sont des Script, pas des LocalScript.
3. **StarterPlayer › StarterPlayerScripts** : les 9 **LocalScript**.
4. Dans **chaque** TARDIS : un `Shut` (Script) dans `TARDISDoors › LeftDoor` et un autre dans `RightDoor`.
5. Workspace :
   ```
   TARDIS (Folder)
   ├─ TARDIS_1 (Folder) › EXTERIEURE (Folder) › <Model, PrimaryPart = Racine>
   │                    › INTERIEURE (Folder) › <Model>
   └─ TARDIS_DESTINATIONS (Folder) › ACCORDE / REFUSE
   ```
6. `TardisConfig` : renseigner `Config.Pilotes`, `Config.Techniciens` et `Config.Tardis` (mettre en commentaire les TARDIS qui n'existent pas dans le Workspace).
7. Paramètres du jeu › Sécurité : **Enable Studio Access to API Services** (sauvegarde) ; avec StreamingEnabled, `ModelStreamingMode = Persistent` sur les Models du TARDIS.

Au lancement, l'Output (côté Server) doit afficher, pour chaque TARDIS actif : `serveur prêt`, `extras prêts` et `systèmes prêts`.

## Touches principales

| Touche | Action |
|---|---|
| T | Menu rapide |
| Y | Tablette |
| E | Portes, commandes de la console, ramassage |
| V / G / X | Porter : changer de mode / poser / téléportation de poche |

En vol libre : ZQSD et caméra pour se diriger, F pour la vitesse, V pour le vortex, U pour l'urgence, X pour démat / remat, B pour le saut, Espace ×2 pour la chute, G pour se poser, et H, I, N, P, J, L, M, C, R, O, K pour les modes avancés. Toutes les touches sont modifiables dans les réglages de la tablette.
