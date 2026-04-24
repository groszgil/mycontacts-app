import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/app_contact.dart';
import '../services/storage_service.dart';
import '../utils/theme.dart';
import 'contact_detail_screen.dart';
import 'add_edit_contact_screen.dart';

class AnniversariesScreen extends StatefulWidget {
  const AnniversariesScreen({super.key});

  @override
  State<AnniversariesScreen> createState() => _AnniversariesScreenState();
}

class _AnniversariesScreenState extends State<AnniversariesScreen> {
  static const _monthNames = [
    '', 'ינואר', 'פברואר', 'מרץ', 'אפריל', 'מאי', 'יוני',
    'יולי', 'אוגוסט', 'ספטמבר', 'אוקטובר', 'נובמבר', 'דצמבר',
  ];

  Future<void> _navigateToDetail(AppContact c) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContactDetailScreen(
          contact: c,
          onEdit: () => _navigateToEdit(c),
          onDelete: () async {
            await StorageService.deleteContact(c.id);
            setState(() {});
          },
        ),
      ),
    );
    setState(() {});
  }

  Future<void> _navigateToEdit(AppContact c) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddEditContactScreen(contact: c)),
    );
    if (result == true) setState(() {});
  }

  /// Days until next anniversary (0 = today)
  int? _daysUntil(DateTime ann) {
    final now = DateTime.now();
    var next = DateTime(now.year, ann.month, ann.day);
    if (next.isBefore(DateTime(now.year, now.month, now.day))) {
      next = DateTime(now.year + 1, ann.month, ann.day);
    }
    return next.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF1A1A2E) : AppTheme.surface,
        body: SafeArea(
          child: ValueListenableBuilder(
            valueListenable: StorageService.contactsBox.listenable(),
            builder: (ctx, box, _) {
              final all = StorageService.getAllContacts()
                  .where((c) => c.anniversary != null)
                  .toList();

              return Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                    child: Row(
                      children: [
                        const Text(
                          'ימי נישואין 💍',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const Spacer(),
                        if (all.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE91E63)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${all.length}',
                              style: const TextStyle(
                                color: Color(0xFFE91E63),
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  Expanded(child: _buildList(all, isDark)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildList(List<AppContact> all, bool isDark) {
    if (all.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('💍', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text(
              'אין ימי נישואין שמורים',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textLight),
            ),
            const SizedBox(height: 8),
            const Text(
              'הוסף יום נישואין בעת עריכת איש קשר',
              style: TextStyle(fontSize: 14, color: AppTheme.textLight),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Sort by days until anniversary
    all.sort((a, b) =>
        (_daysUntil(a.anniversary!) ?? 999)
            .compareTo(_daysUntil(b.anniversary!) ?? 999));

    // Group by month
    final grouped = <int, List<AppContact>>{};
    for (final c in all) {
      grouped.putIfAbsent(c.anniversary!.month, () => []).add(c);
    }

    final now = DateTime.now();
    final monthOrder =
        List.generate(12, (i) => ((now.month - 1 + i) % 12) + 1)
            .where((m) => grouped.containsKey(m))
            .toList();

    final items = <Widget>[];
    for (final month in monthOrder) {
      items.add(Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
        child: Row(children: [
          Text(
            _monthNames[month],
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppTheme.textDark,
            ),
          ),
          const SizedBox(width: 8),
          if (month == now.month)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE91E63).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('החודש',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFE91E63))),
            ),
        ]),
      ));
      for (final c in grouped[month]!) {
        items.add(_AnniversaryTile(
          contact: c,
          daysUntil: _daysUntil(c.anniversary!),
          isDark: isDark,
          onTap: () => _navigateToDetail(c),
        ));
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      children: items,
    );
  }
}

class _AnniversaryTile extends StatelessWidget {
  final AppContact contact;
  final int? daysUntil;
  final bool isDark;
  final VoidCallback onTap;

  const _AnniversaryTile({
    required this.contact,
    required this.daysUntil,
    required this.isDark,
    required this.onTap,
  });

  static const _pink = Color(0xFFE91E63);

  @override
  Widget build(BuildContext context) {
    final ann = contact.anniversary!;
    final years = contact.completedAnniversaryYears ?? 0;
    final dateStr =
        '${ann.day.toString().padLeft(2, '0')}/${ann.month.toString().padLeft(2, '0')}/${ann.year}';

    final days = daysUntil ?? 999;
    String daysLabel;
    String? nextLabel; // second line in badge
    Color daysColor;

    if (days == 0) {
      daysLabel = '💍 היום!';
      daysColor = _pink;
    } else if (days == 1) {
      daysLabel = 'מחר!';
      daysColor = _pink;
    } else if (days <= 7) {
      daysLabel = 'עוד $days ימים';
      daysColor = _pink;
      nextLabel = '${years + 1} שנים נשואין';
    } else {
      daysLabel = 'עוד $days ימים';
      daysColor = AppTheme.textLight;
      nextLabel = '${years + 1} שנים נשואין';
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF252540) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.08 : 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Builder(builder: (_) {
              final photoPath = StorageService.resolvePhotoPath(contact.localPhotoPath);
              return CircleAvatar(
                radius: 22,
                backgroundColor: _pink.withValues(alpha: 0.1),
                backgroundImage: photoPath != null
                    ? FileImage(File(photoPath))
                    : null,
                child: photoPath == null
                    ? Text(
                        contact.name.isNotEmpty ? contact.name[0] : '?',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, color: _pink),
                      )
                    : null,
              );
            }),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: isDark ? Colors.white : AppTheme.textDark,
                    ),
                  ),
                  Row(
                    children: [
                      Text(dateStr,
                          style: const TextStyle(
                              fontSize: 13, color: AppTheme.textLight)),
                      if (years > 0) ...[
                        const SizedBox(width: 6),
                        Text('· $years שנים נשואין',
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textLight)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Badge: days + next year
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: daysColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(daysLabel,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: daysColor)),
                  if (nextLabel != null) ...[
                    const SizedBox(height: 2),
                    Text(nextLabel,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: daysColor.withValues(alpha: 0.75))),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
