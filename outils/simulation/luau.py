"""Petit interpréteur Luau en Python (sous-ensemble utilisé par les modules du TARDIS), pour simuler sans Roblox."""
import re, math, time

# ---------------------------------------------------------------- Lexeur
MOTS = set("and break do else elseif end false for function if in local nil not or repeat return then true until while".split())
def echapper(s):
    out, i = [], 0
    while i < len(s):
        c = s[i]
        if c == "\\" and i + 1 < len(s):
            d = s[i + 1]; i += 2
            if d == "n": out.append("\n")
            elif d == "t": out.append("\t")
            elif d == "r": out.append("\r")
            elif d == "\n": out.append("\n")
            elif d.isdigit():
                m = re.match(r"\d{1,3}", s[i - 1:]); out.append(chr(int(m.group(0)))); i += len(m.group(0)) - 1
            elif d == "x": out.append(chr(int(s[i:i + 2], 16))); i += 2
            elif d == "u":
                m = re.match(r"\{([0-9a-fA-F]+)\}", s[i:]); out.append(chr(int(m.group(1), 16))); i += len(m.group(0))
            elif d == "z":
                while i < len(s) and s[i] in " \n\t\r": i += 1
            else: out.append(d)
        else:
            out.append(c); i += 1
    return "".join(out)

def lexer(t):
    i, l, n, res = 0, 1, len(t), []
    while i < n:
        c = t[i]
        if c == "\n": l += 1; i += 1
        elif c in " \t\r": i += 1
        elif t.startswith("--", i):
            m = re.match(r"--\[(=*)\[", t[i:])
            if m:
                f = t.find("]" + m.group(1) + "]", i); f = n if f < 0 else f + len(m.group(1)) + 2
            else:
                f = t.find("\n", i); f = n if f < 0 else f
            l += t.count("\n", i, f); i = f
        elif c == "[" and re.match(r"\[=*\[", t[i:]):
            m = re.match(r"\[(=*)\[", t[i:]); f = t.find("]" + m.group(1) + "]", i)
            contenu = t[i + len(m.group(0)):f]
            if contenu.startswith("\n"): contenu = contenu[1:]
            res.append(("str", contenu, l)); l += t.count("\n", i, f); i = f + len(m.group(1)) + 2
        elif c in "\"'`":
            j = i + 1
            while t[j] != c:
                if t[j] == "\\": j += 1
                j += 1
            res.append(("str" if c != "`" else "istr", echapper(t[i + 1:j]) if c != "`" else t[i + 1:j], l)); l += t.count("\n", i, j); i = j + 1
        elif c.isalpha() or c == "_":
            m = re.match(r"[A-Za-z_][A-Za-z0-9_]*", t[i:]); v = m.group(0)
            res.append(("kw" if v in MOTS else "name", v, l)); i += len(v)
        elif c.isdigit() or (c == "." and i + 1 < n and t[i + 1].isdigit()):
            m = re.match(r"0[xX][0-9a-fA-F_]+|0[bB][01_]+|(?:[0-9_]*\.?[0-9_]+|[0-9_]+\.)(?:[eE][+-]?[0-9]+)?", t[i:]); s = m.group(0).replace("_", "")
            v = int(s, 16) if s[:2] in ("0x", "0X") else int(s[2:], 2) if s[:2] in ("0b", "0B") else (float(s) if any(x in s for x in ".eE") else int(s))
            res.append(("num", v, l)); i += len(m.group(0))
        else:
            m = re.match(r"\.\.\.|\.\.=|//=|\.\.|==|~=|<=|>=|\+=|-=|\*=|/=|%=|\^=|//|::|->|.", t[i:])
            res.append(("op", m.group(0), l)); i += len(m.group(0))
    res.append(("eof", None, l))
    return res

# ---------------------------------------------------------------- Analyseur (AST en tuples)
BIN = {"or": 1, "and": 2, "<": 3, ">": 3, "<=": 3, ">=": 3, "~=": 3, "==": 3, "..": 5, "+": 6, "-": 6, "*": 7, "/": 7, "//": 7, "%": 7, "^": 10}
DROITE = {"..", "^"}
class Parseur:
    def __init__(s, toks): s.t, s.i = toks, 0
    def pk(s, d=0): return s.t[s.i + d]
    def v(s, d=0): return s.t[s.i + d][1]
    def avance(s): x = s.t[s.i]; s.i += 1; return x
    def attend(s, v):
        if s.v() != v: raise SyntaxError(f"ligne {s.pk()[2]} : '{v}' attendu, trouvé '{s.v()}'")
        return s.avance()
    def accepte(s, v):
        if s.v() == v and s.pk()[0] in ("op", "kw", "name"): s.avance(); return True
        return False
    def type_(s):  # saute une annotation de type
        prof = 0
        while True:
            x = s.pk()
            if x[0] == "eof": return
            if x[1] in ("(", "{", "<", "["): prof += 1
            elif x[1] in (")", "}", ">", "]"):
                if prof == 0: return
                prof -= 1
            elif prof == 0 and (x[1] in (",", "=", ";") or (x[0] == "kw" and x[1] not in ("nil",)) ): return
            elif prof == 0 and x[1] == "->": pass
            s.avance()
            if prof == 0 and s.pk()[0] in ("name", "kw") and s.t[s.i - 1][0] in ("name",) and s.t[s.i - 1][1] not in ("typeof",) and s.v() not in ("nil",) and s.t[s.i - 1][2] != s.pk()[2]: return
    def bloc(s, fins):
        stats = []
        while not (s.pk()[0] == "kw" and s.v() in fins) and s.pk()[0] != "eof":
            if s.v() == "return" and s.pk()[0] == "kw":
                s.avance(); ex = [] if (s.v() in fins and s.pk()[0] == "kw") or s.v() == ";" or s.pk()[0] == "eof" else s.explist()
                s.accepte(";"); stats.append(("return", ex)); break
            st = s.stat()
            if st: stats.append(st)
        return stats
    def stat(s):
        x = s.pk(); l = x[2]
        if x[1] == ";": s.avance(); return None
        if x[0] == "kw":
            k = x[1]
            if k == "local":
                s.avance()
                if s.accepte("function"):
                    nom = s.avance()[1]; return ("localfunc", nom, s.corps(nom), l)
                noms = []
                while True:
                    noms.append(s.avance()[1])
                    if s.v() == "<": s.avance(); s.avance(); s.attend(">")
                    if s.accepte(":"): s.type_()
                    if not s.accepte(","): break
                ex = s.explist() if s.accepte("=") else []
                return ("local", noms, ex, l)
            if k == "function":
                s.avance(); chemin = [s.avance()[1]]; methode = False
                while s.v() in (".", ":"):
                    if s.avance()[1] == ":": methode = True
                    chemin.append(s.avance()[1])
                return ("funcstat", chemin, methode, s.corps(".".join(chemin), methode), l)
            if k == "if":
                s.avance(); clauses = []
                c = s.expr(); s.attend("then"); clauses.append((c, s.bloc({"elseif", "else", "end"})))
                sinon = None
                while True:
                    if s.accepte("elseif"): c = s.expr(); s.attend("then"); clauses.append((c, s.bloc({"elseif", "else", "end"})))
                    elif s.accepte("else"): sinon = s.bloc({"end"}); s.attend("end"); break
                    else: s.attend("end"); break
                return ("if", clauses, sinon, l)
            if k == "while":
                s.avance(); c = s.expr(); s.attend("do"); b = s.bloc({"end"}); s.attend("end"); return ("while", c, b, l)
            if k == "repeat":
                s.avance(); b = s.bloc({"until"}); s.attend("until"); c = s.expr(); return ("repeat", b, c, l)
            if k == "do":
                s.avance(); b = s.bloc({"end"}); s.attend("end"); return ("do", b, l)
            if k == "for":
                s.avance(); n1 = s.avance()[1]
                if s.accepte(":"): s.type_()
                if s.accepte("="):
                    a = s.expr(); s.attend(","); b = s.expr(); c = s.expr() if s.accepte(",") else None
                    s.attend("do"); corps = s.bloc({"end"}); s.attend("end"); return ("fornum", n1, a, b, c, corps, l)
                noms = [n1]
                while s.accepte(","):
                    noms.append(s.avance()[1])
                    if s.accepte(":"): s.type_()
                s.attend("in"); ex = s.explist(); s.attend("do"); corps = s.bloc({"end"}); s.attend("end"); return ("forin", noms, ex, corps, l)
            if k == "break": s.avance(); return ("break", l)
        if x[0] == "name" and x[1] == "continue" and s.pk(1)[1] not in ("(", "=", ".", ":", "[", "{") and s.pk(1)[0] != "str":
            s.avance(); return ("continue", l)
        if x[0] == "name" and x[1] in ("type", "export") and s.pk(1)[0] == "name":
            # déclaration de type : on saute jusqu'à la fin de la ligne
            while s.pk()[2] == l and s.pk()[0] != "eof": s.avance()
            return None
        # affectation ou appel
        e = s.suffixe()
        if s.v() in ("=", ","):
            cibles = [e]
            while s.accepte(","): cibles.append(s.suffixe())
            s.attend("="); return ("assign", cibles, s.explist(), l)
        if s.v() in ("+=", "-=", "*=", "/=", "//=", "%=", "^=", "..="):
            op = s.avance()[1][:-1]; return ("compound", e, op, s.expr(), l)
        if e[0] not in ("call", "method"): raise SyntaxError(f"ligne {l} : instruction invalide ({s.v()})")
        return ("exprstat", e, l)
    def corps(s, nom="?", methode=False):
        if s.v() == "<":
            while s.v() != ">": s.avance()
            s.avance()
        s.attend("("); params, va = (["self"] if methode else []), False
        while s.v() != ")":
            if s.accepte("..."):
                va = True
                if s.accepte(":"): s.type_()
            else:
                params.append(s.avance()[1])
                if s.accepte(":"): s.type_()
            s.accepte(",")
        s.attend(")")
        if s.accepte(":"): s.type_()
        b = s.bloc({"end"}); s.attend("end")
        return ("func", params, va, b, nom)
    def explist(s):
        ex = [s.expr()]
        while s.accepte(","): ex.append(s.expr())
        return ex
    def expr(s, lim=0):
        x = s.pk()
        if x[1] in ("not", "-", "#") and x[0] in ("kw", "op"):
            s.avance(); e = ("un", x[1], s.expr(9))
        else:
            e = s.simple()
        while True:
            op = s.v()
            if s.pk()[0] not in ("op", "kw") or op not in BIN: break
            p = BIN[op]
            if p <= lim: break
            s.avance(); d = s.expr(p - 1 if op in DROITE else p); e = ("bin", op, e, d)
        if s.v() == "::": s.avance(); s.type_()
        return e
    def simple(s):
        x = s.pk()
        if x[0] == "num": s.avance(); return ("const", x[1])
        if x[0] == "str": s.avance(); return ("const", x[1])
        if x[0] == "istr": s.avance(); return ("istr", x[1])
        if x[0] == "kw":
            if x[1] == "nil": s.avance(); return ("const", None)
            if x[1] == "true": s.avance(); return ("const", True)
            if x[1] == "false": s.avance(); return ("const", False)
            if x[1] == "function": s.avance(); return s.corps("anonyme")
            if x[1] == "if":
                s.avance(); c = s.expr(); s.attend("then"); a = s.expr(); branches = [(c, a)]
                while s.accepte("elseif"): c = s.expr(); s.attend("then"); branches.append((c, s.expr()))
                s.attend("else"); return ("ifexp", branches, s.expr())
        if x[1] == "...": s.avance(); return ("vararg",)
        if x[1] == "{": return s.table()
        return s.suffixe()
    def table(s):
        s.attend("{"); champs = []
        while s.v() != "}":
            if s.v() == "[" and s.pk()[0] == "op":
                s.avance(); k = s.expr(); s.attend("]"); s.attend("="); champs.append(("k", k, s.expr()))
            elif s.pk()[0] == "name" and s.pk(1)[1] == "=" and s.pk(1)[0] == "op":
                k = s.avance()[1]; s.avance(); champs.append(("k", ("const", k), s.expr()))
            else:
                champs.append(("p", s.expr()))
            if not (s.accepte(",") or s.accepte(";")): break
        s.attend("}"); return ("table", champs)
    def suffixe(s):
        x = s.pk()
        if x[1] == "(" and x[0] == "op":
            s.avance(); e = ("paren", s.expr()); s.attend(")")
        elif x[0] == "name": s.avance(); e = ("name", x[1], x[2])
        else: raise SyntaxError(f"ligne {x[2]} : expression inattendue '{x[1]}'")
        while True:
            v, ty = s.v(), s.pk()[0]
            if v == "." and ty == "op": s.avance(); e = ("index", e, ("const", s.avance()[1]))
            elif v == "[" and ty == "op": s.avance(); k = s.expr(); s.attend("]"); e = ("index", e, k)
            elif v == ":" and ty == "op" and s.pk(1)[0] == "name" and (s.pk(2)[1] in ("(", "{") or s.pk(2)[0] == "str"):
                s.avance(); nom = s.avance()[1]; e = ("method", e, nom, s.args(), x[2])
            elif (v == "(" and ty == "op" and s.pk()[2] == s.t[s.i - 1][2]) or (v == "{" and ty == "op") or ty == "str":
                e = ("call", e, s.args(), x[2])
            else: return e
    def args(s):
        if s.pk()[0] == "str": return [("const", s.avance()[1])]
        if s.v() == "{": return [s.table()]
        s.attend("(")
        if s.accepte(")"): return []
        a = s.explist(); s.attend(")"); return a

# ---------------------------------------------------------------- Valeurs
class LuaError(Exception):
    def __init__(s, valeur, trace=""): super().__init__(str(valeur)); s.valeur = valeur; s.trace = trace
class Table:
    __slots__ = ("h", "mt")
    def __init__(s, h=None): s.h = h or {}; s.mt = None
    def get(s, k):
        k = cle(k)
        if k in s.h: return s.h[k]
        if s.mt is not None:
            i = s.mt.h.get("__index")
            if i is not None:
                return i.get(k) if isinstance(i, Table) else premier(appeler(i, [s, k]))
        return None
    def set(s, k, v):
        k = cle(k)
        if k is None: raise LuaError("index nil")
        if v is None: s.h.pop(k, None)
        else: s.h[k] = v
    def longueur(s):
        n = 0
        while (n + 1) in s.h: n += 1
        return n
def cle(k):
    if isinstance(k, float) and k.is_integer(): return int(k)
    return k
class Fonction:
    def __init__(s, nom, py=None, ast=None, env=None, interp=None):
        s.nom, s.py, s.ast, s.env, s.interp = nom, py, ast, env, interp
def premier(lst): return lst[0] if lst else None
def appeler(f, args):
    if isinstance(f, Fonction):
        if f.py: r = f.py(*args); return r if isinstance(r, list) else [r]
        return f.interp.appeler_lua(f, args)
    if callable(f): r = f(*args); return r if isinstance(r, list) else [r]
    mt = getattr(f, "mt", None)
    if isinstance(f, Table) and f.mt and f.mt.h.get("__call"): return appeler(f.mt.h["__call"], [f] + args)
    if hasattr(f, "__lua_call__"): return f.__lua_call__(args)
    raise LuaError(f"attempt to call a {type_lua(f)} value")
def type_lua(v):
    if v is None: return "nil"
    if isinstance(v, bool): return "boolean"
    if isinstance(v, (int, float)): return "number"
    if isinstance(v, str): return "string"
    if isinstance(v, Table): return "table"
    if isinstance(v, Fonction) or callable(v): return "function"
    return "userdata"
def vrai(v): return v is not None and v is not False
def nombre_txt(x):
    if isinstance(x, bool): return "true" if x else "false"
    if isinstance(x, int): return str(x)
    if isinstance(x, float):
        if x != x: return "nan"
        if x in (math.inf, -math.inf): return "inf" if x > 0 else "-inf"
        if x.is_integer() and abs(x) < 1e15: return str(int(x))
        return "%.14g" % x
    return str(x)
def tostring(v):
    if v is None: return "nil"
    if isinstance(v, (bool, int, float)): return nombre_txt(v)
    if isinstance(v, str): return v
    if isinstance(v, Table):
        if v.mt and v.mt.h.get("__tostring"): return premier(appeler(v.mt.h["__tostring"], [v]))
        return "table: %x" % id(v)
    if hasattr(v, "__lua_tostring__"): return v.__lua_tostring__()
    return "function: %x" % id(v) if type_lua(v) == "function" else "userdata"

class Retour(Exception):
    def __init__(s, vals): s.vals = vals
class Arret(Exception): pass
class Suite(Exception): pass

# ---------------------------------------------------------------- Évaluateur
class Env:
    __slots__ = ("vars", "parent")
    def __init__(s, parent=None): s.vars = {}; s.parent = parent
    def cherche(s, n):
        e = s
        while e is not None:
            if n in e.vars: return e
            e = e.parent
        return None

class Interp:
    def __init__(s, globales):
        s.G = globales  # dict Python
        s.pas = 0
    def executer(s, source, nom="?", varargs=()):
        ast = Parseur(lexer(source)).bloc(set())
        f = Fonction(nom, ast=("func", [], True, ast, nom), env=Env(), interp=s)
        return s.appeler_lua(f, list(varargs))
    def appeler_lua(s, f, args):
        _, params, va, corps, nom = f.ast
        env = Env(f.env)
        for i, p in enumerate(params): env.vars[p] = args[i] if i < len(args) else None
        if va: env.vars["..."] = list(args[len(params):])
        try:
            s.bloc(corps, env)
        except Retour as r:
            return r.vals
        return []
    def bloc(s, stats, env):
        for st in stats: s.stat(st, env)
    def lire_nom(s, n, env, l=0):
        e = env.cherche(n)
        if e is not None: return e.vars[n]
        if n in s.G: return s.G[n]
        return None
    def ecrire_nom(s, n, v, env):
        e = env.cherche(n)
        if e is not None: e.vars[n] = v
        else: s.G[n] = v
    def stat(s, st, env):
        k = st[0]
        s.pas += 1
        if s.pas > 5_000_000: raise LuaError("boucle infinie ? (5 millions d'instructions)")
        if k == "local":
            vals = s.explist(st[2], env)
            for i, n in enumerate(st[1]): env.vars[n] = vals[i] if i < len(vals) else None
        elif k == "assign":
            vals = s.explist(st[2], env)
            for i, c in enumerate(st[1]): s.affecter(c, vals[i] if i < len(vals) else None, env)
        elif k == "compound":
            v = s.binop(st[2], s.ev(st[1], env), s.ev(st[3], env)); s.affecter(st[1], v, env)
        elif k == "exprstat": s.ev_multi(st[1], env)
        elif k == "localfunc":
            env.vars[st[1]] = None; env.vars[st[1]] = Fonction(st[1], ast=st[2], env=env, interp=s)
        elif k == "funcstat":
            f = Fonction(".".join(st[1]), ast=st[3], env=env, interp=s)
            if len(st[1]) == 1: s.ecrire_nom(st[1][0], f, env)
            else:
                t = s.lire_nom(st[1][0], env)
                for n in st[1][1:-1]: t = s.indexer(t, n)
                s.affecter_index(t, st[1][-1], f)
        elif k == "if":
            for c, b in st[1]:
                if vrai(s.ev(c, env)): s.bloc(b, Env(env)); return
            if st[2] is not None: s.bloc(st[2], Env(env))
        elif k == "while":
            while vrai(s.ev(st[1], env)):
                try: s.bloc(st[2], Env(env))
                except Arret: break
                except Suite: continue
        elif k == "repeat":
            while True:
                e2 = Env(env)
                try: s.bloc(st[1], e2)
                except Arret: break
                except Suite: pass
                if vrai(s.ev(st[2], e2)): break
        elif k == "do": s.bloc(st[1], Env(env))
        elif k == "fornum":
            a, b = s.ev(st[2], env), s.ev(st[3], env); c = s.ev(st[4], env) if st[4] else 1
            i = a
            while (c > 0 and i <= b) or (c < 0 and i >= b):
                e2 = Env(env); e2.vars[st[1]] = i
                try: s.bloc(st[5], e2)
                except Arret: break
                except Suite: pass
                i += c
        elif k == "forin":
            vals = s.explist(st[2], env)
            f, etat, ctl = (vals + [None, None, None])[:3]
            if isinstance(f, Table) and not (f.mt and f.mt.h.get("__call")):
                # itération généralisée de Luau : comme pairs
                t = f
                cles = list(t.h.keys()); n = t.longueur()
                ordre = list(range(1, n + 1)) + [c for c in cles if not (isinstance(c, int) and 1 <= c <= n)]
                for c in ordre:
                    if c not in t.h: continue
                    e2 = Env(env); e2.vars[st[1][0]] = c
                    if len(st[1]) > 1: e2.vars[st[1][1]] = t.h[c]
                    try: s.bloc(st[3], e2)
                    except Arret: break
                    except Suite: pass
                return
            while True:
                r = appeler(f, [etat, ctl])
                if not r or r[0] is None: break
                ctl = r[0]
                e2 = Env(env)
                for i, n in enumerate(st[1]): e2.vars[n] = r[i] if i < len(r) else None
                try: s.bloc(st[3], e2)
                except Arret: break
                except Suite: pass
        elif k == "return": raise Retour(s.explist(st[1], env))
        elif k == "break": raise Arret()
        elif k == "continue": raise Suite()
        else: raise LuaError("instruction inconnue " + k)
    def affecter(s, c, v, env):
        if c[0] == "name": s.ecrire_nom(c[1], v, env)
        elif c[0] == "index": s.affecter_index(s.ev(c[1], env), s.ev(c[2], env), v)
        else: raise LuaError("affectation invalide")
    def affecter_index(s, t, k, v):
        if isinstance(t, Table):
            if k not in t.h and t.mt and t.mt.h.get("__newindex") is not None:
                ni = t.mt.h["__newindex"]
                if isinstance(ni, Table): ni.set(k, v)
                else: appeler(ni, [t, k, v])
                return
            t.set(k, v)
        elif hasattr(t, "__lua_setindex__"): t.__lua_setindex__(k, v)
        else: raise LuaError(f"attempt to index {type_lua(t)} with '{tostring(k)}' (écriture)")
    def indexer(s, o, k):
        if isinstance(o, Table): return o.get(k)
        if isinstance(o, str):
            return s.G["string"].get(k)
        if hasattr(o, "__lua_index__"): return o.__lua_index__(k)
        raise LuaError(f"attempt to index {type_lua(o)} with '{tostring(k)}'")
    def explist(s, ex, env):
        if not ex: return []
        vals = [s.ev(e, env) for e in ex[:-1]]
        return vals + s.ev_multi(ex[-1], env)
    def ev_multi(s, e, env):
        k = e[0]
        if k == "call":
            f = s.ev(e[1], env); args = s.explist(e[2], env)
            if f is None: raise LuaError(f"ligne {e[3]} : attempt to call a nil value ({s.nom_expr(e[1])})")
            return appeler(f, args)
        if k == "method":
            o = s.ev(e[1], env); m = s.indexer(o, e[2])
            if m is None: raise LuaError(f"ligne {e[4]} : méthode '{e[2]}' inexistante sur {type_lua(o)} ({s.nom_expr(e[1])})")
            return appeler(m, [o] + s.explist(e[3], env))
        if k == "vararg": return list(env.cherche("...").vars["..."])
        return [s.ev(e, env)]
    def nom_expr(s, e):
        if e[0] == "name": return e[1]
        if e[0] == "index" and e[2][0] == "const": return s.nom_expr(e[1]) + "." + str(e[2][1])
        return "?"
    def ev(s, e, env):
        k = e[0]
        if k == "const": return e[1]
        if k == "name": return s.lire_nom(e[1], env)
        if k == "index": return s.indexer(s.ev(e[1], env), s.ev(e[2], env))
        if k in ("call", "method", "vararg"): return premier(s.ev_multi(e, env))
        if k == "paren": return s.ev(e[1], env)
        if k == "func": return Fonction(e[4], ast=e, env=env, interp=s)
        if k == "table":
            t = Table(); n = 1
            for j, c in enumerate(e[1]):
                if c[0] == "k": t.set(s.ev(c[1], env), s.ev(c[2], env))
                else:
                    if j == len(e[1]) - 1:
                        for v in s.ev_multi(c[1], env):
                            if v is not None: t.h[n] = v
                            n += 1
                    else:
                        v = s.ev(c[1], env)
                        if v is not None: t.h[n] = v
                        n += 1
            return t
        if k == "un":
            v = s.ev(e[2], env)
            if e[1] == "not": return not vrai(v)
            if e[1] == "-":
                if isinstance(v, (int, float)) and not isinstance(v, bool): return -v
                if hasattr(v, "__lua_unm__"): return v.__lua_unm__()
                raise LuaError("arithmétique sur " + type_lua(v))
            if e[1] == "#":
                if isinstance(v, str): return len(v.encode("utf-8"))
                if isinstance(v, Table): return v.longueur()
                raise LuaError("# sur " + type_lua(v))
        if k == "bin":
            op = e[1]
            if op == "and":
                a = s.ev(e[2], env); return s.ev(e[3], env) if vrai(a) else a
            if op == "or":
                a = s.ev(e[2], env); return a if vrai(a) else s.ev(e[3], env)
            return s.binop(op, s.ev(e[2], env), s.ev(e[3], env))
        if k == "ifexp":
            for c, v in e[1]:
                if vrai(s.ev(c, env)): return s.ev(v, env)
            return s.ev(e[2], env)
        if k == "istr":
            def rempl(m): return tostring(s.executer_expr(m.group(1), env))
            return re.sub(r"\{([^}]*)\}", rempl, e[1])
        raise LuaError("expression inconnue " + k)
    def executer_expr(s, src, env):
        p = Parseur(lexer(src)); return s.ev(p.expr(), env)
    def binop(s, op, a, b):
        num = lambda x: isinstance(x, (int, float)) and not isinstance(x, bool)
        if op == "..":
            if isinstance(a, (str, int, float)) and isinstance(b, (str, int, float)) and not isinstance(a, bool) and not isinstance(b, bool):
                return (a if isinstance(a, str) else nombre_txt(a)) + (b if isinstance(b, str) else nombre_txt(b))
            raise LuaError(f"attempt to concatenate {type_lua(a)} with {type_lua(b)}")
        if op in ("==", "~="):
            eg = (a == b and type(a) == type(b)) if not (num(a) and num(b)) else a == b
            if isinstance(a, bool) or isinstance(b, bool): eg = a is b
            if hasattr(a, "__lua_eq__"): eg = a.__lua_eq__(b)
            return eg if op == "==" else not eg
        if op in ("<", ">", "<=", ">="):
            if not ((num(a) and num(b)) or (isinstance(a, str) and isinstance(b, str))):
                raise LuaError(f"attempt to compare {type_lua(a)} {op} {type_lua(b)}")
            return {"<": a < b, ">": a > b, "<=": a <= b, ">=": a >= b}[op]
        if num(a) and num(b):
            if op == "+": return a + b
            if op == "-": return a - b
            if op == "*": return a * b
            if op == "/": return a / b if b != 0 else (math.inf if a > 0 else -math.inf if a < 0 else math.nan)
            if op == "//": return math.floor(a / b) if b != 0 else math.inf
            if op == "%": return a - math.floor(a / b) * b if b != 0 else math.nan
            if op == "^": return float(a) ** b
        for x in (a, b):
            if hasattr(x, "__lua_arith__"): return x.__lua_arith__(op, a, b)
        if isinstance(a, str) and num(b): return s.binop(op, float(a), b)
        raise LuaError(f"attempt to perform arithmetic ({op}) on {type_lua(a)} and {type_lua(b)}")
