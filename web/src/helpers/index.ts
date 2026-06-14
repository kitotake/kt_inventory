// helpers/index.ts
// CORRECTIONS :
//   1. probeImage : flag settled + img.src='' pour libérer la ressource → pas de fuite mémoire
//   2. resolveItemUrl : Promise.any() teste les candidats EN PARALLÈLE (plus rapide)
//   3. getItemUrl : sentinelle null avant résolution → évite les doubles appels async
//   4. useItemUrl : cleanup correct si itemName change pendant la résolution
// NOUVEAU :
//   5. canCraftItem → retourne le détail des ingrédients manquants (CraftCheckResult)
//   6. canPurchaseItem → vérifie aussi le solde du joueur selon la devise de l'item
//   7. getPlayerBalance → lit le solde (money / black_money / devise custom) depuis leftInventory.groups ou metadata

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

/**
 * Résultat détaillé d'une vérification de craft.
 * - ok      : true si tous les ingrédients sont disponibles en quantité suffisante
 * - missing : liste des ingrédients manquants avec quantité possédée / requise
 */
export interface CraftCheckResult {
  ok: boolean;
  missing: { name: string; label: string; have: number; need: number }[];
}

/**
 * Résultat détaillé d'une vérification d'achat.
 * - ok      : true si l'item est achetable (stock + grade + solde)
 * - reason  : 'out_of_stock' | 'grade' | 'balance' | undefined (si ok)
 */
export interface PurchaseCheckResult {
  ok: boolean;
  reason?: 'out_of_stock' | 'grade' | 'balance';
}

// ── Soldes joueur ──────────────────────────────────────────────────────────────

/**
 * Lit le solde du joueur pour une devise donnée.
 * Convention :
 *  - 'money'        → leftInventory.groups.money (ou groups.cash en fallback)
 *  - 'black_money'  → leftInventory.groups.black_money
 *  - autre (custom) → somme du `count` des items dont `name === currency`
 *    dans leftInventory.items (ex: jetons, gold_token, etc.)
 */
export const getPlayerBalance = (currency: string): number => {
  const leftInventory = store.getState().inventory.leftInventory;
  const groups = leftInventory.groups ?? {};

  if (currency === 'money') {
    return groups.money ?? groups.cash ?? 0;
  }
  if (currency === 'black_money') {
    return groups.black_money ?? 0;
  }

  // Devise custom (jeton, item-currency) → on additionne les counts dans l'inventaire
  return leftInventory.items.reduce((total, slot) => {
    if (isSlotWithItem(slot) && slot.name === currency) return total + slot.count;
    return total;
  }, 0);
};

export const canPurchaseItem = (
  item: Slot,
  inventory: { type: Inventory['type']; groups: Inventory['groups'] }
): boolean => {
  return checkPurchaseItem(item, inventory).ok;
};

/**
 * Vérification détaillée d'achat (stock + grade + solde).
 * Renvoie un objet { ok, reason } pour permettre un affichage thématisé
 * (ex: "Stock épuisé" vs "Solde insuffisant" vs "Grade requis").
 */
export const checkPurchaseItem = (
  item: Slot,
  inventory: { type: Inventory['type']; groups: Inventory['groups'] }
): PurchaseCheckResult => {
  if (inventory.type !== 'shop' || !isSlotWithItem(item)) return { ok: true };

  // 1. Stock
  if (item.count !== undefined && item.count === 0) return { ok: false, reason: 'out_of_stock' };

  // 2. Grade / groupes
  if (item.grade !== undefined && inventory.groups) {
    const leftInventory = store.getState().inventory.leftInventory;
    if (!leftInventory.groups) return { ok: false, reason: 'grade' };

    const reqGroups = Object.keys(inventory.groups);
    let hasGrade = false;

    if (Array.isArray(item.grade)) {
      for (const g of reqGroups) {
        if (leftInventory.groups[g] !== undefined && item.grade.includes(leftInventory.groups[g])) { hasGrade = true; break; }
      }
    } else {
      for (const g of reqGroups) {
        if (leftInventory.groups[g] !== undefined && leftInventory.groups[g] >= (item.grade as number)) { hasGrade = true; break; }
      }
    }

    if (!hasGrade) return { ok: false, reason: 'grade' };
  }

  // 3. Solde (devise) — seulement si un prix > 0 est défini
  if (item.price && item.price > 0) {
    const currency = item.currency ?? 'money';
    const balance  = getPlayerBalance(currency);
    if (balance < item.price) return { ok: false, reason: 'balance' };
  }

  return { ok: true };
};

export const canCraftItem = (item: Slot, inventoryType: string): boolean => {
  return checkCraftItem(item, inventoryType).ok;
};

/**
 * Vérification détaillée de craft : renvoie ok + la liste des ingrédients
 * manquants (nom technique, label affichable, quantité possédée/requise).
 *
 * Règles de comptage :
 *  - count >= 1 : on compte les exemplaires possédés (Items[name].count global,
 *                  sinon nombre de slots dans leftInventory portant ce nom).
 *  - count < 1  : on interprète comme un seuil de durabilité (ex: 0.5 = 50%)
 *                  sur UN item possédé (comportement legacy conservé).
 */
export const checkCraftItem = (item: Slot, inventoryType: string): CraftCheckResult => {
  if (!isSlotWithItem(item) || inventoryType !== 'crafting' || !item.ingredients) {
    return { ok: true, missing: [] };
  }

  const leftInventory = store.getState().inventory.leftInventory;
  const missing: CraftCheckResult['missing'] = [];

  for (const [itemName, need] of Object.entries(item.ingredients)) {
    const label = Items[itemName]?.label ?? itemName;

    // Seuil de durabilité (legacy) : need < 1 → cherche un item avec durability suffisante
    if (need < 1) {
      const hasItem = leftInventory.items.some((p) => {
        if (isSlotWithItem(p) && p.name === itemName) {
          return (p.metadata?.durability ?? 0) >= need * 100;
        }
        return false;
      });
      if (!hasItem) missing.push({ name: itemName, label, have: 0, need: 1 });
      continue;
    }

    // Quantité possédée : priorité au compteur global Items[name].count,
    // sinon somme des counts des slots correspondants dans leftInventory.
    const globalItem = Items[itemName];
    let have = globalItem?.count ?? 0;

    if (!have) {
      have = leftInventory.items.reduce((total, p) => {
        if (isSlotWithItem(p) && p.name === itemName) return total + p.count;
        return total;
      }, 0);
    }

    if (have < need) missing.push({ name: itemName, label, have, need });
  }

  return { ok: missing.length === 0, missing };
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