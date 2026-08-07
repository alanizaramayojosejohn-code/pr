<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import { useRoute, useRouter } from "vue-router";
import { useCategories } from "@/composables/useCategories";
import { useAuth } from "@/composables/useAuth";
import { useRoutines } from "@/composables/useRoutines";
import CategoryIcon from "@/ui/admin/components/CategoryIcon.vue";

const route = useRoute();
const router = useRouter();
const { isAdmin } = useAuth();
const {
  categories,
  counts,
  uncategorizedCount,
  loading,
  error,
  fetchCategories,
  fetchCounts,
  createCategory,
} = useCategories();
const { routines, fetchRoutines } = useRoutines();

const pickerRoutineId = computed(() =>
  typeof route.query.picker === "string" ? route.query.picker : null
);
const isPicker = computed(() => pickerRoutineId.value !== null);
const pickerRoutine = computed(() =>
  routines.value.find((r) => r.id === pickerRoutineId.value) ?? null
);

const creating = ref(false);
const newName = ref("");

onMounted(async () => {
  if (!isPicker.value && !isAdmin.value) {
    router.replace({ name: "dashboard" });
    return;
  }
  await Promise.all([
    fetchCategories(),
    fetchCounts(),
    isPicker.value ? fetchRoutines() : Promise.resolve(),
  ]);
});

function openCategory(categoryId: string) {
  router.push({
    name: "category-exercises",
    params: { categoryId },
    query: isPicker.value ? { picker: pickerRoutineId.value! } : {},
  });
}

function openUncategorized() {
  router.push({
    name: "category-exercises",
    params: { categoryId: "uncategorized" },
    query: isPicker.value ? { picker: pickerRoutineId.value! } : {},
  });
}

function goBack() {
  // El modo picker se entraba desde /rutinas, que ya no existe en el panel web.
  router.push({ name: "dashboard" });
}

async function onCreateCategory() {
  const name = newName.value.trim();
  if (!name) return;
  const c = await createCategory(name);
  if (c) {
    newName.value = "";
    creating.value = false;
    await fetchCounts();
  }
}
</script>

<template>
  <section class="cats">
    <header class="cats__head">
      <button class="cats__back" @click="goBack" aria-label="Volver">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m15 18-6-6 6-6"/></svg>
      </button>
      <div class="cats__title">
        <h1>Categorías</h1>
        <p v-if="isPicker && pickerRoutine" class="cats__sub cats__sub--brand">
          Agregar a {{ pickerRoutine.name }}
        </p>
        <p v-else class="cats__sub">Elige un grupo muscular</p>
      </div>
      <button
        v-if="isAdmin && !isPicker"
        class="cats__new"
        @click="creating = !creating"
      >
        {{ creating ? "Cancelar" : "+ Nueva" }}
      </button>
    </header>

    <form v-if="creating" class="cats__form" @submit.prevent="onCreateCategory">
      <input
        v-model.trim="newName"
        placeholder="Nombre de la categoría (ej: Hombro)"
        autofocus
      />
      <button type="submit" :disabled="!newName.trim()">Crear</button>
    </form>

    <p v-if="error" class="cats__error">{{ error }}</p>
    <p v-if="loading && categories.length === 0" class="cats__empty">Cargando…</p>

    <div v-else class="grid">
      <button
        v-for="c in categories"
        :key="c.id"
        class="card"
        @click="openCategory(c.id)"
      >
        <div class="card__icon">
          <CategoryIcon :slug="c.slug" />
        </div>
        <div class="card__name">{{ c.name }}</div>
        <div class="card__count">{{ counts[c.id] ?? 0 }} ejercicios</div>
      </button>

      <button
        v-if="isAdmin && uncategorizedCount > 0"
        class="card card--dim"
        @click="openUncategorized"
      >
        <div class="card__icon card__icon--dim">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 8v4M12 16h.01"/></svg>
        </div>
        <div class="card__name">Sin categoría</div>
        <div class="card__count">{{ uncategorizedCount }} ejercicios</div>
      </button>
    </div>
  </section>
</template>

<style scoped>
.cats {
  max-width: 720px;
  margin: 0 auto;
  padding: 4px 20px 24px;
  display: flex;
  flex-direction: column;
  gap: 20px;
}
.cats__head {
  display: flex;
  align-items: center;
  gap: 12px;
}
.cats__back {
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
.cats__back svg {
  width: 18px;
  height: 18px;
}
.cats__back:hover {
  border-color: var(--brand-500);
  color: var(--brand-400);
}
.cats__title {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
}
.cats__title h1 {
  margin: 0;
  font-family: var(--font-display);
  font-size: 24px;
  font-weight: var(--weight-bold);
  letter-spacing: -0.4px;
  color: var(--text-primary);
}
.cats__sub {
  margin: 0;
  color: var(--text-tertiary);
  font-size: 12px;
}
.cats__sub--brand {
  color: var(--brand-400);
  font-weight: var(--weight-semibold);
}
.cats__new {
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
.cats__form {
  display: flex;
  gap: 8px;
}
.cats__form input {
  flex: 1;
  padding: 12px 14px;
  border-radius: var(--radius-md);
  border: 1px solid var(--border-default);
  background: var(--surface-1);
  color: var(--text-primary);
  font-family: inherit;
  font-size: 14px;
}
.cats__form input:focus {
  outline: none;
  border-color: var(--brand-500);
  box-shadow: 0 0 0 2px var(--brand-glow);
}
.cats__form button {
  padding: 0 18px;
  border-radius: var(--radius-pill);
  border: none;
  background: var(--brand-500);
  color: var(--surface-0);
  font-family: inherit;
  font-weight: var(--weight-bold);
  font-size: 13px;
  cursor: pointer;
}
.cats__form button:disabled {
  opacity: 0.4;
  cursor: not-allowed;
}
.cats__error {
  margin: 0;
  padding: 10px 12px;
  border-radius: var(--radius-sm);
  background: var(--danger-glow, rgba(239, 83, 80, 0.12));
  color: var(--danger);
  font-size: 13px;
}
.cats__empty {
  text-align: center;
  color: var(--text-tertiary);
  padding: 32px 0;
  font-size: 14px;
}

.grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 12px;
}
.card {
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding: 18px;
  border-radius: 16px;
  border: 1px solid var(--border-subtle);
  background: var(--surface-1);
  cursor: pointer;
  text-align: left;
  font-family: inherit;
  color: var(--text-primary);
  transition: border-color 120ms ease, transform 120ms ease;
}
.card:hover {
  border-color: var(--brand-500);
  transform: translateY(-1px);
}
.card__icon {
  width: 44px;
  height: 44px;
  border-radius: var(--radius-pill);
  background: var(--brand-glow);
  color: var(--brand-400);
  display: grid;
  place-items: center;
}
.card__icon--dim {
  background: var(--surface-2);
  color: var(--text-tertiary);
}
.card__name {
  font-family: var(--font-body);
  font-size: 16px;
  font-weight: var(--weight-semibold);
  color: var(--text-primary);
}
.card__count {
  font-size: 12px;
  color: var(--text-tertiary);
}
.card--dim {
  opacity: 0.8;
}
</style>
