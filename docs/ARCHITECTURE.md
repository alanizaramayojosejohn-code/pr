# Arquitectura

## Estructura de carpetas

```
src/
├── App.vue                     # Layout raíz con <RouterView>, nav y logout
├── main.ts                     # Bootstrap: createApp + router + registerSW (PWA)
├── assets/                     # CSS y recursos estáticos
├── components/                 # Scaffold heredado (HelloWorld, TheWelcome, ...)
├── composables/                # Lógica reutilizable por feature
│   ├── useAuth.ts              # Sesión + perfil (role/status/expires_at)
│   ├── useUsers.ts             # Listado de perfiles + alta (Edge Function) + renovar/bloquear/rol
│   ├── useExercise.ts          # CRUD catálogo + upload a Storage
│   ├── useRoutines.ts          # CRUD rutinas + routine_exercises
│   ├── useWorkout.ts           # Sesión activa: logs, prefill, add/remove, finish/abort
│   ├── useMeasurements.ts      # CRUD body_measurements
│   └── useTareas.ts            # Scaffold heredado (a borrar)
├── router/
│   └── index.ts                # Rutas + guards requiresAuth / requiresAdmin / onlyGuest
├── supabase/
│   └── index.ts                # Cliente Supabase (singleton)
└── ui/
    ├── admin/pages/            # Vistas autenticadas (MyHome, MyRoutines, MyWorkout, ...)
    └── public/pages/           # Vistas públicas (MyLogin)
```

## Convenciones

- **Alias `@` → `src/`** configurado en `vite.config.ts`.
- **Composables** exponen `ref`s reactivos y funciones async. Patrón `useXxx()`. Tras cada mutación suelen refrescar con el fetch correspondiente (sincronía optimista mínima).
- **UI**: vistas en `ui/admin` requieren sesión; `ui/public` accesibles sin login. La subcarpeta `admin` es histórica — la mayoría de esas vistas son de usuario normal, no de rol admin.
- **Router** usa `createWebHashHistory` (URLs con `#`), apto para hosting estático sin reescritura de rutas.
- **PWA**: `vite-plugin-pwa` en modo `autoUpdate`. `registerSW({ immediate: true })` en `main.ts`. `devOptions.enabled: false`.

## Flujo de autenticación

1. `MyLogin.vue` usa `useAuth().login(email, password)`.
2. Supabase persiste la sesión en `localStorage`.
3. `useAuth` escucha `onAuthStateChange` y, con cada sesión válida, carga `profiles` (role/status/expires_at) y expone `isLoggedIn`, `isAdmin`, `ready`, `initPromise`.
4. `router.beforeEach` espera a `initPromise` y aplica los guards:
   - `onlyGuest` — impide entrar a `/login` con sesión activa.
   - `requiresAuth` — redirige a `/login` si no hay sesión.
   - `requiresAdmin` — redirige a `/dashboard` si el rol no es admin.

## Ciclo de una sesión de entrenamiento

1. Desde `/rutinas` o Home ("Rutina de hoy") → `startFromRoutine(routineId)`:
   - `INSERT` en `workout_sessions` con `user_id`, `routine_id`, `started_at = now()`.
   - `INSERT` batch en `exercise_logs` con una fila por cada set objetivo de cada `routine_exercise`, con `weight`/`reps` nulos.
   - Navega a `/entrenar/:sessionId`.
2. `useWorkout.load(sessionId)` carga sesión, rutina (+ routine_exercises + Exercise), logs, y hace **prefill**: query a `exercise_logs` + `workout_sessions` del mismo usuario, filtrando logs con peso/reps no nulos, agrupando por ejercicio → coge los sets de la sesión más reciente.
3. Completar un set: `updateLog(id, { weight, reps, rest_seconds_used })`. Arranca rest timer (intervalo `setInterval` en la página) con el valor de `pendingRest[exerciseId]`.
4. Finalizar: `finish()` borra logs incompletos (weight/reps null) y escribe `finished_at`. Abort: `abort()` elimina logs + sesión.

## Storage

- Buckets: `exercise-images`, `exercise-videos`.
- `useExercise.uploadFile(file, bucket)` genera un nombre único (`Date.now()-nombre`) y devuelve la URL pública.
- Las URLs se guardan en `image_url` / `video_url` de `Exercise`.
- Políticas: lectura pública; escritura solo admin.

## Build y despliegue

- `npm run build` ejecuta `run-p type-check build-only` (paralelo).
- `type-check` usa `vue-tsc --build`.
- Hay configuración de Firebase (`firebase.json`, `.firebaserc`) pensada para despliegue en Firebase Hosting.
