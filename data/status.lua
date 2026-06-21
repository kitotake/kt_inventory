-- data/status.lua
-- Config du système de statuts (faim / soif / stress).
-- Remplace l'ancien shared/config/status_config.lua du framework union.

return {
    min = 0,
    max = 100,

    defaults = {
        hunger = 100,
        thirst = 100,
        stress = 0,
    },

    tickInterval = 10000, -- ms entre chaque décroissance
    saveInterval = 30000, -- ms entre chaque sauvegarde batch

    decay = {
        hunger = 0.15,
        thirst = 0.25,
        stress = 0.5,
    },

    -- Réutilisable par d'autres modules (ex: tir → +stressGain.shooting)
    stressGain = {
        shooting  = 3,
        sprinting = 0.3,
        fistFight = 5,
        explosion = 12,
        nearDeath = 20,
        meleeHit  = 2,
    },

    effects = {
        damageOnEmpty = true,
        damageAmount  = 4,
        stressVisual  = true,
    },

    -- Tolérance anti-cheat pour kt_inventory:playerStatus:sync (latence réseau)
    syncTolerance = 5,
}