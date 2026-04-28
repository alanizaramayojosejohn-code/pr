<template>
  <section class="home">
    <header class="home__greet">
      <span class="home__date">{{ dateLabel }}</span>
      <h1 class="home__hello">Hola, {{ firstName }}</h1>
    </header>

    <div v-if="isAdmin && (expiringSoon.length || expiredBlocked.length)" class="home__alerts">
      <RouterLink v-if="expiredBlocked.length" to="/usuarios" class="alert alert--danger">
        <strong>{{ expiredBlocked.length }}</strong>
        <span>cuenta(s) bloqueadas por vencimiento</span>
      </RouterLink>
      <RouterLink v-if="expiringSoon.length" to="/usuarios" class="alert alert--warning">
        <strong>{{ expiringSoon.length }}</strong>
        <span>cuenta(s) expiran en ≤ 7 días</span>
      </RouterLink>
    </div>

    <article v-if="todayRoutine" class="hero">
      <header class="hero__top">
        <span class="pill">
          <span class="pill__dot"></span>
          RUTINA DE HOY · {{ todayLabel.toUpperCase() }}
        </span>
      </header>
      <div class="hero__title-block">
        <h2 class="hero__title">{{ todayRoutine.name }}</h2>
        <p class="hero__meta">
          {{ todayRoutine.routine_exercises?.length ?? 0 }} ejercicios · {{ totalSets }} series
        </p>
      </div>
      <button
        class="hero__cta"
        :disabled="starting || !(todayRoutine.routine_exercises?.length)"
        @click="onStartToday"
      >
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polygon points="6 4 20 12 6 20 6 4" fill="currentColor"/></svg>
        {{ starting ? "Empezando…" : "Empezar rutina" }}
      </button>
    </article>

    <div v-else-if="!isAdmin" class="hero hero--empty">
      <span class="pill">HOY · {{ todayLabel.toUpperCase() }}</span>
      <p class="hero__empty-text">
        No tenés rutina asignada para hoy.
      </p>
      <RouterLink to="/rutinas" class="hero__cta hero__cta--outline">
        Elegir una rutina
      </RouterLink>
    </div>

    <section v-if="isAdmin" class="shortcuts">
      <h3 class="shortcuts__title">Administración</h3>
      <div class="shortcuts__grid">
        <RouterLink to="/ejercicios" class="shortcut">
          <span class="shortcut__icon">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 4v16M18 4v16M3 8h3M3 16h3M18 8h3M18 16h3M6 12h12"/></svg>
          </span>
          <span class="shortcut__label">Ejercicios</span>
        </RouterLink>
        <RouterLink to="/usuarios" class="shortcut">
          <span class="shortcut__icon">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="8.5" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>
          </span>
          <span class="shortcut__label">Usuarios</span>
        </RouterLink>
      </div>
    </section>
  </section>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import { useRouter } from "vue-router";
import { useAuth } from "@/composables/useAuth";
import { useUsers } from "@/composables/useUsers";
import { useRoutines, dayLabel } from "@/composables/useRoutines";
import { useWorkout } from "@/composables/useWorkout";

const { profile, isAdmin } = useAuth();
const { fetchUsers, expiringSoon, expiredBlocked } = useUsers();
const { routines, fetchRoutines } = useRoutines();
const { startFromRoutine } = useWorkout();
const router = useRouter();
const starting = ref(false);

const todayDow = new Date().getDay();
const todayLabel = computed(() => dayLabel(todayDow));
const todayRoutine = computed(() =>
  routines.value.find((r) => r.day_of_week === todayDow)
);

const totalSets = computed(() => {
  const r = todayRoutine.value;
  if (!r?.routine_exercises) return 0;
  return r.routine_exercises.reduce((s, re) => s + (re.target_sets ?? 0), 0);
});

const firstName = computed(() => {
  const email = profile.value?.email ?? "";
  const local = email.split("@")[0] ?? "";
  return local.charAt(0).toUpperCase() + local.slice(1);
});

const dateLabel = computed(() => {
  const d = new Date();
  return d
    .toLocaleDateString("es-AR", { weekday: "long", day: "numeric", month: "long" })
    .toUpperCase();
});

onMounted(() => {
  if (isAdmin.value) fetchUsers();
  if (!isAdmin.value) fetchRoutines();
});

async function onStartToday() {
  if (!todayRoutine.value) return;
  starting.value = true;
  const s = await startFromRoutine(todayRoutine.value.id);
  starting.value = false;
  if (s) router.push({ name: "entrenar", params: { sessionId: s.id } });
}
</script>

<style scoped>
.home {
  max-width: 640px;
  margin: 0 auto;
  padding: 4px 20px 24px;
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.home__greet {
  display: flex;
  flex-direction: column;
  gap: 2px;
}
.home__date {
  font-size: 10px;
  font-weight: var(--weight-bold);
  letter-spacing: 1.2px;
  color: var(--text-tertiary);
}
.home__hello {
  margin: 0;
  font-family: var(--font-display);
  font-size: 22px;
  font-weight: var(--weight-bold);
  letter-spacing: -0.4px;
  color: var(--text-primary);
}

.home__alerts {
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.alert {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 12px 14px;
  border-radius: var(--radius-md);
  text-decoration: none;
  font-size: 13px;
}
.alert strong {
  font-family: var(--font-display);
  font-size: 18px;
}
.alert--danger {
  background: var(--danger-glow);
  color: var(--danger);
  border: 1px solid #ef535066;
}
.alert--warning {
  background: var(--warning-glow);
  color: var(--warning);
  border: 1px solid #f59e0b66;
}

.hero {
  display: flex;
  flex-direction: column;
  gap: 14px;
  padding: 20px;
  background: var(--surface-1);
  border: 1px solid var(--brand-glow);
  border-radius: var(--radius-xl);
}
.hero__top {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
.pill {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 5px 10px;
  border-radius: var(--radius-pill);
  background: var(--brand-glow);
  color: var(--brand-300);
  font-family: var(--font-body);
  font-size: 10px;
  font-weight: var(--weight-bold);
  letter-spacing: 1px;
}
.pill__dot {
  width: 6px;
  height: 6px;
  border-radius: var(--radius-pill);
  background: var(--brand-400);
}
.hero__title-block {
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.hero__title {
  margin: 0;
  font-family: var(--font-display);
  font-size: 22px;
  font-weight: var(--weight-bold);
  letter-spacing: -0.4px;
  color: var(--text-primary);
}
.hero__meta {
  margin: 0;
  font-size: 13px;
  color: var(--text-secondary);
}
.hero__cta {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  height: 52px;
  border: none;
  border-radius: var(--radius-pill);
  background: var(--brand-500);
  color: var(--surface-0);
  font-family: var(--font-body);
  font-size: 15px;
  font-weight: var(--weight-bold);
  cursor: pointer;
  text-decoration: none;
}
.hero__cta svg {
  width: 16px;
  height: 16px;
}
.hero__cta:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
.hero__cta--outline {
  background: transparent;
  color: var(--brand-300);
  border: 1px solid var(--brand-500);
}
.hero--empty {
  border-color: var(--border-subtle);
}
.hero__empty-text {
  margin: 0;
  color: var(--text-secondary);
  font-size: 14px;
}

.shortcuts {
  display: flex;
  flex-direction: column;
  gap: 10px;
}
.shortcuts__title {
  margin: 0;
  font-family: var(--font-body);
  font-size: 15px;
  font-weight: var(--weight-semibold);
  color: var(--text-primary);
}
.shortcuts__grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 10px;
}
.shortcut {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 14px;
  border-radius: var(--radius-lg);
  background: var(--surface-1);
  border: 1px solid var(--border-subtle);
  color: var(--text-primary);
  text-decoration: none;
}
.shortcut__icon {
  width: 36px;
  height: 36px;
  display: grid;
  place-items: center;
  border-radius: var(--radius-sm);
  background: var(--surface-2);
  color: var(--brand-400);
}
.shortcut__icon svg {
  width: 18px;
  height: 18px;
}
.shortcut__label {
  font-size: 14px;
  font-weight: var(--weight-semibold);
}
</style>
