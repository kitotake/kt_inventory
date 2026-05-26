// components/inventory/PlayerPreview.tsx
import React, { useEffect, useRef, useState } from 'react';
import { useAppSelector } from '../../store';
import { selectEquipped } from '../../store/clothing';
import { fetchNui } from '../../utils/fetchNui';
import useNuiEvent from '../../hooks/useNuiEvent';

const PlayerPreview: React.FC = () => {
  const equipped      = useAppSelector(selectEquipped);
  const containerRef  = useRef<HTMLDivElement>(null);
  const [pedReady, setPedReady] = useState(false);

  // Informe le client Lua que la preview est montée
  // et lui donne les dimensions pour positionner la caméra scaleform
  useEffect(() => {
    const container = containerRef.current;
    if (!container) return;

    const rect = container.getBoundingClientRect();

    fetchNui('pedPreviewInit', {
      x:      rect.left,
      y:       rect.top,
      width:   rect.width,
      height:  rect.height,
    });

    return () => {
      fetchNui('pedPreviewDestroy', {});
    };
  }, []);

  // Le Lua signale que la caméra est prête
  useNuiEvent('pedPreviewReady', () => {
    setPedReady(true);
  });

  // Rotate ped on mouse drag
  const isDragging  = useRef(false);
  const lastX       = useRef(0);

  const handleMouseDown = (e: React.MouseEvent) => {
    isDragging.current = true;
    lastX.current      = e.clientX;
  };

  const handleMouseMove = (e: React.MouseEvent) => {
    if (!isDragging.current) return;
    const delta = e.clientX - lastX.current;
    lastX.current = e.clientX;
    fetchNui('pedPreviewRotate', { delta });
  };

  const handleMouseUp = () => {
    isDragging.current = false;
  };

  const equippedEntries = Object.entries(equipped).filter(
    ([, val]) => val !== null && val !== undefined
  );

  return (
    <div
      ref={containerRef}
      className="player-preview"
      onMouseDown={handleMouseDown}
      onMouseMove={handleMouseMove}
      onMouseUp={handleMouseUp}
      onMouseLeave={handleMouseUp}
      style={{ cursor: isDragging.current ? 'grabbing' : 'grab' }}
    >
      {/* Zone de rendu de la caméra scaleform (transparente) */}
      <div className="player-preview__camera" />

      {/* Overlay de chargement */}
      {!pedReady && (
        <div
          style={{
            position:   'absolute',
            inset:       0,
            display:    'flex',
            alignItems: 'center',
            justifyContent: 'center',
            color:      'rgba(255,255,255,0.3)',
            fontSize:   '1.2vh',
            pointerEvents: 'none',
          }}
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="32"
            height="32"
            viewBox="0 0 24 24"
            strokeWidth="1.5"
            stroke="rgba(255,255,255,0.3)"
            fill="none"
            strokeLinecap="round"
            strokeLinejoin="round"
          >
            <path stroke="none" d="M0 0h24v24H0z" fill="none"/>
            <circle cx="12" cy="7" r="4"/>
            <path d="M5.5 21v-2a7 7 0 0 1 14 0v2"/>
          </svg>
        </div>
      )}
      </div>
  );
};

export default PlayerPreview;
