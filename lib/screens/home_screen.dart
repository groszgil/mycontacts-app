import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/app_contact.dart';
import '../models/category.dart';
import '../models/app_settings.dart';
import '../services/storage_service.dart';
import '../utils/theme.dart';
import '../widgets/contact_card.dart';
import 'add_edit_contact_screen.dart';
import 'import_contacts_screen.dart';
import 'contact_detail_screen.dart';
import 'settings_screen.dart';
import 'about_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Category> _categories = [];
  AppSettings _settings = AppSettings();
  int _selectedCategoryIndex = 0;
  late PageController _pageController;
  String _searchQuery = '';
  bool _isSearching = false;
  bool _isReordering = false;
  bool _headerCollapsed = false;
  bool _isListView = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadData();
    StorageService.categoriesBox.listenable().addListener(_loadData);
    StorageService.settingsBox.listenable().addListener(_loadData);
  }

  @override
  void dispose() {
    StorageService.categoriesBox.listenable().removeListener(_loadData);
    StorageService.settingsBox.listenable().removeListener(_loadData);
    _pageController.dispose();
    super.dispose();
  }

  void _loadData() {
    final cats = StorageService.getAllCategories();
    final settings = StorageService.getSettings();
    // clamp: when birthdays tab (-1) is selected, keep it but guard category index
    final safeIndex = _selectedCategoryIndex < 0
        ? _selectedCategoryIndex
        : _selectedCategoryIndex.clamp(0, cats.isEmpty ? 0 : cats.length - 1);
    setState(() {
      _categories = cats;
      _settings = settings;
      _isListView = settings.isListView;
      _selectedCategoryIndex = safeIndex;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients && cats.isNotEmpty && _selectedCategoryIndex >= 0) {
        _pageController.jumpToPage(_selectedCategoryIndex);
      }
    });
  }

  void _selectCategory(int index) {
    setState(() {
      _selectedCategoryIndex = index;
      _searchQuery = '';
      _isSearching = false;
      _headerCollapsed = false;
    });
    if (index >= 0) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _deleteContact(AppContact contact) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('מחיקת איש קשר'),
        content: Text('האם למחוק את "${contact.name}"?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('ביטול'),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('מחק'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await StorageService.deleteContact(contact.id);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF1A1A2E) : AppTheme.surface,
        body: SafeArea(
          child: ValueListenableBuilder(
            valueListenable: StorageService.contactsBox.listenable(),
            builder: (ctx, box, child) {
              _settings = StorageService.getSettings();
              return Column(
                children: [
                  _buildHeader(isDark),
                  if (_isSearching) _buildSearchBar(isDark),
                  if (!_isSearching && _categories.length >= 1)
                    _buildCategoryBar(),
                  Expanded(
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification.metrics.axis == Axis.vertical) {
                          final collapsed =
                              notification.metrics.pixels > 40;
                          if (collapsed != _headerCollapsed) {
                            setState(
                                () => _headerCollapsed = collapsed);
                          }
                        }
                        return false;
                      },
                      child: _buildBody(),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        floatingActionButton: _buildFAB(),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(bool isDark) {
    final primary = AppTheme.primaryOf(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      padding: EdgeInsets.fromLTRB(
          20, _headerCollapsed ? 8 : 14, 12, _headerCollapsed ? 6 : 10),
      child: Row(
        children: [
          Expanded(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: _headerCollapsed ? 20 : 30,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppTheme.textDark,
                letterSpacing: -0.5,
                fontFamily: 'SF Pro Display',
              ),
              child: const Text('מועדפים'),
            ),
          ),
          // Search toggle
          _IconBtn(
            icon: _isSearching
                ? Icons.search_off_rounded
                : Icons.search_rounded,
            isDark: isDark,
            onTap: () => setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) _searchQuery = '';
              _headerCollapsed = false;
            }),
          ),
          const SizedBox(width: 8),
          // List/Grid toggle
          _IconBtn(
            icon: _isListView
                ? Icons.grid_view_rounded
                : Icons.view_list_rounded,
            isDark: isDark,
            onTap: () {
              setState(() {
                _isListView = !_isListView;
                _settings.isListView = _isListView;
              });
              StorageService.saveSettings(_settings);
            },
          ),
          const SizedBox(width: 8),
          // Reorder toggle
          _IconBtn(
            icon: _isReordering
                ? Icons.check_rounded
                : Icons.swap_vert_rounded,
            isDark: isDark,
            active: _isReordering,
            primaryColor: primary,
            onTap: () => setState(() => _isReordering = !_isReordering),
          ),
          const SizedBox(width: 8),
          // Import device favorites
          _IconBtn(
            icon: Icons.group_add_rounded,
            isDark: isDark,
            onTap: _importDeviceFavorites,
          ),
          const SizedBox(width: 8),
          // Overflow menu
          _IconBtn(
            icon: Icons.more_vert_rounded,
            isDark: isDark,
            onTap: () => _showOverflowMenu(),
          ),
        ],
      ),
    );
  }

  void _showOverflowMenu() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          // ── ייבוא מועדפים מהמכשיר ─────────────────────────────────
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _importDeviceFavorites();
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.group_add_rounded, size: 20),
                SizedBox(width: 8),
                Text('ייבוא מועדפים מהמכשיר'),
              ],
            ),
          ),
          // ── הוסף ידנית ─────────────────────────────────────────────
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _navigateToAdd();
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_add_rounded, size: 20),
                SizedBox(width: 8),
                Text('הוסף ידנית'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ).then((_) => setState(() {}));
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.settings_rounded, size: 20),
                SizedBox(width: 8),
                Text('הגדרות'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutScreen()),
              );
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline_rounded, size: 20),
                SizedBox(width: 8),
                Text('אודות'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('ביטול'),
        ),
      ),
    );
  }

  // ── Search bar ─────────────────────────────────────────────────────────────

  Widget _buildSearchBar(bool isDark) {
    final primary = AppTheme.primaryOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: TextField(
        autofocus: true,
        textDirection: TextDirection.rtl,
        decoration: InputDecoration(
          hintText: 'חפש שם או מספר...',
          prefixIcon: Icon(Icons.search_rounded, color: primary),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: AppTheme.textLight),
                  onPressed: () => setState(() => _searchQuery = ''),
                )
              : null,
        ),
        onChanged: (v) => setState(() => _searchQuery = v),
      ),
    );
  }

  // ── Category chips ─────────────────────────────────────────────────────────

  Widget _buildCategoryBar() {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          // Placeholder to keep the structure — birthday chip removed (moved to bottom tab)
          if (false) ...[
            GestureDetector(
              onTap: () => _selectCategory(-1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: _selectedCategoryIndex == -1
                      ? Colors.orange
                      : Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: _selectedCategoryIndex == -1
                      ? [
                          BoxShadow(
                            color: Colors.orange.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    'יומולדות 🎂',
                    style: TextStyle(
                      color: _selectedCategoryIndex == -1
                          ? Colors.white
                          : Colors.orange,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ],
          // Regular category chips
          for (int i = 0; i < _categories.length; i++) ...[
            GestureDetector(
              onTap: () => _selectCategory(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: _selectedCategoryIndex == i
                      ? AppTheme.colorFromValue(_categories[i].colorValue)
                      : AppTheme.colorFromValue(_categories[i].colorValue)
                          .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: _selectedCategoryIndex == i
                      ? [
                          BoxShadow(
                            color: AppTheme.colorFromValue(
                                    _categories[i].colorValue)
                                .withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    _categories[i].name,
                    style: TextStyle(
                      color: _selectedCategoryIndex == i
                          ? Colors.white
                          : AppTheme.colorFromValue(_categories[i].colorValue),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Body ───────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    if (_categories.isEmpty) return _buildEmptyState();

    if (_isSearching && _searchQuery.isNotEmpty) {
      return _buildSearchResults();
    }

    if (_isReordering) {
      final cat = _categories[_selectedCategoryIndex];
      final contacts = StorageService.getContactsByCategory(cat.id);
      return _buildDragReorderList(contacts);
    }

    return PageView.builder(
      controller: _pageController,
      itemCount: _categories.length,
      onPageChanged: (i) => setState(() => _selectedCategoryIndex = i),
      itemBuilder: (context, i) {
        final contacts =
            StorageService.getContactsByCategory(_categories[i].id);
        return _buildContactsList(contacts);
      },
    );
  }

  Widget _buildSearchResults() {
    final q = _searchQuery.toLowerCase();
    final all = StorageService.getAllContacts().where((c) {
      return c.name.toLowerCase().contains(q) ||
          c.effectivePrimaryPhone.contains(q) ||
          (c.notes?.toLowerCase().contains(q) ?? false);
    }).toList();

    if (all.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded,
                size: 56,
                color: AppTheme.primaryOf(context).withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            const Text('לא נמצאו תוצאות',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textLight)),
          ],
        ),
      );
    }
    return _buildContactsList(all);
  }

  // ── Contact list / grid ────────────────────────────────────────────────────

  Widget _buildContactsList(List<AppContact> contacts) {
    if (contacts.isEmpty) return _buildCategoryEmpty();

    if (_isListView) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
        itemCount: contacts.length,
        itemBuilder: (context, i) {
          final c = contacts[i];
          return ContactCard(
            key: ValueKey(c.id),
            contact: c,
            isListView: true,
            onEdit: () => _navigateToEdit(c),
            onDelete: () => _deleteContact(c),
            onTap: () => _navigateToDetail(c),
          );
        },
      );
    }

    final cols = _settings.gridColumns;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.78,
      ),
      itemCount: contacts.length,
      itemBuilder: (context, i) {
        final c = contacts[i];
        return ContactCard(
          key: ValueKey(c.id),
          contact: c,
          isListView: false,
          onEdit: () => _navigateToEdit(c),
          onDelete: () => _deleteContact(c),
          onTap: () => _navigateToDetail(c),
        );
      },
    );
  }

  // ── Reorderable grid ───────────────────────────────────────────────────────

  // ── Empty states ───────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    final primary = AppTheme.primaryOf(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: _navigateToImport,
            child: _PulsingCircle(
              icon: Icons.contacts_rounded,
              color: primary,
              size: 100,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'אין אנשי קשר עדיין',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : AppTheme.textDark),
          ),
          const SizedBox(height: 8),
          const Text('לחץ לבחירת איש קשר מהמכשיר',
              style: TextStyle(fontSize: 15, color: AppTheme.textLight)),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _navigateToImport,
                icon: const Icon(Icons.contacts_rounded, size: 18),
                label: const Text('ייבוא מהטלפון'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _navigateToAdd,
                icon: const Icon(Icons.person_add_rounded, size: 18),
                label: const Text('הוסף ידנית'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Birthday tab ───────────────────────────────────────────────────────────

  static const _monthNames = [
    '', 'ינואר', 'פברואר', 'מרץ', 'אפריל', 'מאי', 'יוני',
    'יולי', 'אוגוסט', 'ספטמבר', 'אוקטובר', 'נובמבר', 'דצמבר',
  ];

  Widget _buildBirthdayTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final all = StorageService.getAllContacts()
        .where((c) => c.birthday != null)
        .toList();

    if (all.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎂', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            const Text('אין ימי הולדת שמורים',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textLight)),
            const SizedBox(height: 6),
            const Text('הוסף יום הולדת בעת עריכת איש קשר',
                style: TextStyle(fontSize: 14, color: AppTheme.textLight)),
          ],
        ),
      );
    }

    // Sort by daysUntilBirthday
    all.sort((a, b) =>
        (a.daysUntilBirthday ?? 999).compareTo(b.daysUntilBirthday ?? 999));

    // Group by birthday month
    final grouped = <int, List<AppContact>>{};
    for (final c in all) {
      grouped.putIfAbsent(c.birthday!.month, () => []).add(c);
    }

    // Months ordered starting from current month
    final now = DateTime.now();
    final monthOrder =
        List.generate(12, (i) => ((now.month - 1 + i) % 12) + 1)
            .where((m) => grouped.containsKey(m))
            .toList();

    // Build flat list of widgets
    final items = <Widget>[];
    for (final month in monthOrder) {
      items.add(Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
        child: Row(
          children: [
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
          ],
        ),
      ));
      for (final c in grouped[month]!) {
        items.add(_BirthdayListTile(
          contact: c,
          isDark: isDark,
          onTap: () => _navigateToDetail(c),
        ));
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: items,
    );
  }

  // ── Drag-to-reorder list ───────────────────────────────────────────────────

  Widget _buildDragReorderList(List<AppContact> contacts) {
    if (contacts.isEmpty) return _buildCategoryEmpty();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppTheme.primaryOf(context);

    return Column(
      children: [
        Container(
          color: primary.withValues(alpha: 0.9),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.drag_indicator_rounded, color: Colors.white, size: 16),
              SizedBox(width: 6),
              Text(
                'גרור לשינוי סדר — לחץ ✓ לסיום',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14),
              ),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 100),
            itemCount: contacts.length,
            onReorder: (oldIndex, newIndex) async {
              if (newIndex > oldIndex) newIndex--;
              final list = List<AppContact>.from(contacts);
              list.insert(newIndex, list.removeAt(oldIndex));
              await StorageService.updateSortOrders(list);
              setState(() {});
            },
            itemBuilder: (context, i) {
              final c = contacts[i];
              return ListTile(
                key: ValueKey(c.id),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: AppTheme.primaryOf(context).withValues(alpha: 0.15),
                  backgroundImage: StorageService.resolvePhotoPath(c.localPhotoPath) != null
                      ? FileImage(File(StorageService.resolvePhotoPath(c.localPhotoPath)!))
                      : null,
                  child: StorageService.resolvePhotoPath(c.localPhotoPath) == null
                      ? Text(
                          c.name.isNotEmpty ? c.name[0] : '?',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryOf(context)),
                        )
                      : null,
                ),
                title: Text(
                  c.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                ),
                subtitle: Text(
                  c.effectivePrimaryPhone,
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textLight),
                ),
                trailing: const Icon(Icons.drag_handle_rounded,
                    color: AppTheme.textLight),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryEmpty() {
    final primary = AppTheme.primaryOf(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: _navigateToImport,
            child: _PulsingCircle(
              icon: Icons.contacts_rounded,
              color: primary,
              size: 90,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'אין אנשי קשר עדיין',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppTheme.textLight),
          ),
          const SizedBox(height: 6),
          const Text(
            'לחץ לבחירת איש קשר מהמכשיר',
            style: TextStyle(fontSize: 13, color: AppTheme.textLight),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _navigateToImport,
                icon: const Icon(Icons.contacts_rounded, size: 18),
                label: const Text('ייבוא מהטלפון'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _navigateToAdd,
                icon: const Icon(Icons.person_add_rounded, size: 18),
                label: const Text('הוסף ידנית'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── FAB ────────────────────────────────────────────────────────────────────

  Widget _buildFAB() {
    if (_isReordering) return const SizedBox.shrink();
    final primary = AppTheme.primaryOf(context);
    return FloatingActionButton.extended(
      heroTag: 'import_fab',
      onPressed: _navigateToImport,
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      icon: const Icon(Icons.person_add_rounded),
      label: const Text('הוספת איש קשר',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
    );
  }

  // ── Import device favorites (starred contacts) ────────────────────────────

  Future<void> _importDeviceFavorites() async {
    // Request contacts permission
    final status =
        await FlutterContacts.permissions.request(PermissionType.read);
    final granted = status == PermissionStatus.granted ||
        status == PermissionStatus.limited;
    if (!granted || !mounted) return;

    // Fetch contacts with the favorite (starred) flag
    final all = await FlutterContacts.getAll(
      properties: {
        ContactProperty.phone,
        ContactProperty.name,
        ContactProperty.favorite,
      },
    );

    // Only starred contacts not yet imported
    final importedPhoneIds = StorageService.getSyncMap().values.toSet();
    final favorites = all
        .where((c) =>
            c.android?.isFavorite == true &&
            c.phones.isNotEmpty &&
            (c.displayName ?? '').isNotEmpty &&
            !importedPhoneIds.contains(c.id ?? ''))
        .toList();

    if (!mounted) return;

    if (favorites.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('לא נמצאו מועדפים חדשים מהמכשיר'),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    // Confirmation dialog
    final names = favorites
        .take(3)
        .map((c) => c.displayName ?? '')
        .where((n) => n.isNotEmpty)
        .join('، ');
    final more = favorites.length > 3 ? ' ועוד ${favorites.length - 3}' : '';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('ייבוא ${favorites.length} מועדפים',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          content: Text(
            'נמצאו ${favorites.length} מועדפים מהמכשיר:\n$names$more\n\nלייבא אותם לרשימה?',
            style: const TextStyle(fontSize: 15, height: 1.55),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('ביטול'),
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

    if (confirm != true || !mounted) return;

    // Import each starred contact — fetch full details for notes/events
    int added = 0;
    final existingCount = StorageService.getAllContacts().length;

    for (final c in favorites) {
      final name = c.displayName ?? '';
      if (name.isEmpty || c.phones.isEmpty) continue;

      // Fetch full details (notes, events) for this individual contact
      Contact full = c;
      if (c.id != null) {
        final fetched = await FlutterContacts.get(
          c.id!,
          properties: {
            ContactProperty.phone,
            ContactProperty.note,
            ContactProperty.event,
          },
        );
        if (fetched != null) full = fetched;
      }

      final phones = full.phones.map((p) => p.number).toList();
      final labels = full.phones.map((p) {
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

      final notes = full.notes.isNotEmpty
          ? full.notes
              .map((n) => n.note)
              .where((n) => n.isNotEmpty)
              .join('\n')
          : null;

      DateTime? birthday;
      DateTime? anniversary;
      for (final event in full.events) {
        if (event.label.label == EventLabel.birthday && birthday == null) {
          try {
            birthday =
                DateTime(event.year ?? 2000, event.month, event.day);
          } catch (_) {}
        } else if (event.label.label == EventLabel.anniversary &&
            anniversary == null) {
          try {
            anniversary =
                DateTime(event.year ?? 2000, event.month, event.day);
          } catch (_) {}
        }
      }

      final appContact = AppContact(
        id: const Uuid().v4(),
        name: name,
        primaryPhone: phones.first,
        phones: phones,
        phoneLabels: labels,
        categoryIds: ['all'],
        sortOrder: existingCount + added,
        notes: notes,
        birthdayMillis: birthday?.millisecondsSinceEpoch,
        anniversaryMillis: anniversary?.millisecondsSinceEpoch,
      );
      await StorageService.saveContact(appContact);
      final cid = full.id ?? '';
      if (cid.isNotEmpty) {
        await StorageService.addToSyncMap(appContact.id, cid);
      }
      added++;
    }

    if (!mounted) return;
    if (added > 0) {
      final addedNames = favorites
          .take(3)
          .map((c) => c.displayName ?? '')
          .where((n) => n.isNotEmpty)
          .join('، ');
      final suffix = added > 3 ? ' ועוד ${added - 3}' : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('יובאו $added מועדפים: $addedNames$suffix'),
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      setState(() {});
    }
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  Future<void> _navigateToAdd() async {
    final result = await Navigator.push(context,
        MaterialPageRoute(builder: (_) => const AddEditContactScreen()));
    if (result == true) setState(() {});
  }

  Future<void> _navigateToImport() async {
    final result = await Navigator.push(context,
        MaterialPageRoute(builder: (_) => const ImportContactsScreen()));
    if (result == true) setState(() {});
  }

  Future<void> _navigateToEdit(AppContact contact) async {
    final result = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => AddEditContactScreen(contact: contact)));
    if (result == true) setState(() {});
  }

  Future<void> _navigateToDetail(AppContact contact) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContactDetailScreen(
          contact: contact,
          onEdit: () => _navigateToEdit(contact),
          onDelete: () => _deleteContact(contact),
        ),
      ),
    );
    setState(() {});
  }
}

// ── Small icon button ──────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final bool active;
  final Color? primaryColor;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    required this.isDark,
    required this.onTap,
    this.active = false,
    this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = primaryColor ?? AppTheme.primaryOf(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: active
              ? color
              : (isDark ? const Color(0xFF252540) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon,
            color: active
                ? Colors.white
                : (isDark ? Colors.white70 : AppTheme.textDark),
            size: 20),
      ),
    );
  }
}

// ── Birthday list tile ─────────────────────────────────────────────────────

class _BirthdayListTile extends StatelessWidget {
  final AppContact contact;
  final bool isDark;
  final VoidCallback onTap;

  const _BirthdayListTile({
    required this.contact,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final b = contact.birthday!;
    final days = contact.daysUntilBirthday ?? 999;
    final dateStr =
        '${b.day.toString().padLeft(2, '0')}/${b.month.toString().padLeft(2, '0')}';
    String daysLabel;
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
    } else {
      daysLabel = 'עוד $days ימים';
      daysColor = AppTheme.textLight;
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
            // Avatar
            CircleAvatar(
              radius: 22,
              backgroundColor:
                  AppTheme.primaryOf(context).withValues(alpha: 0.12),
              backgroundImage: StorageService.resolvePhotoPath(contact.localPhotoPath) != null
                  ? FileImage(File(StorageService.resolvePhotoPath(contact.localPhotoPath)!))
                  : null,
              child: StorageService.resolvePhotoPath(contact.localPhotoPath) == null
                  ? Text(
                      contact.name.isNotEmpty ? contact.name[0] : '?',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryOf(context)),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            // Name + date
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
                  Text(
                    dateStr,
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.textLight),
                  ),
                ],
              ),
            ),
            // Days badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: daysColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                daysLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: daysColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Animated pulsing icon for empty states ─────────────────────────────────

class _PulsingCircle extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _PulsingCircle(
      {required this.icon, required this.color, required this.size});

  @override
  State<_PulsingCircle> createState() => _PulsingCircleState();
}

class _PulsingCircleState extends State<_PulsingCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.88, end: 1.08).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.15),
              blurRadius: 20,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Icon(widget.icon,
            size: widget.size * 0.46, color: widget.color),
      ),
    );
  }
}
