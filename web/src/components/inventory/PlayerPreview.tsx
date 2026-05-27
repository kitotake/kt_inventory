// components/inventory/PlayerPreview.tsx
// Le rendu du ped est fait côté Lua via CreateCam + RenderScriptCams.
// Ce composant est un conteneur transparent qui reçoit ce rendu GTA.

import React, { useEffect, useRef, useState } from 'react';
import { fetchNui } from '../../utils/fetchNui';
import useNuiEvent from '../../hooks/useNuiEvent';

const PlayerPreview: React.FC = () => {
  const containerRef  = useRef<HTMLDivElement>(null);
  const [pedReady, setPedReady]   = useState(false);
  const [rotating, setRotating]   = useState(false);
  const lastXRef = useRef(0);

  // Signaler au Lua de créer le ped + caméra
  useEffect(() => {
    fetchNui('pedPreviewInit', {});

    return () => {
      fetchNui('pedPreviewDestroy', {});
      setPedReady(false);
    };
  }, []);

  // Le Lua indique que tout est prêt
  useNuiEvent('pedPreviewReady', () => {
    setPedReady(true);
  });

  // ── Rotation du ped via drag ─────────────────────────────────────────────

  const handleMouseDown = (e: React.MouseEvent) => {
    setRotating(true);
    lastXRef.current = e.clientX;
  };

  const handleMouseMove = (e: React.MouseEvent) => {
    if (!rotating) return;
    const delta = e.clientX - lastXRef.current;
    lastXRef.current = e.clientX;
    if (Math.abs(delta) > 0) {
      fetchNui('pedPreviewRotate', { delta });
    }
  };

  const handleMouseUp = () => setRotating(false);

  return (
    <div
      ref={containerRef}
      className="player-preview"
      onMouseDown={handleMouseDown}
      onMouseMove={handleMouseMove}
      onMouseUp={handleMouseUp}
      onMouseLeave={handleMouseUp}
      style={{ cursor: rotating ? 'grabbing' : 'grab' }}
    >
      {/* Zone transparente — GTA rend la caméra ici via RenderScriptCams */}
      <div className="player-preview__camera" />

      {/* Spinner de chargement tant que le ped n'est pas prêt */}
      {!pedReady && (
        <div className="player-preview__loading">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="28"
            height="28"
            viewBox="0 0 24 24"
            strokeWidth="1.5"
            stroke="rgba(255,255,255,0.25)"
            fill="none"
            strokeLinecap="round"
            strokeLinejoin="round"
          >
            <path stroke="none" d="M0 0h24v24H0z" fill="none" />
            <circle cx="12" cy="7" r="4" />
            <path d="M5.5 21v-2a7 7 0 0 1 14 0v2" />
          </svg>
        </div>
      )}

      {/* Label d'aide rotation */}
      {pedReady && (
        <div className="player-preview__hint">
          ↔ Tourner
        </div>
      )}
    </div>
  );
};

export default PlayerPreview;