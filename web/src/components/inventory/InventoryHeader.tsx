// components/inventory/InventoryHeader.tsx
import React, { useMemo } from 'react';
import WeightBar from '../utils/WeightBar';
import { getTotalWeight } from '../../helpers';
import { Slot } from '../../typings';

interface InventoryHeaderProps {
  label?:     string;
  maxWeight?: number;
  items:      Slot[];
}

const InventoryHeader: React.FC<InventoryHeaderProps> = React.memo(({ label, maxWeight, items }) => {
  const weight = useMemo(
    () => (maxWeight !== undefined ? Math.floor(getTotalWeight(items) * 1000) / 1000 : 0),
    [maxWeight, items]
  );

  const pct = useMemo(
    () => (maxWeight ? (weight / maxWeight) * 100 : 0),
    [weight, maxWeight]
  );

  const desc = useMemo(() => {
    if (!maxWeight) return '';
    const fmt = (v: number) => v >= 1000 ? `${(v / 1000).toFixed(2)} kg` : `${v.toFixed(0)} g`;
    return `${fmt(weight)} / ${fmt(maxWeight)}`;
  }, [weight, maxWeight]);

  return (
    <div className="inventory-grid-header-wrapper">
      <p>{label}</p>
      {maxWeight !== undefined && (
        <div className="inventory-header-weight">
          <WeightBar
            percent={pct}
            weightDescription={desc}
            currentWeight={weight * 1000}
            maxWeight={maxWeight}
          />
        </div>
      )}
    </div>
  );
});

InventoryHeader.displayName = 'InventoryHeader';
export default InventoryHeader;