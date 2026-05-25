import React, { useMemo } from 'react';

const colorChannelMixer = (a: number, b: number, amount: number) =>
  a * amount + b * (1 - amount);

const colorMixer = (rgbA: number[], rgbB: number[], amount: number) =>
  `rgb(${colorChannelMixer(rgbA[0], rgbB[0], amount)}, ${colorChannelMixer(rgbA[1], rgbB[1], amount)}, ${colorChannelMixer(rgbA[2], rgbB[2], amount)})`;

const COLORS = {
  primaryColor: [231, 76, 60],
  secondColor:  [39, 174, 96],
  accentColor:  [211, 84, 0],
};

interface Props {
  percent: number;
  durability?: boolean;
}

const WeightBar: React.FC<Props> = ({ percent, durability }) => {
  const color = useMemo(
    () =>
      durability
        ? percent < 50
          ? colorMixer(COLORS.accentColor, COLORS.primaryColor, percent / 100)
          : colorMixer(COLORS.secondColor,  COLORS.accentColor,  percent / 100)
        : percent > 50
        ? colorMixer(COLORS.primaryColor, COLORS.accentColor, percent / 100)
        : colorMixer(COLORS.accentColor,  COLORS.secondColor,  percent / 50),
    [durability, percent]
  );

  // ======================================================
  // DURABILITY BAR
  // ======================================================

  if (durability) {
    return (
      <div className="durability-bar">
        <div
          style={{
            width: `${percent}%`,
            backgroundColor: color,
            visibility: percent > 0 ? 'visible' : 'hidden',
          }}
        />
      </div>
    );
  }

  // ======================================================
  // WEIGHT CIRCLE
  // ======================================================

  return (
    <div className="weight-circle">
      <svg viewBox="0 0 36 36" xmlns="http://www.w3.org/2000/svg">
        {/* Background track */}
        <path
          className="circle-bg"
          d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831"
        />
        {/* Progress */}
        <path
          className="circle-progress"
          stroke={color}
          strokeDasharray={`${percent}, 100`}
          d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831"
        />
      </svg>

      {/* Icône poids — SVG Tabler inline, pas de dépendance FA */}
      <div className="weight-circle__icon">
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="11"
          height="11"
          viewBox="0 0 24 24"
          strokeWidth="2"
          stroke="currentColor"
          fill="none"
          strokeLinecap="round"
          strokeLinejoin="round"
          aria-hidden="true"
        >
          <path stroke="none" d="M0 0h24v24H0z" fill="none" />
          {/* cercle du haut */}
          <path d="M12 6m-3 0a3 3 0 1 0 6 0a3 3 0 1 0 -6 0" />
          {/* sac */}
          <path d="M6.835 9h10.33a1 1 0 0 1 .984 .821l1.637 9a1 1 0 0 1 -.984 1.179h-13.604a1 1 0 0 1 -.984 -1.179l1.637 -9a1 1 0 0 1 .984 -.821z" />
        </svg>
      </div>
    </div>
  );
};

export default WeightBar;
