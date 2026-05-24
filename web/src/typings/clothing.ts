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

export interface ClothingSlotDef {
  category: ClothingCategory;
  label: string;
  icon: string; // nom icône Tabler
  side: 'left' | 'right';
}

export interface EquippedClothing {
  [category: string]: {
    name: string;
    label: string;
    drawable: number;
    texture: number;
  } | null;
}

// Définition des slots gauche (côté LeftInventory)
export const LEFT_CLOTHING_SLOTS: ClothingSlotDef[] = [
  { category: 'hat',    label: 'Chapeau',  icon: 'ti-hat',      side: 'left' },
  { category: 'mask',   label: 'Masque',   icon: 'ti-mask',     side: 'left' },
  { category: 'glasses',label: 'Lunettes', icon: 'ti-eyeglass', side: 'left' },
  { category: 'chain',  label: 'Écharpe',  icon: 'ti-scarf',    side: 'left' },
  { category: 'gloves', label: 'Gants',    icon: 'ti-glove',    side: 'left' },
  { category: 'top',    label: 'Veste',    icon: 'ti-shirt',    side: 'left' },
  { category: 'watch',  label: 'Montre',   icon: 'ti-watch',    side: 'left' },
  { category: 'pants',  label: 'Pantalon', icon: 'ti-git-branch', side: 'left' },
];

// Définition des slots droite (côté RightInventory)
export const RIGHT_CLOTHING_SLOTS: ClothingSlotDef[] = [
  { category: 'cap',       label: 'Casquette',  icon: 'ti-cap',      side: 'right' },
  { category: 'hair',      label: 'Coiffure',   icon: 'ti-scissors', side: 'right' },
  { category: 'bracelet',  label: 'Bracelet',   icon: 'ti-diamond',  side: 'right' },
  { category: 'bag',       label: 'Sac',        icon: 'ti-backpack', side: 'right' },
  { category: 'shoes',     label: 'Chaussures', icon: 'ti-shoe',     side: 'right' },
  { category: 'armor',     label: 'Gilet',      icon: 'ti-shield',   side: 'right' },
  { category: 'undershirt',label: 'Sous-vêt.',  icon: 'ti-shirt',    side: 'right' },
  { category: 'ears',      label: 'Boucles',    icon: 'ti-ear',      side: 'right' },
];
