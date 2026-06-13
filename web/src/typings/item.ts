// typings/item.ts
import { ClothingCategory } from './clothing';

export type ItemData = {
  name:          string;
  label:         string;
  stack:         boolean;
  usable:        boolean;
  close:         boolean;
  count:         number;
  description?:  string;
  buttons?:      string[];
  ammoName?:     string;
  image?:        string;
  category?:     'clothing' | 'clothing_tenu' | string;
  clothingSlot?: ClothingCategory;
  maxAmmo?:      number;
};