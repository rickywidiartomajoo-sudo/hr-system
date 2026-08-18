-- =====================================================================
-- Auto-generated request numbers: CUTI-2026-0001, RMB-2026-0001, dst.
-- =====================================================================

alter table public.leave_requests add column if not exists request_number text unique;
alter table public.reimburse_requests add column if not exists request_number text unique;

create sequence if not exists public.leave_request_seq;
create sequence if not exists public.reimburse_request_seq;

create or replace function public.set_request_number()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_prefix text;
  v_seq_name text;
  v_next bigint;
begin
  if new.request_number is not null then
    return new;
  end if;

  if TG_TABLE_NAME = 'leave_requests' then
    v_prefix := 'CUTI';
    v_seq_name := 'public.leave_request_seq';
  else
    v_prefix := 'RMB';
    v_seq_name := 'public.reimburse_request_seq';
  end if;

  v_next := nextval(v_seq_name);
  new.request_number := v_prefix || '-' || to_char(now(), 'YYYY') || '-' || lpad(v_next::text, 4, '0');
  return new;
end;
$$;

drop trigger if exists trg_set_leave_request_number on public.leave_requests;
create trigger trg_set_leave_request_number
  before insert on public.leave_requests
  for each row execute function public.set_request_number();

drop trigger if exists trg_set_reimburse_request_number on public.reimburse_requests;
create trigger trg_set_reimburse_request_number
  before insert on public.reimburse_requests
  for each row execute function public.set_request_number();
