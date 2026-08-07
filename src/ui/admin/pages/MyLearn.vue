<template>
  <section class="learn">
    <header class="learn__head">
      <h1>Aprender</h1>
      <p>Guías cortas para empezar a entrenar y comer mejor.</p>
    </header>

    <nav class="learn__cats">
      <RouterLink
        v-for="c in categories"
        :key="c.slug"
        :to="{ name: 'aprender-categoria', params: { slug: c.slug } }"
        class="cat-pill"
      >
        <span class="cat-pill__name">{{ c.name }}</span>
        <span class="cat-pill__count">{{ articlesByCategory(c.slug).length }}</span>
      </RouterLink>
    </nav>

    <p v-if="!articles.length" class="learn__empty">
      Aún no hay artículos publicados.
    </p>

    <div v-else class="learn__list">
      <RouterLink
        v-for="a in articles"
        :key="a.slug"
        :to="{ name: 'aprender-detalle', params: { slug: a.slug } }"
        class="acard"
      >
        <div
          class="acard__cover"
          :class="{ 'acard__cover--empty': !a.cover }"
          :style="a.cover ? `background-image:url(${a.cover})` : ''"
        >
          <span v-if="!a.cover" class="acard__cover-icon">📖</span>
        </div>
        <div class="acard__body">
          <h2 class="acard__title">{{ a.title }}</h2>
          <p class="acard__excerpt">{{ a.excerpt }}</p>
          <p class="acard__meta">{{ formatDate(a.published) }} · {{ a.readingMinutes }} min lectura</p>
        </div>
      </RouterLink>
    </div>
  </section>
</template>

<script setup lang="ts">
import { useArticles } from "@/composables/useArticles";

const { articles, categories, articlesByCategory, formatDate } = useArticles();
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
.learn__head h1 {
  margin: 0;
  font-family: var(--font-display);
  font-size: 26px;
  font-weight: var(--weight-bold);
  letter-spacing: -0.5px;
  color: var(--text-primary);
}
.learn__head p {
  margin: 4px 0 0;
  font-size: 13px;
  color: var(--text-tertiary);
}

.learn__cats {
  display: flex;
  gap: 8px;
  overflow-x: auto;
  padding-bottom: 4px;
  margin: 0 -20px;
  padding-left: 20px;
  padding-right: 20px;
  scrollbar-width: none;
}
.learn__cats::-webkit-scrollbar {
  display: none;
}
.cat-pill {
  flex-shrink: 0;
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 8px 14px;
  border-radius: var(--radius-pill);
  border: 1px solid var(--border-subtle);
  background: var(--surface-1);
  color: var(--text-secondary);
  text-decoration: none;
  font-size: 12px;
  font-weight: var(--weight-semibold);
  transition: border-color 120ms ease, color 120ms ease;
}
.cat-pill:hover {
  border-color: var(--brand-500);
  color: var(--brand-300);
}
.cat-pill__count {
  display: inline-grid;
  place-items: center;
  min-width: 18px;
  height: 18px;
  padding: 0 5px;
  border-radius: var(--radius-pill);
  background: var(--surface-3);
  color: var(--text-tertiary);
  font-size: 10px;
  font-weight: var(--weight-bold);
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
  gap: 14px;
}

/* ── Card ── */
.acard {
  display: grid;
  grid-template-columns: 96px 1fr;
  background: var(--surface-1);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-lg);
  text-decoration: none;
  color: inherit;
  overflow: hidden;
  transition: border-color 120ms ease, box-shadow 120ms ease;
}
.acard:hover {
  border-color: var(--border-default);
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.25);
}

/* ── Cover (left column) ── */
.acard__cover {
  background: var(--surface-2);
  background-size: cover;
  background-position: center;
  min-height: 110px;
  display: grid;
  place-items: center;
}
.acard__cover--empty {
  background: linear-gradient(145deg, var(--surface-2), var(--surface-3));
}
.acard__cover-icon {
  font-size: 28px;
  opacity: 0.5;
}

/* ── Body (right column) ── */
.acard__body {
  padding: 14px 16px;
  display: flex;
  flex-direction: column;
  gap: 5px;
  justify-content: center;
}
.acard__title {
  margin: 0;
  font-family: var(--font-body);
  font-size: 15px;
  font-weight: var(--weight-bold);
  color: var(--text-primary);
  letter-spacing: -0.2px;
  line-height: 1.3;
}
.acard__excerpt {
  margin: 0;
  font-size: 12px;
  color: var(--text-secondary);
  line-height: 1.5;
  display: -webkit-box;
  -webkit-line-clamp: 3;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
.acard__meta {
  margin: 2px 0 0;
  font-size: 11px;
  color: var(--text-tertiary);
  font-weight: var(--weight-medium);
}
</style>
