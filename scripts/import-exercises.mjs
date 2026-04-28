#!/usr/bin/env node
/**
 * Importa el catálogo de free-exercise-db a la tabla Exercise + bucket exercise-images.
 * Idempotente: usa `source_id` como clave estable — correr de nuevo actualiza sin duplicar.
 *
 * Env vars requeridas:
 *   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
 *
 * Env vars opcionales:
 *   ANTHROPIC_API_KEY  + IMPORT_TRANSLATE=1  → traduce instrucciones vía Claude Haiku 4.5
 *   IMPORT_LIMIT=50    → procesa solo N ejercicios (para probar)
 *   IMPORT_SKIP_IMAGES=1 → no vuelve a subir imágenes (útil para re-runs que solo actualizan texto)
 *   IMPORT_SKIP_CATEGORIES=stretching,strongman → filtra esas categorías
 *   IMPORT_SKIP_EQUIPMENT=bands,exercise ball,medicine ball,foam roll → filtra esos equipos
 */
import { createClient } from "@supabase/supabase-js";
import { mkdir, readFile, writeFile, access } from "node:fs/promises";
import { constants as fsConstants, readFileSync, existsSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = path.resolve(__dirname, "..");

// Carga .env y .env.local (local-pisa-committed). Sin dependencias externas.
function loadDotEnv(file) {
  if (!existsSync(file)) return;
  const src = readFileSync(file, "utf8");
  for (const line of src.split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$/i);
    if (!m) continue;
    const key = m[1];
    if (process.env[key] !== undefined) continue;
    let val = m[2];
    if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
      val = val.slice(1, -1);
    }
    process.env[key] = val;
  }
}
loadDotEnv(path.join(PROJECT_ROOT, ".env.local"));
loadDotEnv(path.join(PROJECT_ROOT, ".env"));

// Compatibilidad con los nombres de Vite
process.env.SUPABASE_URL ??= process.env.VITE_SUPABASE_URL;
const ROOT_REPO = "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main";
const JSON_URL = `${ROOT_REPO}/dist/exercises.json`;
const IMG_BASE = `${ROOT_REPO}/exercises`;

const BUCKET = "exercise-images";
const STORAGE_PREFIX = "seed";
const TMP = path.resolve(__dirname, "..", "tmp");
const TMP_JSON = path.join(TMP, "exercises.json");

const CONCURRENCY = 6;
const LIMIT = Number(process.env.IMPORT_LIMIT ?? 0) || Infinity;
const START = Math.max(0, Number(process.env.IMPORT_START ?? 0) || 0);
const SKIP_IMAGES = process.env.IMPORT_SKIP_IMAGES === "1";
const SKIP_CATEGORIES = new Set(
  (process.env.IMPORT_SKIP_CATEGORIES ?? "")
    .split(",")
    .map((s) => s.trim().toLowerCase())
    .filter(Boolean)
);
const SKIP_EQUIPMENT = new Set(
  (process.env.IMPORT_SKIP_EQUIPMENT ?? "")
    .split(",")
    .map((s) => s.trim().toLowerCase())
    .filter(Boolean)
);
const HAS_DEEPL = !!process.env.DEEPL_API_KEY;
const HAS_ANTHROPIC = !!process.env.ANTHROPIC_API_KEY;
const DO_TRANSLATE =
  process.env.IMPORT_TRANSLATE === "1" && (HAS_DEEPL || HAS_ANTHROPIC);
const TRANSLATE_PROVIDER = HAS_DEEPL ? "deepl" : HAS_ANTHROPIC ? "anthropic" : "none";

// Traducciones locales (curadas a mano). Tienen prioridad sobre cualquier API.
const LOCAL_TRANSLATIONS_FILE = path.join(__dirname, "translations.es.json");
let localTranslations = {};
try {
  if (existsSync(LOCAL_TRANSLATIONS_FILE)) {
    localTranslations = JSON.parse(readFileSync(LOCAL_TRANSLATIONS_FILE, "utf8"));
  }
} catch (e) {
  console.warn(`⚠ No pude leer translations.es.json: ${e.message}`);
}

const SUPABASE_URL = process.env.SUPABASE_URL;
let SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!SUPABASE_URL || !SERVICE_KEY) {
  console.error(
    "Faltan env vars SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY.\n" +
      "Obtén la service_role key en Supabase → Settings → API."
  );
  process.exit(1);
}

// Validación temprana del formato de la key — ayuda a diagnosticar errores comunes
const keyPrefix = SERVICE_KEY.slice(0, 16);
const looksLikePublishable = SERVICE_KEY.startsWith("sb_publishable_");
if (looksLikePublishable) {
  console.error(
    `✗ La key cargada empieza con "${keyPrefix}…" — es una publishable/anon key.\n` +
      "  Necesitás la service_role key (Supabase → Settings → API Keys → service_role)."
  );
  process.exit(1);
}
// Si viene con prefijo sb_secret_ pero contiene JWT adentro, usamos el JWT puro.
// PostgREST acepta el JWT directamente; el prefijo es solo una etiqueta visual.
if (SERVICE_KEY.startsWith("sb_secret_")) {
  const inner = SERVICE_KEY.slice("sb_secret_".length);
  if (inner.startsWith("eyJ")) {
    SERVICE_KEY = inner;
    console.log(`◦ Key: prefijo sb_secret_ removido → usando JWT (${keyPrefix}…)`);
  } else {
    console.log(`◦ Key: formato sb_secret_ opaco (${keyPrefix}…)`);
  }
} else if (SERVICE_KEY.startsWith("eyJ")) {
  console.log(`◦ Key: JWT directo (${keyPrefix}…)`);
} else {
  console.warn(
    `⚠ Formato desconocido (${keyPrefix}…). Revisá que no haya comillas o espacios en .env.local.`
  );
}

const supabase = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { persistSession: false },
});

const PUBLIC_URL = (key) =>
  supabase.storage.from(BUCKET).getPublicUrl(key).data.publicUrl;

const MUSCLE_TO_SLUG = {
  chest: "pecho",
  lats: "espalda",
  "middle back": "espalda",
  "lower back": "espalda",
  traps: "espalda",
  biceps: "brazo",
  triceps: "brazo",
  forearms: "brazo",
  shoulders: "hombro",
  quadriceps: "cuadriceps",
  hamstrings: "isquios",
  glutes: "gluteos",
  calves: "pantorrilla",
  abdominals: "core",
  neck: "core",
  adductors: "aductores",
  abductors: "aductores",
};

function createLimit(n) {
  let active = 0;
  const queue = [];
  const next = () => {
    if (active >= n) return;
    const item = queue.shift();
    if (!item) return;
    active++;
    item
      .fn()
      .then(item.resolve, item.reject)
      .finally(() => {
        active--;
        next();
      });
  };
  return (fn) =>
    new Promise((resolve, reject) => {
      queue.push({ fn, resolve, reject });
      next();
    });
}

async function ensureTmp() {
  await mkdir(TMP, { recursive: true });
}

async function loadExercisesJson() {
  await ensureTmp();
  try {
    await access(TMP_JSON, fsConstants.F_OK);
    const raw = await readFile(TMP_JSON, "utf8");
    return JSON.parse(raw);
  } catch {
    console.log("↓ Descargando exercises.json…");
    const res = await fetch(JSON_URL);
    if (!res.ok) throw new Error(`No pude bajar exercises.json: ${res.status}`);
    const text = await res.text();
    await writeFile(TMP_JSON, text);
    return JSON.parse(text);
  }
}

async function fetchCategoryMap() {
  const { data, error } = await supabase
    .from("exercise_categories")
    .select("id, slug");
  if (error) throw error;
  const map = {};
  for (const row of data ?? []) map[row.slug] = row.id;
  return map;
}

function pickRest(ex) {
  if (ex.category === "stretching") return 30;
  if (ex.mechanic === "compound") return 90;
  if (ex.mechanic === "isolation") return 60;
  return 60;
}

async function uploadOne(ex, srcPath, i) {
  const key = `${STORAGE_PREFIX}/${ex.id}/${i}.jpg`;
  if (SKIP_IMAGES) return PUBLIC_URL(key);

  const res = await fetch(`${IMG_BASE}/${srcPath}`);
  if (!res.ok) {
    if (res.status === 404) return null;
    throw new Error(`fetch ${srcPath}: ${res.status}`);
  }
  const buf = Buffer.from(await res.arrayBuffer());
  if (buf.length < 200) return null; // placeholder/empty

  const { error } = await supabase.storage
    .from(BUCKET)
    .upload(key, buf, {
      contentType: "image/jpeg",
      upsert: true,
      cacheControl: "31536000",
    });
  if (error) throw error;
  return PUBLIC_URL(key);
}

async function uploadImages(ex) {
  const [img0, img1] = ex.images ?? [];
  if (!img0) return [null, null];
  const urls = await Promise.all([
    uploadOne(ex, img0, 0),
    img1 ? uploadOne(ex, img1, 1) : Promise.resolve(null),
  ]);
  return urls;
}

// ---- Translation (opcional) ----
const TRANSLATE_SYSTEM = [
  "Eres un traductor especializado en fitness y entrenamiento de gimnasio.",
  "Traduces instrucciones de ejercicios de inglés a español neutro.",
  "Mantén la terminología técnica precisa: dumbbell=mancuerna, barbell=barra, cable=polea, machine=máquina, kettlebell=pesa rusa, EZ bar=barra Z, foam roller=rodillo de espuma.",
  "Press=press (no traducir). Curl=curl (no traducir). Squat=sentadilla. Deadlift=peso muerto. Lunge=zancada.",
  "Devuelve SOLO un array JSON con los pasos traducidos en el mismo orden, sin comentarios ni texto adicional.",
].join(" ");

async function translateViaAnthropic(arr) {
  const body = {
    model: "claude-haiku-4-5-20251001",
    max_tokens: 1500,
    system: [
      { type: "text", text: TRANSLATE_SYSTEM, cache_control: { type: "ephemeral" } },
    ],
    messages: [{ role: "user", content: JSON.stringify(arr) }],
  };
  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-api-key": process.env.ANTHROPIC_API_KEY,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify(body),
  });
  if (!res.ok) throw new Error(`Claude ${res.status}`);
  const data = await res.json();
  const text = data?.content?.[0]?.text?.trim() ?? "";
  const parsed = JSON.parse(text);
  if (!Array.isArray(parsed) || !parsed.every((x) => typeof x === "string")) {
    throw new Error("Respuesta no parseable");
  }
  return parsed;
}

// DeepL Free: https://www.deepl.com/docs-api. Hasta 50 `text` params por request.
// La key Free termina en `:fx` y usa api-free.deepl.com; la Pro no tiene sufijo y usa api.deepl.com.
async function translateViaDeepL(arr) {
  const key = process.env.DEEPL_API_KEY;
  const host = key.endsWith(":fx") ? "https://api-free.deepl.com" : "https://api.deepl.com";
  const form = new URLSearchParams();
  form.set("source_lang", "EN");
  form.set("target_lang", "ES");
  form.set("preserve_formatting", "1");
  for (const t of arr) form.append("text", t);
  const res = await fetch(`${host}/v2/translate`, {
    method: "POST",
    headers: {
      Authorization: `DeepL-Auth-Key ${key}`,
      "content-type": "application/x-www-form-urlencoded",
    },
    body: form.toString(),
  });
  if (!res.ok) throw new Error(`DeepL ${res.status}`);
  const data = await res.json();
  const list = data?.translations ?? [];
  if (list.length !== arr.length) throw new Error("DeepL: count mismatch");
  return list.map((t) => t.text);
}

async function translateInstructions(arr, sourceId) {
  if (!Array.isArray(arr) || arr.length === 0) return arr;

  // 1) Prioridad: traducción curada a mano en translations.es.json
  const local = localTranslations[sourceId];
  if (Array.isArray(local) && local.length === arr.length && local.every((s) => typeof s === "string")) {
    return local;
  }

  // 2) Fallback a API si está activada
  if (!DO_TRANSLATE) return arr;
  try {
    if (TRANSLATE_PROVIDER === "deepl") return await translateViaDeepL(arr);
    if (TRANSLATE_PROVIDER === "anthropic") return await translateViaAnthropic(arr);
  } catch (e) {
    console.warn(`  ! Traducción falló (${e.message ?? e}) — EN`);
  }
  return arr;
}

async function processOne(ex, slugToCatId) {
  const [img0, img1] = await uploadImages(ex);
  const primary = ex.primaryMuscles?.[0];
  const catSlug = primary ? MUSCLE_TO_SLUG[primary] : null;
  const catId = catSlug ? slugToCatId[catSlug] ?? null : null;

  const translated = await translateInstructions(ex.instructions ?? [], ex.id);
  const description = translated.join("\n\n");

  const row = {
    source_id: ex.id,
    name: ex.name,
    description,
    image_url: img0 ?? "",
    image_url_2: img1 ?? null,
    video_url: "",
    equipment: ex.equipment,
    mechanic: ex.mechanic,
    level: ex.level,
    category_id: catId,
    rest_seconds: pickRest(ex),
  };

  const { error } = await supabase
    .from("Exercise")
    .upsert(row, { onConflict: "source_id" });
  if (error) throw error;
}

async function main() {
  console.log("◦ SUPABASE_URL:", SUPABASE_URL);
  const localCount = Object.keys(localTranslations).length;
  const apiLabel = DO_TRANSLATE
    ? TRANSLATE_PROVIDER === "deepl" ? "DeepL" : "Claude Haiku"
    : "off";
  console.log(`◦ Traducciones: ${localCount} local + API ${apiLabel}`);
  console.log("◦ Skip images:", SKIP_IMAGES ? "yes" : "no");
  if (START > 0 || LIMIT !== Infinity) {
    const end = LIMIT === Infinity ? "fin" : START + LIMIT;
    console.log(`◦ Rango: [${START}, ${end})`);
  }

  const all = await loadExercisesJson();
  const end = LIMIT === Infinity ? all.length : START + LIMIT;
  let exercises = all.slice(START, end);
  if (SKIP_CATEGORIES.size) {
    const before = exercises.length;
    exercises = exercises.filter(
      (e) => !SKIP_CATEGORIES.has((e.category ?? "").toLowerCase())
    );
    console.log(
      `◦ Filtro categorías [${[...SKIP_CATEGORIES].join(",")}]: ${before} → ${exercises.length}`
    );
  }
  if (SKIP_EQUIPMENT.size) {
    const before = exercises.length;
    exercises = exercises.filter(
      (e) => !SKIP_EQUIPMENT.has((e.equipment ?? "").toLowerCase())
    );
    console.log(
      `◦ Filtro equipment [${[...SKIP_EQUIPMENT].join(",")}]: ${before} → ${exercises.length}`
    );
  }
  console.log(`✓ ${all.length} ejercicios en el JSON (procesando ${exercises.length})`);

  const slugToCatId = await fetchCategoryMap();
  const expectedSlugs = new Set(Object.values(MUSCLE_TO_SLUG));
  const missing = [...expectedSlugs].filter((s) => !slugToCatId[s]);
  if (missing.length) {
    console.error(`✗ Faltan categorías en DB: ${missing.join(", ")}`);
    process.exit(1);
  }

  const limit = createLimit(CONCURRENCY);
  let ok = 0,
    err = 0;
  const t0 = Date.now();

  const tasks = exercises.map((ex) =>
    limit(async () => {
      try {
        await processOne(ex, slugToCatId);
        ok++;
      } catch (e) {
        err++;
        console.error(`\n  ✗ ${ex.id}:`, e.message ?? e);
      } finally {
        const done = ok + err;
        if (done % 10 === 0 || done === exercises.length) {
          process.stdout.write(
            `\r  ${done}/${exercises.length}  (ok ${ok}, err ${err})`
          );
        }
      }
    })
  );

  await Promise.all(tasks);
  const secs = ((Date.now() - t0) / 1000).toFixed(1);
  console.log(`\n\n✓ Importados: ${ok}  ✗ Errores: ${err}  ⏱ ${secs}s`);
}

main().catch((e) => {
  console.error("\nFALLÓ:", e);
  process.exit(1);
});
