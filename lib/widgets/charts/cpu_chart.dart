import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class CPUChart extends StatelessWidget {
  final double cpu;
  const CPUChart({super.key,required this.cpu});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              isCurved: true,
              color: AppColors.accent,
              barWidth: 3,
              dotData: FlDotData(show: false),
              spots: [
                FlSpot(0, cpu - 10),
                FlSpot(1, cpu - 5),
                FlSpot(2, cpu),
                FlSpot(3, cpu + 3),
                FlSpot(4, cpu - 2),
                FlSpot(5, cpu),
              ],
            ),
          ],
        ),
      ),
    );
  }
}