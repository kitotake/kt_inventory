// components/inventory/ClothingSlot.tsx
// v10 — drag & drop avec équipement réel (RemoveItem/AddItem serveur)
//
// DIFF vs v9 :
//   ✓ drop équipement      → appelle 'equipClothingItem', attend confirmation serveur
//   ✓ handleRemove         → devient async, attend 'removeClothing', annule si échec
//   ✓ swap                 → si slot déjà occupé, envoie swap=true au Lua
//   ✗ plus de dispatch optimiste avant confirmation serveur

import React, { useCallback, useMemo, useState }    from 'react';
import { useDrag, useDrop }               from 'react-dnd';
import { useAppDispatch, useAppSelector } from '../../store';
import {
  ClothingCategory,
  EquippedClothingItem,
  canDropInSlot,
  getClothingItemType,
} from '../../typings/clothing';
import {
  selectSelectedSlot,
  setSelectedSlot,
  equipClothing,
  removeClothing,
} from '../../store/clothing';
import { fetchNui }                        from '../../utils/fetchNui';
import { DragSource, InventoryType, SlotWithItem } from '../../typings';
import { closeTooltip, openTooltip }       from '../../store/tooltip';
import { getItemUrl }                      from '../../helpers';
import { Items }                           from '../../store/items';
import { getClothingImageUrlSync }         from '../../hooks/useClothingImage';

// ─── Types ────────────────────────────────────────────────────────────────────

export type ClothingDragSource = DragSource & {
  fromClothingSlot?: ClothingCategory;
};

interface EquipResponse {
  ok: boolean;
  reason?: string;
  swapped?: {
    name:  string;
    label: string;
    metadata?: Record<string, any>;
  };
}

interface RemoveResponse {
  ok: boolean;
  reason?: string;
}

interface Props {
  category: ClothingCategory;
  label:    string;
  icon:     string;
  accepts:  ClothingCategory[];
  item?:    EquippedClothingItem | null;
}

// ─── Style ────────────────────────────────────────────────────────────────────

const computeStyle = (p: {
  isOver:     boolean;
  canDrop:    boolean;
  isSelected: boolean;
  isOutfit:   boolean;
  isEquipped: boolean;
  isDragging: boolean;
  isBusy:     boolean;
  imageUrl?:  string;
}): React.CSSProperties => {
  let border = '', bg = '', shadow = 'none';

  if (p.isOver && p.canDrop) {
    border = '1px dashed rgba(255,255,255,0.6)';
    bg     = 'rgba(59,130,246,0.12)';
  } else if (p.isOver) {
    border = '1px dashed rgba(231,76,60,0.6)';
    bg     = 'rgba(231,76,60,0.08)';
  } else if (p.isSelected) {
    border = '1px solid rgba(59,130,246,0.9)';
    bg     = 'rgba(37,99,235,0.15)';
    shadow = '0 0 12px rgba(59,130,246,0.35),inset 0 0 8px rgba(59,130,246,0.1)';
  } else if (p.isOutfit) {
    border = '1px solid rgba(167,139,250,0.6)';
    bg     = 'rgba(109,40,217,0.08)';
  } else if (p.isEquipped) {
    border = '1px solid rgba(37,99,235,0.5)';
    shadow = '0 0 6px rgba(37,99,235,0.2)';
  }

  return {
    backgroundImage:    p.imageUrl ? `url(${p.imageUrl})` : 'none',
    backgroundSize:     '62%',
    backgroundPosition: 'center 40%',
    backgroundRepeat:   'no-repeat',
    border,
    backgroundColor:    bg,
    boxShadow:          shadow,
    opacity:            p.isDragging ? 0.35 : p.isBusy ? 0.6 : 1,
    cursor:             p.isBusy ? 'wait' : undefined,
    transition:
      'transform 120ms ease, border-color 120ms ease, ' +
      'background-color 120ms ease, box-shadow 120ms ease, opacity 120ms ease',
  };
};

// ─── Composant ────────────────────────────────────────────────────────────────

const ClothingSlot: React.FC<Props> = ({ category, label, icon, accepts, item }) => {
  const dispatch   = useAppDispatch();
  const selected   = useAppSelector(selectSelectedSlot);
  const isSelected = selected === category;
  const isEquipped = Boolean(item);
  const isOutfit   = isEquipped && item?.itemType === 'clothing_tenu';

  // Verrou local anti-spam pendant un aller-retour serveur
  const [isBusy, setIsBusy] = useState(false);

  const acceptsKey    = accepts.join(',');
  // eslint-disable-next-line react-hooks/exhaustive-deps
  const stableAccepts = useMemo(() => accepts, [acceptsKey]);

  // ── useDrag ──────────────────────────────────────────────────────────────
  const [{ isDragging }, drag] = useDrag<
    ClothingDragSource,
    void,
    { isDragging: boolean }
  >(
    () => ({
      type:    'SLOT',
      canDrag: () => Boolean(item) && !isBusy,
      item: (): ClothingDragSource => ({
        inventory:       InventoryType.PLAYER,
        item:            { name: item!.name, slot: 0 },
        image:           item?.name ? `url(${getItemUrl(item.name) ?? ''})` : undefined,
        fromClothingSlot: category,
      }),
      collect: (m) => ({ isDragging: m.isDragging() }),
    }),
    [item, category, isBusy]
  );

  // ── useDrop ──────────────────────────────────────────────────────────────
  const [{ isOver, canDrop }, drop] = useDrop<
    ClothingDragSource,
    void,
    { isOver: boolean; canDrop: boolean }
  >(
    () => ({
      accept:  'SLOT',
      collect: (m) => ({ isOver: m.isOver(), canDrop: m.canDrop() }),

      canDrop: (source) => {
        if (isBusy)                                     return false;
        if (source.fromClothingSlot)                    return false;
        if (source.inventory !== InventoryType.PLAYER) return false;
        const name = source.item?.name ?? '';
        const d    = Items[name];
        return canDropInSlot(name, d?.category, stableAccepts, d?.clothingSlot);
      },

      drop: (source) => {
        if (!source.item) return;

        const name    = source.item.name ?? '';
        const srcSlot = source.item.slot;          // slot inventaire réel
        const d       = Items[name];
        const type    = getClothingItemType(name);

        dispatch(closeTooltip());
        setIsBusy(true);

        // ── Appel serveur : équipement réel ──────────────────────────────────
        //    - Le Lua retire l'item de l'inventaire (RemoveItem côté serveur)
        //    - Si un item est déjà équipé dans ce slot, swap=true demande
        //      au serveur de le ré-ajouter dans l'inventaire en échange
        //    - Aucune mise à jour Redux/visuelle avant confirmation 'ok'
        fetchNui<EquipResponse>('equipClothingItem', {
          invSlot: srcSlot,
          category,
          name,
          swap: Boolean(item),
        })
          .then((res) => {
            if (!res?.ok) {
              // Échec (slot incompatible, item déjà déplacé, inventaire plein
              // pour le swap, etc.) — aucun changement visuel/Redux
              return;
            }

            // 1. Équiper le nouvel item dans Redux
            dispatch(equipClothing({
              category,
              item: { name, label: d?.label ?? name, itemType: type },
            }));

            // 2. Si un item était déjà équipé, il a été remis dans l'inventaire
            //    par le serveur — le rafraîchissement de l'inventaire arrive
            //    via l'event NUI 'refreshSlots' (déclenché côté Lua après le
            //    callback serveur). Rien à faire ici pour l'item swappé.

            // 3. Vider le slot source côté inventaire local (l'item a été
            //    retiré côté serveur). Le Lua envoie aussi 'refreshSlots'
            //    mais on anticipe pour éviter un flicker.
            //    -> géré via dispatch(clearSlot) déclenché par l'event NUI
            //       'clothingEquipped' dans index.tsx (cf. fichier index.tsx)
          })
          .catch(() => {
            // erreur réseau / NUI — ne rien changer
          })
          .finally(() => setIsBusy(false));
      },
    }),
    [category, stableAccepts, dispatch, item, isBusy]
  );

  // ── Ref combinée ─────────────────────────────────────────────────────────
  const connectRef = useCallback(
    (el: HTMLDivElement | null) => { drag(drop(el)); },
    [drag, drop]
  );

  // ── Retrait visuel + réintégration inventaire ───────────────────────────
  const handleRemove = useCallback(
    (e: React.MouseEvent) => {
      e.stopPropagation();
      if (!item || isBusy) return;

      setIsBusy(true);
      dispatch(closeTooltip());

      // Le serveur :
      //  1. Vérifie qu'un slot d'inventaire est libre (AddItem)
      //  2. Si oui : ajoute l'item dans l'inventaire, retire l'état "équipé"
      //  3. Si non : retourne { ok: false, reason: 'inventory_full' }
      //     → le Lua affiche une notification, RIEN n'est modifié visuellement
      fetchNui<RemoveResponse>('removeClothing', { category, name: item.name })
        .then((res) => {
          if (!res?.ok) {
            // inventory_full ou autre — le vêtement reste équipé,
            // la notification d'erreur est gérée côté Lua (lib.notify)
            return;
          }
          dispatch(removeClothing(category));
        })
        .catch(() => {
          // erreur réseau — ne rien changer
        })
        .finally(() => setIsBusy(false));
    },
    [dispatch, category, item, isBusy]
  );

  // ── Image URL ─────────────────────────────────────────────────────────────
  const imageUrl = useMemo(() => {
    if (!item) return undefined;
    const texture    = (item as any).metadata?.texture ?? 0;
    const clothingUrl = getClothingImageUrlSync(item.name, texture);
    if (clothingUrl) return clothingUrl;
    return getItemUrl(item.name) ?? undefined;
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [item]);

  // ── Style calculé ─────────────────────────────────────────────────────────
  const slotStyle = useMemo(
    () => computeStyle({ isOver, canDrop, isSelected, isOutfit, isEquipped, isDragging, isBusy, imageUrl }),
    [isOver, canDrop, isSelected, isOutfit, isEquipped, isDragging, isBusy, imageUrl]
  );

  // ── Tooltip ───────────────────────────────────────────────────────────────
  const tooltipItem = useMemo((): SlotWithItem | null => {
    if (!item) return null;
    return {
      slot: 0, name: item.name, count: 1, weight: 0,
      metadata: {
        label:       item.label,
        description: item.itemType === 'clothing_tenu'
          ? 'Tenue complète'
          : 'Vêtement équipé',
      },
    };
  }, [item]);

  const handleClick = useCallback(() => {
    if (isBusy) return;
    const next = isSelected ? null : category;
    dispatch(setSelectedSlot(next));
    if (next) fetchNui('pedPreviewZoomCategory', { category: next });
    else      fetchNui('pedPreviewResetCam', {});
  }, [dispatch, isSelected, category, isBusy]);

  const handleMouseEnter = useCallback(() => {
    if (!tooltipItem) return;
    dispatch(openTooltip({ item: tooltipItem, inventoryType: 'player' }));
  }, [dispatch, tooltipItem]);

  const handleMouseLeave = useCallback(
    () => dispatch(closeTooltip()),
    [dispatch]
  );

  // ── Classes CSS ───────────────────────────────────────────────────────────
  const className = useMemo(() => [
    'inventory-slot',
    'clothing-slot',
    isSelected         ? 'clothing-slot--selected' : '',
    isEquipped         ? 'clothing-slot--equipped'  : '',
    isOutfit           ? 'clothing-slot--outfit'    : '',
    isDragging         ? 'clothing-slot--dragging'  : '',
    isBusy             ? 'clothing-slot--busy'      : '',
    isOver && !canDrop ? 'clothing-slot--rejected'  : '',
    isOver && canDrop  ? 'clothing-slot--accept'    : '',
  ].filter(Boolean).join(' '), [isSelected, isEquipped, isOutfit, isDragging, isBusy, isOver, canDrop]);

  // ── Rendu ─────────────────────────────────────────────────────────────────
  return (
    <div
      ref={connectRef}
      className={className}
      style={slotStyle}
      onClick={handleClick}
      onMouseEnter={handleMouseEnter}
      onMouseLeave={handleMouseLeave}
    >
      {/* Slot vide */}
      {!item && (
        <>
          <div className="clothing-slot__icon-wrapper" aria-hidden="true">
            <i className={`ti ${icon} clothing-slot__icon`} />
          </div>
          <div className="inventory-slot-label-box">
            <div className="inventory-slot-label-text">{label}</div>
          </div>
        </>
      )}

      {/* Slot occupé */}
      {item && (
        <div className="item-slot-wrapper">
          {isOutfit
            ? <div className="clothing-slot__outfit-badge" />
            : <div className="clothing-slot__badge" />
          }

          {/* Bouton retrait — réintègre l'item dans l'inventaire */}
          <button
            className="clothing-slot__remove-btn"
            onClick={handleRemove}
            disabled={isBusy}
            title="Retirer le vêtement"
            aria-label={`Retirer ${item.label}`}
          >
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
              <line x1="18" y1="6"  x2="6"  y2="18" />
              <line x1="6"  y1="6"  x2="18" y2="18" />
            </svg>
          </button>

          {isSelected && (
            <div className="clothing-slot__selected-overlay" aria-hidden="true" />
          )}

          <div className="inventory-slot-label-box">
            <div className="inventory-slot-label-text">{item.label}</div>
          </div>
        </div>
      )}

      {/* Indicateurs drag */}
      {isOver && canDrop && (
        <div className="clothing-slot__drop-indicator" aria-hidden="true">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
            <polyline points="20 6 9 17 4 12" />
          </svg>
        </div>
      )}
      {isOver && !canDrop && (
        <div className="clothing-slot__reject-indicator" aria-hidden="true">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
            <line x1="18" y1="6"  x2="6"  y2="18" />
            <line x1="6"  y1="6"  x2="18" y2="18" />
          </svg>
        </div>
      )}
    </div>
  );
};

export default React.memo(ClothingSlot);