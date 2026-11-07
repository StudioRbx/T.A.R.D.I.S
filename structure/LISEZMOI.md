# Structure du TARDIS (build Studio)

Ce dossier contient le **build complet** du TARDIS tel qu'il est dans la map de test **DEVMAP** (V6.9.16, relevé le 07/11/2026) :
les pièces, les modèles et les petits scripts du kit, en plus des scripts du système qui, eux, sont dans `src/`.

| Fichier | Va dans | Contenu | Descendants |
|---|---|---|---|
| `Workspace.TARDIS.TARDIS_1.INTERIEURE.rbxm` | `Workspace › TARDIS › TARDIS_1` | intérieur : console, commandes (Controls), porte, écran, portail, rotor, caméléon, camouflage, portes intérieures, spawns C.T.A.T et C.A.T | 13 313 |
| `Workspace.TARDIS.TARDIS_1.EXTERIEURE.rbxm` | `Workspace › TARDIS › TARDIS_1` | extérieur : Model `TARDIS_1` (PrimaryPart `Racine`), portes `TARDISDoors` et leurs scripts `Shut` | 517 |
| `Workspace.TARDIS.TARDIS_DESTINATIONS.rbxm` | `Workspace › TARDIS` | destinations de la map de test (ACCORDE, REFUSE) : **propres à chaque map**, ne pas écraser celles d'une autre map | 8 |
| `Workspace.TARDIS_2.rbxm` | `Workspace` | TARDIS de réserve (extérieur `TARDIS_3`, intérieur `TARDIS_3_INTERIEURE`) | 5 115 |
| `Workspace.TARDIS_3.rbxm` | `Workspace` | TARDIS de réserve (extérieur `TARDIS_2`, intérieur `TARDIS_2_INTERIEUR`) | 6 250 |
| `ReplicatedStorage.TardisAssets.rbxm` | `ReplicatedStorage` | `Sons` (Demat, Remat, Demat_Urg, Remat_Urg) et `Outils` du technicien (Scanner, Soudeur, Chiffon, Visseuse, CleMolette, Extincteur) | 18 |

`TARDIS_2` et `TARDIS_3` ne sont pas actifs : dans `TardisConfig`, ils ne sont qu'en exemple, en commentaire.

- `index.json` : pour chaque fichier, son parent, sa taille, son **empreinte** (même calcul que `outils/manifeste.json`), le nombre de
  descendants et, pour l'intérieur et l'extérieur, leur position dans DEVMAP (centre de l'intérieur, pivot de l'extérieur).
- `ARBORESCENCE.md` : l'arbre lisible de tout ce qui est dans les fichiers (4 niveaux, éléments répétés regroupés).

## Mettre la structure dans une map

**À la main** : clic droit sur `ServerStorage › Insert from File…`, choisir le `.rbxm`, puis glisser l'objet à sa place. Les positions
sont celles de DEVMAP : déplacer l'intérieur et l'extérieur (Pivot) à l'endroit voulu dans la map.

**Depuis GitHub** : coller `outils/importer_structure.luau` dans la barre de commande (mode Édition). Les fichiers sont téléchargés,
vérifiés et chargés dans `ServerStorage › TARDIS_Structure_V<version>`. Avec `PLACER = true`, chacun est aussi mis à sa place ; ce
qui s'y trouvait est rangé dans `ServerStorage › TARDIS_Sauvegarde_<date>`, jamais supprimé.

Puis mettre les scripts du système à jour avec `outils/synchro_github.luau`.

## Refaire l'export depuis Studio

Dans la barre de commande de DEVMAP, `SerializationService:SerializeInstancesAsync({ objet })` donne le `.rbxm` de l'objet
(`buffer`), à écrire tel quel dans ce dossier ; puis mettre à jour `index.json` (taille, empreinte, descendants) et `ARBORESCENCE.md`.
