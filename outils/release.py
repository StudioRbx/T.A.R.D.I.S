"""Modèle de release GitHub pour chaque version (proposition 198, V6.9.8).

Usage :
  python3 outils/release.py --liste            toutes les versions des notes, publiées ou non
  python3 outils/release.py --manquantes       versions de V6.5 et après sans release sur GitHub
  python3 outils/release.py V6.9.8             écrit docs/releases/V6.9.8.md, prêt à coller dans GitHub
  python3 outils/release.py --toutes           écrit le fichier de chaque version manquante

Sur GitHub : Releases › Draft a new release › tag (par ex. v6.9.8, cible main) › titre et texte du fichier.
Quand une release est publiée, ajouter son tag dans docs/releases/publiees.txt.
"""
import posixpath
import re
import sys

from suivi_versions import RACINE, cle_tri, date_de, lire_versions, titre_propre

DOSSIER = RACINE / "docs" / "releases"
PUBLIEES = DOSSIER / "publiees.txt"
DEPOT = "https://github.com/StudioRbx/T.A.R.D.I.S"
PREMIERE_SUIVIE = (6, 5)  # avant la V6.5, il n'y avait pas de dépôt GitHub


def tag_de(version):
    return "v" + version[1:].split("–")[0].lower()


def publiees():
    if not PUBLIEES.exists():
        return set()
    return {l.strip() for l in PUBLIEES.read_text(encoding="utf-8").splitlines() if l.strip() and not l.startswith("#")}


def suivies():
    """Versions de premier niveau dans GitHub : V6.5 et après, sans les plages (V6.5.1–6.5.6)."""
    return [v for v in lire_versions() if "–" not in v["version"] and cle_tri(v["version"]) >= PREMIERE_SUIVIE
            and (v["niveau"] == 2 or cle_tri(v["version"])[:2] >= (6, 6))]


def liens_absolus(texte):
    """Les liens relatifs des notes (« ../GLOSSAIRE.md ») ne marchent pas dans une release : on les rend complets."""
    def remplacer(m):
        cible = m.group(1)
        if re.match(r"^[a-z]+:|^#", cible):
            return m.group(0)
        chemin = posixpath.normpath(posixpath.join("docs/patch-notes", cible))
        return f"]({DEPOT}/blob/main/{chemin})"
    return re.sub(r"\]\(([^)\s]+)\)", remplacer, texte)


def texte_release(v):
    titre = titre_propre(v["titre"])
    date = date_de(v["titre"])
    corps = liens_absolus("\n".join(v["lignes"]).strip())
    tag = tag_de(v["version"])
    entete = [f"# {v['version']} — {titre}" if titre else f"# {v['version']}", ""]
    if date:
        entete.append(f"*Date : {date}*  ")
    entete += [
        f"*Tag : `{tag}` (cible : `main`)*",
        "",
        corps,
        "",
        "---",
        f"Notes complètes : [docs/patch-notes/{v['fichier']}]({DEPOT}/blob/main/docs/patch-notes/{v['fichier']}) · "
        f"[CHANGELOG]({DEPOT}/blob/main/CHANGELOG.md) · [État des tests]({DEPOT}/blob/main/docs/ETAT_DES_TESTS.md)",
    ]
    return f"{v['version']} — {titre}" if titre else v["version"], "\n".join(entete) + "\n"


def ecrire(v):
    DOSSIER.mkdir(parents=True, exist_ok=True)
    titre, texte = texte_release(v)
    chemin = DOSSIER / f"{v['version']}.md"
    chemin.write_text(texte, encoding="utf-8")
    return titre, chemin


def principal(args):
    versions = suivies()
    deja = publiees()
    if not args or args[0] == "--liste":
        for v in versions:
            etat = "publiée" if tag_de(v["version"]) in deja else "à publier"
            print(f"{v['version']:<10} {tag_de(v['version']):<10} {etat:<10} {titre_propre(v['titre'])}")
        return 0
    if args[0] == "--manquantes":
        manquantes = [v for v in versions if tag_de(v["version"]) not in deja]
        for v in manquantes:
            print(f"{tag_de(v['version']):<10} {titre_propre(v['titre'])}")
        print(f"{len(manquantes)} release(s) à publier")
        return 0
    if args[0] == "--toutes":
        for v in versions:
            if tag_de(v["version"]) not in deja:
                titre, chemin = ecrire(v)
                print(f"{chemin.relative_to(RACINE)}  ←  {titre}")
        return 0
    voulue = args[0] if args[0].startswith("V") else "V" + args[0].lstrip("v")
    for v in versions:
        if v["version"] == voulue:
            titre, chemin = ecrire(v)
            print(f"Titre : {titre}\nFichier : {chemin.relative_to(RACINE)}")
            return 0
    print(f"Version {voulue} introuvable dans docs/patch-notes", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(principal(sys.argv[1:]))
