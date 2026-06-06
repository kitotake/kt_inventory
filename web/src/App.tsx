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

debugData([
  {
    action: 'setupInventory',
    data: {
      leftInventory: {
        id: 'test', type: 'player', slots: 80, label: 'Bob Smith',
        weight: 3000, maxWeight: 25000,
        items: [
          { slot: 1, name: 'iron',    weight: 3000, metadata: { description: 'name: Svetozar Miletic\nGender: Male', ammo: 3 }, count: 5 },
          { slot: 2, name: 'water',   weight: 100,  count: 1, metadata: { description: 'Eau fraîche' } },
          { slot: 3, name: 'bandage', weight: 115,  count: 3, metadata: { durability: 75 } },
          { slot: 4, name: 'clothing', weight: 115,  count: 3, metadata: { components: { mask: [1, 0] } } },
        ],
      },
      rightInventory: {
        id: 'shop', type: 'shop', slots: 30, label: 'Boutique',
        weight: 0, maxWeight: 100000,
        items: [
          { slot: 1, name: 'water',   weight: 5,   price: 10,  count: 999 },
          { slot: 2, name: 'bandage', weight: 115, price: 50,  count: 50  },
          { slot: 3, name: 'burger',  weight: 20,  price: 15,  count: 100 },
        ],
      },
    },
  },
]);

const App: React.FC = () => {
  const dispatch = useAppDispatch();
  const manager  = useDragDropManager();

  useEffect(() => { fetchNui('uiLoaded', {}); }, []);

  useNuiEvent<{
    locale:        { [key: string]: string };
    items:         typeof Items;
    leftInventory: Inventory;
    imagepath:     string;
  }>('init', ({ locale, items, leftInventory, imagepath }) => {
    for (const name in locale) Locale[name] = locale[name];
    for (const name in items)  Items[name]  = items[name];
    setImagePath(imagepath);
    dispatch(setupInventory({ leftInventory }));
  });

  useNuiEvent('closeInventory', () => {
    manager.dispatch({ type: 'dnd-core/END_DRAG' });
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
