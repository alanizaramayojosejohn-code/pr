<template>
  <section v-if="!selectedRoutine" class="routines">
    <header class="routines__head">
      <h1>Rutinas</h1>
      <button class="routines__add" :disabled="creating" @click="onCreate">
        <svg viewBox="0 0 24 24" class="routines__add-ic" aria-hidden="true">
          <path d="M12 5v14M5 12h14" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" />
        </svg>
        Nueva
      </button>
    </header>

    <p v-if="error" class="routines__error">{{ error }}</p>

    <p v-if="loading && !routines.length" class="routines__empty">Cargando…</p>

    <div v-else class="routines__grid">
      <article
        v-for="r in routines"
        :key="r.id"
        class="rcard"
        :class="{ 'rcard--today': r.day_of_week === todayDow }"
        @click="selectedId = r.id"
      >
        <span class="rcard__badge">
          <span v-if="r.day_of_week === todayDow" class="rcard__dot"></span>
          {{ badgeLabel(r) }}
        </span>
        <h2 class="rcard__name">{{ r.name }}</h2>
        <p class="rcard__stats">{{ statsLabel(r) }}</p>
      </article>

      <button class="rcard rcard--add" :disabled="creating" @click="onCreate">
        <span class="rcard__plus">
          <svg viewBox="0 0 24 24" aria-hidden="true">
            <path d="M12 5v14M5 12h14" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" />
          </svg>
        </span>
        <span class="rcard__add-title">Nueva rutina</span>
        <span class="rcard__add-sub">Crear desde cero</span>
      </button>
    </div>
  </section>

  <section v-else class="redit">
    <header class="redit__head">
      <button class="redit__back" @click="selectedId = null" title="Volver">
        <svg viewBox="0 0 24 24" aria-hidden="true">
          <path d="M15 6l-6 6 6 6" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" fill="none" />
        </svg>
      </button>
      <div class="redit__title">
        <h1
          contenteditable="true"
          @blur="onRename(selectedRoutine, $event)"
          @keydown.enter.prevent="($event.target as HTMLElement).blur()"
        >{{ selectedRoutine.name }}</h1>
        <p>{{ statsLabel(selectedRoutine) }}</p>
      </div>
    </header>

    <div class="redit__day">
      <span class="redit__day-lab">Día</span>
      <div class="redit__day-pills">
        <button
          v-for="d in DAY_PILLS"
          :key="String(d.value)"
          class="day-pill"
          :class="{ 'day-pill--active': selectedRoutine.day_of_week === d.value }"
          @click="onDayChange(selectedRoutine, d.value)"
        >{{ d.short }}</button>
      </div>
    </div>

    <ul class="redit__exs">
      <li
        v-for="(re, i) in selectedRoutine.routine_exercises ?? []"
        :key="re.id"
        class="rex"
      >
        <div class="rex__order">
          <button :disabled="i === 0" @click="reorderRoutine(selectedRoutine.id, re.id, -1)" title="Subir">↑</button>
          <button :disabled="i === (selectedRoutine.routine_exercises?.length ?? 0) - 1" @click="reorderRoutine(selectedRoutine.id, re.id, 1)" title="Bajar">↓</button>
        </div>
        <div class="rex__img">
          <img v-if="re.exercise?.image_url" :src="re.exercise.image_url" alt="" />
          <svg v-else viewBox="0 0 24 24" aria-hidden="true">
            <path d="M6.5 6.5l11 11M4 9l5-5 4 4-5 5zM11 16l5-5 4 4-5 5zM4 11l9 9M11 4l9 9" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" fill="none" />
          </svg>
        </div>
        <div class="rex__body">
          <p class="rex__name">{{ re.exercise?.name ?? "—" }}</p>
          <div class="rex__inputs">
            <label>
              <span>Series</span>
              <input type="number" min="1" :value="re.target_sets" @change="onReChange(re.id, 'target_sets', $event)" />
            </label>
            <label>
              <span>Reps</span>
              <input type="number" min="1" :value="re.target_reps" @change="onReChange(re.id, 'target_reps', $event)" />
            </label>
            <label>
              <span>Descanso</span>
              <input type="number" min="0" step="5" :value="re.rest_seconds" @change="onReChange(re.id, 'rest_seconds', $event)" />
            </label>
          </div>
        </div>
        <button class="rex__remove" @click="onRemoveRE(re.id)" title="Quitar">×</button>
      </li>
    </ul>

    <button class="redit__add" @click="openPicker(selectedRoutine)">
      <span class="redit__add-ic">+</span>
      Agregar ejercicio por categoría
    </button>

    <button class="redit__delete" @click="onDelete(selectedRoutine)">Eliminar rutina</button>
  </section>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import { useRouter } from "vue-router";
import { useRoutines, DAYS } from "@/composables/useRoutines";
import type { Routine } from "@/composables/useRoutines";

const {
  routines,
  loading,
  error,
  fetchRoutines,
  createRoutine,
  updateRoutine,
  deleteRoutine,
  updateRoutineExercise,
  removeRoutineExercise,
  reorderRoutine,
} = useRoutines();

const router = useRouter();

const creating = ref(false);
const selectedId = ref<string | null>(null);
const todayDow = new Date().getDay();

const DAY_PILLS = [
  { value: null, short: "—" },
  { value: 1, short: "L" },
  { value: 2, short: "M" },
  { value: 3, short: "X" },
  { value: 4, short: "J" },
  { value: 5, short: "V" },
  { value: 6, short: "S" },
  { value: 0, short: "D" },
] as const;

const selectedRoutine = computed(() =>
  selectedId.value ? routines.value.find((r) => r.id === selectedId.value) ?? null : null
);

onMounted(async () => {
  await fetchRoutines();
});

function badgeLabel(r: Routine): string {
  if (r.day_of_week === null || r.day_of_week === undefined) return "SIN DÍA";
  const label = DAYS.find((d) => d.value === r.day_of_week)?.label ?? "—";
  if (r.day_of_week === todayDow) return `HOY · ${label.toUpperCase()}`;
  return label.toUpperCase();
}

function statsLabel(r: Routine): string {
  const list = r.routine_exercises ?? [];
  const exCount = list.length;
  if (!exCount) return "Sin ejercicios";
  const totalSets = list.reduce((acc, re) => acc + (re.target_sets || 0), 0);
  const totalRest = list.reduce(
    (acc, re) => acc + (re.target_sets || 0) * (re.rest_seconds || 0),
    0
  );
  // ~30s por serie ejecutada + descansos
  const minutes = Math.max(5, Math.round((totalSets * 30 + totalRest) / 60 / 5) * 5);
  return `${exCount} ej. · ~${minutes} min`;
}

function openPicker(r: Routine) {
  router.push({ name: "ejercicios", query: { picker: r.id } });
}

async function onCreate() {
  if (creating.value) return;
  const name = window.prompt("Nombre de la nueva rutina")?.trim();
  if (!name) return;
  creating.value = true;
  const r = await createRoutine({ name, day_of_week: null });
  creating.value = false;
  if (r) selectedId.value = r.id;
}

async function onRename(r: Routine, e: Event) {
  const el = e.target as HTMLElement;
  const name = (el.textContent ?? "").trim();
  if (name && name !== r.name) {
    await updateRoutine(r.id, { name });
  } else {
    el.textContent = r.name;
  }
}

async function onDayChange(r: Routine, day: number | null) {
  if (r.day_of_week === day) return;
  await updateRoutine(r.id, { day_of_week: day });
}

async function onDelete(r: Routine) {
  if (!confirm(`¿Eliminar la rutina "${r.name}"?`)) return;
  const ok = await deleteRoutine(r.id);
  if (ok) selectedId.value = null;
}

async function onRemoveRE(id: string) {
  await removeRoutineExercise(id);
}

async function onReChange(
  id: string,
  field: "target_sets" | "target_reps" | "rest_seconds",
  e: Event
) {
  const v = Number((e.target as HTMLInputElement).value);
  if (Number.isNaN(v)) return;
  await updateRoutineExercise(id, { [field]: v });
}
</script>

<style scoped>
.routines {
  max-width: 480px;
  margin: 0 auto;
  padding: 8px 20px 24px;
  display: flex;
  flex-direction: column;
  gap: 20px;
}
.routines__head {
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.routines__head h1 {
  margin: 0;
  font-family: var(--font-display);
  font-size: 26px;
  font-weight: var(--weight-bold);
  letter-spacing: -0.5px;
  color: var(--text-primary);
}
.routines__add {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 8px 14px;
  border-radius: var(--radius-pill);
  border: none;
  background: var(--brand-500);
  color: var(--surface-0);
  font-family: inherit;
  font-weight: var(--weight-bold);
  font-size: 13px;
  cursor: pointer;
}
.routines__add:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
.routines__add-ic {
  width: 14px;
  height: 14px;
}
.routines__error {
  margin: 0;
  padding: 10px 12px;
  border-radius: var(--radius-sm);
  background: var(--danger-glow);
  color: var(--danger);
  font-size: 13px;
}
.routines__empty {
  margin: 0;
  padding: 32px 0;
  text-align: center;
  color: var(--text-tertiary);
}
.routines__grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
}
@media (max-width: 380px) {
  .routines__grid { grid-template-columns: 1fr; }
}

.rcard {
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding: 14px;
  text-align: left;
  background: var(--surface-1);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-lg);
  cursor: pointer;
  font-family: inherit;
  color: inherit;
}
.rcard:hover {
  border-color: var(--border-default);
}
.rcard--today {
  border-color: var(--brand-glow);
}
.rcard__badge {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  align-self: flex-start;
  padding: 4px 10px;
  border-radius: var(--radius-pill);
  background: var(--surface-3);
  color: var(--text-tertiary);
  font-size: 9px;
  font-weight: var(--weight-bold);
  letter-spacing: 0.6px;
  text-transform: uppercase;
}
.rcard--today .rcard__badge {
  background: var(--brand-glow);
  color: var(--brand-300);
}
.rcard__dot {
  width: 6px;
  height: 6px;
  border-radius: var(--radius-pill);
  background: var(--brand-500);
  box-shadow: 0 0 6px var(--brand-glow);
}
.rcard__name {
  margin: 0;
  font-family: var(--font-body);
  font-size: 15px;
  font-weight: var(--weight-bold);
  color: var(--text-primary);
  line-height: 1.25;
  letter-spacing: -0.2px;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
.rcard__stats {
  margin: 0;
  font-size: 11px;
  color: var(--text-tertiary);
  font-weight: var(--weight-medium);
}
.rcard__start {
  margin-top: auto;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  padding: 9px 0;
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-pill);
  background: var(--surface-3);
  color: var(--text-secondary);
  font-family: inherit;
  font-weight: var(--weight-semibold);
  font-size: 12px;
  cursor: pointer;
}
.rcard__start--primary {
  background: var(--brand-500);
  border-color: var(--brand-500);
  color: var(--surface-0);
  font-weight: var(--weight-bold);
}
.rcard__start:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
.rcard__start-ic {
  width: 11px;
  height: 11px;
}

.rcard--add {
  align-items: center;
  justify-content: center;
  text-align: center;
  background: var(--surface-0);
  border-style: dashed;
  border-color: var(--border-subtle);
  gap: 6px;
}
.rcard--add:hover {
  border-color: var(--brand-500);
}
.rcard__plus {
  display: grid;
  place-items: center;
  width: 32px;
  height: 32px;
  border-radius: var(--radius-pill);
  background: var(--brand-glow);
  color: var(--brand-400);
}
.rcard__plus svg {
  width: 16px;
  height: 16px;
}
.rcard__add-title {
  font-size: 13px;
  font-weight: var(--weight-bold);
  color: var(--text-primary);
}
.rcard__add-sub {
  font-size: 11px;
  color: var(--text-tertiary);
}

/* ───────── Editor ───────── */
.redit {
  max-width: 480px;
  margin: 0 auto;
  padding: 8px 20px 24px;
  display: flex;
  flex-direction: column;
  gap: 16px;
}
.redit__head {
  display: grid;
  grid-template-columns: 36px 1fr auto;
  gap: 12px;
  align-items: center;
}
.redit__back {
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
.redit__back svg {
  width: 16px;
  height: 16px;
}
.redit__title {
  min-width: 0;
}
.redit__title h1 {
  margin: 0;
  padding: 0;
  font-family: var(--font-display);
  font-size: 22px;
  font-weight: var(--weight-bold);
  color: var(--text-primary);
  letter-spacing: -0.4px;
  outline: none;
  line-height: 1.15;
}
.redit__title h1:focus {
  color: var(--brand-300);
}
.redit__title p {
  margin: 4px 0 0;
  font-size: 11px;
  color: var(--text-tertiary);
  font-weight: var(--weight-medium);
}
.redit__start {
  padding: 10px 16px;
  border-radius: var(--radius-pill);
  border: none;
  background: var(--brand-500);
  color: var(--surface-0);
  font-family: inherit;
  font-weight: var(--weight-bold);
  font-size: 13px;
  cursor: pointer;
}
.redit__start:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.redit__day {
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.redit__day-lab {
  font-size: 9px;
  font-weight: var(--weight-bold);
  letter-spacing: 0.8px;
  color: var(--text-tertiary);
  text-transform: uppercase;
}
.redit__day-pills {
  display: grid;
  grid-template-columns: repeat(8, 1fr);
  gap: 6px;
}
.day-pill {
  padding: 8px 0;
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-pill);
  background: var(--surface-2);
  color: var(--text-secondary);
  font-family: inherit;
  font-size: 12px;
  font-weight: var(--weight-semibold);
  cursor: pointer;
}
.day-pill--active {
  background: var(--brand-500);
  border-color: var(--brand-500);
  color: var(--surface-0);
  font-weight: var(--weight-bold);
}

.redit__exs {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.rex {
  display: grid;
  grid-template-columns: auto 44px 1fr auto;
  gap: 10px;
  align-items: center;
  padding: 10px;
  background: var(--surface-1);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-md);
}
.rex__order {
  display: flex;
  flex-direction: column;
  gap: 2px;
}
.rex__order button {
  width: 22px;
  height: 20px;
  border-radius: var(--radius-xs);
  border: 1px solid var(--border-subtle);
  background: transparent;
  color: var(--text-tertiary);
  font-size: 11px;
  cursor: pointer;
}
.rex__order button:disabled {
  opacity: 0.3;
  cursor: not-allowed;
}
.rex__img {
  display: grid;
  place-items: center;
  width: 44px;
  height: 44px;
  border-radius: var(--radius-sm);
  background: var(--surface-3);
  color: var(--text-tertiary);
  overflow: hidden;
}
.rex__img img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.rex__img svg {
  width: 22px;
  height: 22px;
}
.rex__body {
  display: flex;
  flex-direction: column;
  gap: 6px;
  min-width: 0;
}
.rex__name {
  margin: 0;
  font-size: 14px;
  font-weight: var(--weight-semibold);
  color: var(--text-primary);
  line-height: 1.2;
}
.rex__inputs {
  display: flex;
  gap: 6px;
}
.rex__inputs label {
  display: flex;
  flex-direction: column;
  gap: 2px;
  flex: 1;
  min-width: 0;
}
.rex__inputs span {
  font-size: 9px;
  font-weight: var(--weight-bold);
  letter-spacing: 0.5px;
  color: var(--text-tertiary);
  text-transform: uppercase;
}
.rex__inputs input {
  width: 100%;
  padding: 6px 8px;
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-sm);
  background: var(--surface-2);
  color: var(--text-primary);
  font-family: inherit;
  font-size: 13px;
  font-weight: var(--weight-semibold);
}
.rex__inputs input:focus {
  outline: none;
  border-color: var(--brand-500);
}
.rex__remove {
  background: transparent;
  border: none;
  color: var(--text-tertiary);
  font-size: 18px;
  cursor: pointer;
  padding: 4px 6px;
}
.rex__remove:hover {
  color: var(--danger);
}

.redit__add {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 14px;
  border: 1.5px dashed var(--border-default);
  border-radius: var(--radius-md);
  background: transparent;
  color: var(--text-secondary);
  font-family: inherit;
  font-size: 13px;
  font-weight: var(--weight-semibold);
  cursor: pointer;
}
.redit__add:hover {
  border-color: var(--brand-500);
  color: var(--brand-300);
}
.redit__add-ic {
  display: inline-grid;
  place-items: center;
  width: 22px;
  height: 22px;
  border-radius: var(--radius-pill);
  background: var(--brand-glow);
  color: var(--brand-400);
  font-size: 14px;
  font-weight: var(--weight-bold);
}

.redit__delete {
  margin-top: 8px;
  padding: 10px;
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-pill);
  background: transparent;
  color: var(--text-tertiary);
  font-family: inherit;
  font-size: 12px;
  cursor: pointer;
}
.redit__delete:hover {
  color: var(--danger);
  border-color: var(--danger);
}
</style>
