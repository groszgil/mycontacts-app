import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:home_widget/home_widget.dart';
import '../models/app_contact.dart';
import '../models/category.dart';
import '../models/app_settings.dart';

class StorageService {
  static const String _contactsBox = 'contacts';
  static const String _categoriesBox = 'categories';
  static const String _settingsBox = 'settings';
  static const String _appGroup = 'group.com.mycontacts.myContacts';

  static Future<void> init() async {
    await Hive.initFlutter();

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

  // ── Backup ────────────────────────────────────────────────────────────────

  static Map<String, dynamic> exportToJson() {
    final contacts = getAllContacts().map((c) => {
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
      'lastContactedMillis': c.lastContactedMillis,
    }).toList();

    final categories = getAllCategories().map((c) => {
      'id': c.id,
      'name': c.name,
      'colorValue': c.colorValue,
      'sortOrder': c.sortOrder,
    }).toList();

    return {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'contacts': contacts,
      'categories': categories,
    };
  }

  static Future<void> importFromJson(String jsonStr) async {
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;

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
        lastContactedMillis: (c['lastContactedMillis'] as num?)?.toInt(),
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
      return '${parts.last[0]}${parts.first[0]}';
    }
    return name.isNotEmpty ? name[0] : '?';
  }
}
