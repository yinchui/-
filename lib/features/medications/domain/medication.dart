import 'dart:convert';

class Medication {
  Medication({
    required this.id,
    required this.userId,
    required this.name,
    required this.dosage,
    required List<String> schedule,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : schedule = List.unmodifiable(schedule),
       createdAt = createdAt.toUtc(),
       updatedAt = updatedAt.toUtc();

  final String id;
  final String userId;
  final String name;
  final String dosage;
  final List<String> schedule;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toMap() => {
    'id': id,
    'user_id': userId,
    'name': name,
    'dosage': dosage,
    'schedule': jsonEncode(schedule),
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
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Medication(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      schedule: schedule ?? this.schedule,
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
    createdAt,
    updatedAt,
  );
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
