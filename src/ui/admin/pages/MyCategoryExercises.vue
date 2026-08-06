<script setup lang="ts">
import { computed, onMounted, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import { useExercise, type Exercise } from "@/composables/useExercise";
import { useCategories } from "@/composables/useCategories";
import { useRoutines } from "@/composables/useRoutines";
import { useAuth } from "@/composables/useAuth";
import ExerciseThumb from "@/ui/admin/components/ExerciseThumb.vue";

const PAGE_SIZE = 10;

const route = useRoute();
const router = useRouter();
const { isAdmin } = useAuth();

const { fetchPaginated, createExercise, deleteExercise } = useExercise();
const { categories, fetchCategories } = useCategories();
const { routines, fetchRoutines, addExercisesToRoutine } = useRoutines();

const items = ref<Exercise[]>([]);
const total = ref(0);
const page = ref(1);
const search = ref("");
const loading = ref(false);
const error = ref<string | null>(null);

const categoryId = computed(() => String(route.params.categoryId ?? ""));
const isUncategorized = computed(() => categoryId.value === "uncategorized");
const pickerRoutineId = computed(() =>
  typeof route.query.picker === "string" ? route.query.picker : null
);
const isPicker = computed(() => pickerRoutineId.value !== null);

const category = computed(() =>
  categories.value.find((c) => c.id === categoryId.value) ?? null
);
const title = computed(() => {
  if (isUncategorized.value) return "Sin categoría";
  return category.value?.name ?? "Ejercicios";
});

const pageCount = computed(() =>
  Math.max(1, Math.ceil(total.value / PAGE_SIZE))
);
const pagesToShow = computed(() => {
  const max = pageCount.value;
  const cur = page.value;
  const pages: number[] = [];
  const start = Math.max(1, Math.min(cur - 1, max - 2));
  for (let i = start; i < start + 3 && i <= max; i++) pages.push(i);
  return pages;
});

const selectedIds = ref<Set<number>>(new Set());

// Modal state — create flow only; edit uses dedicated page
const showModal = ref(false);
const savingModal = ref(false);
type ExerciseForm = {
  name: string;
  description: string;
  image_url: string;
  video_url: string;
  category_id: string | null;
  rest_seconds: number;
};
const form = ref<ExerciseForm>(emptyForm());
const imageFile = ref<File | null>(null);
const videoFile = ref<File | null>(null);
const imagePreview = ref<string | null>(null);

function emptyForm(): ExerciseForm {
  return {
    name: "",
    description: "",
    image_url: "",
    video_url: "",
    category_id: isUncategorized.value ? null : categoryId.value,
    rest_seconds: 60,
  };
}

async function load() {
  loading.value = true;
  error.value = null;
  try {
    const res = await fetchPaginated({
      categoryId: isUncategorized.value ? null : categoryId.value,
      page: page.value,
      pageSize: PAGE_SIZE,
      search: search.value,
    });
    items.value = res.items;
    total.value = res.total;
  } catch (e) {
    error.value = e instanceof Error ? e.message : "Error al cargar";
  } finally {
    loading.value = false;
  }
}

onMounted(async () => {
  // Access control: non-admin out of picker flow → back to dashboard
  if (!isPicker.value && !isAdmin.value) {
    router.replace({ name: "dashboard" });
    return;
  }
  // Uncategorized only for admin
  if (isUncategorized.value && !isAdmin.value) {
    router.replace({ name: "ejercicios" });
    return;
  }
  await Promise.all([
    fetchCategories(),
    isPicker.value ? fetchRoutines() : Promise.resolve(),
  ]);
  await load();
});

watch(page, load);

let searchTimer: number | undefined;
function onSearch() {
  window.clearTimeout(searchTimer);
  searchTimer = window.setTimeout(() => {
    page.value = 1;
    load();
  }, 250);
}

function toggleSelect(ex: Exercise) {
  if (!isPicker.value || ex.id == null) return;
  const next = new Set(selectedIds.value);
  if (next.has(ex.id)) next.delete(ex.id);
  else next.add(ex.id);
  selectedIds.value = next;
}

function onCardClick(ex: Exercise) {
  if (ex.id == null) return;
  if (isPicker.value) {
    router.push({
      name: "exercise-detail",
      params: { id: ex.id },
      query: { routine: pickerRoutineId.value! },
    });
  }
}

// Cache exercises we've seen so selection survives pagination
const seen = ref<Map<number, Exercise>>(new Map());
watch(items, (list) => {
  for (const ex of list) {
    if (ex.id != null) seen.value.set(ex.id, ex);
  }
});

async function onConfirmPicker() {
  if (!pickerRoutineId.value || selectedIds.value.size === 0) return;
  const toAdd: Exercise[] = [];
  for (const id of selectedIds.value) {
    const ex = seen.value.get(id);
    if (ex) toAdd.push(ex);
  }
  if (!toAdd.length) return;
  const ok = await addExercisesToRoutine(pickerRoutineId.value, toAdd);
  // /rutinas ya no existe en el panel web; el picker queda sin punto de entrada.
  if (ok) router.push({ name: "ejercicios" });
}

function goBack() {
  router.push({
    name: "ejercicios",
    query: isPicker.value ? { picker: pickerRoutineId.value! } : {},
  });
}

// ---- Admin CRUD ----
function openCreate() {
  form.value = emptyForm();
  imageFile.value = null;
  videoFile.value = null;
  imagePreview.value = null;
  showModal.value = true;
}

function openEdit(item: Exercise) {
  if (!isAdmin.value || item.id == null) return;
  router.push({ name: "exercise-edit", params: { id: item.id } });
}

function closeModal() {
  showModal.value = false;
}

function onImageChange(e: Event) {
  const file = (e.target as HTMLInputElement).files?.[0];
  if (!file) return;
  imageFile.value = file;
  imagePreview.value = URL.createObjectURL(file);
}
function onVideoChange(e: Event) {
  const file = (e.target as HTMLInputElement).files?.[0];
  if (!file) return;
  videoFile.value = file;
}

async function submitModal() {
  if (!form.value.name.trim()) return;
  savingModal.value = true;
  const ok = await createExercise(
    { ...form.value },
    imageFile.value ?? undefined,
    videoFile.value ?? undefined
  );
  savingModal.value = false;
  if (ok) {
    closeModal();
    await load();
  }
}

async function onDelete(id: number) {
  if (!confirm("¿Eliminar este ejercicio?")) return;
  const ok = await deleteExercise(id);
  if (ok) await load();
}
</script>

<template>
  <section class="cx">
    <header class="cx__head">
      <button class="cx__back" @click="goBack" aria-label="Volver">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m15 18-6-6 6-6"/></svg>
      </button>
      <div class="cx__title">
        <h1>{{ title }}</h1>
        <p v-if="isPicker" class="cx__sub cx__sub--brand">
          Agregar a rutina · {{ selectedIds.size }} seleccionados
        </p>
        <p v-else class="cx__sub">
          {{ total }} ejercicios · catálogo
        </p>
      </div>
      <button
        v-if="isAdmin && !isPicker"
        class="cx__new"
        @click="openCreate"
      >
        + Nuevo
      </button>
    </header>

    <div class="cx__search">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/></svg>
      <input
        v-model="search"
        :placeholder="`Buscar en ${title}…`"
        @input="onSearch"
      />
    </div>

    <p v-if="error" class="cx__error">{{ error }}</p>
    <p v-if="!loading && items.length === 0" class="cx__empty">
      {{ search ? "No hay coincidencias." : "No hay ejercicios en esta categoría." }}
    </p>

    <ul v-else class="list">
      <li
        v-for="ex in items"
        :key="ex.id"
        class="ex"
        :class="{ 'ex--sel': isPicker && ex.id != null && selectedIds.has(ex.id) }"
        @click="onCardClick(ex)"
      >
        <ExerciseThumb :url="ex.image_url" :url2="ex.image_url_2" :alt="ex.name" size="md" />
        <div class="ex__body">
          <div class="ex__name">{{ ex.name }}</div>
          <div class="ex__desc">
            {{ ex.description || `${ex.rest_seconds ?? 60}s descanso` }}
          </div>
        </div>

        <button
          v-if="isPicker"
          type="button"
          class="ex__check"
          :class="{ 'ex__check--on': ex.id != null && selectedIds.has(ex.id) }"
          :aria-label="ex.id != null && selectedIds.has(ex.id) ? 'Quitar de selección' : 'Agregar a selección'"
          @click.stop="toggleSelect(ex)"
        >
          <svg v-if="ex.id != null && selectedIds.has(ex.id)" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6 9 17l-5-5"/></svg>
        </button>

        <div v-else-if="isAdmin" class="ex__actions">
          <button class="btn-edit" @click.stop="openEdit(ex)">Editar</button>
          <button class="btn-del" @click.stop="onDelete(ex.id!)" aria-label="Eliminar">×</button>
        </div>
      </li>
    </ul>

    <nav v-if="pageCount > 1" class="pag">
      <button
        class="pag__btn"
        :disabled="page === 1"
        @click="page = Math.max(1, page - 1)"
        aria-label="Anterior"
      >‹</button>
      <button
        v-for="p in pagesToShow"
        :key="p"
        class="pag__num"
        :class="{ 'pag__num--active': p === page }"
        @click="page = p"
      >{{ p }}</button>
      <button
        class="pag__btn"
        :disabled="page === pageCount"
        @click="page = Math.min(pageCount, page + 1)"
        aria-label="Siguiente"
      >›</button>
    </nav>

    <div v-if="isPicker && selectedIds.size > 0" class="cta">
      <button class="cta__btn" @click="onConfirmPicker">
        + Agregar {{ selectedIds.size }} ejercicio{{ selectedIds.size === 1 ? "" : "s" }}
      </button>
    </div>

    <!-- Admin modal -->
    <div v-if="showModal" class="modal-overlay" @click.self="closeModal">
      <div class="modal">
        <div class="modal-header">
          <h2>Nuevo ejercicio</h2>
          <button class="modal-close" @click="closeModal">✕</button>
        </div>
        <div class="modal-body">
          <div class="field">
            <label>Nombre</label>
            <input v-model="form.name" type="text" placeholder="Ej: Press banca" />
          </div>
          <div class="field">
            <label>Categoría</label>
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
              <label>Descanso</label>
              <div class="rest">
                <input
                  type="number"
                  min="0"
                  step="5"
                  :value="form.rest_seconds"
                  @input="form.rest_seconds = Number(($event.target as HTMLInputElement).value) || 0"
                />
                <span>s</span>
              </div>
            </div>
          </div>
          <div class="field">
            <label>Descripción</label>
            <textarea v-model="form.description" placeholder="Cómo realizar el ejercicio…"></textarea>
          </div>
          <div class="field">
            <label>Imagen</label>
            <input type="file" accept="image/*" @change="onImageChange" />
            <img v-if="imagePreview" :src="imagePreview" class="preview-img" />
          </div>
          <div class="field">
            <label>Video</label>
            <input type="file" accept="video/*" @change="onVideoChange" />
            <p v-if="videoFile" class="file-name">📹 {{ videoFile.name }}</p>
          </div>
        </div>
        <div class="modal-footer">
          <button class="btn-secondary" @click="closeModal">Cancelar</button>
          <button class="btn-primary" :disabled="savingModal" @click="submitModal">
            {{ savingModal ? "Guardando…" : "Crear ejercicio" }}
          </button>
        </div>
      </div>
    </div>
  </section>
</template>

<style scoped>
.cx {
  max-width: 720px;
  margin: 0 auto;
  padding: 4px 20px 120px;
  display: flex;
  flex-direction: column;
  gap: 16px;
}
.cx__head {
  display: flex;
  align-items: center;
  gap: 12px;
}
.cx__back {
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
.cx__back svg { width: 18px; height: 18px; }
.cx__back:hover { border-color: var(--brand-500); color: var(--brand-400); }
.cx__title { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 2px; }
.cx__title h1 {
  margin: 0;
  font-family: var(--font-display);
  font-size: 22px;
  font-weight: var(--weight-bold);
  letter-spacing: -0.4px;
  color: var(--text-primary);
}
.cx__sub { margin: 0; font-size: 12px; color: var(--text-tertiary); }
.cx__sub--brand { color: var(--brand-400); font-weight: var(--weight-semibold); }
.cx__new {
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

.cx__search {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 14px;
  border-radius: 12px;
  background: var(--surface-1);
  border: 1px solid var(--border-subtle);
  color: var(--text-tertiary);
}
.cx__search svg { width: 16px; height: 16px; flex-shrink: 0; }
.cx__search input {
  flex: 1;
  background: transparent;
  border: none;
  color: var(--text-primary);
  font-family: inherit;
  font-size: 14px;
}
.cx__search input:focus { outline: none; }
.cx__search input::placeholder { color: var(--text-tertiary); }

.cx__error {
  margin: 0;
  padding: 10px 12px;
  border-radius: var(--radius-sm);
  background: var(--danger-glow, rgba(239, 83, 80, 0.12));
  color: var(--danger);
  font-size: 13px;
}
.cx__empty {
  text-align: center;
  color: var(--text-tertiary);
  padding: 40px 0;
  font-size: 14px;
}

.list { list-style: none; padding: 0; margin: 0; display: flex; flex-direction: column; gap: 10px; }
.ex {
  display: grid;
  grid-template-columns: auto 1fr auto;
  gap: 12px;
  align-items: center;
  padding: 12px;
  border: 1px solid var(--border-subtle);
  border-radius: 14px;
  background: var(--surface-1);
  cursor: pointer;
  transition: border-color 120ms ease;
}
.ex:hover { border-color: var(--border-default); }
.ex--sel { border-color: var(--brand-500); background: var(--brand-glow); }
.ex__body { min-width: 0; display: flex; flex-direction: column; gap: 3px; }
.ex__name {
  font-family: var(--font-body);
  font-size: 15px;
  font-weight: var(--weight-semibold);
  color: var(--text-primary);
}
.ex__desc {
  font-size: 12px;
  color: var(--text-tertiary);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.ex__check {
  width: 26px;
  height: 26px;
  border-radius: 8px;
  border: 1.5px solid var(--border-default);
  background: var(--surface-0);
  display: grid;
  place-items: center;
  color: var(--surface-0);
  cursor: pointer;
  padding: 0;
}
.ex__check--on {
  background: var(--brand-500);
  border-color: var(--brand-500);
}
.ex__check svg { width: 16px; height: 16px; }

.ex__actions { display: flex; gap: 6px; }
.btn-edit {
  background: transparent;
  color: var(--brand-300);
  border: 1px solid var(--brand-500);
  padding: 6px 10px;
  border-radius: var(--radius-pill);
  font-family: inherit;
  font-size: 11px;
  font-weight: var(--weight-semibold);
  cursor: pointer;
}
.btn-edit:hover { background: var(--brand-glow); }
.btn-del {
  background: transparent;
  color: var(--text-tertiary);
  border: 1px solid var(--border-subtle);
  padding: 6px 10px;
  border-radius: var(--radius-pill);
  font-family: inherit;
  font-size: 14px;
  line-height: 1;
  cursor: pointer;
}
.btn-del:hover { color: var(--danger); border-color: var(--danger); }

.pag { display: flex; justify-content: center; align-items: center; gap: 8px; padding: 8px 0; }
.pag__btn,
.pag__num {
  width: 36px;
  height: 36px;
  border-radius: var(--radius-pill);
  border: 1px solid var(--border-subtle);
  background: var(--surface-1);
  color: var(--text-secondary);
  font-family: inherit;
  font-weight: var(--weight-semibold);
  font-size: 13px;
  cursor: pointer;
  display: grid;
  place-items: center;
}
.pag__btn:disabled { opacity: 0.4; cursor: not-allowed; }
.pag__num--active {
  background: var(--brand-500);
  border-color: transparent;
  color: var(--surface-0);
  font-weight: var(--weight-bold);
}

.cta {
  position: fixed;
  left: 0;
  right: 0;
  bottom: calc(86px + env(safe-area-inset-bottom));
  padding: 0 20px;
  z-index: 30;
}
.cta__btn {
  display: block;
  width: 100%;
  max-width: 480px;
  margin: 0 auto;
  height: 50px;
  border-radius: var(--radius-pill);
  border: none;
  background: var(--brand-500);
  color: var(--surface-0);
  font-family: inherit;
  font-weight: var(--weight-bold);
  font-size: 15px;
  cursor: pointer;
  box-shadow: 0 10px 24px rgba(0, 0, 0, 0.45);
}

/* Modal */
.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.72);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 100;
  padding: 20px;
  backdrop-filter: blur(6px);
}
.modal {
  background: var(--surface-1);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-xl);
  width: 100%;
  max-width: 480px;
  max-height: calc(100vh - 40px);
  overflow: auto;
}
.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 18px 20px;
  border-bottom: 1px solid var(--border-subtle);
}
.modal-header h2 {
  margin: 0;
  font-family: var(--font-display);
  font-size: 18px;
  font-weight: var(--weight-bold);
  letter-spacing: -0.3px;
  color: var(--text-primary);
}
.modal-close {
  background: transparent;
  border: none;
  color: var(--text-tertiary);
  font-size: 18px;
  cursor: pointer;
  line-height: 1;
}
.modal-body {
  padding: 20px;
  display: flex;
  flex-direction: column;
  gap: 14px;
}
.field { display: flex; flex-direction: column; gap: 6px; }
.field label {
  font-size: 11px;
  font-weight: var(--weight-bold);
  letter-spacing: 0.5px;
  text-transform: uppercase;
  color: var(--text-tertiary);
}
.field input[type="text"],
.field input[type="number"],
.field textarea {
  background: var(--surface-2);
  border: 1px solid var(--border-default);
  border-radius: var(--radius-md);
  padding: 10px 12px;
  color: var(--text-primary);
  font-family: inherit;
  font-size: 14px;
}
.field textarea { resize: vertical; min-height: 80px; }
.field input:focus,
.field textarea:focus {
  outline: none;
  border-color: var(--brand-500);
  box-shadow: 0 0 0 2px var(--brand-glow);
}
.field-row { display: flex; gap: 12px; }
.field-row .field { flex: 1; }
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
.preview-img {
  width: 72px;
  height: 72px;
  border-radius: var(--radius-sm);
  object-fit: cover;
  border: 1px solid var(--border-subtle);
  margin-top: 4px;
}
.file-name { font-size: 12px; color: var(--brand-400); margin: 4px 0 0; }
.modal-footer {
  display: flex;
  justify-content: flex-end;
  gap: 10px;
  padding: 18px 20px;
  border-top: 1px solid var(--border-subtle);
}
.btn-primary {
  background: var(--brand-500);
  color: var(--surface-0);
  border: none;
  padding: 10px 18px;
  border-radius: var(--radius-pill);
  font-family: inherit;
  font-weight: var(--weight-bold);
  font-size: 13px;
  cursor: pointer;
}
.btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }
.btn-secondary {
  background: transparent;
  color: var(--text-secondary);
  border: 1px solid var(--border-default);
  padding: 10px 18px;
  border-radius: var(--radius-pill);
  font-family: inherit;
  font-size: 13px;
  cursor: pointer;
}
</style>
