import { supabase } from "@/supabase";
import { ref } from "vue";

export interface Exercise {
  id?: number;
  name: string;
  description: string;
  image_url: string;
  video_url: string;
  rest_seconds?: number;
  category_id?: string | null;
  image_url_2?: string | null;
  equipment?: string | null;
  mechanic?: string | null;
  level?: string | null;
  source_id?: string | null;
}

export function useExercise() {
  const exercise = ref<Exercise[]>([]);
  const loading = ref(false);
  const error = ref<string | null>(null);

  async function uploadFile(file: File, bucket: string): Promise<string> {
    const fileName = `${Date.now()}-${file.name}`;
    const { error: err } = await supabase.storage.from(bucket).upload(fileName, file);
    if (err) throw err;
    const { data } = supabase.storage.from(bucket).getPublicUrl(fileName);
    return data.publicUrl;
  }

  async function getExercises() {
    loading.value = true;
    error.value = null;
    const { data, error: err } = await supabase
      .from("Exercise")
      .select("*")
      .order("created_at", { ascending: true });
    if (err) error.value = err.message;
    else exercise.value = data as Exercise[];
    loading.value = false;
  }

  async function createExercise(
    newExercise: Omit<Exercise, "id">,
    imageFile?: File,
    videoFile?: File
  ) {
    loading.value = true;
    error.value = null;
    try {
      let image_url = newExercise.image_url;
      let video_url = newExercise.video_url;
      if (imageFile) image_url = await uploadFile(imageFile, "exercise-images");
      if (videoFile) video_url = await uploadFile(videoFile, "exercise-videos");

      const { error: err } = await supabase
        .from("Exercise")
        .insert({ ...newExercise, image_url, video_url });
      if (err) throw err;
      await getExercises();
      return true;
    } catch (e) {
      error.value = e instanceof Error ? e.message : "Error al crear ejercicio";
      return false;
    } finally {
      loading.value = false;
    }
  }

  async function updateExercise(
    id: number,
    data: Partial<Exercise>,
    imageFile?: File,
    videoFile?: File
  ) {
    loading.value = true;
    error.value = null;
    try {
      let image_url = data.image_url;
      let video_url = data.video_url;
      if (imageFile) image_url = await uploadFile(imageFile, "exercise-images");
      if (videoFile) video_url = await uploadFile(videoFile, "exercise-videos");

      const { error: err } = await supabase
        .from("Exercise")
        .update({ ...data, image_url, video_url })
        .eq("id", id);
      if (err) throw err;
      await getExercises();
      return true;
    } catch (e) {
      error.value = e instanceof Error ? e.message : "Error al actualizar";
      return false;
    } finally {
      loading.value = false;
    }
  }

  async function getById(id: number): Promise<Exercise | null> {
    error.value = null;
    const { data, error: err } = await supabase
      .from("Exercise")
      .select("*")
      .eq("id", id)
      .single();
    if (err) {
      error.value = err.message;
      return null;
    }
    return data as Exercise;
  }

  async function deleteExercise(id: number) {
    loading.value = true;
    error.value = null;
    const { error: err } = await supabase.from("Exercise").delete().eq("id", id);
    if (err) error.value = err.message;
    else await getExercises();
    loading.value = false;
    return !err;
  }

  async function fetchPaginated(opts: {
    categoryId?: string | null;
    page?: number;
    pageSize?: number;
    search?: string;
  }): Promise<{ items: Exercise[]; total: number }> {
    const page = Math.max(1, opts.page ?? 1);
    const pageSize = opts.pageSize ?? 10;
    const from = (page - 1) * pageSize;
    const to = from + pageSize - 1;

    let q = supabase.from("Exercise").select("*", { count: "exact" });
    if (opts.categoryId === null) q = q.is("category_id", null);
    else if (opts.categoryId) q = q.eq("category_id", opts.categoryId);
    const term = opts.search?.trim();
    if (term) q = q.ilike("name", `%${term}%`);

    const { data, count, error: err } = await q
      .order("name", { ascending: true })
      .range(from, to);
    if (err) throw err;
    return { items: (data as Exercise[]) ?? [], total: count ?? 0 };
  }

  return {
    exercise,
    loading,
    error,
    getExercises,
    getById,
    createExercise,
    updateExercise,
    deleteExercise,
    fetchPaginated,
  };
}
