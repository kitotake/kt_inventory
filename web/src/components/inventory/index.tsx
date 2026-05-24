// components/inventory/index.tsx
// MODIFIÉ : nouveau layout
// [LeftInventory] [LeftInventoryClothing] [PlayerPreview] [RightInventoryClothing] [RightInventory]
//                            [InventoryControl — input quantité]

import React, { useState } from 'react';
import useNuiEvent from '../../hooks/useNuiEvent';
import InventoryControl from './InventoryControl';
import InventoryHotbar from './InventoryHotbar';
import { useAppDispatch } from '../../store';
import { refreshSlots, setAdditionalMetadata, setupInventory } from '../../store/inventory';
import { setAllEquipped } from '../../store/clothing';
import { useExitListener } from '../../hooks/useExitListener';
import type { Inventory as InventoryProps } from '../../typings';
import type { EquippedClothing } from '../../typings/clothing';
import RightInventory from './RightInventory';
import LeftInventory from './LeftInventory';
import LeftInventoryClothing from './LeftInventoryClothing';
import RightInventoryClothing from './RightInventoryClothing';
import PlayerPreview from './PlayerPreview';
import Tooltip from '../utils/Tooltip';
import { closeTooltip } from '../../store/tooltip';
import InventoryContext from './InventoryContext';
import { closeContextMenu } from '../../store/contextMenu';
import Fade from '../utils/transitions/Fade';

const Inventory: React.FC = () => {
  const [inventoryVisible, setInventoryVisible] = useState(false);
  const dispatch = useAppDispatch();

  useNuiEvent<boolean>('setInventoryVisible', setInventoryVisible);

  useNuiEvent<false>('closeInventory', () => {
    setInventoryVisible(false);
    dispatch(closeContextMenu());
    dispatch(closeTooltip());
  });

  useExitListener(setInventoryVisible);

  useNuiEvent<{
    leftInventory?: InventoryProps;
    rightInventory?: InventoryProps;
  }>('setupInventory', (data) => {
    dispatch(setupInventory(data));
    !inventoryVisible && setInventoryVisible(true);
  });

  // Réception des vêtements équipés depuis le client Lua
  useNuiEvent<EquippedClothing>('setupClothing', (data) => {
    dispatch(setAllEquipped(data));
  });

  useNuiEvent('refreshSlots', (data) => dispatch(refreshSlots(data)));

  useNuiEvent('displayMetadata', (data: Array<{ metadata: string; value: string }>) => {
    dispatch(setAdditionalMetadata(data));
  });

  return (
    <>
      <Fade in={inventoryVisible}>
        <div className="inventory-wrapper">

          {/* Ligne principale : 5 panneaux */}
          <div className="inventory-main-row">
            <LeftInventory />
            <LeftInventoryClothing />
            <PlayerPreview />
            <RightInventoryClothing />
            <RightInventory />
          </div>

          {/* Input quantité tout en bas */}
          <InventoryControl />

          {/* Tooltip et context menu */}
          <Tooltip />
          <InventoryContext />

        </div>
      </Fade>
      <InventoryHotbar />
    </>
  );
};

export default Inventory;
