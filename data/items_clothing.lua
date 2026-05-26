-- data/items_clothing.lua
-- Items clothing (pièces individuelles) et clothing_tenu (tenues complètes)
-- À fusionner avec data/items.lua ou à require séparément

return {

    -- ─────────────────────────────────────────────────────────────────────
    -- PIÈCES INDIVIDUELLES : type 'clothing'
    -- metadata obligatoires : category, drawable, texture
    -- metadata optionnels   : palette, label
    -- ─────────────────────────────────────────────────────────────────────

    ['clothing_hat_001'] = {
        label       = 'Bonnet noir',
        weight      = 50,
        stack       = false,
        close       = false,
        description = 'Un bonnet en laine noire.',
        client = {
            image = 'clothing_hat.png',
        },
        -- metadata à fournir lors de la création de l'item :
        -- metadata = { category='hat', drawable=14, texture=0, label='Bonnet noir' }
    },

    ['clothing_mask_001'] = {
        label       = 'Cagoule',
        weight      = 30,
        stack       = false,
        close       = false,
        description = 'Une cagoule pour ne pas être reconnu.',
        client = {
            image = 'clothing_mask.png',
        },
    },

    ['clothing_top_001'] = {
        label       = 'Veste en cuir',
        weight      = 300,
        stack       = false,
        close       = false,
        description = 'Une veste en cuir noir.',
        client = {
            image = 'clothing_top.png',
        },
    },

    ['clothing_pants_001'] = {
        label       = 'Jean noir',
        weight      = 200,
        stack       = false,
        close       = false,
        description = 'Jean noir slim.',
        client = {
            image = 'clothing_pants.png',
        },
    },

    ['clothing_shoes_001'] = {
        label       = 'Baskets blanches',
        weight      = 150,
        stack       = false,
        close       = false,
        description = 'Baskets blanches classiques.',
        client = {
            image = 'clothing_shoes.png',
        },
    },

    ['clothing_glasses_001'] = {
        label       = 'Lunettes de soleil',
        weight      = 20,
        stack       = false,
        close       = false,
        description = 'Lunettes de soleil style aviateur.',
        client = {
            image = 'clothing_glasses.png',
        },
    },

    -- ─────────────────────────────────────────────────────────────────────
    -- TENUES COMPLÈTES : type 'clothing_tenu'
    -- metadata obligatoires : outfit (table catégorie → {drawable, texture})
    -- ─────────────────────────────────────────────────────────────────────

    ['clothing_tenu_policier'] = {
        label       = 'Tenue de policier',
        weight      = 500,
        stack       = false,
        close       = false,
        description = 'Tenue complète de la police de Los Santos.',
        client = {
            image = 'clothing_tenu_policier.png',
        },
        -- Exemple de metadata à fournir :
        -- metadata = {
        --     label    = 'Tenue Policier',
        --     category = 'tenu',  -- catégorie spéciale pour les tenues
        --     outfit   = {
        --         hat        = { drawable = 25, texture = 0 },
        --         top        = { drawable = 55, texture = 0 },
        --         pants      = { drawable = 24, texture = 0 },
        --         shoes      = { drawable = 25, texture = 0 },
        --         undershirt = { drawable = 58, texture = 0 },
        --     }
        -- }
    },

    ['clothing_tenu_civil'] = {
        label       = 'Tenue civile',
        weight      = 400,
        stack       = false,
        close       = false,
        description = 'Tenue civile décontractée.',
        client = {
            image = 'clothing_tenu_civil.png',
        },
    },

    ['clothing_tenu_mechanic'] = {
        label       = 'Tenue de mécanicien',
        weight      = 450,
        stack       = false,
        close       = false,
        description = 'Combinaison de mécanicien.',
        client = {
            image = 'clothing_tenu_mechanic.png',
        },
    },

    -- Remplace les deux lignes existantes :
['clothing'] = {
    label = 'Clothing',
    consume = 0,
},
['clothing_tenue'] = {
    label = 'clothing tenue',
    consume = 0,
},

-- Par :
['clothing_hat_001'] = {
    label       = 'Bonnet noir',
    weight      = 50,
    stack       = false,
    close       = false,
    category    = 'clothing',      -- ← lu par le NUI via Items[name].category
    clothingSlot = 'hat',          -- ← lu par le NUI via Items[name].clothingSlot
},

['clothing_pants_001'] = {
    label       = 'Jean noir',
    weight      = 200,
    stack       = false,
    close       = false,
    category    = 'clothing',
    clothingSlot = 'pants',
},

['clothing_shoes_001'] = {
    label       = 'Baskets blanches',
    weight      = 150,
    stack       = false,
    close       = false,
    category    = 'clothing',
    clothingSlot = 'shoes',
},

['clothing_top_001'] = {
    label       = 'Hoodie',
    weight      = 200,
    stack       = false,
    close       = false,
    category    = 'clothing',
    clothingSlot = 'top',
},

['clothing_tenu_police'] = {
    label       = 'Tenue Police',
    weight      = 500,
    stack       = false,
    close       = false,
    category    = 'clothing_tenu',  -- ← accepté dans tous les slots clothing
    -- pas de clothingSlot : la tenue est distribuée sur tous les slots par le Lua
},
}
