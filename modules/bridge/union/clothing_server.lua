-- modules/bridge/union/clothing_server.lua  v4
-- Corrections v4 :
--   [FIX-NUI-1] outfit stocke désormais { drawable, texture, palette, name, label }
--               par slot → le client peut reconstruire l'état Redux clothing
--               sans avoir à retrouver le nom de l'item depuis un drawable GTA.
--   [FIX-NUI-2] equipClothing retourne aussi { name, label } pour clothingEquipped NUI.
--   [FIX-NUI-3] equipOutfit retourne les slots avec name+label pour outfitEquipped NUI.
-- Conserve tous les fixes précédents (v3).

if not lib then return end

-- Lazy loading pour éviter les dépendances circulaires
local Inventory, Items

local function getInventory()
    Inventory = Inventory or require 'modules.inventory.server'
    return Inventory
end

local function getItems()
    Items = Items or require 'modules.items.server'
    return Items
end

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
-- INITIALISATION TABLE
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
-- [FIX-NUI-1] CONVERSION outfit → EquippedClothing (format Redux React)
--
-- L'outfit stocké en BDD contient des champs GTA (drawable, texture, palette)
-- + les champs NUI (name, label) ajoutés en v4.
-- Cette fonction construit l'objet EquippedClothing attendu par index.tsx :
--   { [slotName]: { name, label, itemType } }
-- ─────────────────────────────────────────────────────────────

---@param outfit table
---@return table EquippedClothing pour SendNUIMessage setupClothing
local function outfitToEquipped(outfit)
    local equipped = {}
    for slotName, slotData in pairs(outfit) do
        if slotData.name then  -- [FIX-NUI-1] champ stocké depuis v4
            equipped[slotName] = {
                name     = slotData.name,
                label    = slotData.label or slotName,
                itemType = 'clothing',
            }
        end
    end
    return equipped
end

-- ─────────────────────────────────────────────────────────────
-- CALLBACKS lib.callback.register
-- Signature ox_lib correcte : function(source, arg1, arg2, ...)
-- Retour direct (sync) ou Citizen.Await(promise) pour async.
-- ─────────────────────────────────────────────────────────────

-- Retourne l'outfit complet + l'état EquippedClothing pour le NUI
lib.callback.register('kt_inventory:getOutfit', function(source)
    local inv = getInventory()(source)
    if not inv or not inv.player then return nil, nil end
    local uniqueId = inv.owner
    if not uniqueId then return nil, nil end
    local outfit = loadOutfit(uniqueId)
    -- [FIX-NUI-1] Retourne aussi l'état NUI pour que le client puisse
    -- envoyer setupClothing au React sans conversion supplémentaire
    local equipped = outfit and outfitToEquipped(outfit) or nil
    return outfit, equipped
end)

lib.callback.register('kt_inventory:equipClothing', function(source, slotId, metadata)
    if type(slotId)   ~= 'number' then return false, 'invalid_slot'     end
    if type(metadata) ~= 'table'  then return false, 'invalid_metadata' end

    local inv = getInventory()(source)
    if not inv or not inv.player then return false, 'no_inventory' end

    local slotData = inv.items[slotId]
    if not slotData then return false, 'slot_empty' end

    local item = getItems()(slotData.name)
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

    -- [FIX-NUI-1] Stocker name + label avec les données GTA
    -- → permet à outfitToEquipped() de reconstruire l'état Redux au prochain spawn
    outfit[clothingSlot] = {
        drawable = math.floor(metadata.drawable),
        texture  = math.floor(metadata.texture),
        palette  = metadata.palette and math.floor(metadata.palette) or 0,
        name     = slotData.name,           -- [FIX-NUI-1]
        label    = item.label or slotData.name, -- [FIX-NUI-1]
    }

    saveOutfit(uniqueId, outfit)
    TriggerClientEvent('kt_inventory:outfitUpdated', source, outfit)

    -- [FIX-NUI-2] Retourner aussi les infos NUI pour clothingEquipped
    return true, outfit, {
        category = clothingSlot,
        name     = slotData.name,
        label    = item.label or slotData.name,
        itemType = 'clothing',
    }
end)

lib.callback.register('kt_inventory:equipOutfit', function(source, slotId)
    if type(slotId) ~= 'number' then return false, 'invalid_slot' end

    local inv = getInventory()(source)
    if not inv or not inv.player then return false, 'no_inventory' end

    local slotData = inv.items[slotId]
    if not slotData then return false, 'slot_empty' end

    local item = getItems()(slotData.name)
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

    -- [FIX-NUI-3] Construire slots pour outfitEquipped NUI
    local nuiSlots = {}
    for slotName, slotDataItem in pairs(outfitData) do
        if slotDataItem.name then
            nuiSlots[slotName] = {
                name  = slotDataItem.name,
                label = slotDataItem.label or slotName,
            }
        end
    end

    return true, outfitData, {
        name   = item.label or slotData.name,
        label  = item.label or slotData.name,
        slots  = nuiSlots,
    }
end)

lib.callback.register('kt_inventory:removeClothingSlot', function(source, clothingSlot)
    if type(clothingSlot) ~= 'string'        then return false end
    if not VALID_CLOTHING_SLOTS[clothingSlot] then return false end

    local inv = getInventory()(source)
    if not inv or not inv.player then return false end

    local uniqueId = inv.owner
    local outfit   = loadOutfit(uniqueId) or {}

    outfit[clothingSlot] = nil
    saveOutfit(uniqueId, outfit)
    TriggerClientEvent('kt_inventory:outfitUpdated', source, outfit)

    return true
end)

-- ─────────────────────────────────────────────────────────────
-- DISCONNECT
-- ─────────────────────────────────────────────────────────────

AddEventHandler('playerDropped', function()
    local inv = getInventory()(source)
    if inv and inv.owner then
        outfitCache[inv.owner] = nil
    end
end)

-- ─────────────────────────────────────────────────────────────
-- EXPORTS
-- ─────────────────────────────────────────────────────────────

exports('GetPlayerOutfit', function(source)
    local inv = getInventory()(source)
    if not inv or not inv.owner then return nil end
    return outfitCache[inv.owner]
end)

exports('GetPlayerEquipped', function(source)
    local inv = getInventory()(source)
    if not inv or not inv.owner then return nil end
    local outfit = outfitCache[inv.owner]
    return outfit and outfitToEquipped(outfit) or nil
end)

exports('SetPlayerOutfit', function(source, outfitData)
    if type(outfitData) ~= 'table' then return false end
    local ok, reason = validateOutfit(outfitData)
    if not ok then
        lib.print.warn(('[kt_inventory:clothing] SetPlayerOutfit invalide: %s'):format(reason))
        return false
    end
    local inv = getInventory()(source)
    if not inv or not inv.owner then return false end
    saveOutfit(inv.owner, outfitData)
    TriggerClientEvent('kt_inventory:outfitUpdated', source, outfitData)
    return true
end)

exports('ValidateClothingMetadata', function(metadata, clothingSlot)
    return validateClothingMetadata(metadata, clothingSlot)
end)

lib.print.info('^2[kt_inventory] Clothing server v4 chargé^0')