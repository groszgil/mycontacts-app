import 'package:flutter/material.dart';

/// The app logo widget — used in the splash screen and About tab.
class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 80});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFADA4FF), Color(0xFF6C63FF), Color(0xFF3D35CC)],
          stops: [0.0, 0.5, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.48),
            blurRadius: size * 0.38,
            offset: Offset(0, size * 0.12),
            spreadRadius: -size * 0.04,
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Decorative circle — top-right
          Positioned(
            top: -size * 0.07,
            right: -size * 0.07,
            child: Container(
              width: size * 0.52,
              height: size * 0.52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.09),
              ),
            ),
          ),
          // Decorative circle — bottom-left
          Positioned(
            bottom: -size * 0.1,
            left: -size * 0.06,
            child: Container(
              width: size * 0.4,
              height: size * 0.4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          // Main person icon
          Center(
            child: Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: size * 0.5,
            ),
          ),
          // Gold star badge — bottom-right
          Positioned(
            bottom: size * 0.08,
            right: size * 0.08,
            child: Container(
              width: size * 0.3,
              height: size * 0.3,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFFCC00),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFCC00).withValues(alpha: 0.65),
                    blurRadius: size * 0.12,
                    spreadRadius: -size * 0.02,
                  ),
                ],
              ),
              child: Icon(
                Icons.star_rounded,
                color: Colors.white,
                size: size * 0.18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
