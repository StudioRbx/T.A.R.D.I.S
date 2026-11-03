# Analyse des 110 propositions gardées (03/11/2026)

> Lecture du code proposition par proposition, faite avant de construire le plan. Sert de point de départ quand on attaque chaque lot.
> État au moment de l'analyse : V6.9.6. « Preuve » = l'endroit du code qui montre ce qui existe déjà.

## V6.9.7 — Corrections : TARDIS bloqué ou perdu

### 141. Silence total en Silencieux à bord aussi

*Option : le Silencieux coupe aussi les sons à l'intérieur.*

- **Déjà fait :** partiel — Les sons de voyage sont déjà muets en Silencieux, dedans comme dehors : src/ServerScriptService/TardisServeur/init.server.lua:119 (jouerVoyage s'arrête si le mode est Discret) ; Signalisation.lua:50 et :61 (compte à rebours sans bip) ; TardisExtras.server.lua:1499 (pas d'annonce). Ce qui reste audible à bord : le bourdonnement Moteur_Vol (Ambiance.lua:270-274), la boucle d'ambiance du thème (Signalisation.lua:244) et le jukebox (Ambiance.lua:293). Bug trouvé : téléportation de poche (DematPorte) en Silencieux. Config.Son renvoie nil (Sons = {}, TardisConfig.lua:109), puis jouerSurPersonnage(porteur, nil) plante sur string.gsub(nil) (init.server.lua:1629), juste après partage.occupe = true et setEtat(Demat) (init.server.lua:1651-1655). Le TARDIS reste bloqué « occupé », en démat. Un client peut aussi envoyer ce mode exprès.
- **Fichiers :** `src/ServerScriptService/TardisServeur/init.server.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Ambiance.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Signalisation.lua`, `src/ReplicatedStorage/TardisConfig.lua`
- **Dépend de :** —
- **Dans Studio :** —
- **Feuille de route :** aucun conflit
- **Effort :** petit · **Risque :** faible
- **Approche :** Corriger d'abord le plantage : dans jouerSurPersonnage, sortir tout de suite si nom est nil (if not nom then return end). Ajouter ensuite l'option Config.Modes.Silencieux.SilenceABord (désactivée par défaut). Quand elle est active, en mode Silencieux et pendant la démat, le vol et la remat, Ambiance.lua ramène les moteurs et le jukebox à 0, et Signalisation.lua coupe la boucle d'ambiance, en fondu. Le son reviendra à l'atterrissage. L'alarme reste audible (sécurité).

### 9. Voyage vers un joueur hors ligne refusé proprement

*Message clair si le joueur visé a quitté pendant le vol, avec repli sur le lieu précédent.*

- **Déjà fait :** partiel — Un message existe, mais il n'y a pas de repli. resoudreDestination renvoie « joueur introuvable » (init.server.lua:1587-1590). Le gestionnaire Remat répond alors « Impossible : joueur introuvable » et le TARDIS reste dans le vortex (:1874-1877). Même chose pour NavAtterrir (:2034) et pour le Rappel, qui laisse le TARDIS en vol si le joueur n'a plus de personnage (TardisExtras.server.lua:1368-1369). La remat automatique part avec la destination capturée avant la démat (TardisCommandes.lua:144-153). Les clients effacent le choix au départ du joueur (TardisMenu.client.lua:592 et :850, Navigation.lua:131-133, Copilote.lua:256-258), mais pas autoRemat.donnees. Seul repli actuel : la tempête de vortex après 10 min (TardisSystemes.server.lua:1044-1063).
- **Fichiers :** `src/ServerScriptService/TardisServeur/init.server.lua`, `src/ServerScriptService/TardisExtras.server.lua`, `src/ReplicatedStorage/TardisCommandes.lua`
- **Dépend de :** —
- **Dans Studio :** —
- **Feuille de route :** aucun conflit
- **Effort :** petit · **Risque :** faible
- **Approche :** Côté serveur : garder le nom des joueurs partis (table nomsPartis remplie sur PlayerRemoving). Dans Remat, NavAtterrir et Rappel, si la cible est introuvable ou n'a plus de personnage alors que le TARDIS est en Vol : envoyer « X a quitté le jeu : retour à <précédent> », puis atterrir(precedent.cf, precedent.nom), ou rester dans le vortex avec un message clair s'il n'y a pas de précédent. Option côté client : sur PlayerRemoving, si autoRemat.donnees.joueur correspond au joueur parti, remplacer la destination par precedent = true.

### 24. Retour au sol automatique

*Si le pilote se déconnecte en vol, le TARDIS descend en douceur au lieu de rester figé.*

- **Déjà fait :** partiel — src/ServerScriptService/TardisServeur/init.server.lua:2068-2079 (surveillerPorteur : CharacterRemoving, qui se déclenche aussi quand le joueur quitte, appelle lancerDescente("Douce", true) si VolLibre == joueur.UserId) ; src/ServerScriptService/TardisServeur/VolLibre.lua:213-216 (avec force, il se pose même s'il n'est pas matérialisé) et :156-185 (finirVolLibre libère partage.occupe). Il manque deux cas : 1) déconnecté pendant qu'il est invisible (VolPhase "Invisible"), le TARDIS descend invisible puis réapparaît d'un coup quand finirVolLibre efface VolPhase, sans animation de remat ; 2) un pilote figé ou en perte de connexion, qui ne quitte pas mais n'envoie plus de positions : rien ne le surveille, le TARDIS reste immobile dans les airs et occupé.
- **Fichiers :** `src/ServerScriptService/TardisServeur/VolLibre.lua`, `src/ServerScriptService/TardisServeur/init.server.lua`, `src/ReplicatedStorage/TardisConfig.lua`
- **Dépend de :** —
- **Dans Studio :** —
- **Feuille de route :** Aucun conflit. Ça rejoint la partie « Vol libre » de la V7 (contrôles côté serveur des positions envoyées par le client) : un client modifié qui arrête d'envoyer peut aujourd'hui bloquer le TARDIS (occupé) indéfiniment.
- **Effort :** petit · **Risque :** faible
- **Approche :** Dans VolLibre.lua, ajoute une surveillance : une boucle légère (ou un task.delay relancé) qui appelle lancerDescente("Douce", true) si os.clock() - volLibre.dernierTemps dépasse Config.VolLibre.DelaiSansNouvelles (par exemple 8 s) pendant un vol qui n'est pas en descente. Dans la branche forcée de lancerDescente, si VolPhase vaut "Invisible" ou "Demat" : lancer d'abord changerPhaseVol("Invisible", "Remat", "Visible", E.Remat), attendre la fin du remat, puis descendre (ou utiliser teleAtterrir au sol sous le TARDIS). Ajouter un cas aux simulations (outils/simulation) : pilote qui part en vol invisible, pilote muet.

### 108. Régénération dans le vide

*Gérer proprement une mort par chute hors de la carte.*

- **Déjà fait :** rien — Aucune gestion de FallenPartsDestroyHeight dans src (aucun résultat avec grep). Le chemin « corps disloqué » (TardisSystemes.server.lua:830-847) reprend la position de la tête ou de la racine. Après une chute hors de la carte, cette position est dans le vide (ou nil si les pièces sont déjà détruites), et le corps neuf est replacé exactement là (:772-785) : il retombe et enchaîne les régénérations. Autre cas : l'état Dead est désactivé pour la C.A.T. (:683). Si le moteur détruit les pièces sans mettre la santé à 0, l'événement Died ne se déclenche jamais et le joueur peut rester sans corps.
- **Fichiers :** `src/ServerScriptService/TardisSystemes.server.lua`
- **Dépend de :** —
- **Dans Studio :** Rien. Le repli prévu est le SpawnLocation de l'équipe dans le TARDIS, déjà créé par le script (Part "Arrivee", TardisSystemes.server.lua:520-570).
- **Feuille de route :** Aucun. C'est un correctif.
- **Effort :** petit · **Risque :** moyen
- **Approche :** Dans surveillerPersonnage, retenir chaque seconde la dernière position sûre (humanoid.FloorMaterial ~= Air et Y > workspace.FallenPartsDestroyHeight + 50). Un Heartbeat léger (ou une vérification toutes les 0,2 s) repère une racine qui passe sous ce seuil : on téléporte le personnage à la dernière position sûre, sinon au spawn de l'équipe dans le TARDIS, puis on lance derouler(true) avec la mention « Chute dans le vide » dans le journal. Dans le chemin enAttente, refuser toute position sous ce seuil. Écouter aussi le retrait de HumanoidRootPart pour forcer un LoadCharacter si le corps a disparu sans mourir. À tester dans Studio : le comportement du moteur à la mort sous la limite ne peut pas être reproduit dans outils/simulation.

### 134. Sons 3D dehors

*Les sons de voyage s'entendent plus fort près de la cabine et faiblissent avec la distance.*

- **Déjà fait :** partiel — Les sons de voyage du dehors sont déjà positionnés (donc en 3D) : src/ServerScriptService/TardisServeur/init.server.lua:79-84 (copie « ext » sur exterieur.PrimaryPart) ; TardisVolLibre.client.lua:464-470 (son du vol libre sur la base de la cabine) ; init.server.lua:1628-1637 (TARDIS porté : son sur le porteur). Mais la portée n'est réglée que pour les sons créés par Config.Sons (init.server.lua:64, RollOffMaxDistance = 140). Les Sound placés à la main (Demat, Remat...) gardent leurs réglages de Studio (par défaut RollOffMode Inverse, Max 10000, donc audibles de très loin).
- **Fichiers :** `src/ReplicatedStorage/TardisConfig.lua`, `src/ServerScriptService/TardisServeur/init.server.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisVolLibre.client.lua`
- **Dépend de :** —
- **Dans Studio :** Rien à construire. Tester en jeu à plusieurs distances de la cabine pour régler Min et Max.
- **Feuille de route :** aucun conflit
- **Effort :** petit · **Risque :** faible
- **Approche :** Ajouter Config.PorteeSons = { Dehors = { Mode = InverseTapered, Min = 12, Max = 200 }, Dedans = { Max = 80 } }. Appliquer ce réglage dans preparerSon selon le parent (extérieur ou rotor), dans le clone du vol libre (TardisVolLibre.client.lua:466) et dans jouerSurPersonnage, pour qu'il vaille aussi pour les Sound posés à la main.

## V6.9.8 — Vérification et outils de suivi

### 27. Vol en formation avec un joueur

*Suivre automatiquement un joueur ou un véhicule à distance fixe.*

- **Déjà fait :** complet — src/StarterPlayer/StarterPlayerScripts/TardisVolLibre.client.lua:58 (TOUCHE_CIBLE = L), :250 (bouton CIBLE du sous-menu PLUS), :1059-1091 (basculerCible : le joueur ou le véhicule occupé le plus proche du centre de l'écran, à moins de 200 studs), :1143-1162 (il le suit à distance fixe, 14 studs derrière et 16 au-dessus, en montant devant un obstacle) ; docs/patch-notes/V4.md:146 et :185.
- **Fichiers :** `src/StarterPlayer/StarterPlayerScripts/TardisVolLibre.client.lua`, `src/ReplicatedStorage/TardisConfig.lua`
- **Dépend de :** —
- **Dans Studio :** —
- **Feuille de route :** Aucun conflit. Le bouton CIBLE vit dans l'interface de vol libre (pas dans le menu T ni dans la tablette Y). Il suivra la décision V11 sur le vol libre à l'écran.
- **Effort :** petit · **Risque :** faible
- **Approche :** Déjà fait depuis la V4 (« Verrouillage de cible », touche L) : rien à construire. Retouche facultative : sortir les valeurs écrites en dur (14 derrière, 16 au-dessus, 200 studs) dans Config.VolLibre.Formation = { Arriere, Hauteur, Cote, Portee }, ajouter une position de côté (vraie formation, à gauche ou à droite) et lâcher la cible quand elle dépasse la portée ou entre dans un intérieur, avec un message. À présenter à l'utilisateur comme existant plutôt que comme une nouveauté.

### 51. Écran de destination sur la console

*La destination choisie s'affiche sur un écran physique de la console.*

- **Déjà fait :** complet — src/ServerScriptService/TardisServeur/init.server.lua:28 (ecran = Config.Trouver(interieur, "Ecran"), chemin Console > Ecran dans TardisConfig.lua:31), init.server.lua:134-145 (SurfaceGui + TextLabel créés sur l'écran), init.server.lua:226-243 majEcran() qui écrit « DESTINATION : <nom> » + état/alerte, rappelée à chaque changement (lignes 285, 295, 811, 956...). En plus : TardisExtrasClient/Ambiance.lua:120 (titre de l'hologramme « DESTINATION : ... ») et Ambiance.lua:129-163 (ligne vivante coordonnées/heure sous le texte de l'écran).
- **Fichiers :** —
- **Dépend de :** —
- **Dans Studio :** Rien : la pièce Console > Ecran est déjà en place (docs/ETAT_DES_LIEUX.md:111).
- **Feuille de route :** Aucun conflit. La V11.1 (écrans de la console en lecture seule, dont « destination ») reprendra et enrichira cet écran ; ne rien refaire avant.
- **Effort :** petit · **Risque :** faible
- **Approche :** Déjà fait : l'écran physique de la console affiche la destination choisie depuis longtemps. Seule limite : en vol libre il montre la destination sélectionnée, pas « VOL LIBRE » ; à traiter éventuellement dans la V11.1 quand les écrans de la console seront refaits. À marquer comme déjà existant dans le tri.

### 69. Recherche dans les destinations

*Un champ de recherche dans le menu rapide aussi (pas seulement la tablette).*

- **Déjà fait :** complet — src/StarterPlayer/StarterPlayerScripts/TardisMenu.client.lua:182-188 (TextBox « Rechercher… » dans la section DESTINATION du menu T) et :543-546 (construireListe filtre lieux, retour et joueurs avec string.find sur recherche.Text). Même mécanisme dans la tablette : TardisTablette/Construction.lua:391 et Navigation.lua:65-67.
- **Fichiers :** —
- **Dépend de :** —
- **Dans Studio :** —
- **Feuille de route :** Le menu T disparaît en V11.4. Si la recherche doit survivre, il faudra la refaire sur la console en V11.2 (TextBox dans un SurfaceGui de l'écran des destinations).
- **Effort :** petit · **Risque :** faible
- **Approche :** Rien à coder : le menu rapide a déjà son champ de recherche, qui filtre les lieux et les joueurs. Il suffit de marquer la proposition comme faite dans docs/PROPOSITIONS_200.md. Le besoin revient en V11.2, quand on fera la liste des destinations sur la console.

### 71. Thème clair de la tablette

*Un thème clair pour la tablette, en plus des thèmes sombres.*

- **Déjà fait :** complet — src/ReplicatedStorage/TardisUI.lua:412-429 : UI.THEMES.Gallifrey est un thème clair (ivoire, gris perle, or miel), proposé avec Cristal et PoliceBox. Il se choisit dans TardisTablette/Volet.lua:224-232 (« THÈME DE L'INTERFACE ») et est sauvegardé par joueur (TardisUI.lua:488). Introduit en V4 (docs/patch-notes/V4.md:192). Défauts restants : des couleurs écrites en dur ne changent pas avec le thème, par exemple TardisMenu.client.lua:197 (fond de liste Color3.fromRGB(4,10,24), qui reste sombre en Gallifrey), environ 29 dans TardisTablette/Construction.lua et 16 dans Outils.lua. Autre incohérence : la palette par défaut UI.C (TardisUI.lua:11-25) n'est pas Cristal, alors que les réglages affichent Cristal comme choisi par défaut (Volet.lua:228).
- **Fichiers :** `src/ReplicatedStorage/TardisUI.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisMenu.client.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisTablette/Construction.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisTablette/Outils.lua`
- **Dépend de :** —
- **Dans Studio :** —
- **Feuille de route :** La tablette Y et le menu T sont retirés en V11.4. Corriger le thème clair n'a d'intérêt que jusqu'à la V11. Ensuite, les écrans de la console auront leurs propres couleurs, et aucune décision ne dit encore si un thème par joueur s'y appliquera.
- **Effort :** petit · **Risque :** faible
- **Approche :** Le thème clair existe déjà : on marque la proposition comme faite. Si on veut le peaufiner, on remplace les quelques couleurs en dur les plus visibles (fond de la liste du menu, fonds de panneaux) par des rôles C.*, qui sont recolorés par UI.appliquerTheme, et on aligne la palette par défaut sur Cristal. Il vaut mieux ne pas y passer plus de temps, puisque la V11 retire ces interfaces.

### 198. Releases GitHub automatiques

*Un modèle de release pour chaque version, prêt à publier.*

- **Déjà fait :** partiel — 21 tags annotés v6.5 → v6.9.6 (git tag). Il y a des releases GitHub publiées pour 8 de ces tags seulement (v6.5 à v6.6.6, vu avec gh api repos/StudioRbx/T.A.R.D.I.S/releases), sans fichier joint. Elles ont toutes la même forme : section du patch note copiée, puis le pied « [Patch note V6](…/docs/patch-notes/V6.md) · [Journal des versions](…/CHANGELOG.md) ». Aucune release pour les 13 tags v6.7 → v6.9.6. Pas de dossier .github, pas de modèle, pas de script ni de workflow qui produise une release.
- **Fichiers :** `.github/release-template.md (nouveau)`, `outils/release.py (nouveau : extrait la section « ## Vx.y.z » de docs/patch-notes/Vn.md et ajoute le pied commun)`, `.github/workflows/release.yml (facultatif : publie au push d'un tag v*)`, `README.md (ligne sur la procédure de publication)`
- **Dépend de :** —
- **Dans Studio :** —
- **Feuille de route :** Aucun. Au contraire, c'est utile avant la V7, pour publier proprement V7 → V11. Si la V9 déplace docs/patch-notes, il faudra changer le chemin dans le script.
- **Effort :** petit · **Risque :** faible
- **Approche :** Écrire outils/release.py qui prend un numéro (ex. 6.9.6), découpe dans docs/patch-notes/V6.md la section qui commence au titre « ## V6.9.6 » ou « ### V6.9.6 » et finit au titre suivant, retire les marqueurs « à installer » et ajoute le pied commun déjà utilisé dans les releases v6.5-v6.6.6. Le script affiche le texte ou le publie avec « gh api repos/StudioRbx/T.A.R.D.I.S/releases -f tag_name=… » (l'API REST, car GraphQL est bloqué dans les sessions). On peut ajouter un workflow GitHub Actions qui le lance quand un tag v* est poussé. On s'en sert ensuite pour rattraper les 13 releases manquantes (v6.7 → v6.9.6).

### 199. Page d'état des tests

*Une page qui liste ce qui a été testé en jeu, version par version.*

- **Déjà fait :** partiel — docs/patch-notes/V6.md contient des tableaux « Testé dans ZONE-TSADE (Play) » pour V6.6 → V6.6.6 (lignes 225, 288, 322, 360, 408, 462, 499) avec des notes « Non testé en jeu » (419, 474, 510), et 12 tableaux « À tester » jamais marqués comme faits pour V6.7 → V6.9.5 (lignes 550, 606, 658, 700, 758, 791, 831, 871, 910, 948, 982, 1018). CHANGELOG.md:7 a une légende 🎮 « installée dans ZONE-TSADE », mise seulement sur V6.6.6. outils/simulation/LISEZMOI.md liste ce que les simulations couvrent. Il n'existe aucune page qui rassemble l'état version par version.
- **Fichiers :** `docs/ETAT_DES_TESTS.md (nouveau)`, `CHANGELOG.md (lien et marqueurs 🎮 à jour)`, `README.md (lien)`, `docs/RAPPELS.md (renvoi vers la page)`
- **Dépend de :** —
- **Dans Studio :** Rien à construire. En revanche, seul l'utilisateur peut tester en jeu : il devra dire quelles lignes « À tester » sont validées, ratées ou pas encore jouées, pour que la page soit tenue à jour.
- **Feuille de route :** Pas de conflit. La feuille de route (docs/FEUILLE_DE_ROUTE.md:49 et :81) compte sur les tableaux « À tester » pour vérifier que V8 et V9 ne changent rien en jeu, donc la page sert ces versions. Il faudra seulement marquer comme dépassées les lignes sur le menu T et la tablette Y quand la V11 les retirera.
- **Effort :** petit · **Risque :** faible
- **Approche :** Créer docs/ETAT_DES_TESTS.md avec un tableau par version : version, installée dans ZONE-TSADE (oui/non), tests en jeu (validé / partiel / à faire, avec un lien vers la section du patch note), points non testés, résultat des simulations (outils/simulation). Le remplir au départ à partir des sections déjà présentes dans V6.md. Pour les versions V6.7 → V6.9.6, l'état sera « à faire » tant que l'utilisateur n'a pas rendu ses résultats. On peut ensuite ajouter un petit script qui liste les sections « À tester » sans résultat, pour que rien ne soit oublié.

### 200. Glossaire du TARDIS

*Un lexique des termes (démat, remat, vortex, modes, équipes).*

- **Déjà fait :** rien — Aucun glossaire ni lexique dans le dépôt (grep « glossaire|lexique » : seulement docs/PROPOSITIONS_200.md:292). Les définitions sont éparpillées : CHANGELOG.md:79 (C.A.T. et C.T.A.T.) ; src/ReplicatedStorage/TardisConfig.lua:54-80 (les clés de code Normal et Express s'affichent « Classique » et « Rapide », ce qui n'est expliqué nulle part dans la doc) ; README.md:81-87 (TARDIS_DESTINATIONS, ACCORDE / REFUSE / SANS_EXPRESS) ; docs/RAPPELS.md §2 (Arrivee, ZDC-…).
- **Fichiers :** `docs/GLOSSAIRE.md (nouveau)`, `README.md (lien)`
- **Dépend de :** —
- **Dans Studio :** —
- **Feuille de route :** Pas de conflit. Il faudra compléter le glossaire en V8 si le nettoyage renomme des clés internes (Normal → Classique, Express → Rapide), en V10 (TARDIS attribué) et en V11 (noms des écrans et boutons de la console). Ne pas y mettre de définition pour des éléments retirés (clé du TARDIS, recette, rôle staff, crise post-régénération), ou les marquer « retiré ».
- **Effort :** petit · **Risque :** faible
- **Approche :** Créer docs/GLOSSAIRE.md : un tableau par thème avec le terme affiché, le nom dans le code ou dans Studio, et une définition d'une ligne. Thèmes : voyage (démat, remat, vortex, vol libre, saut, poche, empreinte temporelle) ; modes (Classique = Normal, Urgence, Rapide = Express, Sauvetage, Silencieux, Siège, Catastrophe/paradoxe, Maintenance) ; équipes et rôles (C.A.T., C.T.A.T., pilote, technicien, copilote) ; pièces Studio (Racine, Lampe, Rotor, Console, Arrivee, ZDC-…) ; destinations (ACCORDE, REFUSE, SANS_EXPRESS). Chaque définition est vérifiée dans TardisConfig.lua, et le guide d'installation (n° 196) renvoie au glossaire.

## V6.9.9 — Effets visuels du voyage

### 36. Distorsion de l'air plus forte en Urgence

*L'air ondule autour de la cabine en urgence, plus que pour les autres modes.*

- **Déjà fait :** partiel — src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/EffetsExterieurs.lua:64-95 (« air qui ondule » : particules TardisAir, en remat seulement, même débit 6*sin(p*pi) pour tous les modes) et :97-104 (distorsion d'écran BlurEffect/ColorCorrection, intensité identique quel que soit le mode) ; seuls les arcs dépendent de l'urgence : TardisEffets.client.lua:748-751
- **Fichiers :** `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/EffetsExterieurs.lua`, `src/ReplicatedStorage/TardisConfig.lua`
- **Dépend de :** —
- **Dans Studio :** —
- **Feuille de route :** aucun conflit
- **Effort :** petit · **Risque :** faible
- **Approche :** Dans la section 5 d'EffetsExterieurs, calculer un facteur selon Config.modeSaccade(modeAnime) (par exemple 1,8 en Urgence, 2,2 en Catastrophe) et l'appliquer au débit et à l'opacité de l'émetteur TardisAir, à la taille du flou (intensite*10) et à la portée (45 studs), puis faire aussi onduler l'air pendant la démat d'urgence (aujourd'hui `p and remat` seulement). Diviser ce facteur par 2 quand UI.effetsReduits() est actif, et ajouter un réglage dans Config.Effets (par ex. DistorsionUrgence = 1.8).

### 38. Marques au sol après l'atterrissage

*Une trace carrée légère reste 30 s là où la cabine s'est posée.*

- **Déjà fait :** rien — Aucune trace après l'atterrissage. Ce qui ressemble : l'onde d'arrivée, un anneau qui s'efface en 1 s (TardisEffets.client.lua:771-790), l'empreinte temporelle, une silhouette laissée au DÉPART (TardisEffets.client.lua:874-940, Config.Empreinte dans TardisConfig.lua:147-153), l'ombre annonciatrice avant l'arrivée (EffetsExterieurs.lua:64-75) et les particules selon le terrain (Decor.lua:12-48)
- **Fichiers :** `src/StarterPlayer/StarterPlayerScripts/TardisEffets.client.lua`, `src/ReplicatedStorage/TardisConfig.lua`
- **Dépend de :** —
- **Dans Studio :** —
- **Feuille de route :** aucun conflit
- **Effort :** petit · **Risque :** faible
- **Approche :** Dans le bloc « 3) Arrivée » de TardisEffets (qui fait déjà le raycast du sol à la fin d'une remat et exclut le Silencieux, le camouflage et Choc=false), créer avec piece() une plaque fine (0,05 stud d'épaisseur), carrée, environ 1,25 fois l'emprise de la cabine pour qu'elle dépasse autour de la base. Elle prend l'orientation (lacet) de la cabine, une couleur sombre tirée du sol, une transparence de 0,7, puis un tween vers 1 en 30 s avant Debris. Ne pas la créer sur l'eau (SurEau). Ajouter Config.Effets.MarquesSol et une durée réglable. La marque est locale à chaque joueur : un joueur qui arrive après l'atterrissage ne la voit pas, ce qui est acceptable.

### 46. Effets selon l'heure du jeu

*La lueur est plus forte la nuit, plus discrète le jour.*

- **Déjà fait :** rien — Lighting.ClockTime ne sert qu'aux lumières de la salle intérieure (nuit automatique, TardisEffets.client.lua:444-445). La lueur et le halo de la cabine (:327-350) et la lampe (:288-311) ne dépendent pas de l'heure
- **Fichiers :** `src/StarterPlayer/StarterPlayerScripts/TardisEffets.client.lua`, `src/ReplicatedStorage/TardisConfig.lua`
- **Dépend de :** —
- **Dans Studio :** —
- **Feuille de route :** aucun conflit
- **Effort :** petit · **Risque :** faible
- **Approche :** Ajouter dans TardisConfig une fonction Config.facteurHeure(clockTime), testable dans outils/simulation, avec une transition douce : environ 1,35 la nuit, 0,7 en plein jour, en fondu entre 5 h et 7 h et entre 17 h 30 et 19 h 30. Multiplier par ce facteur la brillance de la lueur, l'opacité du halo, l'éclat de la lampe et l'opacité des ondes au sol, mais pas les effets de l'intérieur. Réglages dans Config.Effets (Nuit, Jour). Si la place a une heure fixe, l'effet reste constant.

### 53. Lumières de la salle selon l'état

*Bleu posé, ambré en voyage, cyan dans le vortex, rouge en alerte.*

- **Déjà fait :** partiel — Rouge en alerte déjà fait : init.server.lua:927-949 appliquerEclairage() passe les LedsAlerte en rouge (Config.CouleurAlerte), TardisEffets.client.lua:389-399 teinte rouge qui pulse à bord. Hors tension : lumière de secours rouge (TardisEffets.client.lua:475-477). En voyage : les lumières du rotor prennent la couleur du mode (TardisEffets.client.lua:423-436 et 496, CouleurRotor par mode TardisConfig.lua:60-122) et la salle respire avec le moteur. Manque : la teinte de la salle par état (bleu posé, ambré en démat/remat, cyan en E.Vol ou VolVortex).
- **Fichiers :** `src/StarterPlayer/StarterPlayerScripts/TardisEffets.client.lua`, `src/ReplicatedStorage/TardisConfig.lua`
- **Dépend de :** —
- **Dans Studio :** Rien d'obligatoire : le code utilise les Light déjà présentes dans l'intérieur. Il faut juste qu'il y ait des PointLight/SpotLight dans la salle.
- **Feuille de route :** Aucun conflit direct. Les thèmes d'intérieur (attribut Theme, choisis aujourd'hui dans le menu) passeront sur la console en V11, mais ils agissent sur Lighting.Ambient et les LEDs, pas sur les lumières de la salle. À coordonner avec #191 (pas de flash) et #186 (daltonien) si on les fait.
- **Effort :** petit · **Risque :** faible
- **Approche :** Dans proteger("lumieres") (TardisEffets.client.lua:439-505), juste avant objet.Color = couleur, mélanger la couleur d'origine vers une couleur d'état (Config.CouleursSalle = { Pose = bleu, Voyage = ambre, Vortex = cyan, Alerte = rouge, Force = 0.35 }) : Demat/Remat → Voyage, E.Vol ou VolVortex → Vortex, attribut Alerte → Alerte, sinon Pose. Lisser le mélange comme melangeRotor, ne pas toucher aux lumières du rotor ni aux LedsAlerte, et ne rien teinter hors tension (la lumière de secours garde la priorité).

### 43. Effet Catastrophe plus violent

*Éclats, fumée noire et étincelles autour de la cabine lors d'un paradoxe.*

- **Déjà fait :** partiel — Déjà présent en Catastrophe : arcs doublés (TardisEffets.client.lua:751), étincelles à la lampe (:752-768), console qui crache des étincelles et salle rouge à bord (:1065-1077), choc d'atterrissage x2,2 (:258), enseigne rouge chaotique (Signalisation.lua:167-170), saccades maximales (TardisConfig.lua:116-124). Manquent : éclats, fumée noire et étincelles autour de la cabine DEHORS
- **Fichiers :** `src/StarterPlayer/StarterPlayerScripts/TardisEffets.client.lua`, `src/ReplicatedStorage/TardisConfig.lua`
- **Dépend de :** —
- **Dans Studio :** —
- **Feuille de route :** aucun conflit
- **Effort :** moyen · **Risque :** faible
- **Approche :** Dans le bloc « Effets propres aux modes » de TardisEffets, pendant une Remat en Catastrophe : un émetteur de fumée noire (smoke_main.dds, LightInfluence 1, couleur presque noire) sur une pièce d'effet qui suit la cabine, avec des bouffées à chaque souffle, et des gerbes d'étincelles sur les faces. À l'atterrissage forcé, détecté par l'attribut serveur « Catastrophe » (init.server.lua:727), car le serveur remet Mode à Normal en posant le TARDIS : une explosion d'éclats (petites pièces locales non ancrées, sans collision, avec Debris, ou des particules) et une fumée qui traîne environ 20 s. Mettre le tout derrière Config.Effets.Catastrophe et le diviser par 3 en effets réduits. La tentative avortée du paradoxe (Catastrophe puis Urgence) en profitera aussi.

### 41. Vitres qui s'éteignent en dernier

*En démat, les fenêtres restent lumineuses une seconde après le reste.*

- **Déjà fait :** rien — fondu() applique la même transparence alpha à toutes les pièces de l'extérieur (TardisEffets.client.lua:205-225, table visuels :63-87) ; les fenêtres ne sont repérées nulle part dans ce script. Une détection existe ailleurs : Decor.lua:130-135 (Material Glass ou transparence entre 0,1 et 0,95, pour les reflets)
- **Fichiers :** `src/StarterPlayer/StarterPlayerScripts/TardisEffets.client.lua`, `src/ReplicatedStorage/TardisConfig.lua`
- **Dépend de :** —
- **Dans Studio :** Conseillé : ranger les vitres de la cabine dans un dossier/Model nommé par exemple « Fenetres » dans l'extérieur (ou les nommer « Vitre »), pour ne pas dépendre de la détection automatique (verre ou pièce semi-transparente)
- **Feuille de route :** aucun conflit
- **Effort :** moyen · **Risque :** moyen
- **Approche :** Repérer les vitres une fois au chargement (Config.NomFenetres, à défaut la détection de Decor) et les marquer dans visuels. Dans fondu(), en Démat, leur donner Config.Alpha(etat, ecoule - 1, ...) au lieu de alpha et les pousser vers une couleur chaude (Neon) pendant ce retard ; garder max(…, camouflage). Attention : à la fin de la démat, le serveur passe aussitôt en Vol et Config.Alpha renvoie alors 1, ce qui couperait net la seconde de retard. Il faut donc finir le fondu des vitres pendant la première seconde de l'état Vol (sauf si Ciel ou VolLibre), ou compresser le retard dans la dernière seconde de la démat. Prolonger aussi la lueur (PointLight) d'une seconde.

### 191. Pas de flash

*Une option qui supprime tout flash lumineux.*

- **Déjà fait :** partiel — « Réduire les effets » atténue les flashs sans les supprimer : flash plein écran de régénération ramené à une transparence de 0,7 (Regeneration.lua:684), exposition du thème Flashbang plafonnée à 0,6 (TardisEffets.client.lua:359), flashTemporel du vol libre supprimé (TardisVolLibre.client.lua:427), flash d'explosion adapté (AutoDestruction.lua:89-94). Restent sans garde : le flash de la lampe au départ et à l'arrivée (flashLampe, TardisEffets.client.lua:250-252/301/322) et le flash du bouclier (TardisEffets.client.lua:817). Pas d'option dédiée « aucun flash ».
- **Fichiers :** `src/ReplicatedStorage/TardisUI.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisEffets.client.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisVolLibre.client.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Regeneration.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/AutoDestruction.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Signalisation.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisTablette/Volet.lua`
- **Dépend de :** —
- **Dans Studio :** —
- **Feuille de route :** Aucun : ce sont des effets côté client. Seul l'interrupteur, dans les réglages de la tablette Y, devra passer dans le panneau de réglages autonome (n°193) en V11.4.
- **Effort :** petit · **Risque :** faible
- **Approche :** Ajouter UI.sansFlash() (préférence « sansFlash »). Dans chacun des sept à huit endroits, sauter le voile plein écran (Regeneration, AutoDestruction), garder flashLampe à 0, ne plus créer le flash du bouclier ni flashTemporel, ramener l'exposition du thème Flashbang à la normale et rendre la lampe de signalisation fixe au lieu de clignotante. Option : activer sansFlash fait aussi passer effetsReduits à vrai.

## V6.9.10 — Vol libre et vortex

### 23. Pilote automatique de croisière

*Garder cap et altitude sans toucher aux touches.*

- **Déjà fait :** partiel — src/StarterPlayer/StarterPlayerScripts/TardisVolLibre.client.lua:1093 (basculerCap, touche M) et :1131-1137 (le cap fixe ne suit plus la caméra, mais il faut toujours tenir la touche d'avance, GetMoveVector) ; :1003 (basculerStationnaire, touche H) et :1209, :1231, :1233 (altitude figée, sans avance) ; docs/patch-notes/V4.md:139 et :147. Personne ne garde à la fois le cap, l'altitude et la vitesse sans touche.
- **Fichiers :** `src/StarterPlayer/StarterPlayerScripts/TardisVolLibre.client.lua`, `src/ReplicatedStorage/TardisConfig.lua`
- **Dépend de :** —
- **Dans Studio :** —
- **Feuille de route :** Aucun conflit direct : ça vit dans l'interface de vol libre (TardisVolLibre), pas dans le menu T ni dans la tablette Y. Mais la V11 laisse ouverte la question « le vol libre reste-t-il à l'écran ? » : le bouton CROISIÈRE du sous-menu PLUS suivra ce choix. La V9 déplacera ce fichier dans le dossier VolLibre, et la V8 regroupera les boucles par image (#177) : rien ne bloque.
- **Effort :** petit · **Risque :** faible
- **Approche :** Ajoute un état vol.croisiere = { cap, altitude } capturé à l'activation (le regard horizontal de la caméra, vol.centre.Y, le niveau actuel). Dans piloter(), quand il est actif et que le joueur ne touche rien : direction = cap à la vitesse du niveau, altitude tenue comme en stationnaire. Une touche de direction, le frein, la chute, CIBLE, ATTERRIR ICI ou l'urgence l'annulent, et un rayon tiré vers l'avant (~25 studs) le met en stationnaire devant un obstacle pour qu'il ne glisse pas sans fin contre un mur. Ajoute un bouton CROISIÈRE dans le sous-menu PLUS, avec une touche réglable par UI.touche("volCroisiere", …) : toutes les touches évidentes sont déjà prises (F, U, V, B, O, C, Ctrl, R, K, H, I, Maj, N, J, L, P, M, X, G, ZQSD). Rien ne change côté serveur : recevoirPositionVol borne déjà la vitesse.

### 26. Caméra cinématique

*Une caméra extérieure lente qui tourne autour de la cabine pendant le vol.*

- **Déjà fait :** rien
- **Fichiers :** `src/StarterPlayer/StarterPlayerScripts/TardisCamera.client.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisVolLibre.client.lua`, `src/ReplicatedStorage/TardisConfig.lua`
- **Dépend de :** 23
- **Dans Studio :** Rien d'obligatoire si on réutilise le bouton BoutonCamera qui existe déjà sur la console. Une pièce à part sur la console (par exemple « BoutonCameraCinematique ») seulement si l'utilisateur veut un bouton physique séparé.
- **Feuille de route :** Pas de conflit si la caméra passe par TardisCamera (bouton de la console), ce qui va dans le sens de la V11. À l'inverse, une touche ou un bouton dans l'interface de vol libre dépendrait de la question V11 encore ouverte sur le vol libre à l'écran. La V8 regroupe les boucles RenderStepped (#177) : brancher l'orbite sur la boucle de rendu existante de TardisCamera plutôt que d'en ajouter une.
- **Effort :** moyen · **Risque :** moyen
- **Approche :** Aucune orbite en vol aujourd'hui. Code réutilisable : TardisCamera.client.lua (caméra au-dessus de la Lampe, qui suit déjà le TARDIS en vol, recharge la zone avec RequestStreamAroundAsync, réservée aux pilotes à la ligne 146), Replay.lua:64-87 (caméra de poursuite), Regeneration.lua:665 (orbite lente). Ajoute à TardisCamera un mode « orbite » (un bouton à côté de « Quitter la caméra ») : caméra Scriptable qui tourne lentement (~8°/s) autour du pivot de l'extérieur, que chaque client déplace déjà en vol, à une distance de 25 à 35 studs, avec chargerZone relancé toutes les quelques secondes. Pour le pilote, l'orbite casse le pilotage (direction = regard de la caméra) : ne l'autoriser qu'en CROISIÈRE (#23), CAP FIXE, CIBLE ou STATIONNAIRE. Décider aussi si les passagers à bord y ont droit (aujourd'hui le bouton caméra est réservé aux pilotes).

### 30. Freinage d'urgence

*Une touche qui arrête net le TARDIS (avec secousse à bord).*

- **Déjà fait :** partiel — src/StarterPlayer/StarterPlayerScripts/TardisVolLibre.client.lua:50 (TOUCHE_FREIN = LeftControl), :245 (bouton FREIN du sous-menu PLUS), :989-1001 (freiner : vitesse mise à zéro, secousse et champ de vision réduit sur la caméra du pilote seulement, fumée créée sur la copie locale du pilote, sans effet en urgence) ; docs/patch-notes/V4.md:84 et :156. La secousse à bord n'existe pas : rien n'est envoyé au serveur, donc les passagers et les autres joueurs ne sentent ni ne voient rien. Mécanisme réutilisable : TardisExtras.server.lua:1133-1138 (VolLibreChoc renvoyé à tout le monde par ChocPos et ChocTemps) et EffetsExterieurs.lua:221-233 (secouer(0.6) si jeSuisDedans()).
- **Fichiers :** `src/StarterPlayer/StarterPlayerScripts/TardisVolLibre.client.lua`, `src/ServerScriptService/TardisExtras.server.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/EffetsExterieurs.lua`
- **Dépend de :** —
- **Dans Studio :** Facultatif : un son « Frein » (crissement temporel) dans TardisAssets, lu par sonAsset s'il existe.
- **Feuille de route :** Aucun conflit avec la V11 (c'est l'interface de vol, pas T ni Y). La nouvelle action réseau « VolLibreFrein » devra être déclarée dans le garde-barrière unique et le schéma de la V7 (#156, #157). Faite avant la V7, elle fera simplement partie de ce que la V7 recense.
- **Effort :** petit · **Risque :** faible
- **Approche :** Dans freiner(), après l'arrêt : remote:FireServer("VolLibreFrein"). Dans TardisExtras (à côté de VolLibreChoc), si VolLibre == joueur.UserId et qu'il n'y a pas eu de frein dans la dernière seconde : écrire l'attribut FreinTemps = GetServerTimeNow(). Dans EffetsExterieurs, sur FreinTemps : secouer(0.5) si jeSuisDedans(), secousse plus légère selon la distance pour ceux qui sont dehors, et fumée sur l'extérieur pour tout le monde, au lieu de la fumée locale du pilote seul. Garder le refus en urgence, qui est voulu. Les effets réduits (UI.effetsReduits) sont déjà pris en compte par secouer().

### 52. Rotor qui suit la vitesse du vol

*Le rotor monte et descend plus vite en vol libre rapide.*

- **Déjà fait :** partiel — src/StarterPlayer/StarterPlayerScripts/TardisEffets.client.lua:404-420 proteger("rotor") : le rotor pompe en vol libre (actif si attribut VolLibre), mais à vitesse fixe Config.VitesseRotor (TardisConfig.lua:159-160), seulement ×3 pendant 3 s avec RotorBoost (clic sur le rotor, TardisExtras.server.lua:836-852). Aucun lien avec la vitesse du vol (niveaux 25/50/90/150 studs/s, TardisConfig.lua:260-262).
- **Fichiers :** `src/StarterPlayer/StarterPlayerScripts/TardisEffets.client.lua`, `src/ReplicatedStorage/TardisConfig.lua`
- **Dépend de :** —
- **Dans Studio :** —
- **Feuille de route :** Aucun. Le vol libre reste une question ouverte de la V11 mais le rotor n'en dépend pas. La V8 (#177, boucles regroupées) déplacera le code mais ne le change pas.
- **Effort :** petit · **Risque :** faible
- **Approche :** Côté client uniquement, dans proteger("rotor") : mesurer la vitesse réelle de la cabine (écart de exterieur:GetPivot().Position d'une image à l'autre, lissé ; marche pour le pilote comme pour les passagers qui suivent VolLibreCF) et en tirer un facteur 1 à ~3 (vitesse / plus haut niveau de Config.VolLibre.Niveaux, bonus en VolVortex et VolUrgence). Attention : remplacer math.sin(t * vitesse) par une phase cumulée (phase += dt * vitesse) pour que le rotor ne saute pas quand la vitesse change. Ajouter un réglage Config.RotorVolLibre = { FacteurMax = 3 }.

### 136. Ambiance du vortex

*Un son de vent cosmique pendant le vol, seulement à bord.*

- **Déjà fait :** rien — Aucun son de vortex dans le dépôt. Seul le bourdonnement Moteur_Vol joue pendant le vol (src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Ambiance.lua:263-275, fondu enchaîné Moteur_Pose / Moteur_Vol / Moteur_Urgence) : c'est un moteur, pas du vent. On peut réutiliser le modèle « audible seulement à bord » du jukebox (Ambiance.lua:291-293, presence + jeSuisDedans). L'état vortex correspond à Etat == Vol (init.server.lua:520) et à VolPhase == « Invisible » en vol libre.
- **Fichiers :** `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Ambiance.lua`, `src/ReplicatedStorage/TardisConfig.lua`, `src/ServerScriptService/TardisDiagnostic.lua`
- **Dépend de :** —
- **Dans Studio :** Aucune construction. Donner un ID pour Config.Sons.Vortex, ou placer un Sound « Vortex » dans ReplicatedStorage › TardisAssets › Sons.
- **Feuille de route :** aucun conflit
- **Effort :** petit · **Risque :** faible
- **Approche :** Dans la boucle Heartbeat d'Ambiance.lua, cloner le Sound « Vortex » en boucle dans SoundService (son local, non positionné, comme le jukebox). Volume = presence (à bord et alimenté) × (Etat == Vol ou VolPhase == « Invisible ») × 0.4 × UI.volume(), en fondu, et plus bas quand le jukebox joue. Ajouter « Vortex » à Config.Sons (Id 0) et à la liste du diagnostic ; respecter l'option de la n°141 si elle est faite.

## V6.9.11 — Navigation et fiches de lieux

### 1. Destinations favorites en tête de liste

*Les lieux épinglés passent en premier dans le menu, la tablette et le poste du copilote.*

- **Déjà fait :** partiel — Menu T : TardisMenu.client.lua:556-573 (tri favoris d'abord, étiquette « Favori ») et :859 (reconstruit si les favoris changent). Tablette : TardisTablette/Navigation.lua:46-54 (étoile ●/○) et :77-90 (tri favoris d'abord, puis distance ou ordre d'origine). Stockage : TardisUI.lua:609-617 (UI.estFavori / UI.basculerFavori, préférences du joueur). Ce qui manque : le poste du copilote, TardisExtrasClient/Copilote.lua:105-108, garde l'ordre brut de ListeDestinations, sans tri ni étoile.
- **Fichiers :** `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Copilote.lua`
- **Dépend de :** —
- **Dans Studio :** —
- **Feuille de route :** Les favoris sont rangés dans les préférences de chaque joueur (UI.prefs.favoris). La V11 retire le menu T et la tablette Y. Le sélecteur physique de la console est partagé par tout le monde (init.server.lua:1057-1066, ordre alphabétique de listeDestinations :193-202), donc il ne peut pas suivre les favoris d'un seul joueur. Pour la console, il faudra des favoris propres au TARDIS, gardés par le serveur. Le sort du poste du copilote en V11 n'est pas encore décidé (question ouverte dans FEUILLE_DE_ROUTE.md).
- **Effort :** petit · **Risque :** faible
- **Approche :** Dans Copilote.lua, dans remplirListe : ranger d'abord les lieux dans une table, puis les trier comme dans TardisMenu.client.lua:563-567 (UI.estFavori d'abord, ensuite l'ordre d'origine). UI est déjà dans le contexte. Ajouter la sous-étiquette « Favori » et écouter UI.prefsChangees (clé "favoris") pour rafraîchir la liste. Attention : le copilote voit ses propres favoris, pas ceux du pilote.

### 8. Point de base

*Un lieu « Base » défini par les pilotes, raccourci dans tous les menus.*

- **Déjà fait :** rien — Aucun lieu « Base » dans le code (aucune occurrence de Base, PointBase ou maison). Ce qui s'en rapproche : l'entrée « Retour : <précédent> » en tête de liste (TardisMenu.client.lua:550-555, Copilote.lua:100-104), resoudreDestination avec donnees.precedent (init.server.lua:1604-1609) et le Rappel (TardisExtras.server.lua:1361). Modèle à copier pour un réglage du TARDIS fixé par les pilotes et sauvegardé : les catégories de destinations (TardisExtras.server.lua:825 publierCategories, :1352 action « Categorie », sauverReglages :531).
- **Fichiers :** `src/ServerScriptService/TardisServeur/init.server.lua`, `src/ServerScriptService/TardisExtras.server.lua`, `src/ReplicatedStorage/TardisCommandes.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisMenu.client.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisTablette/Navigation.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Copilote.lua`
- **Dépend de :** —
- **Dans Studio :** Rien d'obligatoire. En V11 : un bouton « BASE » à placer sur la console (pièce nommée).
- **Feuille de route :** Le raccourci dans le menu T et la tablette Y disparaîtra en V11 : garder la logique côté serveur et réduire l'interface au strict minimum. En V11.2, prévoir un bouton physique « BASE ». Après la V10, il faudra une base par TARDIS : la ranger dans les réglages de chaque TARDIS, pas dans une liste commune.
- **Effort :** petit · **Risque :** faible
- **Approche :** Côté serveur : une action « DefinirBase » réservée aux pilotes (le lieu actuel, ou une destination du dossier), rangée dans les réglages sauvegardés (sauverReglages) et publiée en attribut BaseNom. Ajouter donnees.base == true dans resoudreDestination (init.server.lua:1571). Côté clients : une entrée « Base : X » en tête de liste, à côté de « Retour : … », dans le menu, la tablette et le copilote, plus le type "base" dans Commandes.donnees (TardisCommandes.lua:91).

### 16. Zones à vitesse réduite

*Un dossier de destinations où seuls Classique et Silencieux sont permis.*

- **Déjà fait :** partiel — Le mécanisme de zones existe déjà. dansZone(position, nomDossier) (init.server.lua:773-786) vérifie une Part de n'importe quel sous-dossier de TARDIS_DESTINATIONS. La zone SANS_EXPRESS (TardisConfig.lua:18 ; init.server.lua:789) fait déjà repasser un Express en Classique via modeAutorise (:467-479), appelé au départ (:495), à l'arrivée (:679), en poche (:1649) et en vol libre (VolLibre.lua:67). Ce qui manque : une zone où l'Urgence, l'Express et le Sauvetage sont tous refusés, et où seuls Classique et Silencieux restent permis.
- **Fichiers :** `src/ReplicatedStorage/TardisConfig.lua`, `src/ServerScriptService/TardisServeur/init.server.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisTablette/Volet.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisMenu.client.lua`, `docs/RAPPELS.md`
- **Dépend de :** —
- **Dans Studio :** Créer dans Workspace > TARDIS_DESTINATIONS un sous-dossier (par exemple VITESSE_REDUITE) avec des Parts qui couvrent les zones. Comme pour SANS_EXPRESS, ces Parts apparaissent aussi dans la liste des destinations.
- **Feuille de route :** aucun conflit
- **Effort :** petit · **Risque :** faible
- **Approche :** Ajouter Config.ZoneVitesseReduite = "VITESSE_REDUITE" et dansZoneVitesseReduite. Dans modeAutorise, si le mode n'est ni Normal ni Silencieux et que la position est dans la zone : alerter(« ZONE À VITESSE RÉDUITE : VOYAGE CLASSIQUE ») et renvoyer "Normal". Il faut décider si l'Urgence imposée (alerte, collision, zone REFUSE, :665-678) passe avant : prévoir un paramètre pour ne pas désarmer une urgence forcée. Remarque : publierDestinations n'écoute que les enfants directs du dossier (ChildAdded, :319-320), pas les Parts ajoutées dans les sous-dossiers pendant la partie (DescendantAdded le ferait).

### 144. Fiches de lieux

*Une fiche RP par destination (description, dangers), affichée à l'arrivée.*

- **Déjà fait :** rien — Aucune fiche de lieu dans le code (grep « danger|fiche|Description » : rien sur les destinations). Ce qui existe autour : à l'arrivée, le bandeau « POSÉ <lieu> » n'affiche que le nom (src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Signalisation.lua:74-77, visible pour les joueurs à bord) ; le nom du lieu est posé dans l'attribut Position par atterrir() (src/ServerScriptService/TardisServeur/init.server.lua:688-689, partDestination = la Part, nom = dest.Name, ligne 1087) ; le Carnet de bord RP (V6.9.1) stocke des notes de joueurs par lieu, mais ce ne sont pas des fiches écrites à l'avance et elles ne s'affichent que dans la tablette (src/ServerScriptService/TardisExtras.server.lua:1084-1105, src/StarterPlayer/StarterPlayerScripts/TardisTablette/Outils.lua:642-734) ; Config.FicheAnomalie (src/ReplicatedStorage/TardisConfig.lua:243-250) sert de modèle de format, mais pour le TARDIS lui-même.
- **Fichiers :** `src/ReplicatedStorage/TardisConfig.lua`, `src/ServerScriptService/TardisServeur/init.server.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Signalisation.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Ambiance.lua`, `docs/patch-notes/V6.md`, `CHANGELOG.md`
- **Dépend de :** —
- **Dans Studio :** Rien n'est obligatoire si les fiches sont écrites dans TardisConfig. En option, l'utilisateur peut ajouter sur chaque Part de TARDIS_DESTINATIONS des attributs texte « Description » et « Dangers », et un attribut « NiveauDanger » (nombre de 0 à 3). Ces attributs passent avant la Config, et il faut vérifier que le nom des Parts correspond aux clés de la Config.
- **Feuille de route :** Pas de conflit avec le menu T ni la tablette Y : la fiche s'affiche dans le bandeau d'arrivée (Signalisation), pas dans ces menus, donc la V11 ne la supprime pas. Pour la V11.1 (écrans de la console), il faudra en plus afficher la fiche du lieu en cours sur un écran de la console. Le dossier des destinations est commun aux trois TARDIS (TardisConfig.lua:15), donc rien ne suppose plusieurs TARDIS. Pour la V7 : la fiche doit être publiée par le serveur dans un attribut, et le client ne doit jamais choisir le texte. Proche des propositions 56 (Bibliothèque, qui pourra réutiliser ces fiches) et 51 (écran de destination sur la console).
- **Effort :** petit · **Risque :** faible
- **Approche :** Ajouter dans TardisConfig une table Config.FichesLieux = { ["Nom du lieu"] = { Description = "...", Dangers = "...", Niveau = 0..3 } }. Dans atterrir() (init.server.lua, à côté de SetAttribute("Position", nom) ligne 689), le serveur lit les attributs de partDestination, ou la table de Config s'ils manquent, et publie l'attribut exterieur « FicheLieu » en JSON ; il le vide quand il n'y a pas de Part (vol libre, Porté/Posé, sur place). Dans Signalisation.lua, sous le bandeau « POSÉ », ajouter une carte de 6 à 8 s pour les joueurs à bord (jeSuisDedans) avec la description et les dangers, colorée selon le niveau. En option, ajouter une ligne « Dangers » sur l'écran Diagnostic NAVIGATION (Ambiance.lua:365), pour préparer la V11.1.

## V6.9.12 — Pannes : le socle commun

### 117. Pannes aléatoires réglables

*Fréquence des pannes réglable (aucune, rare, normale, fréquente).*

- **Déjà fait :** partiel — src/ReplicatedStorage/TardisConfig.lua:600-601 (Config.Systemes.PannesIntervalleMin = 20*60 / PannesIntervalleMax = 40*60) ; src/ServerScriptService/TardisSystemes.server.lua:305-319 (boucle « Pannes aléatoires, très rares » qui tire au hasard vapeur ou incendie). Il n'y a pas de préréglage nommé : pour avoir « aucune panne », il faut mettre un intervalle énorme à la main.
- **Fichiers :** `src/ReplicatedStorage/TardisConfig.lua`, `src/ServerScriptService/TardisSystemes.server.lua`
- **Dépend de :** —
- **Dans Studio :** —
- **Feuille de route :** Aucun si le réglage reste dans TardisConfig. Le mettre dans le menu T ou la tablette Y serait du travail perdu à la V11. Le réglage doit rester par TARDIS (def), ce qui est compatible avec la V10.
- **Effort :** petit · **Risque :** faible
- **Approche :** Ajouter Config.Systemes.FrequencePannes = "Normale" et une table de préréglages : Aucune = arrêt de la boucle, Rare = 40-80 min, Normale = les 20-40 min actuelles, Frequente = 8-15 min. PannesIntervalleMin/Max restent possibles pour des valeurs sur mesure. Dans la boucle de TardisSystemes.server.lua:306, passer par une liste de pannes (fonction + poids) au lieu du if/else vapeur/incendie : c'est elle qui accueillera les propositions 118, 119 et 120. On peut aussi ne tirer une panne qu'à technicien qu'un technicien est en ligne. Les pannes causées par les réglages (surtension, coupure après N voyages) ne sont pas touchées.

### 125. Rapport de panne aux pilotes

*Un message clair aux pilotes : quelle panne, quel effet sur le vol.*

- **Déjà fait :** partiel — src/ServerScriptService/TardisSystemes.server.lua:26-30 (direAuxPilotes, qui écrit aussi aux techniciens) ; messages par panne : :61 (avarie), :202 (vapeur), :211 (incendie), :264-265 (coupure après N voyages), :174 (bouclier tombé) ; écran de la console via interne("alerter") -> TardisServeur/init.server.lua:251. Ces messages disent quoi faire, jamais quel effet la panne a sur le vol. Dans les faits, seuls Avarie et RedemarrageRequis bloquent le vol (ils coupent l'alimentation, testée dans decoller, TardisServeur/init.server.lua:486). Vapeur et incendie ne changent rien au vol.
- **Fichiers :** `src/ServerScriptService/TardisSystemes.server.lua`, `src/ReplicatedStorage/TardisConfig.lua`
- **Dépend de :** —
- **Dans Studio :** —
- **Feuille de route :** Aucun si le rapport passe par le message du serveur et l'écran de la console (alerter), qui restent en V11. Ne pas en faire une carte du menu T ou de la tablette Y.
- **Effort :** petit · **Risque :** faible
- **Approche :** Dans TardisSystemes, créer une table FICHES_PANNES (Avarie, Vapeur, Incendie, Coupure, Bouclier, Air vicié) avec titre, effet sur le vol (« décollage impossible », « aucun effet sur le vol », « bouclier coupé »…) et réparation. Ajouter une fonction signalerPanne(cle) qui remplace les direAuxPilotes actuels : texte en trois parties PANNE / EFFET SUR LE VOL / QUI RÉPARE, et texte court sur l'écran de la console. Les futures pannes 118, 119 et 120 se brancheront sur cette table.

### 129. Historique des pannes

*Les 20 dernières pannes et qui les a réparées.*

- **Déjà fait :** partiel — Le journal de la tablette technicien note les pannes et leur fin, mais il est local au client : 40 lignes perdues à la reconnexion, et il ne commence qu'à l'ouverture (TabletteTechnicien.lua:373-405). Le réparateur n'y figure pas : le nom n'apparaît que dans les messages direAuxPilotes (TardisSystemes.server.lua:242, :903, :326). TardisSupervision.server.lua:168-176 envoie au journal du jeu le début des pannes, sans la réparation ni son auteur. Un modèle à copier existe : le journal des régénérations en JSON côté serveur (TardisSystemes.server.lua:480-485).
- **Fichiers :** `src/ServerScriptService/TardisSystemes.server.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/TabletteTechnicien.lua`, `src/ServerScriptService/TardisSupervision.server.lua`
- **Dépend de :** 125
- **Dans Studio :** —
- **Feuille de route :** L'affichage dans la tablette technicien (touche Y) est à refaire en V11, sur l'écran « journal » de la console prévu en V11.1. Les données gardées côté serveur, dans un attribut, se réutilisent telles quelles.
- **Effort :** petit · **Risque :** faible
- **Approche :** Côté serveur, tenir une liste de 20 entrées par TARDIS : type, heure de début, heure de fin, réparé par. Elle est remplie par signalerPanne (125) et par chaque réparation : visseuse :903, vanne :242, redémarrage :326 et :1161, rotor :143. La publier en JSON dans l'attribut HistoriquePannes de l'extérieur, comme TardisRegenerations. Ajouter un panneau « Historique des pannes » dans la tablette technicien, qui lit cet attribut, et envoyer aussi la réparation avec son auteur sur le bus TardisEvenements (« Journal »).

### 122. Diagnostic par zone

*Le diagnostic montre la zone de l'intérieur où se trouve la panne.*

- **Déjà fait :** partiel — La tablette technicien a déjà un bouton « Localiser » par panne : surbrillance et étiquette avec la distance, pour la grille n°x, le rotor, la vanne, la console et le levier (src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/TabletteTechnicien.lua:419-438 et 558-563, cartes dans lirePannes à la ligne 443). Le Diagnostic serveur (src/ServerScriptService/TardisSystemes.server.lua:1178-1191) ne donne qu'une liste de défauts, sans lieu, et l'intérieur n'a aucune notion de « zone ». Point fragile : le numéro de grille VapeurSurcharge dépend de l'ordre de GetDescendants, recalculé séparément sur le serveur (ligne 193) et sur le client (TabletteTechnicien.lua:27-29). Rien ne garantit que cet ordre soit le même des deux côtés.
- **Fichiers :** `src/ServerScriptService/TardisSystemes.server.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/TabletteTechnicien.lua`, `src/ReplicatedStorage/TardisConfig.lua`, `src/ServerScriptService/TardisDiagnostic.lua`
- **Dépend de :** —
- **Dans Studio :** Un dossier « Zones » dans l'intérieur, avec des pièces invisibles, sans collision, ancrées, qui couvrent chaque zone et portent son nom (Console, Couloir, Salle des machines…). Autre possibilité : un attribut « Zone » sur les pièces de panne (grilles, vanne, levier).
- **Feuille de route :** Le message du diagnostic et la fonction de zone ne sont pas touchés par la feuille de route. Seul l'affichage de la zone sur les cartes de la tablette technicien dépend de son avenir à la V11 (question ouverte). Chaque TARDIS aura ses propres zones (V10) : la fonction doit lire l'intérieur de def, ce qui est déjà la règle.
- **Effort :** petit · **Risque :** faible
- **Approche :** Écrire une fonction zoneDe(part) qui renvoie la pièce du dossier Zones contenant la position, ou à défaut la zone la plus proche. Sans dossier Zones, elle renvoie une direction par rapport à la console (« avant, gauche… »). Ajouter la zone à chaque défaut du Diagnostic (« fuite de vapeur : grille 2, salle des machines ») et au titre des cartes de la tablette technicien. Au passage, publier le nom ou le chemin de la grille en attribut, au lieu d'un numéro qui dépend de l'ordre. Les nouvelles pannes 118, 119 et 120, si elles sont faites avant, ont aussi besoin d'une pièce cible pour être situées.

### 142. Sons de pannes

*Grincements, sifflements de vapeur, étincelles selon la panne.*

- **Déjà fait :** rien — Les pannes ne font aucun son. src/ServerScriptService/TardisSystemes.server.lua:197-213 : surcharge de vapeur et incendie donnent une alerte et un message, sans son ; seul le son « Reparation » joue une fois la panne réglée (:245, :300). Visuels déjà en place côté client : jet de vapeur constant sur la grille en surcharge (Ambiance.lua:321-323), flammes et fumée sur la console (Systemes.lua:14-37). Avarie et RedemarrageRequis n'ont ni son ni effet sonore.
- **Fichiers :** `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Ambiance.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Systemes.lua`, `src/ReplicatedStorage/TardisConfig.lua`, `src/ServerScriptService/TardisDiagnostic.lua`
- **Dépend de :** —
- **Dans Studio :** Aucune construction : les pièces Grille et Console existent déjà. Donner des ID (vapeur, crépitement, grincement, étincelles) pour Config.Sons, ou placer des Sound Panne_Vapeur, Panne_Feu, Panne_Grincement et Panne_Etincelles dans TardisAssets › Sons.
- **Feuille de route :** aucun conflit
- **Effort :** petit · **Risque :** faible
- **Approche :** Côté client, attacher les sons aux visuels existants. Pendant VapeurSurcharge : sifflement en boucle positionné sur la grille concernée (RollOffMax d'environ 40). Pendant Incendie et tant que IncendieEteint est faux : crépitement en boucle sur les pièces en feu. Pendant Avarie ou RedemarrageRequis : un grincement au hasard toutes les 8 à 15 s, et des étincelles brèves au clic sur le rotor. Déclarer ces sons dans Config.Sons (Id 0) et dans le diagnostic. Les nouvelles pannes 118, 119 et 120 suivront le même modèle, et la n°64 (console qui réagit aux pannes) s'y ajoute facilement.

## V6.9.13 — Nouvelles pannes et outils du technicien

### 118. Nouvelle panne : fuite d'air

*L'air baisse vite tant qu'un technicien n'a pas colmaté.*

- **Déjà fait :** partiel — L'air existe déjà, mais pas la fuite : attribut RegulAir et usure lente toutes les 30 s dans src/ServerScriptService/TardisSystemes.server.lua:1196-1216, purge à 100 % dans TardisSystemes.server.lua:1165-1177, seuil d'air vicié et voile gris dans src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/TabletteTechnicien.lua:93-100, carte « AIR VICIÉ » dans lirePannes (TabletteTechnicien.lua:~490). Aucune panne « fuite d'air » ni aucun colmatage.
- **Fichiers :** `src/ServerScriptService/TardisSystemes.server.lua`, `src/ReplicatedStorage/TardisConfig.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/TabletteTechnicien.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisTablette/Outils.lua`, `src/ServerScriptService/TardisSupervision.server.lua`, `src/ServerScriptService/TardisDiagnostic.lua`
- **Dépend de :** 117
- **Dans Studio :** Facultatif : des pièces nommées « FuiteAir » (ou un dossier « Conduits ») aux endroits où l'air peut fuir. Sans elles, la fuite se place sur une grille de vapeur existante.
- **Feuille de route :** La carte d'intervention et le compteur de pannes vivent dans la tablette technicien et dans l'outil Ingénierie de la tablette Y. La V11 retire la tablette Y, et le sort de la tablette technicien y est encore une question ouverte. La logique serveur et le colmatage physique (ProximityPrompt) ne sont pas concernés.
- **Effort :** moyen · **Risque :** moyen
- **Approche :** Côté serveur, ajouter panneFuiteAir() à côté de panneVapeur (TardisSystemes.server.lua:197). Elle pose l'attribut FuiteAir (le numéro du point) et lance une perte rapide, par exemple TECH.FuiteAirPerte points toutes les 5 s. La purge (ligne 1165) est refusée ou sans effet tant que la fuite n'est pas colmatée. Le colmatage se fait par un ProximityPrompt sur le point : visseuse ou clé à molette en main, E maintenu quelques secondes, comme la vanne aux lignes 226-250. Ensuite, ajouter la panne au tirage de la 117, au Diagnostic (ligne 1180), au journal de TardisSupervision.server.lua:172-174, au compteur de TardisTablette/Outils.lua:119, et une carte « FUITE D'AIR » avec Localiser dans lirePannes, plus un jet sifflant au point de fuite.

### 119. Nouvelle panne : rotor bloqué

*Le TARDIS ne peut plus décoller tant que le rotor n'est pas débloqué.*

- **Déjà fait :** rien — Le rotor ne sert aujourd'hui qu'à la réparation de l'intégrité (prompt TardisReparation, src/ServerScriptService/TardisSystemes.server.lua:129-145). Les décollages sont bloqués seulement par Alimentation et DemarrageBloque, vérifiés en trois endroits : decoller() dans src/ServerScriptService/TardisServeur/init.server.lua:481-487, demarrerVolLibre() dans src/ServerScriptService/TardisServeur/VolLibre.lua:83-89 et teleporterEnPoche() dans init.server.lua:1641-1645. Il n'existe aucun attribut RotorBloque.
- **Fichiers :** `src/ServerScriptService/TardisSystemes.server.lua`, `src/ServerScriptService/TardisServeur/init.server.lua`, `src/ServerScriptService/TardisServeur/VolLibre.lua`, `src/ReplicatedStorage/TardisConfig.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisEffets.client.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/TabletteTechnicien.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisTablette/Outils.lua`, `src/ServerScriptService/TardisSupervision.server.lua`
- **Dépend de :** 117
- **Dans Studio :** Rien d'obligatoire, le Rotor existe déjà. Facultatif : un Sound « RotorBloque » (grincement) dans TardisAssets > Sons.
- **Feuille de route :** La même vérification est copiée dans trois fonctions. Le nettoyage de la V8 voudra la regrouper : autant créer tout de suite une fonction unique de « raison de blocage au départ ». Les affichages de la carte technicien et de la tablette Y relèvent de la V11.
- **Effort :** moyen · **Risque :** moyen
- **Approche :** Ajouter panneRotor() dans TardisSystemes, seulement quand le TARDIS est posé : elle met l'attribut RotorBloque et lance une alerte. Créer une seule fonction de blocage (Alimentation, DemarrageBloque, RotorBloque) et l'appeler dans decoller, demarrerVolLibre et teleporterEnPoche, avec le message « ROTOR BLOQUÉ » ; ajouter aussi une ligne « (ROTOR BLOQUÉ) » dans majEcran (init.server.lua:226). Pour débloquer : un second prompt sur le rotor (clé à molette, E maintenu), décalé avec UIOffset pour ne pas gêner le prompt Réparer. Pilotes et techniciens doivent pouvoir le faire, pour ne pas bloquer le TARDIS si aucun technicien n'est en ligne. En plus : rotor qui tremble quand on tente de décoller (TardisEffets), carte technicien, Diagnostic, journal de Supervision et compteur Ingénierie.

### 127. Outil : scanner portatif

*Un outil qui montre l'état d'un système en le visant.*

- **Déjà fait :** rien — Il n'existe aucun outil qui vise. La table OUTILS ne contient que Chiffon, Visseuse, CleMolette et Extincteur (src/ServerScriptService/TardisSystemes.server.lua:862-867). Le seul « scanner » est le radar de la tablette (src/StarterPlayer/StarterPlayerScripts/TardisTablette/Scanner.lua). L'état des systèmes n'est lisible que dans les jauges de la tablette technicien (TabletteTechnicien.lua:618-640).
- **Fichiers :** `src/ServerScriptService/TardisSystemes.server.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/TabletteTechnicien.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Systemes.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/init.client.lua`
- **Dépend de :** —
- **Dans Studio :** Rien d'obligatoire : l'outil vise les pièces qui existent déjà (Grille / Grilles, Vanne, Rotor, levier Alimentation, Console). En option, un MeshPart ou un modèle de scanner à mettre dans TardisAssets à la place de la pièce de base.
- **Feuille de route :** Les boutons qui donnent l'outil sont dans la tablette technicien (TabletteTechnicien.lua:344) et dans le menu technicien (Systemes.lua:120). La V11 les déplacera. L'outil, lui, est un Tool du sac et reste valable. Il ajoute un raycast de plus, à ranger dans l'utilitaire unique de la 171 (V8).
- **Effort :** moyen · **Risque :** faible
- **Approche :** Ajouter « Scanner » dans OUTILS (côté serveur : simple distribution) et dans les deux listes de boutons. Tout le reste se fait sur le client, en lecture seule : un nouveau module client détecte le Tool « Scanner » en main. Au clic, il lance un raycast caméra vers la souris sur l'intérieur, reconnaît la pièce visée (grille, vanne, rotor, levier, console) et affiche une étiquette (BillboardGui) avec les attributs correspondants : VapeurSurcharge et avancement, Incendie, PointsDeVie et PV, RegulAir, RegulEnergie, Alimentation. Aucune action serveur n'est envoyée, donc la V7 n'a rien à sécuriser.

### 128. Outil : soudeur

*Un outil pour les pannes de structure (intégrité).*

- **Déjà fait :** partiel — L'intégrité existe : PV et avarie (src/ServerScriptService/TardisSystemes.server.lua:49-90). La seule réparation consiste à maintenir E 5 s sur le rotor, pour les pilotes comme pour les techniciens (:124-146, +1500 PV par maintien, Config.Systemes.ReparationParMaintien, TardisConfig.lua:597). Aucun soudeur et aucune « panne de structure » : les dégâts baissent seulement les PV (:71-77) et ne laissent aucune trace sur la cabine.
- **Fichiers :** `src/ServerScriptService/TardisSystemes.server.lua`, `src/ReplicatedStorage/TardisConfig.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/TabletteTechnicien.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Systemes.lua`
- **Dépend de :** —
- **Dans Studio :** Un dossier « Structure » (ou « Breches ») dans l'intérieur : des pièces ancrées et invisibles posées sur les murs et la console, aux endroits où une brèche peut s'ouvrir. En option, un modèle de soudeur dans TardisAssets.
- **Feuille de route :** Même remarque que la 127 : la distribution passe par la tablette technicien et le menu technicien, que la V11 déplacera. Il faut décider si le prompt du rotor reste. C'est la seule réparation des pilotes, et elle doit rester possible pendant une avarie.
- **Effort :** moyen · **Risque :** moyen
- **Approche :** Dans degats(), au-delà d'un seuil (explosion, ou PV sous 60 %), ouvrir une brèche sur une pièce du dossier Structure. L'état est publié dans un attribut Breche, la fumée et les étincelles sont gérées côté client. Ajouter « Soudeur » dans OUTILS : un clic à moins de 8 studs de la brèche fait avancer la soudure (n/4), referme la brèche et rend des PV. Garder le prompt du rotor, en réduisant son gain quand une brèche est ouverte. Ajouter la brèche aux pannes lues par lirePannes() et au diagnostic (:1180-1188).

## V6.9.14 — Équipage et garde-robe

### 63. Garde-robe améliorée

*Plus de tenues dans les casiers, rangées par catégorie.*

- **Déjà fait :** partiel — Casiers et tenues fonctionnent déjà : 9 tenues dans Config.Tenues (src/ReplicatedStorage/TardisConfig.lua:418-429), chacune avec un champ « categorie » (Festive, Comité d'Éthique, Ressources Humaines, Bureau de l'Admin). Le menu du casier (src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Interactions.lua:98-224) n'affiche la catégorie que dans la description (l. 166), sans regrouper : tri par favoris puis par index (l. 152-159). Côté serveur : appliquerTenue (src/ServerScriptService/TardisExtras.server.lua:944-960) et action « Tenue » (l. 1169-1174).
- **Fichiers :** `src/ReplicatedStorage/TardisConfig.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Interactions.lua`
- **Dépend de :** —
- **Dans Studio :** Rien à construire. Fournir les identifiants Shirt/Pants (catalogue Roblox) des nouvelles tenues et vérifier dans Studio qu'ils s'affichent.
- **Feuille de route :** Aucun conflit direct : le casier est un panneau à part, pas le menu T ni la tablette Y. La V9 déplacera Interactions.lua. Attention : Config.Tenues sert aussi de repli à la régénération (TardisSystemes.server.lua:415-417), donc les nouvelles tenues pourront aussi être tirées au hasard après une régénération.
- **Effort :** petit · **Risque :** faible
- **Approche :** Ajouter les tenues à la FIN de Config.Tenues, jamais au milieu : les favoris (UI.prefs.tenuesFavorites[tostring(i)], Interactions.lua:157 et 170) et l'attribut TardisTenue sont rangés par index, et insérer au milieu les décalerait. Mieux encore, passer la clé des favoris au nom de la tenue. Dans construire(), regrouper par catégorie avec un en-tête par groupe (TextLabel au LayoutOrder calculé), favoris en premier, et en option des onglets ou filtres par catégorie. Ajouter un champ facultatif regeneration = false pour exclure les tenues festives du tirage de la régénération.

### 90. Tenue de l'équipe au spawn

*Une tenue d'uniforme donnée à l'apparition (C.A.T. et C.T.A.T.).*

- **Déjà fait :** rien — Aucune tenue donnée à l'apparition selon l'équipe. Briques réutilisables : TardisExtras.server.lua:945-958 appliquerTenue (haut et bas, pour les casiers), TardisSystemes.server.lua:416-428 habillerTenueJeu, TardisSystemes.server.lua:850-853 suivreJoueur / CharacterAdded (surveillance de la régénération), TardisSystemes.server.lua:520-575 spawns des équipes dans le TARDIS (bloc « premier TARDIS seulement »). Config.Tenues (TardisConfig.lua:419) contient des tenues de casier (festive, admin…), pas d'uniforme d'équipe.
- **Fichiers :** `src/ReplicatedStorage/TardisConfig.lua`, `src/ServerScriptService/TardisSystemes.server.lua`
- **Dépend de :** —
- **Dans Studio :** Rien à construire, mais il faut fournir les identifiants Shirt et Pants (vêtements publiés sur Roblox) de l'uniforme C.A.T. et de l'uniforme C.T.A.T.
- **Feuille de route :** Aucun avec V10/V11 (rien ne passe par le menu T ou la tablette Y). En V9, le code ira dans le dossier « Equipage ». Le seul point délicat est la régénération de la C.A.T., qui change l'apparence.
- **Effort :** moyen · **Risque :** moyen
- **Approche :** Ajouter Uniforme = { shirt = …, pant = … } (et Actif = true) à Config.Equipe et à Config.EquipeTechnique. Dans TardisSystemes, dans le bloc du premier TARDIS, sur CharacterAdded (et sur un changement de Team), appliquer le haut et le bas comme habillerTenueJeu si la Team correspond. Il ne faut pas appliquer l'uniforme quand le personnage est recréé par une régénération (enAttente[UserId] existe, voir TardisSystemes.server.lua:837-844). Il faut aussi décider si changerApparence (TardisSystemes.server.lua:450) remet l'uniforme après la nouvelle apparence (visage et cheveux changent, uniforme gardé) : à mettre en option, car ApplyDescription remplace les vêtements.

### 89. Badges des équipes

*Un badge au-dessus de la tête des membres C.A.T. et C.T.A.T. (option).*

- **Déjà fait :** rien — Aucun badge au-dessus de la tête (aucun BillboardGui lié aux équipes). Il existe seulement les briques : src/ReplicatedStorage/TardisUI.lua:336 UI.badge (une étiquette d'interface, pas un badge au-dessus de la tête), TardisUI.lua:591 UI.couleurJoueur (couleur de la Team), TardisConfig.lua:132 Config.Equipe et TardisConfig.lua:139 Config.EquipeTechnique (noms des Teams). Les seuls BillboardGui sont la bulle de l'interphone (Interactions.lua:81) et le marqueur de la tablette technicien (TabletteTechnicien.lua:427).
- **Fichiers :** `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Badges.lua (nouveau module)`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/init.client.lua`, `src/ReplicatedStorage/TardisConfig.lua`
- **Dépend de :** —
- **Dans Studio :** Rien d'obligatoire. En option, l'identifiant d'une image (Decal publiée) pour l'emblème de la C.A.T. et celui de la C.T.A.T. ; sans image, le badge est un simple texte coloré.
- **Feuille de route :** Le réglage on/off ne doit pas aller dans la tablette Y (préférences, Volet) : la V11.4 retire la tablette. Il faut le mettre dans TardisConfig (Config.Equipe.Badge). Le module client est cloné une fois par TARDIS : il faut une garde « premier TARDIS seulement » pour ne pas créer trois badges après la V10.
- **Effort :** petit · **Risque :** faible
- **Approche :** Un module client crée un BillboardGui (texte « C.A.T. » ou « C.T.A.T. », couleur de la Team via UI.couleurJoueur, MaxDistance d'environ 60) sur la tête de chaque joueur dont la Team correspond à Config.nomEquipe() ou à Config.EquipeTechnique.Nom. Il se met à jour sur CharacterAdded et sur GetPropertyChangedSignal("Team"). Comme tout se fait côté client, rien ne passe par le réseau et aucune RemoteEvent n'est ajoutée (rien à sécuriser en V7). Option Config.Equipe.Badge = true, à vérifier aussi pour voir si le jeu SCP affiche déjà ses propres étiquettes de grade.

### 54. Portes intérieures animées

*Les portes intérieures s'ouvrent et se ferment avec les extérieures.*

- **Déjà fait :** partiel — src/StarterPlayer/StarterPlayerScripts/TardisPortail.client.lua:330-357 : le dossier PortesInterieures (Config.NomPortesInt, TardisConfig.lua:44) est seulement rendu invisible et non collidable d'un coup quand PorteOuverte est vrai, sans animation. Les battants extérieurs tournent dans src/Workspace/TARDIS/TARDIS_x/EXTERIEURE/TARDISDoors/LeftDoor/Shut.server.lua:19-39 (rotateMod) ; LeftOpen/RightOpen sont lus par TardisLiaisonPortes.server.lua:12-40.
- **Fichiers :** `src/StarterPlayer/StarterPlayerScripts/TardisPortail.client.lua`, `src/ReplicatedStorage/TardisConfig.lua`
- **Dépend de :** —
- **Dans Studio :** Ranger PortesInterieures en deux Models « Gauche » et « Droite » (un par battant), chacun avec une Part « Charniere » (ou un PrimaryPart) placée sur l'axe de rotation, et vérifier que les battants ouverts ne cachent pas la Part Portail (sinon la fenêtre vers l'extérieur est bouchée).
- **Feuille de route :** Aucun conflit fort. Le script tourne déjà une fois par TARDIS ; en V10, TARDIS_2 et TARDIS_3 devront avoir le même rangement de PortesInterieures dans Studio, sinon ils gardent le masquage actuel.
- **Effort :** moyen · **Risque :** moyen
- **Approche :** Côté client dans TardisPortail : si PortesInterieures contient Gauche/Droite, remplacer le masquage par une rotation animée (TweenService sur un CFrameValue, PivotTo autour de la charnière) qui suit LeftOpen et RightOpen de TARDISDoors, avec CanCollide coupé pendant l'ouverture. Si ce rangement n'existe pas, on garde le masquage actuel. Tester avec le passage sans coupure et la vue par le Portail (battantsCopies, lignes 260-327), qui sont la partie fragile.

## V6.9.15 — Confort de l'interface et accessibilité

### 188. Effets réduits par défaut sur mobile

*Les téléphones démarrent en effets réduits.*

- **Déjà fait :** rien — UI.effetsReduits renvoie UI.pref("effetsReduits", false) (src/ReplicatedStorage/TardisUI.lua:529-531) : la valeur par défaut est toujours faux, sur tous les appareils. Le mobile n'est détecté que pour les boutons tactiles (TardisMenu.client.lua:713, TabletteTechnicien.lua:752). Tous les effets lisent déjà UI.effetsReduits (TardisEffets.client.lua:165/206/243, TardisVolLibre.client.lua:427/787, Regeneration.lua:37, Signalisation.lua:98, EffetsExterieurs.lua:220, AutoDestruction.lua:90).
- **Fichiers :** `src/ReplicatedStorage/TardisUI.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisTablette/Volet.lua`
- **Dépend de :** —
- **Dans Studio :** —
- **Feuille de route :** Aucun conflit sur le fond. Il y a en revanche un piège avec la n°193 : les préférences suivent le joueur sur tous ses appareils (une seule clé prefs_UserId). Si un joueur sur téléphone sauvegarde effetsReduits=true, cette valeur s'applique aussi sur PC, et inversement.
- **Effort :** petit · **Risque :** faible
- **Approche :** Dans UI.effetsReduits, quand la préférence n'est pas définie, renvoyer UserInputService.TouchEnabled and not KeyboardEnabled, sur le modèle de UI.debutant (TardisUI.lua:563). Pour éviter le piège de la synchronisation, sauvegarder le choix dans une clé séparée selon le type d'appareil (« effetsReduitsMobile » sur téléphone, « effetsReduits » sinon). Mettre à jour le libellé dans Volet.lua:161 (« par défaut sur mobile »).

### 190. Sous-titres des sons

*Un petit texte pour les sons importants (alarme, départ, arrivée).*

- **Déjà fait :** rien — Aucun sous-titre. Les sons de voyage sont joués côté serveur : jouer et jouerVoyage (src/ServerScriptService/TardisServeur/init.server.lua:104-128), l'alarme des LED en init.server.lua:947. L'alarme en boucle est côté client (TardisExtrasClient/Ambiance.lua:208-228, attribut Alerte), le son « Cloitre » d'intrusion est dans TardisExtras.server.lua:209. Le client peut déjà tout déduire des attributs de l'extérieur : Etat et DebutEtat, Mode (Discret = pas de son), Alerte, Intrusion, AutoDestructionDebut, Jukebox.
- **Fichiers :** `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/SousTitres.lua (nouveau)`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/init.client.lua`, `src/ReplicatedStorage/TardisUI.lua`, `src/ReplicatedStorage/TardisConfig.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisTablette/Volet.lua`
- **Dépend de :** —
- **Dans Studio :** —
- **Feuille de route :** Aucun pour l'affichage, qui est un petit bandeau à l'écran et pas un menu. En revanche, l'interrupteur placé aujourd'hui dans les réglages de la tablette Y devra déménager vers le panneau de réglages autonome (n°193) en V11.4. Pour l'instant, les visiteurs et les techniciens n'ont accès à aucun réglage.
- **Effort :** petit · **Risque :** faible
- **Approche :** Créer un module client SousTitres, chargé par TARDIS comme les autres modules d'init.client.lua. Il écoute les attributs Etat, Mode, Alerte, Intrusion, AutoDestructionDebut et Jukebox, et affiche en bas de l'écran pendant 3 à 4 s un texte comme « [Dématérialisation] », « [Atterrissage d'urgence] », « [Alarme] » ou « [Musique : …] ». L'affichage n'a lieu que si le joueur est à bord ou à portée sonore de la cabine, et jamais en mode Silencieux. Les textes vont dans une table Config.SousTitres, et une préférence « sousTitres » sert d'interrupteur.

### 72. Taille de l'interface

*Agrandir ou réduire toute l'interface (accessibilité).*

- **Déjà fait :** partiel — src/ReplicatedStorage/TardisUI.lua:523-526 (UI.tailleInterface, de 0,6 à 1,4, préférence « taille »). Réglage -, Normale, + dans TardisTablette/Volet.lua:123-138. Appliqué à la tablette (Ouverture.lua:16 et :48), au menu T (TardisMenu.client.lua:832-837), au vol libre (TardisVolLibre.client.lua:1576-1582), à la rotation (TardisRotation.client.lua:423-425) et à la tablette technicien (TabletteTechnicien.lua:707). Pas appliqué : le poste du copilote (Copilote.lua:264 a un UIScale sans tailleInterface), ni Maintenance, Signalisation, Regeneration, Interactions, TabletteLecture, Replay, Systemes, Preferences, AutoDestruction, TardisPorter et TardisCamera (aucun UIScale lié à la taille).
- **Fichiers :** `src/ReplicatedStorage/TardisUI.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Copilote.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Maintenance.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Regeneration.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Interactions.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/TabletteLecture.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Replay.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Systemes.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Preferences.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/AutoDestruction.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisPorter.client.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisCamera.client.lua`
- **Dépend de :** —
- **Dans Studio :** —
- **Feuille de route :** Le seul réglage de la taille est dans la page Réglages de la tablette Y (Volet.lua). Il disparaît donc en V11.4, et il est hors de portée des techniciens et des visiteurs, qui n'ont pas cette tablette. Il faudra lui trouver une autre place en V11 (question ouverte de la feuille de route : restera-t-il des interfaces à l'écran ?). La proposition 187 (textes plus gros) touche les mêmes fichiers et peut se faire en même temps.
- **Effort :** petit · **Risque :** faible
- **Approche :** Ajouter dans TardisUI une fonction commune, par exemple UI.suivreTaille(uiscale, calculBase), qui applique base × UI.tailleInterface() et se réabonne à UI.prefsChangees pour « taille ». La brancher sur chaque ScreenGui des modules qui l'ignorent, en commençant par le poste du copilote. Cela remplace les 5 copies actuelles du même calcul, donc c'est du nettoyage qui a sa place en V8.

### 81. Animation d'ouverture plus courte

*Option pour ouvrir le menu sans animation.*

- **Déjà fait :** rien — Aucune option. Menu T : TardisMenu.client.lua:611-623 (tween de 0,45 s plus balayage de 0,7 s). Tablette Y : TardisTablette/Ouverture.lua:52-89 (voile 0,35 s, flou 0,45 s, échelle et rotation 0,55 s Back, allumage de l'écran, panneaux décalés de 0,045 s chacun, balayage de 0,9 s). Une pref voisine existe, UI.effetsReduits (TardisUI.lua:529-531), mais elle ne touche pas aux ouvertures de menus
- **Fichiers :** `src/ReplicatedStorage/TardisUI.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisMenu.client.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisTablette/Ouverture.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisTablette/Volet.lua`
- **Dépend de :** —
- **Dans Studio :** —
- **Feuille de route :** Ne vaut que pour le menu T et la tablette Y, tous deux retirés en V11.4. La pref elle-même, dans TardisUI, peut resservir aux postes à l'écran qui resteraient après la V11 (copilote, tablette technicien : question ouverte de la feuille de route).
- **Effort :** petit · **Risque :** faible
- **Approche :** Ajouter UI.ouvertureInstantanee() = UI.pref("ouvertureRapide", false) dans TardisUI. Quand elle est vraie : dans basculerMenu, une durée de 0 sans balayage ; dans ouvrir() et fermer() de la tablette, poser directement Scale, Position, Rotation et transparences, sans échelonner les panneaux. Ajouter un interrupteur « Ouverture des menus sans animation » dans la section OPTIONS des Réglages (Volet.lua, vers la ligne 160). Ne pas modifier UI.animer de façon globale : des appels attendent .Completed (par exemple Preferences.lua:51).

### 78. Fermer la tablette en cliquant dehors

*Option pour fermer la tablette d'un clic à côté.*

- **Déjà fait :** rien — Refus volontaire dans le code : src/StarterPlayer/StarterPlayerScripts/TardisTablette/Ouverture.lua:111 (« Le voile ne ferme rien : seule la croix rouge en haut à droite ferme la tablette »). Le voile est déjà un TextButton plein écran avec Modal=true (Construction.lua:64-67), donc le clic à côté est déjà capté, mais aucune action ne lui est branchée.
- **Fichiers :** `src/StarterPlayer/StarterPlayerScripts/TardisTablette/Ouverture.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisTablette/Volet.lua`
- **Dépend de :** —
- **Dans Studio :** —
- **Feuille de route :** La tablette Y est retirée en V11.4 : cette option ne servira que jusque-là. C'est acceptable vu le très faible effort.
- **Effort :** petit · **Risque :** faible
- **Approche :** Ajouter une préférence « fermerDehors » (désactivée par défaut, pour garder le comportement actuel) et un interrupteur dans la page Réglages (Volet.lua). Dans Ouverture.lua, brancher W.voile.Activated sur fermer() quand la préférence est active et qu'aucune surcouche ou mode de placement n'est en cours (Placement.lua:113 masque déjà le voile pendant le placement).

### 80. Menu rapide repositionnable

*Glisser le menu rapide où on veut sur l'écran (position retenue).*

- **Déjà fait :** rien — src/StarterPlayer/StarterPlayerScripts/TardisMenu.client.lua:32 (POSITION_Y = 0.55 fixe), :43-44 (OUVERT/FERME calés sur le bord gauche), :613 (basculerMenu anime vers ces positions fixes). Aucun code de glisser-déposer. Les préférences sont déjà sauvegardées côté serveur, ce qui suffirait pour retenir la position : TardisUI.lua:499-521 (UI.sauverPrefs / UI.setPref), TardisExtras.server.lua:1066-1071 et :1120-1124 (DataStore prefs_UserId)
- **Fichiers :** `src/StarterPlayer/StarterPlayerScripts/TardisMenu.client.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisTablette/Volet.lua`
- **Dépend de :** —
- **Dans Studio :** —
- **Feuille de route :** Conflit direct : c'est une amélioration du menu T, que la V11.4 supprime. La durée de vie du travail va jusqu'à la V11, pas au-delà. À faire seulement si le menu T doit rester longtemps, sinon c'est la proposition la moins rentable du lot.
- **Effort :** moyen · **Risque :** moyen
- **Approche :** Rendre l'en-tête du tiroir (entete, ligne 58) déplaçable avec InputBegan/InputChanged (souris et toucher), et borner la position à l'écran en tenant compte de echelleTiroir.Scale. Enregistrer une pref « positionMenu » {x, y} en proportion de l'écran via UI.setPref, et calculer OUVERT depuis cette pref. Côté fermeture, garder la sortie par la gauche (FERME) ou passer à un fondu. Ajouter « Rétablir la position du menu » dans les Réglages (Volet.lua). Le risque est moyen : le glisser ne doit pas gêner le défilement du ScrollingFrame contenu ni les boutons tactiles sur mobile.

## V7 — Sécurité : banc d'essai, audits et sauvegarde

### 185. Simulations élargies

*Couvrir le serveur de voyage, le copilote et la maintenance dans les simulations.*

- **Déjà fait :** partiel — outils/simulation/lancer.sh:5 ne lance que sim_config, sim_modules (TardisSauvegarde et TardisCommandes : voyage auto ou manuel, REMAT, paradoxe, avec un faux pont, sim_modules.py:71-160) et sim_supervision. Aucune simulation ne charge TardisServeur/init.server.lua (serveur de voyage), le copilote (init.server.lua:1685-1720 et action « Copilote » :2023) ni la maintenance (TardisSystemes.server.lua:1227). Obstacle : dans roblox.py:225-238, Vector3 et CFrame sont de fausses valeurs (« tout calcul renvoie une Valeur ») : pas de vraie géométrie, pas de Raycast.
- **Fichiers :** `outils/simulation/roblox.py`, `outils/simulation/luau.py`, `outils/simulation/monde.py`, `outils/simulation/lancer.sh`, `outils/simulation/LISEZMOI.md`, `outils/simulation/sim_serveur.py (nouveau)`, `outils/simulation/sim_copilote.py (nouveau)`, `outils/simulation/sim_maintenance.py (nouveau)`
- **Dépend de :** —
- **Dans Studio :** Rien à construire : les outils tournent hors de Roblox.
- **Feuille de route :** Les simulations doivent viser la partie serveur, pas les écrans de la tablette ou du menu (supprimés en V11). Les chemins de fichiers changeront en V9 : il faut prévoir de centraliser les chemins dans monde.py. Pour la V10, prévoir que le faux monde puisse contenir 3 TARDIS, sans l'exiger maintenant.
- **Effort :** gros · **Risque :** faible
- **Approche :** Je conseille de la faire au début de la V7, avant le garde-barrière unique (156) qui réécrit les OnServerEvent de TardisServeur : il faut un filet de non-régression, et les tests de triche (167) se brancheront sur le même banc d'essai. 1) Donner à roblox.py de vrais Vector3 et CFrame (arithmétique, Magnitude, Unit, lookAt, ToObjectSpace), un Raycast et un GetPartBoundsInRadius qui ne trouvent rien, plus ProximityPrompt et TweenService. 2) sim_serveur : charger TardisServeur avec VolLibre.lua et vérifier démat, vortex, remat, refus en zone REFUSE et vol libre borné en vitesse. 3) sim_copilote et sim_maintenance : désigner et relâcher un copilote, vérifier que la maintenance bloque la démat (via TardisSystemes), puis les ajouter à lancer.sh.

### 166. Attributs : audit

*Vérifier qu'aucun attribut lu par le serveur ne peut venir d'un client.*

- **Déjà fait :** partiel — Roblox ne renvoie jamais au serveur un attribut posé par un client, et le serveur ne lit que des attributs écrits par le serveur. Sur le joueur, TardisPiloteTemp_ et TardisBanni_ sont lus à TardisServeur/init.server.lua:353-355 et écrits à TardisExtras.server.lua:656-657 ; TardisAccesPilote et TardisAccesTechnicien sont écrits à TardisSupervision.server.lua:95-96 ; TardisTechnicien_ est lu à TardisSystemes.server.lua:24 et écrit à TardisExtras.server.lua:659 ; TardisMortReelle est écrit à TardisSystemes:793 et lu à TardisSystemes:695. Les clients n'écrivent que des attributs d'interface (CouleurBase, Disponible) et TardisRotation, TardisReplay, TardisTablette, TardisTabletteTech sur le joueur local (Outils.lua:155 et 477, Journal.lua:111, Replay.lua:42) ; aucun serveur ne les lit. outils/simulation/analyse.py:192-207 croise déjà les attributs lus et écrits, mais sans distinguer le serveur du client. Rien de cela n'est écrit dans un document.
- **Fichiers :** `outils/simulation/analyse.py`, `docs/patch-notes/V6.md (ou la note de V7)`
- **Dépend de :** —
- **Dans Studio :** —
- **Feuille de route :** La V8 (n° 180, moins d'attributs répliqués) et la V9 (un seul point d'entrée, les scripts ne se parlent plus par attributs) changeront la liste des attributs. L'audit restera vrai s'il est automatisé, mais une liste écrite à la main deviendrait vite fausse.
- **Effort :** petit · **Risque :** faible
- **Approche :** Ajouter à analyse.py une section « 8. Attributs lus par un serveur » : classer chaque SetAttribute et GetAttribute selon le côté qui l'écrit (src/ServerScriptService contre src/StarterPlayer) et signaler tout attribut lu par le serveur qui n'est écrit que par un client. L'audit manuel ci-dessus ne trouve aucun cas aujourd'hui. Noter le résultat et la règle « le client n'écrit jamais d'attribut qui compte » dans la note de V7.

### 168. Protection de la sauvegarde

*Taille maximale et schéma vérifié à la lecture.*

- **Déjà fait :** partiel — TardisSauvegarde.lua:79-103 (lire) ne vérifie ni schéma ni taille, et TardisSauvegarde.lua:106-113 (ecrire) n'a pas de taille maximale. Des vérifications au cas par cas existent chez les appelants : init.server.lua:2128 (cf doit être une table), 2142-2146 (historique : seulement #h >= 4, pas de plafond de 10 au chargement), 2147 (échelle bornée) ; TardisExtras.server.lua:644-647 (roles), 745-751 (stats), 1100-1102 (carnet), 1448-1470 (reglages) ; prefs limitées à 6000 caractères à l'entrée (TardisExtras:1121). Il reste deux failles. (1) versCFrame(donnees.cf) (init.server.lua:2104) n'est pas protégé : si les 12 composantes ne sont pas des nombres, l'erreur interrompt le script. Le pont interne (init.server.lua:2189) n'est alors jamais créé, et TardisExtras et TardisSystemes tombent en panne. (2) stats.passagers grossit sans limite (TardisExtras:790).
- **Fichiers :** `src/ServerScriptService/TardisSauvegarde.lua`, `src/ServerScriptService/TardisServeur/init.server.lua`, `src/ServerScriptService/TardisExtras.server.lua`, `outils/simulation/sim_modules.py`
- **Dépend de :** —
- **Dans Studio :** —
- **Feuille de route :** La V9 déplacera la sauvegarde dans son dossier Sauvegarde, et la V10 changera peut-être les clés si chaque pilote a son TARDIS. Mettre le schéma dans le module TardisSauvegarde, et non dans les appelants, rend ce déplacement facile.
- **Effort :** moyen · **Risque :** faible
- **Approche :** Dans TardisSauvegarde : ajouter une taille maximale vérifiée avec HttpService:JSONEncode dans ecrire (refus et avertissement au-delà, par exemple 200 000 caractères, bien sous la limite de 4 Mo d'un DataStore), et un paramètre schema facultatif dans lire(cle, schema) qui renvoie nil et un avertissement si les données ne correspondent pas. Côté TardisServeur : appeler charger() avec pcall, vérifier que cf contient 12 nombres finis, que précédent.nom est un texte, et ramener l'historique à 10 entrées. Côté TardisExtras : plafonner passagers, par exemple à 200. Ajouter dans sim_modules.py des cas « sauvegarde corrompue » et « trop grosse ».

## V7.1 — Sécurité : garde-barrière unique et pont interne

### 156. Garde-barrière unique pour le RemoteEvent

*Une seule liste des actions permises, avec qui peut les envoyer.*

- **Déjà fait :** partiel — Trois OnServerEvent séparés sur le même RemoteEvent, chacun avec ses contrôles écrits à la main : src/ServerScriptService/TardisServeur/init.server.lua:1735 (≈48 actions, droits pilote / porteur / vol libre / copilote), TardisExtras.server.lua:1116 (≈34 actions), TardisSystemes.server.lua:1226 (≈8 actions, dont Tech qui a ses sous-commandes à TardisSystemes:1122). Il existe déjà deux listes partielles : ACTIONS_COPILOTE (init.server.lua:1684) et Config.Maintenance.Bloquees (TardisConfig.lua:532). Une action inconnue est ignorée sans rien dire par les trois scripts, mais aucune liste unique ne dit qui peut envoyer quoi. outils/simulation/analyse.py:167-178 compare déjà les actions envoyées par les clients à celles que traitent les serveurs.
- **Fichiers :** `src/ServerScriptService/TardisGarde.lua (nouveau ModuleScript)`, `src/ServerScriptService/TardisServeur/init.server.lua`, `src/ServerScriptService/TardisExtras.server.lua`, `src/ServerScriptService/TardisSystemes.server.lua`, `outils/simulation/analyse.py`
- **Dépend de :** —
- **Dans Studio :** Rien à construire. Le nouveau ModuleScript est créé par outils/synchro_studio.luau (il crée les scripts qui manquent).
- **Feuille de route :** Aucun conflit bloquant. La V10 (un TARDIS par pilote) changera la règle « qui est pilote de ce TARDIS » : il faut donc la mettre dans une seule fonction du module. La V11 remplacera les envois du menu T et de la tablette Y par la console : la liste devra suivre, et le garde-barrière est l'endroit à réutiliser pour les boutons de la console. La V9 (un seul point d'entrée) pourra garder le module tel quel. L'utilisateur a refusé les n° 158 (limite de fréquence par action) et 164 (compteur de refus) : il ne faut donc ajouter ni nouvelle limite ni compteur. On garde les délais qui existent déjà (Config.Cooldown, 0,5 s dans Extras, 2 s pour la maintenance, 0,25 s pour Tech, 3 s pour le carnet), et les refus ne sont écrits qu'en Config.Debug.
- **Effort :** moyen · **Risque :** moyen
- **Approche :** Créer TardisGarde.lua avec une table ACTIONS[nom] = { qui = "pilote"|"copilote"|"porteur"|"volLibre"|"technicien"|"tous", script = "Serveur"|"Extras"|"Systemes" } et une fonction Garde.autoriser(joueur, action, def, exterieur). Elle lit les attributs posés par le serveur (TardisPilote_<Nom>, TardisTechnicien_<Nom>, Copilote, Porteur, VolLibre) et renvoie ok ou une raison. Chacun des trois OnServerEvent l'appelle en première ligne : une action absente de la table est refusée partout, et les contrôles déjà en place restent tant qu'ils n'ont pas été vérifiés comme équivalents. Ajouter à analyse.py un contrôle « action envoyée mais absente de la table du garde ».

### 170. Mode verrouillé d'urgence

*Une option qui coupe toutes les commandes en un réglage si un exploit est découvert.*

- **Déjà fait :** rien — Aucun interrupteur général. Le plus proche est Config.Maintenance (TardisConfig.lua:528-534, vérifié par Config.bloqueParMaintenance, TardisConfig.lua:827). Il ne vaut que pour un TARDIS, ne bloque que les voyages, se lève depuis le jeu, et ne touche ni les ProximityPrompts (une vingtaine de Triggered et Touched dans les scripts serveur, par exemple promptRamasser à init.server.lua:2062) ni TardisErreursClient (TardisSupervision:214).
- **Fichiers :** `src/ReplicatedStorage/TardisConfig.lua`, `src/ServerScriptService/TardisGarde.lua`, `src/ServerScriptService/TardisServeur/init.server.lua`, `src/ServerScriptService/TardisExtras.server.lua`, `src/ServerScriptService/TardisSystemes.server.lua`, `src/ServerScriptService/TardisSupervision.server.lua`
- **Dépend de :** 156
- **Dans Studio :** —
- **Feuille de route :** Pas de commande de chat ni de rôle staff pour l'activer, puisque ce sont des fonctions retirées. Ce sera donc un réglage de Config, ou un attribut du serveur posé depuis la barre de commande serveur de la console développeur. La V11 ajoutera les boutons de la console : ils devront passer par le même contrôle (c'est le cas automatiquement s'ils passent par le garde-barrière).
- **Effort :** petit · **Risque :** faible
- **Approche :** Ajouter Config.Securite = { Verrouille = false } et une fonction Config.verrouille(), qui renvoie vrai si ce réglage est vrai ou si l'attribut ReplicatedStorage « TardisVerrouille » posé par le serveur l'est. Ainsi on peut tout couper en direct sans republier : game.ReplicatedStorage:SetAttribute("TardisVerrouille", true) dans la console serveur. Garde.autoriser (n° 156) refuse alors toute action avec le message « TARDIS verrouillé (sécurité) ». Ajouter la même vérification en tête des gestionnaires de ProximityPrompt (levier, sélecteur, ramassage...) et de TardisErreursClient.

### 172. Pont interne en table

*Remplacer la chaîne de elseif par une table de fonctions.*

- **Déjà fait :** rien — Le pont est encore une chaîne de 19 « elseif action == … » (PROPOSITIONS.md en annonçait 17) : TardisServeur/init.server.lua:2189-2213 (pont.OnInvoke). Il est appelé par interne() dans TardisExtras.server.lua:29 et TardisSystemes.server.lua:22 (74 appels interne() ou pont:Invoke() au total), et par autrePont dans TardisSystemes.server.lua:489. L'analyse statique lit la chaîne de elseif : outils/simulation/analyse.py:235-243 (vérification 7, regex « action == "(\w+)" » jusqu'à « return nil »).
- **Fichiers :** `src/ServerScriptService/TardisServeur/init.server.lua`, `outils/simulation/analyse.py`
- **Dépend de :** 169
- **Dans Studio :** —
- **Feuille de route :** La V9 prévoit « un seul point d'entrée » : les scripts ne se parleront plus par BindableFunction, donc le pont TardisInterne disparaîtra. Le travail ne durera pas longtemps, mais la table de fonctions deviendra directement l'interface publique du futur module Voyage, ce qui facilite la V9. La proposition 169 (Bindables protégés, V7) touche exactement les mêmes lignes.
- **Effort :** petit · **Risque :** faible
- **Approche :** Le faire en même temps que la proposition 169, en V7 : une table ACTIONS_INTERNES = { decoller = decoller, estPilote = function(j) return pilotes[j] == true end, … }. OnInvoke vérifie que action est une chaîne connue de la table et refuse le reste (c'est aussi la liste blanche de la 169), puis appelle ACTIONS_INTERNES[action](...). Garder les mêmes valeurs de retour (true pour les actions sans résultat, etat renvoie 2 valeurs). Mettre à jour analyse.py (vérification 7) pour lire les clés de la table au lieu des « action == ».

### 169. Bindables protégés

*Les BindableFunction internes renommées et vérifiées.*

- **Déjà fait :** partiel — Les Bindables du serveur sont déjà dans ServerStorage, qu'aucun client ne peut voir : le pont TardisInterne_<Nom> (init.server.lua:2190-2192), TardisEvenements (TardisSupervision.server.lua:33) et TardisBaliseDiffusion (TardisExtras.server.lua:103). Le pont renvoie nil pour une action inconnue (init.server.lua:2213), mais il ne vérifie pas les arguments (decoller, atterrir, setEtat... les reçoivent tels quels). Une BindableFunction ne peut pas savoir quel script l'appelle. Les deux Bindables de ReplicatedStorage (TardisCommandes.lua:30, TardisUI.lua:516) sont créés et utilisés seulement côté client.
- **Fichiers :** `src/ServerScriptService/TardisServeur/init.server.lua`, `src/ServerScriptService/TardisExtras.server.lua`, `src/ServerScriptService/TardisSystemes.server.lua`
- **Dépend de :** 172
- **Dans Studio :** —
- **Feuille de route :** Conflit direct avec la feuille de route. Le n° 172 (V8) réécrit ce même pont en table, et la V9 (un seul point d'entrée) le supprime : « On n'a plus de scripts qui se parlent par RemoteEvent et BindableFunction ». Renommer les Bindables ne protège de rien, car seul un script serveur (par exemple une porte dérobée dans un modèle gratuit) peut les atteindre, et un tel script a de toute façon tous les droits.
- **Effort :** petit · **Risque :** faible
- **Approche :** Ne pas renommer (cacher le nom ne protège pas). Au moment du n° 172, donner à chaque entrée de la table du pont la liste des types attendus pour ses arguments, par exemple atterrir = { fn, "CFrame", "string", ... }, et refuser l'appel si un type ne correspond pas, avec un warn. Le faire avec le n° 172 évite d'écrire deux fois le même code avant que la V9 ne supprime le pont.

### 194. Mode lecture seule clair

*Les visiteurs voient clairement ce qu'ils peuvent et ne peuvent pas faire.*

- **Déjà fait :** partiel — Une tablette en lecture seule est donnée aux non-pilotes à bord : TardisExtras.server.lua:153-170 et 205-206, interface dans TardisExtrasClient/TabletteLecture.lua:13-16 (titre « LECTURE SEULE », état, carte, lieux). Elle n'explique jamais ce que le visiteur peut ou ne peut pas faire. Les prompts de la console sont visibles par tous mais ignorent les non-pilotes sans rien dire (init.server.lua:1057 et 1068 : « if not pilotes[joueur] then return end »). TardisExtras refuse aussi sans message (TardisExtras.server.lua:1220-1222, simple print de debug). À l'entrée, le visiteur déclenche l'alerte INTRUSION chez les pilotes, mais il ne reçoit lui-même aucune explication (TardisExtras.server.lua:207-211).
- **Fichiers :** `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/TabletteLecture.lua`, `src/ServerScriptService/TardisExtras.server.lua`, `src/ServerScriptService/TardisServeur/init.server.lua`, `src/ReplicatedStorage/TardisConfig.lua`
- **Dépend de :** 156
- **Dans Studio :** —
- **Feuille de route :** En V11, toutes les commandes passent sur la console : des boutons physiques visibles par tous. C'est là que le besoin d'un retour clair aux visiteurs devient fort. La tablette en lecture seule pourrait être remplacée par les écrans de console de la V11.1 (question ouverte). Le message de refus trouve naturellement sa place dans le garde-barrière unique de la V7 (n°156).
- **Effort :** petit · **Risque :** faible
- **Approche :** 1) À la V7, dans le garde-barrière unique (n°156), renvoyer au non-pilote un message bref (« Réservé aux pilotes de la C.A.T. ») au lieu d'un refus silencieux, avec une limite de fréquence. 2) À la V11, pour chaque bouton et prompt de la console, côté client : ObjectText « Réservé aux pilotes » ou prompt masqué pour les non-pilotes. Ajouter aussi, en tête de la tablette en lecture seule et sur une carte d'accueil à l'entrée, la liste « Vous pouvez : regarder les écrans, la carte, les casiers… / Vous ne pouvez pas : piloter, ouvrir les portes… », tirée de Config selon le rôle (visiteur ou technicien).

## V7.2 — Sécurité : schéma des données et tests de triche

### 157. Schéma de données par action

*Types, bornes et longueurs vérifiés pour chaque action.*

- **Déjà fait :** partiel — Des vérifications existent, mais au cas par cas et pas pour toutes les actions : Taille, avec facteur nombre et pas NaN (init.server.lua:1922-1923) ; Repositionner, avec position de type CFrame (init.server.lua:1964) ; Bouclier, avec type texte (init.server.lua:2003-2004) ; Prefs, texte de 6000 caractères au plus et JSON valide (TardisExtras.server.lua:1120-1125) ; Interphone, 120 caractères au plus (TardisExtras.server.lua:1158) ; carnet, longueur en UTF-8 (TardisExtras.server.lua:1214) ; TenuesCompte, 50 identifiants entiers au plus (TardisSystemes.server.lua:1269-1276) ; Reguler, valeur bornée de 0 à 100 (TardisSystemes.server.lua:1130-1132). Ailleurs, beaucoup de champs passent sans contrôle de type : donnees.joueur (Promouvoir, Bannir), donnees.mode, donnees.index, donnees.raison...
- **Fichiers :** `src/ServerScriptService/TardisGarde.lua`, `src/ServerScriptService/TardisServeur/init.server.lua`, `src/ServerScriptService/TardisExtras.server.lua`, `src/ServerScriptService/TardisSystemes.server.lua`
- **Dépend de :** 156
- **Dans Studio :** —
- **Feuille de route :** Ce point recoupe les n° 162 (nombres invalides refusés partout) et 163 (textes filtrés et bornés partout), que l'utilisateur a refusés. Le schéma doit donc rester par action : il vérifie le type, les bornes et la longueur de chaque champ attendu (une borne « min ≤ x ≤ max » refuse déjà NaN). Il ne faut pas ajouter de filtre général sur les nombres ni étendre le filtre des textes. Les actions des boutons du menu T et de la tablette Y changeront en V11 : il faudra mettre leurs schémas à jour, sans rien jeter.
- **Effort :** gros · **Risque :** moyen
- **Approche :** Ajouter à chaque entrée de ACTIONS (n° 156) un champ schema, par exemple { facteur = { "number", 0.25, 1 }, mode = { "string", 0, 20 }, position = "CFrame" }, et une fonction Garde.valider(schema, donnees) qui refuse les types inattendus, les valeurs hors bornes, les textes trop longs et les tables trop grandes. Il y a environ 90 actions, sous-commandes de Tech comprises. Le gros du travail est de relire chaque action pour écrire son schéma sans casser ce que le client envoie vraiment : se servir des FireServer listés par analyse.py.

### 167. Simulations de triche

*De nouveaux tests qui envoient de fausses requêtes et vérifient qu'elles sont refusées.*

- **Déjà fait :** partiel — Les simulations existent (outils/simulation/lancer.sh, luau.py, roblox.py avec un faux FireServer à roblox.py:331). sim_supervision.py vérifie que de fausses commandes de chat (« /tardis statut », « /tardis maintenance on »...) ne font rien, et sim_modules.py:138 et 149 vérifie des refus côté TardisCommandes. Aucune simulation n'envoie de fausse requête aux OnServerEvent : TardisServeur, TardisExtras et TardisSystemes ne sont jamais chargés dans les simulations (monde.py ne prépare que TardisConfig, TardisUI, TardisCommandes et TardisSauvegarde).
- **Fichiers :** `outils/simulation/sim_securite.py (nouveau)`, `outils/simulation/monde.py`, `outils/simulation/lancer.sh`, `outils/simulation/LISEZMOI.md`
- **Dépend de :** 156, 157, 170, 185
- **Dans Studio :** —
- **Feuille de route :** aucun conflit
- **Effort :** moyen · **Risque :** faible
- **Approche :** Puisque le n° 156 met le contrôle dans un ModuleScript sans état (TardisGarde), le tester directement dans sim_securite.py, sans charger les gros scripts serveur. Lui envoyer une batterie de requêtes de « tricheur » : action inconnue, visiteur qui demande Demat, copilote qui demande Taille, faux porteur pour Poser, NaN, infini, texte de 10 000 caractères, table géante, UserId inventé, mode verrouillé (n° 170). Vérifier que chaque requête est refusée et que les vraies requêtes passent. L'essai de bout en bout sur TardisServeur viendra avec le n° 185, si l'interpréteur luau.py sait le charger.

## V8 — Nettoyage : journal, mesure et code mort

### 175. Journal à niveaux

*Info, avertissement, debug, à la place des print épars.*

- **Déjà fait :** partiel — Un seul niveau existe : Config.Debug = false dans TardisConfig.lua:202, utilisé seulement dans TardisExtras.server.lua:1117, :1221, :1232 et :1525. Il y a environ 40 print/warn éparpillés, tous déjà préfixés « [TARDIS] » (par exemple TardisServeur/init.server.lua:44, :2166, :2218 ; TardisSauvegarde.lua:60-108 ; TardisSystemes.server.lua:455-566). Le journal de jeu à catégories (RoSysLog) est une autre chose : journal() dans TardisServeur/init.server.lua:246 et TardisExtras.server.lua:44, journaliser() dans TardisSupervision.server.lua:133, avec Config.Journal.Output. Attention : TardisExtrasClient/Supervision.lua relève les avertissements qui commencent par « [TARDIS] » pour les remonter au serveur.
- **Fichiers :** `src/ReplicatedStorage/TardisConfig.lua`, `src/ServerScriptService/TardisServeur/init.server.lua`, `src/ServerScriptService/TardisExtras.server.lua`, `src/ServerScriptService/TardisSystemes.server.lua`, `src/ServerScriptService/TardisSupervision.server.lua`, `src/ServerScriptService/TardisSauvegarde.lua`, `src/ServerScriptService/TardisDiagnostic.lua`, `src/ServerScriptService/TardisPontFondation.server.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisPortail.client.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisCamera.client.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisEffets.client.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Supervision.lua`
- **Dépend de :** —
- **Dans Studio :** —
- **Feuille de route :** Aucun. La V7 (refus du garde-barrière « notés ») pourrait déjà s'en servir. Si les journaux de refus de la V7 doivent être propres, on peut faire cette proposition au tout début de la V7. La proposition 181 (Mesure du coût par module, en debug) en dépend.
- **Effort :** petit · **Risque :** faible
- **Approche :** Dans TardisConfig : Config.NiveauJournal = "info" ("debug" remplace Config.Debug = true, garder une compatibilité) et une fonction Config.log(niveau, source, message) qui écrit « [TARDIS] [source] message » avec print, ou warn à partir du niveau avertissement. Garder le préfixe « [TARDIS] » sur les avertissements pour ne pas casser la remontée des erreurs de Supervision.lua. Remplacer les environ 40 print/warn un par un. Ne pas fusionner avec journal()/journaliser() (RoSysLog), qui reste le journal RP par catégorie.

### 181. Mesure du coût par module

*Un compteur de temps par module en mode debug.*

- **Déjà fait :** rien — Aucun chronométrage n'existe. Config.Debug existe (src/ReplicatedStorage/TardisConfig.lua:202), mais il ne sert qu'à afficher les commandes reçues par TardisExtras (TardisExtras.server.lua:1117, 1221, 1232). Aucun os.clock() ni debug.profilebegin autour des boucles par image. Les modules client reçoivent RunService par leur contexte (TardisExtrasClient/init.client.lua:78-110), ce qui permet de les chronométrer sans les réécrire.
- **Fichiers :** `src/ReplicatedStorage/TardisConfig.lua`, `src/ReplicatedStorage/TardisUI.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/init.client.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisEffets.client.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisVolLibre.client.lua`, `src/ServerScriptService/TardisExtras.server.lua`, `src/ServerScriptService/TardisSystemes.server.lua`
- **Dépend de :** 175
- **Dans Studio :** Rien à construire. Il faut juste passer Config.Debug (ou Config.Mesure) à true pour un test, et lire l'Output ou le MicroProfiler.
- **Feuille de route :** Ne pas instrumenter TardisMenu ni TardisTablette (supprimés en V11). La V9 crée un point d'entrée unique : l'outil doit vivre dans un module partagé, pour que seul l'endroit où on le branche change.
- **Effort :** petit · **Risque :** faible
- **Approche :** Ajouter un petit utilitaire partagé, mesure(nom, signal, fonction) : il connecte la fonction et, si Config.Debug est actif, cumule os.clock() par nom et entoure l'appel de debug.profilebegin/profileend. Un résumé (ms par seconde, par module) s'affiche toutes les 30 s par le journal à niveaux (175). Côté client, on passe aux modules un RunService « mesuré » par le chargeur. Côté serveur, on enveloppe les Heartbeat (TardisExtras:592 et :767, TardisSystemes:1007). C'est à faire en tout premier dans la V8, pour avoir un « avant » à comparer.

### 176. Code mort supprimé

*Paramètres et outils qui ne servent plus depuis les retraits de V6.9.4 et V6.9.5.*

- **Déjà fait :** partiel — Les retraits des V6.9.4 et V6.9.5 sont propres pour l'essentiel : il ne reste ni Config.Cle, ni CriseDuree, ni Config.Recette, ni TardisStaff, ni TardisMessageStaff, et les simulations le vérifient (outils/simulation/sim_config.py:62-64, sim_supervision.py:29 et :38). Restes morts trouvés : Config.NomExterieur et Config.NomInterieur (TardisConfig.lua:13-14), jamais lus. Config.Journal.Taille (TardisConfig.lua:484), qui ne servait qu'à /tardis journal, retiré. Les fiches d'erreurs de TardisSupervision.server.lua:189-204 (compte, joueurs, premier, dernier), qui n'étaient lues que par /tardis erreurs. La TextChatCommand de la balise, toujours nommée « TardisCommandeStaff » (TardisSupervision.server.lua:253-254). Des commentaires obsolètes : TardisConfig.lua:481, :484, :491 (/tardis journal, /tardis erreurs), TardisExtras.server.lua:109-110, TardisExtrasClient/init.client.lua:151 (« réponses du staff »).
- **Fichiers :** `src/ReplicatedStorage/TardisConfig.lua`, `src/ServerScriptService/TardisSupervision.server.lua`, `src/ServerScriptService/TardisExtras.server.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/init.client.lua`, `outils/simulation/sim_config.py`
- **Dépend de :** —
- **Dans Studio :** —
- **Feuille de route :** Ne pas supprimer ce qui est seulement en pause et ressemble à du code mort : le bloc Config.Intercom en commentaire, TardisPontFondation et Intercom.lua (intégration OS Fondation en pause), ni la balise /tardis help, qui est encore active. RangMin n'est pas mort : il est lu dans TardisServeur/init.server.lua:341.
- **Effort :** petit · **Risque :** faible
- **Approche :** Supprimer NomExterieur/NomInterieur et Journal.Taille. Réduire noterErreur à l'anti-doublon (une clé vue = une ligne au journal, plafond de 100). Renommer la TextChatCommand en « TardisBaliseChat » (elle est créée au lancement, rien à faire dans Studio). Corriger les commentaires. Ajouter des tests « absent » dans sim_config. Ensuite, chercher les fonctions locales jamais appelées en ajoutant à analyse.py une vérification « local function déclarée, jamais utilisée », puis relancer sh outils/simulation/lancer.sh.

### 183. Configuration validée au démarrage

*Une vérification des réglages avec un message clair en cas d'erreur.*

- **Déjà fait :** partiel — TardisDiagnostic.lua:31-94 (appelé depuis TardisServeur/init.server.lua:2222) vérifie au démarrage les pièces, les sons et les destinations, mais pas les valeurs de réglage. outils/simulation/sim_config.py:14-65 vérifie une partie de la configuration (6 modes, Timing > 0, Alpha entre 0 et 1, équipes, réglages retirés), mais seulement hors jeu. TardisConfig.lua ne contient ni assert ni fonction de validation. Une erreur de frappe dans Config.Tardis (:312), Config.Modes ou Config.Sons (:459) ne produit aucun message en jeu.
- **Fichiers :** `src/ReplicatedStorage/TardisConfig.lua`, `src/ServerScriptService/TardisDiagnostic.lua`, `src/ServerScriptService/TardisServeur/init.server.lua`, `outils/simulation/sim_config.py`
- **Dépend de :** 175
- **Dans Studio :** Rien à construire.
- **Feuille de route :** La V9 découpe TardisConfig en un module par domaine : il faut écrire la vérification comme une liste de règles par domaine (facile à déplacer), pas comme un bloc unique. La V10 ajoutera la règle « un pilote dans un seul TARDIS » : prévoir l'emplacement, sans l'écrire maintenant.
- **Effort :** petit · **Risque :** faible
- **Approche :** Ajouter une fonction verifierConfig() (dans TardisDiagnostic ou dans un petit module voisin) qui renvoie la liste des problèmes en français : noms de Config.Tardis uniques et dossiers présents, UserIds numériques, chaque mode avec Sons, Durees > 0 et Couleur, identifiants de Config.Sons et de Config.Tenues valides, Cooldown et nombres positifs. Elle est appelée une fois au démarrage à côté du diagnostic : un warn par problème, sans jamais arrêter le script. Ajouter dans sim_config.py un test avec une configuration valide (0 problème) et une configuration cassée (message attendu).

## V8.1 — Sons : liste unique et volumes par catégorie

### 173. Liste des sons partagée

*Une seule liste entre le serveur et le préchargement client.*

- **Déjà fait :** partiel — Le préchargement côté client ne recopie pas de liste : il précharge tout le dossier, avec PreloadAsync(sons:GetChildren()), à TardisEffets.client.lua:148-157. La duplication est ailleurs. Liste du serveur : LISTE_SONS dans TardisServeur/init.server.lua:72-77 (Camouflage, Decamouflage, Cloitre, Reparation + Config.Modes). Liste du diagnostic : SONS_OPTIONNELS dans TardisDiagnostic.lua:24-25, plus sa propre boucle sur Config.Modes (lignes 62-65). Liste des sons créés : Config.Sons dans TardisConfig.lua:459-465. Noms écrits en dur dans le client : Ambiance.lua:195 (Moteur_*), Ambiance.lua:210 (Alarme), Regeneration.lua:567, AutoDestruction.lua:24 (Cloitre), Intercom.lua:30, TardisVolLibre.client.lua:380 (Chute, Impact).
- **Fichiers :** `src/ReplicatedStorage/TardisConfig.lua`, `src/ServerScriptService/TardisServeur/init.server.lua`, `src/ServerScriptService/TardisDiagnostic.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisEffets.client.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Ambiance.lua`
- **Dépend de :** —
- **Dans Studio :** —
- **Feuille de route :** Aucun. La proposition 182 (Préchargement intelligent, gardée) s'appuiera sur cette liste, et la 132 (Banque de sons dans TardisAssets) en utilisera les noms : il vaut mieux faire la 173 avant ces deux-là.
- **Effort :** petit · **Risque :** faible
- **Approche :** Ajouter dans TardisConfig une fonction Config.listeSons() qui renvoie, sans doublons, { nom, optionnel, joueSur = "serveur"|"client", precharger } à partir de Config.Modes et d'une table de sons connus (fusion de LISTE_SONS et SONS_OPTIONNELS). Le serveur l'utilise pour preparerSon, TardisDiagnostic pour compter les sons, et le client ne précharge que les noms marqués precharger au lieu de tout le dossier. Les simulations (sim_config) peuvent vérifier que chaque son de Config.Modes et de Config.Sons figure dans la liste.

### 132. Banque de sons dans TardisAssets

*Tous les sons rangés et nommés dans ReplicatedStorage › TardisAssets › Sons.*

- **Déjà fait :** partiel — src/ReplicatedStorage/TardisConfig.lua:456-464 (Config.Sons : sons créés au démarrage dans TardisAssets › Sons, un Sound placé à la main reste prioritaire) ; src/ServerScriptService/TardisServeur/init.server.lua:53-67 (création) et :70-84 (LISTE_SONS, 2e liste) ; src/ServerScriptService/TardisDiagnostic.lua:23-25 (SONS_OPTIONNELS, 3e liste) ; src/StarterPlayer/StarterPlayerScripts/TardisVolLibre.client.lua:394 (son « Moteur » du vol libre, présent dans AUCUNE liste ni dans le diagnostic) ; Ambiance.lua:210 (« Alarme » absent de Config.Sons) ; la recherche du son est recopiée 8 fois (Ambiance.lua:196, Regeneration.lua:567, AutoDestruction.lua:24, Intercom.lua:30, TardisVolLibre.client.lua:378-381, init.server.lua:41...)
- **Fichiers :** `src/ReplicatedStorage/TardisConfig.lua`, `src/ServerScriptService/TardisServeur/init.server.lua`, `src/ServerScriptService/TardisDiagnostic.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisEffets.client.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisVolLibre.client.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Ambiance.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Regeneration.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/AutoDestruction.lua`
- **Dépend de :** —
- **Dans Studio :** Placer dans ReplicatedStorage › TardisAssets › Sons les Sound qui n'ont pas d'ID dans Config.Sons (Demat, Remat, Demat_Urg, Remat_Urg, Demat_Express, Remat_Express, Alarme, Moteur), ou donner leurs ID pour Config.Sons. Vérifier dans la Toolbox que les ID sont publics. Rien à construire en 3D.
- **Feuille de route :** Aucun conflit. C'est presque le même travail que la n°173 (liste des sons partagée), déjà prévue en V8 dans FEUILLE_DE_ROUTE.md : à faire ensemble.
- **Effort :** petit · **Risque :** faible
- **Approche :** Transformer Config.Sons en LA liste unique : chaque nom (sons de voyage de chaque mode, Alarme, Moteur, Chute, Impact, et plus tard Vortex, Bip_Console, Panne_*) avec Id (0 = à placer à la main), Volume, Categorie et Optionnel. Ajouter un utilitaire Config.sonModele(nom) qui remplace les 8 FindFirstChild recopiés ; LISTE_SONS du serveur, SONS_OPTIONNELS du diagnostic et le préchargement client lisent tous cette table. Le comportement en jeu ne change pas.

### 182. Préchargement intelligent

*Charger les sons et images au premier besoin plutôt qu'au démarrage.*

- **Déjà fait :** partiel — src/StarterPlayer/StarterPlayerScripts/TardisEffets.client.lua:149-157 précharge déjà en tâche de fond (task.spawn + PreloadAsync) TOUS les sons de TardisAssets.Sons au démarrage. Mais le serveur crée les sons de Config.Sons au démarrage (TardisServeur/init.server.lua:55-66), donc ceux qui arrivent après le préchargement du client n'en profitent pas. Le jukebox (TardisExtrasClient/Ambiance.lua:240) et l'ambiance (Signalisation.lua:234) créent déjà leur Sound au premier besoin, sans préchargement. Il n'y a aucune image personnalisée à charger : les textures sont celles intégrées à Roblox (rbxasset://).
- **Fichiers :** `src/StarterPlayer/StarterPlayerScripts/TardisEffets.client.lua`, `src/ServerScriptService/TardisServeur/init.server.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Ambiance.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Signalisation.lua`, `src/ReplicatedStorage/TardisConfig.lua`
- **Dépend de :** 173, 132
- **Dans Studio :** Rien à construire. Si 132 est faite, il faut ranger les Sound dans ReplicatedStorage › TardisAssets › Sons.
- **Feuille de route :** aucun conflit
- **Effort :** petit · **Risque :** faible
- **Approche :** Il ne faut pas tout passer au chargement à la demande : le commentaire de TardisEffets rappelle que le premier son de voyage arrivait en retard. On prévoit deux niveaux, à partir de la liste partagée (173). Les sons de voyage et d'alarme sont préchargés quand le joueur est pilote ou technicien, ou quand il s'approche du TARDIS, et aussi quand le serveur ajoute un son (ChildAdded sur Sons). Les autres (jukebox, ambiance, régénération) sont préchargés juste avant leur premier usage. Le gain est modeste, parce que le préchargement actuel ne bloque déjà rien.

### 82. Sons d'interface désactivables par type

*Couper séparément les bips, les alertes et les confirmations.*

- **Déjà fait :** partiel — Un interrupteur global existe : TardisUI.lua:621-622 (UI.son ne joue rien si pref « sons » = false), réglé dans TardisTablette/Volet.lua:235-240 (« Sons de notification : activés / coupés »). Il n'existe que deux types, Config.SonsInterface (TardisConfig.lua:257 : Notification, Alerte), sans catégorie bip ni confirmation. « Notification » sert à la fois de bip du compte à rebours (Signalisation.lua:48), de confirmation de commande (TardisMenu.client.lua:323, TardisTablette/Etat.lua:50) et de son d'ouverture (Ouverture.lua:87, TardisMenu.client.lua:619)
- **Fichiers :** `src/ReplicatedStorage/TardisUI.lua`, `src/ReplicatedStorage/TardisConfig.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisTablette/Volet.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisTablette/Etat.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisMenu.client.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Signalisation.lua`, `src/ReplicatedStorage/TardisCommandes.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Copilote.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Interactions.lua`
- **Dépend de :** —
- **Dans Studio :** —
- **Feuille de route :** Le filtrage, dans TardisUI.son, survit à la V11. En revanche, la page Réglages qui porte les interrupteurs est dans la tablette Y, retirée en V11.4 : il faudra lui trouver une autre place (question ouverte de la feuille de route). Il recoupe aussi la n° 133 (volume par catégorie) et la n° 173 (liste des sons partagée, V8) : mieux vaut définir les catégories une seule fois.
- **Effort :** petit · **Risque :** faible
- **Approche :** Donner à UI.son une catégorie : Bip, Alerte, Confirmation, Ouverture, chacune liée à un type de Config.SonsInterface. Remplacer la pref booléenne « sons » par une table prefs.sonsCoupes[categorie], en gardant « sons = false » comme « tout couper » pour les préférences déjà sauvegardées. Reclasser les 17 appels UI.son (bip du compte à rebours = Bip, résultat de commande = Confirmation ou Alerte, ouverture des menus = Ouverture). Dans Volet.lua, remplacer la ligne unique par un interrupteur par catégorie. À faire en même temps que la n° 133 si elle est programmée.

### 133. Volume par catégorie

*Volumes séparés : voyages, moteur, alarmes, jukebox, interface.*

- **Déjà fait :** partiel — Un seul volume global : src/ReplicatedStorage/TardisUI.lua:533-536 (UI.volume) ; src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Preferences.lua:10-34 (multiplie le volume de tous les Sound de l'extérieur et de l'intérieur) ; src/StarterPlayer/StarterPlayerScripts/TardisTablette/Volet.lua:140-152 (5 boutons 0-100 %) ; volume recalculé à la main dans Ambiance.lua:274 (moteur) et :293 (jukebox), et dans Signalisation.lua:244 (ambiance). Les sons d'interface ignorent ce volume (TardisUI.lua:620-638 : seulement activés ou coupés, préférence « sons »). Défaut trouvé : le moteur du vol libre impose son volume à chaque image (TardisVolLibre.client.lua:410-411, e.moteur.Volume = 0.3 + 0.6 * f), donc il ignore le réglage de volume.
- **Fichiers :** `src/ReplicatedStorage/TardisUI.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Preferences.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Ambiance.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Signalisation.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisVolLibre.client.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisTablette/Volet.lua`, `src/ReplicatedStorage/TardisConfig.lua`
- **Dépend de :** 132
- **Dans Studio :** —
- **Feuille de route :** Le réglage est affiché dans la tablette Y (Volet.lua, Réglages), que la V11.4 supprime. Un volume est propre à chaque joueur : il ne peut pas aller sur la console, qui est partagée. La V11.4 doit donc garder un petit panneau de réglages personnels (question encore ouverte dans FEUILLE_DE_ROUTE.md). Recoupe aussi la n°82 (sons d'interface par type). C'est un changement visible, à signaler dans les notes de la V8, qui promet un comportement identique.
- **Effort :** moyen · **Risque :** faible
- **Approche :** Côté client, créer 5 SoundGroup dans SoundService (Voyages, Moteur, Alarmes, Jukebox, Interface) et ranger chaque Sound dans le sien d'après sa Categorie dans la banque de la n°132. Le volume du groupe vaut volume_<catégorie> × UI.volume(). Retirer les multiplications faites à la main (Preferences, Ambiance, Signalisation, moteur du vol libre) pour ne pas baisser le son deux fois. Dans Volet.lua, ajouter 5 lignes de boutons, sauvegardées par UI.setPref comme le volume d'aujourd'hui.

## V8.2 — Code partagé et ordre des fonctions

### 171. Utilitaire unique pour les raycasts

*Une seule fonction pour la liste d'exclusion, recopiée 5 fois aujourd'hui.*

- **Déjà fait :** partiel — Aucun utilitaire partagé. Côté serveur, la même liste « { exterieur, interieur } + personnages de tous les joueurs » est recopiée 7 fois : TardisServeur/init.server.lua:540 (chercherSol), :557 (verifierEau), :642 (test de collision, OverlapParams) ; TardisServeur/VolLibre.lua:193 ; TardisSystemes.server.lua:962 et :982 ; TardisExtras.server.lua:577. Côté client, deux scripts ont déjà leur propre petit utilitaire local, mais chacun le sien : TardisVolLibre.client.lua:100 exclusions(...) (4 appels) et TardisEffets.client.lua:565 exclusionsSol() (2 appels). Il reste en plus 5 copies écrites à la main : TardisRotation.client.lua:161 et :319, TardisExtrasClient/EffetsExterieurs.lua:52, TardisTablette/Placement.lua:45 et :123.
- **Fichiers :** `src/ReplicatedStorage/TardisConfig.lua`, `src/ServerScriptService/TardisServeur/init.server.lua`, `src/ServerScriptService/TardisServeur/VolLibre.lua`, `src/ServerScriptService/TardisSystemes.server.lua`, `src/ServerScriptService/TardisExtras.server.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisVolLibre.client.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisEffets.client.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisRotation.client.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/EffetsExterieurs.lua`
- **Dépend de :** —
- **Dans Studio :** Rien si la fonction va dans TardisConfig, qui existe déjà. Créer un nouveau ModuleScript obligerait l'utilisateur à l'ajouter à la main, puisqu'il installe par copier-coller.
- **Feuille de route :** TardisTablette/Placement.lua (2 copies) appartient à la tablette Y, que la V11 retire : il ne faut pas passer de temps dessus, seulement remplacer l'appel si c'est trivial. La V9 déplacera probablement la fonction dans un module « outils » : c'est acceptable.
- **Effort :** petit · **Risque :** faible
- **Approche :** Ajouter dans TardisConfig, à côté de Config.modeles et Config.canal, une fonction Config.exclusionsTardis(exterieur, interieur, ...) qui renvoie la liste avec les personnages de tous les joueurs, plus éventuellement Config.parametresRayon(liste, options) pour RespectCanCollide et IgnoreWater. La liste sert aux RaycastParams comme aux OverlapParams. Remplacer les 7 copies du serveur et les 4 du client, et faire appeler la nouvelle fonction par les deux utilitaires locaux (exclusions, exclusionsSol). Ne pas toucher aux listes différentes, sans les personnages : Signalisation.lua:89, TardisEffets.client.lua:825, Regeneration.lua:130, TardisPortail.client.lua:379.

### 184. Fonctions « définies plus bas » réordonnées

*Supprimer les déclarations anticipées qui ont causé 6 bugs.*

- **Déjà fait :** partiel — outils/simulation/analyse.py:2-3 détecte déjà les fonctions appelées avant leur déclaration (0 remarque aujourd'hui), donc le risque de nouveau bug est déjà surveillé. Mais les déclarations anticipées sont toujours là. Serveur : TardisServeur/init.server.lua:405-408 (dansInterieur défini à :531, dansZoneRefusee à :787 avec la garde « dansZoneRefusee and » à :491, dansZoneSansExpress à :789, ouvrirPortesSimple à :817), :1388 basculerBouclier (défini dans un bloc à :1521) ; TardisExtras.server.lua:26 (6 fonctions, avec la garde « le script n'a pas fini de se charger » à :193). Client : TardisVolLibre.client.lua:276-277 (9 fonctions) et :843 sautTemporel ; Copilote.lua:80, TabletteTechnicien.lua:248 et :352, Interactions.lua:147 ; tablette Y : Navigation.lua:14, Outils.lua:157, 160, 575, 607 et 644, Scanner.lua:13 et 77, Volet.lua:119.
- **Fichiers :** `src/ServerScriptService/TardisServeur/init.server.lua`, `src/ServerScriptService/TardisExtras.server.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisVolLibre.client.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Copilote.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/TabletteTechnicien.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Interactions.lua`
- **Dépend de :** 176, 185
- **Dans Studio :** Rien à construire.
- **Feuille de route :** Ne pas réordonner les modules de la tablette Y (Navigation, Outils, Scanner, Volet) : la V11 les supprime. La V9 découpera TardisServeur et TardisExtras en modules par domaine, ce qui réglera une partie de l'ordre de lui-même : en V8, il faut se limiter aux 11 déclarations serveur et aux 10 de TardisVolLibre, sans grand déménagement.
- **Effort :** petit · **Risque :** moyen
- **Approche :** Après le retrait du code mort (176), remonter dansInterieur, dansZone/dansZoneRefusee/dansZoneSansExpress et ouvrirPortesSimple au-dessus de leur premier usage, puis supprimer les gardes « x and x(...) ». Sortir basculerBouclier de son bloc do. Dans TardisExtras, remonter roleDe, ajouterIncident et surPremiereEntree avant la boucle de :191. Pour les fonctions mutuellement récursives de TardisVolLibre (sautTemporel et deplacer), garder une seule déclaration commentée si l'ordre est impossible. Après chaque déplacement, relancer analyse.py, plus les simulations de 185 si elles existent.

## V8.3 — Boucles par image et effets à distance

### 177. Boucles par image regroupées

*Une seule boucle Heartbeat par TARDIS côté client.*

- **Déjà fait :** rien — Il n'existe aucun répartiteur commun. Environ 25 connexions par image permanentes par TARDIS, dans les scripts clonés une fois par TARDIS (Config.demarrerPourChaqueTardis, TardisConfig.lua:394). TardisEffets.client.lua:239, :678, :1054. TardisPortail.client.lua:307 et :397 (BindToRenderStep, priorité caméra). Dans TardisExtrasClient : Ambiance.lua:171 et :263, Boucliers.lua:38, AutoDestruction.lua:14, Decor.lua:115, Systemes.lua:88, Signalisation.lua:57, :175 et :216, EffetsExterieurs.lua:25, :58 et :192 (plus le BindToRenderStep de la ligne 234), Replay.lua:16 et :66, Intercom.lua:80, TabletteTechnicien.lua:93, :433 et :800. Il n'y a qu'un TARDIS déclaré aujourd'hui (TardisConfig.lua:312-316), donc le gain se multipliera surtout à la V10.
- **Fichiers :** `src/ReplicatedStorage/TardisUI.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/init.client.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisEffets.client.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Ambiance.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Boucliers.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/AutoDestruction.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Decor.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Systemes.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Signalisation.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/EffetsExterieurs.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Replay.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Intercom.lua`, `outils/simulation/analyse.py`
- **Dépend de :** 181
- **Dans Studio :** —
- **Feuille de route :** Ne pas regrouper les boucles des interfaces que la V11 retire : TardisMenu.client.lua:731 et :743, TardisTablette/Suivi.lua:171, et sans doute les boucles d'affichage de TabletteTechnicien.lua:433 et :800 (tablette technicien ouverte par Y : à confirmer si la V11 la retire aussi). Laisser à part les BindToRenderStep liés à la caméra (TardisPortail, TardisCamera, l'impact du vol libre, la secousse) : leur ordre compte. La V9 déplacera le répartiteur dans un module, ce qui ne pose pas de problème.
- **Effort :** moyen · **Risque :** moyen
- **Approche :** Ajouter dans TardisUI, qui est partagé par tous les LocalScripts d'un même client, une fonction UI.chaqueImage(nomTardis, nom, fn, "rendu"|"physique") : une seule connexion RenderStepped et une seule Heartbeat pour tous les TARDIS, avec chaque fonction appelée sous pcall et un avertissement « [TARDIS] » si elle plante. Il faut que la panne d'un effet n'arrête pas les autres. La transmettre aux modules par le contexte (contexte.chaqueImage, que la vérification 6 de analyse.py contrôle déjà), puis convertir les boucles permanentes une par une. Les boucles temporaires (Regeneration.lua:619, TardisEffets.client.lua:917) restent comme elles sont. Mesurer avant et après avec la proposition 181.

### 178. Effets coupés loin du joueur

*Ne rien calculer pour un TARDIS hors de vue.*

- **Déjà fait :** partiel — Seul le portail est coupé à distance : TardisPortail.client.lua:308 (rien si la porte est fermée) et :233 (au-delà de Config.DistanceVueMax = 60, TardisConfig.lua:174). Plusieurs boucles s'arrêtent déjà quand le joueur n'est pas à bord : Ambiance.lua:174, Signalisation.lua:58, TabletteTechnicien.lua:96, Intercom.lua:81. En revanche, aucun test de distance ni de visibilité pour la cabine vue de dehors : la boucle principale de TardisEffets.client.lua:239, la flottaison avec PivotTo à TardisEffets.client.lua:678, Decor.lua:115, Boucliers.lua:38, et EffetsExterieurs.lua:25 et :58 (dont un raycast par image pendant la matérialisation) tournent pour un TARDIS même très loin. Aucun mot-clé DistanceEffets ou WorldToViewportPoint dans src.
- **Fichiers :** `src/ReplicatedStorage/TardisConfig.lua`, `src/ReplicatedStorage/TardisUI.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisEffets.client.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/init.client.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Decor.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Boucliers.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/EffetsExterieurs.lua`
- **Dépend de :** 177, 181
- **Dans Studio :** —
- **Feuille de route :** Pas de conflit, mais le gain n'est réel qu'avec plusieurs TARDIS actifs (V10). Il faut le concevoir pour N TARDIS dès la V8, puis le revérifier à la V10. Les écrans de console de la V11 (SurfaceGui) devront eux aussi être coupés quand le joueur n'est pas à bord : le prévoir dans le même critère.
- **Effort :** moyen · **Risque :** moyen
- **Approche :** Dans le répartiteur de la proposition 177, calculer une fois par image et par TARDIS un niveau de détail : « proche » (joueur à bord avec dansInterieur, pilote ou porteur, ou caméra à moins de Config.DistanceEffets ≈ 400 studs de la Racine), « loin » ou « invisible » (camouflé, Detruit). Les effets décoratifs ne tournent qu'en « proche ». Ce qui donne l'état visible de la cabine (alpha démat/remat, position de flottaison, fin de l'animation) doit au minimum appliquer son état final ou tourner à environ 5 Hz. Sinon une cabine lointaine pourrait rester à moitié transparente ou mal placée. Garder etatPrecedent à jour même quand l'effet est coupé, pour ne pas rejouer un flash au retour. Tester dans Studio avec une démat à 1 000 studs puis en revenant près de la cabine.

### 47. Réduction automatique des effets

*Effets allégés quand les images par seconde baissent.*

- **Déjà fait :** rien — Seule l'option manuelle « réduire les effets » existe (UI.effetsReduits, src/ReplicatedStorage/TardisUI.lua:529-531, bouton dans TardisTablette/Volet.lua:161-162). Aucune mesure des images par seconde. C'est déjà prévu dans la feuille de route : docs/FEUILLE_DE_ROUTE.md:47 (V8, « effets qui s'allègent automatiquement quand les images par seconde baissent »)
- **Fichiers :** `src/ReplicatedStorage/TardisUI.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisEffets.client.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/EffetsExterieurs.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Regeneration.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisVolLibre.client.lua`
- **Dépend de :** 177, 178
- **Dans Studio :** —
- **Feuille de route :** Fait partie de la V8 prévue. S'il faut un interrupteur (auto activé ou non), ne pas l'ajouter dans la tablette Y que la V11 supprimera : le laisser automatique, ou prévoir son déplacement sur la console en V11.
- **Effort :** moyen · **Risque :** moyen
- **Approche :** Un seul compteur partagé dans TardisUI (le module est mis en cache, donc les 3 exemplaires par TARDIS de TardisEffets et TardisExtrasClient le partagent). Il calcule une moyenne glissante de dt avec hystérésis : allégé sous 30 images/s pendant 3 s, minimal sous 20, retour au-dessus de 45 pendant 5 s, et UI.niveauEffets() renvoie 1, 0,5 ou 0,2. Ce niveau réduit seulement le coût (débits et Emit des particules, fréquence des arcs, ondes, phare, flou) ; il ne touche jamais Config.Alpha ni les saccades, pour que l'animation reste la même chez tous les joueurs, et il reste séparé de l'option d'accessibilité effetsReduits. À brancher après le regroupement des boucles (177) et la coupure des effets loin du joueur (178).

## V8.4 — Moins d'attributs envoyés sur le réseau

### 180. Moins d'attributs répliqués

*Regrouper les changements fréquents pour soulager le réseau.*

- **Déjà fait :** rien — Rien n'a été fait pour réduire les attributs répliqués. Il y a environ 306 SetAttribute côté serveur (TardisServeur 98, TardisSystemes 78, VolLibre 62, TardisExtras 60). Points chauds trouvés : src/ServerScriptService/TardisServeur/VolLibre.lua:144 (recevoirPositionVol republie VolLibreCF environ 15 fois par seconde, au rythme de TardisVolLibre.client.lua:36 ENVOIS_PAR_SECONDE = 15 et :1306) ; TardisSystemes.server.lua:1007-1019 (Heartbeat qui écrit DepotCF à chaque image quand le TARDIS est posé sur un véhicule) ; VolLibre.lua:52-58 (phaseVol écrit 4 attributs à la suite) ; VolLibre.lua:~300-306 (6 attributs Descente*) ; TardisSystemes.server.lua:52-56 (publierPV écrit 3 attributs à chaque dégât, y compris à chaque balle) ; TardisExtras.server.lua:148-152 (Registre renvoyé en entier à chaque entrée ou sortie). Seules quelques listes sont déjà regroupées en JSON (Incidents :419, Carnet :1092, StatsModes :735).
- **Fichiers :** `src/ServerScriptService/TardisServeur/VolLibre.lua`, `src/ServerScriptService/TardisSystemes.server.lua`, `src/ServerScriptService/TardisExtras.server.lua`, `src/ServerScriptService/TardisServeur/init.server.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisVolLibre.client.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisEffets.client.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/init.client.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisPorter.client.lua`
- **Dépend de :** 166, 181, 185
- **Dans Studio :** Rien à construire. Il faut seulement vérifier en jeu le trafic réseau (statistiques réseau de la console développeur) avant et après.
- **Feuille de route :** Le menu T et la tablette Y lisent PV, PointsDeVie, Registre et d'autres attributs : il ne faut pas y modifier les lecteurs, puisque la V11 les supprime. On change d'abord les écritures sans changer le format (limiter la fréquence, ne pas réécrire une valeur identique). La V7 (156/157) réécrit aussi la réception des positions du vol libre : il faut se coordonner pour ne pas toucher deux fois à recevoirPositionVol. À faire avant la V11, pour que la console soit construite sur le format allégé.
- **Effort :** moyen · **Risque :** moyen
- **Approche :** 1) Mesurer d'abord avec 181. 2) Envoyer les positions du vol libre par un UnreliableRemoteEvent (FireAllClients) et ne mettre à jour l'attribut VolLibreCF que 2 fois par seconde (pour les joueurs qui arrivent en cours de vol et pour le tracteur de TardisExtras:592), tout en gardant le nom et l'ordre des attributs. 3) Ailleurs : limiter DepotCF sur un véhicule à environ 5 fois par seconde, regrouper les dégâts de PV en une publication toutes les 0,2 s, ne rien écrire quand la valeur ne change pas, garder « VolPhase en dernier » comme déclencheur.

## V9 — Guide d'installation

### 196. Guide d'installation pas à pas

*Un document illustré pour installer une version dans Studio.*

- **Déjà fait :** partiel — README.md:75-91 (section « Installation dans Studio » en 7 étapes, texte seul, sans illustration) ; README.md:63-73 + outils/synchro_studio.luau:1-5 (synchro par empreinte) ; docs/RAPPELS.md §2-§3 (objets à placer : Arrivee, ZDC-…, Diagnostic1-4, Casier, Vanne, Murs, Sol, SiegeEquipage, Grille, équipes C.A.T./C.T.A.T.) ; docs/FEUILLE_DE_ROUTE.md:82 (la V9 prévoit déjà de mettre à jour le README et la synchro pour la nouvelle arborescence). Les instructions sont éparpillées entre README, RAPPELS et les patch notes, et rien n'est illustré.
- **Fichiers :** `docs/INSTALLATION.md (nouveau)`, `README.md (garder un résumé et ajouter le lien)`, `docs/RAPPELS.md (renvoyer vers le guide)`, `outils/synchro_studio.luau (seulement si le guide en change les prérequis)`
- **Dépend de :** 200
- **Dans Studio :** Rien à construire. Si l'utilisateur veut un guide vraiment illustré, il faut qu'il fournisse des captures de l'Explorer de Studio (hiérarchie Workspace › TARDIS › TARDIS_1, ServerScriptService, réglage « Enable Studio Access to API Services »), parce qu'on n'a pas accès à Studio. Sinon, on illustre avec des arborescences en texte et des tableaux.
- **Feuille de route :** Écrire le guide complet maintenant ferait du travail à refaire : la V9 change l'organisation des fichiers et donc tous les chemins d'installation, la V10 change Config.Tardis (3 TARDIS, un par pilote), et la V11 ajoute les pièces nommées de la console (écrans et boutons) à placer dans Studio. Le guide doit être fait en V9, puis complété en V10 et en V11.
- **Effort :** moyen · **Risque :** faible
- **Approche :** Créer docs/INSTALLATION.md en même temps que la refonte de l'arborescence (V9). Il regroupe dans un seul parcours numéroté ce qui est aujourd'hui dans README.md:75-91, la synchro (manifeste.py, http.server, synchro_studio.luau) et la liste d'objets de RAPPELS.md §2-3. Chaque étape a une arborescence en texte, un tableau des types (Script, LocalScript, ModuleScript) et la ligne attendue dans l'Output (diagnostic). Ajouter une section « Vérifier après installation » qui renvoie au tableau « À tester » de la version, puis compléter le guide en V10 (3 TARDIS) et en V11 (pièces de la console).

## V10.1 — Régénération : nouveaux styles et choix du style

### 103. Nouveau style : Cristal

*Le corps se couvre d'éclats lumineux qui se brisent.*

- **Déjà fait :** rien — Il existe 7 styles (TardisConfig.lua:619 : Classique, Volcan, Douce, Tourbillon, Colonne, Supernova, Fracture). Leurs branches sont dans src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Regeneration.lua:194-563 (style 1 = cas par défaut, style 7 Fracture à :469). Aucun style Cristal. Le cadre est réutilisable : garder(), partTemporaire, parImage(p, i, t), flashPour, eclatChangement() (Regeneration.lua:123-134, 596-614).
- **Fichiers :** `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Regeneration.lua`, `src/ServerScriptService/TardisSystemes.server.lua`, `src/ReplicatedStorage/TardisConfig.lua`
- **Dépend de :** —
- **Dans Studio :** Rien d'obligatoire : les éclats sont créés par le script. En option, un Sound "Regeneration_Cristal" dans ReplicatedStorage > TardisAssets > Sons.
- **Feuille de route :** Pas de conflit de fond. Regeneration.lua fait déjà 904 lignes : ajouter un style avant la V9 grossit un fichier que la V9 va réorganiser. Mieux vaut l'ajouter quand les styles auront chacun leur module.
- **Effort :** moyen · **Risque :** faible
- **Approche :** Ajouter une branche `elseif style == 8` : des éclats en Glass/Neon (petites pièces en coin) accrochés aux membres et repositionnés à chaque image par parImage, de plus en plus lumineux pendant la montée. À p ≥ 0,52 ils sont projetés vers l'extérieur, tournent puis disparaissent, avec flashPour = une couleur bleu-blanc. En effets réduits (`reduit`), on en crée moins. Passer la borne du serveur à #Config.Regeneration.Styles (TardisSystemes.server.lua:727) et mettre à jour le commentaire de la configuration.

### 104. Nouveau style : Écho

*Plusieurs silhouettes des anciens visages apparaissent puis s'effacent.*

- **Déjà fait :** rien — Aucun style Écho dans Regeneration.lua (branches 2 à 7 de :194 à :563). Le serveur ne garde que le dernier avatar porté : derniereTenue[UserId] (TardisSystemes.server.lua:330, 397-406). Aucun historique des anciennes apparences, donc rien pour dessiner « plusieurs anciens visages ».
- **Fichiers :** `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Regeneration.lua`, `src/ServerScriptService/TardisSystemes.server.lua`, `src/ReplicatedStorage/TardisConfig.lua`
- **Dépend de :** —
- **Dans Studio :** Rien (les silhouettes sont des copies générées par le script).
- **Feuille de route :** Même remarque que pour 103 : il grossit Regeneration.lua avant la réorganisation de la V9. Aucun conflit avec V10 ni V11.
- **Effort :** moyen · **Risque :** moyen
- **Approche :** Côté client, à chaque régénération vue, juste avant le changement (p ≈ 0,45), copier le corps (mettre personnage.Archivable = true le temps de la copie, retirer scripts, humanoïde et sons). Garder pour chaque joueur, pendant la session, une file des 3 ou 4 dernières copies. Dans la branche style 9, faire apparaître ces silhouettes en ForceField/Neon translucide autour du joueur, décalées et ancrées, puis les effacer l'une après l'autre. Limite : on ne revoit que les visages vus pendant la session (un historique côté serveur avec CreateHumanoidModelFromDescription serait plus lourd et répliqué à tout le monde). Le risque vient du coût des copies : il faut les plafonner et respecter UI.effetsReduits().

### 102. Choix du style par le joueur

*Chaque membre de la C.A.T. choisit son style de régénération préféré.*

- **Déjà fait :** rien — Le style est seulement global : Config.Regeneration.Style (src/ReplicatedStorage/TardisConfig.lua:619, 0 = au hasard, 1 à 7 imposé), lu dans derouler() à src/ServerScriptService/TardisSystemes.server.lua:725-728 avec la borne 7 écrite en dur (`if style < 1 or style > 7 then style = math.random(7)`). Aucun choix par joueur. Les préférences des joueurs existent déjà (JSON dans l'attribut TardisPrefs, action "Prefs" à src/ServerScriptService/TardisExtras.server.lua:1120-1125, réglages de la tablette à src/StarterPlayer/StarterPlayerScripts/TardisTablette/Volet.lua:156-180), mais aucune ne concerne la régénération.
- **Fichiers :** `src/ReplicatedStorage/TardisConfig.lua`, `src/ServerScriptService/TardisSystemes.server.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisTablette/Volet.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Regeneration.lua`
- **Dépend de :** —
- **Dans Studio :** Rien si le choix passe par un bouton d'interface. Si on veut le mettre sur un objet (V11 ou garde-robe) : une Part avec un ProximityPrompt, à placer dans l'intérieur.
- **Feuille de route :** Le bouton se placerait naturellement dans les Réglages de la tablette Y (Volet.lua:156), que la V11 supprime : ce serait du travail jeté. Pour que ça tienne après la V11, mettre le choix sur la console ou sur un ProximityPrompt (garde-robe). La partie serveur (lecture de la préférence) ne pose pas de conflit.
- **Effort :** petit · **Risque :** faible
- **Approche :** Ajouter dans Config.Regeneration une liste `Styles = { "Classique", ... }` qui sert de référence unique (et remplace le 7 écrit en dur côté serveur et dans le commentaire), plus `ChoixDuJoueur = true`. Dans derouler(), si Config.Style vaut 0, lire `styleRegen` dans le JSON de joueur:GetAttribute("TardisPrefs") avec un pcall, garder seulement un entier entre 0 et #Styles, sinon tirer au hasard. Côté client, un bouton qui fait défiler les styles et appelle UI.setPref("styleRegen", n), posé sur la console ou sur un ProximityPrompt au moment de la V11. À faire après 103 et 104 pour que la liste les contienne déjà (ce n'est pas obligatoire).

## V10.2 — Régénération : fins et réactions

### 107. Dernière régénération

*Après N régénérations, une version plus dramatique, puis remise à zéro.*

- **Déjà fait :** partiel — Une limite existe : Config.Regeneration.Nombre (TardisConfig.lua:611, 0 = infini, c'est la valeur actuelle). Une fois la limite atteinte, c'est la vraie mort tout de suite, sans dernière régénération : TardisSystemes.server.lua:799-805 (`mortReelle("Mort (plus de régénération)")`). Le compteur repart de zéro à cette mort (:788). Il n'y a pas de régénération plus spectaculaire ni de nouveau cycle.
- **Fichiers :** `src/ServerScriptService/TardisSystemes.server.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Regeneration.lua`, `src/ReplicatedStorage/TardisConfig.lua`
- **Dépend de :** —
- **Dans Studio :** Rien (en option, un son dédié dans TardisAssets > Sons).
- **Feuille de route :** Aucun conflit avec la feuille de route. Il faut seulement choisir clairement entre l'actuel « Nombre = vraie mort » et le « cycle qui recommence », pour ne pas avoir deux réglages qui se contredisent.
- **Effort :** moyen · **Risque :** moyen
- **Approche :** Ajouter `Cycle = 12` (0 = désactivé) et `DureeDerniere = 14` dans Config.Regeneration. Dans derouler(), si nombre + 1 == Cycle : régénération « ultime », avec un attribut TardisRegenerationUltime = true, une durée plus longue et un style imposé (par exemple Supernova plus fort : onde de choc doublée, flash plus long, secousse plus forte), puis regenerations[UserId] = 0 et une entrée « Dernière régénération du cycle » dans le journal. Côté client, si l'attribut est présent, renforcer la branche choisie. Bien séparer ce cas de la vraie mort de Nombre (:801).

### 114. Régénération refusée : chute dramatique

*Si le joueur refuse, une animation de mort différente.*

- **Déjà fait :** rien — Le refus mène directement à mortReelle("Régénération refusée") (TardisSystemes.server.lua:825-828 ; mortReelle de :786 à :796 met BreakJointsOnDeath = true et la santé à 0) : c'est la mort Roblox standard, le corps se disloque. Côté client, le bouton se contente de fermer l'interface (Regeneration.lua:826-829), et la lueur de la phase de choix s'efface toute seule (:761-775). Aucune animation propre au refus.
- **Fichiers :** `src/ServerScriptService/TardisSystemes.server.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Regeneration.lua`
- **Dépend de :** —
- **Dans Studio :** Rien (en option, un son "RegenerationRefusee" dans TardisAssets > Sons).
- **Feuille de route :** Aucun. Ce n'est pas la « crise post-régénération » retirée : il s'agit de la mort, pas d'un effet après la régénération.
- **Effort :** moyen · **Risque :** moyen
- **Approche :** Ajouter un paramètre de nature à mortReelle. Pour un refus : poser l'attribut TardisRegenRefusee = maintenant, garder le ForceField et BreakJointsOnDeath = false pendant environ 2,5 s, figer le joueur, puis faire une chute lente en R6 (genoux qui plient, torse qui bascule en avant), avec des tweens Motor6D comme poseRegeneration (:655-671). Ensuite seulement : santé à 0 sans dislocation. Côté client, si l'attribut est présent : la lueur dorée vacille et s'éteint, les volutes sont aspirées vers le corps, l'image se désature pour le joueur et la caméra recule lentement. Points délicats : la réparation automatique des articulations (DescendantRemoving, :693-713) et la mise à mort côté client (surveillerMoi, Regeneration.lua:782-794), qui doivent attendre la fin de l'animation.

### 115. Effet sur le TARDIS proche

*Une régénération près du TARDIS fait trembler la cabine.*

- **Déjà fait :** partiel — À bord, c'est déjà fait : derouler() repère le TARDIS (tardisABord, :486-495) et déclenche evenementABord (:720-724). Le serveur inflige des dégâts, déclenche l'alarme et pose l'attribut RegenerationABord (:497-510). Le client fait jaillir des étincelles de la console et secoue l'écran de ceux qui sont à bord (Regeneration.lua:881-901). Près du TARDIS mais dehors : rien, la cabine extérieure ne tremble pas. Une vibration de la cabine existe déjà pour les voyages sans stabilisateur (TardisExtrasClient/Systemes.lua:86-104).
- **Fichiers :** `src/ServerScriptService/TardisSystemes.server.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Systemes.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Regeneration.lua`, `src/ReplicatedStorage/TardisConfig.lua`
- **Dépend de :** —
- **Dans Studio :** Rien.
- **Feuille de route :** La recherche du TARDIS proche parcourt tous les TARDIS (Config.Tardis), et c'est la V10 qui fixe les 3 TARDIS officiels et leur attribution : à faire après la V10 pour ne pas refaire la détection. La V8 (177, boucles par image regroupées) demande de ne pas ajouter de nouvelle boucle RenderStepped : réutiliser celle de Systemes.lua.
- **Effort :** petit · **Risque :** faible
- **Approche :** Quand lieu == nil dans derouler(), envoyer un BindableEvent "TardisRegenerationProche" avec la position. Chaque exemplaire de TardisSystemes compare cette position à exterieur:GetPivot() ; si la distance est inférieure à Config.Regeneration.RayonTardis (par exemple 25 studs), il pose exterieur:SetAttribute("RegenerationProche", maintenant). Dans la boucle de vibration de Systemes.lua:88, ajouter ce cas (cabine posée seulement, sans Porteur ni VolLibre, amplitude qui diminue sur la durée de la régénération) et une petite secousse pour ceux qui sont à bord. Sans dégâts, ou très faibles.

## V10.3 — Départ annulable et remat ratée

### 11. Annuler un départ

*Pendant le son de départ (avant que la cabine s'efface), un bouton annule le voyage.*

- **Déjà fait :** rien — decoller (init.server.lua:481-525) attend d'un bloc avec task.wait(decalage + duree) (:514), sans aucun moyen d'interrompre. partage.occupe est vrai et la porte est verrouillée pendant toute la démat. Fenêtre « son seul, cabine encore visible » : Decalage de 3,25 s en Classique, 2,25 s en Urgence, 0 en Express et en Silencieux (TardisConfig.lua:57, 66, 77, 103 ; Config.Alpha :805-807). Les clients suivent l'attribut Etat (TardisEffets.client.lua:276, fondu d'après Etat) : repasser à Pose remet la cabine visible. Une transition Demat→Pose n'est comptée ni dans les statistiques (TardisExtras.server.lua:781) ni dans l'usure (TardisSystemes.server.lua:255).
- **Fichiers :** `src/ServerScriptService/TardisServeur/init.server.lua`, `src/ReplicatedStorage/TardisCommandes.lua`, `src/ReplicatedStorage/TardisConfig.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisMenu.client.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisTablette/Etat.lua`
- **Dépend de :** 156, 157
- **Dans Studio :** Rien maintenant. En V11 : le bouton se trouve sur la console (le levier existant peut servir à annuler, ou un bouton dédié à placer).
- **Feuille de route :** Un bouton « Annuler » dans le menu T ou la tablette Y serait supprimé en V11 : mieux vaut le brancher tout de suite sur le levier de la console (promptLevier, init.server.lua:1068), en plus d'une action à distance. Aucun compte à rebours ne doit être ajouté (« Départ dans 3, 2, 1 » est retiré). La fenêtre est nulle en Express et en Silencieux, et très courte en Classique (3,25 s) : il faut décider si l'annulation reste permise pendant une partie de l'animation.
- **Effort :** moyen · **Risque :** moyen
- **Approche :** Dans decoller, remplacer le task.wait unique par une attente en petits pas qui vérifie un jeton d'annulation tant que le délai n'est pas écoulé, ou par exemple tant que la progression reste sous 30 %. Si le départ est annulé : arrêter les sons de démat, rétablir Mode, PrecedentNom et Verrouille, remettre Etat à Pose, libérer partage.occupe, puis renvoyer false avec « DÉPART ANNULÉ ». Côté client, surEtat vide déjà autoRemat au retour à Pose (TardisCommandes.lua:154-157). Ajouter l'action « AnnulerDepart » (pilote ou copilote) et le levier de la console.

### 45. Rematérialisation partielle ratée

*Rare : la cabine clignote, disparaît, puis réapparaît (bug d'atterrissage RP).*

- **Déjà fait :** rien — Aucun raté aléatoire. Le mécanisme le plus proche est réservé au paradoxe : atterrissageAvorte() (src/ServerScriptService/TardisServeur/init.server.lua:739-760) commence une remat Catastrophe puis renvoie la cabine dans le vortex. Le fondu est calculé de façon déterministe par Config.Alpha (TardisConfig.lua:798-825) à partir de Etat/DebutEtat
- **Fichiers :** `src/ServerScriptService/TardisServeur/init.server.lua`, `src/ReplicatedStorage/TardisConfig.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisEffets.client.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisVolLibre.client.lua`, `outils/simulation/sim_config.py`
- **Dépend de :** —
- **Dans Studio :** —
- **Feuille de route :** Touche atterrir() du serveur et la signature de Config.Alpha, deux zones que la V7 (audit des attributs) et les V8/V9 (nettoyage, découpage de TardisServeur et TardisEffets) vont retravailler : mieux vaut l'ajouter après ces refontes. Un éventuel message dans la tablette serait à déplacer sur la console en V11.
- **Effort :** moyen · **Risque :** moyen
- **Approche :** Effet purement visuel, sans toucher aux collisions. Dans atterrir(), avant setEtat(E.Remat) (comme Mode), le serveur tire au sort une chance rare (Config.RematRatee = { Chance = 0.03, Modes = { Normal = true, Urgence = true } }, ni Silencieux, ni Sauvetage, ni Catastrophe) et pose un attribut « Hoquet » qui donne la position du raté dans la progression (0,5 à 0,7). Il l'efface au posé. Config.Alpha reçoit ce paramètre en plus : sur environ 12 % de la progression, la cabine clignote, disparaît (alpha 1), puis l'animation reprend ; Souffle renvoie 0 pendant le raté pour couper la lueur et les ondes. Passer ce paramètre dans TardisEffets (:165, :206) et TardisVolLibre (:448), avec un simple fondu sans clignotement en effets réduits, et mettre à jour les simulations.

## V10.4 — Voyage de groupe synchronisé

### 18. Voyage de groupe synchronisé

*Deux TARDIS qui partent et arrivent ensemble (quand il y en aura plusieurs).*

- **Déjà fait :** rien — Un seul TARDIS est actif : TardisConfig.lua:312-315 (TARDIS_2 et TARDIS_3 sont en commentaire). Chaque script est cloné une fois par TARDIS (Config.demarrerPourChaqueTardis, TardisConfig.lua:394) et n'a aucun lien avec les autres TARDIS. Le seul canal commun est le Bindable ServerStorage.TardisEvenements, qui ne sert qu'au journal (init.server.lua:240-243).
- **Fichiers :** `src/ServerScriptService/TardisServeur/init.server.lua`, `src/ReplicatedStorage/TardisConfig.lua`, `src/ReplicatedStorage/TardisCommandes.lua`
- **Dépend de :** 156, 157
- **Dans Studio :** Au moins deux TARDIS complets (extérieur, intérieur, console), comme le prévoit la V10.
- **Feuille de route :** Il faut plusieurs TARDIS : à faire après la V10. La règle de la V10 « un pilote = un TARDIS, le serveur refuse toute commande sur un autre » oblige le pilote de l'autre TARDIS à accepter, avec une invitation et une confirmation. La V11 ne mettra la console que sur TARDIS_1 (V11.5 et suivantes ne seront pas faites) : il reste à décider où se trouve le bouton sur TARDIS_2 et TARDIS_3. La V9 réorganise les scripts (un point d'entrée par côté), ce qui facilitera la coordination entre TARDIS.
- **Effort :** gros · **Risque :** élevé
- **Approche :** Créer un coordinateur serveur commun (un module partagé par les instances de TardisServeur) : le pilote A propose, le pilote B accepte, puis les deux décollent au même moment de l'horloge serveur, dans le même mode (le plus lent des deux), et atterrissent côte à côte grâce à un décalage de CFrame pour éviter enCollision. Si l'un des deux échoue (portes bloquées, hors tension, maintenance), annuler les deux départs proprement : ce mécanisme gagne à s'appuyer sur celui de la proposition 11.

## V10.5 — Accès à bord : sonnette, passages secrets, chambres

### 68. Zones d'intérieur cachées

*Des pièces secrètes que seuls les pilotes peuvent ouvrir.*

- **Déjà fait :** rien — Aucune pièce secrète ni passage réservé aux pilotes dans src (pas de « Secret », « Cache » ou « Passage »). Ce qui sert de base existe déjà : estPilote par TARDIS via le pont interne (TardisSystemes.server.lua:22, TardisExtras.server.lua), le suivi des joueurs à bord (TardisExtras.server.lua:146 et 190-215), le dossier PortesInterieures (TardisConfig.lua:44, géré par TardisPortail.client.lua:34).
- **Fichiers :** `src/ReplicatedStorage/TardisConfig.lua`, `src/ServerScriptService/TardisExtras.server.lua`
- **Dépend de :** —
- **Dans Studio :** Construire les pièces cachées dans le modèle TARDIS_Interieur et un dossier « ZonesCachees » : pour chaque zone, un Model avec une Part « Passage » (le pan de mur ou la bibliothèque qui s'ouvre) et une Part « Declencheur » (livre, levier, panneau). Ne pas les mettre dans PortesInterieures, que TardisPortail cache déjà.
- **Feuille de route :** Pièces à construire dans chaque intérieur : après la V10. La règle « un pilote = un TARDIS » de la V10 convient, puisque estPilote est déjà propre à chaque TARDIS. Il reste à décider si le copilote et les pilotes temporaires peuvent ouvrir. Aucun lien avec le menu T ni la tablette Y.
- **Effort :** moyen · **Risque :** moyen
- **Approche :** Serveur (TardisExtras, section Intérieur) : un ProximityPrompt sur chaque « Declencheur », qui vérifie estPilote côté serveur puis ouvre le « Passage » (Transparency et CanCollide à false, ou Tween d'un Model) pendant Config.ZonesCachees.DureeOuverture secondes avant de refermer. Pour éviter qu'un non-pilote suive pendant l'ouverture, renvoyer à l'arrivée (pointArriveeInterieur, TardisExtras.server.lua:960 environ) un non-pilote détecté dans la boîte de la zone, avec la boucle de 0,5 s déjà en place. Utiliser des prompts serveur plutôt qu'un RemoteEvent, pour ne rien ajouter à sécuriser en V7. Réutiliser l'animation des portes intérieures (54) si elle est faite avant.

### 93. Demande d'accès à bord

*Un joueur dehors peut sonner ; les pilotes acceptent ou refusent.*

- **Déjà fait :** partiel — Deux briques proches existent. L'interphone : TardisExtras.server.lua:1154-1167 (un joueur dehors, à 12 studs ou moins, envoie un message filtré à l'intérieur) et Interactions.lua:41-95 (panneau et bulle). L'invitation : TardisExtras.server.lua:1265-1277 (« Inviter », dans le sens pilote vers joueur) et :1140-1152 (« InvitationReponse » : accepter ou refuser, téléportation via pointArriveeInterieur, :967), avec la carte Accepter/Refuser dans Interactions.lua:13-38. Ce qui manque : le sens inverse (le joueur dehors sonne, les pilotes acceptent ou refusent). Attention : un invité accepté déclenche aujourd'hui l'alerte INTRUSION (TardisExtras.server.lua:206-211, car il n'est pas pilote).
- **Fichiers :** `src/ServerScriptService/TardisExtras.server.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Interactions.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Preferences.lua`, `src/ReplicatedStorage/TardisConfig.lua`
- **Dépend de :** 156, 157
- **Dans Studio :** Optionnel : un Sound « Sonnette » dans ReplicatedStorage › TardisAssets › Sons. Optionnel aussi : une Part « Sonnette » sur l'extérieur pour porter le prompt (sinon le script le pose sur la porte ou sur le PrimaryPart).
- **Feuille de route :** Ajoute deux actions RemoteEvent (Sonner, AccesReponse) : à déclarer dans le garde-barrière de la V7 (propositions 156 et 157), pas à côté. La carte Accepter/Refuser est une fenêtre à part, pas le menu T ni la tablette Y : elle survit à la V11 (on pourra ajouter un bouton sur la console en V11.3). Après la V10, la demande ne doit aller qu'aux pilotes de CE TARDIS : c'est déjà le cas avec estPilote par TARDIS, mais à vérifier quand un pilote n'aura qu'un seul TARDIS.
- **Effort :** moyen · **Risque :** moyen
- **Approche :** Côté serveur : un ProximityPrompt « Sonner » sur la porte extérieure, actif seulement si le TARDIS est Posé, visible et non camouflé. Au déclenchement, on vérifie la distance et une attente (par exemple 30 s par joueur), puis on envoie remote:FireClient(pilote, "__sonnette", nom) aux pilotes à bord ou en ligne et on note la demande (expire après 60 s, comme les invitations). Côté client : on réutilise la carte d'afficherInvitation (« X sonne à la porte : Accepter / Refuser »). Si un pilote accepte : téléportation par pointArriveeInterieur (ou ouverture des portes) et ajout du joueur à une liste « invités autorisés » qui supprime l'alerte INTRUSION. Cette liste règle aussi le même défaut de l'invitation actuelle.

### 57. Chambres de l'équipage

*Des petites pièces privées, une par membre de la C.A.T.*

- **Déjà fait :** rien — Aucune chambre ni porte réservée à un joueur dans le code. Ce qui existe : l'équipe C.A.T. est une Team (Config.Equipe, TardisConfig.lua:130-135), les pilotes sont listés par UserId (Config.Pilotes, TardisConfig.lua:298, Config.estPilote ligne 338) et via Adonis/WL. Les casiers (Interactions.lua:98-220) sont ouverts à tous, pas personnels.
- **Fichiers :** `src/ServerScriptService/TardisExtras.server.lua (ou un nouveau script serveur TardisChambres)`, `src/ReplicatedStorage/TardisConfig.lua`, `src/ServerScriptService/TardisSauvegarde.lua`, `src/ServerScriptService/TardisDiagnostic.lua`
- **Dépend de :** 68
- **Dans Studio :** Construire les pièces « Chambre1 » à « ChambreN » dans le Model de l'intérieur, chacune avec une Part « PorteChambre » (la porte) et une Part « Plaque » (le nom de l'occupant), plus le mobilier. Une chambre par membre de la C.A.T., donc il faut connaître le nombre de membres.
- **Feuille de route :** Dépend de la V10 : l'attribution « un pilote = un TARDIS » va redéfinir qui est membre de quel TARDIS (fin de la liste globale Config.Pilotes, accès Adonis/WL par TARDIS). Si on attribue les chambres avant, il faudra tout refaire. La vérification serveur d'ouverture suit les règles de la V7.
- **Effort :** gros · **Risque :** moyen
- **Approche :** Réglage par TARDIS : def.Chambres = { [n] = UserId }, ou attribution automatique au premier passage d'un membre C.A.T., gardée dans TardisSauvegarde. Un script serveur pose un ProximityPrompt sur chaque PorteChambre : seul l'occupant (et éventuellement un pilote) peut ouvrir. La porte s'ouvre côté serveur (CanCollide et transparence ou rotation), et la Plaque affiche le pseudo dans une SurfaceGui. La porte réservée utilise le même mécanisme que #68 (pièces cachées réservées aux pilotes) : faire #68 d'abord et réutiliser sa porte.

## V10.6 — Nouvelles salles : machines, infirmerie, bibliothèque

### 58. Salle des machines

*Une pièce sous la console où les techniciens réparent les pannes.*

- **Déjà fait :** partiel — Les pannes et leurs points de réparation existent déjà : src/ServerScriptService/TardisSystemes.server.lua:191-320 (grilles « Grille » ou dossier « Grilles » cherchées partout dans l'intérieur par GetDescendants, l. 194-196 ; « Vanne » cherchée par FindFirstChild("Vanne", true), l. 219 ; levier d'alimentation par chemin fixe Config.Chemins.Alimentation = Controls > LockLever, src/ReplicatedStorage/TardisConfig.lua:33). Les interventions guidées pointent vers ces pièces : src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/TabletteTechnicien.lua:27-39 et 446-490. La salle elle-même n'existe pas : aucune mention de « salle des machines » dans src.
- **Fichiers :** `src/ReplicatedStorage/TardisConfig.lua`, `src/ServerScriptService/TardisSystemes.server.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/TabletteTechnicien.lua`, `src/ServerScriptService/TardisDiagnostic.lua`
- **Dépend de :** 118, 119
- **Dans Studio :** Construire la pièce sous la console, DANS le modèle TARDIS_Interieur (sinon elle ne compte pas « à bord » : la boîte englobante de l'intérieur est calculée au démarrage, init.server.lua:529-536 et TardisExtrasClient/init.client.lua:26-30), avec une trappe ou un escalier pour y descendre. Y déplacer ou y ajouter les pièces « Grille » (ou un dossier « Grilles »), la « Vanne » et éventuellement le levier d'alimentation (puis donner son nouveau chemin). Prévoir de la place pour les futures pannes (fuite d'air, rotor bloqué).
- **Feuille de route :** Pièce à construire dans chaque intérieur : à faire une fois les intérieurs rangés et officialisés (V10). Les indications de la tablette technicien (touche Y) seront retirées avec la tablette en V11 : ne pas investir dans un affichage propre à la tablette, mettre plutôt les repères dans le monde (panneaux, surbrillance). La V9 range les pannes dans un dossier « Systemes » : faire la partie script après ce déménagement.
- **Effort :** moyen · **Risque :** moyen
- **Approche :** Côté script, il y a surtout du branchement à faire. Ajouter un réglage Config.SalleDesMachines (nom du dossier, point d'arrivée de la trappe), créer un ProximityPrompt « Descendre / Remonter » sur la trappe (comme la console de secours, TardisExtras.server.lua:874 et suivantes), mettre à jour Config.Chemins.Alimentation si le levier change de place, puis ajouter « SALLE DES MACHINES » comme lieu dans les nomCible de la tablette technicien et dans TardisDiagnostic (liste des pièces attendues). Grilles et vanne marchent déjà où qu'elles soient placées. Le gros du travail (effort G) est la construction dans Studio. Risque : agrandir la boîte englobante de l'intérieur change dansInterieur (zone sûre, air, jukebox), donc à tester.

### 59. Infirmerie

*Une pièce qui soigne lentement les joueurs à bord.*

- **Déjà fait :** partiel — Le soin à bord existe déjà, et il est plus fort que la proposition : Config.ZoneSure = true (src/ReplicatedStorage/TardisConfig.lua:219-220). La fonction zoneSure (src/ServerScriptService/TardisExtras.server.lua:173-189) remet Health = MaxHealth et pose un ForceField invisible toutes les 0,5 s (boucle l. 190-215, appel l. 214) pour tout joueur dans l'intérieur. Il n'existe aucune pièce « Infirmerie » ni aucun soin progressif.
- **Fichiers :** `src/ReplicatedStorage/TardisConfig.lua`, `src/ServerScriptService/TardisExtras.server.lua`
- **Dépend de :** —
- **Dans Studio :** Construire l'infirmerie (lits, armoire à pharmacie) dans le modèle TARDIS_Interieur, avec une Part invisible « Infirmerie » (CanCollide false, Anchored) qui couvre la zone de soin.
- **Feuille de route :** Ne sert à rien tant que Config.ZoneSure = true, puisque tout l'intérieur soigne déjà instantanément : il faut d'abord décider de passer ZoneSure à false (ce qui change le jeu : on peut être blessé à bord) ou de la réduire à « pas de dégâts » sans soin complet. Pièce à construire dans chaque intérieur : à faire après la V10.
- **Effort :** petit · **Risque :** moyen
- **Approche :** Dans la boucle de 0,5 s de TardisExtras.server.lua (l. 190-215), pour chaque joueur dedans dont la racine est dans la boîte de la Part « Infirmerie » (CFrame:PointToObjectSpace comparé à Size/2), ajouter Config.Infirmerie.SoinParSeconde * 0,5 PV sans dépasser MaxHealth. Le bonus de régénération qui monte MaxHealth (TardisSystemes.server.lua:634-641) reste compatible. Ajouter un petit effet visible chez le client (particules vertes, BillboardGui « Soins ») via un attribut. Avant tout, trancher la question de ZoneSure, sinon la pièce est décorative.

### 56. Bibliothèque

*Une pièce avec des livres qui affichent des fiches RP (lieux, anomalies).*

- **Déjà fait :** rien — Aucune bibliothèque ni aucun livre dans le code. Données réutilisables : Config.FicheAnomalie (TardisConfig.lua:243-251, affichée seulement dans la tablette, TardisTablette/Outils.lua:315-324), carnet de bord RP par lieu (attribut « Carnet », TardisExtras.server.lua:1084-1105), liste des destinations (attribut CarteDestinations). Pour le prompt local à ouvrir, on peut copier le modèle des casiers (TardisExtrasClient/Interactions.lua:98-220).
- **Fichiers :** `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Bibliotheque.lua (nouveau)`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/init.client.lua`, `src/ReplicatedStorage/TardisConfig.lua`, `src/ServerScriptService/TardisDiagnostic.lua`
- **Dépend de :** 144
- **Dans Studio :** Construire une pièce « Bibliotheque » DANS le Model de l'intérieur (pour que dansInterieur, les lumières et les sons de bord la prennent en compte), avec des étagères et des Parts nommées « Livre » portant un attribut « Fiche » (clé de la fiche : nom d'un lieu, d'une anomalie...).
- **Feuille de route :** Pas de conflit avec la V11 : c'est un panneau de lecture ouvert par un prompt, pas le menu T ni la tablette Y. Il pourra même accueillir la fiche d'anomalie quand la tablette sera retirée (V11.4). Code nouveau : à ranger dans le domaine « Bord » à la V9.
- **Effort :** moyen · **Risque :** faible
- **Approche :** Ajouter Config.Bibliotheque (fiches : titre, catégorie Lieu/Anomalie, texte) et un module client Bibliotheque qui pose un ProximityPrompt local sur chaque « Livre » et ouvre un panneau de lecture (UI.coin, UI.pile, comme le casier). Lecture seule, donc pas de RemoteEvent ni rien à sécuriser. Les fiches de lieux viennent de la même table que #144 (fiches à l'arrivée) : faire #144 d'abord ou en même temps, avec une seule source. On peut ajouter en option les notes du carnet pour ce lieu. Ajouter « Livre » au diagnostic des pièces facultatives.

## V10.7 — Réglages personnels hors de la tablette

### 193. Réglages retenus entre appareils

*Les préférences suivent le joueur (déjà sauvegardées) et sont résumées dans un écran.*

- **Déjà fait :** partiel — La sauvegarde entre appareils est faite : DataStore « prefs_<UserId> » chargé à l'arrivée et publié dans l'attribut TardisPrefs (src/ServerScriptService/TardisExtras.server.lua:1066-1081), mis à jour par l'action « Prefs » (taille maximale 6000, JSON vérifié, TardisExtras.server.lua:1120-1125), lu et envoyé côté client par TardisUI.lua:479-521. Il manque un écran de résumé. Les réglages ne sont que dans la tablette Y (TardisTablette/Volet.lua:120-240) et n'existent que pour les pilotes (Volet.lua:306) : les visiteurs et les techniciens n'en ont aucun.
- **Fichiers :** `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Reglages.lua (nouveau)`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/init.client.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisTablette/Volet.lua`, `src/ReplicatedStorage/TardisUI.lua`, `src/ServerScriptService/TardisExtras.server.lua`
- **Dépend de :** 157, 168
- **Dans Studio :** —
- **Feuille de route :** L'écran de réglages actuel est dans la tablette Y, supprimée en V11.4 (« derniers réglages »). L'écran de résumé ne doit pas être construit dans la tablette Y : il doit devenir le panneau de réglages autonome qui survivra à la V11. Côté sécurité, la V7 (n°157 et 168) doit d'abord fixer le schéma de l'action Prefs et la taille du DataStore.
- **Effort :** moyen · **Risque :** faible
- **Approche :** Créer un panneau « Mes réglages » autonome dans TardisExtrasClient, ouvert par une touche, un petit bouton engrenage sur mobile et une touche de manette, et accessible à tous (pilotes, techniciens, visiteurs). Il résume et permet de modifier taille, volume, effets réduits, sans flash, sous-titres, daltonien, grande police et thème, en rappelant que ces choix suivent le joueur sur tous ses appareils. Le panneau reprend la partie « Options » de Volet.lua, qui disparaît avec la tablette Y en V11.4. Côté serveur, rien à ajouter, sauf le schéma de la V7.

### 186. Mode daltonien

*Couleurs des modes et alertes adaptées, avec des symboles en plus.*

- **Déjà fait :** rien — Aucune option daltonien. Les couleurs des modes sont codées en dur : UI.couleurMode (src/ReplicatedStorage/TardisUI.lua:44-47), états UI.LIBELLES (TardisUI.lua:37-42, vert/ambre/cyan), CouleurRotor par mode (src/ReplicatedStorage/TardisConfig.lua:54-110), utilisées dans TardisMenu.client.lua:795 et TardisEffets.client.lua:425. Point déjà positif : le libellé texte accompagne toujours la couleur (Config.libelleMode, TardisConfig.lua:669), et la lampe a un rythme propre à chaque mode (Signalisation.lua:182). Aucun symbole.
- **Fichiers :** `src/ReplicatedStorage/TardisUI.lua`, `src/ReplicatedStorage/TardisConfig.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Copilote.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/TabletteTechnicien.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisEffets.client.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisTablette/Volet.lua`
- **Dépend de :** 193
- **Dans Studio :** —
- **Feuille de route :** La plupart des endroits où l'on voit les couleurs de mode (sélecteur de modes du menu T : TardisMenu.client.lua:795 ; de la tablette Y : Construction.lua:451) disparaissent en V11.4. Si on adapte maintenant chaque menu, ce travail sera perdu. Seuls TardisUI/TardisConfig, le copilote, la tablette technicien et les écrans de console V11.1 restent.
- **Effort :** moyen · **Risque :** faible
- **Approche :** Ajouter dans TardisConfig un champ Symbole par mode (par exemple ▲ Urgence, » Rapide, ✚ Sauvetage, ◌ Silencieux, ✖ Catastrophe) et une palette sûre pour les daltoniens (Okabe-Ito), choisie quand la préférence « daltonien » est active. UI.couleurMode et UI.LIBELLES la lisent, et une fonction UI.libelleModeAvecSymbole sert partout. On construit les écrans de console V11.1 directement avec ces fonctions, plutôt que d'adapter les menus T et Y voués à disparaître. Les couleurs du rotor et des lumières sont calculées côté client (TardisEffets), donc on peut aussi les adapter pour chaque joueur.

### 187. Textes plus gros

*Une option de grande police pour toutes les interfaces.*

- **Déjà fait :** partiel — Un réglage « Taille de l'interface » existe déjà (0,6 à 1,4 sur toute l'interface, via UIScale) : UI.tailleInterface (src/ReplicatedStorage/TardisUI.lua:524-526), boutons -/Normale/+ dans TardisTablette/Volet.lua:123-139. Il est appliqué dans TardisMenu.client.lua:832, TardisTablette/Ouverture.lua:16, TardisVolLibre.client.lua:1576-1579, TabletteTechnicien.lua:707 et TardisRotation.client.lua:423, mais pas dans Copilote.lua:25 ni dans TabletteLecture.lua. Aucune option de police agrandie seule : environ 255 TextSize sont écrits en dur, et UI.texte (TardisUI.lua:122) met 14 par défaut.
- **Fichiers :** `src/ReplicatedStorage/TardisUI.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisTablette/Volet.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Copilote.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/TabletteLecture.lua`
- **Dépend de :** 193
- **Dans Studio :** —
- **Feuille de route :** Le menu T et la tablette Y, qui portent la plupart des textes, disparaissent en V11.4. Il ne faut pas reprendre leurs TextSize un par un. Les écrans de console V11 (SurfaceGui dans le monde) se lisent surtout en s'approchant. L'option reste utile pour le vol libre, le copilote, la tablette technicien, les notifications et le futur panneau de réglages.
- **Effort :** moyen · **Risque :** moyen
- **Approche :** Ajouter une préférence « grandePolice » (facteur 1,25). Un observateur générique dans TardisUI parcourt les ScreenGui Tardis* du PlayerGui, garde le TextSize d'origine dans un attribut et le multiplie par le facteur à l'ajout et à chaque changement de préférence. Cela couvre aussi les TextSize écrits en dur sans les toucher un par un. Le risque vient des textes coupés dans les cadres de taille fixe : vérifier les écrans qui restent après la V11, et brancher au passage UI.tailleInterface dans Copilote et TabletteLecture.

## V10.8 — Textes à clés et langue anglaise

### 85. Langue anglaise

*Une traduction anglaise de toute l'interface (option).*

- **Déjà fait :** rien — Aucune trace de langue ni de table de traduction (grep langue, anglais, english : rien). Les textes sont écrits en dur : environ 256 « Text = "..." » dans les clients, environ 95 messages serveur (dire, notifier, FireClient dans ServerScriptService), plus les libellés de TardisConfig (modes, destinations, raisons de maintenance, TardisConfig.lua:530). Le client reconnaît certains messages serveur à leur texte français : TardisExtrasClient/Preferences.lua:61 (string.find sur « INTRUSION », « BALISE », « ZONE INTERDITE »)
- **Fichiers :** `src/ReplicatedStorage/TardisConfig.lua`, `src/ReplicatedStorage/TardisUI.lua`, `src/ReplicatedStorage/TardisCommandes.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisMenu.client.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisTablette/Volet.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Preferences.lua`, `src/ServerScriptService/TardisServeur/init.server.lua`, `src/ServerScriptService/TardisExtras.server.lua`, `src/ServerScriptService/TardisSystemes.server.lua`
- **Dépend de :** —
- **Dans Studio :** —
- **Feuille de route :** Conflit fort : la V9 déplace presque tous les fichiers et la V11 remplace tous les textes du menu T et de la tablette par des écrans de console. Traduire l'interface actuelle avant serait du travail jeté. Les messages serveur devraient aussi passer par des clés de message, ce qui recoupe le schéma de données de la V7 (n° 157).
- **Effort :** gros · **Risque :** élevé
- **Approche :** Créer un module de textes partagé (TardisTextes : clé → {fr, en}) et une fonction UI.t(cle, ...) qui choisit selon une pref « langue ». Le serveur enverrait des clés et des paramètres plutôt que des phrases. Ne pas traduire l'interface actuelle : préparer le module pendant ou après la V9, puis écrire directement les écrans de console de la V11 avec des clés, et traduire seulement à ce moment-là. Il faut d'abord remplacer les tests sur le texte des messages (Preferences.lua:61) par des codes, sinon les alertes ne sonneraient plus en anglais.

## V11.1.1 — Écrans de la console : accueil, équipage, statistiques

### 86. Écran d'accueil de la tablette

*Un résumé à l'ouverture : état, destination, pannes, équipage.*

- **Déjà fait :** partiel — La tablette est déjà un tableau de bord. État et badges : panneau STATUT (TardisTablette/Construction.lua:289-350 : W.etatGrand, badges, jauges BOUCLIER et INTÉGRITÉ). Destination : TÉLÉMÉTRIE (Construction.lua:360, W.infoDestination). Personnes à bord : OCCUPANTS DE LA SALLE (Construction.lua:554). Le mode débutant ne garde que statut et navigation (TardisUI.lua:584-591). Il manque un résumé unique à l'ouverture et toute liste des pannes côté pilote : les pannes ne sont lues que dans la tablette technicien (TardisExtrasClient/TabletteTechnicien.lua:443, lirePannes) ; le pilote ne voit que le voile Avarie (Construction.lua:241-253)
- **Fichiers :** `src/StarterPlayer/StarterPlayerScripts/TardisTablette/Construction.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisTablette/Ouverture.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisTablette/Etat.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/TabletteTechnicien.lua`, `src/ReplicatedStorage/TardisUI.lua`
- **Dépend de :** 125
- **Dans Studio :** En V11 : une pièce nommée sur la console (par exemple EcranAccueil) pour porter le SurfaceGui du résumé. Rien à construire si l'écran reste dans la tablette.
- **Feuille de route :** La tablette Y est retirée en V11.4, et la V11.1 prévoit justement des « écrans d'affichage (lecture seule) » sur la console : état, destination, intégrité, énergie. Un écran d'accueil dans la tablette ferait doublon avec ce que la V11.1 va construire.
- **Effort :** moyen · **Risque :** faible
- **Approche :** Sortir lirePannes de TabletteTechnicien dans une fonction partagée (dans TardisUI ou un petit module client), ce qui recoupe la n° 125 (rapport de panne aux pilotes). Construire ensuite un résumé « état · destination · pannes en cours · équipage à bord (pilotes, techniciens, copilote) » qui lit les attributs existants. En V11.1, l'afficher sur un écran de la console. Si l'utilisateur le veut avant, une carte superposée de quelques secondes à l'ouverture de la tablette (Ouverture.lua, ouvrir), qu'on peut couper dans les Réglages, réutilisable telle quelle sur la console.

### 79. Indicateur de connexion des pilotes

*Voir qui est pilote, copilote et technicien en ligne, d'un coup d'œil.*

- **Déjà fait :** partiel — Les données existent déjà côté client, car ce sont des attributs répliqués par joueur : TardisPilote_<Nom> (TardisServeur/init.server.lua:359), TardisCopilote_<Nom> (init.server.lua:1711) et TardisTechnicien_<Nom> (TardisExtras.server.lua:659), plus l'attribut CopiloteNom du TARDIS. Affichages actuels : la tablette technicien liste les pilotes en ligne (TabletteTechnicien.lua:657-663). La tablette pilote liste seulement les occupants à bord (TardisTablette/Suivi.lua:33-42) et le nom du copilote dans les outils (Outils.lua:91). Il n'existe aucun indicateur réunissant pilotes, copilote et techniciens en ligne.
- **Fichiers :** `src/ReplicatedStorage/TardisUI.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisTablette/Suivi.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/TabletteTechnicien.lua`
- **Dépend de :** —
- **Dans Studio :** Pour la version console : une pièce écran nommée, par exemple EcranEquipage, sur la console. On peut aussi réutiliser un écran prévu pour la V11.1.
- **Feuille de route :** Un panneau dans la tablette Y serait refait en V11, puisque tous les affichages passent sur la console. La V10 change aussi le sens de la liste : avec un TARDIS attribué à chaque pilote, l'indicateur doit montrer qui est le pilote de quel TARDIS. Il vaut mieux le concevoir directement pour l'écran de la console, une fois la V10 en place. La proposition 86 (écran d'accueil, qui montre l'équipage) pourra reprendre cette fonction.
- **Effort :** petit · **Risque :** faible
- **Approche :** Ajouter une fonction cliente UI.equipageEnLigne(def) qui parcourt Players et renvoie les pilotes, le copilote et les techniciens du TARDIS à partir des attributs existants, sans changement côté serveur. La rafraîchir sur PlayerAdded, PlayerRemoving et le changement de ces attributs. L'afficher sur un écran de la console en V11.1, et la réutiliser dans la tablette technicien si celle-ci reste après la V11.

### 76. Tablette : onglet Statistiques

*Un vrai onglet de statistiques avec graphiques (voyages par jour, par mode).*

- **Déjà fait :** partiel — Serveur : src/ServerScriptService/TardisExtras.server.lua:720-797 compte les voyages, le temps de vol libre et les passagers par pilote, ainsi que les voyages par mode et le temps gagné (compterMode, :743-747), pour le joueur et pour le serveur. Ces données sont publiées dans les attributs TardisStats et StatsModes. Client : affichage en texte seul, en bas de la page Réglages de la tablette (TardisTablette/Volet.lua:195-221), plus 3 compteurs de session (Suivi.lua:61-66). Il manque un onglet dédié, les graphiques et tout comptage par jour (aucun historique daté côté serveur).
- **Fichiers :** `src/ServerScriptService/TardisExtras.server.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisTablette/Volet.lua`
- **Dépend de :** —
- **Dans Studio :** Pour la version console (V11) : une pièce écran nommée, par exemple EcranStatistiques, sur la console ou un mur de la salle de contrôle, avec une face visible. Le script y crée le SurfaceGui.
- **Feuille de route :** Un onglet de la tablette Y serait supprimé en V11.4 : il ne faut pas le construire dans la tablette. Les statistiques sont aussi globales à l'instance (« stats_serveur ») ; avec les 3 TARDIS officialisés et un pilote par TARDIS (V10), elles devront être comptées par TARDIS. La partie données est donc à faire après la V10, et l'affichage sur un écran de la console en V11.1 (écrans en lecture seule).
- **Effort :** moyen · **Risque :** faible
- **Approche :** Côté serveur : ajouter à statsServeur et à chaque pilote une table parJour (clé « AAAA-MM-JJ », gardée 30 jours, par mode), avec une limite de taille comme le prévoit la proposition 168, puis la publier dans un attribut JSON compact. Côté client : dessiner des barres avec des Frames (voyages par jour sur 14 jours, répartition par mode) dans un SurfaceGui de la console, pendant la V11.1.

## V11.1.2 — Écrans de la console : journal de l'équipage

### 96. Journal de l'équipage

*Qui est entré, sorti, a piloté et a réparé, dans la tablette.*

- **Déjà fait :** partiel — Les entrées et sorties existent déjà : TardisExtras.server.lua:147-151 ajouterRegistre (attribut « Registre », 40 lignes) appelé à :199 et :224, affiché dans la tablette par l'outil Registre (TardisTablette/Outils.lua:332-358, 14 lignes). Le pilotage est seulement en partie suivi : TardisServeur/init.server.lua:1856, :1899 et :2039 notent « décollage / atterrissage demandé par X », mais uniquement vers la supervision et RoSysLog (TardisSupervision.server.lua:133), pas dans la tablette. Le journal de la tablette (TardisTablette/Journal.lua:53-57) note seulement « Vol libre : X prend les commandes ». Pour les réparations : TechDernier (TardisSystemes.server.lua:1135, :1142) n'est affiché que dans la tablette technicien (TabletteTechnicien.lua:401) ; MaintenancePar existe (TardisSystemes.server.lua:1243) ; la réparation au rotor (TardisSystemes.server.lua:139-146) et les outils ne notent pas qui a réparé.
- **Fichiers :** `src/ServerScriptService/TardisExtras.server.lua`, `src/ServerScriptService/TardisServeur/init.server.lua`, `src/ServerScriptService/TardisSystemes.server.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisTablette/Outils.lua`
- **Dépend de :** —
- **Dans Studio :** Rien en V6.9.x. En V11.1 : la Part ou l'écran de console qui portera le journal (SurfaceGui), à placer dans Studio.
- **Feuille de route :** La proposition dit « dans la tablette », que la V11.4 retire. La V11.1 prévoit déjà un écran « journal » sur la console. Il faut donc écrire maintenant seulement la partie serveur (les données) et l'afficher sur l'écran de la console. Recoupe la proposition 129 (historique des pannes, avec qui a réparé) et la proposition 113 (journal des régénérations) : mieux vaut un seul journal d'équipage avec des catégories qu'en faire trois. Penser à la proposition 180 (moins d'attributs répliqués).
- **Effort :** moyen · **Risque :** faible
- **Approche :** Transformer le Registre de TardisExtras en « JournalEquipage » serveur : lignes heure, nom (rôle), type (entré, sorti, a piloté, a réparé, maintenance), publiées dans un seul attribut (40 lignes maximum). Les points d'écriture passent par le pont interne (interne("journalEquipage", …)) depuis les endroits qui envoient déjà journal("Voyage", …) dans TardisServeur et depuis la réparation au rotor et les outils dans TardisSystemes (ajouter le joueur, qui manque aujourd'hui). L'affichage se fait sur l'écran journal de la console en V11.1. En attendant, on peut l'afficher en lecture seule dans l'outil Registre existant, sans créer de nouvel onglet dans la tablette.

### 113. Journal des régénérations détaillé

*Lieu, heure, style et avatar avant/après dans la tablette.*

- **Déjà fait :** partiel — Le journal existe déjà : noterRegeneration (TardisSystemes.server.lua:478-485) note l'heure (os.date), le nom, le pseudo, la nature, le lieu (seulement le nom du TARDIS ou « Hors du TARDIS ») et le numéro, 40 entrées au plus, publiées dans l'attribut ReplicatedStorage.TardisRegenerations. La tablette les affiche en texte (TardisTablette/Outils.lua:544-570). Il manque le style, l'avatar avant et après, et un lieu précis hors du TARDIS. L'origine de l'avatar n'est écrite que dans l'Output (:455, :459).
- **Fichiers :** `src/ServerScriptService/TardisSystemes.server.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisTablette/Outils.lua`
- **Dépend de :** —
- **Dans Studio :** Rien.
- **Feuille de route :** L'affichage est dans l'outil Régénérations de la tablette Y, que la V11 supprime : le refaire ou l'enrichir maintenant serait jeté. Seul l'enrichissement des données côté serveur se garde.
- **Effort :** petit · **Risque :** faible
- **Approche :** noterRegeneration renvoie l'entrée créée. derouler() y ajoute `style` (le nom tiré de la liste des styles), `avant` (derniereTenue avant le tirage) et, dans changerApparence, `apres` (l'identifiant et la source de l'avatar appliqué), puis republie l'attribut. Hors du TARDIS, prendre comme lieu la destination ou la zone la plus proche si la configuration en fournit. À l'affichage (sur la console en V11), utiliser des vignettes `rbxthumb://type=Outfit&id=X&w=150&h=150` pour les avatars du compte et `type=AvatarHeadShot` pour ceux du jeu. Attention : les identifiants d'avatars deviennent visibles par tous les clients ; c'est acceptable puisque le joueur les a partagés, mais il faut le savoir.

### 106. Compteur de régénérations visible

*Le nombre de régénérations du joueur dans sa fiche.*

- **Déjà fait :** partiel — Le compteur existe seulement en mémoire sur le serveur : regenerations[UserId] (TardisSystemes.server.lua:328), augmenté à :716-718, remis à zéro à la vraie mort (:788). Il est visible seulement dans le message de chat « Régénération n°X » (:744) et dans les numéros du journal (TardisTablette/Outils.lua:560-561). Il n'est pas dans la fiche du joueur : la partie STATISTIQUES des réglages (TardisTablette/Volet.lua:195-220) n'affiche que voyages, temps de vol et passagers (statistiques à TardisExtras.server.lua:721-760). Il n'est ni sauvegardé ni publié en attribut.
- **Fichiers :** `src/ServerScriptService/TardisSystemes.server.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisTablette/Volet.lua`, `src/ServerScriptService/TardisSauvegarde.lua`
- **Dépend de :** —
- **Dans Studio :** Rien.
- **Feuille de route :** L'affichage prévu (fiche, réglages de la tablette Y) disparaît en V11. Une fiche personnelle sur une console partagée est à repenser avec la V11. La proposition 76 (onglet Statistiques de la tablette) a le même conflit.
- **Effort :** petit · **Risque :** faible
- **Approche :** Côté serveur : à chaque changement du compteur, publier joueur:SetAttribute("TardisRegenNombre", n). Si on veut aussi un total sur toute la vie du joueur, le sauvegarder avec TardisSauvegarde sous une clé "regen_<UserId>", directement dans TardisSystemes, puisque seul l'exemplaire du premier TARDIS gère la régénération. Côté client : une ligne « Régénérations : n (cycle) · total : m ». On peut ajouter la donnée dès maintenant ; l'afficher dans la tablette ne vaut la peine que si on accepte de le refaire en V11.

## V11.1.3 — Écrans de la console : parasites et panne d'écrans

### 64. Console qui réagit aux pannes

*Fumée, étincelles et écrans qui grésillent selon la panne en cours.*

- **Déjà fait :** partiel — Certaines réactions existent déjà. Incendie : feu et fumée sur 3 pièces de la console (src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Systemes.lua:14-37). Surcharge de vapeur : jet constant à la grille en panne (src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Ambiance.lua:296-330). Régénération à bord : étincelles sur la console (Regeneration.lua:881-898). Arcs statiques (Systemes.lua:52-66). Il manque les étincelles et la fumée pour Avarie et RedemarrageRequis, et tout grésillement d'écran : les écrans Diagnostic1-4 (Ambiance.lua:335-379) ne font que passer le titre en rouge hors tension.
- **Fichiers :** `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Systemes.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Ambiance.lua`, `src/ReplicatedStorage/TardisConfig.lua`
- **Dépend de :** 118, 119, 120
- **Dans Studio :** Facultatif : placer dans la console des Attachments nommés (par exemple dossier « PointsPanne » avec « Fumee », « Etincelles ») pour choisir où sortent les effets ; sans eux, le script prend des pièces au hasard comme pour l'incendie.
- **Feuille de route :** La V11.1 crée les écrans de la console : le grésillement doit s'appliquer à ces écrans, donc le faire une seule fois dans le module d'écrans de la V11. Recoupe la panne n°120 (écrans morts) : partager le même effet de parasites. Respecter aussi 47 (réduction des effets), 191 (pas de flash) et 178 (effets coupés loin).
- **Effort :** moyen · **Risque :** faible
- **Approche :** Créer côté client une table « panne → réaction » (attribut surveillé, intensité de fumée, rythme d'étincelles, parasites d'écran), branchée sur Incendie, VapeurSurcharge, Avarie, RedemarrageRequis puis les pannes 118 à 120. Réutiliser les émetteurs existants (Systemes.lua) au lieu d'en créer de nouveaux. Pour les écrans : un petit helper qui fait vibrer la position des textes, ajoute un Frame de bruit qui clignote et brouille quelques caractères tant qu'une panne est active, appelé par les écrans Diagnostic et par ceux de la V11.1. Tout est local, sans RemoteEvent, donc aucun impact sur la sécurisation.

### 120. Nouvelle panne : écrans morts

*Les écrans de la console s'éteignent, l'interface affiche des parasites.*

- **Déjà fait :** rien — Écrans actuels, sans aucune panne d'écran : écran de la console côté serveur (SurfaceGui et majEcran, src/ServerScriptService/TardisServeur/init.server.lua:134-145 et 226-243), ligne vivante (src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Ambiance.lua:131-165), écrans Diagnostic1 à Diagnostic4 (Ambiance.lua:336-380). Ils ne réagissent qu'à Alimentation. UI.lignesEcran (src/ReplicatedStorage/TardisUI.lua:227) pourrait servir de base aux parasites.
- **Fichiers :** `src/ServerScriptService/TardisSystemes.server.lua`, `src/ServerScriptService/TardisServeur/init.server.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Ambiance.lua`, `src/ReplicatedStorage/TardisUI.lua`, `src/ReplicatedStorage/TardisConfig.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/TabletteTechnicien.lua`
- **Dépend de :** 117, 64
- **Dans Studio :** Rien d'obligatoire : l'écran de la console (Console > Ecran) existe et Diagnostic1 à 4 sont facultatifs. À la V11.1, les nouveaux écrans de la console placés dans Studio seront aussi touchés. Facultatif : un Sound « Parasites ».
- **Feuille de route :** Conflit direct pour la partie « l'interface affiche des parasites » : mettre des parasites dans le menu T et la tablette Y, c'est travailler sur des interfaces que la V11.4 supprime. Les écrans de la console qui remplacent ces menus n'arrivent qu'à la V11.1. Le sujet recoupe aussi la proposition 64 gardée (« écrans qui grésillent selon la panne ») : à faire ensemble.
- **Effort :** moyen · **Risque :** moyen
- **Approche :** Côté serveur, ajouter panneEcrans() (attribut EcransMorts) au tirage de la 117. On la répare par un prompt « Réinitialiser les écrans » sur la console (visseuse en main ou E maintenu), ou par un redémarrage depuis la tablette technicien. Côté client, faire un module commun d'effet parasites (bruit et bandes animées sur un SurfaceGui), utilisé par tous les écrans de la console : ceux de la V11.1, majEcran, la ligne vivante, Diagnostic1-4. Pas de parasites sur T et Y. Les commandes ne doivent jamais être bloquées, seuls les affichages sont touchés.

## V11.2 — Boutons de navigation de la console

### 137. Bips de la console

*Des petits sons quand on touche la console.*

- **Déjà fait :** rien — Aucun son quand on touche la console : creerPrompt (src/ServerScriptService/TardisServeur/init.server.lua:1035-1044, invites du Sélecteur et du Levier) et le clic sur le rotor (src/ServerScriptService/TardisExtras.server.lua:846-866, étincelles seulement) ne jouent rien. Le seul « bip » existant est la notification d'interface (TardisUI.lua:620, utilisée par le compte à rebours Signalisation.lua:50).
- **Fichiers :** `src/ServerScriptService/TardisServeur/init.server.lua`, `src/ServerScriptService/TardisExtras.server.lua`, `src/ReplicatedStorage/TardisConfig.lua`
- **Dépend de :** —
- **Dans Studio :** Rien à construire. Optionnel : un Sound « Bip_Console » dans TardisAssets › Sons. Sinon, repli sur un son intégré à Roblox (rbxasset://sounds/electronicpingshort.wav), comme Config.SonsInterface.
- **Feuille de route :** Pas de conflit, mais un lien fort avec la V11. Les V11.2 et V11.3 créent tous les boutons physiques de la console : le bip doit faire partie de l'utilitaire commun de ces boutons. Fait avant la V11, il ne couvrirait que le Sélecteur, le Levier et le rotor.
- **Effort :** petit · **Risque :** faible
- **Approche :** Côté serveur, dans creerPrompt (et plus tard dans l'utilitaire des boutons de la V11), relier Triggered à la lecture d'un clone de « Bip_Console » posé sur la pièce touchée (RollOffMaxDistance d'environ 25). Les joueurs autour de la console l'entendent, pas seulement celui qui clique. Prévoir un petit délai minimal entre deux bips et une hauteur différente selon la commande (PlaybackSpeed).

### 77. Carte des destinations en grand

*Une carte plein écran avec tous les lieux, cliquable.*

- **Déjà fait :** partiel — src/StarterPlayer/StarterPlayerScripts/TardisTablette/Scanner.lua:74-155 : mini-carte vue du dessus, avec zoom automatique pour garder toutes les destinations visibles et des marqueurs cliquables qui choisissent la destination (:98-102). Elle affiche aussi les joueurs et le TARDIS fléché, et lit l'attribut CarteDestinations. Cadre de 226 × 226 px dans le widget Scanner (Construction.lua:479-506). Il n'existe aucune version en grand ou plein écran.
- **Fichiers :** `src/StarterPlayer/StarterPlayerScripts/TardisTablette/Scanner.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisTablette/Construction.lua`
- **Dépend de :** 51
- **Dans Studio :** Une grande pièce écran nommée, par exemple EcranCarte, sur la console ou au mur de la salle de contrôle, assez grande pour une carte lisible (environ 6 × 4 studs). Le script y crée le SurfaceGui et les marqueurs cliquables.
- **Feuille de route :** Une carte plein écran ouverte depuis la tablette Y disparaîtrait en V11.4. La feuille de route prévoit déjà un écran « radar / mini-carte » sur la console en V11.1 et les boutons de destination en V11.2 : cette proposition doit devenir la version grand format de cet écran. Après la V10, il faudra aussi choisir si la carte montre les deux autres TARDIS officiels.
- **Effort :** moyen · **Risque :** moyen
- **Approche :** Sortir de Scanner.lua la logique de la carte (lecture de CarteDestinations, projection x/z, zoom automatique) pour en faire une fonction réutilisable dans TardisUI ou un module partagé, puis l'afficher dans un SurfaceGui grand format sur la console. Le clic sur un marqueur envoie le choix de destination, comme les boutons de la V11.2. Le risque moyen vient des clics sur un SurfaceGui (distance, caméra à la 1re personne, mobile).

### 138. Jukebox : file d'attente

*Ajouter des musiques à une file au lieu d'en jouer une seule.*

- **Déjà fait :** rien — Le jukebox joue une piste en boucle, ou une playlist par catégorie lue au hasard : src/ServerScriptService/TardisExtras.server.lua:1329-1350 (action Jukebox : index ou liste) ; src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Ambiance.lua:236-289 ; interface dans la tablette, src/StarterPlayer/StarterPlayerScripts/TardisTablette/Outils.lua:485-508. Pas de file d'attente. Défaut trouvé : chaque client mélange la playlist de son côté (Ambiance.lua:250-256, math.random), et l'attribut JukeboxDebut (TardisExtras.server.lua:1338) n'est lu par aucun client. Les passagers n'entendent donc pas la même musique au même moment. Config.Jukebox est vide (TardisConfig.lua:452-454).
- **Fichiers :** `src/ServerScriptService/TardisExtras.server.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Ambiance.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisTablette/Outils.lua`, `src/ReplicatedStorage/TardisConfig.lua`
- **Dépend de :** —
- **Dans Studio :** Aucune construction tant que l'interface reste dans la tablette. Remplir Config.Jukebox avec des ID publics. En V11 : une pièce écran et des boutons « jukebox » nommés sur la console (ou ailleurs dans la salle).
- **Feuille de route :** L'interface du jukebox (surcouche dans Outils.lua) est dans la tablette Y, que la V11.4 supprime. Le jukebox ne figure pas dans les V11.1 à V11.3 : son emplacement sur la console reste à décider. Faire l'interface de la file une seule fois, sur la console.
- **Effort :** moyen · **Risque :** moyen
- **Approche :** Le serveur tient la file (attribut JukeboxFile en JSON, 10 pistes au maximum, actions Ajouter, Retirer et Passer réservées aux pilotes). Il publie la piste en cours (Jukebox + JukeboxDebut) et passe à la suivante à la fin, d'après Sound.TimeLength lu côté serveur, ou un champ duree dans Config.Jukebox en repli. Les clients se calent sur TimePosition = maintenant − JukeboxDebut, ce qui corrige aussi le décalage actuel entre joueurs. La logique serveur peut être écrite avant la V11 ; l'interface vient avec la console.

## V11.3 — Boutons des systèmes : énergie, Artron et décoratifs

### 17. Carburant temporel (Artron)

*Une jauge qui baisse à chaque voyage selon le mode et se recharge posé.*

- **Déjà fait :** rien — Aucune jauge Artron ni de carburant. Systèmes proches déjà présents : le compteur de voyages consécutifs avec coupure (TardisSystemes.server.lua:250-270, VoyagesAvantCoupure dans TardisConfig.lua:602), la saleté par voyage (même endroit), l'énergie du bouclier (TardisSystemes.server.lua:159-171), la régulation de l'énergie par les techniciens (RegulEnergie, TardisSystemes.server.lua:1110-1140) et les jauges de la tablette technicien (TabletteTechnicien.lua:203-219).
- **Fichiers :** `src/ReplicatedStorage/TardisConfig.lua`, `src/ServerScriptService/TardisSystemes.server.lua`, `src/ServerScriptService/TardisServeur/init.server.lua`, `src/ServerScriptService/TardisServeur/VolLibre.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/TabletteTechnicien.lua`
- **Dépend de :** —
- **Dans Studio :** Rien d'obligatoire. Avec la V11 : un écran (Part nommée avec SurfaceGui) sur la console pour afficher la jauge.
- **Feuille de route :** Afficher la jauge dans le menu T ou la tablette Y serait du travail jeté en V11 : l'affichage « énergie » fait déjà partie des écrans de console prévus en V11.1. Il y a aussi un risque de doublon avec RegulEnergie, la coupure après N voyages et la proposition gardée 131 (énergie partagée entre systèmes) : les concevoir ensemble, l'Artron pouvant servir de réserve des « moteurs » pour la 131. Avec la V10, une jauge par TARDIS.
- **Effort :** moyen · **Risque :** moyen
- **Approche :** Ajouter Config.Artron (Max, Cout par mode, Recharge par minute une fois posé et alimenté). Côté serveur : retirer le coût à l'entrée de decoller (et au décollage du vol libre), puis publier l'attribut Artron. Si la jauge est trop basse, ne jamais bloquer les pilotes : forcer l'Urgence ou n'autoriser que le Classique, avec un message. Faire la recharge dans la boucle de TardisSystemes, sauvegarder la valeur avec le reste et la montrer dans une jauge de la tablette technicien, puis sur l'écran de la console en V11.

### 131. Énergie partagée entre systèmes

*Répartir l'énergie entre boucliers, moteurs et vie à bord.*

- **Déjà fait :** partiel — Il existe un seul curseur d'énergie globale, RegulEnergie (TardisSystemes.server.lua:1109-1135, Config.Technicien.Regulation, TardisConfig.lua:583). Il ne sert qu'à deux choses : la lumière de la salle (TardisEffets.client.lua:491-493) et le risque de surtension vers une fuite de vapeur (TardisSystemes.server.lua:1214-1218). L'énergie des boucliers (BouclierEnergie) est séparée : elle ne dépend que des tirs (:152-172). Rien ne lie l'énergie aux moteurs (décollage ou vitesse du vol libre) ni à la vie à bord (l'air s'use de façon fixe, :1196-1212).
- **Fichiers :** `src/ServerScriptService/TardisSystemes.server.lua`, `src/ServerScriptService/TardisServeur/init.server.lua`, `src/ServerScriptService/TardisServeur/VolLibre.lua`, `src/ReplicatedStorage/TardisConfig.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/TabletteTechnicien.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisEffets.client.lua`
- **Dépend de :** 156, 157
- **Dans Studio :** Si les commandes sont sur la console (V11.3) : des pièces nommées pour trois curseurs ou leviers (Boucliers, Moteurs, Vie) et un écran de répartition (SurfaceGui). Sinon, rien.
- **Feuille de route :** Si les commandes sont faites avant la V11, elles iraient dans les curseurs de la tablette technicien (Y), à refaire sur la console en V11.3 (« boutons des systèmes… énergie »). La proposition recoupe aussi le carburant Artron (17, gardée) pour les « moteurs » : il faut décider qui des deux limite les voyages. Une nouvelle action « Repartir » avec des valeurs doit passer par le garde-barrière et le schéma de la V7.
- **Effort :** gros · **Risque :** élevé
- **Approche :** Remplacer RegulEnergie par trois parts (Boucliers, Moteurs, Vie) dont le total vaut 100 (ou la tension). Le serveur les valide et les publie en attributs RepartBoucliers, RepartMoteurs, RepartVie. Les brancher ensuite : la recharge et l'encaissement de BouclierEnergie, la vitesse maximale du vol libre et la durée du voyage (ou la consommation d'Artron de la 17), l'usure de l'air et la lumière. Prévoir des valeurs par défaut qui donnent exactement le comportement actuel, l'écran de répartition et les leviers de la console en V11.3, et une simulation dans outils/simulation pour équilibrer.

### 66. Interrupteurs physiques décoratifs

*Des leviers et boutons qui bougent quand on les touche (sans commande).*

- **Déjà fait :** rien — Aucun interrupteur décoratif. Ce qui s'en rapproche le plus est le rotor interactif : ClickDetector sur chaque pièce, étincelles et attribut RotorBoost, sans commande (src/ServerScriptService/TardisExtras.server.lua:836-870). Les leviers de la console (Config.Chemins, TardisConfig.lua:28-37) sont fonctionnels et ne bougent pas par script.
- **Fichiers :** `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Decor.lua`, `src/ServerScriptService/TardisExtras.server.lua`, `src/ReplicatedStorage/TardisConfig.lua`
- **Dépend de :** —
- **Dans Studio :** Placer dans la console un dossier « Decoratifs » avec des Models nommés par type (« LevierDeco », « BoutonDeco », « InterrupteurDeco »), chacun avec une PrimaryPart servant de pivot, orientée pour que la rotation ou l'enfoncement se fasse dans le bon axe.
- **Feuille de route :** La V11.2 et la V11.3 ajoutent de vrais boutons physiques sur la console. Il faut un seul helper d'animation (bouton qui s'enfonce, levier qui bascule) pour les deux, et des noms séparés pour ne pas prendre un emplacement prévu pour une vraie commande ni tromper le pilote. À faire avec la V11, pour réserver d'abord les emplacements des vraies commandes.
- **Effort :** petit · **Risque :** faible
- **Approche :** Serveur : ClickDetector sur chaque Model du dossier « Decoratifs » (sur le modèle du rotor, TardisExtras.server.lua:836-870), avec une limite de fréquence par joueur, qui écrit un attribut « DecoClic » (index et heure serveur). Client (Decor.lua) : à chaque changement, animation locale par TweenService d'un CFrameValue appliqué par PivotTo (bascule de 30° puis retour, ou enfoncement de 0,1 stud), plus le bip de la console (137) si elle existe. Aucune commande derrière, donc aucun contrôle de rôle nécessaire.

## V11.4 — Retrait de T et Y sur TARDIS_1 : ce qui reste à l'écran

### 101. Couleurs d'équipe dans le chat

*Noms colorés selon l'équipe dans les messages du TARDIS.*

- **Déjà fait :** rien — Les messages du TARDIS ne passent pas par le chat Roblox. Ils partent de dire() (TardisExtras.server.lua:35-37 : remote:FireClient avec du texte brut) et s'affichent en notifications dans le menu T (TardisMenu.client.lua:700, seulement si le menu est ouvert), la tablette (TardisTablette/Etat.lua:40-49, texte sans RichText), le poste du copilote (Copilote.lua:221) et la tablette technicien (TabletteTechnicien.lua:780). Briques existantes : TardisUI.lua:591 UI.couleurJoueur (couleur de la Team) et un précédent de message coloré dans le chat, Intercom.lua:70-72 (DisplaySystemMessage avec <font color>), mais l'intercom est en commentaire.
- **Fichiers :** `src/ReplicatedStorage/TardisUI.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Preferences.lua`, `src/ReplicatedStorage/TardisConfig.lua`
- **Dépend de :** —
- **Dans Studio :** Rien. Il faut seulement que les Teams C.A.T. et C.T.A.T. aient des TeamColor différentes dans Studio › Teams (la C.T.A.T. créée par le script est en Deep orange).
- **Feuille de route :** Colorer les noms dans les notifications du menu T et de la tablette Y serait perdu à la V11.4 (ces notifications disparaissent avec les menus). Il faut colorer dans le chat (TextChatService), qui reste après la V11 et peut même remplacer ces notifications. Ne pas toucher au chat normal des joueurs : Roblox le colore normalement déjà selon la Team.
- **Effort :** petit · **Risque :** faible
- **Approche :** Ajouter UI.colorerNoms(message) dans TardisUI : pour chaque joueur dont la Team est C.A.T. ou C.T.A.T., remplacer son DisplayName (motif échappé) par <font color="#RRGGBB">nom</font>, en échappant les caractères RichText du reste du texte. Un seul module client (garde « premier TARDIS ») recopie les messages reçus par remote.OnClientEvent dans TextChannels.RBXGeneral:DisplaySystemMessage("[TARDIS] " .. UI.colorerNoms(message)), avec Config.MessagesDansLeChat = true. Les messages techniques (préfixe « __ ») sont ignorés et les répétitions limitées pour ne pas inonder le chat. À faire au moment de la V11.4, quand les notifications des menus disparaissent.

### 192. Manette : navigation des menus

*Parcourir le menu et la tablette à la manette.*

- **Déjà fait :** rien — La manette n'est gérée que pour la caméra (TardisCamera.client.lua:104, ButtonB en :187) et le vol libre (TardisVolLibre.client.lua:850/860/899 : ButtonA/Y/X). Aucune navigation des menus : pas de GuiService.SelectedObject ni de ContextActionService. Le menu T et la tablette Y ne s'ouvrent qu'au clavier (TardisMenu.client.lua:704-707, TardisTablette/Volet.lua:304-308) ou par les boutons tactiles.
- **Fichiers :** `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Copilote.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisExtrasClient/TabletteTechnicien.lua`, `src/ReplicatedStorage/TardisUI.lua`, `src/StarterPlayer/StarterPlayerScripts/TardisCamera.client.lua`
- **Dépend de :** 193
- **Dans Studio :** —
- **Feuille de route :** Conflit direct : la proposition vise le menu T et la tablette Y, que la V11.4 supprime. Les boutons de console de la V11 (ProximityPrompt) se pilotent déjà nativement à la manette. Il ne restera que les interfaces à l'écran encore ouvertes (copilote, tablette technicien, panneau de réglages ; question ouverte de la V11). Attention aussi : ButtonB sert déjà à la caméra (TardisCamera.client.lua:187).
- **Effort :** moyen · **Risque :** moyen
- **Approche :** Ne rien faire sur T et Y. À la V11.4, pour chaque interface à l'écran qui reste, sélectionner le premier bouton à l'ouverture (GuiService.SelectedObject), fermer avec ButtonB par ContextActionService pendant que l'interface est ouverte (ce qui évite le conflit avec la caméra), et ouvrir le panneau de réglages avec une touche de manette. Vérifier que les ProximityPrompt de la console affichent bien leur touche de manette.

### 29. Mobile : joystick virtuel

*Un vrai joystick tactile pour le vol libre sur téléphone.*

- **Déjà fait :** partiel — src/StarterPlayer/StarterPlayerScripts/TardisVolLibre.client.lua:1121-1126 (la direction vient de PlayerModule:GetControls():GetMoveVector(), donc le joystick tactile natif de Roblox pilote déjà le vol sur téléphone), :1576-1579 (échelle du tableau de bord et des boutons selon l'écran) ; docs/patch-notes/V3.md:148 (« stick ou joystick mobile pour se déplacer »). Il manque une commande verticale tactile (on ne monte et ne descend qu'en inclinant la caméra, ce qui demande un deuxième doigt) et un joystick dédié au vol : on garde le stick générique, et le bouton Sauter de Roblox ne sert à rien en vol.
- **Fichiers :** `src/StarterPlayer/StarterPlayerScripts/TardisVolLibre.client.lua`, `src/ReplicatedStorage/TardisUI.lua`, `src/ReplicatedStorage/TardisConfig.lua`
- **Dépend de :** —
- **Dans Studio :** —
- **Feuille de route :** Conflit possible avec la V11 : la feuille de route laisse ouvertes les questions « le vol libre » et « les joueurs sur mobile ». Si la V11 change la façon de lancer ou d'afficher le vol libre, l'interface tactile sera à revoir. La V9 découpera TardisVolLibre (≈ 1 600 lignes) : un module à part (par exemple JoystickTactile) se déplacera sans peine.
- **Effort :** moyen · **Risque :** moyen
- **Approche :** Seulement si UserInputService.TouchEnabled et pas de clavier (même test que TardisMenu.client.lua:713, Config.BoutonsTactiles) : afficher pendant le pilotage un joystick à gauche (un cadre Active qui capte le toucher, pour que la caméra ne tourne pas) et une glissière MONTER / DESCENDRE à droite. Masquer les commandes tactiles de Roblox pendant le vol et les rendre à la sortie dans sortirPilotage. Dans piloter(), le vecteur du joystick remplace GetMoveVector et la glissière ajoute la composante verticale. Le risque vient des conflits de toucher entre le joystick, la rotation de la caméra et les 21 boutons du tableau de bord : à tester sur un vrai téléphone. Pas pressé : le joystick natif fonctionne déjà.

### 84. Aide intégrée

*Une page d'aide dans la tablette qui explique chaque fonction.*

- **Déjà fait :** partiel — Une page AIDE existe déjà : bouton « ? » à TardisTablette/Construction.lua:229 (W.btnAide), contenu à TardisTablette/Volet.lua:284-299 (8 blocs : menus, voyager, porter, vol libre, rotation, outils, balise, boucliers). Elle est incomplète et en partie fausse : elle place les outils dans le « menu classique, section Outils » et parle d'une « tuile Rotation du menu », alors que ces tuiles sont dans la tablette (TardisTablette/Outils.lua:42-63). Elle ne parle ni du copilote, ni du carnet, ni de la maintenance, ni du siège, ni des modes Sauvetage et Silencieux, ni de l'énergie et des pannes
- **Fichiers :** `src/StarterPlayer/StarterPlayerScripts/TardisTablette/Volet.lua`, `src/ReplicatedStorage/TardisConfig.lua`
- **Dépend de :** —
- **Dans Studio :** —
- **Feuille de route :** La page vit dans la tablette Y (retirée en V11.4) et décrit des boutons du menu T et de la tablette, qui passent sur la console en V11. Une aide complète écrite maintenant serait à réécrire. Elle peut partager son contenu avec la n° 200 (glossaire).
- **Effort :** moyen · **Risque :** faible
- **Approche :** Tout de suite (P) : corriger les deux lignes fausses de Volet.lua:290-291. Pour la vraie aide : sortir le contenu dans une table de données partagée (par exemple Config.Aide, ou un module ReplicatedStorage à part après la V9), avec une entrée par fonction (titre, à quoi ça sert, conditions : posé, alimenté, rôle). La page de la tablette et, en V11, un écran ou un bouton « ? » de la console liront cette même table. On pourra y ranger le glossaire (n° 200).
