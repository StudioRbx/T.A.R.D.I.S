#!/bin/sh
# Lance toutes les simulations du TARDIS (sans Roblox) depuis la racine du dépôt : sh outils/simulation/lancer.sh
cd "$(dirname "$0")/../.." || exit 1
echo "=== Analyse statique (portées et vérifications croisées) ==="; python3 outils/simulation/analyse.py .
for s in sim_config sim_modules sim_supervision sim_v697 sim_v698 sim_v699 sim_v6910 sim_v69101 sim_v69102 sim_v69103 sim_v69104 sim_v69105 sim_v69106 sim_v69107 sim_v69108 sim_v69109 sim_v6911 sim_v6912 sim_paquet; do
	echo; echo "=== $s ==="; python3 outils/simulation/$s.py | tail -1
done
