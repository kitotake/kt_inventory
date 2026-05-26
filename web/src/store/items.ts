import { ItemData } from '../typings/item';

export const Items: { [key: string]: ItemData | undefined } = {
  // Items non-clothing (refusés dans tous les slots clothing)
  water: {
    name: 'water', close: false, label: 'Eau',
    stack: true, usable: true, count: 0,
    // Pas de category 'clothing' → refusé partout
  },

  // Pièce individuelle — doit avoir category + clothingSlot
  clothing_hat_snapback: {
    name: 'clothing_hat_snapback', close: false,
    label: 'Snapback',
    stack: false, usable: false, count: 0,
    category: 'clothing',
    clothingSlot: 'hat',          // ← accepté UNIQUEMENT dans le slot hat
  },

  clothing_pants_jeans: {
    name: 'clothing_pants_jeans', close: false,
    label: 'Jean classique',
    stack: false, usable: false, count: 0,
    category: 'clothing',
    clothingSlot: 'pants',        // ← accepté UNIQUEMENT dans le slot pants
  },

  clothing_shoes_sneakers: {
    name: 'clothing_shoes_sneakers', close: false,
    label: 'Sneakers',
    stack: false, usable: false, count: 0,
    category: 'clothing',
    clothingSlot: 'shoes',
  },

  clothing_top_hoodie: {
    name: 'clothing_top_hoodie', close: false,
    label: 'Hoodie',
    stack: false, usable: false, count: 0,
    category: 'clothing',
    clothingSlot: 'top',
  },

  // Tenue complète — category: 'clothing_tenu', pas de clothingSlot requis
  // Acceptée dans tous les slots clothing (le Lua distribue)
  clothing_tenu_police: {
    name: 'clothing_tenu_police', close: false,
    label: 'Tenue Police',
    stack: false, usable: false, count: 0,
    category: 'clothing_tenu',
    // clothingSlot omis → sera équipée via equipOutfit sur tous les slots
  },
};