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

## Roles

| Rol          | Dónde trabaja      | Puede                                                                 |
|--------------|--------------------|-----------------------------------------------------------------------|
| `user`       | App Android        | Entrenar, sus rutinas, su progreso                                     |
| `instructor` | App Android        | Todo lo de `user` + dar de alta clientes suyos, mantener plantillas, enviárselas y leer su actividad |
| `admin`      | Panel PWA          | Catálogo de ejercicios, alta de cualquier cuenta, vencimientos, asignar instructor a un cliente |

El panel PWA es solo para `admin`: `useAuth.ts` cierra la sesión de cualquier
otro rol. Los instructores gestionan a sus alumnos desde la app.

Un cliente cuelga de su instructor por `profiles.instructor_id`. Todo el
control de acceso del instructor pasa por `is_my_client()`, así que ampliar su
alcance a otra tabla es agregar una política con esa misma condición.

## Tablas de dominio

Todas con RLS habilitada. Convención de políticas:

- El dueño (`user_id = auth.uid()`) puede `SELECT/INSERT/UPDATE/DELETE` sus propias filas.
- Admin tiene `*_admin_select` (solo lectura) sobre tablas de datos de usuario.
- El instructor tiene `instructor_*` sobre las filas de sus alumnos: escritura en
  `routines` y `routine_exercises`, solo lectura en `workout_sessions`,
  `exercise_logs`, `body_measurements` y `profiles`.
- `Exercise` es catálogo global: lectura para todos los autenticados, escritura solo admin.

### `profiles`

Perfil extendido del usuario. PK = `id` (referencia a `auth.users.id`).

| Campo           | Tipo                                    | Notas                                                 |
|-----------------|-----------------------------------------|-------------------------------------------------------|
| `id`            | uuid                                    | PK; FK a `auth.users(id)`                             |
| `email`         | text                                    | Denormalizado                                         |
| `role`          | text (`user`\|`instructor`\|`admin`)    | Default `user`; con CHECK                             |
| `status`        | text (`approved`\|`blocked`)            | Sin estado `pending` — las cuentas nacen aprobadas     |
| `expires_at`    | timestamptz (null)                      | Null para admins e instructores; para `user`, now() + 30d |
| `instructor_id` | uuid (null)                             | FK a `profiles(id)`. Solo lo llevan los clientes       |
| `created_at`    | timestamptz                             |                                                       |

### `Exercise`

Catálogo global gestionado por admin.

| Campo         | Tipo        | Notas                                     |
|---------------|-------------|-------------------------------------------|
| `id`          | bigint      | PK                                        |
| `name`        | varchar     |                                           |
| `description` | text        | Instrucciones separadas por línea en blanco |
| `image_url`   | text        | Bucket `exercise-images`                  |
| `image_url_2` | text        | Segunda pose                              |
| `video_url`   | text        | Bucket `exercise-videos`                  |
| `rest_seconds`| integer     | Default 60                                |
| `category_id` | uuid        | FK a `exercise_categories`                |
| `equipment`   | text        |                                           |
| `mechanic`    | text        |                                           |
| `level`       | text        |                                           |
| `source_id`   | text        | Clave estable del importador (idempotencia) |
| `created_at`  | timestamptz |                                           |

### `exercise_categories`

| Campo        | Tipo        | Notas                          |
|--------------|-------------|--------------------------------|
| `id`         | uuid        | PK                             |
| `name`       | text        |                                |
| `slug`       | text        | Usado por los filtros de la app |
| `sort_order` | integer     | Default 0                      |
| `created_at` | timestamptz |                                |

### `routines`

| Campo                | Tipo           | Notas                                                        |
|----------------------|----------------|--------------------------------------------------------------|
| `id`                 | uuid           | PK (default `gen_random_uuid()`)                             |
| `user_id`            | uuid           | FK a `auth.users`                                            |
| `name`               | text           |                                                              |
| `days_of_week`       | integer[]      | 0=domingo … 6=sábado; array vacío = sin día                  |
| `notes`              | text           |                                                              |
| `is_template`        | boolean        | Default false. true = plantilla del instructor, no se entrena |
| `source_template_id` | uuid (null)    | FK a `routines`. Plantilla de la que salió esta copia         |
| `assigned_by`        | uuid (null)    | FK a `profiles`. Instructor que la envió                      |
| `created_at`         | timestamptz    |                                                              |

> El panel PWA todavía consulta `day_of_week` (singular), columna que ya no
> existe: su pantalla de rutinas quedó obsoleta con el rewrite Flutter y hoy no
> está ruteada.

### `routine_exercises`

Tabla puente ordenada.

| Campo            | Tipo          | Notas                             |
|------------------|---------------|-----------------------------------|
| `id`             | uuid          | PK                                |
| `routine_id`     | uuid          | FK a `routines`                   |
| `exercise_id`    | bigint        | FK a `Exercise`                   |
| `position`       | integer       | Orden dentro de la rutina         |
| `target_sets`    | integer       |                                   |
| `target_reps`    | integer       |                                   |
| `rest_seconds`   | integer       |                                   |
| `default_weight` | numeric (null)| Peso sugerido por el instructor   |

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

## Funciones SQL

Fuente: `supabase/migrations/20260801120000_instructor_role.sql`.

| Función                                     | Qué hace                                                                 |
|---------------------------------------------|--------------------------------------------------------------------------|
| `is_admin()`                                | Preexistente; la usan las políticas de admin                              |
| `is_instructor()`                           | true si quien llama es instructor aprobado                                |
| `is_my_client(uuid)`                        | true si ese perfil es alumno de quien llama                               |
| `assign_routine_template(template, client)` | Copia una plantilla a la cuenta del alumno y devuelve el id de la copia   |

`assign_routine_template` es `SECURITY DEFINER` y comprueba la autorización
adentro. Existe para que copiar rutina + ejercicios sea atómico: hacerlo con
inserts sueltos desde el cliente dejaría media rutina si falla uno. Reenviar la
misma plantilla **reescribe** la copia del alumno en vez de duplicarla.

## Edge Functions

### `create-user`

Alta de cuentas. Fuente en `supabase/functions/create-user/index.ts`.

1. El caller debe tener JWT válido y `profiles.role` en (`admin`, `instructor`),
   con `status = 'approved'`. El rol se lee de la base, nunca del body.
2. Admin: crea `user`, `instructor` o `admin`, y puede pasar `instructor_id`
   para un cliente.
3. Instructor: el rol se fuerza a `user` y `instructor_id` a su propio id.
4. Usa `service_role` para `auth.admin.createUser({ email_confirm: true })` y
   luego `upsert` en `profiles`. Si el perfil falla, borra la cuenta recién
   creada para no dejarla huérfana.

Llamada desde `useUsers.ts` (panel) e `instructor_repository.dart` (app).

Desplegar: `npx supabase functions deploy create-user --project-ref zpexmkwbmnczeoikbnao`

### `admin-create-user` (heredada)

Versión anterior, solo admin. Su código nunca estuvo en el repo. Quedó
desplegada pero ya no la llama nadie; se puede borrar del proyecto Supabase.

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
