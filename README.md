# pr — Gym Tracker PWA

PWA para llevar el progreso en el gimnasio: rutinas, pesos por ejercicio, repeticiones, temporizador de descansos y medidas corporales. Un **administrador** gestiona el catálogo de ejercicios disponibles y autoriza qué usuarios pueden acceder.

Construida con **Vue 3 + Vite + TypeScript** y conectada a **Supabase** (auth, base de datos y storage).

Ver [`docs/PRODUCT.md`](docs/PRODUCT.md) para la visión completa del producto.

## Stack

- **Frontend:** Vue 3 (Composition API, `<script setup>`), Vue Router 4
- **Build:** Vite 7
- **Lenguaje:** TypeScript ~5.9
- **Backend:** Supabase (`@supabase/supabase-js`)
- **PWA:** `vite-plugin-pwa` (autoUpdate)
- **DevTools:** `vite-plugin-vue-devtools`

## Requisitos

- Node `^20.19.0` o `>=22.12.0`
- Cuenta/proyecto en Supabase

## Configuración

Crea un archivo `.env` en la raíz con:

```
VITE_SUPABASE_URL=https://<tu-proyecto>.supabase.co
VITE_SUPABASE_KEY=<tu-publishable-key>
```

El cliente se inicializa en `src/supabase/index.ts` y se reutiliza en todos los composables.

## Scripts

```sh
npm install          # instala dependencias
npm run dev          # servidor de desarrollo (Vite)
npm run build        # type-check + build de producción
npm run preview      # previsualiza el build
npm run type-check   # solo vue-tsc
```

## Documentación

- [`docs/PRODUCT.md`](docs/PRODUCT.md) — visión del producto, usuarios, dominio y roadmap
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — estructura de carpetas y convenciones
- [`docs/SUPABASE.md`](docs/SUPABASE.md) — esquema, tablas usadas y buckets de Storage
- [`docs/FEATURES.md`](docs/FEATURES.md) — funcionalidades actuales y rutas

## Rutas

| Ruta                    | Vista                  | Auth | Admin |
|-------------------------|------------------------|------|-------|
| `/`                     | → `/dashboard`         | —    | —     |
| `/login`                | `MyLogin.vue`          | No   | —     |
| `/dashboard`            | `MyHome.vue`           | Sí   | No    |
| `/rutinas`              | `MyRoutines.vue`       | Sí   | No    |
| `/medidas`              | `MyMeasurements.vue`   | Sí   | No    |
| `/entrenar/:sessionId`  | `MyWorkout.vue`        | Sí   | No    |
| `/cuenta`               | `MyAccount.vue`        | Sí   | No    |
| `/ejercicios`           | `MyExercise.vue`       | Sí   | Sí    |
| `/usuarios`             | `MyUsers.vue`          | Sí   | Sí    |
| `/tareas`               | `MyTasks.vue`          | Sí   | No    |

El router usa `createWebHashHistory` y protege las rutas con `meta.requiresAuth` / `meta.requiresAdmin` leyendo el perfil (`profiles.role`) desde `useAuth`.

> `/tareas` es scaffold heredado candidato a borrar.
