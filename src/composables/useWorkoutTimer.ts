import { computed, onUnmounted, ref } from 'vue';
import { registerPlugin } from '@capacitor/core';
import { Capacitor } from '@capacitor/core';

interface WorkoutTimerPlugin {
  start(options: { routineName: string }): Promise<void>;
  pause(): Promise<void>;
  resume(): Promise<void>;
  stop(): Promise<void>;
}

const WorkoutTimer = registerPlugin<WorkoutTimerPlugin>('WorkoutTimer', {
  web: {
    start: async () => {},
    pause: async () => {},
    resume: async () => {},
    stop: async () => {},
  },
});

export function useWorkoutTimer() {
  const isRunning  = ref(false);
  const isPaused   = ref(false);
  const elapsedSec = ref(0);

  let interval: number | undefined;
  let tickStart = 0;
  let frozenSec = 0;

  function startTick() {
    stopTick();
    tickStart = Date.now() - elapsedSec.value * 1000;
    interval = window.setInterval(() => {
      elapsedSec.value = Math.floor((Date.now() - tickStart) / 1000);
    }, 500);
  }

  function stopTick() {
    if (interval !== undefined) {
      window.clearInterval(interval);
      interval = undefined;
    }
  }

  async function start(routineName: string) {
    if (Capacitor.isNativePlatform()) {
      await WorkoutTimer.start({ routineName });
    }
    elapsedSec.value = 0;
    isRunning.value  = true;
    isPaused.value   = false;
    startTick();
  }

  async function pause() {
    if (!isRunning.value || isPaused.value) return;
    if (Capacitor.isNativePlatform()) {
      await WorkoutTimer.pause();
    }
    frozenSec = elapsedSec.value;
    stopTick();
    isPaused.value = true;
  }

  async function resume() {
    if (!isRunning.value || !isPaused.value) return;
    if (Capacitor.isNativePlatform()) {
      await WorkoutTimer.resume();
    }
    elapsedSec.value = frozenSec;
    isPaused.value   = false;
    startTick();
  }

  async function stop() {
    if (Capacitor.isNativePlatform()) {
      await WorkoutTimer.stop();
    }
    stopTick();
    isRunning.value  = false;
    isPaused.value   = false;
    elapsedSec.value = 0;
  }

  const formattedTime = computed(() => {
    const m = Math.floor(elapsedSec.value / 60);
    const s = elapsedSec.value % 60;
    return `${m}:${s.toString().padStart(2, '0')}`;
  });

  onUnmounted(stopTick);

  return { isRunning, isPaused, elapsedSec, formattedTime, start, pause, resume, stop };
}
