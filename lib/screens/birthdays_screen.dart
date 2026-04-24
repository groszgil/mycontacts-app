import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/app_contact.dart';
import '../services/storage_service.dart';
import '../utils/theme.dart';
import 'contact_detail_screen.dart';
import 'add_edit_contact_screen.dart';

class BirthdaysScreen extends StatefulWidget {
  const BirthdaysScreen({super.key});

  @override
  State<BirthdaysScreen> createState() => _BirthdaysScreenState();
}

class _BirthdaysScreenState extends State<BirthdaysScreen> {
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppTheme.primaryOf(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF1A1A2E) : AppTheme.surface,
        body: SafeArea(
          child: ValueListenableBuilder(
            valueListenable: StorageService.contactsBox.listenable(),
            builder: (ctx, box, _) {
              final all = StorageService.getAllContacts()
                  .where((c) => c.birthday != null)
                  .toList();

              return Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                    child: Row(
                      children: [
                        const Text(
                          'ימי הולדת 🎂',
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
                              color: Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${all.length}',
                              style: const TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  Expanded(child: _buildList(all, isDark, primary)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildList(
      List<AppContact> all, bool isDark, Color primary) {
    if (all.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎂', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text(
              'אין ימי הולדת שמורים',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textLight),
            ),
            const SizedBox(height: 8),
            const Text(
              'הוסף יום הולדת בעת עריכת איש קשר',
              style: TextStyle(fontSize: 14, color: AppTheme.textLight),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Sort by days until birthday
    all.sort((a, b) =>
        (a.daysUntilBirthday ?? 999).compareTo(b.daysUntilBirthday ?? 999));

    // Group by month
    final grouped = <int, List<AppContact>>{};
    for (final c in all) {
      grouped.putIfAbsent(c.birthday!.month, () => []).add(c);
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
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('החודש',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.orange)),
            ),
        ]),
      ));
      for (final c in grouped[month]!) {
        items.add(_BirthdayTile(
          contact: c,
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

class _BirthdayTile extends StatelessWidget {
  final AppContact contact;
  final bool isDark;
  final VoidCallback onTap;

  const _BirthdayTile({
    required this.contact,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final b = contact.birthday!;
    final days = contact.daysUntilBirthday ?? 999;
    final currentAge = contact.completedBirthdayYears;
    final dateStr =
        '${b.day.toString().padLeft(2, '0')}/${b.month.toString().padLeft(2, '0')}/${b.year}';

    String daysLabel;
    String? nextLabel; // second line in badge
    Color daysColor;

    if (days == 0) {
      daysLabel = '🎂 היום!';
      daysColor = Colors.orange;
    } else if (days == 1) {
      daysLabel = 'מחר!';
      daysColor = Colors.orange;
    } else if (days <= 7) {
      daysLabel = 'עוד $days ימים';
      daysColor = Colors.orange.shade700;
      if (currentAge != null) nextLabel = 'בן/בת ${currentAge + 1}';
    } else {
      daysLabel = 'עוד $days ימים';
      daysColor = AppTheme.textLight;
      if (currentAge != null) nextLabel = 'בן/בת ${currentAge + 1}';
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
            Builder(builder: (ctx) {
              final photoPath = StorageService.resolvePhotoPath(contact.localPhotoPath);
              return CircleAvatar(
                radius: 22,
                backgroundColor:
                    AppTheme.primaryOf(ctx).withValues(alpha: 0.12),
                backgroundImage: photoPath != null
                    ? FileImage(File(photoPath))
                    : null,
                child: photoPath == null
                    ? Text(
                        contact.name.isNotEmpty ? contact.name[0] : '?',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryOf(ctx)),
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
                      if (currentAge != null && currentAge > 0) ...[
                        const SizedBox(width: 6),
                        Text('· בן/בת $currentAge',
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textLight)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Badge: days + next age
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
