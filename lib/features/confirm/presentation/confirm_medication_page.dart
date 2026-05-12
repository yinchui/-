import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medication_reminder/core/theme/app_theme.dart';
import 'package:medication_reminder/features/confirm/application/confirm_dose_controller.dart';
import 'package:medication_reminder/features/confirm/presentation/slide_to_confirm.dart';
import 'package:medication_reminder/features/medications/domain/medication_dose.dart';

class ConfirmMedicationPage extends ConsumerStatefulWidget {
  const ConfirmMedicationPage({
    required this.doses,
    this.onConfirmed,
    super.key,
  });

  final List<MedicationDose> doses;
  final VoidCallback? onConfirmed;

  @override
  ConsumerState<ConfirmMedicationPage> createState() =>
      _ConfirmMedicationPageState();
}

class _ConfirmMedicationPageState extends ConsumerState<ConfirmMedicationPage> {
  var _confirmed = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _confirmed,
      child: Scaffold(
        backgroundColor: AppColors.warmBackground,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _confirmed
                  ? const _SuccessContent()
                  : _ConfirmContent(doses: widget.doses, onConfirmed: _confirm),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirm() async {
    try {
      await ref.read(confirmDoseControllerProvider).confirm(widget.doses);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('确认失败，请稍后再试')));
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() => _confirmed = true);
    widget.onConfirmed?.call();
  }
}

class _ConfirmContent extends StatelessWidget {
  const _ConfirmContent({required this.doses, required this.onConfirmed});

  final List<MedicationDose> doses;
  final Future<void> Function() onConfirmed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _ReminderBadge(),
        const SizedBox(height: 24),
        Expanded(
          child: ListView.separated(
            itemCount: doses.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _DoseTile(dose: doses[index]);
            },
          ),
        ),
        const SizedBox(height: 20),
        SlideToConfirm(onConfirmed: onConfirmed),
      ],
    );
  }
}

class _ReminderBadge extends StatelessWidget {
  const _ReminderBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.orangeSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_active, color: AppColors.orange, size: 18),
            SizedBox(width: 8),
            Text(
              '该吃药了',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoseTile extends StatelessWidget {
  const _DoseTile({required this.dose});

  final MedicationDose dose;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: AppColors.orangeSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.medication_liquid,
                color: AppColors.orange,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
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
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    dose.medication.dosage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _formatTime(dose.scheduledTime),
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessContent extends StatelessWidget {
  const _SuccessContent();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 88, color: AppColors.green),
          SizedBox(height: 16),
          Text(
            '已确认',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatTime(DateTime value) {
  return '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}
