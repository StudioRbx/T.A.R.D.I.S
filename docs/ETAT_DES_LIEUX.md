# État des lieux — 29/10/2026

Reprise du projet T.A.R.D.I.S. après l'ancienne conversation (du 9 au 20 octobre 2026), avec une comparaison contre la place Roblox Studio **ZONE-TSADE** (placeId `139437911928851`), ouverte au moment de la reprise.

---

## 1. Résumé

| | |
|---|---|
| **Version déclarée dans le jeu** | `Config.Version = "6.5"` |
| **Sous-version réellement installée** | ≈ **V6.5.12** (voir [docs/patch-notes/V6.md](patch-notes/V6.md)) |
| **Dernière livraison de l'ancienne conversation** | V6.5.14 (20/10/2026) |
| **Scripts du projet** | 17 sur 17 présents, du bon type et au bon endroit |
| **TARDIS actifs dans le Workspace** | 1 (`TARDIS_1`) |
| **TARDIS déclarés dans la config** | 1 (`TARDIS_2` et `TARDIS_3` mis en commentaire le 29/10, voir §6) |

Le jeu tourne sur la V6.5, mais **deux correctifs livrés à la fin de l'ancienne conversation ne sont pas installés**, et la **configuration des accès diffère** de la dernière version envoyée. Tout le reste correspond.

---

## 2. Les 17 scripts dans ZONE-TSADE

Le code de ce dépôt (`src/`) a été exporté directement depuis ZONE-TSADE le 29/10/2026. Il correspond **octet pour octet** à ce qui tourne dans le jeu.

| Script | Type | Emplacement | Lignes |
|---|---|---|---:|
| TardisConfig | ModuleScript | ReplicatedStorage | 503 |
| TardisUI | ModuleScript | ReplicatedStorage | 469 |
| TardisServeur | Script | ServerScriptService | 2 199 |
| TardisExtras | Script | ServerScriptService | 1 359 |
| TardisSystemes | Script | ServerScriptService | 975 |
| TardisLiaisonPortes | Script | ServerScriptService | 68 |
| TardisEffets | LocalScript | StarterPlayerScripts | 584 |
| TardisPortail | LocalScript | StarterPlayerScripts | 424 |
| TardisCamera | LocalScript | StarterPlayerScripts | 232 |
| TardisMenu | LocalScript | StarterPlayerScripts | 696 |
| TardisTablette | LocalScript | StarterPlayerScripts | 2 955 |
| Tardisporter ¹ | LocalScript | StarterPlayerScripts | 238 |
| TardisVolLibre | LocalScript | StarterPlayerScripts | 1 563 |
| TardisRotation | LocalScript | StarterPlayerScripts | 427 |
| TardisExtrasClient | LocalScript | StarterPlayerScripts | 2 022 |
| Shut (LeftDoor) | Script | TARDIS_1 › TARDISDoors › LeftDoor | 85 |
| Shut (RightDoor) | Script | TARDIS_1 › TARDISDoors › RightDoor | 85 |
| **Total** | | | **≈ 14 900** |

¹ Dans Studio, le script s'appelle `Tardisporter` (p minuscule) alors que la conversation l'appelle `TardisPorter`. Ça n'a aucune conséquence, puisqu'aucun script ne le cherche par son nom.

Les 4 scripts serveur sont bien des `Script` dans ServerScriptService. C'était la cause des « outils muets » de la V4.10, quand ils avaient été posés par erreur en LocalScript.

---

## 3. Écarts entre l'ancienne conversation et Studio

### 3.1 Correctifs livrés mais non installés

| Livraison | Date | Script | Constat dans Studio |
|---|---|---|---|
| **V6.5.13** : régénération, accessoires manquants (3 essais de chargement, mémoire des avatars, avatars incompatibles R6 écartés, repli sur l'avatar actuel) | 18/10 | TardisSystemes | ❌ Absent : aucune trace des nouvelles tentatives ni du filtrage R6. Le bug « parfois je n'ai pas mes accessoires » est donc toujours présent. |
| **V6.5.14** : suppression de l'onglet du menu à l'écran (T et Y uniquement) | 20/10 | TardisMenu | ❌ Absent : l'onglet `42 × 92` collé au bord gauche est toujours créé. |

➡️ Pour les installer, il faut recoller ces deux scripts depuis le dernier ZIP `TARDIS V6.5` de l'ancienne conversation. Ils ne sont pas dans ce dépôt, puisque leur code n'a jamais été dans le jeu.

### 3.2 Configuration des accès (`TardisConfig`)

| Réglage | Dernière version envoyée (18/10) | Dans ZONE-TSADE |
|---|---|---|
| `Config.Pilotes.UserIds` | 2039993113, 2973741851, 10819409819, 4366160002, **2467966666**, 3855328330 | 2039993113, 2973741851, 10819409819, 4366160002, 3855328330 |
| `Config.Pilotes.RangMin` | *(retiré)* | `255` (sans effet, car `UniquementUserIds = true`) |
| `Config.Techniciens.UserIds` | 10829137819, 3192865267, **2644152451** | 10829137819, 3192865267, **3855328330** |
| `Config.Tardis` : TARDIS_1, techniciens | 10829137819, 3192865267, 2644152451, 2467966666 | 10829137819, 3192865267, 3855328330 |
| `Config.Tardis` : TARDIS_2 et TARDIS_3 | **en commentaire** (désactivés) | **actifs** ⚠️ |

Conséquences :

- **2467966666** n'a plus aucun accès, et **2644152451** n'est plus technicien.
- **3855328330** est à la fois pilote et technicien. Le rôle pilote l'emporte.
- **TARDIS_2 et TARDIS_3 sont actifs dans la config alors que leurs modèles n'existent plus** dans le Workspace. Leurs exemplaires de scripts démarrent et attendent leurs modèles indéfiniment. L'Output se remplit d'avertissements « Infinite yield » et des scripts tournent pour rien. **À corriger** en remettant les deux lignes en commentaire (`-- { Nom = "TARDIS_2", ... }`).

Ces différences venaient sans doute de modifications faites à la main dans Studio. **Résolu le 29/10 : la config du 18/10 a été remise en place** (voir §6).

### 3.3 Le reste est conforme

Ces fonctionnalités de la V6.5 sont bien installées : mode de voyage Auto/Manuel, régénération « Le Voyageur » avec ses 5 styles, refus, compteur, lien Time Lord et repousse des membres, son `Alarme` en alerte, stabilisateur à 5 % en urgence, correctifs de performance (destinations mémorisées), panneau **Commandes rapides** de la tablette, et `VoyagesAvantCoupure = 15`.

---

## 4. Le modèle dans le Workspace

### 4.1 Hiérarchie

```
Workspace
└─ TARDIS (Folder)
   ├─ TARDIS_1 (Folder)
   │  ├─ EXTERIEURE (Folder) › TARDIS_1 (Model, PrimaryPart = Racine)      ✅
   │  └─ INTERIEURE (Folder) › TARDIS_1_INTERIEURE (Model)                 ✅
   └─ TARDIS_DESTINATIONS (Folder)
      ├─ ACCORDE › Pont, Dummy, Test, Batîment
      └─ REFUSE  › SCP01, Truck
```

- Extérieur à `(132, 60, -420)`, intérieur à `(-256, 705, -475)`.
- `StreamingEnabled = true`, et les deux Models sont en `ModelStreamingMode = Persistent` ✅.
- L'équipe **« Le Voyageur »** existe ✅.

### 4.2 Pièces obligatoires : toutes présentes ✅

Extérieur : `Racine`, `Portail`, `TARDISDoors` (avec `LeftOpen`, `RightOpen`, `Locked`, `LeftDoor`, `RightDoor`), `Lampe` (un Model dans `Exterior › Toiture`, géré depuis la V6.0.5).

Intérieur : `Portail`, `Rotor` (Model), `PortesInterieures`, `Console › Selecteur / Ecran / BoutonCamera`, `Console › LeverLeft › Main › Lever › Main` (verrou), `Console › Circuit › Cloister › Switch` (alerte), `Controls › Matlever › Fly › Levier` (vol), `Controls › LockLever › Main › Lever › Main` (alimentation) et `Controls › Power › On` (démarrage).

### 4.3 Pièces optionnelles absentes (fonctionnalités inactives)

| Pièce attendue | Fonctionnalité qui reste inactive |
|---|---|
| `Arrivee` | Point d'arrivée précis des joueurs embarqués. Le calcul automatique est utilisé, d'où les blocages dans le décor signalés en V6.0.4. |
| `LedsAlerte` | En alerte, toutes les lumières passent au rouge au lieu des seules LED choisies. |
| `Diagnostic1` à `Diagnostic4` | Les 4 écrans de diagnostic. |
| `Casier` | Les casiers à tenues. |
| `ConsoleSecours` | La console de secours. |
| `Vanne` | La vanne de l'incendie (repli sur le rotor). |
| `Murs`, `Sol` | Peinture des murs et styles d'intérieur de la Customisation. |
| Seats `SiegeEquipage` | Sièges d'équipage (secousses réduites). |
| `Grille` / `Grilles` | Une seule `Grille` trouvée : un seul jet de vapeur. |
| Points `ZDC-…` | **La saisie (TARDIS laissé 15 min sans pilote) n'a aucune destination.** |

### 4.4 Sons (`ReplicatedStorage › TardisAssets › Sons`)

Présents : `Demat`, `Remat`, `Demat_Urg`, `Remat_Urg`, `Alarme`.

Absents (optionnels, le TARDIS fonctionne sans eux, en silence) : `Camouflage`, `Decamouflage`, `Cloitre`, `Chute`, `Impact`, `Moteur`, `Moteur_Pose`, `Moteur_Vol`, `Moteur_Urgence`, `Regeneration`. `Config.Jukebox` est vide.

### 4.5 Scripts d'origine du kit encore actifs

L'intérieur vient d'un kit Toolbox, et ses scripts tournent en parallèle de ceux du projet. Ceux que l'ancienne conversation demandait de désactiver sont encore actifs :

- `Console › Screens › ScreenA › Screen › Power` et `ScreenB › Screen › Power` : `Enabled = true`. Ils produisent des erreurs dans l'Output (déjà signalé le 13/10 et le 14/10).
- `TARDISDoors › LeftDoor › Move` et `RightDoor › Move` (anciens scripts d'ouverture au clic) : sans effet, puisque le serveur désactive leurs ClickDetectors depuis la V4.0, mais ils restent chargés.
- `Default Mainscript` et `README:` sont bien désactivés ✅.

Les nombreux scripts d'animation du kit (`FastPhase`, `Oscillate`, `Move` des leviers…) sont décoratifs et peuvent rester.

---

## 5. Recommandations, par priorité

1. **Mettre TARDIS_2 et TARDIS_3 en commentaire** dans `Config.Tardis`.
2. **Trancher la liste des accès** (pilotes et techniciens, voir §3.2), puis la corriger dans `TardisConfig`.
3. **Installer V6.5.13 et V6.5.14** (`TardisSystemes` et `TardisMenu` du dernier ZIP), puis réexporter vers ce dépôt.
4. **Désactiver les deux scripts `Power`** des écrans.
5. **Créer au moins un point `ZDC-…`** dans `TARDIS_DESTINATIONS` pour que la saisie fonctionne, et une Part `Arrivee` dans l'intérieur.
6. **Prochaine étape prévue** dans l'ancienne conversation : la **tablette technicien** de la V6 (informations complètes, aucun contrôle de vol, commandes RP pour l'énergie, l'air, la vapeur, les pannes et les réparations).

---

## 6. Corrections appliquées dans ZONE-TSADE (29/10/2026)

| Recommandation | Statut | Détail |
|---|---|---|
| 1. TARDIS_2 et TARDIS_3 en commentaire | ✅ Fait | `TardisConfig` : `-- { Nom = "TARDIS_2", ... }` et `-- { Nom = "TARDIS_3", ... }`. Fichier du dépôt identique à Studio. |
| 4. Scripts `Power` des écrans | ✅ Fait | `ScreenA › Screen › Power` et `ScreenB › Screen › Power` : `Enabled = false` (objets du modèle, hors dépôt). |
| 2. Liste des accès | ✅ Fait | Décision : **config du 18/10** (V6.5.11). Pilotes 2039993113, 2973741851, 10819409819, 4366160002, 2467966666, 3855328330 ; techniciens 10829137819, 3192865267, 2644152451 ; TARDIS_1 : techniciens + 2644152451 et 2467966666 ; `RangMin` retiré. Vérifié en Play : 6 pilotes, 3 techniciens, le compte de test reconnu pilote par le serveur. |
| 3. V6.5.13 et V6.5.14 | ⏳ À faire | Le code n'est pas dans le jeu. |
| 5. Points `ZDC-…` et `Arrivee` | ⏳ À faire | Objets à placer dans Studio. |

**Vérification en Play :** un seul exemplaire de chaque script serveur (aucun clone `_TARDIS_2` ni `_TARDIS_3`), `TARDIS_1 : extras prêts` et `systèmes prêts` dans l'Output, et le pont `TardisInterne_TARDIS_1` qui répond (état `Pose`, 6 destinations). Le message `serveur prêt` n'a pas pu être relu, car l'historique de l'Output est saturé par les autres systèmes du jeu, mais il est imprimé juste après la création de ce pont.

⚠️ Ces changements ont été faits dans Studio. Il faut **enregistrer ou publier la place** pour les garder.
