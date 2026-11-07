-- StarterPlayer > StarterPlayerScripts > TardisPortail (LocalScript)
-- 1) De l'extérieur : on voit la salle de contrôle à travers la porte ouverte.
-- 2) De l'intérieur : on voit la rue (les environs du TARDIS) à travers la porte ouverte.
-- 3) Passage sans coupure visible entre l'extérieur et l'intérieur.
--
-- Principe de la vue : une caméra virtuelle est placée de l'autre côté, au même endroit
-- par rapport à l'autre porte que ta caméra par rapport à la porte que tu regardes.
-- Elle regarde perpendiculairement à la porte, et le ViewportFrame est décalé/agrandi
-- pour que l'image tombe pile dans l'encadrement, quel que soit l'angle de vue.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local Config = require(ReplicatedStorage:WaitForChild("TardisConfig"))
local E = Config.Etats

local joueur = Players.LocalPlayer
local camera = workspace.CurrentCamera

local def = Config.demarrerPourChaqueTardis(script) -- un exemplaire par TARDIS : tout le monde voit les trois
local exterieur, interieur = Config.modeles(def)
local portailExt = exterieur:WaitForChild(Config.NomPortailExt)
local portailInt = interieur:WaitForChild(Config.NomPortailInt)
local rotor = interieur:WaitForChild(Config.NomRotor)
local dossierPortes = exterieur:FindFirstChild(Config.NomDossierPortes or "TARDISDoors")

-- Les deux portes peuvent avoir des tailles différentes (TARDIS réduit) : on lit leurs dimensions à chaque image
local SEUIL_PORTES = Config.TailleOuverturePortes or 1 -- en dessous de cette taille, ni vue ni passage
local FOV_MAX = 120
local DEMI_TOUR = CFrame.Angles(0, math.pi, 0)

local NOM_PORTES_INT = Config.NomPortesInt or "PortesInterieures"       -- Folder des portes de l'intérieur
local RAYON_EXT = Config.RayonVueExterieur or 120                       -- rayon des environs copiés (studs)
local COULEUR_CIEL = Config.CouleurCiel or Color3.fromRGB(150, 190, 230) -- fond de la vue vers l'extérieur

local function porteOuverte()
	return exterieur:GetAttribute("PorteOuverte") == true
		and exterieur:GetAttribute("Etat") == E.Pose
		and (exterieur:GetAttribute("Echelle") or 1) >= SEUIL_PORTES - 0.001 -- trop petit : ni vue, ni passage
end

-- Repère posé au SOL de la porte (et non en son centre) : les deux portes sont alignées par le sol,
-- même quand le TARDIS extérieur est plus petit que l'intérieur
local function repereSol(portail)
	return portail.CFrame * CFrame.new(0, -portail.Size.Y / 2, 0)
end

-- Centre "virtuel" d'une porte de la taille de "porteVue", posée au sol de "porteCible"
local function centreAligne(porteCible, porteVue)
	return repereSol(porteCible) * CFrame.new(0, porteVue.Size.Y / 2, 0)
end

--------------------------------------------------------------------
-- Nettoyage des copies (on ne garde que le visuel)
--------------------------------------------------------------------
local A_RETIRER = {
	"LuaSourceContainer", "Sound", "ProximityPrompt", "ClickDetector", "Light", "LayerCollector",
	"ParticleEmitter", "Beam", "Trail", "Fire", "Smoke", "Sparkles",
}

local function nettoyer(racine)
	for _, objet in racine:GetDescendants() do
		for _, classe in A_RETIRER do
			if objet:IsA(classe) then
				objet:Destroy()
				break
			end
		end
	end
end

local function copierPart(part)
	local copie = part:Clone()
	if not copie then return nil end -- Archivable = false
	for _, enfant in copie:GetChildren() do
		if enfant:IsA("BasePart") or enfant:IsA("Model") or enfant:IsA("Folder") then
			enfant:Destroy() -- les pièces enfants sont copiées séparément
		end
	end
	nettoyer(copie)
	copie.Anchored = true
	return copie
end

--------------------------------------------------------------------
-- Copie de l'intérieur (vue depuis l'extérieur)
--------------------------------------------------------------------
local function clonerInterieur()
	local ancien = interieur.Archivable
	interieur.Archivable = true
	local copie = interieur:Clone()
	interieur.Archivable = ancien

	nettoyer(copie)
	for _, nom in { Config.NomIgnorerVue, NOM_PORTES_INT, Config.NomPortailInt } do
		local objet = copie:FindFirstChild(nom)
		if objet then objet:Destroy() end
	end
	return copie
end

--------------------------------------------------------------------
-- Copie des environs du TARDIS (vue depuis l'intérieur)
--------------------------------------------------------------------
local exclus = {}
local function estExclu(instance)
	if instance == nil or instance == workspace then return false end
	local resultat = exclus[instance]
	if resultat ~= nil then return resultat end

	if instance == exterieur or instance == interieur or instance:IsA("Terrain") or instance:IsA("Camera")
		or (instance.Parent == workspace and string.sub(instance.Name, 1, 6) == "Tardis") then
		resultat = true
	elseif instance:IsA("Model") and instance:FindFirstChildOfClass("Humanoid") then
		resultat = true -- joueurs et PNJ : ils bougent, une copie figée n'aurait pas de sens
	else
		resultat = estExclu(instance.Parent)
	end
	exclus[instance] = resultat
	return resultat
end

-- Distance entre un point et le bord le plus proche d'une Part (marche aussi pour une grande baseplate)
local function distanceA(part, point)
	local p = part.CFrame:PointToObjectSpace(point)
	local s = part.Size / 2
	local proche = Vector3.new(math.clamp(p.X, -s.X, s.X), math.clamp(p.Y, -s.Y, s.Y), math.clamp(p.Z, -s.Z, s.Z))
	return (p - proche).Magnitude
end

-- Demi-épaisseur d'une Part le long de l'axe avant/arrière du Portail
local function demiEpaisseur(part, axe)
	local cf, s = part.CFrame, part.Size / 2
	return math.abs(cf.RightVector:Dot(axe)) * s.X
		+ math.abs(cf.UpVector:Dot(axe)) * s.Y
		+ math.abs(cf.LookVector:Dot(axe)) * s.Z
end

local RAYON_VOL = 600     -- portes ouvertes en plein vol : on copie un grand morceau du paysage
local TAILLE_MIN_VOL = 4  -- ... mais seulement les pièces assez grandes (sinon trop lourd)

local function clonerEnvirons(enVol)
	table.clear(exclus)
	local modele = Instance.new("Model")
	modele.Name = "Environs"
	local nombre = 0

	local repere = portailExt.CFrame
	local centre = repere.Position
	local rayon = enVol and RAYON_VOL or RAYON_EXT

	for _, objet in workspace:GetDescendants() do
		if objet:IsA("BasePart") and objet.Transparency < 1
			and not estExclu(objet)
			and (not enVol or objet.Size.Magnitude >= TAILLE_MIN_VOL)
			and distanceA(objet, centre) <= rayon then
			-- Au sol, on ne garde que ce qui est au moins en partie DEVANT la porte (côté rue),
			-- sinon les murs derrière le TARDIS boucheraient la vue. En vol, rien ne gêne : on garde tout.
			local z = repere:PointToObjectSpace(objet.Position).Z
			if enVol or z - demiEpaisseur(objet, repere.LookVector) < 0 then
				-- pcall : une pièce impossible à copier est simplement ignorée
				local ok, copie = pcall(copierPart, objet)
				if ok and copie then
					copie.Parent = modele
					nombre += 1
				end
			end
		end
	end

	-- Battants de la porte : copiés à part et synchronisés à chaque image (on les voit s'ouvrir/se fermer)
	local battants = {}
	if dossierPortes then
		for _, objet in dossierPortes:GetDescendants() do
			if objet:IsA("BasePart") and objet.Transparency < 1 then
				local ok, copie = pcall(copierPart, objet)
				if ok and copie then
					copie.Parent = modele
					battants[objet] = copie
				end
			end
		end
	end

	print(("[TARDIS] Vue de la rue : %d pièces copiées"):format(nombre))
	return modele, battants
end

--------------------------------------------------------------------
-- Création d'une "fenêtre" (SurfaceGui + ViewportFrame) sur une face d'un Portail
--------------------------------------------------------------------
local function creerFenetre(nom, part, face, fond)
	local gui = Instance.new("SurfaceGui")
	gui.Name = nom
	gui.Adornee = part
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = Config.PixelsParStud
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.Parent = joueur:WaitForChild("PlayerGui")

	local cadre = Instance.new("Frame")
	cadre.Size = UDim2.fromScale(1, 1)
	cadre.BackgroundTransparency = 1
	cadre.ClipsDescendants = true
	cadre.Parent = gui

	local vue = Instance.new("ViewportFrame")
	vue.AnchorPoint = Vector2.new(0.5, 0.5)
	vue.BackgroundColor3 = fond
	vue.Ambient = Config.LumiereAmbiante
	vue.LightColor = Color3.new(1, 1, 1)
	vue.Visible = false
	vue.Parent = cadre

	local cam = Instance.new("Camera")
	cam.Parent = vue
	vue.CurrentCamera = cam

	return { vue = vue, cam = cam, cadre = cadre }
end

-- source : repère de la porte regardée (face avant tournée vers le joueur)
-- cible  : repère correspondant de l'autre côté
local function majFenetre(fenetre, source, cible, taille)
	local LARGEUR, HAUTEUR, DEMI_Z = taille.X, taille.Y, taille.Z / 2
	local oeil = source:PointToObjectSpace(camera.CFrame.Position)
	local distance = -DEMI_Z - oeil.Z

	if distance <= 0.05 or oeil.Magnitude > Config.DistanceVueMax then
		fenetre.vue.Visible = false
		return
	end
	fenetre.vue.Visible = true

	local S = math.max(math.abs(oeil.X) + LARGEUR / 2, math.abs(oeil.Y) + HAUTEUR / 2)
	local fov = math.deg(2 * math.atan(S / distance))
	if fov > FOV_MAX then
		fov = FOV_MAX
		S = distance * math.tan(math.rad(FOV_MAX / 2))
	end

	fenetre.cam.FieldOfView = fov
	fenetre.cam.CFrame = cible * CFrame.new(oeil) * DEMI_TOUR
	fenetre.vue.Size = UDim2.fromScale(2 * S / LARGEUR, 2 * S / HAUTEUR)
	fenetre.vue.Position = UDim2.fromScale((LARGEUR / 2 - oeil.X) / LARGEUR, (HAUTEUR / 2 - oeil.Y) / HAUTEUR)
end

-- Fenêtre extérieur -> intérieur (face avant du Portail extérieur, côté rue)
local fenetreExt = creerFenetre("TardisVueInterieur", portailExt, Enum.NormalId.Front, Color3.new(0, 0, 0))
local copieInterieur = clonerInterieur()
copieInterieur.Parent = fenetreExt.vue
local rotorCopie = copieInterieur:FindFirstChild(Config.NomRotor)

-- Fenêtre intérieur -> extérieur (face arrière du Portail intérieur, côté salle)
local fenetreInt = creerFenetre("TardisVueExterieur", portailInt, Enum.NormalId.Back, COULEUR_CIEL)
local environs, battantsCopies = nil, {}

local centreVueVol = nil -- d'où a été copiée la vue en vol (on la refait si le TARDIS s'éloigne trop)
local derniereCopie = os.clock() -- (V7.3.5, G-169) heure de la dernière copie des environs
local function reconstruireEnvirons(enVol)
	local ok, nouveau, battants = pcall(clonerEnvirons, enVol == true)
	if not ok then
		warn("[TARDIS] Impossible de copier les environs : " .. tostring(nouveau))
		return
	end
	derniereCopie = os.clock()
	if environs then environs:Destroy() end
	environs, battantsCopies = nouveau, battants
	environs.Parent = fenetreInt.vue
	fenetreInt.vue.LightDirection = -Lighting:GetSunDirection()
end

-- Lancé à part : même si la copie échoue ou prend du temps, la vue de l'intérieur et le passage marchent
task.spawn(reconstruireEnvirons)

-- Portes ouvertes en plein vol : la vue montre le paysage qui défile (copie refaite tous les 250 studs)
task.spawn(function()
	local enCours = false
	while true do
		task.wait(0.5)
		if exterieur:GetAttribute("VolLibre") and exterieur:GetAttribute("PorteOuverte") and not enCours then
			local position = portailExt.Position
			if not centreVueVol or (position - centreVueVol).Magnitude > 250 then
				enCours = true
				centreVueVol = position
				reconstruireEnvirons(true)
				enCours = false
			end
		elseif not exterieur:GetAttribute("VolLibre") and centreVueVol then
			centreVueVol = nil
			reconstruireEnvirons(false) -- de retour au sol : vue normale
		end
	end
end)
exterieur:GetAttributeChangedSignal("Etat"):Connect(function()
	if exterieur:GetAttribute("Etat") == E.Pose then
		task.wait(0.5) -- laisse le temps au TARDIS de réapparaître complètement
		reconstruireEnvirons() -- le TARDIS a changé d'endroit : nouveaux environs
	end
end)

--------------------------------------------------------------------
-- (V7.3.5) Vue par la porte : voile du bouclier, salle qui suit ses lumières, rue rafraîchie, silhouettes
--------------------------------------------------------------------
local VP = Config.VuePorte or {}

-- (G-159) Voile bleuté qui ondule sur la vue de la rue quand un bouclier est levé (la bulle n'est pas copiée dans la vue)
local voile = Instance.new("Frame")
voile.Name = "TardisVoileBouclier"
voile.Size = UDim2.fromScale(1, 1)
voile.BorderSizePixel = 0
voile.BackgroundColor3 = VP.CouleurVoile or Color3.fromRGB(110, 180, 255)
voile.BackgroundTransparency = 1
voile.ZIndex = 5
voile.Visible = false
voile.Parent = fenetreInt.cadre
local function bouclierLeve()
	return VP.VoileBouclier ~= false and Config.bouclierLeve(exterieur:GetAttribute("BouclierJoueurs"),
		exterieur:GetAttribute("BouclierBalles"), exterieur:GetAttribute("BouclierComplet"))
end

-- (G-166) La salle vue de dehors suit ses lumières : sombre hors tension, rouge en alerte ou pendant l'auto-destruction
local ambianteNormale = fenetreExt.vue.Ambient
local function majAmbianceSalle()
	if VP.SalleSuitLumieres == false then return end
	local alerte = exterieur:GetAttribute("Alerte") == true or exterieur:GetAttribute("AutoDestructionDebut") ~= nil
	local ambiante, lumiere = Config.ambianceVueSalle(exterieur:GetAttribute("Alimentation") == false, alerte, ambianteNormale)
	fenetreExt.vue.Ambient = ambiante
	fenetreExt.vue.LightColor = lumiere
end
for _, nom in { "Alimentation", "Alerte", "AutoDestructionDebut" } do
	exterieur:GetAttributeChangedSignal(nom):Connect(majAmbianceSalle)
end
majAmbianceSalle()

-- (G-166) La copie du rotor prend les couleurs du vrai (couleur du mode, alerte, auto-destruction) : pièces appariées
-- dans l'ordre (la copie garde l'ordre des pièces), seulement si elles correspondent toutes
local pairesRotor = {}
if rotorCopie and VP.SalleSuitLumieres ~= false then
	local function pieces(racine)
		local liste = racine:IsA("BasePart") and { racine } or {}
		for _, objet in racine:GetDescendants() do
			if objet:IsA("BasePart") then table.insert(liste, objet) end
		end
		return liste
	end
	local originaux, copies = pieces(rotor), pieces(rotorCopie)
	if #originaux == #copies then
		for i, original in originaux do
			if copies[i].Name == original.Name then pairesRotor[original] = copies[i] end
		end
	end
end
local function majCouleursRotor()
	for original, copie in pairesRotor do
		if copie.Color ~= original.Color then copie.Color = original.Color end
		if copie.Material ~= original.Material then copie.Material = original.Material end
	end
end

-- (G-169) Posé longtemps : la copie des environs est refaite de temps en temps, porte fermée (véhicules et objets qui ont
-- bougé), pour que l'image ne saute pas sous les yeux
if VP.RafraichirEnvirons ~= false then
	task.spawn(function()
		while true do
			task.wait(5)
			if Config.rafraichirEnvirons(derniereCopie, os.clock(), VP.PeriodeRafraichir, exterieur:GetAttribute("PorteOuverte") == true,
				exterieur:GetAttribute("Etat"), exterieur:GetAttribute("VolLibre") ~= nil) then
				reconstruireEnvirons()
			end
		end
	end)
end

-- (G-168) Silhouettes des personnages : joueurs et PNJ sont exclus des copies (ils bougent) ; à la place, de simples
-- silhouettes sombres, mises à jour 5 fois par seconde porte ouverte : dans la rue (vue de la salle) et à bord (vue de
-- dehors). Les plus proches de la porte d'abord, 12 au plus ; jamais le joueur lui-même.
if VP.Silhouettes ~= false then
	local COULEUR = VP.CouleurSilhouette or Color3.fromRGB(25, 25, 32)
	local MAX = math.max(tonumber(VP.MaxSilhouettes) or 12, 0)
	local PERIODE = math.max(tonumber(VP.PeriodeSilhouettes) or 0.2, 0.05)
	local cfSalle, tailleSalle = Config.boite(interieur)
	local dossiers = {}
	local function dossierDe(fenetre)
		local dossier = dossiers[fenetre]
		if not dossier or dossier.Parent ~= fenetre.vue then
			dossier = Instance.new("Model")
			dossier.Name = "TardisSilhouettes"
			dossier.Parent = fenetre.vue
			dossiers[fenetre] = dossier
		end
		return dossier
	end
	-- PNJ : Models avec un Humanoid au premier ou au deuxième niveau du Workspace, et dans la salle (cherchés toutes les 3 s)
	local pnj, prochaineRecherche = {}, 0
	local function chercherPnj()
		table.clear(pnj)
		local function regarder(objet)
			if objet:IsA("Model") and objet:FindFirstChildOfClass("Humanoid") and not Players:GetPlayerFromCharacter(objet) then
				table.insert(pnj, objet)
			end
		end
		for _, objet in workspace:GetChildren() do
			regarder(objet)
			if objet:IsA("Folder") then
				for _, enfant in objet:GetChildren() do regarder(enfant) end
			end
		end
		for _, objet in interieur:GetChildren() do regarder(objet) end
	end
	-- Quelle vue montre ce point : la vue de dehors s'il est dans la salle, la vue de la salle s'il est dans la rue devant la porte
	local function vueDe(position)
		if cfSalle and tailleSalle then
			local q = cfSalle:PointToObjectSpace(position)
			if math.abs(q.X) <= tailleSalle.X / 2 and math.abs(q.Y) <= tailleSalle.Y / 2 and math.abs(q.Z) <= tailleSalle.Z / 2 then
				return fenetreExt, (position - portailInt.Position).Magnitude
			end
		end
		local distance = (position - portailExt.Position).Magnitude
		if distance <= RAYON_EXT and portailExt.CFrame:PointToObjectSpace(position).Z < 0 then return fenetreInt, distance end
		return nil
	end
	local actives = {} -- [personnage] = { modele, pieces = { [original] = copie }, fenetre }
	local function creerSilhouette(perso, fenetre)
		local modele = Instance.new("Model")
		modele.Name = "Silhouette"
		local pieces, nombre = {}, 0
		for _, objet in perso:GetDescendants() do
			if nombre >= 24 then break end
			if objet:IsA("BasePart") and objet.Transparency < 1 and objet.Name ~= "HumanoidRootPart" then
				local piece = Instance.new("Part")
				piece.Size = objet.Size
				piece.CFrame = objet.CFrame
				piece.Anchored = true
				piece.CanCollide = false
				piece.CastShadow = false
				piece.Material = Enum.Material.SmoothPlastic
				piece.Color = COULEUR
				piece.Parent = modele
				pieces[objet] = piece
				nombre += 1
			end
		end
		modele.Parent = dossierDe(fenetre)
		return { modele = modele, pieces = pieces, fenetre = fenetre }
	end
	local function retirer(perso)
		local silhouette = actives[perso]
		if silhouette then
			silhouette.modele:Destroy()
			actives[perso] = nil
		end
	end
	task.spawn(function()
		while true do
			task.wait(PERIODE)
			if not porteOuverte() then
				for perso in actives do retirer(perso) end
			else
				majCouleursRotor()
				if os.clock() >= prochaineRecherche then
					prochaineRecherche = os.clock() + 3
					chercherPnj()
				end
				local candidats = {}
				local function ajouter(perso)
					if not perso or not perso.Parent or perso == joueur.Character then return end
					local racine = perso:FindFirstChild("HumanoidRootPart") or perso.PrimaryPart
					if not (racine and racine:IsA("BasePart")) then return end
					local fenetre, distance = vueDe(racine.Position)
					if fenetre then table.insert(candidats, { cle = perso, fenetre = fenetre, distance = distance }) end
				end
				for _, autre in Players:GetPlayers() do ajouter(autre.Character) end
				for _, perso in pnj do ajouter(perso) end
				local gardes = Config.choisirSilhouettes(candidats, MAX)
				for perso in actives do
					if not gardes[perso] then retirer(perso) end
				end
				for _, candidat in candidats do
					if gardes[candidat.cle] then
						local silhouette = actives[candidat.cle]
						if silhouette and silhouette.fenetre ~= candidat.fenetre then
							retirer(candidat.cle) -- passé de l'autre côté de la porte
							silhouette = nil
						end
						if not silhouette then
							actives[candidat.cle] = creerSilhouette(candidat.cle, candidat.fenetre)
						else
							for original, piece in silhouette.pieces do
								if original.Parent then piece.CFrame = original.CFrame end
							end
						end
					end
				end
			end
		end
	end)
end

--------------------------------------------------------------------
-- Mise à jour des vues (après la caméra du joueur)
--------------------------------------------------------------------
RunService:BindToRenderStep("TardisVue_" .. def.Nom, Enum.RenderPriority.Camera.Value + 1, function()
	if not porteOuverte() then
		fenetreExt.vue.Visible = false
		fenetreInt.vue.Visible = false
		voile.Visible = false
		return
	end

	-- Camouflé : pas de salle de contrôle flottant dans le vide vue de dehors
	if exterieur:GetAttribute("Camouflage") then
		fenetreExt.vue.Visible = false
	else
		majFenetre(fenetreExt, portailExt.CFrame, centreAligne(portailInt, portailExt), portailExt.Size)
	end
	majFenetre(fenetreInt, portailInt.CFrame * DEMI_TOUR, centreAligne(portailExt, portailInt) * DEMI_TOUR, portailInt.Size)
	-- (V7.3.5, G-159) voile du bouclier sur la vue de la rue
	if fenetreInt.vue.Visible and bouclierLeve() then
		voile.Visible = true
		voile.BackgroundTransparency = Config.transparenceVoile(os.clock(), VP.TransparenceVoile)
	else
		voile.Visible = false
	end

	if rotorCopie then
		rotorCopie:PivotTo(rotor:GetPivot())
	end
	for original, copie in battantsCopies do
		copie.CFrame = original.CFrame
	end
end)

--------------------------------------------------------------------
-- Portes intérieures : cachées quand la porte du TARDIS est ouverte
--------------------------------------------------------------------
local portesInt = interieur:FindFirstChild(NOM_PORTES_INT)
--------------------------------------------------------------------
-- (V6.9.14) Portes intérieures animées : si PortesInterieures est rangé en deux Models « Gauche » et « Droite » (chacun
-- avec une Part « Charniere » sur l'axe, sinon son PrimaryPart), chaque battant tourne autour de sa charnière en même
-- temps que le battant extérieur du même côté (LeftOpen / RightOpen de TARDISDoors ; sans eux : PorteOuverte). Tout se
-- passe chez le joueur (comme le masquage), seulement TARDIS posé et porte assez grande. Le battant ne bloque plus le
-- passage dès qu'il commence à s'ouvrir, et redevient solide une fois refermé. Rangement absent ou incomplet : le
-- masquage d'avant (plus bas) est gardé.
--------------------------------------------------------------------
local REGLAGES_PORTES = Config.PortesInterieuresAnimees or {}
local function charniereDe(modele)
	if not (modele and modele:IsA("Model")) then return nil end
	local charniere = modele:FindFirstChild("Charniere", true)
	if charniere and charniere:IsA("BasePart") then return charniere end
	return modele.PrimaryPart
end
local battantsAnimes = nil
if portesInt then
	local gauche, droite = portesInt:FindFirstChild("Gauche"), portesInt:FindFirstChild("Droite")
	if charniereDe(gauche) and charniereDe(droite) then
		battantsAnimes = { { modele = gauche, valeur = "LeftOpen", signe = 1 }, { modele = droite, valeur = "RightOpen", signe = -1 } }
	elseif gauche or droite then
		warn("[TARDIS] " .. def.Nom .. " : " .. NOM_PORTES_INT .. " doit contenir deux Models « Gauche » et « Droite », chacun avec une Part « Charniere » : portes intérieures seulement cachées.")
	end
end
if battantsAnimes then
	local duree = math.max(tonumber(REGLAGES_PORTES.Duree) or 0.5, 0.05)
	local function etatPermet()
		return exterieur:GetAttribute("Etat") == E.Pose and (exterieur:GetAttribute("Echelle") or 1) >= SEUIL_PORTES - 0.001
	end
	for _, battant in battantsAnimes do
		local modele = battant.modele
		local angleAttribut = modele:GetAttribute(REGLAGES_PORTES.AttributAngle or "Angle") -- posé dans Studio (facultatif)
		battant.angleMax = math.rad(type(angleAttribut) == "number" and angleAttribut or battant.signe * (tonumber(REGLAGES_PORTES.Angle) or 90))
		battant.ouverture = 0 -- 0 = fermé, 1 = grand ouvert
		battant.collisions = {}
		for _, objet in modele:GetDescendants() do
			if objet:IsA("BasePart") then battant.collisions[objet] = objet.CanCollide end
		end
		local function valeurOuvert()
			local valeur = dossierPortes and dossierPortes:FindFirstChild(battant.valeur)
			if valeur and valeur:IsA("BoolValue") then return valeur.Value == true end
			return exterieur:GetAttribute("PorteOuverte") == true
		end
		local function poser(t)
			-- Rotation autour de l'axe vertical de la charnière, depuis la position fermée retenue
			local axe = battant.charniereFermee * CFrame.Angles(0, battant.angleMax * t, 0)
			modele:PivotTo(axe * battant.relatif)
		end
		local function solide(oui)
			for objet, origine in battant.collisions do
				if objet.Parent then objet.CanCollide = oui and origine end
			end
		end
		local enMouvement = false
		local function animer()
			if enMouvement then return end
			enMouvement = true
			local precedent = os.clock()
			while true do
				local cible = (etatPermet() and valeurOuvert()) and 1 or 0
				if battant.ouverture == cible then break end
				if battant.ouverture == 0 then
					-- Position fermée relue à chaque ouverture (l'intérieur a pu être déplacé)
					local charniere = charniereDe(modele)
					if not charniere then break end -- charnière retirée : le battant reste où il est
					battant.charniereFermee = charniere.CFrame
					battant.relatif = battant.charniereFermee:Inverse() * modele:GetPivot()
					solide(false)
				end
				task.wait()
				local maintenant = os.clock()
				local pas = math.max(maintenant - precedent, 1 / 60) / duree
				precedent = maintenant
				battant.ouverture = cible > battant.ouverture and math.min(battant.ouverture + pas, 1) or math.max(battant.ouverture - pas, 0)
				poser(battant.ouverture)
				if battant.ouverture == 0 then solide(true) end
			end
			enMouvement = false
		end
		battant.animer = animer
		local valeur = dossierPortes and dossierPortes:FindFirstChild(battant.valeur)
		if valeur and valeur:IsA("BoolValue") then
			valeur.Changed:Connect(function() task.spawn(animer) end)
		end
		for _, attribut in { "PorteOuverte", "Etat", "Echelle" } do
			exterieur:GetAttributeChangedSignal(attribut):Connect(function() task.spawn(animer) end)
		end
		task.spawn(animer)
	end
end
if portesInt and not battantsAnimes then
	local origines = {}
	for _, objet in portesInt:GetDescendants() do
		if objet:IsA("BasePart") then
			origines[objet] = { objet.Transparency, objet.CanCollide }
		elseif objet:IsA("Decal") then
			origines[objet] = { objet.Transparency }
		end
	end

	local function majPortesInt()
		local cacher = porteOuverte()
		for objet, origine in origines do
			objet.Transparency = cacher and 1 or origine[1]
			if objet:IsA("BasePart") then
				objet.CanCollide = (not cacher) and origine[2]
			end
		end
	end

	exterieur:GetAttributeChangedSignal("PorteOuverte"):Connect(majPortesInt)
	exterieur:GetAttributeChangedSignal("Etat"):Connect(majPortesInt)
	majPortesInt()
end

--------------------------------------------------------------------
-- Passage sans coupure (avant la caméra du joueur, pour éviter tout saut d'image)
--------------------------------------------------------------------
local zPrecExt, zPrecInt = nil, nil

local function dansCadre(p, taille)
	return math.abs(p.X) <= taille.X / 2 and math.abs(p.Y) <= taille.Y / 2 + 1
end

local function traverser(personnage, depuis, vers)
	local decalage = vers * depuis:Inverse()
	local racine = personnage.HumanoidRootPart
	local vitesse = racine.AssemblyLinearVelocity

	personnage:PivotTo(decalage * personnage:GetPivot())
	racine.AssemblyLinearVelocity = decalage:VectorToWorldSpace(vitesse)

	-- Si on arrive dans un mur, un battant ou la console, on avance par petits pas vers l'intérieur de la pièce
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { personnage }
	params.RespectCanCollide = true
	for pas = 1, 8 do
		local genant = false
		for _, part in workspace:GetPartBoundsInBox(racine.CFrame, Vector3.new(2, 4.5, 1.6), params) do
			if part.CanCollide then genant = true break end
		end
		if not genant then break end
		-- "vers" regarde vers la sortie (face Front du Portail) : l'intérieur de la pièce est derrière
		personnage:PivotTo(personnage:GetPivot() * CFrame.new(0, 0, 0) + vers.LookVector * -0.75)
		if pas == 8 then personnage:PivotTo(personnage:GetPivot() + Vector3.new(0, 1, 0)) end
	end

	-- La caméra subit le même décalage : le joueur ne voit pas la téléportation
	camera.CFrame = decalage * camera.CFrame
	camera.Focus = decalage * camera.Focus
end

RunService:BindToRenderStep("TardisPassage_" .. def.Nom, Enum.RenderPriority.Camera.Value - 1, function()
	local personnage = joueur.Character
	local racine = personnage and personnage:FindFirstChild("HumanoidRootPart")
	if not racine then
		zPrecExt, zPrecInt = nil, nil
		return
	end

	local pExt = portailExt.CFrame:PointToObjectSpace(racine.Position)
	local pInt = portailInt.CFrame:PointToObjectSpace(racine.Position)

	if porteOuverte() then
		-- Entrée : passe de devant (Z < 0) à derrière (Z >= 0) la porte extérieure
		if zPrecExt and zPrecExt < 0 and pExt.Z >= 0 and dansCadre(pExt, portailExt.Size) then
			traverser(personnage, repereSol(portailExt), repereSol(portailInt))
			zPrecExt, zPrecInt = nil, nil
			return
		end
		-- Sortie : passe de derrière (Z > 0) à devant (Z <= 0) la porte intérieure
		if zPrecInt and zPrecInt > 0 and pInt.Z <= 0 and dansCadre(pInt, portailInt.Size) then
			traverser(personnage, repereSol(portailInt), repereSol(portailExt))
			zPrecExt, zPrecInt = nil, nil
			return
		end
	end

	zPrecExt, zPrecInt = pExt.Z, pInt.Z
end)