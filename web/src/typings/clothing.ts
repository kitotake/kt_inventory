// typings/clothing.ts
export type ClothingCategory =
  | 'hat'
  | 'mask'
  | 'glasses'
  | 'chain'
  | 'gloves'
  | 'top'
  | 'watch'
  | 'pants'
  | 'cap'
  | 'hair'
  | 'ears'
  | 'bag'
  | 'undershirt'
  | 'armor'
  | 'bracelet'
  | 'shoes';

export type ClothingItemType = 'clothing' | 'clothing_tenu';

export interface EquippedClothingItem {
  name: string;
  label: string;
  itemType?: ClothingItemType;
  outfitData?: Partial<Record<ClothingCategory,
      {
        drawable: number;
        texture: number;
        palette?: number;
      }
    >
  >;
}

export interface ClothingSlotData {
  category: ClothingCategory;
  label: string;
  icon: string;
  side: 'left' | 'right';
  accepts: ClothingCategory[];
}

export interface EquippedClothing {
  [category: string]: EquippedClothingItem | null;
}

// ── Définitions des slots ─────────────────────────────────────

export const LEFT_CLOTHING_SLOTS: ClothingSlotData[] = [
  { category: 'hat', label: 'Chapeau', icon: 'ti-hat', side: 'left', accepts: ['hat'] },
  { category: 'mask', label: 'Masque', icon: 'ti-mask', side: 'left', accepts: ['mask'] },
  { category: 'glasses', label: 'Lunettes', icon: 'ti-eyeglass', side: 'left', accepts: ['glasses'] },
  { category: 'chain', label: 'Écharpe', icon: 'ti-scarf', side: 'left', accepts: ['chain'] },
  { category: 'gloves', label: 'Gants', icon: 'ti-glove', side: 'left', accepts: ['gloves'] },
  { category: 'top', label: 'Veste', icon: 'ti-shirt', side: 'left', accepts: ['top'] },
  { category: 'watch', label: 'Montre', icon: 'ti-watch', side: 'left', accepts: ['watch'] },
  { category: 'pants', label: 'Pantalon', icon: 'ti-git-branch', side: 'left', accepts: ['pants'] },
];

export const RIGHT_CLOTHING_SLOTS: ClothingSlotData[] = [
  { category: 'cap', label: 'Casquette', icon: 'ti-cap', side: 'right', accepts: ['cap'] },
  { category: 'hair', label: 'Coiffure', icon: 'ti-scissors', side: 'right', accepts: ['hair'] },
  { category: 'bracelet', label: 'Bracelet', icon: 'ti-diamond', side: 'right', accepts: ['bracelet'] },
  { category: 'bag', label: 'Sac', icon: 'ti-backpack', side: 'right', accepts: ['bag'] },
  { category: 'shoes', label: 'Chaussures', icon: 'ti-shoe', side: 'right', accepts: ['shoes'] },
  { category: 'armor', label: 'Gilet', icon: 'ti-shield', side: 'right', accepts: ['armor'] },
  { category: 'undershirt', label: 'Sous-vêt.', icon: 'ti-shirt', side: 'right', accepts: ['undershirt'] },
  { category: 'ears', label: 'Boucles', icon: 'ti-ear', side: 'right', accepts: ['ears'] },
];

// ──────────────────────────────────────────────
// HELPERS
// ──────────────────────────────────────────────

export const isOutfitItem = (itemName: string): boolean =>
  Boolean(itemName?.startsWith('clothing_tenu') || itemName?.includes('_tenu'));

export const getClothingItemType = (itemName: string): ClothingItemType =>
  isOutfitItem(itemName) ? 'clothing_tenu' : 'clothing';

/**
 * Retourne true si l'item peut être déposé dans le slot donné.
 * Règles :
 *  1. L'item doit venir de l'inventaire joueur.
 *  2. category doit être 'clothing' ou 'clothing_tenu'.
 *  3. Pour 'clothing'      : Items[name].clothingSlot doit matcher slot.accepts.
 *  4. Pour 'clothing_tenu' : accepté dans tous les slots (ou refusé selon config).
 */
export const canDropInSlot = (
  _itemName: string,
  itemCategory: string | undefined,
  slotAccepts: ClothingCategory[],
  itemClothingSlot: ClothingCategory | undefined
): boolean => {
  if (!itemCategory) return false;
  if (itemCategory !== 'clothing' && itemCategory !== 'clothing_tenu') return false;
  // Tenue complète : acceptée partout (le Lua distribue sur tous les slots)

  if (itemCategory === 'clothing_tenu') return true;
  // Pièce individuelle : le clothingSlot de l'item doit correspondre
  if (!itemClothingSlot) return false;
  return slotAccepts.includes(itemClothingSlot);
};
