# Medication Reminder App Verification

Date: 2026-05-13

## Commands

- `dart format .` passed: formatted 49 files, 0 changed.
- `flutter test` passed: 52 tests.
- `flutter analyze` passed: no issues found.
- `flutter build apk --debug` passed: built `build/app/outputs/flutter-apk/app-debug.apk`.
- Course dosing update: `dart format .` passed: formatted 50 files, 0 changed.
- Course dosing update: `flutter test` passed: 66 tests.
- Course dosing update: `flutter analyze` passed: no issues found.
- Course dosing update: `flutter build apk --release` passed: built `build/app/outputs/flutter-apk/app-release.apk`.

## Manual Checks

Android device verification was executed on a physical `Mi 10` running Android 13 (API 33), device id `b1991f76`.

Observed on device:

- `adb install -r -d build/app/outputs/flutter-apk/app-debug.apk` installed successfully.
- The app launched into `com.yaowan.medication_reminder/.MainActivity`.
- Today tab loaded with warm background and bottom navigation.
- Medication could be added with two daily times (`14:30,20:00`).
- Today tab displayed the medication grouped by time.
- Calendar tab rendered the month grid and stats band without overflow.
- App restart kept medications in SQLite.
- Delete confirmation removed the test medication and returned the medication list to the empty state.
- App startup and main navigation did not show an app-level fatal exception in logcat.
- Course dosing update was installed with `adb install -r -d /Users/aa/Desktop/yaowan-medication-reminder.apk` successfully.
- Launch after update showed the app title `药记录` on the Today tab.
- Automated widget coverage verifies future course doses are visible on the Calendar page.
- Automated widget coverage verifies existing course medications can be opened from the medication list, edited, saved, and persisted without changing the record identity.

Known gaps from device smoke testing:

- Confirmation flow was not reachable from the main UI. `ConfirmMedicationPage` exists and has widget coverage, but Today medication cards do not navigate to it and notification click handling is not wired.
- Notification scheduling did not produce visible package alarm entries during this smoke test. The app initializes notification permissions at startup, but medication creation currently saves data without calling the reminder rescheduler.

## Notes

- Supabase sync is scaffolded but should be validated against a real Supabase project and authenticated user before production.
- UptimeRobot setup is documented in `docs/operations/supabase-and-uptimerobot.md`.
