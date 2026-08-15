-- Run this once in the Supabase SQL Editor (Project > SQL Editor > New query).
-- Sets up the `administrator` table and the only two ways it can be
-- read or written: register_administrator() and login_administrator().
-- The raw password is never stored and the password hash never leaves
-- the database — the client only ever gets back { id, email }.

create extension if not exists pgcrypto with schema extensions;

create table if not exists public.administrator (
  id uuid primary key default gen_random_uuid(),
  email text unique not null,
  password text not null, -- bcrypt hash only, never plaintext
  created_at timestamptz not null default now()
);

alter table public.administrator enable row level security;
-- No RLS policies are added on purpose: with none defined, the anon/
-- authenticated roles have zero direct access to this table. The only
-- way in is through the SECURITY DEFINER functions below.

create or replace function public.register_administrator(p_email text, p_password text)
returns table (id uuid, email text)
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  return query
  insert into public.administrator (email, password)
  values (lower(p_email), extensions.crypt(p_password, extensions.gen_salt('bf')))
  returning administrator.id, administrator.email;
end;
$$;

create or replace function public.login_administrator(p_email text, p_password text)
returns table (id uuid, email text)
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  return query
  select administrator.id, administrator.email
  from public.administrator
  where administrator.email = lower(p_email)
    and administrator.password = extensions.crypt(p_password, administrator.password);
end;
$$;

revoke all on function public.register_administrator(text, text) from public;
revoke all on function public.login_administrator(text, text) from public;
grant execute on function public.register_administrator(text, text) to anon;
grant execute on function public.login_administrator(text, text) to anon;
