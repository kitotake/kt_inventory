// hooks/useItemSort.ts
// Tri/filtrage par catégorie sans mutation Redux.
// CONTRAINTE : item.slot (position réelle) jamais modifié.

import { useMemo, useState, useCallback } from 'react';
import { Slot, SlotWithItem } from '../typings';
import { Items } from '../store/items';
import { isSlotWithItem } from '../helpers';

export type SortCategory = 'all' | 'weapons' | 'food' | 'drinks' | 'clothing' | 'medical';

export type SortOrder = 'slot' | 'name' | 'weight' | 'count';

export interface UseItemSortResult {
  sortedItems: Slot[];
  highlightedSlots: Set<number>;
  activeCategory: SortCategory;
  sortOrder: SortOrder;
  setCategory: (cat: SortCategory) => void;
  setSortOrder: (order: SortOrder) => void;
  resetFilters: () => void;
}

const CATEGORY_MATCHERS: Record<SortCategory, (item: SlotWithItem) => boolean> = {
  all: () => true,
  weapons: (i) => {
    const n = i.name.toLowerCase(),
      c = Items[i.name]?.category?.toLowerCase() ?? '';
    return n.startsWith('weapon_') || n.startsWith('ammo_') || c === 'weapon' || c === 'ammo';
  },
  food: (i) => {
    const n = i.name.toLowerCase(),
      c = Items[i.name]?.category?.toLowerCase() ?? '';
    return (
      c === 'food' || ['burger', 'sandwich', 'bread', 'taco', 'hotdog', 'pizza', 'meat'].some((k) => n.includes(k))
    );
  },
  drinks: (i) => {
    const n = i.name.toLowerCase(),
      c = Items[i.name]?.category?.toLowerCase() ?? '';
    return c === 'drink' || ['water', 'juice', 'coffee', 'beer', 'soda', 'cola', 'energy'].some((k) => n.includes(k));
  },
  clothing: (i) => {
    const c = Items[i.name]?.category?.toLowerCase() ?? '';
    return c === 'clothing' || c === 'clothing_tenu';
  },
  medical: (i) => {
    const n = i.name.toLowerCase(),
      c = Items[i.name]?.category?.toLowerCase() ?? '';
    return (
      c === 'medical' ||
      ['bandage', 'morphine', 'adrenaline', 'medkit', 'firstaid', 'pill', 'painkiller'].some((k) => n.includes(k))
    );
  },
};

const COMPARATORS: Record<SortOrder, (a: Slot, b: Slot) => number> = {
  slot: (a, b) => a.slot - b.slot,
  name: (a, b) => (a.name ?? '').localeCompare(b.name ?? ''),
  weight: (a, b) => (b.weight ?? 0) - (a.weight ?? 0),
  count: (a, b) => ((b as SlotWithItem).count ?? 0) - ((a as SlotWithItem).count ?? 0),
};

export const useItemSort = (items: Slot[], _inventoryId: string): UseItemSortResult => {
  const [activeCategory, setActiveCategory] = useState<SortCategory>('all');
  const [sortOrder, setSortOrderState] = useState<SortOrder>('slot');

  const setCategory = useCallback((c: SortCategory) => setActiveCategory(c), []);
  const setSortOrder = useCallback((o: SortOrder) => setSortOrderState(o), []);
  const resetFilters = useCallback(() => {
    setActiveCategory('all');
    setSortOrderState('slot');
  }, []);

  const { sortedItems, highlightedSlots } = useMemo(() => {
    const hasFilter = activeCategory !== 'all';
    const matcher = CATEGORY_MATCHERS[activeCategory];
    const comparator = COMPARATORS[sortOrder];
    const highlighted = new Set<number>();

    if (hasFilter) {
      for (const slot of items) {
        if (!isSlotWithItem(slot)) continue;
        if (matcher(slot as SlotWithItem)) highlighted.add(slot.slot);
      }
    }

    let sorted: Slot[];
    if (sortOrder === 'slot' && !hasFilter) {
      sorted = items;
    } else {
      sorted = [...items].sort((a, b) => {
        const af = isSlotWithItem(a),
          bf = isSlotWithItem(b);
        if (af && !bf) return -1;
        if (!af && bf) return 1;
        if (!af && !bf) return a.slot - b.slot;
        return comparator(a, b);
      });
    }

    return { sortedItems: sorted, highlightedSlots: highlighted };
  }, [items, activeCategory, sortOrder]);

  return { sortedItems, highlightedSlots, activeCategory, sortOrder, setCategory, setSortOrder, resetFilters };
};

export const CATEGORY_LABELS: Record<SortCategory, string> = {
  all: 'Tout',
  weapons: 'Armes',
  food: 'Nourriture',
  drinks: 'Boissons',
  clothing: 'Vêtements',
  medical: 'Médical',
};

export const SORT_ORDER_LABELS: Record<SortOrder, string> = {
  slot: 'Position',
  name: 'Nom',
  weight: 'Poids',
  count: 'Quantité',
};
