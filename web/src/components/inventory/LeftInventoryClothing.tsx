// components/inventory/LeftInventoryClothing.tsx

import React from 'react';

import ClothingGrid from './ClothingGrid';

import {
  LEFT_CLOTHING_SLOTS,
} from '../../typings/clothing';

const LeftInventoryClothing: React.FC = () => {
  return (
    <ClothingGrid
      side="left"
      slots={LEFT_CLOTHING_SLOTS}
    />
  );
};

export default LeftInventoryClothing;