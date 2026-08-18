-- ============================================
-- AHDMS Legacy Cleanup
-- Run this ONCE, before (re-)running ahdms_core_functions.sql, on any
-- Supabase project that had the pre-migration functions applied
-- (schema.sql / doctor_dashboard.sql / nurse_dashboard.sql /
-- officer_profile.sql / staff_registration.sql, or anything created ad
-- hoc directly in the SQL editor for the old `administrator`-table /
-- `patients.id` schema).
--
-- Those old functions still exist as live objects in Postgres even
-- though the local .sql files were deleted from the repo -- deleting a
-- file never touches the database. Some of them (list_all_patients,
-- list_patients_by_officer, create_discharge_request) share a name with
-- a NEW function in ahdms_core_functions.sql but return a different
-- shape, and `create or replace function` cannot change an existing
-- function's return type -- so the new file fails to apply until the
-- old versions are dropped first.
-- ============================================

drop function if exists list_all_discharge_requests();
drop function if exists update_discharge_request_status_by_doctor(int8, text, int8);
drop function if exists list_all_patients();
drop function if exists create_patient(text, date, text, int8, int8, date, text, text, int8, timestamptz);
drop function if exists update_patient(int8, text, date, text, int8, date, text, text, int8, timestamptz, int8);
drop function if exists list_patients_by_officer(int8);
drop function if exists create_discharge_request(int8, int8);
drop function if exists update_discharge_request_status(int8, text, int8);
drop function if exists list_discharge_requests_by_officer(int8);
drop function if exists list_tasks_by_officer(int8);
drop function if exists update_task_status(int8, text, int8);
drop function if exists get_officer_name(int8);
drop function if exists register_users(text, text);
drop function if exists register_staff(text, text, text, text, int8);
drop function if exists list_officers_with_duty();
drop function if exists set_officer_duty_status(int8, text, int8);
drop function if exists login_administrator(text, text);
drop function if exists login_administrator(text, text, text);
drop function if exists register_administrator(text, text);

-- Ask PostgREST to pick up the change immediately instead of waiting for
-- its next automatic schema-cache refresh.
select pg_notify('pgrst', 'reload schema');
