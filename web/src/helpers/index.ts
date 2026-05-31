// helpers/index.ts
import { Inventory, InventoryType, ItemData, Slot, SlotWithItem, State } from '../typings';
import { isEqual } from 'lodash';
import { store } from '../store';
import { Items } from '../store/items';
import { imagepath } from '../store/imagepath';
import { fetchNui } from '../utils/fetchNui';

export const canPurchaseItem = (
  item: Slot,
  inventory: { type: Inventory['type']; groups: Inventory['groups'] }
) => {
  if (inventory.type !== 'shop' || !isSlotWithItem(item)) return true;
  if (item.count !== undefined && item.count === 0) return false;
  if (item.grade === undefined || !inventory.groups) return true;

  const leftInventory = store.getState().inventory.leftInventory;
  if (!leftInventory.groups) return false;

  const reqGroups = Object.keys(inventory.groups);

  if (Array.isArray(item.grade)) {
    for (let i = 0; i < reqGroups.length; i++) {
      const reqGroup = reqGroups[i];
      if (leftInventory.groups[reqGroup] !== undefined) {
        const playerGrade = leftInventory.groups[reqGroup];
        for (let j = 0; j < item.grade.length; j++) {
          if (playerGrade === item.grade[j]) return true;
        }
      }
    }
    return false;
  } else {
    for (let i = 0; i < reqGroups.length; i++) {
      const reqGroup = reqGroups[i];
      if (leftInventory.groups[reqGroup] !== undefined) {
        if (leftInventory.groups[reqGroup] >= item.grade) return true;
      }
    }
    return false;
  }
};

export const canCraftItem = (item: Slot, inventoryType: string) => {
  if (!isSlotWithItem(item) || inventoryType !== 'crafting') return true;
  if (!item.ingredients) return true;
  const leftInventory = store.getState().inventory.leftInventory;
  const ingredientItems = Object.entries(item.ingredients);

  const remainingItems = ingredientItems.filter((ingredient) => {
    const [itemName, count] = [ingredient[0], ingredient[1]];
    const globalItem = Items[itemName];
    if (count >= 1) {
      if (globalItem && globalItem.count >= count) return false;
    }
    const hasItem = leftInventory.items.find((playerItem) => {
      if (isSlotWithItem(playerItem) && playerItem.name === itemName) {
        if (count < 1) return playerItem.metadata?.durability >= count * 100;
      }
    });
    return !hasItem;
  });

  return remainingItems.length === 0;
};

export const isSlotWithItem = (slot: Slot, strict: boolean = false): slot is SlotWithItem =>
  (slot.name !== undefined && slot.weight !== undefined) ||
  (strict && slot.name !== undefined && slot.count !== undefined && slot.weight !== undefined);

export const canStack = (sourceSlot: Slot, targetSlot: Slot) =>
  sourceSlot.name === targetSlot.name && isEqual(sourceSlot.metadata, targetSlot.metadata);

export const findAvailableSlot = (item: Slot, data: ItemData, items: Slot[]) => {
  if (!data.stack) return items.find((target) => target.name === undefined);
  const stackableSlot = items.find(
    (target) => target.name === item.name && isEqual(target.metadata, item.metadata)
  );
  return stackableSlot || items.find((target) => target.name === undefined);
};

export const getTargetInventory = (
  state: State,
  sourceType: Inventory['type'],
  targetType?: Inventory['type']
): { sourceInventory: Inventory; targetInventory: Inventory } => ({
  sourceInventory: sourceType === InventoryType.PLAYER ? state.leftInventory : state.rightInventory,
  targetInventory: targetType
    ? targetType === InventoryType.PLAYER ? state.leftInventory : state.rightInventory
    : sourceType === InventoryType.PLAYER ? state.rightInventory : state.leftInventory,
});

export const itemDurability = (metadata: any, curTime: number) => {
  if (metadata?.durability === undefined) return;
  let durability = metadata.durability;
  if (durability > 100 && metadata.degrade)
    durability = ((metadata.durability - curTime) / (60 * metadata.degrade)) * 100;
  if (durability < 0) durability = 0;
  return durability;
};

export const getTotalWeight = (items: Inventory['items']) =>
  items.reduce((total, slot) => (isSlotWithItem(slot) ? total + slot.weight : total), 0);

export const isContainer = (inventory: Inventory) => inventory.type === InventoryType.CONTAINER;

export const getItemData = async (itemName: string) => {
  const resp: ItemData | null = await fetchNui('getItemData', itemName);
  if (resp?.name) {
    Items[itemName] = resp;
    return resp;
  }
};

export const getItemUrl = (item: string | SlotWithItem) => {
  const isObj = typeof item === 'object';

  if (isObj) {
    if (!item.name) return;

    const metadata = item.metadata;

    if (metadata?.imageurl) return metadata.imageurl;

    // images/food/burger.png
    if (metadata?.folder && metadata?.image) {
      return `${imagepath}/${metadata.folder}/${metadata.image}.png`;
    }

    if (metadata?.image) {
      return `${imagepath}/${metadata.image}.png`;
    }
  }

  const itemName = isObj ? item.name : item;
  const itemData = Items[itemName];

  if (!itemData) {
    return `${imagepath}/${itemName}.png`;
  }

  if (itemData.image) {
    return itemData.image;
  }

  return `${imagepath}/${itemName}.png`;
};