// Limpia los buckets de Storage que no pertenecen a PR.
// Uso: SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... node scripts/clean-buckets.mjs [--apply]
//
// Por defecto hace DRY-RUN (lista qué borraría). Pasá --apply para ejecutar.

import { createClient } from "@supabase/supabase-js";

const KEEP = new Set(["exercise-images"]);
const APPLY = process.argv.includes("--apply");

const url = process.env.SUPABASE_URL;
const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!url || !key) {
  console.error("Faltan SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY");
  process.exit(1);
}

const supabase = createClient(url, key);

async function emptyBucket(bucket) {
  let total = 0;
  // Recorre raíz + subcarpetas en BFS
  const queue = [""];
  while (queue.length) {
    const prefix = queue.shift();
    const { data, error } = await supabase.storage.from(bucket).list(prefix, {
      limit: 1000,
      sortBy: { column: "name", order: "asc" },
    });
    if (error) throw error;
    if (!data?.length) continue;

    const files = [];
    for (const item of data) {
      const path = prefix ? `${prefix}/${item.name}` : item.name;
      if (item.id === null) {
        queue.push(path);
      } else {
        files.push(path);
      }
    }
    if (files.length) {
      if (APPLY) {
        const { error: rmErr } = await supabase.storage.from(bucket).remove(files);
        if (rmErr) throw rmErr;
      }
      total += files.length;
    }
  }
  return total;
}

async function main() {
  const { data: buckets, error } = await supabase.storage.listBuckets();
  if (error) {
    console.error("Error listando buckets:", error.message);
    process.exit(1);
  }

  const toDelete = buckets.filter((b) => !KEEP.has(b.name));
  if (!toDelete.length) {
    console.log("No hay buckets para borrar.");
    return;
  }

  console.log(`${APPLY ? "[APPLY]" : "[DRY-RUN]"} Buckets a procesar:`);
  for (const b of toDelete) console.log(`  - ${b.name}`);
  console.log("");

  for (const b of toDelete) {
    process.stdout.write(`Vaciando "${b.name}"... `);
    const removed = await emptyBucket(b.name);
    console.log(`${removed} archivos${APPLY ? " borrados" : " (dry-run)"}`);

    if (APPLY) {
      process.stdout.write(`Borrando bucket "${b.name}"... `);
      const { error: delErr } = await supabase.storage.deleteBucket(b.name);
      if (delErr) {
        console.log(`ERROR: ${delErr.message}`);
      } else {
        console.log("OK");
      }
    }
  }

  if (!APPLY) {
    console.log("\nDry-run completo. Re-ejecutá con --apply para borrar de verdad.");
  }
}

main().catch((e) => {
  console.error("Error:", e.message);
  process.exit(1);
});
