import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../services/api_service.dart';

class AIRecommendationCard extends StatefulWidget {
  final String issue;
  final String solution;
  final String? serverId;
  final String? fixAction;

  const AIRecommendationCard({
    super.key,
    required this.issue,
    required this.solution,
    this.serverId,
    this.fixAction,
  });

  @override
  State<AIRecommendationCard> createState() =>
      _AIRecommendationCardState();
}

class _AIRecommendationCardState
    extends State<AIRecommendationCard> {
  bool isFixing = false;

  Future<void> runFix() async {
    if (widget.serverId == null || widget.fixAction == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No fix action available'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => isFixing = true);

    try {
      final result = await ApiService.fixServer(
          widget.serverId!, widget.fixAction!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✅ ${result['message'] ?? 'Fix applied!'}'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Fix failed: $e'),
            backgroundColor: AppColors.critical,
          ),
        );
      }
    }

    setState(() => isFixing = false);
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
            Text("Issue: ${widget.issue}",
                style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 8),
            Text("Solution: ${widget.solution}",
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton(
                  onPressed: isFixing ? null : runFix,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent),
                  child: isFixing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black),
                        )
                      : const Text("Fix",
                          style: TextStyle(color: Colors.black)),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {},
                  child: const Text("Ignore"),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}