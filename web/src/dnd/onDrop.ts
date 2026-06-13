// dnd/onDrop.ts
import { canStack, findAvailableSlot, getTargetInventory, isSlotWithItem } from '../helpers';
import { validateMove } from '../thunks/validateItems';
import { store } from '../store';
import { DragSource, DropTarget, InventoryType, SlotWithItem } from '../typings';
import { moveSlots, stackSlots, swapSlots } from '../store/inventory';
import { Items } from '../store/items';

export const onDrop = (source: DragSource, target?: DropTarget) => {
  if (!source.item?.slot || source.item.slot < 1) return;

  const { inventory: state } = store.getState();
  const { sourceInventory, targetInventory } = getTargetInventory(state, source.inventory, target?.inventory);

  const sourceSlot = sourceInventory.items.find(i => i.slot === source.item.slot) as SlotWithItem | undefined;
  if (!sourceSlot) return console.error(`[onDrop] source slot ${source.item.slot} not found`);

  const sourceData = Items[sourceSlot.name];
  if (sourceData === undefined) return console.error(`${sourceSlot.name} item data undefined!`);

  if (sourceSlot.metadata?.container !== undefined) {
    if (targetInventory.type === InventoryType.CONTAINER) return;
    if (state.rightInventory.id === sourceSlot.metadata.container) return;
  }

  const targetSlot = target
    ? targetInventory.items.find(i => i.slot === target.item.slot)
    : findAvailableSlot(sourceSlot, sourceData, targetInventory.items);

  if (targetSlot === undefined) return;
  if (targetSlot.metadata?.container !== undefined && state.rightInventory.id === targetSlot.metadata.container) return;

  const count =
    state.shiftPressed && sourceSlot.count > 1 && sourceInventory.type !== 'shop'
      ? Math.floor(sourceSlot.count / 2)
      : state.itemAmount === 0 || state.itemAmount > sourceSlot.count
      ? sourceSlot.count
      : state.itemAmount;

  const data = { fromSlot: sourceSlot, toSlot: targetSlot, fromType: sourceInventory.type, toType: targetInventory.type, count };
  store.dispatch(validateMove({ ...data, fromSlot: sourceSlot.slot, toSlot: targetSlot.slot }));

  isSlotWithItem(targetSlot, true)
    ? sourceData.stack && canStack(sourceSlot, targetSlot)
      ? store.dispatch(stackSlots({ ...data, toSlot: targetSlot }))
      : store.dispatch(swapSlots({ ...data, toSlot: targetSlot }))
    : store.dispatch(moveSlots(data));
};