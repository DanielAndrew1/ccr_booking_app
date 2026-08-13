-- Run this once in Supabase SQL Editor.
-- It allows signed-in app users to manage the products attached to projects.
alter table public.booking_items enable row level security;

drop policy if exists "Authenticated users manage booking items" on public.booking_items;
create policy "Authenticated users manage booking items"
  on public.booking_items
  for all
  to authenticated
  using (true)
  with check (true);

alter table public.booking_status_history enable row level security;
drop policy if exists "Authenticated users manage booking status history" on public.booking_status_history;
create policy "Authenticated users manage booking status history"
  on public.booking_status_history
  for all
  to authenticated
  using (true)
  with check (true);

alter table public.audit_logs enable row level security;
drop policy if exists "Authenticated users create audit logs" on public.audit_logs;
create policy "Authenticated users create audit logs"
  on public.audit_logs
  for insert
  to authenticated
  with check (true);
