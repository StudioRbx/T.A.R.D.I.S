# Plan de la V7 « Modifications »

357 propositions gardées sur 1200 (second tri, 05/11/2026), en 10 sous-versions et 52 sous-sous-versions de 10 propositions au plus.
Ensuite : V8 sécurisation des scripts, V9 optimisation et nettoyage, V10 organisation des fichiers, V11 les 3 TARDIS, V12 la console.

## V7.1 — Corrections et banc d'essai (2 lots, 14 propositions)

Corriger d'abord les défauts du code actuel et renforcer les simulations, pour que toute la suite de la V7 soit vérifiée pour de vrai.

### V7.1.1 — Corrections et oublis du code actuel

**Objectif :** Corriger les défauts trouvés en lisant le code : préférences jamais envoyées, outils gardés après la perte du rôle, fausses intrusions, auto-destruction impossible à annuler, effets mal réglés.

- ✅ **T-1. Préférences envoyées au bon RemoteEvent** *(petit — fait en avance dans la V6.9.9)* : UI.sauverPrefs (TardisUI) cherche « TardisCommande », qui n'existe plus depuis les canaux par TARDIS (« TardisCommande_TARDIS_1 ») : les préférences ne partent jamais au serveur. Il faut viser le bon canal (ou un canal commun) et ajouter un test qui le vérifie.
- ✅ **T-201. Code d'erreur quand une simulation échoue** *(petit)* : lancer.sh n'affiche que la dernière ligne de chaque simulation (tail -1) et se termine toujours sans erreur. Il devrait rendre un code d'échec dès qu'un test rate, pour qu'un oubli ne passe pas inaperçu et que GitHub puisse le voir.
- ✅ **C-242. Outils retirés à la perte du rôle de technicien** *(petit)* : La boucle de TardisSystemes ne retire les outils qu'aux techniciens sortis : un joueur qui quitte la C.T.A.T. ou perd son accès garde la visseuse et l'extincteur, qui marchent encore. Ses outils seraient retirés dès que le rôle disparaît.
- ✅ **C-215. L'équipage ne déclenche plus d'intrusion** *(petit)* : Aujourd'hui tout joueur qui n'est pas pilote déclenche « INTRUSION » (boucle du registre dans TardisExtras), y compris les techniciens et le copilote. Les membres C.A.T. et C.T.A.T., le copilote et les invités acceptés ne sonneraient plus l'alerte ni la sentinelle.
- ✅ **C-155. Auto-destruction annulable pendant le compte à rebours** *(petit)* : Le glossaire la dit annulable, mais lancerAutoDestruction n'a aucune annulation. Un bouton pour le pilote qui l'a lancée (en partie là).
- ✅ **C-158. Reconstitution hors des zones interdites** *(petit)* : renaitre tire un lieu au hasard dans toutes les destinations. Exclure les zones REFUSE et les points ZDC.
- ✅ **G-44. Saut temporel visible même sans flash** *(petit)* : Avec « aucun flash » ou « effets réduits », le saut (touche B) n'a aucun effet (flashTemporel). La cabine s'étire vers l'avant et laisse une distorsion à la place de l'éclair.
- ✅ **G-232. Kaléidoscope du Tourbillon plus doux** *(petit)* : Le kaléidoscope plein écran du style Tourbillon ne tient pas compte des « effets réduits ». En mode réduit, il serait plus transparent et tournerait moins vite.
- ✅ **G-237. Caméra cinématique qui évite les murs** *(petit)* : L'orbite fait 9,5 studs : à bord ou dans un couloir, la caméra passe à travers les murs. Un raycast raccourcirait la distance.
- ✅ **G-79. Effets de voyage à l'échelle de la cabine rapetissée** *(petit)* : Les tailles des particules (tourbillon, étincelles, givre) et la portée de la lampe ne suivent pas l'attribut Echelle : une cabine à 25 % a des effets géants. Les multiplier par l'échelle les rend justes.

**Dans Studio :** Rien.

*Pourquoi ici :* Ce sont des défauts actifs : ils passent avant toute nouveauté. Le plus urgent est T-1 : UI.sauverPrefs (TardisUI) cherche encore « TardisCommande », qui n'existe plus depuis les canaux par TARDIS, donc aucune préférence ne part au serveur ; toutes les nouvelles préférences de la V7 (V7.4.1) en dépendent. T-201 fait échouer lancer.sh dès qu'une simulation rate, pour que la suite de la V7 soit vérifiée pour de vrai. C-242 (boucle des outils, TardisSystemes) et C-215 (registre de TardisExtras) sont des corrections serveur courtes. C-155 met le code d'accord avec le glossaire (annulation dans lancerAutoDestruction) et sert de règle avant les effets de la V7.3.3. C-158 retire les zones REFUSE et ZDC du tirage de renaitre. G-44, G-232 et G-237 complètent l'option « aucun flash » et les « effets réduits » (TardisVolLibre, Regeneration). G-79 multiplie les tailles des effets par l'attribut Echelle : il passe avant la V7.8.6, qui ajoute la cabine géante. Ordre conseillé : T-1, T-201, C-242, C-215, C-155, C-158, puis les quatre retouches client.

### V7.1.2 — Banc d'essai des simulations

**Objectif :** Rendre les simulations plus solides avant les lots qui touchent au serveur : tests rangés par sujet, démarrage complet du serveur, pièces manquantes et pièces en retard.

- ✅ **T-202. Simulations rangées par sujet et non par version** *(moyen)* : sim_v697, sim_v698 et sim_v699 mélangent des sujets différents. Les regrouper en sim_voyage, sim_effets, sim_outils… rend chaque test facile à retrouver et à garder à jour pendant la V9.
- ✅ **T-204. Simulation du démarrage complet du serveur** *(gros)* : Charger ensemble les 6 Scripts serveur dans le faux monde et vérifier qu'ils affichent « serveur prêt », « extras prêts », « systèmes prêts » sans erreur ni attente sans fin.
- ✅ **T-205. Simulation d'une place où il manque des pièces** *(moyen)* : Retirer tour à tour chaque pièce optionnelle (Arrivee, Casier, Vanne, Murs…) du faux monde et vérifier qu'aucun script ne plante : seul le diagnostic doit la signaler.
- ✅ **T-206. Simulation des pièces qui arrivent en retard** *(moyen)* : Avec StreamingEnabled, les pièces du TARDIS arrivent parfois après les LocalScripts. Les faire apparaître en retard dans le faux monde vérifie que les scripts clients attendent au lieu de planter.

**Dans Studio :** Rien : les outils tournent hors de Roblox (outils/simulation).

*Pourquoi ici :* Ce lot n'apporte rien de visible en jeu, mais il est placé tôt exprès : dans les sous-versions suivantes, beaucoup de lots changent decoller, atterrir, VolLibre et TardisSystemes. T-204 (gros) charge les 6 Scripts serveur ensemble et vérifie « serveur prêt », « extras prêts », « systèmes prêts » : il protège contre les attentes sans fin. T-205 et T-206 vérifient que les nouvelles pièces optionnelles de la V7 (Gyrophare, Cable, Volant, modèles d'outils…) peuvent manquer ou arriver en retard sans casser les scripts. T-202 range sim_v697, sim_v698, sim_v699 par sujet, pour y ajouter facilement les tests de chaque lot. T-201 (code d'erreur) est déjà fait en V7.1.1. Ordre : T-202, T-204, T-205, T-206.

## V7.2 — Cabine et monde extérieur (4 lots, 29 propositions)

Faire vivre la cabine et ce qui l'entoure : lampe et vitres, traces au sol, eau, saisons et météo. Presque tout est côté client, sans risque.

### V7.2.1 — Cabine : lampe et vitres vivantes

**Objectif :** Faire raconter l'état du TARDIS par sa cabine : vitres allumées la nuit, sombres sans courant, teintées par l'état de la salle, lampe qui arrive la première, contour pendant la remat.

- ✅ **G-1. Fenêtres allumées la nuit quand il est posé** *(petit)* : Posé, avec du courant et la nuit (Lighting.ClockTime), les vitres gardent une lueur chaude et fixe, comme si la salle était éclairée. Le TARDIS se repère de loin sans flash ni clignotement (TardisEffets, même liste de vitres que la V6.9.9).
- ✅ **G-3. Cabine éteinte quand le courant est coupé** *(petit)* : Hors tension (attribut Alimentation à false), les vitres deviennent sombres et l'enseigne s'éteint, en plus de la lampe déjà coupée. De dehors, on voit tout de suite que le TARDIS est en panne de courant.
- ✅ **G-6. Vitres qui prennent la couleur de la salle** *(petit)* : Les vitres reprennent la couleur de l'état de la salle (Config.CouleursSalle : bleu, ambre, cyan, rouge) avec un faible mélange. En partie là : les reflets des vitres (Decor) suivent déjà le thème, mais pas l'état.
- ✅ **G-9. La lampe s'allume la première à l'arrivée** *(petit)* : En remat, la lampe apparaît quelques dixièmes de seconde avant le reste de la cabine, seule dans le vide. C'est l'inverse des vitres qui s'éteignent en dernier : même calcul avec Config.Alpha et un décalage.
- ✅ **G-10. Frémissement pendant le silence du départ** *(petit)* : Pendant le Decalage du son (3,25 s en Classique), la cabine vibre très légèrement et la lampe s'allume faiblement, avant les vrais souffles. Les témoins comprennent qu'un départ se prépare.
- ✅ **G-13. Contour lumineux qui respire pendant la remat** *(petit)* : Un Highlight sur la cabine, seulement le contour, bat au rythme des souffles pendant la remat puis disparaît une fois posée. La forme de la cabine se lit mieux quand elle est encore presque transparente.
- ✅ **G-14. Ombres des croisillons des fenêtres au sol** *(petit)* : Activer les ombres de la lueur de la cabine (TardisLueur, Shadows) seulement de près et seulement la nuit : les croisillons des fenêtres se dessinent au sol à chaque souffle. Coupé en « effets réduits » pour garder les performances.
- ✅ **G-99. Reflet du soleil sur les vitres le jour** *(petit)* : Le jour, quand la caméra est dans l'axe du soleil (Lighting:GetSunDirection), un éclat bref brille sur une vitre. Il n'apparaît pas en « aucun flash ».
- ✅ **G-66. Signal de maintenance visible dehors** *(petit)* : En mode maintenance, la lampe reste fixe et ambrée et un petit panneau « HORS SERVICE » apparaît sur la porte. Aujourd'hui seul le bandeau à l'écran signale la maintenance.

**Dans Studio :** Rien de nouveau. Vérifier sur TARDIS_1 le dossier « Fenetres » (ou les Parts « Vitre ») fait en V6.9.9 et la présence de l'enseigne. La lumière TardisLueur doit exister dans la lampe (G-14).

*Pourquoi ici :* Tout se passe dans TardisEffets, sur la liste des vitres et sur la lampe déjà utilisées par la V6.9.9 (41, vitres qui s'éteignent en dernier ; 53, couleurs de salle). G-9 reprend le même calcul que la 41, à l'envers. G-6 lit Config.CouleursSalle. G-3 et G-66 lisent les attributs Alimentation et Maintenance, qui existent déjà : aucune nouvelle règle n'est nécessaire. Tout est côté client, sans nouvelle action réseau. C'est un lot sûr et très visible, placé juste après les corrections. Ordre conseillé : G-3, G-1, G-6, G-66 (états posés), puis G-10, G-9, G-13 (voyage), puis G-14 et G-99 (lumière, coupés en « effets réduits » ou « aucun flash »).

### V7.2.2 — Traces au sol à l'arrivée

**Objectif :** Faire réagir le sol à chaque arrivée et départ : marque selon le mode, givre après une Urgence, terrain qui réagit aussi au départ, cercle gallifreyen, poussière du plafond, brume de nuit.

- ✅ **G-19. Marque au sol différente selon le mode** *(petit)* : La trace carrée de la V6.9.9 change selon le mode : brûlée et fumante en Urgence, givrée en bleu après une Urgence froide, nette et verte en Rapide. En partie là : aujourd'hui la marque est la même dans tous les modes.
- ✅ **G-20. Givre au sol après un atterrissage d'urgence** *(petit)* : En plus du givre sur la cabine (EffetsExterieurs), un disque de givre blanc-bleu se forme au sol tout autour et fond en 25 secondes. Rien sur l'eau.
- ✅ **G-21. Terrain réactif aussi au départ** *(petit)* : Le module Decor ne joue l'effet du sol (sable, neige, métal, herbe) qu'à l'atterrissage, avec TerrainAtterrissage. La même gerbe, plus petite, part au moment où la cabine s'efface. En partie là.
- ✅ **G-23. Herbe du terrain qui s'agite au décollage** *(petit)* : Pour les joueurs proches seulement, workspace.GlobalWind est poussé un court instant pendant les souffles : l'herbe du Terrain et les particules sensibles au vent s'agitent autour de la cabine, puis le vent revient à sa valeur.
- ✅ **G-29. Brume basse qui reste après l'arrivée de nuit** *(petit)* : La nuit, une nappe de brume très basse reste quelques secondes autour de la base après l'atterrissage, puis se dissipe. La cabine semble sortir du brouillard.
- ✅ **G-12. Cercle gallifreyen au sol pendant la remat** *(moyen)* : Sous l'ombre annonciatrice (EffetsExterieurs), un cercle d'écriture gallifreyenne (Decal ou SurfaceGui) tourne lentement et s'efface quand la cabine est pleine. Un vrai repère Doctor Who pour les témoins.
- ✅ **G-22. Poussière qui tombe du plafond à l'arrivée** *(moyen)* : Si la cabine se pose sous un toit (raycast vers le haut à moins de 20 studs), de la poussière et de petits débris tombent du plafond au choc d'arrivée. Le lieu réagit à l'atterrissage.
- ✅ **C-178. Saleté selon le terrain d'atterrissage** *(petit)* : TerrainAtterrissage est déjà connu : le sable et la boue salissent plus, la neige et l'herbe moins.

**Dans Studio :** Fournir une image (Decal) de cercle d'écriture gallifreyenne pour G-12, ou accepter un cercle dessiné par le code.

*Pourquoi ici :* Ce lot prolonge la marque au sol de la V6.9.9 (38) dans Signalisation et l'effet de terrain du module Decor (TerrainAtterrissage). G-19 change cette même marque selon le mode, sans créer de second effet. G-21 et C-178 réutilisent TerrainAtterrissage : C-178 est la seule règle serveur (saleté selon le sol, TardisSystemes), simple et sans risque. G-12 et G-22 (moyens) passent en dernier ; G-22 fait un raycast vers le haut à l'arrivée. Tout le reste est côté client. Ordre : C-178, G-19, G-20, G-21, G-23, G-29, G-12, G-22.

### V7.2.3 — Sur l'eau et au ras de l'eau

**Objectif :** Rendre l'eau crédible : remontée en surface, vol ralenti sous l'eau, cabine lavée, rides, grandes gerbes, vapeur et sillage.

- ✅ **C-62. Remat dans l'eau profonde : remontée en surface** *(petit)* : Une destination sous l'eau pose la cabine au fond. Elle remonterait à la surface et flotterait (SurEau, BaseEau), comme quand elle est posée sur l'eau.
- ✅ **C-77. Vol libre ralenti sous l'eau** *(petit)* : Dans l'eau, la vitesse du vol libre serait divisée par deux et le Turbo coupé, comme dans un milieu épais.
- ✅ **C-179. Eau et pluie qui nettoient la cabine** *(petit)* : Posé sur l'eau (SurEau) ou sous la pluie, la saleté baisse toute seule.
- ✅ **G-25. Rides de l'eau autour de la cabine qui flotte** *(petit)* : Quand la cabine flotte (SurEau, BaseEau), des cercles d'eau partent régulièrement de sa base au rythme du tangage. Aujourd'hui elle tangue mais l'eau autour ne bouge pas.
- ✅ **G-26. Grandes gerbes d'eau à l'arrivée et à l'impact** *(petit)* : Un atterrissage ou une chute du vol libre sur l'eau fait jaillir une grande gerbe et un anneau d'écume, au lieu de la bouffée de poussière. En partie là : le tourbillon a déjà une version eau.
- ✅ **G-27. Vapeur qui monte de l'eau pendant la remat** *(petit)* : Pendant une matérialisation sur l'eau, une vapeur blanche monte de la surface à chaque souffle, comme si l'eau chauffait. Elle se dissipe en quelques secondes après l'arrivée.
- ✅ **G-35. Sillage sur l'eau en vol au ras de l'eau** *(moyen)* : Quand la cabine vole juste au-dessus de l'eau, des gerbes et une traînée d'écume la suivent à la surface, selon sa vitesse (vol.vitesseVecteur dans TardisVolLibre).

**Dans Studio :** Rien. Tester sur une zone de Terrain avec de l'eau profonde.

*Pourquoi ici :* Les règles d'abord : C-62 (remat sous l'eau qui remonte, dans atterrir, avec SurEau et BaseEau), C-77 (vol ralenti dans l'eau, VolLibre) et C-179 (saleté qui baisse sur l'eau, TardisSystemes). Puis les effets côté client : G-25 et G-27 (EffetsExterieurs), G-26 (tourbillon qui a déjà une version eau), G-35 (sillage, vol.vitesseVecteur dans TardisVolLibre). C-62 doit passer avant les effets, car une cabine posée au fond ne doit pas créer de rides en surface.

### V7.2.4 — Saisons et météo

**Objectif :** Ajouter des décorations de saison automatiques, dehors et dans la salle, et faire réagir la cabine au temps : éclair attiré pendant l'orage, neige ou feuilles qui glissent du toit au départ.

- ✅ **C-186. Décorations saisonnières automatiques selon la date** *(petit)* : Noël en décembre, Halloween en octobre, sans que les pilotes y pensent (option).
- ✅ **G-100. Nouvelles décorations saisonnières de la cabine** *(moyen)* : Le module Decor ne connaît que Noël et Halloween. On peut ajouter Pâques (oeufs au toit), le Nouvel An (petites fusées locales au toit) et l'anniversaire du serveur (guirlande), avec le même attribut Decoration.
- ✅ **G-190. Décorations de saison dans la salle** *(moyen)* : Noël et Halloween (module Decor, aujourd'hui seulement sur la cabine) décorent aussi la salle : guirlandes autour de la console, citrouilles et lueur orange.
- ✅ **G-32. Neige ou feuilles qui glissent du toit au départ** *(moyen)* : Posé longtemps en zone de neige (matériau Snow) ou sous les arbres, une fine couche blanche ou quelques feuilles se forment sur le toit. Au début de la démat, elles glissent et tombent.
- ✅ **G-31. Éclair attiré par la cabine pendant l'orage** *(moyen)* : Pendant un orage signalé par le jeu, un éclair frappe parfois la lampe d'un TARDIS posé, avec étincelles et lampe qui grésille. Aucun dégât, c'est de l'ambiance. Coupé en « aucun flash ».

**Dans Studio :** Décider comment le jeu ZONE-TSADE signale un orage (un attribut sur Lighting ou ReplicatedStorage), sinon G-31 reste inactif. Facultatif : modèles de décorations (oeufs, guirlandes, citrouilles) dans TardisAssets.

*Pourquoi ici :* Tout passe par le module Decor et l'attribut Decoration, déjà utilisés pour Noël et Halloween. C-186 (règle : la date choisit la saison) passe en premier, pour que les nouvelles saisons de G-100 et la salle de G-190 en profitent tout de suite. G-32 et G-31 (moyens) suivent. G-31 n'a pas de signal d'orage dans le code actuel : il faut d'abord la décision Studio ci-contre.

## V7.3 — Salle de contrôle et console (5 lots, 31 propositions)

Rendre la salle plus vivante et plus lisible : surchauffe et vapeur, ambiance, alerte et auto-destruction, commandes qui bougent, vue par la porte.

### V7.3.1 — Surchauffe, vapeur et écrans Diagnostic

**Objectif :** Rendre la surchauffe juste et visible : le compteur redescend au repos, un avertissement arrive avant la coupure, et la salle le montre par la vapeur, les grilles et les écrans Diagnostic.

- ✅ **C-98. Compteur de voyages consécutifs qui redescend au repos** *(petit)* : Le compteur de VoyagesAvantCoupure ne revient à zéro qu'au redémarrage. Chaque minute posé enlèverait un voyage.
- ✅ **C-117. Surchauffe annoncée avant la coupure** *(petit)* : À deux voyages de VoyagesAvantCoupure, un avertissement et plus de vapeur : les pilotes peuvent laisser refroidir au lieu de subir la coupure.
- ✅ **C-184. Rotor tapoté trop souvent qui surchauffe** *(petit)* : Le rotor interactif accepte un clic toutes les 0,5 s. Trop de clics en peu de temps compteraient comme un voyage dans le compteur de coupure : on ne joue pas avec la console.
- ✅ **G-63. Surchauffe visible après plusieurs voyages d'affilée** *(petit)* : Avec l'attribut VoyagesConsecutifs élevé, la cabine posée dégage un peu de chaleur (air qui ondule légèrement et vapeur au toit) qui retombe avec le repos.
- ✅ **G-143. Grande bouffée de vapeur à l'atterrissage** *(petit)* : Quand la cabine se pose, toutes les grilles crachent ensemble une bouffée de vapeur, comme une décompression.
- ✅ **G-144. Vapeur qui fait le tour au décollage** *(petit)* : Au début de la démat, les grilles soufflent l'une après l'autre en faisant le tour de la salle.
- ✅ **G-145. Grille en surcharge qui rougeoie** *(petit)* : La grille en VapeurSurcharge devient orange lumineux et l'air tremble au-dessus d'elle : le technicien la trouve plus vite.
- ✅ **G-147. Lueur orangée sous les grilles en vol** *(petit)* : Pendant les voyages, une lumière orangée monte de sous les grilles, comme si le moteur chauffait dessous ; elle s'éteint une fois posé.
- ✅ **G-199. Voyants colorés sur les écrans Diagnostic** *(petit)* : Sur les écrans Diagnostic, les lignes « ● » s'affichent en vert et les « ○ » en rouge ou ambre, au lieu de tout en blanc (Ambiance, section 3 ter).
- ✅ **G-200. Courbe du moteur sur l'écran ÉNERGIE** *(petit)* : Une petite courbe animée en bas de l'écran Diagnostic ÉNERGIE, plus agitée en vol, saccadée en Urgence et plate hors tension.

**Dans Studio :** Rien. Les grilles et les quatre écrans Diagnostic existent déjà.

*Pourquoi ici :* Les règles d'abord : C-98 fait redescendre VoyagesConsecutifs au repos, C-117 prévient à deux voyages de VoyagesAvantCoupure, C-184 compte les clics abusifs sur le rotor. Les trois sont dans TardisSystemes et ne touchent qu'au compteur de coupure : petit risque. Ensuite les effets, côté client dans Ambiance (grilles, vapeur, écrans Diagnostic) et TardisEffets (G-63 sur la cabine). G-145 met en valeur la grille VapeurSurcharge qui existe déjà. G-199 et G-200 changent seulement l'affichage des écrans Diagnostic.

### V7.3.2 — Salle : ambiance, jukebox et style

**Objectif :** Rendre la salle plus vivante au quotidien : lumières qui suivent la musique, jukebox ouvert au copilote et aux techniciens, câbles qui se balancent, nouveau style qui se répand en vague.

- ✅ **C-189. Jukebox ouvert au copilote et aux techniciens** *(petit)* : Le jukebox est réservé aux pilotes. Le copilote et les techniciens à bord pourraient aussi le régler.
- ✅ **G-140. Lumières qui suivent la musique du jukebox** *(petit)* : À bord et hors alerte, les LedsAlerte suivent doucement le volume de la musique (PlaybackLoudness, calculé chez chaque joueur).
- ✅ **G-163. Câbles du plafond qui se balancent aux secousses** *(moyen)* : Des câbles suspendus au plafond (pièces « Cable » de l'intérieur, ou des cordes locales) oscillent pendant la démat, la remat et les chocs, plus fort en Urgence. Ils restent immobiles avec le stabilisateur, comme les secousses de caméra de TardisEffets.
- ✅ **G-189. Changement de style en vague** *(moyen)* : Un nouveau style d'intérieur ou de console (appliquerPieces, appliquerStyleConsole) se répand depuis la console vers les murs en 2 s, au lieu de changer d'un coup.

**Dans Studio :** Facultatif : des Parts « Cable » suspendues au plafond de l'intérieur de TARDIS_1 (G-163). Sans elles, le code crée des cordes locales. À reproduire sur TARDIS_2 et TARDIS_3 en V11.

*Pourquoi ici :* C-189 (règle) passe en premier : il élargit les droits de l'action jukebox dans TardisExtras. G-140 lit PlaybackLoudness chez chaque joueur, dans la boucle d'Ambiance qui existe déjà, pour ne pas ajouter de boucle par image (voir la V9). G-163 réutilise les secousses et le stabilisateur. G-189 change appliquerPieces et appliquerStyleConsole (TardisServeur) pour un effet en vague : c'est le seul point délicat, gardé pour la fin.

### V7.3.3 — Alerte et auto-destruction

**Objectif :** Mettre en scène l'alerte et le compte à rebours de l'auto-destruction : gyrophares, écrans ALERTE, hologramme rouge, lumières qui s'éteignent une à une, rotor qui s'emballe, image délavée après l'explosion.

- ✅ **G-119. Hologramme rouge en alerte** *(petit)* : En alerte et pendant l'auto-destruction, les cercles et le faisceau de l'hologramme passent au rouge et pulsent, au lieu de rester cyan.
- ✅ **G-133. Gyrophares d'alerte qui tournent au plafond** *(moyen)* : En alerte, deux projecteurs rouges tournent au plafond et balaient la salle, en plus de la teinte rouge ; ils se placent sur des pièces « Gyrophare » si elles existent.
- ✅ **G-175. Écrans Diagnostic qui affichent ALERTE** *(petit)* : En alerte, les quatre écrans Diagnostic affichent en grand « ALERTE » en rouge une seconde sur trois, entre leurs lignes habituelles.
- ✅ **G-177. Lumières qui s'éteignent une à une** *(petit)* : Pendant le compte à rebours de l'auto-destruction, les lumières de la salle s'éteignent une par une jusqu'à ne laisser que le rouge.
- ✅ **G-178. Rotor qui s'emballe avant l'explosion** *(petit)* : Pendant le compte à rebours, le rotor monte et descend de plus en plus vite et vire au blanc-rouge.
- ✅ **G-179. Étincelles qui gagnent toute la console** *(petit)* : Pendant l'auto-destruction, chaque seconde une nouvelle pièce de la console crache des étincelles ; à la fin, toute la console brille.
- ✅ **G-271. Image délavée après l'explosion** *(petit)* : Après l'auto-destruction, les joueurs proches voient une image grise qui reprend ses couleurs en quelques secondes, en plus du flash.

**Dans Studio :** Facultatif : des Parts « Gyrophare » au plafond de l'intérieur (G-133). Sans elles, le code place deux projecteurs au-dessus de la console.

*Pourquoi ici :* La règle utile a été posée en V7.1.1 : l'auto-destruction est annulable (C-155). Les effets doivent donc savoir revenir en arrière si on annule : c'est pour cela qu'ils viennent après. Tout est côté client : Ambiance (hologramme, écrans Diagnostic), TardisEffets (rotor), AutoDestruction.lua (lumières, étincelles, image délavée). Les gyrophares (G-133) sont lus sur des Parts optionnelles, testées par la simulation des pièces manquantes (V7.1.2). Ordre : alerte d'abord (G-119, G-133, G-175), puis le compte à rebours (G-177, G-178, G-179), puis G-271.

### V7.3.4 — Console : commandes qui bougent

**Objectif :** Faire bouger les vraies commandes de la console : levier de vol, levier du verrou, levier d'alimentation, interrupteur d'alerte, contour sur la commande visée, clignotement rouge au refus.

- ✅ **G-108. Contour lumineux sur la commande visée** *(petit)* : Quand l'invite E d'une commande s'affiche (PromptShown côté client), la pièce reçoit un léger contour cyan : on sait quel levier on va actionner parmi tous ceux de la console.
- ✅ **G-107. Commande qui clignote en rouge au refus** *(moyen)* : Quand le serveur refuse une commande de la console (PATIENTEZ, HORS TENSION, EN MAINTENANCE), la pièce touchée clignote deux fois en rouge, en plus du message à l'écran.
- ✅ **G-103. Levier du verrou qui suit les portes** *(petit)* : Le levier LeverLeft reste baissé tant que PortesVerrouillees est vrai et remonte sinon ; une petite lampe au bout passe du vert au rouge.
- ✅ **G-104. Levier d'alimentation animé avec étincelle** *(petit)* : Le LockLever bascule à chaque coupure ou retour du courant, avec une courte gerbe d'étincelles à la coupure (basculerAlimentation).
- ✅ **G-105. Interrupteur d'alerte qui s'allume en rouge** *(petit)* : Le Switch du Cloister bascule et devient un néon rouge tant que l'Alerte est active : on voit d'où vient l'alerte et comment la lever.
- ✅ **G-101. Levier de vol qui bascule vraiment** *(moyen)* : Le levier de vol (Config.Chemins.Levier) s'abaisse au décollage et remonte à l'atterrissage, selon l'attribut Etat. Aujourd'hui, seul le texte de l'invite change (promptLevier) ; ce sont les vraies commandes, pas les interrupteurs décoratifs déjà prévus.

**Dans Studio :** Vérifier les pièces Levier, LeverLeft, LockLever et le Switch du Cloister sur TARDIS_1. Ajouter une Part « Charniere » sur l'axe de chaque levier pour qu'il pivote juste (à reproduire sur TARDIS_2 et TARDIS_3 en V11).

*Pourquoi ici :* G-108 et G-107 passent en premier : ils ne bougent rien, ils montrent seulement la commande visée et le refus (PATIENTEZ, HORS TENSION, EN MAINTENANCE). G-107 a besoin que le serveur dise quelle pièce a été refusée : un petit ajout aux messages de refus. Puis les leviers suivent les attributs PortesVerrouillees, Alimentation, Alerte et Etat (G-103, G-104, G-105, G-101). G-101 (levier de vol) est le plus visible et le plus délicat : il passe en dernier. La V12 fera de la console l'interface principale : ces animations y serviront.

### V7.3.5 — Vue par la porte

**Objectif :** Rendre la vue par la porte plus fidèle : voile du bouclier, salle qui suit ses lumières, rue rafraîchie de temps en temps, et silhouettes des personnages.

- ✅ **G-159. Voile du bouclier dans la vue de la porte** *(petit)* : Quand un bouclier est levé, la vue de la rue depuis la salle (fenetreInt) prend un léger voile bleuté qui ondule, car la bulle n'est pas copiée dans la vue.
- ✅ **G-166. Vue de la salle qui suit ses lumières** *(petit)* : Depuis dehors, la salle vue par la porte (ViewportFrame) suit l'état : sombre hors tension, rouge en alerte, et la copie du rotor prend aussi sa couleur du mode.
- ✅ **G-169. Vue de la rue rafraîchie de temps en temps** *(petit)* : Posé longtemps, la copie des environs est refaite toutes les 2 minutes quand la porte est fermée, pour montrer les véhicules et objets qui ont bougé.
- ✅ **G-168. Silhouettes des personnages à travers la porte** *(gros)* : Aujourd'hui joueurs et PNJ sont exclus des copies (estExclu) : de simples silhouettes, mises à jour plusieurs fois par seconde, montreraient qui est dehors ou à bord.

**Dans Studio :** Rien.

*Pourquoi ici :* Tout est dans TardisPortail.client (fenetreInt, ViewportFrame, estExclu). G-159, G-166 et G-169 sont petits et sûrs. G-168 (gros) met à jour des silhouettes plusieurs fois par seconde : c'est un coût réseau et image à mesurer, d'où sa place isolée à la fin de la sous-version ; la V9 (optimisation) pourra l'alléger. G-159 montre le bouclier tel qu'il est aujourd'hui ; les règles de bouclier de la V7.7.6 ne changent pas son apparence dans la vue.

## V7.4 — Caméras et confort de l'écran (2 lots, 15 propositions)

Donner des réglages contre la fatigue et la nausée, puis faire de la caméra de la Lampe un vrai outil RP.

### V7.4.1 — Confort de l'écran : secousses et nausée

**Objectif :** Donner des réglages contre la fatigue des yeux et la nausée, et des signaux d'écran simples pour l'équipage : secousses lissées, force réglable, champ de vision fixe, vignette rouge quand le TARDIS souffre.

- ✅ **G-277. Secousses plus naturelles et moins saccadées** *(petit)* : Les secousses changent de direction au hasard à chaque image. Un bruit lissé (math.noise) qui décroît doucement fatiguerait moins les yeux.
- ✅ **G-279. Réglage de la force des secousses** *(petit)* : Un curseur de 0 à 100 %, en plus des « effets réduits », lu par toutes les fonctions secouer.
- ✅ **G-280. Champ de vision fixe contre la nausée** *(petit)* : Une option bloque les changements de champ de vision du vol libre, du saut temporel et de la régénération.
- ✅ **C-222. Lien Time Lord choisi par chaque membre** *(petit)* : Aujourd'hui un seul pilote allume ou éteint le lien pour toute la C.A.T. (attribut TardisLienTimeLord de ReplicatedStorage, action LienTimeLord). Chaque membre choisirait plutôt dans ses préférences s'il veut ressentir les régénérations des autres.
- ✅ **G-262. Salle qui s'agrandit à la première entrée** *(petit)* : Avec le message de Découverte, un travelling compensé (dolly zoom) d'une seconde : la salle semble s'agrandir devant le joueur.
- ✅ **G-268. Vignette rouge quand le TARDIS est très abîmé** *(petit)* : Quand les PV sont bas, les bords de l'écran battent lentement en rouge pour ceux à bord. L'équipage sent le danger sans lire de jauge.
- ✅ **G-275. Aveuglé par le projecteur de la lampe** *(petit)* : Quand le projecteur piloté par la caméra du pilote vise un joueur, son écran blanchit un peu.

**Dans Studio :** Rien.

*Pourquoi ici :* Ce lot vient après T-1 (V7.1.1), parce que G-279, G-280 et C-222 sont de nouvelles préférences : sans la correction, elles ne seraient jamais sauvegardées. Il vient aussi après la V6.9.15 (188 effets réduits sur mobile, 72 taille), qui a posé les autres préférences. G-277 et G-279 passent ensemble : toutes les fonctions secouer (TardisEffets, EffetsExterieurs, Decor, Regeneration, AutoDestruction) lisent un seul réglage et un bruit lissé. C-222 fait passer le lien Time Lord d'un attribut commun (TardisLienTimeLord) à un choix par joueur : la logique serveur de TardisSystemes change un peu. G-262, G-268 et G-275 sont de petits effets d'écran, coupés par les réglages qu'on vient d'ajouter. Ces réglages iront dans le panneau « Mes réglages » de la V11.7.

### V7.4.2 — Caméra extérieure de la lampe

**Objectif :** Faire de la caméra de la Lampe un vrai outil RP : vue du dessus, zoom, vision de nuit, cadre de surveillance, grésillement, suivi d'un joueur et plusieurs points de vue.

- ✅ **G-282. Grésillement à l'entrée de la caméra extérieure** *(petit)* : Au lieu d'une coupure nette, 0,3 seconde de parasites quand on entre ou sort de la caméra de la Lampe.
- ✅ **G-278. Vue du dessus dans la caméra extérieure** *(petit)* : Une touche passe la caméra de la Lampe (TardisCamera) en vue verticale, plus haute, comme une carte vivante des alentours ; la même touche revient à la vue normale.
- ✅ **G-285. Zoom optique dans la caméra extérieure** *(petit)* : La molette monte déjà la caméra ; une autre touche changerait le champ de vision pour zoomer sur un point.
- ✅ **G-284. Vision de nuit dans la caméra extérieure** *(petit)* : Une touche passe l'image en vert et la rend plus lumineuse, pour voir autour du TARDIS la nuit.
- ✅ **G-283. Cadre de caméra de surveillance** *(petit)* : Option : heure, « REC » et lignes de balayage sur l'image de la caméra de la Lampe.
- ✅ **G-289. Image qui grésille quand le TARDIS est abîmé** *(petit)* : Plus les PV sont bas, plus l'image de la caméra de la Lampe se brouille par moments.
- ✅ **G-287. Suivre un joueur avec la caméra extérieure** *(moyen)* : Un clic sur un joueur verrouille la caméra sur lui ; elle tourne autour de lui jusqu'à ce qu'on le relâche.
- ✅ **G-288. Plusieurs points de vue extérieurs** *(moyen)* : Une touche passe de la Lampe au-dessus de la porte, puis sous la cabine en vol.

**Dans Studio :** Rien. Les points de vue de G-288 se calculent depuis la porte et la base de la cabine.

*Pourquoi ici :* Tout est dans TardisCamera.client (majCamera, entrer, sortir), côté client. Aucun autre lot ne touche ce fichier, donc le risque est faible. G-282 (parasites à l'entrée) passe en premier, car il masque les changements de vue suivants. G-278, G-285 et G-284 sont des touches simples. G-289 lit PointsDeVie, qui existe. G-287 et G-288 (moyens) passent à la fin. Ces touches resteront après la V12, car la caméra ne dépend ni de T ni de Y.

## V7.5 — Régénération de la C.A.T. (6 lots, 38 propositions)

Mettre en scène la régénération (caméra, corps, poses, lieu), puis lui donner des règles et de nouveaux styles.

### V7.5.1 — Régénération : caméra de cinéma

**Objectif :** Donner à la caméra cinématique de la régénération une vraie mise en scène : flou de fond, bandes noires, plan final sur le visage, trajet propre à chaque style, et une touche pour la passer.

- ✅ **G-233. Profondeur de champ pendant la caméra cinématique** *(petit)* : Un DepthOfFieldEffect fait la mise au point sur la tête et floute le décor derrière. Le plan ressemble à une vraie scène de film.
- ✅ **G-234. Bandes noires de cinéma pendant la régénération** *(petit)* : Deux bandes noires en haut et en bas de l'écran pendant la caméra cinématique. On sent tout de suite le moment fort.
- ✅ **G-235. Plan final sur le nouveau visage** *(petit)* : À la fin, la caméra passe devant le visage pendant 2 secondes avant de rendre la main. Le joueur voit sa nouvelle apparence de face.
- ✅ **G-236. Trajet de caméra propre à chaque style** *(moyen)* : Colonne en contre-plongée vers le ciel, Volcan qui recule d'un coup à l'explosion, Douce en gros plan lent. Aujourd'hui tous les styles ont la même orbite.
- ✅ **G-264. Braises qui passent devant la caméra cinématique** *(petit)* : Pendant la caméra cinématique de la régénération, quelques braises et étincelles passent tout près de l'objectif, avec un léger flou. Le plan gagne en profondeur.
- ✅ **G-240. Vignette dorée côté régénération pour les témoins** *(petit)* : Au lieu de teinter toute l'image, l'or vient du bord de l'écran tourné vers la régénération. On sait d'où vient la lumière.
- ✅ **G-238. Passer la caméra cinématique d'une touche** *(petit)* : Une touche rend la caméra normale tout de suite, pour ceux qui veulent garder la main. L'effet visible par les autres continue.

**Dans Studio :** Rien.

*Pourquoi ici :* Tout se passe dans Regeneration.lua (Config.Regeneration.CameraCinematique), côté client, sans toucher au serveur ni au déroulé de la régénération. C'est un lot sûr et visible pour la C.A.T., placé en tête de la régénération. G-237 (caméra qui évite les murs) est déjà corrigée en V7.1.1 : l'orbite est donc fiable avant d'y ajouter des plans. G-238 passe en premier, car il donne une sortie à ceux qui n'aiment pas la caméra. G-236 (trajet par style) passe en dernier : il servira aussi aux nouveaux styles de la V7.5.6. Le trajet de chaque style restera à reprendre quand Regeneration.lua sera découpé en V10.

### V7.5.2 — Régénération : le corps change

**Objectif :** Montrer la transformation sur le corps : énergie qui descend le long des bras, lueur qui bat, peau qui change en douceur, anciens accessoires qui brûlent, nouveaux qui apparaissent, membre qui repousse en lumière.

- ✅ **G-206. Énergie qui descend le long des bras** *(petit)* : Avant que les mains crachent leurs jets, des filets dorés (Beams fins) coulent de l'épaule jusqu'à la main. Le jet semble venir du corps et pas de nulle part.
- ✅ **G-207. Lueur de la peau qui bat comme un cœur** *(petit)* : La lueur (Highlight) monte aujourd'hui de façon lisse ; la faire battre lentement, puis de plus en plus vite jusqu'à l'éruption, donne du rythme à la montée.
- ✅ **G-208. Couleur de peau qui change en douceur** *(moyen)* : Juste avant l'éclat, les couleurs du corps (BodyColors) glissent vers celles du nouvel avatar. Le changement ne se fait plus d'un seul coup sous la lumière.
- ✅ **G-209. Anciens accessoires qui brûlent et tombent** *(moyen)* : Au changement, les accessoires de l'ancien avatar se détachent, rougeoient puis tombent en cendres, avant que les nouveaux arrivent. On voit vraiment l'ancien visage partir.
- ✅ **G-210. Nouveaux accessoires qui apparaissent un à un** *(petit)* : Après l'application du nouvel avatar, chaque accessoire (cheveux, chapeau…) apparaît en fondu avec une petite étincelle, au lieu de surgir d'un coup.
- ✅ **G-213. Cheveux qui fument encore après** *(petit)* : En partie là : les mains fument déjà après la régénération. Ajouter quelques volutes sur l'accessoire de cheveux, qui s'arrêtent en même temps.
- ✅ **G-215. Membre qui repousse en lumière** *(petit)* : Dans surveillerMembres, le bras ou la jambe apparaît d'un coup. Il pourrait d'abord apparaître en lumière dorée (Neon), puis prendre sa vraie couleur en 1 seconde.

**Dans Studio :** Rien.

*Pourquoi ici :* La plupart des effets sont dans Regeneration.lua (client) : G-206, G-207 et G-213 sont de petits ajouts aux effets existants. G-208, G-209 et G-210 touchent le moment où le nouvel avatar est appliqué : il faut garder l'ordre actuel (ancien avatar, éclat, nouvel avatar) et seulement ajouter des fondus. G-215 est dans surveillerMembres (TardisSystemes) : petit changement serveur. Il passe avant les poses du corps (V7.5.3), qui touchent le serveur.

### V7.5.3 — Régénération : poses du corps

**Objectif :** Donner au corps une vraie gestuelle pendant la régénération : pose propre à chaque style, genou à terre, légère lévitation, mains qui tremblent, nouveau Voyageur qui regarde ses mains, pose assise.

- ✅ **G-205. Mains qui tremblent pendant le temps du choix** *(petit)* : Pendant TardisRegenChoix, les épaules et les mains vibrent un peu. Les témoins voient que l'énergie monte avant même que la régénération commence.
- ✅ **G-203. Genou à terre pendant la montée d'énergie** *(moyen)* : Pendant la montée (0 à 15 % de la courbe d'intensité), le corps fléchit, puis se redresse d'un coup quand les jets jaillissent. Le début se lit mieux qu'avec une pose immobile.
- ✅ **G-201. Pose de régénération propre à chaque style** *(moyen)* : Aujourd'hui poseRegeneration (TardisSystemes) donne la même pose à tous les styles. La Douce garderait les bras bas, paumes ouvertes ; le Volcan cambrerait fort ; la Fracture bougerait par à-coups.
- ✅ **G-218. Régénération assise dans un siège** *(petit)* : Quand le joueur est assis (humanoid.Sit), la pose debout se tord. Il faudrait une pose assise, bras levés, et des jets adaptés.
- ✅ **G-204. Légère lévitation pendant l'éruption** *(moyen)* : Pour les styles Douce et Colonne, le corps s'élève de 1 à 2 studs pendant l'éruption puis se repose au changement (AlignPosition côté serveur, vu par tous).
- ✅ **G-202. Le nouveau Voyageur regarde ses mains** *(moyen)* : À la fin de la régénération, une courte pose : il lève les mains devant son visage puis touche sa tête, comme dans la série. On comprend tout de suite qu'il découvre son nouveau corps.

**Dans Studio :** Facultatif : des Animations publiées par le propriétaire du jeu. Sinon les poses sont faites par le code, comme aujourd'hui.

*Pourquoi ici :* Tout se fait dans poseRegeneration (TardisSystemes), côté serveur, pour que tous les joueurs voient la même chose. C'est plus risqué que les effets client (V7.5.1, V7.5.2) : d'où sa place après eux. G-204 ajoute un AlignPosition : il faut le retirer à coup sûr à la fin, même si le joueur quitte. Ordre : G-205 (temps du choix), G-203 (montée), G-201 (pose par style), G-218 (assis), G-204 (lévitation), G-202 (fin). Les poses par style seront à reprendre dans les modules par style après la V10.

### V7.5.4 — Régénération à bord et selon le lieu

**Objectif :** Faire réagir le TARDIS et le lieu à la régénération : plus courte à bord, énergie rendue au TARDIS, vitres et salle dorées, jets attirés par le rotor, régénération sous l'eau, sol brûlé selon le matériau.

- ✅ **C-238. Régénération plus courte à bord du TARDIS** *(petit)* : Une régénération à bord dure moins longtemps (par exemple 60 % de Config.Regeneration.Duree), car le TARDIS aide son Time Lord. Le TARDIS devient un refuge RP pour la C.A.T.
- ✅ **C-266. Régénération à bord qui recharge le TARDIS** *(petit)* : Option : l'énergie d'une régénération à bord recharge l'énergie du TARDIS (ou le carburant Artron prévu) au lieu d'enlever 400 points d'intégrité (Config.Regeneration.DegatsTardis).
- ✅ **G-65. Vitres dorées pendant une régénération à bord** *(petit)* : Quand un pilote se régénère à bord (attribut RegenerationABord), les vitres s'illuminent en or et pulsent jusqu'à la fin. Dehors, on devine qu'il se passe quelque chose.
- ✅ **G-141. Lueur dorée pendant une régénération à bord** *(petit)* : En plus des étincelles de la console (RegenerationABord), une lumière dorée envahit la salle quelques secondes, puis retombe.
- ✅ **G-220. Jets attirés par le rotor à bord** *(moyen)* : Lors d'une régénération à bord (RegenerationABord), une partie des jets se courbe vers le rotor, qui brille en or un instant. On voit que le TARDIS absorbe l'énergie.
- ✅ **G-217. Régénération sous l'eau avec des bulles** *(moyen)* : Si le joueur nage ou se trouve dans l'eau du Terrain, les flammes deviennent des bulles et de la vapeur, et il n'y a pas de sol brûlant.
- ✅ **G-223. Sol brûlé selon le matériau** *(moyen)* : Comme le terrain réactif (Decor) : herbe noircie, neige qui fond en flaque, métal qui rougeoie. Aujourd'hui solBrulant fait le même disque partout.

**Dans Studio :** Rien.

*Pourquoi ici :* Les règles d'abord, dans TardisSystemes (Config.Regeneration.Duree et DegatsTardis) : C-238 et C-266, deux options. Puis les effets qui lisent RegenerationABord : G-65 (vitres, TardisEffets), G-141 (salle, Ambiance), G-220 (jets vers le rotor, Regeneration.lua). Enfin les effets selon le lieu : G-217 (eau) et G-223 (sol, avec la même lecture du matériau que le module Decor). Ce lot suit les poses (V7.5.3) et touche les mêmes moments que la 115 prévue en V11.2 (TARDIS proche qui tremble) : voir les remarques.

### V7.5.5 — Régénération : règles et vraie mort

**Objectif :** Donner un prix aux régénérations : bonus de vie qui s'use, zones sans régénération, délai entre deux régénérations, pas de spawn à bord après une vraie mort, technicien à réanimer, styles débloqués.

- **C-241. Bonus de vie qui faiblit à chaque régénération** *(petit)* : Les PV en plus après une régénération (bonusPV, Config.Regeneration.BonusPV) baissent un peu à chaque régénération de la série, puis reviennent au maximum après une mort réelle. Les incarnations successives s'usent.
- **C-265. Recharge entre deux régénérations** *(petit)* : Après une régénération, un délai réglable pendant lequel une nouvelle mort est une vraie mort (option, désactivée par défaut). Mourir en boucle n'est plus sans conséquence.
- **C-270. Pas de spawn à bord après une mort réelle** *(petit)* : Après une mort réelle, le membre de la C.A.T. réapparaît au spawn normal du jeu pendant quelques minutes au lieu du TARDIS. La vraie mort a une conséquence visible.
- **C-264. Zones sans régénération possible** *(moyen)* : Un dossier de Parts (par exemple certaines chambres de confinement) où un membre de la C.A.T. qui meurt meurt vraiment. Certaines menaces de ZONE-TSADE deviennent vraiment dangereuses.
- **C-277. Technicien tombé à réanimer** *(moyen)* : Les techniciens ne se régénèrent pas : à 0 PV à bord, ils restent à terre 30 secondes ; un équipier qui maintient E les relève, sinon ils meurent. Cela donne un rôle de secours à l'équipage.
- **C-274. Styles de régénération débloqués avec l'expérience** *(moyen)* : En complément du choix du style prévu : les styles rares (Supernova, Fracture) se débloquent après un certain nombre de régénérations. Les anciens membres de la C.A.T. ont quelque chose en plus.

**Dans Studio :** Créer un dossier de Parts « SansRegeneration » (par exemple certaines chambres de confinement) dans Workspace, commun aux trois TARDIS (C-264).

*Pourquoi ici :* Ces règles touchent le déroulé de la mort et du spawn (TardisSystemes, TardisExtras) : un défaut ici fait perdre un personnage RP, d'où leur place à la fin de la régénération, juste avant les nouveaux styles. C-241, C-265 et C-270 sont des options de Config, coupées par défaut. C-264 lit le nouveau dossier. C-277 donne aux techniciens un état « à terre » de 30 s : il faut le retirer à coup sûr. C-274 passe en dernier : il dépend du choix du style (102), prévu en V11.1 ; en V7, il ne peut que débloquer les styles dans la liste actuelle (voir les remarques). Il faut décider avant le lot si la vraie mort existe vraiment (lien avec la 107 en V11.2).

### V7.5.6 — Régénération : nouveaux styles

**Objectif :** Ajouter quatre styles de régénération (Phénix, Givre, Implosion, Tempête) et une couleur d'énergie personnelle par membre de la C.A.T.

- **G-227. Couleur d'énergie personnelle par membre** *(moyen)* : Chaque membre de la C.A.T. a une teinte (or, blanc, bleu pâle) qui remplace l'or et l'orange de la palette, quel que soit le style joué.
- **G-230. Nouveau style : Implosion** *(moyen)* : La lumière est aspirée vers le corps, qui devient noir un instant, puis la nouvelle apparence se révèle sans éclat. Il va bien avec l'option « Aucun flash ».
- **G-229. Nouveau style : Givre** *(moyen)* : Une énergie bleu glacé, le sol se couvre de givre et une buée sort de la bouche. Il contraste avec les styles de feu actuels.
- **G-231. Nouveau style : Tempête** *(moyen)* : Un vent tourne autour du Voyageur, soulève poussière et feuilles, et des éclairs dorés passent dans le tourbillon.
- **G-228. Nouveau style : Phénix** *(moyen)* : Deux ailes de flammes (Beams courbés) sortent du dos, battent une fois, puis se défont en plumes de braise qui retombent.

**Dans Studio :** Facultatif : un son par nouveau style dans TardisAssets > Sons.

*Pourquoi ici :* Ce lot vient après les poses (V7.5.3), la caméra (V7.5.1) et le corps (V7.5.2), pour que chaque nouveau style ait tout de suite sa pose, son trajet de caméra et ses effets. G-227 passe en premier : la couleur personnelle remplace la palette, donc les nouveaux styles l'utilisent dès le départ. G-230 (Implosion, sans éclat) est le plus simple et va avec « aucun flash ». Ils seront plus simples à écrire une fois Regeneration.lua découpé par style (V10), et ils rejoindront le choix du style de la V11.1 : voir les remarques.

## V7.6 — Vol libre et rayon tracteur (5 lots, 37 propositions)

Poser les limites du vol libre, puis rendre la chute, la caméra du pilote, l'altitude et le rayon tracteur plus vivants.

### V7.6.1 — Vol libre : limites et prudence

**Objectif :** Donner des limites au vol libre : montée en puissance au départ, vitesse bridée portes ouvertes ou cabine abîmée, turbulences selon la vitesse, saut temporel par charges, atterrissages contrôlés.

- **C-76. Montée en puissance au décollage du vol libre** *(petit)* : Les 3 premières secondes, la vitesse serait limitée à LENT. On évite les départs en TURBO au milieu des joueurs.
- **C-75. Portes ouvertes en vol : vitesse bridée** *(petit)* : Tant que les portes sont ouvertes en vol libre (O), le niveau maximal serait NORMAL, et un tonneau (C) ferait tomber les passagers près de la porte.
- **C-82. Turbulences qui suivent la vitesse** *(petit)* : TurbulencesForce est la même en LENT et en TURBO. Elle suivrait le niveau de vitesse : faible en LENT, forte en TURBO et en Urgence.
- **C-103. Intégrité basse qui bride le vol libre** *(moyen)* : Sous 50 % d'intégrité, les niveaux RAPIDE et TURBO sont refusés ; sous 25 %, plus de saut temporel. Il faut réparer avant de repartir à fond.
- **C-72. Saut temporel par charges** *(petit)* : SautRecharge (0,25 s) permet de sauter en boucle. Le saut aurait 3 charges, rendues en 5 s.
- **C-73. Saut temporel plus long en étant dématérialisé** *(petit)* : Quand le TARDIS est invisible en vol, le saut (B) irait trois fois plus loin. Utile pour passer un obstacle sans être vu.
- **C-153. Stabilisateur qui réduit les tempêtes temporelles** *(petit)* : En vol libre, une tempête temporelle dévie deux fois moins le TARDIS quand le stabilisateur est activé. Le stabilisateur sert aussi en vol.
- **C-67. Vol libre en zone REFUSE : atterrissage d'urgence** *(petit)* : finirVolLibre ne regarde pas les zones. Se poser en vol libre dans une zone REFUSE ferait une glissade d'Urgence, avec un message.
- **C-68. Collision à l'atterrissage du vol libre** *(petit)* : lancerDescente et teleAtterrir ne testent pas enCollision. Une arrivée dans un mur passerait en glissade d'Urgence, avec dégâts.

**Dans Studio :** Rien.

*Pourquoi ici :* Ce lot vient après la V6.9.10 (23 croisière, 30 frein d'urgence), qui touche les mêmes niveaux de vitesse. Toutes les règles sont dans VolLibre.lua (serveur) et TardisVolLibre.client (niveaux, saut, turbulences). Elles passent avant la V7.6.2 (chute et feu) et la V7.6.3 (caméra du pilote) : G-266 a besoin de la règle des portes ouvertes (C-75), G-274 de la règle des turbulences (C-82). Ordre : C-76, C-75, C-82, C-103 (vitesse), puis C-72, C-73 (saut), puis C-153, puis C-67 et C-68, qui ajoutent des tests de zone et de collision dans finirVolLibre, lancerDescente et teleAtterrir.

### V7.6.2 — Vol libre : chute et feu

**Objectif :** Faire de la chute et du feu en vol des moments marquants : dégâts selon la hauteur et la vitesse, crash si l'Urgence dure, braises, cabine qui rougeoie, cratère, chute ressentie à bord.

- **C-74. Vol libre en feu : crash après un moment** *(petit)* : En Urgence, si le pilote ne coupe pas l'urgence après X s, le TARDIS chute tout seul (lancerDescente « Chute »).
- **C-107. Dégâts de chute selon la hauteur** *(petit)* : DegatsChute vaut toujours 80. Le calculer selon la hauteur de la chute (double Espace) : une petite chute coûte peu, une grande beaucoup.
- **C-108. Dégâts de choc selon la vitesse** *(petit)* : DegatsChoc est fixe (25). Le multiplier par le niveau du vol libre au moment du choc, pour récompenser le vol prudent.
- **G-41. Braises qui tombent de la cabine en feu** *(petit)* : En urgence en vol (VolUrgence), des braises se détachent de la cabine et tombent vers le sol, en plus du feu et de la fumée (majUrgence). Elles s'éteignent avant de toucher le sol.
- **G-42. Cabine qui rougeoie après une chute** *(petit)* : Après l'impact d'une chute, la cabine garde une teinte orange qui refroidit en 10 secondes, avec un peu de vapeur. Aujourd'hui tous les effets de chute s'arrêtent net à l'impact.
- **G-43. Cratère temporaire après une chute violente** *(moyen)* : Un impact fort laisse un cratère sombre avec quelques débris au sol pendant 30 secondes. Il remplace la marque carrée pour cet atterrissage-là.
- **G-296. Lueur de chaleur pendant la chute** *(petit)* : Pendant la rentrée atmosphérique, les bords de l'écran du pilote rougeoient et vibrent.
- **G-184. Chute en vol libre ressentie à bord** *(moyen)* : Pendant la chute (Espace ×2), les occupants ont un léger effet d'apesanteur (caméra qui flotte), puis un gros choc quand la cabine touche le sol.

**Dans Studio :** Rien.

*Pourquoi ici :* Les règles d'abord (VolLibre.lua et TardisSystemes) : C-74 relance lancerDescente « Chute », C-107 et C-108 remplacent DegatsChute et DegatsChoc fixes par un calcul. Ensuite les effets : G-41 et G-42 dans EffetsExterieurs, G-43 qui remplace la marque carrée de la V6.9.9 pour cet atterrissage, G-296 pour le pilote, G-184 pour les passagers. Le lot suit la V7.6.1, qui a posé les limites de vitesse.

### V7.6.3 — Vol libre : caméra du pilote

**Objectif :** Rendre le pilotage plus agréable à regarder : transitions douces, roulis dans les virages, recul avec la vitesse, cabine transparente quand elle gêne, fumée, vent par la porte, turbulences ressenties.

- **G-290. Transitions de caméra en début et fin de vol** *(petit)* : entrerPilotage et sortirPilotage changent la caméra d'un coup. Un glissement ou un fondu rapide de 0,3 seconde masquerait le saut.
- **G-291. Roulis de la caméra dans les virages** *(petit)* : La caméra du pilote penche un peu dans le même sens que la cabine (R.INCLINAISON), pour mieux sentir les virages.
- **G-292. Caméra qui recule avec la vitesse** *(petit)* : Plus le TARDIS va vite, plus la caméra s'éloigne ; elle se rapproche à l'arrêt.
- **G-281. Cabine transparente quand elle gêne la vue** *(petit)* : En vol libre, quand la caméra passe tout près de la cabine ou qu'elle cache le sol à l'atterrissage, la cabine devient à moitié transparente pour le pilote seulement (LocalTransparencyModifier).
- **G-297. Fumée sur l'écran en vol d'urgence** *(petit)* : Quand le TARDIS vole en feu (VolUrgence), un peu de fumée passe devant la caméra du pilote.
- **G-274. Turbulences ressenties à l'écran** *(petit)* : Les joueurs poussés par les turbulences du vol libre ont une petite secousse et de la poussière devant les yeux.
- **G-266. Vent par la porte ouverte en vol** *(petit)* : Portes ouvertes en vol libre : des particules de vent entrent et ceux près de la porte sont un peu secoués.

**Dans Studio :** Rien.

*Pourquoi ici :* Tout est dans TardisVolLibre.client, sur la boucle de caméra du pilote qui existe déjà. Ce lot vient après la V6.9.10 (26, caméra cinématique), qui touche la même boucle, et après la V7.6.1 : G-266 suit la règle des portes ouvertes (C-75), G-274 la règle des turbulences (C-82). G-290 passe en premier, car il simplifie l'entrée et la sortie du pilotage. G-291, G-292 et G-297 respectent le réglage de secousses et le champ de vision fixe de la V7.4.1.

### V7.6.4 — Vol libre : toit, sol et nuages

**Objectif :** Garder les passagers du toit au décollage, puis montrer l'altitude et la vitesse en vol libre : poussière au ras du sol, petit nuage à l'atterrissage, bang au passage en Turbo, nuages traversés et ciel plus sombre en haute altitude.

- **C-78. Passagers sur le toit en vol libre** *(moyen)* : Les joueurs debout sur la cabine au décollage resteraient accrochés, comme les clandestins du vortex, au lieu de tomber dès le départ.
- **G-34. Poussière soulevée en vol au ras du sol** *(petit)* : En vol libre à moins de 12 studs du sol, un anneau de poussière (couleur du sol, comme le tourbillon) se forme sous la cabine. Il est plus fort quand elle va vite.
- **G-36. Petit nuage à l'atterrissage du vol libre** *(petit)* : La touche N (atterrir ici) et le retour au sol automatique finissent sans aucun effet. Une petite bouffée de poussière et une onde légère marquent le moment où elle touche le sol.
- **G-38. Bang sonique au passage en Turbo** *(petit)* : Quand le vol libre passe au niveau TURBO, un anneau d'air (onde transparente) part de la cabine vers l'arrière. Il se déclenche une seule fois par passage.
- **G-39. Nuages traversés en haute altitude** *(moyen)* : Au-dessus d'une certaine hauteur, la cabine traverse des nappes de nuage (particules) qui s'écartent sur son passage. On sent qu'elle monte vraiment haut.
- **G-295. Ciel plus sombre en haute altitude** *(moyen)* : Au-dessus d'une hauteur, l'Atmosphere et la lumière locales passent au bleu nuit. On sent qu'on monte très haut.

**Dans Studio :** Rien.

*Pourquoi ici :* C-78 (règle) passe d'abord : les joueurs debout sur la cabine restent accrochés au décollage, avec la même logique que les clandestins du vortex (TardisServeur, VolLibre.lua) ; il faut les lâcher proprement à l'atterrissage ou en cas de chute. Le reste, ce sont des effets côté client, dans TardisVolLibre.client et EffetsExterieurs. Ils lisent la hauteur et le niveau de vitesse, déjà connus. G-36 marque la fin de la touche N et du retour au sol automatique, que la V7.6.1 a rendus plus sûrs (C-67, C-68). G-39 et G-295 (moyens) passent en dernier : G-295 change l'Atmosphere locale et doit la remettre à l'atterrissage.

### V7.6.5 — Rayon tracteur

**Objectif :** Rendre le rayon tracteur lisible et physique : poids des objets, particules qui montrent le sens, cible entourée de cyan, rayon qui tremble près de la portée, pose flottante, effets à bord et à l'écran.

- **C-84. Rayon tracteur sensible au poids des objets** *(moyen)* : Les objets lourds ralentiraient le TARDIS, ou ne pourraient pas être soulevés : Config.Tracteur.Force deviendrait une limite de masse.
- **G-85. Rayon tracteur avec particules aspirées** *(petit)* : Des particules lumineuses glissent le long du faisceau, de l'objet vers la cabine. On voit dans quel sens le rayon attire.
- **G-86. Objet attiré entouré d'une lueur cyan** *(petit)* : L'objet ou le joueur pris par le rayon tracteur (TracteurCible) reçoit un Highlight cyan qui pulse. On voit tout de suite ce qui est capturé.
- **G-87. Rayon qui vibre près de la portée maximale** *(petit)* : Quand l'objet approche de Config.Tracteur.Portee, le faisceau devient plus fin, tremble et rougit, pour montrer au pilote qu'il va lâcher.
- **G-88. Joueur attiré en pose flottante** *(moyen)* : Un joueur pris par le rayon tracteur prend une pose de flottement (bras écartés, petite rotation) au lieu de glisser debout. Animation locale, arrêtée quand il est lâché.
- **G-196. Rayon tracteur ressenti dans la salle** *(petit)* : Quand le rayon tracteur est actif, une lueur verte monte du centre du sol de la salle et la console vibre un peu.
- **G-273. Effet sur le joueur pris par le rayon tracteur** *(petit)* : Le joueur attiré voit une teinte bleue et un léger flou pendant qu'il est transporté.

**Dans Studio :** Rien.

*Pourquoi ici :* C-84 (règle : Config.Tracteur.Force devient une limite de masse) passe d'abord, dans TardisExtras et TardisVolLibre.client : G-87 en dépend, car la limite de portée et de poids se montre par le même tremblement. Les effets suivent : G-85, G-86 et G-87 dans EffetsExterieurs, G-88 (animation locale), G-196 dans la salle, G-273 sur l'écran du joueur attiré. Tous lisent TracteurCible, qui existe déjà.

## V7.7 — Systèmes du TARDIS (7 lots, 53 propositions)

Donner du poids à l'énergie, à l'intégrité, à la maintenance, à l'air, aux boucliers et au camouflage, règle d'abord puis effet.

### V7.7.1 — Énergie : règles du courant

**Objectif :** Donner du sens à l'énergie et à la coupure de courant : réglages du technicien qui comptent, portes à ouvrir à la main, mode veille, console de secours sur batterie avec plus de commandes.

- **C-116. Customisation impossible hors tension** *(petit)* : Sans courant, murs, styles de l'intérieur et de la console, thème et enseigne seraient refusés (« HORS TENSION »), comme les autres systèmes.
- **C-133. Jukebox coupé hors tension et en alerte** *(petit)* : La musique s'arrête quand l'alimentation est coupée ou pendant l'alerte générale, puis reprend ensuite.
- **C-129. Portes à ouvrir à la main hors tension** *(petit)* : Sans courant, les portes ne s'ouvrent qu'en maintenant E 4 s, pour tout le monde. Couper le courant devient une décision lourde.
- **C-132. Mode veille quand la salle est vide** *(petit)* : Posé, personne à bord depuis 5 minutes : lumières baissées, aucune panne aléatoire, air qui remonte. Tout se rallume quand quelqu'un entre.
- **C-119. Redémarrage qui échoue si l'énergie est mal réglée** *(petit)* : Le redémarrage (levier ou à distance) échoue si la régulation de l'énergie est en sous-tension ou en surtension. Le technicien doit d'abord la régler.
- **C-120. Sous-tension : camouflage et rapetissement refusés** *(petit)* : Sous le seuil SousTension (20 %), basculerCamouflage et reglerTaille répondent « SOUS-TENSION ». Le curseur d'énergie de la tablette technicien sert enfin à quelque chose.
- **C-121. Surtension qui supprime la recharge du Rapide** *(petit)* : Au-dessus de SurtensionAuDessus, la recharge de 5 s du Rapide saute, mais le risque de fuite de vapeur reste. Un vrai choix pour les techniciens.
- **C-188. Console de secours avec plus de commandes** *(petit)* : La console de secours n'a que Décoller et Atterrir. Ajouter l'alimentation, les portes et l'alerte.
- **C-131. Console de secours sur batterie** *(moyen)* : Aujourd'hui la console de secours refuse « HORS TENSION ». Elle permettrait un seul voyage d'Urgence sans courant, puis la batterie se recharge en 10 minutes.

**Dans Studio :** Rien. La Part ConsoleSecours existe déjà. L'invite à maintenir de C-129 est créée par le code.

*Pourquoi ici :* Ce sont des règles serveur (TardisServeur : basculerCamouflage, reglerTaille, customisation ; TardisSystemes : redémarrage, régulation ; TardisExtras : jukebox, console de secours). Elles passent avant la V7.7.2, qui montre la coupure et le retour du courant. C-120 doit aussi précéder la V7.7.7 (camouflage). C-188 puis C-131 passent ensemble à la fin : ils touchent la même console de secours, et la batterie de C-131 est le changement le plus risqué (un voyage sans courant). Ordre : C-116, C-133, C-129, C-132, puis C-119, C-120, C-121, puis C-188 et C-131. La console de secours sera à revoir avec la console de la V12.

### V7.7.2 — Coupure et retour du courant

**Objectif :** Rendre visible chaque coupure et chaque retour du courant à bord : extinction en cascade, écrans qui s'éteignent en point, rotor qui retombe, néons qui s'amorcent, écran qui redémarre, console de secours qui s'allume.

- **G-131. Coupure de courant en cascade** *(moyen)* : Hors tension, les lumières et néons s'éteignent par vagues, de la console vers les murs, en une seconde, et les néons gardent une lueur qui meurt doucement (aujourd'hui tout s'éteint d'un coup dans appliquerEclairage).
- **G-113. Écrans qui s'éteignent en point lumineux** *(petit)* : À la coupure, l'écran de la console et les écrans Diagnostic se réduisent en une ligne puis en un point blanc, comme un vieux téléviseur, au lieu de disparaître d'un coup.
- **G-118. Hologramme éteint quand le courant est coupé** *(petit)* : Aujourd'hui l'hologramme reste allumé sans courant (seul jeSuisDedans compte) : il s'éteindrait en grésillant à la coupure et reviendrait au retour du courant.
- **G-129. Rotor qui retombe à la coupure** *(petit)* : Si le courant est coupé quand le rotor est en haut, il retombe lourdement au lieu de glisser, avec un petit à-coup de caméra pour ceux qui sont à bord.
- **G-116. Console de secours qui s'allume en panne** *(petit)* : La pièce ConsoleSecours reste sombre d'habitude et s'illumine en orange quand le courant est coupé ou en avarie, pour attirer l'œil vers elle au bon moment.
- **G-132. Néons qui s'amorcent au rallumage** *(petit)* : Au retour du courant, les néons clignotent deux ou trois fois avant de tenir, comme des tubes qui s'allument ; remplacé par un fondu avec « Aucun flash ».
- **G-112. Écran de la console qui redémarre** *(petit)* : Au retour du courant, l'écran de la console (guiEcran) montre quelques secondes une séquence de démarrage (logo, lignes qui défilent) avant d'afficher l'état normal.
- **G-156. Salle qui se rallume pendant le redémarrage** *(moyen)* : Pendant les 10 s de maintien du redémarrage, les lumières remontent peu à peu, comme une jauge, au lieu de revenir d'un coup à la fin.

**Dans Studio :** Rien.

*Pourquoi ici :* Ce lot suit les règles de la V7.7.1. Le point délicat est G-131 : appliquerEclairage (TardisServeur) éteint tout d'un coup côté serveur ; la cascade se fait côté client, qui garde la valeur finale du serveur. G-132 et G-156 utilisent le même mécanisme au rallumage, G-132 avec un fondu en « aucun flash ». G-113 et G-112 changent l'écran de la console (guiEcran) et les écrans Diagnostic. G-118 et G-116 lisent Alimentation dans Ambiance. Ordre : coupure (G-131, G-113, G-118, G-129, G-116), puis retour (G-132, G-112, G-156).

### V7.7.3 — Intégrité : dégâts et réparations

**Objectif :** Rendre l'intégrité plus juste et plus visible : tirs à l'intérieur qui comptent, explosions selon la distance, réparation complète par la C.T.A.T., guérison lente, cabine abîmée, épave, néons qui vacillent.

- **C-109. Explosions moins fortes avec la distance** *(petit)* : Une explosion fait 300 PV qu'elle soit à 1 ou à 60 studs (TardisSystemes). Les dégâts baissent avec la distance.
- **C-104. Tirs à l'intérieur qui abîment le TARDIS** *(moyen)* : surveillerImpacts ne regarde que l'extérieur. Les impacts de balles sur la console et les murs de la salle enlèveraient aussi un peu d'intégrité : un combat à bord a un prix.
- **C-105. Réparation complète réservée aux techniciens** *(petit)* : Le maintien de E sur le rotor (invite TardisReparation) ne remonte qu'à 50 % pour un pilote ; au-delà, il faut un membre de la C.T.A.T. Rôle plus net pour l'équipe technique.
- **C-106. Auto-réparation lente du TARDIS posé** *(petit)* : Posé, alimenté et sans panne, le TARDIS regagne 1 % par minute, sans dépasser 80 %. Il « guérit » un peu seul, sans remplacer les techniciens.
- **G-60. Cabine abîmée selon ses points de vie** *(moyen)* : Sous 50 % de PointsDeVie, des traces noires apparaissent sur les panneaux ; sous 25 %, l'enseigne grésille et une fumée légère sort du toit. Tout disparaît après réparation.
- **G-138. Néons qui vacillent quand l'intégrité est basse** *(petit)* : Sous 30 % de PointsDeVie, quelques néons de la salle vacillent au hasard (lentement avec « Aucun flash ») : on voit que le TARDIS souffre.
- **G-61. Épave visible quand le TARDIS est détruit** *(moyen)* : Aujourd'hui l'attribut Detruit rend la cabine invisible (alphaVol). Une carcasse noircie et fumante, enseigne éteinte, pourrait rester à la place jusqu'à la remise en état.

**Dans Studio :** Facultatif : une texture de traces noires pour G-60. Sans elle, le code assombrit des panneaux.

*Pourquoi ici :* Les règles d'abord, dans TardisSystemes (surveillerImpacts, invite TardisReparation) : C-109, puis C-104 (tirs dans la salle), puis C-105 et C-106 (réparation). C-105 vient après la V6.9.13 (outils du technicien). Puis les effets : G-60 (cabine abîmée) et G-61 (épave quand Detruit) dans TardisEffets, G-138 dans Ambiance. G-61 doit vérifier que la cabine réapparaît bien après la remise en état. Ce lot suit les dégâts de chute (V7.6.2), qui ont changé le calcul des PV.

### V7.7.4 — Maintenance et réparations

**Objectif :** Rendre la maintenance plus pratique et les réparations plus visibles : durée limitée, réparations plus rapides, levée réservée, gyrophare orange, signal dehors, volant de vanne, étincelles et vague verte.

- **C-162. Maintenance à durée limitée** *(petit)* : Choisir une durée (15, 30 ou 60 minutes) après laquelle la maintenance se lève seule, avec un message.
- **C-161. Réparations plus rapides en maintenance** *(petit)* : En maintenance, la réparation du rotor rend deux fois plus et la purge est plus courte.
- **C-279. Maintenance levée par son auteur ou un pilote** *(petit)* : Aujourd'hui n'importe quel technicien ou pilote lève la maintenance (action Maintenance de TardisSystemes). Une maintenance lancée par un pilote ne pourrait être levée que par lui ou un autre pilote.
- **C-102. Réparation du rotor interrompue par les dégâts** *(petit)* : Si le TARDIS prend un tir ou un choc pendant les 5 s de maintien sur le rotor (TardisReparation), la réparation est annulée. Il faut se mettre à l'abri avant de réparer.
- **G-134. Gyrophare orange en mode maintenance** *(petit)* : Tant que la maintenance est active, une lampe orange tourne lentement au-dessus de la console : on voit d'un coup d'œil que les voyages sont bloqués, sans ouvrir la tablette.
- **G-152. Volant de la vanne qui tourne** *(petit)* : Pendant les 4 s de maintien sur la Vanne avec la clé à molette, son volant tourne (si la pièce en a un) et un filet de fumée s'arrête à la fin.
- **G-153. Étincelles bleues pendant la réparation du rotor** *(petit)* : Pendant les 5 s de maintien sur le rotor (TardisReparation), de petites étincelles bleues jaillissent devant le joueur qui répare.
- **G-154. Vague verte à la fin d'une réparation** *(petit)* : Quand ReparationTemps change, une lueur verte parcourt la console de bas en haut : la réparation se voit, pas seulement dans le message.

**Dans Studio :** Facultatif : une Part « Volant » dans la Vanne de TARDIS_1 (G-152).

*Pourquoi ici :* Les règles d'abord, dans l'action Maintenance et dans TardisReparation (TardisSystemes) : C-162, C-161, C-279, puis C-102 (réparation annulée par les dégâts, qui lit les impacts de la V7.7.3). G-66 (signal dehors) est déjà fait en V7.2.1. Puis les effets : G-134 dans Ambiance, G-152, G-153 et G-154 au moment des réparations. Lot placé après l'intégrité, qui a changé la réparation (C-105).

### V7.7.5 — Air et incendie

**Objectif :** Faire de l'air un vrai sujet RP : usure selon les occupants, air vicié qui essouffle, portes ouvertes qui aèrent, purge qui étouffe le feu, masques à oxygène, effets à l'écran et sur les écrans.

- **C-124. Usure de l'air selon le nombre d'occupants** *(petit)* : UsureAir est la même pour 1 ou 15 joueurs à bord. La multiplier par le nombre d'occupants.
- **C-122. Air vicié qui essouffle les occupants** *(petit)* : Sous SeuilAirVicie, il n'y a qu'un voile gris. Ajouter une marche plus lente et un saut réduit ; à 0 %, de très légers dégâts.
- **C-123. Portes ouvertes qui renouvellent l'air** *(petit)* : TARDIS posé et portes ouvertes : RegulAir remonte doucement. Une solution RP à côté de la purge.
- **C-183. Purge refusée portes ouvertes** *(petit)* : La purge de l'air (commande Purger) ne marcherait que portes fermées ; sinon la tablette technicien répond « PORTES OUVERTES ». Un geste RP de plus.
- **C-125. Purge de l'air qui étouffe l'incendie** *(petit)* : Pendant une purge (commande Purger), les flammes s'éteignent faute d'air ; la vanne reste à fermer à la clé à molette.
- **C-128. Masques à oxygène dans les casiers** *(moyen)* : Un casier donne un masque qui protège de l'air vicié pendant 5 minutes. Relie les casiers et la régulation de l'air.
- **G-151. Flammes qui s'étouffent sous l'extincteur** *(petit)* : Au jet d'extincteur, les flammes rétrécissent en une seconde au lieu de s'arrêter net, et une mousse blanche reste au sol quelques secondes.
- **G-192. Buée sur les écrans après une purge** *(petit)* : Après une purge de l'air (TechPurgeFin), l'écran de la console et les écrans Diagnostic se couvrent d'une buée blanche qui s'efface en 10 secondes, en commençant par le centre.
- **G-270. Vision qui se rétrécit dans l'air très vicié** *(petit)* : En partie là (image ternie par TardisAirVicie). Sous 10 % d'air, une vignette sombre se resserre doucement.

**Dans Studio :** Facultatif : un modèle de masque (Accessory) dans TardisAssets pour C-128.

*Pourquoi ici :* Ce lot vient après la V6.9.13 (118, panne de fuite d'air), qui touche la même régulation RegulAir. Les règles sont dans TardisSystemes : C-124, C-122, C-123, puis la purge (C-183, C-125). C-128 relie les casiers (TardisExtras) à l'air vicié : il passe après. Les effets suivent : G-151 (extincteur), G-192 (buée après TechPurgeFin), G-270 (vignette sous 10 % d'air). C-36 (air plus vite dans le vortex) est déjà en V7.8.1.

### V7.7.6 — Boucliers : recharge, faille et équipage

**Objectif :** Rendre les boucliers plus tactiques : recharge au repos, délai après une brèche, explosions absorbées, joueurs écartés, équipage qui passe, anti-balles en vol libre, motif hexagonal et chute ressentie.

- **C-138. Bouclier qui se recharge au repos** *(petit)* : BouclierEnergie ne remonte qu'en relançant le bouclier. Sans tir depuis 30 s, il regagne quelques pour cent par seconde.
- **C-139. Bouclier brisé : délai avant relance** *(petit)* : Après BouclierBrise, il faudrait 60 s avant de le relancer (aujourd'hui il repart tout de suite à 100 %). Les assaillants ont une fenêtre.
- **C-143. Bouclier complet qui absorbe les explosions** *(petit)* : Une explosion proche fait 300 PV même bouclier levé. Elle viderait l'énergie du bouclier à la place.
- **C-141. Activation du bouclier qui écarte les joueurs** *(petit)* : Les joueurs pris dans la bulle au moment où elle se lève sont doucement poussés dehors, sauf l'équipage.
- **C-142. Bouclier anti-joueurs qui laisse passer l'équipage** *(moyen)* : Les murs invisibles bloquent aussi les pilotes et techniciens. Un groupe de collision propre à l'équipage les laisse passer.
- **C-140. Bouclier anti-balles possible en vol libre** *(moyen)* : toutCouper retire les boucliers dès le vol libre. Garder l'anti-balles en vol, avec une bulle qui suit la cabine.
- **G-89. Motif en nid d'abeille sur les impacts du bouclier** *(petit)* : Les ondulations d'impact (EffetsExterieurs) et les révélations (Boucliers) montrent un motif hexagonal qui s'efface. Le bouclier ressemble à un vrai champ de force.
- **G-161. Chute du bouclier ressentie à bord** *(petit)* : Quand le bouclier se brise (BouclierBrise), la salle tremble et les lumières baissent d'un coup pendant une seconde.

**Dans Studio :** Rien. Le groupe de collision de l'équipage (C-142) est créé par le code.

*Pourquoi ici :* Les règles d'abord, dans TardisSystemes (BouclierEnergie, BouclierBrise) : C-138, C-139, C-143, puis C-141 et C-142 (collisions, à tester avec plusieurs joueurs), puis C-140 (anti-balles en vol libre, après la V7.6.1 qui a fixé les règles du vol). Puis les effets côté client : G-89 dans EffetsExterieurs et Boucliers.lua, G-161 à bord. G-159 (voile dans la vue de la porte) est dans la V7.3.5, avec la vue par la porte.

### V7.7.7 — Camouflage et circuit caméléon

**Objectif :** Rendre le camouflage plus vivant : panne de camouflage instable, camouflage trahi au contact, balayage de haut en bas, et un circuit caméléon qui déguise la cabine en objet banal.

- **C-169. Nouvelle panne : camouflage instable** *(moyen)* : Le camouflage clignote ou refuse de s'activer jusqu'à une réparation sur la console.
- **G-75. Camouflage qui balaie de haut en bas** *(moyen)* : Au lieu d'un fondu égal partout (alphaCamouflage), une ligne lumineuse descend sur la cabine et la fait disparaître au fur et à mesure. Elle remonte pour la faire réapparaître.
- **G-74. Camouflage trahi au contact ou sous les tirs** *(moyen)* : Un joueur qui touche la cabine camouflée, ou une balle qui la frappe, fait onduler sa silhouette une demi-seconde. Le camouflage est crédible et on peut jouer avec en RP.
- **C-145. Circuit caméléon : déguiser la cabine** *(gros)* : Un second camouflage qui donne à la cabine l'apparence d'un objet banal (caisse, armoire électrique) au lieu de la rendre invisible.

**Dans Studio :** À construire : quelques modèles de déguisement (caisse, armoire électrique…) dans TardisAssets > Cameleon, à la taille de la cabine.

*Pourquoi ici :* C-169 (nouvelle panne) vient après la V6.9.12 (117, liste pondérée des pannes) et passe en premier. C-120 (camouflage refusé en sous-tension) est déjà fait en V7.7.1. G-75 et G-74 changent alphaCamouflage dans TardisEffets. C-145 (gros) passe en dernier : c'est un second camouflage, avec ses modèles, son action réseau et sa place dans les menus. C-146 (camouflés visibles entre pilotes) est gardé pour la V7.10.3, avec les autres idées à plusieurs TARDIS.

## V7.8 — Voyage : modes, zones et destinations (11 lots, 76 propositions)

Changer les règles du voyage classique : vortex, Urgence, zones, empreinte, taille, nouveaux modes, interruptions et nouvelles destinations.

### V7.8.1 — Le vortex : couleurs et ambiance

**Objectif :** Faire du vortex un moment fort : tunnel aux couleurs du mode qui s'ouvre et se referme en fondu, éclairs, bords d'écran, brume et hologramme brouillé à bord, avec deux règles qui donnent du poids au séjour.

- **C-36. Air consommé plus vite dans le vortex** *(petit)* : L'usure de l'air (Config.Technicien.UsureAir) serait doublée pendant le vol. Un long séjour dans le vortex donne du travail à la C.T.A.T.
- **C-118. Tempête de vortex plus tôt si intégrité basse** *(petit)* : La tempête de vortex arrive après 10 minutes dans le vortex. Sous 30 % d'intégrité, elle arriverait après 5 minutes : un TARDIS abîmé tient mal dans le vortex.
- **G-47. Vortex du ciel aux couleurs du mode** *(petit)* : Le tunnel du voyage classique dans le ciel (attribut Ciel) a la même couleur dans tous les modes. Il pourrait prendre la couleur dehors du mode : orange en Urgence, rouge en Catastrophe, cyan en Sauvetage.
- **G-48. Ouverture et fermeture du vortex en fondu** *(petit)* : Aujourd'hui le tunnel apparaît et disparaît d'un coup (creerVortex, detruireVortex). Il pourrait s'ouvrir en s'élargissant depuis la cabine et se refermer en se resserrant, en une seconde.
- **G-49. Éclairs du vortex qui éclairent la cabine** *(petit)* : Les arcs du tunnel sont seulement des traits. Une lumière brève sur la cabine à chaque éclair lui donne du relief. Coupé en « aucun flash ».
- **G-298. Couleur du vortex selon le mode** *(petit)* : teinteVortex ne change qu'en urgence. La grille et la teinte suivraient le mode : violet en Silencieux, vert en Rapide.
- **G-299. Éclairs dans le tunnel du vortex** *(petit)* : De temps en temps, un éclair parcourt la grille du vortex et la caméra frémit.
- **G-267. Bords de l'écran qui ondulent dans le vortex** *(petit)* : Pour les passagers à bord pendant l'état Vol, un léger dégradé cyan respire sur les bords de l'écran.
- **G-146. Brume au sol dans le vortex** *(petit)* : Pendant le vol dans le vortex, une brume basse et légère couvre le sol de la salle, puis se dissipe à l'atterrissage.
- **G-121. Hologramme brouillé dans le vortex** *(petit)* : Pendant le vol dans le vortex, les marqueurs de la carte tournent en spirale et se brouillent, puis reprennent leur place à l'arrivée : on sent qu'on n'est plus nulle part.

**Dans Studio :** Rien.

*Pourquoi ici :* Ce lot vient après la V6.9.10 (136, son du vortex ; 52, rotor qui suit la vitesse), qui touche les mêmes moments. Les deux règles passent d'abord : C-36 double l'usure de l'air en vol et C-118 avance la tempête si l'intégrité est basse (TardisSystemes et VolLibre, une condition chacune). Les effets suivent : G-47, G-48, G-49, G-298 et G-299 dans creerVortex et teinteVortex (TardisVolLibre.client) ; G-267 côté écran ; G-146 et G-121 dans Ambiance. Tous lisent l'état Vol et le mode, qui existent déjà. G-49 et G-299 sont coupés avec « aucun flash ».

### V7.8.2 — Urgence : règles d'atterrissage

**Objectif :** Faire de l'Urgence une vraie conséquence : imposée quand la cabine est abîmée ou surchargée, cabine posée de travers, durée imprévisible, départ portes ouvertes, joueurs dessous repoussés.

- **C-11. Urgence imposée quand l'intégrité est basse** *(petit)* : Sous X % des points de vie (TardisSystemes), decoller() et atterrir() passeraient en Urgence ; sous 5 %, le décollage serait refusé. L'état de la cabine se sent en vol.
- **C-32. Trop de passagers : départ en Urgence** *(petit)* : Au-delà de N joueurs à bord, le décollage se ferait en Urgence et le Rapide serait refusé. Le TARDIS peine quand il est surchargé.
- **C-18. Urgence imposée par collision qui abîme la cabine** *(petit)* : Quand une collision impose l'Urgence (urgenceForcee dans atterrir), la cabine perdrait des points de vie. Rater son atterrissage aurait un prix.
- **C-14. Urgence : cabine posée de travers** *(petit)* : En Urgence, la cabine arriverait avec une petite rotation au hasard (la porte n'est plus dans l'axe prévu). Cela montre un atterrissage mal maîtrisé.
- **C-16. Durée d'Urgence un peu imprévisible** *(moyen)* : La remat d'Urgence durerait parfois quelques secondes de plus, en saccades, après la fin du son. L'urgence ne serait jamais tout à fait la même.
- **C-17. Décollage d'Urgence avec les portes ouvertes** *(petit)* : En Urgence, decoller() n'attendrait plus que fermerPortes réussisse : la cabine part portes ouvertes et ceux qui sont dans l'encadrement tombent dehors.
- **C-58. En Urgence, les joueurs dessous sont repoussés** *(petit)* : À une arrivée d'Urgence, les joueurs sous la cabine seraient projetés sur le côté au lieu d'être emmenés à bord.
- **C-101. Arcs statiques en remat et plus forts en Urgence** *(petit)* : Aujourd'hui l'électricité statique (TardisSystemes) ne joue que pendant la démat. Elle jouerait aussi pendant la remat, avec des dégâts doublés en Urgence : on s'écarte d'une cabine qui arrive.
- **C-181. Stabilisateur qui annule aussi la gravité folle** *(petit)* : Le stabilisateur ne coupe que les vibrations. Il empêcherait aussi la gravité folle de l'Urgence.

**Dans Studio :** Rien.

*Pourquoi ici :* Ce sont des règles dans decoller, atterrir et modeAutorise (TardisServeur) et dans TardisSystemes (arcs statiques, gravité folle). Elles passent avant la V7.8.3, qui montre l'Urgence à l'écran : les effets pourront ainsi lire les nouveaux cas (cabine de travers, durée plus longue). Le banc d'essai (V7.1.2) est prêt pour vérifier qu'aucun voyage ne reste bloqué. Ordre : C-11 et C-32 (quand l'Urgence est imposée), puis C-18, C-14, C-16 (ce qu'elle change), puis C-17 et C-58 (joueurs qui tombent ou sont repoussés, à tester avec soin), puis C-101 et C-181. C-17 est délicat en RP : il faut une option dans Config pour le couper.

### V7.8.3 — Urgence : effets dehors et à bord

**Objectif :** Montrer l'Urgence : lampadaires qui grésillent, lampe qui vacille, vapeur froide à l'ouverture, atterrissage avorté lisible, rotor saccadé ou enrayé, arcs sur la console, roulis de caméra.

- **G-58. Lampe qui grésille après un atterrissage d'urgence** *(petit)* : Après une remat d'Urgence, la lampe posée lâche quelques étincelles et vacille pendant 20 secondes, puis se stabilise. Elle va avec le givre qui fond.
- **G-59. Vapeur froide à l'ouverture après une Urgence** *(petit)* : Si les portes s'ouvrent dans la minute qui suit une arrivée d'Urgence, une vapeur froide sort au ras du sol par l'ouverture. Ça raconte que le voyage a été rude.
- **G-24. Lampadaires proches qui grésillent en Urgence** *(moyen)* : Pendant une démat ou une remat d'Urgence ou de Catastrophe, les lumières du décor à moins de 40 studs clignotent (côté client, valeurs remises ensuite). Le TARDIS dérange vraiment ce qui l'entoure.
- **G-53. Atterrissage avorté plus lisible** *(moyen)* : Au premier essai en Catastrophe, la cabine à moitié matérialisée est aspirée vers le haut en se tordant, avant de repartir dans le vortex. Les témoins comprennent qu'elle a été repoussée. En partie là.
- **G-125. Rotor saccadé en Urgence** *(petit)* : En Urgence, la course du rotor suit un mouvement irrégulier (Config.Bruit) avec de petits arrêts, au lieu du même sinus régulier que les autres modes.
- **G-126. Rotor qui s'enraye en Catastrophe** *(petit)* : En Catastrophe, le rotor monte, se bloque, redescend d'un coup, et ses néons sautent entre la couleur du mode et le rouge.
- **G-197. Arcs électriques sur la console en Urgence** *(petit)* : En Urgence (pas seulement en Catastrophe), quelques arcs bleus courent sur la console à chaque souffle, comme ceux de la cabine dehors ; coupés avec « Aucun flash ».
- **G-183. Roulis de caméra en Urgence** *(petit)* : En Urgence et en Catastrophe, la caméra penche un peu de gauche à droite, en plus des secousses actuelles (CameraOffset).

**Dans Studio :** Rien.

*Pourquoi ici :* Ce lot suit les règles de la V7.8.2. Dehors : G-58, G-59 et G-24 dans EffetsExterieurs et TardisEffets (valeurs du décor remises après) ; G-53 (Catastrophe repoussée) dans TardisEffets. À bord : G-125 et G-126 changent la course du rotor selon le mode, G-197 ajoute les arcs de l'Urgence, G-183 ajoute un roulis à CameraOffset. Ils sont coupés par « aucun flash » et par le réglage des secousses (V7.4.1). Tout est côté client.

### V7.8.4 — Zones, destinations et atterrissage

**Objectif :** Donner plus de règles aux destinations : Sauvetage permis en zone REFUSE, mode imposé par une Part, dossier INTERDIT, spawns protégés, Rapide limité en distance, pilotage à distance désactivable, pose sur une légère pente, barrière rouge visible.

- **C-24. Mode imposé par une destination** *(petit)* : Un attribut ModeImpose sur une Part de destination (Silencieux, Urgence…) l'emporterait sur le protocole choisi. Plus souple que de créer un dossier par règle.
- **C-5. Sauvetage autorisé dans les zones REFUSE** *(petit)* : Aujourd'hui, atterrir() change tout mode en Urgence en zone REFUSE. Le Sauvetage, qui est une mission de secours, pourrait s'y poser normalement.
- **C-39. Dossier INTERDIT : aucun atterrissage possible** *(petit)* : Un sous-dossier où même l'Urgence est refusée : le TARDIS reste dans le vortex avec « ZONE INTERDITE ». Pour les chambres de confinement.
- **C-45. Atterrissage interdit sur les points d'apparition** *(petit)* : Une cible sur ou près d'une SpawnLocation serait refusée (ou en Urgence), pour ne pas bloquer ceux qui réapparaissent.
- **C-9. Voyage Rapide limité en distance** *(petit)* : Au-delà de X studs entre le départ et l'arrivée, modeAutorise changerait le Rapide en Classique, avec un message à l'écran comme pour la recharge.
- **C-97. Pilotage à distance désactivable (option RP)** *(petit)* : Démat et Remat depuis le menu marchent de n'importe où sur la carte. Une option les réserverait aux pilotes à bord ou près de la cabine.
- **G-18. Atterrissage aligné sur une légère pente** *(moyen)* : Sur un sol incliné de moins de 10°, la cabine se pose penchée comme le sol, au lieu de rester droite avec un coin dans le vide. Au-delà, elle reste droite comme aujourd'hui.
- **G-55. Barrière rouge quand une zone REFUSE repousse** *(moyen)* : Quand une destination REFUSE force une urgence, un mur rouge en nid d'abeille apparaît une seconde autour du point d'arrivée, comme si le lieu se défendait. Ça explique visuellement la remat d'urgence.

**Dans Studio :** Créer un sous-dossier INTERDIT dans Workspace > TARDIS_DESTINATIONS (commun aux trois TARDIS). Facultatif : un attribut ModeImpose sur certaines Parts de destination.

*Pourquoi ici :* Ce lot vient après la V6.9.11 (16, dossier VITESSE_REDUITE ; 144, fiches de lieux), qui touche les mêmes fonctions resoudreDestination, modeAutorise et atterrir. C-24 passe en premier : c'est le socle « mode imposé par la destination », que C-5 et C-39 utilisent. C-39 doit aussi être exclu du tirage de renaitre (corrigé en V7.1.1 pour REFUSE et ZDC). C-97 est une option de Config, coupée par défaut. G-18 (moyen) penche la cabine sur une pente de moins de 10° au moment où atterrir() calcule sa position : il passe après les règles de lieu, pour ne pas mélanger deux changements dans le même calcul. G-55 montre la zone REFUSE qui repousse : il vient en dernier, après la règle.

### V7.8.5 — Empreinte temporelle et leurre

**Objectif :** Faire de l'empreinte et du leurre des outils de jeu : paradoxe quand on croise sa trace, pister un TARDIS par son empreinte, arriver à la place de son leurre, effets plus lisibles et leurre plus crédible.

- **C-56. Paradoxe en croisant sa propre empreinte** *(petit)* : Revenir à moins de X studs de son point de départ pendant les 30 s de l'empreinte imposerait une arrivée d'Urgence : le TARDIS croise sa propre trace.
- **C-52. Pister un TARDIS grâce à son empreinte** *(moyen)* : Pendant les 30 s de l'empreinte temporelle, un autre TARDIS pourrait la choisir comme destination et arriver là où le premier est allé.
- **C-53. Se rematérialiser à la place de son leurre** *(petit)* : Si la destination est à quelques studs du leurre posé, le leurre disparaît pendant la remat et le vrai TARDIS prend sa place exactement. Le leurre devient un point d'arrivée préparé à l'avance.
- **G-81. Empreinte colorée selon le mode du départ** *(petit)* : L'empreinte temporelle est toujours bleu clair (Config.Empreinte.Couleur). Elle pourrait prendre la couleur dehors du mode : orangée après une Urgence, rouge après une Catastrophe.
- **G-83. Empreinte qui réagit quand on la traverse** *(moyen)* : Un joueur qui traverse l'empreinte la fait onduler et s'effacer plus vite là où il passe, avec quelques étincelles bleues. Le joueur interagit avec la trace.
- **G-95. Leurre qui grésille quand on le touche** *(petit)* : Le faux TARDIS (TardisLeurre) se brouille et montre des parasites quand un joueur le touche ou tire dessus. Il se trahit en RP, sans disparaître.
- **G-96. Leurre plus crédible avec lampe et enseigne animées** *(petit)* : Le leurre est une copie figée. Sa lampe pourrait respirer et son enseigne s'éclairer la nuit comme la vraie cabine, pour mieux tromper.

**Dans Studio :** Rien. Pour tester C-52, déclarer un second TARDIS dans Config.Tardis.

*Pourquoi ici :* Les règles d'abord, dans TardisServeur (atterrir, destinations) et TardisExtras (TardisLeurre) : C-56 (paradoxe), C-52 (empreinte choisie comme destination) et C-53 (leurre remplacé). Puis les effets : G-81 et G-83 dans TardisEffets (Config.Empreinte), G-95 et G-96 dans EffetsExterieurs. C-52 n'a vraiment d'intérêt qu'avec plusieurs TARDIS (voir les remarques). Lot placé après les zones (V7.8.4), qui ont fixé l'ordre des règles d'arrivée.

### V7.8.6 — Taille et placement du TARDIS

**Objectif :** Rendre la taille du TARDIS plus utile : reprendre sa taille en poche, voyager rétréci, lancer le TARDIS porté, cabine géante, rapetissement progressif, onde à la pose et flèche de placement.

- **C-65. Poche : reprendre sa taille à l'arrivée** *(petit)* : Option : le TARDIS de poche arrive aujourd'hui toujours petit. S'il y a la place (enCollision), il reprendrait sa taille d'avant.
- **C-66. Un TARDIS rétréci peut voyager vers une destination** *(petit)* : La Remat d'un TARDIS rétréci ignore la destination (cibleSurPlace). Il pourrait y aller et arriver petit, sans être porté.
- **C-196. Agrandir le TARDIS au-delà de sa taille** *(moyen)* : Le curseur de taille irait jusqu'à 1,5 pour une cabine géante, en plus du rapetissement.
- **C-193. Lancer le TARDIS porté** *(moyen)* : Le porteur peut lancer le TARDIS rapetissé à quelques studs ; il se pose là où il tombe.
- **G-45. Rapetissement progressif en vol de précision** *(petit)* : Le vol de précision réduit la cabine à 30 % d'un coup sur chaque client (ScaleTo). Une transition d'une demi-seconde, avec quelques étincelles, rend le changement lisible.
- **G-77. Onde au sol quand on pose le TARDIS porté** *(petit)* : Quand le porteur pose le TARDIS (touche G), une onde et une bouffée de poussière partent au sol quand il reprend sa taille. Aujourd'hui il se recale sans rien.
- **G-80. Flèche au sol pendant le repositionnement fin** *(petit)* : Pendant TardisRotation, une flèche lumineuse au sol montre où regarde la porte, et un cadre montre la place de la cabine. Le placement est plus précis.

**Dans Studio :** Rien.

*Pourquoi ici :* Les règles d'abord, dans TardisServeur (reglerTaille, poche, cibleSurPlace, enCollision) et TardisPorter : C-65 et C-66 (voyage rétréci), C-196 (jusqu'à 1,5), puis C-193 (lancer, le plus délicat). G-79 (effets à l'échelle) est déjà fait en V7.1.1 : la cabine géante aura donc des effets justes. Puis les effets : G-45 (vol de précision), G-77 (pose du TARDIS porté), G-80 (TardisRotation). C-196 change les bornes de reglerTaille : à recenser dans le schéma de la V8.

### V7.8.7 — Nouveaux modes de voyage

**Objectif :** Ajouter des modes et compléter ceux qui existent : Micro-saut, Blindé, voyages plus courts pour un petit TARDIS, Silencieux et Sauvetage aussi en vol libre.

- **C-1. Protocole Silencieux en vol libre** *(petit)* : En vol libre, la démat et la remat (changerPhaseVol dans VolLibre) ne tiennent compte que de l'Urgence et du Rapide. Avec le protocole Silencieux choisi, elles se feraient sans son ni effet dehors, comme un voyage Silencieux.
- **C-2. Sauvetage depuis le vol libre avec Atterrir ici** *(moyen)* : En protocole Sauvetage, la touche N (Atterrir ici) poserait la cabine en tournant sur elle-même et ouvrirait les portes, comme atterrir() le fait pour un voyage Sauvetage.
- **C-25. Petit TARDIS : voyages plus courts** *(moyen)* : Quand le TARDIS est rétréci (Echelle sous 1), Config.Timing raccourcirait la démat et la remat, avec le son coupé en fondu comme pour le Rapide.
- **C-21. Nouveau mode Micro-saut pour les petits déplacements** *(moyen)* : Un mode de démat et remat très courtes, sans passage par le vortex, permis seulement à moins de 60 studs. Pas de recharge, mais impossible plus loin.
- **C-23. Nouveau mode Blindé, lent mais protégé** *(moyen)* : Démat et remat 50 % plus longues, mais la cabine ne prend aucun dégât pendant la remat et les 10 secondes qui suivent. Pour arriver dans une zone de combat.

**Dans Studio :** Facultatif : des sons pour le Micro-saut et le Blindé dans TardisAssets > Sons (sinon ceux du Rapide et du Classique).

*Pourquoi ici :* Ce lot touche Config.Modes, Config.Timing, modeAutorise et changerPhaseVol : c'est un socle commun. Il passe donc avant la V7.8.8, qui donne à chaque mode sa couleur sur la console et le rotor. C-1 et C-2 complètent le vol libre (VolLibre.lua). C-25 raccourcit les temps quand Echelle est sous 1. C-21 et C-23 (nouveaux modes) passent à la fin : chaque mode doit avoir sa couleur, ses sons et sa place dans les menus et la tablette. Lot placé dans la seconde moitié de la sous-version, car il touche le cœur du voyage.

### V7.8.8 — Console : couleurs du mode et rotor

**Objectif :** Montrer sur la console le mode du prochain voyage et l'état de la recharge : anneau de couleur, recharge visible, chenillard des boutons, texte de l'écran coloré, rotor propre à chaque mode.

- **G-114. Texte de l'écran à la couleur du mode** *(petit)* : Pendant un voyage, le texte de l'écran de la console prend la couleur du mode (bleu Classique, rouge Urgence, vert Rapide, violet Silencieux), puis revient à la normale une fois posé.
- **G-127. Rotor qui tourne pendant le Sauvetage** *(petit)* : Pendant la descente en tournant du Sauvetage, les pièces intérieures du rotor tournent sur elles-mêmes au même rythme que la cabine dehors.
- **G-128. Rotor presque immobile en Silencieux** *(petit)* : En Silencieux, le rotor monte et descend très lentement avec une course réduite, en accord avec son violet discret.
- **G-167. Couleur du mode qui quitte le rotor** *(petit)* : À l'atterrissage, la couleur du mode se vide du rotor de bas en haut, comme un liquide qui s'écoule, au lieu du fondu uniforme d'aujourd'hui (melangeRotor dans TardisEffets).
- **G-110. Anneau de couleur du mode choisi** *(moyen)* : Avant le départ, un anneau autour du levier prend la couleur du mode du prochain voyage (Config.Modes[mode].CouleurRotor) : l'équipage voit si on part en Urgence ou en Rapide.
- **G-109. Recharge du levier visible sur la console** *(moyen)* : Après un voyage, un anneau autour du levier se remplit pendant Config.Cooldown et la recharge du Rapide, puis passe au vert quand on peut repartir.
- **G-111. Chenillard des boutons pendant la démat** *(moyen)* : Pendant la démat et la remat, les petits néons de la console s'allument l'un après l'autre autour du pupitre, plus vite en Urgence, plus lentement en Silencieux.

**Dans Studio :** Facultatif : une Part « AnneauLevier » autour du levier de vol. Sans elle, le code crée l'anneau. Nommer les petits néons de la console s'ils doivent s'allumer dans un ordre précis (G-111).

*Pourquoi ici :* Ce lot suit la V7.8.7 : les nouveaux modes ont alors leur CouleurRotor, et l'anneau (G-110) et le texte (G-114) les montrent tout de suite. G-127, G-128 et G-167 changent melangeRotor et la course du rotor dans TardisEffets. G-109 lit Config.Cooldown et la recharge du Rapide, que la V7.7.1 a changée (C-121). Tout est côté client. Ces repères seront à reprendre avec la console de la V12 : voir les remarques.

### V7.8.9 — Départs et arrivées interrompus

**Objectif :** Faire que le voyage puisse être dérangé : coupure de courant pendant la remat, démat interrompue par une explosion, technicien qui stabilise un paradoxe, TARDIS saisi immobilisé.

- **C-26. Coupure de courant pendant la remat** *(moyen)* : atterrir() ne vérifie l'alimentation qu'au début. Couper le courant pendant la remat l'arrêterait et renverrait le TARDIS dans le vortex.
- **C-28. Démat interrompue par une explosion** *(moyen)* : Une explosion qui touche la cabine pendant la démat la ferait échouer : la cabine réapparaît et il faut relancer le départ.
- **C-54. Un technicien peut stabiliser un paradoxe** *(moyen)* : Pendant les 15 s de confirmation, un technicien qui maintient E sur le rotor diviserait par deux les dégâts de la Catastrophe. La C.T.A.T. a un rôle en vol.
- **C-94. TARDIS saisi immobilisé au point ZDC** *(moyen)* : Après une saisie, portes verrouillées et démarrage bloqué jusqu'à ce qu'un pilote maintienne E quelques secondes sur la console.

**Dans Studio :** Rien.

*Pourquoi ici :* Ces règles touchent le cœur de decoller et atterrir (TardisServeur) et la saisie ZDC (TardisExtras). Elles sont moyennes et risquées : un voyage interrompu ne doit jamais laisser le TARDIS occupé ou bloqué, d'où les simulations de la V7.1.2 et la place tardive. C-26 et C-28 créent un seul chemin « départ ou arrivée annulés », que la 11 (annuler un départ, V11.3) pourra réutiliser. C-54 ajoute une invite sur le rotor pendant les 15 s de confirmation. C-94 bloque le démarrage après une saisie jusqu'au maintien de E sur la console.

### V7.8.10 — Vortex : en sortir, y entrer

**Objectif :** Relier le vortex et le reste du jeu : portes ouvrables dans le vortex, retour seul si plus aucun pilote, rappel depuis le vortex, fuite vers un lieu sûr, passage du vol libre au vortex et retour.

- **C-34. Vortex abandonné : retour au point de départ** *(petit)* : Si plus aucun pilote n'est en ligne pendant que le TARDIS est dans le vortex, il reviendrait seul à son point de départ (precedent). En partie là pour le vol libre seulement.
- **C-92. Rappel possible depuis le vortex** *(petit)* : Le Rappel exige un TARDIS posé. Depuis le vortex, il irait directement se poser près du pilote.
- **C-95. Fuite devant une anomalie vers un lieu sûr** *(petit)* : Une anomalie à moins de 10 studs envoie le TARDIS dans le vortex jusqu'à l'action d'un pilote. Il irait plutôt se poser sur la destination ACCORDE la plus proche hors de sa portée.
- **C-35. Portes ouvrables dans le vortex** *(moyen)* : Dans le vortex classique, un pilote pourrait ouvrir les portes : les passagers voient le vortex, et celui qui saute réapparaît au spawn.
- **C-79. Passer du vol libre au voyage classique** *(moyen)* : Une touche ferait entrer le TARDIS dans le vortex classique depuis le vol libre ; on choisit ensuite une destination et on clique sur REMAT.
- **C-80. Rematérialiser en vol libre au-dessus d'une destination** *(moyen)* : L'inverse : depuis le vortex, la remat se ferait en l'air au-dessus de la destination, et le pilote continue en vol libre.

**Dans Studio :** Rien.

*Pourquoi ici :* C-34, C-92 et C-95 sont de petites règles dans TardisServeur et TardisExtras : elles passent d'abord. C-35 ouvre les portes dans le vortex : il faut vérifier la vue par la porte (V7.3.5) et le saut au spawn. C-79 et C-80 (moyens) relient le vol libre (VolLibre.lua) et le vortex classique : ils créent deux nouvelles actions et changent l'état du TARDIS entre deux systèmes, d'où leur place tardive, après la V7.8.9 qui a sécurisé les interruptions.

### V7.8.11 — Nouvelles destinations

**Objectif :** Ajouter des destinations nouvelles : balises posées par les pilotes, accord du joueur visé, véhicule occupé, objet qui bouge, et chute du TARDIS si son véhicule disparaît.

- **C-43. Balises de navigation posées par les pilotes** *(moyen)* : Un pilote marque l'endroit où il se tient : il devient une destination pendant 30 minutes. Différent du point de Base, qui est unique et permanent.
- **C-46. Accord du joueur avant un atterrissage sur lui** *(moyen)* : En « Sur lui », le joueur visé recevrait une demande accepter ou refuser ; sans réponse en 10 s, le TARDIS arrive à sa dernière position, sans le figer.
- **C-47. Voyage vers un véhicule occupé** *(moyen)* : Une nouvelle destination : un VehicleSeat avec quelqu'un dessus ; la cabine se pose à côté. La formation sait déjà viser les véhicules, pas le voyage.
- **C-144. Véhicule porteur perdu : le TARDIS tombe** *(petit)* : Posé sur un véhicule (vehiculeSuivi), si le véhicule est détruit ou disparaît, le TARDIS chute au sol et prend des dégâts de chute au lieu de rester en l'air.
- **C-99. Atterrir sur un objet qui bouge** *(gros)* : Une destination non ancrée (plate-forme, train, véhicule) : la cabine se fixerait dessus et suivrait ses mouvements.

**Dans Studio :** Pour tester C-99 et C-144 : une plate-forme qui bouge, un train ou un véhicule non ancré dans la place de test.

*Pourquoi ici :* Ce lot vient après la V6.9.11 (8, point de base ; 1, favoris), qui a changé la liste des destinations. C-43 et C-46 ajoutent des actions réseau (poser une balise, accepter ou refuser). C-47 réutilise la visée des véhicules de la formation. C-144 (le TARDIS tombe si le véhicule disparaît, vehiculeSuivi) passe avant C-99 : il fixe ce qui se passe quand le support disparaît. C-99 (gros) attache la cabine à un objet qui bouge : c'est le plus risqué de la V7, placé seul à la fin des règles de voyage.

## V7.9 — Équipage, visiteurs et RP (7 lots, 45 propositions)

Mieux gérer les rôles, les visiteurs, les interfaces de poste, les gestes et outils de l'équipage, le carnet et les balises.

### V7.9.1 — Équipage : rôles, droits et reconnexion

**Objectif :** Rendre la gestion des rôles plus claire : raison de bannissement, pilotes temporaires limités, technicien temporaire, rôle prolongé, fin annoncée, joueur prévenu, bannissement d'un absent, retour à bord après une coupure.

- **C-204. Pilotes temporaires sans droit de promouvoir** *(petit)* : Un pilote promu pour une durée (TardisPiloteTemp_) ne pourrait plus promouvoir, bannir ni lancer l'auto-destruction : seuls les pilotes de la config, d'Adonis ou de la WL le peuvent. Aujourd'hui un pilote temporaire peut en nommer d'autres en chaîne.
- **C-208. Joueur prévenu quand ses droits changent** *(petit)* : Quand verifierAcces donne ou retire un accès (rang Adonis, WL, entrée ou sortie de la C.T.A.T.), le joueur reçoit un message clair. Aujourd'hui le changement est silencieux et le joueur ne comprend pas pourquoi la tablette change.
- **C-210. Fin d'un rôle temporaire annoncée à l'avance** *(petit)* : Cinq minutes avant la fin d'un rôle ou d'un bannissement (boucle publierRoles), le joueur concerné et le pilote qui l'a donné sont prévenus. Le RP ne s'arrête plus d'un coup en plein vol.
- **C-209. Prolonger un rôle temporaire sans le refaire** *(petit)* : Un bouton « +30 min » sur chaque rôle en cours du menu Équipage ajoute du temps à entree.fin. Plus besoin de retirer puis redonner le rôle.
- **C-206. Technicien temporaire nommé par un pilote** *(petit)* : Le menu Équipage proposerait « Technicien pour… » à côté de « Pilote pour… », avec les mêmes durées (Config.DureesRoles). Un joueur de passage peut ainsi aider aux réparations sans entrer dans la C.T.A.T.
- **C-202. Raison obligatoire pour un bannissement** *(petit)* : Le pilote choisit une raison (liste courte dans TardisConfig) en bannissant ; elle est montrée au banni, gardée dans roles.bans et envoyée au journal. Cela évite les bannissements sans explication.
- **C-211. Bannir un joueur absent par son pseudo** *(moyen)* : Le menu Équipage accepterait un pseudo de joueur hors ligne (Players:GetUserIdFromNameAsync) pour le bannir à l'avance. Aujourd'hui seule une personne connectée peut être bannie.
- **C-233. Reconnexion à bord après une coupure** *(moyen)* : Un membre de l'équipage qui se déconnecte à bord et revient dans les 5 minutes réapparaît dans le TARDIS, même s'il a voyagé. Le RP continue malgré une coupure de connexion.

**Dans Studio :** Rien. La liste courte des raisons de bannissement va dans TardisConfig.

*Pourquoi ici :* Tout passe par TardisExtras (roles, publierRoles, menu Équipage) et TardisSupervision (verifierAcces). C-204 passe en premier : il limite ce que peut faire un pilote temporaire, avant d'ajouter de nouveaux rôles temporaires (C-206) et la prolongation (C-209). C-202 range la raison dans roles.bans : la V7.9.2 (bannissement à la porte) et la V7.10.1 (bannissements partagés entre serveurs) s'en servent. C-211 appelle GetUserIdFromNameAsync, qui peut échouer. C-233 (moyen) garde 5 minutes la place d'un membre déconnecté à bord, dans la même table des joueurs de TardisExtras, et le refait apparaître dans le TARDIS même s'il a voyagé : il passe en dernier. Le menu Équipage est dans T, qui disparaîtra en V12 : seule la logique serveur restera.

### V7.9.2 — Visiteurs à bord : accès et expulsions

**Objectif :** Mieux gérer les visiteurs : banni repoussé à la porte, liste des clandestins au départ, armes rangées à l'entrée, délai après expulsion, expulsion reportée à l'atterrissage, portes fermées en maintenance, uniformes réservés.

- **C-201. Bannissement qui interdit aussi l'entrée à bord** *(moyen)* : En partie là : aujourd'hui TardisBanni_<nom> retire seulement les droits de pilote (TardisServeur, verifierJoueur). Le banni serait aussi repoussé à la porte, expulsé s'il est déjà à bord, et l'invitation lui serait refusée.
- **C-221. Délai avant de remonter après expulsion** *(petit)* : Un joueur expulsé (fonction expulser) ne peut pas repasser la porte pendant une minute ; il est renvoyé dehors avec un message. Sans cela, l'expulsion ne sert presque à rien.
- **C-223. Expulsion reportée à l'atterrissage** *(petit)* : Si le TARDIS est en vol ou dans le vortex, l'expulsion attend qu'il soit posé (aujourd'hui le joueur est envoyé près de la cabine cachée). Le pilote est prévenu que l'expulsion aura lieu à l'arrivée.
- **C-224. Liste des passagers clandestins au décollage** *(petit)* : Au moment de la démat, les pilotes reçoivent la liste des joueurs à bord qui ne sont pas de l'équipage (table dedans de TardisExtras). Personne ne voyage plus sans que le pilote le sache.
- **C-163. Maintenance : portes fermées aux visiteurs** *(petit)* : Pendant la maintenance, seuls les pilotes et techniciens peuvent entrer.
- **C-220. Armes des visiteurs rangées à l'entrée** *(moyen)* : Les outils d'un visiteur qui entre sont rangés dans un casier invisible et rendus à la sortie (boucle du registre). L'équipage garde les siens, ce qui limite les fusillades à bord.
- **C-232. Uniformes des casiers réservés à l'équipage** *(petit)* : Une marque equipage = true sur certaines tenues de Config.Tenues : seuls les C.A.T. et C.T.A.T. peuvent les prendre au casier (action Tenue). Un Classe D ne peut plus se déguiser en membre de l'équipage.

**Dans Studio :** Rien. Le casier invisible des armes (C-220) est un dossier créé par le code dans ServerStorage.

*Pourquoi ici :* Tout passe par la boucle du registre de TardisExtras (table dedans, expulser) et la porte. C-215 (l'équipage ne déclenche plus d'intrusion) est déjà fait en V7.1.1. C-201 vient après la V7.9.1, qui a posé la raison du bannissement. C-221 et C-223 complètent l'expulsion. C-220 est le plus délicat : il faut rendre les outils à coup sûr, même si le joueur quitte ou meurt à bord. C-232 vient après la V6.9.14 (63 garde-robe par catégorie, 90 uniformes). La sonnette et la liste d'invités viendront avec la 93 en V11.5.

### V7.9.3 — Tablettes et postes : petits raccourcis

**Objectif :** Rendre les interfaces plus simples : Y ferme aussi la tablette, touches F1 à F3, tablette technicien lisible sur téléphone, destination cachée aux visiteurs, copilote qui quitte son poste.

- **M-102. La touche Y ferme aussi la tablette** *(petit)* : Aujourd'hui Y ne fait qu'ouvrir (Volet : « Seule la croix rouge la ferme »). Une deuxième pression la fermerait, comme on s'y attend.
- **M-105. Touches F1 F2 F3 vers le volet** *(petit)* : Tablette ouverte, F1 ouvre l'aide, F2 la grille des outils et F3 les réglages (V.ouvrir), sans viser les petits boutons de l'en-tête.
- **C-243. Le copilote quitte son poste lui-même** *(petit)* : Un bouton « Quitter le poste » sur le panneau du copilote (TardisExtrasClient › Copilote). Aujourd'hui il doit sortir du TARDIS ou attendre qu'un pilote le relève.
- **C-228. Destination cachée aux visiteurs** *(petit)* : Dans la tablette en lecture seule (TabletteLecture), la destination et la position s'affichent « inconnues » pour les visiteurs. Seul l'équipage sait où va le TARDIS, ce qui sert le RP d'enlèvement ou de mission secrète.
- **M-201. Tablette technicien adaptée aux téléphones** *(moyen)* : La tablette (TabletteTechnicien) a une taille fixe de 1040 × 664 px : sur téléphone, l'échelle descend à 0,4 et les textes de 10 px deviennent illisibles. Sous 700 px de large, elle passe en deux onglets (Systèmes / Interventions) empilés.

**Dans Studio :** Rien. Tester M-201 avec l'émulateur de téléphone de Studio.

*Pourquoi ici :* Ce lot vient après la V6.9.15 (78, fermer la tablette d'un clic à côté ; 72, taille de l'interface), qui touche Volet et les mêmes ouvertures. M-102 et M-105 sont dans Volet (tablette Y). C-243 ajoute un bouton au panneau Copilote et une action serveur. C-228 masque deux champs dans TabletteLecture. M-201 (moyen) réorganise TabletteTechnicien en deux onglets sous 700 px. M-102, M-105, C-228 et C-243 servent jusqu'à la V12, qui retire T et Y : voir les remarques.

### V7.9.4 — Équipage : gestes et tenue

**Objectif :** Montrer qui fait quoi à bord : tablette visible dans les mains, pilote aux commandes en vol libre, geste au levier, copilote penché, écusson sur la manche, retour à sa tenue d'origine.

- **C-185. Casier : retrouver sa tenue d'origine** *(petit)* : appliquerTenue remplace le haut et le bas sans retour possible. Un choix « Ma tenue » remet ceux d'avant.
- **G-244. Écusson d'équipe sur la manche** *(petit)* : Un petit écusson C.A.T. ou C.T.A.T. (SurfaceGui) sur le bras gauche, quelle que soit la tenue portée.
- **G-254. Copilote penché sur son poste** *(petit)* : Quand le poste du copilote est ouvert, son personnage se penche en avant, mains posées, comme s'il réglait la navigation.
- **G-251. Tablette visible dans les mains** *(moyen)* : Quand un pilote ouvre la tablette (Y), les autres voient une tablette 3D dans ses mains, avec un écran qui éclaire son visage.
- **G-252. Pilote aux commandes en vol libre** *(moyen)* : Le personnage du pilote est figé (racine.Anchored). Il aurait plutôt une pose mains sur la console, regard levé.
- **G-253. Geste au levier de la console** *(moyen)* : Quand un pilote actionne une commande de la console, son bras pousse le levier un court instant. Les passagers voient qui a lancé le voyage.

**Dans Studio :** Facultatif : un modèle de tablette dans TardisAssets (G-251). Les emblèmes des équipes de la V6.9.14 (89) servent aussi à l'écusson (G-244).

*Pourquoi ici :* Ce lot vient après la V6.9.14 (63 garde-robe, 89 badges, 90 uniformes) : C-185 garde la tenue d'avant dans appliquerTenue (TardisExtras), et G-244 réutilise l'image d'emblème des badges. Les gestes (G-251 à G-254) sont des animations locales ou par Motor6D, lancées par des états qui existent déjà (tablette ouverte, pilotage, poste du copilote). G-252 remplace la pose figée de racine.Anchored en vol libre : à faire après la V7.6.3, qui a touché le pilotage.

### V7.9.5 — Outils du technicien en 3D

**Objectif :** Rendre les outils de la C.T.A.T. crédibles : vrais modèles 3D, ceinture à outils visible, animation de réparation au rotor, gestes propres à chaque outil.

- **G-247. Outils avec un vrai modèle 3D** *(moyen)* : donnerOutil crée de simples blocs de couleur. Des modèles rangés dans TardisAssets › Outils rendraient la visseuse ou l'extincteur crédibles.
- **G-246. Ceinture à outils visible des techniciens** *(moyen)* : Le chiffon, la visseuse, la clé et l'extincteur sont accrochés à la taille quand ils ne sont pas en main. On reconnaît un technicien de loin.
- **G-248. Animation de réparation au rotor** *(moyen)* : Pendant les 5 secondes où l'on maintient E sur le rotor, les bras se tendent et bougent, avec quelques étincelles à la main.
- **G-249. Gestes propres à chaque outil** *(moyen)* : Le chiffon frotte en cercles, la visseuse tourne en crachant des étincelles sur la grille, la clé à molette pivote sur la vanne.

**Dans Studio :** À construire : des modèles dans TardisAssets > Outils (chiffon, visseuse, clé à molette, extincteur, et le scanner et le soudeur de la V6.9.13).

*Pourquoi ici :* Ce lot vient après la V6.9.13 (127 scanner, 128 soudeur), pour que tous les outils aient leur modèle en même temps. G-247 passe en premier : donnerOutil (TardisSystemes) prend le modèle s'il existe, sinon garde les blocs actuels (la simulation des pièces manquantes de la V7.1.2 le vérifie). G-246 accroche ces modèles à la taille. G-248 et G-249 sont des animations jouées pendant les maintiens déjà existants (rotor, grille, vanne). C-242 (outils retirés à la perte du rôle) est déjà fait en V7.1.1.

### V7.9.6 — Carnet de bord : notes et fusion

**Objectif :** Rendre le carnet de bord plus riche et plus sûr : rubrique technique, notes épinglées, étiquettes, notes confidentielles, et plus aucune note perdue entre deux serveurs.

- **C-248. Rubrique de la C.T.A.T. dans le carnet** *(petit)* : Les techniciens pourraient écrire des notes marquées « technique » dans le carnet (peutEcrireCarnet). Les réparations et l'état des systèmes laissent une trace RP.
- **C-249. Notes épinglées en tête du carnet** *(petit)* : Un pilote peut épingler une note importante (consigne, danger) : elle reste en haut et ne part jamais avec la limite de Config.Carnet.Max.
- **C-250. Étiquettes sur les notes du carnet** *(petit)* : Chaque note reçoit une étiquette (Danger, Contact, Indice, Mission) choisie dans une liste. Le carnet se trie et se lit plus vite.
- **C-253. Notes confidentielles réservées aux pilotes** *(petit)* : Une case « confidentiel » à l'écriture : la note n'est montrée qu'aux pilotes, même si le carnet devient lisible par d'autres. Utile pour les secrets RP.
- **T-8. Carnet de bord fusionné entre serveurs** *(moyen)* : Le carnet est sauvegardé comme une liste complète : deux serveurs qui ajoutent chacun une note perdent celle de l'autre. Fusionner les notes par auteur et par date dans UpdateAsync garde tout.

**Dans Studio :** Rien. Pour T-8, tester sur la place publiée avec deux serveurs ouverts.

*Pourquoi ici :* Tout est dans TardisExtras (carnet, peutEcrireCarnet) et le poste du copilote. C-248, C-249, C-250 et C-253 ajoutent des champs aux notes : ils passent ensemble pour ne changer le format des notes qu'une fois. T-8 vient ensuite, car la fusion par auteur et par date dans UpdateAsync doit connaître le format final. C'est le premier lot qui change une sauvegarde : il est placé tard, après les sous-versions surtout visuelles.

### V7.9.7 — Balises, sentinelle et anomalies

**Objectif :** Rendre les alertes plus utiles : balise avec motif, prise en charge, appelant prévenu, balise qui suit le joueur, balises abusives bloquées, pannes envoyées aux techniciens, sentinelle plus fine.

- **C-255. Balise de détresse avec un motif** *(petit)* : « /tardis help blessé » ou « /tardis help poursuivi » : le motif, filtré par Roblox, s'affiche aux pilotes avec la balise (TardisSupervision.commande puis allumerBalise). Les pilotes savent quoi préparer.
- **C-256. Balise prise en charge par un pilote** *(petit)* : Quand un pilote appuie sur Y ALLER, les autres pilotes voient « prise en charge par X » et l'appelant reçoit « un TARDIS arrive ». Plus deux pilotes qui partent pour la même balise.
- **C-261. Balise qui suit le joueur appelant** *(petit)* : La position de la balise se met à jour toutes les quelques secondes tant qu'elle est allumée (aujourd'hui elle reste où le joueur était). Un joueur en fuite peut être retrouvé.
- **C-259. Balise : TARDIS indisponible annoncé à l'appelant** *(petit)* : Si tous les TARDIS sont en maintenance, détruits ou sans pilote en ligne, l'appelant de /tardis help l'apprend tout de suite au lieu d'attendre 5 minutes pour rien.
- **C-260. Bloquer les balises abusives d'un joueur** *(petit)* : Un pilote peut ignorer les balises d'un joueur pour la session depuis la liste des balises. Un joueur qui spamme /tardis help ne dérange plus les pilotes des 3 TARDIS.
- **C-275. Pannes signalées aux techniciens en ligne** *(petit)* : Les pannes (vapeur, incendie, coupure) sont envoyées aux techniciens de ce TARDIS où qu'ils soient, pas seulement aux pilotes (direAuxPilotes dans TardisSystemes). La C.T.A.T. peut venir sans être appelée.
- **C-149. Sentinelle qui verrouille les portes (option)** *(petit)* : Quand un inconnu entre dans le rayon, les portes se verrouillent seules ; elles se déverrouillent quand il s'éloigne.
- **C-150. Sentinelle qui reconnaît les SCP** *(petit)* : Message et alerte plus forts quand c'est une entité ou un joueur SCP qui approche (estEntiteHostile existe déjà côté serveur).
- **C-154. Sentinelle qui signale aussi les véhicules** *(petit)* : La sentinelle ne regarde que les joueurs à pied. Un véhicule occupé (VehicleSeat) qui approche serait signalé aussi, avec sa vitesse.
- **C-286. Anomalies : équipes et PNJ configurables** *(petit)* : La détection d'anomalies prend aujourd'hui toute équipe qui commence par « SCP » et tous les PNJ avec Humanoid. Une liste d'équipes et un attribut TardisAmi sur les PNJ éviteraient les démat pour rien.

**Dans Studio :** Facultatif : un attribut TardisAmi sur les PNJ alliés (C-286). La liste des équipes surveillées va dans TardisConfig.

*Pourquoi ici :* Les balises sont dans TardisSupervision (commande /tardis help) et TardisExtras (allumerBalise) : C-255 (motif filtré par Roblox) passe en premier, puis C-256, C-261, C-259 et C-260. C-275 vient après la V6.9.12 (125, signalerPanne), qu'il étend aux techniciens. La sentinelle et les anomalies suivent : C-286 d'abord (liste d'équipes et TardisAmi), puis C-149, C-150 et C-154. C-259 et C-260 sont pensés pour 3 TARDIS mais marchent déjà avec un seul.

## V7.10 — Sauvegarde et plusieurs TARDIS (3 lots, 19 propositions)

Revoir la sauvegarde et le partage entre serveurs, puis préparer et relier plusieurs TARDIS avant la V11.

### V7.10.1 — Sauvegarde et serveurs

**Objectif :** Revoir la sauvegarde : un seul profil par joueur, des préférences communes aux trois TARDIS, des réglages et des données gardés entre les sessions, et des bannissements partagés en direct.

- **C-298. Distance parcourue en vol comptée** *(petit)* : Les statistiques ajoutent la distance parcourue en voyage et en vol libre, à côté du temps de vol déjà compté (TardisExtras, Heartbeat). Un chiffre de plus pour le futur onglet Statistiques.
- **C-198. Réglages techniques et saleté gardés** *(petit)* : Régulations de l'énergie, de l'air et de la vapeur, et saleté, repartent à zéro à chaque serveur. Les sauvegarder.
- **C-199. Dossiers d'incident gardés entre les sessions** *(petit)* : Les fiches d'intrusion (ajouterIncident) ne vivent que pendant la session. Les sauvegarder (40 dernières).
- **C-197. Reprendre la dernière position au démarrage (option)** *(petit)* : Au lancement, le TARDIS reste à sa place de Studio. Option pour qu'il réapparaisse là où il était posé.
- **T-3. Un seul profil sauvegardé par joueur** *(moyen)* : Les statistiques, la découverte et les préférences sont trois clés séparées, et chaque TARDIS les relit : cela fait 2 à 3 lectures DataStore par joueur et par TARDIS à chaque arrivée. Une seule clé « profil » par joueur divise les requêtes et se sauvegarde d'un bloc.
- **T-2. Préférences communes à tous les TARDIS** *(moyen)* : Aujourd'hui, chaque exemplaire de TardisExtras lit et écrit « prefs_<UserId> » dans son propre magasin (TardisExtras_v2_<Nom>). Avec 3 TARDIS, on aurait 3 copies qui se marchent dessus : un seul magasin « joueurs » pour tous évite ce conflit.
- **T-7. Bannissements transmis en direct aux autres serveurs** *(moyen)* : Un bannissement ou une promotion n'est connu des autres serveurs qu'à leur redémarrage. Un message MessagingService à chaque changement de rôle l'applique partout en quelques secondes.

**Dans Studio :** Activer « Enable Studio Access to API Services » pour tester DataStore et MessagingService. Tester sur la place publiée, avec deux serveurs ouverts pour T-7.

*Pourquoi ici :* C'est le lot le plus sensible pour les données : il passe à la fin, après tous les lots qui ajoutent des préférences ou des statistiques (C-298 ajoute la distance parcourue). C-198, C-199 et C-197 ajoutent des données à sauver par TARDIS. T-3 (un seul profil) puis T-2 (préférences communes) changent les clés : il faut lire les anciennes clés prefs_, stats et découverte et les recopier, sans rien perdre. T-7 (MessagingService) passe en dernier et applique tout de suite les bannissements de la V7.9.1. Juste après, la V8 protègera cette sauvegarde (168, taille et schéma) : le format doit donc être fixé ici.

### V7.10.2 — Préparer les 3 TARDIS

**Objectif :** Préparer l'arrivée de trois TARDIS : simulations avec les trois déclarés, mesure de ce que couvrent les tests, couleur de lampe et point de vortex propres à chacun, destinations et pilotes réservés.

- **T-203. Simulation avec les trois TARDIS déclarés** *(moyen)* : Lancer les simulations avec TARDIS_2 et TARDIS_3 actifs dans Config.Tardis pour vérifier Config.demarrerPourChaqueTardis, Config.canal et les scripts clonés avant la V10.
- **T-207. Mesure de ce que couvrent les simulations** *(moyen)* : luau.py note les lignes exécutées et un rapport montre les scripts et fonctions jamais testés : on sait où ajouter des simulations au lieu de deviner.
- **G-93. Couleur de lampe propre à chaque TARDIS** *(petit)* : Pour la V10 (un TARDIS par pilote), une couleur de lampe et d'effets par TARDIS dans Config.Tardis permet de distinguer TARDIS_1, 2 et 3 de loin, sans plaque.
- **C-37. Position de vortex propre à chaque TARDIS** *(petit)* : Config.PositionCiel est la même pour tous : avec trois TARDIS en vol (V10), ils se superposent dans le ciel. Chaque TARDIS aurait son propre point de vortex.
- **C-42. Destinations réservées à un seul TARDIS** *(petit)* : Un attribut Tardis = « TARDIS_1 » sur une Part : les autres TARDIS ne la voient pas et ne peuvent pas s'y poser (utile en V10).
- **C-187. Personnalisation réservée au pilote attitré** *(petit)* : Avec un TARDIS par pilote (V10), seul son pilote change couleurs, styles et enseigne.
- **C-213. Le titulaire choisit qui pilote son TARDIS** *(moyen)* : Avec la V10 (un TARDIS par pilote), le pilote titulaire pourrait limiter l'accès de son TARDIS aux seuls pilotes qu'il accepte. Les autres pilotes y restent des passagers.

**Dans Studio :** Rien d'obligatoire. Pour tester en jeu : déclarer TARDIS_2 et TARDIS_3 dans Config.Tardis.

*Pourquoi ici :* T-203 passe en premier : il lance les simulations avec TARDIS_2 et TARDIS_3 actifs, pour vérifier Config.demarrerPourChaqueTardis et Config.canal avant d'ajouter des réglages par TARDIS. T-207 mesure ce que les tests couvrent, à la fin de la V7 et avant la V8 (sécurité). G-93 et C-37 ajoutent des champs à Config.Tardis. C-42, C-187 et C-213 lisent « à quel TARDIS appartient ce pilote ou ce lieu » : ils seront vraiment utiles en V11 (un TARDIS par pilote), mais le propriétaire les veut en V7.

### V7.10.3 — Entre TARDIS : se voir, se rejoindre

**Objectif :** Faire interagir plusieurs TARDIS : arcs entre deux TARDIS proches, voyage vers un autre TARDIS, atterrissage rétréci dans un autre intérieur, camouflés visibles entre pilotes, remorquage d'un TARDIS en avarie.

- **C-48. Voyage vers un autre TARDIS** *(petit)* : Une destination « TARDIS_2 » : arrivée devant sa porte, à sa position du moment. Pour que les équipes se retrouvent (V10).
- **G-94. Arcs entre deux TARDIS proches en voyage** *(moyen)* : Si deux TARDIS se matérialisent à moins de 25 studs l'un de l'autre, des arcs bleus sautent entre leurs lampes. Chaque client a les trois exemplaires de TardisEffets.
- **C-146. TARDIS camouflés visibles entre pilotes** *(moyen)* : Pour la V10 : les pilotes d'un autre TARDIS voient une silhouette légère d'un TARDIS camouflé, pas les autres joueurs.
- **C-51. Atterrir dans un autre TARDIS, rétréci** *(moyen)* : Si le joueur visé est dans l'intérieur d'un autre TARDIS, la cabine s'y poserait rétrécie, au lieu d'arriver en taille réelle au milieu de sa salle.
- **C-200. Remorquer un TARDIS en avarie** *(gros)* : Quand il y aura 3 TARDIS : l'un peut tracter un TARDIS en avarie jusqu'à un lieu sûr avec son rayon tracteur.

**Dans Studio :** Au moins deux TARDIS complets dans la place de test (extérieur, intérieur, console).

*Pourquoi ici :* Ce lot suit la V7.10.2, qui a préparé les réglages par TARDIS. C-48 (destination « TARDIS_2 ») passe en premier, puis G-94 et C-146, qui ont besoin de savoir où sont les autres TARDIS. C-51 pose la cabine rétrécie dans un autre intérieur : il réutilise la taille (V7.8.6). C-200 (gros) réutilise le rayon tracteur (V7.6.5) et la poussée de C-84 pour tirer un TARDIS : c'est le plus risqué, en dernier. Tout ce lot serait plus simple après la V11 (3 TARDIS officiels) : voir les remarques.

## Remarques

- Effort compté ainsi : petit = 1, moyen = 2, gros = 3. Aucun lot ne dépasse 10 propositions ni l'équivalent de 10 petites.
- Numérotation : la feuille de route met encore la sécurisation en V7 dans son tableau du haut. Avec ce plan, V7 = « Modifications » (dix sous-versions V7.1.1 à V7.4.2, chacune découpée en sous-sous-versions), puis V8 sécurisation, V9 optimisation et nettoyage, V10 organisation des fichiers, V11 les 3 TARDIS, V12 la console. Les numéros cités dans ce plan pour les lots suivants (V11.1, V11.2, V11.3, V11.5, V11.6, V11.7) suivent la nouvelle numérotation.
- La V7.1.2 (banc d'essai des simulations) n'apporte rien de visible en jeu. Elle est placée tôt exprès, dans la première sous-version, pour servir de filet aux lots qui changent le serveur dans les sous-versions suivantes.
- Dépendances aux lots V6.9.x (ils sont tous avant la V7, donc l'ordre est déjà bon, mais il faut les avoir finis) : V6.9.9 pour V7.2.1 (vitres, couleurs de salle) et V7.2.2 (marque au sol) ; V6.9.10 pour V7.8.1, V7.6.1 et V7.6.3 (croisière, frein, caméra cinématique, son du vortex) ; V6.9.11 pour V7.8.4 et V7.8.11 (VITESSE_REDUITE, point de base, fiches) ; V6.9.12 pour V7.9.7 (C-275, signalerPanne) et V7.7.7 (C-169, liste pondérée des pannes) ; V6.9.13 pour V7.7.3 (C-105), V7.7.5 (fuite d'air) et V7.9.5 (modèles du scanner et du soudeur) ; V6.9.14 pour V7.9.2 (C-232) et V7.9.4 (C-185, G-244) ; V6.9.15 pour V7.4.1 et V7.9.3 (préférences, taille, fermeture de la tablette).
- V8 (sécurisation) : la V7 ajoute des actions réseau, qu'il faudra recenser dans le garde-barrière (156) et le schéma par action (157). Exemples : annuler l'auto-destruction (C-155), raison de bannissement et bannir un absent (C-202, C-211), technicien temporaire et prolongation (C-206, C-209), quitter le poste du copilote (C-243), étiquettes et notes confidentielles du carnet (C-249, C-250, C-253), balises (C-255, C-256, C-260), poser une balise de navigation et accepter un atterrissage (C-43, C-46), lancer le TARDIS porté (C-193), passer du vol libre au vortex (C-79, C-80), durée de maintenance (C-162), nouveaux modes (C-21, C-23), circuit caméléon (C-145), taille jusqu'à 1,5 (C-196). Les nouvelles préférences (G-279, G-280, C-222, option C-197) entrent dans le schéma Prefs et la protection de la sauvegarde (168). Le format de sauvegarde fixé en V7.10.1 est celui que la V8 protègera.
- V9 (optimisation) : plusieurs effets tournent à chaque image (G-14, G-111, G-131, G-140, G-163, G-168, G-207, G-267, G-291). Il faut les brancher sur les boucles qui existent déjà, pour que la V9 (177 boucles regroupées, 178 effets coupés loin du joueur) n'ait pas à les reprendre. G-168 (silhouettes par la porte) est le plus coûteux : à mesurer avec le compteur de la 181.
- V10 (organisation des fichiers) : les styles de régénération (G-227 à G-231), les poses par style (G-201) et les trajets de caméra par style (G-236) seraient plus simples une fois Regeneration.lua découpé par style. Ils sont gardés en V7, comme demandé, et seront déplacés dans les modules en V10.
- V11 (3 TARDIS) : G-93, G-94, C-37, C-42, C-48, C-51, C-52, C-146, C-187, C-200, C-213, T-2 et T-203 seraient nettement mieux faits après la V11. Ils sont gardés en fin de V7 (V7.10.1 à V7.10.3, et C-52 en V7.8.5), testables en déclarant TARDIS_2 et TARDIS_3 dans Config.Tardis. Ce qui est construit dans Studio sur TARDIS_1 pendant la V7 (Parts Cable, Gyrophare, Volant, Charniere des leviers, AnneauLevier) s'ajoute à la liste de contrôle de la V11.1.
- V11, lots déjà prévus qui touchent les mêmes choses : C-274 dépend vraiment du choix du style (102, V11.1) ; les nouveaux styles G-228 à G-231 rejoignent Cristal et Écho (103, 104) dans la même liste Config.Regeneration.Styles ; G-65, G-141 et G-220 (régénération à bord) touchent le même moment que la 115 (V11.2) ; C-264, C-265 et C-270 (vraie mort) demandent la même décision que la 107 (cycle ou vraie mort, V11.2) ; C-26 et C-28 (voyage interrompu) créent le chemin d'annulation que la 11 (V11.3) réutilisera ; C-215 ne règle que l'équipage, la liste d'invités viendra avec la 93 (V11.5) ; les grilles et la vanne (G-145, G-152) seront déplacées dans la salle des machines (58, V11.6) ; les nouvelles préférences iront dans le panneau « Mes réglages » (193, V11.7).
- V12 (la console remplace les menus) : les commandes et repères de la console (G-101, G-103, G-104, G-105, G-107, G-108, G-109, G-110, G-111, G-114) et la console de secours (C-131, C-188) seraient mieux faits avec la console de la V12. Ils sont gardés en V7 et serviront de base. À l'inverse, M-102 et M-105 (tablette Y), le menu Équipage de C-202, C-206, C-209 et C-211, la tablette en lecture seule de C-228, le panneau du copilote de C-243 et le bouton d'annulation de C-155 disparaîtront ou seront refaits en V12 : seule leur logique serveur restera. M-201 (tablette technicien) n'est pas dans T ni dans Y et devrait survivre.
- Décisions à prendre avant certains lots : la façon dont le jeu signale un orage (G-31, V7.2.4) ; une option pour couper le départ portes ouvertes de C-17 (V7.8.2), qui fait tomber des joueurs ; l'existence de la vraie mort (V7.5.5) ; C-97 (pilotage à distance réservé) coupé par défaut.
