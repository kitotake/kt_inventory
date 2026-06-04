// helpers/index.ts
// CORRECTIONS :
//   1. probeImage : flag settled + img.src='' pour libérer la ressource → pas de fuite mémoire
//   2. resolveItemUrl : Promise.any() teste les candidats EN PARALLÈLE (plus rapide)
//   3. getItemUrl : sentinelle null avant résolution → évite les doubles appels async
//   4. useItemUrl : cleanup correct si itemName change pendant la résolution

import { useEffect, useState }  from 'react';
import { isEqual }              from 'lodash';
import { store }                from '../store';
import { Items }                from '../store/items';
import { imagepath }            from '../store/imagepath';
import { fetchNui }             from '../utils/fetchNui';
import {
  Inventory, InventoryType, ItemData,
  Slot, SlotWithItem, State,
} from '../typings';

// ── Inventory helpers ─────────────────────────────────────────────────────────

export const canPurchaseItem = (
  item: Slot,
  inventory: { type: Inventory['type']; groups: Inventory['groups'] }
): boolean => {
  if (inventory.type !== 'shop' || !isSlotWithItem(item)) return true;
  if (item.count !== undefined && item.count === 0) return false;
  if (item.grade === undefined || !inventory.groups) return true;
  const leftInventory = store.getState().inventory.leftInventory;
  if (!leftInventory.groups) return false;
  const reqGroups = Object.keys(inventory.groups);
  if (Array.isArray(item.grade)) {
    for (const g of reqGroups) {
      if (leftInventory.groups[g] !== undefined && item.grade.includes(leftInventory.groups[g])) return true;
    }
    return false;
  }
  for (const g of reqGroups) {
    if (leftInventory.groups[g] !== undefined && leftInventory.groups[g] >= (item.grade as number)) return true;
  }
  return false;
};

export const canCraftItem = (item: Slot, inventoryType: string): boolean => {
  if (!isSlotWithItem(item) || inventoryType !== 'crafting') return true;
  if (!item.ingredients) return true;
  const leftInventory = store.getState().inventory.leftInventory;
  for (const [itemName, count] of Object.entries(item.ingredients)) {
    const globalItem = Items[itemName];
    if (count >= 1 && globalItem && globalItem.count >= count) continue;
    const hasItem = leftInventory.items.some((p) => {
      if (isSlotWithItem(p) && p.name === itemName) {
        if (count < 1) return (p.metadata?.durability ?? 0) >= count * 100;
        return true;
      }
      return false;
    });
    if (!hasItem) return false;
  }
  return true;
};

export const isSlotWithItem = (slot: Slot, strict = false): slot is SlotWithItem =>
  (slot.name !== undefined && slot.weight !== undefined) ||
  (strict && slot.name !== undefined && slot.count !== undefined && slot.weight !== undefined);

export const canStack = (a: Slot, b: Slot): boolean =>
  a.name === b.name && isEqual(a.metadata, b.metadata);

export const findAvailableSlot = (item: Slot, data: ItemData, items: Slot[]): Slot | undefined => {
  if (!data.stack) return items.find((t) => t.name === undefined);
  return items.find((t) => t.name === item.name && isEqual(t.metadata, item.metadata))
    ?? items.find((t) => t.name === undefined);
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

export const itemDurability = (
  metadata: Record<string, unknown> | undefined,
  curTime: number
): number | undefined => {
  if (metadata?.durability === undefined) return undefined;
  let d = metadata.durability as number;
  if (d > 100 && metadata.degrade) d = ((d - curTime) / (60 * (metadata.degrade as number))) * 100;
  return Math.max(0, d);
};

export const getTotalWeight = (items: Inventory['items']): number =>
  items.reduce((t, s) => (isSlotWithItem(s) ? t + s.weight : t), 0);

export const isContainer = (inventory: Inventory): boolean =>
  inventory.type === InventoryType.CONTAINER;

export const getItemData = async (itemName: string): Promise<ItemData | undefined> => {
  const resp = await fetchNui<ItemData | null>('getItemData', itemName);
  if (resp?.name) { Items[itemName] = resp; return resp; }
  return undefined;
};

// ── Image URL ─────────────────────────────────────────────────────────────────

const resolvedUrlCache = new Map<string, string | null>();

// Teste une URL d'image. Flag settled évite les effets de bord après démontage.
const probeImage = (url: string): Promise<string | null> =>
  new Promise((resolve) => {
    const img = new Image();
    let settled = false;
    const done = (result: string | null) => {
      if (settled) return;
      settled     = true;
      img.onload  = null;
      img.onerror = null;
      img.src     = '';   // libère la ressource navigateur
      resolve(result);
    };
    img.onload  = () => done(url);
    img.onerror = () => done(null);
    img.src     = url;
  });

// Teste les deux candidats EN PARALLÈLE via Promise.any → plus rapide que séquentiel
export const resolveItemUrl = async (itemName: string): Promise<string> => {
  if (resolvedUrlCache.has(itemName)) {
    return resolvedUrlCache.get(itemName) ?? `${imagepath}/default.png`;
  }
  try {
    const winner = await Promise.any([
      `${imagepath}/${itemName}.png`,
      `${imagepath}/${itemName}/${itemName}.png`,
    ].map((url) =>
      probeImage(url).then((r) => { if (!r) throw new Error('miss'); return r; })
    ));
    resolvedUrlCache.set(itemName, winner);
    return winner;
  } catch {
    resolvedUrlCache.set(itemName, null);
    return `${imagepath}/default.png`;
  }
};

export const getItemUrl = (item: string | SlotWithItem): string | undefined => {
  const isObj    = typeof item === 'object';
  const itemName = isObj ? (item as SlotWithItem).name : (item as string);
  if (!itemName) return undefined;

  if (isObj) {
    const m = (item as SlotWithItem).metadata;
    if (m?.imageurl)                  return m.imageurl as string;
    if (m?.folder && m?.image)        return `${imagepath}/${m.folder}/${m.image}.png`;
    if (m?.image)                     return `${imagepath}/${m.image}.png`;
  }

  const itemData = Items[itemName];
  if (itemData?.image) return itemData.image;

  // Déjà en cache
  if (resolvedUrlCache.has(itemName)) {
    return resolvedUrlCache.get(itemName) ?? `${imagepath}/default.png`;
  }

  // Sentinelle null → évite les doubles appels async
  resolvedUrlCache.set(itemName, null);
  void resolveItemUrl(itemName).then((url) => {
    resolvedUrlCache.set(itemName, url);
    if (itemData) itemData.image = url;
  });

  return `${imagepath}/${itemName}.png`;
};

export const useItemUrl = (itemName: string | undefined): string => {
  const getInitial = (): string => {
    if (!itemName) return '';
    const cached = resolvedUrlCache.get(itemName);
    if (cached) return cached;
    return Items[itemName]?.image ?? `${imagepath}/${itemName}.png`;
  };

  const [url, setUrl] = useState<string>(getInitial);

  useEffect(() => {
    if (!itemName) return;
    let cancelled = false;
    if (resolvedUrlCache.has(itemName)) {
      const c = resolvedUrlCache.get(itemName);
      if (c && c !== url) setUrl(c);
      return;
    }
    void resolveItemUrl(itemName).then((r) => { if (!cancelled) setUrl(r); });
    return () => { cancelled = true; };
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [itemName]);

  return url;
};

export const createImageFallback = (itemName: string) => {
  const candidates = [
    `${imagepath}/${itemName}/${itemName}.png`,
    `${imagepath}/default.png`,
  ];
  let attempt = 0;
  return (e: React.SyntheticEvent<HTMLImageElement>) => {
    if (attempt < candidates.length) { e.currentTarget.src = candidates[attempt++]; }
    else { e.currentTarget.style.display = 'none'; }
  };
};

export const clearImageCache = (): void => {
  resolvedUrlCache.clear();
  for (const key of Object.keys(Items)) {
    const item = Items[key];
    if (item) item.image = undefined;
  }
};
