# Funcionalidades

## 1. Autenticación y roles

**Archivos:** `src/composables/useAuth.ts`, `src/ui/public/pages/MyLogin.vue`, `src/ui/admin/pages/MyAccount.vue`

- Login con email + password. **No hay autorregistro público** — solo el admin crea cuentas.
- `useAuth` carga el perfil del usuario (`profiles`) con `role` (`user` | `admin`), `status` (`approved` | `blocked`) y `expires_at`.
- Guards de router:
  - `requiresAuth` — redirige a `/login` si no hay sesión.
  - `requiresAdmin` — redirige a `/dashboard` si no es admin.
  - `onlyGuest` — redirige a `/dashboard` si ya hay sesión (protege `/login`).
- Estado expuesto: `user`, `profile`, `isLoggedIn`, `isAdmin`, `ready`, `initPromise`, `loading`, `error`.
- `/cuenta` permite cambiar contraseña del usuario actual.

### Expiración de cuentas

- `profiles.expires_at` — las cuentas tipo `user` expiran a los 30 días por defecto.
- Admins no expiran (`expires_at = null`).
- `pg_cron` diario `expire_old_profiles_daily` (02:00 UTC) pone `status = 'blocked'` en perfiles vencidos.
- Home muestra un badge in-app al admin cuando hay cuentas próximas a vencer (≤ 7 días) o ya bloqueadas por vencimiento.

## 2. Catálogo de ejercicios (admin)

**Archivos:** `src/composables/useExercise.ts`, `src/ui/admin/pages/MyExercise.vue`
**Ruta:** `/ejercicios` *(admin)*
**Tabla:** `Exercise` **·** **Buckets:** `exercise-images`, `exercise-videos`

Operaciones:

- **Listar** — `getExercises()`
- **Crear** — `createExercise(data, imageFile?, videoFile?)` sube archivos a Storage primero.
- **Actualizar** — `updateExercise(id, data, imageFile?, videoFile?)`
- **Eliminar** — `deleteExercise(id)` con `confirm()`

Campos: `name`, `description`, `image_url`, `video_url`, `rest_seconds` (default 60).

## 3. Gestión de usuarios (admin)

**Archivos:** `src/composables/useUsers.ts`, `src/ui/admin/pages/MyUsers.vue`
**Ruta:** `/usuarios` *(admin)*
**Tabla:** `profiles` **·** **Edge Function:** `admin-create-user`

- Listar todos los perfiles con rol, status, fecha de expiración y email.
- **Crear usuario**: llama a la Edge Function `admin-create-user` (valida admin por JWT + usa `service_role` para crear la cuenta auth y su perfil).
- **Renovar expiración**: suma 30 días desde `max(now, expires_at)` y reabre `status` a `approved`.
- **Bloquear / desbloquear**: toggle de `status`.
- **Cambiar rol**: `user` ↔ `admin` (admins pasan a `expires_at = null`).
- Computed `expiringSoon` (≤ 7 días) y `expiredBlocked` para los avisos de Home.

## 4. Rutinas

**Archivos:** `src/composables/useRoutines.ts`, `src/ui/admin/pages/MyRoutines.vue`
**Ruta:** `/rutinas` *(auth)*
**Tablas:** `routines`, `routine_exercises`

- Crear rutina con nombre y `day_of_week` (0-6 o `null` = sin día fijo).
- Renombrar inline (`contenteditable` en el `<h2>`).
- Cambiar día asignado (select).
- **Añadir ejercicios** del catálogo — el catálogo disponible filtra los ya presentes.
- Por cada `routine_exercise`: editar `target_sets`, `target_reps`, `rest_seconds`; reordenar ↑/↓; eliminar.
- Borrar rutina completa.
- Botón **Empezar** que crea `workout_sessions` + pre-inserta `exercise_logs` vacíos (uno por set objetivo) y navega a `/entrenar/:sessionId`.

## 5. Entrenamiento (`/entrenar/:sessionId`)

**Archivos:** `src/composables/useWorkout.ts`, `src/ui/admin/pages/MyWorkout.vue`
**Tablas:** `workout_sessions`, `exercise_logs`

UX **Strong-style**:

- **Header sticky**: nombre de rutina + cronómetro de sesión + botones `Cancelar` (borra sesión + logs) y `Finalizar` (setea `finished_at`; borra logs incompletos).
- **Rest timer flotante**: barra de progreso, botones `−15s`, `+15s`, `Saltar`.
- **Por ejercicio**: imagen + nombre + input de descanso.
  - El descanso se guarda en un mapa `pendingRest: Map<exerciseId, seconds>` inicializado con `routine_exercises.rest_seconds` y mutado a nivel de ejercicio — cambio en una serie se propaga al resto del mismo ejercicio; al pasar al siguiente ejercicio vuelve a su default.
  - Botón **"Guardar como default"** aparece cuando el valor actual difiere del `routine_exercises.rest_seconds` y persiste el cambio en la rutina (`saveRestAsDefault`).
- **Tabla de sets**: `# | Previo | kg | reps | ✓ | ×`
  - "Previo" muestra el placeholder del último entreno (`prefill`: última sesión del usuario con ese ejercicio, filtrando logs con weight/reps no nulos).
  - Al marcar `✓`: si los inputs están vacíos, copia el prefill; guarda `rest_seconds_used`; dispara el timer.
  - Volver a clicar `✓` desmarca (resetea weight/reps a `null`).
  - `×` borra una serie.
- `+ Añadir serie` — inserta nuevo `exercise_log` con `set_number = lastSet + 1`.
- `+ Añadir ejercicio` — catálogo filtrado para añadir ejercicios ad-hoc a la sesión.
- Un set cuenta como "completado" cuando `weight != null && reps != null` (no hay columna dedicada).

### Entradas al flujo

- Botón "Empezar" verde en cada rutina de `/rutinas`.
- Card "Rutina de hoy" de Home — muestra la rutina cuyo `day_of_week === new Date().getDay()`; botón Empezar inline.

## 6. Medidas corporales

**Archivos:** `src/composables/useMeasurements.ts`, `src/ui/admin/pages/MyMeasurements.vue`
**Ruta:** `/medidas` *(auth)*
**Tabla:** `body_measurements`

Campos fijos (decisión de producto): `weight_kg`, `body_fat_pct`, `waist_cm`, `chest_cm`, `arm_cm`, `thigh_cm` + `measured_at` + `notes`.

- Form de alta: fecha (default hoy) + 6 campos numéricos + notas. Guardar deshabilitado si no hay ningún número.
- Historial en tabla con **edición inline** por celda (cambios se guardan con `UPDATE`).
- Borrar fila con `×`.

## 7. Progreso (`/progreso`)

**Archivos:** `src/composables/useProgress.ts`, `src/ui/admin/pages/MyProgress.vue`, `src/ui/admin/components/LineChart.vue`
**Ruta:** `/progreso` *(auth)*

Dos gráficos con SVG plano (sin dependencias de chart library):

- **Peso corporal en el tiempo** — serie única a partir de `body_measurements.weight_kg` agrupada por día (promedio si hay múltiples entradas el mismo día).
- **Fuerza por ejercicio** — selector con los ejercicios que el usuario ha trabajado en sesiones finalizadas. Muestra dos series por día: **peso máx** y **1RM estimado** con fórmula de Epley (`w × (1 + reps/30)`).

`LineChart.vue` es un componente reutilizable: ejes auto-escalados (±10% padding), hasta 5 ticks en cada eje, tooltip con cursor sobre hover/touch, leyenda cuando hay más de una serie.

## 8. Historial (`/historial`)

**Archivos:** `src/composables/useHistory.ts`, `src/ui/admin/pages/MyHistory.vue`
**Ruta:** `/historial` *(auth)*

- Lista de `workout_sessions` con `finished_at != null` del usuario, en orden descendente por fecha.
- Por sesión: fecha, nombre de rutina, duración (`finished_at − started_at`), nº de ejercicios, nº de sets, volumen total (`Σ weight × reps`).
- Click en una fila expande el detalle: bloque por ejercicio con sus series (kg, reps, descanso usado) más máximo y volumen del ejercicio.
- Botón "Eliminar sesión" dentro del detalle expandido — borra logs + sesión con `confirm()`.

## 9. Home (`/dashboard`)

**Archivo:** `src/ui/admin/pages/MyHome.vue`

- Saludo con email.
- Admin: badges de cuentas expiradas y a punto de expirar.
- User: card "Rutina de hoy" (si existe una rutina con `day_of_week` del día) con botón Empezar.
- Grid de accesos a Rutinas / Medidas / Ejercicios / Usuarios / Mi cuenta según rol.

## 10. PWA

- `vite-plugin-pwa` en modo `autoUpdate`.
- Manifest con nombre, theme, iconos 192/512.
- `registerSW({ immediate: true })` en `main.ts`.
- `devOptions.enabled: false` — el SW solo se activa en build de producción.

## Deuda conocida

- Sin tipos generados de Supabase (`data as Profile[]`, `as Routine[]`, etc.).
- `pendingRest` en sesión no persiste — si recargas la página, vuelve al default del `routine_exercise` (pero el botón "guardar como default" permite persistirlo explícitamente).
- No hay emails transaccionales (aviso de expiración por email). Requeriría integrar Resend/SendGrid.
