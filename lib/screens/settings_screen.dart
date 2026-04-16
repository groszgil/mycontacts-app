import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../models/app_settings.dart';
import '../models/category.dart';
import '../services/storage_service.dart';
import '../utils/theme.dart';
import 'add_edit_category_screen.dart';

// Preset accent colours (value, Hebrew label)
const _accentPresets = [
  (0xFF6C63FF, 'סגול'),
  (0xFF2F80ED, 'כחול'),
  (0xFF27AE60, 'ירוק'),
  (0xFFEB5757, 'אדום'),
  (0xFFF2994A, 'כתום'),
  (0xFF56CCF2, 'תכלת'),
  (0xFFBB6BD9, 'סגלגל'),
  (0xFF1A1A2E, 'שחור'),
];

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onSettingsChanged;
  const SettingsScreen({super.key, this.onSettingsChanged});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AppSettings _settings;
  late List<Category> _categories;

  final List<(int, int, String)> _gridPresets = [
    (2, 3, '2 × 3'),
    (3, 4, '3 × 4'),
    (4, 4, '4 × 4'),
    (4, 5, '4 × 5'),
    (5, 4, '5 × 4'),
    (5, 5, '5 × 5'),
  ];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _settings = StorageService.getSettings();
      _categories = StorageService.getAllCategories()
          .where((c) => c.id != 'all')
          .toList();
    });
  }

  Future<void> _saveSettings() async {
    await StorageService.saveSettings(_settings);
    widget.onSettingsChanged?.call();
  }

  Future<void> _deleteCategory(Category cat) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('מחיקת קטגוריה'),
        content: Text('האם למחוק "${cat.name}"?'),
        actions: [
          CupertinoDialogAction(
              child: const Text('ביטול'),
              onPressed: () => Navigator.pop(ctx, false)),
          CupertinoDialogAction(
              isDestructiveAction: true,
              child: const Text('מחק'),
              onPressed: () => Navigator.pop(ctx, true)),
        ],
      ),
    );
    if (ok == true) {
      await StorageService.deleteCategory(cat.id);
      _reload();
      widget.onSettingsChanged?.call();
    }
  }

  Future<void> _exportBackup() async {
    try {
      final data = StorageService.exportToJson();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/my_contacts_backup.json');
      await file.writeAsString(jsonStr);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'גיבוי אנשי קשר מועדפים',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('שגיאה בייצוא: $e')),
        );
      }
    }
  }

  Future<void> _importBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: false,
      );
      if (result == null || result.files.isEmpty) return;
      final path = result.files.single.path;
      if (path == null) return;

      final content = await File(path).readAsString();

      final ok = await showCupertinoDialog<bool>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('ייבוא גיבוי'),
          content: const Text(
              'הייבוא יוסיף את אנשי הקשר והקטגוריות מהקובץ. אנשי קשר קיימים לא יימחקו. להמשיך?'),
          actions: [
            CupertinoDialogAction(
                child: const Text('ביטול'),
                onPressed: () => Navigator.pop(ctx, false)),
            CupertinoDialogAction(
                child: const Text('ייבא'),
                onPressed: () => Navigator.pop(ctx, true)),
          ],
        ),
      );
      if (ok != true) return;

      await StorageService.importFromJson(content);
      _reload();
      widget.onSettingsChanged?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('הייבוא הושלם בהצלחה')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('שגיאה בייבוא: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppTheme.primaryOf(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('הגדרות')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [

            // ── Display ──────────────────────────────────────────────────────
            _SectionTitle('תצוגה'),
            const SizedBox(height: 12),
            _Card(isDark: isDark, child: Column(
              children: [
                // Dark mode
                _ToggleTile(
                  icon: Icons.dark_mode_rounded,
                  iconColor: primary,
                  title: 'מצב כהה',
                  value: _settings.isDarkMode,
                  onChanged: (v) {
                    setState(() => _settings.isDarkMode = v);
                    _saveSettings();
                  },
                ),
                _Divider(),
                // Font size
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.text_fields_rounded,
                                color: primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('גודל טקסט',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                        color: isDark ? Colors.white : AppTheme.textDark)),
                                Text(_fontScaleLabel(_settings.fontScale),
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.textLight)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: _settings.fontScale,
                        min: 0.85,
                        max: 1.4,
                        divisions: 11,
                        activeColor: primary,
                        inactiveColor: primary.withValues(alpha: 0.2),
                        onChanged: (v) {
                          setState(() => _settings.fontScale =
                              double.parse(v.toStringAsFixed(2)));
                        },
                        onChangeEnd: (_) => _saveSettings(),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('ישראל ישראלי  052-1234567',
                            style: TextStyle(
                                fontSize: 15 * _settings.fontScale,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white : AppTheme.textDark)),
                      ),
                    ],
                  ),
                ),
              ],
            )),
            const SizedBox(height: 24),

            // ── Accent colour ─────────────────────────────────────────────────
            _SectionTitle('צבע ראשי'),
            const SizedBox(height: 12),
            _Card(
              isDark: isDark,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _accentPresets.map((preset) {
                    final (value, label) = preset;
                    final color = Color(value);
                    final selected = _settings.accentColorValue == value;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _settings.accentColorValue = value);
                        _saveSettings();
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: selected
                                  ? Border.all(
                                      color: Colors.white, width: 3)
                                  : null,
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.5),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      )
                                    ]
                                  : null,
                            ),
                            child: selected
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 20)
                                : null,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: selected
                                  ? color
                                  : AppTheme.textLight,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Grid layout ──────────────────────────────────────────────────
            _SectionTitle('פריסת גריד'),
            const SizedBox(height: 12),
            _Card(isDark: isDark, child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _gridPresets.map((preset) {
                  final (cols, rows, label) = preset;
                  final selected = _settings.gridColumns == cols &&
                      _settings.gridRows == rows;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _settings.gridColumns = cols;
                        _settings.gridRows = rows;
                      });
                      _saveSettings();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? primary
                            : primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(label,
                          style: TextStyle(
                              color: selected ? Colors.white : primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                    ),
                  );
                }).toList(),
              ),
            )),
            const SizedBox(height: 24),

            // ── Categories ───────────────────────────────────────────────────
            Row(
              children: [
                const Expanded(child: _SectionTitle('קטגוריות')),
                GestureDetector(
                  onTap: () async {
                    final ok = await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AddEditCategoryScreen()),
                    );
                    if (ok == true) {
                      _reload();
                      widget.onSettingsChanged?.call();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.add, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text('הוסף',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_categories.isEmpty)
              _Card(
                isDark: isDark,
                child: const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: Text('אין קטגוריות עדיין',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppTheme.textLight, fontSize: 14)),
                  ),
                ),
              )
            else
              _Card(
                isDark: isDark,
                child: Column(
                  children: _categories.asMap().entries.map((entry) {
                    final i = entry.key;
                    final cat = entry.value;
                    final color = AppTheme.colorFromValue(cat.colorValue);
                    return Column(
                      children: [
                        if (i > 0) _Divider(),
                        ListTile(
                          leading: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                                color: color, shape: BoxShape.circle),
                            child: const Icon(Icons.folder_rounded,
                                color: Colors.white, size: 18),
                          ),
                          title: Text(cat.name,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : AppTheme.textDark)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined,
                                    color: AppTheme.textLight, size: 20),
                                onPressed: () async {
                                  final ok = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            AddEditCategoryScreen(
                                                category: cat)),
                                  );
                                  if (ok == true) {
                                    _reload();
                                    widget.onSettingsChanged?.call();
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.red, size: 20),
                                onPressed: () => _deleteCategory(cat),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 24),

            // ── Backup ───────────────────────────────────────────────────────
            _SectionTitle('גיבוי'),
            const SizedBox(height: 12),
            _Card(isDark: isDark, child: Column(
              children: [
                _ActionTile(
                  icon: Icons.upload_rounded,
                  iconColor: const Color(0xFF27AE60),
                  title: 'ייצא גיבוי',
                  subtitle: 'שמור את כל אנשי הקשר כקובץ JSON',
                  onTap: _exportBackup,
                ),
                _Divider(),
                _ActionTile(
                  icon: Icons.download_rounded,
                  iconColor: const Color(0xFF2F80ED),
                  title: 'ייבא גיבוי',
                  subtitle: 'שחזר אנשי קשר מקובץ JSON',
                  onTap: _importBackup,
                ),
              ],
            )),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  String _fontScaleLabel(double scale) {
    if (scale <= 0.9) return 'קטן מאוד';
    if (scale <= 1.0) return 'רגיל';
    if (scale <= 1.1) return 'בינוני';
    if (scale <= 1.2) return 'גדול';
    if (scale <= 1.3) return 'גדול מאוד';
    return 'ענק';
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      title,
      style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : AppTheme.textDark,
          letterSpacing: -0.3),
    );
  }
}

class _Card extends StatelessWidget {
  final bool isDark;
  final Widget child;
  const _Card({required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) {
    final primary = AppTheme.primaryOf(context);
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252540) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, indent: 16, endIndent: 16);
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title,
          style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: isDark ? Colors.white : AppTheme.textDark)),
      trailing: CupertinoSwitch(
        value: value,
        activeTrackColor: iconColor,
        onChanged: onChanged,
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(title,
          style: TextStyle(
              fontWeight: FontWeight.w600, fontSize: 16, color: isDark ? Colors.white : AppTheme.textDark)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 13, color: AppTheme.textLight)),
      trailing: const Icon(Icons.chevron_left, color: AppTheme.textLight),
      onTap: onTap,
    );
  }
}
