# Notification Rescheduling Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Ensure saved medication plans are converted into Android scheduled notifications so the app alerts at dose time.

**Architecture:** Add a repository decorator that reschedules notifications after medication changes, and schedule reminders once during app startup after cloud pull completes. Extend the alarm rescheduler to handle course daily plans so each planned date uses that day's dosage and time list.

**Tech Stack:** Flutter, Riverpod, flutter_local_notifications, sqflite repository layer, Dart unit/widget tests.

---

### Task 1: Course Reminder Scheduling

**Files:**
- Modify: `test/core/notifications/alarm_rescheduler_test.dart`
- Modify: `lib/core/notifications/alarm_rescheduler.dart`

**Step 1: Write the failing test**

Add a test that creates one medication with `dailyPlans` for two different dates and different dosages. Call `AlarmRescheduler.rescheduleAll` from the first day and assert it schedules one notification per future daily plan, with the correct date, dosage, and payload.

**Step 2: Run test to verify it fails**

Run: `flutter test test/core/notifications/alarm_rescheduler_test.dart`

Expected: FAIL because current implementation only schedules `medication.schedule` once and uses `medication.dosage`.

**Step 3: Write minimal implementation**

Change `AlarmRescheduler` so:
- If `medication.dailyPlans` is empty, preserve the existing rolling next-occurrence behavior.
- If `dailyPlans` is not empty, schedule only future planned doses from `dailyPlan.date + dailyPlan.schedule`, using `dailyPlan.dosage`.

**Step 4: Run test to verify it passes**

Run: `flutter test test/core/notifications/alarm_rescheduler_test.dart`

Expected: PASS.

### Task 2: Reschedule After Saves And Deletes

**Files:**
- Create: `lib/core/notifications/rescheduling_medication_repository.dart`
- Create: `test/core/notifications/rescheduling_medication_repository_test.dart`

**Step 1: Write the failing tests**

Add tests that wrap an in-memory repository and fake scheduler:
- `saveMedication` persists the medication and calls `cancelAll` plus schedules the new medication.
- `deleteMedication` removes the medication and reschedules remaining medications.
- Notification failures do not prevent saving medication data.

**Step 2: Run test to verify it fails**

Run: `flutter test test/core/notifications/rescheduling_medication_repository_test.dart`

Expected: FAIL because the repository decorator does not exist yet.

**Step 3: Write minimal implementation**

Create `ReschedulingMedicationRepository` implementing `MedicationRepository`. Delegate all data methods, and after `saveMedication` or `deleteMedication`, fetch all medications and call `AlarmRescheduler.rescheduleAll`.

**Step 4: Run test to verify it passes**

Run: `flutter test test/core/notifications/rescheduling_medication_repository_test.dart`

Expected: PASS.

### Task 3: Wire Startup Scheduling

**Files:**
- Modify: `lib/main.dart`
- Modify: `test/android_manifest_test.dart` or add a small focused main wiring test only if needed.

**Step 1: Implement app wiring**

In `main`, create one `LocalNotificationScheduler`, initialize it, build the repository, wrap it with `ReschedulingMedicationRepository`, and call startup rescheduling after cloud pull.

**Step 2: Verify**

Run:
- `flutter test`
- `flutter analyze`
- `flutter build apk --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`

Expected: all pass and APK is produced.
