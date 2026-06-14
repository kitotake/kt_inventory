// components/inventory/DevModeSwitcher.tsx
// Visible uniquement en mode navigateur (pnpm dev / debugData).
// Permet de basculer le rightInventory entre différents types de démo.

import React, { useState } from 'react';
import { useAppDispatch } from '../../store';
import { setupInventory } from '../../store/inventory';
import { isEnvBrowser } from '../../utils/misc';

// ── Types de modes disponibles ────────────────────────────────

type DevMode = 'shop' | 'crafting' | 'player' | 'container';

interface ModeConfig {
  label:    string;
  icon:     string;
  tooltip:  string;
  color:    string;
  inventory: any;
}

// ── Données de démo par mode ──────────────────────────────────

const MODES: Record<DevMode, ModeConfig> = {
  shop: {
    label:   'Boutique',
    icon:    'ti-shopping-cart',
    tooltip: 'Inventaire type Shop',
    color:   'var(--dev-mode-shop)',
    inventory: {
      id: 'shop_demo', type: 'shop', slots: 30, label: 'Boutique',
      weight: 0, maxWeight: 100000,
      items: [
        { slot: 1, name: 'water',   weight: 5,   price: 10,  count: 999 },
        { slot: 2, name: 'bandage', weight: 115, price: 50,  count: 50  },
        { slot: 3, name: 'burger',  weight: 20,  price: 15,  count: 100 },
        { slot: 4, name: 'iron',    weight: 3000,price: 200, count: 30  },
      ],
    },
  },

  crafting: {
    label:   'Craft',
    icon:    'ti-tools',
    tooltip: 'Inventaire type Crafting',
    color:   'var(--dev-mode-crafting)',
    inventory: {
      id: 'crafting_demo', type: 'crafting', slots: 20, label: 'Atelier',
      weight: 0, maxWeight: 0,
      items: [
        {
          slot: 1, name: 'bandage', weight: 115, count: 1,
          duration: 3000,
          ingredients: { iron: 2, water: 1 },
        },
        {
          slot: 2, name: 'burger', weight: 20, count: 1,
          duration: 5000,
          ingredients: { water: 1 },
        },
      ],
    },
  },

  player: {
    label:   'Joueur',
    icon:    'ti-user',
    tooltip: 'Second inventaire joueur (échange)',
    color:   'var(--dev-mode-player)',
    inventory: {
      id: 'player2_demo', type: 'player', slots: 40, label: 'Joueur B',
      weight: 2000, maxWeight: 15000,
      items: [
        { slot: 1, name: 'water',   weight: 500,  count: 2,  metadata: {} },
        { slot: 2, name: 'bandage', weight: 115,  count: 10, metadata: {} },
        { slot: 3, name: 'iron',    weight: 3000, count: 1,  metadata: {} },
      ],
    },
  },

  container: {
    label:   'Conteneur',
    icon:    'ti-box',
    tooltip: 'Inventaire type Container',
    color:   'var(--dev-mode-container)',
    inventory: {
      id: 'container_demo', type: 'container', slots: 20, label: 'Coffre',
      weight: 5000, maxWeight: 50000,
      items: [
        { slot: 1, name: 'iron',    weight: 3000, count: 10, metadata: {} },
        { slot: 2, name: 'bandage', weight: 115,  count: 5,  metadata: {} },
      ],
    },
  },
};

// ── Composant ─────────────────────────────────────────────────

const DevModeSwitcher: React.FC = () => {
  if (!isEnvBrowser()) return null;

  const dispatch   = useAppDispatch();
  const [active, setActive] = useState<DevMode>('shop');
  const [animating, setAnimating] = useState(false);

  const handleSwitch = (mode: DevMode) => {
    if (mode === active || animating) return;
    setAnimating(true);
    setActive(mode);
    dispatch(setupInventory({ rightInventory: MODES[mode].inventory }));
    setTimeout(() => setAnimating(false), 250);
  };

  return (
    <div className="dev-mode-switcher" role="toolbar" aria-label="Mode inventaire droit">
      <span className="dev-mode-switcher__badge">DEV</span>
      <div className="dev-mode-switcher__buttons">
        {(Object.keys(MODES) as DevMode[]).map((mode) => {
          const cfg    = MODES[mode];
          const isSel  = active === mode;
          return (
            <button
              key={mode}
              className={[
                'dev-mode-switcher__btn',
                isSel ? 'dev-mode-switcher__btn--active' : '',
                animating && isSel ? 'dev-mode-switcher__btn--animating' : '',
              ].filter(Boolean).join(' ')}
              style={isSel ? { '--mode-color': cfg.color } as React.CSSProperties : undefined}
              onClick={() => handleSwitch(mode)}
              title={cfg.tooltip}
              aria-pressed={isSel}
            >
              <i className={`ti ${cfg.icon}`} aria-hidden="true" />
              <span>{cfg.label}</span>
            </button>
          );
        })}
      </div>
    </div>
  );
};

export default DevModeSwitcher;