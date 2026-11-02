-- ServerScriptService > TardisSauvegarde (ModuleScript) — V6.8.1
-- Sauvegarde versionnée (modification 25) : toutes les données du TARDIS passent par ce module.
--   • Chaque valeur est rangée dans une enveloppe { format, donnees, ecrit, version } : le format peut évoluer,
--     une migration le met à jour à la lecture, et on sait quelle version du TARDIS l'a écrite.
--   • Les anciens magasins (TardisSauvegarde_v1_*, TardisExtras_v1_*) ne sont jamais modifiés ni effacés :
--     à la première lecture d'une clé absente du nouveau magasin, l'ancienne valeur est recopiée (migration
--     paresseuse, sans perte, et un retour en arrière reste possible).
--   • Lectures et écritures sont réessayées 3 fois (le service DataStore échoue parfois), et les écritures passent
--     par UpdateAsync.
-- Utilisation :
--   local magasin = require(...TardisSauvegarde).ouvrir("TardisSauvegarde_v2_TARDIS_1", "TardisSauvegarde_v1_TARDIS_1")
--   local donnees = magasin:lire("place_123")
--   magasin:ecrire("place_123", donnees)

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("TardisConfig"))

local Sauvegarde = {}
Sauvegarde.FORMAT = 2

-- Migrations : MIGRATIONS[n] transforme des données au format n en format n + 1.
-- Le format 1 (avant la V6.8.1) n'avait pas d'enveloppe ; son contenu est repris tel quel.
Sauvegarde.MIGRATIONS = {
	[1] = function(donnees) return donnees end,
}

local function reessayer(fonction)
	local derniereErreur
	for essai = 1, 3 do
		local ok, resultat = pcall(fonction)
		if ok then return true, resultat end
		derniereErreur = resultat
		task.wait(essai) -- 1 s, puis 2 s
	end
	return false, derniereErreur
end

local function migrer(donnees, format)
	format = tonumber(format) or 1
	while format < Sauvegarde.FORMAT do
		local migration = Sauvegarde.MIGRATIONS[format]
		if migration then donnees = migration(donnees) end
		format += 1
	end
	return donnees
end

local function envelopper(valeur)
	return { format = Sauvegarde.FORMAT, donnees = valeur, ecrit = os.time(), version = tostring(Config.Version or "?") }
end

local Magasin = {}
Magasin.__index = Magasin

-- nom : le magasin actuel ; ancien (optionnel) : le magasin d'avant, lu seulement pour migrer
function Sauvegarde.ouvrir(nom, ancien)
	local magasin = setmetatable({ nom = nom }, Magasin)
	local ok, store = pcall(DataStoreService.GetDataStore, DataStoreService, nom)
	if ok then magasin.store = store else warn("[TARDIS] Sauvegarde « " .. nom .. " » indisponible : " .. tostring(store)) end
	if ancien then
		local okAncien, storeAncien = pcall(DataStoreService.GetDataStore, DataStoreService, ancien)
		if okAncien then magasin.ancien = storeAncien end
	end
	return magasin
end

function Magasin:disponible()
	return self.store ~= nil
end

-- Renvoie la valeur (déjà migrée au format actuel), ou nil. Deuxième valeur : faux si la lecture a échoué
-- (pour ne pas écraser une sauvegarde qu'on n'a pas pu lire).
function Magasin:lire(cle)
	if not self.store then return nil, false end
	local ok, valeur = reessayer(function() return self.store:GetAsync(cle) end)
	if not ok then
		warn(string.format("[TARDIS] Lecture impossible (%s / %s) : %s", self.nom, cle, tostring(valeur)))
		return nil, false
	end
	if type(valeur) == "table" and valeur.format ~= nil and valeur.donnees ~= nil then
		return migrer(valeur.donnees, valeur.format), true
	end
	if valeur ~= nil then return migrer(valeur, 1), true end -- valeur écrite sans enveloppe
	-- Absente : on regarde dans l'ancien magasin, et on recopie
	if not self.ancien then return nil, true end
	local okAncien, ancienne = reessayer(function() return self.ancien:GetAsync(cle) end)
	if not okAncien then
		warn(string.format("[TARDIS] Lecture de l'ancienne sauvegarde impossible (%s) : %s", cle, tostring(ancienne)))
		return nil, false
	end
	if ancienne == nil then return nil, true end
	local migree = migrer(ancienne, 1)
	task.spawn(function()
		if self:ecrire(cle, migree) then
			print(string.format("[TARDIS] Sauvegarde migrée vers %s : %s.", self.nom, cle))
		end
	end)
	return migree, true
end

-- Renvoie vrai si l'écriture a réussi
function Magasin:ecrire(cle, valeur)
	if not self.store then return false end
	local ok, erreur = reessayer(function()
		self.store:UpdateAsync(cle, function() return envelopper(valeur) end)
	end)
	if not ok then warn(string.format("[TARDIS] Écriture impossible (%s / %s) : %s", self.nom, cle, tostring(erreur))) end
	return ok
end

return Sauvegarde
