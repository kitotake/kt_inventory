// typings/state.ts
import { Inventory } from './inventory';

export type LayoutMode = 'default' | 'weapon' | 'shop' | 'crafting' | 'exchange';

export type State = {
  leftInventory:      Inventory;
  rightInventory:     Inventory;
  itemAmount:         number;
  shiftPressed:       boolean;
  isBusy:             boolean;
  layoutMode:         LayoutMode;
  additionalMetadata: Array<{ metadata: string; value: string }>;
  history?: {
    leftInventory:  Inventory;
    rightInventory: Inventory;
  };
};