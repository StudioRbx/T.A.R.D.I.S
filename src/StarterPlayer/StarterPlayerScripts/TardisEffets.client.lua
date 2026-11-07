-- StarterPlayer > StarterPlayerScripts > TardisEffets (LocalScript)
-- (Dé)matérialisation de l'extérieur, lampe, rotor, lumières de la salle, secousses, et depuis la V6.7 :
-- lueur de la cabine, tourbillon de poussière, ondes au sol, arcs d'urgence, choc d'atterrissage ; depuis la V6.9.9 :
-- lueurs selon l'heure, lumières de la salle selon l'état, Catastrophe plus violente, vitres qui s'éteignent en dernier,
-- et l'option « aucun flash » (UI.sansFlash) ; depuis la V6.9.10 : rotor qui suit la vitesse du vol libre ;
-- depuis la V6.9.10.1 : les néons de la salle prennent aussi la couleur de l'état ; depuis la V7.2.1 : cabine vivante
-- (fenêtres allumées la nuit, vitres sombres hors tension et teintées par l'état, maintenance, frémissement du départ,
-- lampe qui arrive la première, contour de la remat, ombres des croisillons, reflet du soleil).
-- Tout est calculé à partir des attributs "Etat" et "DebutEtat" posés par le serveur (Config.Souffle),
-- donc tous les joueurs voient la même chose au même moment (même ceux qui arrivent en cours de vol).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("TardisConfig"))
local UI = require(ReplicatedStorage:WaitForChild("TardisUI"))
local E = Config.Etats
local EFFETS = Config.Effets or {}
local joueur = Players.LocalPlayer

local def = Config.demarrerPourChaqueTardis(script) -- un exemplaire par TARDIS : tout le monde voit les trois
local exterieur, interieur = Config.modeles(def)
local rotor = interieur:WaitForChild(Config.NomRotor)
local lampe = exterieur:FindFirstChild(Config.NomLampe, true)
local lumiere = lampe and lampe:FindFirstChildWhichIsA("Light", true)

-- Pièce d'effet : ancrée, sans collision, ignorée par les raycasts
local function piece(proprietes)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	for cle, valeur in proprietes do p[cle] = valeur end
	p.Parent = workspace
	return p
end
local function tween(objet, duree, proprietes, style, direction)
	local t = TweenService:Create(objet, TweenInfo.new(duree, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), proprietes)
	t:Play()
	return t
end

-- Tout ce qui s'affiche sur l'extérieur, avec ses valeurs d'origine.
-- Chaque type d'objet a ses propres propriétés à faire disparaître.
local PROPRIETES = {
	-- { classe, { propriétés de transparence }, { propriétés de luminosité }, { propriétés à couper } }
	{ "BasePart",     { "Transparency" }, {}, {} },
	{ "Decal",        { "Transparency" }, {}, {} }, -- inclut les Textures
	{ "ImageLabel",   { "ImageTransparency", "BackgroundTransparency" }, {}, {} },
	{ "ImageButton",  { "ImageTransparency", "BackgroundTransparency" }, {}, {} },
	{ "TextLabel",    { "TextTransparency", "TextStrokeTransparency", "BackgroundTransparency" }, {}, {} },
	{ "TextButton",   { "TextTransparency", "TextStrokeTransparency", "BackgroundTransparency" }, {}, {} },
	{ "GuiObject",    { "BackgroundTransparency" }, {}, {} }, -- Frames et autres éléments d'interface
	{ "Highlight",    { "FillTransparency", "OutlineTransparency" }, {}, {} },
	{ "Light",        {}, { "Brightness" }, {} },
	{ "ParticleEmitter", {}, {}, { "Enabled" } },
	{ "Beam",         {}, {}, { "Enabled" } },
	{ "Trail",        {}, {}, { "Enabled" } },
	{ "Fire",         {}, {}, { "Enabled" } },
	{ "Smoke",        {}, {}, { "Enabled" } },
	{ "Sparkles",     {}, {}, { "Enabled" } },
}

local visuels = {} -- [objet] = { transparences = {...}, luminosites = {...}, actifs = {...}, vitre = vrai/faux }

-- Vitres de la cabine (V6.9.9) : rangées dans un dossier « Fenetres » (Config.NomFenetres) ou nommées « Vitre… »
-- (Config.NomVitre). Si rien n'est rangé ni nommé : détection automatique (verre, ou pièce semi-transparente), faite
-- une seule fois au chargement (pas sur les pièces ajoutées ensuite, comme les bulles des boucliers).
local dossierFenetres = exterieur:FindFirstChild(Config.NomFenetres or "Fenetres", true)
local PREFIXE_VITRE = Config.NomVitre or "Vitre"
local vitresNommees = false
for _, objet in exterieur:GetDescendants() do
	if objet:IsA("BasePart") and string.sub(objet.Name, 1, #PREFIXE_VITRE) == PREFIXE_VITRE then vitresNommees = true break end
end
local detectionAuto = true -- vrai pendant le chargement seulement
local function estVitre(objet)
	if not objet:IsA("BasePart") or objet == exterieur.PrimaryPart or objet.Name == Config.NomPortailExt then return false end
	local boucliers = exterieur:FindFirstChild("Boucliers")
	if boucliers and objet:IsDescendantOf(boucliers) then return false end
	if dossierFenetres and objet:IsDescendantOf(dossierFenetres) then return true end
	if string.sub(objet.Name, 1, #PREFIXE_VITRE) == PREFIXE_VITRE then return true end
	if dossierFenetres or vitresNommees or not detectionAuto then return false end -- vitres rangées ou nommées : pas de détection automatique
	return objet.Material == Enum.Material.Glass or (objet.Transparency > 0.1 and objet.Transparency < 0.95)
end
local nombreVitres = 0

local function enregistrer(objet)
	if visuels[objet] or objet == lumiere then return end -- la lumière de la Lampe est gérée à part
	for _, regle in PROPRIETES do
		if objet:IsA(regle[1]) then
			local fiche = { transparences = {}, luminosites = {}, actifs = {} }
			for _, prop in regle[2] do fiche.transparences[prop] = objet[prop] end
			for _, prop in regle[3] do fiche.luminosites[prop] = objet[prop] end
			for _, prop in regle[4] do fiche.actifs[prop] = objet[prop] end
			if estVitre(objet) then
				fiche.vitre = true
				nombreVitres += 1
			end
			-- (V7.2.1, G-9) La lampe (et ce qu'elle contient) apparaît la première en remat
			if lampe and (objet == lampe or objet:IsDescendantOf(lampe)) then fiche.lampe = true end
			visuels[objet] = fiche
			return
		end
	end
end

for _, objet in exterieur:GetDescendants() do
	enregistrer(objet)
end
detectionAuto = false
exterieur.DescendantAdded:Connect(enregistrer)
exterieur.DescendantRemoving:Connect(function(objet)
	if visuels[objet] and visuels[objet].vitre then nombreVitres -= 1 end
	visuels[objet] = nil
end)

local rotorBase = rotor:GetPivot() -- marche avec une Part OU un Model
local brillanceBase = lumiere and lumiere.Brightness or 0
local porteeBase = lumiere and lumiere.Range or 8
-- (V7.1.1, G-79) Échelle de la cabine (attribut Echelle, réglé par le serveur) : les effets suivent sa taille,
-- une cabine à 25 % n'a plus des effets géants (portée de la lampe, tourbillon, étincelles, arcs)
local function echelle() return math.clamp(tonumber(exterieur:GetAttribute("Echelle")) or 1, 0.05, 20) end
local couleurLampe = lumiere and lumiere.Color or Color3.new(1, 1, 1)

-- Position de la lampe dans le monde (sa lumière est sur une pièce ou sur un Attachment)
local function positionLampe()
	if not lumiere then return exterieur:GetPivot().Position + Vector3.new(0, exterieur:GetExtentsSize().Y / 2, 0) end
	local support = lumiere.Parent
	if support and support:IsA("Attachment") then return support.WorldPosition end
	if support and support:IsA("BasePart") then return support.Position end
	return exterieur:GetPivot().Position + Vector3.new(0, exterieur:GetExtentsSize().Y / 2, 0)
end

-- Rotor coloré selon le mode du voyage (V6.6.2) : ses néons et ses lumières prennent la couleur du mode
-- (Config.Modes[mode].CouleurRotor) pendant le voyage, en fondu, puis retrouvent leur couleur d'origine.
local melangeRotor, couleurRotor = 0, Color3.new(1, 1, 1)
local neonsRotor = {} -- [part] = couleur d'origine
for _, objet in rotor:GetDescendants() do
	if objet:IsA("BasePart") and objet.Material == Enum.Material.Neon then neonsRotor[objet] = objet.Color end
end
if rotor:IsA("BasePart") and rotor.Material == Enum.Material.Neon then neonsRotor[rotor] = rotor.Color end

-- Ambiance de l'intérieur (locale) : noir quand le courant est coupé, teinte rouge en alerte
local Lighting = game:GetService("Lighting")
local expositionOrigine = Lighting.ExposureCompensation
local expositionEcrite = false
local lumieresSalle = {} -- [Light] = { brillance, couleur, facteur } : gestion des lumières de la salle
local listeLumieres = nil -- les Light de la salle, mémorisées
local ambianceOrigine, exterieureOrigine = Lighting.Ambient, Lighting.OutdoorAmbient
local themeActuel = 0 -- 0 = éclairage normal, 1 = thème appliqué (lissé)
local ledsOrigine = {} -- [Light] = couleur d'origine (thèmes de l'intérieur)
local couleurEtatSalle, forceEtatSalle = nil, 0 -- couleur de l'état de la salle (V6.9.9), lissée

-- Néons de la salle selon l'état (V6.9.10.1, Config.NeonsSalle) : les pièces en Neon de l'intérieur prennent la couleur
-- de l'état, en douceur, dans la boucle des lumières (aucune boucle en plus). Un néon n'est repeint que quand sa
-- couleur change vraiment ; sa couleur d'origine est rendue exactement quand l'effet retombe. Pas le rotor (couleur du
-- mode), ni les LedsAlerte, ni les écrans. Si le serveur change lui-même la couleur d'un néon (alerte sans dossier
-- LedsAlerte, style de la console), c'est sa nouvelle couleur d'origine.
local NEONS = Config.NeonsSalle or {}
local neonsSalle = {}            -- [BasePart] = { origine = Color3, ecrite = Color3 ou nil (jamais repeint) }
local couleurNeons, forceNeons = nil, 0 -- couleur et force appliquées aux néons, lissées
local cleNeons = nil             -- couleur et force (arrondies) du dernier passage : rien à repeindre si elles n'ont pas bougé
local neonsExclus = {}
for _, nom in NEONS.Exclure or { "Ecran", "Ecran-Ingenieure" } do neonsExclus[nom] = true end
if NEONS.ExclureIgnorerVue == true then neonsExclus[Config.NomIgnorerVue or "IgnorerVue"] = true end
local function memeCouleur(a, b) -- les couleurs des pièces sont gardées sur 8 bits par canal : on compare à 1/255 près
	return math.abs(a.R - b.R) < 0.006 and math.abs(a.G - b.G) < 0.006 and math.abs(a.B - b.B) < 0.006
end
local function neonExclu(objet)
	if objet == rotor or objet:IsDescendantOf(rotor) then return true end
	-- (V6.9.10.1, relecture) cherché à chaque fois : le dossier peut arriver après le chargement (Streaming, ajout en jeu)
	local dossierLedsNeons = interieur:FindFirstChild(Config.NomLedsAlerte or "LedsAlerte")
	if dossierLedsNeons and objet:IsDescendantOf(dossierLedsNeons) then return true end
	if string.sub(objet.Name, 1, 6) == "Tardis" then return true end -- pièces d'effet des scripts
	local p = objet
	while p and p ~= interieur do
		if neonsExclus[p.Name] then return true end
		p = p.Parent
	end
	return false
end
local function enregistrerNeon(objet)
	if NEONS.Actif == false or neonsSalle[objet] or not objet:IsA("BasePart") or objet.Material ~= Enum.Material.Neon or neonExclu(objet) then return end
	local infos = { origine = objet.Color, ecrite = nil }
	neonsSalle[objet] = infos
	objet:GetPropertyChangedSignal("Color"):Connect(function()
		if infos.ecrite and memeCouleur(objet.Color, infos.ecrite) then return end -- notre propre couleur
		infos.origine = objet.Color
		infos.ecrite = nil
		cleNeons = nil -- à repeindre au prochain passage
	end)
end
local function chercherNeons()
	for _, objet in interieur:GetDescendants() do enregistrerNeon(objet) end
end
chercherNeons()
interieur.DescendantAdded:Connect(enregistrerNeon)
-- Hors tension, le serveur passe les néons en plastique : ceux d'un joueur arrivé à ce moment-là sont trouvés au retour du courant
exterieur:GetAttributeChangedSignal("Alimentation"):Connect(function()
	if exterieur:GetAttribute("Alimentation") ~= false then task.defer(chercherNeons) end
end)
-- Une image : la couleur visée suit l'état (bleu, ambre, cyan, rouge) ou le secours rouge hors tension
local function lisserNeons(dt, horsTension, cibleCouleurSalle)
	if NEONS.Actif == false then return end
	local cible, force = cibleCouleurSalle, cibleCouleurSalle and (tonumber(NEONS.Force) or 0.5) or 0
	if horsTension then cible, force = NEONS.Secours or Color3.fromRGB(255, 40, 40), tonumber(NEONS.ForceSecours) or 0.6 end
	if UI.effetsReduits() then force *= tonumber(NEONS.ForceReduite) or 0.5 end
	force = math.clamp(force, 0, 1)
	-- « Aucun flash » : un changement encore plus lent (jamais de saut de couleur)
	local lissage = math.min(dt * (UI.sansFlash() and 0.75 or 1.5), 1)
	if cible then couleurNeons = couleurNeons and couleurNeons:Lerp(cible, lissage) or cible end
	forceNeons += (force - forceNeons) * lissage
	if force == 0 and forceNeons < 0.004 then forceNeons = 0 end
end
local function peindreNeons()
	if NEONS.Actif == false then return end
	local cle = "0"
	if forceNeons > 0 and couleurNeons then
		cle = string.format("%d,%d,%d,%d", math.floor(couleurNeons.R * 255 + 0.5), math.floor(couleurNeons.G * 255 + 0.5),
			math.floor(couleurNeons.B * 255 + 0.5), math.floor(forceNeons * 255 + 0.5))
	end
	if cle == cleNeons then return end -- rien n'a bougé depuis le dernier passage
	cleNeons = cle
	for part, infos in neonsSalle do
		if not part.Parent then
			neonsSalle[part] = nil
		elseif cle == "0" then
			-- L'effet est retombé : la couleur d'origine, exactement
			if infos.ecrite then
				infos.ecrite = infos.origine
				part.Color = infos.origine
				infos.ecrite = nil
			end
		else
			local couleur = infos.origine:Lerp(couleurNeons, forceNeons)
			if not (infos.ecrite and memeCouleur(infos.ecrite, couleur)) then
				infos.ecrite = couleur
				part.Color = couleur
			end
		end
	end
end
local function themeChoisi()
	local nom = exterieur:GetAttribute("Theme")
	for _, theme in Config.Themes or {} do
		if theme.nom == nom then return theme end
	end
	return nil
end
local teinte = Instance.new("ColorCorrectionEffect")
teinte.Name = "TardisAmbiance"
teinte.Parent = Lighting
local noirActuel, rougeActuel = 0, 0 -- 0 = rien, 1 = effet complet (lissés)
local boiteCF, boiteTaille = Config.boite(interieur) -- Model ou dossier (V6.9.10.2)

local function dansInterieur(position)
	local p = boiteCF:PointToObjectSpace(position)
	return math.abs(p.X) <= boiteTaille.X / 2
		and math.abs(p.Y) <= boiteTaille.Y / 2
		and math.abs(p.Z) <= boiteTaille.Z / 2
end

-- Camouflage : fondu de 0 (visible) à 1 (invisible) sur Config.DureeCamouflage secondes
local function alphaCamouflage()
	local duree = Config.DureeCamouflage or 2
	local ecoule = workspace:GetServerTimeNow() - (exterieur:GetAttribute("DebutCamouflage") or 0)
	local p = math.clamp(ecoule / duree, 0, 1)
	if exterieur:GetAttribute("Camouflage") then
		return p
	end
	return 1 - p
end

-- Préchargement des sons du TARDIS (sinon le premier son peut arriver en retard le temps de se charger)
task.spawn(function()
	local assets = ReplicatedStorage:FindFirstChild("TardisAssets")
	local sons = assets and assets:FindFirstChild("Sons")
	if sons then
		pcall(function()
			game:GetService("ContentProvider"):PreloadAsync(sons:GetChildren())
		end)
	end
end)

-- Démat / remat pendant le vol libre : même animation que pour un voyage, mais en plein vol
local function alphaVol()
	local phase = exterieur:GetAttribute("VolPhase")
	if phase == "Invisible" or exterieur:GetAttribute("Detruit") == true then return 1 end
	if phase == E.Demat or phase == E.Remat then
		local ecoule = workspace:GetServerTimeNow() - (exterieur:GetAttribute("VolPhaseDebut") or 0)
		return Config.Alpha(phase, ecoule, Config.modeVolDe(exterieur), UI.effetsReduits() or UI.sansFlash())
	end
	return 0
end

-- Respiration en cours (voyage ou phase de vol libre) : souffle 0..1, progression 0..1, fond 0..1, et l'état animé
local function respiration()
	local etat = exterieur:GetAttribute("Etat") or E.Pose
	if etat == E.Demat or etat == E.Remat then
		local ecoule = workspace:GetServerTimeNow() - (exterieur:GetAttribute("DebutEtat") or 0)
		local s, p, fond = Config.Souffle(etat, ecoule, Config.modeDe(exterieur))
		return s, p, fond, etat, Config.modeDe(exterieur)
	end
	local phase = exterieur:GetAttribute("VolPhase")
	if phase == E.Demat or phase == E.Remat then
		local ecoule = workspace:GetServerTimeNow() - (exterieur:GetAttribute("VolPhaseDebut") or 0)
		local s, p, fond = Config.Souffle(phase, ecoule, Config.modeVolDe(exterieur))
		return s, p, fond, phase, Config.modeVolDe(exterieur)
	end
	return 0, 0, 0, nil, nil
end

local alphaActuel = 0
local secousseActive = false
local dernierModeAnime = "Normal" -- mode de la dernière animation (le serveur le remet à Normal en posant le TARDIS)
local courseRotor = 0 -- hauteur actuelle du rotor (lissée)
local phaseRotor = 0       -- V6.9.10 : phase cumulée du rotor (il ne saute pas quand sa vitesse change)
local facteurRotorVol = 1  -- V6.9.10 : vitesse du rotor en vol libre (Config.facteurRotorVol), lissée
local dernierePositionCabine = nil -- V6.9.10 : pour mesurer la vitesse réelle de la cabine d'une image à l'autre
local choc = 0        -- secousse d'arrivée (atterrissage), décroît
local flashLampe = 0  -- éclat de la lampe au départ et à l'arrivée, décroît
local etatPrecedent = exterieur:GetAttribute("Etat") or E.Pose

-- Une erreur dans un effet est signalée une seule fois dans l'Output, sans bloquer les autres effets
local erreursSignalees = {}
local function proteger(nom, fonction, ...)
	local ok, erreur = pcall(fonction, ...)
	if not ok and not erreursSignalees[nom] then
		erreursSignalees[nom] = true
		warn("[TARDIS] Effet '" .. nom .. "' en erreur : " .. tostring(erreur))
	end
end

local alphaVitreActuel, alphaLampeActuel = 0, 0
-- Vitres en retard seulement quand leur lueur est préparée (pas en Silencieux, ni camouflé, ni porté : correction de relecture V6.9.9)
local vitresEnRetard = false
local function fondu(etat, ecoule, camouflage, mode)
	-- « Aucun flash » (V6.9.9) : la cabine s'efface sans grésillements, comme en « réduire les effets »
	local adouci = UI.effetsReduits() or UI.sansFlash()
	local alpha = math.max(Config.Alpha(etat, ecoule, mode, adouci), camouflage)
	-- Vitres (V6.9.9) : en démat, la même animation avec un retard qui grandit jusqu'à Config.Effets.RetardVitres
	local retard = (nombreVitres > 0 and etat == E.Demat and vitresEnRetard) and Config.retardVitres(etat, ecoule, mode) or 0
	local alphaVitre = retard > 0 and math.max(Config.Alpha(etat, ecoule - retard, mode, adouci), camouflage) or alpha
	-- (V7.2.1, G-9) En remat, la lampe a Config.Effets.AvanceLampe secondes d'avance sur le reste
	local alphaLampe = (etat == E.Remat and lampe) and math.max(Config.alphaLampe(etat, ecoule, mode, adouci), camouflage) or alpha
	if alpha ~= alphaActuel or alphaVitre ~= alphaVitreActuel or alphaLampe ~= alphaLampeActuel then
		alphaActuel, alphaVitreActuel, alphaLampeActuel = alpha, alphaVitre, alphaLampe
		for objet, fiche in visuels do
			if objet.Parent then
				local a = (fiche.lampe and alphaLampe) or (fiche.vitre and alphaVitre) or alpha
				for prop, origine in fiche.transparences do
					objet[prop] = origine + (1 - origine) * a
				end
				for prop, origine in fiche.luminosites do
					objet[prop] = origine * (1 - a)
				end
				for prop, origine in fiche.actifs do
					objet[prop] = origine and a < 0.5
				end
			end
		end
	end
end

--------------------------------------------------------------------
-- Vitres qui s'éteignent en dernier (V6.9.9) : à la fin de la démat, une copie lumineuse et chaude des vitres
-- s'allume à leur place, puis s'éteint pendant les premières secondes du Vol (Config.lueurVitres). C'est une copie
-- locale, figée là où était la cabine : le serveur l'emmène dans le ciel dès le début du Vol.
--------------------------------------------------------------------
local COULEUR_VITRES = Color3.fromRGB(255, 214, 140)
local lueurVitres = nil -- { modele, copies = { [copie] = { origine, decalage } }, lumiere, mode }
local function eteindreLueurVitres()
	if lueurVitres then
		lueurVitres.modele:Destroy()
		lueurVitres = nil
	end
end
-- (V7.2.1) Copie lumineuse des vitres, rangée hors de la cabine (aussi pour les fenêtres allumées la nuit, G-1).
-- mince : la copie est amincie pour rester derrière la vraie vitre (pas de scintillement quand les deux sont visibles)
local function copierVitres(nom, mince)
	if nombreVitres <= 0 then return nil end
	local pivot = exterieur:GetPivot()
	local modele = Instance.new("Model")
	modele.Name = nom
	local copies = {}
	for objet, fiche in visuels do
		local origine = fiche.transparences.Transparency
		if fiche.vitre and objet.Parent and origine and origine < 0.95 then
			local copie = objet:Clone()
			if copie then
				copie:ClearAllChildren()
				copie.Anchored, copie.CanCollide, copie.CanTouch, copie.CanQuery, copie.CastShadow = true, false, false, false, false
				copie.Material = Enum.Material.Neon
				copie.Color = COULEUR_VITRES
				if copie:IsA("UnionOperation") then copie.UsePartColor = true end
				if copie:IsA("MeshPart") then copie.TextureID = "" end
				if mince then
					local t = copie.Size
					local m = math.min(t.X, t.Y, t.Z)
					copie.Size = Vector3.new(t.X * (t.X == m and 0.5 or 0.98), t.Y * (t.Y == m and 0.5 or 0.98), t.Z * (t.Z == m and 0.5 or 0.98))
				end
				copie.Transparency = 1
				copie.Parent = modele
				copies[copie] = { origine = origine, decalage = pivot:ToObjectSpace(objet.CFrame) }
			end
		end
	end
	local support = Instance.new("Part")
	support.Name = "Lumiere"
	support.Anchored, support.CanCollide, support.CanTouch, support.CanQuery, support.CastShadow = true, false, false, false, false
	support.Transparency, support.Size, support.CFrame = 1, Vector3.one, pivot
	support.Parent = modele
	local taille = exterieur:GetExtentsSize()
	local lumiereVitres = Instance.new("PointLight")
	lumiereVitres.Color, lumiereVitres.Brightness, lumiereVitres.Range, lumiereVitres.Shadows = COULEUR_VITRES, 0, math.max(taille.X, taille.Z) * 1.6, false
	lumiereVitres.Parent = support
	modele.Parent = workspace
	return { modele = modele, copies = copies, lumiere = lumiereVitres, support = support }
end
local function preparerLueurVitres(mode)
	eteindreLueurVitres()
	if (tonumber(EFFETS.RetardVitres) or 0) <= 0 then return end
	lueurVitres = copierVitres("TardisLueurVitres_" .. def.Nom)
	if lueurVitres then lueurVitres.mode = mode end
end
-- Une image : la lueur suit la cabine pendant la démat, puis reste figée et s'éteint pendant le Vol
local function majLueurVitres(etat, ecoule, facteur)
	if not lueurVitres then return end
	if etat ~= E.Demat and etat ~= E.Vol then eteindreLueurVitres() return end -- démat interrompue, ou déjà posé
	local force = Config.lueurVitres(etat, ecoule, lueurVitres.mode)
	if etat == E.Vol and force <= 0 then eteindreLueurVitres() return end
	local pivot = etat == E.Demat and exterieur:GetPivot() or nil
	for copie, infos in lueurVitres.copies do
		if pivot then copie.CFrame = pivot * infos.decalage end
		copie.Transparency = 1 - (1 - math.max(infos.origine, 0.3)) * force
	end
	if pivot then lueurVitres.support.CFrame = pivot end
	lueurVitres.lumiere.Brightness = 2.5 * force * facteur
end

--------------------------------------------------------------------
-- Lueur de la cabine (V6.7) : à chaque souffle, la lumière fuit par les fenêtres et la lampe s'entoure d'un halo.
-- Deux pièces d'effet indépendantes du modèle (le fondu de l'extérieur ne les touche pas).
--------------------------------------------------------------------
local lueur, halo = nil, nil
if EFFETS.Lueur ~= false then
	lueur = piece({ Name = "TardisLueur_" .. def.Nom, Transparency = 1, Size = Vector3.one, CFrame = exterieur:GetPivot() })
	local lumiereLueur = Instance.new("PointLight")
	lumiereLueur.Name = "Lumiere"
	lumiereLueur.Brightness, lumiereLueur.Range, lumiereLueur.Shadows = 0, 12, false
	lumiereLueur.Parent = lueur
	halo = piece({ Name = "TardisHalo_" .. def.Nom, Shape = Enum.PartType.Ball, Transparency = 1, Size = Vector3.one, Color = couleurLampe })
end

--------------------------------------------------------------------
-- Cabine vivante (V7.2.1) : la cabine raconte l'état du TARDIS. Fenêtres allumées la nuit (G-1), vitres sombres hors
-- tension (G-3) et teintées par l'état de la salle (G-6), panneau de maintenance (G-66), frémissement du silence du
-- départ (G-10), contour qui bat pendant la remat (G-13), ombres des croisillons de près la nuit (G-14), reflet du
-- soleil le jour (G-99). Tout est local, et rien n'est rangé dans la cabine (le fondu le prendrait pour une de ses pièces).
--------------------------------------------------------------------
local COULEUR_MAINTENANCE = Color3.fromRGB(255, 170, 40)
local fenetresNuit = nil  -- (G-1) copie lumineuse des vitres : { modele, copies, lumiere, support, pivot, force }
local panneau, panneauPivot = nil, nil -- (G-66) panneau « HORS SERVICE » posé sur la porte
local contour = nil       -- (G-13) Highlight de la remat (contour seulement)
local tremblement = nil   -- (G-10) décalage local de la cabine pendant le frémissement
local dernierReflet, prochainTestReflet = -math.huge, 0 -- (G-99)
local function procheCouleur(a, b)
	return math.abs(a.R - b.R) < 0.003 and math.abs(a.G - b.G) < 0.003 and math.abs(a.B - b.B) < 0.003
end

-- G-1 : fenêtres allumées la nuit (copie mince derrière les vraies vitres, qui suit la cabine)
local function majFenetresNuit(force)
	if force <= 0.01 then
		if fenetresNuit then fenetresNuit.modele:Destroy() fenetresNuit = nil end
		return
	end
	if not fenetresNuit then
		fenetresNuit = copierVitres("TardisFenetresNuit_" .. def.Nom, true)
		if not fenetresNuit then return end
	end
	local pivot = exterieur:GetPivot()
	if fenetresNuit.pivot == pivot and fenetresNuit.force == force then return end -- rien n'a changé
	fenetresNuit.pivot, fenetresNuit.force = pivot, force
	for copie, infos in fenetresNuit.copies do
		copie.CFrame = pivot * infos.decalage
		copie.Transparency = 1 - (1 - math.max(infos.origine, 0.3)) * force
	end
	fenetresNuit.support.CFrame = pivot
	fenetresNuit.lumiere.Brightness = 0.9 * force
end

-- G-3 et G-6 : couleur des vraies vitres (couleur de l'état de la salle, sombre hors tension), en douceur.
-- Si un autre script change la couleur d'une vitre (reflets du Decor, thème), elle devient sa nouvelle couleur d'origine.
local function majCouleursVitres(nomEtat, alimente, lissage)
	for objet, fiche in visuels do
		if fiche.vitre and objet.Parent and objet:IsA("BasePart") then
			local actuelle = objet.Color
			if not fiche.couleurEcrite or not procheCouleur(actuelle, fiche.couleurEcrite) then fiche.couleurBase = actuelle end
			local cible = Config.couleurVitre(fiche.couleurBase, nomEtat, alimente)
			if not procheCouleur(actuelle, cible) then
				objet.Color = actuelle:Lerp(cible, lissage)
			elseif actuelle ~= cible then
				objet.Color = cible
			end
			fiche.couleurEcrite = objet.Color
		end
	end
end

-- G-66 : panneau « HORS SERVICE » sur la porte pendant la maintenance
local function majPanneau(actif, visible)
	if not actif then
		if panneau then panneau:Destroy() panneau, panneauPivot = nil, nil end
		return
	end
	local portes = exterieur:FindFirstChild(Config.NomDossierPortes)
	if not portes then return end
	if not panneau then
		panneau = piece({ Name = "TardisPanneau_" .. def.Nom, Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(245, 240, 225), Transparency = 1 })
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Ecran"
		gui.Face = Enum.NormalId.Front
		gui.LightInfluence = 0.3
		gui.Parent = panneau
		local texte = Instance.new("TextLabel")
		texte.Name = "Texte"
		texte.BackgroundTransparency = 1
		texte.Size = UDim2.fromScale(1, 1)
		texte.TextScaled = true
		texte.Font = Enum.Font.GothamBold
		texte.TextColor3 = Color3.fromRGB(170, 30, 20)
		texte.Text = "HORS SERVICE"
		texte.Parent = gui
	end
	local pivot = exterieur:GetPivot()
	if pivot ~= panneauPivot then
		panneauPivot = pivot
		local cadre, taille
		if portes:IsA("Model") then cadre, taille = portes:GetBoundingBox()
		elseif portes:IsA("BasePart") then cadre, taille = portes.CFrame, portes.Size
		else return end
		-- Le panneau se pose sur la face des portes tournée vers l'extérieur de la cabine
		local dehors = cadre.Position - pivot.Position
		dehors = Vector3.new(dehors.X, 0, dehors.Z)
		if dehors.Magnitude < 0.05 then dehors = pivot.LookVector end
		dehors = dehors.Unit
		local versPortes = cadre:VectorToObjectSpace(dehors)
		local profondeur = math.abs(versPortes.X) * taille.X + math.abs(versPortes.Y) * taille.Y + math.abs(versPortes.Z) * taille.Z
		local e = echelle()
		local position = cadre.Position + dehors * (profondeur / 2 + 0.04 * e) + Vector3.new(0, taille.Y * 0.1, 0)
		panneau.Size = Vector3.new(2.2, 0.7, 0.05) * e
		panneau.CFrame = CFrame.lookAt(position, position + dehors)
	end
	local transparence = 1 - math.clamp(visible, 0, 1)
	if panneau.Transparency ~= transparence then panneau.Transparency = transparence end
	panneau.Ecran.Enabled = visible > 0.5
end

-- G-13 : contour de la cabine qui bat pendant la remat (Highlight rangé dans le Workspace, pas dans la cabine)
local function majContour(force, couleur)
	if force <= 0.01 then
		if contour then contour:Destroy() contour = nil end
		return
	end
	if not contour then
		contour = Instance.new("Highlight")
		contour.Name = "TardisContour_" .. def.Nom
		contour.FillTransparency = 1
		contour.DepthMode = Enum.HighlightDepthMode.Occluded
		contour.Adornee = exterieur
		contour.Parent = workspace
	end
	contour.OutlineColor = couleur
	contour.OutlineTransparency = 1 - force
end

-- G-10 : frémissement de la cabine pendant le silence du départ (décalage local, retiré à la fin du silence)
local function majFremissement(force, t)
	local amplitude = math.max(tonumber(EFFETS.Fremissement) or 0, 0) * echelle()
	local porte = exterieur:GetAttribute("Porteur") ~= nil or exterieur:GetAttribute("VolLibre") ~= nil
	local cible = nil
	if force > 0.001 and amplitude > 0 and not porte then
		cible = CFrame.new(math.noise(t * 23, 1.7) * amplitude * force, math.noise(t * 19, 5.3) * amplitude * 0.4 * force,
			math.noise(t * 29, 9.1) * amplitude * force)
	end
	if cible == nil and tremblement == nil then return end
	local pivot = exterieur:GetPivot()
	if tremblement then pivot = pivot * tremblement:Inverse() end -- le décalage précédent est retiré
	tremblement = cible
	exterieur:PivotTo(cible and pivot * cible or pivot)
end

-- G-14 : la lueur projette les croisillons des fenêtres au sol, de près et la nuit (pas en « effets réduits »)
local function majOmbres(nuit, reduit)
	local lumiereLueur = lueur and lueur:FindFirstChild("Lumiere")
	if not lumiereLueur then return end
	local distance = tonumber(EFFETS.OmbresFenetres) or 0
	local camera = workspace.CurrentCamera
	local ombres = false
	if distance > 0 and not reduit and nuit > 0.5 and camera then
		ombres = (camera.CFrame.Position - exterieur:GetPivot().Position).Magnitude < distance * echelle()
	end
	if lumiereLueur.Shadows ~= ombres then lumiereLueur.Shadows = ombres end
end

-- G-99 : le jour, un éclat bref quand le reflet du soleil sur une vitre arrive dans l'œil (au plus un toutes les 6 s)
local function majReflet(t, nuit, visible)
	if t < prochainTestReflet then return end
	prochainTestReflet = t + 0.25
	if nuit > 0.2 or visible < 0.9 or t - dernierReflet < 6 or nombreVitres <= 0 then return end
	local camera = workspace.CurrentCamera
	if not camera then return end
	local oeil = camera.CFrame.Position
	local pivot = exterieur:GetPivot()
	if (oeil - pivot.Position).Magnitude > 250 then return end
	local soleil = Lighting:GetSunDirection()
	for objet, fiche in visuels do
		if fiche.vitre and objet.Parent and objet:IsA("BasePart") and objet.Transparency < 0.9 then
			local taille, cadre = objet.Size, objet.CFrame
			local normale = (taille.X <= taille.Y and taille.X <= taille.Z) and cadre.RightVector or (taille.Y <= taille.Z and cadre.UpVector or cadre.LookVector)
			if normale:Dot(objet.Position - pivot.Position) < 0 then normale = -normale end
			if Config.refletSoleil(soleil, normale, oeil - objet.Position) > 0.995 then
				dernierReflet = t
				local e = echelle()
				local eclat = piece({ Name = "TardisReflet_" .. def.Nom, Shape = Enum.PartType.Ball, Color = Color3.new(1, 1, 0.92),
					Transparency = 0.1, Size = Vector3.one * 0.4 * e, CFrame = CFrame.new(objet.Position + normale * 0.1) })
				tween(eclat, 0.35, { Size = Vector3.one * 1.4 * e, Transparency = 1 })
				Debris:AddItem(eclat, 0.5)
				return
			end
		end
	end
end

RunService.RenderStepped:Connect(function(dt)
	local etat = exterieur:GetAttribute("Etat") or E.Pose
	local ecoule = workspace:GetServerTimeNow() - (exterieur:GetAttribute("DebutEtat") or 0)
	local t = os.clock()
	local reduit = UI.effetsReduits()
	local sansFlash = UI.sansFlash() -- « aucun flash » (V6.9.9)
	-- Lueurs du voyage selon l'heure du jeu (V6.9.9) : plus fortes la nuit, plus discrètes le jour
	local facteurHeure = Config.facteurHeure(Lighting.ClockTime)

	-- 0) Changement d'état : départ (la cabine vient de disparaître) et arrivée (elle vient de se poser)
	-- (Silencieux, V6.9 : aucun éclat ; le serveur remet Mode à Normal en posant le TARDIS, d'où dernierModeAnime)
	local modeDiscret = (Config.Modes[dernierModeAnime] or {}).Discret == true
	if etat ~= etatPrecedent then
		if etat == E.Demat then
			-- Vitres (V6.9.9) : leur lueur est préparée au départ (pas en Silencieux, ni camouflé, ni porté)
			local modeDepart = Config.modeDe(exterieur)
			vitresEnRetard = not (Config.Modes[modeDepart] or {}).Discret and exterieur:GetAttribute("Camouflage") ~= true and not exterieur:GetAttribute("Porteur")
			if vitresEnRetard then
				proteger("vitres", preparerLueurVitres, modeDepart)
			end
		elseif etat == E.Vol and etatPrecedent == E.Demat then
			if not modeDiscret and not sansFlash then flashLampe = 1 end
		elseif etat == E.Pose and etatPrecedent == E.Remat then
			if not modeDiscret and not sansFlash then flashLampe = 1 end
			if EFFETS.Choc ~= false then
				local racine = joueur.Character and joueur.Character:FindFirstChild("HumanoidRootPart")
				if racine and dansInterieur(racine.Position) then
					local stabilise = exterieur:GetAttribute("Stabilisateur") ~= false
					local modeArrivee = Config.modeDe(exterieur)
					local force = (modeArrivee == "Catastrophe" and 2.2) or (Config.modeSaccade(modeArrivee) and 1.5) or (modeArrivee == "Sauvetage" and 0.7) or 1
					choc = force * (stabilise and 0.45 or 1) * (reduit and 0.4 or 1)
				end
			end
		end
		etatPrecedent = etat
	end
	flashLampe = math.max(0, flashLampe - dt * 1.8)

	-- 1) Fondu de l'extérieur (le plus invisible des deux : voyage ou camouflage)
	local camouflage = 0
	proteger("camouflage", function()
		-- Le camouflage et la démat en vol rendent tous les deux le TARDIS invisible : on garde le plus fort
		camouflage = math.max(alphaCamouflage(), alphaVol())
	end)
	local mode = Config.modeDe(exterieur)
	local urgence = Config.modeSaccade(mode) -- urgence ou catastrophe : animation contrariée
	-- Vortex temporel : pendant le vol, le TARDIS est visible dans le ciel (le vortex est dessiné par TardisVolLibre)
	local etatFondu = (etat == E.Vol and exterieur:GetAttribute("Ciel") == true) and E.Pose or etat
	proteger("fondu", fondu, etatFondu, ecoule, camouflage, mode)
	if lueurVitres then proteger("vitres", majLueurVitres, etat, ecoule, facteurHeure) end

	-- Respiration : le souffle en cours (voyage ou phase de vol libre), lu une fois par image
	local souffle, progression, fond, etatAnime, modeAnime = 0, 0, 0, nil, nil
	proteger("souffle", function() souffle, progression, fond, etatAnime, modeAnime = respiration() end)
	local enVoyage = etatAnime ~= nil
	if modeAnime then dernierModeAnime = modeAnime end
	local discret = enVoyage and (Config.Modes[modeAnime] or {}).Discret == true -- Silencieux : ni lumière ni effet dehors
	local camoufle = exterieur:GetAttribute("Camouflage") == true
	local visible = (1 - alphaActuel) * (1 - camouflage)
	-- (V7.2.1, G-10) Silence du départ : la cabine frémit, la lampe s'allume faiblement
	local fremissement = (not discret and not camoufle) and Config.fremissement(etat, ecoule, mode) or 0

	-- 2) Lampe du toit : elle bat au rythme des souffles, vacille en urgence, éclate au départ et à l'arrivée
	if lumiere then
		local brillance = brillanceBase
		if etat ~= E.Pose or enVoyage then
			if (urgence or Config.modeSaccade(modeAnime)) and not sansFlash then
				-- Urgence : la lampe vacille et coupe de façon irrégulière (pas avec « aucun flash » : elle respire)
				brillance *= (Config.Bruit(ecoule, 15) < 0.35) and 0.05 or (0.5 + 0.5 * Config.Bruit(ecoule + 1.3, 9)) * (0.7 + 0.8 * souffle)
			elseif enVoyage then
				brillance *= 0.3 + 1.6 * souffle -- un éclat à chaque souffle
			else
				brillance *= 0.5 + 0.5 * math.sin(t * Config.VitesseLampe)
			end
			if fremissement > 0 then brillance *= 1 + 1.5 * fremissement * (0.7 + 0.3 * math.sin(t * 9)) end -- (V7.2.1, G-10)
			brillance *= facteurHeure -- V6.9.9 : plus vive la nuit, plus discrète le jour
		end
		brillance += brillanceBase * 2.5 * flashLampe * facteurHeure
		if discret then brillance = 0 end -- Silencieux : la lampe reste éteinte
		if exterieur:GetAttribute("Alimentation") == false then
			brillance = 0 -- plus de courant
		end
		lumiere.Brightness = brillance * (1 - camouflage) -- éteinte quand le TARDIS est camouflé
		lumiere.Range = porteeBase * echelle() * (1 + 0.6 * souffle + flashLampe) -- (G-79) ScaleTo réduit la portée, on la garde réduite
		-- Alerte : la lampe du toit passe au rouge
		lumiere.Color = exterieur:GetAttribute("Alerte") and (Config.CouleurAlerte or Color3.fromRGB(255, 30, 30)) or couleurLampe
		-- (V7.2.1, G-66) Maintenance : lampe fixe et ambrée (l'alerte garde le rouge)
		if EFFETS.PanneauMaintenance ~= false and exterieur:GetAttribute("Maintenance") and not exterieur:GetAttribute("Alerte") then
			lumiere.Color = COULEUR_MAINTENANCE
		end
	end

	-- 2 bis) Lueur de la cabine et halo de la lampe
	if lueur then
		proteger("lueur", function()
			local alimente = exterieur:GetAttribute("Alimentation") ~= false
			local intensite = (enVoyage and alimente and not discret) and souffle * visible or 0
			-- Couleur du mode dehors (le Rapide garde sa couleur pour l'intérieur : lumière neutre ici)
			local couleur = Color3.fromRGB(255, 240, 210):Lerp(Config.couleurDehors(modeAnime or mode), 0.45)
			local pivot = exterieur:GetPivot()
			local taille = exterieur:GetExtentsSize()
			lueur.CFrame = pivot
			lueur.Lumiere.Brightness = (3.2 * intensite + 2 * flashLampe * (1 - camouflage)) * facteurHeure
			lueur.Lumiere.Range = math.max(taille.X, taille.Z) * 1.8 + 6 * souffle
			lueur.Lumiere.Color = couleur
			-- Halo : une sphère de lumière autour de la lampe, qui gonfle à chaque souffle
			local haloIntensite = math.max(intensite, flashLampe * (1 - camouflage) * (alimente and 1 or 0))
			if haloIntensite > 0.01 then
				halo.CFrame = CFrame.new(positionLampe())
				halo.Size = Vector3.one * (0.9 + 2.2 * haloIntensite)
				halo.Color = (exterieur:GetAttribute("Alerte") and (Config.CouleurAlerte or Color3.fromRGB(255, 30, 30)) or couleurLampe):Lerp(Color3.new(1, 1, 1), 0.5)
				halo.Transparency = 1 - math.clamp(0.55 * haloIntensite * facteurHeure, 0, 0.9)
			else
				halo.Transparency = 1
			end
		end)
	end

	-- 2 quater) Cabine vivante (V7.2.1)
	local nuit = Config.nuitDe(Lighting.ClockTime)
	local alimente = exterieur:GetAttribute("Alimentation") ~= false
	proteger("fenetres", function()
		local pose = etat == E.Pose and not enVoyage and exterieur:GetAttribute("VolLibre") == nil
		majFenetresNuit(Config.fenetresNuit(Lighting.ClockTime, pose and E.Pose or E.Vol, alimente, visible, camoufle))
	end)
	proteger("couleurVitres", function()
		local nomEtat = Config.etatSalle(etat, exterieur:GetAttribute("VolPhase"), exterieur:GetAttribute("VolLibre") ~= nil,
			exterieur:GetAttribute("VolVortex") == true, exterieur:GetAttribute("Alerte") == true)
		majCouleursVitres(nomEtat, alimente, math.clamp(dt * 3, 0, 1))
	end)
	if EFFETS.PanneauMaintenance ~= false then
		proteger("panneau", majPanneau, exterieur:GetAttribute("Maintenance") ~= nil and etat == E.Pose, visible)
	end
	if EFFETS.ContourRemat ~= false then
		proteger("contour", function()
			local force = 0
			if etatAnime == E.Remat and not discret and not camoufle then
				force = math.clamp(0.8 * souffle * (1 - 0.5 * visible), 0, 0.85) * (reduit and 0.5 or 1)
			end
			majContour(force, Config.couleurDehors(modeAnime or mode))
		end)
	end
	proteger("fremissement", majFremissement, fremissement, t)
	proteger("ombres", majOmbres, nuit, reduit)
	if EFFETS.RefletSoleil ~= false and not sansFlash then
		proteger("reflet", majReflet, t, nuit, visible)
	end

	-- 2 ter) Ambiance pour le joueur qui se trouve dans l'intérieur
	proteger("ambiance", function()
		local personnage = joueur.Character
		local racineJoueur = personnage and personnage:FindFirstChild("HumanoidRootPart")
		local dedans = racineJoueur ~= nil and dansInterieur(racineJoueur.Position)
		local horsTension = exterieur:GetAttribute("Alimentation") == false
		local alerte = exterieur:GetAttribute("Alerte") == true

		local lissage = math.clamp(dt * 3, 0, 1)
		local cibleNoir = (dedans and horsTension) and 1 or 0
		local cibleRouge = (dedans and alerte) and 1 or 0
		noirActuel += (cibleNoir - noirActuel) * lissage
		rougeActuel += (cibleRouge - rougeActuel) * lissage

		-- Thème de l'intérieur (menu) : ambiance lumineuse de la salle, seulement quand on y est, avec du courant
		local theme = themeChoisi()
		local cibleTheme = (dedans and not horsTension and theme) and 1 or 0
		themeActuel += (cibleTheme - themeActuel) * lissage
		local ambiance, exterieure, exposition = ambianceOrigine, exterieureOrigine, 0
		if theme then
			ambiance, exterieure, exposition = theme.ambiance, theme.exterieur, theme.exposition or 0
			if reduit then exposition = math.min(exposition, 0.6) end -- Flashbang : beaucoup moins éblouissant
			if sansFlash then exposition = math.min(exposition, 0) end -- « aucun flash » : exposition normale
			if theme.festive then
				-- Festive : les couleurs tournent
				local teinteFestive = Color3.fromHSV((t * 0.08) % 1, 0.8, 0.9)
				ambiance, exterieure = teinteFestive, teinteFestive:Lerp(Color3.new(0, 0, 0), 0.4)
			end
		end
		Lighting.Ambient = ambianceOrigine:Lerp(ambiance, themeActuel)
		Lighting.OutdoorAmbient = exterieureOrigine:Lerp(exterieure, themeActuel)
		local leds = interieur:FindFirstChild(Config.NomLedsAlerte or "LedsAlerte")
		if leds and not alerte then
			local couleurLeds = theme and theme.leds
			if theme and theme.festive then couleurLeds = Color3.fromHSV((t * 0.08 + 0.5) % 1, 0.9, 1) end
			for _, objet in leds:GetDescendants() do
				if objet:IsA("Light") then
					ledsOrigine[objet] = ledsOrigine[objet] or objet.Color
					objet.Color = couleurLeds and ledsOrigine[objet]:Lerp(couleurLeds, themeActuel) or ledsOrigine[objet]
				end
			end
		end

		-- Courant coupé : l'image s'assombrit fortement
		-- (trois exemplaires tournent, un par TARDIS : seul celui qui a quelque chose à assombrir écrit l'exposition)
		if noirActuel > 0.002 or themeActuel > 0.002 then
			Lighting.ExposureCompensation = expositionOrigine - 3 * noirActuel + exposition * themeActuel
			expositionEcrite = true
		elseif expositionEcrite then
			Lighting.ExposureCompensation = expositionOrigine
			expositionEcrite = false
		end
		-- Alerte : teinte rouge qui pulse doucement (comme une alarme)
		local pulsation = 0.75 + 0.25 * math.sin(t * 4)
		local intensite = rougeActuel * pulsation
		-- Contre-jour (V6.7) : à bord, chaque souffle éclaire doucement l'image (la salle respire avec le moteur)
		local contrejour = 0
		if EFFETS.Contrejour ~= false and dedans and enVoyage and not horsTension and not sansFlash then
			contrejour = (discret and 0 or souffle * (reduit and 0.02 or 0.07)) + choc * 0.05
		end
		teinte.TintColor = Color3.new(1, 1 - 0.45 * intensite, 1 - 0.45 * intensite)
		teinte.Saturation = -0.2 * noirActuel
		teinte.Brightness = -0.05 * intensite + contrejour
	end)

	-- 3) Rotor de la console : il pompe pendant le voyage, s'arrête en douceur une fois posé
	-- (il accélère un instant quand on clique dessus : rotor interactif)
	proteger("rotor", function()
		local boost = exterieur:GetAttribute("RotorBoost")
		local boostActif = boost ~= nil and workspace:GetServerTimeNow() - boost < 3
		local actif = etat ~= E.Pose or boostActif or exterieur:GetAttribute("VolLibre") ~= nil
		-- Vol libre (V6.9.10) : le rotor suit la vitesse réelle de la cabine (chez le pilote comme chez ceux qui la suivent)
		local voulu = 1
		if exterieur:GetAttribute("VolLibre") ~= nil then
			local position = exterieur:GetPivot().Position
			if dernierePositionCabine and dt > 0 then
				voulu = Config.facteurRotorVol((position - dernierePositionCabine).Magnitude / dt,
					exterieur:GetAttribute("VolVortex") == true, exterieur:GetAttribute("VolUrgence") == true)
			end
			dernierePositionCabine = position
		else
			dernierePositionCabine = nil
		end
		facteurRotorVol += (voulu - facteurRotorVol) * math.min(dt * ((Config.RotorVolLibre or {}).Lissage or 2), 1)
		local vitesse = Config.VitesseRotor * (boostActif and 3 or 1) * facteurRotorVol
		phaseRotor = (phaseRotor + dt * vitesse) % (2 * math.pi)
		local amplitude = Config.AmplitudeRotor * ((etat == E.Pose and not boostActif) and 0.5 or 1)
		-- Atterrissage : la course se réduit pendant les 2 dernières secondes, pour s'arrêter sans à-coup
		if etat == E.Remat then
			local duree, decalage = Config.Timing(E.Remat, mode)
			amplitude *= math.clamp((duree + decalage - ecoule) / 2, 0.1, 1)
		end
		local cible = actif and math.sin(phaseRotor) * amplitude or 0
		courseRotor += (cible - courseRotor) * math.min(dt * (actif and 12 or 4), 1)
		if math.abs(courseRotor) < 0.002 and not actif then courseRotor = 0 end
		local voulu = rotorBase * CFrame.new(0, courseRotor, 0)
		if rotor:GetPivot() ~= voulu then rotor:PivotTo(voulu) end
	end)

	-- 3 ter) Couleur du rotor selon le mode (sauf hors tension et en alerte, qui ont leurs propres couleurs)
	proteger("couleurRotor", function()
		local actif = etat ~= E.Pose and exterieur:GetAttribute("Alimentation") ~= false and exterieur:GetAttribute("Alerte") ~= true
		if actif then couleurRotor = Config.Modes[Config.modeDe(exterieur)].CouleurRotor or couleurRotor end
		local avant = melangeRotor
		melangeRotor += ((actif and 1 or 0) - melangeRotor) * math.min(dt * 2, 1)
		if melangeRotor < 0.002 then melangeRotor = 0 end
		if melangeRotor == 0 and avant == 0 then return end
		-- Les néons battent au rythme des souffles
		local battement = 1 - 0.35 * souffle * melangeRotor
		for part, origine in neonsRotor do
			part.Color = origine:Lerp(couleurRotor:Lerp(Color3.new(1, 1, 1), 0.25 * souffle), melangeRotor * battement)
		end
	end)

	-- 3 bis) Lumières de la salle : secours hors tension, pièces vides éteintes, pénombre après 5 min,
	-- nuit automatique, et respiration avec le moteur en voyage (les LEDs d'alerte restent gérées par le thème)
	proteger("lumieres", function()
		local horsTension = exterieur:GetAttribute("Alimentation") == false
		local activite = exterieur:GetAttribute("ActivitePilote")
		local tabletteOuverte = joueur:GetAttribute("TardisTablette") == true
		local inactif = not tabletteOuverte and activite ~= nil and workspace:GetServerTimeNow() - activite > 5 * 60
		local heure = Lighting.ClockTime
		local nuit = heure < 6 or heure > 18.5
		local enVol = etat ~= E.Pose
		-- En démat / remat : chaque souffle fait monter puis redescendre la lumière ; dans le vortex : respiration lente
		local pulsation = enVoyage and (0.5 + 0.5 * souffle) or (0.7 + 0.3 * (0.5 + 0.5 * math.sin(t * Config.VitesseRotor)))
		-- Positions des joueurs (une seule fois par image)
		local racines = {}
		for _, autre in Players:GetPlayers() do
			local r = autre.Character and autre.Character:FindFirstChild("HumanoidRootPart")
			if r then table.insert(racines, r.Position) end
		end
		-- Couleur de l'état (V6.9.9) : bleu posé, ambre en voyage, cyan dans le vortex, rouge en alerte (Config.CouleursSalle)
		local nomEtatSalle = Config.etatSalle(etat, exterieur:GetAttribute("VolPhase"), exterieur:GetAttribute("VolLibre") ~= nil,
			exterieur:GetAttribute("VolVortex") == true, exterieur:GetAttribute("Alerte") == true)
		local cibleCouleurSalle, cibleForceSalle = Config.teinteSalle(nomEtatSalle)
		local lissageSalle = math.min(dt * 1.5, 1)
		if cibleCouleurSalle then
			couleurEtatSalle = couleurEtatSalle and couleurEtatSalle:Lerp(cibleCouleurSalle, lissageSalle) or cibleCouleurSalle
		end
		forceEtatSalle += ((cibleCouleurSalle and cibleForceSalle or 0) - forceEtatSalle) * lissageSalle
		if forceEtatSalle < 0.002 and not cibleCouleurSalle then forceEtatSalle = 0 end
		lisserNeons(dt, horsTension, cibleCouleurSalle) -- V6.9.10.1 : néons de la salle
		-- Trois exemplaires tournent (un par TARDIS) : on ne travaille que si la caméra est près de cette salle
		if (workspace.CurrentCamera.CFrame.Position - Config.pivot(interieur).Position).Magnitude > 350 then return end
		peindreNeons()
		if not listeLumieres then
			listeLumieres = {}
			for _, objet in interieur:GetDescendants() do
				if objet:IsA("Light") then table.insert(listeLumieres, objet) end
			end
			interieur.DescendantAdded:Connect(function(objet) if objet:IsA("Light") then table.insert(listeLumieres, objet) end end)
		end
		local dossierLeds = interieur:FindFirstChild(Config.NomLedsAlerte or "LedsAlerte")
		for _, objet in listeLumieres do
			if objet.Parent then
				local infos = lumieresSalle[objet]
				if not infos then
					infos = { brillance = objet.Brightness, couleur = objet.Color, facteur = 1, rotor = objet:IsDescendantOf(rotor) }
					lumieresSalle[objet] = infos
				end
				local part = objet.Parent:IsA("Attachment") and objet.Parent.Parent or objet.Parent
				local cible, couleur = 1, infos.couleur
				if horsTension then
					-- Lumière de secours : rouge, qui s'éteint et se rallume lentement
					cible = 0.25 * (0.5 + 0.5 * math.sin(t * 1.1))
					couleur = Color3.fromRGB(255, 40, 40)
				else
					-- Pièce vide : éteinte (personne à moins de 28 studs de la lampe)
					local quelquUn = false
					if part and part:IsA("BasePart") then
						for _, position in racines do
							if (position - part.Position).Magnitude < 28 then quelquUn = true break end
						end
					end
					if not quelquUn then cible = 0
					elseif inactif then cible = 0.35 -- pénombre
					elseif nuit then cible = 0.7 end -- nuit automatique
					if nuit and cible > 0 then couleur = couleur:Lerp(Color3.fromRGB(255, 200, 140), 0.35) end
					if enVol or enVoyage then cible *= pulsation end
					-- Régulation de l'énergie (tablette technicien, V6.7.2) : en sous-tension, la salle baisse
					local tension = exterieur:GetAttribute("RegulEnergie")
					if tension then cible *= 0.3 + 0.7 * math.clamp(tension / math.max((Config.Technicien or {}).SousTension or 20, 1) * 0.5, 0, 1) end
					-- Choc d'atterrissage : la lumière vacille
					-- (« aucun flash », V6.9.9 : une simple baisse, sans vacillement à 20 Hz)
					if choc > 0 then
						if UI.sansFlash() then cible *= 1 - 0.25 * math.min(choc, 1) else cible *= 1 - 0.5 * choc * Config.Bruit(t, 20) end
					end
					-- Lumières du rotor : couleur du mode du voyage
					if melangeRotor > 0 and infos.rotor then couleur = couleur:Lerp(couleurRotor, 0.85 * melangeRotor) end
					-- Couleur de l'état de la salle (V6.9.9) : pas sur les lumières du rotor (ni sur les LedsAlerte, non recolorées)
					if couleurEtatSalle and forceEtatSalle > 0.002 and not infos.rotor then couleur = couleur:Lerp(couleurEtatSalle, forceEtatSalle) end
				end
				-- Les souffles se suivent vite : la lumière les suit de près ; le reste change en douceur
				infos.facteur += (cible - infos.facteur) * math.min(dt * (enVoyage and 8 or 2), 1)
				objet.Brightness = infos.brillance * infos.facteur
				if not (dossierLeds and objet:IsDescendantOf(dossierLeds)) then
					objet.Color = couleur
				end
			end
		end
	end)

	-- 4) Secousses de caméra pendant le décollage et l'atterrissage, et choc d'arrivée
	local personnage = joueur.Character
	local humanoid = personnage and personnage:FindFirstChildOfClass("Humanoid")
	local racine = personnage and personnage:FindFirstChild("HumanoidRootPart")
	if humanoid and racine then
		-- Les secousses commencent en même temps que l'animation (après le silence du début du son)
		local _, decalage = Config.Timing(etat, Config.modeDe(exterieur))
		-- Stabilisateur actif : aucune secousse en voyage normal ; en urgence, il n'en absorbe qu'une partie
		local stabilise = exterieur:GetAttribute("Stabilisateur") ~= false
		local dedans = dansInterieur(racine.Position)
		local secouer = (etat == E.Demat or etat == E.Remat) and ecoule >= decalage and dedans
			and not (stabilise and not urgence)
		local offset = Vector3.zero
		if secouer then
			local f = Config.ForceSecousse * (urgence and 2.5 or 1) -- urgence : ça secoue beaucoup plus
			if stabilise then f *= 0.05 end -- urgence avec stabilisateur : à peine une vibration (5 %)
			-- Sièges d'équipage : assis, on est bien moins secoué
			if humanoid.Sit and humanoid.SeatPart and string.sub(humanoid.SeatPart.Name, 1, 13) == "SiegeEquipage" then f *= 0.3 end
			if reduit then f *= 0.3 end
			-- Chaque souffle secoue plus fort que le creux qui le suit
			f *= 0.4 + 0.6 * souffle
			offset = Vector3.new((math.random() - 0.5) * f, (math.random() - 0.5) * f, (math.random() - 0.5) * f)
		end
		-- Choc d'atterrissage : un à-coup vers le bas qui s'amortit en une demi-seconde
		if choc > 0 then
			if dedans then
				offset += Vector3.new((math.random() - 0.5) * 0.5 * choc, -0.55 * choc * (0.5 + 0.5 * math.cos(choc * 6)), (math.random() - 0.5) * 0.5 * choc)
			end
			choc = math.max(0, choc - dt * 2.2)
		end
		if offset ~= Vector3.zero then
			humanoid.CameraOffset = offset
			secousseActive = true
		elseif secousseActive then
			humanoid.CameraOffset = Vector3.zero
			secousseActive = false
		end
	else
		choc = math.max(0, choc - dt * 2.2)
	end
end)

--------------------------------------------------------------------
-- Atterrissage sur l'eau : le TARDIS flotte et tangue doucement.
-- Tourbillon de matérialisation (V6.7) : près du sol, la poussière (ou l'eau) tourbillonne autour de la cabine,
-- avec une rafale à chaque souffle ; une onde court au sol à chaque souffle ; urgence : arcs électriques ;
-- arrivée : bouffée de poussière.
--------------------------------------------------------------------
do
	local flottait = false
	local souffleSol = nil -- { part, emetteurs, eau, couleur }
	local dernierSouffle = 0
	local etatSol = nil    -- état animé à l'image précédente (pour l'arrivée)
	local arcsPart = nil   -- étincelles de la lampe en urgence
	local modeSol = "Normal" -- mode de la dernière animation (pour l'arrivée)
	local derniereRide = 0   -- (V7.2.3, G-25) heure de la dernière ride autour de la cabine qui flotte
	local vapeur = nil       -- (V7.2.3, G-27) vapeur qui monte de l'eau pendant la remat

	local function exclusionsSol()
		local liste = { exterieur, interieur }
		for _, autre in Players:GetPlayers() do
			if autre.Character then table.insert(liste, autre.Character) end
		end
		return liste
	end

	local function arreterSouffle()
		if not souffleSol then return end
		local ancien = souffleSol
		souffleSol = nil
		for _, emetteur in ancien.emetteurs do emetteur.Enabled = false end
		task.delay(2.5, function() ancien.part:Destroy() end)
	end

	-- (V7.2.3, G-27) Vapeur au-dessus de l'eau : une bouffée à chaque souffle de la remat, dissipée après l'arrivée
	local function bouffeeVapeur(position, intensite)
		if EFFETS.VapeurEau == false then return end
		local e = echelle()
		if not vapeur or not vapeur.Parent then
			local taille = exterieur:GetExtentsSize()
			vapeur = piece({ Name = "TardisVapeurEau", Transparency = 1, Size = Vector3.new(taille.X * 1.6, 0.2, taille.Z * 1.6), CFrame = CFrame.new(position) })
			local emetteur = Instance.new("ParticleEmitter")
			emetteur.Name = "Vapeur"
			emetteur.Rate = 0
			emetteur.Lifetime = NumberRange.new(2, 3.5)
			emetteur.Speed = NumberRange.new(1.5 * e, 4 * e)
			emetteur.SpreadAngle = Vector2.new(20, 20)
			emetteur.Acceleration = Vector3.new(0, 1.5 * e, 0)
			emetteur.Drag = 1
			emetteur.Color = ColorSequence.new(Color3.fromRGB(235, 242, 248))
			emetteur.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5 * e), NumberSequenceKeypoint.new(1, 5 * e) })
			emetteur.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.65), NumberSequenceKeypoint.new(1, 1) })
			emetteur.Shape = Enum.ParticleEmitterShape.Box
			emetteur.Parent = vapeur
		end
		vapeur.CFrame = CFrame.new(position)
		vapeur.Vapeur:Emit(math.floor((UI.effetsReduits() and 3 or 8) * (0.4 + 0.6 * intensite)))
	end
	local function dissiperVapeur()
		if not vapeur then return end
		local ancienne = vapeur
		vapeur = nil
		task.delay(4, function() ancienne:Destroy() end)
	end

	-- (V7.2.3, G-26) Arrivée sur l'eau : grande gerbe et anneau d'écume qui s'élargit
	local function gerbeArrivee(position)
		if EFFETS.GerbeEau == false then return end
		local e = echelle()
		local taille = exterieur:GetExtentsSize()
		local largeur = math.max(taille.X, taille.Z)
		local part = piece({ Name = "TardisGerbeEau", Transparency = 1, Size = Vector3.new(largeur, 0.2, largeur), CFrame = CFrame.new(position) })
		local gouttes = Instance.new("ParticleEmitter")
		gouttes.Rate = 0
		gouttes.Lifetime = NumberRange.new(0.8, 1.4)
		gouttes.Speed = NumberRange.new(16 * e, 32 * e)
		gouttes.SpreadAngle = Vector2.new(30, 30)
		gouttes.Acceleration = Vector3.new(0, -55 * e, 0)
		gouttes.Color = ColorSequence.new(Color3.fromRGB(225, 240, 255))
		gouttes.Size = NumberSequence.new(0.7 * e, 0.15 * e)
		gouttes.Transparency = NumberSequence.new(0.15, 1)
		gouttes.Shape = Enum.ParticleEmitterShape.Box
		gouttes.Parent = part
		gouttes:Emit(UI.effetsReduits() and 20 or 60)
		local anneau = piece({ Name = "TardisEcume", Material = Enum.Material.SmoothPlastic, Shape = Enum.PartType.Cylinder,
			Color = Color3.fromRGB(240, 248, 255), Transparency = 0.3, Size = Vector3.new(0.2, largeur, largeur),
			CFrame = CFrame.new(position + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90)) })
		tween(anneau, 2.2, { Size = Vector3.new(0.2, largeur * 3.5, largeur * 3.5), Transparency = 1 })
		Debris:AddItem(part, 2)
		Debris:AddItem(anneau, 2.4)
	end

	-- Anneau d'émetteurs autour de la cabine : la matière est soufflée en tournant (tangente + un peu vers l'extérieur)
	local function creerSouffle(position, couleur, eau)
		local part = piece({ Name = "TardisSouffle", Transparency = 1, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(position) })
		local taille = exterieur:GetExtentsSize()
		local rayon = math.max(taille.X, taille.Z) * 0.6
		local e = echelle() -- (G-79) tailles et vitesses à l'échelle de la cabine
		local emetteurs = {}
		for i = 1, 14 do
			local angle = i / 14 * math.pi * 2
			local local_ = Vector3.new(math.cos(angle) * rayon, 0.3, math.sin(angle) * rayon)
			local tangente = Vector3.new(-math.sin(angle), 0, math.cos(angle))
			local dehors = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local point = Instance.new("Attachment")
			point.CFrame = CFrame.lookAt(local_, local_ + tangente + dehors * 0.4 + Vector3.new(0, eau and 0.6 or 0.25, 0))
			point.Parent = part
			local emetteur = Instance.new("ParticleEmitter")
			emetteur.Texture = "rbxasset://textures/particles/smoke_main.dds"
			emetteur.EmissionDirection = Enum.NormalId.Front
			emetteur.Color = ColorSequence.new(couleur)
			emetteur.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, (eau and 0.5 or 0.7) * e), NumberSequenceKeypoint.new(0.5, (eau and 1.8 or 2.6) * e), NumberSequenceKeypoint.new(1, (eau and 2.2 or 3.6) * e) })
			emetteur.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, eau and 0.3 or 0.5), NumberSequenceKeypoint.new(0.6, eau and 0.6 or 0.75), NumberSequenceKeypoint.new(1, 1) })
			emetteur.Lifetime = NumberRange.new(0.7, 1.4)
			emetteur.Speed = NumberRange.new(10 * e, 22 * e)
			emetteur.SpreadAngle = Vector2.new(10, eau and 35 or 18)
			emetteur.Drag = 2.5
			emetteur.Acceleration = Vector3.new(0, (eau and -28 or 1.2) * e, 0) -- l'eau retombe, la poussière flotte
			emetteur.Rotation = NumberRange.new(0, 360)
			emetteur.RotSpeed = NumberRange.new(-90, 90)
			emetteur.LightInfluence = 1
			emetteur.Rate = 0
			emetteur.Parent = point
			table.insert(emetteurs, emetteur)
		end
		-- Étincelles de poussière brillante, soulevées au centre (rafales seulement)
		local centre = Instance.new("Attachment")
		centre.Parent = part
		local paillettes = Instance.new("ParticleEmitter")
		paillettes.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		paillettes.Color = ColorSequence.new(couleur:Lerp(Color3.new(1, 1, 1), 0.6))
		paillettes.LightEmission = 0.6
		paillettes.Size = NumberSequence.new(0.25 * e, 0)
		paillettes.Transparency = NumberSequence.new(0.2, 1)
		paillettes.Lifetime = NumberRange.new(0.8, 1.6)
		paillettes.Speed = NumberRange.new(6 * e, 14 * e)
		paillettes.SpreadAngle = Vector2.new(180, 180)
		paillettes.Acceleration = Vector3.new(0, (eau and -20 or -3) * e, 0)
		paillettes.Drag = 1.5
		paillettes.Rate = 0
		paillettes.Parent = centre
		table.insert(emetteurs, paillettes)
		souffleSol = { part = part, emetteurs = emetteurs, eau = eau, couleur = couleur, rayon = rayon, echelle = e }
	end

	-- Onde au sol : un anneau fin qui court sur le sol en s'effaçant
	local function onde(position, couleur, largeur, duree, transparence)
		local anneau = piece({ Name = "TardisOnde", Shape = Enum.PartType.Cylinder, Color = couleur, Transparency = transparence or 0.55,
			Size = Vector3.new(0.12, largeur, largeur), CFrame = CFrame.new(position + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.pi / 2) })
		tween(anneau, duree or 0.8, { Size = Vector3.new(0.12, largeur * 2.6, largeur * 2.6), Transparency = 1 })
		Debris:AddItem(anneau, (duree or 0.8) + 0.1)
	end

	-- Arc électrique (urgence) : un éclair bref en zigzag entre deux points de la cabine
	local function arc(cf, taille)
		local function pointSurface()
			local face = math.random(3)
			local x, y, z = (math.random() - 0.5) * taille.X, (math.random() - 0.5) * taille.Y, (math.random() - 0.5) * taille.Z
			local signe = math.random() < 0.5 and -1 or 1
			if face == 1 then x = signe * taille.X / 2 elseif face == 2 then z = signe * taille.Z / 2 else y = signe * taille.Y / 2 end
			return cf:PointToWorldSpace(Vector3.new(x, y, z))
		end
		local depart, arrivee = pointSurface(), pointSurface()
		if (arrivee - depart).Magnitude < 1 then arrivee = pointSurface() end
		local precedent = depart
		local e = echelle() -- (G-79) éclair, éclat et lumière à l'échelle de la cabine
		local n = 5
		for k = 1, n do
			local suivant = k == n and arrivee or depart:Lerp(arrivee, k / n) + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 0.9 * e
			local segment = piece({ Name = "TardisArc", Color = k % 2 == 0 and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 220, 255),
				Size = Vector3.new(0.1 * e, 0.1 * e, (suivant - precedent).Magnitude), CFrame = CFrame.lookAt((precedent + suivant) / 2, suivant) })
			Debris:AddItem(segment, 0.08 + math.random() * 0.06)
			precedent = suivant
		end
		local eclat = piece({ Name = "TardisArcEclat", Shape = Enum.PartType.Ball, Color = Color3.fromRGB(200, 235, 255), Transparency = 0.3,
			Size = Vector3.one * 0.6 * e, CFrame = CFrame.new(arrivee) })
		local lum = Instance.new("PointLight")
		lum.Color, lum.Brightness, lum.Range = Color3.fromRGB(170, 220, 255), 4, 12 * e
		lum.Parent = eclat
		tween(eclat, 0.15, { Size = Vector3.one * 1.6 * e, Transparency = 1 })
		Debris:AddItem(eclat, 0.2)
	end

	-- Intensité de la matérialisation en cours (0 = rien, 1 = au plus fort) : voyage ou phase de vol libre, démat ou remat
	local function intensiteSol()
		local s, p, _, etatAnime, modeAnime = respiration()
		if not etatAnime then return 0, 0, nil, nil end
		if p <= 0 or p >= 1 then return 0, s, etatAnime, modeAnime end
		return math.sin(p * math.pi), s, etatAnime, modeAnime
	end

	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		local facteurHeure = Config.facteurHeure(Lighting.ClockTime) -- V6.9.9 : ondes plus visibles la nuit
		local sansFlash = UI.sansFlash()

		-- 1) Sur l'eau : flottaison (seulement quand personne ne le porte ni ne le pilote)
		local surEau = exterieur:GetAttribute("SurEau") == true and not exterieur:GetAttribute("VolLibre")
			and not exterieur:GetAttribute("Porteur")
		local base = exterieur:GetAttribute("BaseEau")
		if surEau and typeof(base) == "CFrame" then
			flottait = true
			exterieur:PivotTo(base * CFrame.new(0, math.sin(t * 1.2) * 0.25 - 0.15, 0)
				* CFrame.Angles(math.sin(t * 0.9) * math.rad(2), 0, math.cos(t * 0.7) * math.rad(2.5)))
			-- (V7.2.3, G-25) Rides qui partent de la base au rythme du tangage (au plus bas de chaque balancement)
			local intervalle = tonumber(EFFETS.RidesEau) or 0
			if intervalle > 0 and t - derniereRide >= intervalle and math.sin(t * 1.2) < -0.6
				and exterieur:GetAttribute("Camouflage") ~= true then
				derniereRide = t
				local taille = exterieur:GetExtentsSize()
				onde((base * CFrame.new(0, -taille.Y / 2 + 0.1, 0)).Position, Color3.fromRGB(230, 240, 250),
					math.max(taille.X, taille.Z) * 1.4, 2.2, UI.effetsReduits() and 0.8 or 0.6)
			end
		elseif flottait then
			flottait = false
			if typeof(base) == "CFrame" and not exterieur:GetAttribute("VolLibre") and not exterieur:GetAttribute("Porteur") then
				exterieur:PivotTo(base) -- on revient exactement à la position du serveur
			end
		end

		-- 2) Tourbillon, ondes et arcs près du sol
		local intensite, s, etatAnime, modeAnime = 0, 0, nil, nil
		proteger("intensiteSol", function() intensite, s, etatAnime, modeAnime = intensiteSol() end)
		local camoufle = exterieur:GetAttribute("Camouflage") == true or exterieur:GetAttribute("Detruit") == true
		local pivot = exterieur:GetPivot()
		local nouveauSouffle = s > 0.5 and dernierSouffle <= 0.5 -- début d'un souffle à cette image
		dernierSouffle = s
		local couleurMode = Config.couleurDehors(modeAnime or "Normal") -- Rapide : neutre dehors

		local discretSol = etatAnime ~= nil and (Config.Modes[modeAnime] or {}).Discret == true
		if etatAnime and modeAnime then modeSol = modeAnime end
		if etatAnime and not camoufle and not discretSol then
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = exclusionsSol()
			params.IgnoreWater = false
			local depart = pivot.Position + Vector3.new(0, 1, 0)
			local resultat = workspace:Raycast(depart, Vector3.new(0, -14, 0), params)
			if resultat and EFFETS.Tourbillon ~= false then
				local eau = resultat.Material == Enum.Material.Water
				if not souffleSol or souffleSol.eau ~= eau or math.abs((souffleSol.echelle or 1) - echelle()) > 0.01 then -- (G-79) recréé si la taille change
					arreterSouffle()
					local couleur
					if eau then
						couleur = Color3.fromRGB(225, 240, 255)
					elseif resultat.Instance:IsA("Terrain") then
						couleur = workspace.Terrain:GetMaterialColor(resultat.Material)
					else
						couleur = resultat.Instance.Color
					end
					if not eau then couleur = couleur:Lerp(Color3.fromRGB(200, 190, 170), 0.35) end
					creerSouffle(resultat.Position, couleur, eau)
				end
				souffleSol.part.CFrame = CFrame.new(resultat.Position)
				-- (V7.2.3, G-27) Remat au-dessus de l'eau : la vapeur monte à chaque souffle
				if eau and nouveauSouffle and etatAnime == E.Remat then bouffeeVapeur(resultat.Position, intensite) end
				-- Débit continu qui suit la respiration, plus une rafale au début de chaque souffle
				for i, emetteur in souffleSol.emetteurs do
					if i < #souffleSol.emetteurs then
						emetteur.Rate = 16 * intensite * (0.25 + 0.75 * s)
						if nouveauSouffle then emetteur:Emit(math.floor(4 + 6 * intensite)) end
					elseif nouveauSouffle then
						emetteur:Emit(math.floor(10 + 25 * intensite))
					end
				end
			else
				arreterSouffle()
			end
			-- Onde au sol à chaque souffle (même sans poussière : sol dur ou cabine en l'air à moins de 14 studs)
			if resultat and nouveauSouffle and EFFETS.Ondes ~= false then
				local taille = exterieur:GetExtentsSize()
				local largeur = math.max(taille.X, taille.Z) * 1.1
				onde(resultat.Position, couleurMode:Lerp(Color3.new(1, 1, 1), 0.3), largeur, 0.7 + 0.5 * intensite,
					1 - math.clamp((0.4 + 0.25 * intensite) * facteurHeure, 0, 0.9))
			end
			-- Urgence et catastrophe : arcs sur la cabine et étincelles à la lampe (deux fois plus en catastrophe)
			-- (« aucun flash », V6.9.9 : plus d'arcs, qui éclatent en blanc ; les étincelles restent)
			if Config.modeSaccade(modeAnime) and EFFETS.Arcs ~= false and intensite > 0.05 then
				local cf, taille = exterieur:GetBoundingBox()
				if not sansFlash and math.random() < dt * (3 + 9 * s) * intensite * (modeAnime == "Catastrophe" and 2 or 1) then arc(cf, taille) end
				if arcsPart and arcsPart.Parent and math.abs((arcsPart:GetAttribute("Echelle") or 1) - echelle()) > 0.01 then
					arcsPart:Destroy() -- (G-79) la cabine a changé de taille : on refait les étincelles
				end
				if not arcsPart or not arcsPart.Parent then
					arcsPart = piece({ Name = "TardisEtincellesLampe", Transparency = 1, Size = Vector3.one, CFrame = CFrame.new(positionLampe()) })
					local etincelles = Instance.new("ParticleEmitter")
					etincelles.Name = "Etincelles"
					etincelles.Color = ColorSequence.new(Color3.fromRGB(255, 240, 200), Color3.fromRGB(255, 140, 60))
					etincelles.LightEmission = 1
					local e = echelle() -- (G-79) étincelles de la lampe à l'échelle de la cabine
					etincelles.Size = NumberSequence.new(0.2 * e, 0)
					etincelles.Speed = NumberRange.new(8 * e, 16 * e)
					etincelles.Lifetime = NumberRange.new(0.3, 0.7)
					etincelles.SpreadAngle = Vector2.new(60, 60)
					etincelles.Acceleration = Vector3.new(0, -35 * e, 0)
					arcsPart:SetAttribute("Echelle", e)
					etincelles.Rate = 0
					etincelles.Parent = arcsPart
				end
				arcsPart.CFrame = CFrame.new(positionLampe())
				if nouveauSouffle or math.random() < dt * 2 then arcsPart.Etincelles:Emit(math.floor(6 + 14 * s)) end
			elseif arcsPart then
				arcsPart:Destroy()
				arcsPart = nil
			end
		else
			arreterSouffle()
			if arcsPart then arcsPart:Destroy() arcsPart = nil end
		end

		-- 3) Arrivée : la cabine vient de se poser (fin d'une remat) : bouffée de poussière et onde d'arrivée
		local etatMaintenant = exterieur:GetAttribute("Etat") or E.Pose
		if etatSol == E.Remat and etatMaintenant == E.Pose and not camoufle and EFFETS.Choc ~= false and not (Config.Modes[modeSol] or {}).Discret then
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = exclusionsSol()
			params.IgnoreWater = false
			local resultat = workspace:Raycast(pivot.Position + Vector3.new(0, 1, 0), Vector3.new(0, -14, 0), params)
			if resultat then
				local taille = exterieur:GetExtentsSize()
				local largeur = math.max(taille.X, taille.Z) * 1.2
				onde(resultat.Position, Color3.fromRGB(235, 235, 235), largeur, 1, 1 - math.clamp(0.5 * facteurHeure, 0, 0.9))
				if souffleSol then
					for _, emetteur in souffleSol.emetteurs do emetteur:Emit(14) end
				end
				if resultat.Material == Enum.Material.Water then gerbeArrivee(resultat.Position) end -- (V7.2.3, G-26)
			end
		end
		if etatMaintenant ~= E.Remat and vapeur then dissiperVapeur() end -- (V7.2.3, G-27) dissipée après l'arrivée
		etatSol = etatMaintenant
	end)
end

--------------------------------------------------------------------
-- Boucliers : apparition rapide (la bulle jaillit avec un rebond, flash lumineux, onde au sol)
-- et disparition (la bulle se rétracte en s'effaçant)
--------------------------------------------------------------------
do
	local function effetTemporaire(proprietes)
		return piece(proprietes)
	end

	local function animerBouclier(modele)
		local bulle = modele:WaitForChild("Bulle", 5)
		if not bulle then return end
		local cible = bulle:GetAttribute("TailleCible") or bulle.Size

		-- 1) La bulle jaillit du TARDIS
		bulle.Size = cible * 0.05
		tween(bulle, 0.35, { Size = cible }, Enum.EasingStyle.Back)

		-- 2) Flash lumineux qui déborde un peu de la bulle (pas avec « aucun flash », V6.9.9)
		local flash = nil
		if not UI.sansFlash() then
			flash = effetTemporaire({ Name = "TardisFlashBouclier", Shape = Enum.PartType.Ball, Color = bulle.Color,
				Size = cible * 0.3, CFrame = bulle.CFrame, Transparency = 0.25 })
			tween(flash, 0.45, { Size = cible * 1.12, Transparency = 1 })
			Debris:AddItem(flash, 0.5)
		end

		-- 3) Onde au sol
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { exterieur, interieur, flash }
		local sol = workspace:Raycast(bulle.Position, Vector3.new(0, -cible.Y, 0), params)
		if sol then
			local onde = effetTemporaire({ Name = "TardisOndeBouclier", Shape = Enum.PartType.Cylinder, Color = bulle.Color,
				Size = Vector3.new(0.15, 2, 2), Transparency = 0.2,
				CFrame = CFrame.new(sol.Position + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.pi / 2) })
			tween(onde, 0.5, { Size = Vector3.new(0.1, cible.X * 1.7, cible.X * 1.7), Transparency = 1 })
			task.delay(0.55, function() onde:Destroy() end)
		end

		-- 4) Disparition : la bulle se rétracte en s'effaçant
		modele:GetAttributeChangedSignal("Disparition"):Connect(function()
			if bulle.Parent then
				tween(bulle, 0.3, { Size = cible * 0.05, Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			end
		end)
	end

	task.spawn(function()
		local dossier = exterieur:WaitForChild("Boucliers", 30)
		if not dossier then return end
		dossier.ChildAdded:Connect(function(modele)
			task.spawn(animerBouclier, modele)
		end)
	end)
end

--------------------------------------------------------------------
-- Invites du TARDIS (E) : invisibles pour les joueurs non autorisés (Config.Pilotes).
-- La vraie sécurité est sur le serveur, qui ignore leurs actions ; ceci évite juste de les afficher.
--------------------------------------------------------------------
do
	local function regler(objet)
		if objet:IsA("ProximityPrompt") then
			objet.Style = joueur:GetAttribute("TardisPilote_" .. def.Nom) == true and Enum.ProximityPromptStyle.Default
				or Enum.ProximityPromptStyle.Custom -- "Custom" sans interface = rien ne s'affiche
		end
	end
	local function toutRegler()
		for _, racine in { exterieur, interieur } do
			for _, objet in racine:GetDescendants() do regler(objet) end
		end
	end
	exterieur.DescendantAdded:Connect(regler)
	interieur.DescendantAdded:Connect(regler)
	joueur:GetAttributeChangedSignal("TardisPilote_" .. def.Nom):Connect(toutRegler)
	toutRegler()
end

--------------------------------------------------------------------
-- Empreinte temporelle (V6.6.2) : après un départ, une silhouette translucide du TARDIS reste là où il
-- était, scintille légèrement, puis s'efface (Config.Empreinte). Chaque joueur la construit lui-même à
-- partir de l'attribut "Etat" : tout le monde la voit au même endroit.
--------------------------------------------------------------------
do
	local reglages = Config.Empreinte or {}
	local DUREE = reglages.Duree or 30
	local COULEUR = reglages.Couleur or Color3.fromRGB(120, 180, 255)
	local TRANSPARENCE = reglages.Transparence or 0.75
	local enAttente = nil -- silhouette préparée au début de la démat, montrée quand le TARDIS est parti

	-- Copie de la cabine à sa position actuelle (pièces visibles seulement, sans scripts ni interfaces)
	local function preparer()
		local modele = Instance.new("Model")
		modele.Name = "TardisEmpreinte_" .. def.Nom
		for _, part in exterieur:GetDescendants() do
			local fiche = visuels[part]
			local origine = fiche and fiche.transparences.Transparency
			if part:IsA("BasePart") and part ~= exterieur.PrimaryPart and part.Name ~= Config.NomPortailExt
				and (origine or part.Transparency) < 0.95 then
				local fantome = part:Clone()
				if fantome then
					fantome:ClearAllChildren()
					fantome.Anchored, fantome.CanCollide, fantome.CanTouch, fantome.CanQuery = true, false, false, false
					fantome.CastShadow = false
					fantome.Material = Enum.Material.Neon
					fantome.Color = COULEUR
					if fantome:IsA("UnionOperation") then fantome.UsePartColor = true end
					if fantome:IsA("MeshPart") then fantome.TextureID = "" end
					fantome.Transparency = 1
					fantome.Parent = modele
				end
			end
		end
		return modele
	end

	local function montrer(modele)
		local pieces = modele:GetChildren()
		modele.Parent = workspace
		local debut = os.clock()
		local connexion
		connexion = RunService.Heartbeat:Connect(function()
			local ecoule = os.clock() - debut
			local p = ecoule / DUREE
			if p >= 1 or not modele.Parent then
				connexion:Disconnect()
				modele:Destroy()
				return
			end
			-- Apparition rapide, puis effacement lent, avec un léger scintillement
			local apparition = math.clamp(ecoule / 0.6, 0, 1)
			local visibilite = (1 - TRANSPARENCE) * apparition * (1 - p) * (1 + 0.15 * math.sin(ecoule * 9))
			local transparence = math.clamp(1 - visibilite, 0, 1)
			for _, piece_ in pieces do piece_.Transparency = transparence end
		end)
	end

	exterieur:GetAttributeChangedSignal("Etat"):Connect(function()
		local etat = exterieur:GetAttribute("Etat")
		if etat == E.Demat then
			if enAttente then enAttente:Destroy() enAttente = nil end
			-- Pas d'empreinte pour un départ discret : camouflé, porté (téléportation de poche), en vol libre ou Silencieux
			if exterieur:GetAttribute("Camouflage") == true or exterieur:GetAttribute("Porteur") or exterieur:GetAttribute("VolLibre")
				or (Config.Modes[Config.modeDe(exterieur)] or {}).Discret then return end
			enAttente = preparer()
		elseif etat == E.Vol and enAttente then
			local modele = enAttente
			enAttente = nil
			montrer(modele)
		elseif enAttente then
			enAttente:Destroy() -- démat interrompue
			enAttente = nil
		end
	end)
end
--------------------------------------------------------------------
-- Effets propres aux modes (V6.7.1)
--  • Rapide : sa couleur ne se voit qu'à l'intérieur : un éclair vert dans la salle de contrôle au départ et à
--    l'arrivée (plus d'éclair vert dehors : l'ancien Éclair Express de la V6.6.4 est remplacé par les ondes neutres)
--  • Sauvetage (V6.9.5) : pendant la descente en tournant, quatre lumières aux fenêtres (une par côté) éclairent vers
--    l'extérieur, à l'horizontale, et balaient les alentours comme un phare ; le sol sous la cabine n'est pas éclairé
--  • Catastrophe : à bord, la console crache des étincelles et la salle bat en rouge pendant la matérialisation ;
--    dehors (V6.9.9), fumée noire et étincelles autour de la cabine, puis éclats et fumée à l'atterrissage forcé
--------------------------------------------------------------------
do
	local COULEUR_RAPIDE = Config.Modes.Express.CouleurRotor or Color3.fromRGB(74, 222, 128)
	local ROUGE = Color3.fromRGB(255, 60, 60)
	local teinteMode = Instance.new("ColorCorrectionEffect")
	teinteMode.Name = "TardisTeinteMode_" .. def.Nom
	teinteMode.Parent = Lighting
	local supportRotor = rotor:IsA("BasePart") and rotor or rotor:FindFirstChildWhichIsA("BasePart", true) or Config.partPrincipale(interieur)
	local lumiereRotor = Instance.new("PointLight")
	lumiereRotor.Brightness, lumiereRotor.Range, lumiereRotor.Shadows = 0, 40, false
	lumiereRotor.Parent = supportRotor
	local eclat, couleurEclat = 0, COULEUR_RAPIDE -- éclair intérieur (décroît)

	-- Phare de sauvetage (V6.9.5) : une pièce invisible un peu plus large que la cabine, à hauteur des fenêtres, qui suit
	-- la cabine (et donc sa rotation) ; une SurfaceLight sur chacune de ses 4 faces latérales éclaire vers l'extérieur
	-- (faisceau étroit, pas d'ombre : il traverse les vitres), et un faisceau visible part de chaque côté
	local COULEUR_PHARE = Color3.fromRGB(255, 246, 220)
	local boiteCabine, tailleCabine = exterieur:GetBoundingBox()
	local relatifPhare = exterieur:GetPivot():ToObjectSpace(boiteCabine * CFrame.new(0, tailleCabine.Y * 0.22, 0)) -- vers 72 % de la hauteur
	local phare = piece({ Name = "TardisPhare_" .. def.Nom, Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false,
		Size = Vector3.new(tailleCabine.X * 1.04, math.max(tailleCabine.Y * 0.12, 0.5), tailleCabine.Z * 1.04), CFrame = exterieur:GetPivot() * relatifPhare })
	local lumieresPhare, faisceauxPhare = {}, {}
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right } do
		local lumiere = Instance.new("SurfaceLight")
		lumiere.Face, lumiere.Angle, lumiere.Range, lumiere.Brightness, lumiere.Shadows = face, 28, 60, 0, false
		lumiere.Color = COULEUR_PHARE
		lumiere.Parent = phare
		table.insert(lumieresPhare, lumiere)
		-- Faisceau visible : de la fenêtre vers l'extérieur, de plus en plus large et pâle
		local direction = Vector3.FromNormalId(face)
		local demiLargeur = math.abs(direction.X) > 0 and phare.Size.X / 2 or phare.Size.Z / 2
		local a0 = Instance.new("Attachment")
		a0.Position = direction * demiLargeur
		a0.Parent = phare
		local a1 = Instance.new("Attachment")
		a1.Position = direction * (demiLargeur + 40)
		a1.Parent = phare
		local faisceau = Instance.new("Beam")
		faisceau.Attachment0, faisceau.Attachment1 = a0, a1
		faisceau.Width0, faisceau.Width1 = phare.Size.Y * 1.5, 14
		faisceau.LightEmission, faisceau.LightInfluence = 1, 0
		faisceau.Color = ColorSequence.new(COULEUR_PHARE)
		faisceau.Transparency = NumberSequence.new(1)
		faisceau.FaceCamera = true
		faisceau.Enabled = false
		faisceau.Parent = phare
		table.insert(faisceauxPhare, faisceau)
	end
	local intensitePhare = 0

	-- Étincelles de la console (catastrophe) : préparées à la demande
	local pointsConsole = nil
	local function preparerEtincelles()
		pointsConsole = {}
		local console = interieur:FindFirstChild("Console")
		if not console then return end
		local pieces = {}
		for _, objet in console:GetDescendants() do
			if objet:IsA("BasePart") and objet.Size.Magnitude > 0.8 then table.insert(pieces, objet) end
		end
		for _ = 1, math.min(8, #pieces) do
			local part = table.remove(pieces, math.random(#pieces))
			local point = Instance.new("Attachment")
			point.Parent = part
			local etincelles = Instance.new("ParticleEmitter")
			etincelles.Color = ColorSequence.new(Color3.fromRGB(255, 235, 150), Color3.fromRGB(255, 90, 30))
			etincelles.LightEmission = 1
			etincelles.Size = NumberSequence.new(0.25, 0)
			etincelles.Speed = NumberRange.new(8, 20)
			etincelles.Lifetime = NumberRange.new(0.3, 0.8)
			etincelles.SpreadAngle = Vector2.new(90, 90)
			etincelles.Acceleration = Vector3.new(0, -30, 0)
			etincelles.Rate = 0
			etincelles.Parent = point
			table.insert(pointsConsole, etincelles)
		end
	end

	--------------------------------------------------------------------
	-- Catastrophe dehors (V6.9.9) : pendant la matérialisation, fumée noire et gerbes d'étincelles qui sortent des faces
	-- de la cabine (une bouffée à chaque souffle) ; à l'atterrissage forcé (attribut « Catastrophe » posé par le serveur,
	-- qui remet aussitôt Mode à Normal), une explosion d'éclats et une fumée qui traîne. Divisé par 3 en « effets réduits ».
	--------------------------------------------------------------------
	local CATASTROPHE_DEHORS = EFFETS.Catastrophe ~= false
	local DUREE_FUMEE = tonumber(EFFETS.DureeFumeeCatastrophe) or 20
	local FUMEE = "rbxasset://textures/particles/smoke_main.dds"
	local NOIR, NOIR_CLAIR = Color3.fromRGB(18, 16, 16), Color3.fromRGB(48, 42, 40)
	local cabineCatastrophe = nil -- { part, fumee, etincelles } : suit la cabine pendant la remat
	local souffleCatastrophe = 0
	local function emetteurFumee(parent, debit)
		local fumee = Instance.new("ParticleEmitter")
		fumee.Name = "Fumee"
		fumee.Texture = FUMEE
		fumee.Color = ColorSequence.new(NOIR, NOIR_CLAIR)
		fumee.LightInfluence = 1
		fumee.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 6) })
		fumee.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(0.7, 0.7), NumberSequenceKeypoint.new(1, 1) })
		fumee.Lifetime = NumberRange.new(2, 3.5)
		fumee.Speed = NumberRange.new(2, 5)
		fumee.Acceleration = Vector3.new(0, 3, 0)
		fumee.Rotation, fumee.RotSpeed = NumberRange.new(0, 360), NumberRange.new(-40, 40)
		fumee.Shape, fumee.ShapeStyle = Enum.ParticleEmitterShape.Box, Enum.ParticleEmitterShapeStyle.Surface
		fumee.Rate = debit
		fumee.Parent = parent
		return fumee
	end
	local function emetteurEtincelles(parent)
		local etincelles = Instance.new("ParticleEmitter")
		etincelles.Name = "Etincelles"
		etincelles.Color = ColorSequence.new(Color3.fromRGB(255, 235, 170), Color3.fromRGB(255, 110, 30))
		etincelles.LightEmission = 1
		etincelles.Size = NumberSequence.new(0.22, 0)
		etincelles.Speed = NumberRange.new(10, 22)
		etincelles.Lifetime = NumberRange.new(0.3, 0.8)
		etincelles.SpreadAngle = Vector2.new(35, 35)
		etincelles.Acceleration = Vector3.new(0, -40, 0)
		etincelles.Shape, etincelles.ShapeStyle, etincelles.ShapeInOut = Enum.ParticleEmitterShape.Box, Enum.ParticleEmitterShapeStyle.Surface, Enum.ParticleEmitterShapeInOut.Outward
		etincelles.Rate = 0
		etincelles.Parent = parent
		return etincelles
	end
	local function arreterCabineCatastrophe()
		if not cabineCatastrophe then return end
		local ancien = cabineCatastrophe
		cabineCatastrophe = nil
		ancien.fumee.Enabled, ancien.etincelles.Enabled = false, false
		Debris:AddItem(ancien.part, 4) -- les dernières particules finissent de vivre
	end
	-- Une image de la remat en Catastrophe : la pièce d'effet (la boîte de la cabine) suit la cabine
	local function majCabineCatastrophe(dt, reduit)
		local cf, taille = exterieur:GetBoundingBox()
		if not cabineCatastrophe then
			local part = piece({ Name = "TardisCatastrophe_" .. def.Nom, Transparency = 1, Size = taille, CFrame = cf })
			cabineCatastrophe = { part = part, fumee = emetteurFumee(part, 0), etincelles = emetteurEtincelles(part) }
		end
		cabineCatastrophe.part.CFrame = cf
		local souffle = respiration()
		local division = reduit and 3 or 1
		cabineCatastrophe.fumee.Rate = (4 + 10 * souffle) / division
		if souffle > 0.5 and souffleCatastrophe <= 0.5 then
			cabineCatastrophe.fumee:Emit(math.floor(12 / division))
			cabineCatastrophe.etincelles:Emit(math.floor(36 / division))
		elseif math.random() < dt * 3 then
			cabineCatastrophe.etincelles:Emit(math.floor(12 / division))
		end
		souffleCatastrophe = souffle
	end
	-- Atterrissage forcé : explosion d'éclats (petites pièces locales, sans collision) et fumée qui traîne DUREE_FUMEE s
	local function explosionCatastrophe()
		local division = UI.effetsReduits() and 3 or 1
		local cf, taille = exterieur:GetBoundingBox()
		local centre = cf.Position
		for i = 1, math.floor(18 / division) do
			local eclat_ = Instance.new("Part")
			eclat_.Name = "TardisEclatCatastrophe"
			eclat_.Anchored, eclat_.CanCollide, eclat_.CanTouch, eclat_.CanQuery, eclat_.CastShadow, eclat_.Massless = false, false, false, false, false, true
			eclat_.Size = Vector3.new(0.2 + math.random() * 0.5, 0.1 + math.random() * 0.15, 0.2 + math.random() * 0.5)
			eclat_.Material = i % 3 == 0 and Enum.Material.Neon or Enum.Material.SmoothPlastic
			eclat_.Color = i % 3 == 0 and Color3.fromRGB(255, 140, 60) or Color3.fromRGB(30, 45, 85)
			local angle = math.random() * math.pi * 2
			local direction = Vector3.new(math.cos(angle), 0.5 + math.random() * 0.8, math.sin(angle))
			eclat_.CFrame = CFrame.new(centre + direction * 1.5) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
			eclat_.Parent = workspace
			eclat_.AssemblyLinearVelocity = direction * (25 + math.random() * 25)
			eclat_.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 20
			Debris:AddItem(eclat_, 2 + math.random())
		end
		-- Fumée noire qui traîne autour de la base, de plus en plus faible, et une gerbe d'étincelles
		local base = piece({ Name = "TardisFumeeCatastrophe_" .. def.Nom, Transparency = 1, Size = Vector3.new(taille.X, 1, taille.Z),
			CFrame = cf * CFrame.new(0, -taille.Y / 2 + 0.5, 0) })
		local fumee = emetteurFumee(base, 12 / division)
		fumee:Emit(math.floor(30 / division))
		tween(fumee, DUREE_FUMEE, { Rate = 0 }, Enum.EasingStyle.Linear)
		emetteurEtincelles(base):Emit(math.floor(80 / division))
		Debris:AddItem(base, DUREE_FUMEE + 4)
	end
	exterieur:GetAttributeChangedSignal("Catastrophe"):Connect(function()
		local quand = exterieur:GetAttribute("Catastrophe")
		if not CATASTROPHE_DEHORS or type(quand) ~= "number" or workspace:GetServerTimeNow() - quand > 5 then return end
		if exterieur:GetAttribute("Camouflage") == true then return end
		proteger("catastropheAtterrissage", explosionCatastrophe)
	end)

	local etatAvant, modeAvant = exterieur:GetAttribute("Etat") or E.Pose, "Normal"
	exterieur:GetAttributeChangedSignal("Etat"):Connect(function()
		local etat = exterieur:GetAttribute("Etat")
		local modeMaintenant = Config.modeDe(exterieur)
		-- Rapide : éclair vert dans la salle au début de la démat, au début de la remat et une fois posé
		if ((etat == E.Demat or etat == E.Remat) and modeMaintenant == "Express")
			or (etat == E.Pose and etatAvant == E.Remat and (modeMaintenant == "Express" or modeAvant == "Express")) then
			eclat, couleurEclat = 1, COULEUR_RAPIDE
		end
		etatAvant, modeAvant = etat, modeMaintenant
	end)
	exterieur:GetAttributeChangedSignal("VolPhase"):Connect(function()
		local phase = exterieur:GetAttribute("VolPhase")
		if (phase == E.Demat or phase == E.Remat) and Config.modeVolDe(exterieur) == "Express" then
			eclat, couleurEclat = 1, COULEUR_RAPIDE
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		local etat = exterieur:GetAttribute("Etat") or E.Pose
		local mode = Config.modeDe(exterieur)
		local reduit = UI.effetsReduits()
		local sansFlash = UI.sansFlash() -- V6.9.9 : ni éclair du Rapide, ni battement rouge (la salle reste rouge, fixe)
		local racine = joueur.Character and joueur.Character:FindFirstChild("HumanoidRootPart")
		local dedans = racine ~= nil and dansInterieur(racine.Position)

		-- Éclair intérieur du Rapide, et battement rouge de la catastrophe (seulement pour ceux qui sont à bord)
		if sansFlash then eclat = 0 end
		eclat = math.max(0, eclat - dt * 2.5)
		local intensiteEclat = dedans and eclat * (reduit and 0.4 or 1) or 0
		local catastrophe = etat == E.Remat and mode == "Catastrophe"
		local pulsationCatastrophe = sansFlash and 0.5 or (0.5 + 0.5 * math.sin(t * 9))
		local battement = (catastrophe and dedans) and pulsationCatastrophe * (reduit and 0.25 or 0.5) or 0
		local teinte = Color3.new(1, 1, 1):Lerp(couleurEclat, 0.4 * intensiteEclat):Lerp(ROUGE, 0.5 * battement)
		teinteMode.TintColor = teinte
		teinteMode.Brightness = 0.12 * intensiteEclat
		lumiereRotor.Color = catastrophe and ROUGE or couleurEclat
		lumiereRotor.Brightness = 10 * intensiteEclat + (catastrophe and 5 * pulsationCatastrophe or 0)
		-- Catastrophe : la console crache des étincelles (chez tout le monde : elle est visible de dehors par la porte)
		if catastrophe then
			if not pointsConsole then preparerEtincelles() end
			if #pointsConsole > 0 and math.random() < dt * 7 then
				pointsConsole[math.random(#pointsConsole)]:Emit(math.random(10, 25))
			end
		end
		-- Catastrophe dehors (V6.9.9) : chez tout le monde, sauf si la cabine est camouflée
		if CATASTROPHE_DEHORS and catastrophe and exterieur:GetAttribute("Camouflage") ~= true then
			proteger("catastropheDehors", majCabineCatastrophe, dt, reduit)
		elseif cabineCatastrophe then
			arreterCabineCatastrophe()
		end

		-- Phare de sauvetage : allumé pendant la descente en tournant (pas camouflé, avec du courant), il suit la cabine
		local sauvetage = etat == E.Remat and mode == "Sauvetage" and exterieur:GetAttribute("Camouflage") ~= true
			and exterieur:GetAttribute("Alimentation") ~= false
		intensitePhare += ((sauvetage and 1 or 0) - intensitePhare) * math.min(dt * 4, 1)
		if sauvetage or intensitePhare > 0.01 then
			phare.CFrame = exterieur:GetPivot() * relatifPhare
			-- La lumière suit l'apparition de la cabine (elle sort des fenêtres à mesure que la cabine se matérialise)
			local dureePhare, decalagePhare = Config.Timing(E.Remat, "Sauvetage")
			local p = sauvetage and math.clamp((workspace:GetServerTimeNow() - (exterieur:GetAttribute("DebutEtat") or 0) - decalagePhare) / math.max(dureePhare, 0.1), 0, 1) or 1
			local force = intensitePhare * math.clamp(p * 1.4, 0, 1)
			for _, lumiere in lumieresPhare do lumiere.Brightness = 8 * force end
			for _, faisceau in faisceauxPhare do
				faisceau.Enabled = force > 0.01
				faisceau.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1 - 0.32 * force), NumberSequenceKeypoint.new(1, 1) })
			end
		else
			for _, faisceau in faisceauxPhare do faisceau.Enabled = false end
		end
	end)
end
