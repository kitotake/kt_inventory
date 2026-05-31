// utils/fetchNui.ts
import { isEnvBrowser } from './misc';

const resourceName = (window as any).GetParentResourceName
  ? (window as any).GetParentResourceName()
  : 'kt_inventory';

export async function fetchNui<T>(eventName: string, data?: unknown): Promise<T> {
  if (isEnvBrowser()) return undefined as any;

  const resp = await fetch(`https://${resourceName}/${eventName}`, {
    method: 'post',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data),
  });

  const text = await resp.text();
  if (!text || text.trim() === '') return undefined as any;

  try {
    return JSON.parse(text) as T;
  } catch {
    return text as unknown as T;
  }
}
