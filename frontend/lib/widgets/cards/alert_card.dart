import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class AlertCard extends StatelessWidget {
  final String title;
  final String server;
  final String severity;

  const AlertCard({
    super.key,
    required this.title,
    required this.server,
    required this.severity,
  });

  Color getColor() {
    if (severity == 'Critical') return AppColors.critical;
    if (severity == 'Warning')  return AppColors.warning;
    return AppColors.accent;
  }

  @override
  Widget build(BuildContext context) {
    final cardColor     = AppTheme.card(context);
    final textPrimary   = AppTheme.textPrimary(context);
    final textSecondary = AppTheme.textSecondary(context);
    final color         = getColor();

    return Card(
      color: cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.warning_rounded, color: color, size: 20),
        ),
        title: Text(title,
            style: TextStyle(
                color: textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
        subtitle: Text(server,
            style: TextStyle(color: textSecondary, fontSize: 11)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: color.withValues(alpha: 0.4)),
          ),
          child: Text(severity,
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
