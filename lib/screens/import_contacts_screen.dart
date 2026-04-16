import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
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

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _loading = true;
      _permissionDenied = false;
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
      return;
    }

    // Fetch phones, emails, and photo thumbnails
    final contacts = await FlutterContacts.getAll(
      properties: {
        ContactProperty.phone,
        ContactProperty.email,
        ContactProperty.photoThumbnail,
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

  Future<void> _selectContact(Contact contact) async {
    String? photoPath;
    final thumbnail = contact.photo?.thumbnail;
    if (thumbnail != null && thumbnail.isNotEmpty) {
      photoPath = await _savePhoto(thumbnail);
    }

    final phones = contact.phones.map((ph) => ph.number).toList();
    final phoneLabels =
        contact.phones.map((ph) => _mapPhoneLabel(ph.label.label)).toList();

    final emails = contact.emails.map((e) => e.address).toList();
    final emailLabels =
        contact.emails.map((e) => _mapEmailLabel(e.label.label)).toList();

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

  Widget _buildBody() {
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
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.contacts_outlined,
                  size: 64, color: AppTheme.textLight),
              const SizedBox(height: 20),
              const Text('נדרשת הרשאה',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark)),
              const SizedBox(height: 10),
              const Text(
                'כדי לייבא אנשי קשר יש לאשר גישה לאנשי הקשר של הטלפון בהגדרות.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textLight, fontSize: 15),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  await FlutterContacts.permissions.openSettings();
                },
                child: const Text('פתח הגדרות'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _loadContacts,
                child: const Text('נסה שוב'),
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
        final thumbBytes = contact.photo?.thumbnail;
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
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
                fontSize: 16),
          ),
          subtitle: Text(
            phone,
            style:
                const TextStyle(color: AppTheme.textLight, fontSize: 13),
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
