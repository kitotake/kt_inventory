// store/clothing.ts
import { createSlice, PayloadAction } from '@reduxjs/toolkit';
import { ClothingCategory, EquippedClothing, EquippedClothingItem } from '../typings/clothing';
import { RootState } from './index';

interface ClothingState {
  equipped: EquippedClothing;
  selectedSlot: ClothingCategory | null;
}

const initialState: ClothingState = {
  equipped: {},
  selectedSlot: null,
};

export const clothingSlice = createSlice({
  name: 'clothing',
  initialState,
  reducers: {
    equipClothing(
      state,
      action: PayloadAction<{
        category: ClothingCategory;
        item: EquippedClothingItem;
      }>
    ) {
      const { category, item } = action.payload;
      state.equipped[category] = item;
    },
    removeClothing(state, action: PayloadAction<ClothingCategory>) {
      state.equipped[action.payload] = null;
    },
    setSelectedSlot(state, action: PayloadAction<ClothingCategory | null>) {
      state.selectedSlot = action.payload;
    },
    setAllEquipped(state, action: PayloadAction<EquippedClothing>) {
      state.equipped = action.payload;
    },
  },
});

export const { equipClothing, removeClothing, setSelectedSlot, setAllEquipped } = clothingSlice.actions;

export const selectEquipped     = (state: RootState) => state.clothing.equipped;
export const selectSelectedSlot = (state: RootState) => state.clothing.selectedSlot;

export default clothingSlice.reducer;
