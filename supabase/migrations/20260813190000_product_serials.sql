create table if not exists public.product_serials (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  serial_number text not null unique,
  created_at timestamptz not null default now()
);

create index if not exists product_serials_product_id_idx
  on public.product_serials (product_id);

create table if not exists public.booking_serial_assignments (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  product_id uuid not null references public.products(id),
  product_serial_id uuid not null references public.product_serials(id),
  created_at timestamptz not null default now(),
  unique (booking_id, product_serial_id)
);

create index if not exists booking_serial_assignments_booking_id_idx
  on public.booking_serial_assignments (booking_id);

alter table public.product_serials enable row level security;
alter table public.booking_serial_assignments enable row level security;

drop policy if exists "Authenticated users manage product serials" on public.product_serials;
create policy "Authenticated users manage product serials"
  on public.product_serials for all to authenticated
  using (true) with check (true);

drop policy if exists "Authenticated users manage booking serial assignments" on public.booking_serial_assignments;
create policy "Authenticated users manage booking serial assignments"
  on public.booking_serial_assignments for all to authenticated
  using (true) with check (true);
