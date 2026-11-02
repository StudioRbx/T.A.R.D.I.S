"""Construit un faux « game » Roblox pour charger les modules du TARDIS."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from luau import Interp, Table, Fonction, LuaError, appeler, premier, tostring
from roblox import Instance, Signal, environnement, charger_module, H, lancer, SORTIE, ERREURS, MAGASINS, Valeur
DEPOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "src"))

def monde(serveur=True):
    I = Interp({})
    G = environnement(I, serveur)
    game = Instance("DataModel", "game")
    for s in ("Players", "ReplicatedStorage", "ServerStorage", "ServerScriptService", "RunService", "DataStoreService", "HttpService", "TweenService",
              "TextService", "StarterGui", "SoundService", "Lighting", "Teams", "TextChatService", "ScriptContext", "LogService", "CollectionService",
              "UserInputService", "GuiService", "ContentProvider", "Debris", "PhysicsService", "MarketplaceService", "StarterPlayer"):
        Instance(s, s, game)
    ws = Instance("Workspace", "Workspace", game)
    game.extra["serveur"] = serveur
    G["game"], G["workspace"] = game, ws
    rs = game.m_FindFirstChild("ReplicatedStorage")
    for nom in ("TardisConfig", "TardisUI", "TardisCommandes"):
        m = Instance("ModuleScript", nom, rs); m.extra["chemin"] = f"{DEPOT}/ReplicatedStorage/{nom}.lua"
    sss = game.m_FindFirstChild("ServerScriptService")
    m = Instance("ModuleScript", "TardisSauvegarde", sss); m.extra["chemin"] = f"{DEPOT}/ServerScriptService/TardisSauvegarde.lua"
    def require(obj):
        ch = obj.extra.get("chemin") if isinstance(obj, Instance) else None
        if not ch: raise LuaError("require : module inconnu de la simulation " + tostring(obj))
        return charger_module(I, ch, obj)
    G["require"] = Fonction("require", py=require)
    G["script"] = Instance("Script", "SimulationScript", sss)
    joueur = Instance("Player", "Pilote", game.m_FindFirstChild("Players")); joueur.props.update({"UserId": 101, "DisplayName": "Pilote", "Team": None, "Character": None})
    game.m_FindFirstChild("Players").props["LocalPlayer"] = joueur
    return I, G, game, joueur
