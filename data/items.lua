return {

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
        description = 'Clé associée à une plaque d\'immatriculation.',
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

    ['clothing'] = {
        label = 'Clothing',
        consume = 0,
    },

    ['mastercard'] = {
        label = 'Fleeca Card',
        stack = false,
        weight = 10,
        client = {
            image = 'card_bank.png'
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

    ['fries'] = {
        label = 'Frites',
        weight = 8,
        client = {
            image = 'fries.png',
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
}