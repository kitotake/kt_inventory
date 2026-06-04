// components/inventory/ClothingSlot.tsx
// CORRECTIONS :
//   1. accepts[] stabilisé via useMemo sur acceptsKey → useDrop descriptor stable
//   2. Style complet via useMemo (pas d'objet inline recréé à chaque render)
//   3. tooltipItem mémoïsé
//   4. Tous les handlers via useCallback

import React, { useCallback, useMemo } from 'react';
import { useDrop }             from 'react-dnd';
import { useAppDispatch, useAppSelector } from '../../store';
import {
  ClothingCategory, EquippedClothingItem,
  canDropInSlot, getClothingItemType,
} from '../../typings/clothing';
import {
  selectSelectedSlot, setSelectedSlot,
  equipClothing, removeClothing,
} from '../../store/clothing';
import { fetchNui }            from '../../utils/fetchNui';
import { DragSource, InventoryType, SlotWithItem } from '../../typings';
import { closeTooltip, openTooltip } from '../../store/tooltip';
import { getItemUrl }          from '../../helpers';
import { Items }               from '../../store/items';

interface Props {
  category: ClothingCategory;
  label:    string;
  icon:     string;
  accepts:  ClothingCategory[];
  item?:    EquippedClothingItem | null;
}

const computeStyle = (p: {
  isOver: boolean; canDrop: boolean; isSelected: boolean;
  isOutfit: boolean; isEquipped: boolean; imageUrl?: string;
}): React.CSSProperties => {
  let border = '', bg = '', shadow = 'none';
  if (p.isOver && p.canDrop)   { border = '1px dashed rgba(255,255,255,0.6)'; bg = 'rgba(59,130,246,0.12)'; }
  else if (p.isOver)           { border = '1px dashed rgba(231,76,60,0.6)';  bg = 'rgba(231,76,60,0.08)'; }
  else if (p.isSelected)       { border = '1px solid rgba(59,130,246,0.9)';  bg = 'rgba(37,99,235,0.15)'; shadow = '0 0 12px rgba(59,130,246,0.35),inset 0 0 8px rgba(59,130,246,0.1)'; }
  else if (p.isOutfit)         { border = '1px solid rgba(167,139,250,0.6)'; bg = 'rgba(109,40,217,0.08)'; }
  else if (p.isEquipped)       { border = '1px solid rgba(37,99,235,0.5)';   shadow = '0 0 6px rgba(37,99,235,0.2)'; }
  return {
    backgroundImage: p.imageUrl ? `url(${p.imageUrl})` : 'none',
    backgroundSize: '62%', backgroundPosition: 'center 40%', backgroundRepeat: 'no-repeat',
    border, backgroundColor: bg, boxShadow: shadow,
    transition: 'transform 120ms ease, border-color 120ms ease, background-color 120ms ease, box-shadow 120ms ease',
  };
};

const ClothingSlot: React.FC<Props> = ({ category, label, icon, accepts, item }) => {
  const dispatch   = useAppDispatch();
  const selected   = useAppSelector(selectSelectedSlot);
  const isSelected = selected === category;
  const isEquipped = Boolean(item);
  const isOutfit   = isEquipped && item?.itemType === 'clothing_tenu';

  // Stabiliser accepts (tableau statique → clé string)
  const acceptsKey    = accepts.join(',');
  // eslint-disable-next-line react-hooks/exhaustive-deps
  const stableAccepts = useMemo(() => accepts, [acceptsKey]);

  const [{ isOver, canDrop }, drop] = useDrop<DragSource, void, { isOver: boolean; canDrop: boolean }>(
    () => ({
      accept: 'SLOT',
      collect: (m) => ({ isOver: m.isOver(), canDrop: m.canDrop() }),
      canDrop: (source) => {
        if (source.inventory !== InventoryType.PLAYER) return false;
        const name = source.item?.name ?? '';
        const d    = Items[name];
        return canDropInSlot(name, d?.category, stableAccepts, d?.clothingSlot);
      },
      drop: (source) => {
        if (!source.item) return;
        const name = source.item.name ?? '';
        const d    = Items[name];
        const type = getClothingItemType(name);
        fetchNui('equipClothing', { slot: source.item.slot, category, itemType: type });
        dispatch(equipClothing({ category, item: { name, label: d?.label ?? name, itemType: type } }));
        dispatch(closeTooltip());
      },
    }),
    [category, stableAccepts]
  );

  const imageUrl = useMemo(() => item ? getItemUrl(item.name) : undefined, [item?.name]); // eslint-disable-line react-hooks/exhaustive-deps
  const slotStyle = useMemo(
    () => computeStyle({ isOver, canDrop, isSelected, isOutfit, isEquipped, imageUrl }),
    [isOver, canDrop, isSelected, isOutfit, isEquipped, imageUrl]
  );

  const tooltipItem = useMemo((): SlotWithItem | null => {
    if (!item) return null;
    return {
      slot: 0, name: item.name, count: 1, weight: 0,
      metadata: {
        label: item.label,
        description: item.itemType === 'clothing_tenu' ? 'Tenue complète — clic droit pour retirer' : 'Clic droit pour retirer',
      },
    };
  }, [item]);

  const handleClick = useCallback(() => {
    const next = isSelected ? null : category;
    dispatch(setSelectedSlot(next));
    if (next) fetchNui('pedPreviewZoomCategory', { category: next });
    else      fetchNui('pedPreviewResetCam', {});
  }, [dispatch, isSelected, category]);

  const handleRightClick = useCallback((e: React.MouseEvent) => {
    e.preventDefault();
    if (!item) return;
    fetchNui('removeClothing', { category, itemType: item.itemType });
    dispatch(removeClothing(category));
  }, [dispatch, category, item]);

  const handleMouseEnter = useCallback(() => {
    if (!tooltipItem) return;
    dispatch(openTooltip({ item: tooltipItem, inventoryType: 'player' }));
  }, [dispatch, tooltipItem]);

  const handleMouseLeave = useCallback(() => dispatch(closeTooltip()), [dispatch]);

  const className = useMemo(() => [
    'inventory-slot', 'clothing-slot',
    isSelected         ? 'clothing-slot--selected'  : '',
    isEquipped         ? 'clothing-slot--equipped'   : '',
    isOutfit           ? 'clothing-slot--outfit'     : '',
    isOver && !canDrop ? 'clothing-slot--rejected'   : '',
    isOver && canDrop  ? 'clothing-slot--accept'     : '',
  ].filter(Boolean).join(' '), [isSelected, isEquipped, isOutfit, isOver, canDrop]);

  return (
    <div
      ref={drop} className={className} style={slotStyle}
      onClick={handleClick} onContextMenu={handleRightClick}
      onMouseEnter={handleMouseEnter} onMouseLeave={handleMouseLeave}
    >
      {!item && (
        <>
          <div className="clothing-slot__icon-wrapper" aria-hidden="true">
            <i className={`ti ${icon} clothing-slot__icon`} />
          </div>
          <div className="inventory-slot-label-box">
            <div className="inventory-slot-label-text">{label}</div>
          </div>
        </>
      )}
      {item && (
        <div className="item-slot-wrapper">
          {isOutfit ? <div className="clothing-slot__outfit-badge" /> : <div className="clothing-slot__badge" />}
          {isSelected && <div className="clothing-slot__selected-overlay" aria-hidden="true" />}
          <div className="inventory-slot-label-box">
            <div className="inventory-slot-label-text">{item.label}</div>
          </div>
        </div>
      )}
      {isOver && canDrop && (
        <div className="clothing-slot__drop-indicator" aria-hidden="true">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5"><polyline points="20 6 9 17 4 12" /></svg>
        </div>
      )}
      {isOver && !canDrop && (
        <div className="clothing-slot__reject-indicator" aria-hidden="true">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
            <line x1="18" y1="6" x2="6" y2="18" /><line x1="6" y1="6" x2="18" y2="18" />
          </svg>
        </div>
      )}
    </div>
  );
};

export default React.memo(ClothingSlot);
