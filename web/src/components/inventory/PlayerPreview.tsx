// components/inventory/PlayerPreview.tsx
import React from 'react';
import { useAppSelector } from '../../store';
import { selectEquipped } from '../../store/clothing';

const PlayerPreview: React.FC = () => {
  const equipped = useAppSelector(selectEquipped);

  return (
    <div className="player-preview">
      <div className="player-preview__label">Aperçu</div>
      <div className="player-preview__figure">
        <svg
          viewBox="0 0 80 180"
          xmlns="http://www.w3.org/2000/svg"
          className="player-preview__svg"
          aria-label="Silhouette du personnage"
        >
          {/* Tête */}
          <ellipse
            cx="40" cy="22" rx="17" ry="20"
            className="player-preview__head"
          />
          {/* Corps — couleur selon veste équipée */}
          <rect
            x="18" y="44" width="44" height="50" rx="6"
            className={equipped['top'] ? 'player-preview__body player-preview__body--equipped' : 'player-preview__body'}
          />
          {/* Bras gauche */}
          <rect x="4"  y="47" width="13" height="36" rx="5"
            className={equipped['top'] ? 'player-preview__arm player-preview__arm--equipped' : 'player-preview__arm'}
          />
          {/* Bras droit */}
          <rect x="63" y="47" width="13" height="36" rx="5"
            className={equipped['top'] ? 'player-preview__arm player-preview__arm--equipped' : 'player-preview__arm'}
          />
          {/* Jambe gauche */}
          <rect
            x="19" y="96" width="17" height="46" rx="5"
            className={equipped['pants'] ? 'player-preview__leg player-preview__leg--equipped' : 'player-preview__leg'}
          />
          {/* Jambe droite */}
          <rect
            x="44" y="96" width="17" height="46" rx="5"
            className={equipped['pants'] ? 'player-preview__leg player-preview__leg--equipped' : 'player-preview__leg'}
          />
          {/* Chaussures */}
          <rect
            x="16" y="137" width="22" height="10" rx="4"
            className={equipped['shoes'] ? 'player-preview__shoe player-preview__shoe--equipped' : 'player-preview__shoe'}
          />
          <rect
            x="42" y="137" width="22" height="10" rx="4"
            className={equipped['shoes'] ? 'player-preview__shoe player-preview__shoe--equipped' : 'player-preview__shoe'}
          />
          {/* Lunettes — affichées si équipées */}
          {equipped['glasses'] && (
            <>
              <ellipse cx="32" cy="17" rx="9" ry="6" fill="none" stroke="#60a5fa" strokeWidth="1.5" opacity="0.9"/>
              <ellipse cx="48" cy="17" rx="9" ry="6" fill="none" stroke="#60a5fa" strokeWidth="1.5" opacity="0.9"/>
              <line x1="41" y1="17" x2="39" y2="17" stroke="#60a5fa" strokeWidth="1.2"/>
            </>
          )}
          {/* Chapeau — affiché si équipé */}
          {equipped['hat'] && (
            <rect x="22" y="1" width="36" height="10" rx="4" fill="#1e3a5f" stroke="#3b82f6" strokeWidth="1"/>
          )}
        </svg>
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
