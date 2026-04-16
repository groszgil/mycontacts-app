import 'dart:io';
import 'package:flutter/material.dart';
import '../models/app_contact.dart';
import '../utils/theme.dart';
import '../utils/launch_helper.dart';

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
      return '${parts.last[0]}${parts.first[0]}';
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

                    // Notes
                    if (contact.notes != null &&
                        contact.notes!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: primary.withValues(alpha: 0.15)),
                        ),
                        child: Text(
                          contact.notes!,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? Colors.white70
                                : AppTheme.textMedium,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
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
    if (contact.localPhotoPath != null &&
        File(contact.localPhotoPath!).existsSync()) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            File(contact.localPhotoPath!),
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

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
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
              Icon(icon, color: color, size: 22),
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

class _SmallActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SmallActionBtn({
    required this.icon,
    required this.color,
    required this.onTap,
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
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }
}
