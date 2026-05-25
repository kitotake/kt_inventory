// components/inventory/PlayerPreview.tsx
import React from 'react';
import { useAppSelector } from '../../store';
import { selectEquipped } from '../../store/clothing';

const PlayerPreview: React.FC = () => {
  const equipped = useAppSelector(selectEquipped);

  const equippedEntries = Object.entries(equipped).filter(
    ([, val]) => val !== null && val !== undefined
  );

  return (
    <div className="player-preview">
    
    </div>
  );
};

export default PlayerPreview;
