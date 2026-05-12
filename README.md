# 药丸

Android-first Flutter 服药提醒 MVP。应用以 SQLite 为本地事实源，支持药品管理、今日服药列表、日历记录、滑动确认提醒，并预留 Supabase 同步。

## 功能

- 今日页按时间展示待服、已服和漏服状态。
- 药品页支持添加药名、剂量和每日服用时间。
- 日历页展示月统计、日期状态点和当天服药明细。
- 全屏确认页通过滑动写入服药记录。
- 本地 SQLite 持久化并记录 `sync_queue`。
- Supabase migration 和同步服务骨架已加入，生产前需接入真实项目和认证用户。

## 开发命令

```bash
flutter pub get
dart format .
flutter test
flutter analyze
flutter build apk --debug
```

## Android

Android 提醒使用 `flutter_local_notifications` 和 `android_alarm_manager_plus` 的 manifest 配置。首次运行会请求通知/精确闹钟相关权限，实际设备验证仍需要通过 `flutter run` 完成。

## 运维

Supabase 和 UptimeRobot 配置见 `docs/operations/supabase-and-uptimerobot.md`。
