// hooks/useClothingImage.ts
// Lazy-charge clothingData.json une seule fois au montage.
// Fournit getClothingImageUrl() utilisable dans ClothingSlot et les tooltips.

import { useState, useEffect, useRef, useCallback } from 'react';

// ── Types ────────────────────────────────────────────────────────────────────

interface CompactClothingData {
  collections: string[];
  /** item_name → [colIdx, localIndex, componentNum, isProp(0|1), texCount, gender(0=m,1=f)] */
  items: Record<string, [number, number, number, number, number, number]>;
}

interface ClothingImageInfo {
  model:        string;
  collection:   string;
  localIndex:   number;
  componentNum: number;
  isProp:       boolean;
  texCount:     number;
}

// ── Singleton store (partagé entre tous les composants) ──────────────────────

let _data:    CompactClothingData | null = null;
let _promise: Promise<CompactClothingData> | null = null;

const MODELS = ['mp_m_freemode_01', 'mp_f_freemode_01'] as const;
const BASE_URL =
  'https://raw.githubusercontent.com/Colbss/FiveM-ClothingData/refs/heads/master/images';

function loadData(): Promise<CompactClothingData> {
  if (_data) return Promise.resolve(_data);
  if (_promise) return _promise;

  _promise = fetch('./clothingData.json')
    .then((r) => {
      if (!r.ok) throw new Error(`HTTP ${r.status}`);
      return r.json() as Promise<CompactClothingData>;
    })
    .then((d) => {
      _data = d;
      return d;
    })
    .catch((err) => {
      _promise = null; // permettre un retry
      console.error('[ClothingImage] Failed to load clothingData.json:', err);
      throw err;
    });

  return _promise;
}

// ── Helpers purs (utilisables sans le hook si data est déjà chargée) ─────────

export function resolveClothingImageInfo(
  itemName: string,
  data: CompactClothingData
): ClothingImageInfo | null {
  const entry = data.items[itemName];
  if (!entry) return null;
  const [colIdx, localIndex, componentNum, isPropNum, texCount, genderIdx] = entry;
  return {
    model:        MODELS[genderIdx] ?? MODELS[0],
    collection:   data.collections[colIdx] ?? 'base',
    localIndex,
    componentNum,
    isProp:       isPropNum === 1,
    texCount,
  };
}

export function buildClothingImageUrl(
  info: ClothingImageInfo,
  texture = 0
): string {
  const prefix = info.isProp ? 'P' : 'D';
  const tex    = Math.max(0, Math.min(texture, info.texCount - 1));
  return `${BASE_URL}/${info.model}/${info.collection}/${prefix}_${info.componentNum}_${info.localIndex}_${tex}.webp`;
}

/**
 * Retourne l'URL directement si les données sont déjà chargées.
 * Util pour les contextes synchrones (ex: getItemUrl override).
 */
export function getClothingImageUrlSync(
  itemName: string,
  texture = 0
): string | undefined {
  if (!_data) return undefined;
  const info = resolveClothingImageInfo(itemName, _data);
  if (!info) return undefined;
  return buildClothingImageUrl(info, texture);
}

/**
 * Retourne toutes les URLs de textures d'un item (pour un sélecteur de texture).
 */
export function getAllTextureUrls(itemName: string): string[] {
  if (!_data) return [];
  const info = resolveClothingImageInfo(itemName, _data);
  if (!info) return [];
  return Array.from({ length: info.texCount }, (_, i) =>
    buildClothingImageUrl(info, i)
  );
}

// ── Hook React ────────────────────────────────────────────────────────────────

interface UseClothingImageReturn {
  /** true une fois les données chargées */
  ready: boolean;
  /** Retourne l'URL de l'image pour un item + texture donnés */
  getUrl: (itemName: string, texture?: number) => string | undefined;
  /** Retourne toutes les URLs de textures */
  getAllUrls: (itemName: string) => string[];
}

export function useClothingImage(): UseClothingImageReturn {
  const [ready, setReady] = useState(_data !== null);
  const dataRef = useRef<CompactClothingData | null>(_data);

  useEffect(() => {
    if (dataRef.current) return;
    loadData()
      .then((d) => {
        dataRef.current = d;
        setReady(true);
      })
      .catch(() => {
        // erreur déjà loguée dans loadData
      });
  }, []);

  const getUrl = useCallback((itemName: string, texture = 0): string | undefined => {
    if (!dataRef.current) return undefined;
    const info = resolveClothingImageInfo(itemName, dataRef.current);
    if (!info) return undefined;
    return buildClothingImageUrl(info, texture);
  }, []);

  const getAllUrls = useCallback((itemName: string): string[] => {
    if (!dataRef.current) return [];
    const info = resolveClothingImageInfo(itemName, dataRef.current);
    if (!info) return [];
    return Array.from({ length: info.texCount }, (_, i) =>
      buildClothingImageUrl(info, i)
    );
  }, []);

  return { ready, getUrl, getAllUrls };
}
