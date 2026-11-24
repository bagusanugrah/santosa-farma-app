export function loadSnapScript(clientKey: string, isProduction: boolean): Promise<any> {
  return new Promise((resolve, reject) => {
    if (typeof window === 'undefined') return resolve(null);
    if ((window as any).snap) return resolve((window as any).snap);

    const snapScriptUrl = isProduction
      ? 'https://app.midtrans.com/snap/snap.js'
      : 'https://app.sandbox.midtrans.com/snap/snap.js';
    const scriptId = 'midtrans-snap-script';

    let script = document.getElementById(scriptId) as HTMLScriptElement;
    if (script) {
      if ((window as any).snap) {
        return resolve((window as any).snap);
      }
      script.addEventListener('load', () => resolve((window as any).snap));
      script.addEventListener('error', (e) => reject(e));
      return;
    }

    script = document.createElement('script');
    script.id = scriptId;
    script.src = snapScriptUrl;
    if (clientKey) {
      script.setAttribute('data-client-key', clientKey);
    }
    script.async = true;
    script.onload = () => resolve((window as any).snap);
    script.onerror = (e) => reject(e);
    document.body.appendChild(script);
  });
}
