-- Paste this entire script into Supabase Dashboard → SQL Editor → New query.
-- It is safe to run after (or instead of) the previous commercial-fields script.

alter table public.bookings
  add column if not exists payment_plan_type text not null default 'one_time_end',
  add column if not exists payment_frequency text,
  add column if not exists payment_interval integer not null default 1,
  add column if not exists installment_amount numeric,
  add column if not exists down_payment_amount numeric not null default 0,
  add column if not exists contract_path text,
  add column if not exists quote_number text;

insert into storage.buckets (id, name, public)
values ('project-contracts', 'project-contracts', false)
on conflict (id) do nothing;

drop policy if exists "Authenticated users can read project contracts" on storage.objects;
create policy "Authenticated users can read project contracts" on storage.objects for select to authenticated using (bucket_id = 'project-contracts');
drop policy if exists "Authenticated users can upload project contracts" on storage.objects;
create policy "Authenticated users can upload project contracts" on storage.objects for insert to authenticated with check (bucket_id = 'project-contracts');
drop policy if exists "Authenticated users can update project contracts" on storage.objects;
create policy "Authenticated users can update project contracts" on storage.objects for update to authenticated using (bucket_id = 'project-contracts') with check (bucket_id = 'project-contracts');

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  amount numeric not null check (amount > 0),
  method text not null default 'cash',
  status text not null default 'completed',
  provider_reference text,
  paid_at timestamptz default now(),
  recorded_by uuid references public.users(id),
  created_at timestamptz not null default now()
);

create table if not exists public.invoices (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references public.bookings(id) on delete cascade,
  invoice_number text not null unique,
  subtotal numeric not null default 0,
  deposit_amount numeric not null default 0,
  paid_amount numeric not null default 0,
  status text not null default 'draft',
  issued_at timestamptz,
  due_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.payments
  add column if not exists payment_schedule_id uuid,
  add column if not exists receipt_number text;

create unique index if not exists payments_receipt_number_key
  on public.payments (receipt_number) where receipt_number is not null;

create table if not exists public.payment_schedules (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  invoice_id uuid references public.invoices(id) on delete set null,
  schedule_type text not null,
  amount numeric not null check (amount > 0),
  due_at timestamptz not null,
  status text not null default 'pending' check (status in ('pending', 'paid', 'overdue', 'cancelled')),
  paid_amount numeric not null default 0 check (paid_amount >= 0),
  paid_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.payments
  drop constraint if exists payments_payment_schedule_id_fkey;
alter table public.payments
  add constraint payments_payment_schedule_id_fkey
  foreign key (payment_schedule_id) references public.payment_schedules(id) on delete set null;

create index if not exists payment_schedules_due_idx
  on public.payment_schedules (due_at, status);

alter table public.reminders
  add column if not exists payment_schedule_id uuid references public.payment_schedules(id) on delete cascade;
drop index if exists public.reminders_payment_schedule_type_key;
create unique index reminders_payment_schedule_type_key
  on public.reminders (payment_schedule_id, reminder_type);

create or replace function public.sync_project_finance(target_booking_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  project public.bookings%rowtype;
  invoice_id uuid;
  due_date timestamptz;
  schedule_amount numeric;
  payment_date timestamptz;
begin
  select * into project from public.bookings where id = target_booking_id;
  if not found then raise exception 'Project not found'; end if;

  insert into public.invoices (booking_id, invoice_number, subtotal, deposit_amount, paid_amount, status, issued_at, due_at)
  values (project.id, 'SLI-' || upper(left(project.id::text, 8)), coalesce(project.total_price, 0), coalesce(project.down_payment_amount, 0), 0, 'issued', now(), project.return_datetime)
  on conflict (booking_id) do update set subtotal = excluded.subtotal, deposit_amount = excluded.deposit_amount, due_at = excluded.due_at
  returning id into invoice_id;

  delete from public.reminders where payment_schedule_id in (select id from public.payment_schedules where booking_id = project.id and status = 'pending');
  delete from public.payment_schedules where booking_id = project.id and status = 'pending';

  if project.payment_plan_type = 'one_time_start' then
    insert into public.payment_schedules (booking_id, invoice_id, schedule_type, amount, due_at)
    values (project.id, invoice_id, 'project_start', project.total_price, project.pickup_datetime);
  elsif project.payment_plan_type = 'one_time_end' then
    insert into public.payment_schedules (booking_id, invoice_id, schedule_type, amount, due_at)
    values (project.id, invoice_id, 'project_end', project.total_price, project.return_datetime);
  elsif project.payment_plan_type = 'monthly' then
    schedule_amount := coalesce(nullif(project.installment_amount, 0), project.total_price);
    payment_date := project.pickup_datetime;
    while payment_date <= project.return_datetime loop
      insert into public.payment_schedules (booking_id, invoice_id, schedule_type, amount, due_at)
      values (project.id, invoice_id, 'monthly', schedule_amount, payment_date);
      payment_date := payment_date + interval '1 month';
    end loop;
  else
    if coalesce(project.down_payment_amount, 0) > 0 then
      insert into public.payment_schedules (booking_id, invoice_id, schedule_type, amount, due_at)
      values (project.id, invoice_id, 'down_payment', project.down_payment_amount, project.pickup_datetime);
    end if;
    schedule_amount := coalesce(nullif(project.installment_amount, 0), project.total_price - coalesce(project.down_payment_amount, 0));
    payment_date := project.pickup_datetime + case when coalesce(project.payment_frequency, 'month') = 'week' then (coalesce(project.payment_interval, 1) || ' weeks')::interval else (coalesce(project.payment_interval, 1) || ' months')::interval end;
    while payment_date <= project.return_datetime loop
      insert into public.payment_schedules (booking_id, invoice_id, schedule_type, amount, due_at)
      values (project.id, invoice_id, 'installment', schedule_amount, payment_date);
      payment_date := payment_date + case when coalesce(project.payment_frequency, 'month') = 'week' then (coalesce(project.payment_interval, 1) || ' weeks')::interval else (coalesce(project.payment_interval, 1) || ' months')::interval end;
    end loop;
  end if;

  insert into public.reminders (booking_id, payment_schedule_id, reminder_type, channel, scheduled_for, status)
  select booking_id, id, 'payment_due', 'push', greatest(now(), due_at - interval '3 days'), 'pending'
  from public.payment_schedules where booking_id = project.id and status = 'pending'
  on conflict (payment_schedule_id, reminder_type) do nothing;
end;
$$;

create or replace view public.finance_dashboard as
select
  coalesce(sum(case when due_at < now() and status in ('pending', 'overdue') then amount - paid_amount else 0 end), 0) as overdue_amount,
  count(*) filter (where due_at < now() and status in ('pending', 'overdue')) as overdue_payments,
  coalesce(sum(case when due_at >= date_trunc('month', now()) and due_at < date_trunc('month', now()) + interval '1 month' and status in ('pending', 'overdue') then amount - paid_amount else 0 end), 0) as expected_this_month,
  coalesce(sum(case when due_at >= now() and status in ('pending', 'overdue') then amount - paid_amount else 0 end), 0) as expected_future_income
from public.payment_schedules;

create or replace function public.record_project_payment(target_schedule_id uuid, payment_amount numeric, payment_method text default 'cash')
returns uuid language plpgsql security definer set search_path = public as $$
declare payment_id uuid; target_booking_id uuid;
begin
  select booking_id into target_booking_id from public.payment_schedules where id = target_schedule_id;
  if target_booking_id is null then raise exception 'Payment schedule not found'; end if;
  insert into public.payments (booking_id, payment_schedule_id, amount, method, status, paid_at, receipt_number)
  values (target_booking_id, target_schedule_id, payment_amount, payment_method, 'completed', now(), 'SLR-' || upper(left(gen_random_uuid()::text, 8))) returning id into payment_id;
  update public.payment_schedules set paid_amount = paid_amount + payment_amount, paid_at = now(), status = case when paid_amount + payment_amount >= amount then 'paid' else 'pending' end where id = target_schedule_id;
  update public.invoices set paid_amount = (select coalesce(sum(amount), 0) from public.payments where booking_id = target_booking_id and status = 'completed'), status = case when (select coalesce(sum(amount), 0) from public.payments where booking_id = target_booking_id and status = 'completed') >= subtotal then 'paid' else 'part_paid' end where booking_id = target_booking_id;
  return payment_id;
end;
$$;
