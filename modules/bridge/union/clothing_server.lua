-- modules/bridge/union/clothing_server.lua
-- Corrections :
--   [FIX-1] Citizen.CreateThreadNow + await → MySQL.query avec callback via onResourceStart
--   [FIX-2] lib.callback.register : signature corrigée.
--           L'ancienne version utilisait function(source, cb, ...) qui est FAUSSE dans ox_lib.
--           ox_lib ne passe PAS de cb — il attend un RETOUR de la fonction (sync)
--           ou Citizen.Await(promise) pour l'async.
--           Tous les callbacks qui font du MySQL utilisent désormais promise + Citizen.Await.
--   [FIX-3] loadOutfitAsync remplacé par loadOutfitSync (via MySQL.scalar.await dans promise)
--   [FIX-4] outfitCache invalidé au playerDropped
--   [FIX-5] Limites drawable/texture étendues pour DLC (1024/64)

if not lib then return end

local Inventory = require 'modules.inventory.server'
local Items     = require 'modules.items.server'

-- ─────────────────────────────────────────────────────────────
-- CONSTANTES
-- ─────────────────────────────────────────────────────────────

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

local MAX_DRAWABLE = 1024
local MAX_TEXTURE  = 64

-- ─────────────────────────────────────────────────────────────
-- VALIDATION
-- ─────────────────────────────────────────────────────────────

local function validateClothingMetadata(metadata, clothingSlot)
    if type(metadata) ~= 'table' then
        return false, 'metadata must be a table'
    end

    local slotDef = VALID_CLOTHING_SLOTS[clothingSlot]
    if not slotDef then
        return false, ('unknown clothingSlot: %s'):format(tostring(clothingSlot))
    end

    if type(metadata.drawable) ~= 'number'
        or metadata.drawable < 0
        or math.floor(metadata.drawable) ~= metadata.drawable then
        return false, 'drawable must be a non-negative integer'
    end

    if type(metadata.texture) ~= 'number'
        or metadata.texture < 0
        or math.floor(metadata.texture) ~= metadata.texture then
        return false, 'texture must be a non-negative integer'
    end

    if metadata.drawable > MAX_DRAWABLE then
        return false, ('drawable out of range: %d (max %d)'):format(metadata.drawable, MAX_DRAWABLE)
    end

    if metadata.texture > MAX_TEXTURE then
        return false, ('texture out of range: %d (max %d)'):format(metadata.texture, MAX_TEXTURE)
    end

    if metadata.palette ~= nil then
        if type(metadata.palette) ~= 'number' or metadata.palette < 0 or metadata.palette > 3 then
            return false, 'palette must be 0-3'
        end
    end

    return true
end

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
-- INITIALISATION TABLE [FIX-1]
-- ─────────────────────────────────────────────────────────────

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    MySQL.query('SELECT 1 FROM kt_clothing LIMIT 1', {}, function(result)
        if not result then
            MySQL.query([[
                CREATE TABLE IF NOT EXISTS `kt_clothing` (
                    `unique_id`  VARCHAR(64)  NOT NULL,
                    `outfit`     LONGTEXT     DEFAULT NULL,
                    `updated_at` TIMESTAMP    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                    PRIMARY KEY (`unique_id`)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            ]], {}, function()
                lib.print.info('[kt_inventory:clothing] Table kt_clothing créée.')
            end)
        end
    end)
end)

-- ─────────────────────────────────────────────────────────────
-- CACHE + PERSISTANCE
-- ─────────────────────────────────────────────────────────────

---@type table<string, table>
local outfitCache = {}

-- [FIX-3] Version synchrone via MySQL.scalar.await dans un contexte Citizen.Await.
-- À appeler UNIQUEMENT depuis un lib.callback.register (contexte schedulable).
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

    if not result then return nil end

    local ok, decoded = pcall(json.decode, result)
    if ok and type(decoded) == 'table' then
        outfitCache[uniqueId] = decoded
        return decoded
    end

    return nil
end

---@param uniqueId string
---@param outfitData table
local function saveOutfit(uniqueId, outfitData)
    outfitCache[uniqueId] = outfitData

    local ok, encoded = pcall(json.encode, outfitData)
    if not ok then
        lib.print.warn(('[kt_inventory:clothing] Échec encodage outfit uid=%s'):format(uniqueId))
        return
    end

    MySQL.query(
        'INSERT INTO kt_clothing (unique_id, outfit) VALUES (?, ?) ON DUPLICATE KEY UPDATE outfit = VALUES(outfit), updated_at = CURRENT_TIMESTAMP',
        { uniqueId, encoded }
    )
end

-- ─────────────────────────────────────────────────────────────
-- CALLBACKS [FIX-2]
-- Signature correcte ox_lib : function(source, arg1, arg2, ...)
-- Pas de cb en paramètre. Pour l'async : Citizen.Await(promise).
-- MySQL.scalar.await est utilisable directement car lib.callback.register
-- s'exécute dans un thread Citizen schedulable.
-- ─────────────────────────────────────────────────────────────

lib.callback.register('kt_inventory:getOutfit', function(source)
    local inv = Inventory(source)
    if not inv or not inv.player then return nil end

    local uniqueId = inv.owner
    if not uniqueId then return nil end

    return loadOutfit(uniqueId)
end)

lib.callback.register('kt_inventory:equipClothing', function(source, slotId, metadata)
    if type(slotId)   ~= 'number' then return false, 'invalid_slot'     end
    if type(metadata) ~= 'table'  then return false, 'invalid_metadata' end

    local inv = Inventory(source)
    if not inv or not inv.player then return false, 'no_inventory' end

    local slotData = inv.items[slotId]
    if not slotData then return false, 'slot_empty' end

    local item = Items(slotData.name)
    if not item then return false, 'invalid_item' end

    if item.category ~= 'clothing' then
        return false, 'not_clothing'
    end

    local clothingSlot = item.clothingSlot
    if not clothingSlot then return false, 'no_clothing_slot' end

    local ok, reason = validateClothingMetadata(metadata, clothingSlot)
    if not ok then
        lib.print.warn(('[kt_inventory:clothing] Validation échouée player %d: %s'):format(source, reason))
        return false, 'invalid_metadata'
    end

    local uniqueId = inv.owner
    local outfit   = loadOutfit(uniqueId) or {}

    outfit[clothingSlot] = {
        drawable = math.floor(metadata.drawable),
        texture  = math.floor(metadata.texture),
        palette  = metadata.palette and math.floor(metadata.palette) or 0,
    }

    saveOutfit(uniqueId, outfit)
    TriggerClientEvent('kt_inventory:outfitUpdated', source, outfit)

    return true, outfit
end)

lib.callback.register('kt_inventory:equipOutfit', function(source, slotId)
    if type(slotId) ~= 'number' then return false, 'invalid_slot' end

    local inv = Inventory(source)
    if not inv or not inv.player then return false, 'no_inventory' end

    local slotData = inv.items[slotId]
    if not slotData then return false, 'slot_empty' end

    local item = Items(slotData.name)
    if not item then return false, 'invalid_item' end

    if item.category ~= 'clothing_tenu' then
        return false, 'not_outfit'
    end

    local outfitData = slotData.metadata and slotData.metadata.outfit
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

lib.callback.register('kt_inventory:removeClothingSlot', function(source, clothingSlot)
    if type(clothingSlot) ~= 'string'         then return false end
    if not VALID_CLOTHING_SLOTS[clothingSlot]  then return false end

    local inv = Inventory(source)
    if not inv or not inv.player then return false end

    local uniqueId = inv.owner
    local outfit   = loadOutfit(uniqueId) or {}

    outfit[clothingSlot] = nil
    saveOutfit(uniqueId, outfit)
    TriggerClientEvent('kt_inventory:outfitUpdated', source, outfit)

    return true
end)

-- ─────────────────────────────────────────────────────────────
-- DISCONNECT [FIX-4]
-- ─────────────────────────────────────────────────────────────

AddEventHandler('playerDropped', function()
    local inv = Inventory(source)
    if inv and inv.owner then
        outfitCache[inv.owner] = nil
    end
end)

-- ─────────────────────────────────────────────────────────────
-- EXPORTS
-- ─────────────────────────────────────────────────────────────

exports('GetPlayerOutfit', function(source)
    local inv = Inventory(source)
    if not inv or not inv.owner then return nil end
    return outfitCache[inv.owner]
end)

exports('SetPlayerOutfit', function(source, outfitData)
    if type(outfitData) ~= 'table' then return false end

    local ok, reason = validateOutfit(outfitData)
    if not ok then
        lib.print.warn(('[kt_inventory:clothing] SetPlayerOutfit invalide: %s'):format(reason))
        return false
    end

    local inv = Inventory(source)
    if not inv or not inv.owner then return false end

    saveOutfit(inv.owner, outfitData)
    TriggerClientEvent('kt_inventory:outfitUpdated', source, outfitData)
    return true
end)

exports('ValidateClothingMetadata', function(metadata, clothingSlot)
    return validateClothingMetadata(metadata, clothingSlot)
end)

lib.print.info('^2[kt_inventory] Clothing server v3 chargé^0')