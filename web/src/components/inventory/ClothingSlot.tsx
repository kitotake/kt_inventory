// components/inventory/ClothingSlot.tsx
import React from 'react';
import { useDrop } from 'react-dnd';
import { useAppDispatch, useAppSelector } from '../../store';
import {
  ClothingCategory,
  EquippedClothingItem,
  canDropInSlot,
  getClothingItemType,
} from '../../typings/clothing';
import {
  selectSelectedSlot,
  setSelectedSlot,
  equipClothing,
  removeClothing,
} from '../../store/clothing';
import { fetchNui } from '../../utils/fetchNui';
import { DragSource, InventoryType } from '../../typings';
import { closeTooltip, openTooltip } from '../../store/tooltip';
import { getItemUrl } from '../../helpers';
import { Items } from '../../store/items';

interface Props {
  category: ClothingCategory;
  label:    string;
  icon:     string;
  accepts:  ClothingCategory[];
  item?:    EquippedClothingItem | null;
}

const ClothingSlot: React.FC<Props> = ({ category, label, icon, accepts, item }) => {
  const dispatch   = useAppDispatch();
  const selected   = useAppSelector(selectSelectedSlot);
  const isSelected = selected === category;
  const isEquipped = Boolean(item);
  const isOutfit   = isEquipped && item?.itemType === 'clothing_tenu';

  const [{ isOver, canDrop }, drop] = useDrop<DragSource, void, { isOver: boolean; canDrop: boolean }>(
    () => ({
      accept: 'SLOT',
      collect: (monitor) => ({
        isOver:  monitor.isOver(),
        canDrop: monitor.canDrop(),
      }),
      canDrop: (source) => {
        if (source.inventory !== InventoryType.PLAYER) return false;
        const itemName = source.item?.name ?? '';
        const itemData = Items[itemName];
        return canDropInSlot(itemName, itemData?.category, accepts, itemData?.clothingSlot);
      },
      drop: (source) => {
        if (!source.item) return;
        const itemName  = source.item.name ?? '';
        const itemData  = Items[itemName];
        const itemType  = getClothingItemType(itemName);
        const itemLabel = itemData?.label ?? itemName;

        fetchNui('equipClothing', { slot: source.item.slot, category, itemType });
        dispatch(equipClothing({ category, item: { name: itemName, label: itemLabel, itemType } }));
        dispatch(closeTooltip());
      },
    }),
    [category, accepts],
  );

  const handleClick = () => {
    const next = isSelected ? null : category;
    dispatch(setSelectedSlot(next));
    // Zoom caméra vers la zone anatomique correspondante
    if (next) {
      fetchNui('pedPreviewZoomCategory', { category: next });
    } else {
      fetchNui('pedPreviewResetCam', {});
    }
  };

  const handleRightClick = (e: React.MouseEvent) => {
    e.preventDefault();
    if (!item) return;
    fetchNui('removeClothing', { category, itemType: item.itemType });
    dispatch(removeClothing(category));
  };

  // Calcul de la bordure selon l'état
  const getBorder = (): string => {
    if (isOver && canDrop)  return '1px dashed rgba(255,255,255,0.6)';
    if (isOver && !canDrop) return '1px dashed rgba(231,76,60,0.6)';
    if (isSelected)         return '1px solid rgba(59,130,246,0.9)';
    if (isOutfit)           return '1px solid rgba(167,139,250,0.6)';
    if (isEquipped)         return '1px solid rgba(37,99,235,0.5)';
    return '';
  };

  const getBackground = (): string => {
    if (isOver && canDrop)  return 'rgba(59,130,246,0.12)';
    if (isOver && !canDrop) return 'rgba(231,76,60,0.08)';
    if (isSelected)         return 'rgba(37,99,235,0.15)';
    if (isOutfit)           return 'rgba(109,40,217,0.08)';
    return '';
  };

  return (
    <div
      ref={drop}
      className={[
        'inventory-slot',
        'clothing-slot',
        isSelected ? 'clothing-slot--selected'  : '',
        isEquipped ? 'clothing-slot--equipped'   : '',
        isOutfit   ? 'clothing-slot--outfit'     : '',
        isOver && !canDrop ? 'clothing-slot--rejected' : '',
        isOver && canDrop  ? 'clothing-slot--accept'   : '',
      ].filter(Boolean).join(' ')}
      onClick={handleClick}
      onContextMenu={handleRightClick}
      onMouseEnter={() => {
        if (!item) return;
        dispatch(openTooltip({
          item: {
            slot: 0, name: item.name, count: 1, weight: 0,
            metadata: {
              label: item.label,
              description: item.itemType === 'clothing_tenu'
                ? 'Tenue complète — clic droit pour retirer'
                : 'Clic droit pour retirer',
            },
          } as any,
          inventoryType: 'player',
        }));
      }}
      onMouseLeave={() => dispatch(closeTooltip())}
      style={{
        backgroundImage:    item ? `url(${getItemUrl(item.name)})` : 'none',
        backgroundSize:     '62%',
        backgroundPosition: 'center 40%',
        backgroundRepeat:   'no-repeat',
        border:             getBorder(),
        backgroundColor:    getBackground(),
        transition:         'transform 120ms ease, border-color 120ms ease, background-color 120ms ease, box-shadow 120ms ease',
        boxShadow:          isSelected ? '0 0 12px rgba(59,130,246,0.35), inset 0 0 8px rgba(59,130,246,0.1)' :
                            isEquipped ? '0 0 6px rgba(37,99,235,0.2)' : 'none',
      }}
    >
      {/* Slot vide */}
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

      {/* Slot équipé */}
      {item && (
        <div className="item-slot-wrapper">
          {/* Badge tenue complète */}
          {isOutfit
            ? <div className="clothing-slot__outfit-badge" title="Tenue complète" />
            : <div className="clothing-slot__badge" />
          }
          {/* Overlay de sélection */}
          {isSelected && (
            <div className="clothing-slot__selected-overlay" aria-hidden="true" />
          )}
          <div className="inventory-slot-label-box">
            <div className="inventory-slot-label-text">{item.label}</div>
          </div>
        </div>
      )}

      {/* Indicateur drop accepté */}
      {isOver && canDrop && (
        <div className="clothing-slot__drop-indicator" aria-hidden="true">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
            <polyline points="20 6 9 17 4 12" />
          </svg>
        </div>
      )}

      {/* Indicateur drop refusé */}
      {isOver && !canDrop && (
        <div className="clothing-slot__reject-indicator" aria-hidden="true">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
            <line x1="18" y1="6" x2="6" y2="18" />
            <line x1="6" y1="6" x2="18" y2="18" />
          </svg>
        </div>
      )}
    </div>
  );
};

export default React.memo(ClothingSlot);
