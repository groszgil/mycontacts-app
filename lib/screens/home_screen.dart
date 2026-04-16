import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/app_contact.dart';
import '../models/category.dart';
import '../models/app_settings.dart';
import '../services/storage_service.dart';
import '../utils/theme.dart';
import '../widgets/contact_card.dart';
import 'add_edit_contact_screen.dart';
import 'import_contacts_screen.dart';
import 'contact_detail_screen.dart';
import 'merge_duplicates_screen.dart';

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
              child: const Text('אנשי קשר'),
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
    final primary = AppTheme.primaryOf(context);
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const MergeDuplicatesScreen()),
              );
            },
            child: const Text('מיזוג כפילויות'),
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
    final birthdayContacts = StorageService.getContactsBirthdayThisMonth();
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          // Birthday chip (only shown if there are birthday contacts this month)
          if (birthdayContacts.isNotEmpty) ...[
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

    // Birthday filter
    if (_selectedCategoryIndex == -1) {
      final birthdayContacts = StorageService.getContactsBirthdayThisMonth();
      return _buildContactsList(birthdayContacts);
    }

    if (_isReordering) {
      final cat = _categories[_selectedCategoryIndex];
      final contacts = StorageService.getContactsByCategory(cat.id);
      return _buildReorderableGrid(contacts);
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

  Widget _buildReorderableGrid(List<AppContact> contacts) {
    if (contacts.isEmpty) return _buildCategoryEmpty();
    final cols = _settings.gridColumns;
    final screenW = MediaQuery.of(context).size.width;
    const padding = 14.0;
    const spacing = 10.0;
    final cardW = (screenW - padding * 2 - spacing * (cols - 1)) / cols;
    final cardH = cardW / 0.78;
    final primary = AppTheme.primaryOf(context);

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 48, 14, 100),
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: contacts.asMap().entries.map((entry) {
              final i = entry.key;
              final c = entry.value;
              return SizedBox(
                width: cardW,
                height: cardH,
                child: Stack(
                  children: [
                    ContactCard(
                      key: ValueKey(c.id),
                      contact: c,
                      onEdit: () => _navigateToEdit(c),
                      onDelete: () => _deleteContact(c),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (i > 0)
                            _ReorderBtn(
                              icon: Icons.arrow_back_ios_rounded,
                              color: primary,
                              onTap: () async {
                                final list = List<AppContact>.from(contacts);
                                list.insert(i - 1, list.removeAt(i));
                                await StorageService.updateSortOrders(list);
                                setState(() {});
                              },
                            ),
                          const Spacer(),
                          if (i < contacts.length - 1)
                            _ReorderBtn(
                              icon: Icons.arrow_forward_ios_rounded,
                              color: primary,
                              onTap: () async {
                                final list = List<AppContact>.from(contacts);
                                list.insert(i + 1, list.removeAt(i));
                                await StorageService.updateSortOrders(list);
                                setState(() {});
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            color: primary.withValues(alpha: 0.9),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: const Text(
              'מצב סידור — לחץ ✓ לסיום',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  // ── Empty states ───────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    final primary = AppTheme.primaryOf(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PulsingCircle(
            icon: Icons.contacts_rounded,
            color: primary,
            size: 100,
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
          const Text('לחץ על + כדי להוסיף',
              style: TextStyle(fontSize: 15, color: AppTheme.textLight)),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: _navigateToAdd,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_add_rounded,
                      color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('הוסף ראשון',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryEmpty() {
    final primary = AppTheme.primaryOf(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PulsingCircle(
            icon: Icons.person_search_rounded,
            color: primary,
            size: 90,
          ),
          const SizedBox(height: 16),
          const Text(
            'אין אנשי קשר בקטגוריה זו',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppTheme.textLight),
          ),
        ],
      ),
    );
  }

  // ── FAB ────────────────────────────────────────────────────────────────────

  Widget _buildFAB() {
    if (_isReordering) return const SizedBox.shrink();
    final primary = AppTheme.primaryOf(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.extended(
          heroTag: 'import_fab',
          onPressed: _navigateToImport,
          backgroundColor: Colors.white,
          foregroundColor: primary,
          elevation: 3,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: const Icon(Icons.contacts_rounded),
          label: const Text('הוסף מאנשי הקשר',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        ),
        const SizedBox(height: 10),
        FloatingActionButton.extended(
          heroTag: 'add_fab',
          onPressed: _navigateToAdd,
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: const Icon(Icons.person_add_rounded),
          label: const Text('הוסף ידנית',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        ),
      ],
    );
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

class _ReorderBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ReorderBtn(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 14),
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
