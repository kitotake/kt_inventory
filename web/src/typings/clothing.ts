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

// Type d'item clothing : pièce individuelle ou tenue complète
export type ClothingItemType = 'clothing' | 'clothing_tenu';

export interface EquippedClothingItem {
  name: string;
  label: string;
  /** Type de l'item : pièce ou tenue complète */
  itemType?: ClothingItemType;
  /** Pour clothing_tenu : dictionnaire catégorie → drawable/texture */
  outfitData?: Partial<Record<ClothingCategory, { drawable: number; texture: number; palette?: number }>>;
}

export interface ClothingSlotData {
  category: ClothingCategory;
  label: string;
  icon: string;
  side: 'left' | 'right';
}

export interface EquippedClothing {
  [category: string]: EquippedClothingItem | null;
}

// ======================================================
// SLOT DEFINITIONS
// ======================================================

export const LEFT_CLOTHING_SLOTS: ClothingSlotData[] = [
  { category: 'hat',     label: 'Chapeau',   icon: 'ti-hat',        side: 'left' },
  { category: 'mask',    label: 'Masque',    icon: 'ti-mask',       side: 'left' },
  { category: 'glasses', label: 'Lunettes',  icon: 'ti-eyeglass',   side: 'left' },
  { category: 'chain',   label: 'Écharpe',   icon: 'ti-scarf',      side: 'left' },
  { category: 'gloves',  label: 'Gants',     icon: 'ti-glove',      side: 'left' },
  { category: 'top',     label: 'Veste',     icon: 'ti-shirt',      side: 'left' },
  { category: 'watch',   label: 'Montre',    icon: 'ti-watch',      side: 'left' },
  { category: 'pants',   label: 'Pantalon',  icon: 'ti-git-branch', side: 'left' },
];

export const RIGHT_CLOTHING_SLOTS: ClothingSlotData[] = [
  { category: 'cap',        label: 'Casquette',  icon: 'ti-cap',      side: 'right' },
  { category: 'hair',       label: 'Coiffure',   icon: 'ti-scissors', side: 'right' },
  { category: 'bracelet',   label: 'Bracelet',   icon: 'ti-diamond',  side: 'right' },
  { category: 'bag',        label: 'Sac',        icon: 'ti-backpack', side: 'right' },
  { category: 'shoes',      label: 'Chaussures', icon: 'ti-shoe',     side: 'right' },
  { category: 'armor',      label: 'Gilet',      icon: 'ti-shield',   side: 'right' },
  { category: 'undershirt', label: 'Sous-vêt.',  icon: 'ti-shirt',    side: 'right' },
  { category: 'ears',       label: 'Boucles',    icon: 'ti-ear',      side: 'right' },
];

// ======================================================
// HELPERS
// ======================================================

/**
 * Retourne true si le nom d'item correspond à une tenue complète (clothing_tenu)
 */
export const isOutfitItem = (itemName: string): boolean =>
  itemName?.startsWith('clothing_tenu') || itemName?.includes('_tenu') || false;

/**
 * Retourne le type d'item clothing
 */
export const getClothingItemType = (itemName: string): ClothingItemType =>
  isOutfitItem(itemName) ? 'clothing_tenu' : 'clothing';
