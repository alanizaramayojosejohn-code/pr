type ClientMsg =
  | { type: "schedule-rest"; fireAt: number; body: string }
  | { type: "cancel-rest" }
  | { type: "show-routine"; title: string; body: string }
  | { type: "clear-routine" };

export type SWMessageEvent = { type: "rest-end" };

const supportsNotifications =
  typeof window !== "undefined" &&
  "Notification" in window &&
  "serviceWorker" in navigator;

export function useNotifications() {
  async function ensurePermission(): Promise<boolean> {
    if (!supportsNotifications) return false;
    if (Notification.permission === "granted") return true;
    if (Notification.permission === "denied") return false;
    const result = await Notification.requestPermission();
    return result === "granted";
  }

  async function postToSW(msg: ClientMsg): Promise<void> {
    if (!supportsNotifications) return;
    try {
      const reg = await navigator.serviceWorker.ready;
      const target = reg.active ?? reg.waiting ?? reg.installing;
      target?.postMessage(msg);
    } catch {
      /* no SW available */
    }
  }

  function scheduleRest(durationSec: number, body: string): Promise<void> {
    return postToSW({
      type: "schedule-rest",
      fireAt: Date.now() + durationSec * 1000,
      body,
    });
  }

  function cancelRest(): Promise<void> {
    return postToSW({ type: "cancel-rest" });
  }

  function showRoutine(title: string, body: string): Promise<void> {
    if (Notification.permission !== "granted") return Promise.resolve();
    return postToSW({ type: "show-routine", title, body });
  }

  function clearRoutine(): Promise<void> {
    return postToSW({ type: "clear-routine" });
  }

  function onSWMessage(handler: (msg: SWMessageEvent) => void): () => void {
    if (!supportsNotifications) return () => {};
    const listener = (event: MessageEvent) => {
      const data = event.data as SWMessageEvent | undefined;
      if (data && typeof data === "object" && "type" in data) handler(data);
    };
    navigator.serviceWorker.addEventListener("message", listener);
    return () => navigator.serviceWorker.removeEventListener("message", listener);
  }

  return {
    supported: supportsNotifications,
    ensurePermission,
    scheduleRest,
    cancelRest,
    showRoutine,
    clearRoutine,
    onSWMessage,
  };
}
