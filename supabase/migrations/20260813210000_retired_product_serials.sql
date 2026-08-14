alter table public.product_serials
  add column if not exists is_retired boolean not null default false;

create index if not exists product_serials_selectable_idx
  on public.product_serials (product_id, is_maintenance, is_retired);
