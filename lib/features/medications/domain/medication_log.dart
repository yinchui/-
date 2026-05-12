enum MedicationLogStatus { confirmed, missed }

const _unset = Object();

class MedicationLog {
  MedicationLog({
    required this.id,
    required this.medicationId,
    required DateTime scheduledTime,
    required DateTime? confirmedTime,
    required this.status,
    required DateTime date,
  }) : scheduledTime = scheduledTime.toUtc(),
       confirmedTime = confirmedTime?.toUtc(),
       date = DateTime(date.year, date.month, date.day);

  final String id;
  final String medicationId;
  final DateTime scheduledTime;
  final DateTime? confirmedTime;
  final MedicationLogStatus status;
  final DateTime date;

  bool get isConfirmed => status == MedicationLogStatus.confirmed;

  Map<String, Object?> toMap() => {
    'id': id,
    'medication_id': medicationId,
    'scheduled_time': scheduledTime.toIso8601String(),
    'confirmed_time': confirmedTime?.toIso8601String(),
    'status': status.name,
    'date': _formatDate(date),
  };

  factory MedicationLog.fromMap(Map<String, Object?> map) {
    return MedicationLog(
      id: map['id']! as String,
      medicationId: map['medication_id']! as String,
      scheduledTime: DateTime.parse(map['scheduled_time']! as String),
      confirmedTime: map['confirmed_time'] == null
          ? null
          : DateTime.parse(map['confirmed_time']! as String),
      status: MedicationLogStatus.values.byName(map['status']! as String),
      date: DateTime.parse(map['date']! as String),
    );
  }

  MedicationLog copyWith({
    String? id,
    String? medicationId,
    DateTime? scheduledTime,
    Object? confirmedTime = _unset,
    MedicationLogStatus? status,
    DateTime? date,
  }) {
    return MedicationLog(
      id: id ?? this.id,
      medicationId: medicationId ?? this.medicationId,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      confirmedTime: identical(confirmedTime, _unset)
          ? this.confirmedTime
          : confirmedTime as DateTime?,
      status: status ?? this.status,
      date: date ?? this.date,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MedicationLog &&
            id == other.id &&
            medicationId == other.medicationId &&
            scheduledTime == other.scheduledTime &&
            confirmedTime == other.confirmedTime &&
            status == other.status &&
            date == other.date;
  }

  @override
  int get hashCode =>
      Object.hash(id, medicationId, scheduledTime, confirmedTime, status, date);
}

String _formatDate(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
