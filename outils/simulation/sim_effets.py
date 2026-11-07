"""Simulations des effets visuels du voyage (sim_effets, anciennement sim_v699 de la V6.9.9) : le vrai code, exécuté avec de faux objets Roblox.
  1. TardisConfig : réglages (V6.9.9) et fonctions sans effet de bord (distorsion, heure, état de la salle, vitres).
  2. TardisUI : préférence « aucun flash » (sansFlash), sauvegardée comme les autres préférences.
  3. TardisEffets (le script entier, image par image) : lueur selon l'heure (46), lumières de la salle selon l'état (53),
     Catastrophe dehors (43), vitres qui s'éteignent en dernier (41), et chaque flash supprimé avec « aucun flash » (191).
  4. EffetsExterieurs (le module entier) : distorsion plus forte en Urgence et en Catastrophe, aussi en démat (36).
  5. Signalisation (le module entier) : marque au sol après chaque atterrissage (38), enseigne fixe sans flash (191).
  6. Régénération, auto-destruction et vol libre : les gardes « aucun flash » (191)."""
import os, sys, re, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from monde import *
import roblox
from roblox import Couleur
OK, KO = [], []
def verifier(nom, condition, detail=""):
    (OK if condition else KO).append(nom + ("" if condition else "  →  " + str(detail)))
def tache(f): lancer(Fonction("t", py=f))
def lire(chemin): return open(os.path.join(DEPOT, chemin), encoding="utf-8").read()
V3 = lambda x, y, z: Valeur("Vector3", [x, y, z])

# ------------------------------------------------------------------ Le monde : un TARDIS (extérieur + intérieur), le Lighting, la caméra
I, G, game, joueur = monde(serveur=False)
rs = game.m_FindFirstChild("ReplicatedStorage")
ws = game.m_FindFirstChild("Workspace")
Lighting = game.m_FindFirstChild("Lighting")
RunService = game.m_FindFirstChild("RunService")
R = {}
tache(lambda: R.update(Config=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisConfig")])),
                       UI=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisUI")]))))
Config, UI = R["Config"], R["UI"]
E = Config.get("Etats")
f = lambda nom, *a: appeler(Config.get(nom), list(a))
Lighting.props.update({"ClockTime": 12, "ExposureCompensation": 0, "Ambient": Couleur(0.5, 0.5, 0.5), "OutdoorAmbient": Couleur(0.5, 0.5, 0.5)})
camera = Instance("Camera", "Camera", ws); camera.props["CFrame"] = Valeur("CFrame")
ws.props["CurrentCamera"] = camera
ws.props["Terrain"] = Instance("Terrain", "Terrain")
Instance("PlayerGui", "PlayerGui", joueur)
dossier = Instance("Folder", "TARDIS", ws)
tardis = Instance("Folder", "TARDIS_1", dossier)
x = Instance("Model", "Cabine", Instance("Folder", "EXTERIEURE", tardis))
interieur = Instance("Model", "Salle", Instance("Folder", "INTERIEURE", tardis))
racine = Instance("Part", "Racine", x); racine.props["Transparency"] = 1; x.props["PrimaryPart"] = racine
corps = Instance("Part", "Corps", x)
vitre = Instance("Part", "Vitre1", x); vitre.props.update({"Transparency": 0.3, "Material": Valeur("Enum.Material.Glass")})
lampe = Instance("Part", "Lampe", x)
lumiereLampe = Instance("PointLight", "PointLight", lampe); lumiereLampe.props.update({"Brightness": 2, "Range": 10})
Instance("Folder", "Boucliers", x)
cible = Instance("ObjectValue", "TracteurCible", x); cible.props["Value"] = None
enseigne = Instance("SurfaceGui", "Enseigne", corps); enseigne.props["Brightness"] = 1
etiquette = Instance("TextLabel", "Texte", enseigne); etiquette.props.update({"Text": "POLICE BOX", "TextColor3": Couleur(1, 1, 1), "TextTransparency": 0, "TextStrokeTransparency": 1, "BackgroundTransparency": 1})
rotor = Instance("Part", "Rotor", interieur)
interieur.props["PrimaryPart"] = rotor
plafond = Instance("Part", "Plafond", interieur)
lumiereSalle = Instance("PointLight", "Lumiere", plafond); lumiereSalle.props.update({"Brightness": 3, "Color": Couleur(1, 1, 1)})
lumiereRotorSalle = Instance("PointLight", "LumiereRotor", rotor); lumiereRotorSalle.props.update({"Color": Couleur(1, 1, 1)})
x.attrs.update({"Etat": "Pose", "DebutEtat": 1000.0, "Mode": "Normal"})
# Le sol : un raycast vers le bas touche une pièce grise (ou de l'eau)
solPart = Instance("Part", "Sol"); solPart.props["Color"] = Couleur(0.5, 0.5, 0.5)
SOL = {"materiau": "Grass", "present": True}
def raycast(_w, origine, direction, params=None):
    if not SOL["present"]: return None
    return Table({"Position": V3(0, 0, 0), "Normal": V3(0, 1, 0), "Instance": solPart, "Material": Valeur("Enum.Material." + SOL["materiau"])})
ws.extra["Raycast"] = Fonction("Raycast", py=raycast)

def image(dt=0.1, n=1):
    for _ in range(n):
        H.avancer(dt)
        for nom in ("RenderStepped", "Heartbeat"):
            sig = RunService.extra.get(nom)
            if sig: sig.declencher(dt)
def maintenant(): return 1000.0 + H.t
def etat(nom, mode="Normal"):
    x.m_SetAttribute("Mode", mode)
    x.m_SetAttribute("DebutEtat", maintenant())
    x.m_SetAttribute("Etat", nom)
def pref(cle, valeur): UI.get("prefs").set(cle, valeur)
def dans_ws(prefixe): return [e for e in ws.enfants if e.Name.startswith(prefixe)]


# ------------------------------------------------------------------ 1. TardisConfig : réglages et fonctions pures
verifier("Config.Version ≥ 6.9.9 (6.9.9 à sa sortie)", tuple(int(n) for n in Config.get("Version").split(".")) >= (6, 9, 9), Config.get("Version"))
EF = Config.get("Effets")
attendus = {"DistorsionUrgence": 1.8, "DistorsionCatastrophe": 2.2, "MarquesSol": True, "DureeMarques": 30, "Nuit": 1.35, "Jour": 0.7,
            "Catastrophe": True, "DureeFumeeCatastrophe": 20, "RetardVitres": 1}
verifier("Config.Effets : les 9 réglages de la V6.9.9", all(EF.get(k) == v for k, v in attendus.items()), {k: EF.get(k) for k in attendus})
verifier("Anciens réglages des effets inchangés", all(EF.get(k) is True for k in ("Tourbillon", "Lueur", "Ondes", "Arcs", "Choc", "Contrejour")))
verifier("Config.NomFenetres = Fenetres, Config.NomVitre = Vitre", Config.get("NomFenetres") == "Fenetres" and Config.get("NomVitre") == "Vitre")
cfgsrc = lire("ReplicatedStorage/TardisConfig.lua")
fin_bloc = cfgsrc.find("-- Néons de la salle selon l'état (V6.9.10.1)")  # (réglage ajouté juste après en V6.9.10.1)
bloc = cfgsrc[cfgsrc.index("-- Effets visuels du voyage (V6.9.9)"):fin_bloc if fin_bloc > 0 else cfgsrc.index("-- Vue de l'intérieur depuis l'extérieur")]
effets_v699 = bloc.split("\n}")[0]
nouvelles = [l for l in effets_v699.splitlines() if re.match(r"\s*\w+ = ", l)] + [l for l in bloc.splitlines() if l.startswith("Config.")]
verifier("Chaque nouveau réglage est commenté « (V6.9.9) »", len(nouvelles) == 12 and all("(V6.9.9)" in l for l in nouvelles),
         (len(nouvelles), [l for l in nouvelles if "(V6.9.9)" not in l][:3]))
# 36. Distorsion
for mode, reduit, attendu in [("Normal", False, 1), ("Express", False, 1), ("Sauvetage", False, 1), ("Silencieux", False, 1), ("Urgence", False, 1.8),
                              ("Catastrophe", False, 2.2), ("Urgence", True, 1.4), ("Catastrophe", True, 1.6), ("Normal", True, 1), (True, False, 1.8)]:
    v = premier(f("facteurDistorsion", mode, reduit))
    verifier(f"facteurDistorsion({mode}, réduit={reduit}) = {attendu}", abs(v - attendu) < 1e-9, v)
# 46. Heure
for h, attendu in [(0, 1.35), (3, 1.35), (4.99, 1.35), (6, (1.35 + 0.7) / 2), (7, 0.7), (12, 0.7), (17.5, 0.7), (18.5, (1.35 + 0.7) / 2), (19.5, 1.35), (23.9, 1.35), (24, 1.35)]:
    v = premier(f("facteurHeure", h))
    verifier(f"facteurHeure({h} h) = {attendu:.3f}", abs(v - attendu) < 1e-6, v)
vals = [premier(f("facteurHeure", h / 10)) for h in range(0, 241)]
verifier("facteurHeure : transition douce (pas de saut de plus de 0,05 par 6 min)", max(abs(a - b) for a, b in zip(vals, vals[1:])) < 0.05)
verifier("facteurHeure : heure absente → plein jour", abs(premier(f("facteurHeure", None)) - 0.7) < 1e-9)
# 53. État de la salle
cas = [(("Pose", None, False, False, False), "Pose"), (("Demat", None, False, False, False), "Voyage"), (("Remat", None, False, False, False), "Voyage"),
       (("Vol", None, False, False, False), "Vortex"), (("Pose", None, True, False, False), "Voyage"), (("Pose", None, True, True, False), "Vortex"),
       (("Pose", "Invisible", True, False, False), "Vortex"), (("Pose", "Demat", True, False, False), "Voyage"), (("Vol", None, False, False, True), "Alerte"),
       (("Pose", None, False, False, True), "Alerte")]
for args, attendu in cas:
    v = premier(f("etatSalle", *args))
    verifier(f"etatSalle{args} = {attendu}", v == attendu, v)
CS = Config.get("CouleursSalle")
couleurs = {k: CS.get(k).rgb255() for k in ("Pose", "Voyage", "Vortex", "Alerte")}
verifier("Couleurs de la salle : bleu, ambre, cyan, rouge", couleurs["Pose"][2] > couleurs["Pose"][0] and couleurs["Voyage"][0] > couleurs["Voyage"][2]
         and couleurs["Vortex"][1] > 200 and couleurs["Vortex"][2] > 200 and couleurs["Alerte"][0] > 200 and couleurs["Alerte"][1] < 80, couleurs)
c, force = f("teinteSalle", "Voyage")
verifier("teinteSalle(Voyage) = ambre, force 0,35", c == CS.get("Voyage") and abs(force - 0.35) < 1e-9, (c, force))
CS.set("Pose", False)
verifier("teinteSalle : un état à false garde ses couleurs", f("teinteSalle", "Pose")[:2] == [None, 0])
CS.set("Pose", Couleur(120 / 255, 170 / 255, 1, [120, 170, 255]))
# 41. Vitres
for mode in ("Normal", "Urgence", "Express", "Silencieux"):
    duree, decalage = f("Timing", "Demat", mode)
    fin = decalage + duree
    r_fin = premier(f("retardVitres", "Demat", fin, mode)); r_debut = premier(f("retardVitres", "Demat", decalage, mode))
    verifier(f"retardVitres({mode}) : 0 au début, {min(1, duree / 2)} s à la fin", r_debut == 0 and abs(r_fin - min(1, duree / 2)) < 1e-9, (r_debut, r_fin))
    l_fin = premier(f("lueurVitres", "Demat", fin, mode)); l_avant = premier(f("lueurVitres", "Demat", fin - 2 * min(1, duree / 2) - 0.01, mode))
    l_vol = [premier(f("lueurVitres", "Vol", t, mode)) for t in (0, 0.5 * min(1, duree / 2), min(1, duree / 2))]
    verifier(f"lueurVitres({mode}) : monte à la fin de la démat, s'éteint en Vol", l_avant == 0 and l_fin == 1 and l_vol[0] == 1 and 0 < l_vol[1] < 1 and l_vol[2] == 0, (l_avant, l_fin, l_vol))
verifier("retardVitres : rien en remat ni posé", premier(f("retardVitres", "Remat", 10, "Normal")) == 0 and premier(f("retardVitres", "Pose", 10, "Normal")) == 0)
duree, decalage = f("Timing", "Demat", "Normal")
fin = decalage + duree
a_corps = premier(f("Alpha", "Demat", fin - 0.3, "Normal", True)); a_vitre = premier(f("Alpha", "Demat", fin - 0.3 - premier(f("retardVitres", "Demat", fin - 0.3, "Normal")), "Normal", True))
verifier("Normal, 0,3 s avant la fin : les vitres plus visibles que le reste", a_vitre < a_corps, (a_vitre, a_corps))

# ------------------------------------------------------------------ 2. TardisUI : « aucun flash »
verifier("UI.sansFlash() faux par défaut", premier(appeler(UI.get("sansFlash"), [])) is False)
# Correction T-1 : les canaux sont par TARDIS (« TardisCommande_TARDIS_1 »…), il n'y a plus de « TardisCommande » tout court
canal2 = Instance("RemoteEvent", "TardisCommande_TARDIS_2", rs)
remote = Instance("RemoteEvent", "TardisCommande_TARDIS_1", rs)
tache(lambda: appeler(UI.get("setPref"), ["sansFlash", True]))
H.avancer(1)
envois = remote.extra.get("envois", [])
verifier("UI.setPref(sansFlash) : préférence envoyée au serveur par le canal du TARDIS (correction T-1)", envois and envois[-1][0] == "Prefs" and '"sansFlash":true' in envois[-1][1], envois[-1:])
verifier("Correction T-1 : toujours le même canal (le premier par ordre alphabétique)", not canal2.extra.get("envois"), canal2.extra.get("envois"))
verifier("UI.sansFlash() vrai une fois activé", premier(appeler(UI.get("sansFlash"), [])) is True)
pref("sansFlash", False)
extras = lire("ServerScriptService/TardisExtras.server.lua")
verifier("Serveur : les préférences sont gardées telles quelles (pas de liste de clés à compléter)", "prefs[joueur.UserId] = donnees" in extras and "sansFlash" not in extras)
volet = lire("StarterPlayer/StarterPlayerScripts/TardisTablette/Volet.lua")
verifier("Tablette (réglages) : interrupteur « Aucun flash », qui active aussi « réduire les effets »",
         'UI.setPref("sansFlash", actif)' in volet and ('if actif and not UI.effetsReduits() then UI.setPref("effetsReduits", true) end' in volet
                                                         # V6.9.15 : l'option se règle par appareil (UI.setEffetsReduits)
                                                         or 'if actif and not UI.effetsReduits() then UI.setEffetsReduits(true) end' in volet))

# ------------------------------------------------------------------ 3. TardisEffets : le script entier, image par image
perso = Instance("Model", "Pilote", ws); hrp = Instance("Part", "HumanoidRootPart", perso); joueur.props["Character"] = perso  # à bord
G["script"] = Instance("LocalScript", "TardisEffets", game.m_FindFirstChild("StarterPlayer"))
tache(lambda: I.executer(lire("StarterPlayer/StarterPlayerScripts/TardisEffets.client.lua"), "TardisEffets"))
verifier("TardisEffets se charge (faux monde : cabine, vitre, lampe, salle, rotor)", not roblox.ERREURS and len(RunService.extra["RenderStepped"].connexions) == 3, roblox.ERREURS[:3])
lueur = ws.m_FindFirstChild("TardisLueur_TARDIS_1"); halo = ws.m_FindFirstChild("TardisHalo_TARDIS_1")
teinteMode = Lighting.m_FindFirstChild("TardisTeinteMode_TARDIS_1"); ambiance = Lighting.m_FindFirstChild("TardisAmbiance")
lumiereRotorScript = [e for e in rotor.enfants if e.ClassName == "PointLight" and e is not lumiereRotorSalle][0]
crees = []  # tout ce qui est posé dans le Workspace
ws.__lua_index__("ChildAdded").connecter(Fonction("suivi", py=lambda o: crees.append(o) or []))
def creees(prefixe): return [o for o in crees if o.Name.startswith(prefixe)]
image(0.1, 40)
proche = lambda a, b, tol=0.02: all(abs(u - v) <= tol for u, v in zip(a, b))
def melange(base, cible, k): return tuple(b + (c - b) * k for b, c in zip(base, cible))
blanc = (1.0, 1.0, 1.0)
def norm(c): return (c.r, c.g, c.b)
cs = {k: norm(CS.get(k)) for k in ("Pose", "Voyage", "Vortex", "Alerte")}
# 53. Lumières de la salle selon l'état
verifier("53. Posé : la salle tire vers le bleu (35 %)", proche(norm(lumiereSalle.props["Color"]), melange(blanc, cs["Pose"], 0.35)), lumiereSalle.props["Color"].rgb255())
verifier("53. Les lumières du rotor gardent leur couleur", lumiereRotorSalle.props["Color"].rgb255() == (255, 255, 255), lumiereRotorSalle.props["Color"].rgb255())
# 46. Lueur selon l'heure : même instant d'une remat, de nuit puis de jour
etat("Remat"); duree, decalage = f("Timing", "Remat", "Normal")
image(0.1, int((decalage + 3) / 0.1))
def mesure(heure):
    Lighting.props["ClockTime"] = heure; image(0.0)
    return lueur.m_FindFirstChild("Lumiere").props["Brightness"], halo.props["Transparency"], lumiereLampe.props["Brightness"]
while mesure(12)[0] < 0.5: image(0.1)
jour, nuit = mesure(12), mesure(0)
verifier("46. Lueur de la cabine : × 1,35 la nuit, × 0,7 le jour (même instant)", jour[0] > 0 and abs(nuit[0] / jour[0] - 1.35 / 0.7) < 1e-6, (jour[0], nuit[0]))
verifier("46. Halo de la lampe plus opaque la nuit", nuit[1] < jour[1] < 1, (jour[1], nuit[1]))
verifier("46. Lampe du toit plus vive la nuit", abs(nuit[2] / jour[2] - 1.35 / 0.7) < 1e-6, (jour[2], nuit[2]))
Lighting.props["ClockTime"] = 12
image(0.1, 15)
verifier("53. Remat : la salle tire vers l'ambre", proche(norm(lumiereSalle.props["Color"]), melange(blanc, cs["Voyage"], 0.35)), lumiereSalle.props["Color"].rgb255())
x.m_SetAttribute("Alerte", True); image(0.1, 40)
verifier("53. Alerte : rouge", proche(norm(lumiereSalle.props["Color"]), melange(blanc, cs["Alerte"], 0.35)), lumiereSalle.props["Color"].rgb255())
x.m_SetAttribute("Alerte", None)
x.m_SetAttribute("Alimentation", False); image(0.1, 5)
verifier("53. Hors tension : la lumière de secours (rouge 255, 40, 40) garde la priorité", lumiereSalle.props["Color"].rgb255() == (255, 40, 40), lumiereSalle.props["Color"].rgb255())
x.m_SetAttribute("Alimentation", None)
# 191. Flash de la lampe à l'arrivée (lueur = 2 × flash quand rien d'autre ne brille)
def arrivee(sans):
    pref("sansFlash", sans)
    image(0.1, 20)  # l'éclat précédent s'est éteint
    etat("Remat"); image(0.1, 5)
    etat("Pose"); image(0.0)
    return lueur.m_FindFirstChild("Lumiere").props["Brightness"]
avec, sans = arrivee(False), arrivee(True)
verifier("191. Arrivée : éclat de la lampe et de la lueur", avec > 1, avec)
verifier("191. « Aucun flash » : aucun éclat à l'arrivée", sans == 0, sans)
pref("sansFlash", False); image(0.1, 30)
# 41. Vitres qui s'éteignent en dernier + flash du départ
def depart(mode, sans=False):
    pref("sansFlash", sans)
    etat("Demat", mode)
    duree, decalage = f("Timing", "Demat", mode)
    fin = decalage + duree
    while maintenant() - x.attrs["DebutEtat"] < fin - 0.3: image(0.1)
    image(0.0)
    m = ws.m_FindFirstChild("TardisLueurVitres_TARDIS_1")
    res = {"corps": corps.props["Transparency"], "vitre": (vitre.props["Transparency"] - 0.3) / 0.7, "lueur": m}
    if m:
        copies = [e for e in m.enfants if e.Name == "Vitre1"]
        res["copie"] = copies[0].props["Transparency"] if copies else None
        res["copieNeon"] = copies and copies[0].props["Material"].nom == "Enum.Material.Neon"
        res["lumiere"] = m.m_FindFirstChild("Lumiere").m_FindFirstChild("PointLight").props["Brightness"] if m.m_FindFirstChild("Lumiere") else None
    while maintenant() - x.attrs["DebutEtat"] < fin: image(0.1)
    x.m_SetAttribute("Mode", "Normal"); x.m_SetAttribute("Ciel", True); etat("Vol")  # comme le serveur
    image(0.0); res["flash"] = lueur.m_FindFirstChild("Lumiere").props["Brightness"]
    image(0.1, 3); res["volTot"] = ws.m_FindFirstChild("TardisLueurVitres_TARDIS_1") is not None
    image(0.1, 12); res["volTard"] = ws.m_FindFirstChild("TardisLueurVitres_TARDIS_1") is not None
    x.m_SetAttribute("Ciel", False); etat("Pose"); image(0.1, 30)
    return res
d = depart("Normal")
verifier("41. Démat, 0,3 s avant la fin : la vitre est plus visible que le reste", d["vitre"] < d["corps"] - 0.01, (d["vitre"], d["corps"]))
verifier("41. Une copie chaude (Neon) des vitres s'allume à la fin de la démat", d["lueur"] is not None and d["copieNeon"] and d["copie"] < 0.6, d)
verifier("41. Avec une lumière qui prolonge la lueur", (d.get("lumiere") or 0) > 0.5, d.get("lumiere"))
verifier("41. Elle reste au début du Vol, puis disparaît (au bout de la seconde de retard)", d["volTot"] and not d["volTard"], d)
verifier("191. Départ : éclat de la lampe", d["flash"] > 1, d["flash"])
d = depart("Normal", sans=True)
verifier("191. « Aucun flash » : aucun éclat au départ (les vitres restent, sans éclat)", d["flash"] == 0 and d["lueur"] is not None, d["flash"])
d = depart("Silencieux")
verifier("41. Silencieux : pas de lueur des vitres", d["lueur"] is None, d)
EF.set("RetardVitres", 0)
d = depart("Normal")
verifier("41. RetardVitres = 0 : vitres et reste ensemble, pas de lueur", d["lueur"] is None and abs(d["vitre"] - d["corps"]) < 1e-9, d)
EF.set("RetardVitres", 1)
d = depart("Express")
verifier("41. Rapide (2 s) : retard ramené à 1 s, lueur présente", d["lueur"] is not None and d["vitre"] <= d["corps"], d)
verifier("41. Aucune lueur des vitres oubliée dans le Workspace", not dans_ws("TardisLueurVitres"), [o.Name for o in dans_ws("TardisLueurVitres")])
# 53. Vol : cyan
etat("Vol"); image(0.1, 40)
verifier("53. Vortex (Vol) : cyan", proche(norm(lumiereSalle.props["Color"]), melange(blanc, cs["Vortex"], 0.35)), lumiereSalle.props["Color"].rgb255())
etat("Pose"); image(0.1, 40)
# 191. Urgence : lampe qui vacille et grésillements de la cabine ; arcs
def urgence(sans):
    pref("sansFlash", sans); pref("effetsReduits", False)
    etat("Demat", "Urgence")
    duree, decalage = f("Timing", "Demat", "Urgence")
    image(0.1, int(decalage / 0.1) + 2)
    n0 = len(creees("TardisArc"))
    lampes, ecarts = [], []
    for _ in range(int(duree * 0.7 / 0.1)):
        image(0.1)
        lampes.append(lumiereLampe.props["Brightness"])
        attendu = premier(f("Alpha", "Demat", maintenant() - x.attrs["DebutEtat"], "Urgence", True))
        ecarts.append(abs(corps.props["Transparency"] - attendu))
    arcs = len(creees("TardisArc")) - n0
    etat("Pose"); image(0.1, 30)
    return min(lampes), max(ecarts), arcs
u_avec, u_sans = urgence(False), urgence(True)
verifier("191. Urgence : la lampe coupe par moments (vacillement)", u_avec[0] < 0.2, u_avec[0])
verifier("191. « Aucun flash » : la lampe respire sans couper", u_sans[0] > 0.3, u_sans[0])
verifier("191. « Aucun flash » : la cabine s'efface sans grésillements (animation « réduite »)", u_sans[1] < 1e-9 and u_avec[1] > 0.01, (u_sans[1], u_avec[1]))
verifier("191. Urgence : des arcs électriques ; « aucun flash » : aucun arc", u_avec[2] > 0 and u_sans[2] == 0, (u_avec[2], u_sans[2]))
# 191. Contre-jour à bord, éclair vert du Rapide, battement rouge de la Catastrophe
def interieurFlash(sans):
    pref("sansFlash", sans)
    etat("Demat", "Express"); vals = []
    for _ in range(15):
        image(0.1); vals.append((ambiance.props["Brightness"], teinteMode.props["Brightness"]))
    etat("Pose"); image(0.1, 30)
    return max(v[0] for v in vals), max(v[1] for v in vals)
i_avec, i_sans = interieurFlash(False), interieurFlash(True)
verifier("191. Rapide à bord : contre-jour et éclair vert", i_avec[0] > 0 and i_avec[1] > 0.05, i_avec)
verifier("191. « Aucun flash » : ni contre-jour ni éclair vert", i_sans[0] < 1e-6 and i_sans[1] == 0, i_sans)
# 43. Catastrophe dehors
def catastrophe(sans=False, reduit=False, camoufle=False):
    pref("sansFlash", sans); pref("effetsReduits", reduit)
    x.m_SetAttribute("Camouflage", True if camoufle else None)
    n0 = {k: len(creees(k)) for k in ("TardisCatastrophe_", "TardisEclatCatastrophe", "TardisFumeeCatastrophe_")}
    etat("Remat", "Catastrophe")
    duree, decalage = f("Timing", "Remat", "Catastrophe")
    rotorLum, debits = [], []
    for _ in range(int((decalage + duree) / 0.1)):
        image(0.1)
        rotorLum.append(lumiereRotorScript.props["Brightness"])
        p = ws.m_FindFirstChild("TardisCatastrophe_TARDIS_1")
        if p: debits.append(p.m_FindFirstChild("Fumee").props["Rate"])
    pendant = ws.m_FindFirstChild("TardisCatastrophe_TARDIS_1")
    etincelles = pendant.m_FindFirstChild("Etincelles").emis if pendant else 0
    x.m_SetAttribute("Mode", "Normal"); etat("Pose"); x.m_SetAttribute("Catastrophe", maintenant())  # comme le serveur
    image(0.1, 3)
    res = {"pendant": pendant is not None, "debitMax": max(debits) if debits else 0, "etincelles": etincelles,
           "eclats": len(creees("TardisEclatCatastrophe")) - n0["TardisEclatCatastrophe"],
           "fumee": len(creees("TardisFumeeCatastrophe_")) - n0["TardisFumeeCatastrophe_"],
           "rotor": (min(rotorLum[20:]), max(rotorLum[20:])), "suit": ws.m_FindFirstChild("TardisCatastrophe_TARDIS_1") is not None}
    image(0.1, 60)
    res["apres6s"] = ws.m_FindFirstChild("TardisCatastrophe_TARDIS_1") is not None or bool(dans_ws("TardisEclatCatastrophe"))
    res["fumee10s"] = ws.m_FindFirstChild("TardisFumeeCatastrophe_TARDIS_1") is not None
    image(0.1, 200)
    res["fumee30s"] = ws.m_FindFirstChild("TardisFumeeCatastrophe_TARDIS_1") is not None
    x.m_SetAttribute("Camouflage", None); x.m_SetAttribute("Alerte", None)
    return res
c = catastrophe()
verifier("43. Remat en Catastrophe : fumée noire et étincelles autour de la cabine", c["pendant"] and c["debitMax"] >= 10 and c["etincelles"] > 0, c)
verifier("43. Atterrissage forcé : 18 éclats et une fumée qui traîne", c["eclats"] == 18 and c["fumee"] == 1, c)
verifier("43. Tout est nettoyé : effets de la remat et éclats partis, fumée encore là à 10 s, partie à 30 s",
         not c["apres6s"] and c["fumee10s"] and not c["fumee30s"], c)
verifier("191. Catastrophe : la lumière du rotor bat", c["rotor"][1] - c["rotor"][0] > 1, c["rotor"])
c = catastrophe(reduit=True, sans=True)
verifier("43. Effets réduits : 3 fois moins (6 éclats, débit divisé par 3)", c["eclats"] == 6 and c["debitMax"] < 14 / 3 + 1e-6, c)
verifier("191. « Aucun flash » : la lumière rouge du rotor reste fixe", c["rotor"][1] - c["rotor"][0] < 1e-9, c["rotor"])
c = catastrophe(camoufle=True)
verifier("43. Cabine camouflée : ni fumée ni éclats", not c["pendant"] and c["eclats"] == 0 and c["fumee"] == 0, c)
pref("sansFlash", False); pref("effetsReduits", False)
n0 = len(creees("TardisEclatCatastrophe")); x.m_SetAttribute("Catastrophe", maintenant() - 60); image(0.1, 2)
verifier("43. Ancien atterrissage forcé (attribut vieux de 60 s) : rien ne se rejoue", len(creees("TardisEclatCatastrophe")) == n0)
# 191. Thème Flashbang à bord
x.m_SetAttribute("Theme", "Flashbang")
image(0.1, 40); expo_avec = Lighting.props["ExposureCompensation"]
pref("sansFlash", True); image(0.1, 5); expo_sans = Lighting.props["ExposureCompensation"]
x.m_SetAttribute("Theme", None); pref("sansFlash", False); image(0.1, 60)
verifier("191. Thème Flashbang : exposition forte ; « aucun flash » : exposition normale", expo_avec > 2 and expo_sans <= 1e-9, (expo_avec, expo_sans))
# 191. Bouclier : flash à l'apparition
def bouclier(sans, nom):
    pref("sansFlash", sans)
    m = Instance("Model", nom); b = Instance("Part", "Bulle", m); b.props.update({"Size": V3(12, 12, 12), "Color": Couleur(0.4, 0.7, 1)})
    n0 = len(creees("TardisFlashBouclier")); m.set_parent(x.m_FindFirstChild("Boucliers")); image(0.1, 2)
    return len(creees("TardisFlashBouclier")) - n0
verifier("191. Bouclier : flash à l'apparition ; « aucun flash » : pas de flash", bouclier(False, "B1") == 1 and bouclier(True, "B2") == 0)
image(0.1, 10)
verifier("191. Flash du bouclier nettoyé (Debris)", not dans_ws("TardisFlashBouclier"))
pref("sansFlash", False)
verifier("TardisEffets : aucune erreur pendant tous les scénarios", not roblox.ERREURS and not [l for l in roblox.SORTIE if "en erreur" in l], (roblox.ERREURS[:2], [l for l in roblox.SORTIE if "en erreur" in l][:3]))

# ------------------------------------------------------------------ Outils du script TardisExtrasClient (extraits tels quels)
init = lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/init.client.lua")
outils = init[init.index("local function partTemporaire(proprietes)"):init.index("-- La lampe du toit : la pièce qui contient la PointLight")]
O = {}
tache(lambda: O.update(t=premier(I.executer("local exterieur, Config, E = ...\n" + outils + "\nreturn { partTemporaire = partTemporaire, progressionAnimation = progressionAnimation }",
                                            "outils-extras", (x, Config, E)))))
DEDANS = {"v": False}
def contexte(**plus):
    t = Table({"C": UI.get("C"), "Config": Config, "E": E, "Lighting": Lighting, "RunService": RunService, "UI": UI, "animer": UI.get("animer"),
               "camera": camera, "creer": UI.get("creer"), "texte": UI.get("texte"), "def": Config.get("Tardis").get(1), "exterieur": x, "interieur": interieur,
               "joueur": joueur, "jeSuisDedans": Fonction("jeSuisDedans", py=lambda: DEDANS["v"]), "partTemporaire": O["t"].get("partTemporaire"),
               "progressionAnimation": O["t"].get("progressionAnimation"), "remote": remote, "ReplicatedStorage": rs,
               "secouer": Fonction("secouer", py=lambda *a: [])})
    for k, v in plus.items(): t.set(k, v)
    return t
def module(nom):
    res = {}
    tache(lambda: res.update(m=premier(appeler(premier(I.executer(lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/" + nom + ".lua"), nom)), [contexte()]))))
    return res.get("m")

# ------------------------------------------------------------------ 4. EffetsExterieurs : air qui ondule et distorsion (36)
module("EffetsExterieurs")
verifier("EffetsExterieurs se charge", not roblox.ERREURS, roblox.ERREURS[:3])
flou = Lighting.m_FindFirstChild("TardisDistorsion")
def distorsion(etatNom, mode, reduit=False):
    pref("effetsReduits", reduit)
    etat(etatNom, mode)
    duree, decalage = f("Timing", etatNom, mode)
    flous, debits, air = [], [], False
    for _ in range(int((decalage + duree) / 0.1)):
        image(0.1)
        flous.append(flou.props["Size"])
        a = ws.m_FindFirstChild("TardisAir")
        if a and a.m_FindFirstChild("Emetteur").props["Enabled"] is not False:
            air = True; debits.append(a.m_FindFirstChild("Emetteur").props["Rate"])
    etat("Pose"); image(0.1, 40)
    return max(flous), max(debits) if debits else 0, air
normal = distorsion("Remat", "Normal")
urg = distorsion("Remat", "Urgence")
cata = distorsion("Remat", "Catastrophe")
urgReduit = distorsion("Remat", "Urgence", reduit=True)
verifier("36. Remat normale : flou d'écran et air qui ondule", normal[0] > 8 and normal[1] > 5 and normal[2], normal)
verifier("36. Urgence : distorsion × 1,8 (flou et débit de l'air)", abs(urg[0] / normal[0] - 1.8) < 0.1 and abs(urg[1] / normal[1] - 1.8) < 0.1, (urg, normal))
verifier("36. Catastrophe : distorsion × 2,2", abs(cata[0] / normal[0] - 2.2) < 0.12, (cata, normal))
verifier("36. Effets réduits : Urgence ramenée à × 1,4", abs(urgReduit[0] / normal[0] - 1.4) < 0.1, (urgReduit, normal))
dn, du = distorsion("Demat", "Normal"), distorsion("Demat", "Urgence")
verifier("36. Démat : l'air n'ondule qu'en Urgence (avant : seulement à la remat)", not dn[2] and du[2], (dn, du))
ds = distorsion("Remat", "Silencieux")
verifier("36. Silencieux : ni flou ni air", ds[0] < 0.01 and not ds[2], ds)
image(0.1, 40)
verifier("36. Les volutes d'air sont nettoyées après le voyage", not dans_ws("TardisAir"))
pref("effetsReduits", False)

# ------------------------------------------------------------------ 5. Signalisation : marque au sol (38) et enseigne (191)
module("Signalisation")
verifier("Signalisation se charge", not roblox.ERREURS, roblox.ERREURS[:3])
# Le faux CFrame ne calcule pas de positions : par défaut, tout point paraît dans la salle. On teste d'abord ce cas
# (paradoxe : cabine posée dans la salle → pas de marque), puis on place la salle « loin » (boîte illisible → pas de test de salle).
boiteSalle = interieur.m_GetBoundingBox
def atterrir(mode, **attrs):
    for k, v in attrs.items(): x.m_SetAttribute(k, v)
    etat("Remat", mode); image(0.1, 5)
    x.m_SetAttribute("Mode", "Normal"); etat("Pose"); image(0.1, 2)  # le serveur remet Mode à Normal en posant
    m = ws.m_FindFirstChild("TardisMarqueSol_TARDIS_1")
    for k in attrs: x.m_SetAttribute(k, None)
    return m
m = atterrir("Normal")
verifier("38. Cabine posée dans la salle (paradoxe) : pas de marque (correction de relecture)", m is None, m)
H.avancer(31); image(0.1)
def salle_loin(): raise roblox.LuaError("salle hors de portée")
interieur.m_GetBoundingBox = salle_loin
m = atterrir("Normal")
verifier("38. Atterrissage (Classique) : une marque carrée au sol", m is not None and m.props["Size"].args == [5.0, 0.05, 5.0] and m.props["Transparency"] == 0.7
         and m.props["Material"].nom == "Enum.Material.SmoothPlastic", m and (m.props["Size"].args, m.props["Transparency"]))
verifier("38. Couleur : celle du sol, assombrie", m is not None and proche(norm(m.props["Color"]), (0.175, 0.175, 0.175), 0.005), m and m.props["Color"].rgb255())
H.avancer(29); image(0.1)
verifier("38. Toujours là à 29 s", ws.m_FindFirstChild("TardisMarqueSol_TARDIS_1") is m)
H.avancer(1.5); image(0.1)
verifier("38. Partie après 30 s", m.parent is None and not dans_ws("TardisMarqueSol"))
for mode in ("Urgence", "Express", "Sauvetage", "Catastrophe"):
    m = atterrir(mode)
    verifier(f"38. Marque aussi après un atterrissage {mode}", m is not None)
m2 = atterrir("Normal")
verifier("38. Une seule marque par TARDIS (la nouvelle remplace l'ancienne)", len(dans_ws("TardisMarqueSol")) == 1 and m.parent is None, len(dans_ws("TardisMarqueSol")))
m2.set_parent(None)
verifier("38. Silencieux : aucune marque", atterrir("Silencieux") is None)
verifier("38. Sur l'eau (SurEau) : aucune marque", atterrir("Normal", SurEau=True) is None)
SOL["materiau"] = "Water"
verifier("38. Sol en eau (Terrain) : aucune marque", atterrir("Normal") is None)
SOL["materiau"] = "Grass"
verifier("38. Camouflé : aucune marque", atterrir("Normal", Camouflage=True) is None)
EF.set("MarquesSol", False)
verifier("38. Config.Effets.MarquesSol = false : aucune marque", atterrir("Normal") is None)
EF.set("MarquesSol", True)
for o in dans_ws("TardisMarqueSol"): o.set_parent(None)
def enseigneRapide(sans):
    pref("sansFlash", sans)
    etat("Demat", "Express"); vals = set()
    for _ in range(10):
        image(0.05); vals.add(round(enseigne.props["Brightness"], 6))
    etat("Pose"); image(0.1, 2)
    return vals
e_avec, e_sans = enseigneRapide(False), enseigneRapide(True)
verifier("191. Enseigne en Rapide : stroboscope", len(e_avec) >= 2, e_avec)
verifier("191. « Aucun flash » : enseigne fixe, allumée", e_sans == {1.0}, e_sans)
verifier("Enseigne : brillance d'origine rendue une fois posé", enseigne.props["Brightness"] == 1)
pref("sansFlash", False)
verifier("Signalisation : aucune erreur", not roblox.ERREURS, roblox.ERREURS[:3])

# ------------------------------------------------------------------ 6. Auto-destruction, vol libre, régénération : gardes « aucun flash »
gui = joueur.m_FindFirstChild("PlayerGui")
module("AutoDestruction")
def explosion(sans):
    pref("sansFlash", sans)
    x.m_SetAttribute("Explosion", None); image(0.1)
    x.m_SetAttribute("Explosion", True); image(0.1)
    voile = gui.m_FindFirstChild("TardisFlashExplosion") is not None
    boule = ws.m_FindFirstChild("TardisExplosion")
    image(0.1, 40)
    return voile, boule.props["Transparency"] if boule else None
ex_avec, ex_sans = explosion(False), explosion(True)
verifier("191. Explosion : voile blanc à l'écran ; « aucun flash » : pas de voile", ex_avec[0] and not ex_sans[0], (ex_avec, ex_sans))
verifier("191. « Aucun flash » : boule de feu adoucie (petite, très transparente)", ex_avec[1] == 0 and ex_sans[1] == 0.8, (ex_avec, ex_sans))
x.m_SetAttribute("Explosion", None)
def compteARebours(sans):
    pref("sansFlash", sans)
    x.m_SetAttribute("AutoDestructionDebut", maintenant()); x.m_SetAttribute("AutoDestructionDuree", 20)
    image(0.1, 50)
    rouges = [h for h in x.enfants if h.ClassName == "Highlight"]
    vals = []
    for _ in range(10):
        image(0.05); vals.append(rouges[-1].props["FillTransparency"])
    x.m_SetAttribute("AutoDestructionDebut", None); image(0.1, 2)
    return max(vals) - min(vals)
verifier("191. Compte à rebours : le rouge clignote ; « aucun flash » : il monte sans clignoter", compteARebours(False) > 0.05 and compteARebours(True) < 0.01)
pref("sansFlash", False)
vl = lire("StarterPlayer/StarterPlayerScripts/TardisVolLibre.client.lua")
fonction = vl[vl.index("local function distorsionTemporelle(position"):vl.index("--------------------------------------------------------------------", vl.index("local function flashTemporel(position"))]  # V7.1.1 : flashTemporel appelle distorsionTemporelle
F = {}
tache(lambda: F.update(f=premier(I.executer("local UI = ...\nlocal creer, animer = UI.creer, UI.animer\nlocal vol = { taille = Vector3.new(4, 9, 4) }\n"
                                            + fonction + "\nreturn flashTemporel", "flashTemporel", (UI,)))))
verifier("Vol libre : fonction flashTemporel extraite", F.get("f") is not None, roblox.ERREURS[-2:])
def flashVol(sans):
    compte = lambda: len([o for o in crees if o.Name == "TardisFlash"])
    pref("sansFlash", sans); n0 = compte()
    tache(lambda: appeler(F["f"], [V3(0, 0, 0)])); image(0.1, 6)
    return compte() - n0
fv = (flashVol(False), flashVol(True))
verifier("191. Vol libre : éclair du saut temporel ; « aucun flash » : aucun", fv == (1, 0), (fv, roblox.ERREURS[-2:]))
verifier("Vol libre : la démat / remat en vol suit aussi « aucun flash »", "Config.Alpha(phase, ecoule, Config.modeVolDe(exterieur), UI.effetsReduits() or UI.sansFlash())" in vl)
pref("sansFlash", False)
reg = lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Regeneration.lua")
verifier("191. Régénération : préférence lue au début de l'effet", "local sansFlash = UI.sansFlash()" in reg)
verifier("191. Régénération : pas d'écran blanc pour celui qui se régénère", "if moi and not flashFait and p >= 0.5 and not sansFlash then" in reg)
i_eclat = reg.index("local function eclatChangement()")
verifier("191. Régénération : l'éclat du changement s'arrête avant la boule de lumière",
         reg.index("if sansFlash then", i_eclat) < reg.index("TardisRegenEclatChangement", i_eclat) and reg.index("return", reg.index("if sansFlash then", i_eclat)) < reg.index("TardisRegenEclatChangement", i_eclat))
i_expl = reg.index('"TardisRegenExplosion"')
verifier("191. Régénération (style Explosion) : l'onde de choc seule, sans la boule", "if sansFlash then ondeDeChoc(OR_CLAIR, 0.8) return end" in reg[i_expl - 300:i_expl])
i_lien = reg.index('Name = "TardisLienTimeLord"')
verifier("191. Lien Time Lord : le voile doré est derrière la garde", "if not sansFlash then" in reg[i_lien - 200:i_lien])
eff = lire("StarterPlayer/StarterPlayerScripts/TardisEffets.client.lua")
verifier("Pas de nouvelle boucle par image (3 RenderStepped dans TardisEffets, comme avant)", eff.count("RunService.RenderStepped:Connect") == 3 and eff.count("RunService.Heartbeat:Connect") == 1)
verifier("Pas de nouvelle action réseau (aucun FireServer ajouté)", eff.count("FireServer") == 0 and lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Signalisation.lua").count("FireServer") == 0)
verifier("Aucune erreur au total", not roblox.ERREURS, roblox.ERREURS[:3])


print("\n".join("  ✓ " + o for o in OK))
print("\n".join("  ✗ " + k for k in KO))
print(f"EFFETS DU VOYAGE (V6.9.9) : {len(OK)}/{len(OK) + len(KO)} vérifications réussies")
sys.exit(1 if KO else 0)
