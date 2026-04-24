import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/theme.dart';
import '../utils/launch_helper.dart';
import '../widgets/whatsapp_icon.dart';

class DialerScreen extends StatefulWidget {
  const DialerScreen({super.key});

  @override
  State<DialerScreen> createState() => _DialerScreenState();
}

class _DialerScreenState extends State<DialerScreen> {
  String _number = '';

  void _press(String digit) {
    HapticFeedback.lightImpact();
    if (_number.length >= 20) return;
    setState(() => _number += digit);
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null) return;
    // Keep only digits, +, *, #
    final pasted = data!.text!.replaceAll(RegExp(r'[^\d+*#]'), '');
    if (pasted.isEmpty) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _number = (_number + pasted).substring(
        0,
        (_number + pasted).length.clamp(0, 20),
      );
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

  String get _formatted {
    // Pretty-format Israeli mobile: 05X-XXXXXXX
    final d = _number.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('0') && d.length >= 3) {
      if (d.length <= 3) return d;
      if (d.length <= 7) return '${d.substring(0, 3)}-${d.substring(3)}';
      return '${d.substring(0, 3)}-${d.substring(3, 7)}-${d.substring(7)}';
    }
    if (_number.startsWith('+') && d.length > 3) {
      return _number; // International — keep as-is
    }
    return _number;
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
          child: Column(
            children: [
              // ── Header ───────────────────────────────────────────────────
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

              // ── Number display ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // RIGHT side (RTL first child) — delete / backspace button
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

                    // LEFT side (RTL last child) — paste button
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

              const SizedBox(height: 8),
              Divider(
                  indent: 40,
                  endIndent: 40,
                  color: (isDark ? Colors.white : AppTheme.textDark)
                      .withValues(alpha: 0.1)),
              const SizedBox(height: 16),

              // ── Keypad ────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    _KeyRow(keys: const [
                      _KeyData('1', ''),
                      _KeyData('2', 'ABC'),
                      _KeyData('3', 'DEF'),
                    ], onPress: _press, isDark: isDark, primary: primary),
                    const SizedBox(height: 8),
                    _KeyRow(keys: const [
                      _KeyData('4', 'GHI'),
                      _KeyData('5', 'JKL'),
                      _KeyData('6', 'MNO'),
                    ], onPress: _press, isDark: isDark, primary: primary),
                    const SizedBox(height: 8),
                    _KeyRow(keys: const [
                      _KeyData('7', 'PQRS'),
                      _KeyData('8', 'TUV'),
                      _KeyData('9', 'WXYZ'),
                    ], onPress: _press, isDark: isDark, primary: primary),
                    const SizedBox(height: 8),
                    _KeyRow(keys: const [
                      _KeyData('*', ''),
                      _KeyData('0', '+'),
                      _KeyData('#', ''),
                    ], onPress: _press, isDark: isDark, primary: primary),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Action buttons ────────────────────────────────────────────
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

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Key data ───────────────────────────────────────────────────────────────

class _KeyData {
  final String digit;
  final String letters;
  const _KeyData(this.digit, this.letters);
}

// ── Key row ────────────────────────────────────────────────────────────────

class _KeyRow extends StatelessWidget {
  final List<_KeyData> keys;
  final void Function(String) onPress;
  final bool isDark;
  final Color primary;

  const _KeyRow({
    required this.keys,
    required this.onPress,
    required this.isDark,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: keys
          .map((k) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _DialKey(
                    data: k,
                    onPress: onPress,
                    isDark: isDark,
                    primary: primary,
                  ),
                ),
              ))
          .toList(),
    );
  }
}

// ── Single dial key ────────────────────────────────────────────────────────

class _DialKey extends StatefulWidget {
  final _KeyData data;
  final void Function(String) onPress;
  final bool isDark;
  final Color primary;

  const _DialKey({
    required this.data,
    required this.onPress,
    required this.isDark,
    required this.primary,
  });

  @override
  State<_DialKey> createState() => _DialKeyState();
}

class _DialKeyState extends State<_DialKey> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark
        ? (_pressed
            ? const Color(0xFF3A3A5C)
            : const Color(0xFF252540))
        : (_pressed
            ? const Color(0xFFE8E4FF)
            : Colors.white);

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
        duration: const Duration(milliseconds: 80),
        height: 64,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: widget.isDark ? 0.12 : 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.data.digit,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w400,
                color: widget.isDark ? Colors.white : AppTheme.textDark,
                height: 1.0,
              ),
            ),
            if (widget.data.letters.isNotEmpty)
              Text(
                widget.data.letters,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textLight,
                  letterSpacing: 1.5,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Action button ──────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  /// Optional override — when set, rendered instead of [Icon(icon)].
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
