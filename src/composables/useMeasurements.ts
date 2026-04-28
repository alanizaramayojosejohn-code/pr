import { ref } from "vue";
import { supabase } from "@/supabase";

export interface BodyMeasurement {
  id: string;
  user_id: string;
  measured_at: string;
  weight_kg: number | null;
  body_fat_pct: number | null;
  waist_cm: number | null;
  chest_cm: number | null;
  arm_cm: number | null;
  thigh_cm: number | null;
  notes: string | null;
  created_at: string;
}

export type MeasurementField =
  | "weight_kg"
  | "body_fat_pct"
  | "waist_cm"
  | "chest_cm"
  | "arm_cm"
  | "thigh_cm";

export const MEASUREMENT_FIELDS: { key: MeasurementField; label: string; unit: string }[] = [
  { key: "weight_kg", label: "Peso", unit: "kg" },
  { key: "body_fat_pct", label: "Grasa corporal", unit: "%" },
  { key: "waist_cm", label: "Cintura", unit: "cm" },
  { key: "chest_cm", label: "Pecho", unit: "cm" },
  { key: "arm_cm", label: "Brazo", unit: "cm" },
  { key: "thigh_cm", label: "Muslo", unit: "cm" },
];

export type MeasurementPayload = Partial<Pick<BodyMeasurement, MeasurementField | "measured_at" | "notes">>;

export function useMeasurements() {
  const measurements = ref<BodyMeasurement[]>([]);
  const loading = ref(false);
  const error = ref<string | null>(null);

  async function fetchMeasurements() {
    loading.value = true;
    error.value = null;
    const { data, error: err } = await supabase
      .from("body_measurements")
      .select("*")
      .order("measured_at", { ascending: false })
      .order("created_at", { ascending: false });
    if (err) error.value = err.message;
    else measurements.value = (data as BodyMeasurement[]) ?? [];
    loading.value = false;
  }

  async function createMeasurement(payload: MeasurementPayload) {
    error.value = null;
    const { data: userRes } = await supabase.auth.getUser();
    if (!userRes.user) return null;

    const { data, error: err } = await supabase
      .from("body_measurements")
      .insert({ ...payload, user_id: userRes.user.id })
      .select()
      .single();
    if (err) {
      error.value = err.message;
      return null;
    }
    await fetchMeasurements();
    return data as BodyMeasurement;
  }

  async function updateMeasurement(id: string, patch: MeasurementPayload) {
    error.value = null;
    const { error: err } = await supabase
      .from("body_measurements")
      .update(patch)
      .eq("id", id);
    if (err) {
      error.value = err.message;
      return false;
    }
    await fetchMeasurements();
    return true;
  }

  async function deleteMeasurement(id: string) {
    error.value = null;
    const { error: err } = await supabase
      .from("body_measurements")
      .delete()
      .eq("id", id);
    if (err) {
      error.value = err.message;
      return false;
    }
    await fetchMeasurements();
    return true;
  }

  return {
    measurements,
    loading,
    error,
    fetchMeasurements,
    createMeasurement,
    updateMeasurement,
    deleteMeasurement,
  };
}
