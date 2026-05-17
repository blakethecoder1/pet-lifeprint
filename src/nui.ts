declare global {
  interface Window {
    GetParentResourceName?: () => string;
  }
}

type NuiCallback<T = unknown> = (data: T) => void;

const isInGame = typeof window.GetParentResourceName === 'function';
const resourceName = isInGame ? window.GetParentResourceName!() : 'bldr-resource';

export const isDebug = !isInGame;

if (isDebug) {
  document.body.style.background = 'rgba(0, 0, 0, 0.6)';
}

export const NUI = {
  async request<T = unknown>(event: string, data: Record<string, unknown> = {}, mockData?: T): Promise<T> {
    if (!isInGame && mockData !== undefined) {
      console.log(`[NUI Dev] ${event}:`, mockData);
      return mockData;
    }
    if (!isInGame) {
      console.warn(`[NUI Dev] No mock for '${event}'. Pass mockData as 3rd arg.`);
      return {} as T;
    }
    const response = await fetch(`https://${resourceName}/${event}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data),
    });
    return response.json();
  },

  on<T = unknown>(action: string, callback: NuiCallback<T>): () => void {
    const handler = (e: MessageEvent) => {
      let payload: any = e.data;
      if (typeof payload === 'string') { try { payload = JSON.parse(payload); } catch {} }
      const { action: eventAction, data } = payload ?? {};
      if (eventAction === action) callback((data ?? {}) as T);
    };
    window.addEventListener('message', handler);
    return () => window.removeEventListener('message', handler);
  },

  close(mockData: { success: boolean } = { success: true }): Promise<{ success: boolean }> {
    return this.request('close', {}, mockData);
  },

  emit(action: string, data: unknown): void {
    window.dispatchEvent(new MessageEvent('message', { data: { action, data } }));
  },
};

if (isDebug) {
  setTimeout(() => NUI.emit('open', {}), 100);
}
