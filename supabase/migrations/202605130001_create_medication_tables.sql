create table if not exists public.medications (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  dosage text not null,
  schedule jsonb not null,
  created_at timestamptz not null,
  updated_at timestamptz not null
);

create table if not exists public.medication_logs (
  id uuid primary key,
  medication_id uuid not null references public.medications(id) on delete cascade,
  scheduled_time timestamptz not null,
  confirmed_time timestamptz,
  status text not null check (status in ('confirmed', 'missed')),
  date date not null
);

alter table public.medications enable row level security;
alter table public.medication_logs enable row level security;

create policy "Users manage own medications"
on public.medications
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "Users manage logs for own medications"
on public.medication_logs
for all
using (
  exists (
    select 1
    from public.medications
    where medications.id = medication_logs.medication_id
      and medications.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.medications
    where medications.id = medication_logs.medication_id
      and medications.user_id = auth.uid()
  )
);
