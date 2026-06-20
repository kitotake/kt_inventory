// components/inventory/InventoryControl.tsx

import React, { useState } from 'react';
import { useDrop } from 'react-dnd';
import { useAppDispatch, useAppSelector } from '../../store';
import { selectItemAmount, setItemAmount } from '../../store/inventory';
import { DragSource } from '../../typings';
import { onUse } from '../../dnd/onUse';
import { onGive } from '../../dnd/onGive';
import { Locale } from '../../store/locale';
import UsefulControls from './UsefulControls';
import StatusCircle from './StatusCircle';

const InventoryControl: React.FC = () => {
  const itemAmount = useAppSelector(selectItemAmount);
  const dispatch = useAppDispatch();
  const [infoVisible, setInfoVisible] = useState(false);

  const [, use] = useDrop<DragSource, void, unknown>(() => ({
    accept: 'SLOT',
    drop: (source) => {
      if (source.inventory === 'player') {
        onUse(source.item);
      }
    },
  }));

  const [, give] = useDrop<DragSource, void, unknown>(() => ({
    accept: 'SLOT',
    drop: (source) => {
      if (source.inventory === 'player') {
        onGive(source.item);
      }
    },
  }));

  const inputHandler = (event: React.ChangeEvent<HTMLInputElement>) => {
    const value = isNaN(event.target.valueAsNumber)
      ? 0
      : Math.max(0, Math.floor(event.target.valueAsNumber));

    dispatch(setItemAmount(value));
  };

  return (
    <>
      <UsefulControls
        infoVisible={infoVisible}
        setInfoVisible={setInfoVisible}
      />

      <div className="inventory-control">
       <div className="inventory-control">

  {/* Ligne statuts */}
  <div className="inventory-status-row">
    <StatusCircle type="food" />
    <StatusCircle type="drink" />
  </div>

  {/* Ligne contrôles */}
  <div className="inventory-control-wrapper">
    <input
      className="inventory-control-input"
      type="number"
      defaultValue={itemAmount}
      onChange={inputHandler}
      min={0}
    />

    <button
      className="inventory-control-button"
      ref={use}
    >
      {Locale.ui_use || 'Utiliser'}
    </button>
  </div>

</div>
      </div>
    </>
  );
};

export default InventoryControl;