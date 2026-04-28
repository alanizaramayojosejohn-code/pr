import { ref } from "vue";
import { supabase } from "@/supabase";

export interface ExerciseCategory {
  id: string;
  name: string;
  slug: string;
  sort_order: number;
  created_at: string;
}

function slugify(s: string): string {
  return s
    .toLowerCase()
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/(^-|-$)/g, "");
}

export function useCategories() {
  const categories = ref<ExerciseCategory[]>([]);
  const counts = ref<Record<string, number>>({});
  const uncategorizedCount = ref(0);
  const loading = ref(false);
  const error = ref<string | null>(null);

  async function fetchCategories() {
    loading.value = true;
    error.value = null;
    const { data, error: err } = await supabase
      .from("exercise_categories")
      .select("*")
      .order("sort_order", { ascending: true })
      .order("name", { ascending: true });
    if (err) error.value = err.message;
    else categories.value = (data as ExerciseCategory[]) ?? [];
    loading.value = false;
  }

  async function fetchCounts() {
    const { data, error: err } = await supabase
      .from("Exercise")
      .select("category_id");
    if (err) {
      error.value = err.message;
      return;
    }
    const map: Record<string, number> = {};
    let noCat = 0;
    for (const row of (data ?? []) as { category_id: string | null }[]) {
      if (!row.category_id) noCat += 1;
      else map[row.category_id] = (map[row.category_id] ?? 0) + 1;
    }
    counts.value = map;
    uncategorizedCount.value = noCat;
  }

  async function createCategory(name: string): Promise<ExerciseCategory | null> {
    error.value = null;
    const clean = name.trim();
    if (!clean) return null;
    const slug = slugify(clean);
    const maxOrder = categories.value.reduce((m, c) => Math.max(m, c.sort_order), 0);
    const { data, error: err } = await supabase
      .from("exercise_categories")
      .insert({ name: clean, slug, sort_order: maxOrder + 10 })
      .select()
      .single();
    if (err) {
      error.value = err.message;
      return null;
    }
    await fetchCategories();
    return data as ExerciseCategory;
  }

  async function renameCategory(id: string, name: string): Promise<boolean> {
    error.value = null;
    const clean = name.trim();
    if (!clean) return false;
    const { error: err } = await supabase
      .from("exercise_categories")
      .update({ name: clean, slug: slugify(clean) })
      .eq("id", id);
    if (err) {
      error.value = err.message;
      return false;
    }
    await fetchCategories();
    return true;
  }

  async function deleteCategory(id: string): Promise<boolean> {
    error.value = null;
    const { error: err } = await supabase
      .from("exercise_categories")
      .delete()
      .eq("id", id);
    if (err) {
      error.value = err.message;
      return false;
    }
    categories.value = categories.value.filter((c) => c.id !== id);
    return true;
  }

  return {
    categories,
    counts,
    uncategorizedCount,
    loading,
    error,
    fetchCategories,
    fetchCounts,
    createCategory,
    renameCategory,
    deleteCategory,
  };
}
