import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medication_reminder/core/theme/app_theme.dart';
import 'package:medication_reminder/features/calendar/application/calendar_service.dart';
import 'package:medication_reminder/features/medications/application/medication_providers.dart';
import 'package:medication_reminder/features/medications/application/schedule_service.dart';
import 'package:medication_reminder/features/medications/domain/medication.dart';
import 'package:medication_reminder/features/medications/domain/medication_dose.dart';
import 'package:medication_reminder/features/medications/domain/medication_log.dart';

final _calendarServiceProvider = Provider<CalendarService>((ref) {
  return CalendarService();
});

final _scheduleServiceProvider = Provider<ScheduleService>((ref) {
  return ScheduleService();
});

final _calendarMonthDataProvider =
    FutureProvider.family<CalendarMonthData, DateTime>((ref, month) async {
      final repository = ref.watch(medicationRepositoryProvider);
      final service = ref.watch(_calendarServiceProvider);
      final scheduleService = ref.watch(_scheduleServiceProvider);
      final now = ref.watch(nowProvider);
      final visibleMonth = DateTime(month.year, month.month);
      final daysInMonth = DateUtils.getDaysInMonth(
        visibleMonth.year,
        visibleMonth.month,
      );
      final medications = await repository.getMedications();
      final logsByDate = <DateTime, List<MedicationLog>>{};
      final monthLogs = <MedicationLog>[];

      for (var day = 1; day <= daysInMonth; day += 1) {
        final date = DateTime(visibleMonth.year, visibleMonth.month, day);
        final logs = await repository.getLogsForDate(date);
        logsByDate[date] = logs;
        monthLogs.addAll(logs);
      }

      return CalendarMonthData(
        month: visibleMonth,
        logsByDate: logsByDate,
        medications: medications,
        stats: service.summarize(monthLogs),
        service: service,
        scheduleService: scheduleService,
        now: now,
      );
    });

class CalendarMonthData {
  const CalendarMonthData({
    required this.month,
    required this.logsByDate,
    required this.medications,
    required this.stats,
    required this.service,
    required this.scheduleService,
    required this.now,
  });

  final DateTime month;
  final Map<DateTime, List<MedicationLog>> logsByDate;
  final List<Medication> medications;
  final CalendarStats stats;
  final CalendarService service;
  final ScheduleService scheduleService;
  final DateTime now;

  List<MedicationLog> logsForDate(DateTime date) {
    return logsByDate[DateTime(date.year, date.month, date.day)] ?? const [];
  }

  CalendarDayStatus statusForDate(DateTime date) {
    return service.statusForLogs(logsForDate(date));
  }

  List<MedicationDose> dosesForDate(DateTime date) {
    return scheduleService.buildDosesForDate(
      medications: medications,
      logs: logsForDate(date),
      date: date,
      now: now,
    );
  }
}

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({Key? key})
    : super(key: key ?? const ValueKey('calendar-page'));

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  late DateTime _visibleMonth;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final today = ref.read(todayProvider);
    _visibleMonth = DateTime(today.year, today.month);
    _selectedDate = DateTime(today.year, today.month, today.day);
  }

  @override
  Widget build(BuildContext context) {
    final monthDataValue = ref.watch(_calendarMonthDataProvider(_visibleMonth));

    return ColoredBox(
      color: AppColors.warmBackground,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            _CalendarHeader(
              visibleMonth: _visibleMonth,
              onPrevious: () => _moveMonth(-1),
              onNext: () => _moveMonth(1),
            ),
            const SizedBox(height: 16),
            monthDataValue.when(
              data: (monthData) {
                final selectedDoses = monthData.dosesForDate(_selectedDate);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatsRow(stats: monthData.stats),
                    const SizedBox(height: 18),
                    _MonthGrid(
                      month: _visibleMonth,
                      selectedDate: _selectedDate,
                      today: ref.watch(todayProvider),
                      statusForDate: monthData.statusForDate,
                      onSelected: (date) {
                        setState(() => _selectedDate = date);
                      },
                    ),
                    const SizedBox(height: 18),
                    _DayDetails(
                      selectedDate: _selectedDate,
                      doses: selectedDoses,
                    ),
                  ],
                );
              },
              loading: () => const _LoadingState(),
              error: (error, stackTrace) => const _ErrorState(),
            ),
          ],
        ),
      ),
    );
  }

  void _moveMonth(int offset) {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + offset,
      );
      _selectedDate = DateTime(_visibleMonth.year, _visibleMonth.month);
    });
  }
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.visibleMonth,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime visibleMonth;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '${visibleMonth.year}年${visibleMonth.month}月',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        IconButton(
          tooltip: '上个月',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          tooltip: '下个月',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final CalendarStats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatTile(label: '已服', value: '${stats.confirmed}'),
        const SizedBox(width: 10),
        _StatTile(label: '漏服', value: '${stats.missed}'),
        const SizedBox(width: 10),
        _StatTile(label: '服药率', value: _formatRate(stats.rate)),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Column(
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selectedDate,
    required this.today,
    required this.statusForDate,
    required this.onSelected,
  });

  final DateTime month;
  final DateTime selectedDate;
  final DateTime today;
  final CalendarDayStatus Function(DateTime date) statusForDate;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final leading = first.weekday % 7;

    return Column(
      children: [
        const _WeekdayHeader(),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            mainAxisExtent: 42,
          ),
          itemCount: leading + days,
          itemBuilder: (context, index) {
            if (index < leading) {
              return const SizedBox.shrink();
            }

            final day = index - leading + 1;
            final date = DateTime(month.year, month.month, day);
            return _DayCell(
              date: date,
              isSelected: _sameDate(date, selectedDate),
              isToday: _sameDate(date, today),
              status: statusForDate(date),
              onTap: () => onSelected(date),
            );
          },
        ),
      ],
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    const weekdays = ['日', '一', '二', '三', '四', '五', '六'];
    return Row(
      children: [
        for (final weekday in weekdays)
          Expanded(
            child: Center(
              child: Text(
                weekday,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.isSelected,
    required this.isToday,
    required this.status,
    required this.onTap,
  });

  final DateTime date;
  final bool isSelected;
  final bool isToday;
  final CalendarDayStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (status) {
      CalendarDayStatus.confirmed => AppColors.green,
      CalendarDayStatus.missed => AppColors.red,
      CalendarDayStatus.none => Colors.transparent,
    };

    return Material(
      color: isSelected ? AppColors.orangeSoft : AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isToday ? AppColors.orange : AppColors.borderSoft,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                color: isSelected ? AppColors.orange : AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayDetails extends StatelessWidget {
  const _DayDetails({required this.selectedDate, required this.doses});

  final DateTime selectedDate;
  final List<MedicationDose> doses;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${selectedDate.month}月${selectedDate.day}日',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            if (doses.isEmpty)
              const Text(
                '当天还没有服药计划',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              for (final dose in doses) ...[
                _DoseRow(dose: dose),
                if (dose != doses.last) const Divider(height: 18),
              ],
          ],
        ),
      ),
    );
  }
}

class _DoseRow extends StatelessWidget {
  const _DoseRow({required this.dose});

  final MedicationDose dose;

  @override
  Widget build(BuildContext context) {
    final statusText = switch (dose.status) {
      DoseStatus.confirmed => '已服用',
      DoseStatus.missed => '漏服',
      DoseStatus.pending => '计划中',
    };
    final statusColor = switch (dose.status) {
      DoseStatus.confirmed => AppColors.green,
      DoseStatus.missed => AppColors.red,
      DoseStatus.pending => AppColors.orange,
    };
    final statusBackground = switch (dose.status) {
      DoseStatus.confirmed => AppColors.greenSoft,
      DoseStatus.missed => AppColors.redSoft,
      DoseStatus.pending => AppColors.orangeSoft,
    };

    return Row(
      children: [
        Container(
          width: 8,
          height: 36,
          decoration: BoxDecoration(
            color: statusColor,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dose.medication.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                dose.dosage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${_formatTime(dose.scheduledTime.toLocal())} · $statusText',
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: statusBackground,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 80),
      child: Center(child: CircularProgressIndicator(color: AppColors.orange)),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 80),
      child: Text(
        '日历加载失败',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _formatRate(double value) {
  return '${(value * 100).round()}%';
}

String _formatTime(DateTime value) {
  return '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}

bool _sameDate(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}
