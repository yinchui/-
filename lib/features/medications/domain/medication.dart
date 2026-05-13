import 'dart:convert';

import 'medication_daily_plan.dart';

class Medication {
  Medication({
    required this.id,
    required this.userId,
    required this.name,
    required this.dosage,
    required List<String> schedule,
    DateTime? startDate,
    this.durationDays,
    List<MedicationDailyPlan> dailyPlans = const [],
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : schedule = List.unmodifiable(schedule),
       startDate = startDate == null
           ? null
           : DateTime(startDate.year, startDate.month, startDate.day),
       dailyPlans = List.unmodifiable(dailyPlans),
       createdAt = createdAt.toUtc(),
       updatedAt = updatedAt.toUtc();

  final String id;
  final String userId;
  final String name;
  final String dosage;
  final List<String> schedule;
  final DateTime? startDate;
  final int? durationDays;
  final List<MedicationDailyPlan> dailyPlans;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toMap() => {
    'id': id,
    'user_id': userId,
    'name': name,
    'dosage': dosage,
    'schedule': jsonEncode(schedule),
    'start_date': startDate == null ? null : _formatDate(startDate!),
    'duration_days': durationDays,
    'daily_plans': jsonEncode(
      dailyPlans.map((dailyPlan) => dailyPlan.toMap()).toList(),
    ),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory Medication.fromMap(Map<String, Object?> map) {
    return Medication(
      id: map['id']! as String,
      userId: map['user_id']! as String,
      name: map['name']! as String,
      dosage: map['dosage']! as String,
      schedule: List<String>.from(
        jsonDecode(map['schedule']! as String) as List,
      ),
      startDate: map['start_date'] == null
          ? null
          : DateTime.parse(map['start_date']! as String),
      durationDays: map['duration_days'] as int?,
      dailyPlans: _dailyPlansFromMap(map['daily_plans']),
      createdAt: DateTime.parse(map['created_at']! as String),
      updatedAt: DateTime.parse(map['updated_at']! as String),
    );
  }

  Medication copyWith({
    String? id,
    String? userId,
    String? name,
    String? dosage,
    List<String>? schedule,
    DateTime? startDate,
    int? durationDays,
    List<MedicationDailyPlan>? dailyPlans,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Medication(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      schedule: schedule ?? this.schedule,
      startDate: startDate ?? this.startDate,
      durationDays: durationDays ?? this.durationDays,
      dailyPlans: dailyPlans ?? this.dailyPlans,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Medication &&
            id == other.id &&
            userId == other.userId &&
            name == other.name &&
            dosage == other.dosage &&
            _listEquals(schedule, other.schedule) &&
            startDate == other.startDate &&
            durationDays == other.durationDays &&
            _listEquals(dailyPlans, other.dailyPlans) &&
            createdAt == other.createdAt &&
            updatedAt == other.updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    name,
    dosage,
    Object.hashAll(schedule),
    startDate,
    durationDays,
    Object.hashAll(dailyPlans),
    createdAt,
    updatedAt,
  );
}

List<MedicationDailyPlan> _dailyPlansFromMap(Object? value) {
  if (value == null) {
    return const [];
  }

  final decoded = jsonDecode(value as String) as List;
  return decoded
      .map(
        (dailyPlan) =>
            MedicationDailyPlan.fromMap(dailyPlan as Map<String, Object?>),
      )
      .toList();
}

String _formatDate(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

bool _listEquals(List<Object?> a, List<Object?> b) {
  if (a.length != b.length) {
    return false;
  }

  for (var i = 0; i < a.length; i += 1) {
    if (a[i] != b[i]) {
      return false;
    }
  }

  return true;
}
