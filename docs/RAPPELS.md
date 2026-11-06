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
- **V6.9.10.1, la console** (rien d'autre à construire : les affichages et les boutons sont faits par les scripts) :
  - **néons** : les pièces en matériau **Neon** de l'intérieur prennent les couleurs de l'état (sauf rotor, `LedsAlerte`, écrans) ; une pièce qui ne doit jamais changer : la ranger dans `LedsAlerte`, ou ajouter son nom à `Config.NeonsSalle.Exclure` ;
  - **deux écrans de destination** : deux pièces nommées **`Ecran`** dans `Console`, ou un Model **`Ecran`** qui contient les deux pièces ; si l'affichage est sur la mauvaise face, ajouter à la pièce (ou au Model) l'attribut texte **`FaceEcran`** = `Front`, `Back`, `Top`, `Bottom`, `Left`, `Right` ou **`Auto`** (V6.9.10.3 : la grande face tournée vers les joueurs ; `Aucune` : pas d'affichage, pour un cadre) ; l'Output dit au démarrage quelle face et quel sens chaque écran utilise ; texte tourné : attribut **`RotationEcran`** = `90`, `180`, `270` ou `Auto` (V6.9.10.4) ;
  - **alerte** : `Console › Datapanel › Redbutton › Button` ;
  - **vol libre** : `Console › Selecteur › Colors` (clic ou touche F) ; **V6.9.10.5** : `Colors` peut être un Model (clic sur toutes ses pièces) ; l'invite « Vol libre » flotte 1,5 stud au-dessus du bouton (`Config.BoutonVolLibre.HauteurInvite`), celle du Selecteur (E) reste sur le Selecteur ; **V6.9.10.8** : un nom avec des espaces en trop (comme le Model « Selecteur␣ » de DEVMAP) est accepté ;
  - **écran ingénieur** : `Console › Ecran-Ingenieure` (avec le tiret ; même attribut `FaceEcran`, `Auto` par défaut depuis la V6.9.10.3 ; si c'est un Model, l'affichage va sur la pièce qui a l'attribut, sinon la plus grande pièce nommée comme un écran ou une vitre) ;
  - **casier** : `Console › Casier` (pièce ou Model) ; **jukebox** : `Console › JukeBox` (J et B majuscules) ; **V6.9.10.8** : les invites de la console (Selecteur, levier, alerte, casier, jukebox…) sont revenues sur leur commande ; pour les relever, un nombre de studs dans `Config.InvitesConsole.HauteurInvite` (aujourd'hui `false`) ; la caméra du casier ne va plus dans le mur (si tout est bouché autour du joueur, elle ne bouge pas) ;
  - **écran ingénieur (V6.9.10.5)** : l'affichage remplit maintenant toute la face Top (fini la bande étroite au milieu) ; s'il est encore à l'envers ou tourné, l'attribut **`RotationEcran`** (`0`, `90`, `180`, `270` ou `Auto`) sur la pièce ou le Model `Ecran-Ingenieure` reste là pour le remettre droit ; l'Output dit au démarrage la face, le sens et la taille de l'image ;
  - **touches** : E pour les commandes de la console, F pour Vol libre, Z pour le jukebox, l'écran ingénieur et le casier de la console (chacun a aussi un clic) ;
- **V6.9.10.2, l'intérieur** : les pièces peuvent être directement dans le dossier `INTERIEURE` (`Portail` et `Rotor` doivent y être en enfants directs) ; les SpawnLocations **`Spawn C.A.T`** et **`Spawn C.T.A.T`** y sont réutilisés (le nom doit finir par le nom de l'équipe ; pas besoin de régler leur couleur, le script s'en charge) ;
- **V6.9.10.6, les menus** : facultatif, pour de vrais coins coupés et les lignes de balayage : importer les 3 images de `assets/interface/` (Gestionnaire de ressources › Importer), puis coller leurs identifiants dans `Config.Interface.Images` (mode d'emploi : `assets/interface/LISEZMOI.md`) ;
- supprimer les scripts du kit désactivés (`Default Mainscript`, `README:`, les `Move` / `MainPhase` des portes).

## 3. Équipes
- **C.A.T.** : à créer dans Teams (pilotes, régénération) si ce n'est pas déjà fait.
- **C.T.A.T.** : créée automatiquement par le script si elle n'existe pas ; si tu la crées toi-même, une **couleur différente** de celle de la C.A.T.

## 4. Sons
- Voir la liste de sons proposés (02/11) : les identifiants choisis vont dans `Config.Sons`, `Config.Jukebox` et `Config.AmbianceThemes`, ou dans `ReplicatedStorage › TardisAssets › Sons`.
- **V6.9.10.5, le jukebox** (`Console › JukeBox` et la tablette) : sa liste est vide tant que tu n'y mets rien. Le plus simple : dans la **Toolbox de Studio**, onglet **Audio**, catégorie **Music**, chercher des musiques libres « dans l'esprit » Doctor Who (la vraie musique de la série appartient à la BBC : ses copies sur Roblox sont supprimées). Mots à chercher : *sci-fi orchestral*, *time travel*, *space mystery*, *adventure orchestral*, *electronic suspense*, *synth arpeggio*. Écoute-les, puis **glisse les Sound** dans **`ReplicatedStorage › TardisAssets › Jukebox`** (le dossier est créé au premier lancement ; tu peux aussi le créer toi-même). Le nom du Sound = le nom de la piste ; pour la ranger dans une playlist, ajoute-lui un attribut texte **`Categorie`** (« Thèmes », « Ambiance de bord », « Vortex », « Action », « Émotion »), ou range-le dans un sous-dossier qui porte ce nom. Volume et vitesse du Sound sont gardés. (Les pistes de `Config.Jukebox` restent possibles.)
- **V6.9.10.5, les tenues** (`Config.Tenues`) : les nombres `shirt` / `pant` sont les identifiants des vêtements du **catalogue** (le nombre dans l'adresse de la page de l'objet). Le serveur retrouve tout seul leur image au démarrage. Si l'Output affiche `[TARDIS] Tenues : vêtements introuvables…`, les tenues listées ont un identifiant qui ne mène à aucun vêtement (objet supprimé, privé, ou mauvais nombre) : corrige-le ; en attendant, le joueur qui les choisit garde ses vêtements.
- **V6.9.10** : un son **« Vortex »** (vent cosmique, en boucle) : son identifiant dans `Config.Sons.Vortex` (aujourd'hui 0), ou un Sound « Vortex » dans `TardisAssets › Sons`. Sans lui, pas de vent du vortex à bord (le diagnostic le signale). **En option**, un son **« Frein »** (crissement temporel du freinage d'urgence en vol libre) : `Config.Sons.Frein` ou un Sound « Frein ». Rien à construire pour l'orbite : le bouton **BoutonCamera** de la console suffit.

## 5. Branchements au jeu (quand tu pourras)
- Adonis (`G_API`) et niveaux dans `Config.Acces.Adonis` ; module WL (`Config.Acces.WL`) ; journal RoSysLog (`Config.Journal.Cible`).

## 6. Tests en jeu et releases (V6.9.10.8)
- Après tes tests, donne-moi les résultats : je les note dans [ETAT_DES_TESTS.md](ETAT_DES_TESTS.md) (167 tests de la V6.7 à la V6.9.10.8, dont 18 sans objet ; 149 encore à faire).
- **Releases GitHub à jour** : les 33 versions de la V6.5 à la V6.9.10.8 ont leur tag et leur release (les 24 en retard, V6.7 → V6.9.10.7, publiées le 06/11/2026). Chaque nouvelle version est publiée avec sa release ; la liste est dans `docs/releases/publiees.txt`.

## 7. Plus tard (tu m'expliqueras)
- Ce qui remplacera la **clé du TARDIS**.
