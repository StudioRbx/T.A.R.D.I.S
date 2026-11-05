# Rappels — à faire après l'installation et les tests dans Roblox Studio

> Tenu à jour par Claude. Quand tu as publié et testé une version dans Studio, ces points te sont rappelés (même sans le demander).

## 1. Intercom du site (mis en pause le 02/11/2026)
- Le bloc `Config.Intercom` de `TardisConfig` est **en commentaire** : aucune annonce « faille spatio-temporelle » ni aucun rappel.
- Pour le remettre : enlever les `--` devant les 8 lignes du bloc, puis (si l'OS Fondation doit faire l'annonce) renseigner `Cible` avec le chemin de l'objet de l'OS.

## 2. Objets à placer dans Studio
Le diagnostic au démarrage (Output : `[TARDIS] TARDIS_1 : … pièces`) liste ce qui manque. À placer dans l'intérieur ou les destinations de TARDIS_1 :
- **`Arrivee`** (Part) : point d'apparition à bord, et spawns des équipes C.A.T. et C.T.A.T. (sinon : derrière la porte intérieure) ;
- **points `ZDC-…`** dans `TARDIS_Destinations` : points de saisie ;
- **`Diagnostic1` à `Diagnostic4`** : écrans de diagnostic ;
- **`Casier`** : casiers (tenues) ;
- **`Vanne`** : vanne de la panne d'incendie (clé à molette) ;
- **`Murs`** et **`Sol`** : pour la couleur des murs et le style de l'intérieur ;
- **`SiegeEquipage`** : sièges de l'équipage ;
- **`Grille`** (ou un dossier `Grilles`) : vapeur et purge ;
- sous-dossiers de destinations **`REFUSE`** et **`SANS_EXPRESS`** si tu veux des zones interdites ;
- **V6.9.9** : ranger les vitres de la cabine dans un dossier **`Fenetres`** de l'extérieur, ou les nommer **`Vitre`** (vitres qui s'éteignent en dernier) ; vérifier que la salle contient des **PointLight** ou **SpotLight** (lumières selon l'état) ;
- supprimer les scripts du kit désactivés (`Default Mainscript`, `README:`, les `Move` / `MainPhase` des portes).

## 3. Équipes
- **C.A.T.** : à créer dans Teams (pilotes, régénération) si ce n'est pas déjà fait.
- **C.T.A.T.** : créée automatiquement par le script si elle n'existe pas ; si tu la crées toi-même, une **couleur différente** de celle de la C.A.T.

## 4. Sons
- Voir la liste de sons proposés (02/11) : les identifiants choisis vont dans `Config.Sons`, `Config.Jukebox` et `Config.AmbianceThemes`, ou dans `ReplicatedStorage › TardisAssets › Sons`.

## 5. Branchements au jeu (quand tu pourras)
- Adonis (`G_API`) et niveaux dans `Config.Acces.Adonis` ; module WL (`Config.Acces.WL`) ; journal RoSysLog (`Config.Journal.Cible`).

## 6. Tests en jeu et releases (V6.9.8)
- Après tes tests, donne-moi les résultats : je les note dans [ETAT_DES_TESTS.md](ETAT_DES_TESTS.md) (86 tests de la V6.7 à la V6.9.8, dont 18 déjà sans objet).
- **15 releases** à publier sur GitHub (V6.7 → V6.9.8) : les textes sont prêts dans [`docs/releases/`](releases/). Pour chacune : Releases › Draft a new release › tag `v6.x.y` sur `main`, titre et texte du fichier. Ensuite, ajoute le tag dans `docs/releases/publiees.txt` (ou dis-le-moi).

## 7. Plus tard (tu m'expliqueras)
- Ce qui remplacera la **clé du TARDIS**.
