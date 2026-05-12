import 'package:flutter/material.dart';
import 'package:medication_reminder/core/theme/app_theme.dart';
import 'package:medication_reminder/features/medications/domain/medication_dose.dart';

class MedicationCard extends StatelessWidget {
  const MedicationCard({super.key, required this.dose});

  final MedicationDose dose;

  @override
  Widget build(BuildContext context) {
    final statusStyle = _statusStyleFor(dose.status);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: statusStyle.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ColoredBox(
                color: statusStyle.accentColor,
                child: const SizedBox(width: 5),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: statusStyle.accentColor.withValues(
                            alpha: 0.14,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          statusStyle.icon,
                          color: statusStyle.accentColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              dose.medication.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  dose.medication.dosage,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  statusStyle.text,
                                  style: TextStyle(
                                    color: statusStyle.accentColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        flex: 0,
                        child: Text(
                          _formatTime(dose.scheduledTime),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

_MedicationCardStatusStyle _statusStyleFor(DoseStatus status) {
  return switch (status) {
    DoseStatus.confirmed => const _MedicationCardStatusStyle(
      accentColor: AppColors.green,
      backgroundColor: AppColors.greenSoft,
      text: '已服用',
      icon: Icons.task_alt,
    ),
    DoseStatus.missed => const _MedicationCardStatusStyle(
      accentColor: AppColors.red,
      backgroundColor: AppColors.redSoft,
      text: '漏服',
      icon: Icons.error_outline,
    ),
    DoseStatus.pending => const _MedicationCardStatusStyle(
      accentColor: AppColors.orange,
      backgroundColor: AppColors.card,
      text: '待服用',
      icon: Icons.medication_liquid,
    ),
  };
}

class _MedicationCardStatusStyle {
  const _MedicationCardStatusStyle({
    required this.accentColor,
    required this.backgroundColor,
    required this.text,
    required this.icon,
  });

  final Color accentColor;
  final Color backgroundColor;
  final String text;
  final IconData icon;
}

String _formatTime(DateTime value) {
  return '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}
