print("^2[ITEMS] Fichier chargé !^0")

-- ─────────────────────────────────────────────────────────────
--  kt_illegal — Items ox_inventory
-- ─────────────────────────────────────────────────────────────
local items = {
-- ── Cannabis ─────────────────────────────────────────────────
['weed_seed'] = {
    label       = 'Graine de cannabis',
    weight      = 10,
    stack       = true,
    close       = true,
    description = 'Une graine à planter.',
   client = {
        image = 'drugs/weed_seed.png'
    }
},

['weed_raw'] = {
    label       = 'Cannabis brut',
    weight      = 50,
    stack       = true,
    close       = true,
    description = 'Récolte brute non traitée.',
   client = {
        image = 'drugs/weed_raw.png'
    }
},

['weed_packaged'] = {
    label       = 'Cannabis emballé',
    weight      = 30,
    stack       = true,
    close       = true,
    description = 'Prêt à la vente.',
   client = {
        image = 'drugs/weed_packaged.png'
    }
},

-- ── Consommables culture ──────────────────────────────────────
['fertilizer'] = {
    label       = 'Engrais',
    weight      = 200,
    stack       = true,
    close       = true,
    description = 'Accélère la croissance des plantes.',
   client = {
        image = 'drugs/fertilizer.png'
    },
},

['water_bottle'] = {
    label       = "Bouteille d'eau",
    weight      = 100,
    stack       = true,
    close       = true,
    description = 'Pour arroser les plantes.',
   client = {
        image = 'drugs/water_bottle.png'
    },
},

-- ── Équipement ────────────────────────────────────────────────
['uv_lamp'] = {
    label       = 'Lampe UV',
    weight      = 500,
    stack       = false,
    close       = true,
    description = 'Accélère la croissance en intérieur.',
   client = {
        image = 'drugs/uv_lamp.png'
    }
},

['bank_card'] = {
    label = 'Carte Bancaire Basique',
    weight = 10,
    stack = false,
    close = true,
    description = 'Carte bancaire standard. Dépôt max: $5 000 | Retrait max: $20 000',
    client = {
        image = 'documents/bank_card.png'
    }
},

['bank_gold_card'] = {
    label = 'Carte Bancaire Or',
    weight = 10,
    stack = false,
    close = true,
    description = 'Carte bancaire Or. Dépôt max: $10 000 | Retrait max: $10 000',
    client = {
        image = 'documents/bank_gold_card.png'
    }
},

['bank_diamond_card'] = {
    label = 'Carte Bancaire Diamant',
    weight = 10,
    stack = false,
    close = true,
    description = 'Carte bancaire Diamant. Dépôt max: $50 000 | Retrait max: $25 000',
    client = {
        image = 'documents/bank_diamond_card.png'
    }
},

['bank_receipt'] = {
    label = 'Reçu bancaire',
    weight = 1,
    stack = false,
    close = true,
    description = 'Reçu de transaction bancaire.',
    client = {
        image = 'documents/bank_receipt.png'
    }
},

-- ── Cartes d'identité & documents ────────────────────────────

["identity_card"] = {
    label = "Carte d'identité",
    weight = 0,
    stack = false,
    close = true,
   
    client = {
        image = 'documents/identity_card.png',
        description = "Carte nationale d'identité officielle."
    },
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
  
    client = {
        image = 'documents/license_card.png',
        description = "Permis de conduire"
    },
    server = {
        export = "kt_idcard_ui.UseLicenseCard"
    }
},

["weapon_permit"] = {
    label = "Permis de port d'arme",
    weight = 0,
    stack = false,
    close = true,
   
    client = {
        image = 'documents/weapon_permit.png',
        description = "Autorisation de port d'arme"
    },
    server = {
        export = "kt_idcard_ui.UseWeaponCard"
    }
},

["police_badge"] = {
    label = "Badge de police",
    weight = 0,
    stack = false,
    close = true,
    client = {
        description = "Badge officiel de la police",
        image = 'documents/polic_badge.png'
    },
    
    server = {
        export = "kt_idcard_ui.UsePoliceCard"
    }
},

["mairie_card"] = {
    label = "Carte mairie",
    weight = 0,
    stack = false,
    close = true,
    client = {
         description = "Carte de mairie",
        image = 'documents/mairie_card.png'
    },
   
},

["gov_card"] = {
    label = "Carte gouvernement",
    weight = 0,
    stack = false,
    close = true,
    client = {
        description = "Carte gouvernementale",
        image = 'documents/gov_card.png'
    },
     server = {
        export = "kt_idcard_ui.UseGovCard"
    }
},

["ems_card"] = {
    label = "Carte EMS",
    weight = 0,
    stack = false,
    close = true,
    client = {
        description = "Carte des services médicaux",
        image = 'documents/ems_card.png'
    },
    server = {
        export = "kt_idcard_ui.UseEMSCard"
    }
},

["company_badge"] = {
    label = "Badge entreprise",
    weight = 0,
    stack = false,
    close = true,
 
    client = {
           description = "Badge d'entreprise",
        image = 'documents/company_badge.png'
    }
},

["passport"] = {
    label = "Passeport",
    weight = 0,
    stack = false,
    close = true,
    client = {
          image = 'documents/passport.png',
    description = "Passeport officiel",
     },
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
            notification = 'You apply a bandage to yourself.',
            image = 'medical/bandage.png',
        }
    },

    

    ['parachute'] = {
        label = 'Parachute',
        weight = 800,
        stack = false,
        client = {
            anim = { dict = 'clothingshirt', clip = 'try_shirt_positive_d' },
            usetime = 1500,
              image = 'misc/parachute.png',
        
        }
    },

    ['garbage'] = {
        label = 'Garbage',
        client = {
            image = 'garbage.png'
        }
    },

    ['paperbag'] = {
        label = 'Paper Bag',
        weight = 1,
        stack = false,
        close = false,
        consume = 0,
        client = {
          image = 'consumables/paperbag.png',
          description = 'A simple paper bag, can be used to carry small items.',
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
            image = 'clothing/panties.png',
        }
    },

    ['lockpick'] = {
        label = 'Lockpick',
        weight = 16,
        stack = true,
        close = true,
        description = 'Un outil pour crocheter les serrures de véhicule.',
        client = {
            image = 'tools/lockpick.png'
        }
    },

    ['carkey'] = {
        label = 'Clé de véhicule',
        weight = 50,
        stack = false,
        close = false,
        description = "Clé associée à une plaque d'immatriculation.",
        client = {
            image = 'keys/vehicle_key.png'
        }
    },

     ['key'] = {
        label = 'Clé de véhicule',
        weight = 50,
        stack = false,
        close = false,
        description = "Clé associée à une plaque d'immatriculation.",
        client = {
            image = 'keys/key.png'
        }
    },

     ['oldkey'] = {
        label = 'Clé de véhicule',
        weight = 50,
        stack = false,
        close = false,
        description = "Clé associée à une plaque d'immatriculation.",
        client = {
            image = 'keys/oldkey.png'
        }
    },

    ['phone'] = {
        label = 'Phone',
        weight = 190,
        stack = false,
        consume = 0,
        client = {
            image = 'electronics/phone.png'
        }
    },

['black_money'] = {
        label = 'Dirty Money',
        weight = 0,
    stack = true,
    close = false,
    consume = 0,
    client = {
        image = 'valuables/black_money.png',
    }
    },

    ['money'] = {
    label = 'Money',
    weight = 0,
    stack = true,
    close = false,
    consume = 0,
    client = {
        image = 'valuables/money.png',
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
            notification = 'You.. drank mustard',
            image = 'food/mustard.png',
        }
    },

    ['radio'] = {
        label = 'Radio',
        weight = 10,
        stack = false,
        allowArmed = true,
        client = {
            image = 'electronics/radio.png',
        description = 'A portable radio, can be used to listen to music or communicate.'
        }
    },

    ['armour'] = {
        label = 'Bulletproof Vest',
        weight = 1500,
        stack = false,
        client = {
            anim = { dict = 'clothingshirt', clip = 'try_shirt_positive_d' },
            usetime = 2500,
            notification = 'You put on a bulletproof vest',
            image = 'misc/armour.png',
        }
    },

    ['scrapmetal'] = {
        label = 'Scrap Metal',
        weight = 80,
        stack = true,
        close = true,
        description = 'Pieces of scrap metal, can be sold to a scrap dealer.',
        client = {
            image = 'tools/scrapmetal.png'
        }
    },

    -- ─────────────────────────────────────────────
    -- 🍔 FAST FOOD
    -- ─────────────────────────────────────────────

    ['burger'] = {
        label = 'Burger',
        weight = 20,
        client = {
            image = 'food/burger.png',
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
            image = 'food/cheeseburger.png',
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
            image = 'food/Frites.png',
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
            image = 'food/pizza.png',
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
            image = 'food/donut.png',
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
            image = 'drinks/water.png',
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
            image = 'drinks/cola.png',
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
            image = 'drinks/energy_drink.png',
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
            image = 'food/chocolate.png',
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
            image = 'food/chips.png',
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
            image = 'food/sandwich.png',
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
            image = 'food/taco.png',
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
            image = 'food/hotdog.png',
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
            image = 'drinks/beer.png',
            status = { stress = -15 },
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            prop = { model = `prop_beer_bottle`, pos = vec3(0.01, 0.01, 0.06), rot = vec3(0, 0, 0) },
            usetime = 2500,
            notification = 'Tu bois une biere'
        }
    },

    ['dusse'] = {
        label = 'Dusse ITEM CHEAT',
        weight = 0,
        client = {
            image = 'drinks/Dusse.png',
            status = { hunger = 250, stress = -50, thirst = 150 },
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            prop = { model = `prop_beer_bottle`, pos = vec3(0.01, 0.01, 0.06), rot = vec3(0, 0, 0) },
            usetime = 2500,
            notification = 'Tu bois une Dusse'
        }
    },

    -- ─────────────────────────────────────────────
  
}

local modules = {
    require 'data.clothing_items',
    require 'data.crafting',
    require 'data.licenses',
    require 'data.weapons',
    require 'data.vehicles',
    require 'data.shops',
    require 'data.stashes',
    require 'data.evidence',
}

for _, module in pairs(modules) do
    for name, data in pairs(module) do
        items[name] = data
    end
end

return items