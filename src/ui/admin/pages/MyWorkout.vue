<template>
  <section v-if="loading" class="workout workout--loading">Cargando sesión…</section>
  <section v-else-if="!session" class="workout workout--empty">
    <p>Sesión no encontrada.</p>
    <RouterLink to="/rutinas">Volver a rutinas</RouterLink>
  </section>
  <section v-else class="workout">
    <header class="whead">
      <button class="whead__close" @click="onAbort" title="Cancelar sesión">
        <svg viewBox="0 0 24 24" aria-hidden="true">
          <path d="M6 6l12 12M18 6L6 18" stroke="currentColor" stroke-width="2" stroke-linecap="round" />
        </svg>
      </button>
      <div class="whead__title">
        <h1>{{ routine?.name ?? "Sesión libre" }}</h1>
        <p>{{ elapsedLabel }} · {{ activeIdx + 1 }} de {{ totalCount }} ejercicios</p>
      </div>
      <button class="whead__finish" @click="onFinish">Finalizar</button>
    </header>

    <div v-if="rest.running.value" class="rest">
      <div class="rest__bar">
        <div class="rest__fill" :style="{ width: rest.progressPct.value + '%' }"></div>
      </div>
      <div class="rest__row">
        <span class="rest__lab">Descanso</span>
        <span class="rest__time">{{ rest.remainingLabel.value }}</span>
        <div class="rest__btns">
          <button @click="rest.adjust(-15)">−15</button>
          <button @click="rest.adjust(15)">+15</button>
          <button class="rest__skip" @click="rest.stop()" title="Saltar descanso">×</button>
        </div>
      </div>
    </div>

    <p v-if="error" class="workout__error">{{ error }}</p>

    <button v-if="prevExId !== null" class="ex-nav ex-nav--prev" @click="goToExercise(activeIdx - 1)">
      <span class="ex-nav__icon">
        <svg viewBox="0 0 24 24" aria-hidden="true">
          <path d="M6.5 6.5l11 11M4 9l5-5 4 4-5 5zM11 16l5-5 4 4-5 5zM4 11l9 9M11 4l9 9" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" fill="none" />
        </svg>
      </span>
      <div>
        <p class="ex-nav__lab">ANTERIOR</p>
        <p class="ex-nav__name">{{ exerciseLabel(prevExId) }}</p>
      </div>
      <svg class="ex-nav__chev" viewBox="0 0 24 24" aria-hidden="true">
        <path d="M6 15l6-6 6 6" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" fill="none" />
      </svg>
    </button>

    <article v-if="activeExId !== null" class="ex">
      <header class="ex__head">
        <div class="ex__img">
          <img v-if="activeExercise?.image_url" :src="activeExercise.image_url" alt="" />
          <svg v-else viewBox="0 0 24 24" aria-hidden="true">
            <path d="M6.5 6.5l11 11M4 9l5-5 4 4-5 5zM11 16l5-5 4 4-5 5zM4 11l9 9M11 4l9 9" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" fill="none" />
          </svg>
        </div>
        <div class="ex__title">
          <h2>{{ activeExercise?.name ?? "—" }}</h2>
          <p>
            Ejercicio {{ activeIdx + 1 }} de {{ totalCount }} · descanso
            <input
              type="number"
              min="0"
              step="5"
              :value="pendingRest.get(activeExId) ?? 60"
              @change="onRestChange(activeExId, $event)"
            />s
          </p>
        </div>
        <button class="ex__menu" @click="onRemoveExercise(activeExId)" title="Quitar ejercicio">×</button>
      </header>

      <div class="sets">
        <div
          v-for="(l, i) in activeLogs"
          :key="l.id"
          class="setrow"
          :class="{
            'setrow--done': isLogCompleted(l),
            'setrow--active': !isLogCompleted(l) && i === activeSetIdx,
          }"
        >
          <span class="setrow__num">{{ l.set_number }}</span>
          <span class="setrow__prev">{{ prefillFor(activeExId, i) }}</span>
          <input
            type="number"
            step="0.5"
            min="0"
            inputmode="decimal"
            v-model.lazy.number="l.weight"
            :placeholder="prefillWeight(activeExId, i)"
            @change="onLogChange(l, 'weight')"
          />
          <input
            type="number"
            min="0"
            inputmode="numeric"
            v-model.lazy.number="l.reps"
            :placeholder="prefillReps(activeExId, i)"
            @change="onLogChange(l, 'reps')"
          />
          <button
            class="setrow__check"
            :class="{ 'setrow__check--done': isLogCompleted(l) }"
            @click="onToggle(l, activeExId, i)"
            :title="isLogCompleted(l) ? 'Iniciar descanso' : 'Completar serie'"
          >
            <svg viewBox="0 0 24 24" aria-hidden="true">
              <path d="M5 12.5l4.5 4.5L19 7.5" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" fill="none" />
            </svg>
          </button>
          <button class="setrow__del" @click="onRemoveSet(l.id)" title="Borrar serie">×</button>
        </div>

        <button class="ex__addset" @click="addSet(activeExId)">+ Añadir serie</button>
      </div>

      <button v-if="canSaveRestDefault(activeExId)" type="button" class="ex__rest-save" @click="onSaveRestDefault(activeExId)">
        {{ savedRestFor === activeExId ? "✓ Guardado como default" : `Guardar ${pendingRest.get(activeExId)}s como default` }}
      </button>
    </article>

    <button v-if="nextExId !== null" class="ex-nav ex-nav--next" @click="goToExercise(activeIdx + 1)">
      <span class="ex-nav__icon">
        <svg viewBox="0 0 24 24" aria-hidden="true">
          <path d="M6.5 6.5l11 11M4 9l5-5 4 4-5 5zM11 16l5-5 4 4-5 5zM4 11l9 9M11 4l9 9" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" fill="none" />
        </svg>
      </span>
      <div>
        <p class="ex-nav__lab">SIGUIENTE</p>
        <p class="ex-nav__name">{{ exerciseLabel(nextExId) }}</p>
      </div>
      <svg class="ex-nav__chev" viewBox="0 0 24 24" aria-hidden="true">
        <path d="M6 9l6 6 6-6" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" fill="none" />
      </svg>
    </button>

    <div v-else-if="allExercisesDone" class="done-banner">
      🎉 ¡Todos los ejercicios completados! Toca <strong>Finalizar</strong> para guardar la sesión.
    </div>

    <details class="add-ex">
      <summary>+ Añadir ejercicio</summary>
      <div v-if="!catalog.length" class="add-ex__empty">El catálogo está vacío.</div>
      <div v-else class="catalog">
        <button v-for="ex in availableCatalog" :key="ex.id" class="catalog__item" @click="onAddExercise(ex)">
          <img v-if="ex.image_url" :src="ex.image_url" alt="" />
          <span>{{ ex.name }}</span>
        </button>
        <p v-if="availableCatalog.length === 0" class="add-ex__empty">
          Ya están todos los ejercicios del catálogo en la sesión.
        </p>
      </div>
    </details>
  </section>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, reactive, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import { useWorkout, isLogCompleted } from "@/composables/useWorkout";
import type { ExerciseLog } from "@/composables/useWorkout";
import { useExercise } from "@/composables/useExercise";
import type { Exercise } from "@/composables/useExercise";
import { useNotifications } from "@/composables/useNotifications";

const route = useRoute();
const router = useRouter();

const {
  session,
  routine,
  logs,
  exercisesById,
  prefill,
  loading,
  error,
  orderedExerciseIds,
  logsForExercise,
  routineExerciseFor,
  load,
  updateLog,
  addSet,
  removeSet,
  addExercise,
  saveRestAsDefault,
  finish,
  abort,
} = useWorkout();

const { exercise: catalog, getExercises } = useExercise();
const notifications = useNotifications();

const pendingRest = reactive(new Map<number, number>());
const now = ref(Date.now());
let nowTimer: number | null = null;

const elapsedLabel = computed(() => {
  if (!session.value?.started_at) return "00:00";
  const ms = now.value - new Date(session.value.started_at).getTime();
  return fmt(Math.max(0, Math.floor(ms / 1000)));
});

function fmt(totalSec: number): string {
  const h = Math.floor(totalSec / 3600);
  const m = Math.floor((totalSec % 3600) / 60);
  const s = totalSec % 60;
  const mm = String(m).padStart(2, "0");
  const ss = String(s).padStart(2, "0");
  return h > 0 ? `${h}:${mm}:${ss}` : `${mm}:${ss}`;
}

const rest = createRestTimer();

function createRestTimer() {
  const running = ref(false);
  const totalSec = ref(0);
  const endAt = ref(0);
  const remaining = ref(0);
  let intervalId: number | null = null;

  function clearTick() {
    if (intervalId !== null) {
      clearInterval(intervalId);
      intervalId = null;
    }
  }
  function tick() {
    const left = Math.max(0, Math.round((endAt.value - Date.now()) / 1000));
    remaining.value = left;
    if (left <= 0) expire();
  }
  function start(sec: number) {
    clearTick();
    totalSec.value = sec;
    endAt.value = Date.now() + sec * 1000;
    remaining.value = sec;
    running.value = true;
    intervalId = window.setInterval(tick, 250);
    void scheduleSWRest(sec);
  }
  function stop() {
    clearTick();
    running.value = false;
    remaining.value = 0;
    void notifications.cancelRest();
  }
  function expire() {
    clearTick();
    running.value = false;
    remaining.value = 0;
    if (document.visibilityState === "visible") {
      void notifications.cancelRest();
      notifyRestEnded();
    }
  }
  function adjust(deltaSec: number) {
    if (!running.value) return;
    endAt.value += deltaSec * 1000;
    totalSec.value = Math.max(totalSec.value + deltaSec, 1);
    tick();
    const remainingSec = Math.max(1, Math.round((endAt.value - Date.now()) / 1000));
    void scheduleSWRest(remainingSec);
  }
  const progressPct = computed(() => {
    if (!running.value || totalSec.value === 0) return 0;
    return Math.max(0, Math.min(100, (remaining.value / totalSec.value) * 100));
  });
  const remainingLabel = computed(() => fmt(remaining.value));

  return { running, totalSec, remaining, progressPct, remainingLabel, start, stop, adjust };
}

let audioCtx: AudioContext | null = null;
function ensureAudio() {
  try {
    type WebkitWindow = typeof window & { webkitAudioContext?: typeof AudioContext };
    const Ctx = window.AudioContext || (window as WebkitWindow).webkitAudioContext;
    if (!Ctx) return;
    if (!audioCtx) audioCtx = new Ctx();
    if (audioCtx.state === "suspended") void audioCtx.resume();
  } catch {
    /* no audio available */
  }
}
function playBeep() {
  const ctx = audioCtx;
  if (!ctx) return;
  try {
    const t0 = ctx.currentTime;
    for (let i = 0; i < 2; i++) {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.type = "sine";
      osc.frequency.value = 880;
      const at = t0 + i * 0.25;
      gain.gain.setValueAtTime(0.0001, at);
      gain.gain.exponentialRampToValueAtTime(0.35, at + 0.02);
      gain.gain.exponentialRampToValueAtTime(0.0001, at + 0.2);
      osc.start(at);
      osc.stop(at + 0.22);
    }
  } catch {
    /* ignore */
  }
}
function notifyRestEnded() {
  if (typeof navigator !== "undefined" && typeof navigator.vibrate === "function") {
    navigator.vibrate([200, 100, 200]);
  }
  playBeep();
}

async function scheduleSWRest(sec: number) {
  if (!notifPermissionGranted.value) return;
  const exName = activeExercise.value?.name ?? "Ejercicio";
  await notifications.scheduleRest(sec, `Siguiente serie · ${exName}`);
}

const notifPermissionGranted = ref(
  typeof Notification !== "undefined" && Notification.permission === "granted",
);

async function ensureNotifPermission() {
  if (notifPermissionGranted.value) return true;
  const ok = await notifications.ensurePermission();
  notifPermissionGranted.value = ok;
  return ok;
}

const totalCount = computed(() => orderedExerciseIds.value.length);

const userActiveIdx = ref<number | null>(null);
const autoActiveIdx = computed(() => {
  for (let i = 0; i < orderedExerciseIds.value.length; i++) {
    const exId = orderedExerciseIds.value[i];
    if (exId === undefined) continue;
    const ls = logsForExercise(exId);
    const allDone = ls.length > 0 && ls.every(isLogCompleted);
    if (!allDone) return i;
  }
  return Math.max(0, orderedExerciseIds.value.length - 1);
});
const activeIdx = computed(() => {
  const u = userActiveIdx.value;
  if (u !== null && u >= 0 && u < orderedExerciseIds.value.length) return u;
  return autoActiveIdx.value;
});
const activeExId = computed<number | null>(() => orderedExerciseIds.value[activeIdx.value] ?? null);
const prevExId = computed<number | null>(() => orderedExerciseIds.value[activeIdx.value - 1] ?? null);
const nextExId = computed<number | null>(() => orderedExerciseIds.value[activeIdx.value + 1] ?? null);
const allExercisesDone = computed(() => {
  if (orderedExerciseIds.value.length === 0) return false;
  return orderedExerciseIds.value.every((exId) => {
    const ls = logsForExercise(exId);
    return ls.length > 0 && ls.every(isLogCompleted);
  });
});
const activeExercise = computed(() => (activeExId.value !== null ? exercisesById.value.get(activeExId.value) ?? null : null));
const activeLogs = computed(() => (activeExId.value !== null ? logsForExercise(activeExId.value) : []));
const activeSetIdx = computed(() => activeLogs.value.findIndex((l) => !isLogCompleted(l)));

function exerciseLabel(exId: number): string {
  const ex = exercisesById.value.get(exId);
  const re = routineExerciseFor(exId);
  const name = ex?.name ?? "—";
  if (re?.target_sets && re?.target_reps) return `${name} · ${re.target_sets} × ${re.target_reps}`;
  return name;
}

function goToExercise(idx: number) {
  if (idx < 0 || idx >= orderedExerciseIds.value.length) return;
  userActiveIdx.value = idx;
}

const availableCatalog = computed(() => {
  const inSession = new Set(orderedExerciseIds.value);
  return catalog.value.filter((e) => e.id !== undefined && !inSession.has(e.id));
});

watch(
  () => route.params.sessionId,
  async (sid) => {
    if (!sid) return;
    await load(String(sid));
    initPendingRest();
  },
  { immediate: true }
);

let unbindSW: (() => void) | null = null;

function onVisibilityChange() {
  if (!session.value || session.value.finished_at) return;
  if (document.visibilityState === "hidden") {
    showOngoingRoutine();
  } else {
    void notifications.clearRoutine();
  }
}

function showOngoingRoutine() {
  if (!notifPermissionGranted.value) return;
  const title = routine.value?.name ?? "Sesión libre";
  const exName = activeExercise.value?.name ?? "—";
  const body = `${exName} · ${activeIdx.value + 1}/${totalCount.value} · ${elapsedLabel.value}`;
  void notifications.showRoutine(title, body);
}

onMounted(async () => {
  await getExercises();
  nowTimer = window.setInterval(() => (now.value = Date.now()), 1000);
  document.addEventListener("visibilitychange", onVisibilityChange);
  unbindSW = notifications.onSWMessage((msg) => {
    if (msg.type === "rest-end" && document.visibilityState === "visible") {
      notifyRestEnded();
    }
  });
});

onBeforeUnmount(() => {
  if (nowTimer) clearInterval(nowTimer);
  rest.stop();
  document.removeEventListener("visibilitychange", onVisibilityChange);
  unbindSW?.();
  void notifications.clearRoutine();
  if (audioCtx) {
    void audioCtx.close().catch(() => {});
    audioCtx = null;
  }
});

watch(
  [activeExId, () => session.value?.id],
  () => {
    if (document.visibilityState === "hidden") showOngoingRoutine();
  },
);

watch(orderedExerciseIds, () => {
  initPendingRest();
});

function initPendingRest() {
  for (const exId of orderedExerciseIds.value) {
    if (pendingRest.has(exId)) continue;
    const re = routineExerciseFor(exId);
    const ex = exercisesById.value.get(exId);
    pendingRest.set(exId, re?.rest_seconds ?? ex?.rest_seconds ?? 60);
  }
}

function prefillFor(exerciseId: number, idx: number): string {
  const sets = prefill.value.get(exerciseId);
  const s = sets?.[idx];
  if (!s || s.weight === null || s.reps === null) return "—";
  return `${s.weight} × ${s.reps}`;
}
function prefillWeight(exerciseId: number, idx: number): string {
  const s = prefill.value.get(exerciseId)?.[idx];
  return s?.weight !== null && s?.weight !== undefined ? String(s.weight) : "";
}
function prefillReps(exerciseId: number, idx: number): string {
  const s = prefill.value.get(exerciseId)?.[idx];
  return s?.reps !== null && s?.reps !== undefined ? String(s.reps) : "";
}

async function onLogChange(l: ExerciseLog, field: "weight" | "reps") {
  const raw = l[field] as number | string | null;
  let value: number | null;
  if (raw === null || raw === undefined) {
    value = null;
  } else if (typeof raw === "string") {
    const trimmed = raw.trim();
    if (trimmed === "") value = null;
    else {
      const n = Number(trimmed);
      value = Number.isNaN(n) ? null : n;
    }
  } else if (Number.isNaN(raw)) {
    value = null;
  } else {
    value = raw;
  }
  if (l[field] !== value) {
    Object.assign(l, { [field]: value });
  }
  await updateLog(l.id, { [field]: value });
}

async function onToggle(l: ExerciseLog, exerciseId: number, idx: number) {
  if (isLogCompleted(l)) {
    await updateLog(l.id, { rest_seconds_used: null });
    return;
  }
  ensureAudio();
  const restSec = pendingRest.get(exerciseId) ?? 60;
  const patch: Partial<Pick<ExerciseLog, "weight" | "reps" | "rest_seconds_used">> = {
    rest_seconds_used: restSec,
  };
  if (l.weight === null) {
    const pw = prefill.value.get(exerciseId)?.[idx]?.weight;
    patch.weight = typeof pw === "number" ? pw : 0;
  }
  if (l.reps === null) {
    const pr = prefill.value.get(exerciseId)?.[idx]?.reps;
    patch.reps = typeof pr === "number" ? pr : 0;
  }
  await updateLog(l.id, patch);
  if (restSec > 0) {
    await ensureNotifPermission();
    rest.start(restSec);
  }
}

async function onRestChange(exerciseId: number, e: Event) {
  const n = Number((e.target as HTMLInputElement).value);
  if (Number.isNaN(n) || n < 0) return;
  pendingRest.set(exerciseId, n);
  if (savedRestFor.value === exerciseId) savedRestFor.value = null;
}

const savedRestFor = ref<number | null>(null);
let savedRestTimer: number | null = null;

function canSaveRestDefault(exerciseId: number): boolean {
  const re = routineExerciseFor(exerciseId);
  if (!re) return false;
  const pending = pendingRest.get(exerciseId);
  if (pending === undefined) return false;
  return pending !== re.rest_seconds;
}

async function onSaveRestDefault(exerciseId: number) {
  const seconds = pendingRest.get(exerciseId);
  if (seconds === undefined) return;
  const ok = await saveRestAsDefault(exerciseId, seconds);
  if (!ok) return;
  savedRestFor.value = exerciseId;
  if (savedRestTimer) clearTimeout(savedRestTimer);
  savedRestTimer = window.setTimeout(() => {
    if (savedRestFor.value === exerciseId) savedRestFor.value = null;
  }, 1800);
}

async function onRemoveSet(id: string) {
  await removeSet(id);
}

async function onRemoveExercise(exerciseId: number) {
  if (!confirm("¿Quitar este ejercicio de la sesión?")) return;
  const ids = logs.value.filter((l) => l.exercise_id === exerciseId).map((l) => l.id);
  for (const id of ids) await removeSet(id);
  if (userActiveIdx.value !== null && userActiveIdx.value >= orderedExerciseIds.value.length - 1) {
    userActiveIdx.value = null;
  }
}

async function onAddExercise(ex: Exercise) {
  await addExercise(ex, 3);
}

async function onFinish() {
  if (!confirm("¿Finalizar sesión?")) return;
  const ok = await finish();
  if (ok) {
    await notifications.cancelRest();
    await notifications.clearRoutine();
    router.push({ name: "dashboard" });
  }
}

async function onAbort() {
  if (!confirm("¿Cancelar la sesión? Se perderá lo registrado.")) return;
  const ok = await abort();
  if (ok) {
    await notifications.cancelRest();
    await notifications.clearRoutine();
    router.push({ name: "rutinas" });
  }
}
</script>

<style scoped>
.workout {
  max-width: 480px;
  margin: 0 auto;
  padding: 0 0 24px;
  display: flex;
  flex-direction: column;
  gap: 16px;
}
.workout--loading,
.workout--empty {
  text-align: center;
  padding: 64px 16px;
  color: var(--text-tertiary);
}

/* ───────── Header ───────── */
.whead {
  position: sticky;
  top: 0;
  z-index: 5;
  display: grid;
  grid-template-columns: 36px 1fr auto;
  align-items: center;
  gap: 12px;
  padding: 14px 20px;
  background: var(--surface-0);
  border-bottom: 1px solid var(--border-subtle);
}
.whead__close {
  display: grid;
  place-items: center;
  width: 36px;
  height: 36px;
  border-radius: var(--radius-pill);
  border: none;
  background: var(--surface-2);
  color: var(--text-primary);
  cursor: pointer;
}
.whead__close svg {
  width: 16px;
  height: 16px;
}
.whead__title {
  min-width: 0;
}
.whead__title h1 {
  margin: 0;
  font-family: var(--font-body);
  font-size: 14px;
  font-weight: var(--weight-semibold);
  color: var(--text-primary);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.whead__title p {
  margin: 1px 0 0;
  font-size: 11px;
  color: var(--text-tertiary);
  font-weight: var(--weight-medium);
  font-variant-numeric: tabular-nums;
}
.whead__finish {
  padding: 8px 14px;
  border-radius: var(--radius-pill);
  border: none;
  background: var(--brand-500);
  color: var(--surface-0);
  font-family: inherit;
  font-weight: var(--weight-bold);
  font-size: 12px;
  cursor: pointer;
}

/* ───────── Rest banner ───────── */
.rest {
  position: sticky;
  top: 65px;
  z-index: 4;
  margin: 0;
  padding: 14px 20px;
  background: var(--brand-glow);
  border-bottom: 1px solid var(--brand-500);
  display: flex;
  flex-direction: column;
  gap: 10px;
}
.rest__bar {
  height: 4px;
  background: var(--brand-glow);
  border-radius: 2px;
  overflow: hidden;
}
.rest__fill {
  height: 100%;
  background: var(--brand-500);
  border-radius: 2px;
  transition: width 0.25s linear;
}
.rest__row {
  display: flex;
  align-items: center;
  gap: 10px;
}
.rest__lab {
  font-size: 11px;
  font-weight: var(--weight-bold);
  letter-spacing: 0.8px;
  color: var(--text-tertiary);
  text-transform: uppercase;
}
.rest__time {
  font-family: var(--font-display);
  font-variant-numeric: tabular-nums;
  font-size: 20px;
  font-weight: var(--weight-bold);
  color: var(--brand-300);
  min-width: 56px;
}
.rest__btns {
  margin-left: auto;
  display: flex;
  gap: 6px;
}
.rest__btns button {
  padding: 6px 10px;
  border-radius: var(--radius-pill);
  border: none;
  background: var(--surface-2);
  color: var(--text-secondary);
  cursor: pointer;
  font-family: inherit;
  font-size: 11px;
  font-weight: var(--weight-semibold);
}
.rest__btns button:hover {
  color: var(--text-primary);
}
.rest__skip {
  color: var(--danger) !important;
  font-size: 14px !important;
}

.workout__error {
  margin: 0 20px;
  padding: 10px 12px;
  border-radius: var(--radius-sm);
  background: var(--danger-glow);
  color: var(--danger);
  font-size: 13px;
}

/* ───────── Exercise nav (prev/next) ───────── */
.ex-nav {
  display: grid;
  grid-template-columns: 32px 1fr 16px;
  gap: 12px;
  align-items: center;
  margin: 0 20px;
  padding: 14px;
  background: var(--surface-1);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-lg);
  text-align: left;
  cursor: pointer;
  font-family: inherit;
  color: inherit;
}
.ex-nav:hover {
  border-color: var(--border-default);
}
.ex-nav__icon {
  display: grid;
  place-items: center;
  width: 32px;
  height: 32px;
  border-radius: var(--radius-sm);
  background: var(--surface-3);
  color: var(--text-tertiary);
}
.ex-nav__icon svg {
  width: 16px;
  height: 16px;
}
.ex-nav__lab {
  margin: 0;
  font-size: 9px;
  font-weight: var(--weight-bold);
  letter-spacing: 0.8px;
  color: var(--text-tertiary);
  text-transform: uppercase;
}
.ex-nav__name {
  margin: 1px 0 0;
  font-size: 13px;
  font-weight: var(--weight-medium);
  color: var(--text-secondary);
  line-height: 1.2;
}
.ex-nav__chev {
  width: 16px;
  height: 16px;
  color: var(--text-tertiary);
}

/* ───────── Exercise card ───────── */
.ex {
  margin: 0 20px;
  padding: 18px;
  background: var(--surface-1);
  border: 1px solid var(--border-subtle);
  border-radius: 18px;
  display: flex;
  flex-direction: column;
  gap: 14px;
}
.ex__head {
  display: grid;
  grid-template-columns: 42px 1fr auto;
  gap: 12px;
  align-items: center;
}
.ex__img {
  display: grid;
  place-items: center;
  width: 42px;
  height: 42px;
  border-radius: 10px;
  background: var(--surface-3);
  color: var(--text-tertiary);
  overflow: hidden;
}
.ex__img img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.ex__img svg {
  width: 20px;
  height: 20px;
}
.ex__title h2 {
  margin: 0;
  font-family: var(--font-body);
  font-size: 17px;
  font-weight: var(--weight-bold);
  color: var(--text-primary);
  letter-spacing: -0.2px;
  line-height: 1.2;
}
.ex__title p {
  margin: 2px 0 0;
  font-size: 11px;
  color: var(--text-tertiary);
  font-weight: var(--weight-medium);
  display: inline-flex;
  align-items: center;
  gap: 4px;
  flex-wrap: wrap;
}
.ex__title p input {
  width: 44px;
  padding: 2px 6px;
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-xs);
  background: var(--surface-2);
  color: var(--text-secondary);
  font-family: inherit;
  font-size: 11px;
  font-weight: var(--weight-semibold);
}
.ex__title p input:focus {
  outline: none;
  border-color: var(--brand-500);
}
.ex__menu {
  background: transparent;
  border: none;
  color: var(--text-tertiary);
  font-size: 20px;
  cursor: pointer;
  line-height: 1;
}
.ex__menu:hover {
  color: var(--danger);
}

/* ───────── Set rows (pill style) ───────── */
.sets {
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.setrow {
  display: grid;
  grid-template-columns: 28px 56px 1fr 1fr 36px 18px;
  gap: 8px;
  align-items: center;
  padding: 6px 4px;
  border-radius: 10px;
}
.setrow--active {
  background: var(--brand-glow);
}
.setrow__num {
  display: grid;
  place-items: center;
  width: 28px;
  height: 28px;
  border-radius: var(--radius-pill);
  background: var(--surface-3);
  color: var(--text-secondary);
  font-size: 12px;
  font-weight: var(--weight-bold);
}
.setrow--active .setrow__num {
  background: var(--brand-500);
  color: var(--surface-0);
}
.setrow--done .setrow__num {
  background: var(--surface-3);
  color: var(--text-tertiary);
}
.setrow__prev {
  font-size: 12px;
  color: var(--text-tertiary);
  font-variant-numeric: tabular-nums;
}
.setrow input[type="number"] {
  width: 100%;
  height: 36px;
  padding: 0 10px;
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-sm);
  background: var(--surface-2);
  color: var(--text-primary);
  font-family: inherit;
  font-size: 14px;
  font-weight: var(--weight-semibold);
}
.setrow input[type="number"]:focus {
  outline: none;
  border-color: var(--brand-500);
}
.setrow--active input[type="number"] {
  border-color: var(--brand-500);
}
.setrow__check {
  display: grid;
  place-items: center;
  width: 36px;
  height: 36px;
  border: 1px solid var(--border-default);
  border-radius: var(--radius-sm);
  background: var(--surface-2);
  color: var(--text-tertiary);
  cursor: pointer;
}
.setrow__check svg {
  width: 16px;
  height: 16px;
}
.setrow__check--done {
  background: var(--brand-500);
  border-color: var(--brand-500);
  color: var(--surface-0);
}
.setrow--active .setrow__check {
  border-color: var(--brand-500);
  color: var(--brand-300);
}
.setrow__del {
  background: transparent;
  border: none;
  color: var(--text-tertiary);
  cursor: pointer;
  font-size: 14px;
  padding: 2px;
}
.setrow__del:hover {
  color: var(--danger);
}

.ex__addset {
  width: 100%;
  height: 40px;
  border: 1px solid var(--border-subtle);
  border-radius: 10px;
  background: transparent;
  color: var(--text-tertiary);
  cursor: pointer;
  font-family: inherit;
  font-size: 13px;
  font-weight: var(--weight-medium);
}
.ex__addset:hover {
  border-color: var(--brand-500);
  color: var(--brand-300);
}

.ex__rest-save {
  align-self: flex-start;
  padding: 6px 12px;
  border-radius: var(--radius-pill);
  border: 1px solid var(--brand-500);
  background: transparent;
  color: var(--brand-300);
  cursor: pointer;
  font-size: 11px;
  font-weight: var(--weight-bold);
  font-family: inherit;
}
.ex__rest-save:hover {
  background: var(--brand-glow);
}

/* ───────── Done banner ───────── */
.done-banner {
  margin: 0 20px;
  padding: 16px;
  border: 1px solid var(--brand-500);
  border-radius: var(--radius-lg);
  background: var(--brand-glow);
  color: var(--text-primary);
  font-size: 13px;
  text-align: center;
  font-weight: var(--weight-medium);
}
.done-banner strong {
  color: var(--brand-300);
  font-weight: var(--weight-bold);
}

/* ───────── Add exercise (catalog) ───────── */
.add-ex {
  margin: 0 20px;
  padding: 12px 16px;
  border: 1px dashed var(--border-subtle);
  border-radius: var(--radius-md);
}
.add-ex summary {
  cursor: pointer;
  font-size: 13px;
  color: var(--text-secondary);
  font-weight: var(--weight-medium);
}
.add-ex summary:hover {
  color: var(--brand-400);
}
.add-ex__empty {
  color: var(--text-tertiary);
  font-size: 13px;
  padding: 8px 0;
}
.catalog {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 8px;
  padding: 12px 0 0;
}
.catalog__item {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px;
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-md);
  background: var(--surface-2);
  color: var(--text-primary);
  cursor: pointer;
  font-family: inherit;
  font-size: 13px;
  text-align: left;
}
.catalog__item img {
  width: 32px;
  height: 32px;
  object-fit: cover;
  border-radius: var(--radius-sm);
}
.catalog__item:hover {
  border-color: var(--brand-500);
}
</style>
