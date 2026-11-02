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
    for nom, f in dict(sub=sub, find=find, match=match, gmatch=gmatch, gsub=gsub, format=fmt, rep=rep, split=split,
                      lower=lambda s: s.lower(), upper=lambda s: s.upper(), len=lambda s: len(s.encode()), reverse=lambda s: s[::-1],
                      byte=lambda s, i=1, j=None: [ord(c) for c in s[int(i) - 1:int(j if j else i)]], char=lambda *c: "".join(chr(int(x)) for x in c)).items():
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
threading.stack_size(256 * 1024 * 1024)
ERREURS = []   # erreurs levées dans les tâches (comme la sortie rouge de Roblox)
class Tache:
    courante = threading.local()
    def __init__(s, f, args, nom="tâche"):
        s.f, s.args, s.nom = f, list(args), nom
        s.ev, s.rendu, s.fini, s.demarree = threading.Event(), threading.Event(), False, False
    def _corps(s):
        s.ev.wait(); s.ev.clear()
        Tache.courante.t = s
        try:
            appeler(s.f, s.args)
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
        if k in ("X", "Y", "Z", "R", "G", "B", "Magnitude", "Scale", "Offset", "Min", "Max", "Value", "Time"):
            return float(s.args[{"X": 0, "R": 0, "Y": 1, "G": 1, "Z": 2, "B": 2}.get(k, 0)]) if s.args and isinstance(s.args[0], (int, float)) and len(s.args) > {"X": 0, "R": 0, "Y": 1, "G": 1, "Z": 2, "B": 2}.get(k, 0) else 0.0
        if k == "Name": return s.nom.split(".")[-1]
        return Valeur(s.nom + "." + str(k))
    def __lua_call__(s, args): return [Valeur(s.nom + "()", args[1:] if args and args[0] is s else args)]
    def __lua_arith__(s, op, a, b): return Valeur("calcul")
    def __lua_unm__(s): return Valeur("calcul")
    def __lua_eq__(s, o): return s is o or (isinstance(o, Valeur) and o.nom == s.nom and o.args == s.args)
    def __lua_tostring__(s): return s.nom
    def __lua_setindex__(s, k, v): pass
def constructeur(nom):
    t = Table()
    t.mt = Table({"__index": Fonction(nom, py=lambda _t, k: Fonction(nom + "." + k, py=lambda *a: Valeur(nom, a)))})
    return t

# ---------------------------------------------------------------- Instances
class Instance:
    def __init__(s, classe, nom=None, parent=None):
        s.ClassName, s.props, s.attrs, s.enfants = classe, {"Name": nom or classe}, {}, []
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
        m = getattr(s, "m_" + k, None)
        if m: return Fonction(k, py=lambda _s, *a: m(*a))
        for e in s.enfants:
            if e.Name == k: return e
        if k in ("Changed",): return s.changed
        if k[0].isupper() and k.endswith(("ed", "Added", "Removing", "Triggered", "Event", "Activated")) or k in ("Heartbeat", "RenderStepped", "Stepped", "OnServerEvent", "OnClientEvent", "Event", "Triggered", "Touched", "Error", "MessageOut", "Chatted", "PlayerAdded", "PlayerRemoving", "CharacterAdded", "CharacterRemoving", "ChildAdded", "ChildRemoved", "DescendantAdded", "DescendantRemoving"):
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
        if r is None: raise LuaError(f"WaitForChild : « {n} » absent de {s.Name} (simulation)")
        return r
    def m_FindFirstChildOfClass(s, c):
        for e in s.enfants:
            if e.ClassName == c: return e
        return None
    def m_FindFirstChildWhichIsA(s, c, rec=False): return s.m_FindFirstChildOfClass(c)
    def m_FindFirstAncestorWhichIsA(s, c): return None
    def m_GetChildren(s): return Table({i + 1: e for i, e in enumerate(s.enfants)})
    def m_GetDescendants(s):
        res = []
        def visite(o):
            for e in o.enfants: res.append(e); visite(e)
        visite(s); return Table({i + 1: e for i, e in enumerate(res)})
    def m_IsA(s, c): return s.ClassName == c or (c == "BasePart" and s.ClassName in ("Part", "MeshPart")) or c == "Instance"
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
    def m_GetDataStore(s, nom): return MAGASINS.setdefault(nom, FauxDataStore(nom))
    def m_BindToClose(s, f): s.extra.setdefault("fermeture", []).append(f); return []
    def m_PreloadAsync(s, *a): return []
    def m_SetCore(s, *a): return []
    def m_GetMouse(s): return Instance("Mouse")
    def m_IsStudio(s): return True
    def m_IsServer(s): return s.extra.get("serveur", True)
    def m_IsClient(s): return not s.extra.get("serveur", True)
    def m_BindToRenderStep(s, *a): return []
    def m_UnbindFromRenderStep(s, *a): return []
    def m_GetRankInGroup(s, g): return 0
    def m_PivotTo(s, cf): s.props["Pivot"] = cf; return []
    def m_GetPivot(s): return s.props.get("Pivot", Valeur("CFrame"))
    def m_GetBoundingBox(s): return [Valeur("CFrame"), Valeur("Vector3", [10, 10, 10])]

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
                "fmod": Fonction("fmod", py=math.fmod), "lerp": Fonction("lerp", py=lambda a, b, t: a + (b - a) * t),
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
        if isinstance(v, Valeur): return v.nom.split(".")[0] if "." in v.nom else v.nom
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
    for nom in ("Vector3", "Vector2", "Color3", "CFrame", "UDim", "UDim2", "ColorSequence", "ColorSequenceKeypoint", "NumberSequence", "NumberSequenceKeypoint",
                "NumberRange", "BrickColor", "TweenInfo", "RaycastParams", "OverlapParams", "Rect", "Region3", "PhysicalProperties", "Random", "DateTime", "Font", "Ray", "Axes", "Faces"):
        G[nom] = constructeur(nom)
    G["Vector3"].h.update({"zero": Valeur("Vector3", [0, 0, 0]), "one": Valeur("Vector3", [1, 1, 1]), "yAxis": Valeur("Vector3", [0, 1, 0]), "xAxis": Valeur("Vector3", [1, 0, 0])})
    G["Enum"] = Valeur("Enum")
    G["Instance"] = Table({"new": Fonction("Instance.new", py=lambda c, p=None: Instance(c, None, p))})
    G["_G"] = Table(); G["shared"] = Table()
    return G
SORTIE = []

def charger_module(I, chemin, script_obj, cache={}):
    if chemin in cache: return cache[chemin]
    src = open(chemin, encoding="utf-8").read()
    ancien = I.G.get("script"); I.G["script"] = script_obj
    try:
        r = I.executer(src, os.path.basename(chemin))
    finally:
        I.G["script"] = ancien
    cache[chemin] = premier(r)
    return cache[chemin]
