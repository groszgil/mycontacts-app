import 'package:flutter_contacts/flutter_contacts.dart';
import '../models/app_contact.dart';
import 'storage_service.dart';

class SyncChange {
  final AppContact appContact;
  final String? newName;        // null if unchanged
  final List<String>? newPhones; // null if unchanged

  SyncChange({required this.appContact, this.newName, this.newPhones});

  bool get hasChanges => newName != null || newPhones != null;
}

class SyncResult {
  final List<SyncChange> changes;
  final List<Contact> newPhoneContacts;

  SyncResult({required this.changes, required this.newPhoneContacts});

  bool get hasAnything => changes.isNotEmpty || newPhoneContacts.isNotEmpty;
}

class ContactSyncService {
  static Future<SyncResult> checkForChanges() async {
    // Check permission without requesting
    final status = await FlutterContacts.permissions.request(PermissionType.read);
    final granted = status == PermissionStatus.granted || status == PermissionStatus.limited;
    if (!granted) return SyncResult(changes: [], newPhoneContacts: []);

    // Fetch phone contacts with phones
    final phoneContacts = await FlutterContacts.getAll(
      properties: {ContactProperty.phone, ContactProperty.name},
    );
    final phoneMap = {for (final c in phoneContacts) c.id: c};

    final syncMap = StorageService.getSyncMap(); // appContactId → phoneContactId
    final allAppContacts = StorageService.getAllContacts();
    final appContactMap = {for (final c in allAppContacts) c.id: c};

    // 1. Check changed contacts
    final changes = <SyncChange>[];
    for (final entry in syncMap.entries) {
      final appContact = appContactMap[entry.key];
      if (appContact == null) continue; // deleted from app
      final phoneContact = phoneMap[entry.value];
      if (phoneContact == null) continue; // deleted from phone

      String? newName;
      List<String>? newPhones;

      final phoneName = phoneContact.displayName ?? '';
      if (phoneName.isNotEmpty && phoneName != appContact.name) {
        newName = phoneName;
      }

      final phoneNumbers = phoneContact.phones.map((p) => p.number).toList();
      final appPhones = List<String>.from(appContact.phones);
      if (phoneNumbers.isNotEmpty && !_listsEqual(phoneNumbers, appPhones)) {
        newPhones = phoneNumbers;
      }

      if (newName != null || newPhones != null) {
        changes.add(SyncChange(
          appContact: appContact,
          newName: newName,
          newPhones: newPhones,
        ));
      }
    }

    // 2. Find truly NEW phone contacts — those whose ID was not seen during
    //    the previous sync run.  On the very first run we snapshot all IDs
    //    without reporting any "new" ones (otherwise the user would be
    //    bombarded with every contact they ever had on their phone).
    final knownIds = StorageService.getKnownPhoneContactIds();
    final currentIds = Set<String>.from(
        phoneContacts.map((c) => c.id ?? '').where((id) => id.isNotEmpty));

    List<Contact> newContacts;
    if (knownIds.isEmpty) {
      // First sync run — just snapshot, report nothing new.
      newContacts = [];
    } else {
      newContacts = phoneContacts
          .where((c) =>
              c.phones.isNotEmpty &&
              !knownIds.contains(c.id ?? '') &&
              (c.displayName ?? '').isNotEmpty)
          .toList();
    }

    // Always update the snapshot so the next run is accurate.
    await StorageService.saveKnownPhoneContactIds(currentIds);

    return SyncResult(changes: changes, newPhoneContacts: newContacts);
  }

  static bool _listsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static Future<void> applyChange(SyncChange change) async {
    final c = change.appContact;
    if (change.newName != null) c.name = change.newName!;
    if (change.newPhones != null) {
      c.phones = change.newPhones!;
      c.primaryPhone = change.newPhones!.first;
      c.primaryPhoneIndex = 0;
    }
    await StorageService.saveContact(c);
  }
}
