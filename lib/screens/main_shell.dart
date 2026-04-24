import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../models/app_contact.dart';
import '../services/storage_service.dart';
import '../services/contact_sync_service.dart';
import '../utils/theme.dart';
import 'home_screen.dart';
import 'device_contacts_screen.dart';
import 'dialer_screen.dart';
import 'birthdays_screen.dart';
import 'anniversaries_screen.dart';
import 'import_contacts_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Run after the first frame so the scaffold/navigator is fully mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkFirstLaunch();
      await _runContactSync();
    });
  }

  // ── First-launch import prompt ────────────────────────────────────────────

  Future<void> _checkFirstLaunch() async {
    if (!StorageService.isFirstLaunch) return;
    await StorageService.markFirstLaunchDone();
    if (!mounted) return;
    await _showFirstLaunchDialog();
  }

  Future<void> _showFirstLaunchDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          contentPadding:
              const EdgeInsets.fromLTRB(24, 24, 24, 16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.contacts_rounded,
                    size: 36, color: AppTheme.primary),
              ),
              const SizedBox(height: 18),
              const Text(
                'ייבוא מועדפים מהטלפון',
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'האם תרצה לייבא אנשי קשר מועדפים מהטלפון שלך?\n\nכך תוכל להתחיל להשתמש מיד ולחסוך זמן.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textLight,
                    height: 1.55),
              ),
            ],
          ),
          actionsPadding:
              const EdgeInsets.fromLTRB(16, 0, 16, 12),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('לא עכשיו'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('כן, ייבא'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (result == true && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ImportContactsScreen()),
      );
    }
  }

  // ── Ongoing contact sync ──────────────────────────────────────────────────

  Future<void> _runContactSync() async {
    // Only run when at least some contacts have been imported before.
    final hasSyncMap = StorageService.getSyncMap().isNotEmpty;
    final hasKnownIds = StorageService.getKnownPhoneContactIds().isNotEmpty;
    if (!hasSyncMap && !hasKnownIds) return;

    SyncResult result;
    try {
      result = await ContactSyncService.checkForChanges();
    } catch (_) {
      return;
    }
    if (!result.hasAnything || !mounted) return;

    // Show a dialog for each changed (existing) contact.
    for (final change in result.changes) {
      if (!mounted) break;
      final confirmed = await _showSyncChangeDialog(change);
      if (confirmed) await ContactSyncService.applyChange(change);
    }

    // Offer to import new contacts found on the device.
    if (result.newPhoneContacts.isNotEmpty && mounted) {
      await _showNewContactsDialog(result.newPhoneContacts);
    }
  }

  Future<bool> _showSyncChangeDialog(SyncChange change) async {
    final contactName = change.appContact.name;
    String description;
    if (change.newName != null && change.newPhones != null) {
      description =
          'השם השתנה ל״${change.newName}״\nהמספר השתנה ל-${change.newPhones!.first}';
    } else if (change.newName != null) {
      description = 'השם השתנה ל״${change.newName}״';
    } else {
      description = 'המספר השתנה ל-${change.newPhones!.first}';
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(contactName,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          content: Text(
            '$description\n\nלעדכן?',
            style: const TextStyle(fontSize: 15, height: 1.5),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('לא'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('עדכן'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return result ?? false;
  }

  Future<void> _showNewContactsDialog(List<Contact> newContacts) async {
    final count = newContacts.length;
    final names = newContacts
        .take(5)
        .map((c) => c.displayName ?? '')
        .where((n) => n.isNotEmpty)
        .join('، ');
    final more = count > 5 ? ' ועוד ${count - 5}' : '';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('אנשי קשר חדשים',
              style: TextStyle(fontWeight: FontWeight.w700)),
          content: Text(
            'נמצאו $count אנשי קשר חדשים בטלפון שלך:\n$names$more\n\nהאם לייבא אותם לרשימה?',
            style: const TextStyle(fontSize: 15, height: 1.55),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('לא'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('ייבא'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (result != true || !mounted) return;

    // Auto-create basic AppContact entries (name + phones) for each new contact.
    int added = 0;
    final existingCount = StorageService.getAllContacts().length;
    for (final c in newContacts) {
      final name = c.displayName ?? '';
      if (name.isEmpty || c.phones.isEmpty) continue;
      final phones = c.phones.map((p) => p.number).toList();
      final labels = c.phones.map((p) {
        switch (p.label.label) {
          case PhoneLabel.mobile:
          case PhoneLabel.iPhone:
          case PhoneLabel.workMobile:
            return 'נייד';
          case PhoneLabel.work:
          case PhoneLabel.workFax:
            return 'עבודה';
          case PhoneLabel.home:
          case PhoneLabel.homeFax:
            return 'בית';
          default:
            return 'כללי';
        }
      }).toList();

      final appContact = AppContact(
        id: const Uuid().v4(),
        name: name,
        primaryPhone: phones.first,
        phones: phones,
        phoneLabels: labels,
        email: null,
        categoryIds: ['all'],
        sortOrder: existingCount + added,
      );
      await StorageService.saveContact(appContact);
      final phoneId = c.id ?? '';
      if (phoneId.isNotEmpty) {
        await StorageService.addToSyncMap(appContact.id, phoneId);
      }
      added++;
    }

    if (mounted && added > 0) {
      final addedNames = newContacts
          .take(3)
          .map((c) => c.displayName ?? '')
          .where((n) => n.isNotEmpty)
          .join('، ');
      final suffix = added > 3 ? ' ועוד ${added - 3}' : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'הצטרפו לרשימה $added אנשי קשר חדשים: $addedNames$suffix'),
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _callEmergency() async {
    final phone = StorageService.emergencyContactPhone;
    if (phone == null || phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppTheme.primaryOf(context);

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          HomeScreen(),
          DeviceContactsScreen(),
          DialerScreen(),
          BirthdaysScreen(),
          AnniversariesScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(isDark, primary),
      // SOS floating button — visible only when emergency contact is configured
      floatingActionButton: ValueListenableBuilder<bool>(
        valueListenable: StorageService.emergencyEnabledNotifier,
        builder: (context, enabled, _) {
          if (!enabled) return const SizedBox.shrink();
          return FloatingActionButton(
            heroTag: 'sos_fab',
            onPressed: _callEmergency,
            backgroundColor: const Color(0xFFE53935),
            foregroundColor: Colors.white,
            elevation: 6,
            tooltip: 'SOS — ${StorageService.emergencyContactName ?? ''}',
            child: const Icon(Icons.sos_rounded, size: 30),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }

  Widget _buildBottomNav(bool isDark, Color primary) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E36) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: primary.withValues(alpha: isDark ? 0.15 : 0.08),
            width: 0.5,
          ),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: primary,
        unselectedItemColor: AppTheme.textLight,
        selectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
        items: [
          BottomNavigationBarItem(
            icon: _NavIcon(
              icon: Icons.star_rounded,
              selected: _selectedIndex == 0,
              primary: primary,
            ),
            label: 'מועדפים',
          ),
          BottomNavigationBarItem(
            icon: _NavIcon(
              icon: Icons.people_rounded,
              selected: _selectedIndex == 1,
              primary: const Color(0xFF42A5F5),
            ),
            label: 'אנשי קשר',
          ),
          BottomNavigationBarItem(
            icon: _NavIcon(
              icon: Icons.dialpad_rounded,
              selected: _selectedIndex == 2,
              primary: const Color(0xFF4CAF50),
            ),
            label: 'חייגן',
          ),
          BottomNavigationBarItem(
            icon: _NavIcon(
              icon: Icons.cake_rounded,
              selected: _selectedIndex == 3,
              primary: Colors.orange,
            ),
            label: 'ימי הולדת',
          ),
          BottomNavigationBarItem(
            icon: _NavIcon(
              icon: Icons.favorite_rounded,
              selected: _selectedIndex == 4,
              primary: const Color(0xFFE91E63),
            ),
            label: 'נישואין',
          ),
        ],
      ),
    );
  }
}

/// Animated nav icon with a pill highlight when selected.
class _NavIcon extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final Color primary;

  const _NavIcon(
      {required this.icon, required this.selected, required this.primary});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.symmetric(
        horizontal: selected ? 14 : 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: selected
            ? primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(icon, size: 22),
    );
  }
}
