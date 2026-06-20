// components/inventory/InventoryGrid.tsx
// Orchestrateur — choisit le bon rendu selon side + layoutMode.

import React from 'react';
import { useAppSelector } from '../../store';
import InventoryHeader       from './InventoryHeader';
import InventorySlotList     from './InventorySlotList';
import InventoryFilterRight  from './InventoryFilterRight';
import WeaponAttachmentsGrid from './WeaponAttachmentsGrid';
import { useItemSort } from '../../hooks/useItemSort';
import { Inventory } from '../../typings';
import { selectLayoutMode } from '../../store/inventory';

const selectLeft  = (s: any): Inventory => s.inventory.leftInventory;
const selectRight = (s: any): Inventory => s.inventory.rightInventory;
const selectBusy  = (s: any): boolean   => s.inventory.isBusy;

interface InventoryGridProps {
  side: 'left' | 'right';
}

const InventoryGrid: React.FC<InventoryGridProps> = ({ side }) => {
  const inventory  = useAppSelector(side === 'left' ? selectLeft : selectRight);
  const isBusy     = useAppSelector(selectBusy);
  const layoutMode = useAppSelector(selectLayoutMode);

  const {
    sortedItems, highlightedSlots,
    activeCategory, sortOrder,
    setCategory, setSortOrder, resetFilters,
  } = useItemSort(inventory.items, inventory.id);

  // Mode weapon — panneau droit remplacé par les slots accessoires
  if (side === 'right' && layoutMode === 'weapon') {
    return <WeaponAttachmentsGrid inventory={inventory} isBusy={isBusy} />;
  }

  return (
    <div className="inventory-grid-wrapper">
      {/*
        InventoryHeader reçoit `side` pour afficher :
          left  → weight-circle + food-circle (nourriture)
          right → weight-circle + drink-circle (boisson)
      */}
      <InventoryHeader
        label={inventory.label}
        maxWeight={inventory.maxWeight}
        items={inventory.items}
        side={side}
      />

      <InventoryFilterRight
        side={side}
        activeCategory={activeCategory}
        sortOrder={sortOrder}
        highlightCount={highlightedSlots.size}
        onCategoryChange={setCategory}
        onSortChange={setSortOrder}
        onReset={resetFilters}
      />

      <InventorySlotList
        items={sortedItems}
        inventoryType={inventory.type}
        inventoryGroups={inventory.groups}
        inventoryId={inventory.id}
        isBusy={isBusy}
        highlightedSlots={highlightedSlots}
        hasActiveFilter={activeCategory !== 'all'}
      />
    </div>
  );
};

export default React.memo(InventoryGrid);