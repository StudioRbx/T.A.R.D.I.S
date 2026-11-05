# Simulations du TARDIS (sans Roblox)

Outils écrits en Python, sans rien télécharger, pour vérifier le code avant de l'installer dans Studio.

- `analyse.py` : **analyse statique** de tous les scripts.
  - Portées : toute variable lue ou écrite sans être déclarée (faute de frappe, fonction supprimée, fonction appelée avant sa déclaration).
  - Vérifications croisées : actions envoyées par les clients et traitées par un serveur, réglages `Config.X`, attributs lus et écrits, `UI.X`, `Commandes.X`, contexte des modules, pont interne.
- `luau.py` : un **petit interpréteur Luau** en Python (le sous-ensemble utilisé par le TARDIS).
- `roblox.py`, `monde.py` : de **faux objets Roblox** (instances, attributs, signaux, services, DataStore avec pannes simulées, `task.wait` / `task.delay` en temps virtuel ; depuis la V6.9.9 : `Color3` calculable avec `Lerp`, `Debris:AddItem`, `:Emit`, `:ClearAllChildren`, `GetExtentsSize`, valeurs par défaut des pièces, lumières et effets).
- `sim_config.py` : charge `TardisConfig` et teste ses fonctions (modes, durées, souffles, maintenance, pilotes, équipes).
- `sim_modules.py` : `TardisSauvegarde` (enveloppe, migration, pannes) et `TardisCommandes` (vortex de 10 s, REMAT manuelle, paradoxe, modes, poche, petit TARDIS).
- `sim_supervision.py` : `TardisSupervision` (rôle de technicien de la C.T.A.T., balise `/tardis help`, plus de commandes du staff).
- `sim_v697.py` : corrections de la V6.9.7 (vol libre sans pilote, joueur visé parti, poche en Silencieux, chute dans le vide).
- `sim_v698.py` : V6.9.8 (thème clair recoloré et lisible, réglages du vol en formation, écran de destination, recherche du menu T, outils de release et d'état des tests, glossaire).
- `sim_v699.py` : V6.9.9, effets visuels du voyage. Le **vrai `TardisEffets` entier** et les vrais modules `EffetsExterieurs`, `Signalisation` et `AutoDestruction` tournent image par image dans un faux monde (cabine avec une vitre, lampe, salle, rotor, sol) : distorsion plus forte en Urgence (36), marque au sol (38), lueurs selon l'heure (46), lumières de la salle selon l'état (53), Catastrophe dehors (43), vitres qui s'éteignent en dernier (41), et chaque flash supprimé avec « aucun flash » (191).

- `sim_paquet.py` : le paquet .rbxmx pour Studio (`outils/paquet_studio.py`) et son installation (`outils/installer_paquet.luau`) sur une fausse place : scripts créés, réécrits seulement s'ils diffèrent, portes de chaque TARDIS, ancien nom supprimé, script inconnu signalé, paquet abîmé refusé.

Lancer tout : `sh outils/simulation/lancer.sh` (depuis la racine du dépôt).

Limites : ce n'est pas Roblox. La physique, l'affichage, les effets et le réseau ne sont pas simulés ; seuls la logique et les échanges le sont. Les tests en jeu restent nécessaires.
