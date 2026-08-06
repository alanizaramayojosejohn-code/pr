-- ============================================================================
-- Rol "instructor"
-- ============================================================================
-- Un instructor es un usuario que administra a un subconjunto de clientes:
--   · los da de alta (Edge Function `create-user`),
--   · mantiene una biblioteca de rutinas plantilla,
--   · les envía copias de esas plantillas,
--   · y lee su actividad (entrenos, series, mediciones) en modo consulta.
--
-- El vínculo es `profiles.instructor_id`. Todo el control de acceso cuelga de
-- `is_my_client()`, así que sumar una tabla nueva al alcance del instructor es
-- agregar una política más con esa misma condición.
--
-- Idempotente: se puede correr más de una vez.
-- ============================================================================

-- ── 1. Vínculo alumno → instructor ──────────────────────────────────────────

alter table public.profiles
  add column if not exists instructor_id uuid
    references public.profiles(id) on delete set null;

create index if not exists profiles_instructor_id_idx
  on public.profiles(instructor_id);

comment on column public.profiles.instructor_id is
  'Instructor a cargo de este cliente. Null para admins, instructores y clientes sin instructor.';

-- El rol pasa de {user, admin} a {user, instructor, admin}.
--
-- Se barren todos los CHECK sobre `role` en vez de dropear un nombre fijo: si
-- el constraint viejo se creó sin nombrar, quedaría con un nombre generado y
-- seguiría rechazando 'instructor' aunque agreguemos el nuevo al lado.
do $$
declare
  c record;
begin
  for c in
    select con.conname
    from pg_constraint con
    join pg_class rel on rel.oid = con.conrelid
    join pg_namespace ns on ns.oid = rel.relnamespace
    where ns.nspname = 'public'
      and rel.relname = 'profiles'
      and con.contype = 'c'
      and pg_get_constraintdef(con.oid) ilike '%role%'
  loop
    execute format('alter table public.profiles drop constraint %I', c.conname);
  end loop;
end $$;

alter table public.profiles add constraint profiles_role_check
  check (role in ('user', 'instructor', 'admin'));

-- ── 2. Plantillas de rutina ─────────────────────────────────────────────────
--
-- Una plantilla es una rutina normal del instructor con `is_template = true`:
-- no aparece en su lista de entreno y se edita con la misma pantalla que
-- cualquier otra rutina. Al enviarla se crea una copia independiente en la
-- cuenta del cliente, que recuerda de qué plantilla salió para poder
-- reenviarla actualizada sin duplicarla.

alter table public.routines
  add column if not exists is_template boolean not null default false,
  add column if not exists source_template_id uuid
    references public.routines(id) on delete set null,
  add column if not exists assigned_by uuid
    references public.profiles(id) on delete set null;

create index if not exists routines_user_template_idx
  on public.routines(user_id, is_template);

create index if not exists routines_source_template_idx
  on public.routines(source_template_id);

comment on column public.routines.is_template is
  'true = plantilla del instructor; no se entrena, solo se copia a clientes.';
comment on column public.routines.source_template_id is
  'Plantilla de la que salió esta copia. Null si el cliente la creó él mismo.';
comment on column public.routines.assigned_by is
  'Instructor que envió esta rutina.';

-- ── 3. Helpers de autorización ──────────────────────────────────────────────
--
-- SECURITY DEFINER a propósito: se usan dentro de políticas sobre `profiles`
-- y consultar esa tabla con RLS activa desde su propia política sería
-- recursivo.

create or replace function public.is_instructor()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.role = 'instructor'
      and p.status = 'approved'
  );
$$;

create or replace function public.is_my_client(p_client_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_instructor()
     and exists (
       select 1 from public.profiles c
       where c.id = p_client_id
         and c.instructor_id = auth.uid()
     );
$$;

comment on function public.is_instructor() is
  'true si quien llama es un instructor aprobado.';
comment on function public.is_my_client(uuid) is
  'true si quien llama es instructor aprobado y p_client_id es alumno suyo.';

revoke execute on function public.is_instructor() from public;
revoke execute on function public.is_my_client(uuid) from public;
grant execute on function public.is_instructor() to authenticated;
grant execute on function public.is_my_client(uuid) to authenticated;

-- ── 4. Enviar plantilla a un alumno ─────────────────────────────────────────
--
-- Copiar rutina + ejercicios desde el cliente serían N inserts sin
-- transacción: si falla el tercero el alumno se queda con media rutina. Acá
-- va todo en una sola llamada atómica, con la autorización comprobada dentro.
--
-- Reenviar la misma plantilla no duplica: reescribe la copia que ya tiene.

create or replace function public.assign_routine_template(
  p_template_id uuid,
  p_client_id   uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_instructor uuid := auth.uid();
  v_template   public.routines%rowtype;
  v_copy_id    uuid;
begin
  if v_instructor is null then
    raise exception 'No autenticado' using errcode = '28000';
  end if;

  select * into v_template from public.routines where id = p_template_id;
  if not found then
    raise exception 'La plantilla no existe' using errcode = 'P0002';
  end if;

  if v_template.user_id <> v_instructor then
    raise exception 'Esa plantilla no te pertenece' using errcode = '42501';
  end if;

  if not public.is_my_client(p_client_id) then
    raise exception 'Ese alumno no está a tu cargo' using errcode = '42501';
  end if;

  select id into v_copy_id
  from public.routines
  where user_id = p_client_id
    and source_template_id = p_template_id
  limit 1;

  if v_copy_id is null then
    insert into public.routines (
      user_id, name, notes, days_of_week,
      is_template, source_template_id, assigned_by
    )
    values (
      p_client_id, v_template.name, v_template.notes, v_template.days_of_week,
      false, p_template_id, v_instructor
    )
    returning id into v_copy_id;
  else
    update public.routines
       set name         = v_template.name,
           notes        = v_template.notes,
           days_of_week = v_template.days_of_week,
           assigned_by  = v_instructor
     where id = v_copy_id;

    delete from public.routine_exercises where routine_id = v_copy_id;
  end if;

  insert into public.routine_exercises (
    routine_id, exercise_id, position,
    target_sets, target_reps, rest_seconds, default_weight
  )
  select v_copy_id, re.exercise_id, re.position,
         re.target_sets, re.target_reps, re.rest_seconds, re.default_weight
  from public.routine_exercises re
  where re.routine_id = p_template_id;

  return v_copy_id;
end;
$$;

comment on function public.assign_routine_template(uuid, uuid) is
  'Copia una plantilla del instructor a la cuenta de un alumno suyo. Reenviar sobrescribe la copia anterior en vez de duplicarla. Devuelve el id de la copia.';

revoke execute on function public.assign_routine_template(uuid, uuid) from public;
grant execute on function public.assign_routine_template(uuid, uuid) to authenticated;

-- ── 5. Políticas RLS ────────────────────────────────────────────────────────
--
-- Todas se suman a las que ya existen (RLS combina políticas permisivas con
-- OR), así que el dueño de cada fila y el admin conservan lo que ya tenían.

-- profiles: el instructor ve la ficha de sus alumnos.
drop policy if exists instructor_select_clients on public.profiles;
create policy instructor_select_clients on public.profiles
  for select to authenticated
  using (instructor_id = auth.uid());

-- routines: control total sobre las rutinas de sus alumnos (necesario para
-- enviar, corregir y retirar rutinas).
drop policy if exists instructor_manage_client_routines on public.routines;
create policy instructor_manage_client_routines on public.routines
  for all to authenticated
  using (public.is_my_client(user_id))
  with check (public.is_my_client(user_id));

drop policy if exists instructor_manage_client_routine_exercises on public.routine_exercises;
create policy instructor_manage_client_routine_exercises on public.routine_exercises
  for all to authenticated
  using (
    exists (
      select 1 from public.routines r
      where r.id = routine_id and public.is_my_client(r.user_id)
    )
  )
  with check (
    exists (
      select 1 from public.routines r
      where r.id = routine_id and public.is_my_client(r.user_id)
    )
  );

-- Actividad del alumno: solo lectura.
drop policy if exists instructor_select_client_sessions on public.workout_sessions;
create policy instructor_select_client_sessions on public.workout_sessions
  for select to authenticated
  using (public.is_my_client(user_id));

drop policy if exists instructor_select_client_logs on public.exercise_logs;
create policy instructor_select_client_logs on public.exercise_logs
  for select to authenticated
  using (
    exists (
      select 1 from public.workout_sessions s
      where s.id = session_id and public.is_my_client(s.user_id)
    )
  );

drop policy if exists instructor_select_client_measurements on public.body_measurements;
create policy instructor_select_client_measurements on public.body_measurements
  for select to authenticated
  using (public.is_my_client(user_id));
