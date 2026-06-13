// components/inventory/ClothingSlot.tsx
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
import { DragSource, InventoryType, SlotWithItem } from '../../typings';
import { closeTooltip, openTooltip }          from '../../store/tooltip';
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

        dispatch(closeTooltip());
        setIsBusy(true);

        if (isEnvBrowser()) {
          dispatch(equipClothing({
            category: categoryRef.current,
            item: { name, label: data?.label ?? name, itemType },
          }));
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
    dispatch(closeTooltip());

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
    () => computeStyle({ isOver, canDrop, isSelected, isOutfit, isEquipped, isDragging, isBusy, imageUrl }),
    [isOver, canDrop, isSelected, isOutfit, isEquipped, isDragging, isBusy, imageUrl]
  );

  const tooltipItem = useMemo((): SlotWithItem | null => {
    if (!item) return null;
    return {
      slot: 0, name: item.name, count: 1, weight: 0,
      metadata: {
        label:       item.label,
        description: item.itemType === 'clothing_tenu' ? 'Tenue complète' : 'Vêtement équipé',
      },
    };
  }, [item]);

  const handleClick = useCallback(() => {
    if (isBusyRef.current) return;
    const next = isSelected ? null : category;
    dispatch(setSelectedSlot(next));
    if (next) fetchNui('pedPreviewZoomCategory', { category: next });
    else      fetchNui('pedPreviewResetCam', {});
  }, [dispatch, isSelected, category]);

  const handleMouseEnter = useCallback(() => {
    if (!tooltipItem) return;
    dispatch(openTooltip({ item: tooltipItem, inventoryType: 'player' }));
  }, [dispatch, tooltipItem]);

  const handleMouseLeave = useCallback(() => dispatch(closeTooltip()), [dispatch]);

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
      onMouseEnter={handleMouseEnter}
      onMouseLeave={handleMouseLeave}
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