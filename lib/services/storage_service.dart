import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../models/app_contact.dart';
import '../models/category.dart';
import '../models/app_settings.dart';

class StorageService {
  static const String _contactsBox = 'contacts';
  static const String _categoriesBox = 'categories';
  static const String _settingsBox = 'settings';
  static const String _appGroup = 'group.com.mycontacts.myContacts';

  /// Cached documents directory path — resolved once at init, used for photo
  /// path resolution so we don't need async in widget builds.
  static String? _appDocPath;

  // ── App JSON config (emergency contact + biometric lock) ─────────────────

  static Map<String, dynamic>? _cachedConfig;

  static String get _configPath =>
      p.join(_appDocPath!, '.app_config.json');

  static Map<String, dynamic> _readConfig() {
    if (_cachedConfig != null) return _cachedConfig!;
    try {
      final f = File(_configPath);
      if (!f.existsSync()) return _cachedConfig = {};
      _cachedConfig = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      return _cachedConfig!;
    } catch (_) {
      return _cachedConfig = {};
    }
  }

  static Future<void> _writeConfig(Map<String, dynamic> config) async {
    _cachedConfig = Map<String, dynamic>.from(config);
    await File(_configPath).writeAsString(jsonEncode(config));
  }

  /// Notifier for emergency SOS feature — updated whenever config changes.
  static final ValueNotifier<bool> emergencyEnabledNotifier =
      ValueNotifier(false);

  /// Notifier for app lock feature — updated whenever config changes.
  static final ValueNotifier<bool> appLockEnabledNotifier =
      ValueNotifier(false);

  // ── Emergency contact ─────────────────────────────────────────────────────

  static bool get isEmergencyEnabled {
    if (_appDocPath == null) return false;
    return _readConfig()['emergencyEnabled'] as bool? ?? false;
  }

  static String? get emergencyContactName {
    if (_appDocPath == null) return null;
    return _readConfig()['emergencyName'] as String?;
  }

  static String? get emergencyContactPhone {
    if (_appDocPath == null) return null;
    return _readConfig()['emergencyPhone'] as String?;
  }

  static Future<void> setEmergencyConfig({
    required bool enabled,
    String? name,
    String? phone,
  }) async {
    final c = _readConfig();
    c['emergencyEnabled'] = enabled;
    if (name != null) c['emergencyName'] = name;
    if (phone != null) c['emergencyPhone'] = phone;
    await _writeConfig(c);
    emergencyEnabledNotifier.value = enabled;
    // Sync to the shared App Group so the iOS widget can read it
    await _updateEmergencyWidget(
      enabled: enabled,
      name: c['emergencyName'] as String? ?? '',
      phone: c['emergencyPhone'] as String? ?? '',
    );
  }

  static Future<void> _updateEmergencyWidget({
    required bool enabled,
    required String name,
    required String phone,
  }) async {
    try {
      await HomeWidget.saveWidgetData<String>(
        'emergency_json',
        jsonEncode({'name': name, 'phone': phone, 'enabled': enabled}),
      );
      await HomeWidget.updateWidget(
        name: 'EmergencyWidget',
        iOSName: 'EmergencyWidget',
      );
    } catch (_) {}
  }

  // ── Friendship reminder ───────────────────────────────────────────────────

  static bool get friendshipReminderEnabled {
    if (_appDocPath == null) return false;
    return _readConfig()['friendshipReminderEnabled'] as bool? ?? false;
  }

  static int get friendshipReminderDaysBefore {
    if (_appDocPath == null) return 0;
    return (_readConfig()['friendshipReminderDaysBefore'] as num?)?.toInt() ?? 0;
  }

  static int get friendshipReminderHour {
    if (_appDocPath == null) return 9;
    return (_readConfig()['friendshipReminderHour'] as num?)?.toInt() ?? 9;
  }

  static Future<void> setFriendshipReminder({
    required bool enabled,
    int? daysBefore,
    int? hour,
  }) async {
    final c = _readConfig();
    c['friendshipReminderEnabled'] = enabled;
    if (daysBefore != null) c['friendshipReminderDaysBefore'] = daysBefore;
    if (hour != null) c['friendshipReminderHour'] = hour;
    await _writeConfig(c);
  }

  // ── Custom event reminder timing (global) ─────────────────────────────────

  static int get customEventReminderDaysBefore {
    if (_appDocPath == null) return 0;
    return (_readConfig()['customEventReminderDaysBefore'] as num?)?.toInt() ?? 0;
  }

  static int get customEventReminderHour {
    if (_appDocPath == null) return 9;
    return (_readConfig()['customEventReminderHour'] as num?)?.toInt() ?? 9;
  }

  static Future<void> setCustomEventReminderTiming({
    int? daysBefore,
    int? hour,
  }) async {
    final c = _readConfig();
    if (daysBefore != null) c['customEventReminderDaysBefore'] = daysBefore;
    if (hour != null) c['customEventReminderHour'] = hour;
    await _writeConfig(c);
  }

  // ── App lock ──────────────────────────────────────────────────────────────

  static bool get isAppLockEnabled {
    if (_appDocPath == null) return false;
    return _readConfig()['appLockEnabled'] as bool? ?? false;
  }

  static Future<void> setAppLockEnabled(bool enabled) async {
    final c = _readConfig();
    c['appLockEnabled'] = enabled;
    await _writeConfig(c);
    appLockEnabledNotifier.value = enabled;
  }

  /// Resolves a stored photo path to a valid absolute path.
  ///
  /// On iOS the app-container UUID can change between installs/restores, making
  /// stored absolute paths invalid. We try the stored path first; if it doesn't
  /// exist we reconstruct from the cached docs dir + filename.
  static String? resolvePhotoPath(String? stored) {
    if (stored == null) return null;
    if (File(stored).existsSync()) return stored;
    // Attempt to fix a stale absolute path by re-joining the filename
    if (_appDocPath != null) {
      final filename = p.basename(stored);
      if (filename.isNotEmpty) {
        final reconstructed = p.join(_appDocPath!, filename);
        if (File(reconstructed).existsSync()) return reconstructed;
      }
    }
    return null; // file genuinely missing
  }

  static Future<void> init() async {
    await Hive.initFlutter();
    _appDocPath = (await getApplicationDocumentsDirectory()).path;

    // Pre-load config and initialise ValueNotifiers so widgets can read them synchronously
    final cfg = _readConfig();
    emergencyEnabledNotifier.value = cfg['emergencyEnabled'] as bool? ?? false;
    appLockEnabledNotifier.value   = cfg['appLockEnabled']   as bool? ?? false;

    // Guard against duplicate registration (e.g. hot restart in dev)
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(AppContactAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(CategoryAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(AppSettingsAdapter());

    if (!Hive.isBoxOpen(_contactsBox)) {
      await Hive.openBox<AppContact>(_contactsBox);
    }
    if (!Hive.isBoxOpen(_categoriesBox)) {
      await Hive.openBox<Category>(_categoriesBox);
    }
    if (!Hive.isBoxOpen(_settingsBox)) {
      await Hive.openBox<AppSettings>(_settingsBox);
    }

    await _seedDefaultCategory();

    // Initialise home widget app group
    await HomeWidget.setAppGroupId(_appGroup);
  }

  static Future<void> _seedDefaultCategory() async {
    final box = Hive.box<Category>(_categoriesBox);
    if (box.isEmpty) {
      await box.put('all', Category(
        id: 'all',
        name: 'הכל',
        colorValue: 0xFF6C63FF,
        sortOrder: 0,
      ));
    }
  }

  // ── Contacts ──────────────────────────────────────────────────────────────

  static Box<AppContact> get contactsBox => Hive.box<AppContact>(_contactsBox);

  static List<AppContact> getAllContacts() {
    return contactsBox.values.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  static List<AppContact> getContactsByCategory(String categoryId) {
    if (categoryId == 'all') return getAllContacts();
    return getAllContacts()
        .where((c) => c.categoryIds.contains(categoryId))
        .toList();
  }

  static Future<void> saveContact(AppContact contact) async {
    await contactsBox.put(contact.id, contact);
    await _updateHomeWidget();
  }

  static Future<void> deleteContact(String id) async {
    await contactsBox.delete(id);
    await _updateHomeWidget();
  }

  static Future<void> updateSortOrders(List<AppContact> contacts) async {
    for (int i = 0; i < contacts.length; i++) {
      contacts[i].sortOrder = i;
      await contacts[i].save();
    }
    await _updateHomeWidget();
  }

  // ── Categories ────────────────────────────────────────────────────────────

  static Box<Category> get categoriesBox => Hive.box<Category>(_categoriesBox);

  static List<Category> getAllCategories() {
    final cats = categoriesBox.values.toList();
    cats.sort((a, b) {
      // "הכל" (id == 'all') always goes last
      if (a.id == 'all') return 1;
      if (b.id == 'all') return -1;
      return a.sortOrder.compareTo(b.sortOrder);
    });
    return cats;
  }

  static Future<void> saveCategory(Category category) async {
    await categoriesBox.put(category.id, category);
  }

  static Future<void> deleteCategory(String id) async {
    if (id == 'all') return;
    await categoriesBox.delete(id);
    for (final contact in contactsBox.values) {
      if (contact.categoryIds.contains(id)) {
        contact.categoryIds.remove(id);
        await contact.save();
      }
    }
  }

  // ── Settings ──────────────────────────────────────────────────────────────

  static Box<AppSettings> get settingsBox => Hive.box<AppSettings>(_settingsBox);

  static AppSettings getSettings() {
    return settingsBox.get('settings', defaultValue: AppSettings())!;
  }

  static Future<void> saveSettings(AppSettings settings) async {
    await settingsBox.put('settings', settings);
  }

  // ── Contact sync map ─────────────────────────────────────────────────────

  /// Get sync map: appContactId → phoneContactId
  static Map<String, String> getSyncMap() {
    final raw = _readConfig()['syncMap'];
    if (raw is Map) return Map<String, String>.from(raw.map((k, v) => MapEntry(k.toString(), v.toString())));
    return {};
  }

  /// Add a mapping when importing a contact
  static Future<void> addToSyncMap(String appContactId, String phoneContactId) async {
    final cfg = Map<String, dynamic>.from(_readConfig());
    final map = getSyncMap();
    map[appContactId] = phoneContactId;
    cfg['syncMap'] = map;
    // Also track all imported phone IDs
    final imported = Set<String>.from((cfg['importedPhoneIds'] as List? ?? []).map((e) => e.toString()));
    imported.add(phoneContactId);
    cfg['importedPhoneIds'] = imported.toList();
    await _writeConfig(cfg);
  }

  /// Remove from sync map (when contact is deleted)
  static Future<void> removeFromSyncMap(String appContactId) async {
    final cfg = Map<String, dynamic>.from(_readConfig());
    final map = getSyncMap();
    map.remove(appContactId);
    cfg['syncMap'] = map;
    await _writeConfig(cfg);
  }

  /// Get set of all phone contact IDs that were ever imported
  static Set<String> getImportedPhoneIds() {
    final raw = _readConfig()['importedPhoneIds'];
    if (raw is List) return Set<String>.from(raw.map((e) => e.toString()));
    return {};
  }

  // ── One-time permission rationale flag ───────────────────────────────────

  /// Returns true if the contacts-permission rationale screen has already been
  /// shown to the user (marker file exists in the app documents folder).
  static bool get hasShownContactsRationale {
    if (_appDocPath == null) return false;
    return File(p.join(_appDocPath!, '.contacts_explained')).existsSync();
  }

  /// Persists the "rationale shown" marker so we never show it again.
  static Future<void> markContactsRationaleShown() async {
    if (_appDocPath == null) return;
    final marker = File(p.join(_appDocPath!, '.contacts_explained'));
    if (!marker.existsSync()) await marker.create();
  }

  // ── First-launch flag ─────────────────────────────────────────────────────

  /// True when the app has never been opened before (no marker file exists).
  static bool get isFirstLaunch {
    if (_appDocPath == null) return false;
    return !File(p.join(_appDocPath!, '.first_launch_done')).existsSync();
  }

  /// Marks the first launch as complete so the prompt never shows again.
  static Future<void> markFirstLaunchDone() async {
    if (_appDocPath == null) return;
    final marker = File(p.join(_appDocPath!, '.first_launch_done'));
    if (!marker.existsSync()) await marker.create();
  }

  // ── Known phone contact IDs (for new-contact sync detection) ─────────────

  /// Returns the set of phone-contact IDs that were present on the device at
  /// the time of the last sync check. Any ID not in this set is "new".
  static Set<String> getKnownPhoneContactIds() {
    final raw = _readConfig()['knownPhoneContactIds'];
    if (raw is List) {
      return Set<String>.from(raw.map((e) => e.toString()));
    }
    return {};
  }

  /// Saves the current set of phone-contact IDs so we can detect new ones
  /// on the next app open.
  static Future<void> saveKnownPhoneContactIds(Set<String> ids) async {
    final cfg = Map<String, dynamic>.from(_readConfig());
    cfg['knownPhoneContactIds'] = ids.toList();
    await _writeConfig(cfg);
  }

  // ── Backup ────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> exportToJson() async {
    final contactList = getAllContacts();
    final contacts = <Map<String, dynamic>>[];

    for (final c in contactList) {
      // Encode display photo as base64
      String? photoBase64;
      if (c.localPhotoPath != null) {
        final f = File(c.localPhotoPath!);
        if (await f.exists()) {
          photoBase64 = base64Encode(await f.readAsBytes());
        }
      }

      // Encode original photo if different from display photo
      String? originalPhotoBase64;
      if (c.originalPhotoPath != null &&
          c.originalPhotoPath != c.localPhotoPath) {
        final f = File(c.originalPhotoPath!);
        if (await f.exists()) {
          originalPhotoBase64 = base64Encode(await f.readAsBytes());
        }
      }

      contacts.add({
        'id': c.id,
        'name': c.name,
        'primaryPhone': c.effectivePrimaryPhone,
        'phones': c.phones,
        'phoneLabels': c.phoneLabels,
        'primaryPhoneIndex': c.primaryPhoneIndex,
        'emails': c.emails,
        'emailLabels': c.emailLabels,
        'categoryIds': c.categoryIds,
        'sortOrder': c.sortOrder,
        'notes': c.notes,
        'nickname': c.nickname,
        'birthdayMillis': c.birthdayMillis,
        'anniversaryMillis': c.anniversaryMillis,
        'lastContactedMillis': c.lastContactedMillis,
        if (c.address != null) 'address': c.address,
        if (c.customEventsJson != null) 'customEventsJson': c.customEventsJson,
        if (photoBase64 != null) 'photoBase64': photoBase64,
        if (originalPhotoBase64 != null)
          'originalPhotoBase64': originalPhotoBase64,
      });
    }

    final categories = getAllCategories().map((c) => {
      'id': c.id,
      'name': c.name,
      'colorValue': c.colorValue,
      'sortOrder': c.sortOrder,
    }).toList();

    return {
      'version': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'contacts': contacts,
      'categories': categories,
    };
  }

  static Future<void> importFromJson(String jsonStr) async {
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    final appDir = await getApplicationDocumentsDirectory();

    final cats = data['categories'] as List<dynamic>? ?? [];
    for (final c in cats) {
      final cat = Category(
        id: c['id'] as String,
        name: c['name'] as String,
        colorValue: (c['colorValue'] as num).toInt(),
        sortOrder: (c['sortOrder'] as num?)?.toInt() ?? 0,
      );
      await categoriesBox.put(cat.id, cat);
    }

    final contacts = data['contacts'] as List<dynamic>? ?? [];
    for (final c in contacts) {
      final contactId = c['id'] as String;
      // Check if contact already exists (to preserve photos from old backups)
      final existing = contactsBox.get(contactId);

      // Restore display photo from base64
      String? localPhotoPath;
      final photoBase64 = c['photoBase64'] as String?;
      if (photoBase64 != null) {
        try {
          final bytes = base64Decode(photoBase64);
          final file = File(p.join(appDir.path,
              'contact_import_${const Uuid().v4()}.jpg'));
          await file.writeAsBytes(bytes);
          localPhotoPath = file.path;
        } catch (_) {}
      }

      // If backup has no photo but contact already exists with a valid photo → keep it
      if (localPhotoPath == null &&
          existing?.localPhotoPath != null &&
          File(existing!.localPhotoPath!).existsSync()) {
        localPhotoPath = existing.localPhotoPath;
      }

      // Restore original photo from base64 (if exported separately)
      String? originalPhotoPath;
      final origBase64 = c['originalPhotoBase64'] as String?;
      if (origBase64 != null) {
        try {
          final bytes = base64Decode(origBase64);
          final file = File(p.join(appDir.path,
              'contact_orig_import_${const Uuid().v4()}.jpg'));
          await file.writeAsBytes(bytes);
          originalPhotoPath = file.path;
        } catch (_) {}
      } else if (existing?.originalPhotoPath != null &&
          File(existing!.originalPhotoPath!).existsSync()) {
        // Preserve existing original photo
        originalPhotoPath = existing.originalPhotoPath;
      } else {
        // No separate original → use display photo as original too
        originalPhotoPath = localPhotoPath;
      }

      final contact = AppContact(
        id: c['id'] as String,
        name: c['name'] as String,
        primaryPhone: c['primaryPhone'] as String? ?? '',
        phones: (c['phones'] as List?)?.cast<String>() ?? [],
        phoneLabels: (c['phoneLabels'] as List?)?.cast<String>() ?? [],
        primaryPhoneIndex: (c['primaryPhoneIndex'] as num?)?.toInt() ?? 0,
        emails: (c['emails'] as List?)?.cast<String>() ?? [],
        emailLabels: (c['emailLabels'] as List?)?.cast<String>() ?? [],
        categoryIds: (c['categoryIds'] as List?)?.cast<String>() ?? [],
        sortOrder: (c['sortOrder'] as num?)?.toInt() ?? 0,
        notes: c['notes'] as String?,
        nickname: c['nickname'] as String?,
        birthdayMillis: (c['birthdayMillis'] as num?)?.toInt(),
        anniversaryMillis: (c['anniversaryMillis'] as num?)?.toInt(),
        lastContactedMillis: (c['lastContactedMillis'] as num?)?.toInt(),
        address: c['address'] as String?,
        customEventsJson: c['customEventsJson'] as String?,
        localPhotoPath: localPhotoPath,
        originalPhotoPath: originalPhotoPath,
      );
      await contactsBox.put(contact.id, contact);
    }

    await _updateHomeWidget();
  }

  // ── Birthday / Contact helpers ────────────────────────────────────────────

  /// Returns contacts whose birthday falls in the current month.
  static List<AppContact> getContactsBirthdayThisMonth() {
    return getAllContacts().where((c) => c.birthdayThisMonth).toList();
  }

  /// Updates the lastContactedMillis for a contact and saves it.
  static Future<void> markContacted(String contactId) async {
    final contact = contactsBox.get(contactId);
    if (contact == null) return;
    contact.lastContactedMillis = DateTime.now().millisecondsSinceEpoch;
    await contact.save();
  }

  /// Finds groups of potential duplicate contacts (same name or same phone).
  static List<List<AppContact>> findDuplicates() {
    final contacts = getAllContacts();
    final groups = <List<AppContact>>[];
    final used = <String>{};

    for (int i = 0; i < contacts.length; i++) {
      if (used.contains(contacts[i].id)) continue;
      final group = <AppContact>[contacts[i]];
      for (int j = i + 1; j < contacts.length; j++) {
        if (used.contains(contacts[j].id)) continue;
        if (_areDuplicates(contacts[i], contacts[j])) {
          group.add(contacts[j]);
        }
      }
      if (group.length > 1) {
        groups.add(group);
        for (final c in group) used.add(c.id);
      }
    }
    return groups;
  }

  static bool _areDuplicates(AppContact a, AppContact b) {
    // Same primary phone
    if (a.effectivePrimaryPhone.isNotEmpty &&
        a.effectivePrimaryPhone == b.effectivePrimaryPhone) return true;
    // Same phone in any phones list
    for (final p in a.phones) {
      if (p.isNotEmpty && b.phones.contains(p)) return true;
    }
    // Very similar name (normalized)
    final na = a.name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final nb = b.name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (na == nb) return true;
    return false;
  }

  /// Merges a list of contacts into the first one, deleting the rest.
  static Future<void> mergeContacts(List<AppContact> contacts) async {
    if (contacts.length < 2) return;
    final primary = contacts.first;
    final toDelete = contacts.skip(1).toList();

    // Merge phones, emails, categories from duplicates
    for (final dup in toDelete) {
      for (int i = 0; i < dup.phones.length; i++) {
        final phone = dup.phones[i];
        if (phone.isNotEmpty && !primary.phones.contains(phone)) {
          primary.phones.add(phone);
          primary.phoneLabels.add(
            i < dup.phoneLabels.length ? dup.phoneLabels[i] : 'נייד');
        }
      }
      for (int i = 0; i < dup.emails.length; i++) {
        final email = dup.emails[i];
        if (email.isNotEmpty && !primary.emails.contains(email)) {
          primary.emails.add(email);
          primary.emailLabels.add(
            i < dup.emailLabels.length ? dup.emailLabels[i] : 'כללי');
        }
      }
      for (final catId in dup.categoryIds) {
        if (!primary.categoryIds.contains(catId)) {
          primary.categoryIds.add(catId);
        }
      }
      // Keep notes
      if (primary.notes == null && dup.notes != null) {
        primary.notes = dup.notes;
      } else if (dup.notes != null && dup.notes!.isNotEmpty) {
        primary.notes = '${primary.notes ?? ''}\n${dup.notes!}'.trim();
      }
    }

    await contactsBox.put(primary.id, primary);
    for (final dup in toDelete) {
      await contactsBox.delete(dup.id);
    }
    await _updateHomeWidget();
  }

  // ── Home Widget ───────────────────────────────────────────────────────────

  static Future<void> _updateHomeWidget() async {
    try {
      final contacts = getAllContacts().take(8).map((c) => {
        'name': c.name,
        'phone': c.effectivePrimaryPhone,
        'initials': _initials(c.name),
      }).toList();
      await HomeWidget.saveWidgetData<String>(
          'contacts_json', jsonEncode(contacts));
      await HomeWidget.updateWidget(
        name: 'ContactsWidget',
        iOSName: 'ContactsWidget',
      );
    } catch (_) {
      // Widget not set up yet — fail silently
    }
  }

  static String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}';
    }
    return name.isNotEmpty ? name[0] : '?';
  }
}
