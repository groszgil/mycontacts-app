import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_contacts/flutter_contacts.dart' hide Category;
import 'package:local_auth/local_auth.dart';
import '../models/app_settings.dart';
import '../models/category.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
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

  // Emergency contact state
  bool _emergencyEnabled = false;
  String? _emergencyName;
  String? _emergencyPhone;

  // Biometric lock state
  bool _appLockEnabled = false;
  bool _biometricsAvailable = false;

  // Friendship reminder state
  bool _friendshipReminderEnabled = false;
  int _friendshipReminderDaysBefore = 0;
  int _friendshipReminderHour = 9;

  // Custom event reminder timing (global)
  int _customEventReminderDaysBefore = 0;
  int _customEventReminderHour = 9;

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
    _loadConfig();
    _checkBiometrics();
  }

  void _reload() {
    setState(() {
      _settings = StorageService.getSettings();
      _categories = StorageService.getAllCategories()
          .where((c) => c.id != 'all')
          .toList();
    });
  }

  void _loadConfig() {
    setState(() {
      _emergencyEnabled = StorageService.isEmergencyEnabled;
      _emergencyName    = StorageService.emergencyContactName;
      _emergencyPhone   = StorageService.emergencyContactPhone;
      _appLockEnabled   = StorageService.isAppLockEnabled;
      _friendshipReminderEnabled     = StorageService.friendshipReminderEnabled;
      _friendshipReminderDaysBefore  = StorageService.friendshipReminderDaysBefore;
      _friendshipReminderHour        = StorageService.friendshipReminderHour;
      _customEventReminderDaysBefore = StorageService.customEventReminderDaysBefore;
      _customEventReminderHour       = StorageService.customEventReminderHour;
    });
  }

  Future<void> _checkBiometrics() async {
    try {
      final auth = LocalAuthentication();
      final available = await auth.canCheckBiometrics ||
          await auth.isDeviceSupported();
      if (mounted) setState(() => _biometricsAvailable = available);
    } catch (_) {}
  }

  /// Opens a device-contacts picker bottom sheet and lets the user choose
  /// one contact to set as the emergency contact.
  Future<void> _pickEmergencyContact() async {
    // Request permission
    final status = await FlutterContacts.permissions
        .request(PermissionType.read);
    final granted = status == PermissionStatus.granted ||
        status == PermissionStatus.limited;
    if (!granted || !mounted) return;

    // Load contacts with phone numbers
    final contacts = await FlutterContacts.getAll(
      properties: {ContactProperty.phone},
    );
    if (!mounted) return;

    // Sort contacts with phone numbers only
    final withPhone = contacts
        .where((c) => c.phones.isNotEmpty)
        .toList()
      ..sort((a, b) =>
          (a.displayName ?? '').compareTo(b.displayName ?? ''));

    // Show bottom sheet
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollCtrl) => Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text('בחר איש קשר חירום',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  itemCount: withPhone.length,
                  itemBuilder: (_, i) {
                    final c = withPhone[i];
                    final name   = c.displayName ?? '';
                    final phone  = c.phones.first.number;
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(name.isNotEmpty ? name[0] : '?'),
                      ),
                      title:    Text(name.isNotEmpty ? name : '(ללא שם)'),
                      subtitle: Text(phone),
                      onTap: () => Navigator.pop(ctx, (name, phone)),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((result) async {
      if (result == null) return;
      final (String name, String phone) = result as (String, String);
      await StorageService.setEmergencyConfig(
        enabled: _emergencyEnabled,
        name: name,
        phone: phone,
      );
      if (mounted) {
        setState(() {
          _emergencyName  = name;
          _emergencyPhone = phone;
        });
      }
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
      final data = await StorageService.exportToJson();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
      final contactCount = (data['contacts'] as List).length;

      // Encode to bytes in memory — no intermediate file needed
      final bytes = Uint8List.fromList(utf8.encode(jsonStr));

      // Use FilePicker.saveFile → presents iOS "Save to Files" dialog
      // (UIDocumentPickerViewController) which is reliable on all iOS versions
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'שמור גיבוי',
        fileName: 'my_contacts_backup.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: bytes,
      );

      if (!mounted) return;
      if (outputPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('גיבוי נשמר — $contactCount אנשי קשר ✅'),
            backgroundColor: const Color(0xFF27AE60),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בייצוא: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  Future<void> _importBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true, // read bytes directly — avoids path access issues on iOS
      );
      if (result == null || result.files.isEmpty) return;

      final fileResult = result.files.single;
      String content;

      if (fileResult.bytes != null) {
        // Must use utf8.decode — String.fromCharCodes breaks multi-byte chars (Hebrew)
        content = utf8.decode(fileResult.bytes!);
      } else if (fileResult.path != null) {
        content = await File(fileResult.path!).readAsString();
      } else {
        throw Exception('לא ניתן לקרוא את הקובץ');
      }

      // Validate JSON before asking user
      final decoded = jsonDecode(content) as Map<String, dynamic>;
      final contactCount = (decoded['contacts'] as List?)?.length ?? 0;

      if (!mounted) return;
      final ok = await showCupertinoDialog<bool>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('ייבוא גיבוי'),
          content: Text(
              'נמצאו $contactCount אנשי קשר בקובץ.\nהייבוא יוסיף אותם לאפליקציה (ללא מחיקת קיימים). להמשיך?'),
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
          SnackBar(
            content: Text('יובאו $contactCount אנשי קשר בהצלחה ✅'),
            backgroundColor: const Color(0xFF27AE60),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בייבוא: $e'),
            backgroundColor: Colors.red,
          ),
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

            // ── Reminders ─────────────────────────────────────────────────────
            _SectionTitle('תזכורות'),
            const SizedBox(height: 12),
            _Card(isDark: isDark, child: Column(
              children: [
                // ── Birthday ─────────────────────────────────────────────────
                _ToggleTile(
                  icon: Icons.cake_rounded,
                  iconColor: Colors.orange,
                  title: 'תזכורת יום הולדת',
                  value: _settings.birthdayReminderEnabled,
                  onChanged: (v) {
                    setState(() => _settings.birthdayReminderEnabled = v);
                    _saveSettings();
                    _rescheduleNotifications();
                  },
                ),
                if (_settings.birthdayReminderEnabled) ...[
                  _Divider(),
                  _ReminderTimingTile(
                    isDark: isDark,
                    primary: primary,
                    label: 'מתי להזכיר',
                    daysBefore: _settings.birthdayReminderDaysBefore,
                    hour: _settings.birthdayReminderHour,
                    onDaysChanged: (v) {
                      setState(() => _settings.birthdayReminderDaysBefore = v);
                      _saveSettings();
                      _rescheduleNotifications();
                    },
                    onHourChanged: (v) {
                      setState(() => _settings.birthdayReminderHour = v);
                      _saveSettings();
                      _rescheduleNotifications();
                    },
                  ),
                ],
                _Divider(),
                // ── Anniversary ──────────────────────────────────────────────
                _ToggleTile(
                  icon: Icons.favorite_rounded,
                  iconColor: const Color(0xFFE91E63),
                  title: 'תזכורת יום נישואין',
                  value: _settings.anniversaryReminderEnabled,
                  onChanged: (v) {
                    setState(() => _settings.anniversaryReminderEnabled = v);
                    _saveSettings();
                    _rescheduleNotifications();
                  },
                ),
                if (_settings.anniversaryReminderEnabled) ...[
                  _Divider(),
                  _ReminderTimingTile(
                    isDark: isDark,
                    primary: const Color(0xFFE91E63),
                    label: 'מתי להזכיר',
                    daysBefore: _settings.anniversaryReminderDaysBefore,
                    hour: _settings.anniversaryReminderHour,
                    onDaysChanged: (v) {
                      setState(() => _settings.anniversaryReminderDaysBefore = v);
                      _saveSettings();
                      _rescheduleNotifications();
                    },
                    onHourChanged: (v) {
                      setState(() => _settings.anniversaryReminderHour = v);
                      _saveSettings();
                      _rescheduleNotifications();
                    },
                  ),
                ],
                _Divider(),
                // ── Friendship ──────────────────────────────────────────────
                _ToggleTile(
                  icon: Icons.people_rounded,
                  iconColor: const Color(0xFF42A5F5),
                  title: 'תזכורת יום חברות',
                  value: _friendshipReminderEnabled,
                  onChanged: (v) async {
                    await StorageService.setFriendshipReminder(enabled: v);
                    setState(() => _friendshipReminderEnabled = v);
                    _rescheduleNotifications();
                  },
                ),
                if (_friendshipReminderEnabled) ...[
                  _Divider(),
                  _ReminderTimingTile(
                    isDark: isDark,
                    primary: const Color(0xFF42A5F5),
                    label: 'מתי להזכיר',
                    daysBefore: _friendshipReminderDaysBefore,
                    hour: _friendshipReminderHour,
                    onDaysChanged: (v) async {
                      await StorageService.setFriendshipReminder(
                          enabled: _friendshipReminderEnabled, daysBefore: v);
                      setState(() => _friendshipReminderDaysBefore = v);
                      _rescheduleNotifications();
                    },
                    onHourChanged: (v) async {
                      await StorageService.setFriendshipReminder(
                          enabled: _friendshipReminderEnabled, hour: v);
                      setState(() => _friendshipReminderHour = v);
                      _rescheduleNotifications();
                    },
                  ),
                ],
                _Divider(),
                // ── Custom events (global timing) ───────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.event_rounded,
                            color: AppTheme.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text('תזכורות אירועים מותאמים',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: isDark ? Colors.white : AppTheme.textDark)),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 64, bottom: 4),
                  child: Text(
                    'שעה ומספר ימים לתזכורות אירועים שהופעלה להם תזכורת',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textLight),
                  ),
                ),
                _Divider(),
                _ReminderTimingTile(
                  isDark: isDark,
                  primary: AppTheme.primary,
                  label: 'מתי להזכיר',
                  daysBefore: _customEventReminderDaysBefore,
                  hour: _customEventReminderHour,
                  onDaysChanged: (v) async {
                    await StorageService.setCustomEventReminderTiming(daysBefore: v);
                    setState(() => _customEventReminderDaysBefore = v);
                    _rescheduleNotifications();
                  },
                  onHourChanged: (v) async {
                    await StorageService.setCustomEventReminderTiming(hour: v);
                    setState(() => _customEventReminderHour = v);
                    _rescheduleNotifications();
                  },
                ),
              ],
            )),
            const SizedBox(height: 24),

            // ── Security (biometric lock) ─────────────────────────────────────
            _SectionTitle('אבטחה'),
            const SizedBox(height: 12),
            _Card(isDark: isDark, child: Column(
              children: [
                _ToggleTile(
                  icon: Icons.fingerprint_rounded,
                  iconColor: const Color(0xFF6C63FF),
                  title: 'נעילה ביומטרית',
                  value: _appLockEnabled,
                  onChanged: _biometricsAvailable
                      ? (v) async {
                          await StorageService.setAppLockEnabled(v);
                          setState(() => _appLockEnabled = v);
                        }
                      : null,
                ),
                if (!_biometricsAvailable) ...[
                  _Divider(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 16, color: AppTheme.textLight),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'המכשיר אינו תומך בנעילה ביומטרית',
                            style: const TextStyle(
                                fontSize: 13, color: AppTheme.textLight),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            )),
            const SizedBox(height: 24),

            // ── Emergency contact ─────────────────────────────────────────────
            _SectionTitle('איש קשר חירום'),
            const SizedBox(height: 12),
            _Card(isDark: isDark, child: Column(
              children: [
                _ToggleTile(
                  icon: Icons.sos_rounded,
                  iconColor: const Color(0xFFE53935),
                  title: 'כפתור SOS',
                  subtitle: 'מציג כפתור חיוג מהיר לאיש קשר חירום',
                  value: _emergencyEnabled,
                  onChanged: (v) async {
                    await StorageService.setEmergencyConfig(
                      enabled: v,
                      name: _emergencyName,
                      phone: _emergencyPhone,
                    );
                    setState(() => _emergencyEnabled = v);
                  },
                ),
                _Divider(),
                ListTile(
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.person_rounded,
                        color: Color(0xFFE53935), size: 22),
                  ),
                  title: Text(
                    _emergencyName ?? 'לא נבחר',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: _emergencyName != null
                          ? (isDark ? Colors.white : AppTheme.textDark)
                          : AppTheme.textLight,
                    ),
                  ),
                  subtitle: _emergencyPhone != null
                      ? Text(_emergencyPhone!,
                          style: const TextStyle(
                              fontSize: 13, color: AppTheme.textLight))
                      : null,
                  trailing: TextButton(
                    onPressed: _pickEmergencyContact,
                    child: Text(
                      _emergencyName != null ? 'שנה' : 'בחר',
                      style: TextStyle(
                          color: primary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            )),
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

  Future<void> _rescheduleNotifications() async {
    try {
      await NotificationService.scheduleBirthdayNotifications();
      await NotificationService.scheduleAnniversaryNotifications();
      await NotificationService.scheduleFriendshipNotifications();
      await NotificationService.scheduleCustomEventNotifications();
    } catch (_) {}
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
  final String? subtitle;
  final bool value;
  /// Null means the toggle is disabled (greyed out).
  final ValueChanged<bool>? onChanged;

  const _ToggleTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final disabled = onChanged == null;
    return ListTile(
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: (disabled ? Colors.grey : iconColor).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon,
            color: disabled ? Colors.grey : iconColor, size: 20),
      ),
      title: Text(title,
          style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: disabled
                  ? AppTheme.textLight
                  : (isDark ? Colors.white : AppTheme.textDark))),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style: const TextStyle(fontSize: 12, color: AppTheme.textLight))
          : null,
      trailing: CupertinoSwitch(
        value: value,
        activeTrackColor: iconColor,
        onChanged: disabled ? null : onChanged,
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

// ── Reminder timing tile ────────────────────────────────────────────────────

class _ReminderTimingTile extends StatelessWidget {
  final bool isDark;
  final Color primary;
  final String label;
  final int daysBefore;
  final int hour;
  final ValueChanged<int> onDaysChanged;
  final ValueChanged<int> onHourChanged;

  const _ReminderTimingTile({
    required this.isDark,
    required this.primary,
    required this.label,
    required this.daysBefore,
    required this.hour,
    required this.onDaysChanged,
    required this.onHourChanged,
  });

  static const _daysOptions = [0, 1, 3, 7];
  static const _daysLabels = ['ביום עצמו', 'יום לפני', '3 ימים לפני', 'שבוע לפני'];

  String get _hourLabel {
    final h = hour.toString().padLeft(2, '0');
    return '$h:00';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : AppTheme.textMedium,
            ),
          ),
          const SizedBox(height: 10),

          // Days-before selector chips
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: List.generate(_daysOptions.length, (i) {
              final selected = daysBefore == _daysOptions[i];
              return GestureDetector(
                onTap: () => onDaysChanged(_daysOptions[i]),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: selected ? primary : primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _daysLabels[i],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : primary,
                    ),
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 12),

          // Hour picker row
          Row(
            children: [
              Icon(Icons.access_time_rounded, size: 16, color: AppTheme.textLight),
              const SizedBox(width: 8),
              Text(
                'שעת תזכורת:',
                style: const TextStyle(fontSize: 13, color: AppTheme.textLight),
              ),
              const SizedBox(width: 10),
              // Hour - / hour display / +
              GestureDetector(
                onTap: () => onHourChanged((hour - 1).clamp(0, 23)),
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.remove, size: 16, color: primary),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 52,
                padding: const EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _hourLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => onHourChanged((hour + 1).clamp(0, 23)),
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.add, size: 16, color: primary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
