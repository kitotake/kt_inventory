// components/inventory/RightInventory.tsx
import React from 'react';
import InventoryGrid from './InventoryGrid';

const RightInventory: React.FC = () => <InventoryGrid side="right" />;
export default React.memo(RightInventory);
