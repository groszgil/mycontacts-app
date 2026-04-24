import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../services/storage_service.dart';
import '../utils/theme.dart';
import 'add_edit_contact_screen.dart';

class ImportContactsScreen extends StatefulWidget {
  const ImportContactsScreen({super.key});

  @override
  State<ImportContactsScreen> createState() => _ImportContactsScreenState();
}

class _ImportContactsScreenState extends State<ImportContactsScreen> {
  List<Contact> _all = [];
  List<Contact> _filtered = [];
  final _searchCtrl = TextEditingController();
  bool _loading = true;
  bool _permissionDenied = false;
  // true only the very first time the user opens this screen
  bool _showingRationale = false;

  @override
  void initState() {
    super.initState();
    if (StorageService.hasShownContactsRationale) {
      // Rationale already shown before — jump straight to fetching contacts.
      // iOS will show its system permission dialog at most once; subsequent
      // calls to request() return immediately without a dialog.
      _loadContacts();
    } else {
      // First time: show the explanation screen before touching the OS dialog.
      setState(() {
        _loading = false;
        _showingRationale = true;
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _dismissRationale() async {
    await StorageService.markContactsRationaleShown();
    setState(() => _showingRationale = false);
    await _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _loading = true; _permissionDenied = false;
    });

    final status =
        await FlutterContacts.permissions.request(PermissionType.read);
    final granted = status == PermissionStatus.granted ||
        status == PermissionStatus.limited;

    if (!granted) {
      setState(() {
        _loading = false;
        _permissionDenied = true;
      });
      return; // Stop here — do NOT re-prompt or auto-open Settings
    }

    // Fetch phones, emails, thumbnail (for list avatars) AND full-resolution
    // photo (so the imported photo can be cropped/adjusted later), events,
    // and addresses.
    final contacts = await FlutterContacts.getAll(
      properties: {
        ContactProperty.phone,
        ContactProperty.email,
        ContactProperty.photoThumbnail,
        ContactProperty.photoFullRes,
        ContactProperty.event,
        ContactProperty.address,
        ContactProperty.note,
      },
    );

    final withPhone = contacts
        .where((c) => c.phones.isNotEmpty)
        .toList()
      ..sort((a, b) {
        final aName = a.displayName ?? '';
        final bName = b.displayName ?? '';
        return aName.compareTo(bName);
      });

    setState(() {
      _all = withPhone;
      _filtered = withPhone;
      _loading = false;
    });
  }

  void _filter(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _all
          : _all.where((c) {
              final name = (c.displayName ?? '').toLowerCase();
              final phone = c.phones.map((ph) => ph.number).join(' ');
              return name.contains(q) || phone.contains(q);
            }).toList();
    });
  }

  String _mapPhoneLabel(PhoneLabel label) {
    switch (label) {
      case PhoneLabel.mobile:
      case PhoneLabel.iPhone:
      case PhoneLabel.workMobile:
        return 'נייד';
      case PhoneLabel.work:
      case PhoneLabel.workFax:
      case PhoneLabel.companyMain:
        return 'עבודה';
      case PhoneLabel.home:
      case PhoneLabel.homeFax:
        return 'בית';
      default:
        return 'כללי';
    }
  }

  String _mapEmailLabel(EmailLabel label) {
    switch (label) {
      case EmailLabel.work:
        return 'עבודה';
      case EmailLabel.home:
        return 'בית';
      default:
        return 'כללי';
    }
  }

  Future<String?> _savePhoto(Uint8List bytes) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'contact_import_${const Uuid().v4()}.jpg';
      final file = File(p.join(appDir.path, fileName));
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  /// Extract birthday from contact events
  DateTime? _extractBirthday(Contact contact) {
    for (final event in contact.events) {
      if (event.label.label == EventLabel.birthday) {
        try {
          final year = event.year ?? 2000;
          return DateTime(year, event.month, event.day);
        } catch (_) {}
      }
    }
    return null;
  }

  /// Extract anniversary from contact events
  DateTime? _extractAnniversary(Contact contact) {
    for (final event in contact.events) {
      if (event.label.label == EventLabel.anniversary) {
        try {
          final year = event.year ?? 2000;
          return DateTime(year, event.month, event.day);
        } catch (_) {}
      }
    }
    return null;
  }

  /// Extract the first address from contact.
  /// Stored as "$street\n$city\n$zip" for structured display.
  String? _extractAddress(Contact contact) {
    if (contact.addresses.isEmpty) return null;
    final addr = contact.addresses.first;
    final street = addr.street ?? '';
    final city   = addr.city ?? '';
    final zip    = addr.postalCode ?? '';
    if (street.isEmpty && city.isEmpty && zip.isEmpty) return null;
    return '$street\n$city\n$zip';
  }

  Future<void> _selectContact(Contact contact) async {
    // Fetch full contact details individually — getAll() can miss notes on
    // some Android versions even when ContactProperty.note is requested.
    final fullContact = contact.id != null
        ? await FlutterContacts.get(
            contact.id!,
            properties: {
              ContactProperty.phone,
              ContactProperty.email,
              ContactProperty.photoThumbnail,
              ContactProperty.photoFullRes,
              ContactProperty.event,
              ContactProperty.address,
              ContactProperty.note,
            },
          )
        : null;
    final c = fullContact ?? contact;

    String? photoPath;
    // Prefer full-size photo so the user can crop/adjust after import.
    // Fall back to thumbnail if full-size wasn't returned by the OS.
    final photoBytes = c.photo?.fullSize ?? c.photo?.thumbnail;
    if (photoBytes != null && photoBytes.isNotEmpty) {
      photoPath = await _savePhoto(photoBytes);
    }

    final phones = c.phones.map((ph) => ph.number).toList();
    final phoneLabels =
        c.phones.map((ph) => _mapPhoneLabel(ph.label.label)).toList();

    final emails = c.emails.map((e) => e.address).toList();
    final emailLabels =
        c.emails.map((e) => _mapEmailLabel(e.label.label)).toList();

    final birthday = _extractBirthday(c);
    final anniversary = _extractAnniversary(c);
    final address = _extractAddress(c);

    // Extract notes from device contact
    final notes = c.notes.isNotEmpty
        ? c.notes.map((n) => n.note).where((n) => n.isNotEmpty).join('\n')
        : null;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditContactScreen(
          prefillName: contact.displayName ?? '',
          prefillPhones: phones,
          prefillPhoneLabels: phoneLabels,
          prefillEmails: emails,
          prefillEmailLabels: emailLabels,
          prefillPhotoPath: photoPath,
          prefillBirthday: birthday,
          prefillAnniversary: anniversary,
          prefillAddress: address,
          prefillNotes: notes,
          sourceContactId: c.id,
        ),
      ),
    );

    if (result == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ייבוא מאנשי קשר'),
          bottom: (_loading || _permissionDenied)
              ? null
              : PreferredSize(
                  preferredSize: const Size.fromHeight(60),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: _filter,
                      textDirection: TextDirection.rtl,
                      decoration: InputDecoration(
                        hintText: 'חפש שם או מספר...',
                        prefixIcon: Icon(Icons.search,
                            color: Theme.of(context).colorScheme.primary),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear,
                                    color: AppTheme.textLight),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  _filter('');
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildRationale() {
    final primary = Theme.of(context).colorScheme.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.contacts_rounded, size: 40, color: primary),
            ),
            const SizedBox(height: 24),
            const Text(
              'גישה לאנשי קשר',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'כדי לייבא אנשי קשר מהטלפון שלך, '
              'האפליקציה צריכה גישה לרשימת אנשי הקשר שלך.\n\n'
              'הגישה משמשת אך ורק לייבוא — '
              'לא מועבר מידע לשום גורם חיצוני.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textLight,
                fontSize: 15,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _dismissRationale,
                child: const Text(
                  'המשך',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_showingRationale) return _buildRationale();

    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CupertinoActivityIndicator(radius: 16),
            SizedBox(height: 16),
            Text('טוען אנשי קשר...',
                style: TextStyle(color: AppTheme.textLight, fontSize: 15)),
          ],
        ),
      );
    }

    if (_permissionDenied) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.contacts_outlined,
                  size: 64, color: AppTheme.textLight),
              const SizedBox(height: 20),
              const Text(
                'אין גישה לאנשי קשר',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark),
              ),
              const SizedBox(height: 12),
              const Text(
                'לא ניתן לייבא אנשי קשר ללא הרשאת גישה.\n\n'
                'כדי לאפשר גישה: פתח הגדרות ← פרטיות ← אנשי קשר ← הפעל עבור האפליקציה.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppTheme.textLight, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 24),
              // Subtle text link — not a primary CTA button
              TextButton(
                onPressed: () => FlutterContacts.permissions.openSettings(),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.textLight,
                  textStyle: const TextStyle(
                      fontSize: 13, decoration: TextDecoration.underline),
                ),
                child: const Text('עבור להגדרות'),
              ),
            ],
          ),
        ),
      );
    }

    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded,
                size: 56, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            const Text('לא נמצאו תוצאות',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textLight)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _filtered.length,
      itemBuilder: (context, index) {
        final contact = _filtered[index];
        final name = contact.displayName ?? '';
        final phone = contact.phones.first.number;
        // Use thumbnail for list avatars (small/fast); fullSize used on import.
        final thumbBytes = contact.photo?.thumbnail ?? contact.photo?.fullSize;
        final hasPhoto = thumbBytes != null && thumbBytes.isNotEmpty;
        final initials = _initials(name);
        final colorIndex = name.isNotEmpty
            ? name.codeUnitAt(0) % AppTheme.categoryColors.length
            : 0;
        final color = AppTheme.categoryColors[colorIndex];

        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                  color: color.withValues(alpha: 0.3), width: 1.5),
            ),
            child: ClipOval(
              child: hasPhoto
                  ? Image.memory(thumbBytes!, fit: BoxFit.cover)
                  : Center(
                      child: Text(
                        initials,
                        style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                            fontSize: 16),
                      ),
                    ),
            ),
          ),
          title: Text(
            name.isEmpty ? phone : name,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontSize: 16),
          ),
          subtitle: name.isEmpty ? null : Text(
            phone,
            style: const TextStyle(color: AppTheme.textLight, fontSize: 13),
          ),
          trailing: Builder(builder: (ctx) {
            final primary = Theme.of(ctx).colorScheme.primary;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'הוסף',
                style: TextStyle(
                    color: primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14),
              ),
            );
          }),
          onTap: () => _selectContact(contact),
        );
      },
    );
  }

  String _initials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      final a = parts.last.isNotEmpty ? parts.last[0] : '';
      final b = parts.first.isNotEmpty ? parts.first[0] : '';
      return '$a$b';
    }
    return name[0];
  }
}
