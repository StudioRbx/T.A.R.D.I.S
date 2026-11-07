#!/bin/sh
# Lance l'analyse statique puis toutes les simulations.
# (V7.1.1, T-201) Le script échoue (code 1) dès qu'une étape échoue, et nomme celles qui ont échoué à la fin.
# (V7.1.2, T-202) Simulations rangées par sujet : `sh outils/simulation/lancer.sh voyage` ne lance que celles du sujet
# « voyage » (ou une seule simulation par son nom). Sans sujet : l'analyse statique et tout. Sujets : voir sujets() plus bas.
cd "$(dirname "$0")/../.." || exit 1
PY=python3
command -v "$PY" >/dev/null 2>&1 && "$PY" -c "" >/dev/null 2>&1 || PY=python
export PYTHONIOENCODING=utf-8
filtre="$1"

# Index par sujet : chaque simulation et les sujets qu'elle couvre.
sujets() {
	case "$1" in
		sim_config) echo "base config" ;;
		sim_modules) echo "base sauvegarde commandes voyage" ;;
		sim_supervision) echo "equipage supervision" ;;
		sim_voyage) echo "voyage vollibre destinations secours" ;;
		sim_effets) echo "effets voyage cabine" ;;
		sim_outils) echo "outils interface theme formation" ;;
		sim_v6910) echo "voyage vollibre camera effets" ;;
		sim_v69101) echo "console ecrans effets serveur jukebox" ;;
		sim_v69102) echo "interieur portail streaming" ;;
		sim_v69103) echo "console ecrans" ;;
		sim_v69104) echo "console ecrans" ;;
		sim_v69105) echo "console camera tenues jukebox" ;;
		sim_v69106) echo "interface tablette menu" ;;
		sim_v69107) echo "interface console jukebox" ;;
		sim_v69108) echo "console invites" ;;
		sim_v69109) echo "leurre voyage" ;;
		sim_v6911) echo "navigation destinations voyage" ;;
		sim_v6912) echo "pannes" ;;
		sim_v6913) echo "pannes outils technicien" ;;
		sim_v6914) echo "equipage tenues portes" ;;
		sim_v6915) echo "interface accessibilite menu tablette" ;;
		sim_v6916) echo "console ecrans invites" ;;
		sim_v6917) echo "streaming interieur diagnostic" ;;
		sim_v711) echo "outils equipage autodestruction effets" ;;
		sim_v712) echo "banc demarrage serveur client streaming pieces" ;;
		sim_v721) echo "effets cabine vitres lampe maintenance" ;;
		sim_v722) echo "sol marque givre brume terrain vent cercle salete poussiere" ;;
		sim_v723) echo "eau rides vapeur gerbe sillage nettoyage pluie remontee" ;;
		sim_v724) echo "saisons decorations salle toit neige feuilles eclair orage" ;;
		sim_v731) echo "surchauffe vapeur grilles lueur rotor surmene chaleur cabine courbe moteur" ;;
		sim_v732) echo "jukebox equipage copilote technicien lumieres musique cables plafond style vague" ;;
		sim_paquet) echo "paquet studio synchro" ;;
		*) echo "" ;;
	esac
}

echecs=""
lancees=0
if [ -z "$filtre" ] || [ "$filtre" = "analyse" ]; then
	echo "=== Analyse statique (portées et vérifications croisées) ==="
	"$PY" outils/simulation/analyse.py . || echecs="$echecs analyse"
	lancees=1
fi
for s in sim_config sim_modules sim_supervision sim_voyage sim_effets sim_outils sim_v6910 sim_v69101 sim_v69102 sim_v69103 sim_v69104 sim_v69105 sim_v69106 sim_v69107 sim_v69108 sim_v69109 sim_v6911 sim_v6912 sim_v6913 sim_v6914 sim_v6915 sim_v6916 sim_v6917 sim_v711 sim_v712 sim_v721 sim_v722 sim_v723 sim_v724 sim_v731 sim_v732 sim_paquet; do
	if [ -n "$filtre" ] && [ "$s" != "$filtre" ] && ! sujets "$s" | grep -qw -- "$filtre"; then continue; fi
	lancees=$((lancees + 1))
	echo; echo "=== $s ($(sujets "$s")) ==="
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
if [ $lancees -eq 0 ]; then
	echo "ÉCHEC : aucune simulation pour le sujet « $filtre »"
	exit 1
fi
if [ -n "$echecs" ]; then
	echo "ÉCHEC :$echecs"
	exit 1
fi
echo "Tout est passé."
