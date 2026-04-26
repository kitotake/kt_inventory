KT_INVENTORY
└── web
    ├── .gitignore
    ├── .prettierrc
    ├── index.html
    ├── package-lock.json
    ├── package.json
    ├── pnpm-lock.yaml
    ├── tsconfig.json
    ├── tsconfig.node.json
    ├── vite.config.ts
    │
    ├── build
    │   ├── index.html
    │   └── assets
    │       ├── index-73495d07.js
    │       └── index-9aba2ab3.css
    │
    ├── images
    │   ├── advancedkit.png
    │   ├── ammo-*.png
    │   ├── WEAPON_*.png
    │   ├── bandage.png
    │   ├── money.png
    │   ├── lockpick.png
    │   ├── phone.png
    │   ├── water.png
    │   ├── weed.png
    │   ├── */etc.png
    │   └── ziptie.png
    │
    └── src
        ├── App.tsx
        ├── index.scss
        ├── main.tsx
        ├── vite-env.d.ts
        │
        ├── components
        │   └── inventory
        │       ├── index.tsx
        │       ├── InventoryContext.tsx
        │       ├── InventoryControl.tsx
        │       ├── InventoryGrid.tsx
        │       ├── InventoryHotbar.tsx
        │       ├── InventorySlot.tsx
        │       ├── LeftInventory.tsx
        │       ├── RightInventory.tsx
        │       ├── SlotTooltip.tsx
        │       └── UsefulControls.tsx
        │
        ├── components/utils
        │   ├── Divider.tsx
        │   ├── DragPreview.tsx
        │   ├── ItemNotifications.tsx
        │   ├── KeyPress.tsx
        │   ├── Tooltip.tsx
        │   ├── WeightBar.tsx
        │   │
        │   ├── icons
        │   │   └── ClockIcon.tsx
        │   │
        │   ├── menu
        │   │   └── Menu.tsx
        │   │
        │   └── transitions
        │       ├── Fade.tsx
        │       └── SlideUp.tsx
        │
        ├── dnd
        │   ├── onBuy.ts
        │   ├── onCraft.ts
        │   ├── onDrop.ts
        │   ├── onGive.ts
        │   └── onUse.ts
        │
        ├── helpers
        │   └── index.ts
        │
        ├── hooks
        │   ├── useDebounce.ts
        │   ├── useExitListener.ts
        │   ├── useIntersection.ts
        │   ├── useKeyPress.ts
        │   ├── useNuiEvent.ts
        │   └── useQueue.ts
        │
        ├── reducers
        │   ├── index.ts
        │   ├── moveSlots.ts
        │   ├── refreshSlots.ts
        │   ├── setupInventory.ts
        │   ├── stackSlots.ts
        │   └── swapSlots.ts
        │
        ├── store
        │   ├── contextMenu.ts
        │   ├── imagepath.ts
        │   ├── index.ts
        │   ├── inventory.ts
        │   ├── items.ts
        │   ├── locale.ts
        │   └── tooltip.ts
        │
        ├── thunks
        │   ├── buyItem.ts
        │   ├── craftItem.ts
        │   └── validateItems.ts
        │
        ├── typings
        │   ├── dnd.ts
        │   ├── index.ts
        │   ├── inventory.ts
        │   ├── item.ts
        │   ├── slot.ts
        │   └── state.ts
        │
        └── utils
            ├── debugData.ts
            ├── fetchNui.ts
            ├── misc.ts
            └── setClipboard.ts
