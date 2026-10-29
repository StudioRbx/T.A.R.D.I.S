"""Analyse les variables de niveau principal d'un script Luau, section par section.

Pour chaque section (bannière "-----" suivie d'un commentaire), donne :
  - les locales de niveau principal qu'elle déclare ;
  - celles d'autres sections qu'elle lit ;
  - celles d'autres sections qu'elle réaffecte (x = ..., x += ...) : bloquant pour une extraction en module.
Approximation volontairement prudente (les clés de table et les locales internes comptent comme des lectures).

Usage : python outils/analyse_luau.py <fichier.lua> [premiere_ligne_section ...]
"""
import re
import sys

MOTS_CLES = set("and break do else elseif end false for function if in local nil not or repeat return then true until while continue type export".split())
OUVRANTS = {"function", "do", "if", "repeat"}
FERMANTS = {"end", "until"}


def jetons(texte):
    """Renvoie [(type, valeur, ligne)] sans commentaires ni chaînes (les chaînes deviennent ('chaine', '', ligne))."""
    i, ligne, n = 0, 1, len(texte)
    res = []
    while i < n:
        c = texte[i]
        if c == "\n":
            ligne += 1
            i += 1
        elif c in " \t\r":
            i += 1
        elif texte.startswith("--", i):
            m = re.match(r"--\[(=*)\[", texte[i:])
            if m:
                fin = texte.find("]" + m.group(1) + "]", i)
                fin = n if fin < 0 else fin + len(m.group(1)) + 2
            else:
                fin = texte.find("\n", i)
                fin = n if fin < 0 else fin
            ligne += texte.count("\n", i, fin)
            i = fin
        elif c == "[" and re.match(r"\[=*\[", texte[i:]):
            m = re.match(r"\[(=*)\[", texte[i:])
            fin = texte.find("]" + m.group(1) + "]", i)
            fin = n if fin < 0 else fin + len(m.group(1)) + 2
            res.append(("chaine", "", ligne))
            ligne += texte.count("\n", i, fin)
            i = fin
        elif c in "\"'`":
            j = i + 1
            while j < n and texte[j] != c:
                if texte[j] == "\\":
                    j += 1
                elif texte[j] == "\n":
                    ligne += 1
                j += 1
            res.append(("chaine", "", ligne))
            i = j + 1
        elif c.isalpha() or c == "_":
            m = re.match(r"[A-Za-z_][A-Za-z0-9_]*", texte[i:])
            res.append(("nom", m.group(0), ligne))
            i += len(m.group(0))
        elif c.isdigit():
            m = re.match(r"0[xX][0-9a-fA-F_]+|[0-9_]*\.?[0-9_]+(?:[eE][+-]?[0-9]+)?", texte[i:])
            res.append(("nombre", m.group(0), ligne))
            i += max(len(m.group(0)), 1)
        else:
            m = re.match(r"\.\.\.|\.\.=|\.\.|==|~=|<=|>=|\+=|-=|\*=|/=|%=|\^=|::|->|.", texte[i:])
            res.append(("ponct", m.group(0), ligne))
            i += len(m.group(0))
    return res


def analyser(texte, debuts_sections):
    js = jetons(texte)
    profondeur = 0
    declarations = {}   # nom -> ligne de déclaration (niveau principal)
    lectures = []       # (nom, ligne)
    ecritures = []      # (nom, ligne)
    k = 0
    while k < len(js):
        t, v, l = js[k]
        if t == "nom" and v in OUVRANTS:
            # 'do' d'un while/for compte comme un seul bloc : while/for n'ouvrent rien eux-mêmes
            profondeur += 1
        elif t == "nom" and v in FERMANTS:
            profondeur -= 1
        if t == "nom" and v == "local" and profondeur == 0:
            if k + 1 < len(js) and js[k + 1][1] == "function":
                declarations.setdefault(js[k + 2][1], js[k + 2][2])
            else:
                j = k + 1
                while j < len(js) and js[j][0] == "nom":
                    declarations.setdefault(js[j][1], js[j][2])
                    j += 1
                    # annotations de type « : Type » ignorées
                    if j < len(js) and js[j][1] == ":":
                        j += 2
                    if j < len(js) and js[j][1] == ",":
                        j += 1
                    else:
                        break
        if t == "nom" and v not in MOTS_CLES:
            precedent = js[k - 1][1] if k > 0 else ""
            suivant = js[k + 1][1] if k + 1 < len(js) else ""
            if precedent not in (".", ":") and not (precedent == "local"):
                if suivant in ("=", "+=", "-=", "*=", "/=", "%=", "^=", "..="):
                    # « x = » : écriture, sauf clé de table ({ x = 1 } ou , x = 1)
                    if precedent not in ("{", ",", ";") or js[k - 1][0] != "ponct" or precedent == ";":
                        ecritures.append((v, l))
                    else:
                        lectures.append((v, l))
                elif not (suivant == "=" and precedent in ("{", ",")):
                    lectures.append((v, l))
        k += 1

    bornes = sorted(debuts_sections) + [10 ** 9]

    def section_de(ligne):
        for a, b in zip(bornes, bornes[1:]):
            if a <= ligne < b:
                return a
        return 0

    rapport = {}
    for a in bornes[:-1]:
        rapport[a] = {"declare": [], "lit": set(), "ecrit": set(), "ecrit_propre": set()}
    for nom, ligne in declarations.items():
        s = section_de(ligne)
        if s in rapport:
            rapport[s]["declare"].append(nom)
    for nom, ligne in lectures:
        s = section_de(ligne)
        if nom in declarations and s in rapport and section_de(declarations[nom]) != s:
            rapport[s]["lit"].add(nom)
    for nom, ligne in ecritures:
        s = section_de(ligne)
        if nom in declarations and s in rapport:
            if section_de(declarations[nom]) != s:
                rapport[s]["ecrit"].add(nom)
            else:
                rapport[s]["ecrit_propre"].add(nom)
    # Qui lit les déclarations de chaque section, depuis ailleurs
    lu_par = {}
    for nom, ligne in lectures:
        if nom in declarations:
            s_decl, s_lit = section_de(declarations[nom]), section_de(ligne)
            if s_decl != s_lit:
                lu_par.setdefault(nom, set()).add(s_lit)
    return declarations, rapport, lu_par, profondeur


if __name__ == "__main__":
    texte = open(sys.argv[1], encoding="utf-8").read()
    if len(sys.argv) > 2:
        debuts = [int(x) for x in sys.argv[2:]]
    else:
        lignes = texte.split("\n")
        debuts = [1] + [i + 1 for i in range(1, len(lignes)) if re.match(r"^-{20,}$", lignes[i - 1]) and lignes[i].startswith("-- ")]
    declarations, rapport, lu_par, prof = analyser(texte, debuts)
    sys.stdout.reconfigure(encoding="utf-8")
    print("profondeur finale (doit être 0) :", prof, "· locales de niveau principal :", len(declarations))
    lignes = texte.split("\n")
    for a, r in rapport.items():
        titre = lignes[a - 1][:70] if a > 1 else "(début)"
        exportees = sorted(n for n in r["declare"] if n in lu_par)
        print("\n== L%d %s" % (a, titre))
        print("   déclare :", len(r["declare"]), "· exportées :", ", ".join(exportees) or "-")
        print("   lit :", ", ".join(sorted(r["lit"])) or "-")
        if r["ecrit"]:
            print("   !! RÉAFFECTE d'autres sections :", ", ".join(sorted(r["ecrit"])))
        risque = sorted(n for n in r["ecrit_propre"] if n in lu_par)
        if risque:
            print("   !! réaffecte ses propres exportées (lues ailleurs) :", ", ".join(risque))
