import 'package:hive/hive.dart';

part 'app_contact.g.dart';

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

  AppContact({
    required this.id,
    required this.name,
    required this.primaryPhone,
    List<String>? phones,
    this.email,
    this.whatsappPhone,
    this.localPhotoPath,
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

  DateTime? get lastContactedAt =>
      lastContactedMillis != null ? DateTime.fromMillisecondsSinceEpoch(lastContactedMillis!) : null;

  /// Returns true if birthday is this month (ignoring year)
  bool get birthdayThisMonth {
    final b = birthday;
    if (b == null) return false;
    final now = DateTime.now();
    return b.month == now.month;
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
