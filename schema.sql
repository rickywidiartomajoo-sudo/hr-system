-- =====================================================================
-- Dragonworks HRIS — schema for new Supabase project
-- Reverse-engineered from index.html frontend calls (sb.from / sb.storage)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. PROFILES (mirrors auth.users, 1 row per user)
-- ---------------------------------------------------------------------
create table if not exists public.profiles (
  id              uuid primary key references auth.users(id) on delete cascade,
  full_name       text not null,
  email           text not null,
  position_title  text,
  division        text,
  role            text not null default 'employee' check (role in ('admin','hr','employee')),
  is_active       boolean not null default true,
  avatar_url      text,
  created_at      timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 2. LEAVE REQUESTS
-- ---------------------------------------------------------------------
create table if not exists public.leave_requests (
  id              uuid primary key default gen_random_uuid(),
  employee_id     uuid not null references public.profiles(id) on delete cascade,
  leave_type      text not null check (leave_type in ('annual','sick','permit','unpaid','other')),
  start_date      date not null,
  end_date        date not null,
  reason          text not null,
  attachment_url  text,
  status          text not null default 'pending' check (status in ('pending','approved','rejected')),
  hr_notes        text,
  approved_by     uuid references public.profiles(id),
  created_at      timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 3. REIMBURSE REQUESTS
-- ---------------------------------------------------------------------
create table if not exists public.reimburse_requests (
  id              uuid primary key default gen_random_uuid(),
  employee_id     uuid not null references public.profiles(id) on delete cascade,
  category        text not null,
  amount          numeric(14,2) not null check (amount > 0),
  description     text not null,
  invoice_url     text,
  status          text not null default 'pending' check (status in ('pending','approved','rejected')),
  hr_notes        text,
  approved_by     uuid references public.profiles(id),
  created_at      timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 4. ACTIVITY LOGS
-- ---------------------------------------------------------------------
create table if not exists public.activity_logs (
  id              uuid primary key default gen_random_uuid(),
  actor_id        uuid references public.profiles(id) on delete set null,
  action          text not null,
  description     text,
  metadata        jsonb not null default '{}'::jsonb,
  created_at      timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 5. SETTINGS (single row, id = 1)
-- ---------------------------------------------------------------------
create table if not exists public.settings (
  id                  int primary key default 1 check (id = 1),
  company_name        text default '',
  address             text default '',
  email               text default '',
  phone               text default '',
  logo_url            text,
  primary_color       text default '#6366F1',
  annual_leave_quota  int default 12
);
insert into public.settings (id) values (1) on conflict (id) do nothing;

-- ---------------------------------------------------------------------
-- 6. INDEXES
-- ---------------------------------------------------------------------
create index if not exists idx_leave_employee on public.leave_requests(employee_id);
create index if not exists idx_leave_status on public.leave_requests(status);
create index if not exists idx_reimburse_employee on public.reimburse_requests(employee_id);
create index if not exists idx_reimburse_status on public.reimburse_requests(status);
create index if not exists idx_activity_actor on public.activity_logs(actor_id);
create index if not exists idx_activity_created on public.activity_logs(created_at desc);

-- ---------------------------------------------------------------------
-- 7. DASHBOARD SUMMARY VIEW (used by DashboardAPI.summary)
-- ---------------------------------------------------------------------
create or replace view public.v_dashboard_summary as
select
  (select count(*) from public.profiles)                                   as total_employee,
  (select count(*) from public.leave_requests)                             as total_leave,
  (select count(*) from public.reimburse_requests)                         as total_reimburse,
  (select count(*) from public.leave_requests where status = 'pending')
    + (select count(*) from public.reimburse_requests where status = 'pending') as total_pending,
  (select count(*) from public.leave_requests where status = 'approved')
    + (select count(*) from public.reimburse_requests where status = 'approved') as total_approved,
  (select count(*) from public.leave_requests where status = 'rejected')
    + (select count(*) from public.reimburse_requests where status = 'rejected') as total_rejected;

-- ---------------------------------------------------------------------
-- 8. HELPER FUNCTIONS (security definer, avoid RLS recursion on profiles)
-- ---------------------------------------------------------------------
create or replace function public.is_hr_or_admin()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.profiles where id = auth.uid() and role in ('admin','hr')
  );
$$;

create or replace function public.is_admin()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.profiles where id = auth.uid() and role = 'admin'
  );
$$;

grant execute on function public.is_hr_or_admin() to authenticated;
grant execute on function public.is_admin() to authenticated;

-- ---------------------------------------------------------------------
-- 9. ROW LEVEL SECURITY
-- ---------------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.leave_requests enable row level security;
alter table public.reimburse_requests enable row level security;
alter table public.activity_logs enable row level security;
alter table public.settings enable row level security;

-- profiles: everyone can read their own row; hr/admin can read all
create policy profiles_select on public.profiles
  for select using (id = auth.uid() or public.is_hr_or_admin());

-- profiles: user can update only their own row (full_name, avatar_url from "Profil Saya")
create policy profiles_update_self on public.profiles
  for update using (id = auth.uid()) with check (id = auth.uid());
-- NOTE: admin create/update/delete/role-change/reset-password of OTHER users goes through
-- the create-user / update-user / delete-user / update-role / reset-password Edge Functions,
-- which must run with the service_role key (bypasses RLS). Those Edge Functions are NOT part
-- of this HTML file, so redeploy/recreate them separately on the new project.

-- leave_requests
create policy leave_select on public.leave_requests
  for select using (employee_id = auth.uid() or public.is_hr_or_admin());
create policy leave_insert on public.leave_requests
  for insert with check (employee_id = auth.uid());
create policy leave_update_hr on public.leave_requests
  for update using (public.is_hr_or_admin());
create policy leave_delete on public.leave_requests
  for delete using (employee_id = auth.uid() or public.is_hr_or_admin());

-- reimburse_requests
create policy reimburse_select on public.reimburse_requests
  for select using (employee_id = auth.uid() or public.is_hr_or_admin());
create policy reimburse_insert on public.reimburse_requests
  for insert with check (employee_id = auth.uid());
create policy reimburse_update_hr on public.reimburse_requests
  for update using (public.is_hr_or_admin());
create policy reimburse_delete on public.reimburse_requests
  for delete using (employee_id = auth.uid() or public.is_hr_or_admin());

-- activity_logs: readable by any authenticated user (dashboard "recent activity" widget
-- is shown to all roles); only self-attributed inserts
create policy activity_select on public.activity_logs
  for select using (auth.role() = 'authenticated');
create policy activity_insert on public.activity_logs
  for insert with check (actor_id = auth.uid());

-- settings: readable by all authenticated users, editable by admin only
create policy settings_select on public.settings
  for select using (auth.role() = 'authenticated');
create policy settings_update on public.settings
  for update using (public.is_admin());

-- ---------------------------------------------------------------------
-- 10. STORAGE BUCKETS (leave/invoice attachments = private, avatar = public)
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('leave', 'leave', false), ('invoice', 'invoice', false), ('avatar', 'avatar', true)
on conflict (id) do nothing;

-- users upload only into their own "<uid>/..." folder
create policy storage_leave_insert_own on storage.objects
  for insert with check (bucket_id = 'leave' and (storage.foldername(name))[1] = auth.uid()::text);
create policy storage_leave_read on storage.objects
  for select using (bucket_id = 'leave' and ((storage.foldername(name))[1] = auth.uid()::text or public.is_hr_or_admin()));

create policy storage_invoice_insert_own on storage.objects
  for insert with check (bucket_id = 'invoice' and (storage.foldername(name))[1] = auth.uid()::text);
create policy storage_invoice_read on storage.objects
  for select using (bucket_id = 'invoice' and ((storage.foldername(name))[1] = auth.uid()::text or public.is_hr_or_admin()));

create policy storage_avatar_insert_own on storage.objects
  for insert with check (bucket_id = 'avatar' and (storage.foldername(name))[1] = auth.uid()::text);
create policy storage_avatar_public_read on storage.objects
  for select using (bucket_id = 'avatar');
