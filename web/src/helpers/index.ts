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

// ─────────────────────────────────────────────────────────────────────────────
// IMAGE URL + FALLBACK AUTOMATIQUE
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Cache des URLs déjà résolues (évite de re-tester à chaque render).
 * key   = itemName
 * value = URL finale confirmée ou null si aucune trouvée
 */
const resolvedUrlCache = new Map<string, string | null>();

/**
 * Vérifie si une URL d'image existe réellement (charge l'image en mémoire).
 * Retourne l'URL si ok, null sinon.
 */
const probeImage = (url: string): Promise<string | null> =>
  new Promise((resolve) => {
    const img = new Image();
    img.onload  = () => resolve(url);
    img.onerror = () => resolve(null);
    img.src = url;
  });

/**
 * Séquence de fallback pour un itemName donné :
 *   1. images/{itemName}.png                   ← chemin flat standard
 *   2. images/{itemName}/{itemName}.png         ← sous-dossier éponyme
 *   3. images/default.png                      ← image générique ultime
 *
 * Le résultat est mis en cache pour ne pas re-tester à chaque render.
 */
export const resolveItemUrl = async (itemName: string): Promise<string> => {
  if (resolvedUrlCache.has(itemName)) {
    return resolvedUrlCache.get(itemName) ?? `${imagepath}/default.png`;
  }

  const candidates = [
    `${imagepath}/${itemName}.png`,
    `${imagepath}/${itemName}/${itemName}.png`,
    `${imagepath}/default.png`,
  ];

  for (const url of candidates) {
    const ok = await probeImage(url);
    if (ok) {
      resolvedUrlCache.set(itemName, url);
      return url;
    }
  }

  // Aucune image trouvée — on stocke null et on retourne le fallback générique
  resolvedUrlCache.set(itemName, null);
  return `${imagepath}/default.png`;
};

/**
 * Version synchrone (usage dans backgroundImage CSS / src des balises <img>).
 * Retourne immédiatement le premier candidat plausible.
 * La résolution asynchrone s'effectue en arrière-plan et met à jour le cache
 * pour les renders suivants.
 *
 * Logique de priorité :
 *   - metadata.imageurl  → URL externe absolue (imgur, etc.)
 *   - metadata.folder + metadata.image → sous-dossier custom
 *   - metadata.image    → chemin relatif custom
 *   - itemData.image    → image déjà résolue en cache sur l'item
 *   - fallback sync     → images/{itemName}.png  (le onError de l'<img> prendra le relais)
 */
export const getItemUrl = (item: string | SlotWithItem): string | undefined => {
  const isObj    = typeof item === 'object';
  const itemName = isObj ? (item as SlotWithItem).name : item;

  if (!itemName) return undefined;

  // ── Priorité 1 : overrides metadata ─────────────────────────────────────
  if (isObj) {
    const metadata = (item as SlotWithItem).metadata;

    if (metadata?.imageurl) return metadata.imageurl as string;

    if (metadata?.folder && metadata?.image)
      return `${imagepath}/${metadata.folder}/${metadata.image}.png`;

    if (metadata?.image)
      return `${imagepath}/${metadata.image}.png`;
  }

  // ── Priorité 2 : image déjà résolue sur l'item dans le store ────────────
  const itemData = Items[itemName];
  if (itemData?.image) return itemData.image;

  // ── Priorité 3 : cache de résolution async ───────────────────────────────
  if (resolvedUrlCache.has(itemName)) {
    const cached = resolvedUrlCache.get(itemName);
    if (cached) return cached;
  }

  // ── Priorité 4 : candidate plausible + résolution async en arrière-plan ──
  // On lance la probe sans bloquer. Le résultat sera en cache au prochain render.
  resolveItemUrl(itemName).then((url) => {
    // Mémoriser sur l'item data pour éviter de repasser par le cache Map
    if (itemData) itemData.image = url;
  });

  // Retour immédiat : chemin flat standard (le navigateur appellera onError si absent)
  return `${imagepath}/${itemName}.png`;
};

/**
 * Hook React pour forcer un re-render quand l'URL est résolue de manière async.
 *
 * Usage dans un composant :
 *   const url = useItemUrl(item.name);
 *   <div style={{ backgroundImage: `url(${url})` }} />
 */
import { useState, useEffect } from 'react';

export const useItemUrl = (itemName: string | undefined): string => {
  const fallback = itemName ? `${imagepath}/${itemName}.png` : '';
  const [url, setUrl] = useState<string>(() => {
    if (!itemName) return '';
    // Utiliser le cache synchrone si disponible
    const cached = resolvedUrlCache.get(itemName);
    if (cached) return cached;
    const itemData = Items[itemName];
    if (itemData?.image) return itemData.image;
    return fallback;
  });

  useEffect(() => {
    if (!itemName) return;

    // Si déjà dans le cache, mettre à jour immédiatement
    if (resolvedUrlCache.has(itemName)) {
      const cached = resolvedUrlCache.get(itemName);
      if (cached && cached !== url) setUrl(cached);
      return;
    }

    // Sinon résoudre en async
    let cancelled = false;
    resolveItemUrl(itemName).then((resolved) => {
      if (!cancelled) setUrl(resolved);
    });

    return () => { cancelled = true; };
  }, [itemName]);

  return url;
};

/**
 * Gestionnaire onError à placer sur les balises <img> et divs avec backgroundImage.
 * Enchaîne automatiquement les fallbacks sans passer par le cache async.
 *
 * Usage :
 *   <img src={getItemUrl(item)} onError={createImageFallback(item.name)} />
 *
 * Ou pour un div avec backgroundImage (via ref) :
 *   <div ref={el => el && attachImageFallback(el, item.name)} />
 */
export const createImageFallback = (itemName: string) => {
  const candidates = [
    `${imagepath}/${itemName}/${itemName}.png`,
    `${imagepath}/default.png`,
  ];
  let attempt = 0;

  return (event: React.SyntheticEvent<HTMLImageElement>) => {
    if (attempt < candidates.length) {
      event.currentTarget.src = candidates[attempt];
      attempt++;
    } else {
      // Plus de fallback : masquer l'image cassée
      event.currentTarget.style.display = 'none';
    }
  };
};

/**
 * Variante pour les divs avec backgroundImage (utilise un <img> fantôme).
 * Appelle le callback avec l'URL résolue une fois confirmée.
 *
 * Usage :
 *   resolveAndApply(itemName, (url) => {
 *     divRef.current.style.backgroundImage = `url(${url})`;
 *   });
 */
export const resolveAndApply = (
  itemName: string,
  callback: (url: string) => void
): void => {
  resolveItemUrl(itemName).then(callback);
};

/**
 * Vide le cache de résolution (utile si les images changent dynamiquement,
 * ex: reconnexion après mise à jour du serveur de ressources).
 */
export const clearImageCache = (): void => {
  resolvedUrlCache.clear();
  for (const key in Items) {
    if (Items[key]) Items[key]!.image = undefined;
  }
};