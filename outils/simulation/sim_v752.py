"""Simulations de la V7.5.2 (régénération : le corps change) : le vrai code, exécuté avec de faux objets Roblox et des
maths réelles (Vector3 et CFrame calculables, roblox.activer_maths).
  1. TardisConfig : réglages Config.Regeneration.Corps et calculs purs (fluxBras, battementCoeur, couleursCorps,
     proprieteBodyColors, estCheveux, fonduApparition, debitFumeeApres).
  2. Regeneration (le vrai code de copieAccessoire, brulerAccessoire, apparitionsAccessoires, extrait du module) :
     les anciens accessoires brûlent (G-209), les nouveaux apparaissent un par un (G-210).
  3. Sources : fils d'or dans les bras (G-206), cœur (G-207), peau (G-208, serveur), cheveux qui fument (G-213),
     membre qui repousse en or (G-215, serveur)."""
import os, sys, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from monde import *
import roblox
from roblox import Couleur, Vec3, CF, activer_maths
OK, KO = [], []
def verifier(nom, condition, detail=""):
    (OK if condition else KO).append(nom + ("" if condition else "  →  " + str(detail)))
def tache(f): lancer(Fonction("t", py=f))
def lire(chemin): return open(os.path.join(DEPOT, chemin), encoding="utf-8").read()
def vider_cache(): roblox.charger_module.__defaults__[0].clear()
def proche(a, b, e=1e-6): return a is not None and b is not None and abs(float(a) - float(b)) <= e
def vec(v): return tuple(float(v.__lua_index__(k)) for k in "XYZ")

# Clone profond et familles de classes utiles ici (les autres simulations n'en ont pas besoin)
_isa = roblox.Instance.m_IsA
def isa(s, c):
    if c == "JointInstance" and s.ClassName in ("Weld", "Motor6D", "ManualWeld"): return True
    if c == "BaseScript" and s.ClassName in ("Script", "LocalScript"): return True
    return _isa(s, c)
roblox.Instance.m_IsA = isa
def clone(s):
    c = roblox.Instance(s.ClassName, s.Name); c.props = dict(s.props); c.attrs = dict(s.attrs)
    for e in list(s.enfants): clone(e).set_parent(c)
    return c
roblox.Instance.m_Clone = clone

# ================================================================== 1. TardisConfig
vider_cache()
I, G, game, joueur = monde(serveur=False)
activer_maths(G)
rs = game.m_FindFirstChild("ReplicatedStorage")
R = {}
tache(lambda: R.update(Config=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisConfig")]))))
Config = R["Config"]
f = lambda nom, *a: premier(appeler(Config.get(nom), list(a)))
verifier("Config.Version ≥ 7.5.2 (7.5.2 à sa sortie)", tuple(int(n) for n in Config.get("Version").split(".")) >= (7, 5, 2), Config.get("Version"))
C = Config.get("Regeneration").get("Corps")
verifier("Config.Regeneration.Corps : fils d'or, battement (1,1 → 3,2 par seconde)",
         C and (C.get("FluxBras"), C.get("Battement"), C.get("BattementDebut"), C.get("BattementFin")) == (True, True, 1.1, 3.2))
verifier("Config.Regeneration.Corps : teinte avant l'éclat (40 %, sur 12 %), cendres (8 au plus, 1,4 s)",
         (C.get("TeinteAvant"), C.get("DebutTeinte"), C.get("DureeTeinte"), C.get("Cendres"), C.get("CendresMax"), C.get("DureeCendres")) == (True, 0.4, 0.12, True, 8, 1.4))
verifier("Config.Regeneration.Corps : apparition (toutes les 0,25 s, en 0,5 s), cheveux, membre doré (1 s)",
         (C.get("Apparition"), C.get("IntervalleApparition"), C.get("DureeApparition"), C.get("FumeeCheveux"), C.get("RepousseDoree"), C.get("DureeRepousseDoree")) == (True, 0.25, 0.5, True, True, 1))
verifier("La teinte finit pile à l'éclat (0,4 + 0,12 = 0,52)", proche(C.get("DebutTeinte") + C.get("DureeTeinte"), 0.52))

# fluxBras
fb = [f("fluxBras", p) for p in (0, 0.05, 0.1, 0.25, 0.4, 0.46, 0.52, 0.8)]
verifier("G-206 : fluxBras monte tout de suite (0 → 0,5 → 1 sur 10 %)", proche(fb[0], 0) and proche(fb[1], 0.5) and proche(fb[2], 1), fb)
verifier("G-206 : fluxBras tient pendant la montée puis s'efface avant l'éclat (1 ; 0,5 à 46 % ; 0 à 52 %)",
         proche(fb[3], 1) and proche(fb[4], 1) and proche(fb[5], 0.5) and proche(fb[6], 0) and proche(fb[7], 0), fb)
verifier("G-206 : fluxBras sans valeur → 0", proche(f("fluxBras", None), 0))

# battementCoeur
duree = 8
pas = [k * 0.005 for k in range(int(0.52 * duree / 0.005))]
vals = [f("battementCoeur", t, duree, 1.1, 3.2) for t in pas]
verifier("G-207 : battementCoeur reste entre 0 et 1", all(0 <= v <= 1 for v in vals), (min(vals), max(vals)))
def coups(debut, fin):
    n, haut = 0, False
    for t, v in zip(pas, vals):
        if debut <= t < fin:
            if v > 0.9 and not haut: n += 1
            haut = v > 0.9
    return n
q = 0.52 * duree / 4
c1, c4 = coups(0, q), coups(3 * q, 4 * q)
verifier("G-207 : le cœur bat de plus en plus vite (plus de coups forts dans le dernier quart que dans le premier)", c4 > c1 and c1 >= 1, (c1, c4))
verifier("G-207 : deux coups par battement (le second, plus faible, monte à 0,6)", any(0.55 < v < 0.65 for v in vals) and max(vals) > 0.99)
verifier("G-207 : après l'éclat (52 %), la lueur ne bat plus (1)", proche(f("battementCoeur", 0.52 * duree, duree, 1.1, 3.2), 1) and proche(f("battementCoeur", 7, duree), 1))
verifier("G-207 : au tout début, la lueur est entre deux coups (faible)", f("battementCoeur", 0, duree, 1.1, 3.2) < 0.3, f("battementCoeur", 0, duree, 1.1, 3.2))

# couleursCorps, proprieteBodyColors
R2 = {}
tache(lambda: R2.update(r=premier(I.executer("""local Config = ...
local d = { HeadColor = Color3.fromRGB(10, 20, 30), TorsoColor = Color3.fromRGB(1, 2, 3), LeftArmColor = Color3.fromRGB(4, 5, 6),
  RightArmColor = Color3.fromRGB(7, 8, 9), LeftLegColor = Color3.fromRGB(11, 12, 13), RightLegColor = Color3.fromRGB(14, 15, 16) }
local c = Config.couleursCorps(d)
local n = 0 for _ in c do n += 1 end
return { n = n, tete = c.HeadColor3 == d.HeadColor, jambe = c.RightLegColor3 == d.RightLegColor, rien = Config.couleursCorps({}) == nil,
  partiel = Config.couleursCorps({ HeadColor = Color3.new(1, 0, 0) }).HeadColor3 ~= nil }
""", "couleurs", (Config,)))))
r = R2.get("r")
verifier("G-208 : couleursCorps lit les 6 couleurs de la description (HeadColor → HeadColor3…)", r and r.get("n") == 6 and r.get("tete") and r.get("jambe"), r and r.h)
verifier("G-208 : couleursCorps sans couleur → nil (rien à teinter) ; une seule couleur suffit", r and r.get("rien") and r.get("partiel"))
pb = {m: f("proprieteBodyColors", m) for m in ("Right Arm", "Left Leg", "Head", "Torso", "LeftHand", "RightLowerLeg", "UpperTorso", "Handle")}
verifier("G-215 : proprieteBodyColors pour R6 (Right Arm, Left Leg, Head, Torso)",
         (pb["Right Arm"], pb["Left Leg"], pb["Head"], pb["Torso"]) == ("RightArmColor3", "LeftLegColor3", "HeadColor3", "TorsoColor3"), pb)
verifier("G-215 : proprieteBodyColors pour R15 (LeftHand, RightLowerLeg, UpperTorso) ; rien pour une autre pièce",
         (pb["LeftHand"], pb["RightLowerLeg"], pb["UpperTorso"], pb["Handle"]) == ("LeftArmColor3", "RightLegColor3", "TorsoColor3", None), pb)

# estCheveux, fonduApparition, debitFumeeApres
verifier("G-213 : estCheveux : type Hair, ou un nom avec « hair » / « cheveu » ; pas un chapeau",
         f("estCheveux", "Accessoire", "Hair") is True and f("estCheveux", "PonytailHair", None) is True and f("estCheveux", "Cheveux bouclés", "Unknown") is True
         and f("estCheveux", "Chapeau", "Hat") is False and f("estCheveux", None, None) is False)
verifier("G-210 : fonduApparition : invisible avant son tour, à moitié au milieu, visible ensuite",
         proche(f("fonduApparition", 0.5, 1, 0.5), 1) and proche(f("fonduApparition", 1, 1, 0.5), 1) and proche(f("fonduApparition", 1.25, 1, 0.5), 0.5) and proche(f("fonduApparition", 2, 1, 0.5), 0))
verifier("G-213 : debitFumeeApres : 14 à la fin, 7 au bout de 7 s, 0 au bout de 14 s (et après)",
         proche(f("debitFumeeApres", 0), 14) and proche(f("debitFumeeApres", 7), 7) and proche(f("debitFumeeApres", 14), 0) and proche(f("debitFumeeApres", 20), 0))

# ================================================================== 2. Le vrai code (accessoires)
ws = game.m_FindFirstChild("Workspace")
debris = game.m_FindFirstChild("Debris") or Instance("Debris", "Debris", game)
tache(lambda: R.update(UI=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisUI")]))))
creer_vrai = R["UI"].get("creer")
ANIM = []
def animer_instant(obj, duree, props, *a):
    ANIM.append((obj, duree))
    for k, v in props.h.items(): obj.props[k] = v
    return []
src = lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Regeneration.lua")
d_c = src.index("local CORPS = "); f_c = src.index("local function surveillerRegeneration")
code = ("local Config, creer, animer, Debris, workspace = ...\n"
        'local FUMEE = "rbxasset://textures/particles/smoke_main.dds"\n'
        'local ETINCELLE = "rbxasset://textures/particles/sparkles_main.dds"\n' + src[d_c:f_c] +
        "\nreturn { copie = copieAccessoire, bruler = brulerAccessoire, apparitions = apparitionsAccessoires }\n")
tache(lambda: R.update(M=premier(I.executer(code, "regeneration_corps",
      (Config, creer_vrai, Fonction("animer", py=animer_instant), debris, ws)))))
M = R["M"]
verifier("Vrai code de Regeneration extrait (copieAccessoire, brulerAccessoire, apparitionsAccessoires), sans erreur", M is not None and not roblox.ERREURS, roblox.ERREURS[:3])

perso = Instance("Model", "Voyageur", ws)
def accessoire(nom, y, avec_poignee=True):
    a = Instance("Accessory", nom, perso)
    if avec_poignee:
        h = Instance("MeshPart", "Handle", a); h.props.update({"CFrame": CF((1, y, 0)), "Size": Vec3(2, 1, 2), "Anchored": False, "CanCollide": True, "Transparency": 0})
        Instance("Weld", "AccessoryWeld", h); Instance("Attachment", "HatAttachment", h); Instance("SpecialMesh", "Mesh", h); Instance("Script", "Vieux", h)
    return a
chapeau = accessoire("Chapeau", 6)
R3 = {}
tache(lambda: R3.update(c=premier(appeler(M.get("copie"), [chapeau]))))
c = R3["c"]
cp = c and c.get("copie")
verifier("G-209 : copieAccessoire copie la pièce (TardisRegenCendre), ancrée, sans collision ni requête, sans masse",
         cp is not None and cp.Name == "TardisRegenCendre" and (cp.props.get("Anchored"), cp.props.get("CanCollide"), cp.props.get("CanQuery"), cp.props.get("CanTouch"), cp.props.get("Massless")) == (True, False, False, False, True))
verifier("G-209 : … sans soudure, attache ni script (le maillage reste) ; l'accessoire d'origine est intact",
         cp is not None and [e.ClassName for e in cp.enfants] == ["SpecialMesh"] and len(chapeau.m_FindFirstChild("Handle").enfants) == 4, cp and [e.ClassName for e in cp.enfants])
verifier("G-209 : … pas encore dans le monde, avec la position de la poignée", cp is not None and cp.parent is None and tuple(c.get("cf").p) == (1, 6, 0))
sans = accessoire("Vide", 6, avec_poignee=False)
tache(lambda: R3.update(v=premier(appeler(M.get("copie"), [sans]))))
verifier("G-209 : un accessoire sans poignée ne se copie pas (nil)", R3.get("v") is None)

c.set("cf", CF((1, 7, 0)))
tache(lambda: R3.update(b=premier(appeler(M.get("bruler"), [c, 0, False]))))
b = R3["b"]
hl = b.m_FindFirstChild("Braise"); cendres = b.m_FindFirstChild("Cendres")
verifier("G-209 : brulerAccessoire pose la copie dans le monde, là où était l'accessoire au moment du retrait",
         b is cp and b.parent is ws)
verifier("G-209 : … elle rougeoie (Highlight rouge) et part en cendres (20 particules)",
         hl is not None and hl.ClassName == "Highlight" and hl.props.get("FillColor").rgb255() == (255, 70, 20) and cendres is not None and cendres.emis == 20)
pos = vec(b.props["CFrame"].__lua_index__("Position"))
verifier("G-209 : … elle tombe jusqu'au sol (0,2 au-dessus), devient transparente et rapetisse (40 %)",
         proche(pos[1], 0.2, 1e-6) and proche(pos[0], 1, 1e-6) and b.props.get("Transparency") == 1 and proche(vec(b.props["Size"])[0], 0.8), (pos, b.props.get("Size")))
verifier("G-209 : … en 1,4 s (Config.Regeneration.Corps.DureeCendres)", ANIM and ANIM[-1][0] is b and proche(ANIM[-1][1], 1.4))
H.avancer(2.1)
verifier("G-209 : … puis la copie disparaît (Debris, 2 s)", b.parent is None)
tache(lambda: R3.update(c2=premier(appeler(M.get("copie"), [chapeau]))))
tache(lambda: R3.update(b2=premier(appeler(M.get("bruler"), [R3["c2"], None, True]))))
b2 = R3["b2"]
verifier("G-209 : réduire les effets : pas de cendres (la braise reste) ; sans sol, la chute est de 3 studs",
         b2.m_FindFirstChild("Cendres") is None and b2.m_FindFirstChild("Braise") is not None and proche(vec(b2.props["CFrame"].__lua_index__("Position"))[1], 6 - 2.8, 1e-6),
         vec(b2.props["CFrame"].__lua_index__("Position")))

# Apparitions
tache(lambda: R3.update(s=premier(appeler(M.get("apparitions"), [False]))))
suivi = R3["s"]
n1, n2, n3 = accessoire("Lunettes", 5), accessoire("Cheveux", 6), accessoire("Cape", 3)
h1, h2, h3 = (a.m_FindFirstChild("Handle") for a in (n1, n2, n3))
def aj(a, t): tache(lambda: appeler(suivi.get("ajouter"), [a, t]))
def maj(t): tache(lambda: appeler(suivi.get("maj"), [t]))
def attente(): return premier(appeler(suivi.get("enAttente"), []))
aj(n1, 1.0); aj(n2, 1.0); aj(sans, 1.0)
verifier("G-210 : un nouvel accessoire est caché dès son arrivée (LocalTransparencyModifier = 1) ; sans poignée, il est ignoré",
         h1.props.get("LocalTransparencyModifier") == 1 and h2.props.get("LocalTransparencyModifier") == 1 and attente() == 2, attente())
maj(1.0)
e1 = h1.m_FindFirstChild("TardisRegenEtincelle")
verifier("G-210 : à son tour, une étincelle (14 particules) ; le second attend encore",
         e1 is not None and e1.emis == 14 and h2.m_FindFirstChild("TardisRegenEtincelle") is None)
maj(1.25)
verifier("G-210 : un par un : le premier est à moitié visible quand le second commence (0,25 s après)",
         proche(h1.props.get("LocalTransparencyModifier"), 0.5) and h2.m_FindFirstChild("TardisRegenEtincelle") is not None and proche(h2.props.get("LocalTransparencyModifier"), 1),
         (h1.props.get("LocalTransparencyModifier"), h2.props.get("LocalTransparencyModifier")))
maj(1.5)
verifier("G-210 : le premier est visible (0) et sort de la file", proche(h1.props.get("LocalTransparencyModifier"), 0) and attente() == 1, attente())
aj(n3, 1.5)
verifier("G-210 : un accessoire arrivé plus tard est caché et prend la suite (0,25 s après le précédent : 1,5 s)", h3.props.get("LocalTransparencyModifier") == 1 and attente() == 2)
maj(1.6)
verifier("G-210 : … à 1,6 s il a son étincelle et il est visible à 20 %",
         h3.m_FindFirstChild("TardisRegenEtincelle") is not None and proche(h3.props.get("LocalTransparencyModifier"), 0.8), h3.props.get("LocalTransparencyModifier"))
h2.set_parent(None)
maj(1.7)
verifier("G-210 : un accessoire détruit entre-temps sort de la file", attente() == 1, attente())
tache(lambda: appeler(suivi.get("finir"), []))
verifier("G-210 : finir() rend visibles ceux qui attendent encore (rien ne reste invisible)", h3.props.get("LocalTransparencyModifier") == 0 and attente() == 0)
H.avancer(1.1)
verifier("G-210 : l'étincelle disparaît au bout d'une seconde (Debris)", e1.parent is None)
tache(lambda: R3.update(s2=premier(appeler(M.get("apparitions"), [True]))))
n4 = accessoire("Badge", 4); h4 = n4.m_FindFirstChild("Handle")
tache(lambda: appeler(R3["s2"].get("ajouter"), [n4, 0])); tache(lambda: appeler(R3["s2"].get("maj"), [0]))
verifier("G-210 : réduire les effets : une petite étincelle (4 particules)", h4.m_FindFirstChild("TardisRegenEtincelle").emis == 4)
verifier("Aucune erreur Luau pendant ces essais", not roblox.ERREURS, roblox.ERREURS[:3])

# ================================================================== 3. Sources
reg = src
eff = reg[reg.index("local function surveillerRegeneration"):reg.index("local function surveillerMoi")]
verifier("G-206 : fils d'or épaule → main (R6 : le bras ; R15 : du haut du bras à la main), coupés par FluxBras",
         'CORPS.FluxBras ~= false' in eff and '{ "Left Arm", "Left Arm" }' in eff and '{ "RightUpperArm", "RightHand" }' in eff and '"TardisRegenFilBras"' in eff)
verifier("G-206 : à chaque image, leur force suit Config.fluxBras(p)", "local fb = Config.fluxBras(p)" in eff and "fil.Enabled = fb > 0.01" in eff)
verifier("G-207 : la lueur (remplissage, contour) et la lumière de la tête battent avec Config.battementCoeur",
         "Config.battementCoeur(t, duree, CORPS.BattementDebut, CORPS.BattementFin)" in eff and "lueur.FillTransparency = 1 - 0.7 * i * coeur" in eff
         and "lueur.OutlineTransparency = 1 - i * coeur" in eff and "lumiereTete.Brightness = 6 * i * coeur" in eff and "CORPS.Battement ~= false" in eff)
verifier("G-209 : copies préparées à 40 % (sauf Cendres = false), suivies à chaque image",
         "if not copiesPretes and p >= 0.4 then preparerCopies() end" in eff and "if CORPS.Cendres == false then return end" in eff and "c.cf = c.poignee.CFrame" in eff)
verifier("G-209 : un ancien accessoire retiré (ChildRemoved) brûle, CendresMax au plus, au sol trouvé",
         "personnage.ChildRemoved:Connect" in eff and "brules < (CORPS.CendresMax or 8)" in eff and "brulerAccessoire(c, solTrouve and sol.Y or nil, reduit)" in eff)
verifier("G-210 : un nouvel accessoire (ChildAdded, après 40 %) entre dans la file des apparitions",
         "personnage.ChildAdded:Connect" in eff and "apparitions and copiesPretes and objet:IsA(\"Accessory\")" in eff and "if apparitions then apparitions.maj(t) end" in eff)
i_dep = eff.index("local depart = os.clock()"); i_add = eff.index("personnage.ChildAdded:Connect"); i_rs = eff.index("depart = os.clock()\n", i_add)
verifier("`depart` existe avant d'être lu par ChildAdded, et repart au début de la boucle de rendu",
         i_dep < i_add < i_rs and eff.count("local depart = os.clock()") == 1)
verifier("Après : les apparitions en attente finissent et les copies inutilisées sont jetées",
         "if apparitions then apparitions.finir() end" in eff and "c.copie:Destroy() anciens[objet] = nil" in eff)
verifier("G-213 : les cheveux fument (Config.estCheveux, type d'accessoire lu sans risque), 70 % du débit des mains, qui baisse pareil",
         "Config.estCheveux(objet.Name, typeNom)" in eff and "pcall(function() typeNom = objet.AccessoryType.Name end)" in eff
         and "fumee.Rate = Config.debitFumeeApres(k) * 0.7" in eff and "volutes.Rate = Config.debitFumeeApres(k)" in eff and "CORPS.FumeeCheveux ~= false" in eff)
verifier("G-213 : … et s'arrêtent avec les mains (même boucle de 15 s, Debris 17 s)", "Debris:AddItem(fumee, 17)" in eff and "Debris:AddItem(volutes, 17)" in eff)
sysrc = lire("ServerScriptService/TardisSystemes.server.lua")
i_t = sysrc.index("(V7.5.2, G-208)"); i_ch = sysrc.index("task.delay(duree * 0.55, function()", i_t)
bloc = sysrc[i_t:i_ch]
verifier("G-208 (serveur) : à 40 % de la durée, BodyColors glisse vers Config.couleursCorps(description), avant le changement (55 %)",
         "task.delay(duree * (CORPS.DebutTeinte or 0.4)" in bloc and "Config.couleursCorps(description)" in bloc
         and 'personnage:FindFirstChildOfClass("BodyColors")' in bloc and "TweenService:Create(corps, TweenInfo.new(duree * (CORPS.DureeTeinte or 0.12)" in bloc and "CORPS.TeinteAvant ~= false" in bloc)
verifier("G-208 (serveur) : attend l'avatar au plus 10 % de la durée, et ne casse rien s'il manque (pcall)",
         "local limite = os.clock() + duree * 0.1" in bloc and "pcall(function()" in bloc)
i_tw = sysrc.index("local TweenService = game:GetService(\"TweenService\")")
verifier("G-208 (serveur) : TweenService est déclaré avant la régénération", i_tw < i_t)
mem = sysrc[sysrc.index("local function surveillerMembres"):sysrc.index("local function bonusPV")]
verifier("G-215 (serveur) : le membre qui repousse sort en Neon doré, puis prend la couleur de BodyColors (Config.proprieteBodyColors) en 1 s",
         "neuf.Material = Enum.Material.Neon" in mem and "Config.proprieteBodyColors(membre)" in mem and "TweenInfo.new(CORPS.DureeRepousseDoree or 1), { Color = vraie }" in mem
         and "neuf.Material = matiere" in mem and "CORPS.RepousseDoree ~= false" in mem)
verifier("Ordre gardé : ancien avatar → éclat (52 %) → nouvel avatar (55 %)", "p >= 0.52 then" in eff and "task.delay(duree * 0.55, function()" in sysrc)

print(f"V7.5.2 : {len(OK)}/{len(OK) + len(KO)} vérifications réussies")
for k in KO: print("  ÉCHEC :", k)
sys.exit(1 if KO else 0)
