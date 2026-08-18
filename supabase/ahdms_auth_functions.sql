-- ============================================
-- AHDMS Auth Functions
-- Run after: ahdms_schema.sql
-- ============================================
-- Login/registration against `credentials` + `officers`. RLS on both is
-- enabled with no policies, so the only way in for the anon role is
-- through these SECURITY DEFINER functions. There is no real Supabase
-- Auth session — the client holds officer_id/role/full_name in its own
-- cookie after login (see app/composables/useAdminSession.ts) and passes
-- officer_id back on every RPC call that needs to know who's asking.

-- ── login ─────────────────────────────────────────────────────────────

create or replace function login_officer(p_email text, p_password text)
returns table (
    officer_id   bigint,
    full_name    text,
    email        text,
    role         text,
    duty_status  text
)
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
    return query
    select o.officer_id, o.full_name, c.email, o.role, o.duty_status
    from credentials c
    join officers o on o.officer_id = c.officer_id
    where c.email = lower(p_email)
      and c.password = crypt(p_password, c.password);
end;
$$;

-- ── register ──────────────────────────────────────────────────────────
-- Creates the officers row and its matching credentials row together, so
-- no login can exist without an officer profile behind it.
--
-- Bootstrap rule: when the officers table is completely empty (fresh
-- database, no admin exists yet), the check on p_admin_id is skipped so
-- the very first account can be created. After that, every call must
-- pass a p_admin_id belonging to an existing admin.

create or replace function register_officer(
    p_email      text,
    p_password   text,
    p_full_name  text,
    p_role       text,
    p_admin_id   bigint default null
)
returns table (
    officer_id   bigint,
    full_name    text,
    email        text,
    role         text,
    duty_status  text
)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
    v_officer_id   bigint;
    v_is_bootstrap boolean;
begin
    if p_role not in ('nurse', 'doctor', 'billing', 'admin') then
        raise exception 'Invalid role: %', p_role;
    end if;

    select not exists (select 1 from officers) into v_is_bootstrap;

    if not v_is_bootstrap and not exists (
        select 1 from officers where officers.officer_id = p_admin_id and officers.role = 'admin'
    ) then
        raise exception 'Only admins can register staff';
    end if;

    if exists (select 1 from credentials where credentials.email = lower(p_email)) then
        raise exception 'Email already registered';
    end if;

    insert into officers (full_name, role)
    values (p_full_name, p_role)
    returning officers.officer_id into v_officer_id;

    insert into credentials (officer_id, email, password)
    values (v_officer_id, lower(p_email), crypt(p_password, gen_salt('bf')));

    return query
    select o.officer_id, o.full_name, c.email, o.role, o.duty_status
    from officers o
    join credentials c on c.officer_id = o.officer_id
    where o.officer_id = v_officer_id;
end;
$$;

-- ── grants ────────────────────────────────────────────────────────────

revoke all on function login_officer(text, text) from public;
revoke all on function register_officer(text, text, text, text, bigint) from public;

grant execute on function login_officer(text, text) to anon;
grant execute on function register_officer(text, text, text, text, bigint) to anon;
