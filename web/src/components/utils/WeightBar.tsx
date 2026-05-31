// components/utils/WeightBar.tsx
import React, { useMemo, useState } from 'react';

const colorChannelMixer = (a: number, b: number, amount: number) => a * amount + b * (1 - amount);
const colorMixer = (rgbA: number[], rgbB: number[], amount: number) =>
  `rgb(${colorChannelMixer(rgbA[0], rgbB[0], amount)}, ${colorChannelMixer(rgbA[1], rgbB[1], amount)}, ${colorChannelMixer(rgbA[2], rgbB[2], amount)})`;

const COLORS = {
  primaryColor: [231, 76, 60],
  secondColor:  [39, 174, 96],
  accentColor:  [211, 84, 0],
};

interface Props {
  percent:           number;
  durability?:       boolean;
  weightDescription?:string;
  currentWeight?:    number;
  maxWeight?:        number;
}

const WeightBar: React.FC<Props> = ({ percent, durability, weightDescription, currentWeight, maxWeight }) => {
  const [tooltipVisible, setTooltipVisible] = useState(false);

  const color = useMemo(() =>
    durability
      ? percent < 50
        ? colorMixer(COLORS.accentColor, COLORS.primaryColor, percent / 100)
        : colorMixer(COLORS.secondColor,  COLORS.accentColor,  percent / 100)
      : percent > 50
      ? colorMixer(COLORS.primaryColor, COLORS.accentColor, percent / 100)
      : colorMixer(COLORS.accentColor,  COLORS.secondColor,  percent / 50),
  [durability, percent]);

  if (durability) {
    return (
      <div className="durability-bar">
        <div style={{ width: `${percent}%`, backgroundColor: color, visibility: percent > 0 ? 'visible' : 'hidden' }} />
      </div>
    );
  }

  const buildTooltip = () => {
    if (weightDescription) return weightDescription;
    if (currentWeight !== undefined && maxWeight !== undefined) {
      const cur = currentWeight >= 1000 ? `${(currentWeight / 1000).toFixed(2)} kg` : `${currentWeight} g`;
      const max = maxWeight >= 1000     ? `${(maxWeight / 1000).toFixed(2)} kg`     : `${maxWeight} g`;
      return `${cur} / ${max}`;
    }
    return `${Math.round(percent)}%`;
  };

  return (
    <div
      className="weight-circle"
      onMouseEnter={() => setTooltipVisible(true)}
      onMouseLeave={() => setTooltipVisible(false)}
      style={{ cursor: 'default' }}
    >
      <svg viewBox="0 0 36 36" xmlns="http://www.w3.org/2000/svg">
        <path className="circle-bg"       d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831" />
        <path className="circle-progress" stroke={color} strokeDasharray={`${percent}, 100`} d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831" />
      </svg>
      <div className="weight-circle__icon">
        <svg xmlns="http://www.w3.org/2000/svg" width="11" height="11" viewBox="0 0 24 24" strokeWidth="2" stroke="currentColor" fill="none" strokeLinecap="round" strokeLinejoin="round">
          <path stroke="none" d="M0 0h24v24H0z" fill="none" />
          <path d="M12 6m-3 0a3 3 0 1 0 6 0a3 3 0 1 0 -6 0" />
          <path d="M6.835 9h10.33a1 1 0 0 1 .984 .821l1.637 9a1 1 0 0 1 -.984 1.179h-13.604a1 1 0 0 1 -.984 -1.179l1.637 -9a1 1 0 0 1 .984 -.821z" />
        </svg>
      </div>
      {tooltipVisible && (
        <div className="weight-circle__tooltip" style={{ position: 'absolute', bottom: 'calc(100% + 6px)', left: '50%', transform: 'translateX(-50%)', background: '#1a1b24', color: '#c8cad0', fontSize: '11px', padding: '4px 8px', borderRadius: '3px', whiteSpace: 'nowrap', pointerEvents: 'none', zIndex: 9999, border: '1px solid rgba(255,255,255,0.07)', boxShadow: '0 2px 8px rgba(0,0,0,0.5)' }}>
          {buildTooltip()}
        </div>
      )}
    </div>
  );
};

export default WeightBar;
