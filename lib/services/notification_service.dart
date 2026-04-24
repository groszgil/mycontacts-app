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

    // iOS notification categories for birthday greeting actions
    final birthdayCategory = DarwinNotificationCategory(
      'birthday_greeting',
      actions: [
        DarwinNotificationAction.plain(
          'whatsapp',
          '💬 WhatsApp',
          options: {DarwinNotificationActionOption.foreground},
        ),
        DarwinNotificationAction.plain(
          'sms',
          '✉️ SMS',
          options: {DarwinNotificationActionOption.foreground},
        ),
        DarwinNotificationAction.plain(
          'call',
          '📞 התקשר',
          options: {DarwinNotificationActionOption.foreground},
        ),
      ],
    );

    final iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: [birthdayCategory],
    );

    // Android — notification channel + launcher icon as small icon
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    final settings = InitializationSettings(
      iOS: iosSettings,
      android: androidSettings,
    );
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // Create Android notification channels
    if (Platform.isAndroid) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'birthdays_channel',
          'ימי הולדת',
          description: 'תזכורות לימי הולדת של אנשי הקשר',
          importance: Importance.high,
          enableVibration: true,
          playSound: true,
        ),
      );
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'anniversaries_channel',
          'ימי נישואין',
          description: 'תזכורות לימי נישואין של אנשי הקשר',
          importance: Importance.high,
          enableVibration: true,
          playSound: true,
        ),
      );
    }

    _initialized = true;
  }

  static void _onNotificationResponse(NotificationResponse response) {
    // payload = "phone:PHONE_NUMBER"
    final payload = response.payload ?? '';
    final phone = payload.startsWith('phone:') ? payload.substring(6) : '';
    if (phone.isEmpty) return;

    final action = response.actionId;
    if (action == 'whatsapp') {
      _launchUrl('https://wa.me/${_sanitize(phone)}');
    } else if (action == 'sms') {
      _launchUrl('sms:$phone');
    } else if (action == 'call') {
      _launchUrl('tel:$phone');
    }
  }

  static void _launchUrl(String url) async {
    // Use dart:io Process on iOS is not standard; flutter launch helper
    // We write payload to a temp file and main.dart reads it on resume
    // For simplicity: store in shared prefs and let app handle on next open
  }

  static String _sanitize(String phone) =>
      phone.replaceAll(RegExp(r'[^0-9+]'), '');

  static Future<void> requestPermission(BuildContext context) async {
    if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } else if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  /// Schedules birthday notifications for all contacts with birthdays.
  static Future<void> scheduleBirthdayNotifications() async {
    await init();
    // Cancel existing birthday notifications (IDs 1000–1999)
    final pending = await _plugin.pendingNotificationRequests();
    for (final n in pending) {
      if (n.id >= 1000 && n.id < 2000) await _plugin.cancel(n.id);
    }

    final settings = StorageService.getSettings();
    if (!settings.birthdayReminderEnabled) return;

    final contacts = StorageService.getAllContacts();
    int id = 1000;
    final now = DateTime.now();

    for (final contact in contacts) {
      final birthday = contact.birthday;
      if (birthday == null) continue;

      // Next birthday occurrence minus daysBefore
      var nextBirthday = DateTime(
        now.year,
        birthday.month,
        birthday.day,
        settings.birthdayReminderHour,
        0,
      ).subtract(Duration(days: settings.birthdayReminderDaysBefore));

      if (nextBirthday.isBefore(now)) {
        nextBirthday = DateTime(
          now.year + 1,
          birthday.month,
          birthday.day,
          settings.birthdayReminderHour,
          0,
        ).subtract(Duration(days: settings.birthdayReminderDaysBefore));
      }

      final tzTime = tz.TZDateTime.from(nextBirthday, tz.local);
      final phone = contact.effectivePrimaryPhone;

      final daysBefore = settings.birthdayReminderDaysBefore;
      final title = daysBefore == 0
          ? '🎂 יום הולדת שמח!'
          : '🎂 יום הולדת בקרוב';
      final body = daysBefore == 0
          ? 'היום יום הולדתו/ה של ${contact.name}. שלח/י ברכה!'
          : 'עוד $daysBefore ימים יום הולדתו/ה של ${contact.name}';

      await _plugin.zonedSchedule(
        id++,
        title,
        body,
        tzTime,
        NotificationDetails(
          iOS: DarwinNotificationDetails(
            categoryIdentifier: 'birthday_greeting',
            sound: 'default',
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
          android: AndroidNotificationDetails(
            'birthdays_channel',
            'ימי הולדת',
            channelDescription: 'תזכורות לימי הולדת של אנשי הקשר',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            color: const Color(0xFF6C63FF),
          ),
        ),
        payload: 'phone:$phone',
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
      );
    }
  }

  /// Schedules anniversary notifications for all contacts with anniversaries.
  static Future<void> scheduleAnniversaryNotifications() async {
    await init();
    // Cancel existing anniversary notifications (IDs 3000–3999)
    final pending = await _plugin.pendingNotificationRequests();
    for (final n in pending) {
      if (n.id >= 3000 && n.id < 4000) await _plugin.cancel(n.id);
    }

    final settings = StorageService.getSettings();
    if (!settings.anniversaryReminderEnabled) return;

    final contacts = StorageService.getAllContacts();
    int id = 3000;
    final now = DateTime.now();

    for (final contact in contacts) {
      final ann = contact.anniversary;
      if (ann == null) continue;

      var nextAnn = DateTime(
        now.year,
        ann.month,
        ann.day,
        settings.anniversaryReminderHour,
        0,
      ).subtract(Duration(days: settings.anniversaryReminderDaysBefore));

      if (nextAnn.isBefore(now)) {
        nextAnn = DateTime(
          now.year + 1,
          ann.month,
          ann.day,
          settings.anniversaryReminderHour,
          0,
        ).subtract(Duration(days: settings.anniversaryReminderDaysBefore));
      }

      final tzTime = tz.TZDateTime.from(nextAnn, tz.local);
      final phone = contact.effectivePrimaryPhone;
      final years = (contact.completedAnniversaryYears ?? 0) +
          (settings.anniversaryReminderDaysBefore > 0 ? 1 : 0);

      final daysBefore = settings.anniversaryReminderDaysBefore;
      final title = daysBefore == 0
          ? '💍 יום נישואין שמח!'
          : '💍 יום נישואין בקרוב';
      final body = daysBefore == 0
          ? 'היום יום הנישואין של ${contact.name}! $years שנים נשואין 🎉'
          : 'עוד $daysBefore ימים יום הנישואין של ${contact.name}';

      await _plugin.zonedSchedule(
        id++,
        title,
        body,
        tzTime,
        NotificationDetails(
          iOS: DarwinNotificationDetails(
            sound: 'default',
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
          android: AndroidNotificationDetails(
            'anniversaries_channel',
            'ימי נישואין',
            channelDescription: 'תזכורות לימי נישואין של אנשי הקשר',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            color: const Color(0xFFE91E63),
          ),
        ),
        payload: 'phone:$phone',
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
      );
    }
  }

  // ── Friendship reminders ──────────────────────────────────────────────────

  static Future<void> scheduleFriendshipNotifications() async {
    if (!StorageService.friendshipReminderEnabled) return;
    await init();

    final pending = await _plugin.pendingNotificationRequests();
    for (final n in pending) {
      if (n.id >= 5000 && n.id < 6000) await _plugin.cancel(n.id);
    }

    final contacts = StorageService.getAllContacts();
    int id = 5000;
    final now = DateTime.now();
    final daysBefore = StorageService.friendshipReminderDaysBefore;
    final hour       = StorageService.friendshipReminderHour;

    for (final contact in contacts) {
      final friendship = contact.customEvents
          .where((e) => e.name == 'חברות')
          .firstOrNull;
      if (friendship == null) continue;
      final d = friendship.date;

      var next = DateTime(now.year, d.month, d.day, hour, 0)
          .subtract(Duration(days: daysBefore));
      if (next.isBefore(now)) {
        next = DateTime(now.year + 1, d.month, d.day, hour, 0)
            .subtract(Duration(days: daysBefore));
      }

      final nowYear = now.year;
      final years = nowYear - d.year +
          (!DateTime(nowYear, d.month, d.day).isAfter(DateTime(nowYear, now.month, now.day)) ? 0 : -1);

      final title = daysBefore == 0 ? '👥 יום חברות!' : '👥 יום חברות בקרוב';
      final body = daysBefore == 0
          ? 'היום ${years + 1} שנות חברות עם ${contact.name}! 🎉'
          : 'עוד $daysBefore ימים ${years + 1} שנות חברות עם ${contact.name}';

      await _plugin.zonedSchedule(
        id++, title, body,
        tz.TZDateTime.from(next, tz.local),
        NotificationDetails(
          iOS: const DarwinNotificationDetails(
              sound: 'default', presentAlert: true,
              presentBadge: true, presentSound: true),
          android: AndroidNotificationDetails(
            'friendship_channel', 'ימי חברות',
            channelDescription: 'תזכורות לימי חברות',
            importance: Importance.high, priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            color: const Color(0xFF42A5F5),
          ),
        ),
        payload: 'phone:${contact.effectivePrimaryPhone}',
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
      );
    }
  }

  // ── Custom event reminders ─────────────────────────────────────────────────

  static Future<void> scheduleCustomEventNotifications() async {
    await init();

    final pending = await _plugin.pendingNotificationRequests();
    for (final n in pending) {
      if (n.id >= 6000 && n.id < 7000) await _plugin.cancel(n.id);
    }

    final contacts = StorageService.getAllContacts();
    int id = 6000;
    final now = DateTime.now();
    final daysBefore = StorageService.customEventReminderDaysBefore;
    final hour       = StorageService.customEventReminderHour;

    for (final contact in contacts) {
      for (final ev in contact.customEvents) {
        if (ev.name == 'חברות') continue; // handled separately
        if (!ev.reminder) continue;
        if (!ev.yearly) {
          // One-time event: only if in the future
          final evDay = DateTime(ev.date.year, ev.date.month, ev.date.day, hour, 0)
              .subtract(Duration(days: daysBefore));
          if (evDay.isBefore(now)) continue;
          final title = '📅 ${ev.name}';
          final body = '${ev.name} של ${contact.name} בקרוב';
          await _plugin.zonedSchedule(
            id++, title, body,
            tz.TZDateTime.from(evDay, tz.local),
            _eventNotifDetails(),
            payload: 'phone:${contact.effectivePrimaryPhone}',
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
        } else {
          // Yearly recurring
          var next = DateTime(now.year, ev.date.month, ev.date.day, hour, 0)
              .subtract(Duration(days: daysBefore));
          if (next.isBefore(now)) {
            next = DateTime(now.year + 1, ev.date.month, ev.date.day, hour, 0)
                .subtract(Duration(days: daysBefore));
          }
          final title = '📅 ${ev.name}';
          final body = daysBefore == 0
              ? 'היום ${ev.name} של ${contact.name}!'
              : 'עוד $daysBefore ימים ${ev.name} של ${contact.name}';
          await _plugin.zonedSchedule(
            id++, title, body,
            tz.TZDateTime.from(next, tz.local),
            _eventNotifDetails(),
            payload: 'phone:${contact.effectivePrimaryPhone}',
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
          );
        }
      }
    }
  }

  static NotificationDetails _eventNotifDetails() => NotificationDetails(
        iOS: const DarwinNotificationDetails(
            sound: 'default', presentAlert: true,
            presentBadge: true, presentSound: true),
        android: AndroidNotificationDetails(
          'events_channel', 'אירועים מותאמים',
          channelDescription: 'תזכורות לאירועים אישיים',
          importance: Importance.high, priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFF6C63FF),
        ),
      );

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

      final notifyAt =
          tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5));
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
