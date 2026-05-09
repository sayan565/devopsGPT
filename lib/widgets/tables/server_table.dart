import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class ServerTable extends StatelessWidget {
  final List<dynamic> servers;

  const ServerTable({super.key, required this.servers});

  Color getStatusColor(String status) {
    if (status == 'critical') return AppColors.critical;
    if (status == 'warning')  return AppColors.warning;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingTextStyle: const TextStyle(
              color: Colors.white70, fontSize: 12),
          dataTextStyle: const TextStyle(
              color: Colors.white, fontSize: 12),
          columns: const [
            DataColumn(label: Text("Server")),
            DataColumn(label: Text("CPU")),
            DataColumn(label: Text("Memory")),
            DataColumn(label: Text("Status")),
          ],
          rows: servers.map((server) {
            String status = server['status'] ?? 'unknown';
            return DataRow(cells: [
              DataCell(Text(
                  server['name'] ?? server['serverId'] ?? '')),
              DataCell(Text('${server['cpu']}%')),
              DataCell(Text('${server['memory']}%')),
              DataCell(_statusBadge(status)),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: getStatusColor(status),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.toUpperCase(),
        style: const TextStyle(
            color: Colors.white, fontSize: 10),
      ),
    );
  }
}