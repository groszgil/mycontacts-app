import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../models/app_contact.dart';
import '../services/storage_service.dart';
import '../utils/theme.dart';
import '../utils/launch_helper.dart';
import '../widgets/whatsapp_icon.dart';

// ── T9 mapping (Hebrew standard + English) ────────────────────────────────────

const Map<String, String> _kHebT9 = {
  '2': 'אבג',
  '3': 'דהו',
  '4': 'זחט',
  '5': 'יכך',       // kaf + final kaf
  '6': 'מםנןס',     // mem, final mem, nun, final nun, samekh
  '7': 'עפףצץ',     // ayin, pe, final pe, tsadi, final tsadi
  '8': 'קרש',
  '9': 'ת',
};

const Map<String, String> _kEngT9 = {
  '2': 'abc', '3': 'def', '4': 'ghi', '5': 'jkl',
  '6': 'mno', '7': 'pqrs', '8': 'tuv', '9': 'wxyz',
};

// Hebrew letters shown under each key
const Map<String, String> _kKeyLetters = {
  '1': '',    '2': 'אבג',  '3': 'דהו',  '4': 'זחט',
  '5': 'יכל', '6': 'מנס',  '7': 'עפצ',  '8': 'קרש',
  '9': 'ת',   '0': '+',    '*': '',     '#': '',
};

String _charToDigit(String ch) {
  for (final e in _kHebT9.entries) {
    if (e.value.contains(ch)) return e.key;
  }
  final lower = ch.toLowerCase();
  for (final e in _kEngT9.entries) {
    if (e.value.contains(lower)) return e.key;
  }
  return '';
}

String _nameToT9(String name) {
  final buf = StringBuffer();
  for (int i = 0; i < name.length; i++) {
    final d = _charToDigit(name[i]);
    if (d.isNotEmpty) buf.write(d);
  }
  return buf.toString();
}

// ── Search result model ───────────────────────────────────────────────────────

class _ContactMatch {
  final String name;
  final String phone;
  const _ContactMatch({required this.name, required this.phone});
}

// ── Key data ──────────────────────────────────────────────────────────────────

class _KeyData {
  final String digit;
  const _KeyData(this.digit);
  String get letters => _kKeyLetters[digit] ?? '';
}

// ── Screen ────────────────────────────────────────────────────────────────────

class DialerScreen extends StatefulWidget {
  const DialerScreen({super.key});

  @override
  State<DialerScreen> createState() => _DialerScreenState();
}

class _DialerScreenState extends State<DialerScreen> {
  String _number = '';

  /// Device contacts loaded once for T9 search
  List<Contact> _deviceContacts = [];

  @override
  void initState() {
    super.initState();
    _loadDeviceContacts();
  }

  Future<void> _loadDeviceContacts() async {
    try {
      final status =
          await FlutterContacts.permissions.request(PermissionType.read);
      final granted = status == PermissionStatus.granted ||
          status == PermissionStatus.limited;
      if (!granted) return;
      final contacts = await FlutterContacts.getAll(
        properties: {ContactProperty.phone},
      );
      if (mounted) setState(() => _deviceContacts = contacts);
    } catch (_) {}
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  void _press(String digit) {
    HapticFeedback.lightImpact();
    if (_number.length >= 20) return;
    setState(() => _number += digit);
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null) return;
    final pasted = data!.text!.replaceAll(RegExp(r'[^\d+*#]'), '');
    if (pasted.isEmpty) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _number = (_number + pasted)
          .substring(0, (_number + pasted).length.clamp(0, 20));
    });
  }

  void _backspace() {
    HapticFeedback.lightImpact();
    if (_number.isEmpty) return;
    setState(() => _number = _number.substring(0, _number.length - 1));
  }

  void _clear() {
    HapticFeedback.mediumImpact();
    setState(() => _number = '');
  }

  // ── Formatted display ────────────────────────────────────────────────────────

  String get _formatted {
    final d = _number.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('0') && d.length >= 3) {
      if (d.length <= 3) return d;
      if (d.length <= 7) return '${d.substring(0, 3)}-${d.substring(3)}';
      return '${d.substring(0, 3)}-${d.substring(3, 7)}-${d.substring(7)}';
    }
    return _number;
  }

  // ── T9 search — searches BOTH app favorites & device contacts ────────────────

  List<_ContactMatch> get _t9Matches {
    if (_number.length < 2) return [];
    final seen = <String>{};
    final results = <_ContactMatch>[];

    void add(String name, String phone) {
      if (results.length >= 5) return;
      final key = '${name.toLowerCase()}|${phone.replaceAll(RegExp(r'\D'), '')}';
      if (seen.contains(key)) return;
      seen.add(key);
      results.add(_ContactMatch(name: name, phone: phone));
    }

    // 1. App favorites (Hive) — searched first
    for (final c in StorageService.getAllContacts()) {
      if (results.length >= 5) break;
      final t9 = _nameToT9(c.name);
      final phonePlain =
          c.effectivePrimaryPhone.replaceAll(RegExp(r'\D'), '');
      if (t9.contains(_number) || phonePlain.contains(_number)) {
        add(c.name, c.effectivePrimaryPhone);
      }
    }

    // 2. Device contacts
    for (final c in _deviceContacts) {
      if (results.length >= 5) break;
      if (c.phones.isEmpty) continue;
      final name = c.displayName ?? '';
      if (name.isEmpty) continue;
      final t9 = _nameToT9(name);
      final rawPhone = c.phones.first.number;
      final phonePlain = rawPhone.replaceAll(RegExp(r'\D'), '');
      if (t9.contains(_number) || phonePlain.contains(_number)) {
        add(name, rawPhone);
      }
    }

    return results;
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppTheme.primaryOf(context);
    final matches = _t9Matches;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF1A1A2E) : AppTheme.surface,
        body: SafeArea(
          child: Column(
            children: [
              // ── Header ─────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    Text(
                      'חייגן 📞',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppTheme.textDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // ── Number display ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // backspace
                    GestureDetector(
                      onTap: _number.isEmpty ? null : _backspace,
                      onLongPress: _number.isEmpty ? null : _clear,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.backspace_outlined,
                          color: _number.isEmpty
                              ? AppTheme.textLight.withValues(alpha: 0.25)
                              : AppTheme.textLight,
                          size: 24,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _number.isEmpty ? 'הזן מספר' : _formatted,
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          fontSize: _number.isEmpty ? 22 : 36,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 2,
                          color: _number.isEmpty
                              ? AppTheme.textLight
                              : (isDark ? Colors.white : AppTheme.textDark),
                        ),
                      ),
                    ),
                    // paste
                    GestureDetector(
                      onTap: _pasteFromClipboard,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(Icons.content_paste_rounded,
                            color: AppTheme.textLight, size: 22),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 6),
              Divider(
                indent: 40,
                endIndent: 40,
                color: (isDark ? Colors.white : AppTheme.textDark)
                    .withValues(alpha: 0.1),
              ),

              // ── T9 contact suggestions ──────────────────────────────────────
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: matches.isEmpty
                    ? const SizedBox(height: 8, width: double.infinity)
                    : SizedBox(
                        height: 68,
                        width: double.infinity,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          itemCount: matches.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 8),
                          itemBuilder: (_, i) => _T9Chip(
                            match: matches[i],
                            primary: primary,
                            isDark: isDark,
                          ),
                        ),
                      ),
              ),

              // ── Keypad (always LTR so 1 is on the left) ────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Column(
                    children: [
                      _KeyRow(
                        keys: const [
                          _KeyData('1'), _KeyData('2'), _KeyData('3')
                        ],
                        onPress: _press,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 10),
                      _KeyRow(
                        keys: const [
                          _KeyData('4'), _KeyData('5'), _KeyData('6')
                        ],
                        onPress: _press,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 10),
                      _KeyRow(
                        keys: const [
                          _KeyData('7'), _KeyData('8'), _KeyData('9')
                        ],
                        onPress: _press,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 10),
                      _KeyRow(
                        keys: const [
                          _KeyData('*'), _KeyData('0'), _KeyData('#')
                        ],
                        onPress: _press,
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Action buttons ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ActionBtn(
                      icon: Icons.message_rounded,
                      color: const Color(0xFF2196F3),
                      label: 'SMS',
                      enabled: _number.isNotEmpty,
                      onTap: () => LaunchHelper.sendSms(_number),
                    ),
                    // Big call button
                    GestureDetector(
                      onTap: _number.isEmpty
                          ? null
                          : () => LaunchHelper.makeCall(_number),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: _number.isEmpty
                              ? AppTheme.textLight.withValues(alpha: 0.3)
                              : const Color(0xFF4CAF50),
                          shape: BoxShape.circle,
                          boxShadow: _number.isEmpty
                              ? []
                              : [
                                  BoxShadow(
                                    color: const Color(0xFF4CAF50)
                                        .withValues(alpha: 0.4),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                        ),
                        child: const Icon(Icons.call_rounded,
                            color: Colors.white, size: 30),
                      ),
                    ),
                    _ActionBtn(
                      icon: Icons.chat_rounded,
                      color: const Color(0xFF25D366),
                      label: 'WhatsApp',
                      enabled: _number.isNotEmpty,
                      iconWidget: const WhatsAppIcon(size: 24),
                      onTap: () => LaunchHelper.openWhatsApp(_number),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

// ── T9 suggestion chip ─────────────────────────────────────────────────────────

class _T9Chip extends StatelessWidget {
  final _ContactMatch match;
  final Color primary;
  final bool isDark;

  const _T9Chip({
    required this.match,
    required this.primary,
    required this.isDark,
  });

  String get _initials {
    final parts = match.name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts.last.isNotEmpty) {
      return '${parts.first[0]}${parts.last[0]}';
    }
    return match.name.isNotEmpty ? match.name[0] : '?';
  }

  String get _firstName {
    return match.name.trim().split(RegExp(r'\s+')).first;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        LaunchHelper.makeCall(match.phone);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: primary.withValues(alpha: isDark ? 0.18 : 0.1),
          borderRadius: BorderRadius.circular(22),
          border:
              Border.all(color: primary.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: primary.withValues(alpha: 0.25),
              child: Text(
                _initials,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _firstName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.call_rounded,
                        size: 10, color: const Color(0xFF4CAF50)),
                    const SizedBox(width: 3),
                    Text(
                      match.phone,
                      style: const TextStyle(
                          fontSize: 10, color: AppTheme.textLight),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Key row ────────────────────────────────────────────────────────────────────

class _KeyRow extends StatelessWidget {
  final List<_KeyData> keys;
  final void Function(String) onPress;
  final bool isDark;

  const _KeyRow({
    required this.keys,
    required this.onPress,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: keys
          .map((k) => Expanded(
                child: Center(
                  child: _DialKey(
                    data: k,
                    onPress: onPress,
                    isDark: isDark,
                  ),
                ),
              ))
          .toList(),
    );
  }
}

// ── Single dial key — iPhone-style circle ─────────────────────────────────────

class _DialKey extends StatefulWidget {
  final _KeyData data;
  final void Function(String) onPress;
  final bool isDark;

  const _DialKey({
    required this.data,
    required this.onPress,
    required this.isDark,
  });

  @override
  State<_DialKey> createState() => _DialKeyState();
}

class _DialKeyState extends State<_DialKey> {
  bool _pressed = false;

  Color get _bgIdle =>
      widget.isDark ? const Color(0xFF2C2C3E) : const Color(0xFFF2F2F7);

  Color get _bgPressed =>
      widget.isDark ? const Color(0xFF3D3D55) : const Color(0xFFDEDEE8);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPress(widget.data.digit);
      },
      onTapCancel: () => setState(() => _pressed = false),
      onLongPress: widget.data.digit == '0'
          ? () {
              HapticFeedback.mediumImpact();
              widget.onPress('+');
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 70),
        width: 74,
        height: 74,
        decoration: BoxDecoration(
          color: _pressed ? _bgPressed : _bgIdle,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withValues(alpha: widget.isDark ? 0.25 : 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.data.digit,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w300,
                color: widget.isDark ? Colors.white : const Color(0xFF1C1C1E),
                height: 1.0,
              ),
            ),
            if (widget.data.letters.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  widget.data.letters,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: widget.isDark
                        ? Colors.white.withValues(alpha: 0.55)
                        : const Color(0xFF8E8E93),
                    letterSpacing: 0.8,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Action button ──────────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final Widget? iconWidget;

  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.iconWidget,
  });

  @override
  Widget build(BuildContext context) {
    final c = enabled ? color : AppTheme.textLight.withValues(alpha: 0.5);
    Widget iconChild = iconWidget != null && enabled
        ? iconWidget!
        : (iconWidget != null
            ? ColorFiltered(
                colorFilter: ColorFilter.mode(
                    AppTheme.textLight.withValues(alpha: 0.5), BlendMode.srcIn),
                child: iconWidget!)
            : Icon(icon, color: c, size: 24));

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(child: iconChild),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: c, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
