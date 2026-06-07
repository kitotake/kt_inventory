// reducers/refreshSlots.ts
// CORRECTIONS :
//   1. Suppression de filter(Boolean) inutile — boucle for...of directe
//   2. Items[name]!.count += count → mutation hors Redux corrigée en assignation propre
//   3. slotsData : resize par push/splice au lieu d'appel récursif au reducer setupInventory

import { CaseReducer, PayloadAction } from '@reduxjs/toolkit';
import { itemDurability } from '../helpers';
import { Items }          from '../store/items';
import { InventoryType, Slot, State } from '../typings';

export type ItemsPayload = { item: Slot; inventory?: InventoryType };

interface Payload {
  items?:      ItemsPayload | ItemsPayload[];
  itemCount?:  Record<string, number>;
  weightData?: { inventoryId: string; maxWeight: number };
  slotsData?:  { inventoryId: string; slots: number };
}

type InvKey = 'leftInventory' | 'rightInventory';

const resolveByType = (state: State, t?: InventoryType): InvKey =>
  !t || t === InventoryType.PLAYER ? 'leftInventory' : 'rightInventory';

const resolveById = (state: State, id: string): InvKey | null => {
  if (id === state.leftInventory.id)  return 'leftInventory';
  if (id === state.rightInventory.id) return 'rightInventory';
  return null;
};

export const refreshSlotsReducer: CaseReducer<State, PayloadAction<Payload>> = (
  state, action
) => {
  const { items, itemCount, weightData, slotsData } = action.payload;
  const curTime = Math.floor(Date.now() / 1000);

  // 1. Mise à jour de slots individuels
  if (items !== undefined) {
    const list: ItemsPayload[] = Array.isArray(items) ? items : [items];
    for (const data of list) {
      if (!data) continue;
      const key = resolveByType(state, data.inventory);
      const idx = data.item.slot - 1;
      const inv = state[key];
      if (idx < 0 || idx >= inv.items.length) continue;
      inv.items[idx] = {
        ...data.item,
        durability: itemDurability(data.item.metadata, curTime),
      };
    }
    if (state.rightInventory.type === InventoryType.CRAFTING) {
      state.rightInventory = { ...state.rightInventory };
    }
  }

  // 2. Mise à jour des compteurs globaux d'items (sans mutation directe)
  if (itemCount !== undefined) {
    for (const [name, delta] of Object.entries(itemCount)) {
      const existing = Items[name];
      if (existing !== undefined) {
        Items[name] = { ...existing, count: existing.count + delta };
      }
    }
  }

  // 3. Mise à jour du poids max
  if (weightData !== undefined) {
    const key = resolveById(state, weightData.inventoryId);
    if (key !== null) state[key].maxWeight = weightData.maxWeight;
  }

  // 4. Redimensionnement des slots (sans appel récursif)
  if (slotsData !== undefined) {
    const key = resolveById(state, slotsData.inventoryId);
    if (key === null) return;
    const inv = state[key];
    inv.slots = slotsData.slots;
    if (slotsData.slots > inv.items.length) {
      for (let i = inv.items.length; i < slotsData.slots; i++) {
        inv.items.push({ slot: i + 1 });
      }
    } else if (slotsData.slots < inv.items.length) {
      inv.items.splice(slotsData.slots);
    }
  }
};