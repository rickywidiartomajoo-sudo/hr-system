-- =====================================================================
-- Attendance (absensi) with geotagging + selfie photo
-- One row per employee per day, check-in and check-out on the same row.
-- =====================================================================

create table if not exists public.attendance (
  id                uuid primary key default gen_random_uuid(),
  employee_id       uuid not null references public.profiles(id) on delete cascade,
  att_date          date not null default (now() at time zone 'Asia/Jakarta')::date,
  check_in_at       timestamptz,
  check_in_lat      double precision,
  check_in_lng      double precision,
  check_in_accuracy double precision,
  check_in_photo_url text,
  check_out_at      timestamptz,
  check_out_lat     double precision,
  check_out_lng     double precision,
  check_out_accuracy double precision,
  check_out_photo_url text,
  created_at        timestamptz not null default now(),
  unique (employee_id, att_date)
);

create index if not exists idx_attendance_employee on public.attendance(employee_id);
create index if not exists idx_attendance_date on public.attendance(att_date desc);

alter table public.attendance enable row level security;

create policy attendance_select on public.attendance
  for select using (employee_id = auth.uid() or public.is_hr_or_admin());

create policy attendance_insert_own on public.attendance
  for insert with check (employee_id = auth.uid());

create policy attendance_update_own on public.attendance
  for update using (employee_id = auth.uid()) with check (employee_id = auth.uid());

insert into storage.buckets (id, name, public)
values ('attendance', 'attendance', false)
on conflict (id) do nothing;

create policy storage_attendance_insert_own on storage.objects
  for insert with check (bucket_id = 'attendance' and (storage.foldername(name))[1] = auth.uid()::text);
create policy storage_attendance_read on storage.objects
  for select using (bucket_id = 'attendance' and ((storage.foldername(name))[1] = auth.uid()::text or public.is_hr_or_admin()));
