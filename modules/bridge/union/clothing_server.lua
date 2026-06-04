-- modules/bridge/union/clothing_server.lua
-- Persistance et validation côté serveur du système de vêtements
-- Problèmes résolus :
--   - Aucune validation serveur des composants/props GTA
--   - Pas de sauvegarde persistante de la tenue dans la DB
--   - Pas de sync entre joueurs proches
--   - Pas de protection contre l'équipement de tenues invalides

if not lib then return end

local Inventory = require 'modules.inventory.server'
local Items     = require 'modules.items.server'

-- ─────────────────────────────────────────────────────────────
-- CONSTANTES GTA V
-- Plages valides pour composants et props
-- ─────────────────────────────────────────────────────────────

-- Slots composants valides (0-11)
local VALID_COMPONENT_SLOTS = {
    [0]  = true,  -- head / face
    [1]  = true,  -- beard / mask overlay
    [2]  = true,  -- hair
    [3]  = true,  -- torso
    [4]  = true,  -- legs
    [5]  = true,  -- hands / parachute bag
    [6]  = true,  -- feet
    [7]  = true,  -- accessories
    [8]  = true,  -- undershirt
    [9]  = true,  -- body armor
    [10] = true,  -- decals
    [11] = true,  -- top
}

-- Slots props valides (0-9)
local VALID_PROP_SLOTS = {
    [0] = true,  -- hats
    [1] = true,  -- glasses
    [2] = true,  -- ears
    [6] = true,  -- watches
    [7] = true,  -- bracelets
}

-- Slots clothing items valides (depuis items_clothing.lua)
local VALID_CLOTHING_SLOTS = {
    hat        = { type = 'prop',      slot = 0  },
    mask       = { type = 'component', slot = 1  },
    glasses    = { type = 'prop',      slot = 1  },
    top        = { type = 'component', slot = 11 },
    undershirt = { type = 'component', slot = 8  },
    pants      = { type = 'component', slot = 4  },
    shoes      = { type = 'component', slot = 6  },
    bag        = { type = 'component', slot = 5  },
    armor      = { type = 'component', slot = 9  },
    watch      = { type = 'prop',      slot = 6  },
    bracelet   = { type = 'prop',      slot = 7  },
    chain      = { type = 'component', slot = 7  },
    gloves     = { type = 'component', slot = 3  },
}

-- ─────────────────────────────────────────────────────────────
-- VALIDATION
-- ─────────────────────────────────────────────────────────────

---@param metadata table
---@param clothingSlot string
---@return boolean valid, string? reason
local function validateClothingMetadata(metadata, clothingSlot)
    if type(metadata) ~= 'table' then
        return false, 'metadata must be a table'
    end

    local slotDef = VALID_CLOTHING_SLOTS[clothingSlot]
    if not slotDef then
        return false, ('unknown clothingSlot: %s'):format(tostring(clothingSlot))
    end

    -- drawable doit être un entier >= 0
    if type(metadata.drawable) ~= 'number' or metadata.drawable < 0 or math.floor(metadata.drawable) ~= metadata.drawable then
        return false, 'drawable must be a non-negative integer'
    end

    -- texture doit être un entier >= 0
    if type(metadata.texture) ~= 'number' or metadata.texture < 0 or math.floor(metadata.texture) ~= metadata.texture then
        return false, 'texture must be a non-negative integer'
    end

    -- Limites raisonnables anti-exploit
    if metadata.drawable > 512 then
        return false, ('drawable out of range: %d'):format(metadata.drawable)
    end

    if metadata.texture > 32 then
        return false, ('texture out of range: %d'):format(metadata.texture)
    end

    -- palette optionnel
    if metadata.palette ~= nil then
        if type(metadata.palette) ~= 'number' or metadata.palette < 0 or metadata.palette > 3 then
            return false, 'palette must be 0-3'
        end
    end

    return true
end

---@param outfitData table  { hat = {drawable, texture}, ... }
---@return boolean valid, string? reason
local function validateOutfit(outfitData)
    if type(outfitData) ~= 'table' then
        return false, 'outfitData must be a table'
    end

    for slotName, slotData in pairs(outfitData) do
        if not VALID_CLOTHING_SLOTS[slotName] then
            return false, ('unknown slot in outfit: %s'):format(tostring(slotName))
        end

        local ok, reason = validateClothingMetadata(slotData, slotName)
        if not ok then
            return false, ('slot %s: %s'):format(slotName, reason)
        end
    end

    return true
end

-- ─────────────────────────────────────────────────────────────
-- PERSISTANCE
-- Table : kt_clothing
-- Colonnes : unique_id (PK), outfit (JSON), updated_at
-- ─────────────────────────────────────────────────────────────

-- Création de la table si inexistante
Citizen.CreateThreadNow(function()
    Wait(1000) -- Attendre oxmysql

    local ok = pcall(MySQL.scalar.await, 'SELECT 1 FROM kt_clothing LIMIT 1')

    if not ok then
        MySQL.query([[
            CREATE TABLE IF NOT EXISTS `kt_clothing` (
                `unique_id`  VARCHAR(64)  NOT NULL,
                `outfit`     LONGTEXT     DEFAULT NULL,
                `updated_at` TIMESTAMP    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (`unique_id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]])
        lib.print.info('[kt_inventory:clothing] Table kt_clothing créée.')
    end
end)

-- Cache en mémoire des tenues actives (évite N requêtes DB par session)
---@type table<string, table>  uniqueId → outfitData
local outfitCache = {}

---@param uniqueId string
---@return table|nil
local function loadOutfit(uniqueId)
    if outfitCache[uniqueId] then
        return outfitCache[uniqueId]
    end

    local result = MySQL.scalar.await(
        'SELECT outfit FROM kt_clothing WHERE unique_id = ?',
        { uniqueId }
    )

    if result then
        local decoded = json.decode(result)
        if decoded then
            outfitCache[uniqueId] = decoded
            return decoded
        end
    end

    return nil
end

---@param uniqueId string
---@param outfitData table
local function saveOutfit(uniqueId, outfitData)
    outfitCache[uniqueId] = outfitData

    MySQL.query(
        [[INSERT INTO kt_clothing (unique_id, outfit)
          VALUES (?, ?)
          ON DUPLICATE KEY UPDATE outfit = VALUES(outfit), updated_at = CURRENT_TIMESTAMP]],
        { uniqueId, json.encode(outfitData) }
    )
end

-- ─────────────────────────────────────────────────────────────
-- CALLBACKS NET
-- ─────────────────────────────────────────────────────────────

-- Chargement de la tenue au spawn
lib.callback.register('kt_inventory:getOutfit', function(source)
    local inv = Inventory(source)
    if not inv?.player then return end

    local uniqueId = inv.owner
    if not uniqueId then return end

    return loadOutfit(uniqueId)
end)

-- Équipement d'un vêtement (pièce individuelle)
lib.callback.register('kt_inventory:equipClothing', function(source, slotId, metadata)
    if type(slotId) ~= 'number' then return false, 'invalid_slot' end
    if type(metadata) ~= 'table' then return false, 'invalid_metadata' end

    local inv = Inventory(source)
    if not inv?.player then return false, 'no_inventory' end

    local slotData = inv.items[slotId]
    if not slotData then return false, 'slot_empty' end

    local item = Items(slotData.name)
    if not item then return false, 'invalid_item' end

    -- Vérifie que c'est bien un item clothing
    if item.category ~= 'clothing' then
        return false, 'not_clothing'
    end

    local clothingSlot = item.clothingSlot
    if not clothingSlot then return false, 'no_clothing_slot' end

    -- Validation des métadonnées
    local ok, reason = validateClothingMetadata(metadata, clothingSlot)
    if not ok then
        lib.print.warn(('[kt_inventory:clothing] Validation échouée player %d: %s'):format(source, reason))
        return false, 'invalid_metadata'
    end

    -- Mise à jour de la tenue persistée
    local uniqueId = inv.owner
    local outfit   = loadOutfit(uniqueId) or {}

    outfit[clothingSlot] = {
        drawable = math.floor(metadata.drawable),
        texture  = math.floor(metadata.texture),
        palette  = metadata.palette and math.floor(metadata.palette) or 0,
    }

    saveOutfit(uniqueId, outfit)

    -- Sync aux joueurs proches (pour voir la tenue des autres)
    TriggerClientEvent('kt_inventory:outfitUpdated', source, outfit)

    return true, outfit
end)

-- Équipement d'une tenue complète
lib.callback.register('kt_inventory:equipOutfit', function(source, slotId)
    if type(slotId) ~= 'number' then return false, 'invalid_slot' end

    local inv = Inventory(source)
    if not inv?.player then return false, 'no_inventory' end

    local slotData = inv.items[slotId]
    if not slotData then return false, 'slot_empty' end

    local item = Items(slotData.name)
    if not item then return false, 'invalid_item' end

    if item.category ~= 'clothing_tenu' then
        return false, 'not_outfit'
    end

    -- L'outfit complet est dans les métadonnées de l'item
    local outfitData = slotData.metadata?.outfit
    if not outfitData then return false, 'no_outfit_data' end

    local ok, reason = validateOutfit(outfitData)
    if not ok then
        lib.print.warn(('[kt_inventory:clothing] Outfit invalide player %d: %s'):format(source, reason))
        return false, 'invalid_outfit'
    end

    local uniqueId = inv.owner
    saveOutfit(uniqueId, outfitData)

    TriggerClientEvent('kt_inventory:outfitUpdated', source, outfitData)

    return true, outfitData
end)

-- Retrait d'un slot vêtement
lib.callback.register('kt_inventory:removeClothingSlot', function(source, clothingSlot)
    if type(clothingSlot) ~= 'string' then return false end
    if not VALID_CLOTHING_SLOTS[clothingSlot] then return false end

    local inv = Inventory(source)
    if not inv?.player then return false end

    local uniqueId = inv.owner
    local outfit   = loadOutfit(uniqueId) or {}

    outfit[clothingSlot] = nil
    saveOutfit(uniqueId, outfit)

    TriggerClientEvent('kt_inventory:outfitUpdated', source, outfit)
    return true
end)

-- ─────────────────────────────────────────────────────────────
-- NETTOYAGE AU DISCONNECT
-- ─────────────────────────────────────────────────────────────

AddEventHandler('playerDropped', function()
    local src = source
    local inv  = Inventory(src)

    if inv?.owner then
        outfitCache[inv.owner] = nil
    end
end)

-- ─────────────────────────────────────────────────────────────
-- EXPORT PUBLIC
-- ─────────────────────────────────────────────────────────────

exports('GetPlayerOutfit', function(source)
    local inv = Inventory(source)
    if not inv?.owner then return nil end
    return loadOutfit(inv.owner)
end)

exports('SetPlayerOutfit', function(source, outfitData)
    if type(outfitData) ~= 'table' then return false end

    local ok, reason = validateOutfit(outfitData)
    if not ok then
        lib.print.warn(('[kt_inventory:clothing] SetPlayerOutfit invalide: %s'):format(reason))
        return false
    end

    local inv = Inventory(source)
    if not inv?.owner then return false end

    saveOutfit(inv.owner, outfitData)
    TriggerClientEvent('kt_inventory:outfitUpdated', source, outfitData)
    return true
end)

exports('ValidateClothingMetadata', function(metadata, clothingSlot)
    return validateClothingMetadata(metadata, clothingSlot)
end)

lib.print.info('^2[kt_inventory] Clothing server chargé^0')
