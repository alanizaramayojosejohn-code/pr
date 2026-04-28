<template>
  <section v-if="!article" class="article article--empty">
    <p>Artículo no encontrado.</p>
    <RouterLink :to="{ name: 'aprender' }">Volver a Aprender</RouterLink>
  </section>

  <article v-else class="article">
    <header class="article__head">
      <button class="article__back" @click="goBack" aria-label="Volver">
        <svg viewBox="0 0 24 24" aria-hidden="true">
          <path d="M15 6l-6 6 6 6" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" fill="none" />
        </svg>
      </button>
      <RouterLink
        :to="{ name: 'aprender-categoria', params: { slug: article.category } }"
        class="article__cat"
      >{{ catName }}</RouterLink>
    </header>

    <div
      class="article__cover"
      :style="article.cover ? `background-image:url(${article.cover})` : ''"
    >
      <span v-if="!article.cover" class="article__cover-fallback">{{ article.title.charAt(0).toUpperCase() }}</span>
    </div>

    <div class="article__title">
      <h1>{{ article.title }}</h1>
      <p class="article__meta">{{ formatDate(article.published) }} · {{ article.readingMinutes }} min de lectura</p>
    </div>

    <div class="article__body" v-html="rendered"></div>

    <footer class="article__footer">
      <RouterLink :to="{ name: 'aprender' }" class="article__more">← Más artículos</RouterLink>
    </footer>
  </article>
</template>

<script setup lang="ts">
import { computed } from "vue";
import { useRoute, useRouter } from "vue-router";
import { useArticles } from "@/composables/useArticles";

const route = useRoute();
const router = useRouter();
const { findArticle, findCategory, renderMarkdown, formatDate } = useArticles();

const article = computed(() => findArticle(String(route.params.slug)));
const catName = computed(() => (article.value ? findCategory(article.value.category)?.name ?? "" : ""));
const rendered = computed(() => (article.value ? renderMarkdown(article.value.body) : ""));

function goBack() {
  if (window.history.length > 1) router.back();
  else router.push({ name: "aprender" });
}
</script>

<style scoped>
.article {
  max-width: 480px;
  margin: 0 auto;
  padding: 8px 0 24px;
  display: flex;
  flex-direction: column;
  gap: 16px;
}
.article--empty {
  text-align: center;
  padding: 64px 20px;
  color: var(--text-tertiary);
}

.article__head {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 0 20px;
}
.article__back {
  display: grid;
  place-items: center;
  width: 36px;
  height: 36px;
  border-radius: var(--radius-pill);
  border: none;
  background: var(--surface-2);
  color: var(--text-primary);
  cursor: pointer;
}
.article__back svg {
  width: 16px;
  height: 16px;
}
.article__cat {
  padding: 5px 11px;
  border-radius: var(--radius-pill);
  background: var(--brand-glow);
  color: var(--brand-300);
  text-decoration: none;
  font-size: 10px;
  font-weight: var(--weight-bold);
  letter-spacing: 0.6px;
  text-transform: uppercase;
}

.article__cover {
  height: 180px;
  background: linear-gradient(135deg, var(--surface-2), var(--surface-3));
  background-size: cover;
  background-position: center;
  display: grid;
  place-items: center;
  color: var(--brand-400);
  margin: 0 20px;
  border-radius: var(--radius-lg);
}
.article__cover-fallback {
  font-family: var(--font-display);
  font-size: 80px;
  font-weight: var(--weight-bold);
  opacity: 0.35;
}

.article__title {
  padding: 0 20px;
}
.article__title h1 {
  margin: 0;
  font-family: var(--font-display);
  font-size: 26px;
  font-weight: var(--weight-bold);
  letter-spacing: -0.5px;
  color: var(--text-primary);
  line-height: 1.2;
}
.article__meta {
  margin: 8px 0 0;
  font-size: 12px;
  color: var(--text-tertiary);
  font-weight: var(--weight-medium);
}

.article__body {
  padding: 0 20px;
  font-size: 15px;
  line-height: 1.7;
  color: var(--text-secondary);
}

.article__body :deep(h2) {
  margin: 28px 0 8px;
  font-family: var(--font-display);
  font-size: 19px;
  font-weight: var(--weight-bold);
  color: var(--text-primary);
  letter-spacing: -0.2px;
  line-height: 1.3;
}
.article__body :deep(h3) {
  margin: 20px 0 6px;
  font-family: var(--font-body);
  font-size: 16px;
  font-weight: var(--weight-bold);
  color: var(--text-primary);
}
.article__body :deep(p) {
  margin: 0 0 14px;
}
.article__body :deep(strong) {
  color: var(--text-primary);
  font-weight: var(--weight-bold);
}
.article__body :deep(em) {
  color: var(--text-primary);
}
.article__body :deep(a) {
  color: var(--brand-300);
  text-decoration: underline;
  text-decoration-color: var(--brand-glow);
  text-underline-offset: 3px;
}
.article__body :deep(a:hover) {
  text-decoration-color: var(--brand-400);
}
.article__body :deep(ul),
.article__body :deep(ol) {
  margin: 0 0 14px;
  padding-left: 20px;
}
.article__body :deep(li) {
  margin: 4px 0;
}
.article__body :deep(blockquote) {
  margin: 16px 0;
  padding: 12px 16px;
  border-left: 3px solid var(--brand-500);
  background: var(--surface-1);
  border-radius: var(--radius-sm);
  color: var(--text-primary);
  font-style: italic;
}
.article__body :deep(code) {
  padding: 2px 6px;
  border-radius: var(--radius-xs);
  background: var(--surface-2);
  font-family: ui-monospace, "SF Mono", Menlo, monospace;
  font-size: 13px;
  color: var(--brand-300);
}
.article__body :deep(pre) {
  margin: 16px 0;
  padding: 14px;
  border-radius: var(--radius-md);
  background: var(--surface-2);
  overflow-x: auto;
}
.article__body :deep(pre code) {
  padding: 0;
  background: transparent;
  color: var(--text-secondary);
  font-size: 13px;
}
.article__body :deep(hr) {
  margin: 28px 0;
  border: none;
  border-top: 1px solid var(--border-subtle);
}
.article__body :deep(table) {
  width: 100%;
  margin: 16px 0;
  border-collapse: collapse;
  font-size: 13px;
}
.article__body :deep(th),
.article__body :deep(td) {
  padding: 10px 12px;
  border-bottom: 1px solid var(--border-subtle);
  text-align: left;
  vertical-align: top;
}
.article__body :deep(th) {
  background: var(--surface-1);
  color: var(--text-primary);
  font-weight: var(--weight-bold);
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}
.article__body :deep(img) {
  max-width: 100%;
  height: auto;
  border-radius: var(--radius-md);
  margin: 16px 0;
}

.article__footer {
  padding: 24px 20px 0;
  border-top: 1px solid var(--border-subtle);
  margin: 16px 20px 0;
}
.article__more {
  color: var(--text-tertiary);
  text-decoration: none;
  font-size: 13px;
  font-weight: var(--weight-medium);
}
.article__more:hover {
  color: var(--brand-300);
}
</style>
