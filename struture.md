````md id="lvq6a4"
# KT_INVENTORY Structure

## Root

```txt
KT_INVENTORY/
│
├── client.lua                # Main client entry
├── server.lua                # Main server entry
├── init.lua                  # Shared initialization
├── fxmanifest.lua            # Resource manifest
├── README.md                 # Documentation
├── struture.md               # Project structure
````

---

# .github

GitHub automation, workflows and issue templates.

```txt
.github/
│
├── FUNDING.yml
│
├── actions/
│   └── bump-manifest-version.js
│
├── ISSUE_TEMPLATE/
│   ├── bug_report.md
│   └── feature_request.md
│
└── workflows/
    ├── codeql-analysis.yml
    └── release.yml
```

---

# data

Contains all inventory/gameplay configuration data.

```txt
data/
│
├── animations.lua        # Animations list
├── crafting.lua          # Crafting recipes
├── evidence.lua          # Evidence system config
├── items.lua             # Main items
├── items_clothing.lua    # Clothing items
├── licenses.lua          # License config
├── shops.lua             # Shop definitions
├── stashes.lua           # Stashes/storage
├── vehicles.lua          # Vehicle storage config
└── weapons.lua           # Weapon config
```

---

# locales

Translations.

```txt
locales/
│
├── en.json
└── fr.json
```

---

# modules

Main backend/client modular architecture.

```txt
modules/
│
├── bridge/               # Framework bridge
├── crafting/             # Crafting system
├── hooks/                # Hooks/events
├── interface/            # NUI interface
├── inventory/            # Inventory core
├── items/                # Item logic
├── mysql/                # Database layer
├── pefcl/                # PEFCL support
├── shops/                # Shops system
├── utils/                # Shared utilities
└── weapon/               # Weapon logic
```

---

# modules/bridge

Framework abstraction layer.

```txt
modules/bridge/
│
├── client.lua
├── server.lua
│
└── union/
    │
    ├── client.lua
    ├── server.lua
    ├── clothing_client.lua    # Clothing preview callbacks
    └── preview.lua            # Ped preview system
```

---

# modules/crafting

Crafting backend/frontend.

```txt
modules/crafting/
│
├── client.lua
└── server.lua
```

---

# modules/hooks

Server hook system.

```txt
modules/hooks/
│
└── server.lua
```

---

# modules/interface

NUI interaction layer.

```txt
modules/interface/
│
└── client.lua
```

---

# modules/inventory

Main inventory logic.

```txt
modules/inventory/
│
├── client.lua
└── server.lua
```

---

# modules/items

Item handling system.

```txt
modules/items/
│
├── client.lua
├── containers.lua
├── server.lua
└── shared.lua
```

---

# modules/mysql

Database handlers.

```txt
modules/mysql/
│
├── server.lua
└── server_union.lua
```

---

# modules/shops

Shop system.

```txt
modules/shops/
│
├── client.lua
└── server.lua
```

---

# modules/utils

Utility functions.

```txt
modules/utils/
│
├── client.lua
└── server.lua
```

---

# modules/weapon

Weapon system.

```txt
modules/weapon/
│
└── client.lua
```

---

# setup

Migration & conversion tools.

```txt
setup/
│
├── convert.lua
└── convert_union.lua
```

---

# web

React + Vite inventory UI.

```txt
web/
│
├── index.html
├── package.json
├── vite.config.ts
├── tsconfig.json
├── tsconfig.node.json
├── clothing.scss
│
├── build/                 # Production build
│   │
│   ├── index.html
│   │
│   └── assets/
│       ├── index-78feb906.js
│       └── index-dac55531.css
│
└── src/
```

---

# web/src

Main frontend source.

```txt
src/
│
├── App.tsx
├── main.tsx
├── index.scss
├── clothing.scss
│
├── components/
├── dnd/
├── helpers/
├── hooks/
├── reducers/
├── store/
├── thunks/
├── typings/
└── utils/
```

---

# web/src/components/inventory

Inventory UI components.

```txt
components/inventory/
│
├── ClothingGrid.tsx
├── ClothingSlot.tsx
├── InventoryContext.tsx
├── InventoryControl.tsx
├── InventoryGrid.tsx
├── InventoryHotbar.tsx
├── InventorySlot.tsx
├── LeftInventory.tsx
├── LeftInventoryClothing.tsx
├── PlayerPreview.tsx
├── RightInventory.tsx
├── RightInventoryClothing.tsx
├── SlotTooltip.tsx
├── UsefulControls.tsx
└── index.tsx
```

---

# web/src/components/utils

Reusable utility components.

```txt
components/utils/
│
├── Divider.tsx
├── DragPreview.tsx
├── ItemNotifications.tsx
├── KeyPress.tsx
├── Tooltip.tsx
└── WeightBar.tsx
```

---

# web/src/components/utils/icons

Custom icons.

```txt
components/utils/icons/
│
└── ClockIcon.tsx
```

---

# web/src/components/utils/menu

Context menu system.

```txt
components/utils/menu/
│
└── Menu.tsx
```

---

# web/src/components/utils/transitions

Animation components.

```txt
components/utils/transitions/
│
├── Fade.tsx
└── SlideUp.tsx
```

---

# web/src/dnd

Drag & Drop actions.

```txt
dnd/
│
├── onBuy.ts
├── onCraft.ts
├── onDrop.ts
├── onGive.ts
└── onUse.ts
```

---

# web/src/hooks

React hooks.

```txt
hooks/
│
├── useDebounce.ts
├── useExitListener.ts
├── useIntersection.ts
├── useKeyPress.ts
├── useNuiEvent.ts
└── useQueue.ts
```

---

# web/src/reducers

Redux reducers.

```txt
reducers/
│
├── index.ts
├── moveSlots.ts
├── refreshSlots.ts
├── setupInventory.ts
├── stackSlots.ts
└── swapSlots.ts
```

---

# web/src/store

Global application store.

```txt
store/
│
├── clothing.ts
├── contextMenu.ts
├── imagepath.ts
├── index.ts
├── inventory.ts
├── items.ts
├── locale.ts
└── tooltip.ts
```

---

# web/src/thunks

Async Redux actions.

```txt
thunks/
│
├── buyItem.ts
├── craftItem.ts
└── validateItems.ts
```

---

# web/src/typings

TypeScript types.

```txt
typings/
│
├── clothing.ts
├── dnd.ts
├── index.ts
├── inventory.ts
├── item.ts
├── slot.ts
└── state.ts
```

---

# web/src/utils

Frontend utilities.

```txt
utils/
│
├── debugData.ts
├── fetchNui.ts
├── misc.ts
└── setClipboard.ts
```

---

# Architecture Overview

```txt
GAME CLIENT
    │
    ├── Lua Inventory Logic
    ├── Ped Preview System
    ├── Clothing System
    └── NUI Communication
            │
            ▼
REACT / VITE UI
    │
    ├── Redux Store
    ├── Drag & Drop
    ├── Clothing UI
    ├── Player Preview
    └── Context Menus
            │
            ▼
SERVER
    │
    ├── Item Validation
    ├── Database
    ├── Shops
    ├── Crafting
    └── Player Inventories
```

```
```
