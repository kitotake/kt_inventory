// store/itemMeta.ts
import { createSlice, PayloadAction } from '@reduxjs/toolkit';
import type { RootState } from '.';

interface ItemMetaState {
  // suivi des slots en cours de renommage/nettoyage (évite double-clic)
  pendingSlots: Record<number, boolean>;
}

const initialState: ItemMetaState = {
  pendingSlots: {},
};

export const itemMetaSlice = createSlice({
  name: 'itemMeta',
  initialState,
  reducers: {
    setSlotPending(state, action: PayloadAction<{ slot: number; pending: boolean }>) {
      if (action.payload.pending) state.pendingSlots[action.payload.slot] = true;
      else delete state.pendingSlots[action.payload.slot];
    },
  },
});

export const { setSlotPending } = itemMetaSlice.actions;
export const selectPendingSlots = (state: RootState) => state.itemMeta.pendingSlots;
export default itemMetaSlice.reducer;