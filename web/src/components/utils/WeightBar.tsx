// components/utils/WeightBar.tsx
// CORRECTIONS :
//   1. SVG rotate(230deg) → classe CSS .weight-circle__svg (pas inline)
//   2. DurabilityBar et WeightCircle séparés et mémoïsés
//   3. TOOLTIP_STYLE constant module-level (pas d'objet inline)
//   4. Stacking context CEF : SVG z-index 0, icône z-index 1

import React, { useMemo, useState } from 'react';

const TOOLTIP_STYLE: React.CSSProperties = {
  position: 'absolute', bottom: 'calc(100% + 6px)', left: '50%',
  transform: 'translateX(-50%)', background: '#1a1b24', color: '#c8cad0',
  fontSize: '11px', padding: '4px 8px', borderRadius: '3px',
  whiteSpace: 'nowrap', pointerEvents: 'none', zIndex: 9999,
  border: '1px solid rgba(255,255,255,0.07)', boxShadow: '0 2px 8px rgba(0,0,0,0.5)',
};

type RGB = [number, number, number];
const mix = (a: RGB, b: RGB, t: number): string => {
  const ch = (ai: number, bi: number) => Math.round(ai * t + bi * (1 - t));
  return `rgb(${ch(a[0],b[0])},${ch(a[1],b[1])},${ch(a[2],b[2])})`;
};
const RED:    RGB = [231, 76,  60];
const GREEN:  RGB = [39,  174, 96];
const ORANGE: RGB = [211, 84,  0];

const getDurabilityColor = (p: number) =>
  p < 50 ? mix(ORANGE, RED, p / 100) : mix(GREEN, ORANGE, p / 100);
const getWeightColor = (p: number) =>
  p > 50 ? mix(RED, ORANGE, p / 100) : mix(ORANGE, GREEN, p / 50);

// ── DurabilityBar ─────────────────────────────────────────────────────────────
const DurabilityBar: React.FC<{ percent: number }> = React.memo(({ percent }) => {
  const pct   = Math.round(percent * 10) / 10;
  const color = useMemo(() => getDurabilityColor(pct), [pct]);
  return (
    <div className="durability-bar">
      <div style={{ width: `${pct}%`, backgroundColor: color, visibility: pct > 0 ? 'visible' : 'hidden' }} />
    </div>
  );
});
DurabilityBar.displayName = 'DurabilityBar';

// ── WeightCircle ──────────────────────────────────────────────────────────────
const WeightCircle: React.FC<{
  percent: number; weightDescription?: string;
  currentWeight?: number; maxWeight?: number;
}> = React.memo(({ percent, weightDescription, currentWeight, maxWeight }) => {
  const [tooltipVisible, setTooltipVisible] = useState(false);
  const pct   = Math.round(percent * 10) / 10;
  const color = useMemo(() => getWeightColor(pct), [pct]);

  const tooltipText = useMemo(() => {
    if (weightDescription) return weightDescription;
    if (currentWeight !== undefined && maxWeight !== undefined) {
      const fmt = (v: number) => v >= 1000 ? `${(v / 1000).toFixed(2)} kg` : `${v} g`;
      return `${fmt(currentWeight)} / ${fmt(maxWeight)}`;
    }
    return `${Math.round(pct)}%`;
  }, [weightDescription, currentWeight, maxWeight, pct]);

  return (
    <div className="weight-circle" onMouseEnter={() => setTooltipVisible(true)} onMouseLeave={() => setTooltipVisible(false)}>
      {/*
        IMPORTANT : la rotation est gérée par la classe CSS .weight-circle__svg
        → NE PAS ajouter transform="rotate(230)" ici
        → Ajouter dans index.scss : .weight-circle__svg { transform: rotate(230deg); }
      */}
      <svg className="weight-circle__svg" viewBox="0 0 36 36" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
        <path className="circle-bg"       d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831" />
        <path className="circle-progress" stroke={color} strokeDasharray={`${pct}, 100`} d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831" />
      </svg>
      <div className="weight-circle__icon" aria-label={tooltipText}>
        <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" strokeWidth="2" stroke="currentColor" fill="none" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
          <path stroke="none" d="M0 0h24v24H0z" fill="none" />
          <path d="M12 6m-3 0a3 3 0 1 0 6 0a3 3 0 1 0 -6 0" />
          <path d="M6.835 9h10.33a1 1 0 0 1 .984 .821l1.637 9a1 1 0 0 1 -.984 1.179h-13.604a1 1 0 0 1 -.984 -1.179l1.637 -9a1 1 0 0 1 .984 -.821z" />
        </svg>
      </div>
      {tooltipVisible && <div className="weight-circle__tooltip" style={TOOLTIP_STYLE} role="tooltip">{tooltipText}</div>}
    </div>
  );
});
WeightCircle.displayName = 'WeightCircle';

// ── WeightBar — dispatcher ────────────────────────────────────────────────────
interface WeightBarProps {
  percent: number; durability?: boolean;
  weightDescription?: string; currentWeight?: number; maxWeight?: number;
}

const WeightBar: React.FC<WeightBarProps> = ({ percent, durability, weightDescription, currentWeight, maxWeight }) => {
  if (durability) return <DurabilityBar percent={percent} />;
  return <WeightCircle percent={percent} weightDescription={weightDescription} currentWeight={currentWeight} maxWeight={maxWeight} />;
};

export default React.memo(WeightBar);
