-- Run this in the Supabase SQL Editor. Adds a single shared RPC every
-- dashboard (nurse/doctor/admin) calls after login to resolve the
-- session's officer_id into a display name, instead of each page
-- hardcoding a placeholder name like "Nurse Station 2" or "Dr. On Call".
--
-- officers.full_name already has what we need — no join against
-- credentials is required just to look up a display name.

create or replace function get_officer_name(p_officer_id int8)
returns text
language plpgsql
security definer
as $$
declare
  v_name text;
begin
  select officers.full_name into v_name
  from officers
  where officers.officer_id = p_officer_id;

  return v_name;
end;
$$;

revoke all on function get_officer_name(int8) from public;
grant execute on function get_officer_name(int8) to anon;
