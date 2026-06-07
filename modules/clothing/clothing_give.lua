-- ============================================================
-- clothing_give.lua — helpers serveur pour donner des vêtements
-- ============================================================

local ClothingMetadata = require 'modules.clothing.clothing_metadata'

---Donne un vêtement à un joueur avec les metadata correctes
---@param source number
---@param itemName string   ex: 'clothing_m_jbib_23'
---@param textureIndex? number  défaut: 0
---@return boolean, string?
local function GiveClothing(source, itemName, textureIndex)
    local meta = ClothingMetadata[itemName]
    if not meta then return false, 'item_not_found' end

    textureIndex = textureIndex or 0
    if textureIndex < 0 or textureIndex >= meta.texCount then
        return false, 'invalid_texture'
    end

    local inv = getInventory()(source)
    if not inv then return false, 'no_inventory' end

    local Items   = getItems()
    local itemDef = Items(itemName)
    if not itemDef then return false, 'item_not_defined' end

    local metadata = {
        texture  = textureIndex,
        drawable = meta.drawable,
        [meta.type == 'prop' and 'prop' or 'component'] = meta.slot,
    }

    return Inventory.AddItem(inv, itemDef, 1, metadata)
end

---Donne toutes les textures d'un vêtement
---@param source number
---@param itemName string
---@return boolean, string?
local function GiveClothingAllTextures(source, itemName)
    local meta = ClothingMetadata[itemName]
    if not meta then return false, 'item_not_found' end
    for i = 0, meta.texCount - 1 do
        local ok, err = GiveClothing(source, itemName, i)
        if not ok then return false, err end
    end
    return true
end

exports('GiveClothing', GiveClothing)
exports('GiveClothingAllTextures', GiveClothingAllTextures)
return { GiveClothing = GiveClothing, GiveClothingAllTextures = GiveClothingAllTextures }