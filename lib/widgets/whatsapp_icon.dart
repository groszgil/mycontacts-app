import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// The official WhatsApp logo: green circle with the white WhatsApp glyph.
/// Drop-in replacement for [Icon] wherever a WhatsApp action button is needed.
class WhatsAppIcon extends StatelessWidget {
  final double size;

  const WhatsAppIcon({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF25D366),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: FaIcon(
            FontAwesomeIcons.whatsapp,
            color: Colors.white,
            size: size * 0.64,
          ),
        ),
      ),
    );
  }
}
