import React from 'react';
import { useAppSelector } from '../../store';
import { ClothingSlotData } from '../../typings/clothing';
import { selectEquipped } from '../../store/clothing';
import ClothingSlot from './ClothingSlot';

interface Props {
  side?:  'left' | 'right';
  slots:  ClothingSlotData[];
}

const ClothingGrid: React.FC<Props> = ({ side = 'left', slots }) => {
  const equipped = useAppSelector(selectEquipped);

  return (
    <div className={`clothing-panel clothing-panel--${side}`}>
      <div className="clothing-panel__slots">
        {slots.map((slot) => (
          <ClothingSlot
            key={slot.category}
            category={slot.category}
            label={slot.label}
            icon={slot.icon}
            accepts={slot.accepts}
            item={equipped[slot.category]}
          />
        ))}
      </div>
    </div>
  );
};

export default ClothingGrid;