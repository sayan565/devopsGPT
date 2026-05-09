import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/animated_background.dart';

class ServerDetailScreen extends StatelessWidget {
  final Map<String, dynamic> server;

  const ServerDetailScreen({
    super.key,
    required this.server,
  });

  @override
  Widget build(BuildContext context) {
    double cpu    = double.tryParse(
        server['cpu'].toString()) ?? 0;
    double memory = double.tryParse(
        server['memory'].toString()) ?? 0;
    double disk   = double.tryParse(
        server['disk']?.toString() ?? '0') ?? 0;
    String status = server['status'] ?? 'unknown';

    final textPrimary = AppTheme.textPrimary(context);
    final textMuted   = AppTheme.textMuted(context);
    final progressBg  = AppTheme.cardBorder(context);

    Color statusColor = status == 'healthy'
        ? AppColors.success
        : status == 'critical'
            ? AppColors.critical
            : AppColors.warning;

    return AnimatedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: CustomScrollView(
            slivers: [

              // App Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    GestureDetector(
                      onTap: () =>
                          Navigator.pop(context),
                      child: GlassCard(
                        padding: const EdgeInsets.all(10),
                        borderRadius: 14,
                        child: Icon(
                            Icons.arrow_back_rounded,
                            color: textPrimary,
                            size: 20),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          server['name'] ??
                              server['serverId'],
                          style: GoogleFonts.inter(
                            color: textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          server['serverId'] ?? '',
                          style: TextStyle(
                              color: textMuted,
                              fontSize: 12),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor
                            .withValues(alpha: 0.2),
                        borderRadius:
                            BorderRadius.circular(20),
                        border: Border.all(
                            color: statusColor
                                .withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ]),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([

                    // Metrics Row
                    Row(children: [
                      _metricCard(context, 'CPU',
                          '${cpu.toInt()}%',
                          Icons.speed_rounded,
                          cpu > 70
                              ? AppColors.critical
                              : AppColors.accent),
                      const SizedBox(width: 10),
                      _metricCard(context, 'Memory',
                          '${memory.toInt()}%',
                          Icons.memory_rounded,
                          memory > 80
                              ? AppColors.warning
                              : AppColors.purple),
                      const SizedBox(width: 10),
                      _metricCard(context, 'Disk',
                          '${disk.toInt()}%',
                          Icons.storage_rounded,
                          disk > 60
                              ? AppColors.warning
                              : AppColors.success),
                    ]),

                    const SizedBox(height: 16),

                    // Instance Details
                    GlassCard(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          _sectionTitle(context,
                              'Instance Details',
                              Icons.info_rounded),
                          const SizedBox(height: 16),
                          _detailRow(context, 'Instance ID',
                              server['serverId'] ?? 'N/A'),
                          _detailRow(context, 'Instance Type',
                              server['instanceType'] ?? 'N/A'),
                          _detailRow(context, 'State',
                              server['state'] ?? 'N/A'),
                          _detailRow(context, 'AMI ID',
                              server['amiId'] ?? 'N/A'),
                          _detailRow(context, 'Region',
                              server['region'] ?? 'N/A'),
                          _detailRow(context, 'Availability Zone',
                              server['availabilityZone'] ??
                                  'N/A'),
                          _detailRow(context, 'Launch Time',
                              (server['launchTime'] ?? 'N/A')
                                  .toString()
                                  .substring(0, 19)
                                  .replaceAll('T', ' ')),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Network Details
                    GlassCard(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          _sectionTitle(context,
                              'Network',
                              Icons.network_check_rounded),
                          const SizedBox(height: 16),
                          _detailRow(context, 'Public IP',
                              server['publicIp'] ?? 'N/A',
                              copyable: true),
                          _detailRow(context, 'Private IP',
                              server['privateIp'] ?? 'N/A',
                              copyable: true),
                          _detailRow(context,
                              'Security Groups',
                              server['securityGroups'] ??
                                  'N/A'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Performance Metrics
                    GlassCard(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          _sectionTitle(context,
                              'Live Metrics',
                              Icons.bar_chart_rounded),
                          const SizedBox(height: 16),
                          _progressMetric(context,
                              'CPU Usage', cpu, progressBg,
                              cpu > 70
                                  ? AppColors.critical
                                  : AppColors.accent),
                          const SizedBox(height: 12),
                          _progressMetric(context,
                              'Memory Usage', memory, progressBg,
                              memory > 80
                                  ? AppColors.warning
                                  : AppColors.purple),
                          const SizedBox(height: 12),
                          _progressMetric(context,
                              'Disk Usage', disk, progressBg,
                              disk > 60
                                  ? AppColors.warning
                                  : AppColors.success),
                          const SizedBox(height: 12),
                          Text(
                            'Last synced: '
                            '${(server['lastSyncedAt'] ?? '').toString().substring(0, 19).replaceAll('T', ' ')} UTC',
                            style: TextStyle(
                                color: textMuted,
                                fontSize: 11),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 100),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricCard(BuildContext context, String label,
      String value, IconData icon, Color color) {
    final textMuted = AppTheme.textMuted(context);
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        borderColor: color.withValues(alpha: 0.3),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            Text(label,
                style: TextStyle(
                    color: textMuted,
                    fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context,
      String title, IconData icon) {
    return Row(children: [
      Icon(icon, color: AppColors.accent, size: 18),
      const SizedBox(width: 8),
      Text(title,
          style: GoogleFonts.inter(
              color: AppTheme.textPrimary(context),
              fontSize: 15,
              fontWeight: FontWeight.bold)),
    ]);
  }

  Widget _detailRow(BuildContext context,
      String label, String value,
      {bool copyable = false}) {
    final textPrimary   = AppTheme.textPrimary(context);
    final textSecondary = AppTheme.textSecondary(context);
    final textMuted     = AppTheme.textMuted(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: TextStyle(
                    color: textSecondary,
                    fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    color: textPrimary, fontSize: 12)),
          ),
          if (copyable)
            GestureDetector(
              onTap: () {
                Clipboard.setData(
                    ClipboardData(text: value));
              },
              child: Icon(Icons.copy_rounded,
                  color: textMuted, size: 14),
            ),
        ],
      ),
    );
  }

  Widget _progressMetric(BuildContext context,
      String label, double value, Color bgColor, Color color) {
    final textSecondary = AppTheme.textSecondary(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment:
              MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    color: textSecondary,
                    fontSize: 12)),
            Text('${value.toInt()}%',
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: value / 100,
            backgroundColor: bgColor,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}
