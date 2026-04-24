import 'dart:convert';
import 'package:hive/hive.dart';

part 'app_contact.g.dart';

// ── Custom event (not Hive-registered — stored as JSON string) ─────────────

class ContactEvent {
  final String name;
  final DateTime date;
  final bool yearly;
  /// Whether the user wants a push-notification reminder for this event.
  final bool reminder;

  const ContactEvent({
    required this.name,
    required this.date,
    this.yearly = true,
    this.reminder = false,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'millis': date.millisecondsSinceEpoch,
        'yearly': yearly,
        'reminder': reminder,
      };

  static ContactEvent? tryFromMap(dynamic map) {
    if (map is! Map) return null;
    try {
      return ContactEvent(
        name: (map['name'] as String?) ?? '',
        date: DateTime.fromMillisecondsSinceEpoch(
            (map['millis'] as num).toInt()),
        yearly: map['yearly'] as bool? ?? true,
        reminder: map['reminder'] as bool? ?? false,
      );
    } catch (_) {
      return null;
    }
  }

  /// Days until next occurrence (0 = today). null = one-time event in the past.
  int? get daysUntil {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    if (yearly) {
      var next = DateTime(today.year, date.month, date.day);
      if (next.isBefore(todayOnly)) {
        next = DateTime(today.year + 1, date.month, date.day);
      }
      return next.difference(todayOnly).inDays;
    } else {
      final eventDay = DateTime(date.year, date.month, date.day);
      if (eventDay.isBefore(todayOnly)) return null;
      return eventDay.difference(todayOnly).inDays;
    }
  }
}

@HiveType(typeId: 0)
class AppContact extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String name;

  /// Legacy field – kept for backward-compat. Use [effectivePrimaryPhone].
  @HiveField(2)
  late String primaryPhone;

  /// All phone numbers. Index [primaryPhoneIndex] is the primary.
  @HiveField(3)
  late List<String> phones;

  /// Legacy single email – kept for backward-compat. Use [emails].
  @HiveField(4)
  String? email;

  /// Deprecated – WhatsApp always derives from the primary phone.
  @HiveField(5)
  String? whatsappPhone;

  @HiveField(6)
  String? localPhotoPath;

  @HiveField(7)
  late List<String> categoryIds;

  @HiveField(8)
  int sortOrder;

  @HiveField(9)
  String? notes;

  /// Label per phone: 'נייד' | 'עבודה' | 'בית' | 'כללי'
  @HiveField(10)
  List<String> phoneLabels;

  /// Which index in [phones] is the primary number.
  @HiveField(11)
  int primaryPhoneIndex;

  /// All email addresses.
  @HiveField(12)
  List<String> emails;

  /// Label per email: 'עבודה' | 'בית' | 'כללי'
  @HiveField(13)
  List<String> emailLabels;

  @HiveField(14)
  String? nickname;

  @HiveField(15)
  int? birthdayMillis;

  @HiveField(16)
  int? lastContactedMillis;

  @HiveField(17)
  int? anniversaryMillis;

  /// Full original photo before any crop/adjust — used so the editor always
  /// starts from the unedited source image.
  @HiveField(18)
  String? originalPhotoPath;

  /// Full address string (street, city, zip, country).
  @HiveField(19)
  String? address;

  /// Custom events encoded as JSON list: [{"name":..., "millis":..., "yearly":...}]
  @HiveField(20)
  String? customEventsJson;

  AppContact({
    required this.id,
    required this.name,
    required this.primaryPhone,
    List<String>? phones,
    this.email,
    this.whatsappPhone,
    this.localPhotoPath,
    this.originalPhotoPath,
    this.address,
    this.customEventsJson,
    List<String>? categoryIds,
    this.sortOrder = 0,
    this.notes,
    List<String>? phoneLabels,
    this.primaryPhoneIndex = 0,
    List<String>? emails,
    List<String>? emailLabels,
    this.nickname,
    this.birthdayMillis,
    this.lastContactedMillis,
    this.anniversaryMillis,
  })  : phones = phones ?? [],
        categoryIds = categoryIds ?? [],
        phoneLabels = phoneLabels ?? [],
        emails = emails ?? [],
        emailLabels = emailLabels ?? [];

  /// The effective primary phone number.
  String get effectivePrimaryPhone {
    if (phones.isNotEmpty) {
      return phones[primaryPhoneIndex.clamp(0, phones.length - 1)];
    }
    return primaryPhone;
  }

  /// The effective first email.
  String? get effectiveEmail {
    if (emails.isNotEmpty) return emails.first;
    return email;
  }

  DateTime? get birthday =>
      birthdayMillis != null ? DateTime.fromMillisecondsSinceEpoch(birthdayMillis!) : null;

  DateTime? get anniversary =>
      anniversaryMillis != null ? DateTime.fromMillisecondsSinceEpoch(anniversaryMillis!) : null;

  DateTime? get lastContactedAt =>
      lastContactedMillis != null ? DateTime.fromMillisecondsSinceEpoch(lastContactedMillis!) : null;

  /// Returns true if birthday is this month (ignoring year)
  bool get birthdayThisMonth {
    final b = birthday;
    if (b == null) return false;
    final now = DateTime.now();
    return b.month == now.month;
  }

  /// Days until next birthday (0 = today)
  int? get daysUntilBirthday {
    final b = birthday;
    if (b == null) return null;
    final now = DateTime.now();
    var next = DateTime(now.year, b.month, b.day);
    if (next.isBefore(DateTime(now.year, now.month, now.day))) {
      next = DateTime(now.year + 1, b.month, b.day);
    }
    return next.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  /// Days until next anniversary occurrence (0 = today).
  int? get daysUntilAnniversary {
    final a = anniversary;
    if (a == null) return null;
    final now = DateTime.now();
    var next = DateTime(now.year, a.month, a.day);
    if (next.isBefore(DateTime(now.year, now.month, now.day))) {
      next = DateTime(now.year + 1, a.month, a.day);
    }
    return next.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  /// Completed years since birthday (the person's current age).
  int? get completedBirthdayYears {
    final b = birthday;
    if (b == null) return null;
    final now = DateTime.now();
    final passed = !DateTime(now.year, b.month, b.day)
        .isAfter(DateTime(now.year, now.month, now.day));
    return now.year - b.year - (passed ? 0 : 1);
  }

  /// Completed years since anniversary (accounts for whether date passed yet).
  int? get completedAnniversaryYears {
    final a = anniversary;
    if (a == null) return null;
    final now = DateTime.now();
    final passed = !DateTime(now.year, a.month, a.day)
        .isAfter(DateTime(now.year, now.month, now.day));
    return now.year - a.year - (passed ? 0 : 1);
  }

  /// Address split into [street, city, zipCode].
  /// Stored as "\n"-separated string for backward-compat with the single-string
  /// address format used in earlier versions.
  List<String> get addressParts {
    if (address == null || address!.isEmpty) return ['', '', ''];
    final parts = address!.split('\n');
    return [
      parts.isNotEmpty ? parts[0] : '',
      parts.length > 1 ? parts[1] : '',
      parts.length > 2 ? parts[2] : '',
    ];
  }

  /// Human-readable formatted address for display and map navigation.
  String? get formattedAddress {
    if (address == null || address!.isEmpty) return null;
    final parts = addressParts;
    final visible = parts.where((s) => s.isNotEmpty).toList();
    return visible.isEmpty ? null : visible.join(', ');
  }

  /// Decoded list of custom events.
  List<ContactEvent> get customEvents {
    if (customEventsJson == null || customEventsJson!.isEmpty) return [];
    try {
      final list = jsonDecode(customEventsJson!) as List;
      return list
          .map((e) => ContactEvent.tryFromMap(e))
          .whereType<ContactEvent>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Human-readable "last contacted" string (Hebrew)
  String? get lastContactedLabel {
    final lc = lastContactedAt;
    if (lc == null) return null;
    final diff = DateTime.now().difference(lc);
    if (diff.inMinutes < 60) return 'לפני ${diff.inMinutes} דק\'';
    if (diff.inHours < 24) return 'לפני ${diff.inHours} שע\'';
    if (diff.inDays == 1) return 'אתמול';
    if (diff.inDays < 7) return 'לפני ${diff.inDays} ימים';
    if (diff.inDays < 30) return 'לפני ${(diff.inDays / 7).round()} שבועות';
    if (diff.inDays < 365) return 'לפני ${(diff.inDays / 30).round()} חודשים';
    return 'לפני יותר משנה';
  }
}
