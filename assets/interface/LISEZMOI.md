# Images de l'interface « Hologramme de confinement » (V6.9.10.6)

Roblox ne sait pas découper un cadre en biais. Les panneaux, les boutons et les puces des menus du TARDIS utilisent donc
trois petites images blanches, teintées en jeu (`ImageColor3`). **Elles sont facultatives** : sans elles, les menus
gardent des coins droits avec un petit trait en biais dans les deux coins coupés, et il n'y a pas de lignes de balayage.

| Fichier | Taille | Contenu | Réglage dans `TardisConfig` |
|---|---|---|---|
| `coin_fond.png` | 64 × 64 | la forme pleine : coins coupés de 16 px en haut à droite et en bas à gauche | `Config.Interface.Images.CoinFond` |
| `coin_bord.png` | 64 × 64 | la même forme, en contour blanc de 2 px | `Config.Interface.Images.CoinBord` |
| `balayage.png` | 8 × 3 | une ligne blanche à moitié transparente toutes les 3 lignes (motif répété) | `Config.Interface.Images.Balayage` |

## Importer les images dans Studio

1. Ouvre la place dans Studio, puis **Affichage › Gestionnaire de ressources** (*View › Asset Manager*).
2. Clique sur **Importer** (*Bulk Import*) et choisis les trois fichiers de ce dossier. Attends la fin de la modération.
3. Dans le dossier **Images** du gestionnaire, clic droit sur chaque image › **Copier l'identifiant** (*Copy ID to Clipboard*).
4. Colle les identifiants dans `ReplicatedStorage › TardisConfig`, bloc `Config.Interface` (tout en bas du fichier) :

```lua
Config.Interface = {
	Images = { CoinFond = 1234567890, CoinBord = 1234567891, Balayage = 1234567892 },
	...
}
```

Un nombre (`1234567890`) ou un texte (`"rbxassetid://1234567890"`) conviennent. `0` = image absente. Il faut au moins
`CoinFond` pour les coins coupés ; `CoinBord` dessine leur filet (sans lui, les panneaux découpés n'ont pas de bord).

## Réglages 9 tranches (déjà faits par le code)

Le code (`TardisUI.decouper`) pose lui-même ces réglages sur les `ImageLabel` « FondCoupe » et « BordCoupe » :

- `ScaleType = Slice`, `SliceCenter = Rect.new(16, 16, 48, 48)` (les quatre coins de 16 px restent nets, quelle que
  soit la taille du panneau) ;
- `SliceScale` = coupe ÷ 16 : **1** pour les panneaux (coupe de 16 px), **0,75** pour les panneaux de la tablette
  (12 px), **0,625** pour les boutons (10 px), **0,5** pour les puces (8 px) ;
- la lueur des grands panneaux réutilise `coin_bord.png`, 3 px plus grande et très transparente.

Pour `balayage.png` : `ScaleType = Tile`, `TileSize = 8 × 3`, `ResampleMode = Pixelated`, teinte du texte, transparence 0,9.
Les lignes de balayage et la lueur sont coupées par l'option « Réduire les effets » des réglages de la tablette.

## Refaire les images

Les formes sont simples : un carré de 64 px dont on coupe en biais les coins haut droit et bas gauche (16 px), en blanc
(seule l'opacité varie, pour que la teinte de Roblox reste exacte). Si tu les redessines, garde la taille, la coupe et
le blanc, sinon `SliceCenter` ne tombe plus juste.
