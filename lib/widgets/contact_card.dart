import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_contact.dart';
import '../utils/theme.dart';
import '../utils/launch_helper.dart';

class ContactCard extends StatefulWidget {
  final AppContact contact;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onTap;
  final bool isListView;

  const ContactCard({
    super.key,
    required this.contact,
    required this.onEdit,
    required this.onDelete,
    this.onTap,
    this.isListView = false,
  });

  @override
  State<ContactCard> createState() => _ContactCardState();
}

class _ContactCardState extends State<ContactCard> {
  double _swipeDx = 0;
  bool _pressed = false;

  String get _initials {
    final parts = widget.contact.name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.last[0]}${parts.first[0]}';
    }
    return widget.contact.name.isNotEmpty ? widget.contact.name[0] : '?';
  }

  Color _avatarColor() {
    final colors = AppTheme.categoryColors;
    final index = widget.contact.name.codeUnitAt(0) % colors.length;
    return colors[index];
  }

  void _showPreviewDialog(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 280),
      transitionBuilder: (ctx, anim, _, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.elasticOut),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
      pageBuilder: (ctx, _, __) => _ContactPreviewDialog(
        contact: widget.contact,
        avatarColor: _avatarColor(),
        initials: _initials,
        onEdit: () {
          Navigator.pop(ctx);
          widget.onEdit();
        },
        onDelete: () {
          Navigator.pop(ctx);
          widget.onDelete();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _avatarColor();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.isListView) {
      return GestureDetector(
        onHorizontalDragUpdate: (details) {
          setState(() {
            _swipeDx = (_swipeDx + details.delta.dx).clamp(-80.0, 80.0);
          });
        },
        onHorizontalDragEnd: (details) {
          if (_swipeDx > 55) {
            HapticFeedback.mediumImpact();
            LaunchHelper.makeCall(widget.contact.effectivePrimaryPhone);
          } else if (_swipeDx < -55) {
            HapticFeedback.mediumImpact();
            LaunchHelper.openWhatsApp(widget.contact.effectivePrimaryPhone);
          }
          setState(() => _swipeDx = 0);
        },
        onHorizontalDragCancel: () => setState(() => _swipeDx = 0),
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap?.call();
        },
        onLongPress: () {
          HapticFeedback.mediumImpact();
          _showPreviewDialog(context);
        },
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.elasticOut,
          child: _buildListCard(color, isDark),
        ),
      );
    }

    final swipeRight = _swipeDx > 10;
    final swipeLeft = _swipeDx < -10;
    final swipeProgress = (_swipeDx.abs() / 60).clamp(0.0, 1.0);

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        setState(() {
          _swipeDx = (_swipeDx + details.delta.dx).clamp(-80.0, 80.0);
        });
      },
      onHorizontalDragEnd: (details) {
        if (_swipeDx > 55) {
          HapticFeedback.mediumImpact();
          LaunchHelper.makeCall(widget.contact.effectivePrimaryPhone);
        } else if (_swipeDx < -55) {
          HapticFeedback.mediumImpact();
          LaunchHelper.openWhatsApp(widget.contact.effectivePrimaryPhone);
        }
        setState(() => _swipeDx = 0);
      },
      onHorizontalDragCancel: () => setState(() => _swipeDx = 0),
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap?.call();
      },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _showPreviewDialog(context);
      },
      child: Stack(
        children: [
          // ── Swipe hint backgrounds ────────────────────────────────────────
          if (swipeRight)
            Positioned.fill(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 80),
                decoration: BoxDecoration(
                  color: Colors.green
                      .withValues(alpha: 0.15 + swipeProgress * 0.25),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.phone_rounded,
                            color: Colors.green
                                .withValues(alpha: 0.5 + swipeProgress * 0.5),
                            size: 28),
                        const SizedBox(height: 4),
                        Text(
                          'שיחה',
                          style: TextStyle(
                            color: Colors.green
                                .withValues(alpha: 0.5 + swipeProgress * 0.5),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (swipeLeft)
            Positioned.fill(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 80),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366)
                      .withValues(alpha: 0.15 + swipeProgress * 0.25),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_rounded,
                            color: const Color(0xFF25D366)
                                .withValues(alpha: 0.5 + swipeProgress * 0.5),
                            size: 28),
                        const SizedBox(height: 4),
                        Text(
                          'WhatsApp',
                          style: TextStyle(
                            color: const Color(0xFF25D366)
                                .withValues(alpha: 0.5 + swipeProgress * 0.5),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ── Card (slightly translated on swipe) with spring animation ────
          AnimatedScale(
            scale: _pressed ? 0.95 : 1.0,
            duration: const Duration(milliseconds: 100),
            curve: Curves.elasticOut,
            child: Transform.translate(
              offset: Offset(_swipeDx * 0.25, 0),
              child: _buildGridCard(color, isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridCard(Color color, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252540) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isDark ? 0.08 : 0.14),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Square photo area — fills top ~70% of card
          Expanded(
            flex: 7,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: _buildPhotoArea(color),
            ),
          ),
          // Name strip — bottom ~30%
          Expanded(
            flex: widget.contact.lastContactedLabel != null ? 4 : 3,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.contact.nickname ?? widget.contact.name,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppTheme.textDark,
                      height: 1.2,
                    ),
                  ),
                  if (widget.contact.lastContactedLabel != null) ...[
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryOf(context)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.contact.lastContactedLabel!,
                        style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.primaryOf(context),
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListCard(Color color, bool isDark) {
    return Container(
      height: 72,
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252540) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          // Avatar
          Hero(
            tag: 'contact_${widget.contact.id}',
            child: _buildCircleAvatar(color, 50),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.contact.nickname ?? widget.contact.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.contact.effectivePrimaryPhone,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textLight),
                ),
                if (widget.contact.lastContactedLabel != null)
                  Text(
                    widget.contact.lastContactedLabel!,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.primaryOf(context)
                          .withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
          ),
          // Quick call button
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              LaunchHelper.makeCall(widget.contact.effectivePrimaryPhone);
            },
            child: Container(
              margin: const EdgeInsets.only(right: 14),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.phone_rounded,
                  color: Colors.green, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleAvatar(Color color, double size) {
    if (widget.contact.localPhotoPath != null &&
        File(widget.contact.localPhotoPath!).existsSync()) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage:
            FileImage(File(widget.contact.localPhotoPath!)),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.4),
            color.withValues(alpha: 0.2),
          ],
        ),
      ),
      child: Center(
        child: Text(
          _initials,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.32,
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoArea(Color color) {
    if (widget.contact.localPhotoPath != null &&
        File(widget.contact.localPhotoPath!).existsSync()) {
      return Hero(
        tag: 'contact_${widget.contact.id}',
        child: Image.file(
          File(widget.contact.localPhotoPath!),
          fit: BoxFit.cover,
        ),
      );
    }
    return Hero(
      tag: 'contact_${widget.contact.id}',
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.28),
              color.withValues(alpha: 0.12),
            ],
          ),
        ),
        child: Center(
          child: FittedBox(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                _initials,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Contact Preview Dialog ─────────────────────────────────────────────────

class _ContactPreviewDialog extends StatelessWidget {
  final AppContact contact;
  final Color avatarColor;
  final String initials;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ContactPreviewDialog({
    required this.contact,
    required this.avatarColor,
    required this.initials,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppTheme.primaryOf(context);
    final primaryPhone = contact.effectivePrimaryPhone;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF252540) : Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                // Avatar
                _buildAvatar(),
                const SizedBox(height: 14),
                // Name
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    contact.name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppTheme.textDark,
                    ),
                  ),
                ),
                // Nickname
                if (contact.nickname != null &&
                    contact.nickname!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    contact.nickname!,
                    style: const TextStyle(
                        fontSize: 15, color: AppTheme.textLight),
                  ),
                ],
                // Last contacted
                if (contact.lastContactedLabel != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    contact.lastContactedLabel!,
                    style: TextStyle(
                        fontSize: 13,
                        color: primary.withValues(alpha: 0.8)),
                  ),
                ],
                // Birthday
                if (contact.birthday != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cake_rounded,
                          size: 14, color: AppTheme.textLight),
                      const SizedBox(width: 4),
                      Text(
                        '${contact.birthday!.day}/${contact.birthday!.month}',
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.textLight),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                // Action buttons row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ActionCircle(
                        icon: Icons.phone_rounded,
                        color: Colors.green,
                        label: 'שיחה',
                        onTap: () {
                          Navigator.pop(context);
                          LaunchHelper.makeCall(primaryPhone);
                        },
                      ),
                      _ActionCircle(
                        icon: Icons.sms_rounded,
                        color: const Color(0xFF2196F3),
                        label: 'SMS',
                        onTap: () {
                          Navigator.pop(context);
                          LaunchHelper.sendSms(primaryPhone);
                        },
                      ),
                      _ActionCircle(
                        icon: Icons.chat_rounded,
                        color: const Color(0xFF25D366),
                        label: 'WhatsApp',
                        onTap: () {
                          Navigator.pop(context);
                          LaunchHelper.openWhatsApp(primaryPhone);
                        },
                      ),
                      if (contact.effectiveEmail != null &&
                          contact.effectiveEmail!.isNotEmpty)
                        _ActionCircle(
                          icon: Icons.mail_rounded,
                          color: const Color(0xFFEA4335),
                          label: 'מייל',
                          onTap: () {
                            Navigator.pop(context);
                            LaunchHelper.sendEmail(
                                contact.effectiveEmail!);
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                // Edit / Delete row
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: onEdit,
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.only(
                              bottomRight: Radius.circular(24),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Icon(Icons.edit_rounded,
                                  size: 18, color: primary),
                              const SizedBox(width: 6),
                              Text(
                                'עריכה',
                                style: TextStyle(
                                  color: primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 48,
                      color: Colors.grey.withValues(alpha: 0.2),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: onDelete,
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(24),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Icon(Icons.delete_rounded,
                                  size: 18, color: Colors.red),
                              SizedBox(width: 6),
                              Text(
                                'מחיקה',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    if (contact.localPhotoPath != null &&
        File(contact.localPhotoPath!).existsSync()) {
      return CircleAvatar(
        radius: 50,
        backgroundImage: FileImage(File(contact.localPhotoPath!)),
      );
    }
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            avatarColor.withValues(alpha: 0.4),
            avatarColor.withValues(alpha: 0.2),
          ],
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: avatarColor,
            fontWeight: FontWeight.w800,
            fontSize: 32,
          ),
        ),
      ),
    );
  }
}

class _ActionCircle extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _ActionCircle({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Skeleton loading card ──────────────────────────────────────────────────

class ContactCardSkeleton extends StatefulWidget {
  const ContactCardSkeleton({super.key});

  @override
  State<ContactCardSkeleton> createState() => _ContactCardSkeletonState();
}

class _ContactCardSkeletonState extends State<ContactCardSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _shimmer = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor =
        isDark ? const Color(0xFF252540) : const Color(0xFFE8E8EE);
    final shimmerColor =
        isDark ? const Color(0xFF3A3A5A) : const Color(0xFFF5F5FA);

    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [baseColor, shimmerColor, baseColor],
              stops: [
                (_shimmer.value - 0.3).clamp(0.0, 1.0),
                _shimmer.value.clamp(0.0, 1.0),
                (_shimmer.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 7,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: Container(color: Colors.transparent),
                ),
              ),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: 10,
                        width: 70,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF3A3A5A)
                              : const Color(0xFFD8D8E8),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 8,
                        width: 50,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF2E2E4E)
                              : const Color(0xFFE8E8F0),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── (Legacy _ActionSheet removed — replaced by _ContactPreviewDialog) ─────

class _ActionSheet extends StatelessWidget {
  final AppContact contact;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ActionSheet({
    required this.contact,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final primary = AppTheme.primaryOf(context);
    final primaryPhone = contact.effectivePrimaryPhone;
    final phones = contact.phones;
    final phoneLabels = contact.phoneLabels;
    final emails = contact.emails;
    final emailLabels = contact.emailLabels;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Name + primary phone
            Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Column(
                children: [
                  Text(
                    contact.name,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    primaryPhone,
                    style: const TextStyle(
                        fontSize: 14, color: AppTheme.textLight),
                  ),
                  if (contact.notes != null &&
                      contact.notes!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        contact.notes!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.textMedium),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),

            // Primary phone actions
            _SheetTile(
              icon: Icons.phone_rounded,
              iconColor: primary,
              title: 'חיוג',
              subtitle: phones.length > 1
                  ? '${phoneLabels.isNotEmpty ? phoneLabels[contact.primaryPhoneIndex.clamp(0, phoneLabels.length - 1)] : "ראשי"} • $primaryPhone'
                  : null,
              onTap: () {
                Navigator.pop(context);
                LaunchHelper.makeCall(primaryPhone);
              },
            ),
            _SheetTile(
              icon: Icons.sms_rounded,
              iconColor: const Color(0xFF2196F3),
              title: 'הודעת SMS',
              onTap: () {
                Navigator.pop(context);
                LaunchHelper.sendSms(primaryPhone);
              },
            ),
            _SheetTile(
              icon: Icons.chat_rounded,
              iconColor: const Color(0xFF25D366),
              title: 'WhatsApp',
              onTap: () {
                Navigator.pop(context);
                LaunchHelper.openWhatsApp(primaryPhone);
              },
            ),

            // Extra phones (non-primary)
            if (phones.length > 1)
              for (int i = 0; i < phones.length; i++)
                if (i !=
                    contact.primaryPhoneIndex.clamp(0, phones.length - 1))
                  _SheetTile(
                    icon: Icons.phone_outlined,
                    iconColor: primary.withValues(alpha: 0.6),
                    title:
                        'חיוג (${i < phoneLabels.length ? phoneLabels[i] : "נייד"})',
                    subtitle: phones[i],
                    onTap: () {
                      Navigator.pop(context);
                      LaunchHelper.makeCall(phones[i]);
                    },
                  ),

            // Emails
            if (emails.isNotEmpty)
              for (int i = 0; i < emails.length; i++)
                _SheetTile(
                  icon: Icons.mail_rounded,
                  iconColor: const Color(0xFFEA4335),
                  title:
                      'מייל (${i < emailLabels.length ? emailLabels[i] : "כללי"})',
                  subtitle: emails[i],
                  onTap: () {
                    Navigator.pop(context);
                    LaunchHelper.sendEmail(emails[i]);
                  },
                )
            else if (contact.email != null && contact.email!.isNotEmpty)
              _SheetTile(
                icon: Icons.mail_rounded,
                iconColor: const Color(0xFFEA4335),
                title: 'שליחת מייל',
                subtitle: contact.email,
                onTap: () {
                  Navigator.pop(context);
                  LaunchHelper.sendEmail(contact.email!);
                },
              ),

            const Divider(height: 1),
            _SheetTile(
              icon: Icons.edit_rounded,
              iconColor: AppTheme.textMedium,
              title: 'עריכה',
              onTap: () {
                Navigator.pop(context);
                onEdit();
              },
            ),
            _SheetTile(
              icon: Icons.delete_rounded,
              iconColor: Colors.red,
              title: 'מחיקה',
              titleColor: Colors.red,
              onTap: onDelete,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _SheetTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final VoidCallback onTap;

  const _SheetTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.titleColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: titleColor ?? AppTheme.textDark,
          fontSize: 16,
        ),
      ),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style:
                  const TextStyle(color: AppTheme.textLight, fontSize: 13))
          : null,
      onTap: onTap,
    );
  }
}
