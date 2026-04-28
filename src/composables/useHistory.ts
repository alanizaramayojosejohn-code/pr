import { ref } from "vue";
import { supabase } from "@/supabase";

export interface HistoryLog {
  exercise_id: number;
  exercise_name: string;
  set_number: number;
  weight: number | null;
  reps: number | null;
  rest_seconds_used: number | null;
}

export interface HistoryExerciseGroup {
  exercise_id: number;
  exercise_name: string;
  sets: HistoryLog[];
  max_weight: number | null;
  total_volume: number;
}

export interface HistorySession {
  id: string;
  routine_id: string | null;
  routine_name: string | null;
  started_at: string;
  finished_at: string;
  duration_sec: number;
  total_sets: number;
  total_volume: number;
  exercise_count: number;
  exercises: HistoryExerciseGroup[];
}

type RawLog = {
  session_id: string;
  exercise_id: number;
  set_number: number;
  weight: number | null;
  reps: number | null;
  rest_seconds_used: number | null;
  Exercise: { name: string } | null;
};

type RawSession = {
  id: string;
  routine_id: string | null;
  started_at: string;
  finished_at: string;
  routines: { name: string } | null;
};

export function useHistory() {
  const sessions = ref<HistorySession[]>([]);
  const loading = ref(false);
  const error = ref<string | null>(null);

  async function fetchSessions() {
    loading.value = true;
    error.value = null;
    const { data: userRes } = await supabase.auth.getUser();
    if (!userRes.user) {
      loading.value = false;
      return;
    }

    const { data: ss, error: err1 } = await supabase
      .from("workout_sessions")
      .select("id, routine_id, started_at, finished_at, routines(name)")
      .eq("user_id", userRes.user.id)
      .not("finished_at", "is", null)
      .order("started_at", { ascending: false });
    if (err1) {
      error.value = err1.message;
      loading.value = false;
      return;
    }
    const rawSessions = (ss as unknown as RawSession[]) ?? [];
    if (rawSessions.length === 0) {
      sessions.value = [];
      loading.value = false;
      return;
    }

    const ids = rawSessions.map((s) => s.id);
    const { data: logsData, error: err2 } = await supabase
      .from("exercise_logs")
      .select("session_id, exercise_id, set_number, weight, reps, rest_seconds_used, Exercise(name)")
      .in("session_id", ids)
      .order("set_number", { ascending: true });
    if (err2) {
      error.value = err2.message;
      loading.value = false;
      return;
    }
    const rawLogs = (logsData as unknown as RawLog[]) ?? [];

    const logsBySession = new Map<string, RawLog[]>();
    for (const l of rawLogs) {
      const arr = logsBySession.get(l.session_id) ?? [];
      arr.push(l);
      logsBySession.set(l.session_id, arr);
    }

    sessions.value = rawSessions.map((s) => buildHistorySession(s, logsBySession.get(s.id) ?? []));
    loading.value = false;
  }

  function buildHistorySession(s: RawSession, logs: RawLog[]): HistorySession {
    const groups = new Map<number, HistoryExerciseGroup>();
    let totalVolume = 0;
    for (const l of logs) {
      const name = l.Exercise?.name ?? "—";
      const group = groups.get(l.exercise_id) ?? {
        exercise_id: l.exercise_id,
        exercise_name: name,
        sets: [],
        max_weight: null,
        total_volume: 0,
      };
      group.sets.push({
        exercise_id: l.exercise_id,
        exercise_name: name,
        set_number: l.set_number,
        weight: l.weight,
        reps: l.reps,
        rest_seconds_used: l.rest_seconds_used,
      });
      if (l.weight !== null && l.reps !== null) {
        const vol = Number(l.weight) * Number(l.reps);
        group.total_volume += vol;
        totalVolume += vol;
        if (group.max_weight === null || Number(l.weight) > group.max_weight) {
          group.max_weight = Number(l.weight);
        }
      }
      groups.set(l.exercise_id, group);
    }
    for (const g of groups.values()) g.sets.sort((a, b) => a.set_number - b.set_number);

    const duration = Math.max(
      0,
      Math.floor((new Date(s.finished_at).getTime() - new Date(s.started_at).getTime()) / 1000)
    );
    return {
      id: s.id,
      routine_id: s.routine_id,
      routine_name: s.routines?.name ?? null,
      started_at: s.started_at,
      finished_at: s.finished_at,
      duration_sec: duration,
      total_sets: logs.length,
      total_volume: totalVolume,
      exercise_count: groups.size,
      exercises: [...groups.values()],
    };
  }

  async function deleteSession(id: string): Promise<boolean> {
    error.value = null;
    const { error: err1 } = await supabase.from("exercise_logs").delete().eq("session_id", id);
    if (err1) {
      error.value = err1.message;
      return false;
    }
    const { error: err2 } = await supabase.from("workout_sessions").delete().eq("id", id);
    if (err2) {
      error.value = err2.message;
      return false;
    }
    sessions.value = sessions.value.filter((s) => s.id !== id);
    return true;
  }

  return {
    sessions,
    loading,
    error,
    fetchSessions,
    deleteSession,
  };
}
