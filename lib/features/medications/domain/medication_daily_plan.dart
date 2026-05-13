class MedicationDailyPlan {
  MedicationDailyPlan({
    required DateTime date,
    required this.dayIndex,
    required this.dosage,
    required List<String> schedule,
  }) : date = DateTime(date.year, date.month, date.day),
       schedule = List.unmodifiable(schedule);

  final DateTime date;
  final int dayIndex;
  final String dosage;
  final List<String> schedule;

  Map<String, Object?> toMap() => {
    'date': _formatDate(date),
    'day_index': dayIndex,
    'dosage': dosage,
    'schedule': schedule,
  };

  factory MedicationDailyPlan.fromMap(Map<String, Object?> map) {
    return MedicationDailyPlan(
      date: DateTime.parse(map['date']! as String),
      dayIndex: map['day_index']! as int,
      dosage: map['dosage']! as String,
      schedule: List<String>.from(map['schedule']! as List),
    );
  }

  MedicationDailyPlan copyWith({
    DateTime? date,
    int? dayIndex,
    String? dosage,
    List<String>? schedule,
  }) {
    return MedicationDailyPlan(
      date: date ?? this.date,
      dayIndex: dayIndex ?? this.dayIndex,
      dosage: dosage ?? this.dosage,
      schedule: schedule ?? this.schedule,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MedicationDailyPlan &&
            date == other.date &&
            dayIndex == other.dayIndex &&
            dosage == other.dosage &&
            _listEquals(schedule, other.schedule);
  }

  @override
  int get hashCode =>
      Object.hash(date, dayIndex, dosage, Object.hashAll(schedule));
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
