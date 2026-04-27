import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../services/storage_service.dart';
import '../utils/theme.dart';
import '../utils/launch_helper.dart';
import '../widgets/whatsapp_icon.dart';

class DeviceContactsScreen extends StatefulWidget {
  const DeviceContactsScreen({super.key});

  @override
  State<DeviceContactsScreen> createState() => _DeviceContactsScreenState();
}

class _DeviceContactsScreenState extends State<DeviceContactsScreen> {
  List<Contact> _all = [];
  List<Contact> _filtered = [];
  final _searchCtrl = TextEditingController();
  bool _loading = true;
  bool _permissionDenied = false;
  bool _showingRationale = false;
  /// 0=א→ת, 1=ת→א, 2=by phone count
  int _sortOrder = 0;

  @override
  void initState() {
    super.initState();
    // Reuse the same one-time rationale flag as the import screen
    if (StorageService.hasShownContactsRationale) {
      _loadContacts();
    } else {
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

    final contacts = await FlutterContacts.getAll(
      properties: {
        ContactProperty.phone,
        ContactProperty.photoThumbnail,
      },
    );

    final list = contacts.where((c) => c.phones.isNotEmpty).toList();

    if (mounted) {
      setState(() {
        _all = list;
        _filtered = _applySort(list);
        _loading = false;
      });
    }
  }

  List<Contact> _applySort(List<Contact> list) {
    final copy = List<Contact>.from(list);
    switch (_sortOrder) {
      case 1: // ת→א
        copy.sort((a, b) =>
            (b.displayName ?? '').compareTo(a.displayName ?? ''));
      case 2: // by phone count (most first)
        copy.sort((a, b) => b.phones.length.compareTo(a.phones.length));
      default: // א→ת
        copy.sort((a, b) =>
            (a.displayName ?? '').compareTo(b.displayName ?? ''));
    }
    return copy;
  }

  void _filter(String query) {
    final q = query.trim().toLowerCase();
    final base = q.isEmpty
        ? _all
        : _all.where((c) {
            final name = (c.displayName ?? '').toLowerCase();
            final phones = c.phones.map((p) => p.number).join(' ');
            return name.contains(q) || phones.contains(q);
          }).toList();
    setState(() => _filtered = _applySort(base));
  }

  void _applySortAndRefresh() {
    setState(() => _filtered = _applySort(_filtered));
  }

  void _showSortSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppTheme.primaryOf(context);

    final options = [
      (0, Icons.sort_by_alpha_rounded, 'א → ת', 'לפי שם בסדר עולה'),
      (1, Icons.sort_by_alpha_rounded, 'ת → א', 'לפי שם בסדר יורד'),
      (2, Icons.phone_rounded, 'לפי כמות מספרים', 'הכי הרבה מספרים קודם'),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF252540) : Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'מיון רשימה',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppTheme.textDark,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  for (final (idx, icon, title, subtitle) in options) ...[
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() => _sortOrder = idx);
                        _applySortAndRefresh();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: _sortOrder == idx
                              ? primary.withValues(alpha: 0.12)
                              : (isDark
                                  ? const Color(0xFF1A1A2E)
                                  : const Color(0xFFF7F7FA)),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _sortOrder == idx
                                ? primary.withValues(alpha: 0.4)
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(icon,
                                size: 22,
                                color: _sortOrder == idx
                                    ? primary
                                    : AppTheme.textLight),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(title,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: _sortOrder == idx
                                            ? primary
                                            : (isDark
                                                ? Colors.white
                                                : AppTheme.textDark),
                                      )),
                                  Text(subtitle,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textLight)),
                                ],
                              ),
                            ),
                            if (_sortOrder == idx)
                              Icon(Icons.check_rounded,
                                  size: 20, color: primary),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showActions(Contact contact) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ContactActionsSheet(contact: contact),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppTheme.primaryOf(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF1A1A2E) : AppTheme.surface,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ─────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                child: Row(
                  children: [
                    Text(
                      'אנשי קשר 📋',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppTheme.textDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Spacer(),
                    if (!_loading && !_permissionDenied && !_showingRationale)
                      Text(
                        '${_filtered.length}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textLight,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    if (!_loading && !_permissionDenied && !_showingRationale) ...[
                      const SizedBox(width: 6),
                      // Sort button
                      GestureDetector(
                        onTap: _showSortSheet,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _sortOrder != 0
                                ? primary.withValues(alpha: 0.18)
                                : primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.sort_rounded,
                              color: primary, size: 20),
                        ),
                      ),
                    ],
                    if (!_permissionDenied && !_showingRationale) ...[
                      const SizedBox(width: 6),
                      Tooltip(
                        message: 'מרענן את רשימת אנשי הקשר מהמכשיר',
                        child: GestureDetector(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                    'מרענן את רשימת אנשי הקשר מהמכשיר...'),
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                            _loadContacts();
                          },
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.refresh_rounded,
                                color: primary, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // ── Search bar ─────────────────────────────────────────────
              if (!_loading && !_permissionDenied && !_showingRationale) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _filter,
                    textDirection: TextDirection.rtl,
                    decoration: InputDecoration(
                      hintText: 'חפש שם או מספר...',
                      prefixIcon:
                          Icon(Icons.search, color: primary),
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
              ],
              const SizedBox(height: 4),

              // ── Body ───────────────────────────────────────────────────
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  // ── Body states ──────────────────────────────────────────────────────────

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
    if (_permissionDenied) return _buildDenied();
    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded,
                size: 56,
                color: AppTheme.primaryOf(context).withValues(alpha: 0.3)),
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
    return _buildGroupedList();
  }

  // ── Grouped contact list ─────────────────────────────────────────────────

  Widget _buildGroupedList() {
    // For A-Z sort: group by first letter with section headers
    // For other sorts: show a flat sorted list
    if (_sortOrder == 0) {
      final groups = <String, List<Contact>>{};
      for (final c in _filtered) {
        final name = c.displayName ?? '';
        final key = name.isEmpty ? '#' : name[0].toUpperCase();
        groups.putIfAbsent(key, () => []).add(c);
      }
      final keys = groups.keys.toList()..sort();
      final items = <dynamic>[];
      for (final k in keys) {
        items.add(k);
        items.addAll(groups[k]!);
      }
      return ListView.builder(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: items.length,
        itemBuilder: (ctx, i) {
          final item = items[i];
          if (item is String) return _SectionHeader(label: item);
          return _ContactTile(
            contact: item as Contact,
            onTap: () => _showActions(item),
          );
        },
      );
    }

    // Flat list for Z-A or by-phone-count
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: _filtered.length,
      itemBuilder: (ctx, i) => _ContactTile(
        contact: _filtered[i],
        onTap: () => _showActions(_filtered[i]),
      ),
    );
  }

  // ── First-time rationale ─────────────────────────────────────────────────

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
                  color: AppTheme.textDark),
            ),
            const SizedBox(height: 16),
            const Text(
              'כדי להציג את אנשי הקשר מהטלפון, '
              'האפליקציה צריכה גישה לרשימת אנשי הקשר שלך.\n\n'
              'הגישה משמשת לתצוגה וחיוג בלבד — '
              'לא מועבר מידע לשום גורם חיצוני.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppTheme.textLight, fontSize: 15, height: 1.55),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _dismissRationale,
                child: const Text('המשך',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Permission denied ────────────────────────────────────────────────────

  Widget _buildDenied() {
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
              'לא ניתן להציג אנשי קשר ללא הרשאת גישה.\n\n'
              'כדי לאפשר: הגדרות ← פרטיות ← אנשי קשר.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppTheme.textLight, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 24),
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
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 16, 4),
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1A1A2E)
          : AppTheme.surface,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppTheme.primaryOf(context),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── Contact row ───────────────────────────────────────────────────────────────

class _ContactTile extends StatelessWidget {
  final Contact contact;
  final VoidCallback onTap;

  const _ContactTile({required this.contact, required this.onTap});

  String _initials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      final a = parts.first.isNotEmpty ? parts.first[0] : '';
      final b = parts.last.isNotEmpty ? parts.last[0] : '';
      return '$a$b';
    }
    return name[0];
  }

  @override
  Widget build(BuildContext context) {
    final name = contact.displayName ?? '';
    final phone = contact.phones.first.number;
    final extraCount = contact.phones.length - 1;
    final thumbBytes = contact.photo?.thumbnail;
    final hasPhoto = thumbBytes != null && thumbBytes.isNotEmpty;
    final colorIndex =
        name.isNotEmpty ? name.codeUnitAt(0) % AppTheme.categoryColors.length : 0;
    final color = AppTheme.categoryColors[colorIndex];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border:
                    Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
              ),
              child: ClipOval(
                child: hasPhoto
                    ? Image.memory(thumbBytes!, fit: BoxFit.cover)
                    : Center(
                        child: Text(
                          _initials(name),
                          style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w700,
                              fontSize: 16),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),

            // Name + phone
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? phone : name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? Colors.white
                          : AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        phone,
                        style: const TextStyle(
                            color: AppTheme.textLight, fontSize: 13),
                      ),
                      if (extraCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '+$extraCount',
                            style: TextStyle(
                                fontSize: 11,
                                color: color,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Quick-call button
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                LaunchHelper.makeCall(phone);
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.call_rounded,
                    color: Color(0xFF4CAF50), size: 20),
              ),
            ),
            const SizedBox(width: 8),
            // WhatsApp button
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                LaunchHelper.openWhatsApp(phone);
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const WhatsAppIcon(size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Actions bottom sheet ──────────────────────────────────────────────────────

class _ContactActionsSheet extends StatelessWidget {
  final Contact contact;
  const _ContactActionsSheet({required this.contact});

  String _initials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      final a = parts.first.isNotEmpty ? parts.first[0] : '';
      final b = parts.last.isNotEmpty ? parts.last[0] : '';
      return '$a$b';
    }
    return name[0];
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = contact.displayName ?? '';
    final colorIndex =
        name.isNotEmpty ? name.codeUnitAt(0) % AppTheme.categoryColors.length : 0;
    final color = AppTheme.categoryColors[colorIndex];
    final thumbBytes = contact.photo?.thumbnail;
    final hasPhoto = thumbBytes != null && thumbBytes.isNotEmpty;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E36) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Avatar + name
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: color.withValues(alpha: 0.3), width: 2),
                    ),
                    child: ClipOval(
                      child: hasPhoto
                          ? Image.memory(thumbBytes!, fit: BoxFit.cover)
                          : Center(
                              child: Text(
                                _initials(name),
                                style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 20),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      name.isEmpty ? 'ללא שם' : name,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppTheme.textDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(indent: 24, endIndent: 24),

            // Phone rows
            ...contact.phones.map((ph) => _PhoneRow(
                  phone: ph.number,
                  label: _mapPhoneLabel(ph.label.label),
                  isDark: isDark,
                )),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── Phone row in sheet ────────────────────────────────────────────────────────

class _PhoneRow extends StatelessWidget {
  final String phone;
  final String label;
  final bool isDark;

  const _PhoneRow(
      {required this.phone, required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        children: [
          // Label + number
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textLight,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(phone,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppTheme.textDark)),
              ],
            ),
          ),

          // Action buttons
          Row(
            children: [
              _ActionCircle(
                icon: Icons.call_rounded,
                color: const Color(0xFF4CAF50),
                tooltip: 'התקשר',
                onTap: () {
                  Navigator.pop(context);
                  LaunchHelper.makeCall(phone);
                },
              ),
              const SizedBox(width: 10),
              _ActionCircle(
                icon: Icons.message_rounded,
                color: const Color(0xFF2196F3),
                tooltip: 'SMS',
                onTap: () {
                  Navigator.pop(context);
                  LaunchHelper.sendSms(phone);
                },
              ),
              const SizedBox(width: 10),
              _ActionCircle(
                icon: Icons.chat_rounded,
                color: const Color(0xFF25D366),
                tooltip: 'WhatsApp',
                iconWidget: const WhatsAppIcon(size: 20),
                onTap: () {
                  Navigator.pop(context);
                  LaunchHelper.openWhatsApp(phone);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Small circular action button ──────────────────────────────────────────────

class _ActionCircle extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  final Widget? iconWidget;

  const _ActionCircle(
      {required this.icon,
      required this.color,
      required this.tooltip,
      required this.onTap,
      this.iconWidget});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: iconWidget ?? Icon(icon, color: color, size: 20),
          ),
        ),
      ),
    );
  }
}
