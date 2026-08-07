#!/usr/bin/env node
/**
 * Convierte las descripciones de ejercicios de voseo a tuteo estándar.
 *
 * Env vars requeridas (las mismas que import-exercises):
 *   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
 *
 * Opciones:
 *   DRY_RUN=1   → muestra los cambios sin escribir a Supabase
 *   VERBOSE=1   → imprime cada línea modificada
 */

import { createClient } from "@supabase/supabase-js";
import { readFileSync, existsSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = path.resolve(__dirname, "..");

// ── Env vars ──────────────────────────────────────────────────────────────────

function loadDotEnv(file) {
  if (!existsSync(file)) return;
  const src = readFileSync(file, "utf8");
  for (const line of src.split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$/i);
    if (!m) continue;
    if (process.env[m[1]] !== undefined) continue;
    let val = m[2];
    if (
      (val.startsWith('"') && val.endsWith('"')) ||
      (val.startsWith("'") && val.endsWith("'"))
    )
      val = val.slice(1, -1);
    process.env[m[1]] = val;
  }
}
loadDotEnv(path.join(PROJECT_ROOT, ".env.local"));
loadDotEnv(path.join(PROJECT_ROOT, ".env"));

process.env.SUPABASE_URL ??= process.env.VITE_SUPABASE_URL;

const DRY_RUN = process.env.DRY_RUN === "1";
const VERBOSE = process.env.VERBOSE === "1";

let SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY ?? "";
if (SERVICE_KEY.startsWith("sb_secret_")) {
  const inner = SERVICE_KEY.slice("sb_secret_".length);
  if (inner.startsWith("eyJ")) SERVICE_KEY = inner;
}

if (!process.env.SUPABASE_URL || !SERVICE_KEY) {
  console.error("Faltan env vars SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY.");
  process.exit(1);
}

const supabase = createClient(process.env.SUPABASE_URL, SERVICE_KEY, {
  auth: { persistSession: false },
});

// ── Diccionario voseo → tuteo ─────────────────────────────────────────────────
//
// Clave: forma voseo (minúsculas).
// Valor: forma tuteo equivalente.
//
// Incluye:
//   • Imperativos regulares -AR (bajá → baja)
//   • Imperativos irregulares con cambio vocálico (soltá → suelta, empezá → empieza)
//   • Imperativos -ER/-IR regulares e irregulares
//   • Formas reflexivas comunes
//   • Presente de indicativo más comunes en instrucciones

const DICT = {
  // ── Irregulares con cambio vocálico — AR ────────────────────────────────────
  "empezá": "empieza",
  "comenzá": "comienza",
  "soltá": "suelta",
  "apretá": "aprieta",
  "acercate": "acércate",
  "acercáte": "acércate",
  "colgá": "cuelga",
  "encontrá": "encuentra",
  "recordá": "recuerda",
  "mostrá": "muestra",
  "contá": "cuenta",
  "acostá": "acuesta",
  "acostáte": "acuéstate",
  "acostate": "acuéstate",
  "cerráte": "ciérrate",
  // ── Regulares -AR (sin cambio vocálico): bajá → baja ────────────────────────
  // Se manejan por regex al final; aquí solo los más frecuentes en gym.
  "usá": "usa",
  "tomá": "toma",
  "bajá": "baja",
  "girá": "gira",
  "incliná": "inclina",
  "estirá": "estira",
  "flexioná": "flexiona",
  "rotá": "rota",
  "colocá": "coloca",
  "apoyá": "apoya",
  "llevá": "lleva",
  "cruzá": "cruza",
  "realizá": "realiza",
  "respirá": "respira",
  "inhalá": "inhala",
  "exhalá": "exhala",
  "descansá": "descansa",
  "empujá": "empuja",
  "jalá": "jala",
  "tirá": "tira",
  "doblá": "dobla",
  "sacá": "saca",
  "agarrá": "agarra",
  "cargá": "carga",
  "regresá": "regresa",
  "separé": "separa",
  "separá": "separa",
  "colocáte": "colócate",
  "colocate": "colócate",
  "bajate": "bájate",
  "bajáte": "bájate",
  "parráte": "párate",
  "paráte": "párate",
  "parate": "párate",
  "agachate": "agáchate",
  "agacháte": "agáchate",
  "inclinate": "inclínate",
  "inclináte": "inclínate",
  "giráte": "gírate",
  "girate": "gírate",
  "estirarte": "estirarte",   // sin cambio (tuteo ya correcto)
  "tensá": "tensa",
  "relajá": "relaja",
  "apretáte": "apriétate",
  "apretate": "apriétate",
  "soltáte": "suéltate",
  "soltate": "suéltate",
  "contraé": "contrae",
  "arrancá": "arranca",
  "levantáte": "levántate",
  "levantate": "levántate",
  "agachate": "agáchate",
  // ── Irregulares -ER ─────────────────────────────────────────────────────────
  "volvé": "vuelve",
  "mové": "mueve",
  "extendé": "extiende",
  "mantené": "mantén",
  "sostené": "sostén",
  "prometé": "promete",
  "corré": "corre",
  "traé": "trae",
  "caé": "cae",
  "poné": "pon",
  "ponéte": "ponte",
  "ponete": "ponte",
  "sabé": "sabe",
  // ── Irregulares -IR ─────────────────────────────────────────────────────────
  "subí": "sube",
  "seguí": "sigue",
  "abrí": "abre",
  "cerrá": "cierra",
  "salí": "sal",
  "veníte": "ven",
  "vení": "ven",
  "hacé": "haz",
  "hacélo": "hazlo",
  "hacela": "hazla",
  "hacelos": "hazlos",
  "decí": "di",
  // ── Indicativo presente (menos común en instrucciones) ──────────────────────
  "podés": "puedes",
  "tenés": "tienes",
  "querés": "quieres",
  "hacés": "haces",
  "sabés": "sabes",
  "notás": "notas",
  "sentís": "sientes",
  // ── Typos / tildes faltantes frecuentes ─────────────────────────────────────
  // "Concentrate" (falta tilde) → "Concéntrate"
  "concentrate": "concéntrate",
};

// ── Motor de sustitución ──────────────────────────────────────────────────────

/** Aplica la sustitución preservando la capitalización de la primera letra. */
function applyCase(original, replacement) {
  if (!original || !replacement) return replacement;
  if (original[0] === original[0].toUpperCase()) {
    return replacement[0].toUpperCase() + replacement.slice(1);
  }
  return replacement;
}

/**
 * Reemplaza todas las instancias del diccionario en el texto,
 * delimitadas por word boundaries. No distingue mayúsculas.
 */
function applyDict(text) {
  let result = text;
  for (const [voseo, tuteo] of Object.entries(DICT)) {
    // Escapar caracteres especiales de regex y caracteres acentuados
    const escaped = voseo.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    // Usar lookbehind/lookahead para delimitar palabras respetando acentos
    const re = new RegExp(`(?<![\\wáéíóúüñÁÉÍÓÚÜÑ])${escaped}(?![\\wáéíóúüñÁÉÍÓÚÜÑ])`, "gi");
    result = result.replace(re, (match) => applyCase(match, tuteo));
  }
  return result;
}

/**
 * Regex de respaldo para imperatives regulares -AR no cubiertos por el diccionario.
 * Patrón: consonante(s) + "á" al final de palabra, sin ser palabras como "allá", "acá".
 * Solo aplica si hay al menos 2 letras antes del -á final.
 * Exclusiones: está, irá, irás, acá, allá, así, quizá, más, además, mamá, papá, sofá.
 */
const EXCLUDE_FINAL_A_ACCENT = new Set([
  "está", "estará", "irá", "irás", "saldrá", "acá", "allá",
  "quizá", "además", "más", "así", "mamá", "papá", "sofá", "atrás",
  "demás", "jamás", "canfá", "cafá",
]);

function applyFallbackAR(text) {
  // Palabras de 3+ chars que terminan en á (con acento) seguidas de boundary
  return text.replace(
    /(?<![áéíóúüñÁÉÍÓÚÜÑ\w])([A-Za-záéíóúüñÁÉÍÓÚÜÑ]{2,})á(?![áéíóúüñÁÉÍÓÚÜÑ\w])/g,
    (match, stem) => {
      const lower = (stem + "á").toLowerCase();
      if (EXCLUDE_FINAL_A_ACCENT.has(lower)) return match;
      // Solo si el stem termina en consonante (probablemente imperativo -AR)
      const lastStemChar = stem[stem.length - 1].toLowerCase();
      if ("aeiouáéíóúü".includes(lastStemChar)) return match;
      const replacement = stem + "a";
      return applyCase(match, replacement);
    }
  );
}

/** Aplica todas las transformaciones a un string de descripción. */
function fixDescription(text) {
  if (!text) return text;
  let fixed = applyDict(text);
  fixed = applyFallbackAR(fixed);
  return fixed;
}

// ── Main ──────────────────────────────────────────────────────────────────────

async function main() {
  console.log(DRY_RUN ? "🔍 DRY RUN — no se escribirá nada" : "✏️  Modo escritura activado");
  console.log("Obteniendo ejercicios desde Supabase…\n");

  let allExercises = [];
  let from = 0;
  const PAGE = 1000;

  while (true) {
    const { data, error } = await supabase
      .from("Exercise")
      .select("id, name, description")
      .not("description", "is", null)
      .range(from, from + PAGE - 1);

    if (error) {
      console.error("Error al leer exercises:", error.message);
      process.exit(1);
    }
    if (!data || data.length === 0) break;
    allExercises = allExercises.concat(data);
    if (data.length < PAGE) break;
    from += PAGE;
  }

  console.log(`Total ejercicios con descripción: ${allExercises.length}\n`);

  const toUpdate = [];

  for (const ex of allExercises) {
    const original = ex.description;
    const fixed = fixDescription(original);

    if (fixed !== original) {
      toUpdate.push({ id: ex.id, name: ex.name, description: fixed });

      if (VERBOSE) {
        console.log(`\n── ${ex.name} (id ${ex.id})`);
        // Mostrar solo las líneas que cambiaron
        const origLines = original.split("\n");
        const fixedLines = fixed.split("\n");
        for (let i = 0; i < origLines.length; i++) {
          if (origLines[i] !== fixedLines[i]) {
            console.log(`  - ${origLines[i]}`);
            console.log(`  + ${fixedLines[i]}`);
          }
        }
      }
    }
  }

  console.log(`Ejercicios con cambios: ${toUpdate.length} / ${allExercises.length}`);

  if (toUpdate.length === 0) {
    console.log("\n✅ No hay voseo pendiente.");
    return;
  }

  if (DRY_RUN) {
    console.log("\nEjemplos de cambios (primeros 5):");
    for (const ex of toUpdate.slice(0, 5)) {
      console.log(`  • ${ex.name} (id ${ex.id})`);
    }
    console.log("\nVuelve a correr sin DRY_RUN=1 para aplicar los cambios.");
    return;
  }

  // Actualizar en lotes de 50
  const BATCH = 50;
  let updated = 0;

  for (let i = 0; i < toUpdate.length; i += BATCH) {
    const batch = toUpdate.slice(i, i + BATCH);
    for (const ex of batch) {
      const { error } = await supabase
        .from("Exercise")
        .update({ description: ex.description })
        .eq("id", ex.id);

      if (error) {
        console.error(`✗ Error al actualizar ${ex.name} (id ${ex.id}):`, error.message);
      } else {
        updated++;
      }
    }
    process.stdout.write(`\r  Actualizados: ${updated} / ${toUpdate.length}`);
  }

  console.log(`\n\n✅ Listo. ${updated} ejercicios actualizados.`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
