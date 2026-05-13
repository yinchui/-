# Calendar Plans, Medication Editing, App Name Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Let users see future medication plans on the calendar, edit existing medications, and rename the app to 药记录.

**Architecture:** Reuse `ScheduleService` as the single source for planned doses on arbitrary dates. Reuse `MedicationFormPage` for both create and edit flows, preserving the medication id and created time when editing. Keep the Android package id unchanged and only change the visible app label.

**Tech Stack:** Flutter, Dart, Riverpod, flutter_test, Android manifest.

---

### Task 1: Calendar Future Plans

**Files:**
- Modify: `lib/features/calendar/presentation/calendar_page.dart`
- Test: `test/features/calendar/presentation/calendar_page_test.dart`

**Steps:**
1. Write a widget test with a course medication containing a future daily plan.
2. Run the calendar page test and verify it fails because future planned doses are not shown.
3. Use `ScheduleService.buildDosesForDate` for selected day details.
4. Display pending planned doses with time, dose, and `计划中`.
5. Run the calendar page test and commit.

### Task 2: Medication Editing

**Files:**
- Modify: `lib/features/medications/application/save_medication_controller.dart`
- Modify: `lib/features/medications/presentation/medication_form_page.dart`
- Modify: `lib/features/medications/presentation/medications_page.dart`
- Test: `test/features/medications/application/save_medication_controller_test.dart`
- Test: `test/features/medications/presentation/medications_page_test.dart`

**Steps:**
1. Write controller and widget tests for editing an existing course medication.
2. Run tests and verify they fail.
3. Extend save controller with an optional existing medication.
4. Pre-fill the form when editing and add an edit button in the list.
5. Run affected tests and commit.

### Task 3: App Name And Package

**Files:**
- Modify: `lib/app.dart`
- Modify: `lib/core/widgets/app_shell.dart`
- Modify: `android/app/src/main/AndroidManifest.xml`

**Steps:**
1. Change visible app title and Android label to `药记录`.
2. Run format, tests, analyze, and release build.
3. Copy the APK to `/Users/aa/Desktop/yaowan-medication-reminder.apk`.
4. Install on the connected Android device and launch for smoke testing.
