"""Paquet de mise à jour pour Roblox Studio, sans serveur ni accès Internet (V6.9.9).

Usage : python3 outils/paquet_studio.py [dossier_de_sortie]

Écrit TARDIS_MiseAJour_<version>.rbxmx : un dossier « TARDIS_MiseAJour » avec un ModuleScript par script du dépôt
(son code tel quel) et un ModuleScript « _manifeste » (emplacement, type, taille et empreinte de chaque script).

Dans Studio (mode Édition) :
  1. clic droit sur Workspace › Insert from File… › choisir le fichier .rbxmx ;
  2. coller le contenu de outils/installer_paquet.luau dans la barre de commande (View › Command Bar), Entrée.
Chaque script est comparé à son empreinte : seuls ceux qui diffèrent sont réécrits, puis le dossier est supprimé.
"""
import json
import os
import re
import sys

import manifeste as M

RACINE = M.RACINE


def cdata(texte):
    # « ]]> » ne peut pas apparaître dans une section CDATA : on la coupe en deux
    return "<![CDATA[" + texte.replace("]]>", "]]]]><![CDATA[>") + "]]>"


def item_module(nom, source, ref):
    return (f'<Item class="ModuleScript" referent="RBX{ref}"><Properties>'
            f'<string name="Name">{nom}</string>'
            f'<ProtectedString name="Source">{cdata(source)}</ProtectedString>'
            f'</Properties></Item>')


def version():
    texte = open(os.path.join(RACINE, "src", "ReplicatedStorage", "TardisConfig.lua"), encoding="utf-8").read()
    m = re.search(r'Config\.Version\s*=\s*"([^"]+)"', texte)
    return m.group(1) if m else "inconnue"


def principal(sortie):
    M.main()
    manifeste = json.load(open(os.path.join(RACINE, "outils", "manifeste.json"), encoding="utf-8"))
    v = version()
    items, entrees = [], []
    for i, e in enumerate(manifeste["entrees"], 1):
        cle = f"f{i:03d}"
        source = open(os.path.join(RACINE, e["fichier"]), "rb").read().decode("utf-8")
        items.append(item_module(cle, source, i + 1))
        entrees.append(dict(e, cle=cle))
    infos = {"version": v, "entrees": entrees, "supprimer": manifeste["supprimer"]}
    items.insert(0, item_module("_manifeste", "return [==[" + json.dumps(infos, ensure_ascii=False) + "]==]", 1))
    xml = ('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" version="4">'
           f'<Item class="Folder" referent="RBX0"><Properties><string name="Name">TARDIS_MiseAJour</string></Properties>'
           + "".join(items) + "</Item></roblox>")
    os.makedirs(sortie, exist_ok=True)
    chemin = os.path.join(sortie, f"TARDIS_MiseAJour_V{v}.rbxmx")
    open(chemin, "w", encoding="utf-8").write(xml)
    print(f"{chemin} : V{v}, {len(entrees)} scripts, {os.path.getsize(chemin) // 1024} Ko")
    return chemin


if __name__ == "__main__":
    principal(sys.argv[1] if len(sys.argv) > 1 else os.path.join(RACINE, "dist"))
