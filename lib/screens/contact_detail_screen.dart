import 'dart:io';
import 'package:flutter/material.dart';
import '../models/app_contact.dart';
import '../services/storage_service.dart';
import '../utils/theme.dart';
import '../utils/launch_helper.dart';
import '../widgets/whatsapp_icon.dart';

class ContactDetailScreen extends StatelessWidget {
  final AppContact contact;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ContactDetailScreen({
    super.key,
    required this.contact,
    required this.onEdit,
    required this.onDelete,
  });

  String get _initials {
    final parts = contact.name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}';
    }
    return contact.name.isNotEmpty ? contact.name[0] : '?';
  }

  Color _avatarColor() {
    final colors = AppTheme.categoryColors;
    return colors[contact.name.codeUnitAt(0) % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppTheme.primaryOf(context);
    final color = _avatarColor();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF1A1A2E) : AppTheme.surface,
        body: CustomScrollView(
          slivers: [
            // ── Photo AppBar ─────────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 280,
              pinned: true,
              backgroundColor:
                  isDark ? const Color(0xFF252540) : Colors.white,
              leading: _CircleBtn(
                icon: Icons.arrow_back_ios_rounded,
                onTap: () => Navigator.pop(context),
              ),
              actions: [
                _CircleBtn(
                  icon: Icons.edit_rounded,
                  onTap: () {
                    Navigator.pop(context);
                    onEdit();
                  },
                ),
                _CircleBtn(
                  icon: Icons.delete_rounded,
                  color: Colors.red,
                  onTap: () {
                    Navigator.pop(context);
                    onDelete();
                  },
                ),
                const SizedBox(width: 8),
              ],
              title: Text(
                contact.name,
                style: TextStyle(
                  color: isDark ? Colors.white : AppTheme.textDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: Hero(
                  tag: 'contact_${contact.id}',
                  child: _buildPhotoArea(color),
                ),
              ),
            ),

            // ── Content ──────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text(
                      contact.name,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppTheme.textDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Quick action row ─────────────────────────────────────
                    Row(
                      children: [
                        _QuickAction(
                          icon: Icons.phone_rounded,
                          label: 'שיחה',
                          color: primary,
                          onTap: () => LaunchHelper.makeCall(
                              contact.effectivePrimaryPhone),
                        ),
                        const SizedBox(width: 10),
                        _QuickAction(
                          icon: Icons.sms_rounded,
                          label: 'SMS',
                          color: const Color(0xFF2196F3),
                          onTap: () => LaunchHelper.sendSms(
                              contact.effectivePrimaryPhone),
                        ),
                        const SizedBox(width: 10),
                        _QuickAction(
                          icon: Icons.chat_rounded,
                          label: 'WhatsApp',
                          color: const Color(0xFF25D366),
                          iconWidget: const WhatsAppIcon(size: 22),
                          onTap: () => LaunchHelper.openWhatsApp(
                              contact.effectivePrimaryPhone),
                        ),
                        if (contact.effectiveEmail != null &&
                            contact.effectiveEmail!.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          _QuickAction(
                            icon: Icons.mail_rounded,
                            label: 'מייל',
                            color: const Color(0xFFEA4335),
                            onTap: () => LaunchHelper.sendEmail(
                                contact.effectiveEmail!),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 28),

                    // ── Phones ───────────────────────────────────────────────
                    if (contact.phones.isNotEmpty) ...[
                      _SectionTitle(
                          'טלפונים', Icons.phone_rounded, primary),
                      const SizedBox(height: 10),
                      for (int i = 0; i < contact.phones.length; i++) ...[
                        _DetailTile(
                          isDark: isDark,
                          leadingIcon: Icons.phone_outlined,
                          leadingColor: primary,
                          title: contact.phones[i],
                          subtitle: i < contact.phoneLabels.length
                              ? contact.phoneLabels[i]
                              : 'נייד',
                          isPrimary: i ==
                              contact.primaryPhoneIndex
                                  .clamp(0, contact.phones.length - 1),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _SmallActionBtn(
                                icon: Icons.phone_rounded,
                                color: primary,
                                onTap: () => LaunchHelper.makeCall(
                                    contact.phones[i]),
                              ),
                              const SizedBox(width: 6),
                              _SmallActionBtn(
                                icon: Icons.sms_rounded,
                                color: const Color(0xFF2196F3),
                                onTap: () => LaunchHelper.sendSms(
                                    contact.phones[i]),
                              ),
                              const SizedBox(width: 6),
                              _SmallActionBtn(
                                icon: Icons.chat_rounded,
                                color: const Color(0xFF25D366),
                                iconWidget: const WhatsAppIcon(size: 16),
                                onTap: () => LaunchHelper.openWhatsApp(
                                    contact.phones[i]),
                              ),
                            ],
                          ),
                        ),
                        if (i < contact.phones.length - 1)
                          const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 20),
                    ],

                    // ── Emails ───────────────────────────────────────────────
                    if (contact.emails.isNotEmpty) ...[
                      _SectionTitle('מייל', Icons.mail_rounded,
                          const Color(0xFFEA4335)),
                      const SizedBox(height: 10),
                      for (int i = 0; i < contact.emails.length; i++) ...[
                        _DetailTile(
                          isDark: isDark,
                          leadingIcon: Icons.mail_outline,
                          leadingColor: const Color(0xFFEA4335),
                          title: contact.emails[i],
                          subtitle: i < contact.emailLabels.length
                              ? contact.emailLabels[i]
                              : 'כללי',
                          trailing: _SmallActionBtn(
                            icon: Icons.mail_rounded,
                            color: const Color(0xFFEA4335),
                            onTap: () => LaunchHelper.sendEmail(
                                contact.emails[i]),
                          ),
                        ),
                        if (i < contact.emails.length - 1)
                          const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 20),
                    ],

                    // ── Dates & Events (birthday / anniversary / friendship / custom) ──
                    Builder(builder: (ctx) {
                      final friendship = contact.customEvents
                          .where((e) => e.name == 'חברות')
                          .firstOrNull;
                      final customEvents = contact.customEvents
                          .where((e) => e.name != 'חברות')
                          .toList();
                      final hasDates = contact.birthday != null ||
                          contact.anniversary != null ||
                          friendship != null ||
                          customEvents.isNotEmpty;
                      if (!hasDates) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionTitle('תאריכים ואירועים',
                              Icons.event_rounded, Colors.orange),
                          const SizedBox(height: 10),

                          // Birthday
                          if (contact.birthday != null) ...[
                            _DateInfoTile(
                              isDark: isDark,
                              icon: Icons.cake_rounded,
                              color: Colors.orange,
                              label: 'יום הולדת',
                              date: contact.birthday!,
                              daysUntil: contact.daysUntilBirthday,
                              yearsCompleted: contact.completedBirthdayYears,
                              yearsLabel: 'בן/בת',
                            ),
                            const SizedBox(height: 8),
                          ],

                          // Anniversary
                          if (contact.anniversary != null) ...[
                            _DateInfoTile(
                              isDark: isDark,
                              icon: Icons.favorite_rounded,
                              color: const Color(0xFFE91E63),
                              label: 'יום נישואין',
                              date: contact.anniversary!,
                              daysUntil: contact.daysUntilAnniversary,
                              yearsCompleted: contact.completedAnniversaryYears,
                            ),
                            const SizedBox(height: 8),
                          ],

                          // Friendship
                          if (friendship != null) ...[
                            _DateInfoTile(
                              isDark: isDark,
                              icon: Icons.people_rounded,
                              color: const Color(0xFF42A5F5),
                              label: 'חברות',
                              date: friendship.date,
                              daysUntil: friendship.daysUntil,
                              yearsCompleted: () {
                                final now = DateTime.now();
                                final d = friendship.date;
                                final passed = !DateTime(now.year, d.month, d.day)
                                    .isAfter(DateTime(now.year, now.month, now.day));
                                return now.year - d.year - (passed ? 0 : 1);
                              }(),
                              yearsLabel: 'שנות חברות',
                            ),
                            const SizedBox(height: 8),
                          ],

                          // Custom events — inline, right under the fixed dates
                          for (final ev in customEvents) ...[
                            _EventDetailTile(isDark: isDark, event: ev),
                            const SizedBox(height: 8),
                          ],

                          const SizedBox(height: 12),
                        ],
                      );
                    }),

                    // ── Address ───────────────────────────────────────────────
                    if (contact.address != null &&
                        contact.address!.isNotEmpty) ...[
                      _SectionTitle(
                          'כתובת', Icons.location_on_rounded, Colors.teal),
                      const SizedBox(height: 10),
                      _AddressTile(
                          isDark: isDark, address: contact.address!),
                      const SizedBox(height: 20),
                    ],

                    // ── Notes (bottom) ────────────────────────────────────────
                    if (contact.notes != null && contact.notes!.isNotEmpty) ...[
                      _SectionTitle('הערות', Icons.note_rounded, AppTheme.textMedium),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF252540)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withValues(alpha: isDark ? 0.08 : 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          contact.notes!,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white70 : AppTheme.textMedium,
                            height: 1.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoArea(Color color) {
    final photoPath = StorageService.resolvePhotoPath(contact.localPhotoPath);
    if (photoPath != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            File(photoPath),
            fit: BoxFit.cover,
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.35),
                ],
                stops: const [0.55, 1.0],
              ),
            ),
          ),
        ],
      );
    }
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.45),
            color.withValues(alpha: 0.2),
          ],
        ),
      ),
      child: Center(
        child: Text(
          _initials,
          style: TextStyle(
            color: color,
            fontSize: 90,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;

  const _CircleBtn({required this.icon, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(6),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.25),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color ?? Colors.white, size: 18),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  /// Optional override — when set, rendered instead of [Icon(icon)].
  final Widget? iconWidget;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.iconWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              iconWidget ?? Icon(icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _SectionTitle(this.title, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _DetailTile extends StatelessWidget {
  final bool isDark;
  final IconData leadingIcon;
  final Color leadingColor;
  final String title;
  final String subtitle;
  final bool isPrimary;
  final Widget trailing;

  const _DetailTile({
    required this.isDark,
    required this.leadingIcon,
    required this.leadingColor,
    required this.title,
    required this.subtitle,
    this.isPrimary = false,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252540) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: isPrimary
            ? Border.all(
                color: AppTheme.primaryOf(context).withValues(alpha: 0.3),
                width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.08 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: leadingColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(leadingIcon, color: leadingColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                ),
                Text(
                  subtitle + (isPrimary ? ' · ראשי' : ''),
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textLight),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _DateInfoTile extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final Color color;
  final String label;
  final DateTime date;
  final int? daysUntil;
  final int? yearsCompleted;
  /// If null → "X שנים יחד". Set to e.g. "בן/בת" or "שנות חברות".
  final String? yearsLabel;

  const _DateInfoTile({
    required this.isDark,
    required this.icon,
    required this.color,
    required this.label,
    required this.date,
    this.daysUntil,
    this.yearsCompleted,
    this.yearsLabel,
  });

  String get _formatted =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  String? get _daysLabel {
    if (daysUntil == null) return null;
    if (daysUntil == 0) return '🎂 היום!';
    if (daysUntil == 1) return 'מחר!';
    return 'עוד $daysUntil ימים';
  }

  /// The next occurrence label — shown under the days counter so the user
  /// knows what milestone is being counted toward.
  /// e.g. "לגיל 45" / "שנה 51 יחד" / "שנה 11 לחברות"
  String? get _nextLabel {
    final d = daysUntil;
    final y = yearsCompleted;
    if (d == null || d == 0 || d == 1) return null; // "היום!" / "מחר!" is self-explanatory
    if (y == null) return null;
    final next = y + 1;
    if (yearsLabel == 'בן/בת') return 'בן/בת $next';
    if (yearsLabel == 'שנות חברות') return '$next שנות חברות';
    return '$next שנים נשואין'; // anniversary
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252540) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.08 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
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
                Text(
                  _formatted,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                ),
                if (yearsCompleted != null && yearsCompleted! > 0)
                  Text(
                    yearsLabel != null
                        ? '$yearsLabel $yearsCompleted'
                        : '$yearsCompleted שנים נשואין',
                    style: TextStyle(
                      fontSize: 12,
                      color: color.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          // Days-until badge — shows days + next milestone on separate lines
          if (_daysLabel != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: daysUntil == 0
                    ? color.withValues(alpha: 0.2)
                    : color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    _daysLabel!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  if (_nextLabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _nextLabel!,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: color.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SmallActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  /// Optional override — when set, rendered instead of [Icon(icon)].
  final Widget? iconWidget;

  const _SmallActionBtn({
    required this.icon,
    required this.color,
    required this.onTap,
    this.iconWidget,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: iconWidget ?? Icon(icon, color: color, size: 16),
        ),
      ),
    );
  }
}

// ── Address tile ───────────────────────────────────────────────────────────

class _AddressTile extends StatelessWidget {
  final bool isDark;
  final String address; // raw "\n"-separated storage string

  const _AddressTile({required this.isDark, required this.address});

  static const _teal = Colors.teal;

  List<String> get _parts {
    final p = address.split('\n');
    return [
      p.isNotEmpty ? p[0] : '',
      p.length > 1 ? p[1] : '',
      p.length > 2 ? p[2] : '',
    ];
  }

  String get _navAddress {
    final visible = _parts.where((s) => s.isNotEmpty).toList();
    return visible.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final parts = _parts;
    final street = parts[0];
    final city   = parts[1];
    final zip    = parts[2];
    final nav    = _navAddress;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252540) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.08 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Address text — icon + lines
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _teal.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_on_rounded,
                    color: _teal, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (street.isNotEmpty)
                        Text(
                          street,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                        ),
                      if (city.isNotEmpty || zip.isNotEmpty)
                        Text(
                          [if (city.isNotEmpty) city,
                           if (zip.isNotEmpty) zip].join('  '),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textMedium,
                          ),
                        ),
                      // Fallback: legacy single-string address
                      if (street.isEmpty && city.isEmpty)
                        Text(
                          address,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white70 : AppTheme.textDark,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),
          // Map buttons row
          Row(
            children: [
              _MapBtn(
                label: 'Google Maps',
                color: const Color(0xFF4285F4),
                icon: Icons.map_rounded,
                onTap: () => LaunchHelper.openGoogleMaps(nav),
              ),
              const SizedBox(width: 8),
              _MapBtn(
                label: 'Waze',
                color: const Color(0xFF33CCFF),
                icon: Icons.navigation_rounded,
                onTap: () => LaunchHelper.openWaze(nav),
              ),
              const SizedBox(width: 8),
              _MapBtn(
                label: 'Apple Maps',
                color: const Color(0xFF007AFF),
                icon: Icons.place_rounded,
                onTap: () => LaunchHelper.openAppleMaps(nav),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MapBtn extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _MapBtn({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Custom event detail tile ───────────────────────────────────────────────

class _EventDetailTile extends StatelessWidget {
  final bool isDark;
  final ContactEvent event;

  const _EventDetailTile({required this.isDark, required this.event});

  static const _purple = AppTheme.primary;

  @override
  Widget build(BuildContext context) {
    final dateStr =
        '${event.date.day.toString().padLeft(2, '0')}/${event.date.month.toString().padLeft(2, '0')}/${event.date.year}';
    final days = event.daysUntil;

    String? daysLabel;
    Color daysColor = _purple;
    if (days != null) {
      if (days == 0) {
        daysLabel = '🎉 היום!';
      } else if (days == 1) {
        daysLabel = 'מחר!';
      } else {
        daysLabel = 'עוד $days ימים';
        if (days > 7) daysColor = AppTheme.textLight;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252540) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.08 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _purple.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.event_rounded, color: _purple, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      dateStr,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textLight),
                    ),
                    if (event.yearly) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: _purple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'שנתי',
                          style: TextStyle(
                              fontSize: 10,
                              color: _purple,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                    // Reminder badge
                    if (event.reminder) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.notifications_active_rounded,
                                size: 10, color: Colors.orange),
                            SizedBox(width: 3),
                            Text('תזכורת',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (daysLabel != null)
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
    );
  }
}
