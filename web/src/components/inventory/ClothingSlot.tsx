// components/inventory/ClothingSlot.tsx
// v3 :
//   ✓ Suppression de dispatch(closeTooltip()) (tooltip retiré du projet)
//   ✓ Retrait de l'import closeTooltip, openTooltip
//   ✓ Retrait de tooltipItem, handleMouseEnter, handleMouseLeave

import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useDrag, useDrop }               from 'react-dnd';
import { useAppDispatch, useAppSelector } from '../../store';
import { isEnvBrowser }                   from '../../utils/misc';
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
import { fetchNui }                           from '../../utils/fetchNui';
import { clearSlot }                          from '../../store/inventory';
import { DragSource, InventoryType } from '../../typings';
import { getItemUrl }                         from '../../helpers';
import { Items }                              from '../../store/items';
import { getClothingImageUrlSync }            from '../../hooks/useClothingImage';

export type ClothingDragSource = DragSource & {
  fromClothingSlot?: ClothingCategory;
};

interface EquipResponse  { ok: boolean; reason?: string; }
interface RemoveResponse { ok: boolean; reason?: string; }

interface Props {
  category: ClothingCategory;
  label:    string;
  icon:     string;
  accepts:  ClothingCategory[];
  item?:    EquippedClothingItem | null;
}

const computeStyle = (p: {
  isOver:     boolean;
  canDrop:    boolean;
  isOutfit:   boolean;
  isEquipped: boolean;
  isDragging: boolean;
  isBusy:     boolean;
  imageUrl?:  string;
}): React.CSSProperties => {
  return {
    backgroundImage:    p.imageUrl ? `url(${p.imageUrl})` : 'none',
    backgroundSize:     '62%',
    backgroundPosition: 'center 40%',
    backgroundRepeat:   'no-repeat',
    opacity:   p.isDragging ? 0.35 : p.isBusy ? 0.6 : 1,
    cursor:    p.isBusy ? 'wait' : undefined,
    transition:
      'transform 120ms ease, border-color 120ms ease, ' +
      'background-color 120ms ease, box-shadow 120ms ease, opacity 120ms ease',
  };
};

const ClothingSlot: React.FC<Props> = ({ category, label, icon, accepts, item }) => {
  const dispatch   = useAppDispatch();
  const selected   = useAppSelector(selectSelectedSlot);
  const isSelected = selected === category;
  const isEquipped = Boolean(item);
  const isOutfit   = isEquipped && item?.itemType === 'clothing_tenu';

  const [isBusy, setIsBusy] = useState(false);

  const itemRef     = useRef(item);
  const isBusyRef   = useRef(isBusy);
  const categoryRef = useRef(category);
  const acceptsRef  = useRef(accepts);

  useEffect(() => { itemRef.current     = item;     }, [item]);
  useEffect(() => { isBusyRef.current   = isBusy;   }, [isBusy]);
  useEffect(() => { categoryRef.current = category; }, [category]);
  useEffect(() => { acceptsRef.current  = accepts;  }, [accepts]);

  // [] intentionnel : toutes les valeurs lues via refs
  const [{ isDragging }, drag] = useDrag<ClothingDragSource, void, { isDragging: boolean }>(
    () => ({
      type: 'SLOT',
      canDrag: () => Boolean(itemRef.current) && !isBusyRef.current,
      item: (): ClothingDragSource => ({
        inventory: InventoryType.PLAYER,
        item: { name: itemRef.current!.name, slot: 0 },
        image: itemRef.current?.name
          ? `url(${getItemUrl(itemRef.current.name) ?? ''})`
          : undefined,
        fromClothingSlot: categoryRef.current,
      }),
      collect: (monitor) => ({ isDragging: monitor.isDragging() }),
    }),
    []
  );

  // [] intentionnel : toutes les valeurs lues via refs
  const [{ isOver, canDrop }, drop] = useDrop<ClothingDragSource, void, { isOver: boolean; canDrop: boolean }>(
    () => ({
      accept: 'SLOT',
      collect: (monitor) => ({ isOver: monitor.isOver(), canDrop: monitor.canDrop() }),

      canDrop: (source) => {
        if (isBusyRef.current) return false;
        if (source.fromClothingSlot) return false;
        if (source.inventory !== InventoryType.PLAYER) return false;
        const name = source.item?.name ?? '';
        const data = Items[name];
        return canDropInSlot(name, data?.category, acceptsRef.current, data?.clothingSlot);
      },

      drop: (source) => {
        if (!source.item) return;
        const name     = source.item.name ?? '';
        const srcSlot  = source.item.slot;
        const data     = Items[name];
        const itemType = getClothingItemType(name);

        setIsBusy(true);

        if (isEnvBrowser()) {
          dispatch(equipClothing({
            category: categoryRef.current,
            item: { name, label: data?.label ?? name, itemType },
          }));

          // ✅ FIX : vide le slot inventaire source (équivalent du
          //          consumedInvSlot envoyé par le serveur en prod)
          if (srcSlot && srcSlot > 0) {
            dispatch(clearSlot({ slot: srcSlot }));
          }

          setIsBusy(false);
          return;
        }

        fetchNui<EquipResponse>('equipClothingItem', {
          invSlot:  srcSlot,
          category: categoryRef.current,
          name,
          swap:     Boolean(itemRef.current),
        })
          .then((res) => {
            if (!res?.ok) return;
            dispatch(equipClothing({
              category: categoryRef.current,
              item: { name, label: data?.label ?? name, itemType },
            }));
          })
          .catch((err) => console.error('[ClothingSlot] equip error:', err))
          .finally(() => setIsBusy(false));
      },
    }),
    []
  );

  const connectRef = useCallback(
    (el: HTMLDivElement | null) => { if (el) drag(drop(el)); },
    [drag, drop]
  );

  const handleRemove = useCallback((e: React.MouseEvent) => {
    e.stopPropagation();
    if (!itemRef.current || isBusyRef.current) return;

    setIsBusy(true);

    if (isEnvBrowser()) {
      dispatch(removeClothing(categoryRef.current));
      setIsBusy(false);
      return;
    }

    fetchNui<RemoveResponse>('removeClothing', {
      category: categoryRef.current,
      name:     itemRef.current.name,
    })
      .then((res) => { if (res?.ok) dispatch(removeClothing(categoryRef.current)); })
      .catch(() => {})
      .finally(() => setIsBusy(false));
  }, [dispatch]);

  const imageUrl = useMemo(() => {
    if (!item) return undefined;
    const texture     = (item as any).metadata?.texture ?? 0;
    const clothingUrl = getClothingImageUrlSync(item.name, texture);
    return clothingUrl ?? getItemUrl(item.name) ?? undefined;
  }, [item]);

  const slotStyle = useMemo(
    () => computeStyle({ isOver, canDrop, isOutfit, isEquipped, isDragging, isBusy, imageUrl }),
    [isOver, canDrop, isOutfit, isEquipped, isDragging, isBusy, imageUrl]
  );

  const handleClick = useCallback(() => {
    if (isBusyRef.current) return;
    const next = isSelected ? null : category;
    dispatch(setSelectedSlot(next));
    if (next) fetchNui('pedPreviewZoomCategory', { category: next });
    else      fetchNui('pedPreviewResetCam', {});
  }, [dispatch, isSelected, category]);

  const className = useMemo(() => [
    'inventory-slot',
    'clothing-slot',
    isSelected ? 'clothing-slot--selected' : '',
    isEquipped ? 'clothing-slot--equipped'  : '',
    isOutfit   ? 'clothing-slot--outfit'    : '',
    isDragging ? 'clothing-slot--dragging'  : '',
    isBusy     ? 'clothing-slot--busy'      : '',
    isOver && !canDrop ? 'clothing-slot--rejected' : '',
    isOver && canDrop  ? 'clothing-slot--accept'   : '',
  ].filter(Boolean).join(' '),
  [isSelected, isEquipped, isOutfit, isDragging, isBusy, isOver, canDrop]);

  return (
    <div
      ref={connectRef}
      className={className}
      style={slotStyle}
      onClick={handleClick}
    >
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

      {item && (
        <div className="item-slot-wrapper">
          {isOutfit
            ? <div className="clothing-slot__outfit-badge" />
            : <div className="clothing-slot__badge" />
          }
          <div className="inventory-slot-label-box">
            <div className="inventory-slot-label-text">{item.label}</div>
          </div>
        </div>
      )}
    </div>
  );
};

export default React.memo(ClothingSlot);