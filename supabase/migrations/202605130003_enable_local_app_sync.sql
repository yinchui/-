alter table public.medications
  drop constraint if exists medications_user_id_fkey;

drop policy if exists "Users manage own medications" on public.medications;
drop policy if exists "Users manage logs for own medications" on public.medication_logs;
drop policy if exists "Local app manages medication sync" on public.medications;
drop policy if exists "Local app manages medication log sync" on public.medication_logs;

create policy "Local app manages medication sync"
on public.medications
for all
using (user_id = '00000000-0000-4000-8000-000000000000')
with check (user_id = '00000000-0000-4000-8000-000000000000');

create policy "Local app manages medication log sync"
on public.medication_logs
for all
using (
  exists (
    select 1
    from public.medications
    where medications.id = medication_logs.medication_id
      and medications.user_id = '00000000-0000-4000-8000-000000000000'
  )
)
with check (
  exists (
    select 1
    from public.medications
    where medications.id = medication_logs.medication_id
      and medications.user_id = '00000000-0000-4000-8000-000000000000'
  )
);
