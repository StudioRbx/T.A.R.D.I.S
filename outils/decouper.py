"""Découpe un gros script Luau en ModuleScripts enfants (convention Rojo : dossier + init.*.lua).

Chaque groupe de sections devient un module de la forme :
    return function(contexte)
        local a, b = contexte.a, contexte.b   -- uniquement ce que le groupe lit
        <code du groupe>
        return { x = x }                      -- uniquement ce que la suite du script lit
    end
et, à sa place dans le script principal :
    local x = require(script:WaitForChild("Nom"))({ a = a, b = b }).x

Sécurités (le découpage est refusé si l'une échoue) :
  - le groupe ne réaffecte aucune variable déclarée hors de lui ;
  - aucune de ses variables exportées n'est réaffectée hors de lui ;
  - aucune variable qu'il lit n'est réaffectée ailleurs après sa déclaration (sa copie serait périmée).
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from analyse_luau import jetons, MOTS_CLES, OUVRANTS, FERMANTS  # noqa: E402


def references(texte):
    """Déclarations de niveau principal, lectures et écritures (avec numéro de ligne)."""
    js = jetons(texte)
    profondeur, declarations, lectures, ecritures = 0, {}, [], []
    for k, (t, v, l) in enumerate(js):
        if t == "nom" and v in OUVRANTS:
            profondeur += 1
        elif t == "nom" and v in FERMANTS:
            profondeur -= 1
        if t == "nom" and v == "local" and profondeur == 0:
            if js[k + 1][1] == "function":
                declarations.setdefault(js[k + 2][1], js[k + 2][2])
            else:
                j = k + 1
                while j < len(js) and js[j][0] == "nom":
                    declarations.setdefault(js[j][1], js[j][2])
                    j += 1
                    if j < len(js) and js[j][1] == ":":
                        j += 2
                    if j < len(js) and js[j][1] == ",":
                        j += 1
                    else:
                        break
        if t == "nom" and v not in MOTS_CLES:
            avant = js[k - 1] if k else ("", "", 0)
            apres = js[k + 1][1] if k + 1 < len(js) else ""
            if avant[1] in (".", ":") or avant[1] == "local":
                continue
            cle_de_table = apres == "=" and avant[0] == "ponct" and avant[1] in ("{", ",")
            if apres in ("=", "+=", "-=", "*=", "/=", "%=", "^=", "..=") and not cle_de_table:
                ecritures.append((v, l))
            else:
                lectures.append((v, l))
    return declarations, lectures, ecritures


def trouver_ligne(lignes, prefixe):
    for i, l in enumerate(lignes):
        if l.startswith(prefixe):
            return i + 1
    raise SystemExit("Titre introuvable : " + prefixe)


def decouper(chemin, groupes, chemin_sortie_dossier, extension_init, entete_module):
    """groupes : [(nom_module, prefixe_titre_debut, prefixe_titre_suivant_ou_None, description)]"""
    texte = open(chemin, encoding="utf-8", newline="").read()
    lignes = texte.split("\n")
    declarations, lectures, ecritures = references(texte)

    plages = []
    for nom, debut, suivant, description in groupes:
        a = trouver_ligne(lignes, debut) - 1          # la bannière au-dessus du titre
        b = (trouver_ligne(lignes, suivant) - 2) if suivant else len(lignes)
        while b > a and lignes[b - 1].strip() == "":
            b -= 1
        plages.append((nom, a, b, description))

    erreurs = []
    avertissements = set()
    remplacements = []
    modules = {}
    for nom, a, b, description in plages:
        dedans = lambda ligne: a <= ligne <= b
        locales = {n for n, l in declarations.items() if dedans(l)}
        lues = sorted({n for n, l in lectures if dedans(l) and n in declarations and declarations[n] < a})
        exportees = sorted({n for n, l in lectures if l > b and n in locales})
        for n, l in ecritures:
            if dedans(l) and n in declarations and not dedans(declarations[n]):
                erreurs.append("%s : réaffecte %s (déclarée ligne %d)" % (nom, n, declarations[n]))
            if l > b and n in exportees:
                erreurs.append("%s : son export %s est réaffecté ligne %d" % (nom, n, l))
            if n in lues and l > declarations[n] and not dedans(l):
                if l > a:
                    erreurs.append("%s : %s, qu'il lit, est réaffectée plus loin (ligne %d)" % (nom, n, l))
                else:
                    avertissements.add("%s lit %s, réaffectée ligne %d (avant le groupe : à vérifier)" % (nom, n, l))
        corps = lignes[a - 1:b]
        # Module
        contenu = ["-- " + entete_module + " > " + nom + " (ModuleScript)", "-- " + description,
                   "-- Extrait du script principal en V6.6.3 : reçoit ce qu'il utilise, renvoie ce que la suite utilise.", "",
                   "return function(contexte)"]
        for i in range(0, len(lues), 6):
            paquet = lues[i:i + 6]
            contenu.append("\tlocal " + ", ".join(paquet) + " = " + ", ".join("contexte." + n for n in paquet))
        contenu.append("")
        contenu += [("\t" + l) if l.strip() else "" for l in corps]
        contenu.append("")
        contenu.append("\treturn { " + ", ".join("%s = %s" % (n, n) for n in exportees) + " }" if exportees else "\treturn {}")
        contenu.append("end")
        modules[nom] = "\n".join(contenu) + "\n"
        # Appel dans le script principal
        appel = ["--------------------------------------------------------------------",
                 "-- " + description + " : module " + nom,
                 "--------------------------------------------------------------------"]
        contexte = "{ " + ", ".join("%s = %s" % (n, n) for n in lues) + " }"
        if exportees:
            appel.append("local " + nom + " = require(script:WaitForChild(\"" + nom + "\"))(" + contexte + ")")
            for i in range(0, len(exportees), 6):
                paquet = exportees[i:i + 6]
                appel.append("local " + ", ".join(paquet) + " = " + ", ".join(nom + "." + n for n in paquet))
        else:
            appel.append("require(script:WaitForChild(\"" + nom + "\"))(" + contexte + ")")
        remplacements.append((a, b, appel))
        print("%-18s lignes %4d-%4d (%4d) · lit %2d · exporte %s" % (nom, a, b, b - a + 1, len(lues), ", ".join(exportees) or "-"))

    for av in sorted(avertissements):
        print("  ! " + av)
    if erreurs:
        print("\nDÉCOUPAGE REFUSÉ :")
        for e in erreurs:
            print("  -", e)
        sys.exit(1)

    resultat = list(lignes)
    for a, b, appel in sorted(remplacements, reverse=True):
        resultat[a - 1:b] = appel
    os.makedirs(chemin_sortie_dossier, exist_ok=True)
    with open(os.path.join(chemin_sortie_dossier, "init" + extension_init), "w", encoding="utf-8", newline="") as f:
        f.write("\n".join(resultat))
    for nom, contenu in modules.items():
        with open(os.path.join(chemin_sortie_dossier, nom + ".lua"), "w", encoding="utf-8", newline="") as f:
            f.write(contenu)
    os.remove(chemin)
    print("\nÉcrit :", chemin_sortie_dossier, "(init + %d modules)" % len(modules))
