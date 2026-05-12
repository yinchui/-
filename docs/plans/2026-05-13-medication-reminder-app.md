# Medication Reminder App Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 构建 Android-first 的 Flutter「药丸」MVP，支持本地离线服药管理、强制滑动确认提醒、日历记录，并预留 Supabase 同步。

**Architecture:** 从当前空仓库创建 Flutter 应用，采用 feature-first 分层：domain 模型、SQLite 数据层、application 服务/状态、presentation 页面。所有用户操作先写 SQLite 并记录 sync_queue，通知调度通过抽象接口包裹，Supabase 同步作为可禁用的后台服务接入。

**Tech Stack:** Flutter、Dart、Material 3、flutter_riverpod、sqflite、path_provider、uuid、intl、timezone、flutter_local_notifications、android_alarm_manager_plus、supabase_flutter、flutter_test。

---

## Context And Scope

**Product spec:** `docs/superpowers/specs/2026-05-12-medication-reminder-app-design.md`

**Visual references from brainstorm:**
- `.superpowers/brainstorm/66272-1778599503/content/home-v2.html`
- `.superpowers/brainstorm/66272-1778599503/content/calendar-page.html`
- `.superpowers/brainstorm/66272-1778599503/content/confirm-page.html`

**Current repository state:** 当前目录不是 git 仓库，且还没有 Flutter 代码。执行计划时先初始化项目和 git，再进入功能任务。

**MVP boundaries:**
- Android 必须可运行；iOS 只保留 Flutter 生成结构和后续扩展空间。
- 本地 SQLite 是主数据源；Supabase 先实现 Auth/Sync 服务骨架、SQL migration 和可手动触发的同步。
- UptimeRobot 不在 app 代码内实现，只在交付文档中记录配置步骤。
- 先不做家庭共享、库存提醒、医生导出、停药/调药记录。

**Execution skills:** 实施时使用 @test-driven-development。全部任务完成前使用 @verification-before-completion。若拆给子任务执行，使用 @subagent-driven-development 或在新会话使用 @executing-plans。

---

### Task 1: Initialize Repository And Flutter Project

**Files:**
- Create: `.gitignore`
- Create: `pubspec.yaml`
- Create: `analysis_options.yaml`
- Create: `lib/main.dart`
- Create: `test/widget_test.dart`
- Modify: generated Flutter project files

**Step 1: Verify toolchain**

Run:
```bash
flutter --version
dart --version
```

Expected: both commands print versions and exit 0. If Flutter is missing, stop and install Flutter before continuing.

**Step 2: Initialize git if needed**

Run:
```bash
git status --short --branch || git init
```

Expected: if the repo was not initialized, output includes `Initialized empty Git repository`.

**Step 3: Scaffold Flutter project**

Run:
```bash
flutter create --project-name medication_reminder --org com.yaowan --platforms=android,ios .
```

Expected: creates `lib/`, `test/`, `android/`, `ios/`, `pubspec.yaml`, `.gitignore`.

**Step 4: Add dependencies**

Run:
```bash
flutter pub add flutter_riverpod go_router sqflite path path_provider uuid intl timezone flutter_local_notifications android_alarm_manager_plus supabase_flutter
flutter pub add --dev flutter_lints mocktail
```

Expected: `pubspec.yaml` and `pubspec.lock` update successfully.

**Step 5: Set analyzer baseline**

Replace `analysis_options.yaml` with:
```yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    prefer_single_quotes: true
    require_trailing_commas: true
```

**Step 6: Write smoke widget test**

Replace `test/widget_test.dart` with:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:medication_reminder/main.dart';

void main() {
  testWidgets('app starts on today page', (tester) async {
    await tester.pumpWidget(const MedicationReminderApp());

    expect(find.text('今日'), findsWidgets);
    expect(find.text('药丸'), findsOneWidget);
  });
}
```

**Step 7: Run test to verify it fails**

Run:
```bash
flutter test test/widget_test.dart
```

Expected: FAIL because `MedicationReminderApp` does not exist or does not render `药丸`.

**Step 8: Create minimal app**

Replace `lib/main.dart` with:
```dart
import 'package:flutter/material.dart';

void main() {
  runApp(const MedicationReminderApp());
}

class MedicationReminderApp extends StatelessWidget {
  const MedicationReminderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '药丸',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('药丸')),
        body: const Center(child: Text('今日')),
      ),
    );
  }
}
```

**Step 9: Run verification**

Run:
```bash
flutter test
flutter analyze
```

Expected: all tests pass; analyzer has no issues.

**Step 10: Commit**

```bash
git add .
git commit -m "chore: scaffold flutter app"
```

Expected: commit succeeds. If git user identity is missing, configure it locally before committing.

---

### Task 2: Add App Theme, Routing, And Shell Navigation

**Files:**
- Create: `lib/app.dart`
- Create: `lib/core/theme/app_theme.dart`
- Create: `lib/core/routing/app_router.dart`
- Create: `lib/core/widgets/app_shell.dart`
- Modify: `lib/main.dart`
- Test: `test/app_shell_test.dart`

**Step 1: Write failing shell navigation test**

Create `test/app_shell_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medication_reminder/app.dart';

void main() {
  testWidgets('bottom navigation switches between main tabs', (tester) async {
    await tester.pumpWidget(const MedicationReminderApp());

    expect(find.text('今日'), findsWidgets);

    await tester.tap(find.byIcon(Icons.calendar_month));
    await tester.pumpAndSettle();
    expect(find.text('日历'), findsWidgets);

    await tester.tap(find.byIcon(Icons.medication));
    await tester.pumpAndSettle();
    expect(find.text('药品'), findsWidgets);
  });
}
```

**Step 2: Run test to verify it fails**

Run:
```bash
flutter test test/app_shell_test.dart
```

Expected: FAIL because `lib/app.dart` does not exist.

**Step 3: Add theme tokens**

Create `lib/core/theme/app_theme.dart`:
```dart
import 'package:flutter/material.dart';

class AppColors {
  static const warmBackground = Color(0xFFFDF6EE);
  static const card = Color(0xFFFFFFFF);
  static const green = Color(0xFF6BBF7A);
  static const greenSoft = Color(0xFFE8F7EB);
  static const orange = Color(0xFFF2994A);
  static const orangeSoft = Color(0xFFFFF0E0);
  static const red = Color(0xFFEF5350);
  static const redSoft = Color(0xFFFFEBEE);
  static const textPrimary = Color(0xFF3D2E1F);
  static const textSecondary = Color(0xFF8B7355);
  static const textMuted = Color(0xFFBBA88A);
  static const borderSoft = Color(0xFFF0E6D8);
}

class AppTheme {
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.orange,
      primary: AppColors.orange,
      secondary: AppColors.green,
      surface: AppColors.card,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.warmBackground,
      fontFamily: 'NotoSansSC',
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.warmBackground,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.card,
        indicatorColor: AppColors.orangeSoft,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
```

**Step 4: Add shell navigation**

Create `lib/core/widgets/app_shell.dart`:
```dart
import 'package:flutter/material.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _pages = <Widget>[
    _PlaceholderPage(title: '今日'),
    _PlaceholderPage(title: '日历'),
    _PlaceholderPage(title: '药品'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today), label: '今日'),
          NavigationDestination(icon: Icon(Icons.calendar_month), label: '日历'),
          NavigationDestination(icon: Icon(Icons.medication), label: '药品'),
        ],
      ),
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Text(title, style: Theme.of(context).textTheme.headlineMedium),
      ),
    );
  }
}
```

Create `lib/app.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:medication_reminder/core/theme/app_theme.dart';
import 'package:medication_reminder/core/widgets/app_shell.dart';

class MedicationReminderApp extends StatelessWidget {
  const MedicationReminderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '药丸',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const AppShell(),
    );
  }
}
```

Replace `lib/main.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:medication_reminder/app.dart';

void main() {
  runApp(const MedicationReminderApp());
}
```

**Step 5: Run verification**

Run:
```bash
flutter test test/app_shell_test.dart
flutter test
flutter analyze
```

Expected: PASS and no analyzer issues.

**Step 6: Commit**

```bash
git add lib test
git commit -m "feat: add app shell navigation"
```

---

### Task 3: Add Domain Models And JSON Serialization

**Files:**
- Create: `lib/features/medications/domain/medication.dart`
- Create: `lib/features/medications/domain/medication_log.dart`
- Create: `lib/features/medications/domain/sync_queue_item.dart`
- Test: `test/features/medications/domain/domain_models_test.dart`

**Step 1: Write failing tests**

Create `test/features/medications/domain/domain_models_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:medication_reminder/features/medications/domain/medication.dart';
import 'package:medication_reminder/features/medications/domain/medication_log.dart';
import 'package:medication_reminder/features/medications/domain/sync_queue_item.dart';

void main() {
  test('Medication serializes schedule as JSON-ready map', () {
    final medication = Medication(
      id: 'm1',
      userId: 'u1',
      name: '阿莫西林',
      dosage: '2粒',
      schedule: const ['08:00', '12:00', '20:00'],
      createdAt: DateTime.utc(2026, 5, 12),
      updatedAt: DateTime.utc(2026, 5, 12, 1),
    );

    final map = medication.toMap();
    expect(map['name'], '阿莫西林');
    expect(map['schedule'], '["08:00","12:00","20:00"]');

    expect(Medication.fromMap(map), medication);
  });

  test('MedicationLog detects confirmed state', () {
    final log = MedicationLog(
      id: 'l1',
      medicationId: 'm1',
      scheduledTime: DateTime.utc(2026, 5, 12, 8),
      confirmedTime: DateTime.utc(2026, 5, 12, 8, 3),
      status: MedicationLogStatus.confirmed,
      date: DateTime(2026, 5, 12),
    );

    expect(log.isConfirmed, isTrue);
    expect(MedicationLog.fromMap(log.toMap()), log);
  });

  test('SyncQueueItem serializes action and payload', () {
    final item = SyncQueueItem(
      id: 7,
      tableName: 'medications',
      recordId: 'm1',
      action: SyncAction.insert,
      payload: const {'name': '维生素 D'},
      createdAt: DateTime.utc(2026, 5, 12),
      synced: false,
    );

    final map = item.toMap();
    expect(map['action'], 'insert');
    expect(map['synced'], 0);
    expect(SyncQueueItem.fromMap(map), item);
  });
}
```

**Step 2: Run test to verify it fails**

Run:
```bash
flutter test test/features/medications/domain/domain_models_test.dart
```

Expected: FAIL because domain files do not exist.

**Step 3: Implement models**

Create `lib/features/medications/domain/medication.dart`:
```dart
import 'dart:convert';

class Medication {
  const Medication({
    required this.id,
    required this.userId,
    required this.name,
    required this.dosage,
    required this.schedule,
    required this.createdAt,
    required this.updatedAt,
  });

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
      schedule: (jsonDecode(map['schedule']! as String) as List)
          .map((value) => value as String)
          .toList(),
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
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Medication &&
          id == other.id &&
          userId == other.userId &&
          name == other.name &&
          dosage == other.dosage &&
          _listEquals(schedule, other.schedule) &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

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
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i += 1) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
```

Create `lib/features/medications/domain/medication_log.dart`:
```dart
enum MedicationLogStatus { confirmed, missed }

class MedicationLog {
  const MedicationLog({
    required this.id,
    required this.medicationId,
    required this.scheduledTime,
    required this.confirmedTime,
    required this.status,
    required this.date,
  });

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
        'date': _dateOnly(date),
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MedicationLog &&
          id == other.id &&
          medicationId == other.medicationId &&
          scheduledTime == other.scheduledTime &&
          confirmedTime == other.confirmedTime &&
          status == other.status &&
          date == other.date;

  @override
  int get hashCode => Object.hash(
        id,
        medicationId,
        scheduledTime,
        confirmedTime,
        status,
        date,
      );
}

String _dateOnly(DateTime value) {
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}
```

Create `lib/features/medications/domain/sync_queue_item.dart`:
```dart
import 'dart:convert';

enum SyncAction { insert, update, delete }

class SyncQueueItem {
  const SyncQueueItem({
    required this.id,
    required this.tableName,
    required this.recordId,
    required this.action,
    required this.payload,
    required this.createdAt,
    required this.synced,
  });

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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncQueueItem &&
          id == other.id &&
          tableName == other.tableName &&
          recordId == other.recordId &&
          action == other.action &&
          _mapEquals(payload, other.payload) &&
          createdAt == other.createdAt &&
          synced == other.synced;

  @override
  int get hashCode => Object.hash(
        id,
        tableName,
        recordId,
        action,
        Object.hashAll(payload.entries.map((entry) => Object.hash(entry.key, entry.value))),
        createdAt,
        synced,
      );
}

bool _mapEquals(Map<String, Object?> a, Map<String, Object?> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}
```

**Step 4: Run verification**

Run:
```bash
dart format lib/features/medications/domain test/features/medications/domain
flutter test test/features/medications/domain/domain_models_test.dart
flutter analyze
```

Expected: PASS and no analyzer issues.

**Step 5: Commit**

```bash
git add lib/features/medications/domain test/features/medications/domain
git commit -m "feat: add medication domain models"
```

---

### Task 4: Add SQLite Schema And Database Access

**Files:**
- Create: `lib/core/storage/database_schema.dart`
- Create: `lib/core/storage/app_database.dart`
- Test: `test/core/storage/database_schema_test.dart`

**Step 1: Write failing schema test**

Create `test/core/storage/database_schema_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:medication_reminder/core/storage/database_schema.dart';

void main() {
  test('schema creates all required tables', () {
    expect(DatabaseSchema.createStatements, contains(contains('medications')));
    expect(DatabaseSchema.createStatements, contains(contains('medication_logs')));
    expect(DatabaseSchema.createStatements, contains(contains('sync_queue')));
    expect(DatabaseSchema.version, 1);
  });
}
```

**Step 2: Run test to verify it fails**

Run:
```bash
flutter test test/core/storage/database_schema_test.dart
```

Expected: FAIL because storage files do not exist.

**Step 3: Implement schema**

Create `lib/core/storage/database_schema.dart`:
```dart
class DatabaseSchema {
  static const version = 1;

  static const createStatements = [
    '''
    CREATE TABLE medications (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      name TEXT NOT NULL,
      dosage TEXT NOT NULL,
      schedule TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE medication_logs (
      id TEXT PRIMARY KEY,
      medication_id TEXT NOT NULL,
      scheduled_time TEXT NOT NULL,
      confirmed_time TEXT,
      status TEXT NOT NULL CHECK(status IN ('confirmed', 'missed')),
      date TEXT NOT NULL,
      FOREIGN KEY(medication_id) REFERENCES medications(id) ON DELETE CASCADE
    )
    ''',
    '''
    CREATE TABLE sync_queue (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      table_name TEXT NOT NULL,
      record_id TEXT NOT NULL,
      action TEXT NOT NULL CHECK(action IN ('insert', 'update', 'delete')),
      payload TEXT NOT NULL,
      created_at TEXT NOT NULL,
      synced INTEGER NOT NULL DEFAULT 0
    )
    ''',
    'CREATE INDEX idx_medication_logs_date ON medication_logs(date)',
    'CREATE INDEX idx_sync_queue_unsynced ON sync_queue(synced, created_at)',
  ];
}
```

Create `lib/core/storage/app_database.dart`:
```dart
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:medication_reminder/core/storage/database_schema.dart';

class AppDatabase {
  AppDatabase({Database? database}) : _database = database;

  Database? _database;

  Future<Database> get instance async {
    if (_database != null) return _database!;

    final directory = await getApplicationDocumentsDirectory();
    final path = p.join(directory.path, 'medication_reminder.sqlite');
    _database = await openDatabase(
      path,
      version: DatabaseSchema.version,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        for (final statement in DatabaseSchema.createStatements) {
          await db.execute(statement);
        }
      },
    );
    return _database!;
  }

  Future<void> close() async {
    final db = _database;
    _database = null;
    await db?.close();
  }
}
```

**Step 4: Run verification**

Run:
```bash
dart format lib/core/storage test/core/storage
flutter test test/core/storage/database_schema_test.dart
flutter analyze
```

Expected: PASS and no analyzer issues.

**Step 5: Commit**

```bash
git add lib/core/storage test/core/storage
git commit -m "feat: add sqlite schema"
```

---

### Task 5: Implement Medication Repository With Sync Queue Writes

**Files:**
- Create: `lib/features/medications/data/medication_repository.dart`
- Create: `lib/features/medications/data/sqlite_medication_repository.dart`
- Create: `test/helpers/fake_database.dart`
- Test: `test/features/medications/data/sqlite_medication_repository_test.dart`

**Step 1: Write failing repository test**

Create `test/features/medications/data/sqlite_medication_repository_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:medication_reminder/core/storage/database_schema.dart';
import 'package:medication_reminder/features/medications/data/sqlite_medication_repository.dart';
import 'package:medication_reminder/features/medications/domain/medication.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late SqliteMedicationRepository repository;

  setUp(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    db = await openDatabase(inMemoryDatabasePath, version: 1, onCreate: (db, _) async {
      for (final statement in DatabaseSchema.createStatements) {
        await db.execute(statement);
      }
    });
    repository = SqliteMedicationRepository(database: db);
  });

  tearDown(() async => db.close());

  test('upsert medication persists row and enqueues sync item', () async {
    final medication = Medication(
      id: 'm1',
      userId: 'u1',
      name: '阿莫西林',
      dosage: '2粒',
      schedule: const ['08:00', '20:00'],
      createdAt: DateTime.utc(2026, 5, 12),
      updatedAt: DateTime.utc(2026, 5, 12),
    );

    await repository.saveMedication(medication);

    expect(await repository.watchMedications().first, [medication]);
    final queued = await db.query('sync_queue');
    expect(queued.single['table_name'], 'medications');
    expect(queued.single['action'], 'insert');
  });

  test('delete medication removes row and queues delete', () async {
    final medication = Medication(
      id: 'm1',
      userId: 'u1',
      name: '维生素 D',
      dosage: '1片',
      schedule: const ['08:00'],
      createdAt: DateTime.utc(2026, 5, 12),
      updatedAt: DateTime.utc(2026, 5, 12),
    );

    await repository.saveMedication(medication);
    await repository.deleteMedication('m1');

    expect(await repository.watchMedications().first, isEmpty);
    final queued = await db.query('sync_queue', orderBy: 'id DESC');
    expect(queued.first['action'], 'delete');
  });
}
```

**Step 2: Add test dependency and run failure**

Run:
```bash
flutter pub add --dev sqflite_common_ffi
flutter test test/features/medications/data/sqlite_medication_repository_test.dart
```

Expected: FAIL because repository files do not exist.

**Step 3: Implement repository contract**

Create `lib/features/medications/data/medication_repository.dart`:
```dart
import 'package:medication_reminder/features/medications/domain/medication.dart';
import 'package:medication_reminder/features/medications/domain/medication_log.dart';

abstract class MedicationRepository {
  Stream<List<Medication>> watchMedications();
  Future<List<Medication>> getMedications();
  Future<void> saveMedication(Medication medication);
  Future<void> deleteMedication(String medicationId);
  Future<List<MedicationLog>> getLogsForDate(DateTime date);
  Future<void> saveLog(MedicationLog log);
}
```

Create `lib/features/medications/data/sqlite_medication_repository.dart`:
```dart
import 'dart:async';

import 'package:medication_reminder/features/medications/data/medication_repository.dart';
import 'package:medication_reminder/features/medications/domain/medication.dart';
import 'package:medication_reminder/features/medications/domain/medication_log.dart';
import 'package:medication_reminder/features/medications/domain/sync_queue_item.dart';
import 'package:sqflite/sqflite.dart';

class SqliteMedicationRepository implements MedicationRepository {
  SqliteMedicationRepository({required Database database}) : _database = database;

  final Database _database;
  final _medicationController = StreamController<List<Medication>>.broadcast();

  @override
  Stream<List<Medication>> watchMedications() async* {
    yield await getMedications();
    yield* _medicationController.stream;
  }

  @override
  Future<List<Medication>> getMedications() async {
    final rows = await _database.query('medications', orderBy: 'name COLLATE NOCASE');
    return rows.map(Medication.fromMap).toList();
  }

  @override
  Future<void> saveMedication(Medication medication) async {
    final existing = await _database.query(
      'medications',
      where: 'id = ?',
      whereArgs: [medication.id],
      limit: 1,
    );
    final action = existing.isEmpty ? SyncAction.insert : SyncAction.update;

    await _database.transaction((txn) async {
      await txn.insert(
        'medications',
        medication.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await _enqueue(txn, 'medications', medication.id, action, medication.toMap());
    });
    _medicationController.add(await getMedications());
  }

  @override
  Future<void> deleteMedication(String medicationId) async {
    await _database.transaction((txn) async {
      await txn.delete('medications', where: 'id = ?', whereArgs: [medicationId]);
      await _enqueue(txn, 'medications', medicationId, SyncAction.delete, {
        'id': medicationId,
      });
    });
    _medicationController.add(await getMedications());
  }

  @override
  Future<List<MedicationLog>> getLogsForDate(DateTime date) async {
    final dateText = _dateOnly(date);
    final rows = await _database.query(
      'medication_logs',
      where: 'date = ?',
      whereArgs: [dateText],
      orderBy: 'scheduled_time ASC',
    );
    return rows.map(MedicationLog.fromMap).toList();
  }

  @override
  Future<void> saveLog(MedicationLog log) async {
    await _database.transaction((txn) async {
      await txn.insert(
        'medication_logs',
        log.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await _enqueue(txn, 'medication_logs', log.id, SyncAction.insert, log.toMap());
    });
  }

  Future<void> _enqueue(
    Transaction txn,
    String tableName,
    String recordId,
    SyncAction action,
    Map<String, Object?> payload,
  ) {
    final item = SyncQueueItem(
      id: null,
      tableName: tableName,
      recordId: recordId,
      action: action,
      payload: payload,
      createdAt: DateTime.now().toUtc(),
      synced: false,
    );
    return txn.insert('sync_queue', item.toMap());
  }
}

String _dateOnly(DateTime value) {
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}
```

**Step 4: Run verification**

Run:
```bash
dart format lib/features/medications/data test/features/medications/data
flutter test test/features/medications/data/sqlite_medication_repository_test.dart
flutter analyze
```

Expected: PASS and no analyzer issues.

**Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/features/medications/data test/features/medications/data
git commit -m "feat: persist medications with sync queue"
```

---

### Task 6: Add Schedule Expansion And Daily Dose State

**Files:**
- Create: `lib/features/medications/domain/medication_dose.dart`
- Create: `lib/features/medications/application/schedule_service.dart`
- Test: `test/features/medications/application/schedule_service_test.dart`

**Step 1: Write failing tests**

Create `test/features/medications/application/schedule_service_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:medication_reminder/features/medications/application/schedule_service.dart';
import 'package:medication_reminder/features/medications/domain/medication.dart';
import 'package:medication_reminder/features/medications/domain/medication_log.dart';

void main() {
  test('builds doses by combining medications and logs', () {
    final med = Medication(
      id: 'm1',
      userId: 'u1',
      name: '阿莫西林',
      dosage: '2粒',
      schedule: const ['08:00', '20:00'],
      createdAt: DateTime.utc(2026, 5, 12),
      updatedAt: DateTime.utc(2026, 5, 12),
    );
    final logs = [
      MedicationLog(
        id: 'l1',
        medicationId: 'm1',
        scheduledTime: DateTime(2026, 5, 12, 8),
        confirmedTime: DateTime(2026, 5, 12, 8, 3),
        status: MedicationLogStatus.confirmed,
        date: DateTime(2026, 5, 12),
      ),
    ];

    final doses = ScheduleService().buildDosesForDate(
      medications: [med],
      logs: logs,
      date: DateTime(2026, 5, 12),
      now: DateTime(2026, 5, 12, 9),
    );

    expect(doses.length, 2);
    expect(doses.first.status.name, 'confirmed');
    expect(doses.last.status.name, 'pending');
  });
}
```

**Step 2: Run test to verify it fails**

Run:
```bash
flutter test test/features/medications/application/schedule_service_test.dart
```

Expected: FAIL because schedule service does not exist.

**Step 3: Implement dose model**

Create `lib/features/medications/domain/medication_dose.dart`:
```dart
import 'package:medication_reminder/features/medications/domain/medication.dart';
import 'package:medication_reminder/features/medications/domain/medication_log.dart';

enum DoseStatus { confirmed, missed, pending }

class MedicationDose {
  const MedicationDose({
    required this.medication,
    required this.scheduledTime,
    required this.status,
    required this.log,
  });

  final Medication medication;
  final DateTime scheduledTime;
  final DoseStatus status;
  final MedicationLog? log;

  String get id => '${medication.id}-${scheduledTime.toIso8601String()}';
}
```

**Step 4: Implement schedule service**

Create `lib/features/medications/application/schedule_service.dart`:
```dart
import 'package:medication_reminder/features/medications/domain/medication.dart';
import 'package:medication_reminder/features/medications/domain/medication_dose.dart';
import 'package:medication_reminder/features/medications/domain/medication_log.dart';

class ScheduleService {
  List<MedicationDose> buildDosesForDate({
    required List<Medication> medications,
    required List<MedicationLog> logs,
    required DateTime date,
    required DateTime now,
  }) {
    final doses = <MedicationDose>[];

    for (final medication in medications) {
      for (final time in medication.schedule) {
        final scheduledTime = _combine(date, time);
        final log = _findLog(
          logs: logs,
          medicationId: medication.id,
          scheduledTime: scheduledTime,
        );

        doses.add(
          MedicationDose(
            medication: medication,
            scheduledTime: scheduledTime,
            status: _statusFor(log: log, scheduledTime: scheduledTime, now: now),
            log: log,
          ),
        );
      }
    }

    doses.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    return doses;
  }

  DoseStatus _statusFor({
    required MedicationLog? log,
    required DateTime scheduledTime,
    required DateTime now,
  }) {
    if (log?.status == MedicationLogStatus.confirmed) return DoseStatus.confirmed;
    if (log?.status == MedicationLogStatus.missed) return DoseStatus.missed;
    return DoseStatus.pending;
  }

  DateTime _combine(DateTime date, String hhmm) {
    final parts = hhmm.split(':').map(int.parse).toList();
    return DateTime(date.year, date.month, date.day, parts[0], parts[1]);
  }

  MedicationLog? _findLog({
    required List<MedicationLog> logs,
    required String medicationId,
    required DateTime scheduledTime,
  }) {
    for (final log in logs) {
      if (log.medicationId == medicationId &&
          log.scheduledTime.isAtSameMomentAs(scheduledTime)) {
        return log;
      }
    }
    return null;
  }
}
```

**Step 5: Run verification**

Run:
```bash
dart format lib/features/medications/application lib/features/medications/domain test/features/medications/application
flutter test test/features/medications/application/schedule_service_test.dart
flutter analyze
```

Expected: PASS and no analyzer issues.

**Step 6: Commit**

```bash
git add lib/features/medications/application lib/features/medications/domain test/features/medications/application
git commit -m "feat: build daily medication doses"
```

---

### Task 7: Add Riverpod Providers And In-Memory Repository For UI Tests

**Files:**
- Create: `lib/features/medications/data/in_memory_medication_repository.dart`
- Create: `lib/features/medications/application/medication_providers.dart`
- Test: `test/features/medications/application/medication_providers_test.dart`

**Step 1: Write failing provider test**

Create `test/features/medications/application/medication_providers_test.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medication_reminder/features/medications/application/medication_providers.dart';
import 'package:medication_reminder/features/medications/data/in_memory_medication_repository.dart';
import 'package:medication_reminder/features/medications/data/medication_repository.dart';
import 'package:medication_reminder/features/medications/domain/medication.dart';

void main() {
  test('today doses provider exposes saved medications', () async {
    final repository = InMemoryMedicationRepository();
    await repository.saveMedication(
      Medication(
        id: 'm1',
        userId: 'local',
        name: '维生素 D',
        dosage: '1片',
        schedule: const ['08:00'],
        createdAt: DateTime(2026, 5, 12),
        updatedAt: DateTime(2026, 5, 12),
      ),
    );

    final container = ProviderContainer(
      overrides: [
        medicationRepositoryProvider.overrideWithValue(repository),
        todayProvider.overrideWithValue(DateTime(2026, 5, 12)),
        nowProvider.overrideWithValue(DateTime(2026, 5, 12, 7)),
      ],
    );
    addTearDown(container.dispose);

    final doses = await container.read(todayDosesProvider.future);
    expect(doses.single.medication.name, '维生素 D');
  });
}
```

**Step 2: Run test to verify it fails**

Run:
```bash
flutter test test/features/medications/application/medication_providers_test.dart
```

Expected: FAIL because providers do not exist.

**Step 3: Implement in-memory repository**

Create `lib/features/medications/data/in_memory_medication_repository.dart`:
```dart
import 'dart:async';

import 'package:medication_reminder/features/medications/data/medication_repository.dart';
import 'package:medication_reminder/features/medications/domain/medication.dart';
import 'package:medication_reminder/features/medications/domain/medication_log.dart';

class InMemoryMedicationRepository implements MedicationRepository {
  final _medications = <String, Medication>{};
  final _logs = <String, MedicationLog>{};
  final _controller = StreamController<List<Medication>>.broadcast();

  @override
  Stream<List<Medication>> watchMedications() async* {
    yield await getMedications();
    yield* _controller.stream;
  }

  @override
  Future<List<Medication>> getMedications() async {
    final values = _medications.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return values;
  }

  @override
  Future<void> saveMedication(Medication medication) async {
    _medications[medication.id] = medication;
    _controller.add(await getMedications());
  }

  @override
  Future<void> deleteMedication(String medicationId) async {
    _medications.remove(medicationId);
    _controller.add(await getMedications());
  }

  @override
  Future<List<MedicationLog>> getLogsForDate(DateTime date) async {
    return _logs.values.where((log) {
      return log.date.year == date.year &&
          log.date.month == date.month &&
          log.date.day == date.day;
    }).toList();
  }

  @override
  Future<void> saveLog(MedicationLog log) async {
    _logs[log.id] = log;
  }
}
```

**Step 4: Implement providers**

Create `lib/features/medications/application/medication_providers.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medication_reminder/features/medications/application/schedule_service.dart';
import 'package:medication_reminder/features/medications/data/in_memory_medication_repository.dart';
import 'package:medication_reminder/features/medications/data/medication_repository.dart';
import 'package:medication_reminder/features/medications/domain/medication.dart';
import 'package:medication_reminder/features/medications/domain/medication_dose.dart';

final medicationRepositoryProvider = Provider<MedicationRepository>((ref) {
  return InMemoryMedicationRepository();
});

final scheduleServiceProvider = Provider((ref) => ScheduleService());

final todayProvider = Provider<DateTime>((ref) => DateTime.now());
final nowProvider = Provider<DateTime>((ref) => DateTime.now());

final medicationsProvider = StreamProvider<List<Medication>>((ref) {
  return ref.watch(medicationRepositoryProvider).watchMedications();
});

final todayDosesProvider = FutureProvider<List<MedicationDose>>((ref) async {
  final medications = await ref.watch(medicationsProvider.future);
  final today = ref.watch(todayProvider);
  final logs = await ref.watch(medicationRepositoryProvider).getLogsForDate(today);
  return ref.watch(scheduleServiceProvider).buildDosesForDate(
        medications: medications,
        logs: logs,
        date: today,
        now: ref.watch(nowProvider),
      );
});
```

**Step 5: Run verification**

Run:
```bash
dart format lib/features/medications test/features/medications
flutter test test/features/medications/application/medication_providers_test.dart
flutter analyze
```

Expected: PASS and no analyzer issues.

**Step 6: Commit**

```bash
git add lib/features/medications test/features/medications
git commit -m "feat: add medication state providers"
```

---

### Task 8: Build Today Page

**Files:**
- Create: `lib/features/today/presentation/today_page.dart`
- Create: `lib/features/today/presentation/widgets/medication_card.dart`
- Create: `lib/features/today/presentation/widgets/progress_pill.dart`
- Modify: `lib/core/widgets/app_shell.dart`
- Test: `test/features/today/presentation/today_page_test.dart`

**Step 1: Write failing widget test**

Create `test/features/today/presentation/today_page_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medication_reminder/features/medications/application/medication_providers.dart';
import 'package:medication_reminder/features/medications/data/in_memory_medication_repository.dart';
import 'package:medication_reminder/features/medications/domain/medication.dart';
import 'package:medication_reminder/features/today/presentation/today_page.dart';

void main() {
  testWidgets('today page groups medications by time and shows progress', (tester) async {
    final repository = InMemoryMedicationRepository();
    await repository.saveMedication(
      Medication(
        id: 'm1',
        userId: 'local',
        name: '阿莫西林',
        dosage: '2粒',
        schedule: const ['08:00', '20:00'],
        createdAt: DateTime(2026, 5, 12),
        updatedAt: DateTime(2026, 5, 12),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          medicationRepositoryProvider.overrideWithValue(repository),
          todayProvider.overrideWithValue(DateTime(2026, 5, 12)),
          nowProvider.overrideWithValue(DateTime(2026, 5, 12, 7)),
        ],
        child: const MaterialApp(home: TodayPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('早上好'), findsOneWidget);
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('20:00'), findsOneWidget);
    expect(find.text('阿莫西林'), findsNWidgets(2));
  });
}
```

**Step 2: Run test to verify it fails**

Run:
```bash
flutter test test/features/today/presentation/today_page_test.dart
```

Expected: FAIL because `TodayPage` does not exist.

**Step 3: Implement UI widgets**

Create `lib/features/today/presentation/widgets/progress_pill.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:medication_reminder/core/theme/app_theme.dart';

class ProgressPill extends StatelessWidget {
  const ProgressPill({
    required this.confirmed,
    required this.total,
    super.key,
  });

  final int confirmed;
  final int total;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          total == 0 ? '今天还没有服药安排' : '已完成 $confirmed / $total',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
```

Create `lib/features/today/presentation/widgets/medication_card.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:medication_reminder/core/theme/app_theme.dart';
import 'package:medication_reminder/features/medications/domain/medication_dose.dart';

class MedicationCard extends StatelessWidget {
  const MedicationCard({required this.dose, super.key});

  final MedicationDose dose;

  @override
  Widget build(BuildContext context) {
    final confirmed = dose.status == DoseStatus.confirmed;
    return Container(
      decoration: BoxDecoration(
        color: confirmed ? AppColors.greenSoft : AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: confirmed ? null : Border.all(color: AppColors.borderSoft, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(width: 4, color: confirmed ? AppColors.green : AppColors.orange),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Icon(
                      Icons.medication_liquid,
                      color: confirmed ? AppColors.green : AppColors.orange,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dose.medication.name,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${dose.medication.dosage} · ${confirmed ? '已服用' : '待服用'}',
                            style: TextStyle(
                              color: confirmed ? AppColors.green : AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _timeText(dose.scheduledTime),
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeText(DateTime value) {
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }
}
```

**Step 4: Implement TodayPage**

Create `lib/features/today/presentation/today_page.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medication_reminder/core/theme/app_theme.dart';
import 'package:medication_reminder/features/medications/application/medication_providers.dart';
import 'package:medication_reminder/features/medications/domain/medication_dose.dart';
import 'package:medication_reminder/features/today/presentation/widgets/medication_card.dart';
import 'package:medication_reminder/features/today/presentation/widgets/progress_pill.dart';

class TodayPage extends ConsumerWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doses = ref.watch(todayDosesProvider);
    return SafeArea(
      child: doses.when(
        data: (items) => _TodayContent(doses: items),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('加载失败：$error')),
      ),
    );
  }
}

class _TodayContent extends StatelessWidget {
  const _TodayContent({required this.doses});

  final List<MedicationDose> doses;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<MedicationDose>>{};
    for (final dose in doses) {
      grouped.putIfAbsent(_timeText(dose.scheduledTime), () => []).add(dose);
    }
    final confirmed = doses.where((dose) => dose.status == DoseStatus.confirmed).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 96),
      children: [
        const Text(
          '早上好',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        const Text('今天也稳稳照顾自己', style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 14),
        ProgressPill(confirmed: confirmed, total: doses.length),
        const SizedBox(height: 28),
        if (grouped.isEmpty)
          const Text('今天还没有添加药品', style: TextStyle(color: AppColors.textSecondary)),
        for (final entry in grouped.entries) ...[
          _TimeSectionHeader(time: entry.key),
          const SizedBox(height: 10),
          for (final dose in entry.value) ...[
            MedicationCard(dose: dose),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  String _timeText(DateTime value) {
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }
}

class _TimeSectionHeader extends StatelessWidget {
  const _TimeSectionHeader({required this.time});

  final String time;

  @override
  Widget build(BuildContext context) {
    return Text(
      time,
      style: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );
  }
}
```

Modify `lib/core/widgets/app_shell.dart` to import `TodayPage` and replace the first placeholder:
```dart
import 'package:medication_reminder/features/today/presentation/today_page.dart';

static const _pages = <Widget>[
  TodayPage(),
  _PlaceholderPage(title: '日历'),
  _PlaceholderPage(title: '药品'),
];
```

**Step 5: Run verification**

Run:
```bash
dart format lib/features/today lib/core/widgets test/features/today
flutter test test/features/today/presentation/today_page_test.dart
flutter test
flutter analyze
```

Expected: PASS and no analyzer issues.

**Step 6: Commit**

```bash
git add lib/features/today lib/core/widgets test/features/today
git commit -m "feat: build today medication page"
```

---

### Task 9: Build Medication Management Page And Form

**Files:**
- Create: `lib/features/medications/presentation/medications_page.dart`
- Create: `lib/features/medications/presentation/medication_form_page.dart`
- Create: `lib/features/medications/application/save_medication_controller.dart`
- Modify: `lib/core/widgets/app_shell.dart`
- Test: `test/features/medications/presentation/medications_page_test.dart`

**Step 1: Write failing widget test**

Create `test/features/medications/presentation/medications_page_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medication_reminder/features/medications/application/medication_providers.dart';
import 'package:medication_reminder/features/medications/data/in_memory_medication_repository.dart';
import 'package:medication_reminder/features/medications/presentation/medications_page.dart';

void main() {
  testWidgets('adds a medication from form', (tester) async {
    final repository = InMemoryMedicationRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [medicationRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: MedicationsPage()),
      ),
    );

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.bySemanticsLabel('药名'), '维生素 D');
    await tester.enterText(find.bySemanticsLabel('剂量'), '1片');
    await tester.enterText(find.bySemanticsLabel('服用时间'), '08:00,20:00');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('维生素 D'), findsOneWidget);
    expect(find.text('1片 · 08:00, 20:00'), findsOneWidget);
  });
}
```

**Step 2: Run test to verify it fails**

Run:
```bash
flutter test test/features/medications/presentation/medications_page_test.dart
```

Expected: FAIL because `MedicationsPage` does not exist.

**Step 3: Implement save controller**

Create `lib/features/medications/application/save_medication_controller.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medication_reminder/features/medications/application/medication_providers.dart';
import 'package:medication_reminder/features/medications/domain/medication.dart';
import 'package:uuid/uuid.dart';

final saveMedicationControllerProvider =
    Provider<SaveMedicationController>((ref) => SaveMedicationController(ref));

class SaveMedicationController {
  SaveMedicationController(this._ref);

  final Ref _ref;
  final _uuid = const Uuid();

  Future<void> save({
    required String name,
    required String dosage,
    required String scheduleInput,
  }) async {
    final now = DateTime.now().toUtc();
    final schedule = scheduleInput
        .split(',')
        .map((value) => value.trim())
        .where((value) => RegExp(r'^\d{2}:\d{2}$').hasMatch(value))
        .toList();
    if (name.trim().isEmpty || dosage.trim().isEmpty || schedule.isEmpty) {
      throw ArgumentError('请填写药名、剂量和至少一个服用时间');
    }

    await _ref.read(medicationRepositoryProvider).saveMedication(
          Medication(
            id: _uuid.v4(),
            userId: 'local',
            name: name.trim(),
            dosage: dosage.trim(),
            schedule: schedule,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }
}
```

**Step 4: Implement management UI**

Create `lib/features/medications/presentation/medication_form_page.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medication_reminder/features/medications/application/save_medication_controller.dart';

class MedicationFormPage extends ConsumerStatefulWidget {
  const MedicationFormPage({super.key});

  @override
  ConsumerState<MedicationFormPage> createState() => _MedicationFormPageState();
}

class _MedicationFormPageState extends ConsumerState<MedicationFormPage> {
  final _name = TextEditingController();
  final _dosage = TextEditingController();
  final _schedule = TextEditingController(text: '08:00');

  @override
  void dispose() {
    _name.dispose();
    _dosage.dispose();
    _schedule.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('添加药品')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: '药名')),
          const SizedBox(height: 16),
          TextField(controller: _dosage, decoration: const InputDecoration(labelText: '剂量')),
          const SizedBox(height: 16),
          TextField(
            controller: _schedule,
            decoration: const InputDecoration(
              labelText: '服用时间',
              helperText: '多个时间用英文逗号分隔，例如 08:00,20:00',
            ),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: () async {
              await ref.read(saveMedicationControllerProvider).save(
                    name: _name.text,
                    dosage: _dosage.text,
                    scheduleInput: _schedule.text,
                  );
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
```

Create `lib/features/medications/presentation/medications_page.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medication_reminder/features/medications/application/medication_providers.dart';
import 'package:medication_reminder/features/medications/presentation/medication_form_page.dart';

class MedicationsPage extends ConsumerWidget {
  const MedicationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medications = ref.watch(medicationsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('药品'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const MedicationFormPage()),
            ),
          ),
        ],
      ),
      body: medications.when(
        data: (items) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final medication = items[index];
            return ListTile(
              tileColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              leading: const Icon(Icons.medication),
              title: Text(medication.name),
              subtitle: Text('${medication.dosage} · ${medication.schedule.join(', ')}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => ref
                    .read(medicationRepositoryProvider)
                    .deleteMedication(medication.id),
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('加载失败：$error')),
      ),
    );
  }
}
```

Modify `lib/core/widgets/app_shell.dart` to replace the third placeholder with `MedicationsPage`.

**Step 5: Run verification**

Run:
```bash
dart format lib/features/medications lib/core/widgets test/features/medications
flutter test test/features/medications/presentation/medications_page_test.dart
flutter test
flutter analyze
```

Expected: PASS and no analyzer issues.

**Step 6: Commit**

```bash
git add lib/features/medications lib/core/widgets test/features/medications
git commit -m "feat: add medication management"
```

---

### Task 10: Build Calendar Statistics And Calendar Page

**Files:**
- Create: `lib/features/calendar/application/calendar_service.dart`
- Create: `lib/features/calendar/presentation/calendar_page.dart`
- Modify: `lib/core/widgets/app_shell.dart`
- Test: `test/features/calendar/application/calendar_service_test.dart`
- Test: `test/features/calendar/presentation/calendar_page_test.dart`

**Step 1: Write failing service test**

Create `test/features/calendar/application/calendar_service_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:medication_reminder/features/calendar/application/calendar_service.dart';
import 'package:medication_reminder/features/medications/domain/medication_log.dart';

void main() {
  test('summarizes confirmed and missed logs', () {
    final logs = [
      MedicationLog(
        id: 'l1',
        medicationId: 'm1',
        scheduledTime: DateTime(2026, 5, 12, 8),
        confirmedTime: DateTime(2026, 5, 12, 8, 3),
        status: MedicationLogStatus.confirmed,
        date: DateTime(2026, 5, 12),
      ),
      MedicationLog(
        id: 'l2',
        medicationId: 'm2',
        scheduledTime: DateTime(2026, 5, 12, 20),
        confirmedTime: null,
        status: MedicationLogStatus.missed,
        date: DateTime(2026, 5, 12),
      ),
    ];

    final stats = CalendarService().summarize(logs);
    expect(stats.confirmed, 1);
    expect(stats.missed, 1);
    expect(stats.rate, 0.5);
  });
}
```

**Step 2: Run test to verify it fails**

Run:
```bash
flutter test test/features/calendar/application/calendar_service_test.dart
```

Expected: FAIL because calendar service does not exist.

**Step 3: Implement calendar service**

Create `lib/features/calendar/application/calendar_service.dart`:
```dart
import 'package:medication_reminder/features/medications/domain/medication_log.dart';

class CalendarStats {
  const CalendarStats({
    required this.confirmed,
    required this.missed,
  });

  final int confirmed;
  final int missed;

  int get total => confirmed + missed;
  double get rate => total == 0 ? 0 : confirmed / total;
}

class CalendarService {
  CalendarStats summarize(List<MedicationLog> logs) {
    var confirmed = 0;
    var missed = 0;
    for (final log in logs) {
      if (log.status == MedicationLogStatus.confirmed) confirmed += 1;
      if (log.status == MedicationLogStatus.missed) missed += 1;
    }
    return CalendarStats(confirmed: confirmed, missed: missed);
  }
}
```

**Step 4: Write failing widget test**

Create `test/features/calendar/presentation/calendar_page_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medication_reminder/features/calendar/presentation/calendar_page.dart';

void main() {
  testWidgets('calendar page renders month grid and stats', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: CalendarPage())));

    expect(find.text('2026年5月'), findsOneWidget);
    expect(find.text('已服'), findsOneWidget);
    expect(find.text('漏服'), findsOneWidget);
    expect(find.text('服药率'), findsOneWidget);
  });
}
```

**Step 5: Implement calendar page**

Create `lib/features/calendar/presentation/calendar_page.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:medication_reminder/core/theme/app_theme.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _visibleMonth = DateTime(2026, 5);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 96),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_visibleMonth.year}年${_visibleMonth.month}月',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() {
                  _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1);
                }),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(() {
                  _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1);
                }),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              _StatChip(label: '已服', value: '0'),
              SizedBox(width: 10),
              _StatChip(label: '漏服', value: '0'),
              SizedBox(width: 10),
              _StatChip(label: '服药率', value: '0%'),
            ],
          ),
          const SizedBox(height: 24),
          _MonthGrid(month: _visibleMonth),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: DecoratedBox(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            children: [
              Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final leading = first.weekday % 7;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: leading + days,
      itemBuilder: (context, index) {
        if (index < leading) return const SizedBox.shrink();
        final day = index - leading + 1;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(child: Text('$day')),
        );
      },
    );
  }
}
```

Modify `lib/core/widgets/app_shell.dart` to replace the second placeholder with `CalendarPage`.

**Step 6: Run verification**

Run:
```bash
dart format lib/features/calendar lib/core/widgets test/features/calendar
flutter test test/features/calendar
flutter test
flutter analyze
```

Expected: PASS and no analyzer issues.

**Step 7: Commit**

```bash
git add lib/features/calendar lib/core/widgets test/features/calendar
git commit -m "feat: add calendar view"
```

---

### Task 11: Build Full-Screen Confirmation Flow

**Files:**
- Create: `lib/features/confirm/presentation/confirm_medication_page.dart`
- Create: `lib/features/confirm/presentation/slide_to_confirm.dart`
- Create: `lib/features/confirm/application/confirm_dose_controller.dart`
- Test: `test/features/confirm/presentation/confirm_medication_page_test.dart`

**Step 1: Write failing widget test**

Create `test/features/confirm/presentation/confirm_medication_page_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medication_reminder/features/confirm/presentation/confirm_medication_page.dart';
import 'package:medication_reminder/features/medications/domain/medication.dart';
import 'package:medication_reminder/features/medications/domain/medication_dose.dart';

void main() {
  testWidgets('slide confirmation calls completion callback', (tester) async {
    var confirmed = false;
    final dose = MedicationDose(
      medication: Medication(
        id: 'm1',
        userId: 'local',
        name: '阿莫西林',
        dosage: '2粒',
        schedule: const ['08:00'],
        createdAt: DateTime(2026, 5, 12),
        updatedAt: DateTime(2026, 5, 12),
      ),
      scheduledTime: DateTime(2026, 5, 12, 8),
      status: DoseStatus.pending,
      log: null,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ConfirmMedicationPage(doses: [dose], onConfirmed: () => confirmed = true),
        ),
      ),
    );

    expect(find.text('该吃药了'), findsOneWidget);
    await tester.drag(find.byType(SlideToConfirm), const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(confirmed, isTrue);
    expect(find.text('已确认'), findsOneWidget);
  });
}
```

**Step 2: Run test to verify it fails**

Run:
```bash
flutter test test/features/confirm/presentation/confirm_medication_page_test.dart
```

Expected: FAIL because confirm page does not exist.

**Step 3: Implement slide control**

Create `lib/features/confirm/presentation/slide_to_confirm.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:medication_reminder/core/theme/app_theme.dart';

class SlideToConfirm extends StatefulWidget {
  const SlideToConfirm({required this.onConfirmed, super.key});

  final VoidCallback onConfirmed;

  @override
  State<SlideToConfirm> createState() => _SlideToConfirmState();
}

class _SlideToConfirmState extends State<SlideToConfirm> {
  double _drag = 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxDrag = constraints.maxWidth - 60;
        return GestureDetector(
          onHorizontalDragUpdate: (details) {
            setState(() => _drag = (_drag + details.delta.dx).clamp(0, maxDrag));
          },
          onHorizontalDragEnd: (_) {
            if (_drag >= maxDrag * 0.85) {
              widget.onConfirmed();
            } else {
              setState(() => _drag = 0);
            }
          },
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.orange, Color(0xFFEB7B30)]),
              borderRadius: BorderRadius.circular(32),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Text('滑动确认已服用', style: TextStyle(color: Colors.white)),
                Positioned(
                  left: _drag,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_forward, color: AppColors.orange),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
```

**Step 4: Implement confirmation page**

Create `lib/features/confirm/presentation/confirm_medication_page.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:medication_reminder/core/theme/app_theme.dart';
import 'package:medication_reminder/features/confirm/presentation/slide_to_confirm.dart';
import 'package:medication_reminder/features/medications/domain/medication_dose.dart';

class ConfirmMedicationPage extends StatefulWidget {
  const ConfirmMedicationPage({
    required this.doses,
    required this.onConfirmed,
    super.key,
  });

  final List<MedicationDose> doses;
  final VoidCallback onConfirmed;

  @override
  State<ConfirmMedicationPage> createState() => _ConfirmMedicationPageState();
}

class _ConfirmMedicationPageState extends State<ConfirmMedicationPage> {
  var _confirmed = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _confirmed,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _confirmed ? _success() : _confirmContent(),
          ),
        ),
      ),
    );
  }

  Widget _confirmContent() {
    return Column(
      children: [
        const SizedBox(height: 32),
        const Chip(label: Text('该吃药了')),
        const Spacer(),
        for (final dose in widget.doses)
          ListTile(
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            leading: const Icon(Icons.medication, color: AppColors.orange),
            title: Text(dose.medication.name),
            subtitle: Text(dose.medication.dosage),
          ),
        const Spacer(),
        SlideToConfirm(
          onConfirmed: () {
            setState(() => _confirmed = true);
            widget.onConfirmed();
          },
        ),
      ],
    );
  }

  Widget _success() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 88, color: AppColors.green),
          SizedBox(height: 16),
          Text('已确认', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
```

**Step 5: Run verification**

Run:
```bash
dart format lib/features/confirm test/features/confirm
flutter test test/features/confirm/presentation/confirm_medication_page_test.dart
flutter test
flutter analyze
```

Expected: PASS and no analyzer issues.

**Step 6: Commit**

```bash
git add lib/features/confirm test/features/confirm
git commit -m "feat: add medication confirmation flow"
```

---

### Task 12: Add Local Notification And Alarm Scheduling Abstraction

**Files:**
- Create: `lib/core/notifications/notification_scheduler.dart`
- Create: `lib/core/notifications/local_notification_scheduler.dart`
- Create: `lib/core/notifications/alarm_rescheduler.dart`
- Create: `lib/core/notifications/reminder_retry_service.dart`
- Test: `test/core/notifications/alarm_rescheduler_test.dart`

**Step 1: Write failing scheduling test**

Create `test/core/notifications/alarm_rescheduler_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:medication_reminder/core/notifications/alarm_rescheduler.dart';
import 'package:medication_reminder/core/notifications/notification_scheduler.dart';
import 'package:medication_reminder/core/notifications/reminder_retry_service.dart';
import 'package:medication_reminder/features/medications/domain/medication.dart';
import 'package:medication_reminder/features/medications/domain/medication_dose.dart';

class FakeNotificationScheduler implements NotificationScheduler {
  final scheduled = <ScheduledNotificationRequest>[];

  @override
  Future<void> initialize() async {}

  @override
  Future<void> schedule(ScheduledNotificationRequest request) async {
    scheduled.add(request);
  }

  @override
  Future<void> cancelAll() async {}
}

void main() {
  test('rescheduler schedules one reminder per medication time', () async {
    final scheduler = FakeNotificationScheduler();
    await AlarmRescheduler(scheduler).rescheduleAll(
      medications: [
        Medication(
          id: 'm1',
          userId: 'local',
          name: '阿莫西林',
          dosage: '2粒',
          schedule: const ['08:00', '20:00'],
          createdAt: DateTime(2026, 5, 12),
          updatedAt: DateTime(2026, 5, 12),
        ),
      ],
      from: DateTime(2026, 5, 12, 7),
    );

    expect(scheduler.scheduled.length, 2);
    expect(scheduler.scheduled.first.title, '该吃药了');
  });

  test('retry service schedules another reminder five minutes later while unconfirmed', () async {
    final scheduler = FakeNotificationScheduler();
    final dose = MedicationDose(
      medication: Medication(
        id: 'm1',
        userId: 'local',
        name: '阿莫西林',
        dosage: '2粒',
        schedule: const ['08:00'],
        createdAt: DateTime(2026, 5, 12),
        updatedAt: DateTime(2026, 5, 12),
      ),
      scheduledTime: DateTime(2026, 5, 12, 8),
      status: DoseStatus.pending,
      log: null,
    );

    await ReminderRetryService(scheduler).scheduleRetryIfNeeded(
      dose: dose,
      now: DateTime(2026, 5, 12, 8, 1),
    );

    expect(scheduler.scheduled.single.title, '还没确认服药');
    expect(scheduler.scheduled.single.scheduledAt, DateTime(2026, 5, 12, 8, 6));
  });
}
```

**Step 2: Run test to verify it fails**

Run:
```bash
flutter test test/core/notifications/alarm_rescheduler_test.dart
```

Expected: FAIL because notification files do not exist.

**Step 3: Implement scheduler abstraction**

Create `lib/core/notifications/notification_scheduler.dart`:
```dart
class ScheduledNotificationRequest {
  const ScheduledNotificationRequest({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledAt,
    required this.payload,
  });

  final int id;
  final String title;
  final String body;
  final DateTime scheduledAt;
  final String payload;
}

abstract class NotificationScheduler {
  Future<void> initialize();
  Future<void> schedule(ScheduledNotificationRequest request);
  Future<void> cancelAll();
}
```

Create `lib/core/notifications/alarm_rescheduler.dart`:
```dart
import 'package:medication_reminder/core/notifications/notification_scheduler.dart';
import 'package:medication_reminder/features/medications/domain/medication.dart';

class AlarmRescheduler {
  AlarmRescheduler(this._scheduler);

  final NotificationScheduler _scheduler;

  Future<void> rescheduleAll({
    required List<Medication> medications,
    required DateTime from,
  }) async {
    await _scheduler.cancelAll();
    for (final medication in medications) {
      for (final time in medication.schedule) {
        final scheduledAt = _nextOccurrence(from, time);
        await _scheduler.schedule(
          ScheduledNotificationRequest(
            id: _stableId('${medication.id}-$time'),
            title: '该吃药了',
            body: '${medication.name} · ${medication.dosage}',
            scheduledAt: scheduledAt,
            payload: medication.id,
          ),
        );
      }
    }
  }

  DateTime _nextOccurrence(DateTime from, String hhmm) {
    final parts = hhmm.split(':').map(int.parse).toList();
    var candidate = DateTime(from.year, from.month, from.day, parts[0], parts[1]);
    if (!candidate.isAfter(from)) candidate = candidate.add(const Duration(days: 1));
    return candidate;
  }

  int _stableId(String value) => value.codeUnits.fold(0, (sum, code) => sum + code) % 2147483647;
}
```

Create `lib/core/notifications/reminder_retry_service.dart`:
```dart
import 'package:medication_reminder/core/notifications/notification_scheduler.dart';
import 'package:medication_reminder/features/medications/domain/medication_dose.dart';

class ReminderRetryService {
  ReminderRetryService(this._scheduler);

  final NotificationScheduler _scheduler;

  Future<void> scheduleRetryIfNeeded({
    required MedicationDose dose,
    required DateTime now,
  }) async {
    if (dose.status == DoseStatus.confirmed) return;
    await _scheduler.schedule(
      ScheduledNotificationRequest(
        id: _stableId('retry-${dose.id}'),
        title: '还没确认服药',
        body: '${dose.medication.name} · ${dose.medication.dosage}',
        scheduledAt: now.add(const Duration(minutes: 5)),
        payload: 'retry:${dose.id}',
      ),
    );
  }

  int _stableId(String value) => value.codeUnits.fold(0, (sum, code) => sum + code) % 2147483647;
}
```

Create `lib/core/notifications/local_notification_scheduler.dart`:
```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:medication_reminder/core/notifications/notification_scheduler.dart';
import 'package:timezone/timezone.dart' as tz;

class LocalNotificationScheduler implements NotificationScheduler {
  LocalNotificationScheduler({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<void> initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);
  }

  @override
  Future<void> schedule(ScheduledNotificationRequest request) {
    const androidDetails = AndroidNotificationDetails(
      'medication_reminders',
      '服药提醒',
      channelDescription: '定时提醒并要求确认服药',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    return _plugin.zonedSchedule(
      request.id,
      request.title,
      request.body,
      tz.TZDateTime.from(request.scheduledAt, tz.local),
      const NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: request.payload,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  @override
  Future<void> cancelAll() => _plugin.cancelAll();
}
```

**Step 4: Run verification**

Run:
```bash
dart format lib/core/notifications test/core/notifications
flutter test test/core/notifications/alarm_rescheduler_test.dart
flutter analyze
```

Expected: PASS and no analyzer issues. If the notification package API changed, adapt only `LocalNotificationScheduler`; keep the abstraction and test intact.

**Step 5: Commit**

```bash
git add lib/core/notifications test/core/notifications
git commit -m "feat: add reminder scheduling service"
```

---

### Task 13: Wire SQLite Repository Into App Startup

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/app.dart`
- Modify: `lib/features/medications/application/medication_providers.dart`
- Test: `test/app_startup_test.dart`

**Step 1: Write provider override startup test**

Create `test/app_startup_test.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medication_reminder/app.dart';
import 'package:medication_reminder/features/medications/application/medication_providers.dart';
import 'package:medication_reminder/features/medications/data/in_memory_medication_repository.dart';

void main() {
  testWidgets('app accepts repository override at root', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          medicationRepositoryProvider.overrideWithValue(InMemoryMedicationRepository()),
        ],
        child: const MedicationReminderApp(),
      ),
    );

    expect(find.text('早上好'), findsOneWidget);
  });
}
```

**Step 2: Run test**

Run:
```bash
flutter test test/app_startup_test.dart
```

Expected: PASS before wiring. This protects root override behavior.

**Step 3: Add database provider**

Modify `lib/features/medications/application/medication_providers.dart`:
```dart
import 'package:medication_reminder/core/storage/app_database.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

final sqliteDatabaseProvider = FutureProvider((ref) async {
  final database = ref.watch(appDatabaseProvider);
  ref.onDispose(database.close);
  return database.instance;
});

final medicationRepositoryProvider = Provider<MedicationRepository>((ref) {
  return InMemoryMedicationRepository();
});
```

**Step 4: Wire repository in main**

Modify `lib/main.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medication_reminder/app.dart';
import 'package:medication_reminder/core/storage/app_database.dart';
import 'package:medication_reminder/features/medications/application/medication_providers.dart';
import 'package:medication_reminder/features/medications/data/sqlite_medication_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = AppDatabase();
  final sqlite = await database.instance;

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        medicationRepositoryProvider.overrideWithValue(
          SqliteMedicationRepository(database: sqlite),
        ),
      ],
      child: const MedicationReminderApp(),
    ),
  );
}
```

Keep `MedicationReminderApp` free of repository construction so tests can override dependencies.

**Step 5: Run verification**

Run:
```bash
dart format lib test
flutter test
flutter analyze
```

Expected: PASS and no analyzer issues.

**Step 6: Commit**

```bash
git add lib/main.dart lib/app.dart lib/features/medications/application test/app_startup_test.dart
git commit -m "feat: wire sqlite repository at startup"
```

---

### Task 14: Add Supabase Sync Skeleton And SQL Migration

**Files:**
- Create: `lib/core/sync/sync_service.dart`
- Create: `lib/core/sync/supabase_sync_service.dart`
- Create: `supabase/migrations/202605130001_create_medication_tables.sql`
- Create: `docs/operations/supabase-and-uptimerobot.md`
- Test: `test/core/sync/sync_service_test.dart`

**Step 1: Write failing sync test**

Create `test/core/sync/sync_service_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:medication_reminder/core/sync/sync_service.dart';

void main() {
  test('sync result reports pushed and failed counts', () {
    const result = SyncResult(pushed: 2, failed: 1);
    expect(result.hasFailures, isTrue);
    expect(result.summary, '2 pushed, 1 failed');
  });
}
```

**Step 2: Run test to verify it fails**

Run:
```bash
flutter test test/core/sync/sync_service_test.dart
```

Expected: FAIL because sync service does not exist.

**Step 3: Implement sync contract**

Create `lib/core/sync/sync_service.dart`:
```dart
class SyncResult {
  const SyncResult({
    required this.pushed,
    required this.failed,
  });

  final int pushed;
  final int failed;

  bool get hasFailures => failed > 0;
  String get summary => '$pushed pushed, $failed failed';
}

abstract class SyncService {
  Future<SyncResult> pushPendingChanges();
}
```

Create `lib/core/sync/supabase_sync_service.dart`:
```dart
import 'dart:convert';

import 'package:medication_reminder/core/sync/sync_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseSyncService implements SyncService {
  SupabaseSyncService({
    required Database database,
    required SupabaseClient client,
  })  : _database = database,
        _client = client;

  final Database _database;
  final SupabaseClient _client;

  @override
  Future<SyncResult> pushPendingChanges() async {
    final rows = await _database.query(
      'sync_queue',
      where: 'synced = ?',
      whereArgs: [0],
      orderBy: 'created_at ASC',
    );

    var pushed = 0;
    var failed = 0;
    for (final row in rows) {
      try {
        final table = row['table_name']! as String;
        final action = row['action']! as String;
        final payload = row['payload']! as String;
        if (action == 'delete') {
          await _client.from(table).delete().eq('id', row['record_id']! as String);
        } else {
          await _client.from(table).upsert(_decodePayload(table, payload));
        }
        await _database.update(
          'sync_queue',
          {'synced': 1},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
        pushed += 1;
      } catch (_) {
        failed += 1;
      }
    }
    return SyncResult(pushed: pushed, failed: failed);
  }

  Map<String, Object?> _decodePayload(String table, String payload) {
    final decoded = Map<String, Object?>.from(jsonDecode(payload) as Map);
    if (table == 'medications' && decoded['schedule'] is String) {
      decoded['schedule'] = jsonDecode(decoded['schedule']! as String);
    }
    return decoded;
  }
}
```

**Step 4: Add Supabase SQL migration**

Create `supabase/migrations/202605130001_create_medication_tables.sql`:
```sql
create table if not exists public.medications (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  dosage text not null,
  schedule jsonb not null,
  created_at timestamptz not null,
  updated_at timestamptz not null
);

create table if not exists public.medication_logs (
  id uuid primary key,
  medication_id uuid not null references public.medications(id) on delete cascade,
  scheduled_time timestamptz not null,
  confirmed_time timestamptz,
  status text not null check (status in ('confirmed', 'missed')),
  date date not null
);

alter table public.medications enable row level security;
alter table public.medication_logs enable row level security;

create policy "Users manage own medications"
on public.medications
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "Users manage logs for own medications"
on public.medication_logs
for all
using (
  exists (
    select 1 from public.medications
    where medications.id = medication_logs.medication_id
    and medications.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1 from public.medications
    where medications.id = medication_logs.medication_id
    and medications.user_id = auth.uid()
  )
);
```

**Step 5: Add operations doc**

Create `docs/operations/supabase-and-uptimerobot.md`:
```markdown
# Supabase And UptimeRobot Setup

## Supabase

1. Create a Supabase project.
2. Run `supabase/migrations/202605130001_create_medication_tables.sql`.
3. Enable Google provider in Supabase Auth.
4. Add app URL scheme/deep links after Android package name is finalized.
5. Store `SUPABASE_URL` and `SUPABASE_ANON_KEY` in local build configuration.

## UptimeRobot

1. Create an HTTP(s) monitor.
2. Target the Supabase REST endpoint: `https://<project-ref>.supabase.co/rest/v1/`.
3. Set interval to 5 minutes.
4. Configure email or push alert contacts.

The app must remain usable when this monitor reports downtime because SQLite is the source of truth.
```

**Step 6: Run verification**

Run:
```bash
dart format lib/core/sync test/core/sync
flutter test test/core/sync/sync_service_test.dart
flutter analyze
```

Expected: PASS and no analyzer issues. Runtime sync still requires a real Supabase project and authenticated user.

**Step 7: Commit**

```bash
git add lib/core/sync supabase docs/operations test/core/sync
git commit -m "feat: add supabase sync skeleton"
```

---

### Task 15: Configure Android Notification Permissions

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `lib/main.dart`
- Test: manual Android smoke test

**Step 1: Add Android permissions**

Modify `android/app/src/main/AndroidManifest.xml` inside the root `<manifest>`:
```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
<uses-permission android:name="android.permission.USE_EXACT_ALARM" />
<uses-permission android:name="android.permission.VIBRATE" />
```

Inside `<application>`, ensure receivers/services required by `flutter_local_notifications` and `android_alarm_manager_plus` are present per package docs. Do not add duplicate receiver entries if the generated plugin registrant already provides them.

**Step 2: Initialize timezone and notifications**

Modify `lib/main.dart` after `WidgetsFlutterBinding.ensureInitialized()`:
```dart
tz.initializeTimeZones();
await LocalNotificationScheduler().initialize();
```

Add imports:
```dart
import 'package:medication_reminder/core/notifications/local_notification_scheduler.dart';
import 'package:timezone/data/latest.dart' as tz;
```

**Step 3: Run static verification**

Run:
```bash
flutter analyze
flutter test
flutter build apk --debug
```

Expected: analyzer/tests pass; debug APK builds.

**Step 4: Manual device verification**

Run:
```bash
flutter devices
flutter run
```

Expected:
- App launches on Android.
- Permission prompt appears on Android 13+ when notification permission is requested by plugin flow.
- Adding a medication persists after app restart.
- Notification scheduling code does not crash app startup.

**Step 5: Commit**

```bash
git add android/app/src/main/AndroidManifest.xml lib/main.dart
git commit -m "feat: configure android reminders"
```

---

### Task 16: Final Polish, Seed Data Removal, And Verification

**Files:**
- Modify: any files touched by previous tasks as needed
- Create: `docs/verification/2026-05-13-medication-reminder-app.md`

**Step 1: Run full verification**

Run:
```bash
dart format .
flutter test
flutter analyze
flutter build apk --debug
```

Expected: all commands pass.

**Step 2: Verify UX manually**

Run:
```bash
flutter run
```

Manual checklist:
- Today tab loads with warm background and bottom navigation.
- Add medication form can create at least one medicine with two times.
- Today tab displays the medicine grouped by time.
- Calendar tab renders month grid and stats band without overflow.
- Confirmation page requires slide interaction and blocks back navigation until confirmed.
- App restart keeps medications in SQLite.

**Step 3: Record verification**

Create `docs/verification/2026-05-13-medication-reminder-app.md`:
```markdown
# Medication Reminder App Verification

Date: 2026-05-13

## Commands

- `dart format .`
- `flutter test`
- `flutter analyze`
- `flutter build apk --debug`

## Manual Checks

- Today tab loads.
- Medication can be added.
- Medication persists after restart.
- Calendar tab renders.
- Confirmation flow requires slide.
- Android debug build launches.

## Notes

Supabase sync is scaffolded but should be validated against a real project before production.
```

**Step 4: Commit**

```bash
git add .
git commit -m "chore: verify medication reminder app"
```

Expected: final commit contains only polish and verification docs.

---

## Implementation Notes

- Keep UI copy in Chinese.
- Prefer Material icons over emoji in production UI.
- Avoid landing-page style screens; first screen must be the actual Today workflow.
- Keep card radius around 20px only where it matches the existing brainstorm direction.
- Do not introduce cloud-only flows; every core action must work offline.
- Do not store Supabase secrets in git.
- Keep repository methods small and testable; avoid introducing code generation until the project clearly benefits from it.

## Done Criteria

- `flutter test` passes.
- `flutter analyze` passes.
- `flutter build apk --debug` passes.
- Android app can add a medication, show today doses, show calendar shell, and complete slide confirmation.
- SQLite persistence works across restart.
- Sync queue records local mutations.
- Supabase schema and UptimeRobot setup doc exist.
