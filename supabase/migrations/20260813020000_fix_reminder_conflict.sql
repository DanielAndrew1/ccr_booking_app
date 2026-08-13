-- Run this in Supabase SQL Editor to fix project finance/reminder creation.
drop index if exists public.reminders_payment_schedule_type_key;

create unique index reminders_payment_schedule_type_key
  on public.reminders (payment_schedule_id, reminder_type);

create or replace function public.sync_project_finance(target_booking_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  project public.bookings%rowtype;
  invoice_id uuid;
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
    insert into public.payment_schedules (booking_id, invoice_id, schedule_type, amount, due_at) values (project.id, invoice_id, 'project_start', project.total_price, project.pickup_datetime);
  elsif project.payment_plan_type = 'one_time_end' then
    insert into public.payment_schedules (booking_id, invoice_id, schedule_type, amount, due_at) values (project.id, invoice_id, 'project_end', project.total_price, project.return_datetime);
  elsif project.payment_plan_type = 'monthly' then
    schedule_amount := coalesce(nullif(project.installment_amount, 0), project.total_price);
    payment_date := project.pickup_datetime;
    while payment_date <= project.return_datetime loop
      insert into public.payment_schedules (booking_id, invoice_id, schedule_type, amount, due_at) values (project.id, invoice_id, 'monthly', schedule_amount, payment_date);
      payment_date := payment_date + interval '1 month';
    end loop;
  else
    if coalesce(project.down_payment_amount, 0) > 0 then
      insert into public.payment_schedules (booking_id, invoice_id, schedule_type, amount, due_at) values (project.id, invoice_id, 'down_payment', project.down_payment_amount, project.pickup_datetime);
    end if;
    schedule_amount := coalesce(nullif(project.installment_amount, 0), project.total_price - coalesce(project.down_payment_amount, 0));
    payment_date := project.pickup_datetime + case when coalesce(project.payment_frequency, 'month') = 'week' then (coalesce(project.payment_interval, 1) || ' weeks')::interval else (coalesce(project.payment_interval, 1) || ' months')::interval end;
    while payment_date <= project.return_datetime loop
      insert into public.payment_schedules (booking_id, invoice_id, schedule_type, amount, due_at) values (project.id, invoice_id, 'installment', schedule_amount, payment_date);
      payment_date := payment_date + case when coalesce(project.payment_frequency, 'month') = 'week' then (coalesce(project.payment_interval, 1) || ' weeks')::interval else (coalesce(project.payment_interval, 1) || ' months')::interval end;
    end loop;
  end if;
  insert into public.reminders (booking_id, payment_schedule_id, reminder_type, channel, scheduled_for, status)
  select booking_id, id, 'payment_due', 'push', greatest(now(), due_at - interval '3 days'), 'pending'
  from public.payment_schedules where booking_id = project.id and status = 'pending'
  on conflict (payment_schedule_id, reminder_type) do nothing;
end;
$$;
