import 'package:flutter/material.dart';
import 'package:medication_reminder/core/theme/app_theme.dart';
import 'package:medication_reminder/core/widgets/app_shell.dart';

class MedicationReminderApp extends StatelessWidget {
  const MedicationReminderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '药记录',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const AppShell(),
    );
  }
}
