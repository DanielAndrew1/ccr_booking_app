alter table public.bookings
  add column if not exists booking_number text,
  add column if not exists assigned_user_id uuid references public.users(id),
  add column if not exists deposit_amount numeric not null default 0,
  add column if not exists paid_amount numeric not null default 0,
  add column if not exists payment_status text not null default 'unpaid',
  add column if not exists cancelled_at timestamptz,
  add column if not exists completed_at timestamptz;

alter table public.clients
  add column if not exists notes text,
  add column if not exists preferred_contact_method text not null default 'push',
  add column if not exists reminder_opt_in boolean not null default true;

alter table public.products
  add column if not exists is_active boolean not null default true,
  add column if not exists maintenance_status text not null default 'available',
  add column if not exists maintenance_due_at timestamptz;

create unique index if not exists bookings_booking_number_key
  on public.bookings (booking_number)
  where booking_number is not null;

create index if not exists bookings_assigned_user_id_idx
  on public.bookings (assigned_user_id);

create index if not exists bookings_dates_idx
  on public.bookings (pickup_datetime, return_datetime);

create table if not exists public.booking_items (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  product_id uuid not null references public.products(id),
  quantity integer not null default 1 check (quantity > 0),
  unit_price numeric not null default 0 check (unit_price >= 0),
  created_at timestamptz not null default now(),
  unique (booking_id, product_id)
);

insert into public.booking_items (booking_id, product_id, quantity, unit_price)
select
  booking_id,
  product_id::uuid,
  count(*)::integer,
  max(product_price)
from (
  select
    bookings.id as booking_id,
    product_id,
    products.price as product_price
  from public.bookings
  cross join lateral unnest(bookings.product_ids) as product_id
  join public.products on products.id = product_id::uuid
) booking_product_rows
group by booking_id, product_id
on conflict (booking_id, product_id) do nothing;

create index if not exists booking_items_product_id_idx
  on public.booking_items (product_id);

create table if not exists public.booking_status_history (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  status text not null,
  changed_by uuid references public.users(id),
  note text,
  created_at timestamptz not null default now()
);

create index if not exists booking_status_history_booking_id_idx
  on public.booking_status_history (booking_id, created_at desc);

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  amount numeric not null check (amount > 0),
  method text not null,
  status text not null default 'pending',
  provider_reference text,
  paid_at timestamptz,
  recorded_by uuid references public.users(id),
  created_at timestamptz not null default now()
);

create index if not exists payments_booking_id_idx
  on public.payments (booking_id, created_at desc);

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

create table if not exists public.maintenance_records (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  status text not null default 'reported',
  summary text not null,
  cost numeric not null default 0,
  reported_by uuid references public.users(id),
  assigned_user_id uuid references public.users(id),
  due_at timestamptz,
  resolved_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists maintenance_records_product_id_idx
  on public.maintenance_records (product_id, created_at desc);

create table if not exists public.client_notes (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients(id) on delete cascade,
  body text not null,
  created_by uuid references public.users(id),
  created_at timestamptz not null default now()
);

create table if not exists public.staff_tasks (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid references public.bookings(id) on delete cascade,
  assigned_user_id uuid not null references public.users(id),
  title text not null,
  task_type text not null,
  due_at timestamptz,
  status text not null default 'open',
  completed_at timestamptz,
  created_by uuid references public.users(id),
  created_at timestamptz not null default now()
);

create index if not exists staff_tasks_assignee_idx
  on public.staff_tasks (assigned_user_id, status, due_at);

create table if not exists public.reminders (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  reminder_type text not null,
  channel text not null default 'push',
  scheduled_for timestamptz not null,
  sent_at timestamptz,
  status text not null default 'pending',
  provider_reference text,
  created_at timestamptz not null default now()
);

create index if not exists reminders_pending_idx
  on public.reminders (scheduled_for)
  where status = 'pending';

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.users(id),
  entity_type text not null,
  entity_id uuid,
  action text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists audit_logs_entity_idx
  on public.audit_logs (entity_type, entity_id, created_at desc);

create or replace function public.product_available_quantity(
  target_product_id uuid,
  starts_at timestamptz,
  ends_at timestamptz,
  excluded_booking_id uuid default null
)
returns integer
language sql
stable
as $$
  select greatest(
    0,
    products.quantity - coalesce(sum(booking_items.quantity) filter (
      where bookings.status not in ('cancelled', 'canceled', 'completed', 'deleted')
        and bookings.pickup_datetime < ends_at
        and bookings.return_datetime > starts_at
        and (excluded_booking_id is null or bookings.id <> excluded_booking_id)
    ), 0)
  )::integer
  from public.products
  left join public.booking_items on booking_items.product_id = products.id
  left join public.bookings on bookings.id = booking_items.booking_id
  where products.id = target_product_id
  group by products.quantity;
$$;
