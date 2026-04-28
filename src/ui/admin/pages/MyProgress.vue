<template>
  <section class="progress">
    <header class="progress__head">
      <h1>Mi progreso</h1>
    </header>

    <p v-if="error" class="progress__error">{{ error }}</p>

    <article class="progress__card">
      <header class="progress__card-head">
        <h2>Peso corporal</h2>
        <small v-if="weightSeries.length">
          {{ weightSeries.length }} registros
        </small>
      </header>
      <LineChart
        v-if="weightSeries.length"
        :series="[
          {
            label: 'Peso (kg)',
            color: '#4f8cff',
            points: weightSeries.map((p) => ({ date: p.date, value: p.weight_kg })),
          },
        ]"
        unit="kg"
      />
      <p v-else class="progress__empty">
        Registra medidas en <RouterLink to="/medidas">/medidas</RouterLink> para ver tu evolución.
      </p>
    </article>

    <article class="progress__card">
      <header class="progress__card-head">
        <h2>Fuerza por ejercicio</h2>
        <select
          v-if="exerciseOptions.length"
          v-model.number="selectedExerciseId"
          class="progress__select"
        >
          <option :value="0" disabled>Elegí un ejercicio…</option>
          <option v-for="o in exerciseOptions" :key="o.id" :value="o.id">
            {{ o.name }} ({{ o.sessions }} sesiones)
          </option>
        </select>
      </header>

      <template v-if="exerciseOptions.length === 0">
        <p class="progress__empty">
          Termina al menos una sesión con series completas para ver este gráfico.
        </p>
      </template>

      <template v-else-if="!selectedExerciseId">
        <p class="progress__empty">Elegí un ejercicio en el selector.</p>
      </template>

      <template v-else-if="strengthSeries.length === 0">
        <p class="progress__empty">Sin datos para este ejercicio todavía.</p>
      </template>

      <template v-else>
        <LineChart
          :series="[
            {
              label: 'Peso máx',
              color: '#4f8cff',
              points: strengthSeries.map((p) => ({ date: p.date, value: p.max_weight })),
            },
            {
              label: '1RM estimado',
              color: '#ffb454',
              points: strengthSeries.map((p) => ({ date: p.date, value: p.best_1rm })),
            },
          ]"
          unit="kg"
        />
        <p class="progress__hint">
          1RM estimado con fórmula de Epley: <em>peso × (1 + reps/30)</em>.
        </p>
      </template>
    </article>
  </section>
</template>

<script setup lang="ts">
import { onMounted, ref, watch } from "vue";
import { useProgress } from "@/composables/useProgress";
import LineChart from "@/ui/admin/components/LineChart.vue";

const {
  weightSeries,
  exerciseOptions,
  strengthSeries,
  error,
  loadAll,
  loadStrengthSeries,
} = useProgress();

const selectedExerciseId = ref<number>(0);

onMounted(async () => {
  await loadAll();
  const first = exerciseOptions.value[0];
  if (first && !selectedExerciseId.value) {
    selectedExerciseId.value = first.id;
  }
});

watch(selectedExerciseId, async (id) => {
  if (id) await loadStrengthSeries(id);
});
</script>

<style scoped>
.progress {
  max-width: 640px;
  margin: 0 auto;
  padding: 4px 20px 24px;
  display: flex;
  flex-direction: column;
  gap: 16px;
}
.progress__head h1 {
  margin: 0;
  font-family: var(--font-display);
  font-size: 26px;
  font-weight: var(--weight-bold);
  letter-spacing: -0.5px;
  color: var(--text-primary);
}
.progress__error {
  margin: 0;
  padding: 10px 12px;
  border-radius: var(--radius-sm);
  background: var(--danger-glow);
  color: var(--danger);
  font-size: 13px;
}
.progress__card {
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-lg);
  background: var(--surface-1);
  padding: 18px;
  display: flex;
  flex-direction: column;
  gap: 12px;
}
.progress__card-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  flex-wrap: wrap;
}
.progress__card-head h2 {
  margin: 0;
  font-family: var(--font-display);
  font-size: 16px;
  font-weight: var(--weight-semibold);
  color: var(--text-primary);
}
.progress__card-head small {
  color: var(--text-tertiary);
  font-size: 11px;
  font-weight: var(--weight-semibold);
  letter-spacing: 0.5px;
}
.progress__select {
  width: 100%;
  padding: 10px 12px;
  border-radius: var(--radius-md);
  border: 1px solid var(--border-subtle);
  background: var(--surface-2);
  color: var(--text-primary);
  font-family: inherit;
  font-size: 13px;
}
.progress__select:focus {
  outline: none;
  border-color: var(--brand-500);
  box-shadow: 0 0 0 2px var(--brand-glow);
}
.progress__empty {
  color: var(--text-tertiary);
  text-align: center;
  padding: 24px 0;
  font-size: 14px;
}
.progress__empty a {
  color: var(--brand-400);
}
.progress__hint {
  margin: 0;
  font-size: 11px;
  color: var(--text-tertiary);
}
</style>
