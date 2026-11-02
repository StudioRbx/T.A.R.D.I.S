# Simulations du TARDIS (sans Roblox)

Outils écrits en Python, sans rien télécharger, pour vérifier le code avant de l'installer dans Studio.

- `analyse.py` : **analyse statique** de tous les scripts.
  - Portées : toute variable lue ou écrite sans être déclarée (faute de frappe, fonction supprimée, fonction appelée avant sa déclaration).
  - Vérifications croisées : actions envoyées par les clients et traitées par un serveur, réglages `Config.X`, attributs lus et écrits, `UI.X`, `Commandes.X`, contexte des modules, pont interne.
- `luau.py` : un **petit interpréteur Luau** en Python (le sous-ensemble utilisé par le TARDIS).
- `roblox.py`, `monde.py` : de **faux objets Roblox** (instances, attributs, signaux, services, DataStore avec pannes simulées, `task.wait` / `task.delay` en temps virtuel).
- `sim_config.py` : charge `TardisConfig` et teste ses fonctions (modes, durées, souffles, maintenance, pilotes, équipes).
- `sim_modules.py` : `TardisSauvegarde` (enveloppe, migration, pannes) et `TardisCommandes` (vortex de 10 s, REMAT manuelle, paradoxe, modes, poche, petit TARDIS).
- `sim_supervision.py` : `TardisSupervision` (rôle de technicien de la C.T.A.T., balise `/tardis help`, plus de commandes du staff).

Lancer tout : `sh outils/simulation/lancer.sh` (depuis la racine du dépôt).

Limites : ce n'est pas Roblox. La physique, l'affichage, les effets et le réseau ne sont pas simulés ; seuls la logique et les échanges le sont. Les tests en jeu restent nécessaires.
