return {

    -- ─────────────────────────────────────────────────────────────
--  kt_illegal — Items ox_inventory
-- ─────────────────────────────────────────────────────────────

-- ── Cannabis ─────────────────────────────────────────────────
['weed_seed'] = {
    label       = 'Graine de cannabis',
    weight      = 10,
    stack       = true,
    close       = true,
    description = 'Une graine à planter.',
},

['weed_raw'] = {
    label       = 'Cannabis brut',
    weight      = 50,
    stack       = true,
    close       = true,
    description = 'Récolte brute non traitée.',
},

['weed_packaged'] = {
    label       = 'Cannabis emballé',
    weight      = 30,
    stack       = true,
    close       = true,
    description = 'Prêt à la vente.',
},

-- ── Consommables culture ──────────────────────────────────────
['fertilizer'] = {
    label       = 'Engrais',
    weight      = 200,
    stack       = true,
    close       = true,
    description = 'Accélère la croissance des plantes.',
},

['water_bottle'] = {
    label       = "Bouteille d'eau",
    weight      = 100,
    stack       = true,
    close       = true,
    description = 'Pour arroser les plantes.',
},

-- ── Équipement ────────────────────────────────────────────────
['uv_lamp'] = {
    label       = 'Lampe UV',
    weight      = 500,
    stack       = false,
    close       = true,
    description = 'Accélère la croissance en intérieur.',
},

['bank_card'] = {
    label = 'Carte Bancaire Basique',
    weight = 10,
    stack = false,
    close = true,
    description = 'Carte bancaire standard. Dépôt max: $5 000 | Retrait max: $20 000',
    client = {
        image = 'bank_card.png'
    }
},

['bank_gold_card'] = {
    label = 'Carte Bancaire Or',
    weight = 10,
    stack = false,
    close = true,
    description = 'Carte bancaire Or. Dépôt max: $10 000 | Retrait max: $10 000',
    client = {
        image = 'bank_gold_card.png'
    }
},

['bank_diamond_card'] = {
    label = 'Carte Bancaire Diamant',
    weight = 10,
    stack = false,
    close = true,
    description = 'Carte bancaire Diamant. Dépôt max: $50 000 | Retrait max: $25 000',
    client = {
        image = 'bank_diamond_card.png'
    }
},

['bank_receipt'] = {
    label = 'Reçu bancaire',
    weight = 1,
    stack = false,
    close = true,
},

-- ── Cartes d'identité & documents ────────────────────────────

["identity_card"] = {
    label = "Carte d'identité",
    weight = 0,
    stack = false,
    close = true,
    description = "Carte nationale d'identité officielle.",
    server = {
        export = "kt_idcard_ui.UseIdentityCard"
    }
},

-- [FIX] identity_card2 supprimé : doublon de identity_card avec apostrophe
-- typographique (') dans le label qui causait une erreur de syntaxe Lua potentielle.
-- Utiliser uniquement ['identity_card'].

["license_card"] = {
    label = "Permis de conduire",
    weight = 0,
    stack = false,
    close = true,
    description = "Permis de conduire",
    server = {
        export = "kt_idcard_ui.UseLicenseCard"
    }
},

["weapon_permit"] = {
    label = "Permis de port d'arme",
    weight = 0,
    stack = false,
    close = true,
    description = "Autorisation de port d'arme",
    server = {
        export = "kt_idcard_ui.UseWeaponCard"
    }
},

["police_badge"] = {
    label = "Badge de police",
    weight = 0,
    stack = false,
    close = true,
    description = "Badge officiel de police",
    server = {
        export = "kt_idcard_ui.UsePoliceCard"
    }
},

["mairie_card"] = {
    label = "Carte mairie",
    weight = 0,
    stack = false,
    close = true,
    description = "Carte de mairie"
},

["gov_card"] = {
    label = "Carte gouvernement",
    weight = 0,
    stack = false,
    close = true,
    description = "Carte gouvernementale"
},

["ems_card"] = {
    label = "Carte EMS",
    weight = 0,
    stack = false,
    close = true,
    description = "Carte des services médicaux",
    server = {
        export = "kt_idcard_ui.UseEMSCard"
    }
},

["company_badge"] = {
    label = "Badge entreprise",
    weight = 0,
    stack = false,
    close = true,
    description = "Badge professionnel"
},

["passport"] = {
    label = "Passeport",
    weight = 0,
    stack = false,
    close = true,
    description = "Passeport officiel",
    server = {
        export = "kt_idcard_ui.UsePassport"
    }
},

-- ── Divers ────────────────────────────────────────────────────

    ['bandage'] = {
        label = 'Bandage',
        weight = 115,
        client = {
            anim = { dict = 'missheistdockssetup1clipboard@idle_a', clip = 'idle_a', flag = 49 },
            prop = { model = `prop_rolled_sock_02`, pos = vec3(-0.14, -0.14, -0.08), rot = vec3(-50.0, -50.0, 0.0) },
            disable = { move = true, car = true, combat = true },
            usetime = 2500,
        }
    },

    ['black_money'] = {
        label = 'Dirty Money',
    },

    ['parachute'] = {
        label = 'Parachute',
        weight = 800,
        stack = false,
        client = {
            anim = { dict = 'clothingshirt', clip = 'try_shirt_positive_d' },
            usetime = 1500
        }
    },

    ['garbage'] = {
        label = 'Garbage',
    },

    ['paperbag'] = {
        label = 'Paper Bag',
        weight = 1,
        stack = false,
        close = false,
        consume = 0
    },

    ['identification'] = {
        label = 'Identification',
        client = {
            image = 'card_id.png'
        }
    },

    ['panties'] = {
        label = 'Knickers',
        weight = 10,
        consume = 0,
        client = {
            status = { thirst = -10, stress = -25 },
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            prop = { model = `prop_cs_panties_02`, pos = vec3(0.03, 0.0, 0.02), rot = vec3(0.0, -13.5, -1.5) },
            usetime = 2500,
        }
    },

    ['lockpick'] = {
        label = 'Lockpick',
        weight = 16,
        stack = true,
        close = true,
        description = 'Un outil pour crocheter les serrures de véhicule.',
    },

    ['vehicle_key'] = {
        label = 'Clé de véhicule',
        weight = 50,
        stack = false,
        close = false,
        description = "Clé associée à une plaque d'immatriculation.",
    },

    ['phone'] = {
        label = 'Phone',
        weight = 190,
        stack = false,
        consume = 0,
        client = {
            add = function(total)
                if total > 0 then
                    pcall(function() return exports.npwd:setPhoneDisabled(false) end)
                end
            end,
            remove = function(total)
                if total < 1 then
                    pcall(function() return exports.npwd:setPhoneDisabled(true) end)
                end
            end
        }
    },

    ['money'] = {
        label = 'Money',
        client = {
            image = 'money.png',
        }
    },

    ['mustard'] = {
        label = 'Mustard',
        weight = 50,
        client = {
            status = { hunger = 10, thirst = 10 },
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            prop = { model = `prop_food_mustard`, pos = vec3(0.01, 0.0, -0.07), rot = vec3(1.0, 1.0, -1.5) },
            usetime = 2500,
            notification = 'You.. drank mustard'
        }
    },

    ['radio'] = {
        label = 'Radio',
        weight = 10,
        stack = false,
        allowArmed = true
    },

    ['armour'] = {
        label = 'Bulletproof Vest',
        weight = 1500,
        stack = false,
        client = {
            anim = { dict = 'clothingshirt', clip = 'try_shirt_positive_d' },
            usetime = 2500
        }
    },

    ['scrapmetal'] = {
        label = 'Scrap Metal',
        weight = 80,
    },

    -- ─────────────────────────────────────────────
    -- 🍔 FAST FOOD
    -- ─────────────────────────────────────────────

    ['burger'] = {
        label = 'Burger',
        weight = 20,
        client = {
            image = 'burger.png',
            status = { hunger = 30, stress = -5 },
            anim = 'eating',
            prop = 'burger',
            usetime = 2500,
            notification = 'Tu manges un burger'
        }
    },

    ['cheeseburger'] = {
        label = 'Cheeseburger',
        weight = 22,
        client = {
            image = 'cheeseburger.png',
            status = { hunger = 35, stress = -8 },
            anim = 'eating',
            prop = 'burger',
            usetime = 2500,
            notification = 'Tu manges un cheeseburger'
        }
    },

    ['Frites'] = {
        label = 'Frites',
        weight = 8,
        client = {
            image = 'Frites.png',
            status = { hunger = 20, stress = -3 },
            anim = 'eating',
            prop = 'burger',
            usetime = 2000,
            notification = 'Tu manges des frites'
        }
    },

    ['pizza'] = {
        label = 'Pizza',
        weight = 30,
        client = {
            image = 'pizza.png',
            status = { hunger = 40, stress = -10 },
            anim = 'eating',
            prop = { model = `prop_cs_burger_01`, pos = vec3(0.02, 0.02, -0.02), rot = vec3(0.0, 0.0, 0.0) },
            usetime = 3000,
            notification = 'Tu manges une pizza'
        }
    },

    ['donut'] = {
        label = 'Donut',
        weight = 8,
        client = {
            image = 'donut.png',
            status = { hunger = 15, stress = -5 },
            anim = 'eating',
            prop = 'burger',
            usetime = 1500,
            notification = 'Tu manges un donut'
        }
    },

    -- ─────────────────────────────────────────────
    -- 🥤 BOISSONS
    -- ─────────────────────────────────────────────

    ['water'] = {
        label = 'Water',
        weight = 5,
        client = {
            image = 'water.png',
            status = { thirst = 30 },
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            prop = { model = `prop_ld_flow_bottle`, pos = vec3(0.03, 0.03, 0.02), rot = vec3(0, 0, 0) },
            usetime = 2500,
            notification = "Tu bois de l'eau"
        }
    },

    ['cola'] = {
        label = 'Cola',
        weight = 3,
        client = {
            image = 'cola.png',
            status = { thirst = 25, stress = -3 },
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            prop = { model = `prop_ecola_can`, pos = vec3(0.01, 0.01, 0.06), rot = vec3(5, 5, -180) },
            usetime = 2500,
            notification = 'Tu bois un cola'
        }
    },

    ['energy_drink'] = {
        label = 'Energy Drink',
        weight = 3,
        client = {
            image = 'energy.png',
            status = { thirst = 20, stress = -5 },
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            prop = { model = `prop_energy_drink`, pos = vec3(0.01, 0.01, 0.06), rot = vec3(0, 0, 0) },
            usetime = 2000,
            notification = 'Tu bois une energy drink'
        }
    },

    -- ─────────────────────────────────────────────
    -- 🍫 SNACKS
    -- ─────────────────────────────────────────────

    ['chocolate'] = {
        label = 'Chocolate',
        weight = 10,
        client = {
            image = 'chocolate.png',
            status = { hunger = 12, stress = -8 },
            anim = 'eating',
            prop = 'burger',
            usetime = 1500,
            notification = 'Tu manges du chocolat'
        }
    },

    ['chips'] = {
        label = 'Chips',
        weight = 12,
        client = {
            image = 'chips.png',
            status = { hunger = 18, stress = -3 },
            anim = 'eating',
            prop = 'burger',
            usetime = 2000,
            notification = 'Tu manges des chips'
        }
    },

    -- ─────────────────────────────────────────────
    -- 🍱 CUISINE RP
    -- ─────────────────────────────────────────────

    ['sandwich'] = {
        label = 'Sandwich',
        weight = 18,
        client = {
            image = 'sandwich.png',
            status = { hunger = 25, stress = -5 },
            anim = 'eating',
            prop = 'burger',
            usetime = 2500,
            notification = 'Tu manges un sandwich'
        }
    },

    ['taco'] = {
        label = 'Taco',
        weight = 12,
        client = {
            image = 'taco.png',
            status = { hunger = 28, stress = -6 },
            anim = 'eating',
            prop = 'burger',
            usetime = 2500,
            notification = 'Tu manges un taco'
        }
    },

    ['hotdog'] = {
        label = 'Hotdog',
        weight = 15,
        client = {
            image = 'hotdog.png',
            status = { hunger = 26, stress = -5 },
            anim = 'eating',
            prop = 'burger',
            usetime = 2500,
            notification = 'Tu manges un hotdog'
        }
    },

    -- ─────────────────────────────────────────────
    -- 🍺 BOISSONS ALCOOLISEES
    -- ─────────────────────────────────────────────

    ['beer'] = {
        label = 'Beer',
        weight = 50,
        client = {
            image = 'beer.png',
            status = { stress = -15 },
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            prop = { model = `prop_beer_bottle`, pos = vec3(0.01, 0.01, 0.06), rot = vec3(0, 0, 0) },
            usetime = 2500,
            notification = 'Tu bois une biere'
        }
    },

    ['fd'] = {
        label = 'fd',
        weight = 0,
        client = {
            image = 'beer.png',
            status = { hunger = 250, stress = -50, thirst = 150 },
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            prop = { model = `prop_beer_bottle`, pos = vec3(0.01, 0.01, 0.06), rot = vec3(0, 0, 0) },
            usetime = 2500,
            notification = 'Tu bois une biere'
        }
    },

    -- ─────────────────────────────────────────────
    -- 👕 VÊTEMENTS INDIVIDUELS
    -- [FIX] Déplacés depuis items_clothing.lua (fichier orphelin non chargé)
    -- et corrigés : clothing_shoes_001 était dupliqué sans category/clothingSlot
    -- ─────────────────────────────────────────────

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

    -- [FIX] clothing_shoes_001 : une seule définition avec category + clothingSlot
    -- L'ancienne entrée dans items.lua n'avait ni category ni clothingSlot → équipement impossible
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

    -- ─────────────────────────────────────────────
    -- 👔 TENUES COMPLÈTES
    -- category = 'clothing_tenu' → s'applique à tous les slots via metadata.outfit
    -- ─────────────────────────────────────────────

    ['clothing_tenu_police'] = {
        label       = 'Tenue Police',
        weight      = 500,
        stack       = false,
        close       = false,
        description = 'Tenue complète de la police de Los Santos.',
        category    = 'clothing_tenu',
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
        stack        = false,
        close        = false,
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