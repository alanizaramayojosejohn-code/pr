# Producto

## Visión

PWA para controlar el progreso en el gimnasio. El usuario final registra sus entrenamientos día a día (rutinas, pesos, repeticiones, descansos) y su evolución física (medidas corporales). Un administrador cura el catálogo de ejercicios disponibles y controla quién puede acceder a la aplicación.

## Usuarios

### Usuario final (gym-goer)

Persona que entrena y quiere llevar un registro cuantitativo de su progreso.

**Necesidades clave:**
- Crear y organizar sus **rutinas** (conjuntos de ejercicios por día/sesión).
- Registrar, para cada ejercicio en cada sesión, el **peso levantado** y las **repeticiones** realizadas.
- Usar un **temporizador de descanso** entre series.
- Registrar sus **medidas físicas** (peso corporal, cintura, brazo, pierna, pecho, etc.) y consultar su evolución en el tiempo.
- Volver a sesiones anteriores para comparar progreso.

### Administrador

Persona que gestiona el contenido y el acceso a la plataforma.

**Necesidades clave:**
- Mantener el **catálogo de ejercicios** disponibles (nombre, descripción, imagen, video, descanso default).
- **Crear** cuentas de usuario y gestionarlas (renovar expiración, bloquear, cambiar rol).
- Ver la lista de usuarios registrados y saber cuáles están a punto de expirar.

## Dominio

### Entidades principales

- **Ejercicio** *(catálogo global gestionado por admin)* — nombre, descripción, imagen, video, `rest_seconds` default. Tabla `Exercise`.
- **Rutina** — agrupa una lista ordenada de ejercicios que el usuario realiza en una sesión o día. Pertenece a un usuario. Puede asignarse a un `day_of_week` fijo o quedar libre.
- **Registro de serie** (`exercise_logs`) — por cada ejercicio dentro de una sesión: peso, repeticiones, número de serie, `rest_seconds_used`.
- **Sesión de entrenamiento** (`workout_sessions`) — una ejecución concreta de una rutina en una fecha. Contiene las series registradas ese día.
- **Medida corporal** (`body_measurements`) — snapshot en una fecha: peso, %grasa, cintura, pecho, brazo, muslo, notas.
- **Perfil de usuario** (`profiles`) — cuenta con `role` (`user` | `admin`) y `status` (`approved` | `blocked`) + `expires_at`.

### Flujos

**Usuario final:**
1. El admin crea su cuenta desde `/usuarios` (no hay autorregistro público).
2. Crea rutinas combinando ejercicios del catálogo.
3. Cada día: abre una rutina → pulsa Empezar → ejecuta la sesión en `/entrenar/:sessionId` con prefill del último entreno y rest timer automático.
4. Periódicamente: registra sus medidas corporales en `/medidas`.
5. Consulta su historial y progreso *(pantalla `/progreso` pendiente)*.

**Admin:**
1. Añade/edita/elimina ejercicios en el catálogo (`/ejercicios`).
2. Crea usuarios y gestiona sus cuentas (`/usuarios`): renovar, bloquear/desbloquear, cambiar rol.
3. Home le avisa de cuentas próximas a vencer o bloqueadas por vencimiento.

## Estado actual vs. objetivo

### Ya implementado

- **Auth + roles + expiración**: `profiles` (role/status/expires_at), `/login`, guards `requiresAuth` / `requiresAdmin`, `pg_cron` diario que bloquea cuentas vencidas, Edge Function `admin-create-user`.
- **Catálogo de ejercicios** (`/ejercicios`) con imágenes, videos y `rest_seconds` default.
- **Gestión de usuarios** (`/usuarios`): alta, renovar expiración, bloquear, cambiar rol. Avisos in-app en Home.
- **Rutinas** (`/rutinas`): CRUD completo, `routine_exercises` con orden, sets/reps/rest por ejercicio, asignación a día.
- **Sesiones de entrenamiento** (`/entrenar/:sessionId`) Strong-style: prefill del último entreno, rest timer automático con ajustes, add/remove sets y ejercicios sobre la marcha, finalizar/cancelar.
- **Medidas corporales** (`/medidas`): form fijo (6 campos + fecha + notas) y tabla de historial con edición inline.
- **Home** (`/dashboard`) con "Rutina de hoy" y avisos de expiración.
- **RLS** en todas las tablas: user CRUD sobre sus datos + policies `*_admin_select` de solo lectura para admin. Admin solo escribe en `Exercise`, `profiles.role/status/expires_at`, y buckets.
- **PWA** configurada (instalable, offline shell).

### Por implementar

- **`/progreso`**: gráficos de evolución (peso corporal, peso máximo o 1RM estimado por ejercicio). Necesitará Chart.js o similar.
- Opción "guardar como default" en el input de descanso de la sesión, para persistir el cambio en `routine_exercises.rest_seconds`.
- Emails transaccionales de aviso de expiración (requiere Resend/SendGrid; plan free de Supabase no incluye).
- Limpieza: borrar `/tareas` y su composable `useTareas.ts`.
- Generar tipos TypeScript desde Supabase y eliminar `as Tipo[]` casts.

## Decisiones de producto cerradas

- **Autorregistro**: no existe. El admin crea cuentas (Edge Function `admin-create-user` o Supabase Dashboard).
- **Status**: `approved` | `blocked` (sin `pending` — al crearse ya quedan aprobadas). Vencidas pasan a `blocked` vía cron.
- **Expiración**: 30 días por defecto para `user`. Admins no expiran. Renovar suma 30 días desde `max(now, expires_at)` y reabre a `approved`.
- **Rutina por día**: `day_of_week` (0-6) asignable, pero el usuario puede ejecutar cualquier rutina cuando quiera.
- **Rest por defecto**: configurable en el ejercicio del catálogo (`Exercise.rest_seconds`) y a nivel de `routine_exercise`.
- **Regla de rest en sesión**: cambio del rest en un ejercicio se propaga a sets siguientes del mismo ejercicio; al pasar al siguiente ejercicio vuelve al default de su `routine_exercise`.
- **Medidas corporales fijas**: `weight_kg`, `body_fat_pct`, `waist_cm`, `chest_cm`, `arm_cm`, `thigh_cm`. No free-form.
- **Acceso admin a datos de usuarios**: read-only (policies `*_admin_select`). No edita entrenamientos ajenos.
- **UX de sesión**: copiar de cerca la app **Strong** — sets con prefill del último entreno, checkbox que arranca el rest timer automáticamente, rutinas como templates editables en sesión.
