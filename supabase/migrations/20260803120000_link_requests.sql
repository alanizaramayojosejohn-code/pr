-- ============================================================================
-- Vinculación instructor ↔ alumno por solicitud
-- ============================================================================
-- Reemplaza el alta manual: el instructor ya no crea cuentas ni reparte
-- contraseñas. Ahora el alumno se registra solo y las dos partes se vinculan
-- pidiéndoselo mutuamente:
--
--   · El instructor busca al alumno por email y le manda solicitud.
--   · El alumno busca a su instructor por email y le manda solicitud.
--   · En ambos casos acepta **el que no la pidió**.
--
-- Si los dos se mandan solicitud, la segunda se auto-acepta: pedir es aceptar.
--
-- Un alumno sin instructor usa la app entera; el vínculo es opcional y suma
-- (plantillas y seguimiento), no habilita.
--
-- Idempotente: se puede correr más de una vez.
-- ============================================================================

-- ── 1. Perfil automático al registrarse ─────────────────────────────────────
--
-- Antes toda cuenta nacía desde la Edge Function, que insertaba el perfil a
-- mano. Con auto-registro (email/contraseña y Google) hace falta que la fila de
-- `profiles` aparezca sola, o el usuario entra a una app sin perfil.
--
-- `on conflict do nothing` a propósito: si el proyecto ya tuviera un trigger
-- equivalente, los dos conviven sin pisarse.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, role, status)
  values (new.id, lower(coalesce(new.email, '')), 'user', 'approved')
  on conflict (id) do nothing;
  return new;
end;
$$;

comment on function public.handle_new_user() is
  'Crea el perfil de toda cuenta nueva. Rol user, sin vencimiento: el acceso ya no depende del instructor.';

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Cuentas que ya existen en auth pero se quedaron sin perfil (p. ej. altas por
-- Google previas a este trigger).
insert into public.profiles (id, email, role, status)
select u.id, lower(u.email), 'user', 'approved'
from auth.users u
left join public.profiles p on p.id = u.id
where p.id is null
  and u.email is not null
on conflict (id) do nothing;

-- ── 2. Tabla de solicitudes ─────────────────────────────────────────────────

create table if not exists public.instructor_links (
  id            uuid primary key default gen_random_uuid(),
  instructor_id uuid not null references public.profiles(id) on delete cascade,
  client_id     uuid not null references public.profiles(id) on delete cascade,
  -- Quién la inició. Determina quién puede aceptarla: el otro.
  requested_by  uuid not null references public.profiles(id) on delete cascade,
  status        text not null default 'pending'
                check (status in ('pending', 'accepted', 'rejected', 'cancelled')),
  created_at    timestamptz not null default now(),
  responded_at  timestamptz,
  constraint instructor_links_not_self check (instructor_id <> client_id)
);

comment on table public.instructor_links is
  'Solicitudes de vínculo instructor↔alumno. El vínculo efectivo vive en profiles.instructor_id; esta tabla es el historial y la bandeja de pendientes.';

-- Un solo vínculo vivo por par. Parcial y no un UNIQUE normal: tras un rechazo
-- se tiene que poder volver a intentar.
create unique index if not exists instructor_links_active_pair_idx
  on public.instructor_links (instructor_id, client_id)
  where status in ('pending', 'accepted');

-- Un alumno tiene un instructor y no más: `profiles.instructor_id` es una sola
-- columna, así que dos vínculos aceptados serían un estado imposible.
create unique index if not exists instructor_links_one_accepted_idx
  on public.instructor_links (client_id)
  where status = 'accepted';

create index if not exists instructor_links_client_pending_idx
  on public.instructor_links (client_id) where status = 'pending';

create index if not exists instructor_links_instructor_pending_idx
  on public.instructor_links (instructor_id) where status = 'pending';

alter table public.instructor_links enable row level security;

-- Solo lectura, y solo de lo propio. No hay políticas de insert/update/delete a
-- propósito: todo cambio pasa por las funciones de abajo, que son las que
-- validan roles y dirección. Sin ellas nadie puede escribir esta tabla.
drop policy if exists links_select_own on public.instructor_links;
create policy links_select_own on public.instructor_links
  for select to authenticated
  using (instructor_id = auth.uid() or client_id = auth.uid());

-- ── 3. El alumno ve la ficha de su instructor ───────────────────────────────
--
-- La política existente cubre el sentido instructor → alumno. Falta el inverso,
-- o el alumno no puede ni mostrar el email de quien lo entrena.
--
-- SECURITY DEFINER porque consultar `profiles` desde una política sobre
-- `profiles` sería recursivo.

create or replace function public.my_instructor_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select instructor_id from public.profiles where id = auth.uid();
$$;

revoke execute on function public.my_instructor_id() from public;
grant execute on function public.my_instructor_id() to authenticated;

drop policy if exists client_select_instructor on public.profiles;
create policy client_select_instructor on public.profiles
  for select to authenticated
  using (id = public.my_instructor_id());

-- ── 4. Buscar a la contraparte por email ────────────────────────────────────
--
-- Coincidencia exacta, nunca parcial: una búsqueda por prefijo permitiría
-- barrer la base de emails. Aun así confirma si un email existe, que es
-- inherente a "buscalo por email" y el precio de que el flujo sea usable.
--
-- El rol buscado se deriva del rol de quien busca: el instructor solo encuentra
-- alumnos y el alumno solo encuentra instructores.

create or replace function public.find_link_candidate(p_email text)
returns table (id uuid, email text, role text)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_role text;
  v_want text;
begin
  select p.role into v_role from public.profiles p where p.id = auth.uid();
  if v_role is null then
    raise exception 'No autenticado' using errcode = '28000';
  end if;

  if v_role = 'instructor' then
    v_want := 'user';
  elsif v_role = 'user' then
    v_want := 'instructor';
  else
    raise exception 'Tu cuenta no se vincula con otras' using errcode = '42501';
  end if;

  return query
    select p.id, p.email, p.role
    from public.profiles p
    where p.email = lower(trim(p_email))
      and p.role = v_want
      and p.id <> auth.uid()
    limit 1;
end;
$$;

comment on function public.find_link_candidate(text) is
  'Busca por email exacto a la contraparte que corresponde al rol de quien llama. Devuelve 0 o 1 fila.';

revoke execute on function public.find_link_candidate(text) from public;
grant execute on function public.find_link_candidate(text) to authenticated;

-- ── 5. Mandar solicitud ─────────────────────────────────────────────────────

create or replace function public.send_link_request(p_target_email text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me          public.profiles%rowtype;
  v_target      public.profiles%rowtype;
  v_instructor  uuid;
  v_client      uuid;
  v_existing    public.instructor_links%rowtype;
  v_id          uuid;
begin
  select * into v_me from public.profiles where id = auth.uid();
  if v_me.id is null then
    raise exception 'No autenticado' using errcode = '28000';
  end if;
  if v_me.status <> 'approved' then
    raise exception 'Tu cuenta está bloqueada' using errcode = '42501';
  end if;

  select * into v_target
  from public.profiles
  where email = lower(trim(p_target_email))
    and id <> v_me.id;

  if v_target.id is null then
    raise exception 'No hay ninguna cuenta con ese email' using errcode = 'P0002';
  end if;

  -- La dirección sale de los roles, nunca de un parámetro: así ningún cliente
  -- puede declararse instructor de otro mandando el body a mano.
  if v_me.role = 'instructor' and v_target.role = 'user' then
    v_instructor := v_me.id;
    v_client     := v_target.id;
  elsif v_me.role = 'user' and v_target.role = 'instructor' then
    v_instructor := v_target.id;
    v_client     := v_me.id;
  else
    raise exception 'Solo se vincula un instructor con un alumno'
      using errcode = '42501';
  end if;

  if v_target.status <> 'approved' then
    raise exception 'Esa cuenta está bloqueada' using errcode = '42501';
  end if;

  -- El alumno ya tiene instructor: hay que soltar el vínculo actual primero.
  if exists (
    select 1 from public.profiles
    where id = v_client and instructor_id is not null
  ) then
    if v_me.role = 'user' then
      raise exception 'Ya tenés instructor. Terminá ese vínculo antes de pedir otro'
        using errcode = '42501';
    else
      raise exception 'Ese alumno ya tiene instructor' using errcode = '42501';
    end if;
  end if;

  select * into v_existing
  from public.instructor_links
  where instructor_id = v_instructor
    and client_id = v_client
    and status in ('pending', 'accepted');

  if v_existing.id is not null then
    -- Pedir lo que ya te pidieron es aceptarlo: evita que dos personas se
    -- queden esperando cada una a que la otra apriete el botón.
    if v_existing.status = 'pending' and v_existing.requested_by <> v_me.id then
      perform public.respond_link_request(v_existing.id, true);
      return v_existing.id;
    end if;
    return v_existing.id;
  end if;

  insert into public.instructor_links (instructor_id, client_id, requested_by)
  values (v_instructor, v_client, v_me.id)
  returning id into v_id;

  return v_id;
end;
$$;

comment on function public.send_link_request(text) is
  'Manda solicitud de vínculo a la cuenta del email dado. La dirección se deduce de los roles. Si la contraparte ya te había pedido lo mismo, se acepta en el acto.';

revoke execute on function public.send_link_request(text) from public;
grant execute on function public.send_link_request(text) to authenticated;

-- ── 6. Aceptar / rechazar ───────────────────────────────────────────────────

create or replace function public.respond_link_request(
  p_link_id uuid,
  p_accept  boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_link public.instructor_links%rowtype;
  v_me   uuid := auth.uid();
begin
  if v_me is null then
    raise exception 'No autenticado' using errcode = '28000';
  end if;

  select * into v_link from public.instructor_links where id = p_link_id;
  if v_link.id is null then
    raise exception 'La solicitud no existe' using errcode = 'P0002';
  end if;
  if v_link.status <> 'pending' then
    raise exception 'Esa solicitud ya fue respondida' using errcode = '42501';
  end if;

  -- Responde el que no pidió. El que pidió cancela, no acepta.
  if v_me not in (v_link.instructor_id, v_link.client_id)
     or v_me = v_link.requested_by then
    raise exception 'No te toca responder esa solicitud' using errcode = '42501';
  end if;

  if not p_accept then
    update public.instructor_links
       set status = 'rejected', responded_at = now()
     where id = p_link_id;
    return;
  end if;

  if exists (
    select 1 from public.profiles
    where id = v_link.client_id and instructor_id is not null
  ) then
    raise exception 'Ese alumno ya tiene instructor' using errcode = '42501';
  end if;

  update public.instructor_links
     set status = 'accepted', responded_at = now()
   where id = p_link_id;

  update public.profiles
     set instructor_id = v_link.instructor_id
   where id = v_link.client_id;
end;
$$;

comment on function public.respond_link_request(uuid, boolean) is
  'Acepta o rechaza una solicitud pendiente. Solo puede llamarla la parte que no la originó. Aceptar escribe profiles.instructor_id.';

revoke execute on function public.respond_link_request(uuid, boolean) from public;
grant execute on function public.respond_link_request(uuid, boolean) to authenticated;

-- ── 7. Cancelar una solicitud propia ────────────────────────────────────────

create or replace function public.cancel_link_request(p_link_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_link public.instructor_links%rowtype;
begin
  select * into v_link from public.instructor_links where id = p_link_id;
  if v_link.id is null then
    raise exception 'La solicitud no existe' using errcode = 'P0002';
  end if;
  if v_link.requested_by <> auth.uid() then
    raise exception 'Esa solicitud no es tuya' using errcode = '42501';
  end if;
  if v_link.status <> 'pending' then
    raise exception 'Esa solicitud ya fue respondida' using errcode = '42501';
  end if;

  update public.instructor_links
     set status = 'cancelled', responded_at = now()
   where id = p_link_id;
end;
$$;

revoke execute on function public.cancel_link_request(uuid) from public;
grant execute on function public.cancel_link_request(uuid) to authenticated;

-- ── 8. Terminar un vínculo aceptado ─────────────────────────────────────────
--
-- Lo puede cortar cualquiera de los dos, sin permiso del otro: el alumno no
-- queda preso de un instructor ni el instructor obligado a llevar un alumno.
--
-- Las rutinas que el instructor le mandó se quedan con el alumno: son suyas y
-- borrarlas al desvincular sería destruir su historial.

create or replace function public.end_instructor_link(p_client_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me         uuid := auth.uid();
  v_instructor uuid;
begin
  select instructor_id into v_instructor
  from public.profiles where id = p_client_id;

  if v_instructor is null then
    raise exception 'Ese alumno no tiene instructor' using errcode = 'P0002';
  end if;
  if v_me <> p_client_id and v_me <> v_instructor then
    raise exception 'No sos parte de ese vínculo' using errcode = '42501';
  end if;

  update public.profiles set instructor_id = null where id = p_client_id;

  update public.instructor_links
     set status = 'cancelled', responded_at = now()
   where client_id = p_client_id
     and instructor_id = v_instructor
     and status = 'accepted';
end;
$$;

comment on function public.end_instructor_link(uuid) is
  'Corta el vínculo. La puede llamar el alumno o su instructor. Las rutinas ya enviadas se quedan con el alumno.';

revoke execute on function public.end_instructor_link(uuid) from public;
grant execute on function public.end_instructor_link(uuid) to authenticated;

-- ── 9. Bandeja: mis solicitudes con el email de la contraparte ──────────────
--
-- Va por función y no por select + join porque el email del otro no es visible
-- bajo RLS mientras la solicitud está pendiente: todavía no son nada el uno del
-- otro. Acá se devuelve solo el email de quien ya te mandó (o a quien mandaste)
-- una solicitud, que es exactamente lo que la pantalla necesita mostrar.

create or replace function public.my_link_requests()
returns table (
  id                uuid,
  status            text,
  created_at        timestamptz,
  counterpart_id    uuid,
  counterpart_email text,
  counterpart_role  text,
  i_requested       boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select
    l.id,
    l.status,
    l.created_at,
    other.id,
    other.email,
    other.role,
    l.requested_by = auth.uid()
  from public.instructor_links l
  join public.profiles other
    on other.id = case
         when l.instructor_id = auth.uid() then l.client_id
         else l.instructor_id
       end
  where l.status = 'pending'
    and auth.uid() in (l.instructor_id, l.client_id)
  order by l.created_at desc;
$$;

comment on function public.my_link_requests() is
  'Solicitudes pendientes en las que participo, con el email de la contraparte. i_requested distingue las que mandé de las que tengo que responder.';

revoke execute on function public.my_link_requests() from public;
grant execute on function public.my_link_requests() to authenticated;
