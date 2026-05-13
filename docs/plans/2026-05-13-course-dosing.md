# Course Dosing Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add course-based medication setup so a user can create a multi-day regimen from a weekly dosage template and then edit individual daily doses.

**Architecture:** Keep SQLite as the source of truth. Extend `Medication` with nullable course metadata and a `dailyPlans` JSON payload while keeping existing fixed-dose medications compatible. Update scheduling so daily plans drive Today/Calendar doses when present, and fall back to legacy `dosage + schedule` when absent.

**Tech Stack:** Flutter, Dart, Riverpod, sqflite, flutter_test.

---

### Task 1: Add Daily Plan Domain Model

**Files:**
- Create: `lib/features/medications/domain/medication_daily_plan.dart`
- Modify: `lib/features/medications/domain/medication.dart`
- Test: `test/features/medications/domain/domain_models_test.dart`

**Step 1: Write failing tests**

Add tests that:
- serialize and deserialize `MedicationDailyPlan`.
- normalize `date` to date-only.
- serialize a `Medication` with `startDate`, `durationDays`, and two daily plans.
- deserialize a legacy medication map that has no course fields.

**Step 2: Run red test**

Run:
```bash
PATH=/Users/aa/.codex/toolchains/flutter/bin:$PATH FLUTTER_SUPPRESS_ANALYTICS=true flutter test test/features/medications/domain/domain_models_test.dart
```

Expected: FAIL because `MedicationDailyPlan` and course fields do not exist.

**Step 3: Implement model**

Create `MedicationDailyPlan` with `date`, `dayIndex`, `dosage`, `schedule`, `toMap`, `fromMap`, equality, and JSON helpers through `Medication`.

Update `Medication` with:
- `DateTime? startDate`
- `int? durationDays`
- `List<MedicationDailyPlan> dailyPlans`

`Medication.fromMap` must default missing `start_date`, `duration_days`, and `daily_plans` to legacy behavior.

**Step 4: Run green test and commit**

Run the domain test again, then commit:
```bash
git add lib/features/medications/domain test/features/medications/domain/domain_models_test.dart
git commit -m "feat: add medication daily plans"
```

### Task 2: Upgrade SQLite Schema And Repository Coverage

**Files:**
- Modify: `lib/core/storage/database_schema.dart`
- Modify: `lib/core/storage/app_database.dart`
- Modify: `lib/features/medications/data/sqlite_medication_repository.dart`
- Test: `test/core/storage/database_schema_test.dart`
- Test: `test/features/medications/data/sqlite_medication_repository_test.dart`

**Step 1: Write failing tests**

Add tests that:
- assert `DatabaseSchema.version == 2`.
- assert `medications` includes `start_date`, `duration_days`, and `daily_plans`.
- open a version 1 database, upgrade it, and verify old rows read with empty daily plans.
- save and read a medication with daily plans through `SqliteMedicationRepository`.

**Step 2: Run red tests**

Run:
```bash
PATH=/Users/aa/.codex/toolchains/flutter/bin:$PATH FLUTTER_SUPPRESS_ANALYTICS=true flutter test test/core/storage/database_schema_test.dart test/features/medications/data/sqlite_medication_repository_test.dart
```

Expected: FAIL because schema version and columns have not changed.

**Step 3: Implement migration**

Set schema version to 2. Add course columns to create SQL. In `AppDatabase`, add `onUpgrade` from version `< 2` with `ALTER TABLE` statements:

- `start_date TEXT`
- `duration_days INTEGER`
- `daily_plans TEXT NOT NULL DEFAULT '[]'`

**Step 4: Run green tests and commit**

Run the two test files again, then commit:
```bash
git add lib/core/storage lib/features/medications/data test/core/storage/database_schema_test.dart test/features/medications/data/sqlite_medication_repository_test.dart
git commit -m "feat: migrate medication course storage"
```

### Task 3: Generate Course Plans In Save Controller

**Files:**
- Modify: `lib/features/medications/application/save_medication_controller.dart`
- Test: `test/features/medications/application/save_medication_controller_test.dart`

**Step 1: Write failing tests**

Add tests that:
- generate seven daily plans from a Monday start date and seven weekday dosages.
- cycle the weekly template over more than seven days.
- allow a per-day dosage override.
- reject duration outside `1..366`.
- reject any generated day whose final dosage is blank.

**Step 2: Run red test**

Run:
```bash
PATH=/Users/aa/.codex/toolchains/flutter/bin:$PATH FLUTTER_SUPPRESS_ANALYTICS=true flutter test test/features/medications/application/save_medication_controller_test.dart
```

Expected: FAIL because the save API has no course inputs.

**Step 3: Implement controller API**

Extend `save` with optional:
- `DateTime? startDate`
- `int? durationDays`
- `List<String>? weeklyDosages`
- `Map<int, String>? dailyDosageOverrides`

When `durationDays` is provided, build `MedicationDailyPlan` entries. Keep the old fixed-dose path for existing tests and old callers.

**Step 4: Run green test and commit**

Run controller tests, then commit:
```bash
git add lib/features/medications/application/save_medication_controller.dart test/features/medications/application/save_medication_controller_test.dart
git commit -m "feat: generate course daily plans"
```

### Task 4: Make Schedule Service Use Daily Plans

**Files:**
- Modify: `lib/features/medications/domain/medication_dose.dart`
- Modify: `lib/features/medications/application/schedule_service.dart`
- Modify: `lib/features/today/presentation/widgets/medication_card.dart`
- Modify: `lib/features/confirm/application/confirm_dose_controller.dart`
- Test: `test/features/medications/application/schedule_service_test.dart`
- Test: `test/features/today/presentation/today_page_test.dart`

**Step 1: Write failing tests**

Add tests that:
- show a course medication only on dates with a matching daily plan.
- use the daily plan dosage in `MedicationDose`.
- keep legacy medication scheduling unchanged.

**Step 2: Run red tests**

Run:
```bash
PATH=/Users/aa/.codex/toolchains/flutter/bin:$PATH FLUTTER_SUPPRESS_ANALYTICS=true flutter test test/features/medications/application/schedule_service_test.dart test/features/today/presentation/today_page_test.dart
```

Expected: FAIL because `MedicationDose` cannot carry per-day dosage.

**Step 3: Implement scheduling**

Add `String get dosage` or `String dosage` to `MedicationDose`. `ScheduleService` should:
- use matching daily plan schedule and dosage when `dailyPlans` is non-empty.
- return no doses when the target date has no daily plan.
- fall back to medication schedule and dosage for legacy medication.

Update UI and confirmation log creation to read `dose.dosage` for display.

**Step 4: Run green tests and commit**

Run the affected tests, then commit:
```bash
git add lib/features/medications/domain/medication_dose.dart lib/features/medications/application/schedule_service.dart lib/features/today/presentation/widgets/medication_card.dart lib/features/confirm/application/confirm_dose_controller.dart test/features/medications/application/schedule_service_test.dart test/features/today/presentation/today_page_test.dart
git commit -m "feat: schedule course daily doses"
```

### Task 5: Redesign Medication Form For Courses

**Files:**
- Modify: `lib/features/medications/presentation/medication_form_page.dart`
- Modify: `lib/features/medications/presentation/medications_page.dart`
- Test: `test/features/medications/presentation/medications_page_test.dart`

**Step 1: Write failing widget test**

Update the medication page test to add a seven-day medication:
- enter name.
- enter daily time.
- set duration to 7.
- fill weekday dosages.
- edit one daily preview dosage.
- save and expect the medication list subtitle to summarize `7天疗程`.

**Step 2: Run red test**

Run:
```bash
PATH=/Users/aa/.codex/toolchains/flutter/bin:$PATH FLUTTER_SUPPRESS_ANALYTICS=true flutter test test/features/medications/presentation/medications_page_test.dart
```

Expected: FAIL because the form has no course controls.

**Step 3: Implement form**

Build a compact mobile-first form:
- `TextField` for drug name.
- read-only date row using `showDatePicker`.
- numeric duration field.
- time input field.
- seven weekday dosage fields in a responsive two-column layout.
- daily preview list that regenerates from the template and supports overrides.

Call the extended save controller with course inputs.

**Step 4: Run green test and commit**

Run the widget test, then commit:
```bash
git add lib/features/medications/presentation test/features/medications/presentation/medications_page_test.dart
git commit -m "feat: add course medication form"
```

### Task 6: Sync Schema And Final Verification

**Files:**
- Create: `supabase/migrations/202605130002_add_course_dosing_fields.sql`
- Modify: `docs/verification/2026-05-13-medication-reminder-app.md`

**Step 1: Add Supabase migration**

Create SQL:
```sql
alter table medications
  add column if not exists start_date date,
  add column if not exists duration_days integer,
  add column if not exists daily_plans jsonb not null default '[]'::jsonb;
```

**Step 2: Run full verification**

Run:
```bash
PATH=/Users/aa/.codex/toolchains/flutter/bin:$PATH FLUTTER_SUPPRESS_ANALYTICS=true dart format .
PATH=/Users/aa/.codex/toolchains/flutter/bin:$PATH FLUTTER_SUPPRESS_ANALYTICS=true flutter test
PATH=/Users/aa/.codex/toolchains/flutter/bin:$PATH FLUTTER_SUPPRESS_ANALYTICS=true flutter analyze
PATH=/Users/aa/.codex/toolchains/flutter/bin:$PATH FLUTTER_SUPPRESS_ANALYTICS=true flutter build apk --release
```

Expected: all commands pass.

**Step 3: Android smoke test**

Install the release APK on the connected device, add a seven-day course, restart the app, and verify Today shows the expected daily dosage.

**Step 4: Commit**

```bash
git add supabase/migrations docs/verification
git commit -m "chore: verify course dosing"
```
