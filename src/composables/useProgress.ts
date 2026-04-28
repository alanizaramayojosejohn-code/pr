import { ref } from "vue";
import { supabase } from "@/supabase";

export interface WeightPoint {
  date: string;
  weight_kg: number;
}

export interface StrengthPoint {
  date: string;
  max_weight: number;
  best_1rm: number;
}

export interface ExerciseOption {
  id: number;
  name: string;
  sessions: number;
}

function epley1rm(weight: number, reps: number): number {
  if (reps <= 0) return weight;
  if (reps === 1) return weight;
  return weight * (1 + reps / 30);
}

export function useProgress() {
  const weightSeries = ref<WeightPoint[]>([]);
  const exerciseOptions = ref<ExerciseOption[]>([]);
  const strengthSeries = ref<StrengthPoint[]>([]);
  const loading = ref(false);
  const error = ref<string | null>(null);

  async function loadWeightSeries() {
    const { data, error: err } = await supabase
      .from("body_measurements")
      .select("measured_at, weight_kg")
      .not("weight_kg", "is", null)
      .order("measured_at", { ascending: true });
    if (err) {
      error.value = err.message;
      weightSeries.value = [];
      return;
    }
    const rows = (data as { measured_at: string; weight_kg: number }[]) ?? [];
    const byDay = new Map<string, { sum: number; count: number }>();
    for (const r of rows) {
      const agg = byDay.get(r.measured_at) ?? { sum: 0, count: 0 };
      agg.sum += Number(r.weight_kg);
      agg.count += 1;
      byDay.set(r.measured_at, agg);
    }
    weightSeries.value = [...byDay.entries()]
      .map(([date, agg]) => ({ date, weight_kg: agg.sum / agg.count }))
      .sort((a, b) => a.date.localeCompare(b.date));
  }

  async function loadExerciseOptions() {
    const { data: userRes } = await supabase.auth.getUser();
    if (!userRes.user) {
      exerciseOptions.value = [];
      return;
    }

    type Row = {
      exercise_id: number;
      session_id: string;
      Exercise: { id: number; name: string } | null;
      workout_sessions: { user_id: string; finished_at: string | null } | null;
    };

    const { data, error: err } = await supabase
      .from("exercise_logs")
      .select(
        "exercise_id, session_id, Exercise!inner(id, name), workout_sessions!inner(user_id, finished_at)"
      )
      .not("weight", "is", null)
      .not("reps", "is", null)
      .eq("workout_sessions.user_id", userRes.user.id)
      .not("workout_sessions.finished_at", "is", null);
    if (err) {
      error.value = err.message;
      exerciseOptions.value = [];
      return;
    }

    const agg = new Map<number, { name: string; sessions: Set<string> }>();
    for (const row of (data as unknown as Row[]) ?? []) {
      if (!row.Exercise) continue;
      const entry = agg.get(row.exercise_id) ?? {
        name: row.Exercise.name,
        sessions: new Set<string>(),
      };
      entry.sessions.add(row.session_id);
      agg.set(row.exercise_id, entry);
    }
    exerciseOptions.value = [...agg.entries()]
      .map(([id, v]) => ({ id, name: v.name, sessions: v.sessions.size }))
      .sort((a, b) => a.name.localeCompare(b.name));
  }

  async function loadStrengthSeries(exerciseId: number) {
    strengthSeries.value = [];
    if (!exerciseId) return;
    const { data: userRes } = await supabase.auth.getUser();
    if (!userRes.user) return;

    type Row = {
      weight: number;
      reps: number;
      workout_sessions: { started_at: string; user_id: string; finished_at: string | null } | null;
    };

    const { data, error: err } = await supabase
      .from("exercise_logs")
      .select("weight, reps, workout_sessions!inner(started_at, user_id, finished_at)")
      .eq("exercise_id", exerciseId)
      .not("weight", "is", null)
      .not("reps", "is", null)
      .eq("workout_sessions.user_id", userRes.user.id)
      .not("workout_sessions.finished_at", "is", null);
    if (err) {
      error.value = err.message;
      return;
    }

    const byDay = new Map<string, { maxW: number; best1rm: number }>();
    for (const row of (data as unknown as Row[]) ?? []) {
      if (!row.workout_sessions) continue;
      const date = row.workout_sessions.started_at.slice(0, 10);
      const w = Number(row.weight);
      const r = Number(row.reps);
      const rm = epley1rm(w, r);
      const cur = byDay.get(date);
      if (!cur) {
        byDay.set(date, { maxW: w, best1rm: rm });
      } else {
        if (w > cur.maxW) cur.maxW = w;
        if (rm > cur.best1rm) cur.best1rm = rm;
      }
    }
    strengthSeries.value = [...byDay.entries()]
      .map(([date, v]) => ({ date, max_weight: v.maxW, best_1rm: v.best1rm }))
      .sort((a, b) => a.date.localeCompare(b.date));
  }

  async function loadAll() {
    loading.value = true;
    error.value = null;
    await Promise.all([loadWeightSeries(), loadExerciseOptions()]);
    loading.value = false;
  }

  return {
    weightSeries,
    exerciseOptions,
    strengthSeries,
    loading,
    error,
    loadAll,
    loadWeightSeries,
    loadExerciseOptions,
    loadStrengthSeries,
  };
}
