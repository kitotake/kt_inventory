// dnd/onUse.ts
import { fetchNui } from '../utils/fetchNui';
import { Slot } from '../typings';

export const onUse = (item: Slot) => {
  fetchNui('useItem', item.slot);
};
