"""Simulations de la V7.5.4 (régénération à bord et selon le lieu) : le vrai code, exécuté avec de faux objets Roblox.
  1. TardisConfig : réglages Config.Regeneration.ABord / Lieu et calculs purs (dureeRegeneration, effetABord,
     pulsationOr, sousEau, solBrulantSelon).
  2. TardisSystemes (le vrai gestionnaire « régénération à bord », extrait du script) : dégâts par défaut, recharge
     en option (C-266), durée transmise aux clients (G-65 / G-141 / G-220).
  3. Sources : durée plus courte à bord (C-238), catastrophe sans lumière dorée, client (bulles et vapeur sous l'eau,
     sol selon le matériau, vitres / salle / rotor dorés)."""
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

# ================================================================== 1. TardisConfig
vider_cache()
I, G, game, joueur = monde(serveur=False)
activer_maths(G)
rs = game.m_FindFirstChild("ReplicatedStorage")
R = {}
tache(lambda: R.update(Config=premier(appeler(G["require"], [rs.m_FindFirstChild("TardisConfig")]))))
Config = R["Config"]
f = lambda nom, *a: premier(appeler(Config.get(nom), list(a)))
verifier("Config.Version ≥ 7.5.4 (7.5.4 à sa sortie)", tuple(int(n) for n in Config.get("Version").split(".")) >= (7, 5, 4), Config.get("Version"))
REGEN = Config.get("Regeneration")
AB, LI = REGEN.get("ABord"), REGEN.get("Lieu")
verifier("Config.Regeneration.ABord : durée ×0,6 (C-238), recharge désactivée par défaut (400 points, 25 %) (C-266)",
         AB and (AB.get("FacteurDuree"), AB.get("Recharge"), AB.get("RechargeIntegrite"), AB.get("RechargeBouclier")) == (0.6, False, 400, 25))
verifier("Config.Regeneration.ABord : vitres (G-65), lueur de la salle (G-141), jets vers le rotor (G-220)",
         (AB.get("Vitres"), AB.get("LueurSalle"), AB.get("JetsVersRotor")) == (True, True, True))
verifier("Config.Regeneration.Lieu : sous l'eau (G-217), sol selon le matériau (G-223)",
         LI and (LI.get("SousEau"), LI.get("SolSelonMateriau")) == (True, True))
verifier("Les réglages des versions d'avant sont toujours là (Poses, DegatsTardis, Duree)",
         REGEN.get("Poses") is not None and REGEN.get("DegatsTardis") is not None and REGEN.get("Duree") is not None)

verifier("C-238 : hors du TARDIS, la durée ne change pas (5 s → 5 s)", proche(f("dureeRegeneration", 5, False, 0.6), 5))
verifier("C-238 : à bord, 5 s × 0,6 = 3 s (et 0,6 sans facteur)", proche(f("dureeRegeneration", 5, True, 0.6), 3) and proche(f("dureeRegeneration", 5, True, None), 3))
verifier("C-238 : facteur borné entre 0,1 et 1 (20 s × 5 → 20 s ; 20 s × 0,01 → 2 s)",
         proche(f("dureeRegeneration", 20, True, 5), 20) and proche(f("dureeRegeneration", 20, True, 0.01), 2))
verifier("C-238 : jamais moins d'1 s (1 s × 0,6 → 1 s) ; sans durée → 5 s",
         proche(f("dureeRegeneration", 1, True, 0.6), 1) and proche(f("dureeRegeneration", None, False, None), 5))

e = f("effetABord", REGEN)
verifier("C-266 : par défaut, la régénération à bord abîme le TARDIS (DegatsTardis), sans recharge",
         e and proche(e.get("degats"), REGEN.get("DegatsTardis")) and e.get("reparation") is None)
verifier("C-266 : sans réglages → 400 points de dégâts", proche(f("effetABord", None).get("degats"), 400))

verifier("G-65 : pulsation dorée nulle avant le début et après la fin", all(f("pulsationOr", t, 6) == 0 for t in (0, -1, 6, 7)))
puls = [f("pulsationOr", i * 0.01, 6) for i in range(1, 600)]
verifier("G-65 : pulsation toujours entre 0 et 1, et elle bat vraiment (varie de plus de 0,3 au milieu)",
         all(0 <= p <= 1 for p in puls) and max(puls[150:450]) - min(puls[150:450]) > 0.3, (min(puls), max(puls)))
verifier("G-65 : elle monte au début et retombe à la fin (enveloppe de 15 %)",
         f("pulsationOr", 0.05, 6) < 0.15 and f("pulsationOr", 5.95, 6) < 0.15 and max(puls[200:400]) > 0.9)

verifier("G-217 : sous l'eau quand il nage", f("sousEau", "Swimming", 0) is True)
verifier("G-217 : sous l'eau quand l'eau remplit au moins la moitié de l'endroit (0,6 oui, 0,4 non)",
         f("sousEau", "Running", 0.6) is True and f("sousEau", "Running", 0.4) is False)
verifier("G-217 : sans renseignement → pas sous l'eau", f("sousEau", None, None) is False)

g = {m: f("solBrulantSelon", m) for m in ("Grass", "LeafyGrass", "Mud", "Snow", "Ice", "Metal", "DiamondPlate", "Concrete", "Sand")}
verifier("G-223 : herbe, neige, métal reconnus ; béton et sable → le disque habituel (nil)",
         [g[m] and g[m].get("genre") for m in g] == ["herbe", "herbe", "herbe", "neige", "neige", "metal", "metal", None, None]
         and f("solBrulantSelon", None) is None, {m: g[m] and g[m].get("genre") for m in g})
verifier("G-223 : l'herbe garde la couleur du style puis noircit (Slate, tache qui reste)",
         g["Grass"].get("couleur") is None and g["Grass"].get("materiauFin") == "Slate" and g["Grass"].get("transparenceFin") < 1)
verifier("G-223 : la neige devient une flaque (Glass, bleutée, peu de lumière)",
         g["Snow"].get("materiau") == "Glass" and g["Snow"].get("couleur") is not None and g["Snow"].get("lumiere") < 1
         and g["Snow"].get("transparenceFin") < 1)
verifier("G-223 : le métal rougeoie plus fort (×1,4) et plus longtemps (20 s, contre 12 d'habitude)",
         g["Metal"].get("lumiere") == 1.4 and g["Metal"].get("refroidi") == 20 and g["Metal"].get("refroidi") > 12)
ENUM_MAT = {"Neon", "Slate", "Glass", "Metal"}
verifier("G-223 : tous les matériaux donnés existent dans Enum.Material",
         all(g[m].get("materiau") in ENUM_MAT and g[m].get("materiauFin") in ENUM_MAT for m in g if g[m]))

# ================================================================== 2. TardisSystemes : le gestionnaire « à bord »
sysrc = lire("ServerScriptService/TardisSystemes.server.lua")
d_h = sysrc.index("evenementABord.Event:Connect(function(nomTardis, duree)")
f_h = sysrc.index("-- Catastrophe (V6.7.1)")
extrait = sysrc[d_h:f_h]
code = ("local Config, REGEN, exterieur = ...\n"
        "local def = { Nom = \"TARDIS1\" }\n"
        "local journal = {}\n"
        "local function reparer(n) table.insert(journal, { \"reparer\", n }) end\n"
        "local function degats(n, raison) table.insert(journal, { \"degats\", n, raison }) end\n"
        "local function direAuxPilotes(m, b) table.insert(journal, { \"dire\", m }) end\n"
        "local function interne(quoi) table.insert(journal, { \"interne\", quoi }) end\n"
        "local workspace = { GetServerTimeNow = function() return 1234 end }\n"
        "local gestionnaire\n"
        "local evenementABord = { Event = { Connect = function(_, f) gestionnaire = f end } }\n"
        + extrait +
        "\nreturn { lancer = function(nom, duree) for k in pairs(journal) do journal[k] = nil end gestionnaire(nom, duree) return journal end,\n"
        "  recharge = function(v) REGEN.ABord.Recharge = v end }\n")
ws = game.m_FindFirstChild("Workspace")
ext = Instance("Model", "TARDIS1", ws)
tache(lambda: R.update(r=I.executer(code, "abord_serveur", (Config, REGEN, ext))))
r = R.get("r") or [None]
M = r[0] if r else None
verifier("Vrai gestionnaire « régénération à bord » extrait de TardisSystemes, sans erreur", M is not None and not roblox.ERREURS, (r, roblox.ERREURS[:3]))
def lancer_abord(nom, duree):
    tache(lambda: R.update(j=premier(appeler(M.get("lancer"), [nom, duree]))))
    j = R["j"]; out = []
    i = 1
    while j.get(i) is not None:
        e = j.get(i); out.append([e.get(k) for k in (1, 2, 3)]); i += 1
    return out

ext.attrs.clear()
j = lancer_abord("AUTRE", 3)
verifier("Un autre TARDIS : rien ne se passe", j == [] and ext.attrs.get("RegenerationABord") is None, j)
j = lancer_abord("TARDIS1", 3)
verifier("C-266 : par défaut le TARDIS encaisse le choc (dégâts « Régénération à bord »), pas de réparation",
         any(e[0] == "degats" and proche(e[1], REGEN.get("DegatsTardis")) and e[2] == "Régénération à bord" for e in j)
         and not any(e[0] == "reparer" for e in j), j)
verifier("G-65 / G-141 / G-220 : la durée (3 s) part aux clients, avant l'instant des étincelles",
         proche(ext.attrs.get("RegenerationABordDuree"), 3) and proche(ext.attrs.get("RegenerationABord"), 1234))
verifier("L'alarme et le Cloître sonnent toujours", [e[1] for e in j if e[0] == "interne"] == ["alerter", "jouer"], j)
j = lancer_abord("TARDIS1", None)
verifier("Sans durée → 0 (seulement les étincelles)", proche(ext.attrs.get("RegenerationABordDuree"), 0))

tache(lambda: appeler(M.get("recharge"), [True]))
ext.attrs["BouclierEnergie"] = 90
j = lancer_abord("TARDIS1", 3)
verifier("C-266 : avec l'option Recharge, l'énergie répare le TARDIS (400 points), sans dégâts",
         any(e[0] == "reparer" and proche(e[1], 400) for e in j) and not any(e[0] == "degats" for e in j), j)
verifier("C-266 : … le bouclier gagne 25 %, sans dépasser 100 (90 → 100)", proche(ext.attrs.get("BouclierEnergie"), 100))
ext.attrs["BouclierEnergie"] = 40
lancer_abord("TARDIS1", 3)
verifier("C-266 : … (40 → 65), et les pilotes sont prévenus", proche(ext.attrs.get("BouclierEnergie"), 65)
         and any(e[0] == "dire" and "recharge" in str(e[1]) for e in lancer_abord("TARDIS1", 3)))
del ext.attrs["BouclierEnergie"]
lancer_abord("TARDIS1", 3)
verifier("C-266 : bouclier inconnu → plein (100)", proche(ext.attrs.get("BouclierEnergie"), 100))
tache(lambda: appeler(M.get("recharge"), [False]))
verifier("Option remise : de nouveau des dégâts", any(e[0] == "degats" for e in lancer_abord("TARDIS1", 3)))
verifier("Aucune erreur pendant le gestionnaire", not roblox.ERREURS, roblox.ERREURS[:3])

# ================================================================== 3. Sources
der = sysrc[sysrc.index("local function derouler(changerTenue)"):sysrc.index("-- Chute dans le vide (V6.9.7) : on retient")]
verifier("C-238 : la durée est calculée après le lieu, plus courte à bord",
         "local duree = Config.dureeRegeneration(REGEN.Duree or 5, lieu ~= nil, (REGEN.ABord or {}).FacteurDuree)" in der
         and der.index("local lieu = racinePos and tardisABord(racinePos.Position) or nil") < der.index("local duree = Config.dureeRegeneration(")
         and "local duree = REGEN.Duree or 5" not in der)
verifier("C-238 : la durée est utilisée ensuite (pose, fin) et transmise au TARDIS",
         "if lieu then evenementABord:Fire(lieu, duree) end" in der and der.index("Config.dureeRegeneration(") < der.index("task.delay(duree, function()"))
cat = sysrc[f_h:f_h + 900]
verifier("Catastrophe : durée 0, donc seulement les étincelles (pas de lumière dorée)",
         cat.index("exterieur:SetAttribute(\"RegenerationABordDuree\", 0)") < cat.index("exterieur:SetAttribute(\"RegenerationABord\", workspace:GetServerTimeNow())"))

cli = lire("StarterPlayer/StarterPlayerScripts/TardisExtrasClient/Regeneration.lua")
verifier("G-217 : le client regarde l'eau du Terrain autour du corps (ReadVoxels) et l'état Swimming via Config.sousEau",
         "workspace.Terrain:ReadVoxels(region, 4)" in cli and "Enum.Material.Water" in cli
         and "sousEau = Config.sousEau(humanoid and humanoid:GetState().Name, occupation)" in cli and "if LIEU.SousEau ~= false then" in cli)
verifier("G-217 : sous l'eau, les flammes deviennent des bulles (dans emetteur, avant tout effet)",
         "if sousEau and proprietes.Texture == FEU then" in cli
         and cli.index("local sousEau = false") < cli.index("local function emetteur(parent, proprietes, debitMax, seuil)") < cli.index("if sousEau and proprietes.Texture == FEU then"))
verifier("G-217 : … de la vapeur monte du corps, et pas de sol brûlant",
         "if sousEau then\n" in cli and "EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(0, 4, 0) }, 35, 0.1)" in cli
         and "local avecSolBrulant = not sousEau" in cli)
verifier("G-223 : le rayon vers le sol retient le matériau touché",
         "if r then sol, solTrouve, materiauSol = r.Position, true, r.Material end" in cli and "local solTrouve, materiauSol = false, nil" in cli)
verifier("G-223 : le sol brûlé suit Config.solBrulantSelon (couleur, matériau, lumière)",
         "genreSol = LIEU.SolSelonMateriau ~= false and materiauSol and Config.solBrulantSelon(materiauSol.Name) or nil" in cli
         and "Material = Enum.Material[genreSol and genreSol.materiau or \"Neon\"]" in cli
         and "brulure.PointLight.Brightness = 3 * i * (genreSol and genreSol.lumiere or 1)" in cli)
verifier("G-223 : … et son refroidissement aussi (durée, couleur, matériau et transparence de fin)",
         "local refroidi = g.refroidi or 12" in cli and "ancienne.Material = Enum.Material[g.materiauFin]" in cli
         and "Debris:AddItem(ancienne, refroidi + 3.5)" in cli and "Debris:AddItem(ancienne, 12.5)" not in cli)
ab = cli[cli.index("local function orABord(d)"):]
verifier("G-65 : à bord, les vitres s'illuminent en or (Highlight + lumière) et pulsent (Config.pulsationOr)",
         "Config.NomFenetres" in ab and "Config.NomVitre" in ab and "Name = \"TardisRegenVitre\"" in ab
         and "local p = Config.pulsationOr(t, d)" in ab and "v.halo.FillTransparency = 1 - 0.6 * p" in ab)
verifier("G-141 : une lumière dorée envahit la salle (portée 60), en vague au début de l'éruption",
         "Name = \"TardisRegenSalle\"" in ab and "Range = 60" in ab and "salle.Brightness = 4 * math.clamp(1 - math.abs(t - d * 0.3) / (d * 0.2), 0, 1)" in ab)
verifier("G-220 : des jets courbés vont du torse de celui qui se régénère jusqu'au rotor, qui brille en or",
         "Name = \"TardisRegenRotor\"" in ab and "Name = \"TardisRegenVersRotor\"" in ab and "Attachment1 = cible" in ab
         and "CurveSize0 = math.random(-8, 8)" in ab and "maintenant - quand < 3" in ab)
verifier("Effets réduits : un seul jet au lieu de trois ; chaque réglage peut être coupé",
         "for _ = 1, reduit and 1 or 3 do" in ab and "ABORD.Vitres ~= false" in ab and "ABORD.LueurSalle ~= false" in ab and "ABORD.JetsVersRotor ~= false" in ab)
verifier("Tout disparaît à la fin de la régénération (déconnexion et destruction)",
         "connexion:Disconnect()" in ab and "for _, o in objets do if o.Parent then o:Destroy() end end" in ab)
verifier("Le client lit la durée et n'allume l'or que si elle est positive (la catastrophe garde ses seules étincelles)",
         "local d = tonumber(exterieur:GetAttribute(\"RegenerationABordDuree\")) or 0\n\t\tif d > 0 then orABord(d) end" in cli
         and cli.index("local function orABord(d)") < cli.index("if d > 0 then orABord(d) end"))

print(f"V7.5.4 : {len(OK)}/{len(OK) + len(KO)} vérifications réussies")
for k in KO: print("  ÉCHEC :", k)
sys.exit(1 if KO else 0)
