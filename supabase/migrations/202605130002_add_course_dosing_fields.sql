alter table public.medications
  add column if not exists start_date date,
  add column if not exists duration_days integer,
  add column if not exists daily_plans jsonb not null default '[]'::jsonb;
