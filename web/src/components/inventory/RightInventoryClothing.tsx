// components/inventory/RightInventoryClothing.tsx
import React from 'react';
import { useAppDispatch, useAppSelector } from '../../store';
import { selectEquipped, selectSelectedSlot, setSelectedSlot, removeClothing } from '../../store/clothing';
import { RIGHT_CLOTHING_SLOTS, ClothingCategory } from '../../typings/clothing';
import { fetchNui } from '../../utils/fetchNui';

const RightInventoryClothing: React.FC = () => {
  const dispatch = useAppDispatch();
  const equipped = useAppSelector(selectEquipped);
  const selected = useAppSelector(selectSelectedSlot);

  const handleClick = (category: ClothingCategory) => {
    dispatch(setSelectedSlot(selected === category ? null : category));
  };

  const handleRightClick = (e: React.MouseEvent, category: ClothingCategory) => {
    e.preventDefault();
    if (!equipped[category]) return;
    dispatch(removeClothing(category));
    fetchNui('removeClothing', { category });
  };

  return (
    <div className="clothing-panel clothing-panel--right">
      <div className="clothing-panel__title">Vêtements</div>
      <div className="clothing-panel__slots">
        {RIGHT_CLOTHING_SLOTS.map((slot) => {
          const item       = equipped[slot.category];
          const isSelected = selected === slot.category;
          const isEquipped = !!item;

          return (
            <div
              key={slot.category}
              className={[
                'clothing-slot',
                isSelected ? 'clothing-slot--selected' : '',
                isEquipped ? 'clothing-slot--equipped' : '',
              ].join(' ')}
              onClick={() => handleClick(slot.category)}
              onContextMenu={(e) => handleRightClick(e, slot.category)}
              title={isEquipped ? `${item!.label} — clic droit pour retirer` : slot.label}
            >
              <i className={`ti ${slot.icon} clothing-slot__icon`} aria-hidden="true" />
              <span className="clothing-slot__label">
                {isEquipped ? item!.label : slot.label}
              </span>
              {isEquipped && <span className="clothing-slot__badge" aria-label="Équipé" />}
            </div>
          );
        })}
      </div>
    </div>
  );
};

export default RightInventoryClothing;
