// components/inventory/InventorySlotList.tsx
import React, { useEffect, useMemo, useState } from 'react';
import InventorySlot from './InventorySlot';
import { useIntersection } from '../../hooks/useIntersection';
import { Inventory, Slot } from '../../typings';

const PAGE_SIZE = 30;
const INTERSECTION_OPTIONS = { threshold: 0.5 } as const;

interface InventorySlotListProps {
  items:            Slot[];
  inventoryType:    Inventory['type'];
  inventoryGroups:  Inventory['groups'];
  inventoryId:      Inventory['id'];
  isBusy:           boolean;
  highlightedSlots: Set<number>;
  hasActiveFilter:  boolean;
}

const InventorySlotList: React.FC<InventorySlotListProps> = React.memo(
  ({ items, inventoryType, inventoryGroups, inventoryId, isBusy, highlightedSlots, hasActiveFilter }) => {
    const [page, setPage] = useState(0);
    const { ref, entry }  = useIntersection(INTERSECTION_OPTIONS);

    // Avance d'une page quand le sentinel devient visible
    useEffect(() => {
      if (entry?.isIntersecting) setPage((p) => p + 1);
    }, [entry]);

    // Reset page quand l'inventaire change
    useEffect(() => {
      setPage(0);
    }, [inventoryId]);

    const visibleCount = (page + 1) * PAGE_SIZE;
    const sentinelIdx  = visibleCount - 1;

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

InventorySlotList.displayName = 'InventorySlotList';
export default InventorySlotList;