// components/inventory/index.tsx
import React, { useState } from 'react';
import useNuiEvent from '../../hooks/useNuiEvent';
import InventoryControl from './InventoryControl';
import InventoryHotbar  from './InventoryHotbar';
import { useAppDispatch, useAppSelector } from '../../store';
import {
  refreshSlots, setAdditionalMetadata, setupInventory,
  clearSlot, closeAndReset, selectLayoutMode, selectRightInventory,
} from '../../store/inventory';
import {
  setAllEquipped, equipClothing, removeClothing, equipOutfit,
} from '../../store/clothing';
import { setPlayerStatus } from '../../store/playerStatus';
import { useExitListener } from '../../hooks/useExitListener';
import type { Inventory as InventoryProps } from '../../typings';
import type { EquippedClothing } from '../../typings/clothing';
import { getClothingItemType } from '../../typings/clothing';
import RightInventory        from './RightInventory';
import LeftInventory         from './LeftInventory';
import LeftInventoryClothing from './LeftInventoryClothing';
import RightInventoryClothing from './RightInventoryClothing';
import PlayerPreview          from './PlayerPreview';
import DevModeSwitcher        from './DevModeSwitcher';
import { isEnvBrowser }       from '../../utils/misc';

import InventoryContext from './InventoryContext';
import { closeContextMenu } from '../../store/contextMenu';
import Fade from '../utils/transitions/Fade';

const Inventory: React.FC = () => {
  const [inventoryVisible, setInventoryVisible] = useState(false);
  const dispatch   = useAppDispatch();
  const layoutMode = useAppSelector(selectLayoutMode);

  // ── Panneaux visibles selon le layoutMode ─────────────────────────────
  const showLeftClothing  = layoutMode === 'default' || layoutMode === 'exchange';
  const showPreview       = layoutMode === 'default' || layoutMode === 'exchange';
  const showRightClothing = layoutMode === 'default' || layoutMode === 'exchange';
  const showWeaponCenter  = layoutMode === 'weapon';

  // ── Événements NUI ────────────────────────────────────────────────────

  useNuiEvent<boolean>('setInventoryVisible', setInventoryVisible);

  useNuiEvent<false>('closeInventory', () => {
    setInventoryVisible(false);
    dispatch(closeContextMenu());
    dispatch(closeAndReset());
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

  useNuiEvent<{
    category: string;
    name: string;
    label: string;
    itemType?: string;
    consumedInvSlot?: number;
  }>('clothingEquipped', (data) => {
    dispatch(equipClothing({
      category: data.category as any,
      item: {
        name:     data.name,
        label:    data.label,
        itemType: (data.itemType ?? getClothingItemType(data.name)) as any,
      },
    }));
    if (typeof data.consumedInvSlot === 'number' && data.consumedInvSlot > 0) {
      dispatch(clearSlot({ slot: data.consumedInvSlot }));
    }
  });

  useNuiEvent<{ category: string }>('clothingRemoved', (data) => {
    dispatch(removeClothing(data.category as any));
  });

  useNuiEvent<{
    name:  string;
    label: string;
    slots: Partial<Record<string, { name: string; label: string }>>;
  }>('outfitEquipped', (data) => {
    dispatch(equipOutfit({ name: data.name, label: data.label, slots: data.slots as any }));
  });

  useNuiEvent('refreshSlots', (data) => { dispatch(refreshSlots(data)); });

  useNuiEvent('displayMetadata', (data: Array<{ metadata: string; value: string }>) => {
    dispatch(setAdditionalMetadata(data));
  });

  /** Met à jour les jauges faim / soif depuis le Lua.
   *  Payload attendu : `{ food: number, drink: number }` (0-100) */
  useNuiEvent<{ food?: number; drink?: number }>('setPlayerStatus', (data) => {
    dispatch(setPlayerStatus(data));
  });

  return (
    <>
      <Fade in={inventoryVisible}>
        <div className="inventory-wrapper">
          <div className="inventory-main-row">

            {/* ── COLONNE GAUCHE ──────────────────────────────────────── */}
            {/* InventoryControl est ici, sous la grille du joueur        */}
            <div className="inventory-side inventory-side--left">
              <LeftInventory />
             
            </div>

            {/* ── CLOTHING GAUCHE ─────────────────────────────────────── */}
            {showLeftClothing && <LeftInventoryClothing />}

            {/* ── CENTRE — preview ped uniquement ─────────────────────── */}
            {showPreview && (
              <div className="inventory-center-column">
                <PlayerPreview />
                  <div className="inventory-center-controls">
                  <InventoryControl />
                </div>
              </div>
            )}

            {/* ── CENTRE — mode arme ──────────────────────────────────── */}
            {showWeaponCenter && (
              <div className="inventory-center-column inventory-center-column--weapon">
                <div className="weapon-center-hint">
                  <i className="ti ti-gun" aria-hidden="true" />
                  <span>Glisser un accessoire<br />sur un slot</span>
                </div>
              </div>
            )}

            {/* ── CLOTHING DROITE ─────────────────────────────────────── */}
            {showRightClothing && <RightInventoryClothing />}

            {/* ── COLONNE DROITE ──────────────────────────────────────── */}
            <div className="inventory-side inventory-side--right">
              {isEnvBrowser() && <DevModeSwitcher />}
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