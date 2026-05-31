// typings/slot.ts
export type Slot = {
  slot:          number;
  name?:         string;
  count?:        number;
  weight?:       number;
  category?:     string;
  clothingSlot?: string;
  metadata?:     { [key: string]: any };
  durability?:   number;
};

export type SlotWithItem = Slot & {
  name:        string;
  count:       number;
  weight:      number;
  durability?: number;
  price?:      number;
  currency?:   string;
  ingredients?:{ [key: string]: number };
  duration?:   number;
  image?:      string;
  grade?:      number | number[];
  category?:   string;
  clothingSlot?:string;
};
