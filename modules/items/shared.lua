-- modules/items/shared.lua
-- Corrections :
--   [FIX-1] category et clothingSlot préservés dans ItemList (items_clothing fusionné)
--   [FIX-2] items_clothing.lua supprimé comme fichier séparé
--   [FIX-IMAGE] setImagePath ne mutait jamais la table source (lib.load cache).
--               Remplacé par resolveImagePath + shallow copy de clientData.
--               Bug : 1ère ouverture image OK, 2ème ouverture image par défaut.
--               Cause : lib.load() retourne la même table en cache Lua → clientData.image
--               était écrasé avec le chemin complet → à la réouverture, si client.imagepath
--               avait changé ou si le chemin était re-préfixé, le résultat était corrompu.
--               Fix : copie superficielle de clientData avant toute modification.

local function useExport(resource, export)
    return function(...)
        return exports[resource][export](nil, ...)
    end
end

local ItemList = {}
local isServer = IsDuplicityVersion()

-- [FIX-IMAGE] resolveImagePath ne mutate JAMAIS la table passée en paramètre.
-- Retourne le chemin résolu sans modifier la source.
local function resolveImagePath(path)
    if not path or path == '' then return nil end
    -- Chemin déjà absolu (nui://, https://, http://, fivem://) → retourner tel quel
    -- Pattern étendu : lettres, chiffres, +, -, . dans le scheme (RFC 3986)
    if path:match('^[%w][%w%+%-%.]*://') then return path end
    -- Chemin relatif → préfixer avec imagepath défini dans config client
    local base = client and client.imagepath or ''
    if base == '' then return path end
    -- Éviter le double slash
    return (base:sub(-1) == '/' and base or base .. '/') .. path
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
        -- lib.load() retourne la même table en cache à chaque appel de la ressource.
        -- Sans cette copie, clientData.image est écrit en place sur la table originale :
        --   - 1ère ouverture  : image = "water.png"   → résolu → "nui://.../water.png" ✓
        --   - table source MUTÉE : image vaut maintenant "nui://.../water.png"
        --   - 2ème ouverture : image = "nui://.../water.png" → resolveImagePath ne préfixe pas
        --     (déjà absolu) → retourne intact → devrait marcher...
        --     MAIS si entre-temps le NUI a été rechargé et que client.imagepath a changé
        --     ou si la ressource a été ensure'd → lib.load() retourne l'item ORIGINAL
        --     (pas le muté) → image = "water.png" à nouveau → chemin invalide sans imagepath
        -- La copie isole nos modifications de la table source → toujours cohérent.
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

        -- [FIX-IMAGE] Écriture sur la COPIE — la table originale de data/items.lua
        -- reste intacte pour les prochaines ouvertures.
        if clientData.image then
            clientData.image = resolveImagePath(clientData.image)
        end

        if clientData.propTwo then
            clientData.prop = clientData.prop and { clientData.prop, clientData.propTwo } or clientData.propTwo
            clientData.propTwo = nil
        end
    end

    ::continue::

    -- [FIX-1] category et clothingSlot : champs de premier niveau, jamais touchés
    -- par le bloc client/serveur → survivent correctement dans ItemList.

    ItemList[data.name] = data
end

-- [FIX-2] items_clothing.lua fusionné dans data/items.lua — ne pas le recharger ici.

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

            -- [FIX-IMAGE] Même traitement pour les armes : shallow copy avant modification
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

return ItemList