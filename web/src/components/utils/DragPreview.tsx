import React from 'react';
import { useDragLayer } from 'react-dnd';
import { DragSource } from '../../typings';

const DragPreview: React.FC = () => {
  const { isDragging, item, currentOffset } = useDragLayer((monitor) => ({
    isDragging: monitor.isDragging(),
    item: monitor.getItem() as DragSource | null,
    currentOffset: monitor.getClientOffset(),
  }));

  if (!isDragging || !currentOffset || !item?.item) {
    return null;
  }

  return (
    <div
      className="item-drag-preview"
      style={{
        transform: `translate(${currentOffset.x}px, ${currentOffset.y}px)`,
        backgroundImage: item.image,
        pointerEvents: 'none',
      }}
    />
  );
};

export default DragPreview;