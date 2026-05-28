export const setClipboard = async (value: string) => {
  try {
    await navigator.clipboard.writeText(value);
  } catch {
    const body = document.body ?? document.documentElement;
    if (!body) return;

    const input = document.createElement('input');
    input.value = value;
    input.style.position = 'fixed';
    input.style.opacity = '0';

    body.appendChild(input);
    input.focus();
    input.select();

    try {
      document.execCommand('copy');
    } finally {
      body.removeChild(input);
    }
  }
};