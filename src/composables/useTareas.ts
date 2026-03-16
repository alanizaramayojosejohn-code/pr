import { supabase } from "@/supabase";
import { ref } from "vue";

interface Tarea {
  id?: string;
  titulo: string;
  completada: boolean;
}

export function useTareas() {
  const tareas = ref<Tarea[]>([]);

  async function obtenerTareas() {
    const { data, error } = await supabase
      .from("tareas")
      .select("*")
      .order("created_at", { ascending: true });

    if (error) console.error(error);
    else tareas.value = data as Tarea[];
  }

  async function agregarTarea(titulo: string) {
    const { error } = await supabase
      .from("tareas")
      .insert({ titulo, completada: false });

    if (error) console.error(error);
    else await obtenerTareas();
  }

  async function actualizarTarea(id: string, datos: Partial<Tarea>) {
    const { error } = await supabase.from("tareas").update(datos).eq("id", id);

    if (error) console.error(error);
    else await obtenerTareas();
  }

  async function eliminarTarea(id: string) {
    const { error } = await supabase.from("tareas").delete().eq("id", id);

    if (error) console.error(error);
    else await obtenerTareas();
  }

  return {
    tareas,
    obtenerTareas,
    agregarTarea,
    actualizarTarea,
    eliminarTarea,
  };
}
