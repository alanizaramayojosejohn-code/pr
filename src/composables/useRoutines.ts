import { ref } from "vue";
import { supabase } from "@/supabase";
import type { Exercise } from "./useExercise";

export interface RoutineExercise {
  id: string;
  routine_id: string;
  exercise_id: number;
  position: number;
  target_sets: number;
  target_reps: number;
  rest_seconds: number;
  exercise?: Exercise;
}

export interface Routine {
  id: string;
  user_id: string;
  name: string;
  day_of_week: number | null;
  notes: string | null;
  created_at: string;
  routine_exercises?: RoutineExercise[];
}

export const DAYS = [
  { value: 1, label: "Lunes" },
  { value: 2, label: "Martes" },
  { value: 3, label: "Miércoles" },
  { value: 4, label: "Jueves" },
  { value: 5, label: "Viernes" },
  { value: 6, label: "Sábado" },
  { value: 0, label: "Domingo" },
];

export function dayLabel(d: number | null): string {
  if (d === null || d === undefined) return "Sin día";
  return DAYS.find((x) => x.value === d)?.label ?? "—";
}

export function useRoutines() {
  const routines = ref<Routine[]>([]);
  const loading = ref(false);
  const error = ref<string | null>(null);

  async function fetchRoutines() {
    loading.value = true;
    error.value = null;
    const { data, error: err } = await supabase
      .from("routines")
      .select(
        `*, routine_exercises(*, exercise:Exercise(*))`
      )
      .order("day_of_week", { ascending: true, nullsFirst: false });
    if (err) error.value = err.message;
    else {
      const list = (data as Routine[]) ?? [];
      for (const r of list) {
        r.routine_exercises?.sort((a, b) => a.position - b.position);
      }
      routines.value = list;
    }
    loading.value = false;
  }

  async function createRoutine(payload: {
    name: string;
    day_of_week: number | null;
    notes?: string;
  }) {
    error.value = null;
    const { data: userRes } = await supabase.auth.getUser();
    if (!userRes.user) return null;

    const { data, error: err } = await supabase
      .from("routines")
      .insert({ ...payload, user_id: userRes.user.id })
      .select()
      .single();
    if (err) {
      error.value = err.message;
      return null;
    }
    await fetchRoutines();
    return data as Routine;
  }

  async function updateRoutine(id: string, patch: Partial<Routine>) {
    error.value = null;
    const { error: err } = await supabase
      .from("routines")
      .update(patch)
      .eq("id", id);
    if (err) {
      error.value = err.message;
      return false;
    }
    await fetchRoutines();
    return true;
  }

  async function deleteRoutine(id: string) {
    error.value = null;
    const { error: err } = await supabase.from("routines").delete().eq("id", id);
    if (err) {
      error.value = err.message;
      return false;
    }
    await fetchRoutines();
    return true;
  }

  async function addExerciseToRoutine(
    routineId: string,
    exercise: Exercise,
    overrides?: { target_sets?: number; target_reps?: number; rest_seconds?: number }
  ) {
    error.value = null;
    const r = routines.value.find((x) => x.id === routineId);
    const position = (r?.routine_exercises?.length ?? 0);
    const { error: err } = await supabase.from("routine_exercises").insert({
      routine_id: routineId,
      exercise_id: exercise.id!,
      position,
      target_sets: overrides?.target_sets ?? 3,
      target_reps: overrides?.target_reps ?? 10,
      rest_seconds: overrides?.rest_seconds ?? exercise.rest_seconds ?? 60,
    });
    if (err) {
      error.value = err.message;
      return false;
    }
    await fetchRoutines();
    return true;
  }

  async function addExercisesToRoutine(routineId: string, exercises: Exercise[]) {
    error.value = null;
    if (!exercises.length) return true;
    const r = routines.value.find((x) => x.id === routineId);
    const startPos = r?.routine_exercises?.length ?? 0;
    const rows = exercises.map((ex, i) => ({
      routine_id: routineId,
      exercise_id: ex.id!,
      position: startPos + i,
      target_sets: 3,
      target_reps: 10,
      rest_seconds: ex.rest_seconds ?? 60,
    }));
    const { error: err } = await supabase.from("routine_exercises").insert(rows);
    if (err) {
      error.value = err.message;
      return false;
    }
    await fetchRoutines();
    return true;
  }

  async function updateRoutineExercise(
    id: string,
    patch: Partial<Pick<RoutineExercise, "target_sets" | "target_reps" | "rest_seconds" | "position">>
  ) {
    error.value = null;
    const { error: err } = await supabase
      .from("routine_exercises")
      .update(patch)
      .eq("id", id);
    if (err) {
      error.value = err.message;
      return false;
    }
    await fetchRoutines();
    return true;
  }

  async function removeRoutineExercise(id: string) {
    error.value = null;
    const { error: err } = await supabase
      .from("routine_exercises")
      .delete()
      .eq("id", id);
    if (err) {
      error.value = err.message;
      return false;
    }
    await fetchRoutines();
    return true;
  }

  async function reorderRoutine(routineId: string, exerciseId: string, direction: -1 | 1) {
    const r = routines.value.find((x) => x.id === routineId);
    if (!r?.routine_exercises) return;
    const items = [...r.routine_exercises].sort((a, b) => a.position - b.position);
    const idx = items.findIndex((x) => x.id === exerciseId);
    const swapIdx = idx + direction;
    if (idx < 0 || swapIdx < 0 || swapIdx >= items.length) return;

    const a = items[idx];
    const b = items[swapIdx];
    if (!a || !b) return;
    await supabase.from("routine_exercises").update({ position: b.position }).eq("id", a.id);
    await supabase.from("routine_exercises").update({ position: a.position }).eq("id", b.id);
    await fetchRoutines();
  }

  return {
    routines,
    loading,
    error,
    fetchRoutines,
    createRoutine,
    updateRoutine,
    deleteRoutine,
    addExerciseToRoutine,
    addExercisesToRoutine,
    updateRoutineExercise,
    removeRoutineExercise,
    reorderRoutine,
  };
}
