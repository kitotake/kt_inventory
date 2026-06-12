// components/inventory/InventorySlot.tsx
// Correction v7 :
//   [FIX-C1] (v6) → revu : le drop depuis un ClothingSlot n'effectue plus de
//            dispatch(removeClothing) immédiat. On appelle 'removeClothing'
//            côté Lua et on attend la confirmation serveur (ok=true) avant
//            de mettre à jour Redux. Si ok=false (inventaire plein), rien
//            ne change : le vêtement reste équipé, l'item ne réapparaît pas.

import React, { useCallback, useMemo, useRef } from 'react';
import { useDrag, useDrop }      from 'react-dnd';
import { useAppDispatch }        from '../../store';
import WeightBar                 from '../utils/WeightBar';
import { onDrop }                from '../../dnd/onDrop';
import { onBuy }                 from '../../dnd/onBuy';
import { onCraft }               from '../../dnd/onCraft';
import { onUse }                 from '../../dnd/onUse';
import { Items }                 from '../../store/items';
import { Locale }                from '../../store/locale';
import { canCraftItem, canPurchaseItem, getItemUrl, isSlotWithItem } from '../../helpers';
import { closeTooltip, openTooltip } from '../../store/tooltip';
import { openContextMenu }       from '../../store/contextMenu';
import { removeClothing }        from '../../store/clothing';
import { fetchNui }              from '../../utils/fetchNui';
import { DragSource, Inventory, InventoryType, Slot, SlotWithItem } from '../../typings';
import type { ClothingDragSource } from './ClothingSlot';

const DRAG_TYPE = 'SLOT';

interface RemoveResponse {
  ok: boolean;
  reason?: string;
}

interface SlotProps {
  inventoryId:     Inventory['id'];
  inventoryType:   Inventory['type'];
  inventoryGroups: Inventory['groups'];
  item:            Slot;
}

// ── ShopPrice — sous-composant mémoïsé ───────────────────────────────────────
const ShopPrice: React.FC<{ item: SlotWithItem }> = React.memo(({ item }) => {
  if (!item.price || item.price === 0) return null;
  const isCustom = item.currency && item.currency !== 'money' && item.currency !== 'black_money';
  if (isCustom) {
    return (
      <div className="item-slot-currency-wrapper">
        <img
          src={item.currency ? (getItemUrl(item.currency) ?? '') : ''}
          alt="currency"
          style={{ imageRendering: '-webkit-optimize-contrast', height: 'auto', width: '2vh', backfaceVisibility: 'hidden' }}
        />
        <p>{item.price.toLocaleString('en-us')} {Locale.$ ?? '$'}</p>
      </div>
    );
  }
  return (
    <div className="item-slot-price-wrapper" style={{ color: !item.currency || item.currency === 'money' ? '#22c55e' : '#ef4444' }}>
      <p>{item.price.toLocaleString('en-us')} {Locale.$ ?? '$'}</p>
    </div>
  );
});
ShopPrice.displayName = 'ShopPrice';

// ── InventorySlot ─────────────────────────────────────────────────────────────
const InventorySlot: React.ForwardRefRenderFunction<HTMLDivElement, SlotProps> = (
  { item, inventoryId, inventoryType, inventoryGroups }, ref
) => {
  const dispatch = useAppDispatch();
  const timerRef = useRef<number | null>(null);

  const canPurchase = canPurchaseItem(item, { type: inventoryType, groups: inventoryGroups });
  const canCraft    = canCraftItem(item, inventoryType);

  // [FIX-B6] inventoryGroups sérialisé pour éviter les re-créations de canDrag
  // eslint-disable-next-line react-hooks/exhaustive-deps
  const groupsKey = useMemo(() => JSON.stringify(inventoryGroups), [inventoryGroups]);

  // [FIX-B9] Logique conditionnelle par type d'inventaire
  const canDrag = useCallback(
    () => {
      if (inventoryType === InventoryType.SHOP)     return canPurchaseItem(item, { type: inventoryType, groups: inventoryGroups });
      if (inventoryType === InventoryType.CRAFTING) return canCraftItem(item, inventoryType);
      return true;
    },
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [item.slot, item.name, inventoryType, groupsKey]
  );

  const [{ isDragging }, drag] = useDrag<DragSource, void, { isDragging: boolean }>(
    () => ({
      type: DRAG_TYPE,
      collect: (m) => ({ isDragging: m.isDragging() }),
      item: () =>
        isSlotWithItem(item, inventoryType !== InventoryType.SHOP)
          ? {
              inventory: inventoryType,
              item: { name: item.name, slot: item.slot },
              // [FIX-B7] fallback '' si undefined
              image: item.name ? `url(${getItemUrl(item as SlotWithItem) ?? ''})` : undefined,
            }
          : null,
      canDrag,
    }),
    [inventoryType, item.slot, item.name, canDrag]
  );

  const [{ isOver }, drop] = useDrop<ClothingDragSource, void, { isOver: boolean }>(
    () => ({
      accept: DRAG_TYPE,
      collect: (m) => ({ isOver: m.isOver() }),
      drop: (source) => {
        // [FIX-C1] Drop depuis un ClothingSlot → demande de retrait au serveur
        if (source.fromClothingSlot) {
          dispatch(closeTooltip());

          const fromCategory = source.fromClothingSlot;
          const itemName     = source.item?.name;

          // On NE dispatch PAS removeClothing tout de suite.
          // Le serveur décide :
          //  - ok=true  → l'item a été ajouté dans l'inventaire (refreshSlots
          //               arrive séparément), on retire l'équipement en Redux
          //  - ok=false → inventaire plein, rien ne bouge (notif Lua)
          fetchNui<RemoveResponse>('removeClothing', {
            category: fromCategory,
            name:     itemName,
            toSlot:   item.slot, // indication pour le Lua, non garanti
          })
            .then((res) => {
              if (res?.ok) {
                dispatch(removeClothing(fromCategory));
              }
            })
            .catch(() => {
              // erreur réseau — ne rien changer
            });

          return;
        }

        dispatch(closeTooltip());

        switch (source.inventory) {
          case InventoryType.SHOP:     onBuy(source,   { inventory: inventoryType, item: { slot: item.slot } }); break;
          case InventoryType.CRAFTING: onCraft(source, { inventory: inventoryType, item: { slot: item.slot } }); break;
          default:                     onDrop(source,  { inventory: inventoryType, item: { slot: item.slot } }); break;
        }
      },
      canDrop: (source) => {
        // [FIX-C1] Toujours accepter les drags depuis un clothing slot
        //          (peu importe si le slot target est vide ou non) —
        //          le Lua choisit lui-même le slot d'inventaire libre.
        if (source.fromClothingSlot) {
          return inventoryType === InventoryType.PLAYER;
        }
        return (
          (source.item.slot !== item.slot || source.inventory !== inventoryType) &&
          inventoryType !== InventoryType.SHOP &&
          inventoryType !== InventoryType.CRAFTING
        );
      },
    }),
    [inventoryType, item.slot, dispatch]
  );

  // [FIX-B8] connectRef stable
  const connectRef = useCallback(
    (el: HTMLDivElement | null) => { drag(drop(el)); },
    [drag, drop]
  );

  const mergeRefs = useCallback(
    (el: HTMLDivElement | null) => {
      connectRef(el);
      if (typeof ref === 'function') ref(el);
      else if (ref) (ref as React.MutableRefObject<HTMLDivElement | null>).current = el;
    },
    [connectRef, ref]
  );

  const handleContext = useCallback((e: React.MouseEvent<HTMLDivElement>) => {
    e.preventDefault();
    if (inventoryType !== 'player' || !isSlotWithItem(item)) return;
    dispatch(openContextMenu({ item: item as SlotWithItem, coords: { x: e.clientX, y: e.clientY } }));
  }, [dispatch, inventoryType, item]);

  const handleClick = useCallback((e: React.MouseEvent<HTMLDivElement>) => {
    dispatch(closeTooltip());
    if (timerRef.current !== null) clearTimeout(timerRef.current);
    if (e.ctrlKey && isSlotWithItem(item) && inventoryType !== 'shop' && inventoryType !== 'crafting')
      onDrop({ item: item as SlotWithItem, inventory: inventoryType });
    else if (e.altKey && isSlotWithItem(item) && inventoryType === 'player')
      onUse(item);
  }, [dispatch, inventoryType, item]);

  const handleMouseEnter = useCallback(() => {
    if (!isSlotWithItem(item)) return;
    timerRef.current = window.setTimeout(() => {
      dispatch(openTooltip({ item: item as SlotWithItem, inventoryType }));
    }, 500);
  }, [dispatch, inventoryType, item]);

  const handleMouseLeave = useCallback(() => {
    dispatch(closeTooltip());
    if (timerRef.current !== null) { clearTimeout(timerRef.current); timerRef.current = null; }
  }, [dispatch]);

  const slotStyle = useMemo<React.CSSProperties>(() => {
    const imageUrl = item.name ? getItemUrl(item as SlotWithItem) : undefined;
    const backgroundImage = imageUrl ? `url(${imageUrl})` : 'none';
    return {
      filter:          !canPurchase || !canCraft ? 'brightness(70%) grayscale(100%)' : undefined,
      opacity:         isDragging ? 0.35 : 1.0,
      backgroundImage,
      border:          isOver ? '1px dashed rgba(59,130,246,0.5)' : '',
      backgroundColor: isOver ? 'rgba(37,99,235,0.08)' : '',
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isDragging, isOver, canPurchase, canCraft, item.name]);

  const hasItem = isSlotWithItem(item);

  return (
    <div ref={mergeRefs} onContextMenu={handleContext} onClick={handleClick} className="inventory-slot" style={slotStyle}>
      {hasItem && (
        <div className="item-slot-wrapper" onMouseEnter={handleMouseEnter} onMouseLeave={handleMouseLeave}>
          <div className={inventoryType === 'player' && item.slot <= 5 ? 'item-hotslot-header-wrapper' : 'item-slot-header-wrapper'}>
            {inventoryType === 'player' && item.slot <= 5 && <div className="inventory-slot-number">{item.slot}</div>}
            <div className="item-slot-info-wrapper">
              {(item as SlotWithItem).weight > 0 && (
                <p>
                  {(item as SlotWithItem).weight >= 1000
                    ? `${((item as SlotWithItem).weight / 1000).toLocaleString('en-us', { minimumFractionDigits: 2 })}kg `
                    : `${(item as SlotWithItem).weight.toLocaleString('en-us', { minimumFractionDigits: 0 })}g `}
                </p>
              )}
              {(item as SlotWithItem).count ? <p>{(item as SlotWithItem).count!.toLocaleString('en-us')}x</p> : null}
            </div>
          </div>
          <div>
            {inventoryType !== 'shop' && (item as SlotWithItem).durability !== undefined && (
              <WeightBar percent={(item as SlotWithItem).durability!} durability />
            )}
            {inventoryType === 'shop' && <ShopPrice item={item as SlotWithItem} />}
            <div className="inventory-slot-label-box">
              <div className="inventory-slot-label-text">
                {item.metadata?.label ? (item.metadata.label as string) : Items[item.name!]?.label ?? item.name}
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default React.memo(React.forwardRef(InventorySlot));