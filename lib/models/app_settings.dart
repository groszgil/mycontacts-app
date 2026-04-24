import 'package:hive/hive.dart';

part 'app_settings.g.dart';

@HiveType(typeId: 2)
class AppSettings extends HiveObject {
  @HiveField(0)
  int gridColumns;

  @HiveField(1)
  int gridRows;

  @HiveField(2)
  bool isDarkMode;

  @HiveField(3)
  double fontScale;

  @HiveField(4)
  int accentColorValue;

  @HiveField(5)
  bool isListView;

  // ── Birthday reminders ───────────────────────────────────────────────────
  @HiveField(6)
  bool birthdayReminderEnabled;

  /// 0 = day of, 1 = day before, 3, 7 = X days before
  @HiveField(7)
  int birthdayReminderDaysBefore;

  /// Hour of day (0–23) for the reminder notification
  @HiveField(8)
  int birthdayReminderHour;

  // ── Anniversary reminders ────────────────────────────────────────────────
  @HiveField(9)
  bool anniversaryReminderEnabled;

  @HiveField(10)
  int anniversaryReminderDaysBefore;

  @HiveField(11)
  int anniversaryReminderHour;

  AppSettings({
    this.gridColumns = 3,
    this.gridRows = 4,
    this.isDarkMode = false,
    this.fontScale = 1.0,
    this.accentColorValue = 0xFF6C63FF,
    this.isListView = false,
    this.birthdayReminderEnabled = false,
    this.birthdayReminderDaysBefore = 0,
    this.birthdayReminderHour = 9,
    this.anniversaryReminderEnabled = false,
    this.anniversaryReminderDaysBefore = 0,
    this.anniversaryReminderHour = 9,
  });
}
