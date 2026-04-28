<template>
  <section class="history">
    <header class="history__head">
      <h1>Historial</h1>
      <small v-if="sessions.length" class="history__count">
        {{ sessions.length }} sesiones terminadas
      </small>
    </header>

    <p v-if="error" class="history__error">{{ error }}</p>

    <p v-if="!loading && sessions.length === 0" class="history__empty">
      Todavía no terminaste ninguna sesión. Cuando finalices una en
      <RouterLink to="/rutinas">/rutinas</RouterLink> aparecerá aquí.
    </p>

    <ul v-if="sessions.length" class="history__list">
      <li v-for="s in sessions" :key="s.id" class="session">
        <button class="session__head" @click="toggle(s.id)">
          <div class="session__title">
            <strong>{{ formatDate(s.started_at) }}</strong>
            <span class="session__routine">{{ s.routine_name ?? "Sesión libre" }}</span>
          </div>
          <div class="session__stats">
            <span>{{ formatDuration(s.duration_sec) }}</span>
            <span>· {{ s.exercise_count }} ej.</span>
            <span>· {{ s.total_sets }} sets</span>
            <span v-if="s.total_volume > 0">· {{ formatVolume(s.total_volume) }} kg</span>
          </div>
          <span class="session__chev" :class="{ 'session__chev--open': expanded === s.id }">›</span>
        </button>

        <div v-if="expanded === s.id" class="session__body">
          <article v-for="ex in s.exercises" :key="ex.exercise_id" class="ex-group">
            <header class="ex-group__head">
              <h3>{{ ex.exercise_name }}</h3>
              <small>
                <span v-if="ex.max_weight !== null">máx {{ ex.max_weight }} kg · </span>
                {{ ex.sets.length }} sets
                <span v-if="ex.total_volume > 0"> · {{ formatVolume(ex.total_volume) }} kg vol.</span>
              </small>
            </header>
            <table class="ex-group__sets">
              <thead>
                <tr>
                  <th>#</th>
                  <th>kg</th>
                  <th>reps</th>
                  <th>descanso</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="set in ex.sets" :key="set.set_number" :class="{ 'ex-group__set--empty': set.weight === null || set.reps === null }">
                  <td>{{ set.set_number }}</td>
                  <td>{{ set.weight ?? "—" }}</td>
                  <td>{{ set.reps ?? "—" }}</td>
                  <td>{{ set.rest_seconds_used !== null ? `${set.rest_seconds_used}s` : "—" }}</td>
                </tr>
              </tbody>
            </table>
          </article>

          <div class="session__actions">
            <button class="session__delete" @click="onDelete(s.id)">Eliminar sesión</button>
          </div>
        </div>
      </li>
    </ul>
  </section>
</template>

<script setup lang="ts">
import { onMounted, ref } from "vue";
import { useHistory } from "@/composables/useHistory";

const { sessions, loading, error, fetchSessions, deleteSession } = useHistory();
const expanded = ref<string | null>(null);

onMounted(fetchSessions);

function toggle(id: string) {
  expanded.value = expanded.value === id ? null : id;
}

function formatDate(iso: string): string {
  const d = new Date(iso);
  return d.toLocaleDateString("es-AR", {
    day: "2-digit",
    month: "short",
    year: "numeric",
    weekday: "short",
  });
}

function formatDuration(sec: number): string {
  const h = Math.floor(sec / 3600);
  const m = Math.floor((sec % 3600) / 60);
  if (h > 0) return `${h}h ${m}m`;
  return `${m} min`;
}

function formatVolume(v: number): string {
  if (v >= 1000) return `${(v / 1000).toFixed(1)}k`;
  return String(Math.round(v));
}

async function onDelete(id: string) {
  if (!confirm("¿Eliminar esta sesión y sus series? No se puede deshacer.")) return;
  const ok = await deleteSession(id);
  if (ok && expanded.value === id) expanded.value = null;
}
</script>

<style scoped>
.history {
  max-width: 640px;
  margin: 0 auto;
  padding: 4px 20px 24px;
  display: flex;
  flex-direction: column;
  gap: 16px;
}
.history__head {
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.history__head h1 {
  margin: 0;
  font-family: var(--font-display);
  font-size: 26px;
  font-weight: var(--weight-bold);
  letter-spacing: -0.5px;
  color: var(--text-primary);
}
.history__count {
  color: var(--text-tertiary);
  font-size: 12px;
}
.history__error {
  margin: 0;
  padding: 10px 12px;
  border-radius: var(--radius-sm);
  background: var(--danger-glow);
  color: var(--danger);
  font-size: 13px;
}
.history__empty {
  color: var(--text-tertiary);
  text-align: center;
  padding: 48px 16px;
  font-size: 14px;
}
.history__empty a {
  color: var(--brand-400);
}
.history__list {
  list-style: none;
  padding: 0;
  margin: 0;
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.session {
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-md);
  background: var(--surface-1);
  overflow: hidden;
}
.session__head {
  width: 100%;
  display: grid;
  grid-template-columns: 1fr auto;
  align-items: center;
  gap: 12px;
  padding: 14px;
  background: transparent;
  color: inherit;
  border: none;
  cursor: pointer;
  text-align: left;
  font-family: inherit;
}
.session__head:hover {
  background: #ffffff06;
}
.session__title {
  display: flex;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
}
.session__title strong {
  font-family: var(--font-body);
  font-size: 14px;
  font-weight: var(--weight-semibold);
  color: var(--text-primary);
}
.session__routine {
  color: var(--text-tertiary);
  font-size: 12px;
}
.session__stats {
  display: flex;
  gap: 6px;
  color: var(--text-tertiary);
  font-size: 11px;
  font-variant-numeric: tabular-nums;
  margin-top: 4px;
  flex-wrap: wrap;
}
.session__chev {
  color: var(--text-tertiary);
  font-size: 20px;
  transition: transform 0.15s ease;
  line-height: 1;
  width: 24px;
  text-align: center;
}
.session__chev--open {
  transform: rotate(90deg);
  color: var(--brand-400);
}
.session__body {
  padding: 4px 14px 14px;
  border-top: 1px solid var(--border-subtle);
  display: flex;
  flex-direction: column;
  gap: 10px;
}
.ex-group {
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-sm);
  padding: 10px 12px;
  background: var(--surface-2);
}
.ex-group__head {
  display: flex;
  justify-content: space-between;
  align-items: baseline;
  margin-bottom: 8px;
  gap: 10px;
  flex-wrap: wrap;
}
.ex-group__head h3 {
  margin: 0;
  font-family: var(--font-body);
  font-size: 14px;
  font-weight: var(--weight-semibold);
  color: var(--text-primary);
}
.ex-group__head small {
  color: var(--text-tertiary);
  font-size: 11px;
  font-variant-numeric: tabular-nums;
}
.ex-group__sets {
  width: 100%;
  border-collapse: collapse;
  font-size: 13px;
  font-variant-numeric: tabular-nums;
}
.ex-group__sets th {
  text-align: left;
  font-weight: var(--weight-bold);
  color: var(--text-tertiary);
  font-size: 10px;
  letter-spacing: 0.8px;
  text-transform: uppercase;
  padding: 4px 6px 6px;
}
.ex-group__sets td {
  padding: 5px 6px;
  color: var(--text-secondary);
  border-top: 1px solid var(--border-subtle);
}
.ex-group__set--empty td {
  color: var(--text-disabled);
}
.session__actions {
  display: flex;
  justify-content: flex-end;
}
.session__delete {
  padding: 7px 12px;
  border-radius: var(--radius-pill);
  border: 1px solid var(--border-subtle);
  background: transparent;
  color: var(--text-tertiary);
  cursor: pointer;
  font-family: inherit;
  font-size: 12px;
}
.session__delete:hover {
  color: var(--danger);
  border-color: var(--danger);
}
</style>
