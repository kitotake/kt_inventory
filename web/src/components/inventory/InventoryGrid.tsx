// components/inventory/InventoryGrid.tsx
import React, { useEffect, useMemo, useState } from 'react';
import { useAppSelector } from '../../store';
import WeightBar from '../utils/WeightBar';
import InventorySlot from './InventorySlot';
import InventoryFilterRight from './InventoryFilterRight';
import { getTotalWeight } from '../../helpers';
import { useIntersection } from '../../hooks/useIntersection';
import { useItemSort } from '../../hooks/useItemSort';
import { Inventory, Slot } from '../../typings';

const PAGE_SIZE = 30;
const INTERSECTION_OPTIONS = { threshold: 0.5 } as const;

const selectLeft = (s: any): Inventory => s.inventory.leftInventory;
const selectRight = (s: any): Inventory => s.inventory.rightInventory;
const selectBusy = (s: any): boolean => s.inventory.isBusy;

// ── InventoryHeader ───────────────────────────────────────────────────────────
interface HeaderProps { 
  label?: string;
  maxWeight?: number;
  items: Slot[];
}

const InventoryHeader: React.FC<HeaderProps> = React.memo(({ label, maxWeight, items }) => {
  const weight = useMemo(
    () => (maxWeight !== undefined ? Math.floor(getTotalWeight(items) * 1000) / 1000 : 0),
    [maxWeight, items]
  );
  const pct = useMemo(() => (maxWeight ? (weight / maxWeight) * 100 : 0), [weight, maxWeight]);
  const desc = useMemo(() => {
    if (!maxWeight) return '';
    const fmt = (v: number) => (v >= 1000 ? `${(v / 1000).toFixed(2)} kg` : `${v.toFixed(0)} g`);
    return `${fmt(weight)} / ${fmt(maxWeight)}`;
  }, [weight, maxWeight]);

  return (
    <div className="inventory-grid-header-wrapper">
      <p>{label}</p>
      {maxWeight !== undefined && (
        <div className="inventory-header-weight">
          <WeightBar percent={pct} weightDescription={desc} currentWeight={weight * 1000} maxWeight={maxWeight} />
        </div>
      )}
    </div>
  );
});
InventoryHeader.displayName = 'InventoryHeader';

// ── SlotList ──────────────────────────────────────────────────────────────────
interface SlotListProps {
  items: Slot[];
  inventoryType: Inventory['type'];
  inventoryGroups: Inventory['groups'];
  inventoryId: Inventory['id'];
  isBusy: boolean;
  highlightedSlots: Set<number>;
  hasActiveFilter: boolean;
}

const SlotList: React.FC<SlotListProps> = React.memo(
  ({ items, inventoryType, inventoryGroups, inventoryId, isBusy, highlightedSlots, hasActiveFilter }) => {
    const [page, setPage] = useState(0);
    const { ref, entry } = useIntersection(INTERSECTION_OPTIONS);

    useEffect(() => {
      if (entry?.isIntersecting) setPage((p) => p + 1);
    }, [entry]);
    useEffect(() => {
      setPage(0);
    }, [inventoryId]);

    const visibleCount = (page + 1) * PAGE_SIZE;
    const sentinelIdx = visibleCount - 1;

    const visibleItems = useMemo(
      () => items.slice(0, visibleCount),
      // eslint-disable-next-line react-hooks/exhaustive-deps
      [items, page]
    );

    return (
      <div
        className="inventory-grid-container"
        style={{ pointerEvents: isBusy ? 'none' : 'auto' }}
        data-filtering={hasActiveFilter ? 'true' : undefined}
      >
        {visibleItems.map((item, index) => (
          <div
            key={`${inventoryType}-${inventoryId}-${item.slot}`}
            className="slot-highlight-wrapper"
            data-highlighted={!hasActiveFilter || highlightedSlots.has(item.slot) ? 'true' : 'false'}
          >
            <InventorySlot
              item={item}
              ref={index === sentinelIdx ? ref : null}
              inventoryType={inventoryType}
              inventoryGroups={inventoryGroups}
              inventoryId={inventoryId}
            />
          </div>
        ))}
      </div>
    );
  }
);
SlotList.displayName = 'SlotList';

// ── InventoryGrid ─────────────────────────────────────────────────────────────
interface InventoryGridProps {
  side: 'left' | 'right';
}

const InventoryGrid: React.FC<InventoryGridProps> = ({ side }) => {
  const inventory = useAppSelector(side === 'left' ? selectLeft : selectRight);
  const isBusy = useAppSelector(selectBusy);

  const { sortedItems, highlightedSlots, activeCategory, sortOrder, setCategory, setSortOrder, resetFilters } =
    useItemSort(inventory.items, inventory.id);

  const hasActiveFilter = activeCategory !== 'all';

  return (
    <div className="inventory-grid-wrapper">
      <InventoryHeader label={inventory.label} 
      maxWeight={inventory.maxWeight} 
      items={inventory.items} />
      <InventoryFilterRight
        side={side}
        activeCategory={activeCategory}
        sortOrder={sortOrder}
        highlightCount={highlightedSlots.size}
        onCategoryChange={setCategory}
        onSortChange={setSortOrder}
        onReset={resetFilters}
      />
      <SlotList
        items={sortedItems}
        inventoryType={inventory.type}
        inventoryGroups={inventory.groups}
        inventoryId={inventory.id}
        isBusy={isBusy}
        highlightedSlots={highlightedSlots}
        hasActiveFilter={hasActiveFilter}
      />
    </div>
  );
};

export default React.memo(InventoryGrid);