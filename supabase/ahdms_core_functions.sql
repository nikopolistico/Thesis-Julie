-- ============================================
-- AHDMS Core Functionality RPC Functions
-- Run after: ahdms_schema.sql and ahdms_auth_functions.sql
-- ============================================

-- ============================================
-- HELPER: map task_type -> required officer role
-- ============================================
create or replace function get_required_role(p_task_type text)
returns text
language sql
immutable
as $$
    select case p_task_type
        when 'nurse_clearance'          then 'nurse'
        when 'doctor_signoff'           then 'doctor'
        when 'billing_clearance'        then 'billing'
        when 'philhealth_documentation' then 'billing'
        else null
    end;
$$;

-- ============================================
-- HELPER: auto-assign least-busy, on-duty officer matching a role
-- Simple rule (per thesis scope): on-duty + matching role only,
-- tie-broken by whoever currently has the fewest open tasks.
-- ============================================
create or replace function auto_assign_officer(p_role text)
returns bigint
language sql
stable
as $$
    select o.officer_id
    from officers o
    where o.role = p_role
      and o.duty_status = 'on_duty'
    order by (
        select count(*) from tasks t
        where t.assigned_to = o.officer_id and t.status <> 'done'
    ) asc
    limit 1;
$$;

-- ============================================
-- OFFICERS: toggle duty status (admin action)
-- ============================================
create or replace function set_duty_status(p_officer_id bigint, p_duty_status text)
returns officers
language plpgsql
security definer
as $$
declare
    v_officer officers;
begin
    if p_duty_status not in ('on_duty', 'off_duty') then
        raise exception 'Invalid duty_status: %', p_duty_status;
    end if;

    update officers
    set duty_status = p_duty_status
    where officer_id = p_officer_id
    returning * into v_officer;

    if v_officer is null then
        raise exception 'Officer not found';
    end if;

    return v_officer;
end;
$$;

-- ============================================
-- PATIENTS: register new patient
-- ============================================
create or replace function register_patient(
    p_full_name             text,
    p_date_of_birth         date,
    p_age                   smallint,
    p_contact_number        text,
    p_emergency_contact     text,
    p_room_number           smallint,
    p_philhealth_no         text,
    p_attending_officer_id  bigint
)
returns patients
language plpgsql
security definer
as $$
declare
    v_patient patients;
begin
    insert into patients (
        full_name, date_of_birth, age, contact_number,
        emergency_contact, room_number, philhealth_no, attending_officer_id
    )
    values (
        p_full_name, p_date_of_birth, p_age, p_contact_number,
        p_emergency_contact, p_room_number, p_philhealth_no, p_attending_officer_id
    )
    returning * into v_patient;

    return v_patient;
end;
$$;

-- ============================================
-- PATIENTS: update patient info
-- ============================================
create or replace function update_patient_info(
    p_patient_id            bigint,
    p_contact_number        text default null,
    p_emergency_contact     text default null,
    p_room_number           smallint default null,
    p_attending_officer_id  bigint default null
)
returns patients
language plpgsql
security definer
as $$
declare
    v_patient patients;
begin
    update patients
    set contact_number       = coalesce(p_contact_number, contact_number),
        emergency_contact    = coalesce(p_emergency_contact, emergency_contact),
        room_number          = coalesce(p_room_number, room_number),
        attending_officer_id = coalesce(p_attending_officer_id, attending_officer_id)
    where patient_id = p_patient_id
    returning * into v_patient;

    if v_patient is null then
        raise exception 'Patient not found';
    end if;

    return v_patient;
end;
$$;

-- ============================================
-- DISCHARGE REQUESTS: create + auto-generate & auto-assign tasks
-- ============================================
create or replace function create_discharge_request(
    p_patient_id    bigint,
    p_requested_by  bigint
)
returns bigint
language plpgsql
security definer
as $$
declare
    v_request_id bigint;
    v_task_type  text;
    v_role       text;
    v_officer_id bigint;
begin
    insert into discharge_requests (patient_id, requested_by)
    values (p_patient_id, p_requested_by)
    returning request_id into v_request_id;

    foreach v_task_type in array
        array['nurse_clearance', 'doctor_signoff', 'billing_clearance', 'philhealth_documentation']
    loop
        v_role := get_required_role(v_task_type);
        v_officer_id := auto_assign_officer(v_role);

        insert into tasks (discharge_request_id, task_type, assigned_to, status)
        values (
            v_request_id,
            v_task_type,
            v_officer_id,
            case when v_officer_id is null then 'pending' else 'pending' end
        );
    end loop;

    return v_request_id;
end;
$$;

-- ============================================
-- TASKS: mark complete
-- ============================================
create or replace function complete_task(p_task_id bigint)
returns tasks
language plpgsql
security definer
as $$
declare
    v_task tasks;
begin
    update tasks
    set status = 'done', completed_at = now()
    where task_id = p_task_id
    returning * into v_task;

    if v_task is null then
        raise exception 'Task not found';
    end if;

    return v_task;
end;
$$;

-- ============================================
-- TASKS: list tasks assigned to an officer
-- ============================================
create or replace function list_tasks_for_officer(p_officer_id bigint)
returns setof tasks
language sql
stable
security definer
as $$
    select * from tasks
    where assigned_to = p_officer_id
    order by created_at asc;
$$;

-- ============================================
-- BILLING: create billing record for a discharge request
-- ============================================
create or replace function create_billing_record(
    p_discharge_request_id  bigint,
    p_patient_id            bigint,
    p_total_amount          numeric,
    p_philhealth_deduction  numeric
)
returns billing
language plpgsql
security definer
as $$
declare
    v_billing billing;
    v_officer_id bigint;
begin
    v_officer_id := auto_assign_officer('billing');

    insert into billing (
        discharge_request_id, patient_id, handled_by,
        total_amount, philhealth_deduction
    )
    values (
        p_discharge_request_id, p_patient_id, v_officer_id,
        p_total_amount, p_philhealth_deduction
    )
    returning * into v_billing;

    return v_billing;
end;
$$;

-- ============================================
-- BILLING: verify/clear billing -> also flips discharge_requests.billing_verified
-- ============================================
create or replace function verify_billing(p_billing_id bigint)
returns billing
language plpgsql
security definer
as $$
declare
    v_billing billing;
begin
    update billing
    set status = 'cleared'
    where billing_id = p_billing_id
    returning * into v_billing;

    if v_billing is null then
        raise exception 'Billing record not found';
    end if;

    update discharge_requests
    set billing_verified = true
    where request_id = v_billing.discharge_request_id;

    return v_billing;
end;
$$;

-- ============================================
-- DISCHARGE REQUESTS: approve (only if all tasks done + billing verified)
-- ============================================
create or replace function approve_discharge_request(
    p_request_id   bigint,
    p_approved_by  bigint
)
returns discharge_requests
language plpgsql
security definer
as $$
declare
    v_request discharge_requests;
    v_pending_tasks int;
begin
    select count(*) into v_pending_tasks
    from tasks
    where discharge_request_id = p_request_id and status <> 'done';

    if v_pending_tasks > 0 then
        raise exception 'Cannot approve: % task(s) still pending', v_pending_tasks;
    end if;

    select * into v_request from discharge_requests where request_id = p_request_id;

    if not v_request.billing_verified then
        raise exception 'Cannot approve: billing not yet verified';
    end if;

    update discharge_requests
    set status = 'approved', approved_by = p_approved_by
    where request_id = p_request_id
    returning * into v_request;

    return v_request;
end;
$$;

-- ============================================
-- DISCHARGE REQUESTS: finalize/complete (patient officially discharged)
-- ============================================
create or replace function complete_discharge_request(p_request_id bigint)
returns discharge_requests
language plpgsql
security definer
as $$
declare
    v_request discharge_requests;
begin
    update discharge_requests
    set status = 'completed'
    where request_id = p_request_id and status = 'approved'
    returning * into v_request;

    if v_request is null then
        raise exception 'Request must be approved before it can be completed';
    end if;

    update patients
    set discharge_date = now()
    where patient_id = v_request.patient_id;

    return v_request;
end;
$$;

-- ============================================
-- DISCHARGE REQUESTS: get full status (request + its tasks + billing)
-- ============================================
create or replace function get_discharge_request_details(p_request_id bigint)
returns table (
    request_id         bigint,
    status              text,
    billing_verified    boolean,
    patient_full_name   text,
    tasks_json           jsonb,
    billing_json          jsonb
)
language sql
stable
security definer
as $$
    select
        dr.request_id,
        dr.status,
        dr.billing_verified,
        p.full_name,
        (select coalesce(jsonb_agg(t.* order by t.task_id), '[]'::jsonb)
         from tasks t where t.discharge_request_id = dr.request_id),
        (select coalesce(jsonb_agg(b.* order by b.billing_id), '[]'::jsonb)
         from billing b where b.discharge_request_id = dr.request_id)
    from discharge_requests dr
    join patients p on p.patient_id = dr.patient_id
    where dr.request_id = p_request_id;
$$;

-- ============================================
-- DISCHARGE REQUESTS: list (optionally filtered by status)
-- ============================================
create or replace function list_discharge_requests(p_status text default null)
returns setof discharge_requests
language sql
stable
security definer
as $$
    select * from discharge_requests
    where p_status is null or status = p_status
    order by "timestamp" desc;
$$;

-- ============================================
-- ADDITIONAL FUNCTIONS
-- Added for the Nuxt dashboards: reject (the counterpart to approve),
-- role/name-scoped listings joined with display data the tables alone
-- don't carry (patient_full_name, officer full_name), and read models
-- the UI needs but the functions above don't return on their own.
-- ============================================

-- ── DISCHARGE REQUESTS: reject ──────────────────────────────────────────
-- Mirrors approve_discharge_request. approved_by doubles as "acted_by"
-- for audit purposes -- it records who made the call either way.
create or replace function reject_discharge_request(
    p_request_id  bigint,
    p_rejected_by bigint
)
returns discharge_requests
language plpgsql
security definer
as $$
declare
    v_request discharge_requests;
begin
    update discharge_requests
    set status = 'rejected', approved_by = p_rejected_by
    where request_id = p_request_id
    returning * into v_request;

    if v_request is null then
        raise exception 'Discharge request not found';
    end if;

    return v_request;
end;
$$;

-- ── DISCHARGE REQUESTS: list scoped to the officer who filed them ──────
create or replace function list_discharge_requests_by_requester(p_officer_id bigint)
returns table (
    request_id       bigint,
    patient_id       bigint,
    patient_name     text,
    status           text,
    billing_verified boolean,
    "timestamp"      timestamptz
)
language sql
stable
security definer
as $$
    select dr.request_id, dr.patient_id, p.full_name, dr.status, dr.billing_verified, dr."timestamp"
    from discharge_requests dr
    join patients p on p.patient_id = dr.patient_id
    where dr.requested_by = p_officer_id
    order by dr."timestamp" desc;
$$;

-- ── DISCHARGE REQUESTS: hospital-wide list with display names ──────────
create or replace function list_discharge_requests_detailed(p_status text default null)
returns table (
    request_id        bigint,
    patient_id        bigint,
    patient_name      text,
    requested_by      bigint,
    requested_by_name text,
    approved_by       bigint,
    approved_by_name  text,
    status            text,
    billing_verified  boolean,
    "timestamp"       timestamptz
)
language sql
stable
security definer
as $$
    select dr.request_id, dr.patient_id, p.full_name, dr.requested_by, ro.full_name,
        dr.approved_by, ao.full_name,
        dr.status, dr.billing_verified, dr."timestamp"
    from discharge_requests dr
    join patients p on p.patient_id = dr.patient_id
    join officers ro on ro.officer_id = dr.requested_by
    left join officers ao on ao.officer_id = dr.approved_by
    where p_status is null or dr.status = p_status
    order by dr."timestamp" desc;
$$;

-- ── TASKS: list assigned to an officer, with patient context ──────────
create or replace function list_tasks_for_officer_detailed(p_officer_id bigint)
returns table (
    task_id               bigint,
    discharge_request_id  bigint,
    patient_id            bigint,
    patient_name          text,
    task_type             text,
    status                text,
    created_at            timestamptz,
    completed_at          timestamptz
)
language sql
stable
security definer
as $$
    select t.task_id, t.discharge_request_id, p.patient_id, p.full_name,
        t.task_type, t.status, t.created_at, t.completed_at
    from tasks t
    join discharge_requests dr on dr.request_id = t.discharge_request_id
    join patients p on p.patient_id = dr.patient_id
    where t.assigned_to = p_officer_id
    order by (t.status = 'done'), t.created_at asc;
$$;

-- ── PATIENTS: scoped to attending officer ──────────────────────────────
create or replace function list_patients_by_officer(p_officer_id bigint)
returns setof patients
language sql
stable
security definer
as $$
    select * from patients
    where attending_officer_id = p_officer_id
    order by admission_date desc;
$$;

-- ── PATIENTS: hospital-wide, read-only ──────────────────────────────────
create or replace function list_all_patients()
returns setof patients
language sql
stable
security definer
as $$
    select * from patients
    order by admission_date desc;
$$;

-- ── OFFICERS: hospital-wide staff list ───────────────────────────────────
create or replace function list_officers()
returns setof officers
language sql
stable
security definer
as $$
    select * from officers
    order by role, full_name;
$$;

-- ============================================
-- GRANTS
-- RLS is enabled on every table with no policies, so the anon role has
-- zero direct table access. Every function the client calls has to be
-- explicitly granted here.
-- ============================================

revoke all on function set_duty_status(bigint, text) from public;
revoke all on function register_patient(text, date, smallint, text, text, smallint, text, bigint) from public;
revoke all on function update_patient_info(bigint, text, text, smallint, bigint) from public;
revoke all on function create_discharge_request(bigint, bigint) from public;
revoke all on function complete_task(bigint) from public;
revoke all on function list_tasks_for_officer(bigint) from public;
revoke all on function create_billing_record(bigint, bigint, numeric, numeric) from public;
revoke all on function verify_billing(bigint) from public;
revoke all on function approve_discharge_request(bigint, bigint) from public;
revoke all on function complete_discharge_request(bigint) from public;
revoke all on function get_discharge_request_details(bigint) from public;
revoke all on function list_discharge_requests(text) from public;
revoke all on function reject_discharge_request(bigint, bigint) from public;
revoke all on function list_discharge_requests_by_requester(bigint) from public;
revoke all on function list_discharge_requests_detailed(text) from public;
revoke all on function list_tasks_for_officer_detailed(bigint) from public;
revoke all on function list_patients_by_officer(bigint) from public;
revoke all on function list_all_patients() from public;
revoke all on function list_officers() from public;

grant execute on function set_duty_status(bigint, text) to anon;
grant execute on function register_patient(text, date, smallint, text, text, smallint, text, bigint) to anon;
grant execute on function update_patient_info(bigint, text, text, smallint, bigint) to anon;
grant execute on function create_discharge_request(bigint, bigint) to anon;
grant execute on function complete_task(bigint) to anon;
grant execute on function list_tasks_for_officer(bigint) to anon;
grant execute on function create_billing_record(bigint, bigint, numeric, numeric) to anon;
grant execute on function verify_billing(bigint) to anon;
grant execute on function approve_discharge_request(bigint, bigint) to anon;
grant execute on function complete_discharge_request(bigint) to anon;
grant execute on function get_discharge_request_details(bigint) to anon;
grant execute on function list_discharge_requests(text) to anon;
grant execute on function reject_discharge_request(bigint, bigint) to anon;
grant execute on function list_discharge_requests_by_requester(bigint) to anon;
grant execute on function list_discharge_requests_detailed(text) to anon;
grant execute on function list_tasks_for_officer_detailed(bigint) to anon;
grant execute on function list_patients_by_officer(bigint) to anon;
grant execute on function list_all_patients() to anon;
grant execute on function list_officers() to anon;
