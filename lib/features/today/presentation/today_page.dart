import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medication_reminder/core/theme/app_theme.dart';
import 'package:medication_reminder/features/medications/application/medication_providers.dart';
import 'package:medication_reminder/features/medications/domain/medication_dose.dart';
import 'package:medication_reminder/features/today/presentation/widgets/medication_card.dart';
import 'package:medication_reminder/features/today/presentation/widgets/progress_pill.dart';

class TodayPage extends ConsumerWidget {
  const TodayPage({Key? key}) : super(key: key ?? const ValueKey('today-page'));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dosesValue = ref.watch(todayDosesProvider);
    final now = ref.watch(nowProvider);
    final today = ref.watch(todayProvider);
    final currentDoses = switch (dosesValue) {
      AsyncData(:final value) => value,
      _ => const <MedicationDose>[],
    };
    final completedCount = currentDoses
        .where((dose) => dose.status == DoseStatus.confirmed)
        .length;

    return ColoredBox(
      color: AppColors.warmBackground,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            _TodayHeader(
              greeting: _greetingFor(now),
              dateText: _formatDate(today),
              completedCount: completedCount,
              totalCount: currentDoses.length,
            ),
            const SizedBox(height: 22),
            dosesValue.when(
              data: (doses) {
                if (doses.isEmpty) {
                  return const _EmptyState();
                }

                return _DoseGroups(doses: doses);
              },
              loading: () => const _LoadingState(),
              error: (error, stackTrace) => const _ErrorState(),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayHeader extends StatelessWidget {
  const _TodayHeader({
    required this.greeting,
    required this.dateText,
    required this.completedCount,
    required this.totalCount,
  });

  final String greeting;
  final String dateText;
  final int completedCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$dateText · 按时照顾自己',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        ProgressPill(completedCount: completedCount, totalCount: totalCount),
      ],
    );
  }
}

class _DoseGroups extends StatelessWidget {
  const _DoseGroups({required this.doses});

  final List<MedicationDose> doses;

  @override
  Widget build(BuildContext context) {
    final groupedDoses = <String, List<MedicationDose>>{};
    for (final dose in doses) {
      groupedDoses.putIfAbsent(_formatTime(dose.scheduledTime), () => []);
      groupedDoses[_formatTime(dose.scheduledTime)]!.add(dose);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in groupedDoses.entries) ...[
          _TimeGroupLabel(time: entry.key),
          const SizedBox(height: 10),
          for (final dose in entry.value) ...[
            MedicationCard(dose: dose),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 2),
        ],
      ],
    );
  }
}

class _TimeGroupLabel extends StatelessWidget {
  const _TimeGroupLabel({required this.time});

  final String time;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.schedule, size: 17, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            '$time 时段',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 80),
      child: Column(
        children: [
          Icon(Icons.medication_outlined, color: AppColors.textMuted, size: 48),
          SizedBox(height: 14),
          Text(
            '今天还没有添加药品',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
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
      child: Column(
        children: [
          Icon(Icons.error_outline, color: AppColors.red, size: 44),
          SizedBox(height: 14),
          Text(
            '今日药品加载失败',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

String _greetingFor(DateTime value) {
  if (value.hour >= 5 && value.hour < 12) {
    return '早上好';
  }
  if (value.hour >= 12 && value.hour < 18) {
    return '下午好';
  }
  return '晚上好';
}

String _formatDate(DateTime value) {
  const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  return '${value.month}月${value.day}日 ${weekdays[value.weekday - 1]}';
}

String _formatTime(DateTime value) {
  return '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}
