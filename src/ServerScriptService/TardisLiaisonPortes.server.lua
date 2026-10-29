-- ServerScriptService > TardisLiaisonPortes (Script)
-- Relie les scripts de porte existants (TARDISDoors) au système TARDIS, sans les modifier :
--   LeftOpen / RightOpen  ->  attribut "PorteOuverte" (vue de l'intérieur + passage)
--   attributs "Verrouille" (vol) et "PortesVerrouillees" (menu) ->  Locked

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("TardisConfig"))

local def = Config.demarrerPourChaqueTardis(script) -- un exemplaire par TARDIS
local exterieur = Config.modeles(def)
local portes = exterieur:WaitForChild(Config.NomDossierPortes or "TARDISDoors")
local gaucheOuverte = portes:WaitForChild("LeftOpen")
local droiteOuverte = portes:WaitForChild("RightOpen")
local verrou = portes:WaitForChild("Locked")

local DELAI_FERMETURE = 0.8 -- laisse les battants finir de se fermer avant de couper la vue

--------------------------------------------------------------------
-- Portes -> PorteOuverte
--------------------------------------------------------------------
local compteur = 0

local function majOuverture()
	compteur += 1
	local appel = compteur

	if gaucheOuverte.Value or droiteOuverte.Value then
		exterieur:SetAttribute("PorteOuverte", true)
	else
		task.delay(DELAI_FERMETURE, function()
			-- On ignore si la porte a été rouverte entre-temps
			if appel == compteur then
				exterieur:SetAttribute("PorteOuverte", false)
			end
		end)
	end
end

gaucheOuverte.Changed:Connect(majOuverture)
droiteOuverte.Changed:Connect(majOuverture)
exterieur:SetAttribute("PorteOuverte", gaucheOuverte.Value or droiteOuverte.Value)

--------------------------------------------------------------------
-- Verrouillage -> Locked
-- Locked est vrai si le TARDIS vole (Verrouille) OU si les portes sont verrouillées depuis le menu (PortesVerrouillees)
--------------------------------------------------------------------
if exterieur:GetAttribute("PortesVerrouillees") == nil then
	exterieur:SetAttribute("PortesVerrouillees", verrou.Value) -- état de départ choisi dans Studio
end

local function majVerrou()
	local valeur = exterieur:GetAttribute("Verrouille") == true
		or exterieur:GetAttribute("PortesVerrouillees") == true
	if verrou.Value ~= valeur then
		verrou.Value = valeur
	end
end

-- Si un autre script change Locked pendant que le TARDIS est posé, le menu suit
verrou.Changed:Connect(function()
	if not exterieur:GetAttribute("Verrouille") then
		exterieur:SetAttribute("PortesVerrouillees", verrou.Value)
	end
end)

exterieur:GetAttributeChangedSignal("Verrouille"):Connect(majVerrou)
exterieur:GetAttributeChangedSignal("PortesVerrouillees"):Connect(majVerrou)
majVerrou()