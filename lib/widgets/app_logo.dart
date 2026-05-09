import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;

  const AppLogo({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00D4FF), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.25),
        boxShadow: [
          BoxShadow(
                            color: const Color(0xFF00D4FF).withValues(alpha: 0.3),
            blurRadius: size * 0.4,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(
        Icons.auto_fix_high_rounded,
        color: Colors.white,
        size: size * 0.5,
      ),
    );
  }
}