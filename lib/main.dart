import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medication_reminder/app.dart';

export 'package:medication_reminder/app.dart' show MedicationReminderApp;

void main() {
  runApp(const ProviderScope(child: MedicationReminderApp()));
}
