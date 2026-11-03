#!/bin/sh
# Lance toutes les simulations du TARDIS (sans Roblox) depuis la racine du dépôt : sh outils/simulation/lancer.sh
cd "$(dirname "$0")/../.." || exit 1
echo "=== Analyse statique (portées et vérifications croisées) ==="; python3 outils/simulation/analyse.py .
for s in sim_config sim_modules sim_supervision sim_v697; do
	echo; echo "=== $s ==="; python3 outils/simulation/$s.py | tail -1
done
