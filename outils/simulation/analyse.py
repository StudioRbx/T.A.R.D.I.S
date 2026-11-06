"""Simulation statique du code Luau du TARDIS (sans interpréteur) :
  1. Portées : toute variable lue ou écrite sans être déclarée (locale, paramètre, boucle) ni globale connue de Roblox.
     Repère aussi les fonctions appelées AVANT leur déclaration (dans un corps de fonction défini plus haut).
  2. Vérifications croisées : actions envoyées / traitées, Config.X, attributs lus / écrits, UI.X, Commandes.X,
     contexte des modules, pont interne.
Usage : python3 outils/simulation/analyse.py .   (depuis la racine du dépôt)"""
import os, re, sys, collections

MOTS = set("and break do else elseif end false for function if in local nil not or repeat return then true until while".split())
GLOBALES = set("""game workspace script Instance Vector3 Vector2 Vector3int16 CFrame Color3 ColorSequence ColorSequenceKeypoint NumberSequence
NumberSequenceKeypoint NumberRange UDim UDim2 Enum BrickColor Ray RaycastParams OverlapParams TweenInfo Rect Region3 PhysicalProperties Random
DateTime Axes Faces Font task wait delay spawn tick time os math string table coroutine utf8 bit32 buffer debug print warn error assert pcall
xpcall type typeof tostring tonumber pairs ipairs next select unpack rawget rawset rawequal rawlen setmetatable getmetatable require shared _G
_VERSION newproxy gcinfo settings UserSettings elapsedTime plugin continue SharedTable""".split())

def lexer(texte):
    """[(type, valeur, ligne)] ; les chaînes gardent leur contenu."""
    i, ligne, n, res = 0, 1, len(texte), []
    while i < n:
        c = texte[i]
        if c == "\n": ligne += 1; i += 1
        elif c in " \t\r": i += 1
        elif texte.startswith("--", i):
            m = re.match(r"--\[(=*)\[", texte[i:])
            if m:
                fin = texte.find("]" + m.group(1) + "]", i); fin = n if fin < 0 else fin + len(m.group(1)) + 2
            else:
                fin = texte.find("\n", i); fin = n if fin < 0 else fin
            ligne += texte.count("\n", i, fin); i = fin
        elif c == "[" and re.match(r"\[=*\[", texte[i:]):
            m = re.match(r"\[(=*)\[", texte[i:]); fin = texte.find("]" + m.group(1) + "]", i)
            fin = n if fin < 0 else fin + len(m.group(1)) + 2
            res.append(("chaine", texte[i + len(m.group(0)):fin - len(m.group(1)) - 2], ligne)); ligne += texte.count("\n", i, fin); i = fin
        elif c in "\"'`":
            j, buf = i + 1, []
            while j < n and texte[j] != c:
                if texte[j] == "\\": buf.append(texte[j:j + 2]); j += 2; continue
                if texte[j] == "\n": ligne += 1
                buf.append(texte[j]); j += 1
            res.append(("chaine", "".join(buf), ligne)); i = j + 1
        elif c.isalpha() or c == "_":
            m = re.match(r"[A-Za-z_][A-Za-z0-9_]*", texte[i:]); res.append(("nom", m.group(0), ligne)); i += len(m.group(0))
        elif c.isdigit():
            m = re.match(r"0[xX][0-9a-fA-F_]+|0[bB][01_]+|[0-9_]*\.?[0-9_]+(?:[eE][+-]?[0-9]+)?", texte[i:])
            res.append(("nombre", m.group(0), ligne)); i += max(len(m.group(0)), 1)
        else:
            m = re.match(r"\.\.\.|\.\.=|//=|\.\.|==|~=|<=|>=|\+=|-=|\*=|/=|%=|\^=|//|::|->|.", texte[i:])
            res.append(("ponct", m.group(0), ligne)); i += len(m.group(0))
    return res

def portees(js):
    """Renvoie [(ligne, nom, 'lecture'|'ecriture')] des noms inconnus."""
    pile = [set()]
    inconnus = []
    attente_for = None
    k, n = 0, len(js)
    accolades = []  # pile des ouvrants ( [ {
    def declare(nom): pile[-1].add(nom)
    def connu(nom): return nom in GLOBALES or any(nom in s for s in pile)
    def params(k):
        # js[k] == '(' ; renvoie (noms, index après ')')
        noms, k = [], k + 1
        attendre_nom = True
        while k < n and js[k][1] != ")":
            t, v, _ = js[k]
            if js[k][1] == ":":  # annotation de type : sauter jusqu'à , ou )
                prof = 0
                while k < n and not (prof == 0 and js[k][1] in (",", ")")):
                    if js[k][1] in "([{<": prof += 1
                    if js[k][1] in ")]}>": prof -= 1
                    k += 1
                continue
            if t == "nom" and attendre_nom: noms.append(v); attendre_nom = False
            elif v == ",": attendre_nom = True
            elif v == "...": noms.append("...")
            k += 1
        return noms, k + 1
    while k < n:
        t, v, l = js[k]
        prec = js[k - 1][1] if k else ""
        if t == "ponct":
            if v in "([{": accolades.append(v)
            elif v in ")]}" and accolades: accolades.pop()
            k += 1; continue
        if t != "nom": k += 1; continue
        if v == "local":
            if js[k + 1][1] == "function":
                declare(js[k + 2][1]); k += 1; continue  # 'function' traité au tour suivant
            k += 1
            while k < n and js[k][0] == "nom":
                declare(js[k][1]); k += 1
                if k < n and js[k][1] == "<": k += 3  # <const>
                if k < n and js[k][1] == ":":  # type
                    while k < n and js[k][1] not in (",", "=") and js[k][2] == l: k += 1
                if k < n and js[k][1] == ",": k += 1
                else: break
            continue
        if v == "function":
            j = k + 1
            methode = False
            if js[j][0] == "nom":  # instruction function a.b:c(...)
                premier = js[j][1]
                if prec != "local" and not connu(premier) and js[j + 1][1] not in (".", ":"):
                    inconnus.append((js[j][2], premier, "ecriture"))
                elif prec != "local" and not connu(premier):
                    inconnus.append((js[j][2], premier, "lecture"))
                while js[j][0] == "nom" or js[j][1] in (".", ":"):
                    if js[j][1] == ":": methode = True
                    j += 1
            if js[j][1] == "<":  # génériques
                while js[j][1] != ">": j += 1
                j += 1
            noms, j = params(j)
            pile.append(set(noms) | ({"self"} if methode else set()))
            # type de retour
            if j < n and js[j][1] == ":":
                while j < n and js[j][2] == js[j - 1][2] and js[j][0] != "nom" or (js[j][0] == "nom" and js[j][1] not in MOTS and js[j][2] == l and js[j - 1][1] in (":", "?", "|")):
                    j += 1
            k = j; continue
        if v == "for":
            j, noms = k + 1, []
            while js[j][1] not in ("=", "in"):
                if js[j][0] == "nom": noms.append(js[j][1])
                j += 1
            attente_for = noms
            k = j; continue
        if v in ("do",):
            pile.append(set(attente_for or [])); attente_for = None; k += 1; continue
        if v == "then": pile.append(set()); k += 1; continue
        if v in ("elseif",): pile.pop(); k += 1; continue
        if v == "else": pile.pop(); pile.append(set()); k += 1; continue
        if v == "repeat": pile.append(set()); k += 1; continue
        if v in ("end", "until"):
            if len(pile) > 1: pile.pop()
            k += 1; continue
        if v in MOTS: k += 1; continue
        # Nom ordinaire
        if prec in (".", ":") or (prec == "::"):
            k += 1; continue
        suiv = js[k + 1][1] if k + 1 < n else ""
        if suiv == "=" and accolades and accolades[-1] == "{" and prec in ("{", ",", ";"):
            k += 1; continue  # clé de table
        if prec == "goto" or v in ("type", "export") and js[k + 1][0] == "nom" and js[k + 2][1] in ("=", "<"):
            k += 1; continue
        if v == "continue" and suiv != "(":
            k += 1; continue
        if not connu(v):
            ecriture = suiv in ("=", "+=", "-=", "*=", "/=", "..=", "%=", "^=", "//=") and (not accolades or accolades[-1] != "{")
            inconnus.append((l, v, "ecriture" if ecriture else "lecture"))
        k += 1
    return inconnus

def fichiers(racine):
    for d, _, fs in os.walk(os.path.join(racine, "src")):
        for f in fs:
            if f.endswith(".lua"): yield os.path.join(d, f)

def main(racine):
    class Chemins(dict):  # (V6.9.10.8) mêmes clés sous Windows (\) et Linux (/)
        def __getitem__(s, k): return dict.__getitem__(s, os.path.normpath(k))
    textes = Chemins((os.path.normpath(p), open(p, encoding="utf-8").read()) for p in sorted(fichiers(racine)))
    toks = {p: lexer(t) + [("fin", "", 0)] * 4 for p, t in textes.items()}
    rel = lambda p: os.path.relpath(p, racine)
    rapport = collections.OrderedDict()
    # 1. Portées
    for p, js in toks.items():
        for l, nom, quoi in portees(js):
            rapport.setdefault("1. Variables inconnues (lues ou écrites sans déclaration)", []).append(f"{rel(p)}:{l}  {nom}  ({quoi})")
    # 2. Actions envoyées / traitées
    envoyees, traitees = collections.defaultdict(set), set()
    for p, js in toks.items():
        for i, (t, v, l) in enumerate(js):
            if v == "FireServer" and js[i + 1][1] == "(" and js[i + 2][0] == "chaine":
                envoyees[js[i + 2][1]].add(f"{rel(p)}:{l}")
            if t == "nom" and v == "action" and js[i + 1][1] == "==" and js[i + 2][0] == "chaine":
                traitees.add(js[i + 2][1])
            if t == "chaine" and i > 1 and js[i - 1][1] == "==" and js[i - 2][1] == "action": traitees.add(v)
        # tables d'actions : ACTIONS = { Demat = true, ... } et listes { "A", "B" } à côté de 'action'
        for m in re.finditer(r'(\w+) = true', textes[p]): pass
    for nom, ou in sorted(envoyees.items()):
        if nom not in traitees and not nom.startswith("__"):
            rapport.setdefault("2. Actions envoyées par un client mais traitées par aucun serveur", []).append(f"{nom}  ←  {', '.join(sorted(ou))}")
    # 3. Config.X
    cfg = textes[os.path.join(racine, "src/ReplicatedStorage/TardisConfig.lua")]
    definis = set(re.findall(r"^\s*Config\.(\w+)\s*=", cfg, re.M)) | set(re.findall(r"^\s*function Config\.(\w+)", cfg, re.M))
    for p, js in toks.items():
        for i, (t, v, l) in enumerate(js):
            if v == "Config" and t == "nom" and js[i + 1][1] == "." and js[i + 2][0] == "nom":
                champ = js[i + 2][1]
                ecrit = js[i + 3][1] == "=" if i + 3 < len(js) else False
                optionnel = js[i + 3][1] == "or"  # « Config.X or valeur » : réglage facultatif (bloc commenté, par exemple)
                if champ not in definis and not ecrit and not optionnel:
                    rapport.setdefault("3. Réglages Config.X lus mais jamais définis dans TardisConfig", []).append(f"{rel(p)}:{l}  Config.{champ}")
    # 4. Attributs
    ecrits, lus = set(), collections.defaultdict(set)
    prefixes = set()
    for p, js in toks.items():
        for i, (t, v, l) in enumerate(js):
            if v in ("SetAttribute", "GetAttribute", "GetAttributeChangedSignal") and js[i + 1][1] == "(" and js[i + 2][0] == "chaine":
                nom = js[i + 2][1]
                concat = js[i + 3][1] == ".."
                if v == "SetAttribute":
                    (prefixes.add(nom) if concat else ecrits.add(nom))
                else:
                    lus[(nom, concat)].add(f"{rel(p)}:{l}")
    for (nom, concat), ou in sorted(lus.items()):
        ok = (nom in prefixes or any(e.startswith(nom) for e in ecrits)) if concat else (nom in ecrits or any(nom.startswith(pr) for pr in prefixes))
        if not ok:
            rapport.setdefault("4. Attributs lus mais jamais écrits par le code (à poser dans Studio, ou faute de frappe)", []).append(
                f"{nom}{'…' if concat else ''}  ←  {', '.join(sorted(ou)[:3])}{' …' if len(ou) > 3 else ''}")
    # 5. UI.X et Commandes.X
    for module, chemin in (("UI", "src/ReplicatedStorage/TardisUI.lua"), ("Commandes", "src/ReplicatedStorage/TardisCommandes.lua")):
        src = textes[os.path.join(racine, chemin)]
        defs = set(re.findall(r"^\s*function %s\.(\w+)" % module, src, re.M))
        for autre in textes.values(): defs |= set(re.findall(r"\b%s\.(\w+)\s*=[^=]" % module, autre))
        for p, js in toks.items():
            for i, (t, v, l) in enumerate(js):
                if v == module and t == "nom" and js[i + 1][1] == "." and js[i + 2][0] == "nom" and js[i - 1][1] != ".":
                    champ = js[i + 2][1]
                    if champ not in defs and js[i + 3][1] != "=":
                        rapport.setdefault(f"5. {module}.X utilisés mais jamais définis", []).append(f"{rel(p)}:{l}  {module}.{champ}")
    # 6. contexte des modules
    for p, texte in textes.items():
        utilises = set(re.findall(r"contexte\.(\w+)", texte))
        if not utilises: continue
        nom = os.path.splitext(os.path.basename(p))[0]
        dossier = os.path.dirname(p)
        parents = [q for q in textes if os.path.dirname(q) == dossier and os.path.basename(q).startswith("init.")]
        fourni = None
        for q in parents:
            m = re.search(r'require\(script:WaitForChild\("%s"\)\)\(\{(.*?)\}\)' % re.escape(nom), textes[q], re.S)
            if m: fourni = set(re.findall(r"(\w+)\s*=", m.group(1)))
        if fourni is None:
            continue
        for c in sorted(utilises - fourni):
            rapport.setdefault("6. Modules : contexte.X utilisé mais non fourni par le script parent", []).append(f"{rel(p)}  contexte.{c}")
    # 7. Pont interne
    serveur = textes[os.path.join(racine, "src/ServerScriptService/TardisServeur/init.server.lua")]
    bloc = serveur[serveur.index("pont.OnInvoke"):]
    gerees = set(re.findall(r'action == "(\w+)"', bloc[:bloc.index("return nil")]))
    for p, texte in textes.items():
        for m in re.finditer(r'(?:\binterne|pont:Invoke)\("(\w+)"', texte):
            if m.group(1) not in gerees:
                l = texte.count("\n", 0, m.start()) + 1
                rapport.setdefault("7. Pont interne : action demandée mais non gérée par TardisServeur", []).append(f"{rel(p)}:{l}  {m.group(1)}")
    # Rapport
    total = 0
    for titre, lignes in rapport.items():
        print(f"\n### {titre} ({len(lignes)})")
        for x in lignes: print("  " + x)
        total += len(lignes)
    print(f"\n{len(textes)} fichiers, {sum(len(j) for j in toks.values())} jetons, {total} remarques.")

main(sys.argv[1])
