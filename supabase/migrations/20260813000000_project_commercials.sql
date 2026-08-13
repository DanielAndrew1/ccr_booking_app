-- Commercial details now belong to a project instead of an inventory product.
alter table public.bookings
  add column if not exists payment_plan_type text not null default 'one_time_end',
  add column if not exists payment_frequency text,
  add column if not exists payment_interval integer not null default 1,
  add column if not exists installment_amount numeric,
  add column if not exists down_payment_amount numeric not null default 0,
  add column if not exists contract_path text,
  add column if not exists quote_number text;

alter table public.bookings
  drop constraint if exists bookings_payment_plan_type_check;

alter table public.bookings
  add constraint bookings_payment_plan_type_check
  check (payment_plan_type in (
    'one_time_start',
    'one_time_end',
    'monthly',
    'down_payment_installments'
  ));

insert into storage.buckets (id, name, public)
values ('project-contracts', 'project-contracts', false)
on conflict (id) do nothing;

drop policy if exists "Authenticated users can read project contracts" on storage.objects;
create policy "Authenticated users can read project contracts"
  on storage.objects for select to authenticated
  using (bucket_id = 'project-contracts');

drop policy if exists "Authenticated users can upload project contracts" on storage.objects;
create policy "Authenticated users can upload project contracts"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'project-contracts');

drop policy if exists "Authenticated users can update project contracts" on storage.objects;
create policy "Authenticated users can update project contracts"
  on storage.objects for update to authenticated
  using (bucket_id = 'project-contracts')
  with check (bucket_id = 'project-contracts');
