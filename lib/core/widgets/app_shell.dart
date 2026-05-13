import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medication_reminder/features/calendar/presentation/calendar_page.dart';
import 'package:medication_reminder/features/medications/presentation/medications_page.dart';
import 'package:medication_reminder/features/today/presentation/today_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _pages = <Widget>[
    TodayPage(),
    CalendarPage(),
    MedicationsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final shell = Scaffold(
      appBar: _index == 2 ? null : AppBar(title: const Text('药记录')),
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) {
          setState(() => _index = value);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today), label: '今日'),
          NavigationDestination(icon: Icon(Icons.calendar_month), label: '日历'),
          NavigationDestination(icon: Icon(Icons.medication), label: '药品'),
        ],
      ),
    );

    try {
      ProviderScope.containerOf(context, listen: false);
      return shell;
    } catch (_) {
      return ProviderScope(child: shell);
    }
  }
}
