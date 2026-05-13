# Supabase And UptimeRobot Setup

## Supabase

1. Create a Supabase project.
2. Run all SQL files in `supabase/migrations/` in filename order.
3. Build the app with `--dart-define=SUPABASE_URL=<project-url>` and
   `--dart-define=SUPABASE_ANON_KEY=<anon-key>`.
4. This personal build uses the app's fixed local user id for sync. Do not
   publish the APK publicly with the same Supabase anon key.

## UptimeRobot

1. Create an HTTP(s) monitor.
2. Target the Supabase REST endpoint: `https://<project-ref>.supabase.co/rest/v1/`.
3. Set the interval to 5 minutes.
4. Configure email or push alert contacts.

The app must remain usable when this monitor reports downtime because SQLite is
the source of truth.
