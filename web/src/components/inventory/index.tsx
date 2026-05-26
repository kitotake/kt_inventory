// components/inventory/index.tsx

import React, { useState } from 'react';

import useNuiEvent from '../../hooks/useNuiEvent';

import InventoryControl from './InventoryControl';
import InventoryHotbar from './InventoryHotbar';

import { useAppDispatch } from '../../store';

import {
  refreshSlots,
  setAdditionalMetadata,
  setupInventory,
} from '../../store/inventory';

import { setAllEquipped, equipClothing, removeClothing, equipOutfit } from '../../store/clothing';

import { useExitListener } from '../../hooks/useExitListener';

import type { Inventory as InventoryProps } from '../../typings';
import type { EquippedClothing } from '../../typings/clothing';
import { getClothingItemType } from '../../typings/clothing';

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

  // =====================================================
  // EVENTS
  // =====================================================

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
    if (!inventoryVisible) {
      setInventoryVisible(true);
    }
  });

  // Sync vêtements depuis le Lua (état initial à l'ouverture)
  useNuiEvent<EquippedClothing>('setupClothing', (data) => {
    dispatch(setAllEquipped(data));
  });

  // Equip d'un vêtement individuel depuis le Lua
  useNuiEvent<{ category: string; name: string; label: string; itemType?: string }>(
    'clothingEquipped',
    (data) => {
      dispatch(
        equipClothing({
          category: data.category as any,
          item: {
            name:     data.name,
            label:    data.label,
            itemType: (data.itemType ?? getClothingItemType(data.name)) as any,
          },
        })
      );
    }
  );

  // Retrait d'un vêtement depuis le Lua
  useNuiEvent<{ category: string }>('clothingRemoved', (data) => {
    dispatch(removeClothing(data.category as any));
  });

  // Tenue complète équipée depuis le Lua
  useNuiEvent<{
    name:  string;
    label: string;
    slots: Partial<Record<string, { name: string; label: string }>>;
  }>('outfitEquipped', (data) => {
    dispatch(equipOutfit({
      name:  data.name,
      label: data.label,
      slots: data.slots as any,
    }));
  });

  useNuiEvent('refreshSlots', (data) => {
    dispatch(refreshSlots(data));
  });

  useNuiEvent(
    'displayMetadata',
    (data: Array<{ metadata: string; value: string }>) => {
      dispatch(setAdditionalMetadata(data));
    }
  );

  // =====================================================
  // RENDER
  // =====================================================

  return (
    <>
      <Fade in={inventoryVisible}>
        <div className="inventory-wrapper">

          <div className="inventory-main-row">

            <LeftInventory />

            <LeftInventoryClothing />

            {/* CENTER */}
            <div className="inventory-center-column">
              <PlayerPreview />
              <InventoryControl />
            </div>

            <RightInventoryClothing />

            <RightInventory />

          </div>

          <Tooltip />
          <InventoryContext />

        </div>
      </Fade>

      <InventoryHotbar />
    </>
  );
};

export default Inventory;
