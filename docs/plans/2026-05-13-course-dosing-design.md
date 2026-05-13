# Course Dosing Design

## 背景

当前「药丸」App 的药品模型只支持固定剂量和每天固定提醒时间。用户需要一次性设置一个疗程，例如连续服用 7 天，并且每一周中的不同日期可能有不同剂量。用户确认采用「周模板生成 + 逐日微调」方案。

## 目标

- 添加药品时支持设置开始日期、服用天数和每日提醒时间。
- 支持按周一到周日设置剂量模板。
- 根据开始日期和服用天数生成逐日计划。
- 允许用户在保存前单独修改某一天的剂量。
- 今日页只显示疗程范围内当天需要服用的剂量。
- 日历页和服药记录继续基于实际生成的当天剂量工作。
- 兼容现有固定剂量药品数据。

## 非目标

- 不做复杂停药、调药历史。
- 不做库存提醒。
- 不做多疗程续方管理。
- 不在本轮实现医生导出或家庭共享。

## 推荐方案

采用「周模板 + 每日覆盖」模型。

药品保存时仍保留一个默认剂量 `dosage` 作为兼容字段，同时新增疗程字段：

- `start_date`：疗程开始日期，date-only。
- `duration_days`：疗程天数，正整数。
- `daily_plans`：JSON 数组，每天一条，包含日期、dayIndex、dosage、schedule。

`daily_plans` 是实际排程来源。周模板只作为表单生成 daily plans 的输入，不必单独入库。这样模型简单，后续要支持逐日修改时也不需要再叠加模板覆盖逻辑。

## 数据结构

新增 domain model：

```dart
class MedicationDailyPlan {
  MedicationDailyPlan({
    required this.date,
    required this.dayIndex,
    required this.dosage,
    required List<String> schedule,
  });

  final DateTime date;
  final int dayIndex;
  final String dosage;
  final List<String> schedule;
}
```

`Medication` 新增：

```dart
final DateTime? startDate;
final int? durationDays;
final List<MedicationDailyPlan> dailyPlans;
```

兼容规则：

- 新药品：`dailyPlans` 非空，排程来自 daily plans。
- 旧药品：`dailyPlans` 为空，排程继续来自 `dosage + schedule`，视为每日固定剂量。

## 表单体验

添加药品页改为一个纵向流程：

1. 基础信息：药名。
2. 疗程：开始日期、服用天数。
3. 每天提醒时间：仍支持 `08:00,20:00`。
4. 每周剂量模板：周一到周日 7 个剂量输入。
5. 逐日计划预览：按日期列出每天剂量，允许编辑。

为了避免空模板生成无效计划，保存时校验：

- 药名不能为空。
- 服用天数必须为 1 到 366。
- 提醒时间必须是严格 `HH:mm`。
- 每一天最终剂量不能为空。

## 排程逻辑

`ScheduleService` 生成当天 doses 时：

- 如果 `medication.dailyPlans` 非空，只查找与目标日期相同的 daily plan。
- 对该 daily plan 的每个提醒时间生成 `MedicationDose`。
- `MedicationDose` 需要携带当天剂量，展示时优先用该剂量。
- 如果没有 daily plan，则走旧逻辑，使用 medication 的固定剂量和 schedule。

这样 Today 页面、确认页和日志匹配都能继续按 scheduledTime 运作。

## 存储和同步

SQLite `medications` 表新增三列：

- `start_date TEXT`
- `duration_days INTEGER`
- `daily_plans TEXT NOT NULL DEFAULT '[]'`

迁移到 schema version 2。已有数据库升级时给旧药品补默认值，不改旧 schedule/dosage 行为。

Supabase migration 同步新增对应字段：

- `start_date date`
- `duration_days integer`
- `daily_plans jsonb not null default '[]'::jsonb`

同步 payload 继续由 `Medication.toMap()` 生成。

## 测试策略

- Domain tests 覆盖 daily plan 序列化、date-only 规范化、旧数据兼容。
- Controller tests 覆盖从周模板生成 7 天计划、跨周循环、逐日覆盖、非法天数和空剂量校验。
- Schedule service tests 覆盖疗程范围内显示、范围外不显示、当天剂量不同。
- SQLite schema/repository tests 覆盖 version 2、列创建、保存和读取 daily plans。
- Widget tests 覆盖表单能生成一周疗程药品，Today 页面显示当天剂量。

## 风险

- 表单会比之前复杂，需要控制视觉密度，避免手机上输入负担太重。
- 数据库升级需要兼容已经安装在手机上的 v1 数据库。
- 现有测试里大量假药品构造函数需要更新，适合通过默认参数和 helper 降低改动面。
