import { Capacitor } from "@capacitor/core";
import { LocalNotifications } from "@capacitor/local-notifications";
import { Haptics, ImpactStyle, NotificationType } from "@capacitor/haptics";

type ClientMsg =
  | { type: "schedule-rest"; fireAt: number; body: string }
  | { type: "cancel-rest" }
  | { type: "show-routine"; title: string; body: string }
  | { type: "clear-routine" };

export type SWMessageEvent = { type: "rest-end" };

const isNative = Capacitor.isNativePlatform();

const supportsNotifications =
  isNative ||
  (typeof window !== "undefined" &&
    "Notification" in window &&
    "serviceWorker" in navigator);

const REST_NOTIF_ID = 1;

export function useNotifications() {
  async function ensurePermission(): Promise<boolean> {
    if (isNative) {
      const result = await LocalNotifications.requestPermissions();
      return result.display === "granted";
    }
    if (!supportsNotifications) return false;
    if (Notification.permission === "granted") return true;
    if (Notification.permission === "denied") return false;
    const result = await Notification.requestPermission();
    return result === "granted";
  }

  async function postToSW(msg: ClientMsg): Promise<void> {
    if (isNative || !supportsNotifications) return;
    try {
      const reg = await navigator.serviceWorker.ready;
      const target = reg.active ?? reg.waiting ?? reg.installing;
      target?.postMessage(msg);
    } catch {
      /* no SW available */
    }
  }

  async function scheduleRest(durationSec: number, body: string): Promise<void> {
    if (isNative) {
      await LocalNotifications.schedule({
        notifications: [
          {
            id: REST_NOTIF_ID,
            title: "¡Descanso terminado!",
            body,
            schedule: { at: new Date(Date.now() + durationSec * 1000) },
            smallIcon: "ic_launcher",
          },
        ],
      });
      return;
    }
    return postToSW({
      type: "schedule-rest",
      fireAt: Date.now() + durationSec * 1000,
      body,
    });
  }

  async function cancelRest(): Promise<void> {
    if (isNative) {
      await LocalNotifications.cancel({ notifications: [{ id: REST_NOTIF_ID }] });
      return;
    }
    return postToSW({ type: "cancel-rest" });
  }

  async function showRoutine(title: string, body: string): Promise<void> {
    if (isNative) return;
    if (Notification.permission !== "granted") return;
    return postToSW({ type: "show-routine", title, body });
  }

  async function clearRoutine(): Promise<void> {
    if (isNative) return;
    return postToSW({ type: "clear-routine" });
  }

  function onSWMessage(handler: (msg: SWMessageEvent) => void): () => void {
    if (isNative || !supportsNotifications) return () => {};
    const listener = (event: MessageEvent) => {
      const data = event.data as SWMessageEvent | undefined;
      if (data && typeof data === "object" && "type" in data) handler(data);
    };
    navigator.serviceWorker.addEventListener("message", listener);
    return () => navigator.serviceWorker.removeEventListener("message", listener);
  }

  async function hapticTick(): Promise<void> {
    if (!isNative) return;
    try {
      await Haptics.impact({ style: ImpactStyle.Light });
    } catch {
      /* haptics unavailable */
    }
  }

  async function hapticRestEnd(): Promise<void> {
    if (!isNative) return;
    try {
      await Haptics.notification({ type: NotificationType.Success });
    } catch {
      /* haptics unavailable */
    }
  }

  return {
    supported: supportsNotifications,
    ensurePermission,
    scheduleRest,
    cancelRest,
    showRoutine,
    clearRoutine,
    onSWMessage,
    hapticTick,
    hapticRestEnd,
  };
}
