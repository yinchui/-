import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medication_reminder/core/theme/app_theme.dart';
import 'package:medication_reminder/features/medications/application/medication_providers.dart';

import '../application/save_medication_controller.dart';
import '../domain/medication.dart';

class MedicationFormPage extends ConsumerStatefulWidget {
  const MedicationFormPage({super.key, this.medication});

  final Medication? medication;

  @override
  ConsumerState<MedicationFormPage> createState() => _MedicationFormPageState();
}

class _MedicationFormPageState extends ConsumerState<MedicationFormPage> {
  final _nameController = TextEditingController();
  final _durationController = TextEditingController(text: '7');
  final _scheduleController = TextEditingController();
  final _weeklyDosageControllers = List.generate(
    7,
    (_) => TextEditingController(),
  );
  final _dailyDosageOverrides = <int, String>{};
  DateTime? _startDate;
  var _isSaving = false;
  var _didLoadMedication = false;

  @override
  void initState() {
    super.initState();
    _loadMedicationIfNeeded();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _durationController.dispose();
    _scheduleController.dispose();
    for (final controller in _weeklyDosageControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _loadMedicationIfNeeded();
    final today = ref.watch(todayProvider);
    final startDate = _startDate ?? today;
    final duration = _durationDays;

    return Scaffold(
      backgroundColor: AppColors.warmBackground,
      appBar: AppBar(title: Text(widget.medication == null ? '添加药品' : '编辑药品')),
      body: SafeArea(
        child: ListView(
          key: const ValueKey('medication-form-scroll'),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            _SectionCard(
              title: '基础信息',
              children: [
                TextField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: '药名',
                    hintText: '例如：阿莫西林',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SectionCard(
              title: '疗程',
              children: [
                _DatePickerRow(
                  date: startDate,
                  onPressed: () => _pickStartDate(startDate),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _durationController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(_dailyDosageOverrides.clear),
                  decoration: const InputDecoration(
                    labelText: '服用天数',
                    hintText: '7',
                    suffixText: '天',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _scheduleController,
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(
                    labelText: '服用时间',
                    hintText: '08:00,20:00',
                    helperText: '多个时间用逗号分隔',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SectionCard(
              title: '每周剂量模板',
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (var index = 0; index < _weekdays.length; index++)
                          SizedBox(
                            width: (constraints.maxWidth - 10) / 2,
                            child: TextField(
                              controller: _weeklyDosageControllers[index],
                              textInputAction: TextInputAction.next,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                labelText: '${_weekdays[index]}剂量',
                                hintText: '1片',
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SectionCard(
              title: '逐日计划',
              children: [
                for (var dayIndex = 1; dayIndex <= duration; dayIndex++) ...[
                  _DailyPlanField(
                    key: ValueKey(
                      'daily-$dayIndex-${_dailyDosageOverrides[dayIndex] ?? _templateDosageFor(startDate, dayIndex)}',
                    ),
                    date: startDate.add(Duration(days: dayIndex - 1)),
                    dayIndex: dayIndex,
                    dosage:
                        _dailyDosageOverrides[dayIndex] ??
                        _templateDosageFor(startDate, dayIndex),
                    onChanged: (value) {
                      _dailyDosageOverrides[dayIndex] = value;
                    },
                  ),
                  if (dayIndex != duration) const SizedBox(height: 10),
                ],
              ],
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _isSaving ? null : () => _save(startDate),
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  int get _durationDays {
    final value = int.tryParse(_durationController.text.trim());
    if (value == null || value < 1) {
      return 1;
    }
    if (value > 366) {
      return 366;
    }
    return value;
  }

  Future<void> _pickStartDate(DateTime currentDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _startDate = DateTime(picked.year, picked.month, picked.day);
      _dailyDosageOverrides.clear();
    });
  }

  String _templateDosageFor(DateTime startDate, int dayIndex) {
    final date = startDate.add(Duration(days: dayIndex - 1));
    return _weeklyDosageControllers[date.weekday - 1].text.trim();
  }

  Future<void> _save(DateTime startDate) async {
    setState(() => _isSaving = true);
    try {
      final weeklyDosages = _weeklyDosageControllers
          .map((controller) => controller.text)
          .toList();
      final firstDosage = weeklyDosages[startDate.weekday - 1].trim();

      await ref
          .read(saveMedicationControllerProvider)
          .save(
            name: _nameController.text,
            dosage: firstDosage.isEmpty ? '疗程剂量' : firstDosage,
            scheduleInput: _scheduleController.text,
            startDate: startDate,
            durationDays: int.tryParse(_durationController.text.trim()),
            weeklyDosages: weeklyDosages,
            dailyDosageOverrides: _dailyDosageOverrides,
            existingMedication: widget.medication,
          );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _loadMedicationIfNeeded() {
    if (_didLoadMedication) {
      return;
    }
    _didLoadMedication = true;

    final medication = widget.medication;
    if (medication == null) {
      return;
    }

    _nameController.text = medication.name;
    _scheduleController.text = medication.schedule.join(',');
    if (medication.dailyPlans.isEmpty) {
      _durationController.text = '1';
      for (final controller in _weeklyDosageControllers) {
        controller.text = medication.dosage;
      }
      return;
    }

    _startDate = medication.startDate ?? medication.dailyPlans.first.date;
    _durationController.text =
        (medication.durationDays ?? medication.dailyPlans.length).toString();

    for (final controller in _weeklyDosageControllers) {
      controller.clear();
    }
    for (final plan in medication.dailyPlans) {
      _weeklyDosageControllers[plan.date.weekday - 1].text = plan.dosage;
      _dailyDosageOverrides[plan.dayIndex] = plan.dosage;
    }
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

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
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DatePickerRow extends StatelessWidget {
  const _DatePickerRow({required this.date, required this.onPressed});

  final DateTime date;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.event),
      label: Text('开始日期 ${_formatDate(date)}'),
    );
  }
}

class _DailyPlanField extends StatelessWidget {
  const _DailyPlanField({
    required this.date,
    required this.dayIndex,
    required this.dosage,
    required this.onChanged,
    super.key,
  });

  final DateTime date;
  final int dayIndex;
  final String dosage;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 84,
          child: Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              '第$dayIndex天\n${_formatMonthDay(date)}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.25,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextFormField(
            initialValue: dosage,
            onChanged: onChanged,
            decoration: InputDecoration(
              labelText: '第$dayIndex天剂量',
              hintText: '1片',
              border: const OutlineInputBorder(),
            ),
          ),
        ),
      ],
    );
  }
}

const _weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

String _formatDate(DateTime value) {
  return '${value.year}-${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

String _formatMonthDay(DateTime value) {
  return '${value.month}/${value.day}';
}

String _errorMessage(Object error) {
  if (error is ArgumentError && error.message != null) {
    return error.message.toString();
  }

  return '保存失败，请稍后再试';
}
