// components/inventory/SlotTooltip.tsx
// CORRECTIONS :
//   1. Styles inline extraits en constantes module-level
//   2. QualityStars et CraftingIngredients isolés en sous-composants mémoïsés
//   3. React.memo sur le composant entier

import React, { Fragment, useMemo } from 'react';
import ReactMarkdown   from 'react-markdown';
import { useAppSelector } from '../../store';
import { Items }       from '../../store/items';
import { Locale }      from '../../store/locale';
import { getItemUrl }  from '../../helpers';
import { Inventory, SlotWithItem } from '../../typings';
import ClockIcon       from '../utils/icons/ClockIcon';
import Divider         from '../utils/Divider';

const STYLE_MUTED: React.CSSProperties = { color: 'rgba(180,182,190,0.5)', fontSize: '11px', marginTop: '2px' };
const STYLE_TYPE:  React.CSSProperties = { color: 'rgba(180,182,190,0.5)', fontSize: '11px' };

const QUALITY_COLORS: Record<number, string> = { 1:'#9ca3af', 2:'#22c55e', 3:'#3b82f6', 4:'#a855f7', 5:'#f59e0b' };
const QUALITY_NAMES  = ['', 'Commun', 'Peu commun', 'Rare', 'Épique', 'Légendaire'];

const QualityStars: React.FC<{ quality: number }> = React.memo(({ quality }) => {
  const color = QUALITY_COLORS[quality] ?? QUALITY_COLORS[1];
  return (
    <div style={{ display: 'flex', gap: '2px', marginTop: '2px' }}>
      {Array.from({ length: 5 }, (_, i) => (
        <span key={i} style={{ fontSize: '10px', color: i < quality ? color : 'rgba(255,255,255,0.15)', lineHeight: '1' }}>★</span>
      ))}
      <span style={{ fontSize: '10px', color, marginLeft: '3px' }}>{QUALITY_NAMES[quality] ?? ''}</span>
    </div>
  );
});
QualityStars.displayName = 'QualityStars';

const CraftingIngredients: React.FC<{ ingredients: [string, number][] }> = React.memo(({ ingredients }) => (
  <div className="tooltip-ingredients">
    {ingredients.map(([name, count]) => (
      <div className="tooltip-ingredient" key={`ingredient-${name}`}>
        <img src={name ? (getItemUrl(name) ?? 'none') : 'none'} alt={name} />
        <p>
          {count >= 1 ? `${count}x ${Items[name]?.label ?? name}`
           : count === 0 ? (Items[name]?.label ?? name)
           : `${count * 100}% ${Items[name]?.label ?? name}`}
        </p>
      </div>
    ))}
  </div>
));
CraftingIngredients.displayName = 'CraftingIngredients';

const SlotTooltip: React.ForwardRefRenderFunction<
  HTMLDivElement,
  { item: SlotWithItem; inventoryType: Inventory['type']; style: React.CSSProperties }
> = ({ item, inventoryType, style }, ref) => {
  const additionalMetadata = useAppSelector((s) => s.inventory.additionalMetadata);
  const itemData    = useMemo(() => Items[item.name], [item.name]);
  const ingredients = useMemo(() => {
    if (!item.ingredients) return null;
    return Object.entries(item.ingredients).sort(([, a], [, b]) => a - b);
  }, [item.ingredients]);

  const description = (item.metadata?.description as string | undefined) ?? itemData?.description;
  const ammoLabel   = itemData?.ammoName ? Items[itemData.ammoName]?.label : undefined;
  const isCrafting  = inventoryType === 'crafting';
  const quality     = item.metadata?.quality as number | undefined;

  const weightLabel = useMemo(() => {
    if (!item.weight || item.weight === 0) return null;
    return item.weight >= 1000 ? `${(item.weight / 1000).toFixed(2)} kg` : `${item.weight} g`;
  }, [item.weight]);

  if (!itemData) {
    return (
      <div className="tooltip-wrapper" ref={ref} style={style}>
        <div className="tooltip-header-wrapper"><p>{item.name}</p></div>
        <Divider />
        <p style={STYLE_MUTED}>Données manquantes</p>
      </div>
    );
  }

  return (
    <div className="tooltip-wrapper" ref={ref} style={style}>
      <div className="tooltip-header-wrapper">
        <p>{(item.metadata?.label as string | undefined) ?? itemData.label ?? item.name}</p>
        {isCrafting ? (
          <div className="tooltip-crafting-duration"><ClockIcon /><p>{((item.duration ?? 3000) / 1000)}s</p></div>
        ) : (
          <p style={STYLE_TYPE}>{item.metadata?.type as string | undefined}</p>
        )}
      </div>
      <Divider />

      {quality !== undefined && quality >= 1 && quality <= 5 && <QualityStars quality={quality} />}

      {description && (
        <div className="tooltip-description">
          <ReactMarkdown className="tooltip-markdown">{description}</ReactMarkdown>
        </div>
      )}

      {!isCrafting && (
        <>
          {weightLabel && <p style={STYLE_MUTED}>⚖ {weightLabel}</p>}
          {item.durability !== undefined && <p>{Locale.ui_durability}: {Math.trunc(item.durability)}</p>}
          {item.metadata?.ammo !== undefined && <p>{Locale.ui_ammo}: {item.metadata.ammo as number}</p>}
          {ammoLabel && <p>{Locale.ammo_type}: {ammoLabel}</p>}
          {item.metadata?.serial && <p>{Locale.ui_serial}: {item.metadata.serial as string}</p>}
          {Array.isArray(item.metadata?.components) && (item.metadata.components as string[]).length > 0 && (
            <p>
              {Locale.ui_components}:{' '}
              {(item.metadata.components as string[]).map((c, i, arr) =>
                i + 1 === arr.length ? Items[c]?.label : `${Items[c]?.label}, `
              )}
            </p>
          )}
          {item.metadata?.weapontint !== undefined && <p>{Locale.ui_tint}: {item.metadata.weapontint as string}</p>}
          {additionalMetadata.map((data, index) => (
            <Fragment key={`metadata-${index}`}>
              {item.metadata?.[data.metadata] !== undefined && <p>{data.value}: {item.metadata[data.metadata] as string}</p>}
            </Fragment>
          ))}
        </>
      )}

      {isCrafting && ingredients && <CraftingIngredients ingredients={ingredients} />}
    </div>
  );
};

export default React.memo(React.forwardRef(SlotTooltip));
