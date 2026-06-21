import { createSlice, PayloadAction } from '@reduxjs/toolkit';
import type { RootState } from '.';

interface PlayerStatusState {
  hunger: number;
  thirst: number;
  stress: number;
}

const initialState: PlayerStatusState = {
  hunger: 100,
  thirst: 100,
  stress: 0,
};

export const playerStatusSlice = createSlice({
  name: 'playerStatus',
  initialState,
  reducers: {
    setPlayerStatus(
      state,
      action: PayloadAction<{ hunger?: number; thirst?: number; stress?: number }>
    ) {
      if (action.payload.hunger !== undefined)
        state.hunger = Math.max(0, Math.min(100, action.payload.hunger));
      if (action.payload.thirst !== undefined)
        state.thirst = Math.max(0, Math.min(100, action.payload.thirst));
      if (action.payload.stress !== undefined)
        state.stress = Math.max(0, Math.min(100, action.payload.stress));
    },
  },
});

export const { setPlayerStatus } = playerStatusSlice.actions;
export const selectHunger = (state: RootState) => state.playerStatus.hunger;
export const selectThirst = (state: RootState) => state.playerStatus.thirst;
export const selectStress = (state: RootState) => state.playerStatus.stress;
export default playerStatusSlice.reducer;