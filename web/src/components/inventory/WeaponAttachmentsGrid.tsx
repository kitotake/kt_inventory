// components/inventory/WeaponAttachmentsGrid.tsx
// 6 InventorySlot positionnés en CSS absolu autour de l'arme.
// Slots vides par défaut — le joueur drag ses accessoires depuis leftInventory.
// Le Lua peut envoyer les slots déjà équipés via setupInventory.

import React, { useMemo } from 'react';
import InventorySlot from './InventorySlot';
import { Inventory } from '../../typings';

// ── Convention de position par numéro de slot ────────────────────────────
// slot 1 = scope      → top
// slot 2 = suppressor → right
// slot 3 = magazine   → bottom
// slot 4 = flashlight → left
// slot 5 = grip       → bas-gauche
// slot 6 = laser      → bas-droit
const SLOT_POSITIONS: Record<number, React.CSSProperties> = {
  1: { top: '4%',    left: '50%', transform: 'translateX(-50%)' },
  2: { top: '50%',   right: '4%', transform: 'translateY(-50%)' },
  3: { bottom: '4%', left: '50%', transform: 'translateX(-50%)' },
  4: { top: '50%',   left: '4%',  transform: 'translateY(-50%)' },
  5: { bottom: '12%', left: '8%'  },
  6: { bottom: '12%', right: '8%' },
};

interface WeaponAttachmentsGridProps {
  inventory: Inventory;
  isBusy:    boolean;
}

const WeaponAttachmentsGrid: React.FC<WeaponAttachmentsGridProps> = React.memo(
  ({ inventory, isBusy }) => {
    // Garantit que les 6 positions existent même si le Lua n'a pas envoyé d'item
    const slots = useMemo(() => {
      const bySlot = new Map(inventory.items.map((i) => [i.slot, i]));
      return Array.from({ length: 6 }, (_, i) => bySlot.get(i + 1) ?? { slot: i + 1 });
    }, [inventory.items]);

    return (
      <div className="inventory-grid-wrapper">
        <div className="inventory-grid-header-wrapper">
          <p>{inventory.label ?? 'Accessoires'}</p>
        </div>

        <div
          className="weapon-attach-canvas"
          style={{ pointerEvents: isBusy ? 'none' : 'auto' }}
        >
          {slots.map((item) => {
            const pos = SLOT_POSITIONS[item.slot];
            if (!pos) return null;
            return (
              <div
                key={`attach-${item.slot}`}
                className="weapon-attach-slot-wrapper"
                style={pos}
              >
                <InventorySlot
                  item={item}
                  inventoryType={inventory.type}
                  inventoryGroups={inventory.groups}
                  inventoryId={inventory.id}
                />
              </div>
            );
          })}
        </div>
      </div>
    );
  }
);

WeaponAttachmentsGrid.displayName = 'WeaponAttachmentsGrid';
export default WeaponAttachmentsGrid;