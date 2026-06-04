// reducers/setupInventory.ts
// CORRECTION : O(n²) → O(n) via Map
// AVANT : Array.from(Array(slots), (_, i) => Object.values(items).find(i => i.slot === i+1))
//         = 80 slots × 80 items = 6400 itérations sur un inventaire plein
// APRÈS : Map<slot, item> construite en O(n), accès en O(1)

import { CaseReducer, PayloadAction } from '@reduxjs/toolkit';
import { getItemData, itemDurability } from '../helpers';
import { Items } from '../store/items';
import { Inventory, Slot, State } from '../typings';

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

export const setupInventoryReducer: CaseReducer<
  State,
  PayloadAction<{ leftInventory?: Inventory; rightInventory?: Inventory }>
> = (state, action) => {
  const { leftInventory, rightInventory } = action.payload;
  const curTime = Math.floor(Date.now() / 1000);

  if (leftInventory)  state.leftInventory  = normalizeInventory(leftInventory,  curTime);
  if (rightInventory) state.rightInventory = normalizeInventory(rightInventory, curTime);

  state.shiftPressed = false;
  state.isBusy       = false;
};
