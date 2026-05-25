// components/inventory/RightInventoryClothing.tsx

import React from 'react';

import ClothingGrid from './ClothingGrid';

import {
  RIGHT_CLOTHING_SLOTS,
} from '../../typings/clothing';

const RightInventoryClothing: React.FC = () => {
  return (
    <ClothingGrid
      title="Vêtements"
      side="right"
      slots={RIGHT_CLOTHING_SLOTS}
    />
  );
};

export default RightInventoryClothing;