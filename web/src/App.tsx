// App.tsx
import InventoryComponent from './components/inventory';
import useNuiEvent from './hooks/useNuiEvent';
import { Items } from './store/items';
import { Locale } from './store/locale';
import { setImagePath } from './store/imagepath';
import { setupInventory } from './store/inventory';
import { Inventory } from './typings';
import { useAppDispatch } from './store';
import { debugData } from './utils/debugData';
import DragPreview from './components/utils/DragPreview';
import { fetchNui } from './utils/fetchNui';
import { useDragDropManager } from 'react-dnd';
import KeyPress from './components/utils/KeyPress';
import { useEffect } from 'react';
import { equipClothing, removeClothing, setAllEquipped } from './store/clothing';
import { ClothingCategory, EquippedClothingItem, EquippedClothing } from './typings/clothing';
import { isEnvBrowser } from './utils/misc';

// ── Peuple Items synchroniquement en mode browser ─────────────────────────────
if (isEnvBrowser()) {
  Items['iron']              = { name: 'iron',              label: 'Fer',               weight: 3000, stack: true,  close: false, usable: false, count: 0, category: 'material'      };
  Items['water']             = { name: 'water',             label: 'Eau en bouteille',  weight: 500,  stack: true,  close: false, usable: true,  count: 0, category: 'consumable'    };
  Items['bandage']           = { name: 'bandage',           label: 'Bandage',           weight: 115,  stack: true,  close: false, usable: true,  count: 0, category: 'medical'       };
  Items['burger']            = { name: 'burger',            label: 'Burger',            weight: 20,   stack: true,  close: false, usable: true,  count: 0, category: 'consumable'    };
  Items['clothing_hat']      = { name: 'clothing_hat',      label: 'Chapeau',           weight: 100,  stack: false, close: false, usable: false, count: 0, category: 'clothing',     clothingSlot: 'hat'        };
  Items['clothing_mask']     = { name: 'clothing_mask',     label: 'Masque de ski',     weight: 115,  stack: false, close: false, usable: false, count: 0, category: 'clothing',     clothingSlot: 'mask'       };
  Items['clothing_glasses']  = { name: 'clothing_glasses',  label: 'Lunettes',          weight: 80,   stack: false, close: false, usable: false, count: 0, category: 'clothing',     clothingSlot: 'glasses'    };
  Items['clothing_chain']    = { name: 'clothing_chain',    label: 'Écharpe',           weight: 90,   stack: false, close: false, usable: false, count: 0, category: 'clothing',     clothingSlot: 'chain'      };
  Items['clothing_gloves']   = { name: 'clothing_gloves',   label: 'Gants',             weight: 100,  stack: false, close: false, usable: false, count: 0, category: 'clothing',     clothingSlot: 'gloves'     };
  Items['clothing_top']      = { name: 'clothing_top',      label: 'Veste',             weight: 300,  stack: false, close: false, usable: false, count: 0, category: 'clothing',     clothingSlot: 'top'        };
  Items['clothing_watch']    = { name: 'clothing_watch',    label: 'Montre',            weight: 50,   stack: false, close: false, usable: false, count: 0, category: 'clothing',     clothingSlot: 'watch'      };
  Items['clothing_pants']    = { name: 'clothing_pants',    label: 'Pantalon',          weight: 250,  stack: false, close: false, usable: false, count: 0, category: 'clothing',     clothingSlot: 'pants'      };
  Items['clothing_cap']      = { name: 'clothing_cap',      label: 'Casquette',         weight: 80,   stack: false, close: false, usable: false, count: 0, category: 'clothing',     clothingSlot: 'cap'        };
  Items['clothing_hair']     = { name: 'clothing_hair',     label: 'Coiffure',          weight: 0,    stack: false, close: false, usable: false, count: 0, category: 'clothing',     clothingSlot: 'hair'       };
  Items['clothing_bracelet'] = { name: 'clothing_bracelet', label: 'Bracelet',          weight: 40,   stack: false, close: false, usable: false, count: 0, category: 'clothing',     clothingSlot: 'bracelet'   };
  Items['clothing_bag']      = { name: 'clothing_bag',      label: 'Sac à dos',         weight: 200,  stack: false, close: false, usable: false, count: 0, category: 'clothing',     clothingSlot: 'bag'        };
  Items['clothing_shoes']    = { name: 'clothing_shoes',    label: 'Chaussures',        weight: 150,  stack: false, close: false, usable: false, count: 0, category: 'clothing',     clothingSlot: 'shoes'      };
  Items['clothing_armor']    = { name: 'clothing_armor',    label: 'Gilet pare-balles', weight: 500,  stack: false, close: false, usable: false, count: 0, category: 'clothing',     clothingSlot: 'armor'      };
  Items['clothing_under']    = { name: 'clothing_under',    label: 'Sous-vêtement',     weight: 80,   stack: false, close: false, usable: false, count: 0, category: 'clothing',     clothingSlot: 'undershirt' };
  Items['clothing_ears']     = { name: 'clothing_ears',     label: "Boucles d'oreille", weight: 20,   stack: false, close: false, usable: false, count: 0, category: 'clothing',     clothingSlot: 'ears'       };
  Items['clothing_tenu_001'] = { name: 'clothing_tenu_001', label: 'Tenue complète',    weight: 800,  stack: false, close: false, usable: false, count: 0, category: 'clothing_tenu' };
}

debugData([
  {
    action: 'setupInventory',
    data: {
      leftInventory: {
        id: 'test', type: 'player', slots: 80, label: 'Bob Smith',
        weight: 3000, maxWeight: 25000,
        items: [
          { slot:  1, name: 'iron',              weight: 3000, count: 5,  metadata: { description: 'Minerai de fer' } },
          { slot:  2, name: 'water',             weight: 500,  count: 3,  metadata: { description: 'Eau fraîche'    } },
          { slot:  3, name: 'bandage',           weight: 115,  count: 5,  metadata: { durability: 75 } },
          { slot:  4, name: 'clothing_hat',      weight: 100,  count: 1,  metadata: { texture: 0, label: 'Chapeau'          } },
          { slot:  5, name: 'clothing_mask',     weight: 115,  count: 1,  metadata: { texture: 0, label: 'Masque de ski'     } },
          { slot:  6, name: 'clothing_glasses',  weight: 80,   count: 1,  metadata: { texture: 0, label: 'Lunettes'          } },
          { slot:  7, name: 'clothing_chain',    weight: 90,   count: 1,  metadata: { texture: 0, label: 'Écharpe'           } },
          { slot:  8, name: 'clothing_gloves',   weight: 100,  count: 1,  metadata: { texture: 0, label: 'Gants'             } },
          { slot:  9, name: 'clothing_top',      weight: 300,  count: 1,  metadata: { texture: 0, label: 'Veste'             } },
          { slot: 10, name: 'clothing_watch',    weight: 50,   count: 1,  metadata: { texture: 0, label: 'Montre'            } },
          { slot: 11, name: 'clothing_pants',    weight: 250,  count: 1,  metadata: { texture: 0, label: 'Pantalon'          } },
          { slot: 12, name: 'clothing_cap',      weight: 80,   count: 1,  metadata: { texture: 0, label: 'Casquette'         } },
          { slot: 13, name: 'clothing_hair',     weight: 0,    count: 1,  metadata: { texture: 0, label: 'Coiffure'          } },
          { slot: 14, name: 'clothing_bracelet', weight: 40,   count: 1,  metadata: { texture: 0, label: 'Bracelet'          } },
          { slot: 15, name: 'clothing_bag',      weight: 200,  count: 1,  metadata: { texture: 0, label: 'Sac à dos'         } },
          { slot: 16, name: 'clothing_shoes',    weight: 150,  count: 1,  metadata: { texture: 0, label: 'Chaussures'        } },
          { slot: 17, name: 'clothing_armor',    weight: 500,  count: 1,  metadata: { texture: 0, label: 'Gilet pare-balles' } },
          { slot: 18, name: 'clothing_under',    weight: 80,   count: 1,  metadata: { texture: 0, label: 'Sous-vêtement'     } },
          { slot: 19, name: 'clothing_ears',     weight: 20,   count: 1,  metadata: { texture: 0, label: "Boucles d'oreille" } },
          { slot: 20, name: 'clothing_tenu_001', weight: 800,  count: 1,  metadata: { texture: 0, label: 'Tenue complète'    } },
        ],
      },
      rightInventory: {
        id: 'shop', type: 'shop', slots: 30, label: 'Boutique',
        weight: 0, maxWeight: 100000,
        items: [
          { slot: 1, name: 'water',   weight: 5,   price: 10, count: 999 },
          { slot: 2, name: 'bandage', weight: 115, price: 50, count: 50  },
          { slot: 3, name: 'burger',  weight: 20,  price: 15, count: 100 },
        ],
      },
    },
  },
]);

const App: React.FC = () => {
  const dispatch = useAppDispatch();
  const manager = useDragDropManager();

  useEffect(() => {
    fetchNui('uiLoaded', {});
  }, []);

  useNuiEvent<{
    locale: { [key: string]: string };
    items: typeof Items;
    leftInventory: Inventory;
    imagepath: string;
  }>('init', ({ locale, items, leftInventory, imagepath }) => {
    for (const name in locale) Locale[name] = locale[name];
    for (const name in items) Items[name] = items[name];
    setImagePath(imagepath);
    dispatch(setupInventory({ leftInventory }));
  });

  useNuiEvent('closeInventory', () => {
    manager.dispatch({ type: 'dnd-core/END_DRAG' });
  });

  useNuiEvent<{ category: ClothingCategory; item: EquippedClothingItem }>('clothingEquipped', ({ category, item }) => {
    dispatch(equipClothing({ category, item }));
  });

  useNuiEvent<{ category: ClothingCategory }>('clothingRemoved', ({ category }) => {
    dispatch(removeClothing(category));
  });

  useNuiEvent<EquippedClothing>('setClothingState', (data) => {
    dispatch(setAllEquipped(data));
  });

  return (
    <div className="app-wrapper">
      <InventoryComponent />
      <DragPreview />
      <KeyPress />
    </div>
  );
};

addEventListener('dragstart', (event) => event.preventDefault());

export default App;