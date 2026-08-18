-- =====================================================================
-- In-app notifications for leave/reimburse approval & rejection
-- =====================================================================

create table if not exists public.notifications (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  title       text not null,
  body        text not null,
  kind        text not null default 'info' check (kind in ('info','success','danger')),
  ref_table   text,
  ref_id      uuid,
  is_read     boolean not null default false,
  created_at  timestamptz not null default now()
);

create index if not exists idx_notifications_user on public.notifications(user_id, is_read, created_at desc);

alter table public.notifications enable row level security;

create policy notifications_select_own on public.notifications
  for select using (user_id = auth.uid());

create policy notifications_update_own on public.notifications
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());

create or replace function public.notify_request_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_kind_label text;
  v_body text;
begin
  if new.status is distinct from old.status and new.status in ('approved','rejected') then
    v_kind_label := case when new.status = 'approved' then 'disetujui' else 'ditolak' end;

    if TG_TABLE_NAME = 'leave_requests' then
      v_body := 'Pengajuan cuti kamu (' || new.leave_type || ', ' || new.start_date || ' s/d ' || new.end_date || ') telah ' || v_kind_label || '.';
    else
      v_body := 'Pengajuan reimburse kamu (' || new.category || ', Rp' || to_char(new.amount, 'FM999,999,999') || ') telah ' || v_kind_label || '.';
    end if;

    if new.hr_notes is not null and length(trim(new.hr_notes)) > 0 then
      v_body := v_body || ' Catatan: ' || new.hr_notes;
    end if;

    insert into public.notifications (user_id, title, body, kind, ref_table, ref_id)
    values (
      new.employee_id,
      case when new.status='approved' then 'Pengajuan Disetujui' else 'Pengajuan Ditolak' end,
      v_body,
      case when new.status='approved' then 'success' else 'danger' end,
      TG_TABLE_NAME,
      new.id
    );
  end if;
  return new;
end;
$$;

drop trigger if exists trg_notify_leave_status on public.leave_requests;
create trigger trg_notify_leave_status
  after update on public.leave_requests
  for each row execute function public.notify_request_status();

drop trigger if exists trg_notify_reimburse_status on public.reimburse_requests;
create trigger trg_notify_reimburse_status
  after update on public.reimburse_requests
  for each row execute function public.notify_request_status();
