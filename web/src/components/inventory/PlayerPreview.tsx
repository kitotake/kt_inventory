// components/inventory/PlayerPreview.tsx
// Preview ped GTA — zone transparente sur laquelle GTA rend la caméra scriptée
// Contrôles : drag horizontal = rotation ped, drag vertical = pan cam, molette = zoom

import React, { useEffect, useRef, useState, useCallback } from 'react';
import { fetchNui } from '../../utils/fetchNui';
import useNuiEvent from '../../hooks/useNuiEvent';

interface DragState {
  active: boolean;
  startX: number;
  startY: number;
  lastX: number;
  lastY: number;
}

const PlayerPreview: React.FC = () => {
  const containerRef   = useRef<HTMLDivElement>(null);
  const [pedReady, setPedReady]   = useState(false);
  const [rotating, setRotating]   = useState(false);
  const [zoomFace, setZoomFace]   = useState(false);
  const [showHint, setShowHint]   = useState(false);
  const dragRef = useRef<DragState>({
    active: false,
    startX: 0,
    startY: 0,
    lastX: 0,
    lastY: 0,
  });
  const hintTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Signaler au Lua de créer le ped + caméra dédiée
  useEffect(() => {
    fetchNui('pedPreviewInit', {});

    return () => {
      fetchNui('pedPreviewDestroy', {});
      setPedReady(false);
      setZoomFace(false);
    };
  }, []);

  // Le Lua signale que tout est prêt
  useNuiEvent('pedPreviewReady', () => {
    setPedReady(true);
    // Afficher le hint brièvement
    setShowHint(true);
    hintTimerRef.current = setTimeout(() => setShowHint(false), 3500);
  });

  // Nettoyage timer hint
  useEffect(() => {
    return () => {
      if (hintTimerRef.current) clearTimeout(hintTimerRef.current);
    };
  }, []);

  // ── Gestion drag (rotation + pan vertical) ─────────────────────────────

  const handlePointerDown = useCallback((e: React.PointerEvent) => {
    e.currentTarget.setPointerCapture(e.pointerId);
    dragRef.current = {
      active: true,
      startX: e.clientX,
      startY: e.clientY,
      lastX:  e.clientX,
      lastY:  e.clientY,
    };
    setRotating(true);
  }, []);

  const handlePointerMove = useCallback((e: React.PointerEvent) => {
    if (!dragRef.current.active) return;

    const deltaX = e.clientX - dragRef.current.lastX;
    const deltaY = e.clientY - dragRef.current.lastY;

    dragRef.current.lastX = e.clientX;
    dragRef.current.lastY = e.clientY;

    // Rotation horizontale → ped heading
    if (Math.abs(deltaX) > 0.5) {
      fetchNui('pedPreviewRotate', { delta: deltaX });
    }
    // Pan vertical → caméra pitch
    if (Math.abs(deltaY) > 0.5) {
      fetchNui('pedPreviewRotateVertical', { deltaY });
    }
  }, []);

  const handlePointerUp = useCallback(() => {
    dragRef.current.active = false;
    setRotating(false);
  }, []);

  // ── Zoom molette ────────────────────────────────────────────────────────

  const handleWheel = useCallback((e: React.WheelEvent) => {
    e.preventDefault();
    const delta = e.deltaY > 0 ? 1 : -1;
    fetchNui('pedPreviewZoom', { delta });
  }, []);

  // ── Double-clic : bascule zoom visage / corps ───────────────────────────

  const handleDoubleClick = useCallback(() => {
    const newZoom = !zoomFace;
    setZoomFace(newZoom);
    fetchNui('pedPreviewZoom', { face: newZoom });
  }, [zoomFace]);

  // ── Reset caméra (clic droit) ───────────────────────────────────────────

  const handleContextMenu = useCallback((e: React.MouseEvent) => {
    e.preventDefault();
    setZoomFace(false);
    fetchNui('pedPreviewResetCam', {});
  }, []);

  return (
    <div
      ref={containerRef}
      className={[
        'player-preview',
        pedReady  ? 'player-preview--ready'    : '',
        rotating  ? 'player-preview--rotating' : '',
        zoomFace  ? 'player-preview--face-zoom': '',
      ].filter(Boolean).join(' ')}
      onPointerDown={handlePointerDown}
      onPointerMove={handlePointerMove}
      onPointerUp={handlePointerUp}
      onPointerLeave={handlePointerUp}
      onWheel={handleWheel}
      onDoubleClick={handleDoubleClick}
      onContextMenu={handleContextMenu}
    >
      {/* Zone transparente — GTA rend la caméra scriptée ici */}
      <div className="player-preview__viewport" />

      {/* Vignettage CSS pour fondre les bords et intégrer le ped */}
      <div className="player-preview__vignette" aria-hidden="true" />

      {/* Reflet de sol subtil */}
      <div className="player-preview__floor-reflection" aria-hidden="true" />

      {/* Spinner de chargement */}
      {!pedReady && (
        <div className="player-preview__loading" aria-label="Chargement du personnage">
          <div className="player-preview__spinner">
            <svg viewBox="0 0 50 50" xmlns="http://www.w3.org/2000/svg">
              <circle
                cx="25" cy="25" r="20"
                fill="none"
                stroke="rgba(59,130,246,0.3)"
                strokeWidth="3"
              />
              <circle
                cx="25" cy="25" r="20"
                fill="none"
                stroke="rgba(59,130,246,0.9)"
                strokeWidth="3"
                strokeLinecap="round"
                strokeDasharray="30 95"
                className="player-preview__spinner-arc"
              />
            </svg>
          </div>
          <span className="player-preview__loading-text">Chargement…</span>
        </div>
      )}

      {/* Hints de contrôles */}
      {pedReady && showHint && (
        <div className="player-preview__hints" aria-live="polite">
          <span className="player-preview__hint-item">
            <kbd>↔</kbd> Tourner
          </span>
          <span className="player-preview__hint-sep">·</span>
          <span className="player-preview__hint-item">
            <kbd>↕</kbd> Incliner
          </span>
          <span className="player-preview__hint-sep">·</span>
          <span className="player-preview__hint-item">
            <kbd>⊙</kbd> Zoom
          </span>
          <span className="player-preview__hint-sep">·</span>
          <span className="player-preview__hint-item">
            <kbd>2×</kbd> Visage
          </span>
        </div>
      )}

      {/* Indicateur de zoom visage actif */}
      {pedReady && zoomFace && (
        <div className="player-preview__zoom-badge" aria-label="Mode zoom visage">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <circle cx="11" cy="11" r="8" />
            <path d="m21 21-4.35-4.35" />
          </svg>
          <span>VISAGE</span>
        </div>
      )}

      {/* Curseur de rotation visible */}
      {pedReady && (
        <div className="player-preview__cursor-hint" aria-hidden="true">
          {rotating ? '⊕' : '↻'}
        </div>
      )}
    </div>
  );
};

export default PlayerPreview;
