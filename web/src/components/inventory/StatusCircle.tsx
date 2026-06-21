import React, { useMemo, useState } from 'react';
import { useAppSelector } from '../../store';
import { selectHunger, selectThirst, selectStress } from '../../store/playerStatus';

export type StatusType = 'hunger' | 'thirst' | 'stress';

const TOOLTIP_STYLE: React.CSSProperties = {
  position: 'absolute', bottom: 'calc(100% + 6px)', left: '50%',
  transform: 'translateX(-50%)', background: '#1a1b24', color: '#c8cad0',
  fontSize: '11px', padding: '4px 8px', borderRadius: '3px',
  whiteSpace: 'nowrap', pointerEvents: 'none', zIndex: 9999,
  border: '1px solid rgba(255,255,255,0.07)', boxShadow: '0 2px 8px rgba(0,0,0,0.5)',
};

type RGB = [number, number, number];
const mixRGB = (a: RGB, b: RGB, t: number): string => {
  const ch = (ai: number, bi: number) => Math.round(ai * t + bi * (1 - t));
  return `rgb(${ch(a[0], b[0])},${ch(a[1], b[1])},${ch(a[2], b[2])})`;
};

const GREEN: RGB = [39, 174, 96];
const ORANGE: RGB = [230, 126, 34];
const RED: RGB = [231, 76, 60];
const BLUE: RGB = [59, 130, 246];

/** Vert → Orange → Rouge, bas = mauvais (faim) */
const getHungerColor = (p: number): string => {
  if (p < 25) return mixRGB(RED, ORANGE, p / 25);
  if (p < 60) return mixRGB(ORANGE, GREEN, (p - 25) / 35);
  return `rgb(${GREEN[0]},${GREEN[1]},${GREEN[2]})`;
};

/** Bleu → Orange → Rouge, bas = mauvais (soif) */
const getThirstColor = (p: number): string => {
  if (p < 25) return mixRGB(RED, ORANGE, p / 25);
  if (p < 60) return mixRGB(ORANGE, BLUE, (p - 25) / 35);
  return `rgb(${BLUE[0]},${BLUE[1]},${BLUE[2]})`;
};

/** Vert → Orange → Rouge, haut = mauvais (stress) */
const getStressColor = (p: number): string => {
  if (p > 75) return mixRGB(RED, ORANGE, (p - 75) / 25);
  if (p > 40) return mixRGB(ORANGE, GREEN, (p - 40) / 35);
  return `rgb(${GREEN[0]},${GREEN[1]},${GREEN[2]})`;
};

const HungerIcon: React.FC = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24"
    fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <path d="M3 2v7c0 1.1.9 2 2 2h4a2 2 0 0 0 2-2V2" />
    <path d="M7 2v20" />
    <path d="M21 15V2a5 5 0 0 0-5 5v6c0 1.1.9 2 2 2h3zm0 0v7" />
  </svg>
);

const ThirstIcon: React.FC = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24"
    fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <path d="M12 2.69l5.66 5.66a8 8 0 1 1-11.31 0z" />
  </svg>
);

const StressIcon: React.FC = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24"
    fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <path d="M13 2 3 14h7l-1 8 10-12h-7l1-8z" />
  </svg>
);

const LABELS: Record<StatusType, string> = { hunger: 'Faim', thirst: 'Soif', stress: 'Stress' };

interface InnerProps { type: StatusType; percent: number; }

const StatusCircleInner: React.FC<InnerProps> = ({ type, percent }) => {
  const [hovered, setHovered] = useState(false);
  const pct = Math.round(percent * 10) / 10;

  const color = useMemo(() => {
    if (type === 'hunger') return getHungerColor(pct);
    if (type === 'thirst') return getThirstColor(pct);
    return getStressColor(pct);
  }, [type, pct]);

  const tooltipText = `${LABELS[type]} : ${Math.round(pct)}%`;

  return (
    <div className="status-circle" onMouseEnter={() => setHovered(true)} onMouseLeave={() => setHovered(false)}>
      <svg className="status-circle__svg" viewBox="0 0 36 36" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
        <path className="circle-bg" d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831" />
        <path className="circle-progress" stroke={color} strokeDasharray={`${pct}, 100`}
          d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831" />
      </svg>

      <div className="status-circle__icon" aria-label={tooltipText}>
        {type === 'hunger' ? <HungerIcon /> : type === 'thirst' ? <ThirstIcon /> : <StressIcon />}
      </div>

      {hovered && <div style={TOOLTIP_STYLE} role="tooltip">{tooltipText}</div>}
    </div>
  );
};

const StatusCircle: React.FC<{ type: StatusType }> = ({ type }) => {
  const hunger = useAppSelector(selectHunger);
  const thirst = useAppSelector(selectThirst);
  const stress = useAppSelector(selectStress);
  const percent = type === 'hunger' ? hunger : type === 'thirst' ? thirst : stress;
  return <StatusCircleInner type={type} percent={percent} />;
};

export default React.memo(StatusCircle);  