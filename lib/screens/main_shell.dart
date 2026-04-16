import 'package:flutter/material.dart';
import '../utils/theme.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'about_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppTheme.primaryOf(context);

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          HomeScreen(),
          SettingsScreen(),
          AboutScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(isDark, primary),
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
        selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w700, fontSize: 11),
        unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500, fontSize: 11),
        items: [
          BottomNavigationBarItem(
            icon: _NavIcon(
              icon: Icons.contacts_rounded,
              selected: _selectedIndex == 0,
              primary: primary,
            ),
            label: 'אנשי קשר',
          ),
          BottomNavigationBarItem(
            icon: _NavIcon(
              icon: Icons.settings_rounded,
              selected: _selectedIndex == 1,
              primary: primary,
            ),
            label: 'הגדרות',
          ),
          BottomNavigationBarItem(
            icon: _NavIcon(
              icon: Icons.info_outline_rounded,
              selected: _selectedIndex == 2,
              primary: primary,
            ),
            label: 'אודות',
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
