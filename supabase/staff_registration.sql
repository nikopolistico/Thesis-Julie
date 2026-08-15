-- Run this in the Supabase SQL Editor. Lets an admin register a brand new
-- staff account: a login row in `credentials` plus the matching `officers`
-- row (full_name, role, duty_status), created together so the account can
-- sign in and use its dashboard immediately — no orphaned credentials row
-- with no officer profile behind it.
--
-- credentials.user_id and officers.officer_id share the same value
-- throughout this app: the session's id, set at login, is passed straight
-- through as p_officer_id to every nurse/doctor/admin RPC. register_staff
-- reuses the identity generated for the credentials row as the officers
-- row's primary key to keep that assumption true for new accounts too.

create extension if not exists pgcrypto with schema extensions;

create or replace function register_users(
  p_email text,
  p_password text
)
returns table (
  user_id int8,
  email text
)
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  -- Check kung existing na ang email
  if exists (select 1 from credentials a where a.email = p_email) then
    raise exception 'Email already registered';
  end if;

  return query
  insert into credentials as a (email, password)
  values (p_email, crypt(p_password, gen_salt('bf')))
  returning a.user_id, a.email;
end;
$$;

-- Admin-only. Deliberately NOT granted to anon (see grants below) — it's
-- only reachable through register_staff's admin check, so a bare RPC call
-- can't create a login with no officer profile behind it.
create or replace function register_staff(
  p_email text,
  p_password text,
  p_full_name text,
  p_role text,
  p_admin_id int8
)
returns table (
  officer_id int8,
  full_name text,
  email text,
  role text,
  duty_status text
)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_user_id int8;
  v_email text;
begin
  if not exists (select 1 from officers where officers.officer_id = p_admin_id and officers.role = 'admin') then
    raise exception 'Only admins can register staff';
  end if;

  if p_role not in ('doctor', 'nurse', 'admin') then
    raise exception 'role must be ''doctor'', ''nurse'', or ''admin''';
  end if;

  select u.user_id, u.email into v_user_id, v_email
  from register_users(p_email, p_password) u;

  insert into officers (officer_id, full_name, role, duty_status)
  values (v_user_id, p_full_name, p_role, 'off duty');

  return query
  select officers.officer_id, officers.full_name, v_email, officers.role, officers.duty_status
  from officers
  where officers.officer_id = v_user_id;
end;
$$;

revoke all on function register_users(text, text) from public;
revoke all on function register_staff(text, text, text, text, int8) from public;

grant execute on function register_staff(text, text, text, text, int8) to anon;
