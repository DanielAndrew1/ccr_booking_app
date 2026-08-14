alter table public.bookings
  add column if not exists project_name text,
  add column if not exists project_address text,
  add column if not exists estimated_duration text,
  add column if not exists project_type text,
  add column if not exists contact_full_name text,
  add column if not exists contact_role text,
  add column if not exists contact_phone text,
  add column if not exists contact_email text;
