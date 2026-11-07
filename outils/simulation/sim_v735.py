"""Simulations de la V7.3.5 (vue par la porte) : le vrai code, avec de faux objets Roblox.
  1. TardisConfig : bouclier levé et voile qui ondule (G-159), lumière de la salle vue de dehors (G-166), copie des
     environs à refaire (G-169), silhouettes les plus proches (G-168).
  2. TardisPortail (le vrai LocalScript) : voile du bouclier sur la vue de la rue, salle sombre hors tension et rouge en
     alerte, copie du rotor en couleur, rue recopiée toutes les 2 min porte fermée (jamais porte ouverte), silhouettes
     des joueurs et PNJ dans la rue et à bord, qui suivent, changent de vue et disparaissent porte fermée.
  3. Le code."""
import os, sys
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
def descendants(o):
    res = []
    def visite(x):
        for e in x.enfants: res.append(e); visite(e)
    visite(o); return res
def rgb(c): return c.rgb255() if hasattr(c, "rgb255") else None

# La copie de la salle (interieur:Clone()) doit garder ses enfants pour la copie du rotor : Clone profond pour cette simulation
def clone_profond(s):
    c = Instance(s.ClassName, s.Name); c.props = dict(s.props); c.attrs = dict(s.attrs)
    for e in list(s.enfants): clone_profond(e).set_parent(c)
    return c
roblox.Instance.m_Clone = clone_profond

# ================================================================== 1. TardisConfig
vider_cache()
I, G, game, joueur = monde(serveur=False)
activer_maths(G)
rs = game.m_FindFirstChild("ReplicatedStorage")
R = {}
tache(lambda: R.update(Config=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisConfig")]))))
Config = R["Config"]
E = Config.get("Etats")
VP = Config.get("VuePorte")
f = lambda nom, *a: appeler(Config.get(nom), list(a))
f1 = lambda nom, *a: premier(f(nom, *a))
verifier("Config.Version ≥ 7.3.5 (7.3.5 à sa sortie)", tuple(int(n) for n in Config.get("Version").split(".")) >= (7, 3, 5), Config.get("Version"))
verifier("Config.VuePorte : voile, salle, rafraîchissement et silhouettes actifs",
         all(VP.get(k) is True for k in ("VoileBouclier", "SalleSuitLumieres", "RafraichirEnvirons", "Silhouettes")))
verifier("Config.VuePorte : rue recopiée toutes les 120 s, 12 silhouettes au plus, 5 mises à jour par seconde, voile à 0,8",
         (VP.get("PeriodeRafraichir"), VP.get("MaxSilhouettes"), VP.get("PeriodeSilhouettes"), VP.get("TransparenceVoile")) == (120, 12, 0.2, 0.8))
verifier("G-159. bouclierLeve : anti-joueurs, anti-balles ou complet ; aucun → non",
         [f1("bouclierLeve", True, None, None), f1("bouclierLeve", None, True, None), f1("bouclierLeve", False, False, True),
          f1("bouclierLeve", False, False, False), f1("bouclierLeve", None, None, None)] == [True, True, True, False, False])
tv = [f1("transparenceVoile", t / 10, 0.8) for t in range(0, 200)]
verifier("G-159. transparenceVoile : elle ondule autour de 0,8 (entre 0,71 et 0,89, et elle change)",
         min(tv) >= 0.71 and max(tv) <= 0.89 and max(tv) - min(tv) > 0.08, (min(tv), max(tv)))
verifier("G-159. transparenceVoile : moyenne absente → 0,8 ; toujours entre 0 et 1",
         abs(f1("transparenceVoile", 0, None) - 0.8) < 1e-9 and f1("transparenceVoile", 1, 1) <= 1 and f1("transparenceVoile", 1, -1) >= 0)
amb = lambda *a: tuple(rgb(c) for c in f("ambianceVueSalle", *a))
normale = f1("ambianceVueSalle", False, False, None)
verifier("G-166. ambianceVueSalle : normale → l'ambiante d'origine et une lumière blanche",
         amb(False, False, Config.get("LumiereAmbiante")) == ((170, 170, 170), (255, 255, 255)), amb(False, False, Config.get("LumiereAmbiante")))
verifier("G-166. ambianceVueSalle : hors tension → presque noire", amb(True, False, None) == ((18, 18, 24), (45, 45, 60)))
verifier("G-166. ambianceVueSalle : alerte → rouge (même hors tension)", amb(False, True, None) == ((110, 25, 25), (255, 70, 60)) and amb(True, True, None) == amb(False, True, None))
P = E.get("Pose")
verifier("G-169. rafraichirEnvirons : posé, porte fermée, 120 s après → oui ; 119 s → non",
         f1("rafraichirEnvirons", 0, 120, 120, False, P, False) is True and f1("rafraichirEnvirons", 0, 119, 120, False, P, False) is False)
verifier("G-169. rafraichirEnvirons : porte ouverte, en vol, en vol libre ou période 0 → non",
         [f1("rafraichirEnvirons", 0, 500, 120, True, P, False), f1("rafraichirEnvirons", 0, 500, 120, False, E.get("Vol"), False),
          f1("rafraichirEnvirons", 0, 500, 120, False, P, True), f1("rafraichirEnvirons", 0, 500, 0, False, P, False)] == [False] * 4)
RC = {}
tache(lambda: RC.update(r=I.executer("""local Config = ...
local c = { { cle = "a", distance = 30 }, { cle = "b", distance = 5 }, { cle = "c", distance = 12 }, { cle = "d", distance = 50 } }
local g2 = Config.choisirSilhouettes(c, 2)
local g9 = Config.choisirSilhouettes(c, 9)
local g0 = Config.choisirSilhouettes(c, 0)
local n9 = 0 for _ in g9 do n9 += 1 end
local n0 = 0 for _ in g0 do n0 += 1 end
local vide = Config.choisirSilhouettes(nil, 3)
return g2.b == true and g2.c == true and g2.a == nil and g2.d == nil, n9, n0, next(vide) == nil, c[1].cle""", "silhouettes", (Config,))))
r = list(RC["r"])
verifier("G-168. choisirSilhouettes : les plus proches d'abord (2 sur 4 → b et c)", r[0] is True, r)
verifier("G-168. choisirSilhouettes : max au-delà du nombre → tous ; max 0 → aucun ; liste absente → aucun ; la liste n'est pas touchée",
         r[1] == 4 and r[2] == 0 and r[3] is True and r[4] == "a", r)

# ================================================================== 2. TardisPortail (le vrai LocalScript)
def part(nom, parent, pos=(0, 0, 0), taille=(2, 2, 2), classe="Part"):
    p = Instance(classe, nom, parent)
    p.props.update({"CFrame": CF(pos), "Size": Vec3(*taille), "Position": Vec3(*pos)})
    return p
def deplacer(p, pos): p.props.update({"CFrame": CF(pos), "Position": Vec3(*pos)})
def perso(nom, parent, pos):
    m = Instance("Model", nom, parent)
    Instance("Humanoid", "Humanoid", m)
    x, y, z = pos
    hrp = part("HumanoidRootPart", m, (x, y, z), (2, 2, 1)); hrp.props["Transparency"] = 1
    part("Torso", m, (x, y, z), (2, 2, 1)); part("Head", m, (x, y + 1.5, z), (1, 1, 1))
    m.props["PrimaryPart"] = hrp
    return m

vider_cache(); roblox.ERREURS.clear()
I, G, game, joueur = monde(serveur=True)
activer_maths(G)
ws = game.m_FindFirstChild("Workspace")
t1 = Instance("Folder", "TARDIS_1", Instance("Folder", "TARDIS", ws))
ext = Instance("Model", "TARDIS_1", Instance("Folder", "EXTERIEURE", t1))
racine = part("Racine", ext, (200, 0, 0)); ext.props["PrimaryPart"] = racine
portailExt = part("Portail", ext, (200, 4, 2), (4, 8, 1))
Instance("Model", "TARDISDoors", ext)
salle = Instance("Folder", "INTERIEURE", t1)
rotor = Instance("Model", "Rotor", salle); colonne = part("Colonne", rotor, (0, 5, 0), (2, 10, 2))
portailInt = part("Portail", salle, (0, 4, 20), (6, 8, 1))
part("Sol", salle, (0, -1, 0), (40, 2, 40))
Instance("Folder", "TARDIS_DESTINATIONS", t1.parent)
part("Lampadaire", ws, (200, 4, -20), (1, 8, 1))
rs = game.m_FindFirstChild("ReplicatedStorage")
tache(lambda: R.update(Config=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisConfig")]))))
Config = R["Config"]; E = Config.get("Etats")
ext.attrs.update({"Etat": E.get("Pose"), "PorteOuverte": False, "Echelle": 1, "Alimentation": True})
camera = Instance("Camera", "Camera", ws); camera.props["CFrame"] = CF((0, 4, 26)); ws.props["CurrentCamera"] = camera
ws.props["Terrain"] = Instance("Terrain", "Terrain")
Instance("PlayerGui", "PlayerGui", joueur)
players = game.m_FindFirstChild("Players")
# Dans la rue (devant la porte extérieure, z < 2) : un autre joueur, un PNJ, et le joueur lui-même ; à bord : un compagnon
autre = Instance("Player", "Autre", players); autre.props.update({"UserId": 202})
persoAutre = perso("Autre", ws, (200, 3, -6)); autre.props["Character"] = persoAutre
pnjRue = perso("Marchand", ws, (204, 3, -10))
persoMoi = perso("Pilote", ws, (198, 3, -4)); joueur.props["Character"] = persoMoi
compagnon = perso("Compagnon", salle, (5, 3, 5))
derriere = perso("Passant", ws, (200, 3, 30))  # derrière le TARDIS : pas dans la vue
loin = perso("Lointain", ws, (200, 3, -400))   # trop loin
game.extra["serveur"] = False
G["script"] = Instance("LocalScript", "TardisPortail", game.m_FindFirstChild("StarterPlayer"))
tache(lambda: I.executer(lire("StarterPlayer/StarterPlayerScripts/TardisPortail.client.lua"), "TardisPortail"))
H.avancer(2)
pg = joueur.m_FindFirstChild("PlayerGui")
guiRue, guiSalle = pg.m_FindFirstChild("TardisVueExterieur"), pg.m_FindFirstChild("TardisVueInterieur")
verifier("Portail chargé : les deux fenêtres, aucune erreur", guiRue is not None and guiSalle is not None and not roblox.ERREURS, roblox.ERREURS[:3])
vueRue = next(o for o in descendants(guiRue) if o.ClassName == "ViewportFrame")
vueSalle = next(o for o in descendants(guiSalle) if o.ClassName == "ViewportFrame")
voile = next((o for o in descendants(guiRue) if o.Name == "TardisVoileBouclier"), None)
rendu = next(v for k, v in game.m_FindFirstChild("RunService").extra.get("rendu", {}).items() if str(k).startswith("TardisVue_"))
def image(): tache(lambda: appeler(rendu, [1 / 60]))
def attr(nom, valeur):
    ext.attrs[nom] = valeur
    ext.signal_attr(nom).declencher()

# --- G-159 voile du bouclier
verifier("G-159. Voile créé dans le cadre de la vue de la rue, au-dessus de l'image, caché au départ",
         voile is not None and voile.parent is vueRue.parent and voile.props.get("ZIndex") == 5 and voile.props.get("Visible") is False
         and rgb(voile.props.get("BackgroundColor3")) == (110, 180, 255))
attr("PorteOuverte", True)
image()
verifier("G-159. Porte ouverte, vue de la rue visible, pas de bouclier : pas de voile", vueRue.props.get("Visible") is True and voile.props.get("Visible") is False,
         (vueRue.props.get("Visible"), voile.props.get("Visible")))
attr("BouclierComplet", True)
transparences = []
for i in range(30):
    H.avancer(0.1); image(); transparences.append(voile.props.get("BackgroundTransparency"))
verifier("G-159. Bouclier levé : le voile apparaît et ondule (transparence entre 0,71 et 0,89, qui change)",
         voile.props.get("Visible") is True and min(transparences) >= 0.71 and max(transparences) <= 0.89 and max(transparences) - min(transparences) > 0.02,
         (voile.props.get("Visible"), min(transparences), max(transparences)))
attr("BouclierComplet", False); attr("BouclierBalles", True); image()
verifier("G-159. Bouclier anti-balles : voile aussi", voile.props.get("Visible") is True)
attr("PorteOuverte", False); image()
verifier("G-159. Porte fermée : voile caché", voile.props.get("Visible") is False)
attr("BouclierBalles", False); attr("PorteOuverte", True); image()
verifier("G-159. Bouclier baissé : plus de voile", voile.props.get("Visible") is False)
attr("PorteOuverte", False)

# --- G-166 salle qui suit ses lumières
verifier("G-166. Au départ : la salle vue de dehors a l'ambiante normale (170) et une lumière blanche",
         rgb(vueSalle.props.get("Ambient")) == (170, 170, 170) and rgb(vueSalle.props.get("LightColor")) == (255, 255, 255),
         (rgb(vueSalle.props.get("Ambient")), rgb(vueSalle.props.get("LightColor"))))
attr("Alimentation", False)
verifier("G-166. Hors tension : salle presque noire", rgb(vueSalle.props.get("Ambient")) == (18, 18, 24) and rgb(vueSalle.props.get("LightColor")) == (45, 45, 60))
attr("Alerte", True)
verifier("G-166. Alerte : salle rouge", rgb(vueSalle.props.get("Ambient")) == (110, 25, 25) and rgb(vueSalle.props.get("LightColor")) == (255, 70, 60))
attr("Alerte", False); attr("Alimentation", True)
verifier("G-166. Retour du courant et fin de l'alerte : ambiante normale", rgb(vueSalle.props.get("Ambient")) == (170, 170, 170) and rgb(vueSalle.props.get("LightColor")) == (255, 255, 255))
attr("AutoDestructionDebut", 1000.0)
verifier("G-166. Auto-destruction : salle rouge aussi", rgb(vueSalle.props.get("Ambient")) == (110, 25, 25))
attr("AutoDestructionDebut", None)
verifier("G-166. Auto-destruction annulée : ambiante normale", rgb(vueSalle.props.get("Ambient")) == (170, 170, 170))
copieSalle = next((o for o in vueSalle.enfants if o.Name == "INTERIEURE"), None)
copieColonne = copieSalle and copieSalle.m_FindFirstChild("Rotor") and copieSalle.m_FindFirstChild("Rotor").m_FindFirstChild("Colonne")
tache(lambda: I.executer("local p = ... p.Color = Color3.fromRGB(255, 40, 30) p.Material = Enum.Material.Neon", "rotor", (colonne,)))
attr("PorteOuverte", True); H.avancer(0.5)
verifier("G-166. Porte ouverte : la copie du rotor prend la couleur et la matière du vrai",
         copieColonne is not None and copieColonne is not colonne and rgb(copieColonne.props.get("Color")) == (255, 40, 30)
         and getattr(copieColonne.props.get("Material"), "nom", str(copieColonne.props.get("Material"))).endswith("Neon"),
         (copieColonne and rgb(copieColonne.props.get("Color")), copieColonne and copieColonne.props.get("Material")))

# --- G-168 silhouettes
def silhouettes(vue):
    d = next((o for o in vue.enfants if o.Name == "TardisSilhouettes"), None)
    return [] if d is None else [s for s in d.enfants if s.Name == "Silhouette"]
rue, bord = silhouettes(vueRue), silhouettes(vueSalle)
verifier("G-168. Porte ouverte : dans la vue de la rue, deux silhouettes (l'autre joueur et le PNJ ; ni moi, ni le passant derrière, ni le lointain)",
         len(rue) == 2, len(rue))
verifier("G-168. À bord : le compagnon apparaît dans la salle vue de dehors", len(bord) == 1, len(bord))
pieces = rue[0].enfants if rue else []
verifier("G-168. Une silhouette : le corps sans la HumanoidRootPart (2 pièces), sombre, ancrée, sans collision ni ombre",
         len(pieces) == 2 and all(rgb(p.props.get("Color")) == (25, 25, 32) and p.props.get("Anchored") is True and p.props.get("CanCollide") is False
                                  and p.props.get("CastShadow") is False and p.ClassName == "Part" for p in pieces), [(p.Name, rgb(p.props.get("Color"))) for p in pieces])
torse = persoAutre.m_FindFirstChild("Torso")
deplacer(torse, (201, 3, -9))
H.avancer(0.3)
copieTorse = None
for s in silhouettes(vueRue):
    for p in s.enfants:
        if p.props.get("CFrame") is not None and tuple(p.props["CFrame"].p) == (201, 3, -9): copieTorse = p
verifier("G-168. L'autre joueur bouge : sa silhouette suit (moins de 0,3 s)", copieTorse is not None)
avant = len(silhouettes(vueRue))
deplacer(persoAutre.m_FindFirstChild("HumanoidRootPart"), (0, 3, 0))
H.avancer(0.3)
verifier("G-168. Il entre dans la salle : sa silhouette passe de la vue de la rue à la vue de la salle",
         len(silhouettes(vueRue)) == avant - 1 and len(silhouettes(vueSalle)) == 2, (len(silhouettes(vueRue)), len(silhouettes(vueSalle))))
pnjRue.m_Destroy(); H.avancer(3.5)
verifier("G-168. Le PNJ s'en va : sa silhouette disparaît", len(silhouettes(vueRue)) == 0, len(silhouettes(vueRue)))
attr("PorteOuverte", False); H.avancer(0.3)
verifier("G-168. Porte fermée : plus aucune silhouette", not silhouettes(vueRue) and not silhouettes(vueSalle))

# --- G-169 rue recopiée de temps en temps
def environs(): return next((o for o in vueRue.enfants if o.Name == "Environs"), None)
e0 = environs()
H.avancer(60)
verifier("G-169. Porte fermée, 1 min : la même copie des environs", environs() is e0 and e0 is not None)
H.avancer(70)
e1 = environs()
verifier("G-169. Porte fermée, plus de 2 min : copie des environs refaite (le lampadaire est toujours là)",
         e1 is not None and e1 is not e0 and any(o.Name == "Lampadaire" for o in e1.enfants), (e1 is e0,))
attr("PorteOuverte", True)
H.avancer(200)
verifier("G-169. Porte ouverte : jamais recopiée (l'image ne saute pas)", environs() is e1)
attr("PorteOuverte", False)
attr("Etat", E.get("Vol")); H.avancer(200)
e2 = environs()
verifier("G-169. En vol : pas de copie refaite", e2 is e1)
verifier("Portail : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])

# ================================================================== 3. Le code
portail = lire("StarterPlayer/StarterPlayerScripts/TardisPortail.client.lua")
bloc = portail[portail.index("-- (V7.3.5) Vue par la porte"):portail.index("-- Mise à jour des vues (après la caméra du joueur)")]
verifier("3. Bloc V7.3.5 : aucune boucle par image (ni Heartbeat, ni RenderStepped, ni BindToRenderStep)",
         not any(m in bloc for m in ("Heartbeat", "RenderStepped", "BindToRenderStep")))
verifier("3. Silhouettes : jamais le joueur lui-même, 12 au plus, les PNJ cherchés toutes les 3 s seulement",
         "perso == joueur.Character" in bloc and "Config.choisirSilhouettes(candidats, MAX)" in bloc and "os.clock() + 3" in bloc)
verifier("3. Boîte de la salle par Config.boite (jamais GetBoundingBox sur l'intérieur)", "Config.boite(interieur)" in bloc and "interieur:GetBoundingBox" not in portail)
verifier("3. Voile mis à jour dans la boucle de rendu existante, caché porte fermée", portail.count("voile.Visible = false") >= 3)

print("\n".join("  ✓ " + o for o in OK)); print("\n".join("  ✗ " + k for k in KO))
print(f"VUE PAR LA PORTE (V7.3.5) : {len(OK)}/{len(OK) + len(KO)} vérifications réussies")
sys.exit(1 if KO else 0)
