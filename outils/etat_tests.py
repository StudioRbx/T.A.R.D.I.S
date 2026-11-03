"""Page d'état des tests en jeu (proposition 199, V6.9.8).

Usage : python3 outils/etat_tests.py

Reprend chaque tableau « À tester » des notes de version et (re)génère docs/ETAT_DES_TESTS.md.
Les résultats déjà notés dans la page (colonne « Résultat » et « Remarque ») sont gardés : on peut relancer
le script à chaque nouvelle version sans rien perdre.

Résultats possibles : ⬜ à tester · ✅ marche · ⚠️ marche à moitié · ❌ ne marche pas · ➖ plus d'actualité
"""
import re
import sys

from suivi_versions import RACINE, cle_tri, lire_versions, tableaux_a_tester, titre_propre

PAGE = RACINE / "docs" / "ETAT_DES_TESTS.md"
RESULTATS = ["⬜", "✅", "⚠️", "❌", "➖"]
LIGNE = re.compile(r"^\| (.+?) \| (.+?) \| (.+?) \| (.*?) \|$")


def anciens_resultats():
    """{ (version, test) : (résultat, remarque) } lus dans la page existante."""
    if not PAGE.exists():
        return {}
    gardes, version = {}, None
    for ligne in PAGE.read_text(encoding="utf-8").splitlines():
        m = re.match(r"^## (V[\d.]+)", ligne)
        if m:
            version = m.group(1)
            continue
        m = LIGNE.match(ligne)
        if m and version and m.group(3) in RESULTATS:
            gardes[(version, m.group(1))] = (m.group(3), m.group(4))
    return gardes


def echapper(texte):
    return texte.replace("|", "\\|")


def generer():
    gardes = anciens_resultats()
    sections, total, compte = [], 0, {r: 0 for r in RESULTATS}
    versions = [v for v in lire_versions() if "–" not in v["version"]]
    for v in sorted(versions, key=lambda v: cle_tri(v["version"]), reverse=True):
        tests = tableaux_a_tester(v["lignes"])
        if not tests:
            continue
        lignes = [f"## {v['version']} — {titre_propre(v['titre'])}", "", "| Test | Attendu | Résultat | Remarque |",
                  "|---|---|---|---|"]
        for test, attendu in tests:
            resultat, remarque = gardes.get((v["version"], echapper(test)), ("⬜", ""))
            compte[resultat] += 1
            total += 1
            lignes.append(f"| {echapper(test)} | {echapper(attendu)} | {resultat} | {remarque} |")
        sections.append("\n".join(lignes))
    resume = " · ".join(f"{r} {compte[r]}" for r in RESULTATS)
    texte = "\n".join([
        "# État des tests en jeu",
        "",
        "Ce qui a été essayé dans Roblox Studio ou dans ZONE-TSADE, version par version (proposition 199, V6.9.8).",
        "Page générée par `python3 outils/etat_tests.py` depuis les tableaux « À tester » de `docs/patch-notes/`.",
        "Pour noter un résultat : remplacer ⬜ dans la colonne Résultat, ajouter une remarque si besoin, puis relancer",
        "le script (les résultats notés sont gardés).",
        "",
        "Légende : ⬜ à tester · ✅ marche · ⚠️ marche à moitié · ❌ ne marche pas · ➖ plus d'actualité",
        "",
        f"**Total : {total} tests** — {resume}",
        "",
        "Les simulations sans Roblox (`outils/simulation/lancer.sh`) vérifient la logique ; seuls ces tests en jeu",
        "confirment l'affichage, les sons et les sensations.",
        "",
        "\n\n".join(sections),
        "",
    ])
    PAGE.write_text(texte, encoding="utf-8")
    return total, compte


if __name__ == "__main__":
    total, compte = generer()
    print(f"{PAGE.relative_to(RACINE)} : {total} tests ({', '.join(f'{r} {n}' for r, n in compte.items())})")
    sys.exit(0)
