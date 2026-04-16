import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'storage_service.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(iOS: iosSettings);
    await _plugin.initialize(settings);
    _initialized = true;
  }

  static Future<void> requestPermission(BuildContext context) async {
    if (!Platform.isIOS) return;
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Schedules birthday notifications for all contacts with birthdays.
  static Future<void> scheduleBirthdayNotifications() async {
    await init();
    // Cancel existing birthday notifications
    final pending = await _plugin.pendingNotificationRequests();
    for (final n in pending) {
      if (n.id >= 1000 && n.id < 2000) await _plugin.cancel(n.id);
    }

    final contacts = StorageService.getAllContacts();
    int id = 1000;
    final now = DateTime.now();

    for (final contact in contacts) {
      final birthday = contact.birthday;
      if (birthday == null) continue;

      // Next birthday (this year or next)
      var nextBirthday = DateTime(now.year, birthday.month, birthday.day, 9, 0);
      if (nextBirthday.isBefore(now)) {
        nextBirthday = DateTime(now.year + 1, birthday.month, birthday.day, 9, 0);
      }

      final tzBirthday = tz.TZDateTime.from(nextBirthday, tz.local);

      await _plugin.zonedSchedule(
        id++,
        '🎂 יום הולדת היום!',
        'היום יום הולדתו/ה של ${contact.name}. אל תשכח לאחל!',
        tzBirthday,
        const NotificationDetails(
          iOS: DarwinNotificationDetails(
            categoryIdentifier: 'birthday',
            sound: 'default',
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
      );
    }
  }

  /// Notifies about contacts not contacted for more than [days] days.
  static Future<void> scheduleIdleReminders({int days = 30}) async {
    await init();
    // Cancel existing idle notifications
    final pending = await _plugin.pendingNotificationRequests();
    for (final n in pending) {
      if (n.id >= 2000 && n.id < 3000) await _plugin.cancel(n.id);
    }

    final contacts = StorageService.getAllContacts();
    final now = DateTime.now();
    int id = 2000;

    for (final contact in contacts) {
      final last = contact.lastContactedAt;
      if (last == null) continue;
      final daysSince = now.difference(last).inDays;
      if (daysSince < days) continue;

      final notifyAt = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5));
      await _plugin.zonedSchedule(
        id++,
        'לא דיברת עם ${contact.name}',
        'עברו $daysSince ימים מאז שדיברת עם ${contact.name}',
        notifyAt,
        const NotificationDetails(
          iOS: DarwinNotificationDetails(sound: 'default'),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  static Future<void> cancelAll() async => _plugin.cancelAll();
}
