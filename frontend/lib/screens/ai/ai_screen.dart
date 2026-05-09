import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/cards/ai_card.dart';

class AIScreen extends StatelessWidget {
  const AIScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("AI Recommendations"),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: const [
          AIRecommendationCard(
            issue: "Memory Leak",
            solution: "Restart container",
          ),
          AIRecommendationCard(
            issue: "High CPU",
            solution: "Scale server",
          ),
        ],
      ),
    );
  }
}