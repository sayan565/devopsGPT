import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class ServerCard extends StatelessWidget {
  final String name;
  final double cpu;
  final double memory;
  final String status;

  const ServerCard({
    super.key,
    required this.name,
    required this.cpu,
    required this.memory,
    required this.status,
  });

  Color getStatusColor() {
    if (status == "Critical") return AppColors.critical;
    if (status == "Warning") return AppColors.warning;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.card,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 8),
            Text("CPU: $cpu%", style: const TextStyle(color: Colors.white70)),
            Text("Memory: $memory%",
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: getStatusColor(),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(status, style: const TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }
}