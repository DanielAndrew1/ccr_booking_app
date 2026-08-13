alter table public.products
  add column if not exists is_unlimited boolean not null default false,
  add column if not exists tracks_serial_numbers boolean not null default false;

create table if not exists public.project_locations (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references public.bookings(id) on delete cascade,
  address text not null,
  city text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.camera_installations (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  serial_number text not null unique,
  installed_at timestamptz not null default now(),
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists camera_installations_booking_id_idx
  on public.camera_installations (booking_id);

alter table public.project_locations enable row level security;
alter table public.camera_installations enable row level security;

drop policy if exists "Authenticated users manage project locations" on public.project_locations;
create policy "Authenticated users manage project locations"
  on public.project_locations for all to authenticated
  using (true) with check (true);

drop policy if exists "Authenticated users manage camera installations" on public.camera_installations;
create policy "Authenticated users manage camera installations"
  on public.camera_installations for all to authenticated
  using (true) with check (true);
