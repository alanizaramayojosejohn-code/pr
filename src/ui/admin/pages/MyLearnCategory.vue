<template>
  <section v-if="!category" class="learn learn--empty">
    <p>Categoría no encontrada.</p>
    <RouterLink :to="{ name: 'aprender' }">Volver a Aprender</RouterLink>
  </section>

  <section v-else class="learn">
    <header class="learn__head">
      <button class="learn__back" @click="goBack" aria-label="Volver">
        <svg viewBox="0 0 24 24" aria-hidden="true">
          <path d="M15 6l-6 6 6 6" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" fill="none" />
        </svg>
      </button>
      <div>
        <h1>{{ category.name }}</h1>
        <p>{{ category.description }}</p>
      </div>
    </header>

    <p v-if="!list.length" class="learn__empty">
      Aún no hay artículos en esta categoría.
    </p>

    <div v-else class="learn__list">
      <RouterLink
        v-for="a in list"
        :key="a.slug"
        :to="{ name: 'aprender-detalle', params: { slug: a.slug } }"
        class="acard"
      >
        <div class="acard__cover" :style="a.cover ? `background-image:url(${a.cover})` : ''">
          <span v-if="!a.cover" class="acard__cover-fallback">{{ a.title.charAt(0).toUpperCase() }}</span>
        </div>
        <div class="acard__body">
          <h2 class="acard__title">{{ a.title }}</h2>
          <p class="acard__excerpt">{{ a.excerpt }}</p>
          <p class="acard__meta">{{ formatDate(a.published) }} · {{ a.readingMinutes }} min</p>
        </div>
      </RouterLink>
    </div>
  </section>
</template>

<script setup lang="ts">
import { computed } from "vue";
import { useRoute, useRouter } from "vue-router";
import { useArticles } from "@/composables/useArticles";

const route = useRoute();
const router = useRouter();
const { findCategory, articlesByCategory, formatDate } = useArticles();

const category = computed(() => findCategory(String(route.params.slug)));
const list = computed(() => (category.value ? articlesByCategory(category.value.slug) : []));

function goBack() {
  router.push({ name: "aprender" });
}
</script>

<style scoped>
.learn {
  max-width: 480px;
  margin: 0 auto;
  padding: 8px 20px 24px;
  display: flex;
  flex-direction: column;
  gap: 16px;
}
.learn--empty {
  text-align: center;
  padding: 64px 16px;
  color: var(--text-tertiary);
}
.learn__head {
  display: flex;
  align-items: flex-start;
  gap: 12px;
}
.learn__back {
  display: grid;
  place-items: center;
  width: 36px;
  height: 36px;
  border-radius: var(--radius-pill);
  border: none;
  background: var(--surface-2);
  color: var(--text-primary);
  cursor: pointer;
  flex-shrink: 0;
}
.learn__back svg {
  width: 16px;
  height: 16px;
}
.learn__head h1 {
  margin: 0;
  font-family: var(--font-display);
  font-size: 22px;
  font-weight: var(--weight-bold);
  letter-spacing: -0.4px;
  color: var(--text-primary);
}
.learn__head p {
  margin: 4px 0 0;
  font-size: 12px;
  color: var(--text-tertiary);
}
.learn__empty {
  margin: 0;
  padding: 32px 0;
  text-align: center;
  color: var(--text-tertiary);
  font-size: 13px;
}
.learn__list {
  display: flex;
  flex-direction: column;
  gap: 12px;
}
.acard {
  display: flex;
  flex-direction: column;
  background: var(--surface-1);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-lg);
  text-decoration: none;
  color: inherit;
  overflow: hidden;
}
.acard:hover {
  border-color: var(--border-default);
}
.acard__cover {
  height: 120px;
  background: linear-gradient(135deg, var(--surface-2), var(--surface-3));
  background-size: cover;
  background-position: center;
  display: grid;
  place-items: center;
  color: var(--brand-400);
}
.acard__cover-fallback {
  font-family: var(--font-display);
  font-size: 48px;
  font-weight: var(--weight-bold);
  opacity: 0.35;
}
.acard__body {
  padding: 14px 16px 16px;
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.acard__title {
  margin: 0;
  font-family: var(--font-body);
  font-size: 16px;
  font-weight: var(--weight-bold);
  color: var(--text-primary);
  line-height: 1.25;
}
.acard__excerpt {
  margin: 0;
  font-size: 13px;
  color: var(--text-secondary);
  line-height: 1.45;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
.acard__meta {
  margin: 4px 0 0;
  font-size: 11px;
  color: var(--text-tertiary);
}
</style>
