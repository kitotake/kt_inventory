import { ClothingCategory } from './clothing';

export type ItemData = {
  name: string;
  label: string;
  stack: boolean;
  usable: boolean;
  close: boolean;
  count: number;
  description?: string;
  buttons?: string[];
  ammoName?: string;
  image?: string;
  /** 'clothing' = pièce individuelle, 'clothing_tenu' = tenue complète */
  category?: 'clothing' | 'clothing_tenu' | string;
  /** Slot cible pour le drag & drop vers les emplacements vêtements */
  clothingSlot?: ClothingCategory;
};