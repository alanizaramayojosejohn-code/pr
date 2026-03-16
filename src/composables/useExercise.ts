import { supabase } from "@/supabase";
import { ref } from "vue";

export interface Exercise {
  id?: string;
  name: string;
  description: string;
  image_url: string;
  video_url: string;
}

export function useExercise() {
  const exercise = ref<Exercise[]>([]);

  // Sube un archivo a Storage y retorna la URL pública
  async function uploadFile(file: File, bucket: string): Promise<string> {
    // Genera un nombre único para evitar colisiones
    const fileName = `${Date.now()}-${file.name}`;

    const { error } = await supabase.storage
      .from(bucket)
      .upload(fileName, file);

    if (error) throw error;

    // Obtiene la URL pública del archivo subido
    const { data } = supabase.storage
      .from(bucket)
      .getPublicUrl(fileName);

    return data.publicUrl;
  }

  async function getExercises() {
    const { data, error } = await supabase
      .from("Exercises")
      .select("*")
      .order("created_at", { ascending: true });

    if (error) console.error(error);
    else exercise.value = data as Exercise[];
  }

  async function createExercise(
    newExercise: Omit<Exercise, "id">,
    imageFile?: File,
    videoFile?: File
  ) {
    let image_url = newExercise.image_url;
    let video_url = newExercise.video_url;

    // Si hay archivos los sube a Storage primero
    if (imageFile) image_url = await uploadFile(imageFile, "exercise-images");
    if (videoFile) video_url = await uploadFile(videoFile, "exercise-videos");

    const { error } = await supabase
      .from("Exercises")
      .insert({ ...newExercise, image_url, video_url });

    if (error) console.error(error);
    else await getExercises();
  }

  async function updateExercise(
    id: string,
    data: Partial<Exercise>,
    imageFile?: File,
    videoFile?: File
  ) {
    let image_url = data.image_url;
    let video_url = data.video_url;

    if (imageFile) image_url = await uploadFile(imageFile, "exercise-images");
    if (videoFile) video_url = await uploadFile(videoFile, "exercise-videos");

    const { error } = await supabase
      .from("Exercises")
      .update({ ...data, image_url, video_url })
      .eq("id", id);

    if (error) console.error(error);
    else await getExercises();
  }

  async function deleteExercise(id: string) {
    const { error } = await supabase
      .from("Exercises")
      .delete()
      .eq("id", id);

    if (error) console.error(error);
    else await getExercises();
  }

  return {
    exercise,
    getExercises,
    createExercise,
    updateExercise,
    deleteExercise,
  };
}