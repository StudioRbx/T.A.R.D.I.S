"""Génère outils/manifeste.json : la liste des scripts de src/ avec leur emplacement Studio et leur empreinte.

Convention (celle de Rojo) :
  X.lua -> ModuleScript, X.server.lua -> Script, X.client.lua -> LocalScript
  dossier D/ contenant init(.server|.client).lua -> le script D, et les autres fichiers deviennent ses enfants

Le script Luau outils/synchro_studio.luau lit ce manifeste (servi par `python -m http.server`) et met Studio à jour.
"""
import json
import os
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(RACINE, "src")

# Scripts présents dans chaque TARDIS (portes) : appliqués à tous les TARDIS_n du Workspace
DOSSIER_PAR_TARDIS = "Workspace/TARDIS/TARDIS_x"

# Anciens noms à supprimer dans Studio (renommages)
SUPPRIMER = [
    "StarterPlayer/StarterPlayerScripts/Tardisporter",
]


def empreinte(octets):
    h = 0
    for c in octets:
        h = (h * 31 + c) % 2147483647
    return h


def classe_et_nom(fichier):
    for suffixe, classe in ((".server.lua", "Script"), (".client.lua", "LocalScript"), (".lua", "ModuleScript")):
        if fichier.endswith(suffixe):
            return classe, fichier[: -len(suffixe)]
    return None, None


def main():
    entrees = []
    for dossier, _, fichiers in os.walk(SRC):
        for f in sorted(fichiers):
            classe, nom = classe_et_nom(f)
            if not classe:
                continue
            chemin_fichier = os.path.relpath(os.path.join(dossier, f), RACINE).replace("\\", "/")
            parent = os.path.relpath(dossier, SRC).replace("\\", "/")
            if nom == "init":  # le dossier lui-même est le script
                parent, nom = os.path.dirname(parent), os.path.basename(parent)
            octets = open(os.path.join(dossier, f), "rb").read()
            entrees.append({
                "fichier": chemin_fichier,
                "parent": parent,          # chemin Studio du parent, à partir du DataModel
                "nom": nom,
                "classe": classe,
                "parTardis": parent.startswith(DOSSIER_PAR_TARDIS),
                "taille": len(octets),
                "empreinte": empreinte(octets),
            })
    # Les parents d'abord (un script-dossier avant ses enfants)
    entrees.sort(key=lambda e: (e["parent"].count("/"), e["parent"], e["nom"]))
    manifeste = {"entrees": entrees, "supprimer": SUPPRIMER}
    with open(os.path.join(RACINE, "outils", "manifeste.json"), "w", encoding="utf-8") as sortie:
        json.dump(manifeste, sortie, ensure_ascii=False, indent=1)
    print(len(entrees), "scripts dans le manifeste")


if __name__ == "__main__":
    sys.exit(main())
