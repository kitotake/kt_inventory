// store/playerStatus.ts
import { createSlice, PayloadAction } from '@reduxjs/toolkit';
import type { RootState } from '.';

interface PlayerStatusState {
  food:  number; // 0-100
  drink: number; // 0-100
}

const initialState: PlayerStatusState = {
  food:  75,
  drink: 60,
};

export const playerStatusSlice = createSlice({
  name: 'playerStatus',
  initialState,
  reducers: {
    setPlayerStatus(
      state,
      action: PayloadAction<{ food?: number; drink?: number }>
    ) {
      if (action.payload.food  !== undefined)
        state.food  = Math.max(0, Math.min(100, action.payload.food));
      if (action.payload.drink !== undefined)
        state.drink = Math.max(0, Math.min(100, action.payload.drink));
    },
  },
});

export const { setPlayerStatus } = playerStatusSlice.actions;
export const selectFood  = (state: RootState) => state.playerStatus.food;
export const selectDrink = (state: RootState) => state.playerStatus.drink;
export default playerStatusSlice.reducer;