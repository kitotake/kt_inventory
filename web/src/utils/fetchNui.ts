import { isEnvBrowser } from './misc';

const resourceName = (window as any).GetParentResourceName
  ? (window as any).GetParentResourceName()
  : 'kt_inventory';

export async function fetchNui<T>(eventName: string, data?: unknown): Promise<T> {
  if (isEnvBrowser()) return undefined as any;

  const resp = await fetch(`https://${resourceName}/${eventName}`, {
    method: 'post',
    headers: {
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: JSON.stringify(data),
  });

  // FiveM NUI callbacks can return bare values (1, true) or objects.
  // Parse safely so non-JSON responses don't crash the UI.
  const text = await resp.text();

  if (!text || text.trim() === '') return undefined as any;

  try {
    return JSON.parse(text) as T;
  } catch {
    // Returned a bare non-JSON value (e.g. plain "1") — treat as success
    return text as unknown as T;
  }
}