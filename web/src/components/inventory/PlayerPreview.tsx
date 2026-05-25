// components/inventory/PlayerPreview.tsx
import React from 'react';
import { useAppSelector } from '../../store';
import { selectEquipped } from '../../store/clothing';

const PlayerPreview: React.FC = () => {
  const equipped = useAppSelector(selectEquipped);

  return (
    <div className="player-preview">
      <div className="player-preview__figure">
        {/* Placeholder pour la figure du joueur */}
      </div>
      {/* Indicateurs items équipés */}
      <div className="player-preview__tags">
        {Object.entries(equipped)
          .filter(([, val]) => val !== null && val !== undefined)
          .map(([cat, val]) => (
            <span key={cat} className="player-preview__tag">
              {(val as any).label}
            </span>
          ))}
      </div>
    </div>
  );
};

export default PlayerPreview;
