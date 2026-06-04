// components/inventory/index.tsx
import React, { useState } from 'react';
import useNuiEvent from '../../hooks/useNuiEvent';
import InventoryControl from './InventoryControl';
import InventoryHotbar from './InventoryHotbar';
import { useAppDispatch } from '../../store';
import { refreshSlots, setAdditionalMetadata, setupInventory } from '../../store/inventory';
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
    if (!inventoryVisible) setInventoryVisible(true);
  });

  useNuiEvent<EquippedClothing>('setupClothing', (data) => {
    dispatch(setAllEquipped(data));
  });

  useNuiEvent<{ category: string; name: string; label: string; itemType?: string }>('clothingEquipped', (data) => {
    dispatch(
      equipClothing({
        category: data.category as any,
        item: {
          name: data.name,
          label: data.label,
          itemType: (data.itemType ?? getClothingItemType(data.name)) as any,
        },
      })
    );
  });

  useNuiEvent<{ category: string }>('clothingRemoved', (data) => {
    dispatch(removeClothing(data.category as any));
  });

  useNuiEvent<{
    name: string;
    label: string;
    slots: Partial<Record<string, { name: string; label: string }>>;
  }>('outfitEquipped', (data) => {
    dispatch(
      equipOutfit({
        name: data.name,
        label: data.label,
        slots: data.slots as any,
      })
    );
  });

  useNuiEvent('refreshSlots', (data) => {
    dispatch(refreshSlots(data));
  });

  useNuiEvent('displayMetadata', (data: Array<{ metadata: string; value: string }>) => {
    dispatch(setAdditionalMetadata(data));
  });

  return (
    <>
      <Fade in={inventoryVisible}>
        <div className="inventory-wrapper">
          <div className="inventory-main-row">
            {/* COLONNE GAUCHE : inventaire items */}
            <div className="inventory-side inventory-side--left">
              <LeftInventory />
            </div>

            {/* CLOTHING GAUCHE */}
            <LeftInventoryClothing />

            {/* CENTRE : preview ped dominant */}
            <div className="inventory-center-column">
              <PlayerPreview />
              <div className="inventory-center-controls">
                <InventoryControl />
              </div>
            </div>

            {/* CLOTHING DROITE */}
            <RightInventoryClothing />

            {/* COLONNE DROITE : inventaire secondaire */}
            <div className="inventory-side inventory-side--right">
              <RightInventory />
            </div>
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
