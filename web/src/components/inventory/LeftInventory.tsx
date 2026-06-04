// components/inventory/LeftInventory.tsx
import React from 'react';
import InventoryGrid from './InventoryGrid';

const LeftInventory: React.FC = () => <InventoryGrid side="left" />;

export default React.memo(LeftInventory);
