import 'dart:convert';

enum SyncAction { insert, update, delete }

const _unset = Object();

class SyncQueueItem {
  SyncQueueItem({
    required this.id,
    required this.tableName,
    required this.recordId,
    required this.action,
    required Map<String, Object?> payload,
    required DateTime createdAt,
    required this.synced,
  }) : payload = _deepFreezeMap(payload),
       createdAt = createdAt.toUtc();

  final int? id;
  final String tableName;
  final String recordId;
  final SyncAction action;
  final Map<String, Object?> payload;
  final DateTime createdAt;
  final bool synced;

  Map<String, Object?> toMap() => {
    'id': id,
    'table_name': tableName,
    'record_id': recordId,
    'action': action.name,
    'payload': jsonEncode(payload),
    'created_at': createdAt.toIso8601String(),
    'synced': synced ? 1 : 0,
  };

  factory SyncQueueItem.fromMap(Map<String, Object?> map) {
    return SyncQueueItem(
      id: map['id'] as int?,
      tableName: map['table_name']! as String,
      recordId: map['record_id']! as String,
      action: SyncAction.values.byName(map['action']! as String),
      payload: Map<String, Object?>.from(
        jsonDecode(map['payload']! as String) as Map,
      ),
      createdAt: DateTime.parse(map['created_at']! as String),
      synced: (map['synced']! as int) == 1,
    );
  }

  SyncQueueItem copyWith({
    Object? id = _unset,
    String? tableName,
    String? recordId,
    SyncAction? action,
    Map<String, Object?>? payload,
    DateTime? createdAt,
    bool? synced,
  }) {
    return SyncQueueItem(
      id: identical(id, _unset) ? this.id : id as int?,
      tableName: tableName ?? this.tableName,
      recordId: recordId ?? this.recordId,
      action: action ?? this.action,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      synced: synced ?? this.synced,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SyncQueueItem &&
            id == other.id &&
            tableName == other.tableName &&
            recordId == other.recordId &&
            action == other.action &&
            _deepEquals(payload, other.payload) &&
            createdAt == other.createdAt &&
            synced == other.synced;
  }

  @override
  int get hashCode => Object.hash(
    id,
    tableName,
    recordId,
    action,
    _deepHash(payload),
    createdAt,
    synced,
  );
}

bool _deepEquals(Object? a, Object? b) {
  if (identical(a, b)) {
    return true;
  }

  if (a is Map && b is Map) {
    if (a.length != b.length) {
      return false;
    }

    for (final key in a.keys) {
      if (!b.containsKey(key) || !_deepEquals(a[key], b[key])) {
        return false;
      }
    }

    return true;
  }

  if (a is List && b is List) {
    if (a.length != b.length) {
      return false;
    }

    for (var i = 0; i < a.length; i += 1) {
      if (!_deepEquals(a[i], b[i])) {
        return false;
      }
    }

    return true;
  }

  return a == b;
}

int _deepHash(Object? value) {
  if (value is Map) {
    final entries = value.entries.toList()
      ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
    return Object.hashAll(
      entries.map((entry) => Object.hash(entry.key, _deepHash(entry.value))),
    );
  }

  if (value is List) {
    return Object.hashAll(value.map(_deepHash));
  }

  return value.hashCode;
}

Map<String, Object?> _deepFreezeMap(Map source) {
  final frozen = <String, Object?>{};
  for (final entry in source.entries) {
    frozen[entry.key as String] = _deepFreezeValue(entry.value);
  }

  return Map<String, Object?>.unmodifiable(frozen);
}

Object? _deepFreezeValue(Object? value) {
  if (value is Map) {
    return _deepFreezeMap(value);
  }

  if (value is List) {
    return List<Object?>.unmodifiable(value.map(_deepFreezeValue));
  }

  return value;
}
