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
  category:  ClothingCategory;
  label:     string;
  icon:      string;
  accepts:   ClothingCategory[];
  item?:     EquippedClothingItem | null;
}

const ClothingSlot: React.FC<Props> = ({ category, label, icon, accepts, item }) => {
  const dispatch = useAppDispatch();
  const selected = useAppSelector(selectSelectedSlot);

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
        // Uniquement depuis l'inventaire joueur
        if (source.inventory !== InventoryType.PLAYER) return false;

        const itemName = source.item?.name ?? '';
        const itemData = Items[itemName];

        return canDropInSlot(
          itemName,
          itemData?.category,
          accepts,
          itemData?.clothingSlot,
        );
      },
      drop: (source) => {
        if (!source.item) return;

        const itemName  = source.item.name ?? '';
        const itemData  = Items[itemName];
        const itemType  = getClothingItemType(itemName);
        const itemLabel = itemData?.label ?? itemName;

        fetchNui('equipClothing', {
          slot:     source.item.slot,
          category,
          itemType,
        });

        dispatch(equipClothing({
          category,
          item: { name: itemName, label: itemLabel, itemType },
        }));
        dispatch(closeTooltip());
      },
    }),
    [category, accepts],
  );

  const handleClick = () => {
    dispatch(setSelectedSlot(isSelected ? null : category));
  };

  const handleRightClick = (e: React.MouseEvent) => {
    e.preventDefault();
    if (!item) return;
    fetchNui('removeClothing', { category, itemType: item.itemType });
    dispatch(removeClothing(category));
  };

  const getBorder = (): string => {
    if (isOver && canDrop)   return '1px dashed rgba(255,255,255,0.6)';
    if (isOver && !canDrop)  return '1px dashed rgba(231,76,60,0.6)';
    if (isSelected)          return '1px solid rgba(59,130,246,0.8)';
    if (isOutfit)            return '1px solid rgba(167,139,250,0.6)';
    if (isEquipped)          return '1px solid rgba(37,99,235,0.45)';
    return '';
  };

  return (
    <div
      ref={drop}
      className={[
        'inventory-slot',
        'clothing-slot',
        isSelected ? 'clothing-slot--selected' : '',
        isEquipped ? 'clothing-slot--equipped'  : '',
        isOutfit   ? 'clothing-slot--outfit'    : '',
        isOver && !canDrop ? 'clothing-slot--rejected' : '',
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
        backgroundSize:     '70%',
        backgroundPosition: 'center',
        backgroundRepeat:   'no-repeat',
        border:             getBorder(),
        transition:         'transform 120ms ease, border-color 120ms ease, background-color 120ms ease',
      }}
    >
      {/* Slot vide */}
      {!item && (
        <>
          <i className={`ti ${icon} clothing-slot__icon`} aria-hidden="true" />
          <span className="clothing-slot__label">
            <div className="inventory-slot-label-box">
              <div className="inventory-slot-label-text">{label}</div>
            </div>
          </span>
        </>
      )}

      {/* Slot équipé */}
      {item && (
        <div className="item-slot-wrapper">
          {isOutfit
            ? <div className="clothing-slot__outfit-badge" title="Tenue complète" />
            : <div className="clothing-slot__badge" />
          }
          <div className="inventory-slot-label-box">
            <div className="inventory-slot-label-text">{item.label}</div>
          </div>
        </div>
      )}
    </div>
  );
};

export default React.memo(ClothingSlot);