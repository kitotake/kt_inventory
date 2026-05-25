// components/inventory/ClothingSlot.tsx

import React from 'react';
import { useDrop } from 'react-dnd';
import { useAppDispatch, useAppSelector } from '../../store';

import {
  ClothingCategory,
  EquippedClothingItem,
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

interface Props {
  category: ClothingCategory;
  label: string;
  icon: string;
  item?: EquippedClothingItem | null;
}

const ClothingSlot: React.FC<Props> = ({ category, label, icon, item }) => {
  const dispatch = useAppDispatch();
  const selected = useAppSelector(selectSelectedSlot);

  const isSelected = selected === category;
  const isEquipped = !!item;

  const [{ isOver }, drop] = useDrop<DragSource, void, { isOver: boolean }>(
    () => ({
      accept: 'SLOT',
      collect: (monitor) => ({
        isOver: monitor.isOver(),
      }),
      canDrop: (source) => source.inventory === InventoryType.PLAYER,
      drop: (source) => {
        if (!source.item) return;

        fetchNui('equipClothing', {
          slot: source.item.slot,
          category,
        });

        dispatch(
          equipClothing({
            category,
            item: {
              name: source.item.name,
              label: source.item.name,
            },
          })
        );

        dispatch(closeTooltip());
      },
    }),
    [category]
  );

  const handleClick = () => {
    dispatch(setSelectedSlot(isSelected ? null : category));
  };

  const handleRightClick = (e: React.MouseEvent<HTMLDivElement>) => {
    e.preventDefault();
    if (!item) return;

    dispatch(removeClothing(category));
    fetchNui('removeClothing', { category });
  };

  return (
    <div
      ref={drop}
      className={[
        'inventory-slot',
        'clothing-slot',
        isSelected ? 'clothing-slot--selected' : '',
        isEquipped ? 'clothing-slot--equipped' : '',
      ]
        .filter(Boolean)
        .join(' ')}
      onClick={handleClick}
      onContextMenu={handleRightClick}
      onMouseEnter={() => {
        if (!item) return;
        dispatch(
          openTooltip({
            item: item as any,
            inventoryType: 'player',
          })
        );
      }}
      onMouseLeave={() => dispatch(closeTooltip())}
      style={{
        opacity: 1,
        border: isOver ? '1px dashed rgba(255,255,255,0.4)' : '',
        backgroundImage: item ? `url(${getItemUrl(item.name)})` : 'none',
        backgroundSize: '70%',
        backgroundPosition: 'center',
        backgroundRepeat: 'no-repeat',
      }}
    >
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

      {item && (
        <div className="item-slot-wrapper">
          <div className="inventory-slot-label-box">
            <div className="inventory-slot-label-text">{item.label}</div>
          </div>
        </div>
      )}
    </div>
  );
};

export default React.memo(ClothingSlot);
