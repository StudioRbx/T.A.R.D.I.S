#!/bin/sh
# Lance l'analyse statique puis toutes les simulations.
# (V7.1.1, T-201) Le script échoue (code 1) dès qu'une étape échoue, et nomme celles qui ont échoué à la fin.
cd "$(dirname "$0")/../.." || exit 1
PY=python3
command -v "$PY" >/dev/null 2>&1 && "$PY" -c "" >/dev/null 2>&1 || PY=python
export PYTHONIOENCODING=utf-8
echecs=""
echo "=== Analyse statique (portées et vérifications croisées) ==="
"$PY" outils/simulation/analyse.py . || echecs="$echecs analyse"
for s in sim_config sim_modules sim_supervision sim_v697 sim_v698 sim_v699 sim_v6910 sim_v69101 sim_v69102 sim_v69103 sim_v69104 sim_v69105 sim_v69106 sim_v69107 sim_v69108 sim_v69109 sim_v6911 sim_v6912 sim_v6913 sim_v6914 sim_v6915 sim_v6916 sim_v6917 sim_v711 sim_paquet; do
	echo; echo "=== $s ==="
	sortie=$("$PY" outils/simulation/$s.py 2>&1)
	code=$?
	if [ $code -ne 0 ]; then
		echo "$sortie" | grep "✗\|Error\|Erreur" | head -20
		echo "$sortie" | tail -1
		echecs="$echecs $s"
	else
		echo "$sortie" | tail -1
	fi
done
echo
if [ -n "$echecs" ]; then
	echo "ÉCHEC :$echecs"
	exit 1
fi
echo "Tout est passé."
