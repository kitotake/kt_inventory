// components/inventory/InventorySlot.tsx
// Correction v12 :
//   ✓ Suppression de dispatch(closeTooltip()) (tooltip retiré du projet)
//   ✓ Retrait de l'import closeTooltip, openTooltip
//   ✓ Retrait de handleMouseEnter, handleMouseLeave, timerRef (devenus inutiles)
//   ✓ Thème shop/crafting : classes inventory-slot--shop / --crafting / --locked
//   ✓ LockOverlay minimal (cadenas seul) — le détail (temps, ingrédients
//     manquants, raison d'indisponibilité) est désormais dans InventoryContext
//   ✓ Clic sur un slot shop/crafting (avec item) → ouvre InventoryContext
//     pour afficher le détail, au lieu d'un simple onClick onUse/onDrop
//   ✓ ShopPrice : variante "unavailable" (grisé + barré) quand !canPurchase

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
import { checkCraftItem, checkPurchaseItem, getItemUrl, isSlotWithItem } from '../../helpers';
import { openContextMenu }       from '../../store/contextMenu';
import { removeClothing }        from '../../store/clothing';
import { fetchNui }              from '../../utils/fetchNui';
import { isEnvBrowser }          from '../../utils/misc';
import { refreshSlots }          from '../../store/inventory';
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
const ShopPrice: React.FC<{ item: SlotWithItem; unavailable?: boolean }> = React.memo(({ item, unavailable }) => {
  if (!item.price || item.price === 0) return null;
  const isCustom = item.currency && item.currency !== 'money' && item.currency !== 'black_money';
  if (isCustom) {
    return (
      <div className={`item-slot-currency-wrapper${unavailable ? ' item-slot-currency-wrapper--unavailable' : ''}`}>
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
    <div
      className={`item-slot-price-wrapper${unavailable ? ' item-slot-price-wrapper--unavailable' : ''}`}
      style={!unavailable ? { color: !item.currency || item.currency === 'money' ? '#22c55e' : '#ef4444' } : undefined}
    >
      <p>{item.price.toLocaleString('en-us')} {Locale.$ ?? '$'}</p>
    </div>
  );
});
ShopPrice.displayName = 'ShopPrice';

// ── LockOverlay — cadenas minimal (détail déporté vers InventoryContext) ─────
const LockOverlay: React.FC = React.memo(() => (
  <div className="inventory-slot__lock-overlay" aria-hidden="true">
    
  </div>
));
LockOverlay.displayName = 'LockOverlay';

// ── CraftTimeIcon — petit indicateur discret (coin) si craftTime défini ──────
const CraftTimeIcon: React.FC = React.memo(() => (
  <div className="inventory-slot__craft-time-icon" aria-hidden="true" title="Voir le détail">
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="12" r="9" />
      <polyline points="12 7 12 12 15 15" />
    </svg>
  </div>
));
CraftTimeIcon.displayName = 'CraftTimeIcon';

// ── InventorySlot ─────────────────────────────────────────────────────────────
const InventorySlot: React.ForwardRefRenderFunction<HTMLDivElement, SlotProps> = (
  { item, inventoryId, inventoryType, inventoryGroups }, ref
) => {
  const dispatch = useAppDispatch();

  // [FIX-B6] inventoryGroups sérialisé pour éviter les re-créations de canDrag
  // eslint-disable-next-line react-hooks/exhaustive-deps
  const groupsKey = useMemo(() => JSON.stringify(inventoryGroups), [inventoryGroups]);

  // Vérifications shop / craft — utilisées uniquement pour le verrouillage visuel.
  // Le détail (raison, ingrédients manquants, temps) est calculé dans InventoryContext.
  const canPurchase = useMemo(
    () => checkPurchaseItem(item, { type: inventoryType, groups: inventoryGroups }).ok,
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [item.slot, item.name, (item as SlotWithItem).count, (item as SlotWithItem).price, (item as SlotWithItem).currency, (item as SlotWithItem).grade, inventoryType, groupsKey]
  );

  const canCraft = useMemo(
    () => checkCraftItem(item, inventoryType).ok,
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [item.slot, item.name, JSON.stringify((item as SlotWithItem).ingredients), inventoryType]
  );

  // [FIX-B9] Logique conditionnelle par type d'inventaire
  const canDrag = useCallback(
    () => {
      if (inventoryType === InventoryType.SHOP)     return canPurchase;
      if (inventoryType === InventoryType.CRAFTING) return canCraft;
      return true;
    },
    [inventoryType, canPurchase, canCraft]
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
          const fromCategory = source.fromClothingSlot;
          const itemName     = source.item?.name;

          // ── Mode browser (pnpm dev / debugData) ──────────────────────────
          // Aucun backend Lua disponible : fetchNui ne renverra jamais
          // { ok: true }. On applique donc le changement localement :
          //  1. retire l'item équipé du ClothingSlot (Redux clothing)
          //  2. place l'item dans le slot inventaire ciblé (Redux inventory)
          if (isEnvBrowser()) {
            if (!itemName) return;

            const itemData = Items[itemName];

            dispatch(removeClothing(fromCategory));
            dispatch(
              refreshSlots({
                items: {
                  item: {
                    slot:     item.slot,
                    name:     itemName,
                    count:    1,
                    weight:   itemData?.weight ?? 0,
                    metadata: { label: itemData?.label ?? itemName },
                  },
                  inventory: InventoryType.PLAYER,
                },
              })
            );
            return;
          }

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
    [inventoryType, item.slot, item.name, dispatch]
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

  // Clic droit : menu contextuel classique (inventaire joueur uniquement, comportement inchangé)
  const handleContext = useCallback((e: React.MouseEvent<HTMLDivElement>) => {
    e.preventDefault();
    if (inventoryType !== 'player' || !isSlotWithItem(item)) return;
    dispatch(openContextMenu({
      item: item as SlotWithItem,
      coords: { x: e.clientX, y: e.clientY },
      inventoryType,
      inventoryGroups,
    }));
  }, [dispatch, inventoryType, inventoryGroups, item]);

  // Clic gauche :
  //  - player : comportement existant (ctrl=drop, alt=use)
  //  - shop/crafting avec item : ouvre InventoryContext pour voir le détail
  //    (temps de craft, ingrédients manquants, raison d'indisponibilité)
  const handleClick = useCallback((e: React.MouseEvent<HTMLDivElement>) => {
    if (inventoryType === 'shop' || inventoryType === 'crafting') {
      if (!isSlotWithItem(item)) return;
      dispatch(openContextMenu({
        item: item as SlotWithItem,
        coords: { x: e.clientX, y: e.clientY },
        inventoryType,
        inventoryGroups,
      }));
      return;
    }

    if (e.ctrlKey && isSlotWithItem(item) && inventoryType !== 'shop' && inventoryType !== 'crafting')
      onDrop({ item: item as SlotWithItem, inventory: inventoryType });
    else if (e.altKey && isSlotWithItem(item) && inventoryType === 'player')
      onUse(item);
  }, [dispatch, inventoryType, inventoryGroups, item]);

  const slotStyle = useMemo<React.CSSProperties>(() => {
    const imageUrl = item.name ? getItemUrl(item as SlotWithItem) : undefined;
    const backgroundImage = imageUrl ? `url(${imageUrl})` : 'none';
    return {
      opacity:         isDragging ? 0.35 : 1.0,
      backgroundImage,
      border:          isOver ? '1px dashed rgba(59,130,246,0.5)' : '',
      backgroundColor: isOver ? 'rgba(37,99,235,0.08)' : '',
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isDragging, isOver, item.name]);

  const hasItem    = isSlotWithItem(item);
  const isShop     = inventoryType === InventoryType.SHOP;
  const isCrafting = inventoryType === InventoryType.CRAFTING;
  const isLocked   = hasItem && ((isShop && !canPurchase) || (isCrafting && !canCraft));
  const hasCraftTime = isCrafting && (item as SlotWithItem).craftTime !== undefined;

  const className = useMemo(() => [
    'inventory-slot',
    isShop     ? 'inventory-slot--shop'     : '',
    isCrafting ? 'inventory-slot--crafting' : '',
    isLocked   ? 'inventory-slot--locked'   : '',
    (isShop || isCrafting) && hasItem ? 'inventory-slot--clickable' : '',
  ].filter(Boolean).join(' '),
  [isShop, isCrafting, isLocked, hasItem]);

  return (
    <div ref={mergeRefs} onContextMenu={handleContext} onClick={handleClick} className={className} style={slotStyle}>
      {hasItem && (
        <div className="item-slot-wrapper">
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
            {isShop && <ShopPrice item={item as SlotWithItem} unavailable={!canPurchase} />}
            <div className="inventory-slot-label-box">
              <div className="inventory-slot-label-text">
                {item.metadata?.label ? (item.metadata.label as string) : Items[item.name!]?.label ?? item.name}
              </div>
            </div>
          </div>

          {/* Indicateur discret "a un temps de craft / détail dispo" */}
          {hasCraftTime && !isLocked && <CraftTimeIcon />}

          {/* Cadenas minimal — clic ouvre InventoryContext pour le détail */}
          {isLocked && <LockOverlay />}
        </div>
      )}
    </div>
  );
};

export default React.memo(React.forwardRef(InventorySlot));