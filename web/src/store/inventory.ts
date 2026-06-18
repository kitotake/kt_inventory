// store/inventory.ts
import { createSlice, current, isFulfilled, isPending, isRejected, PayloadAction } from '@reduxjs/toolkit';
import type { RootState } from '.';
import {
  moveSlotsReducer,
  refreshSlotsReducer,
  setupInventoryReducer,
  stackSlotsReducer,
  swapSlotsReducer,
} from '../reducers';
import { State } from '../typings';
import { LayoutMode } from '../typings/state';

const initialState: State = {
  leftInventory: {
    id: '', type: '', slots: 0, maxWeight: 0, items: [],
  },
  rightInventory: {
    id: '', type: '', slots: 0, maxWeight: 0, items: [],
  },
  additionalMetadata: [],
  itemAmount:   0,
  shiftPressed: false,
  isBusy:       false,
  layoutMode:   'default',
};

export const inventorySlice = createSlice({
  name: 'inventory',
  initialState,
  reducers: {
    stackSlots:     stackSlotsReducer,
    swapSlots:      swapSlotsReducer,
    setupInventory: setupInventoryReducer,
    moveSlots:      moveSlotsReducer,
    refreshSlots:   refreshSlotsReducer,

    // ── Layout mode ──────────────────────────────────────────────
    setLayoutMode: (state, action: PayloadAction<LayoutMode>) => {
      state.layoutMode = action.payload;
    },

    // Reset layout + inventaire droit quand on ferme
    closeAndReset: (state) => {
      state.layoutMode    = 'default';
      state.rightInventory = { id: '', type: '', slots: 0, maxWeight: 0, items: [] };
    },

    // ── Vide un slot source après drag vers ClothingSlot ────────
    clearSlot: (state, action: PayloadAction<{ slot: number }>) => {
      const idx = action.payload.slot - 1;
      if (idx >= 0 && idx < state.leftInventory.items.length) {
        state.leftInventory.items[idx] = { slot: action.payload.slot };
      }
    },

    setAdditionalMetadata: (state, action: PayloadAction<Array<{ metadata: string; value: string }>>) => {
      const metadata = [];
      for (let i = 0; i < action.payload.length; i++) {
        const entry = action.payload[i];
        if (!state.additionalMetadata.find((el) => el.value === entry.value)) metadata.push(entry);
      }
      state.additionalMetadata = [...state.additionalMetadata, ...metadata];
    },

    setItemAmount:   (state, action: PayloadAction<number>)   => { state.itemAmount   = action.payload; },
    setShiftPressed: (state, action: PayloadAction<boolean>)  => { state.shiftPressed = action.payload; },

    setContainerWeight: (state, action: PayloadAction<number>) => {
      const container = state.leftInventory.items.find(
        (item) => item.metadata?.container === state.rightInventory.id
      );
      if (!container) return;
      container.weight = action.payload;
    },
  },

  extraReducers: (builder) => {
    builder.addMatcher(isPending, (state) => {
      state.isBusy = true;
      state.history = {
        leftInventory:  current(state.leftInventory),
        rightInventory: current(state.rightInventory),
      };
    });
    builder.addMatcher(isFulfilled, (state) => { state.isBusy = false; });
    builder.addMatcher(isRejected,  (state) => {
      if (state.history?.leftInventory && state.history?.rightInventory) {
        state.leftInventory  = state.history.leftInventory;
        state.rightInventory = state.history.rightInventory;
      }
      state.isBusy = false;
    });
  },
});

export const {
  setAdditionalMetadata, setItemAmount, setShiftPressed,
  setupInventory, swapSlots, moveSlots, stackSlots,
  refreshSlots, setContainerWeight, clearSlot,
  setLayoutMode, closeAndReset,
} = inventorySlice.actions;

export const selectLeftInventory  = (state: RootState) => state.inventory.leftInventory;
export const selectRightInventory = (state: RootState) => state.inventory.rightInventory;
export const selectItemAmount     = (state: RootState) => state.inventory.itemAmount;
export const selectIsBusy         = (state: RootState) => state.inventory.isBusy;
export const selectLayoutMode     = (state: RootState) => state.inventory.layoutMode;

export default inventorySlice.reducer;