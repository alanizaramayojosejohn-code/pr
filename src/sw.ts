/// <reference lib="webworker" />
import { precacheAndRoute, cleanupOutdatedCaches } from "workbox-precaching";

declare const self: ServiceWorkerGlobalScope & {
  __WB_MANIFEST: Array<{ url: string; revision: string | null }>;
};

cleanupOutdatedCaches();
precacheAndRoute(self.__WB_MANIFEST);

self.addEventListener("install", () => {
  void self.skipWaiting();
});
self.addEventListener("activate", (event) => {
  event.waitUntil(self.clients.claim());
});

const ICON = "/pwa-192x192.png";
const BADGE = "/pwa-64x64.png";
const TAG_REST = "pr-rest";
const TAG_ROUTINE = "pr-routine";

let restTimerId: number | null = null;
let restFireAt = 0;

interface ScheduleRestMsg {
  type: "schedule-rest";
  fireAt: number;
  body: string;
}
interface CancelRestMsg {
  type: "cancel-rest";
}
interface ShowRoutineMsg {
  type: "show-routine";
  title: string;
  body: string;
}
interface ClearRoutineMsg {
  type: "clear-routine";
}
type ClientMsg = ScheduleRestMsg | CancelRestMsg | ShowRoutineMsg | ClearRoutineMsg;

function clearRestTimer() {
  if (restTimerId !== null) {
    clearTimeout(restTimerId);
    restTimerId = null;
  }
  restFireAt = 0;
}

async function broadcastRestEnded() {
  const clients = await self.clients.matchAll({
    type: "window",
    includeUncontrolled: true,
  });
  for (const c of clients) c.postMessage({ type: "rest-end" });
}

function fireRestEnded(body: string) {
  clearRestTimer();
  void broadcastRestEnded();
  void self.registration.showNotification("¡Descanso terminado!", {
    body,
    tag: TAG_REST,
    renotify: true,
    requireInteraction: false,
    icon: ICON,
    badge: BADGE,
    vibrate: [200, 100, 200],
    data: { type: "rest-end" },
  } as NotificationOptions);
}

self.addEventListener("message", (event: ExtendableMessageEvent) => {
  const msg = event.data as ClientMsg | undefined;
  if (!msg || typeof msg !== "object" || !("type" in msg)) return;

  if (msg.type === "schedule-rest") {
    clearRestTimer();
    restFireAt = msg.fireAt;
    const delay = Math.max(0, msg.fireAt - Date.now());
    restTimerId = self.setTimeout(() => fireRestEnded(msg.body), delay) as unknown as number;
    return;
  }

  if (msg.type === "cancel-rest") {
    clearRestTimer();
    void self.registration.getNotifications({ tag: TAG_REST }).then((ns) => {
      for (const n of ns) n.close();
    });
    return;
  }

  if (msg.type === "show-routine") {
    void self.registration.showNotification(msg.title, {
      body: msg.body,
      tag: TAG_ROUTINE,
      silent: true,
      requireInteraction: true,
      icon: ICON,
      badge: BADGE,
      data: { type: "routine-active" },
    } as NotificationOptions);
    return;
  }

  if (msg.type === "clear-routine") {
    void self.registration.getNotifications({ tag: TAG_ROUTINE }).then((ns) => {
      for (const n of ns) n.close();
    });
    return;
  }
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  event.waitUntil(
    (async () => {
      const all = await self.clients.matchAll({
        type: "window",
        includeUncontrolled: true,
      });
      for (const c of all) {
        if ("focus" in c) {
          await c.focus();
          return;
        }
      }
      await self.clients.openWindow("/");
    })(),
  );
});
