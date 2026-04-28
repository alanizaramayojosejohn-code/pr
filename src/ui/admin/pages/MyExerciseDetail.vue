<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import { useExercise, type Exercise } from "@/composables/useExercise";
import { useCategories } from "@/composables/useCategories";
import { useRoutines } from "@/composables/useRoutines";

const route = useRoute();
const router = useRouter();

const { getById } = useExercise();
const { categories, fetchCategories } = useCategories();
const { fetchRoutines, addExerciseToRoutine } = useRoutines();

const id = computed(() => Number(route.params.id));
const routineId = computed(() =>
  typeof route.query.routine === "string" ? route.query.routine : null
);
const isPicker = computed(() => routineId.value !== null);

const ex = ref<Exercise | null>(null);
const loading = ref(true);
const error = ref<string | null>(null);
const adding = ref(false);
const expanded = ref(false);

const sets = ref(3);
const reps = ref(10);
const rest = ref(60);

// GIF frame alternation for hero
const frame = ref<0 | 1>(0);
let frameTimer: number | undefined;
const hasTwoFrames = computed(() => !!(ex.value?.image_url && ex.value?.image_url_2));
const heroSrc = computed(() => {
  if (!ex.value) return null;
  if (!hasTwoFrames.value) return ex.value.image_url || null;
  return frame.value === 0 ? ex.value.image_url : ex.value.image_url_2;
});

function startFrameLoop() {
  stopFrameLoop();
  if (!hasTwoFrames.value) return;
  frameTimer = window.setInterval(() => {
    frame.value = frame.value === 0 ? 1 : 0;
  }, 600);
}
function stopFrameLoop() {
  if (frameTimer !== undefined) {
    window.clearInterval(frameTimer);
    frameTimer = undefined;
  }
}

const category = computed(() =>
  categories.value.find((c) => c.id === ex.value?.category_id) ?? null
);

const levelLabel = computed(() => {
  const map: Record<string, string> = {
    beginner: "Principiante",
    intermediate: "Intermedio",
    expert: "Avanzado",
  };
  return ex.value?.level ? map[ex.value.level] ?? ex.value.level : null;
});

const mechanicLabel = computed(() => {
  const map: Record<string, string> = {
    compound: "Compuesto",
    isolation: "Aislado",
  };
  return ex.value?.mechanic ? map[ex.value.mechanic] ?? ex.value.mechanic : null;
});

const equipmentLabel = computed(() => {
  if (!ex.value?.equipment) return null;
  const e = ex.value.equipment.toLowerCase();
  const map: Record<string, string> = {
    barbell: "Barra",
    dumbbell: "Mancuerna",
    cable: "Polea",
    machine: "Máquina",
    "body only": "Peso corporal",
    kettlebells: "Pesa rusa",
    bands: "Bandas",
    "medicine ball": "Balón medicinal",
    "exercise ball": "Pelota",
    "foam roll": "Rodillo",
    "e-z curl bar": "Barra Z",
    other: "Otro",
  };
  return map[e] ?? ex.value.equipment;
});

const steps = computed<string[]>(() => {
  if (!ex.value?.description) return [];
  return ex.value.description
    .split(/\n\n+/)
    .map((s) => s.trim())
    .filter(Boolean);
});
const visibleSteps = computed(() =>
  expanded.value ? steps.value : steps.value.slice(0, 2)
);

onMounted(async () => {
  await fetchCategories();
  if (isPicker.value) await fetchRoutines();
  if (!Number.isFinite(id.value)) {
    router.replace({ name: "ejercicios" });
    return;
  }
  const row = await getById(id.value);
  if (!row) {
    error.value = "No se encontró el ejercicio";
    loading.value = false;
    return;
  }
  ex.value = row;
  rest.value = row.rest_seconds ?? 60;
  loading.value = false;
  startFrameLoop();
});

onBeforeUnmount(stopFrameLoop);
watch(() => [ex.value?.image_url, ex.value?.image_url_2], () => {
  frame.value = 0;
  startFrameLoop();
});

function clamp(n: number, min: number, max: number) {
  return Math.max(min, Math.min(max, n));
}
function bumpSets(d: number) { sets.value = clamp(sets.value + d, 1, 20); }
function bumpReps(d: number) { reps.value = clamp(reps.value + d, 1, 50); }
function bumpRest(d: number) { rest.value = clamp(rest.value + d, 0, 600); }

async function addToRoutine() {
  if (!ex.value || !routineId.value || adding.value) return;
  adding.value = true;
  const ok = await addExerciseToRoutine(routineId.value, ex.value, {
    target_sets: sets.value,
    target_reps: reps.value,
    rest_seconds: rest.value,
  });
  adding.value = false;
  if (ok) {
    router.push({
      name: "category-exercises",
      params: { categoryId: ex.value.category_id ?? "uncategorized" },
      query: { picker: routineId.value },
    });
  } else {
    error.value = "No se pudo agregar el ejercicio a la rutina.";
  }
}

function goBack() {
  router.back();
}
</script>

<template>
  <section class="ed">
    <header class="ed__head">
      <button class="ed__icon-btn" @click="goBack" aria-label="Volver">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m15 18-6-6 6-6"/></svg>
      </button>
      <div class="ed__title">
        <h1>{{ ex?.name ?? "Ejercicio" }}</h1>
        <p class="ed__sub">
          <template v-if="category">{{ category.name }}</template>
          <template v-if="category && levelLabel"> · </template>
          <template v-if="levelLabel">{{ levelLabel }}</template>
          <template v-if="!category && !levelLabel">&nbsp;</template>
        </p>
      </div>
    </header>

    <p v-if="error" class="ed__error">{{ error }}</p>
    <p v-if="loading" class="ed__loading">Cargando…</p>

    <template v-if="!loading && ex">
      <div class="hero">
        <img v-if="heroSrc" :src="heroSrc" :alt="ex.name" />
        <div v-else class="hero__placeholder">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="9" cy="9" r="2"/><path d="m21 15-3.086-3.086a2 2 0 0 0-2.828 0L6 21"/></svg>
        </div>
        <span v-if="hasTwoFrames" class="hero__badge">
          <span class="hero__dot"></span>GIF
        </span>
        <a
          v-if="ex.video_url"
          class="hero__play"
          :href="ex.video_url"
          target="_blank"
          rel="noopener"
          aria-label="Ver video"
        >
          <svg viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>
        </a>
      </div>

      <div class="chips">
        <span v-if="equipmentLabel" class="chip chip--strong">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m6.5 6.5 11 11"/><path d="m21 21-1-1"/><path d="m3 3 1 1"/><path d="m18 22 4-4"/><path d="m2 6 4-4"/><path d="m3 10 7-7"/><path d="m14 21 7-7"/></svg>
          {{ equipmentLabel }}
        </span>
        <span v-if="mechanicLabel" class="chip chip--strong">{{ mechanicLabel }}</span>
        <span v-if="levelLabel && category" class="chip">{{ category.name }}</span>
      </div>

      <section v-if="steps.length > 0" class="card">
        <h2 class="card__head">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="10" x2="21" y1="6" y2="6"/><line x1="10" x2="21" y1="12" y2="12"/><line x1="10" x2="21" y1="18" y2="18"/><path d="M4 6h1v4"/><path d="M4 10h2"/><path d="M6 18H4c0-1 2-2 2-3s-1-1.5-2-1"/></svg>
          Cómo hacerlo
        </h2>
        <p v-for="(s, i) in visibleSteps" :key="i" class="card__step">{{ s }}</p>
        <button
          v-if="steps.length > 2"
          type="button"
          class="card__more"
          @click="expanded = !expanded"
        >
          {{ expanded ? "Ver menos" : `Ver los ${steps.length} pasos` }}
          <svg
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            :class="{ 'rot': expanded }"
          ><path d="m6 9 6 6 6-6"/></svg>
        </button>
      </section>

      <section v-if="isPicker" class="card card--accent">
        <h2 class="card__head">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="20" cy="7" r="3"/><circle cx="4" cy="17" r="3"/><path d="M20 10v5a2 2 0 0 1-2 2H7"/><path d="M4 14V9a2 2 0 0 1 2-2h9"/></svg>
          Configurar para tu rutina
        </h2>

        <div class="cfg-row">
          <span class="cfg-row__label">Series</span>
          <div class="stepper">
            <button type="button" class="stepper__btn" @click="bumpSets(-1)" aria-label="Menos series">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><path d="M5 12h14"/></svg>
            </button>
            <span class="stepper__val">{{ sets }}</span>
            <button type="button" class="stepper__btn stepper__btn--on" @click="bumpSets(1)" aria-label="Más series">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg>
            </button>
          </div>
        </div>

        <div class="cfg-row">
          <span class="cfg-row__label">Repeticiones</span>
          <div class="stepper">
            <button type="button" class="stepper__btn" @click="bumpReps(-1)" aria-label="Menos reps">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><path d="M5 12h14"/></svg>
            </button>
            <span class="stepper__val">{{ reps }}</span>
            <button type="button" class="stepper__btn stepper__btn--on" @click="bumpReps(1)" aria-label="Más reps">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg>
            </button>
          </div>
        </div>

        <div class="cfg-row">
          <span class="cfg-row__label">Descanso</span>
          <div class="stepper">
            <button type="button" class="stepper__btn" @click="bumpRest(-15)" aria-label="Menos descanso">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><path d="M5 12h14"/></svg>
            </button>
            <span class="stepper__val">{{ rest }}<span class="stepper__unit">s</span></span>
            <button type="button" class="stepper__btn stepper__btn--on" @click="bumpRest(15)" aria-label="Más descanso">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg>
            </button>
          </div>
        </div>
      </section>
    </template>

    <footer v-if="!loading && ex && isPicker" class="ed__footer">
      <button class="ed__icon-btn ed__footer-back" @click="goBack" aria-label="Volver">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m15 18-6-6 6-6"/></svg>
      </button>
      <button class="ed__cta" :disabled="adding" @click="addToRoutine">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M12 5v14M5 12h14"/></svg>
        {{ adding ? "Agregando…" : "Agregar a rutina" }}
      </button>
    </footer>
  </section>
</template>

<style scoped>
.ed {
  max-width: 720px;
  margin: 0 auto;
  padding: 4px 20px 120px;
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.ed__head {
  display: flex;
  align-items: center;
  gap: 12px;
}
.ed__icon-btn {
  width: 40px;
  height: 40px;
  border-radius: var(--radius-pill);
  border: 1px solid var(--border-subtle);
  background: var(--surface-1);
  color: var(--text-primary);
  display: grid;
  place-items: center;
  cursor: pointer;
  flex-shrink: 0;
}
.ed__icon-btn svg { width: 18px; height: 18px; }
.ed__icon-btn:hover { border-color: var(--brand-500); color: var(--brand-400); }

.ed__title { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 2px; }
.ed__title h1 {
  margin: 0;
  font-family: var(--font-display);
  font-size: 22px;
  font-weight: var(--weight-bold);
  letter-spacing: -0.4px;
  color: var(--text-primary);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.ed__sub {
  margin: 0;
  font-size: 13px;
  color: var(--text-tertiary);
}

.ed__error {
  margin: 0;
  padding: 10px 12px;
  border-radius: var(--radius-sm);
  background: var(--danger-glow);
  color: var(--danger);
  font-size: 13px;
}
.ed__loading {
  margin: 0;
  padding: 40px 0;
  text-align: center;
  color: var(--text-tertiary);
}

/* Hero */
.hero {
  position: relative;
  aspect-ratio: 4 / 3;
  border-radius: var(--radius-lg);
  overflow: hidden;
  background: var(--surface-1);
  border: 1px solid var(--border-subtle);
}
.hero img {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.hero__placeholder {
  position: absolute;
  inset: 0;
  display: grid;
  place-items: center;
  color: var(--brand-400);
}
.hero__placeholder svg { width: 48px; height: 48px; }
.hero__badge {
  position: absolute;
  top: 16px;
  left: 16px;
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 6px 10px;
  border-radius: var(--radius-pill);
  background: rgba(0, 0, 0, 0.6);
  color: var(--text-primary);
  font-size: 11px;
  font-weight: var(--weight-bold);
  letter-spacing: 0.5px;
}
.hero__dot {
  width: 8px;
  height: 8px;
  border-radius: var(--radius-pill);
  background: var(--brand-500);
}
.hero__play {
  position: absolute;
  right: 16px;
  bottom: 16px;
  width: 44px;
  height: 44px;
  border-radius: var(--radius-pill);
  background: rgba(0, 0, 0, 0.6);
  display: grid;
  place-items: center;
  color: var(--text-primary);
  text-decoration: none;
}
.hero__play svg { width: 18px; height: 18px; }
.hero__play:hover { background: var(--brand-500); color: var(--surface-0); }

/* Chips row */
.chips {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}
.chip {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 6px 10px;
  border-radius: var(--radius-pill);
  background: var(--surface-1);
  border: 1px solid var(--border-subtle);
  color: var(--text-tertiary);
  font-size: 12px;
  font-weight: var(--weight-medium);
}
.chip--strong { color: var(--text-primary); font-weight: var(--weight-semibold); }
.chip svg { width: 12px; height: 12px; color: var(--brand-400); }

/* Cards */
.card {
  background: var(--surface-1);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-lg);
  padding: 14px 16px;
  display: flex;
  flex-direction: column;
  gap: 10px;
}
.card--accent { border-color: var(--brand-glow); }
.card__head {
  margin: 0;
  display: flex;
  align-items: center;
  gap: 8px;
  font-family: var(--font-body);
  font-size: 13px;
  font-weight: var(--weight-bold);
  color: var(--text-primary);
}
.card__head svg { width: 14px; height: 14px; color: var(--brand-400); }
.card__step {
  margin: 0;
  font-size: 13px;
  line-height: 1.45;
  color: var(--text-primary);
}
.card__more {
  margin-top: 2px;
  align-self: flex-start;
  display: flex;
  align-items: center;
  gap: 6px;
  background: transparent;
  border: none;
  padding: 0;
  color: var(--brand-400);
  font-family: inherit;
  font-size: 13px;
  font-weight: var(--weight-semibold);
  cursor: pointer;
}
.card__more svg {
  width: 14px;
  height: 14px;
  transition: transform 150ms ease;
}
.card__more svg.rot { transform: rotate(180deg); }

/* Config / steppers */
.cfg-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}
.cfg-row__label {
  font-size: 13px;
  font-weight: var(--weight-medium);
  color: var(--text-secondary);
}
.stepper {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 4px;
  border-radius: 10px;
  background: var(--surface-2);
}
.stepper__btn {
  width: 28px;
  height: 28px;
  border-radius: 8px;
  background: var(--surface-3);
  color: var(--text-primary);
  border: none;
  cursor: pointer;
  display: grid;
  place-items: center;
}
.stepper__btn svg { width: 14px; height: 14px; }
.stepper__btn:hover { background: var(--border-strong); }
.stepper__btn--on {
  background: var(--brand-500);
  color: var(--surface-0);
}
.stepper__btn--on:hover { background: var(--brand-400); }
.stepper__val {
  min-width: 44px;
  text-align: center;
  font-size: 15px;
  font-weight: var(--weight-bold);
  color: var(--text-primary);
}
.stepper__unit {
  margin-left: 2px;
  font-size: 11px;
  font-weight: var(--weight-medium);
  color: var(--text-tertiary);
}

/* Footer CTA (only picker) */
.ed__footer {
  position: fixed;
  left: 0;
  right: 0;
  bottom: 0;
  padding: 16px 20px calc(24px + env(safe-area-inset-bottom));
  background: var(--surface-0);
  border-top: 1px solid var(--border-subtle);
  display: flex;
  gap: 10px;
  align-items: center;
  justify-content: center;
  z-index: 30;
}
.ed__footer-back {
  width: 50px;
  height: 50px;
  border-radius: var(--radius-pill);
  background: var(--surface-1);
  border: 1px solid var(--border-default);
}
.ed__cta {
  flex: 1;
  max-width: 320px;
  height: 50px;
  border-radius: var(--radius-pill);
  border: none;
  background: var(--brand-500);
  color: var(--surface-0);
  font-family: inherit;
  font-weight: var(--weight-bold);
  font-size: 15px;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  box-shadow: 0 10px 24px rgba(0, 0, 0, 0.45);
}
.ed__cta svg { width: 18px; height: 18px; }
.ed__cta:disabled { opacity: 0.5; cursor: not-allowed; }
</style>
