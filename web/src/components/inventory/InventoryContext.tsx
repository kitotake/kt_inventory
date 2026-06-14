// components/inventory/InventoryContext.tsx
// v8 :
//   ✓ Fix input rename : ajout de stopPropagation sur onChange, onKeyDown,
//     onKeyUp et onMouseDown pour empêcher le Menu de capturer les événements
//   ✓ NOUVEAU : section "Craft" (temps de fabrication + ingrédients manquants
//     détaillés) affichée quand contextMenu.inventoryType === 'crafting'
//   ✓ NOUVEAU : section "Achat" (raison d'indisponibilité : stock / solde /
//     grade) affichée quand contextMenu.inventoryType === 'shop'
//   ✓ Les sections existantes (renommer, use/give/drop, metadata...) sont
//     masquées pour shop/crafting — ces inventaires ne sont pas "possédés"
//     par le joueur et n'ont donc pas de metadata personnalisée

import { onUse } from '../../dnd/onUse';
import { onGive } from '../../dnd/onGive';
import { onDrop } from '../../dnd/onDrop';
import { Items } from '../../store/items';
import { fetchNui } from '../../utils/fetchNui';
import { isEnvBrowser } from '../../utils/misc';
import { Locale } from '../../store/locale';
import { isSlotWithItem, checkCraftItem, checkPurchaseItem } from '../../helpers';
import { setClipboard } from '../../utils/setClipboard';
import { useAppDispatch, useAppSelector } from '../../store';
import { refreshSlots } from '../../store/inventory';
import { setSlotPending, selectPendingSlots } from '../../store/itemMeta';
import React, { useEffect, useMemo, useState } from 'react';
import { Menu, MenuItem } from '../utils/menu/Menu';
import Divider from '../utils/Divider';
import { InventoryType, SlotWithItem } from '../../typings';

interface DataProps {
  action:     string;
  component?: string;
  slot?:      number;
  serial?:    string;
  id?:        number;
}

interface Button { label: string; index: number; group?: string; }
interface Group  { groupName: string | null; buttons: ButtonWithIndex[]; }
interface ButtonWithIndex extends Button { index: number; }

const STYLE_SECTION: React.CSSProperties = {
  padding: '6px 10px',
  display: 'flex',
  flexDirection: 'column',
  gap: '4px',
};

const STYLE_ROW: React.CSSProperties = {
  display: 'flex',
  justifyContent: 'space-between',
  alignItems: 'center',
  gap: '8px',
};

const STYLE_LABEL: React.CSSProperties = {
  fontSize: '11px',
  color: 'rgba(180,182,190,0.55)',
  whiteSpace: 'nowrap',
};

const STYLE_VALUE: React.CSSProperties = {
  fontSize: '11px',
  color: '#c8cad0',
  textAlign: 'right',
  overflow: 'hidden',
  textOverflow: 'ellipsis',
};

const STYLE_RENAME_INPUT: React.CSSProperties = {
  flex: 1,
  background: 'rgba(10,11,18,0.7)',
  border: '1px solid rgba(255,255,255,0.08)',
  borderRadius: '3px',
  color: '#c8cad0',
  fontSize: '11px',
  padding: '4px 6px',
  outline: 'none',
  fontFamily: 'inherit',
};

const STYLE_TOGGLE: React.CSSProperties = {
  fontSize: '11px',
  color: 'rgba(147,197,253,0.85)',
  cursor: 'pointer',
  textAlign: 'center',
  padding: '4px 0',
  userSelect: 'none',
};

const STYLE_TOGGLE_ROW: React.CSSProperties = {
  display: 'flex',
  justifyContent: 'space-between',
  alignItems: 'center',
  padding: '4px 10px',
};

const STYLE_TOGGLE_BTN: React.CSSProperties = {
  fontSize: '11px',
  color: 'rgba(147,197,253,0.85)',
  cursor: 'pointer',
  userSelect: 'none',
  background: 'rgba(59,130,246,0.10)',
  border: '1px solid rgba(59,130,246,0.25)',
  borderRadius: '3px',
  padding: '2px 8px',
};

// ── Helpers ───────────────────────────────────────────────────────────────

const formatWeight = (weight?: number): string => {
  if (!weight || weight <= 0) return '—';
  return weight >= 1000
    ? `${(weight / 1000).toLocaleString('en-us', { minimumFractionDigits: 2 })} kg`
    : `${weight.toLocaleString('en-us', { minimumFractionDigits: 0 })} g`;
};

const formatOrigin = (origin?: string[]): string => {
  if (!origin || origin.length === 0) return 'Inconnue';
  return origin.join(', ');
};

const formatAmmoPercent = (ammo?: number, maxAmmo?: number): string | null => {
  if (ammo === undefined) return null;
  if (!maxAmmo || maxAmmo <= 0) return `${ammo}`;
  const pct = Math.max(0, Math.min(100, Math.round((ammo / maxAmmo) * 100)));
  return `${pct}%`;
};

const formatCraftTime = (seconds: number): string => {
  if (seconds < 60) return `${seconds}s`;
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  return s > 0 ? `${m}m ${s}s` : `${m}m`;
};

const PURCHASE_REASON_LABEL: Record<string, string> = {
  out_of_stock: 'Stock épuisé',
  grade:        'Accès / grade insuffisant',
  balance:      'Solde insuffisant',
};

const CURRENCY_LABEL = (currency?: string): string => {
  if (!currency || currency === 'money')       return Locale.$ ?? '$';
  if (currency === 'black_money')              return Locale.ui_dirty_money ?? 'argent sale';
  return Items[currency]?.label ?? currency;
};

// ── Section Craft ────────────────────────────────────────────────────────

const CraftSection: React.FC<{ item: SlotWithItem }> = ({ item }) => {
  const check = useMemo(
    () => checkCraftItem(item, InventoryType.CRAFTING),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [item.slot, item.name, JSON.stringify(item.ingredients)]
  );

  const hasIngredients = item.ingredients && Object.keys(item.ingredients).length > 0;
  const craftTime      = item.craftTime;

  if (!hasIngredients && craftTime === undefined) return null;

  return (
    <>
      <div style={STYLE_SECTION} onClick={(e) => e.stopPropagation()}>
        {craftTime !== undefined && (
          <div style={STYLE_ROW}>
            <span style={STYLE_LABEL}>Temps de fabrication</span>
            <span style={STYLE_VALUE}>{formatCraftTime(craftTime)}</span>
          </div>
        )}

        {hasIngredients && (
          <div style={STYLE_ROW}>
            <span style={STYLE_LABEL}>Statut</span>
            <span style={{ ...STYLE_VALUE, color: check.ok ? '#22c55e' : '#ef4444', fontWeight: 600 }}>
              {check.ok ? 'Fabriquable' : 'Ingrédients manquants'}
            </span>
          </div>
        )}

        {hasIngredients && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '3px', marginTop: '2px' }}>
            <span style={{ ...STYLE_LABEL, marginBottom: '1px' }}>Ingrédients requis</span>
            {Object.entries(item.ingredients!).map(([name, need]) => {
              const missingEntry = check.missing.find((m) => m.name === name);
              const label = Items[name]?.label ?? name;
              const ok    = !missingEntry;

              // Affichage : pour need < 1 (seuil durabilité legacy), pas de quantité numérique
              const qtyDisplay = need < 1
                ? (ok ? 'OK' : 'requis')
                : `${missingEntry ? missingEntry.have : need}/${need}`;

              return (
                <div key={name} style={STYLE_ROW}>
                  <span style={{ ...STYLE_VALUE, textAlign: 'left', color: ok ? '#c8cad0' : 'rgba(252,165,165,0.95)' }}>
                    {label}
                  </span>
                  <span style={{ ...STYLE_VALUE, fontWeight: 600, color: ok ? '#22c55e' : 'rgba(252,165,165,0.95)' }}>
                    {qtyDisplay}
                  </span>
                </div>
              );
            })}
          </div>
        )}
      </div>
      <Divider />
    </>
  );
};

// ── Section Achat (shop) ────────────────────────────────────────────────

const PurchaseSection: React.FC<{
  item: SlotWithItem;
  inventoryGroups: Record<string, number> | null;
}> = ({ item, inventoryGroups }) => {
  const check = useMemo(
    () => checkPurchaseItem(item, { type: InventoryType.SHOP, groups: inventoryGroups ?? undefined }),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [item.slot, item.name, item.count, item.price, item.currency, item.grade, JSON.stringify(inventoryGroups)]
  );

  if (!item.price) return null;

  return (
    <>
      <div style={STYLE_SECTION} onClick={(e) => e.stopPropagation()}>
        <div style={STYLE_ROW}>
          <span style={STYLE_LABEL}>Prix</span>
          <span style={STYLE_VALUE}>{item.price.toLocaleString('en-us')} {CURRENCY_LABEL(item.currency)}</span>
        </div>

        {item.count !== undefined && (
          <div style={STYLE_ROW}>
            <span style={STYLE_LABEL}>Stock</span>
            <span style={{ ...STYLE_VALUE, color: item.count === 0 ? 'rgba(252,165,165,0.95)' : undefined }}>
              {item.count.toLocaleString('en-us')}
            </span>
          </div>
        )}

        {item.grade !== undefined && (
          <div style={STYLE_ROW}>
            <span style={STYLE_LABEL}>Accès requis</span>
            <span style={STYLE_VALUE}>
              {Array.isArray(item.grade) ? `Grade(s) ${item.grade.join(', ')}` : `Grade ≥ ${item.grade}`}
            </span>
          </div>
        )}

        <div style={STYLE_ROW}>
          <span style={STYLE_LABEL}>Statut</span>
          <span style={{ ...STYLE_VALUE, color: check.ok ? '#22c55e' : '#ef4444', fontWeight: 600 }}>
            {check.ok ? 'Achetable' : (check.reason ? PURCHASE_REASON_LABEL[check.reason] : 'Indisponible')}
          </span>
        </div>
      </div>
      <Divider />
    </>
  );
};

// ── InventoryContext ────────────────────────────────────────────────────

const InventoryContext: React.FC = () => {
  const dispatch    = useAppDispatch();
  const contextMenu = useAppSelector((state) => state.contextMenu);
  const pendingSlots = useAppSelector(selectPendingSlots);
  const item        = contextMenu.item;
  const ctxInventoryType   = contextMenu.inventoryType;
  const ctxInventoryGroups = contextMenu.inventoryGroups;

  const [renameValue, setRenameValue]   = useState('');
  const [showMetadata, setShowMetadata] = useState(false);
  const [showMoreVars, setShowMoreVars] = useState(false);
  const [showMetaData, setShowMetaData] = useState(false);

  // Réinitialise les sections repliables et le champ de rename à chaque
  // ouverture sur un nouvel item
  useEffect(() => {
    if (!item) return;
    const currentLabel = (item.metadata?.label as string | undefined)
      ?? Items[item.name]?.label
      ?? item.name;
    setRenameValue(currentLabel);
    setShowMetadata(false);
    setShowMoreVars(false);
    setShowMetaData(false);
  }, [item]);

  const isPending = item ? Boolean(pendingSlots[item.slot]) : false;

  const handleClick = (data: DataProps) => {
    if (!item) return;
    switch (data?.action) {
      case 'use':        onUse({ name: item.name, slot: item.slot }); break;
      case 'give':       onGive({ name: item.name, slot: item.slot }); break;
      case 'drop':       isSlotWithItem(item) && onDrop({ item, inventory: 'player' }); break;
      case 'remove':     fetchNui('removeComponent', { component: data?.component, slot: data?.slot }); break;
      case 'removeAmmo': fetchNui('removeAmmo', item.slot); break;
      case 'copy':       setClipboard(data.serial || ''); break;
      case 'custom':     fetchNui('useButton', { id: (data?.id || 0) + 1, slot: item.slot }); break;
    }
  };

  // ── Renommer ────────────────────────────────────────────────────────────
  const applyLocalRename = (newLabel: string) => {
    if (!item) return;
    const trimmed = newLabel.trim();
    const defaultLabel = Items[item.name]?.label ?? item.name;

    const nextMetadata = { ...item.metadata };
    if (trimmed === '' || trimmed === defaultLabel) {
      delete nextMetadata.label;
    } else {
      nextMetadata.label = trimmed;
    }

    dispatch(refreshSlots({
      items: {
        item: { ...item, metadata: nextMetadata },
      },
    }));
  };

  const handleRename = () => {
    if (!item) return;
    const trimmed = renameValue.trim();
    const currentLabel = (item.metadata?.label as string | undefined)
      ?? Items[item.name]?.label
      ?? item.name;

    if (trimmed === '' || trimmed === currentLabel) return;

    // Optimiste : on applique localement tout de suite
    applyLocalRename(trimmed);

    if (isEnvBrowser()) return;

    fetchNui('renameItem', { slot: item.slot, label: trimmed }).catch((err) => {
      console.error('[InventoryContext] renameItem error:', err);
    });
  };

  const handleRenameKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter') { e.preventDefault(); handleRename(); }
  };

  // ── Nettoyer ────────────────────────────────────────────────────────────
  const handleClean = () => {
    if (!item) return;

    const defaultLabel = Items[item.name]?.label ?? item.name;
    const nextMetadata = { ...item.metadata };
    delete nextMetadata.label;
    delete nextMetadata.description;

    dispatch(refreshSlots({
      items: { item: { ...item, metadata: nextMetadata } },
    }));
    setRenameValue(defaultLabel);

    if (isEnvBrowser()) return;

    dispatch(setSlotPending({ slot: item.slot, pending: true }));
    fetchNui('cleanItem', { slot: item.slot })
      .catch((err) => console.error('[InventoryContext] cleanItem error:', err))
      .finally(() => dispatch(setSlotPending({ slot: item.slot, pending: false })));
  };

  // ── Poser au sol / Ramasser ─────────────────────────────────────────────
  const handleToggleGround = () => {
    if (!item) return;
    const nextOnGround = !(item.metadata?.onGround === true);

    if (isEnvBrowser()) {
      // Toggle local pour debug visuel — aucun backend pour confirmer
      const nextMetadata = { ...item.metadata, onGround: nextOnGround };
      dispatch(refreshSlots({
        items: { item: { ...item, metadata: nextMetadata } },
      }));
      return;
    }

    dispatch(setSlotPending({ slot: item.slot, pending: true }));
    fetchNui('placeOnGround', { slot: item.slot, onGround: nextOnGround })
      .then((res: any) => {
        if (res?.ok !== false) {
          const nextMetadata = { ...item.metadata, onGround: nextOnGround };
          dispatch(refreshSlots({
            items: { item: { ...item, metadata: nextMetadata } },
          }));
        }
      })
      .catch((err) => console.error('[InventoryContext] placeOnGround error:', err))
      .finally(() => dispatch(setSlotPending({ slot: item.slot, pending: false })));
  };

  // ── Actualiser les variables ───────────────────────────────────────────
  const handleRefreshMeta = () => {
    if (!item) return;

    if (isEnvBrowser()) {
      console.log('[InventoryContext] refreshItemMetadata (browser, no-op):', item.slot);
      return;
    }

    dispatch(setSlotPending({ slot: item.slot, pending: true }));
    fetchNui('refreshItemMetadata', { slot: item.slot })
      .catch((err) => console.error('[InventoryContext] refreshItemMetadata error:', err))
      .finally(() => dispatch(setSlotPending({ slot: item.slot, pending: false })));
  };

  const groupButtons = (buttons: any): Group[] =>
    buttons.reduce((groups: Group[], button: Button, index: number) => {
      if (button.group) {
        const groupIndex = groups.findIndex((g) => g.groupName === button.group);
        if (groupIndex !== -1) groups[groupIndex].buttons.push({ ...button, index });
        else groups.push({ groupName: button.group, buttons: [{ ...button, index }] });
      } else {
        groups.push({ groupName: null, buttons: [{ ...button, index }] });
      }
      return groups;
    }, []);

  if (!item) {
    return <Menu><MenuItem onClick={() => {}} label="" disabled /></Menu>;
  }

  // ── Branches shop / crafting : menu réduit, sections dédiées uniquement ──
  // Ces inventaires ne sont pas "possédés" par le joueur : pas de rename,
  // pas de metadata personnalisée, pas d'actions use/give/drop.
  if (ctxInventoryType === InventoryType.CRAFTING) {
    return (
      <Menu>
        <div style={{ ...STYLE_SECTION, paddingBottom: 0 }} onClick={(e) => e.stopPropagation()}>
          <div style={STYLE_ROW}>
            <span style={{ ...STYLE_LABEL, fontSize: '12px', fontWeight: 600, color: '#c8cad0' }}>
              {item.metadata?.label ? (item.metadata.label as string) : Items[item.name]?.label ?? item.name}
            </span>
          </div>
        </div>
        <Divider />
        <CraftSection item={item} />
        <div style={STYLE_SECTION} onClick={(e) => e.stopPropagation()}>
          <div style={STYLE_ROW}>
            <span style={STYLE_LABEL}>Poids</span>
            <span style={STYLE_VALUE}>{formatWeight(item.weight)}</span>
          </div>
        </div>
      </Menu>
    );
  }

  if (ctxInventoryType === InventoryType.SHOP) {
    return (
      <Menu>
        <div style={{ ...STYLE_SECTION, paddingBottom: 0 }} onClick={(e) => e.stopPropagation()}>
          <div style={STYLE_ROW}>
            <span style={{ ...STYLE_LABEL, fontSize: '12px', fontWeight: 600, color: '#c8cad0' }}>
              {item.metadata?.label ? (item.metadata.label as string) : Items[item.name]?.label ?? item.name}
            </span>
          </div>
        </div>
        <Divider />
        <PurchaseSection item={item} inventoryGroups={ctxInventoryGroups ?? null} />
        <div style={STYLE_SECTION} onClick={(e) => e.stopPropagation()}>
          <div style={STYLE_ROW}>
            <span style={STYLE_LABEL}>Poids</span>
            <span style={STYLE_VALUE}>{formatWeight(item.weight)}</span>
          </div>
        </div>
      </Menu>
    );
  }

  // ── Branche par défaut : inventaire joueur (comportement existant) ───────

  const itemData      = Items[item.name];
  const ammoPercent   = formatAmmoPercent(item.metadata?.ammo, itemData?.maxAmmo);
  const onGround      = item.metadata?.onGround === true;
  const componentList = Array.isArray(item.metadata?.components)
    ? (item.metadata?.components as string[])
    : null;

  return (
    <Menu>
      {/* ── Renommer ───────────────────────────────────────────────────── */}
      <div style={STYLE_SECTION} onClick={(e) => e.stopPropagation()}>
        <div style={STYLE_ROW}>
          <input
            style={STYLE_RENAME_INPUT}
            type="text"
            value={renameValue}
            placeholder={Items[item.name]?.label ?? item.name}
            disabled={isPending}
            onChange={(e) => {
              e.stopPropagation();
              setRenameValue(e.target.value);
            }}
            onKeyDown={(e) => {
              e.stopPropagation();
              handleRenameKeyDown(e);
            }}
            onKeyUp={(e) => e.stopPropagation()}
            onMouseDown={(e) => e.stopPropagation()}
            onBlur={handleRename}
          />
        </div>
      </div>

      <Divider />

      {/* ── Actions principales ──────────────────────────────────────────── */}
      <MenuItem onClick={() => handleClick({ action: 'use' })}  label={Locale.ui_use  || 'Utiliser'} />
      <MenuItem onClick={() => handleClick({ action: 'give' })} label={Locale.ui_give || 'Donner'} />
      <MenuItem onClick={() => handleClick({ action: 'drop' })} label={Locale.ui_drop || 'Jeter'} />
      <MenuItem onClick={handleToggleGround} label={onGround ? 'Ramasser' : 'Poser au sol'} disabled={isPending} />
      <MenuItem onClick={handleClean} label="Nettoyer" disabled={isPending} />

      {item.metadata?.ammo > 0 && (
        <MenuItem onClick={() => handleClick({ action: 'removeAmmo' })} label={Locale.ui_remove_ammo} />
      )}
      {item.metadata?.serial && (
        <MenuItem onClick={() => handleClick({ action: 'copy', serial: item.metadata?.serial })} label={Locale.ui_copy} />
      )}

      {/* ── Accessoires (anciennement "components") ─────────────────────── */}
      {componentList && componentList.length > 0 && (
        <Menu label="Accessoires">
          {componentList.map((component: string, index: number) => (
            <MenuItem key={index} onClick={() => handleClick({ action: 'remove', component, slot: item.slot })} label={Items[component]?.label || ''} />
          ))}
        </Menu>
      )}

      {/* ── Boutons custom ────────────────────────────────────────────────── */}
      {(Items[item.name]?.buttons?.length || 0) > 0 && (
        <>
          {groupButtons(Items[item.name]?.buttons).map((group: Group, index: number) => (
            <React.Fragment key={index}>
              {group.groupName ? (
                <Menu label={group.groupName}>
                  {group.buttons.map((button: Button) => (
                    <MenuItem key={button.index} onClick={() => handleClick({ action: 'custom', id: button.index })} label={button.label} />
                  ))}
                </Menu>
              ) : (
                group.buttons.map((button: Button) => (
                  <MenuItem key={button.index} onClick={() => handleClick({ action: 'custom', id: button.index })} label={button.label} />
                ))
              )}
            </React.Fragment>
          ))}
        </>
      )}

      <Divider />

      {/* ── Toggle section metadata ──────────────────────────────────────── */}
      <div style={STYLE_TOGGLE_ROW} onClick={(e) => e.stopPropagation()}>
        <span style={STYLE_LABEL}>Informations</span>
        <span
          style={STYLE_TOGGLE_BTN}
          onClick={() => {
            const next = !showMetadata;
            setShowMetadata(next);
            if (!next) setShowMoreVars(false); // referme aussi les variables avancées
          }}
        >
          {showMetadata ? 'Voir -' : 'Voir +'}
        </span>
      </div>

      {/* ── Infos lecture-seule (poids, durabilité, munitions, sol) ─────────── */}
      {showMetadata && (
        <div style={STYLE_SECTION} onClick={(e) => e.stopPropagation()}>
          <div style={STYLE_ROW}>
            <span style={STYLE_LABEL}>Poids</span>
            <span style={STYLE_VALUE}>{formatWeight(item.weight)}</span>
          </div>

          {item.durability !== undefined && (
            <div style={STYLE_ROW}>
              <span style={STYLE_LABEL}>{Locale.ui_durability ?? 'Durabilité'}</span>
              <span style={STYLE_VALUE}>{Math.trunc(item.durability)}%</span>
            </div>
          )}

          {ammoPercent !== null && (
            <div style={STYLE_ROW}>
              <span style={STYLE_LABEL}>Munitions</span>
              <span style={STYLE_VALUE}>{ammoPercent}</span>
            </div>
          )}

          <div style={STYLE_ROW}>
            <span style={STYLE_LABEL}>Posée au sol</span>
            <span style={STYLE_VALUE}>{onGround ? 'Oui' : 'Non'}</span>
          </div>

          {/* ── Voir plus de variables ──────────────────────────────────── */}
          <div
            style={STYLE_TOGGLE}
            onClick={(e) => { e.stopPropagation(); setShowMoreVars((v) => !v); }}
          >
            {showMoreVars ? 'Voir moins de variables' : 'Voir + de variables'}
          </div>

          {showMoreVars && (
            <>
              <div style={STYLE_ROW}>
                <span style={STYLE_LABEL}>Nom</span>
                <span style={STYLE_VALUE}>{item.name}</span>
              </div>
              <div style={STYLE_ROW}>
                <span style={STYLE_LABEL}>Date de création</span>
                <span style={STYLE_VALUE}>{item.metadata?.createdAt ?? 'Inconnue'}</span>
              </div>
              <div style={STYLE_ROW}>
                <span style={STYLE_LABEL}>Provenance</span>
                <span style={STYLE_VALUE}>{formatOrigin(item.metadata?.origin)}</span>
              </div>

              <div style={STYLE_ROW}>
                <span style={STYLE_LABEL}>ID</span>
                <span style={STYLE_VALUE}>{item.metadata?.uniqueId ?? '—'}</span>
              </div>

              <div
                style={{ ...STYLE_TOGGLE, marginTop: '2px' }}
                onClick={(e) => { e.stopPropagation(); handleRefreshMeta(); }}
              >
                {isPending ? 'Actualisation…' : 'Actualiser les variables'}
              </div>
            </>
          )}

          {/* ── Voir + de MetaData (debug brut) ───────────────────────────── */}
          <div
            style={STYLE_TOGGLE}
            onClick={(e) => {
              e.stopPropagation();
              setShowMetaData((v) => !v);
            }}
          >
            {showMetaData ? 'Voir moins de MetaData' : 'Voir + de MetaData'}
          </div>

          {showMetaData && (
            <>
              {Object.entries(item.metadata || {}).map(([key, value]) => (
                <div key={key} style={STYLE_ROW}>
                  <span style={STYLE_LABEL}>{key}</span>
                  <span style={STYLE_VALUE}>
                    {typeof value === 'object'
                      ? JSON.stringify(value)
                      : String(value)}
                  </span>
                </div>
              ))}
            </>
          )}
        </div>
      )}
    </Menu>
  );
};

export default InventoryContext;