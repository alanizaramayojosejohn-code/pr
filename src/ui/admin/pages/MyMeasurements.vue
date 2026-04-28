<template>
  <section class="measurements">
    <header class="measurements__head">
      <h1>Mis medidas</h1>
      <button class="measurements__new" @click="showNew = !showNew">
        {{ showNew ? "Cancelar" : "+ Nueva medida" }}
      </button>
    </header>

    <form v-if="showNew" class="measurements__form" @submit.prevent="handleCreate">
      <label class="measurements__date">
        <span>Fecha</span>
        <input v-model="newDate" type="date" required />
      </label>

      <div class="measurements__grid">
        <label v-for="f in MEASUREMENT_FIELDS" :key="f.key">
          <span>{{ f.label }} ({{ f.unit }})</span>
          <input
            v-model.number="newValues[f.key]"
            type="number"
            step="0.1"
            min="0"
            :placeholder="f.unit"
          />
        </label>
      </div>

      <label class="measurements__notes">
        <span>Notas</span>
        <textarea v-model.trim="newNotes" rows="2" placeholder="Opcional"></textarea>
      </label>

      <button type="submit" class="measurements__submit" :disabled="loading || !hasAnyValue">
        Guardar
      </button>
    </form>

    <p v-if="error" class="measurements__error">{{ error }}</p>

    <p v-if="!loading && measurements.length === 0" class="measurements__empty">
      Aún no registraste medidas. Usa "+ Nueva medida" para empezar.
    </p>

    <ul v-if="measurements.length" class="measurements__list">
      <li v-for="m in measurements" :key="m.id" class="card">
        <header class="card__head">
          <input
            class="card__date"
            type="date"
            :value="m.measured_at"
            @change="onFieldChange(m.id, 'measured_at', $event)"
          />
          <button class="card__delete" aria-label="Eliminar" @click="onDelete(m)">×</button>
        </header>

        <div class="card__grid">
          <label v-for="f in MEASUREMENT_FIELDS" :key="f.key" class="card__field">
            <span class="card__label">{{ f.label }} <small>{{ f.unit }}</small></span>
            <input
              type="number"
              step="0.1"
              min="0"
              inputmode="decimal"
              :value="m[f.key] ?? ''"
              @change="onFieldChange(m.id, f.key, $event)"
            />
          </label>
        </div>

        <label class="card__notes">
          <span class="card__label">Notas</span>
          <input
            type="text"
            :value="m.notes ?? ''"
            placeholder="—"
            @change="onFieldChange(m.id, 'notes', $event)"
          />
        </label>
      </li>
    </ul>
  </section>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref } from "vue";
import {
  useMeasurements,
  MEASUREMENT_FIELDS,
} from "@/composables/useMeasurements";
import type {
  BodyMeasurement,
  MeasurementField,
  MeasurementPayload,
} from "@/composables/useMeasurements";

const {
  measurements,
  loading,
  error,
  fetchMeasurements,
  createMeasurement,
  updateMeasurement,
  deleteMeasurement,
} = useMeasurements();

const showNew = ref(false);
const newDate = ref(new Date().toISOString().slice(0, 10));
const newNotes = ref("");
const newValues = reactive<Record<MeasurementField, number | null>>({
  weight_kg: null,
  body_fat_pct: null,
  waist_cm: null,
  chest_cm: null,
  arm_cm: null,
  thigh_cm: null,
});

const hasAnyValue = computed(() =>
  MEASUREMENT_FIELDS.some((f) => typeof newValues[f.key] === "number" && !Number.isNaN(newValues[f.key]))
);

onMounted(fetchMeasurements);

async function handleCreate() {
  const payload: MeasurementPayload = { measured_at: newDate.value };
  for (const f of MEASUREMENT_FIELDS) {
    const v = newValues[f.key];
    if (typeof v === "number" && !Number.isNaN(v)) payload[f.key] = v;
  }
  if (newNotes.value) payload.notes = newNotes.value;

  const created = await createMeasurement(payload);
  if (created) {
    for (const f of MEASUREMENT_FIELDS) newValues[f.key] = null;
    newNotes.value = "";
    newDate.value = new Date().toISOString().slice(0, 10);
    showNew.value = false;
  }
}

async function onFieldChange(
  id: string,
  field: MeasurementField | "measured_at" | "notes",
  e: Event
) {
  const raw = (e.target as HTMLInputElement).value;
  const patch: MeasurementPayload = {};
  if (field === "measured_at") {
    if (!raw) return;
    patch.measured_at = raw;
  } else if (field === "notes") {
    patch.notes = raw.trim() ? raw.trim() : null;
  } else {
    if (raw === "") patch[field] = null;
    else {
      const n = Number(raw);
      if (Number.isNaN(n)) return;
      patch[field] = n;
    }
  }
  await updateMeasurement(id, patch);
}

async function onDelete(m: BodyMeasurement) {
  if (!confirm(`¿Eliminar la medida del ${m.measured_at}?`)) return;
  await deleteMeasurement(m.id);
}
</script>

<style scoped>
.measurements {
  max-width: 720px;
  margin: 0 auto;
  padding: 4px 20px 24px;
  display: flex;
  flex-direction: column;
  gap: 16px;
}
.measurements__head {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
.measurements__head h1 {
  margin: 0;
  font-family: var(--font-display);
  font-size: 26px;
  font-weight: var(--weight-bold);
  letter-spacing: -0.5px;
  color: var(--text-primary);
}
.measurements__new {
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
.measurements__form {
  display: flex;
  flex-direction: column;
  gap: 14px;
  padding: 18px;
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-lg);
  background: var(--surface-1);
}
.measurements__form label {
  display: flex;
  flex-direction: column;
  gap: 6px;
  font-size: 11px;
  font-weight: var(--weight-bold);
  letter-spacing: 0.5px;
  text-transform: uppercase;
  color: var(--text-tertiary);
}
.measurements__form input,
.measurements__form textarea {
  padding: 10px 12px;
  border-radius: var(--radius-md);
  border: 1px solid var(--border-default);
  background: var(--surface-2);
  color: var(--text-primary);
  font-family: inherit;
  font-size: 14px;
  font-weight: var(--weight-regular);
  text-transform: none;
  letter-spacing: normal;
}
.measurements__form input:focus,
.measurements__form textarea:focus {
  outline: none;
  border-color: var(--brand-500);
  box-shadow: 0 0 0 2px var(--brand-glow);
}
.measurements__date {
  max-width: 200px;
}
.measurements__grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
  gap: 10px;
}
.measurements__submit {
  align-self: flex-start;
  padding: 10px 20px;
  border: none;
  border-radius: var(--radius-pill);
  background: var(--brand-500);
  color: var(--surface-0);
  font-family: inherit;
  font-weight: var(--weight-bold);
  font-size: 14px;
  cursor: pointer;
}
.measurements__submit:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
.measurements__error {
  margin: 0;
  padding: 10px 12px;
  border-radius: var(--radius-sm);
  background: var(--danger-glow);
  color: var(--danger);
  font-size: 13px;
}
.measurements__empty {
  color: var(--text-tertiary);
  text-align: center;
  padding: 24px 0;
  font-size: 14px;
}
.measurements__list {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 12px;
}
.card {
  display: flex;
  flex-direction: column;
  gap: 14px;
  padding: 16px;
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-lg);
  background: var(--surface-1);
}
.card__head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}
.card__date {
  flex: 1;
  min-width: 0;
  padding: 8px 10px;
  border-radius: var(--radius-sm);
  border: 1px solid var(--border-default);
  background: var(--surface-2);
  color: var(--text-primary);
  font-family: inherit;
  font-size: 14px;
  font-weight: var(--weight-semibold);
}
.card__date:focus {
  outline: none;
  border-color: var(--brand-500);
  box-shadow: 0 0 0 2px var(--brand-glow);
}
.card__delete {
  flex-shrink: 0;
  width: 32px;
  height: 32px;
  border-radius: var(--radius-pill);
  background: transparent;
  border: 1px solid var(--border-default);
  color: var(--text-tertiary);
  font-size: 18px;
  line-height: 1;
  cursor: pointer;
  display: inline-flex;
  align-items: center;
  justify-content: center;
}
.card__delete:hover {
  border-color: var(--danger);
  color: var(--danger);
}
.card__grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 10px;
}
.card__field,
.card__notes {
  display: flex;
  flex-direction: column;
  gap: 6px;
  min-width: 0;
}
.card__label {
  font-size: 11px;
  font-weight: var(--weight-bold);
  letter-spacing: 0.5px;
  text-transform: uppercase;
  color: var(--text-tertiary);
}
.card__label small {
  font-weight: var(--weight-regular);
  text-transform: none;
  letter-spacing: normal;
  color: var(--text-tertiary);
}
.card__field input,
.card__notes input {
  width: 100%;
  padding: 10px 12px;
  border-radius: var(--radius-sm);
  border: 1px solid var(--border-default);
  background: var(--surface-2);
  color: var(--text-primary);
  font-family: inherit;
  font-size: 14px;
  font-variant-numeric: tabular-nums;
}
.card__field input:focus,
.card__notes input:focus {
  outline: none;
  border-color: var(--brand-500);
  box-shadow: 0 0 0 2px var(--brand-glow);
}
@media (min-width: 520px) {
  .card__grid {
    grid-template-columns: repeat(3, minmax(0, 1fr));
  }
}
</style>
