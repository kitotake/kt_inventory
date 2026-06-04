// components/inventory/InventoryFilterRight.tsx
import React, { useCallback } from 'react';
import { CATEGORY_LABELS, SortCategory, SortOrder, SORT_ORDER_LABELS } from '../../hooks/useItemSort';

const CATEGORY_ICONS: Record<SortCategory, string> = {
  all: 'ti-grid-dots', weapons: 'ti-gun', food: 'ti-soup', drinks: 'ti-bottle',
  clothing: 'ti-shirt', medical: 'ti-first-aid-kit',
};

interface Props {
  activeCategory:   SortCategory;
  sortOrder:        SortOrder;
  highlightCount:   number;
  side?:            'left' | 'right';
  onCategoryChange: (cat: SortCategory) => void;
  onSortChange:     (order: SortOrder)  => void;
  onReset:          () => void;
}

const InventoryFilterRight : React.FC<Props> = React.memo(({
  activeCategory, sortOrder, highlightCount, side = 'right',
  onCategoryChange, onSortChange, onReset,
}) => {
  const categories = Object.keys(CATEGORY_LABELS) as SortCategory[];
  const sortOrders = Object.keys(SORT_ORDER_LABELS) as SortOrder[];

  return (
    <div className={`inv-filter${side === 'right' ? ' inv-filter--right' : ''}`}>

      {/* Catégories */}
      <div className="inv-filter__categories" role="group" aria-label="Catégories">
        {categories.map((cat) => (
          <button
            key={cat}
            className={`inv-filter__cat-btn${activeCategory === cat ? ' inv-filter__cat-btn--active' : ''}`}
            onClick={() => onCategoryChange(cat)}
            title={CATEGORY_LABELS[cat]}
            aria-pressed={activeCategory === cat}
          >
            <i className={`ti ${CATEGORY_ICONS[cat]}`} aria-hidden="true" />
            <span className="inv-filter__cat-label">{CATEGORY_LABELS[cat]}</span>
          </button>
        ))}
     </div>

      {/* Tri */}
      <div className="inv-filter__sort-row" role="group" aria-label="Trier par">
        <span className="inv-filter__sort-label">Tri :</span>
        {sortOrders.map((order) => (
          <button
            key={order}
            className={`inv-filter__sort-btn${sortOrder === order ? ' inv-filter__sort-btn--active' : ''}`}
            onClick={() => onSortChange(order)}
            aria-pressed={sortOrder === order}
          >
            {SORT_ORDER_LABELS[order]}
          </button>
        ))}
      </div>

    </div>
  );
});

InventoryFilterRight.displayName = 'InventoryFilterRight';
export default InventoryFilterRight;