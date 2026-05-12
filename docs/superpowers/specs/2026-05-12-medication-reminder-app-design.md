# 药丸 App 设计文档

## 概述

**产品名称：** 药丸  
**目标用户：** 需要每天定时服用多种药物的个人用户  
**核心痛点：** 闹钟提醒容易被关掉后遗忘，缺乏服药记录  
**解决方案：** 强制交互确认的提醒机制 + 日历式服药记录  

## 技术栈

| 层级 | 技术选型 | 说明 |
|------|----------|------|
| 前端框架 | Flutter | 跨平台，先 Android 后 iOS |
| 本地存储 | SQLite (sqflite) | 离线优先，保证无网络时正常使用 |
| 云端数据库 | Supabase (PostgreSQL) | 多设备同步，实时数据库 |
| 通知系统 | flutter_local_notifications + android_alarm_manager_plus | 精确定时本地通知 |
| 外部监控 | UptimeRobot | 监控 Supabase 服务可用性 |

## 架构设计

### 整体架构：离线优先 + 云端同步

```
Flutter App
├── UI 层（页面 + 组件）
├── 通知服务（本地闹钟调度）
├── 业务逻辑层（药品管理 / 提醒调度 / 记录）
└── 数据层
    ├── SQLite（本地主存储）
    └── 同步队列 ←→ Supabase（云端同步）

外部：UptimeRobot → 监控 Supabase API 可用性
```

### 用户认证

- 使用 Supabase Auth，支持 Google 登录
- 首次使用引导用户登录，绑定设备
- 多设备通过同一账号自动同步数据

### 同步策略

1. **本地 SQLite 为主** — 所有操作先写本地，app 不依赖网络
2. **同步队列** — 本地变更记录到待同步队列，联网时批量推送
3. **定时同步** — WorkManager (Android) / Background Fetch (iOS) 定期同步
4. **断线重连** — Supabase 实时连接断开时自动重试，指数退避（1s → 2s → 4s → 最大 30s）
5. **冲突解决** — last-write-wins（以最后修改时间为准）

## 数据模型

### 药品表 (medications)

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 主键 |
| user_id | UUID | 用户 ID（关联 Supabase Auth） |
| name | String | 药名 |
| dosage | String | 剂量（如"1片"、"5mg"） |
| schedule | JSON | 服用时间规则（如 ["08:00", "12:00", "20:00"]） |
| created_at | DateTime | 创建时间 |
| updated_at | DateTime | 更新时间 |

### 服药记录表 (medication_logs)

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 主键 |
| medication_id | UUID | 关联药品 |
| scheduled_time | DateTime | 计划服药时间 |
| confirmed_time | DateTime? | 实际确认时间，null 表示未确认 |
| status | Enum | confirmed / missed |
| date | Date | 日期 |

### 同步队列表 (sync_queue) — 仅本地

| 字段 | 类型 | 说明 |
|------|------|------|
| id | Integer | 自增主键 |
| table_name | String | 目标表名 |
| record_id | UUID | 记录 ID |
| action | Enum | insert / update / delete |
| payload | JSON | 变更数据 |
| created_at | DateTime | 创建时间 |
| synced | Boolean | 是否已同步 |

## 页面结构

### 1. 首页（今日）

- 顶部问候语 + 日期 + 今日进度胶囊
- 按时间段分组显示药品（早上/中午/晚上）
- 已确认：绿色卡片 + 左侧绿色指示条
- 待服用：白色卡片 + 左侧橙色指示条
- 底部导航栏：今日 | 日历 | 药品

### 2. 日历页

- 月历视图，可左右切换月份
- 顶部统计条：已服次数、漏服次数、服药率
- 每天下方小圆点指示状态（绿/红/橙）
- 点击某天展开详情卡片，显示当天所有药品服用情况
- 今天高亮显示

### 3. 药品管理页

- 药品库列表
- 添加药品：输入药名、剂量、设置服用时间规则
- 编辑/删除已有药品
- 首次添加走完整表单，后续添加可从已有药品库快速选择

### 4. 确认页（全屏独立页面）

- 从通知点击进入
- 顶部提示徽章（🔔 该吃药了）
- 中间显示当前时间段需要服用的所有药品列表
- 底部滑动确认条（橙色渐变，需拖动滑块到右侧）
- 确认成功后显示绿色成功界面
- 不可通过返回键或其他方式绕过

## 提醒系统

### 提醒逻辑

1. 到达设定时间 → 弹出本地通知（通知栏 + 声音 + 震动）
2. 用户点击通知 → 跳转到确认页面
3. 用户划掉通知未确认 → 5 分钟后再次通知
4. 重复提醒无上限，直到用户完成滑动确认
5. 确认后记录实际服药时间

### 技术实现

- Android: android_alarm_manager_plus 精确定时 + flutter_local_notifications
- iOS (后续): UNNotificationRequest
- 通知渠道设置为高优先级，确保不被系统静默

## 设计风格

- **色调：** 温暖奶油色背景 (#FDF6EE)，绿色表示已完成，橙色表示待处理
- **卡片：** 大圆角 (20px)，轻阴影，左侧彩色指示条
- **字体：** Noto Sans SC + Quicksand，温暖友好
- **动效：** 页面进入淡入上移，卡片 hover 微浮，滑块轻晃提示
- **整体感觉：** 柔和、有温度、不冰冷，像一个关心你的小助手

## 外部监控

- UptimeRobot 配置 HTTP(s) 监控，目标为 Supabase 项目 REST API endpoint
- 检查间隔：5 分钟
- 告警方式：邮件/推送通知
- 作用：当 Supabase 服务异常时第一时间知晓，app 内同步机制保证用户体验不受影响

## 未来扩展（不在当前范围）

- iOS 版本发布
- 药品库存提醒
- 多用户/家庭共享
- 停药/调药记录
- 数据导出给医生
