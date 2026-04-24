import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/storage_service.dart';
import '../utils/theme.dart';
import 'home_screen.dart';
import 'device_contacts_screen.dart';
import 'dialer_screen.dart';
import 'birthdays_screen.dart';
import 'anniversaries_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

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
