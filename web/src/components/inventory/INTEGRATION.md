# Guide d'intégration — Système vêtements kt_inventory

## Fichiers à créer (nouveaux)

| Fichier généré             | Destination dans ton projet                          |
|----------------------------|------------------------------------------------------|
| clothing.ts                | web/src/typings/clothing.ts                          |
| clothingStore.ts           | web/src/store/clothing.ts                            |
| LeftInventoryClothing.tsx  | web/src/components/inventory/LeftInventoryClothing.tsx  |
| RightInventoryClothing.tsx | web/src/components/inventory/RightInventoryClothing.tsx |
| PlayerPreview.tsx          | web/src/components/inventory/PlayerPreview.tsx       |
| clothing.scss              | web/src/clothing.scss  (puis @import dans index.scss)|

## Fichiers à remplacer (modifiés)

| Fichier généré       | Remplace                                          |
|----------------------|---------------------------------------------------|
| index.tsx            | web/src/components/inventory/index.tsx            |
| InventoryControl.tsx | web/src/components/inventory/InventoryControl.tsx |
| storeIndex.ts        | web/src/store/index.ts                            |

---

## Étape 1 — Copier les nouveaux fichiers

```
web/src/typings/clothing.ts          ← clothing.ts
web/src/store/clothing.ts            ← clothingStore.ts
web/src/components/inventory/LeftInventoryClothing.tsx
web/src/components/inventory/RightInventoryClothing.tsx
web/src/components/inventory/PlayerPreview.tsx
web/src/clothing.scss
```

## Étape 2 — Remplacer les fichiers existants

```
web/src/store/index.ts               ← storeIndex.ts
web/src/components/inventory/index.tsx
web/src/components/inventory/InventoryControl.tsx
```

## Étape 3 — Importer le SCSS

Dans `web/src/index.scss`, ajouter tout en bas :

```scss
@import './clothing.scss';
```

## Étape 4 — Ajouter les icônes Tabler (si pas déjà présent)

Dans `web/index.html`, ajouter dans le `<head>` :

```html
<link
  rel="stylesheet"
  href="https://cdn.jsdelivr.net/npm/@tabler/icons-webfont@latest/tabler-icons.min.css"
/>
```

## Étape 5 — Côté Lua (client.lua)

Pour envoyer les vêtements équipés au démarrage :

```lua
-- Quand l'inventaire s'ouvre, envoyer les vêtements équipés
SendNUIMessage({
  action = 'setupClothing',
  data = {
    top       = { name = 'tshirt_1', label = 'T-Shirt', drawable = 1, texture = 0 },
    pants     = { name = 'jeans_1',  label = 'Jeans',   drawable = 2, texture = 0 },
    -- etc.
  }
})

-- Quand le joueur retire un vêtement (NUI callback)
RegisterNUICallback('removeClothing', function(data, cb)
  local category = data.category
  -- Appeler ta fonction de retrait de vêtement
  -- ex: SetPedComponentVariation(PlayerPedId(), ...)
  cb('ok')
end)
```

## Résumé du nouveau layout

```
┌─────────────────────────────────────────────────────────────┐
│  LeftInventory │ LeftClothing │ Player │ RightClothing │ RightInventory │
│                                                             │
│                   [ Quantité : 0 → 10 000 ]               │
└─────────────────────────────────────────────────────────────┘
```

## Ce qui a été supprimé

- ❌ Bouton `Use`
- ❌ Bouton `Give`
- ❌ Bouton `Close`
- ❌ Bouton `i` (useful controls)

## Ce qui a été ajouté

- ✅ `LeftInventoryClothing` — 8 slots (Chapeau, Masque, Lunettes, Écharpe, Gants, Veste, Montre, Pantalon)
- ✅ `PlayerPreview` — silhouette SVG réactive aux vêtements équipés
- ✅ `RightInventoryClothing` — 8 slots (Casquette, Coiffure, Bracelet, Sac, Chaussures, Gilet, Sous-vêt., Boucles)
- ✅ Input quantité 0→10000 tout en bas
- ✅ Store Redux `clothing` — equip / remove / selectedSlot
- ✅ Clic droit sur un slot → retire le vêtement
- ✅ Badge bleu si item équipé
- ✅ Slot surligné en bleu si sélectionné
