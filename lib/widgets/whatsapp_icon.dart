import 'package:flutter/material.dart';

/// A pixel-accurate WhatsApp-style icon: green circle + white speech bubble
/// containing a green phone handset.  Drop-in anywhere an [Icon] is used for
/// WhatsApp actions.
class WhatsAppIcon extends StatelessWidget {
  final double size;

  const WhatsAppIcon({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _WhatsAppPainter()),
    );
  }
}

class _WhatsAppPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    // ── 1. Green background circle ─────────────────────────────────────────
    canvas.drawCircle(
      Offset(cx, cy),
      w / 2,
      Paint()..color = const Color(0xFF25D366),
    );

    // ── 2. White speech bubble (rounded rect + tail) ───────────────────────
    final whitePaint = Paint()..color = Colors.white;

    // Main bubble body
    canvas.drawRRect(
      RRect.fromLTRBR(
        w * 0.12, h * 0.09,
        w * 0.88, h * 0.73,
        Radius.circular(w * 0.13),
      ),
      whitePaint,
    );

    // Tail (bottom-left pointing)
    final tail = Path()
      ..moveTo(w * 0.17, h * 0.70)
      ..lineTo(w * 0.09, h * 0.91)
      ..lineTo(w * 0.39, h * 0.74)
      ..close();
    canvas.drawPath(tail, whitePaint);

    // ── 3. Green phone icon inside the bubble ──────────────────────────────
    // Use TextPainter to draw the Material phone icon glyph in green
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.phone_rounded.codePoint),
        style: TextStyle(
          fontSize: w * 0.44,
          fontFamily: Icons.phone_rounded.fontFamily,
          color: const Color(0xFF25D366),
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Center the phone glyph horizontally; vertically inside the bubble body
    final iconX = cx - tp.width / 2 + w * 0.02;
    // Bubble body center Y: between 0.09h and 0.73h → 0.41h
    final iconY = h * 0.41 - tp.height / 2;
    tp.paint(canvas, Offset(iconX, iconY));
  }

  @override
  bool shouldRepaint(covariant _WhatsAppPainter old) => false;
}
