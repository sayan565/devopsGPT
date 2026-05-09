import 'dart:ui';
import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double? borderRadius;
  final Color? borderColor;
  final List<Color>? gradient;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.borderColor,
    this.gradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(borderRadius ?? 20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: gradient != null
                  ? LinearGradient(
                      colors: gradient!,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : LinearGradient(
                      colors: isDark
                          ? [
                              const Color(0x0FFFFFFF),
                              const Color(0x05FFFFFF),
                            ]
                          : [
                              const Color(0x18000000),
                              const Color(0x08000000),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius:
                  BorderRadius.circular(borderRadius ?? 20),
              border: Border.all(
                color: borderColor ??
                    (isDark
                        ? const Color(0x1AFFFFFF)
                        : const Color(0x25000000)),
                width: 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}