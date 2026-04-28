import { ref, computed } from "vue";
import { supabase } from "@/supabase";
import type { Exercise } from "./useExercise";
import type { Routine, RoutineExercise } from "./useRoutines";

export interface ExerciseLog {
  id: string;
  session_id: string;
  exercise_id: number;
  set_number: number;
  weight: number | null;
  reps: number | null;
  rest_seconds_used: number | null;
  created_at: string;
}

export interface WorkoutSession {
  id: string;
  user_id: string;
  routine_id: string | null;
  started_at: string;
  finished_at: string | null;
  notes: string | null;
}

export interface PrefillSet {
  set_number: number;
  weight: number | null;
  reps: number | null;
}

export function isLogCompleted(l: ExerciseLog): boolean {
  return l.rest_seconds_used !== null;
}

export function useWorkout() {
  const session = ref<WorkoutSession | null>(null);
  const routine = ref<Routine | null>(null);
  const logs = ref<ExerciseLog[]>([]);
  const exercisesById = ref<Map<number, Exercise>>(new Map());
  const prefill = ref<Map<number, PrefillSet[]>>(new Map());
  const loading = ref(false);
  const error = ref<string | null>(null);

  const exerciseIdsInSession = computed(() => {
    const ids = new Set<number>();
    for (const l of logs.value) ids.add(l.exercise_id);
    for (const re of routine.value?.routine_exercises ?? []) ids.add(re.exercise_id);
    return [...ids];
  });

  const orderedExerciseIds = computed<number[]>(() => {
    const seen = new Set<number>();
    const out: number[] = [];
    const ordered = [...(routine.value?.routine_exercises ?? [])].sort(
      (a, b) => a.position - b.position
    );
    for (const re of ordered) {
      if (!seen.has(re.exercise_id)) {
        seen.add(re.exercise_id);
        out.push(re.exercise_id);
      }
    }
    const adHocFirstSet = new Map<number, number>();
    for (const l of logs.value) {
      if (seen.has(l.exercise_id)) continue;
      const prev = adHocFirstSet.get(l.exercise_id);
      if (prev === undefined || l.set_number < prev) {
        adHocFirstSet.set(l.exercise_id, l.set_number);
      }
    }
    for (const id of adHocFirstSet.keys()) {
      seen.add(id);
      out.push(id);
    }
    return out;
  });

  function logsForExercise(exerciseId: number): ExerciseLog[] {
    return logs.value
      .filter((l) => l.exercise_id === exerciseId)
      .sort((a, b) => a.set_number - b.set_number);
  }

  function routineExerciseFor(exerciseId: number): RoutineExercise | undefined {
    return routine.value?.routine_exercises?.find((re) => re.exercise_id === exerciseId);
  }

  async function load(sessionId: string) {
    loading.value = true;
    error.value = null;
    try {
      const { data: s, error: e1 } = await supabase
        .from("workout_sessions")
        .select("*")
        .eq("id", sessionId)
        .single();
      if (e1) throw e1;
      session.value = s as WorkoutSession;

      if (s.routine_id) {
        const { data: r, error: e2 } = await supabase
          .from("routines")
          .select("*, routine_exercises(*, exercise:Exercise(*))")
          .eq("id", s.routine_id)
          .single();
        if (e2) throw e2;
        routine.value = r as Routine;
        routine.value.routine_exercises?.sort((a, b) => a.position - b.position);
      } else {
        routine.value = null;
      }

      const { data: l, error: e3 } = await supabase
        .from("exercise_logs")
        .select("*")
        .eq("session_id", sessionId);
      if (e3) throw e3;
      logs.value = (l as ExerciseLog[]) ?? [];

      await loadExercisesAndPrefill();
    } catch (e) {
      error.value = e instanceof Error ? e.message : "Error cargando sesión";
    } finally {
      loading.value = false;
    }
  }

  async function fetchPrefillData(
    userId: string,
    exerciseIds: number[],
    excludeSessionId?: string
  ): Promise<Map<number, PrefillSet[]>> {
    if (exerciseIds.length === 0) return new Map();

    let q = supabase
      .from("exercise_logs")
      .select("exercise_id, set_number, weight, reps, session_id, workout_sessions!inner(started_at, user_id, id)")
      .in("exercise_id", exerciseIds)
      .not("weight", "is", null)
      .not("reps", "is", null)
      .eq("workout_sessions.user_id", userId);
    if (excludeSessionId) q = q.neq("session_id", excludeSessionId);

    const { data } = await q.order("exercise_id", { ascending: true });

    type PrevLogRow = {
      exercise_id: number;
      set_number: number;
      weight: number | null;
      reps: number | null;
      session_id: string;
      workout_sessions: { started_at: string };
    };
    const byExercise = new Map<number, { sessionId: string; startedAt: string; sets: PrefillSet[] }>();
    for (const row of (data as PrevLogRow[] | null) ?? []) {
      const startedAt = row.workout_sessions?.started_at ?? "";
      const existing = byExercise.get(row.exercise_id);
      if (!existing || new Date(startedAt) > new Date(existing.startedAt)) {
        byExercise.set(row.exercise_id, {
          sessionId: row.session_id,
          startedAt,
          sets: [{ set_number: row.set_number, weight: row.weight, reps: row.reps }],
        });
      } else if (existing.sessionId === row.session_id) {
        existing.sets.push({ set_number: row.set_number, weight: row.weight, reps: row.reps });
      }
    }
    const out = new Map<number, PrefillSet[]>();
    for (const [id, v] of byExercise) {
      out.set(id, v.sets.sort((a, b) => a.set_number - b.set_number));
    }
    return out;
  }

  function pickPrefillSet(prev: PrefillSet[] | undefined, setNumber: number): PrefillSet | null {
    if (!prev?.length) return null;
    return prev.find((p) => p.set_number === setNumber) ?? prev[setNumber - 1] ?? prev[prev.length - 1] ?? null;
  }

  async function loadExercisesAndPrefill() {
    const ids = exerciseIdsInSession.value;
    if (ids.length === 0) {
      exercisesById.value = new Map();
      prefill.value = new Map();
      return;
    }

    const { data: exs } = await supabase
      .from("Exercise")
      .select("*")
      .in("id", ids);
    const map = new Map<number, Exercise>();
    for (const e of (exs as Exercise[]) ?? []) map.set(e.id!, e);
    exercisesById.value = map;

    const { data: userRes } = await supabase.auth.getUser();
    if (!userRes.user || !session.value) return;

    prefill.value = await fetchPrefillData(userRes.user.id, ids, session.value.id);
  }

  async function startFromRoutine(routineId: string): Promise<WorkoutSession | null> {
    error.value = null;
    const { data: userRes } = await supabase.auth.getUser();
    if (!userRes.user) return null;

    const { data: r, error: e1 } = await supabase
      .from("routines")
      .select("*, routine_exercises(*)")
      .eq("id", routineId)
      .single();
    if (e1 || !r) {
      error.value = e1?.message ?? "Rutina no encontrada";
      return null;
    }

    const ordered = [...(r.routine_exercises as RoutineExercise[])].sort(
      (a, b) => a.position - b.position
    );
    const exerciseIds = [...new Set(ordered.map((re) => re.exercise_id))];
    const prefillMap = await fetchPrefillData(userRes.user.id, exerciseIds);

    const { data: s, error: e2 } = await supabase
      .from("workout_sessions")
      .insert({ user_id: userRes.user.id, routine_id: routineId })
      .select()
      .single();
    if (e2 || !s) {
      error.value = e2?.message ?? "No se pudo crear la sesión";
      return null;
    }

    const rows: Omit<ExerciseLog, "id" | "created_at">[] = [];
    for (const re of ordered) {
      const prev = prefillMap.get(re.exercise_id);
      for (let n = 1; n <= Math.max(1, re.target_sets); n++) {
        const prevSet = pickPrefillSet(prev, n);
        rows.push({
          session_id: s.id,
          exercise_id: re.exercise_id,
          set_number: n,
          weight: prevSet?.weight ?? null,
          reps: prevSet?.reps ?? null,
          rest_seconds_used: null,
        });
      }
    }
    if (rows.length) {
      const { error: e3 } = await supabase.from("exercise_logs").insert(rows);
      if (e3) {
        error.value = e3.message;
      }
    }
    return s as WorkoutSession;
  }

  async function updateLog(id: string, patch: Partial<Pick<ExerciseLog, "weight" | "reps" | "rest_seconds_used">>) {
    error.value = null;
    const prev = logs.value.find((l) => l.id === id);
    if (prev) Object.assign(prev, patch);
    const { error: err } = await supabase
      .from("exercise_logs")
      .update(patch)
      .eq("id", id);
    if (err) {
      error.value = err.message;
      return false;
    }
    return true;
  }

  async function addSet(exerciseId: number): Promise<ExerciseLog | null> {
    error.value = null;
    if (!session.value) return null;
    const existing = logsForExercise(exerciseId);
    const nextNumber = (existing[existing.length - 1]?.set_number ?? 0) + 1;
    const prevSet = pickPrefillSet(prefill.value.get(exerciseId), nextNumber);
    const { data, error: err } = await supabase
      .from("exercise_logs")
      .insert({
        session_id: session.value.id,
        exercise_id: exerciseId,
        set_number: nextNumber,
        weight: prevSet?.weight ?? null,
        reps: prevSet?.reps ?? null,
        rest_seconds_used: null,
      })
      .select()
      .single();
    if (err || !data) {
      error.value = err?.message ?? "No se pudo añadir la serie";
      return null;
    }
    logs.value.push(data as ExerciseLog);
    return data as ExerciseLog;
  }

  async function removeSet(id: string) {
    error.value = null;
    const { error: err } = await supabase.from("exercise_logs").delete().eq("id", id);
    if (err) {
      error.value = err.message;
      return false;
    }
    logs.value = logs.value.filter((l) => l.id !== id);
    return true;
  }

  async function addExercise(exercise: Exercise, targetSets = 3) {
    if (!session.value || !exercise.id) return;
    const { data: userRes } = await supabase.auth.getUser();
    let prevSets: PrefillSet[] | undefined;
    if (userRes.user) {
      const fetched = await fetchPrefillData(userRes.user.id, [exercise.id], session.value.id);
      prevSets = fetched.get(exercise.id);
      if (prevSets) prefill.value.set(exercise.id, prevSets);
    }
    const rows: Omit<ExerciseLog, "id" | "created_at">[] = [];
    for (let n = 1; n <= targetSets; n++) {
      const prevSet = pickPrefillSet(prevSets, n);
      rows.push({
        session_id: session.value.id,
        exercise_id: exercise.id,
        set_number: n,
        weight: prevSet?.weight ?? null,
        reps: prevSet?.reps ?? null,
        rest_seconds_used: null,
      });
    }
    const { data, error: err } = await supabase
      .from("exercise_logs")
      .insert(rows)
      .select();
    if (err) {
      error.value = err.message;
      return;
    }
    for (const row of (data as ExerciseLog[]) ?? []) logs.value.push(row);
    exercisesById.value.set(exercise.id, exercise);
  }

  async function saveRestAsDefault(exerciseId: number, seconds: number): Promise<boolean> {
    error.value = null;
    const re = routineExerciseFor(exerciseId);
    if (!re) {
      error.value = "Este ejercicio no pertenece a la rutina";
      return false;
    }
    const { error: err } = await supabase
      .from("routine_exercises")
      .update({ rest_seconds: seconds })
      .eq("id", re.id);
    if (err) {
      error.value = err.message;
      return false;
    }
    re.rest_seconds = seconds;
    return true;
  }

  async function finish() {
    if (!session.value) return false;
    error.value = null;
    const isEmpty = (l: ExerciseLog) => l.weight === null && l.reps === null;
    const empty = logs.value.filter(isEmpty).map((l) => l.id);
    if (empty.length) {
      await supabase.from("exercise_logs").delete().in("id", empty);
      logs.value = logs.value.filter((l) => !isEmpty(l));
    }
    const { error: err } = await supabase
      .from("workout_sessions")
      .update({ finished_at: new Date().toISOString() })
      .eq("id", session.value.id);
    if (err) {
      error.value = err.message;
      return false;
    }
    session.value.finished_at = new Date().toISOString();
    return true;
  }

  async function abort() {
    if (!session.value) return false;
    error.value = null;
    await supabase.from("exercise_logs").delete().eq("session_id", session.value.id);
    const { error: err } = await supabase
      .from("workout_sessions")
      .delete()
      .eq("id", session.value.id);
    if (err) {
      error.value = err.message;
      return false;
    }
    session.value = null;
    logs.value = [];
    return true;
  }

  return {
    session,
    routine,
    logs,
    exercisesById,
    prefill,
    loading,
    error,
    orderedExerciseIds,
    logsForExercise,
    routineExerciseFor,
    load,
    startFromRoutine,
    updateLog,
    addSet,
    removeSet,
    addExercise,
    saveRestAsDefault,
    finish,
    abort,
  };
}
