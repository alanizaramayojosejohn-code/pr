# Supabase

## Proyecto

- **URL:** `https://zpexmkwbmnczeoikbnao.supabase.co`
- **Key pública:** `sb_publishable_...` (ver `.env`)
- **Cliente:** `src/supabase/index.ts`

```ts
import { createClient } from "@supabase/supabase-js";

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseKey = import.meta.env.VITE_SUPABASE_KEY;

export const supabase = createClient(supabaseUrl, supabaseKey);
```

## Tablas de dominio

Todas con RLS habilitada. Convención de políticas:

- El dueño (`user_id = auth.uid()`) puede `SELECT/INSERT/UPDATE/DELETE` sus propias filas.
- Admin tiene `*_admin_select` (solo lectura) sobre tablas de datos de usuario.
- `Exercise` es catálogo global: lectura para todos los autenticados, escritura solo admin.

### `profiles`

Perfil extendido del usuario. PK = `id` (referencia a `auth.users.id`).

| Campo         | Tipo                      | Notas                                                   |
|---------------|---------------------------|---------------------------------------------------------|
| `id`          | uuid                      | PK; FK a `auth.users(id)`                              |
| `email`       | text                      | Denormalizado                                          |
| `role`        | text (`user`\|`admin`)    | Default `user`                                         |
| `status`      | text (`approved`\|`blocked`) | Sin estado `pending` — las cuentas nacen aprobadas   |
| `expires_at`  | timestamptz (null)        | Null para admins; para `user` suele ser now() + 30d     |
| `created_at`  | timestamptz               |                                                         |

### `Exercise`

Catálogo global gestionado por admin.

| Campo         | Tipo      | Notas                                |
|---------------|-----------|--------------------------------------|
| `id`          | bigint    | PK                                   |
| `name`        | text      |                                      |
| `description` | text      |                                      |
| `image_url`   | text      | Bucket `exercise-images`             |
| `video_url`   | text      | Bucket `exercise-videos`             |
| `rest_seconds`| integer   | Default 60                           |
| `created_at`  | timestamptz |                                    |

### `routines`

| Campo         | Tipo              | Notas                                  |
|---------------|-------------------|----------------------------------------|
| `id`          | uuid              | PK (default `gen_random_uuid()`)       |
| `user_id`     | uuid              | FK a `auth.users`                      |
| `name`        | text              |                                        |
| `day_of_week` | integer (0-6,null)| 0=domingo … 6=sábado; null = sin día   |
| `notes`       | text              |                                        |
| `created_at`  | timestamptz       |                                        |

### `routine_exercises`

Tabla puente ordenada.

| Campo          | Tipo          | Notas                             |
|----------------|---------------|-----------------------------------|
| `id`           | uuid          | PK                                |
| `routine_id`   | uuid          | FK a `routines`                   |
| `exercise_id`  | bigint        | FK a `Exercise`                   |
| `position`     | integer       | Orden dentro de la rutina (0..N)  |
| `target_sets`  | integer       |                                   |
| `target_reps`  | integer       |                                   |
| `rest_seconds` | integer       |                                   |

### `workout_sessions`

Cada ejecución de una rutina.

| Campo         | Tipo        | Notas                                  |
|---------------|-------------|----------------------------------------|
| `id`          | uuid        | PK                                     |
| `user_id`     | uuid        | FK a `auth.users`                      |
| `routine_id`  | uuid (null) | FK a `routines` (null si libre)        |
| `started_at`  | timestamptz | Default `now()`                        |
| `finished_at` | timestamptz (null) | Se rellena al finalizar          |
| `notes`       | text        |                                        |

### `exercise_logs`

Cada serie registrada dentro de una sesión.

| Campo               | Tipo      | Notas                                       |
|---------------------|-----------|---------------------------------------------|
| `id`                | uuid      | PK                                          |
| `session_id`        | uuid      | FK a `workout_sessions`                     |
| `exercise_id`       | bigint    | FK a `Exercise`                             |
| `set_number`        | integer   | 1..N dentro del ejercicio en esa sesión     |
| `weight`            | numeric (null) | Null hasta completar                   |
| `reps`              | integer (null) | Null hasta completar                   |
| `rest_seconds_used` | integer (null) | Guardado al marcar ✓                   |
| `created_at`        | timestamptz    |                                         |

> Convención: un set está "completado" cuando `weight` y `reps` no son nulos. `finish()` borra los logs incompletos antes de cerrar la sesión.

### `body_measurements`

| Campo          | Tipo          | Notas                                |
|----------------|---------------|--------------------------------------|
| `id`           | uuid          | PK                                   |
| `user_id`      | uuid          | FK a `auth.users`                    |
| `measured_at`  | date          | Default `CURRENT_DATE`               |
| `weight_kg`    | numeric (null)|                                      |
| `body_fat_pct` | numeric (null)|                                      |
| `waist_cm`     | numeric (null)|                                      |
| `chest_cm`     | numeric (null)|                                      |
| `arm_cm`       | numeric (null)|                                      |
| `thigh_cm`     | numeric (null)|                                      |
| `notes`        | text (null)   |                                      |
| `created_at`   | timestamptz   |                                      |

### `tareas`

Scaffold heredado (candidato a borrar). No forma parte del producto.

## Edge Functions

### `admin-create-user`

Crea un usuario nuevo. Validación:

1. El caller debe tener JWT válido y `profiles.role = 'admin'`.
2. Usa `service_role` internamente para:
   - `supabase.auth.admin.createUser({ email, password, email_confirm: true })`.
   - `INSERT` en `profiles` con `role`, `status = 'approved'` y `expires_at`.

Llamada desde `useUsers.ts`.

## Jobs programados (pg_cron)

### `expire_old_profiles_daily`

Diario a las 02:00 UTC:

```sql
UPDATE profiles
SET status = 'blocked'
WHERE role = 'user'
  AND expires_at IS NOT NULL
  AND expires_at < now()
  AND status <> 'blocked';
```

## Storage

Dos buckets referenciados desde `useExercise.ts`:

- `exercise-images` — iconos/imágenes del ejercicio
- `exercise-videos` — videos demostrativos

Lectura pública, escritura solo admin.

## Autenticación

- Provider: **email + password**.
- Métodos usados (`useAuth.ts`):
  - `supabase.auth.signInWithPassword({ email, password })`
  - `supabase.auth.signOut()`
  - `supabase.auth.getSession()` / `onAuthStateChange`
  - `supabase.auth.updateUser({ password })` (cambio de contraseña en `/cuenta`)
- No se usa `signUp` público — las cuentas se crean vía Edge Function `admin-create-user`.

## Tipos TypeScript

El proyecto no tiene tipos generados desde Supabase. Para generarlos:

```sh
npx supabase gen types typescript --project-id zpexmkwbmnczeoikbnao > src/supabase/types.ts
```

Luego tipar el cliente:

```ts
import type { Database } from "./types";
export const supabase = createClient<Database>(supabaseUrl, supabaseKey);
```
