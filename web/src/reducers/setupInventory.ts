// reducers/setupInventory.ts
import { CaseReducer, PayloadAction } from '@reduxjs/toolkit';
import { getItemData, itemDurability } from '../helpers';
import { Items } from '../store/items';
import { Inventory, InventoryType, Slot, State } from '../typings';
import { LayoutMode } from '../typings/state';

const buildSlotMap = (items: Slot[]): Map<number, Slot> => {
  const map = new Map<number, Slot>();
  for (let i = 0; i < items.length; i++) {
    const item = items[i];
    if (item?.slot !== undefined) map.set(item.slot, item);
  }
  return map;
};

const normalizeInventory = (inventory: Inventory, curTime: number): Inventory => {
  const slotMap    = buildSlotMap(Object.values(inventory.items));
  const normalized = new Array<Slot>(inventory.slots);

  for (let i = 0; i < inventory.slots; i++) {
    const slotNumber = i + 1;
    const existing   = slotMap.get(slotNumber);

    if (!existing || !existing.name) {
      normalized[i] = { slot: slotNumber };
      continue;
    }

    if (Items[existing.name] === undefined) {
      void getItemData(existing.name);
    }

    normalized[i] = {
      ...existing,
      durability: itemDurability(existing.metadata, curTime),
    };
  }

  return { ...inventory, items: normalized };
};

const detectLayoutMode = (rightType?: string): LayoutMode => {
  switch (rightType) {
    case 'weapon_attachment': return 'weapon';
    case InventoryType.SHOP:      return 'shop';
    case InventoryType.CRAFTING:  return 'crafting';
    case InventoryType.PLAYER:    return 'exchange';
    default:                      return 'default';
  }
};

export const setupInventoryReducer: CaseReducer<
  State,
  PayloadAction<{ leftInventory?: Inventory; rightInventory?: Inventory }>
> = (state, action) => {
  const { leftInventory, rightInventory } = action.payload;
  const curTime = Math.floor(Date.now() / 1000);

  if (leftInventory)  state.leftInventory  = normalizeInventory(leftInventory,  curTime);
  if (rightInventory) state.rightInventory = normalizeInventory(rightInventory, curTime);

  // Détecte automatiquement le layout selon le type de l'inventaire droit
  if (rightInventory) {
    state.layoutMode = detectLayoutMode(rightInventory.type);
  }

  state.shiftPressed = false;
  state.isBusy       = false;
};