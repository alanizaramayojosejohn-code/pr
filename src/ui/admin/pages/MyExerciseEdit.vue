<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import { useRoute, useRouter } from "vue-router";
import { useExercise, type Exercise } from "@/composables/useExercise";
import { useCategories } from "@/composables/useCategories";

type Form = {
  name: string;
  description: string;
  image_url: string;
  image_url_2: string | null;
  video_url: string;
  category_id: string | null;
  equipment: string | null;
  mechanic: string | null;
  level: string | null;
  rest_seconds: number;
};

const route = useRoute();
const router = useRouter();

const { getById, updateExercise, deleteExercise } = useExercise();
const { categories, fetchCategories } = useCategories();

const id = computed(() => Number(route.params.id));
const current = ref<Exercise | null>(null);
const loading = ref(true);
const saving = ref(false);
const error = ref<string | null>(null);

const form = ref<Form>({
  name: "",
  description: "",
  image_url: "",
  image_url_2: null,
  video_url: "",
  category_id: null,
  equipment: null,
  mechanic: null,
  level: null,
  rest_seconds: 60,
});

const imageFile = ref<File | null>(null);
const imageFile2 = ref<File | null>(null);
const videoFile = ref<File | null>(null);
const preview1 = ref<string | null>(null);
const preview2 = ref<string | null>(null);

const steps = computed({
  get(): string[] {
    return form.value.description
      .split(/\n\n+/)
      .map((s) => s.trim())
      .filter(Boolean);
  },
  set(list: string[]) {
    form.value.description = list.join("\n\n");
  },
});

const categoryName = computed(() => {
  return categories.value.find((c) => c.id === form.value.category_id)?.name ?? "Sin categoría";
});

onMounted(async () => {
  await fetchCategories();
  if (!Number.isFinite(id.value)) {
    router.replace({ name: "ejercicios" });
    return;
  }
  const ex = await getById(id.value);
  if (!ex) {
    error.value = "No se encontró el ejercicio";
    loading.value = false;
    return;
  }
  current.value = ex;
  form.value = {
    name: ex.name,
    description: ex.description ?? "",
    image_url: ex.image_url ?? "",
    image_url_2: ex.image_url_2 ?? null,
    video_url: ex.video_url ?? "",
    category_id: ex.category_id ?? null,
    equipment: ex.equipment ?? null,
    mechanic: ex.mechanic ?? null,
    level: ex.level ?? null,
    rest_seconds: ex.rest_seconds ?? 60,
  };
  preview1.value = ex.image_url || null;
  preview2.value = ex.image_url_2 || null;
  loading.value = false;
});

function onImage1(e: Event) {
  const f = (e.target as HTMLInputElement).files?.[0];
  if (!f) return;
  imageFile.value = f;
  preview1.value = URL.createObjectURL(f);
}
function onImage2(e: Event) {
  const f = (e.target as HTMLInputElement).files?.[0];
  if (!f) return;
  imageFile2.value = f;
  preview2.value = URL.createObjectURL(f);
}
function onVideo(e: Event) {
  const f = (e.target as HTMLInputElement).files?.[0];
  if (!f) return;
  videoFile.value = f;
}

function addStep() {
  form.value.description = (form.value.description ? form.value.description + "\n\n" : "") + "";
}
function updateStep(i: number, value: string) {
  const list = [...steps.value];
  list[i] = value;
  steps.value = list;
}
function removeStep(i: number) {
  const list = [...steps.value];
  list.splice(i, 1);
  steps.value = list;
}

async function save() {
  if (!current.value || saving.value) return;
  if (!form.value.name.trim()) {
    error.value = "El nombre es obligatorio";
    return;
  }
  saving.value = true;
  error.value = null;
  const ok = await updateExercise(
    current.value.id!,
    { ...form.value },
    imageFile.value ?? undefined,
    videoFile.value ?? undefined
  );
  saving.value = false;
  if (ok) {
    router.back();
  } else {
    error.value = "No se pudo guardar. Intentá de nuevo.";
  }
}

async function remove() {
  if (!current.value) return;
  if (!confirm(`¿Eliminar "${current.value.name}"? Esta acción no se puede deshacer.`)) return;
  const ok = await deleteExercise(current.value.id!);
  if (ok) router.back();
}

function cancel() {
  router.back();
}
</script>

<template>
  <section class="ee">
    <header class="ee__head">
      <button class="ee__back" @click="cancel" aria-label="Volver">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m15 18-6-6 6-6"/></svg>
      </button>
      <div class="ee__title">
        <h1>Editar ejercicio</h1>
        <p class="ee__sub">{{ current ? `${current.name} · ${categoryName}` : "Cargando…" }}</p>
      </div>
      <button
        class="ee__del"
        :disabled="!current"
        aria-label="Eliminar"
        @click="remove"
      >
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 6h18M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2m3 0v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6"/></svg>
      </button>
    </header>

    <p v-if="error" class="ee__error">{{ error }}</p>
    <p v-if="loading" class="ee__loading">Cargando ejercicio…</p>

    <form v-if="!loading && current" class="ee__form" @submit.prevent="save">
      <section class="media">
        <h2 class="section-label">Imágenes del movimiento</h2>
        <div class="media__row">
          <label class="media__slot">
            <input type="file" accept="image/*" @change="onImage1" />
            <img v-if="preview1" :src="preview1" alt="Inicio" />
            <template v-else>
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M17 8l-5-5-5 5M12 3v12"/></svg>
            </template>
            <span class="media__tag">Inicio</span>
            <span class="media__change">Cambiar</span>
          </label>
          <label class="media__slot">
            <input type="file" accept="image/*" @change="onImage2" />
            <img v-if="preview2" :src="preview2" alt="Fin" />
            <template v-else>
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M17 8l-5-5-5 5M12 3v12"/></svg>
            </template>
            <span class="media__tag">Fin</span>
            <span class="media__change">Cambiar</span>
          </label>
        </div>

        <label class="video">
          <input type="file" accept="video/*" @change="onVideo" />
          <span class="video__icon">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m22 8-6 4 6 4V8z"/><rect x="2" y="6" width="14" height="12" rx="2"/></svg>
          </span>
          <span class="video__col">
            <span class="video__title">
              {{ videoFile ? videoFile.name : (form.video_url ? "Video subido" : "Subir video (opcional)") }}
            </span>
            <span class="video__meta">MP4 · máx 20 MB</span>
          </span>
          <svg class="video__up" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M17 8l-5-5-5 5M12 3v12"/></svg>
        </label>
      </section>

      <div class="field">
        <span class="field__label">Nombre</span>
        <input v-model="form.name" type="text" placeholder="Ej: Press banca" />
      </div>

      <div class="field">
        <span class="field__label">Categoría</span>
        <div class="chips">
          <button
            v-for="c in categories"
            :key="c.id"
            type="button"
            class="chip"
            :class="{ 'chip--on': form.category_id === c.id }"
            @click="form.category_id = c.id"
          >{{ c.name }}</button>
          <button
            type="button"
            class="chip"
            :class="{ 'chip--on': form.category_id === null }"
            @click="form.category_id = null"
          >Sin categoría</button>
        </div>
      </div>

      <div class="field-row">
        <div class="field">
          <span class="field__label">Equipo</span>
          <input
            v-model="form.equipment"
            type="text"
            placeholder="Ej: Barra"
          />
        </div>
        <div class="field">
          <span class="field__label">Mecánica</span>
          <select v-model="form.mechanic">
            <option :value="null">—</option>
            <option value="compound">Compuesto</option>
            <option value="isolation">Aislado</option>
          </select>
        </div>
      </div>

      <div class="field-row">
        <div class="field">
          <span class="field__label">Nivel</span>
          <select v-model="form.level">
            <option :value="null">—</option>
            <option value="beginner">Principiante</option>
            <option value="intermediate">Intermedio</option>
            <option value="expert">Avanzado</option>
          </select>
        </div>
        <div class="field">
          <span class="field__label">Descanso</span>
          <div class="rest">
            <input
              type="number"
              min="0"
              step="5"
              :value="form.rest_seconds"
              @input="form.rest_seconds = Number(($event.target as HTMLInputElement).value) || 0"
            />
            <span>seg</span>
          </div>
        </div>
      </div>

      <section class="steps">
        <h2 class="section-label">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="10" x2="21" y1="6" y2="6"/><line x1="10" x2="21" y1="12" y2="12"/><line x1="10" x2="21" y1="18" y2="18"/><path d="M4 6h1v4"/><path d="M4 10h2"/><path d="M6 18H4c0-1 2-2 2-3s-1-1.5-2-1"/></svg>
          Instrucciones
        </h2>
        <div class="steps__list">
          <div v-for="(s, i) in steps" :key="i" class="step">
            <span class="step__num">{{ i + 1 }}</span>
            <textarea
              :value="s"
              rows="2"
              placeholder="Describí el paso…"
              @input="updateStep(i, ($event.target as HTMLTextAreaElement).value)"
            ></textarea>
            <button type="button" class="step__del" aria-label="Quitar paso" @click="removeStep(i)">×</button>
          </div>
        </div>
        <button type="button" class="steps__add" @click="addStep">+ Agregar paso</button>
      </section>

      <div v-if="current.source_id" class="source-badge">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><ellipse cx="12" cy="5" rx="9" ry="3"/><path d="M3 5v14a9 3 0 0 0 18 0V5"/><path d="M3 12a9 3 0 0 0 18 0"/></svg>
        Catálogo · {{ current.source_id }}
      </div>
    </form>

    <footer v-if="!loading && current" class="ee__footer">
      <button type="button" class="btn-secondary" @click="cancel">Cancelar</button>
      <button type="button" class="btn-primary" :disabled="saving" @click="save">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6 9 17l-5-5"/></svg>
        {{ saving ? "Guardando…" : "Guardar" }}
      </button>
    </footer>
  </section>
</template>

<style scoped>
.ee {
  max-width: 720px;
  margin: 0 auto;
  padding: 4px 20px 120px;
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.ee__head {
  display: flex;
  align-items: center;
  gap: 12px;
}
.ee__back,
.ee__del {
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
.ee__back svg,
.ee__del svg { width: 18px; height: 18px; }
.ee__back:hover { border-color: var(--brand-500); color: var(--brand-400); }
.ee__del { color: var(--danger); border-color: var(--danger-glow); }
.ee__del:hover { background: var(--danger-glow); }
.ee__del:disabled { opacity: 0.4; cursor: not-allowed; }

.ee__title { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 2px; }
.ee__title h1 {
  margin: 0;
  font-family: var(--font-display);
  font-size: 22px;
  font-weight: var(--weight-bold);
  letter-spacing: -0.4px;
  color: var(--text-primary);
}
.ee__sub {
  margin: 0;
  font-size: 13px;
  color: var(--text-tertiary);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.ee__error {
  margin: 0;
  padding: 10px 12px;
  border-radius: var(--radius-sm);
  background: var(--danger-glow);
  color: var(--danger);
  font-size: 13px;
}
.ee__loading {
  margin: 0;
  padding: 40px 0;
  text-align: center;
  color: var(--text-tertiary);
}

.ee__form {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.section-label {
  margin: 0 0 8px;
  display: flex;
  align-items: center;
  gap: 8px;
  font-family: var(--font-body);
  font-size: 12px;
  font-weight: var(--weight-semibold);
  color: var(--text-secondary);
}
.section-label svg { width: 14px; height: 14px; color: var(--brand-400); }

/* Media */
.media__row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
}
.media__slot {
  position: relative;
  aspect-ratio: 1 / 1;
  border-radius: var(--radius-lg);
  background: var(--surface-1);
  border: 1px solid var(--border-subtle);
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 6px;
  cursor: pointer;
  overflow: hidden;
  color: var(--brand-400);
}
.media__slot input { display: none; }
.media__slot img {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.media__slot svg { width: 26px; height: 26px; }
.media__tag {
  position: relative;
  z-index: 1;
  font-size: 12px;
  font-weight: var(--weight-semibold);
  color: var(--text-secondary);
}
.media__change {
  position: relative;
  z-index: 1;
  font-size: 11px;
  color: var(--text-tertiary);
}
.media__slot img ~ .media__tag,
.media__slot img ~ .media__change {
  background: rgba(0, 0, 0, 0.6);
  color: var(--text-primary);
  padding: 2px 8px;
  border-radius: var(--radius-pill);
}

.video {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-top: 10px;
  padding: 14px;
  border-radius: var(--radius-lg);
  background: var(--surface-1);
  border: 1px dashed var(--border-subtle);
  cursor: pointer;
}
.video input { display: none; }
.video__icon {
  width: 36px;
  height: 36px;
  border-radius: var(--radius-pill);
  background: var(--surface-2);
  display: grid;
  place-items: center;
  color: var(--brand-400);
  flex-shrink: 0;
}
.video__icon svg { width: 18px; height: 18px; }
.video__col { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 2px; }
.video__title {
  font-size: 14px;
  font-weight: var(--weight-semibold);
  color: var(--text-primary);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.video__meta { font-size: 12px; color: var(--text-tertiary); }
.video__up {
  width: 18px;
  height: 18px;
  color: var(--text-secondary);
  flex-shrink: 0;
}

/* Fields */
.field { display: flex; flex-direction: column; gap: 6px; }
.field__label {
  font-size: 11px;
  font-weight: var(--weight-bold);
  letter-spacing: 0.5px;
  text-transform: uppercase;
  color: var(--text-tertiary);
}
.field input[type="text"],
.field input[type="number"],
.field select,
.field textarea {
  background: var(--surface-2);
  border: 1px solid var(--border-default);
  border-radius: var(--radius-md);
  padding: 10px 12px;
  color: var(--text-primary);
  font-family: inherit;
  font-size: 14px;
}
.field select {
  appearance: none;
  background-image: url("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='%237a847f' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><path d='m6 9 6 6 6-6'/></svg>");
  background-repeat: no-repeat;
  background-position: right 12px center;
  background-size: 16px;
  padding-right: 36px;
}
.field input:focus,
.field select:focus,
.field textarea:focus {
  outline: none;
  border-color: var(--brand-500);
  box-shadow: 0 0 0 2px var(--brand-glow);
}
.field-row { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }

.rest {
  display: flex;
  align-items: center;
  gap: 8px;
  background: var(--surface-2);
  border: 1px solid var(--border-default);
  border-radius: var(--radius-md);
  padding: 0 12px 0 0;
}
.rest input {
  flex: 1;
  background: transparent;
  border: none;
  padding: 10px 12px;
  color: var(--text-primary);
  font-family: inherit;
  font-size: 14px;
}
.rest span { color: var(--text-tertiary); font-size: 12px; }

.chips { display: flex; flex-wrap: wrap; gap: 8px; }
.chip {
  padding: 8px 12px;
  border-radius: var(--radius-pill);
  border: 1px solid var(--border-default);
  background: var(--surface-2);
  color: var(--text-secondary);
  font-family: inherit;
  font-size: 13px;
  font-weight: var(--weight-semibold);
  cursor: pointer;
}
.chip--on {
  background: var(--brand-500);
  border-color: var(--brand-500);
  color: var(--surface-0);
}

/* Steps */
.steps {
  background: var(--surface-1);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-lg);
  padding: 14px 16px;
}
.steps__list { display: flex; flex-direction: column; gap: 10px; }
.step {
  display: grid;
  grid-template-columns: auto 1fr auto;
  gap: 10px;
  align-items: start;
}
.step__num {
  width: 24px;
  height: 24px;
  border-radius: var(--radius-pill);
  background: var(--surface-3);
  color: var(--brand-300);
  display: grid;
  place-items: center;
  font-size: 12px;
  font-weight: var(--weight-bold);
  margin-top: 6px;
}
.step textarea {
  width: 100%;
  background: var(--surface-2);
  border: 1px solid var(--border-default);
  border-radius: var(--radius-md);
  padding: 10px 12px;
  color: var(--text-primary);
  font-family: inherit;
  font-size: 13px;
  line-height: 1.45;
  resize: vertical;
}
.step textarea:focus {
  outline: none;
  border-color: var(--brand-500);
  box-shadow: 0 0 0 2px var(--brand-glow);
}
.step__del {
  width: 28px;
  height: 28px;
  border-radius: var(--radius-pill);
  border: 1px solid var(--border-subtle);
  background: var(--surface-2);
  color: var(--text-tertiary);
  cursor: pointer;
  font-size: 14px;
  line-height: 1;
  margin-top: 4px;
}
.step__del:hover { color: var(--danger); border-color: var(--danger); }
.steps__add {
  margin-top: 12px;
  background: transparent;
  border: none;
  color: var(--brand-400);
  font-family: inherit;
  font-size: 13px;
  font-weight: var(--weight-semibold);
  cursor: pointer;
  padding: 4px 0;
}

/* Source badge */
.source-badge {
  align-self: flex-start;
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 6px 12px;
  border-radius: var(--radius-pill);
  background: var(--surface-2);
  color: var(--text-tertiary);
  font-size: 11px;
  font-weight: var(--weight-medium);
}
.source-badge svg { width: 12px; height: 12px; }

/* Footer */
.ee__footer {
  position: fixed;
  left: 0;
  right: 0;
  bottom: 0;
  padding: 16px 20px calc(24px + env(safe-area-inset-bottom));
  background: var(--surface-0);
  border-top: 1px solid var(--border-subtle);
  display: flex;
  gap: 10px;
  z-index: 30;
}
.ee__footer > * { flex: 1; max-width: 320px; }
.ee__footer { justify-content: center; }
.btn-secondary,
.btn-primary {
  height: 50px;
  border-radius: var(--radius-pill);
  font-family: inherit;
  font-weight: var(--weight-bold);
  font-size: 15px;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
}
.btn-secondary {
  background: var(--surface-1);
  color: var(--text-primary);
  border: 1px solid var(--border-default);
}
.btn-primary {
  background: var(--brand-500);
  color: var(--surface-0);
  border: none;
}
.btn-primary svg { width: 18px; height: 18px; }
.btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }
</style>
