-- data/items_clothing.lua
-- Items clothing compatibles avec clothing_client.lua
-- category = 'clothing'      → pièce individuelle (nécessite clothingSlot)
-- category = 'clothing_tenu' → tenue complète (s'applique à tous les slots)

return {

    -- ─────────────────────────────────────────────────────────────────────
    -- PIÈCES INDIVIDUELLES
    -- metadata requises : { drawable, texture, palette? }
    -- ─────────────────────────────────────────────────────────────────────

    ['clothing_hat_001'] = {
        label        = 'Bonnet noir',
        weight       = 50,
        stack        = false,
        close        = false,
        description  = 'Un bonnet en laine noire.',
        category     = 'clothing',
        clothingSlot = 'hat',
    },

    ['clothing_mask_001'] = {
        label        = 'Cagoule',
        weight       = 30,
        stack        = false,
        close        = false,
        description  = 'Une cagoule pour ne pas être reconnu.',
        category     = 'clothing',
        clothingSlot = 'mask',
    },

    ['clothing_glasses_001'] = {
        label        = 'Lunettes de soleil',
        weight       = 20,
        stack        = false,
        close        = false,
        description  = 'Lunettes de soleil style aviateur.',
        category     = 'clothing',
        clothingSlot = 'glasses',
    },

    ['clothing_top_001'] = {
        label        = 'Veste en cuir',
        weight       = 300,
        stack        = false,
        close        = false,
        description  = 'Une veste en cuir noir.',
        category     = 'clothing',
        clothingSlot = 'top',
    },

    ['clothing_undershirt_001'] = {
        label        = 'T-shirt blanc',
        weight       = 100,
        stack        = false,
        close        = false,
        description  = 'T-shirt blanc basique.',
        category     = 'clothing',
        clothingSlot = 'undershirt',
    },

    ['clothing_pants_001'] = {
        label        = 'Jean noir',
        weight       = 200,
        stack        = false,
        close        = false,
        description  = 'Jean noir slim.',
        category     = 'clothing',
        clothingSlot = 'pants',
    },

    ['clothing_shoes_001'] = {
        label        = 'Baskets blanches',
        weight       = 150,
        stack        = false,
        close        = false,
        description  = 'Baskets blanches classiques.',
        category     = 'clothing',
        clothingSlot = 'shoes',
    },

    ['clothing_bag_001'] = {
        label        = 'Sac à dos',
        weight       = 200,
        stack        = false,
        close        = false,
        description  = 'Sac à dos discret.',
        category     = 'clothing',
        clothingSlot = 'bag',
    },

    ['clothing_armor_001'] = {
        label        = 'Gilet pare-balles',
        weight       = 800,
        stack        = false,
        close        = false,
        description  = 'Gilet pare-balles léger.',
        category     = 'clothing',
        clothingSlot = 'armor',
    },

    ['clothing_watch_001'] = {
        label        = 'Montre classique',
        weight       = 30,
        stack        = false,
        close        = false,
        description  = 'Montre analogique.',
        category     = 'clothing',
        clothingSlot = 'watch',
    },

    ['clothing_bracelet_001'] = {
        label        = 'Bracelet',
        weight       = 10,
        stack        = false,
        close        = false,
        description  = 'Bracelet en métal.',
        category     = 'clothing',
        clothingSlot = 'bracelet',
    },

    ['clothing_chain_001'] = {
        label        = 'Collier',
        weight       = 15,
        stack        = false,
        close        = false,
        description  = 'Collier en or.',
        category     = 'clothing',
        clothingSlot = 'chain',
    },

    ['clothing_gloves_001'] = {
        label        = 'Gants noirs',
        weight       = 50,
        stack        = false,
        close        = false,
        description  = 'Gants en cuir noir.',
        category     = 'clothing',
        clothingSlot = 'gloves',
    },

    -- ─────────────────────────────────────────────────────────────────────
    -- TENUES COMPLÈTES
    -- metadata requises : { outfit = { hat={drawable,texture}, ... } }
    -- ─────────────────────────────────────────────────────────────────────

    ['clothing_tenu_police'] = {
        label       = 'Tenue Police',
        weight      = 500,
        stack       = false,
        close       = false,
        description = 'Tenue complète de la police de Los Santos.',
        category    = 'clothing_tenu',
        -- clothingSlot omis intentionnellement : tenue multi-slots
    },

    ['clothing_tenu_civil'] = {
        label       = 'Tenue Civile',
        weight      = 400,
        stack       = false,
        close       = false,
        description = 'Tenue civile décontractée.',
        category    = 'clothing_tenu',
    },

    ['clothing_tenu_mechanic'] = {
        label       = 'Tenue Mécanicien',
        weight      = 450,
        stack       = false,
        close       = false,
        description = 'Combinaison de mécanicien.',
        category    = 'clothing_tenu',
    },

    ['clothing_tenu_ems'] = {
        label       = 'Tenue EMS',
        weight      = 450,
        stack       = false,
        close       = false,
        description = 'Tenue des services médicaux.',
        category    = 'clothing_tenu',
    },
}