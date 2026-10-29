-- TARDIS > TARDISDoors > LeftDoor > Shut (Script)
-- Remplace entièrement l'ancien script Shut du battant GAUCHE.
-- - Ferme le battant automatiquement avant le décollage (attribut "FermerPortes")
-- - L'ouvre automatiquement quand un joueur veut sortir (attribut "OuvrirPorte"), sauf si la porte est verrouillée

local door = script.Parent
local portes = door.Parent                      -- TARDISDoors
local tardis = portes.Parent -- le Model du TARDIS (celui qui contient TARDISDoors), quel que soit son nom

local VALEUR_OUVERT = portes:WaitForChild("LeftOpen")
local VERROU = portes:WaitForChild("Locked")

-- Réglages
local ANGLE_FERMETURE = -0.075                  -- même valeur que l'ancien script (inverser le signe si le battant tourne du mauvais côté)
local OUVRIR_POUR_SORTIR = true            -- ce battant s'ouvre tout seul quand un joueur veut sortir

local enMouvement = false

-- Fait tourner toutes les pièces du battant autour d'un centre (même méthode que l'ancien script)
local function rotateMod(mod, center, rotation)
	local parts = {}
	local function scan(parent)
		for _, obj in parent:GetChildren() do
			if obj:IsA("BasePart") then
				table.insert(parts, obj)
			end
			scan(obj)
		end
	end
	scan(mod)
	for _, part in parts do
		part.CFrame = center * rotation * (center:Inverse() * part.CFrame)
	end
end

local function animer(angle)
	for _ = 0, 20 do
		rotateMod(door, door:GetModelCFrame(), CFrame.Angles(0, angle, 0))
		task.wait()
	end
end

local function jouerSon(nom)
	local poignee = door:FindFirstChild("Handle")
	local son = poignee and poignee:FindFirstChild(nom)
	if son and son:IsA("Sound") then
		son:Play()
	end
end

local function fermer()
	if enMouvement or VALEUR_OUVERT.Value == false then return end
	enMouvement = true
	VALEUR_OUVERT.Value = false
	jouerSon("SnapClose")
	animer(ANGLE_FERMETURE)
	enMouvement = false
end

local function ouvrir()
	if enMouvement or VALEUR_OUVERT.Value == true or VERROU.Value == true then return end
	enMouvement = true
	VALEUR_OUVERT.Value = true
	jouerSon("SnapOpen")
	animer(-ANGLE_FERMETURE)
	enMouvement = false
end

-- Fermeture automatique avant le décollage
tardis:GetAttributeChangedSignal("FermerPortes"):Connect(function()
	if tardis:GetAttribute("FermerPortes") then
		task.wait(0.1)
		fermer()
	end
end)

-- Ouverture automatique quand un joueur veut sortir
if OUVRIR_POUR_SORTIR then
	tardis:GetAttributeChangedSignal("OuvrirPorte"):Connect(function()
		if tardis:GetAttribute("OuvrirPorte") then
			task.wait(0.1)
			ouvrir()
		end
	end)
end