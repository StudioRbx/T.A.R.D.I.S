"""Bibliothèque standard Luau et faux objets Roblox pour l'interpréteur luau.py (simulation)."""
import re, math, json, heapq, itertools, os
from luau import Table, Fonction, LuaError, appeler, premier, tostring, type_lua, vrai, nombre_txt, Interp, cle

# ---------------------------------------------------------------- Motifs Lua → regex Python
CLASSES = {"a": "A-Za-z", "d": "0-9", "l": "a-z", "s": r"\s", "u": "A-Z", "w": "A-Za-z0-9", "x": "0-9A-Fa-f", "p": r"!-/:-@\[-`{-~", "c": r"\x00-\x1f"}
def motif(p):
    out, i, n = [], 0, len(p)
    while i < n:
        c = p[i]
        if c == "%":
            d = p[i + 1]; i += 2
            if d.lower() in CLASSES:
                cl = CLASSES[d.lower()]; out.append(("[^%s]" if d.isupper() else "[%s]") % cl)
            elif d == "b": raise LuaError("motif %b non géré")
            else: out.append(re.escape(d))
            continue
        if c == "[":
            j, buf = i + 1, ["["]
            if j < n and p[j] == "^": buf.append("^"); j += 1
            while j < n and p[j] != "]" or j == i + 1:
                if p[j] == "%":
                    d = p[j + 1]; buf.append(CLASSES.get(d.lower(), re.escape(d)) if d.lower() in CLASSES and d.islower() else re.escape(d)); j += 2; continue
                buf.append("\\" + p[j] if p[j] in "\\[]" else p[j]); j += 1
            buf.append("]"); out.append("".join(buf)); i = j + 1; continue
        if c == "-": out.append("*?"); i += 1; continue
        if c in "*+?": out.append(c); i += 1; continue
        if c == "^" and i == 0: out.append("^"); i += 1; continue
        if c == "$" and i == n - 1: out.append(r"\Z"); i += 1; continue
        if c == "(" and i + 1 < n and p[i + 1] == ")": out.append("()"); i += 2; continue
        if c in "()": out.append(c); i += 1; continue
        if c == ".": out.append("(?s:.)"); i += 1; continue
        out.append(re.escape(c)); i += 1
    return re.compile("".join(out))
def captures(m, pos_mode=False):
    if m.re.groups == 0: return [m.group(0)]
    res = []
    for g in range(1, m.re.groups + 1):
        res.append(m.start(g) + 1 if m.group(g) == "" and m.re.pattern.count("()") else m.group(g))
    return res

def bib_string(I):
    t = Table()
    def sub(s, i=1, j=-1):
        s = tostring(s); n = len(s); i, j = int(i), int(j if j is not None else -1)
        if i < 0: i = max(n + i + 1, 1)
        elif i == 0: i = 1
        if j < 0: j = n + j + 1
        elif j > n: j = n
        return s[i - 1:j] if i <= j else ""
    def find(s, p, init=1, plain=False):
        init = int(init or 1); init = len(s) + init + 1 if init < 0 else init
        if vrai(plain):
            k = s.find(p, init - 1); return [None] if k < 0 else [k + 1, k + len(p)]
        m = motif(p).search(s, init - 1)
        if not m: return [None]
        return [m.start() + 1, m.end()] + (captures(m) if m.re.groups else [])
    def match(s, p, init=1):
        m = motif(p).search(tostring(s), int(init or 1) - 1)
        return captures(m) if m else [None]
    def gmatch(s, p):
        it = motif(p).finditer(tostring(s))
        def suivant(*_):
            m = next(it, None); return captures(m) if m else [None]
        return Fonction("gmatch", py=suivant)
    def gsub(s, p, r, nmax=None):
        rx, compte = motif(p), [0]
        def rempl(m):
            if nmax is not None and compte[0] >= nmax: return m.group(0)
            compte[0] += 1
            caps = captures(m)
            if isinstance(r, str):
                return re.sub(r"%(\d|%)", lambda x: "%" if x.group(1) == "%" else (m.group(0) if x.group(1) == "0" else tostring(caps[int(x.group(1)) - 1])), r)
            if isinstance(r, Table): v = r.get(caps[0])
            else: v = premier(appeler(r, caps))
            return m.group(0) if not vrai(v) else tostring(v)
        res = rx.sub(rempl, tostring(s)); return [res, compte[0]]
    def fmt(f, *args):
        args = list(args); out, i = [], 0
        def un(m):
            spec = m.group(0)
            if spec == "%%": return "%"
            conv = spec[-1]; v = args.pop(0) if args else None
            if conv in "di": return (spec[:-1] + "d") % int(math.floor(v)) if isinstance(v, (int, float)) else (_ for _ in ()).throw(LuaError("format %d : nombre attendu, reçu " + type_lua(v)))
            if conv in "fFeEgG": return spec % float(v)
            if conv in "xX": return spec % int(v)
            if conv == "s": return (spec[:-1] + "s") % tostring(v)
            if conv == "q": return '"' + tostring(v).replace('"', '\\"') + '"'
            if conv == "c": return chr(int(v))
            return spec
        return re.sub(r"%[-+ #0]*\d*(?:\.\d+)?[diouxXeEfFgGqsc%]", un, f)
    def rep(s, n, sep=""): return sep.join([s] * max(int(n), 0))
    def split(s, sep=","):
        t2 = Table()
        for i, x in enumerate(s.split(sep)): t2.h[i + 1] = x
        return t2
    # string.byte compte en octets UTF-8, comme Roblox (un « é » en fait deux) ; le dernier texte encodé est gardé
    cache = {"s": None, "b": b""}
    def octets_de(s, i=1, j=None):
        if cache["s"] is not s:
            cache["s"], cache["b"] = s, s.encode("utf-8")
        b = cache["b"]; i = int(i); j = int(j) if j is not None else i
        if i < 0: i = len(b) + i + 1
        if j < 0: j = len(b) + j + 1
        return list(b[max(i, 1) - 1:j])
    for nom, f in dict(sub=sub, find=find, match=match, gmatch=gmatch, gsub=gsub, format=fmt, rep=rep, split=split,
                      lower=lambda s: s.lower(), upper=lambda s: s.upper(), len=lambda s: len(s.encode()), reverse=lambda s: s[::-1],
                      byte=octets_de, char=lambda *c: "".join(chr(int(x)) for x in c)).items():
        t.h[nom] = Fonction("string." + nom, py=f)
    return t

def bib_table():
    t = Table()
    def insert(tb, a, b=None):
        if b is None: tb.h[tb.longueur() + 1] = a; return []
        n = tb.longueur()
        for i in range(n, int(a) - 1, -1): tb.h[i + 1] = tb.h[i]
        tb.h[int(a)] = b; return []
    def remove(tb, pos=None):
        n = tb.longueur()
        if n == 0: return [None]
        pos = n if pos is None else int(pos)
        v = tb.h.get(pos)
        for i in range(pos, n): tb.h[i] = tb.h[i + 1]
        tb.h.pop(n, None); return [v]
    def concat(tb, sep="", i=1, j=None):
        j = tb.longueur() if j is None else j
        return sep.join(tostring(tb.h[k]) for k in range(int(i), int(j) + 1))
    def sort(tb, comp=None):
        import functools
        vals = [tb.h[i] for i in range(1, tb.longueur() + 1)]
        if comp: vals.sort(key=functools.cmp_to_key(lambda a, b: -1 if vrai(premier(appeler(comp, [a, b]))) else (1 if vrai(premier(appeler(comp, [b, a]))) else 0)))
        else: vals.sort()
        for i, v in enumerate(vals): tb.h[i + 1] = v
        return []
    def find(tb, v, init=1):
        for i in range(int(init), tb.longueur() + 1):
            if tb.h.get(i) == v: return i
        return None
    def clone(tb): n = Table(dict(tb.h)); n.mt = tb.mt; return n
    def clear(tb): tb.h.clear(); return []
    def unpack(tb, i=1, j=None): j = tb.longueur() if j is None else j; return [tb.h.get(k) for k in range(int(i), int(j) + 1)]
    def pack(*a):
        n = Table({i + 1: v for i, v in enumerate(a) if v is not None}); n.h["n"] = len(a); return n
    def create(n, v=None): return Table({i + 1: v for i in range(int(n))} if v is not None else {})
    def freeze(tb): return tb
    for nom, f in dict(insert=insert, remove=remove, concat=concat, sort=sort, find=find, clone=clone, clear=clear, unpack=unpack, pack=pack,
                      create=create, freeze=freeze, isfrozen=lambda tb: False).items():
        t.h[nom] = Fonction("table." + nom, py=f)
    return t

# ---------------------------------------------------------------- Ordonnanceur (temps virtuel) et signaux
class Horloge:
    def __init__(s): s.t = 0.0; s.file = []; s.compteur = itertools.count()
    def plus_tard(s, delai, f, args=()): heapq.heappush(s.file, (s.t + max(delai, 0), next(s.compteur), f, args))
    def avancer(s, duree):
        fin = s.t + duree
        while s.file and s.file[0][0] <= fin:
            t, _, f, args = heapq.heappop(s.file); s.t = max(s.t, t)
            f(*args)
        s.t = fin
H = Horloge()


import threading, sys, traceback
sys.setrecursionlimit(20000)
try:
    threading.stack_size(256 * 1024 * 1024)
except ValueError:  # Windows refuse 256 Mo tout rond (V6.9.10.8)
    threading.stack_size(255 * 1024 * 1024)
ERREURS = []   # erreurs levées dans les tâches (comme la sortie rouge de Roblox)
ATTENTE = {"reelle": False}   # V7.1.2 : WaitForChild attend (banc d'essai) au lieu d'échouer tout de suite
ATTENTES = []  # avertissements « Infinite yield possible » (attente de plus de 5 s)
EN_ATTENTE = []  # V7.1.2 : WaitForChild encore en attente (un script bloqué)
class ArretTache(BaseException): pass  # V7.1.2 : arrête une tâche abandonnée (jamais attrapée par pcall)
TACHES = []  # V7.1.2 : les tâches lancées, pour les arrêter entre deux places du banc d'essai
def arreter_taches():
    """V7.1.2 : réveille chaque tâche en attente pour qu'elle s'arrête ; libère ses fils (sinon Windows en manque)."""
    for t in list(TACHES):
        if t.demarree and not t.fini:
            t.arret = True; t.rendu.clear(); t.ev.set(); t.rendu.wait(2)
    TACHES.clear()
class Tache:
    courante = threading.local()
    def __init__(s, f, args, nom="tâche"):
        s.f, s.args, s.nom = f, list(args), nom
        s.ev, s.rendu, s.fini, s.demarree = threading.Event(), threading.Event(), False, False
        s.arret = False; TACHES.append(s)
    def _corps(s):
        s.ev.wait(); s.ev.clear()
        Tache.courante.t = s
        try:
            if s.arret: raise ArretTache()
            appeler(s.f, s.args)
        except ArretTache:
            pass
        except LuaError as e:
            ERREURS.append(f"[{s.nom}] {e}")
        except Exception as e:
            ERREURS.append(f"[{s.nom}] erreur Python : {e!r}\n" + traceback.format_exc()[-800:])
        s.fini = True
        s.rendu.set()
def reprendre(t):
    if t.fini: return
    if not t.demarree:
        t.demarree = True
        threading.Thread(target=t._corps, daemon=True).start()
    t.rendu.clear()
    t.ev.set()
    t.rendu.wait()
def ceder():
    t = getattr(Tache.courante, "t", None)
    if t is None: raise LuaError("task.wait appelé hors d'une tâche")
    t.rendu.set(); t.ev.wait(); t.ev.clear()
    Tache.courante.t = t
    if t.arret: raise ArretTache()
def lancer(f, *args, nom="tâche"):
    t = Tache(f, args, nom); reprendre(t); return t
def attendre(d=0):
    t = getattr(Tache.courante, "t", None)
    H.plus_tard(d or 0.0, reprendre, (t,))
    ceder()
    return [d]

class Signal:
    def __init__(s, nom="signal"): s.nom = nom; s.connexions = []; s.attente = []
    def __lua_index__(s, k):
        if k == "Connect" or k == "connect": return Fonction("Connect", py=lambda _s, f: s.connecter(f))
        if k == "Once": return Fonction("Once", py=lambda _s, f: s.connecter(f, une_fois=True))
        if k == "Wait": return Fonction("Wait", py=lambda _s: s.attendre())
        if k == "Fire": return Fonction("Fire", py=lambda _s, *a: s.declencher(*a))
        raise LuaError(f"Signal.{k} inconnu")
    def connecter(s, f, une_fois=False):
        c = Connexion(s, f, une_fois); s.connexions.append(c); return c
    def declencher(s, *args):
        for c in list(s.connexions):
            if c.actif:
                if c.une_fois: c.actif = False
                lancer(c.f, *args, nom=s.nom)
        for t in s.attente: H.plus_tard(0, reprendre, (t,))
        s.attente = []
        return []
    def attendre(s):
        t = Tache.courante.t; s.attente.append(t); ceder(); return []
class Connexion:
    def __init__(s, sig, f, une_fois): s.sig, s.f, s.une_fois, s.actif = sig, f, une_fois, True
    def __lua_index__(s, k):
        if k == "Disconnect": return Fonction("Disconnect", py=lambda _s: setattr(s, "actif", False) or [])
        if k == "Connected": return s.actif
        raise LuaError("Connexion." + k)

# ---------------------------------------------------------------- Valeurs Roblox de remplissage (Vector3, Color3, CFrame...)
class Valeur:
    """Valeur Roblox fictive : tout champ, appel ou calcul renvoie une Valeur (suffisant pour charger la configuration)."""
    def __init__(s, nom="Valeur", args=()): s.nom, s.args = nom, list(args)
    def __lua_index__(s, k):
        if k in ("X", "Y", "Z", "R", "G", "B", "Magnitude", "Scale", "Offset", "Min", "Max", "Value", "Time") and not (s.nom == "Enum.KeyCode" and k in ("X", "Y", "Z", "R", "G", "B")):  # V6.9.10 : Enum.KeyCode.X est une touche
            return float(s.args[{"X": 0, "R": 0, "Y": 1, "G": 1, "Z": 2, "B": 2}.get(k, 0)]) if s.args and isinstance(s.args[0], (int, float)) and len(s.args) > {"X": 0, "R": 0, "Y": 1, "G": 1, "Z": 2, "B": 2}.get(k, 0) else 0.0
        if k == "Name": return s.nom.split(".")[-1]
        return Valeur(s.nom + "." + str(k))
    def __lua_call__(s, args): return [Valeur(s.nom + "()", args[1:] if args and args[0] is s else args)]
    def __lua_arith__(s, op, a, b):
        # V6.9.10 : avec les maths réelles (activer_maths), un Vector3 de remplissage à coordonnées connues devient calculable
        if MATHS["actif"]:
            va, vb = en_vec3(a), en_vec3(b)
            if (va is not None or isinstance(a, (int, float))) and (vb is not None or isinstance(b, (int, float))) and (va is not None or vb is not None):
                return Vec3.arith(op, va if va is not None else a, vb if vb is not None else b)
        return Valeur("calcul")
    def __lua_unm__(s): return Valeur("calcul")
    def __lua_eq__(s, o): return s is o or (isinstance(o, Valeur) and o.nom == s.nom and o.args == s.args)
    def __lua_tostring__(s): return s.nom
    def __lua_setindex__(s, k, v): pass
def constructeur(nom):
    t = Table()
    t.mt = Table({"__index": Fonction(nom, py=lambda _t, k: Fonction(nom + "." + k, py=lambda *a: Valeur(nom, a)))})
    return t

class Couleur(Valeur):
    """Color3 calculable (V6.9.9) : R, G, B entre 0 et 1, Lerp, ToHSV. Les arguments d'origine restent dans args
    (fromRGB(4, 10, 24).args == [4, 10, 24], comme avant) ; un Lerp donne des args sur 0..255."""
    def __init__(s, r, g, b, args=None):
        super().__init__("Color3", list(args) if args is not None else [r * 255, g * 255, b * 255])
        s.r, s.g, s.b = float(r), float(g), float(b)
    def rgb255(s): return tuple(int(round(x * 255)) for x in (s.r, s.g, s.b))
    def __lua_index__(s, k):
        if k == "R": return s.r
        if k == "G": return s.g
        if k == "B": return s.b
        if k == "Lerp":
            def lerp(_s, o, a):
                if not isinstance(o, Couleur) or not isinstance(a, (int, float)): return Valeur("Color3.Lerp()")
                return Couleur(s.r + (o.r - s.r) * a, s.g + (o.g - s.g) * a, s.b + (o.b - s.b) * a)
            return Fonction("Lerp", py=lerp)
        if k == "ToHSV":
            import colorsys
            return Fonction("ToHSV", py=lambda _s: list(colorsys.rgb_to_hsv(s.r, s.g, s.b)))
        return Valeur.__lua_index__(s, k)
    def __lua_eq__(s, o):
        return isinstance(o, Couleur) and abs(s.r - o.r) < 1e-9 and abs(s.g - o.g) < 1e-9 and abs(s.b - o.b) < 1e-9
def constructeur_couleur():
    import colorsys
    t = constructeur("Color3")
    n = lambda x: float(x) if isinstance(x, (int, float)) else 0.0
    t.h["new"] = Fonction("Color3.new", py=lambda r=0, g=0, b=0: Couleur(n(r), n(g), n(b), [r, g, b]))
    t.h["fromRGB"] = Fonction("Color3.fromRGB", py=lambda r=0, g=0, b=0: Couleur(n(r) / 255, n(g) / 255, n(b) / 255, [r, g, b]))
    t.h["fromHSV"] = Fonction("Color3.fromHSV", py=lambda h=0, sa=0, v=0: Couleur(*colorsys.hsv_to_rgb(n(h) % 1, n(sa), n(v))))
    return t

# ---------------------------------------------------------------- Maths réelles (V6.9.10), sur demande : activer_maths(G)
# Vector3 et CFrame calculables (positions, rotations, LookVector, Lerp, ToEulerAnglesYXZ…). Les autres simulations
# gardent les valeurs de remplissage : rien ne change pour elles tant que activer_maths n'est pas appelé.
MATHS = {"actif": False}
def _num(x): return isinstance(x, (int, float)) and not isinstance(x, bool)
def en_vec3(v):
    if isinstance(v, Vec3): return v
    if isinstance(v, Valeur) and v.nom == "Vector3" and len(v.args) == 3 and all(_num(a) for a in v.args): return Vec3(*v.args)
    return None
class Vec3(Valeur):
    def __init__(s, x=0.0, y=0.0, z=0.0):
        x, y, z = (float(c) if _num(c) else 0.0 for c in (x, y, z))
        super().__init__("Vector3", [x, y, z]); s.x, s.y, s.z = x, y, z
    def t(s): return (s.x, s.y, s.z)
    def norme(s): return math.sqrt(s.x * s.x + s.y * s.y + s.z * s.z)
    def unite(s):
        n = s.norme()
        return Vec3(s.x / n, s.y / n, s.z / n) if n > 0 else Vec3(math.nan, math.nan, math.nan)
    def dot(s, o): return s.x * o.x + s.y * o.y + s.z * o.z
    def cross(s, o): return Vec3(s.y * o.z - s.z * o.y, s.z * o.x - s.x * o.z, s.x * o.y - s.y * o.x)
    def __lua_index__(s, k):
        if k == "X": return s.x
        if k == "Y": return s.y
        if k == "Z": return s.z
        if k == "Magnitude": return s.norme()
        if k == "Unit": return s.unite()
        if k == "Dot": return Fonction("Dot", py=lambda _s, o: s.dot(en_vec3(o)))
        if k == "Cross": return Fonction("Cross", py=lambda _s, o: s.cross(en_vec3(o)))
        if k == "Lerp": return Fonction("Lerp", py=lambda _s, o, a: Vec3.arith("+", s, Vec3.arith("*", Vec3.arith("-", en_vec3(o), s), a)))
        if k == "Abs": return Fonction("Abs", py=lambda _s: Vec3(abs(s.x), abs(s.y), abs(s.z)))
        if k == "Max": return Fonction("Max", py=lambda _s, o: Vec3(*(max(a, b) for a, b in zip(s.t(), en_vec3(o).t()))))
        if k == "Min": return Fonction("Min", py=lambda _s, o: Vec3(*(min(a, b) for a, b in zip(s.t(), en_vec3(o).t()))))
        if k == "FuzzyEq": return Fonction("FuzzyEq", py=lambda _s, o, e=1e-5: all(abs(a - b) <= e for a, b in zip(s.t(), en_vec3(o).t())))
        return Valeur.__lua_index__(s, k)
    @staticmethod
    def arith(op, a, b):
        va, vb = en_vec3(a), en_vec3(b)
        A = va.t() if va is not None else (float(a),) * 3
        B = vb.t() if vb is not None else (float(b),) * 3
        if op == "+": return Vec3(*(x + y for x, y in zip(A, B)))
        if op == "-": return Vec3(*(x - y for x, y in zip(A, B)))
        if op == "*": return Vec3(*(x * y for x, y in zip(A, B)))
        if op == "/": return Vec3(*((x / y) if y != 0 else (math.inf if x > 0 else -math.inf if x < 0 else math.nan) for x, y in zip(A, B)))
        if op == "//": return Vec3(*(math.floor(x / y) for x, y in zip(A, B)))
        raise LuaError("Vector3 : opération " + op)
    def __lua_arith__(s, op, a, b):
        if isinstance(a, CF) or isinstance(b, CF): return CF.arith(op, a, b)
        if not all(en_vec3(x) is not None or _num(x) for x in (a, b)): return Valeur("calcul")  # avec une valeur de remplissage
        return Vec3.arith(op, a, b)
    def __lua_unm__(s): return Vec3(-s.x, -s.y, -s.z)
    def __lua_eq__(s, o):
        o = en_vec3(o)
        return o is not None and all(abs(a - b) < 1e-9 for a, b in zip(s.t(), o.t()))
    def __lua_tostring__(s): return "%g, %g, %g" % s.t()
def _mat(a, b): return tuple(tuple(sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)) for i in range(3))
def _tr(a): return tuple(tuple(a[j][i] for j in range(3)) for i in range(3))
def _app(R, v): return tuple(sum(R[i][k] * v[k] for k in range(3)) for i in range(3))
I3 = ((1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0))
def _rx(a): c, s_ = math.cos(a), math.sin(a); return ((1, 0, 0), (0, c, -s_), (0, s_, c))
def _ry(a): c, s_ = math.cos(a), math.sin(a); return ((c, 0, s_), (0, 1, 0), (-s_, 0, c))
def _rz(a): c, s_ = math.cos(a), math.sin(a); return ((c, -s_, 0), (s_, c, 0), (0, 0, 1))
def _quat(R):
    t = R[0][0] + R[1][1] + R[2][2]
    if t > 0:
        r = math.sqrt(1 + t) * 2; return ((R[2][1] - R[1][2]) / r, (R[0][2] - R[2][0]) / r, (R[1][0] - R[0][1]) / r, r / 4)
    if R[0][0] > R[1][1] and R[0][0] > R[2][2]:
        r = math.sqrt(1 + R[0][0] - R[1][1] - R[2][2]) * 2; return (r / 4, (R[0][1] + R[1][0]) / r, (R[0][2] + R[2][0]) / r, (R[2][1] - R[1][2]) / r)
    if R[1][1] > R[2][2]:
        r = math.sqrt(1 + R[1][1] - R[0][0] - R[2][2]) * 2; return ((R[0][1] + R[1][0]) / r, r / 4, (R[1][2] + R[2][1]) / r, (R[0][2] - R[2][0]) / r)
    r = math.sqrt(1 + R[2][2] - R[0][0] - R[1][1]) * 2; return ((R[0][2] + R[2][0]) / r, (R[1][2] + R[2][1]) / r, r / 4, (R[1][0] - R[0][1]) / r)
def _dequat(q):
    x, y, z, w = q; n = math.sqrt(x * x + y * y + z * z + w * w) or 1; x, y, z, w = x / n, y / n, z / n, w / n
    return ((1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)),
            (2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)),
            (2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)))
def _slerp(R1, R2, a):
    q1, q2 = _quat(R1), _quat(R2)
    d = sum(x * y for x, y in zip(q1, q2))
    if d < 0: q2, d = tuple(-x for x in q2), -d
    if d > 0.9995: return _dequat(tuple(x + (y - x) * a for x, y in zip(q1, q2)))
    th = math.acos(max(-1, min(1, d))); s1, s2 = math.sin((1 - a) * th) / math.sin(th), math.sin(a * th) / math.sin(th)
    return _dequat(tuple(s1 * x + s2 * y for x, y in zip(q1, q2)))
class CF(Valeur):
    """CFrame calculable : position p et matrice de rotation R (colonnes : RightVector, UpVector, -LookVector)."""
    def __init__(s, p=(0.0, 0.0, 0.0), R=None):
        s.p = tuple(float(c) for c in p); s.R = tuple(tuple(float(c) for c in ligne) for ligne in (R or I3))
        super().__init__("CFrame", list(s.p) + [c for ligne in s.R for c in ligne])
    def col(s, j): return Vec3(s.R[0][j], s.R[1][j], s.R[2][j])
    def fois(s, o): return CF(tuple(a + b for a, b in zip(_app(s.R, o.p), s.p)), _mat(s.R, o.R))
    def point(s, v): return Vec3(*(a + b for a, b in zip(_app(s.R, en_vec3(v).t()), s.p)))
    def inverse(s): Rt = _tr(s.R); return CF(tuple(-c for c in _app(Rt, s.p)), Rt)
    def __lua_index__(s, k):
        if k == "Position" or k == "p": return Vec3(*s.p)
        if k in ("X", "Y", "Z"): return s.p["XYZ".index(k)]
        if k == "Rotation": return CF((0, 0, 0), s.R)
        if k == "LookVector": return Vec3(-s.R[0][2], -s.R[1][2], -s.R[2][2])
        if k in ("RightVector", "XVector"): return s.col(0)
        if k in ("UpVector", "YVector"): return s.col(1)
        if k == "ZVector": return s.col(2)
        if k == "Inverse": return Fonction("Inverse", py=lambda _s: s.inverse())
        if k == "Lerp":
            def lerp(_s, o, a):
                if not isinstance(o, CF): return Valeur("CFrame")
                return CF(tuple(x + (y - x) * a for x, y in zip(s.p, o.p)), _slerp(s.R, o.R, a))
            return Fonction("Lerp", py=lerp)
        if k == "ToEulerAnglesYXZ":
            R = s.R
            return Fonction("ToEulerAnglesYXZ", py=lambda _s: [math.asin(max(-1, min(1, -R[1][2]))), math.atan2(R[0][2], R[2][2]), math.atan2(R[1][0], R[1][1])])
        if k == "Orthonormalize": return Fonction("Orthonormalize", py=lambda _s: CF(s.p, _dequat(_quat(s.R))))
        if k == "GetComponents": return Fonction("GetComponents", py=lambda _s: list(s.p) + [c for ligne in s.R for c in ligne])
        # Avec une valeur de remplissage (pièce dont la position n'est pas connue), le résultat reste une valeur de remplissage
        sv = lambda f: (lambda _s, v: f(v) if en_vec3(v) is not None else Valeur("Vector3"))
        sc = lambda f: (lambda _s, o: f(o) if isinstance(o, CF) else Valeur("CFrame"))
        if k == "PointToObjectSpace": return Fonction("PointToObjectSpace", py=sv(lambda v: s.inverse().point(v)))
        if k == "PointToWorldSpace": return Fonction("PointToWorldSpace", py=sv(lambda v: s.point(v)))
        if k == "VectorToObjectSpace": return Fonction("VectorToObjectSpace", py=sv(lambda v: Vec3(*_app(_tr(s.R), en_vec3(v).t()))))
        if k == "VectorToWorldSpace": return Fonction("VectorToWorldSpace", py=sv(lambda v: Vec3(*_app(s.R, en_vec3(v).t()))))
        if k == "ToObjectSpace": return Fonction("ToObjectSpace", py=sc(lambda o: s.inverse().fois(o)))
        if k == "ToWorldSpace": return Fonction("ToWorldSpace", py=sc(lambda o: s.fois(o)))
        return Valeur.__lua_index__(s, k)
    @staticmethod
    def arith(op, a, b):
        if isinstance(a, CF) and isinstance(b, CF) and op == "*": return a.fois(b)
        if isinstance(a, CF) and en_vec3(b) is not None:
            if op == "*": return a.point(b)
            if op == "+": return CF(tuple(x + y for x, y in zip(a.p, en_vec3(b).t())), a.R)
            if op == "-": return CF(tuple(x - y for x, y in zip(a.p, en_vec3(b).t())), a.R)
        raise LuaError("CFrame : opération " + op + " impossible")
    def __lua_arith__(s, op, a, b):
        if not all(isinstance(x, CF) or en_vec3(x) is not None for x in (a, b)): return Valeur("calcul")  # avec une valeur de remplissage
        return CF.arith(op, a, b)
    def __lua_eq__(s, o): return isinstance(o, CF) and all(abs(x - y) < 1e-9 for x, y in zip(s.args, o.args))
def _regarder(pos, cible, haut=None):
    if en_vec3(pos) is None or en_vec3(cible) is None: return Valeur("CFrame", [pos, cible])  # avec une valeur de remplissage
    pos, cible = en_vec3(pos), en_vec3(cible); haut = en_vec3(haut) if haut is not None else Vec3(0, 1, 0)
    devant = Vec3.arith("-", cible, pos).unite()
    if devant.x != devant.x: return CF(pos.t())
    droite = devant.cross(haut)
    if droite.norme() < 1e-9: droite = devant.cross(Vec3(0, 0, 1) if abs(devant.y) > 0.99 else Vec3(0, 1, 0))
    droite = droite.unite(); dessus = droite.cross(devant)
    return CF(pos.t(), ((droite.x, dessus.x, -devant.x), (droite.y, dessus.y, -devant.y), (droite.z, dessus.z, -devant.z)))
def activer_maths(G):
    """Remplace Vector3 et CFrame par des versions calculables (à appeler juste après environnement(), avant de charger le code)."""
    MATHS["actif"] = True
    n = lambda x: float(x) if _num(x) else 0.0
    v = constructeur("Vector3")
    v.h.update({"new": Fonction("Vector3.new", py=lambda x=0, y=0, z=0: Vec3(n(x), n(y), n(z))),
                "zero": Vec3(0, 0, 0), "one": Vec3(1, 1, 1), "xAxis": Vec3(1, 0, 0), "yAxis": Vec3(0, 1, 0), "zAxis": Vec3(0, 0, 1)})
    G["Vector3"] = v
    def nouveau(*a):
        if not a: return CF()
        if any(isinstance(v, Valeur) and en_vec3(v) is None for v in a): return Valeur("CFrame", a)  # avec une valeur de remplissage
        if len(a) == 1: return CF(en_vec3(a[0]).t())
        if len(a) == 2 and en_vec3(a[0]) is not None: return _regarder(a[0], a[1])
        if len(a) == 3: return CF((n(a[0]), n(a[1]), n(a[2])))
        if len(a) == 12: return CF((n(a[0]), n(a[1]), n(a[2])), ((n(a[3]), n(a[4]), n(a[5])), (n(a[6]), n(a[7]), n(a[8])), (n(a[9]), n(a[10]), n(a[11]))))
        raise LuaError("CFrame.new : arguments non gérés par la simulation")
    def axe_angle(axe, angle):
        u = en_vec3(axe).unite(); c, s_ = math.cos(angle), math.sin(angle); x, y, z = u.t(); t = 1 - c
        return CF((0, 0, 0), ((t * x * x + c, t * x * y - s_ * z, t * x * z + s_ * y), (t * x * y + s_ * z, t * y * y + c, t * y * z - s_ * x), (t * x * z - s_ * y, t * y * z + s_ * x, t * z * z + c)))
    c = constructeur("CFrame")
    c.h.update({"new": Fonction("CFrame.new", py=nouveau), "identity": CF(),
                "lookAt": Fonction("CFrame.lookAt", py=lambda p, cible, haut=None: _regarder(p, cible, haut)),
                "Angles": Fonction("CFrame.Angles", py=lambda x=0, y=0, z=0: CF((0, 0, 0), _mat(_mat(_rx(n(x)), _ry(n(y))), _rz(n(z))))),
                "fromEulerAnglesXYZ": Fonction("CFrame.fromEulerAnglesXYZ", py=lambda x=0, y=0, z=0: CF((0, 0, 0), _mat(_mat(_rx(n(x)), _ry(n(y))), _rz(n(z))))),
                "fromEulerAnglesYXZ": Fonction("CFrame.fromEulerAnglesYXZ", py=lambda x=0, y=0, z=0: CF((0, 0, 0), _mat(_mat(_ry(n(y)), _rx(n(x))), _rz(n(z))))),
                "fromOrientation": Fonction("CFrame.fromOrientation", py=lambda x=0, y=0, z=0: CF((0, 0, 0), _mat(_mat(_ry(n(y)), _rx(n(x))), _rz(n(z))))),
                "fromAxisAngle": Fonction("CFrame.fromAxisAngle", py=axe_angle)})
    G["CFrame"] = c
    G["Vector2"].h.update({"zero": Valeur("Vector2", [0, 0]), "one": Valeur("Vector2", [1, 1])})

# Valeurs par défaut de quelques propriétés (V6.9.9), lues par les effets avant d'être écrites
def _defauts(classe):
    v3 = lambda x, y, z: Valeur("Vector3", [x, y, z])
    if classe in ("Part", "MeshPart", "UnionOperation", "WedgePart", "SpawnLocation"):  # V7.1.2 : SpawnLocation aussi
        return {"Transparency": 0, "Size": v3(4, 1, 2), "Color": Couleur(0.64, 0.64, 0.64), "Material": Valeur("Enum.Material.Plastic"),
                "CFrame": Valeur("CFrame"), "Position": v3(0, 0, 0), "Anchored": False, "CanCollide": True, "Reflectance": 0,
                "CanQuery": True, "CanTouch": True, "CastShadow": True, "Massless": False, "Locked": False}  # V6.9.10.5 : lu par la caméra des casiers (rayons) ; V7.1.2 : CanTouch, CastShadow…
    if classe in ("PointLight", "SpotLight", "SurfaceLight"):
        return {"Brightness": 1, "Range": 8, "Color": Couleur(1, 1, 1), "Enabled": True, "Shadows": False}
    if classe == "Workspace": return {"StreamingEnabled": False}  # V6.9.17 : map sans Streaming par défaut
    if classe == "Model": return {"PrimaryPart": None, "ModelStreamingMode": Valeur("Enum.ModelStreamingMode.Default")}  # V6.9.10.1 : comme Roblox, pas de PrimaryPart par défaut ; V6.9.17 : mode de Streaming
    if classe == "ColorCorrectionEffect": return {"Brightness": 0, "Contrast": 0, "Saturation": 0, "TintColor": Couleur(1, 1, 1), "Enabled": True}
    if classe == "BlurEffect": return {"Size": 24, "Enabled": True}
    if classe == "ParticleEmitter": return {"Rate": 5, "Enabled": True}
    if classe in ("Beam", "Trail", "Fire", "Smoke", "Sparkles"): return {"Enabled": True}
    # V6.9.10.6 : objets d'interface, comme dans Roblox (lus par les menus avant d'être écrits : ZIndex, transparences…)
    if classe in INTERFACE:
        d = {"ZIndex": 1, "BackgroundTransparency": 0, "Visible": True, "Rotation": 0, "LayoutOrder": 0}
        if classe in ("TextLabel", "TextButton", "TextBox"): d.update({"Text": "", "TextTransparency": 0})
        if classe in ("ImageLabel", "ImageButton"): d.update({"ImageTransparency": 0, "Image": ""})
        return d
    return {}
LUMIERES = ("PointLight", "SpotLight", "SurfaceLight")
INTERFACE = ("Frame", "TextLabel", "TextButton", "TextBox", "ImageLabel", "ImageButton", "ScrollingFrame", "CanvasGroup", "ViewportFrame")

# ---------------------------------------------------------------- Instances
class Instance:
    def __init__(s, classe, nom=None, parent=None):
        s.ClassName, s.props, s.attrs, s.enfants = classe, {"Name": nom or classe}, {}, []
        s.props.update(_defauts(classe))
        s.emis = 0  # particules émises par :Emit (ParticleEmitter)
        s.signaux_attr, s.parent, s.extra = {}, None, {}
        s.changed = Signal("Changed")
        if parent is not None: s.set_parent(parent)
    def set_parent(s, p):
        if s.parent is not None and s in s.parent.enfants: s.parent.enfants.remove(s)
        s.parent = p
        if p is not None:
            p.enfants.append(s)
            sig = p.extra.get("ChildAdded")
            if sig: sig.declencher(s)
    @property
    def Name(s): return s.props["Name"]
    def signal_attr(s, nom):
        if nom not in s.signaux_attr: s.signaux_attr[nom] = Signal("Attribut " + nom)
        return s.signaux_attr[nom]
    def __lua_index__(s, k):
        if k in s.extra: return s.extra[k]
        if k in s.props: return s.props[k]
        if k == "Parent": return s.parent
        if k == "ClassName": return s.ClassName
        if k == "Archivable": return True  # V7.1.2 : toutes les instances
        if k == "IsPlaying" and s.ClassName == "Sound": return bool(s.props.get("Playing", False))  # V7.1.2
        if k == "PlaybackLoudness" and s.ClassName == "Sound": return 0  # V7.3.2
        if k == "Source" and s.ClassName in ("Script", "LocalScript", "ModuleScript"): return ""
        m = getattr(s, "m_" + k, None)
        if m: return Fonction(k, py=lambda _s, *a: m(*a))
        for e in s.enfants:
            if e.Name == k: return e
        if k in ("Changed",): return s.changed
        if k[0].isupper() and k.endswith(("ed", "Added", "Removing", "Triggered", "Event", "Activated")) or k in ("MouseEnter", "MouseLeave", "InputBegan", "MouseClick") or k in ("Heartbeat", "RenderStepped", "Stepped", "OnServerEvent", "OnClientEvent", "Event", "Triggered", "Touched", "Error", "MessageOut", "Chatted", "PlayerAdded", "PlayerRemoving", "CharacterAdded", "CharacterRemoving", "ChildAdded", "ChildRemoved", "DescendantAdded", "DescendantRemoving", "TouchTap"):
            s.extra[k] = Signal(s.Name + "." + k); return s.extra[k]
        raise LuaError(f"{k} is not a valid member of {s.ClassName} \"{s.Name}\"")
    def __lua_setindex__(s, k, v):
        if k == "Parent": s.set_parent(v); return
        s.props[k] = v
        sig = s.extra.get("prop_" + k)
        if sig: sig.declencher()
    def __lua_tostring__(s): return s.Name
    # Méthodes
    def m_GetAttribute(s, n): return s.attrs.get(n)
    def m_GetAttributes(s): return Table(dict(s.attrs))
    def m_SetAttribute(s, n, v):
        avant = s.attrs.get(n)
        if v is None: s.attrs.pop(n, None)
        else: s.attrs[n] = v
        if avant != v or type(avant) != type(v): s.signal_attr(n).declencher()
        return []
    def m_GetAttributeChangedSignal(s, n): return s.signal_attr(n)
    def m_GetPropertyChangedSignal(s, n):
        if "prop_" + n not in s.extra: s.extra["prop_" + n] = Signal("prop " + n)
        return s.extra["prop_" + n]
    def m_FindFirstChild(s, n, rec=False):
        for e in s.enfants:
            if e.Name == n: return e
        if vrai(rec):
            for e in s.enfants:
                r = e.m_FindFirstChild(n, True)
                if r: return r
        return None
    def m_WaitForChild(s, n, delai=None):
        r = s.m_FindFirstChild(n)
        if r is None and ATTENTE["reelle"] and getattr(Tache.courante, "t", None) is not None:
            # V7.1.2 (banc d'essai) : on attend pour de vrai, dans le temps virtuel, comme Roblox
            debut, prevenu = H.t, False
            cle = f"{s.Name}:WaitForChild(\"{n}\")"; EN_ATTENTE.append(cle)  # attentes encore en cours (bilan du banc)
            try:
                while r is None:
                    if delai is not None and H.t - debut >= float(delai): return None
                    if not prevenu and delai is None and H.t - debut >= 5:  # comme Roblox : seulement sans délai
                        prevenu = True; ATTENTES.append(f"Infinite yield possible on '{s.Name}:WaitForChild(\"{n}\")'")
                    attendre(0.1); r = s.m_FindFirstChild(n)
            finally:
                EN_ATTENTE.remove(cle)
            return r
        if r is None and delai is not None: return None  # V6.9.10.1 : comme Roblox, nil au bout du délai
        if r is None: raise LuaError(f"WaitForChild : « {n} » absent de {s.Name} (simulation)")
        return r
    def m_FindFirstChildOfClass(s, c):
        for e in s.enfants:
            if e.ClassName == c: return e
        return None
    def m_FindFirstChildWhichIsA(s, c, rec=False):
        for e in s.enfants:
            if e.m_IsA(c): return e
        if vrai(rec):
            for e in s.enfants:
                r = e.m_FindFirstChildWhichIsA(c, True)
                if r: return r
        return None
    def m_FindFirstAncestorWhichIsA(s, c):
        p = s.parent
        while p is not None:
            if p.m_IsA(c): return p
            p = p.parent
        return None
    def m_GetChildren(s): return Table({i + 1: e for i, e in enumerate(s.enfants)})
    def m_GetDescendants(s):
        res = []
        def visite(o):
            for e in o.enfants: res.append(e); visite(e)
        visite(s); return Table({i + 1: e for i, e in enumerate(res)})
    def m_IsA(s, c): return s.ClassName == c or (c == "BasePart" and s.ClassName in ("Part", "MeshPart")) or (c == "Light" and s.ClassName in LUMIERES) or (c == "LayerCollector" and s.ClassName in ("ScreenGui", "SurfaceGui", "BillboardGui")) or (c == "PVInstance" and s.ClassName in ("Model", "Part", "MeshPart", "SpawnLocation", "WedgePart", "UnionOperation", "Workspace")) or (c == "BasePart" and s.ClassName == "SpawnLocation") or c == "Instance"
    def m_Destroy(s): s.set_parent(None); return []
    def m_IsDescendantOf(s, o):
        p = s.parent
        while p is not None:
            if p is o: return True
            p = p.parent
        return False
    def m_GetFullName(s):
        noms, p = [], s
        while p is not None and p.ClassName != "DataModel": noms.append(p.Name); p = p.parent
        return ".".join(reversed(noms))
    # Spécifiques
    def m_FireServer(s, *a): s.extra.setdefault("envois", []).append(list(a)); return []
    def m_FireClient(s, joueur, *a): s.extra.setdefault("envoisClient", []).append([joueur] + list(a)); return []
    def m_FireAllClients(s, *a): return []
    def m_Fire(s, *a):
        if "Event" not in s.extra: s.extra["Event"] = Signal(s.Name + ".Event")
        s.extra["Event"].declencher(*a); return []
    def m_Invoke(s, *a):
        f = s.props.get("OnInvoke")
        if f is None: raise LuaError("BindableFunction sans OnInvoke")
        return appeler(f, list(a))
    def m_GetService(s, n):
        r = s.m_FindFirstChild(n)
        if r is None: raise LuaError("service inconnu de la simulation : " + n)
        return r
    def m_GetServerTimeNow(s): return 1000.0 + H.t
    def m_GetPlayers(s): return Table({i + 1: e for i, e in enumerate([x for x in s.enfants if x.ClassName == "Player"])})
    def m_GetPlayerFromCharacter(s, perso):
        for e in s.enfants:
            if e.ClassName == "Player" and perso is not None and e.props.get("Character") is perso: return e
        return None
    def m_GetPlayerByUserId(s, uid):
        for e in s.enfants:
            if e.ClassName == "Player" and e.props.get("UserId") == uid: return e
        return None
    def m_JSONEncode(s, v): return json.dumps(versPython(v), ensure_ascii=False, separators=(",", ":"))
    def m_JSONDecode(s, t):
        try: return depuisPython(json.loads(t))
        except Exception as e: raise LuaError("JSONDecode : " + str(e))
    def m_GenerateGUID(s, *a): return "GUID"
    def m_Create(s, *a): return Instance("Tween")
    def m_Play(s, *a): return []
    def m_Stop(s, *a): return []
    def m_Clone(s):
        c = Instance(s.ClassName, s.Name); c.props = dict(s.props); c.attrs = dict(s.attrs); return c
    def m_ClearAllChildren(s):
        for e in list(s.enfants): e.set_parent(None)
        return []
    def m_Emit(s, n=1): s.emis += int(n or 0); return []
    def m_AddItem(s, objet, delai=10): H.plus_tard(float(delai or 0), lambda: objet.set_parent(None)); return []
    def m_GetExtentsSize(s): return s.props.get("ExtentsSize", Valeur("Vector3", [4, 9, 4]))
    def m_GetDataStore(s, nom): return MAGASINS.setdefault(nom, FauxDataStore(nom))
    def m_BindToClose(s, f): s.extra.setdefault("fermeture", []).append(f); return []
    def m_PreloadAsync(s, *a): return []
    def m_SetCore(s, *a): return []
    def m_GetMouse(s): return Instance("Mouse")
    def m_IsStudio(s): return True
    # (V6.9.10.6) RunService:IsClient() suit le monde (game.extra["serveur"], posé par monde())
    def _cote(s): return s.parent if s.ClassName == "RunService" and s.parent is not None and "serveur" not in s.extra else s
    def m_IsServer(s): return s._cote().extra.get("serveur", True)
    def m_IsClient(s): return not s._cote().extra.get("serveur", True)
    def m_BindToRenderStep(s, nom, priorite=None, f=None, *a): s.extra.setdefault("rendu", {})[nom] = f; return []
    def m_UnbindFromRenderStep(s, nom, *a): s.extra.setdefault("rendu", {}).pop(nom, None); return []
    # V7.4.2 : ContextActionService (actions liées à des touches, rangées dans extra["actions"][nom] = (fonction, touches))
    def m_BindActionAtPriority(s, nom, f, tactile=False, priorite=None, *touches): s.extra.setdefault("actions", {})[nom] = (f, list(touches)); return []
    def m_BindAction(s, nom, f, tactile=False, *touches): s.extra.setdefault("actions", {})[nom] = (f, list(touches)); return []
    def m_UnbindAction(s, nom): s.extra.setdefault("actions", {}).pop(nom, None); return []
    def m_SetTitle(s, nom, titre): s.extra.setdefault("titres", {})[nom] = titre; return []
    def m_ScreenPointToRay(s, x, y, profondeur=0):  # V7.4.2 : Camera (rayon unitaire depuis la caméra, champ vertical FieldOfView)
        return Table({"Origin": Vec3(*s.props["CFrame"].p) if isinstance(s.props.get("CFrame"), CF) else Vec3(0, 0, 0), "Direction": s._direction_ecran(x, y)})
    def _direction_ecran(s, x, y):
        cf = s.props.get("CFrame"); taille = s.props.get("ViewportSize")
        if not isinstance(cf, CF): return Vec3(0, 0, -1)
        l, h = (taille.args[0], taille.args[1]) if isinstance(taille, Valeur) and len(taille.args) >= 2 else (1280, 720)
        t = math.tan(math.radians(float(s.props.get("FieldOfView", 70))) / 2)
        dx, dy = (2 * float(x) / l - 1) * t * l / h, (1 - 2 * float(y) / h) * t
        d = Vec3.arith("+", Vec3.arith("+", Vec3.arith("*", cf.col(0), dx), Vec3.arith("*", cf.col(1), dy)), cf.__lua_index__("LookVector"))
        return d.unite()
    def m_GetRankInGroup(s, g): return 0
    def m_ReleaseFocus(s, *a): s.extra["focus"] = False; return []  # (V6.9.10.6) TextBox
    def m_CaptureFocus(s, *a): s.extra["focus"] = True; return []
    def m_PivotTo(s, cf): s.props["Pivot"] = cf; return []
    def m_GetScale(s): return s.props.get("Scale", 1)
    def m_GetSunDirection(s):  # V7.2.1 : Lighting:GetSunDirection() (le soleil tourne avec ClockTime, levé à 6 h)
        a = (float(s.props.get("ClockTime", 14) or 14) - 6) / 12 * math.pi
        return Vec3(math.cos(a), math.sin(a), 0.3)
    def m_ScaleTo(s, e): s.props["Scale"] = e; return []
    def _parts(s):  # V7.1.2 : les pièces placées (CFrame et taille calculables) du Model
        r = []
        for e in s.enfants:
            if e.m_IsA("BasePart") and isinstance(e.props.get("CFrame"), CF) and isinstance(e.props.get("Size"), Vec3): r.append(e)
            r.extend(e._parts())
        return r
    def _boite(s):
        ps = s._parts()
        if not ps: return None
        bas = [min(p.props["CFrame"].p[i] - p.props["Size"].t()[i] / 2 for p in ps) for i in range(3)]
        haut = [max(p.props["CFrame"].p[i] + p.props["Size"].t()[i] / 2 for p in ps) for i in range(3)]
        return CF(tuple((a + b) / 2 for a, b in zip(bas, haut))), Vec3(*(b - a for a, b in zip(bas, haut)))
    def m_GetPivot(s):
        if "Pivot" in s.props or not MATHS.get("actif"): return s.props.get("Pivot", Valeur("CFrame"))
        # V7.1.2 (maths actives) : comme Roblox, le pivot de la PrimaryPart, sinon le centre de la boîte des pièces
        pp = s.props.get("PrimaryPart")
        if isinstance(pp, Instance) and isinstance(pp.props.get("CFrame"), CF): return pp.props["CFrame"]
        b = s._boite(); return b[0] if b else CF()
    def m_GetBoundingBox(s):
        if "BoiteCFrame" not in s.props and MATHS.get("actif"):
            b = s._boite()  # V7.1.2 : la vraie boîte des pièces (alignée sur les axes)
            if b: return [b[0], b[1]]
        return [s.props.get("BoiteCFrame", Valeur("CFrame")), s.props.get("BoiteTaille", Valeur("Vector3", [10, 10, 10]))]  # V6.9.10.3 : boîte réglable

def versPython(v):
    if isinstance(v, Table):
        n = v.longueur()
        if n > 0 and n == len(v.h): return [versPython(v.h[i]) for i in range(1, n + 1)]
        if len(v.h) == 0: return []
        return {str(k) if not isinstance(k, str) else k: versPython(x) for k, x in v.h.items()}
    if isinstance(v, float) and v.is_integer(): return int(v)
    if isinstance(v, (str, int, float, bool)) or v is None: return v
    raise LuaError("JSONEncode : type non sérialisable " + type_lua(v))
def depuisPython(v):
    if isinstance(v, list): return Table({i + 1: depuisPython(x) for i, x in enumerate(v)})
    if isinstance(v, dict): return Table({k: depuisPython(x) for k, x in v.items()})
    return v

# ---------------------------------------------------------------- Faux DataStore (avec pannes programmables)
MAGASINS = {}
class FauxDataStore:
    def __init__(s, nom): s.nom, s.donnees, s.pannes_lecture, s.pannes_ecriture, s.lectures, s.ecritures = nom, {}, 0, 0, 0, 0
    def __lua_index__(s, k):
        if k == "GetAsync": return Fonction("GetAsync", py=lambda _s, c: s.lire(c))
        if k == "SetAsync": return Fonction("SetAsync", py=lambda _s, c, v: s.ecrire(c, v))
        if k == "UpdateAsync": return Fonction("UpdateAsync", py=lambda _s, c, f: s.ecrire(c, premier(appeler(f, [s.donnees.get(c)]))))
        raise LuaError("DataStore." + k)
    def lire(s, c):
        s.lectures += 1
        if s.pannes_lecture > 0: s.pannes_lecture -= 1; raise LuaError("502: API Services rejected request (panne simulée)")
        v = s.donnees.get(c); return depuisPython(json.loads(json.dumps(versPython(v)))) if isinstance(v, Table) else v
    def ecrire(s, c, v):
        s.ecritures += 1
        if s.pannes_ecriture > 0: s.pannes_ecriture -= 1; raise LuaError("502: écriture refusée (panne simulée)")
        s.donnees[c] = v; return []

# ---------------------------------------------------------------- Environnement global
def environnement(I, serveur=True):
    G = I.G
    G["string"] = bib_string(I); G["table"] = bib_table()
    m = Table()
    for nom in ("floor", "ceil", "sqrt", "sin", "cos", "tan", "asin", "acos", "exp", "log10"):
        m.h[nom] = Fonction("math." + nom, py=(lambda f: lambda x: f(x))(getattr(math, nom)))
    m.h.update({"abs": Fonction("abs", py=abs), "huge": math.inf, "pi": math.pi,
                "max": Fonction("max", py=lambda *a: max(a)), "min": Fonction("min", py=lambda *a: min(a)),
                "clamp": Fonction("clamp", py=lambda x, a, b: max(a, min(b, x))), "sign": Fonction("sign", py=lambda x: (x > 0) - (x < 0)),
                "random": Fonction("random", py=lambda a=None, b=None: __import__("random").random() if a is None else (__import__("random").randint(1, int(a)) if b is None else __import__("random").randint(int(a), int(b)))),
                "noise": Fonction("noise", py=lambda *a: math.sin(sum(a) * 12.9898) * 0.5), "round": Fonction("round", py=lambda x: math.floor(x + 0.5)),
                "log": Fonction("log", py=lambda x, b=None: math.log(x) if b is None else math.log(x, b)), "atan2": Fonction("atan2", py=math.atan2),
                "atan": Fonction("atan", py=lambda y, x=None: math.atan(y) if x is None else math.atan2(y, x)),
                "fmod": Fonction("fmod", py=math.fmod), "rad": Fonction("rad", py=math.radians), "deg": Fonction("deg", py=math.degrees), "lerp": Fonction("lerp", py=lambda a, b, t: a + (b - a) * t),
                "modf": Fonction("modf", py=lambda x: [float(int(x)), x - int(x)]), "pow": Fonction("pow", py=pow)})
    G["math"] = m
    o = Table({"clock": Fonction("clock", py=lambda: H.t), "time": Fonction("time", py=lambda t=None: 1_800_000_000 + int(H.t)),
               "date": Fonction("date", py=lambda f="%c", t=None: __import__("time").strftime(f.lstrip("!"), __import__("time").gmtime(t if t is not None else 1_800_000_000 + int(H.t))))})
    G["os"] = o
    G["utf8"] = Table({"len": Fonction("utf8.len", py=lambda s, *a: len(s)), "offset": Fonction("utf8.offset", py=lambda s, n, i=1: len(s[:int(n) - 1].encode()) + 1),
                       "char": Fonction("utf8.char", py=lambda *c: "".join(chr(int(x)) for x in c))})
    def _pairs(t):
        cles = list(t.h.keys()); it = iter(cles)
        def suivant(*_):
            for k in it:
                if k in t.h: return [k, t.h[k]]
            return [None]
        return [Fonction("next", py=suivant), t, None]
    def _ipairs(t):
        def suivant(_t, i):
            i = int(i) + 1; v = t.get(i); return [None] if v is None else [i, v]
        return [Fonction("inext", py=suivant), t, 0]
    def _pcall(f, *a):
        try: return [True] + appeler(f, list(a))
        except LuaError as e: return [False, e.valeur]
        except RecursionError: return [False, "stack overflow"]
    def _error(v=None, niveau=1): raise LuaError(v)
    def _select(n, *a):
        if n == "#": return len(a)
        n = int(n); return list(a[n - 1:]) if n > 0 else list(a[n:])
    def _setmt(t, mt): t.mt = mt; return t
    def _tonumber(v, base=None):
        if isinstance(v, (int, float)) and not isinstance(v, bool): return v
        if isinstance(v, str):
            try: return int(v, base or 10) if base or re.fullmatch(r"\s*-?\d+\s*", v) else float(v)
            except ValueError: return None
        return None
    def _typeof(v):
        if isinstance(v, Instance): return "Instance"
        if isinstance(v, Valeur): return v.nom.split(".")[0] if "." in v.nom else v.nom  # Vec3 → "Vector3", CF → "CFrame"
        if isinstance(v, (Signal,)): return "RBXScriptSignal"
        return type_lua(v)
    def _assert(v, msg="assertion failed!", *r):
        if not vrai(v): raise LuaError(msg)
        return [v, msg] + list(r)
    for nom, f in dict(print=lambda *a: SORTIE.append(" ".join(tostring(x) for x in a)) or [], warn=lambda *a: SORTIE.append("⚠ " + " ".join(tostring(x) for x in a)) or [],
                      pairs=_pairs, ipairs=_ipairs, pcall=_pcall, error=_error, select=_select, setmetatable=_setmt, getmetatable=lambda t: t.mt if isinstance(t, Table) else None,
                      tostring=tostring, tonumber=_tonumber, type=type_lua, typeof=_typeof, rawget=lambda t, k: t.h.get(cle(k)), rawset=lambda t, k, v: t.set(k, v) or t,
                      rawequal=lambda a, b: a is b, unpack=lambda t, i=1, j=None: [t.h.get(k) for k in range(int(i), int(j or t.longueur()) + 1)],
                      next=lambda t, k=None: (lambda cs: ([cs[0], t.h[cs[0]]] if cs else [None]) if k is None else ([cs[cs.index(cle(k)) + 1], t.h[cs[cs.index(cle(k)) + 1]]] if cs.index(cle(k)) + 1 < len(cs) else [None]))(list(t.h.keys())),
                      xpcall=lambda f, h, *a: _pcall(f, *a) if _pcall(f, *a)[0] else [False] + appeler(h, [_pcall(f, *a)[1]])).items():
        G[nom] = Fonction(nom, py=f)
    G["assert"] = Fonction("assert", py=_assert)
    G["task"] = Table({"wait": Fonction("task.wait", py=lambda d=0: attendre(d)),
                       "spawn": Fonction("task.spawn", py=lambda f, *a: [lancer(f, *a, nom="task.spawn")] and []),
                       "defer": Fonction("task.defer", py=lambda f, *a: H.plus_tard(0, lambda: lancer(f, *a, nom="task.defer")) or []),
                       "delay": Fonction("task.delay", py=lambda d, f, *a: H.plus_tard(d or 0, lambda: lancer(f, *a, nom="task.delay")) or []),
                       "cancel": Fonction("task.cancel", py=lambda t: [])})
    G["wait"] = G["task"].h["wait"]
    for nom in ("Vector3", "Vector2", "CFrame", "UDim", "UDim2", "ColorSequence", "ColorSequenceKeypoint", "NumberSequence", "NumberSequenceKeypoint",
                "NumberRange", "BrickColor", "TweenInfo", "RaycastParams", "OverlapParams", "Rect", "Region3", "PhysicalProperties", "Random", "DateTime", "Font", "Ray", "Axes", "Faces"):
        G[nom] = constructeur(nom)
    G["Color3"] = constructeur_couleur()
    G["Vector3"].h.update({"zero": Valeur("Vector3", [0, 0, 0]), "one": Valeur("Vector3", [1, 1, 1]), "yAxis": Valeur("Vector3", [0, 1, 0]), "xAxis": Valeur("Vector3", [1, 0, 0])})
    G["Enum"] = Valeur("Enum")
    G["Instance"] = Table({"new": Fonction("Instance.new", py=lambda c, p=None: Instance(c, None, p))})
    G["_G"] = Table(); G["shared"] = Table()
    return G
SORTIE = []

def propre_script(I, src, script_obj):
    """V7.1.2 : chaque script (ou module) a sa propre variable `script`, même après une attente
    (sinon un autre script lancé entre-temps la remplace). Même ligne : les numéros de ligne ne bougent pas."""
    cle = "__script_%d" % id(script_obj); I.G[cle] = script_obj
    return "local script = " + cle + "; " + src

def charger_module(I, chemin, script_obj, cache={}):
    if chemin in cache: return cache[chemin]
    src = propre_script(I, open(chemin, encoding="utf-8").read(), script_obj)  # V7.1.2 : `script` propre au module
    ancien = I.G.get("script"); I.G["script"] = script_obj
    try:
        r = I.executer(src, os.path.basename(chemin))
    finally:
        I.G["script"] = ancien
    cache[chemin] = premier(r)
    return cache[chemin]
