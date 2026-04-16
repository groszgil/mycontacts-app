import 'package:flutter/material.dart';
import '../utils/theme.dart';
import '../utils/launch_helper.dart';
import '../widgets/app_logo.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppTheme.primaryOf(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('אודות')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          child: Column(
            children: [
              // Logo + name
              const SizedBox(height: 8),
              const AppLogo(size: 96),
              const SizedBox(height: 16),
              Text(
                'אנשי קשר מועדפים',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: primary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'גרסה 1.0.0',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textLight,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 28),

              // About the app
              _InfoCard(
                isDark: isDark,
                icon: Icons.info_rounded,
                iconColor: primary,
                title: 'אודות האפליקציה',
                content:
                    'אנשי קשר מועדפים היא אפליקציה המאפשרת לנהל ולגשת בקלות לאנשי הקשר החשובים ביותר שלך — בלחיצה אחת.\n\n'
                    'מיועדת לממשק נוח, מהיר ואינטואיטיבי, עם תמיכה מלאה בעברית.',
              ),
              const SizedBox(height: 14),

              // How to use
              _InfoCard(
                isDark: isDark,
                icon: Icons.help_outline_rounded,
                iconColor: const Color(0xFF27AE60),
                title: 'כיצד להשתמש',
                content:
                    '• לחץ על כרטיס — פתיחת מסך פרטי איש קשר מלא\n'
                    '• החלקה ימינה על כרטיס — חיוג מיידי\n'
                    '• החלקה שמאלה על כרטיס — פתיחת WhatsApp\n'
                    '• לחיצה ארוכה — תפריט מהיר (SMS, מייל, עריכה, מחיקה)\n'
                    '• לחץ "הוסף ידנית" להוספת איש קשר חדש\n'
                    '• לחץ "הוסף מאנשי הקשר" לייבוא מרשימת הטלפון\n'
                    '• ניתן לארגן לפי קטגוריות ולשנות סדר תצוגה\n'
                    '• בהגדרות: צבע ראשי, פריסת גריד, גודל גופן, גיבוי וייבוא',
              ),
              const SizedBox(height: 14),

              // Developer
              _InfoCard(
                isDark: isDark,
                icon: Icons.code_rounded,
                iconColor: const Color(0xFF2F80ED),
                title: 'מפתח',
                content: 'גיל גרוס\nפותח באהבה עבור משתמשי iOS 🇮🇱',
              ),
              const SizedBox(height: 24),

              // Feedback button
              _FeedbackButton(primary: primary),
              const SizedBox(height: 16),

              Text(
                'נבנה עם Flutter ❤️',
                style: TextStyle(fontSize: 12, color: AppTheme.textLight),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Info card ──────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String content;

  const _InfoCard({
    required this.isDark,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final primary = AppTheme.primaryOf(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252540) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : AppTheme.textMedium,
                height: 1.6),
          ),
        ],
      ),
    );
  }
}

// ── Feedback button ────────────────────────────────────────────────────────

class _FeedbackButton extends StatelessWidget {
  final Color primary;

  const _FeedbackButton({required this.primary});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => LaunchHelper.sendEmail(
        'groszgil@gmail.com',
        subject: 'משוב על אפליקציית אנשי קשר מועדפים',
      ),
      child: Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [primary, Color.lerp(primary, Colors.black, 0.25)!],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mail_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'נתקלת בבעיה? יש לך רעיון לשיפור?',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                ),
                Text(
                  'לחץ כאן לשליחת מייל למפתח',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
