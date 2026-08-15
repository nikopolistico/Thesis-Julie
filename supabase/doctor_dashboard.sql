-- SQLBook: Code
-- Run this in the Supabase SQL Editor. Adds the RPC functions the Doctor
-- Dashboard needs: seeing every discharge request nurses have filed
-- (hospital-wide, not scoped to one officer), approving/rejecting them, and
-- viewing patient records read-only.
--
-- Same trust model as nurse_dashboard.sql: RLS is on with no policies, so
-- the only way in is through these SECURITY DEFINER functions. Ownership
-- here is enforced by checking the caller's role in `officers`, not by
-- auth.uid() — this app has no real Supabase Auth session.

-- ── discharge requests: doctor-wide view + approval ─────────────────────

-- Tracks which doctor approved a request, so admin can display "requested
-- by <nurse>, approved by <doctor>" without guessing from status alone.
alter table public.discharge_requests add column if not exists approved_by int8 references public.officers (officer_id);

drop function if exists list_all_discharge_requests();
drop function if exists update_discharge_request_status_by_doctor(int8, text, int8);

create or replace function list_all_discharge_requests()
returns table (
  request_id int8,
  patient_id int8,
  patient_name text,
  requested_by int8,
  requested_by_name text,
  approved_by int8,
  approved_by_name text,
  status text,
  billing_verified bool,
  discharge_date timestamptz,
  "timestamp" timestamptz
)
language plpgsql
security definer
as $$
begin
  return query
  select dr.request_id, dr.patient_id, p.full_name, dr.requested_by, o.full_name,
    dr.approved_by, ao.full_name,
    dr.status, dr.billing_verified, p.discharge_date, dr."timestamp"
  from discharge_requests dr
  join patients p on p.id = dr.patient_id
  join officers o on o.officer_id = dr.requested_by
  left join officers ao on ao.officer_id = dr.approved_by
  order by dr."timestamp" desc;
end;
$$;

-- Any officer with role = 'doctor' may approve/reject any discharge
-- request, regardless of which nurse filed it (unlike
-- update_discharge_request_status, which is scoped to the filing nurse).
create or replace function update_discharge_request_status_by_doctor(
  p_request_id int8,
  p_status text,
  p_doctor_id int8
)
returns table (
  request_id int8,
  patient_id int8,
  patient_name text,
  requested_by int8,
  requested_by_name text,
  approved_by int8,
  approved_by_name text,
  status text,
  billing_verified bool,
  discharge_date timestamptz,
  "timestamp" timestamptz
)
language plpgsql
security definer
as $$
declare
  v_patient_id int8;
begin
  if not exists (select 1 from officers where officers.officer_id = p_doctor_id and officers.role = 'doctor') then
    raise exception 'Only doctors can approve or reject discharge requests';
  end if;

  select discharge_requests.patient_id into v_patient_id
  from discharge_requests
  where discharge_requests.request_id = p_request_id;

  update discharge_requests
  set status = p_status,
      approved_by = case when p_status = 'Approved' then p_doctor_id else discharge_requests.approved_by end
  where discharge_requests.request_id = p_request_id;

  if p_status = 'Approved' then
    update patients
    set discharge_date = now()
    where patients.id = v_patient_id;
  end if;

  return query
  select dr.request_id, dr.patient_id, p.full_name, dr.requested_by, o.full_name,
    dr.approved_by, ao.full_name,
    dr.status, dr.billing_verified, p.discharge_date, dr."timestamp"
  from discharge_requests dr
  join patients p on p.id = dr.patient_id
  join officers o on o.officer_id = dr.requested_by
  left join officers ao on ao.officer_id = dr.approved_by
  where dr.request_id = p_request_id;
end;
$$;

-- ── patients: doctor-wide, read-only ─────────────────────────────────────

create or replace function list_all_patients()
returns table (
  id int8,
  full_name text,
  admission_date date,
  philhealth_no text,
  officer_id int8,
  age int8,
  date_of_birth date,
  contact_number text,
  emergency_contact text,
  room_number int8,
  discharge_date timestamptz
)
language plpgsql
security definer
as $$
begin
  return query
  select
    patients.id, patients.full_name, patients.admission_date, patients.philhealth_no, patients.officer_id,
    patients.age, patients.date_of_birth, patients.contact_number, patients.emergency_contact, patients.room_number,
    patients.discharge_date
  from patients
  order by patients.admission_date desc;
end;
$$;

-- ── grants ─────────────────────────────────────────────────────────────

revoke all on function list_all_discharge_requests() from public;
revoke all on function update_discharge_request_status_by_doctor(int8, text, int8) from public;
revoke all on function list_all_patients() from public;

grant execute on function list_all_discharge_requests() to anon;
grant execute on function update_discharge_request_status_by_doctor(int8, text, int8) to anon;
grant execute on function list_all_patients() to anon;
