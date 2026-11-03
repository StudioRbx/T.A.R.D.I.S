"""Lecture des notes de version (docs/patch-notes/V*.md), commune à release.py et etat_tests.py (V6.9.8).

Une version est un titre « ## Vx.y » ou « ### Vx.y.z — Titre ». Son texte va jusqu'au titre de version suivant.
"""
import re
from pathlib import Path

RACINE = Path(__file__).resolve().parent.parent
NOTES = RACINE / "docs" / "patch-notes"

TITRE_VERSION = re.compile(r"^(#{2,3}) (V\d+(?:\.\d+)*(?:[–-]\d+(?:\.\d+)*)?)\s*(?:—\s*(.*))?$")


def cle_tri(version):
    """V6.9.10 passe après V6.9.9 (tri numérique, pas alphabétique)."""
    nombres = re.findall(r"\d+", version.split("–")[0])
    return tuple(int(n) for n in nombres)


def lire_versions():
    """Liste de dicts { version, titre, niveau, lignes } dans l'ordre des fichiers."""
    versions = []
    fichiers = sorted(NOTES.glob("V*.md"), key=lambda f: cle_tri(f.stem))
    for fichier in fichiers:
        courante = None
        for ligne in fichier.read_text(encoding="utf-8").splitlines():
            m = TITRE_VERSION.match(ligne)
            if m:
                courante = {
                    "version": m.group(2),
                    "titre": (m.group(3) or "").strip(),
                    "niveau": len(m.group(1)),
                    "fichier": fichier.name,
                    "lignes": [],
                }
                versions.append(courante)
            elif ligne.startswith("## ") and courante is not None:
                courante = None  # « ## Prochaine étape » et autres : hors version
            elif courante is not None:
                courante["lignes"].append(ligne)
    return versions


def titre_propre(titre):
    """Retire la date et les mentions d'installation : « Mode Express (29/10/2026) ⭐ installée… » → « Mode Express »."""
    titre = re.sub(r"\s*\(\d{1,2}/\d{1,2}(?:/\d{4})?[^)]*\)", "", titre)
    titre = re.sub(r"\s*⭐.*$", "", titre)
    titre = re.sub(r"\s*\*[^*]*\*\s*$", "", titre)
    return titre.strip()


def date_de(titre):
    m = re.search(r"\((\d{1,2}/\d{1,2}(?:/\d{4})?)", titre)
    return m.group(1) if m else ""


def tableaux_a_tester(lignes):
    """Lignes des tableaux qui suivent un titre « ### À tester… » : liste de (test, attendu)."""
    resultats, dedans = [], False
    for ligne in lignes:
        if ligne.startswith("#"):
            dedans = ligne.lstrip("#").strip().lower().startswith("à tester")
            continue
        if not dedans or not ligne.startswith("|"):
            continue
        cellules = [c.strip() for c in ligne.strip().strip("|").split("|")]
        if len(cellules) < 2 or set(cellules[0]) <= set("-: ") or cellules[0].lower() == "test":
            continue
        resultats.append((cellules[0], cellules[1]))
    return resultats
