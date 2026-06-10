// store/clothing.ts
import { createSlice, PayloadAction } from '@reduxjs/toolkit';
import { ClothingCategory, EquippedClothing, EquippedClothingItem } from '../typings/clothing';
import { RootState } from './index';

interface ClothingState {
  equipped:     EquippedClothing;
  selectedSlot: ClothingCategory | null;
}



const initialState: ClothingState = {
  equipped:     {},
  selectedSlot: null,
};

export const clothingSlice = createSlice({
  name: 'clothing',
  initialState,
  reducers: {
    equipClothing(
      state,
      action: PayloadAction<{ category: ClothingCategory; item: EquippedClothingItem }>
    ) {
      state.equipped[action.payload.category] = action.payload.item;
    },

    // store/clothing.ts — correctif removeClothing
removeClothing(state, action: PayloadAction<ClothingCategory>) {
  delete state.equipped[action.payload]; // delete au lieu d'assigner null
},

    setSelectedSlot(state, action: PayloadAction<ClothingCategory | null>) {
      state.selectedSlot = action.payload;
    },

    setAllEquipped(state, action: PayloadAction<EquippedClothing>) {
      state.equipped = action.payload;
    },

    equipOutfit(
      state,
      action: PayloadAction<{
        name:  string;
        label: string;
        slots: Partial<Record<ClothingCategory, EquippedClothingItem>>;
      }>
    ) {
      for (const [category, item] of Object.entries(action.payload.slots)) {
        state.equipped[category as ClothingCategory] = item ?? null;
      }
    },

    removeAllClothing(state) {
      for (const key of Object.keys(state.equipped)) {
        state.equipped[key] = null;
      }
    },
  },
});

export const {
  equipClothing,
  removeClothing,
  setSelectedSlot,
  setAllEquipped,
  equipOutfit,
  removeAllClothing,
} = clothingSlice.actions;

export const selectEquipped     = (state: RootState) => state.clothing.equipped;
export const selectSelectedSlot = (state: RootState) => state.clothing.selectedSlot;

export default clothingSlice.reducer;
