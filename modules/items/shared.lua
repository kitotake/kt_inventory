-- modules/items/shared.lua
-- Corrections :
--   [FIX-1] category et clothingSlot préservés dans ItemList (items_clothing fusionné)
--   [FIX-2] items_clothing.lua supprimé comme fichier séparé
--   [FIX-IMAGE] LAZY RESOLUTION - les chemins d'images sont résolus au moment du besoin
--               (quand clent.imagepath est garanti d'être défini), pas au chargement.
--               Cela évite les problèmes de timing où resolveImagePath était appelée
--               avant que client.imagepath soit initialisé.

local function useExport(resource, export)
    return function(...)
        return exports[resource][export](nil, ...)
    end
end

local ItemList = {}
local isServer = IsDuplicityVersion()

-- [FIX-IMAGE] Lazy resolution : retourne le chemin OR une fonction qui le résout plus tard
local function resolveImagePath(path)
    if not path or path == '' then return nil end
    
    -- Chemin déjà absolu (nui://, https://, http://, fivem://) → retourner tel quel
    if path:match('^[%w][%w%+%-%.]*://') then return path end
    
    -- Côté CLIENT : si client.imagepath n'existe pas encore, retourner la fonction lazy
    if not isServer and (not client or not client.imagepath) then
        return function()
            local base = client and client.imagepath or ''
            if base == '' then return path end
            return (base:sub(-1) == '/' and base or base .. '/') .. path
        end
    end
    
    -- Chemin relatif → préfixer avec imagepath
    local base = (isServer and '' or (client and client.imagepath or ''))
    if base == '' then return path end
    return (base:sub(-1) == '/' and base or base .. '/') .. path
end

-- Wrapper pour résoudre les chemins lazily au moment du besoin
local function ensureImagePath(imagePath)
    if type(imagePath) == 'function' then
        return imagePath()
    end
    return imagePath
end

---@param data KtItem
local function newItem(data)
    data.weight = data.weight or 0

    if data.close == nil then
        data.close = true
    end

    if data.stack == nil then
        data.stack = true
    end

    local clientData, serverData = data.client, data.server
    ---@cast clientData -nil
    ---@cast serverData -nil

    if not data.consume and (clientData and (clientData.status or clientData.usetime or clientData.export) or serverData?.export) then
        data.consume = 1
    end

    if isServer then
        ---@cast data ktServerItem
        serverData = data.server
        data.client = nil

        if not data.durability then
            if data.degrade or (data.consume and data.consume ~= 0 and data.consume < 1) then
                data.durability = true
            end
        end

        if not serverData then goto continue end

        if serverData.export then
            data.cb = useExport(string.strsplit('.', serverData.export))
        end
    else
        ---@cast data KtClientItem

        -- [FIX-IMAGE] Shallow copy de clientData AVANT toute modification.
        if clientData then
            local copy = {}
            for k, v in pairs(clientData) do copy[k] = v end
            clientData  = copy
            data.client = copy
        end

        data.server = nil
        data.count  = 0

        if not clientData then goto continue end

        if clientData.export then
            data.export = useExport(string.strsplit('.', clientData.export))
        end

        -- [FIX-IMAGE] Lazy resolution du chemin image
        if clientData.image then
            clientData.image = resolveImagePath(clientData.image)
        end

        if clientData.propTwo then
            clientData.prop = clientData.prop and { clientData.prop, clientData.propTwo } or clientData.propTwo
            clientData.propTwo = nil
        end
    end

    ::continue::

    ItemList[data.name] = data
end

for type, data in pairs(lib.load('data.weapons') or {}) do
    for k, v in pairs(data) do
        v.name   = k
        v.close  = type == 'Ammo' and true or false
        v.weight = v.weight or 0

        if type == 'Weapons' then
            ---@cast v KtWeapon
            v.model    = v.model or k
            v.hash     = joaat(v.model)
            v.stack    = v.throwable and true or false
            v.durability = v.durability or 0.05
            v.weapon   = true
        else
            v.stack = true
        end

        v[type == 'Ammo' and 'ammo'
            or type == 'Components' and 'component'
            or type == 'Tints' and 'tint'
            or 'weapon'] = true

        if isServer then
            v.client = nil
        else
            v.count  = 0
            v.server = nil

            -- [FIX-IMAGE] Lazy resolution pour les armes aussi
            local clientData = v.client
            if clientData then
                local copy = {}
                for ck, cv in pairs(clientData) do copy[ck] = cv end
                v.client = copy
                if copy.image then
                    copy.image = resolveImagePath(copy.image)
                end
            end
        end

        ItemList[k] = v
    end
end

for k, v in pairs(lib.load('data.items') or {}) do
    v.name = k
    local success, response = pcall(newItem, v)

    if not success then
        warn(('An error occurred while creating item "%s" callback!\n^1SCRIPT ERROR: %s^0'):format(k, response))
    end
end

ItemList.cash = ItemList.money

-- [FIX-IMAGE] Wrapper pour auto-résoudre les images lazily quand elles sont accédées
local originalItemList = ItemList
ItemList = setmetatable({}, {
    __index = function(self, key)
        local item = originalItemList[key]
        if item and item.client and item.client.image then
            item.client.image = ensureImagePath(item.client.image)
        end
        return item
    end,
    __pairs = function()
        return pairs(originalItemList)
    end,
    __call = function(self, key)
        return self[key]
    end
})

lib.print.info('^2[kt_inventory] modules/items/shared module loaded')

return ItemList

