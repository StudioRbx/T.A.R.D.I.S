# Plan de la V13 « Plus tard »

687 propositions mises « Plus tard » : 662 du second tri des 1200 (numéros T-, G-, M-, C-) et 25 du premier tri des 200 (numéros A-, par exemple A-5 = proposition 5 de [PROPOSITIONS_200.md](PROPOSITIONS_200.md)).
Rangées en 10 sous-versions et 112 sous-sous-versions de 10 propositions au plus. La V13 vient après tout le reste : V7 modifications, V8 sécurisation, V9 nettoyage, V10 fichiers, V11 les 3 TARDIS, V12 la console.

**Retrié le 06/11/2026** : 161 gardées, 9 encore plus tard, 17 abandonnées, 500 pas triées (elles restent ici). Le détail est dans [TRI_PLUS_TARD.md](TRI_PLUS_TARD.md) ; ce plan sera refait avec les gardées.

## V13.1 — Outils, tests et documentation (15 lots, 94 propositions)

Renforcer le banc d'essai, l'analyseur, la synchro et la documentation avant le reste de la V13, pour que chaque lot suivant soit vérifié pour de vrai.

### V13.1.1 — Banc d'essai plus fiable

**Objectif :** Vérifier l'interpréteur et les faux objets des simulations, puis ajouter des tests de référence sur TardisConfig et la sauvegarde.

- **T-211. Tests de l'interpréteur luau.py lui-même** *(petit)* : Un petit fichier qui vérifie que luau.py calcule juste (division entière, chaînes, continue, +=, closures) : si l'interpréteur se trompe, toutes les simulations se trompent avec lui.
- **T-210. Comparer luau.py avec le vrai Luau** *(moyen)* : Faire tourner les fonctions pures (TardisConfig, TardisCommandes) aussi avec l'exécutable officiel luau, gratuit et libre, pour repérer une différence entre l'interpréteur maison et le vrai langage.
- **T-212. Faux objets Roblox stricts sur les propriétés** *(moyen)* : roblox.py accepte n'importe quelle propriété. Refuser une propriété qui n'existe pas sur la classe (par exemple « Transparancy ») repère des fautes de frappe que Studio ne montrerait qu'en jeu.
- **T-208. Courbes des effets comparées à une référence** *(petit)* : Enregistrer une fois les valeurs de Config.Alpha, Config.Souffle et Config.lueurVitres pour chaque mode, puis vérifier à chaque version qu'elles n'ont pas changé sans le vouloir.
- **T-209. Fonctions de TardisConfig testées au hasard** *(petit)* : Appeler Config.Timing, Config.Alpha, Config.facteurHeure… avec des milliers de valeurs tirées au hasard (bords compris) et vérifier qu'elles ne plantent jamais et restent dans leurs bornes.
- **T-214. Données de test pour chaque format de sauvegarde** *(petit)* : Quand Sauvegarde.FORMAT augmente, exiger un exemple au format précédent et une simulation de MIGRATIONS[n] : l'outil refuse un nouveau format sans migration testée.
- **T-260. Nombre de messages réseau mesuré en simulation** *(moyen)* : Le faux RemoteEvent et les faux attributs comptent ce qui passe pendant un voyage simulé (messages par seconde, changements d'attributs) ; chaque version compare à la précédente pour voir tout de suite un envoi en trop.

**Dans Studio :** Rien : tout tourne hors de Roblox (outils/simulation).

*Pourquoi ici :* luau.py et roblox.py portent toutes les simulations : T-211 vérifie d'abord l'interpréteur lui-même, T-210 le compare au vrai Luau, T-212 rend les faux objets stricts sur les propriétés. Viennent ensuite les tests qui s'appuient dessus : courbes de référence (T-208) et tirages au hasard (T-209) sur Config.Alpha, Config.Timing, Config.facteurHeure ; exemple par format de sauvegarde (T-214), utile avant les lots de sauvegarde de la V13.2 ; comptage des messages réseau (T-260), pour mesurer les gains des V13.2 et V13.3. Ordre : T-211, T-210, T-212, puis les autres.

### V13.1.2 — Simulations longues et à plusieurs

**Objectif :** Simuler une panne du DataStore, une longue session, un joueur sur téléphone et deux joueurs ensemble.

- **T-86. Panne de DataStore simulée** *(moyen)* : Une simulation où le DataStore échoue (lecture, écriture, fermeture) vérifie qu'aucune sauvegarde n'est écrasée et que le TARDIS reste utilisable. Complète les simulations prévues, qui ne couvrent pas ces pannes.
- **T-249. Simulation d'une longue session de serveur** *(moyen)* : Faire tourner le faux monde 12 heures en temps virtuel (sauvegardes toutes les 60 s, rôles temporaires qui expirent, journal de 200 lignes, joueurs qui vont et viennent) et vérifier que le nombre d'objets et la taille des tables restent stables.
- **T-268. Simulation d'un joueur sur téléphone** *(moyen)* : Lancer les scripts clients avec un faux UserInputService tactile et sans clavier, pour vérifier que les boutons tactiles apparaissent et que le menu et la tablette restent accessibles sans touche T ni Y.
- **T-213. Simulation d'un pilote et d'un passager ensemble** *(gros)* : Deux faux clients dans le même faux monde, pour vérifier ce que voit chacun (portes, effets, boutons permis) quand le pilote agit.

**Dans Studio :** Rien : simulations hors de Roblox.

*Pourquoi ici :* Ces simulations demandent le banc de V13.1.1. T-86 (panne de DataStore simulée) passe en premier : il protège les lots de sauvegarde de la V13.2. T-249 fait tourner 12 h en temps virtuel (rôles qui expirent, sauvegardes, départs) et montrera les fuites que corrigent les V13.2 et V13.3. T-268 (faux téléphone) sert aux lots mobiles des V13.4 à V13.6. T-213 (pilote et passager dans le même faux monde) est le plus gros : en dernier.

### V13.1.3 — Analyseur : nouveaux contrôles

**Objectif :** Ajouter à analyse.py des contrôles sur les attentes, les appels risqués, les boucles de require, les connexions et le code inutilisé.

- **T-223. Avertissements classés et exceptions acceptées** *(petit)* : Classer les messages de l'analyseur en erreur, attention ou info, avec un fichier d'exceptions commentées : le rapport reste lisible et une vraie nouvelle alerte se voit.
- **T-221. Analyseur : WaitForChild sans délai maximum** *(petit)* : Lister les WaitForChild sans second argument, qui peuvent bloquer un script pour toujours si une pièce manque, pour leur donner un délai et un message.
- **T-222. Analyseur : appels risqués sans pcall** *(petit)* : Signaler les appels qui peuvent échouer sur le réseau (DataStore, HttpService, MarketplaceService, GetUserIdFromNameAsync…) faits hors d'un pcall.
- **T-220. Analyseur : modules qui se requièrent en boucle** *(petit)* : Repérer deux modules qui se require l'un l'autre (directement ou par un troisième) : dans Roblox, cela bloque sans message clair.
- **T-215. Analyseur : connexions jamais déconnectées** *(moyen)* : Repérer les :Connect faits dans une boucle ou une fonction appelée souvent, sans Disconnect ni Destroy : c'est la première cause de fuite de mémoire dans Roblox.
- **T-216. Analyseur : réglages définis mais jamais lus** *(petit)* : L'analyseur signale déjà les Config.X lus mais absents de TardisConfig ; il ferait aussi l'inverse (réglages que plus aucun script ne lit, comme Config.NomExterieur), pour que le code mort ne revienne pas.
- **T-217. Analyseur : attributs écrits que personne ne lit** *(petit)* : En miroir du contrôle « lus mais jamais écrits », lister les attributs posés par le code mais lus nulle part : réseau gaspillé ou reste d'une fonction retirée.

**Dans Studio :** Rien.

*Pourquoi ici :* Tout se passe dans outils/simulation/analyse.py. T-223 (messages classés erreur / attention / info, avec un fichier d'exceptions) passe d'abord, sinon les nouveaux contrôles noient le rapport. Puis WaitForChild sans délai (T-221) et appels réseau sans pcall (T-222) : leurs listes servent à T-44 et T-35 en V13.2. Modules qui se requièrent en boucle (T-220), connexions jamais coupées (T-215, guide des fuites de la V13.3). Enfin réglages et attributs que personne ne lit (T-216, T-217).

### V13.1.4 — Types, style et contrôles des fichiers

**Objectif :** Brancher les outils officiels (luau-analyze, Selene, StyLua) et vérifier l'encodage, les en-têtes et les identifiants d'assets.

- **T-224. Vérification des types avec l'outil officiel** *(moyen)* : Passer les scripts dans luau-lsp ou luau-analyze avec les définitions de Roblox, d'abord sans mode strict, pour attraper des erreurs que l'analyseur maison ne voit pas.
- **T-226. Contrôle de style avec Selene** *(petit)* : Un fichier selene.toml avec la bibliothèque Roblox, lancé dans les vérifications, repère les variables mal écrites, les comparaisons toujours vraies et les mauvais usages de l'API.
- **T-227. Mise en forme uniforme avec StyLua** *(moyen)* : Un fichier stylua.toml (tabulations, largeur de ligne) et une mise en forme faite une fois dans un commit à part, puis vérifiée : les différences entre versions ne montrent plus que le vrai changement.
- **T-242. Encodage et fins de ligne des fichiers vérifiés** *(petit)* : Un contrôle vérifie que chaque fichier de src/ est en UTF-8 valide, sans BOM, en fins de ligne LF et sans mélange d'espaces et de tabulations : l'empreinte du manifeste dépend de chaque octet, un éditeur qui change cela fait échouer la synchro.
- **T-225. Inventaire des identifiants Roblox utilisés** *(petit)* : Un outil liste tous les identifiants d'assets écrits dans src/ (sons de Config.Sons et Config.Jukebox, tenues de Config.Tenues, avatars, images) avec le fichier où chacun sert, dans docs/ASSETS.md : on sait quoi remplacer si un son devient privé, et quels droits donner à la place.
- **T-228. En-tête des fichiers vérifié par l'analyseur** *(petit)* : Chaque fichier commence par « -- Service > Nom (Type) » : vérifier qu'il correspond à l'emplacement et au type réels du manifeste, pour éviter un en-tête faux après un déplacement en V9.

**Dans Studio :** Rien.

*Pourquoi ici :* T-224 (luau-analyze avec les définitions Roblox, d'abord sans mode strict) est la condition des lots de typage strict (V13.2.16 et V13.3.14). Selene (T-226) puis StyLua (T-227) : la mise en forme StyLua se fait une fois, dans un commit à part, pour ne pas mélanger avec un vrai changement. T-242 (UTF-8, LF), T-225 (inventaire des identifiants de Config.Sons, Config.Jukebox, Config.Tenues) et T-228 (en-tête « Service > Nom » d'accord avec l'emplacement réel, qui a changé en V10) sont des contrôles courts.

### V13.1.5 — Outils de code : mesure et découpage

**Objectif :** Mesurer la taille des scripts, repérer le code recopié et réunir les outils Python sous une seule commande.

- **T-219. Rapport de taille et complexité par script** *(petit)* : Lignes, nombre de fonctions, plus longue fonction et imbrication maximale de chaque fichier, à chaque version : on voit si la V8 et la V9 allègent vraiment TardisServeur ou TardisExtras.
- **T-218. Analyseur : morceaux de code recopiés** *(moyen)* : Détecter les blocs d'une dizaine de lignes identiques dans plusieurs scripts, pour guider le partage de code en V8 et V9 au lieu de les chercher à la main.
- **T-298. Outils Python réunis sous une seule commande** *(moyen)* : python3 outils/tardis.py manifeste | paquet | release | tests | simulations | verifier : une seule entrée à retenir, avec une aide intégrée.
- **T-300. decouper.py capable de déplacer vers un autre dossier** *(gros)* : Pour la V9 (un dossier par domaine), permettre de sortir une section d'un script vers un module d'un autre dossier, avec les mêmes contrôles de sûreté qu'aujourd'hui.

**Dans Studio :** Rien.

*Pourquoi ici :* T-219 (lignes, fonctions, imbrication par script) et T-218 (blocs recopiés) montrent où le code reste lourd après les V9 et V10. T-298 réunit manifeste, paquet, release, tests et simulations sous python3 outils/tardis.py : à faire après les ajouts des lots précédents. T-300 (decouper.py vers un autre dossier) était pensé pour la refonte de la V10 : gardé pour les découpages qui restent, en dernier.

### V13.1.6 — Synchro sûre et traçable

**Objectif :** Rendre la synchro Studio prudente (aperçu, Ctrl+Z, copie de secours) et poser la version sur chaque script.

- **T-239. Place affichée dans le rapport de synchro** *(petit)* : Afficher game.PlaceId et le nom de la place en tête du rapport, et demander confirmation si ce n'est pas la place attendue : on ne met plus à jour ZONE-TSADE par erreur au lieu de la copie de test.
- **T-232. Mode aperçu de la synchro** *(petit)* : Une option APERCU = true en haut du script liste ce qui serait créé, mis à jour ou supprimé, sans rien écrire dans Studio.
- **T-230. Annuler toute la synchro par Ctrl+Z** *(petit)* : Entourer synchro_github.luau, synchro_studio.luau et installer_paquet.luau d'un point d'historique (ChangeHistoryService) : un seul Ctrl+Z remet Studio comme avant la mise à jour.
- **T-231. Copie de secours des scripts remplacés** *(petit)* : Avant de réécrire un script, la synchro range l'ancienne version dans ServerStorage › TardisAncienneVersion (vidé à la synchro suivante), pour comparer ou revenir en arrière.
- **T-237. Version posée sur chaque script installé** *(petit)* : La synchro ajoute à chaque script un attribut avec la version et le commit court : dans les Propriétés de Studio, on voit d'un coup d'œil d'où vient un script.
- **T-233. Repérer les retouches faites à la main** *(moyen)* : La synchro pose sur chaque script l'empreinte qu'elle a écrite ; si le script a changé depuis dans Studio, il est signalé « modifié à la main » au lieu d'être écrasé en silence.
- **T-269. Versions mélangées repérées au démarrage** *(moyen)* : Chaque script indique sa version (attribut posé par la synchro) ; le diagnostic avertit si un LocalScript ou un module vient d'une autre version que TardisServeur, après une synchro partielle.

**Dans Studio :** Lancer la synchro une fois en mode aperçu dans une copie de la place.

*Pourquoi ici :* Tout touche outils/synchro_studio.luau, synchro_github.luau et installer_paquet.luau. Sûr d'abord : place affichée et confirmée (T-239), mode aperçu (T-232), point d'historique pour Ctrl+Z (T-230), copie de secours des scripts remplacés (T-231). T-237 pose ensuite la version et le commit sur chaque script : c'est le socle de T-233 (retouches faites à la main repérées par empreinte) et de T-269 (versions mélangées signalées par le diagnostic du serveur).

### V13.1.7 — Synchro : installer, retirer, rapatrier

**Objectif :** Garder les réglages propres à la place, préparer une place neuve, désinstaller proprement et rapatrier une correction faite dans Studio.

- **T-236. Anciens noms à supprimer tirés de git** *(petit)* : La liste SUPPRIMER de manifeste.py est tenue à la main ; la lire dans l'historique git (fichiers renommés ou supprimés dans src/) évite d'oublier un vieux script dans Studio, surtout pendant la V9.
- **T-252. Retour à une version précédente documenté** *(petit)* : synchro_github.luau accepte un nom de branche ; documenter et tester l'usage d'un tag (v6.9.8) pour réinstaller vite une version sûre si une mise à jour pose problème.
- **T-238. Désinstallation propre du TARDIS** *(petit)* : Un script de barre de commande retire tous les scripts listés dans le manifeste, et seulement eux, avec un rapport : utile pour nettoyer une place de test ou repartir de zéro.
- **T-253. Réglages propres à la place jamais écrasés** *(moyen)* : La synchro remplace TardisConfig en entier, avec Config.Pilotes et les identifiants de sons. Un petit module TardisConfigLocal, absent du dépôt et appliqué par-dessus, garderait les réglages de ZONE-TSADE à chaque mise à jour.
- **T-235. Synchro qui prépare une place neuve** *(moyen)* : Créer s'ils manquent Workspace › TARDIS › TARDIS_1 › EXTERIEURE / INTERIEURE, TARDIS_DESTINATIONS avec ACCORDE, REFUSE, SANS_EXPRESS et ReplicatedStorage › TardisAssets, puis dire ce qu'il reste à poser.
- **T-234. Rapatrier dans le dépôt une correction faite dans Studio** *(moyen)* : Un script de barre de commande rassemble les scripts modifiés à la main dans un dossier à enregistrer en .rbxmx, et un outil Python les remet dans src/ : un correctif d'urgence n'est plus perdu à la synchro suivante.

**Dans Studio :** Créer le petit module TardisConfigPlace (pilotes, sons propres à ZONE-TSADE) que la synchro n'écrase plus. Tester T-235 sur une place vide.

*Pourquoi ici :* Suite de V13.1.6, sur les mêmes scripts. T-236 (anciens noms tirés de git) et T-252 (retour à un tag documenté) sont courts. T-238 retire seulement ce que liste le manifeste. T-253 sépare les réglages propres à la place : il passe avant T-235 (créer TARDIS_1, EXTERIEURE, INTERIEURE, TARDIS_DESTINATIONS s'ils manquent), qui complète le guide d'installation de la V10. T-234 (rapatrier un script modifié dans Studio) est le plus délicat : en dernier.

### V13.1.8 — Diagnostic de la place au démarrage

**Objectif :** Faire dire au diagnostic du serveur tout ce qui manque ou est mal réglé dans la place.

- **T-254. Diagnostic : propriétés des pièces essentielles** *(petit)* : Vérifier que les Portail sont invisibles et sans collision, que Racine est ancrée, que la Lampe contient bien une PointLight et que le Rotor est ancré : ces réglages cassent le passage ou les effets sans aucun message aujourd'hui.
- **T-261. Diagnostic : scripts du kit encore présents** *(petit)* : Signaler Default Mainscript, README:, les Move et MainPhase des portes et les scripts Power du kit encore dans le modèle (RAPPELS §2), même désactivés.
- **T-262. Diagnostic : réglages de la place** *(petit)* : Vérifier StreamingEnabled et ModelStreamingMode Persistent sur les Models du TARDIS, et l'accès aux services API dans Studio : les oublis du README §7 sont dits au lancement.
- **T-263. Diagnostic : équipes C.A.T. et C.T.A.T. présentes** *(petit)* : Vérifier que l'équipe C.A.T. existe dans Teams (RAPPELS §3) et que sa couleur diffère de celle de la C.T.A.T.
- **T-267. Diagnostic : destinations en double ou rangées ailleurs** *(petit)* : Signaler deux destinations du même nom et une Part rangée dans un sous-dossier inconnu (ni ACCORDE, ni REFUSE, ni SANS_EXPRESS).
- **T-266. Diagnostic : branchements Adonis, WL et RoSysLog** *(petit)* : Dire au démarrage si G_API d'Adonis répond et si Config.Acces.WL.Module et Config.Journal.Cible sont trouvés par Config.trouverChemin, au lieu d'un échec silencieux.
- **T-264. Diagnostic : sons qui ne se chargent pas** *(petit)* : Au-delà de la présence du Sound, vérifier après quelques secondes que chaque son a une durée (TimeLength > 0) : un identifiant supprimé ou privé est repéré.
- **T-259. Liste des fonctions coupées au démarrage** *(petit)* : Une ligne de l'Output dit quelles fonctions sont désactivées (Copilote, AnnonceBord, Sauvegarde, Intercom en commentaire…) : on sait tout de suite pourquoi une fonction « ne marche pas ».
- **T-265. Diagnostic : tenues et avatars encore valides** *(moyen)* : Vérifier en arrière-plan (MarketplaceService:GetProductInfo, dans un pcall) que les hauts et bas de Config.Tenues et les avatars de régénération existent toujours.

**Dans Studio :** Rien à ajouter : corriger dans Studio ce que le diagnostic signale.

*Pourquoi ici :* Tout va dans TardisDiagnostic (ServerScriptService), qui écrit déjà la ligne de diagnostic du démarrage. Pièces et réglages d'abord : propriétés des pièces essentielles (T-254), scripts du kit restés (T-261), StreamingEnabled et ModelStreamingMode (T-262), équipes C.A.T. et C.T.A.T. (T-263), destinations en double (T-267). Puis branchements Adonis, WL, RoSysLog (T-266), sons qui ne chargent pas (T-264), fonctions coupées (T-259). T-265 interroge MarketplaceService en arrière-plan : plus lent, en dernier.

### V13.1.9 — Réglages : défauts, alias et essais

**Objectif :** Ranger les valeurs par défaut, accepter les anciens noms, tester plus vite dans Studio et suivre les réglages d'une version à l'autre.

- **T-251. Ancien nom de réglage accepté avec avertissement** *(petit)* : Quand un réglage change de nom (Express devenu Rapide), TardisConfig garde un alias qui marche encore et écrit un avertissement : une place avec une ancienne config ne casse pas d'un coup.
- **T-255. Valeurs par défaut réunies en un endroit** *(moyen)* : Beaucoup de scripts écrivent « Config.X or valeur » (Config.NomDestinations or "TARDIS_DESTINATIONS") ; une table de défauts fusionnée au chargement donne une seule valeur par réglage, même si un bloc est incomplet.
- **T-257. Voyages accélérés pour tester dans Studio** *(petit)* : Un réglage d'essai, actif seulement dans Studio, divise les durées de démat, vortex et remat : on teste un voyage en 5 secondes au lieu de 30.
- **T-258. Mode debug allumé sans republier** *(petit)* : Config.Debug est figé dans le module ; un attribut sur ServerScriptService (ou un réglage Studio) l'allumerait le temps d'un dépannage, sans changer le code.
- **T-245. Réglages ajoutés ou retirés entre deux versions** *(petit)* : Un outil compare les clés de TardisConfig entre deux tags (par exemple v6.9.8 et v6.9.9) et écrit la liste des réglages nouveaux, renommés ou retirés, prête à coller dans la note de version.
- **T-246. Réglages changés depuis le dernier démarrage** *(moyen)* : Au démarrage, le serveur compare une empreinte de chaque bloc de TardisConfig à celle gardée la fois d'avant et écrit au journal les blocs modifiés : on sait tout de suite si un comportement a changé à cause d'un réglage touché dans Studio.
- **T-256. Référence des réglages générée automatiquement** *(moyen)* : Un outil lit les commentaires de TardisConfig et produit docs/REGLAGES.md : chaque réglage, sa valeur, son unité, sa version d'arrivée et les scripts qui le lisent.

**Dans Studio :** Rien. T-258 : un attribut Debug sur ServerScriptService pour allumer le mode debug sans republier.

*Pourquoi ici :* Tout part de TardisConfig (découpée par domaine en V10). Socle d'abord : ancien nom accepté avec avertissement (T-251) et valeurs par défaut au même endroit (T-255), qui complète la validation de la config de la V9. T-257 (voyages accélérés dans Studio) et T-258 (debug sans republier) aident à tester toute la suite. T-245 et T-246 suivent les réglages ajoutés ou changés. T-256 génère docs/REGLAGES.md depuis les commentaires : en dernier, quand tout est rangé.

### V13.1.10 — Versions et notes de version

**Objectif :** Fixer la règle de numérotation et outiller les notes de version et les releases.

- **T-244. Règle de numérotation des versions écrite** *(petit)* : Écrire quand on passe de V6.9.x à V7, ce que signifie V11.1.1 et quelle sous-version reçoit un tag : évite les numéros ambigus (plages, versions « non installées ») vus dans le CHANGELOG.
- **T-240. Numéro de version vérifié partout** *(petit)* : Un outil compare Config.Version, manifeste.json, le CHANGELOG, le README et la dernière note de version, et signale tout écart avant publication.
- **T-281. Format des notes de version vérifié** *(petit)* : etat_tests.py et release.py dépendent des titres « ## Vx.y — Titre (date) » et « ### À tester » ; un contrôle signale une note mal écrite avant qu'un test ou une release disparaisse sans bruit.
- **T-286. Pages générées vérifiées à jour** *(petit)* : ETAT_DES_TESTS.md n'a pas encore la V6.9.9 : un contrôle relance etat_tests.py, manifeste.py et release.py --manquantes et échoue si un fichier généré n'est pas à jour.
- **T-243. Tests pas encore faits signalés dans la release** *(petit)* : release.py ajoute au texte la liste des tests ⬜ de la version (lus dans ETAT_DES_TESTS.md), pour que chacun sache ce qui n'a pas encore été vérifié en jeu.
- **T-250. Section « À faire dans Studio » par version** *(petit)* : Chaque note de version liste les pièces, sons et réglages nouveaux à poser ; un outil les rassemble pour un saut de plusieurs versions (par exemple V6.6.6 vers V6.9.9).
- **T-241. Nouvelle version créée en une commande** *(moyen)* : outils/nouvelle_version.py 6.9.10 « Vol libre et vortex » change Config.Version, ajoute la ligne du CHANGELOG, crée le squelette de note (Technique, Simulations, À tester dans Studio) et relance le manifeste.
- **T-282. Une note de version par fichier** *(moyen)* : docs/patch-notes/V6.md fait plus de 1 200 lignes ; un fichier par sous-version se lit, se relie et se compare plus facilement.

**Dans Studio :** Rien.

*Pourquoi ici :* Règle avant outil : T-244 écrit ce que veut dire V13.1.1 et quelle sous-version reçoit un tag. Puis les contrôles : numéro de version partout (T-240), format des notes (T-281), pages générées à jour (T-286). Puis release.py : tests pas faits (T-243), section « À faire dans Studio » (T-250). T-241 crée une version en une commande en s'appuyant sur ces contrôles. T-282 (une note par fichier) change les chemins lus par etat_tests.py et release.py : en dernier.

### V13.1.11 — Documentation du dépôt

**Objectif :** Écrire les conventions, les décisions, le dépannage et les pages générées sur l'architecture et les attributs.

- **T-274. Consignes pour les agents dans le dépôt** *(petit)* : Un fichier CLAUDE.md à la racine : conventions, outils à lancer (manifeste, simulations), français, src/ identique à ZONE-TSADE, décisions à respecter. Chaque nouvelle session part sur les mêmes bases.
- **T-275. Guide des conventions de code** *(petit)* : docs/CONVENTIONS.md : noms en français sans accents, suffixes .server / .client, en-tête de fichier, sections, numéro de version et de proposition dans les commentaires, messages de commit.
- **T-273. Journal des décisions du propriétaire** *(petit)* : docs/DECISIONS.md : chaque décision (pas de commandes du staff, intercom en pause, clé retirée, pas de « 3, 2, 1 »…) avec sa date et sa raison, pour que personne ne revienne dessus par erreur.
- **T-280. README allégé sur la version actuelle** *(petit)* : La ligne « Version actuelle » du README résume 25 versions en une seule phrase géante ; ne garder que la dernière et renvoyer au CHANGELOG.
- **T-279. Liens de la documentation vérifiés** *(petit)* : Un outil vérifie que chaque lien relatif des fichiers .md (docs, README, CHANGELOG, releases) mène à un fichier et à un titre qui existent.
- **T-278. Page de dépannage des problèmes fréquents** *(petit)* : docs/DEPANNAGE.md : symptôme, cause, solution (menu qui ne s'ouvre pas : script du mauvais type ; rien n'est sauvegardé : accès API Studio ; portes bloquées : taille sous 70 %).
- **T-283. Test rapide après chaque installation** *(petit)* : docs/TEST_RAPIDE.md : dix vérifications en cinq minutes (démat, remat, portes, tablette, sauvegarde, technicien) à faire après chaque mise à jour, avant les longs tableaux « À tester ».
- **T-277. Référence des attributs générée** *(petit)* : docs/ATTRIBUTS.md : chaque attribut (Mode, Etat, TardisPilote_…) avec qui l'écrit, qui le lit et son type, produit par l'analyseur qui fait déjà ces croisements.
- **T-276. Carte de l'architecture générée** *(moyen)* : Un outil dessine (schéma Mermaid dans docs/ARCHITECTURE.md) quels scripts requièrent quels modules et qui envoie quelle action sur quel RemoteEvent ou Bindable : la base pour préparer la V9.

**Dans Studio :** Rien.

*Pourquoi ici :* Seulement des fichiers de docs/ : aucun risque en jeu. Conventions d'abord (T-274 CLAUDE.md, T-275 CONVENTIONS.md, T-273 DECISIONS.md), puis le ménage (T-280 README allégé, T-279 liens vérifiés), puis les pages d'aide (T-278 DEPANNAGE.md, T-283 TEST_RAPIDE.md, qui complètent le guide d'installation de la V10). T-277 (ATTRIBUTS.md) et T-276 (carte Mermaid de l'architecture) sont générés depuis le code rangé par la V10 : en dernier.

### V13.1.12 — GitHub : vérifications et suivi des tests

**Objectif :** Lancer les contrôles à chaque commit et à chaque push, protéger main et lire les résultats de test dans les issues.

- **T-229. Manifeste vérifié avant chaque commit** *(petit)* : Un crochet git (pre-commit) relance outils/manifeste.py et l'analyse statique, et refuse le commit si manifeste.json ne correspond plus à src/ : la synchro GitHub ne tombe plus sur une empreinte périmée.
- **T-284. Vérifications automatiques sur GitHub Actions** *(moyen)* : À chaque push et pull request : analyse statique, simulations et manifeste à jour, avec une coche verte ou rouge sur GitHub.
- **T-285. Branche main protégée par les vérifications** *(petit)* : Interdire de fusionner dans main tant que les vérifications sont rouges, puisque synchro_github.luau installe main directement dans Studio.
- **T-287. Modèles d'issue pour bugs et résultats de test** *(petit)* : Formulaires .github/ISSUE_TEMPLATE : « Bug en jeu » (version, TARDIS, étapes, extrait de l'Output) et « Résultat de test » (version, test, ✅ ⚠️ ❌).
- **T-289. Modèle de pull request avec liste de contrôle** *(petit)* : Une case à cocher pour chaque étape : manifeste relancé, simulations vertes, note de version et « À tester » écrits, CHANGELOG à jour, décisions respectées.
- **T-288. Résultats de test lus depuis les issues** *(moyen)* : etat_tests.py lit les issues « Résultat de test » (avec gh) et remplit la colonne Résultat : les testeurs notent dans GitHub sans toucher au Markdown.
- **T-290. Feuille de route comparée aux issues** *(moyen)* : Un outil compare le tableau de FEUILLE_DE_ROUTE.md (#89 à #129, états, dates) aux issues GitHub et liste les écarts, pour que les deux ne divergent pas.

**Dans Studio :** Rien dans Studio. Sur GitHub : activer Actions, protéger la branche main, ajouter les modèles d'issue et de pull request.

*Pourquoi ici :* T-229 (crochet pre-commit) et T-284 (GitHub Actions) lancent les contrôles des lots précédents ; T-285 interdit de fusionner dans main si c'est rouge, puisque synchro_github.luau installe main directement. Les modèles (T-287 issues, T-289 pull request) passent avant T-288, qui lit les issues « Résultat de test » pour remplir ETAT_DES_TESTS.md. T-290 compare la feuille de route aux issues #89 à #129 et suivantes.

### V13.1.13 — Dépôt propre et publication

**Objectif :** Faire le ménage git, chercher les secrets et préparer chaque publication avec une liste de contrôle.

- **T-291. Ménage des anciennes branches** *(petit)* : v6.8-integration-staff (commandes du staff retirées) et sauvegarde-v6.6.6 deviennent des tags puis sont supprimées : la synchro ne peut plus pointer vers une branche périmée.
- **T-292. Tags git rattrapés depuis V6.7.2** *(petit)* : Les tags s'arrêtent à v6.7.1 : les poser sur les bons commits d'après le CHANGELOG, condition pour des releases et des retours en arrière fiables.
- **T-293. Recherche de secrets dans le dépôt** *(petit)* : Activer la détection de secrets de GitHub et un contrôle (aucune clé Open Cloud, webhook ou cookie dans src/ ou outils/) avant d'ajouter des outils qui en utilisent.
- **T-299. Propositions gardées retrouvées dans le code** *(petit)* : Un outil cherche les numéros de proposition cités dans le code et les notes (« (199) », « proposition 198 ») et les compare au plan de FEUILLE_DE_ROUTE.md : on voit lesquelles sont faites, commencées ou pas encore touchées.
- **T-296. Liste de contrôle de publication** *(petit)* : docs/PUBLIER.md : copie de la place, synchro, diagnostic sans erreur, test rapide, publication, tag, release, rappels, dans l'ordre et à cocher.
- **T-270. Vérifier la place depuis Studio sans lancer le jeu** *(moyen)* : outils/verifier_place.luau, collé dans la barre de commande en mode Édition, fait le même diagnostic que le serveur (pièces, sons, destinations, réglages) sans démarrer de partie.
- **T-297. Prévenir les serveurs restés sur l'ancienne version** *(moyen)* : Après une publication, les serveurs déjà ouverts gardent l'ancien code : chacun compare Config.Version à la dernière version publiée (magasin ou MessagingService) et l'écrit au journal.

**Dans Studio :** T-270 : script à coller dans la barre de commande de Studio, en mode Édition.

*Pourquoi ici :* Ménage git d'abord : anciennes branches en tags (T-291), tags rattrapés depuis v6.7.2 (T-292), recherche de secrets (T-293). T-299 relie les numéros de proposition cités dans le code aux plans. Puis la publication : liste de contrôle docs/PUBLIER.md (T-296), vérification de la place depuis Studio (T-270, même contrôle que TardisDiagnostic), et T-297 (prévenir les serveurs restés sur l'ancienne version), qui touche le serveur : en dernier.

### V13.1.14 — Sauvegardes et erreurs lues hors du jeu

**Objectif :** Garder les erreurs entre serveurs et pouvoir lire ou copier une sauvegarde sans lancer le jeu.

- **T-272. Version et appareil joints à chaque erreur** *(petit)* : noterErreur ajoute Config.Version, le type d'appareil (ordinateur, mobile, console) et le TARDIS : on sait si une erreur vient d'une ancienne version ou d'un seul type d'appareil.
- **T-248. Lecture d'une sauvegarde depuis Studio** *(petit)* : Un script de barre de commande affiche une clé de sauvegarde décodée (format, version qui l'a écrite, date, contenu) : utile pour comprendre un problème de données sans deviner.
- **T-271. Erreurs remontées gardées entre les serveurs** *(moyen)* : TardisSupervision garde 100 erreurs en mémoire, perdues à la fermeture et plus consultables depuis le retrait des commandes du staff : les ranger, comptées par version, et les lire depuis Studio.
- **T-247. Copie des sauvegardes hors de Roblox** *(moyen)* : Un script Python lit les magasins TardisSauvegarde_v2 et TardisExtras_v2 par l'API Open Cloud (clé en lecture seule, jamais dans le dépôt) et les garde en JSON daté, avant chaque grosse mise à jour.

**Dans Studio :** T-247 : créer une clé Open Cloud en lecture seule (jamais dans le dépôt).

*Pourquoi ici :* T-272 joint version, appareil et TARDIS à chaque erreur (noterErreur, TardisSupervision) ; T-271 garde les erreurs dans une clé DataStore. T-248 affiche une clé décodée depuis Studio, T-247 copie TardisSauvegarde_v2 et TardisExtras_v2 hors de Roblox. Placé avant la V13.2 : si un lot de sauvegarde tourne mal, on a une copie et on voit ce qui a été écrit.

### V13.1.15 — Place de test et vrai moteur

**Objectif :** Générer une petite place de test et y lancer les tests dans le vrai moteur Roblox.

- **T-294. Place de test minimale générée** *(gros)* : Un outil Python produit un fichier .rbxlx avec un TARDIS simple (Racine, portails, Lampe, Rotor, commandes, destinations) et tous les scripts : on teste une version sans ZONE-TSADE ni son modèle.
- **T-295. Tests dans le vrai moteur par Open Cloud** *(gros)* : L'API Open Cloud d'exécution Luau lance du code dans une place de test sur les serveurs Roblox : GitHub pourrait y faire tourner des tests avec la vraie physique et les vrais services.

**Dans Studio :** T-294 produit un fichier .rbxlx à ouvrir dans Studio ; T-295 demande une place de test publiée et une clé Open Cloud.

*Pourquoi ici :* Les deux plus gros chantiers d'outils, en dernier : T-294 génère une place minimale (Racine, portails, Lampe, Rotor, destinations), T-295 y lance les tests depuis GitHub Actions (V13.1.12) par l'API d'exécution Luau.

## V13.2 — Serveur : sauvegarde et fiabilité (16 lots, 95 propositions)

Rendre le serveur plus sûr : sauvegardes justes même avec plusieurs serveurs, voyages jamais bloqués, données réservées protégées et boucles plus légères. Ces lots complètent le garde-barrière et le schéma posés par la V8.

### V13.2.1 — Sauvegarde : petites corrections

**Objectif :** Corriger les défauts courts de TardisSauvegarde et des lectures du démarrage.

- **T-16. Pas d'attente après le dernier essai** *(petit)* : La fonction reessayer de TardisSauvegarde attend encore 3 s après le troisième échec, pour rien. Supprimer cette dernière attente fait gagner 3 s à chaque panne, au démarrage comme à la fermeture.
- **T-18. Erreurs DataStore définitives non réessayées** *(petit)* : Certaines erreurs ne passeront jamais (valeur trop grosse, nom de clé invalide) mais sont réessayées 3 fois. Lire le code de l'erreur et abandonner tout de suite dans ces cas, avec un message clair dans l'Output.
- **T-9. Réglages jamais écrits avant d'être lus** *(petit)* : TardisExtras lit « reglages » tout à la fin du script, après d'autres lectures qui peuvent prendre plusieurs secondes : un changement de thème pendant ce temps réécrit des réglages presque vides. Bloquer sauverReglages tant que la lecture n'est pas faite, comme carnetCharge le fait déjà pour le carnet.
- **T-13. Écrire seulement les données modifiées** *(petit)* : Toutes les 120 s, si un seul joueur a changé, les statistiques de tous les joueurs sont réécrites ; les préférences sont réécrites au départ même sans changement. Un drapeau « modifié » par joueur et par clé réduit fortement les écritures.
- **T-24. Fin de la lecture des anciens magasins v1** *(petit)* : Chaque clé absente du magasin v2 est cherchée dans le v1 : chaque nouveau joueur coûte donc des lectures en plus, pour toujours. Un réglage qui arrête cette migration (par exemple après une date) supprime ces requêtes inutiles.
- **T-27. Nouvelle lecture quand la sauvegarde est illisible** *(petit)* : Si la première lecture échoue, chargementReussi reste faux et le TARDIS ne sauvegarde plus rien de toute la session. Réessayer la lecture toutes les quelques minutes, et prévenir le journal, débloque la sauvegarde dès que le service revient.
- **T-96. Sauvegarde visible dans le diagnostic de démarrage** *(petit)* : Si le DataStore est coupé (API désactivée dans Studio, panne), seul un avertissement isolé le dit. Ajouter « sauvegarde : active / illisible / coupée » à la ligne de diagnostic rend la situation évidente.

**Dans Studio :** Rien.

*Pourquoi ici :* Tout dans TardisSauvegarde (reessayer, environ 110 lignes) et les lectures de TardisExtras et TardisServeur. Corrections sûres d'abord : plus d'attente de 3 s après le dernier essai (T-16), erreurs définitives non réessayées (T-18), « reglages » lu avant d'être réécrit (T-9). Puis écrire seulement ce qui a changé (T-13), arrêt de la lecture des magasins v1 (T-24), nouvel essai quand la sauvegarde est illisible (T-27), état de la sauvegarde dans le diagnostic (T-96). La simulation de panne (T-86, V13.1.2) vérifie le tout.

### V13.2.2 — Joueurs qui partent

**Objectif :** Ne plus rien perdre ni rien garder en trop quand un joueur quitte le serveur.

- **T-15. Statistiques d'un joueur parti pendant le chargement** *(petit)* : Si un joueur part avant la fin de chargerStats, ses statistiques sont rangées après son départ : elles restent en mémoire et ne sont jamais sauvegardées. Vérifier que le joueur est encore là à la fin du chargement.
- **T-12. Une seule sauvegarde par joueur à la fermeture** *(petit)* : Quand le serveur ferme, PlayerRemoving et BindToClose sauvegardent les statistiques et les préférences du même joueur deux fois. Marquer le joueur « déjà sauvegardé » évite les écritures en double et la file d'attente du DataStore.
- **T-14. Préférences oubliées quand le joueur part** *(petit)* : La table prefs de TardisExtras n'est jamais vidée : à la fermeture, BindToClose réécrit les préférences de tous les joueurs passés depuis le début du serveur. Vider l'entrée au départ (après la sauvegarde) libère la mémoire et raccourcit la fermeture.
- **T-51. Tables par joueur vidées au départ** *(moyen)* : Plusieurs tables gardent un joueur après son départ : posesOrigine (avec son personnage), decouvertes, invitations, stats en cas de départ rapide. Un tour complet des tables, plus un contrôle dans analyse.py, évite que la mémoire monte sur les longs serveurs.
- **T-52. Cache des avatars de régénération limité** *(petit)* : descriptionsChargees garde chaque HumanoidDescription chargée pour toute la session, sans limite. Un plafond (par exemple 50, les plus anciennes retirées) et un nettoyage au départ du joueur gardent la mémoire stable.

**Dans Studio :** Rien.

*Pourquoi ici :* Le même moment pose problème partout : le départ d'un joueur. T-15 (statistiques rangées après le départ) et T-12 (deux sauvegardes à la fermeture) touchent PlayerRemoving et BindToClose ; T-14 vide la table prefs de TardisExtras. T-51 fait le tour des tables par joueur (posesOrigine, decouvertes, invitations), T-52 limite le cache descriptionsChargees de la régénération. Après ce lot, la simulation longue (T-249) ne doit plus montrer de mémoire qui grossit.

### V13.2.3 — Sauvegarde : contenu et clés

**Objectif :** Séparer les données de test, attacher les joueurs à leurs clés et mieux ranger ce qui est enregistré.

- **T-20. Données séparées pour Studio et les places de test** *(petit)* : Un test dans Studio ou dans une place de test du même univers écrit dans les mêmes magasins que ZONE-TSADE. Un préfixe de magasin différent hors du jeu publié (RunService:IsStudio, PlaceId) protège les vraies données.
- **T-28. Clé de sauvegarde du TARDIS réglable** *(petit)* : La clé dépend du PlaceId : republier le jeu sur une autre place fait perdre la dernière position et l'historique. Un réglage Config.Sauvegarde.Cle (par défaut l'actuel) permet de garder les données lors d'un changement de place.
- **T-23. Identifiants des joueurs attachés à leurs clés** *(petit)* : UpdateAsync permet d'attacher le UserId à une clé de joueur. Les outils de Roblox retrouvent alors ses données lors d'une demande d'effacement, sans avoir à deviner le nom des clés.
- **T-22. Effacement des données d'un joueur sur demande** *(moyen)* : Roblox peut demander d'effacer les données d'un joueur (droit à l'oubli). Une fonction qui supprime toutes ses clés (stats_, decouverte_, prefs_) et ses entrées dans les rôles, dans tous les magasins, permet d'y répondre vite.
- **T-30. Dates enregistrées en temps universel** *(petit)* : Les incidents, régénérations et registres stockent un texte os.date à l'heure du serveur. Stocker os.time (un nombre) et laisser chaque client l'afficher à son heure évite les heures fausses et facilite les tris.
- **T-91. Passagers comptés par identifiant** *(petit)* : Les statistiques rangent les passagers par DisplayName, qui change et peut être porté par plusieurs joueurs. Les ranger par UserId (avec le nom à côté) donne des chiffres justes.
- **T-25. Position sauvegardée même pendant un vol** *(petit)* : sauvegarder refuse d'écrire si le TARDIS n'est pas posé : un serveur qui ferme pendant un voyage garde une position ancienne. À la fermeture, enregistrer la dernière position stable connue ou la destination en cours, avec une marque « en vol ».

**Dans Studio :** Rien. Vérifier après T-20 qu'un test dans Studio n'écrit plus dans les magasins du jeu publié.

*Pourquoi ici :* Règle avant données : T-20 sépare d'abord Studio et les places de test, pour essayer les lots suivants sans toucher aux vraies sauvegardes. T-28 rend la clé du TARDIS réglable. T-23 attache le UserId aux clés, ce qui rend simple T-22 (effacement sur demande). T-30 (dates en temps universel) et T-91 (passagers par UserId) changent le contenu : un nouveau Sauvegarde.FORMAT avec migration, testé par T-214. T-25 enregistre la position même pendant un vol.

### V13.2.4 — Sauvegarde : file d'écriture et fermeture

**Objectif :** Respecter les limites du DataStore et sauvegarder vite et sans perte quand le serveur ferme.

- **T-10. File d'écriture par clé dans TardisSauvegarde** *(moyen)* : Chaque clic sur une couleur, un style ou une catégorie écrit tout de suite dans le DataStore, alors qu'une clé n'accepte qu'une écriture toutes les 6 s environ. Une file dans TardisSauvegarde garde la dernière valeur de chaque clé et l'écrit au bon rythme.
- **T-17. Requêtes DataStore selon le budget disponible** *(moyen)* : TardisSauvegarde envoie ses requêtes sans regarder le budget du serveur : quand il est épuisé, les réessais échouent tous. Consulter GetRequestBudgetForRequestType et patienter avant d'envoyer évite des pertes au démarrage et à la fermeture.
- **T-19. Démarrage des extras sans attendre le DataStore** *(moyen)* : TardisExtras lit les rôles, les statistiques et les réglages au début du script, d'un bloc : si le DataStore est lent, tout le script démarre avec plusieurs secondes de retard. Charger en arrière-plan avec des valeurs par défaut rend le TARDIS utilisable tout de suite.
- **T-98. Commandes refusées pendant la fermeture du serveur** *(petit)* : Pendant BindToClose, un pilote peut encore lancer un décollage, et la sauvegarde enregistre alors un état à moitié fait. Un drapeau « fermeture » refuse les nouveaux voyages avec un message.
- **T-11. Écritures en parallèle à la fermeture du serveur** *(moyen)* : Les BindToClose de TardisServeur et TardisExtras écrivent les clés une par une, avec réessais : avec beaucoup de joueurs, on approche la limite de 30 s et la fin est perdue. Lancer toutes les écritures en même temps et attendre qu'elles finissent, avec une limite.

**Dans Studio :** Rien.

*Pourquoi ici :* T-10 crée une file par clé dans TardisSauvegarde (une écriture toutes les 6 s environ par clé), T-17 la règle selon GetRequestBudgetForRequestType. T-19 démarre TardisExtras sans attendre le DataStore. T-98 refuse les nouveaux voyages pendant BindToClose, puis T-11 écrit les clés en parallèle (BindToClose de TardisServeur et de TardisExtras) : la file passe avant la fermeture, qui s'en sert.

### V13.2.5 — Sauvegarde juste entre serveurs

**Objectif :** Ne plus laisser deux serveurs ouverts effacer les données l'un de l'autre.

- **T-4. Compteur de voyages additionné entre serveurs** *(petit)* : « stats_serveur » est lu au démarrage puis réécrit en entier : deux serveurs ouverts en même temps effacent les voyages l'un de l'autre. Écrire avec UpdateAsync en ajoutant seulement les voyages du serveur rend le total juste.
- **T-6. Rôles temporaires fusionnés entre serveurs** *(moyen)* : sauverRoles réécrit toute la table des pilotes promus et des bannis : un bannissement posé sur un serveur peut être effacé par la sauvegarde d'un autre. Fusionner entrée par entrée dans UpdateAsync (ajout, retrait) au lieu de tout remplacer.
- **T-5. Sauvegarde du TARDIS protégée entre serveurs** *(moyen)* : La clé « place_<PlaceId> » est la même pour tous les serveurs : le dernier qui écrit gagne, même avec une position plus ancienne. Mettre le JobId et la date dans l'enveloppe, et comparer dans UpdateAsync avant d'écraser.
- **T-90. Pas d'écrasement par une version plus ancienne** *(moyen)* : Pendant une mise à jour, un vieux serveur peut réécrire une sauvegarde au nouveau format et perdre les nouveaux champs. Refuser d'écrire quand le format stocké est plus récent que celui du serveur, et garder les champs inconnus.
- **T-97. Verrou de session pour les données des joueurs** *(moyen)* : Un joueur qui change vite de serveur peut charger ses statistiques avant que l'ancien serveur ait fini de les écrire, puis écraser la version récente. Un verrou de session léger (serveur et date dans la clé) évite cette perte classique.

**Dans Studio :** Rien.

*Pourquoi ici :* Les cinq passent par UpdateAsync au lieu de réécrire en entier. Du plus court au plus délicat : compteur de voyages additionné (T-4), rôles promus et bannis fusionnés entrée par entrée (T-6), sauvegarde du TARDIS avec JobId et date (T-5), refus d'écraser un format plus récent (T-90, qui complète le schéma vérifié à la lecture de la V8), verrou de session pour les données des joueurs (T-97).

### V13.2.6 — Historique et état conservés

**Objectif :** Pouvoir revenir à une ancienne sauvegarde et garder le registre de sécurité, les pannes et la maintenance d'un serveur à l'autre.

- **T-21. Retour à une version précédente de la sauvegarde** *(moyen)* : Le DataStore garde l'historique des versions de chaque clé. Une fonction Sauvegarde.restaurer(cle, date), lancée depuis la barre de commande, permet de réparer une sauvegarde abîmée sans rien coder sur le moment.
- **T-29. Registre de sécurité persistant** *(moyen)* : Les auto-destructions, bannissements, Sièges et maintenances ne vont qu'au journal du moment (RoSysLog). Garder les 100 derniers dans une clé DataStore permet de retrouver qui a fait quoi, même après la fermeture du serveur.
- **T-26. Pannes et maintenance conservées au redémarrage** *(moyen)* : Les PV, les pannes en cours, le redémarrage requis et le mode maintenance reviennent à zéro à chaque nouveau serveur. Les ranger dans la sauvegarde du TARDIS (option) garde un état cohérent entre deux serveurs.

**Dans Studio :** Rien.

*Pourquoi ici :* Nouvelles données gardées, donc après la file d'écriture (V13.2.4) pour ne pas dépasser les limites. T-21 (Sauvegarde.restaurer depuis la barre de commande) sert de filet si un lot précédent a abîmé une clé. T-29 garde les 100 derniers événements de sécurité. T-26 (option) garde PV, pannes et maintenance au redémarrage : il touche aussi TardisSystemes, en dernier.

### V13.2.7 — Démarrage sans blocage

**Objectif :** Qu'aucun script serveur ne reste bloqué ou en double au démarrage, et qu'une erreur n'arrête plus une boucle pour toujours.

- **T-42. RemoteEvent réutilisé s'il existe déjà** *(petit)* : TardisServeur crée toujours un nouveau RemoteEvent : si un ancien reste (copie dans Studio, script relancé), deux objets portent le même nom et un client peut écouter le mauvais. Réutiliser ou supprimer l'ancien au démarrage.
- **T-43. Script en double détecté au démarrage** *(petit)* : Si TardisServeur ou TardisExtras est copié par erreur, deux exemplaires gèrent le même TARDIS et chaque commande est traitée deux fois. Un repère dans ServerStorage (« déjà lancé pour TARDIS_1 ») fait s'arrêter le second avec un avertissement clair.
- **T-45. Objets partagés créés par une seule fonction** *(petit)* : TardisEvenements, TardisBaliseDiffusion et d'autres objets communs sont créés par plusieurs scripts avec « s'il n'existe pas, le créer ». Une seule fonction « trouver ou créer » partagée évite les doublons si deux scripts démarrent en même temps.
- **T-44. Attentes avec délai et message clair** *(petit)* : Plusieurs WaitForChild sans délai (Portail, Rotor, portes, modèles de Config.modeles) bloquent le script pour toujours si une pièce manque, avec un simple « Infinite yield ». Un délai et un message en français disent tout de suite quoi corriger.
- **T-78. Groupes de collision vérifiés au démarrage** *(petit)* : TardisServeur crée les groupes du bouclier anti-balles sous pcall, sans regarder le résultat : si la limite de groupes du jeu est atteinte ou qu'un groupe d'ACS manque, le bouclier bloque les joueurs ou laisse passer les tirs sans rien dire. Vérifier avec IsCollisionGroupRegistered et CollisionGroupsAreCollidable, et l'écrire dans l'Output.
- **T-35. Appels du pont protégés** *(petit)* : interne() appelle pont:Invoke sans protection : une erreur dans TardisServeur remonte et casse le script appelant. Un pcall dans interne(), qui renvoie nil et un message, isole les scripts les uns des autres en attendant la V9.
- **T-33. Boucles de fond protégées contre les erreurs** *(petit)* : Les boucles « while true » (registre, saisie, anomalies, copilote, air, outils) s'arrêtent pour toujours à la première erreur, par exemple un appel au pont qui échoue. Envelopper chaque tour dans un pcall avec un avertissement unique les garde en vie.

**Dans Studio :** Rien.

*Pourquoi ici :* Sûr et court. Objets partagés d'abord : RemoteEvent réutilisé (T-42), script en double repéré (T-43), une seule fonction « trouver ou créer » (T-45). Puis attentes avec délai et message clair (T-44, liste fournie par T-221) et groupes de collision vérifiés (T-78). Enfin appels du pont sous pcall (T-35) et boucles « while true » protégées (T-33) dans TardisExtras et TardisSystemes.

### V13.2.8 — Réponses claires aux joueurs

**Objectif :** Une seule façon de répondre aux joueurs, et jamais de silence quand une commande échoue.

- **A-174. Format de réponse unique** *(petit)* : Un seul repondre / alerter pour tous les scripts serveur.
- **T-39. Message d'erreur interne au lieu du silence** *(petit)* : Quand une commande plante dans un task.spawn, le joueur ne reçoit aucune réponse et ne sait pas quoi faire. Un pcall autour de chaque commande renvoie « Erreur interne, réessaie » et note l'erreur au journal.
- **T-92. Signal TARDIS prêt pour les clients** *(petit)* : Un client peut envoyer une commande avant que TardisExtras ou TardisSystemes aient branché leur écoute : elle est perdue sans message. Un attribut « prêt » posé quand les trois scripts ont démarré permet aux menus d'attendre.
- **T-99. Délai maximum pour le filtre de texte** *(petit)* : Le carnet, l'enseigne et l'interphone attendent TextService sans limite de temps : si le service est lent, le joueur n'a aucune réponse. Un délai maximum, puis « filtre indisponible, réessaie », évite l'attente infinie.
- **T-80. Anti-répétition des alertes envoyées aux pilotes** *(petit)* : Dix visiteurs qui entrent font dix messages « INTRUSION » et dix alarmes, une anomalie peut répéter son alerte. Côté serveur, une même alerte n'est renvoyée qu'après quelques secondes, avec « (×10) » si elle se répète.

**Dans Studio :** Rien.

*Pourquoi ici :* A-174 (un seul repondre / alerter pour tous les scripts serveur, laissé hors de la V9) est le socle : les quatre autres l'utilisent. T-39 renvoie « Erreur interne » au lieu du silence, T-92 pose un attribut « prêt » pour qu'aucune commande du client ne se perde au démarrage, T-99 met un délai maximum au filtre de texte (carnet, enseigne, interphone), T-80 évite dix alertes INTRUSION à la suite.

### V13.2.9 — Journal du serveur plus utile

**Objectif :** Écrire dans le journal de quoi retrouver une personne, un voyage ou une panne, et des rapports de santé et de fermeture.

- **T-79. Identifiant du joueur dans chaque ligne** *(petit)* : Le journal note le pseudo (joueur.Name), qui peut changer. Ajouter le UserId à chaque ligne permet de retrouver la personne de façon sûre, des semaines plus tard.
- **T-72. Numéro de voyage dans le journal** *(petit)* : Chaque voyage reçoit un numéro, repris dans toutes ses lignes (décollage, collisions, atterrissage, dégâts). On suit ainsi un voyage d'un bout à l'autre dans RoSysLog quand un problème est signalé.
- **T-73. Trace de pile des erreurs serveur** *(petit)* : noterErreur ne garde que le message, alors que ScriptContext.Error donne aussi la trace. Garder les premières lignes de la trace dit tout de suite quelle fonction et quelle ligne ont planté.
- **T-93. État complet joint aux erreurs graves** *(petit)* : Quand une séquence plante, joindre à l'erreur un instantané de l'état (Etat, occupe, VolLibre, Porteur, Mode, Maintenance) permet de comprendre la cause sans avoir à reproduire le bug.
- **T-74. Liste des erreurs tournante** *(petit)* : Après 100 erreurs différentes, TardisSupervision ignore toutes les nouvelles pour le reste de la session. Retirer les plus anciennes et compter celles qui ont été perdues garde les erreurs récentes visibles.
- **T-75. Journal gardé si RoSysLog ne répond pas** *(petit)* : Si le journal du jeu est absent ou refuse une ligne, elle est perdue. Garder les dernières lignes en mémoire et les renvoyer quand la cible revient évite les trous dans le journal.
- **T-95. Changements d'accès Adonis et WL notés** *(petit)* : TardisSupervision donne ou retire l'accès pilote ou technicien sans rien noter. Une ligne au journal à chaque changement (qui, quel rôle, quelle source) permet de vérifier qu'aucun accès n'a été donné par erreur.
- **T-76. Rapport de santé du serveur** *(petit)* : Toutes les 10 minutes, une ligne au journal : joueurs, état de chaque TARDIS, mémoire du serveur, réussites et échecs du DataStore, nombre d'erreurs. On voit venir les problèmes avant qu'ils bloquent le jeu.
- **T-77. Rapport de fermeture du serveur** *(petit)* : À la fermeture, une ligne qui dit ce qui a été sauvegardé, ce qui a échoué et combien de temps cela a pris. Sans elle, une perte de données à l'arrêt passe inaperçue.

**Dans Studio :** Rien.

*Pourquoi ici :* Tout passe par noterErreur et le journal (TardisSupervision, RoSysLog), déjà à niveaux depuis la V9. Le contenu d'abord : UserId (T-79), numéro de voyage (T-72), trace de pile (T-73), état joint aux erreurs graves (T-93). Puis la tenue : liste tournante (T-74), lignes gardées si RoSysLog ne répond pas (T-75). Enfin les nouvelles lignes : accès Adonis et WL (T-95), rapport de santé (T-76), rapport de fermeture (T-77), qui lit les résultats de V13.2.4.

### V13.2.10 — Voyages jamais bloqués

**Objectif :** Qu'une erreur au milieu d'une séquence ne laisse plus le TARDIS occupé, détruit ou les joueurs figés.

- **T-31. Libération garantie du verrou occupé** *(moyen)* : partage.occupe passe à vrai au début de chaque séquence (décollage, atterrissage, taille, poche) : une erreur au milieu le laisse vrai et le TARDIS est bloqué jusqu'au redémarrage (déjà arrivé en V6.9.7). Une fonction commune qui lance la séquence sous pcall, note son nom et remet occupe et Verrouille à la fin règle le problème une fois pour toutes.
- **T-34. Joueurs jamais laissés figés** *(petit)* : Les clandestins et le joueur « sur lui » sont ancrés (Anchored) pendant le voyage : si la séquence plante, ils restent figés. Une liste des joueurs ancrés par le serveur, libérée en fin de séquence, en cas d'erreur, de mort ou de départ, évite ce piège.
- **T-38. Reconstitution garantie après l'auto-destruction** *(petit)* : La reconstitution est un simple task.delay de 5 minutes : si l'atterrissage échoue (TARDIS occupé, aucune destination), le TARDIS reste détruit pour toute la session. Réessayer jusqu'à réussite et prévenir le journal en cas d'échec.
- **T-32. Chien de garde des voyages bloqués** *(moyen)* : En partie là pour le vol libre seulement (V6.9.7). Une boucle qui repère un TARDIS occupé ou en Demat / Remat depuis bien plus longtemps que prévu le remet dans un état sûr (posé ou en vol) et le note au journal.
- **T-46. Mise en maintenance automatique après une erreur grave** *(moyen)* : Si une séquence de voyage plante plusieurs fois de suite, le TARDIS passe seul en maintenance (« erreur technique ») au lieu de continuer dans un état douteux. Différent du verrou d'urgence manuel : ici c'est automatique et par TARDIS.

**Dans Studio :** Rien.

*Pourquoi ici :* Dans TardisServeur (decoller, atterrir, partage.occupe). T-31 libère le verrou occupé même après une erreur : c'est la base. T-34 libère les joueurs ancrés, T-38 réessaie la reconstitution après l'auto-destruction. T-32 (chien de garde, déjà en partie là pour le vol libre) remet un TARDIS bloqué dans un état sûr ; T-46 passe en maintenance après plusieurs erreurs graves : il s'appuie sur les deux, en dernier.

### V13.2.11 — Règles du voyage au cœur du serveur

**Objectif :** Vérifier les règles (états permis, droits, confirmations) au cœur du voyage, quel que soit le chemin de la commande.

- **T-50. Arguments nommés pour décoller et atterrir** *(petit)* : atterrir reçoit 5 arguments par position, et TardisExtras passe parfois true ou false à la place d'un mode (interne("decoller", true)). Passer une table { cible, nom, mode, invisible } évite les erreurs d'ordre et de type.
- **T-49. Fin de voyage attendue, sans délais fixes** *(petit)* : Le rappel, la balise, la saisie et la zone restreinte font « décoller, attendre 3 s, atterrir », en supposant la durée. Une fonction attendreEtat(Vol, délai max) suit le vrai état et marche avec tous les modes.
- **T-81. Transitions d'état autorisées en table** *(moyen)* : L'état du TARDIS (Posé, Démat, Vol, Remat) peut être changé de plusieurs endroits, y compris par le pont (setEtat appelé par TardisExtras). Une table des passages permis, vérifiée dans setEtat, refuse et note tout passage impossible.
- **T-36. Destruction et maintenance vérifiées au cœur du voyage** *(petit)* : Seul le RemoteEvent de TardisServeur refuse les ordres pendant l'auto-destruction ; le rappel, la minuterie, la saisie et la console de secours passent par le pont et peuvent faire voyager un TARDIS « détruit » ou en maintenance. Placer ces contrôles dans decoller et atterrir eux-mêmes ferme la brèche.
- **T-37. Minuterie annulée si son pilote perd ses droits** *(petit)* : armerMinuterie lance le décollage même si le pilote est parti, banni ou si la maintenance a commencé entre-temps. Vérifier ces conditions au moment du départ, et annuler la minuterie au départ du pilote.
- **T-47. Pilote du vol libre déchu en plein vol** *(petit)* : recevoirPositionVol ne vérifie que l'identifiant du pilote : un pilote banni ou dont le rôle temporaire expire garde les commandes. Quand il perd ses droits, le TARDIS se pose seul comme pour un pilote muet.
- **T-94. Copilote relâché quand aucun pilote n'est connecté** *(petit)* : Le copilote garde la navigation (démat, remat, camouflage) tant qu'il reste à bord, même si tous les pilotes ont quitté le jeu. La boucle de surveillance du copilote dans TardisServeur peut le relever quand plus aucun pilote de ce TARDIS n'est en ligne, pour qu'un non-pilote ne garde pas seul les commandes.
- **T-100. Confirmations vérifiées par le serveur** *(moyen)* : Le forçage du paradoxe (forcer = true) et l'auto-destruction (confirmation = 3) ne sont confirmés que par le client : un client modifié saute l'étape. Le serveur retient la demande de confirmation qu'il a envoyée et n'accepte que celle-là, pendant quelques secondes.

**Dans Studio :** Rien.

*Pourquoi ici :* Socle avant règles : T-50 passe une table d'arguments nommés à decoller et atterrir (TardisExtras passe parfois true à la place d'un mode), T-49 attend la vraie fin du voyage au lieu de 3 s fixes. T-81 fixe la table des passages d'état permis (Posé, Démat, Vol, Remat). Puis les règles : auto-destruction et maintenance vérifiées au cœur (T-36), minuterie annulée (T-37), pilote du vol libre déchu (T-47), copilote relâché (T-94), confirmations du paradoxe et de l'auto-destruction tenues par le serveur (T-100).

### V13.2.12 — Portes, invites et clics

**Objectif :** Rendre les portes fiables et mettre les invites et clics derrière le même garde que le RemoteEvent.

- **T-40. Portes attendues par signal plutôt que par sondage** *(petit)* : fermerPortes et ouvrirPortesSimple regardent l'attribut PorteOuverte toutes les 0,1 s pendant 3 à 5 s, et forcent le changement avec un faux puis vrai. Attendre le signal de changement avec un délai maximum est plus fiable et ne coûte rien.
- **T-87. Un seul détecteur de clic pour le rotor** *(petit)* : TardisExtras pose un ClickDetector et une connexion sur chaque pièce du rotor, souvent plusieurs dizaines. Un seul ClickDetector placé sur le Model du rotor marche pour toutes ses pièces et coûte beaucoup moins au serveur.
- **T-41. Battants de porte sans dérive** *(moyen)* : Les scripts Shut font tourner les pièces par petits pas avec GetModelCFrame (déprécié) : les arrondis s'accumulent et les battants finissent par se décaler. Retenir au démarrage les positions ouvertes et fermées, et animer entre les deux.
- **T-65. Même garde pour les invites et les clics** *(moyen)* : Le garde-barrière prévu ne couvre que le RemoteEvent ; la quinzaine de ProximityPrompt et le ClickDetector du rotor ont chacun leur propre contrôle (le rotor n'en a aucun : tout le monde le déclenche). Les faire passer par la même fonction de droits.

**Dans Studio :** T-41 change les scripts Shut des portes (Workspace › EXTERIEURE › TARDISDoors) : vérifier les battants dans Studio. T-87 : un seul ClickDetector sur le Model du rotor (le script peut le créer).

*Pourquoi ici :* T-40 attend le signal de PorteOuverte au lieu de sonder toutes les 0,1 s. T-87 remplace les dizaines de ClickDetector du rotor (TardisExtras) par un seul. T-41 corrige la dérive des battants (GetModelCFrame déprécié). T-65 met la quinzaine de ProximityPrompt et le clic du rotor derrière le garde-barrière de la V8 : après T-87, qui réduit le nombre de clics à garder.

### V13.2.13 — Données réservées et accès

**Objectif :** Ne plus publier à tous ce qui est réservé aux pilotes, et mieux borner ce que le client peut envoyer.

- **T-71. Config figée après chargement** *(petit)* : TardisConfig est une table partagée par tous les scripts d'un même côté : un script peut la modifier par erreur pendant la partie. table.freeze sur les blocs de réglages fait planter tout de suite une écriture fautive au lieu d'un bug discret.
- **T-66. Rayon réel de l'explosion d'auto-destruction** *(petit)* : L'Explosion de l'auto-destruction a un BlastRadius de 1 000 000 avec DestroyJointRadiusPercent = 1 : elle peut casser tous les objets non ancrés de la carte, bien au-delà des 50 studs annoncés. Ramener le rayon à 50 et désactiver les cratères (ExplosionType).
- **T-70. Bouclier vidé par un objet resté contre la bulle** *(petit)* : Dans TardisSystemes (surveillerBouclier), chaque Touched d'une pièce non ancrée compte comme un tir, avec seulement 0,03 s d'écart : un objet ou un véhicule qui reste contre la bulle la vide en quelques secondes. Ignorer la même pièce pendant 1 s, ou ne compter que les objets rapides, garde l'énergie pour les vrais tirs.
- **T-67. Accès Adonis par une source vérifiée** *(petit)* : niveauAdonis lit _G.Adonis : n'importe quel script serveur (un modèle gratuit piégé, par exemple) peut se faire passer pour Adonis et donner l'accès pilote. Lire Adonis par son vrai module ou vérifier l'objet, et prévenir le journal si l'API change.
- **T-64. Clés de préférences permises** *(petit)* : L'action Prefs accepte n'importe quel JSON de 6000 caractères et le recopie dans un attribut lu par d'autres scripts. Une liste des clés permises, avec leur type, complète le schéma par action (qui ne voit qu'un texte).
- **T-68. Catégories limitées aux destinations existantes** *(petit)* : L'action Categorie accepte n'importe quel nom de 100 caractères et l'ajoute aux réglages sauvegardés, sans vérifier qu'il s'agit d'une vraie destination. Refuser les noms inconnus et nettoyer ceux qui ont disparu empêche la sauvegarde de grossir.
- **T-62. Listes d'accès hors de ReplicatedStorage** *(moyen)* : TardisConfig est dans ReplicatedStorage : tout client peut lire les UserIds des pilotes et techniciens, le chemin du module WL et du journal. Déplacer ces réglages sensibles dans un module serveur (ServerStorage) ne laisse au client que ce qu'il doit voir.
- **T-63. Données réservées aux pilotes non publiées à tous** *(moyen)* : Les incidents (pseudo, position), le registre, la liste des bannis, le carnet et le journal des régénérations sont des attributs lisibles par tous les clients, visiteurs compris. Les envoyer seulement aux joueurs qui y ont droit, à la demande.

**Dans Studio :** T-62 : créer un module dans ServerStorage pour les listes d'accès (UserIds, chemin du module WL, journal) et les retirer de TardisConfig.

*Pourquoi ici :* Courts d'abord : config figée par table.freeze (T-71), vrai rayon de l'explosion d'auto-destruction (T-66 : un BlastRadius de 1 000 000 peut casser toute la carte), bouclier qui ne se vide plus contre un objet immobile (T-70), Adonis lu par une source vérifiée (T-67). Puis les entrées du client, branchées sur le schéma de la V8 : clés de préférences permises (T-64), catégories limitées aux vraies destinations (T-68). Enfin les deux moyens : listes d'accès hors de ReplicatedStorage (T-62) et données réservées non publiées à tous (T-63), qui changent ce que lisent les interfaces.

### V13.2.14 — Serveur plus léger

**Objectif :** Faire moins de travail inutile côté serveur : boucles branchées au besoin, listes en mémoire, recherches ciblées.

- **T-56. Recherche du rayon tracteur espacée** *(petit)* : Quand rien n'est accroché, le rayon tracteur cherche une cible à chaque image (recherche de pièces et appel au pont pour chaque joueur). Chercher 4 fois par seconde donne le même résultat pour beaucoup moins de travail.
- **T-57. Boucles par image du serveur branchées au besoin** *(petit)* : Le temps de vol, le rayon tracteur et le suivi de véhicule ont chacun un Heartbeat permanent, même quand rien ne vole. Les brancher au début et les débrancher à la fin (ou compter le temps de vol par horodatage) libère le serveur.
- **T-59. Destinations republiées une fois par lot** *(petit)* : publierDestinations écoute seulement les enfants directs du dossier, alors que la liste lit aussi les sous-dossiers : une destination ajoutée dans ACCORDE n'est pas publiée. Écouter tous les descendants et regrouper les changements en une publication.
- **T-60. Liste des destinations gardée en mémoire** *(petit)* : listeDestinations parcourt et trie tout le dossier à chaque appel (écran, sélecteur, pont), et resoudreDestination cherche par nom dans toute l'arborescence. Une liste gardée en mémoire, refaite seulement quand le dossier change, rend ces appels instantanés.
- **T-61. Propriété réseau rendue après le rayon tracteur** *(petit)* : Le rayon tracteur prend la propriété réseau de l'objet attrapé (SetNetworkOwner(nil)) mais ne la rend jamais : le véhicule relâché reste saccadé pour son conducteur. Appeler SetNetworkOwnershipAuto au relâchement.
- **T-53. Explosions repérées sans écouter tout le Workspace** *(petit)* : Chaque exemplaire de TardisSystemes écoute workspace.DescendantAdded, appelé pour chaque objet créé dans tout le jeu. Écouter seulement les Explosion (ChildAdded du Workspace, ou un seul écouteur commun aux TARDIS) allège le serveur.
- **T-54. Entités repérées sans parcourir tout le Workspace** *(moyen)* : La détection des anomalies appelle workspace:GetDescendants() toutes les 10 s pour chaque TARDIS, très coûteux sur une grosse carte. Tenir une liste des Humanoid à jour (ajout et retrait) une seule fois pour tous les TARDIS.
- **T-55. Présence à bord calculée une fois pour tous** *(moyen)* : TardisServeur, TardisExtras et TardisSystemes calculent chacun « ce joueur est-il à bord ? », souvent par le pont, toutes les 0,2 à 2 s. Un seul calcul publié (une table partagée ou un attribut serveur par joueur) suffit à tous.

**Dans Studio :** Rien.

*Pourquoi ici :* Mesuré avec le compteur par module de la V9 et T-260. Courts d'abord : rayon tracteur espacé (T-56) et Heartbeat branchés au besoin (T-57), destinations publiées une fois et gardées en mémoire (T-59, T-60), propriété réseau rendue après le rayon tracteur (T-61). Puis les parcours de tout le Workspace dans TardisSystemes et TardisExtras : explosions (T-53), entités (T-54). T-55 calcule la présence à bord une fois pour les trois scripts serveur : en dernier.

### V13.2.15 — Attributs et signaux partagés

**Objectif :** Ranger les noms et formats des attributs, et ne plus répliquer chez tous ce qui n'est qu'un signal entre scripts.

- **T-85. Réglages écrits en dur déplacés dans la config** *(petit)* : Plusieurs valeurs sont fixées dans le code serveur : 15 minutes pour la saisie, 10 minutes pour la tempête de vortex, 35 studs pour la balise, 12 studs pour l'interphone, 20 s d'auto-destruction. Les mettre dans TardisConfig permet de les régler sans toucher au code.
- **T-88. Ancien chat ignoré quand le nouveau est actif** *(petit)* : La balise et /tardis écoutent à la fois TextChatService et l'ancien Player.Chatted, d'où un tri des doublons à la seconde près. N'écouter que le système de chat actif simplifie le code et supprime ce risque.
- **T-48. Attribut TardisPilote recalculé après tous les exemplaires** *(petit)* : verifierJoueur calcule « pilote quelque part » dans chaque exemplaire, dans un ordre de démarrage inconnu : la valeur peut rester fausse un moment. La recalculer à chaque changement d'un attribut TardisPilote_<Nom> la garde toujours juste.
- **T-83. Noms des attributs dans un seul module** *(moyen)* : Environ 150 noms d'attributs sont tapés à la main dans tous les scripts : une faute de frappe donne un bug silencieux. Une table de noms partagée, et un contrôle dans analyse.py, attrape ces erreurs.
- **T-69. Attributs en JSON plutôt qu'en tabulations** *(moyen)* : Interphone, Registre, Historique, Balises ou Roles sont des textes coupés par des tabulations : un texte de joueur qui en contient une décale tous les champs. Passer ces attributs en JSON supprime le problème et simplifie la lecture côté client.
- **T-82. Signaux internes au lieu d'attributs répliqués** *(moyen)* : En partie là : TardisSystemes réagit à des attributs comme ChocTemps, Catastrophe ou DescenteDebut, qui servent surtout de signal entre scripts et partent pourtant chez tous les clients. Un événement serveur interne suffit pour ce qui ne concerne pas les clients.

**Dans Studio :** Rien.

*Pourquoi ici :* T-85 sort les valeurs écrites en dur vers la config, T-88 n'écoute que le chat actif, T-48 recalcule TardisPilote au bon moment. T-83 met les ~150 noms d'attributs dans un module : c'est le socle de T-69 (Interphone, Registre, Historique, Balises, Roles en JSON plutôt qu'en tabulations) et de T-82 (signaux internes au lieu d'attributs répliqués). Les lecteurs côté client de T-69 changent en même temps : leur module partagé est T-171 (V13.3.13).

### V13.2.16 — Gros chantiers du serveur

**Objectif :** Typage strict du serveur, vortex animé par les clients et TARDIS unique entre les serveurs.

- **T-84. Typage strict des modules serveur** *(moyen)* : Activer --!strict sur TardisSauvegarde, VolLibre et TardisDiagnostic, avec des types pour les données sauvegardées. Les erreurs de type sont vues dans Studio avant d'arriver en jeu.
- **T-58. Vortex et Sauvetage animés par les clients** *(moyen)* : En vol, le serveur déplace la cabine dans le ciel à chaque image (partir_dans_le_ciel), et de même pendant la descente du Sauvetage : tout le modèle est renvoyé sur le réseau. Publier l'heure de départ et laisser les clients calculer le mouvement, en plus de la proposition « Moins d'attributs répliqués ».
- **T-89. TARDIS unique entre les serveurs** *(gros)* : Chaque serveur a sa propre copie de TARDIS_1 : deux pilotes peuvent le piloter en même temps sur deux serveurs. Un verrou MemoryStore indiquerait sur quel serveur il est « actif » et rendrait les autres copies inactives ou en lecture seule.

**Dans Studio :** Rien.

*Pourquoi ici :* T-84 passe TardisSauvegarde, VolLibre et TardisDiagnostic en --!strict (outil de T-224). T-58 confie l'animation du vortex et de la descente du Sauvetage aux clients : gros gain réseau, mais il touche TardisServeur et TardisEffets. T-89 (verrou MemoryStore : un seul serveur pilote TARDIS_1 à la fois) change la règle du jeu pour tous : en dernier, à confirmer avec le propriétaire.

## V13.3 — Client : performances et code (15 lots, 102 propositions)

Alléger les scripts du client (effets, vortex, vues de porte, interfaces) et ranger leur code commun, sans rien changer en jeu, pour les joueurs sur téléphone d'abord.

### V13.3.1 — Chargement et erreurs du client

**Objectif :** Qu'une erreur dans un module client ne bloque plus les autres, et que chaque interface ne soit créée que pour son TARDIS.

- **T-155. Modules client chargés chacun sous protection** *(petit)* : TardisExtrasClient/init.client.lua fait 17 require à la suite : une erreur dans Ambiance empêche de charger les 16 suivants, dont la régénération. Un pcall par module, avec un avertissement clair, garde le reste en marche (idem pour TardisTablette).
- **T-156. Remontée des erreurs chargée en premier** *(petit)* : Le module Supervision, qui envoie les erreurs au serveur, est chargé en avant-dernier : les erreurs des modules chargés avant lui ne sont jamais remontées. Le charger en tête de TardisExtrasClient.
- **T-157. Pile d'appel jointe aux erreurs remontées** *(petit)* : ScriptContext.Error donne la pile d'appel en 2ᵉ paramètre, ignoré dans Supervision.lua. En envoyer les premières lignes (bornées) permet de trouver la ligne fautive sans reproduire le bug.
- **T-159. Protection des boucles par image pour tous** *(petit)* : Seul TardisEffets protège ses effets avec proteger() ; ailleurs (menu, tablette, vol libre, EffetsExterieurs), une erreur dans un RenderStepped se répète à chaque image. Un utilitaire partagé, signalant chaque erreur une seule fois, généralise ce qui marche déjà.
- **T-152. Interfaces personnelles pour son seul TARDIS** *(moyen)* : TabletteTechnicien, Copilote, Maintenance et l'annonce de Signalisation créent leur ScreenGui pour chacun des TARDIS, car TardisExtrasClient est cloné par TARDIS. Ne construire que celles du TARDIS du joueur, les effets visibles restant pour tous.
- **T-180. Code « pour tous » sorti des scripts d'équipage** *(moyen)* : TardisVolLibre et TardisPorter disent suivre le TARDIS « pour tous les joueurs » mais commencent par Config.attendreMonTardis : un joueur sans rôle n'exécute jamais ce code (pas de vortex dans le ciel, pas de suivi lissé du TARDIS porté). Mettre cette partie dans un script lancé pour chaque TARDIS, comme TardisEffets.

**Dans Studio :** Rien.

*Pourquoi ici :* Socle : T-155 charge chaque module de TardisExtrasClient sous pcall (une erreur dans Ambiance ne bloque plus les 16 suivants), T-156 charge Supervision en premier, T-157 joint la pile d'appel aux erreurs. T-159 étend proteger() aux boucles du menu, de la tablette et du vol libre. Depuis la V11, les trois TARDIS sont là : T-152 (TabletteTechnicien, Copilote, Maintenance pour son seul TARDIS) et T-180 (code « pour tous » sorti des scripts d'équipage) évitent de tout créer trois fois.

### V13.3.2 — Mémoire du client

**Objectif :** Supprimer les fuites et réutiliser les objets au lieu d'en créer à chaque image.

- **T-131. Replay : tampon circulaire pour l'enregistrement** *(petit)* : Replay.lua retire le plus vieux des 6 000 échantillons avec table.remove(t, 1) dix fois par seconde, ce qui décale tout le tableau à chaque fois. Un tampon circulaire fait le même travail sans coût.
- **T-132. Replay : seul le bon exemplaire répond** *(petit)* : Les 3 exemplaires de TardisExtrasClient écoutent l'attribut TardisReplay : ceux qui n'ont rien enregistré le remettent aussitôt à faux, ce qui coupe le replay de l'exemplaire qui joue. Ne réagir que pour le TARDIS du joueur.
- **T-133. Archivable remis à sa valeur après copie** *(petit)* : Replay.lua passe exterieur.Archivable à true pour cloner le fantôme sans jamais le remettre, alors que TardisPortail le fait correctement. Garder et restaurer l'ancienne valeur.
- **T-134. Patchs du bouclier retirés au départ du joueur** *(petit)* : Boucliers.lua garde patchsContact[autre] tant que la bulle existe, même si ce joueur a quitté le jeu : la pièce reste affichée et en mémoire. Un PlayerRemoving détruit son patch.
- **T-137. Connexions des anciens personnages coupées** *(petit)* : Regeneration.lua branche plusieurs GetAttributeChangedSignal sur chaque personnage de chaque joueur. Si un ancien personnage est retiré sans être détruit, ses connexions et lui-même restent en mémoire ; les ranger et les couper à CharacterRemoving.
- **T-136. Tables faibles d'Instances remplacées par Destroying** *(moyen)* : registreCoins, registreBordures, registreCouleurs (TardisUI) et volumesOrigine (Preferences.lua) sont des tables faibles avec des Instances en clé : dans Roblox, une entrée peut disparaître alors que l'objet existe encore (thème ou volume non appliqué). Des tables normales nettoyées sur l'événement Destroying sont plus sûres.
- **T-124. Moins de tables Lua créées par image** *(petit)* : Exemples : { boutonDemat, boutonRemat } dans le RenderStepped du menu, cibles = {…} dans Ambiance, transparences et couleurs dans majVortex, racines dans TardisEffets. Réutiliser des tables vidées avec table.clear réduit les pauses du ramasse-miettes.
- **A-179. Moins d'objets créés par image** *(moyen)* : Réutiliser les pièces et particules au lieu d'en créer.

**Dans Studio :** Rien.

*Pourquoi ici :* Courts d'abord : Replay.lua (T-131 tampon circulaire, T-132 un seul exemplaire répond, T-133 Archivable remis), patchs du bouclier des joueurs partis (T-134), connexions des anciens personnages dans Regeneration.lua (T-137). T-136 remplace les tables faibles de TardisUI et Preferences par Destroying. T-124 et A-179 (pièces et particules réutilisées, laissé hors de la V9) réduisent ce qui est créé à chaque image. Contrôle avec T-215 et la simulation longue T-249.

### V13.3.3 — Fonctions communes du client

**Objectif :** Une seule version des petits calculs répétés partout, publiée une fois par image.

- **T-119. Une seule fonction « dans l'intérieur »** *(petit)* : dansInterieur est réécrite dans TardisEffets, TardisExtrasClient (marge de 20 studs), Suivi.lua, Outils.lua et TabletteTechnicien, avec des marges différentes. Une seule fonction Config.dansInterieur(def, position, marge) évite les écarts.
- **T-120. Une seule fonction alphaVol pour tous** *(petit)* : TardisEffets et TardisVolLibre ont chacun leur alphaVol : l'une teste Detruit, l'autre Camouflage. Une seule version dans TardisConfig empêche que les deux calculs divergent encore.
- **T-113. Attente du rôle par signal, pas par boucle** *(petit)* : Config.attendreMonTardis vérifie toutes les 2 s, pour toujours, chez chaque joueur sans rôle (6 scripts l'utilisent). Écouter les attributs TardisPilote_ et TardisTechnicien_ avec GetAttributeChangedSignal à la place.
- **T-114. Attente des modèles et destinations sans scrutation** *(petit)* : Config.modeles et Config.dossierDestinations attendent avec task.wait(0.5) et task.wait(1) en boucle. ChildAdded ou WaitForChild répondent tout de suite, sans travail pendant l'attente.
- **T-166. Modules uniques signalés par un drapeau commun** *(petit)* : Regeneration, Supervision et Intercom testent chacun def.Nom == Config.Tardis[1].Nom pour ne tourner qu'une fois par joueur. Un champ contexte.premier (ou une liste des modules uniques dans init) rend cette règle visible et évite de l'oublier.
- **T-194. Liste des joueurs et racines en cache** *(petit)* : Players:GetPlayers() et FindFirstChild("HumanoidRootPart") sont appelés à chaque image dans TardisEffets, Boucliers, la tablette et le vol libre, et chaque appel crée une nouvelle table. Une liste partagée mise à jour sur PlayerAdded et CharacterAdded suffit.
- **T-121. État du voyage calculé une fois par image** *(moyen)* : Config.Souffle, Config.Timing et Config.Alpha sont recalculés pour le même TARDIS dans TardisEffets, TardisMenu, Suivi.lua, Signalisation et EffetsExterieurs. Un petit cache par TARDIS, calculé une fois par image et lu par tous, complète le regroupement des boucles (177).
- **T-122. Présence à bord calculée une fois et signalée** *(moyen)* : jeSuisDedans() est appelée à chaque image par Ambiance, Signalisation, TabletteTechnicien, Interactions et d'autres. Un module calcule dedans/dehors quelques fois par seconde, avec une petite marge pour éviter les clignotements, et envoie un signal au changement.

**Dans Studio :** Rien.

*Pourquoi ici :* Socle avant usage : une seule fonction dansInterieur (T-119) et alphaVol (T-120) dans TardisConfig, attentes par signal et non par boucle (T-113 attendreMonTardis, T-114 modèles et destinations), drapeau commun des modules uniques (T-166), joueurs et racines en cache (T-194). Puis l'état du voyage (T-121) et la présence à bord (T-122) calculés une fois par image : les lots suivants (effets, sons, interfaces) les lisent au lieu de recalculer.

### V13.3.4 — TardisUI plus léger

**Objectif :** Alléger le module d'interface partagé et y centraliser l'échelle et l'ordre d'affichage.

- **T-187. Rôle des couleurs trouvé par table directe** *(petit)* : UI.creer cherche le rôle de chaque couleur en parcourant ROLES_COULEUR, pour chaque propriété de chaque objet créé. Une table inverse couleur → rôle, refaite au changement de thème, rend la création des interfaces plus rapide.
- **T-186. UI.setDisponible sans parcourir les descendants** *(petit)* : UI.setDisponible parcourt tous les descendants du bouton à chaque appel, et majInterface l'appelle pour chaque tuile. Mémoriser les TextLabel du bouton à sa création.
- **T-190. Statistiques décodées une fois par changement** *(petit)* : UI.debutant décode le JSON de TardisStats à chaque appel, et UI.widgetVisible l'appelle pour chaque panneau. Décoder une fois quand l'attribut change et garder le résultat.
- **T-189. Préférences envoyées seulement si elles changent** *(petit)* : UI.sauverPrefs renvoie tout le JSON au serveur même si rien n'a changé (par exemple en recliquant la même option). Comparer avec le dernier envoi évite des écritures et des sauvegardes inutiles.
- **T-188. Confirmation qui garde le texte à jour** *(petit)* : UI.confirmer remet après 3 s le texte gardé dans l'attribut TexteOrigine : si majInterface a changé le texte entre-temps, l'ancien revient. Redemander le texte à jour à l'interface plutôt que de restaurer une copie.
- **T-184. Textes d'interface écrits seulement s'ils changent** *(petit)* : L'horloge (os.date) de la tablette et de la tablette technicien, la progression du menu ou la vitesse du vol libre (string.format) sont réécrites à chaque image. Comparer avant d'écrire évite de refaire la mise en page du texte.
- **T-110. Mises à jour du menu regroupées par image** *(petit)* : TardisMenu branche majInterface sur 35 attributs, et Outils.lua majOutils sur 23 : quand le serveur en change dix d'un coup, l'interface est refaite dix fois. Un drapeau et un task.defer n'en font qu'une par image.
- **T-198. Changement de thème étalé sur plusieurs images** *(petit)* : UI.appliquerTheme parcourt tous les objets enregistrés et fait un pcall par propriété, d'un coup : avec la tablette, le menu et les extras, cela fait une image très longue. Traiter les objets par paquets.
- **T-197. Ordres d'affichage des interfaces centralisés** *(petit)* : Les DisplayOrder sont écrits un par un (12, 19, 20, 21, 30), et Maintenance et Intercom ont tous deux 30. Un tableau unique dans TardisUI dit qui passe devant qui.
- **T-199. Échelle de l'écran calculée dans TardisUI** *(petit)* : TardisMenu, TardisVolLibre, TardisRotation, Suivi.lua et Copilote calculent chacun leur échelle à partir de ViewportSize, Copilote toutes les 0,25 s. Un seul calcul dans TardisUI, avec un signal au changement de taille.

**Dans Studio :** Rien.

*Pourquoi ici :* Tout dans TardisUI, utilisé par tous les scripts client. Tables directes (T-187 rôles des couleurs, T-186 setDisponible, T-190 statistiques décodées une fois), envois et textes seulement s'ils changent (T-189, T-184), confirmation qui garde le texte à jour (T-188), mises à jour du menu regroupées par image (T-110), thème étalé sur plusieurs images (T-198). Enfin deux tableaux centraux : DisplayOrder (T-197) et échelle de l'écran (T-199), dont se servent les V13.4 à V13.6.

### V13.3.5 — Effets de la salle par image

**Objectif :** Alléger la boucle principale de TardisEffets et les lumières de la salle.

- **T-182. Réglages lus une fois hors des boucles** *(petit)* : Dans les boucles par image : (Config.Modes[x] or {}), (Config.Technicien or {}).SousTension, Config.CouleurAlerte or Color3.fromRGB(…), themeChoisi() qui parcourt Config.Themes. Les lire une fois au chargement ou au changement d'attribut.
- **T-104. LEDs d'alerte gardées en liste** *(petit)* : Dans la boucle principale de TardisEffets, interieur:FindFirstChild("LedsAlerte") puis leds:GetDescendants() sont appelés à chaque image. Les garder en liste, mise à jour par DescendantAdded comme listeLumieres, supprime ce parcours.
- **T-105. Taille de la cabine mise en cache** *(petit)* : exterieur:GetExtentsSize() est appelé à chaque image dans la lueur de TardisEffets et dans EffetsExterieurs, ce qui coûte cher sur un modèle détaillé. La recalculer seulement quand l'attribut Echelle change.
- **T-106. Fonctions de proteger() créées une seule fois** *(petit)* : Dans le RenderStepped de TardisEffets, chaque proteger("…", function() … end) fabrique une nouvelle fonction à chaque image. Les déclarer une fois hors de la boucle allège le ramasse-miettes, surtout sur téléphone.
- **T-139. Tables d'origine nettoyées quand un objet disparaît** *(petit)* : ledsOrigine et lumieresSalle (TardisEffets) gardent les lumières supprimées pour toujours, car rien ne les retire. Les retirer sur DescendantRemoving de l'intérieur, comme le fait déjà la table visuels.
- **T-130. Couleurs d'origine relues après une customisation** *(petit)* : TardisEffets mémorise une fois les couleurs des néons du rotor (neonsRotor) et des lumières de la salle (lumieresSalle). Après un changement de style, le fondu ramène l'ancienne couleur ; relire ces origines quand le style change.
- **T-142. Lumières éteintes de la salle vraiment désactivées** *(petit)* : Le bloc « lumières » de TardisEffets éteint une pièce vide en mettant Brightness à 0, mais la Light reste active et le moteur continue de la traiter. Passer Enabled à false quand le facteur est presque nul, et la rallumer à l'approche d'un joueur.
- **T-185. Lumières de la salle : joueurs proches seulement** *(petit)* : Le bloc « lumières » de TardisEffets construit la liste des racines de tous les joueurs à chaque image, avant même de vérifier si la caméra est à moins de 350 studs. Faire ce test d'abord et ne garder que les joueurs proches de l'intérieur.
- **T-101. Lighting modifié seulement à bord du TARDIS** *(moyen)* : Le bloc « ambiance » de TardisEffets réécrit Lighting.Ambient et OutdoorAmbient à chaque image, même quand le joueur est dehors : cela fige le cycle jour/nuit de ZONE-TSADE et, dès la V10, les 3 exemplaires se battent pour la même valeur. N'écrire que quand le joueur entre, sort ou que le thème change.

**Dans Studio :** Rien.

*Pourquoi ici :* Dans la boucle RenderStepped de TardisEffets (environ 1 350 lignes). Réglages lus hors des boucles (T-182), LEDs d'alerte en liste (T-104), taille de la cabine en cache (T-105), fonctions de proteger() créées une fois (T-106). Puis les lumières : tables nettoyées (T-139), couleurs relues après customisation (T-130), lumières vraiment désactivées (T-142), joueurs proches seulement (T-185). T-101 (Lighting modifié seulement à bord) change ce que voit le joueur dehors : en dernier.

### V13.3.6 — Effets d'écran et qualité graphique

**Objectif :** Un seul module pour les effets d'écran et les secousses, et des effets adaptés à la qualité graphique du joueur.

- **T-102. Effets d'écran partagés entre les exemplaires** *(moyen)* : TardisEffets (TardisAmbiance), EffetsExterieurs (TardisDistorsion, TardisDistorsionTeinte) et TabletteTechnicien (TardisAirVicie_) créent chacun leurs effets dans Lighting, et cela pour chaque TARDIS : jusqu'à 9 effets d'écran. Un petit module qui additionne les demandes et ne garde qu'un Blur et une ColorCorrection.
- **T-103. Secousses de caméra additionnées dans un module** *(moyen)* : TardisEffets écrit Humanoid.CameraOffset puis le remet à zéro, et EffetsExterieurs a sa propre secousse (BindToRenderStep TardisExtrasSecousse) : un exemplaire peut annuler la secousse d'un autre. Un module partagé reçoit les demandes de chaque script et écrit une seule fois par image.
- **T-140. Effets locaux rangés dans un dossier par TARDIS** *(petit)* : piece() et partTemporaire posent les pièces d'effet directement dans workspace (TardisLueur_, TardisOmbre, TardisAir, TardisProjecteur, TardisViseur…), certaines sans le nom du TARDIS. Un dossier par TARDIS permet de les retrouver, les compter et tout nettoyer d'un coup.
- **T-193. Nombre de Highlight sous la limite Roblox** *(petit)* : Roblox n'affiche qu'environ 31 Highlight à la fois ; la régénération en ajoute un par personnage, la tablette technicien un marqueur, d'autres effets aussi. Les réutiliser ou les limiter évite qu'un effet important disparaisse sans raison visible.
- **T-147. Qualité graphique Roblox lue au démarrage** *(moyen)* : Lire le réglage de qualité du joueur (UserSettings().GameSettings.SavedQualityLevel) pour choisir le nombre d'anneaux du vortex et le rayon de la vue de la rue. Cela complète la réduction selon les images par seconde (47) sans attendre que le jeu rame.
- **T-148. Ombres des lumières d'effet selon la qualité** *(petit)* : Plusieurs lumières d'effet ont Shadows = true (projecteur, éclats de la régénération), ce qui coûte cher sur téléphone. N'activer ces ombres qu'en qualité haute et jamais en « réduire les effets ».

**Dans Studio :** Rien.

*Pourquoi ici :* T-102 et T-103 réunissent les effets d'écran (TardisAmbiance, TardisDistorsion, TardisAirVicie_) et les secousses de caméra de TardisEffets, EffetsExterieurs et TabletteTechnicien : un module au lieu de trois, réutilisé par les effets d'écran de la V13.10. T-140 range les pièces d'effet dans un dossier par TARDIS, T-193 garde les Highlight sous la limite Roblox. T-147 (qualité graphique lue) et T-148 (ombres selon la qualité) complètent l'allègement selon les images par seconde de la V9.

### V13.3.7 — Sons et décor de la cabine

**Objectif :** Des sons gérés une seule fois et un décor de cabine qui ne calcule que quand il le faut.

- **T-154. Préchargement des sons lancé une seule fois** *(petit)* : TardisEffets lance PreloadAsync de tous les sons dans chacun de ses exemplaires, donc trois fois avec 3 TARDIS. Un seul appel (premier exemplaire ou module partagé) suffit, en attendant le préchargement intelligent (182).
- **T-141. Volume appliqué une seule fois aux sons d'effet** *(petit)* : Chaque exemplaire de Preferences.lua surveille workspace.ChildAdded pour les objets « Tardis… » : dès la V10, un même son serait baissé trois fois (volume 0,5 devenant 0,125). Ne surveiller que ses propres effets, en attendant les SoundGroup de la 133.
- **T-111. Sons de moteur muets mis en pause** *(petit)* : Ambiance.lua garde les trois boucles Moteur_Pose, Moteur_Vol et Moteur_Urgence en lecture pour chaque TARDIS, même à volume 0 ou loin du TARDIS. Les mettre en pause quand leur volume reste nul et les relancer au besoin libère des voix audio, surtout sur téléphone.
- **T-167. Liens entre modules sans délai de 3 secondes** *(petit)* : Signalisation retrouve les sons Moteur_ créés par Ambiance avec task.delay(3) : si Ambiance est lent, l'ambiance par thème ne trouve rien. Ambiance renvoie sa liste de moteurs et init la passe à Signalisation.
- **T-116. Décorations déplacées seulement quand la cabine bouge** *(petit)* : Decor.lua replace chaque pièce de décoration (citrouille, guirlandes…) avec CFrame à chaque image, même quand le TARDIS est posé. Ne les déplacer que si le pivot a changé, ou les souder à la Racine avec une WeldConstraint.
- **T-117. Projecteur : boucle et ombres seulement s'il est allumé** *(petit)* : EffetsExterieurs crée pour chaque TARDIS une SpotLight avec Shadows = true et recrée une NumberSequence pour le cône à chaque image, même éteint. Couper la mise à jour et les ombres quand l'attribut Projecteur est faux.
- **T-118. Détection des vitres commune à Effets et Decor** *(petit)* : estVitre (TardisEffets) et la recherche des reflets dans Decor.lua n'utilisent pas la même règle : Decor ignore le dossier Fenetres et le préfixe Vitre. Une fonction partagée dans TardisConfig donne la même liste aux deux.
- **A-48. Son et effet synchronisés sur mobile** *(moyen)* : Vérifier et caler les effets sur les appareils lents.

**Dans Studio :** Rien. A-48 se vérifie sur un vrai téléphone.

*Pourquoi ici :* Ambiance, Preferences, Signalisation, Decor et EffetsExterieurs. Sons d'abord : préchargement lancé une fois (T-154), volume appliqué une fois (T-141), moteurs muets mis en pause (T-111), Signalisation qui trouve les sons d'Ambiance sans délai de 3 s (T-167). Décor : décorations déplacées seulement si la cabine bouge (T-116), projecteur calculé seulement allumé (T-117), même règle des vitres pour Effets et Decor (T-118). A-48 (son et effet calés sur mobile) se vérifie en dernier.

### V13.3.8 — Vortex et vol libre plus légers

**Objectif :** Alléger le vortex et le pilotage, et prévoir une sortie de secours si le pilotage plante.

- **T-108. Vortex : Beams cachés désactivés selon la forme** *(petit)* : En forme « spirale » ou « anneaux », majVortex remet Transparency = NumberSequence.new(1) sur la moitié des Beams à chaque image. Les désactiver (Enabled = false) une fois au changement de forme et sauter leur mise à jour.
- **T-107. Vortex : couleurs mises à jour moins souvent** *(moyen)* : majVortex (TardisVolLibre) réécrit Transparency et Color d'environ 460 Beams à chaque image, avec de nouvelles NumberSequence. Les mettre à jour 15 fois par seconde et seulement si la valeur a changé, en gardant le mouvement des points à chaque image.
- **T-125. Cible de formation sans parcourir tout workspace** *(petit)* : basculerCible (TardisVolLibre) fait workspace:GetDescendants() pour trouver les VehicleSeat occupés, ce qui peut figer l'image sur une grande carte SCP. workspace:GetPartBoundsInRadius autour de la caméra, à la portée de Formation, ne regarde que les environs.
- **T-195. Envois au serveur sautés quand rien ne bouge** *(petit)* : Le vol libre envoie sa position 15 fois par seconde même en stationnaire, et EffetsExterieurs la direction du projecteur toutes les 0,12 s même caméra immobile. Ne rien envoyer si la valeur n'a presque pas changé ; c'est le côté client de la 180.
- **T-135. Sons temporaires détruits même sans Ended** *(petit)* : UI.son et le son de phase du vol libre (VolPhase dans TardisVolLibre) ne détruisent leur Sound qu'à Ended : si le son ne se charge pas, il reste pour toujours. Ajouter une destruction de secours (Debris) ou utiliser SoundService:PlayLocalSound pour les bips.
- **T-160. Sortie de secours si le pilotage plante** *(petit)* : Si piloter() (TardisVolLibre) plante en boucle, le pilote garde une caméra Scriptable et des contrôles coupés. Après quelques erreurs de suite, appeler sortirPilotage() et demander l'atterrissage, pour ne jamais laisser un joueur bloqué.
- **T-143. Zone chargée autour de la cabine en vol libre** *(petit)* : En vol libre, le pilote reste dans l'intérieur, donc le Streaming charge le décor autour de lui et non autour de la cabine : collisions, viseur et hauteur du sol peuvent rater des pièces. Appeler RequestStreamAroundAsync autour de la cabine tous les 200 studs environ.
- **T-179. Vortex sorti dans un module réutilisable** *(moyen)* : creerVortex, majVortex et detruireVortex (TardisVolLibre) servent au vol libre et au tube du voyage classique dans le ciel. Un module à part, avec sa propre mise à jour, se teste et s'allège plus facilement.

**Dans Studio :** Rien.

*Pourquoi ici :* Dans TardisVolLibre (environ 1 600 lignes). Le vortex d'abord : Beams cachés désactivés (T-108), couleurs des ~460 Beams moins souvent (T-107). Puis cible de formation sans GetDescendants (T-125), envois sautés en stationnaire (T-195), sons temporaires détruits même sans Ended (T-135), sortie de secours si piloter() plante (T-160), zone chargée autour de la cabine (T-143). T-179 sort le vortex dans un module réutilisable : en dernier, quand le code est allégé.

### V13.3.9 — Vue de la rue

**Objectif :** Copier la rue vue depuis la salle sans figer l'image, même avec le Streaming.

- **T-138. Cache d'exclusion vidé après la copie de rue** *(petit)* : La table exclus de TardisPortail garde une référence vers presque chaque objet de la carte jusqu'à la copie suivante, ce qui empêche la mémoire des pièces détruites d'être libérée. La vider dès la fin de clonerEnvirons.
- **T-169. Reconstruction de la vue de rue par jeton** *(petit)* : Dans TardisPortail, l'atterrissage (avec task.wait(0.5)) et la boucle du vol peuvent lancer reconstruireEnvirons presque en même temps : une ancienne copie qui finit en dernier remplace la bonne. Un numéro de demande, vérifié à la fin, ne garde que la plus récente.
- **T-127. Copie de la rue étalée sur plusieurs images** *(petit)* : Même avec moins de pièces, cloner des centaines de Parts d'un coup dans clonerEnvirons crée une image très longue. Cloner par paquets (par exemple 50) avec un task.wait() entre deux, l'ancienne vue restant affichée jusqu'à la fin.
- **T-126. Vue de la rue sans parcourir toute la carte** *(moyen)* : clonerEnvirons (TardisPortail) parcourt workspace:GetDescendants() à chaque atterrissage, et pour chaque TARDIS. workspace:GetPartBoundsInRadius(centre, rayon) donne directement les pièces proches et évite un gros à-coup.
- **T-158. Plafond de pièces dans la vue en vol** *(petit)* : Portes ouvertes en vol libre, clonerEnvirons copie toutes les pièces de plus de 4 studs dans 600 studs, et recommence tous les 250 studs : sur une grande carte, cela peut faire des milliers de clones. Un nombre maximal de pièces, en gardant les plus grandes et les plus proches, borne la mémoire.
- **T-145. Vue de la rue refaite après chargement de zone** *(petit)* : clonerEnvirons ne copie que ce qui est chargé à l'instant : avec le Streaming, la vue de la rue peut rester presque vide après un voyage. Refaire la copie une fois RequestStreamAroundAsync terminé.
- **T-144. Zone d'arrivée chargée avant de sortir** *(petit)* : Après un long voyage, les passagers sortent par traverser (TardisPortail) vers un endroit peut-être pas encore chargé. Demander le chargement autour de la porte dès le début de la Remat, pour ceux qui sont à bord.

**Dans Studio :** Rien.

*Pourquoi ici :* Tout dans TardisPortail (clonerEnvirons, traverser). Mémoire et ordre d'abord : cache d'exclusion vidé (T-138), reconstruction par jeton (T-169). Puis la copie : étalée sur plusieurs images (T-127), sans parcourir toute la carte (T-126), plafond de pièces en vol (T-158). Avec le Streaming : vue refaite après chargement (T-145), zone d'arrivée chargée avant de sortir (T-144).

### V13.3.10 — Vue de l'intérieur par la porte

**Objectif :** Une seule fonction de copie visuelle, et une vue de porte à jour, légère et adaptée à l'appareil.

- **T-192. Une seule fonction de copie visuelle** *(petit)* : TardisPortail (nettoyer), Replay.lua (fantôme) et la lueur des vitres de TardisEffets retirent chacun scripts, sons et prompts de leurs copies, avec des listes différentes. Une fonction partagée « copie visuelle » évite d'oublier une classe.
- **T-129. Vue de la porte à jour après customisation** *(petit)* : copieInterieur n'est faite qu'une fois au chargement : après un changement de StyleInterieur, StyleConsole ou CouleurMurs, la vue par la porte montre l'ancien décor. Refaire la copie (ou recopier couleurs et matériaux) sur ces attributs.
- **T-191. Copies de la vue suivies seulement si elles bougent** *(petit)* : Le BindToRenderStep TardisVue_ recopie à chaque image le pivot du rotor et la CFrame de chaque battant dans la vue, même immobiles. Ne recopier que si l'original a bougé.
- **T-150. Vue de porte ignorée hors de l'écran** *(petit)* : majFenetre (TardisPortail) met la vue à jour dès que la porte est ouverte et proche, même si elle est derrière la caméra. Tester d'abord si le portail est à l'écran (WorldToViewportPoint) et cacher la vue sinon.
- **T-149. Résolution des vues de porte selon l'appareil** *(petit)* : Les deux SurfaceGui du portail utilisent toujours Config.PixelsParStud. Une valeur plus basse sur petit écran ou en qualité basse réduit le travail des ViewportFrame sans changer le principe de la vue.
- **T-128. Copie de l'intérieur créée seulement à l'approche** *(moyen)* : TardisPortail clone tout l'intérieur dans un ViewportFrame au chargement, pour chaque TARDIS, même à des kilomètres. La créer quand le joueur passe sous Config.DistanceVueMax et la détruire quand il s'éloigne libère beaucoup de mémoire.

**Dans Studio :** Rien.

*Pourquoi ici :* T-192 crée une seule fonction de copie visuelle (TardisPortail, Replay, lueur des vitres) : socle des autres. Vue à jour après customisation (T-129), copies suivies seulement si elles bougent (T-191), vue ignorée hors de l'écran (T-150), résolution selon l'appareil (T-149). T-128 (copie de l'intérieur créée seulement à l'approche) est le plus gros changement : en dernier.

### V13.3.11 — Menu et tablette : boucles et écrans

**Objectif :** Arrêter les boucles inutiles des interfaces et partager leurs animations et calculs.

- **T-109. CarteDestinations analysée seulement quand elle change** *(petit)* : TabletteLecture découpe la chaîne CarteDestinations avec gmatch toutes les 0,5 s. Garder le résultat tant que la chaîne ne change pas, comme le fait déjà lireDestinations dans Scanner.lua.
- **T-112. Destination de poche confiée à TardisCommandes** *(petit)* : TardisMenu et Navigation.lua ont chacun la même boucle de 0,2 s qui recopie le choix dans UI.destinationPoche, et le dernier qui écrit gagne. Une fonction Commandes.choisir(choix), appelée au clic, remplace les deux boucles.
- **T-115. Boucles d'arrière-plan arrêtées interface fermée** *(petit)* : Copilote (0,25 s), TardisPorter (0,3 s), Interactions, Maintenance, TardisPortail et Outils.lua (deux boucles d'1 s) tournent en task.spawn(while true) même quand rien n'est ouvert. Les lancer à l'ouverture ou au bon attribut, et les arrêter ensuite.
- **T-183. Barre tactile du menu sans Heartbeat permanent** *(petit)* : Sur téléphone, TardisMenu garde un Heartbeat qui fait glisser la barre des boutons T et Y à chaque image, menu ouvert ou non. Un tween lancé à l'ouverture et à la fermeture suffit.
- **T-196. Animations d'interface en pause sans focus** *(petit)* : Quand la fenêtre de Roblox perd le focus (WindowFocusReleased), les animations purement décoratives du menu et de la tablette peuvent s'arrêter. Utile sur ordinateur portable et pour la batterie des appareils mobiles.
- **T-153. Zone sûre des écrans à encoche respectée** *(petit)* : Plusieurs interfaces ont IgnoreGuiInset = true (annonce de bord, vol libre, régénération) et peuvent passer sous l'encoche d'un téléphone. Utiliser ScreenInsets = DeviceSafeInsets pour les éléments à lire ou à toucher.
- **T-123. Animations décoratives communes au menu et tablette** *(petit)* : Les anneaux qui tournent, le vortex de l'en-tête et la lueur des boutons DÉMAT/REMAT sont codés deux fois, dans TardisMenu et dans Suivi.lua. Une fonction commune dans TardisUI évite de corriger deux fois.
- **T-200. Calculs des interfaces en fonctions pures** *(moyen)* : Les pourcentages, comptes à rebours (T-…) et états des boutons sont calculés au milieu des RenderStepped du menu et de la tablette. Les sortir en petites fonctions sans Instance permet de les vérifier dans les simulations existantes.

**Dans Studio :** Rien.

*Pourquoi ici :* Après la V12, ces boucles servent surtout à TARDIS_2 et TARDIS_3, au copilote et au technicien. Courts d'abord : CarteDestinations analysée seulement si elle change (T-109), destination de poche confiée à TardisCommandes (T-112), boucles arrêtées interface fermée (T-115), barre tactile sans Heartbeat (T-183), animations en pause sans focus (T-196), zone sûre des encoches (T-153). Puis le partage : animations communes au menu et à la tablette (T-123), calculs en fonctions pures (T-200), qui rendent ces écrans testables.

### V13.3.12 — Caméra, touches et contrôles

**Objectif :** Un seul propriétaire de la caméra, des contrôles et des touches à la fois.

- **T-164. Priorités de rendu rangées dans un tableau** *(petit)* : TardisCamera et l'impact du vol libre (TardisImpact) sont tous deux à RenderPriority.Camera + 2, donc leur ordre n'est pas garanti ; le portail et la secousse utilisent -1, +1 et +3. Un tableau unique des priorités dans TardisConfig rend l'ordre voulu explicite.
- **T-181. Répétition des boutons maintenus arrêtée à coup sûr** *(petit)* : maintenu() (TardisRotation) répète l'action toutes les 0,08 s jusqu'à l'InputEnded du bouton ; si le doigt glisse hors du bouton, la fin peut ne jamais arriver et la rotation continue en envoyant des requêtes. Arrêter aussi sur la fin de toute entrée (UserInputService.InputEnded) et sur MouseLeave.
- **T-162. Contrôles du personnage bloqués en un seul endroit** *(petit)* : TardisVolLibre (controles) et TardisCamera (controlesPersonnage) font chacun require du PlayerModule et activent ou coupent les contrôles : quitter la caméra peut les rendre en plein vol libre. Un compteur partagé ne les rend qu'une fois personne ne les bloque plus.
- **T-161. Un seul propriétaire de la caméra à la fois** *(moyen)* : TardisCamera, TardisVolLibre, Replay, TardisRotation, AutoDestruction et la régénération prennent la caméra chacun de leur côté et la rendent en Custom. Un petit module qui sait qui l'a, et la rend proprement (même après une erreur), évite qu'un script coupe un autre.
- **T-163. Priorité des touches avec ContextActionService** *(moyen)* : La touche X sert à quitter la caméra (TardisCamera), à la téléportation de poche (TardisPorter) et à la démat en vol libre, chacun via InputBegan. BindActionAtPriority donne la touche au mode actif seulement, sans déclencher deux actions.

**Dans Studio :** Rien.

*Pourquoi ici :* TardisCamera, TardisVolLibre, TardisRotation, Replay, AutoDestruction et Regeneration prennent la caméra et les touches chacun de leur côté. Petits d'abord : priorités de rendu dans un tableau (T-164), répétition des boutons maintenus arrêtée à coup sûr (T-181), contrôles du personnage bloqués en un seul endroit (T-162). Puis un seul propriétaire de la caméra (T-161) et ContextActionService pour les touches (T-163), qui règle le conflit de la touche X. La V13.10 (vues de caméra) s'appuie dessus.

### V13.3.13 — Messages et commandes du client

**Objectif :** Côté client, des noms d'actions sûrs, un seul routeur de messages et des formats d'attributs partagés.

- **T-170. Noms des actions envoyées en constantes** *(petit)* : Les remote:FireServer("VolLibreCamouflage"), ("SiegePose")… sont écrits en texte libre dans le menu, la tablette, le vol libre et les extras. Une liste partagée, qui peut reprendre celle du garde-barrière de la V7, évite une action mal orthographiée ignorée en silence.
- **T-173. TardisCommandes protégé avant son démarrage** *(petit)* : Commandes.demat, remat et le minuteur de remat automatique appellent remote:FireServer sans vérifier que demarrer a été appelé. Un message clair « Commandes non démarrées » remplace l'erreur « attempt to index nil ».
- **T-168. Messages spéciaux reçus par un seul routeur** *(moyen)* : "__paradoxe", "__decouverte" et "__invitation" arrivent par le même OnClientEvent que les notifications, et TardisCommandes, le menu, la tablette et Preferences.lua filtrent chacun ; Preferences cherche même « INTRUSION » dans le texte pour jouer l'alerte. Un routeur client unique distribue chaque message à son gestionnaire.
- **T-171. Formats texte des attributs dans un module** *(moyen)* : CarteDestinations, ListeDestinations ou Interphone (« origine\tnom\tmessage\t ») sont découpés à la main avec string.match dans plusieurs scripts. Un module de formats partagé (encoder / décoder) garantit que client et serveur lisent pareil.
- **T-172. TardisCommandes : un objet par TARDIS** *(moyen)* : Commandes.demarrer ne garde que le premier extérieur reçu (« seul le premier appel compte ») : un joueur pilote de deux TARDIS en V10 enverrait ses commandes au mauvais. Un objet Commandes par TARDIS, avec ses propres protocoles et minuteurs.

**Dans Studio :** Rien.

*Pourquoi ici :* En miroir de la V8 et de V13.2.15. Noms des actions en constantes (T-170, tirés de la liste du garde-barrière de la V8), TardisCommandes protégé avant son démarrage (T-173). Un seul routeur pour __paradoxe, __decouverte et __invitation (T-168), formats des attributs dans un module (T-171, avec T-69 côté serveur). T-172 (un objet TardisCommandes par TARDIS) en dernier : depuis la V11 un pilote n'a qu'un TARDIS, donc à revoir avant de le faire.

### V13.3.14 — Typage strict du client

**Objectif :** Passer les modules partagés du client en --!strict, dans un ordre fixé.

- **T-178. Plan de passage au typage strict** *(petit)* : Aucun fichier n'a de mode --!strict ni --!nonstrict. Fixer l'ordre : modules partagés, puis petits modules (Maintenance, Preferences, Replay), puis gros scripts, avec --!nonstrict explicite en attendant.
- **T-174. Typage strict d'abord sur TardisCommandes** *(petit)* : Module court, sans interface, partagé par le menu et la tablette : ajouter --!strict et des types (Choix de destination, Donnees envoyées) est un premier pas sans risque. Il sert de modèle pour les autres modules.
- **T-175. Types exportés pour la configuration** *(moyen)* : TardisConfig n'a aucun type : Config.Modes[mode].CouleurRotor ou def.Pilotes sont lus sans vérification. Exporter des types (ModeVoyage, DefTardis, ReglagesVolLibre) fait vérifier tous les scripts client qui les lisent.
- **T-176. TardisUI passé en mode strict** *(moyen)* : TardisUI est utilisé par tous les scripts client : typer creer, texte, interrupteur (regler, surChangement) et les préférences fait apparaître les mauvais usages partout d'un coup. À faire après TardisCommandes.
- **T-177. Types des tables d'état W, S et vol** *(moyen)* : La tablette range ses éléments dans W et son état dans S (pour éviter la limite de 200 variables locales), le vol libre dans vol. Un type pour chacune signale un champ mal nommé ou oublié, fréquent dans ces grosses tables.
- **T-165. Contexte des modules décrit par un type** *(moyen)* : Les modules de TardisExtrasClient et TardisTablette reçoivent une grande table contexte (jusqu'à 22 champs) : une faute de nom donne nil sans erreur. Un type Luau Contexte par dossier fait signaler l'erreur par l'éditeur.

**Dans Studio :** Rien.

*Pourquoi ici :* Après T-224 (V13.1.4) et le code rangé par les lots précédents. Règle avant travail : T-178 fixe l'ordre. Puis TardisCommandes, court et sans interface (T-174), types exportés de TardisConfig (T-175), TardisUI (T-176), tables d'état W, S et vol (T-177), contexte des modules (T-165).

### V13.3.15 — Gros chantiers du client

**Objectif :** Tablette construite seulement à la première ouverture, et intérieurs en streaming Atomic.

- **T-151. Tablette construite à la première ouverture** *(gros)* : Construction.lua bâtit toute la tablette (1280×760, des centaines d'objets) au chargement, même pour un pilote qui ne l'ouvre jamais. La construire au premier appui sur Y, puis la garder, allège le démarrage et la mémoire.
- **T-146. Intérieurs en streaming Atomic au lieu de Persistent** *(gros)* : Le README impose ModelStreamingMode = Persistent : chaque joueur garde en mémoire tous les intérieurs, même loin. Passer les intérieurs en Atomic et faire réagir les scripts client à leur arrivée et à leur départ (références relues) prépare les 3 TARDIS de la V10.

**Dans Studio :** T-146 : passer les Models des intérieurs en ModelStreamingMode Atomic (au lieu de Persistent) et mettre à jour le README.

*Pourquoi ici :* T-151 construit la tablette (Construction.lua, des centaines d'objets) à sa première ouverture : utile tant que TARDIS_2 et TARDIS_3 gardent leur tablette. T-146 change une règle d'installation et touche tous les scripts qui cherchent l'intérieur : le plus risqué, en tout dernier, vérifié avec la simulation sur téléphone (T-268).

## V13.4 — Menu rapide T (14 lots, 101 propositions)

Améliorer le menu T (TardisMenu) : recherche, liste, protocoles, statut et mobile. Après la V12, TARDIS_1 n'a plus ce menu : ces lots servent surtout à TARDIS_2 et TARDIS_3, qui le gardent.

### V13.4.1 — Socle du menu pour TARDIS_2 et TARDIS_3

**Objectif :** Afficher le bon TARDIS, ranger les commandes dans TardisCommandes et corriger les petits défauts du tiroir. Pour TARDIS_2 et TARDIS_3 surtout.

- **M-99. Nom et couleur du TARDIS dans l'en-tête** *(petit)* : L'en-tête dit toujours « T.A.R.D.I.S. ». Avec les trois TARDIS de la V10, il afficherait def.Nom et une couleur propre à chaque cabine.
- **M-100. Commandes des tuiles rangées dans TardisCommandes** *(moyen)* : Camouflage, portes, verrou, taille et siège sont envoyés directement par le menu (remote:FireServer). Les mettre dans TardisCommandes, avec leurs conditions, permettra aux boutons de la console V11 de les réutiliser.
- **M-95. Destination partagée entre le menu et la tablette** *(moyen)* : Les protocoles sont communs (TardisCommandes) mais pas la destination : choisir dans T ne change pas Y. Un choix commun dans TardisCommandes prépare aussi l'écran de destination de la console.
- **M-12. Liste et fiche plus légères à calculer** *(petit)* : construireListe détruit et recrée tous les boutons à chaque lettre tapée, et majFiche refait un FindFirstChild récursif deux fois par seconde. Réutiliser les boutons, attendre 0,15 s après la frappe et garder la pièce trouvée en mémoire.
- **M-79. Bouton × de fermeture dans l'en-tête** *(petit)* : Une petite croix en haut du tiroir, à côté du bouton TABLETTE. Sur mobile on n'a pas de touche T, et le bouton tactile est à côté.
- **M-80. Menu fermé automatiquement à la mort du joueur** *(petit)* : ResetOnSpawn est faux : le menu reste ouvert pendant la mort et la régénération. Il se refermerait tout seul et ne gênerait plus l'écran de réapparition.
- **M-65. Menu rouvert après la fermeture de la tablette** *(petit)* : Ouvrir la tablette ferme le menu T. Si le menu était ouvert avant, il se rouvrirait tout seul quand on ferme la tablette, pour reprendre là où on en était.
- **M-94. Confirmation du Siège qui ne s'efface plus** *(petit)* : UI.confirmer écrit « CONFIRMER ? » dans le texte de la tuile Siège, mais majInterface le réécrit dès qu'un attribut change : la demande disparaît alors qu'elle est encore armée. La tuile garderait la confirmation visible pendant ses 3 secondes.

**Dans Studio :** Rien.

*Pourquoi ici :* Tout dans TardisMenu (environ 870 lignes) et TardisCommandes. M-99 affiche le nom et la couleur du TARDIS dans l'en-tête : indispensable avec trois TARDIS. M-100 range camouflage, portes, verrou, taille et siège dans TardisCommandes, M-95 partage la destination entre le menu et la tablette : les lots suivants s'appuient dessus. M-12 allège construireListe avant les lots de recherche. Puis des corrections courtes : bouton × (M-79), menu fermé à la mort (M-80), menu rouvert après la tablette (M-65), confirmation du Siège qui reste (M-94).

### V13.4.2 — Recherche des lieux

**Objectif :** Une recherche qui trouve le lieu même avec une faute d'accent, d'ordre ou de frappe. Pour TARDIS_2 et TARDIS_3 surtout.

- **M-3. Recherche insensible aux accents et majuscules** *(petit)* : string.lower ne transforme pas É, À ou Ç : « electrique » ne trouve pas « Électrique ». Une petite table qui retire les accents avant de comparer règle le problème.
- **M-4. Recherche par mots dans n'importe quel ordre** *(petit)* : « porte 19 » trouverait « Site-19 Porte » : chaque mot tapé doit se trouver dans le nom, peu importe l'ordre. Aujourd'hui string.find cherche la phrase entière.
- **M-1. Entrée dans la recherche choisit le premier lieu** *(petit)* : Quand on valide la recherche avec Entrée (FocusLost de la TextBox), le premier résultat devient la destination. On tape « site » puis Entrée, sans viser la liste à la souris.
- **M-2. Ligne Retour toujours en tête malgré la recherche** *(petit)* : La ligne « Retour : … » n'apparaît pendant une recherche que si le texte tapé correspond à « Retour » suivi du nom (garde dans construireListe). Elle resterait toujours en tête de l'onglet Lieux, même filtré, car c'est le choix le plus fréquent.
- **M-6. Petite croix pour vider la recherche** *(petit)* : Une croix à droite de la case de recherche efface le texte d'un clic, surtout utile sur mobile où effacer lettre par lettre est long.
- **M-8. Touche « / » pour aller dans la recherche** *(petit)* : Menu ouvert, la touche / place le curseur dans la recherche. Rapide pour les pilotes qui connaissent le nom du lieu.
- **M-9. Nombre de résultats affiché sous la recherche** *(petit)* : Une petite ligne « 12 lieux » ou « 3 joueurs » sous la case. On sait si la liste continue plus bas ou si le filtre est trop strict.
- **M-5. Lettres trouvées surlignées dans les résultats** *(petit)* : Avec RichText, la partie du nom qui correspond à la recherche s'affiche en ambre. On voit tout de suite pourquoi un lieu est dans la liste.
- **M-10. Suggestion du lieu voisin après une faute** *(moyen)* : Quand la liste est vide (listeVide), proposer « Vouliez-vous dire : Site-19 ? » en comparant les noms lettre par lettre. Un clic choisit la suggestion.

**Dans Studio :** Rien.

*Pourquoi ici :* La recherche de construireListe. Règle d'abord : insensible aux accents (M-3), mots dans n'importe quel ordre (M-4). Puis le confort : Entrée choisit le premier (M-1), Retour toujours en tête (M-2), croix pour vider (M-6), touche / (M-8), nombre de résultats (M-9), lettres surlignées (M-5). M-10 (suggestion après une faute) en dernier.

### V13.4.3 — Liste des lieux : tri et repères

**Objectif :** Choisir le tri et voir distance, hauteur et lieu actuel sans ouvrir la fiche. Pour TARDIS_2 et TARDIS_3 surtout.

- **M-98. Recherche propre à chaque onglet** *(petit)* : Lieux et Joueurs partagent la même case : chercher « lucas » puis revenir aux Lieux donne une liste vide. Chaque onglet garderait son propre texte de recherche.
- **M-14. Choix du tri : liste, alphabet ou distance** *(petit)* : Un petit bouton au-dessus de la liste change le tri : ordre de Studio (aujourd'hui), alphabétique, ou du plus proche au plus loin (distanceDe existe déjà).
- **M-15. Distance affichée sur chaque ligne de lieu** *(petit)* : La distance n'apparaît que dans la fiche ; l'écrire en petit à droite de chaque ligne aide à choisir sans cliquer sur chaque lieu.
- **M-16. Lieu actuel marqué « Vous êtes ici »** *(petit)* : Le lieu égal à l'attribut Position est grisé avec la mention « Vous êtes ici ». Évite de lancer un voyage vers l'endroit où l'on est déjà.
- **M-11. Hauteur de la destination écrite dans la fiche** *(petit)* : La fiche donne la distance mais pas la différence de hauteur. « 40 studs plus haut » ou « 12 plus bas » aide à prévoir un toit, un sous-sol ou une arrivée en Sauvetage.
- **M-25. Hauteur de la liste adaptée à l'écran** *(petit)* : La liste fait 156 pixels fixes, même sur un grand écran. Elle pourrait grandir avec la place disponible dans le tiroir.
- **M-26. Liste qui défile jusqu'au choix en cours** *(petit)* : À l'ouverture et après une recherche, la liste défile jusqu'à la destination choisie, pour qu'on la voie sans chercher.
- **M-32. Noms trop longs qui défilent au survol** *(petit)* : Les noms coupés par TextTruncate défilent doucement quand on passe dessus, pour lire le nom complet sans ouvrir la tablette.

**Dans Studio :** Rien.

*Pourquoi ici :* Toujours construireListe et majFiche. Recherche propre à chaque onglet (M-98), choix du tri (M-14), distance sur chaque ligne (M-15), « Vous êtes ici » (M-16), hauteur dans la fiche (M-11). Puis la mise en page : hauteur selon l'écran (M-25), défilement jusqu'au choix (M-26), noms longs qui défilent (M-32).

### V13.4.4 — Lieux : dossiers, libellés et favoris

**Objectif :** Effacer ou retrouver un choix, étoiler un favori, et ranger les lieux par dossier avec des noms lisibles. Pour TARDIS_2 et TARDIS_3 surtout.

- **M-28. Bouton pour effacer la destination choisie** *(petit)* : Une fois un lieu choisi, on ne peut plus revenir à « aucune destination » (vortex libre). Une petite croix dans la fiche remet le choix à zéro.
- **M-22. Message clair quand la destination choisie disparaît** *(petit)* : Si le joueur visé quitte ou si le lieu est retiré, construireListe remet le choix à zéro sans rien dire. La fiche afficherait « X a quitté le serveur, choisis une autre destination ».
- **M-96. Destination effacée après l'arrivée (option)** *(petit)* : Après un atterrissage, le choix reste : un clic sur DÉMAT relance vers le même lieu. Une option remet la fiche à « Aucune destination » à l'arrivée.
- **M-17. Épingler un favori directement depuis le menu** *(petit)* : Les favoris ne s'étoilent que dans la tablette. Une étoile sur chaque ligne du menu T appellerait UI.basculerFavori, sans ouvrir la tablette.
- **M-24. Aperçu de la fiche au survol d'une ligne** *(petit)* : Survoler une ligne montre sa distance et son type dans la fiche, en gris, sans la choisir. On compare plusieurs lieux sans changer le choix.
- **M-13. Lieux rangés par dossier avec titres repliables** *(moyen)* : Si le dossier des destinations a des sous-dossiers (Site-19, Extérieur…), la liste les montre en groupes repliables. Le serveur ajoute le dossier dans ListeDestinations.
- **M-31. Libellés et icônes des lieux réglables dans Studio** *(moyen)* : Des attributs Libelle et Icone sur les pièces de destination donnent un nom lisible (« Site-19 · Porte » au lieu de « Site19_Porte ») et un symbole par type de lieu.

**Dans Studio :** M-31 : poser des attributs Libelle et Icone (facultatifs) sur les pièces de destination.

*Pourquoi ici :* Bouton pour effacer le choix (M-28), message quand il disparaît (M-22), choix effacé après l'arrivée en option (M-96), étoile des favoris (M-17, UI.basculerFavori), aperçu au survol (M-24). Puis les deux changements plus gros : groupes repliables par sous-dossier (M-13), libellés et icônes réglables dans Studio (M-31).

### V13.4.5 — Onglet Joueurs

**Objectif :** Une liste de joueurs plus claire : équipage en tête, couleurs d'équipe, risque de paradoxe. Pour TARDIS_2 et TARDIS_3 surtout.

- **M-21. Sa propre ligne « (toi) » placée en dernier** *(petit)* : Aujourd'hui le joueur lui-même est mélangé aux autres. Le mettre en bas de la liste évite de le choisir par erreur.
- **M-20. Équipage C.A.T. et C.T.A.T. en tête des joueurs** *(petit)* : Les membres des deux équipes passent en premier dans l'onglet Joueurs, avant les autres joueurs triés par nom. Ce sont les cibles les plus courantes.
- **M-18. Couleur d'équipe à côté de chaque joueur** *(petit)* : Dans l'onglet Joueurs, un point de la couleur de l'équipe (UI.couleurJoueur existe déjà) aide à repérer un garde, un D ou un scientifique.
- **M-19. Joueurs à bord signalés comme risque de paradoxe** *(petit)* : Un joueur qui est à l'intérieur du TARDIS reçoit la mention « à bord : paradoxe ». Le pilote comprend avant le voyage pourquoi le serveur va demander une confirmation.
- **M-27. Joueur en réapparition signalé dans la liste** *(petit)* : Quand le joueur visé n'a pas de personnage (mort, réapparition), distanceDe renvoie rien et la fiche affiche « — ». Elle dirait « en réapparition, attends quelques secondes ».
- **M-30. Option pour figer le joueur visé** *(petit)* : L'option figer de Commandes.donnees n'existe que dans la tablette. Un petit interrupteur dans la fiche, seulement quand un joueur est choisi.
- **M-29. Flèche de direction vers la destination dans la fiche** *(petit)* : Une flèche qui tourne selon la caméra montre de quel côté se trouve le lieu ou le joueur choisi. Utile pour s'orienter avant le départ.
- **M-35. Touche Tab pour passer de Lieux à Joueurs** *(petit)* : Menu ouvert, Tab appelle changerMode pour basculer entre les deux onglets, même pendant la recherche.

**Dans Studio :** Rien.

*Pourquoi ici :* La liste des joueurs du menu : sa propre ligne en dernier (M-21), C.A.T. et C.T.A.T. en tête (M-20), couleur d'équipe (M-18, UI.couleurJoueur), risque de paradoxe à bord (M-19), joueur en réapparition (M-27), option figer dans la fiche (M-30), flèche de direction (M-29), touche Tab (M-35).

### V13.4.6 — Fiche et départ

**Objectif :** Des boutons DÉMAT et REMAT qui ne partent pas deux fois, disent quand le serveur ne répond pas et acceptent des raccourcis. Pour TARDIS_2 et TARDIS_3 surtout.

- **M-46. État d'envoi qui bloque les doubles clics** *(petit)* : Après un clic sur DÉMAT ou REMAT, le bouton affiche « Envoi… » et ignore les clics jusqu'au changement d'état. Évite deux demandes au serveur.
- **M-47. Alerte si le serveur ne répond pas** *(petit)* : Si l'état ne change pas 3 secondes après DÉMAT ou REMAT et qu'aucun message n'est revenu, le menu affiche « Pas de réponse du TARDIS, réessaie ».
- **M-55. Sous-titre « vortex libre » quand rien n'est choisi** *(petit)* : Posé et sans destination, DÉMAT affiche « Vortex libre » au lieu de « Décoller ». Le pilote sait avant de cliquer qu'il devra choisir dans le vortex.
- **M-49. Nouveau choix pris en compte avant la remat automatique** *(petit)* : Si on choisit un autre lieu pendant les 10 s de vortex, l'arrivée se fait toujours vers l'ancien (autoRemat garde ses données). Le nouveau choix remplacerait l'ancien, avec un message.
- **M-48. Bouton pour rester dans le vortex** *(petit)* : Commandes.annulerAutoRemat existe mais aucun bouton ne l'appelle dans le menu. Un petit bouton sous REMAT arrête la rematérialisation automatique.
- **M-42. Touche Entrée pour le bouton principal disponible** *(petit)* : Menu ouvert et hors recherche, Entrée appuie sur DÉMAT si le TARDIS est posé, sur REMAT s'il est dans le vortex.
- **M-23. Double-clic sur une destination pour partir** *(petit)* : Un double-clic sur une ligne choisit la destination et lance DÉMAT (posé) ou REMAT (dans le vortex), si le bouton est disponible.
- **M-33. Petite animation de la fiche quand le choix change** *(petit)* : La fiche glisse ou s'éclaire un court instant quand la destination change. On remarque qu'un clic a bien été pris en compte.
- **M-97. Proposition de destination du copilote dans le menu** *(moyen)* : Quand le copilote propose un lieu depuis son poste, la fiche du menu l'affiche « Proposé par Lucas » avec un bouton Accepter.

**Dans Studio :** Rien.

*Pourquoi ici :* Sûr d'abord : envoi qui bloque les doubles clics (M-46), alerte si le serveur ne répond pas (M-47), sous-titre « vortex libre » (M-55), nouveau choix pris avant la remat automatique (M-49), bouton pour rester dans le vortex (M-48, Commandes.annulerAutoRemat). Puis les raccourcis : Entrée (M-42), double-clic (M-23), animation de la fiche (M-33). M-97 (proposition du copilote dans la fiche) touche aussi Copilote.lua : en dernier.

### V13.4.7 — Protocoles

**Objectif :** Une carte PROTOCOLES plus claire : modes à segments, invisible à part, et quand le mode s'applique. Pour TARDIS_2 et TARDIS_3 surtout.

- **M-44. Atterrissage invisible séparé des quatre modes** *(petit)* : L'interrupteur « Atterrissage invisible » est rangé avec les modes qui s'excluent, alors qu'il se combine avec eux. Un trait et la mention « option, se combine avec le mode » évitent de croire qu'il remplace le mode choisi.
- **M-39. Indiquer quand un changement de mode s'appliquera** *(petit)* : Dans le vortex, changer de mode n'a d'effet qu'à la REMAT. Une ligne « s'appliquera à l'atterrissage » sous les protocoles évite la confusion.
- **M-40. Texte d'explication réservé aux nouveaux pilotes** *(petit)* : Le long texte sur les zones REFUSE et le vortex automatique prend de la place pour tout le monde. Il ne s'afficherait qu'en mode débutant (UI.debutant).
- **M-36. Sélecteur de mode à segments comme la tablette** *(petit)* : Les quatre interrupteurs Urgence, Rapide, Sauvetage et Silencieux s'excluent mais ressemblent à des options séparées. UI.selecteurModes, déjà utilisé ailleurs, montre clairement qu'un seul mode est actif.
- **M-38. Contour du menu à la couleur du mode choisi** *(petit)* : Le contour ambre du tiroir prend la couleur du mode (UI.couleurMode) : orange en Urgence, violet en Silencieux. On voit le mode d'un coup d'œil.
- **M-37. Section Protocoles repliable pour gagner de la place** *(petit)* : Un clic sur le titre PROTOCOLES replie la carte en une ligne (« Mode : Rapide · invisible »). L'état replié est retenu.
- **M-41. Touches 1 à 5 pour choisir le mode** *(petit)* : Menu ouvert, 1 Classique, 2 Urgence, 3 Rapide, 4 Sauvetage, 5 Silencieux, via Commandes.reglerMode. Rapide avant un départ pressé.
- **M-43. Un seul grand bouton DÉMAT puis REMAT** *(moyen)* : Un bouton qui change de rôle selon l'état, au lieu de deux dont un est toujours grisé. Prépare le levier unique de la console de la V11.

**Dans Studio :** Rien.

*Pourquoi ici :* Règle avant affichage : Atterrissage invisible séparé des quatre modes (M-44), moment où le mode s'applique (M-39). Puis texte réservé aux nouveaux pilotes (M-40), sélecteur à segments (M-36), contour à la couleur du mode (M-38), section repliable (M-37), touches 1 à 5 (M-41). M-43 (un seul bouton DÉMAT puis REMAT) change la mise en page : en dernier.

### V13.4.8 — Voyage en cours

**Objectif :** Voir où en est le voyage, le paradoxe et la minuterie, même menu fermé. Pour TARDIS_2 et TARDIS_3 surtout.

- **M-53. Secondes restantes sur le bouton de paradoxe** *(petit)* : Le bouton rouge « VOUS CONFIRMEZ ? » reste armé 15 s sans le dire. Afficher « encore 12 s » dans son sous-titre.
- **M-54. Bouton Annuler pour la confirmation du paradoxe** *(petit)* : Pendant la confirmation du paradoxe, un petit bouton désarme tout de suite au lieu d'attendre la fin des 15 secondes.
- **M-71. Bandeau rouge d'auto-destruction dans le menu** *(petit)* : Pendant une auto-destruction (AutoDestructionDebut), un bandeau rouge avec le temps restant en haut du menu, pour que le pilote ne le découvre pas par hasard.
- **M-50. Étapes du voyage affichées en frise** *(petit)* : Trois pastilles Démat · Vortex · Remat au-dessus de la barre, l'étape en cours allumée. On comprend où en est le voyage même sans lire le pourcentage.
- **M-52. Vibration de la manette à l'arrivée** *(petit)* : Avec HapticService, une courte vibration au départ et à l'atterrissage pour les joueurs à la manette. Désactivable.
- **M-70. Minuterie de décollage visible et annulable** *(moyen)* : L'attribut MinuterieFin est écouté mais jamais montré. Un compte à rebours « Décollage dans 0:45 » dans le statut, avec un bouton pour l'annuler.
- **M-51. Mini-barre de voyage visible menu fermé** *(moyen)* : Pendant un voyage, une fine barre au bord gauche de l'écran montre la progression quand le tiroir est fermé. Un clic rouvre le menu.

**Dans Studio :** Rien.

*Pourquoi ici :* Paradoxe : secondes restantes (M-53) et bouton Annuler (M-54). Bandeau d'auto-destruction (M-71), frise des étapes (M-50), vibration de la manette (M-52). M-70 montre et annule la minuterie de décollage (MinuterieFin, déjà écouté) ; M-51 ajoute une mini-barre menu fermé, un nouveau ScreenGui : en dernier.

### V13.4.9 — Tuiles des systèmes

**Objectif :** Des tuiles qui disent pourquoi elles sont grisées, de nouvelles tuiles et un choix des tuiles affichées. Pour TARDIS_2 et TARDIS_3 surtout.

- **M-45. Raison du grisé des tuiles au clic** *(petit)* : Un clic sur une tuile grisée la fait trembler et affiche la raison (« Portes : TARDIS trop petit », « Camouflage : seulement posé »). Aujourd'hui le clic ne fait rien.
- **M-57. Tuile Bouclier dans le menu rapide** *(petit)* : Le menu montre la jauge du bouclier mais ne permet pas de l'allumer. Une tuile Bouclier évite d'ouvrir la tablette en pleine attaque.
- **M-58. Tuile Alerte dans le menu rapide** *(petit)* : Une tuile pour lancer ou couper l'alerte (attribut Alerte), à côté de Siège qui la déclenche déjà avec le reste.
- **M-60. Touches lettres pour les tuiles, menu ouvert** *(petit)* : Menu ouvert seulement : C camouflage, V verrou, P portes… Les lettres sont rappelées en petit dans le coin de chaque tuile.
- **M-56. Plusieurs tailles au choix pour la tuile Taille** *(moyen)* : La tuile passe seulement de grand à TaillePetite. Un appui long ouvre trois ou quatre tailles, le serveur accepte déjà un facteur.
- **M-59. Choisir et ordonner les tuiles affichées** *(moyen)* : Comme les widgets de la tablette (UI.widgetVisible), le pilote choisit quelles tuiles apparaissent et dans quel ordre.

**Dans Studio :** Rien.

*Pourquoi ici :* S'appuie sur M-100 (V13.4.1). Raison du grisé au clic (M-45), tuiles Bouclier (M-57) et Alerte (M-58), touches lettres (M-60). M-56 (plusieurs tailles) demande une petite règle au serveur ; M-59 (choisir et ordonner les tuiles, comme UI.widgetVisible) en dernier.

### V13.4.10 — Statut et jauges

**Objectif :** Une carte de statut qui dit tout sans doublon : bouclier, temps posé, porteur, intrusion, jauges vivantes. Pour TARDIS_2 et TARDIS_3 surtout.

- **M-91. Plus de doublon entre l'état et les badges** *(petit)* : En vol libre ou hors tension, la ligne d'état écrit « VOL LIBRE » ou « HORS TENSION » et le badge du même nom s'affiche juste dessous. Cacher le badge quand l'état dit déjà la même chose libère de la place.
- **M-62. Type de bouclier actif écrit sur la jauge** *(petit)* : La jauge dit « actif » sans préciser : Joueurs, Balles ou Complet. Afficher le type à côté du pourcentage.
- **M-66. Temps passé posé affiché sous le lieu** *(petit)* : Sous la position, « posé depuis 4 min » grâce à DebutEtat. Utile en RP pour savoir depuis quand le TARDIS est visible.
- **M-67. Nom du pilote affiché en vol libre** *(petit)* : L'attribut VolLibre contient l'identifiant du pilote : le statut afficherait « VOL LIBRE · piloté par Lucas ».
- **M-68. Badge PORTÉ PAR quand on tient le TARDIS** *(petit)* : L'attribut Porteur grise DÉMAT mais aucun badge ne l'explique. Un badge « PORTÉ PAR Lucas » dans le statut.
- **M-69. Badge « INTRUSION » avec le nom et l'heure** *(petit)* : Le menu écoute déjà l'attribut Intrusion sans l'afficher. Un badge rouge avec le nom de l'intrus et l'heure, cliquable pour l'effacer.
- **M-61. Jauge d'intégrité qui clignote sous 20 %** *(petit)* : Sous 20 %, la jauge d'intégrité pulse doucement en rouge avec un son d'alerte unique. Rien qui flashe en mode « Aucun flash ».
- **M-63. Flèche de tendance sur l'intégrité qui baisse** *(petit)* : Une petite flèche ↓ rouge quand PointsDeVie a baissé dans les dernières secondes. On sait que le TARDIS est attaqué en ce moment.
- **M-72. Jauges d'intégrité et de bouclier qui glissent** *(petit)* : Les barres changent de taille d'un coup (barre.Size). Un tween de 0,3 s montre mieux une perte de points ou la recharge du bouclier, et on remarque le changement.
- **M-64. Badges limités avec un compteur « +3 »** *(petit)* : Treize badges peuvent s'afficher en même temps et pousser le reste vers le bas. Garder les trois plus importants et un badge « +3 » qui déplie les autres.

**Dans Studio :** Rien.

*Pourquoi ici :* Plus de doublon entre l'état et les badges (M-91), puis les informations : type de bouclier (M-62), temps posé (M-66), pilote du vol libre (M-67), PORTÉ PAR (M-68), INTRUSION (M-69, attribut déjà écouté). Puis les effets : jauge qui clignote sous 20 % (M-61), flèche de tendance (M-63), jauges qui glissent (M-72). Le compteur « +3 » des badges (M-64) range le tout : en dernier.

### V13.4.11 — Voiles Avarie et Détruit

**Objectif :** Des voiles lisibles, qui laissent voir l'état, avec un vrai compte à rebours et un appel aux techniciens. Pour TARDIS_2 et TARDIS_3 surtout.

- **M-77. Textes des voiles lisibles sur petit écran** *(petit)* : « TARDIS DÉTRUIT » est un texte tourné de 600 pixels de large, coupé sur un menu réduit. TextScaled et une taille maximale le gardent entier.
- **M-74. Voiles qui laissent voir l'état du TARDIS** *(petit)* : Les voiles Avarie et Détruit recouvrent tout le tiroir. Ils pourraient laisser visible la carte du statut et les jauges, et ne couvrir que les commandes.
- **M-76. Apparition animée des voiles avec parasites** *(petit)* : Les voiles apparaissent d'un coup (Visible). Un fondu avec quelques lignes de parasites rendrait l'avarie plus vivante, adouci en effets réduits.
- **M-73. Vrai compte à rebours sur le voile Détruit** *(moyen)* : « Reconstitution dans quelques minutes » deviendrait « Reconstitution dans 2:34 », avec un attribut de fin posé par le serveur.
- **M-75. Prévenir les techniciens depuis le voile Avarie** *(moyen)* : Un bouton sur le voile envoie un message aux membres de la C.T.A.T. en ligne : « Avarie du TARDIS, rotor à réparer ».

**Dans Studio :** Rien.

*Pourquoi ici :* Textes lisibles sur petit écran (M-77), voiles qui laissent voir le statut (M-74), apparition avec parasites (M-76, sans flash en effets réduits). M-73 demande un attribut de fin posé par le serveur pour la reconstitution ; M-75 envoie un message aux techniciens en ligne (nouvelle action à déclarer au garde-barrière de la V8) : en dernier.

### V13.4.12 — Messages et sons du menu

**Objectif :** Des messages qui ne cachent plus les boutons et un menu calme en effets réduits. Pour TARDIS_2 et TARDIS_3 surtout.

- **M-78. Messages en haut du tiroir, pas sur les boutons** *(petit)* : La notification monte depuis le bas du tiroir et peut cacher les tuiles ou les boutons au moment où l'on veut cliquer. Elle s'afficherait juste sous l'en-tête.
- **M-92. Durée des messages selon leur longueur** *(petit)* : Chaque message reste 4 secondes, même long. La durée suivrait le nombre de mots, et un clic fermerait le message tout de suite.
- **M-85. Son d'ouverture différent du son des messages** *(petit)* : L'ouverture du menu joue UI.son(« Notification »), le même son qu'un message réussi. Un petit son propre à l'ouverture et à la fermeture évite de croire qu'un message est arrivé.
- **M-93. Animations continues du menu calmées en effets réduits** *(petit)* : Anneaux de l'emblème, dégradé du vortex et lueur pulsée des boutons tournent sans regarder UI.effetsReduits. Ils ralentiraient ou s'arrêteraient avec l'option.

**Dans Studio :** Rien.

*Pourquoi ici :* Petit lot dans TardisMenu : messages en haut du tiroir (M-78), durée selon la longueur (M-92), son d'ouverture propre (M-85), animations continues calmées en effets réduits (M-93).

### V13.4.13 — Clavier, manette et mobile

**Objectif :** Des touches réglables et un menu plus pratique au doigt. Pour TARDIS_2 et TARDIS_3 surtout.

- **M-90. Pied de page qui montre les vraies touches** *(petit)* : Le pied de page et le bouton TABLETTE écrivent « T » et « Y » en dur, même si le joueur a changé ses touches (UI.touche). Ils liraient la vraie touche, ou l'icône manette ou tactile.
- **M-7. Maintenir T pour jeter un œil au menu** *(petit)* : Un appui court sur T ouvre ou ferme comme aujourd'hui ; un appui long ouvre le menu seulement le temps de l'appui, pour lire l'état sans le laisser ouvert.
- **M-88. Boutons tactiles aussi sur tablette avec clavier** *(petit)* : Les boutons tactiles disparaissent dès qu'un clavier est branché (KeyboardEnabled), même sur un iPad tenu à la main. Une option pour les garder.
- **M-89. En-tête réduit sur les écrans peu hauts** *(petit)* : Sur un téléphone en paysage, l'en-tête de 78 pixels prend une grande part d'un tiroir déjà réduit. Sous une certaine hauteur d'écran, il passerait à une seule ligne (nom, état, bouton Tablette).
- **M-86. Balayer vers la gauche pour fermer sur mobile** *(petit)* : Un glissement du doigt vers la gauche sur l'en-tête referme le tiroir, comme un vrai tiroir.
- **M-87. Boutons tactiles T et Y réunis en un seul** *(petit)* : Option : un seul bouton rond TARDIS ; un appui ouvre le menu, un appui long ouvre la tablette. Moins de place prise sur le bord de l'écran.
- **M-84. Menu en bas de l'écran en mode portrait** *(moyen)* : Sur un téléphone tenu droit, le tiroir de 340 pixels cache la moitié de l'écran. Il deviendrait un panneau qui monte du bas.
- **A-70. Raccourcis clavier configurables partout** *(moyen)* : Toutes les touches du menu modifiables, comme celles du vol libre.

**Dans Studio :** Rien.

*Pourquoi ici :* Pied de page avec les vraies touches (M-90), appui long sur T (M-7), boutons tactiles même avec un clavier (M-88), en-tête réduit (M-89), balayer pour fermer (M-86), boutons T et Y réunis (M-87). M-84 (menu en bas en mode portrait) et A-70 (toutes les touches du menu modifiables, du premier tri) sont plus gros : en dernier. A-70 complète la navigation à la manette de la V12.4.

### V13.4.14 — Taille et disposition du tiroir

**Objectif :** Choisir la taille et la disposition du tiroir : boutons fixés, mode mini, hauteur, deux colonnes. Pour TARDIS_2 et TARDIS_3 surtout.

- **M-34. Boutons DÉMAT et REMAT fixés en bas du tiroir** *(moyen)* : Les deux grands boutons sont dans la zone qui défile, sous les protocoles : sur un petit écran, il faut descendre pour les atteindre. Ils seraient posés en bas du tiroir, hors du défilement, toujours visibles. Cela prépare aussi la place fixe du levier sur la console.
- **M-81. Mode mini : statut et boutons de voyage seulement** *(moyen)* : Un bouton dans l'en-tête réduit le tiroir à l'état, la destination choisie et DÉMAT / REMAT. Le reste se rouvre d'un clic.
- **M-83. Hauteur du tiroir ajustable en tirant le bas** *(moyen)* : Une poignée en bas du tiroir permet de le rendre plus court ou plus long ; la hauteur est retenue dans les préférences.
- **M-82. Menu sur deux colonnes sur grand écran** *(moyen)* : Sur un écran large, destination à gauche et protocoles, actions et systèmes à droite : tout est visible sans faire défiler.

**Dans Studio :** Rien.

*Pourquoi ici :* Les quatre changements de mise en page, en dernier parce qu'ils déplacent tout ce que les lots précédents ont ajouté : DÉMAT et REMAT fixés en bas (M-34), mode mini (M-81), hauteur réglable retenue dans les préférences (M-83), deux colonnes sur grand écran (M-82).

## V13.5 — Tablette Y des pilotes (15 lots, 98 propositions)

Améliorer la tablette Y (TardisTablette) : lieux, placement, carte, radar, réglages, volet et outils. Après la V12, TARDIS_1 n'a plus de tablette : ces lots servent surtout à TARDIS_2 et TARDIS_3, qui la gardent.

### V13.5.1 — Socle de la tablette

**Objectif :** Séparer la lecture de l'état, rafraîchir les pages du volet et rendre la navigation prévisible. Pour TARDIS_2 et TARDIS_3 surtout.

- **M-198. Lecture de l'état séparée de l'affichage** *(moyen)* : Sortir lireEtat et les textes d'état d'Etat.lua dans un module partagé, que les écrans de la console V11 pourront réutiliser tels quels.
- **M-174. Pages du volet qui se mettent à jour** *(petit)* : Customisation, Inviter, Jukebox et Boucliers ne bougent pas après un clic ou un changement d'état (le contour de la couleur choisie reste l'ancien). Les rafraîchir comme le Registre.
- **M-125. Raison écrite quand un bouton est grisé** *(petit)* : DÉMAT, REMAT, les tuiles du dock et les outils disent pourquoi ils sont grisés (hors tension, porté, bloqué, maintenance) ; aujourd'hui DÉMAT grisé affiche juste « Décoller » (majInterface).
- **M-101. Échap remonte d'un niveau puis ferme** *(petit)* : Dans le volet, Échap revient à la page précédente (V.retour), puis ferme le volet, puis la tablette ; pendant le placement, il annule comme le bouton Annuler. Aujourd'hui seule la croix rouge ferme (Volet, Ouverture).
- **M-103. Message quand Y est ignorée en vol libre** *(petit)* : Volet ignore Y sans rien dire quand le joueur pilote en vol libre. Un court message « Tablette indisponible en vol libre : G pour se poser » éviterait de croire à un bug.
- **M-165. Volet rouvert là où on l'a laissé** *(petit)* : Retour aux outils garde la position du défilement, et le bouton Outils rouvre la dernière page utilisée.
- **M-194. Onglet et scanner retenus à la réouverture** *(petit)* : La tablette rouvre sur le dernier onglet (Lieux, Coord…) et le dernier mode radar ou carte, même après une reconnexion.
- **M-162. Réinitialiser toutes les préférences d'affichage** *(petit)* : Un bouton en bas des réglages remet thème, taille, widgets et options par défaut, sans toucher aux favoris ni aux touches.

**Dans Studio :** Rien.

*Pourquoi ici :* M-198 sort lireEtat d'Etat.lua dans un module partagé : la V12 en a eu besoin pour la console de TARDIS_1, vérifier s'il est déjà fait. M-174 met à jour Customisation, Inviter, Jukebox et Boucliers après un changement : les lots suivants en dépendent. M-125 écrit la raison des boutons grisés. Puis la navigation : Échap qui remonte (M-101), message quand Y est ignorée en vol libre (M-103), volet rouvert là où on l'a laissé (M-165), onglet retenu (M-194), réinitialiser l'affichage (M-162).

### V13.5.2 — Liste des lieux et protocoles

**Objectif :** Naviguer dans la liste au clavier et voir avant de partir si un mode est possible. Pour TARDIS_2 et TARDIS_3 surtout.

- **M-104. Flèches du clavier dans la liste des lieux** *(petit)* : Haut et Bas déplacent la sélection dans W.liste, Entrée la choisit : on navigue sans souris (en plus de la manette déjà prévue).
- **M-110. Choix de la catégorie dans une liste** *(petit)* : W.boutonCategorie passe à la catégorie suivante à chaque clic (et repasse par « aucune »). Une petite liste déroulante permettrait de choisir la bonne directement.
- **M-191. Revenir à la destination choisie juste avant** *(petit)* : Un petit bouton ↶ dans la fiche (ou Ctrl+Z) remet la destination précédente après un mauvais clic dans la liste, le radar ou la carte.
- **M-122. Libellés plus clairs pour viser un joueur** *(petit)* : « Dernière position / Sur lui (figé) » est obscur. Une ligne sous le choix dirait simplement ce que fait chaque option au joueur visé.
- **M-123. Explication du mode choisi sous le sélecteur** *(petit)* : Une ligne fixe sous les protocoles résume le mode actif (ex. « Silencieux : ni son, ni lumière, ni annonce »), sans attendre des infobulles.
- **M-112. Pastille REFUSE et SANS_EXPRESS sur chaque lieu** *(moyen)* : Chaque lieu de la liste et la fiche montrent s'il est en zone REFUSE (urgence imposée) ou SANS_EXPRESS, pour que le pilote le sache avant de partir.
- **M-113. Modes impossibles grisés selon la destination** *(moyen)* : Dans le sélecteur de protocoles (UI.selecteurModes), Rapide se grise si la destination est en SANS_EXPRESS, avec la raison écrite, au lieu d'un refus après coup.

**Dans Studio :** Rien.

*Pourquoi ici :* Navigation.lua et UI.selecteurModes. Flèches du clavier (M-104), liste des catégories (M-110), retour à la destination d'avant (M-191), libellés clairs pour viser un joueur (M-122), explication du mode (M-123). Puis la règle visible : pastilles REFUSE et SANS_EXPRESS (M-112) et modes impossibles grisés (M-113), qui demandent au serveur de publier ces zones dans CarteDestinations.

### V13.5.3 — Catégories et recherche

**Objectif :** Filtrer et grouper les lieux par catégorie, chercher partout et agir depuis la ligne d'un lieu. Pour TARDIS_2 et TARDIS_3 surtout.

- **M-121. Fiche de destination reliée au carnet** *(petit)* : La fiche indique « 3 notes au carnet » pour le lieu choisi, et un clic ouvre le carnet sur ce lieu (afficherCarnet).
- **M-108. Filtre des lieux par catégorie** *(moyen)* : Des pastilles de couleur (Config.Categories) au-dessus de la liste n'affichent qu'une catégorie d'un clic.
- **M-109. Lieux regroupés sous des titres de catégorie** *(moyen)* : La liste se range par catégorie avec un titre repliable, les favoris restant en tête : plus lisible quand il y a beaucoup de lieux.
- **M-107. Recherche dans tous les onglets à la fois** *(moyen)* : Taper un nom montre ensemble les lieux, les joueurs et les voyages de l'historique qui correspondent, groupés par type, au lieu de filtrer seulement l'onglet ouvert.
- **M-193. Clic droit sur un lieu : menu d'actions** *(moyen)* : Favori, catégorie, carnet, leurre, voir sur la carte : tout depuis la ligne du lieu, sans aller chercher ailleurs.

**Dans Studio :** Rien.

*Pourquoi ici :* Fiche reliée au carnet (M-121). Puis la liste : filtre par catégorie (M-108, Config.Categories), titres de catégorie repliables (M-109), recherche dans tous les onglets (M-107). Le menu du clic droit (M-193) regroupe favori, catégorie, carnet et carte : en dernier.

### V13.5.4 — Coordonnées et placement

**Objectif :** Placer le fantôme plus finement, saisir des coordonnées et garder ses propres points. Pour TARDIS_2 et TARDIS_3 surtout.

- **M-119. Touches du placement sans conflit avec E** *(petit)* : Placement tourne avec E, alors que E ouvre aussi les portes et la console. Passer sur d'autres touches (flèches) modifiables dans les réglages.
- **M-116. Molette et pas fin pour tourner le fantôme** *(petit)* : Pendant le placement (module Placement), la molette tourne l'aperçu, et Maj avec la rotation tourne de 1° au lieu de 15° pour aligner la porte.
- **M-124. Placer le fantôme juste devant soi** *(petit)* : Un bouton du HUD de placement met l'aperçu à quelques studs devant le joueur, utile quand le TARDIS est loin de l'endroit visé.
- **M-146. Leurre et localisation perso sur la carte** *(petit)* : La mini-carte montre aussi le leurre posé (TardisLeurre) et la nouvelle localisation choisie dans Coordonnées.
- **M-117. Saisie manuelle des coordonnées X Y Z** *(moyen)* : Dans le panneau Coordonnées, trois champs numériques en plus du fantôme, pour viser un point précis donné en RP.
- **M-118. Mes points : localisations perso enregistrées** *(moyen)* : Une nouvelle localisation placée peut être nommée et gardée dans les préférences du pilote, pour y retourner sans replacer le fantôme.
- **M-127. Clic sur la mini-carte pour placer un point** *(moyen)* : Un clic sur un endroit vide de la mini-carte ouvre le placement du fantôme à cette position, au lieu de devoir viser dans le monde.

**Dans Studio :** Rien.

*Pourquoi ici :* Placement.lua et le panneau Coordonnées. Touches sans conflit avec E (M-119) d'abord, puis molette et pas fin (M-116), fantôme devant soi (M-124), leurre et point perso sur la carte (M-146). Saisie X Y Z (M-117), points perso gardés dans les préférences (M-118). Le clic sur la mini-carte (M-127) relie la carte au placement : en dernier.

### V13.5.5 — Historique et journal de bord

**Objectif :** Un historique et un journal lisibles, filtrables et reliés aux lieux. Pour TARDIS_2 et TARDIS_3 surtout.

- **M-115. Effacement du journal annulable cinq secondes** *(petit)* : Le bouton Effacer du JOURNAL DE BORD vide tout sans retour ; un bouton « Annuler » reste 5 secondes pour remettre les lignes (S.journalEntrees est gardé).
- **M-153. Journal en grand dans le volet** *(petit)* : Le panneau journal ne fait que 120 px de haut ; un bouton l'ouvre en pleine hauteur dans le volet latéral.
- **M-158. Lignes du journal qui mènent à l'élément** *(petit)* : Cliquer « Posé : Site-19 » ou « Balise : Alex » dans le journal choisit ce lieu ou ce joueur comme destination.
- **M-134. Historique filtré par protocole de voyage** *(petit)* : Des pastilles Classique, Urgence, Rapide, Sauvetage, Silencieux au-dessus de l'onglet Historique, qui enregistre déjà le mode de chaque voyage.
- **M-120. Historique avec nom du lieu et heure** *(moyen)* : « Voyage n°3 · 120, 4, -80 » devient « Près de : Site-19 · 14:32 », en prenant le lieu enregistré le plus proche et l'heure du voyage.
- **M-152. Filtres et recherche dans le journal** *(moyen)* : Pastilles (voyages, sécurité, systèmes) et champ de recherche dans JOURNAL DE BORD, qui mélange tout aujourd'hui.

**Dans Studio :** Rien.

*Pourquoi ici :* Journal.lua et l'onglet Historique. Effacement annulable 5 s (M-115), journal en grand (M-153), lignes qui mènent au lieu ou au joueur (M-158), filtre par protocole (M-134). M-120 (nom du lieu et heure) et M-152 (filtres et recherche) changent le format des lignes : en dernier.

### V13.5.6 — Radar et scanner

**Objectif :** Un radar réglable et plus lisible, et un scanner utile même dans le vortex. Pour TARDIS_2 et TARDIS_3 surtout.

- **M-139. Portée du radar réglable** *(petit)* : Des boutons 50 / 150 / 300 studs sur le radar (R.PORTEE est fixé à 150 dans le script).
- **M-140. Cercles du radar avec leur distance** *(petit)* : Les deux anneaux du radar portent une petite étiquette (50, 100 studs) pour lire la distance d'un joueur d'un coup d'œil.
- **M-141. Même orientation pour radar et carte** *(petit)* : Le radar est tourné vers la porte, la mini-carte vers le nord : c'est déroutant. Un bouton choisit la même orientation pour les deux.
- **M-128. Petite traînée derrière les points du radar** *(petit)* : Chaque joueur du radar laisse une courte traînée qui montre dans quelle direction il se déplace (vers le TARDIS ou non).
- **M-130. Joueurs au-dessus ou en dessous sur le radar** *(petit)* : Un petit ▲ ou ▼ à côté d'un point indique qu'il est beaucoup plus haut ou plus bas que le TARDIS (toit, sous-sol), que majScanner ignore aujourd'hui.
- **M-148. Liste écrite des joueurs à portée** *(petit)* : Sous les lectures du scanner, les noms des joueurs à portée triés par distance, plus faciles à lire que des petits points.
- **M-147. Scanner utile pendant le vortex** *(petit)* : Au lieu du seul « SIGNAL PERDU », le scanner montre la destination choisie et le temps passé dans le vortex.
- **M-145. Balises de détresse sur la mini-carte** *(petit)* : L'aide dit « les pilotes la voient sur la mini-carte », mais Scanner ne lit pas l'attribut Balises. Ajouter un point rouge cliquable qui choisit le joueur.
- **M-150. Sentinelle réglable sans fausses alertes** *(petit)* : Rayon choisi par le pilote (Config.Sentinelle.Rayon pour tous aujourd'hui) et option pour ne pas alerter quand un pilote ou un technicien approche.
- **M-151. Alerte de sentinelle qui montre le joueur** *(petit)* : Cliquer l'alerte de la sentinelle ouvre la tablette sur le radar avec le joueur mis en évidence.

**Dans Studio :** Rien.

*Pourquoi ici :* Tout dans Scanner.lua (R.PORTEE fixé à 150). Réglages d'abord : portée (M-139), cercles gradués (M-140), même orientation que la carte (M-141). Puis les points : traînée (M-128), au-dessus ou en dessous (M-130), liste écrite (M-148). Scanner dans le vortex (M-147), balises de détresse lues (M-145). Sentinelle réglable (M-150) puis alerte qui montre le joueur (M-151).

### V13.5.7 — Mini-carte et télémétrie

**Objectif :** Une télémétrie complète et une mini-carte zoomable, colorée et sans noms qui se chevauchent. Pour TARDIS_2 et TARDIS_3 surtout.

- **M-131. Protocole et copilote dans la télémétrie** *(petit)* : Deux lignes de plus dans TÉLÉMÉTRIE : le protocole actuel et le copilote en poste, pour tout voir d'un coup d'œil.
- **M-132. Jauge de l'en-tête qui mesure vraiment** *(petit)* : Les 5 barres en haut à droite sont toujours pleines (vertes, rouges ou grises). Elles devraient montrer une vraie valeur, par exemple l'intégrité.
- **M-133. Coordonnées de la télémétrie faciles à copier** *(petit)* : Les coordonnées de TÉLÉMÉTRIE deviennent un champ en lecture seule : un clic les sélectionne, Ctrl+C les copie pour un rapport RP.
- **M-144. Marqueurs de carte aux couleurs des catégories** *(petit)* : Les ◆ de la mini-carte prennent la couleur de leur catégorie, et les favoris sont un peu plus gros.
- **M-192. Lieu survolé allumé sur la mini-carte** *(petit)* : Survoler un lieu dans la liste fait grossir et briller son marqueur sur la mini-carte, pour savoir où il est avant de le choisir.
- **M-142. Zoom manuel de la mini-carte** *(moyen)* : Boutons + et − (et molette) en plus du zoom automatique de majCarte, qui recule pour montrer toutes les destinations et rend les lieux proches illisibles.
- **M-143. Noms de la carte qui ne se chevauchent pas** *(moyen)* : Quand deux lieux sont proches sur la mini-carte, leurs noms se masquent et n'apparaissent qu'au survol.

**Dans Studio :** Rien.

*Pourquoi ici :* Suivi.lua et majCarte. Télémétrie d'abord : protocole et copilote (M-131), jauge de l'en-tête qui mesure vraiment (M-132), coordonnées à copier (M-133). Puis la carte : couleurs des catégories (M-144), lieu survolé allumé (M-192), zoom manuel (M-142), noms qui ne se chevauchent pas (M-143).

### V13.5.8 — Statut, badges et dock

**Objectif :** Des boucliers, voyants et bandeaux qui expliquent, et des badges qui servent de raccourcis. Pour TARDIS_2 et TARDIS_3 surtout.

- **M-136. Fenêtre des boucliers qui se referme seule** *(petit)* : W.choixBoucliers reste ouverte après un choix et ne se ferme qu'au même bouton. La fermer après le choix ou au clic ailleurs.
- **M-137. Un seul écran pour les boucliers** *(petit)* : Les boucliers existent deux fois (fenêtre du dock et page Outils › Boucliers) avec des textes différents. Garder une seule version, plus claire.
- **M-135. Avertissement sous le seuil des portes** *(petit)* : Relâcher le curseur de taille sous le trait bleu prévient « les portes ne s'ouvriront plus » avant d'envoyer la commande Taille.
- **M-138. Voyant Démarrage bloqué qui explique** *(petit)* : Le voyant « BLOQUÉ » du dock dit pourquoi le démarrage est bloqué, et un clic ouvre la tablette technicien (Ingénierie).
- **M-182. Bandeau Maintenance en haut de la tablette** *(petit)* : En maintenance, une bande orange avec la raison, l'auteur et un bouton « Lever » reste visible quel que soit l'onglet ouvert.
- **M-200. Pastilles d'alerte dans l'en-tête** *(petit)* : Quand le panneau Statut est masqué (widgets ou mode débutant), les alertes importantes (siège, alerte, maintenance) restent visibles en petites pastilles dans l'en-tête.
- **M-161. Bandeau visible en mode débutant** *(petit)* : En mode débutant, un bandeau « Mode débutant : panneaux masqués · désactiver » explique pourquoi la tablette paraît vide.
- **M-129. Badges du statut transformés en raccourcis** *(moyen)* : Clic sur VERROUILLÉ pour déverrouiller, sur SIÈGE pour ouvrir la page Siège, sur BLOQUÉ pour ouvrir Ingénierie.

**Dans Studio :** Rien.

*Pourquoi ici :* Etat.lua et le dock. Boucliers : fenêtre qui se referme (M-136), un seul écran au lieu de deux (M-137), avertissement sous le seuil des portes (M-135). Voyant BLOQUÉ qui explique (M-138), bandeau Maintenance (M-182), pastilles d'alerte dans l'en-tête (M-200), bandeau du mode débutant (M-161). M-129 rend les badges cliquables vers les pages : en dernier.

### V13.5.9 — Réglages de la tablette

**Objectif :** Une page RÉGLAGES rangée, cherchable, avec aperçus et dispositions toutes faites. Pour TARDIS_2 et TARDIS_3 surtout.

- **M-114. Remettre une seule touche par défaut** *(petit)* : Un petit ↺ sur chaque ligne de touche remet sa valeur d'origine, au lieu du seul bouton rouge qui rétablit toutes les touches d'un coup.
- **M-155. Conflits de touches signalés** *(petit)* : Quand deux actions du même contexte ont la même touche, la ligne passe en orange avec « déjà utilisée par… » (liste TOUCHES du Volet).
- **M-111. Champ de recherche en haut des réglages** *(petit)* : La page RÉGLAGES du Volet est longue ; un champ filtre les lignes (« flash », « vortex », « touche V ») pour trouver un réglage tout de suite.
- **M-156. Aperçu du thème au survol** *(petit)* : Survoler un thème dans les réglages change les couleurs un instant (UI.appliquerTheme) ; quitter le survol revient au thème choisi.
- **M-157. Flou et voile réglables derrière la tablette** *(petit)* : Choisir la force du flou (18) et du voile noir (0,45), et les alléger pendant un voyage pour voir la cabine s'effacer.
- **M-195. Aperçu animé de la forme du vortex** *(petit)* : À côté du réglage « Forme du vortex » (grille, anneaux, spirale), une petite vignette animée montre à quoi ressemble chaque forme avant de la choisir.
- **M-154. Réglages rangés en sections repliables** *(moyen)* : La page RÉGLAGES est une longue liste où les statistiques tombent au milieu. La ranger en sections : Affichage, Sons, Touches, Thème, Statistiques.
- **M-106. Dispositions des panneaux enregistrées en un clic** *(moyen)* : Des dispositions toutes faites (Pilotage, Sécurité, Complète) règlent d'un coup les widgets de la tablette (UI.prefs.widgets), au lieu de cocher sept lignes.

**Dans Studio :** Rien.

*Pourquoi ici :* La page RÉGLAGES du volet. Touches d'abord : remettre une seule touche (M-114), conflits signalés (M-155). Puis recherche (M-111), aperçu du thème au survol (M-156), flou et voile réglables (M-157), aperçu animé du vortex (M-195). M-154 range la page en sections, M-106 enregistre des dispositions de panneaux : en dernier.

### V13.5.10 — Volet et outils

**Objectif :** Un volet plus fluide et une grille d'outils plus facile, qui laisse plus de place à l'écran. Pour TARDIS_2 et TARDIS_3 surtout.

- **M-163. Volet latéral qui glisse à l'ouverture** *(petit)* : Le volet apparaît d'un coup (Visible = true). Il glisserait depuis la droite en 0,2 s, et ses pages changeraient en fondu.
- **M-164. Fil d'Ariane dans le titre du volet** *(petit)* : Le titre affiche « Outils › Équipage › Alex » et chaque partie est cliquable pour remonter.
- **M-126. Familles d'outils repliables dans la grille** *(petit)* : Les titres VOYAGE, SÉCURITÉ et AMBIANCE de la grille d'outils se replient d'un clic, et l'état replié est retenu dans les préférences.
- **M-167. Recherche et épingles dans la grille d'outils** *(petit)* : Un champ filtre les 22 tuiles d'outils, et les outils épinglés par le pilote passent en tête de la grille.
- **M-168. Minuterie à durée libre visible partout** *(petit)* : Un champ en secondes en plus des 5 durées fixes, et le compte à rebours affiché dans l'en-tête et quand la tablette est fermée.
- **M-169. Rappel à maintenir pour éviter l'erreur** *(petit)* : Rappel déplace le TARDIS d'un seul clic ; maintenir 1 seconde (barre qui se remplit) éviterait un rappel par mégarde.
- **M-166. Volet par-dessus la tablette sur petit écran** *(moyen)* : Sur petit écran, le volet passerait par-dessus la tablette au lieu de la pousser et de la rapetisser (echelleBase).
- **M-159. Tablette qui se resserre sans colonne vide** *(moyen)* : Quand des widgets sont masqués, appliquerWidgets remonte les panneaux mais garde la largeur. La tablette se resserrerait sur les colonnes visibles.

**Dans Studio :** Rien.

*Pourquoi ici :* Volet.lua et Outils.lua. Volet qui glisse (M-163), fil d'Ariane (M-164), familles d'outils repliables (M-126), recherche et épingles (M-167). Outils : minuterie à durée libre (M-168), rappel à maintenir (M-169). Puis la place à l'écran : volet par-dessus la tablette sur petit écran (M-166), tablette qui se resserre (M-159).

### V13.5.11 — Équipage et invitations

**Objectif :** Des pages Équipage, Inviter et Registre plus vivantes, et des occupants cliquables. Pour TARDIS_2 et TARDIS_3 surtout.

- **M-160. Temps passé à bord pour chaque occupant** *(petit)* : Le panneau OCCUPANTS indique depuis combien de temps chacun est à bord (« Alex · 4 min »), utile pour repérer un visiteur oublié.
- **M-170. Inviter : recherche et tri par distance** *(petit)* : La page Inviter liste tout le monde sans ordre. Ajouter un tri par distance, une recherche et une pastille « invitation envoyée ».
- **M-181. Inviter plusieurs joueurs en une fois** *(petit)* : La page Inviter permet de cocher plusieurs joueurs puis d'envoyer toutes les invitations d'un seul bouton, au lieu d'une page par joueur.
- **M-171. Équipage : durées en direct et recherche** *(petit)* : Les durées restantes des rôles se mettent à jour seules, une recherche aide sur un serveur plein, et Bannir demande un second clic.
- **M-172. Registre : plus de lignes et expulsion groupée** *(petit)* : L'historique du registre s'arrête à 14 lignes : ajouter « voir plus », et un bouton « expulser tous les visiteurs » avec confirmation.
- **M-149. Occupants cliquables avec actions** *(moyen)* : Les noms du panneau OCCUPANTS deviennent des boutons (nommer copilote, expulser), et la liste défile si elle est longue (aujourd'hui le texte déborde).
- **M-178. Voir les choix du copilote** *(moyen)* : La tablette du pilote affiche la destination et le protocole choisis par le copilote, et qui a fait le dernier changement.

**Dans Studio :** Rien.

*Pourquoi ici :* Temps à bord (M-160), Inviter avec tri par distance et plusieurs joueurs (M-170, M-181), durées des rôles en direct (M-171), registre plus long et expulsion groupée (M-172). M-149 rend les occupants cliquables (nommer copilote, expulser, actions déjà permises au serveur). M-178 montre les choix du copilote, en miroir de M-97 dans le menu.

### V13.5.12 — Customisation et jukebox

**Objectif :** Une page Customisation en onglets, avec aperçus et tenues enregistrées, et un jukebox qui montre la piste. Pour TARDIS_2 et TARDIS_3 surtout.

- **M-175. Couleur actuelle de la cabine marquée** *(petit)* : Les boutons de couleur extérieure n'indiquent pas le choix actif, contrairement aux murs. Les marquer, et ajouter « Revenir au style d'origine ».
- **M-176. Aperçu en direct de l'enseigne** *(petit)* : Un compteur 0/24 et un aperçu du texte en lettres d'enseigne avant d'appuyer sur Appliquer.
- **M-185. Recherche dans les pistes du jukebox** *(petit)* : Quand Config.Jukebox a beaucoup de pistes, un champ en haut de la page Jukebox filtre par nom ou par catégorie.
- **M-173. Customisation rangée en trois onglets** *(moyen)* : La page Customisation est très longue : la couper en onglets Intérieur, Console et Extérieur.
- **M-177. Jukebox : piste en cours et suivante** *(moyen)* : La page montre la piste qui joue, un bouton « Suivante » pour les playlists, et ne se ferme plus à chaque choix (fermerSurcouche).
- **M-184. Tenues complètes du TARDIS enregistrées sous un nom** *(moyen)* : Dans Customisation, enregistrer l'ensemble intérieur, console, couleur, décoration et enseigne sous un nom, puis le remettre en un clic.

**Dans Studio :** Rien.

*Pourquoi ici :* Couleur actuelle marquée (M-175), aperçu de l'enseigne avec compteur (M-176), recherche des pistes (M-185). Puis les gros : Customisation en trois onglets (M-173), piste en cours et suivante (M-177), tenues complètes du TARDIS sous un nom (M-184), qui ajoute une préférence sauvegardée (clés permises de T-64).

### V13.5.13 — Carnet, balises et pannes

**Objectif :** Un carnet plus pratique, plusieurs balises à la fois et une tablette qui suit la réparation et le hors tension. Pour TARDIS_2 et TARDIS_3 surtout.

- **M-179. Carnet : recherche, épingle et brouillon gardé** *(moyen)* : Recherche dans les notes, note épinglée en tête, et le texte en cours reste si on change de page (il est perdu aujourd'hui).
- **M-183. Plusieurs balises de détresse à la fois** *(moyen)* : L'alerte ne garde que la dernière balise (baliseCourante). Une petite liste montrerait chaque appel avec sa distance et son « Y aller ».
- **M-180. Voile Avarie avec progression de la réparation** *(moyen)* : Le voile AVARIE montre en direct l'avancée de la réparation du rotor et qui répare, et laisse accessibles Ingénierie et Registre.
- **M-188. Allumage de secours hors tension** *(moyen)* : Hors tension, la tablette s'allume en mode secours : écran plus sombre, seuls Statut et Ingénierie restent actifs. Plus RP et plus clair.

**Dans Studio :** Rien.

*Pourquoi ici :* Quatre lots moyens : carnet avec recherche, épingle et brouillon (M-179), plusieurs balises à la fois (M-183, au lieu de baliseCourante), voile AVARIE avec la progression de la réparation (M-180). M-188 (allumage de secours hors tension) change ce que montre toute la tablette : en dernier.

### V13.5.14 — Animations et veille

**Objectif :** Des transitions douces, un écran de veille et une page des nouveautés. Pour TARDIS_2 et TARDIS_3 surtout.

- **M-189. Liste qui glisse en changeant d'onglet** *(petit)* : Entre Lieux, Joueurs, Coordonnées et Historique, la liste glisse de côté et les lignes arrivent en petite cascade.
- **M-190. Petite animation d'atterrissage réussi** *(petit)* : À l'arrivée, l'anneau de statut fait un tour vert et « POSÉ » apparaît en douceur (sans flash).
- **M-187. Fermeture façon vieil écran qui s'éteint** *(petit)* : À la fermeture (Ouverture.fermer), l'écran se réduit en une ligne lumineuse puis disparaît, au lieu du simple rétrécissement.
- **M-186. Écran de veille après une longue inactivité** *(petit)* : Après 2 minutes sans action, l'écran de la tablette s'assombrit et ses animations s'arrêtent ; un clic le rallume avec la petite animation d'allumage.
- **M-196. Page des nouveautés après une mise à jour** *(petit)* : Quand Config.Version change, la tablette ouvre une fois une page qui résume les nouveautés pour les pilotes.

**Dans Studio :** Rien.

*Pourquoi ici :* L'habillage passe après le fond : liste qui glisse entre onglets (M-189), atterrissage réussi sans flash (M-190), fermeture façon vieil écran (M-187, Ouverture.fermer), écran de veille (M-186), page des nouveautés quand Config.Version change (M-196).

### V13.5.15 — Téléphone et repères de console

**Objectif :** Une tablette à une colonne sur téléphone, et des repères vers la console (à reconsidérer).

- **M-199. Disposition téléphone une colonne à la fois** *(gros)* : Sur petit écran, une colonne à la fois avec des onglets en bas (Statut, Navigation, Scanner), au lieu d'une tablette rapetissée jusqu'à 0,4.
- **M-197. Repères vers la future console** *(moyen)* : Chaque commande indique où elle sera sur la console (« levier de gauche »), pour habituer les pilotes avant la V11.

**Dans Studio :** Rien.

*Pourquoi ici :* M-199 (une colonne à la fois avec des onglets en bas) est le plus gros chantier de la tablette : en dernier. M-197 (repères vers la future console) n'a plus beaucoup de sens après la V12 : TARDIS_1 a déjà sa console et celles de TARDIS_2 et TARDIS_3 ne seront pas faites. Il est rangé ici, mais il vaut mieux l'écarter.

## V13.6 — Autres interfaces et accessibilité (17 lots, 102 propositions)

Améliorer tout ce qui reste à l'écran après la V12, sur tous les TARDIS : tablette technicien, poste du copilote, vol libre, boutons tactiles, bandeaux, régénération, et des réglages d'accessibilité pour tous.

### V13.6.1 — Briques communes de TardisUI

**Objectif :** Des règles et des briques communes pour toutes les petites interfaces : icônes, fermeture, apparition, boutons, panneaux, couleurs.

- **M-292. Règle unique pour les icônes des titres** *(petit)* : ◆, ●, ▲ et ■ sont utilisés au hasard (« ◆ INVITATION », « ● INTERPHONE », poste du copilote sans icône). Une règle simple : ◆ information, ▲ alerte, ● état.
- **M-293. Bouton fermer au même endroit partout** *(petit)* : Croix en haut pour la tablette technicien, « Fermer » en bas pour le casier, « – » pour le copilote, Échap seul pour le replay : un même bouton × en haut à droite partout.
- **M-298. Une seule animation d'apparition des bandeaux** *(petit)* : Chaque bandeau a sa propre entrée (Back 0,35 s, 0,45 s, 0,5 s, 0,6 s). Une UI.apparaitre et une UI.disparaitre communes donnent le même mouvement partout.
- **M-290. Un seul bouton secondaire dans TardisUI** *(moyen)* : TabletteTechnicien, Interactions, Copilote et Systemes ont chacun leur fonction bouton(). Une UI.boutonSecondaire commune (coin, contour, reflet, rendreVivant) les remplace.
- **M-291. Un panneau latéral commun aux interfaces** *(moyen)* : Copilote, lecture seule, casier et interphone recréent chacun leur cadre. Une UI.panneauLateral avec en-tête, bouton réduire et échelle donne le même aspect partout.
- **M-299. Couleurs d'action rangées dans la palette** *(moyen)* : Valider, refuser et danger utilisent des vert et rouge différents d'un fichier à l'autre, et une vingtaine de couleurs du vol libre ne suivent pas le thème. Les ranger dans UI.C pour qu'elles suivent Gallifrey, Cristal et Police Box.

**Dans Studio :** Rien.

*Pourquoi ici :* Socle avant usage : tous les lots suivants de la V13.6 s'en servent. Règles d'abord : icônes des titres (M-292), bouton fermer au même endroit (M-293). Puis les briques dans TardisUI : UI.apparaitre / UI.disparaitre (M-298), bouton secondaire unique (M-290, à la place des bouton() de TabletteTechnicien, Interactions, Copilote et Systemes), panneau latéral commun (M-291), couleurs d'action dans la palette (M-299).

### V13.6.2 — Accessibilité pour tous

**Objectif :** Un vocabulaire commun, des textes lisibles et des options d'accessibilité pour tous les rôles, pas seulement les pilotes.

- **M-297. Même vocabulaire dans toutes les interfaces** *(petit)* : « Silence » dans le copilote mais « Silencieux » ailleurs, « /balisehelp » dans l'aide alors que le glossaire dit /tardis help : une seule table de libellés (Config.libelleMode) pour tout.
- **M-300. Contour lisible des textes posés sur la scène** *(petit)* : Le texte du replay, la bulle d'interphone et l'étiquette « Localiser » n'ont pas ou peu de contour et se perdent sur un ciel clair : une option ajoute un contour sombre épais à ces textes.
- **A-74. Infobulles sur chaque bouton** *(petit)* : Une courte explication au survol de chaque commande.
- **M-286. Police simple au choix du joueur** *(petit)* : Option qui remplace Michroma et Code par Gotham partout (UI.POLICE_TITRE, UI.POLICE_CODE), plus facile à lire, notamment pour les lecteurs dyslexiques.
- **M-287. Option sans lignes d'écran ni vignette** *(petit)* : UI.lignesEcran et UI.vignette assombrissent les bords et baissent le contraste des textes ; une option les retire de toutes les interfaces.
- **M-284. Réglages d'accessibilité pour tous les rôles** *(moyen)* : Taille, volume, réduire les effets, aucun flash et thème ne se règlent que dans la tablette des pilotes. Une roue ⚙ dans la tablette technicien, le poste du copilote et l'interphone ouvre ces mêmes réglages.
- **M-285. Thème à fort contraste** *(moyen)* : Un quatrième thème (noir, texte blanc, bordures jaunes) vérifié à un contraste d'au moins 7:1, pour les joueurs qui voient mal.

**Dans Studio :** Rien.

*Pourquoi ici :* Même vocabulaire partout (M-297), contour des textes sur la scène (M-300), infobulles sur chaque bouton (A-74, premier tri). Puis les options : police simple (M-286), sans lignes d'écran ni vignette (M-287). M-284 ouvre les réglages d'accessibilité à tous les rôles : il recoupe la V11.7 (réglages hors de la tablette), à vérifier avant. M-285 (thème fort contraste 7:1) en dernier.

### V13.6.3 — Lecture seule, replay, porter et caméra

**Objectif :** Une tablette en lecture seule en clair, un replay quittable au doigt, et les boutons de TardisPorter et TardisCamera refaits avec TardisUI.

- **M-295. Tablette en lecture seule avec états en clair** *(petit)* : Elle affiche « État : Pose », le nom brut de l'attribut, au lieu de « POSÉ ». Utiliser UI.LIBELLES comme partout et grouper les lignes sous de petits titres.
- **M-296. Légende sous la carte en lecture seule** *(petit)* : Sur la carte de la tablette en lecture seule, ◆ lieux, ▲ TARDIS et points des joueurs n'ont pas de légende ; une ligne de légende sous la carte.
- **M-294. Bouton quitter et barre pour le replay** *(petit)* : Le replay dit « Échap pour quitter », impossible sur téléphone. Un bouton Quitter et une barre de progression du vol rejoué.
- **M-289. Porter et caméra refaits avec TardisUI** *(moyen)* : TardisPorter et TardisCamera créent leurs boutons à la main (couleurs fixes, police Gotham, sans échelle). Passer par UI.creer leur donne le thème, la taille et les boutons vivants.

**Dans Studio :** Rien.

*Pourquoi ici :* TabletteLecture : états en clair avec UI.LIBELLES (M-295) et légende de la carte (M-296). Replay : bouton Quitter et barre de progression (M-294), indispensable sur téléphone. M-289 refait les boutons de TardisPorter et TardisCamera avec les briques de V13.6.1 : en dernier.

### V13.6.4 — Technicien : interventions

**Objectif :** Des cartes d'intervention triées, avec délais visibles, fin en vert et diagnostic en tableau.

- **M-202. Interventions triées par gravité avec étiquette CRITIQUE** *(petit)* : lirePannes ajoute les pannes dans un ordre fixe (avarie, redémarrage, vapeur, incendie…). Les trier par gravité met toujours l'incendie et l'avarie en haut, avec une étiquette rouge CRITIQUE.
- **M-206. Choisir la raison de la maintenance** *(petit)* : Le bouton MAINTENANCE de la tablette technicien envoie toujours la raison n°1. Un petit menu avec les raisons de Config.Maintenance.Raisons permet de dire pourquoi le TARDIS est bloqué.
- **M-215. Délais des interventions en petite barre** *(petit)* : Les délais (redémarrage à distance, vanne avant reprise du feu, purge) s'affichent aussi en barre qui se vide sur la carte d'intervention, plus lisible qu'un nombre de secondes dans une phrase.
- **M-216. Carte réglée qui passe au vert** *(petit)* : Une panne réglée ne disparaît plus d'un coup : sa carte devient verte « ✓ Réglé » pendant 3 s puis se replie. Le technicien voit que son geste a compté.
- **M-277. Petit son quand une étape est validée** *(petit)* : Dans les cartes d'intervention, chaque étape qui passe de ► à ✓ joue un bref son de réussite : le technicien sait que son geste a marché sans regarder la tablette.
- **M-207. Journal technique ouvrable en grand** *(petit)* : Le journal ne fait que 96 px de haut. Un clic l'ouvre en grand par-dessus la colonne de droite, avec un filtre simple : pannes, commandes, tout.
- **M-217. Résultat du diagnostic présenté en tableau** *(moyen)* : Après DIAGNOSTIC, une carte liste chaque système avec OK ou à surveiller, au lieu d'un seul message qui disparaît en 4 s.

**Dans Studio :** Rien.

*Pourquoi ici :* TabletteTechnicien (environ 810 lignes), lirePannes. Tri par gravité (M-202), choix de la raison de maintenance (M-206), délais en petite barre (M-215), carte réglée qui passe au vert (M-216) avec un petit son (M-277), journal technique en grand (M-207). M-217 (résultat du diagnostic en tableau) en dernier.

### V13.6.5 — Technicien : jauges et plan

**Objectif :** Des jauges plus précises (boutons, seuils, tendances, courbes) et un plan de la salle.

- **M-203. Boutons moins et plus sur les curseurs** *(petit)* : Les curseurs Énergie, Air et Vapeur ne se règlent qu'en glissant. Deux petits boutons − / + (et les flèches du clavier quand le curseur est choisi) donnent un réglage précis au doigt et à la manette.
- **M-288. Repères de seuil sur les jauges techniques** *(petit)* : Les jauges de la tablette technicien changent de couleur mais n'ont aucun trait : de petits repères aux seuils (air vicié 25 %, intégrité 20 et 50 %) montrent la marge qui reste.
- **M-204. Flèche de tendance à côté des jauges** *(petit)* : Une petite flèche ↑ ou ↓ à côté de chaque valeur (air qui baisse, tension qui monte), calculée sur les 10 dernières secondes : le technicien voit venir le problème avant le seuil.
- **M-211. Opacité de la tablette technicien réglable** *(petit)* : Un petit curseur dans l'en-tête de TabletteTechnicien rend la tablette plus ou moins transparente : le technicien voit la salle et la panne derrière tout en lisant les étapes, sans fermer la tablette.
- **M-205. Mini-courbes des deux dernières minutes** *(moyen)* : Sous l'air, la tension et l'intégrité, une courbe minuscule des 2 dernières minutes (gardée en mémoire chez le joueur) montre si la purge ou la régulation a vraiment marché.
- **M-230. Plan de la salle dans la tablette technicien** *(moyen)* : Un petit plan vu de dessus de l'intérieur (calculé depuis GetBoundingBox et les repères grilles, rotor, console, levier) avec un point rouge sur chaque panne et la position du technicien : on sait où aller d'un coup d'œil.

**Dans Studio :** Rien.

*Pourquoi ici :* Curseurs Énergie, Air, Vapeur avec − et + (M-203), repères de seuil (M-288), flèche de tendance (M-204), opacité réglable (M-211). M-205 garde deux minutes d'historique en mémoire pour les mini-courbes ; M-230 dessine le plan de la salle vu de dessus : en dernier.

### V13.6.6 — Technicien : outils et panneaux

**Objectif :** Un panneau technicien qui se montre au bon moment et guide vers la pièce à réparer.

- **M-209. Outil déjà en main signalé dans la tablette** *(petit)* : Dans le panneau OUTILS et sur les boutons « Prendre : … », l'outil que le technicien tient déjà est marqué « en main » (contour vert), pour éviter de cliquer pour rien.
- **M-210. Bouton retour vers la tablette de pilotage** *(petit)* : Un pilote qui ouvre l'Ingénierie depuis sa tablette n'a que la croix pour sortir. Un bouton « ◄ Pilotage » dans l'en-tête le ramène directement à sa tablette.
- **M-213. Panneau des outils caché quand la tablette s'ouvre** *(petit)* : Le petit panneau « ◆ TECHNICIEN » en bas à gauche (Systemes.lua) refait les 5 boutons d'outils de la tablette. Il se cache quand la tablette est ouverte et peut se replier en une seule icône.
- **M-214. Panneau technicien seulement à bord ou près** *(petit)* : Ce même panneau reste à l'écran partout sur la carte, même loin du TARDIS. L'afficher seulement à bord ou à moins de 30 studs de la cabine libère l'écran pendant le reste du RP.
- **M-208. Flèche au bord de l'écran vers la cible** *(moyen)* : Quand la pièce de « Localiser » est hors du champ, une flèche ambrée au bord de l'écran indique où tourner la tête, en plus du contour et de la distance déjà affichés.
- **M-212. Mini-panneau ingénierie tablette fermée** *(moyen)* : Un petit encart repliable, comme l'onglet du copilote, montre la pastille d'état et l'étape en cours de la première intervention : on suit les étapes sans garder la grande tablette ouverte.

**Dans Studio :** Rien.

*Pourquoi ici :* Systemes.lua et TabletteTechnicien. Outil en main signalé (M-209), retour vers la tablette de pilotage (M-210), panneau ◆ TECHNICIEN caché quand la tablette s'ouvre (M-213) et montré seulement près du TARDIS (M-214). Flèche au bord de l'écran vers la cible de Localiser (M-208), mini-panneau tablette fermée (M-212).

### V13.6.7 — Copilote : état et voyage

**Objectif :** Un poste du copilote qui montre protocole, progression, distance et pilote, et qui tient sur un téléphone.

- **M-220. Protocole en cours sur la ligne d'état** *(petit)* : La ligne d'état du copilote n'affiche que POSÉ ou VORTEX. Ajouter le protocole en cours (avec sa couleur) et le lieu visé, comme le fait déjà le menu des pilotes.
- **M-224. Onglet réduit du copilote avec l'état** *(petit)* : L'onglet « ◆ COPILOTE » montre aussi un mot court et sa couleur (Posé, Vortex, Vol libre) pour suivre le voyage sans rouvrir le panneau.
- **M-219. Progression du voyage sur DÉMAT et REMAT** *(petit)* : Les grands boutons du copilote ont déjà la barre Remplissage de UI.boutonPrincipal, mais elle reste vide. La remplir avec la progression du voyage montre où on en est.
- **M-227. Distance affichée pour la destination choisie** *(petit)* : À côté de « → Lieu », la distance en studs (calculée depuis CarteDestinations) aide le copilote à choisir sans ouvrir de carte.
- **M-228. Nom du pilote en haut du poste** *(petit)* : « Pilote : X » avec une pastille (en ligne, en vol libre) en haut du poste, pour savoir qui a confié la navigation et qui tient les commandes.
- **M-221. Liste des destinations du copilote en sections** *(petit)* : Retour, Lieux et Joueurs séparés par de petits titres repliables : aujourd'hui tous les joueurs du serveur suivent les lieux dans une seule liste de 160 px.
- **M-218. Poste du copilote lisible sur téléphone** *(moyen)* : Le panneau de 360 × 650 se réduit à 0,55 sur un téléphone couché. Une version compacte (destination en liste déroulante, boutons pleine largeur) garde des textes lisibles.

**Dans Studio :** Rien.

*Pourquoi ici :* Copilote.lua. Protocole sur la ligne d'état (M-220), onglet réduit avec l'état (M-224), barre de progression sur DÉMAT et REMAT (M-219), distance de la destination (M-227), nom du pilote (M-228), liste en sections (M-221). M-218 (version compacte sur téléphone, sur le panneau commun de M-291) en dernier.

### V13.6.8 — Copilote : messages et confort

**Objectif :** Des messages qui s'effacent ou préviennent, et un poste qu'on peut replier et déplacer.

- **M-222. Message quand on perd le poste** *(petit)* : Quand le pilote retire le poste, le panneau disparaît sans un mot. Un court message « Tu n'es plus copilote » (ou « le pilote a quitté le jeu ») explique ce qui s'est passé.
- **M-223. Réponses du serveur qui s'effacent** *(petit)* : Dans le poste du copilote, la dernière réponse reste affichée pour toujours. Elle repasse en gris après 8 s, puis revient au message d'accueil.
- **M-226. Compteur de caractères du carnet copilote** *(petit)* : La note se coupe sans prévenir à Config.Carnet.LongueurMax. Un compteur « 42 / 200 » et un petit « Note enregistrée » en vert confirment l'envoi.
- **M-225. Panneau du copilote replié retenu** *(petit)* : Le choix replié ou ouvert est gardé dans les préférences, au lieu de revenir ouvert à chaque nomination.
- **M-229. Poste du copilote déplaçable à gauche** *(petit)* : Il est collé à droite, au même endroit que la tablette en lecture seule, le casier et l'interphone. Pouvoir le passer à gauche (choix retenu) évite qu'ils se recouvrent.

**Dans Studio :** Rien.

*Pourquoi ici :* Toujours Copilote.lua : message quand on perd le poste (M-222), réponses qui s'effacent (M-223), compteur du carnet (M-226), panneau replié retenu (M-225), poste déplaçable à gauche (M-229).

### V13.6.9 — Vol libre : tableau de bord

**Objectif :** Un tableau de bord du vol libre plus complet : vitesse verticale, altitude, cap, phase, recharges, obstacles.

- **M-237. Message « aucune cible » enfin visible** *(petit)* : basculerCible écrit « Aucune cible… » dans infosSecondaires, mais la boucle d'affichage le remplace à l'image suivante par la ligne G et boost. Le message doit rester 3 s.
- **M-231. Vitesse verticale sur le tableau du vol** *(petit)* : À côté de l'altitude, une flèche ↑ ou ↓ et la vitesse de montée ou de descente en studs/s : utile pour descendre en douceur avant SE POSER.
- **M-240. Alerte du plafond d'altitude sur le HUD** *(petit)* : Le chiffre d'altitude passe à l'ambre puis au rouge en approchant Config.VolLibre.AltitudeMax, avec un petit mot « PLAFOND ».
- **M-244. Repère de la destination sur la boussole** *(petit)* : Si une destination est choisie, un repère ◆ ambré sur la boussole défilante indique son cap pendant le vol libre.
- **M-247. Phase du vol en bandeau coloré** *(petit)* : La phase (MATÉRIALISÉ, INVISIBLE…) est écrite en 10 px. La mettre en bandeau coloré en haut du tableau : c'est l'information la plus importante pour savoir si on est vu.
- **M-235. Pastilles des modes actifs sur le tableau** *(petit)* : Stationnaire, planeur, cible, cap fixe, précision et tracteur ne se voient que par un « ● » dans PLUS. Une rangée de pastilles sur le tableau de bord les montre même sous-menu fermé.
- **M-236. Recharge du saut et du boost visible** *(petit)* : Les boutons SAUT (4 s) et BOOST (6 s) se remplissent comme une jauge pendant la recharge, au lieu du texte « boost dans 3 s » en 10 px.
- **M-232. Alerte d'obstacle devant sur le réticule** *(petit)* : Un rayon lancé devant la cabine fait passer le réticule à l'ambre puis au rouge quand un mur ou un bâtiment approche à pleine vitesse, avant la collision.
- **A-22. Altimètre et compas** *(petit)* : Un petit cadran qui affiche l'altitude, le cap et la vitesse.

**Dans Studio :** Rien.

*Pourquoi ici :* Le HUD de TardisVolLibre (la V12 laisse le vol libre à l'écran pour tous les TARDIS). Correction d'abord : le message « aucune cible » enfin visible (M-237). Puis vitesse verticale (M-231), alerte du plafond d'altitude (M-240), repère de destination sur la boussole (M-244), phase en bandeau (M-247), pastilles des modes (M-235), recharges du saut et du boost (M-236), alerte d'obstacle (M-232, un raycast par l'utilitaire de la V9). A-22 (altimètre et compas, premier tri) est déjà presque là : vérifier et compléter.

### V13.6.10 — Vol libre : boutons et options

**Objectif :** Des boutons mieux rangés et des options de HUD (masqué, compact, miroir, effets réduits).

- **M-246. Bouton CHUTE isolé des autres boutons** *(petit)* : CHUTE est dangereux mais placé entre REMAT et SE POSER. Le mettre seul en bas, séparé par un espace, évite les erreurs de doigt sur mobile.
- **M-245. Sous-menu PLUS rangé par familles** *(petit)* : Les 13 boutons du sous-menu sont groupés sous trois petits titres (Déplacement, Aides, Spécial) au lieu d'une grille dans l'ordre des touches.
- **M-234. Sous-menu PLUS retenu entre deux vols** *(petit)* : Ouvert ou fermé, l'état du sous-menu PLUS est gardé dans les préférences pour le vol suivant.
- **M-233. Icônes de manette sur les boutons** *(petit)* : Si une manette est branchée, les boutons du vol libre montrent les boutons de la manette (Y vitesse, X vortex déjà gérés) au lieu des lettres du clavier.
- **M-241. Touche pour masquer le HUD du vol** *(petit)* : Une touche cache boussole, tableau de bord et boutons pour les captures ou les scènes RP ; toutes les commandes restent actives.
- **M-242. HUD du vol libre en version compacte** *(petit)* : Option qui ne garde que la vitesse, la phase et l'altitude dans un petit bandeau, pour les petits écrans où le tableau de 330 px gêne la vue.
- **M-243. Disposition miroir des boutons du vol** *(petit)* : Option : panneau des boutons à gauche et tableau de bord à droite, pour les gauchers et sur téléphone où le pouce droit tient la caméra.
- **M-248. Lignes de vitesse adoucies en effets réduits** *(petit)* : Les 18 lignes qui scintillent au bord de l'écran et l'élargissement du champ de vision ne tiennent pas compte de « réduire les effets » ; les adoucir ou les couper.

**Dans Studio :** Rien.

*Pourquoi ici :* CHUTE isolé des autres boutons (M-246), sous-menu PLUS rangé par familles (M-245) et retenu (M-234), icônes de manette (M-233). Puis les options : masquer le HUD (M-241), HUD compact (M-242), disposition miroir (M-243), lignes de vitesse calmées en effets réduits (M-248).

### V13.6.11 — Vol libre : cible et fin du vol

**Objectif :** Voir la cible suivie avant et pendant la formation, un résumé à la fin, et un encart pour les passagers.

- **M-238. Marqueur sur la cible suivie en formation** *(petit)* : En formation (L), un contour léger et le nom au-dessus du joueur ou du véhicule suivi, pour savoir qui on suit vraiment.
- **M-239. Aperçu de la cible avant le verrouillage** *(moyen)* : En visant, le candidat que L choisirait est légèrement surligné sous le réticule : on sait avant d'appuyer qui sera suivi.
- **M-249. Petit résumé à la fin du vol** *(petit)* : En quittant le vol libre, une carte de 4 s : durée, distance, vitesse maximale et G maximal (vol.gMax est déjà mesuré).
- **M-250. Encart pour les passagers pendant le vol** *(moyen)* : À bord pendant un vol libre, un petit encart discret (nom du pilote, vitesse, altitude) aide les passagers à suivre le RP.

**Dans Studio :** Rien.

*Pourquoi ici :* Formation : marqueur sur la cible suivie (M-238), aperçu avant le verrouillage (M-239). Fin du vol : petit résumé avec vol.gMax (M-249). M-250 (encart pour les passagers) est un nouveau ScreenGui pour ceux qui ne pilotent pas : en dernier.

### V13.6.12 — Boutons tactiles

**Objectif :** Des boutons tactiles qui se cachent pendant les scènes, montrent l'état et les alertes, et se déplacent.

- **M-252. Boutons tactiles cachés pendant les scènes** *(petit)* : Les boutons T, Y et ingénierie se cachent en vol libre (le HUD a ses boutons), pendant le replay, la caméra du TARDIS et le choix de régénération.
- **M-253. Couleur d'état sur le bouton T** *(petit)* : Le contour du bouton T prend la couleur de l'état du TARDIS (vert posé, ambre en voyage, cyan vortex, rouge alerte) pour suivre sans ouvrir le menu.
- **M-254. Pastilles d'alerte sur les boutons tactiles** *(petit)* : Une pastille rouge sur Y quand une balise ou la sentinelle attend le pilote, et sur « Y ingénierie » quand des interventions sont en cours, même tablette fermée.
- **M-251. Boutons tactiles T et Y déplaçables** *(petit)* : Les boutons T et Y sont fixés au bord gauche à 38 % de hauteur. Pouvoir les glisser ailleurs (position retenue) évite qu'ils gênent selon la façon de tenir le téléphone.
- **M-255. Choisir la vitesse en glissant sur mobile** *(petit)* : Sur téléphone, glisser le doigt vers le haut ou le bas sur le bouton VITESSE choisit directement LENT, NORMAL, RAPIDE ou TURBO, au lieu de les faire défiler un par un.
- **M-256. Vibration courte sur mobile et manette** *(petit)* : Avec HapticService, une petite vibration au toucher des boutons tactiles et lors d'une alerte (balise, incendie), désactivable dans les réglages.
- **A-189. Boutons tactiles plus grands** *(petit)* : Des boutons adaptés au doigt sur téléphone et tablette.

**Dans Studio :** Rien.

*Pourquoi ici :* Les boutons T, Y et ingénierie (TardisMenu, TardisRotation). Cachés pendant les scènes (M-252), couleur d'état sur T (M-253), pastilles d'alerte (M-254), boutons déplaçables (M-251), vitesse choisie en glissant (M-255), vibration courte (M-256). A-189 (boutons plus grands au doigt) termine. Après la V12, T et Y restent pour TARDIS_2 et TARDIS_3 ; le bouton d'ingénierie reste pour tous.

### V13.6.13 — Bandeaux et messages hors menu

**Objectif :** Des messages du TARDIS au même style partout, visibles même menu fermé, et une pile commune pour les bandeaux du haut.

- **M-275. Son distinct pour un refus** *(petit)* : Config.SonsInterface utilise le même son pour Notification et Alerte. Un troisième son « Refus », joué quand le serveur répond non, fait comprendre sans lire.
- **M-278. Format commun des messages au chat** *(petit)* : Le seul message système du chat (intercom) a sa couleur rouge écrite en dur. Un format commun « [TARDIS] » avec une couleur info ou alerte, pour tous ceux qui viendront.
- **M-276. Notifications Roblox remplacées par le style TARDIS** *(petit)* : La régénération utilise SetCore « SendNotification » (style gris de Roblox) pour les avatars. Passer par le toast commun garde le même aspect que le reste.
- **M-279. Aucun bandeau pendant le choix de régénération** *(petit)* : Pendant les secondes du choix (TardisRegenChoix), les toasts et bandeaux non urgents attendent, pour ne pas cacher le bouton Refuser.
- **M-257. Messages du serveur visibles menu fermé** *(moyen)* : Les réponses du serveur (dire) ne s'affichent que si le menu ou une tablette est ouvert. Un petit toast commun affiche celles qui arrivent quand tout est fermé.
- **M-262. Pile commune pour les bandeaux du haut** *(moyen)* : Maintenance (52 px), intercom (18 px), invitation (100 px) et boussole du vol libre (52 px) sont placés à la main et peuvent se chevaucher. Une pile dans TardisUI les range l'un sous l'autre.

**Dans Studio :** Rien.

*Pourquoi ici :* Son de refus (M-275), format commun au chat (M-278), notifications au style TARDIS au lieu de SetCore (M-276), aucun bandeau pendant le choix de régénération (M-279). Puis toast des messages menu fermé (M-257), et pile commune des bandeaux (M-262) qui place maintenance, intercom, invitation et boussole : en dernier car il les déplace tous.

### V13.6.14 — Balise et invitations

**Objectif :** Des invitations qui ne s'empilent plus, avec compte à rebours, et une balise qui répond à l'appelant.

- **M-265. Invitations qui ne s'empilent plus** *(petit)* : Deux invitations créent deux cartes « TardisInvitation » l'une sur l'autre. La nouvelle remplace l'ancienne, ou se range dessous avec le nom du pilote.
- **M-264. Compte à rebours visible sur l'invitation** *(petit)* : La carte d'invitation disparaît au bout de 60 s sans le dire. Une barre qui se vide et « expire dans 45 s » montrent le temps qui reste.
- **M-266. Accepter l'invitation à la manette** *(petit)* : Accepter et Refuser avec A et B, et Accepter sélectionné par défaut (GuiService.SelectedObject), pour les joueurs sur console.
- **M-260. Photo du pilote sur la carte d'invitation** *(petit)* : La carte « ◆ INVITATION » (Interactions) affiche la tête du pilote (Players:GetUserThumbnailAsync) à côté de son nom : le joueur reconnaît tout de suite qui l'invite.
- **M-258. Bandeau de confirmation pour l'appelant de la balise** *(petit)* : Un visiteur qui tape /tardis help reçoit « Balise allumée… » mais n'a aucun menu pour le lire. Un bandeau avec le temps restant (Config.Balise.Duree) lui confirme que les pilotes sont prévenus.
- **M-259. Bouton pour éteindre sa propre balise** *(petit)* : Dans ce bandeau, un bouton « Éteindre ma balise » si le joueur n'a plus besoin d'aide, pour ne pas faire venir les pilotes pour rien.
- **M-261. Distance et direction dans l'alerte de balise** *(petit)* : « Nom appelle le TARDIS · 340 studs, nord-est » : le pilote décide plus vite s'il y va.

**Dans Studio :** Rien.

*Pourquoi ici :* Interactions.lua (carte TardisInvitation) et la balise /tardis. Invitations qui se remplacent (M-265), compte à rebours (M-264), manette (M-266), photo du pilote (M-260). Balise : bandeau pour l'appelant (M-258), bouton pour éteindre sa balise (M-259, nouvelle action à déclarer au garde-barrière de la V8), distance et direction pour le pilote (M-261).

### V13.6.15 — Interphone

**Objectif :** Un interphone plus clair : bulle selon la longueur, compteur, panneau repliable, « … écrit ».

- **M-269. Bulle d'interphone qui dure selon la longueur** *(petit)* : La bulle reste 10 s, qu'il y ait trois mots ou deux lignes. Une durée selon la longueur (environ 3 s plus un peu par mot) laisse le temps de lire.
- **M-268. Interphone avec compteur et destinataires** *(petit)* : Le texte est coupé à 120 caractères sans prévenir. Un compteur et une ligne « entendu dehors » ou « entendu à bord » selon où on se trouve.
- **M-267. Interphone replié en un bouton** *(petit)* : Le panneau interphone reste ouvert en bas à droite dès qu'on est à bord. Le réduire en un bouton « ● Interphone » qui s'ouvre au clic libère l'écran.
- **M-263. Interphone : indication « quelqu'un écrit »** *(moyen)* : Quand un joueur tape un message à l'interphone, l'autre côté voit « … écrit » près de la porte, pour attendre la réponse au lieu de repartir.

**Dans Studio :** Rien.

*Pourquoi ici :* Interactions.lua et l'interphone de TardisExtras. Bulle qui dure selon la longueur (M-269), compteur et destinataires (M-268), panneau replié en un bouton (M-267). M-263 (« … écrit ») envoie des messages au serveur pendant la frappe : en dernier, avec une limite de fréquence.

### V13.6.16 — Maintenance et alertes pour les passagers

**Objectif :** Des bandeaux de maintenance et d'alerte compréhensibles par ceux qui ne sont ni pilotes ni techniciens.

- **M-270. Durée de la maintenance dans le bandeau** *(petit)* : Le bandeau « EN MAINTENANCE » ajoute « depuis 12 min », pour savoir si c'est récent ou oublié.
- **M-271. Phrase simple de maintenance pour les passagers** *(petit)* : Les passagers lisent le texte technique (« réparations, portes et boucliers restent possibles »). Pour eux, une phrase simple : « Le TARDIS ne peut pas décoller pour l'instant ».
- **M-272. Bandeau de maintenance cliquable pour les techniciens** *(petit)* : Un clic sur le bandeau ouvre la tablette technicien, ou l'Ingénierie pour un pilote, pour lever la maintenance ou voir la raison.
- **M-273. Compte à rebours d'auto-destruction pour les passagers** *(petit)* : À bord, seuls la teinte rouge et les secousses préviennent les passagers. Un grand compteur « ÉVACUEZ · 14 s » s'affiche pour tous ceux qui sont dedans.
- **M-274. Bandeau d'alerte simple pour les passagers** *(moyen)* : Incendie, avarie, air vicié, alerte générale : une ligne simple en haut pour ceux à bord qui ne sont ni pilote ni technicien. Aujourd'hui l'image se ternit sans explication.

**Dans Studio :** Rien.

*Pourquoi ici :* Signalisation et Maintenance. Durée de la maintenance (M-270), phrase simple pour les passagers (M-271), bandeau cliquable pour les techniciens (M-272), compte à rebours d'auto-destruction à bord (M-273). M-274 (bandeau simple incendie, avarie, air vicié) en dernier, sur la pile commune de M-262.

### V13.6.17 — Choix de la régénération

**Objectif :** Une carte de régénération utilisable en première personne, au clavier et à la manette, et un refus qu'on ne fait pas par erreur.

- **M-282. Souris libérée pendant le choix de régénération** *(petit)* : La carte n'a pas de bouton Modal : en vue à la première personne, la souris reste bloquée et Refuser ne se clique pas. La tablette technicien utilise déjà ce bouton Modal.
- **M-281. Secondes restantes écrites sur la carte** *(petit)* : La barre ambrée se vide sans chiffre. Afficher « 6 s pour refuser » aide à comprendre le temps qu'il reste.
- **M-280. Refuser la régénération par appui long** *(petit)* : Refuser est définitif mais part au premier clic. Maintenir 1,5 s (un anneau qui se remplit) évite un refus par erreur.
- **M-283. Refuser au clavier et à la manette** *(petit)* : Une touche et le bouton B de la manette pour refuser, affichés sur la carte, puisque le joueur à terre n'a pas toujours la souris en main.

**Dans Studio :** Rien.

*Pourquoi ici :* Regeneration.lua (carte TardisRegenChoix). Souris libérée d'abord (M-282) : sans elle, Refuser ne marche pas en vue à la première personne. Puis secondes restantes (M-281), refus par appui long (M-280), touche et bouton B (M-283).

## V13.7 — Voyage et vol libre (4 lots, 21 propositions)

Changer les règles du voyage : départs refusés au bon moment, arrivées plus justes, nouveaux protocoles et vol libre plus vivant.

### V13.7.1 — Règles de départ

**Objectif :** Refuser le départ quand il le faut (réparation, Catastrophe, ancrage) et appliquer le bon mode à tous les départs.

- **C-30. Décollage refusé pendant une réparation** *(petit)* : Tant qu'un technicien a une intervention en cours, decoller() renverrait « RÉPARATION EN COURS ». La C.T.A.T. peut finir son travail.
- **C-55. Aucun départ juste après une Catastrophe** *(petit)* : Après un atterrissage forcé, plus aucun voyage pendant 60 s : les systèmes se remettent du paradoxe.
- **A-15. Protocole Ancrage** *(petit)* : Le TARDIS refuse tout décollage tant que l'ancrage est mis (même par erreur de clic).
- **C-10. Recharge du Rapide qui s'allonge à la chaîne** *(petit)* : La recharge de 5 s passerait à 10 puis 20 s si les voyages Rapides s'enchaînent, et reviendrait à 5 s après un moment posé. On garde le Rapide pour les vrais besoins.
- **A-19. Confirmation des voyages lointains** *(petit)* : Au-delà de X studs, REMAT demande une confirmation.
- **C-91. Rappel, repositionnement et minuterie dans le mode choisi** *(petit)* : Ces trois voyages appellent decoller(false) et partent toujours en Classique. Ils suivraient le protocole choisi par le pilote.
- **C-40. Dossier SANS_CAMOUFLAGE pour les zones à détecteurs** *(petit)* : Un sous-dossier où l'atterrissage invisible est impossible : la cabine y arrive toujours visible.
- **C-50. Voyage vers un SCP toujours en Urgence** *(petit)* : Viser un joueur d'une équipe SCP imposerait une arrivée d'Urgence et interdirait le « Sur lui ». On n'approche pas une anomalie tranquillement.

**Dans Studio :** C-40 : créer le sous-dossier SANS_CAMOUFLAGE dans TARDIS_DESTINATIONS (facultatif).

*Pourquoi ici :* Tout passe par decoller() de TardisServeur, après les règles de V13.2.11. Refus d'abord : pendant une réparation (C-30), après une Catastrophe (C-55), protocole Ancrage (A-15). Puis réglages : recharge du Rapide qui s'allonge (C-10), confirmation des voyages lointains (A-19), rappel, repositionnement et minuterie dans le mode choisi (C-91). Enfin les zones : SANS_CAMOUFLAGE (C-40, comme SANS_EXPRESS) et voyage vers un SCP toujours en Urgence (C-50).

### V13.7.2 — Arrivée et nouveaux protocoles

**Objectif :** Des arrivées qui trouvent le sol et le plafond, une orientation au choix, et deux nouveaux protocoles.

- **C-49. Joueur en hauteur : sol cherché plus bas** *(petit)* : cibleJoueur cherche le sol sur 60 studs seulement : un joueur sur une passerelle haute donne « PAS DE SOL ». La recherche irait jusqu'à 500 studs.
- **C-7. Hauteur du Sauvetage adaptée au plafond** *(petit)* : La cabine apparaît toujours 22 studs plus haut (Modes.Sauvetage.Hauteur) et traverse le toit dans un bâtiment. Un rayon vers le haut réduirait cette hauteur sous un plafond.
- **A-5. Orientation à l'arrivée** *(petit)* : Choisir l'orientation de la porte à l'arrivée (vers la destination, nord, comme au départ).
- **C-96. Repositionnement glissé pour les petits ajustements** *(petit)* : Le menu Rotation fait démat, 10 s de vortex et remat même pour 2 studs. Sous 15 studs, la cabine glisserait en 2 s sans voyage.
- **C-20. Sauvetage et Silencieux combinés** *(moyen)* : Les protocoles s'excluent aujourd'hui (TardisCommandes). Un Sauvetage discret garderait la descente en tournant et les portes ouvertes, sans son ni lumière dehors.
- **C-22. Nouveau mode Évacuation pour les brèches** *(moyen)* : Avant la démat, tous les joueurs à moins de 10 studs de la porte seraient emmenés à bord, puis départ d'Urgence. Utile quand un SCP s'échappe.

**Dans Studio :** Rien.

*Pourquoi ici :* atterrir() et les modes (Config.Modes, TardisCommandes). Sol cherché plus bas pour un joueur en hauteur (C-49), hauteur du Sauvetage selon le plafond (C-7), orientation de la porte à l'arrivée (A-5), repositionnement glissé sous 15 studs (C-96, menu Rotation). Puis les protocoles : Sauvetage et Silencieux combinés (C-20), mode Évacuation (C-22), qui emmène des joueurs à bord : le plus délicat, en dernier.

### V13.7.3 — Vol libre plus vivant

**Objectif :** Un vol libre avec rayon tracteur utile, limites visibles, surchauffe, météo, aide à l'atterrissage et vol guidé.

- **C-85. Rayon tracteur : déposer un joueur à bord** *(petit)* : Un joueur tracté amené sous la cabine posée serait mis à bord (emmenerALInterieur), pour un sauvetage ou une capture RP.
- **A-25. Limites de la carte visibles** *(petit)* : Un mur lumineux discret aux limites où le vol s'arrête.
- **C-71. Surchauffe du moteur en Turbo** *(moyen)* : Une jauge monte en TURBO et en Urgence ; pleine, le vol passe en LENT pendant 10 s, puis elle redescend. Le Turbo devient un choix, pas un réflexe.
- **A-32. Vent et météo** *(moyen)* : Le vol est secoué par la météo du jeu (pluie, orage).
- **A-35. Atterrissage de précision assisté** *(moyen)* : Un viseur au sol qui aide à se poser exactement sur un point.
- **C-81. Vol guidé vers une destination** *(moyen)* : Choisir une destination en vol libre : le TARDIS s'y dirige seul et s'arrête au-dessus, le pilote peut reprendre la main. Différent du pilote de croisière (cap fixe).

**Dans Studio :** Rien.

*Pourquoi ici :* VolLibre.lua (serveur) et TardisVolLibre (client). Rayon tracteur qui dépose un joueur à bord (C-85, emmenerALInterieur), limites de la carte visibles (A-25). Puis la conduite : surchauffe en Turbo (C-71), vent et météo (A-32), atterrissage de précision assisté (A-35). C-81 (vol guidé vers une destination) en dernier : le TARDIS vole seul, le serveur doit garder le contrôle des positions.

### V13.7.4 — Rencontre dans le vortex

**Objectif :** Deux TARDIS qui s'arriment dans le vortex, portes l'une en face de l'autre.

- **C-38. Rencontre de deux TARDIS dans le vortex** *(gros)* : Deux TARDIS dans le vortex en même temps pourraient s'arrimer : leurs portes donnent l'une sur l'autre et les équipages passent d'un bord à l'autre.

**Dans Studio :** Prévoir dans chaque intérieur un point d'arrimage devant la porte.

*Pourquoi ici :* Le plus gros changement du voyage. Il demande les trois TARDIS de la V11 et s'appuie sur le voyage de groupe synchronisé (V11.4). Seul dans son lot, en dernier.

## V13.8 — Systèmes et pannes (5 lots, 21 propositions)

Faire réagir les systèmes du TARDIS (intégrité, zone sûre, boucliers, Siège) de façon plus logique, et donner de nouvelles pannes à réparer à la C.T.A.T.

### V13.8.1 — Avarie, chocs et zone sûre

**Objectif :** Des conséquences logiques de l'avarie, des chocs et du manque de courant.

- **C-130. Zone sûre coupée hors tension** *(petit)* : Le ForceField de la zone sûre reste actif sans courant. Le retirer quand l'alimentation est coupée.
- **C-218. Zone sûre coupée pendant l'alerte générale** *(petit)* : Quand l'alerte générale (attribut Alerte) ou le mode Siège est actif, la zone sûre (Config.ZoneSure) ne protège plus personne. L'équipage peut alors se défendre contre un intrus armé à bord.
- **C-152. Avarie qui fait tomber le camouflage** *(petit)* : À 0 % d'intégrité, le camouflage se coupe et la cabine redevient visible, en plus des portes ouvertes et du courant coupé.
- **C-165. Avarie qui passe en maintenance automatique** *(petit)* : À 0 % d'intégrité, une maintenance « Avarie » est posée, puis levée à la réparation : le blocage est clair partout.
- **C-148. TARDIS rapetissé plus fragile aux tirs** *(petit)* : Quand il est rapetissé (attribut Retreci), les tirs et les chocs font deux fois plus de dégâts. Rapetisser pour le cacher devient un risque.
- **C-115. Gros choc qui déclenche une panne** *(petit)* : Une explosion proche, une Catastrophe ou une régénération à bord peut lancer une panne en plus des PV perdus.

**Dans Studio :** Rien.

*Pourquoi ici :* Règles de TardisSystemes. Zone sûre coupée hors tension (C-130) et pendant l'alerte ou le Siège (C-218). Avarie à 0 % : camouflage qui tombe (C-152), maintenance « Avarie » automatique (C-165). TARDIS rapetissé plus fragile (C-148), gros choc qui déclenche une panne (C-115) : il s'appuie sur la liste des pannes, en dernier.

### V13.8.2 — Défense automatique

**Objectif :** Des options qui font réagir le TARDIS seul : fuite, Siège, alerte, bouclier lié à l'énergie.

- **C-151. Fuite face aux anomalies réglable** *(petit)* : La démat automatique à 10 studs d'une anomalie peut être coupée par les pilotes, par exemple pour un RP de confinement.
- **C-136. Siège rétabli à l'arrivée (option)** *(petit)* : Le Siège prend fin au décollage (TardisServeur, setEtat). Option pour le remettre tout seul à l'atterrissage : bouclier, verrou et alerte.
- **C-135. Alerte automatique en cas d'intrusion** *(petit)* : Option : une INTRUSION notée par le registre passe la salle en alerte générale, levée quand l'intrus est sorti.
- **C-134. Siège automatique sous le feu** *(petit)* : Option : si la cabine reçoit beaucoup de tirs en 10 s sans bouclier, le mode Siège se lève seul et les pilotes sont prévenus.
- **A-130. Bouclier qui faiblit avec l'énergie** *(petit)* : Le bouclier consomme de l'énergie et tombe si elle est basse.

**Dans Studio :** Rien.

*Pourquoi ici :* Options réglées par les pilotes : fuite face aux anomalies réglable (C-151), Siège rétabli à l'arrivée (C-136), alerte en cas d'intrusion (C-135), Siège automatique sous le feu (C-134). A-130 (bouclier qui consomme de l'énergie) recoupe l'énergie partagée de la V12.3 : à brancher dessus, en dernier.

### V13.8.3 — Nouvelles pannes

**Objectif :** Trois nouvelles pannes et des pannes rares en vol libre, chacune avec son alarme.

- **A-123. Alarme par type de panne** *(petit)* : Un son et une couleur propres à chaque panne.
- **C-172. Nouvelle panne : stabilisateur déréglé** *(petit)* : La cabine vibre pendant les voyages même stabilisateur activé, après une Catastrophe ou un gros choc.
- **C-170. Nouvelle panne : générateur de bouclier** *(moyen)* : Les boucliers et le Siège sont refusés jusqu'à une réparation à la clé à molette.
- **C-171. Nouvelle panne : gravité déréglée** *(moyen)* : La gravité folle (aujourd'hui seulement en Urgence) se déclenche posé, jusqu'à la réparation.
- **C-167. Pannes possibles en plein vol libre** *(moyen)* : Rares pannes en vol : moteur qui tousse, vitesse réduite et à-coups pendant 20 s. Aujourd'hui les pannes n'arrivent que posé.

**Dans Studio :** Rien.

*Pourquoi ici :* Règle avant effet : alarme par type de panne (A-123) d'abord, pour que chaque nouvelle panne ait son son et sa couleur. Puis stabilisateur déréglé (C-172), générateur de bouclier (C-170, réparé à la clé à molette), gravité déréglée posé (C-171). Pannes en plein vol libre (C-167) touchent aussi VolLibre : en dernier.

### V13.8.4 — Passagers et sièges

**Objectif :** Rendre les sièges d'équipage utiles : vue extérieure assis, chute debout en Catastrophe.

- **C-182. Vue extérieure depuis un siège d'équipage** *(petit)* : S'asseoir sur un SiegeEquipage donne la vue au-dessus de la Lampe (TardisCamera), sans aucune commande.
- **C-180. Passagers debout projetés en Catastrophe** *(moyen)* : En Catastrophe, les passagers qui ne sont pas assis sur un SiegeEquipage tombent 2 s. Les sièges deviennent utiles.

**Dans Studio :** Poser dans l'intérieur des sièges (Seat) nommés « SiegeEquipage » : ils n'existent pas encore dans le code ni dans la V7.

*Pourquoi ici :* Vue extérieure depuis un siège (C-182, TardisCamera) d'abord, puis passagers debout projetés en Catastrophe (C-180), qui touche le serveur et le client.

### V13.8.5 — Jukebox et port du TARDIS

**Objectif :** Un jukebox entendu dehors et choisi selon la situation, et un TARDIS rangé dans le sac.

- **C-192. Jukebox entendu dehors portes ouvertes** *(petit)* : Portes ouvertes, la musique s'entend faiblement devant la cabine.
- **C-191. Playlist automatique selon la situation** *(moyen)* : Option : musique calme posé, tendue en alerte, rapide en vol libre, choisie parmi les catégories de Config.Jukebox.
- **C-194. Ranger le TARDIS porté dans le sac** *(petit)* : Un 4e mode de port : le TARDIS rapetissé devient invisible, rangé dans le sac de son porteur.

**Dans Studio :** Rien.

*Pourquoi ici :* Jukebox entendu devant la cabine portes ouvertes (C-192), playlist selon la situation (C-191, catégories de Config.Jukebox). C-194 ajoute un 4e mode de port (TardisPorter) : à part, en dernier.

## V13.9 — Équipage, accès et jeu de rôle (5 lots, 18 propositions)

Mieux régler qui peut faire quoi (rangs de groupe, techniciens, équipes amies) et ajouter du jeu de rôle autour de l'équipage, des visiteurs et des SCP.

### V13.9.1 — Accès et rôles

**Objectif :** Protéger les pilotes Adonis et WL, annoncer les promotions, donner l'accès par rang de groupe.

- **C-205. Pilotes Adonis et WL protégés du bannissement** *(petit)* : En partie là : seuls les pilotes de Config.Pilotes sont protégés (definirRole, action Bannir). Les pilotes donnés par Adonis ou la WL (TardisAccesPilote) le seraient aussi, pour qu'un pilote temporaire ne puisse pas les écarter.
- **C-214. Nouvelle promotion annoncée aux autres pilotes** *(petit)* : Quand un joueur est promu pilote ou banni, tous les pilotes en ligne reçoivent une ligne courte (direAuxPilotes), pas seulement l'auteur et la cible. L'équipe sait qui a les commandes.
- **C-276. Techniciens autorisés à ouvrir les portes verrouillées** *(petit)* : Un technicien peut ouvrir les portes verrouillées pour entrer réparer, sans toucher aux commandes de vol. Aujourd'hui il reste dehors si aucun pilote n'est là.
- **C-207. Accès par le rang dans un groupe Roblox** *(petit)* : Un bloc Config.Acces.Groupe (identifiant du groupe, rang pilote, rang technicien) lu par TardisSupervision.verifierAcces, à côté d'Adonis et de la WL. Pratique si l'équipe de ZONE-TSADE est gérée par un groupe Roblox.
- **A-92. Liste d'équipage du jour** *(petit)* : Le pilote voit qui a voyagé avec lui pendant la session.

**Dans Studio :** C-207 : donner l'identifiant du groupe Roblox et les rangs pilote et technicien.

*Pourquoi ici :* TardisSupervision.verifierAcces et definirRole. Protection des pilotes Adonis et WL contre le bannissement (C-205), promotion annoncée aux pilotes (C-214), techniciens qui ouvrent les portes verrouillées (C-276). Puis accès par rang de groupe (C-207) et liste d'équipage du jour (A-92). Depuis la V11, chaque règle vaut pour « pilote de TARDIS_x ».

### V13.9.2 — Intrusions et visites

**Objectif :** Des alertes d'intrusion adaptées à l'équipe, un accueil des visiteurs et un mode visite.

- **C-216. Liste d'équipes amies de ZONE-TSADE** *(petit)* : Une liste Config.EquipesAmies (par exemple certains gardes de la Fondation) dont les joueurs entrent sans alerte d'intrusion. Les autres équipes restent signalées comme aujourd'hui.
- **C-217. Alerte d'intrusion graduée selon l'équipe** *(petit)* : Le message aux pilotes change selon l'équipe de l'intrus : SCP en rouge avec le Cloître, Classe D en orange, autres équipes en simple avis. Les pilotes savent tout de suite s'il faut réagir.
- **A-148. Accueil des visiteurs** *(petit)* : Message d'accueil la première fois qu'un joueur entre à bord.
- **C-229. Mode visite : portes ouvertes au public** *(moyen)* : Un interrupteur dans la tablette des pilotes : pendant une visite, plus d'alerte d'intrusion ni de sentinelle, et une annonce aux joueurs proches que le TARDIS se visite. Pratique pour les événements RP.

**Dans Studio :** C-216 : donner les noms des équipes amies de ZONE-TSADE.

*Pourquoi ici :* Le registre d'intrusion de TardisExtras. Liste d'équipes amies (C-216) avant l'alerte graduée par équipe (C-217), message d'accueil (A-148), mode visite (C-229, interrupteur de la tablette).

### V13.9.3 — Carnet, bornes et carte du voyageur

**Objectif :** Des statistiques pour les passagers, des notes placées sur la carte et des bornes pour appeler le TARDIS.

- **C-299. Carte du voyageur pour les passagers** *(petit)* : Les passagers ont aussi leurs statistiques : nombre de voyages à bord et temps passé dans le TARDIS. Aujourd'hui seuls les pilotes sont comptés.
- **C-254. Notes du carnet placées sur la mini-carte** *(moyen)* : Une note peut garder la position exacte du TARDIS ; un petit repère apparaît alors sur la mini-carte de la tablette. On retrouve les lieux notés sans les chercher.
- **C-257. Bornes d'appel du TARDIS sur la carte** *(moyen)* : Des Parts « BorneTardis » posées dans la carte de ZONE-TSADE, avec un ProximityPrompt qui allume la balise. On peut appeler à l'aide sans le chat, et cela crée des lieux RP.

**Dans Studio :** C-257 : poser des Parts « BorneTardis » avec un ProximityPrompt dans la carte de ZONE-TSADE.

*Pourquoi ici :* Statistiques des passagers (C-299), notes du carnet avec position sur la mini-carte (C-254), bornes d'appel qui allument la balise (C-257, la plus longue).

### V13.9.4 — Équipage : missions et régénération

**Objectif :** Des missions d'entretien pour la C.T.A.T. et des ajouts de RP à la régénération.

- **A-111. Nouvelle voix à la régénération** *(petit)* : Changer le son des pas ou un effet de voix après (option RP).
- **A-97. Missions de la C.T.A.T.** *(moyen)* : Des tâches d'entretien régulières à faire (nettoyage, vérification des systèmes).
- **A-109. Énergie de régénération partagée** *(moyen)* : Un membre peut donner de l'énergie à un autre (soin RP).

**Dans Studio :** Rien.

*Pourquoi ici :* Nouvelle voix après la régénération (A-111), missions de la C.T.A.T. (A-97), énergie de régénération partagée (A-109, en lien avec les styles de la V11.1).

### V13.9.5 — SCP et sécurité de la Fondation

**Objectif :** Les SCP qui perturbent ou forcent le TARDIS, et la sécurité qui peut le mettre sous scellés.

- **C-285. SCP à bord : systèmes perturbés** *(moyen)* : Tant qu'un joueur SCP est dans le TARDIS, les lumières vacillent et une petite panne peut se déclencher. On reprend l'idée des anomalies déjà gérées dehors (estEntiteHostile), mais à l'intérieur.
- **C-284. Les SCP peuvent forcer les portes** *(moyen)* : Un joueur d'une équipe SCP peut forcer les portes verrouillées en maintenant E longtemps, avec une alarme à bord. Le verrou n'est plus une protection absolue contre les anomalies.
- **C-283. Scellés posés par la sécurité de la Fondation** *(gros)* : Des gardes (équipes de la config) peuvent poser des scellés sur un TARDIS posé sans pilote, en maintenant E : il ne peut plus décoller tant qu'un pilote ne les brise pas (10 s de maintien). Un vrai jeu entre la Fondation et l'équipage.

**Dans Studio :** C-283 : choisir dans la config les équipes de gardes autorisées.

*Pourquoi ici :* Les plus gros changements de RP, en dernier, après les règles d'intrusion (V13.9.2) : SCP à bord qui perturbent les systèmes (C-285), SCP qui forcent les portes verrouillées (C-284), scellés posés par la sécurité (C-283).

## V13.10 — Graphismes et sons (6 lots, 35 propositions)

Ajouter les effets visuels et sonores laissés pour plus tard : cabine et météo, console et rotor, salle en alerte, écran et caméra. Ils passent en dernier, quand les règles qu'ils montrent existent.

### V13.10.1 — Cabine : lumière, eau et météo

**Objectif :** Une cabine qui réagit à la nuit, à l'eau, à la pluie et au brouillard.

- **G-2. Enseigne POLICE BOX rétroéclairée la nuit** *(petit)* : Hors voyage, la luminosité du SurfaceGui de l'enseigne suit Config.facteurHeure : elle brille doucement la nuit et reste normale le jour. Aujourd'hui Signalisation ne touche à l'enseigne que pendant la démat et la remat.
- **G-33. Ombre douce sous la cabine, posée et en vol** *(petit)* : Un disque sombre et flou sous la cabine, toujours au sol, qui grandit et pâlit avec la hauteur. Posée, elle colle mieux au décor ; en vol libre, les témoins voient où elle est.
- **G-28. Cabine qui ruisselle en sortant de l'eau** *(petit)* : Quand la cabine quitte l'eau (décollage, vol libre), des gouttes tombent de ses bords pendant quelques secondes. Ça vaut aussi après une chute dans l'eau.
- **G-30. Cabine mouillée sous la pluie** *(moyen)* : Si le jeu signale la pluie (attribut de météo dans workspace, réglable dans la config), la cabine devient plus réfléchissante et des gouttes rebondissent sur le toit. Rien ne change quand il ne pleut pas.
- **G-8. Faisceaux de la lampe dans le brouillard** *(moyen)* : Quand le brouillard ou l'Atmosphere est dense, la lampe projette quatre rayons visibles (Beam) qui tournent lentement pendant les voyages. Ils restent coupés en « aucun flash » et en Silencieux.
- **G-17. Ondes au sol qui épousent les pentes** *(moyen)* : Les ondes de chaque souffle sont des anneaux plats : sur une pente ou un escalier, elles flottent ou s'enfoncent. Plusieurs raycasts autour de la cabine les inclinent selon la normale du sol (TardisEffets, fonction onde).

**Dans Studio :** Rien.

*Pourquoi ici :* EffetsExterieurs et TardisEffets. Enseigne rétroéclairée la nuit (G-2, Config.facteurHeure), ombre douce sous la cabine (G-33), cabine qui ruisselle (G-28). Puis cabine mouillée sous la pluie (G-30) et faisceaux dans le brouillard (G-8), qui lisent la météo du jeu. G-17 (ondes qui épousent les pentes, plusieurs raycasts) en dernier.

### V13.10.2 — Cabine : événements visibles dehors

**Objectif :** Voir de dehors le bouclier, l'incendie, le Sauvetage, le vent, la Catastrophe et les balises.

- **G-90. Anneau lumineux là où la bulle touche le sol** *(petit)* : Quand un bouclier est levé, un anneau très fin brille au sol à l'endroit où la bulle le coupe. On voit la limite du bouclier même quand il est invisible.
- **G-62. Fumée par le toit pendant un incendie à bord** *(petit)* : Quand la console brûle (attribut Incendie), une fumée grise sort du haut de la cabine. Les gens dehors voient qu'il y a un problème à bord.
- **G-57. Sauvetage : spirale de poussière pendant la descente** *(petit)* : Pendant la descente en tournant du Sauvetage, une spirale de particules claires suit la cabine jusqu'au sol, sans éclairer le sol. Ça complète le phare des fenêtres.
- **G-40. Vent visible autour des joueurs repoussés** *(petit)* : Les turbulences du vol libre poussent les joueurs proches sans rien montrer. Quelques traits de vent et un peu de poussière autour d'eux rendent la poussée lisible.
- **G-52. Ciel qui s'assombrit au-dessus d'une Catastrophe** *(moyen)* : Pendant la remat forcée en Catastrophe, les joueurs proches voient le ciel s'assombrir et rougir (Atmosphere et ColorCorrection locaux), puis revenir. C'est un effet sur le ciel, pas sur la cabine, en plus du lot V6.9.9.
- **G-91. Repère 3D de la balise de détresse** *(moyen)* : Une colonne de lumière discrète, visible seulement des pilotes, monte à l'endroit d'une balise /tardis active. Elle aide à s'y rendre en vol libre. Aujourd'hui la balise n'existe que dans la tablette.
- **A-37. Feuilles et poussière soulevées** *(moyen)* : Au départ, les petits objets non ancrés autour sont légèrement soulevés.

**Dans Studio :** Rien.

*Pourquoi ici :* Anneau du bouclier au sol (G-90), fumée par le toit en incendie (G-62), spirale du Sauvetage (G-57), vent du vol libre (G-40). Puis ciel de Catastrophe (G-52), repère 3D de la balise pour les pilotes (G-91), feuilles et objets soulevés au départ (A-37, avec un plafond d'objets).

### V13.10.3 — Console et rotor

**Objectif :** Une console et un rotor plus vivants pendant le voyage.

- **G-102. Sélecteur qui tourne d'un cran** *(petit)* : À chaque changement de destination (promptSelecteur), le sélecteur fait un quart de tour avec un petit rebond, côté client : on voit la commande répondre.
- **G-115. Barre de progression du voyage sur l'écran** *(petit)* : Une fine barre sous le texte de l'écran se remplit pendant la démat et la remat, calculée depuis DebutEtat et Config.Timing : tout le monde la voit avancer au même rythme.
- **G-123. Cœur lumineux dans la colonne du rotor** *(petit)* : Une lumière au centre du rotor gonfle à chaque souffle du voyage et éclaire la console de la couleur du mode, en plus des néons qui changent déjà de couleur.
- **G-124. Étincelles qui montent dans le rotor** *(petit)* : Des particules lumineuses montent dans la colonne de verre pendant le vol, plus nombreuses dans le vortex, et s'arrêtent une fois posé.
- **G-136. Ombres du rotor qui tournent au plafond** *(moyen)* : Une lumière placée sous le rotor projette ses formes au plafond ; pendant le vol, ces ombres tournent lentement.
- **G-122. Mini cabine holographique au-dessus de la carte** *(moyen)* : Une petite copie translucide de la cabine tourne au-dessus de l'hologramme ; elle se fissure selon PointsDeVie et s'entoure d'une bulle quand un bouclier est levé.

**Dans Studio :** G-136 : une lumière sous le rotor (le script peut la créer).

*Pourquoi ici :* Sélecteur qui tourne d'un cran (G-102), barre de progression sur l'écran (G-115), cœur lumineux du rotor (G-123), étincelles (G-124), ombres au plafond (G-136). G-122 (mini cabine holographique) en dernier.

### V13.10.4 — Salle : alertes et pannes

**Objectif :** Une salle qui montre la démat, l'alerte, le camouflage, le hors tension et l'auto-destruction.

- **A-50. Effet à bord pendant la démat** *(petit)* : La salle tremble et la lumière baisse un instant au moment où la cabine s'efface.
- **G-155. Levier d'alimentation qui clignote au redémarrage requis** *(petit)* : Quand RedemarrageRequis est vrai, le levier d'alimentation clignote doucement en ambre pour montrer où maintenir E pendant 10 s.
- **G-174. Chenillard rouge sur le pupitre en alerte** *(petit)* : En alerte, une bande de lumières rouges fait le tour du pupitre de la console, en plus du rouge fixe des LedsAlerte.
- **G-172. Vue bleutée quand le TARDIS est camouflé** *(petit)* : Quand le TARDIS est camouflé, la vue de la rue depuis la salle est légèrement bleutée : l'équipage se souvient qu'on est invisible.
- **G-173. Lampe torche automatique hors tension** *(petit)* : Hors tension, chaque joueur à bord reçoit une petite lumière locale devant lui, pour se déplacer dans la salle sombre (option).
- **G-176. Compte à rebours géant au-dessus de la console** *(petit)* : Pendant l'auto-destruction, de grands chiffres rouges remplacent l'hologramme et comptent les 20 s (AutoDestructionDebut, AutoDestructionDuree).
- **G-164. Porte du casier qui s'ouvre** *(petit)* : Pendant le maintien de E sur un Casier, sa porte (pièce « Porte » du casier) pivote et une petite lumière s'allume dedans.

**Dans Studio :** G-164 : une pièce « Porte » dans chaque Casier.

*Pourquoi ici :* Effet à bord pendant la démat (A-50), levier qui clignote au redémarrage requis (G-155), chenillard rouge en alerte (G-174), vue bleutée camouflé (G-172), lampe torche hors tension (G-173), compte à rebours géant (G-176), porte du casier qui s'ouvre (G-164).

### V13.10.5 — Écran et caméra

**Objectif :** Des effets d'écran et des vues de caméra pour les moments forts.

- **G-185. À-coup de caméra au saut temporel** *(petit)* : Le saut temporel (touche B) donne aux occupants un à-coup vers l'arrière et un bref flou.
- **G-272. Givre aux coins de l'écran après une urgence** *(petit)* : Comme le givre sur la cabine, les passagers voient un peu de givre aux coins de l'écran après un atterrissage d'urgence, qui fond vite.
- **G-286. Mise au point au centre de l'image** *(petit)* : Un DepthOfFieldEffect qui fait le point sur ce qu'on vise au centre ; le reste devient flou.
- **G-294. Plan de côté pendant l'atterrissage** *(petit)* : Avec G ou N, la caméra se place de côté pour montrer la cabine qui se pose, puis revient au pilote.
- **G-269. Fumée et chaleur à l'écran pendant un incendie** *(moyen)* : Près de la console en feu, un peu de fumée devant la caméra, une teinte orange et un léger flou. Plus on est près, plus c'est fort.
- **G-293. Vue depuis le toit en vol libre** *(moyen)* : Une touche pour piloter en vue « cockpit » depuis la Lampe, puis revenir à la vue de derrière.

**Dans Studio :** Rien.

*Pourquoi ici :* Sur le module commun des effets d'écran (T-102) et la caméra unique (T-161) de la V13.3. À-coup du saut temporel (G-185), givre après une urgence (G-272), mise au point (G-286, option), plan de côté à l'atterrissage (G-294). Fumée d'incendie à l'écran (G-269) et vue cockpit depuis le toit (G-293) en dernier.

### V13.10.6 — Sons de la salle et effet de poche

**Objectif :** Des pas métalliques, de l'écho dans la salle et un effet propre à la téléportation de poche.

- **A-67. Bruit de pas sur le sol métallique** *(petit)* : Un son de pas différent dans la salle de la console.
- **A-135. Écho dans la salle** *(petit)* : Un effet de réverbération sur les sons à bord.
- **A-39. Effet pour la téléportation de poche** *(moyen)* : Une animation propre quand le TARDIS porté se dématérialise dans les mains.

**Dans Studio :** A-67 : choisir un son de pas métallique (identifiant à fournir).

*Pourquoi ici :* Sons à bord, rangés dans les volumes par catégorie de la V9.1 : bruit de pas (A-67), écho dans la salle (A-135, ReverbSoundEffect). A-39 (effet de la téléportation de poche, TardisPorter) en dernier.

## Remarques

- Couvertes en entier par un lot déjà prévu (gardées quand même, à cocher ou à écarter) : T-64 (clés de préférences permises : le schéma des données par action de la V8.2, n° 157) ; T-82 (signaux internes au lieu d'attributs répliqués : moins d'attributs répliqués de la V9.4, n° 180, et un seul point d'entrée par côté de la V10) ; T-154 (préchargement des sons une seule fois : liste des sons partagée et préchargement intelligent de la V9.1, n° 173 et 182) ; T-166 (modules uniques : un seul LocalScript qui charge les modules, V10) ; T-300 (decouper.py vers un autre dossier : outil pensé pour la refonte de la V10, qui l'aura déjà faite).
- Couvertes en partie par la V8, la V9 ou la V10 (à faire seulement pour ce qui reste) : V8 → T-35 et T-65 (pont et garde-barrière, n° 156, 169, 172), T-68 et T-170 (schéma et liste des actions, n° 156, 157), T-86, T-90 et T-214 (banc d'essai et sauvegarde protégée, n° 185, 168) ; V9 → T-57, T-121, T-122, T-159 (boucles regroupées, n° 177), T-111, T-117, T-185, T-194 (effets coupés loin, n° 178), T-147, T-148, T-149 (effets allégés, n° 47), T-141 (volumes par catégorie, n° 133), T-71 et T-255 (configuration validée, n° 183), T-216 et T-218 (code mort, partage du code, n° 176), T-73, T-157, T-272 (journal à niveaux, n° 175), T-260 (n° 180) ; V10 → T-42, T-43, T-45, T-55, T-62, T-85, T-152, T-180 (un point d'entrée, config découpée), T-235, T-278, T-283 (guide d'installation, n° 196).
- Recoupements avec la V11 et la V12 : M-284 recoupe la V11.7 (réglages personnels hors de la tablette) ; A-130 recoupe l'énergie partagée de la V12.3 ; C-38 s'appuie sur le voyage de groupe de la V11.4 ; T-172 et M-99 changent de sens avec « un pilote = un TARDIS » de la V11 ; A-70 complète la navigation à la manette de la V12.4 ; M-198 a peut-être déjà été fait pour la console de la V12 ; M-197 (repères vers la future console) n'a plus de sens après la V12 : il est conseillé de l'écarter.
- Les V13.4 (menu T) et V13.5 (tablette Y) ne servent plus qu'à TARDIS_2 et TARDIS_3 après la V12, puisque TARDIS_1 passe par sa console. La V13.6 (copilote, technicien, vol libre, boutons tactiles, bandeaux, régénération) vaut pour tous les TARDIS, sauf si la V12 tranche autrement ses questions ouvertes (vol libre, mobile, copilote, tablette technicien).
- Les noms de fichiers cités dans « pourquoi » sont ceux d'aujourd'hui (TardisServeur, TardisEffets, TardisTablette…). La V10 les rangera par domaine (Voyage, VolLibre, Systemes, Equipage, Bord, Supervision, Sauvegarde, Interface, Effets) : il faudra suivre le nouveau chemin. Certaines descriptions gardent l'ancienne numérotation : « V9 » pour la refonte des dossiers (T-300) veut dire V10, « les trois TARDIS de la V10 » (M-99) veut dire V11, « la console V11 » (M-198) veut dire V12.
- Ordre général : outils et tests d'abord (V13.1), puis le code serveur et client sans rien changer en jeu (V13.2, V13.3), puis les interfaces (V13.4 à V13.6), puis les nouvelles règles (V13.7 à V13.9), et les effets en dernier (V13.10). Dans chaque sous-version, les lots courts et sûrs passent avant les gros chantiers.
- Les sièges « SiegeEquipage » (C-180, C-182) n'existent ni dans le code ni dans la V7 : il faudra les poser dans Studio. T-89 (TARDIS unique entre les serveurs) et C-283 (scellés posés par la sécurité) changent les règles du jeu : à confirmer avec le propriétaire avant de les commencer.
