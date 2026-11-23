# TARDIS (ère du 15e Docteur) — modèle Blender 1:1

Environnement : Blender 5.3 (module Python `bpy`), rendu Cycles. Unités : mètres, avant du TARDIS vers -Y, sol à Z = 0.

## Fichiers
- `TARDIS_15e_Docteur.blend` : scène complète (textures empaquetées).
- `render_preview.png` : aperçu portes fermées. `render_portes_ouvertes.png` : contrôle de l'intérieur, portes à 70°.
- `scripts/make_textures.py` : enseigne, plaque « PULL TO OPEN », badge (Pillow).
- `scripts/build_tardis.py` : construit la scène, vérifie l'ouverture des portes, sauvegarde et rend.

## Reconstruire
```bash
python3 blender/scripts/make_textures.py
```
```bash
blender -b -P blender/scripts/build_tardis.py
```
Variables : `TARDIS_RENDU=0` (pas de rendu), `TARDIS_ECHANTILLONS` (128), `TARDIS_POURCENT` (100).

## Portes (pour le script d'animation)
| Objet | Origine (axe des charnières) | Ouverture vers l'intérieur |
|---|---|---|
| `Porte_Gauche` | x = -0,547 ; y = -0,635 ; z = 0,105 | `rotation_euler.z` positif |
| `Porte_Droite` | x = +0,547 ; y = -0,635 ; z = 0,105 | `rotation_euler.z` négatif |

- Enfants parentés : `_Panneaux`, `_Petits_Bois`, `_Vitre`, charnières, plaque (gauche), badge, serrure et poignée (droite).
- Angle utile : 0 à 95° (au-delà de ~98°, le battant touche la façade latérale intérieure).
- L'intérieur est fermé (plancher, plafond lumineux, faces intérieures lambrissées) : aucun vide visible à l'ouverture.
