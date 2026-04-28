import { computed } from "vue";
import MarkdownIt from "markdown-it";
import DOMPurify from "dompurify";
import meta from "@/content/articles/_meta.json";

export interface ArticleCategory {
  slug: string;
  name: string;
  description: string;
  icon: string;
  sort: number;
}

export interface Article {
  slug: string;
  title: string;
  category: string;
  excerpt: string;
  cover: string;
  published: string;
  author: string;
  body: string;
  readingMinutes: number;
}

const md = new MarkdownIt({ html: false, linkify: true, typographer: true, breaks: false });

const rawModules = import.meta.glob("@/content/articles/*.md", {
  eager: true,
  query: "?raw",
  import: "default",
}) as Record<string, string>;

function parseFrontmatter(raw: string): { data: Record<string, string>; body: string } {
  const match = /^---\r?\n([\s\S]*?)\r?\n---\r?\n([\s\S]*)$/.exec(raw);
  if (!match) return { data: {}, body: raw };
  const [, fmText = "", body = ""] = match;
  const data: Record<string, string> = {};
  for (const line of fmText.split(/\r?\n/)) {
    const m = /^([a-zA-Z_][\w-]*)\s*:\s*(.*)$/.exec(line);
    if (!m) continue;
    const [, key = "", value = ""] = m;
    data[key] = value.trim().replace(/^["'](.*)["']$/, "$1");
  }
  return { data, body };
}

function slugFromPath(path: string): string {
  const m = /\/([^/]+)\.md$/.exec(path);
  return m?.[1] ?? path;
}

function readingTime(body: string): number {
  const words = body.replace(/[#*_`>\-[\]()!]/g, " ").trim().split(/\s+/).length;
  return Math.max(1, Math.round(words / 220));
}

const allArticles: Article[] = Object.entries(rawModules)
  .map(([path, raw]) => {
    const { data, body } = parseFrontmatter(raw);
    return {
      slug: slugFromPath(path),
      title: data.title ?? "Sin título",
      category: data.category ?? "entrenamiento",
      excerpt: data.excerpt ?? "",
      cover: data.cover ?? "",
      published: data.published ?? "",
      author: data.author ?? "PR Team",
      body,
      readingMinutes: readingTime(body),
    };
  })
  .filter((a) => !a.slug.startsWith("_"))
  .sort((a, b) => (a.published < b.published ? 1 : -1));

const categoriesSorted: ArticleCategory[] = [...(meta.categories as ArticleCategory[])].sort(
  (a, b) => a.sort - b.sort
);

export function useArticles() {
  const articles = computed(() => allArticles);
  const categories = computed(() => categoriesSorted);

  function articlesByCategory(slug: string): Article[] {
    return allArticles.filter((a) => a.category === slug);
  }

  function findArticle(slug: string): Article | null {
    return allArticles.find((a) => a.slug === slug) ?? null;
  }

  function findCategory(slug: string): ArticleCategory | null {
    return categoriesSorted.find((c) => c.slug === slug) ?? null;
  }

  function renderMarkdown(body: string): string {
    return DOMPurify.sanitize(md.render(body));
  }

  function formatDate(iso: string): string {
    if (!iso) return "";
    const d = new Date(iso);
    if (Number.isNaN(d.getTime())) return iso;
    return d.toLocaleDateString("es-AR", { day: "numeric", month: "long", year: "numeric" });
  }

  return {
    articles,
    categories,
    articlesByCategory,
    findArticle,
    findCategory,
    renderMarkdown,
    formatDate,
  };
}
