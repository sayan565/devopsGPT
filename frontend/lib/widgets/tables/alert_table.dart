import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class AlertTable extends StatelessWidget {
  final List<dynamic> alerts;

  const AlertTable({super.key, required this.alerts});

  Color getColor(String severity) {
    if (severity == 'HIGH')    return AppColors.critical;
    if (severity == 'MEDIUM')  return AppColors.warning;
    return AppColors.accent;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: alerts.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text(
                  "No alerts",
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingTextStyle: const TextStyle(
                    color: Colors.white70, fontSize: 12),
                dataTextStyle: const TextStyle(
                    color: Colors.white, fontSize: 12),
                columns: const [
                  DataColumn(label: Text("Server")),
                  DataColumn(label: Text("Message")),
                  DataColumn(label: Text("Severity")),
                  DataColumn(label: Text("Status")),
                ],
                rows: alerts.map((alert) {
                  String severity = alert['severity'] ?? 'LOW';
                  String status   = alert['status'] ?? 'active';
                  return DataRow(cells: [
                    DataCell(Text(alert['serverId'] ?? '')),
                    DataCell(SizedBox(
                      width: 150,
                      child: Text(
                        alert['message'] ?? '',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11),
                      ),
                    )),
                    DataCell(_badge(severity, getColor(severity))),
                    DataCell(_badge(
                      status,
                      status == 'resolved'
                          ? AppColors.success
                          : AppColors.warning,
                    )),
                  ]);
                }).toList(),
              ),
            ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
            color: Colors.white, fontSize: 10),
      ),
    );
  }
}