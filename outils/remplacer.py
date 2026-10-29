"""Remplacements exacts dans un fichier, avec vérification du nombre d'occurrences.

Usage : python outils/remplacer.py <fichier_de_remplacements.py>
Le fichier définit R = [(chemin, ancien, nouveau, nombre_attendu), ...]. Rien n'est écrit si un remplacement échoue.
"""
import os
import runpy
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main():
    R = runpy.run_path(sys.argv[1])["R"]
    contenus = {}
    for chemin, ancien, nouveau, nombre in R:
        if chemin not in contenus:
            contenus[chemin] = open(os.path.join(RACINE, chemin), encoding="utf-8", newline="").read()
        trouve = contenus[chemin].count(ancien)
        if trouve != nombre:
            sys.exit("ÉCHEC (rien n'est écrit) : %s, %d occurrence(s) au lieu de %d :\n%s" % (chemin, trouve, nombre, ancien[:200]))
        contenus[chemin] = contenus[chemin].replace(ancien, nouveau)
    for chemin, texte in contenus.items():
        open(os.path.join(RACINE, chemin), "w", encoding="utf-8", newline="").write(texte)
        print("modifié :", chemin)


if __name__ == "__main__":
    main()
