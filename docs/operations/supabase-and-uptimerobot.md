# Supabase And UptimeRobot Setup

## Supabase

1. Create a Supabase project.
2. Run `supabase/migrations/202605130001_create_medication_tables.sql`.
3. Enable Google provider in Supabase Auth.
4. Add app URL scheme and deep links after the Android package name is finalized.
5. Store `SUPABASE_URL` and `SUPABASE_ANON_KEY` in local build configuration.

## UptimeRobot

1. Create an HTTP(s) monitor.
2. Target the Supabase REST endpoint: `https://<project-ref>.supabase.co/rest/v1/`.
3. Set the interval to 5 minutes.
4. Configure email or push alert contacts.

The app must remain usable when this monitor reports downtime because SQLite is
the source of truth.
