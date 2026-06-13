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

/**
 * Champs metadata supplémentaires gérés par le menu contextuel enrichi.
 * Tous optionnels — fallback "—"/"Inconnu" si absents.
 *
 * metadata.label       : nom personnalisé (rename RP)
 * metadata.onGround    : item correspond à un objet posé au sol
 * metadata.ammo        : munitions actuelles (déjà existant)
 * metadata.maxAmmo     : capacité max du chargeur (pour % munitions)
 * metadata.createdAt   : date de création, format 'DD/MM/YYYY HH:mm:ss'
 * metadata.origin      : provenance, tableau de strings
 * metadata.uniqueId    : identifiant unique de l'instance d'item
 */
export interface ExtendedItemMetadata {
  label?:     string;
  onGround?:  boolean;
  ammo?:      number;
  maxAmmo?:   number;
  createdAt?: string;
  origin?:    string[];
  uniqueId?:  string;
}