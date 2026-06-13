// components/inventory/index.tsx
// v2 :
//   ✓ event 'clothingEquipped' → si data.consumedInvSlot est fourni, on vide
//     ce slot dans leftInventory immédiatement (anticipation visuelle avant
//     le refreshSlots complet envoyé par le serveur)

import React, { useState } from 'react';
import useNuiEvent from '../../hooks/useNuiEvent';
import InventoryControl from './InventoryControl';
import InventoryHotbar from './InventoryHotbar';
import { useAppDispatch } from '../../store';
import { refreshSlots, setAdditionalMetadata, setupInventory, clearSlot } from '../../store/inventory';
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

  // Reçu depuis Lua handleClothingItem / equipClothingItem.
  // consumedInvSlot (optionnel) : slot inventaire à vider immédiatement,
  // en anticipation du refreshSlots complet envoyé par le serveur.
  useNuiEvent<{
    category: string;
    name: string;
    label: string;
    itemType?: string;
    consumedInvSlot?: number;
  }>('clothingEquipped', (data) => {
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

    if (typeof data.consumedInvSlot === 'number' && data.consumedInvSlot > 0) {
      dispatch(clearSlot({ slot: data.consumedInvSlot }));
    }
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

          
          <InventoryContext />
        </div>
      </Fade>

      <InventoryHotbar />
    </>
  );
};

export default Inventory;