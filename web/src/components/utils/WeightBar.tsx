import React, { useMemo } from 'react';

const colorChannelMixer = (
  colorChannelA: number,
  colorChannelB: number,
  amountToMix: number
) => {
  const channelA = colorChannelA * amountToMix;
  const channelB = colorChannelB * (1 - amountToMix);

  return channelA + channelB;
};

const colorMixer = (
  rgbA: number[],
  rgbB: number[],
  amountToMix: number
) => {
  const r = colorChannelMixer(
    rgbA[0],
    rgbB[0],
    amountToMix
  );

  const g = colorChannelMixer(
    rgbA[1],
    rgbB[1],
    amountToMix
  );

  const b = colorChannelMixer(
    rgbA[2],
    rgbB[2],
    amountToMix
  );

  return `rgb(${r}, ${g}, ${b})`;
};

const COLORS = {
  primaryColor: [231, 76, 60],
  secondColor: [39, 174, 96],
  accentColor: [211, 84, 0],
};

interface Props {
  percent: number;
  durability?: boolean;
}

const WeightBar: React.FC<Props> = ({
  percent,
  durability,
}) => {
  const color = useMemo(
    () =>
      durability
        ? percent < 50
          ? colorMixer(
              COLORS.accentColor,
              COLORS.primaryColor,
              percent / 100
            )
          : colorMixer(
              COLORS.secondColor,
              COLORS.accentColor,
              percent / 100
            )
        : percent > 50
        ? colorMixer(
            COLORS.primaryColor,
            COLORS.accentColor,
            percent / 100
          )
        : colorMixer(
            COLORS.accentColor,
            COLORS.secondColor,
            percent / 50
          ),

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
            visibility:
              percent > 0 ? 'visible' : 'hidden',
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
      <svg viewBox="0 0 36 36">
        {/* Background */}
        <path
          className="circle-bg"
          d="
            M18 2.0845
            a 15.9155 15.9155 0 0 1 0 31.831
            a 15.9155 15.9155 0 0 1 0 -31.831
          "
        />

        {/* Progress */}
        <path
          className="circle-progress"
          stroke={color}
          strokeDasharray={`${percent}, 100`}
          d="
            M18 2.0845
            a 15.9155 15.9155 0 0 1 0 31.831
            a 15.9155 15.9155 0 0 1 0 -31.831
          "
        />
      </svg>

      {/* Icon */}
      <div className="weight-circle__icon">
        <i className="fa-solid fa-weight-hanging" />
      </div>
    </div>
  );
};

export default WeightBar;