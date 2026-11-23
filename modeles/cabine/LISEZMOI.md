# Cabine de police 1:1 (extérieur du TARDIS)

Modèle 3D d'une cabine de police londonienne de 1929 (modèle de Gilbert Mackenzie Trench), à l'échelle réelle.
Généré par `outils/blender/cabine_police_box.py` (Blender 5.3, module `bpy`).

| Mesure | Valeur | Origine |
|---|---|---|
| Hauteur totale (lampe comprise) | 2,84 m | 9 ft 4 in, article « Police box » (Wikipédia), une seule source |
| Largeur du corps | 1,37 m | 4 ft 6 in, même source |
| Socle | 1,52 × 1,52 × 0,10 m | supposé (proportions des photos) |
| Poteaux, enseignes, toiture, lampe | voir les constantes en tête du script | supposé |

## Fichiers

- `cabine_police_box.blend` : scène Blender (collection `Cabine` + collection `Apercu` : sol, soleil, caméra).
- `cabine_police_box.fbx` / `.glb` / `.obj` : la cabine seule, en mètres.
- `cabine_police_box_apercu.png`, `cabine_police_box_portes_ouvertes.png` : rendus Cycles.

## Objets

| Objet | Rôle | Origine (pivot) |
|---|---|---|
| `Corps` | socle, poteaux, 3 faces fixes, linteaux, enseignes, toiture, plancher, plafond | 0, 0, 0 (pied) |
| `Porte_Gauche` | battant avant gauche | charnière : -0,525 ; -0,655 ; 0,11 |
| `Porte_Droite` | battant avant droit, volet du téléphone, serrure | charnière : 0,525 ; -0,655 ; 0,11 |
| `Lampe` | lampe du toit (matériau émissif) | 0, 0, 2,74 |
| `Enseigne_Texte` | « POLICE PUBLIC CALL BOX » sur les 4 faces | — |

Ouverture des portes : rotation Z de `Porte_Gauche` négative, de `Porte_Droite` positive (75° sur le rendu).
Environ 8 300 triangles en tout (dont 6 200 pour les lettres) : sous la limite de 20 000 par maillage de Roblox.

## Dans Roblox Studio

- 1 stud ≈ 0,28 m : à l'échelle des avatars, la cabine fait environ 10,1 studs de haut et 4,9 de large.
- Importer le `.fbx` (ou `.obj`) avec le 3D Importer ; vérifier l'unité choisie à l'import (incertain : selon la version
  de Studio, l'importeur lit les mètres ou les studs ; contrôler la taille obtenue et redimensionner si besoin).
- Les portes sont des maillages séparés avec leur pivot sur la charnière : elles peuvent remplacer `TARDISDoors`.

## Refaire le modèle

```bash
pip install bpy==5.3.0
```

```bash
python outils/blender/cabine_police_box.py modeles/cabine
```
